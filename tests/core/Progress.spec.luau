local TestKit = require("../TestKit")
local Lessons = require("../../src/core/Lessons")
local Progress = require("../../src/core/Progress")

local test, expectEqual = TestKit.test, TestKit.expectEqual

print("Progress")

local function passAll(data: Progress.Data)
	for _, lesson in Lessons.LIST do
		if not lesson.isTest then
			Progress.record(data, lesson.id, 3, true)
		end
	end
end

test("new progress has no stars, lessons, or license", function()
	local data = Progress.new()
	expectEqual(data.version, Progress.VERSION)
	expectEqual(data.stars, 0)
	expectEqual(next(data.lessons), nil)
	expectEqual(data.license, nil)
end)

test("only the first lesson is open at the start", function()
	local data = Progress.new()
	for index, lesson in Lessons.LIST do
		expectEqual(Progress.isUnlocked(data, lesson.id), index == 1)
	end
	expectEqual(Progress.isUnlocked(data, "flying"), false)
end)

test("passing a lesson opens the next one", function()
	local data = Progress.new()
	expectEqual(Progress.record(data, "basics", 4, true), "lights")
	expectEqual(Progress.isPassed(data, "basics"), true)
	expectEqual(Progress.best(data, "basics"), 4)
	expectEqual(Progress.isUnlocked(data, "lights"), true)
	expectEqual(Progress.isUnlocked(data, "speed"), false)
end)

test("not passing opens nothing, but keeps the best star count", function()
	local data = Progress.new()
	expectEqual(Progress.record(data, "basics", 2, false), nil)
	expectEqual(Progress.isPassed(data, "basics"), false)
	expectEqual(Progress.best(data, "basics"), 2)
	expectEqual(Progress.isUnlocked(data, "lights"), false)
	expectEqual(Progress.best(data, "lights"), 0)
end)

test("retrying a passed lesson keeps it passed and keeps the best stars", function()
	local data = Progress.new()
	Progress.record(data, "basics", 5, true)
	expectEqual(Progress.record(data, "basics", 1, false), nil)
	expectEqual(Progress.record(data, "basics", 4, true), nil) -- the next lesson is already open
	expectEqual(Progress.isPassed(data, "basics"), true)
	expectEqual(Progress.best(data, "basics"), 5)
end)

test("the driving test opens once every lesson is passed", function()
	local data = Progress.new()
	for _, lesson in Lessons.LIST do
		if lesson.id ~= "junctions" and not lesson.isTest then
			Progress.record(data, lesson.id, 3, true)
		end
	end
	expectEqual(Progress.isUnlocked(data, "test"), false)
	expectEqual(Progress.record(data, "junctions", 3, true), "test")
	expectEqual(Progress.isUnlocked(data, "test"), true)
	-- Passing the test finishes level 3, so the first mission is next.
	expectEqual(Progress.record(data, "test", 0, true), "schoolRun")
end)

test("a license is dated and never replaced", function()
	local data = Progress.new()
	Progress.grantLicense(data, "2026-11-08")
	Progress.grantLicense(data, "2027-01-01")
	expectEqual(data.license, "2026-11-08")
	expectEqual(pcall(Progress.grantLicense, Progress.new(), "tomorrow"), false)
end)

test("dates are shown the Israeli way", function()
	expectEqual(Progress.formatDate("2026-11-08"), "08.11.2026")
	expectEqual(Progress.formatDate("soon"), "soon")
end)

test("sanitize keeps a good save as it was", function()
	local data = Progress.new()
	data.stars = 42
	passAll(data)
	Progress.grantLicense(data, "2026-11-08")
	local loaded = Progress.sanitize(data)
	expectEqual(loaded.stars, 42)
	expectEqual(loaded.license, "2026-11-08")
	expectEqual(Progress.isUnlocked(loaded, "test"), true)
	expectEqual(Progress.best(loaded, "speed"), 3)
end)

test("sanitize turns anything broken into new progress, keeping what makes sense", function()
	expectEqual(Progress.sanitize(nil).stars, 0)
	expectEqual(Progress.sanitize("hello").stars, 0)
	local loaded = Progress.sanitize({
		stars = -5,
		lessons = { basics = { passed = "yes", best = 2.7 }, lights = 3, flying = { passed = true, best = 9 } },
		license = "someday",
	})
	expectEqual(loaded.stars, 0)
	expectEqual(Progress.isPassed(loaded, "basics"), false)
	expectEqual(Progress.best(loaded, "basics"), 2)
	expectEqual(loaded.lessons.lights, nil)
	expectEqual(loaded.lessons.flying, nil)
	expectEqual(loaded.license, nil)
	expectEqual(Progress.sanitize({ stars = 0 / 0 }).stars, 0)
	expectEqual(Progress.sanitize({ stars = math.huge }).stars, 0)
	expectEqual(Progress.sanitize({ stars = 7, lessons = "none" }).stars, 7)
end)

test("merge adds up stars and keeps the best of every lesson", function()
	local saved = Progress.new()
	saved.stars = 30
	Progress.record(saved, "basics", 4, true)
	Progress.record(saved, "lights", 1, false)
	Progress.grantLicense(saved, "2026-11-01")

	local session = Progress.new()
	session.stars = 5
	Progress.record(session, "basics", 2, false)
	Progress.record(session, "lights", 3, true)
	Progress.grantLicense(session, "2026-11-08")

	local merged = Progress.merge(saved, session)
	expectEqual(merged.stars, 35)
	expectEqual(Progress.isPassed(merged, "basics"), true)
	expectEqual(Progress.best(merged, "basics"), 4)
	expectEqual(Progress.isPassed(merged, "lights"), true)
	expectEqual(Progress.best(merged, "lights"), 3)
	expectEqual(merged.lessons.speed, nil)
	expectEqual(merged.license, "2026-11-01")
	expectEqual(saved.stars, 30) -- the inputs aren't changed

	expectEqual(Progress.merge(Progress.new(), session).license, "2026-11-08")
end)

-- Passes every session in levels up to `last`.
local function passLevels(data: Progress.Data, last: number)
	for level = 1, last do
		for _, lesson in Lessons.inLevel(level) do
			Progress.record(data, lesson.id, 3, true, 3)
		end
	end
end

test("a new player is on level 1, and each level opens when the one before it is passed", function()
	local data = Progress.new()
	expectEqual(Progress.level(data), 1)
	expectEqual(Progress.isLevelOpen(data, 1), true)
	expectEqual(Progress.isLevelOpen(data, 2), false)
	Progress.record(data, "basics", 3, true)
	expectEqual(Progress.level(data), 1)
	expectEqual(select(1, Progress.levelProgress(data, 1)), 1)
	expectEqual(select(2, Progress.levelProgress(data, 1)), 2)
	Progress.record(data, "lights", 3, true)
	expectEqual(Progress.level(data), 2)
	passLevels(data, 3)
	expectEqual(Progress.level(data), 4)
	passLevels(data, #Lessons.LEVELS)
	expectEqual(Progress.level(data), #Lessons.LEVELS)
end)

test("a level stays closed while any level before it isn't passed", function()
	local data = Progress.new()
	for _, lesson in Lessons.inLevel(2) do
		Progress.record(data, lesson.id, 3, true)
	end
	expectEqual(Progress.isLevelOpen(data, 3), false)
	expectEqual(Progress.isUnlocked(data, "junctions"), false)
end)

test("missions stay locked until their level opens, and then all open at once", function()
	local data = Progress.new()
	local missions = Lessons.inLevel(4)
	expectEqual(Progress.isUnlocked(data, missions[1].id), false)
	passLevels(data, 3)
	for _, mission in missions do
		expectEqual(Progress.isUnlocked(data, mission.id), true)
	end
	expectEqual(Progress.isUnlocked(data, Lessons.inLevel(5)[1].id), false)
	-- Passing one mission doesn't open the next level, but passing all of them does.
	expectEqual(Progress.record(data, missions[1].id, 0, true, 1), missions[2].id)
	expectEqual(Progress.level(data), 4)
	Progress.record(data, missions[2].id, 0, true, 1)
	expectEqual(Progress.level(data), 5)
	expectEqual(Progress.isUnlocked(data, Lessons.inLevel(5)[1].id), true)
end)

test("a session keeps its best medal, and a session that isn't passed earns none", function()
	local data = Progress.new()
	Progress.record(data, "basics", 2, false, 0)
	expectEqual(Progress.medal(data, "basics"), 0)
	Progress.record(data, "basics", 3, true, 2)
	expectEqual(Progress.medal(data, "basics"), 2)
	Progress.record(data, "basics", 4, true, 1)
	expectEqual(Progress.medal(data, "basics"), 2)
	Progress.record(data, "basics", 4, true, 3)
	expectEqual(Progress.medal(data, "basics"), 3)
	-- Without a medal, a pass is bronze.
	Progress.record(data, "lights", 3, true)
	expectEqual(Progress.medal(data, "lights"), 1)
	expectEqual(Progress.medal(data, "speed"), 0)
end)

test("old saves get medals: bronze for passed sessions, gold for the test, and a license passes the test", function()
	local loaded = Progress.sanitize({
		stars = 10,
		lessons = { basics = { passed = true, best = 3 }, lights = { passed = false, best = 1 } },
		license = "2026-11-08",
	})
	expectEqual(Progress.medal(loaded, "basics"), 1)
	expectEqual(Progress.medal(loaded, "lights"), 0)
	expectEqual(Progress.isPassed(loaded, "test"), true)
	expectEqual(Progress.medal(loaded, "test"), 3)

	local withTest = Progress.sanitize({ lessons = { test = { passed = true, best = 6 } } })
	expectEqual(Progress.medal(withTest, "test"), 3)
	expectEqual(Progress.best(withTest, "test"), 6)
	local licensed = Progress.sanitize({ lessons = { test = { passed = false, best = 4 } }, license = "2026-11-08" })
	expectEqual(Progress.best(licensed, "test"), 4)
	expectEqual(Progress.isPassed(licensed, "test"), true)
	-- Medals out of range are fixed.
	local odd = Progress.sanitize({ lessons = { basics = { passed = true, best = 3, medal = 9 } } })
	expectEqual(Progress.medal(odd, "basics"), 3)
end)

test("players who passed every lesson and the test start on level 4", function()
	local loaded = Progress.sanitize({
		lessons = {
			basics = { passed = true, best = 3 },
			lights = { passed = true, best = 3 },
			speed = { passed = true, best = 3 },
			crosswalks = { passed = true, best = 3 },
			junctions = { passed = true, best = 3 },
		},
		license = "2026-11-08",
	})
	expectEqual(Progress.level(loaded), 4)
end)

test("merge keeps the best medal", function()
	local a, b = Progress.new(), Progress.new()
	Progress.record(a, "basics", 3, true, 3)
	Progress.record(b, "basics", 3, true, 1)
	expectEqual(Progress.medal(Progress.merge(a, b), "basics"), 3)
	expectEqual(Progress.medal(Progress.merge(b, a), "basics"), 3)
end)

TestKit.finish()
