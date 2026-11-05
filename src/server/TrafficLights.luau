-- Builds the traffic lights and their white stop lines (PRD-002, requirement 1), then switches the lamps on and off
-- from the shared game clock. Each approach to a light crossing gets a pole on the right-hand sidewalk at its stop
-- line, with the light facing the cars that are coming.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Core.TrafficLightConfig)
local RedLightRule = require(ReplicatedStorage.Core.RedLightRule)
local TownLayout = require(ReplicatedStorage.Core.TownLayout)
local TrafficLight = require(ReplicatedStorage.Core.TrafficLight)

local TrafficLights = {}

local SIDEWALK_TOP = 0.5
local POLE_HEIGHT = 12
local POLE_OFFSET = 3 -- how far past the curb the pole stands
local HEAD_SIZE = Vector3.new(3, 8.4, 2) -- bigger than a real light, so kids notice it
local LAMP_SIZE = 2.2
local LAMP_SPACING = 2.6
local STOP_LINE_WIDTH = 1.5

local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local HOUSING = Color3.fromRGB(30, 30, 32)

local LAMP_COLORS = {
	red = { on = Color3.fromRGB(255, 45, 35), off = Color3.fromRGB(70, 20, 18) },
	yellow = { on = Color3.fromRGB(255, 190, 20), off = Color3.fromRGB(70, 55, 15) },
	green = { on = Color3.fromRGB(40, 235, 100), off = Color3.fromRGB(15, 60, 30) },
}

type Lamp = { part: Part, color: string, approach: RedLightRule.Approach, lit: boolean? }

local lamps: { Lamp } = {}

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
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A point `along` the approach's street and `right` studs to the right of its center line, for its traffic.
local function approachPoint(approach: RedLightRule.Approach, along: number, right: number, height: number): Vector3
	if approach.alongX then
		return Vector3.new(along, height, approach.at + approach.direction * right)
	end
	return Vector3.new(approach.at - approach.direction * right, height, along)
end

local function buildStopLine(parent: Instance, approach: RedLightRule.Approach)
	-- Across the approach's half of the road, from the center line to the curb.
	local size = if approach.alongX
		then Vector3.new(STOP_LINE_WIDTH, 0.06, HALF_ROAD)
		else Vector3.new(HALF_ROAD, 0.06, STOP_LINE_WIDTH)
	local position = approachPoint(approach, approach.stopLine, HALF_ROAD / 2, 0.03)
	makePart(parent, "StopLine", size, CFrame.new(position), Color3.fromRGB(245, 245, 245))
end

local function buildLight(parent: Instance, approach: RedLightRule.Approach)
	local model = Instance.new("Model")
	model.Name = `TrafficLight{approach.crossing}`

	local foot = approachPoint(approach, approach.stopLine, HALF_ROAD + POLE_OFFSET, SIDEWALK_TOP)
	-- The light faces the cars driving toward it.
	local facing = if approach.alongX
		then Vector3.new(-approach.direction, 0, 0)
		else Vector3.new(0, 0, -approach.direction)
	local base = CFrame.lookAt(foot, foot + facing)

	-- Cylinders are round along their X axis, so the pole is turned to stand up.
	local pole = makePart(
		model,
		"Pole",
		Vector3.new(POLE_HEIGHT, 0.8, 0.8),
		base * CFrame.new(0, POLE_HEIGHT / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(120, 124, 128)
	)
	pole.Shape = Enum.PartType.Cylinder

	local head = base * CFrame.new(0, POLE_HEIGHT + HEAD_SIZE.Y / 2, 0)
	makePart(model, "Housing", HEAD_SIZE, head, HOUSING)

	-- Red on top, yellow in the middle, green at the bottom. The front of the housing is its -Z side.
	for index, color in { "red", "yellow", "green" } do
		local lamp = makePart(
			model,
			"Lamp",
			Vector3.one * LAMP_SIZE,
			head * CFrame.new(0, (2 - index) * LAMP_SPACING, -HEAD_SIZE.Z / 2),
			LAMP_COLORS[color].off
		)
		lamp.Shape = Enum.PartType.Ball
		table.insert(lamps, { part = lamp, color = color, approach = approach, lit = nil })
	end

	model.Parent = parent
end

function TrafficLights.build(town: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "TrafficLights"
	for _, approach in RedLightRule.approaches() do
		buildStopLine(folder, approach)
		buildLight(folder, approach)
	end
	folder.Parent = town
end

-- Switches lamps on and off every frame. Only lamps that change are touched, so little has to be sent to players.
function TrafficLights.start()
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, lamp in lamps do
			local approach = lamp.approach
			local lit =
				TrafficLight.lampsAt(now, approach.alongX, Config.CROSSINGS[approach.crossing].offset)[lamp.color]
			if lit ~= lamp.lit then
				lamp.lit = lit
				local colors = LAMP_COLORS[lamp.color]
				lamp.part.Color = if lit then colors.on else colors.off
				lamp.part.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end
	end)
end

return TrafficLights
