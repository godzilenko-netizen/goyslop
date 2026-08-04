extends StaticBody3D

@export var max_hp: int = 9999
var current_hp: int = 9999

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hp_label: Label3D = $HPLabel3D

var original_material: StandardMaterial3D
var flash_material: StandardMaterial3D
var freeze_material: StandardMaterial3D
var burn_material: StandardMaterial3D

var is_frozen: bool = false
var is_burning: bool = false

func _ready() -> void:
	add_to_group("Enemies")
	current_hp = max_hp
	
	# Настройка базового оранжевого материала манекена
	original_material = StandardMaterial3D.new()
	original_material.albedo_color = Color(0.9, 0.45, 0.15, 1.0)
	original_material.roughness = 0.6
	if mesh_instance:
		mesh_instance.material_override = original_material
	
	# Белый вспыхивающий материал при получении урона
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 1.0, 1.0)

	# Ледяной материал при заморозке
	freeze_material = StandardMaterial3D.new()
	freeze_material.albedo_color = Color(0.3, 0.85, 1.0, 0.85)
	freeze_material.emission_enabled = true
	freeze_material.emission = Color(0.2, 0.75, 1.0)
	freeze_material.emission_energy_multiplier = 2.0
	freeze_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Огненный материал при горении
	burn_material = StandardMaterial3D.new()
	burn_material.albedo_color = Color(1.0, 0.3, 0.05, 1.0)
	burn_material.emission_enabled = true
	burn_material.emission = Color(1.0, 0.4, 0.0)
	burn_material.emission_energy_multiplier = 2.5

	_update_hp_display()

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	print("🎯 Манекен получил урон: ", amount, " | HP: ", current_hp, "/", max_hp)
	_update_hp_display()
	if not is_frozen and not is_burning:
		_flash_effect()

func apply_freeze(duration: float = 3.0, slow_factor: float = 0.5) -> void:
	print("❄️ Манекен заморожен на ", duration, " сек! (Скорость -", int((1.0 - slow_factor) * 100), "%)")
	is_frozen = true
	if mesh_instance:
		mesh_instance.material_override = freeze_material
	_update_hp_display(" ❄️[ЗАМОРОЖЕН]")

	await get_tree().create_timer(duration).timeout
	is_frozen = false
	if is_instance_valid(self):
		if mesh_instance:
			mesh_instance.material_override = original_material
		_update_hp_display()

func apply_burn(duration: float = 3.0, damage_per_tick: int = 10) -> void:
	if is_burning:
		return
	print("🔥 Манекен подожжён на ", duration, " сек!")
	is_burning = true
	if mesh_instance:
		mesh_instance.material_override = burn_material
	_update_hp_display(" 🔥[ГОРИТ]")

	var ticks = int(duration / 0.5)
	for i in range(ticks):
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(self):
			return
		take_damage(damage_per_tick)

	is_burning = false
	if is_instance_valid(self):
		if mesh_instance and not is_frozen:
			mesh_instance.material_override = original_material
		_update_hp_display()

func _update_hp_display(status_tag: String = "") -> void:
	if hp_label:
		hp_label.text = "Манекен%s\n%d / %d" % [status_tag, current_hp, max_hp]

func _flash_effect() -> void:
	if not mesh_instance:
		return
	mesh_instance.material_override = flash_material
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self) and mesh_instance and not is_frozen and not is_burning:
		mesh_instance.material_override = original_material

