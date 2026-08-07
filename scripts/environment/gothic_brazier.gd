extends StaticBody3D

@onready var flame_root: Node3D = $FlameRoot
@onready var fire_light: OmniLight3D = $FireLight

var phase := 0.0


func _ready() -> void:
	phase = global_position.x * 0.73 + global_position.z * 0.41


func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	var flicker := sin(time * 9.0 + phase) * 0.035 + sin(time * 14.0 - phase) * 0.018
	flame_root.position.y = 1.12 + flicker
	flame_root.scale = Vector3(1.0 - flicker * 0.8, 1.0 + flicker * 2.2, 1.0 - flicker * 0.8)
	fire_light.light_energy = 2.15 + sin(time * 11.0 + phase) * 0.18
