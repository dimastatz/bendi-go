local TestKit = require("../TestKit")
local SpeedZones = require("../../src/core/SpeedZones")
local TownLayout = require("../../src/core/TownLayout")

local test, expectEqual = TestKit.test, TestKit.expectEqual

print("SpeedZones")

test("town streets are 50 km/h", function()
	expectEqual(SpeedZones.limitAt(0, 0), 50)
	local limit, kind = SpeedZones.limitAt(90, -90)
	expectEqual(limit, 50)
	expectEqual(kind, "town")
end)

test("the residential street and the school street are 30 km/h", function()
	local limit, kind = SpeedZones.limitAt(-180, -180)
	expectEqual(limit, 30)
	expectEqual(kind, "residential")
	limit, kind = SpeedZones.limitAt(0, 180)
	expectEqual(limit, 30)
	expectEqual(kind, "school")
end)

test("crossings and places off the road have no limit of their own", function()
	expectEqual(SpeedZones.limitAt(0, 90), nil)
	expectEqual(SpeedZones.limitAt(-90, 0), nil)
end)

test("every slow segment is a real segment", function()
	for _, slow in SpeedZones.SLOW_SEGMENTS do
		local found = false
		for _, segment in TownLayout.segments() do
			if SpeedZones.forSegment(segment) == SpeedZones.SLOW_LIMIT and segment.at == slow.at then
				found = true
			end
		end
		expectEqual(found, true)
	end
end)

test("the school building is next to the school street", function()
	local school = TownLayout.SCHOOL_BUILDING
	expectEqual(school.maxX < 0 and school.maxX > -60, true)
	expectEqual(school.minZ > 90 and school.maxZ < 270, true)
end)

TestKit.finish()
