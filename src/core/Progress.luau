--!strict
-- A player's saved progress (PRD-006, requirements 4, 5, 10, and 11, and PRD-009, requirements 11 and 16 to 19):
-- total stars, each session's best star count, best medal, and whether it's passed, and the date of their license.
-- The player's level is never saved. It's worked out from the passed sessions, so it can't get out of step.
-- The server saves it in a Roblox DataStore. Anything loaded goes through `sanitize`, so a broken or old save can
-- never break the game, and `merge` combines a save with progress made while saving or loading wasn't working.

local Lessons = require("./Lessons")

-- `medal` is the best medal: 0 for none, then 1 bronze, 2 silver, 3 gold (see LessonRun).
export type LessonRecord = { passed: boolean, best: number, medal: number }

export type Data = {
	version: number,
	stars: number,
	lessons: { [string]: LessonRecord },
	license: string?, -- the day the license was earned, like "2026-11-08"
}

local Progress = {}

local GOLD = 3

Progress.VERSION = 1

function Progress.new(): Data
	return { version = Progress.VERSION, stars = 0, lessons = {}, license = nil }
end

local function count(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

local function isDate(value: any): boolean
	return type(value) == "string" and string.match(value, "^%d%d%d%d%-%d%d%-%d%d$") ~= nil
end

-- Turns whatever was loaded into valid progress, keeping every part that makes sense.
function Progress.sanitize(raw: any): Data
	local data = Progress.new()
	if type(raw) ~= "table" then
		return data
	end
	data.stars = count(raw.stars)
	if type(raw.lessons) == "table" then
		for _, lesson in Lessons.LIST do
			local record = raw.lessons[lesson.id]
			if type(record) == "table" then
				local passed = record.passed == true
				local medal = math.min(count(record.medal), GOLD)
				-- Saves from before medals: a passed test followed every rule, and other passed sessions get bronze.
				if passed and medal == 0 then
					medal = if lesson.isTest then GOLD else 1
				end
				data.lessons[lesson.id] = { passed = passed, best = count(record.best), medal = medal }
			end
		end
	end
	if isDate(raw.license) then
		data.license = raw.license
		-- A license means the test was passed, even if an old save lost that.
		local test = data.lessons.test
		data.lessons.test = { passed = true, best = if test then test.best else 0, medal = GOLD }
	end
	return data
end

-- Combines saved progress with progress made in a session that couldn't load the save: stars add up, and every
-- lesson keeps its best result. Neither table is changed.
function Progress.merge(saved: Data, session: Data): Data
	local merged = Progress.new()
	merged.stars = saved.stars + session.stars
	for _, lesson in Lessons.LIST do
		local a, b = saved.lessons[lesson.id], session.lessons[lesson.id]
		if a or b then
			merged.lessons[lesson.id] = {
				passed = (a ~= nil and a.passed) or (b ~= nil and b.passed),
				best = math.max(if a then a.best else 0, if b then b.best else 0),
				medal = math.max(if a then a.medal else 0, if b then b.medal else 0),
			}
		end
	end
	merged.license = saved.license or session.license
	return merged
end

function Progress.isPassed(data: Data, id: string): boolean
	local record = data.lessons[id]
	return record ~= nil and record.passed
end

-- The best star count on this lesson so far.
function Progress.best(data: Data, id: string): number
	local record = data.lessons[id]
	return if record then record.best else 0
end

-- The best medal on this session so far: 0 for none, then bronze, silver, gold.
function Progress.medal(data: Data, id: string): number
	local record = data.lessons[id]
	return if record then record.medal else 0
end

-- How many sessions in `level` are passed, out of how many.
function Progress.levelProgress(data: Data, level: number): (number, number)
	local passed, total = 0, 0
	for _, lesson in Lessons.inLevel(level) do
		total += 1
		if Progress.isPassed(data, lesson.id) then
			passed += 1
		end
	end
	return passed, total
end

-- Level 1 is always open, and each later level opens when every session in the level before it is passed.
function Progress.isLevelOpen(data: Data, level: number): boolean
	if level <= 1 then
		return true
	end
	local passed, total = Progress.levelProgress(data, level - 1)
	return Progress.isLevelOpen(data, level - 1) and passed == total
end

-- The player's level: the highest level that's open.
function Progress.level(data: Data): number
	local level = 1
	while level < #Lessons.LEVELS and Progress.isLevelOpen(data, level + 1) do
		level += 1
	end
	return level
end

-- A session's level must be open. Inside it, missions are all open at once, while lessons still go in order: each
-- one opens when the one before it is passed, and the driving test opens when every lesson is passed.
function Progress.isUnlocked(data: Data, id: string): boolean
	for index, lesson in Lessons.LIST do
		if lesson.id == id then
			if not Progress.isLevelOpen(data, lesson.level) then
				return false
			elseif lesson.mission then
				return true
			elseif lesson.isTest then
				for _, other in Lessons.LIST do
					if not other.isTest and not other.mission and not Progress.isPassed(data, other.id) then
						return false
					end
				end
				return true
			end
			return index == 1 or Progress.isPassed(data, Lessons.LIST[index - 1].id)
		end
	end
	return false
end

-- Records a finished session, with the medal it earned. If this was its first pass and the session after it is open,
-- returns that session's id, for the result card's Next button.
function Progress.record(data: Data, id: string, stars: number, passed: boolean, medal: number?): string?
	local record = data.lessons[id] or { passed = false, best = 0, medal = 0 }
	local wasPassed = record.passed
	record.passed = wasPassed or passed
	record.best = math.max(record.best, stars)
	record.medal = math.max(record.medal, if passed then medal or 1 else 0)
	data.lessons[id] = record

	local nextLesson = Lessons.after(id)
	if passed and not wasPassed and nextLesson and Progress.isUnlocked(data, nextLesson.id) then
		return nextLesson.id
	end
	return nil
end

-- Gives the player their license, dated `date` (like "2026-11-08"). A license is never replaced.
function Progress.grantLicense(data: Data, date: string)
	assert(isDate(date), `not a date: {date}`)
	if not data.license then
		data.license = date
	end
end

-- The date the way Israeli licenses show it: "2026-11-08" becomes "08.11.2026".
function Progress.formatDate(date: string): string
	local year, month, day = string.match(date, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if not year then
		return date
	end
	return `{day}.{month}.{year}`
end

return Progress
