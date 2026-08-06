class_name PlayerStats
extends Node

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal experience_changed(level: int, current: int, maximum: int)
signal died

@export var max_hp: int = 100
@export var max_energy: int = 50
@export var max_xp: int = 100
@export_range(0.0, 1.0, 0.01) var injured_threshold: float = 0.25

var current_hp: int
var current_energy: int
var current_xp: int = 0
var level: int = 1
var is_dead: bool = false


func _ready() -> void:
	current_hp = max_hp
	current_energy = max_energy


func emit_current_values() -> void:
	health_changed.emit(current_hp, max_hp)
	energy_changed.emit(current_energy, max_energy)
	experience_changed.emit(level, current_xp, max_xp)


func take_damage(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var previous := current_hp
	current_hp = maxi(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		is_dead = true
		died.emit()
	return previous - current_hp


func restore_health(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var previous := current_hp
	current_hp = mini(max_hp, current_hp + amount)
	if current_hp != previous:
		health_changed.emit(current_hp, max_hp)
	return current_hp - previous


func restore_health_to_full() -> int:
	return restore_health(max_hp - current_hp)


func spend_energy(amount: int) -> bool:
	if amount < 0 or current_energy < amount:
		return false
	current_energy -= amount
	energy_changed.emit(current_energy, max_energy)
	return true


func restore_energy(amount: int) -> int:
	if amount <= 0:
		return 0
	var previous := current_energy
	current_energy = mini(max_energy, current_energy + amount)
	if current_energy != previous:
		energy_changed.emit(current_energy, max_energy)
	return current_energy - previous


func restore_energy_to_full() -> int:
	return restore_energy(max_energy - current_energy)


func gain_experience(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	while current_xp >= max_xp:
		current_xp -= max_xp
		level += 1
		max_xp = maxi(1, int(max_xp * 1.4))
		current_hp = max_hp
		current_energy = max_energy
		health_changed.emit(current_hp, max_hp)
		energy_changed.emit(current_energy, max_energy)
	experience_changed.emit(level, current_xp, max_xp)


func is_injured() -> bool:
	return max_hp > 0 and current_hp / float(max_hp) <= injured_threshold
