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
	expectEqual(Progress.record(data, "test", 0, true), nil)
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

TestKit.finish()
