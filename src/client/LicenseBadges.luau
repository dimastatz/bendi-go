-- The badge above every player's car: their level (PRD-009, requirement 15), and "Licensed driver" once they have a
-- driving license (PRD-006, requirement 9). The server sets each car's "Level" and "Licensed" attributes, and every
-- client draws the badge in its own language.

local CollectionService = game:GetService("CollectionService")

local Text = require(script.Parent.Text)

local LicenseBadges = {}

local CAR_TAG = "BendiCar"
local BADGE_NAME = "LicenseBadge"
local LICENSED_COLOR = Color3.fromRGB(250, 200, 30)
local LEVEL_COLOR = Color3.fromRGB(58, 150, 232)

-- What the badge says, or nil when there's nothing to show yet.
local function badgeText(car: Model): string?
	local licensed = car:GetAttribute("Licensed") == true
	local level = car:GetAttribute("Level")
	local levelText = if type(level) == "number" then Text.format("levelNumber", { number = level }) else nil
	if licensed then
		return if levelText
			then `★ {Text.get("licensedDriver")} · {levelText}`
			else `★ {Text.get("licensedDriver")}`
	end
	return levelText
end

local function makeBadge(car: Model, base: BasePart): TextLabel
	local badge = Instance.new("BillboardGui")
	badge.Name = BADGE_NAME
	badge.Adornee = base
	badge.Size = UDim2.fromOffset(240, 34)
	badge.StudsOffset = Vector3.new(0, 10, 0)
	badge.MaxDistance = 200
	badge.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0)
	label.Size = UDim2.fromScale(0, 1)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextColor3 = Color3.fromRGB(30, 30, 30)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Parent = badge
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = label

	badge.Parent = car
	return label
end

local function update(car: Model)
	local text = badgeText(car)
	local badge = car:FindFirstChild(BADGE_NAME)
	if not text then
		if badge then
			badge:Destroy()
		end
		return
	end
	local label = badge and badge:FindFirstChild("Text") :: TextLabel?
	if not label then
		local base = car.PrimaryPart or car:WaitForChild("Base", 10)
		if not base or not base:IsA("BasePart") or car:FindFirstChild(BADGE_NAME) then
			return
		end
		label = makeBadge(car, base)
	end
	local shown = label :: TextLabel
	shown.Text = text
	local licensed = car:GetAttribute("Licensed") == true
	shown.BackgroundColor3 = if licensed then LICENSED_COLOR else LEVEL_COLOR
	shown.TextColor3 = if licensed then Color3.fromRGB(30, 30, 30) else Color3.new(1, 1, 1)
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	for _, name in { "Licensed", "Level" } do
		instance:GetAttributeChangedSignal(name):Connect(function()
			update(instance)
		end)
	end
	task.spawn(update, instance)
end

function LicenseBadges.start()
	CollectionService:GetInstanceAddedSignal(CAR_TAG):Connect(watch)
	for _, car in CollectionService:GetTagged(CAR_TAG) do
		watch(car)
	end
end

return LicenseBadges
