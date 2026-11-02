-- Gives every player their own Bendi car and keeps them in the driver's seat.
-- Each player's car is rebuilt when their character respawns and removed when they leave.

local Players = game:GetService("Players")

local CarBuilder = require(script.Parent.CarBuilder)

local CarSpawner = {}

-- Cars spawn side by side in a row, one slot per player, so they never start on top of each other.
local SLOT_SPACING = 16
local FIRST_SLOT = CFrame.new(0, 0, 50)
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
	-- Alternate slots left and right of the first one: 0, +1, -1, +2, -2, ...
	local index = if slot % 2 == 0 then slot / 2 else -(slot - 1) / 2
	return FIRST_SLOT * CFrame.new(index * SLOT_SPACING, 0, 0)
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

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local car = CarBuilder.build(slotOrigin(takeSlot(player)))
	car.Name = `BendiCar_{player.Name}`
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
