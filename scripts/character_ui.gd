extends CanvasLayer

## Окно характеристик персонажа.
## Открывается клавишей C (action: character_screen).
## Стилистически идентично InventoryUI — одна система, одна команда дизайнеров.

signal opened
signal closed

var is_open: bool = false

## Ссылка на игрока для смещения камеры (устанавливается извне или через группу).
var player_ref: Node = null

# Внутренняя ссылка на панель для show/hide
@onready var _root_panel: Control = $RootPanel


func _ready() -> void:
	_root_panel.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Кнопки закрытия в TitleBar и Footer
	var close_title := _root_panel.find_child("CloseBtn", true, false) as Button
	if close_title:
		close_title.pressed.connect(close)
	var close_footer := _root_panel.find_child("FooterCloseBtn", true, false) as Button
	if close_footer:
		close_footer.pressed.connect(close)



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character_screen"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	refresh()
	_root_panel.show()
	_position_panel()
	_shift_camera(true)
	emit_signal("opened")


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root_panel.hide()
	_shift_camera(false)
	emit_signal("closed")


## Обновить значения текстовых меток в окне из атрибутов и статов игрока
func refresh() -> void:
	if not player_ref:
		_resolve_player()
	if not player_ref:
		return
		
	var attr: CharacterAttributes = player_ref.get_node_or_null("CharacterAttributes")
	var stats: PlayerStats = player_ref.get_node_or_null("PlayerStats")
	
	if attr:
		var pr1 := _root_panel.find_child("PR1Val", true, false) as Label
		if pr1: pr1.text = str(attr.strength)
		
		var pr2 := _root_panel.find_child("PR2Val", true, false) as Label
		if pr2: pr2.text = str(attr.dexterity)
		
		var pr4 := _root_panel.find_child("PR4Val", true, false) as Label
		if pr4: pr4.text = str(attr.intelligence)
		
		var cc3 := _root_panel.find_child("CC3Val", true, false) as Label
		if cc3: cc3.text = "%.1f%%" % (attr.get_dodge_chance() * 100.0)

		var crit_ch := _root_panel.find_child("CritChanceVal", true, false) as Label
		if crit_ch: crit_ch.text = "%.1f%%" % (attr.get_crit_chance() * 100.0)

		var crit_sc := _root_panel.find_child("CritScaleVal", true, false) as Label
		if crit_sc: crit_sc.text = "%.0f%%" % (attr.get_crit_multiplier() * 100.0)

		var mcrit_ch := _root_panel.find_child("MagicCritChanceVal", true, false) as Label
		if mcrit_ch: mcrit_ch.text = "%.1f%%" % (attr.get_magic_crit_chance() * 100.0)

		var mcrit_sc := _root_panel.find_child("MagicCritScaleVal", true, false) as Label
		if mcrit_sc: mcrit_sc.text = "%.0f%%" % (attr.get_magic_crit_multiplier() * 100.0)

		var rr_cold := _root_panel.find_child("RRColdVal", true, false) as Label
		if rr_cold: rr_cold.text = "0%"



		
	if stats:
		var lvl := _root_panel.find_child("LevelVal", true, false) as Label
		if lvl: lvl.text = str(stats.level)
		
		var d1 := _root_panel.find_child("D1Val", true, false) as Label
		if d1: d1.text = "%d / %d" % [stats.current_hp, stats.max_hp]
		
		var d2 := _root_panel.find_child("D2Val", true, false) as Label
		if d2: d2.text = "%d / %d" % [stats.current_energy, stats.max_mana]
		
		var xp_lbl := _root_panel.find_child("XPLabel", true, false) as Label
		if xp_lbl: xp_lbl.text = "ОПЫТ: %d / %d" % [stats.current_xp, stats.max_xp]

	# Расчет и вывод урона от ЛКМ
	var d3 := _root_panel.find_child("D3Val", true, false) as Label
	if d3:
		var lkm_skill: SkillData = player_ref.get("basic_attack_skill") as SkillData
		var base_dmg := lkm_skill.damage if lkm_skill else 25
		if attr:
			var mult := attr.get_damage_scaling({})
			d3.text = str(roundi(base_dmg * mult))
		else:
			d3.text = str(base_dmg)




# ─── Позиционирование ──────────────────────────────────────────────────────────

func _position_panel() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := _root_panel.get_combined_minimum_size()
	# Правый край с небольшим отступом, вертикально по центру
	var x := viewport_size.x - panel_size.x - 24.0
	var y := (viewport_size.y - panel_size.y) * 0.5
	y = clampf(y, 20.0, viewport_size.y - panel_size.y - 20.0)
	_root_panel.position = Vector2(x, y)


# ─── Смещение камеры ───────────────────────────────────────────────────────────

func _shift_camera(shift: bool) -> void:
	if not player_ref:
		_resolve_player()
	if not player_ref:
		return
	var camera: Camera3D = player_ref.get_node_or_null("CameraArm/Camera3D")
	if not camera:
		camera = player_ref.find_child("Camera3D", true, false) as Camera3D
	if not camera:
		return
	# Смещаем горизонтальный offset камеры так же, как это делает inventory_ui
	var arm: SpringArm3D = camera.get_parent() as SpringArm3D
	if arm:
		if shift:
			arm.position.x = lerp(arm.position.x, -1.8, 1.0)
		else:
			arm.position.x = lerp(arm.position.x, 0.0, 1.0)


func _resolve_player() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_ref = players[0]
