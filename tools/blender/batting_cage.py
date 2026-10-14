# Training Grounds batting cage: steel hoop frame, strand netting, pitching machine,
# protective screen, home plate, ball bucket and two floodlights.
# Run inside Blender (e.g. via MCP). Layout, units and the 1/4-scale export come from
# cage_helpers.py. One mesh per recolorable role; the mesh names are what TrainingStadium looks up.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "TrainingCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\TrainingCage.fbx"

STEEL = (0.32, 0.34, 0.37)
NET = (0.06, 0.06, 0.07)
PAD = (0.75, 0.16, 0.14)
RUBBER = (0.08, 0.08, 0.09)
METAL = (0.7, 0.72, 0.75)


def build_frame(coll):
    bm, r = bmesh.new(), 1.0
    for y in HOOPS:
        points = [Vector((LEFT_X, y, z)) for z in (0.0, 4.0, 8.0, HEIGHT - 1 - r)]
        for i in range(7):
            a = math.pi - (math.pi / 2) * i / 6
            points.append(Vector((LEFT_X + r + r * math.cos(a), y, HEIGHT - 1 + r * math.sin(a) - r + 1)))
        points += [Vector((x, y, HEIGHT)) for x in (LEFT_X + 4, 3.0, RIGHT_X - 4)]
        for i in range(7):
            a = math.pi / 2 - (math.pi / 2) * i / 6
            points.append(Vector((RIGHT_X - r + r * math.cos(a), y, HEIGHT - 1 + r * math.sin(a) - r + 1)))
        points += [Vector((RIGHT_X, y, z)) for z in (HEIGHT - 1 - r, 8.0, 4.0, 0.0)]
        sweep(bm, points, 0.22, segments=12)
        for x in (LEFT_X, RIGHT_X):
            lathe(bm, [(0, 0), (0.55, 0), (0.55, 0.08), (0.3, 0.14), (0, 0.14)], 16,
                  transform=Matrix.Translation((x, y, 0)))
    for x, z in ((LEFT_X, HEIGHT - 1 - r), (RIGHT_X, HEIGHT - 1 - r), ((LEFT_X + RIGHT_X) / 2, HEIGHT)):
        tube(bm, (x, BACK_Y, z), (x, FRONT_Y, z), 0.17)
    for x in DOOR[:2]:
        tube(bm, (x, BACK_Y, 0.0), (x, BACK_Y, DOOR[2]), 0.17)
        lathe(bm, [(0, 0), (0.45, 0), (0.45, 0.08), (0.25, 0.14), (0, 0.14)], 16, transform=Matrix.Translation((x, BACK_Y, 0)))
    tube(bm, (DOOR[0], BACK_Y, DOOR[2]), (DOOR[1], BACK_Y, DOOR[2]), 0.17)
    return finish(coll, "CageFrame", bm, STEEL)


def build_pads(coll):
    bm = bmesh.new()
    profile = [(0, 0.1), (0.42, 0.1), (0.52, 0.22), (0.52, 4.3), (0.42, 4.45), (0, 4.45)]
    for y in HOOPS:
        for x in (LEFT_X, RIGHT_X):
            lathe(bm, profile, 16, transform=Matrix.Translation((x, y, 0)))
    return finish(coll, "CagePads", bm, PAD)


def build_nets(coll):
    spacing, width, inset, top = 1.5, 0.12, 0.25, HEIGHT - 1.4
    length, span = FRONT_Y - BACK_Y - 2 * inset, RIGHT_X - LEFT_X - 2 * inset
    objects = []

    def wall(name, x, outward, hole):
        bm = bmesh.new()
        net_panel(bm, Vector((x - outward * inset, BACK_Y + inset, 0.05)), Vector((0, 1, 0)), Vector((0, 0, 1)),
                  length, top, Vector((outward, 0, 0)), spacing, width,
                  displace=lambda u, v: 0.3 * hoop_fraction(BACK_Y + inset + u) * math.sin(math.pi * min(1.0, v / top)),
                  hole=hole)
        return make_object(coll, name, bm, NET)

    objects.append(wall("NetLeft", LEFT_X, -1, lambda u, v: False))
    objects.append(wall("NetRight", RIGHT_X, 1, lambda u, v: False))

    bm = bmesh.new()
    net_panel(bm, Vector((LEFT_X + inset, BACK_Y + inset, HEIGHT - 0.35)), Vector((0, 1, 0)), Vector((1, 0, 0)),
              length, span, Vector((0, 0, 1)), spacing, width,
              displace=lambda u, v: -0.55 * hoop_fraction(BACK_Y + inset + u) * math.sin(math.pi * v / span))
    objects.append(make_object(coll, "NetRoof", bm, NET))

    door_hole = lambda u, v: DOOR[0] + 0.3 < LEFT_X + inset + u < DOOR[1] - 0.3 and v < DOOR[2] - 0.3
    for name, y, outward, hole in (("NetBack", BACK_Y, -1, door_hole), ("NetFront", FRONT_Y, 1, lambda u, v: False)):
        bm = bmesh.new()
        net_panel(bm, Vector((LEFT_X + inset, y - outward * inset, 0.05)), Vector((1, 0, 0)), Vector((0, 0, 1)),
                  span, top, Vector((0, outward, 0)), spacing, width,
                  displace=lambda u, v: 0.35 * math.sin(math.pi * u / span) * math.sin(math.pi * min(1.0, v / top)),
                  hole=hole)
        objects.append(make_object(coll, name, bm, NET))
    return objects


def build_machine(coll):
    body, tires, metal = bmesh.new(), bmesh.new(), bmesh.new()
    wheel_y, hub = PITCH.y + 0.4, Vector((PITCH.x, PITCH.y + 0.7, 1.15))
    for i in range(3):
        a = math.radians(90 + 120 * i)
        tube(metal, hub, hub + Vector((1.5 * math.cos(a), 1.5 * math.sin(a), -1.1)), 0.09, 8)
    tube(metal, hub + Vector((0, 0, -0.1)), (PITCH.x, wheel_y, 1.45), 0.16)
    # One side plate carries the motors; the other side stays open so the wheels show.
    box(body, (PITCH.x + 0.3, wheel_y, 3.0), (0.08, 1.5, 3.7))
    for dz in (-0.95, 0.95):
        center = Vector((PITCH.x, wheel_y, PITCH.z + dz))
        turn = Matrix.Translation(center) @ Matrix.Rotation(math.pi / 2, 4, "Y")
        tire = [(0.42, -0.14), (0.6, -0.14), (0.65, -0.07), (0.65, 0.07), (0.6, 0.14), (0.42, 0.14)]
        lathe(tires, tire + [tire[0]], 24, transform=turn)
        cylinder_x(metal, center, 0.22, 0.43, 20)
        cylinder_x(metal, center + Vector((0.2, 0, 0)), 0.3, 0.08, 8)
        cylinder_x(body, center + Vector((0.8, 0, 0)), 0.85, 0.36, 18)
        cylinder_x(metal, center + Vector((1.27, 0, 0)), 0.1, 0.28, 18)
    box(body, (PITCH.x, wheel_y + 0.1, 1.55), (0.7, 1.2, 0.2))
    sweep(metal, [Vector((PITCH.x, PITCH.y + 2.7, 5.55)), Vector((PITCH.x, PITCH.y + 2.0, 4.4)),
                  Vector((PITCH.x, PITCH.y + 1.4, 3.3)), Vector((PITCH.x, PITCH.y + 1.15, 3.02))], 0.36, segments=14)
    funnel = [(0.36, 0.0), (1.05, 0.95), (1.05, 1.05), (0.97, 1.05), (0.3, 0.06)]
    lathe(body, funnel + [funnel[0]], 24, transform=Matrix.Translation((PITCH.x, PITCH.y + 2.85, 5.45)))
    box(body, (PITCH.x - 0.75, PITCH.y + 0.9, 2.1), (0.5, 0.5, 0.6))
    return [finish(coll, "MachineBody", body, PAD, bevel_width=0.03),
            finish(coll, "MachineTires", tires, RUBBER, hard=False),
            finish(coll, "MachineMetal", metal, METAL)]


def build_screen(coll):
    frame, y = bmesh.new(), PITCH.y - 3.0
    x0, x1, h, w = PITCH.x - 3.5, PITCH.x + 3.5, 7.5, 0.95
    for x in (x0, x1):
        tube(frame, (x, y, 0.12), (x, y, h), 0.13)
        tube(frame, (x, y - 1.1, 0.12), (x, y + 1.1, 0.12), 0.11)
    tube(frame, (x0, y, h), (x1, y, h), 0.13)
    cx, cz = PITCH.x, PITCH.z
    for a, b in (((cx - w, cz - w), (cx + w, cz - w)), ((cx - w, cz + w), (cx + w, cz + w)),
                 ((cx - w, cz - w), (cx - w, cz + w)), ((cx + w, cz - w), (cx + w, cz + w))):
        tube(frame, (a[0], y, a[1]), (b[0], y, b[1]), 0.09)
    net = bmesh.new()
    net_panel(net, Vector((x0, y, 0.12)), Vector((1, 0, 0)), Vector((0, 0, 1)), x1 - x0, h - 0.12,
              Vector((0, 1, 0)), 0.5, 0.06, rope=0.0,
              hole=lambda u, v: abs(x0 + u - cx) < w - 0.05 and abs(0.12 + v - cz) < w - 0.05)
    return [finish(coll, "ScreenFrame", frame, PAD), make_object(coll, "ScreenNet", net, NET)]


def build_plate_bucket_balls(coll):
    plate = bmesh.new()
    s = 1.1
    outline = [(s, s * 0.5), (-s, s * 0.5), (-s, -s * 0.5), (0, -s * 1.5), (s, -s * 0.5)]
    prism(plate, [(x + PITCH.x, y) for x, y in outline], 0.0, 0.07)
    bucket, balls = bmesh.new(), bmesh.new()
    spot = Vector((PITCH.x + 3.8, PITCH.y - 1.2, 0))
    cup = [(0, 0.04), (0.55, 0.04), (0.72, 1.35), (0.66, 1.35), (0.5, 0.14), (0, 0.14)]
    lathe(bucket, cup, 24, transform=Matrix.Translation(spot))
    def ball(center):
        bmesh.ops.create_icosphere(balls, subdivisions=2, radius=0.32, matrix=Matrix.Translation(Vector(center)))
    for i in range(7):
        a = 2 * math.pi * i / 7
        ball(spot + Vector((0.36 * math.cos(a), 0.36 * math.sin(a), 1.15 + 0.05 * (i % 2))))
    ball(spot + Vector((0, 0, 1.4)))
    for offset in ((0, 0, 0.32), (0.75, 0.4, 0.32), (-0.5, 0.8, 0.32)):
        ball(spot + Vector((1.2, 0.0, 0)) + Vector(offset))
    hopper = Vector((PITCH.x, PITCH.y + 2.85, 6.15))
    for offset in ((0, 0, 0), (0.5, 0.2, 0.15), (-0.45, 0.3, 0.12), (0.1, -0.5, 0.2), (0.05, 0.25, 0.5)):
        ball(hopper + Vector(offset))
    return [finish(coll, "HomePlate", plate, WHITE, bevel_width=0.02),
            finish(coll, "BallBucket", bucket, (0.9, 0.45, 0.12)),
            make_object(coll, "Baseballs", balls, WHITE)]


def build_lights(coll):
    housing, lens = bmesh.new(), bmesh.new()
    for y in (10.0, 26.0):
        box(housing, (3.0, y, HEIGHT - 0.85), (3.0, 0.9, 0.45))
        for dx in (-1.0, 1.0):
            tube(housing, (3.0 + dx, y, HEIGHT - 0.65), (3.0 + dx, y, HEIGHT - 0.05), 0.07, 8)
        box(lens, (3.0, y, HEIGHT - 1.09), (2.7, 0.66, 0.04))
    return [finish(coll, "LightHousing", housing, STEEL, bevel_width=0.04),
            finish(coll, "LightLens", lens, (1.0, 0.97, 0.85))]


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = [build_frame(coll), build_pads(coll)]
    objects += build_nets(coll) + build_machine(coll) + build_screen(coll)
    objects += build_plate_bucket_balls(coll) + build_lights(coll)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
