class_name HealthComponent
extends Node

signal changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export var max_health: int = 100

var current_health: int
var is_dead: bool = false


func _ready() -> void:
	reset(false)


func take_damage(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var previous := current_health
	current_health = maxi(0, current_health - amount)
	var applied := previous - current_health
	damaged.emit(applied)
	changed.emit(current_health, max_health)
	if current_health == 0:
		is_dead = true
		died.emit()
	return applied


func heal(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var previous := current_health
	current_health = mini(max_health, current_health + amount)
	var applied := current_health - previous
	if applied > 0:
		healed.emit(applied)
		changed.emit(current_health, max_health)
	return applied


func reset(emit_signal: bool = true) -> void:
	is_dead = false
	current_health = max_health
	if emit_signal:
		changed.emit(current_health, max_health)
