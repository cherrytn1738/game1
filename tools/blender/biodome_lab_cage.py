# Training Ground 3 of World 3, Biodome Lab: a research greenhouse. A geodesic glass vault of
# white struts with glowing hub nodes and arched end ribs (the door kept open in its lattice),
# raised beds round the inside full of alien plants (glow-bulb stalks, fiddlehead ferns,
# pitcher plants, spore pods, glowing mushrooms), hanging baskets that sway, a misting tower
# whose sprinkler spins, a giant seed-pod plant that pitches from its glowing mouth at PITCH,
# a woven-vine screen with a budding vine ring round the window; and outside: hydroponic racks
# under magenta grow lights along both walls, specimen tubes and an alien tree with glowing
# fruit beyond the machine end.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; small
# builders (rrect, extrude, slab, ...) come from the top of solar_rooftop_cage.py. The mesh
# names are what TrainingCageStyles looks up for colors, materials and motion; LOOKS lists every
# mesh with its preview colour and shading ("hard", "smooth" or "soft" for pieces built
# double-sided or already facing outward).
SOLAR_ROOFTOP = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\solar_rooftop_cage.py"
_source = open(SOLAR_ROOFTOP, encoding="utf-8").read()
_marker = "# ---------- the cage ----------"
assert _marker in _source, "solar_rooftop_cage.py layout changed"
exec(_source.partition(_marker)[0])

COLLECTION = "BiodomeLabCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\BiodomeLabCage.fbx"

FRAME = (0.94, 0.97, 0.95)
GLASS = (0.68, 0.9, 0.8)
TEAL = (0.3, 1.0, 0.85)
LEAF = (0.18, 0.5, 0.25)
LEAF_LIGHT = (0.5, 0.85, 0.3)
ALIEN = (0.25, 0.65, 0.6)
VIOLET = (0.7, 0.35, 1.0)
MAGENTA = (1.0, 0.3, 0.75)
LIME = (0.7, 1.0, 0.3)
STALK = (0.42, 0.3, 0.5)
SOIL = (0.22, 0.15, 0.12)
rng = random.Random(83)

WALL, PEAK, EXPONENT = 4.5, 16.5, 2.4       # the vault: walls up to WALL, a superellipse to PEAK
CX, A = (LEFT_X + RIGHT_X) / 2, (RIGHT_X - LEFT_X) / 2
VAULT_Y = (BACK_Y - 0.2, FRONT_Y + 0.2)     # end lattices sit just outside the end walls
DOOR_POSTS = (DOOR[0] - 0.25, DOOR[1] + 0.25)
STRUT, NODE = 0.11, 0.2
MOUTH = Vector((PITCH.x, PITCH.y + 0.35, PITCH.z))   # the seed pod's lip; the ball leaves just in front

LOOKS = {
    "BioFrame": (FRAME, "soft"), "BioFrameSolid": (FRAME, "hard"), "BioNodes": (TEAL, "smooth"), "BioGlass": (GLASS, "soft"),
    "BioGlowTrim": (TEAL, "hard"), "BioBeds": ((0.9, 0.92, 0.9), "hard"), "BioSoil": (SOIL, "hard"), "BioMoss": ((0.3, 0.6, 0.25), "soft"),
    "BioPipes": ((0.75, 0.8, 0.82), "hard"), "BioPlate": (WHITE, "hard"),
    "BioPodBody": ((0.35, 0.2, 0.45), "smooth"), "BioPodLips": (MAGENTA, "soft"), "BioPodThroat": (LIME, "smooth"),
    "BioPodVeins": (LIME, "soft"), "BioPodLeaves": (LEAF, "soft"), "BioRoots": ((0.3, 0.2, 0.25), "soft"), "BioStalks": (STALK, "soft"),
    "BioSeeds": (WHITE, "smooth"),
    "BioVines": ((0.36, 0.42, 0.22), "soft"), "BioVineLeaves": (LEAF_LIGHT, "soft"), "BioVineGlow": (TEAL, "smooth"),
    "BioLeaves": (LEAF, "soft"), "BioLeavesLight": (LEAF_LIGHT, "soft"), "BioAlienLeaves": (ALIEN, "soft"),
    "BioGlowBulbs": ((0.4, 0.95, 1.0), "smooth"), "BioSporePods": (LIME, "smooth"), "BioFerns": ((0.35, 0.7, 0.3), "soft"),
    "BioPitchers": ((0.75, 0.2, 0.4), "smooth"), "BioMushroomStems": ((0.92, 0.9, 0.82), "smooth"),
    "BioMushroomCaps": (VIOLET, "smooth"), "BioMushroomCapsTeal": (TEAL, "smooth"),
    "BioTower": (FRAME, "hard"), "BioTank": (GLASS, "smooth"), "BioLiquid": (LIME, "smooth"), "BioSprinkler": ((0.75, 0.8, 0.82), "hard"),
    "BioRacks": (FRAME, "hard"), "BioTroughs": ((0.85, 0.88, 0.88), "hard"), "BioLettuce": (LEAF_LIGHT, "soft"),
    "BioGrowLights": (MAGENTA, "hard"),
    "BioTubeGlass": (GLASS, "smooth"), "BioTubeLiquid": (TEAL, "smooth"), "BioSpecimens": (VIOLET, "soft"),
    "BioTreeTrunk": ((0.4, 0.3, 0.42), "soft"), "BioTreeLeaves": ((0.2, 0.6, 0.55), "soft"), "BioTreeFruit": ((1.0, 0.75, 0.3), "smooth"),
    "BioBasketA": ((0.3, 0.58, 0.26), "soft"), "BioBasketB": ((0.3, 0.58, 0.26), "soft"), "BioBasketC": ((0.3, 0.58, 0.26), "soft"),
    "BioBasketD": ((0.3, 0.58, 0.26), "soft"),
}


# ---------- small builders ----------

def profile_x(z):
    """The vault's half-span at height z: (left x, right x)."""
    if z <= WALL:
        return LEFT_X, RIGHT_X
    dz = min(1.0, (z - WALL) / (PEAK - WALL))
    dx = A * max(0.0, 1 - dz ** EXPONENT) ** (1 / EXPONENT)
    return CX - dx, CX + dx


def profile_points(step=0.5):
    points = [Vector((LEFT_X, 0, z)) for z in arange(WALL, step)]
    for i in range(1, 64):
        t = math.pi * i / 64
        c, s = math.cos(t), math.sin(t)
        points.append(Vector((CX - A * math.copysign(abs(c) ** (2 / EXPONENT), c), 0, WALL + (PEAK - WALL) * abs(s) ** (2 / EXPONENT))))
    points += [Vector((RIGHT_X, 0, z)) for z in reversed(arange(WALL, step)[:-1])]
    return points


PROFILE = Polyline(profile_points())


def strip(a, b, key):
    """Triangles between two rows of points sorted by key (a strip triangulation)."""
    i = j = 0
    triangles = []
    while i < len(a) - 1 or j < len(b) - 1:
        if j == len(b) - 1 or (i < len(a) - 1 and key(a[i + 1]) <= key(b[j + 1])):
            triangles.append((a[i], a[i + 1], b[j]))
            i += 1
        else:
            triangles.append((a[i], b[j + 1], b[j]))
            j += 1
    return triangles


def strut(bm, a, b, radius=STRUT, sides=6):
    """An open six-sided tube whose faces point outward (its ends hide inside the nodes)."""
    a, b = Vector(a), Vector(b)
    t = (b - a).normalized()
    n = t.cross(Vector((0, 0, 1)))
    if n.length < 1e-3:
        n = t.cross(Vector((1, 0, 0)))
    n.normalize()
    k = t.cross(n)
    ring = [n * math.cos(2 * math.pi * i / sides) + k * math.sin(2 * math.pi * i / sides) for i in range(sides)]
    ra, rb = [bm.verts.new(a + d * radius) for d in ring], [bm.verts.new(b + d * radius) for d in ring]
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((ra[i], ra[j], rb[j], rb[i]))


def lattice_parts(m, triangles, glass_inset=0.16):
    """Struts on every edge, a node at every vertex and an inset double-sided pane per triangle."""
    edges, nodes = set(), set()
    def key(p):
        return (round(p.x, 3), round(p.y, 3), round(p.z, 3))
    for tri in triangles:
        keys = [key(p) for p in tri]
        nodes.update(keys)
        for i in range(3):
            edges.add(tuple(sorted((keys[i], keys[(i + 1) % 3]))))
        center = (tri[0] + tri[1] + tri[2]) / 3
        pane = [p + (center - p).normalized() * glass_inset for p in tri]
        double_sided_poly(m["BioGlass"], pane)
    for a, b in edges:
        strut(m["BioFrame"], a, b)
    for p in nodes:
        ball(m["BioNodes"], p, NODE, subdivisions=1)


def leaf_blade(bm, base, direction, length, width, droop=0.3, segments=5, cup=0.0):
    """A broad pointed leaf arching out from base (double-sided strip with a midrib bend)."""
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-3 else Vector((1, 0, 0))
    up = side.cross(d)
    left, right = [], []
    for i in range(segments + 1):
        t = i / segments
        p = Vector(base) + d * length * t - Vector((0, 0, droop * length * t * t))
        w = width * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.8 / 2 + 0.01
        left.append(p - side * w + up * cup * w)
        right.append(p + side * w + up * cup * w)
    double_sided_strip(bm, left, right)


def curl_stalk(bm, base, height, lean, curl, radius, seed, segments=18):
    """A stalk rising from base, leaning, and curling over at the top (returns the points)."""
    b = Vector(base)
    lean = Vector(lean)
    points = []
    for i in range(segments + 1):
        t = i / segments
        bend = lean * (t ** 1.6)
        curl_angle = curl * max(0.0, t - 0.6) / 0.4
        tip_curl = Vector((math.sin(curl_angle) * 0.15 * height * lean.normalized().x if lean.length else 0,
                           math.sin(curl_angle) * 0.15 * height * lean.normalized().y if lean.length else 0,
                           -(1 - math.cos(curl_angle)) * 0.12 * height))
        points.append(b + Vector((0, 0, height * t)) + bend + tip_curl + Vector((noise.noise(Vector((t * 3, seed, 0))) * 0.1,
                                                                                noise.noise(Vector((seed, t * 3, 1))) * 0.1, 0)))
    sweep_radii(bm, points, [radius * (1 - 0.6 * i / segments) for i in range(segments + 1)], segments=7)
    return points


def mushroom(m, base, height, cap, caps="BioMushroomCaps", tilt=0.0, heading=0.0):
    turn = Matrix.Translation(Vector(base)) @ Matrix.Rotation(heading, 4, "Z") @ Matrix.Rotation(tilt, 4, "X")
    r = cap * 0.22
    lathe(m["BioMushroomStems"], [(0, 0), (r * 1.4, 0), (r, height * 0.45), (r * 0.85, height), (0, height)], 10, transform=turn)
    h = cap * 0.7
    lathe(m[caps], [(0, height - 0.05), (cap * 0.35, height - 0.02), (cap * 0.98, height + h * 0.12), (cap, height + h * 0.3),
                    (cap * 0.75, height + h * 0.78), (cap * 0.35, height + h * 0.97), (0, height + h)], 14, transform=turn)


def rosette(bm, center, radius, leaves=6, lift=0.35):
    c, spin = Vector(center), rng.uniform(0, 2 * math.pi)
    for k in range(leaves):
        a = spin + 2 * math.pi * k / leaves
        d = Vector((math.cos(a), math.sin(a), lift))
        leaf(bm, c, d, (-math.sin(a), math.cos(a), 0), radius, radius * 0.8)
    for k in range(2):
        a = spin + math.pi * k + 0.5
        leaf(bm, c, (math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0), (-math.sin(a), math.cos(a), 0), radius * 0.7, radius * 0.6)


# ---------- the dome ----------

def build_dome(m):
    """The geodesic vault: a triangulated lattice over the cage and both end walls, end ribs, a
    base curb, the door frame with glowing trim and a misting pipe along the crown."""
    y0, y1 = VAULT_Y
    rows, nv, nu = [], 16, 16
    du = (y1 - y0) / nu
    for j in range(nv + 1):
        p = PROFILE.at(PROFILE.length * j / nv)
        ys = [y0 + du * i for i in range(nu + 1)] if j % 2 == 0 else [y0] + [y0 + du * (i + 0.5) for i in range(nu)] + [y1]
        rows.append([Vector((p.x, y, p.z)) for y in ys])
    triangles = []
    for a, b in zip(rows, rows[1:]):
        triangles += strip(a, b, key=lambda v: v.y)
    # End walls: rows at chosen heights; at the door end the rows below the door top are split
    # at the door posts and the doorway itself is left open.
    door_top = DOOR[2] + 0.5                 # the lattice row resting on the door header
    heights = [0.0, 2.25, WALL, 6.4, door_top, 10.2, 12.0, 13.7, 15.2]
    for y, door in ((y0, True), (y1, False)):
        end_rows = []
        for k, z in enumerate(heights):
            xl, xr = profile_x(z)
            breaks = [xl, DOOR_POSTS[0], DOOR_POSTS[1], xr] if door and z <= door_top + 1e-6 else [xl, xr]
            row = []
            for s0, s1 in zip(breaks, breaks[1:]):
                n = max(1, round((s1 - s0) / 3.0))
                xs = [s0 + (s1 - s0) * i / n for i in range(n + 1)]
                if k % 2 and n > 1:
                    xs = [s0] + [s0 + (s1 - s0) * (i + 0.5) / n for i in range(n)] + [s1]
                row += [x for x in xs if not row or abs(x - row[-1]) > 1e-6]
            end_rows.append([Vector((x, y, z)) for x in row])
        end_rows.append([Vector((CX, y, PEAK))])
        for k, (a, b) in enumerate(zip(end_rows, end_rows[1:])):
            pieces = [(a, b)]
            if door and heights[k] < door_top - 1e-6:
                pieces = []
                for lo, hi in ((-1e9, DOOR_POSTS[0]), (DOOR_POSTS[1], 1e9)):
                    pieces.append(([p for p in a if lo - 1e-6 <= p.x <= hi + 1e-6], [p for p in b if lo - 1e-6 <= p.x <= hi + 1e-6]))
            for pa, pb in pieces:
                triangles += strip(pa, pb, key=lambda v: v.x)
    lattice_parts(m, triangles)

    solid, trim = m["BioFrameSolid"], m["BioGlowTrim"]
    for y in (y0, y1):
        sweep_profile(solid, [p + Vector((0, y, 0)) for p in PROFILE.samples(0.5)], rrect(0.5, 0.42, 0.12))
    sweep_profile(solid, [Vector((CX, y0, PEAK + 0.05)), Vector((CX, y1, PEAK + 0.05))], rrect(0.32, 0.32, 0.1))
    # Base curb round the dome, open at the door.
    for x in (LEFT_X, RIGHT_X):
        box(m["BioBeds"], (x, (y0 + y1) / 2, 0.3), (0.7, y1 - y0 + 0.7, 0.6))
    box(m["BioBeds"], (CX, y1, 0.3), (RIGHT_X - LEFT_X - 0.7, 0.7, 0.6))
    for xa, xb in ((LEFT_X + 0.35, DOOR_POSTS[0] - 0.25), (DOOR_POSTS[1] + 0.25, RIGHT_X - 0.35)):
        box(m["BioBeds"], ((xa + xb) / 2, y0, 0.3), (xb - xa, 0.7, 0.6))
    # Door frame: rounded posts and header with glowing trim.
    for x in DOOR_POSTS:
        extrude(solid, (x, y0, 0.0), (x, y0, DOOR[2] + 0.5), rrect(0.5, 0.5, 0.15), up=(0, 1, 0))
        box(trim, (x, y0 - 0.27, DOOR[2] / 2 + 0.1), (0.14, 0.05, DOOR[2] - 0.4))
    extrude(solid, (DOOR_POSTS[0] - 0.25, y0, DOOR[2] + 0.25), (DOOR_POSTS[1] + 0.25, y0, DOOR[2] + 0.25), rrect(0.5, 0.5, 0.15))
    box(trim, ((DOOR[0] + DOOR[1]) / 2, y0 - 0.27, DOOR[2] + 0.25), (DOOR[1] - DOOR[0] + 0.3, 0.05, 0.12))
    # Misting pipe along the crown with nozzles, and two hanging grow-light bars.
    pipes = m["BioPipes"]
    crown = PEAK - 0.9
    tube(pipes, (CX, y0 + 1.0, crown), (CX, y1 - 1.0, crown), 0.08, segments=8)
    for y in arange(y1 - y0 - 4.0, 3.0):
        p = Vector((CX, y0 + 2.0 + y, crown))
        cylinder(pipes, p, (0, 0, -1), 0.3, 0.05, segments=6)
        lathe(pipes, [(0, 0), (0.1, 0), (0.06, 0.12), (0, 0.14)], 8, transform=Matrix.Translation(p - Vector((0, 0, 0.42))))
    for x in (CX - 6.5, CX + 6.5):
        z = profile_z_at(x) - 2.2
        for y in (y0 + 4.0, (y0 + y1) / 2, y1 - 4.0):
            tube(pipes, (x, y, profile_z_at(x) - 0.05), (x, y, z), 0.03, segments=4)
        box(m["BioRacks"], (x, (y0 + y1) / 2, z), (0.4, y1 - y0 - 7.0, 0.16))
        box(m["BioGrowLights"], (x, (y0 + y1) / 2, z - 0.1), (0.26, y1 - y0 - 7.4, 0.05))


def profile_z_at(x):
    """Height of the vault above x (inside the walls)."""
    dx = abs(x - CX) / A
    if dx >= 1:
        return WALL
    return WALL + (PEAK - WALL) * (1 - dx ** EXPONENT) ** (1 / EXPONENT)


# ---------- the seed pod (pitching machine) and the screen ----------

def build_seed_pod(m):
    """A giant seed-pod plant: a root mound, a swan-neck stem arching over the screen, a bulb
    whose glowing mouth faces the batter at PITCH, lip petals, veins, leaves and side pods."""
    body, roots = m["BioPodBody"], m["BioRoots"]
    base = Vector((PITCH.x, PITCH.y + 4.6, 0.0))
    for center, size, seed in (((0, 0, 0.5), (2.4, 2.1, 1.1), 1.0), ((0.9, 0.6, 0.35), (1.4, 1.3, 0.7), 2.0),
                               ((-1.0, 0.4, 0.3), (1.3, 1.5, 0.6), 3.0), ((0.2, -1.2, 0.25), (1.2, 1.0, 0.5), 4.0)):
        blob(roots, base + Vector(center), Vector(size), subdivisions=3, lump=0.25, lump_scale=1.6, seed=seed, floor=0.0)
    # Roots snaking out over the floor from under the mound.
    for k in range(8):
        a = 2 * math.pi * k / 8 + rng.uniform(-0.25, 0.25)
        points = []
        for i in range(10):
            t = i / 9
            bend = a + 0.5 * math.sin(t * 3.0 + k)
            r = 1.5 + 2.6 * t
            points.append(base + Vector((math.cos(bend) * r, math.sin(bend) * r, 0.55 * (1 - t) ** 2 + 0.06)))
        sweep_radii(roots, points, [0.3 * (1 - 0.85 * i / 9) for i in range(10)], segments=7)
    # Stem: up out of the mound, over in an arch, down into the back of the bulb.
    stem = [base + Vector((0, 0.2, 0.8)), base + Vector((0, 0.8, 3.0)), base + Vector((0, 1.0, 5.6)), base + Vector((0, 0.5, 7.7)),
            base + Vector((0, -0.7, 8.7)), base + Vector((0, -1.9, 8.3)), base + Vector((0, -2.5, 6.8)), base + Vector((0, -2.0, 5.3)),
            MOUTH + Vector((0, 2.65, 1.45))]
    path = Polyline(stem).samples(0.3)
    sweep_radii(m["BioStalks"], path, [0.62 - 0.27 * i / (len(path) - 1) for i in range(len(path))], segments=12)
    for t, side in ((0.25, 1), (0.42, -1), (0.6, 1)):
        p = path[int(t * (len(path) - 1))]
        ring_points = [p + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, -0.05 * math.sin(3 * a))) for a in [2 * math.pi * i / 16 for i in range(17)]]
        sweep(m["BioPodVeins"], ring_points, 0.04, segments=5)
        leaf_blade(m["BioPodLeaves"], p, (side * 1.0, 0.3, 0.4), 2.6, 1.2, droop=0.35, cup=0.3)
    # The bulb: a lathe along -Y, mouth rim at MOUTH.
    along_y = Matrix.Translation(MOUTH) @ Matrix.Rotation(-math.pi / 2, 4, "X")
    bulb = [(0, 1.0), (0.42, 0.72), (0.7, 0.28), (0.78, 0.04), (0.9, 0.0), (1.1, 0.1), (1.52, 0.5), (1.82, 1.1), (1.88, 1.75),
            (1.7, 2.45), (1.2, 3.05), (0.66, 3.4), (0.32, 3.55), (0, 3.6)]
    lathe(body, bulb, 40, transform=along_y)
    lathe(m["BioPodThroat"], [(0, 0.97), (0.41, 0.69), (0.68, 0.26), (0.76, 0.05), (0.74, 0.04), (0.66, 0.25), (0.39, 0.66), (0, 0.93)], 40,
          transform=along_y)

    def radius_at(d):
        for (r0, d0), (r1, d1) in zip(bulb[4:], bulb[5:]):
            if d0 <= d <= d1:
                return r0 + (r1 - r0) * (d - d0) / (d1 - d0)
        return 0.3
    for k in range(10):
        a = 2 * math.pi * k / 10
        vein = []
        for i in range(17):
            d = 0.15 + 3.1 * i / 16
            wobble = 0.12 * math.sin(i * 0.9 + k)
            r = radius_at(d) + 0.025
            vein.append(along_y @ Vector((math.cos(a + wobble) * r, math.sin(a + wobble) * r, d)))
        frames = sweep_frames(vein)
        outward = [(v - along_y @ Vector((0, 0, 0.15 + 3.1 * i / 16))).normalized() for i, v in enumerate(vein)]
        sides = [outward[i].cross(frames[i][0]).normalized() * 0.05 for i in range(len(vein))]
        double_sided_strip(m["BioPodVeins"], [v - s for v, s in zip(vein, sides)], [v + s for v, s in zip(vein, sides)])
    # Lip petals curling back from the rim (they stay behind the ball).
    for k in range(6):
        a = 2 * math.pi * k / 6 + math.pi / 6

        def petal(u, v, a=a):
            width = 0.55 * math.sin(math.pi * min(1.0, 0.15 + u * 0.95)) + 0.05
            angle = a + (v - 0.5) * width
            r = 0.94 + 1.1 * u
            d = 0.02 + 0.85 * u * u + 0.12 * abs(v - 0.5)
            return along_y @ Vector((math.cos(angle) * r, math.sin(angle) * r, d))
        grid_surface(m["BioPodLips"], petal, 8, 4)
    # Two small unripe pods on side stems, glowing at their tips.
    for side in (-1, 1):
        start = path[int(0.35 * (len(path) - 1))]
        tip = start + Vector((side * 1.9, 0.3, 0.6))
        sweep_radii(m["BioStalks"], [start, start.lerp(tip, 0.5) + Vector((0, 0, 0.5)), tip], [0.16, 0.12, 0.08], segments=8)
        blob(body, tip + Vector((0, 0, 0.0)), Vector((0.42, 0.42, 0.55)), subdivisions=2, lump=0.1)
        ball(m["BioPodThroat"], tip + Vector((0, 0, -0.5)), 0.16, subdivisions=2)
    # Tendrils curling off the stem.
    for t, side in ((0.5, 1), (0.7, -1), (0.85, 1)):
        p = path[int(t * (len(path) - 1))]
        spiral = [p + Vector((side * (0.2 + 0.08 * i), 0.0, 0.0)) +
                  Vector((side * 0.25 * math.cos(i * 0.7) * (1 - i / 18), 0.25 * math.sin(i * 0.7) * (1 - i / 18), -0.04 * i)) for i in range(18)]
        sweep_radii(m["BioStalks"], spiral, [0.06 - 0.003 * i for i in range(18)], segments=5)
    # Big leaves round the mound and a pile of seeds (practice balls).
    for k in range(9):
        a = 2 * math.pi * k / 9 + 0.4
        leaf_blade(m["BioPodLeaves"], base + Vector((math.cos(a) * 1.1, math.sin(a) * 1.1, 1.0)), (math.cos(a), math.sin(a), 0.7),
                   rng.uniform(2.2, 3.0), rng.uniform(1.4, 1.8), droop=0.55, segments=8, cup=0.45)
    for offset in ((2.3, -0.6, 0.3), (2.7, -0.2, 0.3), (2.4, 0.2, 0.3), (2.55, -0.25, 0.68), (-2.4, -0.4, 0.3), (-2.7, 0.0, 0.3)):
        ball(m["BioSeeds"], base + Vector(offset), 0.3, subdivisions=2)
    home_plate(m["BioPlate"], 0.08)


def build_screen(m):
    """A woven-vine screen between two twisted vine posts, a budding vine ring round the window,
    leaves and glowing buds."""
    vines, glow = m["BioVines"], m["BioVineGlow"]
    # Kept low and loosely woven so the seed pod shows over and through it (the invisible
    # screen block is unchanged).
    x0, x1, top = PITCH.x - 3.3, PITCH.x + 3.3, 5.3
    opening = WINDOW + 0.12
    # Twisted posts arching over the top.
    arch = [Vector((x0 - 0.2, SCREEN_Y, 0.0)), Vector((x0 - 0.25, SCREEN_Y, 3.0)), Vector((x0 - 0.1, SCREEN_Y, 5.3)),
            Vector((x0 + 0.8, SCREEN_Y, 6.25)), Vector((PITCH.x, SCREEN_Y, 6.55)), Vector((x1 - 0.8, SCREEN_Y, 6.25)),
            Vector((x1 + 0.1, SCREEN_Y, 5.3)), Vector((x1 + 0.25, SCREEN_Y, 3.0)), Vector((x1 + 0.2, SCREEN_Y, 0.0))]
    line = Polyline(arch).samples(0.25)
    frames = sweep_frames(line)
    for strand_index in range(3):
        path, radii = [], []
        for i, (p, (t, n, b)) in enumerate(zip(line, frames)):
            s = i / (len(line) - 1)
            angle = 2 * math.pi * (strand_index / 3 + s * 6)
            thick = 1 - math.sin(math.pi * s) * 0.6
            path.append(p + (n * math.cos(angle) + b * math.sin(angle)) * 0.16 * thick)
            radii.append(0.13 + 0.09 * thick)
        sweep_radii(vines, path, radii, segments=7)
    # The weave: wavy horizontal and vertical runs that dip in and out, clear of the window.
    def runs(points):
        out, run = [], []
        for p in points:
            if math.hypot(p.x - PITCH.x, p.z - PITCH.z) < opening + 0.05:
                if len(run) > 1:
                    out.append(run)
                run = []
            else:
                run.append(p)
        if len(run) > 1:
            out.append(run)
        return out
    for row, z in enumerate([0.4 + 0.7 * k for k in range(8)]):
        points = [Vector((x0 + (x1 - x0) * i / 34, SCREEN_Y + 0.08 * math.sin(math.pi * i / 4.25 + row * math.pi), z + 0.05 * math.sin(i * 0.8)))
                  for i in range(35)]
        for run in runs(points):
            sweep(vines, run, 0.06, segments=5)
    for col, x in enumerate([x0 + 0.4 + 0.84 * k for k in range(7)]):
        points = [Vector((x + 0.05 * math.sin(i * 0.9), SCREEN_Y + 0.08 * math.sin(math.pi * i / 2.75 + col * math.pi + math.pi / 2), 0.25 + (top - 0.3) * i / 22))
                  for i in range(23)]
        for run in runs(points):
            sweep(vines, run, 0.055, segments=5)
    # The window ring: a thick knotted vine loop with glowing buds round it.
    ring = []
    for i in range(49):
        a = 2 * math.pi * i / 48
        r = opening + 0.12 + 0.04 * math.sin(a * 5)
        ring.append(Vector((PITCH.x + math.cos(a) * r, SCREEN_Y - 0.05 + 0.05 * math.sin(a * 3), PITCH.z + math.sin(a) * r)))
    sweep_radii(vines, ring, [0.16 + 0.04 * math.sin(i * 0.9) for i in range(49)], segments=8)
    for k in range(10):
        a = 2 * math.pi * k / 10 + 0.2
        p = Vector((PITCH.x + math.cos(a) * (opening + 0.38), SCREEN_Y - 0.22, PITCH.z + math.sin(a) * (opening + 0.38)))
        ball(glow, p, 0.11 if k % 2 else 0.08, subdivisions=2)
    # Leaves tucked into the weave and glowing buds dotted over it.
    for _ in range(70):
        x, z = rng.uniform(x0, x1), rng.uniform(0.4, top)
        if math.hypot(x - PITCH.x, z - PITCH.z) < opening + 0.5:
            continue
        side = rng.choice((-1, 1))
        a = rng.uniform(0, 2 * math.pi)
        leaf(m["BioVineLeaves"], (x, SCREEN_Y + side * 0.1, z), (math.cos(a) * 0.8, side * 0.6, math.sin(a) * 0.8),
             (math.sin(a), 0, -math.cos(a)), rng.uniform(0.35, 0.55), 0.24)
    for _ in range(14):
        x, z = rng.uniform(x0 + 0.2, x1 - 0.2), rng.uniform(0.6, top - 0.2)
        if math.hypot(x - PITCH.x, z - PITCH.z) < opening + 0.6:
            continue
        ball(glow, (x, SCREEN_Y + rng.choice((-0.12, 0.12)), z), 0.07, subdivisions=1)


# ---------- planting inside ----------

def raised_bed(m, x0, x1, y0, y1, height=0.55):
    """A white-edged raised bed with dark soil and moss tufts; returns the soil height."""
    beds = m["BioBeds"]
    w = 0.22
    box(beds, ((x0 + x1) / 2, y0 + w / 2, height / 2), (x1 - x0, w, height))
    box(beds, ((x0 + x1) / 2, y1 - w / 2, height / 2), (x1 - x0, w, height))
    box(beds, (x0 + w / 2, (y0 + y1) / 2, height / 2), (w, y1 - y0 - 2 * w, height))
    box(beds, (x1 - w / 2, (y0 + y1) / 2, height / 2), (w, y1 - y0 - 2 * w, height))
    box(m["BioSoil"], ((x0 + x1) / 2, (y0 + y1) / 2, height / 2 - 0.04), (x1 - x0 - 2 * w + 0.02, y1 - y0 - 2 * w + 0.02, height - 0.08))
    for _ in range(int((x1 - x0) * (y1 - y0) / 2.5)):
        p = Vector((rng.uniform(x0 + 0.4, x1 - 0.4), rng.uniform(y0 + 0.4, y1 - 0.4), height - 0.08))
        s = rng.uniform(0.3, 0.6)
        blob(m["BioMoss"], p, Vector((s, s, s * 0.35)), subdivisions=1, lump=0.3, seed=rng.random() * 9)
    return height - 0.06


def glowbulb_plant(m, base, height, count=4):
    b = Vector(base)
    for k in range(count):
        a = 2 * math.pi * k / count + rng.uniform(-0.4, 0.4)
        lean = Vector((math.cos(a), math.sin(a), 0)) * height * rng.uniform(0.15, 0.3)
        h = height * rng.uniform(0.65, 1.0)
        points = curl_stalk(m["BioStalks"], b + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0)), h, lean, rng.uniform(1.0, 2.4),
                            0.09, rng.random() * 9)
        tip = points[-1]
        blob(m["BioGlowBulbs"], tip, Vector((0.26, 0.26, 0.34)) * rng.uniform(0.8, 1.2), subdivisions=2, lump=0.1, seed=rng.random() * 9)
    for k in range(5):
        a = 2 * math.pi * k / 5 + rng.uniform(-0.3, 0.3)
        leaf_blade(m["BioAlienLeaves"], b + Vector((0, 0, 0.1)), (math.cos(a), math.sin(a), 0.6), height * 0.45, height * 0.22, droop=0.4, cup=0.3)


def fern(m, base, height, fronds=6):
    b = Vector(base)
    for k in range(fronds):
        a = 2 * math.pi * k / fronds + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        uncurled = k % 3 != 0
        points = []
        steps = 16 if uncurled else 30
        for i in range(steps + 1):
            t = i / steps
            if uncurled:
                p = b + d * height * 0.55 * t + Vector((0, 0, height * (1.2 * t - 0.5 * t * t)))
            elif t < 0.45:
                # A fiddlehead: up the stalk, then rolled into a tightening spiral at the top.
                p = b + d * 0.25 * t / 0.45 + Vector((0, 0, height * 0.85 * t / 0.45))
            else:
                s = (t - 0.45) / 0.55
                angle = s * 1.8 * math.pi
                r = 0.32 * (1 - 0.75 * s)
                center = b + d * (0.25 + 0.32) + Vector((0, 0, height * 0.85))
                p = center + d * (-r * math.cos(angle)) + Vector((0, 0, r * math.sin(angle)))
            points.append(p)
        sweep_radii(m["BioFerns"], points, [0.05 - 0.035 * i / steps for i in range(steps + 1)], segments=5)
        if uncurled:
            for i in range(3, steps - 1, 2):
                for side in (-1, 1):
                    normal = (points[i + 1] - points[i - 1]).normalized().cross(Vector((0, 0, 1))).normalized() * side
                    leaf(m["BioFerns"], points[i], normal + Vector((0, 0, 0.25)), (points[i + 1] - points[i - 1]).normalized(),
                         0.45 * (1 - i / steps) + 0.12, 0.16)


def pitcher(m, base, height, heading):
    b = Vector(base)
    turn = Matrix.Translation(b) @ Matrix.Rotation(heading, 4, "Z") @ Matrix.Rotation(0.12, 4, "X")
    r = height * 0.18
    lathe(m["BioPitchers"], [(0, 0), (r * 0.6, 0), (r, height * 0.35), (r * 0.8, height * 0.75), (r * 1.05, height * 0.95), (r * 1.15, height),
                             (r * 0.95, height), (r * 0.7, height * 0.8), (0, height * 0.75)], 14, transform=turn)
    lid = turn @ Vector((0, r * 0.6, height * 1.05))
    blob(m["BioPitchers"], lid, Vector((r * 1.0, r * 0.7, r * 0.18)), subdivisions=2)
    ball(m["BioGlowBulbs"], turn @ Vector((0, 0, height * 0.9)), r * 0.45, subdivisions=2)


def spore_cluster(m, base, count, spread, height):
    b = Vector(base)
    for _ in range(count):
        start = b + Vector((rng.uniform(-spread, spread), rng.uniform(-spread, spread), 0))
        top = start + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), height * rng.uniform(0.4, 1.0)))
        sweep(m["BioStalks"], wavy(start, top, 5, 0.08, seed=rng.random() * 9), 0.05, segments=5)
        blob(m["BioSporePods"], top + Vector((0, 0, 0.18)), Vector((0.24, 0.24, 0.3)) * rng.uniform(0.8, 1.3), subdivisions=2, lump=0.15,
             seed=rng.random() * 9)


def build_planting(m):
    """Raised beds round the inside, full of alien plants, spore pods and glowing mushrooms."""
    soil = raised_bed(m, LEFT_X + 0.45, LEFT_X + 3.4, -8.0, 30.0)
    soil_r = raised_bed(m, RIGHT_X - 3.2, RIGHT_X - 0.45, -12.6, 29.0)
    soil_f = raised_bed(m, LEFT_X + 0.45, RIGHT_X - 0.45, 30.6, FRONT_Y - 0.45)
    lx, rx = LEFT_X + 1.9, RIGHT_X - 1.8
    plan = [("bulb", lx, -5.5, 3.6), ("mush", lx, -2.5, 1.0), ("fern", lx, 0.8, 2.6), ("spore", lx, 4.0, 1.8), ("pitcher", lx, 7.0, 2.4),
            ("bulb", lx, 10.5, 4.4), ("mush", lx, 14.0, 1.4), ("fern", lx, 17.5, 3.0), ("spore", lx, 21.0, 2.2), ("bulb", lx, 25.0, 3.8),
            ("mush", lx, 28.3, 1.2),
            ("fern", rx, -10.5, 2.4), ("mush", rx, -7.0, 1.2), ("spore", rx, -3.5, 1.8), ("bulb", rx, 0.5, 3.4), ("pitcher", rx, 4.5, 2.6),
            ("fern", rx, 8.5, 2.8), ("mush", rx, 12.0, 1.0), ("bulb", rx, 15.5, 4.2), ("spore", rx, 19.0, 2.0), ("fern", rx, 22.5, 2.6),
            ("mush", rx, 26.0, 1.3),
            ("bulb", -13.5, 32.2, 4.6), ("fern", -10.0, 32.3, 3.0), ("spore", -6.8, 32.2, 2.0), ("mush", -3.8, 32.4, 1.3),
            ("pitcher", 8.2, 32.2, 2.8), ("spore", 5.6, 32.6, 1.6)]
    for kind, x, y, size in plan:
        s = soil if x < -10 and y < 30 else (soil_r if x > 9 and y < 29 else soil_f)
        if kind == "bulb":
            glowbulb_plant(m, (x, y, s), size)
        elif kind == "fern":
            fern(m, (x, y, s), size)
        elif kind == "spore":
            spore_cluster(m, (x, y, s), 6, 0.6, size)
        elif kind == "pitcher":
            pitcher(m, (x - 0.3, y, s), size, rng.uniform(0, 6.28))
            pitcher(m, (x + 0.4, y + 0.5, s), size * 0.7, rng.uniform(0, 6.28))
        else:
            for k in range(4):
                caps = "BioMushroomCaps" if k % 2 == 0 else "BioMushroomCapsTeal"
                mushroom(m, (x + rng.uniform(-0.6, 0.6), y + rng.uniform(-0.8, 0.8), s), size * rng.uniform(0.6, 1.1),
                         size * rng.uniform(0.35, 0.55), caps=caps, tilt=rng.uniform(-0.2, 0.2), heading=rng.uniform(0, 6.28))
    # Broad leaves filling the beds between the plants.
    for x, y0, y1, s in ((lx, -7.5, 29.5, soil), (rx, -12.0, 28.5, soil_r)):
        for y in arange(y1 - y0, 1.4):
            a = rng.uniform(0, 2 * math.pi)
            name = "BioLeaves" if rng.random() < 0.6 else "BioLeavesLight"
            leaf_blade(m[name], (x + rng.uniform(-0.8, 0.8), y0 + y, s + 0.05), (math.cos(a), math.sin(a), 0.5), rng.uniform(1.0, 1.6),
                       rng.uniform(0.5, 0.8), droop=0.45, cup=0.25)
    # The misting tower in the front-right corner; its sprinkler head spins.
    t = Vector((RIGHT_X - 2.3, FRONT_Y - 2.3, soil_f))
    lathe(m["BioTower"], [(0, 0), (1.05, 0), (1.05, 0.2), (0.95, 0.25), (0, 0.25)], 24, transform=Matrix.Translation(t))
    lathe(m["BioTank"], [(0, 0.25), (0.9, 0.25), (0.92, 1.6), (0.7, 1.85), (0, 1.9)], 24, transform=Matrix.Translation(t))
    lathe(m["BioLiquid"], [(0, 0.3), (0.84, 0.3), (0.85, 1.25), (0, 1.25)], 24, transform=Matrix.Translation(t))
    lathe(m["BioTower"], [(0, 1.8), (0.32, 1.8), (0.26, 7.9), (0.42, 8.0), (0.42, 8.25), (0, 8.3)], 20, transform=Matrix.Translation(t))
    for z in (3.6, 5.3, 7.0):
        torus(m["BioPipes"], t + Vector((0, 0, z)), (0, 0, 1), 0.62, 0.06, segments=24, minor_segments=5)
        for k in range(6):
            a = 2 * math.pi * k / 6
            d = Vector((math.cos(a), math.sin(a), 0))
            tube(m["BioPipes"], t + Vector((0, 0, z)) + d * 0.25, t + Vector((0, 0, z)) + d * 0.62, 0.035, segments=4)
            cylinder(m["BioPipes"], t + Vector((0, 0, z)) + d * 0.62, d + Vector((0, 0, 0.3)), 0.18, 0.05, segments=6, radius_top=0.08)
    sprinkler = m["BioSprinkler"]
    head = t + Vector((0, 0, 8.55))
    cylinder(m["BioTower"], t + Vector((0, 0, 8.2)), (0, 0, 1), 0.62, 0.08, segments=10)
    lathe(sprinkler, [(0, -0.15), (0.16, -0.15), (0.16, 0.15), (0, 0.15)], 12, transform=Matrix.Translation(head))
    for k in range(4):
        a = math.pi * k / 2
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(sprinkler, head + d * 0.12, head + d * 0.9 + Vector((0, 0, 0.12)), 0.04, segments=5)
        cylinder(sprinkler, head + d * 0.9 + Vector((0, 0, 0.12)), Vector((-d.y, d.x, 0)), 0.18, 0.05, segments=6)
    # Hanging moss-ball planters with trailing vines, each its own mesh (they bob gently).
    for index, (x, y) in enumerate(((-7.5, 6.0), (6.5, 10.0), (-6.5, 22.0), (7.5, 18.0))):
        bm = m["BioBasket" + "ABCD"[index]]
        z = profile_z_at(x) - 0.2
        ball_at = Vector((x, y, z - 3.0))
        for k in range(3):
            a = 2 * math.pi * k / 3
            tube(bm, (x, y, z + 0.35), ball_at + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.5)), 0.015, segments=4)
        blob(bm, ball_at, Vector((0.62, 0.62, 0.58)), subdivisions=2, lump=0.3, lump_scale=2.2, seed=index + 1.0)
        for k in range(7):
            a = 2 * math.pi * k / 7 + index
            leaf(bm, ball_at + Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.35)), (math.cos(a), math.sin(a), 0.9), (0, 0, 1), 0.55, 0.32)
        for k in range(8):
            a = 2 * math.pi * k / 8 + 0.3
            start = ball_at + Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, -0.25))
            length = rng.randint(4, 7)
            trail = [start + Vector((math.cos(a) * 0.2 * i / 6, math.sin(a) * 0.2 * i / 6, -0.3 * i)) for i in range(length)]
            for i in range(length - 1):
                leaf(bm, trail[i], (math.cos(a + i), math.sin(a + i), -0.4), (0, 0, 1), 0.3, 0.22)
            sweep(bm, trail, 0.02, segments=4)


# ---------- outside ----------

def build_hydroponics(m):
    """Two-tier hydroponic racks along both outside walls: white frames, NFT troughs of lettuce
    under magenta grow-light bars."""
    racks, troughs = m["BioRacks"], m["BioTroughs"]
    for xc in (LEFT_X - 2.9, RIGHT_X + 2.9):
        for y0, y1 in ((-11.0, 2.0), (4.0, 17.0), (19.0, 32.0)):
            for y in arange(y1 - y0, 3.25):
                for dx in (-1.05, 1.05):
                    extrude(racks, (xc + dx, y0 + y, 0.0), (xc + dx, y0 + y, 4.7), rrect(0.12, 0.12, 0.03), up=(1, 0, 0))
            for z, ceiling in ((1.1, 2.66), (2.9, 4.7)):
                for dx in (-0.55, 0.55):
                    extrude(troughs, (xc + dx, y0, z), (xc + dx, y1, z), [(-0.32, -0.12), (0.32, -0.12), (0.32, 0.12), (-0.32, 0.12)])
                    for y in arange(y1 - y0 - 0.6, 0.95):
                        rosette(m["BioLettuce"], (xc + dx, y0 + 0.3 + y, z + 0.13), 0.45, leaves=5)
                box(racks, (xc, (y0 + y1) / 2, z - 0.2), (2.2, y1 - y0, 0.08))
                box(m["BioGrowLights"], (xc, (y0 + y1) / 2, ceiling - 0.04), (1.6, y1 - y0 - 0.4, 0.06))
            box(racks, (xc, (y0 + y1) / 2, 4.75), (2.3, y1 - y0 + 0.2, 0.1))
            tube(m["BioPipes"], (xc, y0, 0.3), (xc, y1, 0.3), 0.07, segments=8)


def build_backdrop(m):
    """Beyond the machine end: specimen tubes with glowing liquid and floating plants, and an
    alien tree with glowing fruit in the outside corner."""
    for x, y, h in ((-9.5, 37.6, 6.0), (-5.0, 38.2, 5.0), (9.5, 37.8, 5.6)):
        b = Vector((x, y, 0))
        lathe(m["BioTower"], [(0, 0), (1.25, 0), (1.25, 0.5), (1.05, 0.65), (0, 0.65)], 24, transform=Matrix.Translation(b))
        lathe(m["BioTubeGlass"], [(0, 0.6), (0.9, 0.6), (0.9, h), (0, h)], 24, transform=Matrix.Translation(b))
        lathe(m["BioTubeLiquid"], [(0, 0.65), (0.82, 0.65), (0.82, h - 0.6), (0, h - 0.6)], 24, transform=Matrix.Translation(b))
        lathe(m["BioTower"], [(0, h - 0.05), (1.05, h - 0.05), (1.05, h + 0.4), (0.6, h + 0.6), (0, h + 0.65)], 24, transform=Matrix.Translation(b))
        torus(m["BioGlowTrim"], b + Vector((0, 0, 0.62)), (0, 0, 1), 1.0, 0.05, segments=28, minor_segments=5)
        tube(m["BioPipes"], b + Vector((0.4, 0.3, h + 0.5)), b + Vector((0.4, 2.4, h + 0.5)), 0.1, segments=8)
        tube(m["BioPipes"], b + Vector((0.4, 2.4, h + 0.5)), b + Vector((0.4, 2.4, 0.0)), 0.1, segments=8)
        # The specimen: a floating alien plant.
        c = b + Vector((0, 0, h * 0.5))
        for k in range(6):
            a = 2 * math.pi * k / 6
            leaf_blade(m["BioSpecimens"], c, (math.cos(a), math.sin(a), 0.8 if k % 2 else -0.3), 0.75, 0.45, droop=0.1, cup=0.3)
        for k in range(4):
            a = 2 * math.pi * k / 4 + 0.4
            sweep(m["BioSpecimens"], wavy(c, c + Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, -1.3)), 6, 0.08, seed=k + x), 0.03, segments=4)
        ball(m["BioGlowBulbs"], c + Vector((0, 0, 0.25)), 0.16, subdivisions=2)
    # The alien tree: a twisting trunk, an umbrella of long glowing-veined leaves, hanging fruit.
    base = Vector((-18.0, 40.0, 0))
    trunk = [base, base + Vector((0.3, 0.2, 3.0)), base + Vector((-0.4, -0.2, 6.5)), base + Vector((0.2, 0.3, 10.0)), base + Vector((0.0, 0.0, 12.6))]
    line = Polyline(trunk).samples(0.4)
    frames = sweep_frames(line)
    for strand_index in range(3):
        path = [p + (n * math.cos(2 * math.pi * (strand_index / 3 + i * 0.06)) + b * math.sin(2 * math.pi * (strand_index / 3 + i * 0.06))) * 0.35
                for i, (p, (t, n, b)) in enumerate(zip(line, frames))]
        sweep_radii(m["BioTreeTrunk"], path, [0.45 - 0.3 * i / (len(path) - 1) for i in range(len(path))], segments=8)
    for k in range(7):
        a = 2 * math.pi * k / 7
        d = Vector((math.cos(a), math.sin(a), 0))
        start = base + Vector((0, 0, 10.0 + 0.4 * (k % 3)))
        sweep_radii(m["BioTreeTrunk"], [start, start + d * 1.6 + Vector((0, 0, 1.6)), start + d * 3.0 + Vector((0, 0, 1.8))], [0.2, 0.13, 0.07], segments=7)
        top = start + Vector((0, 0, 2.2))
        leaf_blade(m["BioTreeLeaves"], top, (math.cos(a + 0.3), math.sin(a + 0.3), 0.15), 4.0, 1.7, droop=0.45, cup=0.3)
        leaf_blade(m["BioTreeLeaves"], top + Vector((0, 0, 0.4)), (math.cos(a - 0.25), math.sin(a - 0.25), 0.5), 3.2, 1.3, droop=0.35, cup=0.3)
        fruit_at = start + d * 2.6 + Vector((0, 0, 1.6))
        sweep(m["BioTreeTrunk"], [fruit_at, fruit_at - Vector((0, 0, 1.1))], 0.03, segments=4)
        blob(m["BioTreeFruit"], fruit_at - Vector((0, 0, 1.35)), Vector((0.28, 0.28, 0.36)), subdivisions=2, lump=0.1, seed=k)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.2
        start = base + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.8))
        sweep_radii(m["BioTreeTrunk"], [start, start + Vector((math.cos(a) * 1.0, math.sin(a) * 1.0, -0.5)),
                                        start + Vector((math.cos(a) * 1.8, math.sin(a) * 1.8, -0.8))], [0.3, 0.18, 0.05], segments=7)
    for k in range(5):
        a = rng.uniform(0, 2 * math.pi)
        mushroom(m, base + Vector((math.cos(a) * 2.6, math.sin(a) * 2.6, 0)), rng.uniform(0.8, 1.8), rng.uniform(0.4, 0.8),
                 caps="BioMushroomCapsTeal" if k % 2 else "BioMushroomCaps", heading=a)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = {name: bmesh.new() for name in LOOKS}
    build_dome(m)
    build_seed_pod(m)
    build_screen(m)
    build_planting(m)
    build_hydroponics(m)
    build_backdrop(m)
    objects = []
    for name, (rgb, shading) in LOOKS.items():
        bm = m[name]
        if not bm.verts:
            bm.free()
            continue
        objects.append(soft(coll, name, bm, rgb) if shading == "soft" else finish(coll, name, bm, rgb, hard=shading == "hard"))
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
