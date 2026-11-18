extends RefCounted

## StrategyManager - Painted UI Theme
## Builds the shared parchment/walnut/gold theme used by every HUD control.

const COLOR_PARCHMENT: Color = Color("#e6d3ae")
const COLOR_PARCHMENT_DARK: Color = Color("#d5bf95")
const COLOR_WALNUT: Color = Color("#4a3524")
const COLOR_WALNUT_LIGHT: Color = Color("#6b4f37")
const COLOR_INK: Color = Color("#2a2119")
const COLOR_CREAM: Color = Color("#f3e8d2")
const COLOR_GOLD: Color = Color("#d8b25a")
const COLOR_GOLD_BRIGHT: Color = Color("#f0c75e")
const COLOR_DISABLED: Color = Color("#b7a88c")
const COLOR_PANEL_DARK: Color = Color("#2c3a34")

const FONT_SIZE_NORMAL: int = 15
const FONT_SIZE_SMALL: int = 13
const FONT_SIZE_TITLE: int = 18
const CORNER_RADIUS: int = 6
const BORDER_WIDTH: int = 2

static var _cached_theme: Theme = null


## Returns the shared theme instance (built once).
static func get_theme() -> Theme:
	if _cached_theme == null:
		_cached_theme = _build()
	return _cached_theme


static func _build() -> Theme:
	var theme := Theme.new()

	theme.set_color("font_color", "Label", COLOR_INK)
	theme.set_font_size("font_size", "Label", FONT_SIZE_NORMAL)

	theme.set_stylebox("panel", "PanelContainer", make_panel_box())
	theme.set_stylebox("panel", "Panel", make_panel_box())
	theme.set_stylebox("panel", "PopupMenu", make_panel_box())

	theme.set_stylebox("normal", "Button", make_button_box(COLOR_PARCHMENT, COLOR_WALNUT))
	theme.set_stylebox("hover", "Button", make_button_box(COLOR_GOLD_BRIGHT, COLOR_WALNUT_LIGHT))
	theme.set_stylebox("pressed", "Button", make_button_box(COLOR_PARCHMENT_DARK, COLOR_WALNUT, true))
	theme.set_stylebox("disabled", "Button", make_button_box(COLOR_DISABLED, COLOR_WALNUT_LIGHT))
	theme.set_stylebox("focus", "Button", make_focus_box())
	theme.set_color("font_color", "Button", COLOR_INK)
	theme.set_color("font_hover_color", "Button", COLOR_INK)
	theme.set_color("font_pressed_color", "Button", COLOR_WALNUT)
	theme.set_color("font_disabled_color", "Button", Color(0.45, 0.40, 0.33))
	theme.set_font_size("font_size", "Button", FONT_SIZE_NORMAL)

	theme.set_stylebox("panel", "TooltipPanel", make_dark_box())
	theme.set_color("font_color", "TooltipLabel", COLOR_CREAM)

	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_constant("separation", "VBoxContainer", 8)

	theme.set_color("font_color", "RichTextLabel", COLOR_INK)
	return theme


static func make_panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_PARCHMENT
	box.border_color = COLOR_WALNUT
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.set_content_margin_all(12)
	box.shadow_color = Color(0.08, 0.05, 0.02, 0.35)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	return box


static func make_button_box(fill: Color, border: Color, pressed: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	if pressed:
		box.content_margin_top = 5.0
		box.content_margin_bottom = 3.0
	return box


static func make_focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = COLOR_GOLD
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(4)
	return box


static func make_dark_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_PANEL_DARK
	box.border_color = COLOR_WALNUT
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.set_content_margin_all(10)
	return box
