# Future portal: World 3's look for the World portal (the hub portal and the giant end portal in
# World 2, which lead on to World 3). A smooth white composite ring with a gunmetal inner lip,
# eight clamp blocks with glowing slots and a glowing inset ring, a segmented halo of light that
# turns round the frame, a floating crystal core on top, a stepped hexagonal platform with
# glowing step edges and two emitter posts, and the same vortex disc and spiral swirl as the
# clockwork portal (PortalVortex / PortalSwirl, which the game uses to find the opening).
# Run inside Blender (e.g. via MCP). Mesh names are what WorldPortal.luau looks up:
#   FuturePortalRing, FuturePortalTrim, FuturePortalGlow, FuturePortalHalo, FuturePortalCore,
#   FuturePortalBase, FuturePortalSteps, PortalVortex, PortalSwirl
# Same conventions as world_portal.py, whose geometry helpers and vortex builder it reuses:
# +Z up, the portal faces -Y, plinth bottom at z = 0 centred on x = y = 0, under 19 units overall.
# The spinning meshes (halo, core, swirl) are centred on their axles.
WORLD_PORTAL = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\world_portal.py"
_source = open(WORLD_PORTAL, encoding="utf-8").read()
_marker = "# ---------- assembly ----------"
assert _marker in _source, "world_portal.py layout changed; update future_portal.py"
exec(_source.partition(_marker)[0])

COLLECTION = "FuturePortal"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\FuturePortal.fbx"
MAX_EXTENT = 19.0

WHITE = (0.94, 0.95, 0.97)
GUNMETAL = (0.24, 0.27, 0.33)
CYAN = (0.4, 0.92, 1.0)
VIOLET = (0.45, 0.25, 0.95)
MAGENTA = (1.0, 0.45, 0.95)

# Layout (studs). build_vortex reads CENTER_Z and VORTEX_R.
PLATFORM_TOP = 1.2
CENTER_Z = 8.4
VORTEX_R = 5.5
RING_IN, RING_OUT = 5.3, 7.2       # main ring radii
DEPTH = 1.9
HALO_R, HALO_SEGMENTS = 8.25, 12
CORE = Vector((0.0, 0.0, 17.2))    # floating crystal centre


def ring_profile(r_in, r_out, depth, chamfer):
    """A closed (radius, forward) cross-section: a rounded-off rectangle for lathe_y."""
    half = depth / 2
    return [(r_in, -half + chamfer), (r_in + chamfer, -half), (r_out - chamfer, -half), (r_out, -half + chamfer),
            (r_out, half - chamfer), (r_out - chamfer, half), (r_in + chamfer, half), (r_in, half - chamfer),
            (r_in, -half + chamfer)]


def arc_block(bm, radius, angle, width, height, depth, y=0.0, center_z=None):
    """A box standing on the ring at angle (radians, 0 = +X), its long side along the ring."""
    cz = CENTER_Z if center_z is None else center_z
    p = Vector((math.cos(angle) * radius, y, cz + math.sin(angle) * radius))
    rotation = Matrix.Rotation(-angle, 4, "Y")
    box(bm, p, (height, depth, width), rotation)


def build_ring(ring, trim, glow):
    center = Vector((0, 0, CENTER_Z))
    lathe_y(ring, ring_profile(RING_IN, RING_OUT, DEPTH, 0.35), 64, center)
    # Gunmetal inner lip and back plate ring.
    lathe_y(trim, ring_profile(RING_IN - 0.35, RING_IN + 0.15, DEPTH + 0.3, 0.1), 64, center)
    lathe_y(trim, ring_profile(RING_OUT - 0.6, RING_OUT + 0.25, 0.5, 0.1), 64, center + Vector((0, DEPTH / 2 + 0.1, 0)))
    # Glowing inset ring on the front face.
    torus(glow, center + Vector((0, -DEPTH / 2 - 0.02, 0)), (0, 1, 0), (RING_IN + RING_OUT) / 2, 0.12, segments=64, minor_segments=6)
    # Eight clamps round the ring, each with a glowing slot on its front.
    for k in range(8):
        a = math.pi / 8 + k * math.pi / 4
        arc_block(trim, (RING_IN + RING_OUT) / 2 + 0.1, a, 1.5, RING_OUT - RING_IN + 0.7, DEPTH + 0.5)
        arc_block(glow, (RING_IN + RING_OUT) / 2 + 0.1, a, 0.35, RING_OUT - RING_IN - 0.2, 0.1, y=-(DEPTH + 0.5) / 2 - 0.04)


def build_halo(halo):
    """Twelve glowing arc segments round the ring with gaps between them (it turns about the axis)."""
    center = Vector((0, 0, CENTER_Z))
    gap = 0.16
    for k in range(HALO_SEGMENTS):
        a0 = 2 * math.pi * k / HALO_SEGMENTS + gap
        a1 = 2 * math.pi * (k + 1) / HALO_SEGMENTS - gap
        steps = 6
        outer = [Vector((math.cos(a0 + (a1 - a0) * i / steps) * (HALO_R + 0.22), 0, CENTER_Z + math.sin(a0 + (a1 - a0) * i / steps) * (HALO_R + 0.22)))
                 for i in range(steps + 1)]
        inner = [Vector((math.cos(a0 + (a1 - a0) * i / steps) * (HALO_R - 0.22), 0, CENTER_Z + math.sin(a0 + (a1 - a0) * i / steps) * (HALO_R - 0.22)))
                 for i in range(steps + 1)]
        strip_slab(halo, inner, outer, -0.2, 0.2)


def build_core(core):
    """A floating double-pointed crystal above the ring (it turns about the vertical)."""
    lathe(core, [(0, -1.25), (0.7, 0.0), (0, 1.25)], 6, Matrix.Translation(CORE))


def build_base(base, steps):
    """A stepped hexagonal platform with glowing step edges, and two emitter posts in front."""
    for tier, (radius, z0, z1) in enumerate(((7.4, 0.0, 0.5), (6.4, 0.5, 0.85), (5.2, 0.85, PLATFORM_TOP))):
        lathe(base, [(0, z0), (radius, z0), (radius, z1), (0, z1)], 6, Matrix.Rotation(math.pi / 6, 4, "Z"))
        lathe(steps, [(radius + 0.03, z1 - 0.08), (radius + 0.06, z1 - 0.08), (radius + 0.06, z1 - 0.02), (radius + 0.03, z1 - 0.02),
                      (radius + 0.03, z1 - 0.08)], 6, Matrix.Rotation(math.pi / 6, 4, "Z"))
    # Feet: the ring stands on two gunmetal struts down to the platform.
    for side in (-1, 1):
        box(base, (side * 3.2, 0, (PLATFORM_TOP + CENTER_Z - RING_OUT + 1.0) / 2), (1.2, DEPTH - 0.2, CENTER_Z - RING_OUT + 1.0 - PLATFORM_TOP))
        # Emitter posts in front of the ring, each topped with a glowing lens.
        p = Vector((side * 5.6, -4.2, PLATFORM_TOP - 0.4))
        lathe(base, [(0, 0), (0.55, 0), (0.45, 2.6), (0.6, 2.8), (0.6, 3.0), (0, 3.0)], 12, Matrix.Translation(p))
        ball(steps, p + Vector((0, 0, 3.25)), 0.38, subdivisions=2)


def finish_part(coll, name, bm, rgb, angle=40):
    recalc_normals(bm)
    obj = make_object(coll, name, bm, rgb)
    smooth_by_angle(obj, angle)
    return obj


def bounds(obj):
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    return (Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points))),
            Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points))))


NAMES = ["FuturePortalRing", "FuturePortalTrim", "FuturePortalGlow", "FuturePortalHalo", "FuturePortalCore",
         "FuturePortalBase", "FuturePortalSteps", "PortalVortex", "PortalSwirl"]


def build_and_export(export=True):
    coll = fresh_collection(COLLECTION)
    layer = bpy.context.view_layer.layer_collection.children.get(COLLECTION)
    if layer:
        layer.exclude = False
    bm = {name: bmesh.new() for name in NAMES}
    build_ring(bm["FuturePortalRing"], bm["FuturePortalTrim"], bm["FuturePortalGlow"])
    build_halo(bm["FuturePortalHalo"])
    build_core(bm["FuturePortalCore"])
    build_base(bm["FuturePortalBase"], bm["FuturePortalSteps"])
    build_vortex(bm["PortalVortex"], bm["PortalSwirl"])
    colors = {"FuturePortalRing": WHITE, "FuturePortalTrim": GUNMETAL, "FuturePortalGlow": CYAN, "FuturePortalHalo": CYAN,
              "FuturePortalCore": MAGENTA, "FuturePortalBase": GUNMETAL, "FuturePortalSteps": CYAN, "PortalVortex": VIOLET,
              "PortalSwirl": MAGENTA}
    objects = [finish_part(coll, name, bm[name], colors[name]) for name in NAMES]
    low = Vector((1e9, 1e9, 1e9))
    high = -low
    problems = []
    for o in objects:
        lo, hi = bounds(o)
        low = Vector((min(low.x, lo.x), min(low.y, lo.y), min(low.z, lo.z)))
        high = Vector((max(high.x, hi.x), max(high.y, hi.y), max(high.z, hi.z)))
        c = (lo + hi) / 2
        print("%-18s %6d tris  centre (%.3f, %.3f, %.3f)" % (o.name, triangles(o), c.x, c.y, c.z))
    for name, axle in (("FuturePortalHalo", Vector((0, 0, CENTER_Z))), ("PortalSwirl", Vector((0, 0, CENTER_Z))), ("FuturePortalCore", CORE)):
        lo, hi = bounds(next(o for o in objects if o.name == name))
        c = (lo + hi) / 2
        if max(abs(c.x - axle.x), abs(c.z - axle.z)) > 1e-3:
            problems.append(name + " is not centred on its axle")
    size = high - low
    print("extent %.2f x %.2f x %.2f, base z %.2f" % (size.x, size.y, size.z, low.z))
    if max(size) > MAX_EXTENT:
        problems.append("larger than the import limit")
    if problems:
        print("PROBLEMS:", problems)
    if not export or problems:
        return objects
    for other in bpy.context.selected_objects:
        other.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.fbx(filepath=EXPORT_PATH, use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, add_leaf_bones=False, bake_anim=False)
    print("exported", EXPORT_PATH)
    return objects


build_and_export(globals().get("EXPORT", True))
