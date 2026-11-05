--!strict
-- The street plan of the Bendi Go neighborhood (PRD-001, requirement 5), as plain numbers.
-- Streets form a grid. North-south streets run along Z at fixed X positions, and east-west streets run along X at
-- fixed Z positions. The outermost streets make a ring road around the town. Cars drive on the right, so every
-- street has one lane in each direction, with a parking strip along each curb.
-- Positions are in studs (see Units). Y is left out, because the town is flat.

local Rect = require("./Rect")

type Rect = Rect.Rect

-- A position on the ground and the direction the car faces there (a unit vector).
export type Pose = { x: number, z: number, dirX: number, dirZ: number }

-- A straight piece of street. If `alongX` is true it runs along X at z = `at`, from x = `from` to x = `to`.
-- Otherwise it runs along Z at x = `at`, from z = `from` to z = `to`.
export type Street = { alongX: boolean, at: number, from: number, to: number }

-- The land between streets. `pieces` are raised sidewalk slabs, `inner` is the land inside the sidewalks where
-- buildings go, and street trees stand along the edge of `treeLine`, but not inside `keepClear`.
export type Lot = { pieces: { Rect }, inner: { Rect }, treeLine: Rect, keepClear: Rect? }

local TownLayout = {}

TownLayout.LANE_WIDTH = 11 -- about 3 m
TownLayout.PARKING_WIDTH = 8
TownLayout.ROAD_WIDTH = 2 * (TownLayout.LANE_WIDTH + TownLayout.PARKING_WIDTH)
TownLayout.SIDEWALK_WIDTH = 8
TownLayout.BORDER_WIDTH = 60 -- land with buildings between the ring road and the map edge

TownLayout.STREETS_X = { -360, -180, 0, 180, 360 } -- where the north-south streets are
TownLayout.STREETS_Z = { -270, -90, 90, 270 } -- where the east-west streets are

-- A crossing kept flat and empty for the roundabout added in PRD-005.
TownLayout.ROUNDABOUT = { x = 180, z = 90, halfSize = 55 }
TownLayout.ROUNDABOUT_SPACE = Rect.inset(
	Rect.new(TownLayout.ROUNDABOUT.x, TownLayout.ROUNDABOUT.z, TownLayout.ROUNDABOUT.x, TownLayout.ROUNDABOUT.z),
	-TownLayout.ROUNDABOUT.halfSize
)

local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local SIDEWALK = TownLayout.SIDEWALK_WIDTH
local STREETS_X = TownLayout.STREETS_X
local STREETS_Z = TownLayout.STREETS_Z

-- The outside edge of the ring road.
local RING = Rect.new(
	STREETS_X[1] - HALF_ROAD,
	STREETS_Z[1] - HALF_ROAD,
	STREETS_X[#STREETS_X] + HALF_ROAD,
	STREETS_Z[#STREETS_Z] + HALF_ROAD
)

-- The whole map. Invisible walls stand along its edges.
TownLayout.BOUNDS = Rect.inset(RING, -TownLayout.BORDER_WIDTH)

-- The school (PRD-003) fills the block between x = -180 and x = 0, south of z = 90. Its building faces the
-- school zone street at x = 0.
TownLayout.SCHOOL_BLOCK = Rect.new(-180 + HALF_ROAD, 90 + HALF_ROAD, 0 - HALF_ROAD, 270 - HALF_ROAD)
TownLayout.SCHOOL_BUILDING = Rect.new(-75, 128, -35, 232)

-- Zebra crosswalks (PRD-004), all in the middle of a block, away from traffic lights. Each is on a street (along X
-- or along Z, at `at`) and centered at `along` on it. The first is in the school zone, in front of the school.
TownLayout.CROSSWALK_WIDTH = 12
TownLayout.CROSSWALKS = {
	{ alongX = false, at = 0, along = 150 },
	{ alongX = true, at = -90, along = -120 },
	{ alongX = true, at = 90, along = 60 },
	{ alongX = false, at = -180, along = -210 },
}

-- Every street, from one side of the ring road to the other.
function TownLayout.streets(): { Street }
	local streets = {}
	for _, z in STREETS_Z do
		table.insert(streets, { alongX = true, at = z, from = STREETS_X[1], to = STREETS_X[#STREETS_X] })
	end
	for _, x in STREETS_X do
		table.insert(streets, { alongX = false, at = x, from = STREETS_Z[1], to = STREETS_Z[#STREETS_Z] })
	end
	return streets
end

local segmentList: { Street }? = nil

-- The pieces of street between two neighboring crossings. The list is shared, so don't change it.
function TownLayout.segments(): { Street }
	if segmentList then
		return segmentList
	end
	local segments = {}
	for _, z in STREETS_Z do
		for i = 1, #STREETS_X - 1 do
			table.insert(segments, { alongX = true, at = z, from = STREETS_X[i], to = STREETS_X[i + 1] })
		end
	end
	for _, x in STREETS_X do
		for i = 1, #STREETS_Z - 1 do
			table.insert(segments, { alongX = false, at = x, from = STREETS_Z[i], to = STREETS_Z[i + 1] })
		end
	end
	segmentList = segments
	return segments
end

-- Where the road between the two crossings of `segment` starts and ends: at the edge of each crossing, or of the
-- roundabout space.
function TownLayout.segmentEnds(segment: Street): (number, number)
	local function clearance(along: number): number
		local x, z = segment.at, along
		if segment.alongX then
			x, z = along, segment.at
		end
		return if Rect.contains(TownLayout.ROUNDABOUT_SPACE, x, z) then TownLayout.ROUNDABOUT.halfSize else HALF_ROAD
	end
	return segment.from + clearance(segment.from), segment.to - clearance(segment.to)
end

-- The segment (an index into TownLayout.segments()) whose road the point is on, and how far along the street it
-- is. Crossings and the roundabout space are not part of any segment, so they return nil.
function TownLayout.segmentAt(x: number, z: number): (number?, number)
	for index, segment in TownLayout.segments() do
		local along, across = z, x
		if segment.alongX then
			along, across = x, z
		end
		local first, last = TownLayout.segmentEnds(segment)
		if math.abs(across - segment.at) <= HALF_ROAD and along > first and along < last then
			return index, along
		end
	end
	return nil, 0
end

-- Crossings where four streets meet, not counting the ring road or the roundabout space.
function TownLayout.fourWayCrossings(): { { x: number, z: number } }
	local crossings = {}
	for i = 2, #STREETS_X - 1 do
		for j = 2, #STREETS_Z - 1 do
			local x, z = STREETS_X[i], STREETS_Z[j]
			if not Rect.contains(TownLayout.ROUNDABOUT_SPACE, x, z) then
				table.insert(crossings, { x = x, z = z })
			end
		end
	end
	return crossings
end

-- The blocks between streets, then the border land around the ring road.
function TownLayout.lots(): { Lot }
	local lots = {}
	local roundabout = TownLayout.ROUNDABOUT_SPACE
	for i = 1, #STREETS_X - 1 do
		for j = 1, #STREETS_Z - 1 do
			local block = Rect.new(
				STREETS_X[i] + HALF_ROAD,
				STREETS_Z[j] + HALF_ROAD,
				STREETS_X[i + 1] - HALF_ROAD,
				STREETS_Z[j + 1] - HALF_ROAD
			)
			-- Blocks next to the roundabout space lose a corner, and their sidewalk goes around it.
			table.insert(lots, {
				pieces = Rect.subtract(block, roundabout),
				inner = Rect.subtract(Rect.inset(block, SIDEWALK), Rect.inset(roundabout, -SIDEWALK)),
				treeLine = Rect.inset(block, SIDEWALK / 2),
				keepClear = Rect.inset(roundabout, -SIDEWALK),
			})
		end
	end

	table.insert(lots, {
		pieces = Rect.subtract(TownLayout.BOUNDS, RING),
		inner = Rect.subtract(TownLayout.BOUNDS, Rect.inset(RING, -SIDEWALK)),
		treeLine = Rect.inset(RING, -SIDEWALK / 2),
		keepClear = nil,
	})
	return lots
end

-- True if the point is on the road: inside the map and not on a sidewalk or a block.
function TownLayout.isOnRoad(x: number, z: number): boolean
	if not Rect.contains(TownLayout.BOUNDS, x, z) then
		return false
	end
	for _, lot in TownLayout.lots() do
		for _, piece in lot.pieces do
			if Rect.contains(piece, x, z) then
				return false
			end
		end
	end
	return true
end

-- The pose `offset` studs to the right of the street's center line, at `along` on the street, facing `direction`
-- (1 toward `to`, -1 toward `from`). Cars drive on the right, so offset LANE_WIDTH / 2 is the center of the lane.
function TownLayout.lanePose(street: Street, along: number, direction: number, offset: number): Pose
	local dirX, dirZ = 0, direction
	local x, z = street.at, along
	if street.alongX then
		dirX, dirZ = direction, 0
		x, z = along, street.at
	end
	-- Seen from above, the right-hand side of direction (dirX, dirZ) is (-dirZ, dirX).
	return { x = x - dirZ * offset, z = z + dirX * offset, dirX = dirX, dirZ = dirZ }
end

local spawnSpots: { Pose }? = nil

-- Where the car of the player in spawn slot `slot` (1, 2, 3, ...) starts: in the middle of a street, in the lane
-- for traffic, with the lowest slots closest to the town center. Every slot gets its own spot until they run out.
function TownLayout.spawnPose(slot: number): Pose
	if not spawnSpots then
		local spots = {}
		for _, segment in TownLayout.segments() do
			local middle = (segment.from + segment.to) / 2
			for _, direction in { 1, -1 } do
				local pose = TownLayout.lanePose(segment, middle, direction, TownLayout.LANE_WIDTH / 2)
				if not Rect.contains(TownLayout.ROUNDABOUT_SPACE, pose.x, pose.z) then
					table.insert(spots, pose)
				end
			end
		end
		table.sort(spots, function(a: Pose, b: Pose)
			local distanceA, distanceB = a.x * a.x + a.z * a.z, b.x * b.x + b.z * b.z
			if distanceA ~= distanceB then
				return distanceA < distanceB
			end
			if a.x ~= b.x then
				return a.x < b.x
			end
			return a.z < b.z
		end)
		spawnSpots = spots
	end
	local spots = spawnSpots :: { Pose }
	return spots[(slot - 1) % #spots + 1]
end

-- Where "Reset car" puts a car that is at (x, z) and facing (dirX, dirZ): on the nearest street, in the lane that
-- goes the way the car was facing. A street the car is facing along wins over a slightly closer street across it,
-- so resetting in the middle of a crossing doesn't spin the car sideways.
function TownLayout.resetPose(x: number, z: number, dirX: number, dirZ: number): Pose
	local length = math.sqrt(dirX * dirX + dirZ * dirZ)
	if length > 1e-6 then
		dirX, dirZ = dirX / length, dirZ / length
	else
		dirX, dirZ = 0, 0
	end

	local best: Street, bestAlong, bestDirection, bestScore = TownLayout.streets()[1], 0, 1, math.huge
	for _, street in TownLayout.streets() do
		local position, across, heading = x, z, dirX
		if not street.alongX then
			position, across, heading = z, x, dirZ
		end
		local along = math.clamp(position, street.from, street.to)
		local distance = math.sqrt((position - along) ^ 2 + (across - street.at) ^ 2)
		local score = distance + (1 - math.abs(heading)) * HALF_ROAD
		if score < bestScore then
			best, bestAlong, bestScore = street, along, score
			bestDirection = if heading < 0 then -1 else 1
		end
	end
	return TownLayout.lanePose(best, bestAlong, bestDirection, TownLayout.LANE_WIDTH / 2)
end

return TownLayout
