-- Builds the roundabout and the stop sign and give-way junctions (PRD-005, requirements 4, 5, 8, 9).
-- The roundabout has a planted island, a dashed edge, splitter islands between each entrance and exit, planters
-- in the corners, and at each entrance a give-way line with a roundabout sign above a give-way sign.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Approach = require(ReplicatedStorage.Core.Approach)
local Junctions = require(ReplicatedStorage.Core.Junctions)
local Strings = require(ReplicatedStorage.Core.Strings)
local TownLayout = require(ReplicatedStorage.Core.TownLayout)

local SignBuilder = require(script.Parent.SignBuilder)
local TownBuilder = require(script.Parent.TownBuilder)

local JunctionBuilder = {}

local CX, CZ = Junctions.CENTER_X, Junctions.CENTER_Z
local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local SIDEWALK_TOP = 0.5
local WALL_HEIGHT = 8 -- invisible walls on islands, like the curbs, so cars can't drive over them
local POLE_HEIGHT = 10
local SIGN_OFFSET = 3 -- signs stand this far past the curb

local CONCRETE = Color3.fromRGB(196, 190, 180)
local GRASS = Color3.fromRGB(108, 158, 78)
local PAINT = Color3.fromRGB(245, 245, 245)

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function wall(parent: Instance, size: Vector3, cframe: CFrame, shape: Enum.PartType?)
	local part = makePart(parent, "Wall", size, cframe, CONCRETE)
	part.Shape = shape or Enum.PartType.Block
	part.Transparency = 1
	part.CanCollide = true
end

-- A flat disc lying on the ground. Cylinders are round along their X axis, so it's turned to lie flat.
local function disc(
	parent: Instance,
	name: string,
	radius: number,
	bottom: number,
	height: number,
	color: Color3,
	material: Enum.Material?
): Part
	local part = makePart(
		parent,
		name,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(CX, bottom + height / 2, CZ) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A dashed circle painted around the roundabout, leaving gaps at the entrances and exits.
local function dashedCircle(parent: Instance, radius: number, leaveGaps: boolean)
	for angle = 0, 359, 6 do
		local nearLeg = math.abs(((angle + 45) % 90) - 45) < 28
		if not (leaveGaps and nearLeg) then
			local radians = math.rad(angle)
			local position = Vector3.new(CX + radius * math.cos(radians), 0.04, CZ + radius * math.sin(radians))
			local tangent = Vector3.new(-math.sin(radians), 0, math.cos(radians))
			makePart(parent, "Line", Vector3.new(0.5, 0.05, 2.4), CFrame.lookAt(position, position + tangent), PAINT)
		end
	end
end

-- A dashed line across an approach's half of the road at its line.
local function giveWayLine(parent: Instance, approach: Approach.Approach)
	for right = 1.5, HALF_ROAD - 1, 2.8 do
		local x, z = Approach.point(approach, approach.line, right)
		local size = if approach.alongX then Vector3.new(1, 0.05, 1.6) else Vector3.new(1.6, 0.05, 1)
		makePart(parent, "GiveWayLine", size, CFrame.new(x, 0.04, z), PAINT)
	end
end

local function solidLine(parent: Instance, approach: Approach.Approach)
	local x, z = Approach.point(approach, approach.line, HALF_ROAD / 2)
	local size = if approach.alongX then Vector3.new(1.5, 0.06, HALF_ROAD) else Vector3.new(HALF_ROAD, 0.06, 1.5)
	makePart(parent, "StopLine", size, CFrame.new(x, 0.03, z), PAINT)
end

-- Where a sign for `approach` stands, `before` studs ahead of its line, facing the drivers coming toward it.
local function signFrame(approach: Approach.Approach, before: number): (Vector3, Vector3)
	local x, z = Approach.point(approach, approach.line - approach.direction * before, HALF_ROAD + SIGN_OFFSET)
	local facing = if approach.alongX
		then Vector3.new(-approach.direction, 0, 0)
		else Vector3.new(0, 0, -approach.direction)
	return Vector3.new(x, SIDEWALK_TOP, z), facing
end

local function giveWaySign(parent: Instance, foot: Vector3, facing: Vector3, height: number)
	local face = CFrame.lookAt(foot, foot + facing) * CFrame.new(0, height, 0)
	SignBuilder.triangle(parent, face, 3.8, true)
end

local function buildRoundabout(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Roundabout"

	-- The island: a curb, grass, and a palm tree, with an invisible wall around it.
	disc(model, "IslandCurb", Junctions.ISLAND_RADIUS, 0, SIDEWALK_TOP, CONCRETE, Enum.Material.Concrete)
	disc(model, "IslandGrass", Junctions.ISLAND_RADIUS - 1.5, 0, SIDEWALK_TOP + 0.05, GRASS, Enum.Material.Grass)
	wall(
		model,
		Vector3.new(WALL_HEIGHT, Junctions.ISLAND_RADIUS * 2, Junctions.ISLAND_RADIUS * 2),
		CFrame.new(CX, WALL_HEIGHT / 2, CZ) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.PartType.Cylinder
	)
	TownBuilder.buildTree(model, { x = CX, z = CZ, kind = "palm" })
	for angle = 45, 315, 90 do
		local radians = math.rad(angle)
		TownBuilder.buildTree(
			model,
			{ x = CX + 10 * math.cos(radians), z = CZ + 10 * math.sin(radians), kind = "round" }
		)
	end

	dashedCircle(model, Junctions.OUTER_RADIUS, true)
	dashedCircle(model, Junctions.ISLAND_RADIUS + 1, false)

	-- Splitter islands between each entrance and exit.
	for _, entry in Junctions.roundaboutEntries() do
		local inner, outer = Junctions.OUTER_RADIUS + 2, 52
		local middle = (inner + outer) / 2
		local x, z = Approach.point(entry, (if entry.alongX then CX else CZ) - entry.direction * middle, 0)
		local size = if entry.alongX
			then Vector3.new(outer - inner, SIDEWALK_TOP, 2.4)
			else Vector3.new(2.4, SIDEWALK_TOP, outer - inner)
		makePart(model, "Splitter", size, CFrame.new(x, SIDEWALK_TOP / 2, z), CONCRETE, Enum.Material.Concrete)
		wall(model, Vector3.new(size.X, WALL_HEIGHT, size.Z), CFrame.new(x, WALL_HEIGHT / 2, z))

		giveWayLine(model, entry)
		-- A roundabout sign above a give-way sign, just before the line.
		local foot, facing = signFrame(entry, 8)
		SignBuilder.pole(model, foot, POLE_HEIGHT)
		local face = CFrame.lookAt(foot, foot + facing) * CFrame.new(0, POLE_HEIGHT - 2, 0)
		SignBuilder.disc(model, face, 3.8, SignBuilder.BLUE, SignBuilder.BLUE, 0.2)
		SignBuilder.label(model, face, 3, 3, "⟲", SignBuilder.WHITE)
		giveWaySign(model, foot, facing, POLE_HEIGHT - 5.6)
	end

	-- Planters in the four corners, turned 45 degrees, with a tree in each.
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local x, z = CX + corner[1] * 40, CZ + corner[2] * 40
		local turn = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(45), 0)
		makePart(
			model,
			"Planter",
			Vector3.new(20, SIDEWALK_TOP, 20),
			turn * CFrame.new(0, SIDEWALK_TOP / 2, 0),
			CONCRETE,
			Enum.Material.Concrete
		)
		makePart(
			model,
			"PlanterGrass",
			Vector3.new(18, 0.05, 18),
			turn * CFrame.new(0, SIDEWALK_TOP + 0.025, 0),
			GRASS,
			Enum.Material.Grass
		)
		wall(model, Vector3.new(20, WALL_HEIGHT, 20), turn * CFrame.new(0, WALL_HEIGHT / 2, 0))
		TownBuilder.buildTree(model, { x = x, z = z, kind = "round" })
	end

	model.Parent = parent
end

local function buildStopJunction(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "StopJunction"
	local word = Strings.TEXT.stopWord
	for _, approach in Junctions.stopApproaches() do
		solidLine(model, approach)
		local foot, facing = signFrame(approach, 0)
		SignBuilder.pole(model, foot, POLE_HEIGHT)
		local face = CFrame.lookAt(foot, foot + facing) * CFrame.new(0, POLE_HEIGHT - 2, 0)
		SignBuilder.octagon(model, face, 3.8)
		SignBuilder.label(model, face * CFrame.new(0, 0.45, 0), 3, 1.2, word.he, SignBuilder.WHITE)
		SignBuilder.label(model, face * CFrame.new(0, -0.65, 0), 2.6, 0.9, word.en, SignBuilder.WHITE)
	end
	model.Parent = parent
end

local function buildGiveWayJunction(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "GiveWayJunction"
	for _, approach in Junctions.giveWayApproaches() do
		giveWayLine(model, approach)
		local foot, facing = signFrame(approach, 0)
		SignBuilder.pole(model, foot, POLE_HEIGHT - 2)
		giveWaySign(model, foot, facing, POLE_HEIGHT - 4)
	end
	model.Parent = parent
end

function JunctionBuilder.build(town: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Junctions"
	buildRoundabout(folder)
	buildStopJunction(folder)
	buildGiveWayJunction(folder)
	folder.Parent = town
end

return JunctionBuilder
