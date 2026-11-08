local TestKit = require("../TestKit")
local Junctions = require("../../src/core/Junctions")
local LessonRoute = require("../../src/core/LessonRoute")
local TownLayout = require("../../src/core/TownLayout")

local test, expectEqual, expectNear = TestKit.test, TestKit.expectEqual, TestKit.expectNear

print("LessonRoute")

local OFFSET = TownLayout.LANE_WIDTH / 2

test("checkpoints are spread along each street, in the right-hand lane", function()
	local route = LessonRoute.build({ { -360, -270 }, { -180, -270 } })
	expectEqual(route.length, 180)
	expectEqual(#route.checkpoints, 4)
	for index, checkpoint in route.checkpoints do
		expectNear(checkpoint.x, -360 + 45 * index)
		-- Driving toward +x, the right-hand side is +z.
		expectNear(checkpoint.z, -270 + OFFSET)
		expectEqual(checkpoint.dirX, 1)
		expectEqual(checkpoint.dirZ, 0)
		expectEqual(checkpoint.turn, false)
		expectEqual(checkpoint.radius, LessonRoute.RADIUS)
	end
end)

test("the route starts in the lane at the first point, facing the second", function()
	local route = LessonRoute.build({ { 0, 0 }, { 0, -90 } })
	expectNear(route.start.x, OFFSET)
	expectNear(route.start.z, 0)
	expectEqual(route.start.dirX, 0)
	expectEqual(route.start.dirZ, -1)
end)

test("a turn has a checkpoint in the middle of the crossing that points the new way", function()
	local route = LessonRoute.build({ { -270, -90 }, { -180, -90 }, { -180, 0 } })
	local turn = route.checkpoints[2]
	expectEqual(turn.x, -180)
	expectEqual(turn.z, -90)
	expectEqual(turn.dirX, 0)
	expectEqual(turn.dirZ, 1)
	expectEqual(turn.turn, true)
	expectEqual(turn.radius, LessonRoute.TURN_RADIUS)
	expectEqual(route.length, 180)
end)

test("driving straight through a crossing keeps the checkpoint in the lane", function()
	local route = LessonRoute.build({ { -360, -270 }, { -180, -270 }, { 0, -270 } })
	expectEqual(route.checkpoints[4].turn, false)
	expectNear(route.checkpoints[4].z, -270 + OFFSET)
end)

test("there are no checkpoints in the roundabout", function()
	local route = LessonRoute.build({ { 180, -90 }, { 180, 270 } })
	for _, checkpoint in route.checkpoints do
		local distance = math.sqrt((checkpoint.x - Junctions.CENTER_X) ^ 2 + (checkpoint.z - Junctions.CENTER_Z) ^ 2)
		if distance < LessonRoute.ROUNDABOUT_CLEAR then
			error(`checkpoint at {checkpoint.x}, {checkpoint.z} is in the roundabout`)
		end
	end
	expectEqual(#route.checkpoints, 7)
end)

test("a route must run along streets and never turn around", function()
	expectEqual(pcall(LessonRoute.build, { { 0, 0 }, { 90, 90 } }), false)
	expectEqual(pcall(LessonRoute.build, { { 0, 0 }, { 0, 90 }, { 0, 0 } }), false)
	expectEqual(pcall(LessonRoute.build, { { 0, 0 } }), false)
end)

test("advance moves on once the car reaches the next checkpoint", function()
	local route = LessonRoute.build({ { -360, -270 }, { -180, -270 } })
	local first = route.checkpoints[1]
	expectEqual(LessonRoute.advance(route, 1, first.x - 30, first.z), 1)
	expectEqual(LessonRoute.advance(route, 1, first.x - 10, first.z + 6), 2)
end)

test("advance lets the car skip a couple of checkpoints, but not more", function()
	local route = LessonRoute.build({ { -360, -270 }, { -180, -270 } })
	local third, fourth = route.checkpoints[3], route.checkpoints[4]
	expectEqual(LessonRoute.advance(route, 1, third.x, third.z), 4)
	expectEqual(LessonRoute.advance(route, 1, fourth.x, fourth.z), 1)
	expectEqual(LessonRoute.advance(route, 4, fourth.x, fourth.z), 5)
end)

TestKit.finish()
