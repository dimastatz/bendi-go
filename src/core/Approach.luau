--!strict
-- A way into a crossing, crosswalk, or roundabout along one street, used by the rules and by the NPC cars.
-- Cars on the street along X (`alongX`) or along Z drive in `direction` (1 or -1) toward a line across their half
-- of the road at `line` on that street. `at` is where the street is on the other axis.

local RuleKit = require("./RuleKit")
local TownLayout = require("./TownLayout")

export type Approach = { alongX: boolean, direction: number, at: number, line: number }

local Approach = {}

local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local MIN_HEADING = 0.5 -- the car must face within about 60 degrees of the approach's direction

-- How far a point is before the approach's line. Negative once it is past the line.
function Approach.distanceBefore(approach: Approach, x: number, z: number): number
	local along = if approach.alongX then x else z
	return (approach.line - along) * approach.direction
end

-- How far right of the street's center line a point is, for traffic going the approach's way.
function Approach.rightOffset(approach: Approach, x: number, z: number): number
	if approach.alongX then
		return (z - approach.at) * approach.direction
	end
	return (approach.at - x) * approach.direction
end

-- True if the car faces the approach's way: within about 60 degrees.
function Approach.facesAlong(approach: Approach, dirX: number, dirZ: number): boolean
	local length = math.sqrt(dirX * dirX + dirZ * dirZ)
	if length < 1e-6 then
		return false
	end
	local heading = (if approach.alongX then dirX else dirZ) / length
	return heading * approach.direction >= MIN_HEADING
end

-- True if the car is on the approach: in the right-hand half of the road, facing the line, and no more than
-- `length` studs before it.
function Approach.contains(approach: Approach, car: RuleKit.Car, length: number): boolean
	local before = Approach.distanceBefore(approach, car.x, car.z)
	if before < 0 or before > length then
		return false
	end
	local right = Approach.rightOffset(approach, car.x, car.z)
	if right < 0 or right > HALF_ROAD then
		return false
	end
	return Approach.facesAlong(approach, car.dirX, car.dirZ)
end

-- A point `along` the approach's street and `right` studs to the right of its center line.
function Approach.point(approach: Approach, along: number, right: number): (number, number)
	if approach.alongX then
		return along, approach.at + approach.direction * right
	end
	return approach.at - approach.direction * right, along
end

return Approach
