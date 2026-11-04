-- Follows the car from behind and a little above (PRD-001, requirement 4).
-- The camera turns smoothly to stay behind the car's heading, and keeps facing forward when the car reverses.

local RunService = game:GetService("RunService")

local ChaseCamera = {}

local BIND_NAME = "BendiChaseCamera"
local DISTANCE = 24 -- studs behind the car
local HEIGHT = 10 -- studs above the ground
local LOOK_AHEAD = 10 -- the camera looks at a point this far in front of the car
local LOOK_HEIGHT = 3
local TURN_SPEED = 4 -- how fast the camera swings around behind the car when it turns
local HORIZONTAL = Vector3.new(1, 0, 1)

local running = false

function ChaseCamera.start(base: BasePart)
	ChaseCamera.stop()
	running = true

	local heading: Vector3? = nil
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable

		local flatForward = base.CFrame.LookVector * HORIZONTAL
		if flatForward.Magnitude > 1e-3 then
			local target = flatForward.Unit
			local blended = if heading then heading:Lerp(target, 1 - math.exp(-TURN_SPEED * dt)) else target
			-- Blending two opposite directions can cancel out, so jump straight to the target then.
			heading = if blended.Magnitude > 1e-3 then blended.Unit else target
		end
		local forward = heading or -Vector3.zAxis

		local position = base.Position - forward * DISTANCE + Vector3.yAxis * HEIGHT
		local focus = base.Position + forward * LOOK_AHEAD + Vector3.yAxis * LOOK_HEIGHT
		camera.CFrame = CFrame.lookAt(position, focus)
	end)
end

function ChaseCamera.stop()
	if not running then
		return
	end
	running = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

return ChaseCamera
