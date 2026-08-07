extends CharacterBody3D

const ModelValidatorType = preload("res://scripts/model_validator.gd")
const HealthComponentType = preload("res://scripts/components/health_component.gd")
const RetroMaterialStylerType = preload("res://scripts/retro_material_styler.gd")
const TROLL_MODEL_SCENE = preload("res://models/troll/Troll.fbx")
const TROLL_MOVE_SCENE = preload("res://models/troll/Capoeira.fbx")
const TROLL_ATTACK_SCENE = preload("res://models/troll/Baseball Hit.fbx")
const TROLL_DEATH_SCENE = preload("res://models/troll/Dying.fbx")
const WORLD_ITEM_DROP_SCENE = preload("res://scenes/world_item_drop.tscn")
const LEATHER_ARMOR_DATA = preload("res://data/items/leather_armor.tres")

enum State { CIRCLING, AGGRO, ATTACKING, WAITING, DYING }

@export var walk_speed: float = 1.0
@export var run_speed: float = 1.8
@export var circle_radius: float = 10.0
@export var aggro_range: float = 7.0
@export var attack_range: float = 2.5
@export var enemy_name: String = "Тролль"
@export var attack_damage: int = 40
@export_range(0.0, 20.0, 0.1) var knockback_horizontal_force: float = 5.0
@export_range(0.0, 20.0, 0.1) var knockback_vertical_force: float = 4.0

var state: State = State.CIRCLING
var anim_player: AnimationPlayer = null
var player: Node3D = null
static var _cached_animation_library: AnimationLibrary = null

# Visuals and HP Bar
var model_root: Node3D = null
var hp_bar: ProgressBar = null
var hp_viewport: SubViewport = null
var hp_sprite: Sprite3D = null
var _status_label: Label3D = null

# Status effects
var is_frozen: bool = false
var is_burning: bool = false
var speed_modifier: float = 1.0
var _has_hit: bool = false
var _did_hit_player: bool = false
var _freeze_generation := 0
var _burn_generation := 0
var _active_collision_layer: int = 1
var _aggro_armed := true

var freeze_mat: StandardMaterial3D
var burn_mat: StandardMaterial3D
@onready var health: HealthComponentType = $Health

var hp_name_label: Label = null
var hp_num_label: Label = null
var is_hovered: bool = false

func _ready() -> void:
	add_to_group("Enemies")
	_active_collision_layer = collision_layer
	player = get_tree().get_first_node_in_group("Player")
	health.changed.connect(_on_health_changed)
	health.died.connect(_die)
	
	input_ray_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
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
	if TROLL_MODEL_SCENE:
		model_root = TROLL_MODEL_SCENE.instantiate()
		add_child(model_root)
		ModelValidatorType.auto_fit_model_size(model_root, 2.5)
		RetroMaterialStylerType.apply_to_model(model_root, Color(0.42, 0.50, 0.34), 0.92)

func _setup_hp_bar() -> void:
	hp_viewport = SubViewport.new()
	hp_viewport.transparent_bg = true
	hp_viewport.size = Vector2i(240, 52)
	hp_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(240, 52)
	vbox.add_theme_constant_override("separation", 2)
	
	hp_name_label = Label.new()
	hp_name_label.text = enemy_name
	hp_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_name_label.add_theme_font_size_override("font_size", 13)
	hp_name_label.add_theme_color_override("font_color", Color(0.92, 0.75, 0.25, 1.0))
	hp_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hp_name_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(hp_name_label)
	
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = health.max_health
	hp_bar.value = health.current_health
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(240, 24)
	
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.12, 0.08, 0.06, 0.88)
	sb_bg.border_color = Color(0.5, 0.35, 0.1, 1.0)
	sb_bg.set_border_width_all(1)
	sb_bg.set_corner_radius_all(3)
	
	var sb_fg := StyleBoxFlat.new()
	sb_fg.bg_color = Color(0.85, 0.12, 0.12, 1.0)
	sb_fg.set_corner_radius_all(3)
	
	hp_bar.add_theme_stylebox_override("background", sb_bg)
	hp_bar.add_theme_stylebox_override("fill", sb_fg)
	
	hp_num_label = Label.new()
	hp_num_label.text = "%d / %d HP" % [health.current_health, health.max_health]
	hp_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_num_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_num_label.add_theme_font_size_override("font_size", 11)
	hp_num_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 1))
	hp_num_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hp_num_label.add_theme_constant_override("outline_size", 4)
	hp_bar.add_child(hp_num_label)
	
	vbox.add_child(hp_bar)
	hp_viewport.add_child(vbox)
	add_child(hp_viewport)
	
	hp_sprite = Sprite3D.new()
	hp_sprite.texture = hp_viewport.get_texture()
	hp_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_sprite.position = Vector3(0, 3.2, 0)
	hp_sprite.pixel_size = 0.012
	add_child(hp_sprite)
	
	_status_label = Label3D.new()
	_status_label.name = "StatusIcons"
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.position = Vector3(0, 3.65, 0)
	_status_label.pixel_size = 0.006
	_status_label.no_depth_test = true
	_status_label.render_priority = 15
	_status_label.font_size = 72
	_status_label.outline_size = 12
	_status_label.outline_modulate = Color(0, 0, 0, 0.9)
	_status_label.visible = false
	add_child(_status_label)

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
		
	if anim_player.has_animation_library("troll"):
		anim_player.remove_animation_library("troll")
	anim_player.add_animation_library("troll", _get_animation_library())
	
	_play_anim("Move")

func _get_animation_library() -> AnimationLibrary:
	if _cached_animation_library:
		return _cached_animation_library
	var library := AnimationLibrary.new()
	var animation_scenes := {
		"Move": TROLL_MOVE_SCENE,
		"Attack": TROLL_ATTACK_SCENE,
		"Death": TROLL_DEATH_SCENE,
	}
	for animation_name in animation_scenes:
		var packed_scene: PackedScene = animation_scenes[animation_name]
		var instance := packed_scene.instantiate()
		var source_player := _find_anim_player(instance)
		if source_player:
			var animation_names := source_player.get_animation_list()
			if not animation_names.is_empty():
				var animation := source_player.get_animation(animation_names[0]).duplicate()
				ModelValidatorType.sanitize_animation(animation)
				animation.loop_mode = Animation.LOOP_LINEAR if animation_name == "Move" else Animation.LOOP_NONE
				library.add_animation(animation_name, animation)
		instance.free()
	_cached_animation_library = library
	return _cached_animation_library

func _play_anim(anim_name: String, blend: float = 0.2, speed: float = 1.0) -> void:
	if anim_player and anim_player.has_animation("troll/" + anim_name):
		anim_player.play("troll/" + anim_name, blend, speed)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	if state == State.DYING:
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
		State.CIRCLING:
			_process_circling(delta, dist_to_player, dir_to_player)
		State.AGGRO:
			_process_aggro(delta, dist_to_player, dir_to_player)
		State.ATTACKING:
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
								var kb_dir := global_position.direction_to(player.global_position)
								kb_dir.y = 0.0
								if kb_dir.length_squared() > 0.001:
									kb_dir = kb_dir.normalized()
								player.apply_knockback(
									kb_dir * knockback_horizontal_force
									+ Vector3.UP * knockback_vertical_force
								)
			
			if anim_player and not anim_player.is_playing():
				if _did_hit_player:
					state = State.WAITING
					await get_tree().create_timer(0.5).timeout
					if state == State.WAITING:
						state = State.AGGRO
						_play_anim("Move")
				else:
					state = State.AGGRO
					_play_anim("Move")
		State.WAITING:
			velocity.x = 0
			velocity.z = 0

	move_and_slide()

func _process_circling(delta: float, dist_to_player: float, dir_to_player: Vector3) -> void:
	# After respawning inside the player's range, stay passive until the troll
	# has first moved clear. This prevents an unavoidable instant re-aggro.
	if not _aggro_armed:
		if dist_to_player > aggro_range + 1.0:
			_aggro_armed = true
	elif dist_to_player <= aggro_range:
		state = State.AGGRO
		_play_anim("Move")
		return
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
		state = State.ATTACKING
		_has_hit = false
		_did_hit_player = false
		_play_anim("Attack", 0.2, 0.75) # Slowed heavy attack speed
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
	if state == State.DYING: return
	health.take_damage(amount)
	if state == State.CIRCLING:
		_aggro_armed = true
		state = State.AGGRO
		_play_anim("Move")

func _on_health_changed(current: int, maximum: int) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
	if hp_num_label:
		hp_num_label.text = "%d / %d HP" % [current, maximum]
	if hp_viewport:
		hp_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if is_hovered or state != State.CIRCLING:
		_update_target_hud()

func _on_mouse_entered() -> void:
	is_hovered = true
	_update_target_hud()

func _on_mouse_exited() -> void:
	is_hovered = false
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("hide_target_info"):
		hud.hide_target_info()

func _update_target_hud() -> void:
	if not health: return
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_target_info"):
		hud.show_target_info(enemy_name, health.current_health, health.max_health)

func _update_status_icons() -> void:
	if not _status_label: return
	if state == State.DYING:
		_status_label.visible = false
		return
	var text := ""
	if is_burning:
		text += "🔥 "
	if is_frozen:
		text += "❄️ "
	_status_label.text = text.strip_edges()
	_status_label.visible = not text.is_empty()

func _die() -> void:
	if state == State.DYING:
		return
	state = State.DYING
	_freeze_generation += 1
	_burn_generation += 1
	is_frozen = false
	is_burning = false
	speed_modifier = 1.0
	_apply_material_overlay(null)
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim("Death", 0.1)
	# The body must keep its floor mask while dead. Disabling the shape here made
	# gravity pull the troll through the level. Layer 0 keeps the corpse from
	# blocking the player and from receiving projectile collisions.
	collision_layer = 0
	if hp_sprite:
		hp_sprite.visible = false
	_update_status_icons()
	_spawn_death_drop()
	get_tree().create_timer(10.0).timeout.connect(_respawn)

func _respawn() -> void:
	if not is_instance_valid(self): return
	health.reset()
	state = State.CIRCLING
	_aggro_armed = false
	velocity = Vector3.ZERO
	collision_layer = _active_collision_layer
	if hp_sprite:
		hp_sprite.visible = true
	_update_status_icons()
	_play_anim("Move")

func _spawn_death_drop() -> void:
	if not WORLD_ITEM_DROP_SCENE or not get_parent():
		return
	var drop := WORLD_ITEM_DROP_SCENE.instantiate() as WorldItemDrop
	drop.item_data = LEATHER_ARMOR_DATA
	get_parent().add_child(drop)
	var side := global_transform.basis.x.normalized()
	var origin := global_position + Vector3.UP * 1.15
	var target := global_position + side * 1.45 + Vector3.UP * 0.06
	drop.launch_from(origin, target)

func _apply_material_overlay(mat: Material) -> void:
	if not model_root: return
	_set_overlay_recursive(model_root, mat)

func _set_overlay_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = mat
	for child in node.get_children():
		_set_overlay_recursive(child, mat)

func apply_freeze(duration: float, potency: float) -> void:
	if is_frozen or state == State.DYING: return
	_freeze_generation += 1
	var generation := _freeze_generation
	is_frozen = true
	speed_modifier = potency
	_apply_material_overlay(freeze_mat)
	_update_status_icons()
	get_tree().create_timer(duration).timeout.connect(func():
		if generation != _freeze_generation or state == State.DYING:
			return
		is_frozen = false
		speed_modifier = 1.0
		_apply_material_overlay(burn_mat if is_burning else null)
		_update_status_icons()
	)

func apply_burn(duration: float = 3.0, damage_per_tick: int = 10) -> void:
	if is_burning or state == State.DYING: return
	_burn_generation += 1
	var generation := _burn_generation
	is_burning = true
	_apply_material_overlay(burn_mat)
	_update_status_icons()
	
	var ticks = int(duration / 0.5)
	for i in range(ticks):
		await get_tree().create_timer(0.5).timeout
		if generation != _burn_generation or state == State.DYING:
			return
		if is_instance_valid(self):
			take_damage(damage_per_tick)
			
	if is_instance_valid(self) and generation == _burn_generation:
		is_burning = false
		if is_frozen:
			_apply_material_overlay(freeze_mat)
		else:
			_apply_material_overlay(null)
		_update_status_icons()
