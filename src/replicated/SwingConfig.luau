-- One visual timeline for batting, server contact, and the practice pitch.
-- These phases never determine launch strength or grant a gameplay reward.
local Swing = {
	Phases = {
		{name = "Load", duration = 0.10},
		{name = "Windup", duration = 0.14}, -- Brief coil at the top of the backswing.
		{name = "Plant", duration = 0.08},
		{name = "Turn", duration = 0.07},
		{name = "Release", duration = 0.06},
		{name = "Contact", duration = 0.05, marker = "Contact"},
		{name = "Extension", duration = 0.06},
		{name = "Follow", duration = 0.12},
		{name = "Settle", duration = 0.10},
		{name = "Recover", duration = 0.32},
	},
	Markers = {},
	ContactTime = 0,
	Duration = 0,
}

for _, phase in Swing.Phases do
	Swing.Duration += phase.duration
	if phase.marker then Swing.Markers[phase.marker] = Swing.Duration end
end
-- The practice pitch uses this marker time; the server launch leads it (below).
Swing.ContactTime = Swing.Markers.Contact
-- The server launches the ball this much before ContactTime (minus the batter's ping as
-- well), because clients draw server-moved parts about this far behind for smoothness. The
-- ball then visibly leaves the tee as the bat meets it. Timing only: launch strength and
-- direction are unchanged. MinimumLaunchDelay keeps the launch after the swing has begun.
Swing.LaunchVisualLead = 0.25
Swing.MinimumLaunchDelay = 0.1

-- Swing time when the bat's barrel meets the ball on the tee (measured in a playtest: closest
-- at 0.50 s, touching from about 0.49 s). The cinematics freeze the swing here.
Swing.BallContactTime = 0.492

-- Rare cinematic hits (LegendaryHitClient, MythicHitClient). The server rolls them when it
-- accepts a swing (Mythic first) and holds the launch HoldSeconds longer while the cinematic
-- plays. Presentation only: launch strength, distance and rewards are the same as any hit.
Swing.LegendaryHit = {Chance = 1 / 1000, HoldSeconds = 3.6}
Swing.MythicHit = {Chance = 1 / 10000, HoldSeconds = 5.5}

return Swing
