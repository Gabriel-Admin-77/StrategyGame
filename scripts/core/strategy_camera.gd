extends Camera2D

## StrategyManager - Strategy Camera
## Provides smooth 2D panning (WASD, Arrow keys, Right-click/Middle-click drag)
## and zoom (Mouse wheel) with configurable limits.

signal camera_moved(new_position: Vector2)
signal camera_zoomed(new_zoom: Vector2)
signal zoom_3d_changed(ratio: float)

# Panning configuration
@export var pan_speed: float = 450.0
@export var drag_sensitivity: float = 1.0

# Zoom configuration
@export var min_zoom: float = 0.35
@export var max_zoom: float = 2.0
@export var zoom_step: float = 0.1
@export var zoom_smoothness: float = 12.0

# Camera limits (bounding box for camera origin)
@export var limit_min: Vector2 = Vector2(-250.0, -200.0)
@export var limit_max: Vector2 = Vector2(1750.0, 1700.0)

var _target_zoom: Vector2 = Vector2.ONE
var _is_dragging: bool = false
var _previous_position: Vector2 = Vector2.ZERO
var _zoom_3d_ratio: float = 0.0


## Returns the normalized 3D transition factor (0.0 = top-down 2D, 1.0 = close-up 3D)
func get_3d_ratio() -> float:
	return _zoom_3d_ratio


## Configures camera panning boundaries based on the map bounding rect
func configure_map_bounds(map_rect: Rect2, margin: Vector2 = Vector2(250.0, 200.0)) -> void:
	limit_min = -margin
	limit_max = map_rect.position + map_rect.size + margin - Vector2(200.0, 200.0)


func _ready() -> void:
	# Fixed top-left anchor ensures initial view perfectly matches the original layout
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	enabled = true
	_target_zoom = zoom
	_previous_position = position
	_update_3d_transition()


func _update_3d_transition() -> void:
	var current_ratio: float = clampf((zoom.x - 0.7) / (max_zoom - 0.7), 0.0, 1.0)
	if not is_equal_approx(_zoom_3d_ratio, current_ratio):
		_zoom_3d_ratio = current_ratio
		zoom_3d_changed.emit(_zoom_3d_ratio)


func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_handle_zoom_smoothing(delta)

	if position != _previous_position:
		_previous_position = position
		camera_moved.emit(position)


## Moves camera based on WASD or Arrow keys
func _handle_keyboard_pan(delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		# Scale speed inversely by zoom so movement feels natural at all zoom levels
		position += input_dir * (pan_speed / zoom.x) * delta
		_clamp_position()


## Smoothly interpolates current zoom towards target zoom
func _handle_zoom_smoothing(delta: float) -> void:
	if not zoom.is_equal_approx(_target_zoom):
		zoom = zoom.lerp(_target_zoom, zoom_smoothness * delta)
		camera_zoomed.emit(zoom)
		_update_3d_transition()


func _unhandled_input(event: InputEvent) -> void:
	# 1. Mouse Drag (Right Click or Middle Click)
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_is_dragging = true
			else:
				_is_dragging = false

		# 2. Mouse Wheel Zoom
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_adjust_zoom(zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_adjust_zoom(-zoom_step)

	elif event is InputEventMouseMotion and _is_dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		# Invert mouse motion and divide by zoom
		position -= (mm.relative / zoom.x) * drag_sensitivity
		_clamp_position()


## Adjusts target zoom within bounds
func _adjust_zoom(step: float) -> void:
	var new_val: float = clampf(_target_zoom.x + step, min_zoom, max_zoom)
	_target_zoom = Vector2(new_val, new_val)


## Ensures camera stays within map bounds
func _clamp_position() -> void:
	position.x = clampf(position.x, limit_min.x, limit_max.x)
	position.y = clampf(position.y, limit_min.y, limit_max.y)


## Resets camera position and zoom to default
func reset_camera() -> void:
	position = Vector2.ZERO
	_target_zoom = Vector2.ONE
	zoom = Vector2.ONE
	_is_dragging = false
	_previous_position = Vector2.ZERO
	camera_moved.emit(position)
	camera_zoomed.emit(zoom)
	_update_3d_transition()
