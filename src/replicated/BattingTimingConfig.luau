-- Seconds. The server and client share these tuning values.
local Timing = {
	-- Time for the marker to travel from one edge to the other.
	TravelDuration = 2.0,
	StartDelay = 0.25,
	PerfectWindow = 0.08,
	GoodWindow = 0.18,
	OkayWindow = 0.32,
	FlatLaunchAngleDegrees = 38,
	SteepLaunchAngleDegrees = 72,
	MaxHorizontalAngleDegrees = 32,
	MinimumPowerMultiplier = 0.86,
	-- Matches the existing 0.84-second swing; update if swing durations change.
	SwingCooldown = 0.84,
}

function Timing.GetPosition(now, startTime)
	local fullCycle = Timing.TravelDuration * 2
	local elapsed = (now - startTime) % fullCycle
	if elapsed <= Timing.TravelDuration then
		return elapsed / Timing.TravelDuration
	end
	return 2 - elapsed / Timing.TravelDuration
end

function Timing.GetOffset(now, startTime)
	-- The sign always matches the visible fan: left is negative, right is positive.
	return (Timing.GetPosition(now, startTime) - 0.5) * Timing.TravelDuration
end

-- Tee assistance widens all favorable windows without slowing the sweep.
function Timing.GetEffectiveOffset(offset, teeScale)
 return offset / math.max(1, teeScale or 1)
end

function Timing.GetWindows(teeScale)
 local scale = math.max(1, teeScale or 1)
 return {
  Perfect = Timing.PerfectWindow * scale,
  Good = Timing.GoodWindow * scale,
  Okay = Timing.OkayWindow * scale,
 }
end

function Timing.GetHorizontalAngleDegrees(offset)
	local edgeOffset = Timing.TravelDuration / 2
	local signedFraction = math.clamp(offset / edgeOffset, -1, 1)
	return signedFraction * Timing.MaxHorizontalAngleDegrees
end

function Timing.GetPowerMultiplier(offset)
	local edgeOffset = Timing.TravelDuration / 2
	local errorFraction = math.clamp(math.abs(offset) / edgeOffset, 0, 1)
	return 1 - errorFraction * (1 - Timing.MinimumPowerMultiplier)
end

function Timing.GetLaunchAngleDegrees(offset)
	local errorSeconds = math.abs(offset)
	local fraction = math.clamp(
		(errorSeconds - Timing.PerfectWindow) / (Timing.OkayWindow - Timing.PerfectWindow),
		0, 1
	)
	return Timing.FlatLaunchAngleDegrees
		+ fraction * (Timing.SteepLaunchAngleDegrees - Timing.FlatLaunchAngleDegrees)
end

function Timing.GetQuality(offset)
	local errorSeconds = math.abs(offset)
	if errorSeconds <= Timing.PerfectWindow then return "Perfect" end
	if errorSeconds <= Timing.GoodWindow then return "Good" end
	if errorSeconds <= Timing.OkayWindow then return "Okay" end
	-- Every accepted swing makes contact; outer timing uses the weakest quality.
	return "Okay"
end

return Timing
