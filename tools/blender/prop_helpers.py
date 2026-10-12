# Shared geometry helpers for runway prop generators (Batch 2 onward).
# Load inside Blender with: exec(open(HELPERS_PATH, encoding="utf-8").read())
# Units: 1 Blender unit is intended to be 1 stud.
import bpy, bmesh, math
from mathutils import Vector, Matrix, noise

UP = Vector((0, 0, 1))


def lathe(bm, profile, segments, transform=Matrix(), wobble=0.0, seed=0.0):
    """Revolve (radius, z) points around Z. A zero radius makes a pole. Returns the faces."""
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
                local += Vector((local.x, local.y, 0)).normalized() * noise.noise(local * 0.6 + Vector((seed, 0, 0))) * wobble
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


def orient_outward(faces, inside_point):
    """Flip a surface's faces, if needed, so normals point away from inside_point."""
    for f in faces:
        f.normal_update()
    if sum(f.normal.dot(f.calc_center_median() - inside_point) for f in faces) < 0:
        for f in faces:
            f.normal_flip()


def blob(bm, center, size, subdivisions=3, lump=0.0, lump_scale=1.7, seed=0.0, rotation=Matrix(), floor=None):
    """A lumpy ellipsoid. floor flattens anything below that z (for objects resting on the ground)."""
    sphere = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    for v in sphere["verts"]:
        offset = v.co.copy()
        if lump:
            offset *= 1 + noise.noise(offset * lump_scale + Vector((seed, seed * 0.7, 0))) * lump
        v.co = center + rotation @ Vector((offset.x * size.x, offset.y * size.y, offset.z * size.z))
        if floor is not None and v.co.z < floor:
            v.co.z = floor
    return sphere


def double_sided_strip(bm, left, right):
    """A ribbon between two point rows, built twice with opposite winding so it renders from both sides."""
    for reverse in (False, True):
        lv = [bm.verts.new(p) for p in left]
        rv = [bm.verts.new(p) for p in right]
        for i in range(len(left) - 1):
            quad = (lv[i], rv[i], rv[i + 1], lv[i + 1])
            bm.faces.new(tuple(reversed(quad)) if reverse else quad)


def sweep_frames(points):
    """Parallel-transport frames (tangent, normal, binormal) along a polyline, free of flips."""
    tangents = []
    for i in range(len(points)):
        ahead = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
        tangents.append(ahead.normalized())
    normal = tangents[0].cross(Vector((1, 0, 0)))
    if normal.length < 1e-3:
        normal = tangents[0].cross(Vector((0, 1, 0)))
    normal.normalize()
    frames = []
    for i, tangent in enumerate(tangents):
        if i > 0:
            normal = tangents[i - 1].rotation_difference(tangent) @ normal
            normal = (normal - tangent * normal.dot(tangent)).normalized()
        frames.append((tangent, normal, tangent.cross(normal)))
    return frames


def sweep(bm, points, radius, segments=12, radius_end=None, caps=True):
    """A tube along a polyline using parallel-transport frames. Returns the frames for reuse."""
    frames = sweep_frames(points)
    radius_end = radius if radius_end is None else radius_end
    rings = []
    for i, (point, (tangent, normal, binormal)) in enumerate(zip(points, frames)):
        r = radius + (radius_end - radius) * i / (len(points) - 1)
        rings.append([bm.verts.new(point + (normal * math.cos(2 * math.pi * k / segments) + binormal * math.sin(2 * math.pi * k / segments)) * r)
                      for k in range(segments)])
    for a, b in zip(rings, rings[1:]):
        for k in range(segments):
            j = (k + 1) % segments
            bm.faces.new((a[k], a[j], b[j], b[k]))
    if caps:
        bm.faces.new(tuple(reversed(rings[0])))
        bm.faces.new(tuple(rings[-1]))
    return frames


def align_z(direction):
    """4x4 rotation taking +Z onto direction."""
    return UP.rotation_difference(direction.normalized()).to_matrix().to_4x4()


def prism(bm, outline, z0, z1):
    """Extrude a closed 2D outline (counter-clockwise (x, y) points) between two heights."""
    bottom = [bm.verts.new((x, y, z0)) for x, y in outline]
    top = [bm.verts.new((x, y, z1)) for x, y in outline]
    bm.faces.new(tuple(reversed(bottom)))
    bm.faces.new(tuple(top))
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))


# ---------- scene helpers ----------

def fresh_collection(name):
    coll = bpy.data.collections.get(name)
    if not coll:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
    for obj in list(coll.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return coll


def set_material(obj, name, rgb):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    mat.diffuse_color = (*rgb, 1)
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def make_object(coll, name, bm, rgb, offset_x=0.0):
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location.x = offset_x
    coll.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    set_material(obj, name, rgb)
    return obj


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for other in bpy.context.selected_objects:
        other.select_set(False)
    obj.select_set(True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.shade_smooth()


def bevel(obj, width, segments=2):
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width, modifier.segments = width, segments
    modifier.limit_method = "ANGLE"
    apply_modifiers(obj)


def decimate(obj, ratio):
    modifier = obj.modifiers.new("Decimate", "DECIMATE")
    modifier.ratio = ratio
    apply_modifiers(obj)


def fused_surface(coll, name, bm, voxel, lump_scale, lump_strength, rgb, floor=None):
    """Voxel-remesh overlapping shapes into one organic surface with cloud-like lumps."""
    obj = make_object(coll, name, bm, rgb)
    remesh = obj.modifiers.new("Remesh", "REMESH")
    remesh.mode, remesh.voxel_size = "VOXEL", voxel
    texture = bpy.data.textures.get(name + "Lumps") or bpy.data.textures.new(name + "Lumps", "CLOUDS")
    texture.noise_scale, texture.noise_depth = lump_scale, 2
    displace = obj.modifiers.new("Displace", "DISPLACE")
    displace.texture, displace.strength, displace.mid_level = texture, lump_strength, 0.5
    displace.texture_coords = "GLOBAL"
    smooth = obj.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
    smooth.iterations = 2
    apply_modifiers(obj)
    if floor is not None:
        for v in obj.data.vertices:
            v.co.z = max(v.co.z, floor)
    return obj


def lit_shell(coll, source, name, rgb, sun=Vector((0.0, -0.35, 1.0)), threshold=0.45, wobble_scale=0.35,
              wobble=0.35, lift=0.08, min_island=40):
    """A thin shell over the up/sun-facing areas of source, for a lighter second tone.
    Picked with organic noise, cleaned with a majority filter, and lifted just above the surface."""
    sun = sun.normalized()
    shell = source.copy()
    shell.data = source.data.copy()
    shell.name = shell.data.name = name
    coll.objects.link(shell)
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    bm.normal_update()
    lit = {f: f.normal.dot(sun) + noise.noise(f.calc_center_median() * wobble_scale) * wobble > threshold for f in bm.faces}
    for _ in range(4):
        updated = {}
        for f in bm.faces:
            neighbours = {o for e in f.edges for o in e.link_faces if o is not f}
            votes = sum(1 for o in neighbours if lit[o])
            updated[f] = votes * 2 > len(neighbours) if neighbours else lit[f]
        lit = updated
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not lit[f]], context="FACES")
    seen, small = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        stack, island = [f], []
        seen.add(f)
        while stack:
            current = stack.pop()
            island.append(current)
            for e in current.edges:
                for o in e.link_faces:
                    if o not in seen:
                        seen.add(o)
                        stack.append(o)
        if len(island) < min_island:
            small.extend(island)
    bmesh.ops.delete(bm, geom=small, context="FACES")
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * lift
    bm.to_mesh(shell.data)
    bm.free()
    set_material(shell, name, rgb)
    return shell


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# ---------- Batch 3 additions ----------

def recalc_normals(bm):
    """Consistent outward normals for closed pieces (each connected piece is handled separately)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def smooth_by_angle(obj, degrees=35):
    """Flat broad planes with smoothly shaded edges (for faceted crystals, rocks, columns)."""
    bpy.context.view_layer.objects.active = obj
    for other in bpy.context.selected_objects:
        other.select_set(False)
    obj.select_set(True)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(degrees))
    except AttributeError:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(degrees))


def rough_rock(bm, center, size, rng, subdivisions=2, jitter=0.2, floor=0.0):
    """A chunky boulder: a coarse icosphere with each vertex pushed in or out at random."""
    sphere = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    for v in sphere["verts"]:
        scale = 1 + rng.uniform(-jitter, jitter)
        v.co = Vector(center) + Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) * scale
        if floor is not None:
            v.co.z = max(v.co.z, floor)
    return sphere


def hex_crystal(bm, base, direction, length, radius, sides=6):
    """A faceted crystal with a pointed tip, growing from base along direction."""
    transform = Matrix.Translation(base) @ align_z(direction)
    return lathe(bm, [(0, 0), (radius, 0), (radius * 1.06, length * 0.74), (0, length)], sides, transform)


def sweep_profile(bm, points, profile, caps=True):
    """Sweep a closed 2D profile ((u, v) along each frame's normal and binormal) along a path."""
    frames = sweep_frames(points)
    rings = [[bm.verts.new(p + n * u + b * v) for u, v in profile] for p, (t, n, b) in zip(points, frames)]
    count = len(profile)
    for a, c in zip(rings, rings[1:]):
        for k in range(count):
            j = (k + 1) % count
            bm.faces.new((a[k], a[j], c[j], c[k]))
    if caps:
        bm.faces.new(tuple(reversed(rings[0])))
        bm.faces.new(tuple(rings[-1]))
    return frames


def transform_new(bm, before_count, matrix):
    """Apply a matrix to every vertex created after before_count."""
    bm.verts.ensure_lookup_table()
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts[before_count:])
