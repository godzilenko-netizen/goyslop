extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var projectile_scene := load("res://scenes/projectile.tscn") as PackedScene
	var dummy_scene := load("res://scenes/dummy.tscn") as PackedScene
	if not projectile_scene or not dummy_scene:
		push_error("TEST: projectile or dummy scene failed to load")
		quit(1)
		return

	var test_root := Node3D.new()
	root.add_child(test_root)
	var projectile := projectile_scene.instantiate() as Area3D
	projectile.skill_data = load("res://data/skills/fireball.tres")
	var dummy := dummy_scene.instantiate() as PhysicsBody3D
	test_root.add_child(projectile)
	test_root.add_child(dummy)
	projectile.global_position = Vector3.ZERO
	dummy.global_position = Vector3.ZERO
	await physics_frame
	await physics_frame

	var masks_overlap := (projectile.collision_mask & dummy.collision_layer) != 0
	if not masks_overlap:
		push_error("TEST: projectile mask does not include enemy collision layer")
		test_root.queue_free()
		await process_frame
		quit(1)
		return
	if not is_equal_approx(projectile.max_range, 15.0) or not is_equal_approx(projectile.damage, 80.0):
		push_error("TEST: projectile did not receive its SkillData values")
		test_root.queue_free()
		await process_frame
		quit(1)
		return

	print("TEST PASSED: projectile mask and SkillData configuration")
	test_root.queue_free()
	await process_frame
	quit(0)
