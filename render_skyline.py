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

# Deselect all, then select only the object
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active = obj

# Move origin to geometry center
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')

# Get object dimensions and center
dimensions = obj.dimensions
center = obj.location
max_dim = max(dimensions)

# Calculate ideal camera distance (simple "zoom out" formula)
distance = max_dim * 2.2

# Add camera and point it at object from GitHub-style angle
bpy.ops.object.camera_add(location=(distance, -distance, distance), rotation=(math.radians(60), 0, math.radians(45)))
camera = bpy.context.object
bpy.context.scene.camera = camera

# Add light
bpy.ops.object.light_add(type='SUN', location=(0, 0, distance * 1.5))

# Set render engine
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.use_denoising = False
scene.render.resolution_x = 1024
scene.render.resolution_y = 768
scene.render.image_settings.file_format = 'PNG'

# Ensure world/background
if not scene.world:
    scene.world = bpy.data.worlds.new("SkylineWorld")
scene.world.use_nodes = True
bg_node = scene.world.node_tree.nodes.get("Background")
if not bg_node:
    bg_node = scene.world.node_tree.nodes.new("ShaderNodeBackground")

# Render function
def render_with_bg(color_rgba, filename):
    bg_node.inputs[0].default_value = color_rgba
    scene.render.filepath = os.path.abspath(filename)
    bpy.ops.render.render(write_still=True)

# Render images
render_with_bg((1, 1, 1, 1), "skyline-light.png")
render_with_bg((0.05, 0.05, 0.05, 1), "skyline-dark.png")
