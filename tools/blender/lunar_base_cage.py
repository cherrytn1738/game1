# Training Ground 4 of World 3, Lunar Base: a pressurised moon-base tunnel. Ribbed white module
# rings for hoops, a frosted pressure shell with round portholes and a big observation window,
# an airlock collar round the door, a mass driver whose glowing coils fire each pitch, a riveted
# blast shield, supply racks, oxygen tanks and EVA suits inside, and outside a cratered regolith
# apron with moon rocks, solar arrays, a parked lander, a little rover, a turning radar dish and
# the Earth hanging above the machine end.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the
# mesh names are what TrainingCageStyles looks up for colors, materials and motion. Roles used
# by several builders collect in PARTS and are finished together at the end (FINISH). The
# shared helpers above the "Lunar Base" marker (panels with round holes, hazard stripes, ...)
# are also run by quantum_lab_cage.py.
# TrainingStadium squeezes every cage to 75% width but shrinks spinning parts evenly, so the
# spinning Earth and radar head are built at 4/3 of their in-game size and each spinning mesh
# is centred (bounding box) on its own spin axis.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

# ---------- shared helpers (quantum_lab_cage.py runs this file up to the Lunar Base marker) ----------

Y_AXIS = Vector((0, 1, 0))
PARTS = {}


def part(name):
    """The shared bmesh for one colour/material role."""
    if name not in PARTS:
        PARTS[name] = bmesh.new()
    return PARTS[name]


def profile_frame(line, s):
    """Point, unit tangent and outward normal of a cross-section Polyline in the XZ plane
    (drawn from the left wall's foot over the top to the right wall's foot) at arc length s."""
    p = line.at(s)
    t = (line.at(min(s + 0.05, line.length)) - line.at(max(s - 0.05, 0.0))).normalized()
    return p, t, Vector((-t.z, 0, t.x))


def axes(x_axis, y_axis, z_axis):
    """4x4 rotation whose columns are the given unit axes."""
    return Matrix((Vector(x_axis), Vector(y_axis), Vector(z_axis))).transposed().to_4x4()


def side_prism(bm, outline_yz, x0, x1):
    """Extrude a closed (y, z) outline along X between x0 and x1."""
    before = len(bm.verts)
    prism(bm, outline_yz, x0, x1)
    transform_new(bm, before, Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1))))


def stud(bm, base, normal, radius=0.07, height=0.07):
    """A small bolt head standing on a surface."""
    cylinder(bm, base, normal, height, radius, segments=6)


def annulus(bm, center, axis, r0, r1, thickness, segments=28):
    """A flat flange ring of the given thickness around axis."""
    h = thickness / 2
    lathe(bm, [(r0, -h), (r1, -h), (r1, h), (r0, h), (r0, -h)], segments,
          transform=Matrix.Translation(Vector(center)) @ align_z(Vector(axis)))


def ray_polygon(center, direction, outline):
    """Distance from center along direction to the edge of a convex 2D outline."""
    best = None
    for p, q in zip(outline, outline[1:] + outline[:1]):
        e = q - p
        denom = direction.x * e.y - direction.y * e.x
        if abs(denom) < 1e-12:
            continue
        w = p - center
        t = (w.x * e.y - w.y * e.x) / denom
        s = (w.x * direction.y - w.y * direction.x) / denom
        if t > 1e-9 and -1e-6 <= s <= 1 + 1e-6:
            best = t if best is None else min(best, t)
    return best


def panel_with_hole(bm, outline, to3d, center, radius, segments=40, thickness=0.0):
    """A flat convex panel (2D outline mapped to 3D by to3d(u, v, w)) with a round hole.
    thickness 0 builds a thin sheet visible from both sides; otherwise a slab, w across it."""
    c = Vector(center)
    outline = [Vector(p) for p in outline]
    angles = {round(2 * math.pi * k / segments, 6) for k in range(segments)}
    for p in outline:
        d = p - c
        angles.add(round(math.atan2(d.y, d.x) % (2 * math.pi), 6))
    angles = sorted(angles)
    outer, inner = [], []
    for a in angles:
        d = Vector((math.cos(a), math.sin(a)))
        outer.append(c + d * ray_polygon(c, d, outline))
        inner.append(c + d * radius)
    n = len(angles)
    if thickness == 0.0:
        for reverse in (False, True):
            ov = [bm.verts.new(to3d(p.x, p.y, 0.0)) for p in outer]
            iv = [bm.verts.new(to3d(p.x, p.y, 0.0)) for p in inner]
            for k in range(n):
                j = (k + 1) % n
                quad = (ov[k], ov[j], iv[j], iv[k])
                bm.faces.new(tuple(reversed(quad)) if reverse else quad)
        return
    h = thickness / 2
    fo, fi = [bm.verts.new(to3d(p.x, p.y, -h)) for p in outer], [bm.verts.new(to3d(p.x, p.y, -h)) for p in inner]
    bo, bi = [bm.verts.new(to3d(p.x, p.y, h)) for p in outer], [bm.verts.new(to3d(p.x, p.y, h)) for p in inner]
    for k in range(n):
        j = (k + 1) % n
        bm.faces.new((fo[k], fo[j], fi[j], fi[k]))
        bm.faces.new((bo[j], bo[k], bi[k], bi[j]))
        bm.faces.new((fo[j], fo[k], bo[k], bo[j]))
        bm.faces.new((fi[k], fi[j], bi[j], bi[k]))


def clip_band(points, lo, hi):
    """Clip a 2D polygon to lo <= x <= hi."""
    for c, keep_greater in ((lo, True), (hi, False)):
        out = []
        for i, p in enumerate(points):
            q = points[(i + 1) % len(points)]
            p_in = p[0] >= c if keep_greater else p[0] <= c
            q_in = q[0] >= c if keep_greater else q[0] <= c
            if p_in:
                out.append(p)
            if p_in != q_in:
                t = (c - p[0]) / (q[0] - p[0])
                out.append((c, p[1] + t * (q[1] - p[1])))
        points = out
        if not points:
            break
    return points


def hazard_band(bm, origin, along, up, length, height, normal, width=0.3, period=0.6, lift=0.03):
    """Diagonal hazard stripes across a length x height band (origin at its lower start corner)."""
    o, u, v, n = Vector(origin), Vector(along).normalized(), Vector(up).normalized(), Vector(normal).normalized()
    k = -height
    while k < length:
        stripe = clip_band([(k, 0.0), (k + width, 0.0), (k + width + height, height), (k + height, height)], 0.0, length)
        if len(stripe) >= 3:
            double_sided_poly(bm, [o + u * a + v * b + n * lift for a, b in stripe])
        k += period


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def see_through(obj, alpha):
    """Preview only: show a translucent part as translucent in Blender (FBX colours never reach
    Roblox; TrainingCageStyles sets the real transparency)."""
    mat = obj.data.materials[0]
    mat.diffuse_color = (*mat.diffuse_color[:3], alpha)
    try:
        mat.surface_render_method = "BLENDED"
    except (AttributeError, TypeError):
        pass


def finish_part(coll, name, rgb, how):
    bm = PARTS.pop(name)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    if how == "soft":
        return soft(coll, name, bm, rgb)
    if isinstance(how, float):
        return finish(coll, name, bm, rgb, bevel_width=how)
    return finish(coll, name, bm, rgb, hard=how == "hard")


# ---------- Lunar Base ----------

COLLECTION = "LunarBaseCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\LunarBaseCage.fbx"

PANEL = (0.94, 0.95, 0.96)
STEEL = (0.56, 0.58, 0.62)
CYAN = (0.45, 0.88, 1.0)
AMBER = (1.0, 0.62, 0.15)
HAZARD = (1.0, 0.8, 0.1)
FOIL = (0.96, 0.74, 0.28)
rng = random.Random(53)

WALL, PEAK = 8.8, 15.8                 # vertical walls (the banners hang on them), vault crown
CX, A = (LEFT_X + RIGHT_X) / 2, (RIGHT_X - LEFT_X) / 2
PORT_Z, PORT_R = 4.7, 1.15             # a porthole in every wall bay
WIN_Z, WIN_R = 11.2, 3.9               # the observation window in the machine-end wall
GROW = 4 / 3                           # spinning parts shrink evenly to 75% in game
PAD_Z = 0.06                           # regolith height under the parked props
X_MIN, X_MAX, Y_MIN, Y_MAX = -22.6, 20.4, -18.8, 47.0
EARTH, EARTH_R = Vector((CX, 51.0, 15.5)), 8.0
LANDER, DISH, ROVER = Vector((-11.5, 41.5, PAD_Z)), Vector((10.5, 41.0, PAD_Z)), Vector((17.9, 15.5, PAD_Z))
SOLAR = [Vector((-19.8, y, PAD_Z)) for y in (-8.5, -1.5, 5.5)]
CRATERS = [((-20.0, -15.5), 1.6), ((-19.6, 30.5), 2.2), ((18.3, 26.5), 2.0), ((17.9, -8.5), 1.6),
           ((-3.5, 40.5), 2.8), ((4.5, 44.0), 1.9), ((-17.5, 44.0), 1.7), ((17.0, 37.0), 1.5)]
PADS = [(LANDER, 4.4), (DISH, 2.4), (ROVER, 3.6)] + [(p, 2.0) for p in SOLAR]


# ---------- shapes ----------

def profile_points(step=0.5, n=2.4):
    """Tunnel cross-section (x, z): vertical walls rounding into a full vault."""
    b = PEAK - WALL
    points = [Vector((CX - A, 0, z)) for z in arange(WALL, step)]
    for i in range(1, 48):
        t = math.pi * i / 48
        c, s = math.cos(t), math.sin(t)
        points.append(Vector((CX - A * math.copysign(abs(c) ** (2 / n), c), 0, WALL + b * s ** (2 / n))))
    points += [Vector((CX + A, 0, z)) for z in reversed(arange(WALL, step))]
    return points


HOOP = Polyline(profile_points())


def profile_height(x):
    """Height of the tunnel profile above x (the end walls' outline)."""
    best = 0.0
    for a, b in zip(HOOP.points, HOOP.points[1:]):
        if min(a.x, b.x) - 1e-6 <= x <= max(a.x, b.x) + 1e-6:
            t = 0.0 if abs(b.x - a.x) < 1e-9 else (x - a.x) / (b.x - a.x)
            best = max(best, a.z + (b.z - a.z) * t)
    return best


def frame_at(s):
    """Point, unit tangent and outward normal of the tunnel profile at arc length s."""
    return profile_frame(HOOP, s)


def regolith_height(x, y):
    """Rolling regolith: low dunes, a berm banked against the walls, crater bowls with rims,
    flat pads under the parked props, a flat door approach and a ragged fade at the edge."""
    h = 0.28 + noise.noise(Vector((x * 0.1, y * 0.1, 1.7))) * 0.3 + noise.noise(Vector((x * 0.33, y * 0.33, 4.2))) * 0.1
    d = math.hypot(max(LEFT_X - x, 0.0, x - RIGHT_X), max(BACK_Y - y, 0.0, y - FRONT_Y))
    h += 0.5 * math.exp(-((d - 1.3) / 1.2) ** 2)
    for (cx, cy), r in CRATERS:
        q = math.hypot(x - cx, y - cy) / r
        if q < 1.8:
            blend = smoothstep(0.8, 1.5, q)
            h = h * blend + 0.03 * (1 - blend) + 0.65 * math.exp(-((q - 1.1) / 0.22) ** 2)
    for c, r in PADS:
        h = PAD_Z + (h - PAD_Z) * smoothstep(r, r + 1.5, math.hypot(x - c.x, y - c.y))
    if DOOR[0] - 2.0 < x < DOOR[1] + 2.0 and y < BACK_Y + 0.5:
        h = PAD_Z + (h - PAD_Z) * 0.15
    # At the ragged edge the apron dips just under the hub floor (0.1 below the plate top).
    edge = min(x - X_MIN, X_MAX - x, y - Y_MIN, Y_MAX - y) + noise.noise(Vector((x * 0.25, y * 0.25, 8.0))) * 1.2
    return max(-0.12, h * smoothstep(0.0, 2.5, edge) - 0.14 * (1 - smoothstep(0.0, 1.2, edge)))


# ---------- the tunnel ----------

def build_tunnel():
    rings, trim, lights, frame = part("LunarRings"), part("LunarRingTrim"), part("LunarRingLights"), part("LunarFrame")
    band = [(-0.82, -0.5), (0.82, -0.5), (0.82, 0.4), (-0.82, 0.4)]
    fine, coarse = HOOP.samples(0.4), HOOP.samples(0.6)
    for y in HOOPS:
        offset = Vector((0, y, 0))
        sweep_profile(rings, [p + offset for p in fine], band)
        # Grey lips round both edges, clamps every few studs, running lights outside and
        # light panels inside.
        for u in (-0.7, 0.7):
            sweep_profile(trim, [p + offset for p in coarse], [(u - 0.15, 0.3), (u + 0.15, 0.3), (u + 0.15, 0.58), (u - 0.15, 0.58)])
        for f in (0.1, 0.26, 0.42, 0.58, 0.74, 0.9):
            p, t, o = frame_at(HOOP.length * f)
            box(trim, p + offset + o * 0.02, (0.42, 1.9, 1.2), axes(t, Y_AXIS, o))
        s = 3.4
        while s < HOOP.length - 3.3:
            p, t, o = frame_at(s)
            box(lights, p + offset - o * 0.53, (0.8, 0.46, 0.07), axes(t, Y_AXIS, o))
            box(lights, p + offset + o * 0.43, (0.3, 0.3, 0.07), axes(t, Y_AXIS, o))
            s += 2.2
        for x in (LEFT_X, RIGHT_X):
            box(trim, (x, y, 0.22), (2.3, 2.1, 0.44))
            for dx in (-0.8, 0.8):
                for dy in (-0.72, 0.72):
                    stud(trim, (x + dx, y + dy, 0.44), (0, 0, 1), 0.1, 0.08)
    # Stringers along the outside of the shell (above the banners) and a sill round the walls.
    for s in (WALL + 2.0, HOOP.length * 0.34, HOOP.length / 2, HOOP.length * 0.66, HOOP.length - WALL - 2.0):
        p, t, o = frame_at(s)
        start = Vector((p.x, BACK_Y - 0.3, p.z)) + o * 0.22
        tube(frame, start, start + Vector((0, FRONT_Y - BACK_Y + 0.6, 0)), 0.17, 10)
    for x in (LEFT_X - 0.32, RIGHT_X + 0.32):
        box(trim, (x, (BACK_Y + FRONT_Y) / 2, 0.42), (0.64, FRONT_Y - BACK_Y + 0.64, 0.84))
    box(trim, (CX, FRONT_Y + 0.32, 0.42), (RIGHT_X - LEFT_X + 1.28, 0.64, 0.84))
    for x0, x1 in ((LEFT_X - 0.64, DOOR[0] - 1.2), (DOOR[1] + 1.2, RIGHT_X + 0.64)):
        box(trim, ((x0 + x1) / 2, BACK_Y - 0.32, 0.42), (x1 - x0, 0.64, 0.84))
    # Inside: a slim cable tray along the crown with a hanging lamp bar in every bay.
    crown = HOOP.at(HOOP.length / 2)
    box(frame, (crown.x, (BACK_Y + FRONT_Y) / 2, crown.z - 0.6), (0.6, FRONT_Y - BACK_Y - 1.6, 0.1))
    for a, b in zip(HOOPS, HOOPS[1:]):
        mid = (a + b) / 2
        for dy in (-1.2, 1.2):
            tube(frame, (crown.x, mid + dy, crown.z - 0.62), (crown.x, mid + dy, crown.z - 1.3), 0.035, 5)
        box(frame, (crown.x, mid, crown.z - 1.38), (0.9, 3.2, 0.16))
        box(lights, (crown.x, mid, crown.z - 1.47), (0.7, 2.9, 0.04))
    # On the roof: a hatch, a comms mast with a beacon, and radiator fins near the machine end.
    lathe(frame, [(0, crown.z - 0.2), (0.9, crown.z - 0.2), (0.9, crown.z + 0.35), (0.7, crown.z + 0.5), (0, crown.z + 0.5)], 16,
          transform=Matrix.Translation((crown.x, 14.0, 0)))
    tube(frame, (crown.x + 1.2, -2.5, crown.z - 0.2), (crown.x + 1.2, -2.5, crown.z + 3.0), 0.07, 6)
    for z in (crown.z + 1.2, crown.z + 2.2):
        tube(frame, (crown.x + 0.6, -2.5, z), (crown.x + 1.8, -2.5, z), 0.03, 4)
    lathe(part("LunarBeacons"), [(0, crown.z + 3.0), (0.16, crown.z + 3.0), (0.14, crown.z + 3.22), (0, crown.z + 3.3)], 10,
          transform=Matrix.Translation((crown.x + 1.2, -2.5, 0)))
    for f, side in ((0.33, -1), (0.67, 1)):
        p, t, o = frame_at(HOOP.length * f)
        for y in (28.0, 30.0):
            box(part("LunarDish"), p + Vector((0, y, 0)) + o * 1.3, (2.4, 0.12, 2.0), axes(t, Y_AXIS, o))
            box(frame, p + Vector((0, y, 0)) + o * 0.35, (0.3, 0.3, 0.7), axes(t, Y_AXIS, o))


def build_shell():
    shell, ports = part("LunarShell"), part("LunarPortholes")
    # Side walls: a flat panel per bay, a porthole with a bolted flange in the middle of each.
    for x, outward in ((LEFT_X, -1), (RIGHT_X, 1)):
        for a, b in zip(HOOPS, HOOPS[1:]):
            mid = (a + b) / 2
            panel_with_hole(shell, [(a, 0.0), (b, 0.0), (b, WALL), (a, WALL)], lambda u, v, w, x=x: Vector((x + w, u, v)),
                            (mid, PORT_Z), PORT_R, segments=36)
            center = Vector((x, mid, PORT_Z))
            torus(ports, center, (1, 0, 0), PORT_R + 0.08, 0.17, segments=28, minor_segments=6)
            annulus(ports, center, (1, 0, 0), PORT_R + 0.1, PORT_R + 0.62, 0.16)
            for k in range(8):
                angle = 2 * math.pi * (k + 0.5) / 8
                for side in (-1, 1):
                    stud(ports, center + Vector((side * 0.08, math.cos(angle) * (PORT_R + 0.4), math.sin(angle) * (PORT_R + 0.4))),
                         (side, 0, 0), 0.08, 0.1)
    # The vault.
    s0, s1 = WALL, HOOP.length - WALL
    grid_surface(shell, lambda u, v: HOOP.at(s0 + (s1 - s0) * v) + Vector((0, BACK_Y + (FRONT_Y - BACK_Y) * u, 0)), 48, 30)
    # Machine end: the observation window that frames the Earth.
    outline = [(p.x, p.z) for p in HOOP.points]
    panel_with_hole(shell, outline, lambda u, v, w: Vector((u, FRONT_Y + w, v)), (CX, WIN_Z), WIN_R, segments=64)
    window = Vector((CX, FRONT_Y, WIN_Z))
    torus(ports, window, (0, 1, 0), WIN_R + 0.1, 0.34, segments=64, minor_segments=8)
    annulus(ports, window, (0, 1, 0), WIN_R + 0.2, WIN_R + 0.62, 0.2, segments=64)
    for k in range(16):
        angle = 2 * math.pi * (k + 0.5) / 16
        for side in (-1, 1):
            stud(ports, window + Vector((math.cos(angle) * (WIN_R + 0.42), side * 0.1, math.sin(angle) * (WIN_R + 0.42))), (0, side, 0), 0.09, 0.1)
    # Batter end: three panels round the door.
    for x0, x1, z0 in ((LEFT_X, DOOR[0], 0.0), (DOOR[0], DOOR[1], DOOR[2]), (DOOR[1], RIGHT_X, 0.0)):
        top = [p for p in HOOP.points if x0 + 1e-6 < p.x < x1 - 1e-6]
        outline = [(x0, z0), (x1, z0), (x1, profile_height(x1))] + [(p.x, p.z) for p in reversed(top)] + [(x0, profile_height(x0))]
        double_sided_poly(shell, [Vector((x, BACK_Y, z)) for x, z in outline])


def build_airlock():
    collar, hazard, deck, lights = part("LunarAirlock"), part("LunarHazard"), part("LunarDeck"), part("LunarFloorLights")
    y_out, y_in = BACK_Y - 1.9, BACK_Y + 0.35
    x_l, x_r, top = DOOR[0] - 0.05, DOOR[1] + 0.05, DOOR[2] + 0.05
    # A short docking collar round the door with a flanged mouth (the entrance sign hangs above).
    for x0, x1 in ((x_l - 0.9, x_l), (x_r, x_r + 0.9)):
        box(collar, ((x0 + x1) / 2, (y_out + y_in) / 2, top / 2), (x1 - x0, y_in - y_out, top))
    box(collar, ((x_l + x_r) / 2, (y_out + y_in) / 2, top + 0.24), (x_r - x_l + 1.8, y_in - y_out, 0.48))
    mouth = y_out + 0.13
    for x0, x1 in ((x_l - 1.15, x_l), (x_r, x_r + 1.15)):
        box(collar, ((x0 + x1) / 2, mouth, top / 2), (x1 - x0, 0.5, top))
    box(collar, ((x_l + x_r) / 2, mouth, top + 0.3), (x_r - x_l + 2.3, 0.5, 0.6))
    for x in (x_l - 1.15, x_r):
        hazard_band(hazard, (x, mouth - 0.25, 0.25), (0, 0, 1), (1, 0, 0), top - 0.5, 1.15, (0, -1, 0))
    # Threshold plate, a deck in front of the door with a hazard edge, and two bollard lights.
    box(deck, ((x_l + x_r) / 2, (y_out + y_in) / 2, 0.03), (x_r - x_l, y_in - y_out, 0.06))
    y0, y1 = BACK_Y - 5.0, y_out
    for k in range(9):
        y = y0 + (y1 - y0) * (k + 0.5) / 9
        box(deck, ((x_l + x_r) / 2, y, 0.04), (x_r - x_l + 2.6, (y1 - y0) / 9 - 0.08, 0.32))
    for x in (x_l - 1.6, x_r + 1.6):
        tube(deck, (x, y0 + 0.2, 0.2), (x, y1, 0.2), 0.08, 6)
    hazard_band(hazard, (x_r + 1.3, y0, 0.2), (-1, 0, 0), (0, 1, 0), x_r - x_l + 2.6, 0.5, (0, 0, 1), width=0.25, period=0.5)
    for x in (x_l - 2.4, x_r + 2.4):
        lathe(collar, [(0, 0), (0.3, 0), (0.3, 0.1), (0.18, 0.2), (0.16, 1.15), (0, 1.15)], 10, transform=Matrix.Translation((x, y0 + 0.8, 0)))
        lathe(lights, [(0, 1.15), (0.2, 1.15), (0.2, 1.45), (0, 1.5)], 10, transform=Matrix.Translation((x, y0 + 0.8, 0)))


def build_floor():
    deck, lights = part("LunarDeck"), part("LunarFloorLights")
    # Grated walkways along both walls inside, with guide lights on their edges.
    for x0, x1 in ((LEFT_X + 0.55, LEFT_X + 2.35), (RIGHT_X - 2.35, RIGHT_X - 0.55)):
        y = BACK_Y + 1.2
        while y < FRONT_Y - 1.4:
            box(deck, ((x0 + x1) / 2, y + 0.95, 0.06), (x1 - x0, 1.82, 0.12))
            edge = x1 + 0.08 if x0 < 0 else x0 - 0.08
            box(lights, (edge, y + 0.95, 0.05), (0.08, 0.5, 0.06))
            y += 1.9
    # Guide lights either side of the pitch lane, between the batter's boxes and the screen.
    for y in [5.0 + 2.0 * k for k in range(8)]:
        for x in (PITCH.x - 3.35, PITCH.x + 3.35):
            box(lights, (x, y, 0.04), (0.22, 0.55, 0.05))


# ---------- the mass driver and the shield ----------

def build_mass_driver():
    body, metal, coils, glow, cables, balls = (part(n) for n in ("LunarDriverBody", "LunarDriverMetal", "LunarCoils",
                                                                "LunarDriverGlow", "LunarCables", "LunarBalls"))
    ax, az, y0 = PITCH.x, PITCH.z, PITCH.y
    to_y = align_z(Y_AXIS)
    # Chassis: a low white sled with a sloped nose and a dark skid.
    side_prism(body, [(y0 + 0.4, 0.12), (y0 + 8.9, 0.12), (y0 + 8.9, 0.85), (y0 + 1.2, 0.85), (y0 + 0.4, 0.5)], ax - 1.5, ax + 1.5)
    box(metal, (ax, y0 + 4.6, 0.06), (2.7, 8.6, 0.12))
    hazard_band(part("LunarHazard"), (ax + 1.5, y0 + 0.4, 0.15), (-1, 0, 0), (0, 0, 1), 3.0, 0.32, (0, -1, 0), width=0.22, period=0.44)
    # Six big glowing coils, each in a white saddle, tied by two top rails, guide rods down the
    # bore. Their tops glow over the shield.
    for k in range(6):
        y = y0 + 0.95 + 1.25 * k
        torus(coils, (ax, y, az), Y_AXIS, 1.6, 0.24, segments=40, minor_segments=8)
        saddle = [Vector((ax + math.cos(a) * 1.97, y, az + math.sin(a) * 1.97)) for a in [math.radians(200 + 140 * i / 14) for i in range(15)]]
        sweep_profile(body, saddle, [(-0.26, -0.12), (0.26, -0.12), (0.26, 0.12), (-0.26, 0.12)])
        box(body, (ax, y, 0.92), (0.9, 0.5, 0.2))
        for a in (35, 145, 230, 270, 310):
            d = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))
            box(metal, Vector((ax, y, az)) + d * 1.9, (0.22, 0.3, 0.22))
    for a in (35, 145):
        d = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))
        tube(metal, Vector((ax, y0 + 0.5, az)) + d * 2.08, Vector((ax, y0 + 7.9, az)) + d * 2.08, 0.09, 8)
    for a in (90, 210, 330):
        d = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))
        tube(metal, Vector((ax, y0 + 0.3, az)) + d * 0.62, Vector((ax, y0 + 7.9, az)) + d * 0.62, 0.06, 6)
    # Muzzle at PITCH: a flared ring with a glowing lip.
    lathe(metal, [(0.66, 0.0), (1.05, 0.0), (1.35, 0.22), (1.35, 0.5), (0.9, 0.62), (0.66, 0.62), (0.66, 0.0)], 32,
          transform=Matrix.Translation((ax, y0 + 0.06, az)) @ to_y)
    torus(coils, (ax, y0 + 0.07, az), Y_AXIS, 0.8, 0.07, segments=28, minor_segments=5)
    # Breech block with a ball hopper on top.
    box(body, (ax, y0 + 8.4, az), (3.3, 1.3, 3.3))
    box(metal, (ax, y0 + 9.1, az), (2.4, 0.2, 2.4))
    lathe(metal, [(0.35, 0.0), (1.1, 0.9), (1.1, 1.0), (1.0, 1.0), (0.3, 0.08), (0.35, 0.0)], 24,
          transform=Matrix.Translation((ax, y0 + 8.4, az + 1.65)))
    hopper = Vector((ax, y0 + 8.4, az + 2.35))
    for offset in ((0, 0, 0), (0.45, 0.2, 0.08), (-0.42, 0.28, 0.06), (0.1, -0.45, 0.12), (0.05, 0.22, 0.45), (-0.3, -0.3, 0.4)):
        ball(balls, hopper + Vector(offset), 0.3, subdivisions=2)
    # Capacitor towers either side, joined by a glowing power arch over the barrel.
    for side in (-1, 1):
        c = Vector((ax + side * 2.95, y0 + 6.2, 0))
        box(metal, c + Vector((0, 0, 0.15)), (1.6, 1.6, 0.3))
        lathe(body, [(0, 0.3), (0.62, 0.3), (0.62, 5.3), (0, 5.3)], 20, transform=Matrix.Translation(c))
        lathe(metal, [(0, 5.3), (0.68, 5.3), (0.68, 5.5), (0.46, 5.9), (0, 6.0)], 20, transform=Matrix.Translation(c))
        for z in (1.3, 2.5, 3.7, 4.8):
            torus(glow, c + Vector((0, 0, z)), (0, 0, 1), 0.64, 0.08, segments=20, minor_segments=5)
    arch = [Vector((ax - 2.95 * math.cos(t), y0 + 6.2, 5.85 + 1.9 * math.sin(t))) for t in [math.pi * i / 16 for i in range(17)]]
    sweep(metal, arch, 0.2, segments=10)
    for i in range(2, 15, 2):
        if i != 8:
            torus(glow, arch[i], (arch[i + 1] - arch[i - 1]).normalized(), 0.24, 0.05, segments=12, minor_segments=4)
    ball(glow, arch[8] + Vector((0, 0, 0.05)), 0.45, subdivisions=2)
    # Power cables from the capacitors and the breech, out along the floor to the console.
    for side in (-1, 1):
        sweep(cables, [Vector((ax + side * 2.95, y0 + 5.4, 0.12)), Vector((ax + side * 2.3, y0 + 4.8, 0.12)),
                       Vector((ax + side * 1.75, y0 + 4.4, 0.4)), Vector((ax + side * 1.6, y0 + 3.9, 0.7))], 0.09, segments=6)
    sweep(cables, [Vector((ax - 1.66, y0 + 8.4, 2.0)), Vector((ax - 2.0, y0 + 8.6, 0.6)), Vector((ax - 2.4, y0 + 9.0, 0.12)),
                   Vector((-4.0, y0 + 9.3, 0.12)), Vector((-8.5, y0 + 8.4, 0.12)), Vector((-10.4, y0 + 7.4, 0.12))], 0.11, segments=6)


def build_shield():
    shield, trim, hazard, beacons = part("LunarShield"), part("LunarShieldTrim"), part("LunarHazard"), part("LunarBeacons")
    # Kept low so the coils glow over it (the invisible screen block is unchanged).
    x0, x1, top, chamfer = PITCH.x - 3.5, PITCH.x + 3.5, 4.5, 0.7
    front = SCREEN_Y - 0.18
    outline = [(x0, 0.0), (x1, 0.0), (x1, top - chamfer), (x1 - chamfer, top), (x0 + chamfer, top), (x0, top - chamfer)]
    panel_with_hole(shield, outline, lambda u, v, w: Vector((u, SCREEN_Y + w, v)), (PITCH.x, PITCH.z), WINDOW + 0.05,
                    segments=48, thickness=0.36)
    # A heavy rim round the window, bolts, raised seams and rivets along the edges.
    for y in (SCREEN_Y - 0.2, SCREEN_Y + 0.2):
        torus(trim, (PITCH.x, y, PITCH.z), (0, 1, 0), WINDOW + 0.16, 0.13, segments=36, minor_segments=6)
    for k in range(10):
        a = 2 * math.pi * (k + 0.5) / 10
        stud(trim, (PITCH.x + math.cos(a) * 1.5, front, PITCH.z + math.sin(a) * 1.5), (0, -1, 0), 0.09, 0.1)
    box(trim, (PITCH.x, front - 0.02, 1.05), (x1 - x0 - 0.5, 0.06, 0.14))
    for x in (x0 + 0.85, x1 - 0.85):
        box(trim, (x, front - 0.02, 2.55), (0.14, 0.06, 2.9))
    edge = outline + [outline[0]]
    for (ax_, az_), (bx_, bz_) in zip(edge, edge[1:]):
        length = math.hypot(bx_ - ax_, bz_ - az_)
        for i in range(max(1, int(length / 0.55))):
            t = (i + 0.5) / max(1, int(length / 0.55))
            px, pz = ax_ + (bx_ - ax_) * t, az_ + (bz_ - az_) * t
            inward = Vector((PITCH.x - px, 0, top / 2 - pz)).normalized() * 0.22
            if pz > 0.3:
                stud(trim, Vector((px, front, pz)) + inward, (0, -1, 0), 0.06, 0.06)
    hazard_band(hazard, (x1, front, 0.12), (-1, 0, 0), (0, 0, 1), x1 - x0, 0.7, (0, -1, 0), width=0.32, period=0.64)
    # Gusset supports behind it and warning beacons on top.
    for x in (x0 + 0.35, x1 - 0.35):
        side_prism(trim, [(SCREEN_Y + 0.18, 0.0), (SCREEN_Y + 1.7, 0.0), (SCREEN_Y + 0.18, 3.4)], x - 0.08, x + 0.08)
        box(trim, (x, SCREEN_Y + 0.9, 0.06), (0.5, 1.7, 0.12))
    for x in (x0 + chamfer + 0.35, x1 - chamfer - 0.35):
        lathe(trim, [(0, top), (0.3, top), (0.3, top + 0.1), (0, top + 0.1)], 12, transform=Matrix.Translation((x, SCREEN_Y, 0)))
        lathe(beacons, [(0, top + 0.1), (0.22, top + 0.1), (0.2, top + 0.3), (0.1, top + 0.42), (0, top + 0.45)], 12,
              transform=Matrix.Translation((x, SCREEN_Y, 0)))
    home_plate(part("LunarPlate"), 0.08)


# ---------- inside the tunnel ----------

def eva_suit(s, v, d, transform):
    """A spacesuit hanging on its rack, built facing -Y with its feet at the origin, then moved
    into place by transform."""
    marks = [len(bm.verts) for bm in (s, v, d)]
    for side in (-1, 1):
        box(s, (side * 0.26, -0.06, 0.16), (0.36, 0.62, 0.32))
        sweep_radii(s, [Vector((side * 0.26, 0, 0.3)), Vector((side * 0.28, 0.02, 1.0)), Vector((side * 0.25, 0, 1.8))], [0.19, 0.21, 0.24], segments=10)
        arm = [Vector((side * 0.6, 0, 2.85)), Vector((side * 0.78, -0.05, 2.28)), Vector((side * 0.7, -0.16, 1.72))]
        sweep_radii(s, arm, [0.18, 0.16, 0.15], segments=10)
        blob(s, arm[-1] + Vector((0, -0.02, -0.12)), Vector((0.15, 0.16, 0.17)), subdivisions=2)
        torus(d, (side * 0.26, 0, 1.0), (0, 0, 1), 0.22, 0.04, segments=12, minor_segments=4)
    blob(s, Vector((0, 0, 2.35)), Vector((0.62, 0.42, 0.78)), subdivisions=3)
    box(s, (0, 0.5, 2.55), (0.82, 0.45, 1.05))
    box(d, (0, -0.42, 2.45), (0.5, 0.16, 0.32))
    torus(d, (0, 0, 3.0), (0, 0, 1), 0.3, 0.06, segments=16, minor_segments=5)
    ball(s, (0, -0.02, 3.42), 0.42, subdivisions=3)
    lathe(v, [(0, 0.445), (0.22, 0.39), (0.33, 0.28), (0.36, 0.16), (0.3, 0.1), (0, 0.13)], 18,
          transform=Matrix.Translation((0, -0.02, 3.42)) @ align_z(Vector((0, -1, 0.15))))
    for bm, before in zip((s, v, d), marks):
        transform_new(bm, before, transform)


def build_interior():
    frame, crates, tanks, hazard = part("LunarFrame"), part("LunarCrates"), part("LunarTanks"), part("LunarHazard")
    console, screens = part("LunarConsole"), part("LunarScreens")
    # Shelf rack against the left wall at the machine end, stocked with crates.
    x0, x1, y0, y1 = LEFT_X + 0.6, LEFT_X + 2.2, 23.2, 30.8
    for x in (x0, x1):
        for y in (y0, y1):
            box(frame, (x, y, 2.35), (0.14, 0.14, 4.7))
    for z in (0.6, 2.05, 3.5):
        box(frame, ((x0 + x1) / 2, (y0 + y1) / 2, z), (x1 - x0 + 0.2, y1 - y0 + 0.2, 0.1))
        y = y0 + 0.3
        while True:
            w, h = rng.uniform(0.9, 1.5), rng.uniform(0.6, 1.15)
            if y + w > y1 - 0.2:
                break
            box(crates, ((x0 + x1) / 2, y + w / 2, z + 0.05 + h / 2), (x1 - x0 - 0.2, w - 0.08, h))
            y += w + 0.12
    # A control console facing the batter, with a crate stack beside it.
    side_prism(console, [(29.9, 0.0), (31.6, 0.0), (31.6, 1.95), (31.25, 1.95), (29.9, 1.15)], -12.9, -9.9)
    slope = Vector((0, 1.35, 0.8)).normalized()
    normal = Vector((0, -0.8, 1.35)).normalized()
    for k, x in enumerate((-12.2, -11.4, -10.6)):
        box(screens, Vector((x, 30.6, 1.56)) + normal * 0.03, (0.62, 0.9, 0.04), axes((1, 0, 0), slope, normal))
    for x in (-12.5, -10.3):
        tube(console, (x, 31.4, 1.9), (x, 31.4, 2.4), 0.05, 6)
        box(console, (x, 31.36, 2.95), (1.5, 0.12, 1.0))
        box(screens, (x, 31.28, 2.95), (1.32, 0.05, 0.84))
    for center, size in (((-13.0, 33.0, 0.5), (1.2, 1.1, 1.0)), ((-11.6, 33.1, 0.45), (1.3, 1.0, 0.9)), ((-12.3, 33.0, 1.4), (1.1, 1.0, 0.8))):
        box(crates, center, size, Matrix.Rotation(rng.uniform(-0.15, 0.15), 4, "Z"))
    # Oxygen tanks racked against the right wall.
    for y in (27.7, 28.9, 30.1, 31.3):
        c = Vector((RIGHT_X - 1.4, y, 0.1))
        lathe(tanks, [(0, 0), (0.42, 0), (0.48, 0.15), (0.48, 2.7), (0.36, 3.05), (0, 3.12)], 16, transform=Matrix.Translation(c))
        for z in (0.75, 2.2):
            lathe(hazard, [(0.49, z), (0.5, z), (0.5, z + 0.28), (0.49, z + 0.28)], 16, transform=Matrix.Translation(c))
        cylinder(frame, c + Vector((0, 0, 3.1)), (0, 0, 1), 0.3, 0.1, segments=8)
        box(frame, c + Vector((0, 0, 3.45)), (0.36, 0.12, 0.12))
    for z in (1.0, 2.5):
        box(frame, (RIGHT_X - 0.8, 29.5, z), (0.12, 4.4, 0.14))
        for y in (27.7, 28.9, 30.1, 31.3):
            box(frame, (RIGHT_X - 1.05, y, z), (0.5, 0.1, 0.1))
    for center, size in (((10.6, 33.0, 0.55), (1.3, 1.2, 1.1)), ((11.9, 32.9, 0.45), (1.0, 1.1, 0.9)), ((10.8, 33.0, 1.55), (1.0, 1.0, 0.9))):
        box(crates, center, size, Matrix.Rotation(rng.uniform(-0.15, 0.15), 4, "Z"))
    # EVA suits on a rack in the corner beside the door end.
    for x in (RIGHT_X - 0.75,):
        for y in (-13.2, -9.6):
            box(frame, (x, y, 2.3), (0.14, 0.14, 4.6))
        box(frame, (x, -11.4, 4.5), (0.14, 3.7, 0.14))
    for y in (-12.5, -10.3):
        box(frame, (RIGHT_X - 1.0, y, 4.3), (0.5, 0.1, 0.1))
        eva_suit(part("LunarSuits"), part("LunarVisors"), part("LunarConsole"),
                 Matrix.Translation((RIGHT_X - 1.6, y, 0.35)) @ Matrix.Rotation(-math.pi / 2, 4, "Z"))


# ---------- outside ----------

def build_regolith():
    ground, step = part("LunarRegolith"), 0.55
    nx, ny = int((X_MAX - X_MIN) / step), int((Y_MAX - Y_MIN) / step)

    def at(u, v):
        return X_MIN + (X_MAX - X_MIN) * u, Y_MIN + (Y_MAX - Y_MIN) * v

    def keep(u, v):
        x, y = at(u, v)
        if LEFT_X - 0.7 < x < RIGHT_X + 0.7 and BACK_Y - 0.7 < y < FRONT_Y + 0.7:
            return False
        if DOOR[0] - 1.45 < x < DOOR[1] + 1.45 and y < BACK_Y:
            return False
        return regolith_height(x, y) > -0.115

    grid_surface(ground, lambda u, v: Vector((*at(u, v), regolith_height(*at(u, v)))), nx, ny, double=False, keep=keep)
    craters, rocks = part("LunarCraters"), part("LunarRocks")
    for (cx, cy), r in CRATERS:
        lathe(craters, [(0, 0.075), (r * 0.72, 0.075), (r * 0.72, 0.045), (0, 0.045)], 20,
              transform=Matrix.Translation((cx, cy, 0)), wobble=r * 0.08, seed=cx)
        for k in range(rng.randint(2, 4)):
            a = rng.uniform(0, 2 * math.pi)
            x, y = cx + math.cos(a) * r * 1.15, cy + math.sin(a) * r * 1.15
            s = rng.uniform(0.25, 0.5)
            if not X_MIN + 0.8 < x < X_MAX - 0.8:
                continue
            z = regolith_height(x, y)
            rough_rock(rocks, (x, y, z + s * 0.3), (s, s * 0.8, s * 0.6), rng, subdivisions=1, jitter=0.28, floor=z - 0.1)
    placed, tries = 0, 0
    while placed < 44 and tries < 3000:
        tries += 1
        x, y = rng.uniform(X_MIN + 1.8, X_MAX - 1.8), rng.uniform(Y_MIN + 1.5, Y_MAX - 1.5)
        if LEFT_X - 1.6 < x < RIGHT_X + 1.6 and BACK_Y - 1.6 < y < FRONT_Y + 1.6:
            continue
        if DOOR[0] - 3.0 < x < DOOR[1] + 3.0 and y < BACK_Y:
            continue
        if any(math.hypot(x - c.x, y - c.y) < r + 0.8 for c, r in PADS) or any(math.hypot(x - cx, y - cy) < r for (cx, cy), r in CRATERS):
            continue
        s = rng.uniform(0.25, 0.7) * (1.7 if rng.random() < 0.15 else 1.0)
        z = regolith_height(x, y)
        rough_rock(rocks, (x, y, z + s * 0.3), (s, s * rng.uniform(0.7, 1.0), s * rng.uniform(0.5, 0.8)), rng, subdivisions=1, jitter=0.28, floor=z - 0.1)
        placed += 1
    # Rover tracks curving back from the rover to the door deck.
    track = Polyline([Vector(p) for p in ((17.9, 12.6, 0), (17.7, 6.0, 0), (17.3, 0.0, 0), (16.9, -6.0, 0), (15.6, -11.5, 0),
                                           (12.8, -15.0, 0), (7.0, -16.7, 0), (-3.2, -17.0, 0))])
    points = track.samples(0.5)
    for offset in (-1.55, 1.55):
        left, right = [], []
        for i, p in enumerate(points):
            ahead = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
            side = Vector((-ahead.y, ahead.x, 0)).normalized()
            q = p + side * offset
            z = regolith_height(q.x, q.y) + 0.035
            left.append(Vector((q.x, q.y, z)) - side * 0.2)
            right.append(Vector((q.x, q.y, z)) + side * 0.2)
        for i in range(0, len(points) - 1, 2):
            double_sided_strip(craters, left[i:i + 2], right[i:i + 2])


def build_lander():
    foil, body, windows = part("LunarLanderFoil"), part("LunarLanderBody"), part("LunarWindows")
    c = LANDER
    # Descent stage: a gold-foil octagon on four splayed legs with the engine bell beneath.
    lathe(foil, [(0, 1.5), (2.05, 1.5), (2.12, 1.62), (2.12, 3.25), (2.05, 3.38), (0, 3.38)], 8,
          transform=Matrix.Translation(c) @ Matrix.Rotation(math.pi / 8, 4, "Z"))
    lathe(body, [(0, 1.5), (0.4, 1.5), (0.82, 0.72), (0.86, 0.72), (0.44, 1.5)], 16, transform=Matrix.Translation(c))
    for k in range(4):
        d = Vector((math.cos(k * math.pi / 2), math.sin(k * math.pi / 2), 0))
        s = Vector((-d.y, d.x, 0))
        top, foot = c + d * 2.0 + Vector((0, 0, 2.9)), c + d * 3.5 + Vector((0, 0, 0.3))
        tube(body, top, foot, 0.12, 8)
        knee = top.lerp(foot, 0.62)
        for side in (-1, 1):
            tube(body, c + d * 1.75 + s * side * 0.85 + Vector((0, 0, 1.55)), knee, 0.06, 6)
        lathe(body, [(0, 0), (0.55, 0), (0.58, 0.06), (0.3, 0.26), (0, 0.26)], 14, transform=Matrix.Translation(foot - Vector((0, 0, 0.3))))
    # A ladder down the front leg (the lander faces the cage) up to a porch below the hatch.
    d, s = Vector((0, -1, 0)), Vector((1, 0, 0))
    top, foot = c + d * 2.2 + Vector((0, 0, 3.05)), c + d * 3.3 + Vector((0, 0, 0.45))
    for side in (-1, 1):
        tube(body, top + s * side * 0.32, foot + s * side * 0.32, 0.04, 5)
    for k in range(6):
        p = top.lerp(foot, (k + 0.5) / 6)
        tube(body, p - s * 0.32, p + s * 0.32, 0.035, 5)
    box(body, c + Vector((0, -2.4, 3.36)), (1.1, 0.7, 0.08))
    # Ascent module: a faceted cabin with triangular windows and a hatch facing the cage.
    cabin = [(-1.3, -0.95), (1.3, -0.95), (1.65, 0.15), (0.95, 1.25), (-0.95, 1.25), (-1.65, 0.15)]
    prism(body, [(c.x + x, c.y + y) for x, y in cabin], c.z + 3.38, c.z + 5.4)
    side_prism(body, [(c.y - 0.95, c.z + 5.4), (c.y + 0.6, c.z + 5.4), (c.y + 0.3, c.z + 6.0), (c.y - 0.5, c.z + 6.0)], c.x - 1.1, c.x + 1.1)
    for side in (-1, 1):
        double_sided_poly(windows, [Vector((c.x + side * 0.35, c.y - 0.98, c.z + 4.45)), Vector((c.x + side * 1.05, c.y - 0.98, c.z + 4.45)),
                                    Vector((c.x + side * 0.35, c.y - 0.98, c.z + 5.15))])
    box(windows, (c.x, c.y - 0.97, c.z + 3.95), (0.8, 0.04, 0.75))
    lathe(body, [(0, 6.0), (0.55, 6.0), (0.55, 6.35), (0.45, 6.45), (0, 6.45)], 16, transform=Matrix.Translation(c))
    for corner in ((-1.45, -0.7), (1.45, -0.7), (-1.2, 1.0), (1.2, 1.0)):
        p = c + Vector((corner[0], corner[1], 5.0))
        box(body, p, (0.32, 0.32, 0.32))
        for d2 in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0)):
            cylinder(body, p + Vector(d2) * 0.16, d2, 0.2, 0.06, segments=6, radius_top=0.1)
    tube(body, c + Vector((0.7, 0.9, 6.0)), c + Vector((0.95, 1.4, 7.4)), 0.04, 5)
    lathe(body, [(0, 0), (0.45, 0.28), (0.42, 0.3), (0, 0.06)], 12, transform=Matrix.Translation(c + Vector((0.95, 1.4, 7.4))) @ align_z(Vector((0.2, -0.6, 1))))


def build_rover():
    """A little open rover: deck, wire wheels under fenders, two seats, a console, a camera,
    an umbrella antenna and a cargo box, built facing -Y and then parked."""
    body, wheels, lens = part("LunarRoverBody"), part("LunarRoverWheels"), part("LunarWindows")
    marks = [len(bm.verts) for bm in (body, wheels, lens)]
    box(body, (0, 0, 1.08), (2.5, 4.7, 0.2))
    box(body, (0, -0.2, 0.92), (1.0, 3.6, 0.2))
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = Vector((sx * 1.55, sy * 1.7, 0.66))
            tire = [(0.38, -0.21), (0.6, -0.21), (0.66, -0.12), (0.66, 0.12), (0.6, 0.21), (0.38, 0.21), (0.38, -0.21)]
            lathe(wheels, tire, 20, transform=Matrix.Translation(c) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
            cylinder_x(wheels, c, 0.36, 0.38, 14)
            for k in range(10):
                a = 2 * math.pi * k / 10
                box(wheels, c + Vector((0, math.cos(a) * 0.67, math.sin(a) * 0.67)), (0.4, 0.06, 0.1), Matrix.Rotation(a, 4, "X"))
            fender = [c + Vector((0, math.cos(t) * 0.82, math.sin(t) * 0.82)) for t in [math.pi * i / 10 for i in range(11)]]
            sweep_profile(body, fender, [(-0.02, -0.25), (0.04, -0.25), (0.04, 0.25), (-0.02, 0.25)])
            box(body, (sx * 1.2, sy * 1.7, 1.0), (0.5, 0.25, 0.25))
    for x in (-0.55, 0.55):
        box(body, (x, -0.35, 1.35), (0.8, 0.8, 0.14))
        box(body, (x, 0.02, 1.85), (0.8, 0.12, 0.9), Matrix.Rotation(math.radians(-12), 4, "X"))
    tube(body, (0, -1.35, 1.18), (0, -1.45, 1.9), 0.05, 6)
    box(body, (0, -1.5, 2.0), (0.7, 0.35, 0.3), Matrix.Rotation(math.radians(25), 4, "X"))
    tube(body, (-0.95, -2.0, 1.18), (-0.95, -2.0, 3.0), 0.04, 6)
    lathe(body, [(0, 0), (0.7, 0.3), (0.67, 0.33), (0, 0.06)], 16, transform=Matrix.Translation((-0.95, -2.05, 3.0)) @ align_z(Vector((0, -1, 0.8))))
    tube(body, (0.95, -2.1, 1.18), (0.95, -2.1, 1.85), 0.04, 6)
    box(body, (0.95, -2.15, 1.98), (0.32, 0.45, 0.26))
    cylinder(lens, (0.95, -2.38, 1.98), (0, -1, 0), 0.06, 0.1, segments=10)
    box(body, (0, 2.0, 1.55), (2.0, 0.6, 0.75))
    tube(body, (0.85, 2.2, 1.9), (1.0, 2.4, 3.2), 0.025, 4)
    turn = Matrix.Translation(ROVER) @ Matrix.Rotation(math.radians(174), 4, "Z")
    for bm, before in zip((body, wheels, lens), marks):
        transform_new(bm, before, turn)


def build_dish():
    """A lattice mast with an equipment hut, and a radar head that turns on top of it. The head
    is built 4/3 size and balanced by a counterweight so its bounding box centres on the mast."""
    mast, hut, head = part("LunarFrame"), part("LunarDish"), part("LunarDishHead")
    base, mast_top = DISH, DISH + Vector((0, 0, 6.2))

    def leg(angle, z):
        return base + Vector((math.cos(angle), math.sin(angle), 0)) * (1.35 - 0.93 * z / 5.95) + Vector((0, 0, z))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        tube(mast, leg(a, 0.0), leg(a, 5.95), 0.09, 6)
        for z0 in (0.0, 1.5, 3.0, 4.5):
            tube(mast, leg(a, z0 + 0.1), leg(a + math.pi / 2, z0 + 1.4), 0.04, 5)
    lathe(mast, [(0, 5.9), (0.65, 5.9), (0.65, 6.2), (0, 6.2)], 12, transform=Matrix.Translation(base))
    box(hut, base + Vector((2.1, 0.6, 0.8)), (1.8, 1.6, 1.6))
    box(hut, base + Vector((2.1, 0.6, 1.66)), (2.0, 1.8, 0.12))
    # The head at in-game size around its pivot (the turntable foot at the origin).
    start = len(head.verts)
    lathe(head, [(0, 0), (0.7, 0), (0.7, 0.3), (0.5, 0.42), (0, 0.42)], 18)
    for side in (-1, 1):
        box(head, (side * 0.82, 0, 0.95), (0.18, 0.5, 1.2))
    cylinder_x(head, (0, 0, 1.4), 1.9, 0.12, 10)
    radius, depth = 2.0, 0.55
    bowl = [(r * radius / 10, depth * (r / 10) ** 2) for r in range(11)]
    profile = bowl + [(radius + 0.05, depth + 0.02)] + [(r * radius / 10, depth * (r / 10) ** 2 - 0.1) for r in reversed(range(11))]
    tilted = len(head.verts)
    lathe(head, profile, 32)
    for a in (90, 210, 330):
        rim = Vector((math.cos(math.radians(a)) * radius * 0.95, math.sin(math.radians(a)) * radius * 0.95, depth * 0.9))
        tube(head, rim, Vector((0, 0, 1.25)), 0.03, 5)
    lathe(head, [(0, 1.05), (0.14, 1.1), (0.2, 1.35), (0, 1.35)], 10)
    cylinder(head, (0, 0, -0.1), (0, 0, -1), 0.3, 0.32, segments=10)
    transform_new(head, tilted, Matrix.Translation((0, 0, 1.4)) @ Matrix.Rotation(math.radians(50), 4, "X") @ Matrix.Translation((0, 0, 0.2)))
    # Counterweight boom: mirror the bowl's reach so the bounding box centres on the pivot.
    head.verts.ensure_lookup_table()
    reach = -min(v.co.y for v in head.verts[start:])
    tube(head, (0, 0.1, 1.2), (0, reach - 0.55, 0.9), 0.07, 6)
    box(head, (0, reach - 0.35, 0.9), (0.9, 0.7, 0.7))
    head.verts.ensure_lookup_table()
    zs = [v.co.z for v in head.verts[start:]]
    transform_new(head, start, Matrix.Translation(mast_top) @ Matrix.Scale(GROW, 4))
    # In game the head shrinks about its centre, lifting its foot: a post fills that gap.
    lift = 0.25 * GROW * (max(zs) + min(zs)) / 2
    lathe(mast, [(0, 6.2), (0.24, 6.2), (0.24, 6.32 + lift), (0, 6.32 + lift)], 10, transform=Matrix.Translation(base))


def build_solar():
    panels, frame = part("LunarSolar"), part("LunarFrame")
    for c in SOLAR:
        cylinder(frame, c, (0, 0, 1), 1.75, 0.13, segments=8)
        box(frame, c + Vector((0, 0, 0.1)), (0.8, 0.8, 0.2))
        tube(frame, c + Vector((0, -2.7, 1.8)), c + Vector((0, 2.7, 1.8)), 0.08, 8)
        tilt = Matrix.Translation(c + Vector((0, 0, 1.95))) @ Matrix.Rotation(math.radians(-28), 4, "Y")
        before = len(panels.verts)
        box(panels, (0, 0, 0), (2.6, 5.2, 0.08))
        transform_new(panels, before, tilt)
        before = len(frame.verts)
        for x in (-1.3, -0.43, 0.43, 1.3):
            box(frame, (x, 0, 0.05), (0.05, 5.2, 0.03))
        for y in (-2.6, -1.3, 0.0, 1.3, 2.6):
            box(frame, (0, y, 0.05), (2.6, 0.05, 0.03))
        transform_new(frame, before, tilt)
    # Cables from the arrays to the base.
    for c in SOLAR:
        sweep(part("LunarCables"), [c + Vector((0.2, 0, 0.1)), c + Vector((1.6, 0.4, 0.1)), Vector((LEFT_X - 0.7, c.y + 0.8, 0.5))], 0.07, segments=6)


def cap(bm, center, direction, size):
    """A tiny flat hexagon at center facing direction."""
    n = Vector(direction).normalized()
    side = n.cross(Vector((0.3, 0.2, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
    other = n.cross(side)
    double_sided_poly(bm, [Vector(center) + (side * math.cos(a) + other * math.sin(a)) * size for a in [math.pi * k / 3 for k in range(6)]])


def sphere_patches(radius, keep, subdivisions=4, passes=3, min_island=5):
    """Faces of an icosphere picked by keep(direction), cleaned by a majority filter. Tiny caps
    on any bare axis point keep the bounding box centred on the sphere (spinning parts turn
    about their bounding-box centre)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    chosen = {f: keep(f.calc_center_median().normalized()) for f in bm.faces}
    for _ in range(passes):
        updated = {}
        for f in bm.faces:
            neighbours = [o for e in f.edges for o in e.link_faces if o is not f]
            votes = sum(1 for o in neighbours if chosen[o])
            updated[f] = votes * 2 > len(neighbours) or (votes * 2 == len(neighbours) and chosen[f])
        chosen = updated
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not chosen[f]], context="FACES")
    seen, small = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        stack, island = [f], []
        seen.add(f)
        while stack:
            current = stack.pop()
            island.append(current)
            for e in current.edges:
                for o in e.link_faces:
                    if o not in seen:
                        seen.add(o)
                        stack.append(o)
        if len(island) < min_island:
            small.extend(island)
    bmesh.ops.delete(bm, geom=small, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # Relax the jagged triangle edges into smooth coastlines, staying on the sphere.
    for _ in range(8):
        moves = {}
        for v in bm.verts:
            rim = [e for e in v.link_edges if e.is_boundary]
            if len(rim) == 2:
                moves[v] = v.co.lerp((rim[0].other_vert(v).co + rim[1].other_vert(v).co) / 2, 0.5)
        for v, co in moves.items():
            v.co = co.normalized() * radius
    for axis in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        for sign in (1, -1):
            reach = max((v.co.dot(axis) * sign for v in bm.verts), default=0.0)
            if reach < radius - 0.02:
                cap(bm, axis * sign * radius, axis * sign, 0.2)
    return bm


def build_earth(coll):
    def land(d):
        n = noise.noise(d * 1.25 + Vector((3.1, 0.4, 7.7))) + 0.35 * noise.noise(d * 3.2 + Vector((1.3, 5.2, 0.6)))
        return n > 0.12 and abs(d.z) < 0.84

    def cloud(d):
        n = noise.noise(Vector((d.x * 1.8, d.y * 1.8, d.z * 5.5)) + Vector((9.0, 2.0, 4.0)))
        return n > 0.3 or abs(d.z) > 0.9

    ocean, atmosphere = bmesh.new(), bmesh.new()
    ball(ocean, (0, 0, 0), EARTH_R, subdivisions=5)
    ball(atmosphere, (0, 0, 0), EARTH_R * 1.06, subdivisions=4)
    land_bm = sphere_patches(EARTH_R * 1.012, land, subdivisions=6)
    clouds = sphere_patches(EARTH_R * 1.032, cloud, subdivisions=6)
    # Two cyclone spirals in the cloud layer.
    for center, turns in ((Vector((0.5, -0.8, 0.35)), 1), (Vector((-0.7, -0.4, -0.55)), -1)):
        c = center.normalized()
        e1 = c.cross(Vector((0, 0, 1))).normalized()
        e2 = c.cross(e1)
        left, right = [], []
        for i in range(40):
            t = i / 39
            a = turns * t * 3.4 * math.pi
            rho = 0.1 + 0.95 * t
            p = (c * EARTH_R + (e1 * math.cos(a) + e2 * math.sin(a)) * rho).normalized() * EARTH_R * 1.04
            outward = (e1 * math.cos(a) + e2 * math.sin(a))
            w = 0.07 + 0.2 * math.sin(math.pi * t)
            left.append(p - outward * w)
            right.append(p + outward * w)
        double_sided_strip(clouds, left, right)
    objects = []
    for name, bm, rgb in (("LunarEarthOcean", ocean, (0.12, 0.35, 0.8)), ("LunarEarthLand", land_bm, (0.3, 0.62, 0.3)),
                          ("LunarEarthClouds", clouds, WHITE), ("LunarEarthAtmosphere", atmosphere, (0.5, 0.75, 1.0))):
        bmesh.ops.transform(bm, matrix=Matrix.Translation(EARTH), verts=bm.verts[:])
        closed = name in ("LunarEarthOcean", "LunarEarthAtmosphere")
        objects.append(finish(coll, name, bm, rgb, hard=False) if closed else soft(coll, name, bm, rgb))
    return objects


# ---------- finishing ----------

# name, preview colour, how it is finished ("hard" smooth-by-angle, "smooth", "soft" double-sided, or a bevel width)
FINISH = [
    ("LunarRings", PANEL, "hard"), ("LunarRingTrim", STEEL, "hard"), ("LunarRingLights", (0.85, 0.95, 1.0), "hard"),
    ("LunarShell", (0.74, 0.86, 0.96), "soft"), ("LunarPortholes", (0.75, 0.77, 0.8), "smooth"),
    ("LunarFrame", (0.7, 0.72, 0.75), "hard"), ("LunarAirlock", PANEL, 0.05), ("LunarHazard", HAZARD, "soft"),
    ("LunarDeck", (0.22, 0.23, 0.25), "hard"), ("LunarFloorLights", CYAN, "hard"),
    ("LunarDriverBody", PANEL, 0.04), ("LunarDriverMetal", STEEL, "hard"), ("LunarCoils", CYAN, "smooth"),
    ("LunarDriverGlow", (0.55, 0.95, 1.0), "smooth"), ("LunarCables", (0.1, 0.1, 0.11), "smooth"), ("LunarBalls", WHITE, "smooth"),
    ("LunarShield", (0.5, 0.52, 0.56), "hard"), ("LunarShieldTrim", (0.32, 0.33, 0.36), "hard"), ("LunarBeacons", AMBER, "smooth"),
    ("LunarPlate", WHITE, 0.02),
    ("LunarConsole", (0.82, 0.84, 0.87), "hard"), ("LunarScreens", (0.35, 0.85, 1.0), "hard"), ("LunarCrates", (0.95, 0.5, 0.15), 0.04),
    ("LunarTanks", (0.95, 0.95, 0.95), "smooth"), ("LunarSuits", (0.97, 0.97, 0.96), "smooth"), ("LunarVisors", FOIL, "smooth"),
    ("LunarRegolith", (0.55, 0.55, 0.53), "soft"), ("LunarCraters", (0.33, 0.33, 0.33), "soft"), ("LunarRocks", (0.45, 0.45, 0.44), "hard"),
    ("LunarLanderFoil", FOIL, "hard"), ("LunarLanderBody", (0.78, 0.8, 0.82), "hard"), ("LunarWindows", (0.08, 0.1, 0.16), "soft"),
    ("LunarRoverBody", (0.82, 0.83, 0.85), "hard"), ("LunarRoverWheels", (0.25, 0.25, 0.27), "hard"),
    ("LunarDish", PANEL, "hard"), ("LunarDishHead", PANEL, "hard"), ("LunarSolar", (0.1, 0.18, 0.45), "hard"),
]


def build_and_export(export=True):
    coll = begin(COLLECTION)
    PARTS.clear()
    build_tunnel()
    build_shell()
    build_airlock()
    build_floor()
    build_mass_driver()
    build_shield()
    build_interior()
    build_regolith()
    build_lander()
    build_rover()
    build_dish()
    build_solar()
    objects = [finish_part(coll, name, rgb, how) for name, rgb, how in FINISH]
    assert not PARTS, "unfinished parts: %s" % list(PARTS)
    objects += build_earth(coll)
    for obj in objects:
        if obj.name in ("LunarShell", "LunarEarthAtmosphere"):
            see_through(obj, 0.3 if obj.name == "LunarShell" else 0.2)
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
