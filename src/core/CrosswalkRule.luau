--!strict
-- Checks one player's car at the crosswalks (PRD-004, requirements 4, 5, and 8).
-- - Let them cross: someone was waiting or crossing, and the car stopped before the stripes and stayed there until
--   they had crossed. That earns a star.
-- - Didn't stop: the front of the car drove onto the stripes while someone was on the road. That gets a tip.
-- The first time a player comes up to someone waiting to cross, Bendi explains the rule.
-- The rule needs `world.crosswalks`: one Walkers.Status for each crosswalk.

local Approach = require("./Approach")
local Crosswalks = require("./Crosswalks")
local RuleKit = require("./RuleKit")
local Walkers = require("./Walkers")

export type State = {
	approach: Crosswalks.CrosswalkApproach?,
	waited: boolean,
	rewarded: boolean,
	seen: boolean,
	lastX: number?,
	lastZ: number?,
}

export type World = { crosswalks: { Walkers.Status } }

local CrosswalkRule = {}

CrosswalkRule.APPROACH_LENGTH = 60

function CrosswalkRule.newState(): State
	return { approach = nil, waited = false, rewarded = false, seen = false, lastX = nil, lastZ = nil }
end

local function leaveApproach(state: State)
	state.approach = nil
	state.waited = false
	state.rewarded = false
end

local function findApproach(front: RuleKit.Car): Crosswalks.CrosswalkApproach?
	for _, approach in Crosswalks.approaches() do
		if Approach.contains(approach, front, CrosswalkRule.APPROACH_LENGTH) then
			return approach
		end
	end
	return nil
end

-- Checks the car and returns what happened since the last check.
function CrosswalkRule.update(state: State, car: RuleKit.Car, _now: number, world: World?): { RuleKit.Event }
	local events: { RuleKit.Event } = {}
	if RuleKit.jumped(state, car) then
		leaveApproach(state)
		return events
	end

	local statuses = if world then world.crosswalks else {}
	local front = Crosswalks.front(car)

	local approach = state.approach
	if approach then
		if Approach.distanceBefore(approach, front.x, front.z) < 0 then
			-- The front of the car reached the stripes.
			local status = statuses[approach.crosswalk]
			if status and status.crossing then
				table.insert(events, RuleKit.tip("didntStopForPedestrian"))
			end
			leaveApproach(state)
		elseif not Approach.contains(approach, front, CrosswalkRule.APPROACH_LENGTH) then
			leaveApproach(state)
		end
	end

	if not state.approach then
		state.approach = findApproach(front)
		if not state.approach then
			return events
		end
	end

	local current = state.approach :: Crosswalks.CrosswalkApproach
	local status = statuses[current.crosswalk]
	local busy = status ~= nil and (status.waiting or status.crossing)

	if busy and not state.seen then
		state.seen = true
		table.insert(events, RuleKit.tip("pedestrianWaiting"))
	end
	if busy and math.abs(car.speed) < RuleKit.STOP_SPEED then
		state.waited = true
	elseif not busy and state.waited and not state.rewarded then
		state.rewarded = true
		table.insert(events, RuleKit.star(`crosswalk{current.crosswalk}`, "crosswalkPraise"))
	end

	return events
end

return CrosswalkRule
