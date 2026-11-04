-- Looks up player-facing text in the player's language. The language is picked once, from the Roblox language
-- setting and the device language.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("Strings"))

local Text = {}

local language = Strings.languageFor(LocalizationService.RobloxLocaleId, LocalizationService.SystemLocaleId)

function Text.get(key: string): string
	return Strings.get(key, language)
end

return Text
