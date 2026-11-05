-- Gives every player their own Bendi car and keeps them in the driver's seat.
-- Each player's car is rebuilt when their character respawns and removed when they leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TownLayout = require(ReplicatedStorage.Core.TownLayout)

local CarBuilder = require(script.Parent.CarBuilder)
local CollisionGroups = require(script.Parent.CollisionGroups)

local CarSpawner = {}

-- Each player gets a spawn slot, and each slot is its own spot on a street, so cars never start on top of each other.
local RESEAT_DELAY = 0.5

local cars: { [Player]: Model } = {}
local slots: { [Player]: number } = {}

local function takeSlot(player: Player): number
	if slots[player] then
		return slots[player]
	end
	local used = {}
	for _, slot in slots do
		used[slot] = true
	end
	local slot = 1
	while used[slot] do
		slot += 1
	end
	slots[player] = slot
	return slot
end

local function slotOrigin(slot: number): CFrame
	local pose = TownLayout.spawnPose(slot)
	local position = Vector3.new(pose.x, 0, pose.z)
	return CFrame.lookAt(position, position + Vector3.new(pose.dirX, 0, pose.dirZ))
end

local function removeCar(player: Player)
	local car = cars[player]
	if car then
		car:Destroy()
		cars[player] = nil
	end
end

local function seatDriver(player: Player, seat: VehicleSeat, humanoid: Humanoid)
	if humanoid.Health <= 0 or not humanoid:IsDescendantOf(workspace) or not seat:IsDescendantOf(workspace) then
		return
	end
	seat:Sit(humanoid)
	seat:SetNetworkOwner(player)
end

local function onCharacterAdded(player: Player, character: Model)
	removeCar(player)
	CollisionGroups.addPlayerParts(character)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local car = CarBuilder.build(slotOrigin(takeSlot(player)))
	car.Name = `BendiCar_{player.Name}`
	CollisionGroups.addPlayerParts(car)
	car.Parent = workspace
	cars[player] = car

	local seat = car:FindFirstChild("DriverSeat") :: VehicleSeat

	-- Keep the player in the car: if they get out (for example by jumping), put them back.
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == nil then
			task.delay(RESEAT_DELAY, seatDriver, player, seat, humanoid)
		end
	end)

	task.defer(seatDriver, player, seat, humanoid)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

-- Every player's car, by player.
function CarSpawner.allCars(): { [Player]: Model }
	return cars
end

-- The player's current car, if they have one.
function CarSpawner.getCar(player: Player): Model?
	return cars[player]
end

function CarSpawner.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		removeCar(player)
		slots[player] = nil
	end)
end

return CarSpawner
