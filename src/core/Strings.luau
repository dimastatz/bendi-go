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

	-- Speed limits (PRD-003)
	kmh = { en = "km/h", he = "קמ״ש" },
	school = { en = "School", he = "בית ספר" },
	slowZone = {
		en = "This street is 30! Streets where people live and kids play are slower, so everyone stays safe.",
		he = "ברחוב הזה מותר 30! ברחובות שבהם גרים אנשים וילדים משחקים נוסעים לאט, כדי שכולם יהיו בטוחים.",
	},
	tooFastTown = {
		en = "This street is 50. Slow down a little!",
		he = "ברחוב הזה מותר 50. להאט קצת!",
	},
	tooFastResidential = {
		en = "This street is 30. Slow down, people live here!",
		he = "ברחוב הזה מותר 30. להאט, גרים כאן אנשים!",
	},
	tooFastSchool = {
		en = "This street is 30. Slow down, there's a school here!",
		he = "ברחוב הזה מותר 30. להאט, יש כאן בית ספר!",
	},
	speedStar = {
		en = "Nice and steady! You kept to the speed limit on that street.",
		he = "יפה מאוד! שמרת על המהירות המותרת ברחוב הזה.",
	},

	-- Crosswalks (PRD-004)
	pedestrianWaiting = {
		en = "Someone wants to cross! Stop before the stripes and let them go first.",
		he = "מישהו רוצה לחצות! עוצרים לפני הפסים ונותנים לו לעבור קודם.",
	},
	didntStopForPedestrian = {
		en = "Someone was on the crosswalk! Always stop and let people cross first.",
		he = "מישהו היה במעבר החציה! תמיד עוצרים ונותנים להולכי רגל לעבור קודם.",
	},
	crosswalkPraise = {
		en = "Thank you for letting them cross!",
		he = "תודה שנתת להם לחצות!",
	},

	-- Roundabouts, stop signs, and give-way signs (PRD-005)
	roundaboutFirst = {
		en = "Cars already in the roundabout go first. Wait for them, then join!",
		he = "מכוניות שכבר בכיכר עוברות ראשונות. מחכים להן, ואז נכנסים!",
	},
	didntYieldRoundabout = {
		en = "Wait! Cars in the roundabout go first. Look left before you join.",
		he = "רגע! מכוניות בכיכר עוברות ראשונות. מסתכלים שמאלה לפני שנכנסים.",
	},
	yieldedRoundabout = {
		en = "Well done! You let the cars in the roundabout go first.",
		he = "כל הכבוד! נתת למכוניות בכיכר לעבור קודם.",
	},
	clearRoundabout = {
		en = "Nice! The roundabout was clear, so you could go.",
		he = "יפה! הכיכר הייתה פנויה, אז אפשר היה להיכנס.",
	},
	giveWayFirst = {
		en = "This sign means give way: cars on the main road go first. Wait for them!",
		he = "התמרור הזה אומר לתת זכות קדימה: מכוניות בכביש הראשי עוברות ראשונות. מחכים להן!",
	},
	didntGiveWay = {
		en = "Cars on the main road go first. Wait until they pass, then go.",
		he = "מכוניות בכביש הראשי עוברות ראשונות. מחכים שיעברו, ואז נוסעים.",
	},
	yieldedGiveWay = {
		en = "Well done! You let the other cars go first.",
		he = "כל הכבוד! נתת למכוניות האחרות לעבור קודם.",
	},
	clearGiveWay = {
		en = "Nice! The main road was clear, so you could go.",
		he = "יפה! הכביש הראשי היה פנוי, אז אפשר היה לנסוע.",
	},
	stopSign = {
		en = "A stop sign means a full stop before the line, every time. Then look both ways and go.",
		he = "תמרור עצור אומר לעצור לגמרי לפני הקו, כל פעם. אחר כך מסתכלים לשני הכיוונים ונוסעים.",
	},
	rolledStop = {
		en = "At a stop sign, stop completely before the line, even if the road looks empty.",
		he = "בתמרור עצור עוצרים לגמרי לפני הקו, גם אם הכביש נראה ריק.",
	},
	stopPraise = { en = "Great full stop!", he = "עצירה מלאה, מצוין!" },
	stopWord = { en = "STOP", he = "עצור" },

	-- Driving lessons and the license (PRD-006). Text in {braces} is filled in by the game.
	lessons = { en = "Lessons", he = "שיעורים" },
	lessonNumber = { en = "Lesson {number}", he = "שיעור {number}" },
	lessonBasics = { en = "Driving basics", he = "יסודות הנהיגה" },
	lessonLights = { en = "Traffic lights", he = "רמזורים" },
	lessonSpeed = { en = "Speed limits", he = "מהירות מותרת" },
	lessonCrosswalks = { en = "Crosswalks", he = "מעברי חציה" },
	lessonJunctions = { en = "Roundabouts and signs", he = "כיכרות ותמרורים" },
	drivingTest = { en = "Driving test", he = "מבחן נהיגה" },
	start = { en = "Start", he = "התחלה" },
	locked = { en = "Locked", he = "נעול" },
	notTried = { en = "Not passed yet", he = "עוד לא עברת" },
	passedBest = { en = "Passed! Best: {stars} ⭐", he = "עברת! שיא: {stars} ⭐" },
	bestSoFar = { en = "Best so far: {stars} ⭐", he = "שיא עד עכשיו: {stars} ⭐" },
	freeDriving = { en = "Free driving", he = "נהיגה חופשית" },
	tryAgain = { en = "Try again", he = "לנסות שוב" },
	nextLesson = { en = "Next lesson", he = "לשיעור הבא" },
	close = { en = "Close", he = "סגירה" },
	introBasics = {
		en = "Let's learn to drive! Follow the arrows on the road and keep to the right side of the street.",
		he = "בואו נלמד לנהוג! נוסעים לפי החצים על הכביש ושומרים על הצד הימני של הרחוב.",
	},
	introLights = {
		en = "This lesson goes through traffic lights. Stop at red, and go when it turns green!",
		he = "השיעור הזה עובר דרך רמזורים. עוצרים באדום, ונוסעים כשמתחלף לירוק!",
	},
	introSpeed = {
		en = "Watch the speed signs! Most streets are 50, and streets near homes and schools are 30.",
		he = "שימו לב לתמרורי המהירות! ברוב הרחובות מותר 50, וליד בתים ובתי ספר מותר 30.",
	},
	introCrosswalks = {
		en = "Look out for people at the zebra crossings. If someone wants to cross, stop and let them go first.",
		he = "שימו לב לאנשים ליד מעברי החציה. אם מישהו רוצה לחצות, עוצרים ונותנים לו לעבור קודם.",
	},
	introJunctions = {
		en = "Roundabouts and signs! Give way to cars in the roundabout, and stop completely at the stop sign.",
		he = "כיכרות ותמרורים! נותנים זכות קדימה למכוניות בכיכר, ועוצרים לגמרי בתמרור עצור.",
	},
	introTest = {
		en = "This is your driving test! Follow every rule all the way to the end to get your license.",
		he = "זה מבחן הנהיגה שלך! שומרים על כל החוקים עד הסוף כדי לקבל רישיון.",
	},
	lessonStars = { en = "{stars} of {need} ⭐", he = "{stars} מתוך {need} ⭐" },
	lessonPassed = {
		en = "You passed the lesson with {stars} stars!",
		he = "עברת את השיעור עם {stars} כוכבים!",
	},
	lessonTryAgain = {
		en = "You got {stars} stars, and you need {need} to pass. Let's try again!",
		he = "קיבלת {stars} כוכבים, וצריך {need} כדי לעבור. בואו ננסה שוב!",
	},
	lessonUnlocked = {
		en = "A new lesson is open! Find it in the Lessons menu.",
		he = "נפתח שיעור חדש! אפשר למצוא אותו בתפריט השיעורים.",
	},
	testUnlocked = {
		en = "You passed every lesson! The driving test is open.",
		he = "עברת את כל השיעורים! מבחן הנהיגה פתוח.",
	},
	testPassed = {
		en = "You passed the driving test! Here is your license!",
		he = "עברת את מבחן הנהיגה! הנה הרישיון שלך!",
	},
	testFailed = {
		en = "Almost! A few rules were missed. Remember Bendi's tips and try again.",
		he = "כמעט! כמה חוקים לא נשמרו. זוכרים את הטיפים של בנדי ומנסים שוב.",
	},
	licenseTitle = { en = "Driving License", he = "רישיון נהיגה" },
	licenseName = { en = "Name", he = "שם" },
	licenseDate = { en = "Date", he = "תאריך" },
	licenseClass = { en = "Class", he = "דרגה" },
	myLicense = { en = "My license", he = "הרישיון שלי" },
	licensedDriver = { en = "Licensed driver", he = "יש לי רישיון!" },
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

-- Like `get`, and fills in each {name} in the text with values[name]. A name with no value is left as it is.
function Strings.format(key: string, language: string, values: { [string]: any }): string
	local text = Strings.get(key, language)
	return (
		string.gsub(text, "{(%w+)}", function(name: string): string
			local value = values[name]
			return if value ~= nil then tostring(value) else `\{{name}\}`
		end)
	)
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
