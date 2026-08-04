extends CharacterBody3D

@export var max_hp: int = 300
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var circle_radius: float = 10.0
@export var attack_range: float = 2.5
@export var attack_damage: int = 40

var current_hp: int
var state: String = "CIRCLING" # CIRCLING, AGGRO, ATTACKING, DYING
var anim_player: AnimationPlayer = null
var player: Node3D = null

# Visuals and HP Bar
var model_root: Node3D = null
var hp_bar: ProgressBar = null
var hp_viewport: SubViewport = null
var hp_sprite: Sprite3D = null

# Status effects
var is_frozen: bool = false
var is_burning: bool = false
var speed_modifier: float = 1.0
var _has_hit: bool = false
var _did_hit_player: bool = false

var freeze_mat: StandardMaterial3D
var burn_mat: StandardMaterial3D

func _ready() -> void:
	current_hp = max_hp
	add_to_group("Enemies")
	player = get_tree().get_first_node_in_group("Player")
	
	freeze_mat = StandardMaterial3D.new()
	freeze_mat.albedo_color = Color(0.2, 0.5, 1.0, 0.6)
	freeze_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	burn_mat = StandardMaterial3D.new()
	burn_mat.albedo_color = Color(1.0, 0.4, 0.0, 0.6)
	burn_mat.emission_enabled = true
	burn_mat.emission = Color(1.0, 0.2, 0.0)
	burn_mat.emission_energy_multiplier = 2.0
	burn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	_setup_visuals()
	_setup_hp_bar()
	_setup_animations()

func _setup_visuals() -> void:
	var troll_scene = load("res://models/troll/Troll.fbx") as PackedScene
	if troll_scene:
		model_root = troll_scene.instantiate()
		add_child(model_root)
		ModelValidator.auto_fit_model_size(model_root, 2.5) # Trolls are big!
		
	# Create physics collision shape dynamically
	var col_shape = CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	var cap = CapsuleShape3D.new()
	cap.radius = 0.8
	cap.height = 2.5
	col_shape.shape = cap
	col_shape.position = Vector3(0, 1.25, 0)
	add_child(col_shape)

func _setup_hp_bar() -> void:
	# Create a SubViewport for the HP Bar UI
	hp_viewport = SubViewport.new()
	hp_viewport.transparent_bg = true
	hp_viewport.size = Vector2i(200, 30)
	hp_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(200, 30)
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	sb_bg.set_corner_radius_all(4)
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = Color(0.9, 0.1, 0.1, 1.0)
	sb_fg.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("background", sb_bg)
	hp_bar.add_theme_stylebox_override("fill", sb_fg)
	
	hp_viewport.add_child(hp_bar)
	add_child(hp_viewport)
	
	hp_sprite = Sprite3D.new()
	hp_sprite.texture = hp_viewport.get_texture()
	hp_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_sprite.position = Vector3(0, 3.2, 0) # Above the 2.5m troll
	hp_sprite.pixel_size = 0.015
	add_child(hp_sprite)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found = _find_anim_player(child)
		if found:
			return found
	return null

func _setup_animations() -> void:
	if not model_root: return
	anim_player = _find_anim_player(model_root)
	if not anim_player:
		print("Troll: No AnimationPlayer found in Troll.fbx, creating one dynamically!")
		anim_player = AnimationPlayer.new()
		model_root.add_child(anim_player)
		
	var anim_library = AnimationLibrary.new()
	
	var anim_files = {
		"Move": "res://models/troll/Capoeira.fbx",
		"Attack": "res://models/troll/Baseball Hit.fbx",
		"Death": "res://models/troll/Dying.fbx"
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
						ModelValidator.sanitize_animation(orig_anim)
						
						if anim_name == "Move":
							orig_anim.loop_mode = Animation.LOOP_LINEAR
						else:
							orig_anim.loop_mode = Animation.LOOP_NONE
							
						anim_library.add_animation(anim_name, orig_anim)
				inst.queue_free()
	
	if anim_player.has_animation_library("troll"):
		anim_player.remove_animation_library("troll")
	anim_player.add_animation_library("troll", anim_library)
	
	_play_anim("Move")

func _play_anim(anim_name: String, blend: float = 0.2, speed: float = 1.0) -> void:
	if anim_player and anim_player.has_animation("troll/" + anim_name):
		anim_player.play("troll/" + anim_name, blend, speed)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	if state == "DYING":
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
		
	if not player:
		move_and_slide()
		return
		
	var dist_to_player = global_position.distance_to(player.global_position)
	var dir_to_player = global_position.direction_to(player.global_position)
	dir_to_player.y = 0
	dir_to_player = dir_to_player.normalized()
	
	match state:
		"CIRCLING":
			_process_circling(delta, dist_to_player, dir_to_player)
		"AGGRO":
			_process_aggro(delta, dist_to_player, dir_to_player)
		"ATTACKING":
			velocity.x = 0
			velocity.z = 0
			if anim_player and anim_player.current_animation == "troll/Attack":
				if anim_player.current_animation_position >= anim_player.current_animation_length * 0.8 and not _has_hit:
					_has_hit = true
					if player and player.has_method("take_damage"):
						var dist = global_position.distance_to(player.global_position)
						if dist <= attack_range * 1.5:
							_did_hit_player = true
							player.take_damage(attack_damage)
							if player.has_method("apply_knockback"):
								var kb_dir = global_position.direction_to(player.global_position)
								kb_dir.y = 1.0 # Knockup effect
								player.apply_knockback(kb_dir.normalized() * 25.0)
			
			if anim_player and not anim_player.is_playing():
				if _did_hit_player:
					state = "WAITING"
					await get_tree().create_timer(0.5).timeout
					if state == "WAITING":
						state = "AGGRO"
						_play_anim("Move")
				else:
					state = "AGGRO"
					_play_anim("Move")
		"WAITING":
			velocity.x = 0
			velocity.z = 0

	move_and_slide()

func _process_circling(delta: float, dist_to_player: float, dir_to_player: Vector3) -> void:
	var target_dist = circle_radius
	
	var tangent = Vector3(-dir_to_player.z, 0, dir_to_player.x) # Rotate 90 degrees
	var correction = dir_to_player * (dist_to_player - target_dist)
	var move_dir = (tangent + correction * 0.5).normalized()
	
	velocity.x = move_dir.x * walk_speed * speed_modifier
	velocity.z = move_dir.z * walk_speed * speed_modifier
	
	if move_dir.length_squared() > 0.1:
		_smooth_look_at(global_position + move_dir, delta)

func _process_aggro(delta: float, dist_to_player: float, dir_to_player: Vector3) -> void:
	if dist_to_player <= attack_range:
		state = "ATTACKING"
		_has_hit = false
		_did_hit_player = false
		_play_anim("Attack", 0.2, 1.3) # Increased attack speed
		return
		
	velocity.x = dir_to_player.x * run_speed * speed_modifier
	velocity.z = dir_to_player.z * run_speed * speed_modifier
	
	if dir_to_player.length_squared() > 0.1:
		_smooth_look_at(global_position + dir_to_player, delta)

func _smooth_look_at(target_pos: Vector3, delta: float) -> void:
	var body_current = global_transform
	var body_target = body_current.looking_at(target_pos, Vector3.UP)
	global_transform = body_current.interpolate_with(body_target, 10.0 * delta)
	global_transform = global_transform.orthonormalized()

func take_damage(amount: int) -> void:
	if state == "DYING": return
	
	current_hp = max(0, current_hp - amount)
	hp_bar.value = current_hp
	
	if current_hp <= 0:
		_die()
	else:
		if state == "CIRCLING":
			state = "AGGRO"
			_play_anim("Move")

func _die() -> void:
	state = "DYING"
	_play_anim("Death")
	# Disable collisions
	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)
	
	var anim_len = 2.0
	if anim_player and anim_player.has_animation("troll/Death"):
		anim_len = anim_player.get_animation("troll/Death").length
		
	get_tree().create_timer(anim_len + 10.0).timeout.connect(_respawn)

func _respawn() -> void:
	if not is_instance_valid(self): return
	current_hp = max_hp
	hp_bar.value = current_hp
	state = "CIRCLING"
	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", false)
	_play_anim("Move")

func _apply_material_overlay(mat: Material) -> void:
	if not model_root: return
	_set_overlay_recursive(model_root, mat)

func _set_overlay_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = mat
	for child in node.get_children():
		_set_overlay_recursive(child, mat)

func apply_freeze(duration: float, potency: float) -> void:
	if is_frozen or state == "DYING": return
	is_frozen = true
	speed_modifier = potency
	_apply_material_overlay(freeze_mat)
	get_tree().create_timer(duration).timeout.connect(func():
		is_frozen = false
		if not is_burning:
			_apply_material_overlay(null)
			speed_modifier = 1.0
	)

func apply_burn(duration: float = 3.0, damage_per_tick: int = 10) -> void:
	if is_burning or state == "DYING": return
	is_burning = true
	_apply_material_overlay(burn_mat)
	
	var ticks = int(duration / 0.5)
	for i in range(ticks):
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(self) and state != "DYING":
			take_damage(damage_per_tick)
			
	if is_instance_valid(self):
		is_burning = false
		if is_frozen:
			_apply_material_overlay(freeze_mat)
		else:
			_apply_material_overlay(null)
