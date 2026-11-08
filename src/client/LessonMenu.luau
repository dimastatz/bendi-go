-- The Lessons button and menu (PRD-006, requirements 4 and 5), and what to do next after each lesson.
-- The menu shows every lesson and the driving test: whether it's locked or passed, and its best star count. Locked
-- lessons can't be started, and Free driving ends the current lesson. The server checks every request too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = ReplicatedStorage:WaitForChild("Core")
local Lessons = require(Core:WaitForChild("Lessons"))
local Progress = require(Core:WaitForChild("Progress"))

local LicenseCard = require(script.Parent.LicenseCard)
local Text = require(script.Parent.Text)

local LessonMenu = {}

local BLUE = Color3.fromRGB(58, 150, 232)
local GREEN = Color3.fromRGB(60, 170, 80)
local GRAY = Color3.fromRGB(175, 178, 185)
local YELLOW = Color3.fromRGB(250, 200, 30)
local INK = Color3.fromRGB(35, 35, 40)
local ROW_HEIGHT = 64

local lessonEvent: RemoteEvent
local progress: Progress.Data = Progress.new()
local rightToLeft = false

local screen: ScreenGui
local menu: Frame
local list: ScrollingFrame
local licenseButton: TextButton
local result: Frame
local resultText: TextLabel
local resultButtons: Frame

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

-- A row of buttons, centered.
local function buttonRow(parent: Instance, name: string): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
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

local function startLesson(id: string)
	lessonEvent:FireServer("start", id)
	menu.Visible = false
	result.Visible = false
end

local function statusText(lesson: Lessons.Lesson): string
	if not Progress.isUnlocked(progress, lesson.id) then
		return `🔒 {Text.get("locked")}`
	end
	local best = Progress.best(progress, lesson.id)
	if Progress.isPassed(progress, lesson.id) then
		return if lesson.isTest then "✅" else Text.format("passedBest", { stars = best })
	end
	if best > 0 and not lesson.isTest then
		return Text.format("bestSoFar", { stars = best })
	end
	return Text.get("notTried")
end

local function makeRow(lesson: Lessons.Lesson)
	local unlocked = Progress.isUnlocked(progress, lesson.id)
	local passed = Progress.isPassed(progress, lesson.id)

	local row = Instance.new("Frame")
	row.Name = lesson.id
	row.LayoutOrder = lesson.number
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
	badge.Text = if lesson.isTest then "🏁" else tostring(lesson.number)
	badge.Parent = row
	rounded(badge, 20)
	fromStart(badge, 10, (ROW_HEIGHT - 6) / 2)

	local name = textLabel(row, "Title", UDim2.new(1, -170, 0, 22), 17)
	name.Text = Text.get(lesson.title)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	fromStart(name, 60, 18)

	local status = textLabel(row, "Status", UDim2.new(1, -170, 0, 18), 14)
	status.Font = Enum.Font.GothamMedium
	status.TextColor3 = Color3.fromRGB(100, 100, 110)
	status.Text = statusText(lesson)
	fromStart(status, 60, 40)

	local start = button(row, "Start", Text.get("start"), if unlocked then GREEN else GRAY, UDim2.fromOffset(92, 40))
	start.AutoButtonColor = unlocked
	fromEnd(start, 10, (ROW_HEIGHT - 6) / 2)
	if unlocked then
		start.Activated:Connect(function()
			startLesson(lesson.id)
		end)
	end
end

local function refresh()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, lesson in Lessons.LIST do
		makeRow(lesson)
	end
	licenseButton.Visible = progress.license ~= nil
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
	limit.MaxSize = Vector2.new(460, 580)
	limit.Parent = menu

	local title = textLabel(menu, "Title", UDim2.new(1, -32, 0, 40), 26)
	title.Position = UDim2.fromOffset(16, 8)
	title.Text = Text.get("lessons")

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, 54)
	list.Size = UDim2.new(1, -24, 1, -124)
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

	local buttons = buttonRow(menu, "Buttons")
	buttons.AnchorPoint = Vector2.new(0, 1)
	buttons.Position = UDim2.new(0, 0, 1, -10)
	buttons.Size = UDim2.new(1, 0, 0, 50)

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

local function createResult()
	result = Instance.new("Frame")
	result.Name = "Result"
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = UDim2.fromScale(0.5, 0.55)
	result.Size = UDim2.new(0.92, 0, 0, 190)
	result.BackgroundColor3 = Color3.new(1, 1, 1)
	result.Visible = false
	result.Parent = screen
	rounded(result, 18)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 190)
	limit.Parent = result

	resultText = textLabel(result, "Text", UDim2.new(1, -32, 0, 100), 22)
	resultText.Position = UDim2.fromOffset(16, 12)
	resultText.TextXAlignment = Enum.TextXAlignment.Center

	resultButtons = buttonRow(result, "Buttons")
	resultButtons.AnchorPoint = Vector2.new(0, 1)
	resultButtons.Position = UDim2.new(0, 0, 1, -14)
	resultButtons.Size = UDim2.new(1, 0, 0, 50)
end

-- What to do after a lesson: the next lesson, the same one again, or free driving.
local function showResult(id: string, stars: number, passed: boolean, nextId: string?)
	local lesson = Lessons.get(id)
	if not lesson then
		return
	end
	local values = { stars = stars, need = Lessons.PASS_STARS }
	if lesson.isTest then
		resultText.Text = Text.get(if passed then "testPassed" else "testFailed")
	else
		resultText.Text = Text.format(if passed then "lessonPassed" else "lessonTryAgain", values)
	end

	for _, child in resultButtons:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local after = Lessons.after(id)
	local following = nextId or (if passed and after then after.id else nil)
	if following and Progress.isUnlocked(progress, following) then
		local nextButton = button(resultButtons, "Next", Text.get("nextLesson"), GREEN, UDim2.fromOffset(140, 44))
		nextButton.LayoutOrder = 1
		nextButton.Activated:Connect(function()
			startLesson(following)
		end)
	end
	if not (lesson.isTest and passed) then
		local again = button(resultButtons, "Again", Text.get("tryAgain"), BLUE, UDim2.fromOffset(130, 44))
		again.LayoutOrder = 2
		again.Activated:Connect(function()
			startLesson(id)
		end)
	end
	local free = button(resultButtons, "FreeDriving", Text.get("freeDriving"), GRAY, UDim2.fromOffset(140, 44))
	free.LayoutOrder = 3
	free.Activated:Connect(function()
		result.Visible = false
	end)

	menu.Visible = false
	-- The license card shows itself after the test, so the result would only cover it.
	result.Visible = not (lesson.isTest and passed)
end

function LessonMenu.start()
	rightToLeft = Text.isRightToLeft()
	lessonEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BendiLesson") :: RemoteEvent

	screen = Instance.new("ScreenGui")
	screen.Name = "LessonMenu"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5

	local open = button(screen, "Lessons", `📚 {Text.get("lessons")}`, BLUE, UDim2.fromOffset(150, 48))
	open.AnchorPoint = Vector2.new(1, 0)
	open.Position = UDim2.new(1, -12, 0, 8)
	open.TextSize = 20
	open.Activated:Connect(function()
		result.Visible = false
		menu.Visible = not menu.Visible
	end)

	createMenu()
	createResult()
	refresh()
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	lessonEvent.OnClientEvent:Connect(function(message: string, ...)
		if message == "progress" then
			progress = Progress.sanitize((...))
			refresh()
		elseif message == "finished" then
			showResult(...)
		elseif message == "lesson" then
			menu.Visible = false
			result.Visible = false
		elseif message == "license" then
			LicenseCard.show((...), true)
		end
	end)
	lessonEvent:FireServer("progress")
end

return LessonMenu
