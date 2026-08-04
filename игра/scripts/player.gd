extends CharacterBody3D

const ModelValidator = preload("res://scripts/model_validator.gd")

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
var current_speed: float = 5.0

@export var acceleration: float = 20.0
@export var friction: float = 25.0
@export var gravity: float = 25.0

# Статы игрока
@export var max_hp: int = 100
var current_hp: int = 100
@export var max_energy: int = 50
var current_energy: int = 50
var level: int = 1
var current_xp: int = 0
@export var max_xp: int = 100

# Порог здоровья для раненого режима (25%)
@export var injured_hp_threshold_percent: float = 0.25

# Боевые параметры
@export var attack_damage: int = 25
@export var attack_cooldown: float = 0.6
var is_attack_on_cooldown: bool = false
var is_attacking: bool = false

# Фаерболл
@export var fireball_damage: int = 80
@export var fireball_cooldown: float = 3.0
@export var fireball_mana_cost: int = 30
var is_fireball_on_cooldown: bool = false
var mouse_target: Vector3 = Vector3.ZERO

# Ледяная стрела
@export var ice_arrow_damage: int = 45
@export var ice_arrow_cooldown: float = 5.0
@export var ice_arrow_mana_cost: int = 20
var is_ice_arrow_on_cooldown: bool = false
var is_casting: bool = false  # Для защиты анимации каста

@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var visual_mesh: Node3D = $Visuals
@onready var attack_hitbox: Area3D = $Visuals/AttackHitbox
@onready var hud: CanvasLayer = $HUD

var anim_player: AnimationPlayer = null
var is_moving_backwards_state: bool = false

func _ready() -> void:
	randomize()
	print("Игрок появился в 3D мире. Текущее сохранение: ", Global.current_save_name)
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
		
	# Разворот модели лицом вперед и авто-масштаб 1.8м
	if has_node("Visuals/CharacterModel"):
		ModelValidator.auto_fit_model_size($Visuals/CharacterModel, 1.8)
		
	_setup_mixamo_animations()
	_update_hud()

# --- ПОДГРУЗКА И ВАЛИДАЦИЯ ВСЕХ АНИМАЦИЙ MIXAMO (ВКЛЮЧАЯ СЛУЧАЙНЫЕ УДАРЫ) ---
func _setup_mixamo_animations() -> void:
	anim_player = _find_anim_player($Visuals)
	if not anim_player:
		print("ВНИМАНИЕ: AnimationPlayer не найден в $Visuals!")
		return
		
	var anim_library = AnimationLibrary.new()
	
	var anim_files = {
		"Idle": "res://models/characters/player/animations/normal/Idle.fbx",
		"Walk": "res://models/characters/player/animations/normal/Walking.fbx",
		"Run": "res://models/characters/player/animations/normal/Fast Run.fbx",
		"WalkBack": "res://models/characters/player/animations/normal/Walking Backwards.fbx",
		"RunBack": "res://models/characters/player/animations/normal/Running Backward.fbx",
		"Punch1": "res://models/characters/player/animations/normal/Punch1.fbx",
		"Punch2": "res://models/characters/player/animations/normal/Punch2.fbx",
		"Fireball": "res://models/characters/player/animations/normal/Fireball.fbx",
		"SpellCast": "res://models/characters/player/animations/normal/Spell Cast.fbx",
		"InjuredIdle": "res://models/characters/player/animations/injured/Injured Idle.fbx",
		"InjuredRun": "res://models/characters/player/animations/injured/Injured Run.fbx",
		"InjuredWalk": "res://models/characters/player/animations/injured/Injured Walk.fbx",
		"InjuredWalkBack": "res://models/characters/player/animations/injured/Injured Walk Backwards.fbx"
	}
	
	for anim_name in anim_files:
		var path = anim_files[anim_name]
		if ResourceLoader.exists(path):
			var fbx_scene = load(path) as PackedScene
			if fbx_scene:
				var inst = fbx_scene.instantiate()
				var f_player = _find_anim_player(inst)
				if f_player:
					var list = f_player.get_animation_list()
					if list.size() > 0:
						var orig_anim = f_player.get_animation(list[0]).duplicate()
						
						# Санитаризация Root Motion у Hips для движения In-Place
						ModelValidator.sanitize_animation(orig_anim)
						
						if anim_name in ["Idle", "Walk", "Run", "WalkBack", "RunBack", "InjuredIdle", "InjuredRun", "InjuredWalk", "InjuredWalkBack"]:
							orig_anim.loop_mode = Animation.LOOP_LINEAR
						else:
							orig_anim.loop_mode = Animation.LOOP_NONE
							
						anim_library.add_animation(anim_name, orig_anim)
						print("Успешно привязана анимация: ", anim_name)
				inst.queue_free()
				
	if anim_library.get_animation_list().size() > 0:
		if anim_player.has_animation_library("mixamo"):
			anim_player.remove_animation_library("mixamo")
		anim_player.add_animation_library("mixamo", anim_library)
		print("Библиотека анимаций Mixamo успешно привязана!")
		
		# Мгновенный запуск стартовой анимации покоя
		if anim_player.has_animation("mixamo/Idle"):
			anim_player.play("mixamo/Idle", 0.2)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found = _find_anim_player(child)
		if found:
			return found
	return null

func _physics_process(delta: float) -> void:
	# Гравитация
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Левый Shift для спринта / бега
	var is_sprinting = Input.is_key_pressed(KEY_SHIFT)
	current_speed = sprint_speed if is_sprinting else walk_speed
	
	# Получение направления движения (WASD / Стрелки)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# Плавный разгон и торможение (XZ плоскость)
	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)
		
	move_and_slide()
	
	# Поворот туловища к курсору мыши в 3D
	_rotate_towards_mouse()
	
	# Плавное переключение анимаций
	_update_animations(direction, is_sprinting)
	
	# Синхронизация камеры миникарты за игроком
	_update_minimap_camera()

func _update_animations(direction: Vector3, is_sprinting: bool) -> void:
	if not anim_player:
		anim_player = _find_anim_player($Visuals)
		if not anim_player:
			return
			
	# Защита: не перебиваем анимацию удара или каста во время атаки
	if is_attacking or is_casting:
		return
		
	var current_anim = anim_player.current_animation
	var is_injured = (current_hp / float(max_hp)) <= injured_hp_threshold_percent
	var blend_time = 0.2
	
	if direction != Vector3.ZERO:
		var forward_dir = -visual_mesh.global_transform.basis.z
		forward_dir.y = 0
		forward_dir = forward_dir.normalized()
		
		var dot = forward_dir.dot(direction)
		
		if is_moving_backwards_state:
			if dot > 0.1:
				is_moving_backwards_state = false
		else:
			if dot < -0.35:
				is_moving_backwards_state = true
				
		var target_anim = ""
		if is_moving_backwards_state:
			if is_injured:
				target_anim = "mixamo/InjuredWalkBack"
			else:
				target_anim = "mixamo/RunBack" if (is_sprinting and anim_player.has_animation("mixamo/RunBack")) else "mixamo/WalkBack"
		else:
			if is_injured:
				target_anim = "mixamo/InjuredRun" if is_sprinting else "mixamo/InjuredWalk"
			else:
				target_anim = "mixamo/Run" if is_sprinting else "mixamo/Walk"
				
		anim_player.speed_scale = 1.0
		
		if anim_player.has_animation(target_anim) and current_anim != target_anim:
			anim_player.play(target_anim, blend_time)
	else:
		is_moving_backwards_state = false
		anim_player.speed_scale = 1.0
		var target_idle = "mixamo/InjuredIdle" if (is_injured and anim_player.has_animation("mixamo/InjuredIdle")) else "mixamo/Idle"
		if anim_player.has_animation(target_idle) and current_anim != target_idle:
			anim_player.play(target_idle, blend_time)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		attack()
	elif event.is_action_pressed("skill_2"):
		cast_fireball()
	elif event.is_action_pressed("skill_3"):
		cast_ice_arrow()
	elif event.is_action_pressed("interact"):
		interact()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			take_damage(25)
		elif event.keycode == KEY_J:
			gain_xp(25)

func _rotate_towards_mouse() -> void:
	if not camera:
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	
	# Проекция на горизонтальную плоскость Y = текущая позиция игрока
	var plane = Plane(Vector3.UP, global_position.y)
	var hit_pos = plane.intersects_ray(ray_origin, ray_normal)
	
	if hit_pos != null:
		mouse_target = hit_pos  # Сохраняем для фаерболла
		var target_dir = hit_pos - global_position
		target_dir.y = 0
		if target_dir.length_squared() > 0.01:
			visual_mesh.look_at(global_position + target_dir, Vector3.UP)

func _update_minimap_camera() -> void:
	if hud and hud.has_node("Control/MinimapPanel/SubViewportContainer/SubViewport/MinimapCamera"):
		var minimap_cam = hud.get_node("Control/MinimapPanel/SubViewportContainer/SubViewport/MinimapCamera")
		minimap_cam.global_position = Vector3(global_position.x, 30.0, global_position.z)

func _update_hud() -> void:
	if hud and hud.has_method("setup_hud"):
		hud.setup_hud(current_hp, max_hp, current_energy, max_energy, level, current_xp, max_xp)

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	print("Получен урон: ", amount, " | HP: ", current_hp, "/", max_hp)
	_update_hud()

func gain_xp(amount: int) -> void:
	current_xp += amount
	print("Получено опыта: ", amount, " | XP: ", current_xp, "/", max_xp)
	
	if current_xp >= max_xp:
		level += 1
		current_xp -= max_xp
		max_xp = int(max_xp * 1.4)
		current_hp = max_hp
		current_energy = max_energy
		print("УРОВЕНЬ ПОВЫШЕН! Новый уровень: ", level)
		
	_update_hud()

# --- СЛУЧАЙНЫЙ ВЫБОР АНИМАЦИИ ИЗ ДВУХ УДАРОВ KУЛАКОМ ---
func attack() -> void:
	if is_attack_on_cooldown or is_attacking:
		return
		
	is_attack_on_cooldown = true
	is_attacking = true
	
	if not anim_player:
		anim_player = _find_anim_player($Visuals)
		
	if anim_player:
		anim_player.speed_scale = 1.75
		
		# Поиск доступных анимаций ударов
		var punches: Array[String] = []
		if anim_player.has_animation("mixamo/Punch1"):
			punches.append("mixamo/Punch1")
		if anim_player.has_animation("mixamo/Punch2"):
			punches.append("mixamo/Punch2")
			
		if punches.size() > 0:
			var chosen_punch = punches[randi() % punches.size()]
			anim_player.play(chosen_punch, 0.05)
			print("💥 Атака игрока! Наносится случайный удар: ", chosen_punch)
		
	# Запуск визуального кулдауна на первой иконке хотбара
	if hud and hud.has_method("trigger_attack_cooldown"):
		hud.trigger_attack_cooldown(attack_cooldown)
		
	# Поиск врагов в области хитбокса
	if attack_hitbox:
		var bodies = attack_hitbox.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("Enemies") and body.has_method("take_damage"):
				body.take_damage(attack_damage)
				
	# Таймер перезарядки и сброс состояния атаки
	if get_tree():
		await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false
	is_attack_on_cooldown = false

func interact() -> void:
	print("Взаимодействие!")

func _spawn_projectile(fire_dir: Vector3, height_offset: float,
		proj_color: Color, proj_damage: float,
		proj_speed: float = 20.0, proj_lifetime: float = 3.0,
		effect: String = "generic") -> void:
	var scene: PackedScene = load("res://scenes/projectile.tscn")
	if not scene:
		push_error("Projectile.tscn не найдена!")
		return
	var proj = scene.instantiate() as Area3D
	# Параметры задаём ДО add_child — _ready() их увидит
	proj.direction        = fire_dir
	proj.speed            = proj_speed
	proj.damage           = proj_damage
	proj.lifetime         = proj_lifetime
	proj.projectile_color = proj_color
	proj.effect_type      = effect
	var spawn_pos = global_position + fire_dir * 0.8 + Vector3(0, height_offset, 0)
	get_parent().add_child(proj)
	proj.global_position  = spawn_pos

func _get_fire_direction() -> Vector3:
	if mouse_target != Vector3.ZERO:
		var d = (mouse_target - global_position)
		d.y = 0
		if d.length_squared() > 0.01:
			return d.normalized()
	return -visual_mesh.global_transform.basis.z

func cast_fireball() -> void:
	if is_fireball_on_cooldown or is_casting:
		return
	if current_energy < fireball_mana_cost:
		print("💧 Недостаточно маны! (", current_energy, "/", fireball_mana_cost, ")")
		return

	current_energy -= fireball_mana_cost
	_update_hud()
	is_fireball_on_cooldown = true
	is_casting = true

	# Анимация каста фаерболла
	var anim_cast = "mixamo/Fireball"
	if anim_player and anim_player.has_animation(anim_cast):
		anim_player.speed_scale = 1.0
		anim_player.play(anim_cast, 0.1)
		# Снаряд вылетает на пике анимации (~40% длительности)
		var anim_len = anim_player.get_animation(anim_cast).length
		await get_tree().create_timer(anim_len * 0.4).timeout

	_spawn_projectile(_get_fire_direction(), 1.0, Color(1.0, 0.45, 0.0), fireball_damage, 18.0, 3.0, "fire")
	print("🔥 Фаерболл выпущен!")

	# Таймер кулдауна на иконке Хотбара
	if hud and hud.has_method("trigger_skill_cooldown"):
		hud.trigger_skill_cooldown(2, fireball_cooldown)

	is_casting = false
	await get_tree().create_timer(fireball_cooldown).timeout
	current_energy = min(max_energy, current_energy + fireball_mana_cost)
	_update_hud()
	is_fireball_on_cooldown = false

func cast_ice_arrow() -> void:
	if is_ice_arrow_on_cooldown or is_casting:
		return
	if current_energy < ice_arrow_mana_cost:
		print("💧 Недостаточно маны! (", current_energy, "/", ice_arrow_mana_cost, ")")
		return

	current_energy -= ice_arrow_mana_cost
	_update_hud()
	is_ice_arrow_on_cooldown = true
	is_casting = true

	# Анимация каста заклинания
	var anim_cast = "mixamo/SpellCast"
	if anim_player and anim_player.has_animation(anim_cast):
		anim_player.speed_scale = 1.0
		anim_player.play(anim_cast, 0.1)
		var anim_len = anim_player.get_animation(anim_cast).length
		await get_tree().create_timer(anim_len * 0.5).timeout

	_spawn_projectile(_get_fire_direction(), 1.1, Color(0.4, 0.85, 1.0), ice_arrow_damage, 14.0, 5.0, "ice")
	print("❄️ Ледяная стрела выпущена!")

	# Таймер кулдауна на иконке
	if hud and hud.has_method("trigger_skill_cooldown"):
		hud.trigger_skill_cooldown(3, ice_arrow_cooldown)

	is_casting = false
	await get_tree().create_timer(ice_arrow_cooldown).timeout
	current_energy = min(max_energy, current_energy + ice_arrow_mana_cost)
	_update_hud()
	is_ice_arrow_on_cooldown = false
