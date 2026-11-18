extends SceneTree

## Headless integration test for Phase 3 Application Shell:
## - Multi-slot save/load operations & metadata queries
## - Automatic background autosave on turn advance
## - Settings persistence (user://settings.cfg)
## - Main Menu structure, button bindings, and continue state
## - In-game Pause menu & Save/Load modal dialogs

const GameSettings = preload("res://scripts/core/game_settings.gd")

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
	# -------------------------------------------------------------------------
	# 1. Map Scene Subsystems & Modals Verification
	# -------------------------------------------------------------------------
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
	var top_bar = map.top_bar
	var save_load_dialog = map.save_load_dialog
	var settings_dialog = map.settings_dialog
	var pause_menu = map.pause_menu

	_check(save_mgr != null, "SaveManager exists in Map")
	_check(save_load_dialog != null, "SaveLoadDialog exists in Map HUD")
	_check(settings_dialog != null, "SettingsDialog exists in Map HUD")
	_check(pause_menu != null, "PauseMenu exists in Map HUD")
	_check(top_bar.menu_button != null, "TopBar contains MenuButton")

	if save_mgr == null or save_load_dialog == null or pause_menu == null:
		_finish()
		return

	# -------------------------------------------------------------------------
	# 2. Multi-Slot Save and Metadata
	# -------------------------------------------------------------------------
	# Advance to Turn 3 and place a Farm
	turns.advance_turn()
	turns.advance_turn()
	_check(turns.get_current_turn() == 3, "Advanced to Turn 3")

	var farm = load("res://resources/building_types/farm.tres")
	var plains_coords := Vector2i(0, 2)
	_check(map.place_building(plains_coords, farm), "Placed Farm on (0, 2)")

	var gold_before_save: int = resources.get_resources()["gold"]

	# Save into slot_1
	var save_slot_ok: bool = save_mgr.save_to_slot("slot_1")
	_check(save_slot_ok, "save_to_slot('slot_1') succeeded")

	# Check slot metadata
	var meta: Dictionary = save_mgr.get_slot_metadata("slot_1")
	_check(meta.get("exists", false) == true, "slot_1 metadata reports exists == true")
	_check(meta.get("turn", 0) == 3, "slot_1 metadata reports turn == 3")
	_check(meta.get("buildings_count", 0) == 1, "slot_1 metadata reports 1 building")
	_check(meta.get("timestamp", "") != "", "slot_1 metadata has valid timestamp")

	var empty_meta: Dictionary = save_mgr.get_slot_metadata("slot_nonexistent")
	_check(empty_meta.get("exists", true) == false, "nonexistent slot metadata reports exists == false")

	var all_summaries: Array[Dictionary] = save_mgr.get_all_slots_summary()
	_check(all_summaries.size() == 4, "get_all_slots_summary() returns 4 slots (got %d)" % all_summaries.size())

	# -------------------------------------------------------------------------
	# 3. State Mutation & Load from Slot
	# -------------------------------------------------------------------------
	turns.set_current_turn(12)
	resources.set_resources({ "gold": 9999, "wood": 8888, "food": 7777 })
	layer.clear_all()
	_check(layer.get_building_count() == 0, "Mutated state: cleared buildings")
	_check(turns.get_current_turn() == 12, "Mutated state: turn is 12")

	var load_slot_ok: bool = save_mgr.load_from_slot("slot_1")
	_check(load_slot_ok, "load_from_slot('slot_1') succeeded")
	_check(turns.get_current_turn() == 3, "Restored turn count is 3")
	_check(resources.get_resources()["gold"] == gold_before_save, "Restored gold matches %d" % gold_before_save)
	_check(layer.is_occupied(plains_coords), "Restored tile (0, 2) is occupied")
	_check(layer.get_building_at(plains_coords).id == "farm", "Restored building at (0, 2) is Farm")

	# -------------------------------------------------------------------------
	# 4. Autosave on Turn Advance
	# -------------------------------------------------------------------------
	# Advance turn -> map._on_turn_advanced automatically calls autosave()
	turns.advance_turn()
	_check(turns.get_current_turn() == 4, "Turn advanced to 4")
	_check(save_mgr.has_autosave(), "save_mgr.has_autosave() is true after turn advance")

	var auto_meta: Dictionary = save_mgr.get_slot_metadata("autosave")
	_check(auto_meta.get("exists", false) == true, "autosave metadata exists")
	_check(auto_meta.get("turn", 0) == 4, "autosave metadata reflects Turn 4")

	# -------------------------------------------------------------------------
	# 5. GameSettings Persistence
	# -------------------------------------------------------------------------
	GameSettings.master_volume = 42.0
	GameSettings.music_volume = 55.0
	GameSettings.fullscreen = true
	var settings_saved: bool = GameSettings.save_settings()
	_check(settings_saved, "GameSettings.save_settings() returned true")

	# Mutate in memory
	GameSettings.master_volume = 100.0
	GameSettings.fullscreen = false

	# Reload from disk
	GameSettings.load_settings()
	_check(is_equal_approx(GameSettings.master_volume, 42.0), "GameSettings restored master_volume 42.0 (got %f)" % GameSettings.master_volume)
	_check(is_equal_approx(GameSettings.music_volume, 55.0), "GameSettings restored music_volume 55.0 (got %f)" % GameSettings.music_volume)
	_check(GameSettings.fullscreen == true, "GameSettings restored fullscreen == true")

	# -------------------------------------------------------------------------
	# 6. Modal Dialogs In-Game (SaveLoadDialog & PauseMenu)
	# -------------------------------------------------------------------------
	_check(save_load_dialog.visible == false, "SaveLoadDialog starts hidden")
	save_load_dialog.open(save_load_dialog.Mode.SAVE, save_mgr)
	_check(save_load_dialog.visible == true, "SaveLoadDialog opened in SAVE mode")
	_check(save_load_dialog.slots_container.get_child_count() == 4, "SaveLoadDialog built 4 slot cards")
	save_load_dialog.visible = false

	_check(pause_menu.visible == false, "PauseMenu starts hidden")
	pause_menu.open()
	_check(pause_menu.visible == true, "PauseMenu open() makes it visible")
	pause_menu._on_resume_pressed()
	_check(pause_menu.visible == false, "PauseMenu resume hides the modal")

	# -------------------------------------------------------------------------
	# 7. Main Menu Scene & Continue State
	# -------------------------------------------------------------------------
	var main_menu_scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	_check(main_menu_scene != null, "main_menu.tscn loads")

	var menu = main_menu_scene.instantiate()
	root.add_child(menu)
	await process_frame

	_check(menu.continue_button != null, "MainMenu has ContinueButton")
	_check(menu.new_game_button != null, "MainMenu has NewGameButton")
	_check(menu.load_button != null, "MainMenu has LoadButton")
	_check(menu.settings_button != null, "MainMenu has SettingsButton")
	_check(menu.quit_button != null, "MainMenu has QuitButton")
	_check(menu.dummy_save_manager != null, "MainMenu has DummySaveManager")

	# Since autosave and slot_1 exist, continue_button must be enabled!
	_check(menu.continue_button.disabled == false, "ContinueButton is enabled when save files exist")

	# Clean up instances
	map.queue_free()
	menu.queue_free()
	await process_frame

	# -------------------------------------------------------------------------
	# 8. Clean up test files
	# -------------------------------------------------------------------------
	for s: String in ["autosave", "slot_1", "slot_2", "slot_3"]:
		var p: String = save_mgr.get_slot_path(s)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

	if FileAccess.file_exists(GameSettings.SETTINGS_FILE):
		DirAccess.remove_absolute(GameSettings.SETTINGS_FILE)

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL APPLICATION SHELL TESTS PASSED 100%")
		quit(0)
	else:
		printerr("%d APPLICATION SHELL TEST(S) FAILED" % _failures)
		quit(1)
