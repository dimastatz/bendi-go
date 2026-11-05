local TestKit = require("../TestKit")
local Config = require("../../src/core/TrafficLightConfig")
local RedLightRule = require("../../src/core/RedLightRule")
local RuleKit = require("../../src/core/RuleKit")

local test, expectEqual = TestKit.test, TestKit.expectEqual

-- The first light is at (-180, -90) with no offset. East-west traffic there sees:
-- red and yellow 0-2 s, green 2-17 s, flashing green 17-20 s, yellow 20-23 s, red 23-50 s, then it repeats.
local RED, RED_YELLOW, GREEN, FLASHING, YELLOW = 30, 1, 5, 18, 21
local CYCLE = 50
local LANE_Z = -90 + 5.5 -- the right-hand lane for cars driving east (+X)
local STOP_LINE = -180 - Config.STOP_LINE_DISTANCE

-- A car driving east on the z = -90 street.
local function eastbound(x: number, speed: number): RuleKit.Car
	return { x = x, z = LANE_Z, dirX = 1, dirZ = 0, speed = speed }
end

local function kinds(events: { RuleKit.Event }): string
	local names = {}
	for _, event in events do
		table.insert(names, if event.kind == "star" then "star" else event.tip)
	end
	return table.concat(names, ",")
end

-- Runs the steps { x, speed, time } in order and returns everything that happened, comma separated.
local function drive(steps: { { number } }, state: RedLightRule.State?): string
	local rule = state or RedLightRule.newState()
	local all = {}
	for _, step in steps do
		local text = kinds(RedLightRule.update(rule, eastbound(step[1], step[2]), step[3]))
		if text ~= "" then
			table.insert(all, text)
		end
	end
	return table.concat(all, ",")
end

-- A state where Bendi has already explained flashing green and red and yellow, so only rule events show up.
local function experienced(): RedLightRule.State
	local state = RedLightRule.newState()
	state.seen.flashingGreen = true
	state.seen.redYellow = true
	return state
end

print("RedLightRule")

test("every light crossing has four approaches, each with its stop line before the crossing", function()
	local approaches = RedLightRule.approaches()
	expectEqual(#approaches, 4 * #Config.CROSSINGS)
	for _, approach in approaches do
		local crossing = Config.CROSSINGS[approach.crossing]
		local center = if approach.alongX then crossing.x else crossing.z
		expectEqual((center - approach.line) * approach.direction, Config.STOP_LINE_DISTANCE)
	end
end)

test("a car in the right-hand lane heading toward the crossing is in an approach", function()
	local approach = RedLightRule.findApproach(eastbound(STOP_LINE - 20, 10))
	expectEqual(approach ~= nil, true)
	local found = approach :: RedLightRule.LightApproach
	expectEqual(found.crossing, 1)
	expectEqual(found.alongX, true)
	expectEqual(found.direction, 1)
end)

test("approaches along Z work too", function()
	-- Driving north (-Z) toward z = -90, in the right-hand lane (+X side).
	local car = { x = -180 + 5.5, z = -90 + Config.STOP_LINE_DISTANCE + 20, dirX = 0, dirZ = -1, speed = 10 }
	local approach = RedLightRule.findApproach(car) :: RedLightRule.LightApproach
	expectEqual(approach.alongX, false)
	expectEqual(approach.direction, -1)
end)

test("cars in the other lane, facing away, too far back, or pointing straight up are not in an approach", function()
	expectEqual(RedLightRule.findApproach({ x = STOP_LINE - 20, z = -95.5, dirX = 1, dirZ = 0, speed = 10 }), nil)
	expectEqual(RedLightRule.findApproach({ x = STOP_LINE - 20, z = LANE_Z, dirX = -1, dirZ = 0, speed = 10 }), nil)
	expectEqual(RedLightRule.findApproach(eastbound(STOP_LINE - RedLightRule.APPROACH_LENGTH - 1, 10)), nil)
	expectEqual(RedLightRule.findApproach({ x = STOP_LINE - 20, z = LANE_Z, dirX = 0, dirZ = 0, speed = 10 }), nil)
end)

test("stopping at red and waiting for green earns exactly one star", function()
	local result = drive({
		{ STOP_LINE - 30, 10, RED - 2 },
		{ STOP_LINE - 4, 0, RED },
		{ STOP_LINE - 4, 0, CYCLE + RED_YELLOW },
		{ STOP_LINE - 4, 0, CYCLE + GREEN },
		{ STOP_LINE + 6, 10, CYCLE + GREEN + 1 },
	}, experienced())
	expectEqual(result, "star")
end)

test("the star is for that light, with praise", function()
	local state = experienced()
	RedLightRule.update(state, eastbound(STOP_LINE - 4, 0), RED)
	local events = RedLightRule.update(state, eastbound(STOP_LINE - 4, 0), CYCLE + GREEN)
	local event = events[1] :: any
	expectEqual(event.kind, "star")
	expectEqual(event.key, "light1")
	expectEqual(event.praise, "stoppedAtRed")
end)

test("driving through a red light gives a tip and no star", function()
	expectEqual(drive({ { STOP_LINE - 20, 20, RED }, { STOP_LINE + 5, 20, RED + 1 } }, experienced()), "ranRed")
end)

test("going on red and yellow is running the red too", function()
	expectEqual(
		drive({ { STOP_LINE - 20, 20, RED_YELLOW - 0.5 }, { STOP_LINE + 5, 20, RED_YELLOW } }, experienced()),
		"ranRed"
	)
end)

test("stopping at red and then going before green is still running the red", function()
	local result = drive({
		{ STOP_LINE - 4, 0, RED },
		{ STOP_LINE + 5, 10, RED + 3 },
		{ STOP_LINE + 15, 10, CYCLE + GREEN },
	}, experienced())
	expectEqual(result, "ranRed")
end)

test("crossing on yellow or green is fine", function()
	expectEqual(drive({ { STOP_LINE - 20, 20, YELLOW }, { STOP_LINE + 5, 20, YELLOW + 1 } }, experienced()), "")
	expectEqual(drive({ { STOP_LINE - 20, 20, GREEN }, { STOP_LINE + 5, 20, GREEN + 1 } }, experienced()), "")
end)

test("waiting through a second red during the same approach gives no second star", function()
	local result = drive({
		{ STOP_LINE - 4, 0, RED },
		{ STOP_LINE - 4, 0, CYCLE + GREEN },
		{ STOP_LINE - 4, 0, CYCLE + RED },
		{ STOP_LINE - 4, 0, 2 * CYCLE + GREEN },
	}, experienced())
	expectEqual(result, "star")
end)

test("backing out of the approach forgets the wait", function()
	local result = drive({
		{ STOP_LINE - 4, 0, RED },
		{ STOP_LINE - 35, 5, RED + 5 },
		{ STOP_LINE - 70, 5, RED + 10 },
		{ STOP_LINE - 30, 5, CYCLE + GREEN },
	}, experienced())
	expectEqual(result, "")
end)

test("a car that jumps (Reset car) past the line doesn't count as running the red", function()
	expectEqual(drive({ { STOP_LINE - 20, 0, RED }, { STOP_LINE + 45, 0, RED + 1 } }, experienced()), "")
end)

test("Bendi explains flashing green and red and yellow only the first time", function()
	local state = RedLightRule.newState()
	expectEqual(
		drive({ { STOP_LINE - 30, 10, FLASHING }, { STOP_LINE - 25, 10, FLASHING + 0.5 } }, state),
		"flashingGreen"
	)
	expectEqual(drive({ { STOP_LINE - 30, 5, CYCLE + RED_YELLOW } }, state), "redYellow")
	expectEqual(drive({ { STOP_LINE - 30, 5, 2 * CYCLE + FLASHING } }, state), "")
	expectEqual(drive({ { STOP_LINE - 30, 5, 2 * CYCLE + RED_YELLOW } }, state), "")
end)

test("lights only matter near them", function()
	expectEqual(drive({ { 50, 20, FLASHING }, { 60, 20, RED } }), "")
end)

TestKit.finish()
