@tool
extends MainLoop

func _process(_delta: float) -> bool:
	print("Декодирование WebP буфера нейросетевых изображений и кроп...")

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
		var bytes := FileAccess.get_file_as_bytes(item["src"])
		if bytes.size() > 0:
			var img := Image.new()
			var err := img.load_webp_from_buffer(bytes)
			if err == OK and not img.is_empty():
				print("УСПЕШНО ДЕКОДИРОВАН WEBP АРТ! Размер: ", img.get_width(), "x", img.get_height())
				var cropped := img.get_region(item["rect"])
				cropped.resize(128, 128, Image.INTERPOLATE_LANCZOS)
				var save_err := cropped.save_png(item["dst"])
				if save_err == OK:
					print("СОХРАНЕНА КРАСИВАЯ НЕЙРО-ИКОНКА (PNG): ", item["dst"])
				else:
					print("Ошибка сохранения PNG: ", save_err)
			else:
				print("Ошибка декодирования WebP буфера: ", err)
		else:
			print("Файл пуст или не найден: ", item["src"])

	print("Всё выполнено!")
	return true
