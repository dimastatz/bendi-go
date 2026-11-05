-- Bendi's speech bubble (PRD-002, requirement 7). The server sends a tip's key through the BendiTip remote event,
-- and Bendi says it for about 4 seconds. Tips that arrive while Bendi is talking wait their turn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Text = require(script.Parent.Text)

local BendiTips = {}

local SHOW_TIME = 4
local BENDI_BLUE = Color3.fromRGB(58, 150, 232)

local queue: { string } = {}
local current: string? = nil
local frame: Frame
local label: TextLabel
local scale: UIScale

local function circle(parent: Instance, name: string, size: number, position: UDim2, color: Color3): Frame
	local dot = Instance.new("Frame")
	dot.Name = name
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = position
	dot.Size = UDim2.fromOffset(size, size)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	return dot
end

-- Bendi's face: the blue car with big eyes, from the front.
local function makeFace(parent: Instance, rightToLeft: boolean)
	local face = Instance.new("Frame")
	face.Name = "Bendi"
	face.AnchorPoint = Vector2.new(if rightToLeft then 1 else 0, 0.5)
	face.Position = UDim2.fromScale(if rightToLeft then 1 else 0, 0.5)
	face.Size = UDim2.fromOffset(76, 76)
	face.BackgroundColor3 = BENDI_BLUE
	face.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = face

	for _, x in { 0.3, 0.7 } do
		local eye = circle(face, "Eye", 26, UDim2.fromScale(x, 0.4), Color3.new(1, 1, 1))
		circle(eye, "Pupil", 11, UDim2.fromScale(0.5, 0.6), Color3.fromRGB(20, 20, 20))
	end

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.82)
	plate.Size = UDim2.fromOffset(30, 9)
	plate.BackgroundColor3 = Color3.fromRGB(250, 200, 30)
	plate.BorderSizePixel = 0
	plate.Parent = face
end

local function create()
	local rightToLeft = Text.isRightToLeft()

	local screen = Instance.new("ScreenGui")
	screen.Name = "BendiTips"
	screen.ResetOnSpawn = false

	frame = Instance.new("Frame")
	frame.Name = "Tip"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 66) -- below the Reset car button
	frame.Size = UDim2.new(0.9, 0, 0, 96)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = screen

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(600, 96)
	limit.Parent = frame

	scale = Instance.new("UIScale")
	scale.Parent = frame

	makeFace(frame, rightToLeft)

	-- The bubble sits next to Bendi: on the right for English, on the left for Hebrew.
	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.Position = UDim2.fromOffset(if rightToLeft then 0 else 88, 0)
	bubble.Size = UDim2.new(1, -88, 1, 0)
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = bubble
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = bubble

	label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(35, 35, 40)
	label.Font = Enum.Font.GothamMedium
	label.TextWrapped = true
	label.TextScaled = true
	label.TextXAlignment = if rightToLeft then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	label.Parent = bubble
	local textSize = Instance.new("UITextSizeConstraint")
	textSize.MinTextSize = 12
	textSize.MaxTextSize = 22
	textSize.Parent = label

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function showNext()
	if current then
		return
	end
	local text = table.remove(queue, 1)
	if not text then
		return
	end

	current = text
	label.Text = text
	frame.Visible = true
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	task.delay(SHOW_TIME, function()
		frame.Visible = false
		current = nil
		showNext()
	end)
end

-- Has Bendi say the tip with this key from the Strings table. A tip that is already showing or waiting is skipped.
function BendiTips.show(key: string)
	local text = Text.get(key)
	if text == current or table.find(queue, text) then
		return
	end
	table.insert(queue, text)
	showNext()
end

function BendiTips.start()
	create()
	local tipEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BendiTip") :: RemoteEvent
	tipEvent.OnClientEvent:Connect(BendiTips.show)
end

return BendiTips
