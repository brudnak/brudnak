import bpy
import sys
import os

# Get CLI args
argv = sys.argv[sys.argv.index("--") + 1:]
stl_path = argv[0]

# Clear default Blender scene
bpy.ops.wm.read_factory_settings(use_empty=True)

# Import STL model
bpy.ops.import_mesh.stl(filepath=stl_path)
obj = bpy.context.selected_objects[0]
obj.name = "Skyline"

# Setup camera (GitHub-style angle)
bpy.ops.object.camera_add(location=(90, -120, 70), rotation=(1.2, 0, 0.9))
camera = bpy.context.object
bpy.context.scene.camera = camera

# Add basic lighting
bpy.ops.object.light_add(type='SUN', location=(60, -80, 100))

# Setup rendering
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.use_denoising = False  # 🔧 Disable unsupported denoising
scene.render.resolution_x = 1024
scene.render.resolution_y = 768
scene.render.image_settings.file_format = 'PNG'

# Ensure world/background exists
if not scene.world:
    scene.world = bpy.data.worlds.new("SkylineWorld")
scene.world.use_nodes = True

# Get or create background node
bg_node = scene.world.node_tree.nodes.get("Background")
if not bg_node:
    bg_node = scene.world.node_tree.nodes.new("ShaderNodeBackground")

# Render function with background color
def render_with_bg(color_rgba, filename):
    bg_node.inputs[0].default_value = color_rgba  # RGBA
    scene.render.filepath = os.path.abspath(filename)
    bpy.ops.render.render(write_still=True)

# Render for light mode (white background)
render_with_bg((1, 1, 1, 1), "skyline-light.png")

# Render for dark mode (dark gray background)
render_with_bg((0.05, 0.05, 0.05, 1), "skyline-dark.png")
