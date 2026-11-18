# Testing Guide

## Run everything

```powershell
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
```

Options:

| Flag | Effect |
|---|---|
| `-GodotExe <path>` | Use a specific Godot console executable |
| `-LowGraphics` | Pass `-- --low-gfx` to the project (procedural renderer) |
| `-SkipSmoke` | Skip the main-scene startup check |

The runner executes every `tests/test_*.gd` sequentially, then boots
`scenes/main/main.tscn` for 20 frames. It prints a summary and exits non-zero if
any suite fails, so it can be used in CI unchanged.

## Single suite

```powershell
& "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" `
    --headless --path "E:\Godot_v4.7.2-stable_win64.exe\strategy-game" `
    --script res://tests/test_building_system.gd
```

## Writing a suite

`tests/test_*.gd` must extend `SceneTree` and exit explicitly:

```gdscript
extends SceneTree

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
    var scene: PackedScene = load("res://scenes/main/main.tscn")
    var instance = scene.instantiate()
    root.add_child(instance)
    await process_frame          # let _ready() and signal wiring run
    _check(instance != null, "scene instantiates")
    _finish()

func _finish() -> void:
    if _failures == 0:
        print("ALL TESTS PASSED")
        quit(0)
    else:
        printerr("%d TEST(S) FAILED" % _failures)
        quit(1)
```

Rules of thumb:

- **Code 0 = success, code 1 = failure.** Never `quit(0)` after a failed check.
- `await process_frame` after `add_child` so `_ready()` and connections settle.
- Prefer public methods (`place_building`, `set_pending_building`) over private
  ones; `_handle_tile_click` is acceptable for input simulation because the real
  input path needs a window.
- Use constants (`MAP_OFFSET`, `TILE_SIZE`) lifted from `map.gd` rather than
  hard-coded pixel numbers in new tests.
- Clean up files written to `user://` at the end of the suite.
- Headless runs cannot render; visual regressions are checked with screenshots
  from a windowed run (`tests/screenshots/`, git-ignored).
