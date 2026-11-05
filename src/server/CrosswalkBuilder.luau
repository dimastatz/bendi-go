-- Builds the zebra crosswalks (PRD-004, requirement 1): white stripes on a black band across the road, and a blue
-- Israeli crosswalk sign on the right-hand side for each direction of traffic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Approach = require(ReplicatedStorage.Core.Approach)
local Crosswalks = require(ReplicatedStorage.Core.Crosswalks)
local TownLayout = require(ReplicatedStorage.Core.TownLayout)

local SignBuilder = require(script.Parent.SignBuilder)

local CrosswalkBuilder = {}

local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local WIDTH = TownLayout.CROSSWALK_WIDTH
local STRIPE_WIDTH = 1.6
local STRIPE_GAP = 1.6
local SIGN_HEIGHT = 9
local SIGN_SIZE = 3.6

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

-- A flat painted rectangle on crosswalk `index`, `acrossSize` by `alongSize`, centered at `across`.
local function paint(
	parent: Instance,
	index: number,
	across: number,
	acrossSize: number,
	alongSize: number,
	top: number,
	color: Color3
)
	local crosswalk = TownLayout.CROSSWALKS[index]
	local x, z = Crosswalks.point(index, across, 0)
	local size = if crosswalk.alongX
		then Vector3.new(alongSize, 0.02, acrossSize)
		else Vector3.new(acrossSize, 0.02, alongSize)
	makePart(parent, "Paint", size, CFrame.new(x, top - 0.01, z), color)
end

local function buildCrosswalk(parent: Instance, index: number)
	local model = Instance.new("Model")
	model.Name = `Crosswalk{index}`

	paint(model, index, 0, TownLayout.ROAD_WIDTH, WIDTH, 0.07, Color3.fromRGB(28, 28, 30))
	local count = math.floor((TownLayout.ROAD_WIDTH - 2 + STRIPE_GAP) / (STRIPE_WIDTH + STRIPE_GAP))
	local first = -(count * (STRIPE_WIDTH + STRIPE_GAP) - STRIPE_GAP) / 2 + STRIPE_WIDTH / 2
	for stripe = 0, count - 1 do
		paint(
			model,
			index,
			first + stripe * (STRIPE_WIDTH + STRIPE_GAP),
			STRIPE_WIDTH,
			WIDTH,
			0.08,
			Color3.fromRGB(245, 245, 245)
		)
	end

	for _, approach in Crosswalks.approaches() do
		if approach.crosswalk == index then
			local x, z = Approach.point(approach, approach.line, HALF_ROAD + 3)
			local foot = Vector3.new(x, 0.5, z)
			local facing = if approach.alongX
				then Vector3.new(-approach.direction, 0, 0)
				else Vector3.new(0, 0, -approach.direction)
			SignBuilder.pole(model, foot, SIGN_HEIGHT)
			local face = CFrame.lookAt(foot, foot + facing) * CFrame.new(0, SIGN_HEIGHT - SIGN_SIZE / 2, 0)
			SignBuilder.square(model, face, SIGN_SIZE, SignBuilder.BLUE)
			SignBuilder.plainTriangle(model, face * CFrame.new(0, -0.1, 0), SIGN_SIZE * 0.85, SignBuilder.WHITE)
			SignBuilder.label(model, face * CFrame.new(0, -0.45, -0.05), 1.7, 1.7, "🚶", SignBuilder.BLACK)
		end
	end

	model.Parent = parent
end

function CrosswalkBuilder.build(town: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Crosswalks"
	for index in TownLayout.CROSSWALKS do
		buildCrosswalk(folder, index)
	end
	folder.Parent = town
end

return CrosswalkBuilder
