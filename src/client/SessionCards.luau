-- The goal card before a session starts, and the result card at its finish line (PRD-009, requirements 2, 7, 8, and
-- 15). The goal card says what to do, what passing needs, and shows the route on a map. The result card shows a
-- bronze, silver, or gold medal, or "Not yet" with what went well and what to practise, never "failed", with the
-- player's level and buttons for what to do next.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = ReplicatedStorage:WaitForChild("Core")
local Lessons = require(Core:WaitForChild("Lessons"))
local Progress = require(Core:WaitForChild("Progress"))

local GoalPanel = require(script.Parent.GoalPanel)
local RouteMap = require(script.Parent.RouteMap)
local Text = require(script.Parent.Text)

local SessionCards = {}

-- What the server sends when a session ends (see LessonRunner.Result on the server).
export type Result = {
	id: string,
	stars: number,
	count: number,
	need: number?,
	passed: boolean,
	medal: number,
	missed: number,
	practice: { string },
	nextId: string?,
	level: number,
	levelUp: boolean,
}

local BLUE = Color3.fromRGB(58, 150, 232)
local GREEN = Color3.fromRGB(60, 170, 80)
local GRAY = Color3.fromRGB(175, 178, 185)
local YELLOW = Color3.fromRGB(250, 200, 30)
local INK = Color3.fromRGB(35, 35, 40)
local MUTED = Color3.fromRGB(100, 100, 110)
local MAP_WIDTH, MAP_HEIGHT = 220, 160
local MEDALS = {
	{ icon = "🥉", title = "medalBronze", note = "medalBronzeNote" },
	{ icon = "🥈", title = "medalSilver", note = "medalSilverNote" },
	{ icon = "🥇", title = "medalGold", note = "medalGoldNote" },
}

local startSession: (id: string) -> ()
local getProgress: () -> Progress.Data

local goalCard: Frame
local goalLevel: TextLabel
local goalTitle: TextLabel
local goalText: TextLabel
local goalMap: RouteMap.Map
local goalStart: TextButton
local goalId: string? = nil

local resultCard: Frame
local resultTitle: TextLabel
local resultNote: TextLabel
local resultLevel: TextLabel
local resultBar: Frame
local resultButtons: Frame

local function rounded(frame: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
end

local function textLabel(parent: Instance, name: string, height: number, textSize: number, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, 0, 0, height)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.TextColor3 = INK
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

local function button(parent: Instance, name: string, label: string, color: Color3, width: number, order: number)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Size = UDim2.fromOffset(width, 44)
	item.BackgroundColor3 = color
	item.TextColor3 = if color == YELLOW then INK else Color3.new(1, 1, 1)
	item.Font = Enum.Font.GothamBold
	item.TextSize = 18
	item.Text = label
	item.LayoutOrder = order
	item.Parent = parent
	rounded(item, 12)
	return item
end

-- A row of buttons, centered.
local function buttonRow(parent: Instance, order: number): Frame
	local row = Instance.new("Frame")
	row.Name = "Buttons"
	row.Size = UDim2.new(1, 0, 0, 50)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	return row
end

-- A white card in the middle of the screen, with its contents stacked from top to bottom.
local function card(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.92, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Visible = false
	frame.Parent = parent
	rounded(frame, 18)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, math.huge)
	limit.Parent = frame
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 16)
	end
	padding.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function levelName(level: number): string
	local info = Lessons.LEVELS[level]
	local name = Text.format("levelNumber", { number = level })
	return if info then `{name} · {Text.get(info.title)}` else name
end

local function createGoalCard(parent: Instance)
	goalCard = card(parent, "GoalCard")
	goalLevel = textLabel(goalCard, "Level", 18, 14, 1)
	goalLevel.Font = Enum.Font.GothamMedium
	goalLevel.TextColor3 = MUTED
	goalTitle = textLabel(goalCard, "Title", 28, 24, 2)
	local yourGoal = textLabel(goalCard, "YourGoal", 18, 14, 3)
	yourGoal.Text = `🎯 {Text.get("yourGoal")}`
	yourGoal.TextColor3 = MUTED
	goalText = textLabel(goalCard, "Goal", 28, 22, 4)
	goalText.TextColor3 = BLUE
	local rules = textLabel(goalCard, "Rules", 18, 15, 5)
	rules.Font = Enum.Font.GothamMedium
	rules.TextColor3 = MUTED
	rules.Text = Text.get("goalRules")

	local holder = Instance.new("Frame")
	holder.Name = "MapHolder"
	holder.Size = UDim2.fromOffset(MAP_WIDTH, MAP_HEIGHT)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = 6
	holder.Parent = goalCard
	goalMap = RouteMap.new(holder, MAP_WIDTH, MAP_HEIGHT)

	local buttons = buttonRow(goalCard, 7)
	goalStart = button(buttons, "Start", `▶ {Text.get("start")}`, GREEN, 150, 1)
	goalStart.Activated:Connect(function()
		local id = goalId
		if id then
			SessionCards.hide()
			startSession(id)
		end
	end)
	button(buttons, "Close", Text.get("close"), GRAY, 120, 2).Activated:Connect(SessionCards.hide)
end

local function createResultCard(parent: Instance)
	resultCard = card(parent, "ResultCard")
	resultTitle = textLabel(resultCard, "Title", 34, 28, 1)
	resultNote = textLabel(resultCard, "Note", 20, 17, 2)
	resultNote.Font = Enum.Font.GothamMedium
	resultLevel = textLabel(resultCard, "Level", 18, 15, 3)
	resultLevel.TextColor3 = MUTED

	local track = Instance.new("Frame")
	track.Name = "LevelBar"
	track.Size = UDim2.new(0.8, 0, 0, 10)
	track.BackgroundColor3 = Color3.fromRGB(225, 227, 232)
	track.BorderSizePixel = 0
	track.LayoutOrder = 4
	track.Parent = resultCard
	rounded(track, 5)
	resultBar = Instance.new("Frame")
	resultBar.Size = UDim2.fromScale(0, 1)
	resultBar.BackgroundColor3 = YELLOW
	resultBar.BorderSizePixel = 0
	resultBar.Parent = track
	rounded(resultBar, 5)

	resultButtons = buttonRow(resultCard, 5)
end

-- Shows the goal card for session `id`. The menu only offers open sessions, and the server checks again on Start.
function SessionCards.showGoal(id: string)
	local item = Lessons.get(id)
	if not item then
		return
	end
	goalId = id
	goalLevel.Text = levelName(item.level)
	goalTitle.Text = GoalPanel.title(item)
	goalText.Text = GoalPanel.goal(item)
	RouteMap.drawRoute(goalMap, item.nodes)
	resultCard.Visible = false
	goalCard.Visible = true
end

-- The player's level, and how much of it is passed, on the result card.
function SessionCards.refresh()
	local data = getProgress()
	local level = Progress.level(data)
	local passed, total = Progress.levelProgress(data, level)
	resultLevel.Text = `{levelName(level)} · {Text.format("levelProgress", { passed = passed, total = total })}`
	resultBar.Size = UDim2.fromScale(if total > 0 then passed / total else 1, 1)
end

local function noteFor(result: Result): string
	if result.passed then
		return Text.get(MEDALS[result.medal].note)
	end
	local item = Lessons.get(result.id) :: Lessons.Lesson
	local note = if item.goal.kind == "clean"
		then Text.format("notYetClean", { count = result.missed })
		else Text.format("notYetCount", { count = result.count, need = result.need })
	if #result.practice > 0 then
		local rules = {}
		for _, key in result.practice do
			table.insert(rules, Text.get(key))
		end
		note ..= `\n{Text.format("practiceLine", { rules = table.concat(rules, ", ") })}`
	end
	return note
end

local function resultButtonsFor(result: Result)
	for _, child in resultButtons:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	-- The server only sends a next session that's open.
	local nextId = result.nextId
	if nextId then
		button(resultButtons, "Next", `{Text.get("next")} ▶`, GREEN, 120, 1).Activated:Connect(function()
			SessionCards.showGoal(nextId)
		end)
	end
	button(resultButtons, "Again", Text.get("tryAgain"), BLUE, 130, 2).Activated:Connect(function()
		SessionCards.hide()
		startSession(result.id)
	end)
	button(resultButtons, "FreeDriving", Text.get("freeDriving"), GRAY, 150, 3).Activated:Connect(SessionCards.hide)
end

-- Shows how a session went, with what to do next.
function SessionCards.showResult(result: Result)
	local item = Lessons.get(result.id)
	if not item then
		return
	end
	local medal = MEDALS[result.medal]
	resultTitle.Text = if result.passed and medal then `{medal.icon} {Text.get(medal.title)}` else Text.get("notYet")
	resultNote.Text = noteFor(result)
	if result.levelUp then
		resultTitle.Text ..= `\n🎉 {Text.format("levelUp", { number = result.level })}`
	end
	SessionCards.refresh()
	resultButtonsFor(result)
	goalCard.Visible = false
	-- The license card shows itself after a passed test, so the result would only cover it.
	resultCard.Visible = not (item.isTest and result.passed)
end

function SessionCards.hide()
	goalCard.Visible = false
	resultCard.Visible = false
end

-- Builds both cards in `screen`. `start` starts a session, and `progress` returns the player's progress.
function SessionCards.init(screen: ScreenGui, start: (id: string) -> (), progress: () -> Progress.Data)
	startSession = start
	getProgress = progress
	createGoalCard(screen)
	createResultCard(screen)
end

return SessionCards
