-- The school next to the 30 km/h school zone (PRD-003): a two-floor building facing the school street, with a
-- sign in Hebrew and English, solar panels on the roof, and a basketball court in the yard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rect = require(ReplicatedStorage.Core.Rect)
local Strings = require(ReplicatedStorage.Core.Strings)
local TownLayout = require(ReplicatedStorage.Core.TownLayout)

local SignBuilder = require(script.Parent.SignBuilder)

local School = {}

local GROUND = 0.55 -- the top of the block's lawn
local FLOOR_HEIGHT = 11
local FLOORS = 2

local WALLS = Color3.fromRGB(246, 222, 160)
local ACCENT = Color3.fromRGB(235, 130, 60)
local GLASS = Color3.fromRGB(70, 90, 110)
local COURT = Color3.fromRGB(190, 85, 60)
local LINE = Color3.fromRGB(245, 245, 245)

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

local function buildBuilding(model: Instance)
	local rect = TownLayout.SCHOOL_BUILDING
	local x, z = Rect.center(rect)
	local width, depth = Rect.width(rect), Rect.depth(rect)
	local height = FLOORS * FLOOR_HEIGHT

	makePart(
		model,
		"Walls",
		Vector3.new(width, height, depth),
		CFrame.new(x, GROUND + height / 2, z),
		WALLS,
		Enum.Material.Plaster
	)
	for floor = 1, FLOORS do
		local bottom = GROUND + (floor - 1) * FLOOR_HEIGHT
		makePart(
			model,
			"Windows",
			Vector3.new(width + 0.4, 4.5, depth + 0.4),
			CFrame.new(x, bottom + 6, z),
			GLASS,
			Enum.Material.Glass
		)
		makePart(
			model,
			"Stripe",
			Vector3.new(width + 0.6, 1, depth + 0.6),
			CFrame.new(x, bottom + 2.5, z),
			ACCENT,
			Enum.Material.SmoothPlastic
		)
	end
	makePart(
		model,
		"Roof",
		Vector3.new(width + 2, 1, depth + 2),
		CFrame.new(x, GROUND + height + 0.5, z),
		ACCENT,
		Enum.Material.SmoothPlastic
	)

	-- Solar panels in a row on the roof.
	for offset = -depth / 2 + 10, depth / 2 - 10, 12 do
		makePart(
			model,
			"SolarPanel",
			Vector3.new(10, 0.3, 6),
			CFrame.new(x, GROUND + height + 2, z + offset) * CFrame.Angles(math.rad(20), 0, 0),
			Color3.fromRGB(30, 50, 90),
			Enum.Material.Glass
		)
	end

	-- The entrance and the sign face the school street to the east (+X).
	local front = rect.maxX
	makePart(
		model,
		"Door",
		Vector3.new(0.4, 8, 10),
		CFrame.new(front + 0.2, GROUND + 4, z),
		Color3.fromRGB(120, 80, 50),
		Enum.Material.Wood
	)
	local signPosition = Vector3.new(front + 0.5, GROUND + height - 3, z)
	local board = CFrame.lookAt(signPosition, signPosition + Vector3.xAxis)
	makePart(
		model,
		"SignBoard",
		Vector3.new(30, 5, 0.3),
		board,
		Color3.fromRGB(30, 90, 170),
		Enum.Material.SmoothPlastic
	)
	local name = Strings.TEXT.school
	SignBuilder.label(model, board, 28, 4.4, `{name.he}  ·  {name.en}`, SignBuilder.WHITE)
end

local function buildCourt(model: Instance)
	local block = Rect.inset(TownLayout.SCHOOL_BLOCK, TownLayout.SIDEWALK_WIDTH + 6)
	local court = Rect.new(block.minX, block.minZ + 14, TownLayout.SCHOOL_BUILDING.minX - 10, block.maxZ - 14)
	local x, z = Rect.center(court)
	local width, depth = Rect.width(court), Rect.depth(court)
	makePart(
		model,
		"Court",
		Vector3.new(width, 0.1, depth),
		CFrame.new(x, GROUND + 0.05, z),
		COURT,
		Enum.Material.Concrete
	)

	-- Painted lines: the border and the middle line.
	local y = GROUND + 0.11
	makePart(
		model,
		"CourtLine",
		Vector3.new(width - 4, 0.02, 0.5),
		CFrame.new(x, y, z),
		LINE,
		Enum.Material.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		makePart(
			model,
			"CourtLine",
			Vector3.new(width - 4, 0.02, 0.5),
			CFrame.new(x, y, z + side * (depth / 2 - 2)),
			LINE,
			Enum.Material.SmoothPlastic
		)
		makePart(
			model,
			"CourtLine",
			Vector3.new(0.5, 0.02, depth - 4),
			CFrame.new(x + side * (width / 2 - 2), y, z),
			LINE,
			Enum.Material.SmoothPlastic
		)

		-- A hoop at each end.
		local hoopZ = z + side * (depth / 2 - 3)
		local pole = makePart(
			model,
			"HoopPole",
			Vector3.new(12, 0.6, 0.6),
			CFrame.new(x, GROUND + 6, hoopZ) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(90, 90, 95),
			Enum.Material.Metal
		)
		pole.Shape = Enum.PartType.Cylinder
		makePart(
			model,
			"Backboard",
			Vector3.new(6, 4, 0.3),
			CFrame.new(x, GROUND + 12, hoopZ - side * 0.5),
			LINE,
			Enum.Material.SmoothPlastic
		)
	end
end

function School.build(town: Instance)
	local model = Instance.new("Model")
	model.Name = "School"
	buildBuilding(model)
	buildCourt(model)
	model.Parent = town
end

return School
