-- The speedometer (PRD-003, requirements 1 and 2): the car's speed in km/h next to the current speed limit sign.
-- It turns orange when the car is over the limit. It's shown while driving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = ReplicatedStorage:WaitForChild("Core")
local SpeedZones = require(Core:WaitForChild("SpeedZones"))
local Units = require(Core:WaitForChild("Units"))

local Text = require(script.Parent.Text)

local Speedometer = {}

local BIND_NAME = "BendiSpeedometer"
local NORMAL = Color3.fromRGB(255, 255, 255)
local OVER = Color3.fromRGB(255, 165, 40)

local gui: ScreenGui? = nil
local panel: Frame
local speedLabel: TextLabel
local limitLabel: TextLabel
local running = false

local function circle(parent: Instance, size: UDim2, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	return frame
end

local function create(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "Speedometer"
	screen.ResetOnSpawn = false

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -12)
	panel.Size = UDim2.fromOffset(150, 64)
	panel.BackgroundColor3 = NORMAL
	panel.BackgroundTransparency = 0.1
	panel.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel

	speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "Speed"
	speedLabel.Position = UDim2.fromOffset(8, 2)
	speedLabel.Size = UDim2.fromOffset(78, 42)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Font = Enum.Font.GothamBlack
	speedLabel.TextScaled = true
	speedLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	speedLabel.Text = "0"
	speedLabel.Parent = panel

	local unit = Instance.new("TextLabel")
	unit.Name = "Unit"
	unit.Position = UDim2.fromOffset(8, 42)
	unit.Size = UDim2.fromOffset(78, 18)
	unit.BackgroundTransparency = 1
	unit.Font = Enum.Font.GothamMedium
	unit.TextScaled = true
	unit.TextColor3 = Color3.fromRGB(80, 80, 80)
	unit.Text = Text.get("kmh")
	unit.Parent = panel

	-- The limit, drawn like an Israeli speed limit sign.
	local sign = Instance.new("Frame")
	sign.Name = "Limit"
	sign.AnchorPoint = Vector2.new(1, 0.5)
	sign.Position = UDim2.new(1, -8, 0.5, 0)
	sign.Size = UDim2.fromOffset(52, 52)
	sign.BackgroundTransparency = 1
	sign.Parent = panel
	circle(sign, UDim2.fromScale(1, 1), Color3.fromRGB(205, 30, 35))
	local inside = circle(sign, UDim2.fromScale(0.76, 0.76), Color3.new(1, 1, 1))
	limitLabel = Instance.new("TextLabel")
	limitLabel.Size = UDim2.fromScale(0.8, 0.8)
	limitLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	limitLabel.Position = UDim2.fromScale(0.5, 0.5)
	limitLabel.BackgroundTransparency = 1
	limitLabel.Font = Enum.Font.GothamBlack
	limitLabel.TextScaled = true
	limitLabel.TextColor3 = Color3.fromRGB(20, 20, 20)
	limitLabel.Text = tostring(SpeedZones.TOWN_LIMIT)
	limitLabel.Parent = inside

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return screen
end

function Speedometer.show(base: BasePart)
	Speedometer.hide()
	local screen = gui or create()
	gui = screen
	screen.Enabled = true
	running = true

	local limit = SpeedZones.TOWN_LIMIT
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Last.Value, function()
		local velocity = base.AssemblyLinearVelocity
		local kmh = Units.studsPerSecondToKmh(Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
		-- Crossings have no limit of their own, so the last limit stays up there.
		limit = SpeedZones.limitAt(base.Position.X, base.Position.Z) or limit
		speedLabel.Text = tostring(math.floor(kmh + 0.5))
		limitLabel.Text = tostring(limit)
		panel.BackgroundColor3 = if kmh > limit then OVER else NORMAL
	end)
end

function Speedometer.hide()
	if running then
		running = false
		RunService:UnbindFromRenderStep(BIND_NAME)
	end
	if gui then
		gui.Enabled = false
	end
end

return Speedometer
