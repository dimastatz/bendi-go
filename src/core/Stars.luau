--!strict
-- A player's stars for this session (PRD-002, requirement 10). Stars are only ever added, never taken away.
-- Each thing that gives stars (like one traffic light) has a key and a cooldown, so circling back to it
-- right away doesn't give another star.

export type Stars = { total: number, lastAward: { [string]: number } }

local Stars = {}

-- The same thing (one light, one street segment, one crosswalk) gives the same player a star at most this often.
Stars.COOLDOWN = 60

function Stars.new(): Stars
	return { total = 0, lastAward = {} }
end

-- Gives a star for `key` at time `now`, unless `key` already gave one less than `cooldown` seconds ago.
-- Returns true if the star was given.
function Stars.tryAward(stars: Stars, key: string, now: number, cooldown: number): boolean
	local last = stars.lastAward[key]
	if last and now - last < cooldown then
		return false
	end
	stars.lastAward[key] = now
	stars.total += 1
	return true
end

return Stars
