local TestKit = require("../TestKit")
local Crosswalks = require("../../src/core/Crosswalks")
local Rect = require("../../src/core/Rect")
local TownLayout = require("../../src/core/TownLayout")
local TownProps = require("../../src/core/TownProps")

local test, expectEqual, expectNear = TestKit.test, TestKit.expectEqual, TestKit.expectNear

-- Crosswalk 3 is on the z = 90 street at x = 60. Eastbound cars keep to z = 95.5, and the stripes start at x = 54.
local function eastbound(x: number, speed: number)
	return { x = x, z = 95.5, dirX = 1, dirZ = 0, speed = speed }
end

print("Crosswalks")

test("there are at least 4 crosswalks, all mid-block, one in the school zone", function()
	expectEqual(#TownLayout.CROSSWALKS >= 4, true)
	for _, crosswalk in TownLayout.CROSSWALKS do
		local x, z = crosswalk.at, crosswalk.along
		if crosswalk.alongX then
			x, z = crosswalk.along, crosswalk.at
		end
		expectEqual(TownLayout.segmentAt(x, z) ~= nil, true)
	end
	local school = TownLayout.CROSSWALKS[1]
	expectEqual(school.alongX, false)
	expectEqual(school.at, 0)
	expectEqual(school.along > 90 and school.along < 270, true)
end)

test("crosswalks keep clear of spawn spots and parked cars", function()
	for slot = 1, 62 do
		local pose = TownLayout.spawnPose(slot)
		for index in TownLayout.CROSSWALKS do
			local x, z = Crosswalks.point(index, 0, 0)
			local zone = Rect.inset(Rect.new(x, z, x, z), -(TownLayout.CROSSWALK_WIDTH / 2 + 8))
			expectEqual(Rect.contains(zone, pose.x, pose.z), false)
		end
	end
	for _, car in TownProps.parkedCars() do
		for index, crosswalk in TownLayout.CROSSWALKS do
			local x, z = Crosswalks.point(index, 0, 0)
			local along = if crosswalk.alongX then car.pose.x - x else car.pose.z - z
			local across = if crosswalk.alongX then car.pose.z - z else car.pose.x - x
			if math.abs(across) < TownLayout.ROAD_WIDTH then
				expectEqual(math.abs(along) >= TownProps.PARKING_CLEARANCE, true)
			end
		end
	end
end)

test("points on a crosswalk are measured across and along its street", function()
	local x, z = Crosswalks.point(3, 5, 2)
	expectEqual(x, 62)
	expectEqual(z, 95)
	x, z = Crosswalks.point(1, 5, 2)
	expectEqual(x, 5)
	expectEqual(z, 152)
end)

test("each crosswalk has two approaches that end at the near edge of the stripes", function()
	local approaches = Crosswalks.approaches()
	expectEqual(#approaches, 2 * #TownLayout.CROSSWALKS)
	expectEqual(approaches[5].line, 54)
	expectEqual(approaches[6].line, 66)
end)

test("the front of a car is 7 studs ahead of its center", function()
	local front = Crosswalks.front({ x = 0, z = 0, dirX = 2, dirZ = 0, speed = 1 })
	expectEqual(front.x, 7)
	expectEqual(Crosswalks.front({ x = 3, z = 0, dirX = 0, dirZ = 0, speed = 0 }).x, 3)
end)

test("stopping distance grows with speed", function()
	expectNear(Crosswalks.stoppingDistance(0), Crosswalks.SAFETY_MARGIN)
	expectEqual(Crosswalks.stoppingDistance(40) > Crosswalks.stoppingDistance(20), true)
end)

test("the crosswalk is clear with no cars, far cars, or a stopped car", function()
	expectEqual(Crosswalks.isClear(3, {}), true)
	expectEqual(Crosswalks.isClear(3, { eastbound(-80, 20) }), true)
	expectEqual(Crosswalks.isClear(3, { eastbound(45, 0) }), true)
end)

test("it isn't clear with a fast car close by or a car on the stripes", function()
	expectEqual(Crosswalks.isClear(3, { eastbound(20, 40) }), false)
	expectEqual(Crosswalks.isClear(3, { eastbound(58, 0) }), false)
end)

test("cars going away or on another crosswalk's street don't matter", function()
	expectEqual(Crosswalks.isClear(3, { { x = 80, z = 95.5, dirX = 1, dirZ = 0, speed = 40 } }), true)
	expectEqual(Crosswalks.isClear(1, { eastbound(20, 40) }), true)
end)

test("isNear finds cars right before or on the crosswalk", function()
	expectEqual(Crosswalks.isNear(3, eastbound(30, 10), 30), true)
	expectEqual(Crosswalks.isNear(3, eastbound(-20, 10), 30), false)
	expectEqual(Crosswalks.isNear(3, eastbound(60, 10), 30), true)
end)

TestKit.finish()
