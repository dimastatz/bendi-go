--!strict
-- A player's saved progress (PRD-006, requirements 4, 5, 10, and 11): total stars, each lesson's best star count
-- and whether it's passed, and the date of their driving license.
-- The server saves it in a Roblox DataStore. Anything loaded goes through `sanitize`, so a broken or old save can
-- never break the game, and `merge` combines a save with progress made while saving or loading wasn't working.

local Lessons = require("./Lessons")

export type LessonRecord = { passed: boolean, best: number }

export type Data = {
	version: number,
	stars: number,
	lessons: { [string]: LessonRecord },
	license: string?, -- the day the license was earned, like "2026-11-08"
}

local Progress = {}

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
				data.lessons[lesson.id] = { passed = record.passed == true, best = count(record.best) }
			end
		end
	end
	if isDate(raw.license) then
		data.license = raw.license
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

-- The first lesson is always open, each later one opens when the one before it is passed, and the driving test
-- opens when every lesson is passed.
function Progress.isUnlocked(data: Data, id: string): boolean
	for index, lesson in Lessons.LIST do
		if lesson.id == id then
			if lesson.isTest then
				for _, other in Lessons.LIST do
					if not other.isTest and not Progress.isPassed(data, other.id) then
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

-- Records a finished lesson or test. Returns the id of the lesson (or test) that this opened, if any.
function Progress.record(data: Data, id: string, stars: number, passed: boolean): string?
	local record = data.lessons[id] or { passed = false, best = 0 }
	local wasPassed = record.passed
	record.passed = wasPassed or passed
	record.best = math.max(record.best, stars)
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
