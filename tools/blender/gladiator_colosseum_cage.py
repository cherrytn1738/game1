# Training Ground 3 of World 2, Gladiator Colosseum: the batting cage is a small amphitheatre. A
# curved two-tier stone arcade (Tuscan half-columns below, Ionic above, bronze grilles in the lower
# arches, spectators leaning over the upper balustrades) runs round a sand arena, with a gate arch at
# the door. A striped velarium of canvas sails roofs it, stretched from masts on the attic to a ring
# over the middle. Banners and shields hang on the walls. A bronze ballista holds the ball at PITCH
# behind a great round bronze shield screen with a laurel wreath. Inside are braziers, weapon racks,
# a training post and amphorae. Outside are crowd stands with an emperor's box behind the machine
# end, a chariot, and two bronze lions guarding the gate. The crowd bobs in a wave.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "GladiatorColosseumCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\GladiatorColosseumCage.fbx"

TRAVERTINE = (0.86, 0.82, 0.72)
STONE_DARK = (0.66, 0.62, 0.55)
MARBLE = (0.95, 0.94, 0.9)
BRONZE = (0.72, 0.46, 0.22)
GOLD = (1.0, 0.77, 0.25)
IRON = (0.3, 0.3, 0.32)
WOOD = (0.5, 0.33, 0.18)
ROPE = (0.7, 0.58, 0.38)
CRIMSON = (0.66, 0.08, 0.1)
CANVAS = (0.95, 0.9, 0.78)
SAND = (0.88, 0.78, 0.58)
SKIN = (0.88, 0.66, 0.5)
FLAME = (1.0, 0.58, 0.14)
rng = random.Random(77)

CX, CY = (LEFT_X + RIGHT_X) / 2, 10.0
RX, RY, POWER = 19.5, 28.5, 4.0             # the arena's outer wall: a rounded oval round the cage
THICK = 1.5                                 # wall thickness (inward from the outer face)
LOW_TOP, UP_BASE, UP_TOP, ATTIC = 6.6, 7.4, 12.0, 13.5
LOW_SPRING, UP_SPRING = 3.6, 9.0
RING_Z, RING_SCALE, MAST_TOP = 16.4, 0.42, 17.6
GATE = Vector(((DOOR[0] + DOOR[1]) / 2, BACK_Y - 3.0, 0))
TUNICS = ((0.8, 0.16, 0.14), (0.95, 0.94, 0.9), (0.2, 0.36, 0.72), (0.86, 0.62, 0.22))

LOOKS = {
    "ArenaStone": (TRAVERTINE, "hard"), "ArenaStoneDark": (STONE_DARK, "hard"), "ArenaColumns": (MARBLE, "smooth"), "ArenaColumnsUpper": (MARBLE, "smooth"),
    "ArenaGrilles": (BRONZE, "hard"), "ArenaBronze": (BRONZE, "smooth"), "ArenaIron": (IRON, "smooth"),
    "ArenaWood": (WOOD, "hard"), "ArenaRope": (ROPE, "smooth"), "ArenaRigging": (ROPE, "smooth"),
    "ArenaCanvasRed": (CRIMSON, "soft"), "ArenaCanvasCream": (CANVAS, "soft"), "ArenaRing": (WOOD, "smooth"),
    "ArenaSand": (SAND, "soft"), "ArenaSandRidges": ((0.8, 0.7, 0.5), "smooth"),
    "ArenaBanners": (CRIMSON, "soft"), "ArenaBannerGold": (GOLD, "hard"),
    "ArenaShields": (CRIMSON, "smooth"), "ArenaShieldBosses": (GOLD, "smooth"),
    "ArenaShield": (BRONZE, "hard"), "ArenaShieldGold": (GOLD, "smooth"),
    "ArenaLions": (BRONZE, "smooth"), "ArenaPlinths": (MARBLE, "hard"),
    "ArenaChariot": (CRIMSON, "smooth"), "ArenaChariotGold": (GOLD, "smooth"),
    "ArenaSeats": (TRAVERTINE, "hard"), "ArenaAwning": (CRIMSON, "soft"), "ArenaEmperor": ((0.42, 0.12, 0.5), "smooth"), "ArenaEmperorHead": (SKIN, "smooth"),
    "ArenaLaurel": ((0.4, 0.62, 0.22), "smooth"),
    "ArenaWeapons": ((0.75, 0.76, 0.78), "hard"), "ArenaStraw": ((0.85, 0.72, 0.4), "smooth"),
    "ArenaAmphorae": ((0.72, 0.4, 0.24), "smooth"), "ArenaFlames": (FLAME, "smooth"),
    "ArenaPlate": (MARBLE, "hard"), "ArenaBall": (WHITE, "smooth"),
}
for k in range(4):
    LOOKS["ArenaCrowd" + "ABCD"[k]] = (TUNICS[k], "smooth")
    LOOKS["ArenaCrowdHeads" + "ABCD"[k]] = (SKIN, "smooth")


# ---------- the arena's plan ----------

def outer_curve(count=480):
    """The wall's outer face, counter-clockwise from the back, as a closed polyline."""
    points = squircle_points(CX, CY, RX, RY, -math.pi / 2, 3 * math.pi / 2, count + 1, p=POWER)
    return Polyline(points)


OUTER = outer_curve()


def frame_at(s):
    """Point on the outer face, unit tangent and inward normal at arc length s."""
    s %= OUTER.length
    p = OUTER.at(s)
    t = OUTER.at(min(OUTER.length, s + 0.05)) - OUTER.at(max(0.0, s - 0.05))
    t.normalize()
    return p, t, Vector((-t.y, t.x, 0))


def gate_s():
    best, best_d = 0.0, 1e9
    for i in range(600):
        s = OUTER.length * i / 600
        d = (OUTER.at(s) - GATE).length
        if d < best_d:
            best, best_d = s, d
    return best


BAYS = 2 * round(OUTER.length / 5.2 / 2)
BAY = OUTER.length / BAYS
S_GATE = gate_s()


def bay_bounds(i):
    s0 = S_GATE - BAY / 2 + i * BAY
    return s0, s0 + BAY


def inside_arena(x, y, inset=0.0):
    return (abs(x - CX) / (RX - inset)) ** POWER + (abs(y - CY) / (RY - inset)) ** POWER < 1.0


# ---------- small builders ----------

def flame(bm, base, height, radius):
    lathe(bm, [(0, 0), (radius * 0.8, height * 0.12), (radius, height * 0.3), (radius * 0.7, height * 0.6),
               (radius * 0.3, height * 0.85), (0, height)], 10, transform=Matrix.Translation(Vector(base)))


def arch_panel(bm, a, b, inward, thickness, z_spring, z_top, samples=12):
    """A wall panel between a and b (the outer face points) with a round-headed arch opening
    below; it fills from the arch curve up to z_top, through the wall's thickness."""
    a, b = Vector(a), Vector(b)
    width = (b - a).length
    r = width / 2
    t = (b - a).normalized()
    curve, top = [], []
    for k in range(samples + 1):
        u = width * k / samples
        z = z_spring + math.sqrt(max(0.0, r * r - (u - r) ** 2))
        p = a + t * u
        curve.append(Vector((p.x, p.y, z)))
        top.append(Vector((p.x, p.y, z_top)))
    shift = Vector(inward) * thickness
    loft(bm, [curve, top])
    loft(bm, [[p + shift for p in top], [p + shift for p in curve]])
    loft(bm, [[p + shift for p in curve], curve])
    loft(bm, [top, [p + shift for p in top]])


def leaf_pair(bm, centre, direction, normal, size):
    d, n = Vector(direction).normalized(), Vector(normal).normalized()
    side = n.cross(d)
    for s in (-1, 1):
        base = Vector(centre)
        tip = base + d * size * 0.5 + side * s * size * 0.55
        slab(bm, [base, base + d * size * 0.25 + side * s * size * 0.22, tip, base + d * size * 0.45], 0.04, n)


def person(m, group, base, facing, scale=1.0, arms_up=False):
    """A spectator: a tunic body, a head and (sometimes) cheering arms."""
    b, f = Vector(base), Vector(facing).normalized()
    body, heads = m["ArenaCrowd" + "ABCD"[group]], m["ArenaCrowdHeads" + "ABCD"[group]]
    lathe(body, [(0, 0), (0.32 * scale, 0), (0.36 * scale, 0.6 * scale), (0.3 * scale, 1.1 * scale), (0.16 * scale, 1.25 * scale), (0, 1.26 * scale)], 8,
          transform=Matrix.Translation(b))
    ball(heads, b + Vector((0, 0, 1.5 * scale)), 0.25 * scale, subdivisions=1)
    side = f.cross(Vector((0, 0, 1))).normalized()
    for s in (-1, 1):
        shoulder = b + side * s * 0.3 * scale + Vector((0, 0, 1.05 * scale))
        hand = shoulder + (Vector((0, 0, 0.75)) + side * s * 0.25 + f * 0.1) * scale if arms_up else shoulder + (Vector((0, 0, -0.55)) + f * 0.2) * scale
        tube(body, shoulder, hand, 0.08 * scale, 5)


# ---------- the arcade ----------

def pier(m, s, z0, z1, ionic=False, columns="ArenaColumns"):
    p, t, n = frame_at(s)
    centre = p + n * (THICK / 2)
    turn = Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z")
    box(m["ArenaStone"], (centre.x, centre.y, (z0 + z1) / 2), (1.1, THICK + 0.2, z1 - z0), turn)
    for face in (-1, 1):
        c = centre + n * face * (THICK / 2 + 0.1)
        profile = [(0, z0), (0.44, z0), (0.44, z0 + 0.2), (0.34, z0 + 0.3), (0.3, z1 - 0.45), (0.42, z1 - 0.32), (0.46, z1 - 0.12), (0.46, z1), (0, z1)]
        lathe(m[columns], profile, 10, transform=Matrix.Translation((c.x, c.y, 0)))
        if ionic:
            for side in (-1, 1):
                q = c + t * side * 0.36
                torus(m[columns], (q.x, q.y, z1 - 0.22), n, 0.13, 0.05, segments=8, minor_segments=3)


def build_arcade(m):
    for i in range(BAYS):
        s0, s1 = bay_bounds(i)
        a, _, n0 = frame_at(s0)
        b, _, n1 = frame_at(s1)
        t = (b - a).normalized()
        n = Vector((-t.y, t.x, 0))
        pa, pb = a + t * 0.55, b - t * 0.55
        mid = (a + b) / 2
        is_gate = i == 0
        pier(m, s0, 0.4, LOW_TOP)
        pier(m, s0, UP_BASE, UP_TOP, ionic=True, columns="ArenaColumnsUpper")
        arch_panel(m["ArenaStone"], pa, pb, n, THICK, 4.4 if is_gate else LOW_SPRING, LOW_TOP)
        arch_panel(m["ArenaStone"], pa, pb, n, THICK, UP_SPRING, UP_TOP)
        width = (pb - pa).length
        # Keystones over both arches.
        for spring, top in ((4.4 if is_gate else LOW_SPRING, LOW_TOP), (UP_SPRING, UP_TOP)):
            crown = mid + n * (-0.05)
            box(m["ArenaStoneDark"], (crown.x, crown.y, spring + width / 2 + 0.15), (0.42, 0.2, 0.5), Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z"))
            crown = mid + n * (THICK + 0.05)
            box(m["ArenaStoneDark"], (crown.x, crown.y, spring + width / 2 + 0.15), (0.42, 0.2, 0.5), Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z"))
        # Bronze grilles in the lower arches (the gate stays open), balustrades in the upper ones.
        if not is_gate:
            g = m["ArenaGrilles"]
            count = 9
            for k in range(1, count):
                u = width * k / count
                p = pa + t * u + n * (THICK * 0.55)
                z = LOW_SPRING + math.sqrt(max(0.0, (width / 2) ** 2 - (u - width / 2) ** 2)) - 0.05
                box(g, (p.x, p.y, (0.4 + z) / 2), (0.07, 0.07, z - 0.4))
            for z in (1.4, 2.8):
                c = pa.lerp(pb, 0.5) + n * (THICK * 0.55)
                box(g, (c.x, c.y, z), (width, 0.08, 0.08), Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z"))
        c = pa.lerp(pb, 0.5) + n * (THICK * 0.5)
        box(m["ArenaStoneDark"], (c.x, c.y, UP_BASE + 0.45), (width, 0.4, 0.9), Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z"))
        # Spectators lean over the upper balustrades in the bays round the machine end and sides.
        if mid.y > 0.0 and i % 2 == 0:
            for k, u in enumerate((0.3, 0.7)):
                q = pa.lerp(pb, u) + n * (THICK * 0.25)
                person(m, (i + k) % 4, (q.x, q.y, UP_BASE), n, scale=0.85, arms_up=(i + k) % 3 == 0)
    # Plinth, entablature and attic, swept round the wall's centre line.
    centre = [OUTER.at(OUTER.length * k / 240) + frame_at(OUTER.length * k / 240)[2] * (THICK / 2) for k in range(240)]
    profile_along(m["ArenaStoneDark"], centre, [(-1.0, 0.0), (1.0, 0.0), (1.0, 0.4), (-1.0, 0.4)], closed=True)
    profile_along(m["ArenaStone"], centre, [(-0.95, LOW_TOP), (0.95, LOW_TOP), (1.05, LOW_TOP + 0.3), (1.05, UP_BASE), (-1.05, UP_BASE),
                                            (-1.05, LOW_TOP + 0.3)], closed=True)
    profile_along(m["ArenaStone"], centre, [(-0.85, UP_TOP), (0.85, UP_TOP), (0.85, ATTIC - 0.5), (1.1, ATTIC - 0.3), (1.1, ATTIC),
                                            (-1.1, ATTIC), (-1.1, ATTIC - 0.3), (-0.85, ATTIC - 0.5)], closed=True)
    profile_along(m["ArenaStoneDark"], centre, [(-1.12, UP_TOP - 0.05), (1.12, UP_TOP - 0.05), (1.12, UP_TOP + 0.15), (-1.12, UP_TOP + 0.15)], closed=True)


# ---------- the velarium ----------

def build_velarium(m):
    ring = [Vector((CX + (p.x - CX) * RING_SCALE, CY + (p.y - CY) * RING_SCALE, RING_Z)) for p in OUTER.samples(OUTER.length / 160)[:-1]]
    sweep(m["ArenaRing"], ring + [ring[0]], 0.28, segments=10)
    inner = Polyline(ring + [ring[0]])
    for i in range(BAYS):
        s0, s1 = bay_bounds(i)
        o0 = frame_at(s0)[0] + frame_at(s0)[2] * (THICK / 2) + Vector((0, 0, ATTIC))
        o1 = frame_at(s1)[0] + frame_at(s1)[2] * (THICK / 2) + Vector((0, 0, ATTIC))
        # The inner ring is sampled from the same start as OUTER, so map by the same fraction.
        i0 = inner.at(inner.length * (s0 % OUTER.length) / OUTER.length)
        i1 = inner.at(inner.length * (s1 % OUTER.length) / OUTER.length)

        def sail(a, b, o0=o0, o1=o1, i0=i0, i1=i1):
            p = o0.lerp(o1, a).lerp(i0.lerp(i1, a), b)
            return p - Vector((0, 0, 0.55 * math.sin(math.pi * b) * (0.6 + 0.4 * math.sin(math.pi * a))))
        grid_surface(m["ArenaCanvasRed" if i % 2 else "ArenaCanvasCream"], sail, 4, 8)
        # A mast on every other pier, roped to the ring.
        if i % 2 == 0:
            mast = frame_at(s0)[0] + frame_at(s0)[2] * 0.3
            cylinder(m["ArenaWood"], (mast.x, mast.y, ATTIC - 0.2), (0, 0, 1), MAST_TOP - ATTIC + 0.2, 0.14, segments=8)
            ball(m["ArenaBronze"], (mast.x, mast.y, MAST_TOP + 0.1), 0.2, subdivisions=1)
            top = Vector((mast.x, mast.y, MAST_TOP))
            sweep(m["ArenaRigging"], wavy(top, i0, 8, 0.0, sag=0.5), 0.045, segments=4)
        sweep(m["ArenaRigging"], wavy(o0 + Vector((0, 0, 0.05)), i0, 8, 0.0, sag=0.55), 0.04, segments=4)


# ---------- floor ----------

def build_floor(m):
    x0, x1, y0, y1 = CX - RX, CX + RX, CY - RY, CY + RY

    def sand(u, v):
        return Vector((x0 + (x1 - x0) * u, y0 + (y1 - y0) * v, 0.03))

    def keep(u, v):
        x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * v
        in_rect = LEFT_X - 0.4 < x < RIGHT_X + 0.4 and BACK_Y - 0.4 < y < FRONT_Y + 0.4
        return inside_arena(x, y, inset=THICK - 0.3) and not in_rect
    grid_surface(m["ArenaSand"], sand, 72, 108, keep=keep)
    # Raked arcs in the sand round the batter's ground.
    for r in (7.2, 8.2, 9.2):
        for a0, a1 in ((math.radians(200), math.radians(268)), (math.radians(272), math.radians(340))):
            arc = [Vector((PITCH.x + r * math.cos(a0 + (a1 - a0) * k / 18), r * 0.7 * math.sin(a0 + (a1 - a0) * k / 18), 0.02)) for k in range(19)]
            sweep(m["ArenaSandRidges"], arc, 0.06, segments=5)
    home_plate(m["ArenaPlate"], 0.08)


# ---------- the ballista and the shield screen ----------

def build_ballista(m):
    wood, iron, bronze, rope = m["ArenaWood"], m["ArenaIron"], m["ArenaBronze"], m["ArenaRope"]
    x = PITCH.x
    for bx in (x - 1.4, x + 1.4):
        box(wood, (bx, 28.3, 0.22), (0.42, 7.6, 0.44))
    for y in (25.0, 28.4, 31.6):
        box(wood, (x, y, 0.22), (3.4, 0.42, 0.44))
    # The trestle and pivot under the stock.
    for sx in (-1, 1):
        for sy in (-1, 1):
            tube(wood, (x + sx * 1.3, 28.3 + sy * 1.1, 0.45), (x + sx * 0.25, 28.3, 2.15), 0.13, 8)
    box(iron, (x, 28.3, 2.15), (0.7, 0.7, 0.3))
    # The stock: a long beam with a trough, reaching under the ball.
    box(wood, (x, 27.7, 2.42), (0.62, 8.2, 0.36))
    for sx in (-1, 1):
        box(bronze, (x + sx * 0.25, 27.7, 2.66), (0.1, 8.2, 0.14))
    box(bronze, (x, 23.75, 2.42), (0.7, 0.3, 0.42))
    # The torsion frame: two rope skeins in an iron-bound frame, arms sweeping back to the string.
    frame_y = 25.8
    for z in (1.5, 4.5):
        box(wood, (x, frame_y, z), (3.5, 0.6, 0.34))
    for sx in (-1, 1):
        box(wood, (x + sx * 1.6, frame_y, 3.0), (0.36, 0.6, 3.34))
        box(wood, (x + sx * 0.5, frame_y, 3.0), (0.3, 0.6, 3.34))
        skein = Vector((x + sx * 1.05, frame_y, 0))
        cylinder(rope, skein + Vector((0, 0, 1.68)), (0, 0, 1), 2.64, 0.3, segments=12)
        for z in (1.62, 4.38):
            disc(iron, skein + Vector((0, 0, z + (0.08 if z > 3 else -0.08))), (0, 0, 1), 0.42, 0.1, segments=14)
            box(iron, skein + Vector((0, 0.35, z + (0.12 if z > 3 else -0.12))), (0.1, 0.7, 0.08))
        arm = [skein + Vector((0, 0, 3.0)), Vector((x + sx * 2.2, frame_y + 0.7, 3.05)), Vector((x + sx * 3.25, frame_y + 2.0, 3.1))]
        sweep_radii(wood, arm, [0.2, 0.16, 0.11], segments=8)
        lathe(iron, [(0, 0), (0.14, 0), (0.12, 0.3), (0, 0.38)], 8, transform=Matrix.Translation(arm[-1]) @ align_z(arm[-1] - arm[-2]))
        sweep(rope, [arm[-1], Vector((x + sx * 0.25, 30.1, 2.8))], 0.035, segments=4)
    # The slider with its claw, a windlass at the back, and bronze plates with a laurel.
    box(bronze, (x, 30.1, 2.78), (0.8, 1.0, 0.24))
    lathe(iron, [(0, 0), (0.16, 0), (0.1, 0.3), (0, 0.32)], 6, transform=Matrix.Translation((x, 29.55, 2.9)) @ align_z(Vector((0, -1, 0.3))))
    cylinder_x(wood, (x, 31.6, 2.0), 2.6, 0.24, 12)
    for sx in (-1, 1):
        for k in range(4):
            a = math.pi / 2 * k + math.pi / 4
            tube(iron, (x + sx * 1.35, 31.6, 2.0), (x + sx * 1.35, 31.6 + math.cos(a) * 0.7, 2.0 + math.sin(a) * 0.7), 0.05, 5)
        box(wood, (x + sx * 1.35, 31.6, 1.05), (0.3, 0.5, 1.9))
    slab(bronze, [Vector((x - 1.4, frame_y - 0.32, 1.8)), Vector((x + 1.4, frame_y - 0.32, 1.8)), Vector((x + 1.4, frame_y - 0.32, 2.5)),
                  Vector((x - 1.4, frame_y - 0.32, 2.5))], 0.06, Vector((0, -1, 0)))
    for k in range(7):
        a = math.radians(200 + 140 * k / 6)
        leaf_pair(m["ArenaLaurel"], Vector((x + math.cos(a) * 1.0, frame_y - 0.38, 4.0 + math.sin(a) * 0.3)), (math.cos(a + 1.6), 0, math.sin(a + 1.6) * 0.3),
                  (0, -1, 0), 0.4)
    pitch_ball(m["ArenaBall"])


def build_screen(m):
    y = SCREEN_Y
    centre = (PITCH.x, 3.3)
    radius = 3.25
    window_panel(m["ArenaShield"], lambda a: ray_ellipse((PITCH.x, PITCH.z), (math.cos(a), math.sin(a)), centre, radius, radius), y, 0.3, segments=72)
    front = Vector((0, y - 0.15, 0))
    c3 = Vector((centre[0], y - 0.15, centre[1]))
    gold = m["ArenaShieldGold"]
    for r, minor in ((radius - 0.12, 0.12), (2.35, 0.07)):
        torus(m["ArenaShield"], c3, (0, 1, 0), r, minor, segments=64, minor_segments=6)
    torus(gold, (PITCH.x, y - 0.17, PITCH.z), (0, 1, 0), WINDOW + 0.22, 0.14, segments=40, minor_segments=6)
    for k in range(28):
        a = 2 * math.pi * k / 28
        ball(gold, c3 + Vector((math.cos(a) * 2.75, -0.03, math.sin(a) * 2.75)), 0.09, subdivisions=1)
    # A laurel wreath round the boss, open at the top.
    for k in range(22):
        a = math.radians(105 + 330 * k / 21)
        r = 1.75
        p = Vector((PITCH.x + math.cos(a) * r, y - 0.18, PITCH.z + math.sin(a) * r))
        tangent = Vector((-math.sin(a), 0, math.cos(a)))
        leaf_pair(gold, p, tangent, (0, -1, 0), 0.55)
    # Two crossed lightning bolts above and below the window.
    for zc, flip in ((5.45, 1), (0.85, -1)):
        points = [(-1.0, 0.0), (-0.2, 0.2), (-0.35, -0.05), (0.4, 0.15), (0.2, -0.1), (1.0, 0.1)]
        for (ax, az), (bx, bz) in zip(points, points[1:]):
            a3 = Vector((PITCH.x + ax, y - 0.2, zc + az * flip))
            b3 = Vector((PITCH.x + bx, y - 0.2, zc + bz * flip))
            d = (b3 - a3).normalized()
            s = Vector((-d.z, 0, d.x)) * 0.07
            slab(gold, [a3 - s, b3 - s, b3 + s, a3 + s], 0.05, Vector((0, -1, 0)))
    for sx in (-1, 1):
        tube(m["ArenaBronze"], (PITCH.x + sx * 1.9, y + 0.2, 4.0), (PITCH.x + sx * 2.1, y + 2.2, 0.0), 0.12, 8)
    box(m["ArenaStoneDark"], (PITCH.x, y + 0.6, 0.15), (5.0, 2.4, 0.3))


# ---------- inside: banners, shields, braziers, weapons ----------

def build_interior(m):
    # Banners hanging from the upper entablature and round shields on the upper spandrels.
    for i in range(BAYS):
        s0, s1 = bay_bounds(i)
        p, t, n = frame_at(s0)
        if p.y < -4.0 and abs(p.x - 3) < 12:
            continue
        if i % 3 == 0:
            top = p + n * (THICK + 0.55) + Vector((0, 0, UP_BASE - 0.1))
            u = t * 0.6
            def banner(a, b, top=top, u=u):
                return top + u * (2 * a - 1) - Vector((0, 0, 4.0 * b)) + n * 0.05 * math.sin(math.pi * b) - (Vector((0, 0, 0.35)) if b > 0.98 and 0.3 < a < 0.7 else Vector())
            grid_surface(m["ArenaBanners"], banner, 2, 6)
            box(m["ArenaBannerGold"], top + Vector((0, 0, 0.05)), (1.4, 0.12, 0.12), Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z"))
            centre = top - Vector((0, 0, 1.6)) + n * 0.09
            for k in range(8):
                a = math.radians(100 + 340 * k / 8)
                q = centre + t * math.cos(a) * 0.38 + Vector((0, 0, math.sin(a) * 0.38))
                leaf_pair(m["ArenaBannerGold"], q, t * -math.sin(a) + Vector((0, 0, math.cos(a))), n, 0.3)
        if i % 2 == 1:
            a, _, _ = frame_at(s0)
            b, _, _ = frame_at(s1)
            mid = (a + b) / 2 + n * (THICK + 0.12)
            z = UP_SPRING + (BAY - 1.1) / 2 + 0.75
            disc(m["ArenaShields"], (mid.x, mid.y, z), n, 0.5, 0.12, segments=18)
            ball(m["ArenaShieldBosses"], mid + n * 0.08 + Vector((0, 0, z)), 0.14, subdivisions=1)
    # Bronze braziers on tripods.
    for x, y in ((-14.0, 7.0), (-14.0, 27.0), (12.0, 8.0), (12.0, 27.0)):
        c = Vector((x, y, 0))
        for k in range(3):
            a = 2 * math.pi * k / 3
            tube(m["ArenaBronze"], c + Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, 0)), c + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 3.0)), 0.07, 6)
        lathe(m["ArenaBronze"], [(0, 2.9), (0.2, 2.9), (0.72, 3.25), (0.8, 3.55), (0.7, 3.55), (0, 3.3)], 16, transform=Matrix.Translation(c))
        for k, (h, r) in enumerate(((1.2, 0.42), (0.9, 0.28), (0.8, 0.26))):
            a = 2 * math.pi * k / 3
            flame(m["ArenaFlames"], c + Vector((math.cos(a) * 0.25 * (k > 0), math.sin(a) * 0.25 * (k > 0), 3.35)), h, r)
    # A weapon rack on the left: swords, spears and a trident, with shields leaning below.
    wood, steel = m["ArenaWood"], m["ArenaWeapons"]
    for y in (13.0, 19.0):
        box(wood, (-14.6, y, 1.6), (0.3, 0.3, 3.2))
    for z in (1.2, 2.8):
        box(wood, (-14.6, 16.0, z), (0.3, 6.3, 0.22))
    for k in range(7):
        y = 13.6 + k * 0.8
        if k % 3 == 0:
            tube(wood, (-14.3, y, 0.05), (-14.5, y, 4.6), 0.05, 6)
            lathe(steel, [(0, 0), (0.1, 0.05), (0.12, 0.25), (0, 0.6)], 6, transform=Matrix.Translation((-14.5, y, 4.6)))
        else:
            box(steel, (-14.35, y, 2.0), (0.04, 0.16, 1.5))
            box(m["ArenaBronze"], (-14.35, y, 1.2), (0.08, 0.45, 0.08))
            box(wood, (-14.35, y, 0.9), (0.08, 0.1, 0.55))
            ball(m["ArenaBronze"], (-14.35, y, 0.6), 0.07, subdivisions=1)
    tube(wood, (-14.3, 19.6, 0.05), (-14.5, 19.6, 5.0), 0.05, 6)
    for dy in (-0.25, 0.0, 0.25):
        box(steel, (-14.5, 19.6 + dy, 5.2), (0.05, 0.06, 0.55))
    box(steel, (-14.5, 19.6, 4.95), (0.06, 0.6, 0.06))
    for k in range(3):
        disc(m["ArenaShields"], (-13.9, 13.8 + k * 2.2, 0.75), (1, 0, 0.35), 0.7, 0.12, segments=18)
        ball(m["ArenaShieldBosses"], (-13.78, 13.8 + k * 2.2, 0.8), 0.15, subdivisions=1)
    # A training post (palus) wrapped in straw, and amphorae on the right.
    tube(wood, (12.6, 16.0, 0.0), (12.6, 16.0, 4.2), 0.22, 10)
    tube(wood, (12.6, 15.0, 3.2), (12.6, 17.0, 3.2), 0.12, 8)
    for k in range(5):
        torus(m["ArenaStraw"], (12.6, 16.0, 1.6 + k * 0.35), (0, 0, 1), 0.3, 0.12, segments=12, minor_segments=5)
    for k, (x, y, h) in enumerate(((12.4, 21.6, 2.0), (13.0, 22.6, 1.6), (12.3, 23.6, 1.8), (12.9, 24.6, 1.5))):
        lathe(m["ArenaAmphorae"], [(0, 0), (0.08 * h, 0), (0.25 * h, 0.25 * h), (0.3 * h, 0.55 * h), (0.16 * h, 0.82 * h), (0.1 * h, 0.95 * h),
                                   (0.14 * h, 1.0 * h), (0, 0.98 * h)], 14, transform=Matrix.Translation((x, y, 0)))
        for s in (-1, 1):
            sweep(m["ArenaAmphorae"], [Vector((x + s * 0.1 * h, y, 0.92 * h)), Vector((x + s * 0.26 * h, y, 0.9 * h)), Vector((x + s * 0.22 * h, y, 0.72 * h))],
                  0.03 * h, segments=5)


# ---------- outside: crowd stands, chariot, lions ----------

def build_stands(m):
    seats = m["ArenaSeats"]
    y0, depth, rise, rows = CY + RY + 0.6, 1.45, 1.3, 5
    xs = (-14.5, 12.5)
    for k in range(rows):
        box(seats, ((xs[0] + xs[1]) / 2, y0 + depth * (k + 0.5), rise * (k + 1) / 2), (xs[1] - xs[0], depth, rise * (k + 1)))
        for i in range(int((xs[1] - xs[0]) / 1.15)):
            x = xs[0] + 0.6 + i * 1.15
            if abs(x - CX) < 2.6 and k >= 3:
                continue
            group = (i + k) % 4
            person(m, group, (x + rng.uniform(-0.1, 0.1), y0 + depth * (k + 0.3), rise * (k + 1)), (0, -1, 0), scale=0.9, arms_up=rng.random() < 0.3)
    top = rise * rows
    box(seats, ((xs[0] + xs[1]) / 2, y0 + depth * rows + 0.3, top + 1.0), (xs[1] - xs[0], 0.6, 2.0))
    for x in [xs[0] + 1.0 + 3.0 * k for k in range(9)]:
        lathe(m["ArenaColumns"], [(0, top), (0.26, top), (0.2, top + 0.2), (0.18, top + 3.0), (0.28, top + 3.2), (0, top + 3.2)], 8,
              transform=Matrix.Translation((x, y0 + depth * rows + 0.3, 0)))
    box(seats, ((xs[0] + xs[1]) / 2, y0 + depth * rows + 0.3, top + 3.35), (xs[1] - xs[0] + 0.6, 0.8, 0.3))
    # The emperor's box: a platform with a red awning on columns, a throne and the emperor.
    by = y0 + depth * 3.4
    box(m["ArenaPlinths"], (CX, by + 0.4, top - 0.6), (4.6, 2.6, 0.4))
    for sx in (-1, 1):
        for sy in (-1, 1):
            lathe(m["ArenaColumns"], [(0, top - 0.4), (0.2, top - 0.4), (0.16, top + 3.2), (0.24, top + 3.4), (0, top + 3.4)], 8,
                  transform=Matrix.Translation((CX + sx * 2.0, by + 0.4 + sy * 1.0, 0)))

    def awning(a, b):
        return Vector((CX - 2.3 + 4.6 * a, by - 0.8 + 2.6 * b, top + 3.6 + 0.6 * math.sin(math.pi * a) - 0.1 * math.sin(math.pi * b)))
    grid_surface(m["ArenaAwning"], awning, 8, 4)
    for k in range(8):
        a = (k + 0.5) / 8
        p = awning(a, 0.0)
        double_sided_poly(m["ArenaAwning"], [p - Vector((0.29, 0, 0)), p + Vector((0.29, 0, 0)), p + Vector((0, 0, -0.45))])
    box(m["ArenaChariotGold"], (CX, by + 0.9, top), (1.2, 0.8, 1.8))
    lathe(m["ArenaEmperor"], [(0, 0), (0.42, 0), (0.48, 0.7), (0.36, 1.25), (0.18, 1.42), (0, 1.44)], 10, transform=Matrix.Translation((CX, by + 0.5, top - 0.4)))
    ball(m["ArenaEmperorHead"], (CX, by + 0.5, top + 1.3), 0.27, subdivisions=2)
    torus(m["ArenaLaurel"], (CX, by + 0.5, top + 1.45), (0, 0, 1), 0.27, 0.05, segments=14, minor_segments=4)


def build_chariot(m):
    c = Vector((15.6, 6.0, 0))                 # on the arena sand beside the cage
    body, gold = m["ArenaChariot"], m["ArenaChariotGold"]
    box(m["ArenaWood"], c + Vector((0, 0.3, 1.35)), (2.0, 2.2, 0.16))
    front = [Vector((c.x + 1.0 * math.cos(a), c.y + 0.3 - 1.1 * math.sin(a) * 0.9, 0)) for a in [math.pi * k / 16 for k in range(17)]]
    loft(body, [[p + Vector((0, 0, 1.4)) for p in front], [p + Vector((0, 0, 2.6 + 0.2 * math.sin(math.pi * k / 16))) for k, p in enumerate(front)]])
    loft(body, [[p + Vector((0, 0, 2.6 + 0.2 * math.sin(math.pi * k / 16))) for k, p in enumerate(front)], [p + Vector((0, 0, 1.4)) for p in front]])
    sweep(gold, [p + Vector((0, 0, 2.62 + 0.2 * math.sin(math.pi * k / 16))) for k, p in enumerate(front)], 0.07, segments=6)
    sweep(gold, [p + Vector((0, 0, 1.95)) for p in front], 0.04, segments=5)
    tube(m["ArenaIron"], c + Vector((-1.5, 0.9, 1.35)), c + Vector((1.5, 0.9, 1.35)), 0.07, 8)
    tube(m["ArenaWood"], c + Vector((0, -0.6, 1.3)), c + Vector((0, -3.6, 1.6)), 0.09, 8)
    tube(m["ArenaWood"], c + Vector((-0.9, -3.5, 1.6)), c + Vector((0.9, -3.5, 1.6)), 0.08, 8)
    for sx in (-1, 1):
        hub = c + Vector((sx * 1.35, 0.9, 1.35))
        torus(m["ArenaWood"], hub, (1, 0, 0), 1.25, 0.1, segments=28, minor_segments=5)
        torus(gold, hub + Vector((sx * 0.06, 0, 0)), (1, 0, 0), 1.25, 0.05, segments=28, minor_segments=4)
        for k in range(8):
            a = 2 * math.pi * k / 8
            tube(m["ArenaWood"], hub, hub + Vector((0, math.cos(a) * 1.2, math.sin(a) * 1.2)), 0.05, 5)
        cylinder_x(gold, hub, 0.5, 0.16, 12)


def lion(m, base, facing=-1, turn=0.0):
    """A couchant lion built facing along Y, then turned by turn about its base."""
    b = Vector(base)
    l, f = m["ArenaLions"], facing
    start = len(l.verts)
    blob(l, b + Vector((0, -0.2 * f, 0.75)), Vector((0.75, 1.3, 0.6)), subdivisions=2, seed=1, floor=0.0)
    blob(l, b + Vector((0, 0.95 * f, 1.05)), Vector((0.85, 0.75, 0.9)), subdivisions=2, lump=0.25, lump_scale=3.0, seed=2, floor=0.0)
    blob(l, b + Vector((0, 1.45 * f, 1.35)), Vector((0.45, 0.45, 0.45)), subdivisions=2, seed=3)
    blob(l, b + Vector((0, 1.85 * f, 1.25)), Vector((0.25, 0.2, 0.2)), subdivisions=1, seed=4)
    for s in (-1, 1):
        blob(l, b + Vector((s * 0.35, 1.7 * f, 0.18)), Vector((0.2, 0.55, 0.18)), subdivisions=1, seed=s, floor=0.0)
        blob(l, b + Vector((s * 0.55, -0.9 * f, 0.4)), Vector((0.3, 0.6, 0.4)), subdivisions=1, seed=s + 3, floor=0.0)
        ball(l, b + Vector((s * 0.32, 1.6 * f, 1.85)), 0.13, subdivisions=1)
    sweep_radii(l, [b + Vector((0.3, -1.4 * f, 0.5)), b + Vector((0.6, -1.9 * f, 0.2)), b + Vector((0.4, -2.2 * f, 0.15))], [0.08, 0.06, 0.05], segments=6)
    ball(l, b + Vector((0.4, -2.25 * f, 0.18)), 0.12, subdivisions=1)
    transform_new(l, start, Matrix.Translation(b) @ Matrix.Rotation(turn, 4, "Z") @ Matrix.Translation(-b))


def build_outside(m):
    build_stands(m)
    build_chariot(m)
    # The two lions face each other across the gate.
    for x, turn in ((DOOR[0] - 3.0, math.pi / 2), (DOOR[1] + 3.0, -math.pi / 2)):
        y = -19.5
        box(m["ArenaPlinths"], (x, y, 0.6), (2.6, 1.6, 1.2))
        box(m["ArenaStoneDark"], (x, y, 1.25), (2.8, 1.8, 0.12))
        lion(m, (x, y, 1.3), facing=-1, turn=turn)
    # Amphora stacks and a few blocks by the outer wall.
    for x, y in ((19.0, 16.0), (19.4, 18.0), (-20.6, 22.0), (-21.0, 4.0)):
        lathe(m["ArenaAmphorae"], [(0, 0), (0.16, 0), (0.5, 0.5), (0.6, 1.1), (0.32, 1.64), (0.2, 1.9), (0.28, 2.0), (0, 1.96)], 14,
              transform=Matrix.Translation((x, y, 0)))


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = meshes(LOOKS)
    build_arcade(m)
    build_velarium(m)
    build_floor(m)
    build_ballista(m)
    build_screen(m)
    build_interior(m)
    build_outside(m)
    objects = build_looks(coll, m, LOOKS)
    print("bays", BAYS, "bay length %.2f" % BAY)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
