extends StaticBody3D

@export var max_hp: int = 9999
var current_hp: int = 9999

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hp_label: Label3D = $HPLabel3D

var original_material: StandardMaterial3D
var flash_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("Enemies")
	current_hp = max_hp
	
	# Настройка базового оранжевого материала манекена
	original_material = StandardMaterial3D.new()
	original_material.albedo_color = Color(0.9, 0.45, 0.15, 1.0)
	original_material.roughness = 0.6
	mesh_instance.material_override = original_material
	
	# Белый вспыхивающий материал при получении урона
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 1.0, 1.0)
	
	_update_hp_display()

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	print("Манекен получил урон: ", amount, " | HP: ", current_hp, "/", max_hp)
	
	_update_hp_display()
	_flash_effect()

func _update_hp_display() -> void:
	if hp_label:
		hp_label.text = "Манекен\n%d / %d" % [current_hp, max_hp]

func _flash_effect() -> void:
	mesh_instance.material_override = flash_material
	await get_tree().create_timer(0.12).timeout
	mesh_instance.material_override = original_material
