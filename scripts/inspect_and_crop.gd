@tool
extends MainLoop

func _process(_delta: float) -> bool:
	var path := "res://temp_ai/fist.png"
	var bytes := FileAccess.get_file_as_bytes(path)
	print("Размер байтов fist.png: ", bytes.size())
	if bytes.size() > 32:
		var header_hex := ""
		for i in range(32):
			header_hex += "%02X " % bytes[i]
		print("Первые 32 байта: ", header_hex)

		# Находим любая известная сигнатура
		for i in range(bytes.size() - 8):
			if bytes[i] == 0x89 and bytes[i+1] == 0x50 and bytes[i+2] == 0x4E and bytes[i+3] == 0x47:
				print("НАЙДЕН PNG НА СМЕЩЕНИИ: ", i)
			if bytes[i] == 0x52 and bytes[i+1] == 0x49 and bytes[i+2] == 0x46 and bytes[i+3] == 0x46:
				print("НАЙДЕН RIFF НА СМЕЩЕНИИ: ", i)
	return true
