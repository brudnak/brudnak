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

# Slight scale up for emphasis
obj.scale = (1.1, 1.1, 1.1)

# Get object bounds for framing
dims = obj.dimensions
center = obj.location
max_dim = max(dims)
cam_dist = max_dim * 2.2

# Add camera with constraint to look at the model
bpy.ops.object.camera_add(location=(cam_dist, -cam_dist, cam_dist))
camera = bpy.context.object

# Make camera look at object
track = camera.constraints.new(type='TRACK_TO')
track.target = obj
track.track_axis = 'TRACK_NEGATIVE_Z'
track.up_axis = 'UP_Y'

bpy.context.scene.camera = camera

# Add lighting
bpy.ops.object.light_add(type='SUN', location=(cam_dist, -cam_dist, cam_dist * 1.5))

# Render settings
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.use_denoising = False
scene.render.resolution_x = 1024
scene.render.resolution_y = 768
scene.render.image_settings.file_format = 'PNG'

# World setup
if not scene.world:
    scene.world = bpy.data.worlds.new("SkylineWorld")
scene.world.use_nodes = True
bg_node = scene.world.node_tree.nodes.get("Background") or scene.world.node_tree.nodes.new("ShaderNodeBackground")

# Material generator
def make_material(name, base_rgb, neon=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Clear old nodes
    for node in nodes:
        nodes.remove(node)

    output = nodes.new(type='ShaderNodeOutputMaterial')

    if neon:
        # Emission material
        emission = nodes.new(type='ShaderNodeEmission')
        emission.inputs[0].default_value = (*base_rgb, 1)
        emission.inputs[1].default_value = 3.0  # strength

        links.new(emission.outputs[0], output.inputs[0])
    else:
        # Basic principled BSDF
        bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
        bsdf.inputs["Base Color"].default_value = (*base_rgb, 1)
        bsdf.inputs["Roughness"].default_value = 0.4

        links.new(bsdf.outputs[0], output.inputs[0])

    return mat

# Assign initial placeholder
obj.data.materials.append(make_material("SkylineGray", (0.5, 0.5, 0.5)))

# Render with theme
def render_with_theme(bg_rgba, obj_rgb, filename, neon=False):
    # Set background
    bg_node.inputs[0].default_value = bg_rgba

    # Assign styled material
    mat = make_material("SkylineRender", obj_rgb, neon=neon)
    obj.data.materials[0] = mat

    # Output path
    scene.render.filepath = os.path.abspath(filename)
    bpy.ops.render.render(write_still=True)

# 🔳 Light mode
render_with_theme(
    bg_rgba=(1, 1, 1, 1),
    obj_rgb=(0.25, 0.25, 0.25),
    filename="skyline-light.png"
)

# 🟦 Dark mode – NEON!
render_with_theme(
    bg_rgba=(0.05, 0.05, 0.05, 1),
    obj_rgb=(0.0, 1.0, 1.0),
    filename="skyline-dark.png",
    neon=True
)
