--!strict
-- The route of a driving lesson (PRD-006, requirement 2): the checkpoints a player drives through, which the game
-- marks with arrows on the road and dots on the mini-map.
-- A route is given as the points where it turns, and each piece between two points runs along one street. The
-- checkpoints are spread along each piece, in the right-hand lane. Where the route turns, the checkpoint is in the
-- middle of the crossing and points the way to turn. The roundabout has no checkpoints, since cars drive around
-- its island.

local Junctions = require("./Junctions")
local TownLayout = require("./TownLayout")

export type Checkpoint = {
	x: number,
	z: number,
	-- Which way to drive here, as a unit vector along a street.
	dirX: number,
	dirZ: number,
	radius: number, -- the car's center must come this close to count
	turn: boolean,
	piece: number, -- which piece of the route it's on: piece 1 runs from the first point to the second
}

-- Where to go at the next place the route turns (PRD-009, requirement 14). At the roundabout, "right" is the first
-- exit, "straight" the second, and "left" the third.
export type Turn = { way: "left" | "right" | "straight", roundabout: boolean, distance: number }

export type Route = {
	nodes: { { number } },
	checkpoints: { Checkpoint },
	length: number,
	start: TownLayout.Pose,
}

local LessonRoute = {}

LessonRoute.SPACING = 45 -- about how far apart checkpoints are along a street
LessonRoute.RADIUS = 18 -- a checkpoint in a lane counts from anywhere on that side of the road
LessonRoute.TURN_RADIUS = 24
LessonRoute.ROUNDABOUT_CLEAR = Junctions.OUTER_RADIUS + 12 -- no checkpoints this close to the roundabout's center
LessonRoute.LOOKAHEAD = 3 -- a car can skip up to two checkpoints, for example after Reset car

local LANE_OFFSET = TownLayout.LANE_WIDTH / 2

-- The direction from one point to the next, which must be straight along a street.
local function direction(from: { number }, to: { number }): (number, number, number)
	local dx, dz = to[1] - from[1], to[2] - from[2]
	assert((dx == 0) ~= (dz == 0), `route piece from {from[1]}, {from[2]} to {to[1]}, {to[2]} isn't along a street`)
	local length = math.abs(dx) + math.abs(dz)
	return dx / length, dz / length, length
end

local function nearRoundabout(x: number, z: number): boolean
	local dx, dz = x - Junctions.CENTER_X, z - Junctions.CENTER_Z
	return math.sqrt(dx * dx + dz * dz) < LessonRoute.ROUNDABOUT_CLEAR
end

-- Builds the route through `nodes`, each { x, z }.
function LessonRoute.build(nodes: { { number } }): Route
	assert(#nodes >= 2, "a route needs at least two points")
	local checkpoints: { Checkpoint } = {}
	local total = 0

	for index = 1, #nodes - 1 do
		local from, to = nodes[index], nodes[index + 1]
		local dirX, dirZ, length = direction(from, to)
		total += length

		local nextX, nextZ = dirX, dirZ
		if index + 1 < #nodes then
			nextX, nextZ = direction(to, nodes[index + 2])
			assert(nextX ~= -dirX or nextZ ~= -dirZ, `route turns around at {to[1]}, {to[2]}`)
		end

		local steps = math.max(1, math.round(length / LessonRoute.SPACING))
		for step = 1, steps do
			local along = length * step / steps
			local x, z = from[1] + dirX * along, from[2] + dirZ * along
			local checkpoint: Checkpoint
			if step == steps and (nextX ~= dirX or nextZ ~= dirZ) then
				checkpoint = {
					x = x,
					z = z,
					dirX = nextX,
					dirZ = nextZ,
					radius = LessonRoute.TURN_RADIUS,
					turn = true,
					piece = index,
				}
			else
				-- Seen from above, the right-hand side of direction (dirX, dirZ) is (-dirZ, dirX).
				checkpoint = {
					x = x - dirZ * LANE_OFFSET,
					z = z + dirX * LANE_OFFSET,
					dirX = dirX,
					dirZ = dirZ,
					radius = LessonRoute.RADIUS,
					turn = false,
					piece = index,
				}
			end
			if not nearRoundabout(checkpoint.x, checkpoint.z) then
				table.insert(checkpoints, checkpoint)
			end
		end
	end

	local first, second = nodes[1], nodes[2]
	local dirX, dirZ = direction(first, second)
	local start = { x = first[1] - dirZ * LANE_OFFSET, z = first[2] + dirX * LANE_OFFSET, dirX = dirX, dirZ = dirZ }
	return { nodes = nodes, checkpoints = checkpoints, length = total, start = start }
end

-- The checkpoint to drive to next, after the car at (x, z) has been heading for checkpoint `index`. Once the last
-- checkpoint is reached, this is one past the end.
function LessonRoute.advance(route: Route, index: number, x: number, z: number): number
	local reached = index - 1
	local last = math.min(index + LessonRoute.LOOKAHEAD - 1, #route.checkpoints)
	for candidate = index, last do
		local checkpoint = route.checkpoints[candidate]
		if math.sqrt((x - checkpoint.x) ^ 2 + (z - checkpoint.z) ^ 2) <= checkpoint.radius then
			reached = candidate
		end
	end
	return reached + 1
end

local function isRoundabout(node: { number }): boolean
	return node[1] == Junctions.CENTER_X and node[2] == Junctions.CENTER_Z
end

-- The next place the route turns (or goes through the roundabout) that the car at (x, z) hasn't reached yet, while
-- heading for checkpoint `index`. Nil once there are no more turns before the finish.
function LessonRoute.nextTurn(route: Route, index: number, x: number, z: number): Turn?
	local checkpoints, nodes = route.checkpoints, route.nodes
	local checkpoint = checkpoints[index]
	if not checkpoint then
		return nil
	end
	-- Start at the point where the car's piece begins: the roundabout has no checkpoints, so the car can already be
	-- heading for a checkpoint past it. A turn anywhere else at that point was made when its checkpoint was reached.
	for node = math.max(2, checkpoint.piece), #nodes - 1 do
		local before, at, after = nodes[node - 1], nodes[node], nodes[node + 1]
		local inX, inZ = direction(before, at)
		local outX, outZ = direction(at, after)
		local roundabout = isRoundabout(at)
		local turns = inX ~= outX or inZ ~= outZ
		local past = (x - at[1]) * outX + (z - at[2]) * outZ
		local done = if roundabout then past > Junctions.OUTER_RADIUS else node == checkpoint.piece
		if (turns or roundabout) and not done then
			-- Seen from above, turning right means heading toward (-inZ, inX).
			local side = inX * outZ - inZ * outX
			local way: "left" | "right" | "straight" = if side > 0
				then "right"
				elseif side < 0 then "left"
				else "straight"
			local distance = math.sqrt((at[1] - x) ^ 2 + (at[2] - z) ^ 2)
			return { way = way, roundabout = roundabout, distance = distance }
		end
	end
	return nil
end

return LessonRoute
