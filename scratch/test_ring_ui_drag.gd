extends SceneTree

const InventoryModelType = preload("res://scripts/data/inventory_model.gd")
const RING_DATA = preload("res://data/items/ring_of_strength.tres")

var failures: Array[String] = []

func _init() -> void:
	print("--- Running Complete UI Ring Drag & Drop Tests ---")
	
	var main_scene = load("res://scenes/main.tscn")
	var main_inst = main_scene.instantiate()
	root.add_child(main_inst)
	
	await process_frame
	await process_frame
	
	var player = main_inst.find_child("Player", true, false)
	var inv_ui = player.get_node_or_null("InventoryUI")
	inv_ui.open()
	await process_frame
	
	var ring_dict = RING_DATA.to_inventory_item()
	inv_ui.add_item(ring_dict)
	
	var grid_slot_0 = inv_ui.grid_slots[0]
	var ring_slot_1 = inv_ui.equipment_slots["ring_1"]
	var ring_slot_2 = inv_ui.equipment_slots["ring_2"]
	
	# Test 1: Grid Slot 0 -> Ring Slot 1
	_check(inv_ui._can_drop_on_slot(grid_slot_0, ring_slot_1, ring_dict), "UI drop grid -> ring_1 should be valid")
	inv_ui._transfer_item(grid_slot_0, ring_slot_1)
	_check(ring_slot_1.item.get("id") == "ring_of_strength", "ring_1 should hold ring")
	_check(grid_slot_0.item.is_empty(), "grid_slot_0 should be empty")
	
	# Test 2: Ring Slot 1 -> Ring Slot 2
	_check(inv_ui._can_drop_on_slot(ring_slot_1, ring_slot_2, ring_dict), "UI drop ring_1 -> ring_2 should be valid")
	inv_ui._transfer_item(ring_slot_1, ring_slot_2)
	_check(ring_slot_2.item.get("id") == "ring_of_strength", "ring_2 should hold ring")
	_check(ring_slot_1.item.is_empty(), "ring_1 should be empty")
	
	# Test 3: Ring Slot 2 -> Grid Slot 5
	var grid_slot_5 = inv_ui.grid_slots[5]
	_check(inv_ui._can_drop_on_slot(ring_slot_2, grid_slot_5, ring_dict), "UI drop ring_2 -> grid_5 should be valid")
	inv_ui._transfer_item(ring_slot_2, grid_slot_5)
	_check(grid_slot_5.item.get("id") == "ring_of_strength", "grid_5 should hold ring")
	_check(ring_slot_2.item.is_empty(), "ring_2 should be empty")
	
	# Test 4: Chest interactions
	var chest = main_inst.find_child("GothicChest", true, false)
	chest.open_chest()
	await process_frame
	var chest_ui = main_inst.find_child("ChestUI", true, false)
	
	# Empty chest slot 10
	var chest_slot_10 = chest_ui.grid_slots[10]
	_check(chest_slot_10.item.is_empty(), "chest_slot_10 should be empty")
	
	# Player grid_5 -> Chest slot 10
	_check(chest_ui._can_drop_on_slot(grid_slot_5, chest_slot_10, ring_dict), "Chest UI drop grid_5 -> chest_10 should be valid")
	chest_ui._transfer_item(grid_slot_5, chest_slot_10)
	_check(chest_slot_10.item.get("id") == "ring_of_strength", "chest_10 should hold ring")
	_check(grid_slot_5.item.is_empty(), "grid_5 should be empty")
	
	# Chest slot 10 -> Player ring_1
	_check(chest_ui._can_drop_on_slot(chest_slot_10, ring_slot_1, ring_dict), "Chest UI drop chest_10 -> ring_1 should be valid")
	chest_ui._transfer_item(chest_slot_10, ring_slot_1)
	_check(ring_slot_1.item.get("id") == "ring_of_strength", "ring_1 should hold ring")
	_check(chest_slot_10.item.is_empty(), "chest_10 should be empty")
	
	# Player ring_1 -> Chest slot 10
	_check(chest_ui._can_drop_on_slot(ring_slot_1, chest_slot_10, ring_dict), "Chest UI drop ring_1 -> chest_10 should be valid")
	chest_ui._transfer_item(ring_slot_1, chest_slot_10)
	_check(chest_slot_10.item.get("id") == "ring_of_strength", "chest_10 should hold ring from ring_1")
	_check(ring_slot_1.item.is_empty(), "ring_1 should be empty")
	
	if failures.is_empty():
		print("SUCCESS: ALL COMPLETE UI RING DRAG & DROP TESTS PASSED PERFECTLY!")
		quit(0)
	else:
		print("FAIL: ", failures)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		print("FAIL CHECK: ", msg)
