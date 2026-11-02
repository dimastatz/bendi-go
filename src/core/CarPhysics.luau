--!strict
-- Arcade driving model for the Bendi car: turns throttle, steering, and brake input into a forward speed
-- and a turn rate. Speeds are in studs per second and turn rates in radians per second.
-- Positive speed is forward. A positive turn rate turns the car left (counterclockwise seen from above).

local Units = require("./Units")

export type Input = {
	throttle: number, -- -1 (reverse) to 1 (forward)
	steer: number, -- -1 (left) to 1 (right)
	brake: boolean,
}

export type Tuning = {
	maxForwardSpeed: number,
	maxReverseSpeed: number,
	acceleration: number, -- studs per second, per second
	brakeDeceleration: number,
	coastDeceleration: number,
	maxTurnRate: number,
	fullSteerSpeed: number, -- below this speed, steering is weaker so the car can't spin in place
}

local CarPhysics = {}

local DEFAULT_TUNING: Tuning = {
	maxForwardSpeed = Units.kmhToStudsPerSecond(70),
	maxReverseSpeed = Units.kmhToStudsPerSecond(15),
	acceleration = Units.kmhToStudsPerSecond(12), -- 0 to 70 km/h in about 6 seconds
	brakeDeceleration = Units.kmhToStudsPerSecond(35), -- 70 km/h to a stop in 2 seconds
	coastDeceleration = Units.kmhToStudsPerSecond(5),
	maxTurnRate = math.rad(90),
	fullSteerSpeed = Units.kmhToStudsPerSecond(10),
}

CarPhysics.DEFAULT_TUNING = DEFAULT_TUNING

local function approach(value: number, target: number, maxDelta: number): number
	if value < target then
		return math.min(value + maxDelta, target)
	end
	return math.max(value - maxDelta, target)
end

-- Returns the car's new forward speed and turn rate after `dt` seconds of `input`, starting at `speed`.
function CarPhysics.step(speed: number, input: Input, dt: number, tuning: Tuning?): (number, number)
	local t = tuning or DEFAULT_TUNING
	local throttle = math.clamp(input.throttle, -1, 1)
	local steer = math.clamp(input.steer, -1, 1)

	local newSpeed
	if input.brake then
		newSpeed = approach(speed, 0, t.brakeDeceleration * dt)
	elseif throttle > 0 and speed < 0 then
		-- Pressing forward while rolling backward brakes first.
		newSpeed = approach(speed, 0, t.brakeDeceleration * dt)
	elseif throttle < 0 and speed > 0 then
		-- Pressing back while rolling forward brakes first, then reverses once stopped.
		newSpeed = approach(speed, 0, t.brakeDeceleration * dt)
	elseif throttle > 0 then
		newSpeed = approach(speed, t.maxForwardSpeed * throttle, t.acceleration * dt)
	elseif throttle < 0 then
		newSpeed = approach(speed, t.maxReverseSpeed * throttle, t.acceleration * dt)
	else
		newSpeed = approach(speed, 0, t.coastDeceleration * dt)
	end

	local steerStrength = math.min(math.abs(newSpeed) / t.fullSteerSpeed, 1)
	local direction = if newSpeed < 0 then -1 else 1
	local turnRate = -steer * t.maxTurnRate * steerStrength * direction

	return newSpeed, turnRate
end

return CarPhysics
