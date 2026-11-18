extends PanelContainer

## StrategyManager - Building Palette
## Bottom bar listing every available building. Picking an entry arms the map's
## build mode, "Demolish" arms the removal mode, and placement results are
## echoed back into the hint label.

const BuildingType = preload("res://scripts/buildings/building_type.gd")
const PaintedTheme = preload("res://scripts/ui/painted_theme.gd")

signal building_mode_selected(building: BuildingType)
signal demolish_mode_selected()
signal build_mode_cleared()

const BUILDING_DIRECTORY: String = "res://resources/building_types"
const HINT_DEFAULT: String = "Select a building, then click a tile on the map."
const COLOR_HINT_DEFAULT: Color = Color(0.78, 0.82, 0.88)
const COLOR_HINT_SUCCESS: Color = Color(0.55, 0.92, 0.55)
const COLOR_HINT_ERROR: Color = Color(0.95, 0.45, 0.42)

@onready var button_container: HBoxContainer = get_node_or_null("MarginContainer/HBoxContainer/ButtonContainer")
@onready var hint_label: Label = get_node_or_null("MarginContainer/HBoxContainer/HintLabel")

var _button_group: ButtonGroup = ButtonGroup.new()
var _demolish_button: Button = null
var _is_auto_clearing: bool = false


func _ready() -> void:
	theme = PaintedTheme.get_theme()
	_button_group.allow_unpress = true
	_build_palette()
	_reset_hint()


## Creates one toggle button per building type found in the resources folder.
func _build_palette() -> void:
	if button_container == null:
		return

	for building: BuildingType in _load_building_types():
		var button: Button = Button.new()
		button.text = building.display_name
		button.toggle_mode = true
		button.button_group = _button_group
		button.tooltip_text = "%s\nCost: %s\n%s" % [
			building.description,
			building.get_cost_text(),
			building.get_production_text()
		]
		if building.ui_icon != null:
			button.icon = building.ui_icon
			button.add_theme_constant_override("icon_max_width", 24)
		button.toggled.connect(_on_building_toggled.bind(building))
		button_container.add_child(button)

	_demolish_button = Button.new()
	_demolish_button.text = "Demolish"
	_demolish_button.toggle_mode = true
	_demolish_button.tooltip_text = "Remove the building on the selected tile."
	_demolish_button.toggled.connect(_on_demolish_toggled)
	button_container.add_child(_demolish_button)


## Loads every BuildingType stored in res://resources/building_types/.
func _load_building_types() -> Array:
	var buildings: Array = []
	var directory: DirAccess = DirAccess.open(BUILDING_DIRECTORY)
	if directory == null:
		push_warning("BuildingPalette: unable to open %s" % BUILDING_DIRECTORY)
		return buildings

	for file_name: String in directory.get_files():
		var resource_path: String = BUILDING_DIRECTORY.path_join(file_name)
		# Exported projects store resources with a .remap suffix
		if resource_path.ends_with(".remap"):
			resource_path = resource_path.trim_suffix(".remap")
		if not resource_path.ends_with(".tres"):
			continue
		var resource: Resource = load(resource_path)
		if resource is BuildingType:
			buildings.append(resource)

	buildings.sort_custom(_sort_by_name)
	return buildings


func _sort_by_name(a: BuildingType, b: BuildingType) -> bool:
	return a.display_name < b.display_name


func _on_building_toggled(toggled_on: bool, building: BuildingType) -> void:
	if toggled_on:
		_unpress_demolish_button()
		_show_hint("Placing %s (%s)" % [building.display_name, building.get_cost_text()], COLOR_HINT_SUCCESS)
		building_mode_selected.emit(building)
	elif _button_group.get_pressed_button() == null:
		if not _is_auto_clearing:
			_reset_hint()
		build_mode_cleared.emit()


func _on_demolish_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var pressed_button: Button = _button_group.get_pressed_button()
		if pressed_button != null:
			pressed_button.set_pressed(false)
		_show_hint("Demolition mode: click a tile to remove its building.", COLOR_HINT_ERROR)
		demolish_mode_selected.emit()
	else:
		_reset_hint()
		build_mode_cleared.emit()


func _unpress_demolish_button() -> void:
	if _demolish_button != null and _demolish_button.button_pressed:
		_demolish_button.set_pressed(false)


## Called by the map when a building could not be placed.
func show_status(_coords: Vector2i, reason: String) -> void:
	_show_hint(reason, COLOR_HINT_ERROR)


## Called by the map after a successful placement. Automatically disarms build mode.
func show_confirmation(coords: Vector2i, building: BuildingType) -> void:
	_is_auto_clearing = true
	clear_selection()
	_is_auto_clearing = false
	_show_hint("%s placed at (%d, %d)" % [building.display_name, coords.x, coords.y], COLOR_HINT_SUCCESS)


## Clears any pressed building or demolish button and clears build mode.
func clear_selection() -> void:
	var pressed: Button = _button_group.get_pressed_button()
	if pressed != null:
		pressed.set_pressed(false)
	_unpress_demolish_button()
	build_mode_cleared.emit()


func _reset_hint() -> void:
	_show_hint(HINT_DEFAULT, COLOR_HINT_DEFAULT)


func _show_hint(text: String, color: Color) -> void:
	if hint_label == null:
		return
	hint_label.text = text
	hint_label.modulate = color
