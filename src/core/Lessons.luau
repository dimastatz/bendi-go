--!strict
-- The five driving lessons and the driving test (PRD-006, requirements 1, 2, 3, 6, and 7), in the order players
-- take them. Each one is a route through town (see LessonRoute), given as the points where it turns.
-- Lessons are passed with at least PASS_STARS stars, and the test is passed by following every rule on its route.

local LessonRoute = require("./LessonRoute")

export type Lesson = {
	id: string,
	number: number,
	title: string, -- a key in the Strings table
	intro: string, -- what Bendi says at the start, a key in the Strings table
	isTest: boolean,
	nodes: { { number } },
}

local Lessons = {}

Lessons.PASS_STARS = 3

Lessons.LIST = {
	{
		-- Around the ring road, with only right turns and no traffic lights.
		id = "basics",
		number = 1,
		title = "lessonBasics",
		intro = "introBasics",
		isTest = false,
		nodes = { { 90, -270 }, { 360, -270 }, { 360, 270 }, { -360, 270 }, { -360, -270 }, { 0, -270 } },
	},
	{
		-- Through all four traffic lights, most of them twice.
		id = "lights",
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
