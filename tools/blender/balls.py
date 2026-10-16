# The ten purchasable balls, exported together as assets/models/Balls.fbx.
# Run headless:  blender --background --python tools/blender/balls.py
# (or inside Blender via MCP). Every ball is built at radius 1 around its own centre, spaced
# along X so they do not overlap in the import. Each mesh is named "<item id>__<Part>"; after
# the import the meshes are grouped into one model per item id in
# ServerStorage.RunwayAssets.DisplayItems, and BallStyles (Luau) colours each part by name.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "Balls"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\Balls.fbx"
R = 1.0
SPACING = 4.0
BALL_TRIANGLES = 20000


# ---------- shared ball pieces ----------

def seam_points(count=120, radius=R * 1.004, phase=0.0):
    """The classic baseball seam: a closed curve lying on the sphere (a + b = 1, c = 2*sqrt(ab))."""
    a, b = 0.75, 0.25
    c = 2 * math.sqrt(a * b)
    points = []
    for i in range(count + 1):
        t = 2 * math.pi * i / count + phase
        p = Vector((a * math.cos(t) + b * math.cos(3 * t), a * math.sin(t) - b * math.sin(3 * t), c * math.sin(2 * t)))
        points.append(p.normalized() * radius)
    return points


def seam(bm, radius=0.03, lift=1.004, count=120):
    sweep(bm, seam_points(count, R * lift), radius, segments=6, caps=False)


def stitches(bm, count=56, width=0.11, radius=0.018, lift=1.012):
    """V-shaped stitches crossing the seam."""
    points = seam_points(count * 2, R * lift)
    for i in range(0, count * 2, 2):
        p, ahead = points[i], points[i + 1]
        normal = p.normalized()
        tangent = (ahead - p).normalized()
        side = tangent.cross(normal).normalized()
        for sign in (-1, 1):
            start = p + side * width * sign - tangent * 0.035
            end = p + tangent * 0.035
            tube(bm, (start.normalized() * R * lift), (end.normalized() * R * lift), radius, segments=4)


def shell(bm, subdivisions=4, lump=0.0, seed=0.0):
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=R)
    if lump:
        for v in bm.verts:
            v.co *= 1 + noise.noise(v.co * 2.2 + Vector((seed, 0, 0))) * lump


def surface_frame(normal):
    """A rotation taking +Z onto the given surface normal."""
    return align_z(Vector(normal).normalized())


def fibonacci_points(count, seed=0.0):
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(count):
        y = 1 - 2 * (i + 0.5) / count
        r = math.sqrt(1 - y * y)
        a = golden * i + seed
        yield Vector((math.cos(a) * r, y, math.sin(a) * r))


def on_surface_blob(bm, normal, size, height, sides=6):
    """A low dome sitting on the sphere (scuffs, sprinkles' base, scales)."""
    lathe(bm, [(0, R + height), (size * 0.6, R + height * 0.8), (size, R - 0.02), (0, R - 0.05)], sides,
          transform=surface_frame(normal))


def capsule_on_surface(bm, normal, direction, length, radius):
    n = Vector(normal).normalized()
    d = (Vector(direction) - n * Vector(direction).dot(n)).normalized()
    centre = n * (R + radius * 0.7)
    tube(bm, centre - d * length / 2, centre + d * length / 2, radius, segments=5)


def spike(bm, normal, length, radius, sides=5, base=R * 0.96):
    n = Vector(normal).normalized()
    cylinder(bm, n * base, n, length, radius, segments=sides, radius_top=0.0)


def crack_path(start, steps, rng, step=0.16, wander=0.5):
    """A jagged path wandering over the sphere surface."""
    p = Vector(start).normalized()
    heading = p.orthogonal().normalized()
    points = [p * R * 1.002]
    for _ in range(steps):
        heading = (heading + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * wander).normalized()
        heading = (heading - p * heading.dot(p)).normalized()
        p = (p + heading * step).normalized()
        points.append(p * R * 1.002)
    return points


def zigzag(points, amplitude, every=3):
    """Offsets alternate points sideways along the surface (lightning bolts)."""
    out = []
    for i, p in enumerate(points):
        if i % every == 0 and 0 < i < len(points) - 1:
            n = p.normalized()
            t = (points[i + 1] - points[i - 1]).normalized()
            side = t.cross(n).normalized() * amplitude * (1 if (i // every) % 2 == 0 else -1)
            out.append((p + side).normalized() * p.length)
        else:
            out.append(p)
    return out


# ---------- the ten balls ----------

def baseball(add):
    s, st = bmesh.new(), bmesh.new()
    shell(s)
    stitches(st)
    add("Shell", s, (0.96, 0.95, 0.92))
    add("Stitches", st, (0.8, 0.1, 0.1))


def practice_ball(add):
    """Sandlot Ball: worn tan leather with faded stitches and scuffs."""
    s, st, sc = bmesh.new(), bmesh.new(), bmesh.new()
    shell(s, lump=0.012, seed=3)
    stitches(st, count=48)
    rng = random.Random(4)
    for n in fibonacci_points(14, seed=1.3):
        n = (n + Vector((rng.uniform(-.3, .3), rng.uniform(-.3, .3), rng.uniform(-.3, .3)))).normalized()
        on_surface_blob(sc, n, rng.uniform(0.12, 0.22), 0.008, sides=7)
    add("Shell", s, (0.82, 0.68, 0.48))
    add("Stitches", st, (0.62, 0.22, 0.18))
    add("Scuffs", sc, (0.55, 0.42, 0.28))


def bubblegum_ball(add):
    """Glossy pink candy shell, icing seam and three colours of sprinkles."""
    s, icing = bmesh.new(), bmesh.new()
    shell(s)
    seam(icing, radius=0.06, lift=1.01)
    sprinkles = [bmesh.new() for _ in range(3)]
    rng = random.Random(8)
    for i, n in enumerate(fibonacci_points(66, seed=0.4)):
        direction = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        capsule_on_surface(sprinkles[i % 3], n, direction, 0.16, 0.028)
    add("Shell", s, (1.0, 0.47, 0.75))
    add("Icing", icing, (1.0, 0.96, 0.98))
    for i, colour in enumerate([(1.0, 0.86, 0.2), (0.35, 0.85, 1.0), (0.6, 1.0, 0.55)]):
        add("Sprinkles" + str(i + 1), sprinkles[i], colour)


def crystal_ball(add):
    """Faceted amethyst around a glowing core, with small crystal points breaking the surface."""
    s, core, points = bmesh.new(), bmesh.new(), bmesh.new()
    bmesh.ops.create_icosphere(s, subdivisions=2, radius=R)
    for v in s.verts:
        v.co *= 1 + noise.noise(v.co * 3.1) * 0.05
    ball(core, (0, 0, 0), R * 0.55, subdivisions=3)
    rng = random.Random(17)
    for n in fibonacci_points(8, seed=1.1):
        hex_crystal(points, n * R * 0.85, n, rng.uniform(0.3, 0.42), 0.09)
    add("Shell", s, (0.62, 0.36, 0.92), smooth=False)
    add("Core", core, (0.85, 0.6, 1.0))
    add("Points", points, (0.8, 0.6, 1.0), smooth=False)


def frost_comet(add):
    """Ice-blue glass with frost shards and a glowing core."""
    s, core, shards, sm = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s, subdivisions=3)
    ball(core, (0, 0, 0), R * 0.6, subdivisions=3)
    rng = random.Random(11)
    for n in fibonacci_points(22, seed=2.1):
        spike(shards, n, rng.uniform(0.12, 0.26), rng.uniform(0.05, 0.08), sides=4)
    seam(sm, radius=0.028, lift=1.01)
    add("Shell", s, (0.55, 0.82, 1.0))
    add("Core", core, (0.9, 0.97, 1.0))
    add("Shards", shards, (0.85, 0.95, 1.0), smooth=False)
    add("Seam", sm, (1.0, 1.0, 1.0))


def inferno_ball(add):
    """Lumpy black rock split by glowing lava cracks."""
    s, lava = bmesh.new(), bmesh.new()
    shell(s, subdivisions=4, lump=0.045, seed=7)
    sweep(lava, seam_points(120, R * 1.01), 0.045, segments=6, caps=False)
    rng = random.Random(21)
    for n in fibonacci_points(9, seed=0.9):
        sweep(lava, crack_path(n, rng.randint(4, 7), rng), 0.03, segments=5, radius_end=0.008)
    add("Shell", s, (0.12, 0.1, 0.1))
    add("Lava", lava, (1.0, 0.45, 0.08))


def thunder_ball(add):
    """Storm purple with crackling lightning stitches."""
    s, bolts = bmesh.new(), bmesh.new()
    shell(s)
    for phase in (0.0, math.pi):
        points = seam_points(96, R * 1.012)
        half = points[:49] if phase == 0 else points[48:]
        sweep(bolts, zigzag(half, 0.07), 0.035, segments=5)
    rng = random.Random(5)
    for n in fibonacci_points(6, seed=1.7):
        sweep(bolts, zigzag(crack_path(n, 4, rng, step=0.18, wander=0.2), 0.05, every=1), 0.022, segments=4, radius_end=0.006)
    add("Shell", s, (0.36, 0.16, 0.62))
    add("Bolts", bolts, (1.0, 0.92, 0.25))


def galaxy_ball(add):
    """Deep-space shell with two nebula swirls and scattered stars."""
    s, pink, blue, stars = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    # Thin swirls half sunk into the shell, so they read as painted nebula clouds.
    for target, turn, width in ((pink, Matrix(), 0.07), (blue, Matrix.Rotation(math.pi / 2, 4, "X"), 0.05)):
        points = [turn @ p for p in seam_points(140, R * 0.995)]
        sweep(target, points, width, segments=8, caps=False)
    rng = random.Random(13)
    for n in fibonacci_points(40, seed=0.2):
        ball(stars, n * R * 1.01, rng.uniform(0.018, 0.04), subdivisions=1)
    add("Shell", s, (0.07, 0.05, 0.2))
    add("NebulaPink", pink, (1.0, 0.4, 0.8))
    add("NebulaBlue", blue, (0.35, 0.6, 1.0))
    add("Stars", stars, (1.0, 1.0, 1.0))


def dragonfire_ball(add):
    """Overlapping dragon scales, a glowing eye-slit seam and a ridge of spines."""
    s, scales, slit, spines = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s, subdivisions=3)
    for n in fibonacci_points(150, seed=0.6):
        # Each scale is a flattened, tilted dome so the rows overlap like armour.
        lathe(scales, [(0, R + 0.06), (0.1, R + 0.05), (0.16, R + 0.005), (0, R - 0.04)], 5,
              transform=surface_frame(n) @ Matrix.Rotation(0.35, 4, "X"))
    sweep(slit, seam_points(120, R * 1.05), 0.05, segments=6, caps=False)
    for k in range(10):
        a = 2 * math.pi * k / 10
        n = Vector((math.cos(a), 0, math.sin(a)))
        spike(spines, n, 0.32 if k % 2 == 0 else 0.22, 0.07, sides=4, base=R * 1.0)
    add("Shell", s, (0.2, 0.04, 0.05))
    add("Scales", scales, (0.5, 0.08, 0.08), smooth=False)
    add("EyeSlit", slit, (1.0, 0.65, 0.1))
    add("Spines", spines, (0.1, 0.08, 0.08), smooth=False)


def supernova_ball(add):
    """A white-gold core with star flares and an orbiting rainbow ring in six colours."""
    core, flares, inner = bmesh.new(), bmesh.new(), bmesh.new()
    ball(core, (0, 0, 0), R, subdivisions=4)
    ball(inner, (0, 0, 0), R * 1.08, subdivisions=3)
    for n in fibonacci_points(12, seed=0.8):
        spike(flares, n, 0.35, 0.09, sides=4, base=R * 0.95)
    add("Core", core, (1.0, 0.95, 0.75))
    add("Halo", inner, (1.0, 0.85, 0.4))
    add("Flares", flares, (1.0, 0.8, 0.3), smooth=False)
    tilt = Matrix.Rotation(math.radians(24), 4, "X")
    colours = [(1, 0.25, 0.3), (1, 0.6, 0.15), (1, 0.95, 0.25), (0.35, 1, 0.45), (0.3, 0.6, 1), (0.7, 0.35, 1)]
    for k, colour in enumerate(colours):
        arc = bmesh.new()
        points = []
        for i in range(13):
            a = 2 * math.pi * (k + i / 12) / 6
            points.append(tilt @ Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, 0)))
        sweep(arc, points, 0.075, segments=8)
        add("Ring" + str(k + 1), arc, colour)


BALLS = ["baseball", "practice_ball", "bubblegum_ball", "crystal_ball", "frost_comet",
         "inferno_ball", "thunder_ball", "galaxy_ball", "dragonfire_ball", "supernova_ball"]


def build(coll):
    objects = []
    for index, item_id in enumerate(BALLS):
        offset = Vector((index * SPACING, 0, 0))

        def add(part, bm, rgb, smooth=True):
            bm.transform(Matrix.Translation(offset))
            obj = finish(coll, item_id + "__" + part, bm, rgb, hard=not smooth)
            objects.append(obj)

        globals()[item_id](add)
    return objects


def export(objects, path):
    counts = {o.name: triangles(o) for o in objects}
    worst = max(counts.items(), key=lambda kv: kv[1])
    print("meshes", len(objects), "triangles total", sum(counts.values()), "largest", worst)
    problems = [n for n, c in counts.items() if c > BALL_TRIANGLES]
    if problems:
        print("PROBLEMS:", problems)
        return
    for other in bpy.context.selected_objects:
        other.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, add_leaf_bones=False, bake_anim=False)
    print("exported", path)


objects = build(begin(COLLECTION))
if globals().get("EXPORT", True):
    export(objects, EXPORT_PATH)
