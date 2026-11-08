-- The arrows on the road and the mini-map during a lesson (PRD-006, requirement 2). Only the player taking the
-- lesson sees them. The server says which lesson started and which checkpoint is next, and the route itself comes
-- from Core.Lessons, so the client and the server always agree on where the checkpoints are.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = ReplicatedStorage:WaitForChild("Core")
local Lessons = require(Core:WaitForChild("Lessons"))
local TownLayout = require(Core:WaitForChild("TownLayout"))

local Text = require(script.Parent.Text)

local LessonGuide = {}

local ARROW_COUNT = 4 -- how many checkpoints ahead have arrows
local ARROW_HEIGHT = 0.12 -- just above the road paint
local ARROW_COLOR = Color3.fromRGB(40, 170, 255)
local FINISH_COLOR = Color3.fromRGB(250, 200, 30)
local MAP_WIDTH, MAP_HEIGHT = 200, 150
local HEADER_HEIGHT = 44
local MAP_PADDING = 8
local STREET_COLOR = Color3.fromRGB(150, 155, 160)
local ROUTE_COLOR = Color3.fromRGB(40, 170, 255)

local lesson: Lessons.Lesson? = nil
local checkpoint = 1
local stars = 0

local arrows: Folder? = nil
local screen: ScreenGui
local panel: Frame
local mapArea: Frame
local routeLayer: Frame
local target: Frame
local carDot: Frame
local title: TextLabel
local starsLabel: TextLabel
local progressBar: Frame

-- The edges of the town's roads, which the mini-map shows.
local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local MIN_X = TownLayout.STREETS_X[1] - HALF_ROAD
local MAX_X = TownLayout.STREETS_X[#TownLayout.STREETS_X] + HALF_ROAD
local MIN_Z = TownLayout.STREETS_Z[1] - HALF_ROAD
local MAX_Z = TownLayout.STREETS_Z[#TownLayout.STREETS_Z] + HALF_ROAD
local SCALE =
	math.min((MAP_WIDTH - 2 * MAP_PADDING) / (MAX_X - MIN_X), (MAP_HEIGHT - 2 * MAP_PADDING) / (MAX_Z - MIN_Z))

local function toMap(x: number, z: number): Vector2
	return Vector2.new(MAP_PADDING + (x - MIN_X) * SCALE, MAP_PADDING + (z - MIN_Z) * SCALE)
end

local function rounded(frame: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = frame
end

-- A straight line on the mini-map, along a street.
local function line(parent: Instance, x1: number, z1: number, x2: number, z2: number, width: number, color: Color3)
	local a, b = toMap(x1, z1), toMap(x2, z2)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	frame.Size = UDim2.fromOffset(math.abs(b.X - a.X) + width, math.abs(b.Y - a.Y) + width)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
end

local function dot(parent: Instance, name: string, size: number, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = color
	frame.ZIndex = 3
	frame.Parent = parent
	rounded(frame, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(30, 30, 35)
	stroke.Thickness = 2
	stroke.Parent = frame
	return frame
end

local function label(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = size
	text.Position = position
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(35, 35, 40)
	text.Font = Enum.Font.GothamBold
	text.TextSize = textSize
	text.TextXAlignment = if Text.isRightToLeft() then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Parent = parent
	return text
end

local function createMap()
	screen = Instance.new("ScreenGui")
	screen.Name = "LessonGuide"
	screen.ResetOnSpawn = false
	screen.Enabled = false

	-- Top right, below the Lessons button.
	panel = Instance.new("Frame")
	panel.Name = "MiniMap"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, 64)
	panel.Size = UDim2.fromOffset(MAP_WIDTH, HEADER_HEIGHT + MAP_HEIGHT)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BackgroundTransparency = 0.1
	panel.Parent = screen
	rounded(panel, UDim.new(0, 12))

	title = label(panel, "Title", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 4), 15)
	starsLabel = label(panel, "Stars", UDim2.new(1, -16, 0, 16), UDim2.fromOffset(8, 22), 14)
	starsLabel.Font = Enum.Font.GothamMedium

	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.Position = UDim2.fromOffset(8, HEADER_HEIGHT - 4)
	track.Size = UDim2.new(1, -16, 0, 4)
	track.BackgroundColor3 = Color3.fromRGB(220, 220, 225)
	track.BorderSizePixel = 0
	track.Parent = panel
	progressBar = Instance.new("Frame")
	progressBar.Size = UDim2.fromScale(0, 1)
	progressBar.BackgroundColor3 = ROUTE_COLOR
	progressBar.BorderSizePixel = 0
	progressBar.Parent = track

	mapArea = Instance.new("Frame")
	mapArea.Name = "Map"
	mapArea.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
	mapArea.Size = UDim2.fromOffset(MAP_WIDTH, MAP_HEIGHT)
	mapArea.BackgroundColor3 = Color3.fromRGB(110, 165, 95)
	mapArea.ClipsDescendants = true
	mapArea.Parent = panel
	rounded(mapArea, UDim.new(0, 12))

	for _, x in TownLayout.STREETS_X do
		line(mapArea, x, TownLayout.STREETS_Z[1], x, TownLayout.STREETS_Z[#TownLayout.STREETS_Z], 3, STREET_COLOR)
	end
	for _, z in TownLayout.STREETS_Z do
		line(mapArea, TownLayout.STREETS_X[1], z, TownLayout.STREETS_X[#TownLayout.STREETS_X], z, 3, STREET_COLOR)
	end

	routeLayer = Instance.new("Frame")
	routeLayer.Name = "Route"
	routeLayer.Size = UDim2.fromScale(1, 1)
	routeLayer.BackgroundTransparency = 1
	routeLayer.ZIndex = 2
	routeLayer.Parent = mapArea

	target = dot(mapArea, "Next", 10, FINISH_COLOR)
	carDot = dot(mapArea, "Car", 12, Color3.new(1, 1, 1))
	carDot.ZIndex = 4

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- One arrow on the road: a chevron pointing the way to drive.
local function makeArrow(
	parent: Instance,
	x: number,
	z: number,
	dirX: number,
	dirZ: number,
	color: Color3,
	big: boolean
)
	local size = if big then 1.4 else 1
	local position = Vector3.new(x, ARROW_HEIGHT, z)
	local base = CFrame.lookAt(position, position + Vector3.new(dirX, 0, dirZ))
	-- The front is -Z. Each arm runs back from the tip at 45 degrees.
	local armLength = 8 * size
	local reach = armLength / 2 * math.sin(math.rad(45))
	for _, side in { -1, 1 } do
		local arm = Instance.new("Part")
		arm.Name = "Arrow"
		arm.Size = Vector3.new(1.6 * size, 0.1, armLength)
		arm.CFrame = base * CFrame.new(side * reach, 0, -3 * size + reach) * CFrame.Angles(0, side * math.rad(45), 0)
		arm.Color = color
		arm.Material = Enum.Material.Neon
		arm.Transparency = 0.15
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanTouch = false
		arm.CanQuery = false
		arm.CastShadow = false
		arm.Parent = parent
	end
end

local function drawArrows()
	if arrows then
		arrows:Destroy()
		arrows = nil
	end
	local current = lesson
	if not current then
		return
	end
	local route = Lessons.route(current)
	local folder = Instance.new("Folder")
	folder.Name = "LessonArrows"
	local last = #route.checkpoints
	for index = checkpoint, math.min(checkpoint + ARROW_COUNT - 1, last) do
		local point = route.checkpoints[index]
		local color = if index == last then FINISH_COLOR else ARROW_COLOR
		makeArrow(folder, point.x, point.z, point.dirX, point.dirZ, color, point.turn or index == last)
	end
	folder.Parent = workspace
	arrows = folder
end

local function updatePanel()
	local current = lesson
	if not current then
		return
	end
	local route = Lessons.route(current)
	local count = #route.checkpoints
	if current.isTest then
		title.Text = Text.get(current.title)
		starsLabel.Text = ""
	else
		title.Text = `{Text.format("lessonNumber", { number = current.number })}: {Text.get(current.title)}`
		starsLabel.Text = Text.format("lessonStars", { stars = stars, need = Lessons.PASS_STARS })
	end
	progressBar.Size = UDim2.fromScale(math.clamp((checkpoint - 1) / count, 0, 1), 1)
	local point = route.checkpoints[math.min(checkpoint, count)]
	local spot = toMap(point.x, point.z)
	target.Position = UDim2.fromOffset(spot.X, spot.Y)
end

local function drawRoute()
	routeLayer:ClearAllChildren()
	local current = lesson
	if not current then
		return
	end
	local nodes = current.nodes
	for index = 1, #nodes - 1 do
		line(routeLayer, nodes[index][1], nodes[index][2], nodes[index + 1][1], nodes[index + 1][2], 4, ROUTE_COLOR)
	end
end

local function begin(id: string)
	lesson = Lessons.get(id)
	checkpoint = 1
	stars = 0
	screen.Enabled = lesson ~= nil
	drawRoute()
	drawArrows()
	updatePanel()
end

local function finish()
	lesson = nil
	screen.Enabled = false
	drawArrows()
end

function LessonGuide.start()
	createMap()
	local player = Players.LocalPlayer
	local lessonEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BendiLesson") :: RemoteEvent
	lessonEvent.OnClientEvent:Connect(function(message: string, ...)
		if message == "lesson" then
			begin(...)
		elseif message == "status" then
			local nextCheckpoint, earned = ...
			local moved = nextCheckpoint ~= checkpoint
			checkpoint, stars = nextCheckpoint, earned
			if moved then
				drawArrows()
			end
			updatePanel()
		elseif message == "finished" or message == "stopped" then
			finish()
		end
	end)

	-- Keep the car's dot on the mini-map where the car is.
	RunService.RenderStepped:Connect(function()
		if not lesson then
			return
		end
		local car = workspace:FindFirstChild(`BendiCar_{player.Name}`)
		local base = car and car:IsA("Model") and car.PrimaryPart
		carDot.Visible = base ~= nil
		if base then
			local spot = toMap(base.Position.X, base.Position.Z)
			carDot.Position = UDim2.fromOffset(spot.X, spot.Y)
		end
	end)
end

return LessonGuide
