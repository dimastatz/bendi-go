--!strict
-- One player driving one lesson or the driving test (PRD-006, requirements 3 and 7): which checkpoint is next,
-- how many stars they've earned on the way, and which rules they missed.
-- A lesson is passed with at least Lessons.PASS_STARS stars. The test is passed when no rule was missed.

local LessonRoute = require("./LessonRoute")
local Lessons = require("./Lessons")
local RuleKit = require("./RuleKit")

export type Run = {
	lesson: Lessons.Lesson,
	route: LessonRoute.Route,
	checkpoint: number, -- the checkpoint to drive to next
	stars: number,
	missed: { string }, -- the tips for rules that weren't followed, in order
	finished: boolean,
}

local LessonRun = {}

-- Tips that mean a rule wasn't followed. Other tips explain something or praise the player.
LessonRun.MISSED_RULE_TIPS = {
	ranRed = true,
	tooFastTown = true,
	tooFastResidential = true,
	tooFastSchool = true,
	didntStopForPedestrian = true,
	didntYieldRoundabout = true,
	didntGiveWay = true,
	rolledStop = true,
} :: { [string]: boolean }

function LessonRun.new(lesson: Lessons.Lesson): Run
	return {
		lesson = lesson,
		route = Lessons.route(lesson),
		checkpoint = 1,
		stars = 0,
		missed = {},
		finished = false,
	}
end

-- Counts a star the player was given, or a tip they got, while driving the lesson.
function LessonRun.onEvent(run: Run, event: RuleKit.Event)
	if run.finished then
		return
	end
	if event.kind == "star" then
		run.stars += 1
	elseif LessonRun.MISSED_RULE_TIPS[event.tip] then
		table.insert(run.missed, event.tip)
	end
end

-- Moves the run along as the car drives to (x, z). Returns true if the next checkpoint changed.
function LessonRun.update(run: Run, x: number, z: number): boolean
	if run.finished then
		return false
	end
	local index = LessonRoute.advance(run.route, run.checkpoint, x, z)
	if index == run.checkpoint then
		return false
	end
	run.checkpoint = index
	run.finished = index > #run.route.checkpoints
	return true
end

-- True if the finished run passes: enough stars for a lesson, or every rule followed for the test.
function LessonRun.passed(run: Run): boolean
	if not run.finished then
		return false
	end
	if run.lesson.isTest then
		return #run.missed == 0
	end
	return run.stars >= Lessons.PASS_STARS
end

return LessonRun
