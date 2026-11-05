# Training Ground 2 of World 2, Pharaoh's Tomb: a batting cage in a pharaoh's burial hall. Square
# sandstone pillars carved with painted hieroglyph columns under lotus capitals, a painted cavetto
# cornice all round, sandstone block walls with a coloured frieze and a linen net above, and a
# pyramid-shaped roof frame netted in linen with a gold capstone. The door is a pylon gateway with a
# winged sun over it. The floor is limestone tiles over gold (so every joint shines) with a lapis lane
# and gold ankh inlays. An upright sarcophagus stands at the machine end with its painted lid swung
# open on its hinge, and the mummy inside holds the ball out at PITCH. In front of it is a gold scarab
# screen pushing a turning sun disc. Inside are torches, treasure, chests, canopic jars and a cat
# statue, and outside a sphinx, four obelisks and swinging incense burners.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "PharaohsTombCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\PharaohsTombCage.fbx"

SANDSTONE = (0.86, 0.74, 0.54)
BLOCKS = (0.8, 0.68, 0.48)
LIMESTONE = (0.93, 0.9, 0.82)
GOLD = (1.0, 0.76, 0.22)
LAPIS = (0.1, 0.24, 0.66)
TURQUOISE = (0.16, 0.66, 0.66)
RED = (0.72, 0.18, 0.12)
LINEN = (0.93, 0.88, 0.76)
DARK = (0.07, 0.06, 0.06)
FLAME = (1.0, 0.6, 0.16)
rng = random.Random(29)

CX, CY = (LEFT_X + RIGHT_X) / 2, (BACK_Y + FRONT_Y) / 2
DADO = 3.0                                    # top of the block walls
ARCH_Z, ROOF_Z = 11.0, 12.4                   # architrave bottom and top (the pyramid sits on top)
ROOF_X, ROOF_Y = (LEFT_X - 0.6, RIGHT_X + 0.6), (BACK_Y - 0.6, FRONT_Y + 0.6)
APEX = Vector((CX, CY, 25.0))
PYLONS = ((-16.4, -13.4), (-6.6, -3.6))       # gateway towers either side of the door
COFFIN = Vector((PITCH.x, 24.9, 0.5))         # the sarcophagus case: its rim plane and its plinth top
HINGE = Vector((PITCH.x + 1.42, 24.9, 0.0))
LID_OPEN = math.radians(118)          # swung toward the right, clear of the pitch
SUN = Vector((PITCH.x, SCREEN_Y - 0.12, 7.9))

LOOKS = {
    "TombSandstone": (SANDSTONE, "hard"), "TombBlocks": (BLOCKS, "hard"), "TombPylons": (SANDSTONE, "hard"),
    "TombPaintBlue": (LAPIS, "hard"), "TombPaintRed": (RED, "hard"), "TombPaintTeal": (TURQUOISE, "hard"),
    "TombGold": (GOLD, "hard"), "TombGlyphs": (LAPIS, "hard"), "TombGlyphsOuter": (LAPIS, "hard"), "TombObeliskGlyphs": (LAPIS, "hard"),
    "TombNet": (LINEN, "soft"), "TombNetRoof": (LINEN, "soft"), "TombNetRoofEnds": (LINEN, "soft"), "TombRoofFrame": (GOLD, "hard"), "TombRoofCap": (GOLD, "hard"),
    "TombFloor": (LIMESTONE, "hard"), "TombFloorGold": (GOLD, "hard"), "TombLapis": (LAPIS, "hard"),
    "TombScarab": (GOLD, "hard"), "TombScarabInlay": (LAPIS, "hard"), "TombSunDisc": (RED, "smooth"),
    "TombCoffin": (GOLD, "soft"), "TombCoffinInside": (DARK, "soft"), "TombCoffinPaint": (LAPIS, "hard"), "TombLidSky": (LAPIS, "soft"),
    "TombMummy": (LINEN, "smooth"), "TombMummyWraps": ((0.78, 0.72, 0.6), "smooth"), "TombEyes": ((0.4, 1.0, 0.5), "smooth"),
    "TombPlate": (LIMESTONE, "hard"), "TombBall": (WHITE, "smooth"), "TombFlames": (FLAME, "smooth"),
    "TombChest": ((0.42, 0.26, 0.14), "hard"), "TombCoins": (GOLD, "smooth"), "TombGems": ((0.9, 0.1, 0.2), "hard"),
    "TombJars": ((0.94, 0.9, 0.8), "smooth"), "TombObsidian": ((0.06, 0.06, 0.08), "smooth"),
    "TombSphinx": (SANDSTONE, "smooth"), "TombObelisks": ((0.9, 0.79, 0.6), "hard"),
    "TombCenserA": (GOLD, "smooth"), "TombCenserB": (GOLD, "smooth"),
}


# ---------- small builders ----------

def face_poly(bm, origin, u, v, n, points, thickness=0.05, lift=0.0):
    """A raised flat shape on a face: points are (a, b) along u and v from origin."""
    o, u, v, n = Vector(origin), Vector(u), Vector(v), Vector(n)
    slab(bm, [o + u * a + v * b + n * (lift + thickness / 2) for a, b in points], thickness, n)


def ellipse(cx, cy, rx, ry, count=10, a0=0.0, a1=2 * math.pi):
    return [(cx + rx * math.cos(a0 + (a1 - a0) * k / count), cy + ry * math.sin(a0 + (a1 - a0) * k / count)) for k in range(count)]


def bar(a, b, width):
    """A quad strip from a to b (2D)."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    s = Vector((-d.y, d.x)) * width / 2
    return [tuple(a - s), tuple(b - s), tuple(b + s), tuple(a + s)]


def glyph(bm, center, u, v, n, size, kind):
    """One painted hieroglyph, raised from a face; size is its height."""
    c = Vector(center)
    o = c
    s = size

    def put(points, t=0.04):
        face_poly(bm, o, u, v, n, [(x * s, y * s) for x, y in points], thickness=t)
    if kind == "ankh":
        torus(bm, c + Vector(v) * 0.24 * s + Vector(n) * 0.03, n, 0.15 * s, 0.045 * s, segments=10, minor_segments=3)
        put(bar((-0.24, 0.04), (0.24, 0.04), 0.08))
        put(bar((0, 0.06), (0, -0.48), 0.09))
    elif kind == "eye":
        put(ellipse(0, 0.1, 0.32, 0.12, 12))
        put(bar((-0.32, 0.24), (0.34, 0.26), 0.05))
        put(bar((0.0, 0.0), (0.0, -0.4), 0.06))
        put(bar((-0.1, -0.02), (-0.3, -0.38), 0.05))
    elif kind == "bird":
        put(ellipse(-0.02, -0.02, 0.28, 0.17, 10))
        put(ellipse(0.2, 0.24, 0.1, 0.1, 8))
        put([(0.28, 0.27), (0.44, 0.2), (0.28, 0.2)])
        put([(-0.25, 0.0), (-0.46, -0.2), (-0.2, -0.12)])
        put(bar((0.0, -0.15), (0.02, -0.48), 0.04))
        put(bar((0.1, -0.15), (0.14, -0.48), 0.04))
    elif kind == "water":
        points = [(-0.4 + 0.8 * k / 6, 0.06 * (1 if k % 2 else -1)) for k in range(7)]
        for a, b in zip(points, points[1:]):
            put(bar(a, b, 0.07))
    elif kind == "reed":
        put([(0.0, -0.48), (0.1, -0.2), (0.12, 0.15), (0.05, 0.45), (-0.04, 0.2), (-0.08, -0.2)])
    elif kind == "sun":
        put(ellipse(0, 0, 0.26, 0.26, 12))
        torus(bm, c + Vector(n) * 0.03, n, 0.36 * s, 0.03 * s, segments=12, minor_segments=3)
    elif kind == "snake":
        points = [(-0.36 + 0.72 * k / 8, 0.14 * math.sin(k * 1.3)) for k in range(9)]
        for a, b in zip(points, points[1:]):
            put(bar(a, b, 0.07))
        put(ellipse(0.4, 0.1, 0.07, 0.09, 6))
    else:
        put(ellipse(0, 0, 0.1, 0.45, 10))
        put(bar((0, -0.45), (0, 0.4), 0.025), t=0.06)


KINDS = ("ankh", "eye", "bird", "water", "reed", "sun", "snake", "feather")


def glyph_column(m, mesh, origin, u, v, n, height, width, seed, gold=True, spacing=1.05):
    """A vertical column of hieroglyphs in a gold-framed cartouche on a flat face."""
    r = random.Random(seed)
    o, u, v, n = Vector(origin), Vector(u), Vector(v), Vector(n)
    if gold:
        for a, b in (((-width / 2, 0), (-width / 2, height)), ((width / 2, 0), (width / 2, height)),
                     ((-width / 2, 0), (width / 2, 0)), ((-width / 2, height), (width / 2, height))):
            face_poly(m["TombGold"], o, u, v, n, bar(a, b, 0.07), thickness=0.05)
    count = max(1, int(height / (width * spacing)))
    step = height / count
    for k in range(count):
        glyph(mesh, o + v * (step * (k + 0.5)), u, v, n, width * 0.78, r.choice(KINDS))


def pyramid(bm, base_center, wx, wy, height):
    c = Vector(base_center)
    corners = [bm.verts.new(c + Vector((sx * wx / 2, sy * wy / 2, 0))) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    top = bm.verts.new(c + Vector((0, 0, height)))
    bm.faces.new(tuple(reversed(corners)))
    for i in range(4):
        bm.faces.new((corners[i], corners[(i + 1) % 4], top))


def hexahedron(bm, bottom, top):
    """A solid from a bottom and a top quad (four corners each, same winding): battered towers."""
    b = [bm.verts.new(p) for p in bottom]
    t = [bm.verts.new(p) for p in top]
    bm.faces.new(tuple(reversed(b)))
    bm.faces.new(tuple(t))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((b[i], b[j], t[j], t[i]))


def cavetto(bm, a, b, width, z, lip=0.45):
    """The Egyptian gorge cornice: a beam whose top flares outward on both sides."""
    profile = [(-width / 2, 0.0), (width / 2, 0.0), (width / 2, 0.55), (width / 2 + lip * 0.75, 1.05), (width / 2 + lip, 1.3),
               (-width / 2 - lip, 1.3), (-width / 2 - lip * 0.75, 1.05), (-width / 2, 0.55)]
    a, b = Vector(a) + Vector((0, 0, z)), Vector(b) + Vector((0, 0, z))
    d = (b - a).normalized()
    side = Vector((0, 0, 1)).cross(d)
    rings = [[bm.verts.new(p + side * pu + Vector((0, 0, pv))) for pu, pv in profile] for p in (a, b)]
    for k in range(len(profile)):
        j = (k + 1) % len(profile)
        bm.faces.new((rings[0][k], rings[0][j], rings[1][j], rings[1][k]))
    bm.faces.new(tuple(reversed(rings[0])))
    bm.faces.new(tuple(rings[1]))


def flame(bm, base, height, radius):
    lathe(bm, [(0, 0), (radius * 0.8, height * 0.12), (radius, height * 0.3), (radius * 0.7, height * 0.6),
               (radius * 0.3, height * 0.85), (0, height)], 10, transform=Matrix.Translation(Vector(base)))


def loft(bm, rings, closed=False, cap_ends=False):
    """Connect rings of points (equal counts) into a surface; closed joins each ring end to end."""
    verts = [[bm.verts.new(p) for p in ring] for ring in rings]
    count = len(rings[0])
    for a, b in zip(verts, verts[1:]):
        for k in range(count if closed else count - 1):
            j = (k + 1) % count
            bm.faces.new((a[k], a[j], b[j], b[k]))
    if cap_ends:
        bm.faces.new(tuple(reversed(verts[0])))
        bm.faces.new(tuple(verts[-1]))
    return verts


# ---------- pillars, walls and the gateway ----------

def pillar(m, x, y, inward):
    """A square sandstone pillar with a lotus capital and painted glyph columns on its faces."""
    sand = m["TombSandstone"]
    box(sand, (x, y, 0.3), (1.9, 1.9, 0.6))
    box(sand, (x, y, 0.6 + (10.2 - 0.6) / 2), (1.3, 1.3, 9.6))
    lathe(sand, [(0, 10.1), (0.62, 10.1), (0.68, 10.3), (1.0, 10.75), (1.08, ARCH_Z), (0, ARCH_Z)], 16, transform=Matrix.Translation((x, y, 0)))
    for z, mesh in ((9.4, "TombPaintBlue"), (9.75, "TombPaintRed"), (10.25, "TombPaintTeal")):
        box(m[mesh], (x, y, z), (1.34, 1.34, 0.22))
    for z in (10.55, 10.8):
        torus(m["TombPaintTeal"], (x, y, z), (0, 0, 1), 0.86 + (z - 10.55) * 0.7, 0.05, segments=16, minor_segments=4)
    for nx in (inward, -inward):
        n = Vector((nx, 0, 0))
        glyph_column(m, m["TombGlyphs" if nx == inward else "TombGlyphsOuter"], Vector((x + nx * 0.65, y, 1.1)), Vector((0, -nx, 0)), Vector((0, 0, 1)), n, 7.6, 0.9,
                     seed=x * 7 + y + nx)


def block_wall(m, a, b, top=DADO, thickness=0.8):
    """Coursed sandstone blocks between two points, with a painted frieze along the top."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    along = (b - a).normalized()
    length = (b - a).length
    angle = math.atan2(along.y, along.x)
    turn = Matrix.Rotation(angle, 4, "Z")
    course, row = 0.62, 0
    z = 0.0
    while z < top - 0.6 - 1e-6:
        h = min(course, top - 0.6 - z)
        offset = 0.55 if row % 2 else 0.0
        s = -offset
        while s < length - 1e-6:
            e = min(length, s + 1.1)
            s0 = max(0.0, s)
            if e - s0 > 0.1:
                c = a + along * ((s0 + e) / 2)
                box(m["TombBlocks"], (c.x, c.y, z + h / 2), (e - s0 - 0.05, thickness, h - 0.05), turn)
            s = e
        z += h
        row += 1
    # The frieze: a cream band with alternating blue, red and gold panels on both faces.
    c = a + along * (length / 2)
    box(m["TombSandstone"], (c.x, c.y, top - 0.3), (length, thickness + 0.06, 0.6), turn)
    side = Vector((-along.y, along.x, 0))
    count = max(1, int(length / 0.42))
    for k in range(count):
        p = a + along * (length * (k + 0.5) / count)
        mesh = ("TombPaintBlue", "TombPaintRed", "TombGold")[k % 3]
        for s in (-1, 1):
            q = p + side * s * (thickness / 2 + 0.04)
            box(m[mesh], (q.x, q.y, top - 0.3), (0.22, 0.04, 0.42), turn)


def build_walls(m):
    for y in HOOPS:
        pillar(m, LEFT_X, y, 1)
        pillar(m, RIGHT_X, y, -1)
    for y0, y1 in zip(HOOPS, HOOPS[1:]):
        for x in (LEFT_X, RIGHT_X):
            block_wall(m, (x, y0 + 0.65), (x, y1 - 0.65))
    for x0, x1 in ((LEFT_X + 0.65, RIGHT_X - 0.65),):
        block_wall(m, (x0, FRONT_Y), (x1, FRONT_Y))
    block_wall(m, (PYLONS[1][1], BACK_Y), (RIGHT_X - 0.65, BACK_Y))
    # Linen net over the walls, from the frieze up to the architrave.
    net = m["TombNet"]
    h = ARCH_Z - DADO
    for x, normal in ((LEFT_X, -1), (RIGHT_X, 1)):
        for y0, y1 in zip(HOOPS, HOOPS[1:]):
            net_panel(net, Vector((x, y0 + 0.65, DADO)), Vector((0, 1, 0)), Vector((0, 0, 1)), y1 - y0 - 1.3, h, Vector((normal, 0, 0)),
                      1.4, 0.06, rope=0.05, diamond=True)
    net_panel(net, Vector((LEFT_X + 0.65, FRONT_Y, DADO)), Vector((1, 0, 0)), Vector((0, 0, 1)), RIGHT_X - LEFT_X - 1.3, h,
              Vector((0, 1, 0)), 1.4, 0.06, rope=0.05, diamond=True)
    net_panel(net, Vector((PYLONS[1][1], BACK_Y, DADO)), Vector((1, 0, 0)), Vector((0, 0, 1)), RIGHT_X - 0.65 - PYLONS[1][1], h,
              Vector((0, -1, 0)), 1.4, 0.06, rope=0.05, diamond=True)
    # The architrave ring with a painted gorge cornice: vertical blue, red and gold stripes on its flare.
    for a, b in (((LEFT_X, BACK_Y - 0.65), (LEFT_X, FRONT_Y + 0.65)), ((RIGHT_X, BACK_Y - 0.65), (RIGHT_X, FRONT_Y + 0.65)),
                 ((LEFT_X - 0.65, FRONT_Y), (RIGHT_X + 0.65, FRONT_Y)), ((LEFT_X - 0.65, BACK_Y), (RIGHT_X + 0.65, BACK_Y))):
        cavetto(m["TombSandstone"], (a[0], a[1], 0), (b[0], b[1], 0), 1.3, ARCH_Z)
        a3, b3 = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
        along = (b3 - a3).normalized()
        side = Vector((-along.y, along.x, 0))
        length = (b3 - a3).length
        turn = Matrix.Rotation(math.atan2(along.y, along.x), 4, "Z")
        # Painted stripes on the beam's upright faces and a gold fillet under the flare.
        count = int(length / 0.55)
        for k in range(count):
            p = a3 + along * (length * (k + 0.5) / count)
            mesh = ("TombPaintBlue", "TombPaintRed", "TombPaintTeal", "TombGold")[k % 4]
            for s in (-1, 1):
                box(m[mesh], p + side * s * 0.67 + Vector((0, 0, ARCH_Z + 0.27)), (0.36, 0.04, 0.4), turn)
        for s in (-1, 1):
            box(m["TombGold"], (a3 + b3) / 2 + side * s * 0.67 + Vector((0, 0, ARCH_Z + 0.52)), (length, 0.06, 0.08), turn)


def build_gateway(m):
    """Two battered pylon towers either side of the door, a bridge with a winged sun over the gap."""
    pylon = m["TombPylons"]
    top = 14.6
    for x0, x1 in PYLONS:
        inner_door = x1 if x1 < DOOR[0] + 0.1 else x0      # the door-side face stays upright
        bx0, bx1 = x0, x1
        tx0 = x0 + (0.5 if inner_door != x0 else 0.0)
        tx1 = x1 - (0.5 if inner_door != x1 else 0.0)
        hexahedron(pylon, [Vector((bx0, BACK_Y - 1.4, 0)), Vector((bx1, BACK_Y - 1.4, 0)), Vector((bx1, BACK_Y + 1.4, 0)), Vector((bx0, BACK_Y + 1.4, 0))],
                   [Vector((tx0, BACK_Y - 0.7, top)), Vector((tx1, BACK_Y - 0.7, top)), Vector((tx1, BACK_Y + 0.7, top)), Vector((tx0, BACK_Y + 0.7, top))])
        cavetto(pylon, ((tx0 + tx1) / 2 - (tx1 - tx0) / 2, BACK_Y, 0), ((tx0 + tx1) / 2 + (tx1 - tx0) / 2, BACK_Y, 0), 1.4, top, lip=0.3)
        # Reliefs on the outer face: two glyph columns and a great ankh between them.
        slope = Vector((0, 0.7, top)).normalized()
        face_origin = Vector(((x0 + x1) / 2, BACK_Y - 1.4, 0.6))
        n = Vector((0, -top, 0.7)).normalized()
        for dx in (-0.85, 0.85):
            glyph_column(m, m["TombGlyphsOuter"], face_origin + Vector((dx, 0, 0)) + slope * 0.4, Vector((1, 0, 0)), slope, n, 11.0, 0.75, seed=x0 + dx)
        glyph(m["TombPaintRed"], face_origin + slope * 6.2, Vector((1, 0, 0)), slope, n, 1.6, "ankh")
        box(m["TombGold"], ((x0 + x1) / 2, BACK_Y - 1.45, 0.3), (x1 - x0 + 0.1, 0.12, 0.6))
    # The bridge over the door, carrying the winged sun disc above the entrance sign.
    bridge_z = 11.0
    centre = Vector(((PYLONS[0][1] + PYLONS[1][0]) / 2, BACK_Y - 0.72, bridge_z + 0.65))
    disc(m["TombPaintRed"], centre, (0, 1, 0), 0.5, 0.12, segments=24)
    for s in (-1, 1):
        for k in range(5):
            length = 2.6 - k * 0.32
            z = 0.32 - k * 0.14
            p0 = centre + Vector((s * 0.5, -0.02, z))
            p1 = p0 + Vector((s * length, 0, 0.18 - k * 0.04))
            face_poly(m["TombGold" if k % 2 == 0 else "TombPaintBlue"], Vector((0, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0)),
                      [(p0.x, p0.z), (p1.x, p1.z), (p1.x, p1.z - 0.16), (p0.x, p0.z - 0.2)], thickness=0.06, lift=-p0.y - 0.03)
        lathe(m["TombGold"], [(0, 0), (0.12, 0), (0.14, 0.4), (0.06, 0.62), (0, 0.66)], 8,
              transform=Matrix.Translation(centre + Vector((s * 0.55, -0.05, -0.55))))
    # Door posts with gold edging inside the gateway.
    for x in (DOOR[0] - 0.2, DOOR[1] + 0.2):
        box(m["TombGold"], (x, BACK_Y - 1.0, DOOR[2] / 2), (0.14, 0.14, DOOR[2]))


# ---------- the pyramid roof ----------

def build_roof(m):
    frame = m["TombRoofFrame"]
    x0, x1 = ROOF_X
    y0, y1 = ROOF_Y
    corners = [Vector((x0, y0, ROOF_Z)), Vector((x1, y0, ROOF_Z)), Vector((x1, y1, ROOF_Z)), Vector((x0, y1, ROOF_Z))]
    beam = rrect(0.42, 0.42, 0.08)
    for c in corners:
        extrude(frame, c, APEX, beam)
    for y in HOOPS[1:-1]:
        for x in (x0, x1):
            extrude(frame, (x, y, ROOF_Z), APEX, rrect(0.28, 0.28, 0.06))
    for x in (-11.0, -6.0, -1.0, 4.0, 9.0):
        for y in (y0, y1):
            extrude(frame, (x, y, ROOF_Z), APEX, rrect(0.28, 0.28, 0.06))
    for f in (0.0, 0.22, 0.44, 0.66):
        ring = [c.lerp(APEX, f) for c in corners]
        for a, b in zip(ring, ring[1:] + ring[:1]):
            extrude(frame, a, b, rrect(0.36, 0.36, 0.08))
    # Linen net over the four faces: courses and rays to the apex.
    for index, (a, b) in enumerate(zip(corners, corners[1:] + corners[:1])):
        length = (b - a).length
        height = (APEX - (a + b) / 2).length

        def face(u, v, a=a, b=b, length=length, height=height):
            return a.lerp(b, u / length).lerp(APEX, min(0.999, v / height))
        surface_net(m["TombNetRoof" if index % 2 else "TombNetRoofEnds"], face, length, height * 0.9, 1.8, 0.06, diamond=True)
    # The gold capstone.
    f = 0.9
    pyramid(m["TombRoofCap"], corners[0].lerp(APEX, f) * 0 + Vector((CX, CY, ROOF_Z + (APEX.z - ROOF_Z) * f)),
            (x1 - x0) * (1 - f) + 0.3, (y1 - y0) * (1 - f) + 0.3, (APEX.z - ROOF_Z) * (1 - f) + 0.6)


# ---------- the floor ----------

def build_floor(m):
    """Limestone tiles laid over gold, so every joint shows a gold line; a lapis lane with ankhs."""
    zones = [(LEFT_X + 0.7, -3.2, BACK_Y + 0.5, FRONT_Y - 0.5), (9.2, RIGHT_X - 0.7, BACK_Y + 0.5, FRONT_Y - 0.5),
             (-3.2, 9.2, BACK_Y + 0.5, -4.0), (-3.2, 0.6, 3.8, FRONT_Y - 0.5), (5.4, 9.2, 3.8, FRONT_Y - 0.5),
             (0.6, 5.4, 20.6, FRONT_Y - 0.5)]
    for x0, x1, y0, y1 in zones:
        box(m["TombFloorGold"], ((x0 + x1) / 2, (y0 + y1) / 2, 0.025), (x1 - x0, y1 - y0, 0.05))
        tiles(m["TombFloor"], x0, x1, y0, y1, 2.0, 0.14, 0.0, 0.075)
    lapis, gold = m["TombLapis"], m["TombFloorGold"]
    box(lapis, (PITCH.x, 12.2, 0.035), (4.6, 16.8, 0.07))
    for x in (PITCH.x - 2.38, PITCH.x + 2.38):
        box(gold, (x, 12.2, 0.045), (0.18, 16.8, 0.09))
    for y in (3.75, 20.65):
        box(gold, (PITCH.x, y, 0.045), (4.94, 0.18, 0.09))
    for y in (6.4, 10.6, 14.8):
        glyph(gold, Vector((PITCH.x, y, 0.07)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), 1.4, "ankh")
    # A gold border round the batter's ground.
    for a, b in (((-3.3, -4.1), (9.3, -4.1)), ((-3.3, -4.1), (-3.3, 3.9)), ((9.3, -4.1), (9.3, 3.9)), ((-3.3, 3.9), (0.6, 3.9)), ((5.4, 3.9), (9.3, 3.9))):
        a3, b3 = Vector((a[0], a[1], 0.05)), Vector((b[0], b[1], 0.05))
        box(gold, (a3 + b3) / 2, (abs(b3.x - a3.x) + 0.2, abs(b3.y - a3.y) + 0.2, 0.1))
    home_plate(m["TombPlate"], 0.08)


# ---------- the sarcophagus and the mummy ----------

WIDTH = [(0.0, 0.62), (0.6, 0.78), (2.4, 0.98), (4.3, 1.32), (4.9, 1.36), (5.35, 1.02), (5.9, 1.24), (6.4, 1.06), (6.75, 0.55), (6.9, 0.0)]
DEPTH = [(0.0, 0.72), (2.0, 0.86), (4.6, 1.02), (6.0, 1.0), (6.9, 0.6)]


def lerp_table(table, z):
    for (z0, a), (z1, b) in zip(table, table[1:]):
        if z0 <= z <= z1:
            return a + (b - a) * (z - z0) / (z1 - z0)
    return table[-1][1]


def coffin_ring(z, scale_w=1.0, scale_d=1.0, front=False, count=18, p=3.0):
    """Half a superellipse cross-section at height z: the back half (case) or front half (lid)."""
    w, d = lerp_table(WIDTH, z) * scale_w, lerp_table(DEPTH, z) * scale_d
    points = []
    for k in range(count + 1):
        a = math.pi * k / count + (math.pi if front else 0.0)
        c, s = math.cos(a), math.sin(a)
        x = COFFIN.x + w * math.copysign(abs(c) ** (2 / p), c)
        y = COFFIN.y + d * math.copysign(abs(s) ** (2 / p), s) * (0.55 if front else 1.0)
        points.append(Vector((x, y, COFFIN.z + z)))
    return points


def build_sarcophagus(m):
    heights = [i * 6.86 / 22 for i in range(23)]
    # The case: a gold outer shell, a dark painted inside and a rim joining them.
    loft(m["TombCoffin"], [coffin_ring(z) for z in heights])
    loft(m["TombCoffin"], [list(reversed(coffin_ring(z))) for z in heights])
    inner_rings = [coffin_ring(z, 0.86, 0.82) for z in heights]
    loft(m["TombCoffinInside"], inner_rings)
    loft(m["TombCoffinInside"], [list(reversed(r)) for r in inner_rings])
    for side in (0, -1):
        strip = [[coffin_ring(z)[side], coffin_ring(z, 0.86, 0.82)[side]] for z in heights]
        loft(m["TombCoffin"], strip)
        loft(m["TombCoffin"], [list(reversed(s)) for s in strip])
    box(m["TombSandstone"], (COFFIN.x, COFFIN.y + 0.4, 0.25), (3.6, 2.8, 0.5))
    box(m["TombGold"], (COFFIN.x, COFFIN.y + 0.4, 0.52), (3.7, 2.9, 0.06))
    # Painted bands round the case.
    for z in (0.9, 1.8, 2.7, 3.6):
        ring = coffin_ring(z, 1.015, 1.015)
        for a, b in zip(ring, ring[1:]):
            box(m["TombCoffinPaint"], (a + b) / 2, ((b - a).length + 0.02, 0.06, 0.16), Matrix.Rotation(math.atan2((b - a).y, (b - a).x), 4, "Z"))

    # The lid, built closed, then swung open on its hinge at the right edge of the case.
    starts = {name: len(m[name].verts) for name in ("TombCoffin", "TombCoffinPaint", "TombLidSky", "TombGold", "TombObsidian", "TombPaintRed", "TombPaintTeal")}
    front_rings = [coffin_ring(z, front=True) for z in heights]
    loft(m["TombCoffin"], front_rings)
    flat = [[Vector((p.x, COFFIN.y - 0.01, p.z)) for p in r] for r in front_rings]
    loft(m["TombCoffin"], [list(reversed(r)) for r in flat])
    for side in (0, -1):
        strip = [[front_rings[i][side], flat[i][side]] for i in range(len(heights))]
        loft(m["TombCoffin"], strip)
        loft(m["TombCoffin"], [list(reversed(s)) for s in strip])
    loft(m["TombCoffin"], [list(reversed(r)) for r in front_rings])
    face_y = lambda z: COFFIN.y - lerp_table(DEPTH, z) * 0.55 - 0.03

    def band(z, mesh, radius):
        """A painted band hugging the lid's curved front at height z."""
        sweep(m[mesh], coffin_ring(z, 1.0, 1.04, front=True)[1:-1], radius, segments=6)
    # Nemes headdress stripes, the face, a broad collar, crossed crook and flail, wings and a glyph band.
    for k in range(8):
        band(5.5 + k * 0.17, "TombCoffinPaint", 0.045)
    blob(m["TombGold"], Vector((COFFIN.x, face_y(6.1) - 0.05, COFFIN.z + 6.05)), Vector((0.5, 0.18, 0.6)), subdivisions=2)
    for s in (-1, 1):
        ball(m["TombObsidian"], (COFFIN.x + s * 0.2, face_y(6.1) - 0.22, COFFIN.z + 6.2), 0.07, subdivisions=1)
    box(m["TombObsidian"], (COFFIN.x, face_y(5.7) - 0.18, COFFIN.z + 5.55), (0.16, 0.1, 0.5))
    for k, mesh in enumerate(("TombPaintTeal", "TombGold", "TombPaintRed", "TombGold", "TombCoffinPaint")):
        band(4.95 - k * 0.2, mesh, 0.07)
    # Inside the lid, the sky goddess's starry blue, which faces the batter once the lid is open.
    sky = [[Vector((p.x, COFFIN.y + 0.005, p.z)) for p in coffin_ring(z, 0.92, 1.0, front=True)] for z in heights[1:-2]]
    loft(m["TombLidSky"], sky)
    loft(m["TombLidSky"], [list(reversed(r)) for r in sky])
    for _ in range(26):
        z = rng.uniform(0.8, 5.8)
        x = COFFIN.x + rng.uniform(-0.8, 0.8) * lerp_table(WIDTH, z)
        face_poly(m["TombGold"], Vector((0, COFFIN.y + 0.03, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)),
                  [(x + 0.1 * math.cos(math.pi / 2 + 2 * math.pi * k / 5), z + 0.1 * math.sin(math.pi / 2 + 2 * math.pi * k / 5)) for k in range(5)],
                  thickness=0.03)
    for s in (-1, 1):
        sweep(m["TombGold"], [Vector((COFFIN.x + s * 0.7, face_y(4.0) - 0.1, COFFIN.z + 3.6)), Vector((COFFIN.x - s * 0.1, face_y(4.0) - 0.16, COFFIN.z + 4.2)),
                              Vector((COFFIN.x - s * 0.45, face_y(4.0) - 0.12, COFFIN.z + 4.7))], 0.07, segments=6)
        for k in range(6):
            z = 3.2 - k * 0.22
            face_poly(m["TombCoffinPaint" if k % 2 else "TombPaintTeal"], Vector((COFFIN.x, face_y(z) - 0.02, COFFIN.z)), Vector((s, 0, 0)), Vector((0, 0, 1)),
                      Vector((0, -1, 0)), [(0.1, z), (lerp_table(WIDTH, z) * 0.95, z + 0.35), (lerp_table(WIDTH, z) * 0.95, z + 0.18), (0.1, z - 0.15)], thickness=0.04)
    for k in range(5):
        glyph(m["TombGold"], Vector((COFFIN.x, face_y(1.6) - 0.06, COFFIN.z + 0.6 + k * 0.42)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0)), 0.36, KINDS[k])
    turn = Matrix.Translation(HINGE) @ Matrix.Rotation(LID_OPEN, 4, "Z") @ Matrix.Translation(-HINGE)
    for name, start in starts.items():
        transform_new(m[name], start, turn)
    for z in (1.2, 3.3, 5.6):
        cylinder(m["TombGold"], HINGE + Vector((0, 0, COFFIN.z + z - 0.25)), (0, 0, 1), 0.5, 0.09, segments=8)

    # The mummy in the case, reaching out with the ball held at PITCH in both hands.
    mummy, wraps = m["TombMummy"], m["TombMummyWraps"]
    body_y = COFFIN.y + 0.45
    lathe(mummy, [(0, 0.6), (0.36, 0.6), (0.42, 2.2), (0.5, 3.6), (0.62, 4.5), (0.5, 4.85), (0.24, 5.05), (0.2, 5.15), (0, 5.15)], 16,
          transform=Matrix.Translation((COFFIN.x, body_y, 0)) @ Matrix.Diagonal((1.0, 0.65, 1.0, 1.0)))
    blob(mummy, Vector((COFFIN.x, body_y - 0.05, 5.6)), Vector((0.42, 0.4, 0.5)), subdivisions=2, lump=0.06, seed=3)
    body_r = [(0.6, 0.36), (2.2, 0.42), (3.6, 0.5), (4.5, 0.62), (4.85, 0.5)]

    def wrap(z, rx, ry, tilt, centre_y=body_y):
        """A bandage loop round the (oval) body, tilted a little so the wraps spiral."""
        points = [Vector((COFFIN.x + rx * math.cos(a), centre_y + ry * math.sin(a), z + tilt * math.cos(a)))
                  for a in [2 * math.pi * k / 16 for k in range(17)]]
        sweep(wraps, points, 0.045, segments=5)
    for k in range(20):
        z = 0.85 + k * 0.2
        r = lerp_table(body_r, z) + 0.02
        wrap(z, r, r * 0.65, 0.12 * math.sin(k * 1.7))
    for k in range(4):
        wrap(5.3 + k * 0.17, 0.43, 0.41, 0.06 * math.cos(k * 2), centre_y=body_y - 0.05)
    for s in (-1, 1):
        ball(m["TombEyes"], (COFFIN.x + s * 0.15, body_y - 0.42, 5.68), 0.07, subdivisions=1)
        shoulder = Vector((COFFIN.x + s * 0.58, body_y, 4.55))
        hand = PITCH + Vector((s * 0.36, 0.12, 0.02))
        elbow = shoulder.lerp(hand, 0.5) + Vector((s * 0.08, 0, -0.18))
        sweep_radii(mummy, [shoulder, elbow, hand], [0.17, 0.15, 0.13], segments=10)
        for t in (0.2, 0.4, 0.6, 0.8):
            p = Polyline([shoulder, elbow, hand]).at(Polyline([shoulder, elbow, hand]).length * t)
            torus(wraps, p, (hand - shoulder).normalized(), 0.17, 0.035, segments=12, minor_segments=4)
        blob(mummy, hand + Vector((s * 0.02, 0.02, 0)), Vector((0.16, 0.2, 0.2)), subdivisions=2)
        # Loose bandage ends hanging from the arms.
        p = elbow + Vector((0, 0, -0.1))
        double_sided_strip(wraps, [p, p + Vector((s * 0.05, 0.04, -0.9))], [p + Vector((0, 0.12, 0)), p + Vector((s * 0.05, 0.16, -0.85))])
    pitch_ball(m["TombBall"])


# ---------- the scarab screen ----------

def ray_ellipse(origin, d, centre, rx, rz):
    ox, oz = origin[0] - centre[0], origin[1] - centre[1]
    a = (d[0] / rx) ** 2 + (d[1] / rz) ** 2
    b = 2 * (ox * d[0] / rx ** 2 + oz * d[1] / rz ** 2)
    c = (ox / rx) ** 2 + (oz / rz) ** 2 - 1
    disc_ = b * b - 4 * a * c
    if disc_ < 0:
        return 0.0
    return max(0.0, (-b + math.sqrt(disc_)) / (2 * a))


BODY = ((PITCH.x, 3.1), 2.75, 3.0)
HEAD = ((PITCH.x, 6.0), 1.25, 0.75)


def scarab_outline(angle):
    o, d = (PITCH.x, PITCH.z), (math.cos(angle), math.sin(angle))
    r = max(ray_ellipse(o, d, *BODY), ray_ellipse(o, d, *HEAD))
    # Little serrations on the head.
    if d[1] > 0.85:
        r += 0.08 * abs(math.sin(angle * 40))
    return r


def build_screen(m):
    y = SCREEN_Y
    window_panel(m["TombScarab"], scarab_outline, y, 0.32, segments=96)
    front = y - 0.17
    inlay, gold = m["TombScarabInlay"], m["TombGold"]
    # The wing cases: concentric lapis ribs either side of a raised gold seam.
    (bx, bz), rx, rz = BODY
    for r in (0.5, 0.64, 0.78, 0.9):
        for side in (-1, 1):
            points = []
            for k in range(19):
                a = math.radians(-80 + 160 * k / 18)
                px, pz = bx + side * rx * r * math.cos(a), bz + rz * r * math.sin(a) - 0.25
                points.append((px, pz))
            for a, b in zip(points, points[1:]):
                mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
                if math.hypot(mid[0] - PITCH.x, mid[1] - PITCH.z) < WINDOW + 0.35 or abs(mid[0] - PITCH.x) < 0.25:
                    continue
                face_poly(inlay, Vector((0, front, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0)), bar(a, b, 0.12), thickness=0.05)
    for z0, z1 in ((0.4, PITCH.z - WINDOW - 0.3), (PITCH.z + WINDOW + 0.3, 5.7)):
        face_poly(gold, Vector((0, front, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0)), bar((PITCH.x, z0), (PITCH.x, z1), 0.22), thickness=0.08)
    # The pronotum band and the head's lapis plates.
    face_poly(inlay, Vector((0, front, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0)),
              ellipse(PITCH.x, 5.85, 1.0, 0.45, 16), thickness=0.05)
    for y_side in (front - 0.0, y + 0.17):
        n = Vector((0, -1, 0)) if y_side < y else Vector((0, 1, 0))
        torus(gold, (PITCH.x, y_side, PITCH.z), (0, 1, 0), WINDOW + 0.14, 0.09, segments=32, minor_segments=6)
    # Six gold legs: four bracing it on the plinth, and the front pair raised to push the sun.
    for side in (-1, 1):
        for (z0, z1, reach, drop) in ((1.3, 0.35, 1.2, 0.0), (2.8, 0.35, 1.5, 0.0)):
            a = Vector((PITCH.x + side * 2.55, y, z0))
            knee = a + Vector((side * reach, 0, 0.9))
            foot = Vector((PITCH.x + side * (2.6 + reach * 1.3), y, z1))
            sweep_radii(gold, [a, knee, foot], [0.14, 0.12, 0.08], segments=8)
        shoulder = Vector((PITCH.x + side * 1.0, y - 0.05, 5.7))
        sweep_radii(gold, [shoulder, shoulder + Vector((side * 0.9, 0, 0.7)), SUN + Vector((side * 0.95, 0, -0.3))], [0.13, 0.11, 0.08], segments=8)
    box(m["TombSandstone"], (PITCH.x, y + 0.1, 0.2), (8.8, 1.6, 0.4))
    box(gold, (PITCH.x, y + 0.1, 0.42), (8.9, 1.7, 0.05))
    # The sun disc it pushes, with a gold rim and rays: it turns slowly about its axis (Blender +Y).
    sun = m["TombSunDisc"]
    disc(sun, SUN, (0, 1, 0), 0.92, 0.16, segments=32)
    torus(sun, SUN, (0, 1, 0), 0.98, 0.07, segments=32, minor_segments=5)
    for k in range(16):
        a = 2 * math.pi * k / 16
        d, s = Vector((math.cos(a), 0, math.sin(a))), Vector((-math.sin(a), 0, math.cos(a)))
        slab(sun, [SUN + d * 1.06 - s * 0.12, SUN + d * (1.5 if k % 2 == 0 else 1.32), SUN + d * 1.06 + s * 0.12], 0.06, Vector((0, 1, 0)))


# ---------- torches, treasure and statues ----------

def torch(m, x, y, inward):
    base = Vector((x + inward * 0.65, y, 6.8))
    box(m["TombGold"], base + Vector((inward * 0.3, 0, 0)), (0.6, 0.16, 0.16))
    tube(m["TombGold"], base + Vector((inward * 0.55, 0, -0.9)), base + Vector((inward * 0.6, 0, 0.0)), 0.06, 6)
    bowl = base + Vector((inward * 0.7, 0, 0.05))
    lathe(m["TombGold"], [(0, 0), (0.15, 0), (0.42, 0.25), (0.46, 0.36), (0.38, 0.36), (0, 0.18)], 14, transform=Matrix.Translation(bowl))
    flame(m["TombFlames"], bowl + Vector((0, 0, 0.25)), 0.9, 0.3)


def coin_pile(m, centre, radius, height, coins=40):
    c = Vector(centre)
    blob(m["TombCoins"], c, Vector((radius, radius, height)), subdivisions=2, lump=0.2, seed=c.x + c.y, floor=0.0)
    for _ in range(coins):
        a, r = rng.uniform(0, 2 * math.pi), radius * math.sqrt(rng.random()) * 1.15
        z = height * math.sqrt(max(0.0, 1 - (r / (radius * 1.15)) ** 2)) * 0.9 + 0.02
        axis = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 1.0))
        disc(m["TombCoins"], c + Vector((math.cos(a) * r, math.sin(a) * r, z)), axis, 0.16, 0.04, segments=8)
    for _ in range(4):
        a, r = rng.uniform(0, 2 * math.pi), radius * 0.6 * rng.random()
        ball(m["TombGems"], c + Vector((math.cos(a) * r, math.sin(a) * r, height * 0.85)), 0.14, subdivisions=1)


def chest(m, centre, heading=0.0, size=(1.8, 1.1, 0.9)):
    c = Vector(centre)
    turn = Matrix.Rotation(heading, 4, "Z")
    w, d, h = size
    box(m["TombChest"], c + turn @ Vector((0, 0, h / 2)), (w, d, h), turn)
    start = len(m["TombChest"].verts)
    cylinder_x(m["TombChest"], Vector((0, 0, 0)), w, d / 2, 16)
    transform_new(m["TombChest"], start, Matrix.Translation(c + turn @ Vector((0, 0, h))) @ turn @ Matrix.Diagonal((1, 1, 0.6, 1)))
    for dx in (-w / 2 + 0.15, 0, w / 2 - 0.15):
        box(m["TombGold"], c + turn @ Vector((dx, 0, h / 2 + 0.05)), (0.12, d + 0.04, h + 0.12), turn)
    box(m["TombGold"], c + turn @ Vector((0, -d / 2 - 0.03, h * 0.75)), (0.3, 0.06, 0.35), turn)
    for k in range(3):
        ball(m["TombGems"], c + turn @ Vector((-0.4 + 0.4 * k, -d / 2 - 0.05, h * 0.4)), 0.08, subdivisions=1)


def canopic_jar(m, x, y, head):
    lathe(m["TombJars"], [(0, 0), (0.22, 0), (0.3, 0.15), (0.32, 0.6), (0.24, 0.85), (0.2, 0.9), (0, 0.9)], 14, transform=Matrix.Translation((x, y, 0.5)))
    blob(m["TombGold" if head % 2 else "TombObsidian"], Vector((x, y, 1.55)), Vector((0.22, 0.24, 0.26)), subdivisions=2)
    box(m["TombCoffinPaint"], (x, y - 0.31, 1.0), (0.18, 0.04, 0.4))


def cat_statue(m, x, y, facing=1):
    o = m["TombObsidian"]
    lathe(o, [(0, 0.6), (0.48, 0.6), (0.5, 0.9), (0.36, 1.8), (0.28, 2.3), (0, 2.4)], 14, transform=Matrix.Translation((x, y, 0)) @ Matrix.Diagonal((0.8, 1.0, 1.0, 1.0)))
    blob(o, Vector((x + facing * 0.05, y, 2.65)), Vector((0.3, 0.3, 0.3)), subdivisions=2)
    for s in (-1, 1):
        lathe(o, [(0, 0), (0.1, 0), (0, 0.32)], 4, transform=Matrix.Translation((x, y + s * 0.17, 2.85)))
    sweep_radii(o, [Vector((x - facing * 0.3, y + 0.35, 0.65)), Vector((x - facing * 0.1, y + 0.55, 0.62)), Vector((x + facing * 0.3, y + 0.5, 0.62))],
                [0.07, 0.06, 0.04], segments=6)
    torus(m["TombGold"], (x, y, 2.25), (0, 0, 1), 0.3, 0.04, segments=14, minor_segments=4)
    box(m["TombSandstone"], (x, y, 0.3), (1.3, 1.3, 0.6))
    box(m["TombGold"], (x, y, 0.6), (1.35, 1.35, 0.05))


def vase(m, x, y, h):
    lathe(m["TombJars"], [(0, 0), (0.2 * h, 0), (0.36 * h, 0.35 * h), (0.32 * h, 0.7 * h), (0.16 * h, 0.9 * h), (0.22 * h, 1.0 * h), (0, 0.96 * h)], 16,
          transform=Matrix.Translation((x, y, 0)))
    for z, mesh in ((0.42, "TombCoffinPaint"), (0.6, "TombPaintRed")):
        torus(m[mesh], (x, y, z * h), (0, 0, 1), 0.36 * h, 0.03, segments=16, minor_segments=4)


def build_interior(m):
    for y in (2.0, 18.0):
        torch(m, LEFT_X, y, 1)
        torch(m, RIGHT_X, y, -1)
    coin_pile(m, (-12.9, 29.0, 0.0), 1.5, 0.9)
    coin_pile(m, (-11.6, 31.4, 0.0), 1.0, 0.55, coins=20)
    chest(m, (-13.6, 26.4, 0.0), heading=math.pi / 2)
    chest(m, (-13.2, 9.5, 0.0), heading=math.pi / 2, size=(1.6, 1.0, 0.8))
    cat_statue(m, -14.2, 18.0, facing=1)
    coin_pile(m, (11.4, 30.6, 0.0), 1.3, 0.8)
    chest(m, (12.4, 27.2, 0.0), heading=-math.pi / 2, size=(2.0, 1.2, 1.0))
    box(m["TombSandstone"], (12.6, 15.0, 0.25), (1.2, 3.0, 0.5))
    for k in range(4):
        canopic_jar(m, 12.6, 13.9 + k * 0.72, k)
    for k, (y, h) in enumerate(((7.6, 1.5), (8.6, 1.1), (9.6, 1.7), (22.8, 1.3))):
        vase(m, 12.7 - 0.3 * (k % 2), y, h)


def sphinx(m):
    s, gold, lapis = m["TombSphinx"], m["TombGold"], m["TombLapis"]
    cx, y0 = -20.0, 7.0
    box(m["TombSandstone"], (cx, y0 + 6.4, 0.5), (5.2, 13.2, 1.0))
    box(gold, (cx, y0 + 6.4, 1.02), (5.3, 13.3, 0.05))
    blob(s, Vector((cx, y0 + 8.6, 2.6)), Vector((1.9, 3.4, 1.45)), subdivisions=3, seed=1, floor=1.0)
    blob(s, Vector((cx, y0 + 11.0, 2.8)), Vector((2.1, 1.7, 1.7)), subdivisions=2, seed=2, floor=1.0)
    blob(s, Vector((cx, y0 + 5.2, 3.0)), Vector((1.7, 1.5, 1.9)), subdivisions=2, seed=3, floor=1.0)
    for side in (-1, 1):
        x = cx + side * 1.05
        sweep_radii(s, [Vector((x, y0 + 5.0, 1.6)), Vector((x, y0 + 3.0, 1.35)), Vector((x, y0 + 1.2, 1.35))], [0.55, 0.45, 0.42], segments=10)
        blob(s, Vector((x, y0 + 1.0, 1.35)), Vector((0.55, 0.6, 0.38)), subdivisions=2, seed=side)
        blob(s, Vector((cx + side * 1.6, y0 + 11.2, 1.6)), Vector((0.6, 1.6, 0.6)), subdivisions=2, seed=side + 5)
    head = Vector((cx, y0 + 4.4, 5.3))
    blob(s, head, Vector((0.85, 0.8, 0.95)), subdivisions=3, seed=4)
    # The nemes: a gold hood behind the face with lapis stripes round its back, and striped lappets
    # falling over the chest.
    hood, hood_size = head + Vector((0, 0.3, 0.12)), Vector((1.08, 0.98, 1.1))
    blob(gold, hood, hood_size, subdivisions=3, seed=6)
    for k in range(6):
        z = hood.z + 0.8 - k * 0.32
        f = math.sqrt(max(0.0, 1 - ((z - hood.z) / hood_size.z) ** 2))
        arc = [Vector((cx + hood_size.x * f * 1.02 * math.cos(a), hood.y + hood_size.y * f * 1.02 * math.sin(a), z))
               for a in [math.radians(-12 + 204 * i / 16) for i in range(17)]]
        sweep(lapis, arc, 0.07, segments=5)
    for side in (-1, 1):
        for k in range(5):
            box(lapis if k % 2 else gold, (cx + side * 0.95, head.y - 0.35, head.z - 1.3 - k * 0.3), (0.5, 0.25, 0.3))
    box(gold, (cx, head.y - 0.8, head.z - 0.95), (0.25, 0.22, 0.6))
    lathe(gold, [(0, 0), (0.08, 0), (0.12, 0.3), (0, 0.42)], 6, transform=Matrix.Translation(head + Vector((0, -0.78, 0.55))))
    for side in (-1, 1):
        ball(m["TombObsidian"], head + Vector((side * 0.3, -0.78, 0.12)), 0.08, subdivisions=1)


def obelisk(m, x, y, seed):
    base = Vector((x, y, 0))
    for k, (w, h) in enumerate(((2.8, 0.5), (2.3, 0.5))):
        box(m["TombSandstone"], base + Vector((0, 0, 0.25 + k * 0.5)), (w, w, h))
    z0, z1, w0, w1 = 1.0, 15.0, 1.5, 0.95
    hexahedron(m["TombObelisks"], [base + Vector((sx * w0 / 2, sy * w0 / 2, z0)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))],
               [base + Vector((sx * w1 / 2, sy * w1 / 2, z1)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    pyramid(m["TombGold"], base + Vector((0, 0, z1)), w1, w1, 1.3)
    for n in (Vector((1, 0, 0)), Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, -1, 0))):
        u = Vector((0, 0, 1)).cross(n)
        lean = (w0 - w1) / 2 / (z1 - z0)
        up = (Vector((0, 0, 1)) - n * lean).normalized()
        origin = base + n * (w0 / 2) + Vector((0, 0, z0 + 0.6))
        glyph_column(m, m["TombObeliskGlyphs"], origin, u, up, (n + Vector((0, 0, lean))).normalized(), 11.6, 0.6, seed=seed + n.x * 3 + n.y, gold=False,
                     spacing=1.6)


def censer(m, name, top):
    """A gold incense burner hung on a chain from the roof ring."""
    c = m[name]
    t = Vector(top)
    for k in range(18):
        torus(c, t - Vector((0, 0, 0.32 * k + 0.15)), (1, 0, 0) if k % 2 else (0, 1, 0), 0.1, 0.03, segments=8, minor_segments=3)
    bowl = t - Vector((0, 0, 6.3))
    lathe(c, [(0, -0.5), (0.25, -0.48), (0.48, -0.25), (0.52, 0.0), (0.44, 0.05), (0.3, 0.25), (0.12, 0.42), (0.1, 0.5), (0, 0.55)], 16,
          transform=Matrix.Translation(bowl))
    for k in range(4):
        a = math.pi / 2 * k
        tube(c, bowl + Vector((math.cos(a) * 0.48, math.sin(a) * 0.48, 0.0)), t - Vector((0, 0, 5.85)), 0.02, 4)


def build_outside(m):
    sphinx(m)
    for x, y, seed in ((-19.6, -17.6, 1), (17.6, -17.6, 2), (-19.6, 38.6, 3), (17.6, 38.6, 4)):
        obelisk(m, x, y, seed)
    censer(m, "TombCenserA", (-12.2, 30.5, 14.4))
    censer(m, "TombCenserB", (10.2, 30.5, 14.4))
    # Palms of sand-coloured stone pots and scattered blocks outside.
    for x, y in ((18.4, 8.0), (18.4, 20.0), (-19.8, 26.0), (-19.8, 30.5)):
        vase(m, x, y, 1.9)
    for x, y, r in ((19.6, 30.0, 0.7), (18.6, 33.0, 0.5), (-21.6, 33.8, 0.6), (19.4, -6.0, 0.6)):
        box(m["TombBlocks"], (x, y, r / 2), (r * 2.2, r * 1.6, r), Matrix.Rotation(rng.uniform(-0.5, 0.5), 4, "Z"))


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = meshes(LOOKS)
    build_walls(m)
    build_gateway(m)
    build_roof(m)
    build_floor(m)
    build_sarcophagus(m)
    build_screen(m)
    build_interior(m)
    build_outside(m)
    objects = build_looks(coll, m, LOOKS)
    check_centred(objects, {"TombSunDisc": (SUN, (0, 1, 0))})
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
