local TestKit = require("../TestKit")
local StopSignRule = require("../../src/core/StopSignRule")

local test, expectEqual = TestKit.test, TestKit.expectEqual

-- A player driving south (+Z) on x = 180 toward the stop line at z = -115, in the lane at x = 174.5. The front of
-- the car reaches the line when the center is at z = -122.
local function southbound(z: number, speed: number)
	return { x = 174.5, z = z, dirX = 0, dirZ = 1, speed = speed }
end

local function run(state, steps): string
	local happened = {}
	for _, step in steps do
		for _, event in StopSignRule.update(state, southbound(step[1], step[2])) do
			table.insert(happened, if event.kind == "star" then `star:{event.key}:{event.praise}` else event.tip)
		end
	end
	return table.concat(happened, ",")
end

local function experienced()
	local state = StopSignRule.newState()
	state.seen = true
	return state
end

print("StopSignRule")

test("Bendi explains the stop sign the first time", function()
	expectEqual(run(StopSignRule.newState(), { { -150, 10 } }), "stopSign")
end)

test("a full stop before the line earns a star, and going on afterward is fine", function()
	expectEqual(run(experienced(), { { -150, 10 }, { -126, 0 }, { -110, 8 } }), "star:stop1:stopPraise")
end)

test("rolling over the line at walking speed gets a tip", function()
	expectEqual(run(experienced(), { { -150, 10 }, { -130, 1.4 }, { -120, 1.4 } }), "rolledStop")
end)

test("backing away or jumping doesn't count", function()
	expectEqual(run(experienced(), { { -150, 10 }, { -185, 5 } }), "")
	expectEqual(run(experienced(), { { -150, 10 }, { -100, 10 } }), "")
end)

TestKit.finish()
