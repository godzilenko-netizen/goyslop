extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if not packed:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for _f in range(90):
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("c:/Users/ipala/Desktop/игра/scratch/screenshot_test.png")
		print("Screenshot saved to scratch/screenshot_test.png")

	scene.queue_free()
	quit(0)
