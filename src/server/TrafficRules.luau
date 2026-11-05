-- Watches every player's car at the traffic lights and gives stars and tips (PRD-002, requirements 4, 5, 7, 8).
-- Stars are kept on the server for this session. Players see them through their "Stars" attribute, and tips go to
-- the player's screen through the BendiTip remote event.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Core.TrafficLightConfig)
local RedLightRule = require(ReplicatedStorage.Core.RedLightRule)
local Stars = require(ReplicatedStorage.Core.Stars)

local CarSpawner = require(script.Parent.CarSpawner)

local TrafficRules = {}

local tipEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BendiTip") :: RemoteEvent

local players: { [Player]: { rule: RedLightRule.State, stars: Stars.Stars } } = {}

local function onPlayerAdded(player: Player)
	players[player] = { rule = RedLightRule.newState(), stars = Stars.new() }
	player:SetAttribute("Stars", 0)
end

local function check(player: Player, rule: RedLightRule.State, stars: Stars.Stars, now: number)
	local car = CarSpawner.getCar(player)
	local base = car and car.PrimaryPart
	if not base then
		return
	end

	local look = base.CFrame.LookVector
	local events = RedLightRule.update(rule, {
		x = base.Position.X,
		z = base.Position.Z,
		dirX = look.X,
		dirZ = look.Z,
		speed = base.AssemblyLinearVelocity.Magnitude,
	}, now)

	for _, event in events do
		if event.kind == "star" then
			if Stars.tryAward(stars, `light{event.crossing}`, now, Config.STAR_COOLDOWN) then
				player:SetAttribute("Stars", stars.total)
				tipEvent:FireClient(player, "stoppedAtRed")
			end
		else
			tipEvent:FireClient(player, event.tip)
		end
	end
end

function TrafficRules.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		players[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for player, state in players do
			check(player, state.rule, state.stars, now)
		end
	end)
end

return TrafficRules
