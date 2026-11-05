--!strict
-- Checks one player's car at the roundabout entrances and the give-way sign (PRD-005, requirements 7, 9, 10, 11).
-- When the front of the car crosses the give-way line:
-- - Didn't yield: an NPC car with the right of way was close. That gets a tip.
-- - Yielded: an NPC car with the right of way was near while the player waited behind the line. That earns a star.
-- - Entered when clear: there was no NPC car to wait for. That also earns a star, because it's also right.
-- The first time a player reaches the roundabout or the give-way sign, Bendi explains the rule.
-- The rule needs `world.npcs`: where the NPC cars are.

local Approach = require("./Approach")
local Junctions = require("./Junctions")
local RuleKit = require("./RuleKit")

export type State = {
	approach: Junctions.YieldApproach?,
	sawTraffic: boolean,
	seen: { [string]: boolean },
	lastX: number?,
	lastZ: number?,
}

export type World = { npcs: { RuleKit.Car } }

local YieldRule = {}

YieldRule.APPROACH_LENGTH = 50

YieldRule.TIPS = {
	roundabout = {
		first = "roundaboutFirst",
		cutOff = "didntYieldRoundabout",
		yielded = "yieldedRoundabout",
		clear = "clearRoundabout",
	},
	giveWay = { first = "giveWayFirst", cutOff = "didntGiveWay", yielded = "yieldedGiveWay", clear = "clearGiveWay" },
}

function YieldRule.newState(): State
	return { approach = nil, sawTraffic = false, seen = {}, lastX = nil, lastZ = nil }
end

local function findApproach(front: RuleKit.Car): Junctions.YieldApproach?
	for _, approach in Junctions.yieldApproaches() do
		if Approach.contains(approach, front, YieldRule.APPROACH_LENGTH) then
			return approach
		end
	end
	return nil
end

-- Checks the car and returns what happened since the last check.
function YieldRule.update(state: State, car: RuleKit.Car, _now: number, world: World?): { RuleKit.Event }
	local events: { RuleKit.Event } = {}
	if RuleKit.jumped(state, car) then
		state.approach = nil
		return events
	end

	local npcs = if world then world.npcs else {}
	local front = RuleKit.front(car)

	local approach = state.approach
	if approach then
		if Approach.distanceBefore(approach, front.x, front.z) < 0 then
			local tips = YieldRule.TIPS[approach.kind]
			if Junctions.anyInZone(approach.danger, npcs) then
				table.insert(events, RuleKit.tip(tips.cutOff))
			else
				table.insert(events, RuleKit.star(approach.key, if state.sawTraffic then tips.yielded else tips.clear))
			end
			state.approach = nil
		elseif not Approach.contains(approach, front, YieldRule.APPROACH_LENGTH) then
			state.approach = nil
		end
	end

	if not state.approach then
		local found = findApproach(front)
		if not found then
			return events
		end
		state.approach = found
		state.sawTraffic = false
		if not state.seen[found.kind] then
			state.seen[found.kind] = true
			table.insert(events, RuleKit.tip(YieldRule.TIPS[found.kind].first))
		end
	end

	local current = state.approach :: Junctions.YieldApproach
	if Junctions.anyInZone(current.watch, npcs) then
		state.sawTraffic = true
	end
	return events
end

return YieldRule
