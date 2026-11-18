extends Node2D

## StrategyManager - Selection Overlay
## Draws the subtle grid, the hover highlight and the gold selection frame on
## top of the painted terrain and buildings.

const COLOR_GRID: Color = Color(0.12, 0.09, 0.05, 0.16)
const COLOR_SELECTION: Color = Color(0.95, 0.78, 0.35, 1.0)
const COLOR_SELECTION_GLOW: Color = Color(0.95, 0.78, 0.35, 0.22)
const COLOR_HOVER: Color = Color(1.0, 1.0, 1.0, 0.14)
const GRID_WIDTH: float = 1.0
const SELECTION_WIDTH: float = 2.5
const SELECTION_GLOW_WIDTH: float = 7.0

@export var show_grid: bool = true
@export var show_hover: bool = true

var _map = null
var _hovered_coords: Vector2i = Vector2i(-1, -1)
var _last_selection: Vector2i = Vector2i(-2, -2)


func configure(map_node) -> void:
	_map = map_node
	if _map != null:
		_last_selection = _map.selected_coords
	queue_redraw()


func set_hovered(coords: Vector2i) -> void:
	if coords == _hovered_coords:
		return
	_hovered_coords = coords
	queue_redraw()


func get_hovered() -> Vector2i:
	return _hovered_coords


func _process(_delta: float) -> void:
	if _map == null:
		return
	var selection: Vector2i = _map.selected_coords
	if selection != _last_selection:
		_last_selection = selection
		queue_redraw()


func _draw() -> void:
	if _map == null:
		return

	var origin: Vector2 = _map.get_map_rect().position
	var dimensions: Vector2i = _map.get_grid_dimensions()
	var tile: Vector2 = _map.get_tile_size()

	if show_grid:
		for x: int in range(dimensions.x + 1):
			var column_x: float = origin.x + float(x) * tile.x
			draw_line(Vector2(column_x, origin.y), Vector2(column_x, origin.y + dimensions.y * tile.y), COLOR_GRID, GRID_WIDTH)
		for y: int in range(dimensions.y + 1):
			var row_y: float = origin.y + float(y) * tile.y
			draw_line(Vector2(origin.x, row_y), Vector2(origin.x + dimensions.x * tile.x, row_y), COLOR_GRID, GRID_WIDTH)

	if show_hover and _hovered_coords.x >= 0 and _hovered_coords.y >= 0:
		draw_rect(_rect_for(_hovered_coords, origin, tile), COLOR_HOVER, true)

	var selected: Vector2i = _map.selected_coords
	if selected.x >= 0 and selected.y >= 0:
		var selected_rect: Rect2 = _rect_for(selected, origin, tile)
		draw_rect(selected_rect.grow(2.0), COLOR_SELECTION_GLOW, false, SELECTION_GLOW_WIDTH)
		draw_rect(selected_rect, COLOR_SELECTION, false, SELECTION_WIDTH)


func _rect_for(coords: Vector2i, origin: Vector2, tile: Vector2) -> Rect2:
	return Rect2(origin + Vector2(float(coords.x) * tile.x, float(coords.y) * tile.y), tile)
