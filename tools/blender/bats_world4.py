# World 4's (Tiny Town) bat, the Rolling Pin Bat, exported as assets/models/BatsWorld4.fbx.
# Run inside Blender via MCP:
#   EXPORT = False   # optional: skip the export while iterating
#   exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\bats_world4.py", encoding="utf-8").read())
# bats.py's conventions and helpers, without rebuilding (or re-exporting) the ten earlier bats: the
# hand (Tool Handle) is at the origin and the bat runs up +Z (knob -0.52..-0.40, grip -0.40..0.50,
# barrel 0.50..3.40); each mesh is named "<item id>__<Part>" with a "Grip" and a "Barrel". After the
# import the meshes are grouped into ServerStorage.RunwayAssets.DisplayItems.rolling_pin_bat
# (tools/studio/group_item_imports.luau), and BatStyles colours each part by name.
BATS_SCRIPT = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\bats.py"
_bats_source = open(BATS_SCRIPT, encoding="utf-8").read()
_helpers, _, _rest = _bats_source.partition("def wood_bat(add):")
assert _rest, "bats.py layout changed; update bats_world4.py"
exec(_helpers)

COLLECTION = "BatsWorld4"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\BatsWorld4.fbx"
import random


def rolling_pin_bat(add):
    """A baker's rolling pin: a straight, round-ended wooden roller with red turned handles at
    both ends (the hand holds one, the other pokes out past the tip), red rings where the handles
    meet the roller, and a dusting of flour."""
    b, g, k, bands, tip, flour = (bmesh.new() for _ in range(6))
    radius = 0.17
    roller = [(0.09, 0.5), (0.13, 0.54), (radius, 0.62), (radius, 3.0), (0.13, 3.08), (0.09, 3.12), (0.0, 3.12)]
    lathe(b, [(0, 0.5)] + roller, SEGMENTS)
    for z in (0.56, 3.06):
        torus(bands, (0, 0, z), (0, 0, 1), 0.12, 0.03, segments=20, minor_segments=6)
    # The tip handle: a turned red handle with a bead, past the roller's end.
    lathe(tip, [(0, 3.1), (0.07, 3.1), (0.065, 3.3), (0.085, 3.42), (0.08, 3.6), (0.1, 3.68), (0.06, 3.76), (0, 3.78)], 16)
    # The grip is the bottom handle (turned, with two beads).
    lathe(g, [(0, -0.41), (0.085, -0.41), (0.09, -0.2), (0.1, -0.1), (0.085, 0.0), (0.09, 0.3), (0.1, 0.4), (0.075, 0.5),
              (0, 0.5)], 16)
    knob(k)
    rng = random.Random(12)
    for _ in range(26):
        z = rng.uniform(0.75, 2.9)
        a = rng.uniform(0, 2 * math.pi)
        point = Vector((math.cos(a) * radius * 0.99, math.sin(a) * radius * 0.99, z))
        ball(flour, point, rng.uniform(0.02, 0.045), subdivisions=1)
    add("Barrel", b), add("Grip", g), add("Knob", k), add("Bands", bands), add("TipHandle", tip), add("Flour", flour)


COLOURS = {"rolling_pin_bat": {"Barrel": (0.87, 0.7, 0.48), "Grip": (0.8, 0.2, 0.18), "Knob": (0.8, 0.2, 0.18),
                               "Bands": (0.8, 0.2, 0.18), "TipHandle": (0.8, 0.2, 0.18), "Flour": (0.98, 0.98, 0.96)}}
BATS = ["rolling_pin_bat"]
_tail = _rest.partition("\nBATS = [")[2].partition("\n\n")[2]   # build() and export(), as in bats.py
exec(_tail.partition("\nobjects = build(")[0])

objects = build(begin(COLLECTION))
if globals().get("EXPORT", True):
    export(objects, EXPORT_PATH)
