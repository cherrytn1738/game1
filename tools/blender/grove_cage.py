# Training Ground 2, Enchanted Grove: a fairy-tale clearing. Twisted living-wood arches,
# a woven vine net with glowing strands, leaves and blossoms, a stepping-stone path, a tree
# stump that pitches from its knot-hole, a wicker screen, glowing mushrooms and a great tree
# with a fairy door behind the machine end.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the
# mesh names are what TrainingCageStyles looks up for colors and materials.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "GroveCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\GroveCage.fbx"

BARK = (0.36, 0.24, 0.15)
VINE = (0.2, 0.42, 0.18)
LEAF = (0.27, 0.55, 0.22)
LEAF_LIGHT = (0.55, 0.75, 0.3)
GLOW = (0.55, 1.0, 0.75)
STONE = (0.62, 0.62, 0.58)
BLOSSOM = (0.98, 0.62, 0.8)

WALL, PEAK = 8.0, 16.0                 # vertical side height and the vault's peak
CX, A = (LEFT_X + RIGHT_X) / 2, (RIGHT_X - LEFT_X) / 2
rng = random.Random(7)


def profile_points(step=0.75):
    """The arch cross-section (x, z) from the left base, over the vault, to the right base."""
    points = [Vector((LEFT_X, 0, z)) for z in arange(WALL, step)]
    for i in range(1, 33):
        t = math.pi * i / 32
        points.append(Vector((CX - A * math.cos(t), 0, WALL + (PEAK - WALL) * math.sin(t))))
    points += [Vector((RIGHT_X, 0, z)) for z in reversed(arange(WALL, step)[:-1])]
    return points


PROFILE = Polyline(profile_points())


def profile_height(x):
    if abs(x - CX) >= A:
        return WALL
    return WALL + (PEAK - WALL) * math.sqrt(1 - ((x - CX) / A) ** 2)


def door_hole(x, z):
    half = (DOOR[1] - DOOR[0]) / 2
    middle = (DOOR[0] + DOOR[1]) / 2
    if abs(x - middle) > half - 0.25:
        return False
    return z < 6.5 + 1.6 * math.sqrt(max(0.0, 1 - ((x - middle) / half) ** 2)) - 0.15


def leaves_along(bm, points, chance, rng, spread=0.35, size=(0.5, 0.85)):
    for p in points:
        if rng.random() > chance:
            continue
        direction = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 0.4))).normalized()
        side = direction.cross(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 1))).normalized()
        offset = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * spread
        length = rng.uniform(*size)
        leaf(bm, p + offset, direction, side, length, length * 0.5)


def blossom(bm, center, normal, radius):
    n = Vector(normal).normalized()
    side = n.cross(Vector((0.3, 0.2, 1))).normalized()
    other = n.cross(side)
    for k in range(5):
        a = 2 * math.pi * k / 5
        direction = side * math.cos(a) + other * math.sin(a)
        petal_side = n.cross(direction)
        leaf(bm, Vector(center), direction, petal_side, radius, radius * 0.8)


def twisted_branch(bm, points, base_radius, tip_radius, strands=2, twist=4.0, splay=0.3):
    """Strands spiralling around a centreline: living wood that grew into shape."""
    line = Polyline(points)
    samples = line.samples(0.75)
    frames = sweep_frames(samples)
    count = len(samples)
    for k in range(strands):
        path, radii = [], []
        for i, (p, (tangent, normal, binormal)) in enumerate(zip(samples, frames)):
            s = i / (count - 1)
            thick = 1 - math.sin(math.pi * s)          # thick at both ends of an arch
            angle = 2 * math.pi * (k / strands + twist * s)
            reach = splay * (0.7 + 0.6 * thick)
            path.append(p + (normal * math.cos(angle) + binormal * math.sin(angle)) * reach)
            radii.append(tip_radius + (base_radius - tip_radius) * thick)
        sweep_radii(bm, path, radii, segments=7)


def roots(bm, base, outward, count, rng, length=1.8):
    for i in range(count):
        a = math.atan2(outward.y, outward.x) + rng.uniform(-1.1, 1.1)
        direction = Vector((math.cos(a), math.sin(a), 0))
        start = Vector(base) + Vector((0, 0, 0.9))
        points = [start, start + direction * length * 0.35 + Vector((0, 0, -0.45)),
                  start + direction * length * 0.75 + Vector((0, 0, -0.85)), start + direction * length + Vector((0, 0, -0.95))]
        sweep_radii(bm, points, [0.32, 0.22, 0.12, 0.05], segments=6)


def mushroom(stems, caps, spots, base, height, cap_radius, tilt=0.0, heading=0.0, rng=rng):
    turn = Matrix.Translation(Vector(base)) @ Matrix.Rotation(heading, 4, "Z") @ Matrix.Rotation(tilt, 4, "X")
    r = cap_radius * 0.22
    lathe(stems, [(0, 0), (r * 1.35, 0), (r, height * 0.45), (r * 0.85, height), (0, height)], 10, transform=turn)
    cap_height = cap_radius * 0.75
    lathe(caps, [(0, height - 0.05), (cap_radius * 0.35, height - 0.02), (cap_radius * 0.98, height + cap_height * 0.12),
                 (cap_radius, height + cap_height * 0.3), (cap_radius * 0.75, height + cap_height * 0.78),
                 (cap_radius * 0.35, height + cap_height * 0.97), (0, height + cap_height)], 14, transform=turn)
    for _ in range(max(3, int(cap_radius * 6))):
        a, up = rng.uniform(0, 2 * math.pi), rng.uniform(0.35, 0.85)
        local = Vector((math.cos(a) * cap_radius * (1.02 - up * 0.55), math.sin(a) * cap_radius * (1.02 - up * 0.55),
                        height + cap_height * (0.25 + up * 0.7)))
        ball(spots, turn @ local, cap_radius * rng.uniform(0.07, 0.11), subdivisions=1)


def tree(trunk_bm, canopy_blobs, base, height, radius, rng, limbs=4):
    """A gnarled trunk splitting into limbs; returns limb tips for the canopy."""
    b = Vector(base)
    lathe(trunk_bm, [(0, 0), (radius * 1.35, 0), (radius * 1.05, height * 0.08), (radius, height * 0.35),
                     (radius * 0.8, height * 0.75), (radius * 0.6, height), (0, height)], 18,
          transform=Matrix.Translation(b), wobble=radius * 0.12, seed=rng.random() * 10)
    tips = []
    for i in range(limbs):
        a = 2 * math.pi * i / limbs + rng.uniform(-0.4, 0.4)
        start = b + Vector((0, 0, height * 0.8))
        tip = b + Vector((math.cos(a) * radius * 2.6, math.sin(a) * radius * 2.6, height * 1.25))
        middle = start.lerp(tip, 0.5) + Vector((0, 0, height * 0.08))
        sweep_radii(trunk_bm, [start, middle, tip], [radius * 0.45, radius * 0.3, radius * 0.12], segments=8)
        tips.append(tip)
    for tip in tips + [b + Vector((0, 0, height * 1.3))]:
        blob(canopy_blobs, tip, Vector((radius * 2.0, radius * 2.0, radius * 1.5)) * rng.uniform(0.9, 1.15),
             subdivisions=2, lump=0.25, seed=rng.random() * 9)
        # Smaller clumps around each big one break up the silhouette.
        for _ in range(3):
            offset = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 0.8))).normalized() * radius * 1.9
            blob(canopy_blobs, tip + offset, Vector((radius, radius, radius * 0.8)) * rng.uniform(0.9, 1.3),
                 subdivisions=2, lump=0.3, seed=rng.random() * 9)
    roots(trunk_bm, b, Vector((1, 0, 0)), 6, rng, length=radius * 2.4)
    return tips


def build(coll):
    arches, branches, net, glow = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    leaves, leaves_light, blossoms = bmesh.new(), bmesh.new(), bmesh.new()

    # Living-wood arches with roots, and branches running the length of the vault.
    for y in HOOPS:
        points = [p + Vector((0, y, 0)) for p in PROFILE.points]
        twisted_branch(arches, points, 0.42, 0.2, strands=2, twist=4.5, splay=0.28)
        roots(branches, (LEFT_X, y, 0), Vector((-1, 0, 0)), 3, rng)
        roots(branches, (RIGHT_X, y, 0), Vector((1, 0, 0)), 3, rng)
        leaves_along(leaves, [p + Vector((0, y, 0)) for p in PROFILE.samples(0.45)], 0.55, rng)
        leaves_along(leaves_light, [p + Vector((0, y, 0)) for p in PROFILE.samples(0.6)], 0.35, rng)
    for t in (0.25, 0.5, 0.75):
        p = PROFILE.at(PROFILE.length * t)
        line = wavy((p.x, BACK_Y, p.z + 0.15), (p.x, FRONT_Y, p.z + 0.15), 40, 0.22, seed=t * 10)
        sweep_radii(branches, line, [0.17] * len(line), segments=7)
        leaves_along(leaves, line, 0.9, rng)
        leaves_along(leaves_light, line, 0.6, rng)
    for x in (LEFT_X, RIGHT_X):
        line = wavy((x, BACK_Y, WALL), (x, FRONT_Y, WALL), 40, 0.2, seed=x)
        sweep_radii(branches, line, [0.18] * len(line), segments=7)
        # Garlands of vine sag between the arches along the tops of the walls.
        for a, b in zip(HOOPS, HOOPS[1:]):
            garland = wavy((x, a, WALL - 0.2), (x, b, WALL - 0.2), 12, 0.08, seed=a + x, sag=1.3)
            sweep(net, garland, 0.06, segments=5)
            leaves_along(leaves, garland, 0.9, rng, spread=0.15, size=(0.35, 0.55))
            for p in garland[2:-2:3]:
                blossom(blossoms, p + Vector((0, 0, -0.1)), Vector((-1 if x < 0 else 1, 0, 0.3)), 0.22)

    # Woven vine net over the walls and vault, a sparse glowing weave, and both end walls.
    length = FRONT_Y - BACK_Y

    def vault(u, v):
        p = PROFILE.at(v)
        return Vector((p.x, BACK_Y + u, p.z))

    surface_net(net, vault, length, PROFILE.length, 2.4, 0.13, wobble=0.12, seed=1)
    surface_net(glow, vault, length, PROFILE.length, 7.2, 0.09, offset=1.2, lift=0.05)
    span = RIGHT_X - LEFT_X
    for y, outward, has_door in ((BACK_Y, -1, True), (FRONT_Y, 1, False)):
        def end_hole(u, v, has_door=has_door):
            x = LEFT_X + u
            return v > profile_height(x) - 0.1 or (has_door and door_hole(x, v))
        origin, u_axis, v_axis, normal = Vector((LEFT_X, y, 0.02)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, outward, 0))
        net_panel(net, origin, u_axis, v_axis, span, PEAK, normal, 2.4, 0.13, hole=end_hole, rope=0.0,
                  diamond=True, wobble=0.12, seed=y)
        net_panel(glow, origin + normal * 0.05, u_axis, v_axis, span, PEAK, normal, 7.2, 0.09, hole=end_hole, rope=0.0, diamond=True)
    # Leaves and blossoms caught in the weave.
    for _ in range(520):
        u, v = rng.uniform(0, length), rng.uniform(0, PROFILE.length)
        p = vault(u, v)
        bucket = leaves if rng.random() < 0.6 else leaves_light
        leaves_along(bucket, [p], 1.0, rng, spread=0.1, size=(0.4, 0.7))
        if rng.random() < 0.18:
            outward = Vector((p.x - CX, 0, p.z - WALL * 0.5)).normalized()
            blossom(blossoms, p + outward * 0.08, outward, 0.2)

    # Door arch of branches in the batter-end wall.
    middle, half = (DOOR[0] + DOOR[1]) / 2, (DOOR[1] - DOOR[0]) / 2
    door_line = [Vector((DOOR[0], BACK_Y, 0))] + [Vector((DOOR[0], BACK_Y, z)) for z in (2.0, 4.0, 6.5)]
    for i in range(1, 17):
        t = math.pi * i / 16
        door_line.append(Vector((middle - half * math.cos(t), BACK_Y, 6.5 + 1.6 * math.sin(t))))
    door_line += [Vector((DOOR[1], BACK_Y, z)) for z in (4.0, 2.0, 0.0)]
    twisted_branch(branches, door_line, 0.26, 0.14, strands=2, twist=3.0, splay=0.16)
    leaves_along(leaves, Polyline(door_line).samples(0.3), 0.9, rng, spread=0.25)
    for p in Polyline(door_line).samples(0.9)[3:-3]:
        blossom(blossoms, p + Vector((0, -0.2, 0)), Vector((0, -1, 0.2)), 0.24)

    objects = [finish(coll, "GroveArches", arches, BARK, hard=False), finish(coll, "GroveBranches", branches, BARK, hard=False),
               soft(coll, "GroveVineNet", net, VINE), soft(coll, "GroveGlowVines", glow, GLOW),
               soft(coll, "GroveLeaves", leaves, LEAF), soft(coll, "GroveLeavesLight", leaves_light, LEAF_LIGHT),
               soft(coll, "GroveBlossoms", blossoms, BLOSSOM)]
    return objects


def build_floor_and_machine(coll):
    stones, plate, stump, top, knot = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    stems, caps_violet, caps_teal, spots, moss = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()

    # Stepping stones down the pitch lane (clear of the batter's boxes).
    for i, y in enumerate([4.2, 6.6, 9.0, 11.4, 13.8, 16.2, 18.6]):
        center = Vector((PITCH.x + (0.35 if i % 2 else -0.35), y, 0))
        outline = []
        for k in range(14):
            a = 2 * math.pi * k / 14
            r = 0.92 + 0.12 * math.sin(k * 1.7 + i) + rng.uniform(-0.04, 0.04)
            outline.append((center.x + math.cos(a) * r, center.y + math.sin(a) * r * 0.85))
        prism(stones, outline, 0.0, 0.1)
    home_plate(plate, 0.08)

    # The pitching stump: ball leaves through the knot-hole at PITCH.
    base = Vector((PITCH.x, PITCH.y + 1.8, 0))
    lathe(stump, [(0, 0), (2.4, 0), (2.05, 0.35), (1.84, 0.9), (1.76, 2.2), (1.8, 3.8), (1.88, 4.45), (1.72, 4.6), (0, 4.6)],
          22, transform=Matrix.Translation(base), wobble=0.12, seed=3.0)
    torus(stump, (PITCH.x, PITCH.y - 0.02, PITCH.z), (0, 1, 0), 0.62, 0.15, segments=20, minor_segments=6)
    cylinder(knot, (PITCH.x, PITCH.y + 0.6, PITCH.z), (0, -1, 0), 0.62, 0.5, segments=16)
    roots(stump, base, Vector((0, 1, 0)), 6, rng, length=2.6)
    rings = [(0, 4.62)]
    for k in range(1, 7):
        rings.append((1.65 * k / 6, 4.62 - 0.02 * (k % 2)))
    rings.append((1.7, 4.55))
    lathe(top, rings, 22, transform=Matrix.Translation(base))
    blob(moss, base + Vector((-0.5, 0.4, 4.6)), Vector((1.2, 1.0, 0.35)), subdivisions=2, lump=0.3, seed=2.0)
    mushroom(stems, caps_violet, spots, base + Vector((0.6, 0.3, 4.55)), 0.9, 0.55, tilt=0.1)
    mushroom(stems, caps_teal, spots, base + Vector((0.95, -0.4, 4.55)), 0.6, 0.38, tilt=-0.2, heading=1.0)
    # Shelf fungi stepping up the side of the stump.
    for k, z in enumerate((1.4, 2.1, 2.8)):
        a = 0.3 + k * 0.35
        center = base + Vector((math.cos(a) * 1.75, math.sin(a) * 1.75, z))
        lathe(caps_teal, [(0, 0.12), (0.45, 0.05), (0.5, -0.02), (0, -0.04)], 10,
              transform=Matrix.Translation(center) @ Matrix.Diagonal((1.0, 0.6, 1.0, 1.0)))

    # Glowing mushrooms inside the cage (clear of the lane and camera) and outside it.
    for base_point, height, cap, tilt, caps in (
        ((-12.5, 22.0, 0), 2.2, 1.0, 0.1, caps_violet), ((-11.2, 23.6, 0), 1.3, 0.62, -0.15, caps_teal),
        ((-13.4, 24.8, 0), 1.0, 0.5, 0.2, caps_teal), ((-12.0, 27.6, 0), 1.8, 0.85, -0.1, caps_violet),
        ((11.6, 14.0, 0), 1.4, 0.7, 0.15, caps_violet), ((12.4, 15.4, 0), 0.9, 0.45, -0.2, caps_teal),
        ((-19.6, 29.0, 0), 4.8, 2.0, 0.1, caps_violet), ((-20.0, 25.4, 0), 2.6, 1.1, -0.2, caps_teal),
        ((18.2, 30.5, 0), 5.6, 2.2, -0.12, caps_teal), ((18.6, 26.8, 0), 2.2, 0.95, 0.2, caps_violet),
        ((-19.8, -4.0, 0), 3.4, 1.4, 0.15, caps_teal), ((18.4, 4.0, 0), 3.0, 1.3, -0.15, caps_violet),
    ):
        mushroom(stems, caps, spots, base_point, height, cap, tilt=tilt, heading=rng.uniform(0, 6.28))
    return [finish(coll, "GroveStones", stones, STONE, bevel_width=0.03), finish(coll, "GrovePlate", plate, (0.86, 0.85, 0.78), bevel_width=0.02),
            finish(coll, "GroveStump", stump, BARK, hard=False), finish(coll, "GroveStumpTop", top, (0.72, 0.55, 0.36), hard=False),
            finish(coll, "GroveKnot", knot, (0.06, 0.04, 0.03), hard=False), finish(coll, "GroveStems", stems, (0.93, 0.9, 0.8), hard=False),
            finish(coll, "GroveCapsViolet", caps_violet, (0.72, 0.4, 1.0), hard=False),
            finish(coll, "GroveCapsTeal", caps_teal, (0.25, 0.95, 0.85), hard=False),
            finish(coll, "GroveCapSpots", spots, WHITE, hard=False), finish(coll, "GroveMoss", moss, (0.32, 0.6, 0.25), hard=False)]


def build_screen(coll):
    screen, leaves, blossoms = bmesh.new(), bmesh.new(), bmesh.new()
    y, opening = SCREEN_Y, 1.05
    xs = [PITCH.x - 3.5 + 0.7 * i for i in range(11)]
    for i, x in enumerate(xs):
        top = 6.6 + 0.6 * math.sin(math.pi * i / 10) + rng.uniform(-0.15, 0.15)
        dx = abs(x - PITCH.x)
        if dx < opening:
            gap = math.sqrt(opening ** 2 - dx ** 2)
            pieces = [(0.0, PITCH.z - gap), (PITCH.z + gap, top)]
        else:
            pieces = [(0.0, top)]
        for z0, z1 in pieces:
            sweep_radii(screen, wavy((x, y, z0), (x, y, z1), 6, 0.04, seed=x), [0.11] * 7, segments=6)
    for row, z in enumerate([0.45 + 0.55 * k for k in range(12)]):
        points, run = [], []
        for k in range(61):
            x = xs[0] + (xs[-1] - xs[0]) * k / 60
            weave = 0.12 * math.sin(math.pi * (x - xs[0]) / 0.7 + row * math.pi)
            p = Vector((x, y + weave, z + 0.05 * math.sin(k * 0.7)))
            if (Vector((x, z)) - Vector((PITCH.x, PITCH.z))).length < opening + 0.08:
                if len(run) > 1:
                    points.append(run)
                run = []
            else:
                run.append(p)
        if len(run) > 1:
            points.append(run)
        for run in points:
            sweep(screen, run, 0.075, segments=5)
    sweep(screen, [Vector((xs[0] - 0.3, y, 0.22)), Vector((xs[-1] + 0.3, y, 0.22))], 0.26, segments=8)
    for x in (xs[0], xs[-1]):
        tube(screen, (x, y, 3.2), (x, y + 1.6, 0.0), 0.12, 6)
    torus(screen, (PITCH.x, y - 0.05, PITCH.z), (0, 1, 0), opening + 0.1, 0.16, segments=24, minor_segments=6)
    ring_points = [Vector((PITCH.x + math.cos(a) * (opening + 0.12), y - 0.15, PITCH.z + math.sin(a) * (opening + 0.12)))
                   for a in [2 * math.pi * k / 30 for k in range(30)]]
    leaves_along(leaves, ring_points, 1.0, rng, spread=0.15, size=(0.35, 0.55))
    for p in ring_points[::4]:
        blossom(blossoms, p + Vector((0, -0.1, 0)), Vector((0, -1, 0)), 0.2)
    return [finish(coll, "GroveScreen", screen, (0.55, 0.4, 0.26), hard=False),
            soft(coll, "GroveScreenLeaves", leaves, LEAF), soft(coll, "GroveScreenBlossoms", blossoms, BLOSSOM)]


def build_trees(coll):
    trunks, canopy_blobs, door, window, lantern = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    # The great fairy tree behind the machine end, its door facing into the cage.
    great = Vector((-7.0, 40.6, 0))
    tree(trunks, canopy_blobs, great, 15.0, 3.0, rng, limbs=5)
    for base, height, radius in (((-19.3, -16.8, 0), 8.0, 0.8), ((17.0, -16.8, 0), 7.0, 0.75)):
        tree(trunks, canopy_blobs, base, height, radius, rng, limbs=3)
    front = great.y - 3.3
    arch = [(-0.7, 0.0), (0.7, 0.0), (0.7, 1.6)]
    for i in range(1, 12):
        t = math.pi * i / 12
        arch.append((0.7 * math.cos(t), 1.6 + 0.7 * math.sin(t)))
    arch.append((-0.7, 1.6))
    prism(door, [(x, z) for x, z in arch], 0, 0.15)
    transform_new(door, 0, Matrix.Translation((great.x, front - 0.05, 0.02)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    for k in range(4):
        box(door, (great.x - 0.52 + k * 0.35, front - 0.14, 1.05), (0.04, 0.05, 2.0))
    ball(door, (great.x + 0.45, front - 0.18, 1.1), 0.08, subdivisions=1)
    for k in range(3):
        box(door, (great.x, front - 0.45 - k * 0.5, 0.05), (1.6 - k * 0.2, 0.45, 0.1))
    cylinder(window, (great.x, front + 0.1, 3.3), (0, -1, 0), 0.25, 0.4, segments=16)
    torus(door, (great.x, front - 0.12, 3.3), (0, 1, 0), 0.44, 0.07, segments=16, minor_segments=5)
    tube(trunks, (great.x + 2.4, front + 0.6, 6.2), (great.x + 2.6, front - 1.4, 5.0), 0.16, 6)
    tube(door, (great.x + 2.6, front - 1.4, 5.0), (great.x + 2.6, front - 1.4, 4.2), 0.03, 4)
    lathe(lantern, [(0, 3.4), (0.22, 3.55), (0.26, 3.9), (0.2, 4.1), (0, 4.2)], 10,
          transform=Matrix.Translation((great.x + 2.6, front - 1.4, 0)))
    canopy = fused_surface(coll, "GroveCanopy", canopy_blobs, voxel=0.58, lump_scale=0.45, lump_strength=0.7, rgb=LEAF)
    canopy_light = lit_shell(coll, canopy, "GroveCanopyLight", LEAF_LIGHT, threshold=0.5, lift=0.08, min_island=30)
    return [finish(coll, "GroveTrunks", trunks, BARK, hard=False), canopy, canopy_light,
            finish(coll, "GroveFairyDoor", door, (0.5, 0.3, 0.16), bevel_width=0.02),
            finish(coll, "GroveWindowGlow", window, (1.0, 0.82, 0.4), hard=False),
            finish(coll, "GroveLantern", lantern, (1.0, 0.85, 0.45), hard=False)]


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = build(coll) + build_floor_and_machine(coll) + build_screen(coll) + build_trees(coll)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
