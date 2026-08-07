extends Label
class_name FloatingLabel

var target_node: Node3D = null
var offset_3d: Vector3 = Vector3.UP * 1.5
var camera_ref: Camera3D = null
var hide_when_far: bool = false
var max_distance: float = 20.0
var manual_visibility: bool = true


static func create(target: Node3D, offset: Vector3 = Vector3.UP * 1.5) -> FloatingLabel:
	var label := FloatingLabel.new()
	label.target_node = target
	label.offset_3d = offset
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.74))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.96))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 14)
	
	var root_node := target.get_tree().root
	var overlay := root_node.get_node_or_null("WorldLabelOverlay") as CanvasLayer
	if not overlay:
		overlay = CanvasLayer.new()
		overlay.name = "WorldLabelOverlay"
		overlay.layer = 14
		root_node.add_child(overlay)
	overlay.add_child(label)
	return label


func _process(_delta: float) -> void:
	if not manual_visibility or not target_node or not is_instance_valid(target_node) or not target_node.is_visible_in_tree():
		visible = false
		return
		
	if not camera_ref or not is_instance_valid(camera_ref):
		camera_ref = get_viewport().get_camera_3d()
		if not camera_ref:
			visible = false
			return
			
	var target_pos := target_node.global_position + offset_3d
	if camera_ref.is_position_behind(target_pos):
		visible = false
		return
		
	if hide_when_far and camera_ref.global_position.distance_to(target_pos) > max_distance:
		visible = false
		return
		
	var screen_pos := camera_ref.unproject_position(target_pos)
	position = screen_pos - size * 0.5
	visible = true
