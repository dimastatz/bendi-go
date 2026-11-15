--!strict
-- How every curb in town is painted (PRD-007), the Israeli way:
-- - Red and white: no stopping or parking. Painted within 12 m of every crossing, the roundabout, and every
--   crosswalk, the same places TownProps keeps free of parked cars.
-- - Blue and white: paid parking. Painted along the two busy middle streets.
-- - Plain gray: free parking everywhere else.

local TownLayout = require("./TownLayout")
local TownProps = require("./TownProps")

export type Paint = "red" | "blue" | "plain"

-- A stretch of curb along `segment` (from TownLayout.segments()), on the `side` of the road (-1 or 1, which way
-- across the street from its center line), from `from` to `to` along the street.
export type Run = { segment: TownLayout.Street, side: number, from: number, to: number, paint: Paint }

local Curbs = {}

-- Blue and white curbs go along the streets at these z positions (they run along X).
Curbs.PAID_STREETS_Z = { -90, 90 }

Curbs.STRIPE_LENGTH = 4 -- each painted stripe on a red-white or blue-white curb

local function isPaid(segment: TownLayout.Street): boolean
	return segment.alongX and table.find(Curbs.PAID_STREETS_Z, segment.at) ~= nil
end

-- The stretches of `segment`'s road, from `first` to `last`, where stopping isn't allowed, sorted and merged.
local function noStopping(segment: TownLayout.Street, first: number, last: number): { { number } }
	local clearance = TownProps.PARKING_CLEARANCE
	local stretches = { { first, first + clearance }, { last - clearance, last } }
	for _, crosswalk in TownLayout.CROSSWALKS do
		if crosswalk.alongX == segment.alongX and crosswalk.at == segment.at then
			table.insert(stretches, { crosswalk.along - clearance, crosswalk.along + clearance })
		end
	end
	table.sort(stretches, function(a, b)
		return a[1] < b[1]
	end)

	local merged = {}
	for _, stretch in stretches do
		local from, to = math.max(stretch[1], first), math.min(stretch[2], last)
		local previous = merged[#merged]
		if previous and from <= previous[2] then
			previous[2] = math.max(previous[2], to)
		elseif to > from then
			table.insert(merged, { from, to })
		end
	end
	return merged
end

-- Every painted and plain stretch of curb in town. Each side of every segment is covered from end to end.
function Curbs.runs(): { Run }
	local runs = {}
	for _, segment in TownLayout.segments() do
		local first, last = TownLayout.segmentEnds(segment)
		local parking: Paint = if isPaid(segment) then "blue" else "plain"
		for _, side in { -1, 1 } do
			local at = first
			for _, stretch in noStopping(segment, first, last) do
				if stretch[1] > at then
					table.insert(runs, { segment = segment, side = side, from = at, to = stretch[1], paint = parking })
				end
				table.insert(
					runs,
					{ segment = segment, side = side, from = stretch[1], to = stretch[2], paint = "red" }
				)
				at = stretch[2]
			end
			if last > at then
				table.insert(runs, { segment = segment, side = side, from = at, to = last, paint = parking })
			end
		end
	end
	return runs
end

return Curbs
