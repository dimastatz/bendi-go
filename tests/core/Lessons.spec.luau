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

test("there are five lessons, then the driving test, then the missions, numbered in order", function()
	expectEqual(#Lessons.LIST > 6, true)
	for index, item in Lessons.LIST do
		expectEqual(item.number, index)
		expectEqual(item.isTest, index == 6)
		expectEqual(item.mission, index > 6)
		expectEqual(Strings.TEXT[item.title] ~= nil, true)
		expectEqual(Strings.TEXT[item.intro] ~= nil, true)
	end
	expectEqual(Lessons.LIST[1].id, "basics")
	expectEqual(Lessons.LIST[6].id, "test")
end)

test("there are seven levels, in order, each with a name and sessions", function()
	expectEqual(#Lessons.LEVELS, 7)
	for index, level in Lessons.LEVELS do
		expectEqual(level.number, index)
		expectEqual(Strings.TEXT[level.title] ~= nil, true)
		local sessions = Lessons.inLevel(index)
		expectEqual(#sessions >= (if index >= 4 then 2 else 1), true)
		for _, item in sessions do
			expectEqual(item.mission, index >= 4)
		end
	end
	expectEqual(#Lessons.inLevel(8), 0)
end)

test("sessions come in level order, and lessons 1-2, 3-4, and 5 with the test make the first three levels", function()
	local previous = 1
	for _, item in Lessons.LIST do
		expectEqual(item.level >= previous, true)
		previous = item.level
	end
	local ids = {}
	for level = 1, 3 do
		for _, item in Lessons.inLevel(level) do
			table.insert(ids, item.id)
		end
	end
	expectEqual(table.concat(ids, " "), "basics lights speed crosswalks junctions test")
end)

test("busy missions are level 5, night missions level 6, and expert missions level 7", function()
	for _, item in Lessons.LIST do
		expectEqual(item.busy == true, item.level == 5)
		expectEqual(item.night == true, item.level == 6)
		expectEqual(item.expert == true, item.level == 7)
	end
end)

test("lessons need 3 stars, the test needs every rule, and every goal has its text", function()
	for _, item in Lessons.LIST do
		local goal = item.goal
		if not item.mission and not item.isTest then
			expectEqual(goal.kind, "stars")
			expectEqual(goal.count, Lessons.PASS_STARS)
		end
		if goal.kind == "rule" then
			expectEqual(Strings.TEXT[Lessons.RULE_GOALS[goal.rule :: string]] ~= nil, true)
		end
		if goal.kind == "stars" or goal.kind == "rule" then
			expectEqual((goal.count :: number) > 0, true)
		else
			expectEqual(goal.count, nil)
		end
	end
	expectEqual(lesson("test").goal.kind, "clean")
	for _, key in Lessons.RULE_GOALS do
		expectEqual(Strings.TEXT[key] ~= nil, true)
	end
end)

test("goal text names the goal and fills in its count", function()
	local key, values = Lessons.goalText({ kind = "rule", rule = "light", count = 3 })
	expectEqual(key, "goalLight")
	expectEqual(values.count, 3)
	key, values = Lessons.goalText({ kind = "stars", count = 4 })
	expectEqual(key, "goalStars")
	expectEqual(values.count, 4)
	expectEqual((Lessons.goalText({ kind = "clean" })), "goalClean")
	expectEqual((Lessons.goalText({ kind = "finish" })), "goalFinish")
	for _, item in Lessons.LIST do
		expectEqual(Strings.TEXT[(Lessons.goalText(item.goal))] ~= nil, true)
	end
end)

-- How many different places on the route give a star for `rule`.
local function placesFor(item: Lessons.Lesson, rule: string): number
	local count = 0
	if rule == "light" then
		for _, crossing in Config.CROSSINGS do
			count += if passes(item, crossing.x, crossing.z) then 1 else 0
		end
	elseif rule == "crosswalk" then
		for _, crosswalk in TownLayout.CROSSWALKS do
			local x, z = crosswalk.at, crosswalk.along
			if crosswalk.alongX then
				x, z = crosswalk.along, crosswalk.at
			end
			count += if passes(item, x, z) then 1 else 0
		end
	elseif rule == "segment" then
		-- A street segment counts when one piece of the route drives all of it.
		for _, segment in TownLayout.segments() do
			for index = 1, #item.nodes - 1 do
				local from, to = item.nodes[index], item.nodes[index + 1]
				local alongX = from[2] == to[2]
				local at = if alongX then from[2] else from[1]
				local a, b = if alongX then from[1] else from[2], if alongX then to[1] else to[2]
				if
					segment.alongX == alongX
					and segment.at == at
					and math.min(a, b) <= segment.from
					and math.max(a, b) >= segment.to
				then
					count += 1
				end
			end
		end
	elseif rule == "roundabout" then
		local sides = {}
		for index = 2, #item.nodes - 1 do
			local node, before = item.nodes[index], item.nodes[index - 1]
			if node[1] == Junctions.CENTER_X and node[2] == Junctions.CENTER_Z then
				sides[`{math.sign(node[1] - before[1])},{math.sign(node[2] - before[2])}`] = true
			end
		end
		for _ in sides do
			count += 1
		end
	end
	return count
end

test("every goal about one rule can be reached on its route", function()
	for _, item in Lessons.LIST do
		local goal = item.goal
		if goal.kind == "rule" then
			local places = placesFor(item, goal.rule :: string)
			if places < (goal.count :: number) then
				error(`{item.id} needs {goal.count} {goal.rule} stars but passes only {places} places`)
			end
		end
	end
end)

test("get and after find lessons by id", function()
	expectEqual(lesson("lights").number, 2)
	expectEqual(Lessons.get("flying"), nil)
	expectEqual((Lessons.after("basics") :: Lessons.Lesson).id, "lights")
	expectEqual((Lessons.after("junctions") :: Lessons.Lesson).id, "test")
	expectEqual((Lessons.after("test") :: Lessons.Lesson).id, "schoolRun")
	expectEqual(Lessons.after(Lessons.LIST[#Lessons.LIST].id), nil)
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
