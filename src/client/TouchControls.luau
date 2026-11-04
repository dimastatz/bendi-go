-- On-screen pedals and steering buttons for phones and tablets (PRD-001, requirement 2).
-- Roblox's own thumbstick and jump button are hidden while these are shown, so there's one clear way to drive.
-- The brake pedal works like the S key: it brakes, and once the car stops, it reverses.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Text = require(script.Parent.Text)

local TouchControls = {}

-- How many fingers are on each button.
local held = { gas = 0, brake = 0, left = 0, right = 0 }
local gui: ScreenGui? = nil

local function addButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, color: Color3)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.2
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 28
	button.Text = text
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = button

	button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		held[name] += 1
		-- Each finger has its own InputObject. Watching it means lifting the finger releases the button,
		-- even if the finger slid off the button first.
		local connection: RBXScriptConnection
		connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local state = input.UserInputState
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				connection:Disconnect()
				held[name] = math.max(held[name] - 1, 0)
			end
		end)
	end)
end

local function create(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "TouchControls"
	screen.ResetOnSpawn = false

	local steerColor = Color3.fromRGB(58, 150, 232)
	addButton(screen, "left", "◀", UDim2.fromOffset(110, 110), UDim2.new(0, 24, 1, -134), steerColor)
	addButton(screen, "right", "▶", UDim2.fromOffset(110, 110), UDim2.new(0, 150, 1, -134), steerColor)
	addButton(
		screen,
		"brake",
		Text.get("brake"),
		UDim2.fromOffset(110, 110),
		UDim2.new(1, -260, 1, -134),
		Color3.fromRGB(210, 60, 50)
	)
	addButton(
		screen,
		"gas",
		Text.get("gas"),
		UDim2.fromOffset(110, 160),
		UDim2.new(1, -134, 1, -184),
		Color3.fromRGB(60, 170, 80)
	)

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return screen
end

-- Shows the controls, but only on devices with a touch screen.
function TouchControls.show()
	if not UserInputService.TouchEnabled then
		return
	end
	local screen = gui or create()
	gui = screen
	screen.Enabled = true
	GuiService.TouchControlsEnabled = false
end

function TouchControls.hide()
	if not gui then
		return
	end
	gui.Enabled = false
	GuiService.TouchControlsEnabled = true
	for name in held do
		held[name] = 0
	end
end

-- The driving input from the buttons, in the same shape as CarPhysics.Input.
function TouchControls.getInput()
	local throttle = (if held.gas > 0 then 1 else 0) - (if held.brake > 0 then 1 else 0)
	local steer = (if held.right > 0 then 1 else 0) - (if held.left > 0 then 1 else 0)
	return { throttle = throttle, steer = steer, brake = false }
end

return TouchControls
