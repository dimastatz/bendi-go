-- The "Licensed driver" badge above the car of every player who has a driving license (PRD-006, requirement 9).
-- The server sets each car's "Licensed" attribute, and every client draws the badge in its own language.

local CollectionService = game:GetService("CollectionService")

local Text = require(script.Parent.Text)

local LicenseBadges = {}

local CAR_TAG = "BendiCar"
local BADGE_NAME = "LicenseBadge"

local function makeBadge(car: Model, base: BasePart)
	local badge = Instance.new("BillboardGui")
	badge.Name = BADGE_NAME
	badge.Adornee = base
	badge.Size = UDim2.fromOffset(180, 34)
	badge.StudsOffset = Vector3.new(0, 10, 0)
	badge.MaxDistance = 200
	badge.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(250, 200, 30)
	label.TextColor3 = Color3.fromRGB(30, 30, 30)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = `★ {Text.get("licensedDriver")}`
	label.Parent = badge
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label

	badge.Parent = car
end

local function update(car: Model)
	local licensed = car:GetAttribute("Licensed") == true
	local badge = car:FindFirstChild(BADGE_NAME)
	if licensed and not badge then
		local base = car.PrimaryPart or car:WaitForChild("Base", 10)
		if base and base:IsA("BasePart") and not car:FindFirstChild(BADGE_NAME) then
			makeBadge(car, base)
		end
	elseif not licensed and badge then
		badge:Destroy()
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	instance:GetAttributeChangedSignal("Licensed"):Connect(function()
		update(instance)
	end)
	task.spawn(update, instance)
end

function LicenseBadges.start()
	CollectionService:GetInstanceAddedSignal(CAR_TAG):Connect(watch)
	for _, car in CollectionService:GetTagged(CAR_TAG) do
		watch(car)
	end
end

return LicenseBadges
