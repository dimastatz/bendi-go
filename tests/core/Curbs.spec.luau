local TestKit = require("../TestKit")
local Curbs = require("../../src/core/Curbs")
local TownLayout = require("../../src/core/TownLayout")
local TownProps = require("../../src/core/TownProps")

local test, expectEqual, expectNear = TestKit.test, TestKit.expectEqual, TestKit.expectNear

print("Curbs")

-- The runs on one side of one segment, in order.
local function runsFor(segment: TownLayout.Street, side: number): { Curbs.Run }
	local result = {}
	for _, run in Curbs.runs() do
		if run.segment == segment and run.side == side then
			table.insert(result, run)
		end
	end
	return result
end

local function findSegment(alongX: boolean, at: number, from: number): TownLayout.Street
	for _, segment in TownLayout.segments() do
		if segment.alongX == alongX and segment.at == at and segment.from == from then
			return segment
		end
	end
	error("no such segment")
end

test("both sides of every segment are covered from end to end with no gaps", function()
	for _, segment in TownLayout.segments() do
		local first, last = TownLayout.segmentEnds(segment)
		for _, side in { -1, 1 } do
			local runs = runsFor(segment, side)
			expectEqual(#runs > 0, true)
			expectNear(runs[1].from, first)
			expectNear(runs[#runs].to, last)
			for i, run in runs do
				expectEqual(run.to > run.from, true)
				if i > 1 then
					expectNear(run.from, runs[i - 1].to)
					-- Neighboring runs always have different paint, or they would be one run.
					expectEqual(run.paint ~= runs[i - 1].paint, true)
				end
			end
		end
	end
end)

test("curbs near every crossing are red and white", function()
	for _, segment in TownLayout.segments() do
		local runs = runsFor(segment, 1)
		expectEqual(runs[1].paint, "red")
		expectEqual(runs[#runs].paint, "red")
		expectEqual(runs[1].to - runs[1].from >= TownProps.PARKING_CLEARANCE, true)
	end
end)

test("curbs at crosswalks are red and white", function()
	for _, crosswalk in TownLayout.CROSSWALKS do
		for _, run in Curbs.runs() do
			local segment = run.segment
			local onStreet = segment.alongX == crosswalk.alongX and segment.at == crosswalk.at
			if onStreet and run.from <= crosswalk.along and run.to >= crosswalk.along then
				expectEqual(run.paint, "red")
			end
		end
	end
end)

test("a crosswalk near a crossing joins its red curb into one run", function()
	-- The crosswalk at along = -120 on z = -90 is 60 studs from the crossing at x = -180.
	local runs = runsFor(findSegment(true, -90, -180), 1)
	expectEqual(runs[1].paint, "red")
	expectNear(runs[1].to, -120 + TownProps.PARKING_CLEARANCE)
end)

test("the middle streets have paid parking, and other streets have free parking", function()
	local paid = runsFor(findSegment(true, 90, -360), -1)
	expectEqual(#paid, 3)
	expectEqual(paid[2].paint, "blue")
	local free = runsFor(findSegment(false, -360, -270), 1)
	expectEqual(#free, 3)
	expectEqual(free[2].paint, "plain")
end)

test("parked cars only stand along curbs where parking is allowed", function()
	local offset = TownLayout.LANE_WIDTH + TownLayout.PARKING_WIDTH / 2
	for _, car in TownProps.parkedCars() do
		local found = false
		for _, run in Curbs.runs() do
			local segment = run.segment
			local along, across = car.pose.z, car.pose.x
			if segment.alongX then
				along, across = car.pose.x, car.pose.z
			end
			local onSide = math.abs(across - (segment.at + run.side * offset)) < 0.01
			if segment.alongX == (car.pose.dirX ~= 0) and onSide and along >= run.from and along <= run.to then
				found = true
				expectEqual(run.paint ~= "red", true)
			end
		end
		expectEqual(found, true)
	end
end)

TestKit.finish()
