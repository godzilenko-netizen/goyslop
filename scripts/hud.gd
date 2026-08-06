extends CanvasLayer
class_name GameHUD

const SkillDataType = preload("res://scripts/data/skill_data.gd")

@onready var hp_orb: TextureProgressBar = $Control/HPOrbContainer/HPOrb
@onready var hp_label: Label = $Control/HPOrbContainer/HPOrb/HPOrbLabel

@onready var energy_orb: TextureProgressBar = $Control/EnergyOrbContainer/EnergyOrb
@onready var energy_label: Label = $Control/EnergyOrbContainer/EnergyOrb/EnergyOrbLabel

@onready var xp_bar: ProgressBar = $Control/TopXPPanel/XPBar
@onready var xp_label: Label = $Control/TopXPPanel/XPBar/XPLabel

@onready var slot1_panel: PanelContainer = $Control/BottomCenterPanel/HotbarContainer/Slot1
@onready var slot1_icon: TextureRect = $Control/BottomCenterPanel/HotbarContainer/Slot1/FistIcon
@onready var slot1_cooldown: ColorRect = $Control/BottomCenterPanel/HotbarContainer/Slot1/CooldownOverlay

@onready var slot2_icon: TextureRect = $Control/BottomCenterPanel/HotbarContainer/Slot2/SkillIcon
@onready var slot2_cooldown: ColorRect = $Control/BottomCenterPanel/HotbarContainer/Slot2/CooldownOverlay

@onready var slot3_panel: PanelContainer = $Control/BottomCenterPanel/HotbarContainer/Slot3

# Карточки создаются в коде, не из .tscn
var skill1_tooltip: PanelContainer = null
var skill2_tooltip: PanelContainer = null
var skill3_tooltip: PanelContainer = null
var hovered_slot: int = 0  # 0=ничего, 1=slot1, 2=slot2, 3=slot3

# Оверлеи кулдауна на слотах
var slot2_cd_overlay: ColorRect = null
var slot3_cd_overlay: ColorRect = null

func _ready() -> void:
	_force_runtime_ui_layout()
	_setup_procedural_orbs()
	_create_locked_slot_overlays()
	_create_skill_cooldown_overlays()
	
	if slot1_cooldown:
		slot1_cooldown.visible = false
	if slot2_cooldown:
		slot2_cooldown.visible = false
	
	# Подключаем сигналы наведения мыши после создания тултипов
	var s1 = $Control/BottomCenterPanel/HotbarContainer/Slot1
	var s2 = $Control/BottomCenterPanel/HotbarContainer/Slot2
	var s3 = $Control/BottomCenterPanel/HotbarContainer/Slot3
	if s1:
		s1.mouse_entered.connect(func(): hovered_slot = 1; _refresh_tooltips())
		s1.mouse_exited.connect(func(): if hovered_slot == 1: hovered_slot = 0; _refresh_tooltips())
	if s2:
		s2.mouse_entered.connect(func(): hovered_slot = 2; _refresh_tooltips())
		s2.mouse_exited.connect(func(): if hovered_slot == 2: hovered_slot = 0; _refresh_tooltips())
	if s3:
		s3.mouse_entered.connect(func(): hovered_slot = 3; _refresh_tooltips())
		s3.mouse_exited.connect(func(): if hovered_slot == 3: hovered_slot = 0; _refresh_tooltips())

func _make_tooltip_style(border_col: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.07, 0.1, 0.97)
	s.border_width_left = 2; s.border_width_top = 2
	s.border_width_right = 2; s.border_width_bottom = 2
	s.border_color = border_col
	s.corner_radius_top_left = 8; s.corner_radius_top_right = 8
	s.corner_radius_bottom_right = 8; s.corner_radius_bottom_left = 8
	return s

func _make_tooltip_card(slot_offset_left: float, slot_offset_right: float) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(170, 120)
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.anchor_left = 0.5
	card.anchor_top = 1.0
	card.anchor_right = 0.5
	card.anchor_bottom = 1.0
	card.offset_left = slot_offset_left
	card.offset_top = -240.0
	card.offset_right = slot_offset_right
	card.offset_bottom = -100.0
	return card

func _fill_tooltip(card: PanelContainer, title_text: String, stats: Array) -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	for stat in stats:
		var lbl = Label.new()
		lbl.text = stat[0]
		lbl.add_theme_color_override("font_color", stat[1])
		lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(lbl)

func configure_skills(skills: Array[SkillDataType]) -> void:
	var root_control: Control = $Control
	var offsets := {
		1: Vector2(-308.0, -138.0),
		2: Vector2(-248.0, -78.0),
		3: Vector2(-188.0, -18.0),
	}
	var border_colors := {
		1: Color(0.8, 0.65, 0.3, 1.0),
		2: Color(1.0, 0.4, 0.1, 1.0),
		3: Color(0.3, 0.8, 1.0, 1.0),
	}
	for skill in skills:
		# Update texture on skill slot icon
		var slot_path := "Control/BottomCenterPanel/HotbarContainer/Slot%d" % skill.hotbar_slot
		if root_control.has_node(slot_path):
			var slot_node := root_control.get_node(slot_path)
			var icon_rect: TextureRect = slot_node.get_node_or_null("SkillIcon")
			if not icon_rect:
				icon_rect = slot_node.get_node_or_null("FistIcon")
			if icon_rect and skill.icon:
				icon_rect.texture = skill.icon

		if not offsets.has(skill.hotbar_slot):
			continue
		var offset: Vector2 = offsets[skill.hotbar_slot]
		var card := _make_tooltip_card(offset.x, offset.y)
		card.name = "Skill%dTooltipCard" % skill.hotbar_slot
		card.add_theme_stylebox_override("panel", _make_tooltip_style(border_colors[skill.hotbar_slot]))
		root_control.add_child(card)
		_fill_tooltip(card, skill.display_name, _build_skill_stats(skill))
		match skill.hotbar_slot:
			1: skill1_tooltip = card
			2: skill2_tooltip = card
			3: skill3_tooltip = card
	print("Skill tooltips and icons configured from SkillData")

func _build_skill_stats(skill: SkillDataType) -> Array:
	var result: Array = [
		["Урон: %d" % skill.damage, Color(1.0, 0.4, 0.4)],
		["Перезарядка: %.1fс" % skill.cooldown, Color(1.0, 0.84, 0.3)],
		["Расход маны: %d" % skill.mana_cost, Color(0.4, 0.8, 1.0)],
	]
	if skill.max_range > 0.0:
		result.append(["Дальность: %.0fм" % skill.max_range, Color(0.7, 1.0, 0.4)])
	if skill.status_duration > 0.0:
		result.append(["Эффект: %.1fс" % skill.status_duration, Color(0.7, 0.9, 1.0)])
	return result

func _create_locked_slot_overlays() -> void:
	# Заглушки на заблокированных слотах 4–8
	var hotbar = $Control/BottomCenterPanel/HotbarContainer
	var locked_slots = ["Slot4","Slot5","Slot6","Slot7","Slot8"]
	var lock_style = StyleBoxFlat.new()
	lock_style.bg_color = Color(0.05, 0.05, 0.07, 0.7)
	for slot_name in locked_slots:
		var slot = hotbar.get_node_or_null(slot_name)
		if not slot:
			continue
		var overlay = ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.55)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.anchor_left = 0.0; overlay.anchor_top = 0.0
		overlay.anchor_right = 1.0; overlay.anchor_bottom = 1.0
		overlay.offset_left = 0; overlay.offset_top = 0
		overlay.offset_right = 0; overlay.offset_bottom = 0
		slot.add_child(overlay)
		var lock_lbl = Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.add_theme_font_size_override("font_size", 20)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.anchor_left = 0.0; lock_lbl.anchor_top = 0.0
		lock_lbl.anchor_right = 1.0; lock_lbl.anchor_bottom = 1.0
		lock_lbl.offset_left = 0; lock_lbl.offset_top = 0
		lock_lbl.offset_right = 0; lock_lbl.offset_bottom = 0
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(lock_lbl)



func _create_skill_cooldown_overlays() -> void:
	# Процедурно создаём оверлеи кулдауна для слотов 2 и 3
	var slot2 = $Control/BottomCenterPanel/HotbarContainer/Slot2
	if slot2:
		slot2_cd_overlay = ColorRect.new()
		slot2_cd_overlay.color = Color(0, 0, 0, 0.72)
		slot2_cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot2_cd_overlay.anchor_left = 0.0
		slot2_cd_overlay.anchor_top = 0.0
		slot2_cd_overlay.anchor_right = 1.0
		slot2_cd_overlay.anchor_bottom = 0.0  # Закрыто по умолчанию
		slot2_cd_overlay.offset_left = 0
		slot2_cd_overlay.offset_right = 0
		slot2_cd_overlay.offset_top = 0
		slot2_cd_overlay.offset_bottom = 0
		slot2_cd_overlay.visible = false
		slot2.add_child(slot2_cd_overlay)
	
	var slot3 = $Control/BottomCenterPanel/HotbarContainer/Slot3
	if slot3:
		slot3_cd_overlay = ColorRect.new()
		slot3_cd_overlay.color = Color(0, 0, 0, 0.72)
		slot3_cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot3_cd_overlay.anchor_left = 0.0
		slot3_cd_overlay.anchor_top = 0.0
		slot3_cd_overlay.anchor_right = 1.0
		slot3_cd_overlay.anchor_bottom = 0.0
		slot3_cd_overlay.offset_left = 0
		slot3_cd_overlay.offset_right = 0
		slot3_cd_overlay.offset_top = 0
		slot3_cd_overlay.offset_bottom = 0
		slot3_cd_overlay.visible = false
		slot3.add_child(slot3_cd_overlay)



func _force_runtime_ui_layout() -> void:
	if energy_label:
		energy_label.anchor_left = 0.0
		energy_label.anchor_top = 0.0
		energy_label.anchor_right = 1.0
		energy_label.anchor_bottom = 1.0
		energy_label.offset_left = 0
		energy_label.offset_top = 0
		energy_label.offset_right = 0
		energy_label.offset_bottom = 0
		energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
	if hp_label:
		hp_label.anchor_left = 0.0
		hp_label.anchor_top = 0.0
		hp_label.anchor_right = 1.0
		hp_label.anchor_bottom = 1.0
		hp_label.offset_left = 0
		hp_label.offset_top = 0
		hp_label.offset_right = 0
		hp_label.offset_bottom = 0
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _process(_delta: float) -> void:
	_refresh_tooltips()

func _refresh_tooltips() -> void:
	var ctrl = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_CTRL)
	if skill1_tooltip:
		skill1_tooltip.visible = ctrl and hovered_slot == 1
	if skill2_tooltip:
		skill2_tooltip.visible = ctrl and hovered_slot == 2
	if skill3_tooltip:
		skill3_tooltip.visible = ctrl and hovered_slot == 3

func _setup_procedural_orbs() -> void:
	var hp_bg_tex = _create_circle_texture(Color(0.2, 0.05, 0.05, 0.85), Color(0.5, 0.4, 0.25, 1.0))
	var hp_fill_tex = _create_circle_texture(Color(0.88, 0.12, 0.12, 1.0), Color(1.0, 0.4, 0.4, 1.0))
	
	var energy_bg_tex = _create_circle_texture(Color(0.04, 0.12, 0.25, 0.85), Color(0.5, 0.4, 0.25, 1.0))
	var energy_fill_tex = _create_circle_texture(Color(0.12, 0.55, 0.95, 1.0), Color(0.4, 0.8, 1.0, 1.0))
	
	hp_orb.texture_under = hp_bg_tex
	hp_orb.texture_progress = hp_fill_tex
	
	energy_orb.texture_under = energy_bg_tex
	energy_orb.texture_progress = energy_fill_tex



func _create_circle_texture(fill_color: Color, border_color: Color) -> ImageTexture:
	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = 60.0
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius - 4.0:
				var factor = 1.0 - (dist / radius) * 0.25
				img.set_pixel(x, y, fill_color * factor)
			elif dist <= radius:
				img.set_pixel(x, y, border_color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				
	return ImageTexture.create_from_image(img)

func update_hp(current: int, maximum: int) -> void:
	hp_orb.max_value = maximum
	hp_orb.value = current
	hp_label.text = "%d / %d" % [current, maximum]

func update_energy(current: int, maximum: int) -> void:
	energy_orb.max_value = maximum
	energy_orb.value = current
	energy_label.text = "%d / %d" % [current, maximum]

func update_xp(level: int, current: int, maximum: int) -> void:
	xp_bar.max_value = maximum
	xp_bar.value = current
	if xp_label:
		xp_label.text = "Lvl %d — %d / %d XP" % [level, current, maximum]

func trigger_attack_cooldown(duration: float) -> void:
	if not slot1_cooldown:
		return
	slot1_cooldown.anchor_left = 0.0
	slot1_cooldown.anchor_right = 1.0
	slot1_cooldown.anchor_top = 0.0
	slot1_cooldown.anchor_bottom = 1.0
	slot1_cooldown.offset_left = 0
	slot1_cooldown.offset_right = 0
	slot1_cooldown.offset_top = 0
	slot1_cooldown.offset_bottom = 0
	slot1_cooldown.visible = true
	
	var tween = create_tween()
	tween.tween_property(slot1_cooldown, "anchor_top", 1.0, duration)
	await tween.finished
	slot1_cooldown.visible = false
	slot1_cooldown.anchor_top = 0.0

func trigger_skill_cooldown(slot_index: int, duration: float) -> void:
	# Кулдаун на слотах 2 и 3: оверлей скользит сверху вниз (как в настоящих RPG)
	var overlay: ColorRect = null
	if slot_index == 2:
		overlay = slot2_cd_overlay
	elif slot_index == 3:
		overlay = slot3_cd_overlay
	
	if not overlay:
		return
	
	# Сбрасываем до начального состояния
	overlay.anchor_top = 0.0
	overlay.anchor_bottom = 1.0
	overlay.offset_top = 0
	overlay.offset_bottom = 0
	overlay.visible = true
	
	# Анимация: оверлей сжимается сверху вниз (АНЧОР топ идёт от 0 до 1)
	var tween = create_tween()
	tween.tween_property(overlay, "anchor_bottom", 0.0, duration).from(1.0)
	await tween.finished
	overlay.visible = false
	overlay.anchor_bottom = 1.0
