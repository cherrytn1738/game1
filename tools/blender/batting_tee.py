# The batting tee at each world's batting station: a rubber home-plate base with a white
# plate top and bolts, a steel lower tube with a brand band, a height-adjustment collar with a
# T-knob, a ribbed rubber upper tube and a flared rubber cup.
# Run inside Blender (e.g. via MCP). Units are studs with the origin on the ground under the
# stem; +Y points down the field (Roblox -Z), +Z is up. The cup lip sits at z = 3.0, the
# station's BallPosition, so the ball rests in it. Exported at full scale (FieldBuilder
# places it at scale 1); the mesh names are what FieldBuilder styles.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

EXPORT_SCALE = 1.0
COLLECTION = "BattingTee"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\BattingTee.fbx"
CUP_LIP = 3.0


def plate_outline(width, inset=0.0):
    """Home plate, its point toward the batter end (-Y), centred on the stem."""
    s = width / 2 - inset
    return [(s, s * 0.5), (-s, s * 0.5), (-s, -s * 0.5), (0, -s * 1.5), (s, -s * 0.5)]


def build(coll):
    base, plate, metal, accent, rubber = (bmesh.new() for _ in range(5))
    prism(base, plate_outline(2.6), 0.0, 0.3)
    prism(plate, plate_outline(2.6, inset=0.18), 0.3, 0.34)
    for x, y in plate_outline(2.6, inset=0.42):
        lathe(metal, [(0, 0.3), (0.08, 0.3), (0.07, 0.34), (0.04, 0.37), (0, 0.38)], 10, transform=Matrix.Translation((x, y, 0)))
    # Steel lower tube rising out of a flanged socket, with a brand band.
    lathe(metal, [(0, 0.3), (0.3, 0.3), (0.3, 0.38), (0.2, 0.46), (0.17, 0.5), (0.16, 1.95), (0, 1.95)], 20)
    lathe(accent, [(0.165, 0.95), (0.172, 0.97), (0.172, 1.23), (0.165, 1.25)], 20)
    # Height-adjustment collar and its T-knob.
    lathe(metal, [(0.15, 1.82), (0.25, 1.84), (0.27, 1.9), (0.27, 2.1), (0.25, 2.16), (0.13, 2.18)], 20)
    cylinder(metal, (0.26, 0, 2.0), (1, 0, 0), 0.32, 0.05, segments=8)
    cylinder(accent, (0.58, -0.17, 2.0), (0, 1, 0), 0.34, 0.06, segments=10)
    for side in (-1, 1):
        ball(accent, (0.58, side * 0.17, 2.0), 0.07, subdivisions=1)
    # Ribbed rubber upper tube flaring into the cup that holds the ball.
    profile = [(0, 2.1), (0.12, 2.1)]
    for k in range(9):
        z = 2.18 + k * 0.07
        profile.append((0.12 if k % 2 == 0 else 0.135, z))
    profile += [(0.13, 2.82), (0.18, 2.9), (0.26, 2.97), (0.28, CUP_LIP), (0.24, CUP_LIP), (0.15, 2.93), (0, 2.92)]
    lathe(rubber, profile, 24)
    return [finish(coll, "TeeBase", base, (0.12, 0.12, 0.13), bevel_width=0.06),
            finish(coll, "TeePlate", plate, WHITE, bevel_width=0.015),
            finish(coll, "TeeMetal", metal, (0.72, 0.74, 0.78), hard=False),
            finish(coll, "TeeAccent", accent, (1.0, 0.45, 0.12), hard=False),
            finish(coll, "TeeRubber", rubber, (0.1, 0.1, 0.11), hard=False)]


def build_and_export(export=True):
    coll = begin(COLLECTION)
    return report_and_export(build(coll), EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
