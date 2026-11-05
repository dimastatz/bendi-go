-- Drives the local player's Bendi car while they sit in its driver seat.
-- The driver's client owns the car's physics, so it reads input every frame, runs CarPhysics, and sets
-- the Drive and Turn constraints directly. Space brakes instead of jumping out of the car.
-- While driving, the chase camera, the Reset car button, and (on touch screens) the pedals are shown.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = ReplicatedStorage:WaitForChild("Core")
local CarPhysics = require(Core:WaitForChild("CarPhysics"))
local DriverInput = require(Core:WaitForChild("DriverInput"))
local TownLayout = require(Core:WaitForChild("TownLayout"))

local ChaseCamera = require(script.Parent.ChaseCamera)
local ResetButton = require(script.Parent.ResetButton)
local Speedometer = require(script.Parent.Speedometer)
local TouchControls = require(script.Parent.TouchControls)

local CarController = {}

local CAR_TAG = "BendiCar"
local BRAKE_ACTION = "BendiBrake"
local RESET_ACTION = "BendiReset"
local RESET_COOLDOWN = 1 -- seconds between resets
local FALLEN_HEIGHT = -20 -- a car below this has fallen through the map, so it's reset
local HORIZONTAL = Vector3.new(1, 0, 1)

local braking = false
local driveConnection: RBXScriptConnection? = nil
local currentBase: BasePart? = nil
local lastReset = -math.huge

-- Puts the car upright on the nearest road, facing the way traffic goes (PRD-001, requirement 6).
local function resetCar()
	local base = currentBase
	if not base or os.clock() - lastReset < RESET_COOLDOWN then
		return
	end
	lastReset = os.clock()

	local look = base.CFrame.LookVector
	local pose = TownLayout.resetPose(base.Position.X, base.Position.Z, look.X, look.Z)
	local position = Vector3.new(pose.x, 0, pose.z)
	-- Moving the base moves the whole car, and the driver with it. The base is 1 stud tall, so lifting its center
	-- 1 stud drops the car gently onto the road.
	base.CFrame = CFrame.lookAt(position, position + Vector3.new(pose.dirX, 0, pose.dirZ)) * CFrame.new(0, 1, 0)
	base.AssemblyLinearVelocity = Vector3.zero
	base.AssemblyAngularVelocity = Vector3.zero
end

local function onBrake(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	braking = inputState == Enum.UserInputState.Begin
	-- Sinking the input stops Space from also making the character jump out of the seat.
	return Enum.ContextActionResult.Sink
end

local function onReset(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		resetCar()
	end
	return Enum.ContextActionResult.Sink
end

local function stopDriving()
	if driveConnection then
		driveConnection:Disconnect()
		driveConnection = nil
	end
	ContextActionService:UnbindAction(BRAKE_ACTION)
	ContextActionService:UnbindAction(RESET_ACTION)
	braking = false
	currentBase = nil
	ChaseCamera.stop()
	ResetButton.hide()
	Speedometer.hide()
	TouchControls.hide()
end

local function startDriving(seat: VehicleSeat)
	stopDriving()

	local car = seat.Parent :: Model
	local base = car.PrimaryPart :: BasePart
	local drive = base:WaitForChild("Drive") :: LinearVelocity
	local turn = base:WaitForChild("Turn") :: AngularVelocity
	currentBase = base

	-- ButtonA is the gamepad's jump button, so it brakes too instead of jumping out of the car.
	ContextActionService:BindActionAtPriority(
		BRAKE_ACTION,
		onBrake,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonB
	)
	ContextActionService:BindActionAtPriority(
		RESET_ACTION,
		onReset,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonY
	)
	driveConnection = RunService.PreSimulation:Connect(function(dt)
		if base.Position.Y < FALLEN_HEIGHT then
			resetCar()
			return
		end

		local flatForward = base.CFrame.LookVector * HORIZONTAL
		if flatForward.Magnitude < 1e-3 then
			return
		end
		local forward = flatForward.Unit

		-- Start from the car's real speed, so hitting a wall doesn't build up speed it doesn't have.
		local currentSpeed = base.AssemblyLinearVelocity:Dot(forward)
		local input = DriverInput.combine({
			-- The seat reads the keyboard and gamepad: W/S and arrows, the triggers, and the left stick.
			{ throttle = seat.ThrottleFloat, steer = seat.SteerFloat, brake = braking },
			TouchControls.getInput(),
		})
		local speed, turnRate = CarPhysics.step(currentSpeed, input, dt)
		-- The server can ask for a gentle slowdown, for example when a pedestrian is right ahead.
		local cap = car:GetAttribute("SpeedCap")
		if typeof(cap) == "number" and speed > cap then
			speed = math.max(cap, currentSpeed - CarPhysics.DEFAULT_TUNING.brakeDeceleration * dt)
		end

		drive.PlaneVelocity = Vector2.new(forward.X * speed, forward.Z * speed)
		turn.AngularVelocity = Vector3.new(0, turnRate, 0)
	end)

	-- Driving is connected first, so the car still drives if something on screen fails to show.
	ChaseCamera.start(base)
	ResetButton.show(resetCar)
	Speedometer.show(base)
	TouchControls.show()
end

local function isCarSeat(seatPart: BasePart?): boolean
	return seatPart ~= nil
		and seatPart:IsA("VehicleSeat")
		and seatPart.Parent ~= nil
		and seatPart.Parent:HasTag(CAR_TAG)
end

local function onCharacterAdded(character: Model)
	stopDriving()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	humanoid.Seated:Connect(function(active, seatPart)
		if active and isCarSeat(seatPart) then
			startDriving(seatPart :: VehicleSeat)
		else
			stopDriving()
		end
	end)

	if isCarSeat(humanoid.SeatPart) then
		startDriving(humanoid.SeatPart :: VehicleSeat)
	end
end

function CarController.start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

return CarController
