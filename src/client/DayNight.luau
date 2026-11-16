-- The sky and the night lights (PRD-007). Every frame, sets the time of day from the server's clock with
-- Core.DayCycle, so every player sees the same sky. When it gets dark, it turns on every part tagged as a night light
-- (street lamps, headlights, lit windows), and turns them off again in the morning.
-- The lighting style itself (Future lighting, fog, glow, colors) is set in default.project.json, under Lighting.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayCycle = require(ReplicatedStorage.Core.DayCycle)

local DayNight = {}

-- At night the sky is lit a little by the moon, so the road is always easy to see.
local DAY_AMBIENT = Color3.fromRGB(128, 128, 135)
local NIGHT_AMBIENT = Color3.fromRGB(92, 102, 140)
local NIGHT_EXPOSURE = 0.35
local NIGHT_FOG = Color3.fromRGB(40, 46, 70)

local lightsOn = false
-- How each night light looks when it's off, saved the first time it's seen.
local offLooks: { [BasePart]: { color: Color3, material: Enum.Material } } = setmetatable({} :: any, { __mode = "k" })

local function apply(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	local off = offLooks[part]
	if not off then
		off = { color = part.Color, material = part.Material }
		offLooks[part] = off
	end
	local litColor = part:GetAttribute(DayCycle.LIT_COLOR)
	if lightsOn and typeof(litColor) == "Color3" then
		part.Color = litColor
		part.Material = Enum.Material.Neon
	else
		part.Color = off.color
		part.Material = off.material
	end
	for _, child in part:GetChildren() do
		if child:IsA("Light") then
			child.Enabled = lightsOn
		end
	end
end

function DayNight.start()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local dayFog = if atmosphere then atmosphere.Color else nil

	CollectionService:GetInstanceAddedSignal(DayCycle.LIGHT_TAG):Connect(apply)

	local function update()
		local hour = DayCycle.clockAt(workspace:GetServerTimeNow())
		local darkness = DayCycle.darkness(hour)
		Lighting.ClockTime = hour
		Lighting.OutdoorAmbient = DAY_AMBIENT:Lerp(NIGHT_AMBIENT, darkness)
		Lighting.ExposureCompensation = NIGHT_EXPOSURE * darkness
		if atmosphere and dayFog then
			atmosphere.Color = dayFog:Lerp(NIGHT_FOG, darkness)
		end

		local on = DayCycle.lightsOn(hour)
		if on ~= lightsOn then
			lightsOn = on
			for _, part in CollectionService:GetTagged(DayCycle.LIGHT_TAG) do
				apply(part)
			end
		end
	end

	update()
	for _, part in CollectionService:GetTagged(DayCycle.LIGHT_TAG) do
		apply(part)
	end
	RunService.Heartbeat:Connect(update)
end

return DayNight
