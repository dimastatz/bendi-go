--!strict
-- Conversions between Roblox units and real-world units (PRD-001, requirement 8).
-- One stud is 0.28 meters, the scale commonly used for Roblox's default character.
-- Every speed shown to players in km/h goes through this module.

local Units = {}

Units.METERS_PER_STUD = 0.28

local KMH_PER_METERS_PER_SECOND = 3.6

function Units.studsPerSecondToKmh(studsPerSecond: number): number
	return studsPerSecond * Units.METERS_PER_STUD * KMH_PER_METERS_PER_SECOND
end

function Units.kmhToStudsPerSecond(kmh: number): number
	return kmh / KMH_PER_METERS_PER_SECOND / Units.METERS_PER_STUD
end

return Units
