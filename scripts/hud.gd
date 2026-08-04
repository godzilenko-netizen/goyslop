extends CanvasLayer

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
	_setup_slot1_fist_icon()
	_setup_slot2_fireball_icon()
	_setup_slot3_ice_arrow_icon()
	_create_tooltip_in_code()
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

func _create_tooltip_in_code() -> void:
	var root_control: Control = $Control
	
	# Удаляем старые из tscn если есть
	for old_name in ["Skill1TooltipCard", "Skill2TooltipCard", "Skill3TooltipCard"]:
		var old = root_control.get_node_or_null(old_name)
		if old:
			old.queue_free()

	# Шаг слота = 54px + 6px gap = 60px, панель шириню 516px, начинается от -258px
	# Центр слота N: -258 + (N-1)*60 + 8 + 27 = -258 + (N-1)*60 + 35
	# Слот 1: -223, Слот 2: -163, Слот 3: -103
	# Тултип (170px ширина): центр - 85 до центр + 85

	# Слот 1: Удар кулаком  (центр -223 от центра)
	skill1_tooltip = _make_tooltip_card(-308.0, -138.0)
	skill1_tooltip.name = "Skill1TooltipCard"
	skill1_tooltip.add_theme_stylebox_override("panel", _make_tooltip_style(Color(0.8, 0.65, 0.3, 1.0)))
	root_control.add_child(skill1_tooltip)
	_fill_tooltip(skill1_tooltip, "Удар кулаком", [
		["⚔️  Урон: 25", Color(1.0, 0.4, 0.4)],
		["⏳ Перезарядка: 0.6с", Color(1.0, 0.84, 0.3)],
		["💧 Расход маны: 0", Color(0.4, 0.8, 1.0)],
	])

	# Слот 2: Огненный шар (центр -163)
	skill2_tooltip = _make_tooltip_card(-248.0, -78.0)
	skill2_tooltip.name = "Skill2TooltipCard"
	skill2_tooltip.add_theme_stylebox_override("panel", _make_tooltip_style(Color(1.0, 0.4, 0.1, 1.0)))
	root_control.add_child(skill2_tooltip)
	_fill_tooltip(skill2_tooltip, "Огненный шар", [
		["🔥 Урон: 80", Color(1.0, 0.4, 0.1)],
		["⏳ Перезарядка: 3.0с", Color(1.0, 0.84, 0.3)],
		["💧 Расход маны: 30", Color(0.4, 0.8, 1.0)],
		["🎯 Дальность: 15м", Color(0.7, 1.0, 0.4)],
	])

	# Слот 3: Ледяная стрела (центр -103)
	skill3_tooltip = _make_tooltip_card(-188.0, -18.0)
	skill3_tooltip.name = "Skill3TooltipCard"
	skill3_tooltip.add_theme_stylebox_override("panel", _make_tooltip_style(Color(0.3, 0.8, 1.0, 1.0)))
	root_control.add_child(skill3_tooltip)
	_fill_tooltip(skill3_tooltip, "Ледяная стрела", [
		["❄️ Урон: 45", Color(0.5, 0.9, 1.0)],
		["⏳ Перезарядка: 5.0с", Color(1.0, 0.84, 0.3)],
		["💧 Расход маны: 20", Color(0.4, 0.8, 1.0)],
		["🐜 Замедляет врага 2.5с", Color(0.7, 0.9, 1.0)],
	])
	print("✅ Карточки 3 скиллов созданы!")

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

func _setup_slot2_fireball_icon() -> void:
	if slot2_icon:
		slot2_icon.texture = _create_fireball_texture()

func _setup_slot3_ice_arrow_icon() -> void:
	var slot3 = $Control/BottomCenterPanel/HotbarContainer/Slot3
	if not slot3:
		return
	var icon = TextureRect.new()
	icon.expand_mode = 1
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _create_ice_arrow_texture()
	icon.anchor_left = 0.0; icon.anchor_top = 0.0
	icon.anchor_right = 1.0; icon.anchor_bottom = 1.0
	icon.offset_left = 4; icon.offset_top = 4
	icon.offset_right = -4; icon.offset_bottom = -4
	slot3.add_child(icon)

func _create_ice_arrow_texture() -> ImageTexture:
	var size = 32
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Стела стрелы (diagonally)
	var c_ice = Color(0.55, 0.92, 1.0, 1.0)
	var c_glow = Color(0.3, 0.75, 1.0, 0.7)
	var c_tip = Color(1.0, 1.0, 1.0, 1.0)
	# Диагональное тело
	for i in range(22):
		var px = 4 + i
		var py = 27 - i
		if px < size and py >= 0:
			img.set_pixel(px, py, c_ice)
			if px + 1 < size and py - 1 >= 0:
				img.set_pixel(px + 1, py, c_glow)
				img.set_pixel(px, py - 1, c_glow)
	# Наконечник
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var px = 5 + dx
			var py = 26 + dy
			if px >= 0 and px < size and py >= 0 and py < size:
				img.set_pixel(px, py, c_tip)
	# Хвост (3 перья)
	var feathers = [[23, 7], [24, 8], [22, 6], [21, 9], [25, 9]]
	for f in feathers:
		if f[0] < size and f[1] < size:
			img.set_pixel(f[0], f[1], c_ice)
	# Иней
	var frost = [[12, 16], [13, 15], [14, 14], [11, 17], [15, 13]]
	for fr in frost:
		if fr[0] < size and fr[1] < size:
			img.set_pixel(fr[0], fr[1], Color(0.8, 0.95, 1.0, 0.85))
	return ImageTexture.create_from_image(img)

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

func _create_fireball_texture() -> ImageTexture:
	var size = 32
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(16, 16)
	for x in range(size):
		for y in range(size):
			var d = Vector2(x, y).distance_to(center)
			if d < 10:
				var t = 1.0 - d / 10.0
				var col = Color(1.0, 0.2 + t * 0.5, 0.0, t)
				img.set_pixel(x, y, col)
	# Искры
	var sparks = [[8,5],[7,6],[6,8],[5,10],[23,7],[24,9],[25,11],[16,4],[16,3]]
	for s in sparks:
		if s[0] < size and s[1] < size:
			img.set_pixel(s[0], s[1], Color(1.0, 0.9, 0.2, 0.9))
	return ImageTexture.create_from_image(img)

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

func _setup_slot1_fist_icon() -> void:
	if slot1_icon:
		slot1_icon.texture = _create_fist_texture()

func _create_fist_texture() -> ImageTexture:
	var size = 32
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var c_skin = Color(0.98, 0.76, 0.42, 1.0)
	var c_light = Color(1.0, 0.9, 0.65, 1.0)
	var c_shadow = Color(0.72, 0.45, 0.22, 1.0)
	var c_outline = Color(0.18, 0.12, 0.08, 1.0)
	var c_glove = Color(0.85, 0.25, 0.18, 1.0)
	var c_aura = Color(1.0, 0.85, 0.3, 0.8)
	
	for x in range(10, 22):
		for y in range(23, 29):
			img.set_pixel(x, y, c_glove)
			
	for x in range(8, 24):
		for y in range(9, 23):
			img.set_pixel(x, y, c_skin)
			
	for x in range(9, 23):
		for y in range(9, 12):
			img.set_pixel(x, y, c_light)
			
	for y in [13, 17, 20]:
		for x in range(9, 23):
			img.set_pixel(x, y, c_shadow)
			
	for x in range(6, 12):
		for y in range(15, 21):
			img.set_pixel(x, y, c_skin)
			
	var spark_pixels = [[5,6], [6,5], [25,6], [26,5], [4,14], [27,14], [5,22], [26,22]]
	for p in spark_pixels:
		img.set_pixel(p[0], p[1], c_aura)
		
	for x in range(size):
		for y in range(size):
			if img.get_pixel(x, y).a > 0 and img.get_pixel(x, y) != c_aura:
				for dir in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
					var nx = x + dir.x
					var ny = y + dir.y
					if nx >= 0 and nx < size and ny >= 0 and ny < size:
						if img.get_pixel(nx, ny).a == 0:
							img.set_pixel(nx, ny, c_outline)

	return ImageTexture.create_from_image(img)

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

func setup_hud(current_hp: int, max_hp: int, current_energy: int, max_energy: int, level: int, current_xp: int, max_xp: int) -> void:
	update_hp(current_hp, max_hp)
	update_energy(current_energy, max_energy)
	update_xp(level, current_xp, max_xp)

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
