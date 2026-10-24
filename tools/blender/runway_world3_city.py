# World 3 (Future World) runway props, city half: themed sections 1-5 in one batch.
#   Solar Suburbs:       EcoHouse, WindTurbine, SolarTree      (WindTurbine doubles as the wind-farm backdrop)
#   Maglev Highway:      HoverCar, MaglevPylon, HoloSign       backdrop Viaduct
#   Skyline Metropolis:  HoloBillboard, NeoLamp                backdrop Skyscraper
#   Robo Assembly Line:  RobotArm, Conveyor, RobotUnit         backdrop MegaFactory
#   Biodome Gardens:     Biodome, AlienPlant                   (Biodome doubles as the big-domes backdrop)
#   Filler for all five: Planter
# Same conventions as runway_world2.py, whose helper half this script runs so the helpers stay shared:
# run inside Blender (e.g. via MCP); one mesh per colour role, named <Template><Part>; each model
# rests on z = 0 with its footprint centred on the origin; props with a front face -Y (RunwayDecor
# turns them to the tee). Every mesh stays under 20 units so Roblox's 100x FBX import stays below
# its 2048-stud part limit; backdrops are scaled up in RunwayDecor. A manifest (template -> mesh
# names) is written beside the FBX for grouping after import. Preview colours only: RunwayDecor
# tints every part in Roblox. Set EXPORT = False (and optionally ONLY = [template names]) before
# exec() to build without exporting.
import bpy, bmesh, math, os, random, json
from mathutils import Vector, Matrix, Euler, noise

RUNWAY_WORLD2 = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\runway_world2.py"
_source = open(RUNWAY_WORLD2, encoding="utf-8").read()
_marker = "# ---------- 1. Prehistoric Valley ----------"
assert _marker in _source, "runway_world2.py layout changed"
exec(_source.partition(_marker)[0])

COLLECTION = "RunwayWorld3City"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayWorld3City.fbx"
MANIFEST_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayWorld3City.json"

WHITE = (0.92, 0.93, 0.95)
PALE = (0.74, 0.77, 0.82)
CONCRETE = (0.58, 0.58, 0.6)
GRAPHITE = (0.2, 0.21, 0.24)
ROOF = (0.33, 0.35, 0.39)
SOLAR = (0.06, 0.12, 0.36)
GLASS = (0.45, 0.74, 0.92)
WARM_WOOD = (0.72, 0.46, 0.25)
GRASS = (0.38, 0.68, 0.3)
LEAF = (0.2, 0.52, 0.28)
ORANGE = (1.0, 0.5, 0.1)
HAZARD = (1.0, 0.8, 0.1)
MAGENTA = (1.0, 0.3, 0.8)
LIME = (0.6, 1.0, 0.3)

YZ = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # local (a, b, c) -> world (c, a, b)
XZ = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # local (a, b, c) -> world (a, c, b)


# ---------- extra helpers for hard-surface, sleek future shapes ----------

def rounded_rect(w, d, r, seg=3):
    """Counter-clockwise (x, y) outline of a centred w x d rectangle with corner radius r (seg 0: sharp corners)."""
    if seg == 0:
        return [(w / 2, d / 2), (-w / 2, d / 2), (-w / 2, -d / 2), (w / 2, -d / 2)]
    r = max(0.01, min(r, w / 2 - 0.005, d / 2 - 0.005))
    points = []
    for k, (cx, cy) in enumerate(((w / 2 - r, d / 2 - r), (-w / 2 + r, d / 2 - r), (-w / 2 + r, -d / 2 + r), (w / 2 - r, -d / 2 + r))):
        for i in range(seg + 1):
            a = math.pi / 2 * (k + i / seg)
            points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return points


def rounded_block(bm, size, matrix=Matrix(), corner=0.3, edge=0.1, corner_seg=3, edge_seg=2, taper=1.0):
    """A box centred on the matrix origin with rounded vertical corners and rounded top/bottom edges.
    taper scales the top outline against the bottom one (1 keeps the sides straight)."""
    w, d, h = size
    edge = max(0.0, min(edge, h / 2 - 0.001, w / 2 - 0.01, d / 2 - 0.01))
    if edge > 0 and edge_seg > 0:
        levels = [(-h / 2 + edge - edge * math.sin(math.pi / 2 * k / edge_seg), edge * (1 - math.cos(math.pi / 2 * k / edge_seg)))
                  for k in range(edge_seg, -1, -1)]
        levels += [(h / 2 - edge + edge * math.sin(math.pi / 2 * k / edge_seg), edge * (1 - math.cos(math.pi / 2 * k / edge_seg)))
                   for k in range(edge_seg + 1)]
    else:
        levels = [(-h / 2, 0.0), (h / 2, 0.0)]
    sections = []
    for z, inset in levels:
        s = 1 + (taper - 1) * (z + h / 2) / h
        outline = rounded_rect(w * s - 2 * inset, d * s - 2 * inset, corner * s - inset, corner_seg)
        sections.append([matrix @ Vector((x, y, z)) for x, y in outline])
    loft(bm, sections)


def panel(bm, center, w, h, t, corner=0.4, edge=0.04, rotation=(0, 0, 0), **options):
    """A rounded-corner panel standing in the XZ plane: w wide, h tall, t thick along Y."""
    rounded_block(bm, (w, h, t), M(center, rotation) @ Matrix.Rotation(math.pi / 2, 4, "X"), corner=corner, edge=edge, **options)


def mbox(bm, matrix, size):
    """A box of the given size centred on, and oriented by, the matrix."""
    cube = bmesh.ops.create_cube(bm, size=1.0)
    for v in cube["verts"]:
        v.co = matrix @ Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))


def bar(bm, p0, p1, width, depth, normal=(0, -1, 0)):
    """A straight box bar from p0 to p1: width across, depth along normal (e.g. sign strokes, stripes)."""
    p0, p1 = Vector(p0), Vector(p1)
    t = (p1 - p0).normalized()
    n = Vector(normal)
    n = (n - t * n.dot(t)).normalized()
    matrix = Matrix((t, n.cross(t), n)).transposed().to_4x4()
    matrix.translation = (p0 + p1) / 2
    mbox(bm, matrix, ((p1 - p0).length, width, depth))


def outline_prism(bm, outline, matrix, z0, z1):
    """Extrude a closed 2D outline between local heights z0 and z1; matrix YZ / XZ stands it on its side."""
    bottom = [bm.verts.new(matrix @ Vector((a, b, z0))) for a, b in outline]
    top = [bm.verts.new(matrix @ Vector((a, b, z1))) for a, b in outline]
    bm.faces.new(tuple(reversed(bottom)))
    bm.faces.new(tuple(top))
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))


def circle_profile(r, n=6):
    return [(r * math.cos(2 * math.pi * k / n), r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def rect_profile(u0, u1, v0, v1):
    return [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]


def loop_tube(bm, points, profile, normal):
    """Sweep a closed 2D profile around a closed, roughly planar loop (bezels, rims, glow trims).
    Profile (u, v): u across the loop within its plane (positive = away from the loop's centre), v along normal."""
    n = len(points)
    normal = Vector(normal).normalized()
    centre = sum(points, Vector()) / n
    outward = 1.0 if (points[1] - points[-1]).cross(normal).dot(points[0] - centre) >= 0 else -1.0
    rings = []
    for i, p in enumerate(points):
        tangent = (points[(i + 1) % n] - points[i - 1]).normalized()
        side = tangent.cross(normal).normalized() * outward
        rings.append([bm.verts.new(p + side * u + normal * v) for u, v in profile])
    m = len(profile)
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(m):
            j = (k + 1) % m
            bm.faces.new((a[k], a[j], b[j], b[k]))


def capsule(bm, p0, p1, r0, r1=None, segments=12, cap_rings=3):
    """A rounded rod from p0 to p1 (radius r0 at p0, r1 at p1) with domed ends."""
    p0, p1 = Vector(p0), Vector(p1)
    r1 = r0 if r1 is None else r1
    length = (p1 - p0).length
    profile = [(0, -r0)]
    profile += [(r0 * math.cos(a), r0 * math.sin(a)) for a in [-math.pi / 2 + math.pi / 2 * k / cap_rings for k in range(1, cap_rings + 1)]]
    profile += [(r1 * math.cos(a), length + r1 * math.sin(a)) for a in [math.pi / 2 * k / cap_rings for k in range(cap_rings)]]
    profile.append((0, length + r1))
    lathe(bm, profile, segments, Matrix.Translation(p0) @ align_z(p1 - p0))


def beam(bm, points, size0, size1=None, ref=(0, 1, 0), corner=0.35, seg=2):
    """A rounded-rectangle beam along a polyline; size (across, along ref) tapers from size0 to size1."""
    size1 = size0 if size1 is None else size1
    ref = Vector(ref).normalized()
    sections = []
    n = len(points)
    for i, p in enumerate(points):
        p = Vector(p)
        tangent = (Vector(points[min(i + 1, n - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
        a = (ref - tangent * ref.dot(tangent)).normalized()
        b = tangent.cross(a)
        f = i / (n - 1)
        w = size0[0] + (size1[0] - size0[0]) * f
        d = size0[1] + (size1[1] - size0[1]) * f
        sections.append([p + b * x + a * y for x, y in rounded_rect(w, d, corner * min(w, d), seg)])
    loft(bm, sections)


def solar_cells(bm, matrix, width, depth, cols, rows, gap=0.08, thickness=0.08):
    """A grid of thin solar cells in the matrix's XY plane, centred and resting on local z = 0."""
    cw = (width - gap * (cols - 1)) / cols
    cd = (depth - gap * (rows - 1)) / rows
    for i in range(cols):
        for j in range(rows):
            x = -width / 2 + cw / 2 + i * (cw + gap)
            y = -depth / 2 + cd / 2 + j * (cd + gap)
            mbox(bm, matrix @ Matrix.Translation((x, y, thickness / 2)), (cw, cd, thickness))


def leaf(bm, base, direction, length, width, rise=0.8, droop=1.2, cup=0.25, thickness=0.08, wave=0.0, waves=3, steps=10,
         roundness=0.8):
    """A broad leaf from base along a horizontal direction: it arches up by rise, droops by droop toward its
    tip, is cupped along its midrib, and wave ruffles its edges. Lower roundness gives a fuller, rounder blade."""
    d = Vector((direction[0], direction[1], 0)).normalized()
    side = Vector((-d.y, d.x, 0))
    up = Vector((0, 0, 1))
    sections = []
    for i in range(steps + 1):
        s = i / steps
        center = Vector(base) + d * (length * s) + up * (rise * math.sin(math.pi * s * 0.8) - droop * s * s)
        half = width * max(0.05, math.sin(math.pi * s ** 0.75) ** roundness)

        def lift(u):
            return cup * half * u * u + wave * half * abs(u) ** 1.5 * math.sin(waves * 2 * math.pi * s + (0.0 if u > 0 else 1.7))
        top = [center + side * (u * half) + up * (lift(u) + thickness / 2 * (1 - abs(u))) for u in (-1, -0.5, 0, 0.5, 1)]
        under = [center + side * (u * half) + up * (lift(u) - thickness / 2 * (1 - abs(u))) for u in (0.5, 0, -0.5)]
        sections.append(top + under)
    loft(bm, sections)


def card_leaf(bm, base, direction, normal, length, width, bend=0.3, cup=0.25, thickness=0.07, steps=4):
    """A small cupped leaf along direction with its face toward normal, curling back by bend (shrub foliage)."""
    d = Vector(direction).normalized()
    n = Vector(normal)
    n = (n - d * n.dot(d)).normalized()
    s = d.cross(n)
    sections = []
    for i in range(steps + 1):
        t = i / steps
        c = Vector(base) + d * (length * t) - n * (bend * length * t * t)
        half = width * max(0.08, math.sin(math.pi * t ** 0.8) ** 0.7)
        sections.append([c - s * half + n * (cup * half), c + n * (thickness / 2), c + s * half + n * (cup * half), c - n * (thickness / 2)])
    loft(bm, sections)


def interp(table, s):
    """Linear interpolation in a [(s, value), ...] table."""
    if s <= table[0][0]:
        return table[0][1]
    for (s0, v0), (s1, v1) in zip(table, table[1:]):
        if s <= s1:
            return v0 + (v1 - v0) * (s - s0) / (s1 - s0)
    return table[-1][1]


def triangulate_ngons(obj):
    """Split caps with more than four corners into triangles so concave outlines import safely."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    ngons = [f for f in bm.faces if len(f.verts) > 4]
    if ngons:
        try:
            bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="BEAUTY")
        except TypeError:
            bmesh.ops.triangulate(bm, faces=ngons)
    bm.to_mesh(obj.data)
    bm.free()


# ---------- 1. Solar Suburbs ----------

def build_eco_house(coll):
    walls, roof, solar, glass, trim, lawn = (bmesh.new() for _ in range(6))
    rounded_block(walls, (13.0, 10.0, 0.3), M((0, 0, 0.15)), corner=0.7, edge=0.08, edge_seg=1)
    rounded_block(lawn, (12.4, 9.4, 0.26), M((0, 0, 0.37)), corner=0.45, edge=0.08, edge_seg=1)
    # Ground floor box with a flat roof; the upper box sits forward and to the right of it.
    rounded_block(walls, (9.2, 6.2, 3.75), M((-1.0, 1.1, 2.325)), corner=0.1, edge=0.04, corner_seg=1, edge_seg=1)
    box(roof, (-1.0, 1.1, 4.31), (9.56, 6.56, 0.22))

    def top(y):
        return 7.2 + (y + 3.0) * 2.0 / 6.2
    outline_prism(walls, [(-3.0, 4.2), (3.2, 4.2), (3.2, top(3.2)), (-3.0, top(-3.0))], YZ, -2.6, 5.6)
    outline_prism(roof, [(-3.35, top(-3.35) - 0.06), (3.5, top(3.5) - 0.06), (3.5, top(3.5) + 0.2), (-3.35, top(-3.35) + 0.2)],
                  YZ, -2.9, 5.9)
    # Solar: a big array on the slanted roof and three tilted racks on the flat roof.
    solar_cells(solar, M((1.5, 0.075, top(0.075) + 0.2), (math.atan2(2.0, 6.2), 0, 0)), 8.3, 6.4, 5, 3, gap=0.1, thickness=0.09)
    tilt = math.radians(24)
    for y in (-1.25, 0.9, 3.05):
        zc = 4.42 + 0.25 + 0.75 * math.sin(tilt)
        mbox(solar, M((-4.2, y, zc), (tilt, 0, 0)), (2.5, 1.5, 0.08))
        for x in (-5.2, -3.2):
            for side, h in ((1, zc + 0.3 - 4.42), (-1, zc - 0.3 - 4.42)):
                box(roof, (x, y + side * 0.62, 4.42 + h / 2), (0.12, 0.12, h))

    def front_pane(x0, x1, z0, z1, y, sign):
        box(glass, ((x0 + x1) / 2, y + sign * 0.02, (z0 + z1) / 2), (x1 - x0, 0.1, z1 - z0))

    def side_pane(y0, y1, z0, z1, x, sign):
        box(glass, (x + sign * 0.02, (y0 + y1) / 2, (z0 + z1) / 2), (0.1, y1 - y0, z1 - z0))

    def front_frame(bm, x0, x1, z0, z1, y, sign, mullions=()):
        c = y + sign * 0.04
        for z in (z0, z1):
            box(bm, ((x0 + x1) / 2, c, z), (x1 - x0 + 0.12, 0.14, 0.12))
        for x in (x0, x1) + tuple(mullions):
            box(bm, (x, c, (z0 + z1) / 2), (0.12, 0.14, z1 - z0))

    def side_frame(bm, y0, y1, z0, z1, x, sign, mullions=()):
        c = x + sign * 0.04
        for z in (z0, z1):
            box(bm, (c, (y0 + y1) / 2, z), (0.14, y1 - y0 + 0.12, 0.12))
        for y in (y0, y1) + tuple(mullions):
            box(bm, (c, y, (z0 + z1) / 2), (0.14, 0.12, z1 - z0))
    # Front: a full-height glass wall, a door with a glass slit, and the upper window band.
    front_pane(-5.0, -1.0, 0.85, 3.85, -2.0, -1)
    front_frame(trim, -5.0, -1.0, 0.85, 3.85, -2.0, -1, (-3.67, -2.33))
    front_pane(1.65, 2.05, 0.85, 3.5, -2.0, -1)
    front_pane(2.45, 3.3, 1.5, 3.5, -2.0, -1)
    front_frame(walls, 2.45, 3.3, 1.5, 3.5, -2.0, -1)
    front_pane(-2.1, 3.35, 4.85, 6.85, -3.0, -1)
    front_frame(trim, -2.1, 3.35, 4.85, 6.85, -3.0, -1, (-0.28, 1.53))
    # Sides and back.
    side_pane(-1.3, 2.9, 0.95, 3.7, -5.6, -1)
    side_frame(walls, -1.3, 2.9, 0.95, 3.7, -5.6, -1, (0.8,))
    side_pane(-2.4, 2.6, 4.9, 6.8, -2.6, -1)
    side_frame(walls, -2.4, 2.6, 4.9, 6.8, -2.6, -1, (0.1,))
    side_pane(-2.5, 1.9, 4.85, 6.85, 5.6, 1)
    side_frame(walls, -2.5, 1.9, 4.85, 6.85, 5.6, 1, (-0.3,))
    for x0, x1 in ((-4.9, -1.6), (0.2, 3.1)):
        front_pane(x0, x1, 1.2, 3.5, 4.2, 1)
        front_frame(walls, x0, x1, 1.2, 3.5, 4.2, 1)
    front_pane(-1.9, 4.9, 5.0, 7.4, 3.2, 1)
    front_frame(walls, -1.9, 4.9, 5.0, 7.4, 3.2, 1, (0.37, 2.63))
    # Warm wood: deck, step, door, cladding, a post under the overhang and a storage block.
    for i in range(4):
        box(trim, (0.0, -3.31 + i * 0.375, 0.6), (11.8, 0.35, 0.3))
    for i in range(7):
        box(trim, (4.7, -1.82 + i * 0.375, 0.6), (2.1, 0.35, 0.3))
    box(trim, (0.75, -3.72, 0.535), (2.3, 0.45, 0.17))
    box(trim, (0.85, -2.04, 2.1), (1.2, 0.12, 2.7))
    for k in range(7):
        box(trim, (3.68 + k * 0.29, -3.05, 5.7), (0.16, 0.1, 2.8))
    box(trim, (5.35, -2.75, 2.475), (0.26, 0.26, 3.45))
    rounded_block(trim, (1.8, 2.55, 3.75), M((4.6, 1.875, 2.325)), corner=0.06, edge=0.03, corner_seg=1, edge_seg=1)
    # Planters with shrubs, pavers, and round bushes around the lawn.
    for x0, x1 in ((-5.8, -0.9), (2.4, 5.9)):
        box(trim, ((x0 + x1) / 2, -4.3, 0.75), (x1 - x0, 0.6, 0.6))
        count = int((x1 - x0) / 0.8)
        for k in range(count):
            x = x0 + (k + 0.5) * (x1 - x0) / count
            blob(lawn, Vector((x, -4.3, 1.12)), Vector((0.5, 0.36, 0.36)), subdivisions=2, lump=0.2, seed=x)
    box(walls, (0.75, -4.45, 0.52), (1.3, 0.5, 0.06))
    for x, y, r in ((-5.95, 3.7, 0.62), (-5.95, -1.6, 0.5), (6.0, 3.9, 0.6), (2.0, 4.6, 0.5), (-3.2, 4.6, 0.55), (6.0, -1.4, 0.5)):
        blob(lawn, Vector((x, y, 0.5 + r * 0.55)), Vector((r, r, r * 0.85)), subdivisions=2, lump=0.22, seed=x + y)
    return [closed(coll, "EcoHouseWalls", walls, WHITE, hard=True), closed(coll, "EcoHouseRoof", roof, ROOF, hard=True),
            closed(coll, "EcoHouseSolar", solar, SOLAR, hard=True), closed(coll, "EcoHouseGlass", glass, GLASS, hard=True),
            closed(coll, "EcoHouseTrim", trim, WARM_WOOD, hard=True), closed(coll, "EcoHouseLawn", lawn, GRASS)]


def rotor_blade(bm, hub, direction, axis, length, root=0.3, sections=13, ring=10, s0=0.0, s1=1.0, grow=0.0):
    """A slender tapered blade from the hub along direction; chord in the rotor plane, twisting flatter toward the tip.
    s0..s1 builds only part of the blade, grown by grow (painted tip bands)."""
    d = Vector(direction).normalized()
    axis = Vector(axis).normalized()
    side = axis.cross(d).normalized()
    loops = []
    for i in range(sections):
        s = s0 + (s1 - s0) * i / (sections - 1)
        chord = interp([(0, 0.42), (0.07, 0.7), (0.16, 1.0), (0.35, 0.82), (1.0, 0.16)], s) + grow
        thick = interp([(0, 0.42), (0.16, 0.3), (1.0, 0.05)], s) + grow
        pitch = 0.55 * (1 - s) + 0.12 * s
        c_dir = side * math.cos(pitch) + axis * math.sin(pitch)
        t_dir = axis * math.cos(pitch) - side * math.sin(pitch)
        center = Vector(hub) + d * (root + (length - root) * s) + c_dir * (chord * 0.2 * min(1.0, s * 6))
        loops.append([center + c_dir * (chord / 2 * math.cos(a)) + t_dir * (thick / 2 * math.sin(a) * (1 - 0.45 * max(0.0, math.cos(a))))
                      for a in [2 * math.pi * k / ring for k in range(ring)]])
    loft(bm, loops)


def build_wind_turbine(coll):
    tower, blades, hub, base = (bmesh.new() for _ in range(4))
    height, length = 11.5, 8.05
    rounded_block(base, (3.4, 3.4, 0.36), M((0, 0, 0.18)), corner=0.9, edge=0.08, edge_seg=1)
    lathe(base, [(0, 0.3), (1.0, 0.3), (0.9, 0.62), (0, 0.62)], 24)
    lathe(tower, [(0, 0.55), (0.6, 0.55), (0.55, 1.2), (0.27, height - 0.3), (0, height - 0.3)], 24)
    # The hub part is the accent role: door, nacelle stripe, nose cone and painted blade tips.
    box(hub, (0, -0.56, 1.45), (0.5, 0.12, 1.0))
    rounded_block(tower, (1.2, 3.0, 1.25), M((0, 0.55, height)), corner=0.52, edge=0.44, corner_seg=3, edge_seg=3)
    rounded_block(hub, (1.24, 0.35, 1.29), M((0, 1.25, height)), corner=0.54, edge=0.46, corner_seg=3, edge_seg=3)
    lathe(hub, [(0, 0), (0.72, 0), (0.69, 0.4), (0.48, 0.95), (0, 1.4)], 20, M((0, -0.9, height)) @ align_z(Vector((0, -1, 0))))
    for a in (90, 210, 330):
        r = math.radians(a)
        rotor_blade(blades, (0, -1.25, height), (math.cos(r), 0, math.sin(r)), (0, -1, 0), length)
        rotor_blade(hub, (0, -1.25, height), (math.cos(r), 0, math.sin(r)), (0, -1, 0), length, sections=3, s0=0.8, s1=0.88, grow=0.03)
    return [closed(coll, "TurbineTower", tower, WHITE), closed(coll, "TurbineBlades", blades, WHITE),
            closed(coll, "TurbineHub", hub, LIME), closed(coll, "TurbineBase", base, CONCRETE, hard=True)]


def build_solar_tree(coll):
    stem, panels, glow = bmesh.new(), bmesh.new(), bmesh.new()
    lathe(stem, [(0, 0), (1.7, 0), (1.7, 0.2), (1.45, 0.42), (0.8, 0.62), (0.52, 0.8), (0, 0.8)], 28)
    sweep(stem, curve((0, 0, 0.7), (0.35, 0.15, 6.0), (0, 0, 11.4), 16), 0.44, segments=16, radius_end=0.24)
    torus(glow, M((0, 0, 1.05)), 0.46, 0.08, seg=24, tseg=6)
    # Seven leaves spiralling up at the golden angle: big low ones reaching out, small high ones close in.
    for i in range(7):
        a = math.radians(i * 137.5 + 20)
        h = 6.0 + i * 0.8
        reach = 3.6 - i * 0.24
        length, width = 3.3 - i * 0.14, 2.15 - i * 0.07
        frame = M((math.cos(a) * reach, math.sin(a) * reach, h)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.radians(24 - i * 2), 4, "Y")
        rounded_block(stem, (length + 0.26, width + 0.26, 0.12), frame @ Matrix.Translation((0, 0, -0.06)), corner=0.35, edge=0.04, edge_seg=1)
        solar_cells(panels, frame, length, width, 3, 2, gap=0.08, thickness=0.07)
        normal = frame.to_3x3() @ Vector((0, 0, 1))
        under = frame @ Vector((-0.3, 0, -0.12))
        start = Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, h - 1.9))
        sweep(stem, curve(start, Vector((math.cos(a) * reach * 0.3, math.sin(a) * reach * 0.3, h - 0.2)), under, 10), 0.17, segments=8, radius_end=0.11)
        cyl(stem, under - normal * 0.05, 0.22, 0.12, 12, direction=normal)
        cyl(glow, frame @ Vector((length * 0.28, 0, -0.12)), 0.3, 0.05, 16, direction=-normal)
    lathe(stem, [(0, 11.1), (0.34, 11.1), (0.86, 11.6), (0.94, 11.8), (0.8, 11.83), (0, 11.55)], 24)
    lathe(glow, [(0, 11.45), (0.56, 11.65), (0.8, 12.12), (0.7, 12.66), (0.34, 13.08), (0, 13.2)], 20)
    return [closed(coll, "SolarTreeStem", stem, WHITE), closed(coll, "SolarTreePanels", panels, SOLAR, hard=True),
            closed(coll, "SolarTreeGlow", glow, CYAN)]


# ---------- 2. Maglev Highway ----------

def squircle_point(w, zb, zt, a, power=2.6, mid=0.42):
    """A point (x, z) on a rounded vehicle section: angle a about the long axis (0 = right side, pi/2 = top)."""
    c, s = math.cos(a), math.sin(a)
    zm = zb + (zt - zb) * mid
    x = w * math.copysign(abs(c) ** (2 / power), c)
    z = zm + ((zt - zm) if s >= 0 else (zm - zb)) * math.copysign(abs(s) ** (2 / power), s)
    return x, z


def section_at(table, y):
    """Interpolate a [(y, half width, bottom, top), ...] vehicle profile at y."""
    for a, b in zip(table, table[1:]):
        if a[0] <= y <= b[0]:
            f = (y - a[0]) / (b[0] - a[0])
            return tuple(a[i] + (b[i] - a[i]) * f for i in range(1, 4))
    return table[-1][1:] if y > table[-1][0] else table[0][1:]


def vehicle_body(bm, table, ring=20, power=2.6):
    """Loft a streamlined body through the table's sections (along Y)."""
    loft(bm, [[Vector((x, y, z)) for x, z in [squircle_point(w, zb, zt, 2 * math.pi * k / ring, power) for k in range(ring)]]
              for y, w, zb, zt in table])


def surface_strip(bm, table, y0, y1, a0, a1, out=0.03, inset=0.05, steps=10, power=2.6, mirror=False):
    """A thin band hugging a vehicle body between angles a0..a1 from y0 to y1 (window bands, stripes)."""
    count = max(1, int(math.ceil((a1 - a0) / 0.15)))
    angles = [a0 + (a1 - a0) * k / count for k in range(count + 1)]
    sections = []
    for i in range(steps + 1):
        y = y0 + (y1 - y0) * i / steps
        w, zb, zt = section_at(table, y)
        zm = zb + (zt - zb) * 0.42
        outer, inner = [], []
        for a in angles:
            x, z = squircle_point(w, zb, zt, a, power)
            normal = Vector((x, 0, z - zm)).normalized()
            outer.append(Vector((x, y, z)) + normal * out)
            inner.append(Vector((x, y, z)) - normal * inset)
        ring = outer + list(reversed(inner))
        sections.append([Vector((-p.x, p.y, p.z)) for p in ring] if mirror else ring)
    loft(bm, sections)


CAR = [(-4.75, 0.28, 0.74, 0.9), (-4.55, 0.85, 0.6, 1.04), (-4.1, 1.35, 0.5, 1.2), (-3.2, 1.75, 0.45, 1.36),
       (-2.0, 1.93, 0.43, 1.48), (-0.8, 1.98, 0.43, 1.56), (0.4, 2.0, 0.43, 1.64), (1.6, 1.98, 0.44, 1.72),
       (2.8, 1.92, 0.46, 1.8), (3.8, 1.8, 0.5, 1.84), (4.4, 1.6, 0.58, 1.82), (4.75, 1.32, 0.7, 1.72)]
def canopy_size(u):
    """Teardrop bubble profile along the canopy (0 = front, 1 = back): 0..1, fullest at u = 0.42."""
    t = (0.42 - u) / 0.42 if u < 0.42 else (u - 0.42) / 0.58
    return max(0.05, math.sqrt(max(0.0, 1 - t * t)))


def build_hover_car(coll):
    body, glass, glow, trim = (bmesh.new() for _ in range(4))
    vehicle_body(body, CAR)
    # Bubble canopy: half-ellipse arcs lofted into a teardrop dome sitting in the roof.
    loft(glass, [[Vector((1.36 * canopy_size(u) * math.cos(a), -2.95 + 5.3 * u, 1.4 + 1.18 * canopy_size(u) ** 0.85 * math.sin(a)))
                  for a in [math.pi * k / 16 for k in range(17)]] for u in [k / 18 for k in range(19)]])
    # Retro-future twin tail fins joined by a wing, with glowing tips.
    for side in (-1, 1):
        outline_prism(body, [(2.0, 1.35), (4.6, 1.4), (5.0, 2.62), (4.72, 2.7), (3.7, 2.05), (2.7, 1.72)], YZ, side * 1.3 - 0.09, side * 1.3 + 0.09)
        blob(glow, Vector((side * 1.3, 4.9, 2.66)), Vector((0.15, 0.2, 0.12)), subdivisions=2)
    rounded_block(trim, (2.75, 0.62, 0.12), M((0, 4.58, 2.43), (-0.08, 0, 0)), corner=0.25, edge=0.05, edge_seg=1)
    # Hover pods where wheels would be, each with a glowing pad underneath.
    for y in (-2.7, 2.7):
        for side in (-1, 1):
            blob(trim, Vector((side * 1.72, y, 0.42)), Vector((0.5, 1.02, 0.4)), subdivisions=3)
            blob(glow, Vector((side * 1.72, y, 0.07)), Vector((0.36, 0.76, 0.07)), subdivisions=2)
    # Dark lower skirts with an underglow line, a side stripe, a light bar across the nose, tail light, thrusters.
    right = []
    for y, w, zb, zt in CAR[1:-1]:
        x, z = squircle_point(w, zb, zt, -1.0)
        right.append(Vector((x + 0.02, y, z)))
    loop_tube(glow, right + [Vector((-p.x, p.y, p.z)) for p in reversed(right)], circle_profile(0.07), (0, 0, 1))
    for mirror in (False, True):
        surface_strip(trim, CAR, -3.9, 4.4, -0.95, -0.35, out=0.03, inset=0.05, steps=16, mirror=mirror)
        surface_strip(trim, CAR, -4.0, 4.45, 0.16, 0.24, out=0.03, inset=0.03, steps=16, mirror=mirror)
    surface_strip(glow, CAR, -4.42, -4.28, 0.08, math.pi - 0.08, out=0.035, inset=0.04, steps=2)
    capsule(glow, (-1.0, 4.74, 1.36), (1.0, 4.74, 1.36), 0.1, segments=10)
    for side in (-1, 1):
        cyl(trim, (side * 0.72, 4.45, 0.94), 0.27, 0.55, 16, direction=(0, 1, 0))
        cyl(glow, (side * 0.72, 4.98, 0.94), 0.19, 0.04, 16, direction=(0, 1, 0))
    return [closed(coll, "HoverCarBody", body, (0.95, 0.75, 0.2), hard=True), closed(coll, "HoverCarGlass", glass, GLASS),
            closed(coll, "HoverCarGlow", glow, CYAN), closed(coll, "HoverCarTrim", trim, GRAPHITE)]


def build_maglev_pylon(coll):
    body, rail, glow = bmesh.new(), bmesh.new(), bmesh.new()
    rounded_block(body, (3.2, 3.2, 0.5), M((0, 0, 0.25)), corner=0.7, edge=0.12)
    rounded_block(body, (1.9, 1.5, 7.0), M((0, 0, 3.95)), corner=0.5, edge=0.0, taper=0.78)
    rounded_block(body, (1.75, 1.45, 0.9), M((0, 0, 7.15)), corner=0.45, edge=0.25)
    loop_tube(glow, [Vector((x, y, 6.55)) for x, y in rounded_rect(1.56, 1.24, 0.4, 3)], rect_profile(-0.02, 0.05, -0.07, 0.07), (0, 0, 1))
    # The Y: two arms sweeping up and out past the guideway, joined by a saddle under it.
    for side in (-1, 1):
        beam(body, curve((side * 0.3, 0, 6.9), (side * 1.1, 0, 9.9), (side * 3.3, 0, 13.0), 14), (1.15, 1.3), (0.62, 0.95), corner=0.45)
        blob(glow, Vector((side * 3.36, 0, 13.08)), Vector((0.33, 0.47, 0.33)), subdivisions=2)
        capsule(glow, (0, side * 0.77, 1.1), (0, side * 0.6, 6.9), 0.07, segments=8)
    rounded_block(body, (3.9, 1.1, 0.5), M((0, 0, 10.85)), corner=0.25, edge=0.1)
    # Guideway beam with a raised centre rail, glowing along its edges and its running surface.
    outline_prism(rail, [(-1.6, 11.1), (1.6, 11.1), (1.9, 11.35), (1.9, 11.7), (0.5, 11.7), (0.5, 12.45), (-0.5, 12.45),
                         (-0.5, 11.7), (-1.9, 11.7), (-1.9, 11.35)], XZ, -7.0, 7.0)
    for side in (-1, 1):
        box(glow, (side * 1.93, 0, 11.52), (0.07, 14.0, 0.13))
        box(glow, (side * 0.53, 0, 12.15), (0.07, 14.0, 0.12))
    return [closed(coll, "PylonBody", body, WHITE, hard=True), closed(coll, "PylonRail", rail, PALE, hard=True),
            closed(coll, "PylonGlow", glow, CYAN)]


def chevron(bm, x, z, y, half=1.2, rise=1.0, thick=0.42, depth=0.06):
    """An upward chevron in the XZ plane (reads the same from both sides), depth along Y."""
    outline = [(x - half, z - thick), (x, z + rise - thick), (x + half, z - thick), (x + half, z), (x, z + rise), (x - half, z)]
    outline_prism(bm, outline, XZ, y - depth / 2, y + depth / 2)


def build_holo_sign(coll):
    posts, holo, symbols = bmesh.new(), bmesh.new(), bmesh.new()
    for side in (-1, 1):
        x = side * 5.5
        rounded_block(posts, (1.5, 1.5, 0.4), M((x, 0, 0.2)), corner=0.45, edge=0.12)
        rounded_block(posts, (0.78, 0.9, 10.2), M((x, 0, 5.4)), corner=0.3, edge=0.0, taper=0.85)
        rounded_block(posts, (1.1, 1.15, 0.5), M((x, 0, 10.72)), corner=0.35, edge=0.15)
        cyl(symbols, (x, 0, 10.95), 0.3, 0.08, 16)
        for y in (-0.4, 0.4):
            box(symbols, (x - side * 0.27, y * 0.98, 6.75), (0.09, 0.09, 5.4))
        for z in (3.75, 9.75):
            rounded_block(posts, (0.75, 0.75, 0.55), M((x - side * 0.47, 0, z)), corner=0.25, edge=0.14)
            cyl(symbols, (x - side * 0.83, 0, z), 0.2, 0.06, 14, direction=(-side, 0, 0))
    panel(holo, (0, 0, 6.75), 9.3, 6.3, 0.12, corner=0.6, edge=0.03)
    # Glyphs stand just off both faces of the panel so the sign reads from either side.
    for y in (-0.12, 0.12):
        loop_tube(symbols, [Vector((x, y, 6.75 + z)) for x, z in rounded_rect(8.5, 5.5, 0.45, 4)], rect_profile(-0.07, 0.07, -0.03, 0.03), (0, 1, 0))
        for z in (4.75, 6.05, 7.35):
            chevron(symbols, 0, z, y)
        for x0, rows in ((-3.85, ((0, 1.4, 1.65, 2.0), (0, 0.9, 1.15, 2.0), (0, 2.0), (0, 0.6, 0.85, 1.6))),
                         (1.85, ((0, 0.55, 0.8, 2.0), (0, 1.5), (0, 1.0, 1.25, 2.0), (0, 2.0)))):
            for r, row in enumerate(rows):
                z = 8.25 - r * 0.95
                for k in range(0, len(row), 2):
                    bar(symbols, (x0 + row[k], y, z), (x0 + row[k + 1], y, z), 0.24, 0.06, normal=(0, 1, 0))
    return [closed(coll, "HoloSignPosts", posts, PALE, hard=True), closed(coll, "HoloSignPanel", holo, (0.4, 0.85, 1.0)),
            closed(coll, "HoloSignSymbols", symbols, CYAN, hard=True)]


TRAIN = [(-9.3, 0.18, 8.88, 9.06), (-9.05, 0.7, 8.8, 9.32), (-8.6, 1.05, 8.75, 9.66), (-7.9, 1.3, 8.72, 10.14),
         (-7.0, 1.42, 8.7, 10.58), (-5.9, 1.45, 8.7, 10.84), (-4.2, 1.45, 8.7, 10.9), (-0.22, 1.45, 8.7, 10.9)]


def build_viaduct(coll):
    pillars, track, glow, train, windows = (bmesh.new() for _ in range(5))
    for y in (-6.6, 0.0, 6.6):
        rounded_block(pillars, (2.8, 2.2, 0.45), M((0, y, 0.225)), corner=0.5, edge=0.1)
        rounded_block(pillars, (1.5, 1.2, 6.0), M((0, y, 3.4)), corner=0.4, edge=0.0, taper=0.82)
        loft(pillars, [[Vector((x, y + yy, z)) for x, yy in rounded_rect(w, d, 0.35, 3)]
                       for z, w, d in ((6.2, 1.25, 1.0), (6.75, 1.75, 1.12), (7.05, 2.35, 1.22), (7.25, 2.95, 1.3))])
        for side in (-1, 1):
            capsule(glow, (side * 0.76, y, 1.1), (side * 0.63, y, 5.9), 0.07, segments=8)
    outline_prism(track, [(-1.3, 7.2), (1.3, 7.2), (2.3, 8.0), (2.3, 8.6), (2.05, 8.6), (2.05, 8.25), (0.5, 8.25), (0.5, 8.5),
                          (-0.5, 8.5), (-0.5, 8.25), (-2.05, 8.25), (-2.05, 8.6), (-2.3, 8.6), (-2.3, 8.0)], XZ, -9.9, 9.9)
    for side in (-1, 1):
        box(glow, (side * 2.33, 0, 8.22), (0.07, 19.8, 0.14))
    # A two-car streamlined train hovering just above the centre rail.
    for flip in (1, -1):
        table = TRAIN if flip == 1 else [(-y, w, zb, zt) for y, w, zb, zt in reversed(TRAIN)]
        vehicle_body(train, table, ring=22)
        lo, hi = (-8.9, -0.5) if flip == 1 else (0.5, 8.9)
        for mirror in (False, True):
            surface_strip(windows, table, (-6.6 if flip == 1 else 0.7), (-0.7 if flip == 1 else 6.6), 0.24, 0.72, steps=10, mirror=mirror)
            surface_strip(glow, table, lo, hi, -0.06, 0.04, out=0.03, inset=0.03, steps=14, mirror=mirror)
        surface_strip(windows, table, (-8.45 if flip == 1 else 6.95), (-6.95 if flip == 1 else 8.45), 0.62, math.pi - 0.62, steps=8)
    rounded_block(windows, (2.3, 0.7, 1.8), M((0, 0, 9.8)), corner=0.4, edge=0.25)
    return [closed(coll, "ViaductPillars", pillars, CONCRETE, hard=True), closed(coll, "ViaductTrack", track, PALE, hard=True),
            closed(coll, "ViaductGlow", glow, CYAN), closed(coll, "ViaductTrain", train, WHITE),
            closed(coll, "ViaductWindows", windows, GRAPHITE)]


# ---------- 3. Skyline Metropolis ----------

def build_holo_billboard(coll):
    frame, screen, glow = bmesh.new(), bmesh.new(), bmesh.new()
    cz, width, height = 12.45, 11.0, 7.2
    for side in (-1, 1):
        x = side * 3.3
        rounded_block(frame, (1.8, 2.0, 0.45), M((x, 0, 0.225)), corner=0.55, edge=0.14)
        rounded_block(frame, (0.95, 1.15, 8.2), M((x, 0, 4.5)), corner=0.38, edge=0.0, taper=0.7)
        for y in (-1, 1):
            capsule(glow, (x, y * 0.58, 1.0), (x, y * 0.42, 8.0), 0.07, segments=8)
    loop_tube(frame, [Vector((x, 0, cz + z)) for x, z in rounded_rect(width, height, 0.9, 5)], rect_profile(-0.05, 0.42, -0.32, 0.32), (0, 1, 0))
    panel(screen, (0, 0, cz), width + 0.1, height + 0.1, 0.2, corner=0.95, edge=0.0, corner_seg=5)
    # Both faces carry a glowing edge trim and the same advert: a baseball and headline bars.
    for y in (-0.135, 0.135):
        loop_tube(glow, [Vector((x, y, cz + z)) for x, z in rounded_rect(width - 0.55, height - 0.55, 0.7, 5)], circle_profile(0.075), (0, 1, 0))
        ball = Vector((-2.75, y, cz + 0.05))
        loop_tube(glow, [ball + Vector((math.cos(a) * 1.85, 0, math.sin(a) * 1.85)) for a in [2 * math.pi * k / 40 for k in range(40)]],
                  circle_profile(0.11), (0, 1, 0))
        for side in (-1, 1):
            centre = ball + Vector((side * 2.55, 0, 0))
            seam = [centre + Vector((-side * math.cos(a) * 1.75, 0, math.sin(a) * 1.75)) for a in [math.radians(-48 + 8 * k) for k in range(13)]]
            sweep(glow, seam, 0.075, segments=6)
            for k in range(1, 12, 2):
                across = Vector((0, 1, 0)).cross((seam[k + 1] - seam[k - 1]).normalized())
                bar(glow, seam[k] - across * 0.2, seam[k] + across * 0.2, 0.08, 0.06, normal=(0, 1, 0))
        for z, x1, thick in ((2.0, 4.5, 0.5), (0.95, 3.5, 0.28), (0.25, 4.1, 0.28), (-0.45, 2.7, 0.28)):
            bar(glow, (0.2, y, cz + z), (x1, y, cz + z), thick, 0.06, normal=(0, 1, 0))
        rounded_block(glow, (2.2, 0.75, 0.06), M((1.3, y, cz - 1.75), (math.pi / 2, 0, 0)), corner=0.37, edge=0.0, corner_seg=4)
    return [closed(coll, "BillboardFrame", frame, GRAPHITE, hard=True), closed(coll, "BillboardScreen", screen, (0.2, 0.1, 0.45), hard=True),
            closed(coll, "BillboardGlow", glow, MAGENTA)]


def build_neo_lamp(coll):
    pole, light, base = bmesh.new(), bmesh.new(), bmesh.new()
    lathe(base, [(0, 0), (1.3, 0), (1.3, 0.2), (1.12, 0.45), (0.62, 0.88), (0.42, 1.4), (0, 1.4)], 28)
    torus(light, M((0, 0, 0.1)), 1.32, 0.06, seg=40, tseg=6)
    # One sweeping stroke: straight up, then curling over into the lamp head, traced by two neon lines.
    path = curve((0, 0, 1.2), (0, 0, 10.9), (0.3, 0, 14.1), 26, p3=(3.65, 0, 13.42))
    sweep(pole, path, 0.31, segments=16, radius_end=0.2)
    for side in (-1, 1):
        sweep(light, [p + Vector((0, side * (0.3 - 0.1 * i / 25), 0)) for i, p in enumerate(path[:-1])], 0.06, segments=6)
    # The head: a slim lens-shaped housing ringed by a glowing halo on three spokes, a light disc underneath.
    head = Vector((4.25, 0, 13.25))
    lathe(pole, [(0, 0.34), (0.45, 0.31), (0.86, 0.14), (0.92, 0.0), (0.84, -0.1), (0, -0.12)], 32, Matrix.Translation(head))
    torus(light, M(head), 1.42, 0.13, seg=48, tseg=8)
    for k in range(3):
        a = math.radians(60 + 120 * k)
        direction = Vector((math.cos(a), math.sin(a), 0))
        cyl(pole, head + direction * 0.8, 0.07, 0.55, 8, direction=direction)
    cyl(light, head + Vector((0, 0, -0.1)), 0.72, 0.07, 32, direction=(0, 0, -1))
    return [closed(coll, "NeoLampPole", pole, PALE), closed(coll, "NeoLampLight", light, CYAN),
            closed(coll, "NeoLampBase", base, GRAPHITE)]


def build_skyscraper(coll):
    glass, frame, glow = bmesh.new(), bmesh.new(), bmesh.new()
    rounded_block(frame, (7.4, 7.4, 1.3), M((0, 0, 0.65)), corner=1.3, edge=0.1, corner_seg=1, edge_seg=1)
    box(glass, (0, -3.72, 0.55), (2.8, 0.1, 0.9))
    box(frame, (0, -4.05, 1.12), (3.4, 0.8, 0.12))
    # Three chamfered glass tiers with setbacks: cornices, vertical fins, glowing bands and corner lights.
    for z0, z1, w, ch, fins in ((1.3, 9.6, 6.1, 1.05, 4), (10.0, 14.8, 4.9, 0.85, 3), (15.2, 17.6, 3.7, 0.65, 2)):
        rounded_block(glass, (w, w, z1 - z0 + 0.1), M((0, 0, (z0 + z1) / 2)), corner=ch, edge=0.0, corner_seg=1)
        rounded_block(frame, (w + 0.5, w + 0.5, 0.4), M((0, 0, z1 + 0.2)), corner=ch + 0.2, edge=0.06, corner_seg=1, edge_seg=1)
        bands = [z1 - 0.3] + ([z0 + (z1 - z0) * k / 3 for k in (1, 2)] if z1 - z0 > 6 else [])
        for z in bands:
            loop_tube(glow, [Vector((x, y, z)) for x, y in rounded_rect(w, w, ch, 1)], rect_profile(-0.02, 0.05, -0.1, 0.1), (0, 0, 1))
        for quarter in range(4):
            turn = Matrix.Rotation(quarter * math.pi / 2, 3, "Z")
            for k in range(fins):
                u = -(w / 2 - ch) + (w - 2 * ch) * (k + 0.5) / fins
                box(frame, turn @ Vector((u, -(w / 2 + 0.1), (z0 + z1) / 2)), (0.2, 0.3, z1 - z0 - 0.15), rotation=(0, 0, quarter * math.pi / 2))
            m = turn @ Vector((w / 2 - ch / 2 + 0.03, w / 2 - ch / 2 + 0.03, (z0 + z1) / 2))
            box(glow, m, (0.32, 0.08, z1 - z0 - 0.7), rotation=(0, 0, quarter * math.pi / 2 + 3 * math.pi / 4))
    lathe(frame, [(0, 18.0), (1.4, 18.0), (1.15, 18.55), (0, 18.55)], 8, Matrix.Rotation(math.pi / 8, 4, "Z"))
    torus(glow, M((0, 0, 18.3)), 1.3, 0.06, seg=24, tseg=5)
    lathe(frame, [(0, 18.45), (0.34, 18.45), (0.12, 19.4), (0, 19.55)], 8)
    blob(glow, Vector((0, 0, 19.62)), Vector((0.17, 0.17, 0.17)), subdivisions=2)
    return [closed(coll, "SkyscraperGlass", glass, (0.25, 0.45, 0.7), hard=True), closed(coll, "SkyscraperFrame", frame, WHITE, hard=True),
            closed(coll, "SkyscraperGlow", glow, CYAN, hard=True)]


# ---------- 4. Robo Assembly Line ----------

def build_robot_arm(coll):
    body, joints, base, light = (bmesh.new() for _ in range(4))
    by = 2.2
    rounded_block(base, (4.6, 4.6, 0.36), M((0, by, 0.18)), corner=0.7, edge=0.1)
    rounded_block(base, (3.1, 3.1, 0.95), M((0, by, 0.8)), corner=0.6, edge=0.12)
    for x in (-1.85, 1.85):
        for y in (by - 1.85, by + 1.85):
            cyl(joints, (x, y, 0.3), 0.17, 0.12, 10)
    lathe(base, [(0, 1.2), (1.75, 1.2), (1.75, 1.75), (1.6, 1.9), (0, 1.9)], 32, Matrix.Translation((0, by, 0)))
    torus(light, M((0, by, 1.5)), 1.77, 0.06, seg=40, tseg=6)
    # Turning shoulder housing, then upper arm, elbow, forearm with its motor, wrist and a two-finger gripper.
    rounded_block(body, (2.3, 2.5, 2.3), M((0, by, 3.0)), corner=0.9, edge=0.5, corner_seg=4)
    box(light, (0, by - 1.25, 2.45), (1.0, 0.06, 0.14))
    s = Vector((0, by - 0.2, 3.9))
    cyl(joints, s + Vector((-1.35, 0, 0)), 0.82, 2.7, 28, direction=(1, 0, 0))
    e = s + 7.6 * Vector((0, -math.sin(math.radians(15)), math.cos(math.radians(15))))
    beam(body, [s.lerp(e, t / 5) for t in range(6)], (1.8, 1.4), (1.3, 1.15), ref=(1, 0, 0), corner=0.45)
    cyl(joints, e + Vector((-1.05, 0, 0)), 0.8, 2.1, 24, direction=(1, 0, 0))
    f = Vector((0, -math.cos(math.radians(4)), math.sin(math.radians(4))))
    w = e + f * 4.5
    beam(body, [(e - f * 1.5).lerp(w, t / 6) for t in range(7)], (1.5, 1.35), (0.9, 0.95), ref=(1, 0, 0), corner=0.45)
    rounded_block(body, (1.5, 1.4, 1.5), M(e - f * 1.55 + Vector((0, 0, 0.1))), corner=0.55, edge=0.45)
    cyl(joints, w + Vector((-0.6, 0, 0)), 0.52, 1.2, 20, direction=(1, 0, 0))
    t = Vector((0, -0.5, -math.sqrt(3) / 2))
    capsule(body, w, w + t * 1.0, 0.42, segments=16)
    cyl(joints, w + t * 0.95, 0.56, 0.22, 24, direction=t)
    torus(light, Matrix.Translation(w + t * 1.08) @ align_z(t), 0.58, 0.07, seg=32, tseg=6)
    grip = Matrix.Translation(w + t * 1.4) @ align_z(t)
    rounded_block(joints, (1.25, 0.6, 0.45), grip, corner=0.2, edge=0.12)
    for side in (-1, 1):
        mbox(joints, grip @ M((side * 0.45, 0, 0.8), (0, side * 0.12, 0)), (0.24, 0.48, 1.1))
        mbox(joints, grip @ M((side * 0.47, 0, 1.36), (0, -side * 0.7, 0)), (0.22, 0.44, 0.42))
    blob(light, grip @ Vector((0, 0, 0.3)), Vector((0.2, 0.2, 0.12)), subdivisions=2)
    sweep(joints, curve((0.75, by + 1.15, 4.1), (1.05, by + 1.0, 8.7), (0.72, e.y + 1.55, e.z - 0.1), 14), 0.13, segments=8)
    return [closed(coll, "RobotArmBody", body, ORANGE, hard=True), closed(coll, "RobotArmJoints", joints, GRAPHITE, hard=True),
            closed(coll, "RobotArmBase", base, CONCRETE, hard=True), closed(coll, "RobotArmLight", light, CYAN)]


def stadium(half, zc, r, n=10):
    """Closed (y, z) outline of a stadium: half-length half between end centres, end radius r."""
    points = [(half + r * math.cos(a), zc + r * math.sin(a)) for a in [-math.pi / 2 + math.pi * k / n for k in range(n + 1)]]
    return points + [(-half + r * math.cos(a), zc + r * math.sin(a)) for a in [math.pi / 2 + math.pi * k / n for k in range(n + 1)]]


def build_conveyor(coll):
    frame, belt, crates, stripes = (bmesh.new() for _ in range(4))
    half, zr, rr = 7.6, 2.9, 0.42
    for y in (-half, half):
        cyl(frame, (-1.46, y, zr), rr, 2.92, 20, direction=(1, 0, 0))
    for x0, x1 in ((1.45, 1.67), (-1.67, -1.45)):
        outline_prism(frame, stadium(half, zr, 0.6), YZ, x0, x1)
    for side in (-1, 1):
        box(frame, (side * 1.6, 0, 3.75), (0.1, 14.4, 0.6))
        # Hazard stripes on the outer face of each guard.
        for k in range(20):
            y0 = -7.1 + k * 0.7
            if y0 + 0.85 <= 7.15:
                outline_prism(stripes, [(y0, 3.47), (y0 + 0.35, 3.47), (y0 + 0.85, 4.03), (y0 + 0.5, 4.03)], YZ,
                              min(side * 1.645, side * 1.69), max(side * 1.645, side * 1.69))
    for y in (-6.0, 0.0, 6.0):
        for x in (-1.35, 1.35):
            box(frame, (x, y, 1.3), (0.26, 0.26, 2.6))
            rounded_block(frame, (0.6, 0.6, 0.14), M((x, y, 0.07)), corner=0.15, edge=0.04, edge_seg=1)
        box(frame, (0, y, 0.95), (2.7, 0.2, 0.2))
    for x in (-1.35, 1.35):
        box(frame, (x, 0, 0.62), (0.18, 12.0, 0.18))
    rounded_block(frame, (0.7, 1.3, 1.3), M((2.05, half, zr)), corner=0.3, edge=0.2)
    cyl(frame, (2.4, half, zr), 0.4, 0.15, 16, direction=(1, 0, 0))
    box(frame, (-2.2, -half + 0.6, 1.75), (0.18, 0.18, 3.5))
    rounded_block(frame, (0.7, 0.42, 0.6), M((-2.2, -half + 0.6, 3.6)), corner=0.12, edge=0.08)
    cyl(stripes, (-2.2, -half + 0.39, 3.62), 0.13, 0.08, 12, direction=(0, -1, 0))
    # The belt wraps both rollers; cleats ride along its top run.
    loop_tube(belt, [Vector((0, y, z)) for y, z in stadium(half, zr, rr + 0.06, 12)], rect_profile(-0.06, 0.06, -1.38, 1.38), (1, 0, 0))
    top = zr + rr + 0.12
    for k in range(14):
        box(belt, (0, -6.8 + k * 1.05, top + 0.04), (2.6, 0.12, 0.1))
    # Cargo riding the belt: crates with lid bands, a canister and a small stacked box.
    for size, y, turn in (((1.7, 1.7, 1.5), -4.6, 0.12), ((1.3, 1.25, 1.05), -1.3, -0.1), ((1.3, 1.3, 0.95), 4.8, 0.08)):
        rounded_block(crates, size, M((0.05, y, top + size[2] / 2), (0, 0, turn)), corner=0.12, edge=0.1, corner_seg=2)
        rounded_block(crates, (size[0] + 0.08, size[1] + 0.08, 0.14), M((0.05, y, top + size[2] * 0.82), (0, 0, turn)),
                      corner=0.14, edge=0.03, corner_seg=2, edge_seg=1)
    rounded_block(crates, (0.8, 0.8, 0.6), M((0.1, 4.75, top + 0.95 + 0.3), (0, 0, 0.5)), corner=0.1, edge=0.08, corner_seg=2)
    standing = Matrix.Translation((0, 6.75, top + 0.74)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    gear(crates, standing, 0.74, 0.58, 0.2, 10, 0.32)
    cyl(crates, (-0.21, 6.75, top + 0.74), 0.25, 0.42, 12, direction=(1, 0, 0))
    lathe(crates, [(0, top), (0.62, top), (0.62, top + 1.1), (0.5, top + 1.24), (0, top + 1.24)], 20, Matrix.Translation((0, 1.8, 0)))
    for z in (0.3, 0.8):
        torus(crates, M((0, 1.8, top + z)), 0.63, 0.05, seg=20, tseg=5)
    return [closed(coll, "ConveyorFrame", frame, GRAPHITE, hard=True), closed(coll, "ConveyorBelt", belt, DARK, hard=True),
            closed(coll, "ConveyorCrates", crates, (0.85, 0.62, 0.35), hard=True), closed(coll, "ConveyorStripes", stripes, HAZARD, hard=True)]


TORSO = [(0, 4.55), (0.85, 4.65), (1.12, 5.2), (1.25, 6.1), (1.2, 6.9), (0.95, 7.55), (0, 7.78)]


def build_robot_unit(coll):
    shell, joints, visor, stand, accent = (bmesh.new() for _ in range(5))
    # Assembly stand: a round platform and a back column whose clamp holds the robot.
    lathe(stand, [(0, 0), (2.9, 0), (2.9, 0.32), (2.72, 0.52), (0, 0.52)], 32)
    torus(accent, M((0, 0, 0.17)), 2.92, 0.07, seg=32, tseg=5)
    rounded_block(stand, (1.1, 0.9, 6.6), M((0, 1.9, 3.8)), corner=0.35, edge=0.0)
    rounded_block(stand, (1.3, 1.1, 0.35), M((0, 1.9, 7.2)), corner=0.4, edge=0.12)
    rounded_block(stand, (0.8, 1.2, 0.6), M((0, 1.05, 6.3)), corner=0.25, edge=0.15)
    # Legs.
    for side in (-1, 1):
        x = side * 0.62
        rounded_block(shell, (0.85, 1.3, 0.45), M((x, -0.15, 0.745)), corner=0.32, edge=0.18, corner_seg=2)
        blob(joints, Vector((x, 0.0, 1.08)), Vector((0.28, 0.28, 0.28)), subdivisions=2)
        capsule(shell, (x, 0, 1.25), (x, 0, 2.6), 0.36, 0.42, segments=10, cap_rings=2)
        blob(joints, Vector((x, 0, 2.85)), Vector((0.36, 0.36, 0.36)), subdivisions=2)
        blob(accent, Vector((x, -0.3, 2.88)), Vector((0.26, 0.14, 0.24)), subdivisions=1)
        capsule(shell, (x, 0, 3.05), (side * 0.6, 0, 4.15), 0.43, 0.46, segments=10, cap_rings=2)
    # Body: hips, an egg-shaped torso with a belt, chest badge and a glowing heart light.
    rounded_block(joints, (1.95, 1.15, 0.62), M((0, 0, 4.45)), corner=0.45, edge=0.28)
    squash = Matrix.Diagonal((1, 0.82, 1, 1))
    lathe(shell, TORSO, 24, squash)
    band(accent, TORSO, 4.72, 4.95, out=0.04, depth=0.1, segments=24, matrix=squash)
    blob(accent, Vector((0, -0.99, 6.25)), Vector((0.62, 0.13, 0.55)), subdivisions=2)
    cyl(visor, (0, -1.08, 6.3), 0.2, 0.08, 16, direction=(0, -1, 0))
    # Head: a rounded helmet with a dark face screen, glowing eyes and smile, ear discs and an antenna.
    cyl(joints, (0, 0, 7.6), 0.3, 0.55, 12)
    rounded_block(shell, (2.0, 1.75, 1.6), M((0, 0, 8.85)), corner=0.55, edge=0.42, corner_seg=3, edge_seg=3)
    panel(joints, (0, -0.86, 8.82), 1.32, 0.92, 0.14, corner=0.32, edge=0.05)
    for side in (-1, 1):
        blob(visor, Vector((side * 0.32, -0.95, 8.93)), Vector((0.16, 0.05, 0.21)), subdivisions=2)
        cyl(accent, (side * 0.98, 0, 8.85), 0.36, 0.16, 16, direction=(side, 0, 0))
    sweep(visor, [Vector((x, -0.95, 8.56 + 0.1 * (x / 0.28) ** 2)) for x in [-0.28 + 0.56 * k / 8 for k in range(9)]], 0.045, segments=6)
    cyl(joints, (0, 0, 9.6), 0.06, 0.7, 8)
    blob(accent, Vector((0, 0, 10.35)), Vector((0.17, 0.17, 0.17)), subdivisions=2)
    # Shoulders and arms: the left one relaxed, the right one raised in a wave.
    for side in (-1, 1):
        blob(joints, Vector((side * 1.38, 0, 7.15)), Vector((0.42, 0.42, 0.42)), subdivisions=2)
        blob(accent, Vector((side * 1.42, 0, 7.42)), Vector((0.58, 0.58, 0.4)), subdivisions=2)
    capsule(shell, (1.45, 0, 6.95), (1.65, 0.05, 5.75), 0.3, segments=10, cap_rings=2)
    blob(joints, Vector((1.66, 0.05, 5.55)), Vector((0.3, 0.3, 0.3)), subdivisions=2)
    capsule(shell, (1.68, 0.02, 5.4), (1.78, -0.22, 4.4), 0.32, 0.28, segments=10, cap_rings=2)
    cyl(accent, (1.765, -0.18, 4.62), 0.335, 0.2, 14, direction=(0.1, -0.24, -1.0))
    blob(shell, Vector((1.8, -0.27, 4.05)), Vector((0.28, 0.34, 0.38)), subdivisions=2)
    capsule(shell, (-1.45, 0, 7.15), (-2.3, -0.1, 7.95), 0.3, segments=10, cap_rings=2)
    blob(joints, Vector((-2.42, -0.12, 8.08)), Vector((0.3, 0.3, 0.3)), subdivisions=2)
    capsule(shell, (-2.44, -0.12, 8.25), (-2.55, -0.24, 9.65), 0.32, 0.28, segments=10, cap_rings=2)
    cyl(accent, (-2.54, -0.22, 9.3), 0.335, 0.2, 14, direction=(-0.11, -0.12, 1.4))
    rounded_block(shell, (0.72, 0.28, 0.72), M((-2.58, -0.27, 10.15)), corner=0.18, edge=0.1)
    for dx in (-0.22, 0.0, 0.22):
        capsule(shell, (-2.58 + dx, -0.27, 10.45), (-2.58 + dx * 1.25, -0.27, 10.88), 0.1, segments=6, cap_rings=2)
    capsule(shell, (-2.26, -0.27, 10.05), (-2.0, -0.3, 10.36), 0.1, segments=6, cap_rings=2)
    return [closed(coll, "RobotShell", shell, WHITE), closed(coll, "RobotJoints", joints, GRAPHITE),
            closed(coll, "RobotVisor", visor, CYAN), closed(coll, "RobotStand", stand, CONCRETE, hard=True),
            closed(coll, "RobotAccent", accent, ORANGE)]


def build_mega_factory(coll):
    walls, roof, vents, glow = (bmesh.new() for _ in range(4))
    # Main hall with pilasters, two bay doors on the front and a glowing window band all round.
    rounded_block(walls, (14.6, 12.0, 6.6), M((-1.7, 0, 3.3)), corner=0.25, edge=0.08, corner_seg=1, edge_seg=1)
    rounded_block(walls, (14.9, 12.3, 0.6), M((-1.7, 0, 0.3)), corner=0.3, edge=0.06, corner_seg=1, edge_seg=1)
    for x in (-8.4, -4.0, 0.4, 2.6, 4.8):
        box(walls, (x, -6.05, 3.3), (0.4, 0.3, 6.6))
    for x in (-8.4, -6.2, -4.0, -1.8, 0.4, 2.6, 4.8):
        box(walls, (x, 6.05, 3.3), (0.4, 0.3, 6.6))
    for y in (-4.0, 0.0, 4.0):
        box(walls, (-9.05, y, 3.3), (0.3, 0.4, 6.6))
    box(glow, (-1.7, -6.02, 5.5), (14.4, 0.06, 0.8))
    box(glow, (-1.7, 6.02, 5.5), (14.4, 0.06, 0.8))
    box(glow, (-9.02, 0, 5.5), (0.06, 11.8, 0.8))
    for xc in (-6.0, -2.0):
        box(vents, (xc, -6.04, 2.3), (3.0, 0.1, 4.4))
        for k in range(10):
            box(vents, (xc, -6.1, 0.5 + k * 0.42), (2.9, 0.06, 0.12))
        box(walls, (xc, -6.12, 4.65), (3.6, 0.25, 0.3))
        for side in (-1, 1):
            box(walls, (xc + side * 1.65, -6.12, 2.35), (0.3, 0.25, 4.6))
        box(glow, (xc, -6.2, 4.98), (1.6, 0.1, 0.12))
    # A cantilevered awning over the bays and a personnel door with its own light.
    rounded_block(roof, (8.4, 1.5, 0.22), M((-4.0, -6.85, 5.2), (0.08, 0, 0)), corner=0.15, edge=0.05, edge_seg=1)
    for x in (-7.6, -0.4):
        bar(vents, (x, -6.15, 4.55), (x, -7.45, 5.1), 0.12, 0.12, normal=(1, 0, 0))
    box(vents, (2.05, -6.04, 1.35), (1.2, 0.1, 2.5))
    box(walls, (2.05, -6.1, 2.68), (1.5, 0.22, 0.18))
    box(glow, (2.05, -6.12, 2.95), (0.7, 0.1, 0.12))
    # Sawtooth roof whose upright faces are glowing skylights, then a flat section carrying fans.
    for k in range(3):
        x0 = -9.0 + k * 11.0 / 3
        outline_prism(roof, [(x0, 6.6), (x0 + 11.0 / 3, 6.6), (x0 + 11.0 / 3, 8.9)], XZ, -6.15, 6.15)
        box(glow, (x0 + 11.0 / 3 + 0.03, 0, 7.75), (0.06, 11.6, 1.9))
    box(roof, (3.8, 0, 6.75), (3.6, 12.3, 0.3))
    for y in (-3.0, 2.6):
        rounded_block(vents, (2.4, 2.4, 0.7), M((3.8, y, 7.25)), corner=0.3, edge=0.08)
        torus(vents, M((3.8, y, 7.62)), 0.85, 0.1, seg=24, tseg=6)
        cyl(vents, (3.8, y, 7.55), 0.22, 0.2, 12)
        for b in range(4):
            box(vents, (3.8 + math.cos(b * math.pi / 2 + 0.4) * 0.45, y + math.sin(b * math.pi / 2 + 0.4) * 0.45, 7.66),
                (0.75, 0.24, 0.05), rotation=(0.35, 0, b * math.pi / 2 + 0.4))
    for x, y, h in ((-7.3, -3.5, 3.0), (-3.6, 3.2, 3.2)):
        cyl(vents, (x, y, 6.6), 0.35, h, 12)
        lathe(vents, [(0, 6.6 + h - 0.05), (0.62, 6.6 + h - 0.05), (0.62, 6.6 + h + 0.1), (0.2, 6.6 + h + 0.4), (0, 6.6 + h + 0.42)], 12,
              Matrix.Translation((x, y, 0)))
    # Side tower with glowing window strips, pipes, a rooftop stack and a beacon.
    rounded_block(walls, (4.0, 6.0, 13.0), M((7.6, -1.0, 6.5)), corner=0.3, edge=0.1, corner_seg=1, edge_seg=1)
    rounded_block(roof, (4.4, 6.4, 0.4), M((7.6, -1.0, 13.2)), corner=0.35, edge=0.06, corner_seg=1, edge_seg=1)
    for x in (6.5, 7.6, 8.7):
        box(glow, (x, -4.02, 5.5), (0.35, 0.06, 6.0))
    # A glowing gear emblem high on the tower front, and a big wall fan on the hall's far end.
    emblem = Matrix.Translation((7.6, -4.03, 10.4)) @ Matrix.Rotation(math.pi / 2, 4, "X")
    gear(glow, emblem, 1.35, 1.12, 0.75, 10, 0.1)
    cyl(glow, (7.6, -4.0, 10.4), 0.32, 0.1, 16, direction=(0, -1, 0))
    fan = Matrix.Translation((-9.12, 2.0, 3.0)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    torus(vents, fan, 1.45, 0.16, seg=32, tseg=6)
    cyl(vents, (-9.05, 2.0, 3.0), 0.35, 0.3, 14, direction=(-1, 0, 0))
    for b in range(5):
        a = b * 2 * math.pi / 5
        mbox(vents, Matrix.Translation((-9.2, 2.0 + math.cos(a) * 0.75, 3.0 + math.sin(a) * 0.75)) @ Matrix.Rotation(a - math.pi / 2, 4, "X")
             @ Matrix.Rotation(0.5, 4, "Z"), (0.06, 0.4, 1.25))
    loop_tube(glow, [Vector((x + 7.6, y - 1.0, 12.3)) for x, y in rounded_rect(4.0, 6.0, 0.3, 1)], rect_profile(-0.02, 0.05, -0.12, 0.12), (0, 0, 1))
    for y in (-2.6, -1.6):
        sweep(vents, [Vector((9.85, y, 0.0)), Vector((9.85, y, 12.4)), Vector((9.6, y, 12.9)), Vector((8.8, y, 13.0))], 0.2, segments=10)
        for z in (2.0, 6.0, 10.0):
            box(vents, (9.7, y, z), (0.35, 0.3, 0.2))
    cyl(vents, (8.4, 0.4, 13.4), 0.45, 0.9, 16)
    torus(vents, M((8.4, 0.4, 14.25)), 0.47, 0.07, seg=16, tseg=5)
    blob(glow, Vector((6.2, -3.4, 13.6)), Vector((0.2, 0.2, 0.2)), subdivisions=2)
    return [closed(coll, "FactoryWalls", walls, (0.82, 0.84, 0.88), hard=True), closed(coll, "FactoryRoof", roof, ROOF, hard=True),
            closed(coll, "FactoryVents", vents, STEEL, hard=True), closed(coll, "FactoryGlow", glow, (1.0, 0.75, 0.3), hard=True)]


# ---------- 5. Biodome Gardens ----------

def flower(bm, centre, normal, size=1.0):
    """A flat five-petal flower head facing along normal."""
    centre, normal = Vector(centre), Vector(normal).normalized()
    outline = [(size * (0.18 + 0.27 * abs(math.cos(2.5 * a))) * math.cos(a), size * (0.18 + 0.27 * abs(math.cos(2.5 * a))) * math.sin(a))
               for a in [2 * math.pi * k / 15 for k in range(15)]]
    outline_prism(bm, outline, Matrix.Translation(centre) @ align_z(normal), -0.06 * size, 0.06 * size)


def build_biodome(coll):
    frame, glass, plants, flowers, base = (bmesh.new() for _ in range(5))
    radius, squash, z0 = 6.2, 1.2, 1.05
    lathe(base, [(0, 0), (7.0, 0), (7.0, 0.55), (6.8, 0.8), (6.38, 0.88), (6.38, z0), (0, z0)], 40)
    # Geodesic frame: the struts of a frequency-4 hemisphere (an icosphere cut at its equator); the glass is
    # the same hemisphere as a thin shell just inside the struts, so each triangle reads as its own pane.
    for bm, scale in ((frame, 1.0), (glass, 0.985)):
        bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
        for v in bm.verts:
            v.co = Vector((v.co.x * radius * scale, v.co.y * radius * scale, z0 + max(0.0, v.co.z) * radius * squash * scale))
    bmesh.ops.solidify(glass, geom=glass.faces[:], thickness=0.06)
    bmesh.ops.wireframe(frame, faces=frame.faces[:], thickness=0.2, offset=0.0, use_replace=True, use_boundary=True, use_even_offset=True)
    torus(frame, M((0, 0, z0 + 0.08)), radius + 0.03, 0.17, seg=32, tseg=4)
    # Entrance vestibule on the front: a glass vault on arched ribs, a door frame, a landing and a step.
    arch = [math.pi * k / 10 for k in range(11)]
    for y in (-7.45, -6.7, -5.95):
        sweep(frame, [Vector((1.55 * math.cos(a), y, z0 + 1.7 * math.sin(a))) for a in arch], 0.12, segments=6)
    loft(glass, [[Vector((1.45 * math.cos(a), y, z0 + 1.6 * math.sin(a))) for a in arch] for y in (-7.5, -5.5)])
    loop_tube(frame, [Vector((x, -7.53, z0 + 0.75 + z)) for x, z in rounded_rect(1.2, 1.5, 0.45, 3)], rect_profile(-0.03, 0.09, -0.05, 0.05), (0, 1, 0))
    rounded_block(base, (3.6, 2.8, z0), M((0, -6.55, z0 / 2)), corner=0.4, edge=0.06, edge_seg=1)
    rounded_block(base, (2.6, 0.6, 0.55), M((0, -8.25, 0.275)), corner=0.15, edge=0.05, edge_seg=1)
    # Lush garden inside: a broad tree, a ring of bushes, banana-leaf clumps and flowers that read through the glass.
    lathe(plants, [(0, z0 - 0.02), (6.1, z0 - 0.02), (6.1, z0 + 0.1), (0, z0 + 0.1)], 32)
    sweep(plants, curve((0.3, 0.6, z0), (0.7, 0.3, 3.0), (0.1, 0.4, 5.0), 8), 0.45, segments=8, radius_end=0.26)
    for c, r, sub in (((0.1, 0.4, 6.0), (2.0, 2.0, 1.35), 3), ((1.4, 1.0, 5.4), (1.35, 1.35, 1.0), 3), ((-1.3, -0.1, 5.5), (1.35, 1.35, 1.0), 2),
                      ((0.3, -1.2, 5.3), (1.2, 1.2, 0.95), 2), ((-0.6, 1.5, 5.3), (1.15, 1.15, 0.9), 2)):
        blob(plants, Vector(c), Vector(r), subdivisions=sub, lump=0.16, seed=c[0])
    for a, z in ((0.3, 6.6), (2.2, 6.4), (4.1, 6.7), (5.4, 5.9), (1.2, 5.6)):
        flower(flowers, Vector((0.1 + math.cos(a) * 1.8, 0.4 + math.sin(a) * 1.8, z)), (math.cos(a), math.sin(a), 1.0), size=1.35)
    rng = random.Random(9)
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        if abs(math.sin(a) + 1) < 0.15:
            continue
        r = rng.uniform(0.85, 1.15)
        blob(plants, Vector((math.cos(a) * 4.3, math.sin(a) * 4.3, z0 + 0.6)), Vector((r, r, r * 0.8)), subdivisions=2, lump=0.2, seed=k)
        for n in range(2):
            b = a + rng.uniform(-0.5, 0.5)
            p = Vector((math.cos(b) * 4.3, math.sin(b) * 4.3, z0 + 0.6)) + Vector((math.cos(b), math.sin(b), 1.1)).normalized() * r * 0.9
            flower(flowers, p, (math.cos(b) * 0.6, math.sin(b) * 0.6, 1), size=1.5)
    for a0 in (0.9, 2.9, 4.6):
        hub = Vector((math.cos(a0) * 2.6, math.sin(a0) * 2.6, z0 + 0.1))
        for k in range(3):
            a = a0 + 2 * math.pi * k / 3
            leaf(plants, hub, (math.cos(a), math.sin(a)), 2.2, 0.65, rise=1.6, droop=1.0, cup=0.2, thickness=0.1, steps=6, roundness=0.7)
        lathe(flowers, [(0, 0), (0.32, 0.25), (0.28, 0.75), (0.24, 1.2), (0.14, 1.6), (0, 1.85)], 10,
              Matrix.Translation(hub + Vector((0, 0, 1.3))), wobble=0.06, seed=a0)
        sweep(plants, [hub, hub + Vector((0, 0, 1.4))], 0.07, segments=6)
    return [closed(coll, "BiodomeFrame", frame, WHITE, hard=True), closed(coll, "BiodomeGlass", glass, (0.6, 0.85, 0.95), hard=True),
            closed(coll, "BiodomePlants", plants, LEAF), closed(coll, "BiodomeFlowers", flowers, MAGENTA),
            closed(coll, "BiodomeBase", base, CONCRETE, hard=True)]


BULB = [(0, 0), (0.42, 0.1), (0.72, 0.5), (0.78, 0.95), (0.6, 1.35), (0.28, 1.68), (0.06, 1.95), (0, 2.0)]


def build_alien_plant(coll):
    stalks, leaves, bulbs = bmesh.new(), bmesh.new(), bmesh.new()
    rng = random.Random(11)
    blob(leaves, Vector((0, 0, 0.3)), Vector((1.3, 1.3, 0.6)), subdivisions=2, lump=0.15, floor=0.0)
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.2, 0.2)
        leaf(leaves, (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.65), (math.cos(a), math.sin(a)), rng.uniform(4.0, 4.6), 1.25,
             rise=1.0, droop=1.2, cup=0.22, thickness=0.14, wave=0.13, waves=1.5, steps=12, roundness=0.6)
    # Five stalks rising in S-curves, each topped by a glowing onion-shaped pod in a little cup,
    # some with curling tendrils and small glowing berries.
    for k, (h, reach, size) in enumerate(((13.0, 1.3, 1.15), (10.4, 2.6, 0.95), (11.8, 1.9, 1.05), (9.0, 3.0, 0.85), (12.2, 2.2, 1.0))):
        a = 2 * math.pi * k / 5 + 0.3
        d = Vector((math.cos(a), math.sin(a), 0))
        tip = d * reach + Vector((0, 0, h - 2.0 * size))
        path = curve(d * 0.25 + Vector((0, 0, 0.4)), d * (reach * 0.05) + Vector((0, 0, h * 0.45)), d * (reach * 1.35) + Vector((0, 0, h * 0.72)), 16, p3=tip)
        sweep(stalks, path, 0.32, segments=8, radius_end=0.14)
        tangent = (path[-1] - path[-2]).normalized()
        cup = Matrix.Translation(tip) @ align_z(tangent)
        lathe(stalks, [(0, -0.3), (0.2, -0.25), (0.5, 0.05), (0.56, 0.2), (0.4, 0.22), (0, 0.05)], 10, cup)
        lathe(bulbs, [(r * size, z * size) for r, z in BULB], 14, cup @ Matrix.Translation((0, 0, 0.02)))
        if k % 2 == 0:
            q = path[8]
            curl = []
            for i in range(20):
                u = i / 19
                phi = math.pi - u * 2.6 * math.pi
                rho = 0.95 * (1 - u) + 0.12
                curl.append(q + d * (0.95 + rho * math.cos(phi)) + Vector((0, 0, rho * math.sin(phi))))
            sweep(stalks, curl, 0.11, segments=5, radius_end=0.05)
            blob(bulbs, curl[-1], Vector((0.2, 0.2, 0.2)), subdivisions=1)
        p = path[8 if k % 2 else 10]
        side = Vector((-d.y, d.x, 0))
        end = p + side * (0.75 if k % 2 else -0.75) + Vector((0, 0, 0.45))
        sweep(stalks, [p, p + (end - p) * 0.5 + Vector((0, 0, 0.15)), end], 0.07, segments=5, radius_end=0.05)
        blob(bulbs, end + Vector((0, 0, 0.12)), Vector((0.24, 0.24, 0.28)), subdivisions=1)
    return [closed(coll, "AlienPlantStalks", stalks, (0.35, 0.2, 0.55)), closed(coll, "AlienPlantLeaves", leaves, (0.2, 0.6, 0.5)),
            closed(coll, "AlienPlantBulbs", bulbs, LIME)]


# ---------- filler ----------

def build_planter(coll):
    body, glow, bush = bmesh.new(), bmesh.new(), bmesh.new()
    # A flared tub with a rounded rim and a recessed soil bed, on a smaller foot so it seems to hover.
    width, depth, corner, flare = 5.6, 3.4, 1.2, 0.05

    def ring(z, inset):
        s = 1 + flare * (z - 0.3) / 1.55
        return [Vector((x, y, z)) for x, y in rounded_rect(width * s - 2 * inset, depth * s - 2 * inset, corner * s - inset, 6)]
    levels = [(0.3 + 0.12 - 0.12 * math.sin(math.pi / 2 * k / 3), 0.12 * (1 - math.cos(math.pi / 2 * k / 3))) for k in (3, 2, 1, 0)]
    levels += [(1.73 + 0.12 * math.sin(math.pi / 2 * k / 3), 0.12 * (1 - math.cos(math.pi / 2 * k / 3))) for k in (0, 1, 2, 3)]
    levels += [(1.85, 0.24), (1.8, 0.3), (1.58, 0.32)]
    loft(body, [ring(z, inset) for z, inset in levels])
    rounded_block(body, (5.0, 2.8, 0.34), M((0, 0, 0.17)), corner=0.95, edge=0.05, corner_seg=6, edge_seg=1)
    loop_tube(glow, [Vector((x, y, 0.2)) for x, y in rounded_rect(5.02, 2.82, 0.96, 6)], rect_profile(-0.02, 0.04, -0.06, 0.06), (0, 0, 1))
    loop_tube(glow, [p + Vector((0, 0, 0)) for p in ring(1.52, 0.0)], rect_profile(-0.03, 0.035, -0.07, 0.07), (0, 0, 1))
    # A leafy shrub: small cupped leaves shingled over a soft dome, tips curling outward and down.
    rng = random.Random(6)
    core, radii = Vector((0, 0, 1.7)), Vector((2.3, 1.3, 1.75))
    blob(bush, core, radii * 0.9, subdivisions=3, floor=1.6)
    count = 58
    for k in range(count):
        zf = max(-0.2, min(1.0, 1 - (k + 0.5) / count * 1.2 + rng.uniform(-0.05, 0.05)))
        ring = math.sqrt(max(0.0, 1 - zf * zf))
        a = k * 2.39996 + rng.uniform(-0.25, 0.25)
        unit = Vector((ring * math.cos(a), ring * math.sin(a), zf))
        p = core + Vector((unit.x * radii.x, unit.y * radii.y, unit.z * radii.z))
        normal = Vector((unit.x / radii.x, unit.y / radii.y, unit.z / radii.z)).normalized()
        down = Vector((0, 0, -1)) - normal * -normal.z
        if down.length < 0.2:
            down = Vector((math.cos(a), math.sin(a), 0)) - normal * normal.dot(Vector((math.cos(a), math.sin(a), 0)))
        down.normalize()
        across = normal.cross(down)
        direction = (down + across * rng.uniform(-0.9, 0.9) + normal * rng.uniform(0.2, 0.6)).normalized()
        card_leaf(bush, p - direction * 0.35 - normal * 0.08, direction, normal, rng.uniform(0.95, 1.35), rng.uniform(0.42, 0.56),
                  bend=rng.uniform(0.15, 0.4), cup=0.3, thickness=0.08)
    return [closed(coll, "PlanterBox", body, WHITE, hard=True), closed(coll, "PlanterGlow", glow, CYAN),
            closed(coll, "PlanterLeaves", bush, LEAF)]


BUILDERS = [
    ("EcoHouse", build_eco_house), ("WindTurbine", build_wind_turbine), ("SolarTree", build_solar_tree),
    ("HoverCar", build_hover_car), ("MaglevPylon", build_maglev_pylon), ("HoloSign", build_holo_sign), ("Viaduct", build_viaduct),
    ("HoloBillboard", build_holo_billboard), ("NeoLamp", build_neo_lamp), ("Skyscraper", build_skyscraper),
    ("RobotArm", build_robot_arm), ("Conveyor", build_conveyor), ("RobotUnit", build_robot_unit), ("MegaFactory", build_mega_factory),
    ("Biodome", build_biodome), ("AlienPlant", build_alien_plant),
    ("Planter", build_planter),
]


def fresh_city_collection():
    """fresh_collection, also freeing the old meshes so repeated runs do not pile up orphan data."""
    coll = bpy.data.collections.get(COLLECTION)
    old_meshes = [o.data for o in coll.objects if o.type == "MESH"] if coll else []
    coll = fresh_collection(COLLECTION)
    for mesh in old_meshes:
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    return coll


def build_and_export(only=None, export=True):
    global MANIFEST
    coll = fresh_city_collection()
    layer = bpy.context.view_layer.layer_collection.children.get(COLLECTION)
    if layer:
        layer.exclude = False
    objects, manifest = [], {}
    for index, (prop, builder) in enumerate(BUILDERS):
        if only and prop not in only:
            continue
        group = builder(coll)
        # Rest on z = 0 with the footprint centred on the origin.
        lo = Vector((min(v.co[i] for o in group for v in o.data.vertices) for i in range(3)))
        hi = Vector((max(v.co[i] for o in group for v in o.data.vertices) for i in range(3)))
        shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
        slot = index if not only else list(only).index(prop)
        for obj in group:
            obj.data.transform(Matrix.Translation(shift))
            triangulate_ngons(obj)
            obj.location.x += (slot % 6) * 26.0
            obj.location.y += (slot // 6) * 30.0
            objects.append(obj)
            if "." in obj.name:
                print("NAME CLASH:", obj.name)
        manifest[prop] = [o.name for o in group]
        size = hi - lo
        print(prop, "tris", sum(triangles(o) for o in group), "size", tuple(round(c, 2) for c in size),
              {o.name: triangles(o) for o in group})
    for obj in objects:
        if max(obj.dimensions) > 20.0:
            print("TOO BIG:", obj.name, tuple(round(d, 2) for d in obj.dimensions))
    MANIFEST = manifest
    print("triangles:", sum(triangles(o) for o in objects))
    if only or not export:
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


build_and_export(globals().get("ONLY"), globals().get("EXPORT", True))
