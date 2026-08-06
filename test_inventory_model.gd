extends SceneTree

const InventoryModelType = preload("res://scripts/data/inventory_model.gd")

var failures: Array[String] = []


func _init() -> void:
	var model = InventoryModelType.new(2, {"weapon": "weapon"})
	_check(model.add_item({
		"id": "potion",
		"name": "Potion",
		"quantity": 4,
		"max_stack": 3,
	}), "Stackable item must fit across available slots")
	_check(int(model.items[0].get("quantity", 0)) == 3, "First stack must be filled to max_stack")
	_check(int(model.items[1].get("quantity", 0)) == 1, "Remainder must be placed in the next slot")

	var state_before_failure: Dictionary = model.serialize()
	_check(not model.add_item({"id": "sword", "name": "Sword", "slot": "weapon"}), "Full inventory must reject an item")
	_check(model.serialize() == state_before_failure, "Rejected additions must not partially mutate inventory")

	var equipment_model = InventoryModelType.new(1, {"weapon": "weapon"})
	_check(equipment_model.add_item({"id": "sword", "name": "Sword", "slot": "weapon"}), "Weapon must enter storage")
	_check(equipment_model.transfer(equipment_model.grid_ref(0), equipment_model.equipment_ref("weapon")), "Weapon must equip into weapon slot")
	_check(str(equipment_model.equipment["weapon"].get("id", "")) == "sword", "Equipped weapon must be stored by the model")

	var restored = InventoryModelType.new(1, {"weapon": "weapon"})
	restored.load_state(equipment_model.serialize())
	_check(restored.serialize() == equipment_model.serialize(), "Serialized inventory must round-trip")

	if failures.is_empty():
		print("TEST PASSED: transactional inventory model and equipment")
		quit(0)
	else:
		print("TEST FAILED: %d inventory model failure(s)" % failures.size())
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TEST: " + message)
