-- The NPC cars driving around town (PRD-005): builds a car for each one in Core.NpcTraffic and moves it every frame.
-- Only each car's anchored body is moved, and the rest of the car is welded to it. The taillights light up as brake
-- lights when an NPC car slows down or waits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NpcTraffic = require(ReplicatedStorage.Core.NpcTraffic)

local CarInfo = require(script.Parent.CarInfo)
local CarModel = require(script.Parent.CarModel)
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
local SKIN_COLORS = {
	Color3.fromRGB(225, 175, 135),
	Color3.fromRGB(160, 110, 75),
	Color3.fromRGB(240, 200, 170),
	Color3.fromRGB(110, 75, 50),
}
local GLASS = Color3.fromRGB(70, 90, 110)
local BRAKE_ON = Color3.fromRGB(255, 40, 30)
local BRAKE_OFF = CarModel.TAILLIGHT

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

-- Builds one car. Like the Bendi car, its front is -Z, and the body's center is 2 studs above the road. The body and
-- cabin are invisible boxes for collisions, and CarModel draws the car on them.
local function buildCar(parent: Instance, index: number)
	local model = Instance.new("Model")
	model.Name = `NpcCar{index}`
	local body = makePart(model, nil, "Body", Vector3.new(7, 2.5, 14), CFrame.new(0, 2, 0), GLASS)
	body.Transparency = 1
	model.PrimaryPart = body

	local cabin = makePart(model, body, "Cabin", Vector3.new(6, 2.6, 7), CFrame.new(0, 2.55, 1), GLASS)
	cabin.Transparency = 1
	cabin.CanCollide = true

	local brakes = CarModel.build(model, body.CFrame * CFrame.new(0, -2, 0), body, {
		paint = COLORS[(index - 1) % #COLORS + 1],
		plate = CarModel.plateNumber(index),
		headlights = true,
		driver = SKIN_COLORS[(index - 1) % #SKIN_COLORS + 1],
	})

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
