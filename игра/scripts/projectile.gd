extends Area3D

# ── Параметры ──────────────────────────────────────────────────────────────────
@export var speed: float = 20.0
@export var damage: float = 35.0
@export var lifetime: float = 3.0
@export var projectile_color: Color = Color(1.0, 0.45, 0.05, 1.0)
@export_enum("fire", "ice", "generic") var effect_type: String = "fire"

# ── Внутреннее состояние ───────────────────────────────────────────────────────
var direction: Vector3 = Vector3.FORWARD
var _elapsed: float    = 0.0
var _spin_speed: float = 3.5    # Рад/с для вращения шестигранника

@onready var _hex:     MeshInstance3D = $HexMesh
@onready var _trail:   GPUParticles3D = $FireTrail
@onready var _light:   OmniLight3D    = $GlowLight

# ── Инициализация ──────────────────────────────────────────────────────────────
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_hex_mesh()
	_setup_fire_trail()
	_configure_light()

# ── Движение + вращение ────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return

	# Линейное движение
	global_position += direction * speed * delta

	# Вращение шестигранника вокруг произвольной оси (выглядит органично)
	if _hex:
		_hex.rotate(Vector3(0.6, 1.0, 0.4).normalized(), _spin_speed * delta)

# ── Шестигранный меш с лавовой текстурой ──────────────────────────────────────
func _build_hex_mesh() -> void:
	if not _hex:
		return

	# CylinderMesh с 6 гранями = правильная шестигранная призма
	var cylinder      = CylinderMesh.new()
	cylinder.top_radius    = 0.18
	cylinder.bottom_radius = 0.18
	cylinder.height        = 0.22
	cylinder.radial_segments = 6    # ← Ключевое: 6 граней = шестигранник
	cylinder.rings           = 1
	_hex.mesh = cylinder

	var mat = StandardMaterial3D.new()

	# Пробуем загрузить лавовую текстуру
	var tex_path = "res://textures/lava_texture.jpg"
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path) as Texture2D
		mat.albedo_texture = tex
		mat.uv1_scale      = Vector3(1.5, 1.5, 1.0)  # Немного масштабируем UV
	else:
		# Fallback: процедурный лавовый цвет
		mat.albedo_color = Color(0.9, 0.25, 0.0, 1.0)

	# Свечение — как раскалённая лава
	mat.emission_enabled           = true
	mat.emission                   = Color(1.0, 0.38, 0.0, 1.0)
	mat.emission_energy_multiplier = 1.8

	# Материал «горячего металла»
	mat.metallic        = 0.3
	mat.roughness       = 0.75
	mat.rim_enabled     = true
	mat.rim             = 0.45
	mat.rim_tint        = 0.6

	_hex.material_override = mat

# ── Огненный шлейф (GPUParticles3D) ───────────────────────────────────────────
func _setup_fire_trail() -> void:
	if not _trail:
		return

	# Цветовой градиент: белый→жёлтый→оранжевый→красный→прозрачный
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 0.72, 1.0])
	gradient.colors  = PackedColorArray([
		Color(1.0, 1.0, 0.9, 1.0),   # Белый (горячее ядро)
		Color(1.0, 0.85, 0.1, 1.0),  # Ярко-жёлтый
		Color(1.0, 0.40, 0.0, 1.0),  # Оранжевый
		Color(0.7, 0.05, 0.0, 0.65), # Красный полупрозрачный
		Color(0.15, 0.0, 0.0, 0.0),  # Угасающий тёмно-красный
	])
	var grad_tex                 = GradientTexture1D.new()
	grad_tex.gradient            = gradient

	# Градиент размера: частица растёт затем угасает
	var size_curve               = Curve.new()
	size_curve.add_point(Vector2(0.0, 0.25))
	size_curve.add_point(Vector2(0.35, 1.0))
	size_curve.add_point(Vector2(1.0,  0.0))
	var size_tex                 = CurveTexture.new()
	size_tex.curve               = size_curve

	var mat = ParticleProcessMaterial.new()

	# Эмиссия позади снаряда — маленькая сфера
	mat.emission_shape           = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius   = 0.10

	# Частицы чуть разлетаются и уходят вверх (огонь поднимается)
	mat.direction                = Vector3(0.0, 1.0, 0.0)
	mat.spread                   = 55.0
	mat.initial_velocity_min     = 0.8
	mat.initial_velocity_max     = 2.2
	mat.gravity                  = Vector3(0.0, 1.8, 0.0)  # Вверх — как настоящий огонь

	# Турбулентность — огонь «живой»
	mat.turbulence_enabled       = true
	mat.turbulence_noise_strength = 0.35
	mat.turbulence_influence      = 0.3

	# Цвет и размер
	mat.color_ramp               = grad_tex
	mat.scale_curve              = size_tex
	mat.scale_min                = 0.12
	mat.scale_max                = 0.30

	# Вращение частиц
	mat.angle_min                = 0.0
	mat.angle_max                = 360.0
	mat.angular_velocity_min     = -180.0
	mat.angular_velocity_max     = 180.0

	_trail.process_material      = mat
	_trail.amount                = 48
	_trail.lifetime              = 0.50
	_trail.local_coords          = false   # Частицы в мировом пространстве → шлейф
	_trail.emitting              = true

# ── Динамический свет снаряда ─────────────────────────────────────────────────
func _configure_light() -> void:
	if not _light:
		return
	match effect_type:
		"fire":
			_light.light_color  = Color(1.0, 0.42, 0.05)
			_light.light_energy = 2.5
			_light.omni_range   = 4.0
		"ice":
			_light.light_color  = Color(0.45, 0.85, 1.0)
			_light.light_energy = 1.8
			_light.omni_range   = 3.0
		_:
			_light.light_color  = projectile_color
			_light.light_energy = 2.0
			_light.omni_range   = 3.5

# ── Коллизия ──────────────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Enemies") and body.has_method("take_damage"):
		body.take_damage(int(damage))
		_spawn_impact()
		queue_free()
	elif body is StaticBody3D or body is CSGCombiner3D or body is CSGBox3D:
		_spawn_impact()
		queue_free()

# ── Взрыв при попадании ────────────────────────────────────────────────────────
func _spawn_impact() -> void:
	var parent  = get_parent()
	var hit_pos = global_position
	if not parent:
		return

	# Вспышка
	var flash             = OmniLight3D.new()
	flash.light_color     = Color(1.0, 0.7, 0.1) if effect_type == "fire" else Color(0.5, 0.9, 1.0)
	flash.light_energy    = 8.0
	flash.omni_range      = 6.0
	parent.add_child(flash)
	flash.global_position = hit_pos

	# Взрывной burst — огненный градиент
	var burst               = GPUParticles3D.new()
	burst.one_shot          = true
	burst.explosiveness     = 0.98
	burst.amount            = 36
	burst.lifetime          = 0.65
	burst.emitting          = false

	var burst_grad          = Gradient.new()
	burst_grad.offsets      = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	burst_grad.colors       = PackedColorArray([
		Color(1.0, 1.0, 0.6, 1.0),
		Color(1.0, 0.5, 0.0, 1.0),
		Color(0.6, 0.05, 0.0, 0.8),
		Color(0.1, 0.0, 0.0, 0.0),
	])
	var burst_grad_tex      = GradientTexture1D.new()
	burst_grad_tex.gradient = burst_grad

	var bmat                     = ParticleProcessMaterial.new()
	bmat.emission_shape          = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	bmat.emission_sphere_radius  = 0.15
	bmat.direction               = Vector3.ZERO
	bmat.spread                  = 180.0
	bmat.initial_velocity_min    = 3.0
	bmat.initial_velocity_max    = 7.5
	bmat.gravity                 = Vector3(0.0, 2.0, 0.0)   # Огонь вверх
	bmat.scale_min               = 0.10
	bmat.scale_max               = 0.28
	bmat.color_ramp              = burst_grad_tex
	burst.process_material       = bmat

	parent.add_child(burst)
	burst.global_position        = hit_pos
	burst.emitting               = true

	# Затухание вспышки через 0.15 сек
	var tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.15)
	tween.tween_callback(func():
		if is_instance_valid(flash): flash.queue_free()
		get_tree().create_timer(0.7).timeout.connect(func():
			if is_instance_valid(burst): burst.queue_free()
		)
	)
