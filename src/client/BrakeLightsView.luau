-- Lights up the taillights of every Bendi car when it brakes or waits (PRD-008).
-- Each client works out every car's brake lights itself with Core.BrakeLights, from how fast the car is going, so
-- every player sees the same thing without any extra network messages. Changes here are only seen on this client.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = ReplicatedStorage:WaitForChild("Core")
local BrakeLights = require(Core:WaitForChild("BrakeLights"))

local BrakeLightsView = {}

local CAR_TAG = "BendiCar"
local TAILLIGHT = "Taillight"
local LIT_COLOR = Color3.fromRGB(255, 40, 30) -- the same red as the NPC cars' brake lights
local HORIZONTAL = Vector3.new(1, 0, 1)

type Taillight = { part: BasePart, color: Color3, material: Enum.Material }
type Car = {
	model: Model,
	state: BrakeLights.State,
	taillights: { Taillight },
	lit: boolean,
	connections: { RBXScriptConnection },
}

local cars: { [Model]: Car } = {}

local function paint(taillight: Taillight, lit: boolean)
	taillight.part.Color = if lit then LIT_COLOR else taillight.color
	taillight.part.Material = if lit then Enum.Material.Neon else taillight.material
end

-- Remembers how a taillight looks when it's off, then shows it the way the car's lights are now.
local function addTaillight(car: Car, child: Instance)
	if child.Name ~= TAILLIGHT or not child:IsA("BasePart") then
		return
	end
	local taillight = { part = child, color = child.Color, material = child.Material }
	table.insert(car.taillights, taillight)
	paint(taillight, car.lit)
end

local function removeTaillight(car: Car, child: Instance)
	for index, taillight in car.taillights do
		if taillight.part == child then
			table.remove(car.taillights, index)
			return
		end
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Model") or cars[instance] then
		return
	end
	local car: Car =
		{ model = instance, state = BrakeLights.newState(), taillights = {}, lit = false, connections = {} }
	cars[instance] = car
	for _, child in instance:GetChildren() do
		addTaillight(car, child)
	end
	-- With streaming, a car's parts can arrive after the car itself, and leave before it.
	car.connections = {
		instance.ChildAdded:Connect(function(child)
			addTaillight(car, child)
		end),
		instance.ChildRemoved:Connect(function(child)
			removeTaillight(car, child)
		end),
	}
end

local function forget(instance: Instance)
	local car = cars[instance :: Model]
	if car then
		for _, connection in car.connections do
			connection:Disconnect()
		end
		cars[instance :: Model] = nil
	end
end

-- How fast `base` is going forward, in studs per second. Negative is backward.
local function forwardSpeed(base: BasePart): number
	local forward = base.CFrame.LookVector * HORIZONTAL
	if forward.Magnitude < 1e-3 then
		return 0
	end
	return base.AssemblyLinearVelocity:Dot(forward.Unit)
end

local function update(car: Car, dt: number)
	local base = car.model.PrimaryPart
	if not base then
		return
	end
	local seat = car.model:FindFirstChild("DriverSeat")
	local occupied = seat ~= nil and seat:IsA("VehicleSeat") and seat.Occupant ~= nil
	local lit = BrakeLights.update(car.state, forwardSpeed(base), dt, occupied)
	if lit ~= car.lit then
		car.lit = lit
		for _, taillight in car.taillights do
			paint(taillight, lit)
		end
	end
end

function BrakeLightsView.start()
	for _, instance in CollectionService:GetTagged(CAR_TAG) do
		watch(instance)
	end
	CollectionService:GetInstanceAddedSignal(CAR_TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(CAR_TAG):Connect(forget)
	RunService.Heartbeat:Connect(function(dt)
		for _, car in cars do
			update(car, dt)
		end
	end)
end

return BrakeLightsView
