local TestKit = require("../TestKit")
local CrosswalkRule = require("../../src/core/CrosswalkRule")
local RuleKit = require("../../src/core/RuleKit")
local TownLayout = require("../../src/core/TownLayout")

local test, expectEqual = TestKit.test, TestKit.expectEqual

-- Crosswalk 3 is on the z = 90 street at x = 60. Eastbound cars keep to z = 95.5, and the stripes start at x = 54,
-- so a car's front reaches them when its center is at x = 47.
local IDLE = { waiting = false, crossing = false }
local WAITING = { waiting = true, crossing = false }
local CROSSING = { waiting = false, crossing = true }

local function world(status)
	local crosswalks = {}
	for index in TownLayout.CROSSWALKS do
		crosswalks[index] = if index == 3 then status else IDLE
	end
	return { crosswalks = crosswalks }
end

-- Runs the steps { x, speed, status } and returns what happened, comma separated.
local function drive(steps, state: CrosswalkRule.State?): string
	local rule = state or CrosswalkRule.newState()
	local happened = {}
	for index, step in steps do
		local car = { x = step[1], z = 95.5, dirX = 1, dirZ = 0, speed = step[2] }
		for _, event in CrosswalkRule.update(rule, car, index, world(step[3])) do
			table.insert(happened, if event.kind == "star" then `star:{event.key}:{event.praise}` else event.tip)
		end
	end
	return table.concat(happened, ",")
end

local function experienced(): CrosswalkRule.State
	local state = CrosswalkRule.newState()
	state.seen = true
	return state
end

print("CrosswalkRule")

test("stopping for someone and waiting until they've crossed earns a star", function()
	local result = drive({
		{ 0, 10, WAITING },
		{ 40, 0, WAITING },
		{ 40, 0, CROSSING },
		{ 40, 0, CROSSING },
		{ 40, 0, IDLE },
		{ 70, 10, IDLE },
	}, experienced())
	expectEqual(result, "star:crosswalk3:crosswalkPraise")
end)

test("Bendi explains the rule the first time someone is waiting", function()
	local state = CrosswalkRule.newState()
	expectEqual(drive({ { 0, 10, WAITING } }, state), "pedestrianWaiting")
	expectEqual(drive({ { 0, 10, WAITING } }, state), "")
end)

test("driving onto the stripes while someone is crossing gets a tip and no star", function()
	expectEqual(drive({ { 30, 10, CROSSING }, { 50, 10, CROSSING } }, experienced()), "didntStopForPedestrian")
end)

test("stopping, then going while they're still crossing, gets the tip", function()
	local result = drive({ { 40, 0, CROSSING }, { 44, 3, CROSSING }, { 48, 3, CROSSING } }, experienced())
	expectEqual(result, "didntStopForPedestrian")
end)

test("driving past someone still waiting on the sidewalk is not a mistake", function()
	expectEqual(drive({ { 30, 20, WAITING }, { 50, 20, WAITING } }, experienced()), "")
end)

test("stopping when nobody is there gives no star", function()
	expectEqual(drive({ { 40, 0, IDLE }, { 40, 0, IDLE }, { 60, 10, IDLE } }, experienced()), "")
end)

test("the other direction has its own approach", function()
	local state = experienced()
	local happened = {}
	local steps = { { 120, 0, WAITING }, { 120, 0, CROSSING }, { 120, 0, IDLE } }
	for index, step in steps do
		local car = { x = step[1], z = 84.5, dirX = -1, dirZ = 0, speed = step[2] }
		for _, event in CrosswalkRule.update(state, car, index, world(step[3])) do
			table.insert(happened, event.kind)
		end
	end
	expectEqual(table.concat(happened, ","), "star")
end)

test("a car that jumps past the crosswalk doesn't get a tip", function()
	expectEqual(drive({ { 20, 0, CROSSING }, { 80, 0, CROSSING } }, experienced()), "")
end)

test("without crosswalk information nothing happens", function()
	local state = experienced()
	local car: RuleKit.Car = { x = 40, z = 95.5, dirX = 1, dirZ = 0, speed = 0 }
	expectEqual(#CrosswalkRule.update(state, car, 0, nil), 0)
	car = { x = 50, z = 95.5, dirX = 1, dirZ = 0, speed = 5 }
	expectEqual(#CrosswalkRule.update(state, car, 1, nil), 0)
end)

test("backing away from the crosswalk forgets the wait", function()
	local result = drive({
		{ 40, 0, WAITING },
		{ 10, 5, WAITING },
		{ -25, 5, WAITING },
		{ 30, 5, IDLE },
	}, experienced())
	expectEqual(result, "")
end)

TestKit.finish()
