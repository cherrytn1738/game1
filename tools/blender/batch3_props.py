# Batch 3 runway props: every remaining theme, plus three large backdrop pieces.
#   Frost Pass: Pine, Snowman, Ice          Crystal Ridge: Crystal, Geode
#   Golden Dunes: Cactus, Mesa, Dune         Ember Canyon: Spire, LavaRock
#   Neon Circuit: Beacon, Arch               Skyway: Cloud, Rainbow, Island
#   Starlight Finish: Planet, Star, Moon     Backdrops: Mountain, Volcano, Hill
# Run inside Blender (e.g. via MCP). One mesh per color; mesh names start with the prop
# name for grouping after import. Every model stays under ~20 units so Roblox's 100x FBX
# import stays below its 2048-stud part limit; large backdrops are scaled up in RunwayDecor.
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, noise

HELPERS = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\prop_helpers.py"
exec(open(HELPERS, encoding="utf-8").read())

COLLECTION = "RunwayBatch3"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayBatch3.fbx"

WHITE = (0.97, 0.97, 0.98)
SNOW = (0.95, 0.97, 1.0)
DARK = (0.12, 0.12, 0.15)


def closed(coll, name, bm, rgb):
    """make_object for meshes made only of closed pieces, with consistent outward normals."""
    recalc_normals(bm)
    return make_object(coll, name, bm, rgb)


# ---------- Frost Pass ----------

def build_pine(coll):
    trunk, needles = bmesh.new(), bmesh.new()
    sweep(trunk, [Vector((0, 0, z)) for z in (0, 2.5, 5)], 0.75, segments=10, radius_end=0.5)
    # (base z, radius, height) for each tier, widest at the bottom.
    tiers = [(2.0, 5.6, 5.2), (5.2, 4.6, 4.4), (8.0, 3.7, 3.7), (10.4, 2.8, 3.2), (12.4, 1.8, 2.8)]
    for index, (z0, r, h) in enumerate(tiers):
        start = len(needles.verts)
        lathe(needles, [(0, z0 + h), (r * 0.25, z0 + h * 0.78), (r * 0.6, z0 + h * 0.42), (r * 0.92, z0 + h * 0.1),
                        (r, z0 - 0.15), (r * 0.65, z0 + 0.25), (0, z0 + 0.5)], 30)
        needles.verts.ensure_lookup_table()
        # Scalloped, drooping branch tips around each tier's rim.
        for v in needles.verts[start:]:
            if v.co.z < z0 + h * 0.45 and (v.co.x or v.co.y):
                wave = math.cos(9 * math.atan2(v.co.y, v.co.x) + index * 1.3)
                v.co.x *= 1 + 0.13 * wave
                v.co.y *= 1 + 0.13 * wave
                if v.co.z < z0 + 0.1:
                    v.co.z -= 0.35 * max(0.0, wave)
    trunk_obj = closed(coll, "PineTrunk", trunk, (0.4, 0.26, 0.17))
    needles_obj = closed(coll, "PineNeedles", needles, (0.13, 0.4, 0.33))
    snow = lit_shell(coll, needles_obj, "PineSnow", SNOW, sun=Vector((0, 0, 1)), threshold=0.5,
                     wobble_scale=0.6, wobble=0.2, lift=0.06, min_island=6)
    return [trunk_obj, needles_obj, snow]


def build_snowman(coll):
    body, coal, nose, arms, hat, scarf = (bmesh.new() for _ in range(6))
    for center, r, seed in (((0, 0, 3.1), 3.3, 1), ((0, 0, 8.0), 2.45, 2), ((0, 0, 11.8), 1.8, 3)):
        blob(body, Vector(center), Vector((r, r, r * 0.96)), subdivisions=4, lump=0.03, seed=seed, floor=0.0)
    head = Vector((0, 0, 11.8))
    # The snowman faces -Y.
    for x in (-0.62, 0.62):
        blob(coal, head + Vector((x, -1.62, 0.4)), Vector((0.24, 0.16, 0.24)), subdivisions=2)
    for i in range(5):
        a = math.radians(-50 + i * 25)
        blob(coal, head + Vector((math.sin(a) * 0.9, -1.6 + abs(math.sin(a)) * 0.25, -0.55 - math.cos(a) * 0.25)),
             Vector((0.13, 0.1, 0.13)), subdivisions=2)
    for z in (7.2, 8.2, 9.2):
        blob(coal, Vector((0, -2.42 + abs(z - 8.2) * 0.15, z)), Vector((0.26, 0.16, 0.26)), subdivisions=2)
    lathe(nose, [(0, 0), (0.34, 0), (0.18, 0.9), (0.04, 1.75), (0, 1.8)], 12,
          Matrix.Translation(head + Vector((0, -1.55, 0.05))) @ align_z(Vector((0, -1, 0.05))))
    for side in (-1, 1):
        shoulder = Vector((side * 2.1, 0, 8.9))
        elbow = shoulder + Vector((side * 1.6, 0, 1.0))
        hand = elbow + Vector((side * 1.4, 0, 1.3))
        sweep(arms, [shoulder, elbow, hand], 0.2, segments=6, radius_end=0.12)
        sweep(arms, [elbow + (hand - elbow) * 0.5, elbow + (hand - elbow) * 0.5 + Vector((side * 0.6, 0, -0.5))], 0.1, segments=5, radius_end=0.06)
        sweep(arms, [hand, hand + Vector((side * 0.5, 0, 0.6))], 0.09, segments=5, radius_end=0.05)
    lathe(hat, [(0, 13.3), (2.15, 13.3), (2.15, 13.55), (1.3, 13.55), (1.22, 15.6), (0, 15.7)], 24)
    lathe(scarf, [(1.33, 13.62), (1.36, 13.62), (1.3, 14.15), (1.27, 14.15)], 24)
    neck = [Vector((math.cos(a) * 1.75, math.sin(a) * 1.75, 10.15)) for a in [i / 24 * 2 * math.pi for i in range(25)]]
    sweep(scarf, neck, 0.42, segments=8)
    sweep(scarf, [Vector((0.7, -1.7, 10.0)), Vector((1.0, -2.3, 9.0)), Vector((1.2, -2.5, 7.8))], 0.38, segments=8, radius_end=0.3)
    return [closed(coll, "SnowmanBody", body, SNOW), closed(coll, "SnowmanCoal", coal, DARK),
            closed(coll, "SnowmanNose", nose, (1.0, 0.5, 0.15)), closed(coll, "SnowmanArms", arms, (0.35, 0.22, 0.12)),
            closed(coll, "SnowmanHat", hat, (0.15, 0.15, 0.2)), closed(coll, "SnowmanScarf", scarf, (0.85, 0.15, 0.2))]


def crystal_cluster(bm, rng, count, spread, length_range, radius_range, center=Vector((0, 0, 0))):
    for i in range(count):
        angle = i / count * 2 * math.pi + rng.uniform(-0.3, 0.3)
        tilt = 0.15 if i == 0 else rng.uniform(0.25, 0.6)
        direction = Vector((math.cos(angle) * tilt, math.sin(angle) * tilt, 1))
        offset = 0 if i == 0 else rng.uniform(0.3, 1.0) * spread
        base = center + Vector((math.cos(angle) * offset, math.sin(angle) * offset, -0.4))
        length = rng.uniform(*length_range) * (1.35 if i == 0 else 1)
        hex_crystal(bm, base, direction, length, rng.uniform(*radius_range))


def build_ice(coll):
    rng = random.Random(4)
    crystals, snow = bmesh.new(), bmesh.new()
    crystal_cluster(crystals, rng, 6, 2.6, (5, 9), (0.7, 1.15))
    blob(snow, Vector((0, 0, 0)), Vector((5.0, 4.2, 1.5)), subdivisions=4, lump=0.25, seed=2, floor=0.0)
    ice = closed(coll, "IceCrystals", crystals, (0.65, 0.88, 1.0))
    smooth_by_angle(ice, 30)
    return [ice, closed(coll, "IceSnow", snow, SNOW)]


# ---------- Crystal Ridge ----------

def build_crystal(coll):
    rng = random.Random(9)
    rock, gems_a, gems_b = bmesh.new(), bmesh.new(), bmesh.new()
    rough_rock(rock, (0, 0, 0.6), (3.4, 2.8, 1.6), rng)
    rough_rock(rock, (2.8, -1.4, 0.4), (1.6, 1.4, 1.0), rng)
    for i in range(8):
        target = gems_a if i % 2 == 0 else gems_b
        angle = i / 8 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        tilt = 0.12 if i == 0 else rng.uniform(0.2, 0.55)
        offset = 0 if i == 0 else rng.uniform(0.6, 2.4)
        base = Vector((math.cos(angle) * offset, math.sin(angle) * offset, 0.8))
        hex_crystal(target, base, Vector((math.cos(angle) * tilt, math.sin(angle) * tilt, 1)),
                    rng.uniform(5, 9) * (1.5 if i == 0 else 1), rng.uniform(0.8, 1.3))
    rock_obj = closed(coll, "CrystalRock", rock, (0.3, 0.27, 0.35))
    bevel(rock_obj, 0.15)
    smooth_by_angle(rock_obj, 35)
    objects = [rock_obj, closed(coll, "CrystalGemsA", gems_a, (0.65, 0.45, 0.95)), closed(coll, "CrystalGemsB", gems_b, (0.88, 0.7, 1.0))]
    for obj in objects[1:]:
        smooth_by_angle(obj, 30)
    return objects


def build_geode(coll):
    rng = random.Random(12)
    shell, gems = bmesh.new(), bmesh.new()
    for side in (-1, 1):
        start_shell, start_gems = len(shell.verts), len(gems.verts)
        sphere = bmesh.ops.create_icosphere(shell, subdivisions=3, radius=1.0)
        created = set(sphere["verts"])
        for v in created:
            v.co = Vector((v.co.x * 3.0, v.co.y * 3.0, v.co.z * 2.8)) * (1 + rng.uniform(-0.06, 0.06))
        # Keep one half, then give it thickness so the open face shows a solid rim.
        faces = {f for v in created for f in v.link_faces}
        bmesh.ops.delete(shell, geom=[f for f in faces if f.calc_center_median().y * side < 0.05], context="FACES")
        remaining = [f for f in {f for v in created if v.is_valid for f in v.link_faces}]
        bmesh.ops.solidify(shell, geom=remaining, thickness=0.55)
        # Crystals lining the inside, pointing toward the middle.
        for _ in range(26):
            d = Vector((rng.uniform(-1, 1), side * rng.uniform(0.25, 1), rng.uniform(-0.6, 1))).normalized()
            base = Vector((d.x * 2.35, d.y * 2.35, d.z * 2.2))
            hex_crystal(gems, base, -d + Vector((0, 0, 0.2)), rng.uniform(0.7, 1.4), rng.uniform(0.18, 0.32))
        # Swing each half open around its bottom edge and sit it on the ground.
        opener = Matrix.Translation((0, side * 2.6, 2.6)) @ Matrix.Rotation(-side * math.radians(55), 4, "X")
        transform_new(shell, start_shell, opener)
        transform_new(gems, start_gems, opener)
    for v in shell.verts:
        v.co.z = max(v.co.z, 0.0)
    shell_obj = closed(coll, "GeodeShell", shell, (0.35, 0.3, 0.33))
    gems_obj = closed(coll, "GeodeCrystals", gems, (0.75, 0.45, 1.0))
    smooth_by_angle(gems_obj, 30)
    return [shell_obj, gems_obj]


# ---------- Golden Dunes ----------

def ribbed_sweep(bm, points, radius, radius_end=None, ribs=10, depth=0.12, segments=30):
    """A tube with lengthwise ribs, like a saguaro cactus."""
    frames = sweep_frames(points)
    radius_end = radius if radius_end is None else radius_end
    rings = []
    for i, (p, (t, n, b)) in enumerate(zip(points, frames)):
        r = radius + (radius_end - radius) * i / (len(points) - 1)
        ring = []
        for k in range(segments):
            a = 2 * math.pi * k / segments
            rr = r * (1 + depth * math.cos(ribs * a))
            ring.append(bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * rr))
        rings.append(ring)
    for a_ring, b_ring in zip(rings, rings[1:]):
        for k in range(segments):
            j = (k + 1) % segments
            bm.faces.new((a_ring[k], a_ring[j], b_ring[j], b_ring[k]))
    bm.faces.new(tuple(reversed(rings[0])))
    return rings[-1]


def build_cactus(coll):
    body, flower, sand = bmesh.new(), bmesh.new(), bmesh.new()
    trunk = [Vector((0, 0, z)) for z in [i * 0.8 for i in range(17)]]
    ribbed_sweep(body, trunk, 1.55, 1.45)
    blob(body, trunk[-1], Vector((1.45, 1.45, 1.25)), subdivisions=3)
    arms = [
        [Vector((1.0, 0, 5.6)), Vector((2.2, 0, 5.7)), Vector((3.1, 0, 6.3)), Vector((3.5, 0, 7.4)), Vector((3.6, 0, 9.0)), Vector((3.6, 0, 10.4))],
        [Vector((-1.0, 0.2, 7.6)), Vector((-2.0, 0.3, 7.7)), Vector((-2.8, 0.4, 8.4)), Vector((-3.0, 0.4, 9.8)), Vector((-3.0, 0.4, 11.2))],
    ]
    for path in arms:
        ribbed_sweep(body, path, 0.95, 0.85, ribs=8)
        blob(body, path[-1], Vector((0.85, 0.85, 0.75)), subdivisions=3)
    for tip in (trunk[-1] + Vector((0, 0, 1.2)), arms[0][-1] + Vector((0, 0, 0.75)), arms[1][-1] + Vector((0, 0, 0.7))):
        for p in range(5):
            a = p / 5 * 2 * math.pi
            blob(flower, tip + Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.1)), Vector((0.45, 0.45, 0.25)), subdivisions=2)
    blob(sand, Vector((0, 0, 0)), Vector((4.2, 3.6, 0.9)), subdivisions=4, lump=0.2, seed=6, floor=0.0)
    return [closed(coll, "CactusBody", body, (0.3, 0.62, 0.36)), closed(coll, "CactusFlower", flower, (1.0, 0.45, 0.7)),
            closed(coll, "CactusSand", sand, (0.93, 0.78, 0.5))]


def build_mesa(coll):
    rng = random.Random(15)
    a, b = bmesh.new(), bmesh.new()
    z = 0.0
    for layer in range(4):
        r = 6.2 - layer * 0.95
        h = 2.3 if layer < 3 else 1.6
        target = a if layer % 2 == 0 else b
        start = len(target.verts)
        lathe(target, [(0, z), (r, z), (r * 0.93, z + h), (0, z + h)], 9)
        target.verts.ensure_lookup_table()
        for v in target.verts[start:]:
            if v.co.x or v.co.y:
                s = 1 + rng.uniform(-0.12, 0.12)
                v.co.x *= s
                v.co.y *= s
        z += h
    for _ in range(4):
        angle = rng.uniform(0, 2 * math.pi)
        rough_rock(a, (math.cos(angle) * 6.8, math.sin(angle) * 6.0, 0.4), (0.9, 0.8, 0.7), rng, subdivisions=1)
    objects = [closed(coll, "MesaRockA", a, (0.85, 0.5, 0.3)), closed(coll, "MesaRockB", b, (0.95, 0.68, 0.42))]
    for obj in objects:
        bevel(obj, 0.15)
        smooth_by_angle(obj, 35)
    return objects


def build_dune(coll):
    rng = random.Random(21)
    mounds, rocks = bmesh.new(), bmesh.new()
    # Elongated, slightly rotated sand mounds fused into one dune field.
    for center, size, angle in (((0, 0, 0), (7.5, 3.6, 3.4), 0.25), ((4.2, -3.2, 0), (5.0, 2.8, 2.3), -0.2),
                                ((-5.0, 3.0, 0), (4.0, 2.2, 1.7), 0.4)):
        blob(mounds, Vector(center), Vector(size), subdivisions=3, rotation=Matrix.Rotation(angle, 3, "Z"))
    sand = fused_surface(coll, "DuneSand", mounds, voxel=0.15, lump_scale=0.6, lump_strength=0.2, rgb=(0.95, 0.8, 0.52), floor=0.0)
    # Fine wind ripples across the upper slopes.
    for v in sand.data.vertices:
        if v.co.z > 0.3:
            v.co.z += 0.07 * math.sin(v.co.x * 2.6 + v.co.y * 0.9) * min(1.0, v.co.z / 1.5)
    decimate(sand, 0.08)
    for center, size in (((-6.5, -2.5, 0.3), (1.0, 0.8, 0.6)), ((7.5, 1.5, 0.3), (0.7, 0.6, 0.5)), ((1.0, 4.2, 0.2), (0.6, 0.5, 0.4))):
        rough_rock(rocks, center, size, rng)
    rocks_obj = closed(coll, "DuneRock", rocks, (0.7, 0.5, 0.35))
    bevel(rocks_obj, 0.1)
    smooth_by_angle(rocks_obj, 35)
    return [sand, rocks_obj]


# ---------- Ember Canyon ----------

def build_spire(coll):
    rng = random.Random(27)
    rock, glow = bmesh.new(), bmesh.new()
    columns = [(0, 0, 13.0, 1.3), (2.1, 0.6, 9.0, 1.1), (-1.9, 0.9, 10.5, 1.15), (0.6, -2.0, 7.0, 1.0),
               (-1.0, -1.7, 5.0, 0.95), (2.4, -1.6, 4.0, 0.9), (-3.0, -0.6, 3.0, 0.85)]
    for x, y, h, r in columns:
        start = len(rock.verts)
        lathe(rock, [(0, 0), (r, 0), (r, h), (r * 0.82, h + 0.3), (0, h + 0.35)], 6)
        transform_new(rock, start, Matrix.Translation((x, y, 0)) @ Matrix.Rotation(rng.uniform(-0.06, 0.06), 4, "X")
                      @ Matrix.Rotation(rng.uniform(0, 1), 4, "Z"))
    # A glowing lava pool at the base and molten seams running up between columns.
    lathe(glow, [(0, 0.04), (4.6, 0.04), (4.8, 0.0), (0, 0.0)], 28, wobble=0.5, seed=3)
    for x, y, h in ((1.1, 0.35, 8.0), (-1.0, 0.5, 9.0), (0.3, -1.1, 6.0), (-1.5, -1.2, 4.0)):
        prism(glow, [(x - 0.12, y - 0.12), (x + 0.12, y - 0.12), (x + 0.12, y + 0.12), (x - 0.12, y + 0.12)], 0.0, h)
    rock_obj = closed(coll, "SpireRock", rock, (0.2, 0.16, 0.17))
    bevel(rock_obj, 0.12)
    smooth_by_angle(rock_obj, 35)
    return [rock_obj, closed(coll, "SpireGlow", glow, (1.0, 0.5, 0.1))]


def build_lava_rock(coll):
    rng = random.Random(33)
    stone_bm, glow = bmesh.new(), bmesh.new()
    rough_rock(stone_bm, (0, 0, 1.4), (3.2, 2.6, 2.4), rng)
    rough_rock(stone_bm, (3.4, 1.2, 0.8), (1.6, 1.4, 1.3), rng)
    stone = closed(coll, "LavaRockStone", stone_bm, (0.18, 0.15, 0.16))
    bevel(stone, 0.15)
    smooth_by_angle(stone, 35)
    # Glowing cracks traced over the rock: project zigzag lines down onto its surface.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for _ in range(5):
        x, y = rng.uniform(-2.0, 2.0), rng.uniform(-1.6, 1.6)
        points = []
        for step in range(6):
            hit, location, normal, _ = stone.ray_cast(Vector((x, y, 10)), Vector((0, 0, -1)), depsgraph=depsgraph)
            if hit:
                points.append(location + normal * 0.05)
            x += rng.uniform(0.3, 0.7) * (1 if step % 2 == 0 else 0.6)
            y += rng.uniform(-0.6, 0.6)
        if len(points) >= 3:
            sweep(glow, points, 0.14, segments=5, radius_end=0.05)
    lathe(glow, [(0, 0.03), (5.4, 0.03), (5.6, 0.0), (0, 0.0)], 30, wobble=0.6, seed=8)
    return [stone, closed(coll, "LavaRockGlow", glow, (1.0, 0.45, 0.08))]


# ---------- Neon Circuit ----------

def build_beacon(coll):
    body, glow = bmesh.new(), bmesh.new()
    lathe(body, [(0, 0), (3.0, 0), (3.0, 0.8), (2.3, 1.3), (0, 1.3)], 6)
    lathe(body, [(0, 1.3), (1.6, 1.3), (1.05, 13.5), (0, 14.0)], 6)
    for z in (4.0, 7.2, 10.2):
        r = 1.6 + (1.05 - 1.6) * (z - 1.3) / 12.2
        lathe(glow, [(r - 0.05, z - 0.3), (r + 0.28, z - 0.22), (r + 0.28, z + 0.22), (r - 0.05, z + 0.3)], 6)
    # A floating octahedral core above the tip.
    core = Vector((0, 0, 16.6))
    tips = [core + Vector(v) * 1.5 for v in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0))]
    top, bottom = core + Vector((0, 0, 2.0)), core - Vector((0, 0, 2.0))
    verts = [glow.verts.new(p) for p in tips]
    vt, vb = glow.verts.new(top), glow.verts.new(bottom)
    for a, b_ in ((0, 2), (2, 1), (1, 3), (3, 0)):
        glow.faces.new((verts[a], verts[b_], vt))
        glow.faces.new((verts[b_], verts[a], vb))
    body_obj = closed(coll, "BeaconBody", body, (0.12, 0.16, 0.28))
    bevel(body_obj, 0.1)
    smooth_by_angle(body_obj, 35)
    glow_obj = make_object(coll, "BeaconGlow", glow, (0.3, 0.95, 0.95))
    smooth_by_angle(glow_obj, 30)
    return [body_obj, glow_obj]


def build_arch(coll):
    body, glow, base = bmesh.new(), bmesh.new(), bmesh.new()
    path = [Vector((-6, 0, 0)), Vector((-6, 0, 2)), Vector((-6, 0, 4))]
    for i in range(1, 24):
        a = math.pi * i / 24
        path.append(Vector((-6 * math.cos(a), 0, 4 + 6 * math.sin(a))))
    path += [Vector((6, 0, 4)), Vector((6, 0, 2)), Vector((6, 0, 0))]
    # The path lies in the XZ plane, so each frame's normal stays along Y (the arch's faces).
    sweep_profile(body, path, [(-0.6, -0.8), (0.6, -0.8), (0.6, 0.8), (-0.6, 0.8)])
    for u in (0.62, -0.7):
        sweep_profile(glow, path, [(u, -0.22), (u + 0.08, -0.22), (u + 0.08, 0.22), (u, 0.22)])
    for x in (-6, 6):
        prism(base, [(x - 1.5, -1.3), (x + 1.5, -1.3), (x + 1.5, 1.3), (x - 1.5, 1.3)], 0.0, 0.9)
    body_obj = closed(coll, "ArchBody", body, (0.12, 0.16, 0.28))
    base_obj = closed(coll, "ArchBase", base, (0.18, 0.22, 0.36))
    for obj in (body_obj, base_obj):
        bevel(obj, 0.1)
        smooth_by_angle(obj, 35)
    return [body_obj, base_obj, closed(coll, "ArchGlow", glow, (0.3, 0.95, 0.95))]


# ---------- Skyway ----------

def cloud_shape(bm, puffs):
    for center, radius in puffs:
        blob(bm, Vector(center), Vector((radius, radius, radius * 0.85)), subdivisions=3)


def build_cloud(coll):
    bm = bmesh.new()
    cloud_shape(bm, [((0, 0, 2.2), 2.8), ((2.9, 0.3, 1.8), 2.2), ((-2.8, -0.2, 1.7), 2.1), ((1.2, 0.8, 3.6), 2.0),
                     ((-1.3, 0.5, 3.4), 1.9), ((4.9, 0, 1.2), 1.4), ((-4.8, 0.2, 1.1), 1.3)])
    puff = fused_surface(coll, "CloudPuff", bm, voxel=0.16, lump_scale=0.9, lump_strength=0.25, rgb=WHITE)
    shade = lit_shell(coll, puff, "CloudShade", (0.78, 0.86, 1.0), sun=Vector((0, 0, -1)), threshold=0.35,
                      wobble_scale=0.7, wobble=0.25, lift=0.04, min_island=30)
    decimate(puff, 0.18)
    decimate(shade, 0.25)
    return [puff, shade]


def build_rainbow(coll):
    colors = [(0.95, 0.3, 0.35), (1.0, 0.6, 0.2), (1.0, 0.9, 0.3), (0.4, 0.85, 0.45), (0.35, 0.65, 1.0), (0.65, 0.45, 0.95)]
    objects = []
    for index, rgb in enumerate(colors):
        bm = bmesh.new()
        radius = 8.6 - index * 0.85
        path = [Vector((-radius * math.cos(math.pi * i / 36), 0, radius * math.sin(math.pi * i / 36))) for i in range(37)]
        sweep_profile(bm, path, [(-0.45, -0.43), (0.45, -0.43), (0.45, 0.43), (-0.45, 0.43)])
        objects.append(closed(coll, "RainbowBand" + str(index + 1), bm, rgb))
    clouds = bmesh.new()
    for x in (-6.0, 6.0):
        cloud_shape(clouds, [((x, 0, 0.6), 2.2), ((x + 1.6, 0.3, 0.4), 1.5), ((x - 1.6, -0.2, 0.4), 1.5), ((x, 0.2, 1.8), 1.4)])
    cloud = fused_surface(coll, "RainbowCloud", clouds, voxel=0.16, lump_scale=0.9, lump_strength=0.2, rgb=WHITE, floor=0.0)
    decimate(cloud, 0.2)
    return objects + [cloud]


def build_island(coll):
    rock, grass, trunk, leaves = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    lathe(rock, [(0, -8.0), (1.0, -6.4), (2.6, -4.2), (4.2, -2.0), (5.2, -0.4), (5.4, 0.2), (0, 0.4)], 12, wobble=0.5, seed=4)
    lathe(grass, [(0, 1.0), (3.5, 0.95), (5.0, 0.6), (5.7, 0.05), (5.6, -0.35), (0, -0.2)], 28, wobble=0.25, seed=7)
    sweep(trunk, [Vector((1.4, 0.6, 0.5)), Vector((1.6, 0.7, 2.6)), Vector((1.4, 0.5, 4.2))], 0.4, segments=8, radius_end=0.25)
    cloud_shape(leaves, [((1.4, 0.5, 5.4), 1.9), ((2.6, 0.9, 4.8), 1.3), ((0.4, 0.2, 4.9), 1.3), ((1.5, 0.4, 6.6), 1.2)])
    blob(grass, Vector((-2.2, -1.6, 1.0)), Vector((1.2, 1.0, 0.8)), subdivisions=3, lump=0.2, seed=1)
    rock_obj = closed(coll, "IslandRock", rock, (0.55, 0.42, 0.34))
    bevel(rock_obj, 0.15)
    smooth_by_angle(rock_obj, 40)
    leaves_obj = fused_surface(coll, "IslandLeaves", leaves, voxel=0.12, lump_scale=0.6, lump_strength=0.18, rgb=(0.3, 0.7, 0.35))
    decimate(leaves_obj, 0.25)
    return [rock_obj, closed(coll, "IslandGrass", grass, (0.4, 0.78, 0.38)), closed(coll, "IslandTrunk", trunk, (0.45, 0.3, 0.2)), leaves_obj]


# ---------- Starlight Finish ----------

def build_planet(coll):
    body, bands, ring = bmesh.new(), bmesh.new(), bmesh.new()
    blob(body, Vector((0, 0, 0)), Vector((5, 5, 5)), subdivisions=4)
    # Two raised latitude bands.
    for z0, z1 in ((1.0, 2.1), (-2.6, -1.4)):
        profile = []
        for z in (z0, (z0 + z1) / 2, z1):
            profile.append((math.sqrt(max(0.0, 25 - z * z)) + 0.05, z))
        faces = lathe(bands, [(profile[0][0] - 0.06, z0)] + profile + [(profile[-1][0] - 0.06, z1)], 40)
    tilt = Matrix.Rotation(0.42, 4, "X") @ Matrix.Rotation(0.2, 4, "Y")
    lathe(ring, [(6.4, -0.1), (9.6, -0.06), (9.6, 0.06), (6.4, 0.1), (6.4, -0.1)], 64, tilt)
    return [closed(coll, "PlanetBody", body, (0.95, 0.65, 0.4)), make_object(coll, "PlanetBands", bands, (0.85, 0.45, 0.35)),
            make_object(coll, "PlanetRing", ring, (0.98, 0.9, 0.78))]


def build_star(coll):
    bm = bmesh.new()
    outline = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = 3.3 if i % 2 == 0 else 1.4
        outline.append((r * math.cos(a), r * math.sin(a)))
    prism(bm, outline, -0.6, 0.6)
    # Stand the star up so its faces look along Y.
    bmesh.ops.rotate(bm, verts=bm.verts[:], cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(90), 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector((0, 0, 3.3)))
    star = closed(coll, "StarBody", bm, (1.0, 0.85, 0.35))
    bevel(star, 0.45, segments=4)
    return [star]


def build_moon(coll):
    rng = random.Random(41)
    bm = bmesh.new()
    blob(bm, Vector((0, 0, 0)), Vector((4.5, 4.5, 4.5)), subdivisions=5)
    craters = [(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized(), rng.uniform(0.18, 0.4)) for _ in range(9)]
    for v in bm.verts:
        direction = v.co.normalized()
        offset = 0.0
        for center, size in craters:
            angle = direction.angle(center)
            if angle < size * 1.25:
                t = angle / size
                offset += -0.35 * (1 - t * t) if t < 1 else 0.12 * (1 - (t - 1) / 0.25)
        v.co = direction * (4.5 + offset)
    return [closed(coll, "MoonSurface", bm, (0.85, 0.84, 0.92))]


# ---------- Backdrops (authored small; scaled up in RunwayDecor) ----------

def build_mountain(coll):
    bm = bmesh.new()
    for x, y, h, r, seed in ((0, 0, 14.0, 6.4, 1), (4.9, 1.4, 10.0, 5.0, 2), (-4.5, 1.0, 9.0, 4.5, 3)):
        start = len(bm.verts)
        lathe(bm, [(0, 0), (r, 0), (r * 0.7, h * 0.3), (r * 0.4, h * 0.65), (r * 0.12, h * 0.95), (0, h)], 16, wobble=0.9, seed=seed)
        transform_new(bm, start, Matrix.Translation((x, y, 0)))
    rock = fused_surface(coll, "MountainRock", bm, voxel=0.22, lump_scale=1.2, lump_strength=0.7, rgb=(0.45, 0.47, 0.55), floor=0.0)
    decimate(rock, 0.2)
    snow = rock.copy()
    snow.data = rock.data.copy()
    snow.name = snow.data.name = "MountainSnow"
    coll.objects.link(snow)
    sbm = bmesh.new()
    sbm.from_mesh(snow.data)
    sbm.normal_update()
    bmesh.ops.delete(sbm, geom=[f for f in sbm.faces if not (f.normal.z > 0.25 and f.calc_center_median().z
                                + noise.noise(f.calc_center_median() * 0.5) * 1.5 > 7.5)], context="FACES")
    sbm.normal_update()
    for v in sbm.verts:
        v.co += v.normal * 0.06
    sbm.to_mesh(snow.data)
    sbm.free()
    set_material(snow, "MountainSnow", SNOW)
    return [rock, snow]


def build_volcano(coll):
    rock_bm, glow = bmesh.new(), bmesh.new()
    profile = [(0, 0), (10.0, 0), (8.2, 2.2), (5.6, 5.0), (3.4, 7.6), (2.6, 8.4), (2.0, 7.8), (0, 7.4)]
    lathe(rock_bm, profile, 36, wobble=0.45, seed=2)
    rock = closed(coll, "VolcanoRock", rock_bm, (0.25, 0.2, 0.22))
    lathe(glow, [(0, 7.55), (2.05, 7.65), (2.1, 7.5), (0, 7.4)], 24)
    # Lava streams flowing down the outer slope.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for angle in (0.4, 2.3, 4.4):
        points = []
        for t in [i / 10 for i in range(11)]:
            radius = 2.7 + t * 6.0
            direction = Vector((math.cos(angle + t * 0.3), math.sin(angle + t * 0.3), 0))
            hit, location, normal, _ = rock.ray_cast(direction * radius + Vector((0, 0, 20)), Vector((0, 0, -1)), depsgraph=depsgraph)
            if hit:
                points.append(location + normal * 0.08)
        if len(points) >= 3:
            sweep(glow, points, 0.35, segments=6, radius_end=0.2)
    return [rock, closed(coll, "VolcanoGlow", glow, (1.0, 0.45, 0.08))]


def build_hill(coll):
    bm = bmesh.new()
    for center, size in (((0, 0, 0), (8.0, 6.4, 4.2)), ((4.8, 1.0, 0), (4.4, 4.0, 3.0)), ((-5.2, -0.5, 0), (4.4, 3.6, 2.6))):
        blob(bm, Vector(center), Vector(size), subdivisions=3)
    grass = fused_surface(coll, "HillGrass", bm, voxel=0.2, lump_scale=0.9, lump_strength=0.35, rgb=(0.3, 0.62, 0.32), floor=0.0)
    top = lit_shell(coll, grass, "HillGrassTop", (0.5, 0.8, 0.38), sun=Vector((0, -0.3, 1)), threshold=0.75,
                    wobble_scale=0.35, wobble=0.25, lift=0.05, min_island=40)
    decimate(grass, 0.15)
    decimate(top, 0.2)
    return [grass, top]


BUILDERS = [("Pine", build_pine), ("Snowman", build_snowman), ("Ice", build_ice), ("Crystal", build_crystal),
            ("Geode", build_geode), ("Cactus", build_cactus), ("Mesa", build_mesa), ("Dune", build_dune),
            ("Spire", build_spire), ("LavaRock", build_lava_rock), ("Beacon", build_beacon), ("Arch", build_arch),
            ("Cloud", build_cloud), ("Rainbow", build_rainbow), ("Island", build_island), ("Planet", build_planet),
            ("Star", build_star), ("Moon", build_moon), ("Mountain", build_mountain), ("Volcano", build_volcano),
            ("Hill", build_hill)]


def build_and_export(only=None):
    coll = fresh_collection(COLLECTION)
    layer = bpy.context.view_layer.layer_collection.children.get(COLLECTION)
    if layer:
        layer.exclude = False
    objects = []
    for index, (prop, builder) in enumerate(BUILDERS):
        if only and prop not in only:
            continue
        group = builder(coll)
        # Lay props out in rows of seven, 26 units apart, so nothing overlaps in Blender.
        for obj in group:
            obj.location.x += (index % 7) * 26.0
            obj.location.y += (index // 7) * 30.0
            objects.append(obj)
    print("triangles:", {o.name: triangles(o) for o in objects})
    biggest = max(max(o.dimensions) for o in objects)
    print("largest dimension:", round(biggest, 2))
    if only:
        return objects
    for other in bpy.context.selected_objects:
        other.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    os.makedirs(os.path.dirname(EXPORT_PATH), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=EXPORT_PATH, use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, add_leaf_bones=False, bake_anim=False)
    print("exported", EXPORT_PATH)
    return objects


build_and_export(globals().get("ONLY"))
