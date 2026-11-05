local TestKit = require("../TestKit")
local Stars = require("../../src/core/Stars")

local test, expectEqual = TestKit.test, TestKit.expectEqual

print("Stars")

test("a new player has no stars", function()
	expectEqual(Stars.new().total, 0)
end)

test("awarding a star adds one", function()
	local stars = Stars.new()
	expectEqual(Stars.tryAward(stars, "light1", 100, 60), true)
	expectEqual(stars.total, 1)
end)

test("the same key gives no star again before the cooldown ends", function()
	local stars = Stars.new()
	Stars.tryAward(stars, "light1", 100, 60)
	expectEqual(Stars.tryAward(stars, "light1", 159, 60), false)
	expectEqual(stars.total, 1)
	expectEqual(Stars.tryAward(stars, "light1", 160, 60), true)
	expectEqual(stars.total, 2)
end)

test("different keys have their own cooldowns", function()
	local stars = Stars.new()
	Stars.tryAward(stars, "light1", 100, 60)
	expectEqual(Stars.tryAward(stars, "light2", 101, 60), true)
	expectEqual(stars.total, 2)
end)

TestKit.finish()
