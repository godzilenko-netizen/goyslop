import sys

path = r'c:\Users\ipala\Desktop\игра\scripts\player.gd'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('var _regen_timer: float = 0.0', '''var is_dead: bool = false
var is_knocked_down: bool = false

var _regen_timer: float = 0.0''')

text = text.replace('\"InjuredWalkBack\": \"res://models/characters/player/animations/injured/Injured Walk Backwards.fbx\"', '''"InjuredWalkBack": "res://models/characters/player/animations/injured/Injured Walk Backwards.fbx",
		"Death": "res://models/characters/player/animations/reactions/Death.fbx",
		"FallingBack": "res://models/characters/player/animations/reactions/Falling Back.fbx",
		"GettingUp": "res://models/characters/player/animations/reactions/Getting Up.fbx"''')

text = text.replace('func _physics_process(delta: float) -> void:', '''func _physics_process(delta: float) -> void:
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
		return''')

text = text.replace('func _unhandled_input(event: InputEvent) -> void:\n\tif event.is_action_pressed(\"attack\"):', '''func _unhandled_input(event: InputEvent) -> void:
	if is_dead or is_knocked_down: return
	if event.is_action_pressed("attack"):''')

text = text.replace('func attack() -> void:\n\tif is_attack_on_cooldown or is_attacking:', '''func attack() -> void:
	if is_dead or is_knocked_down: return
	if is_attack_on_cooldown or is_attacking:''')

text = text.replace('func cast_fireball() -> void:\n\tif is_fireball_on_cooldown or is_casting:', '''func cast_fireball() -> void:
	if is_dead or is_knocked_down: return
	if is_fireball_on_cooldown or is_casting:''')

text = text.replace('func cast_ice_arrow() -> void:\n\tif is_ice_arrow_on_cooldown or is_casting:', '''func cast_ice_arrow() -> void:
	if is_dead or is_knocked_down: return
	if is_ice_arrow_on_cooldown or is_casting:''')

text = text.replace('''func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)''', '''func take_damage(amount: int) -> void:
	if is_dead: return
	current_hp = max(0, current_hp - amount)''')

if "_die()" not in text:
    text = text.replace('''func take_damage(amount: int) -> void:
	if is_dead: return
	current_hp = max(0, current_hp - amount)
	print("Получен урон: ", amount, " | HP: ", current_hp, "/", max_hp)
	_update_hud()''', '''func take_damage(amount: int) -> void:
	if is_dead: return
	current_hp = max(0, current_hp - amount)
	print("Получен урон: ", amount, " | HP: ", current_hp, "/", max_hp)
	_update_hud()
	if current_hp <= 0:
		_die()''')

text = text.replace('''func apply_knockback(force: Vector3) -> void:
	velocity += force''', '''func apply_knockback(force: Vector3) -> void:
	if is_dead: return
	velocity += force
	if force.y > 0 and not is_knocked_down:
		_knockdown()''')

text += '''

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
		var anim_len = anim_player.get_animation("mixamo/FallingBack").length
		await get_tree().create_timer(anim_len / 1.5).timeout
		
		if is_dead: return
		
		if anim_player.has_animation("mixamo/GettingUp"):
			anim_player.speed_scale = 1.5
			anim_player.play("mixamo/GettingUp", 0.1)
			anim_len = anim_player.get_animation("mixamo/GettingUp").length
			await get_tree().create_timer(anim_len / 1.5).timeout
			
	if not is_dead:
		is_knocked_down = false
'''

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
