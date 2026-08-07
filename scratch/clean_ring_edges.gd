extends SceneTree

func _init() -> void:
	var src_path := "C:/Users/ipala/.gemini/antigravity-ide/brain/cfc6dca9-daa5-40a0-a9ca-62db24beeae0/copper_ring_chroma_1786109079499.png"
	var dest_path := ProjectSettings.globalize_path("res://assets/items/copper_ring.png")
	
	var img := Image.new()
	var buffer := FileAccess.get_file_as_bytes(src_path)
	var err := img.load_webp_from_buffer(buffer)
	if err != OK:
		err = img.load_jpg_from_buffer(buffer)
	if err != OK:
		err = img.load_png_from_buffer(buffer)
		
	if img.is_empty():
		print("Failed loading image")
		quit(1)
		return
		
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	
	var bg_color: Color = img.get_pixel(4, 4)
	
	# Pass 1: Strict Chroma Key
	for y in range(h):
		for x in range(w):
			var col: Color = img.get_pixel(x, y)
			var green_dominance: float = col.g - maxf(col.r, col.b)
			# If pixel is background or has green dominance
			if green_dominance > 0.04 or col.g > 0.35 and col.r < 0.45 and col.b < 0.45:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	
	# Crop around item
	var rect: Rect2i = _get_alpha_rect(img)
	if rect.size.x > 0 and rect.size.y > 0:
		var cropped := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
		cropped.blit_rect(img, rect, Vector2i.ZERO)
		img = cropped
	
	# Fit into square canvas
	var square_size: int = max(img.get_width(), img.get_height())
	var square := Image.create(square_size, square_size, false, Image.FORMAT_RGBA8)
	square.fill(Color(0, 0, 0, 0))
	var offset := Vector2i((square_size - img.get_width()) / 2, (square_size - img.get_height()) / 2)
	square.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), offset)
	
	# Downscale to 32x32 for big retro pixels
	square.resize(32, 32, Image.INTERPOLATE_NEAREST)
	
	# Pass 2: Edge defringe on 32x32 grid to eliminate any lingering green pixels
	var sw: int = square.get_width()
	var sh: int = square.get_height()
	for y in range(sh):
		for x in range(sw):
			var col: Color = square.get_pixel(x, y)
			if col.a > 0.01:
				# If green is dominant over red/blue, remove green spill or make transparent
				if col.g > col.r * 0.9 and col.g > col.b * 0.9 and col.r < 0.5:
					square.set_pixel(x, y, Color(0, 0, 0, 0))
				elif col.g > maxf(col.r, col.b):
					col.g = maxf(col.r, col.b)
					square.set_pixel(x, y, col)
	
	# Upscale back to 96x96 with sharp nearest neighbor
	square.resize(96, 96, Image.INTERPOLATE_NEAREST)
	
	var save_err := square.save_png(dest_path)
	if save_err == OK:
		print("SUCCESSFULLY cleaned green edges and saved transparent retro ring (96x96) to: ", dest_path)
		quit(0)
	else:
		print("Failed saving PNG: ", save_err)
		quit(1)

func _get_alpha_rect(img: Image) -> Rect2i:
	var min_x: int = img.get_width()
	var min_y: int = img.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.05:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x >= min_x and max_y >= min_y:
		return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	return Rect2i()
