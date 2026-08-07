class_name CharacterAttributes
extends Node

## Компонент базовых атрибутов персонажа.
##
## Отвечает за три фундаментальных атрибута и вычисление производных
## характеристик. Не хранит текущее HP/ману — это зона PlayerStats.
##
## Поток данных:
##   CharacterAttributes → (attributes_changed) → PlayerStats.apply_attribute_bonuses()
##
## Расширение:
##   - Новый атрибут: добавить поле base_X, bonus_X, геттер X, производные
##   - Новая производная: добавить метод, не изменяя PlayerStats интерфейс


signal attributes_changed


# ─── Базовые очки (распределяемые игроком) ────────────────────────────────────

@export_group("Base Attributes")
@export var base_strength: int = 10
@export var base_dexterity: int = 10
@export var base_intelligence: int = 10


# ─── Бонусы от экипировки (пересчитываются при equip/unequip) ────────────────

var bonus_strength: int = 0
var bonus_dexterity: int = 0
var bonus_intelligence: int = 0
var equipment_armor_stat: int = 0


# ─── Итоговые атрибуты (read-only, пересчитываются через recalculate) ─────────

var strength: int = 0
var dexterity: int = 0
var intelligence: int = 0


func _ready() -> void:
	recalculate()


# ─── Пересчёт ─────────────────────────────────────────────────────────────────

## Пересчитать все итоговые атрибуты и уведомить слушателей.
## Вызывается при: старте, смене экипировки, распределении очков.
func recalculate() -> void:
	strength     = base_strength     + bonus_strength
	dexterity    = base_dexterity    + bonus_dexterity
	intelligence = base_intelligence + bonus_intelligence
	attributes_changed.emit()


# ─── Производные характеристики ───────────────────────────────────────────────

## Бонус к максимальному здоровью: +5 HP за 1 Силу
func get_max_hp_bonus() -> int:
	return strength * 5

## Регенерация здоровья в секунду: +0.1 за 1 Силу
func get_hp_regen() -> float:
	return strength * 0.1

## Шанс уклонения (0.0–1.0): +0.001 за 1 Ловкость (= 0.1% за единицу)
func get_dodge_chance() -> float:
	return dexterity * 0.001

## Бонус к максимальной мане: +3 за 1 Интеллект
func get_max_mana_bonus() -> int:
	return intelligence * 3

## Регенерация маны в секунду: +0.1 за 1 Интеллект
func get_mana_regen() -> float:
	return intelligence * 0.1

## Шанс критического удара от физ. урона (0.0–1.0): +0.001 за 1 Ловкость (= 0.1% за единицу)
func get_crit_chance() -> float:
	return dexterity * 0.001

## Скейл критического урона: Базово 150% (1.50) + 1% (0.01) за 1 Ловкость
func get_crit_multiplier() -> float:
	return 1.50 + (dexterity * 0.01)

## Шанс критического удара от маг. урона (0.0–1.0): базово 0% (Интеллект не дает шанс крита)
func get_magic_crit_chance() -> float:
	return 0.0

## Скейл критического магического урона: Базово 150% (1.50) + 1% (0.01) за 1 Интеллект
func get_magic_crit_multiplier() -> float:
	return 1.50 + (intelligence * 0.01)

## Эффективная броня: 1 единица брони на предмете даёт 0.1 итоговой брони
func get_armor_value(raw_armor: int) -> float:
	return raw_armor * 0.1

## Установить суммарный стат брони с экипировки и пересчитать характеристики
func set_equipment_armor(stat_val: int) -> void:
	equipment_armor_stat = stat_val
	recalculate()

## Итоговое значение брони персонажа
func get_total_armor() -> float:
	return equipment_armor_stat * 0.1




# ─── Требования снаряжения ────────────────────────────────────────────────────

## Проверить, выполнены ли требования к характеристикам для экипировки предмета.
## item — словарь из InventoryModel (содержит req_str, req_dex, req_int).
func can_equip(item: Dictionary) -> bool:
	if item.is_empty():
		return true
	return (
		strength     >= int(item.get("req_str", 0)) and
		dexterity    >= int(item.get("req_dex", 0)) and
		intelligence >= int(item.get("req_int", 0))
	)

## Объяснить, почему предмет нельзя экипировать (для тултипа).
## Возвращает пустую строку если требования выполнены.
func get_equip_fail_reason(item: Dictionary) -> String:
	if item.is_empty() or can_equip(item):
		return ""
	var parts: Array[String] = []
	var rs := int(item.get("req_str", 0))
	var rd := int(item.get("req_dex", 0))
	var ri := int(item.get("req_int", 0))
	if strength < rs:
		parts.append("Сила %d/%d" % [strength, rs])
	if dexterity < rd:
		parts.append("Ловкость %d/%d" % [dexterity, rd])
	if intelligence < ri:
		parts.append("Интеллект %d/%d" % [intelligence, ri])
	return "Требуется: " + ", ".join(parts)


# ─── Масштабирование урона ────────────────────────────────────────────────────

## Мультипликатор урона от атрибутов предмета.
## Коэффициенты задаются в ItemData: str_scaling, dex_scaling, int_scaling.
## Возвращает 1.0 для немасштабируемых предметов.
func get_damage_scaling(item: Dictionary) -> float:
	var s := float(item.get("str_scaling", 0.0))
	var d := float(item.get("dex_scaling", 0.0))
	var i := float(item.get("int_scaling", 0.0))
	if s == 0.0 and d == 0.0 and i == 0.0:
		return 1.0
	return 1.0 + s * strength + d * dexterity + i * intelligence


# ─── Отладка ──────────────────────────────────────────────────────────────────

func debug_summary() -> String:
	return (
		"STR:%d DEX:%d INT:%d | HP+%d Regen%.1f Dodge%.1f%% Mana+%d MRegen%.1f" % [
			strength, dexterity, intelligence,
			get_max_hp_bonus(), get_hp_regen(),
			get_dodge_chance() * 100.0,
			get_max_mana_bonus(), get_mana_regen()
		]
	)
