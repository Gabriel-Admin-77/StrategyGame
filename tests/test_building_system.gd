extends SceneTree

## Headless verification of the building system:
## building data, placement rules, resource costs, panel sync and turn income.

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
	var farm = load("res://resources/building_types/farm.tres")
	var lumber_mill = load("res://resources/building_types/lumber_mill.tres")
	var workshop = load("res://resources/building_types/workshop.tres")

	_check(farm != null, "farm.tres loads")
	_check(lumber_mill != null, "lumber_mill.tres loads")
	_check(workshop != null, "workshop.tres loads")
	if farm == null or lumber_mill == null or workshop == null:
		_finish()
		return

	_check(farm.display_name == "Farm", "Farm display name is 'Farm'")
	_check(farm.get_production_text() == "+3 Food/turn", "Farm production text is '+3 Food/turn' (got '%s')" % farm.get_production_text())
	_check(farm.get_cost_text() == "30 Gold, 20 Wood", "Farm cost text is '30 Gold, 20 Wood' (got '%s')" % farm.get_cost_text())
	_check(farm.is_terrain_allowed("Plains") and not farm.is_terrain_allowed("Water"), "Farm allows Plains but not Water")
	_check(workshop.get_allowed_terrain_text() == "Plains or Forest", "Workshop requires 'Plains or Forest' (got '%s')" % workshop.get_allowed_terrain_text())

	var map_scene: PackedScene = load("res://scenes/map/map.tscn")
	var map = map_scene.instantiate()
	root.add_child(map)
	await process_frame

	var layer = map.get_node_or_null("BuildingLayer")
	var panel = map.tile_info_panel
	var resources = map.get_node_or_null("ResourceManager")
	var turns = map.get_node_or_null("TurnManager")
	var top_bar = map.top_bar

	_check(layer != null, "map.tscn contains a BuildingLayer child")
	_check(panel != null and resources != null and turns != null and top_bar != null, "existing subsystems are still present")
	if layer == null or panel == null or resources == null or turns == null or top_bar == null:
		_finish()
		return

	var building_label: Label = panel.get_node("MarginContainer/VBoxContainer/BuildingLabel")
	var buildable_label: Label = panel.get_node("MarginContainer/VBoxContainer/BuildableLabel")

	# terrain_grid row 2: PLAINS, FOREST, PLAINS, PLAINS, WATER, WATER, PLAINS, ...
	var plains_coords := Vector2i(0, 2)
	var forest_coords := Vector2i(1, 2)
	var water_coords := Vector2i(4, 2)

	_check(map.get_terrain_name(plains_coords) == "Plains", "tile (0,2) reports Plains")
	_check(map.get_terrain_name(forest_coords) == "Forest", "tile (1,2) reports Forest")
	_check(map.get_terrain_name(water_coords) == "Water", "tile (4,2) reports Water")

	# --- placement rules -----------------------------------------------------
	_check(map.can_place_building(plains_coords, farm), "Farm is allowed on plains")
	_check(not map.can_place_building(forest_coords, farm), "Farm is rejected on forest")
	_check(not map.can_place_building(water_coords, farm), "buildings are rejected on water")
	_check("requires Plains" in map.get_placement_error(forest_coords, farm), "rejection reason explains the terrain requirement")

	# --- click-to-select + build --------------------------------------------
	map._handle_tile_click(_tile_center(plains_coords))
	_check(map.selected_coords == plains_coords, "clicking (0,2) selects that tile")
	_check("Building: None" in building_label.text, "panel starts with no building")

	var gold_before: int = resources.get_resources()["gold"]
	var wood_before: int = resources.get_resources()["wood"]

	_check(map.place_building(plains_coords, farm), "Farm placement succeeds on plains")
	_check(layer.is_occupied(plains_coords), "tile (0,2) is occupied")
	_check(map.get_building_at(plains_coords).display_name == "Farm", "Farm is stored on tile (0,2)")
	_check("Farm" in building_label.text, "info panel shows the Farm")
	_check("Food" in building_label.text, "info panel shows the farm production")
	_check("occupied" in buildable_label.text, "info panel marks the tile as occupied")

	var gold_after: int = resources.get_resources()["gold"]
	var wood_after: int = resources.get_resources()["wood"]
	_check(gold_after == gold_before - 30, "placing the farm costs 30 gold (%d -> %d)" % [gold_before, gold_after])
	_check(wood_after == wood_before - 20, "placing the farm costs 20 wood (%d -> %d)" % [wood_before, wood_after])

	_check(not map.place_building(plains_coords, farm), "a second building on the same tile is rejected")
	_check(not map.place_building(water_coords, farm), "building on water is rejected")

	# --- build mode through the click handler -------------------------------
	map.set_pending_building(lumber_mill)
	_check(map.pending_building == lumber_mill, "build mode accepts a pending building")
	map._handle_tile_click(_tile_center(forest_coords))
	_check(layer.is_occupied(forest_coords), "clicking a forest tile in build mode places the lumber mill")
	_check(map.selected_coords == forest_coords, "the clicked tile becomes the selection")
	_check("Lumber Mill" in building_label.text, "panel switches to the lumber mill")

	# Building on the wrong terrain keeps build mode armed and reports failure
	map._handle_tile_click(_tile_center(water_coords))
	_check(not layer.is_occupied(water_coords), "build mode refuses water tiles")
	_check(map.pending_building == lumber_mill, "build mode stays armed after a failed placement")

	# --- demolish mode ------------------------------------------------------
	map.set_demolish_mode(true)
	_check(map.pending_building == null and map.demolish_mode, "demolish mode clears the pending building")
	map._handle_tile_click(_tile_center(forest_coords))
	_check(not layer.is_occupied(forest_coords), "demolish mode removes the building on click")
	_check("Building: None" in building_label.text, "panel clears the building after demolition")
	map.clear_build_modes()
	_check(map.pending_building == null and not map.demolish_mode, "clear_build_modes resets both modes")

	# --- production on turn advance ----------------------------------------
	_check(int(map.get_building_income().get("food", 0)) == 3, "map reports 3 food income from the farm")
	var food_before: int = resources.get_resources()["food"]
	turns.advance_turn()
	var food_after: int = resources.get_resources()["food"]
	# base income (+5 food per turn) plus the farm's +3 food
	_check(food_after == food_before + 8, "turn advance adds base income and building production (%d -> %d)" % [food_before, food_after])
	_check(turns.get_current_turn() == 2, "turn counter advanced to 2")
	_check("Turn: 2" in top_bar.turn_label.text, "TopBar reflects the new turn")

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL BUILDING SYSTEM TESTS PASSED")
		quit(0)
	else:
		printerr("%d BUILDING SYSTEM TEST(S) FAILED" % _failures)
		quit(1)
