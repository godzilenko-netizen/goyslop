## Unit-тест системы атрибутов персонажа.
## Запуск: godot --headless -s scratch/test_attributes.gd
extends SceneTree

const CharAttrScript = preload("res://scripts/components/character_attributes.gd")
const PlayerStatsScript = preload("res://scripts/components/player_stats.gd")

var _pass := 0
var _fail := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== CharacterAttributes Tests ===")
	_test_base_attributes()
	_test_derived_stats()
	_test_equipment_requirements()
	_test_damage_scaling()
	_test_player_stats_integration()
	_test_regen_tick()
	print("\nResults: %d passed, %d failed" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _assert(label: String, condition: bool) -> void:
	if condition:
		print("  ✅ %s" % label)
		_pass += 1
	else:
		print("  ❌ FAIL: %s" % label)
		_fail += 1

func _assert_eq(label: String, a: Variant, b: Variant) -> void:
	_assert("%s  (%s == %s)" % [label, str(a), str(b)], a == b)

func _assert_near(label: String, a: float, b: float, eps: float = 0.001) -> void:
	_assert("%s  (%.4f ≈ %.4f)" % [label, a, b], absf(a - b) <= eps)

func _make_attr(str_val: int = 10, dex_val: int = 10, int_val: int = 10) -> Object:
	var attr := CharAttrScript.new()
	attr.base_strength     = str_val
	attr.base_dexterity    = dex_val
	attr.base_intelligence = int_val
	attr._ready()
	return attr


# ─── Tests ────────────────────────────────────────────────────────────────────

func _test_base_attributes() -> void:
	print("\n[Base Attributes]")
	var attr := _make_attr(15, 20, 12)
	_assert_eq("strength == 15",     attr.strength,     15)
	_assert_eq("dexterity == 20",    attr.dexterity,    20)
	_assert_eq("intelligence == 12", attr.intelligence, 12)


func _test_derived_stats() -> void:
	print("\n[Derived Stats — base 10 each]")
	var attr := _make_attr(10, 10, 10)
	# STR 10 → HP+50, regen 1.0
	_assert_eq("max_hp_bonus = 10*5 = 50",    attr.get_max_hp_bonus(), 50)
	_assert_near("hp_regen = 10*0.1 = 1.0",   attr.get_hp_regen(),    1.0)
	# DEX 10 → dodge 0.01 (1.0%), crit_chance 0.01 (1.0%), crit_multiplier 1.60 (160%)
	_assert_near("dodge = 10*0.001 = 0.01",   attr.get_dodge_chance(), 0.01)
	_assert_near("crit_chance = 10*0.001 = 0.01", attr.get_crit_chance(), 0.01)
	_assert_near("crit_multiplier = 1.50 + 10*0.01 = 1.60", attr.get_crit_multiplier(), 1.60)
	# INT 10 → mana+30, mana_regen 1.0, magic_crit_chance 0.0 (0%), magic_crit_multiplier 1.60 (160%)
	_assert_eq("max_mana_bonus = 10*3 = 30",  attr.get_max_mana_bonus(), 30)
	_assert_near("mana_regen = 10*0.1 = 1.0", attr.get_mana_regen(),    1.0)
	_assert_near("magic_crit_chance = 0.0",   attr.get_magic_crit_chance(), 0.0)
	_assert_near("magic_crit_multiplier = 1.50 + 10*0.01 = 1.60", attr.get_magic_crit_multiplier(), 1.60)

	print("\n[Derived Stats — STR 20, DEX 50, INT 5]")
	var attr2 := _make_attr(20, 50, 5)
	_assert_eq("hp_bonus = 20*5 = 100",   attr2.get_max_hp_bonus(),  100)
	_assert_near("hp_regen = 20*0.1 = 2.0", attr2.get_hp_regen(),   2.0)
	_assert_near("dodge = 50*0.001 = 0.05", attr2.get_dodge_chance(), 0.05)
	_assert_near("crit_chance = 50*0.001 = 0.05", attr2.get_crit_chance(), 0.05)
	_assert_near("crit_multiplier = 1.50 + 50*0.01 = 2.00", attr2.get_crit_multiplier(), 2.00)
	_assert_eq("mana_bonus = 5*3 = 15",  attr2.get_max_mana_bonus(),  15)
	_assert_near("mana_regen = 5*0.1 = 0.5", attr2.get_mana_regen(), 0.5)
	_assert_near("magic_crit_chance = 0.0",   attr2.get_magic_crit_chance(), 0.0)
	_assert_near("magic_crit_multiplier = 1.50 + 5*0.01 = 1.55", attr2.get_magic_crit_multiplier(), 1.55)




func _test_equipment_requirements() -> void:
	print("\n[Equipment Requirements]")
	var attr := _make_attr(15, 20, 10)

	var item_ok := {"req_str": 15, "req_dex": 10, "req_int": 0}
	_assert("can_equip when exactly meeting reqs", attr.can_equip(item_ok))

	var item_fail_str := {"req_str": 20, "req_dex": 10, "req_int": 0}
	_assert("cannot equip — STR too low", not attr.can_equip(item_fail_str))

	var item_fail_dex := {"req_str": 10, "req_dex": 25, "req_int": 0}
	_assert("cannot equip — DEX too low", not attr.can_equip(item_fail_dex))

	var item_no_reqs := {"req_str": 0, "req_dex": 0, "req_int": 0}
	_assert("can_equip with zero requirements", attr.can_equip(item_no_reqs))

	var item_empty := {}
	_assert("can_equip empty item dict", attr.can_equip(item_empty))

	# Сообщение о провале
	var reason: String = attr.get_equip_fail_reason(item_fail_str)
	_assert("fail reason non-empty for unmet req", reason.length() > 0)
	_assert("fail reason empty for met req",       attr.get_equip_fail_reason(item_ok).is_empty())


func _test_damage_scaling() -> void:
	print("\n[Damage Scaling]")
	var attr := _make_attr(20, 15, 10)

	var no_scale := {}
	_assert_near("no scaling → 1.0", attr.get_damage_scaling(no_scale), 1.0)

	# str_scaling 0.01 → 1.0 + 0.01*20 = 1.20
	var str_item := {"str_scaling": 0.01, "dex_scaling": 0.0, "int_scaling": 0.0}
	_assert_near("str_scaling 0.01 * 20 → 1.20", attr.get_damage_scaling(str_item), 1.20)

	# mixed: 0.01*20 + 0.01*15 = 0.35 → 1.35
	var mixed := {"str_scaling": 0.01, "dex_scaling": 0.01, "int_scaling": 0.0}
	_assert_near("mixed scaling → 1.35", attr.get_damage_scaling(mixed), 1.35)


func _test_player_stats_integration() -> void:
	print("\n[PlayerStats + CharacterAttributes Integration]")
	var attr := CharAttrScript.new()
	attr.base_strength     = 10
	attr.base_dexterity    = 10
	attr.base_intelligence = 10
	attr._ready()
	var ps := PlayerStatsScript.new()
	ps._ready()

	# До применения атрибутов (дефолтные базовые значения: 50 HP, 25 Mana)
	_assert_eq("default max_hp_base == 50", ps.max_hp_base, 50)
	_assert_eq("default max_mana_base == 25", ps.max_mana_base, 25)
	_assert_eq("max_hp before = 50", ps.max_hp, 50)
	_assert_eq("max_mana before = 25", ps.max_mana, 25)

	ps.call("apply_attribute_bonuses", attr)
	# STR 10 → +50 HP (total 100), INT 10 → +30 mana (total 55)
	_assert_eq("max_hp after = 100 (50+50)", ps.max_hp, 100)
	_assert_eq("max_mana after = 55 (25+30)", ps.max_mana, 55)

	# Проверяем alias max_energy
	_assert_eq("max_energy alias == max_mana", ps.max_energy, ps.max_mana)

	attr.base_strength = 20
	attr.recalculate()
	ps.call("apply_attribute_bonuses", attr)
	# STR 20 → +100 HP (total 150)
	_assert_eq("max_hp after STR=20 = 150 (50+100)", ps.max_hp, 150)

	ps.free()
	attr.free()



func _test_regen_tick() -> void:
	print("\n[Regen Tick]")
	var attr := CharAttrScript.new()
	attr.base_strength     = 10
	attr.base_dexterity    = 0
	attr.base_intelligence = 10
	attr._ready()
	var ps := PlayerStatsScript.new()
	ps.max_hp_base   = 100
	ps.max_mana_base = 50
	ps._ready()
	ps.call("apply_attribute_bonuses", attr)

	# Урон — убрать HP и ману
	ps.current_hp     = 100
	ps.current_energy = 50

	# Целенаправленно уменьшим
	ps.current_hp     = ps.max_hp - 5
	ps.current_energy = ps.max_mana - 5

	# Тик 1 секунда (regen 1.0 hp/s и 1.0 mana/s → должен добавить 1 каждый)
	var hp_before   := ps.current_hp
	var mana_before := ps.current_energy
	ps.tick_regen(1.0)
	_assert("hp restored by 1 in 1s tick",   ps.current_hp     == hp_before + 1)
	_assert("mana restored by 1 in 1s tick",  ps.current_energy == mana_before + 1)

	# Тик 0.5 секунды (накопитель не достиг 1 — не должно изменяться)
	hp_before   = ps.current_hp
	mana_before = ps.current_energy
	ps.tick_regen(0.5)
	_assert("no regen in 0.5s tick (accum < 1)", ps.current_hp == hp_before)

	# Тик ещё 0.5 → суммарно 1.0 — должен добавить 1
	ps.tick_regen(0.5)
	_assert("regen after 0.5+0.5s accumulation", ps.current_hp == hp_before + 1)

	# Не должен превышать максимум
	ps.current_hp     = ps.max_hp
	ps.current_energy = ps.max_mana
	ps._hp_regen_accum   = 0.0
	ps._mana_regen_accum = 0.0
	ps.tick_regen(100.0)
	_assert("hp capped at max_hp",  ps.current_hp     == ps.max_hp)
	_assert("mana capped at max_mana", ps.current_energy == ps.max_mana)

	ps.free()
	attr.free()
