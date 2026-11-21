"""
Blender 3D Asset Generator for Strategy Game
Renders high-quality 2.5D pre-rendered sprites and icons with isometric lighting.
"""

import bpy
import math
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_BUILDINGS = os.path.join(PROJECT_ROOT, "assets", "sprites", "buildings")
OUTPUT_UI = os.path.join(PROJECT_ROOT, "assets", "sprites", "ui")

os.makedirs(OUTPUT_BUILDINGS, exist_ok=True)
os.makedirs(OUTPUT_UI, exist_ok=True)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'
    return scene


def setup_lighting():
    # Key Sun Light
    sun_data = bpy.data.lights.new(name="KeySun", type='SUN')
    sun_data.energy = 3.5
    sun_data.color = (1.0, 0.96, 0.88)
    sun_obj = bpy.data.objects.new(name="KeySun", object_data=sun_data)
    bpy.context.scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(50), math.radians(20), math.radians(-35))

    # Fill Light (Cool sky bounce)
    fill_data = bpy.data.lights.new(name="FillLight", type='SUN')
    fill_data.energy = 1.2
    fill_data.color = (0.75, 0.85, 1.0)
    fill_obj = bpy.data.objects.new(name="FillLight", object_data=fill_data)
    bpy.context.scene.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (math.radians(35), math.radians(-30), math.radians(145))

    # Rim / Back Light (warm highlight on silhouette edges)
    rim_data = bpy.data.lights.new(name="RimLight", type='SUN')
    rim_data.energy = 1.8
    rim_data.color = (1.0, 0.9, 0.7)
    rim_obj = bpy.data.objects.new(name="RimLight", object_data=rim_data)
    bpy.context.scene.collection.objects.link(rim_obj)
    rim_obj.rotation_euler = (math.radians(-40), math.radians(10), math.radians(-120))


def setup_camera(ortho_scale=4.5, res=256):
    cam_data = bpy.data.cameras.new("IsoCamera")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ortho_scale
    cam_obj = bpy.data.objects.new("IsoCamera", cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)

    # Classic 2.5D Strategy angle: 30° elevation, 45° azimuth
    distance = 15.0
    cam_obj.location = (distance * 0.707, -distance * 0.707, distance * 0.6)
    cam_obj.rotation_euler = (math.radians(58.0), 0, math.radians(45.0))

    bpy.context.scene.camera = cam_obj
    bpy.context.scene.render.resolution_x = res
    bpy.context.scene.render.resolution_y = res
    return cam_obj


def create_material(name, color, roughness=0.5, metallic=0.0, emission_color=(0,0,0,1), emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission_color
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def build_farm():
    """Constructs a detailed medieval farmhouse with stone base, timber walls, tiled roof, silo, and hay."""
    reset_scene()
    setup_lighting()
    cam = setup_camera(ortho_scale=4.2, res=256)
    cam.location.z += 0.4

    # Materials
    mat_stone = create_material("StoneBase", (0.35, 0.33, 0.31, 1), roughness=0.9)
    mat_wood_dark = create_material("DarkWood", (0.28, 0.18, 0.11, 1), roughness=0.7)
    mat_plaster = create_material("Plaster", (0.85, 0.82, 0.75, 1), roughness=0.8)
    mat_roof = create_material("TileRoof", (0.76, 0.28, 0.16, 1), roughness=0.6)
    mat_gold_hay = create_material("Hay", (0.88, 0.75, 0.25, 1), roughness=0.95)
    mat_chimney = create_material("ChimneyStone", (0.25, 0.24, 0.23, 1), roughness=0.9)
    mat_door = create_material("DoorWood", (0.20, 0.13, 0.08, 1), roughness=0.6)
    mat_window = create_material("WindowGlow", (1.0, 0.9, 0.5, 1), roughness=0.3, emission_color=(1.0, 0.85, 0.4, 1), emission_strength=1.5)
    mat_grass = create_material("GroundMound", (0.30, 0.58, 0.25, 1), roughness=0.9)

    # 1. Natural Ground Base Mound
    bpy.ops.mesh.primitive_cylinder_add(radius=1.8, depth=0.15, location=(0, 0, -0.07))
    ground = bpy.context.active_object
    ground.data.materials.append(mat_grass)

    # 2. Stone Foundation
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, 0, 0.25))
    base = bpy.context.active_object
    base.scale = (2.0, 1.5, 0.5)
    bpy.ops.object.transform_apply(scale=True)
    base.data.materials.append(mat_stone)

    # 3. Main Upper Story (Plaster with wooden corner posts)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, 0, 0.85))
    upper = bpy.context.active_object
    upper.scale = (1.9, 1.4, 0.7)
    bpy.ops.object.transform_apply(scale=True)
    upper.data.materials.append(mat_plaster)

    # Timber Corner Posts
    for px, py in [(-1.05, -0.72), (-1.05, 0.72), (0.85, -0.72), (0.85, 0.72)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, 0.75))
        beam = bpy.context.active_object
        beam.scale = (0.12, 0.12, 1.1)
        bpy.ops.object.transform_apply(scale=True)
        beam.data.materials.append(mat_wood_dark)

    # Horizontal Timber Beam
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, 0, 1.22))
    h_beam = bpy.context.active_object
    h_beam.scale = (2.05, 1.55, 0.1)
    bpy.ops.object.transform_apply(scale=True)
    h_beam.data.materials.append(mat_wood_dark)

    # 4. Gabled Terracotta Roof (Pitched roof)
    # Right slope
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, 0.45, 1.62))
    roof_r = bpy.context.active_object
    roof_r.scale = (2.3, 1.15, 0.1)
    roof_r.rotation_euler = (math.radians(-38), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    roof_r.data.materials.append(mat_roof)

    # Left slope
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, -0.45, 1.62))
    roof_l = bpy.context.active_object
    roof_l.scale = (2.3, 1.15, 0.1)
    roof_l.rotation_euler = (math.radians(38), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    roof_l.data.materials.append(mat_roof)

    # Ridge beam
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, 0, 1.98))
    ridge = bpy.context.active_object
    ridge.scale = (2.35, 0.15, 0.12)
    bpy.ops.object.transform_apply(scale=True)
    ridge.data.materials.append(mat_wood_dark)

    # 5. Stone Chimney
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.7, 0.35, 1.85))
    chimney = bpy.context.active_object
    chimney.scale = (0.35, 0.35, 1.1)
    bpy.ops.object.transform_apply(scale=True)
    chimney.data.materials.append(mat_chimney)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.7, 0.35, 2.42))
    chimney_cap = bpy.context.active_object
    chimney_cap.scale = (0.42, 0.42, 0.08)
    bpy.ops.object.transform_apply(scale=True)
    chimney_cap.data.materials.append(mat_chimney)

    # 6. Silo / Granary Tower (attached to the right side)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=1.6, location=(1.25, -0.2, 0.8))
    silo = bpy.context.active_object
    silo.data.materials.append(mat_wood_dark)

    # Conical roof on silo
    bpy.ops.mesh.primitive_cone_add(radius1=0.55, depth=0.6, location=(1.25, -0.2, 1.9))
    silo_roof = bpy.context.active_object
    silo_roof.data.materials.append(mat_roof)

    # 7. Front Arched Door & Windows
    # Front door (facing -Y)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, -0.76, 0.45))
    door = bpy.context.active_object
    door.scale = (0.38, 0.05, 0.65)
    bpy.ops.object.transform_apply(scale=True)
    door.data.materials.append(mat_door)

    # Windows with warm interior light
    for wx, wy, wz in [(-0.65, -0.73, 0.9), (0.45, -0.73, 0.9)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(wx, wy, wz))
        win = bpy.context.active_object
        win.scale = (0.28, 0.05, 0.28)
        bpy.ops.object.transform_apply(scale=True)
        win.data.materials.append(mat_window)

    # 8. Golden Hay Bales near silo
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.35, location=(0.7, -0.9, 0.18))
    hay1 = bpy.context.active_object
    hay1.rotation_euler = (0, math.radians(90), math.radians(30))
    hay1.data.materials.append(mat_gold_hay)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=0.32, location=(1.05, -0.85, 0.16))
    hay2 = bpy.context.active_object
    hay2.rotation_euler = (0, math.radians(90), math.radians(110))
    hay2.data.materials.append(mat_gold_hay)

    # Render
    out_path = os.path.join(OUTPUT_BUILDINGS, "building_farm_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("SAVED FARM: " + out_path)


def build_gold_icon():
    """Renders 3 gleaming stacked gold coins with beveled rims."""
    reset_scene()
    setup_lighting()
    setup_camera(ortho_scale=2.6, res=128)

    mat_gold = create_material("GoldCoin", (1.0, 0.82, 0.15, 1), roughness=0.18, metallic=0.92)
    mat_gold_edge = create_material("GoldEdge", (0.95, 0.72, 0.10, 1), roughness=0.25, metallic=0.88)

    # Coin 1 (bottom)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.8, depth=0.22, location=(0.1, -0.1, -0.15))
    c1 = bpy.context.active_object
    c1.rotation_euler = (math.radians(15), math.radians(10), math.radians(-20))
    c1.data.materials.append(mat_gold)

    # Coin 2 (middle)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.8, depth=0.22, location=(-0.15, 0.05, 0.08))
    c2 = bpy.context.active_object
    c2.rotation_euler = (math.radians(-5), math.radians(-12), math.radians(15))
    c2.data.materials.append(mat_gold)

    # Coin 3 (top upright/tilted)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.8, depth=0.22, location=(0.0, 0.1, 0.32))
    c3 = bpy.context.active_object
    c3.rotation_euler = (math.radians(20), math.radians(-15), math.radians(35))
    c3.data.materials.append(mat_gold)

    out_path = os.path.join(OUTPUT_UI, "icon_gold_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("SAVED GOLD ICON: " + out_path)


def build_wood_icon():
    """Renders a bundle of three cut logs with natural timber ends and bark."""
    reset_scene()
    setup_lighting()
    setup_camera(ortho_scale=2.8, res=128)

    mat_bark = create_material("Bark", (0.32, 0.20, 0.12, 1), roughness=0.85)
    mat_wood_end = create_material("WoodEnd", (0.78, 0.62, 0.42, 1), roughness=0.6)

    # Log 1 (bottom left)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.38, depth=1.5, location=(-0.35, -0.1, -0.15))
    l1 = bpy.context.active_object
    l1.rotation_euler = (math.radians(20), math.radians(70), math.radians(15))
    l1.data.materials.append(mat_bark)

    # Log 2 (bottom right)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.38, depth=1.5, location=(0.35, -0.1, -0.12))
    l2 = bpy.context.active_object
    l2.rotation_euler = (math.radians(22), math.radians(72), math.radians(18))
    l2.data.materials.append(mat_bark)

    # Log 3 (top resting on both)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.40, depth=1.55, location=(0.0, 0.05, 0.38))
    l3 = bpy.context.active_object
    l3.rotation_euler = (math.radians(18), math.radians(68), math.radians(12))
    l3.data.materials.append(mat_bark)

    out_path = os.path.join(OUTPUT_UI, "icon_wood_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("SAVED WOOD ICON: " + out_path)


def build_food_icon():
    """Renders a basket of golden wheat sheaves and crisp red apples."""
    reset_scene()
    setup_lighting()
    setup_camera(ortho_scale=2.7, res=128)

    mat_basket = create_material("BasketWicker", (0.55, 0.40, 0.22, 1), roughness=0.8)
    mat_wheat = create_material("WheatGold", (0.92, 0.78, 0.28, 1), roughness=0.7)
    mat_apple = create_material("RedApple", (0.85, 0.12, 0.10, 1), roughness=0.25)
    mat_leaf = create_material("AppleLeaf", (0.22, 0.65, 0.18, 1), roughness=0.5)

    # Basket bowl
    bpy.ops.mesh.primitive_cone_add(radius1=0.75, radius2=0.5, depth=0.55, location=(0, 0, -0.1))
    basket = bpy.context.active_object
    basket.rotation_euler = (math.radians(180), 0, 0)
    basket.data.materials.append(mat_basket)

    # Wheat sheaves sticking up
    for angle, tilt in [(-25, 0.65), (0, 0.75), (25, 0.65), (-15, 0.8), (15, 0.8)]:
        bpy.ops.mesh.primitive_cone_add(radius1=0.14, depth=0.8, location=(math.sin(math.radians(angle))*0.3, 0.2, 0.45 + tilt*0.2))
        wheat = bpy.context.active_object
        wheat.rotation_euler = (math.radians(20), math.radians(-angle*0.6), 0)
        wheat.data.materials.append(mat_wheat)

    # 3 Red Apples in foreground
    for ax, ay, az in [(-0.25, -0.22, 0.22), (0.22, -0.20, 0.24), (0.0, -0.32, 0.15)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.24, location=(ax, ay, az))
        apple = bpy.context.active_object
        apple.data.materials.append(mat_apple)

    out_path = os.path.join(OUTPUT_UI, "icon_food_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("SAVED FOOD ICON: " + out_path)


def main():
    print("=== STARTING 3D ASSET RENDERING PIPELINE ===")
    build_farm()
    build_gold_icon()
    build_wood_icon()
    build_food_icon()
    print("=== ASSET RENDERING COMPLETED SUCCESSFULLY ===")


if __name__ == "__main__":
    main()
