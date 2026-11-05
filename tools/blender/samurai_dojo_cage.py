# Training Ground 4 of World 2, Samurai Dojo: a batting cage built as a samurai training hall. A
# vermilion torii stands at every hoop (black-footed pillars, a tie beam and an upswept lintel), with
# paper shoji walls between them (lattice, paper and a slatted transom above). A curved hip-and-gable
# pagoda roof sweeps up at its corners, with tile ridges, rafter ends and golden fish on the ridge.
# Inside: a polished plank floor with tatami round the walls, a bamboo spring launcher whose cup holds
# the ball at PITCH, a gold folding screen painted with a crane, swaying paper lanterns, a weapon rack,
# a suit of armour, a taiko drum, a bonsai and hanging scrolls. Outside: a cherry tree dropping
# petals, stone lanterns, and a koi pond whose koi circle (with a rocking deer-scarer) by the left wall.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "SamuraiDojoCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\SamuraiDojoCage.fbx"

VERMILION = (0.86, 0.2, 0.12)
LACQUER = (0.08, 0.06, 0.06)
DARK_WOOD = (0.3, 0.2, 0.13)
FLOOR_WOOD = (0.66, 0.46, 0.28)
PAPER = (0.97, 0.95, 0.9)
TILE = (0.26, 0.28, 0.32)
TATAMI = (0.74, 0.72, 0.46)
BAMBOO = (0.66, 0.7, 0.36)
GOLD = (0.95, 0.75, 0.3)
STONE = (0.62, 0.62, 0.6)
BLOSSOM = (1.0, 0.72, 0.82)
BARK = (0.32, 0.22, 0.2)
WATER = (0.3, 0.55, 0.65)
INDIGO = (0.12, 0.16, 0.4)
rng = random.Random(64)

CX, CY = (LEFT_X + RIGHT_X) / 2, (BACK_Y + FRONT_Y) / 2
NUKI_Z, KASAGI_Z, PLATE_Z = 8.4, 10.8, 11.8
EAVE_Z, ROOF_H, ROOF_WX, ROOF_WY = 12.3, 8.0, 18.5, 27.5
POND = Vector((-19.6, 12.0, 0.0))
TREE = Vector((16.2, 40.6, 0.0))
LANTERN_SPOTS = ((-9.0, 2.0), (7.6, 2.0), (-9.0, 10.0), (7.6, 10.0), (-9.0, 18.0), (7.6, 18.0))

LOOKS = {
    "DojoTorii": (VERMILION, "smooth"), "DojoToriiBlack": (LACQUER, "hard"), "DojoLacquer": (LACQUER, "hard"),
    "DojoWoodDark": (DARK_WOOD, "hard"), "DojoLattice": (DARK_WOOD, "hard"), "DojoPaper": (PAPER, "hard"),
    "DojoRoof": (TILE, "soft"), "DojoRoofTiles": ((0.2, 0.22, 0.25), "smooth"), "DojoRoofTrim": (LACQUER, "smooth"),
    "DojoRafters": ((0.92, 0.9, 0.84), "hard"), "DojoGold": (GOLD, "smooth"),
    "DojoFloor": (FLOOR_WOOD, "hard"), "DojoTatami": (TATAMI, "hard"), "DojoTatamiEdge": (LACQUER, "hard"),
    "DojoBamboo": (BAMBOO, "smooth"), "DojoBambooNodes": ((0.5, 0.56, 0.26), "smooth"), "DojoRope": ((0.78, 0.66, 0.44), "smooth"),
    "DojoScreenGold": (GOLD, "hard"), "DojoCraneWhite": (WHITE, "soft"), "DojoInk": (LACQUER, "soft"), "DojoCraneRed": (VERMILION, "soft"),
    "DojoPine": ((0.2, 0.42, 0.26), "soft"), "DojoNoren": (INDIGO, "soft"),
    "DojoArmour": ((0.62, 0.1, 0.1), "smooth"), "DojoCords": ((0.9, 0.7, 0.2), "smooth"),
    "DojoDrum": ((0.48, 0.22, 0.12), "smooth"), "DojoDrumSkin": ((0.92, 0.86, 0.72), "smooth"),
    "DojoBonsai": ((0.24, 0.48, 0.24), "smooth"), "DojoScroll": (PAPER, "hard"),
    "DojoStone": (STONE, "hard"), "DojoLanternGlow": ((1.0, 0.86, 0.55), "hard"),
    "DojoBark": (BARK, "smooth"), "DojoBlossom": (BLOSSOM, "smooth"), "DojoBlossomLight": ((1.0, 0.86, 0.9), "smooth"),
    "DojoPetals": (BLOSSOM, "soft"), "DojoWater": (WATER, "hard"), "DojoPondBed": ((0.14, 0.18, 0.16), "hard"),
    "DojoLilyPads": ((0.3, 0.6, 0.3), "hard"), "DojoKoi": ((1.0, 0.45, 0.1), "smooth"), "DojoKoiWhite": (WHITE, "smooth"),
    "DojoShishi": (BAMBOO, "smooth"), "DojoBambooLeaves": ((0.4, 0.6, 0.24), "soft"), "DojoGravel": ((0.84, 0.82, 0.76), "hard"),
    "DojoGravelLines": ((0.74, 0.72, 0.66), "smooth"), "DojoPlate": (PAPER, "hard"), "DojoBall": (WHITE, "smooth"),
}
for letter in "ABCDEF":
    LOOKS["DojoLantern" + letter] = (VERMILION, "smooth")


# ---------- small builders ----------

def bamboo(m, points, radius, node_step=0.9):
    """A bamboo pole along a path, with a node ring every node_step."""
    line = Polyline(points)
    sweep(m["DojoBamboo"], line.samples(0.4), radius, segments=10)
    s = node_step / 2
    while s < line.length - 0.1:
        p = line.at(s)
        t = (line.at(min(line.length, s + 0.05)) - line.at(max(0.0, s - 0.05))).normalized()
        torus(m["DojoBambooNodes"], p, t, radius, radius * 0.18, segments=8, minor_segments=3)
        s += node_step


def turned(x, y, transform_angle):
    return Matrix.Translation((x, y, 0)) @ Matrix.Rotation(transform_angle, 4, "Z")


def stone_lantern(m, x, y, scale=1.0):
    """A stone lantern: base, post, a glowing fire box with an upswept roof and a jewel finial."""
    s = scale
    t = Matrix.Translation((x, y, 0))
    st = m["DojoStone"]
    lathe(st, [(0, 0), (0.75 * s, 0), (0.7 * s, 0.25 * s), (0.4 * s, 0.4 * s), (0, 0.4 * s)], 6, transform=t)
    lathe(st, [(0, 0.4 * s), (0.22 * s, 0.4 * s), (0.18 * s, 1.9 * s), (0, 1.9 * s)], 8, transform=t)
    lathe(st, [(0, 1.85 * s), (0.6 * s, 1.85 * s), (0.62 * s, 2.1 * s), (0, 2.1 * s)], 6, transform=t)
    box(m["DojoLanternGlow"], (x, y, 2.55 * s), (0.62 * s, 0.62 * s, 0.86 * s))
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        box(st, (x + math.cos(a) * 0.4 * s, y + math.sin(a) * 0.4 * s, 2.55 * s), (0.16 * s, 0.16 * s, 0.9 * s))
    lathe(st, [(0, 2.95 * s), (1.0 * s, 2.92 * s), (1.05 * s, 3.08 * s), (0.6 * s, 3.3 * s), (0.2 * s, 3.62 * s), (0, 3.65 * s)], 6, transform=t)
    for k in range(6):
        a = math.pi / 3 * k
        lathe(st, [(0, 0), (0.09 * s, 0), (0, 0.28 * s)], 5, transform=t @ Matrix.Translation((math.cos(a) * 1.0 * s, math.sin(a) * 1.0 * s, 3.0 * s)))
    ball(st, (x, y, 3.82 * s), 0.18 * s, subdivisions=1)
    lathe(st, [(0, 3.95 * s), (0.08 * s, 3.95 * s), (0, 4.15 * s)], 6, transform=t)


# ---------- the torii frame and shoji walls ----------

def torii(m, y):
    red, black = m["DojoTorii"], m["DojoToriiBlack"]
    for x in (LEFT_X, RIGHT_X):
        lathe(red, [(0, 0.8), (0.48, 0.8), (0.42, KASAGI_Z - 0.5), (0, KASAGI_Z - 0.5)], 16, transform=Matrix.Translation((x, y, 0)))
        lathe(black, [(0, 0), (0.62, 0), (0.62, 0.8), (0.5, 0.86), (0, 0.86)], 16, transform=Matrix.Translation((x, y, 0)))
        box(black, (x, y, KASAGI_Z - 0.45), (1.1, 1.1, 0.12))
    # The tie beam (nuki) through both pillars, and wedges where it passes through.
    box(red, (CX, y, NUKI_Z), (RIGHT_X - LEFT_X + 2.6, 0.44, 0.44))
    for x in (LEFT_X, RIGHT_X):
        for side in (-1, 1):
            box(black, (x + side * 0.6, y, NUKI_Z + 0.29), (0.16, 0.5, 0.12))
    # The central strut and the lintel (shimaki red, kasagi black on top) sweeping up at both ends.
    box(red, (CX, y, (NUKI_Z + KASAGI_Z) / 2), (0.7, 0.5, KASAGI_Z - NUKI_Z))
    half = (RIGHT_X - LEFT_X) / 2 + 2.1
    for mesh, z, depth, thick in ((red, KASAGI_Z, 0.8, 0.45), (black, KASAGI_Z + 0.42, 0.95, 0.4)):
        line = []
        for k in range(25):
            u = -1 + 2 * k / 24
            line.append(Vector((CX + half * u, y, z + 0.55 * abs(u) ** 3.5)))
        profile = [(-depth / 2, -thick / 2), (depth / 2, -thick / 2), (depth / 2, thick / 2), (-depth / 2, thick / 2)]
        sweep_profile(mesh, line, [(v, u) for u, v in profile])
    # A black plaque between the beams.
    box(black, (CX, y - 0.3, NUKI_Z + 1.2), (1.4, 0.08, 1.6))
    box(m["DojoGold"], (CX, y - 0.35, NUKI_Z + 1.2), (1.1, 0.04, 1.3))


def shoji(m, a, b, z0, z1, normal):
    """A shoji wall between a and b: a black frame, a dark lattice and paper behind it, with a
    slatted transom above up to the wall plate."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    along = (b - a).normalized()
    length = (b - a).length
    turn = Matrix.Rotation(math.atan2(along.y, along.x), 4, "Z")
    n = Vector(normal)
    mid = (a + b) / 2
    box(m["DojoPaper"], (mid.x, mid.y, (z0 + z1) / 2), (length, 0.06, z1 - z0), turn)
    lattice = m["DojoLattice"]
    count = max(1, round(length / 0.9))
    rows = max(1, round((z1 - z0) / 0.62))
    for face in (-1, 1):
        for k in range(count + 1):
            p = a + along * (length * k / count) + n * face * 0.06
            box(lattice, (p.x, p.y, (z0 + z1) / 2), (0.07, 0.07, z1 - z0), turn)
        for k in range(rows + 1):
            z = z0 + (z1 - z0) * k / rows
            c = mid + n * face * 0.06
            box(lattice, (c.x, c.y, z), (length, 0.07, 0.07), turn)
    for z, h in ((z0 - 0.15, 0.3), (z1 + 0.1, 0.2)):
        c = mid - n * 0.04
        box(m["DojoLacquer"], (c.x, c.y, z), (length, 0.22, h), turn)
    # The transom: dark slats above, under the wall plate.
    for k in range(int(length / 0.35)):
        p = a + along * (0.175 + k * 0.35)
        box(m["DojoWoodDark"], (p.x, p.y, (z1 + 0.3 + PLATE_Z) / 2), (0.1, 0.12, PLATE_Z - z1 - 0.3), turn)
    box(m["DojoWoodDark"], (mid.x, mid.y, PLATE_Z + 0.25), (length, 0.5, 0.5), turn)


def build_frame_and_walls(m):
    for y in HOOPS:
        torii(m, y)
    wall_top = NUKI_Z - 0.45
    for y0, y1 in zip(HOOPS, HOOPS[1:]):
        for x, normal in ((LEFT_X, (-1, 0, 0)), (RIGHT_X, (1, 0, 0))):
            shoji(m, (x, y0 + 0.55), (x, y1 - 0.55), 0.35, wall_top, normal)
    for x0, x1 in ((LEFT_X + 0.55, -6.0), (-6.0, 4.0), (4.0, RIGHT_X - 0.55)):
        shoji(m, (x0, FRONT_Y), (x1, FRONT_Y), 0.35, wall_top, (0, 1, 0))
    for x0, x1 in ((LEFT_X + 0.55, DOOR[0]), (DOOR[1], 2.0), (2.0, RIGHT_X - 0.55)):
        shoji(m, (x0, BACK_Y), (x1, BACK_Y), 0.35, wall_top, (0, -1, 0))
    # Over the door: the transom continues, and a split indigo curtain hangs in the doorway.
    mid = (DOOR[0] + DOOR[1]) / 2
    box(m["DojoLacquer"], (mid, BACK_Y, DOOR[2] + 0.1), (DOOR[1] - DOOR[0] + 0.3, 0.3, 0.3))
    for k in range(int((DOOR[1] - DOOR[0]) / 0.35)):
        box(m["DojoWoodDark"], (DOOR[0] + 0.175 + k * 0.35, BACK_Y, (DOOR[2] + 0.3 + PLATE_Z) / 2), (0.1, 0.12, PLATE_Z - DOOR[2] - 0.3))
    for x in (DOOR[0] - 0.12, DOOR[1] + 0.12):
        box(m["DojoLacquer"], (x, BACK_Y, DOOR[2] / 2), (0.22, 0.3, DOOR[2]))
    width = (DOOR[1] - DOOR[0] - 0.3) / 3
    for k in range(3):
        x0 = DOOR[0] + 0.15 + k * width + 0.04
        double_sided_poly(m["DojoNoren"], [Vector((x0, BACK_Y - 0.2, DOOR[2])), Vector((x0 + width - 0.08, BACK_Y - 0.2, DOOR[2])),
                                           Vector((x0 + width - 0.08, BACK_Y - 0.22, DOOR[2] - 1.3)), Vector((x0, BACK_Y - 0.22, DOOR[2] - 1.3))])
    tube(m["DojoWoodDark"], (DOOR[0], BACK_Y - 0.2, DOOR[2] + 0.02), (DOOR[1], BACK_Y - 0.2, DOOR[2] + 0.02), 0.05, 6)
    disc(m["DojoPaper"], (mid, BACK_Y - 0.24, DOOR[2] - 0.6), (0, 1, 0), 0.38, 0.02, segments=20)
    # The open sliding doors, pushed aside behind the right-hand wall.
    shoji(m, (DOOR[1] + 0.2, BACK_Y + 0.3), (DOOR[1] + 3.2, BACK_Y + 0.3), 0.35, DOOR[2] - 0.3, (0, -1, 0))
    # Wall plates on the corner posts.
    for x, y in ((LEFT_X, BACK_Y), (RIGHT_X, BACK_Y), (LEFT_X, FRONT_Y), (RIGHT_X, FRONT_Y)):
        box(m["DojoLacquer"], (x, y, PLATE_Z + 0.25), (0.6, 0.6, 0.6))


# ---------- the pagoda roof ----------

def roof_z(x, y):
    dx, dy = abs(x - CX), abs(y - CY)
    reach = min(ROOF_WX - dx, ROOF_WY - dy)
    s = max(0.0, reach / ROOF_WX)
    corner = (min(1.0, dx / ROOF_WX) ** 6) * (min(1.0, dy / ROOF_WY) ** 6)
    return EAVE_Z + ROOF_H * s ** 1.6 + 1.5 * corner ** 0.6


def build_roof(m):
    x0, x1, y0, y1 = CX - ROOF_WX, CX + ROOF_WX, CY - ROOF_WY, CY + ROOF_WY

    def surface(u, v):
        x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * v
        return Vector((x, y, roof_z(x, y)))
    grid_surface(m["DojoRoof"], surface, 48, 70)
    tiles_bm, trim = m["DojoRoofTiles"], m["DojoRoofTrim"]
    # Tile ridges running down the slopes: across the long sides they run in x, on the ends in y.
    for y in arange(y1 - y0 - 1.0, 1.25):
        y = y0 + 0.5 + y
        for side in (-1, 1):
            line = []
            for k in range(13):
                x = CX + side * ROOF_WX * (1 - k / 12)
                if ROOF_WX - abs(x - CX) > ROOF_WY - abs(y - CY) + 0.05:
                    break
                line.append(Vector((x, y, roof_z(x, y) + 0.1)))
            if len(line) > 1:
                sweep(tiles_bm, line, 0.13, segments=3)
    for x in arange(x1 - x0 - 1.0, 1.25):
        x = x0 + 0.5 + x
        for side in (-1, 1):
            line = []
            for k in range(13):
                y = CY + side * ROOF_WY * (1 - 0.68 * k / 12)
                if ROOF_WY - abs(y - CY) > ROOF_WX - abs(x - CX) + 0.05:
                    break
                line.append(Vector((x, y, roof_z(x, y) + 0.1)))
            if len(line) > 1:
                sweep(tiles_bm, line, 0.13, segments=3)
    # Ridge, hips and the eave fascia; golden fish (shachi) at both ends of the ridge.
    ridge_half = ROOF_WY - ROOF_WX
    ridge_z = EAVE_Z + ROOF_H
    box(trim, (CX, CY, ridge_z + 0.35), (0.9, 2 * ridge_half + 0.6, 0.8))
    box(m["DojoRafters"], (CX, CY, ridge_z + 0.82), (0.5, 2 * ridge_half + 0.4, 0.14))
    for sx in (-1, 1):
        for sy in (-1, 1):
            hip = []
            for k in range(17):
                t = k / 16
                x = CX + sx * ROOF_WX * t
                y = CY + sy * (ridge_half + ROOF_WX * t)
                hip.append(Vector((x, y, roof_z(x, y) + 0.3)))
            sweep(trim, hip, 0.28, segments=6)
            lathe(trim, [(0, 0), (0.35, 0), (0.0, 0.7)], 6, transform=Matrix.Translation(hip[-1]) @ align_z(Vector((sx * 0.5, sy * 0.5, 1))))
    edge = []
    for k in range(120):
        t = k / 120
        perimeter = 2 * (x1 - x0) + 2 * (y1 - y0)
        d = t * perimeter
        if d < x1 - x0:
            x, y = x0 + d, y0
        elif d < (x1 - x0) + (y1 - y0):
            x, y = x1, y0 + d - (x1 - x0)
        elif d < 2 * (x1 - x0) + (y1 - y0):
            x, y = x1 - (d - (x1 - x0) - (y1 - y0)), y1
        else:
            x, y = x0, y1 - (d - 2 * (x1 - x0) - (y1 - y0))
        edge.append(Vector((x, y, roof_z(x, y) - 0.05)))
    sweep(trim, edge + [edge[0]], 0.24, segments=6)
    # White rafter ends along the eaves.
    for k in range(0, 120, 2):
        p = edge[k]
        out = Vector((0 if x0 + 0.1 < p.x < x1 - 0.1 else (1 if p.x > CX else -1), 0 if y0 + 0.1 < p.y < y1 - 0.1 else (1 if p.y > CY else -1), 0))
        if out.length < 0.5:
            continue
        box(m["DojoRafters"], p - out.normalized() * 0.5 - Vector((0, 0, 0.3)), (0.22 if out.x == 0 else 1.0, 0.22 if out.y == 0 else 1.0, 0.22))
    for sy in (-1, 1):
        fish = Vector((CX, CY + sy * (ridge_half + 0.2), ridge_z + 1.0))
        blob(m["DojoGold"], fish, Vector((0.45, 0.6, 0.75)), subdivisions=2, seed=sy)
        sweep_radii(m["DojoGold"], [fish + Vector((0, 0, 0.5)), fish + Vector((0, -sy * 0.5, 1.3)), fish + Vector((0, -sy * 0.2, 1.9))], [0.32, 0.22, 0.08],
                    segments=8)
        for s in (-1, 1):
            double_sided_poly(m["DojoGold"], [fish + Vector((0, -sy * 0.1, 1.75)), fish + Vector((s * 0.6, -sy * 0.5, 2.2)), fish + Vector((0, -sy * 0.3, 2.05))])
    # Wall plates (keta) on top of the walls, carrying the roof.
    for x in (LEFT_X, RIGHT_X):
        box(m["DojoWoodDark"], (x, CY, PLATE_Z + 0.25), (0.6, FRONT_Y - BACK_Y + 0.6, 0.5))
    for y in (BACK_Y, FRONT_Y):
        box(m["DojoWoodDark"], (CX, y, PLATE_Z + 0.25), (RIGHT_X - LEFT_X + 0.6, 0.6, 0.5))


# ---------- floor ----------

def build_floor(m):
    floor = m["DojoFloor"]
    plank = 0.9
    for i in range(int((RIGHT_X - LEFT_X - 1.2) / plank)):
        x = LEFT_X + 0.6 + plank * (i + 0.5)
        y = BACK_Y + 0.3
        k = 0
        while y < FRONT_Y - 0.3:
            length = min(FRONT_Y - 0.3 - y, 3.6 + 1.2 * ((i * 7 + k) % 3))
            for a, b in ((y, y + length),):
                if -3.2 < x < 9.2 and b > -4.0 and a < 3.8:
                    # Leave the batter's ground (tatami turf and chalk) open.
                    parts = [(a, min(b, -4.0)), (max(a, 3.8), b)]
                else:
                    parts = [(a, b)]
                for p0, p1 in parts:
                    if p1 - p0 > 0.3:
                        box(floor, (x, (p0 + p1) / 2, 0.04), (plank - 0.05, p1 - p0 - 0.05, 0.08))
            y += length
            k += 1
    # Tatami along both walls, black-edged, and a black border round the batter's ground.
    for x0, x1 in ((LEFT_X + 0.6, LEFT_X + 3.6), (RIGHT_X - 3.6, RIGHT_X - 0.6)):
        for j in range(8):
            ya = BACK_Y + 3.0 + j * 4.2
            if ya + 4.0 > FRONT_Y - 0.5:
                break
            box(m["DojoTatami"], ((x0 + x1) / 2, ya + 2.0, 0.1), (x1 - x0 - 0.2, 3.9, 0.12))
            for x in (x0 + 0.06, x1 - 0.06):
                box(m["DojoTatamiEdge"], (x, ya + 2.0, 0.1), (0.14, 3.9, 0.13))
    for a, b in (((-3.3, -4.1), (9.3, -4.1)), ((-3.3, -4.1), (-3.3, 3.9)), ((9.3, -4.1), (9.3, 3.9)), ((-3.3, 3.9), (9.3, 3.9))):
        a3, b3 = Vector((a[0], a[1], 0.05)), Vector((b[0], b[1], 0.05))
        box(m["DojoTatamiEdge"], (a3 + b3) / 2, (abs(b3.x - a3.x) + 0.2, abs(b3.y - a3.y) + 0.2, 0.1))
    home_plate(m["DojoPlate"], 0.08)


# ---------- the bamboo launcher and the folding screen ----------

def build_launcher(m):
    x = PITCH.x
    # The cup: a wide cut bamboo section, open toward the batter, with the ball in its mouth.
    lathe(m["DojoBamboo"], [(0.48, 0.0), (0.56, 0.0), (0.56, 0.75), (0.0, 0.75), (0.0, 0.68), (0.48, 0.68), (0.48, 0.0)], 16,
          transform=Matrix.Translation((x, PITCH.y + 0.05, PITCH.z)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
    torus(m["DojoBambooNodes"], (x, PITCH.y + 0.05, PITCH.z), (0, 1, 0), 0.56, 0.06, segments=16, minor_segments=4)
    pitch_ball(m["DojoBall"])
    # The spring arm: a bent bamboo pole from the cup, over the pivot, down to its anchor.
    arm = [Vector((x, PITCH.y + 0.8, PITCH.z)), Vector((x, 26.4, 3.7)), Vector((x, 28.6, 3.75)), Vector((x, 30.6, 3.0)), Vector((x, 31.9, 1.6)),
           Vector((x, 32.4, 0.5))]
    bamboo(m, Polyline(arm).samples(0.35), 0.24, node_step=1.1)
    # Two A-frames carry a cross pole the arm is lashed over; a base frame and a stake hold it down.
    for sx in (-1, 1):
        for sy in (-1, 1):
            bamboo(m, [Vector((x + sx * 1.3, 26.6 + sy * 1.0, 0.0)), Vector((x + sx * 0.9, 26.6, 4.1))], 0.15, node_step=1.2)
    bamboo(m, [Vector((x - 1.4, 26.6, 4.0)), Vector((x + 1.4, 26.6, 4.0))], 0.13)
    for k in range(3):
        torus(m["DojoRope"], (x + (k - 1) * 0.12, 26.6, 3.92), (1, 0, 0), 0.3, 0.05, segments=12, minor_segments=4)
    for sx in (-1, 1):
        bamboo(m, [Vector((x + sx * 1.3, 25.2, 0.15)), Vector((x + sx * 1.3, 33.0, 0.15))], 0.14)
    for y in (25.6, 28.2, 32.6):
        bamboo(m, [Vector((x - 1.6, y, 0.32)), Vector((x + 1.6, y, 0.32))], 0.12)
    for k in range(4):
        torus(m["DojoRope"], (x, 32.35 + k * 0.08, 0.6), (0, 1, 0.4), 0.3, 0.05, segments=12, minor_segments=4)
    # The pull rope and a wooden toggle; a basket of spare balls.
    sweep(m["DojoRope"], wavy((x, 28.6, 3.75), (x + 1.7, 30.2, 0.4), 8, 0.0, sag=0.2), 0.04, segments=4)
    box(m["DojoWoodDark"], (x + 1.7, 30.2, 0.25), (0.5, 0.3, 0.5))
    lathe(m["DojoBamboo"], [(0, 0), (0.45, 0), (0.6, 0.5), (0.55, 0.5), (0, 0.06)], 14, transform=Matrix.Translation((x + 2.8, 27.6, 0)))
    for offset in ((0, 0, 0.42), (0.22, 0.1, 0.42), (-0.2, 0.12, 0.42), (0.02, -0.2, 0.42)):
        ball(m["DojoBall"], Vector((x + 2.8, 27.6, 0)) + Vector(offset), 0.2, subdivisions=2)


def panel_points(origin, along, width, z0, z1):
    o, a = Vector(origin), Vector(along)
    return [o + Vector((0, 0, z0)), o + a * width + Vector((0, 0, z0)), o + a * width + Vector((0, 0, z1)), o + Vector((0, 0, z1))]


def build_screen(m):
    """A six-fold gold screen: a flat middle panel with the window, two folded leaves each side, a
    crane in flight across the left leaves and a pine bough with a red sun on the right."""
    y, z0, z1 = SCREEN_Y, 0.4, 5.9
    gold, lacquer = m["DojoScreenGold"], m["DojoLacquer"]
    half = 1.45
    window_panel(gold, [(PITCH.x - half, z0), (PITCH.x + half, z0), (PITCH.x + half, z1), (PITCH.x - half, z1)], y, 0.12, segments=64)
    torus(lacquer, (PITCH.x, y - 0.07, PITCH.z), (0, 1, 0), WINDOW + 0.13, 0.07, segments=36, minor_segments=5)
    fold = math.radians(32)
    leaves = []
    for side in (-1, 1):
        start = Vector((PITCH.x + side * half, y, 0))
        for k in range(2):
            ang = fold if k == 0 else -fold
            along = Vector((side * math.cos(ang), math.sin(ang), 0))
            pts = panel_points(start, along, 1.4, z0, z1)
            slab(gold, pts, 0.1, along.cross(Vector((0, 0, 1))))
            leaves.append((side, k, start.copy(), along))
            start = start + along * 1.4
    # Black lacquer frames round every leaf, and little feet.
    frames = [(Vector((PITCH.x - half, y, 0)), Vector((1, 0, 0)), 2 * half)] + [(s, a, 1.4) for _, _, s, a in leaves]
    for start, along, width in frames:
        for z in (z0, z1):
            extrude(lacquer, start + Vector((0, 0, z)), start + along * width + Vector((0, 0, z)), rrect(0.14, 0.16, 0.03))
        for u in (0.0, width):
            p = start + along * u
            extrude(lacquer, p + Vector((0, 0, z0 - 0.4)), p + Vector((0, 0, z1 + 0.08)), rrect(0.14, 0.14, 0.03), up=(1, 0, 0))
    # Paint on the leaves' front faces (toward the batter).
    def on_leaf(index, a, b, lift=0.07):
        side, k, start, along = leaves[index]
        n = Vector((0, 0, 1)).cross(along).normalized()
        if n.y > 0:
            n = -n
        return start + along * a + Vector((0, 0, b)) + n * lift
    # The crane flies toward the window across the two left leaves: body, wings and trailing legs on
    # the outer leaf (index 1, measured outward from the fold), the neck and head on the inner leaf
    # (index 0, measured from the middle panel, the fold at 1.4).
    white, ink = m["DojoCraneWhite"], m["DojoInk"]
    body = [(0.25, 3.8), (0.55, 4.02), (0.95, 4.0), (1.12, 3.8), (0.9, 3.58), (0.4, 3.58)]
    double_sided_poly(white, [on_leaf(1, a, b) for a, b in body])
    for wing in ([(0.45, 3.95), (0.3, 4.6), (0.6, 5.35), (1.15, 5.45), (1.05, 4.7), (0.85, 3.98)],
                 [(0.45, 3.62), (0.35, 3.0), (0.65, 2.25), (1.15, 2.2), (1.0, 2.95), (0.85, 3.6)]):
        double_sided_poly(white, [on_leaf(1, a, b) for a, b in wing])
        tip = wing[2]
        double_sided_poly(ink, [on_leaf(1, a, b, 0.075) for a, b in (tip, (tip[0] - 0.1, tip[1] + (-0.3 if tip[1] > 4 else 0.3)), (tip[0] + 0.12, tip[1] + (-0.25 if tip[1] > 4 else 0.25)))])
    double_sided_poly(ink, [on_leaf(1, a, b, 0.075) for a, b in ((1.0, 3.84), (1.3, 3.95), (1.32, 3.66), (1.0, 3.66))])
    for k in range(2):
        double_sided_strip(ink, [on_leaf(1, 1.0, 3.68 - 0.05 * k, 0.075), on_leaf(1, 1.38, 3.3 - 0.1 * k, 0.075)],
                           [on_leaf(1, 1.0, 3.64 - 0.05 * k, 0.075), on_leaf(1, 1.38, 3.26 - 0.1 * k, 0.075)])
    # The neck crosses the fold to the inner leaf, the head held out toward the window.
    double_sided_strip(ink, [on_leaf(1, 0.4, 3.86, 0.075), on_leaf(1, 0.02, 3.98, 0.075)], [on_leaf(1, 0.4, 3.76, 0.075), on_leaf(1, 0.02, 3.88, 0.075)])
    double_sided_strip(ink, [on_leaf(0, 1.38, 3.98, 0.075), on_leaf(0, 0.95, 4.12, 0.075)], [on_leaf(0, 1.38, 3.88, 0.075), on_leaf(0, 0.95, 4.02, 0.075)])
    head = [on_leaf(0, 0.88 + 0.12 * math.cos(2 * math.pi * j / 8), 4.1 + 0.11 * math.sin(2 * math.pi * j / 8), 0.08) for j in range(8)]
    double_sided_poly(white, head)
    double_sided_poly(m["DojoCraneRed"], [on_leaf(0, 0.88 + 0.05 * math.cos(2 * math.pi * j / 6), 4.18 + 0.04 * math.sin(2 * math.pi * j / 6), 0.09) for j in range(6)])
    double_sided_poly(ink, [on_leaf(0, a, b, 0.085) for a, b in ((0.78, 4.12), (0.5, 4.06), (0.78, 4.06))])
    # Clouds in pale gold over the leaves and a red sun with a pine bough on the right (index 2, 3).
    for index, (a, b, r) in ((0, (0.6, 1.4, 0.4)), (1, (0.8, 1.2, 0.35)), (2, (0.7, 1.3, 0.38)), (3, (0.5, 4.9, 0.3))):
        for j in range(3):
            c = (a + (j - 1) * r * 0.9, b + 0.08 * j)
            double_sided_poly(m["DojoCraneWhite"], [on_leaf(index, c[0] + r * math.cos(2 * math.pi * q / 10), c[1] + r * 0.5 * math.sin(2 * math.pi * q / 10), 0.072)
                                                    for q in range(10)])
    double_sided_poly(m["DojoCraneRed"], [on_leaf(3, 0.75 + 0.5 * math.cos(2 * math.pi * q / 20), 4.4 + 0.5 * math.sin(2 * math.pi * q / 20)) for q in range(20)])
    bough = [(1.4, 2.6), (1.0, 3.0), (0.6, 3.1), (0.2, 3.5)]
    for (a0, b0), (a1, b1) in zip(bough, bough[1:]):
        double_sided_strip(m["DojoInk"], [on_leaf(2, a0, b0 - 0.06, 0.075), on_leaf(2, a1, b1 - 0.05, 0.075)],
                           [on_leaf(2, a0, b0 + 0.06, 0.075), on_leaf(2, a1, b1 + 0.05, 0.075)])
    for a, b in bough[1:]:
        for j in range(7):
            ang = math.pi * j / 6
            double_sided_poly(m["DojoPine"], [on_leaf(2, a, b, 0.078), on_leaf(2, a + 0.4 * math.cos(ang) - 0.03, b + 0.25 * math.sin(ang), 0.078),
                                              on_leaf(2, a + 0.4 * math.cos(ang) + 0.03, b + 0.25 * math.sin(ang) + 0.02, 0.078)])


# ---------- inside ----------

def paper_lantern(m, name, x, y):
    """A red paper lantern with black bands, hung from the tie beam."""
    lan = m[name]
    top = Vector((x, y, NUKI_Z - 0.32))
    tube(lan, top, top - Vector((0, 0, 0.8)), 0.025, 4)
    c = top - Vector((0, 0, 1.7))
    lathe(lan, [(0, -0.95), (0.3, -0.95), (0.5, -0.75), (0.62, -0.3), (0.64, 0.0), (0.62, 0.3), (0.5, 0.75), (0.3, 0.95), (0, 0.95)], 14,
          transform=Matrix.Translation(c))
    for z in (-0.95, 0.95):
        lathe(lan, [(0, z - 0.08), (0.34, z - 0.08), (0.34, z + 0.08), (0, z + 0.08)], 14, transform=Matrix.Translation(c))
    for k in range(5):
        z = -0.6 + 0.3 * k
        r = 0.64 * math.sqrt(max(0.0, 1 - (z / 1.05) ** 2)) + 0.012
        torus(lan, c + Vector((0, 0, z)), (0, 0, 1), r, 0.018, segments=14, minor_segments=3)
    tube(lan, c - Vector((0, 0, 1.0)), c - Vector((0, 0, 1.5)), 0.04, 4)


def katana(m, base, direction, length=3.0):
    b, d = Vector(base), Vector(direction).normalized()
    extrude(m["DojoLacquer"], b, b + d * length * 0.72, rrect(0.12, 0.07, 0.03), up=(0, 0, 1))
    disc(m["DojoGold"], b + d * length * 0.73, d, 0.13, 0.04, segments=10)
    extrude(m["DojoCords"], b + d * length * 0.74, b + d * length, rrect(0.09, 0.07, 0.03), up=(0, 0, 1))


def build_interior(m):
    for index, (x, y) in enumerate(LANTERN_SPOTS):
        paper_lantern(m, "DojoLantern" + "ABCDEF"[index], x, y)
    # The weapon rack on the left: three katana on a black stand, wooden bokken on a wall rack.
    lac = m["DojoLacquer"]
    for y in (12.6, 15.4):
        box(lac, (-14.0, y, 0.6), (0.9, 0.2, 1.2))
    for k, z in enumerate((0.55, 0.85, 1.15)):
        katana(m, (-13.95, 12.2, z), (0, 1, 0.02), 3.6)
    for k in range(5):
        y = 18.0 + k * 0.55
        extrude(m["DojoWoodDark"], (-15.2, y, 0.3), (-15.15, y, 3.6), rrect(0.12, 0.09, 0.03), up=(1, 0, 0))
    box(m["DojoWoodDark"], (-15.25, 19.1, 3.0), (0.2, 3.2, 0.18))
    # A suit of armour on a box by the left front corner.
    ax, ay = -13.4, 27.2
    box(lac, (ax, ay, 0.6), (1.4, 1.2, 1.2))
    lathe(m["DojoArmour"], [(0, 1.2), (0.55, 1.2), (0.62, 1.6), (0.58, 2.6), (0.42, 2.95), (0, 3.0)], 12, transform=Matrix.Translation((ax, ay, 0)))
    for k in range(5):
        torus(m["DojoCords"], (ax, ay, 1.35 + k * 0.32), (0, 0, 1), 0.6 - 0.02 * k, 0.03, segments=14, minor_segments=3)
    for s in (-1, 1):
        for k in range(3):
            box(m["DojoArmour"], (ax + s * 0.8, ay, 2.6 - k * 0.3), (0.5, 0.7, 0.28), Matrix.Rotation(s * 0.3, 4, "Y"))
    lathe(lac, [(0, 3.0), (0.52, 3.0), (0.5, 3.4), (0.3, 3.7), (0, 3.75)], 12, transform=Matrix.Translation((ax, ay, 0)))
    lathe(lac, [(0, 0), (0.75, 0), (0.7, 0.12), (0, 0.18)], 12, transform=Matrix.Translation((ax, ay, 3.0)))
    for s in (-1, 1):
        sweep_radii(m["DojoGold"], [Vector((ax, ay - 0.35, 3.55)), Vector((ax + s * 0.35, ay - 0.5, 3.95)), Vector((ax + s * 0.55, ay - 0.45, 4.5))],
                    [0.06, 0.05, 0.03], segments=6)
    # A taiko drum on its stand, two sticks resting on it.
    dx, dy = 11.4, 27.6
    lathe(m["DojoDrum"], [(0, -0.85), (0.95, -0.85), (1.12, -0.4), (1.16, 0.0), (1.12, 0.4), (0.95, 0.85), (0, 0.85)], 18,
          transform=Matrix.Translation((dx, dy, 1.9)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    for s in (-1, 1):
        disc(m["DojoDrumSkin"], (dx, dy + s * 0.86, 1.9), (0, 1, 0), 0.94, 0.03, segments=18)
        for k in range(16):
            a = 2 * math.pi * k / 16
            ball(m["DojoGold"], (dx + math.cos(a) * 0.9, dy + s * 0.84, 1.9 + math.sin(a) * 0.9), 0.04, subdivisions=1)
        box(m["DojoLacquer"], (dx + s * 0.75, dy, 0.6), (0.18, 1.8, 1.2))
    box(m["DojoLacquer"], (dx, dy, 0.1), (1.8, 2.0, 0.2))
    for s in (-1, 1):
        tube(m["DojoWoodDark"], (dx - 0.4, dy - 0.95, 2.9 + s * 0.05), (dx + 0.4 + s * 0.2, dy - 0.95, 2.95), 0.05, 6)
    # A bonsai on a low table, and hanging scrolls on the front wall.
    box(m["DojoLacquer"], (12.0, 9.8, 0.5), (1.4, 2.0, 0.12))
    for x in (11.5, 12.5):
        for y in (9.0, 10.6):
            box(m["DojoLacquer"], (x, y, 0.22), (0.12, 0.12, 0.44))
    lathe(m["DojoStone"], [(0, 0.56), (0.42, 0.56), (0.48, 0.78), (0.0, 0.78)], 10, transform=Matrix.Translation((12.0, 9.8, 0)))
    sweep_radii(m["DojoBark"], [Vector((12.0, 9.8, 0.75)), Vector((12.25, 9.6, 1.2)), Vector((11.8, 9.9, 1.55)), Vector((12.3, 10.2, 1.85))],
                [0.09, 0.07, 0.05, 0.03], segments=6)
    for p, s in ((Vector((12.35, 9.5, 1.3)), 0.32), (Vector((11.7, 10.0, 1.65)), 0.36), (Vector((12.35, 10.25, 1.95)), 0.3)):
        blob(m["DojoBonsai"], p, Vector((s, s, s * 0.55)), subdivisions=2, lump=0.3, seed=p.x)
    for x in (-8.5, 9.5):
        box(m["DojoScroll"], (x, FRONT_Y - 0.25, 5.2), (1.3, 0.04, 4.0))
        for z in (3.15, 7.25):
            cylinder_x(m["DojoWoodDark"], (x, FRONT_Y - 0.28, z), 1.6, 0.07, 8)
        for k in range(4):
            z = 6.4 - k * 0.85
            double_sided_strip(m["DojoInk"], [Vector((x - 0.35, FRONT_Y - 0.3, z)), Vector((x + 0.3, FRONT_Y - 0.3, z - 0.15 * (k % 2)))],
                               [Vector((x - 0.32, FRONT_Y - 0.3, z - 0.12)), Vector((x + 0.33, FRONT_Y - 0.3, z - 0.1 - 0.15 * (k % 2)))])
            double_sided_strip(m["DojoInk"], [Vector((x + 0.05 * (k % 2), FRONT_Y - 0.3, z + 0.2)), Vector((x - 0.1, FRONT_Y - 0.3, z - 0.45))],
                               [Vector((x + 0.15 + 0.05 * (k % 2), FRONT_Y - 0.3, z + 0.2)), Vector((x, FRONT_Y - 0.3, z - 0.45))])


# ---------- outside: cherry tree, lanterns, koi pond ----------

def build_tree(m):
    bark = m["DojoBark"]
    b = TREE
    trunk = [b, b + Vector((-0.3, -0.2, 2.0)), b + Vector((0.2, -0.6, 3.8)), b + Vector((-0.4, -0.9, 5.4))]
    sweep_radii(bark, trunk, [0.75, 0.6, 0.45, 0.35], segments=10)
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        root = b + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.35))
        sweep_radii(bark, [root, root + Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, -0.35))], [0.3, 0.1], segments=6)
    tips = []
    for k, (a, rise, reach) in enumerate(((0.3, 2.4, 3.2), (1.6, 2.0, 3.4), (2.9, 2.8, 2.8), (4.2, 1.8, 3.0), (5.3, 2.6, 2.6))):
        start = trunk[-1] - Vector((0, 0, 0.6 * (k % 2)))
        tip = start + Vector((math.cos(a) * reach, math.sin(a) * reach * 0.9, rise))
        tip.x = min(tip.x, 19.0)
        sweep_radii(bark, [start, start.lerp(tip, 0.5) + Vector((0, 0, 0.5)), tip], [0.32, 0.2, 0.1], segments=8)
        tips.append(tip)
    for tip in tips + [trunk[-1] + Vector((0, 0, 2.6))]:
        for j in range(4):
            off = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 0.7))).normalized() * 1.3 * (j > 0)
            c = tip + off
            c.x = min(c.x, 19.2)
            s = rng.uniform(1.2, 1.7)
            blob(m["DojoBlossom" if j % 2 == 0 else "DojoBlossomLight"], c, Vector((s, s, s * 0.8)), subdivisions=2, lump=0.3, lump_scale=2.2, seed=rng.random() * 9)
    for _ in range(160):
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0.5, 5.0)
        p = b + Vector((math.cos(a) * r, math.sin(a) * r, 0.03))
        if p.x > 20.6 or p.x < 12.0:
            continue
        spin = rng.uniform(0, math.pi)
        double_sided_poly(m["DojoPetals"], [p + Vector((math.cos(spin + q * 2.1) * 0.13, math.sin(spin + q * 2.1) * 0.13, 0)) for q in range(3)])


def build_pond(m):
    c = POND
    rx, ry = 2.45, 6.8

    def outline(k, count, scale=1.0):
        a = 2 * math.pi * k / count
        wobble = 1 + 0.08 * math.sin(3 * a) + 0.05 * math.cos(5 * a)
        return Vector((c.x + rx * scale * wobble * math.cos(a), c.y + ry * scale * wobble * math.sin(a), 0))
    rim = [outline(k, 40) for k in range(40)]
    prism(m["DojoPondBed"], [(p.x, p.y) for p in rim], 0.0, 0.05)
    prism(m["DojoWater"], [(p.x, p.y) for p in [outline(k, 40, 0.97) for k in range(40)]], 0.25, 0.32)
    for k in range(40):
        p = outline(k, 40, 1.08)
        rough_rock(m["DojoStone"], p + Vector((0, 0, 0.25)), Vector((0.55, 0.55, 0.38)) * rng.uniform(0.8, 1.25), rng, subdivisions=1, jitter=0.2, floor=0.0)
    for k, (dx, dy, r) in enumerate(((0.9, -3.5, 0.45), (-0.8, 2.4, 0.5), (1.1, 4.6, 0.38), (-1.0, -1.6, 0.42))):
        p = c + Vector((dx, dy, 0.34))
        disc(m["DojoLilyPads"], p, (0, 0, 1), r, 0.04, segments=12)
        if k % 2 == 0:
            for j in range(6):
                a = 2 * math.pi * j / 6
                leaf(m["DojoPetals"], p + Vector((0, 0, 0.04)), (math.cos(a), math.sin(a), 0.8), (-math.sin(a), math.cos(a), 0), 0.28, 0.18)
    # Four koi circling the middle of the pond (one spinning mesh, four-fold symmetric), and their
    # white patches in a second mesh turning with them.
    for k in range(4):
        a = math.pi / 2 * k
        centre = c + Vector((math.cos(a) * 1.6, math.sin(a) * 1.6, 0.2))
        heading = Vector((-math.sin(a), math.cos(a), 0))
        side = Vector((math.cos(a), math.sin(a), 0))
        start = len(m["DojoKoi"].verts)
        lathe(m["DojoKoi"], [(0, -0.55), (0.12, -0.42), (0.2, -0.1), (0.18, 0.25), (0.08, 0.5), (0, 0.55)], 10,
              transform=Matrix.Translation(centre) @ align_z(heading))
        slab(m["DojoKoi"], [centre - heading * 0.5, centre - heading * 0.85 + side * 0.22, centre - heading * 0.85 - side * 0.22], 0.04, Vector((0, 0, 1)))
        blob(m["DojoKoiWhite"], centre + heading * 0.15 + Vector((0, 0, 0.12)), Vector((0.14, 0.14, 0.06)), subdivisions=1)
        blob(m["DojoKoiWhite"], centre - heading * 0.2 + Vector((0, 0, 0.13)), Vector((0.12, 0.12, 0.05)), subdivisions=1)
    # A deer-scarer: a bamboo spout pours into a rocking bamboo tube over a stone basin.
    bx, by = c.x + 0.6, c.y + ry + 0.9
    box(m["DojoStone"], (bx, by, 0.3), (1.2, 1.0, 0.6))
    for sx in (-1, 1):
        bamboo(m, [Vector((bx + sx * 0.45, by, 0.0)), Vector((bx + sx * 0.45, by, 1.3))], 0.07)
    bamboo(m, [Vector((bx - 0.5, by, 1.15)), Vector((bx + 0.5, by, 1.15))], 0.05)
    for p in ([Vector((bx, by - 0.9, 1.4)), Vector((bx, by + 0.6, 1.7))],):
        sweep_radii(m["DojoShishi"], [p[0], p[1]], [0.11, 0.11], segments=10)
    bamboo(m, [Vector((bx - 0.2, by + 1.4, 0.0)), Vector((bx - 0.2, by + 1.4, 2.2)), Vector((bx - 0.1, by + 0.7, 2.1))], 0.09)
    stone_lantern(m, c.x + 1.6, c.y - ry - 0.8, 0.85)


def build_outside(m):
    build_tree(m)
    build_pond(m)
    for x, y, s in ((DOOR[0] - 2.4, BACK_Y - 2.6, 1.0), (DOOR[1] + 2.4, BACK_Y - 2.6, 1.0), (18.6, -6.0, 0.9), (18.6, 14.0, 0.9),
                    (18.6, 26.0, 0.9), (-19.2, 30.0, 0.9), (-6.0, 39.4, 1.1), (4.0, 39.4, 1.1)):
        stone_lantern(m, x, y, s)
    # Two bamboo groves, and a raked gravel garden with three mossy rocks.
    for gx, gy, count in ((-19.6, -9.0, 11), (18.6, 33.0, 9)):
        for k in range(count):
            a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0.2, 1.6)
            base = Vector((gx + math.cos(a) * r * 0.6, gy + math.sin(a) * r * 1.8, 0))
            height = rng.uniform(9.0, 13.0)
            lean = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.6, 0.6), 0))
            top = base + lean + Vector((0, 0, height))
            bamboo(m, [base, base.lerp(top, 0.5) + lean * 0.2, top], rng.uniform(0.11, 0.16), node_step=1.3)
            for j in range(6):
                p = base.lerp(top, rng.uniform(0.55, 0.98))
                for q in range(4):
                    ang = rng.uniform(0, 2 * math.pi)
                    leaf(m["DojoBambooLeaves"], p, (math.cos(ang), math.sin(ang), -0.35), (-math.sin(ang), math.cos(ang), 0.2), rng.uniform(0.7, 1.0), 0.16)
    gx0, gx1, gy0, gy1 = 15.6, 20.6, -13.0, -2.0
    box(m["DojoGravel"], ((gx0 + gx1) / 2, (gy0 + gy1) / 2, 0.06), (gx1 - gx0, gy1 - gy0, 0.12))
    for x0, x1, y0, y1 in ((gx0, gx1, gy0, gy0), (gx0, gx1, gy1, gy1), (gx0, gx0, gy0, gy1), (gx1, gx1, gy0, gy1)):
        box(m["DojoStone"], ((x0 + x1) / 2, (y0 + y1) / 2, 0.12), (abs(x1 - x0) + 0.3, abs(y1 - y0) + 0.3, 0.24))
    rocks = ((17.4, -10.4, 0.9), (19.2, -6.6, 0.65), (17.0, -4.2, 0.5))
    for rx_, ry_, s in rocks:
        rough_rock(m["DojoStone"], (rx_, ry_, 0.4 * s), Vector((0.9, 0.8, 0.75)) * s, rng, subdivisions=2, jitter=0.15, floor=0.1)
        blob(m["DojoBonsai"], Vector((rx_, ry_, 0.7 * s + 0.3)), Vector((0.55, 0.5, 0.18)) * s, subdivisions=2, lump=0.3, seed=rx_)
        for r in (1.2, 1.55, 1.9):
            ring = [Vector((rx_ + r * s * math.cos(2 * math.pi * q / 24), ry_ + r * s * math.sin(2 * math.pi * q / 24), 0.13)) for q in range(25)]
            ring = [p for p in ring if gx0 + 0.15 < p.x < gx1 - 0.15 and gy0 + 0.15 < p.y < gy1 - 0.15]
            if len(ring) > 2:
                sweep(m["DojoGravelLines"], ring, 0.035, segments=3)
    for k in range(9):
        y = gy0 + 0.6 + k * 1.2
        line = [Vector((gx0 + 0.2 + (gx1 - gx0 - 0.4) * q / 10, y, 0.13)) for q in range(11)]
        line = [p for p in line if all((p - Vector((rx_, ry_, 0.13))).length > 2.0 * s for rx_, ry_, s in rocks)]
        if len(line) > 1:
            sweep(m["DojoGravelLines"], line, 0.035, segments=3)
    # Stepping stones from the door.
    for k in range(5):
        p = Vector(((DOOR[0] + DOOR[1]) / 2 + (0.4 if k % 2 else -0.4), BACK_Y - 1.4 - k * 1.2, 0))
        prism(m["DojoStone"], [(p.x + math.cos(2 * math.pi * q / 8) * 0.55, p.y + math.sin(2 * math.pi * q / 8) * 0.45) for q in range(8)], 0.0, 0.1)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = meshes(LOOKS)
    build_frame_and_walls(m)
    build_roof(m)
    build_floor(m)
    build_launcher(m)
    build_screen(m)
    build_interior(m)
    build_outside(m)
    for name in ("DojoCraneWhite", "DojoInk", "DojoCraneRed", "DojoPetals", "DojoPine", "DojoNoren", "DojoBambooLeaves"):
        bmesh.ops.triangulate(m[name], faces=m[name].faces[:])
    objects = build_looks(coll, m, LOOKS)
    check_centred(objects, {"DojoKoi": (POND, (0, 0, 1)), "DojoKoiWhite": (POND, (0, 0, 1))})
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
