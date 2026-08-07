class_name FlaskData
extends Resource

@export var flask_id: StringName
@export var display_name: String
@export_enum("health", "mana") var resource_type: String = "health"
@export var icon: Texture2D
@export var liquid_tint: Color = Color.WHITE
@export_range(1, 20, 1) var max_charges: int = 3
@export_range(1, 1000, 1) var restore_amount: int = 30
@export_range(0.1, 120.0, 0.1) var recharge_seconds: float = 8.0
@export var input_action: StringName
@export var hotkey_label: String


func build_tooltip() -> String:
	var resource_name := "здоровья" if resource_type == "health" else "маны"
	return "%s\nВосстанавливает %d %s\nЗаряды: %d\n1 заряд за %.1f с" % [
		display_name,
		restore_amount,
		resource_name,
		max_charges,
		recharge_seconds,
	]
