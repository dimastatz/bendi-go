-- The Bendi car's dashboard (PRD-007): turns the steering wheel with the player's steering, and draws the gauges
-- (a speedometer with a needle, the speed in km/h, and the speed limit sign) and the clock screen. It runs while the
-- player drives, in either camera view, so the wheel also turns when seen through the windows.
-- Only the driver sees the gauges and the wheel turning. Other players see a still dashboard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = ReplicatedStorage:WaitForChild("Core")
local Cockpit = require(Core:WaitForChild("Cockpit"))
local DayCycle = require(Core:WaitForChild("DayCycle"))
local SpeedZones = require(Core:WaitForChild("SpeedZones"))
local Units = require(Core:WaitForChild("Units"))

local DayNight = require(script.Parent.DayNight)
local Text = require(script.Parent.Text)

local Dashboard = {}

local BIND_NAME = "BendiDashboard"
local PIXELS_PER_STUD = 200
local WHITE = Color3.new(1, 1, 1)
local GRAY = Color3.fromRGB(150, 150, 155)
local NEEDLE = Color3.fromRGB(255, 70, 40)
local PANEL = Color3.fromRGB(10, 10, 12)
local DIAL = Color3.fromRGB(22, 24, 28)
local SCREEN = Color3.fromRGB(15, 30, 55)
local BENDI_YELLOW = Color3.fromRGB(250, 200, 30)

local guis: { SurfaceGui } = {}
local joint: Motor6D? = nil
local wheelAngle = 0
local running = false

local function frame(parent: Instance, size: UDim2, position: UDim2, color: Color3, round: boolean?): Frame
	local result = Instance.new("Frame")
	result.Size = size
	result.Position = position
	result.BackgroundColor3 = color
	result.BorderSizePixel = 0
	result.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = result
	end
	return result
end

local function label(parent: Instance, size: UDim2, position: UDim2, text: string, textSize: number): TextLabel
	local result = Instance.new("TextLabel")
	result.Size = size
	result.Position = position
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.BackgroundTransparency = 1
	result.Font = Enum.Font.GothamBlack
	result.TextSize = textSize
	result.TextColor3 = WHITE
	result.Text = text
	result.Parent = parent
	return result
end

-- A full-size see-through frame turned by `angle` degrees, so whatever is drawn at its top points that way.
local function turned(parent: Instance, angle: number): Frame
	local holder = frame(parent, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), WHITE)
	holder.BackgroundTransparency = 1
	holder.Rotation = angle
	return holder
end

-- A screen drawn on the back of `part`, the side that faces the driver.
local function surface(part: BasePart, name: string): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Adornee = part
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0 -- the gauges glow, so they're easy to read at night
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(guis, gui)
	return gui
end

type Gauges = { needle: Frame, speed: TextLabel, limit: TextLabel }

local function drawCluster(part: BasePart): Gauges
	local gui = surface(part, "BendiCluster")
	local panel = frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), PANEL)

	-- The speedometer: a round dial with marks every 10 km/h and numbers every 20.
	local dial = frame(panel, UDim2.fromOffset(160, 160), UDim2.fromOffset(12, 5), DIAL, true)
	local ring = Instance.new("UIStroke")
	ring.Color = WHITE
	ring.Thickness = 3
	ring.Parent = dial
	for kmh = 0, Cockpit.DIAL_MAX_KMH, 10 do
		local angle = Cockpit.needleAngle(kmh)
		local major = kmh % 20 == 0
		local mark = frame(
			turned(dial, angle),
			if major then UDim2.fromOffset(4, 16) else UDim2.fromOffset(2, 9),
			UDim2.new(0.5, 0, 0, 6),
			if major then WHITE else GRAY
		)
		mark.AnchorPoint = Vector2.new(0.5, 0)
		if major then
			local radians = math.rad(angle)
			local number = label(
				dial,
				UDim2.fromOffset(30, 16),
				UDim2.fromScale(0.5 + 0.3 * math.sin(radians), 0.5 - 0.3 * math.cos(radians)),
				tostring(kmh),
				13
			)
			number.Font = Enum.Font.GothamBold
		end
	end
	local needle = turned(dial, Cockpit.needleAngle(0))
	local pointer = frame(needle, UDim2.new(0, 4, 0.42, 0), UDim2.fromScale(0.5, 0.5), NEEDLE)
	pointer.AnchorPoint = Vector2.new(0.5, 1)
	local cap = frame(dial, UDim2.fromOffset(18, 18), UDim2.fromScale(0.5, 0.5), DIAL, true)
	cap.AnchorPoint = Vector2.new(0.5, 0.5)
	local capRing = Instance.new("UIStroke")
	capRing.Color = NEEDLE
	capRing.Thickness = 2
	capRing.Parent = cap

	-- The speed in big numbers.
	local speed = label(panel, UDim2.fromOffset(130, 70), UDim2.fromOffset(250, 70), "0", 64)
	local unit = label(panel, UDim2.fromOffset(130, 24), UDim2.fromOffset(250, 120), Text.get("kmh"), 20)
	unit.Font = Enum.Font.GothamMedium
	unit.TextColor3 = GRAY

	-- The current speed limit, drawn like an Israeli speed limit sign, as many new cars show it.
	local sign = frame(panel, UDim2.fromOffset(110, 110), UDim2.fromOffset(318, 30), Color3.fromRGB(205, 30, 35), true)
	local inside = frame(sign, UDim2.fromScale(0.76, 0.76), UDim2.fromScale(0.5, 0.5), WHITE, true)
	inside.AnchorPoint = Vector2.new(0.5, 0.5)
	local limit =
		label(inside, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.5, 0.5), tostring(SpeedZones.TOWN_LIMIT), 40)
	limit.TextColor3 = Color3.fromRGB(20, 20, 20)

	return { needle = needle, speed = speed, limit = limit }
end

local function drawScreen(part: BasePart): (TextLabel, TextLabel)
	local gui = surface(part, "BendiScreen")
	local panel = frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), SCREEN)
	local title = label(panel, UDim2.fromOffset(240, 30), UDim2.fromOffset(130, 24), "BENDI GO", 24)
	title.TextColor3 = BENDI_YELLOW
	local clock = label(panel, UDim2.fromOffset(240, 60), UDim2.fromOffset(130, 80), "", 52)
	local sky = label(panel, UDim2.fromOffset(240, 30), UDim2.fromOffset(130, 126), "", 24)
	return clock, sky
end

-- Starts the dashboard of `car`, the local player's Bendi car.
function Dashboard.show(car: Model, base: BasePart)
	Dashboard.hide()
	local hub = car:FindFirstChild("SteeringHub")
	joint = if hub then hub:FindFirstChildOfClass("Motor6D") else nil
	wheelAngle = 0

	local clusterPart = car:FindFirstChild("Cluster")
	local screenPart = car:FindFirstChild("Screen")
	if not (clusterPart and clusterPart:IsA("BasePart") and screenPart and screenPart:IsA("BasePart")) then
		return
	end
	local gauges = drawCluster(clusterPart)
	local clock, sky = drawScreen(screenPart)
	running = true

	local limit = SpeedZones.TOWN_LIMIT
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Last.Value, function()
		local velocity = base.AssemblyLinearVelocity
		local kmh = Units.studsPerSecondToKmh(Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
		gauges.needle.Rotation = Cockpit.needleAngle(kmh)
		gauges.speed.Text = tostring(math.floor(kmh + 0.5))
		-- Crossings have no limit of their own, so the last limit stays up there.
		limit = SpeedZones.limitAt(base.Position.X, base.Position.Z) or limit
		gauges.limit.Text = tostring(limit)

		local hour = DayNight.hour()
		clock.Text = Cockpit.clockText(hour)
		sky.Text = if DayCycle.lightsOn(hour) then "🌙" else "☀️"
	end)
end

-- Turns the steering wheel toward `steer` (from -1 for full left to 1 for full right). Called every physics step.
function Dashboard.steer(steer: number, dt: number)
	local wheel = joint
	if not wheel then
		return
	end
	wheelAngle = Cockpit.wheelAngle(wheelAngle, steer, dt)
	-- The wheel faces the driver, so turning right is clockwise from their side: a negative turn around its Z axis.
	wheel.Transform = CFrame.Angles(0, 0, -math.rad(wheelAngle))
end

function Dashboard.hide()
	if running then
		running = false
		RunService:UnbindFromRenderStep(BIND_NAME)
	end
	for _, gui in guis do
		gui:Destroy()
	end
	guis = {}
	joint = nil
end

return Dashboard
