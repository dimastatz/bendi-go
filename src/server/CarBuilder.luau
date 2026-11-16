-- Builds a Bendi car: the mascot from PRD-001 (blue, big eyes, yellow "BENDI GO" plate), drawn by CarModel.
-- The car is driven arcade-style: the invisible Base slides on the ground with no friction, and the
-- driver's client moves it through the Drive (LinearVelocity) and Turn (AngularVelocity) constraints.
-- An invisible Hitbox bumps into curbs and parked cars. Everything else is only for looks.

local CarModel = require(script.Parent.CarModel)

local CarBuilder = {}

CarBuilder.TAG = "BendiCar"

local BODY_COLOR = Color3.fromRGB(58, 150, 232)
local ROOF_HEIGHT = 7.6 -- taller than other cars, so the player fits inside

local LENGTH = CarModel.LENGTH
local WIDTH = CarModel.WIDTH

-- Builds a car with its base resting on the ground at `origin`. The car faces origin's LookVector.
function CarBuilder.build(origin: CFrame): Model
	local car = Instance.new("Model")
	car.Name = "BendiCar"

	-- The base is the only part that touches the ground. Its bottom is at origin's height.
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(WIDTH, 1, LENGTH - 1)
	base.CFrame = origin * CFrame.new(0, 0.5, 0)
	base.Transparency = 1
	base.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	base.Parent = car
	car.PrimaryPart = base

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(WIDTH, 2.5, LENGTH)
	hitbox.CFrame = base.CFrame * CFrame.new(0, 1.75, 0)
	hitbox.Transparency = 1
	hitbox.Massless = true
	local hitboxWeld = Instance.new("WeldConstraint")
	hitboxWeld.Part0 = base
	hitboxWeld.Part1 = hitbox
	hitboxWeld.Parent = hitbox
	hitbox.Parent = car

	CarModel.build(car, origin, base, {
		paint = BODY_COLOR,
		roof = ROOF_HEIGHT,
		plate = "BENDI GO",
		mascot = true,
		headlights = true,
	})

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = base.CFrame * CFrame.new(0, 3.5, 1.5)
	seat.Color = Color3.fromRGB(40, 40, 45)
	-- The seat only reads the driver's input. CarController does the driving.
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = base
	seatWeld.Part1 = seat
	seatWeld.Parent = seat
	seat.Parent = car

	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = base

	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = center
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.PrimaryTangentAxis = Vector3.xAxis
	drive.SecondaryTangentAxis = Vector3.zAxis
	drive.PlaneVelocity = Vector2.zero
	drive.MaxForce = 60000
	drive.Parent = base

	local turn = Instance.new("AngularVelocity")
	turn.Name = "Turn"
	turn.Attachment0 = center
	turn.RelativeTo = Enum.ActuatorRelativeTo.World
	turn.AngularVelocity = Vector3.zero
	turn.MaxTorque = 500000
	turn.Parent = base

	car:AddTag(CarBuilder.TAG)
	return car
end

return CarBuilder
