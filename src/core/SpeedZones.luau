--!strict
-- Speed limits on every street (PRD-003, requirement 3). Town streets are 50 km/h, the Israeli default in towns.
-- One quiet residential street and the street next to the school are 30 km/h. Limits are per street segment:
-- the road between two crossings.

local TownLayout = require("./TownLayout")

export type ZoneKind = "town" | "residential" | "school"

local SpeedZones = {}

SpeedZones.TOWN_LIMIT = 50
SpeedZones.SLOW_LIMIT = 30
-- Going over the limit by up to this much doesn't count, so small bumps over the limit don't feel unfair.
SpeedZones.MARGIN = 3

-- The 30 km/h segments, matched against TownLayout.segments().
SpeedZones.SLOW_SEGMENTS = {
	{ kind = "residential" :: ZoneKind, alongX = false, at = -180, from = -270, to = -90 },
	{ kind = "school" :: ZoneKind, alongX = false, at = 0, from = 90, to = 270 },
}

-- The speed limit in km/h on `segment`, and what kind of zone it is.
function SpeedZones.forSegment(segment: TownLayout.Street): (number, ZoneKind)
	for _, slow in SpeedZones.SLOW_SEGMENTS do
		local matches = slow.alongX == segment.alongX
			and slow.at == segment.at
			and slow.from == segment.from
			and slow.to == segment.to
		if matches then
			return SpeedZones.SLOW_LIMIT, slow.kind
		end
	end
	return SpeedZones.TOWN_LIMIT, "town"
end

-- The speed limit in km/h where the point is, or nil in a crossing or off the road. Crossings belong to no
-- segment, so the speedometer keeps showing the last limit there.
function SpeedZones.limitAt(x: number, z: number): (number?, ZoneKind?)
	local index = TownLayout.segmentAt(x, z)
	if not index then
		return nil, nil
	end
	return SpeedZones.forSegment(TownLayout.segments()[index])
end

return SpeedZones
