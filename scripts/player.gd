extends CharacterBody3D

const ModelValidator = preload("res://scripts/model_validator.gd")
const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")
const SkillDataType = preload("res://scripts/data/skill_data.gd")
const FlaskDataType = preload("res://scripts/data/flask_data.gd")
const RefillableFlaskType = preload("res://scripts/components/refillable_flask.gd")
const PlayerStatsType = preload("res://scripts/components/player_stats.gd")
const GameHUDType = preload("res://scripts/hud.gd")
const RetroMaterialStylerType = preload("res://scripts/retro_material_styler.gd")
const FloatingLabel = preload("res://scripts/ui/floating_label.gd")
const BASIC_ATTACK_SKILL = preload("res://data/skills/basic_attack.tres")
const FIREBALL_SKILL = preload("res://data/skills/fireball.tres")
const ICE_ARROW_SKILL = preload("res://data/skills/ice_arrow.tres")
const BASIC_HEALTH_FLASK = preload("res://data/flasks/basic_health_flask.tres")
const BASIC_MANA_FLASK = preload("res://data/flasks/basic_mana_flask.tres")

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
var current_speed: float = 5.0

@export var acceleration: float = 20.0
@export var friction: float = 25.0
@export var gravity: float = 25.0

# РЎС‚Р°С‚С‹ РёРіСЂРѕРєР°
@export var basic_attack_skill: SkillDataType = BASIC_ATTACK_SKILL
@export var fireball_skill: SkillDataType = FIREBALL_SKILL
@export var ice_arrow_skill: SkillDataType = ICE_ARROW_SKILL
@export var health_flask_data: FlaskDataType = BASIC_HEALTH_FLASK
@export var mana_flask_data: FlaskDataType = BASIC_MANA_FLASK

var is_attack_on_cooldown: bool = false
var is_attacking: bool = false
var mouse_target: Vector3 = Vector3.ZERO
var is_casting: bool = false  # Р¤Р»Р°Рі Р±Р»РѕРєРёСЂРѕРІРєРё РІРѕ РІСЂРµРјСЏ РєР°СЃС‚Р°
var _skill_cooldowns: Dictionary = {}
var health_flask: RefillableFlaskType
var mana_flask: RefillableFlaskType

var is_dead: bool = false
var is_knocked_down: bool = false

var _regen_timer: float = 0.0

@onready var camera:       Camera3D   = $CameraPivot/SpringArm3D/Camera3D
@onready var spring_arm:   SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera_pivot: Node3D     = $CameraPivot
@onready var visual_mesh: Node3D = $Visuals
@onready var attack_hitbox: Area3D = $Visuals/AttackHitbox
@onready var stats: PlayerStatsType = $PlayerStats
@onready var hud: GameHUDType = $HUD
@onready var inventory_ui: CanvasLayer = $InventoryUI
@onready var mana_warning: Label3D = $ManaWarning

var anim_player: AnimationPlayer = null
var is_moving_backwards_state: bool = false
static var _cached_animation_library: AnimationLibrary = null
var _mana_warning_tween: Tween = null

func _ready() -> void:
	randomize()
	add_to_group("Player")
	var global_state := get_node_or_null("/root/Global")
	var save_name: String = str(global_state.current_save_name) if global_state else "default"
	print("Game save: ", save_name)
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if inventory_ui:
		inventory_ui.player_ref = self
	stats.health_changed.connect(hud.update_hp)
	stats.energy_changed.connect(hud.update_energy)
	stats.experience_changed.connect(hud.update_xp)
	stats.died.connect(_die)
	var configured_skills: Array[SkillDataType] = [basic_attack_skill, fireball_skill, ice_arrow_skill]
	hud.configure_skills(configured_skills)
	var configured_flasks: Array[FlaskDataType] = [health_flask_data, mana_flask_data]
	hud.configure_flasks(configured_flasks)
	health_flask = RefillableFlaskType.new(health_flask_data)
	mana_flask = RefillableFlaskType.new(mana_flask_data)
	health_flask.changed.connect(hud.update_flask_state)
	mana_flask.changed.connect(hud.update_flask_state)
	hud.flask_requested.connect(_use_flask_by_id)
	health_flask.emit_current_state()
	mana_flask.emit_current_state()
		
	# Р Р°Р·РІРѕСЂРѕС‚ РјРѕРґРµР»Рё Р»РёС†РѕРј РІРїРµСЂРµРґ Рё Р°РІС‚Рѕ-РјР°СЃС€С‚Р°Р± 1.8Рј
	if has_node("Visuals/CharacterModel"):
		ModelValidator.auto_fit_model_size($Visuals/CharacterModel, 1.8)
		RetroMaterialStylerType.apply_to_model(
			$Visuals/CharacterModel, Color(0.62, 0.53, 0.38), 0.86
		)
		
	_setup_mixamo_animations()
	stats.emit_current_values()
	_warmup_skill_cache()

# --- РџРћР”Р“Р РЈР—РљРђ Р Р’РђР›РР”РђР¦РРЇ Р’РЎР•РҐ РђРќРРњРђР¦РР™ MIXAMO (Р’РљР›Р®Р§РђРЇ РЎР›РЈР§РђР™РќР«Р• РЈР”РђР Р«) ---
func _setup_mixamo_animations() -> void:
	anim_player = _find_anim_player($Visuals)
	if not anim_player:
		print("Р’РќРРњРђРќРР•: AnimationPlayer РЅРµ РЅР°Р№РґРµРЅ РІ $Visuals!")
		return
	if _cached_animation_library:
		if anim_player.has_animation_library("mixamo"):
			anim_player.remove_animation_library("mixamo")
		anim_player.add_animation_library("mixamo", _cached_animation_library)
		if anim_player.has_animation("mixamo/Idle"):
			anim_player.play("mixamo/Idle", 0.2)
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
		"InjuredWalkBack": "res://models/characters/player/animations/injured/Injured Walk Backwards.fbx",
		"Death": "res://models/characters/player/animations/reactions/Death.fbx",
		"FallingBack": "res://models/characters/player/animations/reactions/Falling Back.fbx",
		"GettingUp": "res://models/characters/player/animations/reactions/Getting Up.fbx"
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
						
						# РЎР°РЅРёС‚Р°СЂРёР·Р°С†РёСЏ Root Motion Сѓ Hips РґР»СЏ РґРІРёР¶РµРЅРёСЏ In-Place
						ModelValidator.sanitize_animation(orig_anim)
						
						if anim_name in ["Idle", "Walk", "Run", "WalkBack", "RunBack", "InjuredIdle", "InjuredRun", "InjuredWalk", "InjuredWalkBack"]:
							orig_anim.loop_mode = Animation.LOOP_LINEAR
						else:
							orig_anim.loop_mode = Animation.LOOP_NONE
							
						anim_library.add_animation(anim_name, orig_anim)
						print("РЈСЃРїРµС€РЅРѕ РїСЂРёРІСЏР·Р°РЅР° Р°РЅРёРјР°С†РёСЏ: ", anim_name)
				inst.queue_free()
				
	if anim_library.get_animation_list().size() > 0:
		_cached_animation_library = anim_library
		if anim_player.has_animation_library("mixamo"):
			anim_player.remove_animation_library("mixamo")
		anim_player.add_animation_library("mixamo", anim_library)
		print("Р‘РёР±Р»РёРѕС‚РµРєР° Р°РЅРёРјР°С†РёР№ Mixamo СѓСЃРїРµС€РЅРѕ РїСЂРёРІСЏР·Р°РЅР°!")
		
		# РњРіРЅРѕРІРµРЅРЅС‹Р№ Р·Р°РїСѓСЃРє СЃС‚Р°СЂС‚РѕРІРѕР№ Р°РЅРёРјР°С†РёРё РїРѕРєРѕСЏ
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
	if not is_dead:
		health_flask.tick(delta)
		mana_flask.tick(delta)
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)
		if not is_on_floor(): velocity.y -= gravity * delta
		move_and_slide()
		return
	if is_knocked_down:
		velocity.x = move_toward(velocity.x, 0, friction * 0.5 * delta)
		velocity.z = move_toward(velocity.z, 0, friction * 0.5 * delta)
		if not is_on_floor(): velocity.y -= gravity * delta
		move_and_slide()
		return
	_regen_timer += delta
	if _regen_timer >= 1.0:
		_regen_timer -= 1.0
		stats.restore_health(1)
		stats.restore_energy(1)

	# Р“СЂР°РІРёС‚Р°С†РёСЏ
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Р›РµРІС‹Р№ Shift РґР»СЏ СЃРїСЂРёРЅС‚Р° / Р±РµРіР°
	var is_sprinting = Input.is_key_pressed(KEY_SHIFT)
	current_speed = sprint_speed if is_sprinting else walk_speed
	
	# РџРѕР»СѓС‡РµРЅРёРµ РЅР°РїСЂР°РІР»РµРЅРёСЏ РґРІРёР¶РµРЅРёСЏ (WASD / РЎС‚СЂРµР»РєРё)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# РџР»Р°РІРЅС‹Р№ СЂР°Р·РіРѕРЅ Рё С‚РѕСЂРјРѕР¶РµРЅРёРµ (XZ РїР»РѕСЃРєРѕСЃС‚СЊ)
	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)
		
	move_and_slide()
	
	# РџРѕРІРѕСЂРѕС‚ С‚СѓР»РѕРІРёС‰Р° Рє РєСѓСЂСЃРѕСЂСѓ РјС‹С€Рё РІ 3D
	_rotate_towards_mouse()
	
	# РџР»Р°РІРЅРѕРµ РїРµСЂРµРєР»СЋС‡РµРЅРёРµ Р°РЅРёРјР°С†РёР№
	_update_animations(direction, is_sprinting)
	
	# РЎРёРЅС…СЂРѕРЅРёР·Р°С†РёСЏ РєР°РјРµСЂС‹ РјРёРЅРёРєР°СЂС‚С‹ Р·Р° РёРіСЂРѕРєРѕРј
	_update_minimap_camera()

# Shift camera so the player remains centered in the unobstructed play area.
# We tween camera.h_offset (camera-local horizontal shift) which works
# correctly for top-down isometric cameras in Godot 4.
func shift_camera_for_ui(ui_open: bool) -> void:
	if not camera: return
	var tw := create_tween()
	# Use PROCESS mode so this works even if tree is paused in future
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# A positive camera-local offset moves the rendered player to the left.
	var target: float = 4.0 if ui_open else 0.0
	tw.tween_property(camera, "h_offset", target, 0.35) \
	  .set_trans(Tween.TRANS_CUBIC) \
	  .set_ease(Tween.EASE_OUT if ui_open else Tween.EASE_IN)

func _update_animations(direction: Vector3, is_sprinting: bool) -> void:
	if not anim_player:
		anim_player = _find_anim_player($Visuals)
		if not anim_player:
			return
			
	# Р—Р°С‰РёС‚Р°: РЅРµ РїРµСЂРµР±РёРІР°РµРј Р°РЅРёРјР°С†РёСЋ СѓРґР°СЂР° РёР»Рё РєР°СЃС‚Р° РІРѕ РІСЂРµРјСЏ Р°С‚Р°РєРё
	if is_attacking or is_casting:
		return
		
	var current_anim = anim_player.current_animation
	var is_injured := stats.is_injured()
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
	if is_dead or is_knocked_down: return
	if event.is_action_pressed("health_flask"):
		use_health_flask()
		return
	if event.is_action_pressed("mana_flask"):
		use_mana_flask()
		return
	if inventory_ui and inventory_ui.get("is_open") == true:
		return
	if event.is_action_pressed("attack"):
		if _try_pickup_world_loot():
			return
		attack()
	elif event.is_action_pressed("skill_2"):
		cast_fireball()
	elif event.is_action_pressed("skill_3"):
		cast_ice_arrow()
	elif event.is_action_pressed("inventory"):
		print("Inventory input received!")
		if inventory_ui and inventory_ui.has_method("toggle"):
			inventory_ui.toggle()
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
	
	# РџСЂРѕРµРєС†РёСЏ РЅР° РіРѕСЂРёР·РѕРЅС‚Р°Р»СЊРЅСѓСЋ РїР»РѕСЃРєРѕСЃС‚СЊ Y = С‚РµРєСѓС‰Р°СЏ РїРѕР·РёС†РёСЏ РёРіСЂРѕРєР°
	var plane = Plane(Vector3.UP, global_position.y)
	var hit_pos = plane.intersects_ray(ray_origin, ray_normal)
	
	if hit_pos != null:
		mouse_target = hit_pos  # РЎРѕС…СЂР°РЅСЏРµРј РґР»СЏ С„Р°РµСЂР±РѕР»Р»Р°
		var target_dir = hit_pos - global_position
		target_dir.y = 0
		if target_dir.length_squared() > 0.01:
			visual_mesh.look_at(global_position + target_dir, Vector3.UP)

func _update_minimap_camera() -> void:
	if hud and hud.has_node("Control/MinimapPanel/SubViewportContainer/SubViewport/MinimapCamera"):
		var minimap_cam = hud.get_node("Control/MinimapPanel/SubViewportContainer/SubViewport/MinimapCamera")
		minimap_cam.global_position = Vector3(global_position.x, 30.0, global_position.z)

func take_damage(amount: int) -> void:
	if is_dead: return
	var applied := stats.take_damage(amount)
	print("Damage received: ", applied, " | HP: ", stats.current_hp, "/", stats.max_hp)

func gain_xp(amount: int) -> void:
	var previous_level := stats.level
	stats.gain_experience(amount)
	print("Experience gained: ", amount, " | XP: ", stats.current_xp, "/", stats.max_xp)
	if stats.level > previous_level:
		print("Level up! New level: ", stats.level)

func restore_health(amount: int) -> int:
	return stats.restore_health(amount)

func restore_health_to_full() -> int:
	return stats.restore_health_to_full()


func use_health_flask() -> bool:
	return _use_flask(health_flask)


func use_mana_flask() -> bool:
	return _use_flask(mana_flask)


func _use_flask_by_id(flask_id: StringName) -> void:
	match flask_id:
		&"health": use_health_flask()
		&"mana": use_mana_flask()


func _use_flask(flask: RefillableFlaskType) -> bool:
	if not flask or not flask.data or flask.charges <= 0:
		if flask and flask.data:
			hud.flash_flask_unavailable(flask.data.flask_id)
		return false

	var restored := 0
	match flask.data.resource_type:
		"health":
			if stats.current_hp >= stats.max_hp:
				hud.flash_flask_unavailable(flask.data.flask_id)
				return false
			restored = stats.restore_health(flask.data.restore_amount)
		"mana":
			if stats.current_energy >= stats.max_energy:
				hud.flash_flask_unavailable(flask.data.flask_id)
				return false
			restored = stats.restore_energy(flask.data.restore_amount)
		_:
			return false

	if restored <= 0:
		return false
	flask.consume()
	return true

func restore_energy(amount: int) -> int:
	return stats.restore_energy(amount)

func restore_energy_to_full() -> int:
	return stats.restore_energy_to_full()

func add_inventory_item(item: Dictionary) -> bool:
	if not inventory_ui or not inventory_ui.has_method("add_item"):
		return false
	return inventory_ui.add_item(item)

# --- РЎР›РЈР§РђР™РќР«Р™ Р’Р«Р‘РћР  РђРќРРњРђР¦РР РР— Р”Р’РЈРҐ РЈР”РђР РћР’ KРЈР›РђРљРћРњ ---
func attack() -> void:
	if is_dead or is_knocked_down: return
	if is_attack_on_cooldown or is_attacking:
		return
		
	is_attack_on_cooldown = true
	is_attacking = true
	
	if not anim_player:
		anim_player = _find_anim_player($Visuals)
		
	if anim_player:
		anim_player.speed_scale = 1.75
		
		# РџРѕРёСЃРє РґРѕСЃС‚СѓРїРЅС‹С… Р°РЅРёРјР°С†РёР№ СѓРґР°СЂРѕРІ
		var punches: Array[String] = []
		if anim_player.has_animation("mixamo/Punch1"):
			punches.append("mixamo/Punch1")
		if anim_player.has_animation("mixamo/Punch2"):
			punches.append("mixamo/Punch2")
			
		if punches.size() > 0:
			var chosen_punch = punches[randi() % punches.size()]
			anim_player.play(chosen_punch, 0.05)
			print("рџ’Ґ РђС‚Р°РєР° РёРіСЂРѕРєР°! РќР°РЅРѕСЃРёС‚СЃСЏ СЃР»СѓС‡Р°Р№РЅС‹Р№ СѓРґР°СЂ: ", chosen_punch)
		
	# Р—Р°РїСѓСЃРє РІРёР·СѓР°Р»СЊРЅРѕРіРѕ РєСѓР»РґР°СѓРЅР° РЅР° РїРµСЂРІРѕР№ РёРєРѕРЅРєРµ С…РѕС‚Р±Р°СЂР°
	hud.trigger_attack_cooldown(basic_attack_skill.cooldown)
		
	# РџРѕРёСЃРє РІСЂР°РіРѕРІ РІ РѕР±Р»Р°СЃС‚Рё С…РёС‚Р±РѕРєСЃР°
	if attack_hitbox:
		var bodies = attack_hitbox.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("Enemies") and body.has_method("take_damage"):
				body.take_damage(basic_attack_skill.damage)
				
	# РўР°Р№РјРµСЂ РїРµСЂРµР·Р°СЂСЏРґРєРё Рё СЃР±СЂРѕСЃ СЃРѕСЃС‚РѕСЏРЅРёСЏ Р°С‚Р°РєРё
	if get_tree():
		await get_tree().create_timer(basic_attack_skill.cooldown).timeout
	is_attacking = false
	is_attack_on_cooldown = false

func interact() -> void:
	print("Р’Р·Р°РёРјРѕРґРµР№СЃС‚РІРёРµ!")

func _try_pickup_world_loot() -> bool:
	return _try_pickup_world_loot_at(get_viewport().get_mouse_position())

func _try_pickup_world_loot_at(mouse_position: Vector2) -> bool:
	if not camera or not get_world_3d():
		return false
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin, ray_origin + ray_direction * 100.0, 8
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider := hit.get("collider") as Node
	if collider and collider.is_in_group("WorldLoot") and collider.has_method("try_pickup"):
		return bool(collider.try_pickup())
	return false

func _warmup_skill_cache() -> void:
	var effect_types = ["fire", "ice", "generic"]
	var temp_container = Node3D.new()
	temp_container.name = "SkillCacheWarmup"
	temp_container.position = Vector3(0, -9999, 0)
	add_child(temp_container)
	
	for effect in effect_types:
		var dummy = PROJECTILE_SCENE.instantiate() as Area3D
		dummy.effect_type = effect
		temp_container.add_child(dummy)
	
	# Р”РѕР¶РёРґР°РµРјСЃСЏ 2 РєР°РґСЂРѕРІ РґР»СЏ РїРѕР»РЅРѕР№ РєРѕРјРїРёР»СЏС†РёРё С€РµР№РґРµСЂРѕРІ РЅР° GPU РґРѕ РЅР°С‡Р°Р»Р° Р±РѕСЏ
	await get_tree().process_frame
	await get_tree().process_frame
	
	temp_container.queue_free()
	print("Skill shaders and materials cached")

func apply_knockback(force: Vector3) -> void:
	if is_dead: return
	velocity += force
	if force.y > 0 and not is_knocked_down:
		_knockdown()

func _die() -> void:
	if is_dead: return
	is_dead = true
	is_casting = false
	is_attacking = false
	if anim_player and anim_player.has_animation("mixamo/Death"):
		anim_player.speed_scale = 1.0
		anim_player.play("mixamo/Death", 0.1)

func _knockdown() -> void:
	is_knocked_down = true
	is_casting = false
	is_attacking = false
	if anim_player and anim_player.has_animation("mixamo/FallingBack"):
		anim_player.speed_scale = 1.5
		anim_player.play("mixamo/FallingBack", 0.1)

	# The hit can arrive after this body already ran its physics step. Wait for
	# the upward impulse to really lift the body before checking for landing.
	while is_on_floor() and velocity.y > 0.0:
		await get_tree().physics_frame

	# Never start Getting Up in mid-air. Controls remain locked until a real
	# floor contact is reported by move_and_slide().
	while not is_on_floor():
		await get_tree().physics_frame

	if is_dead:
		return

	if anim_player and anim_player.has_animation("mixamo/GettingUp"):
		anim_player.speed_scale = 1.5
		anim_player.play("mixamo/GettingUp", 0.1)
		var anim_len := anim_player.get_animation("mixamo/GettingUp").length
		await get_tree().create_timer(anim_len / 1.5).timeout
			
	if not is_dead:
		is_knocked_down = false

func _spawn_projectile(fire_dir: Vector3, skill: SkillDataType) -> void:
	if not PROJECTILE_SCENE:
		push_error("Projectile.tscn РЅРµ РЅР°Р№РґРµРЅР°!")
		return
	var proj = PROJECTILE_SCENE.instantiate() as Area3D
	proj.direction = fire_dir
	proj.skill_data = skill
	proj.shooter = self
	var spawn_pos = global_position + fire_dir * 0.8 + Vector3(0, skill.projectile_height, 0)
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
	await _cast_projectile_skill(fireball_skill)

func cast_ice_arrow() -> void:
	await _cast_projectile_skill(ice_arrow_skill)

func _cast_projectile_skill(skill: SkillDataType) -> void:
	if is_dead or is_knocked_down or is_casting:
		return
	if bool(_skill_cooldowns.get(skill.skill_id, false)):
		return
	if not stats.spend_energy(skill.mana_cost):
		print("Not enough mana: ", stats.current_energy, "/", skill.mana_cost)
		_show_mana_warning()
		return

	is_casting = true
	_skill_cooldowns[skill.skill_id] = true
	hud.trigger_skill_cooldown(skill.hotbar_slot, skill.cooldown)
	get_tree().create_timer(skill.cooldown).timeout.connect(func():
		_skill_cooldowns[skill.skill_id] = false
	)

	var animation_name := str(skill.cast_animation)
	if anim_player and not animation_name.is_empty() and anim_player.has_animation(animation_name):
		anim_player.speed_scale = skill.cast_speed
		anim_player.play(animation_name, 0.1)
		var animation_length := anim_player.get_animation(animation_name).length
		await get_tree().create_timer(animation_length * skill.release_ratio / skill.cast_speed).timeout

	if is_dead or is_knocked_down:
		is_casting = false
		return
	_spawn_projectile(_get_fire_direction(), skill)
	print(skill.display_name, " launched")
	is_casting = false

var floating_mana_warning: FloatingLabel = null

func _show_mana_warning() -> void:
	if mana_warning:
		mana_warning.visible = false
	if not floating_mana_warning or not is_instance_valid(floating_mana_warning):
		floating_mana_warning = FloatingLabel.create(self, Vector3.UP * 2.35)
		floating_mana_warning.add_theme_color_override("font_color", Color(1.0, 0.22, 0.12))
		floating_mana_warning.add_theme_color_override("font_outline_color", Color(0.18, 0.01, 0, 0.95))
		floating_mana_warning.text = "НЕДОСТАТОЧНО МАНЫ"

	if _mana_warning_tween and _mana_warning_tween.is_valid():
		_mana_warning_tween.kill()

	floating_mana_warning.offset_3d = Vector3(0.0, 2.35, 0.0)
	floating_mana_warning.modulate = Color(1.0, 0.22, 0.12, 1.0)
	floating_mana_warning.manual_visibility = true

	_mana_warning_tween = create_tween().set_parallel(true)
	_mana_warning_tween.tween_property(
		floating_mana_warning, "offset_3d", Vector3(0.0, 2.75, 0.0), 1.05
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_mana_warning_tween.tween_property(
		floating_mana_warning, "modulate:a", 0.0, 0.65
	).set_delay(0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_mana_warning_tween.chain().tween_callback(func():
		if floating_mana_warning:
			floating_mana_warning.manual_visibility = false
	)
