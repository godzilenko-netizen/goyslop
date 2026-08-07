extends SceneTree

func _init() -> void:
	var img_armor := Image.load_from_file(ProjectSettings.globalize_path("res://assets/items/leather_armor.png"))
	if img_armor:
		print("Leather Armor size: ", img_armor.get_width(), "x", img_armor.get_height())
	
	var img_ring := Image.load_from_file(ProjectSettings.globalize_path("res://assets/items/copper_ring.png"))
	if img_ring:
		print("Copper Ring size: ", img_ring.get_width(), "x", img_ring.get_height())
		
	quit(0)
