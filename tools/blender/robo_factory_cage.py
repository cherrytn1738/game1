# Training Ground 2 of World 3, Robo Factory: a robot work cell. A grey steel I-beam portal frame
# with haunches and bracing, hazard-striped column guards and kick plates, yellow safety-fence
# panels of chain-link under a chain-link roof, a crane runway with a yellow bridge crane whose
# hook carries a big cog (it bobs), high-bay lamps, a big orange six-axis robot arm that pitches
# (its gripper holds the ball at PITCH) on a hatched safety zone, a polycarbonate screen in a
# striped steel frame, spinning warning beacons, stack lights, an operator console, cables and
# cable protectors, a parts shelf; and outside: a conveyor along the right wall carrying robot
# parts through a laser scanner into an assembly station, a welding robot at work on a jig
# (sparks), crates, drums and a control cabinet.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py; small
# builders (rrect, extrude, slab, strands, ...) come from the top of solar_rooftop_cage.py. The
# mesh names are what TrainingCageStyles looks up for colors, materials and motion; LOOKS lists
# every mesh with its preview colour and shading ("hard", "smooth" or "soft" double-sided).
SOLAR_ROOFTOP = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\solar_rooftop_cage.py"
_source = open(SOLAR_ROOFTOP, encoding="utf-8").read()
_marker = "# ---------- the cage ----------"
assert _marker in _source, "solar_rooftop_cage.py layout changed"
exec(_source.partition(_marker)[0])

COLLECTION = "RoboFactoryCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RoboFactoryCage.fbx"

STEEL = (0.36, 0.4, 0.46)
YELLOW = (1.0, 0.76, 0.05)
BLACK = (0.06, 0.06, 0.07)
ORANGE = (1.0, 0.42, 0.06)
DARK = (0.2, 0.21, 0.24)
CHROME = (0.78, 0.8, 0.83)
CYAN = (0.3, 0.9, 1.0)
AMBER = (1.0, 0.6, 0.1)
rng = random.Random(61)

EAVE, RIDGE = 12.9, 14.3                    # portal frame: eaves on the columns, ridge over the middle
CX = (LEFT_X + RIGHT_X) / 2
RUNWAY_Z = 10.35                            # crane runway beams on brackets inside the columns
CRANE_Y = 12.5
WALL_POSTS = (-8.5, -1.0, 6.5)              # wind posts in the machine-end wall
BACK_POST = 8.6                             # just right of the camera zone behind the batter
ROBOT_SCALE = 1.3                           # the pitching robot's arm (its gripper and ball stay true size)
BASE = Vector((9.6, PITCH.y + 1.8 + 0.33 * (ROBOT_SCALE - 1), 0.0))   # right of the pitch line
CONVEYOR_X = (15.1, 18.1)                   # outside the right wall
CONVEYOR_Y = (-12.0, 35.5)
BELT_Z = 2.3

LOOKS = {
    "RoboSteel": (STEEL, "hard"), "RoboFence": (YELLOW, "hard"), "RoboMesh": ((0.24, 0.25, 0.28), "soft"),
    "RoboHazardYellow": (YELLOW, "hard"), "RoboHazardBlack": (BLACK, "hard"), "RoboCrane": ((1.0, 0.68, 0.05), "hard"),
    "RoboCraneLoad": (CHROME, "hard"), "RoboArm": (ORANGE, "hard"), "RoboJoints": (DARK, "hard"),
    "RoboChrome": (CHROME, "hard"), "RoboCables": (BLACK, "smooth"), "RoboGlow": (CYAN, "hard"),
    "RoboBall": (WHITE, "smooth"), "RoboScreenPanel": ((0.75, 0.85, 0.9), "hard"), "RoboPlate": (WHITE, "hard"),
    "RoboLampLens": ((1.0, 0.98, 0.9), "hard"), "RoboBeaconLens": (AMBER, "smooth"),
    "RoboBeaconSpinA": (AMBER, "hard"), "RoboBeaconSpinB": (AMBER, "hard"), "RoboBeaconSpinC": (AMBER, "hard"),
    "RoboBeaconSpinD": (AMBER, "hard"),
    "RoboStackRed": ((1.0, 0.12, 0.1), "smooth"), "RoboStackAmber": (AMBER, "smooth"), "RoboStackGreen": ((0.2, 1.0, 0.35), "smooth"),
    "RoboPanels": ((0.72, 0.74, 0.76), "hard"), "RoboParts": ((0.93, 0.93, 0.95), "hard"), "RoboCrates": ((0.76, 0.58, 0.36), "hard"),
    "RoboDrums": ((0.12, 0.35, 0.75), "hard"), "RoboWeldGlow": ((0.8, 0.9, 1.0), "smooth"), "RoboLaser": ((1.0, 0.1, 0.1), "hard"),
}


# ---------- small builders ----------

def oriented_box(bm, center, x_axis, y_axis, size):
    """A box whose local x and y follow the given (perpendicular) axes."""
    x_axis, y_axis = Vector(x_axis).normalized(), Vector(y_axis).normalized()
    rotation = Matrix((x_axis, y_axis, x_axis.cross(y_axis))).transposed().to_4x4()
    box(bm, center, size, rotation)


def i_beam(bm, a, b, depth=0.8, width=0.6, flange=0.12, web=0.1, up=(0, 0, 1)):
    """A steel I-beam from a to b built from three boxes; up is its web (depth) direction."""
    a, b = Vector(a), Vector(b)
    t = (b - a).normalized()
    v = Vector(up) - t * Vector(up).dot(t)
    v.normalize()
    middle, length = (a + b) / 2, (b - a).length
    for side in (-1, 1):
        oriented_box(bm, middle + v * side * (depth - flange) / 2, t, v, (length, flange, width))
    oriented_box(bm, middle, t, v, (length, depth - 2 * flange, web))


def clip_rect(polygon, u0, u1, v0, v1):
    """Clip a convex 2D polygon to a rectangle (Sutherland-Hodgman)."""
    def clip(points, axis, value, keep_greater):
        out = []
        for i, p in enumerate(points):
            q = points[i - 1]
            p_in = p[axis] >= value if keep_greater else p[axis] <= value
            q_in = q[axis] >= value if keep_greater else q[axis] <= value
            if p_in != q_in:
                t = (value - q[axis]) / (p[axis] - q[axis])
                out.append((q[0] + (p[0] - q[0]) * t, q[1] + (p[1] - q[1]) * t))
            if p_in:
                out.append(p)
        return out
    for axis, value, keep in ((0, u0, True), (0, u1, False), (1, v0, True), (1, v1, False)):
        polygon = clip(polygon, axis, value, keep)
        if len(polygon) < 3:
            return []
    return polygon


def hazard_stripes(bm, origin, u_axis, v_axis, u_len, v_len, pitch=0.6, width=0.3):
    """Black 45-degree stripes over a rectangle, standing just proud of it along u x v."""
    origin, u_axis, v_axis = Vector(origin), Vector(u_axis), Vector(v_axis)
    normal = u_axis.cross(v_axis).normalized()
    for k in range(-int(v_len / pitch) - 2, int(u_len / pitch) + 2):
        c = k * pitch
        band = clip_rect([(c, 0.0), (c + width, 0.0), (c + width + v_len, v_len), (c + v_len, v_len)], 0, u_len, 0, v_len)
        if len(band) < 3:
            continue
        area = sum(band[i - 1][0] * band[i][1] - band[i][0] * band[i - 1][1] for i in range(len(band))) / 2
        if abs(area) < 0.003:
            continue
        slab(bm, [origin + u_axis * u + v_axis * v + normal * 0.012 for u, v in band], 0.02, normal)


def striped_box(m, center, size, stripe_faces=("x", "y")):
    """A yellow box (guard or plate) with black stripes on its vertical faces."""
    c, (sx, sy, sz) = Vector(center), size
    box(m["RoboHazardYellow"], c, size)
    bottom = c.z - sz / 2
    if "y" in stripe_faces:
        for side in (-1, 1):
            if side < 0:
                origin, u = Vector((c.x - sx / 2, c.y - sy / 2, bottom)), Vector((1, 0, 0))
            else:
                origin, u = Vector((c.x + sx / 2, c.y + sy / 2, bottom)), Vector((-1, 0, 0))
            hazard_stripes(m["RoboHazardBlack"], origin, u, (0, 0, 1), sx, sz)
    if "x" in stripe_faces:
        for side in (-1, 1):
            if side < 0:
                origin, u = Vector((c.x - sx / 2, c.y + sy / 2, bottom)), Vector((0, -1, 0))
            else:
                origin, u = Vector((c.x + sx / 2, c.y - sy / 2, bottom)), Vector((0, 1, 0))
            hazard_stripes(m["RoboHazardBlack"], origin, u, (0, 0, 1), sy, sz)


def convex_hull(points):
    points = sorted(set(points))
    if len(points) < 3:
        return points
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def capsule_link(bm, a, ra, b, rb, half_width, segments=14):
    """A flat link in the local XZ plane: the hull of circles at a (radius ra) and b (rb),
    extruded half_width to either side along Y."""
    points = []
    for (cx, cz), r in ((a, ra), (b, rb)):
        for k in range(segments * 2):
            t = 2 * math.pi * k / (segments * 2)
            points.append((round(cx + r * math.cos(t), 5), round(cz + r * math.sin(t), 5)))
    hull = convex_hull(points)
    front = [bm.verts.new((x, -half_width, z)) for x, z in hull]
    back = [bm.verts.new((x, half_width, z)) for x, z in hull]
    bm.faces.new(tuple(front))
    bm.faces.new(tuple(reversed(back)))
    for i in range(len(hull)):
        j = (i + 1) % len(hull)
        bm.faces.new((front[i], back[i], back[j], front[j]))


def along(direction):
    return align_z(Vector(direction))


def toothed_ring(bm, center, axis, root, tip, hole, thickness, teeth):
    """A gear: a toothed outline around a round hole, built from quads only."""
    c, axis = Vector(center), Vector(axis).normalized()
    turn = Matrix.Translation(c) @ along(axis)
    count = teeth * 4
    outer = [((tip if k % 4 in (1, 2) else root) * math.cos(2 * math.pi * k / count),
              (tip if k % 4 in (1, 2) else root) * math.sin(2 * math.pi * k / count)) for k in range(count)]
    inner = [(hole * math.cos(2 * math.pi * k / count), hole * math.sin(2 * math.pi * k / count)) for k in range(count)]
    rings = [[bm.verts.new(turn @ Vector((x, y, z))) for x, y in ring] for ring in (outer, inner) for z in (-thickness / 2, thickness / 2)]
    of, ob, inf, inb = rings
    for k in range(count):
        j = (k + 1) % count
        bm.faces.new((of[k], of[j], inf[j], inf[k]))
        bm.faces.new((ob[j], ob[k], inb[k], inb[j]))
        bm.faces.new((of[j], of[k], ob[k], ob[j]))
        bm.faces.new((inf[k], inf[j], inb[j], inb[k]))


def hex_bolt(bm, base, axis=(0, 0, 1), radius=0.09, height=0.07):
    lathe(bm, [(0, 0), (radius, 0), (radius, height), (0, height)], 6, transform=Matrix.Translation(Vector(base)) @ along(axis))


def sag_points(a, b, sag, count=10):
    a, b = Vector(a), Vector(b)
    return [a.lerp(b, i / count) - Vector((0, 0, sag * math.sin(math.pi * i / count))) for i in range(count + 1)]


# ---------- the cell ----------

def build_frame(m):
    """Steel portal frames with haunches, eave/ridge beams, bracing and the crane runway."""
    steel = m["RoboSteel"]
    slope = (RIDGE - EAVE) / (CX - LEFT_X)
    for y in HOOPS:
        for x, inward in ((LEFT_X, 1), (RIGHT_X, -1)):
            i_beam(steel, (x, y, 0.12), (x, y, EAVE + 0.25), up=(1, 0, 0))
            box(steel, (x, y, 0.06), (1.3, 1.1, 0.12))
            for dx in (-0.45, 0.45):
                for dy in (-0.38, 0.38):
                    hex_bolt(m["RoboChrome"], (x + dx, y + dy, 0.12))
            striped_box(m, (x, y, 0.85), (1.0, 0.82, 1.5))
            # Haunch: a triangular web plate and a sloped flange under the rafter.
            inner = x + inward * 0.4
            far = inner + inward * 2.4
            under = EAVE - 0.33 + slope * (far - x) * inward
            slab(steel, [(inner, y, EAVE - 1.7), (inner, y, EAVE - 0.3), (far, y, under)], 0.1, (0, 1, 0))
            extrude(steel, (inner, y, EAVE - 1.7), (far, y, under), rrect(0.1, 0.5, 0.02), up=(0, 1, 0))
            # Crane runway bracket.
            box(steel, (x + inward * 0.75, y, RUNWAY_Z - 0.55), (0.7, 0.5, 0.35))
        for x0, x1 in ((LEFT_X, CX), (RIGHT_X, CX)):
            z0 = EAVE + 0.05
            i_beam(steel, (x0, y, z0), (x1, y, RIDGE + 0.05), depth=0.8, width=0.5)
    for x in (LEFT_X, RIGHT_X):
        i_beam(steel, (x, BACK_Y - 0.3, EAVE + 0.55), (x, FRONT_Y + 0.3, EAVE + 0.55), depth=0.5, width=0.4)
        runway_x = x + (0.75 if x < 0 else -0.75)
        i_beam(steel, (runway_x, BACK_Y + 0.4, RUNWAY_Z), (runway_x, FRONT_Y - 0.4, RUNWAY_Z), depth=0.7, width=0.45)
        box(m["RoboChrome"], (runway_x, (BACK_Y + FRONT_Y) / 2, RUNWAY_Z + 0.42), (0.14, FRONT_Y - BACK_Y - 0.8, 0.14))
        # X-bracing just outside the door-end bay of each wall.
        brace_x = x + (-0.5 if x < 0 else 0.5)
        for za, zb in ((0.8, EAVE - 1.0), (EAVE - 1.0, 0.8)):
            tube(steel, (brace_x, HOOPS[0] + 0.4, za), (brace_x, HOOPS[1] - 0.4, zb), 0.06, segments=6)
        for y in (HOOPS[0] + 0.4, HOOPS[1] - 0.4):
            for z in (0.8, EAVE - 1.0):
                box(steel, (x + (-0.45 if x < 0 else 0.45), y, z), (0.12, 0.3, 0.3))
    i_beam(steel, (CX, BACK_Y - 0.3, RIDGE + 0.5), (CX, FRONT_Y + 0.3, RIDGE + 0.5), depth=0.45, width=0.4)
    for t in (0.5,):
        for x0 in (LEFT_X, RIGHT_X):
            x = x0 + (CX - x0) * t
            z = EAVE + (RIDGE - EAVE) * t + 0.5
            i_beam(steel, (x, BACK_Y - 0.3, z), (x, FRONT_Y + 0.3, z), depth=0.4, width=0.35)
    # Wind posts in the machine-end wall and the post right of the camera zone.
    for x in WALL_POSTS:
        i_beam(steel, (x, FRONT_Y, 0.12), (x, FRONT_Y, EAVE + 0.2), depth=0.5, width=0.4, up=(0, 1, 0))
        striped_box(m, (x, FRONT_Y, 0.75), (0.7, 0.75, 1.3))
    i_beam(steel, (BACK_POST, BACK_Y, 0.12), (BACK_POST, BACK_Y, EAVE + 0.2), depth=0.5, width=0.4, up=(0, 1, 0))
    striped_box(m, (BACK_POST, BACK_Y, 0.75), (0.7, 0.75, 1.3))
    # Door posts (outside the opening) under a header, wrapped in hazard stripes.
    for x in (DOOR[0] - 0.36, DOOR[1] + 0.36):
        i_beam(steel, (x, BACK_Y, 0.12), (x, BACK_Y, DOOR[2] + 0.55), depth=0.5, width=0.45, up=(1, 0, 0))
        striped_box(m, (x, BACK_Y, 1.1), (0.6, 0.62, 2.2))
    i_beam(steel, (DOOR[0] - 0.6, BACK_Y, DOOR[2] + 0.25), (DOOR[1] + 0.6, BACK_Y, DOOR[2] + 0.25), depth=0.5, width=0.45)
    # Gable cladding above the end walls.
    for y in (BACK_Y, FRONT_Y):
        for x0 in (LEFT_X, RIGHT_X):
            slab(steel, [(x0, y, EAVE + 0.45), (CX, y, RIDGE + 0.45), (CX, y, EAVE + 0.45)], 0.06, (0, 1, 0))


def fence_panel(m, a, b, top=7.4, kick=True):
    """A yellow-framed safety-fence panel of chain-link between floor points a and b (on one wall),
    with a hazard-striped kick plate."""
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    u = (b - a).normalized()
    length = (b - a).length
    fence, profile = m["RoboFence"], rrect(0.14, 0.14, 0.03)
    for p in (a, b):
        extrude(fence, p + Vector((0, 0, 0.05)), p + Vector((0, 0, top)), profile, up=(u.x, u.y, 0))
    for z in (0.22, 1.42, top - 0.04):
        extrude(fence, a + Vector((0, 0, z)), b + Vector((0, 0, z)), profile)
    if kick:
        normal = u.cross(Vector((0, 0, 1)))
        middle = (a + b) / 2
        oriented_box(m["RoboHazardYellow"], middle + Vector((0, 0, 0.82)), u, normal, (length - 0.14, 0.06, 1.0))
        for side in (-1, 1):
            origin = (a + u * 0.07 if side > 0 else b - u * 0.07) + normal * side * 0.03 + Vector((0, 0, 0.32))
            hazard_stripes(m["RoboHazardBlack"], origin, u * side, (0, 0, 1), length - 0.14, 1.0)
    strands(m["RoboMesh"], a + u * 0.07 + Vector((0, 0, 1.5)), u, (0, 0, 1), length - 0.14, top - 1.6, (1, 1), 0.62, 0.045)
    strands(m["RoboMesh"], a + u * 0.07 + Vector((0, 0, 1.5)), u, (0, 0, 1), length - 0.14, top - 1.6, (1, -1), 0.62, 0.045)


def chain_link(m, origin, u_axis, v_axis, u_len, v_len, spacing=0.9, width=0.05, holes=()):
    for direction in ((1, 1), (1, -1)):
        strands(m["RoboMesh"], origin, u_axis, v_axis, u_len, v_len, direction, spacing, width, holes)


def build_walls(m):
    """Fence panels in every bay with chain-link above; the door end keeps the door open and has
    only a hanging net (and a kick plate below the camera zone) behind the batter."""
    top = 7.4
    for x in (LEFT_X, RIGHT_X):
        for y0, y1 in zip(HOOPS, HOOPS[1:]):
            middle = (y0 + y1) / 2
            fence_panel(m, (x, y0 + 0.45), (x, middle - 0.05), top)
            fence_panel(m, (x, middle + 0.05), (x, y1 - 0.45), top)
            chain_link(m, (x, y0 + 0.4, top + 0.05), (0, 1, 0), (0, 0, 1), y1 - y0 - 0.8, EAVE - top - 0.2)
    columns = (LEFT_X,) + WALL_POSTS + (RIGHT_X,)
    for x0, x1 in zip(columns, columns[1:]):
        a, b = x0 + (0.45 if x0 == LEFT_X else 0.3), x1 - (0.45 if x1 == RIGHT_X else 0.3)
        middle = (a + b) / 2
        fence_panel(m, (a, FRONT_Y), (middle - 0.05, FRONT_Y), top)
        fence_panel(m, (middle + 0.05, FRONT_Y), (b, FRONT_Y), top)
        chain_link(m, (a, FRONT_Y, top + 0.05), (1, 0, 0), (0, 0, 1), b - a, EAVE - top - 0.2)
    # Door end.
    fence_panel(m, (LEFT_X + 0.45, BACK_Y), (DOOR[0] - 0.75, BACK_Y), top)
    chain_link(m, (LEFT_X + 0.4, BACK_Y, top + 0.05), (1, 0, 0), (0, 0, 1), DOOR[0] - 0.6 - LEFT_X - 0.4, EAVE - top - 0.2)
    chain_link(m, (DOOR[0] - 0.6, BACK_Y, DOOR[2] + 0.55), (1, 0, 0), (0, 0, 1), DOOR[1] - DOOR[0] + 1.2, EAVE - DOOR[2] - 0.75)
    left, right = DOOR[1] + 0.72, BACK_POST - 0.3
    oriented_box(m["RoboHazardYellow"], ((left + right) / 2, BACK_Y, 0.82), (1, 0, 0), (0, 1, 0), (right - left, 0.06, 1.0))
    for side in (-1, 1):
        origin = Vector((left if side > 0 else right, BACK_Y - side * 0.03, 0.32))
        hazard_stripes(m["RoboHazardBlack"], origin, (side, 0, 0), (0, 0, 1), right - left, 1.0)
    extrude(m["RoboFence"], (left, BACK_Y, 1.38), (right, BACK_Y, 1.38), rrect(0.14, 0.14, 0.03))
    chain_link(m, (left, BACK_Y, 1.5), (1, 0, 0), (0, 0, 1), right - left, EAVE - 1.7)
    fence_panel(m, (BACK_POST + 0.3, BACK_Y), (RIGHT_X - 0.45, BACK_Y), top)
    chain_link(m, (BACK_POST + 0.3, BACK_Y, top + 0.05), (1, 0, 0), (0, 0, 1), RIGHT_X - 0.45 - BACK_POST - 0.3, EAVE - top - 0.2)
    # Chain-link roof on both slopes.
    for x0 in (LEFT_X, RIGHT_X):
        rise = Vector((CX - x0, 0, RIDGE - EAVE))
        chain_link(m, (x0, BACK_Y, EAVE + 0.82), (0, 1, 0), rise.normalized(), FRONT_Y - BACK_Y, rise.length, spacing=1.1)


def build_crane(m):
    """A yellow bridge crane on the runways: end trucks, box girder, trolley and hoist; the hook
    block, chains and a big cog hang below as one bobbing mesh."""
    crane, chrome, load = m["RoboCrane"], m["RoboChrome"], m["RoboCraneLoad"]
    rails = (LEFT_X + 0.75, RIGHT_X - 0.75)
    for x in rails:
        box(crane, (x, CRANE_Y, RUNWAY_Z + 0.8), (0.7, 2.8, 0.55))
        for dy in (-0.9, 0.9):
            cylinder_x(m["RoboJoints"], (x, CRANE_Y + dy, RUNWAY_Z + 0.62), 0.3, 0.2, 16)
        striped_box(m, (x, CRANE_Y + 1.48, RUNWAY_Z + 0.8), (0.6, 0.16, 0.45), stripe_faces=("y",))
        striped_box(m, (x, CRANE_Y - 1.48, RUNWAY_Z + 0.8), (0.6, 0.16, 0.45), stripe_faces=("y",))
    box(crane, ((rails[0] + rails[1]) / 2, CRANE_Y, RUNWAY_Z + 1.45), (rails[1] - rails[0] + 0.6, 0.75, 0.85))
    for k in range(9):
        x = rails[0] + 1.5 + (rails[1] - rails[0] - 3.0) * k / 8
        box(crane, (x, CRANE_Y, RUNWAY_Z + 1.45), (0.1, 0.82, 0.92))
    hook_x = -7.5
    box(crane, (hook_x, CRANE_Y, RUNWAY_Z + 2.15), (1.5, 1.7, 0.55))
    cylinder_x(m["RoboJoints"], (hook_x, CRANE_Y + 0.62, RUNWAY_Z + 2.15), 1.2, 0.33, 16)
    box(m["RoboJoints"], (hook_x + 0.95, CRANE_Y, RUNWAY_Z + 2.15), (0.45, 0.8, 0.5))
    # Hoist cables from the trolley past both sides of the girder.
    hook_top = 8.2
    for dy in (-0.5, 0.5):
        tube(m["RoboCables"], (hook_x, CRANE_Y + dy, RUNWAY_Z + 1.95), (hook_x, CRANE_Y + dy, hook_top + 0.5), 0.04, segments=5)
    # The bobbing load: cable ends, hook block, hook, chain sling and a cog.
    for dy in (-0.5, 0.5):
        tube(load, (hook_x, CRANE_Y + dy, hook_top + 1.1), (hook_x, CRANE_Y + dy, hook_top + 0.2), 0.045, segments=5)
    box(load, (hook_x, CRANE_Y, hook_top - 0.15), (0.5, 1.3, 0.75))
    cylinder_x(load, (hook_x, CRANE_Y, hook_top - 0.15), 0.62, 0.42, 20)
    hook = [Vector((hook_x, CRANE_Y, hook_top - 0.5)), Vector((hook_x, CRANE_Y, hook_top - 0.95))]
    for i in range(1, 10):
        a = math.pi * 1.25 * i / 9
        hook.append(Vector((hook_x, CRANE_Y + 0.32 * math.sin(a), hook_top - 1.27 + 0.32 * math.cos(a))))
    sweep_radii(load, hook, [0.1] * 2 + [0.1 - 0.005 * i for i in range(1, 10)], segments=8)
    cog_center = Vector((hook_x, CRANE_Y, hook_top - 3.3))
    for side in (-1, 1):
        a, b = Vector((hook_x, CRANE_Y, hook_top - 1.55)), cog_center + Vector((side * 0.95, 0, 0.95))
        t = (b - a).normalized()
        n1 = t.cross(Vector((0, 1, 0))).normalized()
        n2 = t.cross(n1)
        count = int((b - a).length / 0.2)
        for i in range(count):
            torus(load, a.lerp(b, (i + 0.5) / count), n1 if i % 2 else n2, 0.1, 0.03, segments=10, minor_segments=4)
    toothed_ring(load, cog_center, (0, 1, 0), 1.18, 1.45, 0.42, 0.36, 14)
    cylinder(load, cog_center + Vector((0, -0.26, 0)), (0, 1, 0), 0.52, 0.46, segments=24)
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        hex_bolt(load, cog_center + Vector((math.cos(a) * 0.82, -0.18, math.sin(a) * 0.82)), axis=(0, -1, 0), radius=0.11, height=0.06)
    # Festoon cable loops hanging along the left runway.
    runway = rails[0] - 0.45
    for k in range(5):
        y0 = -4.0 + k * 3.0
        sweep(m["RoboCables"], sag_points((runway, y0, RUNWAY_Z - 0.4), (runway, y0 + 3.0, RUNWAY_Z - 0.4), 0.9, 10), 0.06, segments=6)
        box(m["RoboChrome"], (runway, y0, RUNWAY_Z - 0.3), (0.16, 0.3, 0.25))


def build_lamps(m):
    """High-bay lamps hanging from the rafters (clear of the crane and the camera zone)."""
    for y in (2.0, 18.0, 30.0):
        for x in (LEFT_X + (CX - LEFT_X) * 0.5, RIGHT_X + (CX - RIGHT_X) * 0.5):
            tube(m["RoboSteel"], (x, y, 13.95), (x, y, 11.6), 0.04, segments=6)
            lathe(m["RoboJoints"], [(0, 11.65), (0.18, 11.62), (0.3, 11.45), (0.85, 11.0), (0.9, 10.92), (0, 11.0)], 20,
                  transform=Matrix.Translation((x, y, 0)))
            lathe(m["RoboLampLens"], [(0, 10.98), (0.84, 10.95), (0.82, 10.9), (0, 10.9)], 20, transform=Matrix.Translation((x, y, 0)))


# ---------- robots ----------

def robot_arm(m, base, heading, j2, j3, j5, tool, scale=1.0, gripper=True):
    """An industrial six-axis robot posed in its own vertical plane. Joint centres j2 (shoulder),
    j3 (elbow) and j5 (wrist) are (reach, height) in that plane, in units of scale; tool is the
    world direction the end effector points. The arm is built locally (local +X reaches along
    heading, +Z is up) and scaled; the tool is built at true size in world space, so a gripped
    ball keeps its size. Returns the tool tip."""
    names = ("RoboArm", "RoboJoints", "RoboChrome", "RoboCables", "RoboGlow")
    before = {n: len(m[n].verts) for n in names}
    arm, joints, chrome, cables, glow = (m[n] for n in names)
    j2, j3, j5 = Vector((j2[0], 0, j2[1])), Vector((j3[0], 0, j3[1])), Vector((j5[0], 0, j5[1]))
    matrix = Matrix.Translation(Vector(base)) @ Matrix.Rotation(heading, 4, "Z") @ Matrix.Scale(scale, 4)
    world_tool = Vector(tool).normalized()
    tool = (matrix.to_3x3().inverted() @ world_tool).normalized()
    box(joints, (0, 0, 0.25), (2.8, 2.8, 0.5))
    for dx in (-1.15, 1.15):
        for dy in (-1.15, 1.15):
            hex_bolt(chrome, (dx, dy, 0.5), radius=0.11, height=0.08)
    lathe(joints, [(0, 0.5), (1.25, 0.5), (1.25, 0.65), (1.12, 0.75), (1.12, 1.3), (0, 1.3)], 32)
    lathe(arm, [(0, 1.28), (1.15, 1.28), (1.15, 1.7), (1.0, 1.8), (0, 1.8)], 32)
    capsule_link(arm, (0.0, 1.55), 0.95, (j2.x, j2.z), 0.86, 0.72)
    # Shoulder, upper arm, elbow.
    cylinder(joints, j2 + Vector((0, -0.95, 0)), (0, 1, 0), 1.9, 0.8, segments=28)
    cylinder(joints, j2 + Vector((0, 0.95, 0)), (0, 1, 0), 0.75, 0.4, segments=20)
    cylinder(arm, j2 + Vector((0, 1.68, 0)), (0, 1, 0), 0.12, 0.43, segments=20)
    cylinder(arm, j2 + Vector((0, -1.05, 0)), (0, 1, 0), 0.12, 0.62, segments=24)
    capsule_link(arm, (j2.x, j2.z), 0.72, (j3.x, j3.z), 0.56, 0.5)
    cylinder(joints, j3 + Vector((0, -0.62, 0)), (0, 1, 0), 1.24, 0.6, segments=24)
    cylinder(joints, j3 + Vector((0, 0.62, 0)), (0, 1, 0), 0.6, 0.32, segments=16)
    cylinder(arm, j3 + Vector((0, 1.2, 0)), (0, 1, 0), 0.1, 0.34, segments=16)
    # Counterbalance beside the upper arm.
    lower, upper = Vector((-0.75, 0.82, 2.05)), j2.lerp(j3, 0.42) + Vector((0, 0.82, 0))
    middle = lower.lerp(upper, 0.6)
    cylinder(joints, lower, middle - lower, (middle - lower).length, 0.2, segments=16)
    cylinder(chrome, middle, upper - middle, (upper - middle).length, 0.08, segments=10)
    for p in (lower, upper):
        cylinder(joints, p + Vector((0, -0.25, 0)), (0, 1, 0), 0.5, 0.16, segments=12)
    # Forearm: a rear motor housing behind the elbow and a tapering tube to the wrist.
    d = (j5 - j3).normalized()
    length = (j5 - j3).length
    turn = Matrix.Translation(j3) @ along(d)
    lathe(joints, [(0, -1.15), (0.5, -1.15), (0.56, -0.95), (0.56, -0.35), (0, -0.35)], 24, transform=turn)
    lathe(arm, [(0, -0.4), (0.5, -0.4), (0.47, 0.6), (0.36, length - 0.75), (0.32, length - 0.5), (0, length - 0.5)], 24, transform=turn)
    # Wrist: a fork, the J5 housing and the flange with its LED ring.
    for side in (-1, 1):
        start = len(arm.verts)
        capsule_link(arm, (j5.x - d.x * 0.6, j5.z - d.z * 0.6), 0.3, (j5.x, j5.z), 0.34, 0.07)
        transform_new(arm, start, Matrix.Translation((0, side * 0.41, 0)))
    cylinder(joints, j5 + Vector((0, -0.36, 0)), (0, 1, 0), 0.72, 0.33, segments=20)
    # Dress pack: a hose along the arm's far side, held by clamps.
    hose = [Vector((-0.95, -0.95, 1.0)), Vector((-0.4, -0.95, 2.3)), j2 + Vector((-0.45, -1.0, 1.0)),
            j2.lerp(j3, 0.5) + Vector((-0.55, -0.7, 0.0)), j3 + Vector((-0.5, -0.75, 0.2)), j3 + Vector((0.1, -0.72, 0.85)),
            j3 + d * (length * 0.45) + Vector((0, -0.55, 0.5)), j5 - d * 0.7 + Vector((0, -0.48, 0.42)), j5 + Vector((0, -0.45, 0.2))]
    smooth_hose = Polyline(hose).samples(0.3)
    sweep(cables, smooth_hose, 0.11, segments=8)
    for p in (hose[3], hose[6]):
        box(chrome, p, (0.34, 0.3, 0.34))
    for n in names:
        transform_new(m[n], before[n], matrix)
    # The tool, at true size in world space from the wrist.
    j5, tool = matrix @ j5, world_tool
    reach = 0.33 * scale
    cylinder(joints, j5, tool, reach + 0.12, 0.29, segments=20)
    cylinder(chrome, j5 + tool * (reach + 0.05), tool, 0.2, 0.34, segments=24)
    torus(glow, j5 + tool * (reach + 0.14), tool, 0.35, 0.045, segments=28, minor_segments=5)
    j5 = j5 + tool * (reach - 0.33)
    if gripper:
        side = Vector((1, 0, 0)) if abs(tool.x) < 0.9 else Vector((0, 1, 0))
        oriented_box(chrome, j5 + tool * 0.86, tool, side, (0.56, 1.1, 0.6))
        oriented_box(joints, j5 + tool * 0.86, tool, side, (0.3, 1.16, 0.64))
        for s in (-1, 1):
            oriented_box(chrome, j5 + tool * 1.4 + side * s * 0.48, tool, side, (0.74, 0.16, 0.44))
            oriented_box(cables, j5 + tool * 1.52 + side * s * 0.39, tool, side, (0.5, 0.05, 0.36))
        return j5 + tool * 1.8
    cylinder(cables, j5 + tool * 0.55, tool, 0.55, 0.17, segments=14)
    side = Vector((0, 0, 1)).cross(tool).normalized() if abs(tool.z) < 0.9 else Matrix.Rotation(heading, 3, "Z") @ Vector((1, 0, 0))
    bend = [j5 + tool * 1.05, j5 + tool * 1.35 + side * 0.12, j5 + tool * 1.6 + side * 0.3]
    sweep(chrome, bend, 0.1, segments=10, radius_end=0.06)
    tip = bend[-1] + (bend[-1] - bend[-2]).normalized() * 0.08
    ball(m["RoboWeldGlow"], tip, 0.09, subdivisions=2)
    return tip


def build_robot_and_screen(m):
    """The pitching robot on its hatched safety zone, its beacon, and the polycarbonate screen."""
    # The arm reaches toward -X in its own plane; the gripper points down the pitch line (-Y).
    s = ROBOT_SCALE
    tip = robot_arm(m, BASE, math.pi, (0.55, 2.6), (1.75, 6.5), ((BASE.x - PITCH.x) / s, PITCH.z / s), (0, -1, 0), scale=s)
    ball(m["RoboBall"], tip, 0.37, subdivisions=3)
    hatch = (BASE.x - 2.6, BASE.x + 2.6, BASE.y - 2.6, BASE.y + 2.6)
    x0, x1, y0, y1 = hatch
    for a, b in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
        extrude(m["RoboHazardYellow"], (a[0], a[1], 0.015), (b[0], b[1], 0.015), [(-0.12, -0.012), (0.12, -0.012), (0.12, 0.012), (-0.12, 0.012)])
    for k in range(-12, 12):
        c = k * 0.7
        band = clip_rect([(c, 0.0), (c + 0.32, 0.0), (c + 0.32 + (y1 - y0), y1 - y0), (c + (y1 - y0), y1 - y0)], 0.15, x1 - x0 - 0.15, 0.15, y1 - y0 - 0.15)
        if len(band) >= 3:
            slab(m["RoboHazardYellow"], [(x0 + u, y0 + v, 0.012) for u, v in band], 0.02, (0, 0, 1))
    home_plate(m["RoboPlate"], 0.08)
    # Yellow walkway lines round the cell floor (open at the door) and a hatched keep-clear
    # strip inside the door.
    line = [(-0.08, -0.01), (0.08, -0.01), (0.08, 0.01), (-0.08, 0.01)]
    lx0, lx1, ly0, ly1 = LEFT_X + 1.4, RIGHT_X - 1.4, BACK_Y + 1.4, FRONT_Y - 1.4
    for a, b in (((lx0, ly0), (lx0, ly1)), ((lx1, ly0), (lx1, ly1)), ((lx0, ly1), (lx1, ly1)),
                 ((lx0, ly0), (DOOR[0] - 0.3, ly0)), ((DOOR[1] + 0.3, ly0), (lx1, ly0))):
        extrude(m["RoboHazardYellow"], (a[0], a[1], 0.012), (b[0], b[1], 0.012), line)
    for k in range(9):
        c = DOOR[0] + 0.2 + k * 0.7
        band = clip_rect([(c, 0.0), (c + 0.3, 0.0), (c + 0.3 + 1.2, 1.2), (c + 1.2, 1.2)], DOOR[0] + 0.2, DOOR[1] - 0.2, 0.0, 1.2)
        if len(band) >= 3:
            slab(m["RoboHazardYellow"], [(u, BACK_Y + 0.5 + v, 0.012) for u, v in band], 0.02, (0, 0, 1))

    # The screen: a steel frame with a hazard-striped kick plate and a clear polycarbonate panel.
    steel = m["RoboSteel"]
    x0, x1, top = PITCH.x - 3.4, PITCH.x + 3.4, 6.6
    for x in (x0 - 0.25, x1 + 0.25):
        i_beam(steel, (x, SCREEN_Y, 0.0), (x, SCREEN_Y, top + 0.3), depth=0.5, width=0.4, up=(1, 0, 0))
        box(steel, (x, SCREEN_Y, 0.08), (0.7, 2.8, 0.16))
        for dy in (-1.1, 1.1):
            hex_bolt(m["RoboChrome"], (x, SCREEN_Y + dy, 0.16))
    i_beam(steel, (x0 - 0.5, SCREEN_Y, top + 0.15), (x1 + 0.5, SCREEN_Y, top + 0.15), depth=0.4, width=0.4)
    striped_box(m, (PITCH.x, SCREEN_Y, 0.85), (x1 - x0, 0.16, 1.3), stripe_faces=("y",))
    slab_with_window(m["RoboScreenPanel"], x0, x1, 1.5, top - 0.05, (PITCH.x, PITCH.z), WINDOW + 0.06, SCREEN_Y, 0.08, segments=48)
    for z in (1.55, top - 0.1):
        extrude(steel, (x0, SCREEN_Y, z), (x1, SCREEN_Y, z), rrect(0.22, 0.2, 0.04))
    # A thick steel ring and a striped ring round the window.
    for y in (SCREEN_Y - 0.08, SCREEN_Y + 0.08):
        torus(steel, (PITCH.x, y, PITCH.z), (0, 1, 0), WINDOW + 0.16, 0.1, segments=40, minor_segments=6)
    segments = 16
    for k in range(segments * 2):
        a0, a1 = math.pi * k / segments, math.pi * (k + 1) / segments
        r0, r1 = WINDOW + 0.3, WINDOW + 0.62
        points = [(PITCH.x + r * math.cos(a), SCREEN_Y - 0.1, PITCH.z + r * math.sin(a)) for r, a in ((r0, a0), (r0, a1), (r1, a1), (r1, a0))]
        slab(m["RoboHazardYellow" if (k // 2) % 2 else "RoboHazardBlack"], points, 0.04, (0, -1, 0))
    for x in (x0 + 0.35, x1 - 0.35):
        for z in (1.85, top - 0.4):
            hex_bolt(m["RoboChrome"], (x, SCREEN_Y - 0.06, z), axis=(0, -1, 0))


# ---------- beacons, lights and controls ----------

def beacon(m, base, spin_name):
    """A warning beacon: a black base, an amber lens and a spinning pair of beams inside."""
    b = Vector(base)
    lathe(m["RoboJoints"], [(0, 0), (0.24, 0), (0.24, 0.16), (0.2, 0.2), (0, 0.2)], 16, transform=Matrix.Translation(b))
    lathe(m["RoboBeaconLens"], [(0, 0.18), (0.2, 0.18), (0.2, 0.45), (0.16, 0.56), (0, 0.6)], 16, transform=Matrix.Translation(b))
    spin = m[spin_name]
    c = b + Vector((0, 0, 0.38))
    box(spin, c, (0.06, 0.26, 0.24))
    for side in (-1, 1):
        lathe(spin, [(0, 0), (0.04, 0), (0.17, 0.75), (0, 0.75)], 10, transform=Matrix.Translation(c + Vector((side * 0.05, 0, 0))) @ along((side, 0, 0)))


def stack_light(m, base, levels=("RoboStackRed", "RoboStackAmber", "RoboStackGreen")):
    b = Vector(base)
    cylinder(m["RoboChrome"], b, (0, 0, 1), 0.3, 0.05, segments=8)
    for k, name in enumerate(levels):
        cylinder(m[name], b + Vector((0, 0, 0.3 + 0.32 * k)), (0, 0, 1), 0.3, 0.14, segments=16)
    cylinder(m["RoboJoints"], b + Vector((0, 0, 0.3 + 0.32 * len(levels))), (0, 0, 1), 0.06, 0.15, segments=16)


def e_stop(m, base, axis):
    b, axis = Vector(base), Vector(axis).normalized()
    cylinder(m["RoboHazardYellow"], b, axis, 0.1, 0.2, segments=16)
    cylinder(m["RoboStackRed"], b + axis * 0.1, axis, 0.08, 0.1, segments=12)
    lathe(m["RoboStackRed"], [(0, 0), (0.16, 0), (0.17, 0.05), (0.12, 0.1), (0, 0.11)], 16,
          transform=Matrix.Translation(b + axis * 0.17) @ along(axis))


def build_controls(m):
    """The operator console inside, the control cabinet outside, cables and cable protectors."""
    panels, glow = m["RoboPanels"], m["RoboGlow"]
    hmi = Vector((11.8, -9.0, 0.0))
    box(panels, hmi + Vector((0, 0, 0.1)), (1.0, 1.0, 0.2))
    extrude(panels, hmi + Vector((0, 0, 0.2)), hmi + Vector((0, 0, 3.6)), rrect(0.3, 0.3, 0.06), up=(1, 0, 0))
    tilt = Matrix.Rotation(math.radians(-25), 4, "Y")
    box(panels, hmi + Vector((-0.05, 0, 3.95)), (0.35, 1.5, 1.05), tilt)
    box(glow, hmi + Vector((-0.24, 0, 3.94)), (0.03, 1.25, 0.82), tilt)
    e_stop(m, hmi + Vector((0.0, 0.0, 4.48)), (0, 0, 1))
    stack_light(m, hmi + Vector((0.35, 0.55, 4.45)))
    # Cable protector along the right wall from the console to the robot base.
    path = [hmi + Vector((0, 0.5, 0)), Vector((13.05, -7.0, 0)), Vector((13.05, 23.5, 0)), Vector((BASE.x + 2.3, BASE.y - 0.4, 0))]
    for a, b in zip(path, path[1:]):
        extrude(m["RoboHazardYellow"], a + Vector((0, 0, 0.0)), b, [(-0.32, 0.0), (0.32, 0.0), (0.2, 0.16), (-0.2, 0.16)])
        t = (b - a).normalized()
        n = t.cross(Vector((0, 0, 1)))
        for k in range(int((b - a).length / 0.9)):
            p = a + t * (0.45 + 0.9 * k)
            slab(m["RoboHazardBlack"], [p - n * 0.21 + Vector((0, 0, 0.165)), p + t * 0.35 - n * 0.21 + Vector((0, 0, 0.165)),
                                        p + t * 0.35 + n * 0.21 + Vector((0, 0, 0.165)), p + n * 0.21 + Vector((0, 0, 0.165))], 0.02, (0, 0, 1))
    sweep(m["RoboCables"], [Vector((BASE.x + 2.4, BASE.y - 0.4, 0.12)), Vector((BASE.x + 2.0, BASE.y - 0.3, 0.6)),
                            Vector((BASE.x + 1.55, BASE.y - 0.2, 1.05))], 0.13, segments=8)
    # Parts shelf inside the left wall: two levels of robot heads and boxes.
    shelf = m["RoboSteel"]
    sx0, sx1, sy0, sy1 = LEFT_X + 0.7, LEFT_X + 2.1, 21.0, 28.0
    for x in (sx0, sx1):
        for y in (sy0, sy1):
            extrude(shelf, (x, y, 0.0), (x, y, 4.6), rrect(0.12, 0.12, 0.02), up=(1, 0, 0))
    for z in (0.4, 2.2, 4.0):
        box(m["RoboFence"], ((sx0 + sx1) / 2, (sy0 + sy1) / 2, z), (sx1 - sx0 + 0.12, sy1 - sy0 + 0.12, 0.08))
    for k, y in enumerate((21.9, 23.6, 25.3, 27.0)):
        robot_head(m, ((sx0 + sx1) / 2, y, 2.25), facing=(1, 0, 0), size=0.95 if k % 2 else 0.8)
        if k % 2 == 0:
            crate(m, ((sx0 + sx1) / 2, y + 0.85, 0.8), (1.0, 0.7, 0.7))
    for y in (22.4, 25.8):
        gear(m, ((sx0 + sx1) / 2, y, 4.13), 0.55, axis=(0, 0, 1))
    # The control cabinet outside the left wall near the door end.
    cab = Vector((-20.2, -9.5, 0.0))
    box(panels, cab + Vector((0, 0, 2.15)), (1.1, 2.6, 4.3))
    box(m["RoboJoints"], cab + Vector((0, 0, 0.1)), (1.2, 2.7, 0.2))
    box(m["RoboJoints"], cab + Vector((0.56, 0, 2.15)), (0.03, 0.05, 4.1))
    for dy in (-0.65, 0.65):
        box(glow, cab + Vector((0.57, dy, 3.2)), (0.03, 0.9, 0.6))
        for k in range(3):
            cylinder(m["RoboStackRed" if k == 0 else ("RoboStackGreen" if k == 1 else "RoboStackAmber")],
                     cab + Vector((0.56, dy - 0.3 + 0.3 * k, 2.4)), (1, 0, 0), 0.06, 0.08, segments=10)
    e_stop(m, cab + Vector((0.55, 0.0, 1.7)), (1, 0, 0))
    for k in range(5):
        box(m["RoboJoints"], cab + Vector((0.56, -0.9 + 0.45 * k, 0.75)), (0.04, 0.3, 0.06))
    stack_light(m, cab + Vector((0.2, 0.9, 4.3)))
    beacon(m, cab + Vector((0.2, -0.8, 4.3)), "RoboBeaconSpinD")
    tray = [cab + Vector((0, 1.3, 3.9)), Vector((-17.0, -6.5, 3.9))]
    extrude(m["RoboSteel"], tray[0], tray[1], [(-0.3, 0), (0.3, 0), (0.3, 0.2), (0.26, 0.2), (0.26, 0.04), (-0.26, 0.04), (-0.26, 0.2), (-0.3, 0.2)])
    for k in range(3):
        sweep(m["RoboCables"], [tray[0] + Vector((0, 0, 0.1 + 0.02 * k)) + Vector((0.1 * (k - 1), 0, 0)), tray[1] + Vector((0.1 * (k - 1), 0, 0.1))], 0.05, segments=6)


# ---------- parts and props ----------

def robot_head(m, center, facing=(0, -1, 0), size=1.0):
    """A boxy robot head: two glowing eyes, a mouth grille and an antenna."""
    c, f = Vector(center), Vector(facing).normalized()
    side = f.cross(Vector((0, 0, 1))).normalized()
    s = size
    oriented_box(m["RoboParts"], c + Vector((0, 0, 0.4 * s)), f, side, (0.75 * s, 0.85 * s, 0.75 * s))
    for k in (-1, 1):
        cylinder(m["RoboGlow"], c + Vector((0, 0, 0.5 * s)) + side * k * 0.2 * s + f * 0.36 * s, f, 0.05 * s, 0.11 * s, segments=12)
        cylinder(m["RoboJoints"], c + Vector((0, 0, 0.4 * s)) + side * k * 0.44 * s, side * k, 0.08 * s, 0.14 * s, segments=12)
    oriented_box(m["RoboJoints"], c + Vector((0, 0, 0.2 * s)) + f * 0.37 * s, f, side, (0.04 * s, 0.4 * s, 0.1 * s))
    cylinder(m["RoboChrome"], c + Vector((0, 0, 0.77 * s)), (0, 0, 1), 0.3 * s, 0.03 * s, segments=6)
    ball(m["RoboStackRed"], c + Vector((0, 0, 1.1 * s)), 0.07 * s, subdivisions=1)


def robot_torso(m, center, facing=(0, -1, 0), size=1.0):
    c, f = Vector(center), Vector(facing).normalized()
    side = f.cross(Vector((0, 0, 1))).normalized()
    s = size
    oriented_box(m["RoboParts"], c + Vector((0, 0, 0.55 * s)), f, side, (0.7 * s, 1.15 * s, 1.1 * s))
    cylinder(m["RoboGlow"], c + Vector((0, 0, 0.7 * s)) + f * 0.34 * s, f, 0.04 * s, 0.17 * s, segments=16)
    for k in (-1, 1):
        ball(m["RoboJoints"], c + Vector((0, 0, 0.95 * s)) + side * k * 0.66 * s, 0.2 * s, subdivisions=2)
    cylinder(m["RoboJoints"], c + Vector((0, 0, 1.1 * s)), (0, 0, 1), 0.16 * s, 0.18 * s, segments=12)


def gear(m, center, radius, axis=(0, 1, 0), teeth=10, name="RoboChrome"):
    toothed_ring(m[name], center, axis, radius * 0.8, radius, radius * 0.25, 0.16, teeth)
    cylinder(m["RoboJoints"], Vector(center) - Vector(axis).normalized() * 0.1, axis, 0.2, radius * 0.3, segments=12)


def crate(m, center, size):
    c, (sx, sy, sz) = Vector(center), size
    box(m["RoboCrates"], c, size)
    for dz in (-sz / 2 + 0.06, sz / 2 - 0.06):
        box(m["RoboJoints"], c + Vector((0, 0, dz)), (sx + 0.02, sy + 0.02, 0.06))


def drum(m, base, radius=0.55, height=1.6):
    lathe(m["RoboDrums"], [(0, 0), (radius, 0), (radius, height), (0, height)], 20, transform=Matrix.Translation(Vector(base)))
    for z in (height * 0.33, height * 0.66):
        torus(m["RoboDrums"], Vector(base) + Vector((0, 0, z)), (0, 0, 1), radius + 0.02, 0.035, segments=20, minor_segments=4)
    striped = Vector(base) + Vector((0, 0, height * 0.5))
    cylinder(m["RoboHazardYellow"], striped - Vector((0, 0, 0.12)), (0, 0, 1), 0.24, radius + 0.01, segments=20)


def build_conveyor(m):
    """A belt conveyor along the outside of the right wall: legs, rollers, guard rails, parts
    riding on it, a laser scanner arch, a drive motor, ending in the assembly station."""
    steel, chrome, belt = m["RoboSteel"], m["RoboChrome"], m["RoboCables"]
    x0, x1 = CONVEYOR_X
    y0, y1 = CONVEYOR_Y
    cx, width = (x0 + x1) / 2, x1 - x0
    for x in (x0, x1):
        box(steel, (x, (y0 + y1) / 2, BELT_Z - 0.2), (0.14, y1 - y0, 0.42))
        box(m["RoboFence"], (x, (y0 + y1) / 2, BELT_Z + 0.42), (0.1, y1 - y0, 0.12))
        for y in arange(y1 - y0, 3.0):
            extrude(m["RoboFence"], (x, y0 + y, BELT_Z + 0.02), (x, y0 + y, BELT_Z + 0.42), rrect(0.08, 0.08, 0.02), up=(1, 0, 0))
    for y in arange(y1 - y0 - 0.6, 4.0):
        for x in (x0 + 0.1, x1 - 0.1):
            extrude(steel, (x, y0 + 0.3 + y, 0.0), (x, y0 + 0.3 + y, BELT_Z - 0.35), rrect(0.16, 0.16, 0.03), up=(1, 0, 0))
        box(steel, (cx, y0 + 0.3 + y, 0.6), (width, 0.1, 0.1))
    box(belt, (cx, (y0 + y1) / 2, BELT_Z - 0.05), (width - 0.3, y1 - y0, 0.1))
    for y in arange(y1 - y0, 1.0):
        box(belt, (cx, y0 + y, BELT_Z + 0.01), (width - 0.4, 0.06, 0.04))
    for y in arange(y1 - y0 - 0.4, 1.0):
        cylinder_x(chrome, (cx, y0 + 0.2 + y, BELT_Z - 0.28), width - 0.35, 0.1, 10)
    for y in (y0, y1):
        cylinder_x(chrome, (cx, y, BELT_Z - 0.12), width - 0.2, 0.18, 16)
    box(m["RoboPanels"], (x1 + 0.45, y0 + 1.0, BELT_Z - 0.5), (0.7, 1.0, 0.8))
    cylinder_x(m["RoboJoints"], (x1 + 0.55, y0 + 1.0, BELT_Z - 1.15), 0.8, 0.32, 16)
    # Parts riding on the belt.
    sequence = ("crate", "head", "gear", "torso", "crate", "head", "torso", "gear", "crate", "head", "torso", "crate", "head")
    for k, kind in enumerate(sequence):
        y = y0 + 2.0 + k * 3.4
        if y > y1 - 2.5:
            break
        base = Vector((cx + rng.uniform(-0.15, 0.15), y, BELT_Z + 0.04))
        if kind == "crate":
            crate(m, base + Vector((0, 0, 0.42)), (1.2, 1.0, 0.84))
        elif kind == "head":
            robot_head(m, base, facing=(-1, 0.2, 0), size=1.0)
        elif kind == "torso":
            robot_torso(m, base, facing=(-1, 0, 0), size=0.85)
        else:
            gear(m, base + Vector((0, 0, 0.1)), 0.65, axis=(0, 0, 1))
            gear(m, base + Vector((0.1, 0.1, 0.28)), 0.42, axis=(0, 0, 1))
    # Laser scanner arch over the belt (well away from the right banner).
    sy = 18.0
    for x in (x0 - 0.15, x1 + 0.15):
        extrude(m["RoboPanels"], (x, sy, BELT_Z + 0.1), (x, sy, BELT_Z + 2.6), rrect(0.3, 0.4, 0.06), up=(1, 0, 0))
    box(m["RoboPanels"], (cx, sy, BELT_Z + 2.75), (width + 0.7, 0.5, 0.35))
    for k in range(7):
        box(m["RoboLaser"], (x0 + 0.25 + (width - 0.5) * k / 6, sy, BELT_Z + 1.32), (0.035, 0.035, 2.5))
    box(m["RoboLaser"], (cx, sy, BELT_Z + 0.05), (width - 0.4, 0.05, 0.02))
    box(m["RoboGlow"], (cx, sy - 0.26, BELT_Z + 2.75), (width - 0.2, 0.03, 0.1))
    # The assembly station at the machine end, where the belt ends.
    st = Vector((17.6, 37.8, 0.0))
    box(m["RoboPanels"], st + Vector((0, 0, 2.6)), (5.6, 5.2, 5.2))
    box(m["RoboJoints"], st + Vector((-1.0, -2.62, BELT_Z + 0.75)), (2.8, 0.06, 1.6))
    box(m["RoboGlow"], st + Vector((-2.82, 0.4, 3.4)), (0.04, 2.6, 1.0))
    for k in range(4):
        box(m["RoboJoints"], st + Vector((-2.83, -1.6 + 0.3 * k, 1.6)), (0.04, 0.16, 1.2))
    striped_box(m, st + Vector((0, -2.62, 5.0)), (5.6, 0.1, 0.4), stripe_faces=("y",))
    lathe(m["RoboSteel"], [(0, 5.2), (0.45, 5.2), (0.45, 6.6), (0.55, 6.6), (0.55, 6.8), (0, 6.8)], 16,
          transform=Matrix.Translation(st + Vector((1.6, 1.4, 0))))
    beacon(m, st + Vector((-1.6, 1.2, 5.2)), "RoboBeaconSpinC")


def build_workshop(m):
    """Behind the machine end: a welding robot at work on a robot body, crates and drums."""
    # Welding jig and the robot body being built.
    steel = m["RoboSteel"]
    jig = Vector((-3.0, 37.2, 0.0))
    box(steel, jig + Vector((0, 0, 1.5)), (4.4, 2.0, 0.2))
    for dx in (-1.9, 1.9):
        for dy in (-0.75, 0.75):
            extrude(steel, jig + Vector((dx, dy, 0)), jig + Vector((dx, dy, 1.4)), rrect(0.16, 0.16, 0.03), up=(1, 0, 0))
    robot_torso(m, jig + Vector((0, 0, 1.6)), facing=(0, -1, 0), size=1.2)
    robot_head(m, jig + Vector((1.4, 0.2, 1.6)), facing=(-0.4, -1, 0), size=0.8)
    box(steel, Vector((-3.0, 40.6, 0.4)), (2.4, 2.4, 0.8))
    striped_box(m, Vector((-3.0, 40.6, 0.4)), (2.5, 2.5, 0.3), stripe_faces=("x", "y"))
    # Welding robot facing the jig (local +X toward -Y); its torch points down onto the body.
    robot_arm(m, (-3.0, 40.6, 0.8), -math.pi / 2, (0.55, 2.6), (1.5, 6.6), (4.4, 5.2), (0, 0, -1), scale=0.72, gripper=False)
    beacon(m, (-1.2, 41.4, 0.8), "RoboBeaconSpinB")
    # Crates and drums on pallets at the left.
    for px, py in ((-18.0, 37.5), (-13.0, 38.6)):
        box(m["RoboCrates"], (px, py, 0.08), (2.6, 2.2, 0.16))
    crate(m, (-18.6, 37.0, 0.66), (1.2, 1.0, 1.0))
    crate(m, (-17.3, 37.2, 0.66), (1.1, 1.1, 1.0))
    crate(m, (-18.0, 37.6, 1.66), (1.2, 1.0, 1.0))
    crate(m, (-17.6, 38.3, 0.66), (1.0, 1.0, 1.0))
    for dx, dy in ((-0.65, -0.5), (0.65, -0.5), (0.0, 0.55)):
        drum(m, (-13.0 + dx, 38.6 + dy, 0.16))
    drum(m, (-10.6, 39.6, 0.0))
    # A tall exhaust stack with a steam vent.
    lathe(steel, [(0, 0), (0.7, 0), (0.7, 0.3), (0.45, 0.4), (0.4, 9.0), (0.5, 9.1), (0.5, 9.4), (0, 9.4)], 20,
          transform=Matrix.Translation((-8.0, 40.8, 0)))


def build_and_export(export=True):
    coll = begin(COLLECTION)
    m = {name: bmesh.new() for name in LOOKS}
    build_frame(m)
    build_walls(m)
    build_crane(m)
    build_lamps(m)
    build_robot_and_screen(m)
    beacon(m, (PITCH.x + 3.65, SCREEN_Y, 6.95), "RoboBeaconSpinA")
    build_controls(m)
    build_conveyor(m)
    build_workshop(m)
    objects = []
    for name, (rgb, shading) in LOOKS.items():
        bm = m[name]
        if not bm.verts:
            bm.free()
            continue
        objects.append(soft(coll, name, bm, rgb) if shading == "soft" else finish(coll, name, bm, rgb, hard=shading == "hard"))
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
