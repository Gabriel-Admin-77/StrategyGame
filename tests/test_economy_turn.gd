extends SceneTree

## Headless verification of the economy + turn loop and its UI wiring.

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
	var map_scene: PackedScene = load("res://scenes/map/map.tscn")
	var map_instance = map_scene.instantiate()
	root.add_child(map_instance)

	# Allow a frame for _ready() and signal connections
	await process_frame

	var turn_mgr = map_instance.get_node_or_null("TurnManager")
	var res_mgr = map_instance.get_node_or_null("ResourceManager")
	var top_bar = map_instance.top_bar
	var tile_panel = map_instance.tile_info_panel

	_check(turn_mgr != null, "TurnManager exists")
	_check(res_mgr != null, "ResourceManager exists")
	_check(top_bar != null, "TopBar exists")
	_check(tile_panel != null, "TileInfoPanel exists")
	if turn_mgr == null or res_mgr == null or top_bar == null or tile_panel == null:
		_finish()
		return

	# Initial state
	_check(turn_mgr.get_current_turn() == 1, "initial turn is 1")
	var initial_res: Dictionary = res_mgr.get_resources()
	_check(initial_res["gold"] == 100, "initial gold is 100")
	_check(initial_res["wood"] == 50, "initial wood is 50")
	_check(initial_res["food"] == 30, "initial food is 30")
	print("Initial state: Turn 1, resources ", initial_res)

	# End the turn through the TopBar signal
	top_bar.end_turn_requested.emit()

	_check(turn_mgr.get_current_turn() == 2, "turn advanced to 2")
	var updated_res: Dictionary = res_mgr.get_resources()
	_check(updated_res["gold"] == 110, "gold is 110 after base income")
	_check(updated_res["wood"] == 55, "wood is 55 after base income")
	_check(updated_res["food"] == 35, "food is 35 after base income")
	print("Turn 2 state: ", updated_res)

	_check("Turn: 2" in top_bar.turn_label.text, "TopBar shows turn 2")
	_check("110" in top_bar.gold_label.text, "TopBar shows 110 gold")
	_check("55" in top_bar.wood_label.text, "TopBar shows 55 wood")
	_check("35" in top_bar.food_label.text, "TopBar shows 35 food")

	# Tile click integration: (0, 0) is the top-left mountain
	map_instance._handle_tile_click(MAP_OFFSET + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5))
	_check(map_instance.selected_coords == Vector2i(0, 0), "clicking selects (0, 0)")
	_check("(0, 0)" in top_bar.coord_label.text, "TopBar shows the selected tile")
	_check("Mountain" in tile_panel.terrain_label.text, "tile panel shows Mountain terrain")

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL ECONOMY & TURN TESTS PASSED")
		quit(0)
	else:
		printerr("%d ECONOMY & TURN TEST(S) FAILED" % _failures)
		quit(1)
