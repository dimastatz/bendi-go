local TestKit = require("../TestKit")
local Junctions = require("../../src/core/Junctions")
local NpcTraffic = require("../../src/core/NpcTraffic")
local Path = require("../../src/core/Path")
local RedLightRule = require("../../src/core/RedLightRule")
local SpeedZones = require("../../src/core/SpeedZones")
local TownLayout = require("../../src/core/TownLayout")
local TrafficLight = require("../../src/core/TrafficLight")
local Units = require("../../src/core/Units")

local test, expectEqual = TestKit.test, TestKit.expectEqual

local IDLE = {}
for index in TownLayout.CROSSWALKS do
	IDLE[index] = { waiting = false, crossing = false }
end

local function countKinds(route): { [string]: number }
	local counts = {}
	for _, stop in route.stops do
		counts[stop.kind] = (counts[stop.kind] or 0) + 1
	end
	return counts
end

print("NpcTraffic")

test("there are 6 to 10 NPC cars, spread out", function()
	local npcs = NpcTraffic.create()
	expectEqual(#npcs >= 6 and #npcs <= 10, true)
	for i = 1, #npcs do
		for j = i + 1, #npcs do
			local distance = math.sqrt((npcs[i].x - npcs[j].x) ^ 2 + (npcs[i].z - npcs[j].z) ^ 2)
			expectEqual(distance >= 30, true)
		end
	end
end)

test("routes stay on the road and off the roundabout's island", function()
	for _, route in NpcTraffic.routes() do
		local path = route.path
		for index = 1, #path.xs do
			local x, z = path.xs[index], path.zs[index]
			if not TownLayout.isOnRoad(x, z) then
				error(`route leaves the road at {x}, {z}`)
			end
			local fromCenter = math.sqrt((x - Junctions.CENTER_X) ^ 2 + (z - Junctions.CENTER_Z) ^ 2)
			expectEqual(fromCenter > Junctions.ISLAND_RADIUS + 3, true)
		end
	end
end)

test("routes keep clear of the roundabout's splitter islands", function()
	for _, route in NpcTraffic.routes() do
		local path = route.path
		for index = 1, #path.xs do
			local dx, dz = path.xs[index] - Junctions.CENTER_X, path.zs[index] - Junctions.CENTER_Z
			-- Splitters run along each leg, 34 to 52 studs from the center, 1.2 studs each side of the center line.
			-- A car is 3.5 studs wide on each side of its path.
			if math.abs(dx) >= 34 and math.abs(dx) <= 52 then
				expectEqual(math.abs(dz) >= 1.2 + 3.5, true)
			end
			if math.abs(dz) >= 34 and math.abs(dz) <= 52 then
				expectEqual(math.abs(dx) >= 1.2 + 3.5, true)
			end
		end
	end
end)

test("routes find the lights, crosswalks, and roundabout entrances they pass", function()
	local counts = countKinds(NpcTraffic.routes()[1])
	expectEqual(counts.light, 2)
	expectEqual(counts.crosswalk, 1)
	expectEqual(counts.yield, 1)
	expectEqual(countKinds(NpcTraffic.routes()[2]).yield, 1)
	expectEqual(countKinds(NpcTraffic.routes()[4]).light, 4)
end)

test("route speeds stay under the speed limit", function()
	for _, route in NpcTraffic.routes() do
		for index, speed in route.speeds do
			local limit = SpeedZones.limitAt(route.path.xs[index], route.path.zs[index]) or SpeedZones.TOWN_LIMIT
			expectEqual(Units.studsPerSecondToKmh(speed) <= limit, true)
		end
	end
end)

test("routes that turn left are refused", function()
	-- Clockwise around a block (seen from above) is all right turns.
	local ok = pcall(NpcTraffic.buildRoute, { { 0, -90 }, { 0, 90 }, { -180, 90 }, { -180, -90 } })
	expectEqual(ok, true)
	local err
	ok, err = pcall(NpcTraffic.buildRoute, { { -180, -90 }, { -180, 90 }, { 0, 90 }, { 0, -90 } })
	expectEqual(ok, false)
	expectEqual(string.find(tostring(err), "only turn right") ~= nil, true)
end)

test("30 minutes of driving: no crashes, nobody stuck, no red lights run, no speeding", function()
	local npcs = NpcTraffic.create()
	local routes = NpcTraffic.routes()
	local dt = 0.25
	local lastMoved = {}
	local lastDistance = {}
	for index, npc in npcs do
		lastMoved[index] = 0
		lastDistance[index] = npc.distance
	end

	for tick = 1, 30 * 60 / dt do
		local now = tick * dt
		local before = {}
		for index, npc in npcs do
			before[index] = npc.distance
		end
		NpcTraffic.step(npcs, {}, IDLE, now, dt)

		for index, npc in npcs do
			local route = routes[npc.route]
			-- Never past a stop line while its light says stop.
			for _, stop in route.stops do
				if stop.kind == "light" then
					local passed = (stop.distance - before[index]) % route.path.total
					local moved = (npc.distance - before[index]) % route.path.total
					if
						passed > 0
						and passed <= moved
						and TrafficLight.isStop(RedLightRule.lightFor(stop.approach, now))
					then
						error(`NPC {index} ran a red light at {now}`)
					end
				end
			end
			local limit = SpeedZones.limitAt(npc.x, npc.z) or SpeedZones.TOWN_LIMIT
			if Units.studsPerSecondToKmh(npc.speed) > limit then
				error(`NPC {index} speeding: {Units.studsPerSecondToKmh(npc.speed)} in {limit}`)
			end
			if math.abs(npc.distance - lastDistance[index]) > 20 then
				lastMoved[index] = now
				lastDistance[index] = npc.distance
			end
			if now - lastMoved[index] > 90 then
				error(`NPC {index} stuck at {npc.x}, {npc.z}`)
			end
		end

		for i = 1, #npcs do
			for j = i + 1, #npcs do
				local distance = math.sqrt((npcs[i].x - npcs[j].x) ^ 2 + (npcs[i].z - npcs[j].z) ^ 2)
				if distance < 9 then
					error(`NPCs {i} and {j} crashed at {now}`)
				end
			end
		end
	end
end)

test("an NPC car waits behind a player's car instead of pushing", function()
	local npcs = { NpcTraffic.create()[1] }
	local route = NpcTraffic.routes()[npcs[1].route]
	local x, z, dirX, dirZ = Path.sample(route.path, npcs[1].distance + 40)
	local player = { x = x, z = z, dirX = dirX, dirZ = dirZ, speed = 0 }
	for tick = 1, 200 do
		NpcTraffic.step(npcs, { player }, IDLE, tick * 0.1, 0.1)
	end
	local gap = math.sqrt((npcs[1].x - x) ^ 2 + (npcs[1].z - z) ^ 2)
	expectEqual(gap >= 12 and gap <= 25, true)
	expectEqual(npcs[1].speed, 0)
end)

test("an NPC car stops for someone at a crosswalk", function()
	local busy = table.clone(IDLE)
	busy[3] = { waiting = true, crossing = false }
	local npcs = { NpcTraffic.create()[1] }
	local route = NpcTraffic.routes()[1]
	local crosswalkStop
	for _, stop in route.stops do
		if stop.kind == "crosswalk" then
			crosswalkStop = stop
		end
	end
	npcs[1].distance = (crosswalkStop.distance - 60) % route.path.total
	for tick = 1, 300 do
		NpcTraffic.step(npcs, {}, busy, 1000 + tick * 0.1, 0.1)
	end
	local ahead = (crosswalkStop.distance - npcs[1].distance) % route.path.total
	expectEqual(ahead > 0 and ahead < 20, true)
	expectEqual(npcs[1].speed < 0.5, true)
end)

test("an NPC car gives way to a car already in the roundabout", function()
	local route = NpcTraffic.routes()[1]
	local yieldStop
	for _, stop in route.stops do
		if stop.kind == "yield" then
			yieldStop = stop
		end
	end
	local npcs = { NpcTraffic.create()[1] }
	npcs[1].distance = (yieldStop.distance - 60) % route.path.total
	-- A player's car stopped in the roundabout, just upstream of the east entrance.
	local radians = math.rad(60)
	local player = {
		x = Junctions.CENTER_X + Junctions.LANE_RADIUS * math.cos(radians),
		z = Junctions.CENTER_Z + Junctions.LANE_RADIUS * math.sin(radians),
		dirX = math.sin(radians),
		dirZ = -math.cos(radians),
		speed = 0,
	}
	for tick = 1, 300 do
		NpcTraffic.step(npcs, { player }, IDLE, tick * 0.1, 0.1)
	end
	local ahead = (yieldStop.distance - npcs[1].distance) % route.path.total
	expectEqual(ahead > 0 and ahead < 20, true)
end)

TestKit.finish()
