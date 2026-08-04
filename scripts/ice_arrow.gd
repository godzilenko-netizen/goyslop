extends Area3D

@export var speed: float = 14.0
@export var damage: int = 45
@export var slow_factor: float = 0.35   # Замедление цели до 35% скорости
@export var freeze_duration: float = 2.5
@export var lifetime: float = 5.0
@export var max_range: float = 20.0

var direction: Vector3 = Vector3.FORWARD
var traveled: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Визуал: вытянутый кристалл льда
	var mesh_inst = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.07
	capsule.height = 0.5
	mesh_inst.mesh = capsule
	# Ориентируем по направлению полёта
	mesh_inst.rotation_degrees = Vector3(90, 0, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.9, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.85, 1.0, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.6
	mat.roughness = 0.1
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# Ледяное свечение
	var light = OmniLight3D.new()
	light.light_color = Color(0.4, 0.85, 1.0)
	light.light_energy = 1.8
	light.omni_range = 4.0
	add_child(light)

	# Коллайдер
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.12
	shape.height = 0.5
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	var move = direction * speed * delta
	global_position += move
	traveled += move.length()

	if traveled >= max_range:
		_shatter()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		# Замедление — если у врага есть walk_speed
		if "walk_speed" in body:
			var orig = body.walk_speed
			body.walk_speed *= slow_factor
			body.sprint_speed *= slow_factor
			get_tree().create_timer(freeze_duration).timeout.connect(func():
				if is_instance_valid(body):
					body.walk_speed = orig
					body.sprint_speed = orig / body.get("walk_speed_ratio" if "walk_speed_ratio" in body else 1.0)
			)
	_shatter()

func _shatter() -> void:
	# Ледяная вспышка
	var boom_light = OmniLight3D.new()
	boom_light.light_color = Color(0.5, 0.9, 1.0)
	boom_light.light_energy = 5.0
	boom_light.omni_range = 6.0
	get_parent().add_child(boom_light)
	boom_light.global_position = global_position

	# Кристальные частицы — несколько маленьких мешей
	for i in range(5):
		var shard = MeshInstance3D.new()
		var s_mesh = BoxMesh.new()
		s_mesh.size = Vector3(0.05, 0.12, 0.05)
		shard.mesh = s_mesh
		var s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.6, 0.95, 1.0, 0.9)
		s_mat.emission_enabled = true
		s_mat.emission = Color(0.4, 0.9, 1.0)
		s_mat.emission_energy_multiplier = 2.0
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shard.material_override = s_mat
		shard.global_position = global_position + Vector3(
			randf_range(-0.3, 0.3), randf_range(0.0, 0.4), randf_range(-0.3, 0.3)
		)
		get_parent().add_child(shard)
		# Удаляем осколки
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(shard): shard.queue_free()
		)

	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(boom_light): boom_light.queue_free()
	queue_free()
