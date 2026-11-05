local TestKit = require("../TestKit")
local Junctions = require("../../src/core/Junctions")
local YieldRule = require("../../src/core/YieldRule")

local test, expectEqual = TestKit.test, TestKit.expectEqual

local CX, CZ = Junctions.CENTER_X, Junctions.CENTER_Z

local function onCircle(angle: number)
	local radians = math.rad(angle)
	return {
		x = CX + Junctions.LANE_RADIUS * math.cos(radians),
		z = CZ + Junctions.LANE_RADIUS * math.sin(radians),
		dirX = math.sin(radians),
		dirZ = -math.cos(radians),
		speed = 15,
	}
end

-- A player driving west (-X) into the roundabout's east entrance, in the lane at z = 84.5. The give-way line is at
-- x = 216, so the front of the car reaches it when the center is at x = 223.
local function westbound(x: number, speed: number)
	return { x = x, z = 84.5, dirX = -1, dirZ = 0, speed = speed }
end

local function run(state, steps): string
	local happened = {}
	for index, step in steps do
		for _, event in YieldRule.update(state, step[1], index, { npcs = step[2] }) do
			table.insert(happened, if event.kind == "star" then `star:{event.key}:{event.praise}` else event.tip)
		end
	end
	return table.concat(happened, ",")
end

local function experienced()
	local state = YieldRule.newState()
	state.seen.roundabout = true
	state.seen.giveWay = true
	return state
end

print("YieldRule")

test("Bendi explains the roundabout the first time", function()
	expectEqual(run(YieldRule.newState(), { { westbound(250, 10), {} } }), "roundaboutFirst")
end)

test("entering an empty roundabout earns a star", function()
	local result = run(experienced(), { { westbound(250, 10), {} }, { westbound(220, 10), {} } })
	expectEqual(result, "star:roundabout1:clearRoundabout")
end)

test("waiting for a car in the roundabout, then going, earns a star", function()
	local result = run(experienced(), {
		{ westbound(240, 5), { onCircle(70) } },
		{ westbound(230, 0), { onCircle(20) } },
		{ westbound(230, 0), { onCircle(-60) } },
		{ westbound(220, 5), { onCircle(-120) } },
	})
	expectEqual(result, "star:roundabout1:yieldedRoundabout")
end)

test("cutting in front of a car in the roundabout gets a tip and no star", function()
	local result =
		run(experienced(), { { westbound(240, 10), { onCircle(40) } }, { westbound(220, 10), { onCircle(30) } } })
	expectEqual(result, "didntYieldRoundabout")
end)

test("the give-way sign works the same way", function()
	local state = YieldRule.newState()
	local southbound = function(z: number)
		return { x = 174.5, z = z, dirX = 0, dirZ = 1, speed = 10 }
	end
	local coming = { x = 205, z = 264.5, dirX = -1, dirZ = 0, speed = 20 }
	expectEqual(run(state, { { southbound(215), {} }, { southbound(240), { coming } } }), "giveWayFirst,didntGiveWay")
	expectEqual(run(state, { { southbound(215), {} }, { southbound(240), {} } }), "star:giveWay:clearGiveWay")
end)

test("without NPC information, entering counts as clear", function()
	local state = experienced()
	YieldRule.update(state, westbound(250, 10), 0, nil)
	local events = YieldRule.update(state, westbound(220, 10), 1, nil)
	expectEqual((events[1] :: any).praise, "clearRoundabout")
end)

test("backing away or jumping doesn't count as entering", function()
	expectEqual(
		run(experienced(), { { westbound(240, 5), {} }, { westbound(275, 5), {} }, { westbound(290, 5), {} } }),
		""
	)
	expectEqual(run(experienced(), { { westbound(250, 0), {} }, { westbound(200, 0), {} } }), "")
end)

TestKit.finish()
