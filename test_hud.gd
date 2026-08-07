extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/hud.tscn") as PackedScene
	var hud := packed.instantiate()
	root.add_child(hud)
	await process_frame
	var flask_data: Array[FlaskData] = [
		load("res://data/flasks/basic_health_flask.tres"),
		load("res://data/flasks/basic_mana_flask.tres"),
	]
	hud.configure_flasks(flask_data)
	await process_frame
	var hotbar := hud.get_node_or_null("Control/BottomCenterPanel/HotbarContainer")
	if not hotbar:
		push_error("TEST: HUD hotbar is missing")
		hud.queue_free()
		await process_frame
		quit(1)
		return
	var flask_bar := hud.get_node_or_null("Control/FlaskBar")
	if not flask_bar or flask_bar.get_child_count() != 2:
		push_error("TEST: HUD must create two flask controls")
		hud.queue_free()
		await process_frame
		quit(1)
		return
	if not hud.get_node_or_null("Control/HPOrbContainer/OrbDecor") \
	or not hud.get_node_or_null("Control/EnergyOrbContainer/OrbDecor"):
		push_error("TEST: custom orb decorations are missing")
		hud.queue_free()
		await process_frame
		quit(1)
		return
	var hp_orb := hud.get_node("Control/HPOrbContainer/HPOrb") as TextureProgressBar
	var mana_orb := hud.get_node("Control/EnergyOrbContainer/EnergyOrb") as TextureProgressBar
	var hp_container := hud.get_node("Control/HPOrbContainer") as Control
	var mana_container := hud.get_node("Control/EnergyOrbContainer") as Control
	if not hp_container.scale.is_equal_approx(Vector2(1.12, 1.12)) \
	or not mana_container.scale.is_equal_approx(Vector2(1.12, 1.12)):
		push_error("TEST: orb compositions must use the shared enlarged scale")
		hud.queue_free()
		await process_frame
		quit(1)
		return
	if not hp_orb.size.is_equal_approx(Vector2(160.0, 160.0)) \
	or not mana_orb.size.is_equal_approx(Vector2(152.0, 152.0)):
		push_error("TEST: orb diameters no longer match their ornament apertures")
		hud.queue_free()
		await process_frame
		quit(1)
		return
	if not hp_orb.texture_under.get_size().is_equal_approx(hp_orb.size) \
	or not mana_orb.texture_under.get_size().is_equal_approx(mana_orb.size):
		push_error("TEST: native orb textures must match their controls to prevent top-left drift")
		hud.queue_free()
		await process_frame
		quit(1)
		return
	print("TEST PASSED: HUD hierarchy")
	hud.queue_free()
	await process_frame
	quit(0)
