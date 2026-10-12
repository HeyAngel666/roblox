"""
Dragão de Lâminas do Reino - modelado no Blender (bpy).

Roda com o Blender (ou o módulo bpy do Python):
    blender --background --python build/blender/dragon.py -- build/assets
    python build/blender/dragon.py build/assets      (com "pip install bpy")

Gera em build/assets/:
    dragon.blend   arquivo do Blender (editável)
    dragon.fbx     modelo para outros programas
    dragon.json    triângulos de cada parte (usado pelo build do Roblox)

O dragão é dividido em partes rígidas (corpo, pescoço, cabeça, mandíbula,
cauda e asas). No Roblox cada parte vira um conjunto de triângulos ligado
por juntas Motor6D, e o jogo anima as juntas (bater de asas, cauda, etc.).

Eixos aqui (Blender): X = direita, Y = frente (cabeça), Z = cima.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv
out_dir = argv[argv.index("--") + 1] if "--" in argv else (argv[1] if len(argv) > 1 else "build/assets")
os.makedirs(out_dir, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)

PIECES = {}  # nome -> {"parent": str|None, "pivot": Vector, "objects": [(obj, colorKey)]}


def piece(name, parent, pivot):
    PIECES[name] = {"parent": parent, "pivot": Vector(pivot), "objects": []}


def new_object(name, verts, edges=(), faces=()):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], list(edges), list(faces))
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def add(piece_name, obj, color):
    PIECES[piece_name]["objects"].append((obj, color))
    return obj


def skin_chain(piece_name, name, points, color="auto", subdiv=1, ratio=1.0, flat=1.0):
    """Cadeia de esferas/cilindros orgânica (modificador Skin).
    points = [(x, y, z, raio), ...]; flat < 1 achata na vertical."""
    verts = [(p[0], p[1], p[2]) for p in points]
    edges = [(i, i + 1) for i in range(len(points) - 1)]
    obj = new_object(name, verts, edges)
    obj.modifiers.new("Skin", "SKIN")
    data = obj.data.skin_vertices[0].data
    for i, p in enumerate(points):
        data[i].radius = (p[3], p[3] * flat)
    data[0].use_root = True
    if subdiv > 0:
        sub = obj.modifiers.new("Suavizar", "SUBSURF")
        sub.levels = subdiv
        sub.render_levels = subdiv
    if ratio < 1.0:
        dec = obj.modifiers.new("LowPoly", "DECIMATE")
        dec.ratio = ratio
    obj.modifiers.new("Triangulos", "TRIANGULATE")
    return add(piece_name, obj, color)


def cone(piece_name, name, base, tip, radius, sides=4, color="spike"):
    base, tip = Vector(base), Vector(tip)
    axis = (tip - base).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    verts = [tip]
    for i in range(sides):
        a = 2 * math.pi * i / sides
        verts.append(base + (u * math.cos(a) + v * math.sin(a)) * radius)
    faces = [(0, 1 + i, 1 + (i + 1) % sides) for i in range(sides)]
    faces.append(tuple(range(sides, 0, -1)))
    obj = new_object(name, verts, faces=faces)
    obj.modifiers.new("Triangulos", "TRIANGULATE")
    return add(piece_name, obj, color)


def tube(piece_name, name, points, sides=4, color="auto"):
    """Tubo afunilado low-poly (ossos, chifres, patas). points = [(x, y, z, raio), ...]"""
    centers = [Vector(p[:3]) for p in points]
    verts, faces = [], []
    for i, p in enumerate(points):
        axis = (centers[min(i + 1, len(centers) - 1)] - centers[max(i - 1, 0)]).normalized()
        helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
        u = axis.cross(helper).normalized()
        v = axis.cross(u).normalized()
        for k in range(sides):
            a = 2 * math.pi * k / sides + math.pi / sides
            verts.append(centers[i] + (u * math.cos(a) + v * math.sin(a)) * p[3])
    for i in range(len(points) - 1):
        for k in range(sides):
            a, b = i * sides + k, i * sides + (k + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    # tampas: ponta fechada em cone
    start_cap = len(verts)
    verts.append(centers[0] - (centers[1] - centers[0]).normalized() * points[0][3] * 0.6)
    end_cap = len(verts)
    verts.append(centers[-1] + (centers[-1] - centers[-2]).normalized() * points[-1][3] * 0.8)
    last = (len(points) - 1) * sides
    for k in range(sides):
        faces.append((start_cap, (k + 1) % sides, k))
        faces.append((end_cap, last + k, last + (k + 1) % sides))
    obj = new_object(name, verts, faces=faces)
    obj.modifiers.new("Triangulos", "TRIANGULATE")
    return add(piece_name, obj, color)


def membrane(piece_name, name, triangles, color="wing"):
    verts, faces = [], []
    for tri in triangles:
        start = len(verts)
        verts.extend(tri)
        faces.append((start, start + 1, start + 2))
    obj = new_object(name, verts, faces=faces)
    return add(piece_name, obj, color)


def lerp(a, b, t):
    a, b = Vector(a), Vector(b)
    return a + (b - a) * t


# ---------------------------------------------------------------------------
# Partes e pivôs (juntas)
# ---------------------------------------------------------------------------
piece("Body", None, (0, 0, 1.2))
piece("Neck1", "Body", (0, 6.0, 2.2))
piece("Neck2", "Neck1", (0, 8.0, 4.0))
piece("Neck3", "Neck2", (0, 9.5, 6.0))
piece("Head", "Neck3", (0, 10.5, 7.5))
piece("Jaw", "Head", (0, 10.9, 7.0))
tail_pivots = [(0, -5.5, 0.8), (0, -9.0, 0.7), (0, -12.0, 0.6), (0, -15.0, 0.5), (0, -18.0, 0.4)]
for i, pv in enumerate(tail_pivots):
    piece("Tail%d" % (i + 1), "Body" if i == 0 else "Tail%d" % i, pv)

# ---------------------------------------------------------------------------
# Corpo
# ---------------------------------------------------------------------------
skin_chain("Body", "Corpo", [
    (0, -6.5, 0.8, 2.3),
    (0, -3.0, 1.1, 3.0),
    (0, 0.0, 1.3, 3.3),
    (0, 3.0, 1.5, 3.0),
    (0, 5.2, 1.8, 2.5),
    (0, 6.6, 2.4, 1.9),
], subdiv=1, ratio=0.42, flat=0.92)

for s in (-1, 1):
    side = "E" if s < 0 else "D"
    # Patas da frente (recolhidas em voo)
    tube("Body", "PataFrente" + side, [
        (s * 1.9, 3.6, 0.6, 0.95), (s * 2.4, 4.6, -1.3, 0.6),
        (s * 2.2, 3.3, -2.3, 0.42), (s * 2.2, 4.3, -2.7, 0.3),
    ], sides=5)
    # Patas de trás
    tube("Body", "PataTras" + side, [
        (s * 2.0, -3.6, 0.8, 1.25), (s * 2.7, -2.2, -1.1, 0.8),
        (s * 2.5, -4.7, -2.1, 0.48), (s * 2.5, -3.7, -2.7, 0.32),
    ], sides=5)
    for k, dx in enumerate((-0.25, 0.0, 0.25)):
        cone("Body", "GarraFrente%s%d" % (side, k), (s * 2.2 + dx, 4.5, -2.7), (s * 2.2 + dx * 1.4, 5.3, -2.9), 0.12, 3, "claw")
        cone("Body", "GarraTras%s%d" % (side, k), (s * 2.5 + dx, -3.5, -2.7), (s * 2.5 + dx * 1.4, -2.7, -2.9), 0.13, 3, "claw")

# Espinhos das costas
for y, h in ((-5.5, 1.1), (-3.0, 1.5), (-0.5, 1.7), (2.0, 1.6), (4.3, 1.3)):
    top = 1.3 + 3.0 * 0.92
    cone("Body", "Espinho%.1f" % y, (0, y, top - 0.4), (0, y - 0.9, top + h), 0.42, 4)

# ---------------------------------------------------------------------------
# Pescoço
# ---------------------------------------------------------------------------
neck = [(0, 5.4, 1.9, 2.1), (0, 6.0, 2.2, 1.95), (0, 8.0, 4.0, 1.6), (0, 9.5, 6.0, 1.35), (0, 10.5, 7.5, 1.15), (0, 10.9, 7.9, 1.1)]
for i in range(3):
    a, b = neck[i], neck[i + 2]
    mid = neck[i + 1]
    skin_chain("Neck%d" % (i + 1), "Pescoco%d" % (i + 1), [a, mid, b], subdiv=1, ratio=0.42)
    c = Vector(mid[:3])
    cone("Neck%d" % (i + 1), "EspinhoPescoco%d" % i, c + Vector((0, -0.2, mid[3] - 0.3)), c + Vector((0, -1.0, mid[3] + 0.9)), 0.3, 4)

# ---------------------------------------------------------------------------
# Cabeça e mandíbula
# ---------------------------------------------------------------------------
skin_chain("Head", "Cabeca", [
    (0, 10.2, 7.7, 1.3),
    (0, 11.5, 7.9, 1.22),
    (0, 13.0, 7.7, 0.92),
    (0, 14.5, 7.4, 0.68),
    (0, 15.6, 7.2, 0.45),
], subdiv=1, ratio=0.55, flat=0.8)
for s in (-1, 1):
    side = "E" if s < 0 else "D"
    tube("Head", "Chifre" + side, [
        (s * 0.7, 10.7, 8.5, 0.38), (s * 1.0, 9.4, 9.6, 0.24), (s * 1.25, 8.0, 10.1, 0.1),
    ], sides=5, color="horn")
    tube("Head", "Sobrancelha" + side, [
        (s * 0.62, 11.9, 8.5, 0.22), (s * 0.78, 12.9, 8.25, 0.12),
    ], sides=3, color="spike")
    cone("Head", "Bochecha" + side, (s * 0.9, 10.8, 7.2), (s * 1.9, 9.8, 7.0), 0.25, 3)
    cone("Head", "Narina" + side, (s * 0.25, 15.3, 7.55), (s * 0.3, 15.9, 7.75), 0.1, 3, "horn")

skin_chain("Jaw", "Mandibula", [
    (0, 10.8, 6.9, 0.85), (0, 12.6, 6.6, 0.62), (0, 14.7, 6.6, 0.36),
], subdiv=1, ratio=0.35, flat=0.6)
for s in (-1, 1):
    for k, y in enumerate((12.4, 13.4, 14.3)):
        cone("Jaw", "Dente%d%d" % (s, k), (s * 0.4, y, 6.9), (s * 0.4, y + 0.05, 7.35), 0.08, 3, "horn")

# ---------------------------------------------------------------------------
# Cauda
# ---------------------------------------------------------------------------
tail = [(0, -5.0, 0.85, 2.35), (0, -5.5, 0.8, 2.2), (0, -9.0, 0.7, 1.7), (0, -12.0, 0.6, 1.3),
        (0, -15.0, 0.5, 0.95), (0, -18.0, 0.4, 0.6), (0, -21.0, 0.3, 0.35)]
for i in range(5):
    seg = [tail[i], tail[i + 1], tail[i + 2]] if i == 0 else [tail[i + 1], tail[i + 2]]
    if i > 0:
        seg = [(tail[i + 1][0], tail[i + 1][1] + 0.4, tail[i + 1][2], tail[i + 1][3])] + [tail[i + 2]]
    skin_chain("Tail%d" % (i + 1), "Cauda%d" % (i + 1), seg, subdiv=1, ratio=0.42)
    c = Vector(tail[i + 1][:3])
    r = tail[i + 1][3]
    cone("Tail%d" % (i + 1), "EspinhoCauda%d" % i, c + Vector((0, -0.4, r - 0.3)), c + Vector((0, -1.3, r + 0.8 * r)), 0.3 * r + 0.1, 4)
# Ponta da cauda (pá)
membrane("Tail5", "PontaCauda", [
    ((0, -20.4, 0.3), (-1.3, -21.8, 0.3), (0, -23.6, 0.3)),
    ((0, -20.4, 0.3), (0, -23.6, 0.3), (1.3, -21.8, 0.3)),
], "spike")

# ---------------------------------------------------------------------------
# Asas
# ---------------------------------------------------------------------------
for s in (-1, 1):
    side = "L" if s < 0 else "R"

    def P(x, y, z):
        return Vector((s * x, y, z))

    S, E, W = P(2.0, 3.2, 2.6), P(9.0, 1.8, 3.9), P(15.0, 4.2, 3.5)
    F1, F2, F3, F4 = P(24.5, 1.5, 2.7), P(22.0, -4.0, 2.3), P(17.0, -8.0, 2.0), P(11.0, -9.5, 1.8)
    M1, B1 = P(6.5, -7.0, 2.0), P(1.9, -4.0, 1.9)
    piece("Wing%s1" % side, "Body", tuple(S))
    piece("Wing%s2" % side, "Wing%s1" % side, tuple(E))

    tube("Wing%s1" % side, "Braco" + side, [tuple(S) + (0.6,), tuple(lerp(S, E, 0.5)) + (0.45,), tuple(E) + (0.42,)], sides=5, color="wingbone")
    tube("Wing%s2" % side, "Antebraco" + side, [tuple(E) + (0.4,), tuple(W) + (0.3,)], sides=4, color="wingbone")
    for k, F in enumerate((F1, F2, F3, F4)):
        tube("Wing%s2" % side, "Dedo%s%d" % (side, k), [tuple(W) + (0.24,), tuple(F) + (0.07,)], sides=3, color="wingbone")
    cone("Wing%s2" % side, "GarraAsa" + side, W, W + Vector((0, 1.3, 0.5)), 0.15, 3, "claw")

    def scallop(a, b):
        return W + (lerp(a, b, 0.5) - W) * 0.8

    membrane("Wing%s1" % side, "MembranaInterna" + side, [(S, E, B1), (E, M1, B1)])
    membrane("Wing%s2" % side, "MembranaExterna" + side, [
        (W, F1, scallop(F1, F2)), (W, scallop(F1, F2), F2),
        (W, F2, scallop(F2, F3)), (W, scallop(F2, F3), F3),
        (W, F3, scallop(F3, F4)), (W, scallop(F3, F4), F4),
        (E, W, F4), (E, F4, M1),
    ])

# ---------------------------------------------------------------------------
# Exporta triângulos
# ---------------------------------------------------------------------------
def to_roblox(v):
    # Blender (X dir., Y frente, Z cima) -> Roblox (X dir., Y cima, -Z frente)
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


depsgraph = bpy.context.evaluated_depsgraph_get()
export = {"pieces": {}, "mouth": to_roblox(Vector((0, 15.4, 7.1))), "eyes": []}
for s in (-1, 1):
    export["eyes"].append(to_roblox(Vector((s * 0.78, 12.3, 8.05))))

total = 0
for name, info in PIECES.items():
    tris = []
    for obj, color in info["objects"]:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        for tri in mesh.loop_triangles:
            verts = [obj.matrix_world @ mesh.vertices[i].co for i in tri.vertices]
            normal = (verts[1] - verts[0]).cross(verts[2] - verts[0])
            if normal.length < 1e-6:
                continue
            normal.normalize()
            key = color
            if color == "auto":
                key = "belly" if normal.z < -0.45 else "back"
            tris.append({"v": [to_roblox(v) for v in verts], "c": key})
        evaluated.to_mesh_clear()
    total += len(tris)
    export["pieces"][name] = {
        "parent": info["parent"],
        "pivot": to_roblox(info["pivot"]),
        "tris": tris,
    }
    print("%-8s %4d triângulos" % (name, len(tris)))
print("TOTAL", total, "triângulos")
if os.environ.get("DRAGON_DEBUG"):
    for name, info in PIECES.items():
        for obj, color in info["objects"]:
            ev = obj.evaluated_get(depsgraph); m = ev.to_mesh(); m.calc_loop_triangles(); print("   ", name, obj.name, len(m.loop_triangles)); ev.to_mesh_clear()

with open(os.path.join(out_dir, "dragon.json"), "w") as f:
    json.dump(export, f, separators=(",", ":"))

bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.path.join(out_dir, "dragon.blend")))
bpy.ops.export_scene.fbx(filepath=os.path.abspath(os.path.join(out_dir, "dragon.fbx")), use_mesh_modifiers=True)
print("OK")
