-- Builds a flat test map: a large asphalt ground with lane lines, so players can feel how fast they're going.
-- PRD-001 step 2 replaces this with the neighborhood.

local TestMap = {}

local GROUND_SIZE = 1024
local LINE_SPACING = 40

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

function TestMap.build()
	local map = Instance.new("Folder")
	map.Name = "TestMap"

	-- The ground's top surface is at Y = 0.
	local ground = makePart(
		"Ground",
		Vector3.new(GROUND_SIZE, 2, GROUND_SIZE),
		Vector3.new(0, -1, 0),
		Color3.fromRGB(70, 72, 76),
		Enum.Material.Asphalt
	)
	ground.Parent = map

	-- Dashed white lines along both axes.
	local lineColor = Color3.fromRGB(235, 235, 235)
	for offset = -GROUND_SIZE / 2 + LINE_SPACING, GROUND_SIZE / 2 - LINE_SPACING, LINE_SPACING do
		local alongZ = makePart(
			"Line",
			Vector3.new(0.6, 0.05, 12),
			Vector3.new(0, 0.025, offset),
			lineColor,
			Enum.Material.SmoothPlastic
		)
		alongZ.CanCollide = false
		alongZ.Parent = map

		local alongX = makePart(
			"Line",
			Vector3.new(12, 0.05, 0.6),
			Vector3.new(offset, 0.025, 0),
			lineColor,
			Enum.Material.SmoothPlastic
		)
		alongX.CanCollide = false
		alongX.Parent = map
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Size = Vector3.new(8, 0.2, 8)
	spawnLocation.Position = Vector3.new(0, 0.1, 30)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Duration = 0
	spawnLocation.Parent = map

	map.Parent = workspace
end

return TestMap
