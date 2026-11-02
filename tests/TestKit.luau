--!strict
-- Minimal test helpers for specs run with the luau CLI.
-- A spec calls `test` for each case and `finish` at the end, which fails the run if any case failed.

local TestKit = {}

local failures = 0

function TestKit.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		print(`  ok    {name}`)
	else
		failures += 1
		print(`  FAIL  {name}\n        {err}`)
	end
end

function TestKit.expectEqual(actual: any, expected: any)
	if actual ~= expected then
		error(`expected {expected}, got {actual}`, 2)
	end
end

function TestKit.expectNear(actual: number, expected: number, tolerance: number?)
	local allowed = tolerance or 1e-9
	if math.abs(actual - expected) > allowed then
		error(`expected {expected} (within {allowed}), got {actual}`, 2)
	end
end

function TestKit.finish()
	local failed = failures
	failures = 0
	if failed > 0 then
		error(`{failed} test(s) failed`, 0)
	end
end

return TestKit
