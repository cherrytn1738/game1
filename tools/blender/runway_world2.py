# World 2 (Time Travel) runway props: all ten themed sections in one batch.
#   Prehistoric Valley: Cycad, DinoNest, Fossil             backdrop Brontosaurus
#   Stone Age Camp:     StoneHut, TuskArch, Campfire         backdrop Megalith
#   Pharaoh's Sands:    Obelisk, Sphinx, ScarabPillar        backdrop Pyramid
#   Olympian Heights:   GreekColumn, Amphora, HeroStatue     backdrop Temple
#   Viking Fjord:       Longship, RuneStone, ShieldRack      (backdrop: World 1's Mountain)
#   Samurai Gardens:    Torii, StoneLantern, CherryTree      backdrop Pagoda
#   Knight's Kingdom:   Banner, Catapult, ArmorStand         backdrop Castle
#   Frontier Town:      WaterTower, Wagon, Barrels           (World 1's Cactus and Mesa too)
#   Clockwork Foundry:  GearTower, PipeWorks                 backdrop Smokestack
#   Chrono Nexus:       TimeRing, Hourglass, HoloClock       backdrop FutureSpire
# Same conventions as batch3_props.py: run inside Blender (e.g. via MCP); one mesh per color,
# named <Template><Part>; each model rests on z = 0 around its origin; props with a front face
# -Y (RunwayDecor turns them to the tee). Every mesh stays under ~20 units so Roblox's 100x FBX
# import stays below its 2048-stud part limit; backdrops are scaled up in RunwayDecor.
# A manifest (template -> mesh names) is written beside the FBX for grouping after import.
import bpy, bmesh, math, os, random, json
from mathutils import Vector, Matrix, Euler, noise

HELPERS = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\prop_helpers.py"
exec(open(HELPERS, encoding="utf-8").read())

COLLECTION = "RunwayWorld2"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayWorld2.fbx"
MANIFEST_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayWorld2.json"

# Preview colors only; RunwayDecor tints every part in Roblox.
WOOD = (0.45, 0.29, 0.17)
DARK_WOOD = (0.27, 0.17, 0.1)
IVORY = (0.93, 0.89, 0.78)
STONE = (0.55, 0.53, 0.5)
SAND = (0.84, 0.68, 0.42)
GOLD = (1.0, 0.76, 0.25)
LAPIS = (0.15, 0.3, 0.7)
MARBLE = (0.93, 0.93, 0.95)
RED = (0.78, 0.15, 0.13)
STEEL = (0.62, 0.65, 0.7)
BRASS = (0.85, 0.62, 0.28)
COPPER = (0.78, 0.42, 0.25)
CYAN = (0.3, 0.95, 1.0)
DARK = (0.08, 0.07, 0.07)
MOSS = (0.35, 0.55, 0.25)


# ---------- geometry helpers ----------

def M(location=(0, 0, 0), rotation=(0, 0, 0)):
    return Matrix.Translation(Vector(location)) @ Euler(rotation).to_matrix().to_4x4()


def box(bm, center, size, rotation=(0, 0, 0)):
    cube = bmesh.ops.create_cube(bm, size=1.0)
    rot = Euler(rotation).to_matrix()
    for v in cube["verts"]:
        v.co = Vector(center) + rot @ Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))


def cyl(bm, base, radius, height, segments=16, top=None, direction=(0, 0, 1)):
    """A (tapered) cylinder standing on base, along direction."""
    top = radius if top is None else top
    lathe(bm, [(0, 0), (radius, 0), (top, height), (0, height)], segments,
          Matrix.Translation(Vector(base)) @ align_z(Vector(direction)))


def square_frustum(bm, z0, half0, z1, half1, center=(0, 0), turn=0.0):
    """A square-section block from half-width half0 at z0 to half1 at z1 (a pyramid when half1 is 0)."""
    r0, r1 = half0 * math.sqrt(2), half1 * math.sqrt(2)
    profile = [(0, z0), (r0, z0), (r1, z1), (0, z1)] if half1 > 0 else [(0, z0), (r0, z0), (0, z1)]
    lathe(bm, profile, 4, Matrix.Translation(Vector((center[0], center[1], 0))) @ Matrix.Rotation(math.pi / 4 + turn, 4, "Z"))


def torus(bm, matrix, R, r, seg=32, tseg=10):
    """A ring in the matrix's XY plane (its axis is the matrix's Z)."""
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        c, s = math.cos(a), math.sin(a)
        rings.append([bm.verts.new(matrix @ Vector(((R + r * math.cos(b)) * c, (R + r * math.cos(b)) * s, r * math.sin(b))))
                      for b in [2 * math.pi * k / tseg for k in range(tseg)]])
    for i in range(seg):
        a, b = rings[i], rings[(i + 1) % seg]
        for k in range(tseg):
            j = (k + 1) % tseg
            bm.faces.new((a[k], a[j], b[j], b[k]))


def arc(matrix, R, a0, a1, count):
    return [matrix @ Vector((R * math.cos(a0 + (a1 - a0) * i / (count - 1)), R * math.sin(a0 + (a1 - a0) * i / (count - 1)), 0))
            for i in range(count)]


def curve(p0, p1, p2, count=12, p3=None):
    """Points along a quadratic (or cubic, with p3) Bezier curve."""
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    points = []
    for i in range(count):
        t = i / (count - 1)
        if p3 is None:
            points.append(p0 * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + p2 * t * t)
        else:
            points.append(p0 * (1 - t) ** 3 + p1 * 3 * (1 - t) ** 2 * t + p2 * 3 * (1 - t) * t * t + Vector(p3) * t ** 3)
    return points


def ribbon(bm, points, widths, thickness, up=Vector((0, 0, 1))):
    """A flat, closed leaf/strap along points: width across (horizontal), thin vertically."""
    n, widest = len(points), max(widths) or 1.0
    rings = []
    for i, p in enumerate(points):
        t = (points[min(i + 1, n - 1)] - points[max(i - 1, 0)]).normalized()
        side = t.cross(up)
        if side.length < 1e-4:
            side = t.cross(Vector((1, 0, 0)))
        side.normalize()
        normal = side.cross(t).normalized()
        w, h = widths[i], thickness * (0.3 + 0.7 * widths[i] / widest)
        rings.append([bm.verts.new(p + side * w), bm.verts.new(p + normal * h),
                      bm.verts.new(p - side * w), bm.verts.new(p - normal * h)])
    for a, b in zip(rings, rings[1:]):
        for k in range(4):
            j = (k + 1) % 4
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(tuple(reversed(rings[0])))
    bm.faces.new(tuple(rings[-1]))


def loft(bm, sections):
    """Join equal-length closed point loops into a solid, capped at both ends."""
    rings = [[bm.verts.new(p) for p in section] for section in sections]
    n = len(sections[0])
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(tuple(reversed(rings[0])))
    bm.faces.new(tuple(rings[-1]))


def gear(bm, matrix, r_out, r_root, r_hole, teeth, thickness):
    """A toothed ring in the matrix's XY plane, thickness along its Z."""
    outer, inner = [], []
    for i in range(teeth * 4):
        phase = i % 4
        a = 2 * math.pi * (i // 4 + (0.0, 0.3, 0.6, 0.9)[phase]) / teeth
        outer.append((r_out if phase in (1, 2) else r_root, a))
        inner.append((r_hole, a))
    h = thickness / 2

    def verts(points, z):
        return [bm.verts.new(matrix @ Vector((r * math.cos(a), r * math.sin(a), z))) for r, a in points]
    ot, ob, it, ib = verts(outer, h), verts(outer, -h), verts(inner, h), verts(inner, -h)
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ot[i], ot[j], it[j], it[i]))
        bm.faces.new((ob[j], ob[i], ib[i], ib[j]))
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
        bm.faces.new((ib[j], ib[i], it[i], it[j]))


def spoked_hub(bm, matrix, r_inner, spokes, hub, thickness, spoke_width=0.35):
    """Spokes and a hub filling a gear's or wheel's hole (same plane conventions as gear)."""
    lathe(bm, [(0, -thickness * 0.7), (hub, -thickness * 0.7), (hub, thickness * 0.7), (0, thickness * 0.7)], 16, matrix)
    for k in range(spokes):
        a = 2 * math.pi * k / spokes
        mid = (r_inner + hub) / 2 * 1.02
        rot = matrix.to_3x3() @ Matrix.Rotation(a, 3, "Z")
        center = matrix @ Vector((math.cos(a) * mid, math.sin(a) * mid, 0))
        cube = bmesh.ops.create_cube(bm, size=1.0)
        for v in cube["verts"]:
            v.co = center + rot @ Vector((v.co.x * (r_inner - hub + 0.3), v.co.y * spoke_width, v.co.z * thickness * 0.8))


def cloth(bm, xs, bottom, top, thickness, wave, matrix=Matrix(), rows=8):
    """A solid panel over columns xs, from bottom(x) up to top, displaced along Y by wave(x, z)."""
    front, back = [], []
    for side, store in ((-1, front), (1, back)):
        for x in xs:
            z0 = bottom(x)
            store.append([bm.verts.new(matrix @ Vector((x, side * thickness / 2 + wave(x, z0 + (top - z0) * r / rows),
                                                        z0 + (top - z0) * r / rows))) for r in range(rows + 1)])
    cols = len(xs)
    for c in range(cols - 1):
        for r in range(rows):
            bm.faces.new((front[c][r], front[c + 1][r], front[c + 1][r + 1], front[c][r + 1]))
            bm.faces.new((back[c][r + 1], back[c + 1][r + 1], back[c + 1][r], back[c][r]))
        bm.faces.new((front[c][0], back[c][0], back[c + 1][0], front[c + 1][0]))
        bm.faces.new((front[c + 1][rows], back[c + 1][rows], back[c][rows], front[c][rows]))
    for r in range(rows):
        bm.faces.new((front[0][r + 1], back[0][r + 1], back[0][r], front[0][r]))
        bm.faces.new((front[-1][r], back[-1][r], back[-1][r + 1], front[-1][r + 1]))


def profile_r(profile, z):
    """A lathe profile's radius at height z (linear between its points)."""
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        if z0 <= z <= z1 and z1 > z0:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return profile[-1][0]


def band(bm, profile, z0, z1, out=0.04, depth=0.12, segments=24, matrix=Matrix()):
    """A closed ring hugging a lathe profile between z0 and z1 (paint stripes, iron hoops)."""
    a, b = profile_r(profile, z0), profile_r(profile, z1)
    lathe(bm, [(a + out, z0), (b + out, z1), (b - depth, z1), (a - depth, z0), (a + out, z0)], segments, matrix)


def jitter(bm, start, scale, strength, floor=None):
    bm.verts.ensure_lookup_table()
    for v in bm.verts[start:]:
        p = v.co * scale
        v.co += Vector((noise.noise(p), noise.noise(p + Vector((7.1, 0, 0))), noise.noise(p + Vector((0, 3.3, 0))))) * strength
        if floor is not None:
            v.co.z = max(v.co.z, floor)


def closed(coll, name, bm, rgb, hard=False):
    """make_object for closed pieces, with consistent outward normals; hard keeps crisp edges."""
    recalc_normals(bm)
    obj = make_object(coll, name, bm, rgb)
    if hard:
        smooth_by_angle(obj, 40)
    return obj


# ---------- 1. Prehistoric Valley ----------

def build_cycad(coll):
    rng = random.Random(21)
    trunk, fronds, light = bmesh.new(), bmesh.new(), bmesh.new()
    profile = [(0, 0), (1.7, 0), (1.25, 0.5)]
    for i in range(1, 15):
        z = 0.5 + i * 0.47
        profile.append((1.05 - z * 0.04 + (0.16 if i % 2 else 0.0), z))
    profile += [(0.55, 7.4), (0, 7.5)]
    lathe(trunk, profile, 14, wobble=0.06, seed=3)
    top = Vector((0, 0, 7.3))
    for i in range(13):
        a = i / 13 * 2 * math.pi + rng.uniform(-0.12, 0.12)
        out = Vector((math.cos(a), math.sin(a), 0))
        length, rise = rng.uniform(6.0, 7.2), rng.uniform(1.4, 2.6)
        points, widths = [], []
        for k in range(15):
            s = k / 14
            points.append(top + out * length * s + Vector((0, 0, rise * math.sin(math.pi * s * 0.85) - 2.6 * s * s)))
            widths.append(0.95 * min(1.0, s * 7) * (1 - s) ** 0.6 * (1 + 0.28 * math.cos(s * 48)))
        ribbon(fronds if i % 2 == 0 else light, points, widths, 0.14)
    for i in range(5):
        a = i / 5 * 2 * math.pi + 0.3
        out = Vector((math.cos(a), math.sin(a), 0))
        steps = [k / 7 for k in range(8)]
        ribbon(light, [top + out * 1.6 * s + Vector((0, 0, 2.4 * s - 0.5 * s * s)) for s in steps],
               [0.4 * min(1, s * 6) * (1 - s) ** 0.5 for s in steps], 0.1)
    return [closed(coll, "CycadTrunk", trunk, WOOD), closed(coll, "CycadFronds", fronds, (0.2, 0.5, 0.2)),
            closed(coll, "CycadFrondsLight", light, (0.45, 0.72, 0.28))]


EGG = [(0, 0), (0.85, 0.25), (1.22, 1.1), (1.15, 2.1), (0.75, 2.9), (0, 3.2)]


def build_dino_nest(coll):
    rng = random.Random(5)
    twigs, eggs, spots = bmesh.new(), bmesh.new(), bmesh.new()
    torus(twigs, Matrix.Diagonal((1, 1, 0.75, 1)) @ M((0, 0, 1.0)), 3.1, 1.15, seg=28, tseg=10)
    jitter(twigs, 0, 0.9, 0.35, floor=0.0)
    blob(twigs, Vector((0, 0, 0.2)), Vector((2.6, 2.6, 0.5)), subdivisions=3, floor=0.0)
    for _ in range(26):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(2.6, 4.0)
        center = Vector((math.cos(a) * r, math.sin(a) * r, rng.uniform(0.7, 1.7)))
        tangent = Vector((-math.sin(a), math.cos(a), rng.uniform(-0.4, 0.4))).normalized()
        half = rng.uniform(1.2, 2.1)
        sweep(twigs, [center - tangent * half, center + tangent * half], rng.uniform(0.09, 0.14), segments=5)
    for x, y, tilt, turn in ((-0.9, -0.5, 0.18, 0.4), (1.0, -0.3, 0.22, 2.2), (0.0, 1.1, 0.12, 4.1)):
        matrix = M((x, y, 0.35), (tilt * math.cos(turn), tilt * math.sin(turn), 0))
        lathe(eggs, EGG, 20, matrix)
        for _ in range(9):
            h = rng.uniform(0.5, 2.6)
            radius = profile_r(EGG, h) * 0.97
            a = rng.uniform(0, 2 * math.pi)
            blob(spots, matrix @ Vector((math.cos(a) * radius, math.sin(a) * radius, h)),
                 Vector((0.24, 0.24, 0.24)) * rng.uniform(0.7, 1.2), subdivisions=1)
    return [closed(coll, "NestTwigs", twigs, WOOD), closed(coll, "NestEggs", eggs, IVORY),
            closed(coll, "NestSpots", spots, (0.3, 0.6, 0.5))]


def build_fossil(coll):
    rng = random.Random(8)
    rock, bone, dark = bmesh.new(), bmesh.new(), bmesh.new()
    blob(rock, Vector((0, 0.6, 0)), Vector((5.0, 6.4, 1.5)), subdivisions=4, lump=0.25, seed=4, floor=0.0)

    def spine_at(s):
        return Vector((0, -4.4 + 10.2 * s, 0.9 + 2.0 * math.sin(math.pi * s)))
    spine = [spine_at(k / 20) for k in range(21)]
    sweep(bone, spine, 0.42, segments=10, radius_end=0.15)
    for k in range(2, 18, 2):
        blob(bone, spine[k] + Vector((0, 0, 0.42)), Vector((0.28, 0.22, 0.3)), subdivisions=2)
    for k in range(6):
        s = 0.18 + k * 0.07
        p = spine_at(s)
        size = 0.75 + 0.45 * math.sin(math.pi * (k + 0.5) / 6)
        for side in (-1, 1):
            rib = curve(p, p + Vector((side * 2.1 * size, 0, 0.9)), Vector((side * 2.5 * size, p.y + 0.2, 0.3)), 9)
            sweep(bone, rib, 0.2, segments=7, radius_end=0.11)
    blob(bone, Vector((0, -5.7, 1.65)), Vector((1.3, 1.9, 1.15)), subdivisions=3, rotation=Matrix.Rotation(-0.15, 3, "X"))
    blob(bone, Vector((0, -6.0, 0.75)), Vector((1.0, 1.6, 0.45)), subdivisions=3)
    for i in range(6):
        y = -7.0 + i * 0.36
        for side in (-1, 1):
            cyl(bone, (side * 0.82, y, 1.15), 0.14, 0.42, 6, top=0.01, direction=(0, 0, -1))
    for side in (-1, 1):
        blob(dark, Vector((side * 0.78, -5.2, 2.05)), Vector((0.42, 0.42, 0.42)), subdivisions=2)
        blob(dark, Vector((side * 0.36, -7.1, 1.95)), Vector((0.18, 0.18, 0.15)), subdivisions=1)
    return [closed(coll, "FossilRock", rock, SAND), closed(coll, "FossilBone", bone, IVORY),
            closed(coll, "FossilSockets", dark, DARK)]


def build_brontosaurus(coll):
    body, belly, dark = bmesh.new(), bmesh.new(), bmesh.new()
    blob(body, Vector((0, 0.5, 5.4)), Vector((3.1, 5.0, 3.0)), subdivisions=4, lump=0.04, seed=1)
    blob(belly, Vector((0, 0.5, 4.6)), Vector((2.75, 4.5, 2.35)), subdivisions=4)
    sweep(body, curve((0, -3.4, 6.6), (0, -6.4, 8.0), (0, -7.0, 12.4), 14), 1.7, segments=14, radius_end=0.72)
    blob(body, Vector((0, -7.6, 12.7)), Vector((0.85, 1.35, 0.78)), subdivisions=3)
    sweep(body, curve((0, 4.6, 5.8), (0, 8.0, 5.0), (1.2, 9.4, 1.6), 14), 1.6, segments=12, radius_end=0.12)
    for x in (-1.75, 1.75):
        for y in (-2.4, 3.0):
            cyl(body, (x, y, 0), 0.95, 4.8, 12, top=0.85)
            blob(body, Vector((x, y - 0.15, 0.35)), Vector((1.1, 1.2, 0.45)), subdivisions=2, floor=0.0)
    for x in (-0.72, 0.72):
        blob(dark, Vector((x, -8.0, 13.0)), Vector((0.2, 0.2, 0.2)), subdivisions=2)
    return [closed(coll, "BrontoBody", body, (0.35, 0.55, 0.45)), closed(coll, "BrontoBelly", belly, (0.7, 0.75, 0.55)),
            closed(coll, "BrontoEyes", dark, DARK)]


# ---------- 2. Stone Age Camp ----------

def build_stone_hut(coll):
    rng = random.Random(14)
    stones, thatch, door, poles = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    cyl(stones, (0, 0, 0), 3.45, 2.5, 20, top=3.3)
    for layer, z in enumerate((0.55, 1.35, 2.1)):
        for i in range(15):
            a = (i + 0.5 * layer) / 15 * 2 * math.pi
            if abs(a - 1.5 * math.pi) < 0.42:
                continue
            r = 3.5 - layer * 0.05
            rough_rock(stones, (math.cos(a) * r, math.sin(a) * r, z), (0.85, 0.75, 0.5), rng, subdivisions=1, jitter=0.18, floor=None)
    start = len(thatch.verts)
    lathe(thatch, [(0, 10.0), (0.5, 9.5), (2.0, 7.2), (3.6, 4.4), (4.6, 2.6), (4.75, 2.25), (4.1, 2.35), (0, 3.0)],
          28, wobble=0.15, seed=2)
    thatch.verts.ensure_lookup_table()
    for v in thatch.verts[start:]:
        if v.co.z < 3.0 and (abs(v.co.x) + abs(v.co.y)) > 0.1:
            v.co.z -= 0.22 * max(0.0, math.cos(14 * math.atan2(v.co.y, v.co.x)))
    box(door, (0, -3.4, 0.85), (1.7, 0.5, 1.7))
    cyl(door, (0, -3.15, 1.7), 0.85, 0.5, 16, direction=(0, -1, 0))
    for x in (-1.05, 1.05):
        cyl(poles, (x, -3.6, 0), 0.16, 2.7, 8)
    cyl(poles, (-1.4, -3.6, 2.6), 0.14, 2.8, 8, direction=(1, 0, 0))
    torus(poles, M((0, 0, 5.8)), 2.82, 0.12, seg=28, tseg=6)
    for a in (0.3, 2.4, 4.4):
        sweep(poles, [Vector((0, 0, 9.0)), Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, 11.0))], 0.12, segments=6, radius_end=0.08)
    return [closed(coll, "HutStones", stones, STONE), closed(coll, "HutThatch", thatch, (0.75, 0.6, 0.3)),
            closed(coll, "HutDoor", door, DARK), closed(coll, "HutPoles", poles, WOOD)]


def build_tusk_arch(coll):
    rng = random.Random(6)
    ivory, base, strap = bmesh.new(), bmesh.new(), bmesh.new()
    for side in (-1, 1):
        rough_rock(base, (side * 5.0, 0, 0.9), (1.7, 1.5, 1.2), rng, subdivisions=2, jitter=0.15, floor=0.0)
        rough_rock(base, (side * 6.1, 0.8, 0.5), (0.9, 0.9, 0.6), rng, subdivisions=1, jitter=0.2, floor=0.0)
        sweep(ivory, curve((side * 5.0, 0, 1.6), (side * 5.6, -0.6, 8.5), (side * 0.3, -0.3, 11.6), 16), 0.85, segments=14, radius_end=0.22)
        sweep(ivory, curve((side * 4.2, 0.7, 1.4), (side * 4.4, 0.9, 6.6), (side * 1.0, 0.9, 8.6), 14), 0.55, segments=12, radius_end=0.15)
    for k in range(3):
        torus(strap, M((-0.25 + k * 0.25, -0.3, 11.1 - k * 0.1), (0, math.pi / 2, 0)), 0.8, 0.2, seg=18, tseg=8)
    return [closed(coll, "TuskIvory", ivory, IVORY), closed(coll, "TuskBase", base, STONE),
            closed(coll, "TuskStrap", strap, (0.55, 0.3, 0.15))]


def build_campfire(coll):
    rng = random.Random(12)
    stones, logs, flame, meat = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for i in range(11):
        a = i / 11 * 2 * math.pi
        rough_rock(stones, (math.cos(a) * 2.3, math.sin(a) * 2.3, 0.35), (0.62, 0.55, 0.45), rng, subdivisions=1, jitter=0.2, floor=0.0)
    for i in range(5):
        a = i / 5 * 2 * math.pi + 0.3
        sweep(logs, [Vector((math.cos(a) * 1.8, math.sin(a) * 1.8, 0.15)), Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, 2.0))],
              0.24, segments=8, radius_end=0.18)
    for a in (0.6, 2.8):
        c = Vector((math.cos(a) * 4.6, math.sin(a) * 4.6, 0.5))
        t = Vector((-math.sin(a), math.cos(a), 0))
        sweep(logs, [c - t * 1.6, c + t * 1.6], 0.5, segments=12)
    # Flame tongues: thin, leaning and twisting out of a low bed of fire.
    blob(flame, Vector((0, 0, 0.45)), Vector((1.15, 1.15, 0.5)), subdivisions=2, lump=0.2, seed=2)
    for i in range(7):
        a = i / 7 * 2 * math.pi
        r = 0.0 if i == 0 else rng.uniform(0.35, 0.7)
        h = 3.3 if i == 0 else rng.uniform(1.8, 2.7)
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0.5))
        lean = Vector((math.cos(a + 1.2) * 0.5, math.sin(a + 1.2) * 0.5, 0)) * (h / 3)
        sweep(flame, curve(base, base + Vector((0, 0, h * 0.55)) - lean, base + Vector((0, 0, h)) + lean, 8),
              0.55 if i == 0 else 0.38, segments=10, radius_end=0.03)
    for x in (-2.1, 2.1):
        sweep(logs, [Vector((x, 0, 0)), Vector((x, 0, 3.7))], 0.12, segments=6)
        for lean in (-0.4, 0.4):
            sweep(logs, [Vector((x, 0, 3.5)), Vector((x + lean, 0, 4.1))], 0.08, segments=5)
    sweep(logs, [Vector((-2.5, 0, 3.75)), Vector((2.5, 0, 3.75))], 0.08, segments=6)
    blob(meat, Vector((0, 0, 3.75)), Vector((0.85, 0.55, 0.55)), subdivisions=2, lump=0.1)
    return [closed(coll, "CampfireStones", stones, STONE), closed(coll, "CampfireLogs", logs, WOOD),
            closed(coll, "CampfireFlame", flame, (1.0, 0.55, 0.1)), closed(coll, "CampfireMeat", meat, (0.55, 0.22, 0.12))]


def build_megalith(coll):
    rng = random.Random(3)
    stone, grass = bmesh.new(), bmesh.new()

    def slab(center, size, turn, lean=0.0):
        """A rough-cut standing stone: a box with every corner nudged, slightly tapered."""
        cube = bmesh.ops.create_cube(stone, size=1.0)
        rot = Matrix.Rotation(turn, 3, "Z") @ Matrix.Rotation(lean, 3, "Y")
        for v in cube["verts"]:
            taper = 0.85 if v.co.z > 0 else 1.0
            local = Vector((v.co.x * size[0] * taper, v.co.y * size[1] * taper, v.co.z * size[2]))
            local += Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), rng.uniform(-0.15, 0.15)))
            v.co = Vector(center) + rot @ local
    for i in range(5):
        a = i / 5 * 2 * math.pi
        for d in (-0.17, 0.17):
            b = a + d
            slab((math.cos(b) * 7.0, math.sin(b) * 7.0, 2.85), (1.5, 1.1, 5.7), b, rng.uniform(-0.05, 0.05))
        slab((math.cos(a) * 7.0, math.sin(a) * 7.0, 6.0), (1.6, 3.6, 0.85), a)
    slab((0, 0, 0.35), (2.6, 1.5, 0.7), 0.3)
    slab((2.6, 2.4, 0.45), (5.0, 1.4, 0.9), 0.8)
    blob(grass, Vector((0, 0, 0)), Vector((8.9, 8.9, 0.35)), subdivisions=4, lump=0.12, seed=5, floor=0.0)
    stone_obj = closed(coll, "MegalithStone", stone, STONE, hard=True)
    return [stone_obj, closed(coll, "MegalithMoss", grass, MOSS)]


# ---------- 3. Pharaoh's Sands ----------

def build_obelisk(coll):
    stone, gold, glyphs = bmesh.new(), bmesh.new(), bmesh.new()
    box(stone, (0, 0, 0.4), (4.4, 4.4, 0.8))
    box(stone, (0, 0, 1.1), (3.4, 3.4, 0.6))
    box(gold, (0, 0, 1.45), (3.0, 3.0, 0.12))
    square_frustum(stone, 1.4, 1.15, 15.6, 0.78)
    square_frustum(gold, 15.55, 0.82, 17.7, 0.0)
    for face in range(4):
        yaw = face * math.pi / 2
        rot = Matrix.Rotation(yaw, 3, "Z")
        for row in range(7):
            z = 3.0 + row * 1.7
            half = 1.15 + (0.78 - 1.15) * (z - 1.4) / 14.2
            kind = (row + face) % 3
            c = rot @ Vector((0, -(half + 0.02), z))
            if kind == 0:
                box(glyphs, c, (0.9 * half, 0.12, 0.3), rotation=(0, 0, yaw))
            elif kind == 1:
                blob(glyphs, c, Vector((0.5, 0.1, 0.26)) * (half / 1.1), subdivisions=2, rotation=rot)
                blob(glyphs, c + rot @ Vector((0, 0, -0.36)), Vector((0.12, 0.1, 0.12)), subdivisions=1, rotation=rot)
            else:
                box(glyphs, c + Vector((0, 0, -0.1)), (0.13, 0.12, 0.75), rotation=(0, 0, yaw))
                box(glyphs, c + Vector((0, 0, 0.1)), (0.55, 0.12, 0.13), rotation=(0, 0, yaw))
                torus(glyphs, Matrix.Translation(c + Vector((0, 0, 0.5))) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X"),
                      0.18, 0.06, seg=12, tseg=5)
    return [closed(coll, "ObeliskStone", stone, SAND, hard=True), closed(coll, "ObeliskGold", gold, GOLD, hard=True),
            closed(coll, "ObeliskGlyphs", glyphs, LAPIS)]


def build_sphinx(coll):
    stone, plinth, gold, stripes = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    box(plinth, (0, 0.3, 0.7), (6.6, 13.6, 1.4))
    box(gold, (0, 0.3, 1.2), (6.72, 13.72, 0.18))
    blob(stone, Vector((0, 2.4, 3.3)), Vector((2.3, 4.2, 1.9)), subdivisions=4, lump=0.03, floor=1.4)
    for x in (-1.6, 1.6):
        blob(stone, Vector((x, 4.3, 2.6)), Vector((1.1, 2.0, 1.25)), subdivisions=3, floor=1.4)
        box(stone, (x * 0.8, -2.3, 1.9), (1.15, 4.6, 1.0))
        blob(stone, Vector((x * 0.8, -4.6, 1.95)), Vector((0.62, 0.75, 0.55)), subdivisions=2, floor=1.4)
    blob(stone, Vector((0, -0.6, 4.3)), Vector((1.7, 1.6, 2.2)), subdivisions=3)
    cyl(stone, (0, -1.0, 5.4), 0.75, 1.2, 12)
    blob(stone, Vector((0, -1.5, 6.95)), Vector((0.82, 0.92, 1.0)), subdivisions=3)
    # Nemes headdress: a hood wider than the face, flaring into striped side panels.
    blob(gold, Vector((0, -1.0, 7.3)), Vector((1.2, 1.0, 1.15)), subdivisions=3)
    for x in (-1, 1):
        box(gold, (x * 1.15, -1.25, 6.3), (0.4, 1.1, 2.3), rotation=(0, x * 0.22, 0))
        for k in range(5):
            box(stripes, (x * 1.15 + x * (k - 2) * -0.1, -1.25, 5.45 + k * 0.42), (0.44, 1.14, 0.12), rotation=(0, x * 0.22, 0))
        box(gold, (x * 0.62, -1.75, 5.35), (0.38, 0.4, 1.3))
    box(stripes, (0, -1.95, 7.85), (1.4, 0.2, 0.16))
    box(gold, (0, -2.3, 5.55), (0.35, 0.3, 0.9))
    for x in (-0.36, 0.36):
        blob(stripes, Vector((x, -2.38, 7.1)), Vector((0.16, 0.08, 0.09)), subdivisions=1)
    sweep(stone, curve((1.9, 5.6, 2.0), (2.4, 3.0, 1.7), (2.0, 0.5, 1.75), 10), 0.22, segments=6, radius_end=0.15)
    return [closed(coll, "SphinxStone", stone, SAND), closed(coll, "SphinxPlinth", plinth, (0.7, 0.55, 0.35), hard=True),
            closed(coll, "SphinxGold", gold, GOLD), closed(coll, "SphinxStripes", stripes, LAPIS)]


PILLAR_SHAFT = [(0, 0.7), (1.35, 0.7), (1.45, 4.0), (1.35, 8.5), (1.2, 10.6), (0, 10.6)]


def build_scarab_pillar(coll):
    stone, bands, scarab = bmesh.new(), bmesh.new(), bmesh.new()
    cyl(stone, (0, 0, 0), 2.0, 0.7, 20)
    lathe(stone, PILLAR_SHAFT, 24)
    lathe(stone, [(0, 10.5), (1.15, 10.5), (1.5, 11.0), (2.05, 11.9), (2.15, 12.25), (0, 12.25)], 24)
    box(stone, (0, 0, 12.5), (3.2, 3.2, 0.5))
    for z in (1.1, 1.55, 9.3, 9.75):
        band(bands, PILLAR_SHAFT[1:5], z, z + 0.22, out=0.05)
    for i in range(12):
        a = i / 12 * 2 * math.pi
        sweep(bands, [Vector((math.cos(a) * 1.22, math.sin(a) * 1.22, 10.65)), Vector((math.cos(a) * 1.62, math.sin(a) * 1.62, 11.3)),
                      Vector((math.cos(a) * 2.12, math.sin(a) * 2.12, 12.05))], 0.07, segments=4)
    for side in (-1, 1):
        y = side * 1.4
        blob(scarab, Vector((0, y, 6.0)), Vector((0.55, 0.25, 0.8)), subdivisions=2)
        blob(scarab, Vector((0, y, 7.0)), Vector((0.42, 0.22, 0.32)), subdivisions=2)
        for x in (-1, 1):
            blob(scarab, Vector((x * 0.95, y, 6.35)), Vector((0.75, 0.12, 0.32)), subdivisions=2, rotation=Matrix.Rotation(x * 0.5, 3, "Y"))
        cyl(bands, (0, side * 1.33, 7.8), 0.45, 0.16, 16, direction=(0, side, 0))
    return [closed(coll, "PillarStone", stone, SAND), closed(coll, "PillarBands", bands, (0.2, 0.6, 0.65)),
            closed(coll, "PillarScarab", scarab, GOLD)]


def build_pyramid(coll):
    stone, cap, steps = bmesh.new(), bmesh.new(), bmesh.new()

    def half_at(z, half0=7.4, top=10.2):
        return half0 * (1 - z / top)
    square_frustum(stone, 0, 7.4, 9.2, half_at(9.2))
    square_frustum(cap, 9.15, half_at(9.15) + 0.05, 10.2, 0.0)
    root2 = math.sqrt(2)
    for k in range(1, 7):
        z = k * 1.3
        a, b = half_at(z) * root2, half_at(z + 0.22) * root2
        lathe(steps, [(a + 0.08, z), (b + 0.08, z + 0.22), (b - 0.2, z + 0.22), (a - 0.2, z), (a + 0.08, z)], 4,
              Matrix.Rotation(math.pi / 4, 4, "Z"))
    square_frustum(stone, 0, 2.6, 3.4, 0.0, center=(8.4, 5.2))
    return [closed(coll, "PyramidStone", stone, SAND, hard=True), closed(coll, "PyramidCap", cap, GOLD, hard=True),
            closed(coll, "PyramidSteps", steps, (0.7, 0.55, 0.33), hard=True)]


# ---------- 4. Olympian Heights ----------

def fluted_column(bm, center, z0, z1, r0, r1, flutes=16):
    start = len(bm.verts)
    lathe(bm, [(0, z0), (r0, z0), (r0 * 0.97 + r1 * 0.03, z0 + (z1 - z0) * 0.3), (r1, z1), (0, z1)], 48,
          Matrix.Translation(Vector((center[0], center[1], 0))))
    bm.verts.ensure_lookup_table()
    for v in bm.verts[start:]:
        d = Vector((v.co.x - center[0], v.co.y - center[1], 0))
        if d.length > 0.01:
            d *= 1 - 0.05 * max(0.0, math.cos(flutes * math.atan2(d.y, d.x)))
            v.co.x, v.co.y = center[0] + d.x, center[1] + d.y


def build_greek_column(coll):
    marble, gold, vine = bmesh.new(), bmesh.new(), bmesh.new()
    box(marble, (0, 0, 0.25), (12.4, 4.4, 0.5))
    box(marble, (0, 0, 0.75), (11.4, 3.8, 0.5))
    for x in (-3.9, 3.9):
        cyl(marble, (x, 0, 1.0), 1.3, 0.35, 24)
        fluted_column(marble, (x, 0), 1.35, 11.4, 1.0, 0.86)
        cyl(gold, (x, 0, 11.25), 0.93, 0.18, 24)
        lathe(marble, [(0, 11.45), (0.9, 11.45), (1.3, 11.9), (1.35, 12.05), (0, 12.05)], 24, Matrix.Translation(Vector((x, 0, 0))))
        box(marble, (x, 0, 12.3), (2.9, 2.9, 0.5))
    box(marble, (0, 0, 13.25), (10.8, 2.4, 1.4))
    box(gold, (0, 0, 12.72), (10.85, 2.45, 0.3))
    for i in range(9):
        for side in (-1, 1):
            box(marble, (-4.8 + i * 1.2, side * 1.24, 13.3), (0.45, 0.12, 0.9))
    box(marble, (0, 0, 14.1), (11.4, 2.9, 0.32))
    cyl(marble, (-1.8, -3.1, 0.9), 0.9, 2.2, 24, direction=(1, 0, 0))
    spiral = []
    for k in range(48):
        t = k * 0.35
        z = 1.6 + t * 0.55
        r = 1.0 + (0.86 - 1.0) * (z - 1.35) / 10.05 + 0.07
        spiral.append(Vector((3.9 + math.cos(t) * r, math.sin(t) * r, z)))
    sweep(vine, spiral, 0.08, segments=5)
    for k in range(1, 47, 3):
        p = spiral[k]
        out = Vector((p.x - 3.9, p.y, 0)).normalized()
        blob(vine, p + out * 0.18, Vector((0.28, 0.28, 0.16)), subdivisions=1)
    return [closed(coll, "ColumnMarble", marble, MARBLE, hard=True), closed(coll, "ColumnGold", gold, GOLD, hard=True),
            closed(coll, "ColumnVine", vine, MOSS)]


AMPHORA = [(0, 0), (0.62, 0), (0.6, 0.18), (0.36, 0.42), (0.75, 1.0), (1.42, 2.1), (1.58, 3.0), (1.45, 3.9),
           (1.0, 4.7), (0.55, 5.2), (0.48, 6.0), (0.72, 6.2), (0.74, 6.45), (0.4, 6.5), (0, 6.35)]


def amphora(clay, bands, matrix, scale):
    profile = [(r * scale, z * scale) for r, z in AMPHORA]
    lathe(clay, profile, 24, matrix)
    for side in (-1, 1):
        sweep(clay, [matrix @ (Vector(p) * scale) for p in curve((side * 1.2, 0, 4.4), (side * 1.9, 0, 5.6), (side * 0.6, 0, 6.0), 9)],
              0.13 * scale, segments=6)
    body = profile[4:9]
    band(bands, body, 2.3 * scale, 2.9 * scale, out=0.03 * scale, matrix=matrix)
    band(bands, body, 3.7 * scale, 3.95 * scale, out=0.03 * scale, matrix=matrix)
    band(bands, profile[9:11], 5.3 * scale, 5.5 * scale, out=0.02 * scale, matrix=matrix)


def build_amphora(coll):
    clay, bands, plinth = bmesh.new(), bmesh.new(), bmesh.new()
    box(plinth, (0, 0, 0.4), (5.6, 3.6, 0.8))
    box(plinth, (0, 0, 0.88), (5.8, 3.8, 0.16))
    amphora(clay, bands, M((-0.9, 0, 0.96)), 1.0)
    amphora(clay, bands, M((1.6, 0.3, 0.96 + 0.95), (0, math.radians(84), 0.4)), 0.62)
    return [closed(coll, "AmphoraClay", clay, (0.8, 0.42, 0.22)), closed(coll, "AmphoraBands", bands, DARK),
            closed(coll, "AmphoraPlinth", plinth, MARBLE, hard=True)]


def build_hero_statue(coll):
    marble, plinth, gold = bmesh.new(), bmesh.new(), bmesh.new()
    box(plinth, (0, 0, 0.2), (4.6, 4.6, 0.4))
    box(plinth, (0, 0, 1.9), (4.0, 4.0, 3.0))
    box(plinth, (0, 0, 3.6), (4.4, 4.4, 0.4))
    box(gold, (0, 0, 2.9), (4.06, 4.06, 0.25))
    top = 3.8
    for x, y in ((-0.45, 0.15), (0.45, -0.3)):
        cyl(marble, (x, y, top), 0.42, 3.3, 12, top=0.5)
    lathe(marble, [(0, 6.3), (1.1, 6.3), (0.95, 7.2), (0.75, 8.0), (0, 8.0)], 20)
    blob(marble, Vector((0, 0, 9.2)), Vector((1.05, 0.72, 1.45)), subdivisions=3)
    cyl(marble, (0, 0, 10.3), 0.32, 0.7, 10)
    blob(marble, Vector((0, -0.05, 11.35)), Vector((0.55, 0.58, 0.62)), subdivisions=3)
    sweep(marble, curve((0.95, 0, 10.2), (1.55, -0.2, 11.2), (1.5, -0.35, 12.6), 8), 0.26, segments=8, radius_end=0.2)
    blob(marble, Vector((1.5, -0.35, 12.8)), Vector((0.24, 0.24, 0.24)), subdivisions=2)
    torus(gold, M((1.55, -0.4, 13.35), (math.pi / 2, 0, 0.2)), 0.55, 0.13, seg=20, tseg=6)
    sweep(marble, curve((-0.95, 0, 10.2), (-1.3, -0.2, 9.4), (-1.25, -0.45, 8.5), 8), 0.26, segments=8, radius_end=0.2)
    cyl(marble, (-1.35, -0.45, 8.6), 1.05, 0.2, 20, direction=(-0.85, -0.5, 0))
    torus(gold, M((-1.45, -0.5, 8.6), (0, 0, 0)) @ align_z(Vector((-0.85, -0.5, 0))), 1.05, 0.08, seg=24, tseg=5)
    torus(gold, M((0, -0.05, 11.75)), 0.5, 0.09, seg=18, tseg=5)
    ribbon(marble, curve((0, 0.55, 10.4), (0, 1.3, 8.5), (0, 1.1, 6.6), 9), [0.95, 1.05, 1.1, 1.15, 1.2, 1.2, 1.15, 1.1, 1.0],
           0.12, up=Vector((0, 1, 0)))
    return [closed(coll, "StatueMarble", marble, MARBLE), closed(coll, "StatuePlinth", plinth, (0.75, 0.75, 0.8), hard=True),
            closed(coll, "StatueGold", gold, GOLD)]


def build_temple(coll):
    marble, roof, gold, cella = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for k, (w, d) in enumerate(((18.0, 11.0), (17.2, 10.2), (16.4, 9.4))):
        box(marble, (0, 0, 0.25 + k * 0.5), (w, d, 0.5))
    positions = [(x, y) for x in [-7.2 + 2.4 * i for i in range(7)] for y in (-4.2, 4.2)]
    positions += [(x, y) for x in (-7.2, 7.2) for y in (-1.4, 1.4)]
    for x, y in positions:
        cyl(marble, (x, y, 1.5), 0.58, 6.6, 14, top=0.5)
        box(marble, (x, y, 8.2), (1.35, 1.35, 0.35))
    box(cella, (0, 0, 4.85), (12.0, 5.2, 6.7))
    box(marble, (0, 0, 8.9), (16.4, 9.4, 1.0))
    box(gold, (0, 0, 8.52), (16.5, 9.5, 0.3))
    v = [roof.verts.new(p) for p in ((-8.4, -5.0, 9.4), (8.4, -5.0, 9.4), (8.4, 5.0, 9.4), (-8.4, 5.0, 9.4), (-8.4, 0, 11.6), (8.4, 0, 11.6))]
    for face in ((v[0], v[1], v[5], v[4]), (v[2], v[3], v[4], v[5]), (v[0], v[4], v[3]), (v[1], v[2], v[5]), (v[3], v[2], v[1], v[0])):
        roof.faces.new(face)
    for side in (-1, 1):
        x = side * 8.45
        w = [gold.verts.new(p) for p in ((x, -4.0, 9.55), (x, 4.0, 9.55), (x, 0, 11.15),
                                         (x + side * 0.12, -4.0, 9.55), (x + side * 0.12, 4.0, 9.55), (x + side * 0.12, 0, 11.15))]
        for face in ((w[0], w[1], w[2]), (w[5], w[4], w[3]), (w[0], w[3], w[4], w[1]), (w[1], w[4], w[5], w[2]), (w[2], w[5], w[3], w[0])):
            gold.faces.new(face)
    return [closed(coll, "TempleMarble", marble, MARBLE, hard=True), closed(coll, "TempleRoof", roof, (0.75, 0.4, 0.3), hard=True),
            closed(coll, "TempleGold", gold, GOLD, hard=True), closed(coll, "TempleCella", cella, (0.8, 0.78, 0.74), hard=True)]


# ---------- 5. Viking Fjord ----------

def build_longship(coll):
    hull, sail, stripes, shields_a, shields_b, metal, trim = (bmesh.new() for _ in range(7))
    length = 8.0

    def shape(y):
        u = abs(y) / length
        return max(0.06, 2.5 * (1 - u ** 2.2) ** 0.7), 0.55 + 2.4 * u ** 4, 2.7 + 1.5 * u ** 3
    sections = []
    for k in range(25):
        y = -length + 2 * length * k / 24
        w, keel, top = shape(y)
        ring = [Vector((w * math.sin(th), y, top - (top - keel) * math.cos(th)))
                for th in [-math.pi / 2 + math.pi * i / 8 for i in range(9)]]
        ring += [Vector((w * 0.88, y, top - 0.3)), Vector((-w * 0.88, y, top - 0.3))]
        sections.append(ring)
    loft(hull, sections)
    sweep(hull, curve((0, -7.7, 3.7), (0, -9.2, 5.0), (0, -8.8, 7.3), 10), 0.42, segments=8, radius_end=0.32)
    blob(trim, Vector((0, -9.2, 7.55)), Vector((0.42, 0.8, 0.45)), subdivisions=2)
    blob(trim, Vector((0, -9.5, 7.2)), Vector((0.3, 0.55, 0.2)), subdivisions=2)
    sweep(hull, curve((0, 7.7, 3.7), (0, 9.2, 5.2), (0, 8.4, 6.6), 10), 0.4, segments=8, radius_end=0.18)
    sweep(hull, curve((0, 8.4, 6.6), (0, 7.8, 6.9), (0, 8.1, 6.2), 6), 0.18, segments=6, radius_end=0.1)
    for side in (-1, 1):
        stripe = []
        for k in range(1, 24):
            y = -length + 2 * length * k / 24
            w, _, top = shape(y)
            stripe.append(Vector((side * (w + 0.02), y, top - 0.55)))
        sweep(trim, stripe, 0.12, segments=6)
        for i in range(8):
            y = -5.6 + i * 1.6
            w, _, top = shape(y)
            target = shields_a if (i + (side > 0)) % 2 == 0 else shields_b
            cyl(target, (side * (w - 0.02), y, top - 0.5), 0.62, 0.14, 16, direction=(side, 0, 0))
            blob(metal, Vector((side * (w + 0.12), y, top - 0.5)), Vector((0.18, 0.18, 0.18)), subdivisions=1)
    cyl(hull, (0, 0, 0.6), 0.28, 12.6, 10)
    cyl(hull, (-3.8, 0, 12.0), 0.18, 7.6, 8, direction=(1, 0, 0))
    edges = [-3.4 + 6.8 * i / 6 for i in range(7)]
    for i in range(6):
        cloth(sail if i % 2 == 0 else stripes, [edges[i] + (edges[i + 1] - edges[i]) * k / 2 for k in range(3)],
              lambda x: 6.2, 11.8, 0.12,
              lambda x, z: -0.9 * math.sin(math.pi * (x + 3.4) / 6.8) * math.sin(math.pi * (z - 6.2) / 5.6))
    return [closed(coll, "LongshipHull", hull, WOOD), closed(coll, "LongshipSail", sail, (0.95, 0.92, 0.82)),
            closed(coll, "LongshipStripes", stripes, RED), closed(coll, "LongshipShieldsA", shields_a, RED),
            closed(coll, "LongshipShieldsB", shields_b, GOLD), closed(coll, "LongshipMetal", metal, STEEL),
            closed(coll, "LongshipTrim", trim, GOLD)]


def build_rune_stone(coll):
    rng = random.Random(17)
    rock, glow = bmesh.new(), bmesh.new()
    blob(rock, Vector((0, 0, 4.1)), Vector((2.3, 0.85, 4.3)), subdivisions=4, lump=0.02, seed=7, floor=0.0)
    for i in range(4):
        a = i / 4 * 2 * math.pi + 0.4
        rough_rock(rock, (math.cos(a) * 2.2, math.sin(a) * 1.2, 0.35), (0.7, 0.6, 0.45), rng, subdivisions=1, jitter=0.2, floor=0.0)

    def surface(x, z, side):
        q = 1 - (x / 2.3) ** 2 - ((z - 4.1) / 4.3) ** 2
        return Vector((x, side * (0.85 * math.sqrt(max(q, 0.0)) + 0.04), z))
    for side in (-1, 1):
        loop = [surface(1.7 * math.sin(t), 4.1 + 3.3 * math.cos(t), side) for t in [math.radians(-150 + 300 * k / 30) for k in range(31)]]
        sweep(glow, loop, 0.13, segments=6)
        blob(glow, loop[-1] + Vector((0.1, 0, -0.15)), Vector((0.26, 0.12, 0.2)), subdivisions=1)
        for row in range(3):
            for col in range(4):
                x, z = -0.9 + col * 0.6, 5.3 - row * 1.2
                p = surface(x, z, side)
                box(glow, p, (0.1, 0.12, 0.7))
                box(glow, p + Vector((0.12, 0, 0.15)), (0.08, 0.12, 0.42), rotation=(0, 0.7 if (row + col) % 2 else -0.7, 0))
    rock_obj = closed(coll, "RuneStoneRock", rock, STONE)
    moss = lit_shell(coll, rock_obj, "RuneStoneMoss", MOSS, sun=Vector((0, 0, 1)), threshold=0.62,
                     wobble_scale=0.6, wobble=0.25, lift=0.04, min_island=5)
    return [rock_obj, closed(coll, "RuneStoneGlow", glow, CYAN), moss]


def build_shield_rack(coll):
    wood, shields_a, shields_b, metal = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for x in (-4.4, 4.4):
        for lean in (-1, 1):
            sweep(wood, [Vector((x, lean * 1.0, 0)), Vector((x, 0, 5.6))], 0.2, segments=6)
    box(wood, (0, 0, 5.2), (9.4, 0.4, 0.4))
    box(wood, (0, 0.1, 2.0), (9.0, 0.35, 0.35))
    for i, x in enumerate((-3.15, -1.05, 1.05, 3.15)):
        tilt = Vector((0, 0.22, 1)).normalized()
        face_dir = Vector((0, -1, 0.22)).normalized()
        base, accent = (shields_a, shields_b) if i % 2 == 0 else (shields_b, shields_a)
        center = Vector((x, -0.35, 3.45))
        cyl(base, center, 1.15, 0.14, 24, direction=face_dir)
        torus(metal, Matrix.Translation(center + face_dir * 0.07) @ align_z(face_dir), 1.15, 0.07, seg=24, tseg=5)
        blob(metal, center + face_dir * 0.2, Vector((0.24, 0.24, 0.24)), subdivisions=2)
        rot = align_z(face_dir).to_3x3()
        for angle in (0.0, math.pi / 2):
            cube = bmesh.ops.create_cube(accent, size=1.0)
            spin = Matrix.Rotation(angle, 3, "Z")
            for v in cube["verts"]:
                v.co = center + face_dir * 0.1 + rot @ spin @ Vector((v.co.x * 2.1, v.co.y * 0.32, v.co.z * 0.05))
    for x, lean in ((-5.2, -0.25), (5.2, 0.25)):
        sweep(wood, [Vector((x, -0.6, 0)), Vector((x + lean * 4.5, -0.6, 4.6))], 0.1, segments=6)
        head = Vector((x + lean * 4.5, -0.6, 4.6))
        box(metal, head + Vector((lean * 1.4, 0, -0.35)), (0.9, 0.12, 0.8), rotation=(0, -lean * 0.3, 0))
    return [closed(coll, "RackWood", wood, WOOD), closed(coll, "RackShieldsA", shields_a, RED),
            closed(coll, "RackShieldsB", shields_b, (0.95, 0.85, 0.6)), closed(coll, "RackMetal", metal, STEEL)]


# ---------- 6. Samurai Gardens ----------

def build_torii(coll):
    red, black, gold = bmesh.new(), bmesh.new(), bmesh.new()
    for x in (-4.6, 4.6):
        cyl(red, (x, 0, 0.8), 0.55, 10.4, 16, top=0.47)
        cyl(black, (x, 0, 0), 0.78, 0.9, 16, top=0.68)
    box(red, (0, 0, 8.6), (12.4, 0.6, 0.7))
    box(red, (0, 0, 10.75), (13.4, 0.8, 0.5))
    box(red, (0, 0, 9.7), (0.8, 0.5, 1.6))
    beam = [Vector((x, 0, 11.35 + 0.9 * (abs(x) / 7.2) ** 2.2)) for x in [-7.2 + 14.4 * k / 24 for k in range(25)]]
    sweep_profile(black, beam, [(-0.38, -0.5), (0.38, -0.5), (0.38, 0.5), (-0.38, 0.5)])
    box(black, (0, -0.32, 9.75), (1.5, 0.2, 2.0))
    box(gold, (0, -0.4, 9.75), (1.2, 0.08, 1.7))
    return [closed(coll, "ToriiRed", red, RED, hard=True), closed(coll, "ToriiBlack", black, DARK, hard=True),
            closed(coll, "ToriiGold", gold, GOLD, hard=True)]


def build_stone_lantern(coll):
    stone, glow = bmesh.new(), bmesh.new()
    lathe(stone, [(0, 0), (1.6, 0), (1.5, 0.5), (0, 0.5)], 6)
    lathe(stone, [(0, 0.5), (0.5, 0.5), (0.45, 1.9), (0.62, 2.05), (0.45, 2.2), (0.42, 3.2), (0, 3.2)], 12)
    lathe(stone, [(0, 3.15), (1.35, 3.15), (1.25, 3.6), (0, 3.6)], 6)
    box(glow, (0, 0, 4.3), (1.25, 1.25, 1.2))
    for x in (-0.65, 0.65):
        for y in (-0.65, 0.65):
            box(stone, (x, y, 4.3), (0.36, 0.36, 1.4))
    box(stone, (0, 0, 3.65), (1.7, 1.7, 0.18))
    start = len(stone.verts)
    lathe(stone, [(0, 6.6), (0.5, 6.2), (1.5, 5.55), (2.25, 5.1), (2.3, 4.95), (0, 5.05)], 4, Matrix.Rotation(math.pi / 4, 4, "Z"))
    stone.verts.ensure_lookup_table()
    for v in stone.verts[start:]:
        if Vector((v.co.x, v.co.y, 0)).length > 2.0:
            v.co.z += 0.35
    blob(stone, Vector((0, 0, 6.85)), Vector((0.38, 0.38, 0.45)), subdivisions=2)
    lathe(stone, [(0, 7.2), (0.12, 7.2), (0.02, 7.6), (0, 7.6)], 8)
    stone_obj = closed(coll, "LanternStone", stone, STONE)
    smooth_by_angle(stone_obj, 40)
    moss = lit_shell(coll, stone_obj, "LanternMoss", MOSS, sun=Vector((0, 0, 1)), threshold=0.6,
                     wobble_scale=0.8, wobble=0.25, lift=0.04, min_island=3)
    return [stone_obj, closed(coll, "LanternGlow", glow, (1.0, 0.85, 0.5), hard=True), moss]


def build_cherry_tree(coll):
    rng = random.Random(31)
    trunk, canopy, petals = bmesh.new(), bmesh.new(), bmesh.new()
    sweep(trunk, curve((0, 0, 0), (0.9, 0.2, 2.4), (0.4, 0.3, 4.6), 10), 0.85, segments=12, radius_end=0.5)
    tips = []
    for i in range(6):
        a = i / 6 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        r, h = rng.uniform(3.2, 4.6), rng.uniform(6.2, 8.2)
        tip = Vector((math.cos(a) * r, math.sin(a) * r, h))
        tips.append(tip)
        sweep(trunk, curve((0.4, 0.3, 4.2), (math.cos(a) * r * 0.4, math.sin(a) * r * 0.4, h * 0.85), tip, 9), 0.42, segments=8, radius_end=0.14)
    blobs = bmesh.new()
    blob(blobs, Vector((0.2, 0.2, 8.6)), Vector((3.0, 3.0, 2.0)), subdivisions=3)
    for tip in tips:
        blob(blobs, tip + Vector((0, 0, 0.6)), Vector((2.3, 2.3, 1.6)) * rng.uniform(0.85, 1.1), subdivisions=3)
    blossom = fused_surface(coll, "CherryBlossom", blobs, 0.45, 1.2, 0.5, (0.98, 0.65, 0.78))
    if triangles(blossom) > 9000:
        decimate(blossom, 9000 / triangles(blossom))
    light = lit_shell(coll, blossom, "CherryBlossomLight", (1.0, 0.85, 0.9), threshold=0.5, min_island=20)
    blob(petals, Vector((0, 0, 0)), Vector((5.4, 5.0, 0.18)), subdivisions=3, lump=0.2, seed=3, floor=0.0)
    return [closed(coll, "CherryTrunk", trunk, DARK_WOOD), blossom, light, closed(coll, "CherryPetals", petals, (1.0, 0.8, 0.88))]


def build_pagoda(coll):
    walls, roofs, gold, stone = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    box(stone, (0, 0, 0.4), (9.4, 9.4, 0.8))
    z = 0.8
    for i in range(5):
        half = 3.0 - i * 0.42
        box(walls, (0, 0, z + 0.95), (half * 2, half * 2, 1.9))
        box(gold, (0, 0, z + 1.75), (half * 2 + 0.1, half * 2 + 0.1, 0.18))
        eave = half + 1.5
        start = len(roofs.verts)
        root2 = math.sqrt(2)
        lathe(roofs, [(0, z + 2.65), (half * 0.9 * root2, z + 2.55), (eave * root2, z + 1.85), (eave * root2, z + 1.7),
                      (half * root2, z + 1.85), (0, z + 1.85)], 4, Matrix.Rotation(math.pi / 4, 4, "Z"))
        roofs.verts.ensure_lookup_table()
        for v in roofs.verts[start:]:
            if Vector((v.co.x, v.co.y, 0)).length > (half + 0.8) * root2:
                v.co.z += 0.45
        z += 2.65
    cyl(gold, (0, 0, z - 0.1), 0.18, 3.3, 8)
    for k in range(5):
        torus(gold, M((0, 0, z + 0.6 + k * 0.45)), 0.42 - k * 0.05, 0.08, seg=14, tseg=5)
    box(walls, (0, -3.02, 1.7), (1.6, 0.1, 1.5))
    return [closed(coll, "PagodaWalls", walls, RED, hard=True), closed(coll, "PagodaRoofs", roofs, (0.15, 0.3, 0.3), hard=True),
            closed(coll, "PagodaGold", gold, GOLD), closed(coll, "PagodaStone", stone, STONE, hard=True)]


# ---------- 7. Knight's Kingdom ----------

def build_banner(coll):
    pole, cloth_bm, emblem, trim = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    lathe(pole, [(0, 0), (1.0, 0), (0.85, 0.4), (0.3, 0.6), (0, 0.6)], 12)
    cyl(pole, (0, 0, 0.5), 0.18, 15.6, 8)
    cyl(pole, (-2.3, 0, 15.2), 0.13, 4.6, 8, direction=(1, 0, 0))
    lathe(trim, [(0, 16.0), (0.3, 16.1), (0.12, 16.8), (0, 17.2)], 8)
    for x in (-2.35, 2.35):
        blob(trim, Vector((x, 0, 15.2)), Vector((0.22, 0.22, 0.22)), subdivisions=2)
    xs = [-1.9 + 3.8 * k / 8 for k in range(9)]
    cloth(cloth_bm, xs, lambda x: 6.4 + 1.6 * (1 - abs(x) / 1.9), 15.0, 0.14,
          lambda x, z: 0.22 * math.sin(z * 0.8 + x * 0.6) * (15.0 - z) / 8.6, rows=10)
    box(trim, (0, 0, 14.9), (3.95, 0.2, 0.3))
    for side in (-1, 1):
        cyl(emblem, (0, side * 0.04, 12.0), 0.95, 0.1, 20, direction=(0, side, 0))
        for k in (-1, 0, 1):
            cyl(emblem, (k * 0.45, side * 0.06, 13.0), 0.16, 0.6 if k == 0 else 0.45, 6, top=0.01)
        box(emblem, (0, side * 0.06, 12.95), (1.3, 0.08, 0.2))
    return [closed(coll, "BannerPole", pole, DARK_WOOD), closed(coll, "BannerCloth", cloth_bm, RED),
            closed(coll, "BannerEmblem", emblem, GOLD), closed(coll, "BannerTrim", trim, GOLD)]


def build_catapult(coll):
    wood, metal, rock = bmesh.new(), bmesh.new(), bmesh.new()
    for x in (-2.2, 2.2):
        box(wood, (x, 0, 1.4), (0.6, 9.0, 0.6))
    for y in (-3.8, 3.8):
        box(wood, (0, y, 1.4), (5.0, 0.6, 0.6))
    for x in (-2.75, 2.75):
        for y in (-3.0, 3.0):
            cyl(wood, (x - 0.25 * (1 if x > 0 else -1), y, 1.2), 1.2, 0.5, 16, direction=(1 if x > 0 else -1, 0, 0))
            torus(metal, Matrix.Translation(Vector((x + 0.0, y, 1.2))) @ Matrix.Rotation(math.pi / 2, 4, "Y"), 1.2, 0.12, seg=20, tseg=5)
    for x in (-2.2, 2.2):
        sweep(wood, [Vector((x, 1.8, 1.7)), Vector((x * 0.65, -1.0, 6.6))], 0.3, segments=6)
        sweep(wood, [Vector((x, -3.4, 1.7)), Vector((x * 0.65, -1.0, 6.6))], 0.26, segments=6)
    cyl(metal, (-1.8, -1.0, 6.6), 0.22, 3.6, 10, direction=(1, 0, 0))
    cyl(wood, (-1.6, 3.0, 1.75), 0.35, 3.2, 10, direction=(1, 0, 0))
    arm = [Vector((0, 3.2, 1.9)), Vector((0, -2.4, 8.6))]
    sweep(wood, arm, 0.36, segments=8)
    for t in (0.25, 0.55):
        p = arm[0].lerp(arm[1], t)
        torus(metal, Matrix.Translation(p) @ align_z(arm[1] - arm[0]), 0.4, 0.08, seg=14, tseg=5)
    lathe(wood, [(0, -0.2), (0.95, 0.1), (1.0, 0.55), (0.75, 0.6), (0.6, 0.2), (0, 0.05)], 14,
          Matrix.Translation(Vector((0, -2.55, 8.75))) @ align_z(Vector((0, -0.4, 1))))
    rough_rock(rock, (0, -2.6, 9.55), (0.8, 0.8, 0.75), random.Random(2), subdivisions=2, jitter=0.15, floor=None)
    return [closed(coll, "CatapultWood", wood, WOOD), closed(coll, "CatapultMetal", metal, STEEL),
            closed(coll, "CatapultRock", rock, STONE)]


def build_armor_stand(coll):
    wood, steel, plume, gold, visor = (bmesh.new() for _ in range(5))
    box(wood, (0, 0, 0.25), (3.2, 3.2, 0.5))
    for x in (-0.45, 0.45):
        cyl(steel, (x, 0, 0.5), 0.36, 3.5, 12, top=0.42)
        blob(steel, Vector((x, -0.1, 2.3)), Vector((0.42, 0.45, 0.38)), subdivisions=2)
        blob(steel, Vector((x, -0.25, 0.7)), Vector((0.42, 0.7, 0.3)), subdivisions=2)
    lathe(steel, [(0, 3.8), (1.15, 3.8), (0.95, 4.6), (0, 4.6)], 16)
    blob(steel, Vector((0, 0, 5.6)), Vector((1.2, 0.85, 1.3)), subdivisions=3)
    torus(gold, M((0, 0, 4.7)), 0.98, 0.1, seg=20, tseg=5)
    box(gold, (0, -0.86, 5.7), (0.18, 0.12, 1.2))
    box(gold, (0, -0.84, 5.95), (0.9, 0.12, 0.18))
    for side in (-1, 1):
        blob(steel, Vector((side * 1.3, 0, 6.6)), Vector((0.62, 0.62, 0.46)), subdivisions=2)
        sweep(steel, curve((side * 1.35, 0, 6.3), (side * 1.6, -0.2, 5.2), (side * 0.4, -1.0, 4.6), 8), 0.28, segments=8, radius_end=0.24)
    cyl(steel, (0, 0, 6.8), 0.35, 0.4, 10)
    lathe(steel, [(0, 7.1), (0.64, 7.1), (0.66, 8.2), (0.5, 8.6), (0, 8.75)], 16)
    box(visor, (0, -0.62, 7.85), (0.9, 0.1, 0.12))
    box(visor, (0, -0.62, 7.55), (0.1, 0.1, 0.5))
    sweep(plume, curve((0, 0, 8.6), (0, 0.6, 9.6), (0, 1.7, 9.0), 10), 0.3, segments=8, radius_end=0.08)
    sweep(plume, curve((0, 0.1, 8.6), (0.2, 0.9, 9.3), (0.3, 1.6, 8.5), 9), 0.18, segments=6, radius_end=0.05)
    box(steel, (0, -1.1, 2.3), (0.28, 0.08, 3.4))
    box(gold, (0, -1.1, 4.1), (1.1, 0.22, 0.18))
    cyl(wood, (0, -1.1, 4.15), 0.11, 0.55, 8)
    blob(gold, Vector((0, -1.1, 4.8)), Vector((0.18, 0.18, 0.18)), subdivisions=1)
    return [closed(coll, "ArmorWood", wood, WOOD), closed(coll, "ArmorSteel", steel, STEEL), closed(coll, "ArmorPlume", plume, RED),
            closed(coll, "ArmorGold", gold, GOLD), closed(coll, "ArmorVisor", visor, DARK)]


def build_castle(coll):
    stone, roofs, flags, door = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for x, y, sx, sy in ((0, -7.0, 14.0, 1.2), (0, 7.0, 14.0, 1.2), (-7.0, 0, 1.2, 14.0), (7.0, 0, 1.2, 14.0)):
        box(stone, (x, y, 3.0), (sx, sy, 6.0))
        count = int(max(sx, sy) / 1.2)
        for k in range(count):
            if k % 2 == 0:
                offset = -max(sx, sy) / 2 + (k + 0.5) * max(sx, sy) / count
                box(stone, (x + (offset if sx > sy else 0), y + (offset if sy > sx else 0), 6.4), (1.0 if sx > sy else 1.3, 1.3 if sx > sy else 1.0, 0.8))
    for x in (-7.0, 7.0):
        for y in (-7.0, 7.0):
            cyl(stone, (x, y, 0), 1.9, 8.5, 16)
            lathe(roofs, [(0, 8.4), (2.25, 8.4), (0, 12.4)], 16, Matrix.Translation(Vector((x, y, 0))))
            cyl(flags, (x, y, 12.2), 0.06, 1.6, 6)
            box(flags, (x + 0.5, y, 13.45), (1.0, 0.06, 0.6))
    box(stone, (0, 1.0, 5.5), (6.0, 6.0, 11.0))
    square_frustum(roofs, 10.9, 3.4, 14.6, 0.0, center=(0, 1.0))
    cyl(flags, (0, 1.0, 14.4), 0.07, 1.8, 6)
    box(flags, (0.6, 1.0, 15.85), (1.2, 0.06, 0.7))
    box(door, (0, -7.6, 1.8), (2.4, 0.3, 3.6))
    cyl(door, (0, -7.45, 3.6), 1.2, 0.3, 16, direction=(0, -1, 0))
    for x in (-1.6, 1.6):
        for z in (6.5, 8.8):
            box(door, (x, -2.02, z), (0.6, 0.1, 1.1))
    return [closed(coll, "CastleStone", stone, STONE, hard=True), closed(coll, "CastleRoofs", roofs, (0.2, 0.3, 0.75), hard=True),
            closed(coll, "CastleFlags", flags, RED, hard=True), closed(coll, "CastleDoor", door, DARK, hard=True)]


# ---------- 8. Frontier Town ----------

TANK = [(0, 9.4), (3.0, 9.4), (3.05, 11.8), (3.0, 14.2), (0, 14.2)]


def build_water_tower(coll):
    wood, tank, bands, roof = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    corners = [(sx, sy) for sx in (-1, 1) for sy in (-1, 1)]
    for sx, sy in corners:
        sweep(wood, [Vector((sx * 3.2, sy * 3.2, 0)), Vector((sx * 2.4, sy * 2.4, 9.2))], 0.3, segments=6)
    for (ax, ay), (bx, by) in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
        for z0, z1 in ((0.6, 4.6), (4.6, 8.6)):
            s0, s1 = 3.2 - 0.8 * z0 / 9.2, 3.2 - 0.8 * z1 / 9.2
            sweep(wood, [Vector((ax * s0, ay * s0, z0)), Vector((bx * s1, by * s1, z1))], 0.13, segments=5)
            sweep(wood, [Vector((bx * s0, by * s0, z0)), Vector((ax * s1, ay * s1, z1))], 0.13, segments=5)
    cyl(wood, (0, 0, 9.0), 3.4, 0.4, 24)
    start = len(tank.verts)
    lathe(tank, TANK, 24)
    for z in (10.0, 11.7, 13.4):
        band(bands, TANK[1:4], z, z + 0.2, out=0.06, depth=0.15)
    lathe(roof, [(0, 14.1), (3.45, 14.1), (3.4, 14.4), (0, 16.7)], 24)
    blob(roof, Vector((0, 0, 16.75)), Vector((0.25, 0.25, 0.25)), subdivisions=1)
    for x in (-0.45, 0.45):
        sweep(wood, [Vector((x, -3.35, 0)), Vector((x, -3.35, 9.4))], 0.09, segments=5)
    for k in range(12):
        sweep(wood, [Vector((-0.45, -3.35, 0.6 + k * 0.75)), Vector((0.45, -3.35, 0.6 + k * 0.75))], 0.06, segments=4)
    sweep(bands, [Vector((2.9, 0, 11.0)), Vector((3.9, 0, 10.6)), Vector((4.2, 0, 9.6))], 0.22, segments=8)
    return [closed(coll, "TowerWood", wood, DARK_WOOD), closed(coll, "TowerTank", tank, WOOD),
            closed(coll, "TowerBands", bands, STEEL), closed(coll, "TowerRoof", roof, RED)]


def wheel(rim_bm, spoke_bm, center, radius):
    matrix = Matrix.Translation(center) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    torus(rim_bm, matrix, radius, 0.15, seg=24, tseg=6)
    spoked_hub(spoke_bm, matrix, radius - 0.1, 10, 0.32, 0.25, spoke_width=0.13)


def build_wagon(coll):
    wood, canvas, wheels, iron = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    box(wood, (0, 0, 2.5), (3.6, 8.0, 1.0))
    box(wood, (0, 0, 1.85), (2.6, 7.2, 0.3))
    for side in (-1, 1):
        box(wood, (side * 1.85, 0, 3.15), (0.12, 8.0, 0.35))
    sections = []
    for k in range(9):
        y = -3.6 + 7.2 * k / 8
        gather = 1 - 0.12 * abs(y / 3.6) ** 3
        sections.append([Vector((math.cos(a) * 1.85 * gather, y, 3.0 + math.sin(a) * 2.0 * gather))
                         for a in [math.pi * i / 12 for i in range(13)]])
    loft(canvas, sections)
    for y in (-3.3, -1.1, 1.1, 3.3):
        gather = 1 - 0.12 * abs(y / 3.6) ** 3
        sweep(wood, [Vector((math.cos(a) * 1.92 * gather, y, 3.0 + math.sin(a) * 2.07 * gather)) for a in [math.pi * i / 12 for i in range(13)]],
              0.08, segments=5)
    for x in (-2.05, 2.05):
        for y in (-2.8, 2.8):
            wheel(iron, wheels, Vector((x, y, 1.7)), 1.6)
    cyl(iron, (-2.2, -2.8, 1.7), 0.12, 4.4, 8, direction=(1, 0, 0))
    cyl(iron, (-2.2, 2.8, 1.7), 0.12, 4.4, 8, direction=(1, 0, 0))
    sweep(wood, [Vector((0, -4.0, 2.2)), Vector((0, -7.0, 1.4))], 0.14, segments=6)
    cyl(wood, (-1.1, -6.9, 1.45), 0.1, 2.2, 6, direction=(1, 0, 0))
    return [closed(coll, "WagonWood", wood, WOOD), closed(coll, "WagonCanvas", canvas, (0.93, 0.9, 0.8)),
            closed(coll, "WagonWheels", wheels, DARK_WOOD), closed(coll, "WagonIron", iron, (0.25, 0.25, 0.27))]


BARREL = [(0, 0), (0.88, 0), (1.05, 1.1), (0.88, 2.2), (0, 2.2)]


def build_barrels(coll):
    wood, bands, crate = bmesh.new(), bmesh.new(), bmesh.new()
    placements = [M((0, 0, 0)), M((1.95, 0.5, 0)), M((-0.6, 1.95, 0)), M((0.9, -1.75, 1.0), (math.pi / 2, 0, 0.5))]
    for matrix in placements:
        lathe(wood, BARREL, 16, matrix)
        for z in (0.3, 1.8):
            band(bands, BARREL[1:4], z, z + 0.14, out=0.04, depth=0.1, segments=16, matrix=matrix)
    box(crate, (-2.0, -0.6, 0.85), (1.7, 1.7, 1.7), rotation=(0, 0, 0.3))
    for dz in (-0.78, 0.78):
        box(bands, (-2.0, -0.6, 0.85 + dz), (1.76, 1.76, 0.16), rotation=(0, 0, 0.3))
    return [closed(coll, "BarrelWood", wood, WOOD), closed(coll, "BarrelBands", bands, (0.3, 0.3, 0.32)),
            closed(coll, "BarrelCrate", crate, (0.75, 0.58, 0.35), hard=True)]


# ---------- 9. Clockwork Foundry ----------

def build_gear_tower(coll):
    brass, copper, steel = bmesh.new(), bmesh.new(), bmesh.new()
    box(steel, (0, 0, 0.5), (14.0, 3.2, 1.0))
    for x in (-6.5, -3.5, -0.5, 2.5, 5.5):
        blob(steel, Vector((x, -1.62, 0.5)), Vector((0.18, 0.08, 0.18)), subdivisions=1)
    standing = Matrix.Rotation(math.pi / 2, 4, "X")
    big = Vector((-2.6, 0, 8.2))
    gear(brass, Matrix.Translation(big) @ standing, 5.0, 4.4, 3.4, 20, 0.8)
    spoked_hub(brass, Matrix.Translation(big) @ standing, 3.5, 6, 0.9, 0.8)
    medium = big + Vector((7.5 * math.cos(math.radians(-30)), 0.9, 7.5 * math.sin(math.radians(-30))))
    gear(copper, Matrix.Translation(medium) @ standing, 3.2, 2.7, 2.0, 13, 0.7)
    spoked_hub(copper, Matrix.Translation(medium) @ standing, 2.1, 5, 0.6, 0.7)
    small = medium + Vector((4.6 * math.cos(math.radians(70)), -0.8, 4.6 * math.sin(math.radians(70))))
    gear(brass, Matrix.Translation(small) @ standing, 1.9, 1.55, 0.6, 9, 0.6)
    for center in (big, medium, small):
        cyl(steel, center + Vector((0, 2.0, 0)), 0.42, 3.4, 12, direction=(0, -1, 0))
        box(steel, (center.x, 2.0, (center.z + 1.0) / 2), (0.7, 0.7, center.z - 1.0))
    return [closed(coll, "GearBrass", brass, BRASS, hard=True), closed(coll, "GearCopper", copper, COPPER, hard=True),
            closed(coll, "GearSteel", steel, STEEL, hard=True)]


def build_pipe_works(coll):
    copper, brass, steel, face, steam = (bmesh.new() for _ in range(5))
    cyl(copper, (-3.5, 0, 2.6), 2.0, 7.0, 24, direction=(1, 0, 0))
    for x in (-3.5, 3.5):
        blob(copper, Vector((x, 0, 2.6)), Vector((0.6, 2.0, 2.0)), subdivisions=3)
    for x in (-2.2, 0.0, 2.2):
        torus(brass, Matrix.Translation(Vector((x, 0, 2.6))) @ Matrix.Rotation(math.pi / 2, 4, "Y"), 2.04, 0.12, seg=24, tseg=5)
    for x in (-2.6, 2.6):
        box(steel, (x, 0, 0.45), (0.8, 3.4, 0.9))
    cyl(steel, (2.6, 0, 4.3), 0.85, 6.2, 16, top=0.7)
    lathe(steel, [(0, 10.4), (0.7, 10.4), (1.05, 11.0), (0.95, 11.1), (0, 11.1)], 16, Matrix.Translation(Vector((2.6, 0, 0))))
    for k, size in enumerate((0.75, 1.0, 1.25)):
        blob(steam, Vector((2.6 + k * 0.35, 0, 11.6 + k * 1.1)), Vector((size, size, size * 0.8)), subdivisions=2, lump=0.15, seed=k)
    pipe = [Vector((-2.0, 0, 4.4)), Vector((-2.0, 0, 7.0)), Vector((-1.4, 0, 7.8)), Vector((0.6, 0, 7.8)), Vector((1.8, 0, 7.4))]
    sweep(copper, curve(pipe[0], pipe[1], pipe[2], 6) + curve(pipe[2], pipe[3], pipe[4], 6)[1:], 0.35, segments=10)
    sweep(copper, curve((-4.4, 0, 4.3), (-4.4, 0, 6.0), (-5.4, 0, 6.4), 8), 0.3, segments=10)
    wheel_at = Vector((-0.4, -0.55, 7.8))
    torus(brass, Matrix.Translation(wheel_at) @ Matrix.Rotation(math.pi / 2, 4, "X"), 0.65, 0.09, seg=18, tseg=5)
    spoked_hub(brass, Matrix.Translation(wheel_at) @ Matrix.Rotation(math.pi / 2, 4, "X"), 0.6, 4, 0.14, 0.12, spoke_width=0.1)
    cyl(steel, (-3.6, -1.4, 0), 0.18, 5.6, 8)
    gauge = Vector((-3.6, -1.55, 6.2))
    cyl(face, gauge, 0.8, 0.12, 24, direction=(0, -1, 0))
    torus(brass, Matrix.Translation(gauge + Vector((0, -0.1, 0))) @ Matrix.Rotation(math.pi / 2, 4, "X"), 0.82, 0.1, seg=24, tseg=5)
    box(steel, gauge + Vector((0.22, -0.16, 0.18)), (0.55, 0.05, 0.08), rotation=(0, -0.7, 0))
    return [closed(coll, "PipeCopper", copper, COPPER), closed(coll, "PipeBrass", brass, BRASS), closed(coll, "PipeSteel", steel, STEEL),
            closed(coll, "PipeGauge", face, (0.95, 0.92, 0.82)), closed(coll, "PipeSteam", steam, (0.92, 0.92, 0.95))]


def build_smokestack(coll):
    brick, bands, smoke, roof, windows = (bmesh.new() for _ in range(5))
    box(brick, (0, 0, 2.5), (12.0, 7.0, 5.0))
    for k in range(4):
        x0 = -6.0 + k * 3.0
        v = [roof.verts.new(p) for p in ((x0, -3.5, 5.0), (x0 + 3.0, -3.5, 5.0), (x0 + 3.0, -3.5, 7.0),
                                          (x0, 3.5, 5.0), (x0 + 3.0, 3.5, 5.0), (x0 + 3.0, 3.5, 7.0))]
        for face in ((v[0], v[2], v[1]), (v[3], v[4], v[5]), (v[0], v[3], v[5], v[2]), (v[1], v[2], v[5], v[4]), (v[0], v[1], v[4], v[3])):
            roof.faces.new(face)
    for (x, y, height, r) in ((3.4, 1.4, 11.0, 1.3), (-2.4, 1.8, 8.0, 1.1)):
        cyl(brick, (x, y, 5.0), r, height, 16, top=r * 0.8)
        for k in range(1, 4):
            z = 5.0 + height * k / 4
            torus(bands, M((x, y, z)), r - (r * 0.2) * k / 4 + 0.03, 0.12, seg=20, tseg=5)
        top = 5.0 + height
        lathe(bands, [(0, top - 0.2), (r * 0.8, top - 0.2), (r * 1.05, top + 0.4), (r * 0.95, top + 0.5), (0, top + 0.5)], 16,
              Matrix.Translation(Vector((x, y, 0))))
        for k, size in enumerate((0.9, 1.2, 1.5)):
            if top + 1.0 + k * 1.3 + size < 19.6:
                blob(smoke, Vector((x + k * 0.5, y, top + 1.0 + k * 1.3)), Vector((size, size, size * 0.8)), subdivisions=2, lump=0.15, seed=x + k)
    for i in range(5):
        x = -4.8 + i * 2.4
        box(windows, (x, -3.55, 2.4), (1.1, 0.12, 1.6))
        cyl(windows, (x, -3.49, 3.2), 0.55, 0.12, 12, direction=(0, -1, 0))
    return [closed(coll, "StackBrick", brick, (0.6, 0.3, 0.22), hard=True), closed(coll, "StackBands", bands, BRASS),
            closed(coll, "StackSmoke", smoke, (0.6, 0.6, 0.62)), closed(coll, "StackRoof", roof, (0.25, 0.27, 0.3), hard=True),
            closed(coll, "StackWindows", windows, (1.0, 0.75, 0.35), hard=True)]


# ---------- 10. Chrono Nexus ----------

def build_time_ring(coll):
    metal, glow, base = bmesh.new(), bmesh.new(), bmesh.new()
    lathe(base, [(0, 0), (2.8, 0), (2.6, 0.5), (2.1, 0.6), (1.9, 1.1), (0, 1.1)], 24)
    standing = Matrix.Rotation(math.pi / 2, 4, "X")
    center = Vector((0, 0, 6.6))
    torus(metal, Matrix.Translation(center) @ standing, 5.0, 0.55, seg=48, tseg=12)
    torus(glow, Matrix.Translation(center) @ standing, 4.3, 0.22, seg=48, tseg=8)
    for k in range(12):
        a = 2 * math.pi * k / 12
        p = center + Vector((math.cos(a) * 5.75, 0, math.sin(a) * 5.75))
        box(glow, p, (0.25, 0.3, 0.7 if k % 3 == 0 else 0.42), rotation=(0, -a + math.pi / 2, 0))
    for side in (-1, 1):
        sweep(metal, [Vector((side * 1.6, 0, 0.9)), Vector((side * 2.6, 0, 1.9)), Vector((side * 2.1, 0, 2.2))], 0.35, segments=8)
    spiral = []
    for k in range(60):
        t = k / 59
        r = 3.8 * (1 - t) + 0.3 * t
        a = t * 2.5 * 2 * math.pi
        spiral.append(center + Vector((math.cos(a) * r, 0, math.sin(a) * r)))
    sweep(glow, spiral, 0.11, segments=5, radius_end=0.06)
    return [closed(coll, "TimeRingMetal", metal, (0.85, 0.87, 0.92)), closed(coll, "TimeRingGlow", glow, CYAN),
            closed(coll, "TimeRingBase", base, (0.3, 0.3, 0.38), hard=True)]


GLASS = [(0, 0.45), (1.25, 0.55), (1.35, 1.6), (1.05, 2.6), (0.28, 3.3), (0.28, 3.55), (1.05, 4.25), (1.35, 5.25), (1.25, 6.3), (0, 6.4)]


def build_hourglass(coll):
    frame, glass, sand = bmesh.new(), bmesh.new(), bmesh.new()
    for z in (0.0, 6.4):
        lathe(frame, [(0, z), (1.95, z), (1.95, z + 0.3), (1.7, z + 0.45), (0, z + 0.45)], 24)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        p = Vector((math.cos(a) * 1.6, math.sin(a) * 1.6, 0))
        lathe(frame, [(0, 0.4), (0.16, 0.4), (0.22, 2.0), (0.14, 3.4), (0.22, 4.8), (0.16, 6.45), (0, 6.45)], 8, Matrix.Translation(p))
    for z in (-0.25, 7.1):
        blob(frame, Vector((0, 0, z + 0.25)), Vector((0.32, 0.32, 0.32)), subdivisions=2)
    lathe(glass, GLASS, 24)
    lathe(sand, [(0, 0.5), (1.15, 0.6), (1.0, 1.5), (0.45, 2.1), (0, 2.25)], 20)
    lathe(sand, [(0, 4.1), (0.95, 4.4), (0.9, 4.8), (0, 4.75)], 20)
    cyl(sand, (0, 0, 2.2), 0.06, 1.95, 6)
    return [closed(coll, "HourglassFrame", frame, GOLD), closed(coll, "HourglassGlass", glass, (0.7, 0.9, 1.0)),
            closed(coll, "HourglassSand", sand, (0.95, 0.75, 0.4))]


def build_holo_clock(coll):
    ring, hands, core = bmesh.new(), bmesh.new(), bmesh.new()
    standing = Matrix.Rotation(math.pi / 2, 4, "X")
    center = Vector((0, 0, 4.3))
    torus(ring, Matrix.Translation(center) @ standing, 3.6, 0.22, seg=48, tseg=8)
    torus(ring, Matrix.Translation(center) @ standing, 3.0, 0.08, seg=40, tseg=5)
    for k in range(12):
        a = 2 * math.pi * k / 12
        p = center + Vector((math.cos(a) * 3.3, 0, math.sin(a) * 3.3))
        box(ring, p, (0.14, 0.12, 0.5 if k % 3 == 0 else 0.28), rotation=(0, -a + math.pi / 2, 0))
    box(hands, center + Vector((0.0, -0.05, 1.05)), (0.18, 0.1, 2.1))
    box(hands, center + Vector((0.95, -0.05, -0.55)), (0.22, 0.1, 2.2), rotation=(0, math.radians(120), 0))
    for a0 in (0.3, math.pi + 0.3):
        sweep(hands, arc(Matrix.Translation(center) @ standing, 4.3, a0, a0 + 2.1, 16), 0.1, segments=5)
    cyl(core, center + Vector((0, 0.06, 0)), 0.38, 0.24, 16, direction=(0, -1, 0))
    return [closed(coll, "HoloClockRing", ring, CYAN), closed(coll, "HoloClockHands", hands, (1.0, 0.45, 0.9)),
            closed(coll, "HoloClockCore", core, (1.0, 1.0, 1.0))]


SPIRE = [(0, 0), (2.6, 0), (2.4, 1.0), (1.6, 2.0), (1.5, 12.0), (1.0, 15.0), (0.5, 17.5), (0.1, 19.0), (0, 19.2)]


def build_future_spire(coll):
    body, glow = bmesh.new(), bmesh.new()
    lathe(body, SPIRE, 8, Matrix.Rotation(math.pi / 8, 4, "Z"))
    for z in (3.0, 6.0, 9.0, 12.0, 15.6):
        band(glow, SPIRE[3:8], z, z + 0.3, out=0.08, depth=0.2, segments=8, matrix=Matrix.Rotation(math.pi / 8, 4, "Z"))
    torus(glow, M((0, 0, 10.0), (0.18, 0, 0)), 3.5, 0.22, seg=40, tseg=8)
    for k in range(3):
        rot = Matrix.Rotation(2 * math.pi * k / 3, 3, "Z")
        outline = [(1.4, 0.0), (3.5, 0.0), (3.2, 0.8), (1.5, 7.5)]
        front = [body.verts.new(rot @ Vector((x, -0.14, z))) for x, z in outline]
        back = [body.verts.new(rot @ Vector((x, 0.14, z))) for x, z in outline]
        body.faces.new(tuple(front))
        body.faces.new(tuple(reversed(back)))
        for i in range(4):
            j = (i + 1) % 4
            body.faces.new((front[j], front[i], back[i], back[j]))
    return [closed(coll, "FutureSpireBody", body, (0.88, 0.9, 0.95), hard=True), closed(coll, "FutureSpireGlow", glow, CYAN)]


BUILDERS = [
    ("Cycad", build_cycad), ("DinoNest", build_dino_nest), ("Fossil", build_fossil), ("Brontosaurus", build_brontosaurus),
    ("StoneHut", build_stone_hut), ("TuskArch", build_tusk_arch), ("Campfire", build_campfire), ("Megalith", build_megalith),
    ("Obelisk", build_obelisk), ("Sphinx", build_sphinx), ("ScarabPillar", build_scarab_pillar), ("Pyramid", build_pyramid),
    ("GreekColumn", build_greek_column), ("Amphora", build_amphora), ("HeroStatue", build_hero_statue), ("Temple", build_temple),
    ("Longship", build_longship), ("RuneStone", build_rune_stone), ("ShieldRack", build_shield_rack),
    ("Torii", build_torii), ("StoneLantern", build_stone_lantern), ("CherryTree", build_cherry_tree), ("Pagoda", build_pagoda),
    ("Banner", build_banner), ("Catapult", build_catapult), ("ArmorStand", build_armor_stand), ("Castle", build_castle),
    ("WaterTower", build_water_tower), ("Wagon", build_wagon), ("Barrels", build_barrels),
    ("GearTower", build_gear_tower), ("PipeWorks", build_pipe_works), ("Smokestack", build_smokestack),
    ("TimeRing", build_time_ring), ("Hourglass", build_hourglass), ("HoloClock", build_holo_clock), ("FutureSpire", build_future_spire),
]


def build_and_export(only=None, export=True):
    coll = fresh_collection(COLLECTION)
    layer = bpy.context.view_layer.layer_collection.children.get(COLLECTION)
    if layer:
        layer.exclude = False
    objects, manifest = [], {}
    for index, (prop, builder) in enumerate(BUILDERS):
        if only and prop not in only:
            continue
        group = builder(coll)
        slot = index if not only else list(only).index(prop)
        for obj in group:
            obj.location.x += (slot % 6) * 26.0
            obj.location.y += (slot // 6) * 30.0
            objects.append(obj)
        manifest[prop] = [o.name for o in group]
    for obj in objects:
        if max(obj.dimensions) > 20.3:
            print("TOO BIG:", obj.name, tuple(round(d, 2) for d in obj.dimensions))
    print("triangles:", sum(triangles(o) for o in objects), {o.name: triangles(o) for o in objects if triangles(o) > 6000})
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


build_and_export(globals().get("ONLY"))
