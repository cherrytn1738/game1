# Training Ground 5 of World 2, Time Machine Lab (opened by Cosmic Rift's pass): World 2's showpiece.
# The batting cage is an oval brass-and-glass rotunda: riveted brass wainscot, glass panes between
# brass mullions, and a glass dome with brass ribs and a turning gear crown at its oculus. Trains of
# meshing gears turn on both side walls, and a clockwork armillary of three toothed rings turns round
# a glowing core high over the hall. The floor is a giant clock face with Roman numerals and two
# turning hands. At the machine end a brass time portal's swirling core holds the ball at PITCH,
# its toothed ring turning. In front of it is a riveted brass screen with gauges and valve wheels.
# Tesla coils spark in the front corners, copper pipes and a control console stand by the portal,
# and clocks and relics from every era of World 2 (a club, a pharaoh's mask, a Roman helmet, a
# samurai helmet, a dinosaur skull, a rocket, an hourglass) drift and turn round the dome.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "TimeMachineLabCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\TimeMachineLabCage.fbx"

BRASS = (0.82, 0.6, 0.26)
BRASS_DARK = (0.56, 0.38, 0.16)
COPPER = (0.78, 0.4, 0.22)
GLASS = (0.7, 0.86, 0.92)
IVORY = (0.95, 0.92, 0.84)
INK = (0.1, 0.08, 0.07)
CYAN = (0.3, 0.9, 1.0)
VIOLET = (0.62, 0.32, 1.0)
IRON = (0.24, 0.24, 0.27)
rng = random.Random(91)

CX, CY = (LEFT_X + RIGHT_X) / 2, 10.0
RX, RY, POWER = 18.5, 28.0, 4.0            # the rotunda's oval plan
WALL_TOP, DOME_H = 10.2, 8.8
CLOCK = Vector((CX, 13.0, 0.0))            # the clock-face floor, clear of the batter's boxes
CLOCK_R = 9.5
ARMILLARY = Vector((CX, 11.0, 14.4))
PORTAL = Vector((PITCH.x, 25.2, PITCH.z))  # the portal ring centre (the core is level with the ball)
PORTAL_R = 4.4                             # the portal ring's outer radius
DOOR_X = (DOOR[0] - 0.2, DOOR[1] + 0.2)
GEARS = {   # name: (centre (y, z), radius, teeth, side)
    "ChronoGearA": ((8.5, 5.2), 2.3, 24, -1), "ChronoGearB": ((11.7, 7.3), 1.5, 16, -1), "ChronoGearC": ((13.9, 6.1), 0.95, 10, -1),
    "ChronoGearD": ((8.5, 5.2), 2.3, 24, 1), "ChronoGearE": ((11.7, 7.3), 1.5, 16, 1), "ChronoGearF": ((13.9, 6.1), 0.95, 10, 1),
}
RINGS = {   # armillary rings: (radius, normal)
    "ChronoRingA": (4.4, Vector((0.0, 0.0, 1.0))), "ChronoRingB": (3.7, Vector((1.0, 0.0, 0.35)).normalized()),
    "ChronoRingC": (3.0, Vector((0.3, 1.0, -0.2)).normalized()),
}
FLOATERS = {   # drifting relics: centre
    "ChronoFloatClub": Vector((-13.6, 3.0, 11.2)), "ChronoFloatMask": Vector((-13.0, 19.0, 12.2)),
    "ChronoFloatHelmet": Vector((11.0, 4.0, 11.6)), "ChronoFloatKabuto": Vector((10.6, 20.0, 12.4)),
    "ChronoFloatSkull": Vector((-8.0, 30.5, 12.8)), "ChronoFloatRocket": Vector((6.0, 31.0, 13.2)),
    "ChronoFloatWatchA": Vector((-12.4, 11.0, 13.6)), "ChronoFloatWatchB": Vector((10.0, 12.0, 13.4)),
    "ChronoFloatWatchC": Vector((CX, -6.0, 14.0)),
}

LOOKS = {
    "ChronoBrass": (BRASS, "hard"), "ChronoBrassFrame": (BRASS, "hard"), "ChronoBrassDark": (BRASS_DARK, "hard"), "ChronoBrassPlate": (BRASS, "hard"),
    "ChronoRivets": (BRASS_DARK, "smooth"), "ChronoCopper": (COPPER, "smooth"), "ChronoIron": (IRON, "hard"),
    "ChronoGlass": (GLASS, "hard"), "ChronoDome": (GLASS, "soft"), "ChronoDomeRibs": (BRASS, "smooth"),
    "ChronoCrownGear": (BRASS, "hard"), "ChronoClockFace": (IVORY, "hard"), "ChronoClockInk": (INK, "hard"),
    "ChronoHandHour": (INK, "hard"), "ChronoHandMinute": (INK, "hard"), "ChronoFloorGrate": (IRON, "hard"),
    "ChronoPortalRing": (BRASS, "hard"), "ChronoPortalGear": (BRASS_DARK, "hard"), "ChronoPortalRim": (CYAN, "smooth"),
    "ChronoPortalSwirl": (VIOLET, "soft"), "ChronoPortalCore": (CYAN, "smooth"),
    "ChronoScreen": (BRASS, "hard"), "ChronoGauges": (IVORY, "hard"), "ChronoGlow": (CYAN, "smooth"),
    "ChronoCoils": (COPPER, "smooth"), "ChronoArcs": (CYAN, "soft"), "ChronoCore": ((1.0, 0.9, 0.6), "smooth"),
    "ChronoConsole": (BRASS_DARK, "hard"), "ChronoButtons": ((1.0, 0.3, 0.2), "smooth"),
    "ChronoFloatHourglass": (BRASS, "smooth"), "ChronoFloatSand": ((0.95, 0.8, 0.45), "smooth"),
    "ChronoPlate": (IVORY, "hard"), "ChronoBall": (WHITE, "smooth"),
}
for name in GEARS:
    LOOKS[name] = (BRASS, "hard")
for name in RINGS:
    LOOKS[name] = (BRASS, "hard")
for name in FLOATERS:
    LOOKS[name] = (BRASS, "smooth")
LOOKS["ChronoFloatWatchFaces"] = (IVORY, "hard")
LOOKS["ChronoFloatWatchTicks"] = (INK, "hard")
LOOKS["ChronoFloatHourglassGlass"] = (GLASS, "smooth")


# ---------- the rotunda's plan ----------

PLAN = Polyline(squircle_points(CX, CY, RX, RY, -math.pi / 2, 3 * math.pi / 2, 401, p=POWER))


def plan_frame(s):
    s %= PLAN.length
    p = PLAN.at(s)
    t = (PLAN.at(min(PLAN.length, s + 0.05)) - PLAN.at(max(0.0, s - 0.05))).normalized()
    return p, t, Vector((-t.y, t.x, 0))


def in_door(x):
    return DOOR_X[0] < x < DOOR_X[1]


def numeral_strokes(text, height):
    """Roman numeral strokes as ((x0, y0), (x1, y1)) in a box of the given height, centred."""
    strokes, x = [], 0.0
    for ch in text:
        if ch == "I":
            strokes.append(((x, 0), (x, height)))
            x += height * 0.32
        elif ch == "V":
            strokes += [((x, height), (x + height * 0.3, 0)), ((x + height * 0.3, 0), (x + height * 0.6, height))]
            x += height * 0.82
        else:
            strokes += [((x, 0), (x + height * 0.6, height)), ((x, height), (x + height * 0.6, 0))]
            x += height * 0.82
    width = x - height * 0.22
    return [((a[0] - width / 2, a[1] - height / 2), (b[0] - width / 2, b[1] - height / 2)) for a, b in strokes]


def numeral(bm, centre, up, normal, text, height, width=0.1, thickness=0.04):
    """Raised numeral strokes on a surface: up points toward the numeral's top."""
    c, up, n = Vector(centre), Vector(up).normalized(), Vector(normal).normalized()
    right = up.cross(n).normalized()
    for (ax, ay), (bx, by) in numeral_strokes(text, height):
        a = c + right * ax + up * ay
        b = c + right * bx + up * by
        d = (b - a).normalized()
        s = d.cross(n).normalized() * width / 2
        slab(bm, [a - s, b - s, b + s, a + s], thickness, n)


ROMAN = ("XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI")


# ---------- walls, dome and door ----------

def build_walls(m):
    count = 2 * round(PLAN.length / 2.6 / 2)
    step = PLAN.length / count
    brass, plate, glass = m["ChronoBrassFrame"], m["ChronoBrassPlate"], m["ChronoGlass"]
    for i in range(count):
        a, _, na = plan_frame(i * step)
        b, _, nb = plan_frame((i + 1) * step)
        mid = (a + b) / 2
        t = (b - a).normalized()
        n = Vector((-t.y, t.x, 0))
        turn = Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z")
        length = (b - a).length
        door = in_door(mid.x) and mid.y < CY
        extrude(brass, (a.x, a.y, 0.0), (a.x, a.y, WALL_TOP + 0.2), rrect(0.32, 0.32, 0.08), up=(t.x, t.y, 0))
        lathe(m["ChronoBrassDark"], [(0, WALL_TOP + 0.2), (0.3, WALL_TOP + 0.2), (0.36, WALL_TOP + 0.4), (0.16, WALL_TOP + 0.6), (0, WALL_TOP + 0.7)], 8,
              transform=Matrix.Translation((a.x, a.y, 0)))
        if not door:
            box(plate, (mid.x, mid.y, 1.35), (length, 0.14, 2.5), turn)
            box(glass, (mid.x, mid.y, (2.7 + WALL_TOP) / 2), (length - 0.3, 0.06, WALL_TOP - 2.7), turn)
            for z in (2.65, 6.3):
                box(brass, (mid.x, mid.y, z), (length, 0.22, 0.16), turn)
            for z in (0.35, 2.3):
                for k in range(4):
                    p = a + t * (length * (k + 0.5) / 4) + n * 0.09
                    ball(m["ChronoRivets"], (p.x, p.y, z), 0.06, subdivisions=1)
            # A porthole medallion on every other panel's wainscot.
            if i % 2 == 0:
                c = mid + n * 0.09
                torus(brass, (c.x, c.y, 1.35), n, 0.55, 0.07, segments=20, minor_segments=5)
                disc(m["ChronoGlow"], (c.x, c.y, 1.35), n, 0.46, 0.04, segments=20)
        else:
            box(glass, (mid.x, mid.y, (DOOR[2] + 0.6 + WALL_TOP) / 2), (length - 0.3, 0.06, WALL_TOP - DOOR[2] - 0.6), turn)
        box(brass, (mid.x, mid.y, WALL_TOP), (length, 0.28, 0.24), turn)
    profile_along(m["ChronoBrassDark"], PLAN.samples(PLAN.length / 240)[:-1], [(-0.35, 0.0), (0.35, 0.0), (0.35, 0.22), (-0.35, 0.22)], closed=True)


def build_door(m):
    """A brass arch frame round the door, a large gear over it and a clock above that."""
    mid_x = (DOOR[0] + DOOR[1]) / 2
    y = CY - RY * (1 - (abs(mid_x - CX) / RX) ** POWER) ** (1 / POWER)
    half = (DOOR_X[1] - DOOR_X[0]) / 2
    arch = [Vector((mid_x - half, y, 0.0)), Vector((mid_x - half, y, DOOR[2] - 1.0))]
    for k in range(1, 16):
        a = math.pi * (1 - k / 16)
        arch.append(Vector((mid_x + half * math.cos(a), y, DOOR[2] - 1.0 + 1.3 * math.sin(a))))
    arch += [Vector((mid_x + half, y, DOOR[2] - 1.0)), Vector((mid_x + half, y, 0.0))]
    sweep_profile(m["ChronoBrass"], arch, rrect(0.5, 0.6, 0.1))
    for p in Polyline(arch).samples(0.7):
        ball(m["ChronoRivets"], p + Vector((0, -0.32, 0)), 0.07, subdivisions=1)
    gear(m["ChronoBrassDark"], (mid_x, y - 0.25, DOOR[2] + 1.0), (0, 1, 0), 1.2, 16, 0.2, tooth=0.25, rim=0.25, spokes=6, hub=0.3)
    disc(m["ChronoClockFace"], (mid_x, y - 0.45, DOOR[2] + 1.0), (0, 1, 0), 0.75, 0.05, segments=24)
    for k in range(12):
        a = 2 * math.pi * k / 12
        box(m["ChronoClockInk"], (mid_x + math.cos(a) * 0.62, y - 0.49, DOOR[2] + 1.0 + math.sin(a) * 0.62), (0.06, 0.03, 0.14),
            Matrix.Rotation(-a + math.pi / 2, 4, "Y"))
    box(m["ChronoClockInk"], (mid_x + 0.2, y - 0.5, DOOR[2] + 1.05), (0.42, 0.03, 0.06))
    box(m["ChronoClockInk"], (mid_x, y - 0.5, DOOR[2] + 1.3), (0.05, 0.03, 0.6))


def build_dome(m):
    rings, segments, top_v = 14, 72, 0.9

    def point(u, v):
        h = math.cos(v * math.pi / 2)
        c, s = math.cos(2 * math.pi * u), math.sin(2 * math.pi * u)
        return Vector((CX + RX * h * math.copysign(abs(c) ** (2 / POWER), c), CY + RY * h * math.copysign(abs(s) ** (2 / POWER), s),
                       WALL_TOP + 0.2 + DOME_H * math.sin(v * math.pi / 2)))
    grid_surface(m["ChronoDome"], lambda u, v: point(u, v * top_v), segments, rings)
    ribs = m["ChronoDomeRibs"]
    for k in range(20):
        u = k / 20
        sweep(ribs, [point(u, top_v * j / 16) for j in range(17)], 0.16, segments=6)
    for v in (0.0, 0.3, 0.55, 0.75, top_v):
        line = [point(j / 96, v) for j in range(97)]
        sweep(ribs, line, 0.14 if v > 0 else 0.2, segments=6)
    # The oculus: a brass collar, a little glass lantern and a gear crown that turns round it.
    top = point(0, top_v)
    z = top.z
    cx, cy = CX, CY
    lathe(m["ChronoBrass"], [(0, z - 0.1), (2.9, z - 0.1), (2.9, z + 0.3), (1.9, z + 0.4), (1.8, z + 2.0), (2.1, z + 2.2), (0, z + 2.6)], 24,
          transform=Matrix.Translation((cx, cy, 0)))
    lathe(m["ChronoGlow"], [(1.85, z + 0.45), (1.86, z + 0.45), (1.86, z + 1.95), (1.85, z + 1.95)], 24, transform=Matrix.Translation((cx, cy, 0)))
    ball(m["ChronoBrass"], (cx, cy, z + 2.9), 0.3, subdivisions=2)
    gear(m["ChronoCrownGear"], (cx, cy, z + 0.75), (0, 0, 1), 3.4, 32, 0.3, tooth=0.4, rim=0.35, spokes=0, hub=0)


# ---------- the floor clock ----------

def build_floor(m):
    face, ink, brass = m["ChronoClockFace"], m["ChronoClockInk"], m["ChronoBrass"]
    c = CLOCK
    disc(face, c + Vector((0, 0, 0.06)), (0, 0, 1), CLOCK_R, 0.06, segments=72)
    annulus(brass, c + Vector((0, 0, 0.07)), (0, 0, 1), CLOCK_R, CLOCK_R + 0.6, 0.14, segments=72)
    for r in (7.3, 3.3):
        torus(brass, c + Vector((0, 0, 0.1)), (0, 0, 1), r, 0.07, segments=64, minor_segments=4)
    for k in range(60):
        a = math.pi / 2 - 2 * math.pi * k / 60
        d = Vector((math.cos(a), math.sin(a), 0))
        long = k % 5 == 0
        p = c + d * (8.9 - (0.3 if long else 0.15)) + Vector((0, 0, 0.11))
        box(ink, p, (0.12 if not long else 0.22, 0.6 if long else 0.3, 0.04), Matrix.Rotation(a - math.pi / 2, 4, "Z"))
    for k, text in enumerate(ROMAN):
        a = math.pi / 2 - 2 * math.pi * k / 12
        d = Vector((math.cos(a), math.sin(a), 0))
        numeral(ink, c + d * 7.9 + Vector((0, 0, 0.11)), d, (0, 0, 1), text, 0.95, width=0.13)
    # Decorative sunburst between the rings.
    for k in range(24):
        a = 2 * math.pi * k / 24
        d, s = Vector((math.cos(a), math.sin(a), 0)), Vector((-math.sin(a), math.cos(a), 0))
        slab(brass, [c + d * 3.5 - s * 0.25, c + d * (6.6 if k % 2 == 0 else 5.4), c + d * 3.5 + s * 0.25], 0.04, Vector((0, 0, 1)))
    disc(brass, c + Vector((0, 0, 0.25)), (0, 0, 1), 0.7, 0.3, segments=24)
    # The two hands turn about the centre. Each is built symmetric (a tip one way, a counterweight
    # ring the same length the other way), so it spins about its own middle.
    for name, length, width, z in (("ChronoHandMinute", 7.0, 0.26, 0.2), ("ChronoHandHour", 4.8, 0.36, 0.28)):
        hand = m[name]
        heading = Vector((1, 0, 0)) if name == "ChronoHandMinute" else Vector((0, 1, 0))
        side = Vector((-heading.y, heading.x, 0))
        base = c + Vector((0, 0, z))
        slab(hand, [base - heading * (length - 0.6) - side * width / 2, base + heading * (length - 0.6) - side * width / 2,
                    base + heading * (length - 0.6) + side * width / 2, base - heading * (length - 0.6) + side * width / 2], 0.05, Vector((0, 0, 1)))
        tip = base + heading * length
        slab(hand, [base + heading * (length - 0.9) - side * 0.45, tip + heading * 0.6, base + heading * (length - 0.9) + side * 0.45], 0.05, Vector((0, 0, 1)))
        torus(hand, base - heading * length, (0, 0, 1), 0.42, 0.18, segments=16, minor_segments=4)
        for sgn in (-1, 1):
            q = base + heading * sgn * length * 0.55
            slab(hand, [q - heading * 0.6, q - side * 0.42, q + heading * 0.6, q + side * 0.42], 0.05, Vector((0, 0, 1)))
    # Iron floor gratings and copper pipes round the edge.
    for k in range(10):
        a = 2 * math.pi * (k + 0.5) / 10
        p = Vector((CX + (RX - 2.5) * math.cos(a) * 0.95, CY + (RY - 2.5) * math.sin(a) * 0.95, 0.04))
        if LEFT_X + 1 < p.x < RIGHT_X - 1 and BACK_Y < p.y < 5:
            continue
        box(m["ChronoFloorGrate"], p, (1.6, 1.6, 0.08))
        for j in range(5):
            box(m["ChronoBrassDark"], p + Vector((-0.64 + 0.32 * j, 0, 0.05)), (0.06, 1.6, 0.05))
    home_plate(m["ChronoPlate"], 0.08)


# ---------- wall gears and the armillary ----------

def build_clockwork(m):
    for name, ((y, z), r, teeth, side) in GEARS.items():
        x = (LEFT_X - 2.4) if side < 0 else (RIGHT_X + 2.4)
        gear(m[name], (x, y, z), (1, 0, 0), r, teeth, 0.3, tooth=0.38, rim=0.42 if r > 1 else 0.3, spokes=6 if r > 1.2 else 4, hub=0.35)
        # Each gear on an iron axle bracket from the wall.
        wall_x = x + side * 0.9
        tube(m["ChronoIron"], (wall_x, y, z), (x - side * 0.25, y, z), 0.12, 8)
    # The armillary: three toothed rings turning about their own axes round a glowing core.
    for name, (r, n) in RINGS.items():
        gear(m[name], ARMILLARY, n, r, 2 * round(r * 6), 0.26, tooth=0.28, rim=0.3, spokes=0, hub=0)
        e1, e2 = axes_of(n)
        for k in range(12):
            a = 2 * math.pi * k / 12
            p = ARMILLARY + (e1 * math.cos(a) + e2 * math.sin(a)) * (r - 0.15)
            ball(m[name], p + n * 0.16, 0.08, subdivisions=1)
            ball(m[name], p - n * 0.16, 0.08, subdivisions=1)
    ball(m["ChronoCore"], ARMILLARY, 0.9, subdivisions=3)
    for k in range(3):
        torus(m["ChronoGlow"], ARMILLARY, (math.cos(k * 2.1), math.sin(k * 2.1), 0.5), 1.25, 0.04, segments=24, minor_segments=4)


# ---------- the time portal ----------

def build_portal(m):
    c = PORTAL
    ring, gear_bm, rim = m["ChronoPortalRing"], m["ChronoPortalGear"], m["ChronoPortalRim"]
    axis = Vector((0, 1, 0))
    # The ring is centred on the ball and large enough to rise over the screen; its lower part
    # sinks into the floor.
    annulus(ring, c, axis, PORTAL_R - 0.6, PORTAL_R, 0.5, segments=72)
    for y in (c.y - 0.26, c.y + 0.26):
        torus(ring, (c.x, y, c.z), axis, PORTAL_R, 0.1, segments=72, minor_segments=5)
    for k, text in enumerate(ROMAN):
        a = math.pi / 2 - 2 * math.pi * k / 12
        d = Vector((math.cos(a), 0, math.sin(a)))
        numeral(m["ChronoClockInk"], c + d * (PORTAL_R - 0.3) + Vector((0, -0.27, 0)), d, (0, -1, 0), text, 0.42, width=0.07, thickness=0.03)
    # The toothed ring behind the face, turning; the glowing rim; the swirling core (centred on the
    # ball, so the ball sits in the eye of the swirl).
    gear(gear_bm, (c.x, c.y + 0.45, c.z), axis, PORTAL_R - 0.2, 48, 0.24, tooth=0.32, rim=0.4, spokes=0, hub=0)
    torus(rim, (c.x, c.y - 0.1, c.z), axis, PORTAL_R - 0.62, 0.12, segments=72, minor_segments=6)
    swirl = m["ChronoPortalSwirl"]
    centre = Vector((PITCH.x, PITCH.y + 0.55, PITCH.z))
    for arm in range(6):
        for j in range(26):
            t0, t1 = j / 26, (j + 1) / 26
            pts = []
            for t, w in ((t0, 0.08 + 0.32 * t0), (t1, 0.08 + 0.32 * t1)):
                a = 2 * math.pi * arm / 6 + t * 3.4
                r = 0.25 + (PORTAL_R - 0.95) * t
                d = Vector((math.cos(a), 0, math.sin(a)))
                s = Vector((-math.sin(a), 0, math.cos(a)))
                pts.append((centre + d * r - s * w, centre + d * r + s * w))
            double_sided_poly(swirl, [pts[0][0], pts[1][0], pts[1][1], pts[0][1]])
    disc(m["ChronoPortalCore"], centre + Vector((0, 0.08, 0)), axis, 0.9, 0.06, segments=28)
    disc(m["ChronoDome"], centre + Vector((0, 0.2, 0)), axis, PORTAL_R - 0.62, 0.02, segments=60)
    pitch_ball(m["ChronoBall"])
    # The cradle: a stepped base and two brass columns clamping the ring, with gear knuckles.
    brass, dark = m["ChronoBrass"], m["ChronoBrassDark"]
    for k, (w, d, h) in enumerate(((2 * PORTAL_R + 2.4, 3.6, 0.3), (2 * PORTAL_R + 1.4, 3.0, 0.25))):
        box(dark if k == 0 else brass, (c.x, c.y + 0.3, 0.15 + 0.3 * k), (w, d, h))
    for sx in (-1, 1):
        col = Vector((c.x + sx * (PORTAL_R + 0.45), c.y + 0.3, 0))
        lathe(brass, [(0, 0.5), (0.5, 0.5), (0.36, 0.8), (0.3, 5.6), (0.46, 5.8), (0.42, 6.1), (0, 6.2)], 16, transform=Matrix.Translation(col))
        tube(brass, col + Vector((0, 0, c.z)), Vector((c.x + sx * PORTAL_R, c.y, c.z)), 0.16, 10)
        gear(dark, col + Vector((sx * 0.05, -0.36, c.z)), (0, 1, 0), 0.6, 12, 0.14, tooth=0.15, rim=0.15, spokes=4, hub=0.15)
        ball(m["ChronoGlow"], col + Vector((0, 0, 6.4)), 0.3, subdivisions=2)
        lathe(brass, [(0, 6.15), (0.34, 6.15), (0.38, 6.3), (0, 6.3)], 12, transform=Matrix.Translation(col))
    # A control console with levers, dials and buttons beside the portal.
    cx, cy = 10.4, 27.0
    box(m["ChronoConsole"], (cx, cy, 0.7), (1.8, 1.4, 1.4))
    slab(m["ChronoConsole"], [Vector((cx - 0.9, cy - 0.7, 1.4)), Vector((cx + 0.9, cy - 0.7, 1.4)), Vector((cx + 0.9, cy + 0.5, 1.95)),
                              Vector((cx - 0.9, cy + 0.5, 1.95))], 0.12)
    for k in range(3):
        p = Vector((cx - 0.55 + 0.55 * k, cy - 0.15, 1.73))
        disc(m["ChronoGauges"], p, (0, -0.45, 1), 0.2, 0.04, segments=16)
        torus(brass, p, (0, -0.45, 1), 0.2, 0.03, segments=16, minor_segments=4)
    for k in range(5):
        ball(m["ChronoButtons"], (cx - 0.6 + 0.3 * k, cy - 0.5, 1.55), 0.06, subdivisions=1)
    for k, ang in enumerate((-0.5, 0.0, 0.6)):
        base = Vector((cx - 0.4 + 0.4 * k, cy + 0.35, 1.95))
        tip = base + Vector((0, math.sin(ang) * 0.6, math.cos(ang) * 0.7))
        tube(m["ChronoIron"], base, tip, 0.04, 6)
        ball(m["ChronoButtons"], tip, 0.1, subdivisions=1)


# ---------- the brass screen ----------

def build_screen(m):
    y = SCREEN_Y
    x0, x1, z0, z1 = PITCH.x - 3.4, PITCH.x + 3.4, 0.25, 5.7
    corner = 0.9
    outline = [(x0, z0), (x1, z0), (x1, z1 - corner)] + [(x1 - corner + corner * math.cos(a), z1 - corner + corner * math.sin(a))
                                                          for a in [math.pi / 2 * k / 6 for k in range(1, 6)]] + \
              [(x1 - corner, z1), (x0 + corner, z1)] + [(x0 + corner + corner * math.cos(a), z1 - corner + corner * math.sin(a))
                                                       for a in [math.pi / 2 + math.pi / 2 * k / 6 for k in range(1, 6)]] + [(x0, z1 - corner)]
    window_panel(m["ChronoScreen"], outline, y, 0.18, segments=72)
    brass, rivets = m["ChronoBrass"], m["ChronoRivets"]
    front = y - 0.1
    # A porthole flange round the window, bolted.
    torus(brass, (PITCH.x, front, PITCH.z), (0, 1, 0), WINDOW + 0.2, 0.13, segments=40, minor_segments=6)
    for k in range(12):
        a = 2 * math.pi * k / 12
        ball(rivets, (PITCH.x + math.cos(a) * (WINDOW + 0.42), front - 0.04, PITCH.z + math.sin(a) * (WINDOW + 0.42)), 0.08, subdivisions=1)
    # Rivet rows round the edge and along two seams.
    edge = Polyline([Vector((x, front, z)) for x, z in outline + outline[:1]])
    for p in edge.samples(0.42):
        inward = Vector((PITCH.x - p.x, 0, 3.3 - p.z)).normalized() * 0.22
        ball(rivets, p + inward - Vector((0, 0.02, 0)), 0.06, subdivisions=1)
    for z in (1.0, 4.95):
        box(m["ChronoBrassDark"], (PITCH.x, front - 0.01, z), (x1 - x0 - 0.3, 0.04, 0.12))
    # Two pressure gauges with needles, a nameplate, and valve wheels on pipes along the top.
    for sx in (-1, 1):
        g = Vector((PITCH.x + sx * 2.3, front - 0.08, 4.3))
        disc(m["ChronoGauges"], g, (0, 1, 0), 0.5, 0.06, segments=24)
        torus(brass, g, (0, 1, 0), 0.52, 0.07, segments=24, minor_segments=5)
        for k in range(9):
            a = math.radians(225 - 270 * k / 8)
            box(m["ChronoClockInk"], g + Vector((math.cos(a) * 0.4, -0.04, math.sin(a) * 0.4)), (0.03, 0.02, 0.1), Matrix.Rotation(-a + math.pi / 2, 4, "Y"))
        a = math.radians(160 if sx < 0 else 40)
        box(m["ChronoButtons"], g + Vector((math.cos(a) * 0.18, -0.06, math.sin(a) * 0.18)), (0.36, 0.02, 0.04), Matrix.Rotation(-a, 4, "Y"))
    box(m["ChronoGauges"], (PITCH.x, front - 0.05, 1.55), (1.8, 0.04, 0.5))
    box(brass, (PITCH.x, front - 0.06, 1.55), (1.95, 0.03, 0.62))
    for k in range(5):
        box(m["ChronoClockInk"], (PITCH.x - 0.6 + 0.3 * k, front - 0.08, 1.55), (0.14, 0.02, 0.26))
    sweep(m["ChronoCopper"], [Vector((x0 - 0.3, y + 0.2, z1 + 0.25)), Vector((x1 + 0.3, y + 0.2, z1 + 0.25))], 0.16, segments=10)
    for sx in (-1, 1):
        sweep(m["ChronoCopper"], [Vector((PITCH.x + sx * 3.7, y + 0.2, z1 + 0.25)), Vector((PITCH.x + sx * 3.7, y + 0.2, 0.0))], 0.16, segments=10)
        w = Vector((PITCH.x + sx * 1.7, y + 0.2, z1 + 0.65))
        tube(m["ChronoCopper"], w - Vector((0, 0, 0.4)), w, 0.06, 6)
        torus(m["ChronoIron"], w + Vector((0, 0, 0.05)), (0, 0, 1), 0.35, 0.05, segments=16, minor_segments=4)
        for k in range(4):
            a = math.pi / 2 * k
            tube(m["ChronoIron"], w + Vector((0, 0, 0.05)), w + Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 0.05)), 0.03, 4)
    for sx in (-1, 1):
        tube(brass, (PITCH.x + sx * 3.0, y + 0.1, 3.4), (PITCH.x + sx * 3.2, y + 2.0, 0.0), 0.12, 8)


# ---------- tesla coils, pipes ----------

def tesla(m, x, y):
    base = Vector((x, y, 0))
    lathe(m["ChronoBrassDark"], [(0, 0), (1.0, 0), (1.0, 0.5), (0.8, 0.7), (0.5, 0.75), (0, 0.75)], 20, transform=Matrix.Translation(base))
    lathe(m["ChronoBrass"], [(0, 0.75), (0.32, 0.75), (0.26, 7.4), (0, 7.4)], 14, transform=Matrix.Translation(base))
    for k in range(26):
        torus(m["ChronoCoils"], base + Vector((0, 0, 1.4 + k * 0.17)), (0, 0, 1), 0.48, 0.07, segments=14, minor_segments=4)
    for z, r in ((1.2, 0.7), (6.0, 0.6)):
        disc(m["ChronoBrass"], base + Vector((0, 0, z)), (0, 0, 1), r, 0.12, segments=18)
    torus(m["ChronoBrass"], base + Vector((0, 0, 7.8)), (0, 0, 1), 1.0, 0.42, segments=28, minor_segments=10)
    ball(m["ChronoGlow"], base + Vector((0, 0, 8.4)), 0.24, subdivisions=2)
    # Lightning arcs leaping off the toroid.
    arcs = m["ChronoArcs"]
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-0.3, 0.3)
        p = base + Vector((math.cos(a) * 1.4, math.sin(a) * 1.4, 7.8))
        pts = [p]
        for j in range(5):
            pts.append(pts[-1] + Vector((math.cos(a) * 0.35 + rng.uniform(-0.2, 0.2), math.sin(a) * 0.35 + rng.uniform(-0.2, 0.2), rng.uniform(-0.35, 0.45))))
        for q0, q1 in zip(pts, pts[1:]):
            d = (q1 - q0).normalized()
            s = d.cross(Vector((0, 0, 1))).normalized() * 0.05
            double_sided_strip(arcs, [q0 - s, q1 - s], [q0 + s, q1 + s])


def build_lab(m):
    tesla(m, -13.6, 29.4)
    tesla(m, 11.6, 29.4)
    copper = m["ChronoCopper"]
    for sx, tx in ((-1, -13.6), (1, 11.6)):
        start = Vector((PORTAL.x + sx * (PORTAL_R + 1.0), PORTAL.y + 0.3, 0.25))
        sweep(copper, [start, Vector((start.x, PORTAL.y + 2.4, 0.25)), Vector((tx, PORTAL.y + 2.4, 0.25)), Vector((tx, 29.4, 0.6))], 0.18, segments=10)
        for t in (0.3, 0.6):
            p = Vector((start.x + (tx - start.x) * t, PORTAL.y + 2.4, 0.25))
            torus(m["ChronoBrass"], p, (1, 0, 0), 0.22, 0.05, segments=12, minor_segments=4)
    # Pipes up the front wall to a pressure tank with a dial.
    tank = Vector((-6.0, 33.0, 0))
    lathe(m["ChronoCopper"], [(0, 0), (0.9, 0), (1.0, 0.3), (1.0, 3.6), (0.7, 4.1), (0, 4.2)], 20, transform=Matrix.Translation(tank))
    for z in (0.6, 2.0, 3.4):
        torus(m["ChronoBrass"], tank + Vector((0, 0, z)), (0, 0, 1), 1.02, 0.06, segments=20, minor_segments=4)
    disc(m["ChronoGauges"], tank + Vector((0, -1.02, 2.6)), (0, 1, 0), 0.4, 0.05, segments=18)
    sweep(copper, [tank + Vector((0, 0, 4.1)), tank + Vector((0, 0, 6.2)), tank + Vector((4.2, 0, 6.2)), Vector((PORTAL.x - 1.0, PORTAL.y + 1.6, 6.2)),
                   Vector((PORTAL.x - 1.0, PORTAL.y + 0.6, 4.8))], 0.14, segments=10)


# ---------- the drifting relics ----------

def build_relics(m):
    f = FLOATERS
    # A caveman's club.
    c = f["ChronoFloatClub"]
    lathe(m["ChronoFloatClub"], [(0, -1.1), (0.12, -1.1), (0.16, -0.3), (0.3, 0.3), (0.42, 0.8), (0.36, 1.1), (0, 1.2)], 10,
          transform=Matrix.Translation(c) @ Matrix.Rotation(0.6, 4, "Y"))
    # A pharaoh's mask: a face with a striped headdress.
    c = f["ChronoFloatMask"]
    blob(m["ChronoFloatMask"], c, Vector((0.55, 0.35, 0.7)), subdivisions=2, seed=1)
    for s in (-1, 1):
        box(m["ChronoFloatMask"], c + Vector((s * 0.6, 0.0, -0.4)), (0.3, 0.3, 1.1))
    box(m["ChronoFloatMask"], c + Vector((0, -0.25, -0.85)), (0.18, 0.18, 0.4))
    # A Roman helmet with a crest.
    c = f["ChronoFloatHelmet"]
    lathe(m["ChronoFloatHelmet"], [(0, 0.55), (0.42, 0.45), (0.55, 0.0), (0.58, -0.25), (0.7, -0.3), (0.0, -0.3)], 16, transform=Matrix.Translation(c))
    for k in range(7):
        box(m["ChronoFloatHelmet"], c + Vector((0, -0.45 + 0.15 * k, 0.75 + 0.1 * math.sin(math.pi * k / 6))), (0.08, 0.14, 0.4))
    # A samurai helmet with its crescent crest.
    c = f["ChronoFloatKabuto"]
    lathe(m["ChronoFloatKabuto"], [(0, 0.5), (0.45, 0.42), (0.58, 0.05), (0.85, -0.2), (0.8, -0.3), (0, -0.25)], 16, transform=Matrix.Translation(c))
    for s in (-1, 1):
        sweep_radii(m["ChronoFloatKabuto"], [c + Vector((0, -0.5, 0.3)), c + Vector((s * 0.4, -0.55, 0.75)), c + Vector((s * 0.6, -0.5, 1.2))], [0.06, 0.05, 0.02], segments=5)
    # A dinosaur skull.
    c = f["ChronoFloatSkull"]
    blob(m["ChronoFloatSkull"], c, Vector((0.5, 0.9, 0.5)), subdivisions=2, seed=3)
    blob(m["ChronoFloatSkull"], c + Vector((0, -0.75, -0.25)), Vector((0.35, 0.6, 0.25)), subdivisions=2, seed=4)
    for k in range(6):
        lathe(m["ChronoFloatSkull"], [(0, 0), (0.06, 0), (0, -0.25)], 5, transform=Matrix.Translation(c + Vector((0.2 * (1 if k % 2 else -1), -0.5 - 0.2 * (k // 2), -0.45))))
    # A little rocket from the future.
    c = f["ChronoFloatRocket"]
    lathe(m["ChronoFloatRocket"], [(0, -1.0), (0.3, -0.9), (0.36, -0.2), (0.3, 0.5), (0.12, 0.95), (0, 1.05)], 14,
          transform=Matrix.Translation(c) @ Matrix.Rotation(0.4, 4, "X"))
    for k in range(4):
        a = math.pi / 2 * k
        d = Vector((math.cos(a), math.sin(a), 0))
        slab(m["ChronoFloatRocket"], [c + d * 0.3 + Vector((0, 0, -0.95)), c + d * 0.7 + Vector((0, 0, -1.1)), c + d * 0.32 + Vector((0, 0, -0.4))], 0.05,
             Vector((0, 0, 1)).cross(d))
    # Pocket watches, faces both sides, with a crown and bow on top.
    for name in ("ChronoFloatWatchA", "ChronoFloatWatchB", "ChronoFloatWatchC"):
        c = f[name]
        r = 0.9 if name.endswith("C") else 0.65
        disc(m[name], c, (0, 1, 0), r, 0.22, segments=28)
        lathe(m[name], [(0, 0), (0.1, 0), (0.1, 0.25), (0.16, 0.25), (0.16, 0.4), (0, 0.42)], 10, transform=Matrix.Translation(c + Vector((0, 0, r))))
        torus(m[name], c + Vector((0, 0, r + 0.55)), (0, 1, 0), 0.18, 0.04, segments=12, minor_segments=4)
        for sy in (-1, 1):
            disc(m["ChronoFloatWatchFaces"], c + Vector((0, sy * 0.12, 0)), (0, 1, 0), r * 0.86, 0.02, segments=24)
            for k in range(12):
                a = 2 * math.pi * k / 12
                box(m["ChronoFloatWatchTicks"], c + Vector((math.cos(a) * r * 0.72, sy * 0.135, math.sin(a) * r * 0.72)), (0.04, 0.02, 0.1),
                    Matrix.Rotation(-a + math.pi / 2, 4, "Y"))
    # An hourglass drifting over the door end (frame and sand bob together).
    c = Vector((CX + 6.0, -8.0, 12.6))
    for z in (-1.0, 1.0):
        disc(m["ChronoFloatHourglass"], c + Vector((0, 0, z)), (0, 0, 1), 0.65, 0.14, segments=18)
    for k in range(3):
        a = 2 * math.pi * k / 3
        tube(m["ChronoFloatHourglass"], c + Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, -1.0)), c + Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, 1.0)), 0.05, 6)
    lathe(m["ChronoFloatHourglassGlass"], [(0, -0.93), (0.45, -0.85), (0.4, -0.35), (0.06, 0.0), (0.4, 0.35), (0.45, 0.85), (0, 0.93)], 16, transform=Matrix.Translation(c))
    lathe(m["ChronoFloatSand"], [(0, -0.9), (0.4, -0.82), (0.25, -0.45), (0, -0.4)], 12, transform=Matrix.Translation(c))
    lathe(m["ChronoFloatSand"], [(0, 0.1), (0.2, 0.45), (0.35, 0.7), (0, 0.72)], 12, transform=Matrix.Translation(c))


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = meshes(LOOKS)
    build_walls(m)
    build_door(m)
    build_dome(m)
    build_floor(m)
    build_clockwork(m)
    build_portal(m)
    build_screen(m)
    build_lab(m)
    build_relics(m)
    for name in ("ChronoPortalSwirl", "ChronoArcs"):
        bmesh.ops.triangulate(m[name], faces=m[name].faces[:])
    objects = build_looks(coll, m, LOOKS)
    spins = {name: (((LEFT_X - 2.4) if side < 0 else (RIGHT_X + 2.4), y, z), (1, 0, 0)) for name, ((y, z), r, t, side) in GEARS.items()}
    spins.update({name: (ARMILLARY, n) for name, (r, n) in RINGS.items()})
    spins.update({"ChronoHandMinute": (CLOCK, (0, 0, 1)), "ChronoHandHour": (CLOCK, (0, 0, 1)),
                  "ChronoPortalGear": (PORTAL, (0, 1, 0)), "ChronoPortalSwirl": (PITCH, (0, 1, 0)), "ChronoPortalCore": (PITCH, (0, 1, 0)),
                  "ChronoCrownGear": ((CX, CY, 0), (0, 0, 1))})
    check_centred(objects, spins)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
