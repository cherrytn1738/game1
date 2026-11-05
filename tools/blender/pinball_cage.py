# Training Ground 2 of World 4, Pinball Cage: a batting cage built inside a giant pinball machine.
# Chrome hoops and nets inside a purple cabinet with glass side panels and a glass playfield cover for
# a roof, neon-ringed mushroom bumpers and slingshot kickers along the walls, two flippers by the
# batter, a plunger with a spring behind the pitching machine, a lit backbox over the far end with
# marquee lights, and neon lane arrows on the floor.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py (through
# tiny_cage_helpers.py); the mesh names are what TrainingCageStyles looks up.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\tiny_cage_helpers.py", encoding="utf-8").read())

COLLECTION = "PinballCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\PinballCage.fbx"
PURPLE = (0.35, 0.15, 0.6)
CHROME4 = (0.85, 0.87, 0.92)
NEON_PINK = (1.0, 0.3, 0.75)
NEON_CYAN = (0.3, 0.95, 1.0)
GLASS4 = (0.75, 0.85, 1.0)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = standard(coll, "Pin", ("frame", "nets", "machine", "screen", "plate", "lights"))
    cabinet, glass, bumpers, rings, flippers, kickers, plunger, backbox, marquee, arrows = (bmesh.new() for _ in range(10))
    # The cabinet: low solid side walls with a sloped top rail, outside the frame.
    wall_h = 4.6
    for x, sign in ((LEFT_X - 1.2, -1), (RIGHT_X + 1.2, 1)):
        box(cabinet, (x, (BACK_Y + FRONT_Y) / 2, wall_h / 2), (1.4, FRONT_Y - BACK_Y + 2.4, wall_h))
        box(cabinet, (x - sign * 0.2, (BACK_Y + FRONT_Y) / 2, wall_h + 0.3), (1.9, FRONT_Y - BACK_Y + 2.6, 0.6))
        # Glass above the wall, up to the playfield cover.
        box(glass, (x, (BACK_Y + FRONT_Y) / 2, (wall_h + 0.6 + HEIGHT + 0.6) / 2), (0.2, FRONT_Y - BACK_Y + 2.0, HEIGHT - wall_h))
    box(cabinet, ((LEFT_X + RIGHT_X) / 2, FRONT_Y + 1.4, wall_h / 2), (RIGHT_X - LEFT_X + 3.8, 1.4, wall_h))
    for x0, x1 in ((LEFT_X - 1.9, DOOR[0] - 0.4), (DOOR[1] + 0.4, RIGHT_X + 1.9)):
        box(cabinet, ((x0 + x1) / 2, BACK_Y - 1.2, wall_h / 2), (x1 - x0, 1.4, wall_h))
    box(glass, ((LEFT_X + RIGHT_X) / 2, (BACK_Y + FRONT_Y) / 2, HEIGHT + 0.6), (RIGHT_X - LEFT_X + 2.6, FRONT_Y - BACK_Y + 2.4, 0.15))
    # Mushroom bumpers with glowing rings, clear of the pitch line and the batter.
    for x, y in ((-11.5, 9.0), (-9.0, 17.5), (10.0, 13.0)):
        lathe(bumpers, [(0, 0), (1.6, 0), (1.6, 0.5), (1.1, 0.7), (1.1, 2.2), (2.3, 2.3), (2.3, 2.8), (1.6, 3.3), (0, 3.4)], 24,
              transform=Matrix.Translation((x, y, 0)))
        torus(rings, (x, y, 1.45), (0, 0, 1), 1.25, 0.2, segments=24, minor_segments=8)
        torus(rings, (x, y, 2.55), (0, 0, 1), 2.35, 0.12, segments=28, minor_segments=6)
    # Slingshot kickers: triangular blocks with neon edges along the side walls.
    for x, sign in ((LEFT_X + 1.6, 1), (RIGHT_X - 1.6, -1)):
        tri = [(x - sign * 0.9, -2.0), (x - sign * 0.9, 4.0), (x + sign * 1.8, -0.5)]
        prism(kickers, tri, 0.0, 1.6)
        tube(rings, (tri[1][0], tri[1][1], 1.65), (tri[2][0], tri[2][1], 1.65), 0.15, 8)
    # Flippers behind the batter (clear of the door), each a tapered paddle on a pivot post.
    for x, sign in ((-1.0, 1), (11.0, -1)):
        pivot = Vector((x, -11.0, 0))
        outline = [(math.cos(a) * 0.9, math.sin(a) * 0.9) for a in [math.pi / 2 + math.pi * i / 8 for i in range(9)]]
        outline += [(4.2 * sign, -0.35), (4.2 * sign + 0.25 * sign, 0.0), (4.2 * sign, 0.35)]
        if sign < 0:
            outline = [(-px, py) for px, py in outline]
            outline.reverse()
        turn = Matrix.Rotation(-0.35 * sign, 3, "Z")
        prism(flippers, [((turn @ Vector((px, py, 0))).x + pivot.x, (turn @ Vector((px, py, 0))).y + pivot.y) for px, py in outline], 0.2, 1.0)
        lathe(kickers, [(0, 0), (0.5, 0), (0.5, 1.2), (0, 1.2)], 12, transform=Matrix.Translation(pivot))
    # The plunger behind the machine: a spring coil, a rod and a red knob.
    base = Vector((PITCH.x, PITCH.y + 3.6, 2.2))
    coil = [base + Vector((0.55 * math.cos(t * 2 * math.pi * 7), 0.55 * math.sin(t * 2 * math.pi * 7) * 0 + t * 3.0, 0.55 * math.sin(t * 2 * math.pi * 7)))
            for t in [i / 140 for i in range(141)]]
    sweep(plunger, coil, 0.09, segments=6)
    tube(plunger, base, base + Vector((0, 4.4, 0)), 0.22, 12)
    ball(marquee, base + Vector((0, 4.8, 0)), 0.75, subdivisions=2)
    # The backbox: a tall lit board over the far end of the cabinet, with marquee lights round it.
    bx0, bx1, bz0, bz1 = LEFT_X - 1.0, RIGHT_X + 1.0, 6.0, 19.0
    by = FRONT_Y + 2.6
    box(backbox, ((bx0 + bx1) / 2, by, (bz0 + bz1) / 2), (bx1 - bx0, 1.6, bz1 - bz0))
    box(backbox, ((bx0 + bx1) / 2 - 8, by - 0.4, 3.0), (1.2, 1.2, 6.0))
    box(backbox, ((bx0 + bx1) / 2 + 8, by - 0.4, 3.0), (1.2, 1.2, 6.0))
    for k in range(26):
        t = k / 26
        perimeter = 2 * ((bx1 - bx0) + (bz1 - bz0))
        s = t * perimeter
        if s < bx1 - bx0:
            p = (bx0 + s, bz0 + 0.6)
        elif s < (bx1 - bx0) + (bz1 - bz0):
            p = (bx1 - 0.6, bz0 + (s - (bx1 - bx0)))
        elif s < 2 * (bx1 - bx0) + (bz1 - bz0):
            p = (bx1 - (s - (bx1 - bx0) - (bz1 - bz0)), bz1 - 0.6)
        else:
            p = (bx0 + 0.6, bz1 - (s - 2 * (bx1 - bx0) - (bz1 - bz0)))
        ball(marquee, (p[0], by - 0.9, p[1]), 0.35, subdivisions=1)
    star = []
    for i in range(10):
        r = 3.4 if i % 2 == 0 else 1.5
        a = math.pi / 2 + math.pi * i / 5
        star.append(((bx0 + bx1) / 2 + r * math.cos(a), 12.6 + r * math.sin(a)))
    outline_prism_xz = [(x, z) for x, z in star]
    front = [arrows.verts.new((x, by - 0.85, z)) for x, z in outline_prism_xz]
    back = [arrows.verts.new((x, by - 1.05, z)) for x, z in outline_prism_xz]
    arrows.faces.new(front)
    arrows.faces.new(list(reversed(back)))
    for i in range(len(front)):
        j = (i + 1) % len(front)
        arrows.faces.new((front[i], back[i], back[j], front[j]))
    # Neon lane arrows on the floor beside the pitch line, pointing to the machine.
    for y in (2.0, 7.0, 12.0):
        for x in (-6.0, 10.0):
            prism(arrows, [(x - 1.1, y), (x + 1.1, y), (x, y + 2.2)], 0.04, 0.1)
    objects += finish_all(coll, [
        ("PinCabinet", cabinet, PURPLE, "hard"), ("PinGlass", glass, GLASS4, "hard"), ("PinBumpers", bumpers, (0.95, 0.25, 0.3), "smooth"),
        ("PinBumperRings", rings, NEON_CYAN, "smooth"), ("PinFlippers", flippers, (0.98, 0.98, 0.98), "hard"),
        ("PinKickers", kickers, (0.98, 0.85, 0.2), "hard"), ("PinPlunger", plunger, CHROME4, "smooth"),
        ("PinBackbox", backbox, (0.15, 0.08, 0.3), "hard"), ("PinMarquee", marquee, NEON_PINK, "smooth"),
        ("PinArrows", arrows, NEON_PINK, "hard")])
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
