# World 4 (Tiny Town) runway props, home half: themed sections 1-5 in one batch.
#   Giant Backyard:        GrassBlade, HoseReel, Sprinkler, Ladybug   filler Pebble       backdrop GiantFence
#   Picnic Blanket:        Sandwich, AntLine, PicnicBasket            filler Crumbs       backdrop BlanketFolds
#   Kitchen Counter:       CuttingBoard, Toaster, Faucet              filler CerealPiece  backdrop CerealHills
#   Block Town:            AlphabetBlock, TrainTrack, BrickTower      filler ToyBrick     (BrickTower doubles as the skyline)
#   Board Game Boulevard:  GiantDie, PlayingCard, GamePiece           filler ChessPawn    backdrop BoardGameBox
# The player is shrunk to bug size, so everyday things are huge: bright toy colours, soft rounded shapes.
# Same conventions as runway_world3_city.py, whose helper half this script runs (with World 2's helpers
# and the shared prop_helpers): run inside Blender (e.g. via MCP); one mesh per colour role, named
# <Template><Part>; each model rests on z = 0 with its footprint centred on the origin; props with a
# front face -Y (RunwayDecor turns them to the tee). Every mesh stays under 20 units so Roblox's 100x FBX
# import stays below its 2048-stud part limit; backdrops are scaled up in RunwayDecor. A manifest
# (template -> mesh names) is written beside the FBX for grouping after import
# (tools/studio/group_runway_imports.luau). Preview colours only: RunwayDecor tints every part in Roblox.
# Set EXPORT = False (and optionally ONLY = [template names]) before exec() to build without exporting.
import bpy, bmesh, math, os, random, json
from mathutils import Vector, Matrix, Euler, noise

RUNWAY_WORLD3_CITY = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\runway_world3_city.py"
_source = open(RUNWAY_WORLD3_CITY, encoding="utf-8").read()
_marker = "# ---------- 1. Solar Suburbs ----------"
assert _marker in _source, "runway_world3_city.py layout changed"
exec(_source.partition(_marker)[0])

COLLECTION = "RunwayWorld4Home"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayWorld4Home.fbx"
MANIFEST_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayWorld4Home.json"

GRASS_DARK = (0.18, 0.55, 0.16)
GRASS_LIGHT = (0.45, 0.8, 0.25)
TOY_RED = (0.9, 0.16, 0.14)
TOY_YELLOW = (1.0, 0.8, 0.1)
TOY_BLUE = (0.15, 0.4, 0.9)
TOY_GREEN = (0.2, 0.7, 0.3)
TOY_ORANGE = (1.0, 0.5, 0.1)
INK = (0.06, 0.05, 0.06)
CREAM_WHITE = (0.97, 0.95, 0.9)
BREAD = (0.93, 0.74, 0.44)
CRUST = (0.62, 0.36, 0.16)
WATER = (0.55, 0.82, 1.0)
CHROME = (0.78, 0.8, 0.84)
BEECH = (0.86, 0.66, 0.42)
PEBBLE = (0.62, 0.6, 0.58)


# ---------- extra helpers for soft toy shapes ----------

def ball(bm, center, size, subdivisions=2, floor=None):
    """An ellipsoid (size = radii per axis); floor flattens anything below that z."""
    size = Vector(size) if not isinstance(size, (int, float)) else Vector((size, size, size))
    return blob(bm, Vector(center), size, subdivisions=subdivisions, floor=floor)


def soft_box(bm, center, size, corner=0.4, edge=0.3, rotation=(0, 0, 0), **options):
    """A rounded box centred on center (corner: vertical corners, edge: top and bottom edges)."""
    rounded_block(bm, size, M(center, rotation), corner=corner, edge=edge, **options)


def path_extrude(bm, points, profile, up=(0, 0, 1)):
    """Loft a closed 2D profile (u across, v up) along a mostly horizontal path (tracks, rails, cloth edges)."""
    up = Vector(up)
    sections = []
    n = len(points)
    for i, p in enumerate(points):
        tangent = (Vector(points[min(i + 1, n - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
        side = tangent.cross(up).normalized()
        sections.append([Vector(p) + side * u + up * v for u, v in profile])
    loft(bm, sections)


def grass_blade(bm, base, lean, height, width, thick=0.32, cup=0.35, steps=10):
    """A tall tapering grass blade rising from base and arching over toward lean (a horizontal direction)."""
    lean = Vector((lean[0], lean[1], 0)).normalized()
    side = Vector((-lean.y, lean.x, 0))
    base = Vector(base)
    points = [base + Vector((0, 0, height * (t - 0.22 * t ** 3))) + lean * (height * 0.45 * t ** 2.2)
              for t in [i / steps for i in range(steps + 1)]]
    sections = []
    for i, c in enumerate(points):
        t = i / steps
        tangent = (points[min(i + 1, steps)] - points[max(i - 1, 0)]).normalized()
        normal = side.cross(tangent).normalized()
        w = width * (1 - t ** 1.5) * (0.85 + 0.15 * math.sin(math.pi * min(1, t * 3))) + 0.03
        h = thick * (1 - 0.75 * t) + 0.02
        sections.append([c - side * w + normal * (cup * w), c + normal * h, c + side * w + normal * (cup * w), c - normal * (h * 0.4)])
    loft(bm, sections)
    return points


def ruffle(bm, center, radius, thickness, waves, amplitude, squareness=2.0, rings=5, segments=48, droop=0.0):
    """A frilly disc (lettuce, doilies): its edge waves up and down; squareness > 2 follows a square outline."""
    center = Vector(center)

    def shape(a):
        c, s = abs(math.cos(a)), abs(math.sin(a))
        return 1.0 / ((c ** squareness + s ** squareness) ** (1.0 / squareness))
    top, bottom = [], []
    for ring in range(1, rings + 1):
        f = ring / rings
        row_t, row_b = [], []
        for k in range(segments):
            a = 2 * math.pi * k / segments
            r = radius * f * shape(a)
            z = amplitude * math.sin(waves * a) * f ** 2 - droop * f ** 3
            p = center + Vector((r * math.cos(a), r * math.sin(a), z))
            row_t.append(bm.verts.new(p + Vector((0, 0, thickness / 2))))
            row_b.append(bm.verts.new(p - Vector((0, 0, thickness / 2))))
        top.append(row_t)
        bottom.append(row_b)
    ct = bm.verts.new(center + Vector((0, 0, thickness / 2)))
    cb = bm.verts.new(center - Vector((0, 0, thickness / 2)))
    for k in range(segments):
        j = (k + 1) % segments
        bm.faces.new((ct, top[0][k], top[0][j]))
        bm.faces.new((cb, bottom[0][j], bottom[0][k]))
        for r in range(rings - 1):
            bm.faces.new((top[r][k], top[r + 1][k], top[r + 1][j], top[r][j]))
            bm.faces.new((bottom[r][j], bottom[r + 1][j], bottom[r + 1][k], bottom[r][k]))
        bm.faces.new((top[-1][k], bottom[-1][k], bottom[-1][j], top[-1][j]))


def sheet(coll, name, quads, rgb):
    """An open surface from quads (four points each, any winding), turned to face upward."""
    bm = bmesh.new()
    for quad in quads:
        verts = [bm.verts.new(p) for p in quad]
        face = bm.faces.new(verts)
        face.normal_update()
        if face.normal.z < 0:
            face.normal_flip()
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    return make_object(coll, name, bm, rgb)


def stud_brick(bm, center, cols, rows, pitch=1.6, height=1.9, turn=0.0, studs=True):
    """A building brick of cols x rows studs: a soft box with round studs on top, centred on center (base)."""
    center = Vector(center)
    rot = Matrix.Rotation(turn, 4, "Z")
    w, d = cols * pitch - 0.04, rows * pitch - 0.04
    rounded_block(bm, (w, d, height), Matrix.Translation(center + Vector((0, 0, height / 2))) @ rot,
                  corner=0.12, edge=0.08, corner_seg=1, edge_seg=1)
    if studs:
        for i in range(cols):
            for j in range(rows):
                local = Vector((-w / 2 + pitch * (i + 0.5), -d / 2 + pitch * (j + 0.5), 0))
                p = center + rot.to_3x3() @ local + Vector((0, 0, height - 0.02))
                cyl(bm, p, 0.48, 0.36, segments=12)


def face_matrix(center, normal, up=(0, 0, 1)):
    """A matrix at center whose local X is the face's right, Y its up and Z its outward normal."""
    n = Vector(normal).normalized()
    u = Vector(up)
    if abs(n.dot(u)) > 0.9:
        u = Vector((0, 1, 0))
    right = u.cross(n).normalized()
    upv = n.cross(right).normalized()
    m = Matrix((right, upv, n)).transposed().to_4x4()
    m.translation = Vector(center)
    return m


def stroke(bm, matrix, points, width, depth):
    """A raised letter stroke: a rounded bar along 2D points on a face (matrix from face_matrix)."""
    world = [matrix @ Vector((x, y, depth / 2)) for x, y in points]
    normal = matrix.to_3x3() @ Vector((0, 0, 1))
    beam(bm, world, (width, depth), ref=normal, corner=0.3, seg=1)


def arc2(cx, cy, r, a0, a1, count):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / (count - 1))),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / (count - 1)))) for i in range(count)]


LETTERS = {
    "A": [[(-0.62, -0.8), (0, 0.8)], [(0, 0.8), (0.62, -0.8)], [(-0.34, -0.14), (0.34, -0.14)]],
    "B": [[(-0.48, -0.8), (-0.48, 0.8)],
          [(-0.48, 0.8)] + arc2(0.08, 0.42, 0.38, 90, -90, 9) + [(-0.48, 0.04)],
          [(-0.48, 0.04)] + arc2(0.12, -0.38, 0.42, 90, -90, 9) + [(-0.48, -0.8)]],
    "C": [arc2(0.05, 0, 0.75, 50, 310, 14)],
}


def letter_face(bm, center, normal, half, letter, up=(0, 0, 1), depth=0.22):
    matrix = face_matrix(center, normal, up)
    scale = half * 0.62
    for points in LETTERS[letter]:
        stroke(bm, matrix, [(x * scale, y * scale) for x, y in points], half * 0.2, depth)


def heart_outline(size, n=28, flip=False):
    """Counter-clockwise (x, y) points of a heart about size wide, centred (flip: upside down, for a spade)."""
    points = []
    for i in range(n):
        t = -2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        points.append((x * size / 34, (y + 3) * size / 34 * (-1 if flip else 1)))
    if flip:
        points.reverse()
    return points


# ---------- 1. Giant Backyard ----------

def build_grass_blade(coll):
    dark, light, dew = bmesh.new(), bmesh.new(), bmesh.new()
    rng = random.Random(41)
    blades = [(0.0, 0.0, 18.5, 1.25), (1.6, 1.1, 15.5, 1.1), (-1.7, 0.7, 16.5, 1.15), (0.9, -1.7, 13.0, 1.0),
              (-1.0, -1.4, 11.5, 0.95), (2.4, -0.5, 10.0, 0.9), (-2.6, -0.4, 12.5, 1.0)]
    tips = []
    for k, (x, y, height, width) in enumerate(blades):
        a = math.atan2(y, x) if (x or y) else 0.6
        lean = (math.cos(a + rng.uniform(-0.5, 0.5)), math.sin(a + rng.uniform(-0.5, 0.5)))
        points = grass_blade(dark if k % 2 == 0 else light, (x, y, -0.2), lean, height, width)
        tips.append(points)
    # A soft clump hides the roots; dew drops hang on two blades.
    ball(dark, (0, 0, 0.2), (2.6, 2.2, 0.9), floor=0.0)
    for points, t in ((tips[0], 6), (tips[2], 5)):
        p = points[t]
        lathe(dew, [(0, -0.62), (0.42, -0.42), (0.5, -0.05), (0.3, 0.32), (0, 0.6)], 12, Matrix.Translation(p + Vector((0, -0.55, -0.2))))
    return [closed(coll, "GrassBlades", dark, GRASS_DARK), closed(coll, "GrassBladesLight", light, GRASS_LIGHT),
            closed(coll, "GrassDew", dew, WATER)]


def build_hose_reel(coll):
    frame, drum, hose, nozzle = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    axle_z = 5.6
    # Two A-frame side legs with a handle bar over the top and a pair of little wheels.
    for x in (-2.9, 2.9):
        beam(frame, [(x, -2.4, 0.4), (x, 0, axle_z), (x, 1.6, axle_z + 3.4)], (0.7, 0.7), ref=(1, 0, 0), corner=0.45)
        beam(frame, [(x, 2.6, 0.2), (x, 0.6, axle_z - 0.6)], (0.6, 0.6), ref=(1, 0, 0), corner=0.45)
        cyl(frame, (x * 1.1, -2.4, 0.9), 0.95, 0.5, segments=16, direction=(1 if x > 0 else -1, 0, 0))
    capsule(frame, (-3.2, 1.6, axle_z + 3.4), (3.2, 1.6, axle_z + 3.4), 0.42)
    capsule(frame, (-3.1, 0, axle_z), (3.1, 0, axle_z), 0.32)
    # The drum: a spool with flanges, wrapped in hose.
    yz = Matrix.Translation((0, 0, axle_z)) @ align_z(Vector((1, 0, 0)))
    lathe(drum, [(0, -2.5), (3.6, -2.5), (3.6, -2.1), (1.4, -2.1), (1.4, 2.1), (3.6, 2.1), (3.6, 2.5), (0, 2.5)], 28, yz)
    turns = 5
    for layer in range(2):
        for k in range(turns):
            x = -1.7 + 3.4 * k / (turns - 1) + layer * 0.2
            torus(hose, Matrix.Translation((x, 0, axle_z)) @ align_z(Vector((1, 0, 0))), 1.85 + layer * 0.72, 0.36, seg=28, tseg=8)
    # The loose end runs down, curls across the ground toward the batter and ends in a spray nozzle.
    path = curve((1.6, -2.3, axle_z - 1.5), (2.2, -5.2, 0.1), (-1.5, -6.5, 0.38), count=10)
    path += curve((-1.5, -6.5, 0.38), (-4.6, -7.2, 0.38), (-2.6, -9.4, 0.38), count=8)[1:]
    sweep(hose, path, 0.38, segments=10)
    end = path[-1]
    direction = (path[-1] - path[-2]).normalized()
    capsule(nozzle, end, end + direction * 2.2, 0.55, 0.42)
    capsule(nozzle, end + direction * 0.7, end + direction * 0.7 + Vector((0, 0, 0.0)) + Vector((-direction.y, direction.x, 0)) * 1.6, 0.32)
    cyl(nozzle, end + direction * 2.1, 0.6, 0.35, segments=14, direction=direction)
    return [closed(coll, "HoseReelFrame", frame, TOY_RED, hard=True), closed(coll, "HoseReelDrum", drum, TOY_YELLOW, hard=True),
            closed(coll, "HoseTube", hose, TOY_GREEN), closed(coll, "HoseNozzle", nozzle, TOY_ORANGE)]


def build_sprinkler(coll):
    body, metal, water = bmesh.new(), bmesh.new(), bmesh.new()
    # A stake in a round base, a tall riser and a turning head with its spray arm.
    lathe(body, [(0, 0), (2.4, 0), (2.4, 0.5), (1.6, 0.9), (0.55, 1.2), (0, 1.2)], 24)
    cyl(metal, (0, 0, 1.0), 0.32, 6.6, segments=12)
    lathe(body, [(0, 7.2), (0.95, 7.2), (1.05, 7.6), (0.8, 8.4), (0, 8.6)], 18)
    capsule(metal, (0, 0, 8.4), (2.1, 0, 9.4), 0.3)
    capsule(body, (-0.3, 0, 8.8), (-1.8, 0, 8.6), 0.36)
    ball(body, (-2.0, 0, 8.6), (0.55, 0.5, 0.5), subdivisions=2)
    cyl(metal, (2.1, 0, 9.4), 0.38, 0.6, segments=12, direction=(1, 0, 0.45))
    # Water: three arcs fanning out from the nozzle, each breaking into drops near the ground.
    start = Vector((2.5, 0, 9.6))
    for k, turn in enumerate((-0.42, 0.0, 0.42)):
        d = Vector((math.cos(turn), math.sin(turn), 0))
        reach = 7.4 - abs(turn) * 2.0
        points = [start + d * (reach * t) + Vector((0, 0, 3.2 * t * (1 - t) * 2.2 - 8.6 * t * t)) for t in [i / 11 for i in range(9)]]
        sweep(water, points, 0.36, segments=8, radius_end=0.2)
        for j, t in enumerate((0.9, 1.0)):
            p = start + d * (reach * t) + Vector((0, 0, 3.2 * t * (1 - t) * 2.2 - 8.6 * t * t))
            ball(water, p, 0.32 - j * 0.06, subdivisions=1)
    return [closed(coll, "SprinklerBody", body, TOY_YELLOW), closed(coll, "SprinklerMetal", metal, CHROME, hard=True),
            closed(coll, "SprinklerWater", water, WATER)]


def build_ladybug(coll):
    shell, spots, dark, eyes = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    rx, ry, rz, base = 4.0, 5.0, 3.4, 1.4
    # The domed shell, its two halves parted by a dark seam down the back.
    ball(shell, (0, 0.4, base), (rx, ry, rz), subdivisions=4, floor=base)
    seam = [Vector((0, 0.4 + ry * math.cos(a), base + rz * math.sin(a) + 0.06)) for a in [math.radians(15 + 150 * i / 14) for i in range(15)]]
    sweep(dark, seam, 0.16, segments=6)
    ball(dark, (0, 0.4, base + 0.1), (rx * 0.97, ry * 0.97, 0.6), subdivisions=3)
    for sx, sy in ((1.9, -1.8), (2.6, 0.9), (1.4, 3.2), (3.4, 2.8), (1.0, -0.2)):
        for side in (-1, 1):
            x, y = side * sx, sy + 0.4
            u = (x / rx) ** 2 + ((y - 0.4) / ry) ** 2
            if u >= 0.92:
                continue
            z = base + rz * math.sqrt(1 - u)
            n = Vector((x / rx ** 2, (y - 0.4) / ry ** 2, (z - base) / rz ** 2)).normalized()
            p = Vector((x, y, z))
            transform = Matrix.Translation(p) @ align_z(n)
            lathe(spots, [(0, -0.2), (0.75, -0.2), (0.72, 0.1), (0.4, 0.2), (0, 0.22)], 14, transform)
    # Head, big friendly eyes, antennae and six little legs.
    ball(dark, (0, -4.4, base + 0.9), (2.2, 1.6, 1.6), subdivisions=3)
    for side in (-1, 1):
        ball(eyes, (side * 0.95, -5.55, base + 1.35), (0.62, 0.42, 0.66), subdivisions=2)
        ball(dark, (side * 0.95, -5.9, base + 1.3), (0.3, 0.16, 0.34), subdivisions=1)
        antenna = curve((side * 0.7, -5.0, base + 2.2), (side * 1.4, -6.2, base + 4.2), (side * 2.4, -6.6, base + 4.6), count=8)
        sweep(dark, antenna, 0.14, segments=6)
        ball(dark, antenna[-1], 0.38, subdivisions=1)
        for k, y in enumerate((-2.4, 0.0, 2.4)):
            leg = [Vector((side * 2.6, y, base + 0.4)), Vector((side * 4.3, y - 0.3, base + 0.9)), Vector((side * 5.0, y - 0.6, 0.3))]
            sweep(dark, curve(leg[0], leg[1], leg[2], count=7), 0.24, segments=6, radius_end=0.18)
            ball(dark, leg[2] + Vector((0, 0, -0.05)), (0.35, 0.45, 0.25), subdivisions=1, floor=0.0)
    return [closed(coll, "LadybugShell", shell, TOY_RED), closed(coll, "LadybugSpots", spots, INK),
            closed(coll, "LadybugBody", dark, (0.1, 0.09, 0.1)), closed(coll, "LadybugEyes", eyes, CREAM_WHITE)]


def build_pebble(coll):
    a, b = bmesh.new(), bmesh.new()
    for k, (x, y, sx, sy, sz) in enumerate(((0, 0, 2.2, 1.7, 1.3), (2.6, 1.1, 1.3, 1.1, 0.85), (-2.4, 0.9, 1.1, 0.9, 0.7),
                                            (1.2, -1.8, 0.8, 0.7, 0.5))):
        target = a if k % 2 == 0 else b
        blob(target, Vector((x, y, sz * 0.55)), Vector((sx, sy, sz)), subdivisions=3, lump=0.12, seed=k * 3.1, floor=0.0)
    return [closed(coll, "PebbleStoneA", a, PEBBLE), closed(coll, "PebbleStoneB", b, (0.75, 0.7, 0.62))]


def build_giant_fence(coll):
    pickets, rails, grass = bmesh.new(), bmesh.new(), bmesh.new()
    # A picket-fence panel standing along Y (so a row of them lines the runway), pointed tops.
    rng = random.Random(7)
    for k in range(5):
        y = -7.2 + 3.6 * k
        top = 15.2 + rng.uniform(-0.6, 0.6)
        outline = [(y - 1.4, 0.0), (y + 1.4, 0.0), (y + 1.4, top), (y, top + 1.9), (y - 1.4, top)]
        outline_prism(pickets, outline, YZ, -0.35, 0.35)
    for z in (3.6, 11.4):
        mbox(rails, M((0.9, 0, z)), (0.7, 18.6, 1.6))
    for k in range(9):
        y = -8.0 + 2.0 * k + rng.uniform(-0.4, 0.4)
        for j in range(3):
            a = rng.uniform(0, 2 * math.pi)
            grass_blade(grass, (rng.uniform(-1.2, 0.6), y + rng.uniform(-0.6, 0.6), -0.1), (math.cos(a), math.sin(a)),
                        rng.uniform(2.2, 4.0), 0.32, thick=0.12, steps=6)
    return [closed(coll, "FencePickets", pickets, CREAM_WHITE, hard=True), closed(coll, "FenceRails", rails, (0.85, 0.84, 0.8), hard=True),
            closed(coll, "FenceGrass", grass, GRASS_LIGHT)]


# ---------- 2. Picnic Blanket ----------

def build_sandwich(coll):
    bread, crust, lettuce, tomato, cheese, pick = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    size, slab = 11.0, 1.5
    z = 0.0
    # A double-decker: bread, lettuce, tomato, cheese, bread, lettuce, cheese, bread.
    layers = ["bread", "lettuce", "tomato", "cheese", "bread", "lettuce", "cheese", "bread"]
    rng = random.Random(3)
    for index, layer in enumerate(layers):
        twist = rng.uniform(-0.06, 0.06)
        if layer == "bread":
            rounded_block(bread, (size, size, slab), M((0, 0, z + slab / 2), (0, 0, twist)), corner=1.6, edge=0.55, corner_seg=4, edge_seg=2)
            ring = [Vector((x, y, 0)) for x, y in rounded_rect(size + 0.04, size + 0.04, 1.62, 4)]
            rot = Matrix.Rotation(twist, 3, "Z")
            loop_tube(crust, [rot @ p + Vector((0, 0, z + slab / 2)) for p in ring], rect_profile(-0.02, 0.16, -0.5, 0.5), (0, 0, 1))
            z += slab
        elif layer == "lettuce":
            ruffle(lettuce, (0, 0, z + 0.2), size * 0.6, 0.22, 9, 0.35, squareness=4.0, droop=0.5)
            z += 0.35
        elif layer == "tomato":
            for x, y in ((-2.6, -2.4), (2.7, -2.1), (-2.2, 2.8), (2.6, 2.7)):
                cyl(tomato, (x * 1.15, y * 1.15, z), 2.6, 0.6, segments=20)
            z += 0.6
        elif layer == "cheese":
            square = [Vector((x, y, 0)) for x, y in rounded_rect(size * 0.98, size * 0.98, 0.3, 1)]
            rot = Matrix.Rotation(math.pi / 4 + twist, 3, "Z")
            outline = [(rot @ p).to_2d() for p in square]
            prism(cheese, outline, z, z + 0.28)
            # The cheese's corners droop over the edges.
            for v in cheese.verts:
                r = max(abs(v.co.x), abs(v.co.y))
                if r > size / 2 and abs(v.co.z - z) < 0.5:
                    v.co.z -= (r - size / 2) * 0.9
            z += 0.3
    # A cocktail pick with a frilly top holds it together.
    cyl(pick, (0.3, 0.2, z - 3.0), 0.16, 5.2, segments=8)
    ruffle(pick, (0.3, 0.2, z + 2.25), 0.9, 0.5, 7, 0.25, rings=2, segments=20)
    ball(pick, (0.3, 0.2, z + 2.6), 0.55, subdivisions=2)
    return [closed(coll, "SandwichBread", bread, BREAD), closed(coll, "SandwichCrust", crust, CRUST),
            closed(coll, "SandwichLettuce", lettuce, (0.45, 0.85, 0.3)), closed(coll, "SandwichTomato", tomato, TOY_RED),
            closed(coll, "SandwichCheese", cheese, (1.0, 0.82, 0.25)), closed(coll, "SandwichPick", pick, TOY_BLUE)]


def ant(body, legs, eyes, origin, step=0.0):
    """One marching ant facing -Y with its feet on z = 0."""
    o = Vector(origin)
    ball(body, o + Vector((0, 2.0, 2.3)), (1.35, 1.9, 1.35), subdivisions=3)
    ball(body, o + Vector((0, -0.1, 2.3)), (0.75, 1.05, 0.75), subdivisions=2)
    ball(body, o + Vector((0, -1.9, 2.75)), (1.05, 1.0, 1.0), subdivisions=3)
    for side in (-1, 1):
        ball(eyes, o + Vector((side * 0.5, -2.7, 3.05)), (0.36, 0.26, 0.4), subdivisions=2)
        ball(legs, o + Vector((side * 0.52, -2.92, 3.0)), (0.17, 0.1, 0.2), subdivisions=1)
        sweep(legs, curve(o + Vector((side * 0.4, -2.4, 3.5)), o + Vector((side * 0.9, -3.4, 4.9)), o + Vector((side * 1.6, -4.1, 4.8)), count=7), 0.11, segments=5)
        for k, y in enumerate((-0.8, -0.1, 0.6)):
            swing = (step if (k + (side > 0)) % 2 else -step)
            sweep(legs, curve(o + Vector((side * 0.5, y, 2.2)), o + Vector((side * 2.0, y + swing, 3.1)), o + Vector((side * 2.6, y + swing * 2 + (k - 1) * 0.9, 0.15)), count=7),
                  0.14, segments=5, radius_end=0.11)


def build_ant_line(coll):
    body, legs, eyes, crumb = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for k in range(3):
        ant(body, legs, eyes, (0.25 * (k - 1), -6.2 + 6.2 * k, 0), step=0.35 if k % 2 else -0.35)
    # The middle ant carries a sugar cube over its head; the last one a crumb.
    rounded_block(crumb, (1.9, 1.9, 1.9), M((0, -1.7, 5.4), (0.2, 0.3, 0.5)), corner=0.25, edge=0.2, corner_seg=1, edge_seg=1)
    blob(crumb, Vector((0.2, 4.4, 5.0)), Vector((1.1, 0.9, 0.8)), subdivisions=2, lump=0.25, seed=4.0)
    sweep(legs, curve((0, -2.3, 3.4), (0.0, -2.2, 4.5), (0, -1.7, 4.6), count=5), 0.12, segments=5)
    return [closed(coll, "AntBodies", body, (0.35, 0.08, 0.06)), closed(coll, "AntLegs", legs, (0.12, 0.05, 0.04)),
            closed(coll, "AntEyes", eyes, CREAM_WHITE), closed(coll, "AntCrumb", crumb, (0.98, 0.96, 0.92))]


def build_picnic_basket(coll):
    wicker, weave, lid, handle, fabric = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    w, d, h = 10.0, 6.6, 6.0
    rounded_block(wicker, (w, d, h), M((0, 0, h / 2)), corner=1.0, edge=0.3, corner_seg=4, edge_seg=1, taper=1.08)
    for k in range(6):
        z = 0.7 + k * 0.95
        s = 1 + 0.08 * z / h
        ring = [Vector((x, y, z)) for x, y in rounded_rect(w * s + 0.06, d * s + 0.06, 1.0 * s, 4)]
        loop_tube(weave, ring, rect_profile(-0.03, 0.12, -0.18, 0.18), (0, 0, 1))
    for k in range(9):
        x = -w / 2 + 0.6 + k * (w - 1.2) / 8
        for y in (-d / 2 - 0.15, d / 2 + 0.15):
            mbox(weave, M((x * (1.0 + 0.04), y * 1.04, h / 2)), (0.3, 0.2, h - 0.6))
    # Two lids on hinges along the middle: one shut, one flipped open with a checked cloth spilling out.
    rounded_block(lid, (w * 1.1, d * 0.56, 0.5), M((0, d * 0.28, h + 0.5)), corner=0.6, edge=0.2, corner_seg=3, edge_seg=1)
    rounded_block(lid, (w * 1.1, d * 0.56, 0.5), M((0, -d * 0.02, h + 1.6), (math.radians(-62), 0, 0)) @ Matrix.Translation((0, -d * 0.28, 0)),
                  corner=0.6, edge=0.2, corner_seg=3, edge_seg=1)
    arch = [Vector((5.0 * math.cos(a), 0.0, h + 0.4 + 5.4 * math.sin(a))) for a in [math.pi * i / 16 for i in range(17)]]
    sweep(handle, arch, 0.42, segments=10)
    for x in (-5.0, 5.0):
        ball(handle, (x, 0, h + 0.5), 0.7, subdivisions=2)
    xs = [-4.2 + 8.4 * i / 14 for i in range(15)]
    cloth(fabric, xs, lambda x: h - 1.0, h + 1.2, 0.18, lambda x, z: -d * 0.42 - 0.35 * math.sin(x * 2.1) - (z - h) * 0.3)
    return [closed(coll, "BasketWicker", wicker, (0.82, 0.6, 0.32)), closed(coll, "BasketWeave", weave, (0.64, 0.42, 0.2)),
            closed(coll, "BasketLid", lid, (0.7, 0.48, 0.24), hard=True), closed(coll, "BasketHandle", handle, (0.55, 0.35, 0.18)),
            closed(coll, "BasketCloth", fabric, TOY_RED)]


def build_crumbs(coll):
    inside, outside = bmesh.new(), bmesh.new()
    rng = random.Random(12)
    for k, (x, y, s) in enumerate(((0, 0, 1.4), (2.3, 0.8, 0.9), (-2.1, 1.0, 1.0), (0.8, -1.9, 0.7), (-1.2, -1.6, 0.6))):
        target = inside if k % 2 == 0 else outside
        rough_rock(target, (x, y, s * 0.55), (s * 1.2, s, s * 0.8), rng, subdivisions=2, jitter=0.25, floor=0.0)
    return [closed(coll, "CrumbBread", inside, BREAD), closed(coll, "CrumbCrust", outside, CRUST)]


def build_blanket_folds(coll):
    # A rumpled checked blanket heaped into soft folds, its edges tucked down to the ground.
    size, cells, sub = 19.6, 8, 3
    n = cells * sub

    def height(u, v):
        edge = (math.sin(math.pi * u) * math.sin(math.pi * v)) ** 0.55
        fold = 4.4 + 2.2 * math.sin(u * 9.0 + 0.6) * math.cos(v * 4.0) + 1.3 * math.sin(v * 11.0 + u * 3.0)
        return max(0.0, edge * fold)

    def point(i, j):
        u, v = i / n, j / n
        sway = 0.5 * math.sin(v * 7.0) * math.sin(math.pi * u)
        return Vector(((u - 0.5) * size + sway, (v - 0.5) * size, height(u, v)))
    red, white = [], []
    for i in range(n):
        for j in range(n):
            quad = [point(i, j), point(i + 1, j), point(i + 1, j + 1), point(i, j + 1)]
            (red if (i // sub + j // sub) % 2 == 0 else white).append(quad)
    return [sheet(coll, "BlanketRed", red, TOY_RED), sheet(coll, "BlanketWhite", white, CREAM_WHITE)]


# ---------- 3. Kitchen Counter ----------

def build_cutting_board(coll):
    wood, dark, carrot, greens, slices = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    # A big chopping board stood on its end, leaning back, with a carrot and slices in front of it.
    lean = M((0, 1.6, 0), (math.radians(-14), 0, 0))
    outline_prism(wood, [(x, y + 7.0) for x, y in rounded_rect(10.0, 14.0, 2.2, 5)], lean @ XZ, -0.55, 0.55)
    outline_prism(wood, [(x, y + 15.2) for x, y in rounded_rect(4.4, 3.4, 1.5, 4)], lean @ XZ, -0.5, 0.5)
    torus(dark, lean @ Matrix.Translation((0, -0.5, 15.4)) @ Matrix.Rotation(math.pi / 2, 4, "X"), 0.85, 0.22, seg=20, tseg=6)
    for z in (2.0, 3.0, 11.8, 12.8):
        mbox(dark, lean @ M((0, -0.57, z)), (8.2, 0.06, 0.16))
    # The carrot: an orange cone lying on the counter with a leafy top.
    tip, top = Vector((3.0, -4.6, 1.0)), Vector((-4.2, -2.6, 1.6))
    axis = top - tip
    lathe(carrot, [(0, 0), (0.45, 0.6), (1.05, 2.8), (1.45, 5.5), (1.55, axis.length - 0.3), (0.8, axis.length), (0, axis.length)], 16,
          Matrix.Translation(tip) @ align_z(axis), wobble=0.06)
    for k in range(5):
        a = -0.6 + 0.3 * k
        d = (axis.normalized() + Vector((0.3 * math.sin(a * 3), 0.4 * math.cos(a * 3), 0.6 + 0.2 * k))).normalized()
        sweep(greens, curve(top, top + d * 1.8, top + d * 3.6 + Vector((0, 0, 0.6)), count=6), 0.18, segments=5, radius_end=0.1)
        ball(greens, top + d * 3.6 + Vector((0, 0, 0.6)), (0.6, 0.5, 0.35), subdivisions=1)
    for x, y, color in ((3.6, -1.8, 0), (5.0, -0.4, 0), (4.6, -3.2, 1), (-3.0, -5.4, 1), (-1.4, -6.0, 0)):
        target = carrot if color == 0 else slices
        cyl(target, (x, y, 0), 1.25 if color == 0 else 1.5, 0.45, segments=18)
        if color == 1:
            torus(greens, Matrix.Translation((x, y, 0.24)), 1.5, 0.24, seg=18, tseg=6)
    return [closed(coll, "BoardWood", wood, BEECH, hard=True), closed(coll, "BoardWoodDark", dark, (0.55, 0.38, 0.22)),
            closed(coll, "BoardCarrot", carrot, TOY_ORANGE), closed(coll, "BoardGreens", greens, (0.25, 0.65, 0.2)),
            closed(coll, "BoardSlices", slices, (0.8, 0.95, 0.6))]


def build_toaster(coll):
    body, trim, chrome, toast, crust = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    w, d, h = 11.0, 6.8, 8.0
    rounded_block(body, (w, d, h), M((0, 0, h / 2 + 0.6)), corner=2.4, edge=1.6, corner_seg=5, edge_seg=3)
    ring = [Vector((x, y, 0)) for x, y in rounded_rect(w + 0.08, d + 0.08, 2.42, 5)]
    loop_tube(chrome, [p + Vector((0, 0, 3.4)) for p in ring], rect_profile(-0.03, 0.12, -0.45, 0.45), (0, 0, 1))
    for x in (-3.8, 3.8):
        for y in (-2.2, 2.2):
            ball(trim, (x, y, 0.45), (0.8, 0.8, 0.5), subdivisions=2, floor=0.0)
    # Two slots on top with slices of toast popping up.
    for x in (-2.3, 2.3):
        rounded_block(trim, (1.6, 5.2, 0.4), M((x, 0, h + 0.62)), corner=0.6, edge=0.1, corner_seg=3, edge_seg=1)
        outline = [(px, pz) for px, pz in rounded_rect(4.4, 5.2, 1.4, 4)]
        bread = M((x, 0, h - 0.4 + 2.6)) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ XZ
        outline_prism(toast, outline, bread, -0.5, 0.5)
        loop_tube(crust, [bread @ Vector((px, pz, 0)) for px, pz in rounded_rect(4.42, 5.22, 1.41, 4)], rect_profile(-0.02, 0.14, -0.52, 0.52),
                  bread.to_3x3() @ Vector((0, 0, 1)))
    # A lever on the side and a browning dial on the front.
    rounded_block(trim, (0.6, 1.8, 3.4), M((w / 2 + 0.2, 0, 4.6)), corner=0.25, edge=0.2, corner_seg=2, edge_seg=1)
    rounded_block(chrome, (1.4, 2.4, 0.8), M((w / 2 + 0.75, 0, 6.0)), corner=0.35, edge=0.3, corner_seg=2, edge_seg=1)
    cyl(trim, (2.8, -d / 2 + 0.05, 2.2), 0.8, 0.5, segments=16, direction=(0, -1, 0))
    mbox(chrome, M((2.8, -d / 2 - 0.5, 2.5)), (0.18, 0.1, 0.6))
    return [closed(coll, "ToasterBody", body, (0.55, 0.85, 0.85)), closed(coll, "ToasterTrim", trim, (0.2, 0.2, 0.24)),
            closed(coll, "ToasterChrome", chrome, CHROME, hard=True), closed(coll, "ToasterToast", toast, BREAD, hard=True),
            closed(coll, "ToasterCrust", crust, CRUST)]


def build_faucet(coll):
    chrome, handle, water = bmesh.new(), bmesh.new(), bmesh.new()
    # A deck plate, a tall column and a gooseneck curving back over toward the batter.
    lathe(chrome, [(0, 0), (3.2, 0), (3.2, 0.5), (2.2, 1.0), (1.3, 1.6), (0, 1.6)], 28)
    lathe(chrome, [(0, 1.4), (1.25, 1.4), (1.05, 6.0), (1.15, 6.6), (0.95, 7.2), (0, 7.2)], 22)
    neck = [Vector((0, 0, 6.5)), Vector((0, 0, 8.4)), Vector((0, 0, 10.4))]
    neck += [Vector((0, -3.6 + 3.6 * math.cos(a), 12.0 + 4.6 * math.sin(a))) for a in [math.pi * i / 18 for i in range(19)]]
    sweep(chrome, neck, 0.75, segments=16)
    tip = neck[-1]
    lathe(chrome, [(0, -1.2), (0.95, -1.2), (0.85, 0.0), (0, 0.0)], 16, Matrix.Translation(tip))
    # A lever handle with a hot/cold cap.
    capsule(handle, (0, 0.6, 6.2), (0, 3.6, 8.6), 0.42, 0.55)
    ball(handle, (0, 3.6, 8.6), 0.8, subdivisions=2)
    # A trickle of water: a stream breaking into drops and a splash puddle.
    spout = tip + Vector((0, 0, -1.3))
    sweep(water, [spout, spout + Vector((0, 0, -2.4)), spout + Vector((0, 0, -4.0))], 0.42, segments=10, radius_end=0.3)
    for k, z in enumerate((spout.z - 5.6, spout.z - 7.3, spout.z - 8.9)):
        lathe(water, [(0, -0.55), (0.42, -0.36), (0.48, 0.0), (0.24, 0.42), (0, 0.72)], 12, Matrix.Translation((0, spout.y, z)))
    ruffle(water, (0, spout.y, 0.12), 2.8, 0.22, 6, 0.08, rings=3, segments=24)
    return [closed(coll, "FaucetChrome", chrome, CHROME), closed(coll, "FaucetHandle", handle, TOY_BLUE),
            closed(coll, "FaucetWater", water, WATER)]


def cereal_loop(bm, center, normal, R=1.3, r=0.55, wobble=0.0):
    torus(bm, Matrix.Translation(Vector(center)) @ align_z(Vector(normal)), R, r, seg=14, tseg=7)


def build_cereal_piece(coll):
    a, b, c = bmesh.new(), bmesh.new(), bmesh.new()
    cereal_loop(a, (0, 0, 0.55), (0.1, 0.05, 1))
    cereal_loop(b, (2.4, 0.9, 0.55), (0, -0.1, 1))
    cereal_loop(c, (-2.1, 1.2, 0.55), (0.05, 0.1, 1))
    cereal_loop(b, (0.9, 0.5, 1.6), (0.5, -0.4, 1))
    cereal_loop(c, (0.5, -2.1, 0.55), (0, 0, 1))
    return [closed(coll, "CerealLoopA", a, (1.0, 0.6, 0.2)), closed(coll, "CerealLoopB", b, (1.0, 0.35, 0.45)),
            closed(coll, "CerealLoopC", c, (0.95, 0.85, 0.3))]


def build_cereal_hills(coll):
    base, a, b, c = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    rx, ry, rz = 8.4, 6.6, 5.8
    ball(base, (0, 0, 0), (rx, ry, rz), subdivisions=3, floor=0.0)
    rng = random.Random(21)
    targets = (a, b, c)
    count = 64
    for k in range(count):
        zf = 1 - (k + 0.5) / count
        ring = math.sqrt(max(0, 1 - zf * zf))
        ang = k * 2.39996 + rng.uniform(-0.2, 0.2)
        unit = Vector((ring * math.cos(ang), ring * math.sin(ang), zf))
        p = Vector((unit.x * rx, unit.y * ry, unit.z * rz))
        n = Vector((unit.x / rx, unit.y / ry, unit.z / rz)).normalized()
        n = (n + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.3)))).normalized()
        cereal_loop(targets[k % 3], p + n * 0.2, n, R=1.45, r=0.62)
    return [closed(coll, "CerealHeapBase", base, (0.95, 0.75, 0.35)), closed(coll, "CerealHeapA", a, (1.0, 0.6, 0.2)),
            closed(coll, "CerealHeapB", b, (1.0, 0.35, 0.45)), closed(coll, "CerealHeapC", c, (0.95, 0.85, 0.3))]


# ---------- 4. Block Town ----------

def build_alphabet_block(coll):
    wood, letters = bmesh.new(), bmesh.new()
    panels = [bmesh.new(), bmesh.new(), bmesh.new()]
    # Three wooden letter blocks stacked a little crooked, A-B-C, each face a coloured panel with a raised letter.
    z = 0.0
    for index, (size, turn, letter) in enumerate(((6.6, 0.0, "A"), (6.1, 0.32, "B"), (5.6, -0.22, "C"))):
        center = Vector((0.25 * (index % 2) - 0.1, 0.2 * index - 0.2, z + size / 2))
        rot = Matrix.Rotation(turn, 4, "Z")
        rounded_block(wood, (size, size, size), Matrix.Translation(center) @ rot, corner=0.55, edge=0.55, corner_seg=2, edge_seg=2)
        half = size / 2
        faces = [Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((-1, 0, 0))]
        if index == 2:
            faces.append(Vector((0, 0, 1)))
        for normal in faces:
            n = rot.to_3x3() @ normal
            face_center = center + n * (half + 0.02)
            up = (0, 0, 1) if abs(n.z) < 0.5 else tuple(rot.to_3x3() @ Vector((0, 1, 0)))
            matrix = face_matrix(face_center, n, up)
            rounded_block(panels[index], (size * 0.8, size * 0.8, 0.16), matrix @ Matrix.Translation((0, 0, 0.0)),
                          corner=0.6, edge=0.06, corner_seg=3, edge_seg=1)
            letter_face(letters, face_center + n * 0.08, n, half, letter, up=up)
        z += size
    return [closed(coll, "BlockWood", wood, BEECH), closed(coll, "BlockPanelA", panels[0], TOY_RED, hard=True),
            closed(coll, "BlockPanelB", panels[1], TOY_BLUE, hard=True), closed(coll, "BlockPanelC", panels[2], TOY_GREEN, hard=True),
            closed(coll, "BlockLetters", letters, CREAM_WHITE)]


def build_train_track(coll):
    track, body, cab, wheels, trim = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    # A wooden toy track snaking along Y with a little steam engine on it.
    path = [Vector((2.2 * math.sin(t * math.pi * 1.2), -9.0 + 18.0 * t, 0)) for t in [i / 30 for i in range(31)]]
    profile = [(-2.1, 0.0), (2.1, 0.0), (2.1, 0.8), (1.45, 0.8), (1.45, 0.55), (0.95, 0.55), (0.95, 0.8), (-0.95, 0.8),
               (-0.95, 0.55), (-1.45, 0.55), (-1.45, 0.8), (-2.1, 0.8)]
    path_extrude(track, path, list(reversed(profile)))
    # The engine sits on the straightest middle stretch, facing -Y.
    mid = 15
    p = path[mid]
    t = (path[mid + 1] - path[mid - 1]).normalized()
    s = t.cross(Vector((0, 0, 1))).normalized()
    frame = Matrix((s, -t, Vector((0, 0, 1)))).transposed().to_4x4()
    frame.translation = p + Vector((0, 0, 0.8))
    rounded_block(trim, (3.4, 8.4, 0.7), frame @ Matrix.Translation((0, 0, 1.0)), corner=0.3, edge=0.2, corner_seg=2, edge_seg=1)
    lathe(body, [(0, 0), (1.55, 0), (1.6, 5.0), (1.45, 5.3), (0, 5.3)], 20, frame @ Matrix.Translation((0, 2.2, 2.9)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    rounded_block(cab, (3.6, 3.0, 3.8), frame @ Matrix.Translation((0, 2.6, 3.3)), corner=0.5, edge=0.4, corner_seg=3, edge_seg=2)
    rounded_block(trim, (4.0, 3.6, 0.5), frame @ Matrix.Translation((0, 2.6, 5.45)), corner=0.5, edge=0.2, corner_seg=3, edge_seg=1)
    lathe(trim, [(0, 0), (0.55, 0), (0.55, 1.4), (0.95, 2.1), (0.95, 2.4), (0, 2.4)], 14, frame @ Matrix.Translation((0, -2.0, 4.2)))
    ball(cab, frame @ Vector((0, -0.4, 4.5)), 0.75, subdivisions=2)
    lathe(trim, [(0, 0), (1.65, 0), (1.65, 0.3), (0, 0.3)], 20, frame @ Matrix.Translation((0, -3.0, 2.9)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    for y in (-2.4, 0.0, 2.6):
        for x in (-1.85, 1.85):
            r = 1.05 if y > 2 else 0.85
            lathe(wheels, [(0, -0.25), (r, -0.25), (r, 0.25), (0, 0.25)], 16,
                  frame @ Matrix.Translation((x, y, 0.85 if y < 2 else 1.05)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    return [closed(coll, "TrackWood", track, BEECH, hard=True), closed(coll, "TrainBody", body, TOY_RED),
            closed(coll, "TrainCab", cab, TOY_BLUE), closed(coll, "TrainWheels", wheels, TOY_YELLOW, hard=True),
            closed(coll, "TrainTrim", trim, (0.15, 0.15, 0.18))]


def build_brick_tower(coll):
    bricks = {"BrickRed": bmesh.new(), "BrickYellow": bmesh.new(), "BrickBlue": bmesh.new(), "BrickGreen": bmesh.new()}
    order = ["BrickRed", "BrickYellow", "BrickBlue", "BrickGreen"]
    h = 1.9
    k = 0
    # Two base layers of four bricks, then a tall tower on the left and a short one on the right.
    for layer in range(2):
        for i in range(2):
            for j in range(2):
                x = -3.2 + 6.4 * i + (0.8 if layer == 1 else 0) * (1 if i == 0 else -1) * 0
                if layer == 0:
                    stud_brick(bricks[order[k % 4]], (x, -1.6 + 3.2 * j, 0), 4, 2)
                else:
                    stud_brick(bricks[order[k % 4]], (-4.8 + 3.2 * (i * 2 + j) + 1.6 * 0, 0, h), 2, 4)
                k += 1
    for layer in range(2, 10):
        turn = 0 if layer % 2 == 0 else math.pi / 2
        for j in range(2):
            offset = Vector((-1.6 + 3.2 * j, 0, 0)) if turn else Vector((0, -1.6 + 3.2 * j, 0))
            if layer == 9 and j == 1:
                continue
            stud_brick(bricks[order[k % 4]], Vector((-3.2, 0, h * layer)) + offset, 4, 2, turn=turn)
            k += 1
    for layer in range(2, 5):
        stud_brick(bricks[order[(k + 1) % 4]], (3.2, 0.0, h * layer), 2, 2 if layer < 4 else 2, turn=0.15 * (layer - 3))
        k += 1
    stud_brick(bricks[order[k % 4]], (3.2, 0.0, h * 5), 2, 2, turn=0.6)
    return [closed(coll, name, bricks[name], color) for name, color in
            (("BrickRed", TOY_RED), ("BrickYellow", TOY_YELLOW), ("BrickBlue", TOY_BLUE), ("BrickGreen", TOY_GREEN))]


def build_toy_brick(coll):
    a, b = bmesh.new(), bmesh.new()
    stud_brick(a, (0, 0, 0), 4, 2)
    stud_brick(b, (1.6, 0.4, 1.9), 2, 2, turn=0.35)
    return [closed(coll, "ToyBrickA", a, TOY_RED), closed(coll, "ToyBrickB", b, TOY_YELLOW)]


# ---------- 5. Board Game Boulevard ----------

PIPS = {1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)], 4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
        5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)], 6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)]}


def die(body, pips, matrix, size):
    rounded_block(body, (size, size, size), matrix, corner=size * 0.16, edge=size * 0.16, corner_seg=3, edge_seg=3)
    # Opposite faces add up to seven.
    faces = [((0, 0, 1), 1, (0, 1, 0)), ((0, 0, -1), 6, (0, 1, 0)), ((0, -1, 0), 2, (0, 0, 1)), ((0, 1, 0), 5, (0, 0, 1)),
             ((1, 0, 0), 3, (0, 0, 1)), ((-1, 0, 0), 4, (0, 0, 1))]
    rot = matrix.to_3x3()
    center = matrix.translation
    for normal, count, up in faces:
        n = rot @ Vector(normal)
        fm = face_matrix(center + n * (size / 2 - 0.02), n, tuple(rot @ Vector(up)))
        spacing = size * 0.27
        radius = size * (0.13 if count > 1 else 0.17)
        for px, py in PIPS[count]:
            lathe(pips, [(0, -0.05), (radius, -0.05), (radius * 0.92, size * 0.035), (radius * 0.5, size * 0.05), (0, size * 0.05)], 14,
                  fm @ Matrix.Translation((px * spacing, py * spacing, 0)))


def build_giant_die(coll):
    body, pips = bmesh.new(), bmesh.new()
    die(body, pips, M((-1.0, 0.6, 4.25), (0, 0, 0.35)), 8.5)
    # A smaller die tumbled against it, resting on an edge.
    die(body, pips, M((4.7, -2.6, 2.05), (0, math.radians(35), -0.4)), 4.2)
    return [closed(coll, "DieBody", body, CREAM_WHITE), closed(coll, "DiePips", pips, TOY_RED)]


def card(face, back, suits, matrix, suit_outline):
    """A playing card standing in the matrix's XZ plane: suits raised on its face (local -Y), a coloured panel on its back."""
    w, h = 8.6, 12.4
    outline = rounded_rect(w, h, 0.9, 4)
    outline_prism(face, outline, matrix @ XZ, -0.14, 0.14)
    outline_prism(back, rounded_rect(w - 0.8, h - 0.8, 0.6, 3), matrix @ XZ, 0.12, 0.2)
    for (cx, cz, s) in ((0, 0.4, 4.6), (-2.9, 4.6, 1.5), (2.9, -4.6, 1.5)):
        outline_prism(suits, [(cx + x, cz + y) for x, y in suit_outline(s)], matrix @ XZ, -0.34, -0.12)


def build_playing_card(coll):
    face, back, red, black = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    # Two cards leaning together into a little tent, the front one a heart, the back one a spade.
    tilt = math.radians(22)
    h = 12.4
    front = M((0, -h / 2 * math.sin(tilt) - 0.2, h / 2 * math.cos(tilt)), (tilt, 0, 0))
    rear = M((0, h / 2 * math.sin(tilt) + 0.2, h / 2 * math.cos(tilt)), (-tilt, 0, math.pi))
    card(face, back, red, front, lambda s: heart_outline(s))
    card(face, back, black, rear, lambda s: heart_outline(s, flip=True))
    return [closed(coll, "CardFace", face, CREAM_WHITE, hard=True), closed(coll, "CardBack", back, CREAM_WHITE, hard=True),
            closed(coll, "CardSuitsRed", red, TOY_RED), closed(coll, "CardSuitsBlack", black, INK)]


MEEPLE = [(-3.4, 0.0), (-1.1, 0.0), (0.0, 2.4), (1.1, 0.0), (3.4, 0.0), (2.2, 3.6), (2.0, 5.0), (4.0, 5.6), (4.5, 6.6),
          (3.8, 7.3), (1.6, 7.4), (1.75, 8.2), (1.5, 9.1), (0.8, 9.7), (0.0, 9.9), (-0.8, 9.7), (-1.5, 9.1), (-1.75, 8.2),
          (-1.6, 7.4), (-3.8, 7.3), (-4.5, 6.6), (-4.0, 5.6), (-2.0, 5.0), (-2.2, 3.6)]


def build_game_piece(coll):
    a, b = bmesh.new(), bmesh.new()
    # A chunky wooden player token, and a smaller one fallen over beside it.
    outline_prism(a, MEEPLE, M((0, 0, 0)) @ XZ, -1.4, 1.4)
    outline_prism(b, [(x * 0.6, y * 0.6) for x, y in MEEPLE], M((4.6, -1.8, 0.85), (math.radians(90), 0, 0.5)) @ XZ, -0.85, 0.85)
    objects = [closed(coll, "MeepleBody", a, TOY_BLUE, hard=True), closed(coll, "MeepleBodyB", b, TOY_YELLOW, hard=True)]
    for obj, width in zip(objects, (0.45, 0.3)):
        bevel(obj, width, segments=3)
    return objects


PAWN = [(0, 0), (2.0, 0), (2.0, 0.45), (1.7, 0.7), (1.85, 0.95), (1.45, 1.2), (1.05, 1.6), (0.8, 2.6), (0.72, 3.0),
        (1.2, 3.15), (1.2, 3.4), (0.7, 3.5)] + [(0.95 * math.sin(a), 4.35 - 0.95 * math.cos(a)) for a in
                                                 [math.radians(30 + 150 * i / 8) for i in range(1, 9)]] + [(0, 5.3)]


def build_chess_pawn(coll):
    body = bmesh.new()
    lathe(body, PAWN, 24)
    return [closed(coll, "PawnBody", body, (0.12, 0.12, 0.14))]


def build_board_game_box(coll):
    base, lid, art, board = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    w, d = 16.0, 11.0
    rounded_block(base, (w, d, 4.0), M((0, 0, 2.0)), corner=0.3, edge=0.2, corner_seg=2, edge_seg=1)
    # The lid is pushed back askew, showing the folded game board inside.
    lid_matrix = M((2.4, 1.6, 4.9), (math.radians(-4), math.radians(3), 0.18))
    rounded_block(lid, (w + 0.5, d + 0.5, 2.0), lid_matrix, corner=0.3, edge=0.2, corner_seg=2, edge_seg=1)
    for k in range(5):
        ring = lid_matrix @ Matrix.Translation((-5.0, 0, 1.02))
        outline_prism(art, [(x, y) for x, y in rounded_rect(2.6 + k * 1.2, 2.6 + k * 1.2, 1.3 + k * 0.6, 6)], ring, 0.0, 0.06 + 0.01 * k)
    for k in range(5):
        a = 2 * math.pi * k / 5
        star = []
        for i in range(10):
            r = 1.4 if i % 2 == 0 else 0.6
            ang = a + math.pi * i / 5 + math.pi / 2
            star.append((r * math.cos(ang), r * math.sin(ang)))
        outline_prism(art, star, lid_matrix @ Matrix.Translation((3.2 + 3.0 * math.cos(a) * 0.9, 2.5 * math.sin(a), 1.02)), 0.0, 0.12)
    rounded_block(board, (w - 1.0, d - 1.0, 0.5), M((-1.4, -1.0, 4.1), (0, 0, -0.05)), corner=0.2, edge=0.1, corner_seg=1, edge_seg=1)
    for i in range(6):
        mbox(board, M((-1.4 - 7.0 + 2.8 * i, -1.0 - 4.7, 4.38), (0, 0, -0.05)), (1.4, 1.4, 0.06))
    return [closed(coll, "GameBoxBase", base, TOY_BLUE, hard=True), closed(coll, "GameBoxLid", lid, TOY_RED, hard=True),
            closed(coll, "GameBoxArt", art, TOY_YELLOW, hard=True), closed(coll, "GameBoxBoard", board, (0.95, 0.9, 0.75), hard=True)]


BUILDERS = [
    ("GrassBlade", build_grass_blade), ("HoseReel", build_hose_reel), ("Sprinkler", build_sprinkler), ("Ladybug", build_ladybug),
    ("Pebble", build_pebble), ("GiantFence", build_giant_fence),
    ("Sandwich", build_sandwich), ("AntLine", build_ant_line), ("PicnicBasket", build_picnic_basket), ("Crumbs", build_crumbs),
    ("BlanketFolds", build_blanket_folds),
    ("CuttingBoard", build_cutting_board), ("Toaster", build_toaster), ("Faucet", build_faucet), ("CerealPiece", build_cereal_piece),
    ("CerealHills", build_cereal_hills),
    ("AlphabetBlock", build_alphabet_block), ("TrainTrack", build_train_track), ("BrickTower", build_brick_tower),
    ("ToyBrick", build_toy_brick),
    ("GiantDie", build_giant_die), ("PlayingCard", build_playing_card), ("GamePiece", build_game_piece),
    ("ChessPawn", build_chess_pawn), ("BoardGameBox", build_board_game_box),
]


def fresh_batch_collection():
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
    coll = fresh_batch_collection()
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
        print(prop, "tris", sum(triangles(o) for o in group), "size", tuple(round(c, 2) for c in size))
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
