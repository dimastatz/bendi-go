local TestKit = require("../TestKit")
local Rect = require("../../src/core/Rect")
local TownLayout = require("../../src/core/TownLayout")
local TownProps = require("../../src/core/TownProps")

local test, expectEqual, expectNear = TestKit.test, TestKit.expectEqual, TestKit.expectNear

local function insideAny(rects: { Rect.Rect }, inner: Rect.Rect): boolean
	for _, rect in rects do
		if
			inner.minX >= rect.minX
			and inner.maxX <= rect.maxX
			and inner.minZ >= rect.minZ
			and inner.maxZ <= rect.maxZ
		then
			return true
		end
	end
	return false
end

print("TownProps")

test("hash is between 0 and 1008 and the same every time", function()
	for _, point in { { 0, 0 }, { -360, 270 }, { 12.5, -7.25 } } do
		local hash = TownProps.hash(point[1], point[2])
		expectEqual(hash >= 0 and hash <= 1008, true)
		expectEqual(TownProps.hash(point[1], point[2]), hash)
	end
end)

test("buildings stand inside the land within the sidewalks and don't overlap", function()
	local all = {}
	for _, lot in TownLayout.lots() do
		local buildings = TownProps.forLot(lot)
		for _, building in buildings do
			expectEqual(insideAny(lot.inner, building.rect), true)
			expectEqual(Rect.overlaps(building.rect, TownLayout.ROUNDABOUT_SPACE), false)
			expectEqual(building.floors >= TownProps.MIN_FLOORS and building.floors <= TownProps.MAX_FLOORS, true)
			expectEqual(building.style >= 1 and building.style <= TownProps.BUILDING_STYLES, true)
			for _, other in all do
				expectEqual(Rect.overlaps(building.rect, other), false)
			end
			table.insert(all, building.rect)
		end
	end
	expectEqual(#all >= 40, true)
end)

test("trees grow on sidewalks and gardens, never on the road", function()
	local count = 0
	for _, lot in TownLayout.lots() do
		local _, trees = TownProps.forLot(lot)
		for _, tree in trees do
			count += 1
			expectEqual(TownLayout.isOnRoad(tree.x, tree.z), false)
			expectEqual(tree.kind == "palm" or tree.kind == "round", true)
		end
	end
	expectEqual(count >= 100, true)
end)

test("parked cars are in the parking strip, facing the way traffic goes on that side", function()
	local cars = TownProps.parkedCars()
	expectEqual(#cars >= 10, true)
	local offset = TownLayout.LANE_WIDTH + TownLayout.PARKING_WIDTH / 2
	for _, car in cars do
		local pose = car.pose
		expectEqual(car.style >= 1 and car.style <= TownProps.CAR_STYLES, true)
		expectEqual(TownLayout.isOnRoad(pose.x, pose.z), true)
		expectEqual(Rect.contains(TownLayout.ROUNDABOUT_SPACE, pose.x, pose.z), false)
		-- Driving the way the car faces, the street's center line is on the left.
		local street = if pose.dirX ~= 0
			then table.find(TownLayout.STREETS_Z, pose.z - pose.dirX * offset)
			else table.find(TownLayout.STREETS_X, pose.x + pose.dirZ * offset)
		expectEqual(street ~= nil, true)
	end
end)

test("parked cars keep 12 m away from crossings", function()
	local clearance = TownLayout.ROAD_WIDTH / 2 + TownProps.PARKING_CLEARANCE
	for _, car in TownProps.parkedCars() do
		local pose = car.pose
		local along = if pose.dirX ~= 0 then pose.x else pose.z
		local crossings = if pose.dirX ~= 0 then TownLayout.STREETS_X else TownLayout.STREETS_Z
		for _, crossing in crossings do
			expectEqual(math.abs(along - crossing) >= clearance, true)
		end
	end
end)

test("lots next to the roundabout space keep their trees out of it", function()
	for _, lot in TownLayout.lots() do
		local _, trees = TownProps.forLot(lot)
		for _, tree in trees do
			expectEqual(Rect.contains(TownLayout.ROUNDABOUT_SPACE, tree.x, tree.z), false)
		end
	end
	expectNear(TownLayout.ROUNDABOUT.halfSize, Rect.width(TownLayout.ROUNDABOUT_SPACE) / 2)
end)

-- Every street lamp in town, with the trees of its lot.
local function allLamps(): { { lamp: TownProps.Lamp, trees: { TownProps.Tree } } }
	local result = {}
	for _, lot in TownLayout.lots() do
		local _, trees = TownProps.forLot(lot)
		for _, lamp in TownProps.lampsForLot(lot) do
			table.insert(result, { lamp = lamp, trees = trees })
		end
	end
	return result
end

test("street lamps stand on the sidewalk next to the curb, reaching over the road", function()
	local lamps = allLamps()
	expectEqual(#lamps >= 60, true)
	for _, entry in lamps do
		local lamp = entry.lamp
		expectEqual(math.abs(lamp.dirX) + math.abs(lamp.dirZ), 1)
		expectEqual(TownLayout.isOnRoad(lamp.x, lamp.z), false)
		-- Just past the curb is the road, and just behind the lamp is still sidewalk.
		local reach = TownProps.LAMP_CURB_OFFSET + 0.5
		expectEqual(TownLayout.isOnRoad(lamp.x + lamp.dirX * reach, lamp.z + lamp.dirZ * reach), true)
		expectEqual(TownLayout.isOnRoad(lamp.x - lamp.dirX, lamp.z - lamp.dirZ), false)
	end
end)

test("street lamps stay clear of trees, crosswalks, and the roundabout", function()
	for _, entry in allLamps() do
		local lamp = entry.lamp
		for _, tree in entry.trees do
			local distance = math.sqrt((lamp.x - tree.x) ^ 2 + (lamp.z - tree.z) ^ 2)
			expectEqual(distance >= 10, true)
		end
		for _, crosswalk in TownLayout.CROSSWALKS do
			local x, z = crosswalk.at, crosswalk.along
			if crosswalk.alongX then
				x, z = crosswalk.along, crosswalk.at
			end
			expectEqual(math.sqrt((lamp.x - x) ^ 2 + (lamp.z - z) ^ 2) >= TownLayout.ROAD_WIDTH / 2, true)
		end
		expectEqual(Rect.contains(Rect.inset(TownLayout.ROUNDABOUT_SPACE, -10), lamp.x, lamp.z), false)
	end
end)

test("both sides of a street get lamps, including the ring road", function()
	local sides = { minus = 0, plus = 0, ring = 0 }
	for _, entry in allLamps() do
		local lamp = entry.lamp
		if lamp.dirX < 0 or lamp.dirZ < 0 then
			sides.minus += 1
		else
			sides.plus += 1
		end
		if lamp.x < TownLayout.STREETS_X[1] or lamp.x > TownLayout.STREETS_X[#TownLayout.STREETS_X] then
			sides.ring += 1
		end
	end
	expectEqual(sides.minus > 10 and sides.plus > 10 and sides.ring > 2, true)
end)

test("the school block is left for the school", function()
	for _, lot in TownLayout.lots() do
		local buildings = TownProps.forLot(lot)
		for _, building in buildings do
			expectEqual(Rect.overlaps(building.rect, TownLayout.SCHOOL_BLOCK), false)
		end
	end
end)

TestKit.finish()
