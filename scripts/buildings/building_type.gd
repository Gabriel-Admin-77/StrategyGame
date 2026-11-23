extends Resource

## StrategyManager - Building Type Data
## Data-driven definition of a placeable building.
## Add new buildings by duplicating a .tres file inside res://resources/building_types/.

@export var id: String = ""
@export var display_name: String = "Building"
@export_multiline var description: String = ""
## Short label drawn on top of the building marker on the map.
@export var short_code: String = "B"
## Marker color used when the building is rendered on the map.
@export var color: Color = Color(0.85, 0.75, 0.35)
## Painted illustration drawn on the map (falls back to a coloured marker).
@export var world_texture: Texture2D = null
## Icon used on palette buttons.
@export var ui_icon: Texture2D = null
## How large the illustration is relative to one tile.
@export var visual_scale: float = 1.35
## Extra pixel offset applied to the illustration.
@export var visual_offset: Vector2 = Vector2.ZERO
## Terrain names (see Map.TERRAIN_DATA "name" keys) the building may be placed on.
## Leave empty to allow every buildable terrain.
@export var allowed_terrain_names: PackedStringArray = PackedStringArray()
## Upfront resource costs, e.g. { "gold": 30, "wood": 20 }. Consumed by the economy phase.
@export var cost: Dictionary = {}
## Per-turn production, e.g. { "food": 3 }. Consumed by the economy phase.
@export var production: Dictionary = {}
## Per-turn upkeep deducted while the building is active, e.g. { "gold": 1 }.
@export var upkeep: Dictionary = {}
## Turns needed to finish construction (1 = instant).
@export var build_turns: int = 1
## 3D Model scene (PackedScene, e.g. .glb) for real-time 3D inspection and zoom transition.
@export var model_3d: PackedScene = null


## Resolves the 3D model for this building, with automatic fallback to assets/models/buildings/.
func get_model_3d() -> PackedScene:
	if model_3d != null:
		return model_3d
	var path: String = "res://assets/models/buildings/building_%s.glb" % id
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is PackedScene:
			return res
	return null


## Returns true when this building may be placed on the given terrain name.
func is_terrain_allowed(terrain_name: String) -> bool:
	if allowed_terrain_names.is_empty():
		return true
	return allowed_terrain_names.has(terrain_name)


## Human readable terrain requirement, e.g. "Plains or Forest".
func get_allowed_terrain_text() -> String:
	if allowed_terrain_names.is_empty():
		return "any buildable"
	return _join_names(allowed_terrain_names)


## Human readable production summary, e.g. "+3 Food/turn".
func get_production_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for resource_name: String in production.keys():
		var amount: String = str(production[resource_name])
		parts.append("+%s %s/turn" % [amount, resource_name.capitalize()])
	return ", ".join(parts)


## Human readable cost summary, e.g. "30 Gold, 20 Wood".
func get_cost_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for resource_name: String in cost.keys():
		var amount: String = str(cost[resource_name])
		parts.append("%s %s" % [amount, resource_name.capitalize()])
	return ", ".join(parts)


## Joins names with commas and a final "or", e.g. "Plains or Forest".
func _join_names(names: PackedStringArray) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return names[0]
	var head: PackedStringArray = names.slice(0, names.size() - 1)
	return "%s or %s" % [", ".join(head), names[names.size() - 1]]
