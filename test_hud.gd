extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/hud.tscn") as PackedScene
	var hud := packed.instantiate()
	root.add_child(hud)
	await process_frame
	var hotbar := hud.get_node_or_null("Control/BottomCenterPanel/HotbarContainer")
	if not hotbar:
		push_error("TEST: HUD hotbar is missing")
		hud.queue_free()
		await process_frame
		quit(1)
		return
	print("TEST PASSED: HUD hierarchy")
	hud.queue_free()
	await process_frame
	quit(0)
