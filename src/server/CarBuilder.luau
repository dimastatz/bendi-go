-- Builds a Bendi car from basic parts.
-- The car is driven arcade-style: the invisible Base slides on the ground with no friction, and the
-- driver's client moves it through the Drive (LinearVelocity) and Turn (AngularVelocity) constraints.
-- Wheels are only for looks. A proper mascot model replaces these parts later.

local CarBuilder = {}

CarBuilder.TAG = "BendiCar"

local BODY_COLOR = Color3.fromRGB(58, 150, 232)
local WHEEL_COLOR = Color3.fromRGB(35, 37, 42)
local PLATE_COLOR = Color3.fromRGB(250, 200, 30)

-- Car size in studs: about 4 m long and 2 m wide at 0.28 m per stud.
local LENGTH = 14
local WIDTH = 7

-- Adds a part positioned relative to the base and welded to it.
local function addPart(car: Model, base: BasePart, name: string, shape: Enum.PartType, size: Vector3, offset: CFrame)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = base.CFrame * offset
	part.Color = BODY_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Massless = true

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part

	part.Parent = car
	return part
end

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

	-- Offsets are from the base's center. The front of the car is -Z.
	addPart(car, base, "Body", Enum.PartType.Block, Vector3.new(WIDTH, 2.5, LENGTH), CFrame.new(0, 1.75, 0))

	local cabin = addPart(car, base, "Cabin", Enum.PartType.Block, Vector3.new(WIDTH - 1, 4, 7), CFrame.new(0, 5, 1.5))
	cabin.Material = Enum.Material.Glass
	cabin.Transparency = 0.6
	cabin.CanCollide = false

	local plate = addPart(car, base, "Plate", Enum.PartType.Block, Vector3.new(2.4, 0.8, 0.2), CFrame.new(0, 1.6, -7.1))
	plate.Color = PLATE_COLOR

	for _, side in { -1, 1 } do
		local eye = addPart(car, base, "Eye", Enum.PartType.Ball, Vector3.one * 1.8, CFrame.new(side * 1.8, 2.4, -6.6))
		eye.Color = Color3.new(1, 1, 1)

		local pupil =
			addPart(car, base, "Pupil", Enum.PartType.Ball, Vector3.one * 0.8, CFrame.new(side * 1.8, 2.4, -7.3))
		pupil.Color = Color3.fromRGB(20, 20, 20)

		for _, axle in { -1, 1 } do
			-- Cylinders are round along their X axis, which already points sideways.
			local wheel = addPart(
				car,
				base,
				"Wheel",
				Enum.PartType.Cylinder,
				Vector3.new(1.2, 3, 3),
				CFrame.new(side * (WIDTH / 2 + 0.1), 1, axle * 4.5)
			)
			wheel.Color = WHEEL_COLOR
			wheel.CanCollide = false
		end
	end

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
