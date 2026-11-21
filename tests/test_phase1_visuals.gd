extends SceneTree

## Headless verification of the painterly Phase 1 foundation:
## imported art, terrain renderer, selection overlay, HUD theme and camera.

const MAP_OFFSET: Vector2 = Vector2(40.0, 56.0)
const TILE_SIZE: float = 64.0

var _failures: int = 0


func _init() -> void:
	_run_test()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		printerr("FAIL: ", message)


func _run_test() -> void:
	# --- imported artwork ---------------------------------------------------
	var terrain_paths: Array[String] = [
		"res://assets/sprites/terrain/terrain_plains.svg",
		"res://assets/sprites/terrain/terrain_forest.svg",
		"res://assets/sprites/terrain/terrain_water.svg",
		"res://assets/sprites/terrain/terrain_mountain.svg"
	]
	for path: String in terrain_paths:
		var texture = load(path)
		_check(texture is Texture2D, "%s imports as a texture" % path.get_file())
		if texture is Texture2D:
			_check(texture.get_width() == 128 and texture.get_height() == 128, "%s is 128x128 (got %dx%d)" % [path.get_file(), texture.get_width(), texture.get_height()])

	var decor_paths: Array[String] = [
		"res://assets/sprites/fx/decor_grass.svg",
		"res://assets/sprites/fx/decor_flower.svg",
		"res://assets/sprites/fx/decor_rock.svg",
		"res://assets/sprites/fx/decor_foam.svg"
	]
	for path: String in decor_paths:
		_check(load(path) is Texture2D, "%s imports as a texture" % path.get_file())

	var building_paths: Array[String] = [
		"res://assets/sprites/buildings/building_farm.svg",
		"res://assets/sprites/buildings/building_house_3d.png",
		"res://assets/sprites/buildings/building_lumber_mill.svg",
		"res://assets/sprites/buildings/building_workshop.svg"
	]
	for path: String in building_paths:
		var texture = load(path)
		_check(texture is Texture2D, "%s imports as a texture" % path.get_file())
		if texture is Texture2D:
			_check(texture.get_width() == 192, "%s is 192 px wide" % path.get_file())

	var icon_paths: Array[String] = [
		"res://assets/sprites/ui/icon_gold.svg",
		"res://assets/sprites/ui/icon_wood.svg",
		"res://assets/sprites/ui/icon_food.svg",
		"res://assets/sprites/ui/icon_turn.svg",
		"res://assets/sprites/ui/icon_tile.svg",
		"res://assets/sprites/ui/icon_save.svg",
		"res://assets/sprites/ui/icon_load.svg",
		"res://assets/sprites/ui/icon_build.svg"
	]
	for path: String in icon_paths:
		_check(load(path) is Texture2D, "%s imports as a texture" % path.get_file())

	# --- building resources reference art -----------------------------------
	for id: String in ["farm", "house", "lumber_mill", "workshop"]:
		var building = load("res://resources/building_types/%s.tres" % id)
		_check(building != null and building.world_texture != null, "%s.tres has a painted world texture" % id)
		_check(building != null and building.ui_icon != null, "%s.tres has a palette icon" % id)

	# --- scene wiring -------------------------------------------------------
	var main_scene: PackedScene = load("res://scenes/main/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var map = main.get_node_or_null("Map")
	var renderer = map.get_node_or_null("TerrainRenderer") if map else null
	var overlay = map.get_node_or_null("SelectionOverlay") if map else null
	var camera = map.get_node_or_null("StrategyCamera") if map else null
	var hud = map.get_node_or_null("HUD") if map else null

	_check(renderer != null, "Map has a TerrainRenderer")
	_check(overlay != null, "Map has a SelectionOverlay")
	_check(camera != null, "Map has a StrategyCamera")
	_check(hud is CanvasLayer, "HUD is a CanvasLayer (camera independent)")

	if renderer == null or overlay == null or camera == null or hud == null:
		_finish()
		return

	_check(renderer.has_all_terrain_art(), "terrain renderer loaded all four painted terrains")
	_check(renderer.get_texture("Plains") != null, "Plains texture resolved")
	_check(renderer.get_decor_texture("foam") != null, "foam decoration resolved")

	# deterministic variants + decorations
	_check(renderer.get_tile_variant(Vector2i(3, 4)) == renderer.get_tile_variant(Vector2i(3, 4)), "tile variants are deterministic")
	_check(renderer.get_tile_variant(Vector2i(3, 4)) >= 0 and renderer.get_tile_variant(Vector2i(3, 4)) <= 3, "tile variant is within 0-3")
	var decoration: String = renderer.get_decoration_for(Vector2i(1, 2), "Forest")
	_check(decoration == "" or decoration == "grass", "forest decoration is empty or grass")
	_check(renderer.get_decoration_for(Vector2i(4, 2), "Water") == "", "water receives no ground decoration")

	# overlay hover follows the map
	var hovered := Vector2i(2, 2)
	overlay.set_hovered(hovered)
	_check(overlay.get_hovered() == hovered, "overlay stores the hovered tile")

	# camera respects zoom limits and map bounds
	camera._adjust_zoom(99.0)
	_check(is_equal_approx(camera._target_zoom.x, camera.max_zoom), "zoom clamps to max (%.2f)" % camera._target_zoom.x)
	camera._adjust_zoom(-99.0)
	_check(is_equal_approx(camera._target_zoom.x, camera.min_zoom), "zoom clamps to min (%.2f)" % camera._target_zoom.x)
	camera._target_zoom = Vector2.ONE
	camera.zoom = Vector2.ONE
	camera.position = Vector2(99999, 99999)
	camera._clamp_position()
	_check(camera.position.x <= camera.limit_max.x and camera.position.y <= camera.limit_max.y, "camera stays inside its pan limits")

	# HUD is themed and icon driven
	var top_bar = hud.get_node_or_null("TopBar")
	_check(top_bar != null and top_bar.theme != null, "TopBar uses the painted theme")
	_check(top_bar.get_node_or_null("MarginContainer/HBoxContainer/GoldIcon") != null, "TopBar has a painted gold icon")
	_check(not ("💰" in top_bar.gold_label.text), "TopBar no longer relies on emoji glyphs")

	var palette = main.get_node_or_null("UILayer/BuildingPalette")
	_check(palette != null and palette.theme != null, "Building palette uses the painted theme")

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL PHASE 1 VISUAL TESTS PASSED")
		quit(0)
	else:
		printerr("%d PHASE 1 VISUAL TEST(S) FAILED" % _failures)
		quit(1)
