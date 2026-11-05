-- The NPC cars driving around town (PRD-005): builds a car for each one in Core.NpcTraffic and moves it every frame.
-- Only each car's anchored body is moved, and the rest of the car is welded to it. Brake lights come on when an NPC
-- car slows down or waits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NpcTraffic = require(ReplicatedStorage.Core.NpcTraffic)

local CarInfo = require(script.Parent.CarInfo)
local CarSpawner = require(script.Parent.CarSpawner)

local NpcCars = {}

local COLORS = {
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(200, 60, 50),
	Color3.fromRGB(50, 110, 190),
	Color3.fromRGB(180, 185, 190),
	Color3.fromRGB(60, 150, 90),
	Color3.fromRGB(245, 245, 245),
	Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(45, 45, 50),
}
local GLASS = Color3.fromRGB(70, 90, 110)
local BRAKE_ON = Color3.fromRGB(255, 40, 30)
local BRAKE_OFF = Color3.fromRGB(110, 25, 20)

local npcs: { NpcTraffic.Npc } = {}
local models: { { body: BasePart, brakes: { BasePart }, lit: boolean? } } = {}

local function makePart(model: Model, body: BasePart?, name: string, size: Vector3, offset: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	if body then
		part.CFrame = body.CFrame * offset
		part.Massless = true
		part.CanCollide = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
	else
		part.CFrame = offset
		part.Anchored = true
	end
	part.Parent = model
	return part
end

-- Builds one car. Like the Bendi car, its front is -Z, and the body's center is 2 studs above the road.
local function buildCar(parent: Instance, index: number)
	local model = Instance.new("Model")
	model.Name = `NpcCar{index}`
	local body =
		makePart(model, nil, "Body", Vector3.new(7, 2.5, 14), CFrame.new(0, 2, 0), COLORS[(index - 1) % #COLORS + 1])
	model.PrimaryPart = body

	local cabin = makePart(model, body, "Cabin", Vector3.new(6, 2.6, 7), CFrame.new(0, 2.55, 1), GLASS)
	cabin.Material = Enum.Material.Glass
	cabin.CanCollide = true
	makePart(model, body, "Driver", Vector3.one * 1.4, CFrame.new(-1.3, 2.6, 0.5), Color3.fromRGB(225, 175, 135)).Shape =
		Enum.PartType.Ball

	local brakes = {}
	for _, side in { -1, 1 } do
		local headlight = makePart(
			model,
			body,
			"Headlight",
			Vector3.new(1.4, 0.7, 0.2),
			CFrame.new(side * 2.4, 0.3, -7),
			Color3.fromRGB(255, 250, 220)
		)
		headlight.Material = Enum.Material.Neon
		table.insert(
			brakes,
			makePart(model, body, "BrakeLight", Vector3.new(1.4, 0.7, 0.2), CFrame.new(side * 2.4, 0.3, 7), BRAKE_OFF)
		)
		for _, axle in { -1, 1 } do
			makePart(
				model,
				body,
				"Wheel",
				Vector3.new(1.2, 3, 3),
				CFrame.new(side * 3.6, -0.5, axle * 4.5),
				Color3.fromRGB(35, 37, 42)
			).Shape =
				Enum.PartType.Cylinder
		end
	end

	model.Parent = parent
	models[index] = { body = body, brakes = brakes, lit = nil }
end

local function place(index: number)
	local npc = npcs[index]
	local car = models[index]
	local position = Vector3.new(npc.x, 0, npc.z)
	car.body.CFrame = CFrame.lookAt(position, position + Vector3.new(npc.dirX, 0, npc.dirZ)) * CFrame.new(0, 2, 0)

	local lit = npc.braking or npc.speed < 0.5
	if lit ~= car.lit then
		car.lit = lit
		for _, light in car.brakes do
			light.Color = if lit then BRAKE_ON else BRAKE_OFF
			light.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

-- Where every NPC car is, for the rules and the pedestrians.
function NpcCars.cars(): { NpcTraffic.Npc }
	return npcs
end

function NpcCars.build(town: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "NpcCars"
	folder.Parent = town
	npcs = NpcTraffic.create()
	for index in npcs do
		buildCar(folder, index)
		place(index)
	end
end

-- Drives every NPC car every frame. `getCrosswalks` says who is waiting at or crossing each crosswalk.
function NpcCars.start(getCrosswalks: () -> any)
	RunService.Heartbeat:Connect(function(dt)
		local players = {}
		for _, car in CarSpawner.allCars() do
			if car.PrimaryPart then
				table.insert(players, CarInfo.fromBase(car.PrimaryPart))
			end
		end
		NpcTraffic.step(npcs, players, getCrosswalks(), workspace:GetServerTimeNow(), math.min(dt, 0.1))
		for index in npcs do
			place(index)
		end
	end)
end

return NpcCars
