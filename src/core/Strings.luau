--!strict
-- All player-facing text, in English and Hebrew (see specs/README.md). Every piece of text the player sees comes
-- from this one table, so adding a language means adding it to LANGUAGES and to every entry in TEXT.

local Strings = {}

Strings.DEFAULT_LANGUAGE = "en"
Strings.LANGUAGES = { "en", "he" }

Strings.TEXT = {
	resetCar = { en = "Reset car", he = "איפוס רכב" },
	gas = { en = "Gas", he = "גז" },
	brake = { en = "Brake", he = "בלם" },
} :: { [string]: { [string]: string } }

-- Returns the language to show for the given locale ids (like "he-il" or "en-us"). The first one that is a
-- supported language other than English wins, so a player whose Roblox is in English but whose device is in
-- Hebrew still gets Hebrew.
function Strings.languageFor(...: string): string
	for _, localeId in { ... } do
		local code = string.lower(string.sub(localeId, 1, 2))
		if code == "iw" then
			code = "he" -- an older code for Hebrew that some devices still use
		end
		if code ~= Strings.DEFAULT_LANGUAGE and table.find(Strings.LANGUAGES, code) then
			return code
		end
	end
	return Strings.DEFAULT_LANGUAGE
end

-- Returns the text for `key` in `language`, or in English if that language doesn't have it yet.
-- An unknown key comes back as itself, so a missing entry shows up on screen instead of breaking the game.
function Strings.get(key: string, language: string): string
	local entry = Strings.TEXT[key]
	if not entry then
		return key
	end
	return entry[language] or entry[Strings.DEFAULT_LANGUAGE]
end

return Strings
