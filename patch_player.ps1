$path = 'c:\Users\ipala\Desktop\игра\scripts\player.gd'
$text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)

# Add states
$text = $text -replace 'var _regen_timer: float = 0\.0', "
var is_dead: bool = false
var is_knocked_down: bool = false

var _regen_timer: float = 0.0"

# Add animations
$animRep = '"InjuredWalkBack": "res://models/characters/player/animations/injured/Injured Walk Backwards.fbx",
		"Death": "res://models/characters/player/animations/reactions/Death.fbx",
		"FallingBack": "res://models/characters/player/animations/reactions/Falling Back.fbx",
		"GettingUp": "res://models/characters/player/animations/reactions/Getting Up.fbx"'
$text = $text -replace '"InjuredWalkBack": "res://models/characters/player/animations/injured/Injured Walk Backwards.fbx"', $animRep

# Modify physics process
$physRep = 'func _physics_process(delta: float) -> void:
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
		return'
$text = $text -replace 'func _physics_process\(delta: float\) -> void:', $physRep

# Block input
$text = $text -replace 'func _unhandled_input\(event: InputEvent\) -> void:\r?\n\tif event\.is_action_pressed\("attack"\):', "func _unhandled_input(event: InputEvent) -> void:
	if is_dead or is_knocked_down: return
	if event.is_action_pressed("attack"):"

$text = $text -replace 'func attack\(\) -> void:\r?\n\tif is_attack_on_cooldown or is_attacking:', "func attack() -> void:
	if is_dead or is_knocked_down: return
	if is_attack_on_cooldown or is_attacking:"

$text = $text -replace 'func cast_fireball\(\) -> void:\r?\n\tif is_fireball_on_cooldown or is_casting:', "func cast_fireball() -> void:
	if is_dead or is_knocked_down: return
	if is_fireball_on_cooldown or is_casting:"

$text = $text -replace 'func cast_ice_arrow\(\) -> void:\r?\n\tif is_ice_arrow_on_cooldown or is_casting:', "func cast_ice_arrow() -> void:
	if is_dead or is_knocked_down: return
	if is_ice_arrow_on_cooldown or is_casting:"

# Update take_damage
$td_orig = 'func take_damage\(amount: int\) -> void:\r?\n\tcurrent_hp = max\(0, current_hp - amount\)'
$td_new = 'func take_damage(amount: int) -> void:
	if is_dead: return
	current_hp = max(0, current_hp - amount)'
$text = $text -replace $td_orig, $td_new

$uh_orig = '_update_hud\(\)'
$text = $text -replace '(?s)func take_damage\(amount: int\) -> void:.*?_update_hud\(\)', "${0}
	if current_hp <= 0:
		_die()"

# Update knockback and add methods
$kb_orig = 'func apply_knockback\(force: Vector3\) -> void:\r?\n\tvelocity \+= force'
$kb_new = 'func apply_knockback(force: Vector3) -> void:
	if is_dead: return
	velocity += force
	if force.y > 0 and not is_knocked_down:
		_knockdown()'
$text = $text -replace $kb_orig, $kb_new

$new_methods = '

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
'
$text += $new_methods

 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
