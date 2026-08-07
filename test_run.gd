extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TEST: " + message)


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main.tscn must load")
	if not packed:
		quit(1)
		return

	var scene := packed.instantiate()
	_check(scene != null, "main.tscn must instantiate")
	root.add_child(scene)
	for _frame in range(120):
		await process_frame

	var world := scene.get_node_or_null("SubViewportContainer/SubViewport/World")
	_check(world != null, "World node is missing")
	var pause_menu = scene.get_node_or_null("PauseMenu")
	_check(pause_menu != null, "PauseMenu is missing")
	if pause_menu:
		pause_menu.open_pause()
		_check(paused, "Opening PauseMenu must pause the scene tree")
		_check(pause_menu.is_open, "PauseMenu must report its open state")
		_check(pause_menu.main_menu_button != null, "PauseMenu must provide a main-menu button")
		pause_menu.close_pause()
		_check(not paused, "Closing PauseMenu must resume the scene tree")
	var player = world.get_node_or_null("Player") if world else null
	var troll = world.get_node_or_null("Troll") if world else null
	_check(player != null, "Player node is missing")
	_check(troll != null, "Troll node is missing")

	if troll:
		var collision_count := 0
		for child in troll.get_children():
			if child is CollisionShape3D:
				collision_count += 1
		_check(collision_count == 1, "Troll must have exactly one collision shape")
		_check(troll.knockback_horizontal_force <= 5.0, "Troll horizontal knockback must stay inside the test arena")
		_check(troll.knockback_vertical_force <= 4.0, "Troll vertical knockback must stay low enough for quick recovery")
		troll.state = troll.State.CIRCLING
		troll._process_circling(0.016, troll.aggro_range - 0.1, Vector3.FORWARD)
		_check(troll.state == troll.State.AGGRO, "Troll must aggro when player is too close")
		troll.apply_burn(1.0, 0)
		troll.apply_freeze(0.1, 0.5)
		await create_timer(0.2).timeout
		_check(is_equal_approx(troll.speed_modifier, 1.0), "Freeze expiration must restore troll speed while burning")
		troll.process_mode = Node.PROCESS_MODE_DISABLED

	if player:
		_check(player.get_script() != null, "Player script must parse and load")
		_check(player.stats != null, "PlayerStats component is missing")
		_check(player.fireball_skill.max_range == 15.0, "Fireball range must come from SkillData")
		_check(player.ice_arrow_skill.status_duration == 2.5, "Ice duration must come from SkillData")
		_check(player.hud.skill2_tooltip != null and player.hud.skill3_tooltip != null, "HUD skill cards must be generated from SkillData")
		_check(InputMap.has_action("health_flask") and InputMap.has_action("mana_flask"), "Flask input actions must exist")
		_check(player.health_flask != null and player.mana_flask != null, "Player must own both refillable flasks")
		_check(
			player.health_flask.data.icon.resource_path == player.mana_flask.data.icon.resource_path,
			"Basic health and mana flasks must share an identical base texture"
		)
		var hp_before: int = player.stats.current_hp
		player.take_damage(10)
		_check(player.stats.current_hp == hp_before - 10, "Damage must be owned by PlayerStats")
		_check(int(player.hud.hp_orb.value) == player.stats.current_hp, "HUD health must update through PlayerStats signal")
		var health_charges_before: int = player.health_flask.charges
		_check(player.use_health_flask(), "Health flask must be usable after taking damage")
		_check(player.stats.current_hp == player.stats.max_hp, "Health flask must restore health")
		_check(player.health_flask.charges == health_charges_before - 1, "Health flask must consume one charge")
		player.health_flask.tick(player.health_flask.data.recharge_seconds + 0.01)
		_check(player.health_flask.charges == health_charges_before, "Health flask charge must refill over time")
		player.stats.spend_energy(20)
		var mana_before: int = player.stats.current_energy
		var mana_charges_before: int = player.mana_flask.charges
		_check(player.use_mana_flask(), "Mana flask must be usable after spending mana")
		_check(player.stats.current_energy > mana_before, "Mana flask must restore mana")
		_check(player.mana_flask.charges == mana_charges_before - 1, "Mana flask must consume one charge")
		player.restore_health_to_full()
		_check(player.stats.current_hp == player.stats.max_hp, "Public health restore must update PlayerStats")
		var inventory = player.get_node_or_null("InventoryUI")
		_check(inventory != null, "InventoryUI is missing")
		if inventory:
			_check(inventory.grid_slots.size() == 60, "Inventory must contain 60 functional slots")
			var before_state: Dictionary = inventory.get_inventory_state()
			_check(before_state.get("items", []).size() == 60, "Inventory state must serialize all slots")
			var occupied_slots := 0
			for item in before_state.get("items", []):
				if item is Dictionary and not item.is_empty():
					occupied_slots += 1
			_check(occupied_slots == 0, "Inventory must start without demo items")
			_check(before_state.get("gold", -1) == 0, "Inventory must start without demo gold")
			_check(inventory.add_item({"id": "test_ring", "name": "Test Ring", "slot": "ring"}), "Inventory must accept a valid item")
			inventory.sort_inventory()
			inventory._open()
			_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Opening inventory must keep the cursor visible")
			player.take_damage(5)
			var inventory_flask_charges: int = player.health_flask.charges
			var flask_input := InputEventAction.new()
			flask_input.action = &"health_flask"
			flask_input.pressed = true
			Input.parse_input_event(flask_input)
			await process_frame
			_check(
				player.health_flask.charges == inventory_flask_charges - 1,
				"Health flask hotkey must remain usable while inventory is open"
			)
			var position_before_moving: Vector3 = player.global_position
			Input.action_press("move_right")
			for _movement_frame in range(12):
				await physics_frame
			Input.action_release("move_right")
			_check(player.global_position.x > position_before_moving.x + 0.01, "Player must keep moving while inventory is open")
			inventory._close()
			_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Closing inventory must keep the gameplay cursor visible")

		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Gameplay cursor must remain visible")
		var original_pivot_rotation: Vector3 = player.camera_pivot.rotation
		var original_arm_rotation: Vector3 = player.spring_arm.rotation
		var camera_motion := InputEventMouseMotion.new()
		camera_motion.relative = Vector2(40.0, 0.0)
		Input.parse_input_event(camera_motion)
		await process_frame
		_check(player.camera_pivot.rotation.is_equal_approx(original_pivot_rotation), "Mouse motion must not rotate the fixed camera pivot")
		_check(player.spring_arm.rotation.is_equal_approx(original_arm_rotation), "Mouse motion must not tilt the fixed camera")

		var knockback_origin: Vector3 = player.global_position
		var troll_test_force := Vector3(
			troll.knockback_horizontal_force if troll else 5.0,
			troll.knockback_vertical_force if troll else 4.0,
			0.0
		)
		player.apply_knockback(troll_test_force)
		var released_in_air := false
		var getting_up_in_air := false
		var saw_airborne := false
		var max_knockback_height := 0.0
		var max_knockback_distance := 0.0
		for _frame in range(600):
			await physics_frame
			max_knockback_height = maxf(
				max_knockback_height,
				player.global_position.y - knockback_origin.y
			)
			max_knockback_distance = maxf(
				max_knockback_distance,
				Vector2(
					player.global_position.x - knockback_origin.x,
					player.global_position.z - knockback_origin.z
				).length()
			)
			if not player.is_on_floor():
				saw_airborne = true
				if player.anim_player and player.anim_player.current_animation == "mixamo/GettingUp":
					getting_up_in_air = true
			if not player.is_knocked_down:
				released_in_air = not player.is_on_floor()
				break
		_check(saw_airborne, "Knockback test must launch the player into the air")
		_check(max_knockback_height < 1.0, "Troll knockback must not launch the player too high")
		_check(max_knockback_distance < 2.5, "Troll knockback must not throw the player too far")
		_check(not getting_up_in_air, "Getting Up must not play before landing")
		_check(not released_in_air, "Knockdown controls must not unlock before landing")
		_check(not player.is_knocked_down, "Knockdown sequence must finish")

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("TEST PASSED: main scene, pause menu, inventory movement, fixed camera, troll states and knockdown")
		quit(0)
	else:
		print("TEST FAILED: %d failure(s)" % failures.size())
		quit(1)
