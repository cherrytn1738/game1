# Training Ground 5 of World 4, Snow Globe (opened by Cosmic Rift's pass): a batting cage sealed inside
# a giant snow globe. The standard cage in candy red and white under a glass dome (cut open at the
# door) on a turned wooden base with a gold band, snowdrifts round the inside edge, little pine trees
# and a snowman in the corners, and snow on the cage roof. TrainingCageStyles adds the drifting snow,
# and the client swirls snow round the cage after each practice hit (TrainingConfig practiceHitEffect).
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py (through
# tiny_cage_helpers.py); the mesh names are what TrainingCageStyles looks up.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\tiny_cage_helpers.py", encoding="utf-8").read())

COLLECTION = "SnowGlobeCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\SnowGlobeCage.fbx"
SNOW = (0.97, 0.98, 1.0)
GLASS4 = (0.8, 0.9, 1.0)
WALNUT = (0.42, 0.26, 0.15)
GOLD4 = (1.0, 0.78, 0.25)
PINE_GREEN = (0.15, 0.45, 0.3)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = standard(coll, "Globe", ("frame", "pads", "nets", "machine", "screen", "plate", "lights"))
    glass, base, band, snow, pines, snowman, carrot = (bmesh.new() for _ in range(7))
    cx, cy = (LEFT_X + RIGHT_X) / 2, (BACK_Y + FRONT_Y) / 2
    rx, ry, rz, p = 19.6, 29.0, 22.0, 6.0
    door_x = ((DOOR[0] + DOOR[1]) / 2, (DOOR[1] - DOOR[0]) / 2 + 0.8)

    def edge_y(x):
        """The base outline's back edge (a superellipse) at x."""
        return cy - ry * max(0.0, 1 - abs((x - cx) / rx) ** p) ** (1 / p)
    # The dome: a rounded-square superellipsoid (it has to clear the cage's corners), with a doorway
    # cut through it at the cage door.
    rings, segments = 18, 80
    grid = []
    for i in range(rings + 1):
        v = (math.pi / 2) * i / rings
        h = math.cos(v) ** 0.5
        row = []
        for k in range(segments):
            u = 2 * math.pi * k / segments
            c, s = math.cos(u), math.sin(u)
            row.append(Vector((cx + rx * h * math.copysign(abs(c) ** (2 / p), c), cy + ry * h * math.copysign(abs(s) ** (2 / p), s),
                               1.6 + rz * math.sin(v))))
        grid.append(row)

    def in_door(p):
        return abs(p.x - door_x[0]) < door_x[1] and p.z < DOOR[2] + 1.0 and p.y < cy
    for i in range(rings):
        for k in range(segments):
            j = (k + 1) % segments
            quad = [grid[i][k], grid[i][j], grid[i + 1][j], grid[i + 1][k]]
            if any(in_door(p) for p in quad):
                continue
            outer = [glass.verts.new(p) for p in quad]
            inner = [glass.verts.new(Vector((cx, cy, 1.6)) + (p - Vector((cx, cy, 1.6))) * 0.992) for p in quad]
            glass.faces.new(outer)
            glass.faces.new(list(reversed(inner)))
    # A doorway frame round the cut, in the base's wood.
    for x in (door_x[0] - door_x[1], door_x[0] + door_x[1]):
        y = edge_y(x)
        box(base, (x, y + 0.6, (DOOR[2] + 2.6) / 2), (0.9, 1.6, DOOR[2] + 2.6))
    y_mid = edge_y(door_x[0])
    box(base, (door_x[0], y_mid + 0.6, DOOR[2] + 2.4), (2 * door_x[1] + 0.9, 1.6, 0.8))
    # The turned wooden base ring under the dome, open at the door, with a gold band.
    # Open from x of about -14.8 to -5.2 (angles on the superellipse).
    path = squircle_points(cx, cy, rx, ry, -math.pi / 2 - 0.0098, -math.pi / 2 - 0.357 + 2 * math.pi, 170, p=p)
    profile_along(base, path, [(-0.6, 0.0), (1.8, 0.0), (1.8, 1.0), (1.2, 1.6), (-0.6, 1.8)])
    profile_along(band, path, [(1.75, 0.35), (1.95, 0.35), (1.95, 0.75), (1.75, 0.75)])
    # Snowdrifts round the inside edge, pines and a snowman in the corners, snow on the cage roof.
    rng = random.Random(14)
    for k in range(26):
        p = path[(k * 6 + 3) % len(path)]
        d = (Vector((cx, cy, 0)) - p).normalized()
        blob(snow, p + d * 2.2, Vector((rng.uniform(1.8, 2.8), rng.uniform(1.8, 2.8), rng.uniform(0.8, 1.5))), subdivisions=2,
             lump=0.15, seed=k, floor=0.0)
    for x, y, height in ((LEFT_X - 1.6, FRONT_Y - 2.0, 6.5), (LEFT_X - 2.0, FRONT_Y - 7.0, 4.8), (RIGHT_X + 1.4, FRONT_Y - 3.0, 6.0),
                         (RIGHT_X + 1.8, 2.0, 5.2), (LEFT_X - 1.4, 8.0, 5.6)):
        pine(pines, (x, y, 0.4), height, 1.6)
        tube(snowman, (x, y, 0.0), (x, y, 0.9), 0.35, 8)
    sx, sy = RIGHT_X + 1.6, FRONT_Y - 9.0
    for z, r in ((1.4, 1.5), (3.6, 1.1), (5.2, 0.75)):
        ball(snow, (sx, sy, z), r, subdivisions=2)
    lathe(carrot, [(0, 0), (0.18, 0), (0, 0.9)], 8, transform=Matrix.Translation((sx - 0.7, sy, 5.2)) @ Matrix.Rotation(-math.pi / 2, 4, "Y"))
    for dz in (0.2, -0.2):
        ball(snowman, (sx - 0.66, sy + 0.25 * (1 if dz > 0 else -1), 5.45), 0.1, subdivisions=1)
    lathe(snowman, [(0, 5.85), (0.9, 5.85), (0.9, 6.0), (0.6, 6.0), (0.6, 7.0), (0, 7.0)], 12, transform=Matrix.Translation((sx, sy, 0)))
    for y in (BACK_Y + 6.0, (BACK_Y + FRONT_Y) / 2, FRONT_Y - 6.0):
        blob(snow, Vector((cx, y, HEIGHT + 0.1)), Vector((8.0, 4.0, 0.5)), subdivisions=2, lump=0.2, seed=y, floor=HEIGHT - 0.1)
    objects += finish_all(coll, [
        ("GlobeGlass", glass, GLASS4, "soft"), ("GlobeBase", base, WALNUT, "hard"), ("GlobeBand", band, GOLD4, "hard"),
        ("GlobeSnow", snow, SNOW, "smooth"), ("GlobePines", pines, PINE_GREEN, "hard"), ("GlobeSnowman", snowman, (0.08, 0.08, 0.1), "smooth"),
        ("GlobeCarrot", carrot, (1.0, 0.5, 0.1), "smooth")])
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
