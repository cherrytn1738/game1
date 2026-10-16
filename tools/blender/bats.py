# The ten purchasable bats, exported together as assets/models/Bats.fbx.
# Run headless:  blender --background --python tools/blender/bats.py
# Every bat matches the in-game Bat tool: the hand (Tool Handle) is at the origin and the bat
# runs up +Z (Roblox +Y of the Handle): knob -0.52..-0.40, grip -0.40..0.50, barrel 0.50..3.40.
# Bats are spaced along X so they do not overlap in the import. Each mesh is named
# "<item id>__<Part>"; every bat has a "Grip" (used to place the model on the Handle) and a
# "Barrel". After the import the meshes are grouped into one model per item id in
# ServerStorage.RunwayAssets.DisplayItems, and BatStyles (Luau) colours each part by name.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\cage_helpers.py", encoding="utf-8").read())

COLLECTION = "Bats"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\Bats.fbx"
SPACING = 2.0
BAT_TRIANGLES = 20000
SEGMENTS = 24

# The standard barrel profile (radius, z), shared so every bat swings the same way.
BARREL = [(0.09, 0.5), (0.095, 0.9), (0.11, 1.5), (0.135, 2.2), (0.155, 2.8), (0.16, 3.22), (0.152, 3.33),
          (0.11, 3.39), (0.0, 3.41)]
KNOB = [(0.0, -0.52), (0.15, -0.52), (0.156, -0.47), (0.12, -0.42), (0.09, -0.38), (0.0, -0.38)]


def barrel_radius(z):
    """Radius of the standard barrel at height z."""
    for (r0, z0), (r1, z1) in zip(BARREL, BARREL[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / max(z1 - z0, 1e-6)
    return BARREL[0][0] if z < BARREL[0][1] else 0.0


def barrel(bm, profile=None, segments=SEGMENTS, wobble=0.0, seed=0.0):
    lathe(bm, [(0, 0.48)] + (profile or BARREL), segments, wobble=wobble, seed=seed)


def grip(bm, ridges=0, radius=0.09):
    profile = [(0, -0.41), (radius, -0.41)]
    if ridges:
        for k in range(ridges):
            z = -0.4 + 0.9 * (k + 0.5) / ridges
            profile += [(radius + 0.012, z - 0.02), (radius, z + 0.02)]
    profile += [(radius, 0.52), (0, 0.52)]
    lathe(bm, profile, 16)


def knob(bm):
    lathe(bm, KNOB, 20)


def band(bm, z, height=0.08, extra=0.006):
    r0, r1 = barrel_radius(z) + extra, barrel_radius(z + height) + extra
    lathe(bm, [(0, z), (r0, z), (r1, z + height), (0, z + height)], SEGMENTS)


def helix(z0, z1, turns, lift=0.012, phase=0.0, steps=120):
    points = []
    for i in range(steps + 1):
        t = i / steps
        z = z0 + (z1 - z0) * t
        a = phase + 2 * math.pi * turns * t
        r = barrel_radius(z) + lift
        points.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
    return points


def on_barrel(z, angle, lift=0.0):
    """A point on the barrel surface and its outward normal."""
    r = barrel_radius(z) + lift
    normal = Vector((math.cos(angle), math.sin(angle), 0))
    return normal * r + Vector((0, 0, z)), normal


def surface_path(z0, z1, angle, rng, steps=8, wander=0.35):
    """A jagged path running up the barrel surface (cracks, bolts)."""
    points = []
    for i in range(steps + 1):
        z = z0 + (z1 - z0) * i / steps
        angle += rng.uniform(-wander, wander)
        points.append(on_barrel(z, angle, 0.004)[0])
    return points


# ---------- the ten bats ----------

def wood_bat(add):
    b, g, k, logo = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    barrel(b)
    grip(g, ridges=9)
    knob(k)
    band(logo, 2.3, 0.18)
    add("Barrel", b), add("Grip", g), add("Knob", k), add("Logo", logo)


def metal_bat(add):
    b, g, k, cap, stripe = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    barrel(b, BARREL[:-3] + [(0.16, 3.33), (0.0, 3.33)])
    lathe(cap, [(0, 3.32), (0.165, 3.32), (0.162, 3.37), (0.12, 3.41), (0, 3.415)], SEGMENTS)
    grip(g, ridges=12)
    knob(k)
    band(stripe, 1.55, 0.06), band(stripe, 1.7, 0.06)
    add("Barrel", b), add("Grip", g), add("Knob", k), add("EndCap", cap), add("Stripes", stripe)


def jungle_bat(add):
    b, g, k, nodes, vines, leaves = (bmesh.new() for _ in range(6))
    barrel(b, segments=14)
    for z in (0.95, 1.5, 2.05, 2.6, 3.1):
        torus(nodes, (0, 0, z), (0, 0, 1), barrel_radius(z) + 0.004, 0.018, segments=16, minor_segments=5)
    for phase in (0.0, math.pi):
        sweep(vines, helix(0.55, 3.25, 1.6, lift=0.02, phase=phase), 0.022, segments=5)
    for z, angle in ((2.35, 0.4), (2.85, 2.6), (3.2, 4.4), (1.75, 5.5)):
        base, normal = on_barrel(z, angle, 0.01)
        leaf(leaves, base, (normal + Vector((0, 0, 0.9))).normalized(), Vector((0, 0, 1)).cross(normal), 0.42, 0.18)
    grip(g, ridges=14)
    knob(k)
    add("Barrel", b), add("Grip", g), add("Knob", k), add("Nodes", nodes), add("Vines", vines)
    add("Leaves", leaves, smooth=False)


def amethyst_bat(add):
    b, g, k, core, points = (bmesh.new() for _ in range(5))
    barrel(b, segments=7)
    cylinder(core, (0, 0, 0.55), (0, 0, 1), 2.75, 0.05, segments=8)
    rng = random.Random(3)
    for angle in (0.3, 2.4, 4.4):
        base, normal = on_barrel(3.28, angle, -0.04)
        hex_crystal(points, base, (normal + Vector((0, 0, 1.4))).normalized(), rng.uniform(0.22, 0.32), 0.05)
    grip(g, ridges=10)
    knob(k)
    add("Barrel", b, smooth=False), add("Grip", g), add("Knob", k), add("Core", core)
    add("Points", points, smooth=False)


def candy_cane_bat(add):
    b, g, k, stripes, mint = (bmesh.new() for _ in range(5))
    barrel(b)
    for phase in (0.0, math.pi * 2 / 3, math.pi * 4 / 3):
        sweep(stripes, helix(0.55, 3.3, 2.2, lift=0.006, phase=phase), 0.035, segments=6)
    lathe(mint, [(0, -0.58), (0.19, -0.58), (0.2, -0.54), (0.19, -0.5), (0, -0.5)], 20)
    grip(g, ridges=8)
    knob(k)
    add("Barrel", b), add("Grip", g), add("Knob", k), add("Stripes", stripes), add("Peppermint", mint)


def frostbite_bat(add):
    b, g, k, core, icicles = (bmesh.new() for _ in range(5))
    barrel(b, wobble=0.012, seed=2)
    cylinder(core, (0, 0, 0.6), (0, 0, 1), 2.7, 0.045, segments=8)
    rng = random.Random(9)
    for i in range(16):
        z = 0.8 + 2.5 * i / 15
        base, normal = on_barrel(z, rng.uniform(0, 2 * math.pi), -0.02)
        cylinder(icicles, base, (normal * 0.5 + Vector((0, 0, -1))).normalized(), rng.uniform(0.12, 0.24), 0.035,
                 segments=5, radius_top=0.0)
    grip(g, ridges=6)
    knob(k)
    add("Barrel", b), add("Grip", g), add("Knob", k), add("Core", core), add("Icicles", icicles, smooth=False)


def magma_bat(add):
    b, g, k, lava = (bmesh.new() for _ in range(4))
    barrel(b, wobble=0.018, seed=5)
    rng = random.Random(14)
    for i in range(6):
        sweep(lava, surface_path(0.6 + rng.uniform(0, 0.4), 3.3 - rng.uniform(0, 0.5), i * 1.05, rng), 0.018,
              segments=5, radius_end=0.006)
    grip(g, ridges=5)
    knob(k)
    add("Barrel", b), add("Grip", g), add("Knob", k), add("Lava", lava)


def lightning_bat(add):
    b, g, k, bolts, coils = (bmesh.new() for _ in range(5))
    barrel(b)
    rng = random.Random(6)
    for angle in (0.0, math.pi):
        sweep(bolts, surface_path(0.6, 3.3, angle, rng, steps=12, wander=0.5), 0.02, segments=5)
    for z in (1.1, 2.0, 2.9):
        torus(coils, (0, 0, z), (0, 0, 1), barrel_radius(z) + 0.02, 0.025, segments=20, minor_segments=6)
    grip(g, ridges=10)
    knob(k)
    add("Barrel", b), add("Grip", g), add("Knob", k), add("Bolts", bolts), add("Coils", coils)


def dragon_bone_bat(add):
    b, g, k, spikes, eye = (bmesh.new() for _ in range(5))
    barrel(b, wobble=0.015, seed=8)
    for i in range(7):
        z = 1.0 + 2.2 * i / 6
        base, normal = on_barrel(z, 0.0, -0.02)
        cylinder(spikes, base, (normal + Vector((0, 0, 0.6))).normalized(), 0.14 + 0.03 * (i % 2), 0.04,
                 segments=5, radius_top=0.0)
    for angle in (1.6, 3.2, 4.8):
        base, normal = on_barrel(3.3, angle, -0.03)
        cylinder(spikes, base, (normal + Vector((0, 0, 1))).normalized(), 0.16, 0.04, segments=5, radius_top=0.0)
    ball(eye, (0, 0, 3.4), 0.06, subdivisions=2)
    eye.transform(Matrix.Translation((0, 0, 3.4)) @ Matrix.Diagonal((1.0, 0.35, 0.5, 1.0)) @ Matrix.Translation((0, 0, -3.4)))
    grip(g, ridges=12, radius=0.095)
    knob(k)
    add("Barrel", b), add("Grip", g), add("Knob", k), add("Spikes", spikes, smooth=False), add("Eye", eye)


def celestial_bat(add):
    b, g, k, pink, blue, rings, stars, star = (bmesh.new() for _ in range(8))
    barrel(b)
    sweep(pink, helix(0.6, 3.3, 1.3, lift=0.003), 0.03, segments=6)
    sweep(blue, helix(0.6, 3.3, 1.3, lift=0.003, phase=math.pi), 0.024, segments=6)
    for z in (0.95, 3.05):
        torus(rings, (0, 0, z), (0, 0, 1), barrel_radius(z) + 0.012, 0.022, segments=20, minor_segments=6)
    rng = random.Random(4)
    for _ in range(18):
        point, _ = on_barrel(rng.uniform(0.7, 3.25), rng.uniform(0, 2 * math.pi), 0.003)
        ball(stars, point, rng.uniform(0.012, 0.022), subdivisions=1)
    # A four-pointed star hovering beside the tip, as if orbiting it.
    outline = []
    for i in range(8):
        a = math.pi / 4 * i
        r = 0.12 if i % 2 == 0 else 0.04
        outline.append((math.cos(a) * r, math.sin(a) * r))
    prism(star, outline, -0.02, 0.02)
    star.transform(Matrix.Translation((0.36, 0, 3.25)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    grip(g, ridges=10)
    knob(k)
    add("Barrel", b), add("Grip", g), add("Knob", k), add("SwirlPink", pink), add("SwirlBlue", blue)
    add("Rings", rings), add("Stars", stars), add("Star", star, smooth=False)


# Preview colours only (Blender renders); in game BatStyles colours each part.
COLOURS = {
    "wood_bat": {"Barrel": (0.75, 0.55, 0.32), "Grip": (0.08, 0.08, 0.08), "Knob": (0.7, 0.5, 0.3), "Logo": (0.35, 0.22, 0.12)},
    "metal_bat": {"Barrel": (0.78, 0.8, 0.85), "Grip": (0.15, 0.35, 0.85), "Knob": (0.1, 0.1, 0.12), "EndCap": (0.85, 0.15, 0.15), "Stripes": (0.15, 0.35, 0.85)},
    "jungle_bat": {"Barrel": (0.78, 0.7, 0.38), "Grip": (0.45, 0.32, 0.18), "Knob": (0.45, 0.32, 0.18), "Nodes": (0.55, 0.48, 0.22), "Vines": (0.2, 0.5, 0.15), "Leaves": (0.3, 0.7, 0.2)},
    "amethyst_bat": {"Barrel": (0.62, 0.36, 0.92), "Grip": (0.8, 0.82, 0.86), "Knob": (0.8, 0.82, 0.86), "Core": (0.9, 0.7, 1.0), "Points": (0.8, 0.62, 1.0)},
    "candy_cane_bat": {"Barrel": (0.97, 0.97, 0.97), "Grip": (0.85, 0.12, 0.16), "Knob": (0.85, 0.12, 0.16), "Stripes": (0.85, 0.12, 0.16), "Peppermint": (0.97, 0.97, 0.97)},
    "frostbite_bat": {"Barrel": (0.55, 0.82, 1.0), "Grip": (0.9, 0.96, 1.0), "Knob": (0.8, 0.9, 1.0), "Core": (0.9, 0.97, 1.0), "Icicles": (0.85, 0.95, 1.0)},
    "magma_bat": {"Barrel": (0.13, 0.1, 0.1), "Grip": (0.2, 0.15, 0.12), "Knob": (0.13, 0.1, 0.1), "Lava": (1.0, 0.45, 0.08)},
    "lightning_bat": {"Barrel": (0.36, 0.16, 0.62), "Grip": (0.08, 0.08, 0.1), "Knob": (0.08, 0.08, 0.1), "Bolts": (1.0, 0.92, 0.25), "Coils": (0.75, 0.75, 0.8)},
    "dragon_bone_bat": {"Barrel": (0.9, 0.86, 0.74), "Grip": (0.45, 0.08, 0.08), "Knob": (0.85, 0.8, 0.68), "Spikes": (0.15, 0.12, 0.12), "Eye": (1.0, 0.65, 0.1)},
    "celestial_bat": {"Barrel": (0.07, 0.05, 0.2), "Grip": (0.95, 0.75, 0.3), "Knob": (0.95, 0.75, 0.3), "SwirlPink": (1.0, 0.4, 0.8), "SwirlBlue": (0.35, 0.6, 1.0), "Rings": (0.95, 0.75, 0.3), "Stars": (1, 1, 1), "Star": (1.0, 0.85, 0.4)},
}

BATS = ["wood_bat", "metal_bat", "jungle_bat", "amethyst_bat", "candy_cane_bat",
        "frostbite_bat", "magma_bat", "lightning_bat", "dragon_bone_bat", "celestial_bat"]


def build(coll):
    objects = []
    for index, item_id in enumerate(BATS):
        offset = Vector((index * SPACING, 0, 0))

        def add(part, bm, smooth=True):
            bm.transform(Matrix.Translation(offset))
            objects.append(finish(coll, item_id + "__" + part, bm, COLOURS[item_id].get(part, (0.8, 0.8, 0.8)), hard=not smooth))

        globals()[item_id](add)
    return objects


def export(objects, path):
    counts = {o.name: triangles(o) for o in objects}
    worst = max(counts.items(), key=lambda kv: kv[1])
    print("meshes", len(objects), "triangles total", sum(counts.values()), "largest", worst)
    problems = [n for n, c in counts.items() if c > BAT_TRIANGLES]
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
