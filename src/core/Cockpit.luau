--!strict
-- The inside view from the Bendi car's driver seat (PRD-007): which camera view is on, how far the steering wheel is
-- turned, where the speedometer needle points, where the driver is looking, and the clock on the dashboard screen.
-- Angles are in degrees.

local Cockpit = {}

export type View = "outside" | "inside"

-- Where the driver is looking, turned away from straight ahead. A positive yaw is to the left, and a positive pitch
-- is up.
export type Look = { yaw: number, pitch: number }

-- Shared by the server, which builds the inside of the car, and the client, which puts the camera and hands there.
-- Positions are in studs from the middle of the car on the ground, and the front of the car is -Z.
Cockpit.DRIVER_X = -1.5 -- the driver sits on the left, like in every Israeli car
Cockpit.SEAT_TOP = 3.3 -- low enough that the player's head fits under the roof
Cockpit.EYE = { x = -1.5, y = 5.8, z = 1 } -- where the driver's eyes are
Cockpit.WHEEL_RADIUS = 0.95

Cockpit.DIAL_MAX_KMH = 140 -- the top of the speedometer
Cockpit.NEEDLE_SWEEP = 240 -- how far the needle turns from 0 to DIAL_MAX_KMH
Cockpit.WHEEL_MAX_TURN = 120 -- how far the steering wheel turns at full steering
Cockpit.WHEEL_SPEED = 10 -- how quickly the steering wheel follows the steering
Cockpit.LOOK_MAX_YAW = 110 -- far enough to see the instructor in the seat next to you
Cockpit.LOOK_MAX_PITCH = 35
Cockpit.LOOK_RETURN_SPEED = 3 -- how quickly the view turns back to the road when the player lets go

function Cockpit.toggle(view: View): View
	return if view == "outside" then "inside" else "outside"
end

-- The needle's angle at `kmh`: straight up is 0, the lowest speed is to the left (negative), and the highest to the
-- right.
function Cockpit.needleAngle(kmh: number): number
	local t = math.clamp(kmh / Cockpit.DIAL_MAX_KMH, 0, 1)
	return Cockpit.NEEDLE_SWEEP * (t - 0.5)
end

-- The steering wheel's next angle, `dt` seconds after `current`, moving smoothly toward the steering input `steer`
-- (from -1 for full left to 1 for full right). Turning right is clockwise, a positive angle.
function Cockpit.wheelAngle(current: number, steer: number, dt: number): number
	local target = math.clamp(steer, -1, 1) * Cockpit.WHEEL_MAX_TURN
	return current + (target - current) * (1 - math.exp(-Cockpit.WHEEL_SPEED * dt))
end

-- Where the driver looks next. While `holding` (a mouse button, a finger, a stick, or a key is turning the view), it
-- turns by `turnYaw` and `turnPitch`, up to the limits. Otherwise it turns smoothly back to the road.
function Cockpit.look(look: Look, turnYaw: number, turnPitch: number, holding: boolean, dt: number): Look
	if holding then
		return {
			yaw = math.clamp(look.yaw + turnYaw, -Cockpit.LOOK_MAX_YAW, Cockpit.LOOK_MAX_YAW),
			pitch = math.clamp(look.pitch + turnPitch, -Cockpit.LOOK_MAX_PITCH, Cockpit.LOOK_MAX_PITCH),
		}
	end
	local keep = math.exp(-Cockpit.LOOK_RETURN_SPEED * dt)
	return { yaw = look.yaw * keep, pitch = look.pitch * keep }
end

-- The clock on the dashboard screen at clock time `hour`, like "07:05".
function Cockpit.clockText(hour: number): string
	local minutes = math.floor(hour * 60 + 0.5) % (24 * 60)
	return string.format("%02d:%02d", minutes // 60, minutes % 60)
end

return Cockpit
