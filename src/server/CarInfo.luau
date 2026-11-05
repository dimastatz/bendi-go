-- What the rules, pedestrians, and NPC cars need to know about a car: where it is, which way it faces, and how fast
-- it's going on the ground.

local CarInfo = {}

function CarInfo.fromBase(base: BasePart)
	local look = base.CFrame.LookVector
	local velocity = base.AssemblyLinearVelocity
	return {
		x = base.Position.X,
		z = base.Position.Z,
		dirX = look.X,
		dirZ = look.Z,
		speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude,
	}
end

return CarInfo
