-- The people walking around town (PRD-004): builds a simple figure for each walker from Core.Walkers, moves them
-- every frame, and gently slows any car that comes close to a crosswalk while someone is on it.
-- Walkers never collide with anything, so a car can never push or knock one over (requirement 6). The client
-- swings their arms and legs (PedestrianAnimator), so the server only moves each figure's torso.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Crosswalks = require(ReplicatedStorage.Core.Crosswalks)
local Units = require(ReplicatedStorage.Core.Units)
local Walkers = require(ReplicatedStorage.Core.Walkers)

local CarInfo = require(script.Parent.CarInfo)
local CarSpawner = require(script.Parent.CarSpawner)

local Pedestrians = {}

local SIDEWALK_TOP = 0.5
local SLOW_DISTANCE = 30 -- cars this close to a crosswalk with someone on it are slowed down
local SLOW_SPEED = Units.kmhToStudsPerSecond(8)

local SCALES = { kid = 0.7, adult = 1, senior = 0.95 }
local SKIN = {
	Color3.fromRGB(255, 220, 185),
	Color3.fromRGB(225, 175, 135),
	Color3.fromRGB(175, 120, 80),
	Color3.fromRGB(120, 80, 55),
}
local SHIRTS = {
	Color3.fromRGB(230, 70, 60),
	Color3.fromRGB(60, 140, 220),
	Color3.fromRGB(250, 200, 50),
	Color3.fromRGB(90, 180, 100),
	Color3.fromRGB(170, 90, 200),
	Color3.fromRGB(245, 245, 245),
}
local PANTS = { Color3.fromRGB(40, 55, 95), Color3.fromRGB(60, 60, 65), Color3.fromRGB(150, 120, 90) }
local HAIR = { Color3.fromRGB(40, 30, 25), Color3.fromRGB(110, 70, 40), Color3.fromRGB(200, 160, 90) }
local GRAY_HAIR = Color3.fromRGB(205, 205, 205)

local walkers: { Walkers.Walker } = {}
local figures: { Model } = {}
local folder: Folder

local function makePart(parent: Instance, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Joins `part` to the torso with a Motor6D, so the client can swing it. `c0` is the joint on the torso and `c1`
-- the same joint on the part.
local function joint(torso: BasePart, part: BasePart, name: string, c0: CFrame, c1: CFrame)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = torso
	motor.Part1 = part
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = torso
end

local function weld(a: BasePart, b: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = a
	constraint.Part1 = b
	constraint.Parent = b
end

local function buildFigure(walker: Walkers.Walker, index: number): Model
	local s = SCALES[walker.kind]
	local pick = function(list: { Color3 }, salt: number): Color3
		return list[(index * 7 + salt) % #list + 1]
	end

	local model = Instance.new("Model")
	model.Name = `Pedestrian_{walker.kind}`

	local torso = makePart(model, "Torso", Vector3.new(1.6, 2.2, 0.9) * s, pick(SHIRTS, 0))
	torso.Anchored = true
	model.PrimaryPart = torso

	local head = makePart(model, "Head", Vector3.one * 1.3 * s, pick(SKIN, 1), Enum.PartType.Ball)
	joint(torso, head, "Neck", CFrame.new(0, 1.1 * s, 0), CFrame.new(0, -0.7 * s, 0))
	local hair = makePart(
		model,
		"Hair",
		Vector3.one * 1.36 * s,
		if walker.kind == "senior" then GRAY_HAIR else pick(HAIR, 2),
		Enum.PartType.Ball
	)
	hair.CFrame = head.CFrame * CFrame.new(0, 0.12 * s, 0.12 * s)
	weld(head, hair)

	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		local leg = makePart(model, `{name}Leg`, Vector3.new(0.7, 2.6, 0.8) * s, pick(PANTS, 3))
		joint(torso, leg, `{name}Hip`, CFrame.new(side * 0.42 * s, -1.1 * s, 0), CFrame.new(0, 1.2 * s, 0))
		local arm = makePart(model, `{name}Arm`, Vector3.new(0.5, 2.1, 0.6) * s, pick(SHIRTS, 0))
		joint(torso, arm, `{name}Shoulder`, CFrame.new(side * 1.05 * s, 0.9 * s, 0), CFrame.new(0, 0.85 * s, 0))
		if walker.kind == "senior" and side > 0 then
			-- A walking cane in the right hand.
			local cane = makePart(model, "Cane", Vector3.new(0.18, 2.4, 0.18), Color3.fromRGB(110, 75, 45))
			cane.CFrame = arm.CFrame * CFrame.new(0, -1.6, -0.3)
			weld(arm, cane)
		end
	end

	if walker.kind == "kid" then
		-- A school backpack.
		local bag = makePart(model, "Backpack", Vector3.new(1.3, 1.5, 0.6) * s, pick(SHIRTS, 4))
		bag.CFrame = torso.CFrame * CFrame.new(0, 0.1, 0.75 * s)
		weld(torso, bag)
	end

	model:SetAttribute("Scale", s)
	model:SetAttribute("Look", 0)
	model.Parent = folder
	return model
end

-- Puts the figure where its walker is, standing on the sidewalk or the road.
local function place(figure: Model, walker: Walkers.Walker)
	local s = SCALES[walker.kind]
	local ground = if walker.onRoad then 0 else SIDEWALK_TOP
	local position = Vector3.new(walker.x, ground + 2.6 * s + 1.1 * s, walker.z)
	local facing = Vector3.new(walker.dirX, 0, walker.dirZ)
	if facing.Magnitude < 1e-3 then
		facing = -Vector3.zAxis
	end
	local cframe = CFrame.lookAt(position, position + facing)
	if walker.kind == "senior" then
		cframe *= CFrame.Angles(math.rad(-8), 0, 0) -- a slight stoop
	end
	figure.PrimaryPart.CFrame = cframe
	if figure:GetAttribute("Look") ~= walker.look then
		figure:SetAttribute("Look", walker.look)
	end
end

-- What each crosswalk is doing, for the rules.
function Pedestrians.status(): { Walkers.Status }
	return Walkers.status(walkers)
end

function Pedestrians.build(town: Instance)
	folder = Instance.new("Folder")
	folder.Name = "Pedestrians"
	folder.Parent = town
	walkers = Walkers.create(math.random)
	for index, walker in walkers do
		figures[index] = buildFigure(walker, index)
		place(figures[index], walker)
	end
end

-- Moves everyone every frame. `getOtherCars` returns the cars that aren't players' (the NPC cars), if any.
function Pedestrians.start(getOtherCars: (() -> { any })?)
	RunService.Heartbeat:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		local cars = if getOtherCars then table.clone(getOtherCars()) else {}
		local playerCars = {}
		for _, car in CarSpawner.allCars() do
			local base = car.PrimaryPart
			if base then
				local info = CarInfo.fromBase(base)
				table.insert(cars, info)
				playerCars[car] = info
			end
		end

		Walkers.step(walkers, cars, now, dt, math.random)
		for index, walker in walkers do
			place(figures[index], walker)
		end

		-- Gently slow players' cars that are about to reach someone on a crosswalk.
		local statuses = Walkers.status(walkers)
		for car, info in playerCars do
			local slow = false
			for index, status in statuses do
				if status.crossing and Crosswalks.isNear(index, info, SLOW_DISTANCE) then
					slow = true
				end
			end
			local cap = if slow then SLOW_SPEED else nil
			if car:GetAttribute("SpeedCap") ~= cap then
				car:SetAttribute("SpeedCap", cap)
			end
		end
	end)
end

return Pedestrians
