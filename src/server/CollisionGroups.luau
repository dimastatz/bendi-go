-- Keeps players from bumping into each other (PRD-001, requirement 7): player cars and characters are in one
-- collision group that doesn't collide with itself, so cars drive right through each other.

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

CollisionGroups.PLAYERS = "BendiPlayers"

function CollisionGroups.setup()
	PhysicsService:RegisterCollisionGroup(CollisionGroups.PLAYERS)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.PLAYERS, CollisionGroups.PLAYERS, false)
end

-- Puts every part of `model` in the players group, including parts added later (like a character's accessories).
function CollisionGroups.addPlayerParts(model: Instance)
	local function add(instance: Instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = CollisionGroups.PLAYERS
		end
	end
	for _, descendant in model:GetDescendants() do
		add(descendant)
	end
	model.DescendantAdded:Connect(add)
end

return CollisionGroups
