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
			_check(inventory.add_item({"id": "test_ring", "name": "Test Ring", "slot": "ring"}), "Inventory must accept a valid item")
			inventory.sort_inventory()

		player.apply_knockback(Vector3(0, 4.0, 0))
		var released_in_air := false
		for _frame in range(480):
			await physics_frame
			if not player.is_knocked_down:
				released_in_air = not player.is_on_floor()
				break
		_check(not released_in_air, "Knockdown controls must not unlock before landing")
		_check(not player.is_knocked_down, "Knockdown sequence must finish")

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("TEST PASSED: main scene, inventory, troll states and knockdown")
		quit(0)
	else:
		print("TEST FAILED: %d failure(s)" % failures.size())
		quit(1)
