# World portal: a cartoony time-travel portal for the World hubs. A chunky octagonal brass frame
# of eight bevelled segments joined by riveted iron corner bands, twelve clock-bezel markers on
# its front face, a cyan vortex disc with four-fold spiral arms in the opening, a gold alarm-clock
# face (cream dial, hour ticks, crown and ring, two bells) perched on the top segment, a glowing
# hourglass "chrono lamp" on a bracket at each side, two clockwork gears over the lower-left and
# upper-right corners, and a low stepped stone plinth with brass trim. Also builds HubGear, a
# large standalone gear (about 10 units across) placed off to the side at x = 30.
# Run inside Blender (e.g. via MCP). Mesh names are what the game looks up for colors, materials
# and motion:
#   PortalFrame, PortalBands, PortalRivets, PortalMarkers, PortalBase, PortalBaseTrim,
#   PortalClock, PortalClockRim, PortalHourHand, PortalMinuteHand, PortalGearA, PortalGearB,
#   PortalLampFrames, PortalLampGlow, PortalVortex, PortalSwirl, HubGear
# The spinning meshes (hands, gears, swirl) are built so their bounding-box centre is their axle,
# because Roblox centres a MeshPart on its bounding box: each hand has a counterweight tail
# reaching as far back as its tip reaches forward, and gears and the swirl are symmetric under a
# half turn. Hands are exported pointing at 12 (minute) and 3 (hour).
# Orientation: +Z up, the portal faces -Y, width along X, plinth bottom at z = 0 centred on
# x = y = 0. 1 unit = 1 stud; the whole portal stays under 19 units so Roblox's 100x FBX import
# stays below its 2048-stud part limit (the game scales the model up to its final height).
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

HELPERS = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\prop_helpers.py"
exec(open(HELPERS, encoding="utf-8").read())

COLLECTION = "WorldPortal"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\WorldPortal.fbx"
MAX_TRIANGLES = 18000          # per mesh, under Roblox's per-MeshPart limit
MAX_EXTENT = 19.0              # largest portal dimension (100x import must stay under 2048 studs)

BRASS = (0.88, 0.63, 0.25)
GOLD = (1.0, 0.8, 0.3)
IRON = (0.2, 0.2, 0.24)
STONE = (0.27, 0.26, 0.33)
CREAM = (0.98, 0.94, 0.82)
COPPER = (0.85, 0.52, 0.26)
HAND = (0.14, 0.12, 0.14)
CYAN = (0.5, 1.0, 0.97)
TEAL = (0.04, 0.5, 0.62)

# Layout (studs).
PLINTH_TOP = 1.0
CENTER_Z = 7.6                 # height of the opening's centre (frame bottom just inside the plinth)
INNER, OUTER = 5.0, 6.65       # frame apothems: centre to the middle of a flat side
LIP = 0.34                     # raised beads along the inner and outer edges of each segment's faces
DEPTH = 1.8                    # frame thickness along Y
FRONT_Y = -DEPTH / 2
BAND_Y = DEPTH / 2 + 0.2       # iron bands stand proud of the beads
VORTEX_R = 5.5                 # just past the opening's corners (5.41) so its edge tucks behind the frame
CLOCK = Vector((0.0, -0.6, 15.75))     # clock axle (case centre); the dial faces -Y
GEAR_BACK_Y = -BAND_Y - 0.13   # gears sit just in front of the bands' rivets
GEAR_A = (math.radians(225), 6.25, 1.85, 10, 6)   # angle, distance from the opening centre, radius, teeth, spokes
GEAR_B = (math.radians(45), 6.25, 1.45, 8, 4)
LAMP_X, LAMP_SCALE = 7.65, 1.2
HUB_GEAR_CENTER = Vector((30.0, 0.0, 0.0))
EIGHTH = math.pi / 4
FRONT = Matrix.Rotation(math.radians(90), 4, "X")   # local +Z -> world -Y, local +Y -> world +Z


# ---------- geometry ----------

def lathe_y(bm, profile, segments, center):
    """Revolve (radius, forward) points around an axis along Y through center; forward is toward -Y.
    Ring vertices start on +X, so with segments divisible by 4 they hit +-X and +-Z exactly."""
    return lathe(bm, profile, segments, Matrix.Translation(Vector(center)) @ FRONT)


def box(bm, center, size, rotation=Matrix()):
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(Vector(center)) @ rotation @ Matrix.Diagonal((*size, 1.0)))


def cylinder(bm, base, direction, length, radius, segments=16):
    lathe(bm, [(0, 0), (radius, 0), (radius, length), (0, length)], segments,
          Matrix.Translation(Vector(base)) @ align_z(Vector(direction)))


def ball(bm, center, radius, subdivisions=2):
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius, matrix=Matrix.Translation(Vector(center)))


def torus(bm, center, axis, major, minor, segments=24, minor_segments=8):
    """A closed ring around axis through center."""
    turn = Matrix.Translation(Vector(center)) @ align_z(Vector(axis))
    rings = []
    for i in range(segments):
        a = 2 * math.pi * i / segments
        out = Vector((math.cos(a), math.sin(a), 0))
        rings.append([bm.verts.new(turn @ (out * (major + minor * math.cos(b)) + Vector((0, 0, minor * math.sin(b)))))
                      for b in [2 * math.pi * j / minor_segments for j in range(minor_segments)]])
    for i in range(segments):
        a, b = rings[i], rings[(i + 1) % segments]
        for j in range(minor_segments):
            k = (j + 1) % minor_segments
            bm.faces.new((a[j], b[j], b[k], a[k]))


def strip_slab(bm, inner, outer, y_front, y_back, loop=False):
    """Extrude the strip between two matching point chains (their x and z are used) along Y.
    Open strips get end caps; loop closes the strip into a ring."""
    n = len(inner)
    fi = [bm.verts.new((p.x, y_front, p.z)) for p in inner]
    fo = [bm.verts.new((p.x, y_front, p.z)) for p in outer]
    bi = [bm.verts.new((p.x, y_back, p.z)) for p in inner]
    bo = [bm.verts.new((p.x, y_back, p.z)) for p in outer]
    for i in range(n if loop else n - 1):
        j = (i + 1) % n
        bm.faces.new((fi[i], fo[i], fo[j], fi[j]))
        bm.faces.new((bi[j], bo[j], bo[i], bi[i]))
        bm.faces.new((fo[i], bo[i], bo[j], fo[j]))
        bm.faces.new((fi[j], bi[j], bi[i], fi[i]))
    if not loop:
        bm.faces.new((fi[0], bi[0], bo[0], fo[0]))
        bm.faces.new((fo[-1], bo[-1], bi[-1], fi[-1]))


def octagon_point(apothem, angle):
    """Point on the frame's octagon (flat sides centred at multiples of 45 degrees) in the XZ plane."""
    flat = round(angle / EIGHTH) * EIGHTH
    r = apothem / math.cos(angle - flat)
    return Vector((r * math.cos(angle), 0.0, CENTER_Z + r * math.sin(angle)))


def flat_tangent(theta):
    return Vector((-math.sin(theta), 0.0, math.cos(theta)))


def gear_depth(radius):
    return radius * 0.26


def gear(bm, center, radius, teeth, spokes, axle_to=None):
    """A chunky gear (toothed rim, spokes, hub) on an axle along Y through center. Teeth and spokes
    are even in number, so it is symmetric under a half turn and its bounding-box centre is the axle
    (the hub cap only adds depth along the axle). axle_to extends the axle back to that y."""
    c = Vector(center)
    depth = gear_depth(radius)
    tip, root, rim_in = radius, radius * 0.8, radius * 0.58
    pitch = 2 * math.pi / teeth
    outer, inner = [], []
    for i in range(teeth):
        for frac, r in ((-0.5, root), (-0.28, root), (-0.18, tip), (0.18, tip), (0.28, root)):
            a = (i + frac) * pitch
            d = Vector((math.cos(a), 0, math.sin(a)))
            outer.append(c + d * r)
            inner.append(c + d * rim_in)
    strip_slab(bm, inner, outer, c.y - depth / 2, c.y + depth / 2, loop=True)
    hub = radius * 0.32
    lathe_y(bm, [(0, -depth * 0.62), (hub, -depth * 0.62), (hub, depth * 0.6), (hub * 0.8, depth * 0.68),
                 (hub * 0.5, depth * 0.7), (hub * 0.42, depth * 0.8), (hub * 0.3, depth * 0.86), (0, depth * 0.88)], 24, c)
    r0, r1 = hub * 0.8, rim_in + radius * 0.04
    for s in range(spokes):
        a = 2 * math.pi * s / spokes
        d = Vector((math.cos(a), 0, math.sin(a)))
        box(bm, c + d * (r0 + r1) / 2, (r1 - r0, depth * 0.7, radius * 0.22), Matrix.Rotation(-a, 4, "Y"))
    if axle_to is not None:
        cylinder(bm, c, (0, 1, 0), axle_to - c.y, hub * 0.45)
    return c


def hand(bm, length, samples, hub, tail, hand_f, hub_f, upright):
    """A clock hand reaching exactly `length` forward (a pointed tip) and back (a round counterweight
    tail of radius `tail`), lying flat in front of the dial. samples are (along, half-width) pairs
    along the hand; *_f are (back, front) forward distances from the clock axle plane.
    upright points it at 12 (along +Z), otherwise at 3 (along +X)."""
    def place(along, across):
        if upright:
            return Vector((CLOCK.x + across, 0, CLOCK.z + along))
        return Vector((CLOCK.x + along, 0, CLOCK.z + across))
    strip_slab(bm, [place(v, -w) for v, w in samples], [place(v, w) for v, w in samples],
               CLOCK.y - hand_f[1], CLOCK.y - hand_f[0])
    lathe_y(bm, [(0, hub_f[0]), (hub, hub_f[0]), (hub, hub_f[1]), (0, hub_f[1])], 16, CLOCK)
    tail_center = place(-(length - tail), 0)
    tail_center.y = CLOCK.y
    lathe_y(bm, [(0, hand_f[0] - 0.005), (tail, hand_f[0] - 0.005), (tail, hand_f[1] + 0.005), (0, hand_f[1] + 0.005)], 16, tail_center)


# ---------- parts ----------

def build_frame(frame, bands, rivets, markers):
    # Eight segments with a small gap at each corner joint; the iron bands wrap the joints. Rounded
    # beads along the inner and outer edges of the front and back faces leave a bezel channel between.
    gap = 0.05
    for k in range(8):
        theta = k * EIGHTH
        t = flat_tangent(theta)
        a0, a1 = theta - EIGHTH / 2, theta + EIGHTH / 2

        def chain(apothem):
            return [octagon_point(apothem, a0) + t * gap, octagon_point(apothem, a1) - t * gap]
        strip_slab(frame, chain(INNER), chain(OUTER), FRONT_Y, -FRONT_Y)
        for y0, y1 in ((FRONT_Y - 0.13, FRONT_Y + 0.12), (-FRONT_Y - 0.12, -FRONT_Y + 0.13)):
            strip_slab(frame, chain(INNER), chain(INNER + LIP), y0, y1)
            strip_slab(frame, chain(OUTER - LIP), chain(OUTER), y0, y1)
    for k in range(8):
        phi = k * EIGHTH + EIGHTH / 2
        before, after = flat_tangent(phi - EIGHTH / 2), flat_tangent(phi + EIGHTH / 2)
        cin, cout = octagon_point(INNER - 0.1, phi), octagon_point(OUTER + 0.1, phi)
        w = 0.34
        strip_slab(bands, [cin - before * w, cin, cin + after * w], [cout - before * w, cout, cout + after * w],
                   -BAND_Y, BAND_Y)
        for f in (0.24, 0.76):
            p = cin.lerp(cout, f)
            for y in (-BAND_Y, BAND_Y):
                blob(rivets, Vector((p.x, y, p.z)), Vector((0.16, 0.09, 0.16)), subdivisions=2)
    # Twelve clock-bezel markers in the front channel: double bars at 12, 3, 6 and 9.
    mid = (INNER + OUTER) / 2
    for i in range(12):
        alpha = math.pi / 2 - i * math.pi / 6
        p = octagon_point(mid, alpha)
        across = flat_tangent(alpha)
        bars = [(-0.16, 0.8, 0.2), (0.16, 0.8, 0.2)] if i % 3 == 0 else [(0.0, 0.62, 0.24)]
        for offset, length, width in bars:
            box(markers, Vector((p.x, FRONT_Y - 0.05, p.z)) + across * offset, (length, 0.16, width),
                Matrix.Rotation(-alpha, 4, "Y"))


def build_base(base, trim):
    steps = [(7.6, 1.75, 0.0, 0.55), (6.2, 1.4, 0.55, PLINTH_TOP)]
    for hx, hy, z0, z1 in steps:
        box(base, (0, 0, (z0 + z1) / 2), (2 * hx, 2 * hy, z1 - z0))
        zt = z1 - 0.1
        for y in (-hy, hy):
            box(trim, (0, y, zt), (2 * hx + 0.1, 0.1, 0.15))
        for x in (-hx, hx):
            box(trim, (x, 0, zt), (0.1, 2 * hy + 0.1, 0.15))
    hx, hy, _, top = steps[0]
    for x in (-hx + 0.3, hx - 0.3):
        for y in (-hy + 0.3, hy - 0.3):
            box(trim, (x, y, (top + 0.14) / 2), (0.72, 0.72, top + 0.14))


def build_clock(face, rim, hour, minute):
    # A gold case (a cup behind the dial with a raised bezel lip) and the cream dial inside it.
    lathe_y(rim, [(0, -0.75), (1.45, -0.75), (1.88, -0.66), (2.02, -0.42), (2.04, 0.42), (2.0, 0.7), (1.9, 0.84),
                  (1.74, 0.84), (1.68, 0.62), (0, 0.62)], 48, CLOCK)
    lathe_y(face, [(0, 0.58), (1.69, 0.58), (1.69, 0.7), (0, 0.7)], 48, CLOCK)
    lathe_y(rim, [(0, 0.66), (0.09, 0.66), (0.09, 0.8), (0, 0.8)], 12, CLOCK)    # axle pin under the hands' hubs
    for i in range(12):
        alpha = math.pi / 2 - i * math.pi / 6
        length, width = (0.4, 0.16) if i % 3 == 0 else (0.24, 0.09)
        r = 1.52 - length / 2
        box(rim, CLOCK + Vector((math.cos(alpha) * r, -0.73, math.sin(alpha) * r)), (length, 0.1, width),
            Matrix.Rotation(-alpha, 4, "Y"))
    # Winding crown: a stem, a knurled knob and a ring on top.
    lathe(rim, [(0, 1.9), (0.2, 1.9), (0.2, 2.16), (0, 2.16)], 16, Matrix.Translation(CLOCK))
    start = len(rim.verts)
    lathe(rim, [(0, 2.1), (0.3, 2.1), (0.36, 2.18), (0.36, 2.38), (0.3, 2.46), (0, 2.46)], 20, Matrix.Translation(CLOCK))
    rim.verts.ensure_lookup_table()
    for v in rim.verts[start:]:
        d = Vector((v.co.x - CLOCK.x, v.co.y - CLOCK.y, 0))
        if d.length > 0.33 and round(math.atan2(d.y, d.x) / (2 * math.pi / 20)) % 2:
            v.co.x = CLOCK.x + d.x * 0.85
            v.co.y = CLOCK.y + d.y * 0.85
    torus(rim, CLOCK + Vector((0, 0, 2.63)), (0, 1, 0), 0.22, 0.07, segments=24, minor_segments=8)
    # Two alarm bells with flared lips, standing clear of the case on short posts.
    for side in (-1, 1):
        d = Vector((side * math.sin(math.radians(48)), 0, math.cos(math.radians(48))))
        cylinder(rim, CLOCK + d * 1.9, d, 0.48, 0.1, segments=10)
        lathe(rim, [(0, 0.1), (0.6, 0.03), (0.76, 0.0), (0.78, 0.07), (0.64, 0.2), (0.57, 0.45), (0.47, 0.7), (0.27, 0.86), (0, 0.9)],
              24, Matrix.Translation(CLOCK + d * 2.3) @ align_z(d))
        ball(rim, CLOCK + d * 3.22, 0.12, subdivisions=2)
    # Thin counterweight tails keep each hand's bounding box centred on the axle without
    # stealing attention from the pointer.
    hand(minute, 1.42, [(-1.3, 0.035), (-0.1, 0.05), (0.14, 0.09), (0.98, 0.075), (1.0, 0.18), (1.42, 0.006)],
         hub=0.2, tail=0.13, hand_f=(0.86, 0.9), hub_f=(0.85, 0.94), upright=True)
    lathe_y(minute, [(0, 0.94), (0.13, 0.94), (0.1, 0.98), (0, 1.0)], 16, CLOCK)
    hand(hour, 0.98, [(-0.86, 0.04), (-0.1, 0.06), (0.15, 0.12), (0.54, 0.1), (0.56, 0.23), (0.98, 0.006)],
         hub=0.25, tail=0.13, hand_f=(0.78, 0.82), hub_f=(0.77, 0.84), upright=False)


def gear_center(spec):
    angle, distance, radius = spec[:3]
    return Vector((math.cos(angle) * distance, GEAR_BACK_Y - gear_depth(radius) / 2, CENTER_Z + math.sin(angle) * distance))


def build_lamps(frames, glow, rivets):
    s = LAMP_SCALE
    plate_x = OUTER + 0.1
    for side in (-1, 1):
        lamp = Vector((side * LAMP_X, -0.25, CENTER_Z))
        # Bracket: a riveted backplate on the frame's side, arms to the lamp caps and a brace.
        box(frames, (side * plate_x, lamp.y, lamp.z), (0.22, 1.1, 3.6))
        for dz in (-1.0, 1.0):
            box(frames, (side * (plate_x + LAMP_X) / 2, lamp.y, lamp.z + dz * s), (LAMP_X - plate_x + 0.1, 0.28, 0.22))
        for dz in (-1.5, 1.5):
            blob(rivets, Vector((side * (plate_x + 0.11), lamp.y, lamp.z + dz)), Vector((0.09, 0.16, 0.16)), subdivisions=2)
        a, b = Vector((side * (plate_x + 0.1), lamp.y, lamp.z - 1.7)), Vector((side * (LAMP_X - 0.2), lamp.y, lamp.z - 1.02 * s))
        sweep(frames, [a.lerp(b, t / 3) for t in range(4)], 0.09, segments=8)
        place = Matrix.Translation(lamp) @ Matrix.Scale(s, 4)
        bottom = [(0, -1.1), (0.3, -1.1), (0.56, -1.0), (0.6, -0.9), (0.6, -0.8), (0.52, -0.72), (0, -0.72)]
        lathe(frames, bottom, 20, place)
        lathe(frames, [(r, -z) for r, z in reversed(bottom)], 20, place)
        lathe(frames, [(0, -1.42), (0.1, -1.32), (0.19, -1.14), (0, -1.08)], 12, place)
        lathe(frames, [(0, 1.08), (0.3, 1.08), (0.22, 1.2), (0, 1.27)], 16, place)
        torus(frames, lamp + Vector((0, 0, 1.38 * s)), (0, 1, 0), 0.13 * s, 0.045 * s, segments=16, minor_segments=6)
        for k in range(4):
            a = math.radians(45 + 90 * k)
            cylinder(frames, lamp + Vector((math.cos(a), math.sin(a), 0)) * 0.48 * s + Vector((0, 0, -0.75 * s)), (0, 0, 1),
                     1.5 * s, 0.055 * s, segments=8)
        # The glowing hourglass glass.
        lathe(glow, [(0, -0.74), (0.36, -0.72), (0.43, -0.5), (0.34, -0.22), (0.1, -0.05), (0.08, 0.0), (0.1, 0.05),
                     (0.34, 0.22), (0.43, 0.5), (0.36, 0.72), (0, 0.74)], 16, place)


def build_vortex(disc, swirl):
    center = Vector((0, -0.15, CENTER_Z))
    lathe_y(disc, [(0, -0.05), (VORTEX_R, -0.05), (VORTEX_R, 0.05), (0, 0.05)], 64, center)
    # Four thick and four thin spiral arms, four-fold symmetric, ending on the disc's rim.
    twist, r0, samples = 1.35 * math.pi, 0.35, 32
    for k in range(8):
        thick = k % 2 == 0
        a0 = k * EIGHTH
        points, widths = [], []
        for i in range(samples + 1):
            t = i / samples
            r = r0 + (VORTEX_R - r0) * t ** 1.15
            a = a0 + twist * t
            points.append(Vector((r * math.cos(a), 0, CENTER_Z + r * math.sin(a))))
            widths.append(0.1 + 0.95 * t if thick else 0.05 + 0.42 * t)
        left, right = [], []
        for i, p in enumerate(points):
            ahead = points[min(i + 1, samples)] - points[max(i - 1, 0)]
            side = Vector((-ahead.z, 0, ahead.x)).normalized() * widths[i] / 2
            left.append(p - side)
            right.append(p + side)
        strip_slab(swirl, left, right, -0.29, -0.22)
    lathe_y(swirl, [(0, 0.24), (0.7, 0.24), (0.7, 0.31), (0, 0.31)], 24, Vector((0, 0, CENTER_Z)))
    # Clip to the disc so the swirl's bounding box is the opening's.
    for v in swirl.verts:
        offset = Vector((v.co.x, 0, v.co.z - CENTER_Z))
        if offset.length > VORTEX_R:
            offset *= VORTEX_R / offset.length
            v.co.x, v.co.z = offset.x, CENTER_Z + offset.z


# ---------- assembly ----------

MESH_NAMES = ["PortalFrame", "PortalBands", "PortalRivets", "PortalMarkers", "PortalBase", "PortalBaseTrim",
              "PortalClock", "PortalClockRim", "PortalHourHand", "PortalMinuteHand", "PortalGearA", "PortalGearB",
              "PortalLampFrames", "PortalLampGlow", "PortalVortex", "PortalSwirl", "HubGear"]


def finish(coll, name, bm, rgb, bevel_width=0.0, segments=2, angle=40):
    """Closed pieces: outward normals, an optional soft bevel, flat broad faces. The bevel hardens
    normals so big flat faces stay flat instead of picking up gradients from their rounded edges."""
    recalc_normals(bm)
    obj = make_object(coll, name, bm, rgb)
    if bevel_width:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width, modifier.segments = bevel_width, segments
        modifier.limit_method = "ANGLE"
        modifier.harden_normals = True
        apply_modifiers(obj)
    smooth_by_angle(obj, angle)
    return obj


def bounds(obj):
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def bbox_center(obj):
    low, high = bounds(obj)
    return (low + high) / 2


def build(coll):
    bm = {name: bmesh.new() for name in MESH_NAMES}
    build_frame(bm["PortalFrame"], bm["PortalBands"], bm["PortalRivets"], bm["PortalMarkers"])
    build_base(bm["PortalBase"], bm["PortalBaseTrim"])
    build_clock(bm["PortalClock"], bm["PortalClockRim"], bm["PortalHourHand"], bm["PortalMinuteHand"])
    for name, spec in (("PortalGearA", GEAR_A), ("PortalGearB", GEAR_B)):
        gear(bm[name], gear_center(spec), spec[2], spec[3], spec[4], axle_to=FRONT_Y + 0.03)
    build_lamps(bm["PortalLampFrames"], bm["PortalLampGlow"], bm["PortalRivets"])
    build_vortex(bm["PortalVortex"], bm["PortalSwirl"])
    gear(bm["HubGear"], HUB_GEAR_CENTER, 5.0, 12, 6)
    return [
        finish(coll, "PortalFrame", bm["PortalFrame"], BRASS, bevel_width=0.16, segments=3),
        finish(coll, "PortalBands", bm["PortalBands"], IRON, bevel_width=0.05),
        finish(coll, "PortalRivets", bm["PortalRivets"], GOLD, angle=80),
        finish(coll, "PortalMarkers", bm["PortalMarkers"], IRON, bevel_width=0.03),
        finish(coll, "PortalBase", bm["PortalBase"], STONE, bevel_width=0.08),
        finish(coll, "PortalBaseTrim", bm["PortalBaseTrim"], BRASS, bevel_width=0.025),
        finish(coll, "PortalClock", bm["PortalClock"], CREAM),
        finish(coll, "PortalClockRim", bm["PortalClockRim"], GOLD),
        finish(coll, "PortalHourHand", bm["PortalHourHand"], HAND),
        finish(coll, "PortalMinuteHand", bm["PortalMinuteHand"], HAND),
        finish(coll, "PortalGearA", bm["PortalGearA"], COPPER, bevel_width=GEAR_A[2] * 0.035),
        finish(coll, "PortalGearB", bm["PortalGearB"], COPPER, bevel_width=GEAR_B[2] * 0.035),
        finish(coll, "PortalLampFrames", bm["PortalLampFrames"], BRASS, bevel_width=0.03),
        finish(coll, "PortalLampGlow", bm["PortalLampGlow"], CYAN),
        finish(coll, "PortalVortex", bm["PortalVortex"], TEAL),
        finish(coll, "PortalSwirl", bm["PortalSwirl"], CYAN),
        finish(coll, "HubGear", bm["HubGear"], COPPER, bevel_width=5.0 * 0.035),
    ]


def report(objects):
    """Print triangle counts, bounding-box centres, the spinning parts' axle checks and the extents.
    Returns a list of problems (empty when everything is within limits)."""
    by_name = {o.name: o for o in objects}
    problems = []
    for o in objects:
        c = bbox_center(o)
        count = triangles(o)
        print("%-17s %6d tris  centre (%.3f, %.3f, %.3f)" % (o.name, count, c.x, c.y, c.z))
        if count > MAX_TRIANGLES:
            problems.append(o.name + " has too many triangles")
    vortex, swirl = bbox_center(by_name["PortalVortex"]), bbox_center(by_name["PortalSwirl"])
    axles = [("PortalSwirl", swirl, vortex), ("PortalHourHand", bbox_center(by_name["PortalHourHand"]), CLOCK),
             ("PortalMinuteHand", bbox_center(by_name["PortalMinuteHand"]), CLOCK),
             ("PortalGearA", bbox_center(by_name["PortalGearA"]), gear_center(GEAR_A)),
             ("PortalGearB", bbox_center(by_name["PortalGearB"]), gear_center(GEAR_B)),
             ("HubGear", bbox_center(by_name["HubGear"]), HUB_GEAR_CENTER)]
    for name, centre, axle in axles:
        error = max(abs(centre.x - axle.x), abs(centre.z - axle.z))
        print("axle check %-17s off by %.5f in X/Z" % (name, error))
        if error > 1e-3:
            problems.append(name + " is not centred on its axle")
    portal = [o for o in objects if o.name != "HubGear"]
    lows, highs = zip(*(bounds(o) for o in portal))
    low = Vector((min(p.x for p in lows), min(p.y for p in lows), min(p.z for p in lows)))
    high = Vector((max(p.x for p in highs), max(p.y for p in highs), max(p.z for p in highs)))
    size = high - low
    print("portal extent x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f  size %.2f x %.2f x %.2f"
          % (low.x, high.x, low.y, high.y, low.z, high.z, size.x, size.y, size.z))
    print("HubGear size %.2f x %.2f x %.2f" % tuple(by_name["HubGear"].dimensions))
    print("opening: vortex diameter %.2f, centre %.2f above the base, clock axle %s"
          % (VORTEX_R * 2, CENTER_Z, tuple(round(v, 3) for v in CLOCK)))
    if max(size) > MAX_EXTENT:
        problems.append("portal is larger than the import limit")
    if problems:
        print("PROBLEMS:", problems)
    return problems


def build_and_export(export=True):
    coll = fresh_collection(COLLECTION)
    layer = bpy.context.view_layer.layer_collection.children.get(COLLECTION)
    if layer:
        layer.exclude = False
    for name in MESH_NAMES:
        old = bpy.data.meshes.get(name)
        if old and old.users == 0:
            bpy.data.meshes.remove(old)
    objects = build(coll)
    problems = report(objects)
    if not export or problems:
        return objects
    for other in bpy.context.selected_objects:
        other.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    os.makedirs(os.path.dirname(EXPORT_PATH), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=EXPORT_PATH, use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, add_leaf_bones=False, bake_anim=False)
    print("exported", EXPORT_PATH)
    return objects


build_and_export(globals().get("EXPORT", True))
