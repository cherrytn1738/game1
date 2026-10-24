# Training Ground 1 of World 3, Solar Rooftop: a batting cage on a sunny skyscraper roof. A clean
# white aluminium frame under a sawtooth canopy of glass solar modules (instead of a net roof),
# sky-blue glass and welded-mesh walls, LED light bars, a sleek white pitching machine whose dark
# face carries a glowing sun around the ball port (sun emblems on its trunnions too) and a
# sun-tracking solar flower on top that turns slowly, a glass screen with a solar strip, potted
# plants, and around it on a paved roof deck: a glass railing on a parapet, HVAC units with
# spinning fans, vents and a duct, a helical wind turbine whose rotor spins, and a stair hut with
# an antenna and a blinking beacon.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; the mesh
# names are what TrainingCageStyles looks up for colors, materials and motion. LOOKS lists every
# mesh with its preview colour and shading: "hard" smooths by angle, "smooth" shades smooth and
# "soft" keeps double-sided pieces as built. A spinning part is its own mesh, centred on its axis.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "SolarRooftopCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\SolarRooftopCage.fbx"

ALUMINIUM = (0.95, 0.96, 0.97)
GLASS = (0.62, 0.84, 0.96)
CELLS = (0.07, 0.15, 0.4)
SILVER = (0.76, 0.79, 0.83)
SUN = (1.0, 0.76, 0.16)
CYAN = (0.45, 0.88, 1.0)
DARK = (0.07, 0.08, 0.1)
STEEL = (0.6, 0.63, 0.67)
LEAF = (0.27, 0.56, 0.27)
LEAF_LIGHT = (0.56, 0.78, 0.3)
WOOD = (0.72, 0.52, 0.32)
rng = random.Random(53)

EAVE = 12.6                                 # top of the walls (ring beam centre)
GLASS_TOP = 4.0                             # glass band below, welded mesh above
MULLIONS = (-8.5, -1.0, 6.5)                # front-wall mullions and the roof beams above them
BACK_MULLION = 8.5                          # just right of the camera zone behind the batter
TILT, ROW_PITCH, ROW_RUN = math.radians(18), 4.0, 3.25   # solar rows face the door end
DECK_X, DECK_Y = (-21.4, 19.4), (-18.0, 41.4)           # roof deck inside the parapet
FACE_Y = PITCH.y + 0.4                      # the machine's dark face, just behind the ball
AXLE_Y = FACE_Y + 2.4                       # its pedestal and trunnions
FLOWER_TILT = math.radians(20)
SHELL = [(0, 0.06), (1.16, 0.06), (1.22, 0.0), (1.34, 0.1), (1.42, 0.45), (1.44, 1.3), (1.42, 2.6),
         (1.32, 3.5), (1.08, 4.1), (0.72, 4.45), (0.3, 4.6), (0, 4.62)]     # (radius, depth behind the face)

LOOKS = {
    "SolarFrame": (ALUMINIUM, "hard"), "SolarPanels": (CELLS, "hard"), "SolarPanelRims": (SILVER, "hard"),
    "SolarPanelGrid": (SILVER, "soft"), "SolarGlass": (GLASS, "hard"), "SolarMesh": ((0.8, 0.9, 0.98), "soft"),
    "SolarLights": ((1.0, 0.97, 0.88), "hard"), "SolarLaneLights": (CYAN, "hard"), "SolarPlate": (WHITE, "hard"),
    "SolarMachineBody": (ALUMINIUM, "hard"), "SolarMachineFace": (DARK, "hard"), "SolarSunGlow": (SUN, "hard"),
    "SolarMachineGlow": (CYAN, "hard"), "SolarAccent": (SUN, "hard"), "SolarHopper": (GLASS, "smooth"),
    "SolarBalls": (WHITE, "smooth"), "SolarFlowerPetals": (CELLS, "hard"), "SolarFlowerGrid": (SILVER, "soft"),
    "SolarScreen": (GLASS, "hard"),
    "SolarDeck": ((0.7, 0.7, 0.68), "hard"), "SolarParapet": ((0.86, 0.86, 0.84), "hard"), "SolarRailing": (STEEL, "hard"),
    "SolarHVAC": ((0.8, 0.82, 0.84), "hard"), "SolarVents": ((0.3, 0.32, 0.35), "hard"),
    "SolarFanA": (DARK, "hard"), "SolarFanB": (DARK, "hard"), "SolarFanC": (DARK, "hard"),
    "SolarTurbineRotor": (ALUMINIUM, "smooth"), "SolarHut": ((0.92, 0.92, 0.9), "hard"),
    "SolarBeacon": ((1.0, 0.15, 0.1), "smooth"),
    "SolarPlanters": (ALUMINIUM, "hard"), "SolarWood": (WOOD, "hard"), "SolarSoil": ((0.3, 0.2, 0.13), "hard"),
    "SolarMoss": ((0.16, 0.3, 0.14), "hard"),
    "SolarTrunks": ((0.42, 0.3, 0.2), "smooth"), "SolarLeaves": (LEAF, "soft"), "SolarLeavesLight": (LEAF_LIGHT, "soft"),
    "SolarFlowers": ((1.0, 0.82, 0.25), "soft"),
}


# ---------- small builders ----------

def rrect(w, h, r, n=3):
    """A closed rounded-rectangle profile (u, v) centred on the origin."""
    points = []
    for cx, cy, start in ((w / 2 - r, h / 2 - r, 0), (r - w / 2, h / 2 - r, 90), (r - w / 2, r - h / 2, 180),
                          (w / 2 - r, r - h / 2, 270)):
        for k in range(n + 1):
            a = math.radians(start + 90 * k / n)
            points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return points


def extrude(bm, a, b, profile, up=(0, 0, 1)):
    """A straight member from a to b with a closed profile whose v axis leans toward up."""
    a, b = Vector(a), Vector(b)
    t = (b - a).normalized()
    v = Vector(up) - t * Vector(up).dot(t)
    if v.length < 1e-6:
        v = Vector((0, 1, 0)) - t * t.y
    v.normalize()
    u = t.cross(v)
    rings = [[bm.verts.new(p + u * pu + v * pv) for pu, pv in profile] for p in (a, b)]
    for k in range(len(profile)):
        j = (k + 1) % len(profile)
        bm.faces.new((rings[0][k], rings[0][j], rings[1][j], rings[1][k]))
    bm.faces.new(tuple(reversed(rings[0])))
    bm.faces.new(tuple(rings[1]))


def slab(bm, points, thickness, normal=None):
    """A flat convex plate through points, thickened evenly to both sides."""
    points = [Vector(p) for p in points]
    if normal is None:
        normal = (points[1] - points[0]).cross(points[2] - points[0])
    half = Vector(normal).normalized() * thickness / 2
    low, high = [bm.verts.new(p - half) for p in points], [bm.verts.new(p + half) for p in points]
    bm.faces.new(tuple(reversed(low)))
    bm.faces.new(tuple(high))
    for i in range(len(points)):
        j = (i + 1) % len(points)
        bm.faces.new((low[i], low[j], high[j], high[i]))


def strands(bm, origin, u_axis, v_axis, u_len, v_len, direction, spacing, width, holes=()):
    """Straight flat double-sided strands across a u_len x v_len rectangle, running along
    direction (du, dv) every spacing; holes are (u0, u1, v0, v1) rectangles left open."""
    origin, u_axis, v_axis = Vector(origin), Vector(u_axis), Vector(v_axis)
    length = math.hypot(*direction)
    d = (direction[0] / length, direction[1] / length)
    p = (-d[1], d[0])

    def span(c, u0, u1, v0, v1):
        t0, t1 = -1e9, 1e9
        for base, step, lo, hi in ((c * p[0], d[0], u0, u1), (c * p[1], d[1], v0, v1)):
            if abs(step) < 1e-9:
                if not lo - 1e-6 <= base <= hi + 1e-6:
                    return None
            else:
                a, b = (lo - base) / step, (hi - base) / step
                t0, t1 = max(t0, min(a, b)), min(t1, max(a, b))
        return (t0, t1) if t1 > t0 else None

    reach = [u * p[0] + v * p[1] for u in (0, u_len) for v in (0, v_len)]
    across = (u_axis * p[0] + v_axis * p[1]) * (width / 2)
    for k in range(math.floor(min(reach) / spacing - 1e-6), math.ceil(max(reach) / spacing + 1e-6) + 1):
        c = k * spacing
        whole = span(c, 0, u_len, 0, v_len)
        if not whole:
            continue
        pieces = [whole]
        for hole in holes:
            cut = span(c, *hole)
            if cut:
                pieces = [q for a, b in pieces for q in ((a, min(b, cut[0])), (max(a, cut[1]), b)) if q[1] - q[0] > width]
        for t0, t1 in pieces:
            ends = [origin + u_axis * (c * p[0] + t * d[0]) + v_axis * (c * p[1] + t * d[1]) for t in (t0, t1)]
            double_sided_strip(bm, [e - across for e in ends], [e + across for e in ends])


def welded_mesh(bm, origin, u_axis, u_len, v_len, step=1.0, width=0.08, holes=()):
    """A square welded mesh panel standing upright, strands spaced to fit its edges exactly."""
    up = Vector((0, 0, 1))
    strands(bm, origin, u_axis, up, u_len, v_len, (0, 1), u_len / max(1, round(u_len / step)), width, holes)
    strands(bm, origin, u_axis, up, u_len, v_len, (1, 0), v_len / max(1, round(v_len / step)), width, holes)


def solar_module(m, origin, u_axis, s_axis, width, length, cells=(6, 6), prefix="Solar"):
    """A glass solar module with a silver rim and cell grid lines on top. origin is its low
    corner, u_axis runs across it and s_axis up its slope."""
    o, u, s = Vector(origin), Vector(u_axis).normalized(), Vector(s_axis).normalized()
    n = u.cross(s).normalized()
    corners = [o, o + u * width, o + u * width + s * length, o + s * length]
    slab(m[prefix + "Panels"], corners, 0.07, n)
    bar = [(-0.06, -0.055), (0.06, -0.055), (0.06, 0.055), (-0.06, 0.055)]
    for a, b in zip(corners, corners[1:] + corners[:1]):
        t = (b - a).normalized() * 0.06
        extrude(m[prefix + "PanelRims"], a - t, b + t, bar, up=n)
    grid, lift = m[prefix + "PanelGrid"], n * 0.047
    for i in range(1, cells[0]):
        a = o + u * (width * i / cells[0]) + lift
        double_sided_strip(grid, [a - u * 0.022, a - u * 0.022 + s * length], [a + u * 0.022, a + u * 0.022 + s * length])
    for j in range(1, cells[1]):
        a = o + s * (length * j / cells[1]) + lift
        double_sided_strip(grid, [a - s * 0.022, a - s * 0.022 + u * width], [a + s * 0.022, a + s * 0.022 + u * width])


def shell_radius(depth):
    for (r0, d0), (r1, d1) in zip(SHELL[1:], SHELL[2:]):
        if min(d0, d1) <= depth <= max(d0, d1) and d1 != d0:
            return r0 + (r1 - r0) * (depth - d0) / (d1 - d0)
    return 1.4


def sized(along_x, length, width, height):
    return (length, width, height) if along_x else (width, length, height)


# ---------- the cage ----------

def build_frame(m):
    """White aluminium posts, ring beam, rafters, roof beams and the door frame."""
    frame = m["SolarFrame"]
    post, thin = rrect(0.5, 0.46, 0.12), rrect(0.3, 0.3, 0.08)
    for y in HOOPS:
        for x in (LEFT_X, RIGHT_X):
            extrude(frame, (x, y, 0.0), (x, y, EAVE), post, up=(1, 0, 0))
            box(frame, (x, y, 0.05), (0.85, 0.85, 0.1))
    for x in MULLIONS:
        extrude(frame, (x, FRONT_Y, 0.0), (x, FRONT_Y, EAVE), thin, up=(0, 1, 0))
    extrude(frame, (BACK_MULLION, BACK_Y, 0.0), (BACK_MULLION, BACK_Y, EAVE), thin, up=(0, 1, 0))
    for x in (DOOR[0] - 0.15, DOOR[1] + 0.15):
        extrude(frame, (x, BACK_Y, 0.0), (x, BACK_Y, DOOR[2] + 0.25), thin, up=(0, 1, 0))
    extrude(frame, (DOOR[0] - 0.3, BACK_Y, DOOR[2] + 0.25), (DOOR[1] + 0.3, BACK_Y, DOOR[2] + 0.25), rrect(0.46, 0.5, 0.1))
    # A glowing strip under the entrance sign.
    box(m["SolarSunGlow"], ((DOOR[0] + DOOR[1]) / 2, BACK_Y - 0.25, DOOR[2] + 0.25), (DOOR[1] - DOOR[0] + 0.4, 0.06, 0.12))
    for x in (LEFT_X, RIGHT_X):
        extrude(frame, (x, BACK_Y - 0.25, EAVE), (x, FRONT_Y + 0.25, EAVE), rrect(0.5, 0.62, 0.12))
    for y in HOOPS:
        extrude(frame, (LEFT_X - 0.22, y, EAVE), (RIGHT_X + 0.22, y, EAVE), rrect(0.44, 0.56, 0.12))
    for x in MULLIONS:
        extrude(frame, (x, BACK_Y, EAVE + 0.02), (x, FRONT_Y, EAVE + 0.02), rrect(0.36, 0.5, 0.1))
    # LED light bars under the middle rafters, a sun-yellow line around the eave, and glowing
    # studs along both edges of the pitch lane (clear of the batter's boxes and the screen).
    for y in HOOPS[2:-1]:
        box(m["SolarLights"], (-1.0, y, EAVE - 0.33), (22.0, 0.22, 0.1))
    for x in (LEFT_X - 0.265, RIGHT_X + 0.265):
        box(m["SolarAccent"], (x, (BACK_Y + FRONT_Y) / 2, EAVE), (0.03, FRONT_Y - BACK_Y + 0.5, 0.14))
    for y in (BACK_Y - 0.235, FRONT_Y + 0.235):
        box(m["SolarAccent"], ((LEFT_X + RIGHT_X) / 2, y, EAVE), (RIGHT_X - LEFT_X + 0.44, 0.03, 0.14))
    for y in arange(14.0, 2.0):
        for x in (PITCH.x - 3.25, PITCH.x + 3.25):
            lathe(m["SolarLaneLights"], [(0, 0), (0.22, 0), (0.2, 0.05), (0, 0.065)], 16,
                  transform=Matrix.Translation((x, 5.0 + y, 0)))


def build_walls(m):
    """Sky-blue glass below and welded mesh above, between the posts; the door end stays open
    at the door and has no rail across the camera zone behind the batter."""
    frame, glass, mesh = m["SolarFrame"], m["SolarGlass"], m["SolarMesh"]
    mesh_top = EAVE - 0.32

    def bay(a, b, inset=(0.3, 0.3), rail=True, glass_band=True, mesh_from=GLASS_TOP + 0.16):
        a, b = Vector((a[0], a[1], 0.0)), Vector((b[0], b[1], 0.0))
        along = (b - a).normalized()
        start, end = a + along * inset[0], b - along * inset[1]
        length, middle = (end - start).length, (start + end) / 2
        along_x = abs(along.x) > 0.5
        if glass_band:
            box(glass, (middle.x, middle.y, 0.2 + (GLASS_TOP - 0.18) / 2), sized(along_x, length, 0.06, GLASS_TOP - 0.18))
            extrude(frame, (start.x, start.y, 0.1), (end.x, end.y, 0.1), rrect(0.26, 0.2, 0.05))
        if rail:
            extrude(frame, (start.x, start.y, GLASS_TOP + 0.08), (end.x, end.y, GLASS_TOP + 0.08), rrect(0.2, 0.16, 0.06))
        welded_mesh(mesh, start + Vector((0, 0, mesh_from)), along, length, mesh_top - mesh_from)

    for x in (LEFT_X, RIGHT_X):
        for y0, y1 in zip(HOOPS, HOOPS[1:]):
            bay((x, y0), (x, y1))
    columns = (LEFT_X,) + MULLIONS + (RIGHT_X,)
    for x0, x1 in zip(columns, columns[1:]):
        bay((x0, FRONT_Y), (x1, FRONT_Y), inset=(0.3 if x0 == LEFT_X else 0.2, 0.3 if x1 == RIGHT_X else 0.2))
    bay((LEFT_X, BACK_Y), (DOOR[0] - 0.15, BACK_Y), inset=(0.3, 0.2))
    bay((DOOR[0] - 0.15, BACK_Y), (DOOR[1] + 0.15, BACK_Y), inset=(0.15, 0.15), rail=False, glass_band=False,
        mesh_from=DOOR[2] + 0.5)
    bay((DOOR[1] + 0.15, BACK_Y), (BACK_MULLION, BACK_Y), inset=(0.2, 0.2), rail=False)
    bay((BACK_MULLION, BACK_Y), (RIGHT_X, BACK_Y), inset=(0.2, 0.3))


def build_roof(m):
    """The solar canopy: twelve rows of tilted glass modules, their low edges resting on the
    roof beams and their high edges on slim struts."""
    frame = m["SolarFrame"]
    slope = Vector((0, math.cos(TILT), math.sin(TILT)))
    length = ROW_RUN / math.cos(TILT)
    low_z = EAVE + 0.36
    x0, x1, count, gap = LEFT_X - 0.2, RIGHT_X + 0.2, 8, 0.12
    width = (x1 - x0 - gap * (count - 1)) / count
    for j in range(12):
        y = BACK_Y + 0.35 + ROW_PITCH * j
        top = Vector((0, y, low_z)) + slope * (length - 0.15)
        for x in (LEFT_X,) + MULLIONS + (RIGHT_X,):
            extrude(frame, (x, top.y, EAVE + 0.28), (x, top.y, top.z - 0.05), rrect(0.16, 0.16, 0.05), up=(1, 0, 0))
        for k in range(count):
            solar_module(m, (x0 + k * (width + gap), y, low_z), (1, 0, 0), slope, width, length)


# ---------- machine and screen ----------

def build_machine(m):
    """A sleek white pitching machine on a yoke: a glowing sun around the ball port, sun
    emblems on both trunnions, LED rings, a ball hopper and a slowly turning solar flower."""
    body, face, sun, glow, accent = (m[n] for n in ("SolarMachineBody", "SolarMachineFace", "SolarSunGlow",
                                                     "SolarMachineGlow", "SolarAccent"))
    along_y = Matrix.Translation((PITCH.x, FACE_Y, PITCH.z)) @ Matrix.Rotation(-math.pi / 2, 4, "X")
    lathe(body, SHELL, 40, transform=along_y)
    lathe(face, [(0, 0.02), (1.17, 0.02), (1.17, 0.07), (0, 0.07)], 40, transform=along_y)
    torus(body, (PITCH.x, FACE_Y + 0.015, PITCH.z), (0, 1, 0), 0.44, 0.05, segments=28, minor_segments=6)
    center = Vector((PITCH.x, FACE_Y, PITCH.z))
    torus(sun, center, (0, 1, 0), 0.62, 0.05, segments=36, minor_segments=6)
    for k in range(12):
        a = 2 * math.pi * k / 12 + math.pi / 12
        d, s = Vector((math.cos(a), 0, math.sin(a))), Vector((-math.sin(a), 0, math.cos(a)))
        inner, outer = center + d * 0.76, center + d * (1.08 if k % 2 == 0 else 0.92)
        slab(sun, [inner - s * 0.085 + Vector((0, 0.005, 0)), outer + Vector((0, 0.005, 0)), inner + s * 0.085 + Vector((0, 0.005, 0))],
             0.025, Vector((0, -1, 0)))
    for depth in (0.5, 3.75):
        torus(glow, (PITCH.x, FACE_Y + depth, PITCH.z), (0, 1, 0), shell_radius(depth) + 0.012, 0.045, segments=48, minor_segments=6)

    # Pedestal, column and the yoke holding the body on two trunnions.
    base = Vector((PITCH.x, AXLE_Y, 0))
    lathe(body, [(0, 0), (1.95, 0), (2.0, 0.1), (1.9, 0.3), (1.45, 0.42), (0, 0.42)], 40, transform=Matrix.Translation(base))
    torus(face, base + Vector((0, 0, 0.07)), (0, 0, 1), 1.96, 0.075, segments=48, minor_segments=6)
    lathe(body, [(0, 0.38), (0.62, 0.38), (0.5, 0.8), (0.42, 1.45), (0.52, 1.72), (0, 1.72)], 28, transform=Matrix.Translation(base))
    for side in (-1, 1):
        sweep_profile(body, [Vector((PITCH.x + side * 0.4, AXLE_Y, 1.55)), Vector((PITCH.x + side * 1.12, AXLE_Y, 1.62)),
                             Vector((PITCH.x + side * 1.6, AXLE_Y, 2.15)), Vector((PITCH.x + side * 1.62, AXLE_Y, 3.0))],
                      rrect(0.5, 0.3, 0.1))
        cylinder_x(body, (PITCH.x + side * 1.55, AXLE_Y, PITCH.z), 0.6, 0.24, 20)
        cylinder_x(body, (PITCH.x + side * 1.84, AXLE_Y, PITCH.z), 0.16, 1.0, 48)
        torus(accent, (PITCH.x + side * 1.84, AXLE_Y, PITCH.z), (1, 0, 0), 1.0, 0.07, segments=48, minor_segments=6)
        c = Vector((PITCH.x + side * 1.935, AXLE_Y, PITCH.z))
        cylinder_x(sun, c, 0.03, 0.26, 24)
        torus(sun, c, (1, 0, 0), 0.43, 0.045, segments=32, minor_segments=5)
        for k in range(12):
            a = 2 * math.pi * k / 12 + math.pi / 12
            d, s = Vector((0, math.cos(a), math.sin(a))), Vector((0, -math.sin(a), math.cos(a)))
            inner, outer = c + d * 0.56, c + d * (0.88 if k % 2 == 0 else 0.74)
            slab(sun, [inner - s * 0.07, outer, inner + s * 0.07], 0.02, Vector((side, 0, 0)))

    # Hopper of practice balls at the back of the body.
    hop = Vector((PITCH.x, FACE_Y + 3.7, 4.12))
    lathe(body, [(0.5, 0.0), (0.68, 0.0), (0.68, 0.2), (0.5, 0.2), (0.5, 0.0)], 28, transform=Matrix.Translation(hop))
    lathe(m["SolarHopper"], [(0, 0.2), (0.6, 0.2), (0.58, 0.38), (0.47, 0.6), (0.28, 0.74), (0, 0.79)], 28,
          transform=Matrix.Translation(hop))
    for offset in ((0.18, 0.12, 0.42), (-0.2, 0.05, 0.42), (0.02, -0.22, 0.42), (0.0, 0.08, 0.66)):
        ball(m["SolarBalls"], hop + Vector(offset), 0.21, subdivisions=2)

    # The solar flower: twelve glass petals on a mast, tilted toward the batter. The petals and
    # their grid lines are two meshes that spin together about the flower's axis.
    n = Vector((0, -math.sin(FLOWER_TILT), math.cos(FLOWER_TILT)))
    flower = Vector((PITCH.x, AXLE_Y - 0.6, 6.55))
    tube(body, (PITCH.x, flower.y - 0.25, 4.2), flower - n * 0.2, 0.13, segments=12)
    ball(body, flower - n * 0.2, 0.22, subdivisions=2)
    cylinder(body, flower - n * 0.08, n, 0.16, 0.5, segments=32)
    lathe(accent, [(0, 0), (0.32, 0), (0.28, 0.12), (0.16, 0.22), (0, 0.26)], 24,
          transform=Matrix.Translation(flower + n * 0.08) @ align_z(n))
    e1 = Vector((1, 0, 0))
    e2 = n.cross(e1)
    outline = [(0.45, -0.1), (1.2, -0.28), (2.0, -0.44), (2.4, -0.4), (2.6, -0.2), (2.65, 0.0), (2.6, 0.2), (2.4, 0.4),
               (2.0, 0.44), (1.2, 0.28), (0.45, 0.1)]
    half_width = {1.0: 0.23, 1.5: 0.34, 2.0: 0.44}
    for k in range(12):
        a = 2 * math.pi * k / 12
        radial = e1 * math.cos(a) + e2 * math.sin(a)
        tangent = n.cross(radial)
        # Petals stay clear of each other, so both meshes are symmetric about the flower centre
        # and turn about the same axis.
        slab(m["SolarFlowerPetals"], [flower + radial * r + tangent * t for r, t in outline], 0.05, n)
        g = flower + n * 0.03
        double_sided_strip(m["SolarFlowerGrid"], [g + radial * 0.6 - tangent * 0.02, g + radial * 2.5 - tangent * 0.02],
                           [g + radial * 0.6 + tangent * 0.02, g + radial * 2.5 + tangent * 0.02])
        for r, w in half_width.items():
            w -= 0.05
            double_sided_strip(m["SolarFlowerGrid"], [g + radial * (r - 0.02) - tangent * w, g + radial * (r - 0.02) + tangent * w],
                               [g + radial * (r + 0.02) - tangent * w, g + radial * (r + 0.02) + tangent * w])
    home_plate(m["SolarPlate"], 0.08)


def build_screen(m):
    """A glass screen in a white frame with a glowing window ring and a solar strip on top."""
    frame, sun = m["SolarFrame"], m["SolarSunGlow"]
    x0, x1, top = PITCH.x - 3.3, PITCH.x + 3.3, 6.5
    slab_with_window(m["SolarScreen"], x0, x1, 0.3, top, (PITCH.x, PITCH.z), WINDOW + 0.06, SCREEN_Y, 0.1, segments=48)
    for x in (x0 - 0.16, x1 + 0.16):
        extrude(frame, (x, SCREEN_Y, 0.0), (x, SCREEN_Y, top + 0.3), rrect(0.32, 0.32, 0.08), up=(0, 1, 0))
        extrude(frame, (x, SCREEN_Y - 1.5, 0.1), (x, SCREEN_Y + 1.5, 0.1), rrect(0.34, 0.2, 0.06))
    for z in (0.22, top + 0.08):
        extrude(frame, (x0 - 0.16, SCREEN_Y, z), (x1 + 0.16, SCREEN_Y, z), rrect(0.28, 0.24, 0.07))
    for y in (SCREEN_Y - 0.08, SCREEN_Y + 0.08):
        torus(frame, (PITCH.x, y, PITCH.z), (0, 1, 0), WINDOW + 0.12, 0.06, segments=40, minor_segments=6)
    torus(sun, (PITCH.x, SCREEN_Y - 0.15, PITCH.z), (0, 1, 0), WINDOW + 0.24, 0.035, segments=40, minor_segments=5)
    tilt = math.radians(26)
    solar_module(m, (x0 - 0.1, SCREEN_Y - 0.45, top + 0.42), (1, 0, 0), (0, math.cos(tilt), math.sin(tilt)),
                 x1 - x0 + 0.2, 1.0, cells=(10, 2))
    for x in (x0 + 0.6, x1 - 0.6):
        extrude(frame, (x, SCREEN_Y, top + 0.15), (x, SCREEN_Y, top + 0.55), rrect(0.12, 0.12, 0.03), up=(1, 0, 0))


# ---------- the roof deck ----------

def build_deck(m):
    """Paver tiles, a parapet with a glass railing and LED handrail, around the cage."""
    deck = m["SolarDeck"]
    nx, ny = round((DECK_X[1] - DECK_X[0]) / 2.0), round((DECK_Y[1] - DECK_Y[0]) / 2.0)
    tx, ty = (DECK_X[1] - DECK_X[0]) / nx, (DECK_Y[1] - DECK_Y[0]) / ny
    fx0, fx1, fy0, fy1 = LEFT_X - 0.05, RIGHT_X + 0.05, BACK_Y - 0.05, FRONT_Y + 0.05
    for i in range(nx):
        for j in range(ny):
            x0, x1 = DECK_X[0] + tx * i, DECK_X[0] + tx * (i + 1)
            y0, y1 = DECK_Y[0] + ty * j, DECK_Y[0] + ty * (j + 1)
            parts = [(x0, x1, y0, y1)]
            if x0 < fx1 and x1 > fx0 and y0 < fy1 and y1 > fy0:
                parts = []
                if x0 < fx0:
                    parts.append((x0, fx0, y0, y1))
                if x1 > fx1:
                    parts.append((fx1, x1, y0, y1))
                mx0, mx1 = max(x0, fx0), min(x1, fx1)
                if y0 < fy0:
                    parts.append((mx0, mx1, y0, fy0))
                if y1 > fy1:
                    parts.append((mx0, mx1, fy1, y1))
            for a0, a1, b0, b1 in parts:
                if a1 - a0 > 0.2 and b1 - b0 > 0.2:
                    box(deck, ((a0 + a1) / 2, (b0 + b1) / 2, -0.02), (a1 - a0 - 0.1, b1 - b0 - 0.1, 0.16))

    # Railing runs between corner points; a run that joins a side run at an end stops its
    # parapet, coping and LED strip at the side run's inner face and leaves the corner post to it.
    parapet, rail, glass, lights = m["SolarParapet"], m["SolarRailing"], m["SolarGlass"], m["SolarLights"]
    xl, xr, yb, yf = DECK_X[0], DECK_X[1], DECK_Y[0], DECK_Y[1]
    runs = [((xl, yb), (xl, yf), False, False), ((xr, yb), (xr, yf), False, False), ((xl, yf), (xr, yf), True, True),
            ((xl, yb), (LEFT_X - 0.4, yb), True, False), ((RIGHT_X + 0.4, yb), (xr, yb), False, True)]
    for (ax, ay), (bx, by), joins_a, joins_b in runs:
        a, b = Vector((ax, ay, 0)), Vector((bx, by, 0))
        along = (b - a).normalized()
        along_x, length = abs(along.x) > 0.5, (b - a).length

        def span(inset):
            pa = a + along * (inset if joins_a else -inset)
            pb = b - along * (inset if joins_b else -inset)
            return (pa + pb) / 2, (pb - pa).length
        middle, size = span(0.25)
        box(parapet, (middle.x, middle.y, 0.45), sized(along_x, size, 0.5, 1.1))
        middle, size = span(0.36)
        box(rail, (middle.x, middle.y, 1.04), sized(along_x, size, 0.72, 0.08))
        middle, size = span(0.06)
        box(lights, (middle.x, middle.y, 3.5), sized(along_x, size, 0.07, 0.05))
        count = max(1, math.ceil(length / 2.6))
        for i in range(count + 1):
            if (i == 0 and joins_a) or (i == count and joins_b):
                continue
            q = a + along * (length * i / count)
            extrude(rail, (q.x, q.y, 1.08), (q.x, q.y, 3.6), rrect(0.16, 0.16, 0.05), up=(1, 0, 0))
        for i in range(count):
            q = a + along * (length * (i + 0.5) / count)
            box(glass, (q.x, q.y, 2.3), sized(along_x, length / count - 0.26, 0.05, 2.3))
        tube(rail, (a.x, a.y, 3.66), (b.x, b.y, 3.66), 0.1, segments=10)


def hvac(m, x0, x1, y0, y1, height, fans):
    """A rooftop unit on a curb with louvres and fan shrouds; fans are (x, y, mesh name)."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    vents = m["SolarVents"]
    box(vents, (cx, cy, 0.17), (x1 - x0 + 0.25, y1 - y0 + 0.25, 0.34))
    box(m["SolarHVAC"], (cx, cy, 0.34 + (height - 0.34) / 2), (x1 - x0, y1 - y0, height - 0.34))
    for k in range(int((height - 1.0) / 0.28)):
        z = 0.75 + 0.28 * k
        box(vents, (cx, y0 - 0.04, z), (x1 - x0 - 0.7, 0.05, 0.2), Matrix.Rotation(math.radians(35), 4, "X"))
        box(vents, (x1 + 0.04, cy, z), (0.05, y1 - y0 - 0.7, 0.2), Matrix.Rotation(math.radians(-35), 4, "Y"))
    for fx, fy, name in fans:
        c = Vector((fx, fy, height))
        lathe(vents, [(1.02, 0.0), (1.18, 0.0), (1.18, 0.38), (1.02, 0.38), (1.02, 0.0)], 36, transform=Matrix.Translation(c))
        for radius in (0.42, 0.78, 1.1):
            torus(vents, c + Vector((0, 0, 0.42)), (0, 0, 1), radius, 0.03, segments=32, minor_segments=4)
        for k in range(8):
            a = 2 * math.pi * k / 8
            d = Vector((math.cos(a), math.sin(a), 0))
            tube(vents, c + Vector((0, 0, 0.42)) + d * 0.1, c + Vector((0, 0, 0.42)) + d * 1.12, 0.025, segments=4)
        cylinder(vents, c + Vector((0, 0, 0.38)), (0, 0, 1), 0.08, 0.16, segments=12)
        fan = m[name]
        lathe(fan, [(0, 0.06), (0.2, 0.06), (0.2, 0.24), (0, 0.29)], 16, transform=Matrix.Translation(c))
        for k in range(6):
            a = 2 * math.pi * k / 6
            r, t = Vector((math.cos(a), math.sin(a), 0)), Vector((-math.sin(a), math.cos(a), 0))
            chord = t * math.cos(0.45) + Vector((0, 0, math.sin(0.45)))
            p = c + Vector((0, 0, 0.16))
            slab(fan, [p + r * 0.18 - chord * 0.12, p + r * 0.95 - chord * 0.3, p + r * 0.98 + chord * 0.24, p + r * 0.18 + chord * 0.12],
                 0.03, r.cross(chord))


def mushroom_vent(m, x, y, scale=1.0):
    lathe(m["SolarVents"], [(0, 0), (0.28 * scale, 0), (0.28 * scale, 0.8 * scale), (0.66 * scale, 0.86 * scale), (0.6 * scale, 1.04 * scale),
                            (0.36 * scale, 1.18 * scale), (0, 1.24 * scale)], 20, transform=Matrix.Translation((x, y, 0)))


def gooseneck(m, x, y, heading):
    d = Vector((math.cos(heading), math.sin(heading), 0))
    base = Vector((x, y, 0))
    points = [base, base + Vector((0, 0, 1.4))]
    for i in range(1, 9):
        a = math.pi * i / 8
        points.append(base + Vector((0, 0, 1.4)) + d * 0.45 * (1 - math.cos(a)) + Vector((0, 0, 0.45 * math.sin(a))))
    points.append(points[-1] + Vector((0, 0, -0.35)))
    sweep(m["SolarHVAC"], points, 0.17, segments=12)


def build_rooftop(m):
    """HVAC units and a duct, vents, the wind turbine and the stair hut with its antenna."""
    hvac(m, -7.0, 1.0, 36.3, 40.4, 2.9, [(-5.0, 38.35, "SolarFanA"), (-1.0, 38.35, "SolarFanB")])
    hvac(m, 4.6, 8.8, 37.0, 40.4, 2.3, [(6.7, 38.7, "SolarFanC")])
    duct, vents = m["SolarHVAC"], m["SolarVents"]
    extrude(duct, (-6.9, 38.35, 1.75), (-11.0, 38.35, 1.75), rrect(1.0, 0.9, 0.1))
    extrude(duct, (-11.0, 38.35, 2.2), (-11.0, 38.35, -0.1), rrect(1.0, 0.9, 0.1), up=(1, 0, 0))
    for x in (-8.2, -9.6):
        extrude(vents, (x - 0.06, 38.35, 1.75), (x + 0.06, 38.35, 1.75), rrect(1.16, 1.06, 0.1))
    extrude(vents, (-11.0, 38.35, 0.95), (-11.0, 38.35, 1.07), rrect(1.16, 1.06, 0.1), up=(1, 0, 0))
    for x, y, s in ((-19.0, -11.5, 1.0), (-18.6, 3.0, 0.8), (17.4, -9.0, 1.0), (17.0, 13.5, 0.85), (-13.6, 39.8, 0.9), (11.4, 36.2, 0.8)):
        mushroom_vent(m, x, y, s)
    gooseneck(m, 16.6, 25.5, 0.5)
    gooseneck(m, -18.8, 9.0, math.pi)

    # Helical wind turbine at the outside corner of the machine end. The static shaft runs up
    # through the rotor, so the rotor can shrink in game (spinning parts shrink evenly) and still
    # sit on it.
    frame, rotor = m["SolarFrame"], m["SolarTurbineRotor"]
    c = Vector((-19.0, 38.6, 0.0))
    box(frame, c + Vector((0, 0, 0.1)), (1.4, 1.4, 0.2))
    lathe(frame, [(0, 0.2), (0.36, 0.2), (0.24, 10.0), (0.46, 10.06), (0.46, 10.5), (0, 10.5)], 20, transform=Matrix.Translation(c))
    cylinder(frame, c + Vector((0, 0, 10.4)), (0, 0, 1), 9.2, 0.11, segments=12)
    lathe(frame, [(0, 19.55), (0.22, 19.55), (0.18, 19.72), (0, 19.8)], 12, transform=Matrix.Translation(c))
    for a in (math.radians(20), math.radians(140), math.radians(260)):
        anchor = c + Vector((math.cos(a) * 2.2, math.sin(a) * 2.2, 0.05))
        tube(m["SolarRailing"], c + Vector((0, 0, 8.4)), anchor, 0.03, segments=5)
        box(m["SolarRailing"], anchor, (0.35, 0.35, 0.1))
    radius, z0, z1 = 2.3, 10.9, 19.3
    airfoil = [(-0.32, 0.0), (-0.22, 0.06), (0.0, 0.07), (0.22, 0.04), (0.32, 0.0), (0.22, -0.03), (0.0, -0.05), (-0.22, -0.05)]
    for k in range(3):
        slices = []
        for i in range(25):
            t = i / 24
            a = 2 * math.pi * k / 3 + (2 * math.pi / 3) * t
            radial, tangent = Vector((math.cos(a), math.sin(a), 0)), Vector((-math.sin(a), math.cos(a), 0))
            p = c + radial * radius + Vector((0, 0, z0 + (z1 - z0) * t))
            slices.append([rotor.verts.new(p + tangent * cu + radial * cv) for cu, cv in airfoil])
        for s0, s1 in zip(slices, slices[1:]):
            for j in range(len(airfoil)):
                q = (j + 1) % len(airfoil)
                rotor.faces.new((s0[j], s0[q], s1[q], s1[j]))
        rotor.faces.new(tuple(reversed(slices[0])))
        rotor.faces.new(tuple(slices[-1]))
        for t in (0.03, 0.5, 0.97):
            a = 2 * math.pi * k / 3 + (2 * math.pi / 3) * t
            radial = Vector((math.cos(a), math.sin(a), 0))
            z = z0 + (z1 - z0) * t
            extrude(rotor, c + radial * 0.12 + Vector((0, 0, z)), c + radial * (radius - 0.05) + Vector((0, 0, z)), rrect(0.36, 0.08, 0.03))
    for z in (z0 + (z1 - z0) * 0.03, z0 + (z1 - z0) * 0.5, z0 + (z1 - z0) * 0.97):
        lathe(rotor, [(0, z - 0.14), (0.24, z - 0.14), (0.24, z + 0.14), (0, z + 0.14)], 16, transform=Matrix.Translation((c.x, c.y, 0)))

    # The stair hut in the far right corner, a yellow door facing the deck, an antenna on top.
    hut = m["SolarHut"]
    box(hut, (16.3, 38.6, 2.7), (5.4, 4.8, 5.4))
    box(hut, (16.3, 38.6, 5.58), (6.0, 5.4, 0.36))
    box(m["SolarAccent"], (13.56, 38.7, 1.98), (0.08, 1.8, 3.9))
    for y in (37.72, 39.68):
        box(frame, (13.55, y, 2.05), (0.12, 0.16, 4.1))
    box(frame, (13.55, 38.7, 4.1), (0.12, 2.12, 0.16))
    box(m["SolarLights"], (13.5, 38.7, 4.55), (0.14, 0.9, 0.12))
    box(m["SolarGlass"], (16.3, 36.17, 3.5), (2.6, 0.06, 1.3))
    for z in (2.82, 4.18):
        box(frame, (16.3, 36.15, z), (2.8, 0.1, 0.1))
    for x in (14.95, 17.65):
        box(frame, (x, 36.15, 3.5), (0.1, 0.1, 1.46))
    tilt = math.radians(22)
    for k in range(2):
        solar_module(m, (13.9 + 2.15 * k, 36.6, 6.0), (1, 0, 0), (0, math.cos(tilt), math.sin(tilt)), 2.05, 2.6, cells=(4, 5))
    for x in (14.6, 16.4):
        for y in (36.8, 38.6):
            extrude(frame, (x, y, 5.76), (x, y, 6.0 + (y - 36.6) * math.tan(tilt)), rrect(0.12, 0.12, 0.03), up=(1, 0, 0))
    mast = Vector((18.1, 40.1, 5.76))
    rail = m["SolarRailing"]
    tube(rail, mast, mast + Vector((0, 0, 11.6)), 0.1, segments=10)
    for z, w in ((7.8, 1.2), (10.6, 0.9), (13.2, 0.7)):
        tube(rail, mast + Vector((-w, 0, z - 5.76)), mast + Vector((w, 0, z - 5.76)), 0.04, segments=6)
    facing = Vector((-1, -0.5, 0.35)).normalized()
    dish = mast + Vector((-0.32, -0.12, 3.1))
    tube(rail, mast + Vector((0, 0, 3.1)), dish, 0.04, segments=6)
    lathe(rail, [(0, 0), (0.24, 0.025), (0.42, 0.1), (0.46, 0.15), (0.42, 0.16), (0, 0.06)], 24,
          transform=Matrix.Translation(dish) @ align_z(facing))
    for k in range(3):
        a = 2 * math.pi * k / 3
        side = facing.cross(Vector((0, 0, 1))).normalized()
        rim = dish + facing * 0.12 + (side * math.cos(a) + facing.cross(side) * math.sin(a)) * 0.4
        tube(rail, rim, dish + facing * 0.55, 0.012, segments=4)
    ball(rail, dish + facing * 0.57, 0.06, subdivisions=1)
    ball(m["SolarBeacon"], mast + Vector((0, 0, 11.75)), 0.24, subdivisions=2)


# ---------- planting and furniture ----------

def planter(m, x0, x1, y0, y1, height=1.1):
    """A white planter box with a wooden rim; returns the soil height."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    box(m["SolarPlanters"], (cx, cy, height / 2), (x1 - x0, y1 - y0, height))
    for a, b, horizontal in (((x0, y0), (x1, y0), True), ((x0, y1), (x1, y1), True), ((x0, y0), (x0, y1), False), ((x1, y0), (x1, y1), False)):
        if horizontal:
            box(m["SolarWood"], ((a[0] + b[0]) / 2, a[1], height + 0.06), (x1 - x0 + 0.05, 0.26, 0.12))
        else:
            box(m["SolarWood"], (a[0], (a[1] + b[1]) / 2, height + 0.06), (0.26, y1 - y0 - 0.26, 0.12))
    box(m["SolarSoil"], (cx, cy, height + 0.01), (x1 - x0 - 0.2, y1 - y0 - 0.2, 0.06))
    return height + 0.04


def round_pot(m, x, y, height=1.3):
    lathe(m["SolarPlanters"], [(0, 0), (0.48, 0), (0.7, height - 0.08), (0.77, height), (0.66, height), (0, height - 0.1)], 24,
          transform=Matrix.Translation((x, y, 0)))
    lathe(m["SolarSoil"], [(0, height - 0.1), (0.66, height - 0.1), (0.64, height - 0.05), (0, height - 0.05)], 24,
          transform=Matrix.Translation((x, y, 0)))
    return height - 0.05


def blade(bm, base, direction, length, width, droop=0.35, segments=5):
    """A strap leaf arching out and down from base."""
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-3 else Vector((1, 0, 0))
    left, right = [], []
    for i in range(segments + 1):
        t = i / segments
        p = Vector(base) + d * length * t - Vector((0, 0, droop * length * t * t))
        w = width * (1 - t) ** 0.7 / 2 + 0.006
        left.append(p - side * w)
        right.append(p + side * w)
    double_sided_strip(bm, left, right)


def grass(m, base, count, height, name="SolarLeavesLight", spread=0.25, width=0.14):
    for _ in range(count):
        a, lean = rng.uniform(0, 2 * math.pi), rng.uniform(0.2, 0.75)
        offset = Vector((rng.uniform(-spread, spread), rng.uniform(-spread, spread), 0))
        blade(m[name], Vector(base) + offset, (math.cos(a) * lean, math.sin(a) * lean, 1), height * rng.uniform(0.7, 1.1), width,
              droop=rng.uniform(0.2, 0.45))


def blossom(m, center, radius, stem_from=None):
    """A five-petal flower facing up, on a thin stem rising from stem_from (soil) if given."""
    c, spin = Vector(center), rng.uniform(0, 2 * math.pi)
    for k in range(5):
        a = spin + 2 * math.pi * k / 5
        leaf(m["SolarFlowers"], c, (math.cos(a), math.sin(a), 0.3), (-math.sin(a), math.cos(a), 0), radius, radius * 0.75)
    if stem_from is not None:
        base = Vector(stem_from)
        sweep(m["SolarLeaves"], wavy(base, c - Vector((0, 0, 0.03)), 4, 0.06, seed=rng.random() * 9), 0.025, segments=5)


def stemmed_flowers(m, center, soil, count, spread, low, high, radius=0.2):
    for _ in range(count):
        base = Vector((center[0] + rng.uniform(-spread, spread), center[1] + rng.uniform(-spread, spread), soil - 0.02))
        top = base + Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), rng.uniform(low, high)))
        blossom(m, top, radius, stem_from=base)


def shrub(m, center, radius, flowers=0):
    c = Vector(center)
    blob(m["SolarLeaves"], c, Vector((radius, radius, radius * 0.85)), subdivisions=2, lump=0.2, lump_scale=2.2, seed=rng.random() * 9)
    blob(m["SolarLeavesLight"], c + Vector((0.1, -0.1, radius * 0.4)), Vector((radius * 0.6, radius * 0.6, radius * 0.45)),
         subdivisions=2, lump=0.25, seed=rng.random() * 9)
    for _ in range(flowers):
        a, up = rng.uniform(0, 2 * math.pi), rng.uniform(0.2, 0.9)
        p = c + Vector((math.cos(a) * radius * (1.0 - up * 0.4), math.sin(a) * radius * (1.0 - up * 0.4), radius * 0.85 * up))
        blossom(m, p, 0.16)


def olive_tree(m, base, height):
    b = Vector(base)
    lean = Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0))
    fork = b + lean + Vector((0, 0, height * 0.55))
    sweep_radii(m["SolarTrunks"], [b, b + lean * 0.4 + Vector((0, 0, height * 0.3)), fork], [0.17, 0.14, 0.12], segments=8)
    tips = []
    for k in range(3):
        a = 2 * math.pi * k / 3 + rng.uniform(-0.4, 0.4)
        tip = fork + Vector((math.cos(a) * height * 0.22, math.sin(a) * height * 0.22, height * 0.3))
        sweep_radii(m["SolarTrunks"], [fork, fork.lerp(tip, 0.5) + Vector((0, 0, 0.1)), tip], [0.1, 0.07, 0.05], segments=6)
        tips.append(tip)
    for tip in tips + [fork + Vector((0, 0, height * 0.42))]:
        s = height * rng.uniform(0.2, 0.25)
        blob(m["SolarLeaves"], tip, Vector((s, s, s * 0.8)), subdivisions=2, lump=0.3, lump_scale=2.0, seed=rng.random() * 9)
        blob(m["SolarLeavesLight"], tip + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), s * 0.38)),
             Vector((s * 0.7, s * 0.7, s * 0.5)), subdivisions=2, lump=0.3, seed=rng.random() * 9)


def bench(m, x, y, along_y=True):
    for k in range(3):
        offset = (k - 1) * 0.36
        center = (x + offset, y, 1.2) if along_y else (x, y + offset, 1.2)
        box(m["SolarWood"], center, sized(not along_y, 2.8, 0.3, 0.1))
    for end in (-1.1, 1.1):
        center = (x, y + end, 0.58) if along_y else (x + end, y, 0.58)
        box(m["SolarFrame"], center, sized(along_y, 1.1, 0.16, 1.16))


def lounger(m, x, y):
    """A wooden sun lounger along Y with a raised back toward +Y."""
    frame, wood = m["SolarPlanters"], m["SolarWood"]
    for dx in (-0.4, 0.4):
        box(frame, (x + dx, y - 0.2, 0.32), (0.08, 2.2, 0.08))
        for dy in (-1.1, 0.6):
            box(frame, (x + dx, y + dy, 0.16), (0.08, 0.08, 0.32))
    for k in range(7):
        box(wood, (x, y - 1.15 + 0.3 * k, 0.4), (0.9, 0.24, 0.07))
    back = Matrix.Rotation(math.radians(-55), 4, "X")
    for k in range(4):
        box(wood, (x, y + 1.0 + 0.16 * k, 0.55 + 0.23 * k), (0.9, 0.26, 0.07), back)
    box(frame, (x, y + 1.05, 0.62), (0.9, 0.08, 0.5))


def parasol(m, x, y):
    """A tilt-free market parasol with alternating sun-yellow and white panels."""
    c = Vector((x, y, 0))
    lathe(m["SolarVents"], [(0, 0), (0.45, 0), (0.42, 0.12), (0.12, 0.2), (0, 0.2)], 16, transform=Matrix.Translation(c))
    cylinder(m["SolarFrame"], c + Vector((0, 0, 0.15)), (0, 0, 1), 4.3, 0.06, segments=10)
    for k in range(8):
        a0, a1 = 2 * math.pi * k / 8, 2 * math.pi * (k + 1) / 8
        rim = [c + Vector((math.cos(a) * 1.9, math.sin(a) * 1.9, 3.55)) for a in (a0, a1)]
        slab(m["SolarAccent" if k % 2 else "SolarPlanters"], [c + Vector((0, 0, 4.25)), rim[0], rim[1]], 0.04)
        sweep(m["SolarFrame"], [c + Vector((0, 0, 4.2)), rim[0] + Vector((0, 0, -0.04))], 0.025, segments=4)
    ball(m["SolarFrame"], c + Vector((0, 0, 4.32)), 0.1, subdivisions=1)


def bollard(m, x, y):
    lathe(m["SolarFrame"], [(0, 0), (0.2, 0), (0.17, 1.0), (0, 1.0)], 14, transform=Matrix.Translation((x, y, 0)))
    lathe(m["SolarLights"], [(0, 1.0), (0.17, 1.0), (0.18, 1.18), (0, 1.22)], 14, transform=Matrix.Translation((x, y, 0)))


def ball_cart(m, x, y):
    c = Vector((x, y, 0))
    lathe(m["SolarFrame"], [(0, 0.9), (0.55, 0.9), (0.76, 1.9), (0.7, 1.92), (0.5, 0.98), (0, 0.98)], 24, transform=Matrix.Translation(c))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(m["SolarFrame"], c + d * 0.45 + Vector((0, 0, 0.92)), c + d * 0.62 + Vector((0, 0, 0.2)), 0.05, segments=6)
        cylinder_x(m["SolarMachineFace"], c + d * 0.62 + Vector((0, 0, 0.12)), 0.08, 0.12, 12)
    for i in range(9):
        a = 2 * math.pi * i / 9
        ball(m["SolarBalls"], c + Vector((math.cos(a) * 0.38, math.sin(a) * 0.38, 1.58 + 0.06 * (i % 2))), 0.21, subdivisions=2)
    ball(m["SolarBalls"], c + Vector((0, 0, 1.8)), 0.21, subdivisions=2)


def build_planting(m):
    """Planters and pots inside the edges and along the deck, benches and solar bollards."""
    soil = planter(m, -15.3, -12.7, 30.0, 32.6, 1.2)
    olive_tree(m, (-14.0, 31.3, soil), 5.2)
    grass(m, (-14.0, 31.3, soil), 14, 1.1)
    soil = planter(m, 10.7, 13.3, 30.0, 32.6, 1.2)
    shrub(m, (12.0, 31.3, soil + 0.75), 0.95, flowers=7)
    grass(m, (11.3, 30.6, soil), 8, 1.0)
    soil = planter(m, 10.9, 13.3, -12.9, -10.5, 1.0)
    grass(m, (12.1, -11.7, soil), 22, 2.2, spread=0.55)
    stemmed_flowers(m, (12.1, -11.7), soil, 6, 0.6, 1.2, 1.9)
    soil = planter(m, -15.3, -14.1, 3.0, 11.0, 0.9)
    for y in (4.3, 7.0, 9.7):
        shrub(m, (-14.7, y, soil + 0.55), 0.62, flowers=4)
    soil = planter(m, 12.4, 13.5, 13.0, 19.0, 0.9)
    for y in (13.9, 15.4, 16.9, 18.2):
        grass(m, (12.95, y, soil), 9, 1.5, spread=0.2)
    for x in (-2.2, 8.2):
        soil = round_pot(m, x, 20.0)
        grass(m, (x, 20.0, soil), 12, 1.6, name="SolarLeaves", spread=0.2, width=0.22)
        stemmed_flowers(m, (x, 20.0), soil, 4, 0.3, 1.0, 1.5)
    ball_cart(m, 9.6, 24.6)
    # Living walls inside the front wall's outer bays, framing the machine for the batter.
    for x0, x1 in ((LEFT_X + 0.35, MULLIONS[0] - 0.25), (MULLIONS[2] + 0.25, RIGHT_X - 0.35)):
        wall_y = FRONT_Y - 0.45
        box(m["SolarMoss"], ((x0 + x1) / 2, wall_y, 2.3), (x1 - x0, 0.3, 4.1))
        box(m["SolarWood"], ((x0 + x1) / 2, wall_y - 0.15, 4.4), (x1 - x0 + 0.1, 0.6, 0.14))
        box(m["SolarPlanters"], ((x0 + x1) / 2, wall_y - 0.45, 0.35), (x1 - x0 + 0.1, 0.9, 0.7))
        for _ in range(int((x1 - x0) * 7.5)):
            x, z = rng.uniform(x0 + 0.3, x1 - 0.3), rng.uniform(0.95, 4.0)
            s = rng.uniform(0.3, 0.52)
            name = "SolarLeavesLight" if rng.random() < 0.35 else "SolarLeaves"
            blob(m[name], Vector((x, wall_y - 0.2 - rng.uniform(0, 0.12), z)), Vector((s, s * 0.6, s * rng.uniform(0.7, 0.95))),
                 subdivisions=1, lump=0.35, lump_scale=2.5, seed=rng.random() * 9)
        for _ in range(int((x1 - x0) * 7)):
            base = Vector((rng.uniform(x0 + 0.2, x1 - 0.2), wall_y - 0.36, rng.uniform(0.9, 4.1)))
            name = "SolarLeavesLight" if rng.random() < 0.5 else "SolarLeaves"
            for k in range(5):
                a = rng.uniform(0, 2 * math.pi)
                leaf(m[name], base, (math.cos(a) * 0.9, -1.0, math.sin(a) * 0.9), (math.sin(a), 0, -math.cos(a)),
                     rng.uniform(0.55, 0.85), 0.32)
            if rng.random() < 0.3:
                blade(m["SolarLeaves"], base, (rng.uniform(-0.3, 0.3), -0.6, -0.2), rng.uniform(0.7, 1.2), 0.12, droop=0.6)
            if rng.random() < 0.2:
                blossom(m, base + Vector((0, -0.25, 0)), 0.16)
    # A sun-lounge corner on the left deck: two loungers under a striped parasol.
    for x in (-20.0, -17.8):
        lounger(m, x, 21.4)
    parasol(m, -18.9, 24.2)
    # Along the deck, between the cage and the parapet.
    for y0, y1, tree in ((-16.0, -8.0, -12.0), (-4.0, 4.0, None), (27.5, 33.5, 30.5)):
        soil = planter(m, -20.9, -19.7, y0, y1, 1.0)
        for y in arange(y1 - y0 - 1.0, 1.4):
            grass(m, (-20.3, y0 + 0.5 + y, soil), 6, 1.2, spread=0.2)
        if tree:
            olive_tree(m, (-20.3, tree, soil), 4.6)
    soil = planter(m, 17.9, 19.1, 15.0, 24.0, 1.0)
    olive_tree(m, (18.5, 19.5, soil), 4.4)
    for y in (16.0, 17.6, 21.4, 23.0):
        shrub(m, (18.5, y, soil + 0.45), 0.5, flowers=3)
    soil = planter(m, 9.6, 12.6, 38.6, 40.8, 1.0)
    grass(m, (11.1, 39.7, soil), 16, 1.4, spread=0.6)
    bench(m, -18.4, 13.0)
    bench(m, 16.6, -4.0)
    for y in (-8.0, 2.0, 14.0, 26.0):
        bollard(m, -17.4, y)
        bollard(m, 15.4, y)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = {name: bmesh.new() for name in LOOKS}
    build_frame(m)
    build_walls(m)
    build_roof(m)
    build_machine(m)
    build_screen(m)
    build_deck(m)
    build_rooftop(m)
    build_planting(m)
    objects = []
    for name, (rgb, shading) in LOOKS.items():
        bm = m[name]
        if not bm.verts:
            bm.free()
            continue
        objects.append(soft(coll, name, bm, rgb) if shading == "soft" else finish(coll, name, bm, rgb, hard=shading == "hard"))
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
