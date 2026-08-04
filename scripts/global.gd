extends Node

var current_save_name: String = "DefaultSave"

func set_save_name(save_name: String) -> void:
	var trimmed = save_name.strip_edges()
	if trimmed != "":
		current_save_name = trimmed
	else:
		current_save_name = "Безымянный_Сейв"
	print("Имя сохранения установлено: ", current_save_name)

func apply_resolution(index: int) -> void:
	var resolutions = [
		Vector2i(1920, 1080),
		Vector2i(1280, 720),
		Vector2i(640, 360)
	]
	if index >= 0 and index < resolutions.size():
		DisplayServer.window_set_size(resolutions[index])

func set_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
