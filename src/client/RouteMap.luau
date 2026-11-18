-- A small map of the town's streets with a session's route drawn on it. Used by the mini-map while driving
-- (LessonGuide) and by the goal card before a session starts (SessionCards).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = ReplicatedStorage:WaitForChild("Core")
local TownLayout = require(Core:WaitForChild("TownLayout"))

local RouteMap = {}

export type Map = {
	frame: Frame,
	routeLayer: Frame,
	toMap: (x: number, z: number) -> Vector2,
}

local PADDING = 8
local GRASS = Color3.fromRGB(110, 165, 95)
local STREET_COLOR = Color3.fromRGB(150, 155, 160)
RouteMap.ROUTE_COLOR = Color3.fromRGB(40, 170, 255)

-- The edges of the town's roads, which the map shows.
local HALF_ROAD = TownLayout.ROAD_WIDTH / 2
local MIN_X = TownLayout.STREETS_X[1] - HALF_ROAD
local MAX_X = TownLayout.STREETS_X[#TownLayout.STREETS_X] + HALF_ROAD
local MIN_Z = TownLayout.STREETS_Z[1] - HALF_ROAD
local MAX_Z = TownLayout.STREETS_Z[#TownLayout.STREETS_Z] + HALF_ROAD

function RouteMap.rounded(frame: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = frame
end

-- A straight line on the map, along a street.
local function line(
	map: Map,
	parent: Instance,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	width: number,
	color: Color3
)
	local a, b = map.toMap(x1, z1), map.toMap(x2, z2)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	frame.Size = UDim2.fromOffset(math.abs(b.X - a.X) + width, math.abs(b.Y - a.Y) + width)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
end

-- A round marker on the map, like the car or the next checkpoint.
function RouteMap.dot(map: Map, name: string, size: number, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = color
	frame.ZIndex = 3
	frame.Parent = map.frame
	RouteMap.rounded(frame, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(30, 30, 35)
	stroke.Thickness = 2
	stroke.Parent = frame
	return frame
end

-- Makes a `width` by `height` map of the town's streets in `parent`.
function RouteMap.new(parent: Instance, width: number, height: number): Map
	local scale = math.min((width - 2 * PADDING) / (MAX_X - MIN_X), (height - 2 * PADDING) / (MAX_Z - MIN_Z))
	local frame = Instance.new("Frame")
	frame.Name = "Map"
	frame.Size = UDim2.fromOffset(width, height)
	frame.BackgroundColor3 = GRASS
	frame.ClipsDescendants = true
	frame.Parent = parent
	RouteMap.rounded(frame, UDim.new(0, 12))

	local routeLayer = Instance.new("Frame")
	routeLayer.Name = "Route"
	routeLayer.Size = UDim2.fromScale(1, 1)
	routeLayer.BackgroundTransparency = 1
	routeLayer.ZIndex = 2
	routeLayer.Parent = frame

	local map: Map = {
		frame = frame,
		routeLayer = routeLayer,
		toMap = function(x: number, z: number): Vector2
			return Vector2.new(PADDING + (x - MIN_X) * scale, PADDING + (z - MIN_Z) * scale)
		end,
	}
	local first, last = TownLayout.STREETS_Z[1], TownLayout.STREETS_Z[#TownLayout.STREETS_Z]
	for _, x in TownLayout.STREETS_X do
		line(map, frame, x, first, x, last, 3, STREET_COLOR)
	end
	first, last = TownLayout.STREETS_X[1], TownLayout.STREETS_X[#TownLayout.STREETS_X]
	for _, z in TownLayout.STREETS_Z do
		line(map, frame, first, z, last, z, 3, STREET_COLOR)
	end
	return map
end

-- Draws the route through `nodes` (each { x, z }), or clears it when `nodes` is nil.
function RouteMap.drawRoute(map: Map, nodes: { { number } }?)
	map.routeLayer:ClearAllChildren()
	if not nodes then
		return
	end
	for index = 1, #nodes - 1 do
		local a, b = nodes[index], nodes[index + 1]
		line(map, map.routeLayer, a[1], a[2], b[1], b[2], 4, RouteMap.ROUTE_COLOR)
	end
end

return RouteMap
