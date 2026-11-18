extends Node

## StrategyManager - Resource Manager
## Manages player resource stockpiles, income generation, spending validation,
## storage caps, and upkeep deductions.

signal resources_updated(current_resources: Dictionary)
signal treasury_deficit(resource_name: String, shortage: int)

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

# Base storage caps per resource
var base_capacity: Dictionary = {
	"gold": 250,
	"wood": 150,
	"food": 100
}

# Extra capacity added by buildings (populated externally)
var bonus_capacity: Dictionary = {}


func _ready() -> void:
	emit_update()


## Emits signal with a duplicate of current resources to avoid external mutation
func emit_update() -> void:
	resources_updated.emit(resources.duplicate())


## Returns the effective maximum storage for a resource.
func get_capacity(res_name: String) -> int:
	return base_capacity.get(res_name, 9999) + bonus_capacity.get(res_name, 0)


## Returns a dictionary of all effective capacities.
func get_all_capacities() -> Dictionary:
	var caps: Dictionary = {}
	for res_name: String in base_capacity:
		caps[res_name] = get_capacity(res_name)
	return caps


## Sets the resource stockpile directly (used when restoring saved games)
func set_resources(new_resources: Dictionary) -> void:
	resources = new_resources.duplicate()
	emit_update()


## Adds specified resources to the stockpile, clamped to capacity.
func add_resources(amounts: Dictionary) -> void:
	for res_name: String in amounts:
		if resources.has(res_name):
			resources[res_name] += amounts[res_name]
			var cap: int = get_capacity(res_name)
			if resources[res_name] > cap:
				resources[res_name] = cap
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


## Deducts upkeep costs. If a resource drops below zero it is clamped to 0
## and a treasury_deficit signal is emitted with the shortage amount.
func deduct_upkeep(costs: Dictionary) -> void:
	for res_name: String in costs:
		var amount: int = costs[res_name]
		if not resources.has(res_name):
			continue
		resources[res_name] -= amount
		if resources[res_name] < 0:
			var shortage: int = -resources[res_name]
			resources[res_name] = 0
			treasury_deficit.emit(res_name, shortage)
	emit_update()


## Returns a copy of current resource totals
func get_resources() -> Dictionary:
	return resources.duplicate()
