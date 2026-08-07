extends SceneTree

const InventoryModelType = preload("res://scripts/data/inventory_model.gd")
const ItemDataType = preload("res://scripts/data/item_data.gd")
const RING_DATA = preload("res://data/items/ring_of_strength.tres")

var failures: Array[String] = []

func _init() -> void:
	print("--- Running Ring Tests ---")
	
	# Test 1: InventoryModel accepts ring in grid
	var categories := {
		"weapon_1": "weapon",
		"weapon_2": "weapon",
		"helmet": "helmet",
		"armor": "armor",
		"belt": "belt",
		"amulet": "amulet",
		"ring_1": "ring",
		"ring_2": "ring",
		"accessory_1": "accessory",
		"accessory_2": "accessory",
	}
	var model = InventoryModelType.new(60, categories, 10)
	var ring_item := RING_DATA.to_inventory_item()
	print("Ring item dict: ", ring_item)
	
	_check(model.add_item(ring_item), "Ring must be added to inventory model")
	_check(model.items[0].get("id") == "ring_of_strength", "Ring must be at index 0")
	
	# Test 2: Equip ring from grid 0 to ring_1
	_check(model.can_transfer(model.grid_ref(0), model.equipment_ref("ring_1")), "Can transfer ring from grid 0 to ring_1")
	_check(model.transfer(model.grid_ref(0), model.equipment_ref("ring_1")), "Transfer ring from grid 0 to ring_1 must succeed")
	_check(model.equipment["ring_1"].get("id") == "ring_of_strength", "ring_1 must contain ring_of_strength")
	_check(model.items[0].is_empty(), "grid slot 0 must be empty after equip")
	
	# Test 3: Transfer ring from ring_1 to ring_2
	_check(model.can_transfer(model.equipment_ref("ring_1"), model.equipment_ref("ring_2")), "Can transfer ring from ring_1 to ring_2")
	_check(model.transfer(model.equipment_ref("ring_1"), model.equipment_ref("ring_2")), "Transfer ring from ring_1 to ring_2 must succeed")
	_check(model.equipment["ring_2"].get("id") == "ring_of_strength", "ring_2 must contain ring_of_strength")
	_check(model.equipment["ring_1"].is_empty(), "ring_1 must be empty after moving to ring_2")
	
	# Test 4: Transfer ring from ring_2 back to grid index 5
	_check(model.can_transfer(model.equipment_ref("ring_2"), model.grid_ref(5)), "Can transfer ring from ring_2 to grid 5")
	_check(model.transfer(model.equipment_ref("ring_2"), model.grid_ref(5)), "Transfer ring from ring_2 to grid 5 must succeed")
	_check(model.items[5].get("id") == "ring_of_strength", "grid 5 must contain ring_of_strength")
	_check(model.equipment["ring_2"].is_empty(), "ring_2 must be empty after unequip")
	
	# Test 5: Test chest_ui drop validation and transfer logic between chest and player ring slot!
	var chest_model = InventoryModelType.new(169, {}, 13)
	chest_model.add_item(ring_item)
	_check(chest_model.items[0].get("id") == "ring_of_strength", "Chest must contain ring")
	
	if failures.is_empty():
		print("ALL RING MODEL TESTS PASSED!")
		quit(0)
	else:
		print("RING MODEL TESTS FAILED: ", failures)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		print("FAIL: ", msg)
