local TestKit = require("../TestKit")
local Config = require("../../src/core/TrafficLightConfig")
local Junctions = require("../../src/core/Junctions")
local Lessons = require("../../src/core/Lessons")
local SpeedZones = require("../../src/core/SpeedZones")
local Strings = require("../../src/core/Strings")
local TownLayout = require("../../src/core/TownLayout")

local test, expectEqual = TestKit.test, TestKit.expectEqual

print("Lessons")

-- True if the lesson's route drives through (x, z), along a street in the given direction if one is given.
local function passes(lesson: Lessons.Lesson, x: number, z: number, dirX: number?, dirZ: number?): boolean
	local nodes = lesson.nodes
	for index = 1, #nodes - 1 do
		local from, to = nodes[index], nodes[index + 1]
		local legX, legZ = math.sign(to[1] - from[1]), math.sign(to[2] - from[2])
		local onLeg = x >= math.min(from[1], to[1])
			and x <= math.max(from[1], to[1])
			and z >= math.min(from[2], to[2])
			and z <= math.max(from[2], to[2])
		if onLeg and (dirX == nil or (legX == dirX and legZ == dirZ)) then
			return true
		end
	end
	return false
end

local function lesson(id: string): Lessons.Lesson
	return assert(Lessons.get(id))
end

test("there are five lessons and then the driving test, numbered in order", function()
	expectEqual(#Lessons.LIST, 6)
	for index, item in Lessons.LIST do
		expectEqual(item.number, index)
		expectEqual(item.isTest, index == 6)
		expectEqual(Strings.TEXT[item.title] ~= nil, true)
		expectEqual(Strings.TEXT[item.intro] ~= nil, true)
	end
	expectEqual(Lessons.LIST[1].id, "basics")
	expectEqual(Lessons.LIST[6].id, "test")
end)

test("get and after find lessons by id", function()
	expectEqual(lesson("lights").number, 2)
	expectEqual(Lessons.get("flying"), nil)
	expectEqual((Lessons.after("basics") :: Lessons.Lesson).id, "lights")
	expectEqual((Lessons.after("junctions") :: Lessons.Lesson).id, "test")
	expectEqual(Lessons.after("test"), nil)
	expectEqual(Lessons.after("flying"), nil)
end)

test("routes are built once and shared", function()
	expectEqual(Lessons.route(lesson("basics")), Lessons.route(lesson("basics")))
end)

test("every route runs along streets, and every checkpoint is on the road", function()
	for _, item in Lessons.LIST do
		for index = 1, #item.nodes - 1 do
			local from, to = item.nodes[index], item.nodes[index + 1]
			if from[1] == to[1] then
				expectEqual(table.find(TownLayout.STREETS_X, from[1]) ~= nil, true)
			else
				expectEqual(table.find(TownLayout.STREETS_Z, from[2]) ~= nil, true)
			end
		end
		for _, checkpoint in Lessons.route(item).checkpoints do
			if not TownLayout.isOnRoad(checkpoint.x, checkpoint.z) then
				error(`{item.id} has a checkpoint off the road at {checkpoint.x}, {checkpoint.z}`)
			end
		end
	end
end)

test("lessons are a few minutes of driving, and the test is the longest route", function()
	local testLength = Lessons.route(lesson("test")).length
	for _, item in Lessons.LIST do
		local length = Lessons.route(item).length
		if length < 1500 or length > 3000 then
			error(`{item.id} is {length} studs long`)
		end
		if not item.isTest and length >= testLength then
			error(`{item.id} is longer than the test`)
		end
	end
end)

test("the first lesson has no traffic lights", function()
	for _, crossing in Config.CROSSINGS do
		expectEqual(passes(lesson("basics"), crossing.x, crossing.z), false)
	end
end)

test("the traffic light lesson and the test go through every traffic light", function()
	for _, id in { "lights", "test" } do
		for _, crossing in Config.CROSSINGS do
			expectEqual(passes(lesson(id), crossing.x, crossing.z), true)
		end
	end
end)

test("the speed lesson and the test drive every 30 km/h street", function()
	for _, id in { "speed", "test" } do
		for _, segment in SpeedZones.SLOW_SEGMENTS do
			local middle = (segment.from + segment.to) / 2
			local x, z = segment.at, middle
			if segment.alongX then
				x, z = middle, segment.at
			end
			expectEqual(passes(lesson(id), x, z), true)
		end
	end
end)

test("the crosswalk lesson crosses every crosswalk, and the test crosses at least three", function()
	local count = 0
	for _, crosswalk in TownLayout.CROSSWALKS do
		local x, z = crosswalk.at, crosswalk.along
		if crosswalk.alongX then
			x, z = crosswalk.along, crosswalk.at
		end
		expectEqual(passes(lesson("crosswalks"), x, z), true)
		if passes(lesson("test"), x, z) then
			count += 1
		end
	end
	expectEqual(count >= 3, true)
end)

test("the junction lesson and the test have the roundabout, both stop signs, and the give-way sign", function()
	local stop, giveWay = Junctions.STOP_CROSSING, Junctions.GIVE_WAY_CROSSING
	for _, id in { "junctions", "test" } do
		local item = lesson(id)
		expectEqual(passes(item, Junctions.CENTER_X, Junctions.CENTER_Z), true)
		for _, approach in Junctions.stopApproaches() do
			expectEqual(passes(item, stop.x, approach.line, 0, approach.direction), true)
		end
		for _, approach in Junctions.giveWayApproaches() do
			expectEqual(passes(item, giveWay.x, approach.line, 0, approach.direction), true)
		end
	end
end)

TestKit.finish()
