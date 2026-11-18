extends Node

## StrategyManager - Save Manager
## Serializes game state (turn, resources, placed buildings, selection) to JSON
## and restores the complete game session from disk.

const BuildingType = preload("res://scripts/buildings/building_type.gd")

signal game_saved(filepath: String)
signal game_loaded(filepath: String)
signal save_error(message: String)

const DEFAULT_SAVE_PATH: String = "user://savegame.json"
const BUILDING_TYPES_PATH: String = "res://resources/building_types"

# Node references (configured automatically in _ready if inside Map)
@export var map_node: Node2D = null
@export var turn_manager: Node = null
@export var resource_manager: Node = null
@export var building_layer: Node2D = null

# Cached map of building id -> BuildingType resource
var _catalog: Dictionary = {}


func _ready() -> void:
	_ensure_catalog()
	_ensure_references()


## Loads and indexes all BuildingType resources from disk by their unique id
func _ensure_catalog() -> void:
	if not _catalog.is_empty():
		return

	var dir: DirAccess = DirAccess.open(BUILDING_TYPES_PATH)
	if dir == null:
		push_warning("SaveManager: Failed to open building types directory: %s" % BUILDING_TYPES_PATH)
		return

	for file_name: String in dir.get_files():
		var clean_name: String = file_name.trim_suffix(".remap")
		if clean_name.ends_with(".tres"):
			var res_path: String = BUILDING_TYPES_PATH.path_join(clean_name)
			var res = load(res_path)
			if res is BuildingType and not res.id.is_empty():
				_catalog[res.id] = res


## Finds parent and sibling subsystems if not set manually
func _ensure_references() -> void:
	if map_node == null:
		if get_parent() is Node2D:
			map_node = get_parent()
	if map_node != null:
		if turn_manager == null:
			turn_manager = map_node.get_node_or_null("TurnManager")
		if resource_manager == null:
			resource_manager = map_node.get_node_or_null("ResourceManager")
		if building_layer == null:
			building_layer = map_node.get_node_or_null("BuildingLayer")


## Serializes current game state and writes to the given path
func save_game(filepath: String = "") -> bool:
	var target_path: String = filepath if not filepath.is_empty() else DEFAULT_SAVE_PATH
	_ensure_references()

	var save_data: Dictionary = {
		"version": 1,
		"turn": turn_manager.get_current_turn() if turn_manager else 1,
		"resources": resource_manager.get_resources() if resource_manager else {},
		"buildings": [],
		"selected_coords": {
			"x": map_node.selected_coords.x if map_node else -1,
			"y": map_node.selected_coords.y if map_node else -1
		}
	}

	# Serialize placed buildings
	if building_layer and building_layer.has_method("get_all_buildings"):
		var placed: Dictionary = building_layer.get_all_buildings()
		for coords: Vector2i in placed.keys():
			var b: BuildingType = placed[coords]
			save_data["buildings"].append({
				"x": coords.x,
				"y": coords.y,
				"id": b.id
			})

	var json_text: String = JSON.stringify(save_data, "\t")
	var file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		var err: String = "Failed to open save file for writing at: %s (Error %d)" % [target_path, FileAccess.get_open_error()]
		save_error.emit(err)
		return false

	file.store_string(json_text)
	file.close()

	game_saved.emit(target_path)
	return true


## Reads JSON save file from disk and restores the game state
func load_game(filepath: String = "") -> bool:
	var target_path: String = filepath if not filepath.is_empty() else DEFAULT_SAVE_PATH
	_ensure_references()
	_ensure_catalog()

	if not FileAccess.file_exists(target_path):
		var err: String = "No save file found at: %s" % target_path
		save_error.emit(err)
		return false

	var file: FileAccess = FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		var err: String = "Failed to open save file for reading: %s" % target_path
		save_error.emit(err)
		return false

	var content: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(content)
	if parse_err != OK:
		var err: String = "JSON parse error: %s at line %d" % [json.get_error_message(), json.get_error_line()]
		save_error.emit(err)
		return false

	var data = json.data
	if not (data is Dictionary):
		save_error.emit("Corrupted save file: root element is not a dictionary.")
		return false

	# 1. Restore Turn
	if turn_manager and data.has("turn"):
		turn_manager.set_current_turn(int(data["turn"]))

	# 2. Restore Resources
	if resource_manager and data.has("resources"):
		resource_manager.set_resources(data["resources"])

	# 3. Restore Buildings
	if building_layer:
		building_layer.clear_all()
		if data.has("buildings") and data["buildings"] is Array:
			for entry: Dictionary in data["buildings"]:
				var coords: Vector2i = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
				var b_id: String = str(entry.get("id", ""))
				var b_type: BuildingType = _catalog.get(b_id, null)
				if b_type != null:
					building_layer.place_building(coords, b_type)

	# 4. Restore Selection & Update UI
	if map_node and data.has("selected_coords"):
		var sel_data: Dictionary = data["selected_coords"]
		var restored_coords: Vector2i = Vector2i(int(sel_data.get("x", -1)), int(sel_data.get("y", -1)))
		map_node.selected_coords = restored_coords
		map_node.queue_redraw()
		if map_node.has_method("_update_tile_info") and restored_coords.x >= 0 and restored_coords.y >= 0:
			map_node._update_tile_info(restored_coords)

	game_loaded.emit(target_path)
	return true


## Checks whether a save file exists
func has_save(filepath: String = "") -> bool:
	var target_path: String = filepath if not filepath.is_empty() else DEFAULT_SAVE_PATH
	return FileAccess.file_exists(target_path)
