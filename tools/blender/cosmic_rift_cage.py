# Training Ground 6, Cosmic Rift: a cage adrift at the edge of a galaxy. Dark chrome hex hoops
# studded with glowing star nodes, a shimmering force-field shell traced with constellations,
# a spinning galaxy on the floor, a portal whose swirling core launches each pitch, a
# holographic screen, a black hole with a spinning accretion disc, a ringed planet, planets
# orbiting overhead, drifting asteroids, floating crystals and nebula clouds.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the
# mesh names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "CosmicRiftCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\CosmicRiftCage.fbx"

CHROME = (0.16, 0.17, 0.22)
CYAN = (0.35, 0.9, 1.0)
VIOLET = (0.6, 0.35, 1.0)
STAR = (1.0, 1.0, 1.0)
rng = random.Random(41)

WALL, PEAK = 9.0, 15.5
CX, A = (LEFT_X + RIGHT_X) / 2, (RIGHT_X - LEFT_X) / 2
HEX = [(0.24 * math.cos(math.pi * k / 3), 0.24 * math.sin(math.pi * k / 3)) for k in range(6)]


def profile_points(outset=0.0, step=0.75):
    """Squared-off superellipse hoop: vertical walls rounding into a flat-topped vault."""
    a, b = A + outset, PEAK - WALL + outset
    points = [Vector((CX - a, 0, z)) for z in arange(WALL, step)]
    for i in range(1, 41):
        t = math.pi * i / 40
        c, s = math.cos(t), math.sin(t)
        points.append(Vector((CX - a * math.copysign(abs(c) ** (2 / 3.2), c), 0, WALL + b * abs(s) ** (2 / 3.2))))
    points += [Vector((CX + a, 0, z)) for z in reversed(arange(WALL, step)[:-1])]
    return points


HOOP = Polyline(profile_points())
FIELD = Polyline(profile_points(0.35))


def field_height(x):
    best = 0.0
    for a, b in zip(FIELD.points, FIELD.points[1:]):
        if min(a.x, b.x) - 1e-6 <= x <= max(a.x, b.x) + 1e-6 and a.z > WALL * 0.5:
            t = 0.0 if abs(b.x - a.x) < 1e-9 else (x - a.x) / (b.x - a.x)
            best = max(best, a.z + (b.z - a.z) * t)
    return best if best else WALL


def star_shape(bm, center, normal, size):
    n = Vector(normal).normalized()
    side = n.cross(Vector((0.2, 0.3, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
    other = n.cross(side)
    points = []
    for k in range(8):
        r = size if k % 2 == 0 else size * 0.3
        a = math.pi * k / 4
        points.append(Vector(center) + (side * math.cos(a) + other * math.sin(a)) * r)
    double_sided_poly(bm, points)


def build_shell(coll):
    chrome, nodes, field, lines, stars, door, trim = (bmesh.new() for _ in range(7))
    for y in HOOPS:
        sweep_profile(chrome, [p + Vector((0, y, 0)) for p in HOOP.samples(0.6)], HEX)
        for t in (0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0):
            ball(nodes, HOOP.at(HOOP.length * t) + Vector((0, y, 0)), 0.36 if t in (0.0, 1.0) else 0.28, subdivisions=2)
    for t in (0.17, 0.35, 0.5, 0.65, 0.83):
        p = HOOP.at(HOOP.length * t)
        sweep_profile(chrome, [Vector((p.x, BACK_Y, p.z)), Vector((p.x, FRONT_Y, p.z))], [(u * 0.7, v * 0.7) for u, v in HEX])
    # The force field: the vault, its ends (door in the batter end), traced with constellations.
    y0, y1 = BACK_Y - 0.35, FRONT_Y + 0.35
    grid_surface(field, lambda u, v: FIELD.at(v * FIELD.length) + Vector((0, y0 + (y1 - y0) * u, 0)), 36, 56)
    xs = (FIELD.points[0].x, FIELD.points[-1].x)
    for y, has_door in ((y0, True), (y1, False)):
        def end(u, v, y=y):
            x = xs[0] + (xs[1] - xs[0]) * u
            return Vector((x, y, min(v * (PEAK + 0.4), field_height(x))))
        def keep(u, v, has_door=has_door):
            x = xs[0] + (xs[1] - xs[0]) * u
            return not (has_door and DOOR[0] < x < DOOR[1] and v * (PEAK + 0.4) < DOOR[2] + 0.3)
        grid_surface(field, end, 36, 18, keep=keep)

    def field_point(u, v):
        return FIELD.at(v * FIELD.length) + Vector((0, y0 + (y1 - y0) * u, 0))
    for _ in range(14):
        u, v = rng.uniform(0.05, 0.95), rng.uniform(0.08, 0.92)
        chain = [(u, v)]
        for _ in range(rng.randint(4, 6)):
            u = min(0.98, max(0.02, u + rng.uniform(-0.07, 0.07)))
            v = min(0.97, max(0.03, v + rng.uniform(-0.09, 0.09)))
            chain.append((u, v))
        for (ua, va), (ub, vb) in zip(chain, chain[1:]):
            path = []
            for i in range(9):
                t = i / 8
                p = field_point(ua + (ub - ua) * t, va + (vb - va) * t)
                outward = Vector((p.x - CX, 0, p.z - WALL * 0.6)).normalized()
                path.append(p + outward * 0.06)
            frames = sweep_frames(path)
            double_sided_strip(lines, [p - f[2] * 0.035 for p, f in zip(path, frames)], [p + f[2] * 0.035 for p, f in zip(path, frames)])
        for u, v in chain:
            p = field_point(u, v)
            outward = Vector((p.x - CX, 0, p.z - WALL * 0.6)).normalized()
            star_shape(stars, p + outward * 0.1, outward, rng.uniform(0.18, 0.32))
    # A hexagonal portal doorway with glowing trim.
    middle, half = (DOOR[0] + DOOR[1]) / 2, (DOOR[1] - DOOR[0]) / 2
    outline = [Vector((DOOR[0], BACK_Y, 0)), Vector((DOOR[0], BACK_Y, 6.4)), Vector((middle - half * 0.45, BACK_Y, 8.2)),
               Vector((middle + half * 0.45, BACK_Y, 8.2)), Vector((DOOR[1], BACK_Y, 6.4)), Vector((DOOR[1], BACK_Y, 0))]
    sweep_profile(door, outline, [(-0.3, -0.35), (0.3, -0.35), (0.3, 0.35), (-0.3, 0.35)])
    sweep(trim, [p + Vector((0, -0.4, 0)) for p in outline], 0.07, segments=6)
    return [finish(coll, "CosmicChrome", chrome, CHROME, hard=True), finish(coll, "CosmicNodes", nodes, CYAN, hard=False),
            soft(coll, "CosmicField", field, VIOLET), soft(coll, "CosmicConstellations", lines, CYAN), soft(coll, "CosmicStars", stars, STAR),
            finish(coll, "CosmicDoorway", door, CHROME, hard=True), finish(coll, "CosmicDoorTrim", trim, CYAN, hard=False)]


def build_galaxy(coll):
    arms, dots, core, plate = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    home_plate(plate, 0.08)
    center = Vector((CX, (BACK_Y + FRONT_Y) / 2, 0.012))
    radius = 13.6
    # Two spiral arms with point symmetry, so the disc turns about its own centre.
    for arm in range(2):
        base_angle = math.pi * arm
        for lane, width in ((0.0, 1.1), (0.55, 0.4)):
            path = []
            for i in range(60):
                t = i / 59
                r = 1.4 + t * (radius - 1.4)
                a = base_angle + t * 4.2 + lane
                path.append(center + Vector((math.cos(a) * r, math.sin(a) * r, 0)))
            frames = [Vector((-(path[min(i + 1, 59)] - path[max(i - 1, 0)]).y, (path[min(i + 1, 59)] - path[max(i - 1, 0)]).x, 0)).normalized()
                      for i in range(60)]
            double_sided_strip(arms, [p - f * width * (1 - 0.6 * i / 60) / 2 for i, (p, f) in enumerate(zip(path, frames))],
                               [p + f * width * (1 - 0.6 * i / 60) / 2 for i, (p, f) in enumerate(zip(path, frames))])
    for _ in range(240):
        r = 1.0 + (rng.random() ** 0.7) * (radius - 1.0)
        a = rng.uniform(0, 2 * math.pi)
        offset = Vector((math.cos(a) * r, math.sin(a) * r, 0.004))
        size = rng.uniform(0.06, 0.16)
        for sign in (1, -1):
            p = center + offset * sign
            double_sided_poly(dots, [p + Vector((size, 0, 0)), p + Vector((0, size, 0)), p + Vector((-size, 0, 0)), p + Vector((0, -size, 0))])
    lathe(core, [(0, 0.016), (1.6, 0.016), (1.6, 0.012), (0, 0.012)], 32, transform=Matrix.Translation((center.x, center.y, 0)))
    return [soft(coll, "CosmicGalaxyArms", arms, (0.85, 0.45, 1.0)), soft(coll, "CosmicGalaxyStars", dots, STAR),
            finish(coll, "CosmicGalaxyCore", core, (1.0, 0.85, 0.95), hard=False), finish(coll, "CosmicPlate", plate, (0.85, 0.9, 1.0), bevel_width=0.02)]


def build_portal_and_screen(coll):
    ring, rim, core, stand, frame, panel, trim = (bmesh.new() for _ in range(7))
    c = Vector((PITCH.x, PITCH.y + 0.55, PITCH.z))
    torus(ring, c, (0, 1, 0), 1.75, 0.3, segments=40, minor_segments=8)
    torus(rim, c + Vector((0, -0.18, 0)), (0, 1, 0), 1.45, 0.07, segments=40, minor_segments=5)
    for k in range(8):
        a = 2 * math.pi * k / 8
        ball(rim, c + Vector((math.cos(a) * 2.05, 0, math.sin(a) * 2.05)), 0.14, subdivisions=1)
    # The swirling core: spiral vanes in the ring's plane (it turns about the pitch axis).
    for vane in range(4):
        path = []
        for i in range(24):
            t = i / 23
            a = vane * math.pi / 2 + t * 3.0
            r = 0.1 + t * 1.35
            path.append(c + Vector((math.cos(a) * r, 0.05, math.sin(a) * r)))
        left, right = [], []
        for i, p in enumerate(path):
            out = (p - c)
            out.y = 0
            out = out.normalized() if out.length > 1e-6 else Vector((1, 0, 0))
            w = 0.05 + 0.18 * (i / 23)
            left.append(p - out * w)
            right.append(p + out * w)
        double_sided_strip(core, left, right)
    # Two curved chrome arms hold the ring above a hexagonal emitter base.
    lathe(stand, [(0, 0), (1.5, 0), (1.5, 0.3), (1.1, 0.5), (0, 0.5)], 6, transform=Matrix.Translation((c.x, c.y + 0.6, 0)))
    for side in (-1, 1):
        sweep_profile(stand, [Vector((c.x + side * 0.9, c.y + 0.6, 0.4)), Vector((c.x + side * 2.0, c.y + 0.5, 1.6)),
                              Vector((c.x + side * 2.1, c.y + 0.3, c.z))], [(u * 0.8, v * 0.8) for u, v in HEX])
    # Holographic screen: a thin chrome frame around a glowing panel with the window.
    slab_with_window(panel, PITCH.x - 3.3, PITCH.x + 3.3, 0.35, 6.4, (PITCH.x, PITCH.z), WINDOW + 0.05, SCREEN_Y, 0.06, segments=48)
    corners = [Vector((PITCH.x - 3.4, SCREEN_Y, 0.0)), Vector((PITCH.x - 3.4, SCREEN_Y, 6.5)), Vector((PITCH.x + 3.4, SCREEN_Y, 6.5)),
               Vector((PITCH.x + 3.4, SCREEN_Y, 0.0))]
    sweep_profile(frame, corners, [(u * 0.6, v * 0.6) for u, v in HEX])
    box(frame, (PITCH.x, SCREEN_Y, 0.15), (7.2, 0.9, 0.3))
    torus(trim, (PITCH.x, SCREEN_Y - 0.06, PITCH.z), (0, 1, 0), WINDOW + 0.12, 0.06, segments=32, minor_segments=5)
    sweep(trim, [p + Vector((0, -0.18, 0)) for p in corners], 0.04, segments=5)
    return [finish(coll, "CosmicPortalRing", ring, CHROME, hard=False), finish(coll, "CosmicPortalRim", rim, CYAN, hard=False),
            soft(coll, "CosmicPortalCore", core, (1.0, 0.4, 0.95)), finish(coll, "CosmicPortalStand", stand, CHROME, hard=True),
            finish(coll, "CosmicScreenFrame", frame, CHROME, hard=True), finish(coll, "CosmicScreenPanel", panel, CYAN, hard=True),
            finish(coll, "CosmicScreenTrim", trim, CYAN, hard=False)]


def build_space(coll):
    objects = []
    # The black hole behind the machine end: a void, a lensing halo and a tilted accretion disc.
    hole = Vector((CX, 45.0, 20.0))
    void, halo, disc = bmesh.new(), bmesh.new(), bmesh.new()
    ball(void, hole, 2.4, subdivisions=4)
    torus(halo, hole, (0, -1, 0.1), 2.65, 0.1, segments=40, minor_segments=5)
    tilt = Matrix.Rotation(math.radians(70), 4, "X")
    for k, (r0, r1) in enumerate(((3.0, 3.8), (4.0, 5.0), (5.2, 6.6))):
        grid_surface(disc, lambda u, v, r0=r0, r1=r1: hole + (tilt @ Vector((math.cos(u * 2 * math.pi) * (r0 + (r1 - r0) * v),
                                                                              math.sin(u * 2 * math.pi) * (r0 + (r1 - r0) * v), 0))), 48, 1)
    objects += [finish(coll, "CosmicVoid", void, (0.0, 0.0, 0.0), hard=False), finish(coll, "CosmicHalo", halo, (1.0, 0.9, 0.8), hard=False),
                soft(coll, "CosmicAccretion", disc, (1.0, 0.55, 0.2))]
    # A ringed planet off the left wall.
    planet_at = Vector((LEFT_X - 3.4, 16.0, 18.5))
    planet, rings = bmesh.new(), bmesh.new()
    ball(planet, planet_at, 1.9, subdivisions=4)
    ball(planet, planet_at + Vector((0.6, -3.6, 2.4)), 0.45, subdivisions=2)
    ring_tilt = Matrix.Rotation(math.radians(64), 4, "Y") @ Matrix.Rotation(math.radians(20), 4, "X")
    grid_surface(rings, lambda u, v: planet_at + ring_tilt @ Vector((math.cos(u * 2 * math.pi) * (2.5 + 0.9 * v),
                                                                     math.sin(u * 2 * math.pi) * (2.5 + 0.9 * v), 0)), 48, 2)
    objects += [finish(coll, "CosmicPlanet", planet, (0.95, 0.6, 0.35), hard=False), soft(coll, "CosmicPlanetRings", rings, (1.0, 0.85, 0.6))]
    # Planets orbiting high overhead (opposite pairs keep each mesh centred on the orbit).
    orbit_center = Vector((CX, (BACK_Y + FRONT_Y) / 2, 22.5))
    for name, offset, radius, color in (("CosmicOrbitA", 0.0, 1.3, (0.3, 0.85, 0.75)), ("CosmicOrbitB", math.pi / 2, 0.9, (1.0, 0.45, 0.35))):
        bm = bmesh.new()
        for sign in (1, -1):
            a = offset + (0 if sign > 0 else math.pi)
            ball(bm, orbit_center + Vector((math.cos(a) * 13.5, math.sin(a) * 13.5, 0)), radius, subdivisions=3)
        objects.append(finish(coll, name, bm, color, hard=False))
    path = bmesh.new()
    torus(path, orbit_center, (0, 0, 1), 13.5, 0.04, segments=96, minor_segments=4)
    objects.append(finish(coll, "CosmicOrbitPath", path, (0.55, 0.7, 1.0), hard=False))
    # Drifting asteroids around the outside, floating crystals inside, and nebula clouds.
    # The rift itself: a jagged glowing tear across the sky above the machine end.
    tear, tear_core = bmesh.new(), bmesh.new()
    points = []
    for i in range(23):
        t = i / 22
        points.append(Vector((-15.0 + 29.0 * t, 37.0 + 2.0 * math.sin(t * 5), 26.0 + 3.0 * t + (0.9 if i % 2 else -0.9) * math.sin(math.pi * t))))
    for bm, width in ((tear, 1.3), (tear_core, 0.35)):
        left, right = [], []
        for i, p in enumerate(points):
            w = width * math.sin(math.pi * i / 22) ** 0.6 * (0.7 + 0.3 * (i % 3) / 2)
            left.append(p + Vector((0, 0.05 if bm is tear_core else 0.0, w)))
            right.append(p + Vector((0, 0.05 if bm is tear_core else 0.0, -w)))
        double_sided_strip(bm, left, right)
    objects += [soft(coll, "CosmicRiftTear", tear, (1.0, 0.3, 0.9)), soft(coll, "CosmicRiftCore", tear_core, STAR)]
    asteroids, crystals = bmesh.new(), bmesh.new()
    for _ in range(40):
        side = rng.choice(("left", "right", "back", "front"))
        if side == "left":
            p = Vector((rng.uniform(-22.0, -18.0), rng.uniform(-12, 34), rng.uniform(4, 17)))
        elif side == "right":
            p = Vector((rng.uniform(16.5, 20.0), rng.uniform(-12, 34), rng.uniform(4, 17)))
        elif side == "front":
            p = Vector((rng.uniform(-14, 12), rng.uniform(37, 41), rng.uniform(3, 12)))
        else:
            p = Vector((rng.uniform(-3, 12), rng.uniform(-18, -16), rng.uniform(10, 16)))
        s = rng.uniform(0.35, 0.9)
        rough_rock(asteroids, p, (s, s * rng.uniform(0.7, 1.0), s * rng.uniform(0.6, 0.9)), rng, subdivisions=1, jitter=0.3, floor=None)
    for base in ((11.5, 7.0, 2.2), (12.0, 16.5, 2.8), (-12.0, 20.0, 3.2)):
        b = Vector(base)
        for k in range(4):
            d = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 1)).normalized()
            hex_crystal(crystals, b + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0)), d, rng.uniform(0.9, 1.6), 0.2)
            hex_crystal(crystals, b, -d, rng.uniform(0.5, 0.9), 0.2)
    objects += [finish(coll, "CosmicAsteroids", asteroids, (0.36, 0.33, 0.42), hard=True), finish(coll, "CosmicCrystals", crystals, VIOLET, hard=True)]
    for name, center, color in (("CosmicNebulaPink", (-12.0, 46.0, 24.0), (1.0, 0.4, 0.75)), ("CosmicNebulaBlue", (10.0, 47.0, 25.0), (0.35, 0.6, 1.0))):
        blobs = bmesh.new()
        c = Vector(center)
        for k in range(6):
            blob(blobs, c + Vector((rng.uniform(-3.5, 3.5), rng.uniform(-1.0, 1.0), rng.uniform(-2.0, 2.0))), Vector((2.6, 1.4, 2.0)) * rng.uniform(0.8, 1.2),
                 subdivisions=2, lump=0.3, seed=rng.random() * 9)
        objects.append(fused_surface(coll, name, blobs, voxel=0.6, lump_scale=0.4, lump_strength=0.8, rgb=color))
    return objects


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = build_shell(coll) + build_galaxy(coll) + build_portal_and_screen(coll) + build_space(coll)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
