class_name CameraController3D
extends Node

@export var camera_pivot_path: NodePath = "CameraPivot"
@export var camera_path: NodePath = "CameraPivot/SpringArm3D/Camera3D"

var camera_pivot: Node3D = null
var camera: Camera3D = null

func _ready() -> void:
	var parent := get_parent()
	if parent:
		if parent.has_node(camera_pivot_path):
			camera_pivot = parent.get_node(camera_pivot_path)
		if parent.has_node(camera_path):
			camera = parent.get_node(camera_path)

func shift_camera_for_ui(ui_open: bool) -> void:
	if not camera: return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var target: float = 4.0 if ui_open else 0.0
	tw.tween_property(camera, "h_offset", target, 0.35) \
	  .set_trans(Tween.TRANS_CUBIC) \
	  .set_ease(Tween.EASE_OUT if ui_open else Tween.EASE_IN)
