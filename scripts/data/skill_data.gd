class_name SkillData
extends Resource

@export var skill_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var hotbar_slot: int = 1

@export_group("Combat")
@export var damage: int = 0
@export var mana_cost: int = 0
@export var cooldown: float = 0.0
@export var max_range: float = 0.0

@export_group("Casting")
@export var cast_animation: StringName
@export_range(0.0, 1.0, 0.01) var release_ratio: float = 0.0
@export var cast_speed: float = 1.0
@export var projectile_height: float = 1.0

@export_group("Projectile")
@export var effect_type: StringName = &"generic"
@export var projectile_speed: float = 0.0
@export var projectile_lifetime: float = 0.0
@export var projectile_color: Color = Color.WHITE
@export var explosion_radius: float = 0.0

@export_group("Status Effect")
@export var status_duration: float = 0.0
@export var status_potency: float = 1.0
@export var status_tick_damage: int = 0


func is_projectile_skill() -> bool:
	return projectile_speed > 0.0 and projectile_lifetime > 0.0
