# Training Ground 4 of World 4, Toy Soldier Fort: a batting cage inside a wooden toy fort. The standard
# cage in navy and red inside crenellated wooden walls with a gate at the door, a round tower with a
# cone roof and flag at each corner, and a wind-up toy soldier as the pitcher: red coat, white
# cross-belts, gold buttons and epaulettes, a tall black busby, one arm held out with the ball, and a
# brass wind-up key in his back that turns.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py (through
# tiny_cage_helpers.py); the mesh names are what TrainingCageStyles looks up. The key is its own
# mesh, centred on its axle (Blender +Y).
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\tiny_cage_helpers.py", encoding="utf-8").read())

COLLECTION = "ToySoldierCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\ToySoldierCage.fbx"
NAVY = (0.12, 0.18, 0.42)
COAT = (0.85, 0.12, 0.12)
GOLD4 = (1.0, 0.78, 0.25)
SKIN = (1.0, 0.82, 0.68)
BLACK = (0.06, 0.06, 0.07)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = standard(coll, "Fort", ("frame", "pads", "nets", "screen", "plate", "lights"))
    walls, towers, roofs, flags, coat, pants, hat, skin, trim, belts, key = (bmesh.new() for _ in range(11))
    # The fort walls round the cage, with battlements, and a gate (two posts and a lintel) at the door.
    x0, x1, y0, y1, h, t = LEFT_X - 2.4, RIGHT_X + 2.4, BACK_Y - 2.0, FRONT_Y + 2.0, 5.0, 1.0
    gate = (DOOR[0] - 0.8, DOOR[1] + 0.8)
    runs = [((x0, y1), (x1, y1)), ((x0, y0), (x0, y1)), ((x1, y0), (x1, y1)), ((x0, y0), (gate[0], y0)), ((gate[1], y0), (x1, y0))]
    for (ax, ay), (bx, by) in runs:
        length = math.hypot(bx - ax, by - ay)
        angle = math.atan2(by - ay, bx - ax)
        box(walls, ((ax + bx) / 2, (ay + by) / 2, h / 2), (length, t, h), Matrix.Rotation(angle, 4, "Z"))
        crenellations(walls, (ax, ay, 0), (bx, by, 0), h, t)
    for x in gate:
        box(walls, (x, y0, (h + 3.4) / 2), (1.4, 1.4, h + 3.4))
    box(walls, ((gate[0] + gate[1]) / 2, y0, h + 2.9), (gate[1] - gate[0] + 1.4, 1.4, 1.0))
    # Corner towers with cone roofs and pennants.
    for k, (x, y) in enumerate(((x0, y0), (x1, y0), (x0, y1), (x1, y1))):
        lathe(towers, [(0, 0), (2.2, 0), (2.2, 8.0), (2.6, 8.0), (2.6, 8.8), (0, 8.8)], 16, transform=Matrix.Translation((x, y, 0)))
        lathe(roofs, [(0, 8.8), (2.8, 8.8), (0, 13.2)], 16, transform=Matrix.Translation((x, y, 0)))
        tube(towers, (x, y, 13.0), (x, y, 15.6), 0.1, 6)
        flag = [Vector((x, y, 15.5)), Vector((x + 1.9, y, 15.0)), Vector((x, y, 14.4))]
        for side in (-0.04, 0.04):
            verts = [flags.verts.new(p + Vector((0, side, 0))) for p in flag]
            flags.faces.new(verts if side > 0 else list(reversed(verts)))
    # The wind-up soldier, standing behind the ball exit, facing the batter (-Y).
    sx, sy = PITCH.x, PITCH.y + 2.6
    for side in (-1, 1):
        lathe(pants, [(0, 0), (0.55, 0), (0.5, 2.6), (0, 2.6)], 12, transform=Matrix.Translation((sx + side * 0.55, sy, 0.3)))
        box(hat, (sx + side * 0.55, sy - 0.25, 0.25), (0.8, 1.4, 0.5))
    lathe(coat, [(0, 2.6), (1.15, 2.6), (1.25, 3.2), (1.1, 5.2), (0.6, 5.6), (0, 5.6)], 16, transform=Matrix.Translation((sx, sy, 0.3)))
    for side in (-1, 1):
        tube(belts, (sx + side * 0.95, sy - 0.98, 5.4), (sx - side * 0.95, sy - 1.0, 3.2), 0.14, 6)
        lathe(trim, [(0, 0), (0.45, 0), (0.45, 0.18), (0, 0.22)], 10, transform=Matrix.Translation((sx + side * 1.2, sy, 5.85)))
    for z in (3.4, 4.0, 4.6, 5.2):
        ball(trim, (sx, sy - 1.12, z + 0.3), 0.12, subdivisions=1)
    # Arms: the right one held out toward the batter with the ball at the exit, the left at his side.
    tube(coat, (sx + 1.15, sy, 5.5), (sx + 1.15, sy - 1.4, 4.0), 0.34, 10)
    tube(coat, (sx + 1.15, sy - 1.4, 4.0), (PITCH.x + 0.5, PITCH.y + 0.4, PITCH.z + 0.6), 0.3, 10)
    ball(skin, (PITCH.x + 0.4, PITCH.y + 0.25, PITCH.z + 0.45), 0.35, subdivisions=2)
    tube(coat, (sx - 1.15, sy, 5.5), (sx - 1.35, sy, 3.6), 0.32, 10)
    ball(skin, (sx - 1.38, sy, 3.35), 0.32, subdivisions=2)
    # Head, rosy cheeks, the chin strap and a tall busby with a gold badge.
    ball(skin, (sx, sy, 6.65), 0.95, subdivisions=3)
    for side in (-1, 1):
        ball(belts, (sx + side * 0.32, sy - 0.84, 6.8), 0.1, subdivisions=1)
        ball(trim, (sx + side * 0.55, sy - 0.7, 6.4), 0.16, subdivisions=1)
    lathe(hat, [(0, 7.2), (1.0, 7.2), (1.1, 8.6), (0.95, 9.4), (0, 9.5)], 16, transform=Matrix.Translation((sx, sy, 0)))
    lathe(trim, [(0, -0.05), (0.32, -0.05), (0.32, 0.05), (0, 0.05)], 12,
          transform=Matrix.Translation((sx, sy - 1.04, 8.0)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    # The wind-up key in his back: a shaft along +Y and a figure-eight bow, centred on its axle.
    axle = Vector((sx, sy + 1.0, 4.4))
    tube(key, axle, axle + Vector((0, 1.4, 0)), 0.18, 8)
    for side in (-1, 1):
        torus(key, axle + Vector((side * 0.8, 1.6, 0)), (0, 1, 0), 0.65, 0.16, segments=16, minor_segments=6)
    tube(key, axle + Vector((0, 0.0, 0)), axle + Vector((0, -0.6, 0)), 0.18, 8)
    objects += finish_all(coll, [
        ("FortWalls", walls, TOY_WOOD, "hard"), ("FortTowers", towers, TOY_BLUE, "smooth"), ("FortRoofs", roofs, COAT, "smooth"),
        ("FortFlags", flags, TOY_YELLOW, "soft"), ("SoldierCoat", coat, COAT, "smooth"), ("SoldierPants", pants, NAVY, "smooth"),
        ("SoldierHat", hat, BLACK, "smooth"), ("SoldierSkin", skin, SKIN, "smooth"), ("SoldierTrim", trim, GOLD4, "smooth"),
        ("SoldierBelts", belts, (0.98, 0.98, 0.98), "smooth"), ("SoldierKey", key, GOLD4, "smooth")])
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
