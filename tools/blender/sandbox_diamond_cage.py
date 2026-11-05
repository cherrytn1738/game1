# Training Ground 1 of World 4, Sandbox Diamond: a batting cage standing in a giant backyard sandbox.
# The standard cage in bright plastic colours inside a wooden sandbox border with corner seats, sand
# heaps round the edges, a toy pail lying on its side as the pitching machine (the ball comes out of
# its mouth), a rack of toy shovels for bats by the door, a sandcastle and a beach ball outside.
# Run inside Blender (e.g. via MCP). Layout and export rules come from cage_helpers.py (through
# tiny_cage_helpers.py); the mesh names are what TrainingCageStyles looks up.
exec(open(r"C:\Users\USER\Documents\RobloxProjects\MyGame\tools\blender\tiny_cage_helpers.py", encoding="utf-8").read())

COLLECTION = "SandboxDiamondCage"
EXPORT_PATH = r"C:\Users\USER\Documents\RobloxProjects\MyGame\assets\models\SandboxDiamondCage.fbx"
SAND = (0.93, 0.82, 0.58)


def build_and_export(export=True):
    coll = begin(COLLECTION)
    objects = standard(coll, "Sand", ("frame", "pads", "nets", "screen", "plate", "lights"))
    border, sand, pail, rim, handles, scoops, castle, beach = (bmesh.new() for _ in range(8))
    # The sandbox: a plank border round the cage with triangular corner seats.
    x0, x1, y0, y1, h, t = LEFT_X - 3.0, RIGHT_X + 3.0, BACK_Y - 2.2, FRONT_Y + 2.2, 1.8, 1.2
    door_gap = (DOOR[0] - 0.6, DOOR[1] + 0.6)
    box(border, ((x0 + x1) / 2, y1, h / 2), (x1 - x0 + t, t, h))
    box(border, (x0, (y0 + y1) / 2, h / 2), (t, y1 - y0 + t, h))
    box(border, (x1, (y0 + y1) / 2, h / 2), (t, y1 - y0 + t, h))
    box(border, ((x0 + door_gap[0]) / 2, y0, h / 2), (door_gap[0] - x0 + t / 2, t, h))
    box(border, ((door_gap[1] + x1) / 2, y0, h / 2), (x1 - door_gap[1] + t / 2, t, h))
    for cx, cy, sx, sy in ((x0, y1, 1, -1), (x1, y1, -1, -1), (x1, y0, -1, 1)):
        prism(border, [(cx, cy), (cx + sx * 3.6, cy), (cx, cy + sy * 3.6)], h - 0.1, h + 0.3)
    # Sand heaps along the inside of the border, clear of the cage frame.
    rng = random.Random(4)
    for k in range(16):
        side = k % 4
        if side == 0:
            p = Vector((x0 + 1.4, rng.uniform(y0 + 3, y1 - 3), 0))
        elif side == 1:
            p = Vector((x1 - 1.4, rng.uniform(y0 + 3, y1 - 3), 0))
        elif side == 2:
            p = Vector((rng.uniform(x0 + 3, x1 - 3), y1 - 1.3, 0))
        else:
            p = Vector((rng.choice((rng.uniform(x0 + 3, door_gap[0] - 2), rng.uniform(door_gap[1] + 2, x1 - 3))), y0 + 1.3, 0))
        blob(sand, p, Vector((rng.uniform(1.6, 2.6), rng.uniform(1.6, 2.6), rng.uniform(0.8, 1.6))), subdivisions=2, lump=0.15,
             seed=k, floor=0.0)
    # The pitching machine: a giant toy pail on its side, its mouth at the ball exit, on a sand heap.
    axis_y = PITCH.y + 0.3
    lathe(pail, [(0, 4.6), (2.3, 4.6), (2.9, 0.0), (2.7, 0.0), (2.12, 4.3), (0, 4.3)], 28,
          transform=Matrix.Translation((PITCH.x, axis_y, PITCH.z)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
    torus(rim, (PITCH.x, axis_y, PITCH.z), (0, 1, 0), 2.85, 0.22, segments=36, minor_segments=8)
    sweep(rim, [Vector((PITCH.x + 2.7 * math.cos(a) * 1.15, axis_y + 2.0, PITCH.z + 2.7 * math.sin(a) * 1.15))
                for a in [math.radians(-70 + 140 * i / 16) for i in range(17)]], 0.14, segments=8)
    blob(sand, Vector((PITCH.x, axis_y + 2.2, 0.0)), Vector((3.6, 3.4, 0.9)), subdivisions=2, lump=0.1, floor=0.0)
    # Toy shovels for bats: a little rack inside the cage by the door with three shovels on it.
    rack_x, rack_y = LEFT_X + 1.6, BACK_Y + 4.0
    for y in (rack_y - 2.2, rack_y + 2.2):
        box(border, (rack_x, y, 1.2), (0.5, 0.5, 2.4))
    box(border, (rack_x, rack_y, 2.3), (0.6, 5.0, 0.4))
    for k, y in enumerate((rack_y - 1.4, rack_y, rack_y + 1.4)):
        lean = Vector((0.35, 0.0, 1)).normalized()
        base = Vector((rack_x - 0.6, y, 1.8))
        top = base + lean * 4.2
        tube(handles, base, top, 0.12, 8)
        tube(handles, top + Vector((0, -0.45, 0)), top + Vector((0, 0.45, 0)), 0.1, 8)
        scoop = Matrix.Translation(base) @ Matrix.Rotation(math.radians(18), 4, "Y")
        lathe(scoops, [(0, -1.6), (0.55, -1.4), (0.7, -0.6), (0.4, 0.0), (0, 0.05)], 12, transform=scoop @ Matrix.Diagonal((1, 0.35, 1, 1)))
    # A sandcastle and a beach ball outside the far end, beyond the machine.
    cx, cy = -8.0, FRONT_Y + 6.4
    box(castle, (cx, cy, 1.0), (4.4, 4.4, 2.0))
    for dx in (-1.9, 1.9):
        for dy in (-1.9, 1.9):
            lathe(castle, [(0, 0), (0.9, 0), (0.8, 3.4), (1.0, 3.4), (1.0, 3.9), (0, 3.9)], 12, transform=Matrix.Translation((cx + dx, cy + dy, 0)))
    lathe(castle, [(0, 2.0), (1.1, 2.0), (0.95, 4.6), (1.2, 4.6), (0, 6.0)], 12, transform=Matrix.Translation((cx, cy, 0)))
    ball(beach, (8.5, FRONT_Y + 5.6, 1.6), 1.6, subdivisions=3)
    objects += finish_all(coll, [
        ("SandBorder", border, TOY_WOOD, "hard"), ("SandHeaps", sand, SAND, "smooth"), ("SandPail", pail, TOY_YELLOW, "smooth"),
        ("SandPailRim", rim, TOY_BLUE, "smooth"), ("SandShovelHandles", handles, TOY_RED, "smooth"),
        ("SandShovelScoops", scoops, TOY_BLUE, "smooth"), ("SandCastle", castle, SAND, "hard"), ("SandBeachBall", beach, TOY_RED, "smooth")])
    return report_and_export(objects, EXPORT_PATH, export)


build_and_export(globals().get("EXPORT", True))
