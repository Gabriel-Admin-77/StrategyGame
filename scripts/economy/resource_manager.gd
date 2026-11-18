extends Node

## StrategyManager - Resource Manager
## Manages player resource stockpiles, income generation, and spending validation.

signal resources_updated(current_resources: Dictionary)

# Current resource stockpile
var resources: Dictionary = {
	"gold": 100,
	"wood": 50,
	"food": 30
}

# Base income awarded at the end of each turn
var base_income: Dictionary = {
	"gold": 10,
	"wood": 5,
	"food": 5
}


func _ready() -> void:
	emit_update()


## Emits signal with a duplicate of current resources to avoid external mutation
func emit_update() -> void:
	resources_updated.emit(resources.duplicate())


## Sets the resource stockpile directly (used when restoring saved games)
func set_resources(new_resources: Dictionary) -> void:
	resources = new_resources.duplicate()
	emit_update()


## Adds specified resources to the stockpile
func add_resources(amounts: Dictionary) -> void:
	for res_name: String in amounts:
		if resources.has(res_name):
			resources[res_name] += amounts[res_name]
	emit_update()


## Checks if player can afford the given cost
func can_afford(cost: Dictionary) -> bool:
	for res_name: String in cost:
		if resources.get(res_name, 0) < cost[res_name]:
			return false
	return true


## Deducts resources if affordable. Returns true if successful.
func spend_resources(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false

	for res_name: String in cost:
		resources[res_name] -= cost[res_name]

	emit_update()
	return true


## Awards base income on end-of-turn
func process_turn_income() -> void:
	add_resources(base_income)


## Returns a copy of current resource totals
func get_resources() -> Dictionary:
	return resources.duplicate()
