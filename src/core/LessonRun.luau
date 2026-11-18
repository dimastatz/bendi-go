--!strict
-- One player driving one session: a lesson, the driving test, or a mission (PRD-006 and PRD-009). It keeps track of
-- which checkpoint is next, the stars earned on the way, how close the player is to the session's goal, and which
-- rules they missed.
-- A finished run is passed when its goal was met, and then earns a medal for how well the rules were followed.

local LessonRoute = require("./LessonRoute")
local Lessons = require("./Lessons")
local RuleKit = require("./RuleKit")

export type Run = {
	lesson: Lessons.Lesson,
	route: LessonRoute.Route,
	checkpoint: number, -- the checkpoint to drive to next
	stars: number,
	counted: number, -- stars for the rule the goal is about
	missed: { string }, -- the tips for rules that weren't followed, in order
	finished: boolean,
}

-- 0 is "not yet", then bronze, silver, and gold (PRD-009, requirement 7).
export type Medal = number

local LessonRun = {}

LessonRun.BRONZE, LessonRun.SILVER, LessonRun.GOLD = 1, 2, 3
LessonRun.MAX_PRACTICE = 2 -- how many rules the result card says to practise

-- Tips that mean a rule wasn't followed, and what to practise after each one (keys in the Strings table). Other tips
-- explain something or praise the player.
LessonRun.MISSED_RULE_TIPS = {
	ranRed = "practiceLights",
	tooFastTown = "practiceSpeed",
	tooFastResidential = "practiceSpeed",
	tooFastSchool = "practiceSpeed",
	didntStopForPedestrian = "practiceCrosswalks",
	didntYieldRoundabout = "practiceRoundabout",
	didntGiveWay = "practiceGiveWay",
	rolledStop = "practiceStop",
} :: { [string]: string }

function LessonRun.new(lesson: Lessons.Lesson): Run
	return {
		lesson = lesson,
		route = Lessons.route(lesson),
		checkpoint = 1,
		stars = 0,
		counted = 0,
		missed = {},
		finished = false,
	}
end

-- True if the star `key` is for `rule`: the key is the rule's name, maybe followed by a number.
function LessonRun.isRuleStar(key: string, rule: string): boolean
	return string.sub(key, 1, #rule) == rule and string.match(string.sub(key, #rule + 1), "^%d*$") ~= nil
end

-- Counts a star the player was given, or a tip they got, while driving the session.
function LessonRun.onEvent(run: Run, event: RuleKit.Event)
	if run.finished then
		return
	end
	if event.kind == "star" then
		run.stars += 1
		local goal = run.lesson.goal
		if goal.kind == "rule" and LessonRun.isRuleStar(event.key, goal.rule :: string) then
			run.counted += 1
		end
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

-- How far along the goal is, and how far it needs to get. Goals that aren't counted (every rule, or just the
-- finish) have no number to reach, so `need` is nil.
function LessonRun.progress(run: Run): (number, number?)
	local goal = run.lesson.goal
	if goal.kind == "stars" then
		return run.stars, goal.count
	elseif goal.kind == "rule" then
		return run.counted, goal.count
	elseif goal.kind == "clean" then
		return #run.missed, nil
	end
	return 0, nil
end

-- True if the goal is met so far. A "finish" goal is met by finishing.
function LessonRun.goalMet(run: Run): boolean
	local goal = run.lesson.goal
	if goal.kind == "clean" then
		return #run.missed == 0
	elseif goal.kind == "finish" then
		return true
	end
	local count, need = LessonRun.progress(run)
	return count >= (need :: number)
end

-- True if the run is finished and its goal was met.
function LessonRun.passed(run: Run): boolean
	return run.finished and LessonRun.goalMet(run)
end

-- The medal for a finished run: gold when every rule was followed, silver with one rule missed, and bronze with
-- more. A run that wasn't passed gets 0, "not yet".
function LessonRun.medal(run: Run): Medal
	if not LessonRun.passed(run) then
		return 0
	end
	local missed = #run.missed
	return if missed == 0 then LessonRun.GOLD elseif missed == 1 then LessonRun.SILVER else LessonRun.BRONZE
end

-- What to practise, as keys in the Strings table: one for each kind of rule missed, in the order they were first
-- missed, and at most MAX_PRACTICE of them.
function LessonRun.practice(run: Run): { string }
	local result = {}
	for _, tip in run.missed do
		local key = LessonRun.MISSED_RULE_TIPS[tip]
		if not table.find(result, key) then
			table.insert(result, key)
			if #result == LessonRun.MAX_PRACTICE then
				break
			end
		end
	end
	return result
end

return LessonRun
