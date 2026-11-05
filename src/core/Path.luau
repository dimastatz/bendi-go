--!strict
-- A path made of straight pieces between points, for things that move along a route: pedestrians walking around
-- a block, and NPC cars driving through town. A closed path loops back to its first point.

export type Path = { xs: { number }, zs: { number }, distances: { number }, total: number, closed: boolean }

local Path = {}

-- Makes a path through `points`, each { x, z }.
function Path.new(points: { { number } }, closed: boolean): Path
	local xs, zs, distances = {}, {}, {}
	local total = 0
	for index, point in points do
		if index > 1 then
			total += math.sqrt((point[1] - xs[index - 1]) ^ 2 + (point[2] - zs[index - 1]) ^ 2)
		end
		xs[index], zs[index], distances[index] = point[1], point[2], total
	end
	if closed then
		local count = #points
		total += math.sqrt((xs[1] - xs[count]) ^ 2 + (zs[1] - zs[count]) ^ 2)
		table.insert(xs, xs[1])
		table.insert(zs, zs[1])
		table.insert(distances, total)
	end
	return { xs = xs, zs = zs, distances = distances, total = total, closed = closed }
end

-- The position `distance` studs along the path and the direction of travel there. A closed path wraps around, and
-- an open one stops at its ends.
function Path.sample(path: Path, distance: number): (number, number, number, number)
	local d = if path.closed then distance % path.total else math.clamp(distance, 0, path.total)
	local distances = path.distances

	-- Find the piece that contains d.
	local low, high = 1, #distances - 1
	while low < high do
		local middle = (low + high + 1) // 2
		if distances[middle] <= d then
			low = middle
		else
			high = middle - 1
		end
	end

	local x1, z1, x2, z2 = path.xs[low], path.zs[low], path.xs[low + 1], path.zs[low + 1]
	local length = distances[low + 1] - distances[low]
	local t = if length > 0 then (d - distances[low]) / length else 0
	local dirX, dirZ = 0, 0
	if length > 0 then
		dirX, dirZ = (x2 - x1) / length, (z2 - z1) / length
	end
	return x1 + (x2 - x1) * t, z1 + (z2 - z1) * t, dirX, dirZ
end

return Path
