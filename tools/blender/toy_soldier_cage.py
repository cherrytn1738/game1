# Training Ground 4 of World 4, Toy Soldier Fort: the batting cage is a painted wooden toy fort.
# Plank walls with battlements, a blue base band and a red stripe run between round blue corner towers
# (red cone roofs, white trim, arrow slits, waving flags) and square mid-side towers, with a wall walk
# inside. A gatehouse frames the door, with its portcullis raised and a drawbridge lowered across a
# painted moat on chains. A red-and-white striped tent canopy on a ridge pole is the roof. A big
# wind-up tin soldier holds the ball out at PITCH while the key in his back turns. A toy drum with
# gold zigzag cords is the screen, with the window through both heads. Inside are a toy cannon with
# cannonballs, a row of soldiers on guard, alphabet blocks, barrels and crates, and a striped sentry
# box at the gate.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "ToySoldierCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\ToySoldierCage.fbx"

PAINT_TAN = (0.86, 0.68, 0.44)
PAINT_BLUE = (0.18, 0.32, 0.72)
PAINT_RED = (0.84, 0.16, 0.16)
NAVY = (0.12, 0.18, 0.44)
GOLD = (1.0, 0.78, 0.25)
SKIN = (1.0, 0.84, 0.7)
BLACK = (0.06, 0.06, 0.07)
rng = random.Random(36)

CX = (LEFT_X + RIGHT_X) / 2
WX0, WX1, WY0, WY1 = LEFT_X - 0.6, RIGHT_X + 0.6, BACK_Y - 0.6, FRONT_Y + 0.6     # the wall lines
WALL_H, WALK_Z = 8.0, 6.4
TOWER_R, TOWER_H = 2.7, 11.0
RIDGE_Z = 15.6
GATE = (DOOR[0] - 2.6, DOOR[1] + 2.6)
SOLDIER = Vector((PITCH.x, PITCH.y + 2.0, 0.55))      # the wind-up soldier's feet, on his stand
KEY = SOLDIER + Vector((0, 1.05, 4.0))
FLAGS = {"FortFlagA": Vector((WX0, WY0, 0)), "FortFlagB": Vector((WX1, WY0, 0)), "FortFlagC": Vector((WX0, WY1, 0)), "FortFlagD": Vector((WX1, WY1, 0))}

LOOKS = {
    "FortWalls": (PAINT_TAN, "hard"), "FortSeams": ((0.62, 0.46, 0.28), "hard"), "FortBaseBand": (PAINT_BLUE, "hard"), "FortStripe": (PAINT_RED, "hard"),
    "FortMerlons": (PAINT_TAN, "hard"), "FortWalk": ((0.7, 0.52, 0.32), "hard"),
    "FortTowers": (PAINT_BLUE, "smooth"), "FortTowerTrim": (WHITE, "smooth"), "FortRoofs": (PAINT_RED, "smooth"), "FortSlits": (BLACK, "hard"),
    "FortPoles": ((0.9, 0.86, 0.78), "smooth"), "FortPennants": (TOY_YELLOW, "soft"),
    "FortGate": (PAINT_BLUE, "hard"), "FortPortcullis": ((0.3, 0.3, 0.34), "hard"), "FortBridge": ((0.66, 0.46, 0.26), "hard"),
    "FortChains": ((0.55, 0.56, 0.6), "smooth"), "FortMoat": ((0.25, 0.55, 0.9), "hard"), "FortWaves": (WHITE, "smooth"),
    "FortCanvasRed": (PAINT_RED, "soft"), "FortCanvasWhite": (WHITE, "soft"),
    "FortPath": ((0.86, 0.76, 0.56), "hard"),
    "FortCoat": (PAINT_RED, "smooth"), "FortTrousers": (NAVY, "smooth"), "FortSkin": (SKIN, "smooth"), "FortBlack": (BLACK, "smooth"),
    "FortGold": (GOLD, "smooth"), "FortBelts": (WHITE, "smooth"), "FortRifleWood": ((0.5, 0.3, 0.16), "smooth"), "FortSteel": ((0.7, 0.72, 0.76), "smooth"),
    "FortStand": (TOY_GREEN, "smooth"), "FortKey": (GOLD, "smooth"),
    "FortDrum": (PAINT_RED, "smooth"), "FortDrumHeads": ((0.97, 0.95, 0.88), "hard"), "FortDrumHoops": (PAINT_BLUE, "smooth"), "FortDrumCords": (GOLD, "smooth"),
    "FortCannon": ((0.2, 0.2, 0.22), "smooth"), "FortCarriage": (PAINT_RED, "hard"), "FortWheels": (TOY_YELLOW, "smooth"),
    "FortBlocks": (TOY_YELLOW, "hard"), "FortBlocksRed": (TOY_RED, "hard"), "FortBlocksBlue": (TOY_BLUE, "hard"), "FortLetters": (WHITE, "hard"),
    "FortBarrels": ((0.62, 0.42, 0.24), "smooth"), "FortPlate": (WHITE, "hard"), "FortBall": (WHITE, "smooth"),
}
for name in FLAGS:
    LOOKS[name] = (TOY_YELLOW if name in ("FortFlagA", "FortFlagD") else PAINT_RED, "soft")


# ---------- walls, towers, gate ----------

def wall(m, a, b, gap=None):
    """A plank wall from a to b: seams, a blue base band, a red stripe and battlements on top.
    gap = (x0, x1) leaves an opening (the gate)."""
    a, b = Vector(a), Vector(b)
    t = (b - a).normalized()
    n = Vector((-t.y, t.x, 0))
    length = (b - a).length
    turn = Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z")
    pieces = [(0.0, length)]
    if gap:
        g0, g1 = sorted(((gap[0] - a.x) / t.x, (gap[1] - a.x) / t.x))
        pieces = [(0.0, g0), (g1, length)]
    for s0, s1 in pieces:
        if s1 - s0 < 0.2:
            continue
        mid = a + t * ((s0 + s1) / 2)
        box(m["FortWalls"], (mid.x, mid.y, WALL_H / 2), (s1 - s0, 1.0, WALL_H), turn)
        box(m["FortBaseBand"], (mid.x, mid.y, 0.4), (s1 - s0, 1.08, 0.8), turn)
        box(m["FortStripe"], (mid.x, mid.y, WALL_H - 1.1), (s1 - s0, 1.06, 0.4), turn)
        crenellations(m["FortMerlons"], a + t * s0, a + t * s1, WALL_H, 1.0, merlon=1.3, gap=0.9, depth=1.0)
        s = s0 + 0.8
        while s < s1 - 0.4:
            p = a + t * s
            for face in (-1, 1):
                q = p + n * face * 0.51
                box(m["FortSeams"], (q.x, q.y, (0.8 + WALL_H - 1.3) / 2), (0.06, 0.03, WALL_H - 2.1), turn)
            s += 0.8


def tower(m, x, y, flag=None):
    """A round painted tower: trim bands, arrow slits, crenellated top, a red cone roof and a flag."""
    c = Vector((x, y, 0))
    lathe(m["FortTowers"], [(0, 0), (TOWER_R + 0.15, 0), (TOWER_R, 0.6), (TOWER_R - 0.1, TOWER_H), (0, TOWER_H)], 24, transform=Matrix.Translation(c))
    for z in (0.6, 5.0, TOWER_H - 0.4):
        torus(m["FortTowerTrim"], c + Vector((0, 0, z)), (0, 0, 1), TOWER_R - 0.05, 0.16, segments=28, minor_segments=5)
    for k in range(10):
        a = 2 * math.pi * k / 10
        d = Vector((math.cos(a), math.sin(a), 0))
        box(m["FortTowers"], c + d * (TOWER_R - 0.3) + Vector((0, 0, TOWER_H + 0.45)), (0.9, 0.6, 0.9), Matrix.Rotation(a + math.pi / 2, 4, "Z"))
        if k % 3 == 0:
            for z in (3.0, 7.6):
                box(m["FortSlits"], c + d * (TOWER_R - 0.06) + Vector((0, 0, z)), (0.18, 0.18, 1.1), Matrix.Rotation(a, 4, "Z"))
    lathe(m["FortRoofs"], [(0, TOWER_H + 0.9), (TOWER_R + 0.5, TOWER_H + 0.9), (TOWER_R + 0.3, TOWER_H + 1.2), (0, TOWER_H + 5.0)], 24,
          transform=Matrix.Translation(c))
    ball(m["FortGold"], c + Vector((0, 0, TOWER_H + 5.1)), 0.3, subdivisions=2)
    if flag:
        pole_top = c + Vector((0, 0, TOWER_H + 7.6))
        tube(m["FortPoles"], c + Vector((0, 0, TOWER_H + 5.0)), pole_top, 0.08, 6)

        def cloth(u, v, top=pole_top):
            return top + Vector((0, 0, -0.1 - 1.4 * v)) + Vector((math.cos(0.4), math.sin(0.4), 0)) * (2.4 * u) + Vector((0, 0, 0.15 * math.sin(math.pi * u * 2)))
        grid_surface(m[flag], cloth, 6, 3)


def square_tower(m, x0, x1, y0, y1, top):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    box(m["FortTowers"], (cx, cy, top / 2), (x1 - x0, y1 - y0, top))
    for z in (0.6, top - 0.4):
        box(m["FortTowerTrim"], (cx, cy, z), (x1 - x0 + 0.12, y1 - y0 + 0.12, 0.3))
    crenellations(m["FortMerlons"], (x0, y0, 0), (x1, y0, 0), top, 0.6, merlon=0.9, gap=0.6, depth=0.9)
    crenellations(m["FortMerlons"], (x0, y1, 0), (x1, y1, 0), top, 0.6, merlon=0.9, gap=0.6, depth=0.9)
    crenellations(m["FortMerlons"], (x0, y0, 0), (x0, y1, 0), top, 0.6, merlon=0.9, gap=0.6, depth=0.9)
    crenellations(m["FortMerlons"], (x1, y0, 0), (x1, y1, 0), top, 0.6, merlon=0.9, gap=0.6, depth=0.9)
    for z in (3.0, 6.4):
        for x, y in ((x0, cy), (x1, cy), (cx, y0), (cx, y1)):
            box(m["FortSlits"], (x, y, z), (0.2 if x in (x0, x1) else 0.16, 0.2 if y in (y0, y1) else 0.16, 1.0))
    tube(m["FortPoles"], (cx, cy, top + 0.9), (cx, cy, top + 3.8), 0.06, 6)
    double_sided_poly(m["FortPennants"], [Vector((cx, cy, top + 3.8)), Vector((cx, cy, top + 3.0)), Vector((cx + 1.4, cy, top + 3.4))])


def build_fort(m):
    wall(m, (WX0, WY0, 0), (WX1, WY0, 0), gap=GATE)
    wall(m, (WX1, WY0, 0), (WX1, WY1, 0))
    wall(m, (WX1, WY1, 0), (WX0, WY1, 0))
    wall(m, (WX0, WY1, 0), (WX0, WY0, 0))
    for name, p in FLAGS.items():
        tower(m, p.x, p.y, flag=name)
    for x in (WX0, WX1):
        square_tower(m, x - 2.0, x + 2.0, 8.0, 12.0, 10.0)
    # The wall walk inside the side and front walls, on posts.
    for a, b in (((WX0 + 0.5, WY0 + 3.0), (WX0 + 0.5, WY1 - 3.0)), ((WX1 - 0.5, WY0 + 3.0), (WX1 - 0.5, WY1 - 3.0)), ((WX0 + 3.0, WY1 - 0.5), (WX1 - 3.0, WY1 - 0.5))):
        a3, b3 = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
        t = (b3 - a3).normalized()
        n = Vector((-t.y, t.x, 0))
        side = n if (CX - a3.x) * n.x + (10 - a3.y) * n.y > 0 else -n
        mid = (a3 + b3) / 2 + side * 0.9
        length = (b3 - a3).length
        turn = Matrix.Rotation(math.atan2(t.y, t.x), 4, "Z")
        box(m["FortWalk"], (mid.x, mid.y, WALK_Z), (length, 1.8, 0.22), turn)
        s = 0.0
        while s <= length:
            p = a3 + t * s + side * 1.6
            box(m["FortWalk"], (p.x, p.y, WALK_Z / 2), (0.3, 0.3, WALK_Z), turn)
            s += 4.0


def build_gate(m):
    """The gatehouse: two square towers, an arch over the door, a raised portcullis, and the
    drawbridge lowered across the moat on chains."""
    g = m["FortGate"]
    for x0, x1 in ((GATE[0], DOOR[0] - 0.1), (DOOR[1] + 0.1, GATE[1])):
        box(g, ((x0 + x1) / 2, WY0, 5.5), (x1 - x0, 3.0, 11.0))
        crenellations(m["FortMerlons"], (x0, WY0 - 1.5, 0), (x1, WY0 - 1.5, 0), 11.0, 0.6, merlon=0.8, gap=0.5, depth=0.9)
        box(m["FortTowerTrim"], ((x0 + x1) / 2, WY0, 10.7), (x1 - x0 + 0.12, 3.12, 0.3))
        box(m["FortSlits"], ((x0 + x1) / 2, WY0 - 1.52, 7.5), (0.2, 0.06, 1.2))
    mid = (DOOR[0] + DOOR[1]) / 2
    box(g, (mid, WY0, 9.8), (DOOR[1] - DOOR[0] + 0.3, 3.0, 2.4))
    crenellations(m["FortMerlons"], (DOOR[0], WY0 - 1.5, 0), (DOOR[1], WY0 - 1.5, 0), 11.0, 0.6, merlon=0.8, gap=0.5, depth=0.9)
    for k in range(9):
        x = DOOR[0] + 0.35 + k * (DOOR[1] - DOOR[0] - 0.7) / 8
        box(m["FortPortcullis"], (x, WY0 - 0.2, 8.9), (0.14, 0.14, 1.9))
        lathe(m["FortPortcullis"], [(0, 0), (0.1, 0), (0, -0.35)], 6, transform=Matrix.Translation((x, WY0 - 0.2, 7.95)))
    for z in (8.4, 9.4):
        box(m["FortPortcullis"], (mid, WY0 - 0.2, z), (DOOR[1] - DOOR[0] - 0.4, 0.12, 0.12))
    # The drawbridge: planks sloping from the threshold down across the moat, with chains.
    y_in, y_out = WY0 - 1.5, WY0 - 5.4
    for k in range(9):
        y = y_in - (y_in - y_out) * (k + 0.5) / 9
        z = 0.55 - 0.45 * (k + 0.5) / 9
        box(m["FortBridge"], (mid, y, z), (DOOR[1] - DOOR[0] - 0.2, (y_in - y_out) / 9 - 0.06, 0.22), Matrix.Rotation(math.radians(-5.5), 4, "X"))
    for x in (DOOR[0] + 0.3, DOOR[1] - 0.3):
        box(m["FortBridge"], (x, (y_in + y_out) / 2, 0.42), (0.25, y_in - y_out, 0.25), Matrix.Rotation(math.radians(-5.5), 4, "X"))
        links = wavy((x, WY0 - 1.55, 8.4), (x, y_out + 0.2, 0.4), 18, 0.0, sag=0.6)
        for k, p in enumerate(links):
            torus(m["FortChains"], p, (1, 0, 0) if k % 2 else (0, 0, 1), 0.14, 0.04, segments=8, minor_segments=3)
    # The painted moat along the back, with white waves.
    box(m["FortMoat"], (CX, WY0 - 3.6, 0.03), (WX1 - WX0 + 2 * TOWER_R + 1.0, 3.8, 0.06))
    for row in range(2):
        y = WY0 - 2.6 - row * 1.8
        wave = [Vector((WX0 - TOWER_R + 0.4 + k * 0.5, y + 0.18 * math.sin(k * 1.4), 0.08)) for k in range(int((WX1 - WX0 + 2 * TOWER_R) / 0.5))]
        wave = [p for p in wave if not (DOOR[0] - 0.2 < p.x < DOOR[1] + 0.2)]
        runs, run = [], []
        for p in wave:
            if run and (p - run[-1]).length > 0.8:
                runs.append(run)
                run = []
            run.append(p)
        runs.append(run)
        for r in runs:
            if len(r) > 1:
                sweep(m["FortWaves"], r, 0.06, segments=4)
    # A striped sentry box beside the gate.
    sx, sy = GATE[1] + 1.6, WY0 - 1.25
    for k in range(6):
        box(m["FortBaseBand" if k % 2 else "FortTowerTrim"], (sx, sy, 0.5 + k), (1.4, 1.4, 1.0))
    lathe(m["FortRoofs"], [(0, 6.0), (1.1, 6.0), (0, 7.4)], 4, transform=Matrix.Translation((sx, sy, 0)) @ Matrix.Rotation(math.pi / 4, 4, "Z"))
    box(m["FortSlits"], (sx, sy - 0.71, 2.4), (0.9, 0.04, 2.6))


def build_tent(m):
    """A striped tent canopy over the yard on a ridge pole, its poles standing in the end walls."""
    poles = m["FortPoles"]
    for y in (WY0, WY1):
        tube(poles, (CX, y, 0.0), (CX, y, RIDGE_Z + 0.9), 0.22, 10)
        ball(m["FortGold"], (CX, y, RIDGE_Z + 1.1), 0.3, subdivisions=2)
    tube(poles, (CX, WY0, RIDGE_Z), (CX, WY1, RIDGE_Z), 0.18, 10)
    count = 16
    for k in range(count):
        y0, y1 = WY0 + (WY1 - WY0) * k / count, WY0 + (WY1 - WY0) * (k + 1) / count
        mesh = m["FortCanvasRed" if k % 2 == 0 else "FortCanvasWhite"]
        for side, wx in ((-1, WX0), (1, WX1)):
            def canvas(u, v, y0=y0, y1=y1, wx=wx):
                x = wx + (CX - wx) * u
                z = WALL_H + 1.2 + (RIDGE_Z - WALL_H - 1.2) * u - 0.5 * math.sin(math.pi * u)
                return Vector((x, y0 + (y1 - y0) * v, z))
            grid_surface(mesh, canvas, 8, 2)
    for y in (WY0, WY1):
        for wx in (WX0, WX1):
            sweep(m["FortChains"], [Vector((CX, y, RIDGE_Z)), Vector((wx, y, WALL_H + 1.2))], 0.05, segments=4)


def build_floor(m):
    """A painted path from the gate to the batter's ground, and lane edging."""
    path = m["FortPath"]
    for k in range(7):
        t = k / 6
        p = Vector(((DOOR[0] + DOOR[1]) / 2, BACK_Y + 0.5, 0)).lerp(Vector((-3.6, -3.8, 0)), t)
        prism(path, [(p.x + 1.0 * math.cos(a), p.y + 0.8 * math.sin(a)) for a in [2 * math.pi * j / 10 for j in range(10)]], 0.0, 0.05)
    for x in (PITCH.x - 2.4, PITCH.x + 2.4):
        for k in range(8):
            y = 4.4 + k * 2.1
            box(m["FortBaseBand"], (x, y, 0.03), (0.22, 1.2, 0.06))
    home_plate(m["FortPlate"], 0.08)


# ---------- soldiers ----------

def toy_soldier(m, base, facing, scale=1.0, pitcher=False):
    """A tin soldier: blue trousers, red coat with white cross belts and gold buttons and epaulettes,
    a tall black bearskin with a gold plate, on a little green stand. pitcher holds his right hand
    out at PITCH; otherwise he stands on guard with his rifle shouldered."""
    b, f, s = Vector(base), Vector(facing).normalized(), scale
    side = f.cross(Vector((0, 0, 1))).normalized()

    def P(dx, dy, z):
        return b + side * dx * s + f * dy * s + Vector((0, 0, z * s))
    disc(m["FortStand"], P(0, 0, -0.12), (0, 0, 1), 1.05 * s, 0.24, segments=20)
    for dx in (-0.32, 0.32):
        lathe(m["FortTrousers"], [(0, 0), (0.26 * s, 0), (0.28 * s, 2.0 * s), (0, 2.05 * s)], 12, transform=Matrix.Translation(P(dx, 0, 0)))
        box(m["FortBlack"], P(dx, 0.08, 0.2), (0.5 * s, 0.7 * s, 0.4 * s), Matrix.Rotation(math.atan2(f.y, f.x) - math.pi / 2, 4, "Z"))
        box(m["FortCoat"], P(dx * 1.62, 0, 1.1), (0.04 * s + 0.02, 0.1 * s, 1.6 * s), Matrix.Rotation(math.atan2(f.y, f.x) - math.pi / 2, 4, "Z"))
    lathe(m["FortCoat"], [(0, 1.9), (0.66, 1.9), (0.72, 2.3), (0.64, 3.3), (0.56, 3.6), (0.3, 3.75), (0, 3.78)], 16,
          transform=Matrix.Translation(P(0, 0, 0)) @ Matrix.Diagonal((s, s, s, 1)))
    lathe(m["FortBelts"], [(0, 1.9), (0.7, 1.9), (0.7, 2.15), (0, 2.15)], 16, transform=Matrix.Translation(P(0, 0, 0)) @ Matrix.Diagonal((s, s, s, 1)))
    for sgn in (-1, 1):
        sweep(m["FortBelts"], [P(sgn * 0.5, 0.58, 3.55), P(-sgn * 0.45, 0.62, 2.25)], 0.07 * s, segments=4)
        disc(m["FortGold"], P(sgn * 0.72, 0, 3.6), (0, 0, 1), 0.3 * s, 0.12 * s, segments=12)
    for k in range(4):
        ball(m["FortGold"], P(0, 0.66, 2.45 + k * 0.32), 0.07 * s, subdivisions=1)
    ball(m["FortSkin"], P(0, 0, 4.2), 0.48 * s, subdivisions=2)
    lathe(m["FortBlack"], [(0, 4.35), (0.5, 4.35), (0.58, 4.9), (0.56, 5.6), (0.4, 5.9), (0, 5.95)], 14,
          transform=Matrix.Translation(P(0, 0, 0)) @ Matrix.Diagonal((s, s, s, 1)))
    disc(m["FortGold"], P(0, 0.5, 4.75), f, 0.2 * s, 0.05 * s, segments=10)
    sweep(m["FortGold"], [P(-0.45, 0.15, 4.35), P(0, 0.42, 3.92), P(0.45, 0.15, 4.35)], 0.04 * s, segments=4)
    for sgn in (-1, 1):
        ball(m["FortBlack"], P(sgn * 0.17, 0.43, 4.28), 0.06 * s, subdivisions=1)
        ball(m["FortCoat"], P(sgn * 0.3, 0.38, 4.08), 0.08 * s, subdivisions=1)
    # Arms.
    shoulder_l, shoulder_r = P(-0.82, 0, 3.4), P(0.82, 0, 3.4)
    if pitcher:
        hand = PITCH + Vector((0, 0.32, -0.3))
        elbow = shoulder_r.lerp(hand, 0.5) + Vector((0, 0, 0.1))
        sweep_radii(m["FortCoat"], [shoulder_r, elbow, hand + (shoulder_r - hand).normalized() * 0.3], [0.26 * s, 0.24 * s, 0.22 * s], segments=10)
        blob(m["FortSkin"], hand, Vector((0.3, 0.3, 0.2)) * s, subdivisions=2)
        hand_l = P(-1.0, 0.2, 2.2)
        sweep_radii(m["FortCoat"], [shoulder_l, P(-1.0, 0.1, 2.8), hand_l], [0.26 * s, 0.24 * s, 0.22 * s], segments=10)
        ball(m["FortSkin"], hand_l, 0.24 * s, subdivisions=2)
    else:
        hand_r = P(0.95, 0.35, 2.3)
        sweep_radii(m["FortCoat"], [shoulder_r, P(0.98, 0.15, 2.85), hand_r], [0.26 * s, 0.24 * s, 0.22 * s], segments=10)
        ball(m["FortSkin"], hand_r, 0.24 * s, subdivisions=2)
        sweep_radii(m["FortCoat"], [shoulder_l, P(-0.95, 0.35, 2.9), P(-0.95, 0.55, 3.4)], [0.26 * s, 0.24 * s, 0.22 * s], segments=10)
        ball(m["FortSkin"], P(-0.95, 0.6, 3.45), 0.24 * s, subdivisions=2)
        # The rifle, shouldered.
        butt, muzzle = P(-0.95, 0.75, 2.0), P(-0.95, 0.45, 6.3)
        extrude(m["FortRifleWood"], butt, butt.lerp(muzzle, 0.62), rrect(0.22 * s, 0.14 * s, 0.04), up=f)
        tube(m["FortSteel"], butt.lerp(muzzle, 0.6), muzzle, 0.06 * s, 6)
        lathe(m["FortSteel"], [(0, 0), (0.04 * s, 0), (0, 0.7 * s)], 6, transform=Matrix.Translation(muzzle) @ align_z(muzzle - butt))


def build_pitcher(m):
    """The big wind-up soldier on his stand; the key in his back turns (about Blender +Y)."""
    toy_soldier(m, SOLDIER, (0, -1, 0), scale=1.3, pitcher=True)
    disc(m["FortStand"], SOLDIER - Vector((0, 0, 0.3)), (0, 0, 1), 1.9, 0.5, segments=28)
    key = m["FortKey"]
    tube(key, KEY - Vector((0, 0.6, 0)), KEY + Vector((0, 0.35, 0)), 0.12, 10)
    disc(key, KEY + Vector((0, 0.4, 0)), (0, 1, 0), 0.22, 0.14, segments=14)
    for sx in (-1, 1):
        c = KEY + Vector((sx * 0.62, 0.45, 0))
        torus(key, c, (0, 1, 0), 0.42, 0.13, segments=18, minor_segments=6)
        disc(key, c, (0, 1, 0), 0.24, 0.1, segments=14)
    pitch_ball(m["FortBall"])


def build_screen(m):
    """A toy drum on its side as the screen: red shell, white heads with the window through both,
    blue hoops, gold zigzag cords and crossed sticks on top."""
    c = Vector((PITCH.x, SCREEN_Y, 2.85))
    r, half = 2.7, 0.7
    axis = Matrix.Translation(c - Vector((0, half, 0))) @ Matrix.Rotation(-math.pi / 2, 4, "X")
    lathe(m["FortDrum"], [(r - 0.12, 0.0), (r, 0.0), (r, 2 * half), (r - 0.12, 2 * half), (r - 0.12, 0.0)], 48, transform=axis)
    for y in (c.y - half, c.y + half):
        window_panel(m["FortDrumHeads"], lambda a: ray_ellipse((PITCH.x, PITCH.z), (math.cos(a), math.sin(a)), (c.x, c.z), r - 0.08, r - 0.08),
                     y, 0.06, segments=64)
        torus(m["FortDrumHoops"], (c.x, y, c.z), (0, 1, 0), r + 0.02, 0.17, segments=56, minor_segments=6)
    lathe(m["FortDrumHeads"], [(WINDOW + 0.06, 0.0), (WINDOW + 0.12, 0.0), (WINDOW + 0.12, 2 * half), (WINDOW + 0.06, 2 * half), (WINDOW + 0.06, 0.0)], 28,
          transform=Matrix.Translation((PITCH.x, c.y - half, PITCH.z)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
    for k in range(16):
        a0, a1 = 2 * math.pi * k / 16, 2 * math.pi * (k + 0.5) / 16
        p0 = Vector((c.x + math.cos(a0) * (r + 0.05), c.y - half + 0.1, c.z + math.sin(a0) * (r + 0.05)))
        p1 = Vector((c.x + math.cos(a1) * (r + 0.05), c.y + half - 0.1, c.z + math.sin(a1) * (r + 0.05)))
        p2 = Vector((c.x + math.cos(a0 + 2 * math.pi / 16) * (r + 0.05), c.y - half + 0.1, c.z + math.sin(a0 + 2 * math.pi / 16) * (r + 0.05)))
        sweep(m["FortDrumCords"], [p0, p1, p2], 0.05, segments=4)
    box(m["FortCarriage"], (c.x, c.y, 0.15), (5.0, 2.2, 0.3))
    for sx in (-1, 1):
        tube(m["FortRifleWood"], (c.x + sx * 1.6, c.y - 0.4, c.z + r + 0.15), (c.x - sx * 1.0, c.y + 0.4, c.z + r + 0.55), 0.09, 8)
        ball(m["FortTowerTrim"], (c.x - sx * 1.0, c.y + 0.4, c.z + r + 0.55), 0.17, subdivisions=2)


# ---------- inside: cannon, guards, blocks ----------

def cannon(m, base, facing):
    b, f = Vector(base), Vector(facing).normalized()
    side = f.cross(Vector((0, 0, 1))).normalized()
    turn = Matrix.Rotation(math.atan2(f.y, f.x), 4, "Z")
    box(m["FortCarriage"], b + Vector((0, 0, 0.9)), (2.6, 1.3, 0.8), turn)
    for sgn in (-1, 1):
        for dy in (-0.8, 0.8):
            p = b + side * sgn * 0.75 + f * dy + Vector((0, 0, 0.7))
            disc(m["FortWheels"], p, side, 0.7, 0.2, segments=16)
            disc(m["FortGold"], p + side * sgn * 0.12, side, 0.2, 0.08, segments=10)
    muzzle = b + f * 2.2 + Vector((0, 0, 2.2))
    breech = b - f * 1.0 + Vector((0, 0, 1.5))
    sweep_radii(m["FortCannon"], [breech, breech.lerp(muzzle, 0.5), muzzle], [0.55, 0.45, 0.4], segments=16)
    torus(m["FortGold"], muzzle, (muzzle - breech).normalized(), 0.45, 0.1, segments=16, minor_segments=5)
    torus(m["FortGold"], breech.lerp(muzzle, 0.3), (muzzle - breech).normalized(), 0.53, 0.07, segments=16, minor_segments=4)
    ball(m["FortCannon"], breech - (muzzle - breech).normalized() * 0.35, 0.35, subdivisions=2)
    for k, (dx, dy, dz) in enumerate(((0, 0, 0), (0.6, 0, 0), (0.3, 0.52, 0), (0.3, 0.17, 0.5))):
        ball(m["FortCannon"], b + side * (2.0 + dx) + f * dy + Vector((0, 0, 0.3 + dz)), 0.3, subdivisions=2)


def letter_block(m, centre, size, mesh, glyph):
    c = Vector(centre)
    box(m[mesh], c, (size, size, size))
    for face in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1)):
        n = Vector(face)
        p = c + n * (size / 2 + 0.01)
        # u runs to the viewer's right and v up, seen from outside the face.
        u = Vector((0, 0, 1)).cross(n) if abs(n.z) < 0.5 else Vector((1, 0, 0))
        u.normalize()
        v = n.cross(u).normalized() if abs(n.z) < 0.5 else Vector((0, 1, 0))
        w = size * 0.18
        if glyph == "A":
            strokes = [((-0.3, -0.35), (0, 0.35)), ((0, 0.35), (0.3, -0.35)), ((-0.15, 0.0), (0.15, 0.0))]
        elif glyph == "B":
            strokes = [((-0.25, -0.35), (-0.25, 0.35)), ((-0.25, 0.35), (0.2, 0.2)), ((0.2, 0.2), (-0.25, 0.0)), ((-0.25, 0.0), (0.25, -0.18)), ((0.25, -0.18), (-0.25, -0.35))]
        else:
            strokes = [((0.25, 0.3), (-0.2, 0.25)), ((-0.2, 0.25), (-0.28, 0.0)), ((-0.28, 0.0), (-0.2, -0.25)), ((-0.2, -0.25), (0.25, -0.3))]
        for (ax, ay), (bx, by) in strokes:
            a = p + u * ax * size + v * ay * size
            bb = p + u * bx * size + v * by * size
            d = (bb - a).normalized()
            s = d.cross(n).normalized() * w / 2
            slab(m["FortLetters"], [a - s, bb - s, bb + s, a + s], 0.03, n)


def build_inside(m):
    cannon(m, (10.6, 27.5, 0), (-0.3, -1, 0))
    for k in range(5):
        y = 3.0 + k * 5.2
        toy_soldier(m, (WX0 + 2.6, y, 0.12), (1, 0, 0), scale=0.85)
    for x in (DOOR[0] - 0.8, DOOR[1] + 0.8):
        toy_soldier(m, (x, WY0 + 1.6, 0.12), (0, 1, 0), scale=0.85)
    for (x, y, z, size, mesh, g) in ((11.2, 6.5, 0.8, 1.6, "FortBlocks", "A"), (12.6, 7.4, 0.8, 1.6, "FortBlocksRed", "B"), (11.9, 7.0, 2.4, 1.6, "FortBlocksBlue", "C"),
                                     (-12.0, 30.6, 0.7, 1.4, "FortBlocksRed", "A"), (11.8, 14.2, 0.6, 1.2, "FortBlocksBlue", "B")):
        letter_block(m, (x, y, z), size, mesh, g)
    for x, y in ((12.4, 20.0), (11.4, 21.2), (12.6, 22.4)):
        lathe(m["FortBarrels"], [(0, 0), (0.55, 0), (0.68, 0.7), (0.55, 1.4), (0, 1.4)], 14, transform=Matrix.Translation((x, y, 0)))
        for z in (0.25, 1.15):
            torus(m["FortSteel"], (x, y, z), (0, 0, 1), 0.6, 0.04, segments=14, minor_segments=3)
    for k in range(3):
        box(m["FortBridge"], (-12.6, 15.5 + k * 1.5, 0.6), (1.3, 1.3, 1.2), Matrix.Rotation(0.1 * k, 4, "Z"))
    # Soldiers on guard outside the front, between the corner towers.
    for k in range(6):
        toy_soldier(m, (CX - 10.0 + k * 4.0, WY1 + 2.4, 0.12), (0, 1, 0), scale=0.8)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = meshes(LOOKS)
    build_fort(m)
    build_gate(m)
    build_tent(m)
    build_floor(m)
    build_pitcher(m)
    build_screen(m)
    build_inside(m)
    objects = build_looks(coll, m, LOOKS)
    check_centred(objects, {"FortKey": (KEY, (0, 1, 0))})
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
