-- The arrows on the road and the mini-map during a driving session (PRD-006, requirement 2, and PRD-009, requirements
-- 5, 13, and 14). Only the player driving the session sees them. The server says which session started and which
-- checkpoint is next, and the route itself comes from Core.Lessons, so the client and the server always agree on where
-- the checkpoints are.
-- In an Expert mission there are no arrows, and the mini-map shows only the car. In a night mission, this player's sky
-- is night until the session ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = ReplicatedStorage:WaitForChild("Core")
local Lessons = require(Core:WaitForChild("Lessons"))

local DayNight = require(script.Parent.DayNight)
local RouteMap = require(script.Parent.RouteMap)

local LessonGuide = {}

local ARROW_COUNT = 4 -- how many checkpoints ahead have arrows
local ARROW_HEIGHT = 0.12 -- just above the road paint
local ARROW_COLOR = Color3.fromRGB(40, 170, 255)
local FINISH_COLOR = Color3.fromRGB(250, 200, 30)
local MAP_WIDTH, MAP_HEIGHT = 200, 150

local lesson: Lessons.Lesson? = nil
local checkpoint = 1

local arrows: Folder? = nil
local screen: ScreenGui
local map: RouteMap.Map
local target: Frame
local carDot: Frame

local function createMap()
	screen = Instance.new("ScreenGui")
	screen.Name = "LessonGuide"
	screen.ResetOnSpawn = false
	screen.Enabled = false

	-- Top right, below the Levels button.
	local panel = Instance.new("Frame")
	panel.Name = "MiniMap"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, 64)
	panel.Size = UDim2.fromOffset(MAP_WIDTH, MAP_HEIGHT)
	panel.BackgroundTransparency = 1
	panel.Parent = screen

	map = RouteMap.new(panel, MAP_WIDTH, MAP_HEIGHT)
	target = RouteMap.dot(map, "Next", 10, FINISH_COLOR)
	carDot = RouteMap.dot(map, "Car", 12, Color3.new(1, 1, 1))
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
	if not current or current.expert then
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

local function updateTarget()
	local current = lesson
	if not current then
		return
	end
	local route = Lessons.route(current)
	local point = route.checkpoints[math.min(checkpoint, #route.checkpoints)]
	local spot = map.toMap(point.x, point.z)
	target.Position = UDim2.fromOffset(spot.X, spot.Y)
	target.Visible = not current.expert
end

local function begin(id: string)
	lesson = Lessons.get(id)
	checkpoint = 1
	local current = lesson
	screen.Enabled = current ~= nil
	DayNight.setNight(current ~= nil and current.night == true)
	RouteMap.drawRoute(map, if current and not current.expert then current.nodes else nil)
	drawArrows()
	updateTarget()
end

local function finish()
	lesson = nil
	screen.Enabled = false
	DayNight.setNight(false)
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
			local nextCheckpoint = ...
			if nextCheckpoint ~= checkpoint then
				checkpoint = nextCheckpoint
				drawArrows()
				updateTarget()
			end
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
			local spot = map.toMap(base.Position.X, base.Position.Z)
			carDot.Position = UDim2.fromOffset(spot.X, spot.Y)
		end
	end)
end

return LessonGuide
