extends Node2D

## StrategyManager - Building Layer
## Owns every placed building: occupancy bookkeeping, construction progress,
## the placement/removal API, and the rendering of building markers on top of
## the terrain grid.

const BuildingType = preload("res://scripts/buildings/building_type.gd")
const GameSettings = preload("res://scripts/core/game_settings.gd")

signal building_placed(coords: Vector2i, building: BuildingType)
signal building_removed(coords: Vector2i, building: BuildingType)
signal building_completed(coords: Vector2i, building: BuildingType)

# Grid geometry - kept in sync with the map through configure_grid()
@export var map_offset: Vector2 = Vector2(40.0, 40.0)
@export var tile_size: Vector2 = Vector2(64.0, 64.0)
## Padding between the tile border and the building marker.
@export var marker_inset: float = 10.0

const COLOR_MARKER_BORDER: Color = Color(0.08, 0.08, 0.08, 0.85)
const COLOR_MARKER_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.25)
const COLOR_MARKER_TEXT: Color = Color(1.0, 1.0, 1.0, 0.95)
const LABEL_FONT_SIZE: int = 15
const SHADOW_OFFSET: Vector2 = Vector2(3.0, 3.0)
const BORDER_WIDTH: float = 2.0
const CONSTRUCTION_TINT: Color = Color(1.0, 1.0, 1.0, 0.5)

# Tile coordinate (Vector2i) -> { "type": BuildingType, "turns_left": int }
var _buildings: Dictionary = {}

# Cached building illustrations, keyed by building id
var _texture_cache: Dictionary = {}
var _anim_time: float = 0.0
var _zoom_3d_ratio: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func set_zoom_3d_ratio(ratio: float) -> void:
	if not is_equal_approx(_zoom_3d_ratio, ratio):
		_zoom_3d_ratio = ratio
		queue_redraw()


func _process(delta: float) -> void:
	if _buildings.is_empty() or GameSettings.is_low_gfx():
		return
	_anim_time += delta
	queue_redraw()


## Called by the map so both systems share the exact same grid geometry.
func configure_grid(offset: Vector2, size: Vector2) -> void:
	map_offset = offset
	tile_size = size
	queue_redraw()


func is_occupied(coords: Vector2i) -> bool:
	return _buildings.has(coords)


## Returns the BuildingType at the given tile, or null if empty.
func get_building_at(coords: Vector2i) -> BuildingType:
	if not _buildings.has(coords):
		return null
	return _buildings[coords]["type"]


func get_building_count() -> int:
	return _buildings.size()


## Returns a Dictionary mapping Vector2i -> BuildingType (all tiles).
func get_all_buildings() -> Dictionary:
	var result: Dictionary = {}
	for coords: Vector2i in _buildings:
		result[coords] = _buildings[coords]["type"]
	return result


## Returns true when the building on the given tile is still under construction.
func is_under_construction(coords: Vector2i) -> bool:
	if not _buildings.has(coords):
		return false
	return _buildings[coords]["turns_left"] > 0


## Returns the number of construction turns remaining (0 = completed).
func get_construction_turns_left(coords: Vector2i) -> int:
	if not _buildings.has(coords):
		return 0
	return _buildings[coords]["turns_left"]


## Returns true when the building is placed and fully completed.
func is_completed(coords: Vector2i) -> bool:
	if not _buildings.has(coords):
		return false
	return _buildings[coords]["turns_left"] <= 0


## Returns all completed buildings: Dictionary of Vector2i -> BuildingType.
func get_completed_buildings() -> Dictionary:
	var result: Dictionary = {}
	for coords: Vector2i in _buildings:
		if _buildings[coords]["turns_left"] <= 0:
			result[coords] = _buildings[coords]["type"]
	return result


## Stores a building on the given tile. Rejects null entries and occupied tiles.
## If build_turns == 1 the building completes instantly (turns_left = 0).
func place_building(coords: Vector2i, building: BuildingType) -> bool:
	if building == null or _buildings.has(coords):
		return false
	var turns_left: int = maxi(building.build_turns - 1, 0)
	_buildings[coords] = { "type": building, "turns_left": turns_left }
	queue_redraw()
	building_placed.emit(coords, building)
	if turns_left <= 0:
		building_completed.emit(coords, building)
	return true


## Places a building with explicit construction state (used by save/load).
func place_building_with_state(coords: Vector2i, building: BuildingType, turns_left: int) -> bool:
	if building == null or _buildings.has(coords):
		return false
	_buildings[coords] = { "type": building, "turns_left": maxi(turns_left, 0) }
	queue_redraw()
	building_placed.emit(coords, building)
	return true


## Removes the building on the given tile. Returns false when the tile is empty.
func remove_building(coords: Vector2i) -> bool:
	if not _buildings.has(coords):
		return false
	var building: BuildingType = _buildings[coords]["type"]
	_buildings.erase(coords)
	queue_redraw()
	building_removed.emit(coords, building)
	return true


## Removes every building without emitting per-tile signals.
func clear_all() -> void:
	if _buildings.is_empty():
		return
	_buildings.clear()
	queue_redraw()


## Advances construction by one turn for every building still being built.
## Returns the list of tile coordinates that completed this turn.
func advance_construction() -> Array:
	var just_completed: Array = []
	for coords: Vector2i in _buildings:
		var entry: Dictionary = _buildings[coords]
		if entry["turns_left"] > 0:
			entry["turns_left"] -= 1
			if entry["turns_left"] <= 0:
				just_completed.append(coords)
				building_completed.emit(coords, entry["type"])
	if not just_completed.is_empty():
		queue_redraw()
	return just_completed


## Screen-space rectangle used to draw the marker of the given tile.
func get_marker_rect(coords: Vector2i) -> Rect2:
	var tile_origin: Vector2 = map_offset + Vector2(float(coords.x) * tile_size.x, float(coords.y) * tile_size.y)
	return Rect2(tile_origin, tile_size).grow(-marker_inset)


## Draws the painted building illustrations, with a coloured marker fallback.
## Buildings under construction are drawn at half opacity with turns-left badge.
func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for coords: Vector2i in _buildings.keys():
		var entry: Dictionary = _buildings[coords]
		var building: BuildingType = entry["type"]
		var under_construction: bool = entry["turns_left"] > 0
		var rect: Rect2 = get_marker_rect(coords)

		var texture: Texture2D = _resolve_texture(building)
		if texture != null:
			var scale_factor: float = building.visual_scale
			if scale_factor <= 0.0:
				scale_factor = 1.35
			var visual_size: Vector2 = tile_size * scale_factor
			var visual_rect := Rect2(
				Vector2(rect.get_center().x - visual_size.x * 0.5, rect.end.y - visual_size.y + marker_inset * 0.5),
				visual_size
			)
			visual_rect.position += building.visual_offset

			# Dynamic 3D depth and ground shadow as zoom increases
			if _zoom_3d_ratio > 0.05 and not under_construction:
				var shadow_center: Vector2 = rect.get_center() + Vector2(6.0 * _zoom_3d_ratio, 8.0 * _zoom_3d_ratio)
				var shadow_radius := Vector2(visual_size.x * 0.38, visual_size.y * 0.16)
				_draw_oval(shadow_center, shadow_radius, Color(0.0, 0.0, 0.0, 0.38 * _zoom_3d_ratio))
				# Physically elevate building upward along isometric axis
				visual_rect.position.y -= _zoom_3d_ratio * 12.0

			# Gentle water bobbing for docked boats
			if building.id == "dock" and not under_construction:
				visual_rect.position.y += sin(_anim_time * 2.4 + float(coords.x * 3 + coords.y * 5)) * 2.2

			var tint: Color = CONSTRUCTION_TINT if under_construction else Color.WHITE
			draw_texture_rect(texture, visual_rect, false, tint)

			# Living building ambient animations (smoke, forge glow, wheel splashes, etc.)
			if not under_construction and not GameSettings.is_low_gfx():
				_draw_building_ambience(building, coords, visual_rect)
		else:
			# Fallback marker when no illustration is available
			var marker_color: Color = building.color
			if under_construction:
				marker_color.a = 0.5
			draw_rect(Rect2(rect.position + SHADOW_OFFSET, rect.size), COLOR_MARKER_SHADOW, true)
			draw_rect(rect, marker_color, true)
			draw_rect(rect, COLOR_MARKER_BORDER, false, BORDER_WIDTH)

			if not building.short_code.is_empty():
				var text_size: Vector2 = font.get_string_size(building.short_code, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
				var text_pos: Vector2 = rect.position + (rect.size - text_size) * 0.5
				text_pos.y += font.get_ascent(LABEL_FONT_SIZE)
				draw_string(font, text_pos, building.short_code, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, COLOR_MARKER_TEXT)

		# Construction badge: show remaining turns
		if under_construction:
			var badge_text: String = str(entry["turns_left"])
			var badge_size: Vector2 = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
			var badge_pos: Vector2 = Vector2(rect.end.x - badge_size.x - 2.0, rect.position.y + font.get_ascent(LABEL_FONT_SIZE) + 2.0)
			draw_string(font, badge_pos + Vector2(1, 1), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color.BLACK)
			draw_string(font, badge_pos, badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color(1.0, 0.85, 0.3))


## Resolves the painted illustration for a building, caching lookups by id.
func _resolve_texture(building: BuildingType) -> Texture2D:
	if building.world_texture != null:
		return building.world_texture

	var key: String = building.id
	if key.is_empty():
		key = building.display_name.to_lower().replace(" ", "_")
	if _texture_cache.has(key):
		return _texture_cache[key]

	var texture: Texture2D = null
	var path: String = "res://assets/sprites/buildings/building_%s.svg" % key
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			texture = resource
	_texture_cache[key] = texture
	return texture


## Ambient living animations for completed buildings
func _draw_building_ambience(building: BuildingType, coords: Vector2i, visual_rect: Rect2) -> void:
	match building.id:
		"farm":
			_draw_chimney_smoke(coords, visual_rect, _anim_time, Vector2(visual_rect.size.x * 0.73, visual_rect.size.y * 0.16))
		"house":
			_draw_chimney_smoke(coords, visual_rect, _anim_time, Vector2(visual_rect.size.x * 0.68, visual_rect.size.y * 0.14))
		"workshop":
			_draw_chimney_smoke(coords, visual_rect, _anim_time, Vector2(visual_rect.size.x * 0.76, visual_rect.size.y * 0.12))
			_draw_forge_glow(coords, visual_rect, _anim_time)
		"lumber_mill":
			_draw_waterwheel_splashes(coords, visual_rect, _anim_time)
		"mine":
			_draw_mine_glow(coords, visual_rect, _anim_time)
		"dock":
			_draw_dock_ripples(coords, visual_rect, _anim_time)


func _draw_chimney_smoke(coords: Vector2i, visual_rect: Rect2, time: float, chimney_offset: Vector2) -> void:
	var base_pos: Vector2 = visual_rect.position + chimney_offset
	for i: int in range(3):
		var phase: float = fmod(time * 0.75 + float(i) * 0.33 + float(coords.x * 7 + coords.y * 13) * 0.1, 1.0)
		var rise: float = phase * 28.0
		var drift: float = sin(time * 1.5 + phase * 3.0) * 4.0 + phase * 7.0
		var puff_pos := Vector2(base_pos.x + drift, base_pos.y - rise)
		var radius: float = 2.5 + phase * 5.5
		var alpha: float = (1.0 - phase) * 0.4
		draw_circle(puff_pos, radius, Color(0.92, 0.94, 0.98, alpha))


func _draw_forge_glow(coords: Vector2i, visual_rect: Rect2, time: float) -> void:
	var forge_pos: Vector2 = visual_rect.position + Vector2(visual_rect.size.x * 0.48, visual_rect.size.y * 0.72)
	var pulse: float = 0.5 + 0.35 * sin(time * 5.5 + float(coords.x * 3 + coords.y * 2))
	draw_circle(forge_pos, 8.0, Color(1.0, 0.45, 0.1, pulse * 0.35))
	draw_circle(forge_pos, 4.0, Color(1.0, 0.85, 0.25, pulse * 0.7))


func _draw_waterwheel_splashes(coords: Vector2i, visual_rect: Rect2, time: float) -> void:
	var wheel_pos: Vector2 = visual_rect.position + Vector2(visual_rect.size.x * 0.2, visual_rect.size.y * 0.82)
	for s: int in range(3):
		var phase: float = fmod(time * 3.5 + float(s) * 0.33 + float(coords.x), 1.0)
		var spray_x: float = cos(phase * PI) * 5.0 - 2.0
		var spray_y: float = -sin(phase * PI) * 6.5
		var alpha: float = (1.0 - phase) * 0.55
		draw_circle(wheel_pos + Vector2(spray_x, spray_y), 1.6, Color(0.85, 0.95, 1.0, alpha))


func _draw_mine_glow(coords: Vector2i, visual_rect: Rect2, time: float) -> void:
	var entrance_pos: Vector2 = visual_rect.position + Vector2(visual_rect.size.x * 0.48, visual_rect.size.y * 0.6)
	var flicker: float = 0.4 + 0.25 * sin(time * 7.5 + float(coords.y * 4)) + 0.1 * sin(time * 17.0)
	draw_circle(entrance_pos, 6.0, Color(1.0, 0.78, 0.2, flicker * 0.35))
	draw_circle(entrance_pos, 2.5, Color(1.0, 0.95, 0.5, flicker * 0.75))


func _draw_dock_ripples(coords: Vector2i, visual_rect: Rect2, time: float) -> void:
	var water_pos: Vector2 = visual_rect.position + Vector2(visual_rect.size.x * 0.72, visual_rect.size.y * 0.85)
	for r: int in range(2):
		var phase: float = fmod(time * 1.5 + float(r) * 0.5 + float(coords.x), 1.0)
		var radius: float = 4.0 + phase * 10.0
		var alpha: float = (1.0 - phase) * 0.35
		draw_arc(water_pos, radius, 0.0, TAU, 12, Color(1.0, 1.0, 1.0, alpha), 1.5)


func _draw_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	var segments: int = 16
	for i: int in range(segments):
		var angle: float = float(i) * TAU / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
