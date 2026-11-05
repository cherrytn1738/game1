# Keyhole portal: World 4's (Tiny Town) look for the World portal (its hub portal and the giant end
# portal at 8,000 studs). The player is bug-sized, so the way on is through a door's keyhole: an arched
# wooden door with panel mouldings, a brass escutcheon round a keyhole that glows from the other side,
# a brass knob and hinges, on a stone threshold. The keyhole-shaped opening is PortalVortex (the game
# finds the opening by that name) with the spiral PortalSwirl turning in its round top.
# Run inside Blender (e.g. via MCP). Mesh names are what WorldPortal.luau looks up:
#   KeyholeDoor, KeyholeTrim, KeyholePlate, KeyholeScrews, KeyholeKnob, KeyholeGlow, KeyholeBase,
#   PortalVortex, PortalSwirl
# Same conventions as world_portal.py, whose geometry helpers and spiral it reuses: +Z up, the portal
# faces -Y, threshold bottom at z = 0 centred on x = y = 0, under 19 units overall. The swirl is centred
# on its axle (the keyhole's round top).
WORLD_PORTAL = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\world_portal.py"
_source = open(WORLD_PORTAL, encoding="utf-8").read()
_marker = "# ---------- assembly ----------"
assert _marker in _source, "world_portal.py layout changed; update keyhole_portal.py"
exec(_source.partition(_marker)[0])

COLLECTION = "KeyholePortal"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\KeyholePortal.fbx"
MAX_EXTENT = 19.0

WOOD = (0.55, 0.33, 0.18)
WOOD_LIGHT = (0.68, 0.43, 0.24)
BRASS4 = (0.9, 0.68, 0.3)
STONE4 = (0.62, 0.6, 0.58)
WARM = (1.0, 0.82, 0.45)
CREAM4 = (1.0, 0.95, 0.78)

# Layout (studs).
SILL = 0.8                        # threshold height; the door stands on it
DOOR_W, DOOR_RECT = 14.0, 11.0    # door width and the height of its straight sides above the sill
DOOR_DEPTH = 1.4
HOLE_C = 10.6                     # height of the keyhole's round top's centre
HOLE_R = 2.7
SLOT_BOTTOM = 5.4
SLOT_TOP_HALF, SLOT_BOTTOM_HALF = 0.95, 1.55
CENTER = Vector((0, 0, 9.4))      # the point every outline is sampled round (inside the keyhole)
SAMPLES = 96
# build_vortex's globals: the spiral sits in the keyhole's round top.
CENTER_Z = HOLE_C
VORTEX_R = HOLE_R - 0.1


def keyhole_polygon(scale=1.0):
    """The keyhole outline as a dense (x, z) polygon, scaled about CENTER."""
    join = math.acos(SLOT_TOP_HALF / HOLE_R)
    points = [(SLOT_BOTTOM_HALF, SLOT_BOTTOM)]
    for i in range(41):
        a = -join + (math.pi + 2 * join) * i / 40
        points.append((HOLE_R * math.cos(a), HOLE_C + HOLE_R * math.sin(a)))
    points.append((-SLOT_BOTTOM_HALF, SLOT_BOTTOM))
    return [(CENTER.x + (x - CENTER.x) * scale, CENTER.z + (z - CENTER.z) * scale) for x, z in points]


def door_polygon(inset=0.0):
    """The arched door outline (x, z), inset from its edge."""
    half = DOOR_W / 2 - inset
    top = SILL + DOOR_RECT
    points = [(half, SILL + inset), (half, top)]
    for i in range(1, 32):
        a = math.pi * i / 32
        points.append((half * math.cos(a), top + half * math.sin(a)))
    points += [(-half, top), (-half, SILL + inset)]
    return points


def ray_hit(polygon, angle):
    """Where a ray from CENTER at angle (in the XZ plane) leaves a star-shaped polygon."""
    d = (math.cos(angle), math.sin(angle))
    best = None
    n = len(polygon)
    for i in range(n):
        (x1, z1), (x2, z2) = polygon[i], polygon[(i + 1) % n]
        ex, ez = x2 - x1, z2 - z1
        denominator = d[0] * ez - d[1] * ex
        if abs(denominator) < 1e-9:
            continue
        ox, oz = x1 - CENTER.x, z1 - CENTER.z
        t = (ox * ez - oz * ex) / denominator
        s = (ox * d[1] - oz * d[0]) / denominator
        if t > 0 and -1e-6 <= s <= 1 + 1e-6 and (best is None or t < best):
            best = t
    return Vector((CENTER.x + d[0] * best, 0, CENTER.z + d[1] * best))


def ring_between(bm, inner_polygon, outer_polygon, y_front, y_back):
    """A slab between two outlines sampled at the same angles round CENTER (a frame with a hole)."""
    angles = [2 * math.pi * i / SAMPLES - math.pi / 2 for i in range(SAMPLES)]
    strip_slab(bm, [ray_hit(inner_polygon, a) for a in angles], [ray_hit(outer_polygon, a) for a in angles], y_front, y_back, loop=True)


def flat(bm, polygon, y_front, y_back):
    """A solid slab of an outline standing in the XZ plane."""
    front = [bm.verts.new((x, y_front, z)) for x, z in polygon]
    back = [bm.verts.new((x, y_back, z)) for x, z in polygon]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(polygon)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))


def finish_part(coll, name, bm, rgb, angle=40):
    recalc_normals(bm)
    obj = make_object(coll, name, bm, rgb)
    smooth_by_angle(obj, angle)
    ngons = bmesh.new()
    ngons.from_mesh(obj.data)
    big = [f for f in ngons.faces if len(f.verts) > 4]
    if big:
        bmesh.ops.triangulate(ngons, faces=big)
    ngons.to_mesh(obj.data)
    ngons.free()
    return obj


def bounds(obj):
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    return (Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points))),
            Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points))))


NAMES = ["KeyholeDoor", "KeyholeTrim", "KeyholePlate", "KeyholeScrews", "KeyholeKnob", "KeyholeGlow", "KeyholeBase",
         "PortalVortex", "PortalSwirl"]


def build_and_export(export=True):
    coll = fresh_collection(COLLECTION)
    layer = bpy.context.view_layer.layer_collection.children.get(COLLECTION)
    if layer:
        layer.exclude = False
    bm = {name: bmesh.new() for name in NAMES}
    half_depth = DOOR_DEPTH / 2
    hole = keyhole_polygon()
    # The door with the keyhole through it, and raised mouldings: an arched frame round its edge and a rail.
    ring_between(bm["KeyholeDoor"], hole, door_polygon(), -half_depth, half_depth)
    ring_between(bm["KeyholeTrim"], door_polygon(1.7), door_polygon(0.8), -half_depth - 0.22, -half_depth + 0.05)
    box(bm["KeyholeTrim"], (0, -half_depth - 0.08, SILL + 1.8), (DOOR_W - 2.4, 0.32, 0.8))
    box(bm["KeyholeTrim"], (0, half_depth + 0.08, SILL + 1.8), (DOOR_W - 2.4, 0.32, 0.8))
    # The brass escutcheon round the keyhole, two screws and a glowing lining inside the hole.
    ring_between(bm["KeyholePlate"], hole, keyhole_polygon(1.55), -half_depth - 0.45, -half_depth + 0.05)
    for z in (14.9, 4.3):
        lathe_y(bm["KeyholeScrews"], [(0, -0.12), (0.42, -0.12), (0.38, 0.05), (0, 0.12)], 12, (0, -half_depth - 0.52, z - 0.35))
    ring_between(bm["KeyholeGlow"], hole, keyhole_polygon(1.06), -half_depth - 0.02, half_depth - 0.2)
    # A brass knob on its rose, and two hinges on the left edge.
    knob = Vector((DOOR_W / 2 - 2.8, -half_depth, SILL + 6.6))
    lathe_y(bm["KeyholeKnob"], [(0, 0), (0.95, 0), (0.95, 0.25), (0.35, 0.4), (0.3, 1.0), (0, 1.0)], 20, knob)
    ball(bm["KeyholeKnob"], knob + Vector((0, -1.55, 0)), 0.85, subdivisions=3)
    for z in (SILL + 2.4, SILL + 9.6):
        box(bm["KeyholeKnob"], (-DOOR_W / 2 + 0.6, -half_depth - 0.1, z), (1.8, 0.24, 1.6))
        cylinder(bm["KeyholeKnob"], (-DOOR_W / 2 - 0.05, -half_depth - 0.1, z - 1.0), (0, 0, 1), 2.0, 0.32, segments=10)
    # The stone threshold.
    box(bm["KeyholeBase"], (0, -0.4, SILL / 2), (DOOR_W + 1.6, DOOR_DEPTH + 2.4, SILL))
    box(bm["KeyholeBase"], (0, -2.0, SILL * 0.25), (DOOR_W - 1.0, 1.4, SILL * 0.5))
    # The opening: the keyhole's shape, glowing, with the spiral turning in its round top.
    flat(bm["PortalVortex"], hole, -0.08, 0.08)
    throwaway = bmesh.new()
    build_vortex(throwaway, bm["PortalSwirl"])
    throwaway.free()
    colors = {"KeyholeDoor": WOOD, "KeyholeTrim": WOOD_LIGHT, "KeyholePlate": BRASS4, "KeyholeScrews": BRASS4, "KeyholeKnob": BRASS4,
              "KeyholeGlow": WARM, "KeyholeBase": STONE4, "PortalVortex": WARM, "PortalSwirl": CREAM4}
    objects = [finish_part(coll, name, bm[name], colors[name]) for name in NAMES]
    low = Vector((1e9, 1e9, 1e9))
    high = -low
    problems = []
    for o in objects:
        lo, hi = bounds(o)
        low = Vector((min(low.x, lo.x), min(low.y, lo.y), min(low.z, lo.z)))
        high = Vector((max(high.x, hi.x), max(high.y, hi.y), max(high.z, hi.z)))
        c = (lo + hi) / 2
        print("%-14s %6d tris  centre (%.3f, %.3f, %.3f)" % (o.name, triangles(o), c.x, c.y, c.z))
    lo, hi = bounds(next(o for o in objects if o.name == "PortalSwirl"))
    c = (lo + hi) / 2
    if max(abs(c.x), abs(c.z - HOLE_C)) > 1e-3:
        problems.append("PortalSwirl is not centred on its axle")
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
