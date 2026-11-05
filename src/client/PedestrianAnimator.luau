-- Swings the arms and legs of the people walking around town, and turns their heads when they look both ways.
-- The server only moves each figure's torso, so this works out how fast each one is walking from how far it moved.

local RunService = game:GetService("RunService")

local PedestrianAnimator = {}

local SWING = math.rad(35) -- how far legs and arms swing at a full stride
local STRIDE = 0.9 -- radians of swing per stud walked, for a full-size adult
local HEAD_TURN = math.rad(50)

type Figure = { motors: { [string]: Motor6D }, last: Vector3?, phase: number, amount: number, look: number }

local figures: { [Model]: Figure } = {}

local function figureFor(model: Model): Figure?
	local figure = figures[model]
	if figure then
		return figure
	end
	local torso = model.PrimaryPart
	if not torso then
		return nil
	end
	local motors = {}
	for _, child in torso:GetChildren() do
		if child:IsA("Motor6D") then
			motors[child.Name] = child
		end
	end
	figure = { motors = motors, last = nil, phase = 0, amount = 0, look = 0 }
	figures[model] = figure
	model.Destroying:Connect(function()
		figures[model] = nil
	end)
	return figure
end

local function animate(model: Model, figure: Figure, dt: number)
	local torso = model.PrimaryPart
	if not torso then
		return
	end
	local position = torso.Position
	local moved = if figure.last then (position - figure.last).Magnitude else 0
	figure.last = position
	local scale = model:GetAttribute("Scale") or 1

	-- Swing while walking, and ease back to standing when stopped.
	local walking = dt > 0 and moved / dt > 0.5
	figure.amount += ((if walking then 1 else 0) - figure.amount) * math.min(1, dt * 8)
	figure.phase += moved * STRIDE / scale
	local swing = math.sin(figure.phase) * SWING * figure.amount

	local motors = figure.motors
	local function set(name: string, angle: number)
		local motor = motors[name]
		if motor then
			motor.Transform = CFrame.Angles(angle, 0, 0)
		end
	end
	set("LeftHip", swing)
	set("RightHip", -swing)
	set("LeftShoulder", -swing)
	set("RightShoulder", swing)

	local look = model:GetAttribute("Look") or 0
	figure.look += (look - figure.look) * math.min(1, dt * 6)
	local neck = motors.Neck
	if neck then
		neck.Transform = CFrame.Angles(0, figure.look * HEAD_TURN, 0)
	end
end

function PedestrianAnimator.start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Town"):WaitForChild("Pedestrians")
		RunService.RenderStepped:Connect(function(dt)
			for _, model in folder:GetChildren() do
				if model:IsA("Model") then
					local figure = figureFor(model)
					if figure then
						animate(model, figure, dt)
					end
				end
			end
		end)
	end)
end

return PedestrianAnimator
