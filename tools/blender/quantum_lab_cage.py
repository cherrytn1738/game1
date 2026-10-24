# Training Ground 5 of World 3, Quantum Lab, the paid showpiece (it shares Cosmic Rift's game
# pass): a lab pod of graphite ribs and translucent hologram walls traced with glowing grid
# lines and data glyphs, three huge energy rings turning round the cage, a particle
# accelerator floating overhead with racing beam bunches, glitching data cubes, a quantum
# reactor pulsing behind the machine end inside gyroscopic containment rings, a teleporter
# ring whose vortex core launches each pitch, a holographic screen, golden quantum computers,
# server racks and floating holo displays inside, a circuit-grid floor, and a glowing lab deck
# with slots the energy rings pass through.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py and the
# shared helpers at the top of lunar_base_cage.py; the mesh names are what TrainingCageStyles
# looks up for colors, materials and motion. Roles used by several builders collect in PARTS.
# TrainingStadium squeezes every cage to 75% width but shrinks spinning parts evenly about
# their own centre, so each spinning mesh is centred (bounding box) on its spin axis and built
# at 4/3 of its in-game size, and the static parts around them leave room in both shapes.
LUNAR = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\lunar_base_cage.py"
_source = open(LUNAR, encoding="utf-8").read()
_marker = "# ---------- Lunar Base ----------"
assert _marker in _source, "lunar_base_cage.py layout changed"
exec(_source.partition(_marker)[0])

COLLECTION = "QuantumLabCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\QuantumLabCage.fbx"

GRAPHITE = (0.13, 0.14, 0.19)
LAB_WHITE = (0.9, 0.93, 0.97)
CYAN = (0.3, 0.9, 1.0)
MAGENTA = (1.0, 0.3, 0.85)
VIOLET = (0.62, 0.38, 1.0)
GOLD = (1.0, 0.78, 0.3)
rng = random.Random(97)

WALL, ROOF = 10.5, 14.6                # vertical walls (the banners hang on them), flat roof
CHAMFER = ROOF - WALL                  # 45-degree chamfers between them
CX = (LEFT_X + RIGHT_X) / 2
GROW = 4 / 3                           # spinning parts shrink evenly to 75% in game
RING_Z = 7.3                           # the energy rings turn round the cage's long axis here
RINGS = (("A", -4.0, 18.9), ("B", 13.5, 19.7), ("C", 30.5, 20.4))   # name, y, radius
ACCEL, ACCEL_R = Vector((CX, 13.5, 18.0)), 10.0
REACTOR = Vector((PITCH.x, 42.0, 9.5))
PORTAL = Vector((PITCH.x, PITCH.y + 0.62, PITCH.z))
DECK_X, DECK_Y, DECK_H = (LEFT_X - 4.9, RIGHT_X + 4.9), (BACK_Y - 4.2, FRONT_Y + 16.0), 0.24
CORNERS = [Vector((LEFT_X, 0, 0)), Vector((LEFT_X, 0, WALL)), Vector((LEFT_X + CHAMFER, 0, ROOF)),
           Vector((RIGHT_X - CHAMFER, 0, ROOF)), Vector((RIGHT_X, 0, WALL)), Vector((RIGHT_X, 0, 0))]


def fillet(points, radius=0.6, steps=4):
    """Round the corners of a polyline with small curves."""
    out = [points[0]]
    for a, b, c in zip(points, points[1:], points[2:]):
        p, q = b - (b - a).normalized() * radius, b + (c - b).normalized() * radius
        out += [p.lerp(b, i / steps).lerp(b.lerp(q, i / steps), i / steps) for i in range(steps + 1)]
    return out + [points[-1]]


PROFILE = Polyline(fillet(CORNERS))    # the ribs
SHARP = Polyline(CORNERS)              # the hologram panels


def outline_height(x):
    """Height of the cage outline above x (the end walls)."""
    best = 0.0
    for a, b in zip(CORNERS, CORNERS[1:]):
        if min(a.x, b.x) - 1e-6 <= x <= max(a.x, b.x) + 1e-6:
            t = 0.0 if abs(b.x - a.x) < 1e-9 else (x - a.x) / (b.x - a.x)
            best = max(best, a.z + (b.z - a.z) * t)
    return best


def line_strip(bm, a, b, across, width):
    """A flat glowing line from a to b, double-sided, width measured along across."""
    half = Vector(across).normalized() * width / 2
    a, b = Vector(a), Vector(b)
    double_sided_strip(bm, [a - half, b - half], [a + half, b + half])


def band_arc(bm, center, e1, e2, normal, radius, a0, a1, profile, steps):
    """Sweep a closed (u along normal, v outward) profile round an arc from angle a0 to a1."""
    rings = []
    for i in range(steps + 1):
        a = a0 + (a1 - a0) * i / steps
        radial = e1 * math.cos(a) + e2 * math.sin(a)
        rings.append([bm.verts.new(center + radial * (radius + v) + normal * u) for u, v in profile])
    n = len(profile)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((r0[k], r0[j], r1[j], r1[k]))
    if a1 - a0 < 2 * math.pi - 1e-6:
        bm.faces.new(tuple(reversed(rings[0])))
        bm.faces.new(tuple(rings[-1]))


def basis(normal):
    """Two unit vectors spanning the plane perpendicular to normal."""
    n = Vector(normal).normalized()
    e1 = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
    return e1, n.cross(e1), n


def xz_box(bm, x0, x1, z0, z1, y0, y1):
    box(bm, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0))


def xz_prism(bm, outline_xz, y0, y1):
    """Extrude a closed (x, z) outline along Y between y0 and y1."""
    before = len(bm.verts)
    prism(bm, outline_xz, y0, y1)
    transform_new(bm, before, Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1))))


# ---------- the lab pod ----------

def build_pod():
    frame, glow, nodes, trim = part("QuantumFrame"), part("QuantumEdgeGlow"), part("QuantumNodes"), part("QuantumTrim")
    for y in HOOPS:
        offset = Vector((0, y, 0))
        path = [p + offset for p in PROFILE.points]
        # Graphite ribs with a glowing line down the inside and outside of each.
        sweep_profile(frame, path, [(-0.35, -0.45), (0.35, -0.45), (0.35, 0.25), (-0.35, 0.25)])
        sweep_profile(glow, path, [(-0.09, -0.5), (0.09, -0.5), (0.09, -0.44), (-0.09, -0.44)])
        sweep_profile(glow, path, [(-0.09, 0.24), (0.09, 0.24), (0.09, 0.3), (-0.09, 0.3)])
        # White armour plates on the walls, hexagonal power nodes on the corners, hex feet.
        for s in (2.4, 6.2, PROFILE.length - 2.4, PROFILE.length - 6.2):
            p, t, o = profile_frame(PROFILE, s)
            box(trim, p + offset - o * 0.1, (2.2, 0.82, 0.86), axes(t, Y_AXIS, o))
        for corner in CORNERS[1:5]:
            lathe(nodes, [(0, -0.5), (0.42, -0.5), (0.42, 0.5), (0, 0.5)], 6,
                  transform=Matrix.Translation(corner + offset) @ align_z(Y_AXIS) @ Matrix.Rotation(math.pi / 6, 4, "Z"))
        for x in (LEFT_X, RIGHT_X):
            lathe(frame, [(0, 0), (0.95, 0), (0.95, 0.4), (0.7, 0.62), (0, 0.62)], 6, transform=Matrix.Translation((x, y, 0)))
            torus(glow, (x, y, 0.42), (0, 0, 1), 0.9, 0.05, segments=6, minor_segments=4)
    # Beams along the corners, with glowing strips on their inner sides.
    for k, corner in enumerate(CORNERS[1:5], start=1):
        inward = ((CORNERS[k - 1] - corner).normalized() + (CORNERS[k + 1] - corner).normalized()).normalized()
        c = corner - inward * 0.14
        box(frame, (c.x, (BACK_Y + FRONT_Y) / 2, c.z), (0.38, FRONT_Y - BACK_Y + 0.7, 0.38))
        g = corner + inward * 0.24
        box(glow, (g.x, (BACK_Y + FRONT_Y) / 2, g.z), (0.1, FRONT_Y - BACK_Y - 0.4, 0.1))
    box(frame, (CX, (BACK_Y + FRONT_Y) / 2, ROOF + 0.14), (0.4, FRONT_Y - BACK_Y + 0.7, 0.28))


def build_walls():
    walls, grid, glyphs = part("QuantumHoloWalls"), part("QuantumGrid"), part("QuantumGlyphs")
    # The five long faces as one panel per bay, a glowing grid, and blocks of data glyphs.
    for i, (a, b) in enumerate(zip(CORNERS, CORNERS[1:])):
        u = (b - a).normalized()
        out = Vector((-u.z, 0, u.x))
        length = (b - a).length
        for y0, y1 in zip(HOOPS, HOOPS[1:]):
            double_sided_poly(walls, [a + Vector((0, y0, 0)), b + Vector((0, y0, 0)), b + Vector((0, y1, 0)), a + Vector((0, y1, 0))])
        count = max(1, round(length / 2.0))
        for k in range(1, count):
            p = a + u * (length * k / count) + out * 0.05
            line_strip(grid, p + Vector((0, BACK_Y + 0.3, 0)), p + Vector((0, FRONT_Y - 0.3, 0)), u, 0.07)
        for y in [BACK_Y + 2.0 * k for k in range(1, 24)]:
            if min(abs(y - h) for h in HOOPS) > 0.6:
                line_strip(grid, a + out * 0.05 + Vector((0, y, 0)), b + out * 0.05 + Vector((0, y, 0)), Y_AXIS, 0.07)
        if i in (0, 1, 3, 4):
            for y0, y1 in zip(HOOPS, HOOPS[1:]):
                for _ in range(rng.randint(1, 2)):
                    s, y = rng.uniform(1.0, length - 1.6), rng.uniform(y0 + 1.2, y1 - 3.2)
                    p = a + u * s
                    banner = (i == 0 and 18.0 < y + 2.4 and y < 26.0) or (i == 4 and 2.0 < y + 2.4 and y < 10.0)
                    if banner and p.z > 6.5:
                        continue
                    for row in range(rng.randint(2, 4)):
                        along = y
                        for _ in range(rng.randint(3, 6)):
                            w = rng.choice((0.18, 0.3, 0.45))
                            q = p + u * (-0.3 * row) + out * 0.06
                            double_sided_poly(glyphs, [q + Vector((0, along, 0)), q + Vector((0, along + w, 0)),
                                                       q + Vector((0, along + w, 0)) + u * 0.16, q + Vector((0, along, 0)) + u * 0.16])
                            along += w + 0.1
    # End walls: the machine end whole, the batter end round the door.
    double_sided_poly(walls, [Vector((p.x, FRONT_Y, p.z)) for p in CORNERS])
    for x0, x1, z0 in ((LEFT_X, DOOR[0], 0.0), (DOOR[0], DOOR[1], DOOR[2]), (DOOR[1], RIGHT_X, 0.0)):
        top = [p for p in CORNERS[1:5] if x0 + 1e-6 < p.x < x1 - 1e-6]
        outline = [(x0, z0), (x1, z0), (x1, outline_height(x1))] + [(p.x, p.z) for p in reversed(top)] + [(x0, outline_height(x0))]
        double_sided_poly(walls, [Vector((x, BACK_Y, z)) for x, z in outline])
    for y, out in ((FRONT_Y, 1), (BACK_Y, -1)):
        for x in [LEFT_X + 2.0 * k for k in range(1, 15)]:
            bottom = DOOR[2] if y == BACK_Y and DOOR[0] - 0.2 < x < DOOR[1] + 0.2 else 0.0
            line_strip(grid, (x, y + out * 0.05, bottom + 0.05), (x, y + out * 0.05, outline_height(x) - 0.05), (1, 0, 0), 0.07)
        for z in [2.0 * k for k in range(1, 8)]:
            span = [x for x in [LEFT_X + 0.05 * k for k in range(601)] if outline_height(x) > z + 0.05]
            runs = [(span[0], span[-1])]
            if y == BACK_Y and z < DOOR[2]:
                runs = [(span[0], DOOR[0] - 0.05), (DOOR[1] + 0.05, span[-1])]
            for xa, xb in runs:
                line_strip(grid, (xa, y + out * 0.05, z), (xb, y + out * 0.05, z), (0, 0, 1), 0.07)


def build_door():
    door, glow, trim, nodes = part("QuantumDoorFrame"), part("QuantumEdgeGlow"), part("QuantumTrim"), part("QuantumNodes")
    y0, y1 = BACK_Y - 0.62, BACK_Y + 0.45
    xl, xr, top = DOOR[0] - 0.05, DOOR[1] + 0.05, DOOR[2] + 0.05
    xz_box(door, xl - 0.9, xl, 0.0, top, y0, y1)
    xz_box(door, xr, xr + 0.9, 0.0, top, y0, y1)
    xz_box(door, xl - 0.9, xr + 0.9, top, top + 0.5, y0, y1)
    for x, side in ((xl - 0.9, -1), (xr + 0.9, 1)):
        xz_prism(door, [(x, top - 1.4), (x + side * 0.7, top + 0.5), (x, top + 0.5)], y0, BACK_Y - 0.05)
    edge = [Vector((xl - 0.16, y0 - 0.03, 0.1)), Vector((xl - 0.16, y0 - 0.03, top + 0.16)), Vector((xr + 0.16, y0 - 0.03, top + 0.16)),
            Vector((xr + 0.16, y0 - 0.03, 0.1))]
    sweep_profile(glow, edge, [(-0.05, -0.05), (0.05, -0.05), (0.05, 0.05), (-0.05, 0.05)])
    box(trim, (xr + 0.45, y0 - 0.04, 4.2), (0.55, 0.06, 0.8))
    box(nodes, (xr + 0.45, y0 - 0.08, 4.25), (0.32, 0.04, 0.45))


def build_floor():
    grid, arrows = part("QuantumFloorGrid"), part("QuantumLaneArrows")

    def blocked(x, y):
        return ((-5.2 < x < 11.2 and -4.8 < y < 4.8) or (-0.5 < x < 6.5 and -4.8 < y < 28.0)
                or (-1.5 < x < 7.5 and 19.5 < y < 29.5) or (DOOR[0] - 0.5 < x < DOOR[1] + 0.5 and y < BACK_Y + 1.5)
                or math.hypot(x + 8.6, y + 8.4) < 3.75)

    def runs(points):
        run, out = [], []
        for p in points:
            if blocked(p.x, p.y):
                if len(run) > 1:
                    out.append((run[0], run[-1]))
                run = []
            else:
                run.append(p)
        if len(run) > 1:
            out.append((run[0], run[-1]))
        return out

    for x in [LEFT_X + 2.0 * k for k in range(1, 15)]:
        for a, b in runs([Vector((x, BACK_Y + 0.7 + 0.2 * k, 0.035)) for k in range(int((FRONT_Y - BACK_Y - 1.4) / 0.2) + 1)]):
            line_strip(grid, a, b, (1, 0, 0), 0.06)
    for y in [BACK_Y + 2.0 * k for k in range(1, 24)]:
        for a, b in runs([Vector((LEFT_X + 0.7 + 0.2 * k, y, 0.035)) for k in range(int((RIGHT_X - LEFT_X - 1.4) / 0.2) + 1)]):
            line_strip(grid, a, b, (0, 1, 0), 0.06)
    # Glowing pads on some grid crossings.
    for x in [LEFT_X + 2.0 * k for k in range(1, 15)]:
        for y in [BACK_Y + 2.0 * k for k in range(1, 24)]:
            if not blocked(x, y) and rng.random() < 0.22:
                double_sided_poly(grid, [Vector((x + dx, y + dy, 0.04)) for dx, dy in ((-0.16, 0), (0, -0.16), (0.16, 0), (0, 0.16))])
    # A quantum emblem on the floor between the door and the batter: a nucleus, three tilted
    # orbits and two rings, drawn in light.
    emblem, mid = part("QuantumEmblem"), Vector((-8.6, -8.4, 0.045))
    for r, w in ((3.0, 0.1), (3.35, 0.05)):
        ring = [mid + Vector((math.cos(a) * r, math.sin(a) * r, 0)) for a in [2 * math.pi * k / 64 for k in range(65)]]
        double_sided_strip(emblem, [mid + (p - mid) * (1 - w / r) for p in ring], [mid + (p - mid) * (1 + w / r) for p in ring])
    for k in range(3):
        turn = Matrix.Rotation(k * math.pi / 3, 3, "Z")
        orbit = [mid + turn @ Vector((math.cos(a) * 2.5, math.sin(a) * 0.95, 0)) for a in [2 * math.pi * i / 48 for i in range(49)]]
        frames = [(orbit[min(i + 1, 48)] - orbit[max(i - 1, 0)]).normalized() for i in range(49)]
        sides = [Vector((-f.y, f.x, 0)) * 0.055 for f in frames]
        double_sided_strip(emblem, [p - s for p, s in zip(orbit, sides)], [p + s for p, s in zip(orbit, sides)])
        electron = mid + turn @ Vector((2.5, 0, 0))
        double_sided_poly(emblem, [electron + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.002)) for a in [2 * math.pi * i / 10 for i in range(10)]])
    double_sided_poly(emblem, [mid + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.002)) for a in [2 * math.pi * i / 16 for i in range(16)]])
    # Chevrons down the lane pointing at the batter.
    for y in [6.0 + 2.0 * k for k in range(7)]:
        for side in (-1, 1):
            double_sided_poly(arrows, [Vector((PITCH.x, y, 0.04)), Vector((PITCH.x + side * 1.1, y + 0.75, 0.04)),
                                       Vector((PITCH.x + side * 1.1, y + 1.05, 0.04)), Vector((PITCH.x, y + 0.3, 0.04))])
    home_plate(part("QuantumPlate"), 0.08)


# ---------- the teleporter and the screen ----------

def build_portal():
    """The teleporter: a ring, its lights, the vortex core and the event-horizon field all spin
    about the pitch line (each mesh centred on PORTAL). Static emitter pylons stand clear of
    the ring both as built and as squeezed in game."""
    ring, lights, core, field = (part(n) for n in ("QuantumPortalRing", "QuantumPortalLights", "QuantumPortalCore", "QuantumPortalField"))
    base, glow = part("QuantumPortalBase"), part("QuantumEdgeGlow")
    c, R = PORTAL, 2.65
    e1, e2 = Vector((1, 0, 0)), Vector((0, 0, 1))
    band_arc(ring, c, e1, e2, Y_AXIS, R, 0.0, 2 * math.pi, [(-0.36, -0.28), (0.36, -0.28), (0.36, 0.28), (-0.36, 0.28)], 64)
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        band_arc(ring, c, e1, e2, Y_AXIS, R, a - 0.13, a + 0.13, [(-0.42, 0.2), (0.42, 0.2), (0.3, 0.45), (-0.3, 0.45)], 4)
        band_arc(lights, c, e1, e2, Y_AXIS, R, a - 0.08, a + 0.08, [(-0.44, 0.24), (-0.4, 0.24), (-0.4, 0.38), (-0.44, 0.38)], 3)
        band_arc(ring, c, e1, e2, Y_AXIS, R, a + 0.32, a + 0.46, [(-0.4, -0.32), (0.4, -0.32), (0.4, 0.3), (-0.4, 0.3)], 2)
    band_arc(lights, c, e1, e2, Y_AXIS, R - 0.2, 0.0, 2 * math.pi, [(-0.4, -0.06), (-0.37, -0.06), (-0.37, 0.06), (-0.4, 0.06)], 64)
    band_arc(lights, c, e1, e2, Y_AXIS, R - 0.2, 0.0, 2 * math.pi, [(0.37, -0.06), (0.4, -0.06), (0.4, 0.06), (0.37, 0.06)], 64)
    # The vortex: six spiral vanes in the ring's plane.
    for vane in range(6):
        left, right = [], []
        for i in range(28):
            t = i / 27
            a = vane * math.pi / 3 + t * 3.3
            radial = e1 * math.cos(a) + e2 * math.sin(a)
            p = c + radial * (0.08 + t * 2.12) + Y_AXIS * 0.05
            w = 0.04 + 0.2 * t
            left.append(p - radial * w)
            right.append(p + radial * w)
        double_sided_strip(core, left, right)
    lathe(field, [(0, -0.015), (2.3, -0.015), (2.3, 0.015), (0, 0.015)], 64, transform=Matrix.Translation(c + Y_AXIS * 0.16) @ align_z(Y_AXIS))
    # Static: a hex platform and two emitter pylons either side of the ring.
    lathe(base, [(0, 0), (3.9, 0), (3.9, 0.08), (3.6, 0.13), (0, 0.13)], 6, transform=Matrix.Translation((c.x, c.y + 0.7, 0)))
    for side in (-1, 1):
        x0, x1 = sorted((c.x + side * 3.5, c.x + side * 4.2))
        side_prism(base, [(c.y - 0.8, 0.13), (c.y + 1.6, 0.13), (c.y + 1.6, 4.6), (c.y + 0.9, 6.0), (c.y - 0.8, 5.2)], x0, x1)
        inner = c.x + side * 3.47
        box(glow, (inner, c.y + 0.2, 3.0), (0.05, 0.3, 4.2))
        for z in (1.2, 4.8):
            box(base, (c.x + side * 3.85, c.y + 0.4, z), (0.95, 2.6, 0.3))
        box(part("QuantumNodes"), (c.x + side * 3.85, c.y + 0.1, 5.7), (0.5, 0.5, 0.3))


def build_screen():
    frame, panel, sgrid, trim = (part(n) for n in ("QuantumScreenFrame", "QuantumScreenPanel", "QuantumScreenGrid", "QuantumScreenTrim"))
    x0, x1, z0, z1 = PITCH.x - 3.45, PITCH.x + 3.45, 0.45, 6.55
    panel_with_hole(panel, [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], lambda u, v, w: Vector((u, SCREEN_Y + w, v)),
                    (PITCH.x, PITCH.z), WINDOW + 0.06, segments=48)
    for x in (x0 - 0.18, x1 + 0.18):
        box(frame, (x, SCREEN_Y, 3.4), (0.36, 0.5, 6.8))
    box(frame, (PITCH.x, SCREEN_Y, 0.22), (x1 - x0 + 0.72, 0.9, 0.44))
    box(frame, (PITCH.x, SCREEN_Y, 6.7), (x1 - x0 + 0.72, 0.42, 0.24))
    box(part("QuantumEdgeGlow"), (PITCH.x, SCREEN_Y - 0.46, 0.3), (x1 - x0, 0.03, 0.08))
    clear = WINDOW + 0.32
    for side in (-1, 1):
        y = SCREEN_Y + side * 0.035
        for k in range(1, 12):
            x = x0 + (x1 - x0) * k / 12
            dx = abs(x - PITCH.x)
            pieces = [(z0, z1)]
            if dx < clear:
                gap = math.sqrt(clear ** 2 - dx ** 2)
                pieces = [(z0, PITCH.z - gap), (PITCH.z + gap, z1)]
            for za, zb in pieces:
                line_strip(sgrid, (x, y, za), (x, y, zb), (1, 0, 0), 0.04)
        for k in range(1, 11):
            z = z0 + (z1 - z0) * k / 11
            dz = abs(z - PITCH.z)
            pieces = [(x0, x1)]
            if dz < clear:
                gap = math.sqrt(clear ** 2 - dz ** 2)
                pieces = [(x0, PITCH.x - gap), (PITCH.x + gap, x1)]
            for xa, xb in pieces:
                line_strip(sgrid, (xa, y, z), (xb, y, z), (0, 0, 1), 0.04)
        # Window rim, crosshair ticks and corner brackets.
        torus(trim, (PITCH.x, y, PITCH.z), Y_AXIS, WINDOW + 0.12, 0.05, segments=40, minor_segments=5)
        for k in range(4):
            d = Vector((math.cos(k * math.pi / 2), 0, math.sin(k * math.pi / 2)))
            line_strip(trim, Vector((PITCH.x, y, PITCH.z)) + d * (WINDOW + 0.3), Vector((PITCH.x, y, PITCH.z)) + d * (WINDOW + 0.75),
                       d.cross(Y_AXIS), 0.08)
        for cx_, cz_, sx, sz in ((x0, z0, 1, 1), (x1, z0, -1, 1), (x1, z1, -1, -1), (x0, z1, 1, -1)):
            corner = Vector((cx_ + sx * 0.15, y, cz_ + sz * 0.15))
            line_strip(trim, corner, corner + Vector((sx * 0.9, 0, 0)), (0, 0, 1), 0.08)
            line_strip(trim, corner, corner + Vector((0, 0, sz * 0.9)), (1, 0, 0), 0.08)


# ---------- energy rings, accelerator, reactor, cubes ----------

def build_energy_rings():
    """Three huge rings round the cage, each two meshes (body and glow) centred on the cage's
    long axis so they spin about it. Pods and gaps make the turning visible."""
    e1, e2 = Vector((1, 0, 0)), Vector((0, 0, 1))
    for name, y, r in RINGS:
        body, glow = part("QuantumRing" + name), part("QuantumRing" + name + "Glow")
        c = Vector((CX, y, RING_Z))
        gap = math.radians(2.4)
        # Twelve armoured segments with glowing joints and a glowing channel round both faces.
        for k in range(12):
            a0, a1 = 2 * math.pi * k / 12 + gap / 2, 2 * math.pi * (k + 1) / 12 - gap / 2
            band_arc(body, c, e1, e2, Y_AXIS, r, a0, a1, [(-0.7, -0.3), (0.7, -0.3), (0.7, 0.32), (0.5, 0.42), (-0.5, 0.42), (-0.7, 0.32)], 10)
            band_arc(glow, c, e1, e2, Y_AXIS, r, a1 - 0.002, a1 + gap + 0.002, [(-0.5, -0.2), (0.5, -0.2), (0.5, 0.3), (-0.5, 0.3)], 1)
            for side in (-1, 1):
                band_arc(body, c, e1, e2, Y_AXIS, r, a0 + 0.03, a0 + 0.075, [(side * 0.62, -0.34), (side * 0.78, -0.34), (side * 0.78, 0.46), (side * 0.62, 0.46)], 1)
        band_arc(glow, c, e1, e2, Y_AXIS, r, 0.0, 2 * math.pi, [(-0.25, -0.35), (0.25, -0.35), (0.25, -0.28), (-0.25, -0.28)], 120)
        band_arc(glow, c, e1, e2, Y_AXIS, r, 0.0, 2 * math.pi, [(-0.2, 0.41), (0.2, 0.41), (0.2, 0.47), (-0.2, 0.47)], 120)
        # Eight emitter pods, big and small by turns, with glowing lenses and side lights.
        for k in range(8):
            a = k * math.pi / 4
            big = k % 2 == 1
            wide, tall, half = (0.92, 1.1, 0.055) if big else (0.78, 0.75, 0.035)
            band_arc(body, c, e1, e2, Y_AXIS, r, a - half, a + half, [(-wide, -0.32), (wide, -0.32), (wide * 0.8, tall), (-wide * 0.8, tall)], 3)
            band_arc(glow, c, e1, e2, Y_AXIS, r, a - half * 0.6, a + half * 0.6, [(-wide * 0.55, tall - 0.02), (wide * 0.55, tall - 0.02), (wide * 0.55, tall + 0.05), (-wide * 0.55, tall + 0.05)], 3)
            for side in (-1, 1):
                band_arc(glow, c, e1, e2, Y_AXIS, r, a - half * 0.6, a + half * 0.6,
                         [(side * wide * 0.98, 0.0), (side * (wide * 0.98 + 0.06), 0.0), (side * (wide * 0.8 + 0.05), tall * 0.8), (side * wide * 0.8, tall * 0.8)], 3)


def build_accelerator():
    """A particle accelerator floating over the roof: a glass tube with magnets and a glowing
    beam (slow spin), racing bunches (fast spin), and two levitator pylons on the roof below
    the ring's in-game position."""
    tube, magnets, beam, bunches = (part(n) for n in ("QuantumAccelTube", "QuantumAccelMagnets", "QuantumAccelBeam", "QuantumAccelBunches"))
    c, R = ACCEL, ACCEL_R
    up = Vector((0, 0, 1))
    e1, e2 = Vector((1, 0, 0)), Vector((0, 1, 0))
    torus(tube, c, up, R, 0.42, segments=112, minor_segments=12)
    torus(beam, c, up, R, 0.1, segments=112, minor_segments=6)
    # Eight curved bending magnets round the tube, with glowing focusing coils between them.
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        band_arc(magnets, c, e1, e2, up, R, a - 0.17, a + 0.17, [(-0.64, -0.6), (0.64, -0.6), (0.64, 0.6), (-0.64, 0.6)], 8)
        band_arc(magnets, c, e1, e2, up, R, a - 0.12, a + 0.12, [(0.64, -0.32), (0.82, -0.32), (0.82, 0.32), (0.64, 0.32)], 6)
        for da in (-0.24, 0.24):
            band_arc(magnets, c, e1, e2, up, R, a + da - 0.02, a + da + 0.02, [(-0.7, -0.66), (0.7, -0.66), (0.7, 0.66), (-0.7, 0.66)], 1)
        for da in (0.36, 0.42, 0.48):
            band_arc(beam, c, e1, e2, up, R, a + da - 0.008, a + da + 0.008,
                     [(0.52 * math.cos(t), 0.52 * math.sin(t)) for t in [2 * math.pi * i / 12 for i in range(12)]], 1)
    for k in range(6):
        a = 2 * math.pi * k / 6
        path = [c + (e1 * math.cos(a + t) + e2 * math.sin(a + t)) * R for t in [0.34 * i / 10 for i in range(11)]]
        sweep_radii(bunches, path, [0.05, 0.12, 0.18, 0.21, 0.22, 0.22, 0.22, 0.21, 0.18, 0.12, 0.05], segments=8)
    # Levitator pylons on the roof under the ring's in-game position (on the x axis both agree).
    pylons, nodes, levitators = part("QuantumFrame"), part("QuantumNodes"), part("QuantumLevitators")
    for side in (-1, 1):
        p = Vector((c.x + side * R, c.y, ROOF))
        lathe(pylons, [(0, 0.0), (1.0, 0.0), (1.0, 0.3), (0.45, 0.6), (0.3, 1.8), (0.55, 1.95), (0.62, 2.1), (0, 2.1)], 6,
              transform=Matrix.Translation(p))
        lathe(nodes, [(0, 2.1), (0.5, 2.1), (0.42, 2.26), (0, 2.26)], 6, transform=Matrix.Translation(p))
        lathe(levitators, [(0, 2.26), (0.3, 2.26), (0.42, 2.62), (0, 2.62)], 12, transform=Matrix.Translation(p))


def build_reactor():
    """The quantum reactor behind the machine end: a glowing core in a plasma shell and three
    containment rings (each spinning in its own plane about the core), inside a static frame
    whose clamps stop clear of the rings."""
    c = REACTOR
    ball(part("QuantumReactorCore"), c, 2.0, subdivisions=4)
    ball(part("QuantumReactorPlasma"), c, 2.45, subdivisions=4)
    for name, r, normal in (("A", 3.05, (0.35, 0.25, 1.0)), ("B", 3.6, (1.0, 0.45, 0.3)), ("C", 4.2, (-0.4, 1.0, 0.55))):
        bm = part("QuantumReactorRing" + name)
        e1, e2, n = basis(normal)
        band_arc(bm, c, e1, e2, n, r, 0.0, 2 * math.pi, [(-0.1, -0.12), (0.1, -0.12), (0.1, 0.12), (-0.1, 0.12)], 72)
        for k in range(8):
            a = 2 * math.pi * k / 8
            ball(bm, c + (e1 * math.cos(a) + e2 * math.sin(a)) * r, 0.24, subdivisions=2)
    frame, glow, nodes = part("QuantumReactorFrame"), part("QuantumReactorGlow"), part("QuantumNodes")
    base = Vector((c.x, c.y, 0))
    lathe(frame, [(0, 0), (6.6, 0), (6.6, 0.6), (5.9, 0.6), (5.9, 1.2), (0, 1.2)], 6, transform=Matrix.Translation(base))
    torus(glow, base + Vector((0, 0, 0.62)), (0, 0, 1), 6.25, 0.06, segments=6, minor_segments=4)
    lathe(frame, [(0, 1.2), (1.1, 1.2), (0.8, 2.4), (0.55, 2.6), (0, 2.6)], 12, transform=Matrix.Translation(base))
    lathe(frame, [(0, c.z + 4.6), (0.6, c.z + 4.6), (0.9, c.z + 5.4), (0, c.z + 5.6)], 12, transform=Matrix.Translation(base))
    tube(glow, base + Vector((0, 0, 2.5)), Vector((c.x, c.y, c.z - 1.2)), 0.16, 10)
    tube(glow, Vector((c.x, c.y, c.z + 1.2)), base + Vector((0, 0, c.z + 4.7)), 0.16, 10)
    crown = c.z + 6.0
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0))
        foot = base + d * 6.0
        tw = axes(s, d, Vector((0, 0, 1)))
        box(frame, foot + Vector((0, 0, (1.2 + crown) / 2)), (0.7, 0.9, crown - 1.2), tw)
        for z in (3.0, 4.2, 5.4, 12.0, 13.2):
            box(frame, foot + d * 0.55 + Vector((0, 0, z)), (1.1, 0.4, 0.14), tw)
        for z in (7.0, 7.6, 11.2, 11.8):
            box(glow, foot + Vector((0, 0, z)), (0.84, 1.04, 0.14), tw)
        # A clamp arm reaching for the core, ending in a glowing emitter clear of every ring.
        tip = c + d * 4.6
        tube(frame, foot - d * 0.3 + Vector((0, 0, c.z - foot.z + 0.0)), tip + d * 0.35, 0.2, 8)
        lathe(glow, [(0, 0), (0.28, 0.0), (0.2, 0.35), (0, 0.4)], 10, transform=Matrix.Translation(tip + d * 0.35) @ align_z(-d))
        box(glow, foot - d * 0.36 + Vector((0, 0, 8.0)), (0.12, 0.05, 9.0), tw)
    turn = Matrix.Translation(base) @ Matrix.Rotation(math.pi / 4, 4, "Z")
    lathe(frame, [(5.4, crown), (6.6, crown), (6.6, crown + 0.5), (5.4, crown + 0.5), (5.4, crown)], 4, transform=turn)
    lathe(glow, [(5.9, crown + 0.5), (6.1, crown + 0.5), (6.1, crown + 0.56), (5.9, crown + 0.56), (5.9, crown + 0.5)], 4, transform=turn)
    # Spokes from the crown to a hub over the core, topped by a spire.
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        d = Vector((math.cos(a), math.sin(a), 0))
        box(frame, base + d * 3.2 + Vector((0, 0, crown + 0.25)), (5.8, 0.4, 0.4), axes(d, Vector((-d.y, d.x, 0)), Vector((0, 0, 1))))
    lathe(frame, [(0, c.z + 4.6), (0.6, c.z + 4.6), (0.9, crown), (0.9, crown + 0.9), (0, crown + 0.9)], 12, transform=Matrix.Translation(base))
    lathe(nodes, [(0, crown + 0.9), (0.35, crown + 0.9), (0.06, crown + 3.2), (0, crown + 3.2)], 6, transform=Matrix.Translation(base))
    # Glowing conduits from the reactor into the cage, ending behind the teleporter's pylons.
    for side in (-1, 1):
        path = [Vector((c.x + side * 2.2, c.y - 5.0, 0.6)), Vector((c.x + side * 2.6, FRONT_Y + 1.0, 0.45)),
                Vector((c.x + side * 2.6, PORTAL.y + 3.4, 0.4)), Vector((c.x + side * 3.85, PORTAL.y + 2.2, 0.4))]
        sweep(part("QuantumConduits"), Polyline(path).samples(0.5), 0.2, segments=10)


def glitch_cluster(bm, center, size, rng):
    """A cube cut into slices shifted as if glitching, a smaller glitched cube beside it, and a
    trail of pixel bits breaking away."""
    c, s = Vector(center), size
    for cube_center, cube_size, slices in ((c, s, 4), (c + Vector((s * 0.95, -s * 0.3, s * 0.55)), s * 0.45, 3)):
        for k in range(slices):
            shift = Vector((rng.uniform(-0.28, 0.28), rng.uniform(-0.12, 0.12), 0)) * cube_size * (0.25 if k % 2 else 1.0)
            z = cube_center.z - cube_size / 2 + cube_size * (k + 0.5) / slices
            box(bm, Vector((cube_center.x, cube_center.y, z)) + shift, (cube_size, cube_size, cube_size / slices - 0.05))
    for k in range(7):
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.6, 1))).normalized() * s * rng.uniform(0.95, 1.35)
        box(bm, c + d, (s * rng.uniform(0.1, 0.2),) * 3)
    for k in range(4):
        box(bm, c + Vector((-s * (0.75 + 0.22 * k), 0, s * (0.15 - 0.1 * k))), (s * (0.16 - 0.03 * k),) * 3)


def build_cubes():
    for name, center, size in (("A", (-12.0, 3.6, 10.4), 1.5), ("B", (9.2, 16.6, 10.2), 1.4), ("C", (-19.4, 6.0, 7.0), 1.7),
                               ("D", (17.6, 21.6, 6.6), 1.6), ("E", (CX + 3.0, 26.3, 19.8), 1.8)):
        glitch_cluster(part("QuantumCubes" + name), center, size, rng)


# ---------- inside the lab ----------

def chandelier(c):
    """A golden quantum computer hanging from the roof in a glass cryostat."""
    gold, glass, frame, nodes = part("QuantumGold"), part("QuantumGlass"), part("QuantumFrame"), part("QuantumNodes")
    base = Vector((c.x, c.y, 0))
    tiers = [(13.4, 1.45), (12.15, 1.25), (10.95, 1.05), (9.8, 0.85), (8.75, 0.62)]
    lathe(frame, [(0, ROOF - 0.38), (1.9, ROOF - 0.38), (1.9, ROOF - 0.1), (0, ROOF - 0.1)], 24, transform=Matrix.Translation(base))
    cylinder(gold, base + Vector((0, 0, tiers[0][0])), (0, 0, 1), ROOF - 0.38 - tiers[0][0], 0.2, segments=12)
    for z, r in tiers:
        lathe(gold, [(0, z - 0.08), (r, z - 0.08), (r + 0.04, z), (r, z + 0.08), (0, z + 0.08)], 28, transform=Matrix.Translation(base))
    for (za, ra), (zb, rb) in zip(tiers, tiers[1:]):
        for k in range(6):
            a = 2 * math.pi * k / 6
            tube(gold, base + Vector((math.cos(a) * ra * 0.8, math.sin(a) * ra * 0.8, za)),
                 base + Vector((math.cos(a) * rb * 0.8, math.sin(a) * rb * 0.8, zb)), 0.05, 6)
        for k in range(3):
            a0 = 2 * math.pi * k / 3 + 0.5
            helix = [base + Vector((math.cos(a0 + t * 9) * 0.12 + math.cos(a0) * ra * 0.45,
                                    math.sin(a0 + t * 9) * 0.12 + math.sin(a0) * ra * 0.45, za - (za - zb) * t)) for t in [i / 24 for i in range(25)]]
            sweep(gold, helix, 0.035, segments=5)
    lathe(frame, [(0, 7.9), (0.32, 7.9), (0.32, 8.67), (0, 8.67)], 12, transform=Matrix.Translation(base))
    ball(nodes, base + Vector((0, 0, 7.75)), 0.2, subdivisions=2)
    lathe(glass, [(1.95, 6.9), (2.0, 6.9), (2.0, ROOF - 0.4), (1.95, ROOF - 0.4), (1.95, 6.9)], 32, transform=Matrix.Translation(base))
    lathe(frame, [(1.85, 6.6), (2.15, 6.6), (2.15, 6.95), (1.85, 6.95), (1.85, 6.6)], 32, transform=Matrix.Translation(base))
    lathe(frame, [(0, 0), (1.6, 0), (1.6, 0.45), (1.2, 0.7), (0, 0.7)], 8, transform=Matrix.Translation(base))
    torus(part("QuantumEdgeGlow"), base + Vector((0, 0, 0.47)), (0, 0, 1), 1.5, 0.05, segments=8, minor_segments=4)


def build_lab():
    racks, leds, trim = part("QuantumServers"), part("QuantumLeds"), part("QuantumTrim")
    holo, fill = part("QuantumHoloPanels"), part("QuantumHoloFill")
    chandelier(Vector((-9.4, 29.8, 0)))
    chandelier(Vector((7.7, 30.2, 0)))
    # Server racks along both walls, their fronts covered in rows of status lights.
    for x, face, ys in ((LEFT_X + 1.15, 1, (5.0, 7.6, 12.4, 15.0)), (RIGHT_X - 1.15, -1, (12.4, 15.0))):
        for y in ys:
            box(racks, (x, y, 1.95), (1.25, 2.3, 3.9))
            box(trim, (x, y, 3.98), (1.3, 2.35, 0.12))
            front = x + face * 0.64
            for row in range(9):
                z = 0.6 + row * 0.36
                k = 0
                while k < 4:
                    w = rng.choice((0.22, 0.34, 0.5))
                    yy = y - 0.95 + k * 0.5
                    if rng.random() < 0.75:
                        box(leds, (front, yy + w / 2, z), (0.03, w, 0.07))
                    k += 1
    # Floating holo displays above the racks: glowing outlines and readouts over a faint fill.
    for x, y, face in ((LEFT_X + 2.2, 6.3, 1), (LEFT_X + 2.2, 13.7, 1), (RIGHT_X - 2.2, 13.7, -1), (RIGHT_X - 2.6, -10.4, -1)):
        normal = Vector((face, 0, 0.35)).normalized()
        u = Vector((0, 1, 0))
        v = normal.cross(u).normalized() * face
        c = Vector((x, y, 5.6))
        w, h = 2.4, 1.4
        corners = [c - u * w / 2 - v * h / 2, c + u * w / 2 - v * h / 2, c + u * w / 2 + v * h / 2, c - u * w / 2 + v * h / 2]
        double_sided_poly(fill, corners)
        for a, b in zip(corners, corners[1:] + corners[:1]):
            line_strip(holo, a + normal * 0.02, b + normal * 0.02, normal.cross(b - a), 0.06)
        for row in range(4):
            z = -h / 2 + 0.3 + row * 0.27
            length = rng.uniform(0.7, 1.9)
            line_strip(holo, c - u * (w / 2 - 0.25) + v * z + normal * 0.02, c - u * (w / 2 - 0.25 - length) + v * z + normal * 0.02, v, 0.06)
        bars = [c + u * (0.4 + 0.18 * k) - v * (h / 2 - 0.15) + normal * 0.02 for k in range(4)]
        for k, p in enumerate(bars):
            line_strip(holo, p, p + v * (0.3 + 0.18 * ((k * 7) % 4)), u, 0.1)
    # A workstation in the corner beside the door end.
    side_prism(trim, [(-12.6, 0.0), (-8.6, 0.0), (-8.6, 1.15), (-12.6, 1.15)], RIGHT_X - 3.2, RIGHT_X - 2.4)
    box(trim, (RIGHT_X - 2.2, -10.6, 1.2), (1.6, 4.4, 0.1))
    lathe(part("QuantumFrame"), [(0, 0), (0.35, 0), (0.08, 0.1), (0.06, 0.65), (0.4, 0.7), (0.4, 0.8), (0, 0.8)], 10,
          transform=Matrix.Translation((RIGHT_X - 4.0, -10.6, 0)))
    box(part("QuantumFrame"), (RIGHT_X - 4.0, -10.6, 1.25), (0.15, 0.7, 0.9))


# ---------- outside ----------

def build_deck():
    """A low lab deck round the pod with glowing edges, open slots where the energy rings
    pass (covering both where they cross as built and as squeezed in game), and four spires."""
    deck, glow, slots = part("QuantumDeck"), part("QuantumDeckGlow"), part("QuantumRingSlots")
    (x0, x1), (y0, y1), h = DECK_X, DECK_Y, DECK_H
    gaps = sorted((y - 1.1, y + 1.1) for _, y, _ in RINGS)
    door0, door1 = DOOR[0] - 0.7, DOOR[1] + 0.7

    def strip(xa, xb, ya, yb):
        # The deck reaches 0.12 below the plate top: the hub floor lies 0.1 below it.
        cuts = [ya] + [v for g in gaps if ya < g[0] < yb for v in g] + [yb]
        for a, b in zip(cuts[0::2], cuts[1::2]):
            box(deck, ((xa + xb) / 2, (a + b) / 2, (h - 0.12) / 2), (xb - xa, b - a, h + 0.12))
    # The deck stops either side of the door, so the way in stays level with the cage floor.
    strip(x0, door0, y0, BACK_Y - 0.05)
    strip(door1, x1, y0, BACK_Y - 0.05)
    strip(x0, LEFT_X - 0.05, BACK_Y - 0.05, FRONT_Y + 0.05)
    strip(RIGHT_X + 0.05, x1, BACK_Y - 0.05, FRONT_Y + 0.05)
    strip(x0, x1, FRONT_Y + 0.05, y1)
    for xa, xb in ((x0, door0), (door1, x1)):
        box(glow, ((xa + xb) / 2, y0, h), (xb - xa + 0.1, 0.1, 0.06))
    box(glow, ((x0 + x1) / 2, y1, h), (x1 - x0 + 0.1, 0.1, 0.06))
    for x in (door0, door1):
        box(glow, (x, (y0 + BACK_Y) / 2, h), (0.1, BACK_Y - y0, 0.06))
    # Light chevrons on the ground lead in through the door.
    for k in range(4):
        y = y0 + 0.8 + k * 0.9
        for side in (-1, 1):
            mid = (DOOR[0] + DOOR[1]) / 2
            double_sided_poly(part("QuantumLaneArrows"), [Vector((mid, y + 0.5, -0.06)), Vector((mid + side * 1.6, y - 0.3, -0.06)),
                                                          Vector((mid + side * 1.6, y - 0.05, -0.06)), Vector((mid, y + 0.75, -0.06))])
    for x in (x0, x1):
        cuts = [y0] + [v for g in gaps for v in g] + [y1]
        for a, b in zip(cuts[0::2], cuts[1::2]):
            box(glow, (x, (a + b) / 2, h), (0.1, b - a, 0.06))
    for name, y, r in RINGS:
        # Where the ring meets the deck as built, and (mapped back to model space) where it meets
        # the deck in game once the ring has shrunk evenly and the deck has been squeezed.
        built = math.sqrt(r ** 2 - RING_Z ** 2)
        game = math.sqrt((0.75 * r) ** 2 - RING_Z ** 2) / 0.75
        for side in (-1, 1):
            xa, xb = CX + side * built, CX + side * game
            lo, hi = min(xa, xb) - 0.7, max(xa, xb) + 0.7
            lo, hi = max(lo, x0 + 0.15), min(hi, x1 - 0.15)
            box(slots, ((lo + hi) / 2, y, 0.06), (hi - lo, 1.3, 0.12))
            for edge in (-1.05, 1.05):
                box(glow, ((lo + hi) / 2, y + edge, h), (hi - lo + 0.2, 0.08, 0.06))
    frame, nodes = part("QuantumSpires"), part("QuantumNodes")
    for x, y in ((x0 + 0.9, y0 + 0.9), (x1 - 0.9, y0 + 0.9), (x0 + 0.9, y1 - 0.9), (x1 - 0.9, y1 - 0.9)):
        turn = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.pi / 4, 4, "Z")
        lathe(frame, [(0, h), (0.6, h), (0.6, h + 0.5), (0.3, h + 0.8), (0.12, h + 8.2), (0, h + 8.6)], 4, transform=turn)
        for z in (2.5, 4.5, 6.5):
            r = 0.3 - 0.18 * (z - h - 0.8) / 7.4 + 0.03
            lathe(part("QuantumEdgeGlow"), [(r - 0.05, z), (r, z), (r, z + 0.12), (r - 0.05, z + 0.12), (r - 0.05, z)], 4, transform=turn)
        ball(nodes, (x, y, h + 8.75), 0.22, subdivisions=2)


# ---------- finishing ----------

FINISH = [
    ("QuantumFrame", GRAPHITE, "hard"), ("QuantumTrim", LAB_WHITE, "hard"), ("QuantumEdgeGlow", CYAN, "hard"),
    ("QuantumNodes", MAGENTA, "hard"), ("QuantumHoloWalls", (0.3, 0.75, 0.95), "soft"), ("QuantumGrid", CYAN, "soft"),
    ("QuantumGlyphs", (0.85, 0.97, 1.0), "soft"), ("QuantumDoorFrame", GRAPHITE, 0.04),
    ("QuantumFloorGrid", CYAN, "soft"), ("QuantumLaneArrows", MAGENTA, "soft"), ("QuantumEmblem", MAGENTA, "soft"),
    ("QuantumPlate", LAB_WHITE, 0.02),
    ("QuantumScreenFrame", GRAPHITE, 0.04), ("QuantumScreenPanel", (0.3, 0.8, 1.0), "soft"), ("QuantumScreenGrid", CYAN, "soft"),
    ("QuantumScreenTrim", MAGENTA, "soft"),
    ("QuantumPortalRing", GRAPHITE, "hard"), ("QuantumPortalLights", CYAN, "hard"), ("QuantumPortalCore", (1.0, 0.55, 0.95), "soft"),
    ("QuantumPortalField", (0.5, 0.85, 1.0), "smooth"), ("QuantumPortalBase", GRAPHITE, "hard"),
    ("QuantumRingA", GRAPHITE, "hard"), ("QuantumRingAGlow", VIOLET, "hard"), ("QuantumRingB", GRAPHITE, "hard"),
    ("QuantumRingBGlow", MAGENTA, "hard"), ("QuantumRingC", GRAPHITE, "hard"), ("QuantumRingCGlow", VIOLET, "hard"),
    ("QuantumAccelTube", (0.6, 0.85, 1.0), "smooth"), ("QuantumAccelMagnets", LAB_WHITE, "hard"),
    ("QuantumAccelBeam", (1.0, 0.6, 0.95), "smooth"), ("QuantumAccelBunches", (1.0, 1.0, 1.0), "smooth"),
    ("QuantumLevitators", CYAN, "smooth"),
    ("QuantumReactorCore", (0.85, 1.0, 1.0), "smooth"), ("QuantumReactorPlasma", (0.5, 0.8, 1.0), "smooth"),
    ("QuantumReactorRingA", MAGENTA, "smooth"), ("QuantumReactorRingB", CYAN, "smooth"), ("QuantumReactorRingC", VIOLET, "smooth"),
    ("QuantumReactorFrame", GRAPHITE, "hard"), ("QuantumReactorGlow", CYAN, "smooth"), ("QuantumConduits", CYAN, "smooth"),
    ("QuantumCubesA", MAGENTA, "hard"), ("QuantumCubesB", CYAN, "hard"), ("QuantumCubesC", (0.9, 0.95, 1.0), "hard"),
    ("QuantumCubesD", VIOLET, "hard"), ("QuantumCubesE", MAGENTA, "hard"),
    ("QuantumGold", GOLD, "smooth"), ("QuantumGlass", (0.75, 0.9, 1.0), "smooth"), ("QuantumServers", GRAPHITE, 0.03),
    ("QuantumLeds", CYAN, "hard"), ("QuantumHoloPanels", CYAN, "soft"), ("QuantumHoloFill", (0.4, 0.8, 1.0), "soft"),
    ("QuantumDeck", (0.18, 0.19, 0.25), "hard"), ("QuantumDeckGlow", CYAN, "hard"), ("QuantumRingSlots", MAGENTA, "hard"),
    ("QuantumSpires", GRAPHITE, "hard"),
]
PREVIEW_ALPHA = {"QuantumHoloWalls": 0.18, "QuantumScreenPanel": 0.35, "QuantumGlass": 0.2, "QuantumReactorPlasma": 0.3,
                 "QuantumHoloFill": 0.3, "QuantumAccelTube": 0.3, "QuantumPortalField": 0.35}


def build_and_export(export=True):
    coll = begin(COLLECTION)
    PARTS.clear()
    build_pod()
    build_walls()
    build_door()
    build_floor()
    build_portal()
    build_screen()
    build_energy_rings()
    build_accelerator()
    build_reactor()
    build_cubes()
    build_lab()
    build_deck()
    objects = [finish_part(coll, name, rgb, how) for name, rgb, how in FINISH]
    assert not PARTS, "unfinished parts: %s" % list(PARTS)
    for obj in objects:
        if obj.name in PREVIEW_ALPHA:
            see_through(obj, PREVIEW_ALPHA[obj.name])
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
