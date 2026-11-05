# Training Ground 1 of World 4, Sandbox Diamond: a batting cage that is a giant backyard sandbox. A
# hexagonal plank sandbox wall (two boards high, a low step at the door) with posts of doubled boards
# at its corners and along its sides, board beams round the top, a rope play net between them and
# four triangular shade sails at alternating heights for a roof, with bunting along the beams. The
# floor is sand with a raked lane. A toy pail lies tipped on a sand heap with the ball resting on its
# lip at PITCH, a round plastic sand-sifter is the screen, and toy shovels stand in a crate as the bat
# rack. Round it are sandcastles (one with a turning pinwheel and waving flags), starfish moulds,
# shells, a toy dump truck, a rake and a bobbing, turning beach ball.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "SandboxDiamondCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\SandboxDiamondCage.fbx"

SAND = (0.93, 0.82, 0.58)
SAND_DARK = (0.84, 0.72, 0.48)
PLANK = (0.78, 0.58, 0.36)
PLANK_DARK = (0.6, 0.42, 0.25)
ROPE = (0.2, 0.5, 0.9)
rng = random.Random(4)

# The sandbox's hexagon (back-left, back-right, mid-right, front-right, front-left, mid-left) and the
# height of the post top at each corner (the shade sails alternate low and high).
HEX = [Vector((-18.5, -16.0, 0)), Vector((16.5, -16.0, 0)), Vector((19.0, 10.0, 0)), Vector((16.5, 36.0, 0)),
       Vector((-18.5, 36.0, 0)), Vector((-21.0, 10.0, 0))]
CORNER_TOP = [13.0, 15.0, 13.0, 15.0, 13.0, 15.0]
BOARD_H, BEAM_Z = 2.0, 11.6
PAIL = Vector((PITCH.x, PITCH.y + 0.35, PITCH.z + 1.6))     # pail axis centre: the ball rests on its lower lip
PAIL_R = 1.95
SAILS = ((0, 1, 5, "SandSailYellow"), (1, 2, 5, "SandSailRed"), (2, 4, 5, "SandSailBlue"), (2, 3, 4, "SandSailGreen"))
CASTLE = Vector((-8.0, 40.6, 0))
PINWHEEL = Vector((-8.0, 40.2, 9.2))
BEACH = Vector((10.5, 41.0, 1.7))

LOOKS = {
    "SandBoards": (PLANK, "hard"), "SandBoardsDark": (PLANK_DARK, "hard"), "SandBolts": ((0.55, 0.56, 0.6), "smooth"),
    "SandNet": (ROPE, "soft"), "SandRope": ((0.9, 0.86, 0.76), "smooth"),
    "SandSailYellow": (TOY_YELLOW, "soft"), "SandSailRed": (TOY_RED, "soft"), "SandSailBlue": (TOY_BLUE, "soft"), "SandSailGreen": (TOY_GREEN, "soft"),
    "SandBuntingRed": (TOY_RED, "soft"), "SandBuntingYellow": (TOY_YELLOW, "soft"), "SandBuntingBlue": (TOY_BLUE, "soft"),
    "SandFloor": (SAND, "soft"), "SandHeaps": (SAND, "smooth"), "SandRakeLines": (SAND_DARK, "smooth"),
    "SandPail": (TOY_YELLOW, "smooth"), "SandPailRim": (TOY_BLUE, "smooth"), "SandPailStar": (TOY_RED, "hard"),
    "SandSifter": (TOY_GREEN, "smooth"), "SandSifterMesh": ((0.12, 0.5, 0.24), "soft"),
    "SandShovelHandles": (TOY_RED, "smooth"), "SandShovelScoops": (TOY_BLUE, "smooth"), "SandCrate": (TOY_BLUE, "hard"),
    "SandCastle": (SAND, "hard"), "SandCastleDark": (SAND_DARK, "hard"), "SandFlags": (TOY_RED, "soft"), "SandSticks": (CREAMY, "smooth"),
    "SandPinwheelA": (TOY_RED, "soft"), "SandPinwheelB": (TOY_YELLOW, "soft"),
    "SandBallRed": (TOY_RED, "smooth"), "SandBallYellow": (TOY_YELLOW, "smooth"), "SandBallBlue": (TOY_BLUE, "smooth"), "SandBallWhite": (WHITE, "smooth"),
    "SandStarfish": ((1.0, 0.5, 0.3), "hard"), "SandMoulds": (TOY_GREEN, "hard"), "SandShells": ((1.0, 0.86, 0.8), "smooth"),
    "SandTruckCab": (TOY_RED, "hard"), "SandTruckBed": (TOY_YELLOW, "hard"), "SandTruckWheels": ((0.12, 0.12, 0.14), "smooth"),
    "SandGrass": ((0.36, 0.64, 0.28), "soft"), "SandPlate": (WHITE, "hard"), "SandBall": (WHITE, "smooth"),
}


# ---------- the sandbox frame ----------

def edge(i):
    return HEX[i], HEX[(i + 1) % 6]


def inside_hex(x, y, inset=0.0):
    p = Vector((x, y, 0))
    for i in range(6):
        a, b = edge(i)
        t = (b - a).normalized()
        n = Vector((t.y, -t.x, 0))                # outward (the hexagon runs counter-clockwise)
        if (p - a).dot(n) > -inset:
            return False
    return True


def board_post(m, p, top, inward):
    """A post of two boards bolted side by side, with a cap block."""
    side = Vector((-inward.y, inward.x, 0))
    for s in (-1, 1):
        c = p + side * s * 0.27
        box(m["SandBoards"], (c.x, c.y, top / 2), (0.5, 0.5, top), Matrix.Rotation(math.atan2(side.y, side.x), 4, "Z"))
    box(m["SandBoardsDark"], (p.x, p.y, top + 0.15), (1.3, 1.3, 0.3), Matrix.Rotation(math.atan2(side.y, side.x), 4, "Z"))
    for z in (0.6, 1.4, BEAM_Z - 0.5):
        ball(m["SandBolts"], p + inward * 0.27 + Vector((0, 0, z)), 0.09, subdivisions=1)


def build_frame(m):
    posts = []
    for i in range(6):
        a, b = edge(i)
        t = (b - a).normalized()
        n = Vector((-t.y, t.x, 0))                 # inward
        length = (b - a).length
        turn = Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z")
        # Two boards high, with a gap for the door in the back wall (one low step board instead).
        for k in range(2):
            z = 0.5 + k * 1.0
            segments = [(0.0, length)]
            if i == 0:
                d0, d1 = DOOR[0] - 0.5 - a.x, DOOR[1] + 0.5 - a.x
                segments = [(0.0, d0), (d1, length)] if k == 1 else [(0.0, length)]
            for s0, s1 in segments:
                c = a + t * ((s0 + s1) / 2)
                box(m["SandBoards" if k == 0 else "SandBoardsDark"], (c.x, c.y, z), (s1 - s0 + 0.6, 0.5, 0.95), turn)
        cap = a + t * (length / 2) + n * 0.1
        box(m["SandBoardsDark"], (cap.x, cap.y, BOARD_H + 0.08), (length + 0.8, 0.9, 0.16), turn)
        posts.append((a, CORNER_TOP[i], n))
        mid = a.lerp(b, 0.5)
        if length > 20:
            posts.append((mid, BEAM_Z + 0.5, n))
        # The top beam: a board on edge along the posts.
        box(m["SandBoards"], (mid.x, mid.y, BEAM_Z), (length + 0.4, 0.4, 0.8), turn)
    for p, top, n in posts:
        board_post(m, p, top, n)
    return posts


def build_net(m):
    net = m["SandNet"]
    for i in range(6):
        a, b = edge(i)
        t = (b - a).normalized()
        n = Vector((-t.y, t.x, 0))
        length = (b - a).length

        def hole(u, v, i=i, a=a, t=t):
            if i != 0:
                return False
            x = a.x + t.x * u
            return DOOR[0] - 0.4 < x < DOOR[1] + 0.4 and v < DOOR[2] - BOARD_H + 0.2
        net_panel(net, Vector((a.x, a.y, BOARD_H + 0.2)) + n * 0.05, t, Vector((0, 0, 1)), length, BEAM_Z - BOARD_H - 0.6, -n, 1.5, 0.08,
                  hole=hole, rope=0.07, diamond=True)


def build_sails(m):
    rope = m["SandRope"]
    tops = [HEX[i] + Vector((0, 0, CORNER_TOP[i] + 0.3)) for i in range(6)]
    centre = sum(HEX, Vector()) / 6
    for i0, i1, i2, name in SAILS:
        corners = [tops[i0], tops[i1], tops[i2]]
        middle = sum(corners, Vector()) / 3
        inset = [c.lerp(middle, 0.08) for c in corners]

        def sail(a, b, inset=inset):
            # A triangle mapped from the unit square (b collapses toward the third corner), sagging
            # in the middle like stretched cloth.
            p = inset[0].lerp(inset[1], a).lerp(inset[2], b)
            w0, w1, w2 = (1 - a) * (1 - b), a * (1 - b), b
            return p - Vector((0, 0, 1.6 * 27 * w0 * w1 * w2 + 0.4 * math.sin(math.pi * b)))
        grid_surface(m[name], sail, 10, 10)
        for c, q in zip(corners, inset):
            sweep(rope, [c, q], 0.05, segments=5)
            torus(m["SandBolts"], q, (q - c).normalized(), 0.14, 0.04, segments=10, minor_segments=4)
    # Bunting along the top beams: pennants alternating red, yellow and blue.
    colors = ("SandBuntingRed", "SandBuntingYellow", "SandBuntingBlue")
    k = 0
    for i in range(6):
        a, b = edge(i)
        line = wavy(a + Vector((0, 0, BEAM_Z + 0.1)), b + Vector((0, 0, BEAM_Z + 0.1)), 20, 0.0, sag=0.0)
        for p, q in zip(line[1:-1:2], line[2:-1:2]):
            mid = (p + q) / 2
            double_sided_poly(m[colors[k % 3]], [p - Vector((0, 0, 0.42)), q - Vector((0, 0, 0.42)), mid - Vector((0, 0, 1.4))])
            k += 1


# ---------- floor ----------

def build_floor(m):
    x0, x1 = min(p.x for p in HEX), max(p.x for p in HEX)
    y0, y1 = min(p.y for p in HEX), max(p.y for p in HEX)

    def sand(u, v):
        return Vector((x0 + (x1 - x0) * u, y0 + (y1 - y0) * v, 0.03))

    def keep(u, v):
        x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * v
        in_rect = LEFT_X - 0.4 < x < RIGHT_X + 0.4 and BACK_Y - 0.4 < y < FRONT_Y + 0.4
        return inside_hex(x, y, inset=0.3) and not in_rect
    grid_surface(m["SandFloor"], sand, 80, 104, keep=keep)
    # Rake lines down the pitch lane and swirls round the batter's ground.
    for k in range(8):
        x = PITCH.x - 1.75 + 0.5 * k
        line = [Vector((x + 0.06 * math.sin(j * 0.9), 3.9 + 16.4 * j / 20, 0.02)) for j in range(21)]
        sweep(m["SandRakeLines"], line, 0.05, segments=4)
    for r in (6.6, 7.4):
        for a0, a1 in ((math.radians(195), math.radians(262)), (math.radians(278), math.radians(345))):
            arc = [Vector((PITCH.x + r * math.cos(a0 + (a1 - a0) * j / 14), r * 0.75 * math.sin(a0 + (a1 - a0) * j / 14), 0.02)) for j in range(15)]
            sweep(m["SandRakeLines"], arc, 0.05, segments=4)
    # Sand heaps along the inside of the sandbox wall.
    for i in range(6):
        a, b = edge(i)
        t = (b - a).normalized()
        n = Vector((-t.y, t.x, 0))
        length = (b - a).length
        for k in range(int(length / 6)):
            p = a + t * (3 + k * 6 + rng.uniform(-1, 1)) + n * 1.7
            if i == 0 and DOOR[0] - 2 < p.x < DOOR[1] + 2:
                continue
            if i == 0 and -4 < p.x < 10:
                continue
            blob(m["SandHeaps"], p, Vector((rng.uniform(1.2, 2.0), rng.uniform(1.2, 2.0), rng.uniform(0.5, 1.1))), subdivisions=2, lump=0.15,
                 seed=p.x + p.y, floor=0.0)
    home_plate(m["SandPlate"], 0.08)


# ---------- the pail, the sifter and the shovels ----------

def star(bm, centre, radius, z0, z1, points=5, inner=0.45, spin=0.0):
    outline = []
    for k in range(points * 2):
        a = spin + math.pi * k / points
        r = radius if k % 2 == 0 else radius * inner
        outline.append((centre[0] + r * math.cos(a), centre[1] + r * math.sin(a)))
    prism(bm, outline, z0, z1)


def build_pail(m):
    """A toy pail tipped on a sand heap, mouth to the batter; the ball rests on its lower lip."""
    along = Matrix.Translation(PAIL) @ Matrix.Rotation(-math.pi / 2, 4, "X")
    depth = 3.6
    lathe(m["SandPail"], [(PAIL_R - 0.12, 0.0), (PAIL_R, 0.0), (PAIL_R * 0.78, depth), (0.0, depth), (0.0, depth - 0.12), (PAIL_R * 0.78 - 0.12, depth - 0.12),
                          (PAIL_R - 0.12, 0.0)], 32, transform=along)
    torus(m["SandPailRim"], PAIL, (0, 1, 0), PAIL_R + 0.05, 0.16, segments=40, minor_segments=8)
    torus(m["SandPailRim"], PAIL + Vector((0, depth * 0.85, 0)), (0, 1, 0), PAIL_R * 0.82, 0.1, segments=36, minor_segments=6)
    # The handle swung down over the top, with hinge bolts either side.
    for sx in (-1, 1):
        ball(m["SandPailRim"], PAIL + Vector((sx * (PAIL_R - 0.05), 0.5, 0)), 0.2, subdivisions=2)
    handle = [PAIL + Vector((math.cos(a) * (PAIL_R + 0.25), 0.5 + 1.4 * math.sin(a) ** 2, math.sin(a) * (PAIL_R + 0.25))) for a in
              [math.pi * k / 16 for k in range(17)]]
    sweep(m["SandPailRim"], handle, 0.08, segments=6)
    # A red star on its side, curved to fit (built flat, then bent round the pail).
    start = len(m["SandPailStar"].verts)
    star(m["SandPailStar"], (0, 0), 0.8, PAIL_R * 0.9 - 0.02, PAIL_R * 0.9 + 0.05)
    transform_new(m["SandPailStar"], start, Matrix.Translation(PAIL + Vector((0, 1.8, 0))) @ Matrix.Rotation(math.radians(-30), 4, "Y"))
    # The heap it lies on, and the sand spilling out over the lip.
    blob(m["SandHeaps"], Vector((PITCH.x, PAIL.y + 1.4, 0.0)), Vector((3.2, 3.2, PAIL.z - PAIL_R + 0.3)), subdivisions=3, lump=0.12, seed=9, floor=0.0)
    blob(m["SandHeaps"], Vector((PITCH.x, PAIL.y - 1.1, 0.0)), Vector((1.6, 1.5, 0.9)), subdivisions=2, lump=0.2, seed=10, floor=0.0)
    blob(m["SandHeaps"], PAIL + Vector((0, 0.6, -PAIL_R + 0.25)), Vector((1.2, 1.0, 0.35)), subdivisions=2, lump=0.2, seed=11)
    pitch_ball(m["SandBall"])


def build_sifter(m):
    """A round plastic sand sifter stood on edge: a ring, a square mesh with the window cut out, two
    handle tabs and two little feet."""
    y = SCREEN_Y
    c = Vector((PITCH.x, y, 3.3))
    r = 3.25
    annulus(m["SandSifter"], c, (0, 1, 0), r - 0.22, r + 0.08, 0.55, segments=64)
    torus(m["SandSifter"], c + Vector((0, -0.28, 0)), (0, 1, 0), r - 0.07, 0.1, segments=64, minor_segments=5)
    window_panel(m["SandSifter"], lambda a: ray_ellipse((PITCH.x, PITCH.z), (math.cos(a), math.sin(a)), (PITCH.x, PITCH.z), WINDOW + 0.32, WINDOW + 0.32),
                 y - 0.02, 0.22, segments=40)

    def hole(u, v):
        x, z = c.x - r + u, c.z - r + v
        return (Vector((x, z)) - Vector((c.x, c.z))).length > r - 0.18 or (Vector((x, z)) - Vector((PITCH.x, PITCH.z))).length < WINDOW + 0.28
    net_panel(m["SandSifterMesh"], Vector((c.x - r, y, c.z - r)), Vector((1, 0, 0)), Vector((0, 0, 1)), 2 * r, 2 * r, Vector((0, -1, 0)), 0.36, 0.05,
              hole=hole, rope=0.0)
    for sx in (-1, 1):
        box(m["SandSifter"], (c.x + sx * (r + 0.4), y, c.z + 0.6), (0.9, 0.5, 0.45))
        box(m["SandSifter"], (c.x + sx * 1.6, y, 0.25), (1.0, 1.6, 0.5))


def build_shovels(m):
    """A toy crate by the left wall holding four shovels upright: the bat rack."""
    cx, cy = LEFT_X + 1.7, 5.0
    crate = m["SandCrate"]
    for sx in (-1, 1):
        box(crate, (cx + sx * 0.8, cy, 0.7), (0.12, 3.4, 1.4))
    for sy in (-1, 1):
        box(crate, (cx, cy + sy * 1.65, 0.7), (1.7, 0.12, 1.4))
    for z in (0.35, 1.05):
        for sx in (-1, 1):
            box(crate, (cx + sx * 0.85, cy, z), (0.08, 3.5, 0.25))
    box(crate, (cx, cy, 0.06), (1.7, 3.4, 0.12))
    for k in range(4):
        y = cy - 1.2 + 0.8 * k
        lean = Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.1, 0.1), 1)).normalized()
        base = Vector((cx, y, 0.2))
        top = base + lean * 4.6
        tube(m["SandShovelHandles"], base + lean * 1.2, top, 0.1, 8)
        tube(m["SandShovelHandles"], top - Vector((0, 0.45, 0)), top + Vector((0, 0.45, 0)), 0.09, 8)
        lathe(m["SandShovelScoops"], [(0, 0.0), (0.4, 0.15), (0.55, 0.7), (0.3, 1.25), (0.1, 1.3), (0, 1.32)], 12,
              transform=Matrix.Translation(base) @ Matrix.Diagonal((1, 0.3, 1, 1)))


# ---------- sandcastles, toys ----------

def tower(m, base, radius, height, mesh="SandCastle"):
    b = Vector(base)
    lathe(m[mesh], [(0, 0), (radius * 1.08, 0), (radius, height), (0, height)], 14, transform=Matrix.Translation(b))
    for k in range(8):
        a = 2 * math.pi * k / 8
        box(m[mesh], b + Vector((math.cos(a) * radius * 0.85, math.sin(a) * radius * 0.85, height + 0.22)), (radius * 0.48, radius * 0.48, 0.45),
            Matrix.Rotation(a, 4, "Z"))
    for k in range(3):
        z = height * (0.3 + 0.25 * k)
        torus(m["SandCastleDark"], b + Vector((0, 0, z)), (0, 0, 1), radius * (1.06 - 0.08 * z / height), 0.05, segments=16, minor_segments=3)


def flag(m, top, side=1):
    t = Vector(top)
    tube(m["SandSticks"], t - Vector((0, 0, 1.6)), t, 0.04, 5)
    double_sided_poly(m["SandFlags"], [t, t - Vector((0, 0, 0.5)), t + Vector((side * 0.8, 0, -0.25))])


def sandcastle(m, centre, scale=1.0, flags=True):
    c, s = Vector(centre), scale
    box(m["SandCastle"], c + Vector((0, 0, 0.9 * s)), (4.0 * s, 4.0 * s, 1.8 * s))
    for k in range(4):
        a = math.pi / 2 * k
        crenellations(m["SandCastle"], c + Vector((math.cos(a) * 2.0 * s - math.sin(a) * 2.0 * s, math.sin(a) * 2.0 * s + math.cos(a) * 2.0 * s, 0)),
                      c + Vector((math.cos(a) * 2.0 * s + math.sin(a) * 2.0 * s, math.sin(a) * 2.0 * s - math.cos(a) * 2.0 * s, 0)),
                      1.8 * s, 0.4 * s, merlon=0.6 * s, gap=0.45 * s, depth=0.45 * s)
    for dx in (-2.0, 2.0):
        for dy in (-2.0, 2.0):
            tower(m, c + Vector((dx * s, dy * s, 0)), 0.85 * s, 3.2 * s)
            if flags:
                flag(m, c + Vector((dx * s, dy * s, 3.2 * s + 2.0 * s)), 1 if dx > 0 else -1)
    tower(m, c, 1.1 * s, 4.8 * s)
    lathe(m["SandCastle"], [(0, 4.8 * s + 0.45), (1.0 * s, 4.8 * s + 0.45), (0, 6.6 * s)], 14, transform=Matrix.Translation(c))
    # An arched door, and a moat traced round it.
    box(m["SandCastleDark"], c + Vector((0, -2.02 * s, 0.6 * s)), (0.8 * s, 0.1, 1.2 * s))
    torus(m["SandCastleDark"], c + Vector((0, 0, 0.03)), (0, 0, 1), 3.6 * s, 0.25 * s, segments=32, minor_segments=4)


def beach_ball(m):
    """Six coloured gores, opposite gores in the same mesh so each mesh is centred on the ball (it
    turns and bobs as a whole), with white caps."""
    names = ("SandBallRed", "SandBallYellow", "SandBallBlue")
    r, n = 1.6, 12
    for g in range(6):
        bm = m[names[g % 3]]
        a0, a1 = 2 * math.pi * g / 6, 2 * math.pi * (g + 1) / 6
        rows = []
        for i in range(1, n):
            lat = -math.pi / 2 + math.pi * i / n
            if abs(lat) > math.radians(72):
                continue
            rows.append([BEACH + Vector((math.cos(lat) * math.cos(a0 + (a1 - a0) * j / 4) * r, math.cos(lat) * math.sin(a0 + (a1 - a0) * j / 4) * r,
                                         math.sin(lat) * r)) for j in range(5)])
        loft(bm, rows)
        loft(bm, [list(reversed(row)) for row in rows])
    for sz in (-1, 1):
        lathe(m["SandBallWhite"], [(0, sz * r * 1.003), (r * math.cos(math.radians(70)) * 1.003, sz * r * math.sin(math.radians(70)) * 1.003)], 24,
              transform=Matrix.Translation(BEACH))


def pinwheel(m):
    """A pinwheel stuck in the big castle's keep, turning about its axle (Blender +Y)."""
    tube(m["SandSticks"], PINWHEEL - Vector((0, -0.1, 3.0)), PINWHEEL + Vector((0, 0.15, 0)), 0.06, 6)
    for k in range(4):
        a = math.pi / 2 * k
        d, s = Vector((math.cos(a), 0, math.sin(a))), Vector((-math.sin(a), 0, math.cos(a)))
        bm = m["SandPinwheelA" if k % 2 == 0 else "SandPinwheelB"]
        double_sided_poly(bm, [PINWHEEL + d * 0.12, PINWHEEL + d * 1.25, PINWHEEL + d * 1.2 + s * 0.8 + Vector((0, -0.25, 0))])
    ball(m["SandSticks"], PINWHEEL + Vector((0, -0.08, 0)), 0.12, subdivisions=1)


def dump_truck(m, base):
    b = Vector(base)
    box(m["SandTruckCab"], b + Vector((0, -1.6, 1.1)), (1.7, 1.4, 1.3))
    box(m["SandTruckCab"], b + Vector((0, 0.3, 0.55)), (1.7, 4.4, 0.35))
    box(m["SandTruckBed"], b + Vector((0, 0.9, 1.25)), (1.8, 2.6, 0.12), Matrix.Rotation(math.radians(-14), 4, "X"))
    for sx in (-1, 1):
        box(m["SandTruckBed"], b + Vector((sx * 0.86, 0.9, 1.6)), (0.1, 2.6, 0.7), Matrix.Rotation(math.radians(-14), 4, "X"))
    box(m["SandTruckBed"], b + Vector((0, 2.25, 1.95)), (1.8, 0.1, 0.8))
    box(m["SandStarfish"], b + Vector((0, -2.32, 1.2)), (1.4, 0.04, 0.6))
    for sx in (-1, 1):
        for y in (-1.5, 1.4):
            cylinder_x(m["SandTruckWheels"], b + Vector((sx * 0.95, y, 0.55)), 0.4, 0.55, 14)
    blob(m["SandHeaps"], b + Vector((0, 1.0, 1.5)), Vector((0.8, 1.1, 0.45)), subdivisions=2, lump=0.2, seed=3)


def build_toys(m):
    sandcastle(m, (-12.4, 28.6, 0), 0.75)
    sandcastle(m, (11.0, -9.5, 0), 0.6, flags=False)
    sandcastle(m, CASTLE, 1.25)
    pinwheel(m)
    beach_ball(m)
    dump_truck(m, (-19.0, 26.0, 0))
    # Starfish moulds and shells on the sand, a rake against the right wall, spare pails.
    for x, y, r, mesh in ((-13.8, 12.0, 0.6, "SandStarfish"), (12.2, 14.0, 0.7, "SandMoulds"), (-13.0, -6.0, 0.55, "SandMoulds"),
                          (11.8, 22.0, 0.5, "SandStarfish"), (18.0, 30.0, 0.6, "SandStarfish"), (-19.6, 2.0, 0.55, "SandMoulds")):
        star(m[mesh], (x, y), r, 0.03, 0.22, spin=rng.uniform(0, 1))
    for x, y in ((-12.6, 18.0), (12.6, 4.0), (-17.5, 33.0), (15.0, -13.0), (2.0, 38.5)):
        lathe(m["SandShells"], [(0, 0.02), (0.45, 0.02), (0.35, 0.22), (0.12, 0.34), (0, 0.36)], 9, transform=Matrix.Translation((x, y, 0)) @ Matrix.Diagonal((1, 0.8, 1, 1)))
    tube(m["SandShovelHandles"], (13.1, 18.0, 0.1), (13.1, 18.4, 5.0), 0.1, 8)
    box(m["SandMoulds"], (13.1, 18.5, 5.0), (0.25, 2.0, 0.25))
    for k in range(7):
        box(m["SandMoulds"], (12.95, 17.6 + k * 0.3, 4.7), (0.12, 0.1, 0.55))
    for x, y, h, mesh in ((12.0, 26.4, 1.4, "SandPail"), (-13.4, 21.6, 1.1, "SandTruckBed")):
        lathe(m[mesh], [(0, 0), (0.55 * h, 0), (0.75 * h, h), (0.68 * h, h), (0.5 * h, 0.08), (0, 0.08)], 18, transform=Matrix.Translation((x, y, 0)))
    # Grass tufts on the lawn round the sandbox.
    for _ in range(60):
        i = rng.randrange(6)
        a, b = edge(i)
        t = (b - a).normalized()
        n = Vector((t.y, -t.x, 0))
        p = a.lerp(b, rng.random()) + n * rng.uniform(1.0, 1.8)
        if not (-22.6 < p.x < 20.6):
            continue
        for _ in range(6):
            ang = rng.uniform(0, 2 * math.pi)
            tip = p + Vector((math.cos(ang) * 0.3, math.sin(ang) * 0.3, rng.uniform(0.5, 0.9)))
            double_sided_strip(m["SandGrass"], [p - Vector((0.05, 0, 0)), tip], [p + Vector((0.05, 0, 0)), tip + Vector((0.01, 0, 0))])


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = meshes(LOOKS)
    build_frame(m)
    build_net(m)
    build_sails(m)
    build_floor(m)
    build_pail(m)
    build_sifter(m)
    build_shovels(m)
    build_toys(m)
    for name in ("SandFlags", "SandPinwheelA", "SandPinwheelB"):
        bmesh.ops.triangulate(m[name], faces=m[name].faces[:])
    objects = build_looks(coll, m, LOOKS)
    check_centred(objects, {"SandPinwheelA": (PINWHEEL, (0, 1, 0)), "SandPinwheelB": (PINWHEEL, (0, 1, 0)),
                            "SandBallRed": (BEACH, (0, 0, 1)), "SandBallYellow": (BEACH, (0, 0, 1)), "SandBallBlue": (BEACH, (0, 0, 1)),
                            "SandBallWhite": (BEACH, (0, 0, 1))})
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
