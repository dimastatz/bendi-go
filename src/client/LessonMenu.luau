-- The Levels button and menu (PRD-006, requirements 4 and 5, and PRD-009, requirements 15 and 16).
-- The menu shows the player's level with a progress bar, then every level with its sessions: whether each one is
-- open, locked, or passed, and its best medal. Starting a session shows its goal card first, and Free driving ends
-- the current session. The server checks every request too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = ReplicatedStorage:WaitForChild("Core")
local Lessons = require(Core:WaitForChild("Lessons"))
local Progress = require(Core:WaitForChild("Progress"))

local GoalPanel = require(script.Parent.GoalPanel)
local LicenseCard = require(script.Parent.LicenseCard)
local SessionCards = require(script.Parent.SessionCards)
local Text = require(script.Parent.Text)

local LessonMenu = {}

local BLUE = Color3.fromRGB(58, 150, 232)
local GREEN = Color3.fromRGB(60, 170, 80)
local GRAY = Color3.fromRGB(175, 178, 185)
local YELLOW = Color3.fromRGB(250, 200, 30)
local INK = Color3.fromRGB(35, 35, 40)
local MUTED = Color3.fromRGB(100, 100, 110)
local ROW_HEIGHT = 64
local MEDAL_ICONS = { "🥉", "🥈", "🥇" }

local lessonEvent: RemoteEvent
local progress: Progress.Data = Progress.new()
local rightToLeft = false

local screen: ScreenGui
local menu: Frame
local list: ScrollingFrame
local header: TextLabel
local headerBar: Frame
local licenseButton: TextButton

local function rounded(frame: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
end

local function button(parent: Instance, name: string, label: string, color: Color3, size: UDim2): TextButton
	local item = Instance.new("TextButton")
	item.Name = name
	item.Size = size
	item.BackgroundColor3 = color
	item.TextColor3 = if color == YELLOW then INK else Color3.new(1, 1, 1)
	item.Font = Enum.Font.GothamBold
	item.TextSize = 18
	item.Text = label
	item.Parent = parent
	rounded(item, 12)
	return item
end

local function textLabel(parent: Instance, name: string, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.BackgroundTransparency = 1
	label.TextColor3 = INK
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = if rightToLeft then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Puts `item` `offset` pixels in from the start of the line: the left for English, the right for Hebrew.
local function fromStart(item: GuiObject, offset: number, y: number)
	item.AnchorPoint = Vector2.new(if rightToLeft then 1 else 0, 0.5)
	item.Position = UDim2.new(if rightToLeft then 1 else 0, if rightToLeft then -offset else offset, 0, y)
end

local function fromEnd(item: GuiObject, offset: number, y: number)
	item.AnchorPoint = Vector2.new(if rightToLeft then 0 else 1, 0.5)
	item.Position = UDim2.new(if rightToLeft then 0 else 1, if rightToLeft then offset else -offset, 0, y)
end

local function levelName(level: number): string
	return `{Text.format("levelNumber", { number = level })} · {Text.get(Lessons.LEVELS[level].title)}`
end

local function statusText(lesson: Lessons.Lesson): string
	if not Progress.isUnlocked(progress, lesson.id) then
		return `🔒 {Text.get("locked")}`
	end
	if Progress.isPassed(progress, lesson.id) then
		local icon = MEDAL_ICONS[Progress.medal(progress, lesson.id)] or "✅"
		return `{icon} {Text.get("passed")}`
	end
	return Text.get("notTried")
end

-- A level's title, with how much of it is passed or what opens it.
local function makeLevelRow(level: number, order: number)
	local row = textLabel(list, `Level{level}`, UDim2.new(1, -8, 0, 0), 17)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = order
	local passed, total = Progress.levelProgress(progress, level)
	local detail = if Progress.isLevelOpen(progress, level)
		then Text.format("levelProgress", { passed = passed, total = total })
		else `🔒 {Text.format("levelLocked", { number = level - 1 })}`
	row.Text = `{levelName(level)}\n<font size="14" color="#64646E">{detail}</font>`
	row.RichText = true
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = row
end

local function makeRow(lesson: Lessons.Lesson, order: number)
	local unlocked = Progress.isUnlocked(progress, lesson.id)
	local passed = Progress.isPassed(progress, lesson.id)

	local row = Instance.new("Frame")
	row.Name = lesson.id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT - 6)
	row.BackgroundColor3 = Color3.fromRGB(244, 245, 248)
	row.Parent = list
	rounded(row, 12)

	local badge = Instance.new("TextLabel")
	badge.Name = "Number"
	badge.Size = UDim2.fromOffset(40, 40)
	badge.BackgroundColor3 = if passed then GREEN elseif unlocked then BLUE else GRAY
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 20
	badge.Text = if lesson.isTest
		then "🏁"
		elseif lesson.night then "🌙"
		elseif lesson.expert then "🧭"
		elseif lesson.busy then "🚦"
		elseif lesson.mission then "⭐"
		else tostring(lesson.number)
	badge.Parent = row
	rounded(badge, 20)
	fromStart(badge, 10, (ROW_HEIGHT - 6) / 2)

	local name = textLabel(row, "Title", UDim2.new(1, -170, 0, 22), 17)
	name.Text = GoalPanel.title(lesson)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	fromStart(name, 60, 18)

	local status = textLabel(row, "Status", UDim2.new(1, -170, 0, 18), 14)
	status.Font = Enum.Font.GothamMedium
	status.TextColor3 = MUTED
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.Text = `{statusText(lesson)} · {GoalPanel.goal(lesson)}`
	fromStart(status, 60, 40)

	local start = button(row, "Start", Text.get("start"), if unlocked then GREEN else GRAY, UDim2.fromOffset(92, 40))
	start.AutoButtonColor = unlocked
	fromEnd(start, 10, (ROW_HEIGHT - 6) / 2)
	if unlocked then
		start.Activated:Connect(function()
			menu.Visible = false
			SessionCards.showGoal(lesson.id)
		end)
	end
end

local function refresh()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	for _, level in Lessons.LEVELS do
		order += 1
		makeLevelRow(level.number, order)
		for _, lesson in Lessons.inLevel(level.number) do
			order += 1
			makeRow(lesson, order)
		end
	end

	local level = Progress.level(progress)
	local passed, total = Progress.levelProgress(progress, level)
	header.Text = `{levelName(level)} · {Text.format("levelProgress", { passed = passed, total = total })}`
	headerBar.Size = UDim2.fromScale(if total > 0 then passed / total else 1, 1)
	licenseButton.Visible = progress.license ~= nil
	SessionCards.refresh()
end

local function createMenu()
	menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.5)
	menu.Size = UDim2.fromScale(0.92, 0.85)
	menu.BackgroundColor3 = Color3.new(1, 1, 1)
	menu.Visible = false
	menu.Parent = screen
	rounded(menu, 18)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 620)
	limit.Parent = menu

	local title = textLabel(menu, "Title", UDim2.new(1, -32, 0, 34), 26)
	title.Position = UDim2.fromOffset(16, 8)
	title.Text = Text.get("levels")

	-- The player's level, with a bar for how much of it is passed.
	header = textLabel(menu, "Level", UDim2.new(1, -32, 0, 18), 15)
	header.Position = UDim2.fromOffset(16, 44)
	header.Font = Enum.Font.GothamMedium
	header.TextColor3 = MUTED
	local track = Instance.new("Frame")
	track.Name = "LevelBar"
	track.Position = UDim2.fromOffset(16, 66)
	track.Size = UDim2.new(1, -32, 0, 8)
	track.BackgroundColor3 = Color3.fromRGB(225, 227, 232)
	track.BorderSizePixel = 0
	track.Parent = menu
	rounded(track, 4)
	headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.fromScale(0, 1)
	headerBar.BackgroundColor3 = YELLOW
	headerBar.BorderSizePixel = 0
	headerBar.Parent = track
	rounded(headerBar, 4)

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, 82)
	list.Size = UDim2.new(1, -24, 1, -152)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = menu
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0, 1)
	buttons.Position = UDim2.new(0, 0, 1, -10)
	buttons.Size = UDim2.new(1, 0, 0, 50)
	buttons.Parent = menu
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = buttons

	local free = button(buttons, "FreeDriving", Text.get("freeDriving"), BLUE, UDim2.fromOffset(140, 44))
	free.LayoutOrder = 1
	free.Activated:Connect(function()
		lessonEvent:FireServer("stop")
		menu.Visible = false
	end)
	licenseButton = button(buttons, "License", Text.get("myLicense"), YELLOW, UDim2.fromOffset(140, 44))
	licenseButton.LayoutOrder = 2
	licenseButton.Activated:Connect(function()
		if progress.license then
			menu.Visible = false
			LicenseCard.show(progress.license, false)
		end
	end)
	local close = button(buttons, "Close", Text.get("close"), GRAY, UDim2.fromOffset(110, 44))
	close.LayoutOrder = 3
	close.Activated:Connect(function()
		menu.Visible = false
	end)
end

local function startSession(id: string)
	lessonEvent:FireServer("start", id)
	menu.Visible = false
	SessionCards.hide()
end

function LessonMenu.start()
	rightToLeft = Text.isRightToLeft()
	lessonEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BendiLesson") :: RemoteEvent

	screen = Instance.new("ScreenGui")
	screen.Name = "LessonMenu"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5

	local open = button(screen, "Levels", `🏆 {Text.get("levels")}`, BLUE, UDim2.fromOffset(150, 48))
	open.AnchorPoint = Vector2.new(1, 0)
	open.Position = UDim2.new(1, -12, 0, 8)
	open.TextSize = 20
	open.Activated:Connect(function()
		SessionCards.hide()
		menu.Visible = not menu.Visible
	end)

	createMenu()
	SessionCards.init(screen, startSession, function()
		return progress
	end)
	refresh()
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	lessonEvent.OnClientEvent:Connect(function(message: string, ...)
		if message == "progress" then
			progress = Progress.sanitize((...))
			refresh()
		elseif message == "offer" then
			SessionCards.showGoal((...))
		elseif message == "finished" then
			menu.Visible = false
			SessionCards.showResult((...))
		elseif message == "lesson" then
			menu.Visible = false
			SessionCards.hide()
		elseif message == "license" then
			LicenseCard.show((...), true)
		end
	end)
	lessonEvent:FireServer("progress")
end

return LessonMenu
