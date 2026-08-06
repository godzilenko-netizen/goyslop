extends Area3D

@export_enum("Health", "Mana") var type: String = "Health"
@export var rotate_speed: float = 2.0
@export var float_speed: float = 2.0
@export var float_amplitude: float = 0.2

var start_y: float

func _ready() -> void:
	start_y = position.y
	
	body_entered.connect(_on_body_entered)
	
	# Configure visual based on type
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.8)
	
	if type == "Health":
		mat.albedo_color = Color(1.0, 0.2, 0.2, 0.8)
		mat.emission = Color(1.0, 0.1, 0.1)
		$Particles.process_material.color = Color(1.0, 0.2, 0.2)
	else:
		mat.albedo_color = Color(0.2, 0.4, 1.0, 0.8)
		mat.emission = Color(0.1, 0.3, 1.0)
		$Particles.process_material.color = Color(0.2, 0.4, 1.0)
		
	if $MeshInstance3D:
		$MeshInstance3D.material_override = mat

func _process(delta: float) -> void:
	rotation.y += rotate_speed * delta
	position.y = start_y + sin(Time.get_ticks_msec() / 1000.0 * float_speed) * float_amplitude

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if type == "Health":
			if body.has_method("restore_health_to_full"):
				body.restore_health_to_full()
		else:
			if body.has_method("restore_energy_to_full"):
				body.restore_energy_to_full()
			
		# Optional: Spawn a quick sound or explosion here before queue_free
		queue_free()
