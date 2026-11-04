local TestKit = require("../TestKit")
local Rect = require("../../src/core/Rect")

local test, expectEqual = TestKit.test, TestKit.expectEqual

local function area(rects: { Rect.Rect }): number
	local total = 0
	for _, rect in rects do
		total += Rect.width(rect) * Rect.depth(rect)
	end
	return total
end

print("Rect")

test("width, depth, and center", function()
	local rect = Rect.new(-2, 1, 6, 5)
	expectEqual(Rect.width(rect), 8)
	expectEqual(Rect.depth(rect), 4)
	local x, z = Rect.center(rect)
	expectEqual(x, 2)
	expectEqual(z, 3)
end)

test("inset shrinks every side, and a negative inset grows it", function()
	local rect = Rect.inset(Rect.new(0, 0, 10, 10), 2)
	expectEqual(rect.minX, 2)
	expectEqual(rect.maxZ, 8)
	expectEqual(Rect.width(Rect.inset(rect, -1)), 8)
end)

test("contains includes the edges", function()
	local rect = Rect.new(0, 0, 10, 10)
	expectEqual(Rect.contains(rect, 5, 5), true)
	expectEqual(Rect.contains(rect, 10, 0), true)
	expectEqual(Rect.contains(rect, 10.1, 5), false)
	expectEqual(Rect.contains(rect, 5, -0.1), false)
end)

test("rectangles that only touch along an edge don't overlap", function()
	local a = Rect.new(0, 0, 10, 10)
	expectEqual(Rect.overlaps(a, Rect.new(5, 5, 15, 15)), true)
	expectEqual(Rect.overlaps(a, Rect.new(10, 0, 20, 10)), false)
	expectEqual(Rect.overlaps(a, Rect.new(0, 11, 10, 20)), false)
end)

test("subtracting a rectangle that doesn't overlap changes nothing", function()
	local a = Rect.new(0, 0, 10, 10)
	local pieces = Rect.subtract(a, Rect.new(20, 20, 30, 30))
	expectEqual(#pieces, 1)
	expectEqual(pieces[1], a)
end)

test("subtracting a corner leaves two pieces", function()
	local pieces = Rect.subtract(Rect.new(0, 0, 10, 10), Rect.new(6, 6, 20, 20))
	expectEqual(#pieces, 2)
	expectEqual(area(pieces), 100 - 16)
end)

test("subtracting a hole in the middle leaves four pieces that don't overlap", function()
	local pieces = Rect.subtract(Rect.new(0, 0, 10, 10), Rect.new(3, 3, 7, 7))
	expectEqual(#pieces, 4)
	expectEqual(area(pieces), 100 - 16)
	for i = 1, #pieces do
		for j = i + 1, #pieces do
			expectEqual(Rect.overlaps(pieces[i], pieces[j]), false)
		end
	end
end)

test("subtracting a bigger rectangle leaves nothing", function()
	expectEqual(#Rect.subtract(Rect.new(2, 2, 4, 4), Rect.new(0, 0, 10, 10)), 0)
end)

TestKit.finish()
