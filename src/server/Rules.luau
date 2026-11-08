-- Runs every rule (traffic lights, speed limits, ...) on every player's car and gives stars and tips.
-- Tips and praise go to the player's screen through the BendiTip remote event. Every star given and every tip is
-- also passed to `onEvent`, which saves the stars and counts them for lessons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CrosswalkRule = require(ReplicatedStorage.Core.CrosswalkRule)
local RedLightRule = require(ReplicatedStorage.Core.RedLightRule)
local RuleKit = require(ReplicatedStorage.Core.RuleKit)
local SpeedRule = require(ReplicatedStorage.Core.SpeedRule)
local Stars = require(ReplicatedStorage.Core.Stars)
local StopSignRule = require(ReplicatedStorage.Core.StopSignRule)
local YieldRule = require(ReplicatedStorage.Core.YieldRule)

local CarInfo = require(script.Parent.CarInfo)
local CarSpawner = require(script.Parent.CarSpawner)

local Rules = {}

-- Every rule has newState() and update(state, car, now, world), which returns stars and tips.
local RULES = { RedLightRule, SpeedRule, CrosswalkRule, YieldRule, StopSignRule }

local tipEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BendiTip") :: RemoteEvent

local players: { [Player]: { states: { any }, stars: Stars.Stars } } = {}
local listener: ((Player, RuleKit.Event) -> ())? = nil

local function onPlayerAdded(player: Player)
	local states = {}
	for index, rule in RULES do
		states[index] = rule.newState()
	end
	players[player] = { states = states, stars = Stars.new() }
end

local function check(player: Player, states: { any }, stars: Stars.Stars, now: number, world: any)
	local car = CarSpawner.getCar(player)
	local base = car and car.PrimaryPart
	if not base then
		return
	end

	local carInfo = CarInfo.fromBase(base)

	for index, rule in RULES do
		for _, event in rule.update(states[index], carInfo, now, world) do
			if event.kind == "star" then
				if Stars.tryAward(stars, event.key, now, Stars.COOLDOWN) then
					if event.praise then
						tipEvent:FireClient(player, event.praise)
					end
					if listener then
						listener(player, event)
					end
				end
			else
				tipEvent:FireClient(player, event.tip)
				if listener then
					listener(player, event)
				end
			end
		end
	end
end

-- `getWorld` returns what rules need to know besides the car, like pedestrians and other cars. It is called once
-- per frame. `onEvent` is told about every star given and every tip.
function Rules.start(getWorld: (() -> any)?, onEvent: ((Player, RuleKit.Event) -> ())?)
	listener = onEvent
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		players[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		local world = if getWorld then getWorld() else nil
		for player, data in players do
			check(player, data.states, data.stars, now, world)
		end
	end)
end

return Rules
