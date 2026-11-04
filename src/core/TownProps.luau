--!strict
-- Where the town's buildings, trees, and parked cars go. Nothing here is random: a simple hash of each position
-- picks the variety, so the town looks the same every time and tests can check it.

local Rect = require("./Rect")
local TownLayout = require("./TownLayout")

type Rect = Rect.Rect

export type Building = { rect: Rect, floors: number, style: number }
export type Tree = { x: number, z: number, kind: "palm" | "round" }
export type ParkedCar = { pose: TownLayout.Pose, style: number }

local TownProps = {}

TownProps.BUILDING_STYLES = 4 -- the builder has one wall color for each style
TownProps.CAR_STYLES = 5 -- and one paint color for each parked car style
TownProps.MIN_FLOORS = 2
TownProps.MAX_FLOORS = 4

-- Israeli law: no parking within 12 m of a crossing. That's about 43 studs.
TownProps.PARKING_CLEARANCE = 43

local CELL_SIZE = 56 -- land is split into cells about this big, with one building or a garden in each
local BUILDING_GAP = 5 -- space around each building inside its cell
local MIN_BUILDING_SIZE = 24 -- a cell too small for a building this wide becomes a garden
local TREE_SPACING = 28
local CORNER_CLEARANCE = 16 -- no street trees right at a corner, so drivers can see around it
local PARKED_CAR_SPACING = 18

-- A number from 0 to 1008 that depends on the position, used to pick variety.
function TownProps.hash(x: number, z: number): number
	return (math.floor(x) * 92821 + math.floor(z) * 68917) % 1009
end

-- Splits `rect` into a grid of cells of about CELL_SIZE.
local function cells(rect: Rect): { Rect }
	local columns = math.max(1, math.floor(Rect.width(rect) / CELL_SIZE))
	local rows = math.max(1, math.floor(Rect.depth(rect) / CELL_SIZE))
	local cellWidth, cellDepth = Rect.width(rect) / columns, Rect.depth(rect) / rows
	local result = {}
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			local minX, minZ = rect.minX + column * cellWidth, rect.minZ + row * cellDepth
			table.insert(result, Rect.new(minX, minZ, minX + cellWidth, minZ + cellDepth))
		end
	end
	return result
end

local function treeKind(x: number, z: number): "palm" | "round"
	return if TownProps.hash(x, z) % 2 == 0 then "palm" else "round"
end

-- Trees every TREE_SPACING studs along the edges of `line`, skipping corners and anything inside `keepClear`.
local function streetTrees(line: Rect, keepClear: Rect?, trees: { Tree })
	local edges = {
		{ line.minX, line.minZ, line.maxX, line.minZ },
		{ line.minX, line.maxZ, line.maxX, line.maxZ },
		{ line.minX, line.minZ, line.minX, line.maxZ },
		{ line.maxX, line.minZ, line.maxX, line.maxZ },
	}
	for _, edge in edges do
		local x1, z1, x2, z2 = edge[1], edge[2], edge[3], edge[4]
		local length = math.max(x2 - x1, z2 - z1)
		local count = math.floor((length - 2 * CORNER_CLEARANCE) / TREE_SPACING)
		local start = (length - count * TREE_SPACING) / 2
		for i = 0, count do
			local t = (start + i * TREE_SPACING) / length
			local x, z = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
			if not (keepClear and Rect.contains(keepClear, x, z)) then
				table.insert(trees, { x = x, z = z, kind = treeKind(x, z) })
			end
		end
	end
end

-- The buildings and trees on one lot from TownLayout.lots().
function TownProps.forLot(lot: TownLayout.Lot): ({ Building }, { Tree })
	local buildings, trees = {}, {}
	for _, inner in lot.inner do
		for _, cell in cells(inner) do
			local x, z = Rect.center(cell)
			local hash = TownProps.hash(x, z)
			local site = Rect.inset(cell, BUILDING_GAP)
			local tooSmall = Rect.width(site) < MIN_BUILDING_SIZE or Rect.depth(site) < MIN_BUILDING_SIZE
			if tooSmall or hash % 5 == 0 then
				-- A small garden with a tree in the middle.
				table.insert(trees, { x = x, z = z, kind = treeKind(x, z) })
			else
				table.insert(buildings, {
					rect = site,
					floors = TownProps.MIN_FLOORS + hash % (TownProps.MAX_FLOORS - TownProps.MIN_FLOORS + 1),
					style = 1 + hash % TownProps.BUILDING_STYLES,
				})
			end
		end
	end
	streetTrees(lot.treeLine, lot.keepClear, trees)
	return buildings, trees
end

-- Cars parked in the parking strips, facing the way traffic goes on their side of the street.
function TownProps.parkedCars(): { ParkedCar }
	local cars = {}
	local clearance = TownLayout.ROAD_WIDTH / 2 + TownProps.PARKING_CLEARANCE
	local keepClear = Rect.inset(TownLayout.ROUNDABOUT_SPACE, -TownProps.PARKING_CLEARANCE)
	local offset = TownLayout.LANE_WIDTH + TownLayout.PARKING_WIDTH / 2
	for _, segment in TownLayout.segments() do
		local first, last = segment.from + clearance, segment.to - clearance
		for along = first + PARKED_CAR_SPACING / 2, last - PARKED_CAR_SPACING / 2, PARKED_CAR_SPACING do
			for _, direction in { 1, -1 } do
				local pose = TownLayout.lanePose(segment, along, direction, offset)
				local hash = TownProps.hash(pose.x, pose.z)
				if hash % 3 == 0 and not Rect.contains(keepClear, pose.x, pose.z) then
					table.insert(cars, { pose = pose, style = 1 + hash % TownProps.CAR_STYLES })
				end
			end
		end
	end
	return cars
end

return TownProps
