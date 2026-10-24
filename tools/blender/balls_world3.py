# The ten World 3 (Future World) balls, exported together as assets/models/BallsWorld3.fbx.
# Run inside Blender via MCP (one call builds and exports):
#   EXPORT = False   # optional: skip the export while iterating
#   exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\balls_world3.py", encoding="utf-8").read())
# Same conventions as balls.py and balls_world2.py: every ball is built at radius 1 around its
# own centre, spaced along X so they do not overlap in the import, and each mesh is named
# "<item id>__<Part>". The main body is always the "Shell" part and is the 2-unit sphere itself
# (the game measures the ball's size from it; the pixel ball's voxel Shell fills the same 2-unit
# box). Surface details stand at most ~1.06 R; rings, fins, the rocket's engine bell and the
# robot's antenna reach up to ~1.35 R. The front is -Y and +Z is up; the display spins each
# ball about +Z, so key features repeat around the sides. balls_world2.py's helpers (and
# through it balls.py's and cage_helpers.py's) are reused without running their builds, so the
# "Balls" and "BallsWorld2" collections are left untouched. Glass shells are made see-through
# in Blender's viewport only; BallStyles (Luau) sets every part's real colour and transparency.
BALLS_WORLD2 = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\balls_world2.py"
_world2_source = open(BALLS_WORLD2, encoding="utf-8").read()
_world2_marker = "# ---------- the ten balls ----------"
assert _world2_marker in _world2_source, "balls_world2.py layout changed; update balls_world3.py"
exec(_world2_source.partition(_world2_marker)[0])
import itertools

COLLECTION = "BallsWorld3"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\BallsWorld3.fbx"


# ---------- surface helpers ----------

# The six cube faces as (normal, u axis, v axis): the cube-sphere grid of the solar panels.
CUBE_FACES = [(Vector(n), Vector(a), Vector(b)) for n, a, b in (
    ((1, 0, 0), (0, 1, 0), (0, 0, 1)), ((-1, 0, 0), (0, -1, 0), (0, 0, 1)),
    ((0, 1, 0), (-1, 0, 0), (0, 0, 1)), ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
    ((0, 0, 1), (1, 0, 0), (0, 1, 0)), ((0, 0, -1), (1, 0, 0), (0, -1, 0)))]


def cube_direction(face, alpha, beta):
    """The sphere seen through one cube face at equal-angle coordinates (alpha, beta) in
    -45..45 degrees, so a grid of cells comes out nearly the same size everywhere."""
    n, a, b = face
    return (n + a * math.tan(alpha) + b * math.tan(beta)).normalized()


def sphere_tile(bm, corner, divisions, base, top):
    """A closed raised tile on the sphere. corner(s, t) gives the unit direction for s, t in
    0..1; the top is a divisions x divisions grid at radius top (so it bends with the ball),
    the walls drop to base and a floor closes it inside the shell."""
    n = divisions
    grid = [[bm.verts.new(corner(i / n, j / n) * R * top) for j in range(n + 1)] for i in range(n + 1)]
    for i in range(n):
        for j in range(n):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    loop = ([(i, 0) for i in range(n)] + [(n, j) for j in range(n)] +
            [(i, n) for i in range(n, 0, -1)] + [(0, j) for j in range(n, 0, -1)])
    floor = [bm.verts.new(corner(i / n, j / n) * R * base) for i, j in loop]
    m = len(loop)
    for k in range(m):
        (i0, j0), (i1, j1) = loop[k], loop[(k + 1) % m]
        bm.faces.new((grid[i1][j1], grid[i0][j0], floor[k], floor[(k + 1) % m]))
    bm.faces.new(tuple(reversed(floor)))


def rounded_rect(width, height, radius, corner_points=4):
    """A 2D rounded-rectangle outline centred on the origin, counter-clockwise."""
    hw, hh = width / 2 - radius, height / 2 - radius
    points = []
    for cx, cy, a0 in ((hw, hh, 0.0), (-hw, hh, math.pi / 2), (-hw, -hh, math.pi), (hw, -hh, 1.5 * math.pi)):
        for k in range(corner_points + 1):
            a = a0 + (math.pi / 2) * k / corner_points
            points.append(Vector((cx + math.cos(a) * radius, cy + math.sin(a) * radius)))
    return points


def band_ring(bm, turn, inner, outer, thickness, segments=96, edge_points=4):
    """A flat ring round the turned Z axis with fully rounded inner and outer edges
    (needs outer - inner >= thickness)."""
    half = thickness / 2
    profile = []
    for centre, a0 in ((outer - half, -math.pi / 2), (inner + half, math.pi / 2)):
        for k in range(edge_points + 1):
            a = a0 + math.pi * k / edge_points
            profile.append((centre + math.cos(a) * half, math.sin(a) * half))
    lathe(bm, profile + [profile[0]], segments, transform=turn)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)


def leaf_blade(bm, base, direction, up, length, width, thickness=0.03, cup=0.3, bend=0.2, rings=10, sides=10):
    """A closed, cupped leaf blade growing from base along direction with its face toward up.
    bend curls the tip toward up and cup lifts the edges, so it reads as a leaf from any side."""
    d = Vector(direction).normalized()
    u = Vector(up)
    u = (u - d * u.dot(d)).normalized()
    side = d.cross(u).normalized()
    base = Vector(base)
    loops = []
    for i in range(rings):
        t = i / rings
        half_w = width / 2 * max(0.12, math.sin(math.pi * t ** 0.75))
        half_t = thickness / 2 * (1 - 0.6 * t)
        centre = base + d * length * t + u * bend * length * t * t
        loop = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            x, y = math.cos(a), math.sin(a)
            loop.append(bm.verts.new(centre + side * (half_w * x) + u * (half_t * y + cup * half_w * x * x)))
        loops.append(loop)
    tip = bm.verts.new(base + d * length + u * bend * length)
    for a, b in zip(loops, loops[1:]):
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((a[k], a[j], b[j], b[k]))
    for k in range(sides):
        bm.faces.new((loops[-1][k], loops[-1][(k + 1) % sides], tip))
    bm.faces.new(tuple(reversed(loops[0])))


def surface_leaf(bm, p, forward, side_sign, length, width, splay=0.7, top=1.034):
    """A small raised leaf growing from point p on the sphere, angled off the stem direction
    forward to one side (side_sign 1 or -1)."""
    n = Vector(p).normalized()
    forward = (forward - n * forward.dot(n)).normalized()
    side = forward.cross(n).normalized() * side_sign
    patch = Patch(n, up=forward * math.cos(splay) + side * math.sin(splay))
    decal(bm, patch, lens(length, width, 12), top=top, dome=0.016, rings=2, centre=(0, length * 0.45))


def see_through(name, alpha):
    """Preview only: lets Blender's viewport show a glass part as see-through (FBX colours do
    not reach Roblox; BallStyles sets the real transparency)."""
    bpy.data.materials[name].diffuse_color[3] = alpha


# ---------- the ten balls ----------

def sun_badge(glow, backing, normal):
    """A glowing sun (a domed core and eight rays) on a round dark panel."""
    patch = Patch(normal)
    decal(backing, patch, ellipse(0, 0, 0.2, 0.2, 36), base=1.0, top=1.03, rings=2)
    decal(glow, patch, ellipse(0, 0, 0.075, 0.075, 20), base=1.0, top=1.04, dome=0.016, rings=3)
    for k in range(8):
        a = math.pi / 2 + 2 * math.pi * k / 8
        d, side = Vector((math.cos(a), math.sin(a))), Vector((-math.sin(a), math.cos(a)))
        length = 0.175 if k % 2 == 0 else 0.14
        decal(glow, patch, [d * 0.1 + side * 0.028, d * length, d * 0.1 - side * 0.028], base=1.0, top=1.04, rings=1)


def solar_cell_ball(add):
    """Gold satellite foil tiled with silver-framed solar panels (a 3 x 3 grid on each cube
    face, every panel split into four cells), with a glowing sun badge front and back."""
    s, panels, frames, glow = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    q = math.pi / 4
    step = 2 * q / 3
    gap, rim, bar = 0.035, 0.024, 0.014   # half the gold gap, the silver rim, half the silver bar (radians)
    for face in CUBE_FACES:
        def area(u0, u1, v0, v1):
            return lambda s_, t_: cube_direction(face, u0 + (u1 - u0) * s_, v0 + (v1 - v0) * t_)

        for i in range(3):
            for j in range(3):
                a0, b0 = -q + i * step + gap, -q + j * step + gap
                a1, b1 = a0 + step - 2 * gap, b0 + step - 2 * gap
                sphere_tile(frames, area(a0, a1, b0, b1), 3, 0.985, 1.02)
                if i == j == 1 and abs(face[0].y) > 0.5:
                    sun_badge(glow, panels, face[0])
                    continue
                am, bmid = (a0 + a1) / 2, (b0 + b1) / 2
                for u0, u1 in ((a0 + rim, am - bar), (am + bar, a1 - rim)):
                    for v0, v1 in ((b0 + rim, bmid - bar), (bmid + bar, b1 - rim)):
                        sphere_tile(panels, area(u0, u1, v0, v1), 1, 1.0, 1.034)
    add("Shell", s, (1.0, 0.74, 0.2))
    add("Panels", panels, (0.08, 0.14, 0.42), smooth=False)
    add("Frames", frames, (0.82, 0.84, 0.88), smooth=False)
    add("Glow", glow, (1.0, 0.62, 0.12), smooth=False)


def hover_ball(add):
    """Polished silver with a glowing ring floating round its middle on dark clamps, thruster
    vents at both poles and small slotted vents between."""
    s, ring, vents, lights = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    band_ring(ring, Matrix(), 1.12, 1.3, 0.075)
    # A dark track under the ring, clamps gripping it, and thin hull seams above and below.
    ribbon(vents, latitude(0.0, 128), 0.17, top=1.02, closed=True)
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        d = Vector((math.cos(a), math.sin(a), 0))
        box(vents, d * 1.11, (0.27, 0.09, 0.14), rotation=Matrix.Rotation(a, 4, "Z"))
    for h in (0.34, -0.34):
        ribbon(vents, latitude(h, 120), 0.026, top=1.008, closed=True)
    # Thrusters at the poles: a glowing ring and core behind turbine slats in a dark rim.
    for sign in (1, -1):
        patch = Patch(Vector((0, 0, sign)), up=(0, 1, 0))
        decal(vents, patch, ellipse(0, 0, 0.36, 0.36, 40), base=0.985, top=1.012, rings=2)
        flat_ring(vents, patch, ellipse(0, 0, 0.44, 0.44, 48), ellipse(0, 0, 0.35, 0.35, 48), top=1.04)
        stroke(lights, patch, ellipse(0, 0, 0.24, 0.24, 40), 0.07, base=1.0, top=1.022, closed=True)
        decal(lights, patch, ellipse(0, 0, 0.1, 0.1, 20), base=1.0, top=1.026, dome=0.02, rings=2)
        for k in range(8):
            a = 2 * math.pi * (k + 0.5) / 8
            d = Vector((math.cos(a), math.sin(a)))
            stroke(vents, patch, [d * 0.13, d * 0.355], 0.035, base=1.0, top=1.032)
        # Four slotted side vents on this half, between the clamps.
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            patch = Patch(latitude(sign * 0.62, a0=a, a1=a, count=2)[0])
            decal(vents, patch, rounded_rect(0.3, 0.17, 0.06), top=1.014, rings=1)
            for v in (-0.045, 0.0, 0.045):
                stroke(lights, patch, [(-0.1, v), (0.1, v)], 0.022, base=1.0, top=1.02)
    add("Shell", s, (0.86, 0.88, 0.92))
    add("Ring", ring, (0.25, 0.7, 1.0))
    add("Vents", vents, (0.12, 0.13, 0.16), smooth=False)
    add("Lights", lights, (0.4, 0.85, 1.0), smooth=False)


def meridian(a, lat0, lat1, count=48):
    """Unit points along the meridian at longitude a, from latitude lat0 to lat1 (radians)."""
    return [Vector((math.cos(lat) * math.cos(a), math.cos(lat) * math.sin(a), math.sin(lat)))
            for lat in (lat0 + (lat1 - lat0) * i / count for i in range(count + 1))]


def hologram_ball(add):
    """A see-through blue globe traced with a glowing latitude/longitude grid, two bright
    bands of scan lines and a faceted data core with an orbit ring inside."""
    s, grid, scan, core = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    polar = math.radians(66)
    for k in range(12):
        ribbon(grid, meridian(2 * math.pi * k / 12, -polar, polar, 32), 0.024, base=0.99, top=1.014)
    for h in (0.0, 0.45, -0.45):
        ribbon(grid, latitude(h, 72), 0.024, base=0.99, top=1.014, closed=True)
    for sign in (1, -1):
        ribbon(grid, latitude(sign * math.sin(polar), 64), 0.032, base=0.99, top=1.016, closed=True)
        decal(grid, Patch(Vector((0, 0, sign))), ellipse(0, 0, 0.07, 0.07, 16), base=0.99, top=1.016, dome=0.01)
    # Two scan bands between the grid lines: a bright leading line trailed by thinner ones.
    for lead, direction in ((0.17, 1), (-0.6, -1)):
        for k, width in enumerate((0.044, 0.028, 0.018, 0.011)):
            h = lead + direction * (0.06 * k - 0.006 * k * k)
            ribbon(scan, latitude(h, 64), width, base=0.995, top=1.022, closed=True)
    bmesh.ops.create_icosphere(core, subdivisions=1, radius=R * 0.3)
    torus(core, (0, 0, 0), Matrix.Rotation(math.radians(30), 3, "X") @ Vector((0, 0, 1)), 0.46, 0.016,
          segments=48, minor_segments=6)
    add("Shell", s, (0.45, 0.75, 1.0))
    add("Grid", grid, (0.3, 0.85, 1.0), smooth=False)
    add("Scanlines", scan, (0.75, 0.97, 1.0), smooth=False)
    add("Core", core, (0.85, 0.98, 1.0), smooth=False)
    see_through("hologram_ball__Shell", 0.3)


def robo_core_ball(add):
    """Riveted steel plates, one big red camera eye in a dark bezel on the front, a hatch with
    a grille and status light on the back, ear ports on both sides and a stubby antenna."""
    s, seams, rivets, eye, bezel = (bmesh.new() for _ in range(5))
    shell(s)
    eye_a, hatch_a = -math.pi / 2, math.pi / 2
    # Plate seams: the equator (broken by the eye and the hatch), two cap rings and four
    # meridians between the eye, the ears and the hatch.
    for a0, a1 in ((eye_a + 0.47, hatch_a - 0.34), (hatch_a + 0.34, eye_a + 2 * math.pi - 0.47)):
        ribbon(seams, latitude(0.0, 64, a0=a0, a1=a1), 0.07, top=1.026)
    cap = 0.8
    for sign in (1, -1):
        ribbon(seams, latitude(sign * cap, 96), 0.05, top=1.022, closed=True)
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            ribbon(seams, meridian(a, sign * 0.03, sign * math.asin(cap), 24), 0.05, top=1.022)
    # Rivets in rows beside the seams, kept off the eye, the hatch and the ears.
    keep_out = [(Vector((0, -1, 0)), 0.52), (Vector((0, 1, 0)), 0.4), (Vector((1, 0, 0)), 0.3), (Vector((-1, 0, 0)), 0.3)]
    spots = []
    for sign in (1, -1):
        spots += latitude(sign * 0.075, 30, a0=0.1, a1=0.1 + 2 * math.pi)
        spots += latitude(sign * (cap - 0.065), 18, a0=0.17, a1=0.17 + 2 * math.pi)
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2 + 0.075
            spots += [meridian(a, sign * lat, sign * lat, 1)[0] for lat in (0.3, 0.55)]
    for p in spots:
        if all(p.angle(c) > r for c, r in keep_out):
            rivet(rivets, p, 0.027, 1.0, 0.03, sides=6)
    # The eye: a glowing red lens in a thick dark bezel with an iris ring and four bolts.
    patch = Patch(Vector((0, -1, 0)))
    flat_ring(bezel, patch, ellipse(0, 0, 0.46, 0.46, 56), ellipse(0, 0, 0.34, 0.34, 56), top=1.058)
    decal(eye, patch, ellipse(0, 0, 0.345, 0.345, 48), base=0.985, top=1.028, dome=0.03, rings=4)
    stroke(bezel, patch, ellipse(0, 0, 0.2, 0.2, 40), 0.03, base=1.0, top=1.06, closed=True)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        rivet(rivets, patch.direction(math.cos(a) * 0.4, math.sin(a) * 0.4), 0.028, 1.042, 0.024, sides=8)
    # The hatch on the back: a framed plate with grille slots, a status light and rivets.
    patch = Patch(Vector((0, 1, 0)))
    stroke(seams, patch, rounded_rect(0.6, 0.5, 0.09), 0.045, top=1.03, closed=True)
    for v in (0.1, 0.03, -0.04, -0.11):
        decal(bezel, patch, [p + Vector((-0.04, v)) for p in rounded_rect(0.36, 0.04, 0.018, 2)], top=1.014, rings=1)
    decal(eye, patch, ellipse(0.19, 0.1, 0.045, 0.045, 14), base=1.0, top=1.024, dome=0.014)
    for u, v in ((-0.22, 0.17), (0.22, 0.17), (-0.22, -0.17), (0.22, -0.17)):
        rivet(rivets, patch.direction(u, v), 0.026, 1.0, 0.03, sides=6)
    # Ear ports with a small red light in each.
    for sign in (1, -1):
        patch = Patch(Vector((sign, 0, 0)))
        flat_ring(bezel, patch, ellipse(0, 0, 0.24, 0.24, 40), ellipse(0, 0, 0.15, 0.15, 40), top=1.048)
        decal(bezel, patch, ellipse(0, 0, 0.15, 0.15, 32), top=1.01, rings=1)
        decal(eye, patch, ellipse(0, 0, 0.07, 0.07, 16), base=1.0, top=1.024, dome=0.018)
    # A stubby antenna with a red bulb on top, and a matching boss underneath.
    for sign in (1, -1):
        decal(bezel, Patch(Vector((0, 0, sign)), up=(0, 1, 0)), ellipse(0, 0, 0.1, 0.1, 20), top=1.035, dome=0.012)
    cylinder(bezel, (0, 0, 0.98), (0, 0, 1), 0.2, 0.022, segments=10)
    ball(eye, (0, 0, 1.2), 0.05, subdivisions=2)
    add("Shell", s, (0.66, 0.68, 0.72))
    add("Seams", seams, (0.45, 0.47, 0.5), smooth=False)
    add("Rivets", rivets, (0.78, 0.8, 0.84))
    add("Eye", eye, (1.0, 0.12, 0.1))
    add("Bezel", bezel, (0.1, 0.1, 0.12), smooth=False)


def bio_seed_ball(add):
    """A glass terrarium ball: a mound of soil inside with a glowing two-leaf sprout, and thin
    leafy vines curling over the outside."""
    s, sprout, soil, vines = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    shell(s)
    # Soil fills the bottom of the glass; its top is a gentle, lumpy mound with a few pebbles.
    level, inner = -0.42, 0.965
    a_top = math.asin(level / inner)
    profile = [(0, -inner)]
    for i in range(1, 9):
        a = -math.pi / 2 + (a_top + math.pi / 2) * i / 8
        profile.append((math.cos(a) * inner, math.sin(a) * inner))
    profile += [(0.72, level + 0.03), (0.5, level + 0.06), (0.26, level + 0.08), (0, level + 0.085)]
    lathe(soil, profile, 40)
    for v in soil.verts:
        if v.co.z > level - 0.005 and v.co.xy.length < 0.8:
            v.co.z += noise.noise(v.co * 5.0) * 0.025
    rng = random.Random(14)
    for k in range(7):
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0.25, 0.62)
        size = rng.uniform(0.045, 0.07)
        blob(soil, Vector((math.cos(a) * r, math.sin(a) * r, level + 0.06 * (1 - (r / 0.72) ** 2) + 0.02)),
             Vector((size, size * 0.9, size * 0.7)), subdivisions=1, lump=0.3, seed=k)
    # The sprout: a gently curving stem, two broad leaves and a small curled bud.
    stem = [Vector((0.07 * math.sin(math.pi * t * 1.3), 0.03 * math.sin(2 * math.pi * t), level + 0.05 + 0.74 * t))
            for t in (i / 12 for i in range(13))]
    sweep_radii(sprout, stem, [0.055 - 0.02 * i / 12 for i in range(13)], segments=10)
    tip = stem[-1] - Vector((0, 0, 0.02))
    # The two leaves tilt their faces toward the front and the back, so one always shows.
    for side in (1, -1):
        leaf_blade(sprout, tip, (side, 0.3 * side, 0.7), (0, -0.7 * side, 1), 0.46, 0.34,
                   thickness=0.045, cup=0.28, bend=-0.14)
    leaf_blade(sprout, tip, (0.1, -0.15, 1), (0, -1, 0.2), 0.17, 0.1, thickness=0.035, cup=0.5, bend=0.25)
    # Three vines spiral up the outside of the glass from underneath, leafing as they go, each
    # ending in a curl.
    for k in range(3):
        a0 = 2 * math.pi * k / 3 + 0.4
        path = [latitude(-0.93 + 1.56 * t, a0=a, a1=a, count=2)[0]
                for t, a in ((i / 55, a0 + 1.7 * i / 55 + 0.22 * math.sin(7 * i / 55 + k)) for i in range(56))]
        end = path[-1]
        ahead = (end - path[-2])
        ahead = (ahead - end * ahead.dot(end)).normalized()
        side = ahead.cross(end).normalized() * (1 if k % 2 == 0 else -1)
        for i in range(1, 16):
            turn = i / 15 * 1.7 * math.pi
            radius = 0.085 * (1 - i / 20)
            path.append((end + (ahead * math.sin(turn) + side * (1 - math.cos(turn))) * radius).normalized())
        sweep(vines, [p * R * 1.022 for p in path], 0.022, segments=6, radius_end=0.011)
        for i in range(4, 52, 6):
            surface_leaf(vines, path[i], path[i + 1] - path[i - 1], 1 if (i // 6) % 2 == 0 else -1, 0.17, 0.085)
    add("Shell", s, (0.75, 0.95, 0.85))
    add("Sprout", sprout, (0.45, 1.0, 0.35))
    add("Soil", soil, (0.38, 0.24, 0.14))
    add("Vines", vines, (0.2, 0.55, 0.22))
    see_through("bio_seed_ball__Shell", 0.25)


# Pixel-art icons for the pixel ball, top row first: X is the icon colour, o a white highlight.
PIXEL_HEART = ["XX..XX", "XoXXXX", "XXXXXX", ".XXXX.", "..XX.."]
PIXEL_GEM = ["..XX..", ".XoXX.", "XXXXXX", "XXXXXX", ".XXXX.", "..XX.."]


def pixel_ball(add):
    """A voxel ball of chamfered cubes, ten across: arcade blue, with pixel-art icons painted
    on by projection so they read cleanly face-on (a magenta heart front and back, a yellow
    diamond on each side) and a few white sparkle pixels. Blue Shell cubes reach all six
    sides, so Shell still spans the full 2-unit ball."""
    n = 10
    size = 2 * R / n

    def centre(c):
        return Vector(((c[0] + 0.5) * size - R, (c[1] + 0.5) * size - R, (c[2] + 0.5) * size - R))

    def around(c, offsets):
        return [(c[0] + a, c[1] + b, c[2] + d) for a, b, d in offsets]

    filled = {(i, j, k) for i in range(n) for j in range(n) for k in range(n) if centre((i, j, k)).length <= R}
    faces = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
    touching = [o for o in itertools.product((-1, 0, 1), repeat=3) if o != (0, 0, 0)]
    surface = sorted(c for c in filled if any(o not in filled for o in around(c, faces)))
    # Cells that only touch the outside at an edge or corner show through the chamfer notches
    # between surface cubes, so they get plain (unchamfered) blocker cubes.
    blockers = sorted(c for c in filled if c not in surface and any(o not in filled for o in around(c, touching)))
    # Each icon is drawn on the 10 x 10 grid seen from one side: every icon pixel colours the
    # outermost cube on its line of sight. (axis, sign) is the side; across is the grid axis
    # that runs left to right as seen from that side; top is the grid row of the icon's top.
    # The icons leave some blue cubes on each side's flat outermost face for the Shell.
    painted = {}
    for icon, colour, top, (axis, sign, across, flip) in (
            (PIXEL_HEART, "Pixels1", 7, (1, -1, 0, False)), (PIXEL_HEART, "Pixels1", 7, (1, 1, 0, True)),
            (PIXEL_GEM, "Pixels2", 8, (0, 1, 1, False)), (PIXEL_GEM, "Pixels2", 8, (0, -1, 1, True))):
        for row, line in enumerate(icon):
            for col, mark in enumerate(line):
                if mark == ".":
                    continue
                key = {across: (7 - col) if flip else (2 + col), 2: top - row}
                line_cells = [c for c in surface if all(c[a] == v for a, v in key.items())]
                cell = (min if sign < 0 else max)(line_cells, key=lambda c: c[axis])
                painted[cell] = colour if mark == "X" else "Pixels3"
    rng = random.Random(7)
    groups = {"Shell": [], "Pixels1": [], "Pixels2": [], "Pixels3": []}
    for c in surface:
        if c in painted:
            groups[painted[c]].append(c)
        elif (rng.random() < 0.05 and not any(o in painted for o in around(c, touching))
              and not any(v in (0, n - 1) for v in c)):
            groups["Pixels3"].append(c)
        else:
            groups["Shell"].append(c)
    # Shell must touch all six sides of the 2-unit box (the game sizes the ball from it).
    for axis in range(3):
        for edge in (0, n - 1):
            assert any(c[axis] == edge for c in groups["Shell"]), "pixel_ball: an icon covers a whole side"
    for name, colour in (("Shell", (0.12, 0.45, 1.0)), ("Pixels1", (1.0, 0.2, 0.7)),
                         ("Pixels2", (1.0, 0.85, 0.15)), ("Pixels3", (0.9, 1.0, 1.0))):
        bm = bmesh.new()
        for c in groups[name]:
            box(bm, centre(c), (size, size, size))
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=size * 0.12, segments=1, affect="EDGES", clamp_overlap=True)
        if name == "Shell":
            for c in blockers:
                box(bm, centre(c), (size, size, size))
        add(name, bm, colour, smooth=False)


def tail_fin(bm, outline, angle, thickness):
    """A flat fin with softened edges standing in the vertical plane at angle round Z.
    outline is a closed list of (out, z) points: distance from the Z axis and height."""
    d = Vector((math.cos(angle), math.sin(angle), 0))
    t = Vector((-math.sin(angle), math.cos(angle), 0)) * (thickness / 2)
    front = [bm.verts.new(d * p[0] + Vector((0, 0, p[1])) + t) for p in outline]
    back = [bm.verts.new(d * p[0] + Vector((0, 0, p[1])) - t) for p in outline]
    caps = [bm.faces.new(front), bm.faces.new(list(reversed(back)))]
    m = len(outline)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((front[j], front[i], back[i], back[j]))
    rim = [e for f in caps for e in f.edges]
    bmesh.ops.bevel(bm, geom=rim, offset=thickness * 0.3, segments=2, affect="EDGES", clamp_overlap=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])


def rocket_ball(add):
    """A white retro rocket ball standing nose up: a red nose cap and stripes, a bolted
    porthole on the front and the back, four red tail fins and a dark engine bell underneath."""
    s, stripes, fins, window, nozzle = (bmesh.new() for _ in range(5))
    shell(s)
    decal(stripes, Patch(Vector((0, 0, 1)), up=(0, 1, 0)), ellipse(0, 0, 0.5, 0.5, 64), base=0.985, top=1.03, rings=4)
    for h, width in ((0.7, 0.05), (-0.3, 0.13), (-0.45, 0.05)):
        ribbon(stripes, latitude(h, 96), width, top=1.03, closed=True)
    for normal in (Vector((0, -1, 0.2)), Vector((0, 1, 0.2))):
        patch = Patch(normal)
        flat_ring(nozzle, patch, ellipse(0, 0, 0.28, 0.28, 48), ellipse(0, 0, 0.205, 0.205, 48), top=1.045)
        decal(window, patch, ellipse(0, 0, 0.21, 0.21, 40), base=0.985, top=1.018, dome=0.026, rings=3)
        for k in range(8):
            a = 2 * math.pi * (k + 0.5) / 8
            rivet(nozzle, patch.direction(math.cos(a) * 0.243, math.sin(a) * 0.243), 0.016, 1.042, 0.016, sides=6)
    # Four swept tail fins (front, back and both sides) that taper to points below the body like
    # landing legs, drawn as (degrees below the equator, distance from the centre) so the tips
    # stay within ~1.35 R. They stand in opposite pairs, so the ball spins true on its display.
    # The porthole bezels and bolts share the dark Nozzle part.
    polar = [(-8 - 7 * i, 0.96) for i in range(9)] + [(-62, 1.12), (-60, 1.26), (-58, 1.355), (-52, 1.34),
                                                     (-45, 1.3), (-37, 1.24), (-29, 1.17), (-21, 1.09), (-14, 1.02)]
    outline = [(math.cos(math.radians(a)) * r, math.sin(math.radians(a)) * r) for a, r in polar]
    for k in range(4):
        tail_fin(fins, outline, k * math.pi / 2, 0.075)
    lathe(nozzle, [(0, -0.9), (0.4, -0.9), (0.4, -0.97), (0.3, -1.0), (0.24, -1.05), (0.28, -1.11), (0.35, -1.18),
                   (0.41, -1.23), (0.38, -1.25), (0.32, -1.21), (0.22, -1.14), (0.15, -1.09), (0, -1.08)], 36)
    add("Shell", s, (0.96, 0.96, 0.95))
    add("Stripes", stripes, (0.85, 0.1, 0.1), smooth=False)
    add("Fins", fins, (0.85, 0.1, 0.1), smooth=False)
    add("Window", window, (0.5, 0.8, 1.0))
    add("Nozzle", nozzle, (0.18, 0.18, 0.2), smooth=False)


def crater_height(t, depth, rim):
    """A crater's surface radius (in R) at t = angle from its centre / its radius: a bowl that
    rises to a raised rim at t = 1, then slopes back to the shell by t = 1.5."""
    if t < 1:
        return 1 - depth + (depth + rim) * t * t
    return 1 + rim * max(0.0, 1 - (t - 1) / 0.5) ** 2


def crater_lens(bm, centre, size, depth, rim, ts, under_ts, lift, under, segments, edge=None):
    """A closed lens-shaped piece following a crater's surface (raised by lift) over t in ts,
    its hidden underside (under lower) sampled at under_ts. edge, if given, is the radius of
    its outer edge (just below the shell, so a crater's outer slope blends in)."""
    def point(t, g):
        return (math.sin(t * size) * g, math.cos(t * size) * g)

    last = crater_height(ts[-1], depth, rim) + lift if edge is None else edge
    top = [point(t, crater_height(t, depth, rim) + lift) for t in ts[1:-1]] + [point(ts[-1], last)]
    bottom = [point(t, crater_height(t, depth, rim) - under) for t in under_ts]
    lathe(bm, [(0, crater_height(0, depth, rim) + lift)] + top + bottom + [(0, crater_height(0, depth, rim) - under)],
          segments, transform=surface_frame(centre))


def moon_rock_ball(add):
    """Grey moon rock pitted with crater bowls of every size, each with a raised rim, and a
    faint glowing pool in three of them (one facing the front, two round the back)."""
    s, craters, glow = bmesh.new(), bmesh.new(), bmesh.new()
    shell(s, subdivisions=5)
    rng = random.Random(52)
    axes = [Vector(v) for v in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))]
    placed = []
    sizes = (0.36, 0.31, 0.28, 0.25, 0.22, 0.2, 0.18, 0.16, 0.15, 0.13, 0.12, 0.11, 0.1, 0.09, 0.09, 0.08, 0.08, 0.07)
    for size in sizes + (0.06,) * 6 + (0.05,) * 6:
        for _ in range(400):
            c = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
            # Rims never overlap, and the bowls stay off the six extreme points so the shell
            # keeps its full 2-unit size.
            if all(c.angle(o) > (size + other) * 1.45 for o, other in placed) and all(c.angle(a) > size * 1.1 for a in axes):
                placed.append((c, size))
                break
    # The shell sinks under each bowl so it never pokes through the crater floor.
    for v in s.verts:
        d = v.co.normalized()
        r = 1.0
        for c, size in placed:
            t = d.angle(c) / size
            if t < 1:
                r = min(r, crater_height(t, 0.22 * size, 0.1 * size) - 0.04)
        v.co = d * R * r
    big = [p for p in placed if p[1] >= 0.13]
    glowing = {min(big, key=lambda p: p[0].angle(Vector(d).normalized()))[0].to_tuple()
               for d in ((0, -1, 0.3), (0.85, 0.5, -0.2), (-0.85, 0.5, 0.2))}
    for c, size in placed:
        depth, rim = 0.22 * size, 0.1 * size
        if size >= 0.07:
            segments = 18 if size >= 0.2 else 12 if size >= 0.12 else 10
            ts, under = (0, 0.4, 0.6, 0.78, 0.9, 1.0, 1.12, 1.3, 1.5, 1.62), (1.3, 0.75)
        else:
            segments, ts, under = 8, (0, 0.4, 0.75, 0.92, 1.0, 1.15, 1.4, 1.62), (1.15,)
        crater_lens(craters, c, size, depth, rim, ts, under, 0.003, 0.03, segments, edge=0.985)
        if c.to_tuple() in glowing:
            crater_lens(glow, c, size, depth, rim, (0, 0.2, 0.4, 0.62), (0.3,), 0.014, 0.006, 20)
    add("Shell", s, (0.62, 0.62, 0.64))
    add("Craters", craters, (0.3, 0.3, 0.33))
    add("Glow", glow, (0.3, 1.0, 0.8))


def blob_outline(size, rng, count=28, squash=1.0):
    """An irregular, continent-like 2D outline: a circle warped by a few random waves."""
    waves = [(k, amp, rng.uniform(0, 2 * math.pi)) for k, amp in ((2, 0.2), (3, 0.14), (5, 0.08), (7, 0.05))]
    points = []
    for i in range(count):
        a = 2 * math.pi * i / count
        r = size * (1 + sum(amp * math.sin(k * a + phase) for k, amp, phase in waves))
        points.append(Vector((math.cos(a) * r, math.sin(a) * r * squash)))
    return points


def gust(scale, flip=False):
    """2D points of a stylised gust of dust: a wavy streak along +u that ends in a curl rising
    above it. flip turns it round (streak along -u, curl below)."""
    points = [Vector((u, 0.022 * math.sin(2 * math.pi * (u + 0.36) / 0.36)))
              for u in (-0.36 + 0.36 * i / 12 for i in range(13))]
    turns, r0, r1 = 1.3, 0.085, 0.022
    for i in range(1, 29):
        f = i / 28
        a = -math.pi / 2 + 2 * math.pi * turns * f
        r = r0 + (r1 - r0) * f
        points.append(Vector((math.cos(a) * r, r0 + math.sin(a) * r)))
    return [(-p if flip else p) * scale for p in points]


def wavy_band(bm, edges, count=96, across=4, base=0.985, top=1.006):
    """A raised band round the Z axis between two wavy edges: edges(a) gives the (low, high)
    heights at angle a. It curves with the ball across its width."""
    rows = []
    for i in range(count):
        a = 2 * math.pi * i / count
        low, high = edges(a)
        heights = [low + (high - low) * j / across for j in range(across + 1)]
        ring = [bm.verts.new(latitude(low, a0=a, a1=a, count=2)[0] * R * base)]
        ring += [bm.verts.new(latitude(h, a0=a, a1=a, count=2)[0] * R * top) for h in heights]
        ring.append(bm.verts.new(latitude(high, a0=a, a1=a, count=2)[0] * R * base))
        rows.append(ring)
    m = len(rows[0])
    for r0, r1 in zip(rows, rows[1:] + rows[:1]):
        for j in range(m):
            k = (j + 1) % m
            bm.faces.new((r0[j], r0[k], r1[k], r1[j]))


def red_planet_ball(add):
    """Rust-red Mars: darker continent-like regions in the mid latitudes, a dark dust-storm
    belt round the middle with light raised gusts curling over it, and white polar ice caps."""
    s, regions, storm, ice = (bmesh.new() for _ in range(4))
    shell(s)
    rng = random.Random(61)
    for n in fibonacci_points(26, seed=0.9):
        if 0.3 < abs(n.z) < 0.72:
            patch = Patch(n, spin=rng.uniform(0, 2 * math.pi))
            decal(regions, patch, blob_outline(rng.uniform(0.13, 0.22), rng, squash=rng.uniform(0.6, 0.9)),
                  base=0.985, top=1.01, dome=0.004, rings=2, centre=(0, 0))
    # The storm belt: a dark band with ragged edges, two staggered rows of gusts on it (the
    # upper ones curl up, the lower ones turn round and curl down) and wind dashes streaming
    # along the middle between them.
    wavy_band(regions, lambda a: (-0.21 + 0.035 * math.sin(3 * a + 1) + 0.02 * math.sin(8 * a),
                                  0.21 + 0.035 * math.sin(4 * a) + 0.02 * math.sin(9 * a + 2)))
    for row, h in enumerate((0.1, -0.1)):
        for k in range(6):
            a = 2 * math.pi * (k + 0.5 * row) / 6
            patch = Patch(latitude(h, a0=a, a1=a, count=2)[0])
            stroke(storm, patch, gust(1.0 + 0.12 * ((k + row) % 2), flip=row == 1), 0.036, top=1.032, step=0.03)
            dash_a = a + 0.1 + 0.524 * row
            dash = [latitude(0.018 * math.sin(7 * t + k), a0=dash_a + 0.34 * t, a1=dash_a + 0.34 * t, count=2)[0]
                    for t in (i / 8 for i in range(9))]
            ribbon(storm, dash, 0.026, top=1.026)
    # Polar ice caps with a few loose ice patches round their edges.
    for sign, size in ((1, 0.38), (-1, 0.3)):
        patch = Patch(Vector((0, 0, sign)), up=(0, 1, 0), spin=rng.uniform(0, 2 * math.pi))
        decal(ice, patch, blob_outline(size, rng, count=36), base=0.985, top=1.026, dome=0.018, rings=3, centre=(0, 0))
        for k in range(4):
            a = 2 * math.pi * k / 4 + rng.uniform(0, 0.8)
            p = latitude(sign * math.cos(size * 1.3 + rng.uniform(0.02, 0.1)), a0=a, a1=a, count=2)[0]
            decal(ice, Patch(p, spin=rng.uniform(0, 3)), blob_outline(rng.uniform(0.04, 0.07), rng, count=16, squash=0.6),
                  base=0.985, top=1.02, dome=0.004, centre=(0, 0))
    add("Shell", s, (0.76, 0.33, 0.16))
    add("Regions", regions, (0.45, 0.17, 0.1), smooth=False)
    add("Storm", storm, (0.96, 0.7, 0.46), smooth=False)
    add("IceCaps", ice, (0.96, 0.98, 1.0), smooth=False)


def singularity_orb(add):
    """A black core in a faint glass lens, a thin photon halo hugging its outline (it faces the
    front, like light bent round the hole), and a bright accretion ring of three bands tilted
    18 degrees and floating clear of it all."""
    s, ring, halo, glass = (bmesh.new() for _ in range(4))
    shell(s)
    ball(glass, (0, 0, 0), R * 1.1, subdivisions=4)
    torus(halo, (0, 0, 0), (0, 1, 0), R * 1.045, 0.024, segments=96, minor_segments=8)
    tilt = Matrix.Rotation(math.radians(18), 4, "X")
    for inner, outer, thickness in ((1.14, 1.18, 0.03), (1.2, 1.3, 0.045), (1.315, 1.35, 0.022)):
        band_ring(ring, tilt, inner, outer, thickness)
    add("Shell", s, (0.02, 0.02, 0.03))
    add("Ring", ring, (1.0, 0.7, 0.3))
    add("Halo", halo, (1.0, 0.93, 0.78))
    add("Lens", glass, (0.7, 0.8, 1.0))
    see_through("singularity_orb__Lens", 0.15)


BALLS = ["solar_cell_ball", "hover_ball", "hologram_ball", "robo_core_ball", "bio_seed_ball",
         "pixel_ball", "rocket_ball", "moon_rock_ball", "red_planet_ball", "singularity_orb"]


def report(objects):
    """Prints each ball's triangles, its Shell's size and how far each part reaches (in R)."""
    for index, item_id in enumerate(BALLS):
        centre = Vector((index * SPACING, 0, 0))
        parts = [o for o in objects if o.name.startswith(item_id + "__")]
        reach = {o.name.split("__")[1]: round(max((o.matrix_world @ v.co - centre).length for v in o.data.vertices) / R, 3)
                 for o in parts}
        size = bpy.data.objects[item_id + "__Shell"].dimensions
        print(item_id, "triangles", sum(triangles(o) for o in parts), "shell %.3f x %.3f x %.3f" % tuple(size), "reach", reach)


def clear_old(collection):
    """Removes the collection's previous objects with their mesh data, so rebuilt meshes keep
    their exact names instead of piling up as .001 copies."""
    coll = bpy.data.collections.get(collection)
    for obj in list(coll.objects) if coll else []:
        mesh = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if mesh is not None and mesh.users == 0:
            bpy.data.meshes.remove(mesh)


# begin() hides every other collection; Blender is shared, so their visibility is put back after
# (even if a builder fails).
_excluded = {layer.name: layer.exclude for layer in bpy.context.view_layer.layer_collection.children}
try:
    clear_old(COLLECTION)
    objects = build(begin(COLLECTION))
    report(objects)
    if globals().get("EXPORT", True):
        export(objects, EXPORT_PATH)
finally:
    for layer in bpy.context.view_layer.layer_collection.children:
        if layer.name != COLLECTION and layer.name in _excluded:
            layer.exclude = _excluded[layer.name]
