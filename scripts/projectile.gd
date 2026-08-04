extends Area3D

@export var speed: float = 20.0
@export var damage: float = 35.0
@export var lifetime: float = 3.0
@export var projectile_color: Color = Color(1.0, 0.45, 0.05, 1.0)
@export_enum("fire", "ice", "lightning", "poison", "earth", "generic") var effect_type: String = "fire"
@export var explosion_radius: float = 4.5
@export var status_duration: float = 3.5
@export var status_potency: float = 0.5

var _shapecast: ShapeCast3D
var shooter: Node = null
var direction: Vector3 = Vector3.FORWARD
var _elapsed: float = 0.0
var _spin_speed: float = 3.5
var _hit_processed: bool = false

@onready var _visuals: Node3D = $Visuals
@onready var _trail: GPUParticles3D = $Trail
@onready var _detail_trail: GPUParticles3D = $DetailTrail
@onready var _light: OmniLight3D = $GlowLight


func _ready() -> void:
	body_entered.connect(_on_impact)
	area_entered.connect(_on_impact)
	
	_shapecast = ShapeCast3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.22
	_shapecast.shape = shape
	_shapecast.collision_mask = collision_mask
	_shapecast.collide_with_areas = true
	_shapecast.collide_with_bodies = true
	if shooter:
		_shapecast.add_exception(shooter)
		for c in shooter.get_children():
			if c is CollisionObject3D:
				_shapecast.add_exception(c)
	add_child(_shapecast)
	
	_orient_to_direction()

	match effect_type:
		"ice":
			_build_ice_arrow_model()
			_setup_ice_trail()
		"fire":
			_build_fireball_model()
			_setup_fire_trail()
		_:
			_build_generic_model()
			_setup_generic_trail()

	_configure_light()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return

	var move_dist = speed * delta
	var move_dir = direction.normalized()
	
	if is_instance_valid(_shapecast):
		# Target position is local to the ShapeCast3D node. Since it's unrotated relative to the parent,
		# and parent rotation might be weird, we can just map the global vector to local.
		_shapecast.target_position = _shapecast.to_local(_shapecast.global_position + move_dir * move_dist)
		_shapecast.force_shapecast_update()
		
		var collision_handled = false
		for i in range(_shapecast.get_collision_count()):
			var hit_target = _shapecast.get_collider(i)
			var old_processed = _hit_processed
			_on_impact(hit_target)
			if _hit_processed and not old_processed:
				global_position = _shapecast.get_collision_point(i)
				collision_handled = true
				break
				
		if collision_handled:
			return
			
	global_position += move_dir * move_dist

	if _visuals:
		if effect_type == "ice":
			# Небольшое вращение вокруг оси полёта подчёркивает грани кристалла.
			_visuals.rotate_z(_spin_speed * 0.22 * delta)
		else:
			_visuals.rotate(Vector3(0.6, 1.0, 0.4).normalized(), _spin_speed * delta)

func _orient_to_direction() -> void:
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	look_at(global_position + direction.normalized(), Vector3.UP)


func _build_fireball_model() -> void:
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.23
	core_mesh.height = 0.46
	core_mesh.radial_segments = 16
	core_mesh.rings = 8
	_add_visual_mesh(
		core_mesh,
		_make_glowing_material(
			Color(1.0, 0.42, 0.03, 1.0),
			Color(1.0, 0.18, 0.01, 1.0),
			4.5,
			0.25,
			0.35
		)
	)

	# Полупрозрачная горячая оболочка делает шар объёмнее.
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.31
	shell_mesh.height = 0.62
	shell_mesh.radial_segments = 12
	shell_mesh.rings = 6
	_add_visual_mesh(
		shell_mesh,
		_make_glowing_material(
			Color(1.0, 0.10, 0.01, 0.28),
			Color(1.0, 0.28, 0.01, 1.0),
			2.8,
			0.0,
			0.65
		)
	)

	# Несколько асимметричных языков пламени вращаются вместе с ядром.
	var flame_offsets := [
		Vector3(0.19, 0.08, 0.04),
		Vector3(-0.16, 0.13, -0.07),
		Vector3(0.03, -0.18, 0.12),
		Vector3(-0.07, -0.08, -0.20),
	]
	var flame_material := _make_glowing_material(
		Color(1.0, 0.62, 0.04, 0.82),
		Color(1.0, 0.26, 0.01, 1.0),
		3.2,
		0.0,
		0.55
	)
	for offset in flame_offsets:
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.105
		flame_mesh.height = 0.25
		flame_mesh.radial_segments = 8
		flame_mesh.rings = 4
		_add_visual_mesh(flame_mesh, flame_material, offset)


func _build_ice_arrow_model() -> void:
	var ice_material := _make_glowing_material(
		Color(0.34, 0.82, 1.0, 0.82),
		Color(0.18, 0.72, 1.0, 1.0),
		2.7,
		0.12,
		0.08
	)
	var ice_core_material := _make_glowing_material(
		Color(0.88, 0.98, 1.0, 1.0),
		Color(0.46, 0.92, 1.0, 1.0),
		4.2,
		0.05,
		0.12
	)

	# Шестигранный кристаллический стержень вдоль локальной оси -Z.
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.072
	shaft_mesh.bottom_radius = 0.092
	shaft_mesh.height = 0.70
	shaft_mesh.radial_segments = 6
	shaft_mesh.rings = 1
	_add_visual_mesh(
		shaft_mesh,
		ice_material,
		Vector3(0.0, 0.0, -0.08),
		Vector3(-PI * 0.5, 0.0, 0.0)
	)

	# Острый четырёхгранный наконечник.
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.17
	tip_mesh.height = 0.38
	tip_mesh.radial_segments = 4
	tip_mesh.rings = 1
	_add_visual_mesh(
		tip_mesh,
		ice_core_material,
		Vector3(0.0, 0.0, -0.54),
		Vector3(-PI * 0.5, PI * 0.25, 0.0)
	)

	# Светящееся внутреннее ядро.
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.028
	core_mesh.bottom_radius = 0.038
	core_mesh.height = 0.58
	core_mesh.radial_segments = 6
	core_mesh.rings = 1
	_add_visual_mesh(
		core_mesh,
		ice_core_material,
		Vector3(0.0, 0.0, -0.05),
		Vector3(-PI * 0.5, 0.0, 0.0)
	)

	# Крестообразные стабилизаторы в хвосте.
	var horizontal_fin := BoxMesh.new()
	horizontal_fin.size = Vector3(0.34, 0.028, 0.24)
	_add_visual_mesh(horizontal_fin, ice_material, Vector3(0.0, 0.0, 0.31))

	var vertical_fin := BoxMesh.new()
	vertical_fin.size = Vector3(0.028, 0.34, 0.24)
	_add_visual_mesh(vertical_fin, ice_material, Vector3(0.0, 0.0, 0.31))

	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.09
	tail_mesh.bottom_radius = 0.0
	tail_mesh.height = 0.22
	tail_mesh.radial_segments = 4
	tail_mesh.rings = 1
	_add_visual_mesh(
		tail_mesh,
		ice_core_material,
		Vector3(0.0, 0.0, 0.48),
		Vector3(-PI * 0.5, PI * 0.25, 0.0)
	)


func _build_generic_model() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	_add_visual_mesh(
		sphere,
		_make_glowing_material(
			projectile_color,
			projectile_color,
			2.0,
			0.1,
			0.4
		)
	)


func _setup_fire_trail() -> void:
	var fire_gradient := Gradient.new()
	fire_gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.48, 0.76, 1.0])
	fire_gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 0.78, 1.0),
		Color(1.0, 0.88, 0.08, 1.0),
		Color(1.0, 0.34, 0.0, 0.94),
		Color(0.55, 0.025, 0.0, 0.58),
		Color(0.08, 0.0, 0.0, 0.0),
	])
	var fire_size := Curve.new()
	fire_size.add_point(Vector2(0.0, 0.22))
	fire_size.add_point(Vector2(0.22, 1.0))
	fire_size.add_point(Vector2(0.70, 0.72))
	fire_size.add_point(Vector2(1.0, 0.0))

	var process := _make_particle_process(
		fire_gradient,
		fire_size,
		Vector3.UP,
		75.0,
		0.5,
		2.2,
		Vector3(0.0, 1.7, 0.0),
		0.58,
		1.30
	)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.16
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.32
	process.turbulence_influence_min = 0.18
	process.turbulence_influence_max = 0.42

	_trail.process_material = process
	_trail.draw_pass_1 = _make_particle_sphere(0.12, 0.24, true)
	_trail.amount = 96
	_trail.lifetime = 0.65
	_trail.randomness = 0.35
	_trail.local_coords = false
	_trail.visibility_aabb = AABB(Vector3(-12, -6, -12), Vector3(24, 12, 24))
	_trail.emitting = true

	var ember_gradient := Gradient.new()
	ember_gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
	ember_gradient.colors = PackedColorArray([
		Color(1.0, 0.95, 0.35, 1.0),
		Color(1.0, 0.42, 0.02, 1.0),
		Color(0.85, 0.08, 0.0, 0.8),
		Color(0.3, 0.0, 0.0, 0.0),
	])
	var ember_size := Curve.new()
	ember_size.add_point(Vector2(0.0, 0.8))
	ember_size.add_point(Vector2(0.65, 0.55))
	ember_size.add_point(Vector2(1.0, 0.0))

	var ember_process := _make_particle_process(
		ember_gradient,
		ember_size,
		Vector3.UP,
		60.0,
		1.2,
		3.5,
		Vector3(0.0, 1.2, 0.0),
		0.55,
		1.15
	)
	ember_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	ember_process.emission_sphere_radius = 0.12

	_detail_trail.process_material = ember_process
	_detail_trail.draw_pass_1 = _make_particle_sphere(0.025, 0.05, true)
	_detail_trail.amount = 42
	_detail_trail.lifetime = 0.85
	_detail_trail.randomness = 0.55
	_detail_trail.local_coords = false
	_detail_trail.visibility_aabb = AABB(Vector3(-12, -6, -12), Vector3(24, 12, 24))
	_detail_trail.emitting = true


func _setup_ice_trail() -> void:
	var frost_gradient := Gradient.new()
	frost_gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.62, 1.0])
	frost_gradient.colors = PackedColorArray([
		Color(0.96, 1.0, 1.0, 0.95),
		Color(0.48, 0.91, 1.0, 0.88),
		Color(0.16, 0.55, 1.0, 0.55),
		Color(0.05, 0.18, 0.48, 0.0),
	])
	var frost_size := Curve.new()
	frost_size.add_point(Vector2(0.0, 0.35))
	frost_size.add_point(Vector2(0.30, 0.95))
	frost_size.add_point(Vector2(1.0, 0.0))

	var frost_process := _make_particle_process(
		frost_gradient,
		frost_size,
		Vector3(0.0, 0.0, 1.0),
		28.0,
		0.45,
		1.5,
		Vector3(0.0, 0.15, 0.0),
		0.45,
		1.05
	)
	frost_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	frost_process.emission_sphere_radius = 0.09

	_trail.process_material = frost_process
	_trail.draw_pass_1 = _make_particle_sphere(0.075, 0.15, true)
	_trail.amount = 72
	_trail.lifetime = 0.72
	_trail.randomness = 0.4
	_trail.local_coords = false
	_trail.visibility_aabb = AABB(Vector3(-12, -6, -12), Vector3(24, 12, 24))
	_trail.emitting = true

	var shard_gradient := Gradient.new()
	shard_gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	shard_gradient.colors = PackedColorArray([
		Color(0.95, 1.0, 1.0, 1.0),
		Color(0.35, 0.82, 1.0, 0.9),
		Color(0.08, 0.35, 0.85, 0.0),
	])
	var shard_size := Curve.new()
	shard_size.add_point(Vector2(0.0, 0.7))
	shard_size.add_point(Vector2(0.45, 1.0))
	shard_size.add_point(Vector2(1.0, 0.0))

	var shard_process := _make_particle_process(
		shard_gradient,
		shard_size,
		Vector3(0.0, 0.0, 1.0),
		38.0,
		0.8,
		2.4,
		Vector3(0.0, -0.45, 0.0),
		0.55,
		1.25
	)
	shard_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	shard_process.emission_sphere_radius = 0.08
	shard_process.angle_min = 0.0
	shard_process.angle_max = 360.0
	shard_process.angular_velocity_min = -240.0
	shard_process.angular_velocity_max = 240.0

	_detail_trail.process_material = shard_process
	_detail_trail.draw_pass_1 = _make_ice_shard_mesh()
	_detail_trail.amount = 34
	_detail_trail.lifetime = 0.82
	_detail_trail.randomness = 0.5
	_detail_trail.local_coords = false
	_detail_trail.visibility_aabb = AABB(Vector3(-12, -6, -12), Vector3(24, 12, 24))
	_detail_trail.emitting = true


func _setup_generic_trail() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		projectile_color,
		Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.0),
	])
	var size_curve := Curve.new()
	size_curve.add_point(Vector2(0.0, 0.8))
	size_curve.add_point(Vector2(1.0, 0.0))
	_trail.process_material = _make_particle_process(
		gradient,
		size_curve,
		Vector3.UP,
		180.0,
		0.2,
		0.8,
		Vector3.ZERO,
		0.6,
		1.0
	)
	_trail.draw_pass_1 = _make_particle_sphere(0.06, 0.12, true)
	_trail.amount = 36
	_trail.lifetime = 0.45
	_trail.local_coords = false
	_trail.emitting = true
	_detail_trail.emitting = false


func _configure_light() -> void:
	if not _light:
		return
	match effect_type:
		"fire":
			_light.light_color = Color(1.0, 0.38, 0.035)
			_light.light_energy = 3.2
			_light.omni_range = 4.8
		"ice":
			_light.light_color = Color(0.34, 0.82, 1.0)
			_light.light_energy = 2.3
			_light.omni_range = 4.0
		_:
			_light.light_color = projectile_color
			_light.light_energy = 2.0
			_light.omni_range = 3.5


func _make_glowing_material(
		albedo: Color,
		emission_color: Color,
		emission_energy: float,
		metallic: float,
		roughness: float
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = emission_energy
	material.metallic = metallic
	material.roughness = roughness
	if albedo.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_particle_material(unshaded: bool = true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.25
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _make_particle_process(
		gradient: Gradient,
		size_curve: Curve,
		particle_direction: Vector3,
		spread_degrees: float,
		velocity_min: float,
		velocity_max: float,
		particle_gravity: Vector3,
		scale_minimum: float,
		scale_maximum: float
	) -> ParticleProcessMaterial:
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient
	var size_texture := CurveTexture.new()
	size_texture.curve = size_curve

	var process := ParticleProcessMaterial.new()
	process.direction = particle_direction
	process.spread = spread_degrees
	process.initial_velocity_min = velocity_min
	process.initial_velocity_max = velocity_max
	process.gravity = particle_gravity
	process.color_ramp = gradient_texture
	process.scale_curve = size_texture
	process.scale_min = scale_minimum
	process.scale_max = scale_maximum
	return process


func _make_particle_sphere(radius: float, height: float, unshaded: bool) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _make_particle_material(unshaded)
	return mesh


func _make_ice_shard_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.045, 0.045, 0.16)
	mesh.material = _make_particle_material(true)
	return mesh


func _add_visual_mesh(
		mesh: Mesh,
		material: Material,
		local_position: Vector3 = Vector3.ZERO,
		local_rotation: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = local_position
	instance.rotation = local_rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(instance)
	return instance


func _on_impact(target: Node) -> void:
	if _hit_processed:
		return
	
	# Игнорировать любые части стрелка (Area3D, дочерние узлы и т.д.)
	print("Impact with: ", target.name); var current = target
	var is_shooter = false
	while current != null:
		if current == shooter or (current.is_in_group("Player") and shooter != null and shooter.is_in_group("Player")):
			is_shooter = true
			break
		current = current.get_parent()
		
	if is_shooter:
		return
		
	_hit_processed = true
	var hit_pos := global_position

	match effect_type:
		"fire":
			_process_fire_impact(hit_pos, target)
		"ice":
			_process_ice_impact(hit_pos, target)
		"lightning":
			_process_lightning_impact(hit_pos, target)
		"poison":
			_process_poison_impact(hit_pos, target)
		"earth":
			_process_earth_impact(hit_pos, target)
		_:
			_process_generic_impact(hit_pos, target)

	queue_free()

# --- ФАЕРБОЛЛ: ВЗРЫВ ПО РАДИУСУ (AOE) + ОГНЕННЫЕ ЭФФЕКТЫ ---
func _process_fire_impact(hit_pos: Vector3, direct_target: Node) -> void:
	_spawn_fireball_explosion_visuals(hit_pos)
	
	# Поиск всех врагов в радиусе взрыва
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node3D:
			var dist = enemy.global_position.distance_to(hit_pos)
			if dist <= explosion_radius:
				# Урон снижается к краям взрыва (от 100% в центре до 65% на краю)
				var falloff = 1.0 - (dist / explosion_radius) * 0.35
				var final_damage = max(10, int(damage * falloff))
				
				if enemy.has_method("take_damage"):
					enemy.take_damage(final_damage)
				if enemy.has_method("apply_burn"):
					enemy.apply_burn(3.0, 10)

# --- ЛЕДЯНАЯ СТРЕЛА: ТОЧЕЧНЫЙ УРОН + ЗАМОРОЗКА + ЛЕДЯНОЙ ВЗРЫВ ---
func _process_ice_impact(hit_pos: Vector3, direct_target: Node) -> void:
	_spawn_ice_shatter_visuals(hit_pos)
	
	# Ледяная стрела наносит урон только тому, в кого попала, но если это Area, ищем родителя
	var enemy = direct_target
	while enemy != null:
		if enemy.is_in_group("Enemies"):
			if enemy.has_method("take_damage"):
				enemy.take_damage(int(damage))
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(status_duration, status_potency)
			elif "walk_speed" in enemy:
				var orig = enemy.walk_speed
				enemy.walk_speed *= status_potency
				get_tree().create_timer(status_duration).timeout.connect(func():
					if is_instance_valid(enemy):
						enemy.walk_speed = orig
				)
			break
		enemy = enemy.get_parent()

# --- БУДУЩИЕ СКИЛЛЫ: МОЛНИЯ ---
func _process_lightning_impact(hit_pos: Vector3, direct_target: Node) -> void:
	_spawn_generic_impact(hit_pos, Color(1.0, 0.9, 0.2))
	if direct_target and direct_target.is_in_group("Enemies") and direct_target.has_method("take_damage"):
		direct_target.take_damage(int(damage * 1.2))

# --- БУДУЩИЕ СКИЛЛЫ: ЯД ---
func _process_poison_impact(hit_pos: Vector3, direct_target: Node) -> void:
	_spawn_generic_impact(hit_pos, Color(0.2, 0.9, 0.3))
	if direct_target and direct_target.is_in_group("Enemies") and direct_target.has_method("take_damage"):
		direct_target.take_damage(int(damage * 0.5))

# --- БУДУЩИЕ СКИЛЛЫ: ЗЕМЛЯ ---
func _process_earth_impact(hit_pos: Vector3, direct_target: Node) -> void:
	_spawn_generic_impact(hit_pos, Color(0.6, 0.45, 0.25))
	if direct_target and direct_target.is_in_group("Enemies") and direct_target.has_method("take_damage"):
		direct_target.take_damage(int(damage))

# --- БАЗОВЫЙ ИМПАКТ ---
func _process_generic_impact(hit_pos: Vector3, direct_target: Node) -> void:
	_spawn_generic_impact(hit_pos, projectile_color)
	if direct_target and direct_target.is_in_group("Enemies") and direct_target.has_method("take_damage"):
		direct_target.take_damage(int(damage))

# --- ВИЗУАЛ ВЗРЫВА ФАЕРБОЛЛА (AOE) ---
func _spawn_fireball_explosion_visuals(hit_pos: Vector3) -> void:
	var world := get_parent()
	if not world:
		return
		
	# 1. Вспышка света от взрыва
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.45, 0.05)
	flash.light_energy = 15.0
	flash.omni_range = explosion_radius * 1.8
	world.add_child(flash)
	flash.global_position = hit_pos

	# 2. Растущая огненная волна взрыва (SphereMesh)
	var blast_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	blast_mesh.mesh = sphere
	
	var blast_mat := StandardMaterial3D.new()
	blast_mat.albedo_color = Color(1.0, 0.35, 0.02, 0.85)
	blast_mat.emission_enabled = true
	blast_mat.emission = Color(1.0, 0.5, 0.05)
	blast_mat.emission_energy_multiplier = 4.0
	blast_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast_mesh.material_override = blast_mat
	
	world.add_child(blast_mesh)
	blast_mesh.global_position = hit_pos
	
	var tween := blast_mesh.create_tween().set_parallel(true)
	var target_scale = explosion_radius * 0.8
	tween.tween_property(blast_mesh, "scale", Vector3(target_scale, target_scale, target_scale), 0.28)
	tween.tween_property(blast_mat, "albedo_color:a", 0.0, 0.28)
	tween.tween_property(flash, "light_energy", 0.0, 0.28)
	
	tween.finished.connect(func():
		if is_instance_valid(blast_mesh): blast_mesh.queue_free()
		if is_instance_valid(flash): flash.queue_free()
	)

	# 3. Частицы разлетающихся искр и дыма
	var burst := GPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 64
	burst.lifetime = 0.65
	burst.local_coords = false
	
	var fire_grad := Gradient.new()
	fire_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 0.6, 1.0),
		Color(1.0, 0.4, 0.0, 0.9),
		Color(0.2, 0.0, 0.0, 0.0)
	])
	var size_curv := Curve.new()
	size_curv.add_point(Vector2(0, 0.4))
	size_curv.add_point(Vector2(0.2, 1.0))
	size_curv.add_point(Vector2(1, 0.0))
	
	var proc := _make_particle_process(fire_grad, size_curv, Vector3.UP, 180.0, 3.5, 8.0, Vector3(0, 1.5, 0), 0.4, 1.2)
	burst.process_material = proc
	burst.draw_pass_1 = _make_particle_sphere(0.06, 0.12, true)
	
	world.add_child(burst)
	burst.global_position = hit_pos
	burst.emitting = true
	
	get_tree().create_timer(0.7).timeout.connect(func():
		if is_instance_valid(burst): burst.queue_free()
	)

# --- ВИЗУАЛ ЛЕДЯНОГО РАЗРЫВА ---
func _spawn_ice_shatter_visuals(hit_pos: Vector3) -> void:
	var world := get_parent()
	if not world:
		return
		
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.4, 0.85, 1.0)
	flash.light_energy = 10.0
	flash.omni_range = 6.0
	world.add_child(flash)
	flash.global_position = hit_pos

	var burst := GPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 0.98
	burst.amount = 54
	burst.lifetime = 0.7
	burst.local_coords = false

	var ice_grad := Gradient.new()
	ice_grad.colors = PackedColorArray([
		Color(0.9, 1.0, 1.0, 1.0),
		Color(0.3, 0.85, 1.0, 0.8),
		Color(0.05, 0.2, 0.5, 0.0)
	])
	var size_curv := Curve.new()
	size_curv.add_point(Vector2(0, 0.5))
	size_curv.add_point(Vector2(1, 0.0))

	var proc := _make_particle_process(ice_grad, size_curv, Vector3.UP, 180.0, 2.5, 7.0, Vector3(0, -1.0, 0), 0.5, 1.3)
	burst.process_material = proc
	burst.draw_pass_1 = _make_ice_shard_mesh()

	world.add_child(burst)
	burst.global_position = hit_pos
	burst.emitting = true

	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.25)
	tween.tween_callback(func(): if is_instance_valid(flash): flash.queue_free())

	get_tree().create_timer(0.75).timeout.connect(func():
		if is_instance_valid(burst): burst.queue_free()
	)

func _spawn_generic_impact(hit_pos: Vector3, col: Color) -> void:
	var world := get_parent()
	if not world: return
	var flash := OmniLight3D.new()
	flash.light_color = col
	flash.light_energy = 6.0
	flash.omni_range = 4.0
	world.add_child(flash)
	flash.global_position = hit_pos
	
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.2)
	tween.tween_callback(func(): if is_instance_valid(flash): flash.queue_free())
