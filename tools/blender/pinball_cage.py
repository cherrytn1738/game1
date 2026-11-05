# Training Ground 2 of World 4, Pinball Cage: the batting cage is a giant pinball machine. A painted
# cabinet with a rounded top arch at the machine end, chrome side rails rising with the playfield's
# tilt, a sloping glass top for a roof and chrome legs. The door is the coin door. The floor is the
# playfield, with glowing inserts. Flippers and slingshots line the sides, pop bumpers light up, two
# spinners turn in their lanes, a star turntable turns, drop targets stand in a bank, and a clear wire
# ramp loops overhead. A spring plunger in its shooter lane holds the ball at PITCH, and the screen is
# the scoreboard backglass with a glowing score. Rollover lanes wait under the top arch.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "PinballCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\PinballCage.fbx"

CABINET = (0.38, 0.16, 0.62)
CHROME = (0.82, 0.84, 0.88)
PINK = (1.0, 0.32, 0.72)
CYAN = (0.3, 0.9, 1.0)
YELLOW = (1.0, 0.84, 0.2)
DARK = (0.08, 0.06, 0.14)
RUBBER = (0.9, 0.16, 0.2)
rng = random.Random(23)

CX = (LEFT_X + RIGHT_X) / 2
ARCH_Y, ARCH_R = 26.0, (RIGHT_X - LEFT_X) / 2      # the rounded top end beyond the machine
GLASS_LOW, GLASS_TILT = 9.6, 0.072                  # glass height at the door end and its rise per stud
BUMPERS = {"PinBumperA": (-11.0, 9.0, 1.4), "PinBumperB": (-12.0, 21.5, 1.6), "PinBumperC": (9.8, 11.0, 1.4),
           "PinBumperD": (10.6, 24.0, 1.6), "PinBumperE": (-6.5, 31.0, 1.3)}
SPINNERS = {"PinSpinnerA": Vector((-13.2, 15.0, 2.2)), "PinSpinnerB": Vector((11.6, 17.5, 2.2))}
TURNTABLE = Vector((8.5, 31.5, 0.08))
PLUNGER_TIP = PITCH.y + BALL_RADIUS + 0.04

LOOKS = {
    "PinCabinet": (CABINET, "hard"), "PinCabinetTrim": (DARK, "hard"), "PinArtPink": (PINK, "hard"), "PinArtYellow": (YELLOW, "hard"),
    "PinArtCyan": (CYAN, "hard"), "PinChrome": (CHROME, "smooth"), "PinChromeRails": (CHROME, "smooth"), "PinGlass": ((0.8, 0.88, 1.0), "soft"),
    "PinCoinDoor": (CHROME, "hard"), "PinCoinSlots": ((1.0, 0.25, 0.2), "hard"),
    "PinFlippers": (WHITE, "smooth"), "PinRubber": (RUBBER, "smooth"), "PinSlings": (WHITE, "hard"),
    "PinBumperBases": (DARK, "smooth"), "PinBumperSkirts": (WHITE, "smooth"),
    "PinInsertsPink": (PINK, "hard"), "PinInsertsYellow": (YELLOW, "hard"), "PinInsertsCyan": (CYAN, "hard"), "PinInsertsGreen": ((0.3, 1.0, 0.4), "hard"),
    "PinFloorArt": ((0.25, 0.12, 0.45), "hard"), "PinTargets": (YELLOW, "hard"), "PinPosts": (CHROME, "smooth"),
    "PinRamp": ((0.7, 0.9, 1.0), "soft"), "PinRampRails": (CHROME, "smooth"),
    "PinShooterLane": ((0.95, 0.92, 0.86), "hard"), "PinSpring": (CHROME, "smooth"), "PinPlungerKnob": (RUBBER, "smooth"),
    "PinBackbox": (CABINET, "hard"), "PinBackglass": (DARK, "hard"), "PinScore": ((1.0, 0.55, 0.12), "hard"), "PinSpeakers": ((0.15, 0.15, 0.18), "hard"),
    "PinTurntable": (PINK, "hard"), "PinTurntableStar": (YELLOW, "hard"),
    "PinChaseA": ((1.0, 0.9, 0.5), "smooth"), "PinChaseB": ((1.0, 0.5, 0.8), "smooth"), "PinWallGlow": (CYAN, "hard"),
    "PinPlate": (WHITE, "hard"), "PinBall": (CHROME, "smooth"),
}
for name in BUMPERS:
    LOOKS[name] = (PINK, "smooth")
for name in SPINNERS:
    LOOKS[name] = (CHROME, "hard")


def glass_z(y):
    return GLASS_LOW + (y - BACK_Y) * GLASS_TILT


def plan_points(count=40):
    """The playfield outline, counter-clockwise from the back-left corner: straight sides, a
    rounded top arch past the machine end."""
    points = [Vector((LEFT_X, BACK_Y, 0)), Vector((RIGHT_X, BACK_Y, 0)), Vector((RIGHT_X, ARCH_Y, 0))]
    for k in range(1, count):
        a = math.pi * k / count
        points.append(Vector((CX + ARCH_R * math.cos(a), ARCH_Y + ARCH_R * math.sin(a), 0)))
    points.append(Vector((LEFT_X, ARCH_Y, 0)))
    return points


PLAN = plan_points()


def inside_plan(x, y, inset=0.0):
    if y < BACK_Y + inset or y > ARCH_Y + ARCH_R - inset:
        return False
    if y <= ARCH_Y:
        return LEFT_X + inset < x < RIGHT_X - inset
    return (x - CX) ** 2 + (y - ARCH_Y) ** 2 < (ARCH_R - inset) ** 2


# ---------- the cabinet ----------

def wall_strip(m, a, b, thickness=0.6, door=None):
    """A cabinet wall from a to b whose top follows the glass; door = (x0, x1, height) cut-out."""
    a, b = Vector(a), Vector(b)
    t = (b - a).normalized()
    n = Vector((-t.y, t.x, 0))
    length = (b - a).length
    steps = max(1, int(length / 2.0))
    for k in range(steps):
        p0, p1 = a + t * (length * k / steps), a + t * (length * (k + 1) / steps)
        mid = (p0 + p1) / 2
        top = glass_z(mid.y) - 0.1
        turn = Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z")
        seg = (p1 - p0).length
        if door and door[0] - 0.01 < mid.x < door[1] + 0.01:
            box(m["PinCabinet"], (mid.x, mid.y, (door[2] + top) / 2), (seg + 0.02, thickness, top - door[2]), turn)
        else:
            box(m["PinCabinet"], (mid.x, mid.y, top / 2), (seg + 0.02, thickness, top), turn)
    # The chrome side rail along the top and a dark trim strip at the foot.
    rail = [a + Vector((0, 0, glass_z(a.y) + 0.05)) + n * 0.0, b + Vector((0, 0, glass_z(b.y) + 0.05))]
    extrude(m["PinChromeRails"], rail[0] - t * 0.3, rail[1] + t * 0.3, rrect(0.9, 0.36, 0.14))
    mid = (a + b) / 2
    box(m["PinCabinetTrim"], (mid.x, mid.y, 0.2), (length + 0.1, thickness + 0.08, 0.4), Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z"))


def side_art(m, x, outward):
    """Lightning flashes, stars and a comet stripe painted on a cabinet side."""
    n = Vector((outward, 0, 0))
    o = Vector((x + outward * 0.32, 0, 0))
    for k, (y, z, s) in enumerate(((-8.0, 5.0, 1.6), (4.0, 7.2, 1.2), (14.0, 4.6, 1.9), (22.0, 7.8, 1.3))):
        outline = []
        for j in range(10):
            a = math.pi / 2 + math.pi * j / 5
            r = s if j % 2 == 0 else s * 0.42
            outline.append(o + Vector((0, y + math.cos(a) * r, z + math.sin(a) * r)))
        slab(m["PinArtYellow" if k % 2 == 0 else "PinArtCyan"], outline, 0.04, n)
    bolt = [(-12.0, 2.4), (-6.0, 3.8), (-6.8, 2.6), (2.0, 4.6), (1.4, 3.4), (10.0, 5.6)]
    for (y0, z0), (y1, z1) in zip(bolt, bolt[1:]):
        a, b = o + Vector((0, y0, z0)), o + Vector((0, y1, z1))
        d = (b - a).normalized()
        s = d.cross(n).normalized() * 0.28
        slab(m["PinArtPink"], [a - s, b - s, b + s, a + s], 0.05, n)
    for z in (1.0, 1.4):
        box(m["PinArtPink"], o + Vector((0, 6.0, z)), (0.04, 40.0, 0.18))


def build_cabinet(m):
    plan = PLAN
    for i in range(len(plan)):
        a, b = plan[i], plan[(i + 1) % len(plan)]
        door = (DOOR[0], DOOR[1], DOOR[2]) if i == 0 else None
        wall_strip(m, a, b, door=door)
    side_art(m, LEFT_X, -1)
    side_art(m, RIGHT_X, 1)
    # Chrome legs with leveller feet at the four outer corners, and a lockdown bar over the coin door.
    for x, y in ((LEFT_X - 0.9, BACK_Y + 1.5), (RIGHT_X + 0.9, BACK_Y + 1.5), (LEFT_X - 0.9, ARCH_Y + 4.0), (RIGHT_X + 0.9, ARCH_Y + 4.0)):
        extrude(m["PinChrome"], (x, y, 0.3), (x, y, 7.0), rrect(0.8, 0.8, 0.15), up=(1, 0, 0))
        lathe(m["PinChrome"], [(0, 0), (0.6, 0), (0.6, 0.15), (0.2, 0.3), (0, 0.32)], 12, transform=Matrix.Translation((x, y, 0)))
        box(m["PinChrome"], (x - (0.3 if x < CX else -0.3), y, 7.0), (0.6, 1.3, 1.4))
    extrude(m["PinChromeRails"], (LEFT_X - 0.4, BACK_Y - 0.1, GLASS_LOW + 0.1), (RIGHT_X + 0.4, BACK_Y - 0.1, GLASS_LOW + 0.1), rrect(0.9, 0.5, 0.2))


def build_coin_door(m):
    """The entrance is the coin door: a chrome frame with coin slots and return buttons beside it."""
    door, slots = m["PinCoinDoor"], m["PinCoinSlots"]
    x0, x1, h = DOOR[0] - 0.2, DOOR[1] + 0.2, DOOR[2] + 0.2
    face = BACK_Y - 0.34
    for x in (x0, x1):
        box(door, (x, face, h / 2), (0.4, 0.2, h))
    box(door, ((x0 + x1) / 2, face, h), (x1 - x0 + 0.4, 0.2, 0.4))
    # Coin panel to the right of the doorway.
    px = DOOR[1] + 2.4
    box(door, (px, face, 3.2), (2.6, 0.12, 3.6))
    for k, z in enumerate((4.2, 2.6)):
        box(m["PinCabinetTrim"], (px, face - 0.08, z), (1.8, 0.04, 1.2))
        box(slots, (px - 0.35, face - 0.12, z + 0.2), (0.14, 0.04, 0.6))
        disc(slots, (px + 0.45, face - 0.12, z - 0.2), (0, 1, 0), 0.22, 0.04, segments=16)
    for k in range(6):
        ball(door, (px - 1.1 + 0.44 * k, face - 0.08, 1.6), 0.06, subdivisions=1)


def build_glass(m):
    x0, x1, y0, y1 = LEFT_X, RIGHT_X, BACK_Y, ARCH_Y + ARCH_R

    def surface(u, v):
        x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * v
        return Vector((x, y, glass_z(y)))
    grid_surface(m["PinGlass"], surface, 30, 56, keep=lambda u, v: inside_plan(x0 + (x1 - x0) * u, y0 + (y1 - y0) * v, inset=0.1))
    # Two chrome straps across the glass.
    for y in (8.0, 22.0):
        extrude(m["PinChromeRails"], (LEFT_X, y, glass_z(y) + 0.12), (RIGHT_X, y, glass_z(y) + 0.12), rrect(0.5, 0.16, 0.06))


# ---------- the playfield ----------

def arrow(bm, centre, direction, length, width, z0=0.02, z1=0.07):
    c, d = Vector((centre[0], centre[1], 0)), Vector(direction).normalized()
    s = Vector((-d.y, d.x, 0))
    tip, back = c + d * length / 2, c - d * length / 2
    prism(bm, [tuple(back - s * width * 0.3)[:2], tuple(c - s * width * 0.3)[:2], tuple(c - s * width * 0.5)[:2], tuple(tip)[:2],
               tuple(c + s * width * 0.5)[:2], tuple(c + s * width * 0.3)[:2], tuple(back + s * width * 0.3)[:2]], z0, z1)


def circle(bm, centre, radius, z0=0.02, z1=0.07, n=16):
    prism(bm, [(centre[0] + radius * math.cos(2 * math.pi * k / n), centre[1] + radius * math.sin(2 * math.pi * k / n)) for k in range(n)], z0, z1)


def build_playfield(m):
    names = ("PinInsertsPink", "PinInsertsYellow", "PinInsertsCyan", "PinInsertsGreen")
    # Arrows pointing up the lanes either side, round inserts in arcs, triangles by the slingshots.
    for side, x in ((-1, -9.5), (1, 8.0)):
        for k in range(5):
            arrow(m[names[k % 4]], (x, 4.5 + 3.2 * k), (0, 1, 0), 2.2, 1.6)
    for k in range(9):
        a = math.radians(200 + 140 * k / 8)
        circle(m[names[(k + 1) % 4]], (CX + math.cos(a) * 11.0, ARCH_Y + 2.0 + math.sin(a) * 8.5 + 9.0), 0.55)
    for k in range(7):
        circle(m[names[k % 4]], (-12.5 + 0.0 * k, -2.0 + 2.8 * k), 0.4)
        circle(m[names[(k + 2) % 4]], (11.0, -1.0 + 2.8 * k), 0.4)
    # Big painted playfield shapes: a starburst behind the batter's ground and stripes down the sides.
    art = m["PinFloorArt"]
    for k in range(12):
        a = 2 * math.pi * k / 12
        c = Vector((-9.0, -8.0, 0))
        d, s = Vector((math.cos(a), math.sin(a), 0)), Vector((-math.sin(a), math.cos(a), 0))
        prism(art, [tuple(c + d * 1.0 - s * 0.4)[:2], tuple(c + d * (4.0 if k % 2 == 0 else 2.6))[:2], tuple(c + d * 1.0 + s * 0.4)[:2]], 0.015, 0.05)
    # Rollover lanes under the top arch: guide posts and lit lane inserts.
    for k in range(4):
        x = CX - 4.5 + 3.0 * k
        extrude(m["PinPosts"], (x, ARCH_Y + 9.0, 0.0), (x, ARCH_Y + 9.0, 1.2), rrect(0.3, 0.3, 0.1), up=(1, 0, 0))
        box(m["PinCabinetTrim"], (x, ARCH_Y + 10.4, 0.5), (0.25, 2.8, 1.0))
        if k < 3:
            circle(m[names[k]], (x + 1.5, ARCH_Y + 10.2), 0.5)
    home_plate(m["PinPlate"], 0.08)


def flipper(m, pivot, angle, length=4.2):
    """A flipper lying on the playfield, its rubber round the edge, on a chrome pivot."""
    p = Vector(pivot)
    d = Vector((math.cos(angle), math.sin(angle), 0))
    s = Vector((-d.y, d.x, 0))
    # A tapered capsule, counter-clockwise: round the small tip, then round the wide pivot end.
    tip = p + d * length
    outline = [tip + (d * math.cos(t) + s * math.sin(t)) * 0.3 for t in [-math.pi / 2 + math.pi * k / 8 for k in range(9)]] + \
              [p + (d * math.cos(t) + s * math.sin(t)) * 0.6 for t in [math.pi / 2 + math.pi * k / 10 for k in range(11)]]
    prism(m["PinFlippers"], [(q.x, q.y) for q in outline], 0.15, 0.85)
    sweep(m["PinRubber"], [Vector((q.x, q.y, 0.5)) for q in outline] + [Vector((outline[0].x, outline[0].y, 0.5))], 0.18, segments=6)
    lathe(m["PinChrome"], [(0, 0), (0.35, 0), (0.3, 1.0), (0, 1.05)], 12, transform=Matrix.Translation(p))


def slingshot(m, a, b, c):
    """A triangular slingshot kicker with a rubber band on its inner face and chrome posts."""
    pts = [Vector(a), Vector(b), Vector(c)]
    prism(m["PinSlings"], [(p.x, p.y) for p in pts], 0.0, 1.0)
    for p in pts:
        lathe(m["PinPosts"], [(0, 0), (0.22, 0), (0.22, 1.3), (0, 1.35)], 10, transform=Matrix.Translation(p))
    sweep(m["PinRubber"], [pts[0] + Vector((0, 0, 0.7)), pts[1] + Vector((0, 0, 0.7))], 0.14, segments=6)


def bumper(m, name, x, y, r):
    """A pop bumper: dark base, white skirt, a glowing cap (its own mesh, so each pulses alone)."""
    c = Vector((x, y, 0))
    lathe(m["PinBumperBases"], [(0, 0), (r * 1.15, 0), (r * 1.15, 0.5), (r * 0.8, 0.6), (0, 0.6)], 24, transform=Matrix.Translation(c))
    lathe(m["PinBumperSkirts"], [(r * 0.55, 0.6), (r * 1.3, 1.2), (r * 1.3, 1.35), (r * 0.55, 1.0)], 24, transform=Matrix.Translation(c))
    lathe(m["PinBumperSkirts"], [(0, 1.0), (r * 0.55, 1.0), (r * 0.5, 2.4), (0, 2.4)], 20, transform=Matrix.Translation(c))
    lathe(m[name], [(0, 2.35), (r * 0.95, 2.35), (r * 1.0, 2.7), (r * 0.8, 3.1), (r * 0.4, 3.3), (0, 3.35)], 24, transform=Matrix.Translation(c))
    torus(m["PinChrome"], c + Vector((0, 0, 2.4)), (0, 0, 1), r * 0.96, 0.07, segments=24, minor_segments=4)


def spinner(m, name, centre):
    """A spinner: a chrome plate on a wire axle across a lane (it turns about Blender X)."""
    c = Vector(centre)
    box(m[name], c, (0.06, 1.6, 1.0))
    for z in (-0.35, 0.35):
        box(m[name], c + Vector((0, 0, z)), (0.08, 1.4, 0.06))
    for sy in (-1, 1):
        extrude(m["PinPosts"], (c.x, c.y + sy * 1.05, 0.0), (c.x, c.y + sy * 1.05, c.z + 0.65), rrect(0.18, 0.18, 0.05), up=(1, 0, 0))
    tube(m["PinPosts"], c - Vector((0, 1.05, 0)), c + Vector((0, 1.05, 0)), 0.04, 6)


def build_toys(m):
    # Flippers along both sides: a lower pair by the batter's end and an upper pair halfway up.
    for y, length in ((-1.0, 4.4), (17.0, 3.6)):
        flipper(m, (LEFT_X + 1.2, y, 0), math.radians(-28), length)
        flipper(m, (RIGHT_X - 1.2, y, 0), math.radians(180 + 28), length)
    slingshot(m, (LEFT_X + 1.0, 3.0, 0), (LEFT_X + 1.0, 8.0, 0), (LEFT_X + 3.8, 3.4, 0))
    slingshot(m, (RIGHT_X - 1.0, 3.0, 0), (RIGHT_X - 1.0, 8.0, 0), (RIGHT_X - 3.8, 3.4, 0))
    for name, (x, y, r) in BUMPERS.items():
        bumper(m, name, x, y, r)
    for name, c in SPINNERS.items():
        spinner(m, name, c)
    # A bank of drop targets along the right wall.
    for k in range(5):
        y = 27.0 + 1.05 * k
        box(m["PinTargets"], (RIGHT_X - 1.4, y, 0.8), (0.3, 0.9, 1.6))
        box(m["PinCabinetTrim"], (RIGHT_X - 1.1, y, 0.3), (0.4, 1.0, 0.6))
    # The star turntable, turning about its centre.
    disc(m["PinTurntable"], TURNTABLE + Vector((0, 0, 0.06)), (0, 0, 1), 2.2, 0.12, segments=32)
    outline = []
    for j in range(12):
        a = math.pi / 2 + math.pi * j / 6
        r = 1.8 if j % 2 == 0 else 0.75
        outline.append((TURNTABLE.x + r * math.cos(a), TURNTABLE.y + r * math.sin(a)))
    prism(m["PinTurntableStar"], outline, 0.12, 0.2)
    # A clear wire ramp looping up the left side and over toward the top arch.
    path = [Vector((-12.5, 2.0, 0.3)), Vector((-13.0, 10.0, 3.5)), Vector((-12.5, 20.0, 6.5)), Vector((-9.0, 30.0, 7.5)),
            Vector((-2.0, 35.0, 7.0)), Vector((4.0, 37.0, 5.5)), Vector((9.0, 35.0, 4.0))]
    line = Polyline(path).samples(0.6)
    frames = sweep_frames(line)
    left, right = [], []
    for p, (t, nrm, bin_) in zip(line, frames):
        side = t.cross(Vector((0, 0, 1))).normalized()
        left.append(p - side * 0.9)
        right.append(p + side * 0.9)
    double_sided_strip(m["PinRamp"], left, right)
    for edge in (left, right):
        sweep(m["PinRampRails"], [q + Vector((0, 0, 0.5)) for q in edge], 0.06, segments=5)
    for q in line[::6]:
        extrude(m["PinPosts"], (q.x, q.y, 0.0), (q.x, q.y, q.z), rrect(0.16, 0.16, 0.05), up=(1, 0, 0))


# ---------- the plunger and the backglass ----------

def build_plunger(m):
    """The shooter lane: a raised lane under the ball, a chrome plunger rod with its spring, a
    housing and a red knob; the ball rests against the plunger tip at PITCH."""
    x = PITCH.x
    lane = m["PinShooterLane"]
    box(lane, (x, 27.8, (PITCH.z - BALL_RADIUS) / 2), (1.2, 8.4, PITCH.z - BALL_RADIUS))
    for sx in (-1, 1):
        box(m["PinChromeRails"], (x + sx * 0.62, 27.8, PITCH.z - 0.1), (0.1, 8.4, 0.7))
    rod_end = PITCH.y + 6.8
    tube(m["PinChrome"], (x, PLUNGER_TIP, PITCH.z), (x, rod_end, PITCH.z), 0.13, 12)
    disc(m["PinChrome"], (x, PLUNGER_TIP + 0.04, PITCH.z), (0, 1, 0), 0.32, 0.1, segments=20)
    coil = []
    for k in range(121):
        t = k / 120
        a = 2 * math.pi * 9 * t
        coil.append(Vector((x + 0.34 * math.cos(a), PLUNGER_TIP + 0.4 + 3.0 * t, PITCH.z + 0.34 * math.sin(a))))
    sweep(m["PinSpring"], coil, 0.05, segments=6)
    box(m["PinCabinet"], (x, PLUNGER_TIP + 3.75, PITCH.z - 0.3), (2.2, 0.6, 2.6))
    box(m["PinChrome"], (x, PLUNGER_TIP + 3.42, PITCH.z), (1.5, 0.08, 1.5))
    ball(m["PinPlungerKnob"], (x, rod_end + 0.35, PITCH.z), 0.48, subdivisions=3)
    torus(m["PinChrome"], (x, rod_end, PITCH.z), (0, 1, 0), 0.26, 0.08, segments=16, minor_segments=5)
    pitch_ball(m["PinBall"])


SEGMENTS = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcfgd"}


def digit(bm, centre, char, h, y, thickness=0.05):
    """A seven-segment digit standing in the XZ plane at y, facing -Y."""
    cx, cz = centre
    w, s = h * 0.5, h * 0.09
    bars = {"a": ((-w / 2, h / 2), (w / 2, h / 2)), "d": ((-w / 2, -h / 2), (w / 2, -h / 2)), "g": ((-w / 2, 0), (w / 2, 0)),
            "f": ((-w / 2, 0), (-w / 2, h / 2)), "b": ((w / 2, 0), (w / 2, h / 2)), "e": ((-w / 2, -h / 2), (-w / 2, 0)), "c": ((w / 2, -h / 2), (w / 2, 0))}
    for key in SEGMENTS[char]:
        (ax, az), (bx, bz) = bars[key]
        if ax == bx:
            box(bm, (cx + ax, y, cz + (az + bz) / 2), (s, thickness, abs(bz - az) - s * 0.6))
        else:
            box(bm, (cx + (ax + bx) / 2, y, cz + az), (abs(bx - ax) - s * 0.6, thickness, s))


def build_backglass(m):
    """The screen is the scoreboard backglass: a cabinet-coloured backbox with dark glass, art, a
    glowing seven-segment score, speaker grilles and the window cut through."""
    y = SCREEN_Y
    x0, x1, z0, z1 = PITCH.x - 3.6, PITCH.x + 3.6, 0.3, 7.6
    window_panel(m["PinBackbox"], [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], y + 0.12, 0.3, segments=64)
    window_panel(m["PinBackglass"], [(x0 + 0.35, z0 + 0.35), (x1 - 0.35, z0 + 0.35), (x1 - 0.35, z1 - 0.35), (x0 + 0.35, z1 - 0.35)], y - 0.08, 0.06,
                 segments=64)
    front = y - 0.13
    torus(m["PinChromeRails"], (PITCH.x, front, PITCH.z), (0, 1, 0), WINDOW + 0.14, 0.09, segments=36, minor_segments=5)
    # The score across the top, and the ball count and credits below.
    for k, ch in enumerate("1450980"):
        digit(m["PinScore"], (x0 + 0.95 + k * 0.88, 6.55), ch, 1.1, front - 0.01)
    for k, ch in enumerate("3"):
        digit(m["PinScore"], (x0 + 1.0, 4.9), ch, 0.7, front - 0.01)
    for k, ch in enumerate("12"):
        digit(m["PinScore"], (x1 - 1.4 + k * 0.5, 4.9), ch, 0.7, front - 0.01)
    # Art: a comet streaking over stars on the dark glass.
    for k in range(9):
        cx, cz = rng.uniform(x0 + 0.6, x1 - 0.6), rng.uniform(1.0, 5.6)
        if math.hypot(cx - PITCH.x, cz - PITCH.z) < WINDOW + 0.7:
            continue
        outline = []
        for j in range(8):
            a = math.pi / 2 + math.pi * j / 4
            r = 0.3 if j % 2 == 0 else 0.1
            outline.append(Vector((cx + r * math.cos(a), front - 0.01, cz + r * math.sin(a))))
        slab(m["PinArtYellow"], outline, 0.03, Vector((0, -1, 0)))
    comet = [(x0 + 0.8, 1.3), (PITCH.x - 1.5, 2.2)]
    for (ax, az), (bx, bz) in zip(comet, comet[1:]):
        for k, w in enumerate((0.35, 0.22, 0.1)):
            a, b = Vector((ax, front - 0.012 - 0.003 * k, az)), Vector((bx, front - 0.012 - 0.003 * k, bz))
            d = (b - a).normalized()
            s = Vector((-d.z, 0, d.x)) * w
            slab(m["PinArtPink" if k == 0 else "PinArtCyan" if k == 1 else "PinArtYellow"], [a - s * 0.2, b - s, b + s, a + s * 0.2], 0.02, Vector((0, -1, 0)))
    # Speaker grilles either side of the window and a chrome trim round the box.
    for sx in (-1, 1):
        c = Vector((PITCH.x + sx * 2.45, front - 0.02, 2.2))
        disc(m["PinSpeakers"], c, (0, 1, 0), 0.75, 0.03, segments=24)
        for k in range(12):
            a = 2 * math.pi * k / 12
            ball(m["PinChrome"], c + Vector((math.cos(a) * 0.5, -0.03, math.sin(a) * 0.5)), 0.05, subdivisions=1)
    for a, b in (((x0, z0), (x1, z0)), ((x0, z1), (x1, z1)), ((x0, z0), (x0, z1)), ((x1, z0), (x1, z1))):
        extrude(m["PinChromeRails"], (a[0], front, a[1]), (b[0], front, b[1]), rrect(0.2, 0.2, 0.05))
    for sx in (-1, 1):
        extrude(m["PinChrome"], (PITCH.x + sx * 3.2, y + 0.4, 0.0), (PITCH.x + sx * 3.3, y + 2.2, 0.0), rrect(0.3, 0.2, 0.05))


# ---------- the head, lights and playfield trim ----------

def build_head(m):
    """The backbox head standing up at the top arch end: a cabinet box with a marquee, art and a
    border of chase lights, on chrome hinges."""
    y0, y1, z0, z1 = ARCH_Y + ARCH_R - 3.0, ARCH_Y + ARCH_R - 0.8, glass_z(ARCH_Y + ARCH_R - 3.0) - 0.3, 23.0
    x0, x1 = CX - 6.5, CX + 6.5
    box(m["PinBackbox"], ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0))
    face = y0 - 0.02
    box(m["PinBackglass"], ((x0 + x1) / 2, face, (z0 + z1) / 2 - 0.6), (x1 - x0 - 1.2, 0.06, z1 - z0 - 3.0))
    box(m["PinArtPink"], ((x0 + x1) / 2, face - 0.05, z1 - 1.0), (x1 - x0 - 1.0, 0.06, 1.2))
    # Art on the head glass: a ringed planet, a rocket and stars.
    planet = Vector((CX - 2.4, face - 0.06, (z0 + z1) / 2))
    disc(m["PinArtCyan"], planet, (0, 1, 0), 1.7, 0.05, segments=32)
    annulus(m["PinArtYellow"], planet + Vector((0, -0.03, 0)), (0, 1, 0.25), 2.1, 2.6, 0.04, segments=40)
    rocket = Vector((CX + 3.4, face - 0.07, (z0 + z1) / 2 - 1.0))
    slab(m["PinArtPink"], [rocket + Vector((-0.9, 0, -2.4)), rocket + Vector((0.9, 0, -2.4)), rocket + Vector((0.9, 0, 1.6)), rocket + Vector((0, 0, 3.4)),
                           rocket + Vector((-0.9, 0, 1.6))], 0.05, Vector((0, -1, 0)))
    for sx in (-1, 1):
        slab(m["PinArtYellow"], [rocket + Vector((sx * 0.9, -0.01, -2.4)), rocket + Vector((sx * 2.0, -0.01, -3.0)), rocket + Vector((sx * 0.9, -0.01, -0.6))],
             0.05, Vector((0, -1, 0)))
    disc(m["PinArtCyan"], rocket + Vector((0, -0.02, 0.6)), (0, 1, 0), 0.6, 0.05, segments=20)
    for k in range(14):
        cx, cz = rng.uniform(x0 + 1, x1 - 1), rng.uniform(z0 + 1, z1 - 2.5)
        outline = []
        for j in range(8):
            a = math.pi / 2 + math.pi * j / 4
            r = 0.45 if j % 2 == 0 else 0.14
            outline.append(Vector((cx + r * math.cos(a), face - 0.08, cz + r * math.sin(a))))
        slab(m["PinArtYellow"], outline, 0.03, Vector((0, -1, 0)))
    # Chase lights round the head's face, alternating between two meshes that blink in turn.
    border = [Vector((x0 + 0.3, face - 0.1, z0 + 0.3)), Vector((x1 - 0.3, face - 0.1, z0 + 0.3)), Vector((x1 - 0.3, face - 0.1, z1 - 0.3)),
              Vector((x0 + 0.3, face - 0.1, z1 - 0.3)), Vector((x0 + 0.3, face - 0.1, z0 + 0.3))]
    for k, p in enumerate(Polyline(border).samples(0.8)):
        ball(m["PinChaseA" if k % 2 == 0 else "PinChaseB"], p, 0.16, subdivisions=1)
    for sx in (-1, 1):
        box(m["PinChrome"], (CX + sx * 5.2, (y0 + y1) / 2, z0 - 0.2), (1.4, y1 - y0 + 0.2, 0.4))


def build_lights(m):
    """Chase lights along the top rails, glowing strips along the inside of the walls."""
    k = 0
    for i in range(len(PLAN)):
        a, b = PLAN[i], PLAN[(i + 1) % len(PLAN)]
        if i == 0:
            continue
        t = (b - a).normalized()
        n = Vector((-t.y, t.x, 0))
        length = (b - a).length
        steps = max(1, int(length / 1.6))
        for j in range(steps):
            p = a + t * (length * (j + 0.5) / steps) - n * 0.55
            ball(m["PinChaseA" if k % 2 == 0 else "PinChaseB"], (p.x, p.y, glass_z(p.y) - 0.15), 0.14, subdivisions=1)
            k += 1
        for z in (1.2, 4.6):
            q0, q1 = a + n * 0.34, b + n * 0.34
            extrude(m["PinWallGlow"], (q0.x, q0.y, z), (q1.x, q1.y, z), rrect(0.08, 0.16, 0.03))


def build_trim(m):
    """Lane guides by the flippers, rollover buttons, the apron and a painted planet ring."""
    rails = m["PinChromeRails"]
    for sx, x in ((-1, LEFT_X + 1.2), (1, RIGHT_X - 1.2)):
        for y0, y1, dx in ((-1.5, 6.5, 2.4), (-0.5, 8.5, 1.2)):
            sweep(rails, [Vector((x - sx * dx, y0, 0.55)), Vector((x - sx * dx * 0.6, (y0 + y1) / 2, 0.55)), Vector((x - sx * 0.3, y1, 0.55))], 0.07, segments=5)
            for y in (y0, y1):
                extrude(m["PinPosts"], (x - sx * dx * (1.0 if y == y0 else 0.0) - (0 if y == y0 else sx * 0.3), y, 0.0),
                        (x - sx * dx * (1.0 if y == y0 else 0.0) - (0 if y == y0 else sx * 0.3), y, 0.6), rrect(0.16, 0.16, 0.05), up=(1, 0, 0))
    for k in range(6):
        x, y = rng.choice((rng.uniform(-13, -5), rng.uniform(7, 12))), rng.uniform(5, 30)
        lathe(m["PinChrome"], [(0, 0.02), (0.38, 0.02), (0.34, 0.14), (0, 0.18)], 12, transform=Matrix.Translation((x, y, 0)))
    box(m["PinCabinetTrim"], (CX, BACK_Y + 1.6, 0.25), (RIGHT_X - LEFT_X - 1.2, 2.8, 0.5))
    for k in range(4):
        box(m["PinArtYellow"], (CX - 9 + 6 * k, BACK_Y + 1.6, 0.52), (3.2, 1.6, 0.04))
    annulus(m["PinFloorArt"], TURNTABLE + Vector((0, 0, 0.03)), (0, 0, 1), 2.6, 3.4, 0.03, segments=40)
    for k in range(10):
        a = 2 * math.pi * k / 10
        circle(m["PinInsertsCyan" if k % 2 else "PinInsertsPink"], (TURNTABLE.x + math.cos(a) * 3.0, TURNTABLE.y + math.sin(a) * 3.0), 0.22)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = meshes(LOOKS)
    build_head(m)
    build_lights(m)
    build_trim(m)
    build_cabinet(m)
    build_coin_door(m)
    build_glass(m)
    build_playfield(m)
    build_toys(m)
    build_plunger(m)
    build_backglass(m)
    objects = build_looks(coll, m, LOOKS)
    spins = {name: (c, (1, 0, 0)) for name, c in SPINNERS.items()}
    spins["PinTurntable"] = (TURNTABLE, (0, 0, 1))
    spins["PinTurntableStar"] = (TURNTABLE, (0, 0, 1))
    check_centred(objects, spins)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
