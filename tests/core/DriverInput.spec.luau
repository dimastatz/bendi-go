local TestKit = require("../TestKit")
local DriverInput = require("../../src/core/DriverInput")

local test, expectEqual = TestKit.test, TestKit.expectEqual

print("DriverInput")

test("one control passes through unchanged", function()
	local input = DriverInput.combine({ { throttle = 0.5, steer = -0.25, brake = false } })
	expectEqual(input.throttle, 0.5)
	expectEqual(input.steer, -0.25)
	expectEqual(input.brake, false)
end)

test("no controls means no input", function()
	local input = DriverInput.combine({})
	expectEqual(input.throttle, 0)
	expectEqual(input.steer, 0)
	expectEqual(input.brake, false)
end)

test("controls add up and are clamped", function()
	local input = DriverInput.combine({
		{ throttle = 1, steer = 1, brake = false },
		{ throttle = 1, steer = 0.5, brake = false },
	})
	expectEqual(input.throttle, 1)
	expectEqual(input.steer, 1)
end)

test("controls pushing opposite ways cancel out", function()
	local input = DriverInput.combine({
		{ throttle = 1, steer = -1, brake = false },
		{ throttle = -1, steer = 1, brake = false },
	})
	expectEqual(input.throttle, 0)
	expectEqual(input.steer, 0)
end)

test("any control can brake", function()
	local input = DriverInput.combine({
		{ throttle = 1, steer = 0, brake = false },
		{ throttle = 0, steer = 0, brake = true },
	})
	expectEqual(input.brake, true)
end)

TestKit.finish()
