# World 3 (Future World) runway props, space half: sections 6-10 in one batch.
#   Virtual Grid:         DataCube, VoxelTree, GlitchPillar          backdrop VoxelPeak    filler VoxelBush
#   Orbital Spaceport:    Rocket, RadarDish, FuelTank                backdrop LaunchTower  filler CargoCrate
#   Lunar Colony:         HabitatPod, LunarLander, AstronautFlag     backdrop MoonRidge
#   Red Planet Outpost:   MarsRover, Terraformer                     (HabitatPod again, tinted)
#   Quantum Singularity:  EnergyRing, QuantumShard, RiftRock         landmark BlackHole
# Same conventions as runway_world2.py, whose helpers this script reuses: run inside Blender (e.g. via
# MCP); one mesh per colour role, named <Template><Part>; 1 unit = 1 stud at template scale; each model
# rests on z = 0 centred on its origin in X and Y. The floating QuantumShard and RiftRock rest their
# lowest point on z = 0 (RunwayDecor lifts them); the BlackHole is centred on its origin instead.
# Props with a front face -Y (RunwayDecor turns them to the tee). No mesh or model exceeds 20 units on
# any axis, so Roblox's 100x FBX import stays under its 2048-stud part limit; backdrops are scaled up
# in RunwayDecor. A manifest (template -> mesh names) is written beside the FBX.
# Iterate with EXPORT = False (and optionally ONLY = [template names]) set before exec().
import bpy, bmesh, math, os, random, json
from mathutils import Vector, Matrix, Euler, noise

# World 2's helpers (and the shared prop_helpers they load); its own builders are not run.
RUNWAY_WORLD2 = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\runway_world2.py"
_source = open(RUNWAY_WORLD2, encoding="utf-8").read()
_marker = "# ---------- 1. Prehistoric Valley ----------"
assert _marker in _source, "runway_world2.py layout changed"
exec(_source.partition(_marker)[0])

COLLECTION = "RunwayWorld3Space"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayWorld3Space.fbx"
MANIFEST_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayWorld3Space.json"
MAX_SIZE = 20.0

# Preview colours only; RunwayDecor tints every part in Roblox.
WHITE = (0.94, 0.95, 0.97)
SILVER = (0.72, 0.75, 0.8)
GUNMETAL = (0.2, 0.22, 0.27)
NAVY = (0.07, 0.09, 0.18)
NEON_CYAN = (0.2, 0.95, 1.0)
NEON_PINK = (1.0, 0.3, 0.8)
VOXEL_GREEN = (0.18, 0.6, 0.3)
VOXEL_LIME = (0.55, 0.9, 0.35)
ROCKET_RED = (0.85, 0.16, 0.14)
FOIL_GOLD = (0.95, 0.72, 0.2)
MOON_GREY = (0.6, 0.6, 0.62)
MARS_RUST = (0.72, 0.33, 0.2)
SOLAR_BLUE = (0.1, 0.18, 0.45)
GLASS_BLUE = (0.55, 0.8, 1.0)
VIOLET = (0.6, 0.3, 1.0)
CONCRETE = (0.62, 0.62, 0.6)
HAZARD = (1.0, 0.75, 0.1)


# ---------- extra geometry helpers ----------

def chamfer_box(bm, center, size, chamfer=0.1, rotation=(0, 0, 0)):
    """A box with every edge cut at 45 degrees so it catches light; rotation is an Euler tuple or 3x3 Matrix."""
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    c = max(0.005, min(chamfer, hx * 0.9, hy * 0.9, hz * 0.9))
    rot = rotation if isinstance(rotation, Matrix) else Euler(rotation).to_matrix()
    center = Vector(center)
    corner = {}
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                points = ((sx * hx, sy * (hy - c), sz * (hz - c)), (sx * (hx - c), sy * hy, sz * (hz - c)),
                          (sx * (hx - c), sy * (hy - c), sz * hz))
                corner[(sx, sy, sz)] = [bm.verts.new(center + rot @ Vector(p)) for p in points]
    loop = ((-1, -1), (1, -1), (1, 1), (-1, 1))
    for s in (-1, 1):
        bm.faces.new([corner[(s, a, b)][0] for a, b in loop])
        bm.faces.new([corner[(a, s, b)][1] for a, b in loop])
        bm.faces.new([corner[(a, b, s)][2] for a, b in loop])
    for a in (-1, 1):
        for b in (-1, 1):
            bm.faces.new((corner[(-1, a, b)][1], corner[(1, a, b)][1], corner[(1, a, b)][2], corner[(-1, a, b)][2]))
            bm.faces.new((corner[(a, -1, b)][0], corner[(a, 1, b)][0], corner[(a, 1, b)][2], corner[(a, -1, b)][2]))
            bm.faces.new((corner[(a, b, -1)][0], corner[(a, b, 1)][0], corner[(a, b, 1)][1], corner[(a, b, -1)][1]))
    for vx, vy, vz in corner.values():
        bm.faces.new((vx, vy, vz))


def obox(bm, matrix, center, size, chamfer=0.0):
    """A box given in a local frame (a rotation + translation matrix), for parts aligned to a tilted body."""
    if chamfer:
        chamfer_box(bm, matrix @ Vector(center), size, chamfer, matrix.to_3x3())
        return
    cube = bmesh.ops.create_cube(bm, size=1.0)
    for v in cube["verts"]:
        v.co = matrix @ (Vector(center) + Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])))


def beam(bm, a, b, width, depth=None, roll=0.0):
    """A rectangular bar from point a to point b (lattice members, struts, rails)."""
    a, b = Vector(a), Vector(b)
    frame = Matrix.Translation((a + b) / 2) @ align_z(b - a) @ Matrix.Rotation(roll, 4, "Z")
    obox(bm, frame, (0, 0, 0), (width, width if depth is None else depth, (b - a).length))


def slab(bm, outline, thickness, matrix=Matrix()):
    """A flat plate: a closed (x, z) outline extruded along Y, placed by matrix (fins, gussets, signs)."""
    front = [bm.verts.new(matrix @ Vector((x, -thickness / 2, z))) for x, z in outline]
    back = [bm.verts.new(matrix @ Vector((x, thickness / 2, z))) for x, z in outline]
    caps = [bm.faces.new(front), bm.faces.new(tuple(reversed(back)))]
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.triangulate(bm, faces=caps)  # outlines may be concave


def settle(parts, ground=True):
    """Move a model's bmesh parts together so it is centred on the origin in X and Y and (if ground) rests on z = 0."""
    verts = [v for bm in parts for v in bm.verts]
    lo = Vector((min(v.co.x for v in verts), min(v.co.y for v in verts), min(v.co.z for v in verts)))
    hi = Vector((max(v.co.x for v in verts), max(v.co.y for v in verts), max(v.co.z for v in verts)))
    offset = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z if ground else 0.0))
    for v in verts:
        v.co += offset


def ring_profile(bm, matrix, radius, profile, segments=48, a0=0.0, a1=None):
    """Sweep a closed 2D (radial, axial) profile around the matrix's Z axis at radius: a full ring, or an
    arc from angle a0 to a1 with capped ends."""
    full = a1 is None
    count = segments if full else segments + 1
    rings = []
    for k in range(count):
        a = 2 * math.pi * k / segments if full else a0 + (a1 - a0) * k / segments
        c, s = math.cos(a), math.sin(a)
        rings.append([bm.verts.new(matrix @ Vector(((radius + u) * c, (radius + u) * s, v))) for u, v in profile])
    n = len(profile)
    for k in range(segments):
        a, b = rings[k], rings[(k + 1) % count]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if not full:
        bm.faces.new(tuple(reversed(rings[0])))
        bm.faces.new(tuple(rings[-1]))


def capsule(bm, x, y, r, z0, z1, dome=0.7, segments=32):
    """A vertical tank standing at z0: a cylinder with a squashed dome ending at z1."""
    profile = [(0, z0), (r, z0)] + [(r * math.cos(t), z1 - dome * r + dome * r * math.sin(t))
                                    for t in [math.pi / 2 * k / 6 for k in range(6)]] + [(0, z1)]
    lathe(bm, profile, segments, Matrix.Translation((x, y, 0)))


VOXEL_FACES = (
    ((1, 0, 0), ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1))),
    ((-1, 0, 0), ((0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0))),
    ((0, 1, 0), ((0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0))),
    ((0, -1, 0), ((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1))),
    ((0, 0, 1), ((0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1))),
    ((0, 0, -1), ((0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0))),
)


def voxel_object(coll, name, cells, solid, cell, origin, rgb):
    """The visible faces of grid cells (i, j, k) as one flat-shaded mesh. A face is kept only where the
    neighbouring cell is not in solid (every colour's cells), so touching cubes never z-fight."""
    bm = bmesh.new()
    verts = {}

    def corner(key):
        if key not in verts:
            verts[key] = bm.verts.new((origin[0] + key[0] * cell[0], origin[1] + key[1] * cell[1], origin[2] + key[2] * cell[2]))
        return verts[key]
    for i, j, k in cells:
        for (di, dj, dk), quad in VOXEL_FACES:
            if (i + di, j + dj, k + dk) not in solid:
                bm.faces.new([corner((i + a, j + b, k + c)) for a, b, c in quad])
    obj = make_object(coll, name, bm, rgb)
    smooth_by_angle(obj, 30)
    return obj


# ---------- 6. Virtual Grid ----------

def build_data_cube(coll):
    """A glowing wireframe cube balanced on one corner, floating over a hex pedestal, with a tilted
    solid core inside it and a few data bits drifting up off its top."""
    rng = random.Random(4)
    edges, core, base = bmesh.new(), bmesh.new(), bmesh.new()
    # Hex pedestal (flat faces toward -Y) with a glowing band and an emitter ring on top.
    lathe(base, [(0, 0), (2.7, 0), (2.7, 0.32), (2.45, 0.5), (1.8, 0.6), (1.5, 1.5), (1.9, 1.62), (1.9, 1.85), (0, 1.85)], 6)
    lathe(edges, [(2.76, 0.1), (2.76, 0.24), (2.6, 0.24), (2.6, 0.1), (2.76, 0.1)], 6)
    lathe(edges, [(1.0, 1.82), (1.45, 1.82), (1.45, 1.95), (1.0, 1.95), (1.0, 1.82)], 6)
    # Wireframe cube balanced on a corner: 12 edge beams and 8 corner nodes, built in the cube's frame.
    # It is turned so one upper corner points at -Y: from the front it reads as the classic isometric cube.
    a, t = 3.7, 0.3
    center = Vector((0, 0, 1.85 + 0.9 + a * math.sqrt(3) / 2))
    on_corner = Vector((1, 1, 1)).normalized().rotation_difference(Vector((0, 0, 1))).to_matrix().to_4x4()
    upper = on_corner @ Vector((1, 1, -1))
    turn = -math.pi / 2 - math.atan2(upper.y, upper.x)
    frame = Matrix.Translation(center) @ Matrix.Rotation(turn, 4, "Z") @ on_corner
    h = a / 2
    for axis in range(3):
        for s1 in (-1, 1):
            for s2 in (-1, 1):
                c, size = [0, 0, 0], [t, t, t]
                c[(axis + 1) % 3], c[(axis + 2) % 3] = s1 * h, s2 * h
                size[axis] = a
                obox(edges, frame, c, size)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                obox(edges, frame, (sx * h, sy * h, sz * h), (t * 1.75,) * 3, chamfer=0.07)
    # A tilted solid core, and data bits drifting up off the top corner.
    chamfer_box(core, center, (2.0, 2.0, 2.0), 0.16, Euler((0.62, 0.3, 0.75)).to_matrix())
    for p, s in (((0.95, 0.1, 10.3), 0.46), ((-0.75, 0.35, 11.05), 0.36), ((0.3, -0.2, 11.75), 0.26)):
        chamfer_box(core, p, (s, s, s), 0.05, Euler((rng.uniform(0, 1), rng.uniform(0, 1), rng.uniform(0, 1))).to_matrix())
    return [closed(coll, "DataCubeEdges", edges, NEON_CYAN, hard=True), closed(coll, "DataCubeCore", core, NEON_PINK, hard=True),
            closed(coll, "DataCubeBase", base, GUNMETAL, hard=True)]


def build_voxel_tree(coll):
    """A 1-unit voxel tree: a 2x2 trunk with stepped roots, two branches carrying side clumps under a big
    crown; the top cube of every leaf column is the light tone, so each terrace gets a sunlit rim."""
    rng = random.Random(42)
    trunk, leaves = set(), set()
    for k in range(10):
        for i in (-1, 0):
            for j in (-1, 0):
                trunk.add((i, j, k))
    for i, j, k in ((-2, -1, 0), (-2, 0, 0), (-2, -1, 1), (1, 0, 0), (1, -1, 0), (1, 0, 1), (-1, 1, 0), (0, -2, 0), (-1, -2, 0)):
        trunk.add((i, j, k))
    for i, j, k in ((-2, 0, 4), (-2, 0, 5), (-3, 0, 5), (-3, 0, 6), (1, -1, 5), (2, -1, 5), (2, -1, 6), (3, -1, 6), (3, -1, 7),
                    (0, 1, 5), (0, 1, 6), (0, 2, 6), (0, 2, 7)):
        trunk.add((i, j, k))
    lobes = [((0.3, 0.3, 11.8), (4.1, 4.0, 3.0)), ((-4.2, 0.5, 7.6), (1.9, 1.8, 1.45)), ((3.7, -1.1, 8.6), (1.9, 1.9, 1.45)),
             ((0.4, 3.9, 8.3), (1.8, 1.7, 1.4)), ((-0.6, 0.8, 14.0), (2.3, 2.1, 1.2))]
    for i in range(-7, 7):
        for j in range(-6, 7):
            for k in range(5, 16):
                p = Vector((i + 0.5, j + 0.5, k + 0.5))
                for c, r in lobes:
                    if ((p.x - c[0]) / r[0]) ** 2 + ((p.y - c[1]) / r[1]) ** 2 + ((p.z - c[2]) / r[2]) ** 2 <= 1.0:
                        leaves.add((i, j, k))
                        break
    trunk -= leaves
    solid = trunk | leaves
    light = {(i, j, k) for i, j, k in leaves if (i, j, k + 1) not in solid}
    light |= {cell for cell in sorted(leaves - light) if rng.random() < 0.04}
    # Centre the grid's bounds on the origin.
    origin = (-(min(c[0] for c in solid) + max(c[0] for c in solid) + 1) / 2, -(min(c[1] for c in solid) + max(c[1] for c in solid) + 1) / 2, 0)
    return [voxel_object(coll, "VoxelTrunk", trunk, solid, (1, 1, 1), origin, WOOD),
            voxel_object(coll, "VoxelLeaves", leaves - light, solid, (1, 1, 1), origin, VOXEL_GREEN),
            voxel_object(coll, "VoxelLeavesLight", light, solid, (1, 1, 1), origin, VOXEL_LIME)]


def build_glitch_pillar(coll):
    """Crisp dark blocks outlined in light (glowing seams and corner edges) with a few lit data pixels.
    Some slices are knocked sideways, each with a glowing ghost copy pushed the other way (an RGB-split
    look), and pixels break off beside them."""
    rng = random.Random(9)
    blocks, glow = bmesh.new(), bmesh.new()
    chamfer_box(blocks, (0, 0, 0.35), (4.6, 4.6, 0.7), 0.1)
    seam = 0.16
    # (height, dx, dy, twist): true blocks, plus slices knocked sideways.
    stack = [(2.4, 0.0, 0.0, 0.0), (0.6, 1.25, 0.0, 0.0), (2.0, 0.1, -0.05, 0.05), (0.5, -1.35, 0.2, 0.0), (0.45, 0.9, -0.35, 0.0),
             (2.6, -0.05, 0.1, -0.04), (1.6, 0.2, 0.0, 0.0), (0.55, -1.2, -0.3, 0.0), (2.1, 0.0, 0.05, 0.06), (0.8, 0.0, 0.0, 0.0)]
    z, previous = 0.7, (0.0, 0.0, 3.4)
    for n, (height, dx, dy, twist) in enumerate(stack):
        width = 3.3 - 0.06 * n  # a slight taper toward the cap
        w = width + (0.4 if n == len(stack) - 1 else 0.0)
        inner = min(width, previous[2]) - 0.36
        box(glow, ((dx + previous[0]) / 2, (dy + previous[1]) / 2, z + seam / 2), (inner, inner, seam + 0.06))
        z += seam
        rot = Matrix.Rotation(twist, 3, "Z")
        center = Vector((dx, dy, z + height / 2))
        chamfer_box(blocks, center, (w, w, height), 0.05, rot)
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            box(glow, center + rot @ Vector((sx * (w / 2 - 0.02), sy * (w / 2 - 0.02), 0)), (0.17, 0.17, height + 0.02),
                rotation=rot.to_euler())
        if height > 1.2:  # one staggered cluster of lit pixels on a face
            yaw = rot @ Matrix.Rotation(rng.randrange(4) * math.pi / 2, 3, "Z")
            col, row = rng.randrange(-3, 0), rng.randrange(int((height - 1.4) / 0.42) + 1)
            for k in range(rng.choice((3, 4))):
                p = Vector(((col + k) * 0.42 + 0.21, -w / 2 - 0.02, -height / 2 + 0.46 + (row + k % 2) * 0.42))
                box(glow, center + yaw @ p, (0.3, 0.1, 0.3), rotation=yaw.to_euler())
        if abs(dx) + abs(dy) > 0.5:  # the glowing ghost of a knocked slice, pushed the other way
            box(glow, (-dx * 0.7, -dy * 0.7, z + height / 2), (width * 0.9, width * 0.9, height * 0.6))
        z += height
        previous = (dx, dy, width)
    # Pixels breaking off beside the knocked-out slices.
    for (x, y, zz), s, lit in (((2.85, 0.4, 4.9), 0.6, False), ((-2.75, 0.3, 7.9), 0.8, True), ((-3.15, -0.5, 9.0), 0.45, False),
                               ((2.6, -0.5, 13.6), 0.75, False), ((3.1, 0.3, 14.75), 0.5, True)):
        chamfer_box(glow if lit else blocks, (x, y, zz), (s, s, s), 0.06, Euler((0, 0, rng.uniform(-0.4, 0.4))).to_matrix())
    return [closed(coll, "GlitchBlocks", blocks, NAVY, hard=True), closed(coll, "GlitchGlow", glow, NEON_PINK, hard=True)]


def build_voxel_peak(coll):
    """A terraced voxel mountain from a height map of columns. Every terrace edge carries a glowing
    strip (merged into long runs), so the contour lines trace the steps; the upper terraces get caps."""
    cell = (1.4, 1.4, 1.1)
    nx, ny = 14, 13
    origin = (-nx * cell[0] / 2, -ny * cell[1] / 2, 0.0)
    heights = {}
    for i in range(nx):
        for j in range(ny):
            x, y = origin[0] + (i + 0.5) * cell[0], origin[1] + (j + 0.5) * cell[1]
            if (x / 10.2) ** 2 + (y / 9.4) ** 2 > 1.0:
                continue
            main = 17.0 * max(0.0, 1 - math.hypot((x + 1.2) / 8.4, (y - 0.5) / 7.6))
            second = 11.2 * max(0.0, 1 - math.hypot((x - 5.4) / 5.2, (y + 1.8) / 4.8))
            third = 7.1 * max(0.0, 1 - math.hypot((x + 6.4) / 4.4, (y + 3.8) / 4.4))
            # A ridge running from the main summit down toward the second peak.
            along = max(0.0, min(1.0, ((x + 1.2) * 6.6 - (y - 0.5) * 2.3) / (6.6 ** 2 + 2.3 ** 2)))
            ridge = 0.6 * 17.0 * (1 - 0.45 * along) * max(0.0, 1 - math.hypot(x + 1.2 - 6.6 * along, y - 0.5 + 2.3 * along) / 2.2)
            h = max(main, second, third, ridge, 1.0) + 1.0 * noise.noise(Vector((x * 0.2, y * 0.2, 0.5)))
            heights[(i, j)] = max(1, min(12, int(round(h / cell[2]))))

    def median(i, j):
        """The median height around a column (3 x 3): single-cell bumps and pits become terrace edges."""
        around = sorted(heights[(i + di, j + dj)] for di in (-1, 0, 1) for dj in (-1, 0, 1) if (i + di, j + dj) in heights)
        return around[len(around) // 2]
    heights = {key: median(*key) for key in heights}
    top = max(heights.values())
    heights = {key: (levels + 1 if levels == top else levels) for key, levels in heights.items()}  # a summit block
    top += 1
    rock, snow = set(), set()
    for (i, j), levels in heights.items():
        for k in range(levels):
            (snow if levels >= top - 4 and k == levels - 1 else rock).add((i, j, k))
    solid = rock | snow
    runs = {}
    for (i, j), levels in heights.items():
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if heights.get((i + di, j + dj), 0) < levels:
                key = ("x", i + (di > 0), levels) if di else ("y", j + (dj > 0), levels)
                runs.setdefault(key, []).append(j if di else i)
    glow, t = bmesh.new(), 0.2
    for (axis, line, levels), steps in runs.items():
        steps.sort()
        start = steps[0]
        for n, step in enumerate(steps):
            if n + 1 < len(steps) and steps[n + 1] == step + 1:
                continue
            z = levels * cell[2]
            if axis == "x":
                y0, y1 = origin[1] + start * cell[1], origin[1] + (step + 1) * cell[1]
                box(glow, (origin[0] + line * cell[0], (y0 + y1) / 2, z), (t, y1 - y0 + t, t))
            else:
                x0, x1 = origin[0] + start * cell[0], origin[0] + (step + 1) * cell[0]
                box(glow, ((x0 + x1) / 2, origin[1] + line * cell[1], z), (x1 - x0 + t, t, t))
            if n + 1 < len(steps):
                start = steps[n + 1]
    return [voxel_object(coll, "VoxelPeakRock", rock, solid, cell, origin, GUNMETAL),
            closed(coll, "VoxelPeakGlow", glow, NEON_CYAN, hard=True),
            voxel_object(coll, "VoxelPeakSnow", snow, solid, cell, origin, WHITE)]


def build_voxel_bush(coll):
    """A filler: a cluster of chamfered cubes of several sizes, three small ones glowing."""
    leaves, glow = bmesh.new(), bmesh.new()
    # (centre, size, yaw, tilt, glowing): a big middle cube, shoulders around it, one perched on top.
    cubes = [((0.0, 0.2, 1.4), 2.8, 0.15, 0.0, False), ((-1.95, -0.45, 0.95), 1.9, -0.3, 0.0, False),
             ((1.9, -0.4, 1.0), 2.0, 0.5, 0.0, False), ((0.55, 1.65, 0.85), 1.7, -0.15, 0.0, False),
             ((-1.55, 1.45, 0.75), 1.5, 0.4, 0.0, False), ((-0.55, 0.75, 3.15), 1.4, 0.55, 0.12, False),
             ((1.25, -1.5, 2.3), 1.0, 0.3, 0.0, True), ((-1.35, 1.25, 2.0), 0.95, -0.2, 0.1, True),
             ((-2.65, -1.55, 0.36), 0.72, 0.6, 0.0, True)]
    for center, size, yaw, tilt, lit in cubes:
        chamfer_box(glow if lit else leaves, center, (size, size, size), 0.1, Euler((tilt, 0, yaw)).to_matrix())
    settle([leaves, glow])
    return [closed(coll, "VoxelBushLeaves", leaves, VOXEL_GREEN, hard=True), closed(coll, "VoxelBushGlow", glow, NEON_CYAN, hard=True)]


# ---------- 7. Orbital Spaceport ----------

ROCKET_BODY = [(0, 1.85), (1.05, 1.85), (1.35, 2.3), (1.65, 3.2), (1.88, 4.6), (2.0, 6.2), (2.02, 7.6), (1.98, 9.2),
               (1.86, 10.8), (1.68, 12.4), (1.45, 13.8), (1.33, 14.6), (0, 14.6)]


def build_rocket(coll):
    """A retro rocket standing on three swept fins on an octagonal pad, held by three short clamps."""
    body, accent, fins, pad, window = (bmesh.new() for _ in range(5))
    octagon = Matrix.Rotation(math.pi / 8, 4, "Z")
    lathe(pad, [(0, 0), (4.0, 0), (4.0, 0.7), (3.9, 1.0), (0, 1.0)], 8, octagon)
    lathe(accent, [(2.45, 0.98), (2.85, 0.98), (2.85, 1.06), (2.45, 1.06), (2.45, 0.98)], 8, octagon)
    lathe(pad, [(0, 1.95), (0.62, 1.95), (0.56, 1.7), (0.72, 1.42), (0.98, 1.16), (0.9, 1.12), (0.62, 1.38), (0.46, 1.68), (0, 1.68)], 24)
    lathe(body, ROCKET_BODY, 32)
    lathe(accent, [(0, 14.55), (1.335, 14.55), (1.22, 15.4), (1.02, 16.4), (0.76, 17.4), (0.47, 18.4), (0.2, 19.2), (0, 19.6)], 32)
    for z0, z1 in ((5.0, 5.6), (6.0, 6.3), (12.6, 13.0)):
        band(accent, ROCKET_BODY[4:12], z0, z1, out=0.05, depth=0.12, segments=32)
    fin = [(1.6, 7.6), (2.05, 7.3), (2.6, 6.0), (3.05, 4.3), (3.38, 2.6), (3.5, 1.35), (3.5, 1.0), (2.9, 1.0), (2.5, 1.55),
           (2.02, 2.05), (1.5, 2.45), (1.0, 2.6)]
    for angle in (90, 210, 330):
        slab(fins, fin, 0.34, Matrix.Rotation(math.radians(angle), 4, "Z"))
    for angle in (30, 150, 270):
        rot = Matrix.Rotation(math.radians(angle), 3, "Z")
        if angle != 270:  # clamps behind, so the front stays clear
            chamfer_box(pad, rot @ Vector((3.05, 0, 1.9)), (0.6, 0.7, 1.8), 0.08, rot)
            chamfer_box(pad, rot @ Vector((2.2, 0, 2.75)), (1.5, 0.45, 0.4), 0.06, rot)
        # Portholes between the fins, one facing -Y.
        out = rot @ Vector((1, 0, 0))
        r = profile_r(ROCKET_BODY[1:-1], 9.6)
        cyl(window, out * (r - 0.08) + Vector((0, 0, 9.6)), 0.52, 0.3, 24, direction=out)
        torus(accent, Matrix.Translation(out * (r + 0.12) + Vector((0, 0, 9.6))) @ align_z(out), 0.6, 0.12, seg=28, tseg=8)
    return [closed(coll, "RocketBody", body, WHITE), closed(coll, "RocketAccent", accent, ROCKET_RED),
            closed(coll, "RocketFins", fins, ROCKET_RED, hard=True), closed(coll, "RocketPad", pad, CONCRETE, hard=True),
            closed(coll, "RocketWindow", window, GLASS_BLUE)]


def build_radar_dish(coll):
    """A parabolic dish tipped up 45 degrees toward -Y on a yoke and turntable, a feed horn on four struts."""
    bowl, mount, feed = bmesh.new(), bmesh.new(), bmesh.new()
    chamfer_box(mount, (0, 0.6, 0.3), (4.4, 4.4, 0.6), 0.12)
    cyl(mount, (0, 0.6, 0.6), 1.9, 0.45, 32)
    cyl(mount, (0, 0.6, 1.05), 1.0, 2.9, 24, top=0.78)
    chamfer_box(mount, (0, 0.6, 4.2), (3.9, 1.3, 0.6), 0.1)
    for x in (-1.7, 1.7):
        chamfer_box(mount, (x, 0.6, 5.35), (0.55, 1.1, 2.3), 0.08)
    hub = Vector((0, 0.6, 6.4))
    axis = Vector((0, -1, 1)).normalized()
    cyl(mount, hub + Vector((-2.05, 0, 0)), 0.36, 4.1, 16, direction=(1, 0, 0))
    frame = Matrix.Translation(hub + axis * 0.9) @ align_z(axis)
    f, R, th = 3.4, 5.0, 0.26
    rs = [R * k / 10 for k in range(1, 11)]
    lathe(bowl, [(0, -th)] + [(r, r * r / (4 * f) - th) for r in rs] + [(R + 0.2, R * R / (4 * f) - 0.05),
          (R + 0.2, R * R / (4 * f) + 0.1)] + [(r, r * r / (4 * f)) for r in reversed(rs)] + [(0, 0)], 48, frame)
    for r in (2.3, 3.8):  # two raised panel rings on the dish face
        torus(bowl, frame @ Matrix.Translation((0, 0, r * r / (4 * f) + 0.02)), r, 0.07, seg=40, tseg=4)
    lathe(mount, [(0, 0.3), (0.75, 0.3), (0.8, 0.0), (0.8, -0.1), (0, -0.1)], 24, frame)  # centre cap
    # Back structure: a cone to the hub, a hub block and radial ribs.
    lathe(mount, [(0, -0.3), (2.4, 2.4 ** 2 / (4 * f) - th + 0.02), (1.1, -0.95), (1.1, -1.3), (0, -1.3)], 24, frame)
    chamfer_box(mount, frame @ Vector((0, 0, -1.25)), (2.6, 1.4, 1.0), 0.12, frame.to_3x3())
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        sweep(mount, [frame @ Vector((r * math.cos(a), r * math.sin(a), r * r / (4 * f) - th - 0.06)) for r in [2.2 + 2.75 * i / 6 for i in range(7)]],
              0.12, segments=6)
    for k in range(4):
        a = 2 * math.pi * (k + 0.5) / 4
        rim = frame @ Vector((4.7 * math.cos(a), 4.7 * math.sin(a), 4.7 ** 2 / (4 * f) + 0.05))
        sweep(feed, [rim, frame @ Vector((0, 0, f - 0.2))], 0.12, segments=6)
    lathe(feed, [(0, f - 1.0), (0.62, f - 1.0), (0.62, f - 0.75), (0.42, f - 0.45), (0.42, f + 0.45), (0.28, f + 0.62), (0, f + 0.62)],
          20, frame)
    settle([bowl, mount, feed])
    return [closed(coll, "DishBowl", bowl, WHITE), closed(coll, "DishMount", mount, STEEL, hard=True),
            closed(coll, "DishFeed", feed, HAZARD)]


def build_fuel_tank(coll):
    """A spherical tank on legs and two domed tanks, bands, a valve manifold along the front and a ladder."""
    body, bands, pipes, base = (bmesh.new() for _ in range(4))
    chamfer_box(base, (0, 0, 0.3), (12.4, 7.4, 0.6), 0.15)
    S, R = Vector((-3.35, 0.4, 4.3)), 2.8
    lathe(body, [(0, S.z - R)] + [(R * math.sin(t), S.z - R * math.cos(t)) for t in [math.pi * k / 14 for k in range(1, 14)]]
          + [(0, S.z + R)], 26, Matrix.Translation((S.x, S.y, 0)))
    torus(bands, M(S), R + 0.03, 0.17, seg=30, tseg=6)
    torus(bands, M(S + Vector((0, 0, 1.7))), math.sqrt(R * R - 1.7 ** 2) + 0.03, 0.09, seg=28, tseg=4)
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        out = Vector((math.cos(a), math.sin(a), 0))
        sweep(bands, [Vector((S.x, S.y, 0.6)) + out * 2.35, S + out * (R + 0.05)], 0.17, segments=6)
    tanks = [(1.45, 0.55, 1.55, 8.7, (2.2, 4.4, 6.6)), (4.65, 0.1, 1.3, 6.9, (2.1, 4.0, 5.6))]
    for x, y, r, top, rings in tanks:
        capsule(body, x, y, r, 0.6, top, segments=24)
        cyl(bands, (x, y, 0.6), r + 0.12, 0.4, 20)
        for z in rings:
            torus(bands, M((x, y, z)), r + 0.03, 0.1, seg=20, tseg=4)
    # Valve manifold: drops from each tank into a header pipe along the front of the slab.
    header_y, header_z = -2.85, 1.05
    sweep(pipes, [Vector((-5.2, header_y, header_z)), Vector((5.7, header_y, header_z))], 0.22, segments=10)
    for x in (-5.2, 5.7):
        cyl(pipes, (x - 0.12, header_y, header_z), 0.32, 0.24, 16, direction=(1, 0, 0))
    for x, y0, z in ((-3.35, -1.55, 2.6), (0.85, -0.7, 3.4), (4.65, -1.0, 2.8)):
        elbow = curve((x, header_y + 0.5, z), (x, header_y, z), (x, header_y, z - 0.5), 5)
        sweep(pipes, [Vector((x, y0, z))] + elbow + [Vector((x, header_y, header_z))], 0.17, segments=8)
        wheel_at = Vector((x, header_y - 0.42, (z + header_z) / 2))
        cyl(pipes, wheel_at + Vector((0, 0.42, 0)), 0.07, 0.42, 6, direction=(0, -1, 0))
        standing = Matrix.Translation(wheel_at) @ Matrix.Rotation(math.pi / 2, 4, "X")
        torus(pipes, standing, 0.38, 0.06, seg=14, tseg=4)
        spoked_hub(pipes, standing, 0.36, 4, 0.1, 0.1, spoke_width=0.08)
    sweep(pipes, curve((-1.65, 0.4, 6.65), (-1.3, 0.45, 9.2), (-0.05, 0.55, 7.6), 12), 0.2, segments=8)
    # Ladder up the front of the tall tank, with safety hoops.
    lx, ly = 2.2, -1.25
    for x in (lx - 0.3, lx + 0.3):
        box(pipes, (x, ly, 4.15), (0.12, 0.12, 7.1))
    for k in range(13):
        box(pipes, (lx, ly, 1.0 + k * 0.52), (0.6, 0.09, 0.09))
    for z in (4.2, 5.8, 7.4):
        sweep(pipes, [Vector((lx + 0.36 * math.cos(t), ly - 0.36 * math.sin(t) - 0.05, z)) for t in [math.pi * k / 6 for k in range(7)]],
              0.05, segments=4)
    settle([body, bands, pipes, base])
    return [closed(coll, "TankBody", body, WHITE), closed(coll, "TankBands", bands, STEEL),
            closed(coll, "TankPipes", pipes, HAZARD), closed(coll, "TankBase", base, CONCRETE, hard=True)]


def build_launch_tower(coll):
    """A lattice gantry with access arms beside a big two-booster rocket on a pad (a backdrop)."""
    steel, rocket, accent, pad, lights = (bmesh.new() for _ in range(5))
    chamfer_box(pad, (0, 0, 0.5), (14.0, 9.6, 1.0), 0.2)
    chamfer_box(pad, (2.6, 0, 1.2), (6.4, 3.6, 0.4), 0.1)
    # Lattice tower: corner posts, a ring of beams each level and X braces on every face.
    tx, half, z0, levels, step = -4.4, 1.45, 1.0, 11, 1.58
    corners = [(tx - half, -half), (tx + half, -half), (tx + half, half), (tx - half, half)]
    for x, y in corners:
        beam(steel, (x, y, z0), (x, y, z0 + levels * step + 0.2), 0.34)
    for k in range(levels + 1):
        z = z0 + k * step
        for (ax, ay), (bx, by) in zip(corners, corners[1:] + corners[:1]):
            beam(steel, (ax, ay, z), (bx, by, z), 0.2)
            if k < levels:
                beam(steel, (ax, ay, z), (bx, by, z + step), 0.13)
                beam(steel, (bx, by, z), (ax, ay, z + step), 0.13)
    top = z0 + levels * step
    chamfer_box(steel, (tx, 0, top + 0.25), (3.6, 3.6, 0.3), 0.06)
    beam(steel, (tx, 0, top + 0.3), (tx, 0, 19.75), 0.16)
    # Rocket: core stage with a payload fairing, two strap-on boosters.
    rx = 2.6
    lathe(rocket, [(0, 1.4), (1.25, 1.4), (1.5, 2.2), (1.5, 14.6), (1.62, 15.2), (1.6, 16.4), (1.28, 17.6), (0.8, 18.7), (0.3, 19.5), (0, 19.75)],
          32, Matrix.Translation((rx, 0, 0)))
    lathe(accent, [(0, 1.15), (0.9, 1.15), (1.05, 1.45), (0, 1.45)], 24, Matrix.Translation((rx, 0, 0)))
    for za, zb in ((9.6, 10.2), (14.3, 14.6)):
        lathe(accent, [(1.46, za), (1.56, za), (1.56, zb), (1.46, zb), (1.46, za)], 32, Matrix.Translation((rx, 0, 0)))
    for bx in (rx - 2.2, rx + 2.2):
        lathe(rocket, [(0, 1.5), (0.55, 1.5), (0.72, 2.0), (0.72, 11.0), (0, 11.0)], 20, Matrix.Translation((bx, 0, 0)))
        lathe(accent, [(0, 10.95), (0.72, 10.95), (0.6, 11.7), (0.32, 12.4), (0, 12.75)], 20, Matrix.Translation((bx, 0, 0)))
        lathe(accent, [(0, 1.0), (0.42, 1.0), (0.58, 1.5), (0, 1.5)], 16, Matrix.Translation((bx, 0, 0)))
        for z in (4.0, 8.0):
            beam(steel, (bx, 0, z), (rx, 0, z), 0.2)
    # Access arms: an umbilical to the near booster, and two to the core (the top one ends in a white room).
    face = tx + half
    for z, reach, room in ((7.2, rx - 2.2 - 0.7, False), (13.4, rx - 1.45, False), (16.1, rx - 1.55, True)):
        for dy in (-0.45, 0.45):
            beam(steel, (face, dy, z - 0.3), (reach, dy, z - 0.3), 0.16)
            beam(steel, (face, dy, z + 0.3), (reach, dy, z + 0.3), 0.16)
        for k in range(int((reach - face) / 0.8)):
            x = face + 0.4 + k * 0.8
            beam(steel, (x, -0.45, z - 0.3), (x + 0.4, -0.45, z + 0.3), 0.1)
            beam(steel, (x, 0.45, z - 0.3), (x + 0.4, 0.45, z + 0.3), 0.1)
        if room:
            chamfer_box(rocket, (reach - 0.55, 0, z + 0.1), (1.1, 1.5, 1.4), 0.08)
        box(lights, (reach - 0.1, 0, z + 0.62), (0.22, 0.22, 0.22))
    for x, y in corners:
        box(lights, (x, y, top + 0.55), (0.28, 0.28, 0.28))
    box(lights, (tx, 0, 19.75), (0.3, 0.3, 0.3))
    settle([steel, rocket, accent, pad, lights])
    return [closed(coll, "GantrySteel", steel, (0.75, 0.25, 0.2), hard=True), closed(coll, "GantryRocket", rocket, WHITE),
            closed(coll, "GantryAccent", accent, GUNMETAL), closed(coll, "GantryPad", pad, CONCRETE, hard=True),
            closed(coll, "GantryLights", lights, (1.0, 0.2, 0.2), hard=True)]


def build_cargo_crate(coll):
    """Two stacked sci-fi crates and one beside them: chamfered bodies, end frames, glowing status strips."""
    body, trim, glow = bmesh.new(), bmesh.new(), bmesh.new()

    def crate(center, size, yaw):
        rot = Matrix.Rotation(yaw, 3, "Z")
        center = Vector(center)
        sx, sy, sz = size
        chamfer_box(body, center, size, 0.2, rot)
        for side in (-1, 1):
            chamfer_box(trim, center + rot @ Vector((side * (sx / 2 - 0.26), 0, 0)), (0.34, sy + 0.1, sz + 0.1), 0.08, rot)
            box(glow, center + rot @ Vector((0, side * (sy / 2 + 0.02), sz * 0.12)), (sx * 0.46, 0.08, 0.16), rotation=rot.to_euler())
            for k in range(3):
                box(glow, center + rot @ Vector((-sx * 0.2 + k * 0.3, side * (sy / 2 + 0.02), -sz * 0.18)), (0.18, 0.08, 0.18),
                    rotation=rot.to_euler())
        box(glow, center + rot @ Vector((0, 0, sz / 2 + 0.02)), (sx * 0.42, 0.14, 0.08), rotation=rot.to_euler())
    crate((-0.95, 0.25, 1.05), (3.4, 2.6, 2.0), 0.05)
    crate((-0.8, 0.2, 2.1 + 0.85), (2.8, 2.3, 1.7), -0.12)
    crate((1.95, -0.6, 0.95), (2.0, 2.1, 1.8), 0.4)
    settle([body, trim, glow])
    return [closed(coll, "CrateBody", body, (0.85, 0.87, 0.9), hard=True), closed(coll, "CrateTrim", trim, GUNMETAL, hard=True),
            closed(coll, "CrateGlow", glow, NEON_CYAN, hard=True)]


# ---------- 8. Lunar Colony ----------

def build_habitat_pod(coll):
    """A horizontal habitat capsule on four short legs: a dome end (+X), a docking port (-X), ribs,
    portholes on both sides, an airlock with an arched door on -Y, an antenna and a solar wing."""
    shell, windows, trim, legs = (bmesh.new() for _ in range(4))
    zc, R = 3.2, 2.3
    along_x = Matrix.Translation((0, 0, zc)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    dome = [(R * math.cos(t), 2.0 + 1.7 * math.sin(t)) for t in [math.pi / 2 * k / 7 for k in range(1, 7)]]
    lathe(shell, [(0, -4.25), (1.45, -4.25), (1.55, -4.05), (R, -3.35), (R, 2.0)] + dome + [(0, 3.7)], 32, along_x)
    for x in (-3.35, -2.4, 0.4, 2.0):
        torus(trim, Matrix.Translation((x, 0, zc)) @ Matrix.Rotation(math.pi / 2, 4, "Y"), R + 0.03, 0.13, seg=32, tseg=6)
    torus(trim, along_x @ Matrix.Translation((0, 0, -4.25)), 1.05, 0.14, seg=24, tseg=6)
    cyl(trim, (-4.33, 0, zc), 0.8, 0.12, 20, direction=(1, 0, 0))
    # Portholes: two on each side and a big one in the dome.
    for x, side in ((1.25, -1), (-2.88, -1), (-1.1, 1), (1.25, 1)):
        out = Vector((0, side * math.cos(0.25), math.sin(0.25)))
        center = Vector((x, 0, zc)) + out * R
        cyl(windows, center - out * 0.12, 0.42, 0.22, 20, direction=out)
        torus(trim, Matrix.Translation(center + out * 0.05) @ align_z(out), 0.47, 0.09, seg=20, tseg=5)
    cyl(windows, (3.45, 0, zc), 0.85, 0.32, 24, direction=(1, 0, 0))
    torus(trim, Matrix.Translation((3.62, 0, zc)) @ align_z(Vector((1, 0, 0))), 0.9, 0.1, seg=24, tseg=5)
    # Airlock module with an arched door, a door window and steps.
    chamfer_box(shell, (-1.1, -2.2, 2.55), (1.9, 1.6, 2.7), 0.15)
    arch = [(-0.62, 1.32), (0.62, 1.32)] + [(0.62 * math.cos(t), 2.75 + 0.62 * math.sin(t)) for t in [math.pi * k / 10 for k in range(11)]]
    slab(trim, [(x - 1.1, z) for x, z in arch], 0.14, Matrix.Translation((0, -3.03, 0)))
    cyl(windows, (-1.1, -3.08, 2.72), 0.27, 0.1, 20, direction=(0, -1, 0))
    box(legs, (-0.68, -3.14, 2.0), (0.1, 0.1, 0.45))
    for k, z in enumerate((0.95, 0.5)):
        box(legs, (-1.1, -3.3 - k * 0.45, z), (1.3, 0.5 + k * 0.4, 0.16))
    for x in (-1.72, -0.48):
        box(legs, (x, -3.5, 0.55), (0.12, 0.9, 1.1))
    # Saddles, legs and footpads.
    for x in (-2.75, 2.15):
        box(legs, (x, 0, 1.05), (0.5, 2.7, 0.5))
        for side in (-1, 1):
            beam(legs, (x, side * 1.25, 1.1), (x + (0.35 if x > 0 else -0.35), side * 1.95, 0.25), 0.22)
            cyl(legs, (x + (0.35 if x > 0 else -0.35), side * 1.95, 0), 0.42, 0.2, 12)
    # Antenna mast with a small dish, and a solar wing on a post.
    cyl(trim, (1.1, 0.6, zc + R - 0.2), 0.07, 1.75, 8)
    lathe(trim, [(0, 0.0), (0.12, 0.0), (0.5, 0.22), (0.46, 0.26), (0, 0.1)], 16,
          Matrix.Translation((1.1, 0.6, zc + R + 1.45)) @ align_z(Vector((0, -0.6, 1))))
    blob(trim, Vector((1.1, 0.6, zc + R + 1.62)), Vector((0.1, 0.1, 0.1)), subdivisions=1)
    cyl(legs, (-2.7, 0, zc + R - 0.2), 0.12, 1.0, 8)
    wing = Matrix.Translation((-2.7, 0, zc + R + 0.85)) @ Matrix.Rotation(-0.4, 4, "X")
    obox(trim, wing, (0, 0, 0), (1.7, 3.6, 0.08))
    obox(windows, wing, (0, 0, 0), (1.55, 3.45, 0.14))
    for k in (-1, 0, 1):
        obox(trim, wing, (0, k * 0.86, 0.02), (1.58, 0.06, 0.16))
    obox(trim, wing, (0, 0, 0.02), (0.06, 3.48, 0.16))
    settle([shell, windows, trim, legs])
    return [closed(coll, "PodShell", shell, WHITE), closed(coll, "PodWindows", windows, SOLAR_BLUE),
            closed(coll, "PodTrim", trim, SILVER), closed(coll, "PodLegs", legs, GUNMETAL, hard=True)]


def octagon_radius(a, apothem):
    """Distance from the axis to an octagon's side (sides facing +-X, +-Y and the diagonals) at angle a."""
    return apothem / math.cos(a - round(a / (math.pi / 4)) * math.pi / 4)


def build_lunar_lander(coll):
    """A classic lander: a crinkled gold-foil octagonal descent stage on four splayed legs with dish
    footpads (a ladder down the front leg), an angular ascent module with triangle windows and antennas."""
    rng = random.Random(12)
    foil, module, legs, windows = (bmesh.new() for _ in range(4))
    # Descent stage: an octagon whose sides are 4 x 5 grids, crinkled along their normals.
    apothem, levels = 2.12, [1.9, 2.26, 2.62, 2.98, 3.34, 3.7]
    angles = [(-math.pi / 8 + k * math.pi / 4 + n * math.pi / 16) for k in range(8) for n in range(4)]
    rings = []
    for li, z in enumerate(levels):
        ring = []
        for ai, a in enumerate(angles):
            r = octagon_radius(a, apothem)
            if ai % 4 and 0 < li < len(levels) - 1:
                r += rng.uniform(-0.1, 0.1)
            ring.append(foil.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    n = len(angles)
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            foil.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    foil.faces.new(tuple(reversed(rings[0])))
    foil.faces.new(tuple(rings[-1]))
    lathe(legs, [(0, 1.95), (0.42, 1.95), (0.86, 1.1), (0.74, 1.1), (0, 1.62)], 20)
    # Legs: the front one (-Y) carries a ladder and a porch.
    for k, deg in enumerate((-90, 0, 90, 180)):
        d = Vector((math.cos(math.radians(deg)), math.sin(math.radians(deg)), 0))
        side = Vector((-d.y, d.x, 0))
        top, foot = d * 2.0 + Vector((0, 0, 3.45)), d * 4.05 + Vector((0, 0, 0.3))
        sweep(legs, [top, foot], 0.17, segments=8)
        knee = top.lerp(foot, 0.55)
        for s in (-1, 1):
            sweep(legs, [d * 2.05 + side * s * 1.0 + Vector((0, 0, 1.95)), knee], 0.1, segments=6)
        lathe(legs, [(0, 0), (0.45, 0), (0.62, 0.12), (0.64, 0.24), (0.2, 0.32), (0, 0.32)], 16, Matrix.Translation(foot - Vector((0, 0, 0.3))))
        if k == 0:
            normal = (foot - top).cross(side).normalized()
            if normal.dot(d) < 0:
                normal = -normal
            for s in (-1, 1):
                sweep(legs, [top + side * s * 0.3 + normal * 0.18, knee.lerp(foot, 0.6) + side * s * 0.3 + normal * 0.18], 0.05, segments=5)
            for t in [0.1 + 0.11 * i for i in range(7)]:
                p = top.lerp(knee.lerp(foot, 0.6), t) + normal * 0.18
                sweep(legs, [p - side * 0.3, p + side * 0.3], 0.045, segments=5)
            chamfer_box(legs, d * 2.45 + Vector((0, 0, 3.72)), (1.3, 0.75, 0.12), 0.03)
    # Ascent module: a faceted cabin with a slanted front face, a rear bay, side tanks and antennas.
    cabin = Matrix.Translation((0, -0.2, 5.15)) @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Rotation(math.pi / 8, 4, "Z")
    lathe(module, [(0, -1.35), (1.3, -1.35), (1.3, 1.35), (0, 1.35)], 8, cabin)
    face = [(-1.15, 4.15), (1.15, 4.15), (1.45, 4.95), (1.05, 6.1), (-1.05, 6.1), (-1.45, 4.95)]
    slab(module, face, 0.55, Matrix.Translation((0, -1.25, 0)))
    for s in (-1, 1):
        tri = [(s * 0.22, 5.2), (s * 1.08, 5.2), (s * 0.3, 5.95)]
        slab(windows, tri if s > 0 else tri[::-1], 0.12, Matrix.Translation((0, -1.55, 0)))
    chamfer_box(module, (0, -1.56, 4.62), (0.78, 0.12, 0.7), 0.04)
    chamfer_box(module, (0, 1.25, 4.95), (2.3, 1.4, 1.55), 0.1)
    chamfer_box(module, (0, 0.2, 3.9), (2.9, 2.6, 0.4), 0.08)
    for s in (-1, 1):
        cyl(module, (s * 1.5, -0.9, 4.55), 0.42, 1.8, 14, direction=(0, 1, 0))
        for y in (-0.9, 0.9):
            chamfer_box(module, (s * 1.55, y, 6.05), (0.34, 0.34, 0.34), 0.05)
            cyl(legs, (s * 1.72, y, 6.05), 0.08, 0.25, 8, direction=(s, 0, 0))
    cyl(module, (0, -0.15, 6.35), 0.6, 0.45, 16)
    torus(module, M((0, -0.15, 6.8)), 0.55, 0.08, seg=16, tseg=5)
    sweep(module, [Vector((0.9, 0.7, 6.3)), Vector((1.35, 0.95, 7.4))], 0.08, segments=6)
    lathe(module, [(0, 0.0), (0.12, 0.0), (0.62, 0.26), (0.58, 0.31), (0, 0.12)], 16,
          Matrix.Translation((1.4, 1.0, 7.45)) @ align_z(Vector((0.4, 0.3, 1))))
    sweep(module, [Vector((-0.75, -0.6, 6.4)), Vector((-0.95, -0.75, 7.9))], 0.05, segments=5)
    blob(module, Vector((-0.95, -0.75, 7.95)), Vector((0.1, 0.1, 0.1)), subdivisions=1)
    return [closed(coll, "LanderFoil", foil, FOIL_GOLD, hard=True), closed(coll, "LanderModule", module, SILVER, hard=True),
            closed(coll, "LanderLegs", legs, GUNMETAL), closed(coll, "LanderWindows", windows, NAVY, hard=True)]


def wavy_plate(bm, points, faces, wave, near, far):
    """A thin solid laid on a waving cloth: (x, z) points with faces (index tuples); each vertex sits at
    y = wave(x, z) + near on one face and + far on the other (signs pick the side of the cloth)."""
    thin_solid(bm, [(x, wave(x, z) + near, z) for x, z in points], [(x, wave(x, z) + far, z) for x, z in points], faces)


def thin_solid(bm, near, far, faces):
    """A thin closed solid from two matching layers of points that share one face list (index tuples);
    walls close it along the open edges (the flag's emblem shapes)."""
    a = [bm.verts.new(p) for p in near]
    b = [bm.verts.new(p) for p in far]
    uses = {}
    for f in faces:
        bm.faces.new([a[i] for i in f])
        bm.faces.new([b[i] for i in reversed(f)])
        for i, j in zip(f, f[1:] + f[:1]):
            uses[(min(i, j), max(i, j))] = uses.get((min(i, j), max(i, j)), 0) + 1
    for f in faces:
        for i, j in zip(f, f[1:] + f[:1]):
            if uses[(min(i, j), max(i, j))] == 1:
                bm.faces.new((a[j], a[i], b[i], b[j]))


def disc_points(cx, cz, radius, rings=3, segments=24):
    """Points and faces of a flat disc as a polar grid (so it can bend with a cloth)."""
    points, faces = [(cx, cz)], []
    for r in range(1, rings + 1):
        for k in range(segments):
            a = 2 * math.pi * k / segments
            points.append((cx + radius * r / rings * math.cos(a), cz + radius * r / rings * math.sin(a)))
    for k in range(segments):
        faces.append((0, 1 + k, 1 + (k + 1) % segments))
    for r in range(1, rings):
        for k in range(segments):
            i0, i1 = 1 + (r - 1) * segments, 1 + r * segments
            faces.append((i0 + k, i1 + k, i1 + (k + 1) % segments, i0 + (k + 1) % segments))
    return points, faces


def build_astronaut_flag(coll):
    """A flag on a pole with a top bar, stiff and rippled, carrying a planet-and-orbit emblem on both
    sides; planted in a mound of moon rock with a trail of boot prints walking up to it."""
    rng = random.Random(23)
    pole, cloth_bm, emblem, base = (bmesh.new() for _ in range(4))
    px, py = -2.45, 0.25
    steps = [(1.55 - 0.62 * k * 0.93, -1.55 + 0.62 * k * 0.37, (-1) ** k) for k in range(5)]
    heading = math.atan2(0.37, -0.93)

    def mound(x, y, spread=1.0):
        q = max(0.0, 1 - (x / (3.75 * spread)) ** 2 - (y / (2.15 * spread)) ** 2)
        h = 1.0 * q ** 0.75 + 0.07 * q * noise.noise(Vector((x * 1.3, y * 1.3, 2.0)))
        for sx, sy, s in steps:
            u = (x - sx) * math.cos(heading) + (y - sy) * math.sin(heading)
            v = -(x - sx) * math.sin(heading) + (y - sy) * math.cos(heading) - s * 0.15
            if ((u - 0.12) / 0.3) ** 2 + (v / 0.15) ** 2 < 1 or ((u + 0.25) / 0.14) ** 2 + (v / 0.13) ** 2 < 1:
                h -= 0.08
        return max(h, 0.0)
    # A polar grid: dense enough for the prints, and its rim is a clean, gently wavy curve on z = 0.
    rings, segments = 14, 56
    centre = base.verts.new((0, 0, mound(0, 0)))
    loops = []
    for r in range(1, rings + 1):
        rho = r / rings
        loop = []
        for k in range(segments):
            a = 2 * math.pi * k / segments
            spread = 1 + 0.05 * math.sin(3 * a + 0.5) + 0.03 * math.sin(5 * a + 1.0)
            x, y = 3.75 * rho * spread * math.cos(a), 2.15 * rho * spread * math.sin(a)
            loop.append(base.verts.new((x, y, 0.0 if r == rings else mound(x, y, spread))))
        loops.append(loop)
    for k in range(segments):
        base.faces.new((centre, loops[0][k], loops[0][(k + 1) % segments]))
    for a, b in zip(loops, loops[1:]):
        for k in range(segments):
            base.faces.new((a[k], b[k], b[(k + 1) % segments], a[(k + 1) % segments]))
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.3, 0.3)
        rough_rock(base, (math.cos(a) * 3.55, math.sin(a) * 2.0, 0.12), Vector((0.32, 0.28, 0.24)) * rng.uniform(0.8, 1.4), rng,
                   subdivisions=1, jitter=0.25, floor=0.0)
    # Pole with a finial and the top bar that holds the flag out.
    cyl(pole, (px, py, 0.3), 0.11, 11.15, 12)
    blob(pole, Vector((px, py, 11.55)), Vector((0.2, 0.2, 0.2)), subdivisions=2)
    cyl(pole, (px, py, 11.05), 0.07, 5.8, 8, direction=(1, 0, 0))
    blob(pole, Vector((px + 5.82, py, 11.05)), Vector((0.11, 0.11, 0.11)), subdivisions=1)

    def wave(x, z):
        u = (x - px) / 5.6
        return py + 0.28 * u ** 0.6 * math.sin(u * 3 * math.pi + 0.3) + 0.04 * math.sin(z * 2.2)
    xs = [px + 0.12 + 5.58 * k / 16 for k in range(17)]
    thickness = 0.09
    cloth(cloth_bm, xs, lambda x: 7.45, 11.0, thickness, lambda x, z: wave(x, z), rows=10)
    # Emblem on both faces: a planet, a tilted orbit with a little moon, and three stars.
    cx, cz = px + 2.85, 9.2
    shapes = [disc_points(cx, cz, 0.8)]
    ring_points, ring_faces, count = [], [], 40
    for k in range(count):
        t = 2 * math.pi * k / count
        e = Vector((1.75 * math.cos(t), 1.02 * math.sin(t)))
        n = Vector((1.02 * math.cos(t), 1.75 * math.sin(t))).normalized()
        rot = Matrix.Rotation(-0.35, 2)
        for off in (-0.075, 0.075):
            p = rot @ (e + n * off)
            ring_points.append((cx + p.x, cz + p.y))
    for k in range(count):
        a, b = 2 * k, 2 * ((k + 1) % count)
        ring_faces.append((a, b, b + 1, a + 1))
    shapes.append((ring_points, ring_faces))
    moon = Matrix.Rotation(-0.35, 2) @ Vector((1.75 * math.cos(0.75), 1.02 * math.sin(0.75)))
    shapes.append(disc_points(cx + moon.x, cz + moon.y, 0.22, rings=1, segments=12))
    for sx, sz, size in ((-2.2, 1.15, 0.3), (2.15, -1.2, 0.26), (-2.05, -1.25, 0.2)):
        star = [(cx + sx, cz + sz)] + [(cx + sx + (size if k % 2 == 0 else size * 0.32) * math.cos(math.pi * k / 4 + math.pi / 2),
                                         cz + sz + (size if k % 2 == 0 else size * 0.32) * math.sin(math.pi * k / 4 + math.pi / 2)) for k in range(8)]
        shapes.append((star, [(0, 1 + k, 1 + (k + 1) % 8) for k in range(8)]))
    for points, faces in shapes:
        for s in (-1, 1):
            wavy_plate(emblem, points, faces, wave, s * (thickness / 2 - 0.01), s * (thickness / 2 + 0.035))
    settle([pole, cloth_bm, emblem, base])
    base_obj = make_object(coll, "FlagBase", base, MOON_GREY)
    smooth_by_angle(base_obj, 35)
    return [closed(coll, "FlagPole", pole, SILVER), closed(coll, "FlagCloth", cloth_bm, (0.15, 0.35, 0.8)),
            closed(coll, "FlagEmblem", emblem, WHITE), base_obj]


def build_moon_ridge(coll):
    """A rugged grey ridge: a height field over a jittered point set, triangulated (constrained
    Delaunay) inside a rounded footprint whose edge sits on z = 0. A crisp crest line runs along X with
    peaks and saddles; ridged noise cuts spurs into the flanks. Crater bowls with raised rims sit on the
    plain and lower slopes; each crater's floor and rim is cut out along a clean circle into the second
    mesh, so the two meshes share one seamless surface."""
    from mathutils import geometry
    rng = random.Random(5)
    rock, craters = bmesh.new(), bmesh.new()
    rx, ry = 9.6, 6.7
    # (x, y, radius, depth): mostly on the plain and lower slopes in front, two on the back slope.
    pits = [(-4.3, -2.9, 1.15, 0.5), (1.2, -3.6, 1.0, 0.45), (4.9, -2.6, 0.9, 0.4), (-1.4, -1.5, 0.75, 0.3), (-6.2, -0.8, 0.7, 0.3),
            (-2.4, 3.9, 0.72, 0.3), (5.4, 2.4, 0.7, 0.28)]

    def wobble(a):
        return 1 + 0.05 * math.sin(3 * a + 1.0) + 0.035 * math.sin(5 * a + 2.0)

    def rho(x, y):
        return math.hypot(x / rx, y / ry) / wobble(math.atan2(y / ry, x / rx))

    def height(x, y):
        crest_y = 0.9 + 0.6 * math.sin(0.35 * x + 0.5)
        crest = (4.2 + 3.4 * math.exp(-((x + 3.0) / 3.0) ** 2) + 2.4 * math.exp(-((x - 4.3) / 2.4) ** 2)
                 + 0.6 * (1 - abs(noise.noise(Vector((x * 0.45, 0.0, 5.0)))))) * max(0.0, 1 - (x / 9.9) ** 4)
        d = (y - crest_y) / (6.0 if y < crest_y else 4.6)
        soft = math.sqrt(d * d + 0.015) - math.sqrt(0.015)  # a slightly rounded crest line
        h = crest * max(0.0, 1 - soft) ** 1.35
        ridged = 1 - abs(noise.noise(Vector((x * 0.42, y * 0.42, 3.7))))
        h = h * (0.8 + 0.32 * ridged) + 0.3 + 0.15 * noise.noise(Vector((x * 0.9, y * 0.9, 1.1)))
        for cx, cy, r, depth in pits:
            dist = math.hypot(x - cx, y - cy) / r
            if dist < 1:
                h -= depth * (1 - dist * dist)
            h += depth * 0.55 * math.exp(-((dist - 1.0) / 0.28) ** 2)
        s = max(0.0, min(1.0, (1 - rho(x, y)) / 0.26))  # the edge slopes smoothly down to z = 0
        return max(0.0, h) * s * s * (3 - 2 * s)
    # Points: the footprint outline, rings around and inside every crater, and a jittered grid.
    outline = [Vector((rx * wobble(a) * math.cos(a), ry * wobble(a) * math.sin(a))) for a in [2 * math.pi * k / 120 for k in range(120)]]
    coords, edges = list(outline), []
    for cx, cy, r, _ in pits:
        for f, n in ((1.3, 32), (1.12, 32), (0.95, 28), (0.72, 22), (0.45, 14), (0.2, 7)):
            start = len(coords)
            coords += [Vector((cx + f * r * math.cos(2 * math.pi * (k + 0.5 * (f < 1)) / n), cy + f * r * math.sin(2 * math.pi * (k + 0.5 * (f < 1)) / n)))
                       for k in range(n)]
            if f == 1.3:
                edges += [(start + k, start + (k + 1) % n) for k in range(n)]
        coords.append(Vector((cx, cy)))
    spacing = 0.38
    for i in range(-27, 28):
        for j in range(-19, 20):
            p = Vector((i * spacing + rng.uniform(-0.12, 0.12), j * spacing + rng.uniform(-0.12, 0.12)))
            if rho(p.x, p.y) < 0.975 and all(math.hypot(p.x - cx, p.y - cy) > r * 1.3 + spacing * 0.4 for cx, cy, r, _ in pits):
                coords.append(p)
    points, _, triangles_2d, _, _, _ = geometry.delaunay_2d_cdt(coords, edges, [list(range(len(outline)))], 1, 1e-6)
    made = ({}, {})
    for tri in triangles_2d:
        middle = sum((points[i] for i in tri), Vector((0, 0))) / 3
        which = 1 if any(math.hypot(middle.x - cx, middle.y - cy) < r * 1.3 for cx, cy, r, _ in pits) else 0
        target = (rock, craters)[which]
        verts = []
        for i in tri:
            if i not in made[which]:
                made[which][i] = target.verts.new((points[i].x, points[i].y, height(points[i].x, points[i].y)))
            verts.append(made[which][i])
        a, b, c = (points[i] for i in tri)
        if (b - a).cross(c - a) < 0:  # wind every triangle counter-clockwise from above (normals up)
            verts.reverse()
        target.faces.new(verts)
    settle([rock, craters])
    rock_obj = make_object(coll, "MoonRidgeRock", rock, MOON_GREY)
    smooth_by_angle(rock_obj, 35)
    crater_obj = make_object(coll, "MoonRidgeCraters", craters, (0.42, 0.42, 0.46))
    smooth_by_angle(crater_obj, 35)
    return [rock_obj, crater_obj]


# ---------- 9. Red Planet Outpost (HabitatPod is reused there, tinted) ----------

def build_mars_rover(coll):
    """A six-wheeled rocker-bogie rover (front -Y): a box body under a solar deck with wings, a mast
    with a two-eyed camera head, a folded robot arm at the front and a high-gain dish."""
    body, wheels, deck, mast, accent = (bmesh.new() for _ in range(5))
    wr, ww = 0.8, 0.64
    for side in (-1, 1):
        x = side * 2.3
        for y in (-2.9, 0.0, 2.9):
            c = Vector((x, y, wr))
            lathe(wheels, [(0, -ww / 2), (wr * 0.72, -ww / 2), (wr * 0.94, -ww / 2 + 0.05), (wr, -ww / 2 + 0.13),
                           (wr, ww / 2 - 0.13), (wr * 0.94, ww / 2 - 0.05), (wr * 0.72, ww / 2), (0, ww / 2)], 20,
                  Matrix.Translation(c) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
            for k in range(10):
                a = 2 * math.pi * k / 10
                box(wheels, c + Vector((0, math.cos(a) * wr, math.sin(a) * wr)), (ww * 0.8, 0.12, 0.12), rotation=(a, 0, 0))
            cyl(accent, c + Vector((side * (ww / 2 - 0.04), 0, 0)), 0.3, 0.1, 16, direction=(side, 0, 0))
            cyl(mast, (side * 1.7, y, wr), 0.12, 0.42, 8, direction=(side, 0, 0))
        # Rocker (body pivot to the rear wheel and the bogie) and bogie (front and middle wheels).
        bx = side * 1.75
        pivot, rear, bogie = Vector((bx, 0.55, 2.05)), Vector((bx, 2.9, 1.6)), Vector((bx, -1.45, 1.75))
        for a, b in ((pivot, rear), (pivot, bogie), (rear, Vector((bx, 2.9, wr))), (bogie, Vector((bx, -2.9, 1.5))),
                     (bogie, Vector((bx, 0.0, 1.5))), (Vector((bx, -2.9, 1.5)), Vector((bx, -2.9, wr))),
                     (Vector((bx, 0.0, 1.5)), Vector((bx, 0.0, wr)))):
            beam(mast, a, b, 0.2, 0.26)
        for p in (pivot, bogie):
            cyl(accent, p - Vector((side * 0.16, 0, 0)), 0.2, 0.32, 12, direction=(side, 0, 0))
    chamfer_box(body, (0, 0.25, 2.35), (2.7, 4.6, 1.3), 0.12)
    for side in (-1, 1):
        chamfer_box(accent, (side * 1.36, 0.25, 2.35), (0.06, 3.9, 0.95), 0.02)
    # Solar deck with white cell lines, and two side wings.
    chamfer_box(deck, (0, 0.35, 3.15), (3.4, 5.6, 0.12), 0.03)
    for side in (-1, 1):
        chamfer_box(deck, (side * 2.3, 0.6, 3.1), (1.25, 4.4, 0.1), 0.03)
        box(body, (side * 2.9, 0.6, 3.12), (0.08, 4.4, 0.14))
        box(body, (side * 1.71, 0.35, 3.17), (0.08, 5.6, 0.14))
    for x in (-0.57, 0.57):
        box(body, (x, 0.35, 3.18), (0.06, 5.6, 0.12))
    for y in (-2.4, -1.2, 0.0, 1.2, 2.4):
        box(body, (0, y + 0.35, 3.18), (3.4, 0.06, 0.12))
    for side in (-1, 1):
        for y in (-1.6, -0.5, 0.6, 1.7, 2.8):
            box(body, (side * 2.3, y, 3.13), (1.25, 0.06, 0.12))
    # Mast and camera head with two lens eyes (the lenses are deck glass).
    cyl(mast, (-0.85, -1.95, 3.2), 0.14, 2.0, 10)
    chamfer_box(body, (-0.85, -2.0, 5.45), (1.15, 0.6, 0.55), 0.1)
    for dx in (-0.28, 0.28):
        cyl(accent, (-0.85 + dx, -2.28, 5.45), 0.2, 0.08, 16, direction=(0, -1, 0))
        cyl(deck, (-0.85 + dx, -2.33, 5.45), 0.14, 0.08, 16, direction=(0, -1, 0))
    # High-gain dish and a whip antenna at the back.
    cyl(mast, (0.95, 1.7, 3.2), 0.08, 0.55, 8)
    lathe(accent, [(0, 0.0), (0.14, 0.0), (0.62, 0.24), (0.58, 0.3), (0, 0.12)], 20,
          Matrix.Translation((0.95, 1.7, 3.75)) @ align_z(Vector((0, 0.45, 1))))
    cyl(mast, (1.25, 2.55, 3.2), 0.05, 1.3, 6)
    # Robot arm folded in front of the body, ending in a tool turret.
    shoulder, elbow, wrist = Vector((0.6, -2.0, 2.15)), Vector((0.75, -2.95, 2.75)), Vector((0.3, -3.45, 1.95))
    sweep(mast, [shoulder, elbow], 0.13, segments=8)
    sweep(mast, [elbow, wrist], 0.11, segments=8)
    for p in (shoulder, elbow):
        blob(accent, p, Vector((0.2, 0.2, 0.2)), subdivisions=2)
    cyl(accent, wrist + Vector((0, 0, 0.12)), 0.3, 0.32, 12, direction=(0, 0, -1))
    cyl(mast, wrist - Vector((0, 0, 0.2)), 0.07, 0.35, 8, direction=(0, 0, -1))
    settle([body, wheels, deck, mast, accent])
    return [closed(coll, "RoverBody", body, WHITE, hard=True), closed(coll, "RoverWheels", wheels, GUNMETAL),
            closed(coll, "RoverDeck", deck, SOLAR_BLUE, hard=True), closed(coll, "RoverMast", mast, SILVER),
            closed(coll, "RoverAccent", accent, FOIL_GOLD)]


def build_terraformer(coll):
    """A tapering octagonal atmosphere processor: radiator fins, a recessed glowing window band with
    mullions, a glowing exhaust crown, and four vents piped into its base."""
    body, core, fins, base = (bmesh.new() for _ in range(4))
    octo = Matrix.Rotation(math.pi / 8, 4, "Z")  # flat sides face +-X, +-Y and the diagonals
    lathe(base, [(0, 0), (4.6, 0), (4.6, 0.45), (4.3, 0.65), (0, 0.65)], 8, octo)
    lathe(base, [(0, 0.6), (3.7, 0.6), (3.7, 1.0), (3.5, 1.25), (0, 1.25)], 8, octo)
    lower = [(0, 1.2), (3.0, 1.2), (3.0, 1.9), (2.72, 2.3), (2.45, 9.0), (2.65, 9.12), (2.65, 9.3), (0, 9.3)]
    upper = [(0, 11.7), (2.45, 11.7), (2.45, 11.9), (2.2, 12.15), (1.75, 16.2), (2.08, 16.5), (2.08, 16.9), (1.3, 17.3), (0, 17.3)]
    lathe(body, lower, 8, octo)
    lathe(body, upper, 8, octo)
    # The glowing core band: recessed between the two body sections, crossed by mullions at the corners.
    lathe(core, [(0, 9.2), (2.3, 9.2), (2.3, 11.8), (0, 11.8)], 8, octo)
    for k in range(8):
        a = math.pi / 8 + k * math.pi / 4
        box(body, (2.42 * math.cos(a), 2.42 * math.sin(a), 10.5), (0.26, 0.26, 2.5), rotation=(0, 0, a))
    for z in (5.4, 7.4):
        band(fins, lower[3:5], z, z + 0.24, out=0.07, depth=0.12, segments=8, matrix=octo)
    band(fins, upper[3:5], 13.6, 13.84, out=0.07, depth=0.12, segments=8, matrix=octo)
    lathe(core, [(1.88, 15.3), (1.95, 15.3), (1.95, 15.65), (1.88, 15.65), (1.88, 15.3)], 8, octo)
    # Exhaust stack with a glowing ring and a glowing mouth.
    lathe(body, [(0, 17.2), (0.95, 17.2), (0.85, 18.85), (1.02, 19.05), (1.02, 19.3), (0, 19.3)], 16)
    lathe(core, [(0, 19.25), (0.86, 19.25), (0.86, 19.42), (0, 19.42)], 16)
    lathe(core, [(0.86, 18.2), (0.95, 18.2), (0.95, 18.5), (0.86, 18.5), (0.86, 18.2)], 16)
    # Radiator fins on the corners of the lower body, smaller ones above the window band.
    fin = [(2.3, 2.5), (3.6, 2.5), (3.6, 3.9), (3.3, 4.2), (3.3, 6.4), (3.12, 6.7), (3.12, 8.3), (2.3, 8.9)]
    for k in range(8):
        slab(fins, fin, 0.24, Matrix.Rotation(math.pi / 8 + k * math.pi / 4, 4, "Z"))
    top_fin = [(1.9, 12.3), (2.8, 12.3), (2.8, 13.1), (2.3, 15.0), (1.85, 15.2)]
    for k in range(4):
        slab(fins, top_fin, 0.2, Matrix.Rotation(math.pi / 8 + math.pi / 4 + k * math.pi / 2, 4, "Z"))
    # Vents on the plinth between the fins (one faces -Y), each piped into the tower.
    for k in range(4):
        a = k * math.pi / 2
        out = Vector((math.cos(a), math.sin(a), 0))
        rot = Matrix.Rotation(a, 3, "Z")
        chamfer_box(base, out * 3.85 + Vector((0, 0, 1.75)), (1.0, 1.5, 1.1), 0.08, rot)
        box(core, out * 4.36 + Vector((0, 0, 1.75)), (0.06, 1.15, 0.7), rotation=(0, 0, a))
        for dz in (-0.2, 0.0, 0.2):
            box(base, out * 4.4 + Vector((0, 0, 1.75 + dz)), (0.08, 1.2, 0.07), rotation=(0, 0, a))
        sweep(base, curve(out * 3.85 + Vector((0, 0, 2.2)), out * 3.75 + Vector((0, 0, 3.4)), out * 2.55 + Vector((0, 0, 3.6)), 10), 0.22,
              segments=10)
        torus(base, Matrix.Translation(out * 3.82 + Vector((0, 0, 2.55))) @ align_z(Vector((0, 0, 1))), 0.27, 0.06, seg=12, tseg=4)
    return [closed(coll, "TerraformerBody", body, (0.78, 0.74, 0.7), hard=True), closed(coll, "TerraformerCore", core, (1.0, 0.55, 0.2), hard=True),
            closed(coll, "TerraformerFins", fins, GUNMETAL, hard=True), closed(coll, "TerraformerBase", base, (0.35, 0.33, 0.32), hard=True)]


# ---------- 10. Quantum Singularity ----------

def build_energy_ring(coll):
    """A ring gate standing in the XZ plane (open toward +-Y) in a cradle on a stepped base: clamps
    round the frame, a glowing inner ring, glowing lines on both faces and orbs floating around it."""
    frame, glow, base = bmesh.new(), bmesh.new(), bmesh.new()
    zc, radius = 7.55, 5.7
    standing = Matrix.Translation((0, 0, zc)) @ Matrix.Rotation(math.pi / 2, 4, "X")  # local XY -> world XZ
    ring_profile(frame, standing, radius, [(-0.5, -0.6), (-0.35, -0.75), (0.35, -0.75), (0.5, -0.6), (0.5, 0.6), (0.35, 0.75),
                                           (-0.35, 0.75), (-0.5, 0.6)], 64)
    for k in range(8):
        a = math.pi / 8 + k * math.pi / 4
        spoke = standing @ Matrix.Rotation(a, 4, "Z")
        obox(frame, spoke, (radius, 0, 0), (1.45, 0.75, 1.9), chamfer=0.1)
        for side in (-1, 1):
            obox(glow, spoke, (radius + 0.1, 0, side * 0.97), (0.75, 0.3, 0.06))
    torus(glow, standing, radius - 0.62, 0.2, seg=64, tseg=8)
    for side in (-1, 1):
        ring_profile(glow, standing, radius, [(-0.1, side * 0.73), (0.1, side * 0.73), (0.1, side * 0.79), (-0.1, side * 0.79)], 64)
    # Cradle hugging the bottom of the ring, two feet and a stepped base.
    ring_profile(base, standing, radius, [(0.45, -0.95), (1.3, -0.95), (1.3, 0.95), (0.45, 0.95)], 16,
                 a0=math.radians(232), a1=math.radians(308))
    chamfer_box(base, (0, 0, 0.35), (9.6, 4.2, 0.7), 0.12)
    chamfer_box(base, (0, 0, 0.85), (7.6, 3.2, 0.35), 0.08)
    for side in (-1, 1):
        chamfer_box(base, (side * 3.95, 0, 1.5), (1.3, 2.0, 1.6), 0.1)
        box(glow, (side * 3.95, -1.02, 1.5), (0.7, 0.06, 0.18))
        box(glow, (side * 3.95, 1.02, 1.5), (0.7, 0.06, 0.18))
    for k, (deg, y) in enumerate(((18, -0.7), (58, 0.6), (102, -0.5), (140, 0.7), (172, -0.6), (-10, 0.5))):
        a = math.radians(deg)
        blob(glow, Vector((math.cos(a) * 6.95, y, zc + math.sin(a) * 6.95)), Vector((0.32, 0.32, 0.32)), subdivisions=2)
    settle([frame, glow, base])
    return [closed(coll, "EnergyRingFrame", frame, GUNMETAL, hard=True), closed(coll, "EnergyRingGlow", glow, NEON_CYAN),
            closed(coll, "EnergyRingBase", base, NAVY, hard=True)]


def build_quantum_shard(coll):
    """A cluster of long faceted crystals growing out of a small jagged rock, circled by a thin tilted
    ring. It floats: its lowest point (the rock's underside) rests on z = 0 and RunwayDecor lifts it."""
    rng = random.Random(31)
    crystal, ring, rock = bmesh.new(), bmesh.new(), bmesh.new()
    rough_rock(rock, (0, 0, 2.0), (1.9, 1.7, 1.0), rng, subdivisions=2, jitter=0.2, floor=None)
    for base, direction, length, radius in (((0.1, -0.1, 1.5), (0.05, 0.1, -1), 1.6, 0.85), ((0.8, 0.5, 1.6), (0.35, 0.3, -1), 1.1, 0.5),
                                            ((-0.8, -0.3, 1.6), (-0.4, -0.2, -1), 0.9, 0.45)):
        hex_crystal(rock, Vector(base), Vector(direction), length, radius, sides=5)
    for base, direction, length, radius in (((0.0, 0.0, 2.3), (0.06, -0.04, 1), 10.1, 0.95), ((0.85, 0.3, 2.4), (0.45, 0.15, 1), 6.0, 0.55),
                                            ((-0.8, 0.5, 2.3), (-0.5, 0.25, 1), 5.2, 0.5), ((0.2, -0.85, 2.3), (0.15, -0.55, 1), 4.6, 0.45),
                                            ((-0.45, -0.6, 2.4), (-0.4, -0.4, 1), 3.4, 0.38), ((0.6, 0.9, 2.4), (0.3, 0.6, 1), 3.0, 0.33),
                                            ((-1.0, -0.1, 2.2), (-0.9, -0.1, 0.55), 2.3, 0.3), ((1.1, -0.4, 2.1), (0.9, -0.3, 0.5), 1.9, 0.28)):
        hex_crystal(crystal, Vector(base), Vector(direction), length, radius)
    torus(ring, M((0, 0, 6.3), (0.4, 0.12, 0)), 3.5, 0.14, seg=64, tseg=8)
    settle([crystal, ring, rock])
    return [closed(coll, "ShardCrystal", crystal, VIOLET, hard=True), closed(coll, "ShardRing", ring, NEON_CYAN),
            closed(coll, "ShardRock", rock, GUNMETAL, hard=True)]


def build_rift_rock(coll):
    """A floating island chunk: a flat-ish top over a jagged underside that tapers to hanging spikes,
    glowing cracks running down its sides and across the top, and crystals on top. Its lowest point
    rests on z = 0 (RunwayDecor lifts it)."""
    from mathutils.bvhtree import BVHTree
    rng = random.Random(77)
    stone, glow, crystals = bmesh.new(), bmesh.new(), bmesh.new()
    top = 8.6

    def reach(a):
        """The island's outline radius at angle a."""
        base = 1 / math.sqrt((math.cos(a) / 6.6) ** 2 + (math.sin(a) / 5.6) ** 2)
        return base * (1 + 0.08 * math.sin(3 * a + 0.7) + 0.05 * math.sin(7 * a + 2.0))

    def bump(a, z):
        return noise.noise(Vector((math.cos(a) * 1.6, math.sin(a) * 1.6, z * 0.45)))
    # (radius fraction, z): top surface from the centre out, the rim, then a faceted underside.
    profile = [(0.0, top + 0.35), (0.3, top + 0.3), (0.6, top + 0.18), (0.85, top + 0.02), (0.97, top - 0.15), (1.0, top - 0.6),
               (0.94, top - 1.6), (0.8, top - 2.9), (0.62, top - 4.1), (0.45, top - 5.2), (0.28, top - 6.2), (0.12, top - 7.1), (0.0, top - 7.6)]
    segments = 28
    rings = []
    for f, z in profile:
        if f == 0.0:
            rings.append([stone.verts.new((0, 0, z))])
            continue
        ring = []
        for k in range(segments):
            a = 2 * math.pi * k / segments
            under = z < top - 1
            r = reach(a) * f * (1 + (rng.uniform(-0.16, 0.16) if under else 0.03 * bump(a, z)))
            zz = z + (rng.uniform(-0.3, 0.3) if under else 0.06 * bump(a + 2.0, z))
            ring.append(stone.verts.new((r * math.cos(a), r * math.sin(a), zz)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(segments):
            j = (k + 1) % segments
            if len(a) == 1:
                stone.faces.new((a[0], b[k], b[j]))
            elif len(b) == 1:
                stone.faces.new((a[k], a[j], b[0]))
            else:
                stone.faces.new((a[k], a[j], b[j], b[k]))
    recalc_normals(stone)
    tree = BVHTree.FromBMesh(stone)

    def on_side(a, z):
        """Where a ray toward the axis at height z first meets the rock's side, lifted off it a little."""
        hit, normal, _, _ = tree.ray_cast(Vector((math.cos(a) * 12, math.sin(a) * 12, z)), Vector((-math.cos(a), -math.sin(a), 0)), 20)
        return hit + normal * 0.07 if hit else None

    def on_top(x, y):
        hit, normal, _, _ = tree.ray_cast(Vector((x, y, top + 3)), Vector((0, 0, -1)), 6)
        return hit + normal * 0.06 if hit else None

    def stalactite(root, direction, length, radius):
        """A five-sided rock spike tapering to a point, its root sunk into the underside."""
        lathe(stone, [(0, -0.6), (radius, -0.6), (radius * 0.92, 0.0), (radius * 0.5, length * 0.5), (0, length)], 5,
              Matrix.Translation(root) @ align_z(direction) @ Matrix.Rotation(rng.uniform(0, 1.2), 4, "Z"))
    # Hanging spikes from the underside make it jagged; the longest hangs from the bottom tip.
    for k in range(11):
        a = 2 * math.pi * k / 11 + rng.uniform(-0.2, 0.2)
        z = rng.uniform(top - 6.0, top - 2.6)
        root = on_side(a, z)
        if root:
            depth = (top - z) / 7.6
            stalactite(root - Vector((math.cos(a), math.sin(a), 0)) * 0.2, Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -1)),
                       rng.uniform(1.6, 2.6) * (0.7 + depth), rng.uniform(0.75, 1.1) * (1.25 - depth * 0.5))
    stalactite(Vector((0.1, -0.1, top - 7.2)), Vector((0.06, -0.04, -1)), 2.6, 1.0)
    for a in (0.8, 2.9, 4.9):
        stalactite(Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, top - 6.7)), Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, -1)), 1.7, 0.7)
    # Glowing cracks zig-zagging down the sides and across the top.
    for a0 in (0.35, 1.9, 3.3, 4.6, 5.6):
        path, a = [], a0
        for n in range(9):
            p = on_side(a, top - 0.75 - n * 0.6)
            if p:
                path.append(p)
            a += (0.08 if n % 2 == 0 else -0.07) * rng.uniform(0.6, 1.4)
        sweep(glow, path, 0.12, segments=5, radius_end=0.05)
    for a0, a1 in ((0.2, 2.6), (3.6, 5.2)):
        path = []
        for n in range(11):
            t = n / 10
            a = a0 + (a1 - a0) * t + (0.05 if n % 2 else -0.05)
            r = reach(a) * (0.9 - 0.5 * math.sin(math.pi * t))
            p = on_top(r * math.cos(a), r * math.sin(a))
            if p:
                path.append(p)
        sweep(glow, path, 0.1, segments=5)
    for base, direction, length, radius in (((2.1, 1.0, top), (0.1, 0.05, 1), 2.4, 0.45), ((2.6, 0.5, top), (0.45, -0.2, 1), 1.7, 0.34),
                                            ((1.6, 1.6, top), (-0.3, 0.4, 1), 1.5, 0.3), ((2.5, 1.5, top), (0.35, 0.45, 1), 1.1, 0.24),
                                            ((-2.6, -1.4, top), (-0.15, -0.1, 1), 1.9, 0.38), ((-2.1, -1.9, top), (0.3, -0.35, 1), 1.2, 0.27)):
        hex_crystal(crystals, Vector(base) - Vector((0, 0, 0.3)), Vector(direction), length * 1.35 + 0.3, radius * 1.3)
    settle([stone, glow, crystals])
    return [closed(coll, "RiftRockStone", stone, (0.33, 0.28, 0.4), hard=True), closed(coll, "RiftRockGlow", glow, NEON_PINK),
            closed(coll, "RiftRockCrystals", crystals, NEON_CYAN, hard=True)]


def build_black_hole(coll):
    """A black sphere inside a disc of glowing rings with gaps, tilted 17 degrees toward the viewer; the
    lensed far side of the disc stands up round the sphere as a vertical ring, and a thin photon ring
    hugs the sphere's outline. The front faces -Y. Unlike every other model, its origin is its centre."""
    core, disc, halo = bmesh.new(), bmesh.new(), bmesh.new()
    radius = 3.0
    bmesh.ops.create_uvsphere(core, u_segments=48, v_segments=24, radius=radius)
    tilt = Matrix.Rotation(math.radians(17), 4, "X")
    for r0, r1, t in ((3.85, 5.1, 0.14), (5.4, 6.65, 0.11), (6.95, 8.05, 0.09), (8.35, 9.2, 0.07), (9.45, 9.85, 0.05)):
        w = (r1 - r0) / 2
        ring_profile(disc, tilt, (r0 + r1) / 2, [(-w, -t), (w, -t * 0.5), (w, t * 0.5), (-w, t)], 96)
    facing = Matrix.Rotation(math.pi / 2, 4, "X")  # rings in the XZ plane, facing +-Y
    ring_profile(disc, Matrix.Translation((0, 0.5, 0)) @ facing, 4.05, [(-0.55, -0.05), (0.55, -0.025), (0.55, 0.025), (-0.55, 0.05)], 96)
    torus(halo, facing, radius * 1.08, 0.14, seg=96, tseg=8)
    return [closed(coll, "BlackHoleCore", core, (0.02, 0.02, 0.03)), closed(coll, "BlackHoleDisc", disc, (1.0, 0.62, 0.25), hard=True),
            closed(coll, "BlackHoleHalo", halo, (1.0, 0.95, 0.85))]


BUILDERS = [
    ("DataCube", build_data_cube), ("VoxelTree", build_voxel_tree), ("GlitchPillar", build_glitch_pillar),
    ("VoxelPeak", build_voxel_peak), ("VoxelBush", build_voxel_bush),
    ("Rocket", build_rocket), ("RadarDish", build_radar_dish), ("FuelTank", build_fuel_tank),
    ("LaunchTower", build_launch_tower), ("CargoCrate", build_cargo_crate),
    ("HabitatPod", build_habitat_pod), ("LunarLander", build_lunar_lander), ("AstronautFlag", build_astronaut_flag),
    ("MoonRidge", build_moon_ridge), ("MarsRover", build_mars_rover), ("Terraformer", build_terraformer),
    ("EnergyRing", build_energy_ring), ("QuantumShard", build_quantum_shard), ("RiftRock", build_rift_rock),
    ("BlackHole", build_black_hole),
]


def clear_collection(name):
    """Our collection, emptied of its old objects and their meshes (no other collection is touched)."""
    coll = bpy.data.collections.get(name)
    if not coll:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
    for obj in list(coll.objects):
        mesh = obj.data if obj.type == "MESH" else None
        bpy.data.objects.remove(obj, do_unlink=True)
        if mesh is not None and mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    return coll


def mesh_bounds(objects):
    """Min and max corners of objects' vertices in their own (unmoved) space."""
    points = [v.co for obj in objects for v in obj.data.vertices]
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return lo, hi


def build_and_export(only=None, export=True):
    coll = clear_collection(COLLECTION)
    layer = bpy.context.view_layer.layer_collection.children.get(COLLECTION)
    if layer:
        layer.exclude = False
    # Blender is shared: the smoothing and export operators change the selection, so put it back after.
    selected = list(bpy.context.selected_objects)
    active = bpy.context.view_layer.objects.active
    objects = []
    try:
        manifest, problems = {}, []
        chosen = [(prop, builder) for prop, builder in BUILDERS if not only or prop in only]
        for slot, (prop, builder) in enumerate(chosen):
            group = builder(coll)
            lo, hi = mesh_bounds(group)
            size = hi - lo
            tris = sum(triangles(o) for o in group)
            print("%-14s %6d tris  size %5.1f x %5.1f x %5.1f  centre (%.2f, %.2f)  z %.2f..%.2f" % (
                prop, tris, size.x, size.y, size.z, (lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z, hi.z))
            if max(size) > MAX_SIZE:
                problems.append("%s is %.2f units on its longest axis" % (prop, max(size)))
            for obj in group:
                if "." in obj.name:
                    problems.append("%s got a suffixed name (another object already uses the name)" % obj.name)
            for obj in group:
                obj.location.x += (slot % 5) * 26.0
                obj.location.y += (slot // 5) * 30.0
                objects.append(obj)
            manifest[prop] = [o.name for o in group]
        print("triangles:", sum(triangles(o) for o in objects))
        for problem in problems:
            print("PROBLEM:", problem)
        if only or not export:
            return objects
        if problems:
            print("NOT EXPORTED: fix the problems above first")
            return objects
        for other in bpy.context.selected_objects:
            other.select_set(False)
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        os.makedirs(os.path.dirname(EXPORT_PATH), exist_ok=True)
        bpy.ops.export_scene.fbx(filepath=EXPORT_PATH, use_selection=True, object_types={"MESH"},
                                 apply_unit_scale=True, add_leaf_bones=False, bake_anim=False)
        with open(MANIFEST_PATH, "w", encoding="utf-8") as handle:
            json.dump(manifest, handle, indent=1)
        print("exported", EXPORT_PATH, "with", len(manifest), "models")
        return objects
    finally:
        for obj in objects:
            obj.select_set(False)
        for other in selected:
            try:
                other.select_set(True)
            except (ReferenceError, RuntimeError):
                pass  # removed meanwhile (e.g. our own old objects), or hidden
        try:
            bpy.context.view_layer.objects.active = active
        except (ReferenceError, RuntimeError):
            pass


build_and_export(globals().get("ONLY"), globals().get("EXPORT", True))
