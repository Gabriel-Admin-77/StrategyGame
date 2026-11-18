extends RefCounted

## StrategyManager - Game Settings Manager
## Manages persistent user preferences (audio volume, UI scale, fullscreen)
## saved to user://settings.cfg, and reads command-line runtime flags.

const SETTINGS_FILE: String = "user://settings.cfg"
const LOW_GFX_FLAG: String = "--low-gfx"

static var master_volume: float = 80.0
static var music_volume: float = 70.0
static var sfx_volume: float = 80.0
static var fullscreen: bool = false
static var ui_scale: float = 1.0


## Returns true when the project was started with "-- --low-gfx".
static func is_low_gfx() -> bool:
	if OS.get_cmdline_user_args().has(LOW_GFX_FLAG):
		return true
	return OS.get_cmdline_args().has(LOW_GFX_FLAG)


## Loads settings from disk if the config file exists
static func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		return

	var config := ConfigFile.new()
	var err: Error = config.load(SETTINGS_FILE)
	if err != OK:
		push_warning("GameSettings: Failed to load %s (Error %d)" % [SETTINGS_FILE, err])
		return

	master_volume = float(config.get_value("audio", "master_volume", 80.0))
	music_volume = float(config.get_value("audio", "music_volume", 70.0))
	sfx_volume = float(config.get_value("audio", "sfx_volume", 80.0))
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	ui_scale = float(config.get_value("display", "ui_scale", 1.0))

	apply_display_settings()


## Saves current settings to user://settings.cfg
static func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "ui_scale", ui_scale)

	var err: Error = config.save(SETTINGS_FILE)
	if err != OK:
		push_warning("GameSettings: Failed to save %s (Error %d)" % [SETTINGS_FILE, err])
		return false
	return true


## Applies display preferences to the current window
static func apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return

	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
