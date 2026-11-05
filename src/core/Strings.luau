--!strict
-- All player-facing text, in English and Hebrew (see specs/README.md). Every piece of text the player sees comes
-- from this one table, so adding a language means adding it to LANGUAGES and to every entry in TEXT.
-- The client loads it into a Roblox LocalizationTable (see `entries`).

local Strings = {}

Strings.DEFAULT_LANGUAGE = "en"
Strings.LANGUAGES = { "en", "he" }
Strings.RIGHT_TO_LEFT = { he = true } :: { [string]: boolean }

Strings.TEXT = {
	resetCar = { en = "Reset car", he = "איפוס רכב" },
	gas = { en = "Gas", he = "גז" },
	brake = { en = "Brake", he = "בלם" },

	-- Bendi's traffic light tips (PRD-002)
	ranRed = {
		en = "Red light means stop! Wait behind the white line until it turns green.",
		he = "אור אדום אומר לעצור! מחכים מאחורי הקו הלבן עד שהרמזור מתחלף לירוק.",
	},
	stoppedAtRed = {
		en = "Great job! You stopped and waited for green.",
		he = "כל הכבוד! עצרת וחיכית לירוק.",
	},
	flashingGreen = {
		en = "Flashing green means the light is about to change. Get ready to stop!",
		he = "ירוק מהבהב אומר שהרמזור עומד להתחלף. מתכוננים לעצור!",
	},
	redYellow = {
		en = "Red and yellow together means get ready, but don't go yet. Wait for green!",
		he = "אדום וצהוב ביחד אומר להתכונן, אבל עוד לא נוסעים. מחכים לירוק!",
	},
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

-- True if `language` is written right to left, like Hebrew.
function Strings.isRightToLeft(language: string): boolean
	return Strings.RIGHT_TO_LEFT[language] == true
end

export type Entry = { Key: string, Source: string, Context: string, Example: string, Values: { [string]: string } }

-- The table as entries for Roblox's LocalizationTable:SetEntries, one per key, with English as the source text.
function Strings.entries(): { Entry }
	local entries = {}
	for key, texts in Strings.TEXT do
		local values = {}
		for _, language in Strings.LANGUAGES do
			values[language] = texts[language]
		end
		table.insert(entries, {
			Key = key,
			Source = texts[Strings.DEFAULT_LANGUAGE],
			Context = "",
			Example = "",
			Values = values,
		})
	end
	table.sort(entries, function(a: Entry, b: Entry)
		return a.Key < b.Key
	end)
	return entries
end

return Strings
