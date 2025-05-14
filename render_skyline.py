# render_skyline.py
import bpy
import sys
import os

# Get CLI args: -- skyline-full.stl
argv = sys.argv[sys.argv.index("--") + 1:]
stl_path = argv[0]

# Clear default scene
bpy.ops.wm.read_factory_settings(use_empty=True)

# Import STL
bpy.ops.import_mesh.stl(filepath=stl_path)
obj = bpy.context.selected_objects[0]
obj.name = "Skyline"

# Position camera to match GitHub-like angle
bpy.ops.object.camera_add(location=(90, -120, 70), rotation=(1.2, 0, 0.9))
camera = bpy.context.object
bpy.context.scene.camera = camera

# Add lighting
bpy.ops.object.light_add(type='SUN', location=(60, -80, 100))

# Set render engine
bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.device = 'CPU'
bpy.context.scene.render.resolution_x = 1024
bpy.context.scene.render.resolution_y = 768
bpy.context.scene.render.image_settings.file_format = 'PNG'

# Function to render a version with specified background color
def render_with_bg(color, filename):
    bpy.context.scene.world.use_nodes = True
    bg = bpy.context.scene.world.node_tree.nodes['Background']
    bg.inputs[0].default_value = color  # RGBA
    bpy.context.scene.render.filepath = os.path.abspath(filename)
    bpy.ops.render.render(write_still=True)

# Light mode image (white background)
render_with_bg((1, 1, 1, 1), "skyline-light.png")

# Dark mode image (dark gray background)
render_with_bg((0.05, 0.05, 0.05, 1), "skyline-dark.png")
