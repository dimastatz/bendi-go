local TestKit = require("../TestKit")
local Rect = require("../../src/core/Rect")
local TownLayout = require("../../src/core/TownLayout")

local test, expectEqual, expectNear = TestKit.test, TestKit.expectEqual, TestKit.expectNear

local HALF_LANE = TownLayout.LANE_WIDTH / 2

local function expectPose(pose: TownLayout.Pose, x: number, z: number, dirX: number, dirZ: number)
	expectNear(pose.x, x)
	expectNear(pose.z, z)
	expectNear(pose.dirX, dirX)
	expectNear(pose.dirZ, dirZ)
end

print("TownLayout")

test("roads have two lanes and two parking strips", function()
	expectEqual(TownLayout.ROAD_WIDTH, 2 * TownLayout.LANE_WIDTH + 2 * TownLayout.PARKING_WIDTH)
end)

test("the town has at least 4 four-way crossings besides the roundabout space", function()
	local crossings = TownLayout.fourWayCrossings()
	expectEqual(#crossings >= 4, true)
	for _, crossing in crossings do
		expectEqual(Rect.contains(TownLayout.ROUNDABOUT_SPACE, crossing.x, crossing.z), false)
	end
end)

test("the town has at least 4 blocks inside the ring road, all inside the map", function()
	local lots = TownLayout.lots()
	expectEqual(#lots - 1 >= 4, true)
	for _, lot in lots do
		for _, piece in lot.pieces do
			expectEqual(Rect.contains(TownLayout.BOUNDS, piece.minX, piece.minZ), true)
			expectEqual(Rect.contains(TownLayout.BOUNDS, piece.maxX, piece.maxZ), true)
		end
	end
end)

test("the roundabout space is on a crossing and nothing is built on it", function()
	local space = TownLayout.ROUNDABOUT_SPACE
	expectEqual(table.find(TownLayout.STREETS_X, TownLayout.ROUNDABOUT.x) ~= nil, true)
	expectEqual(table.find(TownLayout.STREETS_Z, TownLayout.ROUNDABOUT.z) ~= nil, true)
	for _, lot in TownLayout.lots() do
		for _, piece in lot.pieces do
			expectEqual(Rect.overlaps(piece, space), false)
		end
		for _, inner in lot.inner do
			expectEqual(Rect.overlaps(inner, space), false)
		end
	end
	expectEqual(TownLayout.isOnRoad(space.minX + 1, space.minZ + 1), true)
end)

test("streets reach across the whole town and segments join neighboring crossings", function()
	local streets = TownLayout.streets()
	expectEqual(#streets, #TownLayout.STREETS_X + #TownLayout.STREETS_Z)
	for _, street in streets do
		local crossing = if street.alongX then TownLayout.STREETS_X else TownLayout.STREETS_Z
		expectEqual(street.from, crossing[1])
		expectEqual(street.to, crossing[#crossing])
	end
	local segments = TownLayout.segments()
	local expected = #TownLayout.STREETS_Z * (#TownLayout.STREETS_X - 1)
		+ #TownLayout.STREETS_X * (#TownLayout.STREETS_Z - 1)
	expectEqual(#segments, expected)
end)

test("street centers are road and blocks, sidewalks, and the outside are not", function()
	expectEqual(TownLayout.isOnRoad(0, 0), true)
	expectEqual(TownLayout.isOnRoad(-90, 0), false)
	local bounds = TownLayout.BOUNDS
	expectEqual(TownLayout.isOnRoad(bounds.maxX + 1, 0), false)
	-- The sidewalk starts right at the edge of the road.
	expectEqual(TownLayout.isOnRoad(TownLayout.ROAD_WIDTH / 2 - 0.5, 0), true)
	expectEqual(TownLayout.isOnRoad(TownLayout.ROAD_WIDTH / 2 + 0.5, 0), false)
end)

test("lane poses keep to the right of the center line", function()
	local alongX = { alongX = true, at = 90, from = -360, to = 360 }
	expectPose(TownLayout.lanePose(alongX, 10, 1, HALF_LANE), 10, 90 + HALF_LANE, 1, 0)
	expectPose(TownLayout.lanePose(alongX, 10, -1, HALF_LANE), 10, 90 - HALF_LANE, -1, 0)
	local alongZ = { alongX = false, at = 0, from = -270, to = 270 }
	expectPose(TownLayout.lanePose(alongZ, 10, 1, HALF_LANE), -HALF_LANE, 10, 0, 1)
	expectPose(TownLayout.lanePose(alongZ, 10, -1, HALF_LANE), HALF_LANE, 10, 0, -1)
end)

test("the first spawn slots are near the town center", function()
	local pose = TownLayout.spawnPose(1)
	expectEqual(math.abs(pose.x) + math.abs(pose.z) <= HALF_LANE + 1e-9, true)
end)

test("spawn slots are on the road, apart from each other, and wrap around when they run out", function()
	local seen = {}
	local count = 0
	for slot = 1, 200 do
		local pose = TownLayout.spawnPose(slot)
		expectEqual(TownLayout.isOnRoad(pose.x, pose.z), true)
		local key = `{pose.x},{pose.z}`
		if seen[key] then
			-- Once spots run out, slots start over from the first one.
			expectEqual(seen[key], slot - count)
			break
		end
		count += 1
		seen[key] = slot
	end
	expectEqual(count >= 50, true)
end)

test("reset puts a car on the nearest street, in the lane for the way it faces", function()
	-- Inside the block east of the x = 0 street, facing north (-Z).
	expectPose(TownLayout.resetPose(30, 0, 0, -1), HALF_LANE, 0, 0, -1)
	-- Same place, facing south (+Z), goes in the other lane.
	expectPose(TownLayout.resetPose(30, 0, 0.1, 1), -HALF_LANE, 0, 0, 1)
end)

test("reset on an east-west street follows the car's heading", function()
	expectPose(TownLayout.resetPose(-90, 80, 1, 0.2), -90, 90 + HALF_LANE, 1, 0)
	expectPose(TownLayout.resetPose(-90, 80, -1, 0), -90, 90 - HALF_LANE, -1, 0)
end)

test("reset in a crossing keeps the street the car faces along", function()
	-- A few studs into the crossing at (0, 90), facing east: closer to x = 0, but facing along z = 90.
	expectPose(TownLayout.resetPose(3, 82, 1, 0), 3, 90 + HALF_LANE, 1, 0)
end)

test("reset outside the map comes back to the end of the nearest street", function()
	local pose = TownLayout.resetPose(0, 1000, 0, 1)
	expectPose(pose, -HALF_LANE, 270, 0, 1)
	expectEqual(TownLayout.isOnRoad(pose.x, pose.z), true)
end)

test("reset still works when the car points straight up", function()
	local pose = TownLayout.resetPose(30, 0, 0, 0)
	expectEqual(TownLayout.isOnRoad(pose.x, pose.z), true)
	expectNear(math.abs(pose.dirX) + math.abs(pose.dirZ), 1)
end)

TestKit.finish()
