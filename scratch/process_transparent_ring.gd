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
		print("Failed loading image, error: ", err)
		quit(1)
		return
		
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	
	# Chroma key / background removal: detect background color from top-left pixel
	var bg_color: Color = img.get_pixel(4, 4)
	print("Detected background color: ", bg_color)
	
	for y in range(h):
		for x in range(w):
			var col: Color = img.get_pixel(x, y)
			# If pixel is close to green or background color
			var dist := Vector3(col.r - bg_color.r, col.g - bg_color.g, col.b - bg_color.b).length()
			var is_green := col.g > 0.38 and col.r < 0.40 and col.b < 0.40
			if dist < 0.30 or is_green:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	
	# Crop around item
	var rect: Rect2i = _get_alpha_rect(img)
	if rect.size.x > 0 and rect.size.y > 0:
		var cropped := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
		cropped.blit_rect(img, rect, Vector2i.ZERO)
		img = cropped
	
	# Downscale to 32x32 for big retro pixels
	var square_size: int = max(img.get_width(), img.get_height())
	var square := Image.create(square_size, square_size, false, Image.FORMAT_RGBA8)
	square.fill(Color(0, 0, 0, 0))
	var offset := Vector2i((square_size - img.get_width()) / 2, (square_size - img.get_height()) / 2)
	square.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), offset)
	
	square.resize(32, 32, Image.INTERPOLATE_NEAREST)
	square.resize(96, 96, Image.INTERPOLATE_NEAREST)
	
	var save_err := square.save_png(dest_path)
	if save_err == OK:
		print("SUCCESSFULLY saved transparent retro pixelated ring icon (96x96) to: ", dest_path)
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
