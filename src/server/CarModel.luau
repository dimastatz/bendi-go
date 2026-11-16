-- Builds how a car looks (PRD-007): a painted body with bumpers, tinted windows, a roof, wheels with silver rims,
-- headlights, taillights, mirrors, and Israeli yellow license plates. Used for the Bendi car, the NPC cars, and the
-- parked cars.
-- These parts are only for looks: they never collide, aren't touched, and aren't hit by raycasts. Each car keeps its
-- own plain invisible box for collisions, so how cars drive and bump into things doesn't change.
-- Positions are from `origin`, a point on the ground under the middle of the car. The front of the car is -Z.

local NightLight = require(script.Parent.NightLight)

local CarModel = {}

export type Options = {
	paint: Color3,
	roof: number?, -- how high the roof is above the ground. The Bendi car is taller, to fit the player.
	plate: string?, -- text on the license plates
	mascot: boolean?, -- big Bendi eyes on the hood
	headlights: boolean?, -- real light beams at night, for cars that drive
	driver: Color3?, -- an NPC driver's skin color
}

-- Car size in studs: about 4 m long and 2 m wide at 0.28 m per stud.
CarModel.LENGTH = 14
CarModel.WIDTH = 7
CarModel.TAILLIGHT = Color3.fromRGB(120, 20, 20)

local LENGTH, WIDTH = CarModel.LENGTH, CarModel.WIDTH
local SILL = 0.9 -- the bottom of the body
local BELT = 2.9 -- the top of the body, where the windows start
local DEFAULT_ROOF = 5.9
local CABIN_LENGTH = 6.4
local CABIN_CENTER = 0.9 -- the cabin sits a little toward the back
local WINDSHIELD_LENGTH = 2.4
local REAR_WINDOW_LENGTH = 1.4
local WHEEL_SIZE = 3
local AXLE = 4.4

local TRIM = Color3.fromRGB(42, 44, 48)
local GLASS = Color3.fromRGB(30, 40, 50)
local TIRE = Color3.fromRGB(28, 28, 30)
local RIM = Color3.fromRGB(196, 198, 204)
local HEADLIGHT = Color3.fromRGB(222, 226, 230)
local HEADLIGHT_LIT = Color3.fromRGB(255, 248, 225)
local PLATE = Color3.fromRGB(250, 205, 30)

type Builder = { model: Model, origin: CFrame, root: BasePart? }

local function addPart(
	builder: Builder,
	className: string,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = Instance.new(className) :: BasePart
	part.Name = name
	part.Size = size
	part.CFrame = builder.origin * offset
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	local root = builder.root
	if root then
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	else
		part.Anchored = true
	end
	part.Parent = builder.model
	return part
end

local function block(builder: Builder, name: string, size: Vector3, offset: CFrame, color: Color3): BasePart
	return addPart(builder, "Part", name, size, offset, color)
end

local function ball(builder: Builder, name: string, diameter: number, offset: CFrame, color: Color3): BasePart
	local part = addPart(builder, "Part", name, Vector3.one * diameter, offset, color) :: Part
	part.Shape = Enum.PartType.Ball
	return part
end

-- A license plate on the `face` side of the car (Front or Back), with `text` written on it.
local function plate(builder: Builder, face: Enum.NormalId, text: string?)
	local z = if face == Enum.NormalId.Front then -(LENGTH / 2 + 0.05) else LENGTH / 2 + 0.05
	local part = block(builder, "Plate", Vector3.new(2.6, 0.75, 0.1), CFrame.new(0, 1.25, z), PLATE)
	if not text then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.MaxDistance = 60
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(20, 20, 20)
	label.Text = text
	label.Parent = gui
end

-- An Israeli plate number, like 123-45-678, picked from `seed` so the same car always gets the same number.
function CarModel.plateNumber(seed: number): string
	local digits = tostring(10000000 + (math.floor(seed) * 7919 + 12345) % 90000000)
	return `{digits:sub(1, 3)}-{digits:sub(4, 5)}-{digits:sub(6, 8)}`
end

-- Builds the car's look into `model`. If `root` is given, every part is welded to it and moves with it. Otherwise
-- the parts are anchored where they are. Returns the taillights, which NPC cars use as brake lights.
function CarModel.build(model: Model, origin: CFrame, root: BasePart?, options: Options): { BasePart }
	local builder: Builder = { model = model, origin = origin, root = root }
	local paint = options.paint
	local roof = options.roof or DEFAULT_ROOF
	local windowHeight = roof - BELT - 0.25

	-- The body, with dark bumpers and a grille.
	local body = block(
		builder,
		"Body",
		Vector3.new(WIDTH, BELT - SILL, LENGTH - 0.8),
		CFrame.new(0, (SILL + BELT) / 2, 0),
		paint
	)
	body.Reflectance = 0.12
	for _, side in { -1, 1 } do
		block(
			builder,
			"Bumper",
			Vector3.new(WIDTH + 0.1, 0.9, 0.7),
			CFrame.new(0, 1.25, side * (LENGTH / 2 - 0.35)),
			TRIM
		)
	end
	block(builder, "Grille", Vector3.new(2.8, 0.55, 0.1), CFrame.new(0, 2.05, -(LENGTH / 2 - 0.38)), TRIM)

	-- The windows: side windows, then the sloped windshield and rear window. A wedge's slope faces its front (-Z).
	local windowWidth = WIDTH - 0.7
	local cabinFront, cabinBack = CABIN_CENTER - CABIN_LENGTH / 2, CABIN_CENTER + CABIN_LENGTH / 2
	local windowY = BELT + windowHeight / 2
	local windows = {
		block(
			builder,
			"Windows",
			Vector3.new(windowWidth, windowHeight, CABIN_LENGTH),
			CFrame.new(0, windowY, CABIN_CENTER),
			GLASS
		),
		addPart(
			builder,
			"WedgePart",
			"Windshield",
			Vector3.new(windowWidth, windowHeight, WINDSHIELD_LENGTH),
			CFrame.new(0, windowY, cabinFront - WINDSHIELD_LENGTH / 2),
			GLASS
		),
		addPart(
			builder,
			"WedgePart",
			"RearWindow",
			Vector3.new(windowWidth, windowHeight, REAR_WINDOW_LENGTH),
			CFrame.new(0, windowY, cabinBack + REAR_WINDOW_LENGTH / 2) * CFrame.Angles(0, math.pi, 0),
			GLASS
		),
	}
	for _, window in windows do
		window.Material = Enum.Material.Glass
		window.Transparency = 0.3
		window.Reflectance = 0.2
	end

	-- The roof, and the pillar between the front and back side windows.
	local roofPart = block(
		builder,
		"Roof",
		Vector3.new(WIDTH - 0.6, 0.25, CABIN_LENGTH + 0.2),
		CFrame.new(0, roof - 0.125, CABIN_CENTER),
		paint
	)
	roofPart.Reflectance = 0.12
	block(
		builder,
		"Pillar",
		Vector3.new(WIDTH - 0.6, windowHeight, 0.35),
		CFrame.new(0, windowY, CABIN_CENTER - 0.4),
		paint
	)

	for _, side in { -1, 1 } do
		local x = side * 2.4
		block(
			builder,
			"Mirror",
			Vector3.new(0.5, 0.45, 0.8),
			CFrame.new(side * (WIDTH / 2 + 0.2), BELT + 0.35, cabinFront),
			paint
		)

		local headlight = block(
			builder,
			"Headlight",
			Vector3.new(1.5, 0.55, 0.15),
			CFrame.new(x, 2.4, -(LENGTH / 2 - 0.38)),
			HEADLIGHT
		)
		if options.headlights then
			local beam = Instance.new("SpotLight")
			beam.Face = Enum.NormalId.Front
			beam.Brightness = 3
			beam.Range = 45
			beam.Angle = 70
			beam.Shadows = false
			NightLight.tag(headlight, HEADLIGHT_LIT, beam)
		else
			NightLight.tag(headlight, HEADLIGHT_LIT)
		end

		-- Wheels: a black tire, with a silver rim that shows on the outside. Cylinders are round along their X axis,
		-- which already points sideways.
		for _, axle in { -1, 1 } do
			local wheel = CFrame.new(side * (WIDTH / 2 - 0.3), WHEEL_SIZE / 2, axle * AXLE)
			local tire = addPart(builder, "Part", "Tire", Vector3.new(1.2, WHEEL_SIZE, WHEEL_SIZE), wheel, TIRE) :: Part
			tire.Shape = Enum.PartType.Cylinder
			local rim =
				addPart(builder, "Part", "Rim", Vector3.new(1.26, 1.9, 1.9), wheel, RIM, Enum.Material.Metal) :: Part
			rim.Shape = Enum.PartType.Cylinder
		end
	end

	local taillights = {}
	for _, side in { -1, 1 } do
		table.insert(
			taillights,
			block(
				builder,
				"Taillight",
				Vector3.new(1.5, 0.55, 0.15),
				CFrame.new(side * 2.4, 2.4, LENGTH / 2 - 0.38),
				CarModel.TAILLIGHT
			)
		)
	end

	plate(builder, Enum.NormalId.Front, if options.mascot then options.plate else nil)
	plate(builder, Enum.NormalId.Back, options.plate)

	if options.mascot then
		-- Bendi's big eyes, on top of the hood, looking ahead.
		for _, side in { -1, 1 } do
			ball(builder, "Eye", 2, CFrame.new(side * 1.7, BELT + 0.3, -(LENGTH / 2 - 1)), Color3.new(1, 1, 1))
			ball(
				builder,
				"Pupil",
				0.9,
				CFrame.new(side * 1.7, BELT + 0.4, -(LENGTH / 2 - 0.2)),
				Color3.fromRGB(20, 20, 20)
			)
		end
	end

	if options.driver then
		-- Israeli cars are driven from the left seat. Facing -Z, left is -X.
		ball(builder, "Driver", 1.4, CFrame.new(-1.3, BELT + 1.3, 0.3), options.driver)
	end

	return taillights
end

return CarModel
