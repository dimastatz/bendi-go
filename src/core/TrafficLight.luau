--!strict
-- What a traffic light shows at any moment (PRD-002, requirement 2). Every light runs on the shared game clock,
-- so the server and every client can work out the same light from the time alone.
-- East-west traffic (streets along X) and north-south traffic (streets along Z) take turns: one side goes
-- through red and yellow, green, flashing green, and yellow while the other side waits at red.

local Config = require("./TrafficLightConfig")

export type LightState = "red" | "redYellow" | "green" | "flashingGreen" | "yellow"
export type Lamps = { red: boolean, yellow: boolean, green: boolean }

local TrafficLight = {}

-- One side's turn: from its red and yellow until both sides are red again.
local function turnLength(): number
	return Config.RED_YELLOW + Config.GREEN + Config.FLASHING_GREEN + Config.YELLOW + Config.ALL_RED
end

-- How long one full cycle takes, with both sides having a turn.
function TrafficLight.cycleLength(): number
	return 2 * turnLength()
end

-- What the light facing traffic along X (`alongX` true) or along Z shows at `time`, and how many seconds it has
-- shown it. `offset` shifts the cycle of one crossing.
function TrafficLight.stateAt(time: number, alongX: boolean, offset: number): (LightState, number)
	-- East-west traffic takes the first turn of the cycle, north-south traffic the second.
	local start = if alongX then 0 else turnLength()
	local t = (time + offset - start) % TrafficLight.cycleLength()

	local steps: { { state: LightState, length: number } } = {
		{ state = "redYellow", length = Config.RED_YELLOW },
		{ state = "green", length = Config.GREEN },
		{ state = "flashingGreen", length = Config.FLASHING_GREEN },
		{ state = "yellow", length = Config.YELLOW },
	}
	for _, step in steps do
		if t < step.length then
			return step.state, t
		end
		t -= step.length
	end
	return "red", t
end

-- Which of the three lamps are lit at `time`. A flashing green lamp blinks on and off.
function TrafficLight.lampsAt(time: number, alongX: boolean, offset: number): Lamps
	local state, elapsed = TrafficLight.stateAt(time, alongX, offset)
	local flashOn = math.floor(elapsed / Config.FLASH_INTERVAL) % 2 == 0
	return {
		red = state == "red" or state == "redYellow",
		yellow = state == "yellow" or state == "redYellow",
		green = state == "green" or (state == "flashingGreen" and flashOn),
	}
end

-- True for the lights that mean "don't go": red, and red and yellow together.
function TrafficLight.isStop(state: LightState): boolean
	return state == "red" or state == "redYellow"
end

-- True for the lights that mean "go": green and flashing green.
function TrafficLight.isGo(state: LightState): boolean
	return state == "green" or state == "flashingGreen"
end

return TrafficLight
