-- The progress panel while driving a session (PRD-009, requirements 4, 9, and 14), at the top left under the star
-- counter. It shows the session's goal and how close the player is (for example "2 of 3"), a bar for how much of the
-- route is done with a mark for each checkpoint, and an End button. In an Expert mission, it also shows where the
-- instructor says to turn, a few seconds before each turn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = ReplicatedStorage:WaitForChild("Core")
local LessonRoute = require(Core:WaitForChild("LessonRoute"))
local Lessons = require(Core:WaitForChild("Lessons"))

local Text = require(script.Parent.Text)

local GoalPanel = {}

local WIDTH = 280
local BAR_COLOR = Color3.fromRGB(40, 170, 255)
local DONE_COLOR = Color3.fromRGB(60, 170, 80)
local INK = Color3.fromRGB(35, 35, 40)
local MUTED = Color3.fromRGB(100, 100, 110)
local DIRECTION_DISTANCE = 110 -- the instructor says where to turn when the car is this close to the turn
local FINISH_CHECKPOINTS = 3 -- "the finish is just ahead" when this few checkpoints are left

local lessonEvent: RemoteEvent
local lesson: Lessons.Lesson? = nil
local checkpoint = 1
local count = 0

local screen: ScreenGui
local title: TextLabel
local goalLabel: TextLabel
local counter: TextLabel
local fill: Frame
local ticks: Frame
local direction: TextLabel

-- The name of a session as players see it: "Lesson 2: Traffic lights", "Driving test", or a mission's name.
function GoalPanel.title(item: Lessons.Lesson): string
	if item.mission or item.isTest then
		return Text.get(item.title)
	end
	return `{Text.format("lessonNumber", { number = item.number })}: {Text.get(item.title)}`
end

-- The goal in words, like "Stop at 3 red lights".
function GoalPanel.goal(item: Lessons.Lesson): string
	local key, values = Lessons.goalText(item.goal)
	return Text.format(key, values)
end

local function label(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = size
	text.Position = position
	text.BackgroundTransparency = 1
	text.TextColor3 = INK
	text.Font = Enum.Font.GothamBold
	text.TextSize = textSize
	text.TextXAlignment = if Text.isRightToLeft() then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Parent = parent
	return text
end

local function rounded(frame: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
end

local function create()
	screen = Instance.new("ScreenGui")
	screen.Name = "GoalPanel"
	screen.ResetOnSpawn = false
	screen.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Position = UDim2.fromOffset(12, 64)
	panel.Size = UDim2.fromOffset(WIDTH, 92)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BackgroundTransparency = 0.08
	panel.Parent = screen
	rounded(panel, 12)

	title = label(panel, "Title", UDim2.new(1, -86, 0, 18), UDim2.fromOffset(10, 6), 14)
	title.Font = Enum.Font.GothamMedium
	title.TextColor3 = MUTED

	local stop = Instance.new("TextButton")
	stop.Name = "End"
	stop.AnchorPoint = Vector2.new(1, 0)
	stop.Position = UDim2.new(1, -8, 0, 6)
	stop.Size = UDim2.fromOffset(64, 24)
	stop.BackgroundColor3 = Color3.fromRGB(175, 178, 185)
	stop.TextColor3 = Color3.new(1, 1, 1)
	stop.Font = Enum.Font.GothamBold
	stop.TextSize = 14
	stop.Text = Text.get("endDrive")
	stop.Parent = panel
	rounded(stop, 8)
	stop.Activated:Connect(function()
		lessonEvent:FireServer("stop")
	end)

	goalLabel = label(panel, "Goal", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 28), 17)
	counter = label(panel, "Counter", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 50), 15)
	counter.TextColor3 = DONE_COLOR

	local track = Instance.new("Frame")
	track.Name = "Route"
	track.Position = UDim2.fromOffset(10, 74)
	track.Size = UDim2.new(1, -20, 0, 8)
	track.BackgroundColor3 = Color3.fromRGB(220, 222, 228)
	track.BorderSizePixel = 0
	track.Parent = panel
	rounded(track, 4)
	fill = Instance.new("Frame")
	fill.Name = "Done"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = BAR_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = track
	rounded(fill, 4)
	ticks = Instance.new("Frame")
	ticks.Name = "Checkpoints"
	ticks.Size = UDim2.fromScale(1, 1)
	ticks.BackgroundTransparency = 1
	ticks.ZIndex = 2
	ticks.Parent = track

	direction = label(panel, "Direction", UDim2.new(1, -20, 0, 0), UDim2.fromOffset(10, 88), 16)
	direction.AutomaticSize = Enum.AutomaticSize.Y
	direction.TextWrapped = true
	direction.TextTruncate = Enum.TextTruncate.None
	direction.TextColor3 = Color3.fromRGB(30, 110, 200)
	direction.Visible = false
	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = panel

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- A thin mark on the route bar for every checkpoint, so players see the route coming in steps.
local function drawTicks(total: number)
	ticks:ClearAllChildren()
	for index = 1, total - 1 do
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0)
		tick.Position = UDim2.fromScale(index / total, 0)
		tick.Size = UDim2.new(0, 1, 1, 0)
		tick.BackgroundColor3 = Color3.new(1, 1, 1)
		tick.BackgroundTransparency = 0.3
		tick.BorderSizePixel = 0
		tick.Parent = ticks
	end
end

local function update()
	local current = lesson
	if not current then
		return
	end
	local goal = current.goal
	if goal.kind == "clean" then
		counter.Text = Text.format("rulesMissed", { count = count })
		counter.TextColor3 = if count == 0 then DONE_COLOR else Color3.fromRGB(230, 130, 30)
	elseif goal.kind == "finish" then
		counter.Text = ""
	else
		counter.Text = Text.format("goalCounter", { count = math.min(count, goal.count :: number), need = goal.count })
		counter.TextColor3 = if count >= (goal.count :: number) then DONE_COLOR else INK
	end
	local total = #Lessons.route(current).checkpoints
	fill.Size = UDim2.fromScale(math.clamp((checkpoint - 1) / total, 0, 1), 1)
end

local function begin(id: string)
	lesson = Lessons.get(id)
	local current = lesson
	checkpoint, count = 1, 0
	screen.Enabled = current ~= nil
	direction.Visible = false
	if current then
		title.Text = GoalPanel.title(current)
		goalLabel.Text = GoalPanel.goal(current)
		drawTicks(#Lessons.route(current).checkpoints)
		update()
	end
end

-- What the instructor says in an Expert mission, or nil when there's nothing to say yet.
local function directionText(current: Lessons.Lesson, x: number, z: number): string?
	local route = Lessons.route(current)
	local turn = LessonRoute.nextTurn(route, checkpoint, x, z)
	if turn then
		if turn.distance > DIRECTION_DISTANCE then
			return nil
		elseif turn.roundabout then
			return `🔄 {Text.get(
				if turn.way == "right"
					then "roundaboutRight"
					elseif turn.way == "left" then "roundaboutLeft"
					else "roundaboutStraight"
			)}`
		end
		return if turn.way == "right" then `➡️ {Text.get("turnRight")}` else `⬅️ {Text.get("turnLeft")}`
	end
	if #route.checkpoints - checkpoint < FINISH_CHECKPOINTS then
		return `🏁 {Text.get("finishAhead")}`
	end
	return nil
end

function GoalPanel.start()
	lessonEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BendiLesson") :: RemoteEvent
	create()
	local player = Players.LocalPlayer
	lessonEvent.OnClientEvent:Connect(function(message: string, ...)
		if message == "lesson" then
			begin(...)
		elseif message == "status" then
			local nextCheckpoint, _, goalCount = ...
			checkpoint, count = nextCheckpoint, goalCount or 0
			update()
		elseif message == "finished" or message == "stopped" then
			lesson = nil
			screen.Enabled = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		local current = lesson
		if not current or not current.expert then
			return
		end
		local car = workspace:FindFirstChild(`BendiCar_{player.Name}`)
		local base = car and car:IsA("Model") and car.PrimaryPart
		local text = if base then directionText(current, base.Position.X, base.Position.Z) else nil
		direction.Visible = text ~= nil
		if text then
			direction.Text = text
		end
	end)
end

return GoalPanel
