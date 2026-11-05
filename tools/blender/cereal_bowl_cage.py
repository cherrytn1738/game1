# Training Ground 3 of World 4, Cereal Bowl Stadium: a batting cage at the bottom of a giant cereal
# bowl. The standard cage in breakfast colours inside a curved ceramic bowl wall (open at the door),
# with cereal loops floating on the milk round the edge and heaped on the rim, a giant spoon catapult
# as the pitching machine (cocked back, a ball in its bowl), and two cereal boxes standing like
# stadium light towers at the far end.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py (through
# tiny_cage_helpers.py); the mesh names are what TrainingCageStyles looks up.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\tiny_cage_helpers.py", encoding="utf-8").read())

COLLECTION = "CerealBowlCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\CerealBowlCage.fbx"
CERAMIC = (0.35, 0.6, 0.92)
MILK = (0.98, 0.97, 0.94)
CHROME4 = (0.85, 0.87, 0.92)
LOOP_COLOURS = ((1.0, 0.6, 0.2), (1.0, 0.35, 0.45), (0.95, 0.85, 0.3))


def loop(bm, center, normal, R=1.0, r=0.42):
    torus(bm, center, normal, R, r, segments=16, minor_segments=8)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = standard(coll, "Bowl", ("frame", "pads", "nets", "screen", "plate", "lights"))
    bowl, rim, milk, spoon, base, boxes, art = (bmesh.new() for _ in range(7))
    loops = [bmesh.new() for _ in range(3)]
    # The bowl wall: a rounded square (superellipse) round the cage, curving up and out to a rolled rim, open at the door.
    cx, cy, rx, ry = (LEFT_X + RIGHT_X) / 2, (BACK_Y + FRONT_Y) / 2, (RIGHT_X - LEFT_X) / 2 + 2.2, (FRONT_Y - BACK_Y) / 2 + 2.2
    # The door gap: from x of about -14 to -5.6 on the back side (angles on the superellipse).

    a0, a1 = -math.pi / 2 - 0.005, -math.pi / 2 - 0.34 + 2 * math.pi
    path = squircle_points(cx, cy, rx, ry, a0, a1, 160)
    # The path runs counter-clockwise, so "outward" (right of travel) points away from the centre.
    wall = [(0.0, 0.0), (0.9, 0.0), (2.4, 2.4), (3.1, 5.6), (2.6, 5.6), (1.9, 2.6), (0.4, 0.4)]
    profile_along(bowl, path, wall)
    profile_along(rim, path, [(2.85 + 0.42 * math.cos(a), 5.75 + 0.42 * math.sin(a)) for a in [2 * math.pi * k / 10 for k in range(10)]])
    # A shallow milk pool between the cage and the bowl wall.
    profile_along(milk, path, [(-1.2, 0.06), (1.0, 0.06), (1.0, 0.32), (-1.2, 0.32)])
    # Cereal loops floating on the milk and heaped along the rim.
    rng = random.Random(9)
    for k in range(34):
        p = path[(k * 7) % len(path)]
        t = (path[min((k * 7) % len(path) + 1, len(path) - 1)] - path[max((k * 7) % len(path) - 1, 0)]).normalized()
        out = Vector((t.y, -t.x, 0))
        if k % 2 == 0:
            c = p + out * rng.uniform(-0.6, 0.4) + Vector((0, 0, 0.45))
            n = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 1))
        else:
            c = p + out * rng.uniform(2.5, 3.1) + Vector((0, 0, 6.2))
            n = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 1))
        loop(loops[k % 3], c, n)
    # The spoon catapult: a wooden base and A-frame holding a chrome spoon on an axle, cocked back,
    # its bowl just behind the ball exit.
    pivot = Vector((PITCH.x, PITCH.y + 4.2, 1.6))
    box(base, (pivot.x, pivot.y + 0.6, 0.5), (4.6, 5.6, 1.0))
    for side in (-1, 1):
        tube(base, (pivot.x + side * 1.8, pivot.y - 1.2, 1.0), (pivot.x + side * 1.8, pivot.y, pivot.z + 0.9), 0.25, 8)
        tube(base, (pivot.x + side * 1.8, pivot.y + 1.6, 1.0), (pivot.x + side * 1.8, pivot.y, pivot.z + 0.9), 0.25, 8)
    tube(spoon, (pivot.x - 2.1, pivot.y, pivot.z + 0.9), (pivot.x + 2.1, pivot.y, pivot.z + 0.9), 0.22, 10)
    head = Vector((PITCH.x, PITCH.y + 0.4, PITCH.z - 0.2))
    tail = Vector((pivot.x, pivot.y + 4.6, 1.3))
    tube(spoon, tail, head + (tail - head).normalized() * 1.2, 0.3, 10, radius_end=0.22)
    blob(spoon, head + Vector((0, 0.1, -0.3)), Vector((1.3, 1.6, 0.45)), subdivisions=3,
         rotation=Matrix.Rotation(math.atan2(tail.z - head.z, tail.y - head.y), 3, "X"))
    ball(spoon, tail, 0.5, subdivisions=2)
    # Two cereal boxes at the far end, like stadium light towers, with a sun burst on each front.
    for x in (LEFT_X - 1.2, RIGHT_X - 0.8):
        box(boxes, (x, FRONT_Y + 5.0, 9.0), (4.2, 2.0, 18.0))
        lathe(art, [(0, 0), (1.5, 0), (1.5, 0.12), (0, 0.12)], 20,
              transform=Matrix.Translation((x, FRONT_Y + 3.95, 12.0)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
        box(art, (x, FRONT_Y + 3.95, 6.0), (3.2, 0.1, 2.2))
        box(art, (x, FRONT_Y + 3.95, 17.4), (3.6, 0.12, 0.8))
    objects += finish_all(coll, [
        ("BowlWall", bowl, CERAMIC, "smooth"), ("BowlRim", rim, (0.96, 0.97, 1.0), "smooth"), ("BowlMilk", milk, MILK, "smooth"),
        ("BowlLoopsA", loops[0], LOOP_COLOURS[0], "smooth"), ("BowlLoopsB", loops[1], LOOP_COLOURS[1], "smooth"),
        ("BowlLoopsC", loops[2], LOOP_COLOURS[2], "smooth"), ("BowlSpoon", spoon, CHROME4, "smooth"),
        ("BowlCatapult", base, TOY_WOOD, "hard"), ("BowlBoxes", boxes, (0.95, 0.45, 0.15), "hard"), ("BowlBoxArt", art, TOY_YELLOW, "hard")])
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
