-- Speed limit signs and school zone markings (PRD-003, requirement 4).
-- Every street segment gets an Israeli speed limit sign (red ring, black number) at its start, on the right side of
-- the road, for each direction of traffic. The school street also gets a "school ahead" warning triangle and a
-- big "30" painted in each lane.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Approach = require(ReplicatedStorage.Core.Approach)
local SpeedZones = require(ReplicatedStorage.Core.SpeedZones)
local TownLayout = require(ReplicatedStorage.Core.TownLayout)

local SignBuilder = require(script.Parent.SignBuilder)

local SpeedSigns = {}

local SIDEWALK_TOP = 0.5
local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local SIGN_DISTANCE = 8 -- how far into the segment the sign stands
local SIGN_OFFSET = 3 -- how far past the curb
local POLE_HEIGHT = 10
local DISC_SIZE = 4.2 -- bigger than a real sign, so kids notice it
local MARKING_DISTANCE = 22

local function buildSign(parent: Instance, segment: TownLayout.Street, direction: number)
	local first, last = TownLayout.segmentEnds(segment)
	local start = if direction > 0 then first else last
	local approach = { alongX = segment.alongX, direction = direction, at = segment.at, line = 0 }
	local limit, kind = SpeedZones.forSegment(segment)

	local model = Instance.new("Model")
	model.Name = `SpeedSign{limit}`

	local x, z = Approach.point(approach, start + direction * SIGN_DISTANCE, HALF_ROAD + SIGN_OFFSET)
	local foot = Vector3.new(x, SIDEWALK_TOP, z)
	-- The sign faces the drivers coming toward it.
	local facing = if segment.alongX then Vector3.new(-direction, 0, 0) else Vector3.new(0, 0, -direction)
	SignBuilder.pole(model, foot, POLE_HEIGHT)

	local disc = CFrame.lookAt(foot, foot + facing) * CFrame.new(0, POLE_HEIGHT - DISC_SIZE / 2, 0)
	SignBuilder.disc(model, disc, DISC_SIZE, SignBuilder.RED, SignBuilder.WHITE, DISC_SIZE * 0.12)
	SignBuilder.label(model, disc, DISC_SIZE * 0.6, DISC_SIZE * 0.45, tostring(limit), SignBuilder.BLACK)

	if kind == "school" then
		-- "School ahead": a warning triangle with children crossing, below the limit.
		local warning = disc * CFrame.new(0, -DISC_SIZE / 2 - 2.2, 0)
		SignBuilder.triangle(model, warning, 3.8, false)
		SignBuilder.label(model, warning * CFrame.new(0, -0.35, 0), 1.6, 1.6, "🚸", SignBuilder.BLACK)

		-- A big "30" painted in the lane, readable by the drivers coming toward it.
		local markX, markZ = Approach.point(approach, start + direction * MARKING_DISTANCE, TownLayout.LANE_WIDTH / 2)
		local markPosition = Vector3.new(markX, 0.07, markZ)
		local driving = -facing
		local paint = Instance.new("Part")
		paint.Name = "RoadMarking"
		paint.Size = Vector3.new(8, 0.02, 10)
		paint.CFrame = CFrame.lookAt(markPosition, markPosition + driving)
		paint.Transparency = 1
		paint.Anchored = true
		paint.CanCollide = false
		paint.CanTouch = false
		paint.Parent = model
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.Parent = paint
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(245, 245, 245)
		label.Text = tostring(limit)
		label.Parent = gui
	end

	model.Parent = parent
end

function SpeedSigns.build(town: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "SpeedSigns"
	for _, segment in TownLayout.segments() do
		for _, direction in { 1, -1 } do
			buildSign(folder, segment, direction)
		end
	end
	folder.Parent = town
end

return SpeedSigns
