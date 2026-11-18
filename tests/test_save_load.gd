extends SceneTree

## Headless integration test for the Save & Load system:
## State gathering, JSON serialization, disk I/O, state restoration, and UI sync.

const TEST_SAVE_PATH: String = "user://test_save_suite.json"
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
	var farm = load("res://resources/building_types/farm.tres")
	var lumber_mill = load("res://resources/building_types/lumber_mill.tres")

	var map_scene: PackedScene = load("res://scenes/map/map.tscn")
	var map = map_scene.instantiate()
	root.add_child(map)
	await process_frame

	var save_mgr = map.get_node_or_null("SaveManager")
	var turn_mgr = map.get_node_or_null("TurnManager")
	var res_mgr = map.get_node_or_null("ResourceManager")
	var layer = map.get_node_or_null("BuildingLayer")
	var top_bar = map.top_bar

	_check(save_mgr != null, "SaveManager node exists in map.tscn")
	_check(turn_mgr != null and res_mgr != null and layer != null, "Subsystems present")
	if save_mgr == null or turn_mgr == null or res_mgr == null or layer == null:
		_finish()
		return

	# Step 1: Simulate game progression to Turn 3
	turn_mgr.advance_turn()
	turn_mgr.advance_turn()
	_check(turn_mgr.get_current_turn() == 3, "Advanced to Turn 3")

	# Step 2: Place buildings
	var plains_coords := Vector2i(0, 2)
	var forest_coords := Vector2i(1, 2)
	_check(map.place_building(plains_coords, farm), "Placed Farm on (0, 2)")
	_check(map.place_building(forest_coords, lumber_mill), "Placed Lumber Mill on (1, 2)")

	var gold_saved: int = res_mgr.get_resources()["gold"]
	var wood_saved: int = res_mgr.get_resources()["wood"]
	var food_saved: int = res_mgr.get_resources()["food"]

	# Step 3: Save game to test file
	var save_success: bool = save_mgr.save_game(TEST_SAVE_PATH)
	_check(save_success, "save_game() returned true")
	_check(FileAccess.file_exists(TEST_SAVE_PATH), "Save file exists on disk at %s" % TEST_SAVE_PATH)

	# Verify JSON content
	var file = FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var json_str = file.get_as_text()
	file.close()
	var json = JSON.new()
	_check(json.parse(json_str) == OK, "Saved file contains valid JSON")
	var data: Dictionary = json.data
	_check(int(data.get("turn", 0)) == 3, "JSON contains turn == 3")
	_check(data.get("buildings", []).size() == 2, "JSON contains 2 buildings")

	# Step 4: Drastically mutate game state
	turn_mgr.set_current_turn(15)
	res_mgr.set_resources({ "gold": 9999, "wood": 8888, "food": 7777 })
	layer.clear_all()
	_check(layer.get_building_count() == 0, "Mutated state: cleared all buildings")
	_check(turn_mgr.get_current_turn() == 15, "Mutated state: Turn 15")

	# Step 5: Load game back from file
	var load_success: bool = save_mgr.load_game(TEST_SAVE_PATH)
	_check(load_success, "load_game() returned true")

	# Step 6: Verify restored state
	_check(turn_mgr.get_current_turn() == 3, "Restored turn count is 3")
	var restored_res = res_mgr.get_resources()
	_check(restored_res["gold"] == gold_saved, "Restored Gold is %d" % gold_saved)
	_check(restored_res["wood"] == wood_saved, "Restored Wood is %d" % wood_saved)
	_check(restored_res["food"] == food_saved, "Restored Food is %d" % food_saved)

	_check(layer.get_building_count() == 2, "Restored building count is 2")
	_check(layer.is_occupied(plains_coords), "Tile (0, 2) is occupied")
	_check(layer.get_building_at(plains_coords).id == "farm", "Building at (0, 2) is Farm")
	_check(layer.is_occupied(forest_coords), "Tile (1, 2) is occupied")
	_check(layer.get_building_at(forest_coords).id == "lumber_mill", "Building at (1, 2) is Lumber Mill")

	# Step 7: Verify TopBar UI reflected restored values
	_check("Turn: 3" in top_bar.turn_label.text, "TopBar turn text restored")
	_check(str(gold_saved) in top_bar.gold_label.text, "TopBar gold text restored")

	# Clean up test file
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL SAVE & LOAD TESTS PASSED 100%")
		quit(0)
	else:
		printerr("%d SAVE & LOAD TEST(S) FAILED" % _failures)
		quit(1)
