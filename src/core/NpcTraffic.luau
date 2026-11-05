--!strict
-- The NPC cars that drive around town (PRD-005, requirements 1 to 3).
-- Each car follows a fixed loop in the right-hand lane. Loops only turn right, go straight, or use the roundabout,
-- so NPC cars never have to cross oncoming traffic, and they only merge with each other at traffic lights (where the
-- lights keep them apart) or at the roundabout (where they give way).
-- NPC cars follow the rules players learn: they stop at red lights, stop for anyone waiting at or on a crosswalk,
-- keep under the speed limit, and give way to cars already in the roundabout. They slow down for any car ahead of
-- them, including players' cars, and wait instead of pushing.

local Approach = require("./Approach")
local Crosswalks = require("./Crosswalks")
local Junctions = require("./Junctions")
local Path = require("./Path")
local RedLightRule = require("./RedLightRule")
local RuleKit = require("./RuleKit")
local SpeedZones = require("./SpeedZones")
local TownLayout = require("./TownLayout")
local Config = require("./TrafficLightConfig")
local TrafficLight = require("./TrafficLight")
local Units = require("./Units")
local Walkers = require("./Walkers")

export type StopKind = "light" | "crosswalk" | "yield"
export type Stop = { distance: number, kind: StopKind, approach: any }
export type Route = { path: Path.Path, stops: { Stop }, speeds: { number } }
export type Npc = {
	route: number,
	distance: number, -- how far along its route's path
	speed: number,
	braking: boolean,
	x: number,
	z: number,
	dirX: number,
	dirZ: number,
}

local NpcTraffic = {}

-- Each loop is a list of crossings, in driving order. It must only turn right, or go through the roundabout.
NpcTraffic.ROUTES = {
	{ count = 2, nodes = { { 0, -90 }, { 180, -90 }, { 360, -90 }, { 360, 90 }, { 180, 90 }, { 0, 90 } } },
	{ count = 2, nodes = { { 180, 90 }, { 360, 90 }, { 360, 270 }, { 180, 270 } } },
	{ count = 1, nodes = { { 0, -90 }, { 180, -90 }, { 180, 90 }, { 0, 90 } } },
	{ count = 2, nodes = { { -180, -90 }, { 0, -90 }, { 0, 90 }, { -180, 90 } } },
	{ count = 1, nodes = { { -360, -90 }, { -180, -90 }, { -180, 90 }, { -360, 90 } } },
}

NpcTraffic.SPACING = 2 -- studs between points on a route's path
NpcTraffic.LIMIT_SHARE = 0.95 -- NPC cars drive a little under the speed limit
NpcTraffic.TURN_GRIP = 12 -- how hard they can take a curve (studs per second squared sideways)
NpcTraffic.COMFORT_BRAKE = 15 -- normal braking, studs per second squared
NpcTraffic.HARD_BRAKE = 40 -- braking for something that appears suddenly
NpcTraffic.ACCELERATION = 10
NpcTraffic.STOP_MARGIN = 8 -- they stop with their center this far before a line, so the front is just behind it
NpcTraffic.FOLLOW_GAP = 17 -- from their center to the center of the car ahead when stopped behind it
NpcTraffic.LOOK_AHEAD = 90 -- they react to stops this far ahead
NpcTraffic.CAR_LOOK_AHEAD = 50 -- and to cars this far ahead
NpcTraffic.CORRIDOR = 4.5 -- a car closer than this to the path ahead is in the way

local HALF_LANE = TownLayout.LANE_WIDTH / 2
local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local TURN_REACH = 20 -- right turns start curving this far before the corner
local ROUNDABOUT_REACH = { 55, 42 } -- lane points before and after the roundabout, from its center
local ARC_STEP = 15 -- degrees between points around the roundabout
local ARC_TRIM = 25 -- degrees the path cuts in from the entrance and exit

local function lanePoint(x: number, z: number, dirX: number, dirZ: number, along: number): { number }
	-- The lane is to the right of the center line: (-dirZ, dirX) seen from above.
	return { x - dirZ * HALF_LANE + dirX * along, z + dirX * HALF_LANE + dirZ * along }
end

local function unit(fromX: number, fromZ: number, toX: number, toZ: number): (number, number)
	local length = math.sqrt((toX - fromX) ^ 2 + (toZ - fromZ) ^ 2)
	return (toX - fromX) / length, (toZ - fromZ) / length
end

-- The corners of the route, before smoothing.
local function keyPoints(nodes: { { number } }): { { number } }
	local points = {}
	local count = #nodes
	for index, node in nodes do
		local previous, following = nodes[(index - 2) % count + 1], nodes[index % count + 1]
		local inX, inZ = unit(previous[1], previous[2], node[1], node[2])
		local outX, outZ = unit(node[1], node[2], following[1], following[2])
		local x, z = node[1], node[2]

		if x == Junctions.CENTER_X and z == Junctions.CENTER_Z then
			-- Into the roundabout, counterclockwise around it, and out.
			table.insert(points, lanePoint(x, z, inX, inZ, -ROUNDABOUT_REACH[1]))
			table.insert(points, lanePoint(x, z, inX, inZ, -ROUNDABOUT_REACH[2]))
			local start = math.deg(math.atan2(-inZ, -inX)) - ARC_TRIM
			local finish = math.deg(math.atan2(outZ, outX)) + ARC_TRIM
			while finish >= start do
				finish -= 360
			end
			local angle = start
			while angle > finish do
				local radians = math.rad(angle)
				table.insert(points, {
					x + Junctions.LANE_RADIUS * math.cos(radians),
					z + Junctions.LANE_RADIUS * math.sin(radians),
				})
				angle -= ARC_STEP
			end
			local radians = math.rad(finish)
			table.insert(
				points,
				{ x + Junctions.LANE_RADIUS * math.cos(radians), z + Junctions.LANE_RADIUS * math.sin(radians) }
			)
			table.insert(points, lanePoint(x, z, outX, outZ, ROUNDABOUT_REACH[2]))
			table.insert(points, lanePoint(x, z, outX, outZ, ROUNDABOUT_REACH[1]))
		elseif math.abs(inX - outX) > 1e-6 or math.abs(inZ - outZ) > 1e-6 then
			assert(math.abs(outX + inZ) < 1e-6 and math.abs(outZ - inX) < 1e-6, "NPC routes may only turn right")
			-- Where the incoming lane meets the outgoing lane, with a curve around it.
			local cornerX = x - inZ * HALF_LANE - outZ * HALF_LANE
			local cornerZ = z + inX * HALF_LANE + outX * HALF_LANE
			table.insert(points, { cornerX - inX * TURN_REACH, cornerZ - inZ * TURN_REACH })
			table.insert(points, { cornerX, cornerZ })
			table.insert(points, { cornerX + outX * TURN_REACH, cornerZ + outZ * TURN_REACH })
		end
	end
	return points
end

-- Rounds the corners of a closed polygon by cutting each one (Chaikin's method).
local function smooth(points: { { number } }, rounds: number): { { number } }
	for _ = 1, rounds do
		local result = {}
		local count = #points
		for index, point in points do
			local following = points[index % count + 1]
			table.insert(result, { point[1] * 0.75 + following[1] * 0.25, point[2] * 0.75 + following[2] * 0.25 })
			table.insert(result, { point[1] * 0.25 + following[1] * 0.75, point[2] * 0.25 + following[2] * 0.75 })
		end
		points = result
	end
	return points
end

-- Points every SPACING studs along a closed path.
local function resample(path: Path.Path): { { number } }
	local points = {}
	local count = math.floor(path.total / NpcTraffic.SPACING)
	for index = 0, count - 1 do
		local x, z = Path.sample(path, index * path.total / count)
		table.insert(points, { x, z })
	end
	return points
end

-- Where the path crosses each line NPC cars may have to stop at.
local function findStops(path: Path.Path): { Stop }
	local candidates: { { kind: StopKind, approach: any } } = {}
	for _, approach in RedLightRule.approaches() do
		table.insert(candidates, { kind = "light" :: StopKind, approach = approach })
	end
	for _, approach in Crosswalks.approaches() do
		table.insert(candidates, { kind = "crosswalk" :: StopKind, approach = approach })
	end
	for _, approach in Junctions.roundaboutEntries() do
		table.insert(candidates, { kind = "yield" :: StopKind, approach = approach })
	end

	local stops = {}
	local xs, zs, distances = path.xs, path.zs, path.distances
	for index = 1, #xs - 1 do
		local dirX, dirZ = xs[index + 1] - xs[index], zs[index + 1] - zs[index]
		for _, candidate in candidates do
			local approach = candidate.approach
			local before = Approach.distanceBefore(approach, xs[index], zs[index])
			local after = Approach.distanceBefore(approach, xs[index + 1], zs[index + 1])
			local right = Approach.rightOffset(approach, xs[index], zs[index])
			local crosses = before >= 0 and after < 0 and right >= 0 and right <= HALF_ROAD
			if crosses and Approach.facesAlong(approach, dirX, dirZ) then
				local share = before / (before - after)
				local distance = distances[index] + share * (distances[index + 1] - distances[index])
				table.insert(stops, { distance = distance, kind = candidate.kind, approach = approach })
			end
		end
	end
	return stops
end

-- The fastest each point of the path can be driven: under the speed limit, slow enough for curves, and slowing
-- down early enough for the next curve.
local function speedProfile(path: Path.Path): { number }
	local xs, zs = path.xs, path.zs
	local count = #xs - 1 -- the last point repeats the first
	local speeds = {}
	local limit = SpeedZones.TOWN_LIMIT
	for index = 1, count do
		local previous = (index - 2) % count + 1
		local following = index % count + 1
		local inAngle = math.atan2(zs[index] - zs[previous], xs[index] - xs[previous])
		local outAngle = math.atan2(zs[following] - zs[index], xs[following] - xs[index])
		local turn = math.abs((outAngle - inAngle + math.pi) % (2 * math.pi) - math.pi)
		local radius = NpcTraffic.SPACING / math.max(turn, 1e-4)
		limit = SpeedZones.limitAt(xs[index], zs[index]) or limit
		local maxSpeed = Units.kmhToStudsPerSecond(limit) * NpcTraffic.LIMIT_SHARE
		speeds[index] = math.min(maxSpeed, math.sqrt(NpcTraffic.TURN_GRIP * radius))
	end
	-- Twice around backward, so slowing down for a curve starts in time even across the start of the loop.
	for _ = 1, 2 do
		for index = count, 1, -1 do
			local following = index % count + 1
			local reachable = math.sqrt(speeds[following] ^ 2 + 2 * NpcTraffic.COMFORT_BRAKE * NpcTraffic.SPACING)
			speeds[index] = math.min(speeds[index], reachable)
		end
	end
	return speeds
end

-- Builds the path, stops, and speeds for a loop through `nodes`.
function NpcTraffic.buildRoute(nodes: { { number } }): Route
	local rough = Path.new(smooth(keyPoints(nodes), 3), true)
	local path = Path.new(resample(rough), true)
	return { path = path, stops = findStops(path), speeds = speedProfile(path) }
end

local routes: { Route }? = nil

-- Every route's path, stops, and speeds. Built once and shared.
function NpcTraffic.routes(): { Route }
	if routes then
		return routes
	end
	local built = {}
	for _, route in NpcTraffic.ROUTES do
		table.insert(built, NpcTraffic.buildRoute(route.nodes))
	end
	routes = built
	return built
end

local function place(npc: Npc)
	local route = NpcTraffic.routes()[npc.route]
	npc.x, npc.z, npc.dirX, npc.dirZ = Path.sample(route.path, npc.distance)
end

-- True if a point is too close to a car (other than `except`) to start a car there.
local function crowded(x: number, z: number, npcs: { Npc }): boolean
	for _, other in npcs do
		if (other.x - x) ^ 2 + (other.z - z) ^ 2 < 30 ^ 2 then
			return true
		end
	end
	for slot = 1, 10 do
		local pose = TownLayout.spawnPose(slot)
		if (pose.x - x) ^ 2 + (pose.z - z) ^ 2 < 30 ^ 2 then
			return true
		end
	end
	return false
end

-- Makes all the NPC cars, spread out along their routes, away from each other and from players' spawn spots.
function NpcTraffic.create(): { Npc }
	local npcs = {}
	for index, route in NpcTraffic.ROUTES do
		local path = NpcTraffic.routes()[index].path
		for number = 1, route.count do
			local npc: Npc = {
				route = index,
				distance = (number - 1) * path.total / route.count + index * 37,
				speed = 0,
				braking = false,
				x = 0,
				z = 0,
				dirX = 0,
				dirZ = 0,
			}
			place(npc)
			while crowded(npc.x, npc.z, npcs) do
				npc.distance += 10
				place(npc)
			end
			table.insert(npcs, npc)
		end
	end
	return npcs
end

-- The speed from the route's profile at `distance`.
local function profileSpeed(route: Route, distance: number): number
	local index = math.floor((distance % route.path.total) / NpcTraffic.SPACING) % #route.speeds + 1
	return route.speeds[index]
end

-- How far ahead along its path the nearest car in the way is, or nil.
local function carAhead(route: Route, npc: Npc, cars: { RuleKit.Car }): number?
	local reach = NpcTraffic.CORRIDOR * NpcTraffic.CORRIDOR
	for ahead = 4, NpcTraffic.CAR_LOOK_AHEAD, 3 do
		local x, z = Path.sample(route.path, npc.distance + ahead)
		for _, car in cars do
			if car ~= npc and (car.x - x) ^ 2 + (car.z - z) ^ 2 < reach then
				return ahead
			end
		end
	end
	return nil
end

-- True if the NPC car has to stop at `stop`, which is `ahead` studs away.
local function mustStop(
	stop: Stop,
	npc: Npc,
	ahead: number,
	cars: { RuleKit.Car },
	crosswalks: { Walkers.Status },
	now: number
): boolean
	-- A car too close to stop before the line keeps going (except at lights: NPC cars never run a red).
	local canStop = ahead - RuleKit.CAR_HALF_LENGTH >= npc.speed * npc.speed / (2 * NpcTraffic.HARD_BRAKE)

	if stop.kind == "light" then
		local approach = stop.approach
		local light, elapsed = TrafficLight.stateAt(now, approach.alongX, Config.CROSSINGS[approach.crossing].offset)
		if TrafficLight.isStop(light) then
			return true
		end
		-- On yellow, only keep going if the car will be past the line before it turns red.
		return light == "yellow" and ahead > npc.speed * (Config.YELLOW - elapsed)
	elseif stop.kind == "crosswalk" then
		local status = crosswalks[stop.approach.crosswalk]
		return canStop and status ~= nil and (status.waiting or status.crossing)
	end
	local others = {}
	for _, car in cars do
		if car ~= npc then
			table.insert(others, car)
		end
	end
	return canStop and Junctions.anyInZone(stop.approach.watch, others)
end

-- Moves every NPC car forward by `dt` seconds. `players` are the players' cars, and `crosswalks` says who is
-- waiting at or crossing each crosswalk.
function NpcTraffic.step(
	npcs: { Npc },
	players: { RuleKit.Car },
	crosswalks: { Walkers.Status }?,
	now: number,
	dt: number
)
	local cars: { RuleKit.Car } = {}
	for _, npc in npcs do
		table.insert(cars, npc :: any)
	end
	for _, car in players do
		table.insert(cars, car)
	end
	local walkers = crosswalks or {}

	for _, npc in npcs do
		local route = NpcTraffic.routes()[npc.route]
		local total = route.path.total
		local desired = profileSpeed(route, npc.distance)

		for _, stop in route.stops do
			local ahead = (stop.distance - npc.distance) % total
			if ahead <= NpcTraffic.LOOK_AHEAD and mustStop(stop, npc, ahead, cars, walkers, now) then
				local room = math.max(0, ahead - NpcTraffic.STOP_MARGIN)
				desired = math.min(desired, math.sqrt(2 * NpcTraffic.COMFORT_BRAKE * room))
			end
		end

		local gap = carAhead(route, npc, cars)
		if gap then
			local room = math.max(0, gap - NpcTraffic.FOLLOW_GAP)
			desired = math.min(desired, math.sqrt(2 * NpcTraffic.COMFORT_BRAKE * room))
		end

		if desired < npc.speed then
			npc.braking = true
			npc.speed = math.max(desired, npc.speed - NpcTraffic.HARD_BRAKE * dt)
		else
			npc.braking = false
			npc.speed = math.min(desired, npc.speed + NpcTraffic.ACCELERATION * dt)
		end
		npc.distance = (npc.distance + npc.speed * dt) % total
	end

	for _, npc in npcs do
		place(npc)
	end
end

return NpcTraffic
