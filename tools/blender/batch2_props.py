# Batch 2 runway props: generic fillers (bush, rock) and the Candy Crossing set
# (lollipop, cake slice, gumdrops, candy cane). Run inside Blender (e.g. via MCP).
# One mesh per color so Roblox can tint each MeshPart; mesh names start with the prop
# name (Bush*, Rock*, Lollipop*, Cake*, Gumdrop*, CandyCane*) for grouping after import.
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, noise

HELPERS = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\prop_helpers.py"
exec(open(HELPERS, encoding="utf-8").read())

COLLECTION = "RunwayBatch2"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayBatch2.fbx"
LAYOUT = {"Bush": -48.0, "Rock": -30.0, "Lollipop": -12.0, "Cake": 6.0, "Gumdrop": 24.0, "CandyCane": 40.0}

PINK = (0.95, 0.35, 0.6)
WHITE = (0.97, 0.96, 0.94)
RED = (0.88, 0.12, 0.2)


def build_bush(coll):
    bm = bmesh.new()
    for center, radius in (((0, 0, 1.8), 2.4), ((1.8, 0.6, 1.5), 1.8), ((-1.7, -0.4, 1.4), 1.7),
                           ((0.4, -1.4, 1.6), 1.6), ((0, 0.4, 3.0), 1.8), ((-0.6, 1.5, 1.3), 1.5)):
        blob(bm, Vector(center), Vector((radius, radius, radius)), subdivisions=3)
    leaves = fused_surface(coll, "BushLeaves", bm, voxel=0.14, lump_scale=0.5, lump_strength=0.3,
                           rgb=(0.2, 0.55, 0.25), floor=0.05)
    top = lit_shell(coll, leaves, "BushLeavesTop", (0.45, 0.78, 0.3), wobble_scale=0.8, lift=0.05, min_island=30)
    decimate(leaves, 0.16)
    decimate(top, 0.2)
    return [leaves, top]


def build_rock(coll):
    bm = bmesh.new()
    rng = random.Random(3)
    # (center, size): a large boulder with two smaller companions. A coarse, jittered
    # icosphere gives big chunky planes; bevelled edges and angle-based shading keep it soft.
    for center, size in (((0, 0, 1.0), (2.6, 2.1, 2.2)), ((2.7, -1.0, 0.6), (1.5, 1.3, 1.4)),
                         ((-2.3, 1.2, 0.45), (1.1, 1.0, 0.9))):
        sphere = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        for v in sphere["verts"]:
            jitter = 1 + rng.uniform(-0.2, 0.2)
            v.co = Vector(center) + Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) * jitter
            v.co.z = max(v.co.z, 0.0)
    stone = make_object(coll, "RockStone", bm, (0.5, 0.48, 0.47))
    bevel(stone, 0.18, segments=2)
    # Keep the broad planes flat while the bevels shade smoothly.
    bpy.context.view_layer.objects.active = stone
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    except AttributeError:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(35))
    # Moss caps on the upward-facing planes.
    moss_bm = bmesh.new()
    moss_bm.from_mesh(stone.data)
    moss_bm.normal_update()
    bmesh.ops.delete(moss_bm, geom=[f for f in moss_bm.faces if f.normal.z + noise.noise(f.calc_center_median() * 0.8) * 0.2 < 0.7], context="FACES")
    moss_bm.normal_update()
    for v in moss_bm.verts:
        v.co += v.normal * 0.05
    moss = make_object(coll, "RockMoss", moss_bm, (0.35, 0.6, 0.28))
    return [stone, moss]


def build_lollipop(coll):
    stick, candy, swirl, bow = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    sweep(stick, [Vector((0, 0, z)) for z in (0, 4, 8, 12, 14.4)], 0.45, segments=12)
    # The disc's axis runs along Y so its faces look along the runway once imported.
    center = Vector((0, 0, 19.2))
    disc_transform = Matrix.Translation(center) @ Matrix.Rotation(math.radians(90), 4, "X")
    disc = lathe(candy, [(0, -0.8), (4.6, -0.8), (5.2, -0.55), (5.4, 0), (5.2, 0.55), (4.6, 0.8), (0, 0.8)], 48, disc_transform)
    orient_outward(disc, center)
    # A raised spiral on both faces of the disc.
    for face in (1, -1):
        inner, outer = [], []
        steps = 90
        for s in range(steps + 1):
            t = s / steps
            angle = t * 3.0 * 2 * math.pi * face
            r = 0.4 + t * 4.3
            half_width = 0.32 + 0.1 * t
            for row, radius in ((inner, r - half_width), (outer, r + half_width)):
                row.append(disc_transform @ Vector((radius * math.cos(angle), radius * math.sin(angle), face * 0.84)))
        iv = [swirl.verts.new(p) for p in inner]
        ov = [swirl.verts.new(p) for p in outer]
        for i in range(steps):
            quad = (iv[i], ov[i], ov[i + 1], iv[i + 1])
            swirl.faces.new(quad)
    orient_faces_by_side(swirl, center)
    # A little ribbon bow where the stick meets the candy.
    knot = Vector((0, 0, 14.0))
    blob(bow, knot, Vector((0.6, 0.55, 0.55)), subdivisions=3)
    for side in (-1, 1):
        blob(bow, knot + Vector((side * 1.15, 0, 0.15)), Vector((1.0, 0.45, 0.65)), subdivisions=3,
             rotation=Matrix.Rotation(side * 0.35, 3, "Y"))
        blob(bow, knot + Vector((side * 0.55, 0, -0.9)), Vector((0.3, 0.2, 0.9)), subdivisions=2,
             rotation=Matrix.Rotation(side * 0.4, 3, "Y"))
    return [make_object(coll, "LollipopStick", stick, WHITE), make_object(coll, "LollipopCandy", candy, PINK),
            make_object(coll, "LollipopSwirl", swirl, WHITE), make_object(coll, "LollipopBow", bow, (0.55, 0.85, 1.0))]


def orient_faces_by_side(bm, center):
    """Swirl faces on each side of the disc point away from its middle plane (Y here)."""
    for f in bm.faces:
        f.normal_update()
        side = 1 if f.calc_center_median().y > center.y else -1
        if f.normal.y * side < 0:
            f.normal_flip()


def build_cake(coll):
    radius, half_angle = 8.0, math.radians(28)
    outline = [(0.0, 0.0)]
    for i in range(11):
        a = -half_angle + 2 * half_angle * i / 10
        outline.append((radius * math.cos(a), radius * math.sin(a)))
    shift = radius * 0.55
    outline = [(x - shift, y) for x, y in outline]
    def grown(points, amount):
        cx = sum(p[0] for p in points) / len(points)
        cy = sum(p[1] for p in points) / len(points)
        return [(cx + (x - cx) * (1 + amount), cy + (y - cy) * (1 + amount)) for x, y in points]
    sponge, cream, frosting, cherry = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    prism(sponge, outline, 0.0, 2.2)
    prism(cream, grown(outline, 0.02), 2.2, 2.8)
    prism(sponge, outline, 2.8, 5.0)
    prism(frosting, grown(outline, 0.04), 5.0, 5.7)
    # Frosting drips hanging over the curved outer edge.
    rng = random.Random(5)
    for i in range(1, 11):
        a = -half_angle + 2 * half_angle * (i - 0.5) / 10
        edge = Vector((radius * 1.02 * math.cos(a) - shift, radius * 1.02 * math.sin(a), 5.2))
        length = rng.uniform(0.7, 1.7)
        blob(frosting, edge - Vector((0, 0, length * 0.45)), Vector((0.42, 0.42, length * 0.6)), subdivisions=2)
    # A frosting swirl topped with a cherry, toward the wide end of the slice where it shows best.
    top = Vector((radius * 0.72 - shift, 0, 5.7))
    dollop = lathe(frosting, [(0, 0), (1.3, 0), (1.25, 0.45), (0.95, 0.75), (1.0, 1.0), (0.6, 1.35), (0.55, 1.55), (0, 1.9)], 20,
                   Matrix.Translation(top), wobble=0.06)
    orient_outward(dollop, top + Vector((0, 0, 0.6)))
    blob(cherry, top + Vector((0, 0, 2.6)), Vector((0.95, 0.95, 0.9)), subdivisions=3)
    sweep(cherry, [top + Vector((0, 0, 3.3)), top + Vector((0.15, 0.1, 4.1)), top + Vector((0.55, 0.2, 4.7))], 0.09, segments=6)
    objects = [make_object(coll, "CakeSponge", sponge, (0.96, 0.78, 0.48)), make_object(coll, "CakeCream", cream, WHITE),
               make_object(coll, "CakeFrosting", frosting, PINK), make_object(coll, "CakeCherry", cherry, RED)]
    for obj in objects[:3]:
        bevel(obj, 0.14)
    return objects


def build_gumdrops(coll):
    profile = [(0, 0), (2.2, 0), (2.32, 0.3), (2.2, 1.0), (1.95, 1.8), (1.5, 2.6), (0.95, 3.2), (0.45, 3.5), (0, 3.6)]
    groups = {"GumdropA": [((0, 0, 0), 1.0, 0.0)], "GumdropB": [((4.4, 1.2, 0), 0.8, 0.4)],
              "GumdropC": [((-3.6, 1.8, 0), 0.7, -0.3)], }
    groups["GumdropA"].append(((1.4, -3.0, 0), 0.55, 0.2))
    colors = {"GumdropA": (0.95, 0.4, 0.62), "GumdropB": (0.45, 0.88, 0.8), "GumdropC": (0.7, 0.55, 0.95)}
    objects = []
    for name, drops in groups.items():
        bm = bmesh.new()
        for position, scale, lean in drops:
            transform = Matrix.Translation(position) @ Matrix.Rotation(lean * 0.3, 4, "Y") @ Matrix.Scale(scale, 4)
            faces = lathe(bm, profile, 32, transform, wobble=0.05, seed=position[0])
            orient_outward(faces, transform @ Vector((0, 0, 1.5)))
        # Fine sugar-crystal bumps over the whole surface.
        for v in bm.verts:
            if v.co.z > 0.05:
                v.co += Vector((noise.noise(v.co * 6.0), noise.noise(v.co * 6.0 + Vector((9, 0, 0))), noise.noise(v.co * 6.0 + Vector((0, 9, 0))))) * 0.05
        objects.append(make_object(coll, name, bm, colors[name]))
    return objects


def build_candy_cane(coll):
    path = [Vector((0, 0, z)) for z in [i * 0.9 for i in range(17)]]  # up to 14.4
    hook_center = Vector((2.6, 0, 14.4))
    for i in range(1, 17):
        a = math.pi * i / 16
        path.append(hook_center + Vector((-2.6 * math.cos(a), 0, 2.6 * math.sin(a))))
    path.append(path[-1] + Vector((0, 0, -0.9)))
    path.append(path[-1] + Vector((0, 0, -0.9)))
    body, stripe = bmesh.new(), bmesh.new()
    radius = 0.95
    frames = sweep(body, path, radius, segments=18)
    blob(body, path[0], Vector((radius, radius, radius)), subdivisions=3)
    blob(body, path[-1], Vector((radius, radius, radius)), subdivisions=3)
    # Three spiral stripes sitting just outside the body surface.
    distance = [0.0]
    for a, b in zip(path, path[1:]):
        distance.append(distance[-1] + (b - a).length)
    for stripe_index in range(3):
        rows = []
        for point, (tangent, normal, binormal), d in zip(path, frames, distance):
            start = d * 0.55 + stripe_index * 2 * math.pi / 3
            row = []
            for k in range(6):
                angle = start + k * math.radians(11)
                row.append(stripe.verts.new(point + (normal * math.cos(angle) + binormal * math.sin(angle)) * radius * 1.04))
            rows.append(row)
        for a, b in zip(rows, rows[1:]):
            for k in range(5):
                face = stripe.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
    for f in stripe.faces:
        f.normal_update()
    # Stripe normals should point away from the cane's centerline.
    flip = 0
    for f in stripe.faces:
        c = f.calc_center_median()
        nearest = min(path, key=lambda p: (p - c).length)
        flip += 1 if f.normal.dot(c - nearest) < 0 else -1
    if flip > 0:
        for f in stripe.faces:
            f.normal_flip()
    return [make_object(coll, "CandyCaneBody", body, WHITE), make_object(coll, "CandyCaneStripe", stripe, RED)]


def build_and_export():
    coll = fresh_collection(COLLECTION)
    layer = bpy.context.view_layer.layer_collection.children.get(COLLECTION)
    if layer:
        layer.exclude = False
    built = {"Bush": build_bush(coll), "Rock": build_rock(coll), "Lollipop": build_lollipop(coll),
             "Cake": build_cake(coll), "Gumdrop": build_gumdrops(coll), "CandyCane": build_candy_cane(coll)}
    objects = []
    for prop, group in built.items():
        for obj in group:
            obj.location.x = LAYOUT[prop]
            objects.append(obj)
    print("triangles:", {o.name: triangles(o) for o in objects})
    for other in bpy.context.selected_objects:
        other.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    os.makedirs(os.path.dirname(EXPORT_PATH), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=EXPORT_PATH, use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, add_leaf_bones=False, bake_anim=False)
    print("exported", EXPORT_PATH)


build_and_export()
