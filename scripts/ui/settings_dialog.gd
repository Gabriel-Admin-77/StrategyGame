extends PanelContainer

## StrategyManager - Settings Dialog
## Controls audio volume and display options with instant save.

const PaintedTheme = preload("res://scripts/ui/painted_theme.gd")
const GameSettings = preload("res://scripts/core/game_settings.gd")

signal closed

@onready var master_slider: HSlider = get_node_or_null("MarginContainer/VBoxContainer/AudioGrid/MasterSlider")
@onready var music_slider: HSlider = get_node_or_null("MarginContainer/VBoxContainer/AudioGrid/MusicSlider")
@onready var sfx_slider: HSlider = get_node_or_null("MarginContainer/VBoxContainer/AudioGrid/SfxSlider")
@onready var fullscreen_check: CheckBox = get_node_or_null("MarginContainer/VBoxContainer/DisplayGrid/FullscreenCheck")
@onready var close_button: Button = get_node_or_null("MarginContainer/VBoxContainer/CloseButton")


func _ready() -> void:
	theme = PaintedTheme.get_theme()
	_bind_controls()


func open() -> void:
	GameSettings.load_settings()
	_sync_ui_from_settings()
	visible = true


func _bind_controls() -> void:
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	if master_slider:
		master_slider.value_changed.connect(func(v: float):
			GameSettings.master_volume = v
			GameSettings.save_settings()
		)
	if music_slider:
		music_slider.value_changed.connect(func(v: float):
			GameSettings.music_volume = v
			GameSettings.save_settings()
		)
	if sfx_slider:
		sfx_slider.value_changed.connect(func(v: float):
			GameSettings.sfx_volume = v
			GameSettings.save_settings()
		)
	if fullscreen_check:
		fullscreen_check.toggled.connect(func(enabled: bool):
			GameSettings.fullscreen = enabled
			GameSettings.apply_display_settings()
			GameSettings.save_settings()
		)


func _sync_ui_from_settings() -> void:
	if master_slider:
		master_slider.value = GameSettings.master_volume
	if music_slider:
		music_slider.value = GameSettings.music_volume
	if sfx_slider:
		sfx_slider.value = GameSettings.sfx_volume
	if fullscreen_check:
		fullscreen_check.button_pressed = GameSettings.fullscreen


func _on_close_pressed() -> void:
	GameSettings.save_settings()
	visible = false
	closed.emit()
