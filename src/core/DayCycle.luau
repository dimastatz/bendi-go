--!strict
-- The time of day in Bendi Go (PRD-007). A whole day takes CYCLE_SECONDS, and it's worked out from the server's
-- clock, so every player sees the same sky and the same lights at the same moment.
-- Most of the cycle is daytime. The evening and night are short, and never so dark that the road is hard to see.

local DayCycle = {}

DayCycle.CYCLE_SECONDS = 20 * 60

-- Parts tagged with this are lights that turn on in the dark: street lamps, headlights, lit windows. Each has a
-- "LitColor" attribute, the color it glows when on.
DayCycle.LIGHT_TAG = "BendiNightLight"
DayCycle.LIT_COLOR = "LitColor"

-- How dark it is (from 0 to 1) before the lights turn on.
DayCycle.LIGHTS_ON = 0.25

-- Points in the cycle (from 0 to 1) and the clock time there, in hours. Clock times past 24 are the next morning.
local KEYFRAMES = {
	{ at = 0, hour = 7 }, -- morning
	{ at = 0.55, hour = 17 }, -- a long day, 11 minutes
	{ at = 0.65, hour = 19.5 }, -- sunset, 2 minutes
	{ at = 0.85, hour = 28.5 }, -- the night, 4 minutes, until 4:30 in the morning
	{ at = 1, hour = 31 }, -- sunrise, 3 minutes, back to 7:00
}

-- When it gets dark in the evening and light in the morning, in hours.
local DUSK_START, DUSK_END = 17.5, 19.5
local DAWN_START, DAWN_END = 4.5, 6.5

-- The clock time (from 0 up to 24 hours) at server time `now`, in seconds.
function DayCycle.clockAt(now: number): number
	local progress = (now % DayCycle.CYCLE_SECONDS) / DayCycle.CYCLE_SECONDS
	for i = 1, #KEYFRAMES - 1 do
		local from, to = KEYFRAMES[i], KEYFRAMES[i + 1]
		if progress <= to.at then
			local t = (progress - from.at) / (to.at - from.at)
			return (from.hour + (to.hour - from.hour) * t) % 24
		end
	end
	return KEYFRAMES[1].hour
end

-- How dark it is at clock time `hour`: 0 in the day, 1 at night, and in between at dusk and dawn.
function DayCycle.darkness(hour: number): number
	if hour >= DUSK_END or hour <= DAWN_START then
		return 1
	elseif hour > DUSK_START then
		return (hour - DUSK_START) / (DUSK_END - DUSK_START)
	elseif hour < DAWN_END then
		return 1 - (hour - DAWN_START) / (DAWN_END - DAWN_START)
	end
	return 0
end

-- True if lights should be on at clock time `hour`.
function DayCycle.lightsOn(hour: number): boolean
	return DayCycle.darkness(hour) >= DayCycle.LIGHTS_ON
end

return DayCycle
