--!strict
-- Checks one player's car at the traffic lights (PRD-002, requirements 4 and 8).
-- Each light-controlled crossing has four approaches, one for each way a car can drive into it. While a car is in
-- an approach (in the right-hand half of the road, heading toward the crossing, close to the stop line), the rule
-- watches it:
-- - Stopped at red: it stopped before the stop line while the light was red, and was still before the line when
--   the light turned green. That earns a star.
-- - Ran a red: it crossed the stop line while the light was red (or red and yellow). That gets a tip.
-- - Crossing on yellow is fine, because stopping may not have been safe.
-- The first time a player sees a flashing green or a red-and-yellow light, Bendi explains it.

local Approach = require("./Approach")
local Config = require("./TrafficLightConfig")
local RuleKit = require("./RuleKit")
local TrafficLight = require("./TrafficLight")

-- An approach to light crossing number `crossing`. Its `line` is the white stop line.
export type LightApproach = Approach.Approach & { crossing: number }

export type State = {
	approach: LightApproach?,
	waited: boolean, -- stopped at red during this approach
	rewarded: boolean, -- already earned a star during this approach
	seen: { [string]: boolean }, -- light steps Bendi has already explained
	lastX: number?,
	lastZ: number?,
}

local RedLightRule = {}

RedLightRule.APPROACH_LENGTH = 60 -- the car is watched from this far before the stop line

function RedLightRule.newState(): State
	return { approach = nil, waited = false, rewarded = false, seen = {}, lastX = nil, lastZ = nil }
end

-- All approaches to all crossings with traffic lights.
function RedLightRule.approaches(): { LightApproach }
	local approaches = {}
	for index, crossing in Config.CROSSINGS do
		for _, alongX in { true, false } do
			local center = if alongX then crossing.x else crossing.z
			for _, direction in { 1, -1 } do
				table.insert(approaches, {
					crossing = index,
					alongX = alongX,
					direction = direction,
					at = if alongX then crossing.z else crossing.x,
					line = center - direction * Config.STOP_LINE_DISTANCE,
				})
			end
		end
	end
	return approaches
end

-- The approach the car is in, if any.
function RedLightRule.findApproach(car: RuleKit.Car): LightApproach?
	for _, approach in RedLightRule.approaches() do
		if Approach.contains(approach, car, RedLightRule.APPROACH_LENGTH) then
			return approach
		end
	end
	return nil
end

-- The light the approach's traffic sees at `now`.
function RedLightRule.lightFor(approach: LightApproach, now: number): TrafficLight.LightState
	return (TrafficLight.stateAt(now, approach.alongX, Config.CROSSINGS[approach.crossing].offset))
end

local function leaveApproach(state: State)
	state.approach = nil
	state.waited = false
	state.rewarded = false
end

-- Checks the car at time `now` and returns what happened since the last check.
function RedLightRule.update(state: State, car: RuleKit.Car, now: number): { RuleKit.Event }
	local events: { RuleKit.Event } = {}

	if RuleKit.jumped(state, car) then
		leaveApproach(state)
		return events
	end

	local approach = state.approach
	if approach then
		if Approach.distanceBefore(approach, car.x, car.z) < 0 then
			-- The car crossed the stop line since the last check.
			if TrafficLight.isStop(RedLightRule.lightFor(approach, now)) then
				table.insert(events, RuleKit.tip("ranRed"))
			end
			leaveApproach(state)
		elseif not Approach.contains(approach, car, RedLightRule.APPROACH_LENGTH) then
			leaveApproach(state)
		end
	end

	if not state.approach then
		local found = RedLightRule.findApproach(car)
		if not found then
			return events
		end
		state.approach = found
	end

	local current = state.approach :: LightApproach
	local light = RedLightRule.lightFor(current, now)

	if TrafficLight.isStop(light) and math.abs(car.speed) < RuleKit.STOP_SPEED then
		state.waited = true
	elseif TrafficLight.isGo(light) and state.waited and not state.rewarded then
		table.insert(events, RuleKit.star(`light{current.crossing}`, "stoppedAtRed"))
		state.waited = false
		state.rewarded = true
	end

	if (light == "flashingGreen" or light == "redYellow") and not state.seen[light] then
		state.seen[light] = true
		table.insert(events, RuleKit.tip(light))
	end

	return events
end

return RedLightRule
