-- Marks parts that light up in the dark (PRD-007): street lamps, headlights, and windows with the lights on inside.
-- The server only builds and tags them. Every client turns them on and off with its own sky (client DayNight), using
-- the same Core.DayCycle, so all players see the same thing.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DayCycle = require(ReplicatedStorage.Core.DayCycle)

local NightLight = {}

-- Tags `part` as a night light that glows `litColor` when on. If `light` is given (a SpotLight or PointLight), it's
-- put in the part, starts off, and is turned on with it.
function NightLight.tag(part: BasePart, litColor: Color3, light: Light?)
	part:SetAttribute(DayCycle.LIT_COLOR, litColor)
	if light then
		light.Enabled = false
		light.Color = litColor
		light.Parent = part
	end
	CollectionService:AddTag(part, DayCycle.LIGHT_TAG)
end

return NightLight
