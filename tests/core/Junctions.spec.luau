local TestKit = require("../TestKit")
local Junctions = require("../../src/core/Junctions")

local test, expectEqual = TestKit.test, TestKit.expectEqual

local CX, CZ = Junctions.CENTER_X, Junctions.CENTER_Z

local function onCircle(angle: number)
	local radians = math.rad(angle)
	local x, z = CX + Junctions.LANE_RADIUS * math.cos(radians), CZ + Junctions.LANE_RADIUS * math.sin(radians)
	-- Counterclockwise seen from above, so the angle goes down: the direction is (sin, -cos).
	return { x = x, z = z, dirX = math.sin(radians), dirZ = -math.cos(radians), speed = 15 }
end

print("Junctions")

test("the roundabout has 4 entrances with give-way lines the same distance from the center", function()
	local entries = Junctions.roundaboutEntries()
	expectEqual(#entries, 4)
	for _, entry in entries do
		local center = if entry.alongX then CX else CZ
		expectEqual((center - entry.line) * entry.direction, Junctions.YIELD_DISTANCE)
		expectEqual(entry.kind, "roundabout")
	end
end)

test("cars just upstream of an entrance are in its zones, cars far around the circle are not", function()
	local east = Junctions.roundaboutEntries()[1]
	expectEqual(Junctions.inZone(east.danger, onCircle(30)), true)
	expectEqual(Junctions.inZone(east.watch, onCircle(80)), true)
	expectEqual(Junctions.inZone(east.danger, onCircle(80)), false)
	expectEqual(Junctions.inZone(east.watch, onCircle(150)), false)
	expectEqual(Junctions.inZone(east.watch, onCircle(-40)), false)
end)

test("cars on the island or outside the circle are not in the roundabout", function()
	local east = Junctions.roundaboutEntries()[1]
	expectEqual(Junctions.inZone(east.watch, { x = CX + 5, z = CZ + 5, dirX = 1, dirZ = 0, speed = 0 }), false)
	expectEqual(Junctions.inZone(east.watch, { x = CX + 50, z = CZ + 40, dirX = 1, dirZ = 0, speed = 0 }), false)
end)

test("the give-way zone is the main street on both sides, for cars coming toward the junction", function()
	local giveWay = Junctions.giveWayApproaches()[1]
	expectEqual(giveWay.line, 270 - Junctions.LINE_DISTANCE)
	local coming = { x = 230, z = 264.5, dirX = -1, dirZ = 0, speed = 20 }
	expectEqual(Junctions.inZone(giveWay.watch, coming), true)
	expectEqual(Junctions.inZone(giveWay.danger, coming), false)
	expectEqual(Junctions.inZone(giveWay.danger, { x = 210, z = 264.5, dirX = -1, dirZ = 0, speed = 20 }), true)
	expectEqual(Junctions.inZone(giveWay.watch, { x = 230, z = 275.5, dirX = 1, dirZ = 0, speed = 20 }), false)
	expectEqual(Junctions.inZone(giveWay.danger, { x = 185, z = 275.5, dirX = 1, dirZ = 0, speed = 20 }), true)
	expectEqual(Junctions.inZone(giveWay.watch, { x = 230, z = 230, dirX = -1, dirZ = 0, speed = 20 }), false)
	expectEqual(Junctions.inZone(giveWay.watch, { x = 300, z = 264.5, dirX = -1, dirZ = 0, speed = 20 }), false)
end)

test("there are two stop sign approaches on the side street", function()
	local stops = Junctions.stopApproaches()
	expectEqual(#stops, 2)
	expectEqual(stops[1].line, -90 - Junctions.LINE_DISTANCE)
	expectEqual(stops[2].line, -90 + Junctions.LINE_DISTANCE)
	expectEqual(#Junctions.yieldApproaches(), 5)
end)

TestKit.finish()
