extends PanelContainer

## StrategyManager - Pause / In-Game Menu
## Pops up when pressing Escape or clicking Menu to pause and manage session.

const PaintedTheme = preload("res://scripts/ui/painted_theme.gd")

signal resumed
signal save_requested
signal load_requested
signal settings_requested
signal main_menu_requested
signal quit_requested

@onready var resume_button: Button = get_node_or_null("MarginContainer/VBoxContainer/ResumeButton")
@onready var save_button: Button = get_node_or_null("MarginContainer/VBoxContainer/SaveButton")
@onready var load_button: Button = get_node_or_null("MarginContainer/VBoxContainer/LoadButton")
@onready var settings_button: Button = get_node_or_null("MarginContainer/VBoxContainer/SettingsButton")
@onready var menu_button: Button = get_node_or_null("MarginContainer/VBoxContainer/MenuButton")
@onready var quit_button: Button = get_node_or_null("MarginContainer/VBoxContainer/QuitButton")


func _ready() -> void:
	theme = PaintedTheme.get_theme()
	_bind_buttons()


func _bind_buttons() -> void:
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if save_button:
		save_button.pressed.connect(func(): save_requested.emit())
	if load_button:
		load_button.pressed.connect(func(): load_requested.emit())
	if settings_button:
		settings_button.pressed.connect(func(): settings_requested.emit())
	if menu_button:
		menu_button.pressed.connect(func(): main_menu_requested.emit())
	if quit_button:
		quit_button.pressed.connect(func(): quit_requested.emit())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if visible:
			_on_resume_pressed()
		else:
			open()


func open() -> void:
	visible = true


func _on_resume_pressed() -> void:
	visible = false
	resumed.emit()
