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

@export_group("Weapon Data")
@export var weapon_damage: int = 0
@export var weapon_attack_icon: Texture2D
@export var is_weapon: bool = false

@export_group("Attribute Requirements")
## Минимальная Сила для экипировки (0 = нет требования)
@export var req_str: int = 0
## Минимальная Ловкость для экипировки (0 = нет требования)
@export var req_dex: int = 0
## Минимальный Интеллект для экипировки (0 = нет требования)
@export var req_int: int = 0

@export_group("Attribute Scaling")
## Масштабирование урона от Силы (0.0 = не масштабируется)
@export var str_scaling: float = 0.0
## Масштабирование урона от Ловкости
@export var dex_scaling: float = 0.0
## Масштабирование урона от Интеллекта
@export var int_scaling: float = 0.0


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
		# Attribute requirements
		"req_str": req_str,
		"req_dex": req_dex,
		"req_int": req_int,
		# Attribute scaling coefficients
		"str_scaling": str_scaling,
		"dex_scaling": dex_scaling,
		"int_scaling": int_scaling,
		# Weapon data
		"is_weapon": is_weapon,
		"weapon_damage": weapon_damage,
		"weapon_attack_icon": weapon_attack_icon.resource_path if weapon_attack_icon else "",
	}


func rarity_name() -> String:
	return {
		"common": "Обычный",
		"magic": "Магический",
		"rare": "Редкий",
		"unique": "Уникальный",
	}.get(rarity, "Обычный")
