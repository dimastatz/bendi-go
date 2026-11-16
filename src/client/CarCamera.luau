-- Picks the camera while driving (PRD-007): the outside view behind the car (ChaseCamera), or the inside view from
-- the driver's seat (CockpitCamera). The button under "Reset car", the V key, or clicking the gamepad's right stick
-- switches between them. The choice is kept until the player leaves the game.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cockpit = require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("Cockpit"))

local ChaseCamera = require(script.Parent.ChaseCamera)
local CockpitCamera = require(script.Parent.CockpitCamera)
local Text = require(script.Parent.Text)

local CarCamera = {}

local SWITCH_ACTION = "BendiSwitchView"

local view: Cockpit.View = "outside"
local currentCar: Model? = nil
local gui: ScreenGui? = nil
local button: TextButton? = nil

local function apply()
	local car = currentCar
	if not car or not car.PrimaryPart then
		return
	end
	if view == "inside" then
		ChaseCamera.stop()
		CockpitCamera.start(car)
	else
		CockpitCamera.stop()
		ChaseCamera.start(car.PrimaryPart)
	end
	if button then
		-- The button names the view it switches to.
		button.Text = if view == "inside" then `🚗 {Text.get("outsideView")}` else `👀 {Text.get("insideView")}`
	end
end

local function switch()
	view = Cockpit.toggle(view)
	apply()
end

local function create(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "ViewButton"
	screen.ResetOnSpawn = false

	local newButton = Instance.new("TextButton")
	newButton.Name = "SwitchView"
	newButton.AnchorPoint = Vector2.new(0.5, 0)
	newButton.Position = UDim2.new(0.5, 0, 0, 62)
	newButton.Size = UDim2.fromOffset(170, 40)
	newButton.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
	newButton.TextColor3 = Color3.fromRGB(30, 30, 30)
	newButton.Font = Enum.Font.GothamBold
	newButton.TextSize = 18
	newButton.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = newButton
	newButton.Activated:Connect(switch)
	button = newButton

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return screen
end

-- Starts the camera for driving `car`, in the view the player picked last.
function CarCamera.start(car: Model)
	currentCar = car
	local screen = gui or create()
	gui = screen
	screen.Enabled = true
	ContextActionService:BindActionAtPriority(
		SWITCH_ACTION,
		function(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then
				switch()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.V,
		Enum.KeyCode.ButtonR3
	)
	apply()
end

function CarCamera.stop()
	currentCar = nil
	ContextActionService:UnbindAction(SWITCH_ACTION)
	CockpitCamera.stop()
	ChaseCamera.stop()
	-- Give the camera back to Roblox, whichever view was on.
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
	if gui then
		gui.Enabled = false
	end
end

return CarCamera
