--!strict
-- Merges driving input from several controls (keyboard, gamepad, and touch) into one CarPhysics input,
-- so a player can use whichever control they like, or more than one at once.

local CarPhysics = require("./CarPhysics")

local DriverInput = {}

function DriverInput.combine(inputs: { CarPhysics.Input }): CarPhysics.Input
	local throttle, steer, brake = 0, 0, false
	for _, input in inputs do
		throttle += input.throttle
		steer += input.steer
		brake = brake or input.brake
	end
	return { throttle = math.clamp(throttle, -1, 1), steer = math.clamp(steer, -1, 1), brake = brake }
end

return DriverInput
