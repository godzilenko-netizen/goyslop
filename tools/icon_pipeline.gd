extends SceneTree

const DEFAULT_SIZE := 128
const DEFAULT_MODE := "cover"
const DEFAULT_FILTER := "nearest"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_cli(OS.get_cmdline_user_args())
	if options.has("_error"):
		push_error(str(options["_error"]))
		_print_usage()
		quit(64)
		return
	if bool(options.get("help", false)):
		_print_usage()
		quit(0)
		return
	if bool(options.get("self_test", false)):
		quit(_run_self_test())
		return

	var exit_code := 0
	if options.has("manifest"):
		exit_code = _run_manifest(str(options["manifest"]))
	else:
		exit_code = _process_icon(options)
	quit(exit_code)


func _parse_cli(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var index := 0
	while index < args.size():
		var token := str(args[index])
		if token in ["--help", "-h"]:
			result["help"] = true
			index += 1
			continue
		if not token.begins_with("--"):
			result["_error"] = "Unexpected argument: %s" % token
			return result

		var raw_key := token.trim_prefix("--")
		if raw_key.contains("="):
			var parts := raw_key.split("=", true, 1)
			result[str(parts[0]).replace("-", "_")] = str(parts[1])
			index += 1
			continue

		var key := raw_key.replace("-", "_")
		if key in ["trim_alpha", "self_test"]:
			result[key] = true
			index += 1
			continue
		if key == "no_trim_alpha":
			result["trim_alpha"] = false
			index += 1
			continue
		if index + 1 >= args.size():
			result["_error"] = "Missing value for --%s" % raw_key
			return result
		result[key] = str(args[index + 1])
		index += 2
	return result


func _run_manifest(manifest_path: String) -> int:
	if not FileAccess.file_exists(manifest_path):
		push_error("Manifest not found: %s" % manifest_path)
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		push_error("Manifest must contain a JSON object: %s" % manifest_path)
		return ERR_PARSE_ERROR
	var manifest := parsed as Dictionary
	var items: Variant = manifest.get("items", [])
	if not items is Array or items.is_empty():
		push_error("Manifest must contain a non-empty 'items' array")
		return ERR_INVALID_DATA

	var defaults: Dictionary = manifest.get("defaults", {})
	var failures := 0
	for item in items:
		if not item is Dictionary:
			push_error("Every manifest item must be an object")
			failures += 1
			continue
		var item_options := defaults.duplicate(true)
		item_options.merge(item as Dictionary, true)
		if _process_icon(item_options) != OK:
			failures += 1
	if failures > 0:
		push_error("Icon pipeline failed for %d item(s)" % failures)
		return ERR_CANT_CREATE
	print("ICON_PIPELINE_BATCH_OK: %d icon(s)" % items.size())
	return OK


func _process_icon(options: Dictionary) -> int:
	var input_path := str(options.get("input", ""))
	var output_path := str(options.get("output", ""))
	if input_path.is_empty() or output_path.is_empty():
		push_error("Both --input and --output are required")
		return ERR_INVALID_PARAMETER
	if output_path.get_extension().to_lower() != "png":
		push_error("Output must use the .png extension: %s" % output_path)
		return ERR_INVALID_PARAMETER

	var decoded := _decode_image(input_path)
	if decoded.is_empty():
		return ERR_FILE_UNRECOGNIZED
	var image := decoded["image"] as Image
	image.convert(Image.FORMAT_RGBA8)

	var crop_rect := _parse_crop(options.get("crop", null), image.get_size())
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		push_error("Invalid crop rectangle for %s" % input_path)
		return ERR_INVALID_PARAMETER
	if crop_rect != Rect2i(Vector2i.ZERO, image.get_size()):
		image = image.get_region(crop_rect)

	if _as_bool(options.get("trim_alpha", false)):
		var alpha_threshold := clampi(int(options.get("alpha_threshold", 8)), 0, 255)
		var alpha_bounds := _find_alpha_bounds(image, alpha_threshold)
		if alpha_bounds.size.x <= 0 or alpha_bounds.size.y <= 0:
			push_error("Alpha trim removed the entire image: %s" % input_path)
			return ERR_INVALID_DATA
		image = image.get_region(alpha_bounds)

	var square_size := int(options.get("size", DEFAULT_SIZE))
	var output_width := int(options.get("width", square_size))
	var output_height := int(options.get("height", square_size))
	var padding := int(options.get("padding", 0))
	if output_width <= 0 or output_height <= 0 or padding < 0 \
	or padding * 2 >= output_width or padding * 2 >= output_height:
		push_error("Invalid dimensions/padding: %dx%d padding=%d" % [output_width, output_height, padding])
		return ERR_INVALID_PARAMETER

	var mode := str(options.get("mode", DEFAULT_MODE)).to_lower()
	if mode not in ["cover", "contain", "stretch"]:
		push_error("Unknown mode '%s'. Use cover, contain, or stretch." % mode)
		return ERR_INVALID_PARAMETER
	var filter_name := str(options.get("filter", DEFAULT_FILTER)).to_lower()
	var interpolation := _interpolation_from_name(filter_name)
	if interpolation < 0:
		push_error("Unknown filter '%s'. Use nearest, bilinear, cubic, trilinear, or lanczos." % filter_name)
		return ERR_INVALID_PARAMETER

	var background := Color.from_string(str(options.get("background", "#00000000")), Color(0, 0, 0, 0))
	var output_dimensions := Vector2i(output_width, output_height)
	var final_image := _fit_rect(image, output_dimensions, padding, mode, interpolation, background)
	var absolute_output := ProjectSettings.globalize_path(output_path) if output_path.begins_with("res://") else output_path
	var output_directory := absolute_output.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("Cannot create output directory: %s" % output_directory)
		return mkdir_error
	var save_error := final_image.save_png(absolute_output)
	if save_error != OK:
		push_error("Cannot save PNG '%s': %s" % [absolute_output, error_string(save_error)])
		return save_error

	print("ICON_PIPELINE_OK: %s [%s at byte %d] -> %s (%dx%d, %s/%s)" % [
		input_path,
		str(decoded["format"]),
		int(decoded["offset"]),
		output_path,
		output_width,
		output_height,
		mode,
		filter_name,
	])
	return OK


func _decode_image(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Input image not found: %s" % path)
		return {}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("Input image is empty: %s" % path)
		return {}

	var candidates: Array[Dictionary] = []
	var png_offset := _find_png_offset(bytes)
	if png_offset >= 0:
		candidates.append({"format": "PNG", "offset": png_offset})
	var webp_offset := _find_webp_offset(bytes)
	if webp_offset >= 0:
		candidates.append({"format": "WEBP", "offset": webp_offset})
	var jpeg_offset := _find_jpeg_offset(bytes)
	if jpeg_offset >= 0:
		candidates.append({"format": "JPEG", "offset": jpeg_offset})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["offset"]) < int(b["offset"]))

	for candidate in candidates:
		var offset := int(candidate["offset"])
		var payload := bytes.slice(offset)
		var image := Image.new()
		var decode_error := ERR_FILE_UNRECOGNIZED
		match str(candidate["format"]):
			"PNG": decode_error = image.load_png_from_buffer(payload)
			"WEBP": decode_error = image.load_webp_from_buffer(payload)
			"JPEG": decode_error = image.load_jpg_from_buffer(payload)
		if decode_error == OK and not image.is_empty():
			return {"image": image, "format": candidate["format"], "offset": offset}

	var fallback := Image.load_from_file(path)
	if fallback and not fallback.is_empty():
		return {"image": fallback, "format": "ENGINE_FALLBACK", "offset": 0}
	push_error("Unsupported or damaged image data: %s" % path)
	return {}


func _find_png_offset(bytes: PackedByteArray) -> int:
	for index in range(max(bytes.size() - 7, 0)):
		if bytes[index] == 0x89 and bytes[index + 1] == 0x50 and bytes[index + 2] == 0x4E and bytes[index + 3] == 0x47 \
		and bytes[index + 4] == 0x0D and bytes[index + 5] == 0x0A and bytes[index + 6] == 0x1A and bytes[index + 7] == 0x0A:
			return index
	return -1


func _find_webp_offset(bytes: PackedByteArray) -> int:
	for index in range(max(bytes.size() - 11, 0)):
		if bytes[index] == 0x52 and bytes[index + 1] == 0x49 and bytes[index + 2] == 0x46 and bytes[index + 3] == 0x46 \
		and bytes[index + 8] == 0x57 and bytes[index + 9] == 0x45 and bytes[index + 10] == 0x42 and bytes[index + 11] == 0x50:
			return index
	return -1


func _find_jpeg_offset(bytes: PackedByteArray) -> int:
	for index in range(max(bytes.size() - 2, 0)):
		if bytes[index] == 0xFF and bytes[index + 1] == 0xD8 and bytes[index + 2] == 0xFF:
			return index
	return -1


func _parse_crop(value: Variant, image_size: Vector2i) -> Rect2i:
	var full_rect := Rect2i(Vector2i.ZERO, image_size)
	if value == null or str(value).is_empty():
		return full_rect
	var parts: Array = []
	if value is Array:
		parts = value
	else:
		parts.assign(str(value).split(","))
	if parts.size() != 4:
		return Rect2i()
	var requested := Rect2i(
		int(str(parts[0]).strip_edges()),
		int(str(parts[1]).strip_edges()),
		int(str(parts[2]).strip_edges()),
		int(str(parts[3]).strip_edges())
	)
	return requested.intersection(full_rect)


func _find_alpha_bounds(image: Image, threshold: int) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	var normalized_threshold := float(threshold) / 255.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > normalized_threshold:
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _fit_rect(source: Image, output_size: Vector2i, padding: int, mode: String, interpolation: int, background: Color) -> Image:
	var inner_size := output_size - Vector2i.ONE * padding * 2
	var working := source.duplicate()
	working.convert(Image.FORMAT_RGBA8)

	if mode == "stretch":
		working.resize(inner_size.x, inner_size.y, interpolation)
	elif mode == "cover":
		var scale: float = max(float(inner_size.x) / working.get_width(), float(inner_size.y) / working.get_height())
		var resized_width: int = max(int(round(working.get_width() * scale)), inner_size.x)
		var resized_height: int = max(int(round(working.get_height() * scale)), inner_size.y)
		working.resize(resized_width, resized_height, interpolation)
		var crop_x: int = max(int((resized_width - inner_size.x) / 2.0), 0)
		var crop_y: int = max(int((resized_height - inner_size.y) / 2.0), 0)
		working = working.get_region(Rect2i(crop_x, crop_y, inner_size.x, inner_size.y))
	else:
		var scale: float = min(float(inner_size.x) / working.get_width(), float(inner_size.y) / working.get_height())
		var resized_width: int = max(int(round(working.get_width() * scale)), 1)
		var resized_height: int = max(int(round(working.get_height() * scale)), 1)
		working.resize(resized_width, resized_height, interpolation)

	var canvas := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(background)
	var destination := Vector2i(
		padding + (inner_size.x - working.get_width()) / 2,
		padding + (inner_size.y - working.get_height()) / 2
	)
	canvas.blit_rect(working, Rect2i(Vector2i.ZERO, working.get_size()), destination)
	return canvas


func _interpolation_from_name(filter_name: String) -> int:
	match filter_name:
		"nearest": return Image.INTERPOLATE_NEAREST
		"bilinear": return Image.INTERPOLATE_BILINEAR
		"cubic": return Image.INTERPOLATE_CUBIC
		"trilinear": return Image.INTERPOLATE_TRILINEAR
		"lanczos": return Image.INTERPOLATE_LANCZOS
		_: return -1


func _as_bool(value: Variant) -> bool:
	if value is bool:
		return value
	return str(value).to_lower() in ["1", "true", "yes", "on"]


func _run_self_test() -> int:
	var test_directory := ProjectSettings.globalize_path("user://icon_pipeline_self_test")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(test_directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("Self-test cannot create: %s" % test_directory)
		return mkdir_error

	var source_image := Image.create(16, 10, false, Image.FORMAT_RGBA8)
	source_image.fill(Color(0.9, 0.2, 0.1, 1.0))
	var valid_png := source_image.save_png_to_buffer()
	var disguised_png := PackedByteArray([0x42, 0x41, 0x44, 0x21, 0x00, 0x7F])
	disguised_png.append_array(valid_png)

	var input_path := test_directory.path_join("ai_icon_wrong_extension.webp")
	var output_path := test_directory.path_join("normalized.png")
	var input_file := FileAccess.open(input_path, FileAccess.WRITE)
	if not input_file:
		push_error("Self-test cannot write input file")
		return ERR_FILE_CANT_WRITE
	input_file.store_buffer(disguised_png)
	input_file.close()

	var result := _process_icon({
		"input": input_path,
		"output": output_path,
		"width": 48,
		"height": 32,
		"mode": "contain",
		"filter": "nearest",
		"background": "#00000000",
	})
	var normalized := Image.load_from_file(output_path) if result == OK else null
	var passed := normalized != null and not normalized.is_empty() and normalized.get_size() == Vector2i(48, 32)

	DirAccess.remove_absolute(input_path)
	DirAccess.remove_absolute(output_path)
	DirAccess.remove_absolute(test_directory)
	if not passed:
		push_error("ICON_PIPELINE_SELF_TEST_FAILED")
		return ERR_INVALID_DATA
	print("ICON_PIPELINE_SELF_TEST_OK: recovered prefixed PNG data from a .webp file")
	return OK


func _print_usage() -> void:
	print("""
Universal Godot icon pipeline

Single icon:
  godot --headless --path . --script res://tools/icon_pipeline.gd -- \\
    --input <file> --output res://textures/icons/name.png [options]

Batch:
  godot --headless --path . --script res://tools/icon_pipeline.gd -- \\
    --manifest res://tools/icon_manifest.example.json

Self-test:
  godot --headless --path . --script res://tools/icon_pipeline.gd -- --self-test

Options:
  --size 128
  --width 128
  --height 128
  --padding 0
  --mode cover|contain|stretch
  --filter nearest|bilinear|cubic|trilinear|lanczos
  --crop x,y,width,height
  --trim-alpha
  --alpha-threshold 8
  --background #00000000

The input extension is ignored when necessary. PNG, WebP, and JPEG are
detected by their byte signatures, including data with a junk prefix.
Use --size for square output or --width/--height for rectangular assets.
The output is always a normalized RGBA PNG for reliable Godot imports.
""")
