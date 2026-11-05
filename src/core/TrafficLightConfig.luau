--!strict
-- Every traffic light setting in one place (PRD-002, requirement 3), so timing can be tuned after playtesting.
-- Times are in seconds.

local TrafficLightConfig = {}

-- One step of the light, for one direction of traffic. Israeli lights go:
-- red and yellow -> green -> flashing green -> yellow -> red.
TrafficLightConfig.RED_YELLOW = 2
TrafficLightConfig.GREEN = 15
TrafficLightConfig.FLASHING_GREEN = 3
TrafficLightConfig.YELLOW = 3
-- Both directions stay red for this long between turns, so the crossing is empty before the other side goes.
TrafficLightConfig.ALL_RED = 2

-- A flashing green light is on for this long, then off for this long.
TrafficLightConfig.FLASH_INTERVAL = 0.5

-- The same light can give the same player a star at most this often (requirement 5).
TrafficLightConfig.STAR_COOLDOWN = 60

-- How far before the middle of the crossing the white stop line is painted, in studs. It leaves room for the
-- crosswalk that PRD-004 adds between the stop line and the crossing.
TrafficLightConfig.STOP_LINE_DISTANCE = 31

-- The crossings with traffic lights. `offset` shifts each light's cycle so neighboring lights don't all change
-- at once. The four-way crossing at (180, -90) is left without lights for the stop signs in PRD-005.
TrafficLightConfig.CROSSINGS = {
	{ x = -180, z = -90, offset = 0 },
	{ x = -180, z = 90, offset = 12 },
	{ x = 0, z = -90, offset = 24 },
	{ x = 0, z = 90, offset = 36 },
}

return TrafficLightConfig
