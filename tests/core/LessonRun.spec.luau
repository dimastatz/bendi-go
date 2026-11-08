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

TestKit.finish()
