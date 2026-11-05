--!strict
-- Crosswalk geometry (PRD-004): where each crosswalk is, the ways cars drive up to it, and whether the road is
-- clear enough for a pedestrian to step onto it.
-- Positions on a crosswalk use `across` (from the street's center line, negative on one sidewalk and positive on
-- the other) and `along` (along the street, from the crosswalk's center).

local Approach = require("./Approach")
local CarPhysics = require("./CarPhysics")
local RuleKit = require("./RuleKit")
local TownLayout = require("./TownLayout")

export type CrosswalkApproach = Approach.Approach & { crosswalk: number }

local Crosswalks = {}

Crosswalks.HALF_ROAD = TownLayout.ROAD_WIDTH / 2
Crosswalks.CAR_HALF_LENGTH = 7 -- from a car's center to its front bumper
Crosswalks.WATCH_DISTANCE = 100 -- cars farther than this from a crosswalk don't matter to pedestrians
Crosswalks.SAFETY_MARGIN = 8 -- extra room on top of a car's braking distance

local HALF_WIDTH = TownLayout.CROSSWALK_WIDTH / 2

-- The world position of a point on crosswalk `index`.
function Crosswalks.point(index: number, across: number, along: number): (number, number)
	local crosswalk = TownLayout.CROSSWALKS[index]
	if crosswalk.alongX then
		return crosswalk.along + along, crosswalk.at + across
	end
	return crosswalk.at + across, crosswalk.along + along
end

-- The two ways cars drive up to each crosswalk. Each approach's line is the near edge of the stripes.
function Crosswalks.approaches(): { CrosswalkApproach }
	local approaches = {}
	for index, crosswalk in TownLayout.CROSSWALKS do
		for _, direction in { 1, -1 } do
			table.insert(approaches, {
				crosswalk = index,
				alongX = crosswalk.alongX,
				direction = direction,
				at = crosswalk.at,
				line = crosswalk.along - direction * HALF_WIDTH,
			})
		end
	end
	return approaches
end

-- The car's front bumper, as a car of its own, so rules can check where the front of the car is.
function Crosswalks.front(car: RuleKit.Car): RuleKit.Car
	local length = math.sqrt(car.dirX * car.dirX + car.dirZ * car.dirZ)
	if length < 1e-6 then
		return car
	end
	local reach = Crosswalks.CAR_HALF_LENGTH / length
	return {
		x = car.x + car.dirX * reach,
		z = car.z + car.dirZ * reach,
		dirX = car.dirX,
		dirZ = car.dirZ,
		speed = car.speed,
	}
end

-- How close a car driving at `speed` can come before it couldn't stop in time.
function Crosswalks.stoppingDistance(speed: number): number
	return speed * speed / (2 * CarPhysics.DEFAULT_TUNING.brakeDeceleration) + Crosswalks.SAFETY_MARGIN
end

-- True if a car is on the stripes of crosswalk `index`.
local function onCrosswalk(index: number, car: RuleKit.Car): boolean
	local crosswalk = TownLayout.CROSSWALKS[index]
	local along, across = car.z, car.x
	if crosswalk.alongX then
		along, across = car.x, car.z
	end
	local reach = HALF_WIDTH + Crosswalks.CAR_HALF_LENGTH
	return math.abs(across - crosswalk.at) <= Crosswalks.HALF_ROAD and math.abs(along - crosswalk.along) < reach
end

-- True if the car is on crosswalk `index`, or its front is less than `distance` studs before it and it's driving
-- toward it.
function Crosswalks.isNear(index: number, car: RuleKit.Car, distance: number): boolean
	if onCrosswalk(index, car) then
		return true
	end
	local front = Crosswalks.front(car)
	for _, approach in Crosswalks.approaches() do
		if approach.crosswalk == index and Approach.contains(approach, front, distance) then
			return true
		end
	end
	return false
end

-- True if no car is on crosswalk `index` and no car coming toward it is too close to stop. A car that has already
-- stopped is no danger, so pedestrians cross in front of it.
function Crosswalks.isClear(index: number, cars: { RuleKit.Car }): boolean
	for _, car in cars do
		if onCrosswalk(index, car) then
			return false
		end
		if math.abs(car.speed) >= RuleKit.STOP_SPEED then
			local front = Crosswalks.front(car)
			for _, approach in Crosswalks.approaches() do
				if approach.crosswalk == index then
					local before = Approach.distanceBefore(approach, front.x, front.z)
					local right = Approach.rightOffset(approach, front.x, front.z)
					local coming = before >= 0
						and before <= Crosswalks.WATCH_DISTANCE
						and math.abs(right) <= Crosswalks.HALF_ROAD
						and Approach.facesAlong(approach, car.dirX, car.dirZ)
					if coming and before < Crosswalks.stoppingDistance(math.abs(car.speed)) then
						return false
					end
				end
			end
		end
	end
	return true
end

return Crosswalks
