--!strict
-- The roundabout, the stop sign junction, and the give-way junction (PRD-005), and who has to wait for whom there.
-- - Roundabout: single lane, traffic goes counterclockwise (seen from above), and cars entering give way to cars
--   already going around.
-- - Stop signs: on the side street (x = 180) at the crossing (180, -90). The main street there is z = -90.
-- - Give-way sign: on the side street (x = 180) where it meets the ring road at (180, 270).
-- A `Zone` is where cars have the right of way over an approach: an arc of the roundabout upstream of an entrance,
-- or a stretch of the main street on both sides of a junction.

local Approach = require("./Approach")
local RuleKit = require("./RuleKit")
local TownLayout = require("./TownLayout")

export type Zone =
	{ kind: "arc", angle: number, from: number, to: number }
	| { kind: "street", alongX: boolean, at: number, center: number, reach: number }

export type YieldKind = "roundabout" | "giveWay"
export type YieldApproach = Approach.Approach & { key: string, kind: YieldKind, watch: Zone, danger: Zone }
export type StopApproach = Approach.Approach & { key: string }

local Junctions = {}

Junctions.CENTER_X = TownLayout.ROUNDABOUT.x
Junctions.CENTER_Z = TownLayout.ROUNDABOUT.z
Junctions.LANE_RADIUS = 26 -- the middle of the roundabout's lane
Junctions.ISLAND_RADIUS = 19.5
Junctions.OUTER_RADIUS = 32
Junctions.YIELD_DISTANCE = 36 -- the give-way line at each entrance, from the roundabout's center
Junctions.LINE_DISTANCE = 25 -- stop and give-way lines at the junctions, from the crossing's center
Junctions.STOP_CROSSING = { x = 180, z = -90 }
Junctions.GIVE_WAY_CROSSING = { x = 180, z = 270 }

local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local ARC_WIDTH = 8 -- cars this far inside or outside the lane's middle still count as in the roundabout

-- Angles are in degrees, measured like math.atan2(z, x): east is 0 and south (+Z) is 90. Going counterclockwise
-- seen from above means the angle goes down.
local function angleOf(x: number, z: number): number
	return math.deg(math.atan2(z - Junctions.CENTER_Z, x - Junctions.CENTER_X))
end

-- The difference between two angles, from -180 to 180.
local function wrap(degrees: number): number
	return (degrees + 180) % 360 - 180
end

-- The four entrances. Each car going around has to pass an entrance after coming from the arc upstream of it
-- (bigger angles), so that arc is where cars have the right of way.
function Junctions.roundaboutEntries(): { YieldApproach }
	local legs = {
		{ alongX = true, direction = -1, angle = 0 }, -- from the east, driving west
		{ alongX = false, direction = -1, angle = 90 }, -- from the south, driving north
		{ alongX = true, direction = 1, angle = 180 }, -- from the west, driving east
		{ alongX = false, direction = 1, angle = -90 }, -- from the north, driving south
	}
	local entries = {}
	for index, leg in legs do
		local center = if leg.alongX then Junctions.CENTER_X else Junctions.CENTER_Z
		table.insert(entries, {
			key = `roundabout{index}`,
			kind = "roundabout" :: YieldKind,
			alongX = leg.alongX,
			direction = leg.direction,
			at = if leg.alongX then Junctions.CENTER_Z else Junctions.CENTER_X,
			line = center - leg.direction * Junctions.YIELD_DISTANCE,
			watch = { kind = "arc", angle = leg.angle, from = -15, to = 100 } :: Zone,
			danger = { kind = "arc", angle = leg.angle, from = -10, to = 55 } :: Zone,
		})
	end
	return entries
end

-- The give-way approach: driving south on x = 180 into the ring road, which has the right of way.
function Junctions.giveWayApproaches(): { YieldApproach }
	local crossing = Junctions.GIVE_WAY_CROSSING
	return {
		{
			key = "giveWay",
			kind = "giveWay" :: YieldKind,
			alongX = false,
			direction = 1,
			at = crossing.x,
			line = crossing.z - Junctions.LINE_DISTANCE,
			watch = { kind = "street", alongX = true, at = crossing.z, center = crossing.x, reach = 80 } :: Zone,
			danger = { kind = "street", alongX = true, at = crossing.z, center = crossing.x, reach = 40 } :: Zone,
		},
	}
end

function Junctions.yieldApproaches(): { YieldApproach }
	local approaches = Junctions.roundaboutEntries()
	for _, approach in Junctions.giveWayApproaches() do
		table.insert(approaches, approach)
	end
	return approaches
end

-- The two stop sign approaches on the side street, from the north and from the south.
function Junctions.stopApproaches(): { StopApproach }
	local crossing = Junctions.STOP_CROSSING
	local approaches = {}
	for index, direction in { 1, -1 } do
		table.insert(approaches, {
			key = `stop{index}`,
			alongX = false,
			direction = direction,
			at = crossing.x,
			line = crossing.z - direction * Junctions.LINE_DISTANCE,
		})
	end
	return approaches
end

-- True if the car is in the zone.
function Junctions.inZone(zone: Zone, car: RuleKit.Car): boolean
	if zone.kind == "arc" then
		local radius = math.sqrt((car.x - Junctions.CENTER_X) ^ 2 + (car.z - Junctions.CENTER_Z) ^ 2)
		if math.abs(radius - Junctions.LANE_RADIUS) > ARC_WIDTH then
			return false
		end
		local offset = wrap(angleOf(car.x, car.z) - zone.angle)
		return offset >= zone.from and offset <= zone.to
	end

	local along, across, heading = car.z, car.x, car.dirZ
	if zone.alongX then
		along, across, heading = car.x, car.z, car.dirX
	end
	if math.abs(across - zone.at) > HALF_ROAD then
		return false
	end
	local offset = along - zone.center
	if math.abs(offset) > zone.reach then
		return false
	end
	-- In the junction itself, or driving toward it.
	return math.abs(offset) < HALF_ROAD or heading * -offset > 0
end

-- True if any of the cars is in the zone.
function Junctions.anyInZone(zone: Zone, cars: { RuleKit.Car }): boolean
	for _, car in cars do
		if Junctions.inZone(zone, car) then
			return true
		end
	end
	return false
end

return Junctions
