-- Looks up player-facing text in the player's language (PRD-002, requirement 9). The language is picked once, from
-- the Roblox language setting and the device language. All text goes through one Roblox LocalizationTable, built
-- from the Strings table in Core.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("Strings"))

local Text = {}

local language = Strings.languageFor(LocalizationService.RobloxLocaleId, LocalizationService.SystemLocaleId)

local function makeTranslator(): Translator
	local localizationTable = Instance.new("LocalizationTable")
	localizationTable.Name = "BendiGoText"
	localizationTable:SetEntries(Strings.entries())
	localizationTable.Parent = LocalizationService
	return localizationTable:GetTranslator(language)
end

local hasTranslator, translator = pcall(makeTranslator)
if not hasTranslator then
	warn(`Bendi Go: couldn't set up the localization table, using the Strings table directly: {translator}`)
end

function Text.get(key: string): string
	if hasTranslator then
		local found, text = pcall(translator.FormatByKey, translator, key)
		if found then
			return text
		end
	end
	return Strings.get(key, language)
end

-- Like `get`, and fills in each {name} in the text with values[name].
function Text.format(key: string, values: { [string]: any }): string
	if hasTranslator then
		local found, text = pcall(translator.FormatByKey, translator, key, values)
		if found then
			return text
		end
	end
	return Strings.format(key, language, values)
end

-- True if the player's language is written right to left, like Hebrew.
function Text.isRightToLeft(): boolean
	return Strings.isRightToLeft(language)
end

return Text
