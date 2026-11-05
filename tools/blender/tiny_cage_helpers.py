# Shared pieces for World 4's (Tiny Town) Training Ground cages. Load inside Blender with:
#   exec(open(TINY_CAGE_HELPERS, encoding="utf-8").read())
# It loads cage_helpers.py (layout, limits, the 1/4-scale export) and the standard cage's builders
# from batting_cage.py without running its build, so each Tiny Town cage starts from the standard
# frame, nets, screen, plate, bucket and lights and adds its own toy-sized scenery round them.
# standard(coll, prefix, ...) renames every standard mesh "<prefix><name>" (e.g. SandCageFrame), so
# TrainingCageStyles can style each cage's parts on their own.
BATTING_CAGE = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\batting_cage.py"
_cage_source = open(BATTING_CAGE, encoding="utf-8").read()
_cage_marker = "\nbuild_and_export(globals()"
assert _cage_marker in _cage_source, "batting_cage.py layout changed; update tiny_cage_helpers.py"
exec(_cage_source.rpartition(_cage_marker)[0])
import random

TOY_RED = (0.9, 0.18, 0.16)
TOY_YELLOW = (1.0, 0.8, 0.12)
TOY_BLUE = (0.16, 0.42, 0.9)
TOY_GREEN = (0.22, 0.7, 0.32)
TOY_WOOD = (0.82, 0.62, 0.38)
CREAMY = (0.97, 0.95, 0.9)

STANDARD = {
    "frame": lambda coll: [build_frame(coll)],
    "pads": lambda coll: [build_pads(coll)],
    "nets": build_nets,
    "machine": build_machine,
    "screen": build_screen,
    "plate": build_plate_bucket_balls,
    "lights": build_lights,
}


def standard(coll, prefix, parts=("frame", "pads", "nets", "machine", "screen", "plate", "lights")):
    """The standard cage's pieces, each mesh renamed <prefix><name>."""
    objects = []
    for key in parts:
        for obj in STANDARD[key](coll):
            name = prefix + obj.name.split(".")[0]
            obj.name = name
            obj.data.name = name
            objects.append(obj)
    return objects


def ellipse_points(cx, cy, rx, ry, a0, a1, count):
    return [Vector((cx + rx * math.cos(a0 + (a1 - a0) * i / (count - 1)), cy + ry * math.sin(a0 + (a1 - a0) * i / (count - 1)), 0))
            for i in range(count)]


def profile_along(bm, points, profile, closed=False):
    """Loft a 2D profile ((outward, up) points, any closed outline) along a flat path round a centre:
    'outward' is the path's horizontal normal (to the right of travel). Open paths are capped."""
    n = len(points)
    sections = []
    for i, p in enumerate(points):
        if closed:
            ahead, behind = points[(i + 1) % n], points[i - 1]
        else:
            ahead, behind = points[min(i + 1, n - 1)], points[max(i - 1, 0)]
        t = (ahead - behind).normalized()
        out = Vector((t.y, -t.x, 0))
        sections.append([p + out * u + Vector((0, 0, v)) for u, v in profile])
    rings = [[bm.verts.new(q) for q in s] for s in sections]
    m = len(profile)
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for a, b in pairs:
        for k in range(m):
            j = (k + 1) % m
            bm.faces.new((a[k], a[j], b[j], b[k]))
    if not closed:
        bm.faces.new(tuple(reversed(rings[0])))
        bm.faces.new(tuple(rings[-1]))


def crenellations(bm, start, end, height, thickness, merlon=1.6, gap=1.2, depth=1.2):
    """Square merlons along a wall top from start to end (a toy fort's battlements)."""
    start, end = Vector(start), Vector(end)
    d = end - start
    length = d.length
    t = d.normalized()
    angle = math.atan2(t.y, t.x)
    count = max(1, int((length + gap) / (merlon + gap)))
    used = count * merlon + (count - 1) * gap
    s = (length - used) / 2
    for k in range(count):
        c = start + t * (s + merlon / 2 + k * (merlon + gap))
        box(bm, (c.x, c.y, height + depth / 2), (merlon, thickness, depth), Matrix.Rotation(angle, 4, "Z"))


def pine(bm, base, height, radius):
    """A little snowy-cartoon pine: three stacked cones."""
    base = Vector(base)
    for k, (z, r, h) in enumerate(((0.25, 1.0, 0.5), (0.55, 0.78, 0.4), (0.8, 0.52, 0.32))):
        lathe(bm, [(0, base.z + height * z), (radius * r, base.z + height * z), (0, base.z + height * (z + h))], 12,
              transform=Matrix.Translation((base.x, base.y, 0)))


def finish_all(coll, pieces):
    """pieces: [(name, bm, rgb, mode)] with mode "hard", "smooth" or "soft"."""
    objects = []
    for name, bm, rgb, mode in pieces:
        if mode == "soft":
            objects.append(soft(coll, name, bm, rgb))
        else:
            objects.append(finish(coll, name, bm, rgb, hard=(mode == "hard")))
    return objects


def squircle_points(cx, cy, rx, ry, a0, a1, count, p=8.0):
    """Points along a superellipse (a rounded rectangle) from angle a0 to a1."""
    points = []
    for i in range(count):
        a = a0 + (a1 - a0) * i / (count - 1)
        c, s = math.cos(a), math.sin(a)
        points.append(Vector((cx + rx * math.copysign(abs(c) ** (2 / p), c), cy + ry * math.copysign(abs(s) ** (2 / p), s), 0)))
    return points

