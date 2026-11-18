extends PanelContainer

## StrategyManager - Top Bar UI
## Displays turn, coordinates, resource counts, status alerts, and action buttons.

signal end_turn_requested
signal save_requested
signal load_requested

const PaintedTheme = preload("res://scripts/ui/painted_theme.gd")

@onready var turn_label: Label = get_node_or_null("MarginContainer/HBoxContainer/TurnLabel")
@onready var coord_label: Label = get_node_or_null("MarginContainer/HBoxContainer/CoordLabel")
@onready var gold_label: Label = get_node_or_null("MarginContainer/HBoxContainer/GoldLabel")
@onready var wood_label: Label = get_node_or_null("MarginContainer/HBoxContainer/WoodLabel")
@onready var food_label: Label = get_node_or_null("MarginContainer/HBoxContainer/FoodLabel")
@onready var status_label: Label = get_node_or_null("MarginContainer/HBoxContainer/StatusLabel")
@onready var save_button: Button = get_node_or_null("MarginContainer/HBoxContainer/SaveButton")
@onready var load_button: Button = get_node_or_null("MarginContainer/HBoxContainer/LoadButton")
@onready var end_turn_button: Button = get_node_or_null("MarginContainer/HBoxContainer/EndTurnButton")

var _status_timer: SceneTreeTimer = null


func _ready() -> void:
	theme = PaintedTheme.get_theme()
	_ensure_references()
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)


func _ensure_references() -> void:
	if turn_label == null:
		turn_label = get_node_or_null("MarginContainer/HBoxContainer/TurnLabel")
		coord_label = get_node_or_null("MarginContainer/HBoxContainer/CoordLabel")
		gold_label = get_node_or_null("MarginContainer/HBoxContainer/GoldLabel")
		wood_label = get_node_or_null("MarginContainer/HBoxContainer/WoodLabel")
		food_label = get_node_or_null("MarginContainer/HBoxContainer/FoodLabel")
		status_label = get_node_or_null("MarginContainer/HBoxContainer/StatusLabel")
		save_button = get_node_or_null("MarginContainer/HBoxContainer/SaveButton")
		load_button = get_node_or_null("MarginContainer/HBoxContainer/LoadButton")
		end_turn_button = get_node_or_null("MarginContainer/HBoxContainer/EndTurnButton")


func _on_end_turn_pressed() -> void:
	end_turn_requested.emit()


func _on_save_pressed() -> void:
	save_requested.emit()


func _on_load_pressed() -> void:
	load_requested.emit()


func update_turn(turn_num: int) -> void:
	_ensure_references()
	if turn_label:
		turn_label.text = "Turn: %d" % turn_num


func update_coordinates(coords: Vector2i, _info: Dictionary = {}) -> void:
	_ensure_references()
	if coord_label:
		if coords.x >= 0 and coords.y >= 0:
			coord_label.text = "Tile: (%d, %d)" % [coords.x, coords.y]
		else:
			coord_label.text = "Tile: None"


func update_resources(res: Dictionary) -> void:
	_ensure_references()
	if gold_label:
		gold_label.text = "Gold: %d/%d" % [res.get("gold", 0), _get_cap("gold")]
	if wood_label:
		wood_label.text = "Wood: %d/%d" % [res.get("wood", 0), _get_cap("wood")]
	if food_label:
		food_label.text = "Food: %d/%d" % [res.get("food", 0), _get_cap("food")]


## Looks up the effective capacity from the ResourceManager living in the same map.
func _get_cap(res_name: String) -> int:
	var map_node = get_parent()
	while map_node != null:
		var rm = map_node.get_node_or_null("ResourceManager") if map_node is Node else null
		if rm != null and rm.has_method("get_capacity"):
			return rm.get_capacity(res_name)
		map_node = map_node.get_parent()
	# Fallback defaults if ResourceManager is unreachable
	var defaults: Dictionary = { "gold": 250, "wood": 150, "food": 100 }
	return defaults.get(res_name, 9999)


## Shows a temporary notification badge on the top bar
func show_status_message(message: String, color: Color = Color.WHITE) -> void:
	_ensure_references()
	if status_label:
		status_label.text = message
		status_label.modulate = color
		# Automatically clear message after 3 seconds
		_status_timer = get_tree().create_timer(3.0)
		_status_timer.timeout.connect(func():
			if status_label and status_label.text == message:
				status_label.text = ""
		)
