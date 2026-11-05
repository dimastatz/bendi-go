--!strict
-- The people walking around town (PRD-004, requirements 2, 3, 6, and 7).
-- Each crosswalk has its own walker, who crosses it every 20 to 40 seconds: they walk up to the curb, wait and look
-- both ways, and only step onto the road when no car is too close to stop. If a car comes too close while they're
-- crossing, they step back to the curb they came from, or hurry to the far side if they're past the middle.
-- Other walkers stroll around blocks on the sidewalks and never cross the road.

local Crosswalks = require("./Crosswalks")
local Path = require("./Path")
local Rect = require("./Rect")
local RuleKit = require("./RuleKit")
local TownLayout = require("./TownLayout")

export type Kind = "kid" | "adult" | "senior"
export type Phase = "idle" | "toCurb" | "waiting" | "crossing" | "steppingBack" | "away" | "strolling"

export type Walker = {
	kind: Kind,
	speed: number, -- studs per second
	phase: Phase,
	-- Where to draw the walker, which way they face, and how far their head is turned (-1 to 1).
	x: number,
	z: number,
	dirX: number,
	dirZ: number,
	look: number,
	onRoad: boolean,
	-- Crosswalk walkers: which crosswalk, which sidewalk they're on (-1 or 1), and where they are on it.
	crosswalk: number?,
	side: number,
	across: number,
	along: number,
	timer: number,
	nextCrossing: number,
	-- Strolling walkers follow a path around a block.
	path: Path.Path?,
	distance: number,
}

export type Status = { waiting: boolean, crossing: boolean }

local Walkers = {}

-- About 1.4 m/s for kids and adults, and a slower 0.85 m/s for older people.
Walkers.SPEEDS = { kid = 5, adult = 4.5, senior = 3 }
Walkers.MIN_INTERVAL = 20 -- seconds between crossings at a crosswalk
Walkers.MAX_INTERVAL = 40
Walkers.LOOK_TIME = 0.8 -- seconds looking each way before crossing

-- Who crosses at each crosswalk. Kids cross in front of the school.
Walkers.CROSSWALK_KINDS = { "kid", "adult", "senior", "kid" } :: { Kind }

-- Strolling walkers: the center of the block they walk around, and who they are.
Walkers.STROLLERS = {
	{ x = -90, z = 0, kind = "adult" },
	{ x = -90, z = 180, kind = "kid" },
	{ x = 90, z = -180, kind = "senior" },
	{ x = -270, z = 180, kind = "adult" },
	{ x = 270, z = -180, kind = "kid" },
	{ x = -270, z = -180, kind = "adult" },
} :: { { x: number, z: number, kind: Kind } }

local HALF_ROAD = Crosswalks.HALF_ROAD
local CURB = HALF_ROAD + 0.8 -- where walkers wait, just off the road
Walkers.CURB = CURB
local SPOT_ACROSS = HALF_ROAD + 5 -- where walkers stand on the sidewalk between crossings
local SPOT_ALONG = 14
local HURRY = 1.6 -- how much faster walkers move when getting out of a car's way
local STROLL_INSET = TownLayout.SIDEWALK_WIDTH - 1.5 -- strollers walk on the sidewalk, inside the street trees

local function setPosition(walker: Walker)
	local index = walker.crosswalk :: number
	walker.x, walker.z = Crosswalks.point(index, walker.across, walker.along)
	walker.onRoad = math.abs(walker.across) < HALF_ROAD
end

-- Faces the walker along a direction given in crosswalk coordinates.
local function face(walker: Walker, across: number, along: number)
	local crosswalk = TownLayout.CROSSWALKS[walker.crosswalk :: number]
	if crosswalk.alongX then
		walker.dirX, walker.dirZ = along, across
	else
		walker.dirX, walker.dirZ = across, along
	end
end

-- Moves the walker toward a point on their crosswalk. Returns true once they're there.
local function walkTo(walker: Walker, across: number, along: number, speed: number, dt: number): boolean
	local dAcross, dAlong = across - walker.across, along - walker.along
	local distance = math.sqrt(dAcross * dAcross + dAlong * dAlong)
	local step = speed * dt
	if distance <= step then
		walker.across, walker.along = across, along
		setPosition(walker)
		return true
	end
	walker.across += dAcross / distance * step
	walker.along += dAlong / distance * step
	face(walker, dAcross / distance, dAlong / distance)
	setPosition(walker)
	return false
end

local function strollerPath(x: number, z: number, clockwise: boolean): Path.Path
	for _, lot in TownLayout.lots() do
		for _, piece in lot.pieces do
			if Rect.contains(piece, x, z) then
				local r = Rect.inset(piece, STROLL_INSET)
				local corners = { { r.minX, r.minZ }, { r.maxX, r.minZ }, { r.maxX, r.maxZ }, { r.minX, r.maxZ } }
				if not clockwise then
					corners = { corners[4], corners[3], corners[2], corners[1] }
				end
				return Path.new(corners, true)
			end
		end
	end
	error(`no block at {x}, {z}`)
end

-- Makes everyone. `random` returns a number from 0 to 1.
function Walkers.create(random: () -> number): { Walker }
	local walkers = {}
	for index, kind in Walkers.CROSSWALK_KINDS do
		local walker: Walker = {
			kind = kind,
			speed = Walkers.SPEEDS[kind],
			phase = "idle",
			x = 0,
			z = 0,
			dirX = 0,
			dirZ = 1,
			look = 0,
			onRoad = false,
			crosswalk = index,
			side = if index % 2 == 0 then 1 else -1,
			across = 0,
			along = SPOT_ALONG,
			-- Start at different times, so crosswalks don't all get busy at once.
			timer = 2 + random() * 15,
			nextCrossing = 0,
			path = nil,
			distance = 0,
		}
		walker.across = walker.side * SPOT_ACROSS
		face(walker, -walker.side, 0)
		setPosition(walker)
		table.insert(walkers, walker)
	end

	for index, stroller in Walkers.STROLLERS do
		local path = strollerPath(stroller.x, stroller.z, index % 2 == 0)
		local distance = random() * path.total
		local x, z, dirX, dirZ = Path.sample(path, distance)
		local walker: Walker = {
			kind = stroller.kind,
			speed = Walkers.SPEEDS[stroller.kind],
			phase = "strolling",
			x = x,
			z = z,
			dirX = dirX,
			dirZ = dirZ,
			look = 0,
			onRoad = false,
			crosswalk = nil,
			side = 1,
			across = 0,
			along = 0,
			timer = 0,
			nextCrossing = 0,
			path = path,
			distance = distance,
		}
		table.insert(walkers, walker)
	end
	return walkers
end

local function stepCrosser(walker: Walker, cars: { RuleKit.Car }, now: number, dt: number, random: () -> number)
	local index = walker.crosswalk :: number
	local side = walker.side
	local speed = walker.speed

	if walker.phase == "idle" then
		walker.timer -= dt
		if walker.timer <= 0 then
			walker.phase = "toCurb"
		end
	elseif walker.phase == "toCurb" then
		if walkTo(walker, side * CURB, 0, speed, dt) then
			walker.phase = "waiting"
			walker.timer = 0
		end
	elseif walker.phase == "waiting" then
		face(walker, -side, 0)
		walker.timer += dt
		-- Look one way, then the other.
		walker.look = if walker.timer % (2 * Walkers.LOOK_TIME) < Walkers.LOOK_TIME then -1 else 1
		if walker.timer >= 2 * Walkers.LOOK_TIME and Crosswalks.isClear(index, cars) then
			walker.phase = "crossing"
			walker.look = 0
			local interval = Walkers.MIN_INTERVAL + random() * (Walkers.MAX_INTERVAL - Walkers.MIN_INTERVAL)
			walker.nextCrossing = now + interval
		end
	elseif walker.phase == "crossing" then
		-- How far across they are: 0 at the near curb, 1 at the far one.
		local progress = (CURB - side * walker.across) / (2 * CURB)
		local danger = not Crosswalks.isClear(index, cars)
		if danger and progress < 0.5 then
			walker.phase = "steppingBack"
		elseif walkTo(walker, -side * CURB, 0, if danger then speed * HURRY else speed, dt) then
			walker.phase = "away"
		end
	elseif walker.phase == "steppingBack" then
		if walkTo(walker, side * CURB, 0, speed * HURRY, dt) then
			walker.phase = "waiting"
			walker.timer = 0
		end
	elseif walker.phase == "away" then
		if walkTo(walker, -side * SPOT_ACROSS, side * SPOT_ALONG, speed, dt) then
			walker.side = -side
			walker.phase = "idle"
			face(walker, side, 0)
			-- Wait on this side until it's nearly time for the next crossing.
			local walkBack = math.sqrt((SPOT_ACROSS - CURB) ^ 2 + SPOT_ALONG ^ 2) / speed
			walker.timer = math.max(1, walker.nextCrossing - now - walkBack)
		end
	end
end

-- Moves everyone forward by `dt` seconds. `cars` are all the cars in town, players' and NPCs'.
function Walkers.step(walkers: { Walker }, cars: { RuleKit.Car }, now: number, dt: number, random: () -> number)
	for _, walker in walkers do
		if walker.crosswalk then
			stepCrosser(walker, cars, now, dt, random)
		else
			local path = walker.path :: Path.Path
			walker.distance += walker.speed * dt
			walker.x, walker.z, walker.dirX, walker.dirZ = Path.sample(path, walker.distance)
		end
	end
end

-- What's happening at each crosswalk: is someone waiting to cross, and is someone on the road.
function Walkers.status(walkers: { Walker }): { Status }
	local statuses = {}
	for index in TownLayout.CROSSWALKS do
		statuses[index] = { waiting = false, crossing = false }
	end
	for _, walker in walkers do
		local index = walker.crosswalk
		if index then
			local status = statuses[index]
			status.waiting = status.waiting or walker.phase == "waiting" or walker.phase == "steppingBack"
			status.crossing = status.crossing or walker.onRoad
		end
	end
	return statuses
end

return Walkers
