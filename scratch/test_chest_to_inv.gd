extends SceneTree

const InventoryModelType = preload("res://scripts/data/inventory_model.gd")
const RING_DATA = preload("res://data/items/ring_of_strength.tres")

var failures: Array[String] = []

func _init() -> void:
	print("--- Debugging Chest -> Inventory Drag ---")
	
	var main_scene = load("res://scenes/main.tscn")
	var main_inst = main_scene.instantiate()
	root.add_child(main_inst)
	
	await process_frame
	await process_frame
	
	var player = main_inst.find_child("Player", true, false)
	var inv_ui = player.get_node_or_null("InventoryUI")
	inv_ui._open()
	await process_frame
	
	var chest = main_inst.find_child("GothicChest", true, false)
	chest.open_chest()
	await process_frame
	var chest_ui = main_inst.find_child("ChestUI", true, false)
	
	var chest_slot_0 = chest_ui.grid_slots[0]
	var player_grid_0 = inv_ui.grid_slots[0]
	var item_in_chest = chest_slot_0.item
	
	print("Chest slot 0 item: ", item_in_chest)
	print("Player grid 0 item: ", player_grid_0.item)
	
	print("is_my_slot(source): ", inv_ui._is_my_slot(chest_slot_0))
	print("is_my_slot(target): ", inv_ui._is_my_slot(player_grid_0))
	print("chest_ui is_open: ", chest_ui.is_open)
	print("chest_ui player_ref: ", chest_ui.player_ref)
	
	inv_ui._transfer_item(chest_slot_0, player_grid_0)
	
	print("AFTER TRANSFER:")
	print("Player grid 0 item: ", player_grid_0.item)
	print("Chest slot 0 item: ", chest_slot_0.item)
	
	quit(0)
