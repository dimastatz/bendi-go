local TestKit = require("../TestKit")
local Strings = require("../../src/core/Strings")

local test, expectEqual = TestKit.test, TestKit.expectEqual

print("Strings")

test("every text has every language", function()
	for key, entry in Strings.TEXT do
		for _, language in Strings.LANGUAGES do
			if type(entry[language]) ~= "string" or entry[language] == "" then
				error(`{key} has no {language} text`)
			end
		end
	end
end)

test("get returns the text in the requested language", function()
	expectEqual(Strings.get("resetCar", "en"), "Reset car")
	expectEqual(Strings.get("resetCar", "he"), "איפוס רכב")
end)

test("get falls back to English for an unsupported language", function()
	expectEqual(Strings.get("gas", "fr"), "Gas")
end)

test("get returns an unknown key as itself", function()
	expectEqual(Strings.get("noSuchText", "en"), "noSuchText")
end)

test("Hebrew locales pick Hebrew", function()
	expectEqual(Strings.languageFor("he-il"), "he")
	expectEqual(Strings.languageFor("HE"), "he")
	expectEqual(Strings.languageFor("iw-IL"), "he")
end)

test("other locales pick English", function()
	expectEqual(Strings.languageFor("en-us"), "en")
	expectEqual(Strings.languageFor("fr-fr"), "en")
	expectEqual(Strings.languageFor(), "en")
end)

test("a Hebrew device wins over an English Roblox setting", function()
	expectEqual(Strings.languageFor("en-us", "he-il"), "he")
	expectEqual(Strings.languageFor("en-us", "ru-ru"), "en")
end)

test("format fills in values by name", function()
	expectEqual(Strings.format("lessonStars", "en", { stars = 2, need = 3 }), "2 of 3 ⭐")
	expectEqual(Strings.format("lessonNumber", "he", { number = 4 }), "שיעור 4")
	expectEqual(Strings.format("lessonNumber", "en", {}), "Lesson {number}")
end)

test("Hebrew is right to left and English is not", function()
	expectEqual(Strings.isRightToLeft("he"), true)
	expectEqual(Strings.isRightToLeft("en"), false)
end)

test("entries have one row per text, with English as the source", function()
	local entries = Strings.entries()
	local count = 0
	for _ in Strings.TEXT do
		count += 1
	end
	expectEqual(#entries, count)
	for i, entry in entries do
		expectEqual(entry.Source, Strings.TEXT[entry.Key].en)
		expectEqual(entry.Values.he, Strings.TEXT[entry.Key].he)
		if i > 1 then
			expectEqual(entries[i - 1].Key < entry.Key, true)
		end
	end
end)

TestKit.finish()
