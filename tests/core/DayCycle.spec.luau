local TestKit = require("../TestKit")
local DayCycle = require("../../src/core/DayCycle")

local test, expectEqual, expectNear = TestKit.test, TestKit.expectEqual, TestKit.expectNear

local CYCLE = DayCycle.CYCLE_SECONDS

print("DayCycle")

test("a cycle starts in the morning and comes back to the same time", function()
	expectNear(DayCycle.clockAt(0), 7)
	expectNear(DayCycle.clockAt(CYCLE), 7)
	expectNear(DayCycle.clockAt(5 * CYCLE + 30), DayCycle.clockAt(30))
end)

test("the clock follows the keyframes and wraps past midnight", function()
	expectNear(DayCycle.clockAt(0.55 * CYCLE), 17, 1e-6)
	expectNear(DayCycle.clockAt(0.65 * CYCLE), 19.5, 1e-6)
	expectNear(DayCycle.clockAt(0.85 * CYCLE), 4.5, 1e-6)
	-- Halfway through the night is midnight.
	expectNear(DayCycle.clockAt(0.75 * CYCLE), 0, 1e-6)
end)

test("the clock always moves forward and stays between 0 and 24", function()
	local previous = DayCycle.clockAt(0)
	for second = 1, CYCLE - 1 do
		local hour = DayCycle.clockAt(second)
		expectEqual(hour >= 0 and hour < 24, true)
		local step = (hour - previous) % 24
		expectEqual(step > 0 and step < 0.1, true)
		previous = hour
	end
end)

test("most of the cycle is daytime", function()
	local light = 0
	for second = 0, CYCLE - 1 do
		if not DayCycle.lightsOn(DayCycle.clockAt(second)) then
			light += 1
		end
	end
	expectEqual(light / CYCLE > 0.6, true)
end)

test("darkness is 0 in the day, 1 at night, and in between at dusk and dawn", function()
	expectEqual(DayCycle.darkness(12), 0)
	expectEqual(DayCycle.darkness(7), 0)
	expectEqual(DayCycle.darkness(22), 1)
	expectEqual(DayCycle.darkness(2), 1)
	expectEqual(DayCycle.darkness(19.5), 1)
	expectNear(DayCycle.darkness(18.5), 0.5)
	expectNear(DayCycle.darkness(5.5), 0.5)
end)

test("lights turn on as it gets dark", function()
	expectEqual(DayCycle.lightsOn(12), false)
	expectEqual(DayCycle.lightsOn(17.6), false)
	expectEqual(DayCycle.lightsOn(18.5), true)
	expectEqual(DayCycle.lightsOn(23), true)
	expectEqual(DayCycle.lightsOn(6.4), false)
end)

TestKit.finish()
