# Training Ground 3 of World 4, Cereal Bowl Stadium: the batting cage is a giant breakfast bowl. The
# bowl's curved, flaring wall is the enclosure (blue outside with a white stripe band and dots, a
# rolled white rim, a chip broken out of it for the door). Bendy striped drinking straws arch over it
# from rim to rim under a sheet of cling film for a roof. Milk fills it, with cereal loops, berries
# and banana slices bobbing on it and flakes floating at the edges. A giant spoon balanced on a sugar
# cube holds the ball at PITCH in its bowl (a strawberry weighs down its handle). An opened cereal
# box with a sun mascot, a bowl picture and a starburst badge is the screen, with the window
# tunnelled through it and its prize, a spinning top, turning on top. Outside stands a gable-top milk
# carton with cow spots, with spilled cereal, sugar cubes and a resting spoon.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "CerealBowlCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\CerealBowlCage.fbx"

BOWL_BLUE = (0.28, 0.56, 0.9)
MILK = (0.98, 0.97, 0.94)
LOOP_ORANGE, LOOP_PINK, LOOP_YELLOW = (1.0, 0.6, 0.2), (1.0, 0.42, 0.52), (0.96, 0.86, 0.32)
FLAKE = (0.92, 0.7, 0.36)
STEEL = (0.84, 0.86, 0.9)
rng = random.Random(58)

CX, CY = (LEFT_X + RIGHT_X) / 2, 10.0
RX, RY, POWER = 19.0, 28.4, 3.5            # the bowl's plan at the milk
FLARE, WALL_H, THICK = 0.06, 10.4, 0.8     # how far the wall leans out by the rim, its height, its thickness
STRAWS = (-8.0, 0.0, 8.0, 16.0, 24.0, 32.0)
STRAW_RISE = 6.4
TOP = Vector((PITCH.x + 2.0, SCREEN_Y + 0.8, 8.9))   # the spinning-top prize on the cereal box

LOOKS = {
    "BowlWall": (BOWL_BLUE, "soft"), "BowlInside": ((0.95, 0.96, 0.98), "soft"), "BowlRim": (WHITE, "smooth"),
    "BowlStripe": (WHITE, "smooth"), "BowlDots": (WHITE, "hard"),
    "BowlStraws": (WHITE, "smooth"), "BowlStrawStripes": (TOY_RED, "smooth"), "BowlStrawStripesBlue": (TOY_BLUE, "smooth"),
    "BowlFilm": ((0.9, 0.95, 1.0), "soft"),
    "BowlMilk": (MILK, "soft"), "BowlMilkRipples": ((0.92, 0.9, 0.86), "smooth"),
    "BowlLoopsA": (LOOP_ORANGE, "smooth"), "BowlLoopsB": (LOOP_PINK, "smooth"), "BowlLoopsC": (LOOP_YELLOW, "smooth"), "BowlSpilledLoops": (LOOP_ORANGE, "smooth"),
    "BowlBerries": ((0.25, 0.22, 0.6), "smooth"), "BowlBanana": ((1.0, 0.95, 0.7), "smooth"), "BowlFlakes": (FLAKE, "smooth"),
    "BowlSpoon": (STEEL, "smooth"), "BowlSugar": (WHITE, "hard"), "BowlStrawberry": ((0.9, 0.12, 0.18), "smooth"),
    "BowlLeaves": ((0.24, 0.6, 0.24), "soft"), "BowlSeeds": ((1.0, 0.9, 0.4), "smooth"),
    "BowlBox": ((1.0, 0.5, 0.15), "hard"), "BowlBoxSide": ((0.95, 0.85, 0.3), "hard"), "BowlBoxArt": (TOY_YELLOW, "hard"),
    "BowlBoxArtRed": (TOY_RED, "hard"), "BowlBoxArtBlue": (TOY_BLUE, "hard"), "BowlBoxArtWhite": (WHITE, "hard"), "BowlBoxInk": ((0.1, 0.08, 0.08), "hard"),
    "BowlTop": (TOY_RED, "smooth"),
    "BowlCarton": (WHITE, "hard"), "BowlCartonBlue": (TOY_BLUE, "hard"), "BowlCartonSpots": ((0.08, 0.08, 0.1), "hard"),
    "BowlPlate": (WHITE, "hard"), "BowlBall": (WHITE, "smooth"),
}


# ---------- the bowl ----------

def plan(u, scale=1.0):
    """A point on the bowl's plan at parameter u (0..1, counter-clockwise from the back)."""
    a = -math.pi / 2 + 2 * math.pi * u
    c, s = math.cos(a), math.sin(a)
    return Vector((CX + RX * scale * math.copysign(abs(c) ** (2 / POWER), c), CY + RY * scale * math.copysign(abs(s) ** (2 / POWER), s), 0))


def outward(u):
    t = plan(u + 0.001) - plan(u - 0.001)
    t.normalize()
    return Vector((t.y, -t.x, 0))


def wall_point(u, v, offset=0.0):
    p = plan(u, 1 + FLARE * v ** 1.5) + outward(u) * offset
    return Vector((p.x, p.y, WALL_H * v))


DOOR_U = None


def find_door_u():
    best, best_d = 0.0, 1e9
    for i in range(2000):
        u = i / 2000
        p = plan(u)
        d = abs(p.x - (DOOR[0] + DOOR[1]) / 2) + (0 if p.y < CY else 100)
        if d < best_d:
            best, best_d = u, d
    return best


DOOR_U = find_door_u()


def in_chip(u, v):
    """The chip broken out of the bowl for the door: a notch that widens toward the rim."""
    p = plan(u)
    half = (DOOR[1] - DOOR[0]) / 2 + 0.6 + 1.0 * v + 0.35 * math.sin(u * 900)
    return p.y < CY and abs(p.x - (DOOR[0] + DOOR[1]) / 2) < half


def build_bowl(m):
    grid_surface(m["BowlInside"], lambda u, v: wall_point(u, v), 220, 12, keep=lambda u, v: not in_chip(u, v))
    grid_surface(m["BowlWall"], lambda u, v: wall_point(u, v, THICK), 220, 12, keep=lambda u, v: not in_chip(u, v))
    # The rolled rim along the top, a white stripe band, and white dots round the outside.
    runs, run = [], []
    us = [k / 400 for k in range(401)]
    for u in us:
        if in_chip(u % 1.0, 1.0):
            if len(run) > 1:
                runs.append(run)
            run = []
        else:
            run.append(wall_point(u % 1.0, 1.0, THICK / 2))
    if len(run) > 1:
        runs.append(run)
    for run in runs:
        sweep(m["BowlRim"], run, 0.62, segments=12)
    for v0 in (0.66, 0.74):
        for run_u in _runs(0.0, 1.0, v0):
            sweep(m["BowlStripe"], [wall_point(u, v0, THICK + 0.05) for u in run_u], 0.12, segments=6)
    for k in range(70):
        u, v = rng.random(), rng.uniform(0.12, 0.55)
        if in_chip(u, v):
            continue
        p, n = wall_point(u, v, THICK + 0.04), outward(u)
        disc(m["BowlDots"], p, n, rng.uniform(0.35, 0.6), 0.05, segments=14)
    # The chip's broken edges: rough white shards along both sides.
    for side in (-1, 1):
        for k in range(9):
            v = k / 8
            u = DOOR_U
            for j in range(80):
                du = side * j * 0.0006
                if not in_chip(DOOR_U + du, v):
                    u = DOOR_U + du
                    break
            p = wall_point(u, v, THICK / 2)
            rough_rock(m["BowlRim"], p, Vector((0.4, 0.4, 0.5)), rng, subdivisions=1, jitter=0.3)


def _runs(u0, u1, v, count=300):
    runs, run = [], []
    for k in range(count + 1):
        u = (u0 + (u1 - u0) * k / count) % 1.0
        if in_chip(u, v):
            if len(run) > 1:
                runs.append(run)
            run = []
        else:
            run.append(u)
    if len(run) > 1:
        runs.append(run)
    return runs


RIM_CACHE = {}


def rim_x(y, side):
    """The rim's x at y on one side (searched along the plan, cached)."""
    key = (round(y, 4), side)
    if key in RIM_CACHE:
        return RIM_CACHE[key]
    best, best_d = None, 1e9
    for i in range(1000):
        u = i / 1000
        p = wall_point(u, 1.0, THICK / 2)
        if (p.x - CX) * side <= 0:
            continue
        d = abs(p.y - y)
        if d < best_d:
            best, best_d = p.x, d
    RIM_CACHE[key] = best
    return best


def straw_arc(y, count=40):
    xl, xr = rim_x(y, -1), rim_x(y, 1)
    c = (xl + xr) / 2
    half = (xr - xl) / 2
    return [Vector((c - half * math.cos(math.pi * k / count), y, WALL_H + 0.4 + STRAW_RISE * math.sin(math.pi * k / count))) for k in range(count + 1)]


def build_straws(m):
    """Bendy drinking straws arching over the bowl, striped, with an accordion bend near one end."""
    for index, y in enumerate(STRAWS):
        arc = straw_arc(y)
        sweep(m["BowlStraws"], arc, 0.42, segments=12)
        line = Polyline(arc)
        frames = sweep_frames(line.samples(0.2))
        samples = line.samples(0.2)
        mesh = "BowlStrawStripes" if index % 2 == 0 else "BowlStrawStripesBlue"
        for stripe in range(2):
            helix = []
            for k, (p, (t, n, b)) in enumerate(zip(samples, frames)):
                a = k * 0.32 + math.pi * stripe
                helix.append(p + (n * math.cos(a) + b * math.sin(a)) * 0.43)
            sweep(m[mesh], helix, 0.09, segments=5)
        # The accordion bend: ridges round the straw near its right-hand end.
        for k in range(8):
            s = line.length * (0.84 + 0.012 * k)
            p = line.at(s)
            t = (line.at(s + 0.05) - line.at(s - 0.05)).normalized()
            torus(m["BowlStraws"], p, t, 0.44, 0.07, segments=12, minor_segments=4)
    # Cling film stretched over the straws, sagging between them.
    y0, y1 = STRAWS[0], STRAWS[-1]

    def film(u, v):
        y = y0 + (y1 - y0) * v
        arc = straw_arc(y, count=24)
        p = Polyline(arc).at(Polyline(arc).length * u)
        bay = (y - y0) / (STRAWS[1] - STRAWS[0])
        sag = 0.6 * abs(math.sin(math.pi * bay)) * math.sin(math.pi * u)
        return p + Vector((0, 0, 0.36 - sag))
    grid_surface(m["BowlFilm"], film, 24, 40)


# ---------- milk and floating cereal ----------

def build_milk(m):
    x0, x1, y0, y1 = CX - RX, CX + RX, CY - RY, CY + RY

    def milk(u, v):
        return Vector((x0 + (x1 - x0) * u, y0 + (y1 - y0) * v, 0.04))

    def keep(u, v):
        x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * v
        inside = (abs(x - CX) / (RX - 0.1)) ** POWER + (abs(y - CY) / (RY - 0.1)) ** POWER < 1.0
        in_rect = LEFT_X - 0.4 < x < RIGHT_X + 0.4 and BACK_Y - 0.4 < y < FRONT_Y + 0.4
        return inside and not in_rect
    grid_surface(m["BowlMilk"], milk, 80, 114, keep=keep)
    # Floating cereal loops, berries and banana slices round the edges (clear of the lane and
    # the batter's ground), each kind bobbing together, with ripple rings round some.
    spots = []
    while len(spots) < 90:
        x, y = rng.uniform(LEFT_X + 0.8, RIGHT_X - 0.8), rng.uniform(BACK_Y + 1.0, FRONT_Y - 1.0)
        if -0.5 < x < 6.5 and -4.5 < y < 25.0:
            continue
        if -14.0 < x < 10.0 and y < -3.0 and x > -4.0:
            continue
        if any((Vector((x, y)) - Vector(s)).length < 1.4 for s in spots):
            continue
        spots.append((x, y))
    for k, (x, y) in enumerate(spots):
        kind = k % 5
        if kind < 3:
            torus(m["BowlLoops" + "ABC"[kind]], (x, y, 0.18), (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 1), 0.42, 0.2, segments=14, minor_segments=7)
        elif kind == 3:
            ball(m["BowlBerries"], (x, y, 0.22), 0.42, subdivisions=2)
            torus(m["BowlBerries"], (x, y, 0.6), (0, 0, 1), 0.12, 0.05, segments=8, minor_segments=3)
        else:
            disc(m["BowlBanana"], (x, y, 0.14), (0, 0, 1), 0.65, 0.18, segments=18)
        if k % 3 == 0:
            torus(m["BowlMilkRipples"], (x, y, 0.06), (0, 0, 1), 0.95, 0.04, segments=20, minor_segments=3)
    # Flakes floating round the bowl's edge, outside the cage.
    for _ in range(46):
        u = rng.random()
        if in_chip(u, 0.0):
            continue
        p = plan(u, 0.93)
        if LEFT_X - 0.3 < p.x < RIGHT_X + 0.3 and BACK_Y - 0.3 < p.y < FRONT_Y + 0.3:
            continue
        blob(m["BowlFlakes"], p + Vector((0, 0, 0.12)), Vector((0.7, 0.55, 0.08)), subdivisions=2, lump=0.3, seed=u * 50,
             rotation=Matrix.Rotation(rng.uniform(-0.4, 0.4), 4, "X") @ Matrix.Rotation(rng.uniform(0, 6), 4, "Z"))
    home_plate(m["BowlPlate"], 0.08)


# ---------- the spoon catapult ----------

def strawberry(m, centre, size):
    c = Vector(centre)
    blob(m["BowlStrawberry"], c, Vector((size, size, size * 1.2)), subdivisions=2, seed=c.x, rotation=Matrix.Rotation(math.pi, 4, "X"))
    for k in range(18):
        a, z = rng.uniform(0, 2 * math.pi), rng.uniform(-0.7, 0.6)
        r = size * math.sqrt(max(0.0, 1 - z * z)) * 1.01
        ball(m["BowlSeeds"], c + Vector((math.cos(a) * r, math.sin(a) * r, z * size * 1.2)), size * 0.06, subdivisions=1)
    for k in range(6):
        a = 2 * math.pi * k / 6
        leaf(m["BowlLeaves"], c + Vector((0, 0, size * 1.15)), (math.cos(a), math.sin(a), 0.3), (-math.sin(a), math.cos(a), 0), size * 0.8, size * 0.4)


def build_spoon(m):
    """A giant spoon balanced on a sugar cube: its bowl holds the ball at PITCH."""
    spoon = m["BowlSpoon"]
    tilt = math.atan2(2.1, 7.4)                       # the handle runs down and back to the floor
    along = Vector((0, math.cos(tilt), -math.sin(tilt)))
    up = Vector((0, math.sin(tilt), math.cos(tilt)))
    bowl_centre = PITCH - up * (BALL_RADIUS + 0.08) + along * 0.15
    # The spoon's bowl: a shallow oval shell, rim up.
    turn = Matrix.Translation(bowl_centre) @ Matrix(((1, 0, 0, 0), (0, along.y, up.y, 0), (0, along.z, up.z, 0), (0, 0, 0, 1))) @ Matrix.Diagonal((1.0, 1.35, 1.0, 1.0))
    lathe(spoon, [(0, -0.55), (0.6, -0.48), (1.0, -0.22), (1.12, 0.05), (1.06, 0.1), (0.92, -0.12), (0.55, -0.36), (0, -0.42)], 24, transform=turn)
    neck = bowl_centre + along * 1.45 + up * 0.0
    end = neck + along * 7.0
    for k in range(10):
        t0, t1 = k / 10, (k + 1) / 10
        w0, w1 = 0.28 + 0.5 * t0 ** 1.5, 0.28 + 0.5 * t1 ** 1.5
        a, b = neck.lerp(end, t0), neck.lerp(end, t1)
        slab(spoon, [a - Vector((w0, 0, 0)), b - Vector((w1, 0, 0)), b + Vector((w1, 0, 0)), a + Vector((w0, 0, 0))], 0.22, up)
    disc(spoon, end, up, 0.78, 0.22, segments=18)
    # The sugar cube fulcrum, a second cube beside it, and a strawberry weighing down the handle.
    fulcrum_y = PITCH.y + 4.6
    z_handle = neck.z - (fulcrum_y - neck.y) * math.tan(tilt)
    box(m["BowlSugar"], (PITCH.x, fulcrum_y, (z_handle - 0.12) / 2), (1.9, 1.9, z_handle - 0.12))
    box(m["BowlSugar"], (PITCH.x + 2.4, fulcrum_y + 1.4, 0.75), (1.5, 1.5, 1.5), Matrix.Rotation(0.4, 4, "Z"))
    for k in range(18):
        p = Vector((PITCH.x + rng.uniform(-1.0, 1.0), fulcrum_y + rng.uniform(-1.0, 1.0), z_handle - 0.1))
        if k % 3 == 0:
            box(m["BowlSugar"], p, (0.12, 0.12, 0.12))
    strawberry(m, end + up * 0.9, 0.8)
    pitch_ball(m["BowlBall"])


# ---------- the cereal box screen ----------

def build_box(m):
    """An opened cereal box: front and back faces with the window tunnelled through, sides, open
    flaps on top, art on the front and its prize toy spinning on top."""
    y0, y1 = SCREEN_Y - 0.65, SCREEN_Y + 0.95
    x0, x1, z0, z1 = PITCH.x - 3.4, PITCH.x + 3.4, 0.0, 8.6
    outline = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    window_panel(m["BowlBox"], outline, y0, 0.08, segments=64)
    window_panel(m["BowlBox"], outline, y1, 0.08, segments=64)
    r = WINDOW + 0.06
    lathe(m["BowlBoxSide"], [(r, 0.0), (r + 0.08, 0.0), (r + 0.08, y1 - y0), (r, y1 - y0), (r, 0.0)], 28,
          transform=Matrix.Translation((PITCH.x, y0, PITCH.z)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
    depth, mid_y = y1 - y0, (y0 + y1) / 2
    for x in (x0, x1):
        box(m["BowlBoxSide"], (x, mid_y, (z0 + z1) / 2), (0.08, depth, z1 - z0))
    # Open flaps on top, folded out.
    for sx in (-1, 1):
        hinge = Vector((PITCH.x + sx * 3.4, mid_y, z1))
        slab(m["BowlBoxSide"], [hinge + Vector((0, -depth / 2, 0)), hinge + Vector((0, depth / 2, 0)), hinge + Vector((sx * 0.7, depth / 2, 1.3)),
                                hinge + Vector((sx * 0.7, -depth / 2, 1.3))], 0.06)
    for sy, y in ((-1, y0), (1, y1)):
        hinge = Vector((PITCH.x, y, z1))
        slab(m["BowlBox"], [hinge + Vector((-3.4, 0, 0)), hinge + Vector((3.4, 0, 0)), hinge + Vector((3.4, sy * 1.0, 1.2)), hinge + Vector((-3.4, sy * 1.0, 1.2))], 0.06)
    # Art on the front: a smiling sun mascot, a bowl of loops, a starburst badge and a milk splash.
    f = y0 - 0.06
    n = Vector((0, -1, 0))

    def flat(mesh, points, lift=0.0):
        slab(m[mesh], [Vector((x, f - lift, z)) for x, z in points], 0.04, n)
    sun = (x0 + 1.6, 6.6)
    flat("BowlBoxArt", ellipse_xz(sun, 1.05, 1.05, 24))
    for k in range(12):
        a = 2 * math.pi * k / 12
        flat("BowlBoxArt", [(sun[0] + math.cos(a - 0.12) * 1.15, sun[1] + math.sin(a - 0.12) * 1.15), (sun[0] + math.cos(a) * 1.65, sun[1] + math.sin(a) * 1.65),
                            (sun[0] + math.cos(a + 0.12) * 1.15, sun[1] + math.sin(a + 0.12) * 1.15)])
    for sx in (-1, 1):
        flat("BowlBoxInk", ellipse_xz((sun[0] + sx * 0.36, sun[1] + 0.25), 0.12, 0.17, 10), lift=0.03)
    smile = [(sun[0] + 0.55 * math.cos(a), sun[1] - 0.1 + 0.45 * math.sin(a)) for a in [math.radians(200 + 140 * k / 10) for k in range(11)]]
    for (ax, az), (bx, bz) in zip(smile, smile[1:]):
        flat("BowlBoxInk", [(ax, az - 0.05), (bx, bz - 0.05), (bx, bz + 0.05), (ax, az + 0.05)], lift=0.03)
    badge = (x1 - 1.2, 7.3)
    flat("BowlBoxArtRed", [(badge[0] + (0.95 if k % 2 == 0 else 0.62) * math.cos(math.pi * k / 8), badge[1] + (0.95 if k % 2 == 0 else 0.62) * math.sin(math.pi * k / 8))
                           for k in range(16)])
    flat("BowlBoxArtWhite", ellipse_xz(badge, 0.42, 0.42, 16), lift=0.03)
    bowl = (x1 - 1.4, 1.5)
    flat("BowlBoxArtBlue", [(bowl[0] + 1.35 * math.cos(a), bowl[1] + 0.9 * math.sin(a)) for a in [math.pi + math.pi * k / 16 for k in range(17)]])
    for k in range(4):
        flat("BowlBoxArt", ellipse_xz((bowl[0] - 0.9 + 0.6 * k, bowl[1] + 0.15 + 0.12 * (k % 2)), 0.3, 0.3, 12), lift=0.02)
    for k in range(9):
        x = x0 + 0.3 + (x1 - x0 - 0.6) * k / 8
        z = 5.0 + 0.25 * math.sin(k * 1.4)
        if abs(x - PITCH.x) < WINDOW + 0.5:
            continue
        flat("BowlBoxArtWhite", ellipse_xz((x, z), 0.42, 0.3, 12), lift=0.01)
    flat("BowlBoxArtRed", [(x0 + 0.2, 0.2), (x1 - 0.2, 0.2), (x1 - 0.2, 0.55), (x0 + 0.2, 0.55)])
    # The prize: a spinning top turning on the box top.
    lathe(m["BowlTop"], [(0, 0.0), (0.18, 0.25), (0.75, 0.75), (0.85, 0.95), (0.6, 1.2), (0.12, 1.3), (0.1, 1.75), (0, 1.8)], 20,
          transform=Matrix.Translation(TOP))
    disc(m["BowlBoxSide"], (TOP.x, TOP.y, z1 + 0.01), (0, 0, 1), 0.5, 0.02, segments=16)


def ellipse_xz(centre, rx, rz, count):
    return [(centre[0] + rx * math.cos(2 * math.pi * k / count), centre[1] + rz * math.sin(2 * math.pi * k / count)) for k in range(count)]


# ---------- outside ----------

def build_outside(m):
    # A gable-top milk carton by the front right, cow spots on its blue panels.
    c = Vector((17.4, 40.6, 0))
    w, h = 3.4, 8.0
    box(m["BowlCarton"], c + Vector((0, 0, h / 2)), (w, w, h))
    for sx in (-1, 1):
        slab(m["BowlCarton"], [c + Vector((sx * w / 2, -w / 2, h)), c + Vector((sx * w / 2, w / 2, h)), c + Vector((0, w / 2, h + 1.6)), c + Vector((0, -w / 2, h + 1.6))],
             0.08)
    box(m["BowlCarton"], c + Vector((0, 0, h + 1.85)), (0.12, w, 0.5))
    for face in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = Vector((face[0], face[1], 0))
        side = Vector((-face[1], face[0], 0))
        centre = c + n * (w / 2 + 0.02) + Vector((0, 0, 3.4))
        box(m["BowlCartonBlue"], centre, (abs(side.x) * (w - 0.3) + abs(n.x) * 0.04 + 0.001, abs(side.y) * (w - 0.3) + abs(n.y) * 0.04 + 0.001, 4.4))
        for k in range(4):
            p = centre + n * 0.04 + side * rng.uniform(-1.1, 1.1) + Vector((0, 0, rng.uniform(-1.6, 1.6)))
            disc(m["BowlCartonSpots"], p, n, rng.uniform(0.25, 0.5), 0.03, segments=12)
    # A spoon resting outside, spilled loops and flakes, and a pile of sugar cubes.
    s0 = Vector((-19.6, 30.0, 0.3))
    for k in range(10):
        a, b = s0 + Vector((0, -0.7 * k, 0)), s0 + Vector((0, -0.7 * (k + 1), 0))
        slab(m["BowlSpoon"], [a - Vector((0.3, 0, 0)), b - Vector((0.3, 0, 0)), b + Vector((0.3, 0, 0)), a + Vector((0.3, 0, 0))], 0.2, Vector((0, 0, 1)))
    lathe(m["BowlSpoon"], [(0, 0.05), (0.7, 0.1), (1.0, 0.35), (1.05, 0.55), (0, 0.25)], 16,
          transform=Matrix.Translation(s0 + Vector((0, 1.3, 0))) @ Matrix.Diagonal((1, 1.4, 1, 1)))
    for k in range(30):
        u = rng.random()
        p = plan(u, 1.13)
        if not (-22.4 < p.x < 20.4) or in_chip(u, 0.0):
            continue
        kind = k % 4
        if kind < 3:
            torus(m["BowlSpilledLoops"], (p.x, p.y, 0.2), (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1), 0.42, 0.2, segments=14, minor_segments=7)
        else:
            blob(m["BowlFlakes"], p + Vector((0, 0, 0.1)), Vector((0.7, 0.55, 0.08)), subdivisions=2, lump=0.3, seed=k)
    for k, (dx, dy, dz) in enumerate(((0, 0, 0), (1.3, 0.2, 0), (0.6, 1.2, 0), (0.6, 0.5, 1.2))):
        box(m["BowlSugar"], (-19.4 + dx, -6.0 + dy, 0.6 + dz), (1.2, 1.2, 1.2), Matrix.Rotation(rng.uniform(-0.3, 0.3), 4, "Z"))


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = meshes(LOOKS)
    build_bowl(m)
    build_straws(m)
    build_milk(m)
    build_spoon(m)
    build_box(m)
    build_outside(m)
    objects = build_looks(coll, m, LOOKS)
    check_centred(objects, {"BowlTop": (TOP, (0, 0, 1))})
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
