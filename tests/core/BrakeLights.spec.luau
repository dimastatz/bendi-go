local TestKit = require("../TestKit")
local BrakeLights = require("../../src/core/BrakeLights")
local CarPhysics = require("../../src/core/CarPhysics")

local test, expectEqual = TestKit.test, TestKit.expectEqual

local DT = 1 / 60
local FULL_SPEED = CarPhysics.DEFAULT_TUNING.maxForwardSpeed

-- Drives the car with `input` for `seconds`, starting at `speed`. Returns the new speed and how many frames the brake
-- lights were on, out of how many frames.
local function drive(
	state: BrakeLights.State,
	speed: number,
	input: CarPhysics.Input,
	seconds: number,
	occupied: boolean?
): (number, number, number)
	local litFrames, frames = 0, math.round(seconds / DT)
	for _ = 1, frames do
		speed = CarPhysics.step(speed, input, DT)
		if BrakeLights.update(state, speed, DT, occupied ~= false) then
			litFrames += 1
		end
	end
	return speed, litFrames, frames
end

local GAS = { throttle = 1, steer = 0, brake = false }
local BRAKE = { throttle = 0, steer = 0, brake = true }
local ROLL = { throttle = 0, steer = 0, brake = false }
local BACK = { throttle = -1, steer = 0, brake = false }

print("BrakeLights")

test("the lights are off while driving along or speeding up", function()
	local state = BrakeLights.newState()
	local speed = drive(state, 0, GAS, 0.5)
	local _, lit = drive(state, speed, GAS, 3)
	expectEqual(lit, 0)
	expectEqual(state.lit, false)
end)

test("braking turns the lights on quickly, and they stay on until the car stops", function()
	local state = BrakeLights.newState()
	drive(state, FULL_SPEED, GAS, 1)
	local speed = drive(state, FULL_SPEED, BRAKE, 0.2)
	expectEqual(state.lit, true)
	local _, lit, frames = drive(state, speed, BRAKE, 3)
	expectEqual(lit, frames)
end)

test("the lights stay on while a car with a driver stands still", function()
	local state = BrakeLights.newState()
	local _, lit, frames = drive(state, 0, ROLL, 2)
	expectEqual(lit, frames)
end)

test("an empty car never has its brake lights on", function()
	local state = BrakeLights.newState()
	local _, lit = drive(state, 0, ROLL, 1, false)
	expectEqual(lit, 0)
	local _, litBraking = drive(state, FULL_SPEED, BRAKE, 1, false)
	expectEqual(litBraking, 0)
end)

test("letting the car roll doesn't turn the lights on", function()
	local state = BrakeLights.newState()
	drive(state, FULL_SPEED, GAS, 1)
	local _, lit = drive(state, FULL_SPEED, ROLL, 3)
	expectEqual(lit, 0)
end)

test("the lights go off soon after letting go of the brake", function()
	local state = BrakeLights.newState()
	drive(state, FULL_SPEED, GAS, 1)
	local speed = drive(state, FULL_SPEED, BRAKE, 0.5)
	expectEqual(state.lit, true)
	drive(state, speed, GAS, 0.5)
	expectEqual(state.lit, false)
end)

test("pressing back while driving forward brakes, and then reversing turns the lights off", function()
	local state = BrakeLights.newState()
	drive(state, FULL_SPEED, GAS, 1)
	local speed = drive(state, FULL_SPEED, BACK, 0.5)
	expectEqual(state.lit, true)
	-- Keep pressing back: the car stops, then drives backward.
	speed = drive(state, speed, BACK, 4)
	expectEqual(speed < -BrakeLights.STOPPED_SPEED, true)
	expectEqual(state.lit, false)
end)

test("braking while reversing turns the lights on too", function()
	local state = BrakeLights.newState()
	local speed = drive(state, 0, BACK, 3)
	expectEqual(state.lit, false)
	drive(state, speed, BRAKE, 0.2)
	expectEqual(state.lit, true)
end)

test("small bumps in the speed don't flicker the lights", function()
	local state = BrakeLights.newState()
	local speed = FULL_SPEED / 2
	for frame = 1, 600 do
		-- The speed other players see jumps a little as network updates arrive.
		local bump = if frame % 3 == 0 then -0.3 else 0
		expectEqual(BrakeLights.update(state, speed + bump, DT, true), false)
	end
end)

test("a frame with no time passed doesn't change anything", function()
	local state = BrakeLights.newState()
	BrakeLights.update(state, 10, DT, true)
	expectEqual(BrakeLights.update(state, 5, 0, true), false)
	expectEqual(state.deceleration, 0)
end)

TestKit.finish()
