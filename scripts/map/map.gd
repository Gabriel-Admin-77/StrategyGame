extends Node2D

## StrategyManager - Map System
## Handles 2D grid rendering, terrain data, tile selection, and coordinates game subsystems.

# Script classes used by the building system
const BuildingType = preload("res://scripts/buildings/building_type.gd")

# Signal emitted whenever a tile is selected
signal tile_selected(coords: Vector2i, terrain_info: Dictionary)
# Building system signals
signal building_placed(coords: Vector2i, building: BuildingType)
signal building_removed(coords: Vector2i, building: BuildingType)
signal placement_failed(coords: Vector2i, reason: String)

# Terrain type enumeration
enum TerrainType {
	PLAINS,
	FOREST,
	WATER,
	MOUNTAIN
}

# Grid configuration constants
const GRID_WIDTH: int = 25
const GRID_HEIGHT: int = 25
const TILE_SIZE: Vector2 = Vector2(64.0, 64.0)
const MAP_OFFSET: Vector2 = Vector2(40.0, 56.0)

# Visual colors
const COLOR_PLAINS: Color = Color(0.35, 0.72, 0.35)    # Green
const COLOR_FOREST: Color = Color(0.12, 0.45, 0.18)    # Dark Green
const COLOR_WATER: Color = Color(0.22, 0.52, 0.88)     # Blue
const COLOR_MOUNTAIN: Color = Color(0.55, 0.38, 0.22)  # Brown

const COLOR_GRID: Color = Color(0.15, 0.15, 0.15, 0.7) # Grid border lines
const COLOR_SELECTION: Color = Color(1.0, 0.88, 0.1)   # Yellow selection highlight
const SELECTION_LINE_WIDTH: float = 3.0

# Comprehensive terrain data dictionary
const TERRAIN_DATA: Dictionary = {
	TerrainType.PLAINS: {
		"name": "Plains",
		"color": COLOR_PLAINS,
		"yields": { "food": 2 },
		"yield_desc": "+2 Food per turn",
		"can_build": true,
		"description": "Fertile open land ideal for farms and settlements."
	},
	TerrainType.FOREST: {
		"name": "Forest",
		"color": COLOR_FOREST,
		"yields": { "wood": 2 },
		"yield_desc": "+2 Wood per turn",
		"can_build": true,
		"description": "Dense woodlands rich in lumber and natural cover."
	},
	TerrainType.WATER: {
		"name": "Water",
		"color": COLOR_WATER,
		"yields": { "food": 1, "gold": 1 },
		"yield_desc": "+1 Food, +1 Gold per turn",
		"can_build": false,
		"description": "Deep water. Cannot support standard ground buildings."
	},
	TerrainType.MOUNTAIN: {
		"name": "Mountain",
		"color": COLOR_MOUNTAIN,
		"yields": { "gold": 2 },
		"yield_desc": "+2 Gold per turn",
		"can_build": false,
		"description": "Rugged, impassable peaks rich in mineral veins."
	}
}

## Ratio of original cost refunded when a building is demolished.
const DEMOLITION_REFUND_RATIO: float = 0.5

# 25x25 Data-driven expansive kingdom terrain map layout
var terrain_grid: Array = [
	[TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN],
	[TerrainType.MOUNTAIN, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.PLAINS],
	[TerrainType.PLAINS, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS],
	[TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS],
	[TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS],
	[TerrainType.FOREST, TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS],
	[TerrainType.FOREST, TerrainType.PLAINS, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS],
	[TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS],
	[TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS],
	[TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS],
	[TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.MOUNTAIN],
	[TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN],
	[TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.FOREST],
	[TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.MOUNTAIN],
	[TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN],
	[TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.FOREST],
	[TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.FOREST, TerrainType.MOUNTAIN],
	[TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN],
	[TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.FOREST],
	[TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.FOREST, TerrainType.MOUNTAIN],
	[TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN],
	[TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.FOREST],
	[TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.FOREST, TerrainType.FOREST, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.FOREST, TerrainType.MOUNTAIN],
	[TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.FOREST, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN],
	[TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.WATER, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.PLAINS, TerrainType.MOUNTAIN, TerrainType.MOUNTAIN, TerrainType.FOREST]
]

# Currently selected tile coordinate (-1, -1 means no selection)
var selected_coords: Vector2i = Vector2i(-1, -1)

# Building placement mode state
var pending_building: BuildingType = null
var demolish_mode: bool = false

# Node references for UI and Subsystems
@onready var top_bar: PanelContainer = get_node_or_null("HUD/TopBar") if get_node_or_null("HUD/TopBar") else get_node_or_null("TopBar")
@onready var tile_info_panel: PanelContainer = get_node_or_null("HUD/TileInfoPanel") if get_node_or_null("HUD/TileInfoPanel") else get_node_or_null("TileInfoPanel")
@onready var resource_manager: Node = get_node_or_null("ResourceManager")
@onready var turn_manager: Node = get_node_or_null("TurnManager")
@onready var building_layer: Node2D = get_node_or_null("BuildingLayer")
@onready var save_manager: Node = get_node_or_null("SaveManager")
@onready var terrain_renderer = get_node_or_null("TerrainRenderer")
@onready var selection_overlay = get_node_or_null("SelectionOverlay")
@onready var save_load_dialog: PanelContainer = get_node_or_null("HUD/SaveLoadDialog")
@onready var settings_dialog: PanelContainer = get_node_or_null("HUD/SettingsDialog")
@onready var pause_menu: PanelContainer = get_node_or_null("HUD/PauseMenu")
@onready var building_viewer_3d: PanelContainer = get_node_or_null("HUD/BuildingViewer3D")


func _ready() -> void:
	_setup_system_connections()
	_configure_visual_layers()
	_check_startup_load()


func _check_startup_load() -> void:
	if Engine.has_meta("load_slot_on_start"):
		var slot_to_load: String = str(Engine.get_meta("load_slot_on_start"))
		Engine.remove_meta("load_slot_on_start")
		if save_manager and save_manager.has_method("load_from_slot"):
			save_manager.load_from_slot(slot_to_load)


## Hands the map to the painterly terrain renderer and the selection overlay
func _configure_visual_layers() -> void:
	if terrain_renderer and terrain_renderer.has_method("configure"):
		terrain_renderer.configure(self)
	if selection_overlay and selection_overlay.has_method("configure"):
		selection_overlay.configure(self)
	queue_redraw()


## Connects subsystems together cleanly using Signals
func _setup_system_connections() -> void:
	var camera: Camera2D = get_node_or_null("StrategyCamera")
	if camera:
		if camera.has_method("configure_map_bounds"):
			camera.configure_map_bounds(get_map_rect())
		if camera.has_signal("zoom_3d_changed") and building_layer and building_layer.has_method("set_zoom_3d_ratio"):
			camera.zoom_3d_changed.connect(building_layer.set_zoom_3d_ratio)
			building_layer.set_zoom_3d_ratio(camera.get_3d_ratio())

	if building_layer and building_layer.has_method("configure_grid"):
		building_layer.configure_grid(MAP_OFFSET, TILE_SIZE)

	# 1. Connect tile selection signal to UI components
	if tile_info_panel and tile_info_panel.has_method("display_tile"):
		tile_selected.connect(tile_info_panel.display_tile)

	if tile_info_panel and tile_info_panel.has_signal("view_3d_requested"):
		tile_info_panel.view_3d_requested.connect(func(building: BuildingType):
			if building_viewer_3d and building_viewer_3d.has_method("open"):
				building_viewer_3d.open(building)
		)

	if top_bar and top_bar.has_method("update_coordinates"):
		tile_selected.connect(top_bar.update_coordinates)

	# 2. Connect TopBar "End Turn" button to TurnManager
	if top_bar and turn_manager:
		top_bar.end_turn_requested.connect(turn_manager.advance_turn)

	# 3. Connect TurnManager turn advancement to UI and ResourceManager
	if turn_manager:
		if top_bar:
			turn_manager.turn_advanced.connect(top_bar.update_turn)
		if resource_manager:
			turn_manager.turn_advanced.connect(_on_turn_advanced)

	# 4. Connect ResourceManager updates to TopBar
	if resource_manager and top_bar:
		resource_manager.resources_updated.connect(top_bar.update_resources)

	# 5. Connect Save & Load subsystems and Modals
	if top_bar:
		if top_bar.has_signal("save_requested"):
			top_bar.save_requested.connect(func():
				if save_load_dialog and save_manager:
					save_load_dialog.open(save_load_dialog.Mode.SAVE, save_manager)
				elif save_manager:
					save_manager.save_game()
			)
		if top_bar.has_signal("load_requested"):
			top_bar.load_requested.connect(func():
				if save_load_dialog and save_manager:
					save_load_dialog.open(save_load_dialog.Mode.LOAD, save_manager)
				elif save_manager:
					save_manager.load_game()
			)
		if top_bar.has_signal("menu_requested"):
			top_bar.menu_requested.connect(func():
				if pause_menu:
					pause_menu.open()
			)

	if pause_menu:
		pause_menu.save_requested.connect(func():
			if save_load_dialog and save_manager:
				save_load_dialog.open(save_load_dialog.Mode.SAVE, save_manager)
		)
		pause_menu.load_requested.connect(func():
			if save_load_dialog and save_manager:
				save_load_dialog.open(save_load_dialog.Mode.LOAD, save_manager)
		)
		pause_menu.settings_requested.connect(func():
			if settings_dialog:
				settings_dialog.open()
		)
		pause_menu.main_menu_requested.connect(func():
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		)
		pause_menu.quit_requested.connect(func():
			get_tree().quit()
		)

	if save_manager and top_bar and top_bar.has_method("show_status_message"):
		save_manager.game_saved.connect(func(_path: String): top_bar.show_status_message("Game Saved!", Color(0.4, 0.9, 0.4)))
		save_manager.game_loaded.connect(func(_path: String): top_bar.show_status_message("Game Loaded!", Color(0.4, 0.8, 1.0)))
		save_manager.save_error.connect(func(msg: String): top_bar.show_status_message(msg, Color(0.95, 0.4, 0.4)))

	# Initial UI synchronization
	if resource_manager and top_bar:
		top_bar.update_resources(resource_manager.get_resources())
	if turn_manager and top_bar:
		top_bar.update_turn(turn_manager.get_current_turn())


## Handles per-turn resource generation:
## 1. Advance construction on all buildings under construction.
## 2. Award base income.
## 3. Add terrain yields from worked tiles (tiles with completed buildings).
## 4. Add building production from completed buildings.
## 5. Deduct upkeep from completed buildings.
func _on_turn_advanced(_new_turn: int) -> void:
	# 1. Advance construction pipeline
	if building_layer and building_layer.has_method("advance_construction"):
		var just_completed: Array = building_layer.advance_construction()
		if top_bar and not just_completed.is_empty():
			var names: PackedStringArray = PackedStringArray()
			for c: Vector2i in just_completed:
				var b: BuildingType = get_building_at(c)
				if b:
					names.append(b.display_name)
			top_bar.show_status_message("%s completed!" % ", ".join(names), Color(0.4, 0.9, 0.4))

	if resource_manager:
		# 2. Base income
		resource_manager.process_turn_income()
		# 3. Terrain yields from worked tiles
		var terrain_income: Dictionary = get_worked_terrain_yields()
		if not terrain_income.is_empty():
			resource_manager.add_resources(terrain_income)
		# 4. Building production (completed only)
		var building_income: Dictionary = get_building_income()
		if not building_income.is_empty():
			resource_manager.add_resources(building_income)
		# 5. Upkeep costs (completed only)
		var upkeep_costs: Dictionary = get_building_upkeep()
		if not upkeep_costs.is_empty():
			resource_manager.deduct_upkeep(upkeep_costs)

	# 6. Background autosave
	if save_manager and save_manager.has_method("autosave"):
		save_manager.autosave()


## Returns the terrain display name for the given tile coordinates
func get_terrain_name(coords: Vector2i) -> String:
	if coords.x < 0 or coords.x >= GRID_WIDTH or coords.y < 0 or coords.y >= GRID_HEIGHT:
		return ""
	var terrain: TerrainType = terrain_grid[coords.y][coords.x]
	return TERRAIN_DATA[terrain]["name"]


## Returns the building placed on the given tile, or null if none
func get_building_at(coords: Vector2i) -> BuildingType:
	if building_layer == null:
		return null
	return building_layer.get_building_at(coords)


## Checks whether the given building can be placed on the specified tile
func can_place_building(coords: Vector2i, building: BuildingType) -> bool:
	if building == null:
		return false
	if coords.x < 0 or coords.x >= GRID_WIDTH or coords.y < 0 or coords.y >= GRID_HEIGHT:
		return false
	var terrain: TerrainType = terrain_grid[coords.y][coords.x]
	var terrain_info: Dictionary = TERRAIN_DATA[terrain]
	var is_buildable_terrain: bool = terrain_info.get("can_build", false)
	# Specialized structures (e.g. Dock on Water or Mine on Mountain) are permitted if explicitly listed in allowed_terrain_names
	if not is_buildable_terrain and not building.allowed_terrain_names.has(terrain_info["name"]):
		return false
	if not building.is_terrain_allowed(terrain_info["name"]):
		return false
	if building_layer and building_layer.is_occupied(coords):
		return false
	return true


## Returns human-readable error reason if placement cannot proceed
func get_placement_error(coords: Vector2i, building: BuildingType) -> String:
	if building == null:
		return "No building selected."
	if coords.x < 0 or coords.x >= GRID_WIDTH or coords.y < 0 or coords.y >= GRID_HEIGHT:
		return "Target tile is out of map boundaries."
	var terrain: TerrainType = terrain_grid[coords.y][coords.x]
	var terrain_info: Dictionary = TERRAIN_DATA[terrain]
	var is_buildable_terrain: bool = terrain_info.get("can_build", false)
	if not is_buildable_terrain and not building.allowed_terrain_names.has(terrain_info["name"]):
		return "%s cannot support buildings." % terrain_info["name"]
	if not building.is_terrain_allowed(terrain_info["name"]):
		return "%s requires %s (found %s)." % [building.display_name, building.get_allowed_terrain_text(), terrain_info["name"]]
	if building_layer and building_layer.is_occupied(coords):
		return "Tile (%d, %d) is already occupied." % [coords.x, coords.y]
	if resource_manager and not resource_manager.can_afford(building.cost):
		return "Cannot afford %s (%s needed)." % [building.display_name, building.get_cost_text()]
	return ""


## Attempts to place a building on the specified tile
func place_building(coords: Vector2i, building: BuildingType) -> bool:
	if not can_place_building(coords, building):
		var err_msg: String = get_placement_error(coords, building)
		placement_failed.emit(coords, err_msg)
		if top_bar and top_bar.has_method("show_status_message"):
			top_bar.show_status_message(err_msg, Color(0.95, 0.4, 0.4))
		return false

	if resource_manager:
		if not resource_manager.can_afford(building.cost):
			var err_msg: String = "Cannot afford %s (%s needed)." % [building.display_name, building.get_cost_text()]
			placement_failed.emit(coords, err_msg)
			if top_bar and top_bar.has_method("show_status_message"):
				top_bar.show_status_message(err_msg, Color(0.95, 0.4, 0.4))
			return false
		resource_manager.spend_resources(building.cost)

	if building_layer:
		building_layer.place_building(coords, building)

	building_placed.emit(coords, building)
	_update_tile_info(coords)
	return true


## Removes a building from the specified tile and refunds part of the cost.
func demolish_building(coords: Vector2i) -> bool:
	if building_layer == null or not building_layer.is_occupied(coords):
		return false
	var building: BuildingType = building_layer.get_building_at(coords)
	# Refund a portion of the original cost
	if resource_manager and not building.cost.is_empty():
		var refund: Dictionary = {}
		for res_name: String in building.cost:
			var amount: int = int(building.cost[res_name] * DEMOLITION_REFUND_RATIO)
			if amount > 0:
				refund[res_name] = amount
		if not refund.is_empty():
			resource_manager.add_resources(refund)
	building_layer.remove_building(coords)
	building_removed.emit(coords, building)
	_update_tile_info(coords)
	return true


## Arms the map for placing a specific building type
func set_pending_building(building: BuildingType) -> void:
	pending_building = building
	demolish_mode = false


## Arms or disarms demolish mode
func set_demolish_mode(enabled: bool = true) -> void:
	demolish_mode = enabled
	if enabled:
		pending_building = null


## Clears any armed build or demolish mode
func clear_build_modes() -> void:
	pending_building = null
	demolish_mode = false


## Sums resource production across all completed (not under construction) buildings
func get_building_income() -> Dictionary:
	var income: Dictionary = {}
	if building_layer == null:
		return income
	var completed: Dictionary = building_layer.get_completed_buildings()
	for b: BuildingType in completed.values():
		for res_name: String in b.production:
			income[res_name] = income.get(res_name, 0) + b.production[res_name]
	return income


## Returns the sum of terrain yields for every tile that has a completed building.
func get_worked_terrain_yields() -> Dictionary:
	var yields: Dictionary = {}
	if building_layer == null:
		return yields
	var completed: Dictionary = building_layer.get_completed_buildings()
	for coords: Vector2i in completed:
		if coords.x < 0 or coords.x >= GRID_WIDTH or coords.y < 0 or coords.y >= GRID_HEIGHT:
			continue
		var terrain: TerrainType = terrain_grid[coords.y][coords.x]
		var terrain_yields: Dictionary = TERRAIN_DATA[terrain].get("yields", {})
		for res_name: String in terrain_yields:
			yields[res_name] = yields.get(res_name, 0) + terrain_yields[res_name]
	return yields


## Sums upkeep costs across all completed buildings.
func get_building_upkeep() -> Dictionary:
	var costs: Dictionary = {}
	if building_layer == null:
		return costs
	var completed: Dictionary = building_layer.get_completed_buildings()
	for b: BuildingType in completed.values():
		for res_name: String in b.upkeep:
			costs[res_name] = costs.get(res_name, 0) + b.upkeep[res_name]
	return costs


func _unhandled_input(event: InputEvent) -> void:
	# Check for left mouse button click
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_tile_click(get_local_mouse_position())
	elif event is InputEventMouseMotion:
		_update_hover(get_local_mouse_position())


## Converts a local mouse position into grid coordinates (-1, -1 when outside)
func screen_to_tile_coords(mouse_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = mouse_pos - MAP_OFFSET
	if local_pos.x < 0.0 or local_pos.y < 0.0:
		return Vector2i(-1, -1)
	var coords := Vector2i(int(local_pos.x / TILE_SIZE.x), int(local_pos.y / TILE_SIZE.y))
	if not is_tile_in_bounds(coords):
		return Vector2i(-1, -1)
	return coords


func is_tile_in_bounds(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < GRID_WIDTH and coords.y >= 0 and coords.y < GRID_HEIGHT


## Area covered by the terrain grid in local (world) coordinates
func get_map_rect() -> Rect2:
	return Rect2(MAP_OFFSET, Vector2(GRID_WIDTH * TILE_SIZE.x, GRID_HEIGHT * TILE_SIZE.y))


func get_tile_size() -> Vector2:
	return TILE_SIZE


func get_grid_dimensions() -> Vector2i:
	return Vector2i(GRID_WIDTH, GRID_HEIGHT)


## Updates the hover highlight on the selection overlay
func _update_hover(mouse_pos: Vector2) -> void:
	if selection_overlay == null or not selection_overlay.has_method("set_hovered"):
		return
	selection_overlay.set_hovered(screen_to_tile_coords(mouse_pos))


## Determines which tile was clicked based on local mouse position and handles current mode
func _handle_tile_click(mouse_pos: Vector2) -> void:
	var local_pos: Vector2 = mouse_pos - MAP_OFFSET

	# Ignore clicks outside the top/left map boundaries
	if local_pos.x < 0.0 or local_pos.y < 0.0:
		return

	var grid_x: int = int(local_pos.x / TILE_SIZE.x)
	var grid_y: int = int(local_pos.y / TILE_SIZE.y)

	# Only proceed if click falls within valid grid boundaries
	if grid_x >= 0 and grid_x < GRID_WIDTH and grid_y >= 0 and grid_y < GRID_HEIGHT:
		var clicked_coords: Vector2i = Vector2i(grid_x, grid_y)
		selected_coords = clicked_coords
		queue_redraw()

		if pending_building != null:
			# In build mode: attempt placement
			place_building(clicked_coords, pending_building)
			_update_tile_info(clicked_coords)
		elif demolish_mode:
			# In demolish mode: attempt removal
			demolish_building(clicked_coords)
			_update_tile_info(clicked_coords)
		else:
			# Standard inspection mode
			_update_tile_info(clicked_coords)


## Synchronizes tile info across UI components
func _update_tile_info(coords: Vector2i) -> void:
	if coords.x < 0 or coords.y < 0:
		return
	var terrain: TerrainType = terrain_grid[coords.y][coords.x]
	var info: Dictionary = TERRAIN_DATA.get(terrain, {}).duplicate()
	var building: BuildingType = get_building_at(coords)
	info["building"] = building
	if building_layer and building_layer.has_method("get_construction_turns_left"):
		info["construction_turns_left"] = building_layer.get_construction_turns_left(coords)

	tile_selected.emit(coords, info)
	if tile_info_panel and tile_info_panel.has_method("display_tile"):
		tile_info_panel.display_tile(coords, info, building)
	if top_bar and top_bar.has_method("update_coordinates"):
		top_bar.update_coordinates(coords, info)


## Fallback flat terrain used in --low-gfx mode; the painted art is drawn by
## TerrainRenderer and the grid/selection by SelectionOverlay.
func _draw() -> void:
	if terrain_renderer != null and terrain_renderer.enabled:
		return

	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var terrain: TerrainType = terrain_grid[y][x]
			var terrain_info: Dictionary = TERRAIN_DATA.get(terrain, {})
			var color: Color = terrain_info.get("color", COLOR_PLAINS)
			var tile_rect: Rect2 = Rect2(
				MAP_OFFSET.x + x * TILE_SIZE.x,
				MAP_OFFSET.y + y * TILE_SIZE.y,
				TILE_SIZE.x,
				TILE_SIZE.y
			)
			draw_rect(tile_rect, color, true)
