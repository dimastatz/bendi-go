local TestKit = require("../TestKit")
local CarPhysics = require("../../src/core/CarPhysics")

local test, expectEqual, expectNear = TestKit.test, TestKit.expectEqual, TestKit.expectNear

local tuning: CarPhysics.Tuning = {
	maxForwardSpeed = 20,
	maxReverseSpeed = 5,
	acceleration = 4,
	brakeDeceleration = 10,
	coastDeceleration = 1,
	maxTurnRate = 2,
	fullSteerSpeed = 4,
}

local function input(throttle: number, steer: number, brake: boolean?): CarPhysics.Input
	return { throttle = throttle, steer = steer, brake = brake == true }
end

print("CarPhysics")

test("forward throttle accelerates", function()
	local speed = CarPhysics.step(0, input(1, 0), 1, tuning)
	expectEqual(speed, 4)
end)

test("forward speed stops at the top speed", function()
	local speed = CarPhysics.step(19, input(1, 0), 1, tuning)
	expectEqual(speed, 20)
end)

test("partial throttle aims for a lower speed", function()
	local speed = CarPhysics.step(12, input(0.5, 0), 1, tuning)
	expectEqual(speed, 10)
end)

test("reverse throttle reverses from a stop", function()
	local speed = CarPhysics.step(0, input(-1, 0), 1, tuning)
	expectEqual(speed, -4)
end)

test("reverse speed stops at the reverse top speed", function()
	local speed = CarPhysics.step(-4, input(-1, 0), 1, tuning)
	expectEqual(speed, -5)
end)

test("reverse throttle brakes while rolling forward", function()
	local speed = CarPhysics.step(15, input(-1, 0), 1, tuning)
	expectEqual(speed, 5)
end)

test("reverse throttle never jumps straight from forward to backward", function()
	local speed = CarPhysics.step(3, input(-1, 0), 1, tuning)
	expectEqual(speed, 0)
end)

test("forward throttle brakes while rolling backward", function()
	local speed = CarPhysics.step(-5, input(1, 0), 0.2, tuning)
	expectEqual(speed, -3)
end)

test("brake slows the car toward a stop", function()
	local speed = CarPhysics.step(15, input(1, 0, true), 1, tuning)
	expectEqual(speed, 5)
end)

test("brake stops a reversing car without rolling forward", function()
	local speed = CarPhysics.step(-3, input(0, 0, true), 1, tuning)
	expectEqual(speed, 0)
end)

test("no throttle coasts slowly to a stop", function()
	expectEqual(CarPhysics.step(10, input(0, 0), 1, tuning), 9)
	expectEqual(CarPhysics.step(-0.5, input(0, 0), 1, tuning), 0)
end)

test("out-of-range throttle is clamped", function()
	local speed = CarPhysics.step(0, input(5, 0), 10, tuning)
	expectEqual(speed, 20)
end)

test("steering right turns clockwise when driving forward", function()
	local _, turnRate = CarPhysics.step(10, input(1, 1), 0.1, tuning)
	expectEqual(turnRate, -2)
end)

test("steering left turns counterclockwise when driving forward", function()
	local _, turnRate = CarPhysics.step(10, input(1, -1), 0.1, tuning)
	expectEqual(turnRate, 2)
end)

test("steering is inverted when reversing, like a real car", function()
	local _, turnRate = CarPhysics.step(-5, input(-1, 1), 0.1, tuning)
	expectEqual(turnRate, 2)
end)

test("a stopped car does not turn", function()
	local _, turnRate = CarPhysics.step(0, input(0, 1), 0.1, tuning)
	expectEqual(turnRate, 0)
end)

test("steering is weaker at low speed", function()
	local _, turnRate = CarPhysics.step(2, input(0, 1), 0, tuning)
	expectEqual(turnRate, -1)
end)

test("out-of-range steering is clamped", function()
	local _, turnRate = CarPhysics.step(10, input(1, -3), 0.1, tuning)
	expectEqual(turnRate, 2)
end)

test("default tuning has a top speed of 70 km/h", function()
	local speed = CarPhysics.step(0, input(1, 0), 60)
	expectNear(speed, CarPhysics.DEFAULT_TUNING.maxForwardSpeed)
	expectNear(speed * 0.28 * 3.6, 70, 1e-6)
end)

TestKit.finish()
