# World 4 (Tiny Town) runway props, house half: themed sections 6-10 in one batch.
#   Craft Table:       Crayon, PaperPlane, GluePuddle               filler PaperScrap   backdrop PaperHills
#   Bathtub Bay:       RubberDuck, SoapBar, BubbleFoam              filler Bubbles      backdrop TubWall
#   Bookshelf Cliffs:  Pencil, SpinningGlobe, ReadingLamp           filler Eraser       backdrop BookCliffs
#   Attic Treasures:   OldTrunk, RockingHorse, Cobweb               filler DustBunny    backdrop AtticWindow
#   Pillow Fort:       GiantPillow, BlanketTunnel, NightLight       filler PlushToy     (GiantPillow doubles as the pillow hills)
# Same conventions as runway_world4_home.py, whose helper half this script runs (with World 3's and
# World 2's helpers): one mesh per colour role, named <Template><Part>; each model rests on z = 0 with
# its footprint centred on the origin (the floating PaperPlane and Bubbles rest their lowest point on
# z = 0; RunwayDecor lifts them); props with a front face -Y. Every mesh stays under 20 units. A
# manifest (template -> mesh names) is written beside the FBX. Preview colours only: RunwayDecor
# tints every part in Roblox. Set EXPORT = False (and optionally ONLY = [template names]) before exec().
import bpy, bmesh, math, os, random, json
from mathutils import Vector, Matrix, Euler, noise

RUNWAY_WORLD4_HOME = r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\runway_world4_home.py"
_source = open(RUNWAY_WORLD4_HOME, encoding="utf-8").read()
_marker = "# ---------- 1. Giant Backyard ----------"
assert _marker in _source, "runway_world4_home.py layout changed"
exec(_source.partition(_marker)[0])

COLLECTION = "RunwayWorld4House"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayWorld4House.fbx"
MANIFEST_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\RunwayWorld4House.json"

PAPER = (0.97, 0.97, 0.95)
PORCELAIN = (0.96, 0.97, 0.98)
DUCK = (1.0, 0.85, 0.15)
PINK = (1.0, 0.6, 0.7)
WALNUT = (0.45, 0.28, 0.16)
OAK = (0.72, 0.5, 0.3)
BRASS4 = (0.85, 0.65, 0.3)
MOON = (1.0, 0.92, 0.6)
SILK = (0.95, 0.95, 0.98)
FUR = (0.62, 0.42, 0.26)


# ---------- 6. Craft Table ----------

def crayon(bm, bands, base, direction, length, radius=1.35):
    """A wax crayon from base along direction: a round body, a paper wrapper with dark bands, a cone tip."""
    d = Vector(direction).normalized()
    transform = Matrix.Translation(Vector(base)) @ align_z(d)
    body = length * 0.78
    lathe(bm, [(0, 0), (radius, 0), (radius, body), (radius * 0.92, body + 0.15), (radius * 0.45, length * 0.97), (0.3, length),
               (0, length)], 16, transform)
    for z in (length * 0.1, length * 0.66):
        lathe(bands, [(radius + 0.04, z), (radius + 0.08, z), (radius + 0.08, z + 0.55), (radius + 0.04, z + 0.55)], 16, transform)
        lathe(bands, [(0, z), (radius + 0.04, z), (radius + 0.04, z + 0.55), (0, z + 0.55)], 16, transform)
    # A raised wavy label strip between the bands.
    lathe(bands, [(radius + 0.03, length * 0.3), (radius + 0.06, length * 0.3), (radius + 0.06, length * 0.33),
                  (radius + 0.03, length * 0.33)], 16, transform)


def build_crayon(coll):
    a, b, c, bands = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    crayon(a, bands, (0, 0.6, 0), (0.08, 0.1, 1), 18.5)
    crayon(b, bands, (2.9, -0.4, 0), (0.25, -0.1, 1), 15.0)
    crayon(c, bands, (-3.4, -1.6, 1.35), (-0.15, -1.0, 0.0), 13.0)
    return [closed(coll, "CrayonA", a, TOY_RED), closed(coll, "CrayonB", b, TOY_BLUE), closed(coll, "CrayonC", c, TOY_GREEN),
            closed(coll, "CrayonBands", bands, INK)]


def build_paper_plane(coll):
    wings, fold = bmesh.new(), bmesh.new()
    # A folded paper plane, nose toward -Y, slightly nose-down as if gliding.
    length, span, depth = 13.0, 10.0, 2.6
    nose, tail = Vector((0, -length / 2, 0)), Vector((0, length / 2, 0))
    keel = Vector((0, length / 2, -depth))
    for side in (-1, 1):
        wing_tip = Vector((side * span / 2, length / 2, 0.3))
        mid = Vector((side * 0.5, length / 2, -0.2))
        # The wing (from the nose out to its tip) and the keel fold below the spine.
        prism_tri = [nose, tail + Vector((side * 0.02, 0, 0)), wing_tip]
        for tri, target in ((prism_tri, wings), ([nose, tail, keel], wings)):
            top = [bm_v for bm_v in tri]
            verts_top = [target.verts.new(p + Vector((0, 0, 0.09))) for p in top]
            verts_bottom = [target.verts.new(p - Vector((0, 0, 0.09))) for p in top]
            target.faces.new(verts_top)
            target.faces.new(list(reversed(verts_bottom)))
            for i in range(3):
                j = (i + 1) % 3
                target.faces.new((verts_top[i], verts_bottom[i], verts_bottom[j], verts_top[j]))
        stroke_points = [nose + (wing_tip - nose) * 0.12 + Vector((0, 0, 0.12)), tail + (wing_tip - tail) * 0.45 + Vector((0, 0, 0.12))]
        bar(fold, stroke_points[0], stroke_points[1], 0.35, 0.06, normal=(0, 0, 1))
    pitch = Matrix.Rotation(math.radians(-6), 4, "X")
    for target in (wings, fold):
        bmesh.ops.transform(target, matrix=pitch, verts=target.verts[:])
    return [closed(coll, "PlaneWings", wings, PAPER, hard=True), closed(coll, "PlaneStripe", fold, TOY_BLUE)]


def build_glue_puddle(coll):
    bottle, cap, label, glue = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    # A school glue bottle with a pointed orange cap, a drip down its side and a puddle at its foot.
    profile = [(0, 0), (2.6, 0), (2.8, 0.4), (2.8, 6.6), (2.5, 7.6), (1.4, 8.4), (0.9, 8.6), (0, 8.6)]
    lathe(bottle, profile, 28)
    lathe(label, [(2.82, 2.0), (2.88, 2.0), (2.88, 5.8), (2.82, 5.8)], 28)
    lathe(cap, [(0, 8.4), (1.0, 8.4), (1.05, 9.4), (0.75, 9.6), (0.42, 11.4), (0.2, 12.2), (0, 12.3)], 18)
    lathe(cap, [(0, 8.9), (1.25, 8.9), (1.25, 9.3), (0, 9.3)], 18)
    drip = [Vector((math.cos(-1.9) * 2.86, math.sin(-1.9) * 2.86, z)) for z in (7.2, 5.6, 3.4, 1.2, 0.3)]
    sweep(glue, drip, 0.42, segments=8, radius_end=0.6)
    ball(glue, drip[1], (0.6, 0.6, 0.8), subdivisions=1)
    ruffle(glue, (-1.4, -3.8, 0.12), 3.6, 0.24, 5, 0.06, rings=3, segments=24)
    ruffle(glue, (2.6, -3.0, 0.1), 1.8, 0.2, 4, 0.04, rings=2, segments=18)
    return [closed(coll, "GlueBottle", bottle, PAPER), closed(coll, "GlueCap", cap, TOY_ORANGE),
            closed(coll, "GlueLabel", label, TOY_BLUE), closed(coll, "GluePuddle", glue, (0.98, 0.98, 1.0))]


def build_paper_scrap(coll):
    paper, colour = bmesh.new(), bmesh.new()
    rng = random.Random(9)
    rough_rock(paper, (0, 0, 1.4), (1.5, 1.4, 1.4), rng, subdivisions=2, jitter=0.28, floor=0.0)
    rough_rock(colour, (2.4, 1.2, 0.8), (0.9, 0.8, 0.8), rng, subdivisions=1, jitter=0.3, floor=0.0)
    for k, (x, y, turn) in enumerate(((-2.4, 0.8, 0.4), (1.4, -2.0, -0.7))):
        target = colour if k == 0 else paper
        outline = [(x + 1.6 * math.cos(a + turn) * (1 + 0.25 * math.sin(3 * a)), y + 1.1 * math.sin(a + turn)) for a in
                   [2 * math.pi * i / 7 for i in range(7)]]
        prism(target, outline, 0.0, 0.12)
    return [closed(coll, "PaperBall", paper, PAPER, hard=True), closed(coll, "PaperScrapColor", colour, PINK, hard=True)]


def build_paper_hills(coll):
    a, b = bmesh.new(), bmesh.new()
    rng = random.Random(15)
    # Faceted folded-paper peaks, two tones of construction paper.
    for k, (x, y, w, h) in enumerate(((0, 0, 7.5, 13.5), (-6.8, 2.0, 5.5, 9.0), (6.5, 1.5, 5.8, 10.5), (-2.5, -4.5, 4.5, 6.5),
                                       (4.0, -4.0, 4.0, 5.5))):
        target = a if k % 2 == 0 else b
        sides = 5 + k % 2
        profile = [(0, 0), (w, 0), (w * 0.55, h * 0.5), (0, h)]
        start = len(target.verts)
        lathe(target, profile, sides, Matrix.Translation((x, y, 0)) @ Matrix.Rotation(rng.uniform(0, 1), 4, "Z"))
        target.verts.ensure_lookup_table()
        for v in target.verts[start:]:
            if v.co.z > 0.01:
                v.co += Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(-0.4, 0.4)))
    return [closed(coll, "PaperHillA", a, (0.55, 0.8, 1.0), hard=True), closed(coll, "PaperHillB", b, (1.0, 0.75, 0.5), hard=True)]


# ---------- 7. Bathtub Bay ----------

def build_rubber_duck(coll):
    body, beak, eyes = bmesh.new(), bmesh.new(), bmesh.new()
    # The classic bath duck facing -Y: a round body with an upturned tail, a big head and an orange beak.
    ball(body, (0, 0.8, 3.6), (5.0, 6.2, 3.8), subdivisions=4, floor=0.0)
    blob(body, Vector((0, 5.6, 5.6)), Vector((2.6, 2.4, 2.0)), subdivisions=3, rotation=Matrix.Rotation(-0.7, 3, "X"))
    ball(body, (0, -2.6, 8.8), (3.4, 3.2, 3.3), subdivisions=4)
    for side in (-1, 1):
        blob(body, Vector((side * 4.4, 1.2, 4.4)), Vector((1.0, 3.2, 1.8)), subdivisions=2, rotation=Matrix.Rotation(side * 0.25, 3, "Y"))
        ball(eyes, (side * 1.45, -5.3, 9.9), (0.62, 0.42, 0.78), subdivisions=2)
    lathe(beak, [(0, 0), (1.9, 0.2), (1.5, 1.6), (0.6, 2.3), (0, 2.4)], 16,
          Matrix.Translation((0, -5.3, 8.2)) @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Diagonal((1.2, 0.55, 1, 1)))
    return [closed(coll, "DuckBody", body, DUCK), closed(coll, "DuckBeak", beak, TOY_ORANGE), closed(coll, "DuckEyes", eyes, INK)]


def build_soap_bar(coll):
    soap, suds, dish = bmesh.new(), bmesh.new(), bmesh.new()
    # A soap dish with a rounded bar on it, crowned with suds.
    rounded_block(dish, (13.0, 8.6, 1.2), M((0, 0, 0.6)), corner=3.0, edge=0.5, corner_seg=5, edge_seg=2)
    loop_tube(dish, [Vector((x, y, 1.2)) for x, y in rounded_rect(13.0, 8.6, 3.0, 5)], rect_profile(-0.9, 0.0, 0.0, 0.8), (0, 0, 1))
    rounded_block(soap, (9.6, 5.8, 3.4), M((0, 0, 1.2 + 1.7), (0, 0, 0.12)), corner=2.4, edge=1.3, corner_seg=5, edge_seg=3)
    rng = random.Random(4)
    for k in range(11):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 2.4)
        ball(suds, (r * math.cos(a) * 1.4, r * math.sin(a) * 0.8, 4.6 + rng.uniform(0, 0.8)), rng.uniform(0.7, 1.5), subdivisions=2)
    return [closed(coll, "SoapBar", soap, PINK), closed(coll, "SoapSuds", suds, (1.0, 1.0, 1.0)),
            closed(coll, "SoapDish", dish, (0.55, 0.85, 0.85))]


def build_bubble_foam(coll):
    foam, shine = bmesh.new(), bmesh.new()
    rng = random.Random(22)
    # A heap of bath foam: many soft spheres, with a few big clear bubbles riding on top.
    for k in range(34):
        zf = 1 - k / 34
        a = k * 2.39996
        r = math.sqrt(max(0.0, 1 - zf * zf)) * 5.4
        p = Vector((r * math.cos(a), r * math.sin(a) * 0.85, 1.0 + zf * 5.0))
        ball(foam, p, rng.uniform(1.4, 2.3), subdivisions=2, floor=0.0)
    for p, s in (((1.5, -1.0, 8.6), 1.6), ((-2.4, 0.8, 8.0), 1.2), ((0.2, 2.2, 9.4), 0.9), ((3.6, 1.5, 6.8), 1.0)):
        ball(shine, p, s, subdivisions=3)
    return [closed(coll, "BubbleFoam", foam, (1.0, 1.0, 1.0)), closed(coll, "BubbleShine", shine, (0.8, 0.9, 1.0))]


def build_bubbles(coll):
    bubbles = bmesh.new()
    for p, s in (((0, 0, 1.6), 1.6), ((2.4, 0.8, 3.4), 1.0), ((-1.6, -0.8, 4.0), 0.8), ((0.8, -1.2, 5.6), 0.6)):
        ball(bubbles, p, s, subdivisions=3)
    return [closed(coll, "Bubbles", bubbles, (0.8, 0.92, 1.0))]


def build_tub_wall(coll):
    side, rim, feet, water = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    # A stretch of giant claw-foot bathtub along Y: its rounded side, rolled rim, water and gold feet.
    length, height, thick = 18.6, 11.0, 4.0
    sections = []
    for i in range(13):
        t = i / 12
        y = -length / 2 + length * t
        bulge = 0.8 * math.sin(math.pi * t)
        z0 = 2.4 + 0.6 * (1 - math.sin(math.pi * t))
        sections.append([Vector((-thick / 2 - bulge, y, z0 + 0.8)), Vector((thick / 2, y, z0)), Vector((thick / 2 + 0.2, y, height)),
                         Vector((-thick / 2 - bulge - 0.3, y, height))])
    loft(side, sections)
    rim_path = [Vector((-0.2 - 0.4 * math.sin(math.pi * (i / 12)), -length / 2 + length * i / 12, height + 0.2)) for i in range(13)]
    sweep(rim, rim_path, 1.3, segments=12)
    mbox(water, M((thick / 2 + 1.8, 0, height - 1.0)), (3.6, length - 1.0, 0.4))
    for y in (-length / 2 + 2.4, length / 2 - 2.4):
        claw = curve((0, y, 3.2), (-1.6, y, 1.8), (-2.2, y, 0.4), count=7)
        sweep(feet, claw, 0.9, segments=10, radius_end=0.6)
        for k in (-1, 0, 1):
            ball(feet, (-2.4, y + k * 0.7, 0.35), (0.7, 0.45, 0.35), subdivisions=1, floor=0.0)
    return [closed(coll, "TubSide", side, PORCELAIN), closed(coll, "TubRim", rim, (0.98, 0.98, 1.0)),
            closed(coll, "TubFeet", feet, BRASS4), closed(coll, "TubWater", water, (0.55, 0.8, 1.0), hard=True)]


# ---------- 8. Bookshelf Cliffs ----------

def pencil(body, wood, lead, ferrule, eraser, base, direction, length, radius=0.85):
    d = Vector(direction).normalized()
    transform = Matrix.Translation(Vector(base)) @ align_z(d)
    tip = length * 0.16
    lathe(eraser, [(0, 0), (radius * 0.92, 0), (radius * 0.95, length * 0.07), (0, length * 0.07)], 16, transform)
    lathe(ferrule, [(0, length * 0.06), (radius * 1.02, length * 0.06), (radius * 1.02, length * 0.13), (0, length * 0.13)], 16, transform)
    lathe(body, [(0, length * 0.12), (radius, length * 0.12), (radius, length - tip), (0, length - tip)], 6, transform)
    lathe(wood, [(0, length - tip - 0.01), (radius * 0.98, length - tip - 0.01), (radius * 0.3, length - tip * 0.25), (0, length - tip * 0.25)], 12,
          transform)
    lathe(lead, [(0, length - tip * 0.3), (radius * 0.33, length - tip * 0.3), (0.05, length), (0, length)], 10, transform)


def build_pencil(coll):
    body, wood, lead, ferrule, eraser, cup = (bmesh.new() for _ in range(6))
    # A pencil cup with three pencils standing in it, points up.
    lathe(cup, [(0, 0), (3.2, 0), (3.4, 6.5), (3.0, 6.5), (2.85, 0.4), (0, 0.4)], 24)
    for k, (x, y, lean_x, lean_y, length) in enumerate(((0.9, 0.4, 0.15, 0.1, 17.0), (-1.1, 0.6, -0.25, 0.05, 15.5),
                                                       (0.1, -1.1, 0.05, -0.3, 14.0))):
        pencil(body, wood, lead, ferrule, eraser, (x, y, 0.5), (lean_x, lean_y, 1), length)
    return [closed(coll, "PencilBody", body, TOY_YELLOW, hard=True), closed(coll, "PencilWood", wood, (0.95, 0.8, 0.6)),
            closed(coll, "PencilLead", lead, INK), closed(coll, "PencilFerrule", ferrule, CHROME, hard=True),
            closed(coll, "PencilEraser", eraser, PINK), closed(coll, "PencilCup", cup, TOY_BLUE)]


def build_spinning_globe(coll):
    ocean, land, stand = bmesh.new(), bmesh.new(), bmesh.new()
    # A desk globe on a tilted meridian arc, its continents raised over the blue sea.
    center, radius = Vector((0, 0, 9.8)), 5.6
    tilt = Matrix.Rotation(math.radians(23.5), 4, "Y")
    ball(ocean, center, radius, subdivisions=4)
    sphere = bmesh.new()
    bmesh.ops.create_icosphere(sphere, subdivisions=4, radius=1.0)
    sphere.faces.ensure_lookup_table()
    doomed = []
    for f in sphere.faces:
        c = f.calc_center_median()
        value = noise.noise(c * 1.6 + Vector((3.0, 1.0, 0.0))) + 0.35 * noise.noise(c * 4.0)
        if value < 0.12 or abs(c.z) > 0.9:
            doomed.append(f)
    bmesh.ops.delete(sphere, geom=doomed, context="FACES")
    for v in sphere.verts:
        v.co = center + (tilt.to_3x3() @ v.co) * (radius + 0.12)
    # Give the land a little thickness so it reads as raised.
    land_mesh = bpy.data.meshes.new("_globe_land_tmp")
    sphere.to_mesh(land_mesh)
    sphere.free()
    land.from_mesh(land_mesh)
    bpy.data.meshes.remove(land_mesh)
    bmesh.ops.solidify(land, geom=land.faces[:], thickness=0.12)
    # Meridian arc, axle pins and a round foot on a short column.
    arc_points = [center + tilt.to_3x3() @ Vector(((radius + 0.7) * math.sin(a), 0, (radius + 0.7) * math.cos(a)))
                  for a in [math.radians(-160 + 320 * i / 32) for i in range(33)]]
    beam(stand, arc_points, (0.5, 0.9), ref=(0, 1, 0), corner=0.3, seg=1)
    for sign in (-1, 1):
        capsule(stand, center + tilt.to_3x3() @ Vector((0, 0, sign * (radius - 0.2))), center + tilt.to_3x3() @ Vector((0, 0, sign * (radius + 1.0))), 0.25)
    lathe(stand, [(0, 0), (3.8, 0), (3.8, 0.5), (3.0, 1.0), (0.8, 1.3), (0.6, 3.6), (0.0, 3.6)], 24)
    return [closed(coll, "GlobeOcean", ocean, (0.25, 0.55, 0.9)), closed(coll, "GlobeLand", land, (0.45, 0.78, 0.35)),
            closed(coll, "GlobeStand", stand, BRASS4)]


def build_reading_lamp(coll):
    metal, joints, bulb = bmesh.new(), bmesh.new(), bmesh.new()
    # An articulated desk lamp: round base, two arm segments with springs, a cone shade bending down.
    lathe(metal, [(0, 0), (4.2, 0), (4.2, 0.6), (3.4, 1.2), (0, 1.3)], 28)
    a = Vector((0, 1.2, 1.3))
    b = Vector((0, -1.6, 10.0))
    c = Vector((0, -7.2, 14.6))
    for p, q in ((a, b), (b, c)):
        for side in (-0.45, 0.45):
            capsule(metal, p + Vector((side, 0, 0)), q + Vector((side, 0, 0)), 0.28)
        sweep(joints, [p + (q - p) * t + Vector((0, 0, 0.45)) for t in (0.3, 0.7)], 0.22, segments=6)
    for p in (a, b, c):
        lathe(joints, [(0, -0.9), (0.75, -0.9), (0.75, 0.9), (0, 0.9)], 14, Matrix.Translation(p) @ align_z(Vector((1, 0, 0))))
    shade_axis = Vector((0, -0.45, -1)).normalized()
    shade = Matrix.Translation(c + Vector((0, -0.6, -0.3))) @ align_z(-shade_axis)
    lathe(metal, [(0, 0.6), (1.2, 0.6), (1.6, 0.0), (3.4, -3.4), (3.6, -3.8), (3.3, -3.8), (1.2, -0.3), (0, -0.2)], 24, shade)
    ball(bulb, (shade @ Vector((0, 0, -2.4))), 1.5, subdivisions=3)
    return [closed(coll, "LampMetal", metal, TOY_RED), closed(coll, "LampJoints", joints, (0.2, 0.2, 0.24)),
            closed(coll, "LampBulb", bulb, MOON)]


def build_eraser(coll):
    pink, blue = bmesh.new(), bmesh.new()
    rounded_block(pink, (6.2, 2.8, 1.9), M((0, 0, 0.95), (0, 0, 0.1)), corner=0.5, edge=0.35, corner_seg=3, edge_seg=2)
    rounded_block(blue, (2.8, 2.9, 2.0), M((1.6, 0.16, 0.95), (0, 0, 0.1)), corner=0.5, edge=0.35, corner_seg=3, edge_seg=2)
    return [closed(coll, "EraserPink", pink, PINK), closed(coll, "EraserBlue", blue, TOY_BLUE)]


def book(covers, pages, center, size, turn=0.0, standing=False):
    """A closed hardback: cover boards wrapped round a cream page block, spine on -X."""
    w, d, h = size
    rot = Matrix.Rotation(turn, 4, "Z")
    if standing:
        rot = rot @ Matrix.Rotation(math.pi / 2, 4, "Y")
    m = Matrix.Translation(Vector(center)) @ rot
    rounded_block(pages, (w - 0.5, d - 0.4, h - 0.3), m @ Matrix.Translation((0.25, 0, 0)), corner=0.08, edge=0.05, corner_seg=1, edge_seg=1)
    for z in (-h / 2 + 0.12, h / 2 - 0.12):
        rounded_block(covers, (w, d, 0.24), m @ Matrix.Translation((0, 0, z)), corner=0.2, edge=0.06, corner_seg=2, edge_seg=1)
    rounded_block(covers, (0.5, d, h), m @ Matrix.Translation((-w / 2 + 0.25, 0, 0)), corner=0.2, edge=0.15, corner_seg=2, edge_seg=1)


def build_book_cliffs(coll):
    covers = [bmesh.new(), bmesh.new(), bmesh.new()]
    pages = bmesh.new()
    rng = random.Random(31)
    # A cliff of giant books: a stepped pile, the tallest stack at the back, some leaning.
    stacks = [((-4.0, 2.0), 7), ((3.6, 2.4), 5), ((0.0, -3.0), 3), ((-5.2, -3.6), 2), ((5.6, -3.0), 2)]
    k = 0
    for (x, y), count in stacks:
        z = 0.0
        for i in range(count):
            h = rng.uniform(1.7, 2.6)
            size = (rng.uniform(7.2, 9.0), rng.uniform(5.4, 6.4), h)
            book(covers[k % 3], pages, (x + rng.uniform(-0.5, 0.5), y + rng.uniform(-0.4, 0.4), z + h / 2), size, turn=rng.uniform(-0.2, 0.2))
            z += h
            k += 1
    return [closed(coll, "BookCoversA", covers[0], TOY_RED, hard=True), closed(coll, "BookCoversB", covers[1], TOY_BLUE, hard=True),
            closed(coll, "BookCoversC", covers[2], TOY_GREEN, hard=True), closed(coll, "BookPages", pages, (0.98, 0.94, 0.84), hard=True)]


# ---------- 9. Attic Treasures ----------

def build_old_trunk(coll):
    body, bands, lid = bmesh.new(), bmesh.new(), bmesh.new()
    w, d, h = 13.0, 7.6, 6.4
    rounded_block(body, (w, d, h), M((0, 0, h / 2)), corner=0.5, edge=0.3, corner_seg=2, edge_seg=1)
    # A domed lid, propped a little open toward the batter.
    hinge = Matrix.Translation((0, d / 2, h)) @ Matrix.Rotation(math.radians(18), 4, "X") @ Matrix.Translation((0, -d / 2, 0))
    outline = [((-d / 2) * math.cos(math.pi * i / 8), 1.2 + 1.8 * math.sin(math.pi * i / 8)) for i in range(9)] + [(d / 2, 0.0), (-d / 2, 0.0)]
    outline_prism(lid, [(y, z) for y, z in outline], hinge @ YZ, -w / 2, w / 2)
    for x in (-w / 2 + 1.6, -0.0, w / 2 - 1.6):
        mbox(bands, M((x, 0, h / 2)), (0.7, d + 0.16, h + 0.06))
        path = [hinge @ Vector((x, (-d / 2 - 0.1) * math.cos(math.pi * i / 8), 1.2 + (1.8 + 0.1) * math.sin(math.pi * i / 8))) for i in range(9)]
        beam(bands, path, (0.7, 0.2), ref=(0, 0, 1), corner=0.2, seg=1)
    rounded_block(bands, (1.8, 0.5, 2.2), M((0, -d / 2 - 0.25, h - 0.6)), corner=0.3, edge=0.1, corner_seg=2, edge_seg=1)
    for side in (-1, 1):
        torus(bands, Matrix.Translation((side * (w / 2 + 0.35), 0, h * 0.65)) @ align_z(Vector((1, 0, 0))), 1.0, 0.18, seg=16, tseg=6)
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            for z in (0.3, h - 0.3):
                ball(bands, (x * 0.99, y * 0.99, z), 0.5, subdivisions=1)
    return [closed(coll, "TrunkBody", body, WALNUT, hard=True), closed(coll, "TrunkBands", bands, BRASS4),
            closed(coll, "TrunkLid", lid, (0.55, 0.34, 0.2), hard=True)]


def build_rocking_horse(coll):
    body, rockers, mane, saddle = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    # A wooden rocking horse, its side toward the batter (long axis along Y, head toward -Y).
    for x in (-1.6, 1.6):
        points = [Vector((x, 8.0 * math.sin(a), 6.5 - 6.5 * math.cos(a) * 1.0 + 0.4)) for a in [math.radians(-62 + 124 * i / 20) for i in range(21)]]
        beam(rockers, points, (0.7, 0.9), ref=(1, 0, 0), corner=0.4, seg=1)
    for x in (-1.6, 1.6):
        for y in (-3.0, 3.0):
            sweep(body, [Vector((x * 0.6, y * 0.8, 6.2)), Vector((x, y, 1.2))], 0.55, segments=10)
    capsule(rockers, (-1.8, -3.0, 1.3), (1.8, -3.0, 1.3), 0.32)
    capsule(rockers, (-1.8, 3.0, 1.3), (1.8, 3.0, 1.3), 0.32)
    ball(body, (0, 0, 7.2), (2.0, 4.6, 1.9), subdivisions=3)
    sweep(body, [Vector((0, -3.4, 7.8)), Vector((0, -4.6, 9.8)), Vector((0, -5.2, 11.2))], 1.0, segments=12, radius_end=0.9)
    blob(body, Vector((0, -6.0, 11.4)), Vector((1.1, 2.0, 1.2)), subdivisions=3, rotation=Matrix.Rotation(-0.35, 3, "X"))
    for side in (-1, 1):
        lathe(body, [(0, 0), (0.45, 0), (0.0, 1.1)], 8, Matrix.Translation((side * 0.55, -5.0, 12.2)))
        ball(mane, (side * 0.9, -6.4, 11.9), 0.28, subdivisions=1)
    for k in range(7):
        t = k / 6
        p = Vector((0, -4.0 - 1.4 * t, 10.6 + 1.6 * t * (1.2 - t)))
        blob(mane, p + Vector((0, 0.6, 0.6)), Vector((0.5, 0.8, 0.9)), subdivisions=1, lump=0.2, seed=k)
    sweep(mane, curve((0, 4.4, 7.6), (0, 6.2, 7.2), (0, 6.8, 4.8), count=8), 0.6, segments=8, radius_end=0.25)
    rounded_block(saddle, (4.4, 3.0, 0.5), M((0, 0.4, 8.9)), corner=0.9, edge=0.2, corner_seg=3, edge_seg=1)
    for side in (-1, 1):
        mbox(saddle, M((side * 2.0, 0.4, 7.9)), (0.2, 2.6, 2.0))
    return [closed(coll, "HorseBody", body, (0.98, 0.94, 0.86)), closed(coll, "HorseRockers", rockers, TOY_RED, hard=True),
            closed(coll, "HorseMane", mane, (0.55, 0.32, 0.16)), closed(coll, "HorseSaddle", saddle, TOY_BLUE)]


def build_cobweb(coll):
    posts, silk, spider = bmesh.new(), bmesh.new(), bmesh.new()
    # A cobweb strung between an old broom handle and a leaning stick, facing the batter, with a
    # little spider hanging from it.
    cyl(posts, (-6.8, 0, 0), 0.45, 17.5, segments=10, direction=(0.12, 0, 1))
    cyl(posts, (6.4, 0, 0), 0.4, 15.0, segments=10, direction=(-0.2, 0, 1))
    center = Vector((0, 0, 9.5))
    anchors = [Vector((-6.8 + 0.12 * z, 0, z)) for z in (5.0, 9.5, 14.5)] + [Vector((6.4 - 0.2 * z, 0, z)) for z in (13.0, 8.5, 4.5)]
    anchors.insert(3, Vector((0.4, 0, 16.6)))
    anchors.append(Vector((-0.6, 0, 2.6)))
    order = sorted(anchors, key=lambda p: math.atan2(p.z - center.z, p.x - center.x))
    for p in order:
        sweep(silk, [center, center + (p - center) * 0.5 + Vector((0, 0.3, -0.3)), p], 0.07, segments=4)
    for ring in range(1, 6):
        f = ring / 6
        loop = [center + (p - center) * f + Vector((0, 0.2, -0.25 * f)) for p in order]
        for a, b in zip(loop, loop[1:] + loop[:1]):
            sweep(silk, [a, (a + b) / 2 + Vector((0, 0, -0.25)), b], 0.05, segments=4, caps=True)
    thread = [center + Vector((1.6, 0, -1.4)), center + Vector((1.6, -0.2, -4.4))]
    sweep(silk, thread, 0.04, segments=4)
    s = thread[-1] + Vector((0, 0, -0.8))
    ball(spider, s, (0.9, 0.8, 0.8), subdivisions=2)
    ball(spider, s + Vector((0, -0.2, 1.0)), 0.55, subdivisions=2)
    for side in (-1, 1):
        for k in range(4):
            a = -0.9 + 0.6 * k
            leg = [s + Vector((side * 0.6, 0, 0)), s + Vector((side * 1.6, math.sin(a) * 0.6, 0.6 + math.cos(a) * 0.3)),
                   s + Vector((side * 2.2, math.sin(a) * 1.0, -0.6))]
            sweep(spider, curve(*leg, count=5), 0.1, segments=4)
    return [closed(coll, "CobwebPosts", posts, OAK), closed(coll, "CobwebSilk", silk, SILK), closed(coll, "CobwebSpider", spider, INK)]


def build_dust_bunny(coll):
    fluff, eyes = bmesh.new(), bmesh.new()
    blob(fluff, Vector((0, 0, 1.9)), Vector((2.3, 2.1, 1.9)), subdivisions=4, lump=0.35, lump_scale=3.2, seed=2.0, floor=0.0)
    for side in (-1, 1):
        ball(eyes, (side * 0.7, -1.95, 2.3), (0.42, 0.3, 0.5), subdivisions=2)
    return [closed(coll, "DustFluff", fluff, (0.62, 0.6, 0.66)), closed(coll, "DustEyes", eyes, (0.98, 0.98, 0.98))]


def build_attic_window(coll):
    frame, glass, wall = bmesh.new(), bmesh.new(), bmesh.new()
    # A round attic window in a slice of plank wall, moonlight glowing through its panes (faces -Y).
    center, radius = Vector((0, 0, 10.0)), 6.6
    for k in range(7):
        mbox(wall, M((-8.4 + 2.8 * k, 0.6, 9.5), (0, 0, 0)), (2.7, 1.2, 19.0))
    loop = [center + Vector((radius * math.cos(a), -0.2, radius * math.sin(a))) for a in [2 * math.pi * i / 48 for i in range(48)]]
    loop_tube(frame, loop, rect_profile(-0.2, 1.1, -0.9, 0.9), (0, 1, 0))
    lathe(glass, [(0, -0.1), (radius, -0.1), (radius, 0.1), (0, 0.1)], 48, Matrix.Translation(center) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    for a in (0, math.pi / 2):
        d = Vector((math.cos(a), 0, math.sin(a)))
        bar(frame, center - d * radius, center + d * radius, 0.7, 0.6, normal=(0, -1, 0))
    mbox(frame, M((0, -0.6, center.z - radius - 1.2)), (9.0, 1.6, 0.8))
    return [closed(coll, "WindowFrame", frame, OAK, hard=True), closed(coll, "WindowGlass", glass, (0.75, 0.85, 1.0)),
            closed(coll, "WindowWall", wall, WALNUT, hard=True)]


# ---------- 10. Pillow Fort ----------

def pillow(cloth_bm, seam, center, size, rotation=Matrix(), puff=0.55):
    """A plump square pillow: a squashed super-ellipse with pinched corners and piping round its edge."""
    w, d, h = size
    m = Matrix.Translation(Vector(center)) @ rotation
    rings, segments = 14, 40
    top, bottom = [], []
    for r in range(rings + 1):
        f = r / rings
        row_t, row_b = [], []
        for k in range(segments):
            a = 2 * math.pi * k / segments
            c, s = math.cos(a), math.sin(a)
            p = 4.0
            scale = 1 / ((abs(c) ** p + abs(s) ** p) ** (1 / p))
            x, y = w / 2 * c * scale * f, d / 2 * s * scale * f
            corner = (abs(c * scale) * abs(s * scale)) ** 2
            thickness = h / 2 * (1 - f ** 2.4) ** puff * (1 - 0.35 * corner * f) + 0.05
            row_t.append(cloth_bm.verts.new(m @ Vector((x, y, thickness))))
            row_b.append(cloth_bm.verts.new(m @ Vector((x, y, -thickness))))
        top.append(row_t)
        bottom.append(row_b)
    ct = cloth_bm.verts.new(m @ Vector((0, 0, h / 2 + 0.05)))
    cb = cloth_bm.verts.new(m @ Vector((0, 0, -h / 2 - 0.05)))
    for k in range(segments):
        j = (k + 1) % segments
        cloth_bm.faces.new((ct, top[1][k], top[1][j]))
        cloth_bm.faces.new((cb, bottom[1][j], bottom[1][k]))
        for r in range(1, rings):
            cloth_bm.faces.new((top[r][k], top[r + 1][k], top[r + 1][j], top[r][j]))
            cloth_bm.faces.new((bottom[r][j], bottom[r + 1][j], bottom[r + 1][k], bottom[r][k]))
        cloth_bm.faces.new((top[rings][k], bottom[rings][k], bottom[rings][j], top[rings][j]))
    edge = [m @ Vector((w / 2 * math.cos(a) / ((abs(math.cos(a)) ** 4 + abs(math.sin(a)) ** 4) ** 0.25),
                        d / 2 * math.sin(a) / ((abs(math.cos(a)) ** 4 + abs(math.sin(a)) ** 4) ** 0.25), 0))
            for a in [2 * math.pi * k / segments for k in range(segments)]]
    loop_tube(seam, edge, circle_profile(0.28, 6), m.to_3x3() @ Vector((0, 0, 1)))
    ball(seam, m @ Vector((0, 0, h / 2 - 0.05)), (0.7, 0.7, 0.3), subdivisions=2)


def build_giant_pillow(coll):
    a, b, seam = bmesh.new(), bmesh.new(), bmesh.new()
    pillow(a, seam, (0, 0, 2.6), (15.0, 15.0, 5.2), Matrix.Rotation(0.1, 4, "Z"))
    pillow(b, seam, (0.8, 0.4, 6.4), (11.0, 11.0, 4.2), Matrix.Rotation(-0.35, 4, "Z") @ Matrix.Rotation(0.12, 4, "X"))
    return [closed(coll, "PillowClothA", a, (0.6, 0.55, 0.95)), closed(coll, "PillowClothB", b, (1.0, 0.75, 0.8)),
            closed(coll, "PillowSeam", seam, (1.0, 0.95, 0.85))]


def build_blanket_tunnel(coll):
    blanket, stripes, cushions = bmesh.new(), bmesh.new(), bmesh.new()
    # A blanket draped over two cushion walls into a tunnel running along Y (its opening faces the batter).
    length, half = 16.0, 7.6
    for x in (-half + 1.6, half - 1.6):
        rounded_block(cushions, (3.2, length - 2.0, 7.0), M((x, 0, 3.5)), corner=1.2, edge=1.2, corner_seg=4, edge_seg=3)
    columns = 26
    rows = 12

    def point(i, j):
        u = i / columns
        v = j / rows
        a = math.pi * u
        x = -half * math.cos(a) * (1 + 0.04 * math.sin(v * 9))
        z = 7.2 + 3.6 * math.sin(a) * (1 - 0.15 * math.sin(v * math.pi * 3 + u * 2))
        if u < 0.06 or u > 0.94:
            z = 7.2 * (1 - abs(u - 0.5) * 0.0) - (0.06 - min(u, 1 - u)) * 90
        y = -length / 2 + length * v
        return Vector((x * (1.08 if u < 0.06 or u > 0.94 else 1), y, max(0.1, z)))
    quads_a, quads_b = [], []
    for i in range(columns):
        for j in range(rows):
            quad = [point(i, j), point(i + 1, j), point(i + 1, j + 1), point(i, j + 1)]
            (quads_a if (i // 3) % 2 == 0 else quads_b).append(quad)
    objects = [closed(coll, "TunnelCushions", cushions, (0.55, 0.75, 1.0))]
    for name, quads, rgb in (("TunnelBlanket", quads_a, (0.4, 0.4, 0.85)), ("TunnelStripes", quads_b, (1.0, 0.85, 0.4))):
        bm = bmesh.new()
        for quad in quads:
            top = [bm.verts.new(p) for p in quad]
            bottom = [bm.verts.new(p - Vector((0, 0, 0.25))) for p in quad]
            bm.faces.new(top)
            bm.faces.new(list(reversed(bottom)))
            for k in range(4):
                n = (k + 1) % 4
                bm.faces.new((top[k], bottom[k], bottom[n], top[n]))
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
        objects.insert(0 if name == "TunnelBlanket" else 1, closed(coll, name, bm, rgb))
    return objects


def build_night_light(coll):
    base, glow, face = bmesh.new(), bmesh.new(), bmesh.new()
    # A plug-in night light: a round wall plate on a little stand, a glowing crescent moon and star.
    rounded_block(base, (9.0, 2.0, 1.2), M((0, 0.4, 0.6)), corner=0.9, edge=0.4, corner_seg=3, edge_seg=2)
    rounded_block(base, (6.2, 1.4, 12.0), M((0, 0.6, 6.6)), corner=0.6, edge=0.5, corner_seg=3, edge_seg=2)
    crescent = []
    for i in range(33):
        a = math.radians(40 + 280 * i / 32)
        crescent.append((5.2 * math.cos(a), 9.0 + 5.2 * math.sin(a)))
    for i in range(33):
        a = math.radians(320 - 280 * i / 32)
        crescent.append((1.8 + 4.2 * math.cos(a) * 0.98, 9.6 + 4.2 * math.sin(a)))
    outline_prism(glow, crescent, M((-0.6, -0.4, 0)) @ XZ, -0.9, 0.0)
    star = []
    for i in range(10):
        r = 1.8 if i % 2 == 0 else 0.8
        a = math.pi / 2 + math.pi * i / 5
        star.append((4.4 + r * math.cos(a), 12.4 + r * math.sin(a)))
    outline_prism(glow, star, M((0, -0.4, 0)) @ XZ, -0.7, 0.0)
    # A sleepy face on the moon.
    for x, z in ((-2.2, 10.4),):
        bar(face, (x - 0.6, -1.36, z), (x + 0.6, -1.36, z - 0.2), 0.25, 0.1)
    bar(face, (-2.8, -1.36, 7.4), (-1.6, -1.36, 7.0), 0.25, 0.1)
    return [closed(coll, "NightLightBase", base, (0.96, 0.96, 0.98), hard=True), closed(coll, "NightLightGlow", glow, MOON, hard=True),
            closed(coll, "NightLightFace", face, (0.5, 0.4, 0.2))]


def build_plush_toy(coll):
    fur, snout, eyes = bmesh.new(), bmesh.new(), bmesh.new()
    # A little stuffed bear sitting up, facing -Y.
    ball(fur, (0, 0.2, 1.9), (1.7, 1.5, 1.9), subdivisions=3, floor=0.0)
    ball(fur, (0, -0.2, 4.5), 1.45, subdivisions=3)
    for side in (-1, 1):
        ball(fur, (side * 1.05, -0.1, 5.7), 0.55, subdivisions=2)
        ball(snout, (side * 1.05, -0.4, 5.7), (0.3, 0.2, 0.3), subdivisions=1)
        capsule(fur, (side * 1.4, -0.2, 3.0), (side * 2.0, -0.9, 1.9), 0.5)
        capsule(fur, (side * 0.9, -0.6, 0.6), (side * 1.2, -1.9, 0.6), 0.6)
        ball(snout, (side * 1.2, -2.4, 0.6), (0.45, 0.15, 0.45), subdivisions=1)
        ball(eyes, (side * 0.5, -1.45, 4.85), 0.2, subdivisions=1)
    ball(snout, (0, -1.4, 4.2), (0.7, 0.45, 0.5), subdivisions=2)
    ball(eyes, (0, -1.85, 4.4), (0.25, 0.15, 0.2), subdivisions=1)
    ball(snout, (0, -1.3, 2.0), (1.0, 0.4, 1.1), subdivisions=2)
    return [closed(coll, "PlushFur", fur, FUR), closed(coll, "PlushSnout", snout, (0.95, 0.85, 0.7)), closed(coll, "PlushEyes", eyes, INK)]


BUILDERS = [
    ("Crayon", build_crayon), ("PaperPlane", build_paper_plane), ("GluePuddle", build_glue_puddle), ("PaperScrap", build_paper_scrap),
    ("PaperHills", build_paper_hills),
    ("RubberDuck", build_rubber_duck), ("SoapBar", build_soap_bar), ("BubbleFoam", build_bubble_foam), ("Bubbles", build_bubbles),
    ("TubWall", build_tub_wall),
    ("Pencil", build_pencil), ("SpinningGlobe", build_spinning_globe), ("ReadingLamp", build_reading_lamp), ("Eraser", build_eraser),
    ("BookCliffs", build_book_cliffs),
    ("OldTrunk", build_old_trunk), ("RockingHorse", build_rocking_horse), ("Cobweb", build_cobweb), ("DustBunny", build_dust_bunny),
    ("AtticWindow", build_attic_window),
    ("GiantPillow", build_giant_pillow), ("BlanketTunnel", build_blanket_tunnel), ("NightLight", build_night_light),
    ("PlushToy", build_plush_toy),
]

build_and_export(globals().get("ONLY"), globals().get("EXPORT", True))
