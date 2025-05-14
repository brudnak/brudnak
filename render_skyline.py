import bpy
import sys
import os
import math
from mathutils import Vector

# Get CLI args
argv = sys.argv[sys.argv.index("--") + 1:]
stl_path = argv[0]

# Reset Blender
bpy.ops.wm.read_factory_settings(use_empty=True)

# Import STL
bpy.ops.import_mesh.stl(filepath=stl_path)
obj = bpy.context.selected_objects[0]
obj.name = "Skyline"

# Center origin
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
bpy.context.view_layer.objects.active = obj

# Slight upscale
obj.scale = (1.1, 1.1, 1.1)

# Auto framing
dims = obj.dimensions
max_dim = max(dims)
cam_dist = max_dim * 1.3  # 🎯 Tighter zoom

# Focus camera more toward the front face (assuming it's along -Y)
# This will help aim at the engraved name/date
obj_center = obj.location
target_location = obj_center + Vector((0, max_dim * 0.3, 0))

# Create an Empty object as a tracking target at the front
bpy.ops.object.empty_add(type='PLAIN_AXES', location=target_location)
target = bpy.context.object

# Orbit-style camera setup
elevation_deg = 20  # Lower = more head-on
azimuth_deg = 135   # Diagonal view

elevation = math.radians(elevation_deg)
azimuth = math.radians(azimuth_deg)

x = cam_dist * math.cos(elevation) * math.cos(azimuth)
y = cam_dist * math.cos(elevation) * math.sin(azimuth)
z = cam_dist * math.sin(elevation)

bpy.ops.object.camera_add(location=(x, y, z))
camera = bpy.context.object
track = camera.constraints.new(type='TRACK_TO')
track.target = target  # 👈 Focus on the empty at the front
track.track_axis = 'TRACK_NEGATIVE_Z'
track.up_axis = 'UP_Y'
bpy.context.scene.camera = camera

# Lighting
bpy.ops.object.light_add(type='SUN', location=(x, y, z + cam_dist * 0.5))

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

# Material factory
def make_material(name, base_rgb):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    for node in nodes:
        nodes.remove(node)

    output = nodes.new(type='ShaderNodeOutputMaterial')
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.inputs["Base Color"].default_value = (*base_rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.4
    links.new(bsdf.outputs[0], output.inputs[0])
    return mat

# Assign initial material
obj.data.materials.append(make_material("Placeholder", (0.5, 0.5, 0.5)))

# Render theme handler
def render_with_theme(bg_rgba, obj_rgb, filename):
    bg_node.inputs[0].default_value = bg_rgba
    mat = make_material("SkylineMaterial", obj_rgb)
    obj.data.materials[0] = mat
    scene.render.filepath = os.path.abspath(filename)
    bpy.ops.render.render(write_still=True)

# LIGHT MODE
render_with_theme(
    bg_rgba=(1, 1, 1, 1),
    obj_rgb=(0.12, 0.12, 0.12),
    filename="skyline-light.png"
)

# DARK MODE
render_with_theme(
    bg_rgba=(0.05, 0.05, 0.05, 1),
    obj_rgb=(0.0, 0.5, 1.0),
    filename="skyline-dark.png"
)
