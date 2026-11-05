# Training Ground 1 of World 2, Caveman Camp: a stone-age hunting camp. Pointed arches of crossed
# mammoth tusks and rib bones lashed with rope at the top, log poles along the walls and ridge, a
# rope net over the vault with stretched hides laced between the arches, a dirt floor with a
# flagstone path down the pitch lane, a log-and-stone catapult whose stone cup holds the ball at
# PITCH, a log palisade screen with a lashed sapling ring round the window, standing stones with
# cave paintings, spears, pots and bones inside, and round it: a campfire with a turning spit roast,
# a mammoth asleep beside the cage, skull totems, bone torches at the door and a hide drying rack.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "CavemanCampCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\CavemanCampCage.fbx"

IVORY = (0.93, 0.87, 0.72)
BONE = (0.88, 0.84, 0.74)
LOG = (0.42, 0.29, 0.18)
ROPE = (0.66, 0.53, 0.33)
HIDE = (0.66, 0.47, 0.29)
HIDE_DARK = (0.42, 0.28, 0.17)
STONE = (0.58, 0.56, 0.52)
ROCK = (0.44, 0.42, 0.4)
OCHRE = (0.74, 0.27, 0.12)
CHARCOAL = (0.08, 0.07, 0.07)
FUR = (0.45, 0.28, 0.16)
FUR_DARK = (0.3, 0.18, 0.1)
FLAME = (1.0, 0.56, 0.12)
FERN = (0.3, 0.52, 0.2)
DIRT = (0.4, 0.29, 0.19)
STRAW = (0.82, 0.69, 0.38)
rng = random.Random(41)

CX, A = (LEFT_X + RIGHT_X) / 2, (RIGHT_X - LEFT_X) / 2
PEAK = 16.0                                   # where the tusks cross over the middle
TUSK_HOOPS = (-14.0, 2.0, 18.0, 34.0)
BONE_HOOPS = (-6.0, 10.0, 26.0)
FIRE = Vector((17.6, 13.0, 0.0))              # the campfire outside the right wall
SPIT_Z = 2.5
MAMMOTH = Vector((-19.8, 23.5, 0.0))

LOOKS = {
    "CaveTusks": (IVORY, "smooth"), "CaveBones": (BONE, "smooth"), "CaveLogs": (LOG, "smooth"),
    "CaveRope": (ROPE, "smooth"), "CaveLacing": (ROPE, "smooth"), "CaveNet": (ROPE, "soft"), "CaveNetEnds": (ROPE, "soft"),
    "CaveHides": (HIDE, "soft"), "CaveHideSpots": (HIDE_DARK, "soft"),
    "CaveStones": (STONE, "hard"), "CaveRocks": (ROCK, "hard"), "CaveDark": (CHARCOAL, "smooth"),
    "CavePaintRed": (OCHRE, "soft"), "CavePaintBlack": (CHARCOAL, "soft"),
    "CaveDirt": (DIRT, "smooth"), "CaveStraw": (STRAW, "soft"), "CaveFerns": (FERN, "soft"),
    "CavePlate": ((0.9, 0.88, 0.8), "hard"), "CaveBall": (WHITE, "smooth"),
    "CaveScreen": (LOG, "smooth"), "CavePots": ((0.66, 0.4, 0.23), "smooth"),
    "CaveFeathers": ((0.86, 0.32, 0.2), "soft"),
    "CaveFlames": (FLAME, "smooth"), "CaveTorchFlames": (FLAME, "smooth"), "CaveEmbers": ((1.0, 0.32, 0.06), "hard"),
    "CaveSpitRoast": ((0.55, 0.26, 0.12), "smooth"), "CaveSpitBone": (BONE, "smooth"),
    "MammothFur": (FUR, "smooth"), "MammothFurDark": (FUR_DARK, "smooth"), "MammothTusks": (IVORY, "smooth"),
    "MammothEarLeft": (FUR_DARK, "smooth"), "MammothEarRight": (FUR_DARK, "smooth"), "MammothFace": (CHARCOAL, "smooth"),
}


# ---------- the arch shape ----------

def arch_xz(t, side, a=A, peak=PEAK, power=3.2):
    """A point on one side's arch: t 0 at the foot, 1 where it reaches the middle (past 1 the tip
    crosses over). The power keeps the wall nearly upright to banner height, then curls it in
    sharply, so the two sides meet in a point like crossed tusks."""
    reach = a * t ** power
    return (LEFT_X + reach if side < 0 else RIGHT_X - reach), peak * t


def vault_points(count=60, inset=0.6):
    """The vault's cross-section from the left foot, over the point, to the right foot."""
    left = [Vector((*arch_xz(i / count, -1, peak=PEAK - inset),)) for i in range(count + 1)]
    right = [Vector((*arch_xz(1 - i / count, 1, peak=PEAK - inset),)) for i in range(1, count + 1)]
    return [Vector((p.x, 0, p.y)) for p in left + right]


VAULT = Polyline(vault_points())


def vault(u, v):
    p = VAULT.at(v)
    return Vector((p.x, BACK_Y + u, p.z))


def vault_normal(s):
    t = VAULT.at(min(VAULT.length, s + 0.05)) - VAULT.at(max(0.0, s - 0.05))
    t.normalize()
    return Vector((-t.z, 0, t.x))


def vault_height(x):
    """The vault's height over x (for the end walls)."""
    best = 0.0
    for a, b in zip(VAULT.points, VAULT.points[1:]):
        if min(a.x, b.x) <= x <= max(a.x, b.x) and abs(b.x - a.x) > 1e-6:
            best = max(best, a.z + (b.z - a.z) * (x - a.x) / (b.x - a.x))
    return best


def curved_member(bm, y, side, radii, a=A, peak=PEAK, end=1.06, shift=0.24, samples=40):
    """One tusk or rib: a tapering tube along the arch whose tip crosses past the middle, leaning a
    little to its side of the hoop at the top so the two sides cross side by side."""
    points = []
    for i in range(samples + 1):
        # Denser samples near the tip, where the curve turns fastest.
        t = end * (1 - (1 - i / samples) ** 1.6)
        x, z = arch_xz(t, side, a, peak)
        points.append(Vector((x, y + side * shift * min(1.0, t) ** 4, z)))
    r0, r1 = radii
    sweep_radii(bm, points, [r0 + (r1 - r0) * (i / samples) ** 0.8 for i in range(samples + 1)], segments=10)
    return points


# ---------- small builders ----------

def flat_stone(bm, center, radius, rng, z1=0.07, sides=9, squash=0.85):
    outline = []
    spin = rng.uniform(0, math.pi)
    for k in range(sides):
        a = spin + 2 * math.pi * k / sides
        r = radius * rng.uniform(0.8, 1.08)
        outline.append((center[0] + math.cos(a) * r, center[1] + math.sin(a) * r * squash))
    prism(bm, outline, 0.0, z1)


def long_bone(bm, base, direction, length, radius):
    """A femur: a shaft with knobbly ends."""
    d = Vector(direction).normalized()
    transform = Matrix.Translation(Vector(base)) @ align_z(d)
    lathe(bm, [(0, 0), (radius * 1.7, 0.02 * length), (radius * 1.9, 0.08 * length), (radius * 1.1, 0.16 * length),
               (radius, 0.5 * length), (radius * 1.15, 0.84 * length), (radius * 2.0, 0.93 * length), (radius * 1.6, length), (0, length)],
          12, transform=transform)
    side = axes_of(d)[0]
    for end in (0.04, 0.96):
        ball(bm, Vector(base) + d * length * end + side * radius * 1.2, radius * 1.3, subdivisions=1)


def skull(m, center, scale=1.0, horns=False, facing=(0, -1, 0)):
    c, f = Vector(center), Vector(facing).normalized()
    side = f.cross(Vector((0, 0, 1))).normalized()
    blob(m["CaveBones"], c, Vector((0.55, 0.55, 0.5)) * scale, subdivisions=2, lump=0.05, seed=c.x)
    blob(m["CaveBones"], c + f * 0.45 * scale - Vector((0, 0, 0.22 * scale)), Vector((0.32, 0.32, 0.26)) * scale, subdivisions=1)
    for s in (-1, 1):
        ball(m["CaveDark"], c + f * 0.42 * scale + side * s * 0.22 * scale + Vector((0, 0, 0.06 * scale)), 0.13 * scale, subdivisions=1)
    ball(m["CaveDark"], c + f * 0.74 * scale - Vector((0, 0, 0.22 * scale)), 0.07 * scale, subdivisions=1)
    if horns:
        for s in (-1, 1):
            root = c + side * s * 0.45 * scale + Vector((0, 0, 0.2 * scale))
            sweep_radii(m["CaveBones"], [root, root + side * s * 0.55 * scale + Vector((0, 0, 0.15 * scale)),
                                         root + side * s * 0.8 * scale + Vector((0, 0, 0.6 * scale)) + f * 0.1 * scale],
                        [0.14 * scale, 0.1 * scale, 0.03 * scale], segments=8)


def flame(bm, base, height, radius, lean=(0, 0)):
    """A teardrop flame tongue."""
    b = Vector(base)
    tip = b + Vector((lean[0], lean[1], height))
    lathe(bm, [(0, 0), (radius * 0.8, height * 0.12), (radius, height * 0.3), (radius * 0.7, height * 0.6),
               (radius * 0.3, height * 0.85), (0, height)], 10,
          transform=Matrix.Translation(b) @ align_z(tip - b))


def fern(bm, base, count, length, rng):
    for k in range(count):
        a = 2 * math.pi * k / count + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, 1.0)).normalized()
        b = Vector(base)
        points = [b + d * length * t - Vector((0, 0, 0.5 * length * t * t)) for t in (0, 0.33, 0.66, 1.0)]
        stem = Polyline(points)
        for i in range(1, 9):
            p = stem.at(stem.length * i / 9)
            tangent = (stem.at(stem.length * i / 9 + 0.05) - p).normalized()
            side = tangent.cross(Vector((0, 0, 1))).normalized()
            w = length * 0.22 * (1 - i / 10)
            for s in (-1, 1):
                leaf(bm, p, side * s + tangent * 0.3, tangent, w, w * 0.4)


def lash(m, center, axis, radius, turns=3, spacing=0.12):
    e = Vector(axis).normalized()
    for k in range(turns):
        torus(m["CaveRope"], Vector(center) + e * (k - (turns - 1) / 2) * spacing, e, radius, 0.05, segments=12, minor_segments=4)


# ---------- the frame, net and hides ----------

def build_arches(m):
    tusks, bones, logs = m["CaveTusks"], m["CaveBones"], m["CaveLogs"]
    for y in TUSK_HOOPS + BONE_HOOPS:
        is_tusk = y in TUSK_HOOPS
        for side in (-1, 1):
            if is_tusk:
                points = curved_member(tusks, y, side, (0.58, 0.17))
            else:
                points = curved_member(bones, y, side, (0.34, 0.24), peak=PEAK - 0.3, end=1.04, shift=0.2)
                for p in (points[0], points[-1]):
                    ball(bones, p, 0.5, subdivisions=2)
                # Knuckles every third of the way, so a rib reads as bone rather than a pipe.
                for p in points[8:-4:9]:
                    torus(bones, p, (0, 1, 0), 0.3, 0.09, segments=14, minor_segments=5)
            # Rocks piled round the foot.
            foot = points[0]
            for k in range(5):
                a = 2 * math.pi * k / 5 + rng.uniform(-0.3, 0.3)
                rough_rock(m["CaveRocks"], foot + Vector((math.cos(a) * 0.85, math.sin(a) * 0.85, 0.25)),
                           Vector((0.55, 0.55, 0.42)) * rng.uniform(0.8, 1.2), rng, subdivisions=1, jitter=0.25, floor=0.0)
        # Rope binding where the two sides cross at the top.
        lash(m, (CX, y, PEAK - 0.05), (1, 0, 0), 0.62, turns=4, spacing=0.14)
    # Log poles along both walls and the ridge, bound to every hoop.
    for z in (3.4, 9.2):
        t = z / PEAK
        for side in (-1, 1):
            x, _ = arch_xz(t, side)
            x -= side * 0.45
            line = wavy((x, BACK_Y - 0.9, z), (x, FRONT_Y + 0.9, z), 36, 0.12, seed=z + side)
            sweep_radii(logs, line, [0.22] * len(line), segments=8)
            for y in TUSK_HOOPS + BONE_HOOPS:
                lash(m, (x, y, z), (0, 0, 1), 0.36, turns=2, spacing=0.14)
    ridge = wavy((CX, BACK_Y - 1.2, PEAK + 0.55), (CX, FRONT_Y + 1.2, PEAK + 0.55), 36, 0.1, seed=4.0)
    sweep_radii(logs, ridge, [0.26] * len(ridge), segments=8)


def hide(m, ya, yb, s0, s1, seed, out=0.16):
    """A hide stretched over the vault between two hoops, laced to them with rope."""
    u0, u1 = ya - BACK_Y + 0.6, yb - BACK_Y - 0.6

    def surface(a, b):
        u, s = u0 + (u1 - u0) * a, s0 + (s1 - s0) * b
        bulge = 0.28 * math.sin(math.pi * a) * math.sin(math.pi * b)
        return vault(u, s) + vault_normal(s) * (out - bulge)

    def keep(a, b):
        edge = min(a, 1 - a, b, 1 - b)
        return edge > 0.05 + 0.09 * (noise.noise(Vector((a * 5, b * 5, seed))) + 0.5)

    grid_surface(m["CaveHides"], surface, 16, 14, keep=keep)
    for _ in range(5):
        a, b = rng.uniform(0.25, 0.75), rng.uniform(0.25, 0.75)
        c = surface(a, b) + vault_normal(s0 + (s1 - s0) * b) * 0.03
        n = vault_normal(s0 + (s1 - s0) * b)
        e1 = Vector((0, 1, 0))
        e2 = n.cross(e1)
        r = rng.uniform(0.35, 0.7)
        double_sided_poly(m["CaveHideSpots"], [c + (e1 * math.cos(2 * math.pi * k / 9) + e2 * math.sin(2 * math.pi * k / 9))
                                               * r * rng.uniform(0.7, 1.1) for k in range(9)])
    for k in range(1, 8):
        b = k / 8
        s = s0 + (s1 - s0) * b
        for a, y in ((0.06, ya), (0.94, yb)):
            tube(m["CaveLacing"], surface(a, b), vault(y - BACK_Y, s) + vault_normal(s) * 0.25, 0.035, 4)


def build_net_and_hides(m):
    length = FRONT_Y - BACK_Y
    surface_net(m["CaveNet"], vault, length, VAULT.length, 1.9, 0.09, wobble=0.1, seed=3)
    span = RIGHT_X - LEFT_X
    middle, half = (DOOR[0] + DOOR[1]) / 2, (DOOR[1] - DOOR[0]) / 2
    for y, outward, has_door in ((BACK_Y, -1, True), (FRONT_Y, 1, False)):
        def end_hole(u, v, has_door=has_door):
            x = LEFT_X + u
            if v > vault_height(x) - 0.15:
                return True
            return has_door and abs(x - middle) < half - 0.2 and v < DOOR[2] + 0.4
        net_panel(m["CaveNetEnds"], Vector((LEFT_X, y, 0.05)), Vector((1, 0, 0)), Vector((0, 0, 1)), span, PEAK,
                  Vector((0, outward, 0)), 1.9, 0.09, hole=end_hole, rope=0.0, diamond=True, wobble=0.1, seed=y)
    s_top = VAULT.length / 2
    for ya, yb, s0, s1 in ((-6.0, 2.0, 0.5, 6.8), (10.0, 18.0, 0.5, 8.0), (26.0, 34.0, 0.5, 6.0)):
        hide(m, ya, yb, s0, s1, seed=ya)
    for ya, yb, s0, s1 in ((2.0, 10.0, VAULT.length - 7.2, VAULT.length - 0.5), (18.0, 26.0, VAULT.length - 7.6, VAULT.length - 0.5),
                           (-14.0, -6.0, VAULT.length - 6.0, VAULT.length - 0.6)):
        hide(m, ya, yb, s0, s1, seed=ya + 50)
    for ya, yb, s0, s1 in ((10.0, 18.0, s_top - 6.5, s_top + 6.0), (26.0, 34.0, s_top - 4.0, s_top + 5.0)):
        hide(m, ya, yb, s0, s1, seed=ya + 90, out=0.5)


def build_door(m):
    """Femur door posts, a lintel log with a horned skull, and a hide curtain rolled up above."""
    for x in (DOOR[0] - 0.35, DOOR[1] + 0.35):
        long_bone(m["CaveBones"], (x, BACK_Y - 0.25, 0.0), (0, 0, 1), DOOR[2] + 0.4, 0.2)
    sweep_radii(m["CaveLogs"], wavy((DOOR[0] - 1.0, BACK_Y - 0.3, DOOR[2] + 0.5), (DOOR[1] + 1.0, BACK_Y - 0.3, DOOR[2] + 0.5), 8, 0.05, seed=2),
                [0.27] * 9, segments=8)
    for x in (DOOR[0] - 0.35, DOOR[1] + 0.35):
        lash(m, (x, BACK_Y - 0.3, DOOR[2] + 0.5), (0, 1, 0), 0.38, turns=2)
    cylinder_x(m["CaveHides"], ((DOOR[0] + DOOR[1]) / 2, BACK_Y - 0.65, DOOR[2] + 0.0), DOOR[1] - DOOR[0] - 0.4, 0.32, 14)
    skull(m, ((DOOR[0] + DOOR[1]) / 2, BACK_Y - 0.6, DOOR[2] + 1.25), 1.1, horns=True)


# ---------- floor ----------

def build_floor(m):
    stones, dirt = m["CaveStones"], m["CaveDirt"]
    y = 4.2
    while y < 20.2:
        for x in (PITCH.x - 0.95, PITCH.x + 0.95):
            flat_stone(stones, (x + rng.uniform(-0.15, 0.15), y + rng.uniform(-0.2, 0.2)), rng.uniform(0.72, 0.88), rng)
        y += 1.55
    # A ring of flat stones round the plate's dirt circle, outside the batter's boxes.
    for k in range(26):
        a = 2 * math.pi * k / 26
        p = Vector((PITCH.x + math.cos(a) * 7.0, math.sin(a) * 4.6, 0))
        if p.y > 3.6 or abs(p.x - PITCH.x) > 6.4 or p.y < -3.6:
            flat_stone(stones, (p.x, p.y), rng.uniform(0.45, 0.6), rng, z1=0.06)
    for x0, x1 in ((LEFT_X + 0.8, LEFT_X + 3.4), (RIGHT_X - 3.2, RIGHT_X - 0.8)):
        for y in arange(44.0, 3.1):
            yy = BACK_Y + 2.0 + y
            if yy > FRONT_Y - 1.0:
                continue
            blob(dirt, Vector((rng.uniform(x0, x1), yy, 0.0)), Vector((rng.uniform(1.2, 2.0), rng.uniform(1.2, 2.0), rng.uniform(0.2, 0.4))),
                 subdivisions=2, lump=0.3, seed=yy + x0, floor=0.0)
            if rng.random() < 0.7:
                base = Vector((rng.uniform(x0, x1), yy + rng.uniform(-1, 1), 0.0))
                for _ in range(9):
                    a, lean = rng.uniform(0, 2 * math.pi), rng.uniform(0.25, 0.7)
                    tip = base + Vector((math.cos(a) * lean, math.sin(a) * lean, rng.uniform(0.6, 1.0)))
                    double_sided_strip(m["CaveStraw"], [base - Vector((0.04, 0, 0)), tip], [base + Vector((0.04, 0, 0)), tip + Vector((0.01, 0, 0))])
    # Scattered bones and pebbles by the walls.
    for x, y, a in ((-13.0, 2.0, 0.4), (-12.4, 18.6, 2.1), (11.8, 21.0, 1.0), (12.5, 31.0, -0.6), (-11.0, 32.0, 2.6)):
        long_bone(m["CaveBones"], (x, y, 0.12), (math.cos(a), math.sin(a), 0.0), 1.4, 0.07)
    for _ in range(40):
        x = rng.choice((rng.uniform(LEFT_X + 0.6, -10.0), rng.uniform(8.6, RIGHT_X - 0.6)))
        rough_rock(m["CaveRocks"], (x, rng.uniform(4.0, FRONT_Y - 1.0), 0.06), Vector((0.16, 0.16, 0.1)) * rng.uniform(0.8, 1.8), rng,
                   subdivisions=1, jitter=0.25, floor=0.0)
    home_plate(m["CavePlate"], 0.08)


# ---------- the catapult and the screen ----------

def build_catapult(m):
    logs, stones, rope = m["CaveLogs"], m["CaveStones"], m["CaveRope"]
    for x in (0.7, 5.3):
        tube(logs, (x, 23.2, 0.36), (x, 31.8, 0.36), 0.32, 10)
    for y in (23.8, 31.2):
        tube(logs, (0.0, y, 0.68), (6.0, y, 0.68), 0.26, 10)
        for x in (0.7, 5.3):
            lash(m, (x, y, 0.55), (0, 0, 1), 0.42, turns=2)
    # Solid stone wheels on stubby axles.
    for x in (-0.05, 6.05):
        for y in (24.6, 30.4):
            disc(stones, (x, y, 0.78), (1, 0, 0), 0.78, 0.36, segments=14)
            disc(m["CaveRocks"], (x + (0.2 if x > 3 else -0.2), y, 0.78), (1, 0, 0), 0.2, 0.18, segments=8)
    # A-frame uprights either side, and the padded stop beam across their tops.
    for x in (0.75, 5.25):
        lean = 0.2 if x < 3 else -0.2
        for y0 in (25.2, 28.8):
            tube(logs, (x, y0, 0.55), (x + lean, 27.0, 4.6), 0.22, 8)
        lash(m, (x + lean, 27.0, 4.45), (0, 1, 0), 0.32, turns=3)
    tube(logs, (0.3, 27.0, 4.7), (5.7, 27.0, 4.7), 0.24, 10)
    blob(m["CaveHides"], Vector((PITCH.x, 27.0, 4.7)), Vector((0.9, 0.55, 0.45)), subdivisions=2, lump=0.1, seed=6)
    # The torsion skein: rope wound round an axle at the back, the arm's foot clamped in it.
    tube(logs, (0.7, 29.6, 1.12), (5.3, 29.6, 1.12), 0.18, 8)
    for k in range(14):
        torus(rope, (2.2 + k * 0.12, 29.6, 1.12), (1, 0, 0), 0.42 + 0.04 * math.sin(k), 0.08, segments=14, minor_segments=5)
    # The throwing arm rising to its stone cup; the ball sits in the cup at PITCH.
    out = Vector((0, -1, 0.55)).normalized()
    cup_back = PITCH - out * 0.62
    sweep_radii(logs, [Vector((PITCH.x, 29.6, 1.12)), Vector((PITCH.x, 27.2, 1.95)), cup_back], [0.3, 0.26, 0.2], segments=10)
    for t in (0.35, 0.7):
        p = Vector((PITCH.x, 29.6, 1.12)).lerp(cup_back, t)
        lash(m, p, (cup_back - Vector((PITCH.x, 29.6, 1.12))).normalized(), 0.3, turns=2)
    lathe(stones, [(0, -0.66), (0.36, -0.58), (0.58, -0.32), (0.66, 0.02), (0.56, 0.04), (0.5, -0.24), (0.32, -0.44), (0, -0.5)], 16,
          transform=Matrix.Translation(PITCH) @ align_z(out))
    pitch_ball(m["CaveBall"])
    # A pile of round stones to throw, beside the catapult.
    for k, offset in enumerate(((0, 0, 0.36), (0.66, 0.1, 0.36), (0.3, 0.6, 0.36), (0.33, 0.25, 0.9), (-0.4, 0.55, 0.3))):
        ball(stones, Vector((7.2, 27.6, 0)) + Vector(offset), 0.36 if k != 4 else 0.3, subdivisions=2)


def build_screen(m):
    screen, rope = m["CaveScreen"], m["CaveRope"]
    y, opening = SCREEN_Y, 1.1
    xs = [PITCH.x - 3.3 + 0.6 * i for i in range(12)]
    for i, x in enumerate(xs):
        top = 6.1 + 0.45 * math.sin(i * 1.9) + rng.uniform(-0.1, 0.1)
        dx = abs(x - PITCH.x)
        pieces = [(0.0, PITCH.z - math.sqrt(opening ** 2 - dx ** 2)), (PITCH.z + math.sqrt(opening ** 2 - dx ** 2), top)] if dx < opening else [(0.0, top)]
        for k, (z0, z1) in enumerate(pieces):
            line = wavy((x, y, z0), (x, y, z1), 6, 0.03, seed=x)
            sweep_radii(screen, line, [0.27] * len(line), segments=8)
            if k == len(pieces) - 1:
                lathe(screen, [(0, 0), (0.27, 0), (0, 0.55)], 8, transform=Matrix.Translation((x, y, top)))
    for z in (1.0, 5.4):
        for dy in (-0.3, 0.3):
            line = [Vector((xs[0] - 0.35, y + dy, z + 0.05 * math.sin(k))) for k in range(2)]
            line = [Vector((xs[0] - 0.35 + (xs[-1] - xs[0] + 0.7) * t / 12, y + dy, z + 0.04 * math.sin(t * 2.1))) for t in range(13)]
            sweep(rope, line, 0.06, segments=5)
    torus(screen, (PITCH.x, y - 0.32, PITCH.z), (0, 1, 0), opening + 0.08, 0.13, segments=28, minor_segments=7)
    for k in range(10):
        a = 2 * math.pi * k / 10
        p = Vector((PITCH.x + math.cos(a) * (opening + 0.08), y - 0.32, PITCH.z + math.sin(a) * (opening + 0.08)))
        torus(rope, p, (-math.sin(a), 0, math.cos(a)), 0.18, 0.04, segments=10, minor_segments=4)
    for x in (xs[0], xs[-1]):
        tube(screen, (x, y + 0.25, 4.2), (x, y + 2.4, 0.0), 0.2, 8)
        lash(m, (x, y + 0.25, 4.1), (0, 1, 0), 0.32, turns=2)
    for x in xs[::2]:
        rough_rock(m["CaveRocks"], (x, y - 0.4, 0.15), Vector((0.5, 0.42, 0.3)), rng, subdivisions=1, jitter=0.2, floor=0.0)


# ---------- the cave paintings ----------

def to_face(origin, u, v, n, points, lift=0.02):
    return [origin + u * a + v * b + n * lift for a, b in points]


MAMMOTH_SHAPE = [(-0.7, 0.0), (-0.64, 0.36), (-0.44, 0.56), (-0.1, 0.62), (0.2, 0.56), (0.44, 0.5), (0.62, 0.34), (0.72, 0.06),
                 (0.8, -0.28), (0.74, -0.52), (0.66, -0.22), (0.58, -0.12), (0.56, -0.46), (0.45, -0.46), (0.42, -0.12),
                 (-0.28, -0.14), (-0.33, -0.46), (-0.44, -0.46), (-0.48, -0.12), (-0.66, -0.2)]
BISON_SHAPE = [(-0.62, 0.05), (-0.5, 0.28), (-0.15, 0.36), (0.2, 0.52), (0.45, 0.46), (0.62, 0.2), (0.7, -0.05), (0.6, -0.2),
               (0.52, -0.45), (0.44, -0.45), (0.38, -0.15), (-0.35, -0.12), (-0.42, -0.45), (-0.5, -0.45), (-0.55, -0.1)]


def painting(m, origin, u, v, n, width, height, seed):
    """Animals, hunters, hands and suns daubed on a flat rock face (u along it, v up, n outward)."""
    r = random.Random(seed)
    o, u, v, n = Vector(origin), Vector(u), Vector(v), Vector(n)
    red, black = m["CavePaintRed"], m["CavePaintBlack"]
    for k in range(2):
        cx, cz, s = width * (0.3 + 0.42 * k), height * r.uniform(0.55, 0.72), r.uniform(0.75, 1.0)
        shape = MAMMOTH_SHAPE if (k + seed) % 2 == 0 else BISON_SHAPE
        flip = 1 if k == 0 else -1
        double_sided_poly(black if k == 0 else red, to_face(o, u, v, n, [(cx + x * s * flip, cz + z * s) for x, z in shape]))
    # Two stick hunters with spears.
    for k in range(2):
        hx, hz = width * (0.18 + 0.6 * k + r.uniform(-0.05, 0.05)), height * 0.25
        body = [(hx, hz), (hx, hz + 0.5)]
        lines = [body, [(hx, hz), (hx - 0.18, hz - 0.35)], [(hx, hz), (hx + 0.18, hz - 0.35)],
                 [(hx, hz + 0.4), (hx + 0.3, hz + 0.25)], [(hx - 0.25, hz + 0.6), (hx + 0.45, hz + 0.12)]]
        for line in lines:
            a, b = Vector(line[0]), Vector(line[1])
            across = Vector((-(b - a).y, (b - a).x)).normalized() * 0.035
            double_sided_strip(red, to_face(o, u, v, n, [a - across, b - across]), to_face(o, u, v, n, [a + across, b + across]))
        ball_center = o + u * hx + v * (hz + 0.62) + n * 0.02
        double_sided_poly(red, [ball_center + (u * math.cos(2 * math.pi * j / 8) + v * math.sin(2 * math.pi * j / 8)) * 0.08 for j in range(8)])
    # A handprint and a sun.
    hx, hz = width * r.uniform(0.6, 0.8), height * 0.88
    double_sided_poly(red, to_face(o, u, v, n, [(hx + 0.17 * math.cos(2 * math.pi * j / 10), hz + 0.2 * math.sin(2 * math.pi * j / 10)) for j in range(10)]))
    for f, angle in enumerate((-0.9, -0.35, 0.0, 0.35, 0.75)):
        d = (math.sin(angle), math.cos(angle))
        base = (hx + d[0] * 0.16, hz + d[1] * 0.18)
        length = 0.28 if f in (1, 2, 3) else 0.2
        tip = (base[0] + d[0] * length, base[1] + d[1] * length)
        across = (-d[1] * 0.04, d[0] * 0.04)
        double_sided_strip(red, to_face(o, u, v, n, [(base[0] - across[0], base[1] - across[1]), (tip[0] - across[0], tip[1] - across[1])]),
                           to_face(o, u, v, n, [(base[0] + across[0], base[1] + across[1]), (tip[0] + across[0], tip[1] + across[1])]))
    sx, sz = width * r.uniform(0.15, 0.3), height * 0.88
    double_sided_poly(black, to_face(o, u, v, n, [(sx + 0.18 * math.cos(2 * math.pi * j / 12), sz + 0.18 * math.sin(2 * math.pi * j / 12)) for j in range(12)]))
    for j in range(8):
        a = 2 * math.pi * j / 8
        double_sided_strip(black, to_face(o, u, v, n, [(sx + math.cos(a) * 0.25 - math.sin(a) * 0.03, sz + math.sin(a) * 0.25 + math.cos(a) * 0.03),
                                                       (sx + math.cos(a) * 0.42, sz + math.sin(a) * 0.42)]),
                           to_face(o, u, v, n, [(sx + math.cos(a) * 0.25 + math.sin(a) * 0.03, sz + math.sin(a) * 0.25 - math.cos(a) * 0.03),
                                                (sx + math.cos(a) * 0.42 + 0.01, sz + math.sin(a) * 0.42)]))


def standing_stone(m, center, along, width, height, depth, face_sign, seed):
    """A slab of rock with one flat face (toward face_sign across it) that carries a painting."""
    c = Vector(center)
    u = Vector(along).normalized()
    n = Vector((0, 0, 1)).cross(u).normalized() * face_sign
    r = random.Random(seed)
    outline = []
    for k in range(10):
        t = k / 9
        outline.append((t * width, height * (0.78 + 0.22 * math.sin(math.pi * t)) + r.uniform(-0.25, 0.25)))
    rock = m["CaveRocks"]
    start = len(rock.verts)
    prism(rock, [(x, z) for x, z in outline] + [(width, 0.0), (0.0, 0.0)], -depth, 0.0)
    # Outline x runs along the face, y is up, and the prism's depth goes in behind the face.
    transform_new(rock, start, Matrix(((u.x, 0, n.x, c.x), (u.y, 0, n.y, c.y), (0, 1, 0, c.z), (0, 0, 0, 1))))
    for k in range(4):
        rough_rock(rock, c + u * r.uniform(0, width) - n * depth * 0.5 + Vector((0, 0, 0.2)), Vector((0.6, 0.5, 0.4)), r,
                   subdivisions=1, jitter=0.25, floor=0.0)
    painting(m, c + Vector((0, 0, 0.6)), u, Vector((0, 0, 1)), n, width, height - 1.4, seed)


# ---------- inside and outside ----------

def build_interior(m):
    standing_stone(m, (-14.05, 6.6, 0), (0, 1, 0), 4.0, 4.8, 1.2, 1, seed=1)
    standing_stone(m, (-14.05, 23.8, 0), (0, 1, 0), 4.4, 5.4, 1.2, 1, seed=2)
    # A bone pile and a skull between them.
    for k in range(7):
        a = rng.uniform(0, math.pi)
        long_bone(m["CaveBones"], (-13.0 + rng.uniform(-0.6, 0.6), 15.6 + rng.uniform(-0.8, 0.8), 0.12 + 0.15 * k % 0.4),
                  (math.cos(a), math.sin(a), rng.uniform(-0.1, 0.2)), rng.uniform(1.0, 1.6), 0.08)
    skull(m, (-12.6, 16.6, 0.5), 0.9, horns=True, facing=(1, -0.3, 0))
    # A spear rack against the right wall.
    logs = m["CaveLogs"]
    for y in (12.6, 17.4):
        tube(logs, (12.9, y, 0.0), (12.9, y, 3.4), 0.14, 8)
        for s in (-1, 1):
            tube(logs, (12.9, y, 3.0), (12.9, y + s * 0.35, 3.7), 0.07, 6)
    tube(logs, (12.9, 12.3, 3.35), (12.9, 17.7, 3.35), 0.12, 8)
    for k in range(6):
        y = 13.1 + k * 0.78
        foot = Vector((11.7, y + 0.2, 0.0))
        top = Vector((12.95, y, 4.9 + 0.3 * (k % 2)))
        tube(logs, foot, top, 0.05, 6)
        d = (top - foot).normalized()
        lathe(m["CaveRocks"], [(0, 0), (0.12, 0.08), (0.15, 0.25), (0, 0.62)], 6, transform=Matrix.Translation(top) @ align_z(d))
        lash(m, top - d * 0.05, d, 0.07, turns=2, spacing=0.07)
        if k % 2 == 0:
            double_sided_poly(m["CaveFeathers"], [top - d * 0.5, top - d * 0.45 + Vector((0, 0.25, -0.3)), top - d * 0.9 + Vector((0, 0.18, -0.25))])
    # Clay pots and a firewood stack by the right wall.
    for x, y, h in ((11.6, 25.6, 1.4), (12.7, 26.9, 1.0), (11.4, 28.2, 1.7), (12.5, 29.6, 1.2)):
        lathe(m["CavePots"], [(0, 0), (0.42 * h, 0), (0.62 * h, 0.35 * h), (0.6 * h, 0.7 * h), (0.36 * h, 0.95 * h), (0.42 * h, 1.05 * h),
                              (0.3 * h, 1.05 * h), (0, 0.98 * h)], 16, transform=Matrix.Translation((x, y, 0)))
        torus(m["CaveDark"], (x, y, 0.55 * h), (0, 0, 1), 0.63 * h, 0.035, segments=18, minor_segments=4)
    for row in range(3):
        for k in range(4 - row):
            y = 5.2 + k * 0.62 + row * 0.31
            cylinder_x(logs, (12.2, y, 0.3 + row * 0.5), 2.6, 0.27, 10)


def build_campfire(m):
    for k in range(11):
        a = 2 * math.pi * k / 11
        rough_rock(m["CaveRocks"], FIRE + Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, 0.25)), Vector((0.48, 0.42, 0.38)), rng,
                   subdivisions=1, jitter=0.2, floor=0.0)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        tube(m["CaveLogs"], FIRE + Vector((math.cos(a) * 1.0, math.sin(a) * 1.0, 0.1)), FIRE + Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, 1.5)), 0.13, 8)
    for k in range(14):
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0.1, 0.85)
        blob(m["CaveEmbers"], FIRE + Vector((math.cos(a) * r, math.sin(a) * r, 0.08)), Vector((0.2, 0.17, 0.1)), subdivisions=1, lump=0.2, seed=k)
    for k, (h, r, lean) in enumerate(((1.9, 0.42, (0.05, 0.0)), (1.4, 0.32, (0.25, 0.15)), (1.3, 0.3, (-0.2, -0.15)),
                                      (1.0, 0.26, (0.15, -0.3)), (1.1, 0.26, (-0.25, 0.25)))):
        a = 2 * math.pi * k / 5
        flame(m["CaveFlames"], FIRE + Vector((math.cos(a) * 0.28 * (k > 0), math.sin(a) * 0.28 * (k > 0), 0.15)), h, r, lean)
    # Forked sticks carry the spit; the roast and its bone ends turn on the spit's axis (Blender +Y).
    for y in (FIRE.y - 2.1, FIRE.y + 2.1):
        tube(m["CaveLogs"], (FIRE.x, y, 0.0), (FIRE.x, y, SPIT_Z - 0.25), 0.09, 6)
        for s in (-1, 1):
            tube(m["CaveLogs"], (FIRE.x, y, SPIT_Z - 0.3), (FIRE.x + s * 0.3, y, SPIT_Z + 0.25), 0.06, 6)
    axis_y = Matrix.Translation((FIRE.x, FIRE.y, SPIT_Z)) @ Matrix.Rotation(-math.pi / 2, 4, "X")
    lathe(m["CaveSpitRoast"], [(0, -1.2), (0.15, -1.15), (0.36, -0.85), (0.52, -0.3), (0.56, 0.15), (0.48, 0.6), (0.27, 0.95), (0, 1.05)], 14,
          transform=axis_y)
    lathe(m["CaveSpitBone"], [(0, -2.25), (0.055, -2.25), (0.055, 2.25), (0, 2.25)], 6, transform=axis_y)
    for end in (-1, 1):
        lathe(m["CaveSpitBone"], [(0, 0.95), (0.13, 1.0), (0.1, 1.35), (0.2, 1.48), (0.12, 1.6), (0, 1.62)], 10,
              transform=axis_y @ Matrix.Diagonal((1, 1, end, 1)))
    # Two log seats and a flat seat stone.
    for y in (FIRE.y - 3.4, FIRE.y + 3.4):
        tube(m["CaveLogs"], (16.0, y, 0.38), (19.6, y + 0.3, 0.38), 0.38, 10)
    rough_rock(m["CaveRocks"], (20.2, FIRE.y, 0.4), Vector((0.7, 1.1, 0.45)), rng, subdivisions=2, jitter=0.12, floor=0.0)


def build_mammoth(m):
    """A woolly mammoth asleep on its side of the cage, head toward the door end."""
    c = MAMMOTH
    fur, dark = m["MammothFur"], m["MammothFurDark"]
    blob(fur, c + Vector((0, 0, 2.5)), Vector((2.75, 5.2, 2.55)), subdivisions=3, lump=0.12, lump_scale=2.5, seed=1, floor=0.0)
    blob(dark, c + Vector((0, -2.6, 4.25)), Vector((2.05, 2.6, 1.35)), subdivisions=2, lump=0.2, seed=2)
    blob(fur, c + Vector((0, -6.0, 3.75)), Vector((1.85, 2.0, 2.05)), subdivisions=3, lump=0.1, seed=3)
    blob(dark, c + Vector((0, -5.7, 5.2)), Vector((1.25, 1.3, 0.85)), subdivisions=2, lump=0.2, seed=4)
    sweep_radii(fur, [c + Vector((0, -7.5, 3.4)), c + Vector((0, -8.2, 2.4)), c + Vector((0.05, -8.5, 1.3)),
                      c + Vector((0.15, -8.1, 0.45)), c + Vector((0.2, -7.5, 0.35)), c + Vector((0.2, -7.2, 0.6))],
                [0.58, 0.46, 0.36, 0.27, 0.2, 0.14], segments=12)
    for s in (-1, 1):
        root = c + Vector((s * 0.85, -7.1, 2.9))
        sweep_radii(m["MammothTusks"], [root, root + Vector((s * 0.5, -1.2, -0.9)), root + Vector((s * 1.2, -2.2, -1.0)),
                                        root + Vector((s * 1.5, -2.7, -0.1)), root + Vector((s * 1.2, -2.5, 0.85))],
                    [0.3, 0.27, 0.22, 0.15, 0.06], segments=10)
        ear = c + Vector((s * 1.75, -5.6, 4.0))
        blob(m["MammothEarLeft" if s < 0 else "MammothEarRight"], ear, Vector((0.25, 0.85, 0.95)), subdivisions=2, lump=0.15, seed=s)
        # Closed, sleepy eyes.
        eye = c + Vector((s * 1.45, -6.9, 4.25))
        sweep(m["MammothFace"], [eye + Vector((0, -0.18, 0.05)), eye + Vector((s * 0.06, 0, -0.04)), eye + Vector((0, 0.18, 0.05))], 0.04, segments=5)
        for y, z in ((-3.6, 0.7), (3.4, 0.9)):
            blob(fur, c + Vector((s * 1.25, y, z)), Vector((0.95, 1.7, 0.78)), subdivisions=2, lump=0.15, seed=y + s, floor=0.0)
            blob(dark, c + Vector((s * 1.3, y - 1.4, 0.32)), Vector((0.6, 0.45, 0.32)), subdivisions=1, seed=y, floor=0.0)
    # A shaggy fringe along the belly, and the tail.
    for k in range(34):
        t = k / 33
        y = -4.6 + 9.2 * t
        for s in (-1, 1):
            x = s * 2.5 * math.sqrt(max(0.0, 1 - (y / 5.3) ** 2))
            blob(dark, c + Vector((x, y, 1.05 + 0.12 * math.sin(k * 1.7))), Vector((0.4, 0.42, 0.62)), subdivisions=2, lump=0.2, seed=k + s, floor=0.02)
    sweep_radii(fur, [c + Vector((0, 5.0, 3.3)), c + Vector((0.1, 5.7, 2.6)), c + Vector((0.2, 5.9, 1.6))], [0.2, 0.14, 0.1], segments=8)
    blob(dark, c + Vector((0.2, 5.95, 1.35)), Vector((0.28, 0.28, 0.4)), subdivisions=1, seed=9)


def build_outside(m):
    build_campfire(m)
    build_mammoth(m)
    # Skull totems at the back corners.
    for x in (-19.6, 17.6):
        base = Vector((x, -17.0, 0))
        tube(m["CaveLogs"], base, base + Vector((0, 0, 7.4)), 0.22, 8)
        for k, z in enumerate((3.2, 4.6, 6.0)):
            skull(m, base + Vector((0, -0.2, z)), 0.95 - 0.1 * k, horns=(k == 2))
        lash(m, base + Vector((0, 0, 2.4)), (0, 0, 1), 0.3, turns=3)
        for k in range(5):
            a = 2 * math.pi * k / 5
            top = base + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 2.4))
            double_sided_poly(m["CaveFeathers"], [top, top + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, -0.9)),
                                                  top + Vector((math.cos(a) * 0.38, math.sin(a) * 0.38, -0.7))])
        for k in range(4):
            rough_rock(m["CaveRocks"], base + Vector((math.cos(k * 1.6) * 0.6, math.sin(k * 1.6) * 0.6, 0.2)), Vector((0.45, 0.4, 0.35)), rng,
                       subdivisions=1, jitter=0.25, floor=0.0)
    # Bone torches either side of the door.
    for x in (DOOR[0] - 1.4, DOOR[1] + 1.4):
        base = Vector((x, BACK_Y - 1.4, 0))
        long_bone(m["CaveBones"], base, (0, 0, 1), 3.6, 0.13)
        lathe(m["CaveHides"], [(0, 3.4), (0.32, 3.5), (0.44, 3.9), (0.4, 4.05), (0, 3.95)], 10, transform=Matrix.Translation(base))
        flame(m["CaveTorchFlames"], base + Vector((0, 0, 3.95)), 1.0, 0.3)
    # A drying rack with a stretched hide, outside the right wall by the machine end.
    rack = Vector((17.8, 30.0, 0))
    for y in (-2.6, 2.6):
        for s in (-1, 1):
            tube(m["CaveLogs"], rack + Vector((s * 1.1, y, 0)), rack + Vector((0, y, 4.4)), 0.12, 6)
    tube(m["CaveLogs"], rack + Vector((0, -3.0, 4.3)), rack + Vector((0, 3.0, 4.3)), 0.12, 6)

    def rack_hide(a, b):
        return rack + Vector((0.05 * math.sin(math.pi * a * 3), -2.2 + 4.4 * a, 4.0 - 3.4 * b - 0.3 * math.sin(math.pi * a)))
    grid_surface(m["CaveHides"], rack_hide, 10, 8, keep=lambda a, b: min(a, 1 - a, b, 1 - b) > 0.05 + 0.07 * (noise.noise(Vector((a * 4, b * 4, 7))) + 0.5))
    for k in range(5):
        tube(m["CaveRope"], rack_hide(k / 4, 0.04), rack + Vector((0, -2.2 + 4.4 * k / 4, 4.3)), 0.03, 4)
    # Ferns, boulders and a painted boulder outside.
    for x, y, n, length in ((-19.4, 34.5, 10, 2.4), (18.6, 37.0, 9, 2.0), (-19.0, 6.0, 8, 1.8), (19.0, 1.0, 9, 2.2),
                            (-6.0, 39.0, 9, 2.2), (6.0, 39.6, 10, 2.6), (19.2, 21.6, 7, 1.6), (-20.6, 9.5, 7, 1.6)):
        fern(m["CaveFerns"], (x, y, 0.1), n, length, rng)
    for x, y, s in ((-20.6, 37.2, 1.3), (19.6, 39.0, 1.0), (-21.0, 1.6, 1.1), (19.8, 5.2, 0.9), (0.0, 40.4, 1.2), (12.0, 38.8, 0.9)):
        rough_rock(m["CaveRocks"], (x, y, 0.6 * s), Vector((1.1, 1.0, 0.8)) * s, rng, subdivisions=2, jitter=0.18, floor=0.0)
    standing_stone(m, (-12.0, 39.6, 0), (1, 0, 0), 4.6, 5.0, 1.3, -1, seed=3)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = meshes(LOOKS)
    build_arches(m)
    build_net_and_hides(m)
    build_door(m)
    build_floor(m)
    build_catapult(m)
    build_screen(m)
    build_interior(m)
    build_outside(m)
    for name in ("CavePaintRed", "CavePaintBlack", "CaveHideSpots", "CaveFeathers"):
        bmesh.ops.triangulate(m[name], faces=m[name].faces[:])
    objects = build_looks(coll, m, LOOKS)
    check_centred(objects, {"CaveSpitRoast": ((FIRE.x, FIRE.y, SPIT_Z), (0, 1, 0)), "CaveSpitBone": ((FIRE.x, FIRE.y, SPIT_Z), (0, 1, 0))})
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
