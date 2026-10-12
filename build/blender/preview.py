"""
Renderiza uma prévia do dragão exatamente como ele fica no Roblox
(triângulos com as cores da paleta), usando o Cycles do Blender.
    python build/blender/preview.py build/assets/dragon.json saida.png [paleta]
"""
import json
import math
import random
import sys

import bpy
from mathutils import Vector

src, out = sys.argv[1], sys.argv[2]
palette_name = sys.argv[3] if len(sys.argv) > 3 else "red"

PALETTES = {
    "red": {"back": (170, 30, 30), "belly": (235, 180, 90), "wing": (120, 20, 30), "wingbone": (90, 15, 20),
            "horn": (235, 220, 190), "spike": (60, 20, 20), "claw": (40, 35, 35)},
    "green": {"back": (40, 120, 60), "belly": (200, 210, 120), "wing": (30, 90, 70), "wingbone": (25, 70, 45),
              "horn": (220, 215, 180), "spike": (25, 60, 35), "claw": (35, 35, 30)},
    "shadow": {"back": (45, 35, 70), "belly": (130, 70, 170), "wing": (60, 25, 90), "wingbone": (30, 20, 45),
               "horn": (200, 190, 220), "spike": (150, 40, 220), "claw": (20, 15, 25)},
}
palette = PALETTES[palette_name]

bpy.ops.wm.read_factory_settings(use_empty=True)
data = json.load(open(src))
random.seed(3)

verts, faces, colors = [], [], []
for name, piece in data["pieces"].items():
    for tri in piece["tris"]:
        start = len(verts)
        for v in tri["v"]:
            # Roblox -> Blender
            verts.append((v[0], -v[2], v[1]))
        faces.append((start, start + 1, start + 2))
        base = palette[tri["c"]]
        k = 1 + (random.random() - 0.5) * 0.12
        colors.append(tuple(min(1, c / 255 * k) for c in base))

mesh = bpy.data.meshes.new("Dragao")
mesh.from_pydata(verts, [], faces)
attr = mesh.color_attributes.new("Cor", "FLOAT_COLOR", "FACE")
for i, c in enumerate(colors):
    attr.data[i].color = (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 1)
obj = bpy.data.objects.new("Dragao", mesh)
bpy.context.collection.objects.link(obj)

mat = bpy.data.materials.new("Cor")
mat.use_nodes = True
nodes = mat.node_tree.nodes
bsdf = nodes.get("Principled BSDF")
attr_node = nodes.new("ShaderNodeAttribute")
attr_node.attribute_name = "Cor"
mat.node_tree.links.new(attr_node.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.6
obj.data.materials.append(mat)

# Câmera e luz
scene = bpy.context.scene
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
cam.location = Vector(tuple(float(x) for x in (sys.argv[4].split(",") if len(sys.argv) > 4 else ("30", "34", "22"))))
direction = Vector((0, -2, 4)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
cam_data.lens = 32
scene.camera = cam

sun_data = bpy.data.lights.new("Sol", "SUN")
sun_data.energy = 4
sun = bpy.data.objects.new("Sol", sun_data)
sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(30))
scene.collection.objects.link(sun)

world = bpy.data.worlds.new("Mundo")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.62, 0.85, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
scene.world = world

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.render.resolution_x = 960
scene.render.resolution_y = 600
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("render ok", out)
