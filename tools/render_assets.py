"""
Blender 3D Asset Generator for Strategy Game
Renders high-quality 2.5D pre-rendered sprites and icons with isometric lighting.
Includes all 7 buildings: Farm, Lumber Mill, Mine, Market, Dock, House, Workshop.
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
    sun_data.energy = 3.6
    sun_data.color = (1.0, 0.96, 0.88)
    sun_obj = bpy.data.objects.new(name="KeySun", object_data=sun_data)
    bpy.context.scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(50), math.radians(20), math.radians(-35))

    # Fill Light (Cool sky bounce)
    fill_data = bpy.data.lights.new(name="FillLight", type='SUN')
    fill_data.energy = 1.3
    fill_data.color = (0.75, 0.85, 1.0)
    fill_obj = bpy.data.objects.new(name="FillLight", object_data=fill_data)
    bpy.context.scene.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (math.radians(35), math.radians(-30), math.radians(145))

    # Rim / Back Light (warm highlight on silhouette edges)
    rim_data = bpy.data.lights.new(name="RimLight", type='SUN')
    rim_data.energy = 1.9
    rim_data.color = (1.0, 0.9, 0.7)
    rim_obj = bpy.data.objects.new(name="RimLight", object_data=rim_data)
    bpy.context.scene.collection.objects.link(rim_obj)
    rim_obj.rotation_euler = (math.radians(-40), math.radians(10), math.radians(-120))


def setup_camera(ortho_scale=4.4, res=256):
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


# =============================================================================
# 1. FARM
# =============================================================================
def build_farm():
    reset_scene()
    setup_lighting()
    cam = setup_camera(ortho_scale=4.2, res=256)
    cam.location.z += 0.4

    mat_stone = create_material("StoneBase", (0.35, 0.33, 0.31, 1), roughness=0.9)
    mat_wood_dark = create_material("DarkWood", (0.28, 0.18, 0.11, 1), roughness=0.7)
    mat_plaster = create_material("Plaster", (0.85, 0.82, 0.75, 1), roughness=0.8)
    mat_roof = create_material("TileRoof", (0.76, 0.28, 0.16, 1), roughness=0.6)
    mat_gold_hay = create_material("Hay", (0.88, 0.75, 0.25, 1), roughness=0.95)
    mat_chimney = create_material("ChimneyStone", (0.25, 0.24, 0.23, 1), roughness=0.9)
    mat_door = create_material("DoorWood", (0.20, 0.13, 0.08, 1), roughness=0.6)
    mat_window = create_material("WindowGlow", (1.0, 0.9, 0.5, 1), roughness=0.3, emission_color=(1.0, 0.85, 0.4, 1), emission_strength=1.5)
    mat_grass = create_material("GroundMound", (0.30, 0.58, 0.25, 1), roughness=0.9)

    # Ground Base
    bpy.ops.mesh.primitive_cylinder_add(radius=1.8, depth=0.15, location=(0, 0, -0.07))
    bpy.context.active_object.data.materials.append(mat_grass)

    # Stone Foundation
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, 0, 0.25))
    base = bpy.context.active_object
    base.scale = (2.0, 1.5, 0.5)
    bpy.ops.object.transform_apply(scale=True)
    base.data.materials.append(mat_stone)

    # Main Upper Story
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, 0, 0.85))
    upper = bpy.context.active_object
    upper.scale = (1.9, 1.4, 0.7)
    bpy.ops.object.transform_apply(scale=True)
    upper.data.materials.append(mat_plaster)

    # Corner Posts
    for px, py in [(-1.05, -0.72), (-1.05, 0.72), (0.85, -0.72), (0.85, 0.72)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, 0.75))
        beam = bpy.context.active_object
        beam.scale = (0.12, 0.12, 1.1)
        bpy.ops.object.transform_apply(scale=True)
        beam.data.materials.append(mat_wood_dark)

    # Gabled Roof
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, 0.45, 1.62))
    roof_r = bpy.context.active_object
    roof_r.scale = (2.3, 1.15, 0.1)
    roof_r.rotation_euler = (math.radians(-38), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    roof_r.data.materials.append(mat_roof)

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

    # Stone Chimney
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.7, 0.35, 1.85))
    chimney = bpy.context.active_object
    chimney.scale = (0.35, 0.35, 1.1)
    bpy.ops.object.transform_apply(scale=True)
    chimney.data.materials.append(mat_chimney)

    # Silo
    bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=1.6, location=(1.25, -0.2, 0.8))
    bpy.context.active_object.data.materials.append(mat_wood_dark)

    bpy.ops.mesh.primitive_cone_add(radius1=0.55, depth=0.6, location=(1.25, -0.2, 1.9))
    bpy.context.active_object.data.materials.append(mat_roof)

    # Door & Windows
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.1, -0.76, 0.45))
    door = bpy.context.active_object
    door.scale = (0.38, 0.05, 0.65)
    bpy.ops.object.transform_apply(scale=True)
    door.data.materials.append(mat_door)

    for wx, wy, wz in [(-0.65, -0.73, 0.9), (0.45, -0.73, 0.9)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(wx, wy, wz))
        win = bpy.context.active_object
        win.scale = (0.28, 0.05, 0.28)
        bpy.ops.object.transform_apply(scale=True)
        win.data.materials.append(mat_window)

    # Hay bales
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.35, location=(0.7, -0.9, 0.18))
    hay1 = bpy.context.active_object
    hay1.rotation_euler = (0, math.radians(90), math.radians(30))
    hay1.data.materials.append(mat_gold_hay)

    out_path = os.path.join(OUTPUT_BUILDINGS, "building_farm_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("RENDERED: " + out_path)


# =============================================================================
# 2. LUMBER MILL
# =============================================================================
def build_lumber_mill():
    reset_scene()
    setup_lighting()
    cam = setup_camera(ortho_scale=4.4, res=256)
    cam.location.z += 0.3

    mat_dirt = create_material("ForestGround", (0.28, 0.38, 0.22, 1), roughness=0.95)
    mat_wood_body = create_material("LogWood", (0.45, 0.28, 0.16, 1), roughness=0.8)
    mat_timber_dark = create_material("DarkBeams", (0.24, 0.15, 0.09, 1), roughness=0.7)
    mat_green_roof = create_material("MossyRoof", (0.22, 0.38, 0.24, 1), roughness=0.7)
    mat_steel = create_material("SawSteel", (0.85, 0.88, 0.92, 1), roughness=0.25, metallic=0.92)
    mat_water = create_material("StreamWater", (0.20, 0.48, 0.75, 1), roughness=0.2)
    mat_cut_wood = create_material("CutPlanks", (0.82, 0.65, 0.45, 1), roughness=0.6)

    # Ground
    bpy.ops.mesh.primitive_cylinder_add(radius=1.85, depth=0.15, location=(0, 0, -0.07))
    bpy.context.active_object.data.materials.append(mat_dirt)

    # Small Water Channel for wheel
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.15, 0, 0.02))
    stream = bpy.context.active_object
    stream.scale = (0.6, 2.8, 0.08)
    bpy.ops.object.transform_apply(scale=True)
    stream.data.materials.append(mat_water)

    # Main Mill House Body
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.35, 0, 0.65))
    house = bpy.context.active_object
    house.scale = (1.6, 1.8, 1.2)
    bpy.ops.object.transform_apply(scale=True)
    house.data.materials.append(mat_wood_body)

    # Timber Framing
    for bx, by in [(-1.15, -0.9), (-1.15, 0.9), (0.45, -0.9), (0.45, 0.9)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, by, 0.65))
        post = bpy.context.active_object
        post.scale = (0.12, 0.12, 1.3)
        bpy.ops.object.transform_apply(scale=True)
        post.data.materials.append(mat_timber_dark)

    # Gabled Roof
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.35, 0.55, 1.55))
    rf1 = bpy.context.active_object
    rf1.scale = (1.9, 1.25, 0.1)
    rf1.rotation_euler = (math.radians(-35), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    rf1.data.materials.append(mat_green_roof)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.35, -0.55, 1.55))
    rf2 = bpy.context.active_object
    rf2.scale = (1.9, 1.25, 0.1)
    rf2.rotation_euler = (math.radians(35), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    rf2.data.materials.append(mat_green_roof)

    # Big Waterwheel on Right Side
    wheel_center = (0.85, 0, 0.65)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=0.35, location=wheel_center)
    hub = bpy.context.active_object
    hub.rotation_euler = (0, math.radians(90), 0)
    hub.data.materials.append(mat_timber_dark)

    for i in range(8):
        angle = i * (math.pi / 4.0)
        py = math.cos(angle) * 0.75
        pz = math.sin(angle) * 0.75
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(wheel_center[0], wheel_center[1] + py, wheel_center[2] + pz))
        spoke = bpy.context.active_object
        spoke.scale = (0.28, 0.22, 0.05)
        spoke.rotation_euler = (angle, 0, 0)
        bpy.ops.object.transform_apply(scale=True, rotation=False)
        spoke.data.materials.append(mat_wood_body)

    # Open Saw Shed at the front
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.35, -1.35, 0.35))
    bench = bpy.context.active_object
    bench.scale = (1.4, 0.45, 0.5)
    bpy.ops.object.transform_apply(scale=True)
    bench.data.materials.append(mat_timber_dark)

    # Big Log on Bench
    bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=1.3, location=(-0.35, -1.35, 0.72))
    saw_log = bpy.context.active_object
    saw_log.rotation_euler = (0, math.radians(90), 0)
    saw_log.data.materials.append(mat_cut_wood)

    # Steel Circular Saw Blade
    bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=0.04, location=(-0.35, -1.35, 0.85))
    saw_blade = bpy.context.active_object
    saw_blade.rotation_euler = (0, math.radians(90), 0)
    saw_blade.data.materials.append(mat_steel)

    # Piles of Planks on Left Ground
    for i in range(4):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-1.3, -0.4, 0.08 + i * 0.08))
        plank = bpy.context.active_object
        plank.scale = (0.55, 1.1, 0.06)
        bpy.ops.object.transform_apply(scale=True)
        plank.data.materials.append(mat_cut_wood)

    out_path = os.path.join(OUTPUT_BUILDINGS, "building_lumber_mill_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("RENDERED: " + out_path)


# =============================================================================
# 3. MINE
# =============================================================================
def build_mine():
    reset_scene()
    setup_lighting()
    cam = setup_camera(ortho_scale=4.5, res=256)
    cam.location.z += 0.4

    mat_rock = create_material("MountainRock", (0.42, 0.38, 0.35, 1), roughness=0.92)
    mat_rock_dark = create_material("DeepRock", (0.22, 0.20, 0.18, 1), roughness=0.95)
    mat_timber = create_material("MineTimber", (0.32, 0.19, 0.10, 1), roughness=0.8)
    mat_gold_ore = create_material("GoldOre", (1.0, 0.82, 0.15, 1), roughness=0.2, metallic=0.95)
    mat_iron_rail = create_material("IronRail", (0.28, 0.28, 0.32, 1), roughness=0.4, metallic=0.85)
    mat_lantern = create_material("LanternLight", (1.0, 0.75, 0.25, 1), roughness=0.2, emission_color=(1.0, 0.7, 0.2, 1), emission_strength=3.0)

    # 1. Mountain Cliff Backdrop
    for rx, ry, rz, s in [
        (0.0, 0.5, 1.2, (2.4, 1.6, 2.2)),
        (-1.2, 0.2, 0.9, (1.6, 1.5, 1.8)),
        (1.1, 0.3, 1.0, (1.5, 1.5, 1.9)),
        (0.2, 0.8, 2.1, (1.8, 1.2, 1.4)),
    ]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(rx, ry, rz))
        rock = bpy.context.active_object
        rock.scale = s
        rock.rotation_euler = (math.radians(random_val := 8), math.radians(random_val), 0)
        bpy.ops.object.transform_apply(scale=True, rotation=False)
        rock.data.materials.append(mat_rock)

    # Gold Veins embedded in rock
    for gx, gy, gz in [(-1.3, 0.0, 1.1), (0.9, 0.2, 1.4), (0.0, 0.7, 2.1)]:
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.25, subdivisions=2, location=(gx, gy, gz))
        gold_nugget = bpy.context.active_object
        gold_nugget.data.materials.append(mat_gold_ore)

    # 2. Mine Tunnel Mouth (Dark Void)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.15, 0.75))
    tunnel = bpy.context.active_object
    tunnel.scale = (1.2, 0.8, 1.4)
    bpy.ops.object.transform_apply(scale=True)
    tunnel.data.materials.append(mat_rock_dark)

    # 3. Wooden Portal Beams
    # Left post
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.65, -0.2, 0.75))
    lp = bpy.context.active_object
    lp.scale = (0.18, 0.2, 1.5)
    bpy.ops.object.transform_apply(scale=True)
    lp.data.materials.append(mat_timber)

    # Right post
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.65, -0.2, 0.75))
    rp = bpy.context.active_object
    rp.scale = (0.18, 0.2, 1.5)
    bpy.ops.object.transform_apply(scale=True)
    rp.data.materials.append(mat_timber)

    # Header beam
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.2, 1.52))
    hb = bpy.context.active_object
    hb.scale = (1.6, 0.25, 0.2)
    bpy.ops.object.transform_apply(scale=True)
    hb.data.materials.append(mat_timber)

    # Hanging Lantern
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.32, 1.3))
    lantern = bpy.context.active_object
    lantern.scale = (0.16, 0.16, 0.24)
    bpy.ops.object.transform_apply(scale=True)
    lantern.data.materials.append(mat_lantern)

    # 4. Rail Tracks
    for tie_y in [-0.1, -0.45, -0.8, -1.15]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, tie_y, 0.05))
        tie = bpy.context.active_object
        tie.scale = (0.8, 0.14, 0.06)
        bpy.ops.object.transform_apply(scale=True)
        tie.data.materials.append(mat_timber)

    # Left & Right Rails
    for rx in [-0.28, 0.28]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(rx, -0.6, 0.1))
        rail = bpy.context.active_object
        rail.scale = (0.06, 1.4, 0.06)
        bpy.ops.object.transform_apply(scale=True)
        rail.data.materials.append(mat_iron_rail)

    # 5. Minecart on rails
    cart_center = (0.0, -0.7, 0.35)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=cart_center)
    cart = bpy.context.active_object
    cart.scale = (0.6, 0.75, 0.4)
    bpy.ops.object.transform_apply(scale=True)
    cart.data.materials.append(mat_timber)

    # Minecart Wheels
    for wx, wy in [(-0.32, -0.9), (-0.32, -0.5), (0.32, -0.9), (0.32, -0.5)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.06, location=(wx, wy, 0.15))
        wheel = bpy.context.active_object
        wheel.rotation_euler = (0, math.radians(90), 0)
        wheel.data.materials.append(mat_iron_rail)

    # Gold pile inside minecart
    for gx, gy in [(-0.12, -0.72), (0.12, -0.68), (0.0, -0.75)]:
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.15, location=(gx, gy, 0.58))
        bpy.context.active_object.data.materials.append(mat_gold_ore)

    out_path = os.path.join(OUTPUT_BUILDINGS, "building_mine_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("RENDERED: " + out_path)


# =============================================================================
# 4. MARKET
# =============================================================================
def build_market():
    reset_scene()
    setup_lighting()
    cam = setup_camera(ortho_scale=4.4, res=256)
    cam.location.z += 0.35

    mat_pave = create_material("MarketPaving", (0.58, 0.55, 0.50, 1), roughness=0.9)
    mat_wood = create_material("StallWood", (0.42, 0.28, 0.16, 1), roughness=0.75)
    mat_red_cloth = create_material("CrimsonAwning", (0.82, 0.15, 0.12, 1), roughness=0.6)
    mat_cream_cloth = create_material("CreamAwning", (0.92, 0.88, 0.76, 1), roughness=0.6)
    mat_blue_cloth = create_material("BlueAwning", (0.18, 0.42, 0.75, 1), roughness=0.6)
    mat_basket = create_material("Wicker", (0.68, 0.52, 0.32, 1), roughness=0.8)
    mat_apples = create_material("Apples", (0.85, 0.12, 0.10, 1), roughness=0.25)
    mat_bread = create_material("BreadLoaf", (0.82, 0.62, 0.32, 1), roughness=0.7)

    # 1. Cobblestone Ground Base
    bpy.ops.mesh.primitive_cylinder_add(radius=1.85, depth=0.15, location=(0, 0, -0.07))
    bpy.context.active_object.data.materials.append(mat_pave)

    # 2. Main Market Stall (Center-Left)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.35, 0.1, 0.4))
    counter = bpy.context.active_object
    counter.scale = (1.6, 0.9, 0.7)
    bpy.ops.object.transform_apply(scale=True)
    counter.data.materials.append(mat_wood)

    # 4 Awning Posts
    for px, py in [(-1.1, -0.32), (-1.1, 0.52), (0.4, -0.32), (0.4, 0.52)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, 1.0))
        post = bpy.context.active_object
        post.scale = (0.08, 0.08, 1.4)
        bpy.ops.object.transform_apply(scale=True)
        post.data.materials.append(mat_wood)

    # Striped Canopy (Slanted Red/Cream panels)
    for i in range(6):
        stripe_mat = mat_red_cloth if i % 2 == 0 else mat_cream_cloth
        px = -1.1 + (i * 0.28) + 0.14
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, 0.1, 1.72))
        panel = bpy.context.active_object
        panel.scale = (0.28, 1.15, 0.06)
        panel.rotation_euler = (math.radians(-15), 0, 0)
        bpy.ops.object.transform_apply(scale=True, rotation=False)
        panel.data.materials.append(stripe_mat)

    # Counter Goods: Fruit Basket, Bread, Sacks
    bpy.ops.mesh.primitive_cone_add(radius1=0.22, depth=0.2, location=(-0.8, 0.05, 0.85))
    basket = bpy.context.active_object
    basket.rotation_euler = (math.radians(180), 0, 0)
    basket.data.materials.append(mat_basket)

    for ax, ay in [(-0.84, 0.02), (-0.76, 0.08), (-0.8, 0.04)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(ax, ay, 0.96))
        bpy.context.active_object.data.materials.append(mat_apples)

    # Bread Loaf
    bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.35, location=(-0.3, 0.05, 0.82))
    bread = bpy.context.active_object
    bread.rotation_euler = (0, math.radians(90), math.radians(20))
    bread.data.materials.append(mat_bread)

    # 3. Smaller Adjacent Stall (Blue Canopy)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.95, -0.3, 0.35))
    stall2 = bpy.context.active_object
    stall2.scale = (0.8, 0.8, 0.6)
    bpy.ops.object.transform_apply(scale=True)
    stall2.data.materials.append(mat_wood)

    # Blue awning
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.95, -0.3, 1.25))
    awning2 = bpy.context.active_object
    awning2.scale = (0.95, 0.95, 0.06)
    awning2.rotation_euler = (math.radians(-18), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    awning2.data.materials.append(mat_blue_cloth)

    # 4. Barrels and Crates in foreground
    bpy.ops.mesh.primitive_cylinder_add(radius=0.24, depth=0.55, location=(-0.2, -0.85, 0.28))
    bpy.context.active_object.data.materials.append(mat_wood)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.4, -0.85, 0.22))
    crate = bpy.context.active_object
    crate.scale = (0.42, 0.42, 0.42)
    bpy.ops.object.transform_apply(scale=True)
    crate.data.materials.append(mat_wood)

    out_path = os.path.join(OUTPUT_BUILDINGS, "building_market_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("RENDERED: " + out_path)


# =============================================================================
# 5. DOCK
# =============================================================================
def build_dock():
    reset_scene()
    setup_lighting()
    cam = setup_camera(ortho_scale=4.4, res=256)
    cam.location.z += 0.3

    mat_water = create_material("HarborWater", (0.16, 0.46, 0.78, 1), roughness=0.15)
    mat_planks = create_material("DockPlanks", (0.55, 0.42, 0.28, 1), roughness=0.75)
    mat_stilts = create_material("StiltsWood", (0.28, 0.18, 0.11, 1), roughness=0.85)
    mat_boat = create_material("BoatHull", (0.72, 0.25, 0.18, 1), roughness=0.6)
    mat_boat_interior = create_material("BoatInside", (0.82, 0.68, 0.48, 1), roughness=0.7)
    mat_rope = create_material("RopeCoil", (0.75, 0.65, 0.45, 1), roughness=0.9)
    mat_fish_box = create_material("FishBox", (0.62, 0.52, 0.40, 1), roughness=0.8)

    # 1. Harbor Water Base
    bpy.ops.mesh.primitive_cylinder_add(radius=1.85, depth=0.15, location=(0, 0, -0.07))
    bpy.context.active_object.data.materials.append(mat_water)

    # 2. Pier Boardwalk (Extending out)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.25, 0.0, 0.38))
    deck = bpy.context.active_object
    deck.scale = (1.5, 2.4, 0.12)
    bpy.ops.object.transform_apply(scale=True)
    deck.data.materials.append(mat_planks)

    # Wooden Pilings / Stilts under the deck
    for sx, sy in [(-0.95, -1.05), (-0.95, 0.0), (-0.95, 1.05), (0.45, -1.05), (0.45, 0.0), (0.45, 1.05)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.09, depth=0.7, location=(sx, sy, 0.15))
        bpy.context.active_object.data.materials.append(mat_stilts)

    # Mooring Bollards / Cleats
    for bx, by in [(-0.95, -1.1), (0.45, -1.1), (0.45, 0.6)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=0.28, location=(bx, by, 0.52))
        bpy.context.active_object.data.materials.append(mat_stilts)

    # 3. Moored Rowboat / Skiff (Right of the pier)
    boat_pos = (1.05, 0.2, 0.08)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=1.35, location=boat_pos)
    boat = bpy.context.active_object
    boat.scale = (0.65, 1.25, 0.45)
    boat.rotation_euler = (0, 0, math.radians(-12))
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    boat.data.materials.append(mat_boat)

    # Boat bench seat
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(boat_pos[0], boat_pos[1], boat_pos[2] + 0.12))
    seat = bpy.context.active_object
    seat.scale = (0.48, 0.22, 0.05)
    seat.rotation_euler = (0, 0, math.radians(-12))
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    seat.data.materials.append(mat_boat_interior)

    # 4. Cargo Crane / Davit on Pier
    crane_base = (-0.65, 0.75, 0.44)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=1.4, location=(-0.65, 0.75, 1.1))
    bpy.context.active_object.data.materials.append(mat_stilts)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.4, 0.75, 1.75))
    crane_arm = bpy.context.active_object
    crane_arm.scale = (0.8, 0.08, 0.08)
    bpy.ops.object.transform_apply(scale=True)
    crane_arm.data.materials.append(mat_stilts)

    # 5. Fish Crates & Rope Coils on Deck
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.5, -0.6, 0.55))
    crate1 = bpy.context.active_object
    crate1.scale = (0.45, 0.45, 0.3)
    bpy.ops.object.transform_apply(scale=True)
    crate1.data.materials.append(mat_fish_box)

    bpy.ops.mesh.primitive_torus_add(major_radius=0.18, minor_radius=0.05, location=(-0.1, -0.4, 0.47))
    bpy.context.active_object.data.materials.append(mat_rope)

    out_path = os.path.join(OUTPUT_BUILDINGS, "building_dock_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("RENDERED: " + out_path)


# =============================================================================
# 6. WORKSHOP
# =============================================================================
def build_workshop():
    reset_scene()
    setup_lighting()
    cam = setup_camera(ortho_scale=4.4, res=256)
    cam.location.z += 0.35

    mat_ground = create_material("ForgeFloor", (0.45, 0.42, 0.38, 1), roughness=0.95)
    mat_stone = create_material("SmithyStone", (0.36, 0.34, 0.32, 1), roughness=0.9)
    mat_slate_roof = create_material("SlateRoof", (0.28, 0.30, 0.34, 1), roughness=0.6)
    mat_timber = create_material("ForgeTimber", (0.26, 0.16, 0.09, 1), roughness=0.8)
    mat_anvil_iron = create_material("AnvilIron", (0.22, 0.22, 0.25, 1), roughness=0.35, metallic=0.85)
    mat_hot_fire = create_material("ForgeFire", (1.0, 0.35, 0.05, 1), roughness=0.2, emission_color=(1.0, 0.4, 0.05, 1), emission_strength=4.0)
    mat_steel_blade = create_material("SwordBlade", (0.92, 0.94, 0.96, 1), roughness=0.2, metallic=0.95)
    mat_shield_gold = create_material("ShieldBoss", (0.95, 0.75, 0.2, 1), roughness=0.3, metallic=0.9)

    # 1. Cobblestone Ground
    bpy.ops.mesh.primitive_cylinder_add(radius=1.85, depth=0.15, location=(0, 0, -0.07))
    bpy.context.active_object.data.materials.append(mat_ground)

    # 2. Main Smithy Workshop Building
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.35, 0.15, 0.65))
    body = bpy.context.active_object
    body.scale = (1.6, 1.5, 1.2)
    bpy.ops.object.transform_apply(scale=True)
    body.data.materials.append(mat_stone)

    # Slanted Slate Roof
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.35, 0.15, 1.6))
    rf = bpy.context.active_object
    rf.scale = (1.85, 1.75, 0.12)
    rf.rotation_euler = (math.radians(-25), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    rf.data.materials.append(mat_slate_roof)

    # Stone Chimney
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.95, 0.45, 1.85))
    chim = bpy.context.active_object
    chim.scale = (0.4, 0.4, 1.3)
    bpy.ops.object.transform_apply(scale=True)
    chim.data.materials.append(mat_stone)

    # 3. Open Forge & Hearth
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.7, 0.2, 0.45))
    hearth = bpy.context.active_object
    hearth.scale = (0.9, 0.9, 0.8)
    bpy.ops.object.transform_apply(scale=True)
    hearth.data.materials.append(mat_stone)

    # Glowing Embers / Fire
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.25, location=(0.7, 0.2, 0.9))
    bpy.context.active_object.data.materials.append(mat_hot_fire)

    # Forge Hood / Chimney
    bpy.ops.mesh.primitive_cone_add(radius1=0.55, depth=0.6, location=(0.7, 0.2, 1.45))
    bpy.context.active_object.data.materials.append(mat_stone)

    # 4. Blacksmith Anvil on Wooden Stump (Foreground)
    stump_pos = (-0.1, -0.85, 0.25)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.28, depth=0.48, location=stump_pos)
    bpy.context.active_object.data.materials.append(mat_timber)

    # Iron Anvil
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(stump_pos[0], stump_pos[1], stump_pos[2] + 0.32))
    anvil = bpy.context.active_object
    anvil.scale = (0.45, 0.22, 0.2)
    bpy.ops.object.transform_apply(scale=True)
    anvil.data.materials.append(mat_anvil_iron)

    # Anvil Horn (cone)
    bpy.ops.mesh.primitive_cone_add(radius1=0.1, depth=0.22, location=(stump_pos[0] + 0.3, stump_pos[1], stump_pos[2] + 0.32))
    horn = bpy.context.active_object
    horn.rotation_euler = (0, math.radians(90), 0)
    horn.data.materials.append(mat_anvil_iron)

    # 5. Finished Goods leaning on wall
    # Iron Sword
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.25, -0.65, 0.5))
    sword = bpy.context.active_object
    sword.scale = (0.08, 0.03, 0.85)
    sword.rotation_euler = (math.radians(18), math.radians(12), 0)
    sword.data.materials.append(mat_steel_blade)

    # Round Shield
    bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=0.06, location=(-0.7, -0.65, 0.32))
    shield = bpy.context.active_object
    shield.rotation_euler = (math.radians(75), 0, math.radians(-25))
    shield.data.materials.append(mat_timber)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.1, location=(-0.7, -0.64, 0.34))
    bpy.context.active_object.data.materials.append(mat_shield_gold)

    out_path = os.path.join(OUTPUT_BUILDINGS, "building_workshop_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("RENDERED: " + out_path)


# =============================================================================
# RESOURCE ICONS
# =============================================================================
def build_gold_icon():
    reset_scene()
    setup_lighting()
    setup_camera(ortho_scale=2.6, res=128)
    mat_gold = create_material("GoldCoin", (1.0, 0.82, 0.15, 1), roughness=0.18, metallic=0.92)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.8, depth=0.22, location=(0.1, -0.1, -0.15))
    c1 = bpy.context.active_object
    c1.rotation_euler = (math.radians(15), math.radians(10), math.radians(-20))
    c1.data.materials.append(mat_gold)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.8, depth=0.22, location=(-0.15, 0.05, 0.08))
    c2 = bpy.context.active_object
    c2.rotation_euler = (math.radians(-5), math.radians(-12), math.radians(15))
    c2.data.materials.append(mat_gold)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.8, depth=0.22, location=(0.0, 0.1, 0.32))
    c3 = bpy.context.active_object
    c3.rotation_euler = (math.radians(20), math.radians(-15), math.radians(35))
    c3.data.materials.append(mat_gold)

    out_path = os.path.join(OUTPUT_UI, "icon_gold_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("SAVED GOLD ICON: " + out_path)


def build_wood_icon():
    reset_scene()
    setup_lighting()
    setup_camera(ortho_scale=2.8, res=128)
    mat_bark = create_material("Bark", (0.32, 0.20, 0.12, 1), roughness=0.85)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.38, depth=1.5, location=(-0.35, -0.1, -0.15))
    l1 = bpy.context.active_object
    l1.rotation_euler = (math.radians(20), math.radians(70), math.radians(15))
    l1.data.materials.append(mat_bark)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.38, depth=1.5, location=(0.35, -0.1, -0.12))
    l2 = bpy.context.active_object
    l2.rotation_euler = (math.radians(22), math.radians(72), math.radians(18))
    l2.data.materials.append(mat_bark)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.40, depth=1.55, location=(0.0, 0.05, 0.38))
    l3 = bpy.context.active_object
    l3.rotation_euler = (math.radians(18), math.radians(68), math.radians(12))
    l3.data.materials.append(mat_bark)

    out_path = os.path.join(OUTPUT_UI, "icon_wood_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("SAVED WOOD ICON: " + out_path)


def build_food_icon():
    reset_scene()
    setup_lighting()
    setup_camera(ortho_scale=2.7, res=128)
    mat_basket = create_material("BasketWicker", (0.55, 0.40, 0.22, 1), roughness=0.8)
    mat_wheat = create_material("WheatGold", (0.92, 0.78, 0.28, 1), roughness=0.7)
    mat_apple = create_material("RedApple", (0.85, 0.12, 0.10, 1), roughness=0.25)

    bpy.ops.mesh.primitive_cone_add(radius1=0.75, radius2=0.5, depth=0.55, location=(0, 0, -0.1))
    basket = bpy.context.active_object
    basket.rotation_euler = (math.radians(180), 0, 0)
    basket.data.materials.append(mat_basket)

    for angle, tilt in [(-25, 0.65), (0, 0.75), (25, 0.65), (-15, 0.8), (15, 0.8)]:
        bpy.ops.mesh.primitive_cone_add(radius1=0.14, depth=0.8, location=(math.sin(math.radians(angle))*0.3, 0.2, 0.45 + tilt*0.2))
        wheat = bpy.context.active_object
        wheat.rotation_euler = (math.radians(20), math.radians(-angle*0.6), 0)
        wheat.data.materials.append(mat_wheat)

    for ax, ay, az in [(-0.25, -0.22, 0.22), (0.22, -0.20, 0.24), (0.0, -0.32, 0.15)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.24, location=(ax, ay, az))
        bpy.context.active_object.data.materials.append(mat_apple)

    out_path = os.path.join(OUTPUT_UI, "icon_food_3d.png")
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("SAVED FOOD ICON: " + out_path)


def main():
    print("=== STARTING 3D ASSET RENDERING PIPELINE ===")
    print("1/8 Rendering Farm...")
    build_farm()
    print("2/8 Rendering Lumber Mill...")
    build_lumber_mill()
    print("3/8 Rendering Mine...")
    build_mine()
    print("4/8 Rendering Market...")
    build_market()
    print("5/8 Rendering Dock...")
    build_dock()
    print("6/8 Rendering Workshop...")
    build_workshop()
    print("7/8 Rendering Resource Icons...")
    build_gold_icon()
    build_wood_icon()
    build_food_icon()
    print("=== ALL 3D ASSETS RENDERED SUCCESSFULLY ===")


if __name__ == "__main__":
    main()
