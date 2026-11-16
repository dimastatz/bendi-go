local TestKit = require("../TestKit")
local Cockpit = require("../../src/core/Cockpit")

local test, expectEqual, expectNear = TestKit.test, TestKit.expectEqual, TestKit.expectNear

print("Cockpit")

test("the view switches between outside and inside", function()
	expectEqual(Cockpit.toggle("outside"), "inside")
	expectEqual(Cockpit.toggle("inside"), "outside")
end)

test("the needle sweeps from left to right as the speed goes up", function()
	local half = Cockpit.NEEDLE_SWEEP / 2
	expectNear(Cockpit.needleAngle(0), -half)
	expectNear(Cockpit.needleAngle(Cockpit.DIAL_MAX_KMH / 2), 0)
	expectNear(Cockpit.needleAngle(Cockpit.DIAL_MAX_KMH), half)
	-- It stops at the ends of the dial.
	expectNear(Cockpit.needleAngle(-5), -half)
	expectNear(Cockpit.needleAngle(500), half)
end)

test("the steering wheel follows the steering smoothly", function()
	local angle = 0
	angle = Cockpit.wheelAngle(angle, 1, 1 / 60)
	expectEqual(angle > 0 and angle < Cockpit.WHEEL_MAX_TURN / 2, true)
	for _ = 1, 120 do
		angle = Cockpit.wheelAngle(angle, 1, 1 / 60)
	end
	expectNear(angle, Cockpit.WHEEL_MAX_TURN, 0.5)
	for _ = 1, 120 do
		angle = Cockpit.wheelAngle(angle, -1, 1 / 60)
	end
	expectNear(angle, -Cockpit.WHEEL_MAX_TURN, 0.5)
	-- Steering input beyond full is treated as full.
	expectNear(Cockpit.wheelAngle(Cockpit.WHEEL_MAX_TURN, 3, 1), Cockpit.WHEEL_MAX_TURN)
end)

test("looking around turns the view, up to the limits", function()
	local look = Cockpit.look({ yaw = 0, pitch = 0 }, -30, 10, true, 1 / 60)
	expectNear(look.yaw, -30)
	expectNear(look.pitch, 10)
	look = Cockpit.look(look, -500, 500, true, 1 / 60)
	expectNear(look.yaw, -Cockpit.LOOK_MAX_YAW)
	expectNear(look.pitch, Cockpit.LOOK_MAX_PITCH)
end)

test("letting go turns the view back to the road", function()
	local look = { yaw = -Cockpit.LOOK_MAX_YAW, pitch = 20 }
	look = Cockpit.look(look, 0, 0, false, 1 / 60)
	expectEqual(look.yaw > -Cockpit.LOOK_MAX_YAW and look.yaw < 0, true)
	for _ = 1, 300 do
		look = Cockpit.look(look, 0, 0, false, 1 / 60)
	end
	expectNear(look.yaw, 0, 0.1)
	expectNear(look.pitch, 0, 0.1)
end)

test("the dashboard clock shows hours and minutes", function()
	expectEqual(Cockpit.clockText(7), "07:00")
	expectEqual(Cockpit.clockText(19.5), "19:30")
	expectEqual(Cockpit.clockText(0.25), "00:15")
	expectEqual(Cockpit.clockText(23.999), "00:00")
end)

TestKit.finish()
