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

local Config = require("./TrafficLightConfig")
local TownLayout = require("./TownLayout")
local TrafficLight = require("./TrafficLight")
local Units = require("./Units")

-- An approach to a crossing: cars on the street along X (`alongX`) or along Z, driving in `direction` (1 or -1),
-- with the stop line at `stopLine` on that street. `at` is where the street is on the other axis.
export type Approach = { crossing: number, alongX: boolean, direction: number, at: number, stopLine: number }

-- Where the car is, which way it faces (doesn't need to be a unit vector), and its speed in studs per second.
export type Car = { x: number, z: number, dirX: number, dirZ: number, speed: number }

export type Event = { kind: "star", crossing: number } | { kind: "tip", tip: string }

export type State = {
	approach: Approach?,
	waited: boolean, -- stopped at red during this approach
	rewarded: boolean, -- already earned a star during this approach
	seen: { [string]: boolean }, -- light steps Bendi has already explained
	lastX: number?,
	lastZ: number?,
}

local RedLightRule = {}

RedLightRule.APPROACH_LENGTH = 60 -- the car is watched from this far before the stop line
RedLightRule.STOP_SPEED = Units.kmhToStudsPerSecond(1) -- slower than this counts as stopped
RedLightRule.MAX_STEP = 40 -- a car that moved farther than this since the last check was reset, not driven

local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local MIN_HEADING = 0.5 -- the car must face within about 60 degrees of the approach's direction

function RedLightRule.newState(): State
	return { approach = nil, waited = false, rewarded = false, seen = {}, lastX = nil, lastZ = nil }
end

-- All approaches to all crossings with traffic lights.
function RedLightRule.approaches(): { Approach }
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
					stopLine = center - direction * Config.STOP_LINE_DISTANCE,
				})
			end
		end
	end
	return approaches
end

-- How far the car is before the approach's stop line. Negative once it has crossed the line.
local function distanceBefore(approach: Approach, car: Car): number
	local along = if approach.alongX then car.x else car.z
	return (approach.stopLine - along) * approach.direction
end

local function inApproach(approach: Approach, car: Car): boolean
	local before = distanceBefore(approach, car)
	if before < 0 or before > RedLightRule.APPROACH_LENGTH then
		return false
	end

	-- How far right of the center line the car is, for traffic driving in the approach's direction.
	local right = if approach.alongX
		then (car.z - approach.at) * approach.direction
		else (approach.at - car.x) * approach.direction
	if right < 0 or right > HALF_ROAD then
		return false
	end

	local length = math.sqrt(car.dirX * car.dirX + car.dirZ * car.dirZ)
	if length < 1e-6 then
		return false
	end
	local heading = (if approach.alongX then car.dirX else car.dirZ) / length
	return heading * approach.direction >= MIN_HEADING
end

-- The approach the car is in, if any.
function RedLightRule.findApproach(car: Car): Approach?
	for _, approach in RedLightRule.approaches() do
		if inApproach(approach, car) then
			return approach
		end
	end
	return nil
end

local function lightFor(approach: Approach, now: number): TrafficLight.LightState
	return (TrafficLight.stateAt(now, approach.alongX, Config.CROSSINGS[approach.crossing].offset))
end

local function tipEvent(tip: string): Event
	return { kind = "tip", tip = tip }
end

local function starEvent(crossing: number): Event
	return { kind = "star", crossing = crossing }
end

local function leaveApproach(state: State)
	state.approach = nil
	state.waited = false
	state.rewarded = false
end

-- Checks the car at time `now` and returns what happened since the last check.
function RedLightRule.update(state: State, car: Car, now: number): { Event }
	local events: { Event } = {}

	-- A car that jumped (for example with Reset car) didn't drive past anything.
	local lastX, lastZ = state.lastX, state.lastZ
	state.lastX, state.lastZ = car.x, car.z
	if lastX and lastZ and math.sqrt((car.x - lastX) ^ 2 + (car.z - lastZ) ^ 2) > RedLightRule.MAX_STEP then
		leaveApproach(state)
		return events
	end

	local approach = state.approach
	if approach then
		local before = distanceBefore(approach, car)
		if before < 0 then
			-- The car crossed the stop line since the last check.
			if TrafficLight.isStop(lightFor(approach, now)) then
				table.insert(events, tipEvent("ranRed"))
			end
			leaveApproach(state)
		elseif not inApproach(approach, car) then
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

	local current = state.approach :: Approach
	local light = lightFor(current, now)

	if TrafficLight.isStop(light) and math.abs(car.speed) < RedLightRule.STOP_SPEED then
		state.waited = true
	elseif TrafficLight.isGo(light) and state.waited and not state.rewarded then
		table.insert(events, starEvent(current.crossing))
		state.waited = false
		state.rewarded = true
	end

	if (light == "flashingGreen" or light == "redYellow") and not state.seen[light] then
		state.seen[light] = true
		table.insert(events, tipEvent(light))
	end

	return events
end

return RedLightRule
