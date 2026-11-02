-- Drives the local player's Bendi car while they sit in its driver seat.
-- The driver's client owns the car's physics, so it reads input every frame, runs CarPhysics, and sets
-- the Drive and Turn constraints directly. Space brakes instead of jumping out of the car.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarPhysics = require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("CarPhysics"))

local CarController = {}

local CAR_TAG = "BendiCar"
local BRAKE_ACTION = "BendiBrake"
local HORIZONTAL = Vector3.new(1, 0, 1)

local braking = false
local driveConnection: RBXScriptConnection? = nil

local function onBrake(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	braking = inputState == Enum.UserInputState.Begin
	-- Sinking the input stops Space from also making the character jump out of the seat.
	return Enum.ContextActionResult.Sink
end

local function stopDriving()
	if driveConnection then
		driveConnection:Disconnect()
		driveConnection = nil
	end
	ContextActionService:UnbindAction(BRAKE_ACTION)
	braking = false
end

local function startDriving(seat: VehicleSeat)
	stopDriving()

	local car = seat.Parent :: Model
	local base = car.PrimaryPart :: BasePart
	local drive = base:WaitForChild("Drive") :: LinearVelocity
	local turn = base:WaitForChild("Turn") :: AngularVelocity

	ContextActionService:BindActionAtPriority(
		BRAKE_ACTION,
		onBrake,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space
	)

	driveConnection = RunService.PreSimulation:Connect(function(dt)
		local flatForward = base.CFrame.LookVector * HORIZONTAL
		if flatForward.Magnitude < 1e-3 then
			return
		end
		local forward = flatForward.Unit

		-- Start from the car's real speed, so hitting a wall doesn't build up speed it doesn't have.
		local currentSpeed = base.AssemblyLinearVelocity:Dot(forward)
		local input = { throttle = seat.ThrottleFloat, steer = seat.SteerFloat, brake = braking }
		local speed, turnRate = CarPhysics.step(currentSpeed, input, dt)

		drive.PlaneVelocity = Vector2.new(forward.X * speed, forward.Z * speed)
		turn.AngularVelocity = Vector3.new(0, turnRate, 0)
	end)
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
