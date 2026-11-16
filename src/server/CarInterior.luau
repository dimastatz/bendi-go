-- The inside of the Bendi car (PRD-007): seats, a dashboard, a steering wheel, a gear lever, a rear-view mirror, and
-- the driving instructor in the passenger seat. Like in Israel, the driver sits on the left and the instructor on the
-- right.
-- Everything is welded to the car's base and is only for looks. The steering wheel hangs on a Motor6D
-- (SteeringJoint), so the driver's client can turn it. The client draws the gauges on the Cluster and Screen parts.
-- Positions are from `origin`, a point on the ground under the middle of the car. The front of the car is -Z.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cockpit = require(ReplicatedStorage.Core.Cockpit)

local CarInterior = {}

CarInterior.DRIVER_X = Cockpit.DRIVER_X
CarInterior.SEAT_TOP = Cockpit.SEAT_TOP
CarInterior.SEAT_Z = 1.5

local PASSENGER_X = 1.5
local FLOOR = 2.95 -- the top of the car's body, which is the floor inside
local HEADLINER = 7.32 -- the ceiling, just under the roof
local WHEEL_CENTER = Vector3.new(CarInterior.DRIVER_X, 3.85, -1.55)
local WHEEL_TILT = math.rad(-22) -- the top of the wheel leans away from the driver
local RIM_PIECES = 18

local DASH = Color3.fromRGB(38, 39, 43)
local TRIM = Color3.fromRGB(48, 48, 52)
local SEAT = Color3.fromRGB(45, 45, 50)
local CEILING = Color3.fromRGB(190, 188, 182)
local SCREEN = Color3.fromRGB(12, 12, 14)
local CHROME = Color3.fromRGB(190, 192, 196)
local BENDI_YELLOW = Color3.fromRGB(250, 200, 30)

local SKIN = Color3.fromRGB(225, 175, 135)
local HAIR = Color3.fromRGB(60, 40, 30)
local POLO = Color3.fromRGB(40, 110, 190)
local PANTS = Color3.fromRGB(45, 45, 55)

type Builder = { model: Model, origin: CFrame }

-- Adds a part at `offset` from the car's origin, welded to `attachTo`.
local function addPart(
	builder: Builder,
	attachTo: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = builder.origin * offset
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attachTo
	weld.Part1 = part
	weld.Parent = part
	part.Parent = builder.model
	return part
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- A seat's backrest and headrest. The cushion of the driver's seat is the car's VehicleSeat.
local function seatBack(builder: Builder, base: BasePart, x: number)
	local lean = CFrame.Angles(math.rad(10), 0, 0)
	addPart(builder, base, "Backrest", Vector3.new(2, 2.6, 0.5), at(x, CarInterior.SEAT_TOP + 1.2, 2.75) * lean, SEAT)
	addPart(builder, base, "Headrest", Vector3.new(1.2, 0.7, 0.4), at(x, CarInterior.SEAT_TOP + 2.9, 3.05) * lean, SEAT)
end

local function buildDashboard(builder: Builder, base: BasePart)
	addPart(builder, base, "Floor", Vector3.new(6.25, 0.06, 8.6), at(0, FLOOR - 0.02, -0.2), TRIM)
	addPart(builder, base, "Headliner", Vector3.new(6.2, 0.05, 6.4), at(0, HEADLINER, 0.9), CEILING)
	addPart(builder, base, "Dashboard", Vector3.new(6.2, 1.1, 1.6), at(0, 3.45, -3.2), DASH)

	-- The instrument cluster behind the steering wheel, under its little hood. The client draws the gauges on it.
	addPart(builder, base, "ClusterHood", Vector3.new(2.4, 0.4, 0.9), at(CarInterior.DRIVER_X, 4.45, -2.75), DASH)
	addPart(builder, base, "Cluster", Vector3.new(2.2, 0.85, 0.1), at(CarInterior.DRIVER_X, 3.85, -2.38), SCREEN)

	-- The screen in the middle of the dashboard, with air vents below it.
	addPart(builder, base, "Screen", Vector3.new(1.3, 0.75, 0.08), at(0.1, 3.65, -2.37), SCREEN)
	for _, side in { -1, 1 } do
		addPart(builder, base, "Vent", Vector3.new(0.7, 0.18, 0.05), at(0.1 + side * 0.45, 3.1, -2.4), SCREEN)
	end

	-- The console between the seats, with the gear lever.
	addPart(builder, base, "Console", Vector3.new(1, 0.7, 3.2), at(0, 3.25, 0.3), DASH)
	addPart(builder, base, "GearLever", Vector3.new(0.12, 0.6, 0.12), at(0, 3.9, -0.5), CHROME)
	addPart(builder, base, "GearKnob", Vector3.one * 0.32, at(0, 4.25, -0.5), SCREEN, Enum.PartType.Ball)

	-- The rear-view mirror at the top of the windshield.
	addPart(builder, base, "MirrorStem", Vector3.new(0.12, 0.35, 0.12), at(0, HEADLINER - 0.2, -2.35), DASH)
	addPart(builder, base, "RearViewMirror", Vector3.new(1.2, 0.35, 0.12), at(0, HEADLINER - 0.5, -2.35), DASH)
end

-- The steering wheel: a hub on a Motor6D, with a rim and three spokes welded to it.
local function buildSteeringWheel(builder: Builder, base: BasePart)
	local wheel = CFrame.new(WHEEL_CENTER) * CFrame.Angles(WHEEL_TILT, 0, 0)

	-- The column runs from the hub into the dashboard.
	local dashPoint = Vector3.new(CarInterior.DRIVER_X, 3.6, -2.6)
	addPart(
		builder,
		base,
		"SteeringColumn",
		Vector3.new(0.4, 0.4, 1.3),
		CFrame.lookAt(WHEEL_CENTER, dashPoint) * CFrame.new(0, 0, -0.65),
		DASH
	)

	local hub = addPart(builder, base, "SteeringHub", Vector3.new(0.7, 0.7, 0.25), wheel, SCREEN)
	-- The hub hangs on a joint instead of a weld, so the client can turn it.
	local weld = hub:FindFirstChildOfClass("WeldConstraint")
	if weld then
		weld:Destroy()
	end
	local joint = Instance.new("Motor6D")
	joint.Name = "SteeringJoint"
	joint.Part0 = base
	joint.Part1 = hub
	joint.C0 = base.CFrame:ToObjectSpace(hub.CFrame)
	joint.C1 = CFrame.identity
	joint.Parent = hub

	addPart(
		builder,
		hub,
		"Logo",
		Vector3.new(0.3, 0.3, 0.3),
		wheel * CFrame.new(0, 0, 0.1),
		BENDI_YELLOW,
		Enum.PartType.Ball
	)

	local radius = Cockpit.WHEEL_RADIUS
	local pieceLength = 2 * math.pi * radius / RIM_PIECES * 1.1
	for i = 1, RIM_PIECES do
		local angle = i * 2 * math.pi / RIM_PIECES
		addPart(
			builder,
			hub,
			"Rim",
			Vector3.new(pieceLength, 0.2, 0.2),
			wheel * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius, 0),
			SCREEN
		)
	end
	for _, side in { -1, 1 } do
		addPart(
			builder,
			hub,
			"Spoke",
			Vector3.new(radius, 0.15, 0.1),
			wheel * CFrame.new(side * radius / 2, 0, 0),
			DASH
		)
	end
	addPart(builder, hub, "Spoke", Vector3.new(0.15, radius, 0.1), wheel * CFrame.new(0, -radius / 2, 0), DASH)
end

-- The driving instructor, sitting in the passenger seat with their hands on their lap, and turned a little toward
-- the driver. Other players see them through the windows too.
local function buildInstructor(builder: Builder, base: BasePart)
	local x, seat = PASSENGER_X, CarInterior.SEAT_TOP
	addPart(builder, base, "InstructorSeat", Vector3.new(2, 1, 2), at(x, seat - 0.5, CarInterior.SEAT_Z), SEAT)

	local lean = CFrame.Angles(math.rad(8), 0, 0)
	addPart(builder, base, "InstructorLegs", Vector3.new(1.8, 0.9, 2), at(x, seat + 0.45, 0.8), PANTS)
	addPart(builder, base, "InstructorTorso", Vector3.new(1.9, 1.8, 1), at(x, seat + 1.75, 1.9) * lean, POLO)
	addPart(builder, base, "NameTag", Vector3.new(0.5, 0.3, 0.05), at(x - 0.45, seat + 2.15, 1.36) * lean, BENDI_YELLOW)

	local head = at(x, seat + 3.25, 1.95) * CFrame.Angles(0, math.rad(25), 0)
	addPart(builder, base, "InstructorHead", Vector3.one * 1.25, head, SKIN, Enum.PartType.Ball)
	addPart(
		builder,
		base,
		"InstructorHair",
		Vector3.one * 1.28,
		head * CFrame.new(0, 0.1, 0.12),
		HAIR,
		Enum.PartType.Ball
	)
	for _, side in { -1, 1 } do
		addPart(
			builder,
			base,
			"InstructorEye",
			Vector3.one * 0.18,
			head * CFrame.new(side * 0.22, 0.08, -0.58),
			SCREEN,
			Enum.PartType.Ball
		)

		local armX = x + side * 1.25
		addPart(builder, base, "InstructorArm", Vector3.new(0.65, 1.6, 0.7), at(armX, seat + 1.8, 1.9) * lean, POLO)
		addPart(builder, base, "InstructorForearm", Vector3.new(0.6, 0.6, 1.3), at(armX, seat + 1.05, 1.3), SKIN)
		addPart(
			builder,
			base,
			"InstructorHand",
			Vector3.one * 0.6,
			at(armX, seat + 1.05, 0.6),
			SKIN,
			Enum.PartType.Ball
		)
	end
end

-- Builds the inside of the car at `origin`, welded to `base`.
function CarInterior.build(car: Model, origin: CFrame, base: BasePart)
	local builder: Builder = { model = car, origin = origin }
	seatBack(builder, base, CarInterior.DRIVER_X)
	seatBack(builder, base, PASSENGER_X)
	buildDashboard(builder, base)
	buildSteeringWheel(builder, base)
	buildInstructor(builder, base)
end

return CarInterior
