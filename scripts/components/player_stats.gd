class_name PlayerStats
extends Node

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal experience_changed(level: int, current: int, maximum: int)
signal died

# ─── Базовые (без бонусов от атрибутов) ──────────────────────────────────────
@export var max_hp_base: int = 50
@export var max_mana_base: int = 25
@export var max_xp: int = 100
@export_range(0.0, 1.0, 0.01) var injured_threshold: float = 0.25

# ─── Бонусы от атрибутов (устанавливаются через apply_attribute_bonuses) ──────
var _hp_bonus: int = 0
var _mana_bonus: int = 0
var _hp_regen_per_sec: float = 0.0
var _mana_regen_per_sec: float = 0.0
var _dodge_chance: float = 0.0
var _armor_value: float = 0.0

# ─── Итоговые максимумы ───────────────────────────────────────────────────────
var max_hp: int:
	get: return max_hp_base + _hp_bonus
var max_energy: int:   # алиас для обратной совместимости с HUD
	get: return max_mana_base + _mana_bonus
var max_mana: int:
	get: return max_mana_base + _mana_bonus

# ─── Текущие значения ─────────────────────────────────────────────────────────
var current_hp: int
var current_energy: int  # алиас: это мана
var current_mana: int:
	get: return current_energy
	set(v): current_energy = v

var current_xp: int = 0
var level: int = 1
var is_dead: bool = false

# ─── Накопители регенерации (дробные HP/мана между тиками) ───────────────────
var _hp_regen_accum: float = 0.0
var _mana_regen_accum: float = 0.0


func _ready() -> void:
	current_hp = max_hp
	current_energy = max_mana


# ─── Интеграция с CharacterAttributes ────────────────────────────────────────

## Применить производные характеристики из CharacterAttributes.
## Принимает Node (CharacterAttributes) через duck-typing для избежания
## циклической зависимости при компиляции.
## Вызывается автоматически при изменении атрибутов.
func apply_attribute_bonuses(attr: Node) -> void:
	var old_max_hp   := max_hp
	var old_max_mana := max_mana

	_hp_bonus          = attr.get_max_hp_bonus()
	_mana_bonus        = attr.get_max_mana_bonus()
	_hp_regen_per_sec  = attr.get_hp_regen()
	_mana_regen_per_sec = attr.get_mana_regen()
	_dodge_chance      = attr.get_dodge_chance()
	if attr.has_method("get_total_armor"):
		_armor_value = attr.get_total_armor()

	# Пропорционально масштабировать текущее HP при изменении максимума
	if old_max_hp > 0 and max_hp != old_max_hp:
		current_hp = clampi(roundi(float(current_hp) * max_hp / old_max_hp), 0, max_hp)
	current_hp = clampi(current_hp, 0, max_hp)

	if old_max_mana > 0 and max_mana != old_max_mana:
		current_energy = clampi(roundi(float(current_energy) * max_mana / old_max_mana), 0, max_mana)
	current_energy = clampi(current_energy, 0, max_mana)

	health_changed.emit(current_hp, max_hp)
	energy_changed.emit(current_energy, max_mana)


# ─── Регенерация ─────────────────────────────────────────────────────────────

## Тик регенерации. Вызывать из Player._process(delta).
func tick_regen(delta: float) -> void:
	if is_dead:
		return
	var hp_changed := false
	var mana_changed := false

	if _hp_regen_per_sec > 0.0 and current_hp < max_hp:
		_hp_regen_accum += _hp_regen_per_sec * delta
		var whole := int(_hp_regen_accum)
		if whole > 0:
			_hp_regen_accum -= whole
			var prev := current_hp
			current_hp = mini(max_hp, current_hp + whole)
			hp_changed = current_hp != prev

	if _mana_regen_per_sec > 0.0 and current_energy < max_mana:
		_mana_regen_accum += _mana_regen_per_sec * delta
		var whole := int(_mana_regen_accum)
		if whole > 0:
			_mana_regen_accum -= whole
			var prev := current_energy
			current_energy = mini(max_mana, current_energy + whole)
			mana_changed = current_energy != prev

	if hp_changed:
		health_changed.emit(current_hp, max_hp)
	if mana_changed:
		energy_changed.emit(current_energy, max_mana)


# ─── Уклонение ───────────────────────────────────────────────────────────────

## Шанс уклонения (0.0–1.0) из атрибута Ловкости.
func get_dodge_chance() -> float:
	return _dodge_chance


# ─── HP ───────────────────────────────────────────────────────────────────────

func emit_current_values() -> void:
	health_changed.emit(current_hp, max_hp)
	energy_changed.emit(current_energy, max_mana)
	experience_changed.emit(level, current_xp, max_xp)


func take_damage(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	# Проверка уклонения
	if _dodge_chance > 0.0 and randf() < _dodge_chance:
		return 0
	var final_amount := maxi(1, roundi(float(amount) - _armor_value))
	var previous := current_hp
	current_hp = maxi(0, current_hp - final_amount)
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


# ─── Мана (energy) ───────────────────────────────────────────────────────────

func spend_energy(amount: int) -> bool:
	if amount < 0 or current_energy < amount:
		return false
	current_energy -= amount
	energy_changed.emit(current_energy, max_mana)
	return true


func restore_energy(amount: int) -> int:
	if amount <= 0:
		return 0
	var previous := current_energy
	current_energy = mini(max_mana, current_energy + amount)
	if current_energy != previous:
		energy_changed.emit(current_energy, max_mana)
	return current_energy - previous


func restore_energy_to_full() -> int:
	return restore_energy(max_mana - current_energy)


# ─── Опыт / Уровень ──────────────────────────────────────────────────────────

func gain_experience(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	while current_xp >= max_xp:
		current_xp -= max_xp
		level += 1
		max_xp = maxi(1, int(max_xp * 1.4))
		current_hp = max_hp
		current_energy = max_mana
		health_changed.emit(current_hp, max_hp)
		energy_changed.emit(current_energy, max_mana)
	experience_changed.emit(level, current_xp, max_xp)


func is_injured() -> bool:
	return max_hp > 0 and current_hp / float(max_hp) <= injured_threshold
