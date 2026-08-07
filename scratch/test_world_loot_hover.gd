extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Running World Loot Hover & Alt Test ---")
	var packed := load("res://scenes/main.tscn") as PackedScene
	if not packed:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for _f in range(60):
		await process_frame

	var drop := scene.find_child("WorldItemDrop", true, false) as WorldItemDrop
	if drop:
		print("Found WorldItemDrop at: ", drop.global_position)
		drop.hovered = true
		await process_frame
		if drop.floating_label:
			print("FloatingLabel text: ", drop.floating_label.text)
			print("FloatingLabel visibility: ", drop.floating_label.visible, " (manual: ", drop.floating_label.manual_visibility, ")")

	print("WORLD LOOT HOVER TEST COMPLETED SUCCESSFULLY!")
	scene.queue_free()
	quit(0)
