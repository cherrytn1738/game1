# The ten World 4 (Tiny Town) balls, exported together as assets/models/BallsWorld4.fbx.
# Run inside Blender via MCP (one call builds and exports):
#   EXPORT = False   # optional: skip the export while iterating
#   exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\balls_world4.py", encoding="utf-8").read())
# Same conventions as balls_world3.py: every ball is built at radius 1 around its own centre, spaced
# along X, and each mesh is named "<item id>__<Part>". The main body is always the "Shell" part and is
# the 2-unit sphere itself (the game measures the ball's size from it). Surface details stand at most
# ~1.06 R; the dandelion's seed stalks, the blueberry's crown and leaf and the dream orb's moon reach
# up to ~1.3 R. The front is -Y and +Z is up; the display spins each ball about +Z. balls_world3.py's
# helpers (and through it balls_world2.py's, balls.py's and cage_helpers.py's) are reused without
# running their builds. BallStyles (Luau) sets every part's real colour and transparency.
BALLS_WORLD3 = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\balls_world3.py"
_world3_source = open(BALLS_WORLD3, encoding="utf-8").read()
_world3_marker = "# ---------- the ten balls ----------"
assert _world3_marker in _world3_source, "balls_world3.py layout changed; update balls_world4.py"
exec(_world3_source.rpartition(_world3_marker)[0])
import random

COLLECTION = "BallsWorld4"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\BallsWorld4.fbx"


def spiral_points(turns, phase=0.0, count=160, tilt=Matrix()):
    """A loxodrome from pole to pole (unit points), turning `turns` times round the Z axis."""
    points = []
    for i in range(count + 1):
        t = i / count
        z = math.cos(math.pi * (0.04 + 0.92 * t))
        r = math.sqrt(max(0.0, 1 - z * z))
        a = phase + 2 * math.pi * turns * t
        points.append(tilt.to_3x3() @ Vector((math.cos(a) * r, math.sin(a) * r, z)))
    return points


def great_circle(axis, count=96, lift=1.0):
    """Points round the sphere on the great circle whose pole is axis (at radius R * lift)."""
    n = Vector(axis).normalized()
    a = n.orthogonal().normalized()
    b = n.cross(a)
    return [(a * math.cos(2 * math.pi * i / count) + b * math.sin(2 * math.pi * i / count)) * R * lift for i in range(count)]


def noise_patches(bm, threshold, scale, seed, lift, subdivisions=4, skip=lambda n: False):
    """Raised patches of the sphere where a noise field is high (continents, sauce, bloom)."""
    sphere = bmesh.new()
    bmesh.ops.create_icosphere(sphere, subdivisions=subdivisions, radius=1.0)
    doomed = []
    for f in sphere.faces:
        c = f.calc_center_median().normalized()
        value = noise.noise(c * scale + Vector((seed, seed * 0.3, 0))) + 0.35 * noise.noise(c * scale * 2.6)
        if value < threshold or skip(c):
            doomed.append(f)
    bmesh.ops.delete(sphere, geom=doomed, context="FACES")
    bmesh.ops.delete(sphere, geom=[v for v in sphere.verts if not v.link_faces], context="VERTS")
    for v in sphere.verts:
        v.co = v.co.normalized() * R * lift
    bmesh.ops.solidify(sphere, geom=sphere.faces[:], thickness=-0.03)
    mesh = bpy.data.meshes.new("_patches_tmp")
    sphere.to_mesh(mesh)
    sphere.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


def wavy_band(bm, edges, count=96, across=4, base=0.985, top=1.006):
    """A raised band round the Z axis between two wavy edges: edges(a) gives the (low, high)
    heights at angle a. It curves with the ball across its width."""
    rows = []
    for i in range(count):
        a = 2 * math.pi * i / count
        low, high = edges(a)
        heights = [low + (high - low) * j / across for j in range(across + 1)]
        ring = [bm.verts.new(latitude(low, a0=a, a1=a, count=2)[0] * R * base)]
        ring += [bm.verts.new(latitude(h, a0=a, a1=a, count=2)[0] * R * top) for h in heights]
        ring.append(bm.verts.new(latitude(high, a0=a, a1=a, count=2)[0] * R * base))
        rows.append(ring)
    m = len(rows[0])
    for r0, r1 in zip(rows, rows[1:] + rows[:1]):
        for j in range(m):
            k = (j + 1) % m
            bm.faces.new((r0[j], r0[k], r1[k], r1[j]))


def loft(bm, sections):
    """Join equal-length closed point loops into a solid, capped at both ends (as in runway_world2.py)."""
    rings = [[bm.verts.new(p) for p in section] for section in sections]
    n = len(sections[0])
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(tuple(reversed(rings[0])))
    bm.faces.new(tuple(rings[-1]))


# ---------- the ten balls ----------

def dandelion_puff_ball(add):
    """A dandelion clock: a soft seed head bristling with fine stalks, each topped with a feathery
    parachute of little bristles."""
    s, stalks, tufts = (bmesh.new() for _ in range(3))
    shell(s)
    for k, n in enumerate(fibonacci_points(64, seed=0.4)):
        tip = n * R * (1.24 + 0.04 * (k % 3))
        tube(stalks, n * R * 0.98, tip, 0.014, segments=4)
        frame = Matrix.Translation(tip) @ surface_frame(n)
        for j in range(6):
            a = 2 * math.pi * j / 6 + k
            end = frame @ Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.06))
            tube(tufts, tip, end, 0.008, segments=3)
    add("Shell", s, (0.98, 0.97, 0.9))
    add("Stalks", stalks, (0.92, 0.9, 0.82))
    add("Tufts", tufts, (1.0, 1.0, 1.0))


def blueberry_ball(add):
    """A plump blueberry with its five-pointed crown on top, a frosty bloom and a tiny leaf."""
    s, crown, bloom, leaf_bm = (bmesh.new() for _ in range(4))
    shell(s)
    noise_patches(bloom, 0.18, 1.8, 3.0, 1.006, skip=lambda n: n.z > 0.8)
    top = Patch((0, 0, 1), up=(0, 1, 0))
    outline = []
    for i in range(10):
        r = 0.36 if i % 2 == 0 else 0.15
        a = math.pi / 2 + math.pi * i / 5
        outline.append(Vector((math.cos(a) * r, math.sin(a) * r)))
    decal(crown, top, outline, base=0.97, top=1.06, dome=-0.04, rings=2)
    lathe(crown, [(0, R * 1.0), (0.05, R * 1.0), (0.04, R * 1.12), (0, R * 1.13)], 8)
    leaf(leaf_bm, Vector((0.02, 0, R * 1.1)), Vector((1, -0.3, 0.45)), Vector((0, 0, 1)), 0.42, 0.18)
    add("Shell", s, (0.2, 0.25, 0.62))
    add("Bloom", bloom, (0.55, 0.6, 0.85))
    add("Crown", crown, (0.15, 0.15, 0.3))
    add("Leaf", leaf_bm, (0.35, 0.7, 0.3))


def meatball_ball(add):
    """A hearty meatball: a lumpy browned shell, a dollop of tomato sauce over the top and
    flecks of herbs."""
    s, sauce, herbs = (bmesh.new() for _ in range(3))
    shell(s, lump=0.045, seed=2.0)
    noise_patches(sauce, -0.1, 1.4, 7.0, 1.045, subdivisions=4, skip=lambda n: n.z < 0.15 - 0.25 * noise.noise(n * 3.0))
    rng = random.Random(5)
    for n in fibonacci_points(26, seed=1.1):
        patch = Patch(n, spin=rng.uniform(0, 3))
        decal(herbs, patch, ellipse(0, 0, 0.06, 0.03, 8), base=1.0, top=1.07)
    add("Shell", s, (0.48, 0.26, 0.14))
    add("Sauce", sauce, (0.85, 0.15, 0.08))
    add("Herbs", herbs, (0.25, 0.55, 0.15), smooth=False)


def bouncy_ball(add):
    """A swirly rubber bouncy ball: three rainbow stripes spiralling pole to pole."""
    s, red, yellow, blue = (bmesh.new() for _ in range(4))
    shell(s)
    for k, bm in enumerate((red, yellow, blue)):
        ribbon(bm, spiral_points(1.3, phase=2 * math.pi * k / 3), 0.32, base=0.99, top=1.012)
    add("Shell", s, (0.25, 0.85, 0.45))
    add("SwirlRed", red, (1.0, 0.25, 0.3))
    add("SwirlYellow", yellow, (1.0, 0.85, 0.15))
    add("SwirlBlue", blue, (0.2, 0.5, 1.0))


def lucky_dice_ball(add):
    """A rounded die: a white ball with a die face's pips on each of its six sides (opposite faces
    add up to seven), the single pip red."""
    s, pips, one = (bmesh.new() for _ in range(3))
    shell(s)
    layout = {1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)], 4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
              5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)], 6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)]}
    faces = [((0, -1, 0), 1), ((0, 1, 0), 6), ((1, 0, 0), 3), ((-1, 0, 0), 4), ((0, 0, 1), 5), ((0, 0, -1), 2)]
    for normal, count in faces:
        patch = Patch(normal, up=(0, 0, 1) if abs(normal[2]) < 0.5 else (0, 1, 0))
        for px, py in layout[count]:
            radius = 0.2 if count == 1 else 0.11
            target = one if count == 1 else pips
            decal(target, patch, ellipse(px * 0.36, py * 0.36, radius, radius, 18), base=0.99, top=1.014, dome=-0.008, rings=2)
    add("Shell", s, (0.98, 0.97, 0.94))
    add("Pips", pips, (0.08, 0.08, 0.1))
    add("OnePip", one, (0.9, 0.1, 0.12))


def yarn_ball(add):
    """A ball of yarn: two colours of thick strands wound round it in many directions, and a
    loose end trailing off."""
    s, strands, strands2, end = (bmesh.new() for _ in range(4))
    shell(s)
    rng = random.Random(8)
    axes = [Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized() for _ in range(14)]
    for k, axis in enumerate(axes):
        points = great_circle(axis, count=72, lift=1.0 + 0.012 * (k % 3))
        sweep(strands if k % 2 == 0 else strands2, points + points[:1], 0.045, segments=6, caps=False)
    loose = [Vector((0.2, -0.97, 0.1)) * R * 1.02, Vector((0.32, -1.08, -0.05)), Vector((0.48, -1.12, -0.28)), Vector((0.55, -1.08, -0.48))]
    sweep(end, [loose[0].lerp(loose[1], t) if t < 1 else loose[1] for t in (0, 0.5, 1)] + loose[2:], 0.045, segments=6)
    add("Shell", s, (0.85, 0.3, 0.55))
    add("Strands", strands, (0.95, 0.4, 0.65))
    add("Strands2", strands2, (0.75, 0.2, 0.45))
    add("LooseEnd", end, (0.95, 0.4, 0.65))


def bath_bomb_ball(add):
    """A fizzy bath bomb: a pastel ball with a contrasting swirl band, coloured speckles and little
    glossy bubbles fizzing on its surface."""
    s, swirl, speckles, fizz = (bmesh.new() for _ in range(4))
    shell(s)
    wavy_band(swirl, lambda a: (0.05 + 0.18 * math.sin(2 * a), 0.38 + 0.16 * math.sin(2 * a + 1.2)), base=0.99, top=1.008)
    rng = random.Random(3)
    for n in fibonacci_points(40, seed=2.2):
        patch = Patch(n, spin=rng.uniform(0, 3))
        decal(speckles, patch, ellipse(0, 0, 0.045, 0.03, 8), base=0.99, top=1.015)
    for n in list(fibonacci_points(14, seed=0.7)):
        ball(fizz, n * R * 1.0, rng.uniform(0.05, 0.11), subdivisions=2)
    add("Shell", s, (0.75, 0.6, 0.95))
    add("Swirl", swirl, (0.55, 0.9, 0.85))
    add("Speckles", speckles, (1.0, 0.55, 0.7), smooth=False)
    add("Fizz", fizz, (0.9, 0.97, 1.0))


def mini_globe_ball(add):
    """A tiny Earth: blue oceans, raised green continents and white ice caps."""
    s, land, ice = (bmesh.new() for _ in range(3))
    shell(s)
    noise_patches(land, 0.1, 1.6, 11.0, 1.03, skip=lambda n: abs(n.z) > 0.82)
    for sign in (-1, 1):
        cap = Patch((0, 0, sign), up=(0, 1, 0))
        decal(ice, cap, wobbly_outline(0.42, random.Random(4 + sign), count=14), base=0.99, top=1.03)
    add("Shell", s, (0.2, 0.45, 0.9))
    add("Land", land, (0.35, 0.7, 0.3))
    add("IceCaps", ice, (0.96, 0.98, 1.0), smooth=False)


def cats_eye_marble(add):
    """A glass marble with a glowing cat's-eye swirl: three twisted vanes through its middle."""
    s, vanes, core = (bmesh.new() for _ in range(3))
    shell(s)
    for k in range(3):
        base = 2 * math.pi * k / 3
        sections = []
        for i in range(13):
            t = i / 12
            z = -0.88 + 1.76 * t
            a = base + 1.4 * (t - 0.5)
            r = math.sqrt(max(0.0, 0.86 ** 2 - z * z))
            out = Vector((math.cos(a), math.sin(a), 0))
            side = Vector((-out.y, out.x, 0)) * 0.035
            sections.append([Vector((0, 0, z)) + side, out * r + Vector((0, 0, z)) + side, out * r + Vector((0, 0, z)) - side,
                             Vector((0, 0, z)) - side])
        loft(vanes, sections)
    ball(core, (0, 0, 0), 0.12, subdivisions=2)
    add("Shell", s, (0.7, 0.9, 1.0))
    add("Vanes", vanes, (0.2, 0.9, 0.55))
    add("Core", core, (1.0, 0.9, 0.4))
    see_through("cats_eye_marble__Shell", 0.25)


def dream_orb(add):
    """A soft night-light orb: a glowing shell with a crescent moon floating at its side, little
    stars dotted round it and a wisp of cloud."""
    s, moon, stars, cloud = (bmesh.new() for _ in range(4))
    shell(s)
    # The crescent moon stands just off the front-right of the ball, facing the front.
    crescent = []
    for i in range(25):
        a = math.radians(50 + 260 * i / 24)
        crescent.append((0.42 * math.cos(a), 0.42 * math.sin(a)))
    for i in range(25):
        a = math.radians(300 - 260 * i / 24)
        crescent.append((0.16 + 0.33 * math.cos(a), 0.05 + 0.33 * math.sin(a)))
    patch = Patch(Vector((0.55, -0.6, 0.58)).normalized())
    decal(moon, patch, [Vector(p) for p in crescent], base=0.99, top=1.07, rings=2, centre=(-0.27, 0.0))
    rng = random.Random(6)
    for n in fibonacci_points(12, seed=1.7):
        if n.dot(Vector((0.55, -0.6, 0.58)).normalized()) > 0.8:
            continue
        outline = []
        for i in range(10):
            r = 0.1 if i % 2 == 0 else 0.042
            a = math.pi / 2 + math.pi * i / 5
            outline.append(Vector((math.cos(a) * r, math.sin(a) * r)))
        decal(stars, Patch(n, spin=rng.uniform(0, 1)), outline, base=0.99, top=1.03)
    wavy_band(cloud, lambda a: (-0.42 + 0.08 * math.sin(3 * a), -0.22 + 0.1 * math.sin(5 * a + 1)), base=0.99, top=1.02)
    add("Shell", s, (0.45, 0.5, 0.95))
    add("Moon", moon, (1.0, 0.9, 0.55))
    add("Stars", stars, (1.0, 0.95, 0.7), smooth=False)
    add("Cloud", cloud, (0.85, 0.85, 1.0))


BALLS = ["dandelion_puff_ball", "blueberry_ball", "meatball_ball", "bouncy_ball", "lucky_dice_ball",
         "yarn_ball", "bath_bomb_ball", "mini_globe_ball", "cats_eye_marble", "dream_orb"]


def report(objects):
    """Prints each ball's triangles, its Shell's size and how far each part reaches (in R)."""
    for index, item_id in enumerate(BALLS):
        centre = Vector((index * SPACING, 0, 0))
        parts = [o for o in objects if o.name.startswith(item_id + "__")]
        reach = {o.name.split("__")[1]: round(max((o.matrix_world @ v.co - centre).length for v in o.data.vertices) / R, 3)
                 for o in parts}
        size = bpy.data.objects[item_id + "__Shell"].dimensions
        print(item_id, "triangles", sum(triangles(o) for o in parts), "shell %.3f x %.3f x %.3f" % tuple(size), "reach", reach)


def clear_old(collection):
    """Removes the collection's previous objects with their mesh data, so rebuilt meshes keep
    their exact names instead of piling up as .001 copies."""
    coll = bpy.data.collections.get(collection)
    for obj in list(coll.objects) if coll else []:
        mesh = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if mesh is not None and mesh.users == 0:
            bpy.data.meshes.remove(mesh)


# begin() hides every other collection; Blender is shared, so their visibility is put back after
# (even if a builder fails).
_excluded = {layer.name: layer.exclude for layer in bpy.context.view_layer.layer_collection.children}
try:
    clear_old(COLLECTION)
    objects = build(begin(COLLECTION))
    report(objects)
    if globals().get("EXPORT", True):
        export(objects, EXPORT_PATH)
finally:
    for layer in bpy.context.view_layer.layer_collection.children:
        if layer.name != COLLECTION and layer.name in _excluded:
            layer.exclude = _excluded[layer.name]
