local TestKit = require("../TestKit")
local Approach = require("../../src/core/Approach")

local test, expectEqual = TestKit.test, TestKit.expectEqual

-- Cars driving east (+X) on the z = 90 street toward a line at x = 100.
local east = { alongX = true, direction = 1, at = 90, line = 100 }
-- Cars driving north (-Z) on the x = 0 street toward a line at z = 50.
local north = { alongX = false, direction = -1, at = 0, line = 50 }

print("Approach")

test("distance before the line is positive before it and negative past it", function()
	expectEqual(Approach.distanceBefore(east, 80, 95), 20)
	expectEqual(Approach.distanceBefore(east, 110, 95), -10)
	expectEqual(Approach.distanceBefore(north, 0, 70), 20)
end)

test("the right-hand side is positive", function()
	expectEqual(Approach.rightOffset(east, 0, 95), 5)
	expectEqual(Approach.rightOffset(east, 0, 85), -5)
	expectEqual(Approach.rightOffset(north, 5, 0), 5)
end)

test("contains checks distance, side of the road, and heading", function()
	expectEqual(Approach.contains(east, { x = 80, z = 95, dirX = 1, dirZ = 0, speed = 0 }, 30), true)
	expectEqual(Approach.contains(east, { x = 60, z = 95, dirX = 1, dirZ = 0, speed = 0 }, 30), false)
	expectEqual(Approach.contains(east, { x = 80, z = 85, dirX = 1, dirZ = 0, speed = 0 }, 30), false)
	expectEqual(Approach.contains(east, { x = 80, z = 95, dirX = 0, dirZ = 1, speed = 0 }, 30), false)
	expectEqual(Approach.contains(east, { x = 80, z = 95, dirX = 0, dirZ = 0, speed = 0 }, 30), false)
end)

test("point is along the street and to the right of its center line", function()
	local x, z = Approach.point(east, 70, 5)
	expectEqual(x, 70)
	expectEqual(z, 95)
	x, z = Approach.point(north, 70, 5)
	expectEqual(x, 5)
	expectEqual(z, 70)
end)

TestKit.finish()
