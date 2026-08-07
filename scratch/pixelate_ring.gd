extends SceneTree

func _init() -> void:
	var src_path := "C:/Users/ipala/.gemini/antigravity-ide/brain/cfc6dca9-daa5-40a0-a9ca-62db24beeae0/copper_ring_retro_1786109043719.png"
	var dest_path := ProjectSettings.globalize_path("res://assets/items/copper_ring.png")
	
	var img := Image.new()
	var buffer := FileAccess.get_file_as_bytes(src_path)
	var err := img.load_webp_from_buffer(buffer)
	if err != OK:
		err = img.load_png_from_buffer(buffer)
	if err != OK:
		err = img.load_jpg_from_buffer(buffer)
		
	if img.is_empty():
		print("Failed to load source image, error: ", err)
		quit(1)
		return
		
	print("Original generated size: ", img.get_width(), "x", img.get_height())
	
	# Downscale to 32x32 (chunky pixels) using nearest neighbor
	img.resize(32, 32, Image.INTERPOLATE_NEAREST)
	
	# Upscale back to 96x96 with INTERPOLATE_NEAREST for sharp, huge pixels like Diablo 2 / retro RPG
	img.resize(96, 96, Image.INTERPOLATE_NEAREST)
	
	var save_err := img.save_png(dest_path)
	if save_err == OK:
		print("SUCCESSFULLY saved 96x96 retro pixelated ring icon to: ", dest_path)
		quit(0)
	else:
		print("Failed saving PNG, error: ", save_err)
		quit(1)
