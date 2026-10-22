# The ten World 2 (Time Travel) balls, exported together as assets/models/BallsWorld2.fbx.
# Run headless:  blender --background --python tools/blender/balls_world2.py
# (or inside Blender via MCP). Same conventions as balls.py: every ball is built at radius 1
# around its own centre, spaced along X so they do not overlap in the import, and each mesh is
# named "<item id>__<Part>". The main body is always the "Shell" part (the game measures the
# ball's size from it). balls.py's helpers are reused without running its build, so the World 1
# "Balls" collection is left untouched.
from mathutils.bvhtree import BVHTree

BALLS_SCRIPT = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\balls.py"
_balls_source = open(BALLS_SCRIPT, encoding="utf-8").read()
assert "\nobjects = build(" in _balls_source, "balls.py layout changed; update balls_world2.py"
exec(_balls_source.partition("\nobjects = build(")[0])

COLLECTION = "BallsWorld2"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\BallsWorld2.fbx"

FRONT = Vector((0, -1, 0))
GOLD = (1.0, 0.76, 0.22)


# ---------- surface helpers ----------

class Patch:
    """(u, v) coordinates on the tangent plane at normal (u right, v up), projected onto the
    sphere. Flat 2D outlines drawn in a patch hug the ball's curvature."""

    def __init__(self, normal, up=(0, 0, 1), spin=0.0, scale=1.0):
        n = Vector(normal).normalized()
        up = Vector(up)
        y = up - n * up.dot(n)
        if y.length < 1e-4:
            y = n.orthogonal()
        y.normalize()
        x = y.cross(n).normalized()
        c, s = math.cos(spin), math.sin(spin)
        self.n, self.x, self.y = n, (x * c + y * s) * scale, (y * c - x * s) * scale

    def direction(self, u, v):
        return (self.n + self.x * u + self.y * v).normalized()

    def at(self, u, v, lift=1.0):
        return self.direction(u, v) * R * lift


def resample(points, step, closed=False):
    """Adds points along each edge so long straight edges still bend with the sphere."""
    pts = [Vector(p) for p in points]
    if closed:
        pts = pts + [pts[0]]
    out = []
    for a, b in zip(pts, pts[1:]):
        count = max(1, math.ceil((b - a).length / step))
        out.extend(a.lerp(b, i / count) for i in range(count))
    if not closed:
        out.append(pts[-1])
    return out


def ellipse(cx, cy, rx, ry, count=16, spin=0.0):
    c, s = math.cos(spin), math.sin(spin)
    points = []
    for i in range(count):
        a = 2 * math.pi * i / count
        x, y = math.cos(a) * rx, math.sin(a) * ry
        points.append(Vector((cx + x * c - y * s, cy + x * s + y * c)))
    return points


def decal(bm, patch, outline, base=0.985, top=1.035, dome=0.0, rings=2, centre=None):
    """A raised badge: a star-shaped 2D outline extruded from inside the shell (base) to top,
    with an optional domed middle. Fan-built from the centre, so concave notches are fine."""
    outline = [Vector(p) for p in outline]
    c = Vector(centre) if centre is not None else sum(outline, Vector((0, 0))) / len(outline)

    def vert(p, lift):
        return bm.verts.new(patch.at(p.x, p.y, lift))

    apex = vert(c, top + dome)
    layers = [[vert(c.lerp(p, k / rings), top + dome * (1 - (k / rings) ** 2)) for p in outline]
              for k in range(1, rings + 1)]
    bottom = [vert(p, base) for p in outline]
    floor = vert(c, base)
    m = len(outline)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((apex, layers[0][i], layers[0][j]))
        for a, b in zip(layers, layers[1:]):
            bm.faces.new((a[i], b[i], b[j], a[j]))
        bm.faces.new((layers[-1][i], bottom[i], bottom[j], layers[-1][j]))
        bm.faces.new((floor, bottom[j], bottom[i]))


def flat_ring(bm, patch, outer, inner, base=0.985, top=1.04):
    """A raised ring between two matching 2D outlines (gear rims)."""
    loops = [[bm.verts.new(patch.at(p.x, p.y, lift)) for p in pts]
             for pts, lift in ((outer, top), (inner, top), (inner, base), (outer, base))]
    m = len(outer)
    for a, b in zip(loops, loops[1:] + loops[:1]):
        for i in range(m):
            j = (i + 1) % m
            bm.faces.new((a[i], a[j], b[j], b[i]))


def ribbon(bm, points, width, base=0.985, top=1.03, closed=False):
    """A flat-topped strap lying on the sphere along points (bands, rune strokes, trim).
    Corners are mitred so the strap keeps its width."""
    pts = [Vector(p).normalized() for p in points]
    if closed and (pts[0] - pts[-1]).length < 1e-6:
        pts = pts[:-1]
    count = len(pts)
    rings = []
    for i, p in enumerate(pts):
        prev = pts[i - 1] if (closed or i > 0) else None
        ahead = pts[(i + 1) % count] if (closed or i < count - 1) else None
        sides = [(b - a).cross(p).normalized() for a, b in ((prev, p), (p, ahead)) if a is not None and b is not None]
        side = sum(sides, Vector((0, 0, 0))).normalized()
        half = side * (width / 2) / max(0.5, side.dot(sides[0]))
        rings.append([bm.verts.new((p + o).normalized() * R * lift)
                      for o, lift in ((-half, base), (half, base), (half, top), (-half, top))])
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for a, b in pairs:
        for k in range(4):
            j = (k + 1) % 4
            bm.faces.new((a[k], a[j], b[j], b[k]))
    if not closed:
        bm.faces.new(tuple(reversed(rings[0])))
        bm.faces.new(tuple(rings[-1]))


def stroke(bm, patch, points2d, width, base=0.985, top=1.03, closed=False, step=0.04):
    """A ribbon along a 2D polyline drawn in a patch (glyphs, ticks, hands)."""
    pts = resample(points2d, step, closed)
    ribbon(bm, [patch.direction(p.x, p.y) for p in pts], width, base, top, closed)


def latitude(h, count=96, turn=Matrix(), a0=0.0, a1=2 * math.pi):
    """Unit points around the circle at height h above the equator of a (turned) Z axis.
    A full circle leaves out the repeated end point (use closed=True ribbons)."""
    r = math.sqrt(max(0.0, 1 - h * h))
    full = abs(a1 - a0 - 2 * math.pi) < 1e-6
    steps = count if full else max(2, count)
    rot = turn.to_3x3()
    points = []
    for i in range(steps if full else steps + 1):
        a = a0 + (a1 - a0) * i / steps
        points.append(rot @ Vector((math.cos(a) * r, math.sin(a) * r, h)))
    return points


def rivet(bm, normal, radius, z0, height, sides=8):
    """A round dome standing at distance z0 from the centre along normal."""
    lathe(bm, [(0, z0 + height), (radius * 0.65, z0 + height * 0.8), (radius, z0), (0, z0 - 0.04)], sides,
          transform=surface_frame(normal))


def project_onto(bm, tree):
    """Moves every vertex along its direction so its height above radius R becomes a height
    above the (lumpy) shell surface instead."""
    origin = Vector((0, 0, 0))
    for v in bm.verts:
        d = v.co.normalized()
        hit = tree.ray_cast(origin, d)
        if hit[0] is not None:
            v.co = d * (hit[3] + v.co.length - R)


def wobbly_outline(size, rng, count=11, squash=1.0):
    """An organic blob outline (egg speckles, moss)."""
    radii = [rng.uniform(0.75, 1.2) for _ in range(count)]
    radii = [(radii[i - 1] + radii[i] * 2 + radii[(i + 1) % count]) / 4 for i in range(count)]
    return [Vector((math.cos(2 * math.pi * i / count) * size * r, math.sin(2 * math.pi * i / count) * size * r * squash))
            for i, r in enumerate(radii)]


def lens(length, width, count=12, notch=0.0):
    """A pointed leaf / petal outline along +v from the origin. notch dents the tip (petals)."""
    points = []
    for i in range(count):
        a = 2 * math.pi * i / count
        v = (1 - math.cos(a)) / 2 * length
        u = math.sin(a) * width / 2 * (max(0.0, math.sin(math.pi * v / length)) ** 0.7)
        points.append(Vector((u, v)))
    if notch:
        points[count // 2] = Vector((0, length - notch))
    return points


def petal_outline(size):
    """A cherry-blossom petal along +v: narrow at the base, round and notched at the tip."""
    points = []
    for i in range(16):
        a = -math.pi / 2 + 2 * math.pi * i / 16
        u, v = math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.5
        if v < 0.45:
            u *= max(0.12, v / 0.45) ** 0.6
        points.append(Vector((u * size, v * size)))
    points[8] = Vector((0, 0.84 * size))
    return points


# ---------- the ten balls ----------

def dino_egg_ball(add):
    """Lumpy cream eggshell (pointy end up) with raised speckles and hatching cracks."""
    s, spots, cracks = bmesh.new(), bmesh.new(), bmesh.new()
    shell(s, lump=0.022, seed=12)
    for v in s.verts:
        v.co.x *= 1 - 0.06 * v.co.z
        v.co.y *= 1 - 0.06 * v.co.z
        v.co.z *= 1.04
    tree = BVHTree.FromBMesh(s)
    rng = random.Random(31)
    for i, n in enumerate(fibonacci_points(30, seed=0.7)):
        n = (n + Vector((rng.uniform(-.25, .25), rng.uniform(-.25, .25), rng.uniform(-.25, .25)))).normalized()
        size = rng.uniform(0.13, 0.2) if i % 4 == 0 else rng.uniform(0.05, 0.11)
        decal(spots, Patch(n, spin=rng.uniform(0, math.pi)), wobbly_outline(size, rng, squash=rng.uniform(0.7, 1.0)),
              base=0.985, top=1.012, dome=0.012)
    # The main crack zig-zags part way around the top, with short branches off its teeth.
    teeth = []
    points = []
    for i in range(15):
        a = math.radians(-160 + i * 13)
        h = 0.5 + (0.08 if i % 2 == 0 else -0.08)
        p = latitude(h, a0=a, a1=a, count=2)[0]
        points.append(p * R * 1.005)
        teeth.append((p, 1 if i % 2 == 0 else -1))
    sweep(cracks, points, 0.03, segments=6)
    for k in (2, 5, 9, 12):
        p, sign = teeth[k]
        up = Vector((0, 0, sign))
        side = up.cross(p).normalized()
        branch = [p, (p + up * 0.12 + side * 0.05).normalized(), (p + up * 0.2 - side * 0.02).normalized()]
        sweep(cracks, [q * R * 1.005 for q in branch], 0.024, segments=6, radius_end=0.008)
    # A second, smaller crack lower on the other side.
    points = []
    for i in range(6):
        a = math.radians(70 + i * 13)
        points.append(latitude(0.1 + (0.07 if i % 2 == 0 else -0.07), a0=a, a1=a, count=2)[0] * R * 1.005)
    sweep(cracks, points, 0.026, segments=6, radius_end=0.01)
    project_onto(spots, tree)
    project_onto(cracks, tree)
    add("Shell", s, (0.96, 0.92, 0.8))
    add("Spots", spots, (0.45, 0.55, 0.25), smooth=False)
    add("Cracks", cracks, (0.25, 0.18, 0.12))


def stone_shell(bm, rng):
    """A chunky boulder: a lumpy sphere chopped by random planes into broad flat facets."""
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=R)
    for v in bm.verts:
        v.co *= 1 + noise.noise(v.co * 1.4 + Vector((5, 0, 0))) * 0.06
    for n in fibonacci_points(30, seed=0.5):
        n = (n + Vector((rng.uniform(-.2, .2), rng.uniform(-.2, .2), rng.uniform(-.2, .2)))).normalized()
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=n * rng.uniform(0.86, 0.93),
                               plane_no=n, clear_outer=True)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    xs, ys, zs = zip(*[tuple(v.co) for v in bm.verts])
    size = (max(xs) - min(xs) + max(ys) - min(ys) + max(zs) - min(zs)) / 3
    bmesh.ops.scale(bm, vec=Vector((1, 1, 1)) * (2 * R / size), verts=bm.verts[:])


def stone_ball(add):
    """Faceted grey rock with dark crack grooves and patches of moss."""
    s, cracks, moss = bmesh.new(), bmesh.new(), bmesh.new()
    rng = random.Random(41)
    stone_shell(s, rng)
    tree = BVHTree.FromBMesh(s)
    for n in fibonacci_points(11, seed=2.4):
        # Flat, barely raised strips with dense points, so once projected onto the rock they
        # follow the facets and read as grooves rather than twigs.
        path = zigzag(crack_path(n, rng.randint(5, 7), rng, step=0.16, wander=0.45), 0.04, every=2)
        ribbon(cracks, resample(path, 0.04), 0.065, base=0.975, top=1.007)
        for start in (path[len(path) // 3], path[2 * len(path) // 3]):
            ribbon(cracks, resample(crack_path(start, 2, rng, step=0.14, wander=0.8), 0.04), 0.045, base=0.975, top=1.007)
    for centre in (Vector((0.3, -0.5, 0.8)), Vector((-0.7, 0.3, 0.6)), Vector((0.6, 0.6, 0.3)),
                   Vector((-0.4, -0.8, -0.2)), Vector((0.2, 0.4, -0.9))):
        centre.normalize()
        patch = Patch(centre, spin=rng.uniform(0, 3))
        decal(moss, patch, wobbly_outline(0.26, rng, count=14, squash=0.8), base=0.97, top=1.015, dome=0.012)
        for _ in range(20):
            u, v = rng.uniform(-0.24, 0.24), rng.uniform(-0.19, 0.19)
            if u * u / 0.0576 + v * v / 0.0361 > 1:
                continue
            ball(moss, patch.at(u, v, 1.015), rng.uniform(0.045, 0.085), subdivisions=1)
    project_onto(cracks, tree)
    project_onto(moss, tree)
    add("Shell", s, (0.55, 0.53, 0.5), smooth=False)
    smooth_by_angle(bpy.data.objects["stone_ball__Shell"], 20)  # crisper facets than the default 40
    add("Cracks", cracks, (0.2, 0.19, 0.18))
    add("Moss", moss, (0.35, 0.6, 0.2))


def scarab(bm, normal):
    """A winged scarab pushing a sun disc, facing out along normal."""
    patch = Patch(normal, scale=1.22)
    for side in (-1, 1):
        # Wing: a covert bar over five long feathers fanning out from the shoulder.
        shoulder = Vector((0.09 * side, 0.07))
        for k, (angle, length) in enumerate(((14, 0.6), (2, 0.58), (-10, 0.52), (-22, 0.45), (-34, 0.37))):
            a = math.radians(angle)
            direction = Vector((math.cos(a) * side, math.sin(a)))
            normal2d = Vector((-direction.y, direction.x))
            outline = []
            for i in range(9):
                t = math.pi * i / 8
                tip = shoulder + direction * (length - 0.04)
                outline.append(tip + direction * math.sin(t) * 0.04 + normal2d * math.cos(t) * 0.04)
            outline += [shoulder - normal2d * 0.035, shoulder + normal2d * 0.035]
            decal(bm, patch, resample(outline, 0.06, closed=True), top=1.034 - 0.004 * k, dome=0.012, rings=2,
                  centre=shoulder + direction * length * 0.5)
        cover = []
        for i in range(9):
            t = i / 8
            cover.append(Vector(((0.08 + 0.34 * t) * side, 0.13 + 0.06 * math.sin(math.pi * t * 0.8))))
        for i in range(8, -1, -1):
            t = i / 8
            cover.append(Vector(((0.08 + 0.34 * t) * side, 0.05 + 0.06 * math.sin(math.pi * t * 0.8) + 0.04 * t)))
        decal(bm, patch, cover, top=1.045, dome=0.01, centre=Vector((0.25 * side, 0.155)))
        # Legs.
        for y0, y1 in ((-0.02, -0.12), (-0.14, -0.26)):
            stroke(bm, patch, [(0.1 * side, y0), (0.2 * side, y0 - 0.04), (0.2 * side, y1)], 0.028, top=1.035)
    for side in (-1, 1):
        decal(bm, patch, ellipse(0.072 * side, -0.1, 0.07, 0.19, 18), top=1.05, dome=0.04, rings=3)
    decal(bm, patch, ellipse(0, 0.12, 0.13, 0.075, 18), top=1.05, dome=0.03, rings=3)
    head = ellipse(0, 0.22, 0.075, 0.05, 14)
    decal(bm, patch, head, top=1.045, dome=0.02)
    for k in range(5):
        a = math.radians(50 + k * 20)
        stroke(bm, patch, [(math.cos(a) * 0.07, 0.22 + math.sin(a) * 0.04), (math.cos(a) * 0.1, 0.22 + math.sin(a) * 0.08)],
               0.022, top=1.05)
    decal(bm, patch, ellipse(0, 0.41, 0.1, 0.1, 20), top=1.04, dome=0.025, rings=3)


def scarab_ball(add):
    """Lapis blue with golden winged scarabs on two sides and two notched hieroglyph bands."""
    s, beetles, bands = bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    scarab(beetles, FRONT)
    scarab(beetles, -FRONT)
    rng = random.Random(3)
    for h in (0.74, -0.74):
        sign = 1 if h > 0 else -1
        for edge in (0.085, -0.085):
            ribbon(bands, latitude(h + edge * math.sqrt(1 - h * h), 120), 0.03, top=1.04, closed=True)
        ribbon(bands, latitude(h, 120), 0.17, top=1.015, closed=True)
        # A row of glyph blocks between the rails, like a band of hieroglyphs.
        a = 0.0
        while a < 2 * math.pi - 0.09:
            w = rng.choice((0.06, 0.08, 0.11))
            centre = latitude(h, a0=a + w / 2, a1=a + w / 2, count=2)[0]
            patch = Patch(centre, up=(0, 0, sign))
            tall = rng.choice((0.05, 0.07, 0.09))
            hw = w * math.sqrt(1 - h * h) / 2 - 0.012
            if rng.random() < 0.3:
                decal(bands, patch, ellipse(0, 0, hw, tall / 2, 10), top=1.035, dome=0.008, rings=1)
            else:
                decal(bands, patch, [(-hw, -tall / 2), (hw, -tall / 2), (hw, tall / 2), (-hw, tall / 2)], top=1.035, rings=1)
            a += w + 0.02
    add("Shell", s, (0.12, 0.25, 0.7))
    add("Scarab", beetles, GOLD, smooth=False)
    add("Bands", bands, GOLD, smooth=False)


def leaf_on_path(bm, p, forward, side_sign, length, width, splay=0.6, top=1.03):
    """A laurel leaf growing from p on the sphere, angled off the stem direction."""
    n = p.normalized()
    forward = (forward - n * forward.dot(n)).normalized()
    side = forward.cross(n).normalized() * side_sign
    direction = (forward * math.cos(splay) + side * math.sin(splay)).normalized()
    patch = Patch(n, up=direction)
    decal(bm, patch, lens(length, width, 12), top=top, dome=0.018, rings=2, centre=(0, length * 0.45))


def laurel_ball(add):
    """White marble with a golden laurel wreath, laurel sprigs underneath and a Greek-key band."""
    s, laurel, meander = bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    # The wreath: two halves grow from the back around each side and meet at the front.
    h = 0.55
    for direction in (1, -1):
        stem = latitude(h, a0=math.pi / 2, a1=math.pi / 2 + direction * math.pi * 0.96, count=60)
        ribbon(laurel, stem, 0.028, top=1.02)
        for i in range(2, len(stem) - 1, 3):
            forward = stem[i + 1] - stem[i - 1]
            for side_sign in (1, -1):
                leaf_on_path(laurel, stem[i], forward, side_sign, 0.23, 0.09, top=1.028 + 0.004 * (i % 2))
        leaf_on_path(laurel, stem[-1], stem[-1] - stem[-2], 1, 0.22, 0.09, splay=0.0)
    for k in range(3):
        a = -math.pi / 2 + (k - 1) * 0.07
        ball(laurel, latitude(h - 0.08 + 0.04 * (k % 2), a0=a, a1=a, count=2)[0] * R * 1.025, 0.035, subdivisions=2)
    # Sprigs on the lower half: a short curved stem with leaf pairs and a tip leaf.
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        stem = [latitude(-0.32 - 0.5 * t, a0=a + 0.3 * math.sin(math.pi * t), a1=a + 0.3 * math.sin(math.pi * t), count=2)[0]
                for t in [i / 10 for i in range(11)]]
        ribbon(laurel, stem, 0.03, top=1.02)
        for i in (1, 3, 5, 7, 9):
            for side_sign in (1, -1):
                leaf_on_path(laurel, stem[i], stem[i + 1] - stem[i - 1], side_sign, 0.2, 0.08, splay=0.65,
                             top=1.028 + 0.004 * (side_sign > 0))
        leaf_on_path(laurel, stem[-1], stem[-1] - stem[-2], 1, 0.2, 0.08, splay=0.0)
    # Greek key: rails above and below a continuous meander line, 20 repeats around.
    for rail in (0.165, -0.165):
        ribbon(meander, latitude(rail, 160), 0.035, top=1.03, closed=True)
    repeats, unit_h = 20, 0.075
    unit_a = 2 * math.pi / (repeats * 4)
    key = []
    for r in range(repeats):
        for u, v in ((0, 0), (0, 3), (3, 3), (3, 1), (1, 1), (1, 0)):
            key.append(Vector((r * 4 + u, v)))
    key.append(Vector((repeats * 4, 0)))
    points = []
    for p in resample(key, 1.0)[:-1]:
        a = p.x * unit_a
        hh = (p.y - 1.5) * unit_h
        points.append(latitude(hh, a0=a, a1=a, count=2)[0])
    ribbon(meander, points, 0.032, top=1.028, closed=True)
    add("Shell", s, (0.95, 0.94, 0.9))
    add("Laurel", laurel, GOLD, smooth=False)
    add("Meander", meander, GOLD, smooth=False)


RUNES = {
    "fehu": [[(-0.18, -0.5), (-0.18, 0.5)], [(-0.18, 0.12), (0.24, 0.48)], [(-0.18, -0.16), (0.24, 0.2)]],
    "thurisaz": [[(-0.16, -0.5), (-0.16, 0.5)], [(-0.16, 0.3), (0.2, 0.0), (-0.16, -0.3)]],
    "ansuz": [[(-0.18, -0.5), (-0.18, 0.5)], [(-0.18, 0.5), (0.24, 0.2)], [(-0.18, 0.2), (0.24, -0.1)]],
    "raido": [[(-0.18, -0.5), (-0.18, 0.5)], [(-0.18, 0.5), (0.2, 0.26), (-0.18, 0.02), (0.22, -0.5)]],
    "algiz": [[(0, -0.5), (0, 0.5)], [(-0.3, 0.46), (0, 0.1), (0.3, 0.46)]],
    "sowilo": [[(0.2, 0.5), (-0.2, 0.12), (0.2, -0.12), (-0.2, -0.5)]],
    "tiwaz": [[(0, -0.5), (0, 0.5)], [(-0.3, 0.2), (0, 0.5), (0.3, 0.2)]],
    "othala": [[(0, 0.5), (0.3, 0.15), (-0.3, -0.5)], [(0, 0.5), (-0.3, 0.15), (0.3, -0.5)]],
}


def viking_rune_ball(add):
    """Dark iron bound by three crossing bronze straps with rivets, runes inlaid between them."""
    s, straps, rivets, runes = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    turns = [Matrix(), Matrix.Rotation(math.pi / 2, 4, "X"), Matrix.Rotation(math.pi / 2, 4, "Y")]
    for k, turn in enumerate(turns):
        ribbon(straps, latitude(0.0, 128, turn), 0.17, top=1.035 + 0.006 * k, closed=True)
        for p in latitude(0.0, 16, turn):
            # Skip the spots where two straps cross; those get a boss plate instead.
            if max(abs(p.x), abs(p.y), abs(p.z)) > 0.95:
                continue
            for side in (-0.05, 0.05):
                axis = (turn.to_3x3() @ Vector((0, 0, 1)))
                rivet(rivets, (p + axis * side).normalized(), 0.028, 1.03 + 0.006 * k, 0.035, sides=8)
    for axis in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        for n in (axis, -axis):
            up = Vector((0, 0, 1)) if abs(n.z) < 0.5 else Vector((0, 1, 0))
            patch = Patch(n, up=up, spin=math.pi / 4)
            decal(straps, patch, [(-0.13, -0.13), (0.13, -0.13), (0.13, 0.13), (-0.13, 0.13)], top=1.06, rings=1)
            rivet(rivets, n, 0.06, 1.055, 0.055, sides=12)
    names = list(RUNES)
    for i, (sx, sy, sz) in enumerate(((1, -1, 1), (-1, -1, 1), (-1, 1, 1), (1, 1, 1),
                                      (1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1))):
        patch = Patch(Vector((sx, sy, sz)), up=(0, 0, 1))
        for line in RUNES[names[i]]:
            stroke(runes, patch, [Vector(p) * 0.6 for p in line], 0.065, base=0.985, top=1.014)
    add("Shell", s, (0.2, 0.21, 0.23))
    add("Bands", straps, (0.72, 0.45, 0.2), smooth=False)
    add("Rivets", rivets, (0.85, 0.6, 0.3))
    add("Runes", runes, (0.35, 0.85, 1.0), smooth=False)


def sakura(bm, patch, size, top=1.04, base=0.985):
    """A five-petal cherry blossom centred in the patch."""
    for k in range(5):
        a = 2 * math.pi * k / 5
        c, s = math.cos(a), math.sin(a)
        spun = [Vector((p.x * c - (p.y + size * 0.175) * s, p.x * s + (p.y + size * 0.175) * c)) for p in petal_outline(size)]
        decal(bm, patch, spun, base=base, top=top, dome=size * 0.075, rings=2, centre=Vector((-s, c)) * size * 0.65)


def samurai_ball(add):
    """Red lacquer with black lacing bands, a gold sakura mon on two sides and drifting petals."""
    s, bands, crest, petals = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    for h in (0.45, 0.8, -0.45, -0.8):
        ribbon(bands, latitude(h, 120), 0.075, top=1.032, closed=True)
    # Cross-laced cords between the two bands of each half.
    for sign in (1, -1):
        for k in range(14):
            a = 2 * math.pi * k / 14
            w = 0.16
            for j, (a0, a1) in enumerate(((a - w, a + w), (a + w, a - w))):
                line = [latitude(sign * (0.45 + 0.35 * t), a0=a0 + (a1 - a0) * t, a1=a0 + (a1 - a0) * t, count=2)[0]
                        for t in [i / 8 for i in range(9)]]
                ribbon(bands, line, 0.04, top=1.02 + 0.005 * j)
    for normal in (FRONT, -FRONT):
        patch = Patch(normal)
        stroke(crest, patch, ellipse(0, 0, 0.29, 0.29, 48), 0.05, top=1.045, closed=True, step=0.05)
        sakura(crest, patch, 0.2, top=1.04)
        decal(crest, patch, ellipse(0, 0, 0.055, 0.055, 14), top=1.06, dome=0.01)
    # Drifting blossoms and loose petals, kept off the crests and the bands.
    rng = random.Random(9)
    for i, n in enumerate(fibonacci_points(40, seed=0.3)):
        n = (n + Vector((rng.uniform(-.15, .15), rng.uniform(-.15, .15), rng.uniform(-.15, .15)))).normalized()
        if n.angle(FRONT) < 0.5 or n.angle(-FRONT) < 0.5:
            continue
        if any(abs(n.z - h) < 0.11 for h in (0.45, 0.8, -0.45, -0.8)):
            continue
        patch = Patch(n, spin=rng.uniform(0, 2 * math.pi))
        if i % 3 == 0:
            sakura(petals, patch, 0.1, top=1.03, base=0.99)
        else:
            size = rng.uniform(0.13, 0.17)
            decal(petals, patch, resample(petal_outline(size), 0.03, closed=True),
                  base=0.99, top=1.034, dome=0.012, centre=(0, size * 0.45))
    add("Shell", s, (0.78, 0.1, 0.1))
    add("Bands", bands, (0.08, 0.07, 0.08), smooth=False)
    add("Crest", crest, GOLD, smooth=False)
    add("Petals", petals, (1.0, 0.72, 0.82), smooth=False)


def knight_ball(add):
    """A steel great-helm: eye slit and breathing holes, gold trim and ridge, red plume."""
    s, visor, trim, plume = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    front_a = -math.pi / 2
    span = math.radians(56)
    slit_h, slit_w = 0.1, 0.1
    ribbon(visor, latitude(slit_h, 40, a0=front_a - span, a1=front_a + span), slit_w, base=0.985, top=1.008)
    for row, hh in enumerate((-0.12, -0.24, -0.36)):
        for k in range(3 - (row == 2)):
            for side in (-1, 1):
                a = front_a + side * (0.2 + 0.12 * k + 0.06 * (row % 2))
                patch = Patch(latitude(hh, a0=a, a1=a, count=2)[0])
                decal(visor, patch, ellipse(0, 0, 0.032, 0.032, 10), top=1.008, rings=1)
    # Gold frame around the slit.
    for edge in (slit_h + 0.078, slit_h - 0.078):
        ribbon(trim, latitude(edge, 44, a0=front_a - span - 0.05, a1=front_a + span + 0.05), 0.05, top=1.045)
    for side in (-1, 1):
        a = front_a + side * (span + 0.05)
        end = [latitude(slit_h + t, a0=a, a1=a, count=2)[0] for t in (-0.1, 0.0, 0.1)]
        ribbon(trim, end, 0.05, top=1.044)
    # The centre ridge runs from the chin over the crown to the back, broken by the slit.
    def meridian(a0, a1, count):
        return [Vector((0, -math.cos(a), math.sin(a))) for a in [a0 + (a1 - a0) * i / count for i in range(count + 1)]]

    ribbon(trim, meridian(math.asin(-0.85), math.asin(slit_h - 0.1), 16), 0.07, top=1.06)
    ribbon(trim, meridian(math.asin(slit_h + 0.1), math.pi - math.asin(-0.6), 60), 0.07, top=1.06)
    ribbon(trim, latitude(-0.55, 120), 0.09, top=1.04, closed=True)
    for k in range(16):
        a = 2 * math.pi * (k + 0.5) / 16
        rivet(trim, latitude(-0.55, a0=a, a1=a, count=2)[0], 0.03, 1.035, 0.035)
    # Plume holder on the crown, tipped back a little, and a fan of chunky feathers.
    holder_n = Vector((0, 0.15, 1)).normalized()
    cylinder(trim, holder_n * 0.97, holder_n, 0.15, 0.085, segments=14)
    cylinder(trim, holder_n * 1.1, holder_n, 0.03, 0.1, segments=14)
    rng = random.Random(6)
    for spread in (-0.09, 0.0, 0.09):
        outer = spread != 0.0
        for k in range(5):
            start = holder_n * 1.1 + Vector((spread * 0.6, 0, 0))
            theta = math.radians((6 if not outer else 16) + k * 17 + rng.uniform(-3, 3))
            end = Vector((spread * 2.5, math.sin(theta), math.cos(theta))) * ((1.22 if not outer else 1.16) - 0.01 * k)
            control = (start + end) / 2 + Vector((0, -0.04, 0.1))
            ts = [i / 12 for i in range(13)]
            points = [start * (1 - t) ** 2 + control * 2 * t * (1 - t) + end * t * t for t in ts]
            # Plump in the middle and rounded at the tip, like a cartoon feather.
            fat = 0.1 if outer else 0.115
            sweep_radii(plume, points, [0.05 + (fat - 0.05) * math.sin(math.pi * t ** 0.75) - 0.02 * t for t in ts], segments=10)
    add("Shell", s, (0.78, 0.8, 0.84))
    add("Visor", visor, (0.08, 0.08, 0.1), smooth=False)
    add("Trim", trim, GOLD, smooth=False)
    add("Plume", plume, (0.85, 0.1, 0.12))


def sheriff_star(bm, normal):
    patch = Patch(normal)
    outline = []
    for i in range(12):
        a = math.pi / 2 + 2 * math.pi * i / 12
        r = 0.4 if i % 2 == 0 else 0.21
        outline.append(Vector((math.cos(a) * r, math.sin(a) * r)))
    decal(bm, patch, resample(outline, 0.07, closed=True), top=1.035, dome=0.025, rings=3, centre=(0, 0))
    for i in range(6):
        a = math.pi / 2 + 2 * math.pi * i / 6
        ball(bm, patch.at(math.cos(a) * 0.42, math.sin(a) * 0.42, 1.03), 0.058, subdivisions=2)
    stroke(bm, patch, ellipse(0, 0, 0.14, 0.14, 32), 0.03, top=1.072, closed=True, step=0.05)
    decal(bm, patch, ellipse(0, 0, 0.06, 0.06, 14), top=1.07, dome=0.01)


def sheriff_star_ball(add):
    """Tan leather baseball with red stitches and a gold sheriff star on each side."""
    s, st, star = bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    stitches(st)
    # The two widest leather panel ends face these opposite directions, clear of the seam.
    sheriff_star(star, Vector((0.707, -0.707, 0)))
    sheriff_star(star, Vector((-0.707, 0.707, 0)))
    add("Shell", s, (0.8, 0.62, 0.4))
    add("Stitches", st, (0.75, 0.15, 0.12))
    add("Star", star, GOLD, smooth=False)


def gear(bm, normal, radius, spin=0.0, top=1.05):
    """A copper gear lying on the sphere: toothed rim, spokes and a hub."""
    patch = Patch(normal, spin=spin)
    teeth = max(8, round(radius * 40))
    root = radius - 0.065
    outer, inner = [], []
    rim_in = root - 0.075
    for t in range(teeth):
        for frac, r in ((0.0, root), (0.18, radius), (0.47, radius), (0.65, root), (0.82, root)):
            a = 2 * math.pi * (t + frac) / teeth
            outer.append(Vector((math.cos(a) * r, math.sin(a) * r)))
            inner.append(Vector((math.cos(a) * rim_in, math.sin(a) * rim_in)))
    if radius >= 0.27:
        flat_ring(bm, patch, outer, inner, base=0.98, top=top)
        spokes = 5 if radius > 0.35 else 4
        for k in range(spokes):
            a = 2 * math.pi * k / spokes
            d = Vector((math.cos(a), math.sin(a)))
            stroke(bm, patch, [d * 0.05, d * (rim_in + 0.02)], 0.055, base=0.98, top=top - 0.008)
        decal(bm, patch, ellipse(0, 0, 0.085, 0.085, 16), base=0.98, top=top + 0.008)
    else:
        decal(bm, patch, outer, base=0.98, top=top, centre=(0, 0))
        decal(bm, patch, ellipse(0, 0, root * 0.45, root * 0.45, 14), base=0.98, top=top + 0.012)
    decal(bm, patch, ellipse(0, 0, 0.035, 0.035, 10), base=0.98, top=top + 0.025)


CLOCKWORK_GEARS = [((0.0, 1.0, 0.1), 0.46), ((0.0, -0.15, 1.0), 0.36), ((1.0, 0.05, -0.3), 0.35),
                   ((-1.0, 0.15, 0.25), 0.34), ((0.15, -0.25, -1.0), 0.32), ((0.62, -0.55, 0.55), 0.22),
                   ((-0.6, -0.5, -0.6), 0.23), ((0.65, 0.6, 0.6), 0.24), ((-0.6, 0.72, -0.45), 0.25),
                   ((-0.62, -0.62, 0.5), 0.19), ((0.68, -0.48, -0.6), 0.19), ((0.7, 0.7, -0.35), 0.17),
                   ((-0.65, 0.6, 0.55), 0.17)]


def clockwork_ball(add):
    """Brass with copper gears, a clock dial on the front and glowing slits between the gears."""
    s, gears, dial, glow = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    rng = random.Random(23)
    keep_out = [(FRONT, math.atan(0.47))]
    for k, (direction, radius) in enumerate(CLOCKWORK_GEARS):
        n = Vector(direction).normalized()
        gear(gears, n, radius, spin=rng.uniform(0, 1), top=1.045 + 0.01 * (k % 2))
        keep_out.append((n, math.atan(radius) + 0.03))
    # The dial: a cream face with copper bezel, hour ticks and hands (ticks and hands are part
    # of the Gears mesh so they contrast with the face).
    patch = Patch(FRONT)
    decal(dial, patch, ellipse(0, 0, 0.42, 0.42, 40), top=1.022, dome=0.008, rings=2)
    stroke(gears, patch, ellipse(0, 0, 0.44, 0.44, 48), 0.05, top=1.05, closed=True, step=0.05)
    for k in range(12):
        a = math.pi / 2 - 2 * math.pi * k / 12
        d = Vector((math.cos(a), math.sin(a)))
        big = k % 3 == 0
        stroke(gears, patch, [d * (0.29 if big else 0.32), d * 0.38], 0.05 if big else 0.028, top=1.04)
    stroke(gears, patch, [Vector((0, 0)), Vector((math.cos(math.radians(30)), math.sin(math.radians(30)))) * 0.2], 0.045, top=1.045)
    stroke(gears, patch, [Vector((0, 0)), Vector((math.cos(math.radians(110)), math.sin(math.radians(110)))) * 0.3], 0.032, top=1.05)
    decal(gears, patch, ellipse(0, 0, 0.045, 0.045, 12), top=1.06)
    # Glowing vent slits: short parallel arcs in the gaps, kept clear of gears and the dial.
    placed = 0
    for n in fibonacci_points(220, seed=1.9):
        if placed >= 16:
            break
        heading = n.orthogonal().normalized()
        heading = (heading * math.cos(rng.uniform(0, 3)) + n.cross(heading) * math.sin(rng.uniform(0, 3))).normalized()
        side = heading.cross(n).normalized()
        lines = []
        for offset in (-0.06, 0.0, 0.06):
            lines.append([(n + side * offset + heading * t).normalized() for t in (-0.13, -0.065, 0.0, 0.065, 0.13)])
        points = [p for line in lines for p in line]
        if any(p.angle(c) < r + 0.04 for p in points for c, r in keep_out):
            continue
        for line in lines:
            ribbon(glow, line, 0.026, base=0.985, top=1.006)
        keep_out.append((n, 0.2))
        placed += 1
    add("Shell", s, (0.82, 0.62, 0.25))
    add("Gears", gears, (0.72, 0.38, 0.2), smooth=False)
    add("Dial", dial, (0.97, 0.93, 0.8), smooth=False)
    add("Glow", glow, (0.5, 0.95, 1.0), smooth=False)
    return placed


def orbit_ring(bm, turn, inner=1.08, outer=1.2, thickness=0.085, segments=96, struts=4, strut_phase=0.0):
    """A flat brass ring round the shell, held on by short struts."""
    profile = [(inner, -thickness / 2), (outer, -thickness / 2), (outer, thickness / 2), (inner, thickness / 2)]
    lathe(bm, profile + [profile[0]], segments, transform=turn)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    for k in range(struts):
        a = 2 * math.pi * k / struts + strut_phase
        d = turn.to_3x3() @ Vector((math.cos(a), math.sin(a), 0))
        tube(bm, d * R * 0.97, d * (inner + 0.02), 0.03, segments=8)
        ball(bm, d * R * 1.0, 0.05, subdivisions=2)


def chrono_orb(add):
    """A glass orb round a glowing core, circled by two brass rings, one marked like a clock."""
    s, core, ring1, ring2, numerals = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    ball(core, (0, 0, 0), R * 0.6, subdivisions=3)
    turn1 = Matrix.Rotation(math.radians(22), 4, "X")
    turn2 = Matrix.Rotation(math.radians(35), 4, "Z") @ Matrix.Rotation(math.radians(68), 4, "Y")
    orbit_ring(ring1, turn1, strut_phase=math.pi / 4)
    orbit_ring(ring2, turn2, strut_phase=0.3)
    for k in range(12):
        a = 2 * math.pi * k / 12
        big = k % 3 == 0
        # Hour blocks clamp through the ring and stand proud of both faces, like bezel marks.
        radial, across, deep = (0.13, 0.065, 0.2) if big else (0.09, 0.04, 0.16)
        d = Vector((math.cos(a), math.sin(a), 0))
        rotation = Matrix.Rotation(a, 4, "Z")
        box(numerals, turn1 @ (d * 1.14), (radial, across, deep), rotation=turn1 @ rotation)
    add("Shell", s, (0.75, 0.9, 1.0))
    add("Core", core, (0.55, 0.95, 1.0))
    add("Ring1", ring1, (0.85, 0.65, 0.28), smooth=False)
    add("Ring2", ring2, (0.85, 0.65, 0.28), smooth=False)
    add("Numerals", numerals, (0.9, 0.72, 0.3), smooth=False)


BALLS = ["dino_egg_ball", "stone_ball", "scarab_ball", "laurel_ball", "viking_rune_ball",
         "samurai_ball", "knight_ball", "sheriff_star_ball", "clockwork_ball", "chrono_orb"]


objects = build(begin(COLLECTION))
if globals().get("EXPORT", True):
    export(objects, EXPORT_PATH)
