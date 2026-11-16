--!strict
-- When the Bendi car's brake lights are on (PRD-008). They light up while the car slows down by braking, and stay on
-- while it stands still with a driver in it, like a driver holding the brake pedal at a red light.
-- Every client works this out from the car's own movement, so all players see the same lights with no extra network
-- messages. Speeds are in studs per second. Positive speed is forward.

local CarPhysics = require("./CarPhysics")
local Units = require("./Units")

local BrakeLights = {}

export type State = {
	speed: number?, -- the speed last frame, or nil before the first frame
	deceleration: number, -- how fast the car is slowing down, smoothed so small bumps don't flicker the lights
	lit: boolean,
}

-- Below this speed the car counts as standing still.
BrakeLights.STOPPED_SPEED = Units.kmhToStudsPerSecond(2)
-- Slowing down faster than this is braking. Just letting the car roll slows it down much less.
BrakeLights.ON_DECELERATION = 0.45 * CarPhysics.DEFAULT_TUNING.brakeDeceleration
-- Once on, the lights stay on until the car slows down less than this, so they don't blink.
BrakeLights.OFF_DECELERATION = 0.25 * CarPhysics.DEFAULT_TUNING.brakeDeceleration
-- How many seconds it takes the smoothed deceleration to catch up with the real one.
BrakeLights.SMOOTHING = 0.15

function BrakeLights.newState(): State
	return { speed = nil, deceleration = 0, lit = false }
end

-- Updates `state` with the car's `speed` after `dt` seconds and returns whether the brake lights are on.
-- An empty car (`occupied` is false) never has its brake lights on.
-- Runs every frame for every car, so it changes `state` in place.
function BrakeLights.update(state: State, speed: number, dt: number, occupied: boolean): boolean
	local previous = state.speed
	state.speed = speed
	if previous and dt > 0 then
		-- Slowing down in reverse is braking too, so this uses how fast the car goes, whichever way.
		local deceleration = (math.abs(previous) - math.abs(speed)) / dt
		state.deceleration += (deceleration - state.deceleration) * math.min(dt / BrakeLights.SMOOTHING, 1)
	end

	local threshold = if state.lit then BrakeLights.OFF_DECELERATION else BrakeLights.ON_DECELERATION
	local braking = state.deceleration > threshold
	local stopped = math.abs(speed) < BrakeLights.STOPPED_SPEED
	state.lit = occupied and (braking or stopped)
	return state.lit
end

return BrakeLights
