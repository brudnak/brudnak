import bpy
import sys
import os
import math

# Get CLI args
argv = sys.argv[sys.argv.index("--") + 1:]
stl_path = argv[0]

# Clear scene
bpy.ops.wm.read_factory_settings(use_empty=True)

# Import STL
bpy.ops.import_mesh.stl(filepath=stl_path)
obj = bpy.context.selected_objects[0]
obj.name = "Skyline"

# Move origin to center of geometry
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
bpy.context.view_layer.objects.active = obj

# Slight scale adjustment to zoom in
obj.scale = (1.1, 1.1, 1.1)

# Create material for dark and light modes
def make_material(name, color_rgb):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color_rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.4
    return mat

# Assign material slot
obj.data.materials.append(make_material("SkylineBase", (0.6, 0.6, 0.6)))  # Light mode default

# Add camera at GitHub-style angle
bpy.ops.object.camera_add(location=(100, -100, 80), rotation=(math.radians(60), 0, math.radians(45)))
camera = bpy.context.object
bpy.context.scene.camera = camera

# Add lighting
bpy.ops.object.light_add(type='SUN', location=(30, -60, 100))

# Render setup
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.use_denoising = False
scene.render.resolution_x = 1024
scene.render.resolution_y = 768
scene.render.image_settings.file_format = 'PNG'

# Ensure world exists
if not scene.world:
    scene.world = bpy.data.worlds.new("SkylineWorld")
scene.world.use_nodes = True
bg_node = scene.world.node_tree.nodes.get("Background")
if not bg_node:
    bg_node = scene.world.node_tree.nodes.new("ShaderNodeBackground")

# Render pass for each theme
def render_with_theme(color_rgba, object_color_rgb, filename):
    # Set background
    bg_node.inputs[0].default_value = color_rgba

    # Set object color
    mat = make_material("SkylineTheme", object_color_rgb)
    obj.data.materials[0] = mat

    # Output path
    scene.render.filepath = os.path.abspath(filename)
    bpy.ops.render.render(write_still=True)

# 🔳 Light mode: white bg, dark gray skyline
render_with_theme(
    color_rgba=(1, 1, 1, 1),
    object_color_rgb=(0.2, 0.2, 0.2),
    filename="skyline-light.png"
)

# 🟦 Dark mode: dark bg, neon blue skyline
render_with_theme(
    color_rgba=(0.05, 0.05, 0.05, 1),
    object_color_rgb=(0.0, 0.7, 1.0),
    filename="skyline-dark.png"
)
