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
		troll.state = "CIRCLING"
		troll._process_circling(0.016, troll.aggro_range - 0.1, Vector3.FORWARD)
		_check(troll.state == "AGGRO", "Troll must aggro when player is too close")
		troll.apply_burn(1.0, 0)
		troll.apply_freeze(0.1, 0.5)
		await create_timer(0.2).timeout
		_check(is_equal_approx(troll.speed_modifier, 1.0), "Freeze expiration must restore troll speed while burning")
		troll.process_mode = Node.PROCESS_MODE_DISABLED

	if player:
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

		player.apply_knockback(Vector3(0, 18.0, 0))
		var released_in_air := false
		var getting_up_in_air := false
		var saw_airborne := false
		for _frame in range(600):
			await physics_frame
			if not player.is_on_floor():
				saw_airborne = true
				if player.anim_player and player.anim_player.current_animation == "mixamo/GettingUp":
					getting_up_in_air = true
			if not player.is_knocked_down:
				released_in_air = not player.is_on_floor()
				break
		_check(saw_airborne, "Knockback test must launch the player into the air")
		_check(not getting_up_in_air, "Getting Up must not play before landing")
		_check(not released_in_air, "Knockdown controls must not unlock before landing")
		_check(not player.is_knocked_down, "Knockdown sequence must finish")

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("TEST PASSED: main scene, empty inventory, fixed camera, troll states and knockdown")
		quit(0)
	else:
		print("TEST FAILED: %d failure(s)" % failures.size())
		quit(1)
