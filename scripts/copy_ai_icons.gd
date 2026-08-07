@tool
extends MainLoop

func _process(_delta: float) -> bool:
	print("Начало физической обрезки и сохранения нейросетевых PNG иконок...")

	var brain_dir := "C:/Users/ipala/.gemini/antigravity-ide/brain/e24f06bb-0fe0-4578-91c0-f7e28ba9d40b/"
	var dest_dir := "res://textures/skills/"

	DirAccess.make_dir_absolute(dest_dir)

	var items := [
		{
			"src": brain_dir + "bare_fist_d2_ultrapixel_1786053388737.png",
			"dst": dest_dir + "fist_attack.png",
			"rect": Rect2i(244, 236, 528, 528)
		},
		{
			"src": brain_dir + "fireball_d2_ultrapixel_1786053403580.png",
			"dst": dest_dir + "fireball.png",
			"rect": Rect2i(215, 215, 594, 594)
		},
		{
			"src": brain_dir + "ice_arrow_d2_ultrapixel_1786053418745.png",
			"dst": dest_dir + "ice_arrow.png",
			"rect": Rect2i(208, 208, 608, 608)
		}
	]

	for item in items:
		var img := Image.load_from_file(item["src"])
		if img and not img.is_empty():
			print("Загружен нейро-арт: ", item["src"], " (", img.get_width(), "x", img.get_height(), ")")
			# Кропаем внутренний ассет
			var cropped := img.get_region(item["rect"])
			# Масштабируем до 128x128 
			cropped.resize(128, 128, Image.INTERPOLATE_LANCZOS)
			var err := cropped.save_png(item["dst"])
			if err == OK:
				print("УСПЕШНО СОХРАНЕНА НЕЙРО-ИКОНКА: ", item["dst"])
			else:
				print("ОШИБКА сохранения: ", err)
		else:
			print("ОШИБКА загрузки файла: ", item["src"])

	print("Готово!")
	return true
