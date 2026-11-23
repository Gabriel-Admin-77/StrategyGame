extends SceneTree

## Test suite for Step C: 3D Models, Zoom Transition & 3D Viewer

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
	print("=== Running Step C (3D Integration) Tests ===")

	# 1. Verify all 7 buildings have resolvable 3D models
	var building_ids = ["farm", "lumber_mill", "mine", "market", "dock", "workshop", "house"]
	for b_id in building_ids:
		var path: String = "res://resources/building_types/%s.tres" % b_id
		var building = load(path)
		_check(building != null, "Building resource %s.tres loads" % b_id)
		if building:
			var model_scene = building.get_model_3d()
			_check(model_scene != null, "%s has valid 3D model scene" % b_id)

	# 2. Verify Map has BuildingViewer3D in HUD
	var map_scene: PackedScene = load("res://scenes/map/map.tscn")
	var map = map_scene.instantiate()
	root.add_child(map)
	await process_frame

	var viewer = map.get_node_or_null("HUD/BuildingViewer3D")
	_check(viewer != null, "BuildingViewer3D exists in Map HUD")
	_check(viewer.visible == false, "BuildingViewer3D starts hidden")

	# 3. Test opening BuildingViewer3D with Farm
	var farm = load("res://resources/building_types/farm.tres")
	viewer.open(farm)
	await process_frame
	_check(viewer.visible == true, "BuildingViewer3D becomes visible when opened")
	_check(viewer.model_anchor.get_child_count() > 0, "ModelAnchor holds instanced 3D model")
	_check("Farm" in viewer.title_label.text, "Title reflects Farm name")

	# 4. Test closing BuildingViewer3D
	viewer.close()
	await process_frame
	_check(viewer.visible == false, "BuildingViewer3D closes properly")

	# 5. Verify Camera 3D ratio calculation & signal emission
	var camera = map.get_node_or_null("StrategyCamera")
	_check(camera != null, "StrategyCamera exists")
	camera.zoom = Vector2(0.5, 0.5)
	camera._update_3d_transition()
	_check(camera.get_3d_ratio() == 0.0, "At zoom <= 0.7, 3D ratio is 0.0 (got %f)" % camera.get_3d_ratio())

	camera.zoom = Vector2(2.0, 2.0)
	camera._update_3d_transition()
	_check(camera.get_3d_ratio() == 1.0, "At max zoom (2.0), 3D ratio is 1.0 (got %f)" % camera.get_3d_ratio())

	# 6. Verify TileInfoPanel View3DButton integration
	var panel = map.tile_info_panel
	_check(panel != null, "TileInfoPanel exists")
	var info = {"name": "Plains", "color": Color.GREEN, "can_build": true}
	panel.display_tile(Vector2i(0, 2), info, farm)
	_check(panel.view_3d_button != null and panel.view_3d_button.visible == true, "View 3D button is visible when tile has a building")

	panel.display_tile(Vector2i(0, 2), info, null)
	_check(panel.view_3d_button.visible == false, "View 3D button is hidden when tile has no building")

	map.queue_free()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL STEP C 3D INTEGRATION TESTS PASSED 100%")
		quit(0)
	else:
		printerr("STEP C TESTS FAILED: %d failure(s)" % _failures)
		quit(1)
