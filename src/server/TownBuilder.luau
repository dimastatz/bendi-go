-- Builds the Bendi Go neighborhood from TownLayout and TownProps: roads with lane markings, sidewalks, buildings,
-- trees, parked cars, and invisible walls at the map edges.
-- Cars only collide with the road, the curbs, parked cars, and the map edges. Everything else is decoration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rect = require(ReplicatedStorage.Core.Rect)
local TownLayout = require(ReplicatedStorage.Core.TownLayout)
local TownProps = require(ReplicatedStorage.Core.TownProps)

local TownBuilder = {}

local CURB_HEIGHT = 0.5
local CURB_WALL_HEIGHT = 8 -- taller than a car, so cars can't climb onto sidewalks
local EDGE_WALL_HEIGHT = 40
local FLOOR_HEIGHT = 11 -- about 3 m
local LINE_WIDTH = 0.6
local DASH_LENGTH = 6
local DASH_GAP = 6
local PALM_HEIGHT = 18
local TREE_HEIGHT = 8

local ASPHALT = Color3.fromRGB(70, 72, 76)
local MARKING = Color3.fromRGB(235, 235, 235)
local SIDEWALK = Color3.fromRGB(196, 190, 180)
local GRASS = Color3.fromRGB(108, 158, 78)
local GLASS = Color3.fromRGB(70, 90, 110)
local WHITE = Color3.fromRGB(245, 245, 240)
local SOLAR_PANEL = Color3.fromRGB(30, 50, 90)
local TRUNK = Color3.fromRGB(115, 85, 60)
local PALM_LEAF = Color3.fromRGB(70, 135, 60)
local TREE_LEAVES = Color3.fromRGB(60, 120, 55)

-- Light stone colors, like the stone-clad apartment buildings in Israeli towns. One per TownProps.BUILDING_STYLES.
local BUILDING_COLORS = {
	Color3.fromRGB(236, 224, 200),
	Color3.fromRGB(226, 208, 176),
	Color3.fromRGB(244, 238, 226),
	Color3.fromRGB(214, 196, 166),
}

-- One per TownProps.CAR_STYLES. Lots of white and silver, like real streets.
local CAR_COLORS = {
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(180, 185, 190),
	Color3.fromRGB(190, 50, 45),
	Color3.fromRGB(40, 40, 45),
	Color3.fromRGB(240, 240, 240),
}

-- Makes an anchored part with collisions off. Callers turn collisions on for the few parts that need them.
local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Makes a part covering `rect`, from height `bottom` up to `bottom + height`.
local function rectPart(
	parent: Instance,
	name: string,
	rect: Rect.Rect,
	bottom: number,
	height: number,
	color: Color3,
	material: Enum.Material
): Part
	local x, z = Rect.center(rect)
	local size = Vector3.new(Rect.width(rect), height, Rect.depth(rect))
	return makePart(parent, name, size, CFrame.new(x, bottom + height / 2, z), color, material)
end

local function folder(parent: Instance, name: string): Folder
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = parent
	return result
end

local function poseCFrame(pose: TownLayout.Pose): CFrame
	local position = Vector3.new(pose.x, 0, pose.z)
	return CFrame.lookAt(position, position + Vector3.new(pose.dirX, 0, pose.dirZ))
end

-- A painted line along `street`, from `from` to `to`, `offset` studs from its center line.
local function paintLine(parent: Instance, street: TownLayout.Street, from: number, to: number, offset: number)
	local length, middle = to - from, (from + to) / 2
	if street.alongX then
		makePart(
			parent,
			"Line",
			Vector3.new(length, 0.05, LINE_WIDTH),
			CFrame.new(middle, 0.025, street.at + offset),
			MARKING,
			Enum.Material.SmoothPlastic
		)
	else
		makePart(
			parent,
			"Line",
			Vector3.new(LINE_WIDTH, 0.05, length),
			CFrame.new(street.at + offset, 0.025, middle),
			MARKING,
			Enum.Material.SmoothPlastic
		)
	end
end

-- How far from a crossing's center the lane markings stop: at the edge of the crossing, or of the roundabout space.
local function markingClearance(street: TownLayout.Street, along: number): number
	local x, z = street.at, along
	if street.alongX then
		x, z = along, street.at
	end
	local halfSize = if Rect.contains(TownLayout.ROUNDABOUT_SPACE, x, z)
		then TownLayout.ROUNDABOUT.halfSize
		else TownLayout.ROAD_WIDTH / 2
	return halfSize + 2
end

local function buildRoads(map: Instance)
	local bounds = TownLayout.BOUNDS
	local road = rectPart(map, "Road", bounds, -1, 1, ASPHALT, Enum.Material.Asphalt)
	road.CanCollide = true

	-- Grass beyond the map edges, a little lower than the road so the two don't flicker.
	makePart(map, "Grass", Vector3.new(2048, 1, 2048), CFrame.new(0, -0.55, 0), GRASS, Enum.Material.Grass)

	local markings = folder(map, "Markings")
	for _, segment in TownLayout.segments() do
		local from = segment.from + markingClearance(segment, segment.from)
		local to = segment.to - markingClearance(segment, segment.to)

		-- A dashed center line between the two directions of traffic...
		local count = math.floor((to - from + DASH_GAP) / (DASH_LENGTH + DASH_GAP))
		local start = from + (to - from - (count * (DASH_LENGTH + DASH_GAP) - DASH_GAP)) / 2
		for i = 0, count - 1 do
			local dashStart = start + i * (DASH_LENGTH + DASH_GAP)
			paintLine(markings, segment, dashStart, dashStart + DASH_LENGTH, 0)
		end

		-- ...and solid lines between the driving lanes and the parking strips.
		for _, side in { -1, 1 } do
			paintLine(markings, segment, from, to, side * TownLayout.LANE_WIDTH)
		end
	end
end

local function buildBuilding(parent: Instance, building: TownProps.Building)
	local model = Instance.new("Model")
	model.Name = "Building"
	local x, z = Rect.center(building.rect)
	local width, depth = Rect.width(building.rect), Rect.depth(building.rect)
	local height = building.floors * FLOOR_HEIGHT

	makePart(
		model,
		"Walls",
		Vector3.new(width, height, depth),
		CFrame.new(x, CURB_HEIGHT + height / 2, z),
		BUILDING_COLORS[building.style],
		Enum.Material.Limestone
	)
	for floor = 1, building.floors do
		local floorBottom = CURB_HEIGHT + (floor - 1) * FLOOR_HEIGHT
		makePart(
			model,
			"Windows",
			Vector3.new(width + 0.4, 4, depth + 0.4),
			CFrame.new(x, floorBottom + 6, z),
			GLASS,
			Enum.Material.Glass
		)
		if floor > 1 then
			makePart(
				model,
				"Balcony",
				Vector3.new(width + 2, 0.6, depth + 2),
				CFrame.new(x, floorBottom + 0.3, z),
				WHITE,
				Enum.Material.Concrete
			)
		end
	end

	-- Solar water heaters on the roof, like on almost every building in Israel.
	local roof = CURB_HEIGHT + height
	for _, side in { -1, 1 } do
		local heaterX = x + side * width / 4
		local tank = makePart(
			model,
			"HeaterTank",
			Vector3.new(6, 2.4, 2.4),
			CFrame.new(heaterX, roof + 1.2, z + 2),
			WHITE,
			Enum.Material.SmoothPlastic
		)
		tank.Shape = Enum.PartType.Cylinder
		makePart(
			model,
			"SolarPanel",
			Vector3.new(6, 0.3, 5),
			CFrame.new(heaterX, roof + 1.2, z - 2) * CFrame.Angles(math.rad(25), 0, 0),
			SOLAR_PANEL,
			Enum.Material.Glass
		)
	end

	model.Parent = parent
end

local function buildTree(parent: Instance, tree: TownProps.Tree)
	-- Cylinders are round along their X axis, so trunks are turned to stand up.
	local standUp = CFrame.Angles(0, 0, math.rad(90))
	if tree.kind == "palm" then
		local trunk = makePart(
			parent,
			"PalmTrunk",
			Vector3.new(PALM_HEIGHT, 1.6, 1.6),
			CFrame.new(tree.x, CURB_HEIGHT + PALM_HEIGHT / 2, tree.z) * standUp,
			TRUNK,
			Enum.Material.Wood
		)
		trunk.Shape = Enum.PartType.Cylinder
		local crown = CFrame.new(tree.x, CURB_HEIGHT + PALM_HEIGHT, tree.z)
		for i = 1, 6 do
			-- Each leaf points out from the top of the trunk and droops a little.
			makePart(
				parent,
				"PalmLeaf",
				Vector3.new(2.2, 0.3, 9),
				crown
					* CFrame.Angles(0, i * math.pi / 3, 0)
					* CFrame.Angles(math.rad(-25), 0, 0)
					* CFrame.new(0, 0, -4.5),
				PALM_LEAF,
				Enum.Material.Grass
			)
		end
	else
		local trunk = makePart(
			parent,
			"TreeTrunk",
			Vector3.new(TREE_HEIGHT, 1.6, 1.6),
			CFrame.new(tree.x, CURB_HEIGHT + TREE_HEIGHT / 2, tree.z) * standUp,
			TRUNK,
			Enum.Material.Wood
		)
		trunk.Shape = Enum.PartType.Cylinder
		local leaves = makePart(
			parent,
			"TreeLeaves",
			Vector3.one * 12,
			CFrame.new(tree.x, CURB_HEIGHT + TREE_HEIGHT + 4, tree.z),
			TREE_LEAVES,
			Enum.Material.Grass
		)
		leaves.Shape = Enum.PartType.Ball
	end
end

local function buildLots(map: Instance)
	local sidewalks = folder(map, "Sidewalks")
	local buildings = folder(map, "Buildings")
	local trees = folder(map, "Trees")

	for _, lot in TownLayout.lots() do
		for _, piece in lot.pieces do
			rectPart(sidewalks, "Sidewalk", piece, 0, CURB_HEIGHT, SIDEWALK, Enum.Material.Concrete)
			-- An invisible box over the whole sidewalk and block is what actually stops cars at the curb.
			local curb = rectPart(sidewalks, "Curb", piece, 0, CURB_WALL_HEIGHT, SIDEWALK, Enum.Material.SmoothPlastic)
			curb.Transparency = 1
			curb.CanCollide = true
		end
		for _, inner in lot.inner do
			rectPart(sidewalks, "Garden", inner, CURB_HEIGHT, 0.05, GRASS, Enum.Material.Grass)
		end

		local lotBuildings, lotTrees = TownProps.forLot(lot)
		for _, building in lotBuildings do
			buildBuilding(buildings, building)
		end
		for _, tree in lotTrees do
			buildTree(trees, tree)
		end
	end
end

local function buildParkedCar(parent: Instance, car: TownProps.ParkedCar)
	local model = Instance.new("Model")
	model.Name = "ParkedCar"
	local origin = poseCFrame(car.pose)

	-- The front of the car is -Z, like the Bendi car.
	local body = makePart(
		model,
		"Body",
		Vector3.new(7, 2.5, 14),
		origin * CFrame.new(0, 2, 0),
		CAR_COLORS[car.style],
		Enum.Material.SmoothPlastic
	)
	body.CanCollide = true
	local cabin =
		makePart(model, "Cabin", Vector3.new(6, 2.6, 7), origin * CFrame.new(0, 4.55, 1), GLASS, Enum.Material.Glass)
	cabin.CanCollide = true

	for _, side in { -1, 1 } do
		for _, axle in { -1, 1 } do
			local wheel = makePart(
				model,
				"Wheel",
				Vector3.new(1.2, 3, 3),
				origin * CFrame.new(side * 3.6, 1.5, axle * 4.5),
				Color3.fromRGB(35, 37, 42),
				Enum.Material.SmoothPlastic
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end

	model.Parent = parent
end

local function buildEdgeWalls(map: Instance)
	local walls = folder(map, "EdgeWalls")
	local bounds = TownLayout.BOUNDS
	local x, z = Rect.center(bounds)
	local width, depth = Rect.width(bounds), Rect.depth(bounds)
	local y = EDGE_WALL_HEIGHT / 2
	local sides = {
		{ Vector3.new(width + 8, EDGE_WALL_HEIGHT, 4), Vector3.new(x, y, bounds.minZ - 2) },
		{ Vector3.new(width + 8, EDGE_WALL_HEIGHT, 4), Vector3.new(x, y, bounds.maxZ + 2) },
		{ Vector3.new(4, EDGE_WALL_HEIGHT, depth + 8), Vector3.new(bounds.minX - 2, y, z) },
		{ Vector3.new(4, EDGE_WALL_HEIGHT, depth + 8), Vector3.new(bounds.maxX + 2, y, z) },
	}
	for _, side in sides do
		local wall = makePart(walls, "EdgeWall", side[1], CFrame.new(side[2]), WHITE, Enum.Material.SmoothPlastic)
		wall.Transparency = 1
		wall.CanCollide = true
	end
end

function TownBuilder.build()
	local map = Instance.new("Folder")
	map.Name = "Town"

	buildRoads(map)
	buildLots(map)
	buildEdgeWalls(map)

	local parkedCars = folder(map, "ParkedCars")
	for _, car in TownProps.parkedCars() do
		buildParkedCar(parkedCars, car)
	end

	-- Characters appear in the middle of a crossing, away from every car's spawn spot, and are seated right away.
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Size = Vector3.new(8, 0.2, 8)
	spawnLocation.Position = Vector3.new(TownLayout.STREETS_X[3], 0.1, TownLayout.STREETS_Z[3])
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Duration = 0
	spawnLocation.Parent = map

	map.Parent = workspace
end

return TownBuilder
