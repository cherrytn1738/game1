# Shared layout and builders for the Training Ground cages (the standard cage and the five
# fantasy cages). Load inside Blender with: exec(open(CAGE_HELPERS, encoding="utf-8").read())
# Units are studs around the training plate centre: +X toward the pitch line (the batter
# stands at x = 0 facing +X), +Y toward the machine (Roblox -Z), +Z up. Every cage is exported
# at 1/4 scale to stay under Roblox's 2048-stud import limit (FBX arrives at 100x);
# TrainingStadium scales templates back up 4x. Keep the layout in sync with TrainingConfig.Cage.
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, noise

exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\prop_helpers.py", encoding="utf-8").read())

EXPORT_SCALE = 0.25
LEFT_X, RIGHT_X = -16.0, 14.0          # side walls; pitch line x = 3, batter at x = 0
BACK_Y, FRONT_Y = -14.0, 34.0          # batter end (door), machine end
HEIGHT = 14.0
HOOPS = [-14.0, -6.0, 2.0, 10.0, 18.0, 26.0, 34.0]
DOOR = (-13.0, -7.0, 8.0)              # door in the batter-end wall: x from, x to, height
PITCH = Vector((3.0, 24.0, 3.0))       # ball exit (Roblox PitchOffset 3, 3, -24)
SCREEN_Y, WINDOW = 21.0, 0.95          # protective screen plane and its window half-size
# Neighbouring cages are 44 studs apart (14-stud gaps), so nothing may reach past these.
SIDE_LIMITS = (-23.0, 21.0)
MAX_EXTENT = 81.0                      # 20.48 units at 1/4 scale, the import limit
MAX_TRIANGLES = 18000                  # per mesh, under Roblox's per-MeshPart limit
WHITE = (0.96, 0.96, 0.95)


def hoop_fraction(y, hoops=HOOPS):
    """0 at a hoop, 1 midway between two hoops: drives sag and billow."""
    for a, b in zip(hoops, hoops[1:]):
        if a <= y <= b:
            return math.sin(math.pi * (y - a) / (b - a))
    return 0.0


def arange(length, step):
    count = max(1, round(length / step))
    return [length * i / count for i in range(count + 1)]


def net_panel(bm, origin, u_axis, v_axis, u_len, v_len, normal, spacing, width,
              displace=lambda u, v: 0.0, hole=lambda u, v: False, rope=0.06, diamond=False, wobble=0.0, seed=0.0):
    """A net of flat double-sided strands with an optional rope border. diamond turns the
    square mesh 45 degrees; wobble adds a hand-woven waviness to each strand."""
    def point(u, v):
        p = origin + u_axis * u + v_axis * v + normal * displace(u, v)
        if wobble:
            p += normal * noise.noise(Vector((u * 0.7, v * 0.7, seed))) * wobble
        return p

    def strand(samples, across):
        runs, run = [], []
        for u, v in samples:
            if hole(u, v) or not (-1e-6 <= u <= u_len + 1e-6 and -1e-6 <= v <= v_len + 1e-6):
                if len(run) > 1:
                    runs.append(run)
                run = []
            else:
                run.append(point(u, v))
        if len(run) > 1:
            runs.append(run)
        for points in runs:
            half = across * (width / 2)
            double_sided_strip(bm, [p - half for p in points], [p + half for p in points])

    if diamond:
        step = spacing / 2
        span = u_len + v_len
        count = int(span / spacing) + 2
        for direction in (1, -1):
            # Strands run along (1, direction) in panel space; across is the in-plane perpendicular.
            across = (u_axis * -direction + v_axis).normalized()
            for k in range(-count, count + 1):
                c = k * spacing
                samples = []
                t = -span
                while t <= span:
                    u = t
                    v = c + direction * t
                    samples.append((u, v))
                    t += step
                strand(samples, across)
    else:
        fine_v, fine_u = arange(v_len, spacing / 2), arange(u_len, spacing / 2)
        for u in arange(u_len, spacing):
            strand([(u, v) for v in fine_v], u_axis)
        for v in arange(v_len, spacing):
            strand([(u, v) for u in fine_u], v_axis)
    if rope:
        fine_v, fine_u = arange(v_len, spacing / 2), arange(u_len, spacing / 2)
        for edge in ([(u, 0.0) for u in fine_u], [(u, v_len) for u in fine_u],
                     [(0.0, v) for v in fine_v], [(u_len, v) for v in fine_v]):
            sweep(bm, [point(u, v) for u, v in edge], rope, segments=5)


def sweep_radii(bm, points, radii, segments=10, caps=True):
    """A tube along a polyline whose radius is given per point (tapering branches, horns)."""
    frames = sweep_frames(points)
    rings = []
    for point, r, (tangent, normal, binormal) in zip(points, radii, frames):
        rings.append([bm.verts.new(point + (normal * math.cos(2 * math.pi * k / segments)
                                            + binormal * math.sin(2 * math.pi * k / segments)) * r)
                      for k in range(segments)])
    for a, b in zip(rings, rings[1:]):
        for k in range(segments):
            j = (k + 1) % segments
            bm.faces.new((a[k], a[j], b[j], b[k]))
    if caps:
        bm.faces.new(tuple(reversed(rings[0])))
        bm.faces.new(tuple(rings[-1]))
    return frames


class Polyline:
    """Arc-length lookup along a 3D polyline: at(s) for 0 <= s <= length."""
    def __init__(self, points):
        self.points = [Vector(p) for p in points]
        self.lengths = [0.0]
        for a, b in zip(self.points, self.points[1:]):
            self.lengths.append(self.lengths[-1] + (b - a).length)
        self.length = self.lengths[-1]

    def at(self, s):
        s = min(max(s, 0.0), self.length)
        for i in range(1, len(self.lengths)):
            if s <= self.lengths[i]:
                span = self.lengths[i] - self.lengths[i - 1]
                t = 0.0 if span == 0 else (s - self.lengths[i - 1]) / span
                return self.points[i - 1].lerp(self.points[i], t)
        return self.points[-1].copy()

    def samples(self, step):
        return [self.at(s) for s in arange(self.length, step)]


def surface_net(bm, surface, u_len, v_len, spacing, width, hole=lambda u, v: False, diamond=True,
                wobble=0.0, seed=0.0, offset=0.0, lift=0.0):
    """Flat double-sided strands over a curved surface(u, v) -> point. Strands follow the
    parameter grid (or its diagonals); lift pushes them off the surface along its normal."""
    eps = 0.05

    def normal_at(u, v):
        p = surface(u, v)
        du = surface(u + eps, v) - p
        dv = surface(u, v + eps) - p
        n = du.cross(dv)
        return n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))

    def point(u, v):
        p = surface(u, v)
        push = lift + (noise.noise(Vector((u * 0.7, v * 0.7, seed))) * wobble if wobble else 0.0)
        return p + normal_at(u, v) * push if push else p

    def strand(samples, direction):
        runs, run = [], []
        for u, v in samples:
            if hole(u, v) or not (-1e-6 <= u <= u_len + 1e-6 and -1e-6 <= v <= v_len + 1e-6):
                if len(run) > 1:
                    runs.append(run)
                run = []
            else:
                run.append((u, v))
        if len(run) > 1:
            runs.append(run)
        du, dv = direction
        for run in runs:
            left, right = [], []
            for u, v in run:
                p = point(u, v)
                across = surface(u - dv * eps, v + du * eps) - surface(u, v)
                across = across.normalized() * (width / 2) if across.length > 1e-9 else Vector((0, 0, width / 2))
                left.append(p - across)
                right.append(p + across)
            double_sided_strip(bm, left, right)

    step = spacing / 2
    if diamond:
        span = u_len + v_len
        count = int(span / spacing) + 2
        ts = arange(span * 2, step / 1.414)
        for d in (1, -1):
            for k in range(-count, count + 1):
                c = k * spacing + offset
                strand([(t - span, c + d * (t - span)) for t in ts], (1 / 1.414, d / 1.414))
    else:
        for u in arange(u_len, spacing):
            strand([(u + offset, v) for v in arange(v_len, step)], (0, 1))
        for v in arange(v_len, spacing):
            strand([(u, v + offset) for u in arange(u_len, step)], (1, 0))


def grid_surface(bm, surface, u_count, v_count, double=True, keep=lambda u, v: True):
    """A quad grid over surface(u, v) for 0..1 parameters. double builds both windings so it
    renders from either side; keep(u, v) drops cells (holes)."""
    for reverse in ((False, True) if double else (False,)):
        verts = [[bm.verts.new(surface(i / u_count, j / v_count)) for j in range(v_count + 1)] for i in range(u_count + 1)]
        for i in range(u_count):
            for j in range(v_count):
                if not keep((i + 0.5) / u_count, (j + 0.5) / v_count):
                    continue
                quad = (verts[i][j], verts[i + 1][j], verts[i + 1][j + 1], verts[i][j + 1])
                bm.faces.new(tuple(reversed(quad)) if reverse else quad)


def slab_with_window(bm, x0, x1, z0, z1, center, radius, y, thickness, segments=40, top_noise=0.0, seed=0.0):
    """A screen slab in the XZ plane (centred on y) with a round window at center (x, z).
    top_noise roughens the top edge (broken stone, flames, crystal)."""
    cx, cz = center
    outer, inner = [], []
    for k in range(segments):
        a = 2 * math.pi * k / segments
        d = Vector((math.cos(a), math.sin(a)))
        hits = []
        if abs(d.x) > 1e-6:
            hits += [((x1 - cx) / d.x), ((x0 - cx) / d.x)]
        if abs(d.y) > 1e-6:
            hits += [((z1 - cz) / d.y), ((z0 - cz) / d.y)]
        t = min(h for h in hits if h > 0)
        p = Vector((cx + d.x * t, cz + d.y * t))
        if top_noise and p.y > z1 - 1e-4:
            p.y += noise.noise(Vector((p.x * 0.9, seed, 0))) * top_noise
        outer.append(p)
        inner.append(Vector((cx + d.x * radius, cz + d.y * radius)))
    half = thickness / 2
    rings = {}
    for side, offset in (("front", -half), ("back", half)):
        rings[side] = ([bm.verts.new((p.x, y + offset, p.y)) for p in outer],
                       [bm.verts.new((p.x, y + offset, p.y)) for p in inner])
    for k in range(segments):
        j = (k + 1) % segments
        fo, fi = rings["front"]
        bo, bi = rings["back"]
        bm.faces.new((fo[k], fo[j], fi[j], fi[k]))
        bm.faces.new((bo[j], bo[k], bi[k], bi[j]))
        bm.faces.new((fo[j], fo[k], bo[k], bo[j]))
        bm.faces.new((fi[k], fi[j], bi[j], bi[k]))


def tube(bm, a, b, radius, segments=10, radius_end=None):
    a, b = Vector(a), Vector(b)
    sweep(bm, [a.lerp(b, t / 4) for t in range(5)], radius, segments=segments, radius_end=radius_end)


def box(bm, center, size, rotation=Matrix()):
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(Vector(center)) @ rotation @ Matrix.Diagonal((*size, 1.0)))


def cylinder_x(bm, center, length, radius, segments=16):
    """A capped cylinder along X."""
    turn = Matrix.Translation(Vector(center)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    lathe(bm, [(0, -length / 2), (radius, -length / 2), (radius, length / 2), (0, length / 2)], segments, transform=turn)


def cylinder(bm, base, direction, length, radius, segments=16, radius_top=None):
    """A capped (optionally tapered) cylinder from base along direction."""
    top = radius if radius_top is None else radius_top
    lathe(bm, [(0, 0), (radius, 0), (top, length), (0, length)], segments,
          transform=Matrix.Translation(Vector(base)) @ align_z(Vector(direction)))


def torus(bm, center, axis, radius, minor, segments=32, minor_segments=8):
    """A ring around axis through center."""
    profile = [(radius + minor * math.cos(2 * math.pi * k / minor_segments), minor * math.sin(2 * math.pi * k / minor_segments))
               for k in range(minor_segments)]
    lathe(bm, profile + [profile[0]], segments, transform=Matrix.Translation(Vector(center)) @ align_z(Vector(axis)))


def ball(bm, center, radius, subdivisions=2):
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius, matrix=Matrix.Translation(Vector(center)))


def double_sided_poly(bm, points):
    """A flat polygon visible from both sides (leaves, feathers, flat petals)."""
    for reverse in (False, True):
        verts = [bm.verts.new(p) for p in points]
        bm.faces.new(tuple(reversed(verts)) if reverse else tuple(verts))


def leaf(bm, base, direction, side, length, width):
    """A pointed leaf shape lying in the plane of direction and side."""
    d, s = Vector(direction).normalized(), Vector(side).normalized()
    b = Vector(base)
    lift = d.cross(s).normalized() * length * 0.12
    double_sided_poly(bm, [b, b + d * length * 0.35 + s * width / 2 + lift, b + d * length,
                           b + d * length * 0.35 - s * width / 2 + lift])


def wavy(a, b, count, amplitude, seed=0.0, sag=0.0):
    """Points from a to b with a gentle noise offset and an optional downward sag."""
    a, b = Vector(a), Vector(b)
    points = []
    for i in range(count + 1):
        t = i / count
        p = a.lerp(b, t)
        p += Vector((noise.noise(Vector((t * 3, seed, 0))), noise.noise(Vector((seed, t * 3, 1))),
                     noise.noise(Vector((0, seed, t * 3))))) * amplitude
        p.z -= sag * math.sin(math.pi * t)
        points.append(p)
    return points


def home_plate(bm, z_top=0.07):
    """Home plate on the pitch line, its point toward the batter end."""
    s = 1.1
    outline = [(s, s * 0.5), (-s, s * 0.5), (-s, -s * 0.5), (0, -s * 1.5), (s, -s * 0.5)]
    prism(bm, [(x + PITCH.x, y) for x, y in outline], 0.0, z_top)


def screen_frame_points():
    """Corner points of the protective screen window, on the screen plane."""
    cx, cz, w = PITCH.x, PITCH.z, WINDOW
    return [(cx - w, cz - w), (cx + w, cz - w), (cx + w, cz + w), (cx - w, cz + w)]


def finish(coll, name, bm, rgb, hard=True, bevel_width=0.0):
    recalc_normals(bm)
    obj = make_object(coll, name, bm, rgb)
    if bevel_width:
        bevel(obj, bevel_width)
    if hard:
        smooth_by_angle(obj, 40)
    return obj


def soft(coll, name, bm, rgb):
    """make_object for open or double-sided pieces (no normal recalculation)."""
    return make_object(coll, name, bm, rgb)


def begin(collection):
    coll = fresh_collection(collection)
    layer = bpy.context.view_layer.layer_collection.children.get(collection)
    if layer:
        layer.exclude = False
    for other in bpy.context.view_layer.layer_collection.children:
        if other.name != collection:
            other.exclude = True
    return coll


def report_and_export(objects, path, export=True):
    """Print triangle counts and extents, enforce the limits, then export at 1/4 scale."""
    counts = {o.name: triangles(o) for o in objects}
    print("triangles:", counts, "total", sum(counts.values()))
    xs, ys, zs = [], [], []
    for o in objects:
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            xs.append(p.x), ys.append(p.y), zs.append(p.z)
    extent = (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))
    print("extent x %.1f..%.1f  y %.1f..%.1f  z %.1f..%.1f" % extent)
    problems = [n for n, c in counts.items() if c > MAX_TRIANGLES]
    if extent[0] < SIDE_LIMITS[0] - 0.01 or extent[1] > SIDE_LIMITS[1] + 0.01:
        problems.append("reaches into the neighbouring cage")
    if max(extent[1] - extent[0], extent[3] - extent[2], extent[5] - extent[4]) > MAX_EXTENT:
        problems.append("larger than the import limit")
    if problems:
        print("PROBLEMS:", problems)
    if not export or problems:
        return objects
    for other in bpy.context.selected_objects:
        other.select_set(False)
    for obj in objects:
        obj.data.transform(Matrix.Scale(EXPORT_SCALE, 4))
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, add_leaf_bones=False, bake_anim=False)
    print("exported", path)
    return objects
