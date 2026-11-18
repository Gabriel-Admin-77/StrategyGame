extends SceneTree

## Headless verification of Phase 2 Economy Depth:
## - Worked terrain yields
## - Construction pipeline (build_turns, turns_left, advance_construction)
## - Upkeep deduction and treasury deficit signals
## - Demolition refund (50%)
## - Storage caps
## - New building placement (Mine on Mountain, Dock on Water)
## - Save/Load preservation of construction state

const MAP_OFFSET: Vector2 = Vector2(40.0, 56.0)
const TILE_SIZE: float = 64.0

var _failures: int = 0


func _init() -> void:
	_run_tests()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		printerr("FAIL: ", message)


func _run_tests() -> void:
	var map_scene: PackedScene = load("res://scenes/map/map.tscn")
	_check(map_scene != null, "map.tscn loads")
	if map_scene == null:
		_finish()
		return

	var map = map_scene.instantiate()
	root.add_child(map)
	await process_frame

	var layer = map.get_node_or_null("BuildingLayer")
	var resources = map.get_node_or_null("ResourceManager")
	var turns = map.get_node_or_null("TurnManager")
	var save_mgr = map.get_node_or_null("SaveManager")

	_check(layer != null and resources != null and turns != null and save_mgr != null, "all core subsystems present")
	if layer == null or resources == null or turns == null or save_mgr == null:
		_finish()
		return

	# Load building types
	var farm = load("res://resources/building_types/farm.tres")
	var market = load("res://resources/building_types/market.tres")
	var mine = load("res://resources/building_types/mine.tres")
	var dock = load("res://resources/building_types/dock.tres")

	_check(farm != null and market != null and mine != null and dock != null, "all 4 test building types load")
	if farm == null or market == null or mine == null or dock == null:
		_finish()
		return

	# -------------------------------------------------------------------------
	# 1. Specialized Terrain Placement (Mine on Mountain, Dock on Water)
	# -------------------------------------------------------------------------
	var mountain_coords := Vector2i(0, 0)
	var water_coords := Vector2i(4, 2)
	var plains_coords := Vector2i(0, 2)

	_check(map.can_place_building(mountain_coords, mine), "Mine can be placed on Mountain")
	_check(map.can_place_building(water_coords, dock), "Dock can be placed on Water")
	_check(not map.can_place_building(mountain_coords, farm), "Farm is rejected on Mountain")
	_check(not map.can_place_building(water_coords, farm), "Farm is rejected on Water")

	# -------------------------------------------------------------------------
	# 2. Construction Pipeline (build_turns > 1)
	# -------------------------------------------------------------------------
	# Give plentiful resources for testing
	resources.set_resources({ "gold": 200, "wood": 100, "food": 50 })

	# Market has build_turns = 2
	_check(market.build_turns == 2, "Market has build_turns = 2")
	_check(map.place_building(plains_coords, market), "Market placement succeeds on plains")
	_check(layer.is_occupied(plains_coords), "Tile is occupied by Market")
	_check(layer.is_under_construction(plains_coords), "Market starts under construction")
	_check(layer.get_construction_turns_left(plains_coords) == 1, "Market has 1 construction turn remaining")
	_check(not layer.is_completed(plains_coords), "Market is not yet completed")

	# While under construction, market must NOT produce income or demand upkeep
	var building_income = map.get_building_income()
	_check(building_income.get("gold", 0) == 0, "under-construction Market does not produce income")
	var building_upkeep = map.get_building_upkeep()
	_check(building_upkeep.get("food", 0) == 0, "under-construction Market does not demand upkeep")
	var worked_yields = map.get_worked_terrain_yields()
	_check(worked_yields.get("food", 0) == 0, "under-construction tile does not yield worked terrain resources")

	# -------------------------------------------------------------------------
	# 3. Advance Turn: Construction Completion
	# -------------------------------------------------------------------------
	var gold_before: int = resources.get_resources()["gold"]
	turns.advance_turn() # Turn 1 -> 2
	_check(not layer.is_under_construction(plains_coords), "Market is completed after turn advance")
	_check(layer.is_completed(plains_coords), "Market is marked completed")
	_check(layer.get_construction_turns_left(plains_coords) == 0, "Market has 0 construction turns left")

	# -------------------------------------------------------------------------
	# 4. Completed Building: Production + Worked Terrain + Upkeep
	# -------------------------------------------------------------------------
	# Market: +6 Gold production, -1 Food upkeep
	# Plains: +2 Food worked yield
	# Base income: +10 Gold, +5 Wood, +5 Food
	var active_income = map.get_building_income()
	_check(active_income.get("gold", 0) == 6, "completed Market produces 6 gold")
	var active_upkeep = map.get_building_upkeep()
	_check(active_upkeep.get("food", 0) == 1, "completed Market charges 1 food upkeep")
	var active_yields = map.get_worked_terrain_yields()
	_check(active_yields.get("food", 0) == 2, "worked plains yields 2 food")

	# -------------------------------------------------------------------------
	# 5. Demolition Refund (50%)
	# -------------------------------------------------------------------------
	# Market cost: 60 Gold, 35 Wood
	# Expected refund: 30 Gold, 17 Wood
	var res_before_demolish = resources.get_resources()
	_check(map.demolish_building(plains_coords), "demolishing Market succeeds")
	var res_after_demolish = resources.get_resources()
	_check(res_after_demolish["gold"] == res_before_demolish["gold"] + 30, "demolition refunded 30 gold (50% of 60)")
	_check(res_after_demolish["wood"] == res_before_demolish["wood"] + 17, "demolition refunded 17 wood (50% of 35)")
	_check(not layer.is_occupied(plains_coords), "tile is vacant after demolition")

	# -------------------------------------------------------------------------
	# 6. Storage Caps
	# -------------------------------------------------------------------------
	_check(resources.get_capacity("gold") == 250, "default gold capacity is 250")
	_check(resources.get_capacity("wood") == 150, "default wood capacity is 150")
	_check(resources.get_capacity("food") == 100, "default food capacity is 100")

	resources.add_resources({ "gold": 1000, "wood": 1000, "food": 1000 })
	var capped_res = resources.get_resources()
	_check(capped_res["gold"] == 250, "gold is clamped to capacity 250 (got %d)" % capped_res["gold"])
	_check(capped_res["wood"] == 150, "wood is clamped to capacity 150 (got %d)" % capped_res["wood"])
	_check(capped_res["food"] == 100, "food is clamped to capacity 100 (got %d)" % capped_res["food"])

	# -------------------------------------------------------------------------
	# 7. Upkeep Deficit Handling
	# -------------------------------------------------------------------------
	resources.set_resources({ "gold": 0, "wood": 0, "food": 0 })
	var deficit_info := { "received": false, "amount": 0 }
	resources.treasury_deficit.connect(func(res_name: String, amount: int):
		if res_name == "gold":
			deficit_info["received"] = true
			deficit_info["amount"] = amount
	)
	resources.deduct_upkeep({ "gold": 5 })
	_check(deficit_info["received"], "treasury_deficit signal emitted when upkeep exceeds stockpile")
	_check(deficit_info["amount"] == 5, "treasury deficit reports exact shortage (got %d)" % deficit_info["amount"])
	_check(resources.get_resources()["gold"] == 0, "stockpile is clamped at 0 during deficit")

	# -------------------------------------------------------------------------
	# 8. Save & Load with Construction State
	# -------------------------------------------------------------------------
	resources.set_resources({ "gold": 150, "wood": 100, "food": 50 })
	# Place Mine on Mountain (Mountain is at (0,0))
	map.place_building(mountain_coords, mine)
	_check(layer.is_under_construction(mountain_coords), "Mine is placed under construction")
	_check(layer.get_construction_turns_left(mountain_coords) == 1, "Mine has 1 turn left")

	var test_save_path := "user://test_economy_depth_save.json"
	_check(save_mgr.save_game(test_save_path), "save_game succeeds with building under construction")

	# Modify state
	layer.clear_all()
	_check(layer.get_building_count() == 0, "cleared all buildings before load")

	_check(save_mgr.load_game(test_save_path), "load_game succeeds")
	_check(layer.is_occupied(mountain_coords), "Mine is restored at (0,0)")
	_check(layer.is_under_construction(mountain_coords), "Mine restored in under-construction state")
	_check(layer.get_construction_turns_left(mountain_coords) == 1, "Mine restored with 1 turn left")

	# Clean up save file
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL ECONOMY DEPTH TESTS PASSED 100%")
		quit(0)
	else:
		printerr("%d ECONOMY DEPTH TEST(S) FAILED" % _failures)
		quit(1)
