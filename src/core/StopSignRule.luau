--!strict
-- Checks one player's car at the stop signs (PRD-005, requirements 8, 10, 11).
-- - Coming to a full stop before the stop line earns a star.
-- - Rolling over the line without stopping gets a tip, even at walking speed.
-- The first time a player reaches a stop sign, Bendi explains it.

local Approach = require("./Approach")
local Junctions = require("./Junctions")
local RuleKit = require("./RuleKit")

export type State = {
	approach: Junctions.StopApproach?,
	stopped: boolean,
	seen: boolean,
	lastX: number?,
	lastZ: number?,
}

local StopSignRule = {}

StopSignRule.APPROACH_LENGTH = 50

function StopSignRule.newState(): State
	return { approach = nil, stopped = false, seen = false, lastX = nil, lastZ = nil }
end

local function findApproach(front: RuleKit.Car): Junctions.StopApproach?
	for _, approach in Junctions.stopApproaches() do
		if Approach.contains(approach, front, StopSignRule.APPROACH_LENGTH) then
			return approach
		end
	end
	return nil
end

-- Checks the car and returns what happened since the last check.
function StopSignRule.update(state: State, car: RuleKit.Car): { RuleKit.Event }
	local events: { RuleKit.Event } = {}
	if RuleKit.jumped(state, car) then
		state.approach = nil
		return events
	end

	local front = RuleKit.front(car)
	local approach = state.approach
	if approach then
		if Approach.distanceBefore(approach, front.x, front.z) < 0 then
			if not state.stopped then
				table.insert(events, RuleKit.tip("rolledStop"))
			end
			state.approach = nil
		elseif not Approach.contains(approach, front, StopSignRule.APPROACH_LENGTH) then
			state.approach = nil
		end
	end

	if not state.approach then
		local found = findApproach(front)
		if not found then
			return events
		end
		state.approach = found
		state.stopped = false
		if not state.seen then
			state.seen = true
			table.insert(events, RuleKit.tip("stopSign"))
		end
	end

	local current = state.approach :: Junctions.StopApproach
	if not state.stopped and math.abs(car.speed) < RuleKit.STOP_SPEED then
		state.stopped = true
		table.insert(events, RuleKit.star(current.key, "stopPraise"))
	end
	return events
end

return StopSignRule
