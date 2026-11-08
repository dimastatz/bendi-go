-- The Bendi Go driving license card (PRD-006, requirement 8), with the player's display name, avatar picture, and
-- the date they passed the test. Its pink card and its fields are inspired by the Israeli driving license.
-- The first time it's shown, confetti falls to celebrate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Progress = require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("Progress"))

local Text = require(script.Parent.Text)

local LicenseCard = {}

local CARD_PINK = Color3.fromRGB(252, 222, 230)
local CARD_PEACH = Color3.fromRGB(255, 238, 222)
local BENDI_BLUE = Color3.fromRGB(58, 150, 232)
local INK = Color3.fromRGB(40, 40, 50)
local CONFETTI_COLORS = {
	Color3.fromRGB(240, 80, 80),
	Color3.fromRGB(250, 200, 30),
	Color3.fromRGB(60, 170, 80),
	Color3.fromRGB(58, 150, 232),
	Color3.fromRGB(180, 100, 220),
}
local CONFETTI_COUNT = 60

local screen: ScreenGui? = nil

local function rounded(frame: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
end

local function text(parent: Instance, value: string, size: UDim2, position: UDim2, bold: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextColor3 = INK
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.TextScaled = true
	label.TextXAlignment = if Text.isRightToLeft() then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function confetti(parent: Instance)
	for _ = 1, CONFETTI_COUNT do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(math.random(), -0.05 - math.random() * 0.3)
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20))
		piece.Rotation = math.random(0, 360)
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
		piece.BorderSizePixel = 0
		piece.ZIndex = 5
		piece.Parent = parent
		local fall = TweenService:Create(
			piece,
			TweenInfo.new(2.5 + math.random() * 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.fromScale(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 1.1),
				Rotation = piece.Rotation + math.random(-540, 540),
			}
		)
		fall.Completed:Connect(function()
			piece:Destroy()
		end)
		fall:Play()
	end
end

function LicenseCard.hide()
	if screen then
		screen:Destroy()
		screen = nil
	end
end

-- Shows the license earned on `date` (like "2026-11-08"). `celebrate` adds confetti.
function LicenseCard.show(date: string, celebrate: boolean)
	LicenseCard.hide()
	local player = Players.LocalPlayer
	local rightToLeft = Text.isRightToLeft()

	local gui = Instance.new("ScreenGui")
	gui.Name = "LicenseCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	screen = gui

	local shade = Instance.new("TextButton")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.45)
	card.Size = UDim2.fromScale(0.9, 0.9)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.Parent = gui
	rounded(card, 18)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(CARD_PINK, CARD_PEACH)
	gradient.Rotation = 30
	gradient.Parent = card
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.6 -- the shape of a real license card
	aspect.Parent = card
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 300)
	limit.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = card

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromScale(1, 0.22)
	header.BackgroundColor3 = BENDI_BLUE
	header.Parent = card
	rounded(header, 18)
	local title = text(
		header,
		`Bendi Go · {Text.get("licenseTitle")}`,
		UDim2.fromScale(0.9, 0.6),
		UDim2.fromScale(0.05, 0.2),
		true
	)
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Center

	-- The photo is on the left, like on the Israeli license, and on the right for Hebrew readers.
	local photo = Instance.new("ImageLabel")
	photo.Name = "Photo"
	photo.AnchorPoint = Vector2.new(if rightToLeft then 1 else 0, 0)
	photo.Position = UDim2.fromScale(if rightToLeft then 0.95 else 0.05, 0.3)
	photo.Size = UDim2.fromScale(0.28, 0.6)
	photo.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
	photo.ScaleType = Enum.ScaleType.Crop
	photo.Parent = card
	rounded(photo, 10)
	task.spawn(function()
		local ok, image = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size180x180
		)
		if ok then
			photo.Image = image
		end
	end)

	local fields = Instance.new("Frame")
	fields.Name = "Fields"
	fields.Position = UDim2.fromScale(if rightToLeft then 0.05 else 0.38, 0.3)
	fields.Size = UDim2.fromScale(0.57, 0.6)
	fields.BackgroundTransparency = 1
	fields.Parent = card
	local rows = {
		{ Text.get("licenseName"), player.DisplayName },
		{ Text.get("licenseDate"), Progress.formatDate(date) },
		{ Text.get("licenseClass"), "B" },
	}
	for index, row in rows do
		local top = (index - 1) / #rows
		local caption = text(fields, row[1], UDim2.fromScale(1, 0.12), UDim2.fromScale(0, top), false)
		caption.TextColor3 = Color3.fromRGB(120, 110, 120)
		text(fields, row[2], UDim2.fromScale(1, 0.18), UDim2.fromScale(0, top + 0.12), true)
	end

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 0)
	close.Position = UDim2.new(0.5, 0, 1, 12)
	close.Size = UDim2.fromOffset(150, 44)
	close.BackgroundColor3 = Color3.fromRGB(250, 200, 30)
	close.TextColor3 = INK
	close.Font = Enum.Font.GothamBold
	close.TextSize = 20
	close.Text = Text.get("close")
	close.Parent = card
	rounded(close, 12)
	close.Activated:Connect(LicenseCard.hide)
	shade.Activated:Connect(LicenseCard.hide)

	gui.Parent = player:WaitForChild("PlayerGui")
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if celebrate then
		confetti(gui)
	end
end

return LicenseCard
