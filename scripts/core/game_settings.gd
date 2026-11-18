extends RefCounted

## StrategyManager - Runtime Settings
## Reads launch options that affect rendering and tooling.

const LOW_GFX_FLAG: String = "--low-gfx"


## Returns true when the project was started with "-- --low-gfx".
## Low graphics keeps the procedural flat renderer so headless tests and
## low-end machines never depend on imported art files.
static func is_low_gfx() -> bool:
	if OS.get_cmdline_user_args().has(LOW_GFX_FLAG):
		return true
	return OS.get_cmdline_args().has(LOW_GFX_FLAG)
