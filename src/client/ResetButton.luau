-- The "Reset car" button (PRD-001, requirement 6), shown at the top of the screen while driving, on every device.

local Players = game:GetService("Players")

local Text = require(script.Parent.Text)

local ResetButton = {}

local gui: ScreenGui? = nil
local onReset: (() -> ())? = nil

local function create(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "ResetButton"
	screen.ResetOnSpawn = false

	local button = Instance.new("TextButton")
	button.Name = "Reset"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 8)
	button.Size = UDim2.fromOffset(170, 48)
	button.BackgroundColor3 = Color3.fromRGB(250, 200, 30)
	button.TextColor3 = Color3.fromRGB(30, 30, 30)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 22
	button.Text = Text.get("resetCar")
	button.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button

	button.Activated:Connect(function()
		if onReset then
			onReset()
		end
	end)

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return screen
end

function ResetButton.show(callback: () -> ())
	onReset = callback
	local screen = gui or create()
	gui = screen
	screen.Enabled = true
end

function ResetButton.hide()
	onReset = nil
	if gui then
		gui.Enabled = false
	end
end

return ResetButton
