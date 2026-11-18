extends PanelContainer

## StrategyManager - Tile Info Panel
## Displays detailed information about the currently selected map tile.

const BuildingType = preload("res://scripts/buildings/building_type.gd")
const PaintedTheme = preload("res://scripts/ui/painted_theme.gd")

@onready var title_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TitleLabel")
@onready var coords_label: Label = get_node_or_null("MarginContainer/VBoxContainer/CoordsLabel")
@onready var terrain_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TerrainLabel")
@onready var yield_label: Label = get_node_or_null("MarginContainer/VBoxContainer/YieldLabel")
@onready var buildable_label: Label = get_node_or_null("MarginContainer/VBoxContainer/BuildableLabel")
@onready var building_label: Label = get_node_or_null("MarginContainer/VBoxContainer/BuildingLabel")
@onready var hint_label: Label = get_node_or_null("MarginContainer/VBoxContainer/HintLabel")


func _ready() -> void:
	theme = PaintedTheme.get_theme()
	_ensure_references()
	reset_panel()


## Ensures child node references are resolved safely
func _ensure_references() -> void:
	if coords_label == null:
		coords_label = get_node_or_null("MarginContainer/VBoxContainer/CoordsLabel")
		terrain_label = get_node_or_null("MarginContainer/VBoxContainer/TerrainLabel")
		yield_label = get_node_or_null("MarginContainer/VBoxContainer/YieldLabel")
		buildable_label = get_node_or_null("MarginContainer/VBoxContainer/BuildableLabel")
		building_label = get_node_or_null("MarginContainer/VBoxContainer/BuildingLabel")
		hint_label = get_node_or_null("MarginContainer/VBoxContainer/HintLabel")
		title_label = get_node_or_null("MarginContainer/VBoxContainer/TitleLabel")


## Resets the panel to default empty state
func reset_panel() -> void:
	_ensure_references()
	if coords_label:
		coords_label.text = "Coordinates: None"
	if terrain_label:
		terrain_label.text = "Terrain: None"
		terrain_label.modulate = Color.WHITE
	if yield_label:
		yield_label.text = "Resource Yield: None"
	if buildable_label:
		buildable_label.text = "Buildable: None"
		buildable_label.modulate = Color.WHITE
	if building_label:
		building_label.text = "Building: None"
		building_label.modulate = Color.WHITE
	if hint_label:
		hint_label.text = "Click any tile on the map to inspect."
		hint_label.modulate = Color(0.75, 0.75, 0.75)


## Updates the panel with data for the selected tile and building
func display_tile(coords: Vector2i, info: Dictionary, building_param: BuildingType = null) -> void:
	_ensure_references()

	if coords_label:
		coords_label.text = "Coordinates: (X: %d, Y: %d)" % [coords.x, coords.y]

	var terrain_name: String = info.get("name", "Unknown")
	var terrain_color: Color = info.get("color", Color.WHITE)
	if terrain_label:
		terrain_label.text = "Terrain: %s" % terrain_name
		terrain_label.modulate = terrain_color

	var res_yield: String = info.get("yield_desc", "None")
	if yield_label:
		yield_label.text = "Resource Yield: %s" % res_yield

	var building: BuildingType = building_param
	if building == null and info.has("building"):
		building = info["building"]

	if building != null:
		if building_label:
			var construction_note: String = ""
			if info.has("construction_turns_left") and info["construction_turns_left"] > 0:
				construction_note = " [Building: %d turns left]" % info["construction_turns_left"]
			building_label.text = "Building: %s (%s)%s" % [building.display_name, building.get_production_text(), construction_note]
			building_label.modulate = Color(0.95, 0.85, 0.45)
		if buildable_label:
			buildable_label.text = "Buildable: No (occupied)"
			buildable_label.modulate = Color(0.9, 0.7, 0.3)
	else:
		if building_label:
			building_label.text = "Building: None"
			building_label.modulate = Color.WHITE
		var can_build: bool = info.get("can_build", false)
		if buildable_label:
			if can_build:
				buildable_label.text = "Buildable: Yes (Ready for construction)"
				buildable_label.modulate = Color(0.4, 0.9, 0.4)
			else:
				buildable_label.text = "Buildable: No (Unsuitable terrain)"
				buildable_label.modulate = Color(0.9, 0.4, 0.4)

	if hint_label:
		hint_label.text = info.get("description", "")
		hint_label.modulate = Color(0.8, 0.8, 0.8)
