-- The inside view from the driver's seat (PRD-007). The camera sits where the driver's eyes are and moves with the
-- car. The player can look around to see the instructor and check the sides: hold the right mouse button and move
-- the mouse, drag a finger on the screen, push the right stick, or hold Q or E. Letting go turns the view back to
-- the road.
-- While inside, the player's own character is hidden (the camera is where their head is), the windows are made
-- clearer, and the player's hands hold the steering wheel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Cockpit = require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("Cockpit"))

local CockpitCamera = {}

local BIND_NAME = "BendiCockpitCamera"
local BASE_HEIGHT = 0.5 -- the car's base center is this far above the ground
local REST_PITCH = -8 -- looking a little down, at the road ahead and the dashboard
local FIELD_OF_VIEW = 80
local MOUSE_TURN = 0.3 -- degrees per pixel
local TOUCH_TURN = 0.35
local STICK_TURN = 140 -- degrees per second at full stick
local KEY_TURN = 160
local STICK_DEADZONE = 0.2
local WINDOW_CLEARING = 0.6
local WINDOW_NAMES = { Windows = true, Windshield = true, RearWindow = true }
local HAND_ANGLE = math.rad(60) -- hands at 10 and 2 o'clock
local DEFAULT_SKIN = Color3.fromRGB(225, 175, 135)

local running = false
local connections: { RBXScriptConnection } = {}
local hands: { BasePart } = {}
local clearedWindows: { BasePart } = {}
local savedFieldOfView = 70

-- Sets how see-through the local player's character looks to them (0 is normal, 1 is hidden).
local function setCharacterHidden(amount: number)
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = amount
		end
	end
end

local function skinColor(): Color3
	local character = Players.LocalPlayer.Character
	local hand = character and character:FindFirstChild("RightHand")
	if hand and hand:IsA("BasePart") then
		return hand.Color
	end
	return DEFAULT_SKIN
end

local function makeHand(camera: Camera): Part
	local hand = Instance.new("Part")
	hand.Name = "BendiHand"
	hand.Size = Vector3.new(0.45, 0.55, 0.4)
	hand.Color = skinColor()
	hand.Material = Enum.Material.SmoothPlastic
	hand.Anchored = true
	hand.CanCollide = false
	hand.CanTouch = false
	hand.CanQuery = false
	hand.CastShadow = false
	-- Parts inside the camera are only seen by this player.
	hand.Parent = camera
	return hand
end

function CockpitCamera.start(car: Model)
	CockpitCamera.stop()
	local base = car.PrimaryPart
	local camera = workspace.CurrentCamera
	if not base or not camera then
		return
	end
	running = true
	savedFieldOfView = camera.FieldOfView

	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") and WINDOW_NAMES[part.Name] then
			part.LocalTransparencyModifier = WINDOW_CLEARING
			table.insert(clearedWindows, part)
		end
	end
	hands = { makeHand(camera), makeHand(camera) }
	local hub = car:FindFirstChild("SteeringHub") :: BasePart?

	local look: Cockpit.Look = { yaw = 0, pitch = 0 }
	local turnYaw, turnPitch = 0, 0 -- turned by the mouse or fingers since the last frame
	local stick = Vector2.zero
	local dragging: { [InputObject]: boolean } = {}

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			-- Only fingers that start on the world drag the view, not ones on buttons or pedals.
			if input.UserInputType == Enum.UserInputType.Touch and not processed then
				dragging[input] = true
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			dragging[input] = nil
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
					turnYaw -= input.Delta.X * MOUSE_TURN
					turnPitch -= input.Delta.Y * MOUSE_TURN
				end
			elseif input.UserInputType == Enum.UserInputType.Touch and dragging[input] then
				-- Dragging moves the world with the finger, like the normal Roblox touch camera.
				turnYaw += input.Delta.X * TOUCH_TURN
				turnPitch += input.Delta.Y * TOUCH_TURN
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
				stick = Vector2.new(input.Position.X, input.Position.Y)
			end
		end)
	)

	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
		local useStick = stick.Magnitude > STICK_DEADZONE
		if useStick then
			turnYaw -= stick.X * STICK_TURN * dt
			turnPitch += stick.Y * STICK_TURN * dt
		end
		local keys = (if UserInputService:IsKeyDown(Enum.KeyCode.Q) then 1 else 0)
			- (if UserInputService:IsKeyDown(Enum.KeyCode.E) then 1 else 0)
		turnYaw += keys * KEY_TURN * dt
		local holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
			or next(dragging) ~= nil
			or useStick
			or keys ~= 0
		look = Cockpit.look(look, turnYaw, turnPitch, holding, dt)
		turnYaw, turnPitch = 0, 0

		local eye = Cockpit.EYE
		local view = base.CFrame
			* CFrame.new(eye.x, eye.y - BASE_HEIGHT, eye.z)
			* CFrame.Angles(0, math.rad(look.yaw), 0)
			* CFrame.Angles(math.rad(look.pitch + REST_PITCH), 0, 0)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FIELD_OF_VIEW
		camera.CFrame = view
		camera.Focus = view

		-- Roblox's own camera scripts reset this every frame, so it's set again after them.
		setCharacterHidden(1)

		if hub then
			for index, hand in hands do
				local side = if index == 1 then 1 else -1
				hand.CFrame = hub.CFrame
					* CFrame.Angles(0, 0, side * HAND_ANGLE)
					* CFrame.new(0, Cockpit.WHEEL_RADIUS, 0.05)
			end
		end
	end)
end

function CockpitCamera.stop()
	if not running then
		return
	end
	running = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	for _, connection in connections do
		connection:Disconnect()
	end
	connections = {}
	for _, hand in hands do
		hand:Destroy()
	end
	hands = {}
	for _, window in clearedWindows do
		window.LocalTransparencyModifier = 0
	end
	clearedWindows = {}
	setCharacterHidden(0)
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = savedFieldOfView
	end
end

return CockpitCamera
