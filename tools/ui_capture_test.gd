extends SceneTree

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIRECTORY := "res://tmp/ui_qa"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var failure := await _capture_main_menu()
	if failure == OK:
		failure = await _capture_pause_menu()
	if failure == OK:
		failure = await _capture_game_ui()
	if failure == OK:
		print("UI_CAPTURE_OK: %s" % ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	else:
		push_error("UI_CAPTURE_FAILED: %s" % error_string(failure))
	quit(failure)


func _capture_main_menu() -> int:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	await process_frame
	var result := _save_viewport("main_menu.png")
	menu.queue_free()
	await process_frame
	return result


func _capture_game_ui() -> int:
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.035, 0.045, 0.04, 1.0)
	stage.add_child(backdrop)
	root.add_child(stage)

	var hud = load("res://scenes/hud.tscn").instantiate()
	var inventory = load("res://scenes/inventory_ui.tscn").instantiate()
	root.add_child(hud)
	root.add_child(inventory)
	await process_frame
	var flask_data: Array[FlaskData] = [
		load("res://data/flasks/basic_health_flask.tres"),
		load("res://data/flasks/basic_mana_flask.tres"),
	]
	hud.configure_flasks(flask_data)
	hud.update_flask_state(&"health", 2, 3, 0.72, 0.16)
	hud.update_flask_state(&"mana", 1, 3, 0.46, 0.38)
	hud.update_hp(100, 100)
	hud.update_energy(50, 50)
	hud.update_xp(7, 418, 900)
	hud.trigger_skill_cooldown(2, 4.5)
	hud.trigger_skill_cooldown(3, 1.8)
	await process_frame
	var hud_result := _save_viewport("hud.png")
	if hud_result != OK:
		return hud_result
	inventory.call("_open")
	await create_timer(0.45).timeout
	await process_frame
	var result := _save_viewport("hud_inventory.png")
	hud.queue_free()
	inventory.queue_free()
	stage.queue_free()
	await process_frame
	return result


func _capture_pause_menu() -> int:
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.055, 0.05, 0.045, 1.0)
	stage.add_child(backdrop)
	root.add_child(stage)
	var pause_menu = load("res://scenes/pause_menu.tscn").instantiate()
	root.add_child(pause_menu)
	await process_frame
	pause_menu.open_pause()
	await create_timer(0.1, true).timeout
	var result := _save_viewport("pause_menu.png")
	pause_menu.close_pause()
	pause_menu.queue_free()
	stage.queue_free()
	await process_frame
	return result


func _save_viewport(file_name: String) -> int:
	var image := root.get_texture().get_image()
	if image.is_empty():
		return ERR_CANT_CREATE
	return image.save_png(OUTPUT_DIRECTORY.path_join(file_name))
