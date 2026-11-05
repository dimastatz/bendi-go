-- Builds Israeli road signs from parts: a pole, and a round, triangular, or octagonal sign face with text or a
-- symbol drawn on it. A sign is placed with a CFrame whose LookVector points at the drivers who should read it.

local SignBuilder = {}

SignBuilder.RED = Color3.fromRGB(205, 30, 35)
SignBuilder.BLUE = Color3.fromRGB(20, 85, 170)
SignBuilder.WHITE = Color3.fromRGB(250, 250, 250)
SignBuilder.BLACK = Color3.fromRGB(20, 20, 20)

local POLE_COLOR = Color3.fromRGB(150, 154, 158)
local BACK_COLOR = Color3.fromRGB(120, 124, 128)

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A gray pole standing at `foot`, `height` studs tall.
function SignBuilder.pole(parent: Instance, foot: Vector3, height: number)
	-- Cylinders are round along their X axis, so the pole is turned to stand up.
	local pole = makePart(
		parent,
		"Pole",
		Vector3.new(height, 0.5, 0.5),
		CFrame.new(foot + Vector3.yAxis * height / 2) * CFrame.Angles(0, 0, math.rad(90)),
		POLE_COLOR
	)
	pole.Shape = Enum.PartType.Cylinder
end

-- Draws `text` on a see-through panel just in front of the sign face at `face`, `width` by `height` studs.
function SignBuilder.label(
	parent: Instance,
	face: CFrame,
	width: number,
	height: number,
	text: string,
	color: Color3
): TextLabel
	local panel = makePart(parent, "Label", Vector3.new(width, height, 0.05), face * CFrame.new(0, 0, -0.2), color)
	panel.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	return label
end

-- A round sign `diameter` studs across: a colored ring around a colored center.
function SignBuilder.disc(
	parent: Instance,
	face: CFrame,
	diameter: number,
	ring: Color3,
	fill: Color3,
	ringWidth: number
)
	-- Cylinders are round along their X axis, so the discs are turned to face the drivers.
	local turn = CFrame.Angles(0, math.rad(90), 0)
	local back =
		makePart(parent, "Back", Vector3.new(0.1, diameter, diameter), face * CFrame.new(0, 0, 0.1) * turn, BACK_COLOR)
	back.Shape = Enum.PartType.Cylinder
	local outer = makePart(parent, "Ring", Vector3.new(0.1, diameter, diameter), face * turn, ring)
	outer.Shape = Enum.PartType.Cylinder
	local innerSize = diameter - 2 * ringWidth
	local inner =
		makePart(parent, "Center", Vector3.new(0.1, innerSize, innerSize), face * CFrame.new(0, 0, -0.06) * turn, fill)
	inner.Shape = Enum.PartType.Cylinder
end

-- A solid triangle, `width` across its base and `height` tall, pointing up (or down if `pointsDown`).
local function triangle(
	parent: Instance,
	face: CFrame,
	width: number,
	height: number,
	color: Color3,
	pointsDown: boolean
)
	local frame = if pointsDown then face * CFrame.Angles(0, 0, math.rad(180)) else face
	-- Each half is a wedge with its square corner at the bottom middle and its point at the top middle.
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Triangle"
		wedge.Size = Vector3.new(0.1, height, width / 2)
		wedge.CFrame = frame * CFrame.new(side * width / 4, 0, 0) * CFrame.Angles(0, math.rad(-90 * side), 0)
		wedge.Color = color
		wedge.Material = Enum.Material.SmoothPlastic
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanTouch = false
		wedge.Parent = parent
	end
end

-- A triangular warning sign: red border and white inside, pointing up, or down for give way.
function SignBuilder.triangle(parent: Instance, face: CFrame, size: number, pointsDown: boolean)
	local height = size * math.sqrt(3) / 2
	triangle(parent, face * CFrame.new(0, 0, 0.1), size * 1.04, height * 1.04, BACK_COLOR, pointsDown)
	triangle(parent, face, size, height, SignBuilder.RED, pointsDown)
	-- The white inside shares the outside's center point (a third of the way up), so the border is even.
	local scale = 0.7
	local shift = (1 - scale) * height / 6 * (if pointsDown then 1 else -1)
	triangle(parent, face * CFrame.new(0, shift, -0.06), size * scale, height * scale, SignBuilder.WHITE, pointsDown)
end

-- A red octagon, `size` studs across, made of four bars turned 45 degrees from each other.
function SignBuilder.octagon(parent: Instance, face: CFrame, size: number)
	local side = size * math.tan(math.rad(22.5))
	for index = 0, 3 do
		makePart(
			parent,
			"Octagon",
			Vector3.new(size, side, 0.1),
			face * CFrame.Angles(0, 0, math.rad(45 * index)),
			SignBuilder.RED
		)
	end
end

return SignBuilder
