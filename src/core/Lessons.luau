--!strict
-- Every driving session, in the order players take them (PRD-006 and PRD-009): the five lessons, the driving test,
-- and the missions that come after the license. Each one is a route through town (see LessonRoute), given as the
-- points where it turns, with one goal to reach by the finish line.
-- Sessions are grouped into levels (PRD-009, requirement 12). Passing every session in a level opens the next one.

local LessonRoute = require("./LessonRoute")

-- What a session asks for (PRD-009, requirement 3):
-- - "stars": earn `count` stars
-- - "rule": follow one rule `count` times, counted by the stars for that rule (see RULE_GOALS)
-- - "clean": follow every rule on the route
-- - "finish": reach the finish line
export type Goal = { kind: "stars" | "rule" | "clean" | "finish", rule: string?, count: number? }

export type Lesson = {
	id: string,
	number: number,
	title: string, -- a key in the Strings table
	intro: string, -- what Bendi says at the start, a key in the Strings table
	isTest: boolean,
	mission: boolean, -- a mission after the license, rather than a lesson or the test
	level: number,
	goal: Goal,
	night: boolean?, -- the player's own sky is night for the whole session
	busy: boolean?, -- pedestrians cross more often while it runs
	expert: boolean?, -- no arrows, and the instructor says where to turn
	nodes: { { number } },
}

export type Level = { number: number, title: string }

local Lessons = {}

Lessons.PASS_STARS = 3

Lessons.LEVELS = {
	{ number = 1, title = "levelLearner" },
	{ number = 2, title = "levelRoadUser" },
	{ number = 3, title = "levelTestDay" },
	{ number = 4, title = "levelLicensed" },
	{ number = 5, title = "levelBusyTown" },
	{ number = 6, title = "levelNight" },
	{ number = 7, title = "levelExpert" },
} :: { Level }

local LESSON_GOAL: Goal = { kind = "stars", count = Lessons.PASS_STARS }

-- The rules a goal can be about, named by the start of their star keys (light1, segment4, stop2, ...), with the
-- goal's text in the Strings table.
Lessons.RULE_GOALS = {
	light = "goalLight",
	segment = "goalSegment",
	crosswalk = "goalCrosswalk",
	roundabout = "goalRoundabout",
	stop = "goalStop",
	giveWay = "goalGiveWay",
} :: { [string]: string }

Lessons.LIST = {
	{
		-- Around the ring road, with only right turns and no traffic lights.
		id = "basics",
		level = 1,
		goal = LESSON_GOAL,
		mission = false,
		number = 1,
		title = "lessonBasics",
		intro = "introBasics",
		isTest = false,
		nodes = { { 90, -270 }, { 360, -270 }, { 360, 270 }, { -360, 270 }, { -360, -270 }, { 0, -270 } },
	},
	{
		-- Through all four traffic lights, most of them twice.
		id = "lights",
		level = 1,
		goal = LESSON_GOAL,
		mission = false,
		number = 2,
		title = "lessonLights",
		intro = "introLights",
		isTest = false,
		nodes = {
			{ -270, 90 },
			{ -180, 90 },
			{ -180, -90 },
			{ -360, -90 },
			{ -360, 90 },
			{ -180, 90 },
			{ 0, 90 },
			{ 0, -90 },
			{ -180, -90 },
			{ -180, 90 },
			{ 40, 90 },
		},
	},
	{
		-- Town streets at 50 km/h, the quiet street at 30 (twice), and the school street at 30.
		id = "speed",
		level = 2,
		goal = LESSON_GOAL,
		mission = false,
		number = 3,
		title = "lessonSpeed",
		intro = "introSpeed",
		isTest = false,
		nodes = {
			{ -270, -270 },
			{ -180, -270 },
			{ -180, 270 },
			{ 0, 270 },
			{ 0, -270 },
			{ -180, -270 },
			{ -180, -90 },
			{ -270, -90 },
		},
	},
	{
		-- Over all four zebra crosswalks.
		id = "crosswalks",
		level = 2,
		goal = LESSON_GOAL,
		mission = false,
		number = 4,
		title = "lessonCrosswalks",
		intro = "introCrosswalks",
		isTest = false,
		nodes = {
			{ -360, -180 },
			{ -360, -270 },
			{ -180, -270 },
			{ -180, -90 },
			{ 0, -90 },
			{ 0, 270 },
			{ -180, 270 },
			{ -180, 90 },
			{ 110, 90 },
		},
	},
	{
		-- Two stop signs, three trips through the roundabout, and the give-way sign twice.
		id = "junctions",
		level = 3,
		goal = LESSON_GOAL,
		mission = false,
		number = 5,
		title = "lessonJunctions",
		intro = "introJunctions",
		isTest = false,
		nodes = {
			{ 180, -200 },
			{ 180, 270 },
			{ 360, 270 },
			{ 360, 90 },
			{ 180, 90 },
			{ 180, -270 },
			{ 360, -270 },
			{ 360, -90 },
			{ 180, -90 },
			{ 180, 270 },
			{ 270, 270 },
		},
	},
	{
		-- A longer route with every rule: all four traffic lights, both 30 km/h streets, three crosswalks, a stop
		-- sign from each side, the roundabout twice, and the give-way sign.
		id = "test",
		level = 3,
		goal = { kind = "clean" },
		mission = false,
		number = 6,
		title = "drivingTest",
		intro = "introTest",
		isTest = true,
		nodes = {
			{ -270, 90 },
			{ -180, 90 },
			{ -180, 270 },
			{ 0, 270 },
			{ 0, -90 },
			{ -180, -90 },
			{ -180, -270 },
			{ 180, -270 },
			{ 180, 270 },
			{ 360, 270 },
			{ 360, 90 },
			{ 180, 90 },
			{ 180, -180 },
		},
	},
	-- Level 4: mixing the rules on longer routes.
	{
		-- Both 30 km/h streets and their crosswalks, plus four traffic lights.
		id = "schoolRun",
		number = 7,
		title = "missionSchoolRun",
		intro = "introSchoolRun",
		isTest = false,
		mission = true,
		level = 4,
		goal = { kind = "rule", rule = "segment", count = 5 },
		nodes = {
			{ -360, -180 },
			{ -360, -270 },
			{ -180, -270 },
			{ -180, 90 },
			{ 0, 90 },
			{ 0, 270 },
			{ -180, 270 },
			{ -180, 90 },
			{ -360, 90 },
			{ -360, -30 },
		},
	},
	{
		-- Into the roundabout from three different sides, with both stop signs and the give-way sign on the way.
		id = "roundTrip",
		number = 8,
		title = "missionRoundTrip",
		intro = "introRoundTrip",
		isTest = false,
		mission = true,
		level = 4,
		goal = { kind = "rule", rule = "roundabout", count = 3 },
		nodes = {
			{ 30, 90 },
			{ 180, 90 },
			{ 180, 270 },
			{ 360, 270 },
			{ 360, 90 },
			{ 180, 90 },
			{ 180, -90 },
			{ 0, -90 },
			{ 0, -270 },
			{ 180, -270 },
			{ 180, 90 },
			{ 360, 90 },
			{ 360, 0 },
		},
	},
	-- Level 5: the busiest streets, where the NPC cars drive, and more people crossing.
	{
		id = "rushHour",
		number = 9,
		title = "missionRushHour",
		intro = "introRushHour",
		isTest = false,
		mission = true,
		level = 5,
		busy = true,
		goal = { kind = "stars", count = 5 },
		nodes = {
			{ -270, -90 },
			{ 0, -90 },
			{ 0, 90 },
			{ 180, 90 },
			{ 180, -90 },
			{ 360, -90 },
			{ 360, 90 },
			{ 180, 90 },
			{ 180, 270 },
			{ 0, 270 },
			{ 0, -180 },
		},
	},
	{
		-- Over all four crosswalks.
		id = "busyCrosswalks",
		number = 10,
		title = "missionBusyCrosswalks",
		intro = "introBusyCrosswalks",
		isTest = false,
		mission = true,
		level = 5,
		busy = true,
		goal = { kind = "rule", rule = "crosswalk", count = 2 },
		nodes = {
			{ 100, 90 },
			{ -180, 90 },
			{ -180, -270 },
			{ 0, -270 },
			{ 0, 270 },
			{ -180, 270 },
			{ -180, -90 },
			{ 90, -90 },
		},
	},
	-- Level 6: driving at night.
	{
		id = "nightDrive",
		number = 11,
		title = "missionNightDrive",
		intro = "introNightDrive",
		isTest = false,
		mission = true,
		level = 6,
		night = true,
		goal = { kind = "stars", count = 4 },
		nodes = {
			{ -270, -270 },
			{ 180, -270 },
			{ 180, -90 },
			{ -180, -90 },
			{ -180, 90 },
			{ 0, 90 },
			{ 0, 270 },
			{ 120, 270 },
		},
	},
	{
		id = "quietNight",
		number = 12,
		title = "missionQuietNight",
		intro = "introQuietNight",
		isTest = false,
		mission = true,
		level = 6,
		night = true,
		goal = { kind = "clean" },
		nodes = {
			{ -270, 90 },
			{ 0, 90 },
			{ 0, -270 },
			{ -360, -270 },
			{ -360, 270 },
			{ -90, 270 },
		},
	},
	-- Level 7: no arrows. The instructor says where to turn.
	{
		id = "findYourWay",
		number = 13,
		title = "missionFindYourWay",
		intro = "introFindYourWay",
		isTest = false,
		mission = true,
		level = 7,
		expert = true,
		goal = { kind = "finish" },
		nodes = {
			{ -360, -180 },
			{ -360, -270 },
			{ 0, -270 },
			{ 0, 90 },
			{ -360, 90 },
			{ -360, -90 },
			{ -180, -90 },
			{ -180, -180 },
		},
	},
	{
		id = "expertLoop",
		number = 14,
		title = "missionExpertLoop",
		intro = "introExpertLoop",
		isTest = false,
		mission = true,
		level = 7,
		expert = true,
		goal = { kind = "clean" },
		nodes = {
			{ 270, -270 },
			{ 180, -270 },
			{ 180, 90 },
			{ 0, 90 },
			{ 0, -90 },
			{ 360, -90 },
			{ 360, 270 },
			{ 60, 270 },
		},
	},
} :: { Lesson }

local routes: { [string]: LessonRoute.Route } = {}

-- The lesson (or the test) with this id, if there is one.
function Lessons.get(id: string): Lesson?
	for _, lesson in Lessons.LIST do
		if lesson.id == id then
			return lesson
		end
	end
	return nil
end

-- The lesson that comes after this one, if any.
function Lessons.after(id: string): Lesson?
	for index, lesson in Lessons.LIST do
		if lesson.id == id then
			return Lessons.LIST[index + 1]
		end
	end
	return nil
end

-- The text for a goal: a key in the Strings table, and the values to fill into it.
function Lessons.goalText(goal: Goal): (string, { [string]: any })
	if goal.kind == "stars" then
		return "goalStars", { count = goal.count }
	elseif goal.kind == "rule" then
		return Lessons.RULE_GOALS[goal.rule :: string], { count = goal.count }
	elseif goal.kind == "clean" then
		return "goalClean", {}
	end
	return "goalFinish", {}
end

-- The sessions in `level`, in order.
function Lessons.inLevel(level: number): { Lesson }
	local result = {}
	for _, lesson in Lessons.LIST do
		if lesson.level == level then
			table.insert(result, lesson)
		end
	end
	return result
end

-- The lesson's route, built once and shared.
function Lessons.route(lesson: Lesson): LessonRoute.Route
	local route = routes[lesson.id]
	if not route then
		route = LessonRoute.build(lesson.nodes)
		routes[lesson.id] = route
	end
	return route
end

return Lessons
