# Training Ground 5, Dragon's Lair: a volcanic hoard cave. Jagged obsidian pillars veined with
# lava, an iron frame and gabled roof crested with spikes, chain-link lattice walls and heavy
# draped chains, lava cracks and scattered gold on the floor, a sculpted dragon head that
# breathes out each pitch, an iron portcullis screen, treasure hoards with gems and a crown,
# a coiled dragon skeleton over the roof, iron torches and lava pools.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the
# mesh names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "DragonLairCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\DragonLairCage.fbx"

OBSIDIAN = (0.08, 0.07, 0.09)
IRON = (0.2, 0.19, 0.2)
LAVA = (1.0, 0.38, 0.05)
GOLD = (1.0, 0.76, 0.2)
BONE = (0.86, 0.8, 0.66)
rng = random.Random(31)

EAVE, RIDGE = 12.5, 16.5               # gabled roof: eaves along the walls, ridge down the middle
CX, HALF = (LEFT_X + RIGHT_X) / 2, (RIGHT_X - LEFT_X) / 2


def roof_height(x):
    return EAVE + (RIDGE - EAVE) * (1 - min(1.0, abs(x - CX) / HALF))


def obsidian_pillar(bm, veins, base, height, rng):
    """A cluster of tilted, faceted obsidian shards with lava veins climbing the main shard."""
    b = Vector(base)
    shards = [(Vector((0, 0, 0)), height, 1.05, Vector((0, 0, 1)))]
    for k in range(4):
        a = 2 * math.pi * k / 4 + rng.uniform(-0.5, 0.5)
        offset = Vector((math.cos(a), math.sin(a), 0)) * 0.8
        tilt = (Vector((0, 0, 1)) + offset * rng.uniform(0.25, 0.5)).normalized()
        shards.append((offset, height * rng.uniform(0.4, 0.72), rng.uniform(0.45, 0.65), tilt))
    for offset, length, radius, direction in shards:
        hex_crystal(bm, b + offset, direction, length, radius, sides=6)
    for k in range(2):
        a = rng.uniform(0, 2 * math.pi)
        path = []
        for i in range(12):
            t = i / 11
            angle = a + math.sin(t * 7 + k) * 0.5
            r = 1.07 * (1 - 0.15 * t)
            path.append(b + Vector((math.cos(angle) * r, math.sin(angle) * r, 0.3 + t * height * 0.62)))
        sweep(veins, path, 0.05, segments=4)


def chain(bm, a, b, sag, link=0.62):
    """Heavy iron links hanging between two points."""
    a, b = Vector(a), Vector(b)
    count = int((b - a).length / (link * 0.78))
    points = [a.lerp(b, i / count) - Vector((0, 0, sag * math.sin(math.pi * i / count))) for i in range(count + 1)]
    for i in range(count):
        p, q = points[i], points[i + 1]
        middle = (p + q) / 2
        along = (q - p).normalized()
        # Each link is a ring stretched along the chain; every other link turns a quarter turn.
        turn = (Matrix.Translation(middle) @ along.to_track_quat("Z", "Y").to_matrix().to_4x4()
                @ Matrix.Rotation(math.pi / 2 * (i % 2), 4, "Z"))
        before = len(bm.verts)
        torus(bm, (0, 0, 0), (1, 0, 0), 0.2, 0.07, segments=10, minor_segments=4)
        bm.verts.ensure_lookup_table()
        for v in bm.verts[before:]:
            v.co.z *= 1.6
        transform_new(bm, before, turn)


def build_structure(coll):
    obsidian, veins, iron, lattice, spikes, chains, door = (bmesh.new() for _ in range(7))
    for x in (LEFT_X, RIGHT_X):
        for y in HOOPS:
            obsidian_pillar(obsidian, veins, (x, y, 0), EAVE + rng.uniform(-0.5, 1.5), rng)
    # Iron eaves, rafters and the ridge beam, crested with spikes.
    for x in (LEFT_X, RIGHT_X):
        box(iron, (x, (BACK_Y + FRONT_Y) / 2, EAVE), (0.6, FRONT_Y - BACK_Y + 1.0, 0.6))
    box(iron, (CX, (BACK_Y + FRONT_Y) / 2, RIDGE), (0.6, FRONT_Y - BACK_Y + 1.0, 0.6))
    for y in HOOPS:
        for x in (LEFT_X, RIGHT_X):
            sweep_profile(iron, [Vector((x, y, EAVE)), Vector((CX, y, RIDGE))], [(-0.25, -0.25), (0.25, -0.25), (0.25, 0.25), (-0.25, 0.25)])
        for k in range(1, 6):
            for x in (LEFT_X + HALF * k / 6, RIGHT_X - HALF * k / 6):
                ball(iron, (x, y, roof_height(x) + 0.28), 0.09, subdivisions=1)
    # Spikes crest the eaves (the dragon skeleton lies along the ridge).
    for x in (LEFT_X, RIGHT_X):
        for y in arange(FRONT_Y - BACK_Y, 2.0):
            cylinder(spikes, (x, BACK_Y + y, EAVE + 0.3), (0, 0, 1), 1.0 if int(y / 2.0) % 2 == 0 else 0.6, 0.16, segments=6, radius_top=0.0)
    # Chain-link lattice: walls, gabled ends (door in the batter end) and both roof slopes.
    for x, outward in ((LEFT_X, -1), (RIGHT_X, 1)):
        net_panel(lattice, Vector((x - outward * 0.1, BACK_Y, 0.1)), Vector((0, 1, 0)), Vector((0, 0, 1)), FRONT_Y - BACK_Y, EAVE - 0.1,
                  Vector((outward, 0, 0)), 2.0, 0.1, rope=0.0, diamond=True)
    slope = math.hypot(HALF, RIDGE - EAVE)
    for x0, direction in ((LEFT_X, 1), (RIGHT_X, -1)):
        u_axis = Vector((0, 1, 0))
        v_axis = Vector((direction * HALF, 0, RIDGE - EAVE)).normalized()
        normal = u_axis.cross(v_axis) * direction
        net_panel(lattice, Vector((x0, BACK_Y, EAVE + 0.1)), u_axis, v_axis, FRONT_Y - BACK_Y, slope, normal, 2.0, 0.1, rope=0.0, diamond=True)
    for y, outward, has_door in ((BACK_Y, -1, True), (FRONT_Y, 1, False)):
        def hole(u, v, has_door=has_door):
            x = LEFT_X + u
            return v > roof_height(x) - 0.1 or (has_door and DOOR[0] - 0.1 < x < DOOR[1] + 0.1 and v < 8.4)
        net_panel(lattice, Vector((LEFT_X, y - outward * 0.1, 0.1)), Vector((1, 0, 0)), Vector((0, 0, 1)), RIGHT_X - LEFT_X, RIDGE,
                  Vector((0, outward, 0)), 2.0, 0.1, hole=hole, rope=0.0, diamond=True)
    # Heavy chains drape between the pillars along both walls.
    for x in (LEFT_X - 0.55, RIGHT_X + 0.55):
        for a, b in zip(HOOPS, HOOPS[1:]):
            chain(chains, (x, a + 0.6, EAVE - 0.6), (x, b - 0.6, EAVE - 0.6), 1.6)
    # The doorway: a pointed obsidian arch with iron bands.
    middle, half = (DOOR[0] + DOOR[1]) / 2, (DOOR[1] - DOOR[0]) / 2
    for x in DOOR[:2]:
        hex_crystal(door, Vector((x, BACK_Y, 0)), Vector((0, 0, 1)), 6.6, 0.42, sides=6)
    arch = []
    for i in range(13):
        t = i / 12
        side = -1 if t < 0.5 else 1
        s = abs(t - 0.5) * 2
        arch.append(Vector((middle + side * half * math.sin(math.acos(1 - s)) if s > 0 else middle, BACK_Y,
                            5.6 + 2.8 * (1 - s) ** 0.8)))
    sweep_profile(door, arch, [(-0.3, -0.35), (0.3, -0.35), (0.3, 0.35), (-0.3, 0.35)])
    for z in (1.5, 4.0):
        for x in DOOR[:2]:
            torus(iron, (x, BACK_Y, z), (0, 0, 1), 0.46, 0.07, segments=12, minor_segments=4)
    return [finish(coll, "DragonObsidian", obsidian, OBSIDIAN, hard=True), soft(coll, "DragonVeins", veins, LAVA),
            finish(coll, "DragonIron", iron, IRON, hard=True), soft(coll, "DragonLattice", lattice, (0.24, 0.22, 0.22)),
            finish(coll, "DragonSpikes", spikes, IRON, hard=True), finish(coll, "DragonChains", chains, (0.28, 0.26, 0.26), hard=False),
            finish(coll, "DragonDoorway", door, OBSIDIAN, hard=True)]


def crack(bm, start, direction, length, rng, depth=2, width=0.16, avoid=lambda p: False):
    """A branching glowing crack on the floor."""
    points, p, d = [Vector(start)], Vector(start), Vector(direction).normalized()
    for _ in range(int(length / 0.5)):
        d = (d + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0))).normalized()
        p = p + d * 0.5
        if avoid(p):
            break
        points.append(p.copy())
    if len(points) > 1:
        left, right = [], []
        for i, q in enumerate(points):
            ahead = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
            side = Vector((-ahead.y, ahead.x, 0)).normalized() * width * (1 - 0.7 * i / len(points)) / 2
            left.append(q - side + Vector((0, 0, 0.022)))
            right.append(q + side + Vector((0, 0, 0.022)))
        double_sided_strip(bm, left, right)
    if depth > 0 and len(points) > 4:
        for _ in range(2):
            i = rng.randrange(2, len(points) - 1)
            turn = Vector((rng.choice((-1, 1)) * 0.8, 0.5, 0)) if rng.random() < 0.5 else Vector((0.5, rng.choice((-1, 1)) * 0.8, 0))
            crack(bm, points[i], (d + turn).normalized(), length * 0.5, rng, depth - 1, width * 0.7, avoid)


def build_floor_and_head(coll):
    cracks, coins, plate, head_blobs, horns, teeth, eyes, glow, mound = (bmesh.new() for _ in range(9))
    home_plate(plate, 0.08)

    def avoid(p):
        on_lane = PITCH.x - 2.6 < p.x < PITCH.x + 2.6 and -4.5 < p.y < 27.5
        in_box = -3.2 < p.x < 9.2 and -3.8 < p.y < 3.8
        outside = not (LEFT_X - 6 < p.x < RIGHT_X + 6 and BACK_Y - 6 < p.y < FRONT_Y + 10)
        return on_lane or in_box or outside
    for start, direction in (((-15.0, -12.0), (1, 0.6)), ((-15.0, 8.0), (1, 0.2)), ((-14.0, 26.0), (1, -0.4)), ((13.0, -10.0), (-1, 0.5)),
                             ((13.0, 12.0), (-1, -0.2)), ((12.5, 30.0), (-1, -0.6)), ((-19.0, 0.0), (0.3, 1)), ((17.5, 20.0), (-0.2, -1)),
                             ((-6.0, 37.0), (0.4, 1)), ((9.0, 38.0), (-0.3, 1)), ((-10.0, -16.5), (1, 0.1))):
        crack(cracks, Vector((start[0], start[1], 0)), Vector((direction[0], direction[1], 0)), 7.0, rng, depth=2, avoid=avoid)
    # Gold coins strewn along the edges of the gold lane.
    for _ in range(70):
        side = rng.choice((-1, 1))
        p = Vector((PITCH.x + side * rng.uniform(2.4, 3.6), rng.uniform(4.0, 25.0), 0.02))
        cylinder(coins, p, (rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 1), 0.05, 0.17, segments=10)

    # The dragon head: snout and brow fused into one sculpted surface, the jaw hanging open so
    # each pitch leaves between the teeth at PITCH.
    def chunk(center, size, seed):
        blob(head_blobs, Vector(center), Vector(size), subdivisions=3, lump=0.12, lump_scale=2.5, seed=seed)
    x, y = PITCH.x, PITCH.y
    for i in range(6):
        t = i / 5
        chunk((x, y + 0.4 + t * 2.3, 3.75 + t * 0.55), (0.75 + t * 0.35, 0.65, 0.42 + t * 0.2), i)
    for side in (-1, 1):
        chunk((x + side * 0.82, y + 2.3, 4.75), (0.45, 0.7, 0.32), 10 + side)
        chunk((x + side * 0.55, y + 0.55, 4.08), (0.22, 0.25, 0.16), 20 + side)
        chunk((x + side * 1.05, y + 2.9, 3.6), (0.4, 0.9, 0.8), 30 + side)
    for i in range(5):
        t = i / 4
        chunk((x, y + 0.6 + t * 2.0, 2.35 - 0.2 * (1 - t) + t * 0.15), (0.55 + t * 0.3, 0.55, 0.27), 40 + i)
    for i in range(6):
        t = i / 5
        chunk((x, y + 3.2 + t * 3.4, 3.8 - t * 2.2), (1.25 + t * 0.35, 1.0, 1.15 + t * 0.2), 50 + i)
    # The head is sculpted at a convenient size, then grown about the mouth so PITCH stays put.
    grow = Matrix.Translation(PITCH) @ Matrix.Scale(1.35, 4) @ Matrix.Translation(-PITCH)
    bmesh.ops.transform(head_blobs, matrix=grow, verts=head_blobs.verts[:])
    head = fused_surface(coll, "DragonHead", head_blobs, voxel=0.16, lump_scale=1.4, lump_strength=0.1, rgb=(0.42, 0.08, 0.08))
    blob(mound, Vector((x, y + 8.0, 0.6)), Vector((3.6, 3.0, 1.6)), subdivisions=3, lump=0.3, seed=6.0, floor=0.0)
    for side in (-1, 1):
        horn = [Vector((x + side * 0.75, y + 2.7, 5.1)), Vector((x + side * 1.1, y + 3.6, 5.9)), Vector((x + side * 1.35, y + 4.6, 6.4)),
                Vector((x + side * 1.5, y + 5.6, 6.5)), Vector((x + side * 1.55, y + 6.3, 6.2))]
        sweep_radii(horns, horn, [0.32, 0.25, 0.17, 0.1, 0.02], segments=8)
        for k in range(4):
            sweep_radii(horns, [Vector((x + side * 1.2, y + 3.2 + k * 0.7, 3.4 - k * 0.15)), Vector((x + side * 1.75, y + 3.6 + k * 0.7, 3.6 - k * 0.15))],
                        [0.12, 0.01], segments=6)
        ball(eyes, (x + side * 0.72, y + 1.95, 4.5), 0.2, subdivisions=2)
        for k in range(5):
            t = k / 4
            cylinder(teeth, (x + side * (0.48 + 0.15 * t), y + 0.35 + t * 1.5, 3.42 + t * 0.05), (0, 0, -1), 0.4 - 0.12 * t, 0.07, segments=6, radius_top=0.0)
            cylinder(teeth, (x + side * (0.4 + 0.12 * t), y + 0.45 + t * 1.4, 2.55 + t * 0.12), (0, 0, 1), 0.32 - 0.1 * t, 0.06, segments=6, radius_top=0.0)
    for k in range(6):
        cylinder(horns, (x, y + 3.4 + k * 0.6, 5.0 - k * 0.32), (0, 0.3, 1), 0.7 - k * 0.07, 0.16, segments=6, radius_top=0.0)
    ball(glow, (x, y + 1.3, 3.0), 0.42, subdivisions=2)
    for bm in (horns, teeth, eyes, glow):
        bmesh.ops.transform(bm, matrix=grow, verts=bm.verts[:])
    return [soft(coll, "DragonCracks", cracks, LAVA), finish(coll, "DragonCoins", coins, GOLD, hard=False),
            finish(coll, "DragonPlate", plate, (0.6, 0.55, 0.5), bevel_width=0.02), head,
            finish(coll, "DragonHorns", horns, BONE, hard=False), finish(coll, "DragonTeeth", teeth, (0.95, 0.92, 0.82), hard=False),
            finish(coll, "DragonEyes", eyes, (1.0, 0.8, 0.1), hard=False), finish(coll, "DragonMouthGlow", glow, LAVA, hard=False),
            finish(coll, "DragonMound", mound, (0.16, 0.13, 0.13), hard=False)]


def build_screen(coll):
    bars = bmesh.new()
    x0, x1, top = PITCH.x - 3.5, PITCH.x + 3.5, 5.4
    opening = WINDOW + 0.1
    for x in [x0 + 0.5 * k for k in range(15)]:
        dx = abs(x - PITCH.x)
        pieces = [(0.0, top)]
        if dx < opening:
            gap = math.sqrt(opening ** 2 - dx ** 2)
            pieces = [(0.0, PITCH.z - gap), (PITCH.z + gap, top)]
        for z0, z1 in pieces:
            box(bars, (x, SCREEN_Y, (z0 + z1) / 2), (0.14, 0.14, z1 - z0))
    for z in (0.6, 1.8, 4.4, 5.25):
        box(bars, (PITCH.x, SCREEN_Y + 0.12, z), (7.2, 0.12, 0.22))
    for z in (2.4, 3.6):
        for xa, xb in ((x0, PITCH.x - opening), (PITCH.x + opening, x1)):
            box(bars, ((xa + xb) / 2, SCREEN_Y + 0.12, z), (xb - xa, 0.12, 0.22))
    torus(bars, (PITCH.x, SCREEN_Y + 0.05, PITCH.z), (0, 1, 0), opening + 0.05, 0.13, segments=24, minor_segments=6)
    for x in (x0, x1):
        box(bars, (x, SCREEN_Y, top / 2), (0.32, 0.32, top + 0.2))
        cylinder(bars, (x, SCREEN_Y, top + 0.1), (0, 0, 1), 0.6, 0.2, segments=6, radius_top=0.0)
    return [finish(coll, "DragonPortcullis", bars, IRON, hard=True)]


def build_decor(coll):
    hoard_blobs, gems_red, gems_blue, crown, bones, torches, flames, rocks, lava = (bmesh.new() for _ in range(9))
    # Treasure hoards inside the machine-end corner and around the outside.
    for center, size in (((-12.6, 27.0, 0.0), (2.4, 2.8, 1.5)), ((-11.4, 22.6, 0.0), (1.5, 1.5, 0.9)), ((18.2, 6.0, 0.0), (2.4, 3.2, 1.6)),
                         ((-20.0, 30.0, 0.0), (2.6, 3.0, 1.8)), ((9.5, 39.0, 0.0), (3.4, 2.4, 1.8)), ((-20.0, -12.0, 0.0), (2.2, 2.4, 1.2))):
        c, s = Vector(center), Vector(size)
        for k in range(5):
            offset = Vector((rng.uniform(-0.45, 0.45) * s.x, rng.uniform(-0.45, 0.45) * s.y, 0))
            blob(hoard_blobs, c + offset, Vector((s.x * 0.55, s.y * 0.55, s.z * rng.uniform(0.6, 1.0))), subdivisions=2, lump=0.15, seed=rng.random() * 9, floor=0.0)
        for k in range(5):
            p = c + Vector((rng.uniform(-0.6, 0.6) * s.x, rng.uniform(-0.6, 0.6) * s.y, s.z * rng.uniform(0.3, 0.75)))
            hex_crystal(gems_red if k % 2 else gems_blue, p, Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 1)), rng.uniform(0.4, 0.7), 0.15)
    hoard = fused_surface(coll, "DragonHoard", hoard_blobs, voxel=0.22, lump_scale=6.0, lump_strength=0.18, rgb=GOLD, floor=0.0)
    crown_at = Vector((-12.4, 27.0, 1.4))
    lathe(crown, [(0.42, 0), (0.48, 0), (0.48, 0.32), (0.42, 0.32)], 16, transform=Matrix.Translation(crown_at))
    for k in range(8):
        a = 2 * math.pi * k / 8
        cylinder(crown, crown_at + Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.3)), (0, 0, 1), 0.32, 0.07, segments=4, radius_top=0.0)
    for p in ((-11.0, 25.0, 0.0), (17.6, 8.6, 0.0)):
        lathe(crown, [(0, 0), (0.28, 0), (0.08, 0.1), (0.07, 0.5), (0.3, 0.75), (0.32, 1.0), (0.26, 1.0), (0, 0.8)], 12, transform=Matrix.Translation(p))
    # Iron torches on the inner faces of the pillars.
    for y in (-6.0, 10.0, 26.0):
        for x, inward in ((LEFT_X, 1), (RIGHT_X, -1)):
            mount = Vector((x + inward * 0.85, y, 7.2))
            sweep(torches, [mount - Vector((inward * 0.5, 0, 0.4)), mount], 0.07, segments=5)
            lathe(torches, [(0, -0.35), (0.12, -0.3), (0.28, 0.0), (0.3, 0.12), (0, 0.12)], 10, transform=Matrix.Translation(mount))
            lathe(flames, [(0, 0.1), (0.24, 0.3), (0.2, 0.62), (0.08, 0.95), (0, 1.15)], 10, transform=Matrix.Translation(mount))
    # Lava pools with rocky rims outside the cage.
    for center, radius in (((-4.0, 40.5, 0.0), 2.6), ((-19.8, 12.0, 0.0), 1.9), ((18.2, 24.0, 0.0), 1.8), ((16.5, 39.0, 0.0), 1.5)):
        c = Vector(center)
        lathe(lava, [(0, 0.06), (radius, 0.06), (radius, 0.0), (0, 0.0)], 20, transform=Matrix.Translation(c), wobble=radius * 0.12, seed=radius)
        for k in range(10):
            a = 2 * math.pi * k / 10 + rng.uniform(-0.2, 0.2)
            rough_rock(rocks, c + Vector((math.cos(a) * radius, math.sin(a) * radius, 0.15)), (0.55, 0.5, 0.42), rng, subdivisions=1, jitter=0.25)
    return [hoard, finish(coll, "DragonGemsRed", gems_red, (1.0, 0.1, 0.15), hard=True),
            finish(coll, "DragonGemsBlue", gems_blue, (0.2, 0.45, 1.0), hard=True), finish(coll, "DragonCrown", crown, GOLD, hard=False),
            finish(coll, "DragonTorches", torches, IRON, hard=False),
            finish(coll, "DragonFlames", flames, (1.0, 0.55, 0.1), hard=False), finish(coll, "DragonRocks", rocks, (0.14, 0.12, 0.12), hard=True),
            finish(coll, "DragonLava", lava, LAVA, hard=False)]


def build_skeleton(coll):
    """A complete dragon skeleton sprawled over the roof: skull hanging over the entrance,
    spine along the ridge, ribs draped down both slopes, legs gripping the eaves, splayed wing
    bones with tattered membrane, and a tail running down the far end to coil round a hoard."""
    bones, skull_blobs, membrane, eyes = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    top = RIDGE + 1.9                         # vertebrae rest on the ridge beam

    def roof_clear(offset, lift=0.35):
        return roof_height(CX + offset) + lift

    # Spine: neck curling down over the batter end, body along the ridge, tail down the far end.
    neck = [Vector((CX, -16.2, 15.3)), Vector((CX, -15.4, 16.9)), Vector((CX, -13.6, 17.9)), Vector((CX, -11.0, top))]
    body = [Vector((CX + 0.9 * math.sin(t * 0.25), t, top)) for t in [-9.0 + 2.0 * i for i in range(21)]]
    tail = [Vector((CX - 0.4, 32.6, top - 0.6)), Vector((CX + 0.4, 35.0, 15.4)), Vector((CX + 1.6, 36.4, 10.5)),
            Vector((CX + 3.2, 37.0, 5.0)), Vector((CX + 4.8, 36.6, 1.4))]
    hoard, start = Vector((9.5, 39.5, 0)), math.atan2(36.6 - 39.5, CX + 4.8 - 9.5)
    coil = [hoard + Vector((math.cos(start + a) * (4.4 - 0.9 * a / 5.6), math.sin(start + a) * (4.4 - 0.9 * a / 5.6), 0.9 - 0.45 * a / 5.6))
            for a in [5.6 * i / 14 for i in range(1, 15)]]
    spine = Polyline(neck + body + tail + coil)
    samples = spine.samples(0.85)
    count = len(samples)

    def thickness(i):
        t = i / (count - 1)
        if t < 0.08:
            return 0.65 + t * 4
        return 1.0 if t < 0.55 else max(0.12, 1.0 - (t - 0.55) * 1.95)
    sweep_radii(bones, samples, [0.42 * thickness(i) for i in range(count)], segments=8)
    frames = sweep_frames(samples)
    for i, (p, (tangent, normal, binormal)) in enumerate(zip(samples, frames)):
        s = thickness(i)
        blob(bones, p, Vector((0.62, 0.62, 0.55)) * s, subdivisions=1)
        up = Vector((0, 0, 1)) - tangent * tangent.z
        up = up.normalized() if up.length > 0.1 else normal
        cylinder(bones, p, up, 1.15 * s, 0.17 * s, segments=6, radius_top=0.0)
    # Ribs arch out and down both roof slopes, longest mid-chest.
    for y in [-6.5 + 1.2 * k for k in range(24)]:
        f = math.sin(math.pi * (y + 7.0) / 29.5) ** 0.6
        for side in (-1, 1):
            rib = []
            for k in range(8):
                u = k / 7
                d = 0.5 + (1.4 + 7.6 * f) * u
                z = max(roof_clear(d), top + 0.4 * math.sin(math.pi * u) - 4.6 * u * u)
                rib.append(Vector((CX + side * d, y + 0.5 * u, z)))
            sweep_radii(bones, rib, [0.19 - 0.015 * k for k in range(8)], segments=6)
    # Shoulder and hip girdles, and four legs gripping the eaves.
    for y in (-2.0, 20.0):
        for side in (-1, 1):
            blob(bones, Vector((CX + side * 1.4, y, top + 0.1)), Vector((1.0, 0.6, 0.35)), subdivisions=2)
            shoulder = Vector((CX + side * 1.6, y, top - 0.1))
            elbow = Vector((CX + side * 6.5, y - 1.3, roof_clear(5.5, 1.6)))
            wrist = Vector((CX + side * 11.0, y - 0.4, roof_clear(10.0, 0.45)))
            sweep_radii(bones, [shoulder, shoulder.lerp(elbow, 0.5) + Vector((0, 0, 0.4)), elbow], [0.36, 0.3, 0.32], segments=8)
            sweep_radii(bones, [elbow, elbow.lerp(wrist, 0.5), wrist], [0.3, 0.24, 0.26], segments=8)
            for joint in (elbow, wrist):
                ball(bones, joint, 0.38, subdivisions=2)
            for toe in (-0.8, 0.0, 0.8):
                knuckle = Vector((CX + side * 13.6, y + toe, roof_clear(12.6, 0.25)))
                claw = Vector((CX + side * 15.15, y + toe * 1.2, EAVE - 0.1))
                tip = Vector((CX + side * 15.05, y + toe * 1.2, EAVE - 1.0))
                sweep_radii(bones, [wrist, knuckle, claw, tip], [0.15, 0.12, 0.09, 0.02], segments=6)
    # Wings: an arm to the wrist, four fingers fanning over the roof, tattered membrane between.
    for side in (-1, 1):
        root = Vector((CX + side * 1.5, -1.4, top + 0.3))
        wrist = Vector((CX + side * 7.5, -4.8, top + 3.2))
        sweep_radii(bones, [root, root.lerp(wrist, 0.5) + Vector((0, 0, 0.6)), wrist], [0.34, 0.28, 0.3], segments=8)
        ball(bones, wrist, 0.42, subdivisions=2)
        cylinder(bones, wrist, Vector((side * 0.3, -1, 0.6)), 1.2, 0.14, segments=6, radius_top=0.0)
        tips = [Vector((CX + side * 14.5, -13.0, 17.2)), Vector((CX + side * 17.2, -6.0, 15.4)),
                Vector((CX + side * 17.6, 2.5, 14.2)), Vector((CX + side * 15.8, 10.0, 13.6))]
        fingers = []
        for tip in tips:
            curve = [wrist.lerp(tip, t) + Vector((0, 0, 1.1 * math.sin(math.pi * t))) for t in arange(1, 1 / 8)]
            sweep_radii(bones, curve, [0.2 - 0.018 * k for k in range(len(curve))], segments=6)
            fingers.append(Polyline(curve))
        flank = Polyline([Vector((CX + side * 2.2, -1.0, top)), Vector((CX + side * 2.2, 9.0, top)), Vector((CX + side * 2.0, 19.0, top))])
        edges = fingers + [flank]
        for k in range(len(edges) - 1):
            a, b = edges[k], edges[k + 1]

            def sheet(u, v, a=a, b=b):
                pa, pb = a.at(a.length * u), b.at(b.length * u)
                p = pa.lerp(pb, v)
                sag = math.sin(math.pi * v) * u * 0.32 * (pa - pb).length
                return p.lerp(wrist, sag / max((p - wrist).length, 0.01)) - Vector((0, 0, 0.12))

            def keep(u, v, k=k):
                # Rips along the trailing edge make the membrane look ancient.
                return not (u > 0.55 and abs(math.sin(u * 23 + v * 17 + k * 3 + side)) > 0.82)
            grid_surface(membrane, sheet, 10, 6, keep=keep)
    # The skull: sculpted, hanging over the entrance, nose tilted down, with glowing sockets.
    tilt = Matrix.Translation((CX, -17.4, 14.2)) @ Matrix.Rotation(math.radians(28), 4, "X")
    for center, size in (((0, 0.6, 0.3), (1.25, 1.45, 1.05)), ((0.78, -0.25, 0.72), (0.5, 0.65, 0.32)), ((-0.78, -0.25, 0.72), (0.5, 0.65, 0.32)),
                         ((0, -1.6, -0.05), (0.78, 1.6, 0.58)), ((0, -3.0, 0.0), (0.58, 0.55, 0.48)), ((0.95, 0.0, -0.15), (0.42, 0.95, 0.42)),
                         ((-0.95, 0.0, -0.15), (0.42, 0.95, 0.42)), ((0, 0.45, -0.75), (0.85, 0.65, 0.38))):
        blob(skull_blobs, tilt @ Vector(center), Vector(size), subdivisions=3, lump=0.1, lump_scale=2.0, seed=sum(center) * 7)
    for side in (-1, 1):
        jaw = [tilt @ Vector((side * 0.62, 0.5, -0.75)), tilt @ Vector((side * 0.58, -1.0, -1.15)), tilt @ Vector((side * 0.42, -2.6, -1.1))]
        sweep_radii(skull_blobs, jaw, [0.3, 0.26, 0.22], segments=8)
        ball(eyes, tilt @ Vector((side * 0.78, -0.42, 0.44)), 0.38, subdivisions=2)
        horn = [tilt @ Vector(p) for p in ((side * 0.75, 0.9, 0.95), (side * 1.3, 2.2, 1.65), (side * 1.8, 3.5, 1.55), (side * 2.0, 4.6, 0.85), (side * 1.85, 5.2, 0.2))]
        sweep_radii(bones, horn, [0.42, 0.32, 0.22, 0.12, 0.03], segments=8)
        for k in range(6):
            y = -0.6 - 0.42 * k
            cylinder(bones, tilt @ Vector((side * (0.58 - 0.03 * k), y, -0.4)), tilt.to_3x3() @ Vector((0, 0, -1)), 0.5 - 0.04 * k, 0.08, segments=6, radius_top=0.0)
            cylinder(bones, tilt @ Vector((side * (0.5 - 0.03 * k), y, -0.95)), tilt.to_3x3() @ Vector((0, 0, 1)), 0.4 - 0.03 * k, 0.07, segments=6, radius_top=0.0)
    skull = fused_surface(coll, "DragonSkull", skull_blobs, voxel=0.11, lump_scale=1.6, lump_strength=0.06, rgb=BONE)
    return [finish(coll, "DragonBones", bones, BONE, hard=False), skull, soft(coll, "DragonWingMembrane", membrane, (0.32, 0.12, 0.1)),
            finish(coll, "DragonSkullEyes", eyes, (1.0, 0.25, 0.1), hard=False)]


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = build_structure(coll) + build_floor_and_head(coll) + build_screen(coll) + build_decor(coll) + build_skeleton(coll)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
