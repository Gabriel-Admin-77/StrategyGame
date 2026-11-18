extends PanelContainer

## StrategyManager - Save & Load Dialog
## Interactive modal for browsing and selecting named save slots
## (Autosave, Slot 1, Slot 2, Slot 3) for saving or loading.

const PaintedTheme = preload("res://scripts/ui/painted_theme.gd")

signal closed
signal slot_action_confirmed(mode: String, slot_id: String)

enum Mode { SAVE, LOAD }

var current_mode: Mode = Mode.SAVE
var save_manager: Node = null

@onready var title_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TitleLabel")
@onready var slots_container: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/SlotsContainer")
@onready var close_button: Button = get_node_or_null("MarginContainer/VBoxContainer/CloseButton")


func _ready() -> void:
	theme = PaintedTheme.get_theme()
	if close_button:
		close_button.pressed.connect(_on_close_pressed)


## Configures the dialog for either SAVE or LOAD mode and refreshes slot list.
func open(mode: Mode, manager: Node) -> void:
	current_mode = mode
	save_manager = manager
	visible = true

	if title_label:
		title_label.text = "SAVE GAME" if mode == Mode.SAVE else "LOAD GAME"

	refresh_slots()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


## Rebuilds the UI list of slot entries based on current SaveManager data
func refresh_slots() -> void:
	if slots_container == null or save_manager == null:
		return

	for child: Node in slots_container.get_children():
		child.queue_free()

	var slots: Array[String] = ["autosave", "slot_1", "slot_2", "slot_3"]
	for slot_id: String in slots:
		var meta: Dictionary = save_manager.get_slot_metadata(slot_id)
		var slot_card: PanelContainer = _build_slot_card(slot_id, meta)
		slots_container.add_child(slot_card)


func _build_slot_card(slot_id: String, meta: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	# Slot Title & Info
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var slot_title := Label.new()
	var display_name: String = "Autosave" if slot_id == "autosave" else slot_id.replace("_", " ").capitalize()
	slot_title.text = display_name
	slot_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(slot_title)

	var info_label := Label.new()
	info_label.add_theme_font_size_override("font_size", 12)
	if meta.get("exists", false):
		var time_str: String = meta.get("timestamp", "")
		var turn_num: int = meta.get("turn", 1)
		var b_count: int = meta.get("buildings_count", 0)
		info_label.text = "Turn: %d | Buildings: %d | %s" % [turn_num, b_count, time_str]
		info_label.modulate = Color(0.85, 0.85, 0.85)
	else:
		info_label.text = "[ Empty Slot ]"
		info_label.modulate = Color(0.6, 0.6, 0.6)
	vbox.add_child(info_label)

	# Action Button
	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(90, 30)
	if current_mode == Mode.SAVE:
		action_btn.text = "Save"
		# Disallow manual overwrite of autosave slot
		if slot_id == "autosave":
			action_btn.disabled = true
			action_btn.tooltip_text = "Autosave is updated automatically on End Turn."
		else:
			action_btn.pressed.connect(_on_slot_action.bind(slot_id))
	else: # Mode.LOAD
		action_btn.text = "Load"
		if not meta.get("exists", false):
			action_btn.disabled = true
		else:
			action_btn.pressed.connect(_on_slot_action.bind(slot_id))
	hbox.add_child(action_btn)

	return card


func _on_slot_action(slot_id: String) -> void:
	if save_manager == null:
		return

	if current_mode == Mode.SAVE:
		save_manager.save_to_slot(slot_id)
		slot_action_confirmed.emit("save", slot_id)
	else:
		save_manager.load_from_slot(slot_id)
		slot_action_confirmed.emit("load", slot_id)

	refresh_slots()
	visible = false
	closed.emit()
