extends Node

## StrategyManager - Turn Manager
## Tracks game turn progression and broadcasts turn transition signals.

signal turn_advanced(new_turn: int)

var current_turn: int = 1


func _ready() -> void:
	turn_advanced.emit(current_turn)


## Advances to the next turn and broadcasts the update
func advance_turn() -> void:
	current_turn += 1
	turn_advanced.emit(current_turn)


## Sets the current turn directly (used when restoring saved games)
func set_current_turn(turn: int) -> void:
	current_turn = turn
	turn_advanced.emit(current_turn)


## Returns current turn count
func get_current_turn() -> int:
	return current_turn
