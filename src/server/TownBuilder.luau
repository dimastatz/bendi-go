-- Builds the Bendi Go neighborhood from TownLayout, TownProps, and Curbs: roads with lane markings, sidewalks with
-- painted curbs, street lamps, buildings, trees, hedges, parked cars, and invisible walls at the map edges.
-- Cars only collide with the road, the curbs, parked cars, and the map edges. Everything else is decoration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Curbs = require(ReplicatedStorage.Core.Curbs)
local Rect = require(ReplicatedStorage.Core.Rect)
local TownLayout = require(ReplicatedStorage.Core.TownLayout)
local TownProps = require(ReplicatedStorage.Core.TownProps)

local CarModel = require(script.Parent.CarModel)
local NightLight = require(script.Parent.NightLight)

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
local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local CURB_STONE_WIDTH = 1.1
local LAMP_HEIGHT = 16
local LAMP_ARM = 3.5
local WINDOW_SPACING = 9
local HEDGE_LENGTH = 24
local HEDGE_GAP = 6

local ASPHALT = Color3.fromRGB(58, 60, 64)
local MARKING = Color3.fromRGB(232, 232, 226)
local SIDEWALK = Color3.fromRGB(190, 184, 172)
local CURB_STONE = Color3.fromRGB(208, 205, 198)
local CURB_WHITE = Color3.fromRGB(240, 240, 238)
local CURB_RED = Color3.fromRGB(200, 35, 35)
local CURB_BLUE = Color3.fromRGB(30, 85, 175)
local GRASS = Color3.fromRGB(100, 150, 72)
local GLASS = Color3.fromRGB(55, 70, 85)
local WINDOW_LIT = Color3.fromRGB(235, 185, 115)
local SHUTTER = Color3.fromRGB(222, 222, 216)
local RAILING = Color3.fromRGB(175, 195, 205)
local WHITE = Color3.fromRGB(245, 245, 240)
local SOLAR_PANEL = Color3.fromRGB(30, 50, 90)
local METAL = Color3.fromRGB(85, 88, 92)
local LAMP_GLASS = Color3.fromRGB(200, 200, 190)
local LAMP_LIT = Color3.fromRGB(255, 214, 160)
local TRUNK = Color3.fromRGB(115, 85, 60)
local PALM_TRUNK = Color3.fromRGB(128, 104, 78)
local DATES = Color3.fromRGB(150, 95, 40)
local HEDGE = Color3.fromRGB(62, 108, 50)

-- A few shades of green, so trees don't all look the same.
local LEAF_COLORS = {
	Color3.fromRGB(60, 120, 55),
	Color3.fromRGB(78, 132, 58),
	Color3.fromRGB(52, 105, 50),
	Color3.fromRGB(90, 140, 66),
}

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

-- A cylinder standing up, from `bottom` to `bottom + height`. Cylinders are round along their X axis, so it's turned.
local function upright(
	parent: Instance,
	name: string,
	x: number,
	z: number,
	bottom: number,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material
): Part
	local part = makePart(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(x, bottom + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
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

-- A flat strip along `street`, from `from` to `to`, centered `offset` studs from its center line, `width` wide.
local function stripCFrame(
	street: TownLayout.Street,
	from: number,
	to: number,
	offset: number,
	width: number,
	height: number,
	y: number
): (Vector3, CFrame)
	local length, middle = to - from, (from + to) / 2
	if street.alongX then
		return Vector3.new(length, height, width), CFrame.new(middle, y, street.at + offset)
	end
	return Vector3.new(width, height, length), CFrame.new(street.at + offset, y, middle)
end

-- A painted line along `street`, from `from` to `to`, `offset` studs from its center line.
local function paintLine(parent: Instance, street: TownLayout.Street, from: number, to: number, offset: number)
	local size, cframe = stripCFrame(street, from, to, offset, LINE_WIDTH, 0.05, 0.025)
	makePart(parent, "Line", size, cframe, MARKING, Enum.Material.SmoothPlastic)
end

-- How far from a crossing's center the lane markings stop: at the edge of the crossing, or of the roundabout space.
local function markingClearance(street: TownLayout.Street, along: number): number
	local x, z = street.at, along
	if street.alongX then
		x, z = along, street.at
	end
	local halfSize = if Rect.contains(TownLayout.ROUNDABOUT_SPACE, x, z)
		then TownLayout.ROUNDABOUT.halfSize
		else HALF_ROAD
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

-- Curb stones along every road edge, painted the Israeli way: red and white where stopping isn't allowed, blue and
-- white for paid parking, and plain stone where parking is free.
local function buildCurbs(map: Instance)
	local curbs = folder(map, "CurbStones")
	-- The stone sits on the sidewalk's edge, a little higher, and just covers the side of the sidewalk.
	local offset = HALF_ROAD + CURB_STONE_WIDTH / 2 - 0.05
	local height = CURB_HEIGHT + 0.08
	for _, run in Curbs.runs() do
		local across = run.side * offset
		local size, cframe = stripCFrame(run.segment, run.from, run.to, across, CURB_STONE_WIDTH, height, height / 2)
		if run.paint == "plain" then
			makePart(curbs, "CurbStone", size, cframe, CURB_STONE, Enum.Material.Concrete)
			continue
		end
		makePart(curbs, "CurbStone", size, cframe, CURB_WHITE, Enum.Material.SmoothPlastic)
		local stripeColor = if run.paint == "red" then CURB_RED else CURB_BLUE
		local stripe = Curbs.STRIPE_LENGTH
		for along = run.from, run.to - 0.01, 2 * stripe do
			local stripeSize, stripeCFrame = stripCFrame(
				run.segment,
				along,
				math.min(along + stripe, run.to),
				across,
				CURB_STONE_WIDTH + 0.02,
				height + 0.02,
				height / 2
			)
			makePart(curbs, "CurbStripe", stripeSize, stripeCFrame, stripeColor, Enum.Material.SmoothPlastic)
		end
	end
end

-- A street lamp on the sidewalk, with its arm reaching over the road. Its light shines down on the road at night.
local function buildLamp(parent: Instance, lamp: TownProps.Lamp)
	local model = Instance.new("Model")
	model.Name = "StreetLamp"
	upright(model, "Pole", lamp.x, lamp.z, CURB_HEIGHT, LAMP_HEIGHT, 0.6, METAL, Enum.Material.Metal)

	local top = Vector3.new(lamp.x, CURB_HEIGHT + LAMP_HEIGHT - 0.2, lamp.z)
	local arm = CFrame.lookAt(top, top + Vector3.new(lamp.dirX, 0, lamp.dirZ))
	makePart(
		model,
		"Arm",
		Vector3.new(0.35, 0.35, LAMP_ARM),
		arm * CFrame.new(0, 0, -LAMP_ARM / 2),
		METAL,
		Enum.Material.Metal
	)
	makePart(
		model,
		"Head",
		Vector3.new(1.4, 0.5, 2.2),
		arm * CFrame.new(0, -0.1, -LAMP_ARM),
		METAL,
		Enum.Material.Metal
	)
	local bulb = makePart(
		model,
		"Bulb",
		Vector3.new(1, 0.12, 1.6),
		arm * CFrame.new(0, -0.4, -LAMP_ARM),
		LAMP_GLASS,
		Enum.Material.SmoothPlastic
	)
	bulb.CastShadow = false

	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Brightness = 2.5
	light.Range = 32
	light.Angle = 120
	light.Shadows = false
	NightLight.tag(bulb, LAMP_LIT, light)

	model.Parent = parent
end

-- The windows on one floor of one side of a building. The side's middle is at `center`, it faces `normal`, and it's
-- `length` wide. Each window has a roller shutter box above it, like most Israeli windows, and some have the lights
-- on inside at night.
local function buildWindows(model: Model, center: Vector3, normal: Vector3, length: number, floor: number)
	local count = math.max(1, math.floor((length - 4) / WINDOW_SPACING))
	local face = CFrame.lookAt(center, center + normal)
	for i = 1, count do
		-- Facing out of the building, the side runs along X.
		local along = (i - (count + 1) / 2) * WINDOW_SPACING
		local window = face * CFrame.new(along, 0, -0.1)
		local glass = makePart(model, "Window", Vector3.new(4.2, 5, 0.3), window, GLASS, Enum.Material.Glass)
		glass.Reflectance = 0.25
		makePart(
			model,
			"Shutter",
			Vector3.new(4.6, 0.7, 0.5),
			window * CFrame.new(0, 3, 0),
			SHUTTER,
			Enum.Material.SmoothPlastic
		)
		local position = glass.Position
		if TownProps.hash(position.X + floor * 7, position.Z) % 4 == 0 then
			NightLight.tag(glass, WINDOW_LIT)
		end
	end
end

local function buildBuilding(parent: Instance, building: TownProps.Building)
	local model = Instance.new("Model")
	model.Name = "Building"
	local x, z = Rect.center(building.rect)
	local width, depth = Rect.width(building.rect), Rect.depth(building.rect)
	local height = building.floors * FLOOR_HEIGHT
	local color = BUILDING_COLORS[building.style]

	makePart(
		model,
		"Walls",
		Vector3.new(width, height, depth),
		CFrame.new(x, CURB_HEIGHT + height / 2, z),
		color,
		Enum.Material.Limestone
	)
	-- A darker stone band along the bottom.
	makePart(
		model,
		"Plinth",
		Vector3.new(width + 0.3, 1.6, depth + 0.3),
		CFrame.new(x, CURB_HEIGHT + 0.8, z),
		color:Lerp(Color3.new(0, 0, 0), 0.25),
		Enum.Material.Slate
	)

	-- Each side of the building: where its middle is, which way it faces, and how wide it is.
	local sides = {
		{ Vector3.new(x, 0, z - depth / 2), Vector3.new(0, 0, -1), width },
		{ Vector3.new(x, 0, z + depth / 2), Vector3.new(0, 0, 1), width },
		{ Vector3.new(x - width / 2, 0, z), Vector3.new(-1, 0, 0), depth },
		{ Vector3.new(x + width / 2, 0, z), Vector3.new(1, 0, 0), depth },
	}
	for floor = 1, building.floors do
		local floorBottom = CURB_HEIGHT + (floor - 1) * FLOOR_HEIGHT
		for _, side in sides do
			buildWindows(model, side[1] + Vector3.new(0, floorBottom + 6, 0), side[2], side[3], floor)
		end
		if floor > 1 then
			-- Balconies with glass railings on the front and back.
			for _, side in { sides[1], sides[2] } do
				local normal = side[2]
				local base = side[1] + normal * 1.6 + Vector3.new(0, floorBottom + 0.25, 0)
				local frame = CFrame.lookAt(base, base + normal)
				local balconyWidth = side[3] * 0.5
				makePart(model, "Balcony", Vector3.new(balconyWidth, 0.5, 3.2), frame, WHITE, Enum.Material.Concrete)
				local railing = makePart(
					model,
					"Railing",
					Vector3.new(balconyWidth, 2.6, 0.2),
					frame * CFrame.new(0, 1.55, -1.5),
					RAILING,
					Enum.Material.Glass
				)
				railing.Transparency = 0.45
			end
		end
	end

	-- A low wall around the edge of the flat roof.
	local roof = CURB_HEIGHT + height
	for _, side in sides do
		local normal = side[2]
		local wallCenter = side[1] - normal * 0.3 + Vector3.new(0, roof + 0.8, 0)
		makePart(
			model,
			"Parapet",
			Vector3.new(side[3], 1.6, 0.6),
			CFrame.lookAt(wallCenter, wallCenter + normal),
			color,
			Enum.Material.Limestone
		)
	end

	-- Solar water heaters on the roof, like on almost every building in Israel.
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

-- A palm or a round tree standing on a sidewalk or lawn. Also used for the roundabout's island.
function TownBuilder.buildTree(parent: Instance, tree: TownProps.Tree)
	local hash = TownProps.hash(tree.x, tree.z)
	local leaves = LEAF_COLORS[hash % #LEAF_COLORS + 1]
	local model = Instance.new("Model")
	model.Name = if tree.kind == "palm" then "Palm" else "Tree"

	if tree.kind == "palm" then
		-- The trunk gets a little thinner toward the top.
		for piece = 0, 2 do
			upright(
				model,
				"PalmTrunk",
				tree.x,
				tree.z,
				CURB_HEIGHT + piece * PALM_HEIGHT / 3,
				PALM_HEIGHT / 3 + 0.2,
				1.7 - piece * 0.2,
				PALM_TRUNK,
				Enum.Material.Wood
			)
		end
		local crown = CFrame.new(tree.x, CURB_HEIGHT + PALM_HEIGHT, tree.z)
		local dates =
			makePart(model, "Dates", Vector3.one * 2.2, crown * CFrame.new(0, -0.6, 0), DATES, Enum.Material.Wood)
		dates.Shape = Enum.PartType.Ball
		local fronds = 9
		for i = 1, fronds do
			-- Each frond rises out of the top of the trunk, then droops toward its tip.
			local turn = crown
				* CFrame.Angles(0, i * 2 * math.pi / fronds + hash, 0)
				* CFrame.Angles(math.rad(15), 0, 0)
			local color = if i % 2 == 0 then leaves else PALM_TRUNK:Lerp(leaves, 0.75)
			makePart(
				model,
				"PalmLeaf",
				Vector3.new(1.8, 0.25, 5),
				turn * CFrame.new(0, 0, -2.5),
				color,
				Enum.Material.LeafyGrass
			)
			makePart(
				model,
				"PalmLeaf",
				Vector3.new(1.4, 0.2, 5),
				turn * CFrame.new(0, 0, -5) * CFrame.Angles(math.rad(-50), 0, 0) * CFrame.new(0, 0, -2.3),
				color,
				Enum.Material.LeafyGrass
			)
		end
	else
		upright(model, "TreeTrunk", tree.x, tree.z, CURB_HEIGHT, TREE_HEIGHT + 1, 1.4, TRUNK, Enum.Material.Wood)
		-- A leafy crown made of a big ball with smaller balls around it.
		local top = CFrame.new(tree.x, CURB_HEIGHT + TREE_HEIGHT + 4, tree.z)
		local crown = makePart(model, "TreeLeaves", Vector3.one * 10, top, leaves, Enum.Material.LeafyGrass)
		crown.Shape = Enum.PartType.Ball
		for i = 1, 4 do
			local around = top * CFrame.Angles(0, i * math.pi / 2 + hash, 0) * CFrame.new(0, (i % 2) * 1.5 - 1, -3.2)
			local shade = LEAF_COLORS[(hash + i) % #LEAF_COLORS + 1]
			local ball = makePart(model, "TreeLeaves", Vector3.one * 6.5, around, shade, Enum.Material.LeafyGrass)
			ball.Shape = Enum.PartType.Ball
		end
	end

	model.Parent = parent
end

-- Low hedges along the edges of a garden `rect` that face a sidewalk, with gaps to walk through. Edges between two
-- gardens of the same lot (in `inner`) get no hedge.
local function buildHedges(parent: Instance, rect: Rect.Rect, inner: { Rect.Rect })
	local edges = {
		{ rect.minX, rect.minZ + 1.5, rect.maxX, rect.minZ + 1.5, 0, -1 },
		{ rect.minX, rect.maxZ - 1.5, rect.maxX, rect.maxZ - 1.5, 0, 1 },
		{ rect.minX + 1.5, rect.minZ, rect.minX + 1.5, rect.maxZ, -1, 0 },
		{ rect.maxX - 1.5, rect.minZ, rect.maxX - 1.5, rect.maxZ, 1, 0 },
	}
	for _, edge in edges do
		local x1, z1, x2, z2, normalX, normalZ = edge[1], edge[2], edge[3], edge[4], edge[5], edge[6]
		local length = math.max(x2 - x1, z2 - z1)
		local count = math.floor((length + HEDGE_GAP) / (HEDGE_LENGTH + HEDGE_GAP))
		local start = (length - (count * (HEDGE_LENGTH + HEDGE_GAP) - HEDGE_GAP)) / 2
		for i = 0, count - 1 do
			local t = (start + i * (HEDGE_LENGTH + HEDGE_GAP) + HEDGE_LENGTH / 2) / length
			local x, z = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
			local beyondX, beyondZ = x + normalX * 4, z + normalZ * 4
			local nextToGarden = false
			for _, other in inner do
				if Rect.contains(other, beyondX, beyondZ) then
					nextToGarden = true
				end
			end
			if not nextToGarden then
				local size = if normalZ ~= 0
					then Vector3.new(HEDGE_LENGTH, 2.6, 1.8)
					else Vector3.new(1.8, 2.6, HEDGE_LENGTH)
				makePart(parent, "Hedge", size, CFrame.new(x, CURB_HEIGHT + 1.3, z), HEDGE, Enum.Material.LeafyGrass)
			end
		end
	end
end

local function buildLots(map: Instance)
	local sidewalks = folder(map, "Sidewalks")
	local buildings = folder(map, "Buildings")
	local trees = folder(map, "Trees")
	local lamps = folder(map, "StreetLamps")
	local hedges = folder(map, "Hedges")

	for _, lot in TownLayout.lots() do
		for _, piece in lot.pieces do
			rectPart(sidewalks, "Sidewalk", piece, 0, CURB_HEIGHT, SIDEWALK, Enum.Material.Pavement)
			-- An invisible box over the whole sidewalk and block is what actually stops cars at the curb.
			local curb = rectPart(sidewalks, "Curb", piece, 0, CURB_WALL_HEIGHT, SIDEWALK, Enum.Material.SmoothPlastic)
			curb.Transparency = 1
			curb.CanCollide = true
		end
		for _, inner in lot.inner do
			rectPart(sidewalks, "Garden", inner, CURB_HEIGHT, 0.05, GRASS, Enum.Material.Grass)
			if not Rect.overlaps(inner, TownLayout.SCHOOL_BLOCK) then
				buildHedges(hedges, inner, lot.inner)
			end
		end

		local lotBuildings, lotTrees = TownProps.forLot(lot)
		for _, building in lotBuildings do
			buildBuilding(buildings, building)
		end
		for _, tree in lotTrees do
			TownBuilder.buildTree(trees, tree)
		end
		for _, lamp in TownProps.lampsForLot(lot) do
			buildLamp(lamps, lamp)
		end
	end
end

-- A parked car: invisible boxes for collisions, drawn by CarModel.
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
		GLASS,
		Enum.Material.SmoothPlastic
	)
	body.Transparency = 1
	body.CanCollide = true
	local cabin = makePart(
		model,
		"Cabin",
		Vector3.new(6, 2.6, 7),
		origin * CFrame.new(0, 4.55, 1),
		GLASS,
		Enum.Material.SmoothPlastic
	)
	cabin.Transparency = 1
	cabin.CanCollide = true

	CarModel.build(model, origin, nil, {
		paint = CAR_COLORS[car.style],
		plate = CarModel.plateNumber(TownProps.hash(car.pose.x, car.pose.z)),
	})

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

function TownBuilder.build(): Folder
	local map = Instance.new("Folder")
	map.Name = "Town"

	buildRoads(map)
	buildCurbs(map)
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
	return map
end

return TownBuilder
