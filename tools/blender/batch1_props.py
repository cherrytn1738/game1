# Batch 1 runway props (Meadow Run / Emerald Grove): mushroom cluster, flower patch, fern.
# Run inside Blender (e.g. via MCP). Each prop is built from separate meshes, one per
# color, so Roblox can tint each MeshPart per theme. Mesh names start with the prop name
# (Mushroom*, Flower*, Fern*) so they can be grouped into Models after import.
# Units: 1 Blender unit is intended to be 1 stud. Props sit on z = 0 at their own x offset.
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, noise

COLLECTION = "RunwayBatch1"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayBatch1.fbx"
LAYOUT = {"Mushroom": -25.0, "Flower": 0.0, "Fern": 25.0}

PREVIEW_COLORS = {
    "MushroomStem": (0.93, 0.88, 0.78), "MushroomGills": (0.85, 0.72, 0.6),
    "MushroomCap": (0.85, 0.12, 0.15), "MushroomSpots": (0.97, 0.96, 0.93),
    "MushroomGrass": (0.22, 0.6, 0.25),
    "FlowerBush": (0.16, 0.45, 0.2), "FlowerStems": (0.25, 0.6, 0.25),
    "FlowerPetalsA": (0.97, 0.45, 0.65), "FlowerPetalsB": (0.98, 0.95, 0.9),
    "FlowerCenters": (1.0, 0.75, 0.15),
    "FernFronds": (0.18, 0.5, 0.22), "FernFrondsLight": (0.35, 0.68, 0.28),
}


# ---------- generic geometry helpers ----------

def lathe(bm, profile, segments, transform=Matrix(), wobble=0.0, seed=0.0):
    """Revolve (radius, z) points around Z. A zero radius makes a pole."""
    rings = []
    for r, z in profile:
        if r < 1e-4:
            rings.append([bm.verts.new(transform @ Vector((0, 0, z)))])
            continue
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            local = Vector((r * math.cos(a), r * math.sin(a), z))
            if wobble:
                local += local.normalized() * noise.noise(local * 0.6 + Vector((seed, 0, 0))) * wobble
            ring.append(bm.verts.new(transform @ local))
        rings.append(ring)
    faces = []
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(segments):
            j = (i + 1) % segments
            if len(a) == 1:
                faces.append(bm.faces.new((a[0], b[j], b[i])))
            elif len(b) == 1:
                faces.append(bm.faces.new((a[i], a[j], b[0])))
            else:
                faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    return faces


def orient_faces(faces, outward_from=None, want_down=False):
    """Make a revolved surface's normals point away from a point (or downward)."""
    if not faces:
        return
    for f in faces:
        f.normal_update()
    if want_down:
        score = sum(f.normal.z for f in faces)
        flip = score > 0
    else:
        score = sum(f.normal.dot(f.calc_center_median() - outward_from) for f in faces)
        flip = score < 0
    if flip:
        for f in faces:
            f.normal_flip()


def blob(bm, center, size, subdivisions=2, lump=0.0, seed=0.0, rotation=Matrix()):
    sphere = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    for v in sphere["verts"]:
        offset = v.co.copy()
        if lump:
            offset *= 1 + noise.noise(offset * 1.7 + Vector((seed, seed, 0))) * lump
        v.co = center + rotation @ Vector((offset.x * size.x, offset.y * size.y, offset.z * size.z))
    return sphere


def double_sided_strip(bm, left, right):
    """A ribbon between two point rows, built twice with opposite winding so it renders from both sides."""
    for reverse in (False, True):
        lv = [bm.verts.new(p) for p in left]
        rv = [bm.verts.new(p) for p in right]
        for i in range(len(left) - 1):
            quad = (lv[i], rv[i], rv[i + 1], lv[i + 1])
            if lv[i + 1].co == rv[i + 1].co:  # pointed tip
                quad = (lv[i], rv[i], lv[i + 1])
            bm.faces.new(tuple(reversed(quad)) if reverse else quad)


def tube(bm, points, radius_start, radius_end, segments=6):
    """A tapered tube along a polyline (for stems and spines)."""
    rings = []
    for index, point in enumerate(points):
        t = index / (len(points) - 1)
        radius = radius_start + (radius_end - radius_start) * t
        ahead = points[min(index + 1, len(points) - 1)] - points[max(index - 1, 0)]
        ahead.normalize()
        side = ahead.cross(Vector((0, 0, 1)))
        if side.length < 1e-3:
            side = ahead.cross(Vector((1, 0, 0)))
        side.normalize()
        up = side.cross(ahead)
        ring = [bm.verts.new(point + (side * math.cos(2 * math.pi * i / segments) + up * math.sin(2 * math.pi * i / segments)) * radius)
                for i in range(segments)]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(tuple(reversed(rings[0])))
    bm.faces.new(tuple(rings[-1]))


def align_z(normal):
    """Rotation taking +Z onto the given normal."""
    return Vector((0, 0, 1)).rotation_difference(normal.normalized()).to_matrix().to_4x4()


# ---------- scene helpers ----------

def get_collection():
    coll = bpy.data.collections.get(COLLECTION)
    if not coll:
        coll = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(coll)
    for obj in list(coll.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return coll


def finish(coll, name, bm, offset_x):
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location.x = offset_x
    coll.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    rgb = PREVIEW_COLORS[name]
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.6
    mat.diffuse_color = (*rgb, 1)
    mesh.materials.append(mat)
    return obj


# ---------- props ----------

CAP_DOME = [(4.3, 6.0), (4.65, 6.45), (4.6, 7.2), (4.15, 8.15), (3.2, 9.0), (1.8, 9.65), (0.0, 9.9)]
CAP_UNDERSIDE = [(0.0, 6.35), (1.2, 6.25), (2.4, 6.05), (3.5, 5.85), (4.3, 6.0)]
STEM = [(0.0, 0.0), (1.35, 0.0), (1.5, 0.35), (1.3, 1.3), (1.18, 3.0), (1.08, 4.8), (0.98, 6.5), (0.0, 6.5)]


def point_on_profile(profile, t):
    """Point and outward normal at fraction t along a (radius, z) polyline."""
    lengths = [(Vector(b) - Vector(a)).length for a, b in zip(profile, profile[1:])]
    target = t * sum(lengths)
    for (a, b), length in zip(zip(profile, profile[1:]), lengths):
        if target <= length or length == lengths[-1]:
            u = min(target / length, 1.0) if length else 0
            r = a[0] + (b[0] - a[0]) * u
            z = a[1] + (b[1] - a[1]) * u
            dr, dz = b[0] - a[0], b[1] - a[1]
            return r, z, Vector((dz, -dr)).normalized()
        target -= length
    return profile[-1][0], profile[-1][1], Vector((0, 1))


def build_mushroom(coll):
    parts = {name: bmesh.new() for name in ("MushroomStem", "MushroomGills", "MushroomCap", "MushroomSpots", "MushroomGrass")}
    rng = random.Random(7)
    # (scale, x, y, lean) - one hero mushroom with two smaller companions.
    for scale, x, y, lean in ((1.0, 0.0, 0.0, 0.0), (0.5, 4.6, -2.2, 0.28), (0.36, -3.8, 2.8, -0.32)):
        transform = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(lean, 4, "Y") @ Matrix.Scale(scale, 4)
        seed = x * 3.1
        stem = lathe(parts["MushroomStem"], STEM, 20, transform, wobble=0.08, seed=seed)
        orient_faces(stem, outward_from=transform @ Vector((0, 0, 3)))
        gills = lathe(parts["MushroomGills"], CAP_UNDERSIDE, 28, transform)
        orient_faces(gills, want_down=True)
        cap = lathe(parts["MushroomCap"], CAP_DOME, 28, transform, wobble=0.12, seed=seed)
        orient_faces(cap, outward_from=transform @ Vector((0, 0, 6.5)))
        # Raised white spots following the cap surface.
        for _ in range(int(11 * max(scale, 0.6))):
            r, z, n2 = point_on_profile(CAP_DOME, rng.uniform(0.18, 0.92))
            angle = rng.uniform(0, 2 * math.pi)
            position = Vector((r * math.cos(angle), r * math.sin(angle), z))
            normal = Vector((n2.x * math.cos(angle), n2.x * math.sin(angle), n2.y))
            size = rng.uniform(0.45, 0.85)
            spot_transform = transform @ Matrix.Translation(position + normal * 0.02) @ align_z(normal)
            spot = lathe(parts["MushroomSpots"], [(0, -0.05), (size, -0.05), (size * 0.85, 0.12), (size * 0.45, 0.2), (0, 0.22)], 10, spot_transform)
            orient_faces(spot, outward_from=spot_transform @ Vector((0, 0, -0.5)))
    # Grass tuft: a low lumpy mound with double-sided blades.
    grass = parts["MushroomGrass"]
    blob(grass, Vector((0.3, 0.2, 0.0)), Vector((6.2, 5.2, 1.1)), subdivisions=4, lump=0.25, seed=3)
    for _ in range(70):
        angle = rng.uniform(0, 2 * math.pi)
        radius = rng.uniform(1.6, 5.6)
        base = Vector((0.3 + math.cos(angle) * radius, 0.2 + math.sin(angle) * radius * 0.85, 0.35))
        height = rng.uniform(1.0, 2.4)
        lean = Vector((math.cos(angle), math.sin(angle), 0)) * rng.uniform(0.2, 0.7)
        across = Vector((-math.sin(angle + 1.2), math.cos(angle + 1.2), 0)) * 0.22
        spine = [base + lean * (t * t) + Vector((0, 0, height * t)) for t in (0, 0.5, 1)]
        double_sided_strip(grass, [spine[0] - across, spine[1] - across * 0.6, spine[2]],
                           [spine[0] + across, spine[1] + across * 0.6, spine[2]])
    return [finish(coll, name, bm, LAYOUT["Mushroom"]) for name, bm in parts.items()]


def build_flowers(coll):
    parts = {name: bmesh.new() for name in ("FlowerBush", "FlowerStems", "FlowerPetalsA", "FlowerPetalsB", "FlowerCenters")}
    rng = random.Random(11)
    bush = parts["FlowerBush"]
    blob(bush, Vector((0, 0, 0.2)), Vector((6.4, 5.2, 1.5)), subdivisions=4, lump=0.3, seed=5)
    blob(bush, Vector((3.4, -2.0, 0.7)), Vector((2.6, 2.2, 1.7)), subdivisions=3, lump=0.35, seed=8)
    blob(bush, Vector((-3.6, 1.8, 0.6)), Vector((2.4, 2.1, 1.5)), subdivisions=3, lump=0.35, seed=9)
    flowers = 14
    for index in range(flowers):
        angle = index / flowers * 2 * math.pi + rng.uniform(-0.3, 0.3)
        radius = rng.uniform(0.4, 4.6)
        base = Vector((math.cos(angle) * radius, math.sin(angle) * radius * 0.8, 0.9))
        height = rng.uniform(2.6, 5.4)
        lean = Vector((math.cos(angle), math.sin(angle), 0)) * rng.uniform(0.4, 1.2)
        spine = [base + lean * (t * t) + Vector((0, 0, height * t)) for t in (0, 0.33, 0.66, 1)]
        tube(parts["FlowerStems"], spine, 0.16, 0.11)
        # A leaf partway up the stem.
        leaf_at = spine[1]
        leaf_dir = Vector((math.cos(angle + 1.6), math.sin(angle + 1.6), 0.5)).normalized()
        blob(parts["FlowerStems"], leaf_at + leaf_dir * 0.9, Vector((1.0, 0.35, 0.08)), subdivisions=2,
             rotation=Vector((1, 0, 0)).rotation_difference(leaf_dir).to_matrix())
        # Flower head: tilted toward the outside, six cupped petals around a domed center.
        head = spine[-1]
        tilt = align_z((lean * 0.6 + Vector((0, 0, 1))).normalized())
        petals = parts["FlowerPetalsA"] if index % 3 != 2 else parts["FlowerPetalsB"]
        size = rng.uniform(1.05, 1.45)
        for p in range(6):
            a = p / 6 * 2 * math.pi + index
            direction = Vector((math.cos(a), math.sin(a), 0))
            petal_rot = (tilt @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(-0.35, 4, "Y")).to_3x3()
            center = head + (tilt.to_3x3() @ (direction * 0.95 * size)) + (tilt.to_3x3() @ Vector((0, 0, 0.12)))
            blob(petals, center, Vector((1.0, 0.5, 0.12)) * size, subdivisions=2, rotation=petal_rot)
        center_transform = Matrix.Translation(head + tilt.to_3x3() @ Vector((0, 0, 0.15))) @ tilt
        dome = lathe(parts["FlowerCenters"], [(0, -0.1), (0.5 * size, -0.1), (0.48 * size, 0.18), (0.3 * size, 0.32), (0, 0.38)], 12, center_transform)
        orient_faces(dome, outward_from=center_transform @ Vector((0, 0, -0.3)))
    return [finish(coll, name, bm, LAYOUT["Flower"]) for name, bm in parts.items()]


def build_fern(coll):
    parts = {"FernFronds": bmesh.new(), "FernFrondsLight": bmesh.new()}
    rng = random.Random(23)
    # (count, length range, rise range, angle offset): a wide outer ring and an upright inner ring.
    rings = ((9, (6.5, 8.5), (4.0, 5.5), 0.0), (6, (4.2, 5.4), (5.5, 7.0), 0.35))
    fronds = [(ring_index, index, ring) for ring_index, ring in enumerate(rings) for index in range(ring[0])]
    for ring_index, index, (count, length_range, rise_range, offset) in fronds:
        angle = index / count * 2 * math.pi + offset + rng.uniform(-0.15, 0.15)
        outward = Vector((math.cos(angle), math.sin(angle), 0))
        across = Vector((-math.sin(angle), math.cos(angle), 0))
        length = rng.uniform(*length_range)
        rise = rng.uniform(*rise_range)
        bm = parts["FernFronds"] if (index + ring_index) % 2 == 0 else parts["FernFrondsLight"]
        # The spine arches up and out, then droops toward the tip.
        steps = 14
        spine = []
        for s in range(steps + 1):
            t = s / steps
            spine.append(outward * (length * t) + Vector((0, 0, rise * math.sin(t * math.pi * 0.85) + 0.3)))
        tube(bm, spine, 0.12, 0.03, segments=5)
        # Leaflets on both sides, longest near the middle, tapering to the tip.
        for s in range(1, steps):
            t = s / steps
            leaf_length = 2.1 * math.sin(t * math.pi) ** 0.7 * (1.1 - t * 0.4)
            if leaf_length < 0.25:
                continue
            ahead = (spine[s + 1] - spine[s - 1]).normalized()
            for side in (-1, 1):
                direction = (across * side + ahead * 0.55 + Vector((0, 0, -0.25))).normalized()
                base = spine[s]
                tip = base + direction * leaf_length
                width = ahead * (0.32 * (1.1 - t * 0.5))
                mid = base + direction * (leaf_length * 0.45)
                double_sided_strip(bm, [base - width * 0.4, mid - width, tip], [base + width * 0.4, mid + width, tip])
    return [finish(coll, name, bm, LAYOUT["Fern"]) for name, bm in parts.items()]


def build_and_export():
    coll = get_collection()
    objects = build_mushroom(coll) + build_flowers(coll) + build_fern(coll)
    triangles = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
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
