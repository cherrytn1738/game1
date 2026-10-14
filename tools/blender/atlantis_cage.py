# Training Ground 3, Sunken Atlantis: an underwater ruin. A fluted marble arcade under a
# shimmering bubble dome, a mosaic pitch lane on the sand, a giant clam that pitches from its
# open shell, a broken marble screen with a gold-ringed porthole, coral reefs, swaying kelp,
# a treasure chest, a giant trident, a school of fish circling overhead and drifting jellyfish.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the
# mesh names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "AtlantisCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\AtlantisCage.fbx"

MARBLE = (0.9, 0.9, 0.86)
GOLD = (0.95, 0.75, 0.25)
TEAL = (0.1, 0.62, 0.66)
DOME = (0.45, 0.85, 1.0)
rng = random.Random(11)

SPRING, CROWN = 9.6, 13.6              # arcade arches spring from the capitals; entablature on top
DOME_X = (LEFT_X - 0.9, RIGHT_X + 0.9)
DOME_WALL, DOME_PEAK = 14.9, 19.5


def column(bm, gold, base, height, radius, flutes=12):
    """A fluted marble column with a moulded base, a gold-banded capital and volutes."""
    b = Vector(base)
    box(bm, b + Vector((0, 0, 0.25)), (radius * 2.8, radius * 2.8, 0.5))
    torus(bm, b + Vector((0, 0, 0.62)), (0, 0, 1), radius * 1.15, 0.15, segments=24, minor_segments=6)
    z0, z1 = 0.7, height - 1.0
    count = flutes * 2
    rings = []
    for z in (z0, z0 + 0.15, (z0 + z1) / 2, z1 - 0.15, z1):
        taper = radius * (1 - 0.08 * (z - z0) / (z1 - z0))
        rings.append([bm.verts.new(b + Vector((math.cos(2 * math.pi * k / count) * taper * (0.9 if k % 2 else 1.0),
                                               math.sin(2 * math.pi * k / count) * taper * (0.9 if k % 2 else 1.0), z)))
                      for k in range(count)])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(count):
            j = (k + 1) % count
            bm.faces.new((r0[k], r0[j], r1[j], r1[k]))
    torus(gold, b + Vector((0, 0, z1 + 0.05)), (0, 0, 1), radius * 0.98, 0.1, segments=24, minor_segments=5)
    torus(bm, b + Vector((0, 0, z1 + 0.28)), (0, 0, 1), radius * 1.05, 0.17, segments=24, minor_segments=6)
    box(bm, b + Vector((0, 0, height - 0.3)), (radius * 2.6, radius * 2.6, 0.55))
    for side in (-1, 1):
        spiral = [b + Vector((side * radius * 1.25, 0, height - 0.45)) +
                  Vector((side * 0.32 * (1 - t) * math.cos(t * 9), 0, 0.32 * (1 - t) * math.sin(t * 9))) for t in arange(1, 0.08)]
        for y_offset in (-radius * 1.05, radius * 1.05):
            sweep(gold, [p + Vector((0, y_offset, 0)) for p in spiral], 0.06, segments=5)


def broken_column(bm, base, height, radius, rng):
    b = Vector(base)
    box(bm, b + Vector((0, 0, 0.25)), (radius * 2.8, radius * 2.8, 0.5))
    lathe(bm, [(0, 0.5), (radius, 0.5), (radius * 0.96, height)] + [(radius * 0.5, height + 0.25), (0, height + 0.1)], 14,
          transform=Matrix.Translation(b), wobble=0.1, seed=rng.random() * 9)


def arch_ring(bm, x, ya, yb, spring, width=0.9, depth=0.7):
    r = (yb - ya) / 2
    center = Vector((x, (ya + yb) / 2, spring))
    points = [center + Vector((0, -r * math.cos(t), r * math.sin(t))) for t in [math.pi * i / 20 for i in range(21)]]
    sweep_profile(bm, points, [(-depth / 2, -width / 2), (depth / 2, -width / 2), (depth / 2, width / 2), (-depth / 2, width / 2)])


DOME_PROFILE = Polyline([Vector((DOME_X[0], 0, z)) for z in arange(DOME_WALL, 1.5)] +
                        [Vector(((DOME_X[0] + DOME_X[1]) / 2 - (DOME_X[1] - DOME_X[0]) / 2 * math.cos(t), 0,
                                 DOME_WALL + (DOME_PEAK - DOME_WALL) * math.sin(t))) for t in [math.pi * i / 24 for i in range(1, 24)]] +
                        [Vector((DOME_X[1], 0, z)) for z in reversed(arange(DOME_WALL, 1.5))])


def dome_height(x):
    cx, a = (DOME_X[0] + DOME_X[1]) / 2, (DOME_X[1] - DOME_X[0]) / 2
    if abs(x - cx) >= a:
        return DOME_WALL
    return DOME_WALL + (DOME_PEAK - DOME_WALL) * math.sqrt(1 - ((x - cx) / a) ** 2)


def build_architecture(coll):
    marble, gold, dome, door = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for x in (LEFT_X, RIGHT_X):
        for y in HOOPS:
            column(marble, gold, (x, y, 0), SPRING, 0.62)
        for a, b in zip(HOOPS, HOOPS[1:]):
            arch_ring(marble, x, a, b, SPRING)
        box(marble, (x, (BACK_Y + FRONT_Y) / 2, CROWN + 0.5), (1.3, FRONT_Y - BACK_Y + 1.6, 1.0))
        box(marble, (x, (BACK_Y + FRONT_Y) / 2, CROWN + 1.12), (1.7, FRONT_Y - BACK_Y + 2.2, 0.26))
        box(gold, (x + (0.66 if x > 0 else -0.66), (BACK_Y + FRONT_Y) / 2, CROWN + 0.5), (0.05, FRONT_Y - BACK_Y + 1.6, 0.32))
    for y in (BACK_Y, FRONT_Y):
        for x in (-4.5, 7.5):
            column(marble, gold, (x, y, 0), CROWN, 0.55)
        box(marble, (-1.0, y, CROWN + 0.5), (RIGHT_X - LEFT_X + 1.6, 1.3, 1.0))
        box(marble, (-1.0, y, CROWN + 1.12), (RIGHT_X - LEFT_X + 2.2, 1.7, 0.26))
        box(gold, (-1.0, y + (0.66 if y > 0 else -0.66), CROWN + 0.5), (RIGHT_X - LEFT_X + 1.6, 0.05, 0.32))
    # A small temple doorway in the batter-end wall.
    for x in DOOR[:2]:
        column(door, gold, (x, BACK_Y, 0), 7.4, 0.36, flutes=10)
    box(door, ((DOOR[0] + DOOR[1]) / 2, BACK_Y, 7.75), (DOOR[1] - DOOR[0] + 1.2, 0.9, 0.7))
    box(gold, ((DOOR[0] + DOOR[1]) / 2, BACK_Y - 0.46, 7.75), (DOOR[1] - DOOR[0] + 0.6, 0.04, 0.22))

    # The bubble dome: a barrel vault over the arcade with flat ends (door cut in the batter end).
    y0, y1 = BACK_Y - 1.0, FRONT_Y + 1.0
    grid_surface(dome, lambda u, v: DOME_PROFILE.at(v * DOME_PROFILE.length) + Vector((0, y0 + (y1 - y0) * u, 0)), 32, 46)
    for y, has_door in ((y0, True), (y1, False)):
        def end(u, v, y=y):
            x = DOME_X[0] + (DOME_X[1] - DOME_X[0]) * u
            return Vector((x, y, min(v * DOME_PEAK, dome_height(x))))
        def keep(u, v, has_door=has_door):
            x = DOME_X[0] + (DOME_X[1] - DOME_X[0]) * u
            return not (has_door and DOOR[0] < x < DOOR[1] and v * DOME_PEAK < DOOR[2] + 0.2)
        grid_surface(dome, end, 32, 20, keep=keep)
    return [finish(coll, "AtlantisMarble", marble, MARBLE, hard=True), finish(coll, "AtlantisDoorway", door, MARBLE, hard=True),
            finish(coll, "AtlantisGold", gold, GOLD, hard=False), soft(coll, "AtlantisDome", dome, DOME)]


def build_floor(coll):
    tiles = {"AtlantisTilesTeal": bmesh.new(), "AtlantisTilesWhite": bmesh.new(), "AtlantisTilesGold": bmesh.new()}
    shells, stars, plate = bmesh.new(), bmesh.new(), bmesh.new()
    pitch, size = 0.5625, 0.5
    x0, y0 = PITCH.x - 2.25, -4.0
    for i in range(8):
        for j in range(53):
            if i in (0, 7):
                name = "AtlantisTilesTeal"
            elif (j + 2 * abs(i - 3.5)) % 7 < 1:
                name = "AtlantisTilesGold"
            elif (j + abs(i - 3.5)) % 7 < 1:
                name = "AtlantisTilesTeal"
            else:
                name = "AtlantisTilesWhite"
            box(tiles[name], (x0 + pitch * (i + 0.5), y0 + pitch * (j + 0.5), 0.028), (size, size, 0.016))
    home_plate(plate, 0.08)
    # Shells and starfish scattered on the sand, clear of the lane and the batter's boxes.
    placed = 0
    while placed < 34:
        x, y = rng.uniform(LEFT_X - 4, RIGHT_X + 4), rng.uniform(BACK_Y - 3, FRONT_Y + 4)
        if PITCH.x - 3.2 < x < PITCH.x + 3.2 and -4.5 < y < 27:
            continue
        if -4 < x < 10 and -5 < y < 5:
            continue
        placed += 1
        heading = rng.uniform(0, 2 * math.pi)
        if placed % 3 == 0:
            arms = []
            for k in range(10):
                a = heading + math.pi * k / 5
                r = 0.42 if k % 2 == 0 else 0.17
                arms.append((x + math.cos(a) * r, y + math.sin(a) * r))
            prism(stars, arms, 0.0, 0.08)
        else:
            def scallop(u, v, x=x, y=y, heading=heading):
                angle = heading + (v - 0.5) * 2.4
                r = 0.38 * u * (1 + 0.06 * math.cos(v * 40))
                return Vector((x + math.cos(angle) * r, y + math.sin(angle) * r, 0.02 + 0.12 * math.sin(math.pi * u) * (1 - abs(v - 0.5))))
            grid_surface(shells, scallop, 4, 10)
    return [soft(coll, name, bm, color) for name, bm, color in (
                ("AtlantisTilesTeal", tiles["AtlantisTilesTeal"], TEAL), ("AtlantisTilesWhite", tiles["AtlantisTilesWhite"], (0.95, 0.95, 0.92)),
                ("AtlantisTilesGold", tiles["AtlantisTilesGold"], GOLD))] + [
            soft(coll, "AtlantisShells", shells, (1.0, 0.82, 0.75)), finish(coll, "AtlantisStarfish", stars, (1.0, 0.5, 0.25), bevel_width=0.02),
            finish(coll, "AtlantisPlate", plate, MARBLE, bevel_width=0.02)]


def build_clam(coll):
    outer, inner, pearl, rock, coral = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    hinge, radius, spread = Vector((PITCH.x, PITCH.y + 3.4, 2.4)), 2.7, math.radians(72)

    def shell(u, v, sign, lift, opening):
        """One cupped, ribbed half: flat at the hinge and along the scalloped rim, deepest in the middle."""
        angle = (v - 0.5) * 2 * spread
        r = radius * u * (1 + 0.035 * math.cos(angle * 18) * u)
        bulge = 1.1 * math.sin(math.pi * u) ** 0.7 * math.cos((v - 0.5) * math.pi) ** 0.6
        ridge = 0.07 * abs(math.sin(angle * 9)) * math.sin(math.pi * u)
        local = Vector((math.sin(angle) * r, -math.cos(angle) * r, sign * (bulge + ridge) + lift))
        return hinge + Matrix.Rotation(opening, 3, "X") @ local

    grid_surface(inner, lambda u, v: shell(u, v, -1, 0.0, 0.0), 14, 28)
    grid_surface(outer, lambda u, v: shell(u, v, -1, -0.09, 0.0), 14, 28)
    grid_surface(inner, lambda u, v: shell(u, v, 1, 0.0, math.radians(-55)), 14, 28)
    grid_surface(outer, lambda u, v: shell(u, v, 1, 0.09, math.radians(-55)), 14, 28)
    torus(outer, hinge + Vector((0, 0.05, 0.02)), (1, 0, 0), 0.45, 0.22, segments=12, minor_segments=6)
    ball(pearl, (PITCH.x, PITCH.y + 2.5, 2.15), 0.5, subdivisions=3)
    blob(rock, Vector((PITCH.x, PITCH.y + 3.0, 0.7)), Vector((2.5, 2.2, 1.05)), subdivisions=3, lump=0.25, seed=4.0, floor=0.0)
    for dx, dy in ((-2.1, 1.4), (2.2, 1.0), (-1.2, 2.4), (1.0, 2.6), (-2.6, -0.2)):
        branching(coral, Vector((PITCH.x + dx, PITCH.y + 3.0 + dy, 0.5)), 1.6, rng, levels=2, radius=0.12)
    return [soft(coll, "AtlantisClamOuter", outer, (0.95, 0.55, 0.62)), soft(coll, "AtlantisClamInner", inner, (1.0, 0.9, 0.95)),
            finish(coll, "AtlantisPearl", pearl, (1.0, 0.97, 0.97), hard=False), finish(coll, "AtlantisRock", rock, (0.38, 0.47, 0.5), hard=False),
            finish(coll, "AtlantisCoralPink", coral, (1.0, 0.45, 0.6), hard=False)]


def branching(bm, base, height, rng, levels=3, radius=0.2):
    def grow(start, direction, length, r, level):
        end = start + direction * length
        middle = start.lerp(end, 0.5) + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * length * 0.12
        sweep_radii(bm, [start, middle, end], [r, r * 0.88, r * 0.75], segments=6)
        if level == 0:
            ball(bm, end, r * 0.8, subdivisions=1)
            return
        for _ in range(2 + (rng.random() < 0.35)):
            d = (direction + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 0.4))) * 0.75)
            d.z = abs(d.z) + 0.35
            grow(end, d.normalized(), length * 0.74, r * 0.72, level - 1)
    grow(Vector(base), Vector((0, 0, 1)), height * 0.42, radius, levels)


def kelp(bm, base, height, rng, stalks=3):
    for s in range(stalks):
        start = Vector(base) + Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0))
        top = start + Vector((rng.uniform(-1.2, 1.2), rng.uniform(-1.2, 1.2), height * rng.uniform(0.75, 1.0)))
        path = wavy(start, top, 26, 0.45, seed=rng.random() * 20)
        frames = sweep_frames(path)
        left, right = [], []
        for i, (p, (t, n, b)) in enumerate(zip(path, frames)):
            w = 0.22 * (1 - 0.6 * i / len(path))
            twist = i * 0.35
            across = n * math.cos(twist) + b * math.sin(twist)
            left.append(p - across * w)
            right.append(p + across * w)
        double_sided_strip(bm, left, right)
        for i in range(3, len(path) - 2, 3):
            side = 1 if i % 2 else -1
            direction = (frames[i][1] * side + Vector((0, 0, 0.9))).normalized()
            leaf(bm, path[i], direction, frames[i][2], rng.uniform(0.9, 1.4), 0.38)


def build_screen(coll):
    screen, gold, weed = bmesh.new(), bmesh.new(), bmesh.new()
    # Kept low so the clam shows above it (the invisible screen block is unchanged).
    slab_with_window(screen, PITCH.x - 3.5, PITCH.x + 3.5, 0.0, 4.8, (PITCH.x, PITCH.z), WINDOW + 0.05, SCREEN_Y, 0.6,
                     segments=56, top_noise=0.4, seed=2.0)
    for y in (SCREEN_Y - 0.32, SCREEN_Y + 0.32):
        torus(gold, (PITCH.x, y, PITCH.z), (0, 1, 0), WINDOW + 0.12, 0.12, segments=28, minor_segments=6)
    for z in (0.7,):
        box(gold, (PITCH.x, SCREEN_Y - 0.31, z), (6.8, 0.04, 0.22))
        for k in range(14):
            box(gold, (PITCH.x - 3.25 + k * 0.5, SCREEN_Y - 0.33, z + 0.28 * (1 if k % 2 else -1) * 0.5), (0.18, 0.03, 0.12))
    kelp(weed, (PITCH.x - 3.2, SCREEN_Y - 0.6, 0), 3.2, rng, stalks=2)
    kelp(weed, (PITCH.x + 3.3, SCREEN_Y - 0.6, 0), 2.6, rng, stalks=2)
    return [finish(coll, "AtlantisScreen", screen, MARBLE, hard=True), finish(coll, "AtlantisScreenGold", gold, GOLD, hard=False),
            soft(coll, "AtlantisScreenWeed", weed, (0.35, 0.55, 0.2))]


def build_decor(coll):
    objects = []
    coral_pink, coral_orange, sponge, marble, chest, chest_gold, gems, amphora = (bmesh.new() for _ in range(8))
    trident, pedestal = bmesh.new(), bmesh.new()
    # Coral reefs inside (clear of the lane and camera) and along the outside of the colonnade.
    for base, height in (((-12.8, 20.5, 0), 3.2), ((-11.4, 25.5, 0), 2.4), ((12.0, 14.0, 0), 2.2), ((-19.5, 2.0, 0), 4.2),
                         ((-19.8, 22.0, 0), 3.6), ((18.6, -6.0, 0), 3.8), ((18.4, 18.0, 0), 4.4), ((-5.0, 37.5, 0), 3.4),
                         ((11.0, 37.0, 0), 3.0)):
        branching(coral_pink, base, height, rng, levels=3, radius=0.2)
    for center, size in (((-13.6, 23.0, 0.5), (1.1, 1.0, 0.75)), ((-20.2, 12.0, 0.6), (1.6, 1.3, 1.0)),
                         ((18.8, 7.0, 0.6), (1.4, 1.4, 0.9)), ((15.5, 36.5, 0.5), (1.2, 1.0, 0.7)), ((-18.8, 34.0, 0.6), (1.5, 1.2, 0.9))):
        blob(coral_orange, Vector(center), Vector(size), subdivisions=3, lump=0.35, lump_scale=4.0, seed=rng.random() * 9, floor=0.0)
    for base in ((-12.2, 28.5, 0), (12.6, 10.5, 0), (-20.4, 28.0, 0), (19.2, 26.0, 0), (-20.0, -10.0, 0)):
        for k in range(4):
            h = rng.uniform(0.9, 2.2)
            p = Vector(base) + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0))
            lathe(sponge, [(0, 0), (0.28, 0), (0.3, h), (0.22, h), (0.2, 0.15), (0, 0.15)], 10, transform=Matrix.Translation(p))
    # Ruins: broken columns and a fallen drum outside the arcade.
    broken_column(marble, (-20.0, 30.5, 0), 5.0, 0.6, rng)
    broken_column(marble, (18.6, 32.0, 0), 3.2, 0.6, rng)
    broken_column(marble, (-20.2, -15.5, 0), 2.4, 0.55, rng)
    cylinder(marble, (-21.6, 16.0, 0.55), (0.25, 1, 0.0), 3.2, 0.55, segments=16)
    # Treasure chest spilling gold, outside the machine-end corner.
    c = Vector((16.6, 38.0, 0))
    box(chest, c + Vector((0, 0, 0.55)), (2.2, 1.4, 1.1))
    # The lid swings up and back about its rear hinge.
    box(chest, c + Vector((0, 0.7, 1.1)) + Vector((0, 0.35, 0.63)), (2.2, 1.4, 0.35), Matrix.Rotation(math.radians(-105), 4, "X"))
    for dx in (-0.8, 0.8):
        box(chest_gold, c + Vector((dx, 0, 0.55)), (0.18, 1.46, 1.14))
    blob(chest_gold, c + Vector((0, 0, 1.05)), Vector((0.95, 0.6, 0.35)), subdivisions=2, lump=0.3, seed=3.0)
    blob(chest_gold, c + Vector((-0.6, -1.4, 0.15)), Vector((1.3, 0.9, 0.35)), subdivisions=2, lump=0.3, seed=5.0, floor=0.0)
    for k in range(18):
        p = c + Vector((rng.uniform(-2.0, 1.4), rng.uniform(-2.6, -0.8), 0.02))
        cylinder(chest_gold, p, (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 1), 0.05, 0.16, segments=10)
    for p in (c + Vector((0.3, 0.1, 1.35)), c + Vector((-0.4, -0.2, 1.3)), c + Vector((-1.0, -1.6, 0.4))):
        hex_crystal(gems, Vector(p), Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 1)), 0.45, 0.14)
    # Amphorae at the inside corners of the machine end and outside.
    for base, scale in (((-14.4, 31.6, 0), 1.0), ((12.6, 31.4, 0), 0.85), ((19.0, 13.0, 0), 1.1), ((-21.0, 7.0, 0), 0.9)):
        s = scale
        lathe(amphora, [(0, 0), (0.25 * s, 0), (0.55 * s, 0.6 * s), (0.6 * s, 1.1 * s), (0.4 * s, 1.6 * s), (0.18 * s, 1.85 * s),
                        (0.24 * s, 2.0 * s), (0.2 * s, 2.05 * s), (0, 1.95 * s)], 14, transform=Matrix.Translation(base))
        for side in (-1, 1):
            sweep(amphora, [Vector(base) + Vector((side * 0.2 * s, 0, 1.85 * s)), Vector(base) + Vector((side * 0.55 * s, 0, 1.75 * s)),
                            Vector(base) + Vector((side * 0.5 * s, 0, 1.3 * s))], 0.05 * s, segments=5)
    # The giant trident standing behind the machine end.
    t = Vector((PITCH.x, 40.5, 0))
    for k, (w, h) in enumerate(((3.6, 0.6), (2.8, 0.6), (2.0, 0.6))):
        box(pedestal, t + Vector((0, 0, 0.3 + 0.6 * k)), (w, w, h))
    tube(trident, t + Vector((0, 0, 1.8)), t + Vector((0, 0, 15.0)), 0.24, 10)
    torus(trident, t + Vector((0, 0, 14.8)), (0, 0, 1), 0.38, 0.1, segments=14, minor_segments=5)
    box(trident, t + Vector((0, 0, 15.2)), (3.0, 0.32, 0.36))
    for dx in (-1.35, 0.0, 1.35):
        top = 19.0 if dx == 0 else 18.0
        tube(trident, t + Vector((dx, 0, 15.2)), t + Vector((dx, 0, top)), 0.16, 8)
        cylinder(trident, t + Vector((dx, 0, top)), (0, 0, 1), 0.9, 0.3, segments=8, radius_top=0.0)
        cylinder(trident, t + Vector((dx, 0, top - 0.6)), (0.4 * (1 if dx >= 0 else -1), 0, -0.6), 0.5, 0.12, segments=6, radius_top=0.0)
    objects += [finish(coll, "AtlantisCoralReef", coral_pink, (1.0, 0.42, 0.55), hard=False),
                finish(coll, "AtlantisCoralOrange", coral_orange, (1.0, 0.6, 0.2), hard=False),
                finish(coll, "AtlantisSponges", sponge, (0.62, 0.35, 0.9), hard=False),
                finish(coll, "AtlantisRuins", marble, MARBLE, hard=True),
                finish(coll, "AtlantisChest", chest, (0.45, 0.28, 0.15), hard=True),
                finish(coll, "AtlantisTreasure", chest_gold, GOLD, hard=False),
                finish(coll, "AtlantisGems", gems, (1.0, 0.25, 0.6), hard=True),
                finish(coll, "AtlantisAmphorae", amphora, (0.78, 0.42, 0.25), hard=False),
                finish(coll, "AtlantisTrident", trident, GOLD, hard=True),
                finish(coll, "AtlantisPedestal", pedestal, MARBLE, bevel_width=0.05)]
    # Swaying kelp beds (separate meshes so each can sway on its own).
    for index, (base, height) in enumerate((((-20.2, -5.0, 0), 13.0), ((-20.6, 18.0, 0), 15.0), ((18.6, 2.0, 0), 12.0),
                                            ((18.8, 24.0, 0), 14.0), ((-11.0, 42.0, 0), 16.0), ((12.0, 43.0, 0), 13.0))):
        bm = bmesh.new()
        kelp(bm, base, height, rng, stalks=4)
        objects.append(soft(coll, "AtlantisKelp" + "ABCDEF"[index], bm, (0.3, 0.52, 0.16)))
    # A school of fish circling inside the dome, a smaller one the other way, and jellyfish.
    for name, count, ring, z, scale, color in (("AtlantisFishSchool", 10, 8.5, 16.6, 1.0, (1.0, 0.6, 0.15)),
                                               ("AtlantisFishSmall", 8, 5.0, 17.8, 0.7, (0.3, 0.75, 1.0))):
        bm = bmesh.new()
        center = Vector(((LEFT_X + RIGHT_X) / 2, (BACK_Y + FRONT_Y) / 2, z))
        for k in range(count):
            a = 2 * math.pi * k / count
            p = center + Vector((math.cos(a) * ring, math.sin(a) * ring, 0))
            heading = Vector((-math.sin(a), math.cos(a), 0))
            turn = Matrix.Translation(p) @ heading.to_track_quat("X", "Z").to_matrix().to_4x4()
            before = len(bm.verts)
            blob(bm, Vector((0, 0, 0)), Vector((0.65, 0.22, 0.32)) * scale, subdivisions=2)
            double_sided_poly(bm, [Vector((-0.55, 0, 0)) * scale, Vector((-1.05, 0, 0.32)) * scale, Vector((-0.9, 0, 0)) * scale,
                                   Vector((-1.05, 0, -0.32)) * scale])
            double_sided_poly(bm, [Vector((0.1, 0, 0.25)) * scale, Vector((-0.3, 0, 0.5)) * scale, Vector((-0.35, 0, 0.22)) * scale])
            transform_new(bm, before, turn)
        objects.append(soft(coll, name, bm, color))
    for index, (center, size) in enumerate((((-20.0, 8.0, 17.0), 1.3), ((18.6, 16.0, 15.0), 1.0), ((-7.0, 43.0, 19.0), 1.5))):
        bm = bmesh.new()
        c, s = Vector(center), size
        lathe(bm, [(0, s * 0.95), (s * 0.5, s * 0.85), (s * 0.95, s * 0.35), (s * 1.0, 0), (s * 0.8, s * 0.12), (0, s * 0.2)], 16,
              transform=Matrix.Translation(c))
        for k in range(7):
            a = 2 * math.pi * k / 7
            start = c + Vector((math.cos(a) * s * 0.6, math.sin(a) * s * 0.6, 0.05))
            sweep(bm, wavy(start, start + Vector((0, 0, -s * 3.2)), 10, 0.25 * s, seed=k + index * 10), 0.05 * s, segments=4)
        objects.append(soft(coll, "AtlantisJelly" + "ABC"[index], bm, (1.0, 0.55, 0.85)))
    return objects


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = build_architecture(coll) + build_floor(coll) + build_clam(coll) + build_screen(coll) + build_decor(coll)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
