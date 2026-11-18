extends SceneTree

## Headless verification that clicking a tile updates the tile info panel.

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

	await process_frame

	var panel = map_instance.tile_info_panel
	_check(panel != null, "TileInfoPanel is available")
	if panel == null:
		_finish()
		return

	# Tile (1, 1) centre: offset (40, 56) + 1 * 64 + 32
	map_instance._handle_tile_click(Vector2(136, 152))
	_check(map_instance.selected_coords == Vector2i(1, 1), "clicking the tile selects (1, 1)")

	var coords_node: Label = panel.get_node("MarginContainer/VBoxContainer/CoordsLabel")
	var terrain_node: Label = panel.get_node("MarginContainer/VBoxContainer/TerrainLabel")
	var building_node: Label = panel.get_node("MarginContainer/VBoxContainer/BuildingLabel")

	print("Coords text: ", coords_node.text)
	print("Terrain text: ", terrain_node.text)

	_check("X: 1, Y: 1" in coords_node.text, "panel shows the selected coordinates")
	_check("Forest" in terrain_node.text, "panel shows Forest terrain at (1, 1)")
	_check("Building: None" in building_node.text, "panel starts with no building on the tile")

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL PANEL INTEGRATION TESTS PASSED")
		quit(0)
	else:
		printerr("%d PANEL INTEGRATION TEST(S) FAILED" % _failures)
		quit(1)
