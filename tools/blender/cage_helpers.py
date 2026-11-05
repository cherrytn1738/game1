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


# ---------- builders shared by the fully custom cages (World 2 and World 4) ----------
# A custom cage script keeps a LOOKS table {mesh name: (preview rgb, shading)}, builds into
# m = meshes(LOOKS) and finishes with build_looks: "hard" smooths by angle, "smooth" shades smooth,
# "soft" keeps double-sided pieces as built. A spinning part is its own mesh, built symmetric about
# its axis, because a MeshPart turns about its bounding-box centre (check_centred reports it).
TOY_RED, TOY_YELLOW, TOY_BLUE, TOY_GREEN = (0.9, 0.18, 0.16), (1.0, 0.8, 0.12), (0.16, 0.42, 0.9), (0.22, 0.7, 0.32)
TOY_WOOD, CREAMY = (0.82, 0.62, 0.38), (0.97, 0.95, 0.9)
BALL_RADIUS = 0.37                     # the practice ball held at PITCH


def meshes(looks):
    return {name: bmesh.new() for name in looks}


def build_looks(coll, m, looks):
    objects = []
    for name, (rgb, shading) in looks.items():
        bm = m[name]
        if not bm.verts:
            bm.free()
            print("empty mesh skipped:", name)
            continue
        objects.append(soft(coll, name, bm, rgb) if shading == "soft" else finish(coll, name, bm, rgb, hard=shading == "hard"))
    return objects


def rrect(w, h, r, n=3):
    """A closed rounded-rectangle profile (u, v) centred on the origin."""
    points = []
    for cx, cy, start in ((w / 2 - r, h / 2 - r, 0), (r - w / 2, h / 2 - r, 90), (r - w / 2, r - h / 2, 180),
                          (w / 2 - r, r - h / 2, 270)):
        for k in range(n + 1):
            a = math.radians(start + 90 * k / n)
            points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return points


def circle_profile(r, n=8):
    return [(r * math.cos(2 * math.pi * k / n), r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def extrude(bm, a, b, profile, up=(0, 0, 1)):
    """A straight member from a to b with a closed profile whose v axis leans toward up."""
    a, b = Vector(a), Vector(b)
    t = (b - a).normalized()
    v = Vector(up) - t * Vector(up).dot(t)
    if v.length < 1e-6:
        v = Vector((0, 1, 0)) - t * t.y
        if v.length < 1e-6:
            v = Vector((1, 0, 0)) - t * t.x
    v.normalize()
    u = t.cross(v)
    rings = [[bm.verts.new(p + u * pu + v * pv) for pu, pv in profile] for p in (a, b)]
    for k in range(len(profile)):
        j = (k + 1) % len(profile)
        bm.faces.new((rings[0][k], rings[0][j], rings[1][j], rings[1][k]))
    bm.faces.new(tuple(reversed(rings[0])))
    bm.faces.new(tuple(rings[1]))


def slab(bm, points, thickness, normal=None):
    """A flat plate through points (a convex or star-shaped outline), thickened evenly to both sides."""
    points = [Vector(p) for p in points]
    if normal is None:
        normal = (points[1] - points[0]).cross(points[2] - points[0])
    half = Vector(normal).normalized() * thickness / 2
    low, high = [bm.verts.new(p - half) for p in points], [bm.verts.new(p + half) for p in points]
    bm.faces.new(tuple(reversed(low)))
    bm.faces.new(tuple(high))
    for i in range(len(points)):
        j = (i + 1) % len(points)
        bm.faces.new((low[i], low[j], high[j], high[i]))


def axes_of(axis):
    """Two unit vectors perpendicular to axis (and to each other)."""
    n = Vector(axis).normalized()
    helper = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    e1 = n.cross(helper).normalized()
    return e1, n.cross(e1).normalized()


def ring_points(center, axis, radius, count, a0=0.0):
    e1, e2 = axes_of(axis)
    c = Vector(center)
    return [c + (e1 * math.cos(a0 + 2 * math.pi * k / count) + e2 * math.sin(a0 + 2 * math.pi * k / count)) * radius
            for k in range(count)]


def disc(bm, center, axis, radius, thickness, segments=32):
    """A capped cylinder centred on center along axis."""
    n = Vector(axis).normalized()
    cylinder(bm, Vector(center) - n * thickness / 2, n, thickness, radius, segments=segments)


def annulus(bm, center, axis, r0, r1, thickness, segments=32):
    """A flat ring (washer) centred on center, normal to axis."""
    t = thickness / 2
    lathe(bm, [(r0, -t), (r1, -t), (r1, t), (r0, t), (r0, -t)], segments,
          transform=Matrix.Translation(Vector(center)) @ align_z(Vector(axis)))


def gear(bm, center, axis, radius, teeth, thickness, tooth=0.4, rim=0.45, spokes=6, hub=0.45, segments=None):
    """A spur gear normal to axis: a rim with teeth, spokes and a hub. Use an even tooth and spoke
    count so the gear is symmetric about its centre (it can then spin as its own mesh)."""
    c, n = Vector(center), Vector(axis).normalized()
    e1, e2 = axes_of(n)
    annulus(bm, c, n, radius - rim, radius, thickness, segments or max(24, teeth * 2))
    width = 2 * math.pi * radius / teeth * 0.5
    for k in range(teeth):
        a = 2 * math.pi * k / teeth
        d = e1 * math.cos(a) + e2 * math.sin(a)
        s = n.cross(d)
        base, top = c + d * (radius - 0.05), c + d * (radius + tooth)
        outline = [base - s * width / 2, base + s * width / 2, top + s * width * 0.32, top - s * width * 0.32]
        slab(bm, outline, thickness, n)
    for k in range(spokes):
        a = 2 * math.pi * k / spokes + math.pi / spokes
        d = e1 * math.cos(a) + e2 * math.sin(a)
        extrude(bm, c + d * hub * 0.8, c + d * (radius - rim + 0.05), rrect(max(0.12, rim * 0.7), thickness * 0.8, 0.04), up=n)
    if hub:
        disc(bm, c, n, hub, thickness * 1.4, segments=20)


def outline_radius(outline, center, direction):
    """Distance from center along direction (2D) to a closed (x, z) outline, or outline(angle)."""
    if callable(outline):
        return outline(math.atan2(direction[1], direction[0]))
    cx, cz = center
    dx, dz = direction
    best = None
    for (x0, z0), (x1, z1) in zip(outline, outline[1:] + outline[:1]):
        ex, ez = x1 - x0, z1 - z0
        det = dx * (-ez) - dz * (-ex)
        if abs(det) < 1e-12:
            continue
        rx, rz = x0 - cx, z0 - cz
        t = (rx * (-ez) - rz * (-ex)) / det
        s = (dx * rz - dz * rx) / det
        if t > 0 and -1e-6 <= s <= 1 + 1e-6 and (best is None or t < best):
            best = t
    return best or 0.0


def window_panel(bm, outline, y, thickness, center=None, radius=None, segments=56, plane="xz"):
    """A flat screen panel in the XZ plane at y: outer edge is outline (closed (x, z) points
    star-shaped round the window, or a function of the angle), with a round window of radius
    round center (default the pitch window at PITCH)."""
    center = center or (PITCH.x, PITCH.z)
    radius = radius or WINDOW + 0.06
    cx, cz = center
    half = thickness / 2
    outer, inner = [], []
    for k in range(segments):
        a = 2 * math.pi * k / segments
        d = (math.cos(a), math.sin(a))
        r = outline_radius(outline, center, d)
        outer.append((cx + d[0] * r, cz + d[1] * r))
        inner.append((cx + d[0] * radius, cz + d[1] * radius))
    rings = []
    for offset in (-half, half):
        rings.append(([bm.verts.new((x, y + offset, z)) for x, z in outer], [bm.verts.new((x, y + offset, z)) for x, z in inner]))
    (fo, fi), (bo, bi) = rings
    for k in range(segments):
        j = (k + 1) % segments
        bm.faces.new((fo[k], fo[j], fi[j], fi[k]))
        bm.faces.new((bo[j], bo[k], bi[k], bi[j]))
        bm.faces.new((fo[j], fo[k], bo[k], bo[j]))
        bm.faces.new((fi[k], fi[j], bi[j], bi[k]))


def pitch_ball(bm, radius=BALL_RADIUS, center=None):
    ball(bm, center or PITCH, radius, subdivisions=3)


def tiles(bm, x0, x1, y0, y1, size, gap, z0, z1, rng=None, jitter=0.0, keep=lambda x, y: True):
    """Floor tiles over a rectangle; keep(x, y) drops tiles by their centre."""
    nx, ny = max(1, round((x1 - x0) / size)), max(1, round((y1 - y0) / size))
    sx, sy = (x1 - x0) / nx, (y1 - y0) / ny
    for i in range(nx):
        for j in range(ny):
            cx, cy = x0 + sx * (i + 0.5), y0 + sy * (j + 0.5)
            if not keep(cx, cy):
                continue
            h = z1 - z0 + (rng.uniform(-jitter, jitter) if rng else 0.0)
            box(bm, (cx, cy, z0 + h / 2), (sx - gap, sy - gap, h))


def check_centred(objects, spins):
    """spins: {mesh name: (axis point, axis)}. Prints how far each spinning mesh's bounding-box
    centre sits off its axis (it should be ~0)."""
    by_name = {o.name: o for o in objects}
    for name, (point, axis) in spins.items():
        o = by_name.get(name)
        if not o:
            print("spin check: no mesh", name)
            continue
        lo = Vector((min(v.co.x for v in o.data.vertices), min(v.co.y for v in o.data.vertices), min(v.co.z for v in o.data.vertices)))
        hi = Vector((max(v.co.x for v in o.data.vertices), max(v.co.y for v in o.data.vertices), max(v.co.z for v in o.data.vertices)))
        c = (lo + hi) / 2 - Vector(point)
        n = Vector(axis).normalized()
        off = (c - n * c.dot(n)).length
        print("spin check %s: %.3f off its axis%s" % (name, off, "  <-- PROBLEM" if off > 0.05 else ""))


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
