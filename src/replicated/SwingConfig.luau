-- One visual timeline for batting, server contact, and the practice pitch.
-- These phases never determine launch strength or grant a gameplay reward.
local Swing = {
	Phases = {
		{name = "Load", duration = 0.10},
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
-- Existing server launch and practice pitch consume this same marker time.
Swing.ContactTime = Swing.Markers.Contact

return Swing
