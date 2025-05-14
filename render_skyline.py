import bpy
import sys
import os
import math

# Get CLI args
argv = sys.argv[sys.argv.index("--") + 1:]
stl_path = argv[0]

# Reset Blender
bpy.ops.wm.read_factory_settings(use_empty=True)

# Import STL
bpy.ops.import_mesh.stl(filepath=stl_path)
obj = bpy.context.selected_objects[0]
obj.name = "Skyline"

# Origin to geometry center
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
bpy.context.view_layer.objects.active = obj

# Slight scale bump
obj.scale = (1.1, 1.1, 1.1)

# Get object bounds and distance
dims = obj.dimensions
max_dim = max(dims)
cam_dist = max_dim * 1.7  # Closer framing

# Add camera and point it at the object
bpy.ops.object.camera_add(location=(cam_dist, -cam_dist, cam_dist))
camera = bpy.context.object
track = camera.constraints.new(type='TRACK_TO')
track.target = obj
track.track_axis = 'TRACK_NEGATIVE_Z'
track.up_axis = 'UP_Y'
bpy.context.scene.camera = camera

# Add lighting
bpy.ops.object.light_add(type='SUN', location=(cam_dist, -cam_dist, cam_dist * 1.5))

# Set render engine and config
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.use_denoising = False
scene.render.resolution_x = 1024
scene.render.resolution_y = 768
scene.render.image_settings.file_format = 'PNG'

# Set up world
if not scene.world:
    scene.world = bpy.data.worlds.new("SkylineWorld")
scene.world.use_nodes = True
bg_node = scene.world.node_tree.nodes.get("Background") or scene.world.node_tree.nodes.new("ShaderNodeBackground")

# Function: create and assign material
def make_material(name, base_rgb, neon=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    for node in nodes: nodes.remove(node)

    output = nodes.new(type='ShaderNodeOutputMaterial')

    if neon:
        emission = nodes.new(type='ShaderNodeEmission')
        emission.inputs[0].default_value = (*base_rgb, 1)
        emission.inputs[1].default_value = 5.0
        links.new(emission.outputs[0], output.inputs[0])
    else:
        bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
        bsdf.inputs["Base Color"].default_value = (*base_rgb, 1)
        bsdf.inputs["Roughness"].default_value = 0.4
        links.new(bsdf.outputs[0], output.inputs[0])

    return mat

# Assign placeholder to object
obj.data.materials.append(make_material("Base", (0.5, 0.5, 0.5)))

# Render function
def render_with_theme(bg_rgba, obj_rgb, filename, neon=False):
    bg_node.inputs[0].default_value = bg_rgba
    mat = make_material("SkylineMaterial", obj_rgb, neon=neon)
    obj.data.materials[0] = mat
    scene.render.filepath = os.path.abspath(filename)
    bpy.ops.render.render(write_still=True)

# LIGHT MODE
render_with_theme(
    bg_rgba=(1, 1, 1, 1),               # White background
    obj_rgb=(0.15, 0.15, 0.15),         # Dark gray skyline
    filename="skyline-light.png",
    neon=False
)

# DARK MODE
render_with_theme(
    bg_rgba=(0.01, 0.01, 0.01, 1),      # Nearly black background
    obj_rgb=(0.0, 0.7, 1.0),            # Neon blue skyline
    filename="skyline-dark.png",
    neon=True
)
