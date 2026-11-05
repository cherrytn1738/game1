# Training Ground 5 of World 4, Snow Globe (opened by Cosmic Rift's pass): World 4's showpiece. The
# batting cage is sealed inside a giant snow globe: the glass dome itself is the enclosure (no nets),
# with highlights streaking across it and a doorway cut through it at the door, on a carved wooden
# music-box base (gold bands, scrolled panels, ball feet, a plaque) whose wind-up key turns. Inside
# is a tiny snowy village: cottages with lit windows and smoking chimneys, a chapel, snow-laden pines,
# drifts, a frozen pond whose skaters circle, candy-cane lampposts and big snowflake ornaments that
# drift and turn under the dome. A red sleigh full of gifts holds the ball on its curled front at
# PITCH, and an ice snowflake is the screen, with the window at its hub. TrainingCageStyles adds the
# falling snow, and the client swirls snow round the cage after each practice hit (TrainingConfig
# practiceHitEffect).
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "SnowGlobeCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\SnowGlobeCage.fbx"

SNOW = (0.97, 0.98, 1.0)
GLASS = (0.8, 0.9, 1.0)
WALNUT = (0.42, 0.26, 0.15)
WALNUT_DARK = (0.3, 0.18, 0.1)
GOLD = (1.0, 0.78, 0.25)
PINE = (0.15, 0.45, 0.3)
CANDY_RED = (0.88, 0.1, 0.14)
WARM = (1.0, 0.82, 0.45)
ICE = (0.7, 0.88, 1.0)
rng = random.Random(14)

CX, CY = (LEFT_X + RIGHT_X) / 2, (BACK_Y + FRONT_Y) / 2
RX, RY, RZ, P, DOME_Z = 19.6, 29.0, 22.0, 6.0, 1.6
BASE_OUT = 1.9                              # how far the music-box base reaches out from the glass
DOOR_X = ((DOOR[0] + DOOR[1]) / 2, (DOOR[1] - DOOR[0]) / 2 + 0.8)
KEY = Vector((CX, CY + RY + BASE_OUT + 0.6, 1.8))
POND = Vector((-11.4, 28.4, 0.0))
CAROUSEL = Vector((11.6, 17.2, 0.0))
FLAKES = {"GlobeFlakeA": Vector((-9.0, 6.0, 14.5)), "GlobeFlakeB": Vector((7.0, 13.0, 16.0)), "GlobeFlakeC": Vector((-2.0, 27.0, 14.0))}
FLAKE_SCREEN = Vector((PITCH.x, SCREEN_Y, PITCH.z))

LOOKS = {
    "GlobeGlass": (GLASS, "soft"), "GlobeHighlights": (WHITE, "soft"),
    "GlobeBase": (WALNUT, "hard"), "GlobeBaseDark": (WALNUT_DARK, "hard"), "GlobeBand": (GOLD, "hard"), "GlobeCarving": (GOLD, "smooth"),
    "GlobeFeet": (GOLD, "smooth"), "GlobeKey": (GOLD, "smooth"),
    "GlobeSnow": (SNOW, "smooth"), "GlobeSnowCaps": (SNOW, "smooth"), "GlobePines": (PINE, "hard"), "GlobeTrunks": ((0.36, 0.24, 0.16), "hard"),
    "GlobeWalls": ((0.95, 0.88, 0.74), "hard"), "GlobeWallsRed": ((0.74, 0.22, 0.2), "hard"), "GlobeRoofs": ((0.36, 0.22, 0.2), "hard"),
    "GlobeWindows": (WARM, "hard"), "GlobeTimber": ((0.32, 0.2, 0.12), "hard"), "GlobeChimneys": ((0.6, 0.3, 0.24), "hard"),
    "GlobeIcePond": (ICE, "hard"), "GlobeSkaters": (CANDY_RED, "smooth"), "GlobeSkatersScarves": ((0.2, 0.5, 0.9), "smooth"),
    "GlobeLampPosts": (WHITE, "smooth"), "GlobeLampStripes": (CANDY_RED, "smooth"), "GlobeLampGlow": (WARM, "smooth"),
    "GlobeSleigh": (CANDY_RED, "smooth"), "GlobeSleighGold": (GOLD, "smooth"), "GlobeSack": ((0.6, 0.42, 0.26), "smooth"),
    "GlobeGiftsGreen": ((0.2, 0.62, 0.32), "hard"), "GlobeGiftsBlue": ((0.24, 0.46, 0.9), "hard"), "GlobeRibbons": (GOLD, "hard"),
    "GlobeIce": (ICE, "hard"), "GlobeFrost": (WHITE, "smooth"), "GlobeIcicles": ((0.86, 0.94, 1.0), "smooth"),
    "GlobeSnowmen": (SNOW, "smooth"), "GlobeCoal": ((0.08, 0.08, 0.1), "smooth"), "GlobeCarrot": ((1.0, 0.5, 0.1), "smooth"),
    "GlobeOrnaments": (CANDY_RED, "smooth"), "GlobeGarland": (GOLD, "smooth"), "GlobeStar": ((1.0, 0.9, 0.4), "hard"),
    "GlobeCarouselDeck": (GOLD, "smooth"), "GlobeCarouselRed": (CANDY_RED, "soft"), "GlobeCarouselWhite": (WHITE, "soft"),
    "GlobeCarouselPoles": (GOLD, "smooth"), "GlobeCarouselHorses": (WHITE, "smooth"),
    "GlobePlate": (WHITE, "hard"), "GlobeBall": (WHITE, "smooth"),
}
for name in FLAKES:
    LOOKS[name] = (WHITE, "hard")


# ---------- the dome and the music-box base ----------

def edge_point(a, out=0.0):
    """The dome's footprint (a superellipse) at angle a, pushed out by out."""
    c, s = math.cos(a), math.sin(a)
    p = Vector((CX + RX * math.copysign(abs(c) ** (2 / P), c), CY + RY * math.copysign(abs(s) ** (2 / P), s), 0))
    n = Vector((p.x - CX, p.y - CY, 0)).normalized()
    return p + n * out


def in_door(p):
    return abs(p.x - DOOR_X[0]) < DOOR_X[1] and p.z < DOOR[2] + 1.0 and p.y < CY


def dome_point(u, v, scale=1.0):
    h = math.cos(v) ** 0.5
    c, s = math.cos(u), math.sin(u)
    return Vector((CX + RX * h * scale * math.copysign(abs(c) ** (2 / P), c), CY + RY * h * scale * math.copysign(abs(s) ** (2 / P), s),
                   DOME_Z + RZ * math.sin(v) * scale))


def build_dome(m):
    rings, segments = 20, 96
    glass = m["GlobeGlass"]
    grid = [[dome_point(2 * math.pi * k / segments, (math.pi / 2) * i / rings) for k in range(segments)] for i in range(rings + 1)]
    for i in range(rings):
        for k in range(segments):
            j = (k + 1) % segments
            quad = [grid[i][k], grid[i][j], grid[i + 1][j], grid[i + 1][k]]
            if any(in_door(p) for p in quad):
                continue
            outer = [glass.verts.new(p) for p in quad]
            centre = Vector((CX, CY, DOME_Z))
            inner = [glass.verts.new(centre + (p - centre) * 0.993) for p in quad]
            glass.faces.new(outer)
            glass.faces.new(list(reversed(inner)))
    # Two highlights streaking down the glass, a little outside it.
    for u0, width in ((2.2, 0.07), (2.45, 0.035)):
        left = [dome_point(u0, v, 1.004) for v in [0.25 + 1.0 * k / 20 for k in range(21)]]
        right = [dome_point(u0 + width, v, 1.004) for v in [0.25 + 1.0 * k / 20 for k in range(21)]]
        double_sided_strip(m["GlobeHighlights"], left, right)
    # A wooden doorway frame round the cut.
    half = DOOR_X[1]
    y = CY - RY * max(0.0, 1 - abs((DOOR_X[0] - CX) / RX) ** P) ** (1 / P)
    for x in (DOOR_X[0] - half, DOOR_X[0] + half):
        box(m["GlobeBase"], (x, y + 0.6, (DOOR[2] + 2.6) / 2), (0.9, 1.8, DOOR[2] + 2.6))
    box(m["GlobeBase"], (DOOR_X[0], y + 0.6, DOOR[2] + 2.4), (2 * half + 0.9, 1.8, 0.8))
    for x in (DOOR_X[0] - half, DOOR_X[0] + half):
        box(m["GlobeBand"], (x, y - 0.32, (DOOR[2] + 2.6) / 2), (0.3, 0.06, DOOR[2] + 2.4))
    box(m["GlobeBand"], (DOOR_X[0], y - 0.32, DOOR[2] + 2.4), (2 * half + 0.6, 0.06, 0.3))


def build_base(m):
    """The music-box base: a moulded walnut ring round the dome (open at the door), gold bands,
    carved scrolls on gold-framed panels, ball feet, a plaque, and its key."""
    a0 = -math.pi / 2 + 0.36
    a1 = -math.pi / 2 - 0.012 + 2 * math.pi
    path = [edge_point(a0 + (a1 - a0) * k / 220) for k in range(221)]
    # The door opening lies between the path's two ends, so the base is open there.
    profile_along(m["GlobeBase"], path, [(-0.6, 0.0), (BASE_OUT, 0.0), (BASE_OUT, 0.5), (BASE_OUT - 0.2, 0.7), (BASE_OUT - 0.2, 2.9),
                                         (BASE_OUT, 3.1), (BASE_OUT - 0.3, 3.45), (0.4, 3.6), (-0.6, 3.6)])
    profile_along(m["GlobeBand"], path, [(BASE_OUT - 0.05, 3.08), (BASE_OUT + 0.08, 3.08), (BASE_OUT + 0.08, 3.22), (BASE_OUT - 0.05, 3.22)])
    profile_along(m["GlobeBand"], path, [(BASE_OUT - 0.05, 0.52), (BASE_OUT + 0.08, 0.52), (BASE_OUT + 0.08, 0.66), (BASE_OUT - 0.05, 0.66)])
    line = Polyline(path)
    count = int(line.length / 4.2)
    for k in range(count):
        s0, s1 = line.length * k / count + 0.3, line.length * (k + 1) / count - 0.3
        p0, p1 = line.at(s0), line.at(s1)
        t = (p1 - p0).normalized()
        n = Vector((t.y, -t.x, 0))
        face0 = p0 + n * (BASE_OUT - 0.18)
        face1 = p1 + n * (BASE_OUT - 0.18)
        # A gold frame and, inside it, a scroll carved in relief.
        for z in (0.95, 2.65):
            sweep(m["GlobeCarving"], [face0 + Vector((0, 0, z)), face1 + Vector((0, 0, z))], 0.05, segments=5)
        for q in (face0, face1):
            sweep(m["GlobeCarving"], [q + Vector((0, 0, 0.95)), q + Vector((0, 0, 2.65))], 0.05, segments=5)
        mid = (face0 + face1) / 2 + n * 0.04
        span = (face1 - face0).length
        scroll = []
        for j in range(25):
            u = j / 24
            scroll.append(mid + t * (u - 0.5) * span * 0.8 + Vector((0, 0, 1.8 + 0.45 * math.sin(2 * math.pi * u * 1.5))))
        sweep(m["GlobeBaseDark"], scroll, 0.07, segments=5)
        for end, sgn in ((scroll[0], -1), (scroll[-1], 1)):
            spiral = [end + t * sgn * 0.25 * (1 - q / 10) * math.cos(q * 0.9) + Vector((0, 0, 0.25 * (1 - q / 10) * math.sin(q * 0.9))) for q in range(11)]
            sweep(m["GlobeBaseDark"], spiral, 0.05, segments=4)
        foot = p0 + n * (BASE_OUT - 0.3)
        ball(m["GlobeFeet"], (foot.x, foot.y, 0.0), 0.42, subdivisions=2)
    # A gold plaque on the front, and the wind-up key turning about its shaft (Blender +Y).
    front = edge_point(math.pi / 2, BASE_OUT + 0.02)
    box(m["GlobeBand"], (front.x - 4.0, front.y + 0.02, 1.8), (3.0, 0.06, 1.0))
    key = m["GlobeKey"]
    tube(key, KEY - Vector((0, 0.9, 0)), KEY + Vector((0, 0.5, 0)), 0.14, 10)
    disc(key, KEY + Vector((0, 0.55, 0)), (0, 1, 0), 0.28, 0.16, segments=16)
    for sx in (-1, 1):
        c = KEY + Vector((sx * 0.85, 0.62, 0))
        torus(key, c, (0, 1, 0), 0.6, 0.16, segments=22, minor_segments=6)
        disc(key, c, (0, 1, 0), 0.38, 0.1, segments=16)


# ---------- the snowy village ----------

def pine(m, base, height, radius):
    b = Vector(base)
    lathe(m["GlobeTrunks"], [(0, 0), (radius * 0.15, 0), (radius * 0.12, height * 0.3), (0, height * 0.3)], 8, transform=Matrix.Translation(b))
    for z, r, h in ((0.22, 1.0, 0.42), (0.48, 0.78, 0.36), (0.72, 0.52, 0.3)):
        lathe(m["GlobePines"], [(0, height * z), (radius * r, height * z), (radius * r * 0.15, height * (z + h)), (0, height * (z + h))], 12,
              transform=Matrix.Translation(b))
        lathe(m["GlobeSnowCaps"], [(radius * r * 0.6, height * (z + h * 0.42)), (radius * r * 0.42, height * (z + h * 0.62)), (radius * r * 0.15, height * (z + h) + 0.02),
                                   (0, height * (z + h) + 0.04)], 12, transform=Matrix.Translation(b))


def cottage(m, centre, heading, w, d, h, walls="GlobeWalls"):
    """A cottage: timbered walls, a steep roof under snow, lit windows, a door and a chimney."""
    c = Vector(centre)
    turn = Matrix.Rotation(heading, 4, "Z")
    f, s = turn @ Vector((0, 1, 0)), turn @ Vector((1, 0, 0))
    box(m[walls], c + Vector((0, 0, h / 2)), (w, d, h), turn)
    ridge = h + w * 0.55
    for sx in (-1, 1):
        slab(m["GlobeRoofs"], [c + s * sx * (w / 2 + 0.3) + f * (d / 2 + 0.3) + Vector((0, 0, h - 0.15)), c + s * sx * (w / 2 + 0.3) - f * (d / 2 + 0.3) + Vector((0, 0, h - 0.15)),
                               c - f * (d / 2 + 0.3) + Vector((0, 0, ridge)), c + f * (d / 2 + 0.3) + Vector((0, 0, ridge))], 0.18)
        slab(m["GlobeSnowCaps"], [c + s * sx * (w / 2 + 0.32) + f * (d / 2 + 0.32) + Vector((0, 0, h - 0.0)), c + s * sx * (w / 2 + 0.32) - f * (d / 2 + 0.32) + Vector((0, 0, h - 0.0)),
                                  c - f * (d / 2 + 0.32) + Vector((0, 0, ridge + 0.14)), c + f * (d / 2 + 0.32) + Vector((0, 0, ridge + 0.14))], 0.14)
    for sf in (-1, 1):
        slab(m[walls], [c + f * sf * d / 2 + s * w / 2 + Vector((0, 0, h)), c + f * sf * d / 2 - s * w / 2 + Vector((0, 0, h)), c + f * sf * d / 2 + Vector((0, 0, ridge))], 0.1)
    for sf in (-1, 1):
        for sx in (-1, 1):
            p = c + f * sf * (d / 2 + 0.02) + s * sx * w * 0.25 + Vector((0, 0, h * 0.55))
            box(m["GlobeWindows"], p, (0.5 if abs(f.x) < 0.5 else 0.05, 0.05 if abs(f.x) < 0.5 else 0.5, 0.6), Matrix())
            box(m["GlobeTimber"], p + f * sf * 0.02, (0.62 if abs(f.x) < 0.5 else 0.05, 0.05 if abs(f.x) < 0.5 else 0.62, 0.08))
    door = c - f * (d / 2 + 0.02) + Vector((0, 0, 0.55))
    box(m["GlobeTimber"], door, (0.6 if abs(f.x) < 0.5 else 0.05, 0.05 if abs(f.x) < 0.5 else 0.6, 1.1))
    for z in (0.15, h - 0.1):
        box(m["GlobeTimber"], c + Vector((0, 0, z)), (w + 0.06, d + 0.06, 0.16), turn)
    chimney = c + s * w * 0.25 + Vector((0, 0, ridge - 0.4))
    box(m["GlobeChimneys"], chimney, (0.45, 0.45, 1.4), turn)
    box(m["GlobeSnowCaps"], chimney + Vector((0, 0, 0.75)), (0.55, 0.55, 0.12), turn)
    return chimney + Vector((0, 0, 0.9))


def chapel(m, centre):
    c = Vector(centre)
    top = cottage(m, c, 0.0, 2.6, 3.6, 2.6, walls="GlobeWallsRed")
    tower = c - Vector((0, 1.6, 0))
    box(m["GlobeWallsRed"], tower + Vector((0, 0, 2.4)), (1.2, 1.2, 4.8))
    box(m["GlobeWindows"], tower + Vector((0, -0.62, 3.6)), (0.4, 0.05, 0.7))
    lathe(m["GlobeRoofs"], [(0, 4.8), (0.95, 4.8), (0, 7.4)], 4, transform=Matrix.Translation(tower) @ Matrix.Rotation(math.pi / 4, 4, "Z"))
    lathe(m["GlobeSnowCaps"], [(0.6, 5.4), (0.3, 6.5), (0, 7.45)], 4, transform=Matrix.Translation(tower) @ Matrix.Rotation(math.pi / 4, 4, "Z"))
    tube(m["GlobeSleighGold"], tower + Vector((0, 0, 7.3)), tower + Vector((0, 0, 8.1)), 0.04, 5)
    tube(m["GlobeSleighGold"], tower + Vector((-0.25, 0, 7.85)), tower + Vector((0.25, 0, 7.85)), 0.04, 5)
    return top


def lamppost(m, x, y, height=5.0):
    """A candy-cane lamppost: a striped post curling over at the top to a glowing lantern."""
    base = Vector((x, y, 0))
    path = [base + Vector((0, 0, z)) for z in (0.0, height * 0.5, height)]
    for k in range(1, 9):
        a = math.pi * k / 8
        path.append(base + Vector((0.6 - 0.6 * math.cos(a), 0, height + 0.6 * math.sin(a))))
    line = Polyline(path)
    pts = line.samples(0.15)
    sweep(m["GlobeLampPosts"], pts, 0.16, segments=10)
    frames = sweep_frames(pts)
    for stripe in range(2):
        helix = [p + (n * math.cos(k * 0.55 + math.pi * stripe) + b * math.sin(k * 0.55 + math.pi * stripe)) * 0.165 for k, (p, (t, n, b)) in enumerate(zip(pts, frames))]
        sweep(m["GlobeLampStripes"], helix, 0.06, segments=4)
    lantern = base + Vector((1.2, 0, height - 0.35))
    lathe(m["GlobeLampGlow"], [(0, -0.45), (0.25, -0.4), (0.3, 0.0), (0.22, 0.3), (0, 0.35)], 10, transform=Matrix.Translation(lantern))
    lathe(m["GlobeSleighGold"], [(0, 0.3), (0.35, 0.3), (0.0, 0.6)], 8, transform=Matrix.Translation(lantern))
    lathe(m["GlobeLampPosts"], [(0, 0), (0.45, 0), (0.3, 0.3), (0, 0.3)], 12, transform=Matrix.Translation(base))


def snowman(m, x, y, scale=1.0):
    s = scale
    for z, r in ((0.9, 0.95), (2.3, 0.7), (3.4, 0.5)):
        ball(m["GlobeSnowmen"], (x, y, z * s), r * s, subdivisions=2)
    for sx in (-1, 1):
        ball(m["GlobeCoal"], (x + sx * 0.17 * s, y - 0.44 * s, 3.52 * s), 0.06 * s, subdivisions=1)
    for k in range(3):
        ball(m["GlobeCoal"], (x, y - 0.69 * s, (2.0 + 0.3 * k) * s), 0.07 * s, subdivisions=1)
    lathe(m["GlobeCarrot"], [(0, 0), (0.09 * s, 0), (0, 0.6 * s)], 8, transform=Matrix.Translation((x, y - 0.45 * s, 3.4 * s)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    lathe(m["GlobeCoal"], [(0, 3.82 * s), (0.6 * s, 3.82 * s), (0.6 * s, 3.92 * s), (0.4 * s, 3.92 * s), (0.4 * s, 4.6 * s), (0, 4.6 * s)], 12,
          transform=Matrix.Translation((x, y, 0)))
    for sx in (-1, 1):
        tube(m["GlobeTrunks"], (x + sx * 0.6 * s, y, 2.4 * s), (x + sx * 1.4 * s, y, 3.0 * s), 0.05 * s, 5)


def build_village(m):
    chimneys = []
    for centre, heading, size in (((-13.6, 6.0, 0), math.pi / 2, (3.0, 3.6, 2.6)), ((-13.4, 13.5, 0), math.pi / 2, (2.6, 3.2, 2.3)),
                                  ((-13.8, 20.6, 0), math.pi / 2, (3.2, 3.8, 2.8)), ((11.6, 10.0, 0), -math.pi / 2, (2.8, 3.4, 2.5)),
                                  ((11.4, 24.0, 0), -math.pi / 2, (3.0, 3.6, 2.7)), ((-6.0, 37.0, 0), 0.0, (3.6, 3.0, 3.0))):
        chimneys.append(cottage(m, centre, heading, *size))
    chimneys.append(chapel(m, (6.0, 37.2, 0)))
    for x, y, h, r in ((-15.0, 0.5, 4.2, 1.2), (-12.2, 9.8, 3.6, 1.0), (-15.2, 17.2, 4.6, 1.3), (-15.0, 24.5, 3.8, 1.1), (12.8, 6.0, 3.6, 1.0),
                       (12.8, 29.6, 4.4, 1.2), (-17.8, -8.0, 5.0, 1.4), (16.4, -8.0, 5.0, 1.4),
                       (-17.4, 32.0, 5.6, 1.5), (15.6, 33.6, 5.4, 1.5), (10.2, 37.0, 4.4, 1.2),
                       (-10.6, 36.8, 4.8, 1.3), (-17.6, 12.0, 4.4, 1.3), (16.2, 22.0, 4.8, 1.3), (-12.2, -10.8, 3.6, 1.0), (11.6, -11.2, 3.4, 1.0)):
        pine(m, (x, y, 0), h, r)
    # The village's Christmas tree between the cottages: ornaments, a garland and a glowing star.
    tree = Vector((CX, 37.6, 0))
    pine(m, tree, 9.0, 2.6)
    for k in range(26):
        t = k / 26
        z = 9.0 * (0.25 + 0.7 * t)
        r = 2.6 * (1.0 - 0.85 * t) * 0.92
        a = k * 2.4
        ball(m["GlobeOrnaments" if k % 2 else "GlobeRibbons"], tree + Vector((math.cos(a) * r, math.sin(a) * r, z)), 0.16, subdivisions=1)
    garland = [tree + Vector((math.cos(t * 18) * 2.5 * (1 - 0.85 * t), math.sin(t * 18) * 2.5 * (1 - 0.85 * t), 9.0 * (0.24 + 0.7 * t))) for t in [k / 120 for k in range(121)]]
    sweep(m["GlobeGarland"], garland, 0.06, segments=4)
    outline = [(tree.x + (0.7 if j % 2 == 0 else 0.3) * math.cos(math.pi / 2 + math.pi * j / 5), tree.z + 9.6 + (0.7 if j % 2 == 0 else 0.3) * math.sin(math.pi / 2 + math.pi * j / 5))
               for j in range(10)]
    slab(m["GlobeStar"], [Vector((x, tree.y, z)) for x, z in outline], 0.18, Vector((0, 1, 0)))
    for (dx, dy, s, mesh) in ((-1.6, -1.6, 0.8, "GlobeGiftsGreen"), (1.4, -1.8, 0.7, "GlobeGiftsBlue"), (0.2, -2.4, 0.6, "GlobeGiftsGreen")):
        c = tree + Vector((dx, dy, s / 2))
        box(m[mesh], c, (s, s, s))
        box(m["GlobeRibbons"], c, (s + 0.02, 0.1, s + 0.02))
    build_carousel(m)
    snowman(m, 12.4, 1.0, 0.8)
    snowman(m, -10.8, 33.6, 0.7)
    lamppost(m, -5.4, -7.6)
    lamppost(m, 7.8, 12.0)
    lamppost(m, -8.6, 23.4)
    # Drifts round the inside of the glass.
    for k in range(34):
        a = 2 * math.pi * k / 34
        p = edge_point(a, -2.0)
        if abs(p.x - DOOR_X[0]) < DOOR_X[1] + 1.0 and p.y < CY:
            continue
        blob(m["GlobeSnow"], p, Vector((rng.uniform(1.6, 2.6), rng.uniform(1.6, 2.6), rng.uniform(0.6, 1.3))), subdivisions=2, lump=0.15, seed=k, floor=0.0)
    return chimneys


def build_carousel(m):
    """A little carousel in the village: the platform, canopy stripes, poles and horses all turn
    about its centre (each mesh is symmetric, so it turns about its own middle); the horses also rise
    and fall together."""
    c = CAROUSEL
    lathe(m["GlobeBaseDark"], [(0, 0), (2.3, 0), (2.3, 0.3), (0, 0.3)], 24, transform=Matrix.Translation(c))
    disc(m["GlobeCarouselDeck"], c + Vector((0, 0, 0.42)), (0, 0, 1), 2.1, 0.2, segments=32)
    for k in range(16):
        a0, a1 = 2 * math.pi * k / 16, 2 * math.pi * (k + 1) / 16
        mesh = m["GlobeCarouselRed" if k % 2 == 0 else "GlobeCarouselWhite"]
        apex = c + Vector((0, 0, 5.4))
        rim = [c + Vector((math.cos(a) * 2.4, math.sin(a) * 2.4, 4.2)) for a in (a0, a1)]
        double_sided_poly(mesh, [apex, rim[0], rim[1]])
        double_sided_poly(mesh, [rim[0], rim[1], rim[1] - Vector((0, 0, 0.45)), rim[0] - Vector((0, 0, 0.45))])
    cylinder(m["GlobeCarouselPoles"], c + Vector((0, 0, 0.5)), (0, 0, 1), 3.8, 0.18, segments=12)
    ball(m["GlobeCarouselPoles"], c + Vector((0, 0, 5.55)), 0.2, subdivisions=2)
    for k in range(4):
        a = math.pi / 2 * k
        p = c + Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, 0))
        heading = Vector((-math.sin(a), math.cos(a), 0))
        cylinder(m["GlobeCarouselPoles"], p + Vector((0, 0, 0.5)), (0, 0, 1), 3.7, 0.05, segments=6)
        horse = m["GlobeCarouselHorses"]
        body = p + Vector((0, 0, 1.7))
        blob(horse, body, Vector((0.55, 0.55, 0.32)) + Vector((abs(heading.x), abs(heading.y), 0)) * 0.25, subdivisions=2, seed=k)
        neck = body + heading * 0.5 + Vector((0, 0, 0.35))
        sweep_radii(horse, [body + heading * 0.3, neck, neck + heading * 0.25 + Vector((0, 0, 0.25))], [0.16, 0.13, 0.12], segments=8)
        blob(horse, neck + heading * 0.4 + Vector((0, 0, 0.25)), Vector((0.14, 0.14, 0.12)) + Vector((abs(heading.x), abs(heading.y), 0)) * 0.12, subdivisions=1)
        for sh in (-1, 1):
            side = Vector((heading.y, -heading.x, 0)) * 0.18
            for sd in (-1, 1):
                tube(horse, body + heading * sh * 0.4 + side * sd + Vector((0, 0, -0.15)), body + heading * sh * 0.55 + side * sd + Vector((0, 0, -0.75)), 0.06, 5)
        box(m["GlobeCarouselRed"], body + Vector((0, 0, 0.32)), (0.4, 0.4, 0.08))


def build_pond(m):
    """A frozen pond with four skaters circling it (the skaters and their scarves turn about the
    pond's centre; four at quarter turns keep each mesh centred)."""
    disc(m["GlobeIcePond"], POND + Vector((0, 0, 0.06)), (0, 0, 1), 2.7, 0.1, segments=36)
    for k in range(18):
        a = 2 * math.pi * k / 18
        blob(m["GlobeSnow"], POND + Vector((math.cos(a) * 2.9, math.sin(a) * 2.9, 0)), Vector((0.6, 0.6, 0.35)), subdivisions=1, floor=0.0, seed=k)
    for k in range(4):
        a = math.pi / 2 * k
        p = POND + Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, 0.1))
        heading = Vector((-math.sin(a), math.cos(a), 0))
        lathe(m["GlobeSkaters"], [(0, 0.1), (0.18, 0.15), (0.28, 0.6), (0.22, 1.1), (0.14, 1.25), (0, 1.27)], 10, transform=Matrix.Translation(p))
        ball(m["GlobeSkaters"], p + Vector((0, 0, 1.45)), 0.2, subdivisions=1)
        torus(m["GlobeSkatersScarves"], p + Vector((0, 0, 1.22)), (0, 0, 1), 0.16, 0.06, segments=10, minor_segments=4)
        sweep(m["GlobeSkatersScarves"], [p + Vector((0, 0, 1.2)), p - heading * 0.45 + Vector((0, 0, 1.05))], 0.05, segments=4)
        box(m["GlobeSkaters"], p + heading * 0.05, (0.08, 0.5, 0.06), Matrix.Rotation(math.atan2(heading.y, heading.x) - math.pi / 2, 4, "Z"))


def snowflake(bm, centre, axis, radius, width, thickness, hub=0.0):
    """A six-armed snowflake standing normal to axis, with side branches on every arm."""
    c, n = Vector(centre), Vector(axis).normalized()
    e1, e2 = axes_of(n)
    for k in range(6):
        a = math.pi / 2 + math.pi / 3 * k
        d = e1 * math.cos(a) + e2 * math.sin(a)
        s = n.cross(d)
        start = c + d * hub
        end = c + d * radius
        slab(bm, [start - s * width / 2, end - s * width / 2, end + s * width / 2, start + s * width / 2], thickness, n)
        for t, length in ((0.5, 0.35), (0.75, 0.25)):
            root = c + d * radius * t
            for sgn in (-1, 1):
                tip = root + (d * 0.6 + s * sgn * 0.8).normalized() * radius * length
                slab(bm, [root - d * width * 0.4, tip, root + d * width * 0.4], thickness, n)


def build_flakes(m):
    for name, c in FLAKES.items():
        snowflake(m[name], c, (0, 1, 0.3), 1.6, 0.22, 0.12)
        disc(m[name], c, (0, 1, 0.3), 0.35, 0.16, segments=12)


# ---------- the sleigh and the ice snowflake screen ----------

def build_sleigh(m):
    """A red sleigh full of gifts; the ball rests on its curled front at PITCH."""
    gold, red = m["GlobeSleighGold"], m["GlobeSleigh"]
    for sx in (-1, 1):
        x = PITCH.x + sx * 1.15
        runner = [Vector((x, 31.0, 0.25)), Vector((x, 26.0, 0.25))]
        for k in range(1, 11):
            a = math.pi * k / 10
            runner.append(Vector((x, 26.0 - 1.1 * math.sin(a), 0.25 + 1.1 * (1 - math.cos(a)))))
        runner.append(Vector((x, 25.4, 2.4)))
        sweep(gold, runner, 0.11, segments=8)
        for y in (26.5, 29.5):
            tube(gold, (x, y, 0.25), (x, y, 1.05), 0.08, 6)
    # The body: a deep seat with high scrolled sides and a curled dash at the front.
    box(red, (PITCH.x, 28.6, 1.4), (2.6, 3.8, 0.7))
    for sx in (-1, 1):
        side = [(31.0, 1.05), (31.2, 3.4), (30.6, 3.9), (29.6, 3.2), (27.4, 2.4), (25.8, 2.2), (25.2, 1.6), (26.0, 1.05)]
        slab(red, [Vector((PITCH.x + sx * 1.32, y, z)) for y, z in side], 0.16, Vector((1, 0, 0)))
        sweep(gold, [Vector((PITCH.x + sx * 1.42, y, z)) for y, z in side] + [Vector((PITCH.x + sx * 1.42, 31.0, 1.05))], 0.06, segments=5)
    box(red, (PITCH.x, 30.9, 2.5), (2.6, 0.3, 2.6))
    line = Polyline([Vector((PITCH.x, 25.6, 1.1)), Vector((PITCH.x, 25.0, 1.9)), Vector((PITCH.x, 24.4, 2.45))])
    for p0, p1 in zip(line.samples(0.2), line.samples(0.2)[1:]):
        box(red, (p0 + p1) / 2, (2.6, (p1 - p0).length + 0.02, 0.18), Matrix.Rotation(math.atan2(p1.z - p0.z, -(p1.y - p0.y)), 4, "X"))
    torus(gold, (PITCH.x, PITCH.y + 0.15, PITCH.z - BALL_RADIUS - 0.12), (0, 0, 1), 0.3, 0.09, segments=14, minor_segments=5)
    sweep(gold, [Vector((PITCH.x - 1.3, 24.4, 2.5)), Vector((PITCH.x + 1.3, 24.4, 2.5))], 0.1, segments=6)
    # Gifts and a sack in the back.
    for (dx, dy, dz, s, mesh) in ((-0.6, 29.4, 2.2, 1.0, "GlobeGiftsGreen"), (0.6, 29.7, 2.0, 0.8, "GlobeGiftsBlue"), (0.1, 29.5, 2.95, 0.7, "GlobeGiftsBlue")):
        c = Vector((PITCH.x + dx, dy, dz))
        box(m[mesh], c, (s, s, s))
        box(m["GlobeRibbons"], c, (s + 0.02, 0.12, s + 0.02))
        box(m["GlobeRibbons"], c, (0.12, s + 0.02, s + 0.02))
        for sx in (-1, 1):
            torus(m["GlobeRibbons"], c + Vector((sx * 0.12, 0, s / 2 + 0.1)), (0, 1, 0), 0.12, 0.04, segments=10, minor_segments=3)
    blob(m["GlobeSack"], Vector((PITCH.x, 30.4, 2.7)), Vector((0.9, 0.7, 1.0)), subdivisions=2, lump=0.15, seed=2)
    pitch_ball(m["GlobeBall"])


def build_screen(m):
    """An ice snowflake as the screen, its hub round the window, frosted rims and icicles."""
    c = Vector((PITCH.x, SCREEN_Y, 3.3))
    ice, frost = m["GlobeIce"], m["GlobeFrost"]
    window_panel(ice, lambda a: ray_ellipse((PITCH.x, PITCH.z), (math.cos(a), math.sin(a)), (c.x, c.z), 1.75, 1.75), SCREEN_Y, 0.3, segments=48)
    snowflake(ice, c, (0, 1, 0), 3.3, 0.7, 0.26, hub=1.6)
    torus(frost, (PITCH.x, SCREEN_Y - 0.17, PITCH.z), (0, 1, 0), WINDOW + 0.12, 0.08, segments=36, minor_segments=5)
    torus(frost, (c.x, SCREEN_Y - 0.17, c.z), (0, 1, 0), 1.72, 0.07, segments=40, minor_segments=5)
    for k in range(6):
        a = math.pi / 2 + math.pi / 3 * k
        tip = c + Vector((math.cos(a), 0, math.sin(a))) * 3.3
        ball(frost, tip + Vector((0, -0.05, 0)), 0.22, subdivisions=2)
        if math.sin(a) > 0.1:
            for j in range(3):
                q = tip + Vector((math.cos(a + math.pi / 2) * (j - 1) * 0.2, 0, -0.1))
                lathe(m["GlobeIcicles"], [(0, 0), (0.07, 0), (0, -0.55 - 0.15 * j)], 6, transform=Matrix.Translation(q))
    blob(m["GlobeSnow"], Vector((PITCH.x, SCREEN_Y, 0.0)), Vector((2.2, 1.3, 0.7)), subdivisions=2, lump=0.1, floor=0.0, seed=5)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = meshes(LOOKS)
    build_dome(m)
    build_base(m)
    print("chimneys", [tuple(round(v, 2) for v in c) for c in build_village(m)])
    build_pond(m)
    build_flakes(m)
    build_sleigh(m)
    build_screen(m)
    home_plate(m["GlobePlate"], 0.08)
    objects = build_looks(coll, m, LOOKS)
    spins = {"GlobeKey": (KEY, (0, 1, 0)), "GlobeSkaters": (POND, (0, 0, 1)), "GlobeSkatersScarves": (POND, (0, 0, 1))}
    spins.update({name: (CAROUSEL, (0, 0, 1)) for name in ("GlobeCarouselDeck", "GlobeCarouselRed", "GlobeCarouselWhite", "GlobeCarouselPoles", "GlobeCarouselHorses")})
    check_centred(objects, spins)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
