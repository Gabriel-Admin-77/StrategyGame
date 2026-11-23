extends Node2D

## StrategyManager - Painterly Terrain Renderer
## Draws the painted terrain tiles, shoreline foam and seeded decorations.
## The gameplay grid stays authoritative in map.gd; this node only visualises it.
## In --low-gfx mode it disables itself and map.gd falls back to flat colour tiles.

const GameSettings = preload("res://scripts/core/game_settings.gd")

const TERRAIN_TEXTURES: Dictionary = {
	"Plains": "res://assets/sprites/terrain/terrain_plains.svg",
	"Forest": "res://assets/sprites/terrain/terrain_forest.svg",
	"Water": "res://assets/sprites/terrain/terrain_water.svg",
	"Mountain": "res://assets/sprites/terrain/terrain_mountain.svg"
}

const DECOR_TEXTURES: Dictionary = {
	"grass": "res://assets/sprites/fx/decor_grass.svg",
	"flower": "res://assets/sprites/fx/decor_flower.svg",
	"rock": "res://assets/sprites/fx/decor_rock.svg",
	"foam": "res://assets/sprites/fx/decor_foam.svg"
}

const FALLBACK_COLORS: Dictionary = {
	"Plains": Color(0.35, 0.72, 0.35),
	"Forest": Color(0.12, 0.45, 0.18),
	"Water": Color(0.22, 0.52, 0.88),
	"Mountain": Color(0.55, 0.38, 0.22)
}

const FOAM_ALPHA: float = 0.32
const FOAM_THICKNESS: float = 7.0
const DECOR_MIN_SIZE: float = 10.0
const DECOR_SIZE_RANGE: float = 12.0

@export var enabled: bool = true
## Percentage chance (0-100) for a tile to receive a decoration.
@export var decoration_density: int = 34
@export var show_shore_foam: bool = true

var _map = null
var _textures: Dictionary = {}
var _decor: Dictionary = {}
var _anim_time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_load_assets()


func _process(delta: float) -> void:
	if not enabled or _map == null or GameSettings.is_low_gfx():
		return
	_anim_time += delta
	queue_redraw()


## Called by the map once the scene tree is ready.
func configure(map_node) -> void:
	_map = map_node
	if GameSettings.is_low_gfx():
		enabled = false
	_load_assets()
	queue_redraw()


func get_texture(terrain_name: String) -> Texture2D:
	return _textures.get(terrain_name, null)


func get_decor_texture(decor_name: String) -> Texture2D:
	return _decor.get(decor_name, null)


## True when every terrain type has a painted texture available.
func has_all_terrain_art() -> bool:
	for terrain_name: String in TERRAIN_TEXTURES.keys():
		if not _textures.has(terrain_name):
			return false
	return true


## Deterministic variant index (0-3) for a tile, used for subtle tint variety.
func get_tile_variant(coords: Vector2i) -> int:
	var value: int = (coords.x * 73856093) ^ (coords.y * 19349663)
	return absi(value) % 4


## Subtle brightness variation so neighbouring tiles do not look identical.
func get_variant_tint(coords: Vector2i) -> Color:
	var shades: Array[float] = [1.0, 0.96, 1.03, 0.99]
	var shade: float = shades[get_tile_variant(coords)]
	return Color(shade, shade, shade * 0.995, 1.0)


## Decoration key to draw on a tile ("" when nothing should be drawn).
func get_decoration_for(coords: Vector2i, terrain_name: String) -> String:
	var value: int = absi((coords.x * 83492791) ^ (coords.y * 15485863))
	var roll: int = value % 100
	match terrain_name:
		"Plains":
			if roll < 12:
				return "flower"
			if roll < decoration_density:
				return "grass"
		"Forest":
			if roll < 12:
				return "grass"
		"Mountain":
			if roll < 26:
				return "rock"
	return ""


func _load_assets() -> void:
	if _textures.is_empty():
		for terrain_name: String in TERRAIN_TEXTURES.keys():
			var texture := _load_texture(TERRAIN_TEXTURES[terrain_name])
			if texture != null:
				_textures[terrain_name] = texture
	if _decor.is_empty():
		for decor_name: String in DECOR_TEXTURES.keys():
			var texture := _load_texture(DECOR_TEXTURES[decor_name])
			if texture != null:
				_decor[decor_name] = texture


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if resource is Texture2D:
		return resource
	return null


func _draw() -> void:
	if not enabled or _map == null:
		return

	var origin: Vector2 = _map.get_map_rect().position
	var dimensions: Vector2i = _map.get_grid_dimensions()
	var tile: Vector2 = _map.get_tile_size()

	# Pass 1 - terrain bases
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var coords := Vector2i(x, y)
			var terrain_name: String = _map.get_terrain_name(coords)
			var tile_rect := Rect2(origin + Vector2(float(x) * tile.x, float(y) * tile.y), tile)
			var texture: Texture2D = _textures.get(terrain_name, null)
			if texture != null:
				draw_texture_rect(texture, tile_rect, false, get_variant_tint(coords))
			else:
				draw_rect(tile_rect, FALLBACK_COLORS.get(terrain_name, Color.MAGENTA), true)

			# Living water shimmer waves
			if terrain_name == "Water":
				_draw_water_shimmer(coords, tile_rect, tile)

	# Pass 2 - shoreline foam between water and land
	if show_shore_foam:
		_draw_shorelines(origin, dimensions, tile)

	# Pass 3 - seeded decorations
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var coords := Vector2i(x, y)
			var terrain_name: String = _map.get_terrain_name(coords)
			var tile_rect := Rect2(origin + Vector2(float(x) * tile.x, float(y) * tile.y), tile)
			_draw_decoration(coords, tile_rect, terrain_name)


func _draw_water_shimmer(coords: Vector2i, tile_rect: Rect2, tile: Vector2) -> void:
	var wave_time: float = _anim_time * 1.8 + float(coords.x * 2 + coords.y * 3) * 0.45
	var wave_shift: float = sin(wave_time) * 3.5
	var wave_y1: float = tile_rect.position.y + tile.y * 0.34 + sin(wave_time * 1.3) * 2.0
	var wave_y2: float = tile_rect.position.y + tile.y * 0.67 + cos(wave_time) * 2.0
	var alpha_pulse: float = 0.18 + 0.09 * sin(wave_time * 1.6)
	var wave_color := Color(1.0, 1.0, 1.0, alpha_pulse)
	draw_line(
		Vector2(tile_rect.position.x + 8.0 + wave_shift, wave_y1),
		Vector2(tile_rect.position.x + tile.x - 8.0 + wave_shift, wave_y1),
		wave_color, 2.0
	)
	draw_line(
		Vector2(tile_rect.position.x + 14.0 - wave_shift, wave_y2),
		Vector2(tile_rect.position.x + tile.x - 14.0 - wave_shift, wave_y2),
		wave_color * 0.8, 1.5
	)


func _draw_shorelines(origin: Vector2, dimensions: Vector2i, tile: Vector2) -> void:
	var foam: Texture2D = _decor.get("foam", null)
	if foam == null:
		return

	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var coords := Vector2i(x, y)
			if _map.get_terrain_name(coords) != "Water":
				continue

			var tile_rect := Rect2(origin + Vector2(float(x) * tile.x, float(y) * tile.y), tile)
			var foam_wave: float = sin(_anim_time * 2.2 + float(coords.x * 3 + coords.y * 5) * 0.5)
			var current_alpha: float = clampf(FOAM_ALPHA * (0.85 + 0.35 * foam_wave), 0.1, 0.55)
			var current_thickness: float = clampf(FOAM_THICKNESS + 1.5 * foam_wave, 4.0, 10.0)
			var tint := Color(1, 1, 1, current_alpha)

			for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var neighbour: Vector2i = coords + direction
				var neighbour_name: String = _map.get_terrain_name(neighbour)
				if neighbour_name.is_empty() or neighbour_name == "Water":
					continue
				if direction == Vector2i.UP:
					draw_texture_rect(foam, Rect2(tile_rect.position + Vector2(0, -2), Vector2(tile.x, current_thickness)), false, tint)
				elif direction == Vector2i.DOWN:
					draw_texture_rect(foam, Rect2(tile_rect.position + Vector2(0, tile.y - current_thickness + 2), Vector2(tile.x, current_thickness)), false, tint)
				elif direction == Vector2i.LEFT:
					draw_texture_rect(foam, Rect2(tile_rect.position + Vector2(-2, 0), Vector2(current_thickness, tile.y)), false, tint)
				else:
					draw_texture_rect(foam, Rect2(tile_rect.position + Vector2(tile.x - current_thickness + 2, 0), Vector2(current_thickness, tile.y)), false, tint)


func _draw_decoration(coords: Vector2i, tile_rect: Rect2, terrain_name: String) -> void:
	var decor_name: String = get_decoration_for(coords, terrain_name)
	if decor_name.is_empty():
		return

	var texture: Texture2D = _decor.get(decor_name, null)
	if texture == null:
		return

	var seed_value: int = absi((coords.x * 2654435761) ^ (coords.y * 40503))
	var size: float = DECOR_MIN_SIZE + float(seed_value % 100) / 100.0 * DECOR_SIZE_RANGE
	var offset := Vector2(
		float((seed_value >> 5) % 46) + 6.0,
		float((seed_value >> 11) % 34) + 10.0
	)
	draw_texture_rect(texture, Rect2(tile_rect.position + offset, Vector2(size, size)), false, Color(1, 1, 1, 0.9))
