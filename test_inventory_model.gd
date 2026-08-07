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

	var sized_model = InventoryModelType.new(12, {"armor": "armor"}, 4)
	var leather_armor := {
		"id": "leather_armor",
		"name": "Leather Armor",
		"slot": "armor",
		"grid_size": Vector2i(2, 3),
	}
	_check(sized_model.add_item(leather_armor), "2x3 armor must fit into a 4x3 grid")
	_check(sized_model.get_anchor_index(0) == 0, "Large item must keep an anchor cell")
	for occupied_cell in [0, 1, 4, 5, 8, 9]:
		_check(sized_model.get_anchor_index(occupied_cell) == 0, "Large item footprint must reserve every covered cell")
	_check(not sized_model.can_place_at(3, leather_armor), "2x3 armor must not cross the right grid edge")
	_check(sized_model.transfer(sized_model.grid_ref(0), sized_model.equipment_ref("armor")), "Large armor must equip")
	_check(sized_model.get_anchor_index(0) == -1, "Equipping must release the full 2x3 footprint")
	_check(sized_model.transfer(sized_model.equipment_ref("armor"), sized_model.grid_ref(2)), "Large armor must return to another valid 2x3 position")
	_check(sized_model.get_anchor_index(10) == 2, "Moved large item must reserve its new footprint")
	_check(not sized_model.can_transfer(sized_model.grid_ref(2), sized_model.grid_ref(3)), "Transfer preview must reject an item crossing the grid edge")
	var removed_armor: Dictionary = sized_model.remove_item(sized_model.grid_ref(2))
	_check(str(removed_armor.get("id", "")) == "leather_armor", "Removing a large item must return its data")
	_check(sized_model.get_anchor_index(10) == -1, "Removing a large item must release its full footprint")

	var duplicate_model = InventoryModelType.new(60, {"armor": "armor"}, 10)
	var non_stackable_armor := leather_armor.duplicate(true)
	non_stackable_armor["max_stack"] = 1
	_check(duplicate_model.add_item(non_stackable_armor), "First non-stackable armor must fit")
	_check(duplicate_model.add_item(non_stackable_armor), "Second identical non-stackable armor must also fit")
	_check(duplicate_model.get_anchor_index(0) == 0, "First identical armor must keep its own anchor")
	_check(duplicate_model.get_anchor_index(2) == 2, "Second identical armor must use a separate anchor")

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
