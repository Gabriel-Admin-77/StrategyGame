extends Control

## StrategyManager - Main Menu
## Application entry point providing New Game, Continue, Slot Loading, Settings, and Quit.

const PaintedTheme = preload("res://scripts/ui/painted_theme.gd")
const GameSettings = preload("res://scripts/core/game_settings.gd")

@onready var continue_button: Button = get_node_or_null("CenterContainer/VBoxContainer/ContinueButton")
@onready var new_game_button: Button = get_node_or_null("CenterContainer/VBoxContainer/NewGameButton")
@onready var load_button: Button = get_node_or_null("CenterContainer/VBoxContainer/LoadButton")
@onready var settings_button: Button = get_node_or_null("CenterContainer/VBoxContainer/SettingsButton")
@onready var quit_button: Button = get_node_or_null("CenterContainer/VBoxContainer/QuitButton")

@onready var save_load_dialog = get_node_or_null("SaveLoadDialog")
@onready var settings_dialog = get_node_or_null("SettingsDialog")
@onready var dummy_save_manager = get_node_or_null("DummySaveManager")


func _ready() -> void:
	theme = PaintedTheme.get_theme()
	GameSettings.load_settings()
	_update_continue_state()
	_bind_buttons()


func _update_continue_state() -> void:
	if continue_button == null:
		return
	var has_any_save: bool = false
	if dummy_save_manager and dummy_save_manager.has_method("has_autosave"):
		has_any_save = dummy_save_manager.has_autosave()
		if not has_any_save:
			for slot_id: String in ["slot_1", "slot_2", "slot_3"]:
				var meta = dummy_save_manager.get_slot_metadata(slot_id)
				if meta.get("exists", false):
					has_any_save = true
					break
	continue_button.disabled = not has_any_save


func _bind_buttons() -> void:
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(func(): get_tree().quit())

	if save_load_dialog:
		save_load_dialog.slot_action_confirmed.connect(_on_slot_confirmed)


func _on_continue_pressed() -> void:
	# Load main game scene and signal it to restore the latest/autosave slot
	var target_slot: String = "autosave"
	if dummy_save_manager and not dummy_save_manager.has_autosave():
		for s: String in ["slot_1", "slot_2", "slot_3"]:
			if dummy_save_manager.get_slot_metadata(s).get("exists", false):
				target_slot = s
				break
	_launch_game(target_slot)


func _on_new_game_pressed() -> void:
	_launch_game("")


func _on_load_pressed() -> void:
	if save_load_dialog and dummy_save_manager:
		save_load_dialog.open(save_load_dialog.Mode.LOAD, dummy_save_manager)


func _on_settings_pressed() -> void:
	if settings_dialog:
		settings_dialog.open()


func _on_slot_confirmed(mode: String, slot_id: String) -> void:
	if mode == "load":
		_launch_game(slot_id)


func _launch_game(slot_to_load: String = "") -> void:
	# Store the requested startup slot in project metadata
	if not slot_to_load.is_empty():
		Engine.set_meta("load_slot_on_start", slot_to_load)
	else:
		if Engine.has_meta("load_slot_on_start"):
			Engine.remove_meta("load_slot_on_start")
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
