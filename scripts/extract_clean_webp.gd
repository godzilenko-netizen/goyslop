@tool
extends MainLoop

func _process(_delta: float) -> bool:
	print("Извлечение WebP данных (RIFF) из файлов артефактов...")

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
		if bytes.size() > 12:
			var offset: int = -1
			for i in range(bytes.size() - 12):
				# Находим 'RIFF' и 'WEBP'
				if bytes[i] == 0x52 and bytes[i+1] == 0x49 and bytes[i+2] == 0x46 and bytes[i+3] == 0x46:
					if bytes[i+8] == 0x57 and bytes[i+9] == 0x45 and bytes[i+10] == 0x42 and bytes[i+11] == 0x50:
						offset = i
						break
			
			if offset != -1:
				var clean_bytes := bytes.slice(offset)
				print("НАЙДЕНА WebP RIFF СИГНАТУРА СО СМЕЩЕНИЯ: ", offset, " (байт: ", clean_bytes.size(), ")")
				var img := Image.new()
				var err := img.load_webp_from_buffer(clean_bytes)
				if err == OK and not img.is_empty():
					print("УСПЕШНО ЗАГРУЖЕН WebP АРТ! Размер: ", img.get_width(), "x", img.get_height())
					var cropped := img.get_region(item["rect"])
					cropped.resize(128, 128, Image.INTERPOLATE_LANCZOS)
					var save_err := cropped.save_png(item["dst"])
					if save_err == OK:
						print("🎉🎉🎉 СОХРАНЕНА КРАСИВАЯ 128x128 PNG ИКОНКА НЕЙРОСЕТИ: ", item["dst"])
					else:
						print("Ошибка сохранения: ", save_err)
				else:
					print("Ошибка декодирования WebP: ", err)
			else:
				print("Сигнатура WebP (RIFF) не найдена в файле: ", item["src"])
		else:
			print("Файл не найден или пуст: ", item["src"])

	print("Завершено!")
	return true
