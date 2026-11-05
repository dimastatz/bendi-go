--!strict
-- Shared pieces for the rules that watch a player's car and give stars and tips: what a rule is told about the
-- car, what it can report back, and a check for cars that jumped instead of driving.

local Units = require("./Units")

local RuleKit = {}

-- Where the car is, which way it faces (doesn't need to be a unit vector), and its speed in studs per second.
export type Car = { x: number, z: number, dirX: number, dirZ: number, speed: number }

-- A star for `key` (each key has its own cooldown) with an optional `praise` tip, or a tip on its own.
-- Tips and praise are keys in the Strings table.
export type Event = { kind: "star", key: string, praise: string? } | { kind: "tip", tip: string }

-- A car slower than this counts as stopped.
RuleKit.STOP_SPEED = Units.kmhToStudsPerSecond(1)

-- From a car's center to its front bumper.
RuleKit.CAR_HALF_LENGTH = 7

-- The car's front bumper, as a car of its own, so rules can check where the front of the car is.
function RuleKit.front(car: Car): Car
	local length = math.sqrt(car.dirX * car.dirX + car.dirZ * car.dirZ)
	if length < 1e-6 then
		return car
	end
	local reach = RuleKit.CAR_HALF_LENGTH / length
	return {
		x = car.x + car.dirX * reach,
		z = car.z + car.dirZ * reach,
		dirX = car.dirX,
		dirZ = car.dirZ,
		speed = car.speed,
	}
end

-- A car that moved farther than this between two checks was reset, not driven.
RuleKit.MAX_STEP = 40

function RuleKit.star(key: string, praise: string?): Event
	return { kind = "star", key = key, praise = praise }
end

function RuleKit.tip(tip: string): Event
	return { kind = "tip", tip = tip }
end

export type Tracker = { lastX: number?, lastZ: number? }

-- Remembers where the car is and returns true if it jumped there (for example with Reset car).
function RuleKit.jumped(tracker: Tracker, car: Car): boolean
	local lastX, lastZ = tracker.lastX, tracker.lastZ
	tracker.lastX, tracker.lastZ = car.x, car.z
	if not lastX or not lastZ then
		return false
	end
	return math.sqrt((car.x - lastX) ^ 2 + (car.z - lastZ) ^ 2) > RuleKit.MAX_STEP
end

return RuleKit
