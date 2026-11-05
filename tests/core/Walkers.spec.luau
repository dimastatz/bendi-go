local TestKit = require("../TestKit")
local Crosswalks = require("../../src/core/Crosswalks")
local TownLayout = require("../../src/core/TownLayout")
local Walkers = require("../../src/core/Walkers")

local test, expectEqual = TestKit.test, TestKit.expectEqual

-- A repeatable stand-in for math.random.
local function makeRandom()
	local seed = 12345
	return function(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
end

-- Crosswalk 3 is on the z = 90 street at x = 60. Eastbound cars keep to z = 95.5.
local function eastbound(x: number, speed: number)
	return { x = x, z = 95.5, dirX = 1, dirZ = 0, speed = speed }
end

local function crosser(walkers: { Walkers.Walker }, index: number): Walkers.Walker
	for _, walker in walkers do
		if walker.crosswalk == index then
			return walker
		end
	end
	error("no walker")
end

local function readyToCross(walker: Walkers.Walker)
	walker.phase = "waiting"
	walker.timer = 2 * Walkers.LOOK_TIME
	walker.across = walker.side * Walkers.CURB
	walker.along = 0
end

print("Walkers")

test("there are 10 people: kids, adults, and an older person who walks slowly", function()
	local walkers = Walkers.create(makeRandom())
	expectEqual(#walkers, 10)
	local kinds = {}
	for _, walker in walkers do
		kinds[walker.kind] = true
	end
	expectEqual(kinds.kid and kinds.adult and kinds.senior, true)
	expectEqual(Walkers.SPEEDS.senior < Walkers.SPEEDS.adult, true)
end)

test("every crosswalk gets a crossing every 20 to 40 seconds when the road is empty", function()
	local random = makeRandom()
	local walkers = Walkers.create(random)
	local starts = {}
	local phases = {}
	for tick = 1, 300 * 10 do
		local now = tick / 10
		Walkers.step(walkers, {}, now, 0.1, random)
		for _, walker in walkers do
			local index = walker.crosswalk
			if index then
				if walker.phase == "crossing" and phases[index] ~= "crossing" then
					starts[index] = starts[index] or {}
					table.insert(starts[index], now)
				end
				phases[index] = walker.phase
			end
		end
	end
	for index in TownLayout.CROSSWALKS do
		local times = starts[index]
		expectEqual(#times >= 6, true)
		for i = 2, #times do
			local gap = times[i] - times[i - 1]
			if gap < Walkers.MIN_INTERVAL or gap > Walkers.MAX_INTERVAL + 5 then
				error(`crosswalk {index} gap {gap}`)
			end
		end
	end
end)

test("strollers stay on the sidewalk", function()
	local random = makeRandom()
	local walkers = Walkers.create(random)
	for tick = 1, 600 do
		Walkers.step(walkers, {}, tick / 2, 0.5, random)
		for _, walker in walkers do
			if not walker.crosswalk and TownLayout.isOnRoad(walker.x, walker.z) then
				error(`stroller on the road at {walker.x}, {walker.z}`)
			end
		end
	end
end)

test("a waiting walker doesn't step out in front of a fast car", function()
	local random = makeRandom()
	local walkers = Walkers.create(random)
	local walker = crosser(walkers, 3)
	readyToCross(walker)
	Walkers.step(walkers, { eastbound(20, 45) }, 0, 0.1, random)
	expectEqual(walker.phase, "waiting")
end)

test("a walker crosses in front of a car that has stopped", function()
	local random = makeRandom()
	local walkers = Walkers.create(random)
	local walker = crosser(walkers, 3)
	readyToCross(walker)
	Walkers.step(walkers, { eastbound(45, 0) }, 0, 0.1, random)
	expectEqual(walker.phase, "crossing")
	Walkers.step(walkers, { eastbound(45, 0) }, 0.1, 0.5, random)
	local statuses = Walkers.status(walkers)
	expectEqual(statuses[3].crossing, true)
end)

test("a walker steps back to the curb if a car comes too close early on", function()
	local random = makeRandom()
	local walkers = Walkers.create(random)
	local walker = crosser(walkers, 3)
	readyToCross(walker)
	Walkers.step(walkers, {}, 0, 0.1, random)
	Walkers.step(walkers, {}, 0.1, 0.5, random)
	expectEqual(walker.phase, "crossing")
	Walkers.step(walkers, { eastbound(30, 45) }, 0.6, 0.1, random)
	expectEqual(walker.phase, "steppingBack")
	expectEqual(Walkers.status(walkers)[3].waiting, true)
	for tick = 1, 50 do
		Walkers.step(walkers, { eastbound(30, 45) }, 0.6 + tick / 10, 0.1, random)
	end
	expectEqual(walker.phase, "waiting")
	expectEqual(walker.onRoad, false)
end)

test("a walker past the middle hurries to the far side instead", function()
	local random = makeRandom()
	local walkers = Walkers.create(random)
	local walker = crosser(walkers, 3)
	readyToCross(walker)
	walker.phase = "crossing"
	walker.across = -walker.side * (Crosswalks.HALF_ROAD - 4)
	Walkers.step(walkers, { eastbound(30, 45) }, 0, 0.1, random)
	expectEqual(walker.phase, "crossing")
	for tick = 1, 20 do
		Walkers.step(walkers, { eastbound(30, 45) }, tick / 10, 0.1, random)
	end
	expectEqual(walker.phase, "away")
end)

test("status shows waiting and crossing for each crosswalk", function()
	local random = makeRandom()
	local walkers = Walkers.create(random)
	local statuses = Walkers.status(walkers)
	expectEqual(#statuses, #TownLayout.CROSSWALKS)
	expectEqual(statuses[3].waiting, false)
	readyToCross(crosser(walkers, 3))
	expectEqual(Walkers.status(walkers)[3].waiting, true)
end)

TestKit.finish()
