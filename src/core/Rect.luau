--!strict
-- Axis-aligned rectangles on the ground (the X/Z plane), used to lay out the town.
-- A rectangle covers minX..maxX and minZ..maxZ, in studs.

export type Rect = { minX: number, minZ: number, maxX: number, maxZ: number }

local Rect = {}

function Rect.new(minX: number, minZ: number, maxX: number, maxZ: number): Rect
	return { minX = minX, minZ = minZ, maxX = maxX, maxZ = maxZ }
end

function Rect.width(rect: Rect): number
	return rect.maxX - rect.minX
end

function Rect.depth(rect: Rect): number
	return rect.maxZ - rect.minZ
end

function Rect.center(rect: Rect): (number, number)
	return (rect.minX + rect.maxX) / 2, (rect.minZ + rect.maxZ) / 2
end

-- Shrinks the rectangle by `amount` on every side. A negative amount grows it.
function Rect.inset(rect: Rect, amount: number): Rect
	return Rect.new(rect.minX + amount, rect.minZ + amount, rect.maxX - amount, rect.maxZ - amount)
end

-- True if the point is inside the rectangle or on its edge.
function Rect.contains(rect: Rect, x: number, z: number): boolean
	return x >= rect.minX and x <= rect.maxX and z >= rect.minZ and z <= rect.maxZ
end

-- True if the two rectangles share some area. Rectangles that only touch along an edge don't overlap.
function Rect.overlaps(a: Rect, b: Rect): boolean
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

-- Returns the parts of `a` that are outside `b`, as up to 4 rectangles that don't overlap each other.
function Rect.subtract(a: Rect, b: Rect): { Rect }
	if not Rect.overlaps(a, b) then
		return { a }
	end

	local pieces = {}
	-- Full-height strips to the left and right of b...
	if b.minX > a.minX then
		table.insert(pieces, Rect.new(a.minX, a.minZ, b.minX, a.maxZ))
	end
	if b.maxX < a.maxX then
		table.insert(pieces, Rect.new(b.maxX, a.minZ, a.maxX, a.maxZ))
	end
	-- ...then the strips above and below b, between those two.
	local minX, maxX = math.max(a.minX, b.minX), math.min(a.maxX, b.maxX)
	if b.minZ > a.minZ then
		table.insert(pieces, Rect.new(minX, a.minZ, maxX, b.minZ))
	end
	if b.maxZ < a.maxZ then
		table.insert(pieces, Rect.new(minX, b.maxZ, maxX, a.maxZ))
	end
	return pieces
end

return Rect
