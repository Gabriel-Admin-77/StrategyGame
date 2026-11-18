extends SceneTree

## Headless verification of the build UI wiring:
## main.tscn -> BuildingPalette buttons -> map build/demolish modes.

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


func _tile_center(coords: Vector2i) -> Vector2:
	return MAP_OFFSET + Vector2(coords.x * TILE_SIZE + TILE_SIZE * 0.5, coords.y * TILE_SIZE + TILE_SIZE * 0.5)


func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/main/main.tscn")
	_check(main_scene != null, "main.tscn loads")
	if main_scene == null:
		_finish()
		return

	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var map = main.get_node_or_null("Map")
	var palette = main.get_node_or_null("UILayer/BuildingPalette")
	_check(map != null, "main.tscn contains the Map")
	_check(palette != null, "main.tscn contains the BuildingPalette")
	if map == null or palette == null:
		_finish()
		return

	var layer = map.get_node_or_null("BuildingLayer")
	var container: HBoxContainer = palette.get_node_or_null("MarginContainer/HBoxContainer/ButtonContainer")
	_check(layer != null, "Map has a BuildingLayer")
	_check(container != null, "palette has a button container")
	if layer == null or container == null:
		_finish()
		return

	# Building buttons (sorted by name) + Demolish button at the end
	var buttons: Array = container.get_children()
	var labels: PackedStringArray = PackedStringArray()
	var farm_button: Button = null
	var demolish_button: Button = null
	for button: Node in buttons:
		if button is Button:
			labels.append(button.text)
			if button.text == "Farm":
				farm_button = button
			elif button.text == "Demolish":
				demolish_button = button
	print("Palette buttons: ", labels)
	_check(buttons.size() >= 4, "palette builds buttons (got %d)" % buttons.size())
	_check(labels.has("Farm"), "palette contains Farm button")
	_check(labels[labels.size() - 1] == "Demolish", "last button is Demolish")
	_check(farm_button != null, "Farm button found")
	_check(demolish_button != null, "Demolish button found")

	# Pressing a building button must arm build mode through the scene connection
	farm_button.button_pressed = true
	_check(map.pending_building != null, "pressing Farm arms build mode")
	_check(map.pending_building != null and map.pending_building.display_name == "Farm", "pending building is the Farm")

	# Clicking a plains tile builds it
	var plains_coords := Vector2i(0, 2)
	map._handle_tile_click(_tile_center(plains_coords))
	_check(layer.is_occupied(plains_coords), "clicking plains with Farm armed places the farm")
	_check("Farm placed" in palette.hint_label.text, "palette confirms the placement (got '%s')" % palette.hint_label.text)

	# Demolish button switches modes and unpresses the building button
	demolish_button.button_pressed = true
	_check(map.demolish_mode, "pressing Demolish arms demolish mode")
	_check(map.pending_building == null, "demolish mode clears the pending building")
	_check(not farm_button.button_pressed, "the Farm button is released when Demolish is pressed")

	map._handle_tile_click(_tile_center(plains_coords))
	_check(not layer.is_occupied(plains_coords), "clicking the tile in demolish mode removes the farm")

	# Releasing Demolish clears the modes through the scene connection
	demolish_button.button_pressed = false
	_check(not map.demolish_mode, "releasing Demolish leaves demolish mode")

	# Invalid placement is reported in the palette hint
	farm_button.button_pressed = true
	var water_coords := Vector2i(4, 2)
	map._handle_tile_click(_tile_center(water_coords))
	_check(not layer.is_occupied(water_coords), "clicking water places nothing")
	_check("Water" in palette.hint_label.text, "palette reports the water rejection (got '%s')" % palette.hint_label.text)

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL BUILD UI TESTS PASSED")
		quit(0)
	else:
		printerr("%d BUILD UI TEST(S) FAILED" % _failures)
		quit(1)
