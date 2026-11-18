extends SceneTree

## Headless test for StrategyCamera:
## Panning (keyboard & mouse drag), zooming, boundary clamping, and HUD synchronization.

var _failures: int = 0


func _init() -> void:
	_run_test()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		printerr("FAIL: ", message)


func _run_test() -> void:
	var map_scene: PackedScene = load("res://scenes/map/map.tscn")
	var map = map_scene.instantiate()
	root.add_child(map)
	await process_frame

	var camera = map.get_node_or_null("StrategyCamera")
	var top_bar = map.top_bar
	var panel = map.tile_info_panel

	_check(camera != null, "StrategyCamera exists as a child of Map")
	_check(camera is Camera2D, "StrategyCamera inherits from Camera2D")
	_check(camera.enabled, "Camera is enabled")
	_check(camera.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT, "Camera uses FIXED_TOP_LEFT anchor (0)")

	if camera == null:
		_finish()
		return

	# Step 1: Initial state verification
	_check(camera.position == Vector2.ZERO, "Initial camera position is (0, 0)")
	_check(camera.zoom == Vector2.ONE, "Initial camera zoom is (1, 1)")

	# Step 2: Mouse drag panning test
	var press_event = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_RIGHT
	press_event.pressed = true
	press_event.position = Vector2(300, 300)
	camera._unhandled_input(press_event)

	var motion_event = InputEventMouseMotion.new()
	motion_event.relative = Vector2(-60, -40)
	camera._unhandled_input(motion_event)

	_check(camera.position.x == 60.0 and camera.position.y == 40.0, "Right-click drag panned camera to (60, 40)")

	var release_event = InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_RIGHT
	release_event.pressed = false
	release_event.position = Vector2(240, 260)
	camera._unhandled_input(release_event)

	# Verify TopBar and InfoPanel are in HUD CanvasLayer
	_check(top_bar != null and top_bar.is_inside_tree(), "TopBar active in HUD")
	_check(panel != null and panel.is_inside_tree(), "TileInfoPanel active in HUD")

	# Step 3: Mouse Wheel Zoom test
	var zoom_in = InputEventMouseButton.new()
	zoom_in.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_in.pressed = true
	camera._unhandled_input(zoom_in)
	_check(camera._target_zoom.x > 1.0, "Wheel up increased target zoom (got %s)" % str(camera._target_zoom))

	# Test zoom bounds
	for i in range(25):
		camera._adjust_zoom(0.2)
	_check(camera._target_zoom.x <= camera.max_zoom, "Zoom clamped at max_zoom (%s <= %s)" % [camera._target_zoom.x, camera.max_zoom])

	for i in range(35):
		camera._adjust_zoom(-0.2)
	_check(camera._target_zoom.x >= camera.min_zoom - 0.001, "Zoom clamped at min_zoom (%s >= %s)" % [camera._target_zoom.x, camera.min_zoom])

	# Step 4: Boundary clamping test
	camera.position = Vector2(99999, 99999)
	camera._clamp_position()
	_check(camera.position.x == camera.limit_max.x and camera.position.y == camera.limit_max.y, "Position clamped at limit_max")

	camera.position = Vector2(-99999, -99999)
	camera._clamp_position()
	_check(camera.position.x == camera.limit_min.x and camera.position.y == camera.limit_min.y, "Position clamped at limit_min")

	# Step 5: Reset camera test
	camera.reset_camera()
	_check(camera.position == Vector2.ZERO, "reset_camera() reset position to (0, 0)")
	_check(camera.zoom == Vector2.ONE, "reset_camera() reset zoom to (1, 1)")

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL STRATEGY CAMERA TESTS PASSED 100%")
		quit(0)
	else:
		printerr("%d STRATEGY CAMERA TEST(S) FAILED" % _failures)
		quit(1)
