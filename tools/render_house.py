"""Render the high-quality house prototype with Blender/Cycles.

Run from the project root:
    Blender\\blender.exe --background --factory-startup --python tools\\render_house.py

The editable scene and full-size render are kept under art_source/. Godot receives
an antialiased, transparent 192 x 192 PNG in assets/sprites/buildings/.
"""

import argparse
import math
from pathlib import Path
import random
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_PATH = PROJECT_ROOT / "assets" / "sprites" / "buildings" / "building_house_3d.png"
SOURCE_DIRECTORY = PROJECT_ROOT / "art_source" / "blender"
MASTER_DIRECTORY = PROJECT_ROOT / "art_source" / "renders"


def parse_arguments():
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=96)
    parser.add_argument("--master-size", type=int, default=768)
    parser.add_argument("--output-size", type=int, default=192)
    options = parser.parse_args(arguments)
    if options.samples < 1:
        parser.error("--samples must be positive")
    if options.master_size < options.output_size or options.output_size < 1:
        parser.error("--master-size must be at least as large as --output-size")
    return options


def linear_channel(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def rgba(hex_color):
    value = hex_color.lstrip("#")
    return tuple(linear_channel(int(value[index:index + 2], 16) / 255.0) for index in (0, 2, 4)) + (1.0,)


def material(name, hex_color, roughness=0.7, metallic=0.0, bump=0.0, noise_scale=24.0, emission=0.0):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    color = rgba(hex_color)
    result.diffuse_color = color
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if emission > 0.0:
        shader.inputs["Emission Color"].default_value = color
        shader.inputs["Emission Strength"].default_value = emission
    if bump > 0.0:
        noise = result.node_tree.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = noise_scale
        noise.inputs["Detail"].default_value = 2.0
        bump_node = result.node_tree.nodes.new("ShaderNodeBump")
        bump_node.inputs["Strength"].default_value = bump
        bump_node.inputs["Distance"].default_value = 0.035
        result.node_tree.links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
        result.node_tree.links.new(bump_node.outputs["Normal"], shader.inputs["Normal"])
    return result


def finish_object(obj, surface, bevel=0.0, smooth=False, framed=True):
    obj.data.materials.append(surface)
    obj["frame_asset"] = framed
    if bevel > 0.0:
        modifier = obj.modifiers.new("Soft handcrafted edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
    if smooth and obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        normals = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
        normals.keep_sharp = True
    return obj


def box(name, location, dimensions, surface, bevel=0.025, rotation=None, framed=True):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation is not None:
        obj.rotation_euler = rotation
    return finish_object(obj, surface, bevel=bevel, smooth=True, framed=framed)


def cylinder(name, location, radius, depth, surface, vertices=32, rotation=None, bevel=0.015):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    if rotation is not None:
        obj.rotation_euler = rotation
    return finish_object(obj, surface, bevel=bevel, smooth=True)


def sphere(name, location, scale, surface):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    return finish_object(obj, surface, smooth=True)


def beam_between(name, start, end, width, surface, depth=None):
    start_vector = Vector(start)
    end_vector = Vector(end)
    direction = end_vector - start_vector
    obj = box(
        name,
        (start_vector + end_vector) * 0.5,
        (width, depth or width, direction.length),
        surface,
        bevel=width * 0.2,
    )
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def mesh_object(name, vertices, faces, surface, bevel=0.015):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish_object(obj, surface, bevel=bevel, smooth=True)


def gable(name, width, depth, base_z, peak_z, surface):
    half_width = width * 0.5
    half_depth = depth * 0.5
    vertices = [
        (-half_width, -half_depth, base_z),
        (half_width, -half_depth, base_z),
        (0.0, -half_depth, peak_z),
        (-half_width, half_depth, base_z),
        (half_width, half_depth, base_z),
        (0.0, half_depth, peak_z),
    ]
    faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (0, 2, 5, 3), (1, 4, 5, 2)]
    return mesh_object(name, vertices, faces, surface)


def tube_path(name, points, radius, surface):
    curve = bpy.data.curves.new(name + "Curve", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coordinates in zip(spline.points, points):
        point.co = (*coordinates, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    curve.materials.append(surface)
    obj["frame_asset"] = True
    return obj


def arched_door(surface, frame_surface, metal_surface):
    width = 0.5
    height = 1.0
    radius = width * 0.5
    shoulder = height - radius
    bottom = 0.25
    center_y = -0.91
    depth = 0.075
    outline = [(-radius, 0.0), (radius, 0.0), (radius, shoulder)]
    for step in range(1, 17):
        angle = math.pi * step / 16.0
        outline.append((radius * math.cos(angle), shoulder + radius * math.sin(angle)))
    count = len(outline)
    vertices = []
    for y in (center_y - depth * 0.5, center_y + depth * 0.5):
        vertices.extend((x, y, bottom + z) for x, z in outline)
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, count + following, count + index))
    mesh_object("Arched oak front door", vertices, faces, surface, bevel=0.012)
    frame_points = [(x, center_y - 0.055, bottom + z) for x, z in outline[1:]]
    frame_points.append((-radius, center_y - 0.055, bottom))
    tube_path("Curved walnut door frame", frame_points, 0.042, frame_surface)
    for x in (-0.15, -0.05, 0.05, 0.15):
        box("Door plank seam", (x, center_y - 0.047, 0.62), (0.012, 0.012, 0.69), frame_surface, bevel=0.003)
    sphere("Brass door handle", (0.16, center_y - 0.09, 0.66), (0.035, 0.025, 0.035), metal_surface)
    box("Worn stone doorstep", (0.0, -1.03, 0.19), (0.7, 0.36, 0.15), MATERIALS["stone_light"], bevel=0.045)


def front_window(center_x, center_z):
    y = -0.895
    box("Front window warm glass", (center_x, y, center_z), (0.36, 0.055, 0.42), MATERIALS["glass"], bevel=0.035)
    for x in (center_x - 0.21, center_x + 0.21):
        box("Front window vertical frame", (x, y - 0.025, center_z), (0.055, 0.075, 0.52), MATERIALS["wood"], bevel=0.012)
    for z in (center_z - 0.24, center_z + 0.24):
        box("Front window horizontal frame", (center_x, y - 0.025, z), (0.47, 0.075, 0.055), MATERIALS["wood"], bevel=0.012)
    box("Front window mullion", (center_x, y - 0.04, center_z), (0.025, 0.055, 0.42), MATERIALS["wood"], bevel=0.005)
    box("Front window crossbar", (center_x, y - 0.04, center_z), (0.36, 0.055, 0.025), MATERIALS["wood"], bevel=0.005)
    for side in (-1, 1):
        shutter_x = center_x + side * 0.32
        box("Sage wooden shutter", (shutter_x, y + 0.005, center_z), (0.13, 0.07, 0.48), MATERIALS["shutter"], bevel=0.02)
        for z in (center_z - 0.13, center_z, center_z + 0.13):
            box("Shutter slat", (shutter_x, y - 0.038, z), (0.11, 0.018, 0.018), MATERIALS["shutter_dark"], bevel=0.004)
    box("Terracotta flower box", (center_x, -1.0, center_z - 0.36), (0.49, 0.2, 0.14), MATERIALS["roof_dark"], bevel=0.025)
    for index in range(5):
        x = center_x - 0.18 + index * 0.09
        sphere("Window box foliage", (x, -1.02, center_z - 0.27), (0.085, 0.07, 0.07), MATERIALS["leaf"])
        if index % 2 == 0:
            sphere("Window box blossom", (x, -1.075, center_z - 0.22), (0.035, 0.03, 0.035), MATERIALS["flower"])


def side_window(center_y, center_z):
    x = 1.16
    box("Side window warm glass", (x, center_y, center_z), (0.055, 0.4, 0.42), MATERIALS["glass"], bevel=0.035)
    for y in (center_y - 0.23, center_y + 0.23):
        box("Side window vertical frame", (x + 0.025, y, center_z), (0.075, 0.055, 0.52), MATERIALS["wood"], bevel=0.012)
    for z in (center_z - 0.24, center_z + 0.24):
        box("Side window horizontal frame", (x + 0.025, center_y, z), (0.075, 0.5, 0.055), MATERIALS["wood"], bevel=0.012)
    box("Side window mullion", (x + 0.04, center_y, center_z), (0.055, 0.025, 0.42), MATERIALS["wood"], bevel=0.005)
    box("Side window crossbar", (x + 0.04, center_y, center_z), (0.055, 0.4, 0.025), MATERIALS["wood"], bevel=0.005)


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def area_light(name, location, energy, color, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    point_at(obj, (0.0, 0.0, 1.0))


def frame_camera(camera):
    scene = bpy.context.scene
    for _ in range(4):
        bpy.context.view_layer.update()
        projected = []
        for obj in scene.objects:
            if not obj.get("frame_asset", False) or obj.type not in {"MESH", "CURVE"}:
                continue
            projected.extend(world_to_camera_view(scene, camera, obj.matrix_world @ Vector(corner)) for corner in obj.bound_box)
        minimum_x = min(point.x for point in projected)
        maximum_x = max(point.x for point in projected)
        minimum_y = min(point.y for point in projected)
        maximum_y = max(point.y for point in projected)
        camera.data.ortho_scale *= max((maximum_x - minimum_x) / 0.86, (maximum_y - minimum_y) / 0.88)
        offset_x = ((minimum_x + maximum_x) * 0.5 - 0.5) * camera.data.ortho_scale
        offset_y = ((minimum_y + maximum_y) * 0.5 - 0.5) * camera.data.ortho_scale
        camera.location += camera.rotation_euler.to_quaternion() @ Vector((offset_x, offset_y, 0.0))


def create_materials():
    global MATERIALS
    MATERIALS = {
        "plaster": material("Warm limewash", "E5D3AA", bump=0.16, noise_scale=38.0),
        "wood": material("Dark walnut timber", "59402F", bump=0.1, noise_scale=18.0),
        "door": material("Honey oak door", "8B6038", bump=0.13, noise_scale=22.0),
        "stone": material("Foundation sandstone", "817968", bump=0.2, noise_scale=14.0),
        "stone_light": material("Worn pale stone", "AAA089", bump=0.16, noise_scale=18.0),
        "stone_dark": material("Cool foundation stone", "696A62", bump=0.18, noise_scale=16.0),
        "roof": material("Terracotta tiles", "A95440", bump=0.1, noise_scale=26.0),
        "roof_light": material("Sunlit terracotta variation", "BC6850", bump=0.1, noise_scale=26.0),
        "roof_dark": material("Aged terracotta variation", "8E4538", bump=0.1, noise_scale=26.0),
        "glass": material("Warm window glass", "E9BE69", roughness=0.32, emission=0.3),
        "shutter": material("Sage painted shutters", "64806A", bump=0.08, noise_scale=24.0),
        "shutter_dark": material("Shutter grooves", "455E50"),
        "leaf": material("Garden sage leaves", "4F713F", roughness=0.85),
        "flower": material("Muted coral blossoms", "D98572", roughness=0.7),
        "brass": material("Antique brass", "C9A34E", roughness=0.28, metallic=0.72),
    }


def build_walls():
    box("Stone cottage foundation", (0.0, 0.0, 0.15), (2.42, 1.9, 0.28), MATERIALS["stone"], bevel=0.06)
    box("Limewashed cottage walls", (0.0, 0.0, 0.91), (2.25, 1.72, 1.38), MATERIALS["plaster"], bevel=0.035)
    gable("Plastered front and rear gables", 2.25, 1.72, 1.6, 2.48, MATERIALS["plaster"])

    randomizer = random.Random(27)
    stone_surfaces = [MATERIALS["stone"], MATERIALS["stone_light"], MATERIALS["stone_dark"]]
    for index in range(7):
        x = -1.03 + index * 0.345
        box(
            "Individual front foundation stone",
            (x, -0.962, 0.15 + randomizer.uniform(-0.012, 0.012)),
            (0.31, 0.08, randomizer.uniform(0.18, 0.24)),
            stone_surfaces[index % len(stone_surfaces)],
            bevel=0.035,
        )
    for index in range(5):
        y = -0.72 + index * 0.36
        box(
            "Individual side foundation stone",
            (1.225, y, 0.15),
            (0.08, 0.32, randomizer.uniform(0.18, 0.24)),
            stone_surfaces[(index + 1) % len(stone_surfaces)],
            bevel=0.035,
        )

    for x in (-1.12, 1.12):
        for y in (-0.87, 0.87):
            box("Corner timber post", (x, y, 0.94), (0.13, 0.13, 1.48), MATERIALS["wood"], bevel=0.018)
    for z in (0.32, 1.52):
        for y in (-0.89, 0.89):
            box("Front and rear horizontal timber", (0.0, y, z), (2.35, 0.11, 0.12), MATERIALS["wood"], bevel=0.018)
        for x in (-1.15, 1.15):
            box("Side horizontal timber", (x, 0.0, z), (0.11, 1.82, 0.12), MATERIALS["wood"], bevel=0.018)
    for side in (-1, 1):
        beam_between(
            "Front gable diagonal timber",
            (side * 1.07, -0.9, 1.62),
            (0.0, -0.9, 2.47),
            0.085,
            MATERIALS["wood"],
        )
        beam_between(
            "Side wall diagonal brace",
            (1.17, side * 0.72, 0.39),
            (1.17, side * 0.34, 0.82),
            0.075,
            MATERIALS["wood"],
        )
    box("Gable central timber", (0.0, -0.9, 1.96), (0.09, 0.09, 0.74), MATERIALS["wood"], bevel=0.015)


def build_roof():
    half_span = 1.32
    rise = 0.97
    ridge_z = 2.62
    roof_depth = 2.12
    angle = math.atan2(rise, half_span)
    slope_length = math.hypot(half_span, rise)
    roof_surfaces = [MATERIALS["roof"], MATERIALS["roof_light"], MATERIALS["roof_dark"]]
    randomizer = random.Random(81)
    for side in (-1, 1):
        rotation = (0.0, side * angle, 0.0)
        box(
            "Solid pitched roof",
            (side * half_span * 0.5, 0.0, ridge_z - rise * 0.5),
            (slope_length, roof_depth, 0.085),
            MATERIALS["roof_dark"],
            bevel=0.025,
            rotation=rotation,
        )
        for row in range(4):
            distance = (row + 0.5) * slope_length / 4.0
            for column in range(6):
                y = -roof_depth * 0.5 + (column + 0.5) * roof_depth / 6.0
                position = Vector((0.0, y, ridge_z + 0.045)) + Vector((side * math.cos(angle), 0.0, -math.sin(angle))) * distance
                box(
                    "Individual terracotta roof tile",
                    position,
                    (slope_length / 4.0 * 1.06, roof_depth / 6.0 * 0.96, 0.055),
                    randomizer.choices(roof_surfaces, weights=(6, 2, 2))[0],
                    bevel=0.018,
                    rotation=rotation,
                )
        box(
            "Dark eave beam",
            (side * half_span, 0.0, ridge_z - rise - 0.015),
            (0.11, roof_depth + 0.06, 0.12),
            MATERIALS["wood"],
            bevel=0.018,
        )
        for y in (-1.075, 1.075):
            beam_between(
                "Gable roof fascia",
                (0.0, y, ridge_z + 0.015),
                (side * half_span, y, ridge_z - rise),
                0.1,
                MATERIALS["wood"],
            )
    for index in range(7):
        cylinder(
            "Rounded ridge cap",
            (0.0, -0.93 + index * 0.31, ridge_z + 0.075),
            0.105,
            0.34,
            MATERIALS["roof_light"] if index % 3 == 0 else MATERIALS["roof"],
            rotation=(math.pi * 0.5, 0.0, 0.0),
            bevel=0.018,
        )

    box("Stone chimney", (-0.66, 0.35, 2.42), (0.36, 0.4, 0.86), MATERIALS["stone"], bevel=0.035)
    for z in (2.15, 2.36, 2.57):
        box("Chimney mortar course", (-0.66, 0.35, z), (0.37, 0.41, 0.022), MATERIALS["stone_light"], bevel=0.006)
    box("Chimney crown", (-0.66, 0.35, 2.88), (0.46, 0.49, 0.13), MATERIALS["stone_dark"], bevel=0.03)
    box("Chimney dark opening", (-0.66, 0.35, 2.951), (0.28, 0.3, 0.018), MATERIALS["wood"], bevel=0.015)


def build_details():
    arched_door(MATERIALS["door"], MATERIALS["wood"], MATERIALS["brass"])
    front_window(-0.74, 1.04)
    front_window(0.74, 1.04)
    side_window(0.12, 1.05)
    for index, (x, y, scale) in enumerate(((0.0, -1.29, 1.0), (0.08, -1.57, 0.85), (-0.03, -1.82, 0.72))):
        stone = cylinder(
            "Garden path stepping stone",
            (x, y, 0.055),
            0.25 * scale,
            0.1,
            MATERIALS["stone_light"] if index % 2 == 0 else MATERIALS["stone"],
            vertices=9,
            bevel=0.025,
        )
        stone.scale.y = 0.68
        stone.rotation_euler.z = index * 0.42
    for x, y in ((-1.25, -0.55), (1.25, 0.62)):
        for index in range(3):
            sphere(
                "Small cottage garden shrub",
                (x + (index - 1) * 0.09, y + (index % 2) * 0.07, 0.16 + index * 0.025),
                (0.16, 0.13, 0.15),
                MATERIALS["leaf"],
            )


# --- CONTINUED BELOW ---
