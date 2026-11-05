--!strict
-- Checks one player's speed on every street segment (PRD-003, requirements 5 to 9).
-- - Driving a whole segment, from one crossing to the next, without ever going more than 3 km/h over the limit
--   earns a star.
-- - Going more than 3 km/h over the limit for more than 2 seconds gets a tip, at most once per segment.
-- - The first time a player drives into a 30 km/h street, Bendi explains why some streets are slower.
-- There is no time limit on a segment, so waiting at a red light doesn't count against the player.

local RuleKit = require("./RuleKit")
local SpeedZones = require("./SpeedZones")
local TownLayout = require("./TownLayout")
local Units = require("./Units")

export type State = {
	segment: number?, -- the segment the car is on
	direction: number, -- 1 driving toward the segment's `to` end, -1 toward its `from` end
	fromStart: boolean, -- the car came onto the segment at its start, so it can drive the whole segment
	exceeded: boolean, -- went too fast somewhere on this segment
	overTime: number, -- seconds in a row going too fast
	tipped: boolean, -- already got a tip on this segment
	seenSlowZone: boolean,
	praised: boolean, -- Bendi only praises the first speed star, since they come often
	lastTime: number?,
	lastX: number?,
	lastZ: number?,
}

local SpeedRule = {}

SpeedRule.ENTRY_WINDOW = 25 -- the car must come onto the segment within this far of its start
SpeedRule.TIP_DELAY = 2 -- seconds of going too fast before Bendi says something

local TIPS = { town = "tooFastTown", residential = "tooFastResidential", school = "tooFastSchool" }

function SpeedRule.newState(): State
	return {
		segment = nil,
		direction = 1,
		fromStart = false,
		exceeded = false,
		overTime = 0,
		tipped = false,
		seenSlowZone = false,
		praised = false,
		lastTime = nil,
		lastX = nil,
		lastZ = nil,
	}
end

-- The car's heading along the segment's street, from -1 to 1.
local function headingAlong(segment: TownLayout.Street, car: RuleKit.Car): number
	local length = math.sqrt(car.dirX * car.dirX + car.dirZ * car.dirZ)
	if length < 1e-6 then
		return 0
	end
	return (if segment.alongX then car.dirX else car.dirZ) / length
end

local function leaveSegment(state: State, car: RuleKit.Car, events: { RuleKit.Event })
	local index = state.segment
	if not index then
		return
	end
	state.segment = nil
	if not state.fromStart or state.exceeded then
		return
	end
	-- The car drove the whole segment if it left through the far end, onto the crossing there.
	local segment = TownLayout.segments()[index]
	local first, last = TownLayout.segmentEnds(segment)
	local finish = if state.direction > 0 then last else first
	local along, across = car.z, car.x
	if segment.alongX then
		along, across = car.x, car.z
	end
	local onStreet = math.abs(across - segment.at) <= TownLayout.ROAD_WIDTH / 2
	if onStreet and (along - finish) * state.direction >= 0 then
		local praise = if state.praised then nil else "speedStar"
		state.praised = true
		table.insert(events, RuleKit.star(`segment{index}`, praise))
	end
end

local function enterSegment(state: State, index: number, along: number, car: RuleKit.Car, events: { RuleKit.Event })
	local segment = TownLayout.segments()[index]
	local heading = headingAlong(segment, car)
	local first, last = TownLayout.segmentEnds(segment)
	state.segment = index
	state.direction = if heading < 0 then -1 else 1
	local start = if state.direction > 0 then first else last
	state.fromStart = math.abs(heading) >= 0.5 and (along - start) * state.direction <= SpeedRule.ENTRY_WINDOW
	state.exceeded = false
	state.overTime = 0
	state.tipped = false

	local limit = SpeedZones.forSegment(segment)
	if limit < SpeedZones.TOWN_LIMIT and not state.seenSlowZone then
		state.seenSlowZone = true
		table.insert(events, RuleKit.tip("slowZone"))
	end
end

-- Checks the car at time `now` and returns what happened since the last check.
function SpeedRule.update(state: State, car: RuleKit.Car, now: number): { RuleKit.Event }
	local events: { RuleKit.Event } = {}
	local dt = if state.lastTime then now - state.lastTime else 0
	state.lastTime = now

	if RuleKit.jumped(state, car) then
		state.segment = nil
		return events
	end

	local index, along = TownLayout.segmentAt(car.x, car.z)
	if state.segment and index ~= state.segment then
		leaveSegment(state, car, events)
	end
	if not index then
		return events
	end
	if index ~= state.segment then
		enterSegment(state, index, along, car, events)
	end

	local segment = TownLayout.segments()[index]
	-- Turning around halfway means the car won't drive the whole segment.
	if headingAlong(segment, car) * state.direction < -0.5 then
		state.fromStart = false
	end

	local limit, kind = SpeedZones.forSegment(segment)
	if Units.studsPerSecondToKmh(math.abs(car.speed)) > limit + SpeedZones.MARGIN then
		state.exceeded = true
		state.overTime += dt
		if state.overTime > SpeedRule.TIP_DELAY and not state.tipped then
			state.tipped = true
			table.insert(events, RuleKit.tip(TIPS[kind]))
		end
	else
		state.overTime = 0
	end

	return events
end

return SpeedRule
