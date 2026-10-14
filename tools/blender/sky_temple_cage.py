# Training Ground 4, Sky Temple: a temple above the clouds. A stepped marble plinth, slender
# columns wound with gold, segmental golden arches under a glowing gold lattice, a gold inlay
# floor with a sun emblem, a winged golden statue that holds out each pitch, a sunburst screen,
# blue-flamed braziers, a cloud bank, floating islands with waterfalls (one with a shrine) and
# golden armillary rings turning overhead.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the
# mesh names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "SkyTempleCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\SkyTempleCage.fbx"

MARBLE = (0.96, 0.96, 0.93)
GOLD = (1.0, 0.78, 0.28)
GLOW_GOLD = (1.0, 0.85, 0.45)
CLOUD = (1.0, 1.0, 1.0)
rng = random.Random(23)

SPRING, SAGITTA = 12.0, 5.0            # columns carry segmental arches across the cage
HALF = (RIGHT_X - LEFT_X) / 2
CX = (LEFT_X + RIGHT_X) / 2
R = (HALF ** 2 + SAGITTA ** 2) / (2 * SAGITTA)
CZ = SPRING + SAGITTA - R
PHI0 = math.acos(HALF / R)


def arch_point(t, y=0.0, inset=0.0):
    """Point on the segmental arch, t from 0 (left spring) to 1 (right spring)."""
    phi = math.pi - PHI0 - (math.pi - 2 * PHI0) * t
    return Vector((CX + (R - inset) * math.cos(phi), y, CZ + (R - inset) * math.sin(phi)))


def column(marble, gold, base, height, radius, turns=2):
    b = Vector(base)
    box(marble, b + Vector((0, 0, 0.2)), (radius * 2.7, radius * 2.7, 0.4))
    torus(gold, b + Vector((0, 0, 0.5)), (0, 0, 1), radius * 1.12, 0.12, segments=20, minor_segments=5)
    lathe(marble, [(0, 0.4), (radius, 0.4), (radius * 0.97, height * 0.5), (radius * 0.9, height - 1.2), (0, height - 1.2)], 18,
          transform=Matrix.Translation(b))
    helix = [b + Vector((math.cos(t * turns * 2 * math.pi) * radius * 0.98, math.sin(t * turns * 2 * math.pi) * radius * 0.98,
                         0.7 + t * (height - 2.1))) for t in arange(1, 1 / (16 * turns))]
    sweep(gold, helix, 0.06, segments=5)
    lathe(gold, [(radius * 0.9, height - 1.25), (radius * 1.0, height - 1.1), (radius * 1.5, height - 0.45), (radius * 1.45, height - 0.4),
                 (0, height - 0.4)], 18, transform=Matrix.Translation(b))
    box(marble, b + Vector((0, 0, height - 0.2)), (radius * 3.0, radius * 3.0, 0.4))


def feathered_wing(bm, shoulder, tip, rows=4, feathers=14, side=1, scale=1.0):
    """A wing as overlapping feathers hanging from a curved bone."""
    shoulder, tip = Vector(shoulder), Vector(tip)
    elbow = shoulder.lerp(tip, 0.45) + Vector((0, 0.3, 1.2 * scale))
    bone = Polyline([shoulder, elbow, tip])
    sweep_radii(bm, bone.samples(0.4), [0.14 * scale] * len(bone.samples(0.4)), segments=6)
    for row in range(rows):
        for k in range(feathers):
            t = (k + 0.5) / feathers
            p = bone.at(bone.length * t) + Vector((0, 0.04 * row, -0.25 * row * scale))
            length = (1.2 + 1.6 * t) * scale * (1 - row * 0.2) * (1.6 if row == 0 else 1.0)
            direction = Vector((side * (0.35 + 0.5 * t), 0.12, -1)).normalized()
            leaf(bm, p, direction, Vector((side, 0, 0.25)), length, 0.62 * scale)


def build_temple(coll):
    marble, gold, lattice_sides, lattice_roof, inlay, plinth = (bmesh.new() for _ in range(6))
    for x in (LEFT_X, RIGHT_X):
        for y in HOOPS:
            column(marble, gold, (x, y, 0), SPRING, 0.5)
    # Golden segmental arches across the cage, tied by golden beams along the springs and crown.
    for y in HOOPS:
        sweep_profile(gold, [arch_point(t, y) for t in arange(1, 1 / 28)], [(-0.3, -0.35), (0.3, -0.35), (0.3, 0.35), (-0.3, 0.35)])
        for t in (0.25, 0.5, 0.75):
            ball(gold, arch_point(t, y, inset=-0.1), 0.32, subdivisions=1)
    for t in (0.0, 0.5, 1.0):
        p = arch_point(t)
        box(gold, (p.x, (BACK_Y + FRONT_Y) / 2, p.z + 0.1), (0.5, FRONT_Y - BACK_Y + 0.6, 0.4))
    # A glowing golden lattice on the walls, the ends and the vault.
    for x, outward in ((LEFT_X, -1), (RIGHT_X, 1)):
        net_panel(lattice_sides, Vector((x - outward * 0.05, BACK_Y, 0.75)), Vector((0, 1, 0)), Vector((0, 0, 1)),
                  FRONT_Y - BACK_Y, SPRING - 1.0, Vector((outward, 0, 0)), 1.7, 0.08, rope=0.0, diamond=True)
    for y, outward, has_door in ((BACK_Y, -1, True), (FRONT_Y, 1, False)):
        def hole(u, v, has_door=has_door):
            x = LEFT_X + u
            top = arch_point((x - LEFT_X) / (RIGHT_X - LEFT_X)).z
            return v + 0.75 > top or (has_door and DOOR[0] - 0.2 < x < DOOR[1] + 0.2 and v + 0.75 < 8.6)
        net_panel(lattice_sides, Vector((LEFT_X, y - outward * 0.05, 0.75)), Vector((1, 0, 0)), Vector((0, 0, 1)),
                  RIGHT_X - LEFT_X, SPRING + SAGITTA - 0.75, Vector((0, outward, 0)), 1.7, 0.08, hole=hole, rope=0.0, diamond=True)
    surface_net(lattice_roof, lambda u, v: arch_point(v / 31.0, BACK_Y + u, inset=-0.05), FRONT_Y - BACK_Y, 31.0, 1.7, 0.08)
    # Stepped plinth around the outside, open at the door.
    for step, (out, top) in enumerate(((2.4, 0.35), (1.2, 0.7))):
        x0, x1, y0, y1 = LEFT_X - out, RIGHT_X + out, BACK_Y - out, FRONT_Y + out
        z = top / 2
        box(plinth, (x0 + (out - 0.4) / 2, (y0 + y1) / 2, z), (out - 0.4, y1 - y0, top))
        box(plinth, (x1 - (out - 0.4) / 2, (y0 + y1) / 2, z), (out - 0.4, y1 - y0, top))
        box(plinth, ((x0 + x1) / 2, y1 - (out - 0.4) / 2, z), (x1 - x0, out - 0.4, top))
        door_l, door_r = DOOR[0] - 0.4, DOOR[1] + 0.4
        box(plinth, ((x0 + door_l) / 2, y0 + (out - 0.4) / 2, z), (door_l - x0, out - 0.4, top))
        box(plinth, ((door_r + x1) / 2, y0 + (out - 0.4) / 2, z), (x1 - door_r, out - 0.4, top))
    # Gold inlay: a wave border inside the walls and a sun emblem behind the batter.
    for x0, x1, y0, y1 in ((LEFT_X + 1.0, RIGHT_X - 1.0, BACK_Y + 1.0, BACK_Y + 1.0), (LEFT_X + 1.0, RIGHT_X - 1.0, FRONT_Y - 1.0, FRONT_Y - 1.0),
                           (LEFT_X + 1.0, LEFT_X + 1.0, BACK_Y + 1.0, FRONT_Y - 1.0), (RIGHT_X - 1.0, RIGHT_X - 1.0, BACK_Y + 1.0, FRONT_Y - 1.0)):
        a, b = Vector((x0, y0, 0.03)), Vector((x1, y1, 0.03))
        along = (b - a).normalized()
        across = Vector((-along.y, along.x, 0))
        for offset in (-0.35, 0.35):
            double_sided_strip(inlay, [a + across * (offset - 0.05), b + across * (offset - 0.05)],
                               [a + across * (offset + 0.05), b + across * (offset + 0.05)])
        count = int((b - a).length / 0.25)
        wave = [a.lerp(b, i / count) + across * 0.22 * math.sin(i * 0.25 * math.pi * 1.6) for i in range(count + 1)]
        double_sided_strip(inlay, [p - across * 0.04 for p in wave], [p + across * 0.04 for p in wave])
    sun = Vector((-9.0, 1.0, 0.03))
    for ring_r in (1.0, 1.15, 2.6, 2.75):
        pts = [sun + Vector((math.cos(a) * ring_r, math.sin(a) * ring_r, 0)) for a in [2 * math.pi * k / 40 for k in range(41)]]
        double_sided_strip(inlay, [p * 1 for p in pts[:-1]] + [pts[0]], [sun + (p - sun) * 1.04 for p in pts[:-1]] + [sun + (pts[0] - sun) * 1.04])
    for k in range(16):
        a = 2 * math.pi * k / 16
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0))
        inner, outer = sun + d * 1.25, sun + d * (2.45 if k % 2 == 0 else 2.0)
        double_sided_poly(inlay, [inner - s * 0.18, outer, inner + s * 0.18])
    return [finish(coll, "SkyMarble", marble, MARBLE, hard=False), finish(coll, "SkyGold", gold, GOLD, hard=False),
            soft(coll, "SkyLatticeSides", lattice_sides, GLOW_GOLD), soft(coll, "SkyLatticeRoof", lattice_roof, GLOW_GOLD),
            soft(coll, "SkyInlay", inlay, GOLD), finish(coll, "SkyPlinth", plinth, MARBLE, bevel_width=0.04)]


def build_statue_and_screen(coll):
    statue, pedestal, halo, plate, screen, screen_gold = (bmesh.new() for _ in range(6))
    home_plate(plate, 0.08)
    base = Vector((PITCH.x, PITCH.y + 2.2, 0))
    lathe(pedestal, [(0, 0), (1.45, 0), (1.45, 0.25), (1.25, 0.35), (1.25, 0.85), (1.4, 1.0), (0, 1.0)], 24,
          transform=Matrix.Translation(base))
    torus(halo, base + Vector((0, 0, 0.62)), (0, 0, 1), 1.27, 0.07, segments=24, minor_segments=5)
    lathe(statue, [(0, 1.0), (1.0, 1.0), (0.95, 1.3), (0.72, 3.0), (0.5, 4.5), (0.58, 5.2), (0.62, 5.6), (0.4, 6.0), (0.22, 6.2), (0, 6.25)],
          20, transform=Matrix.Translation(base))
    head = base + Vector((0, -0.05, 6.7))
    ball(statue, head, 0.5, subdivisions=3)
    blob(statue, head + Vector((0, 0.18, 0.12)), Vector((0.55, 0.5, 0.48)), subdivisions=2, lump=0.15, seed=1.0)
    torus(halo, head + Vector((0, 0.25, 0.85)), (0, 0.35, 1), 0.58, 0.06, segments=24, minor_segments=5)
    for side in (-1, 1):
        shoulder = base + Vector((side * 0.55, 0, 5.85))
        elbow = Vector((PITCH.x + side * 0.65, PITCH.y + 1.1, 4.3))
        hand = Vector((PITCH.x + side * 0.3, PITCH.y + 0.35, 3.25))
        sweep_radii(statue, [shoulder, shoulder.lerp(elbow, 0.5), elbow, elbow.lerp(hand, 0.5), hand], [0.2, 0.19, 0.17, 0.15, 0.13], segments=8)
        blob(statue, hand + Vector((0, -0.05, -0.08)), Vector((0.18, 0.22, 0.12)), subdivisions=2)
        feathered_wing(statue, base + Vector((side * 0.35, 0.45, 5.6)), base + Vector((side * 4.6, 1.3, 9.2)), rows=4, feathers=14, side=side)
    # The protective screen: marble with a sunburst of gold rays around the window.
    # Lower than the other screens so the statue shows above it (the invisible block is unchanged).
    slab_with_window(screen, PITCH.x - 3.5, PITCH.x + 3.5, 0.0, 5.4, (PITCH.x, PITCH.z), WINDOW + 0.05, SCREEN_Y, 0.5, segments=56)
    for y in (SCREEN_Y - 0.27, SCREEN_Y + 0.27):
        torus(screen_gold, (PITCH.x, y, PITCH.z), (0, 1, 0), WINDOW + 0.12, 0.1, segments=28, minor_segments=5)
    for k in range(20):
        a = 2 * math.pi * k / 20
        d = Vector((math.cos(a), 0, math.sin(a)))
        s = Vector((-d.z, 0, d.x))
        inner = Vector((PITCH.x, SCREEN_Y - 0.27, PITCH.z)) + d * (WINDOW + 0.25)
        outer = inner + d * (1.3 if k % 2 == 0 else 0.8)
        double_sided_poly(screen_gold, [inner - s * 0.16, outer, inner + s * 0.16])
    for z in (0.25, 5.15):
        box(screen_gold, (PITCH.x, SCREEN_Y, z), (7.1, 0.56, 0.18))
    for x in (PITCH.x - 3.5, PITCH.x + 3.5):
        box(screen_gold, (x, SCREEN_Y, 2.7), (0.18, 0.56, 5.4))
    for side in (-1, 1):
        feathered_wing(screen_gold, (PITCH.x + side * 0.3, SCREEN_Y, 5.4), (PITCH.x + side * 2.6, SCREEN_Y, 6.6),
                       rows=2, feathers=7, side=side, scale=0.45)
    return [finish(coll, "SkyStatue", statue, GOLD, hard=False), finish(coll, "SkyPedestal", pedestal, MARBLE, hard=False),
            finish(coll, "SkyHalo", halo, GLOW_GOLD, hard=False), finish(coll, "SkyPlate", plate, MARBLE, bevel_width=0.02),
            finish(coll, "SkyScreen", screen, MARBLE, hard=True), soft(coll, "SkyScreenGold", screen_gold, GOLD)]


def island(name, coll, center, radius, falls, rng, shrine=False):
    rock, grass, water, trees, gold = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    c = Vector(center)
    # A jagged inverted cone of rock with a few chunks hanging beneath it.
    lathe(rock, [(0, -radius * 1.9), (radius * 0.3, -radius * 1.55), (radius * 0.62, -radius * 1.0), (radius * 0.9, -radius * 0.45),
                 (radius * 1.0, -0.15), (0, -0.15)], 18, transform=Matrix.Translation(c), wobble=radius * 0.28, seed=rng.random() * 9)
    for k in range(3):
        a = 2 * math.pi * k / 3 + rng.uniform(-0.4, 0.4)
        rough_rock(rock, c + Vector((math.cos(a) * radius * 0.4, math.sin(a) * radius * 0.4, -radius * (1.3 + 0.25 * k))),
                   (radius * 0.28, radius * 0.28, radius * 0.4), rng, subdivisions=1, jitter=0.3, floor=None)
    lathe(grass, [(0, 0.35), (radius * 0.6, 0.32), (radius * 0.98, 0.1), (radius * 1.02, -0.15), (0, -0.15)], 20,
          transform=Matrix.Translation(c), wobble=0.12, seed=rng.random() * 9)
    for a, length in falls:
        edge = c + Vector((math.cos(a) * radius * 0.92, math.sin(a) * radius * 0.92, 0.1))
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0))
        path = [edge + d * (0.6 * math.sin(min(1.0, t * 3) * math.pi / 2)) + Vector((0, 0, -length * t)) for t in arange(1, 1 / 14)]
        double_sided_strip(water, [p - s * 0.5 for p in path], [p + s * 0.5 for p in path])
    for k in range(3 if not shrine else 2):
        a = rng.uniform(0, 2 * math.pi)
        p = c + Vector((math.cos(a) * radius * 0.5, math.sin(a) * radius * 0.5, 0.3))
        cylinder(trees, p, (0, 0, 1), 0.9, 0.12, segments=6)
        ball(trees, p + Vector((0, 0, 1.4)), 0.6, subdivisions=2)
    if shrine:
        for k in range(6):
            a = 2 * math.pi * k / 6
            cylinder(gold, c + Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, 0.3)), (0, 0, 1), 2.4, 0.14, segments=8)
        lathe(gold, [(0, 2.7), (1.6, 2.7), (1.55, 2.95), (1.2, 3.6), (0.6, 4.05), (0, 4.2)], 18, transform=Matrix.Translation(c))
        ball(gold, c + Vector((0, 0, 4.45)), 0.25, subdivisions=1)
    parts = [finish(coll, name + "Rock", rock, (0.55, 0.5, 0.45), hard=False), finish(coll, name + "Grass", grass, (0.45, 0.78, 0.4), hard=False),
             soft(coll, name + "Falls", water, (0.6, 0.85, 1.0)), finish(coll, name + "Trees", trees, (0.35, 0.65, 0.35), hard=False)]
    if shrine:
        parts.append(finish(coll, name + "Shrine", gold, GOLD, hard=False))
    return parts


def build_sky(coll):
    clouds, rings, objects = bmesh.new(), [], []
    # A bank of cloud along the outside of the plinth, parted at the door.
    spots = []
    for y in arange(FRONT_Y - BACK_Y + 6, 4.5):
        spots += [(LEFT_X - 4.1 + rng.uniform(-0.4, 0.3), BACK_Y - 3 + y), (RIGHT_X + 4.2 + rng.uniform(-0.4, 0.6), BACK_Y - 3 + y)]
    for x in arange(RIGHT_X - LEFT_X + 6, 4.0):
        spots.append((LEFT_X - 3 + x, FRONT_Y + 4.5 + rng.uniform(-0.5, 0.5)))
        px = LEFT_X - 3 + x
        if not (DOOR[0] - 3 < px < DOOR[1] + 3):
            spots.append((px, BACK_Y - 4.4 + rng.uniform(-0.4, 0.4)))
    for x, y in spots:
        s = rng.uniform(1.6, 2.3)
        blob(clouds, Vector((x, y, 0.6)), Vector((s, s, s * 0.7)), subdivisions=2, lump=0.2, seed=rng.random() * 9)
    cloud = fused_surface(coll, "SkyClouds", clouds, voxel=0.56, lump_scale=0.6, lump_strength=0.5, rgb=CLOUD, floor=0.0)
    objects.append(cloud)
    objects += island("SkyIslandA", coll, (LEFT_X - 3.6, 8.0, 19.5), 2.4, [(math.pi, 9.0)], rng)
    objects += island("SkyIslandB", coll, (RIGHT_X + 3.4, 28.0, 21.5), 2.3, [(0.0, 10.0)], rng)
    objects += island("SkyIslandC", coll, (-2.0, 42.5, 19.0), 4.2, [(math.pi * 0.25, 14.0), (math.pi * 0.85, 12.0)], rng, shrine=True)
    # Golden armillary rings and a glowing orb turning high over the vault.
    center = Vector((CX, (BACK_Y + FRONT_Y) / 2, 24.0))
    for name, radius, axis in (("SkyRingOuter", 6.6, (0.3, 0.0, 1.0)), ("SkyRingMiddle", 5.0, (1.0, 0.5, 0.4)),
                               ("SkyRingInner", 3.5, (-0.4, 1.0, 0.6))):
        bm = bmesh.new()
        torus(bm, center, axis, radius, 0.2, segments=48, minor_segments=8)
        normal = Vector(axis).normalized()
        side = normal.cross(Vector((0, 0, 1)) if abs(normal.z) < 0.9 else Vector((1, 0, 0))).normalized()
        other = normal.cross(side)
        for k in range(12):
            a = 2 * math.pi * k / 12
            p = center + (side * math.cos(a) + other * math.sin(a)) * radius
            ball(bm, p, 0.32, subdivisions=1)
        objects.append(finish(coll, name, bm, GOLD, hard=False))
    orb = bmesh.new()
    ball(orb, center, 1.2, subdivisions=3)
    objects.append(finish(coll, "SkyOrb", orb, (1.0, 0.95, 0.7), hard=False))
    return objects


def build_braziers(coll):
    stands, flames, door = bmesh.new(), bmesh.new(), bmesh.new()
    for base in ((-14.4, 32.2, 0), (12.4, 32.2, 0), (DOOR[0] - 2.2, BACK_Y - 3.0, 0), (DOOR[1] + 2.2, BACK_Y - 3.0, 0)):
        b = Vector(base)
        lathe(stands, [(0, 0), (0.6, 0), (0.6, 0.2), (0.18, 0.4), (0.12, 2.6), (0.2, 2.75), (0.75, 3.1), (0.8, 3.35), (0.65, 3.35),
                       (0.2, 2.95), (0, 2.95)], 16, transform=Matrix.Translation(b))
        lathe(flames, [(0, 2.95), (0.55, 3.2), (0.5, 3.7), (0.28, 4.2), (0, 4.75)], 12, transform=Matrix.Translation(b))
    # The doorway: slender columns under a golden arch.
    middle, half = (DOOR[0] + DOOR[1]) / 2, (DOOR[1] - DOOR[0]) / 2
    for x in DOOR[:2]:
        column(door, door, (x, BACK_Y, 0), 5.5, 0.32, turns=1)
    sweep_profile(door, [Vector((middle - half * math.cos(t), BACK_Y, 5.5 + half * 0.95 * math.sin(t))) for t in [math.pi * i / 20 for i in range(21)]],
                  [(-0.25, -0.3), (0.25, -0.3), (0.25, 0.3), (-0.25, 0.3)])
    return [finish(coll, "SkyBraziers", stands, GOLD, hard=False), finish(coll, "SkyFlames", flames, (0.45, 0.8, 1.0), hard=False),
            finish(coll, "SkyDoorway", door, GOLD, hard=False)]


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = build_temple(coll) + build_statue_and_screen(coll) + build_sky(coll) + build_braziers(coll)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
