local TestKit = require("../TestKit")
local Config = require("../../src/core/TrafficLightConfig")
local TrafficLight = require("../../src/core/TrafficLight")

local test, expectEqual = TestKit.test, TestKit.expectEqual

print("TrafficLight")

test("a cycle is two turns of red-yellow, green, flashing green, yellow, and all red", function()
	local turn = Config.RED_YELLOW + Config.GREEN + Config.FLASHING_GREEN + Config.YELLOW + Config.ALL_RED
	expectEqual(TrafficLight.cycleLength(), 2 * turn)
end)

test("timing matches the PRD", function()
	expectEqual(Config.GREEN, 15)
	expectEqual(Config.FLASHING_GREEN, 3)
	expectEqual(Config.YELLOW, 3)
	expectEqual(Config.RED_YELLOW, 2)
end)

test("each light goes through all five steps in the Israeli order", function()
	for _, alongX in { true, false } do
		local order = {}
		for tenth = 0, TrafficLight.cycleLength() * 10 * 2 do
			local state = TrafficLight.stateAt(tenth / 10, alongX, 7)
			if order[#order] ~= state then
				table.insert(order, state)
			end
		end
		local text = table.concat(order, " ")
		local cycle = "redYellow green flashingGreen yellow red"
		if not string.find(text, cycle, 1, true) then
			error(`unexpected order: {text}`)
		end
	end
end)

test("crossing directions are never green at the same time", function()
	for _, offset in { 0, 12, 33.3 } do
		for tenth = 0, TrafficLight.cycleLength() * 10 do
			local time = tenth / 10
			local eastWest = TrafficLight.stateAt(time, true, offset)
			local northSouth = TrafficLight.stateAt(time, false, offset)
			if TrafficLight.isGo(eastWest) and TrafficLight.isGo(northSouth) then
				error(`both sides go at {time}`)
			end
			if not TrafficLight.isStop(eastWest) and not TrafficLight.isStop(northSouth) then
				error(`neither side is stopped at {time}`)
			end
		end
	end
end)

test("stateAt reports how long the step has been showing", function()
	local state, elapsed = TrafficLight.stateAt(Config.RED_YELLOW + 4, true, 0)
	expectEqual(state, "green")
	expectEqual(elapsed, 4)
end)

test("an offset shifts the cycle", function()
	expectEqual(TrafficLight.stateAt(0, true, Config.RED_YELLOW), "green")
	expectEqual(TrafficLight.stateAt(TrafficLight.cycleLength(), true, 0), "redYellow")
end)

test("lamps match each step", function()
	local function lampsFor(target: string)
		for tenth = 0, TrafficLight.cycleLength() * 10 do
			local time = tenth / 10
			local state, elapsed = TrafficLight.stateAt(time, true, 0)
			if state == target and elapsed < Config.FLASH_INTERVAL then
				return TrafficLight.lampsAt(time, true, 0)
			end
		end
		error(`never {target}`)
	end
	local function expectLamps(state: string, red: boolean, yellow: boolean, green: boolean)
		local lamps = lampsFor(state)
		expectEqual(lamps.red, red)
		expectEqual(lamps.yellow, yellow)
		expectEqual(lamps.green, green)
	end
	expectLamps("red", true, false, false)
	expectLamps("redYellow", true, true, false)
	expectLamps("green", false, false, true)
	expectLamps("flashingGreen", false, false, true)
	expectLamps("yellow", false, true, false)
end)

test("flashing green blinks on and off", function()
	local start = Config.RED_YELLOW + Config.GREEN
	expectEqual(TrafficLight.lampsAt(start + 0.1, true, 0).green, true)
	expectEqual(TrafficLight.lampsAt(start + Config.FLASH_INTERVAL + 0.1, true, 0).green, false)
	expectEqual(TrafficLight.lampsAt(start + 2 * Config.FLASH_INTERVAL + 0.1, true, 0).green, true)
end)

TestKit.finish()
