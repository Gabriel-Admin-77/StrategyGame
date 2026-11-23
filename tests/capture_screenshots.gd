extends SceneTree

## Captures windowed screenshots of the game for visual review.
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path <project> \
##       --script res://tests/capture_screenshots.gd --resolution 1120x820

const MAP_OFFSET: Vector2 = Vector2(40.0, 56.0)
const TILE_SIZE: float = 64.0
const OUTPUT_DIR: String = "res://tests/screenshots"

var _failures: int = 0


func _init() -> void:
	_capture()


func _capture() -> void:
	var main_scene: PackedScene = load("res://scenes/main/main.tscn")
	if main_scene == null:
		printerr("FAIL: main.tscn did not load")
		quit(1)
		return

	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	await _save_frame("phase1_overview.png")

	var map = main.get_node_or_null("Map")
	if map == null:
		printerr("FAIL: Map node missing")
		quit(1)
		return

	var farm = load("res://resources/building_types/farm.tres")
	var house = load("res://resources/building_types/house.tres")
	var lumber_mill = load("res://resources/building_types/lumber_mill.tres")
	var workshop = load("res://resources/building_types/workshop.tres")
	var market = load("res://resources/building_types/market.tres")
	var dock = load("res://resources/building_types/dock.tres")
	var mine = load("res://resources/building_types/mine.tres")

	var res_mgr = map.get_node_or_null("ResourceManager")
	if res_mgr:
		res_mgr.base_capacity = {"gold": 9999, "wood": 9999, "food": 9999}
		res_mgr.add_resources({"gold": 500, "wood": 500, "food": 500})

	map.place_building(Vector2i(0, 0), mine)
	map.place_building(Vector2i(0, 2), farm)
	map.place_building(Vector2i(1, 2), lumber_mill)
	map.place_building(Vector2i(2, 2), market)
	map.place_building(Vector2i(3, 1), house)
	map.place_building(Vector2i(3, 2), workshop)
	map.place_building(Vector2i(4, 2), dock)
	map._handle_tile_click(Vector2(_tile_center(Vector2i(2, 2))))

	await process_frame
	await process_frame
	await _save_frame("phase1_with_buildings.png")

	# Step 3: Zoomed out overview of the expansive 25x25 kingdom
	var camera = map.get_node_or_null("StrategyCamera")
	if camera:
		camera.zoom = Vector2(0.48, 0.48)
		camera._target_zoom = Vector2(0.48, 0.48)
		camera.position = Vector2(180.0, 120.0)
	await process_frame
	await process_frame
	await _save_frame("map_25x25_zoomed_out.png")

	# Step 4: Zoomed-in detailed living world view showing smoke, glow, and water ripple animations
	if camera:
		camera.zoom = Vector2(1.5, 1.5)
		camera._target_zoom = Vector2(1.5, 1.5)
		camera.position = Vector2(40.0, 60.0)
	for f in range(12):
		await process_frame
	await _save_frame("living_world_animated.png")

	if _failures == 0:
		print("SCREENSHOTS SAVED TO ", OUTPUT_DIR)
		quit(0)
	else:
		printerr("%d SCREENSHOT FAILURE(S)" % _failures)
		quit(1)


func _tile_center(coords: Vector2i) -> Vector2:
	return MAP_OFFSET + Vector2(coords.x * TILE_SIZE + TILE_SIZE * 0.5, coords.y * TILE_SIZE + TILE_SIZE * 0.5)


func _save_frame(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		_failures += 1
		printerr("FAIL: could not read viewport texture")
		return
	var path: String = OUTPUT_DIR.path_join(file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		_failures += 1
		printerr("FAIL: save_png error %d for %s" % [error, path])
	else:
		print("saved ", path, " (", image.get_width(), "x", image.get_height(), ")")
