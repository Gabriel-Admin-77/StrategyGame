extends PanelContainer

## StrategyManager - Building 3D Viewer
## Renders interactive real-time 3D models of buildings exported from Blender (.glb)
## inside a dedicated SubViewport with 360° rotation, zoom, and lighting.

const BuildingType = preload("res://scripts/buildings/building_type.gd")
const PaintedTheme = preload("res://scripts/ui/painted_theme.gd")

signal closed

@export var auto_rotate: bool = true
@export var rotate_speed: float = 0.65

var _current_building: BuildingType = null
var _is_dragging: bool = false
var _previous_mouse_pos: Vector2 = Vector2.ZERO

@onready var title_label: Label = get_node_or_null("MarginContainer/VBoxContainer/Header/TitleLabel")
@onready var description_label: Label = get_node_or_null("MarginContainer/VBoxContainer/Header/DescriptionLabel")
@onready var viewport: SubViewport = get_node_or_null("MarginContainer/VBoxContainer/ViewportContainer/SubViewport")
@onready var model_anchor: Node3D = get_node_or_null("MarginContainer/VBoxContainer/ViewportContainer/SubViewport/World/ModelAnchor")
@onready var camera_3d: Camera3D = get_node_or_null("MarginContainer/VBoxContainer/ViewportContainer/SubViewport/World/Camera3D")
@onready var auto_rotate_btn: Button = get_node_or_null("MarginContainer/VBoxContainer/Footer/HBox/AutoRotateButton")
@onready var close_btn: Button = get_node_or_null("MarginContainer/VBoxContainer/Footer/HBox/CloseButton")
@onready var viewport_container: SubViewportContainer = get_node_or_null("MarginContainer/VBoxContainer/ViewportContainer")


func _ready() -> void:
	theme = PaintedTheme.get_theme()
	visible = false
	if close_btn:
		close_btn.pressed.connect(close)
	if auto_rotate_btn:
		auto_rotate_btn.pressed.connect(_on_toggle_auto_rotate)
		_update_auto_rotate_button_text()
	if viewport_container:
		viewport_container.gui_input.connect(_on_viewport_gui_input)


func _process(delta: float) -> void:
	if not visible:
		return
	if auto_rotate and model_anchor and not _is_dragging:
		model_anchor.rotation.y += rotate_speed * delta


func open(building: BuildingType) -> void:
	if building == null:
		return
	_current_building = building
	visible = true

	if title_label:
		title_label.text = "%s - 3D View" % building.display_name
	if description_label:
		description_label.text = building.description

	_load_3d_model(building)


func close() -> void:
	visible = false
	_current_building = null
	_clear_model()
	closed.emit()


func _load_3d_model(building: BuildingType) -> void:
	_clear_model()
	if model_anchor == null:
		return

	var scene_3d: PackedScene = building.get_model_3d()
	if scene_3d != null:
		var instance = scene_3d.instantiate()
		model_anchor.add_child(instance)
		# Normalize default transform
		model_anchor.rotation = Vector3(0.2, 0.4, 0.0)
		instance.position = Vector3(0, -0.4, 0)
		instance.scale = Vector3.ONE * 0.75
	else:
		push_warning("BuildingViewer3D: No 3D model found for %s" % building.display_name)


func _clear_model() -> void:
	if model_anchor:
		for child in model_anchor.get_children():
			child.queue_free()


func _on_toggle_auto_rotate() -> void:
	auto_rotate = not auto_rotate
	_update_auto_rotate_button_text()


func _update_auto_rotate_button_text() -> void:
	if auto_rotate_btn:
		auto_rotate_btn.text = "Auto-Rotate: ON" if auto_rotate else "Auto-Rotate: OFF"


func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = mb.pressed
			_previous_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_adjust_zoom(-0.25)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_adjust_zoom(0.25)

	elif event is InputEventMouseMotion and _is_dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if model_anchor:
			model_anchor.rotation.y += mm.relative.x * 0.012
			model_anchor.rotation.x = clampf(model_anchor.rotation.x + mm.relative.y * 0.012, -0.6, 1.2)


func _adjust_zoom(step: float) -> void:
	if camera_3d:
		camera_3d.position.z = clampf(camera_3d.position.z + step, 2.5, 7.5)
