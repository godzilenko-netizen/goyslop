extends CharacterBody3D

const ModelValidator = preload("res://scripts/model_validator.gd")
const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
var current_speed: float = 5.0

@export var acceleration: float = 20.0
@export var friction: float = 25.0
@export var gravity: float = 25.0

# РЎС‚Р°С‚С‹ РёРіСЂРѕРєР°
@export var max_hp: int = 100
var current_hp: int = 100
@export var max_energy: int = 50
var current_energy: int = 50
var level: int = 1
var current_xp: int = 0
@export var max_xp: int = 100

# РџРѕСЂРѕРі Р·РґРѕСЂРѕРІСЊСЏ РґР»СЏ СЂР°РЅРµРЅРѕРіРѕ СЂРµР¶РёРјР° (25%)
@export var injured_hp_threshold_percent: float = 0.25

# Р‘РѕРµРІС‹Рµ РїР°СЂР°РјРµС‚СЂС‹
@export var attack_damage: int = 25
@export var attack_cooldown: float = 0.6
var is_attack_on_cooldown: bool = false
var is_attacking: bool = false

# Р¤Р°РµСЂР±РѕР»Р»
@export var fireball_damage: int = 80
@export var fireball_cooldown: float = 3.0
@export var fireball_mana_cost: int = 30
var is_fireball_on_cooldown: bool = false
var mouse_target: Vector3 = Vector3.ZERO

# Р›РµРґСЏРЅР°СЏ СЃС‚СЂРµР»Р°
@export var ice_arrow_damage: int = 45
@export var ice_arrow_cooldown: float = 5.0
@export var ice_arrow_mana_cost: int = 20
var is_ice_arrow_on_cooldown: bool = false
var is_casting: bool = false  # Р¤Р»Р°Рі Р±Р»РѕРєРёСЂРѕРІРєРё РІРѕ РІСЂРµРјСЏ РєР°СЃС‚Р°

var is_dead: bool = false
var is_knocked_down: bool = false

var _regen_timer: float = 0.0

@onready var camera:       Camera3D   = $CameraPivot/SpringArm3D/Camera3D
@onready var spring_arm:   SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera_pivot: Node3D     = $CameraPivot
@onready var visual_mesh: Node3D = $Visuals
@onready var attack_hitbox: Area3D = $Visuals/AttackHitbox
@onready var hud: CanvasLayer = $HUD
@onready var inventory_ui: CanvasLayer = $InventoryUI

var anim_player: AnimationPlayer = null
var is_moving_backwards_state: bool = false

func _ready() -> void:
	randomize()
	add_to_group("Player")
	var global_state := get_node_or_null("/root/Global")
	var save_name: String = str(global_state.current_save_name) if global_state else "default"
	print("Game save: ", save_name)
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
		
	if inventory_ui:
		inventory_ui.player_ref = self
		
	# Р Р°Р·РІРѕСЂРѕС‚ РјРѕРґРµР»Рё Р»РёС†РѕРј РІРїРµСЂРµРґ Рё Р°РІС‚Рѕ-РјР°СЃС€С‚Р°Р± 1.8Рј
	if has_node("Visuals/CharacterModel"):
		ModelValidator.auto_fit_model_size($Visuals/CharacterModel, 1.8)
		
	_setup_mixamo_animations()
	_update_hud()
	_warmup_skill_cache()

# --- РџРћР”Р“Р РЈР—РљРђ Р Р’РђР›РР”РђР¦РРЇ Р’РЎР•РҐ РђРќРРњРђР¦РР™ MIXAMO (Р’РљР›Р®Р§РђРЇ РЎР›РЈР§РђР™РќР«Р• РЈР”РђР Р«) ---
func _setup_mixamo_animations() -> void:
	anim_player = _find_anim_player($Visuals)
	if not anim_player:
		print("Р’РќРРњРђРќРР•: AnimationPlayer РЅРµ РЅР°Р№РґРµРЅ РІ $Visuals!")
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
	if inventory_ui and inventory_ui.get("is_open") == true:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)
		if not is_on_floor(): velocity.y -= gravity * delta
		move_and_slide()
		return

	_regen_timer += delta
	if _regen_timer >= 1.0:
		_regen_timer -= 1.0
		var needs_update = false
		if current_hp < max_hp:
			current_hp = min(max_hp, current_hp + 1)
			needs_update = true
		if current_energy < max_energy:
			current_energy = min(max_energy, current_energy + 1)
			needs_update = true
		if needs_update:
			_update_hud()

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
	if is_dead or is_knocked_down: return
	if inventory_ui and inventory_ui.get("is_open") == true:
		return
	if event.is_action_pressed("attack"):
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

func _update_hud() -> void:
	if hud and hud.has_method("setup_hud"):
		hud.setup_hud(current_hp, max_hp, current_energy, max_energy, level, current_xp, max_xp)

func take_damage(amount: int) -> void:
	if is_dead: return
	current_hp = max(0, current_hp - amount)
	print("РџРѕР»СѓС‡РµРЅ СѓСЂРѕРЅ: ", amount, " | HP: ", current_hp, "/", max_hp)
	_update_hud()
	if current_hp <= 0:
		_die()

func gain_xp(amount: int) -> void:
	current_xp += amount
	print("РџРѕР»СѓС‡РµРЅРѕ РѕРїС‹С‚Р°: ", amount, " | XP: ", current_xp, "/", max_xp)
	
	if current_xp >= max_xp:
		level += 1
		current_xp -= max_xp
		max_xp = int(max_xp * 1.4)
		current_hp = max_hp
		current_energy = max_energy
		print("РЈР РћР’Р•РќР¬ РџРћР’Р«РЁР•Рќ! РќРѕРІС‹Р№ СѓСЂРѕРІРµРЅСЊ: ", level)
		
	_update_hud()

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
	if hud and hud.has_method("trigger_attack_cooldown"):
		hud.trigger_attack_cooldown(attack_cooldown)
		
	# РџРѕРёСЃРє РІСЂР°РіРѕРІ РІ РѕР±Р»Р°СЃС‚Рё С…РёС‚Р±РѕРєСЃР°
	if attack_hitbox:
		var bodies = attack_hitbox.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("Enemies") and body.has_method("take_damage"):
				body.take_damage(attack_damage)
				
	# РўР°Р№РјРµСЂ РїРµСЂРµР·Р°СЂСЏРґРєРё Рё СЃР±СЂРѕСЃ СЃРѕСЃС‚РѕСЏРЅРёСЏ Р°С‚Р°РєРё
	if get_tree():
		await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false
	is_attack_on_cooldown = false

func interact() -> void:
	print("Р’Р·Р°РёРјРѕРґРµР№СЃС‚РІРёРµ!")

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

	# The launch begins while the body still reports its previous floor state.
	# Wait one physics frame, then keep controls locked until the body lands.
	await get_tree().physics_frame
	var airborne_time := 0.0
	while not is_on_floor() and airborne_time < 5.0:
		await get_tree().physics_frame
		airborne_time += get_physics_process_delta_time()

	if is_dead:
		return

	if anim_player and anim_player.has_animation("mixamo/GettingUp"):
		anim_player.speed_scale = 1.5
		anim_player.play("mixamo/GettingUp", 0.1)
		var anim_len := anim_player.get_animation("mixamo/GettingUp").length
		await get_tree().create_timer(anim_len / 1.5).timeout
			
	if not is_dead:
		is_knocked_down = false
	print("вљЎ [Cache Warmup] РЁРµР№РґРµСЂС‹ Рё РјР°С‚РµСЂРёР°Р»С‹ СЃРєРёР»Р»РѕРІ СѓСЃРїРµС€РЅРѕ Р·Р°РєСЌС€РёСЂРѕРІР°РЅС‹!")

func _spawn_projectile(fire_dir: Vector3, height_offset: float,
		proj_color: Color, proj_damage: float,
		proj_speed: float = 20.0, proj_lifetime: float = 3.0,
		effect: String = "generic") -> void:
	if not PROJECTILE_SCENE:
		push_error("Projectile.tscn РЅРµ РЅР°Р№РґРµРЅР°!")
		return
	var proj = PROJECTILE_SCENE.instantiate() as Area3D
	# РџР°СЂР°РјРµС‚СЂС‹ Р·Р°РґР°С‘Рј Р”Рћ add_child вЂ” _ready() РёС… СѓРІРёРґРёС‚
	proj.direction        = fire_dir
	proj.speed            = proj_speed
	proj.damage           = proj_damage
	proj.lifetime         = proj_lifetime
	proj.projectile_color = proj_color
	proj.effect_type      = effect
	proj.shooter          = self
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
	if is_dead or is_knocked_down: return
	if is_fireball_on_cooldown or is_casting:

		return
	if current_energy < fireball_mana_cost:
		print("?? Недостаточно маны! (", current_energy, "/", fireball_mana_cost, ")")
		return

	current_energy -= fireball_mana_cost
	_update_hud()
	is_fireball_on_cooldown = true
	is_casting = true

	# Анимация каста фаерболла
	var anim_cast = "mixamo/Fireball"
	if anim_player and anim_player.has_animation(anim_cast):
		anim_player.speed_scale = 1.5
		anim_player.play(anim_cast, 0.1)
		# Снаряд вылетает на пике анимации (~40% длительности)
		var anim_len = anim_player.get_animation(anim_cast).length
		await get_tree().create_timer(anim_len * 0.4 / 1.5).timeout

	_spawn_projectile(_get_fire_direction(), 1.0, Color(1.0, 0.45, 0.0), fireball_damage, 18.0, 3.0, "fire")
	print("?? Фаерболл выпущен!")

	# Таймер кулдауна на иконке Хотбара
	if hud and hud.has_method("trigger_skill_cooldown"):
		hud.trigger_skill_cooldown(2, fireball_cooldown)
	is_casting = false
	await get_tree().create_timer(fireball_cooldown).timeout
	_update_hud()
	is_fireball_on_cooldown = false

func cast_ice_arrow() -> void:
	if is_dead or is_knocked_down: return
	if is_ice_arrow_on_cooldown or is_casting:
		return
	if current_energy < ice_arrow_mana_cost:
		print("?? Недостаточно маны! (", current_energy, "/", ice_arrow_mana_cost, ")")
		return

	current_energy -= ice_arrow_mana_cost
	_update_hud()
	is_ice_arrow_on_cooldown = true
	is_casting = true

	# Анимация каста заклинания
	var anim_cast = "mixamo/SpellCast"
	if anim_player and anim_player.has_animation(anim_cast):
		anim_player.speed_scale = 1.5
		anim_player.play(anim_cast, 0.1)
		var anim_len = anim_player.get_animation(anim_cast).length
		await get_tree().create_timer(anim_len * 0.5 / 1.5).timeout

	_spawn_projectile(_get_fire_direction(), 1.1, Color(0.4, 0.85, 1.0), ice_arrow_damage, 14.0, 5.0, "ice")
	print("?? Ледяная стрела выпущена!")

	# Таймер кулдауна на иконке
	if hud and hud.has_method("trigger_skill_cooldown"):
		hud.trigger_skill_cooldown(3, ice_arrow_cooldown)
	is_casting = false
	await get_tree().create_timer(ice_arrow_cooldown).timeout
	_update_hud()
	is_ice_arrow_on_cooldown = false
