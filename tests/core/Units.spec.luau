local TestKit = require("../TestKit")
local Units = require("../../src/core/Units")

local test, expectEqual, expectNear = TestKit.test, TestKit.expectEqual, TestKit.expectNear

print("Units")

test("zero speed is zero in both units", function()
	expectEqual(Units.studsPerSecondToKmh(0), 0)
	expectEqual(Units.kmhToStudsPerSecond(0), 0)
end)

test("converts studs per second to km/h", function()
	-- 50 studs/s * 0.28 m/stud = 14 m/s = 50.4 km/h
	expectNear(Units.studsPerSecondToKmh(50), 50.4)
end)

test("converts km/h to studs per second", function()
	-- 50.4 km/h = 14 m/s = 50 studs/s
	expectNear(Units.kmhToStudsPerSecond(50.4), 50)
end)

test("conversions round-trip", function()
	for _, kmh in { 30, 50, 70 } do
		expectNear(Units.studsPerSecondToKmh(Units.kmhToStudsPerSecond(kmh)), kmh)
	end
end)

TestKit.finish()
