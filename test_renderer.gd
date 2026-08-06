extends SceneTree


func _init() -> void:
	var driver := RenderingServer.get_current_rendering_driver_name().to_lower()
	print("Rendering driver: ", driver)
	if "opengl" not in driver:
		push_error("TEST: expected OpenGL compatibility driver, got " + driver)
		quit(1)
		return
	print("TEST PASSED: OpenGL compatibility renderer")
	quit(0)
