local TestKit = require("../TestKit")
local RuleKit = require("../../src/core/RuleKit")
local SpeedRule = require("../../src/core/SpeedRule")
local TownLayout = require("../../src/core/TownLayout")
local Units = require("../../src/core/Units")

local test, expectEqual = TestKit.test, TestKit.expectEqual

-- Cars driving south (+Z) on the x = 0 street keep to the lane at x = -5.5.
local LANE_X = -TownLayout.LANE_WIDTH / 2

local function names(events: { RuleKit.Event }, into: { string })
	for _, event in events do
		if event.kind == "star" then
			table.insert(into, if event.praise then `star({event.praise})` else "star")
		else
			table.insert(into, event.tip)
		end
	end
end

-- Drives south on x = 0 from `fromZ` to `toZ` at `kmh`, checking every half second.
-- Returns everything that happened, comma separated, and the time at the end.
local function drive(
	state: SpeedRule.State,
	fromZ: number,
	toZ: number,
	kmh: number,
	startTime: number?
): (string, number)
	local speed = Units.kmhToStudsPerSecond(kmh)
	local step = speed * 0.5
	local time = startTime or 0
	local happened = {}
	local z = fromZ
	while z <= toZ do
		names(SpeedRule.update(state, { x = LANE_X, z = z, dirX = 0, dirZ = 1, speed = speed }, time), happened)
		z += step
		time += 0.5
	end
	return table.concat(happened, ","), time
end

print("SpeedRule")

test("driving a whole 50 km/h segment at 45 km/h earns a star, with praise the first time", function()
	local state = SpeedRule.newState()
	local result, time = drive(state, -85, 100, 45)
	expectEqual(result, "star(speedStar)")
	result = drive(state, 95, 280, 25, time)
	expectEqual(result, "slowZone,star")
end)

test("the star is for that segment", function()
	local state = SpeedRule.newState()
	local events = {}
	local speed = Units.kmhToStudsPerSecond(40)
	for z = -85, 85, 5 do
		for _, event in SpeedRule.update(state, { x = LANE_X, z = z, dirX = 0, dirZ = 1, speed = speed }, z) do
			table.insert(events, event)
		end
	end
	local index = TownLayout.segmentAt(LANE_X, 0)
	expectEqual((events[1] :: any).key, `segment{index}`)
end)

test("driving it at 60 km/h gives one tip and no star", function()
	expectEqual(drive(SpeedRule.newState(), -85, 100, 60), "tooFastTown")
end)

test("a moment just over the limit plus the margin gives no star, but no tip either", function()
	local state = SpeedRule.newState()
	local slow, fast = Units.kmhToStudsPerSecond(45), Units.kmhToStudsPerSecond(54)
	local happened = {}
	for z = -85, 95, 10 do
		local speed = if z == 5 then fast else slow
		names(SpeedRule.update(state, { x = LANE_X, z = z, dirX = 0, dirZ = 1, speed = speed }, z / 10), happened)
	end
	expectEqual(table.concat(happened, ","), "")
end)

test("going up to 3 km/h over the limit still earns the star", function()
	expectEqual(drive(SpeedRule.newState(), -85, 100, 52.9), "star(speedStar)")
end)

test("the school zone gives its own tip when driving too fast", function()
	expectEqual(drive(SpeedRule.newState(), 95, 280, 45), "slowZone,tooFastSchool")
end)

test("the school zone at 30 km/h or less earns a star", function()
	expectEqual(drive(SpeedRule.newState(), 95, 280, 30), "slowZone,star(speedStar)")
end)

test("starting in the middle of a segment doesn't count as driving all of it", function()
	expectEqual(drive(SpeedRule.newState(), 0, 85, 40), "")
end)

test("waiting at a red light halfway doesn't break the segment", function()
	local state = SpeedRule.newState()
	local first, time = drive(state, -85, 40, 40)
	expectEqual(first, "")
	for wait = 1, 60 do
		SpeedRule.update(state, { x = LANE_X, z = 40, dirX = 0, dirZ = 1, speed = 0 }, time + wait)
	end
	expectEqual(drive(state, 41, 100, 40, time + 61), "star(speedStar)")
end)

test("turning around halfway gives no star", function()
	local state = SpeedRule.newState()
	local _, time = drive(state, -85, 0, 40)
	local happened = {}
	local speed = Units.kmhToStudsPerSecond(40)
	for z = 0, -85, -10 do
		names(SpeedRule.update(state, { x = 5.5, z = z, dirX = 0, dirZ = -1, speed = speed }, time), happened)
		time += 0.5
	end
	expectEqual(table.concat(happened, ","), "")
end)

test("a car that jumps (Reset car) starts over", function()
	local state = SpeedRule.newState()
	local _, time = drive(state, -85, -20, 40)
	-- Jump ahead past the end of the segment: no star for a segment that wasn't driven.
	expectEqual(drive(state, 60, 85, 40, time), "")
end)

test("a car that doesn't face along the street can't earn the star for it", function()
	local state = SpeedRule.newState()
	local events = SpeedRule.update(state, { x = LANE_X, z = -70, dirX = 0, dirZ = 0, speed = 0 }, 0)
	expectEqual(#events, 0)
	expectEqual(state.fromStart, false)
end)

TestKit.finish()
