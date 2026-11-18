local TestKit = require("../TestKit")
local LessonRun = require("../../src/core/LessonRun")
local Lessons = require("../../src/core/Lessons")
local RuleKit = require("../../src/core/RuleKit")

local test, expectEqual = TestKit.test, TestKit.expectEqual

print("LessonRun")

local function lesson(id: string): Lessons.Lesson
	return assert(Lessons.get(id))
end

-- Drives through every checkpoint of the run's route.
local function driveAll(run: LessonRun.Run)
	for _, checkpoint in run.route.checkpoints do
		LessonRun.update(run, checkpoint.x, checkpoint.z)
	end
end

test("a new run heads for the first checkpoint", function()
	local run = LessonRun.new(lesson("basics"))
	expectEqual(run.checkpoint, 1)
	expectEqual(run.stars, 0)
	expectEqual(run.finished, false)
	expectEqual(run.route, Lessons.route(lesson("basics")))
end)

test("update reports when the next checkpoint changes", function()
	local run = LessonRun.new(lesson("basics"))
	local first = run.route.checkpoints[1]
	expectEqual(LessonRun.update(run, first.x, first.z + 100), false)
	expectEqual(LessonRun.update(run, first.x, first.z), true)
	expectEqual(run.checkpoint, 2)
end)

test("reaching the last checkpoint finishes the run", function()
	local run = LessonRun.new(lesson("basics"))
	driveAll(run)
	expectEqual(run.finished, true)
	expectEqual(run.checkpoint, #run.route.checkpoints + 1)
	local last = run.route.checkpoints[#run.route.checkpoints]
	expectEqual(LessonRun.update(run, last.x, last.z), false)
end)

test("a lesson is passed with three stars", function()
	local run = LessonRun.new(lesson("lights"))
	for index = 1, 2 do
		LessonRun.onEvent(run, RuleKit.star(`light{index}`))
	end
	driveAll(run)
	expectEqual(run.stars, 2)
	expectEqual(LessonRun.passed(run), false)

	run = LessonRun.new(lesson("lights"))
	for index = 1, 3 do
		LessonRun.onEvent(run, RuleKit.star(`light{index}`))
	end
	expectEqual(LessonRun.passed(run), false) -- not finished yet
	driveAll(run)
	expectEqual(LessonRun.passed(run), true)
end)

test("missed rules are remembered, but explanations and praise aren't", function()
	local run = LessonRun.new(lesson("test"))
	LessonRun.onEvent(run, RuleKit.tip("flashingGreen"))
	LessonRun.onEvent(run, RuleKit.tip("yieldedRoundabout"))
	expectEqual(#run.missed, 0)
	LessonRun.onEvent(run, RuleKit.tip("ranRed"))
	expectEqual(run.missed[1], "ranRed")
end)

test("the test is passed by following every rule, with or without stars", function()
	local run = LessonRun.new(lesson("test"))
	driveAll(run)
	expectEqual(LessonRun.passed(run), true)

	run = LessonRun.new(lesson("test"))
	for index = 1, 5 do
		LessonRun.onEvent(run, RuleKit.star(`segment{index}`))
	end
	LessonRun.onEvent(run, RuleKit.tip("rolledStop"))
	driveAll(run)
	expectEqual(LessonRun.passed(run), false)
end)

test("nothing counts after the run is finished", function()
	local run = LessonRun.new(lesson("basics"))
	driveAll(run)
	LessonRun.onEvent(run, RuleKit.star("segment1"))
	LessonRun.onEvent(run, RuleKit.tip("ranRed"))
	expectEqual(run.stars, 0)
	expectEqual(#run.missed, 0)
end)

local function mission(kind: string): Lessons.Lesson
	for _, item in Lessons.LIST do
		if item.goal.kind == kind and item.mission then
			return item
		end
	end
	error(`no mission with a {kind} goal`)
end

test("star keys match their rule, with or without a number", function()
	expectEqual(LessonRun.isRuleStar("light2", "light"), true)
	expectEqual(LessonRun.isRuleStar("segment10", "segment"), true)
	expectEqual(LessonRun.isRuleStar("giveWay", "giveWay"), true)
	expectEqual(LessonRun.isRuleStar("lightning", "light"), false)
	expectEqual(LessonRun.isRuleStar("crosswalk1", "light"), false)
	expectEqual(LessonRun.isRuleStar("stop", "stop"), true)
end)

test("a goal about one rule counts only that rule's stars", function()
	local item = mission("rule")
	local rule = item.goal.rule :: string
	local need = item.goal.count :: number
	local run = LessonRun.new(item)
	LessonRun.onEvent(run, RuleKit.star(if rule == "light" then "segment1" else "light1"))
	for index = 1, need - 1 do
		LessonRun.onEvent(run, RuleKit.star(`{rule}{index}`))
	end
	local count, needed = LessonRun.progress(run)
	expectEqual(count, need - 1)
	expectEqual(needed, need)
	expectEqual(run.stars, need)
	driveAll(run)
	expectEqual(LessonRun.passed(run), false)
	expectEqual(LessonRun.medal(run), 0)

	run = LessonRun.new(item)
	for index = 1, need do
		LessonRun.onEvent(run, RuleKit.star(`{rule}{index}`))
	end
	driveAll(run)
	expectEqual(LessonRun.passed(run), true)
end)

test("a star goal counts every star", function()
	local run = LessonRun.new(lesson("basics"))
	LessonRun.onEvent(run, RuleKit.star("segment1"))
	LessonRun.onEvent(run, RuleKit.star("light1"))
	local count, need = LessonRun.progress(run)
	expectEqual(count, 2)
	expectEqual(need, Lessons.PASS_STARS)
end)

test("a clean goal counts missed rules, and a finish goal is met by finishing", function()
	local run = LessonRun.new(lesson("test"))
	LessonRun.onEvent(run, RuleKit.tip("ranRed"))
	local count, need = LessonRun.progress(run)
	expectEqual(count, 1)
	expectEqual(need, nil)

	run = LessonRun.new(mission("finish"))
	expectEqual(select(1, LessonRun.progress(run)), 0)
	expectEqual(select(2, LessonRun.progress(run)), nil)
	LessonRun.onEvent(run, RuleKit.tip("ranRed"))
	expectEqual(LessonRun.passed(run), false) -- not finished yet
	driveAll(run)
	expectEqual(LessonRun.passed(run), true)
end)

test("medals: gold with no rules missed, silver with one, bronze with more", function()
	local item = mission("finish")
	-- The medal for 0, 1, 2, and 3 rules missed.
	local expected = { LessonRun.GOLD, LessonRun.SILVER, LessonRun.BRONZE, LessonRun.BRONZE }
	for missed = 0, 3 do
		local run = LessonRun.new(item)
		for _ = 1, missed do
			LessonRun.onEvent(run, RuleKit.tip("tooFastTown"))
		end
		expectEqual(LessonRun.medal(run), 0) -- not finished
		driveAll(run)
		expectEqual(LessonRun.medal(run), expected[missed + 1])
	end
end)

test("a passed driving test is always gold", function()
	local run = LessonRun.new(lesson("test"))
	driveAll(run)
	expectEqual(LessonRun.medal(run), LessonRun.GOLD)
end)

test("the practice list names each kind of missed rule once, at most two, in order", function()
	local run = LessonRun.new(lesson("test"))
	for _, tip in { "tooFastTown", "tooFastSchool", "ranRed", "rolledStop", "flashingGreen" } do
		LessonRun.onEvent(run, RuleKit.tip(tip))
	end
	local practice = LessonRun.practice(run)
	expectEqual(#practice, 2)
	expectEqual(practice[1], "practiceSpeed")
	expectEqual(practice[2], "practiceLights")
	expectEqual(#LessonRun.practice(LessonRun.new(lesson("test"))), 0)
end)

TestKit.finish()
