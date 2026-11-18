# StrategyGame — Roadmap

Full-4X turn-based strategy game built with **Godot 4.7.2** and GDScript.

Status legend: `[x]` done · `[~]` in progress · `[ ]` planned

## Phase 0 — Stabilization

- [x] Baseline of all test suites recorded (5/5 passing).
- [x] Timestamped source backup created.
- [x] Unified test runner (`tests/run_tests.ps1`).
- [x] Git repository + baseline commit (requires Git to be available).
- [x] Documentation: roadmap, art bible, testing guide, attribution.
- [x] Legacy `assert()` suites migrated to the `_check()` pattern.

## Phase 1 — Painterly graphics foundation

- [x] Art bible and asset conventions.
- [x] Painterly terrain artwork (4 terrains, deterministic variants).
- [x] Terrain renderer layers (ground, transitions, decoration) with `--low-gfx` fallback.
- [x] Building illustrations + safe fallbacks.
- [x] Camera pan/zoom with HUD kept stationary (HUD CanvasLayer).
- [x] Painted UI theme and resource icons.
- [x] Phase 1 validation tests + screenshots.

## Phase 2 — Economy depth

- [x] Terrain yields actually generate income (worked tiles by completed buildings).
- [x] Construction time (`build_turns`), demolition refund (50%), upkeep, storage caps.
- [x] Additional buildings: house, market, mine, dock (with painterly artwork & `.tres`).
- [x] Complete economy depth verification test suite (`tests/test_economy_depth.gd`).

## Phase 3 — Save/load and application shell (current)

- Versioned save schema with migrations (v1 exists: turn, resources, buildings, selection).
- Autosave each turn, multiple slots, main menu, settings (audio, UI scale, hotkeys).

## Phase 4 — Population and production chains

- Housing, food upkeep, happiness, growth.
- Worker assignment; wood → planks, ore → tools; shortages and starvation.

## Phase 5 — Units and exploration

- `UnitType` resources: settler, worker, scout, warrior.
- Movement points, `AStarGrid2D` pathfinding with terrain costs, path preview.
- Fog of war, unit selection, settling new cities.

## Phase 6 — Procedural maps and scenarios

- Seeded generation, map sizes, terrain density, water level, scenario presets.

## Phase 7 — Combat and AI

- HP/attack/defense, combat preview, city capture.
- AI opponent that expands, builds, defends and attacks.

## Phase 8 — Research and diplomacy

- Technology tree unlocking buildings/units, eras, wonders.
- Trade routes, AI relations.

## Phase 9 — Victory and onboarding

- Economic / military / score victories, defeat, score screen.
- Tutorial hints, difficulty levels, New Game flow.

## Phase 10 — Polish and release

- Animation and FX pass, audio mix, performance profile, export presets.
- Automated tests in CI, packaging, save-compatibility checks.

## Architecture rules

- Gameplay data lives in `resources/` as `.tres`; UI discovers content by scanning folders.
- Logic (`scripts/core|map|economy|turn|buildings`) is UI-agnostic and headless-testable.
- Scenes wire signals only; no gameplay rules inside UI scripts.
- Tabs, typed GDScript, `##` doc comments, `preload()` instead of global `class_name`.
- Every feature ships with a `tests/test_*.gd` suite using `_check()` / `_finish()`.
