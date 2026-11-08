-- The star counter (PRD-002, requirement 6). It's always on screen. When a star is earned, a big star flies into
-- the counter, the counter pops, and a chime plays.
-- The server keeps the count in the player's "Stars" attribute. It's set once the player's saved stars are loaded,
-- and that first count is shown without a celebration.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local StarCounter = {}

local STAR_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local COUNTER_POSITION = UDim2.fromOffset(12, 8)

local function formatCount(count: number): string
	return `⭐ {count}`
end

function StarCounter.start()
	local player = Players.LocalPlayer

	local screen = Instance.new("ScreenGui")
	screen.Name = "StarCounter"
	screen.ResetOnSpawn = false

	local counter = Instance.new("TextLabel")
	counter.Name = "Counter"
	counter.Position = COUNTER_POSITION
	counter.Size = UDim2.fromOffset(120, 48)
	counter.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	counter.BackgroundTransparency = 0.1
	counter.TextColor3 = Color3.fromRGB(40, 40, 40)
	counter.Font = Enum.Font.GothamBold
	counter.TextSize = 26
	counter.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = counter

	local scale = Instance.new("UIScale")
	scale.Parent = counter

	local chime = Instance.new("Sound")
	chime.SoundId = STAR_SOUND
	chime.Volume = 0.6
	chime.Parent = screen

	screen.Parent = player:WaitForChild("PlayerGui")

	local shown: number? = player:GetAttribute("Stars")
	counter.Text = formatCount(shown or 0)

	local function celebrate()
		local flyer = Instance.new("TextLabel")
		flyer.AnchorPoint = Vector2.new(0.5, 0.5)
		flyer.Position = UDim2.fromScale(0.5, 0.45)
		flyer.Size = UDim2.fromOffset(120, 120)
		flyer.BackgroundTransparency = 1
		flyer.Text = "⭐"
		flyer.TextScaled = true
		flyer.Parent = screen

		local flight = TweenService:Create(flyer, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = COUNTER_POSITION + UDim2.fromOffset(30, 24),
			Size = UDim2.fromOffset(30, 30),
		})
		flight.Completed:Connect(function()
			flyer:Destroy()
			counter.Text = formatCount(shown or 0)
			scale.Scale = 1.5
			TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			chime:Play()
		end)
		flight:Play()
	end

	player:GetAttributeChangedSignal("Stars"):Connect(function()
		local count = player:GetAttribute("Stars") or 0
		local earned = shown ~= nil and count > shown
		shown = count
		if earned then
			celebrate()
		else
			counter.Text = formatCount(count)
		end
	end)
end

return StarCounter
