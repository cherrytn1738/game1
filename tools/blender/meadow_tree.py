# Generates the stylized Meadow Run tree in Blender (run inside Blender, e.g. via MCP).
# Produces three meshes sharing an origin at the trunk base, one Roblox MeshPart each:
#   TreeTrunk      - bark
#   TreeLeaves     - full canopy (darker tone)
#   TreeLeavesTop  - thin shell over the sunlit areas (lighter tone)
# Units: 1 Blender unit is intended to be 1 stud; the tree is about 30 tall.
import bpy, bmesh
from mathutils import Vector, noise

COLLECTION = "MeadowTree"
SUN = Vector((0.0, -0.35, 1.0)).normalized()  # Light from above, biased toward the viewer (-Y).

TRUNK_NODES = [
    ((0, 0, 0), 2.0), ((0.2, 0, 3), 1.45), ((0.5, 0.2, 7), 1.15), ((0.2, 0, 11), 0.95),
    ((-3.8, 1.0, 11.5), 0.6), ((-5.8, 1.5, 14.5), 0.38), ((3.8, -1.0, 14.5), 0.62),
    ((5.4, -1.5, 17.5), 0.38), ((0.2, 2.6, 15.5), 0.5), ((0.1, 0.1, 17), 0.6),
    ((2.6, 0.2, -0.25), 0.6), ((-1.9, 1.7, -0.25), 0.55), ((-0.8, -2.4, -0.25), 0.5),
]
# Girth multiplier for the skeleton radii; the relax pass slightly thins the hull.
TRUNK_THICKNESS = 1.25
TRUNK_EDGES = [(0, 1), (1, 2), (2, 3), (2, 4), (4, 5), (3, 6), (6, 7), (3, 8), (3, 9), (0, 10), (0, 11), (0, 12)]

CANOPY_CLUMPS = [
    ((-6.0, 1.5, 16.0), 4.6), ((5.6, -1.5, 19.0), 5.0), ((0.2, 3.0, 17.5), 4.6),
    ((0.0, 0.0, 20.5), 6.2), ((-2.4, -2.4, 18.0), 4.4), ((2.4, 2.6, 21.0), 4.2),
    ((-3.0, 1.0, 22.5), 4.0), ((0.4, -0.4, 24.5), 4.4), ((3.6, -2.8, 22.0), 3.6),
    ((-7.6, -0.8, 18.4), 2.6), ((7.8, 0.6, 20.4), 2.4),
]


def get_collection():
    coll = bpy.data.collections.get(COLLECTION)
    if not coll:
        coll = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(coll)
    for obj in list(coll.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return coll


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for other in bpy.context.selected_objects:
        other.select_set(False)
    obj.select_set(True)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.shade_smooth()


def material(name, rgb, roughness):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = (*rgb, 1)
    return mat


def build_trunk(coll):
    mesh = bpy.data.meshes.new("TreeTrunk")
    mesh.from_pydata([n[0] for n in TRUNK_NODES], TRUNK_EDGES, [])
    trunk = bpy.data.objects.new("TreeTrunk", mesh)
    coll.objects.link(trunk)
    trunk.modifiers.new("Skin", "SKIN")
    for index, (_, radius) in enumerate(TRUNK_NODES):
        mesh.skin_vertices[0].data[index].radius = (radius * TRUNK_THICKNESS, radius * TRUNK_THICKNESS)
    mesh.skin_vertices[0].data[0].use_root = True
    # Relax the skin hull so branch junctions blend instead of stepping.
    relax = trunk.modifiers.new("Relax", "SMOOTH")
    relax.factor, relax.iterations = 0.5, 3
    subsurf = trunk.modifiers.new("Subsurf", "SUBSURF")
    subsurf.levels = subsurf.render_levels = 1
    apply_modifiers(trunk)
    return trunk


def build_dense_canopy(coll):
    bm = bmesh.new()
    for center, radius in CANOPY_CLUMPS:
        sphere = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=radius)
        bmesh.ops.translate(bm, verts=sphere["verts"], vec=Vector(center))
    mesh = bpy.data.meshes.new("CanopyDense")
    bm.to_mesh(mesh)
    bm.free()
    dense = bpy.data.objects.new("CanopyDense", mesh)
    coll.objects.link(dense)
    remesh = dense.modifiers.new("Remesh", "REMESH")
    remesh.mode, remesh.voxel_size = "VOXEL", 0.28
    texture = bpy.data.textures.get("TreeLeafLumps") or bpy.data.textures.new("TreeLeafLumps", "CLOUDS")
    texture.noise_scale, texture.noise_depth = 0.9, 2
    displace = dense.modifiers.new("Displace", "DISPLACE")
    displace.texture, displace.strength, displace.mid_level = texture, 0.55, 0.5
    displace.texture_coords = "GLOBAL"
    smooth = dense.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
    smooth.iterations = 2
    apply_modifiers(dense)
    return dense


def decimate(obj, ratio):
    modifier = obj.modifiers.new("Decimate", "DECIMATE")
    modifier.ratio = ratio
    apply_modifiers(obj)


def copy_object(source, name, coll):
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = obj.data.name = name
    coll.objects.link(obj)
    return obj


def build_sunlit_shell(dense, coll):
    shell = copy_object(dense, "TreeLeavesTop", coll)
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    # Organic patches: facing the sun, broken up by low-frequency noise.
    lit = {}
    for face in bm.faces:
        wobble = noise.noise(face.calc_center_median() * 0.35) * 0.35
        lit[face] = face.normal.dot(SUN) + wobble > 0.45
    # Majority filter removes specks and smooths the patch edges.
    for _ in range(4):
        updated = {}
        for face in bm.faces:
            neighbours = {other for edge in face.edges for other in edge.link_faces if other is not face}
            votes = sum(1 for other in neighbours if lit[other])
            updated[face] = votes * 2 > len(neighbours) if neighbours else lit[face]
        lit = updated
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not lit[f]], context="FACES")
    # Drop tiny islands, then lift the shell just above the canopy surface.
    islands, seen = [], set()
    for face in bm.faces:
        if face in seen:
            continue
        stack, island = [face], []
        seen.add(face)
        while stack:
            current = stack.pop()
            island.append(current)
            for edge in current.edges:
                for other in edge.link_faces:
                    if other not in seen:
                        seen.add(other)
                        stack.append(other)
        islands.append(island)
    bmesh.ops.delete(bm, geom=[f for island in islands if len(island) < 40 for f in island], context="FACES")
    bm.normal_update()
    for vert in bm.verts:
        vert.co += vert.normal * 0.12
    bm.to_mesh(shell.data)
    bm.free()
    return shell


def build():
    coll = get_collection()
    trunk = build_trunk(coll)
    dense = build_dense_canopy(coll)
    leaves = copy_object(dense, "TreeLeaves", coll)
    shell = build_sunlit_shell(dense, coll)
    bpy.data.objects.remove(dense, do_unlink=True)
    decimate(leaves, 0.12)
    decimate(shell, 0.15)
    for obj, mat in ((trunk, material("TreeBark", (0.28, 0.14, 0.06), 0.8)),
                     (leaves, material("TreeLeaf", (0.16, 0.55, 0.18), 0.6)),
                     (shell, material("TreeLeafLight", (0.42, 0.78, 0.22), 0.6))):
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    triangles = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("triangles:", {o.name: triangles(o) for o in (trunk, leaves, shell)})


build()
