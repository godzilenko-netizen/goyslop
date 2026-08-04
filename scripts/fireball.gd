extends Area3D

@export var speed: float = 18.0
@export var damage: int = 80
@export var lifetime: float = 4.0
@export var max_range: float = 15.0

var direction: Vector3 = Vector3.FORWARD
var start_position: Vector3
var traveled: float = 0.0

func _ready() -> void:
	start_position = global_position
	body_entered.connect(_on_body_entered)
	
	# Визуал: процедурная светящаяся сфера
	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	mesh_inst.mesh = sphere
	
	# Огненный материал
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	
	# Свет от фаерболла
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.0)
	light.light_energy = 2.5
	light.omni_range = 5.0
	add_child(light)
	
	# Коллайдер
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.25
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	var move = direction * speed * delta
	global_position += move
	traveled += move.length()
	
	# Вращение для визуального эффекта
	rotate_y(delta * 4.0)
	rotate_x(delta * 2.5)
	
	# Самоуничтожение по дальности или времени
	if traveled >= max_range:
		_explode()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
	_explode()

func _explode() -> void:
	# Взрыв: вспышка
	var boom_light = OmniLight3D.new()
	boom_light.light_color = Color(1.0, 0.6, 0.1)
	boom_light.light_energy = 6.0
	boom_light.omni_range = 8.0
	get_parent().add_child(boom_light)
	boom_light.global_position = global_position
	
	# Удаляем вспышку через 0.2с
	var timer = get_tree().create_timer(0.18)
	await timer.timeout
	if is_instance_valid(boom_light):
		boom_light.queue_free()
	
	queue_free()
