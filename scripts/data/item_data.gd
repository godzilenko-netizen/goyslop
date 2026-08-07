class_name ItemData
extends Resource

@export var item_id: String = "item"
@export var display_name: String = "Предмет"
@export_multiline var description: String = ""
@export_enum("common", "magic", "rare", "unique") var rarity: String = "common"
@export var equipment_slot: String = ""
@export var grid_size: Vector2i = Vector2i.ONE
@export var armor: int = 0
@export var max_stack: int = 1
@export var icon: Texture2D
@export var icon_path: String = ""


func to_inventory_item(quantity: int = 1) -> Dictionary:
	var path_str := icon_path if not icon_path.is_empty() else (icon.resource_path if icon else "")
	return {
		"id": item_id,
		"name": display_name,
		"description": description,
		"rarity": rarity,
		"slot": equipment_slot,
		"grid_size": Vector2i(maxi(grid_size.x, 1), maxi(grid_size.y, 1)),
		"armor": armor,
		"quantity": maxi(quantity, 1),
		"max_stack": maxi(max_stack, 1),
		"icon": path_str,
	}


func rarity_name() -> String:
	return {
		"common": "Обычный",
		"magic": "Магический",
		"rare": "Редкий",
		"unique": "Уникальный",
	}.get(rarity, "Обычный")
