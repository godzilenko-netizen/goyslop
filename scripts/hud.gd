extends CanvasLayer
class_name GameHUD

signal flask_requested(flask_id: StringName)

const SkillDataType = preload("res://scripts/data/skill_data.gd")
const FlaskDataType = preload("res://scripts/data/flask_data.gd")
const GothicUI = preload("res://scripts/ui/gothic_ui.gd")
const HOTBAR_FRAME_TEXTURE = preload("res://assets/ui/hotbar_frame.png")
const HP_ORB_DECOR_TEXTURE = preload("res://assets/ui/hp_orb_dragon_frame.png")
const MANA_ORB_DECOR_TEXTURE = preload("res://assets/ui/mana_orb_statue_frame.png")
const PIXEL_LIQUID_SHADER = preload("res://shaders/pixel_liquid.gdshader")
const ORB_COMPOSITION_SCALE := 1.12

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
@onready var slot3_cooldown: ColorRect = $Control/BottomCenterPanel/HotbarContainer/Slot3/CooldownOverlay

# Карточки создаются в коде, не из .tscn
var skill1_tooltip: PanelContainer = null
var skill2_tooltip: PanelContainer = null
var skill3_tooltip: PanelContainer = null
var hovered_slot: int = 0  # 0=ничего, 1=slot1, 2=slot2, 3=slot3

# Состояние кулдауна для каждого активного слота.
var _cooldown_states: Dictionary = {}
var _flask_controls: Dictionary = {}
var _flask_bar: HBoxContainer = null

func _ready() -> void:
	_apply_gothic_hud_style()
	_force_runtime_ui_layout()
	_setup_procedural_orbs()
	_create_locked_slot_overlays()
	_setup_cooldown_overlays()
	
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
	return GothicUI.tooltip_style(border_col)

func _make_tooltip_card(slot_offset_left: float, slot_offset_right: float) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(188, 124)
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.anchor_left = 0.5
	card.anchor_top = 1.0
	card.anchor_right = 0.5
	card.anchor_bottom = 1.0
	card.offset_left = slot_offset_left
	card.offset_top = -250.0
	card.offset_right = slot_offset_right
	card.offset_bottom = -112.0
	return card

func _fill_tooltip(card: PanelContainer, title_text: String, stats: Array) -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", GothicUI.BRASS_LIGHT)
	title.add_theme_color_override("font_outline_color", GothicUI.INK)
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	for stat in stats:
		var lbl = Label.new()
		lbl.text = stat[0]
		lbl.add_theme_color_override("font_color", stat[1])
		lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(lbl)

func configure_skills(skills: Array[SkillDataType]) -> void:
	var root_control: Control = $Control
	var offsets := {
		1: Vector2(-314.0, -126.0),
		2: Vector2(-251.0, -63.0),
		3: Vector2(-188.0, 0.0),
	}
	var border_colors := {
		1: GothicUI.BRASS,
		2: GothicUI.EMBER,
		3: Color(0.25, 0.58, 0.92, 1.0),
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
		lock_lbl.text = "×"
		lock_lbl.add_theme_font_size_override("font_size", 16)
		lock_lbl.add_theme_color_override("font_color", Color(0.36, 0.33, 0.29, 0.9))
		lock_lbl.add_theme_color_override("font_outline_color", GothicUI.INK)
		lock_lbl.add_theme_constant_override("outline_size", 3)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.anchor_left = 0.0; lock_lbl.anchor_top = 0.0
		lock_lbl.anchor_right = 1.0; lock_lbl.anchor_bottom = 1.0
		lock_lbl.offset_left = 0; lock_lbl.offset_top = 0
		lock_lbl.offset_right = 0; lock_lbl.offset_bottom = 0
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(lock_lbl)



func _setup_cooldown_overlays() -> void:
	_register_cooldown_overlay(1, slot1_cooldown)
	_register_cooldown_overlay(2, slot2_cooldown)
	_register_cooldown_overlay(3, slot3_cooldown)

func _register_cooldown_overlay(slot_index: int, overlay: ColorRect) -> void:
	if not overlay:
		return
	var shade := overlay.get_node_or_null("Shade") as ColorRect
	var sweep := overlay.get_node_or_null("Sweep") as ColorRect
	var timer_label := overlay.get_node_or_null("Timer") as Label
	if not shade or not sweep or not timer_label:
		push_error("Cooldown overlay is incomplete for hotbar slot %d" % slot_index)
		return
	overlay.visible = false
	_cooldown_states[slot_index] = {
		"overlay": overlay,
		"shade": shade,
		"sweep": sweep,
		"timer": timer_label,
		"duration": 0.0,
		"remaining": 0.0,
	}



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


func _apply_gothic_hud_style() -> void:
	var root := $Control as Control
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_style_orb($Control/HPOrbContainer, hp_orb, hp_label, false)
	_style_orb($Control/EnergyOrbContainer, energy_orb, energy_label, true)

	var hotbar_frame := root.get_node_or_null("HotbarFrame") as TextureRect
	if not hotbar_frame:
		hotbar_frame = TextureRect.new()
		hotbar_frame.name = "HotbarFrame"
		hotbar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar_frame.texture = HOTBAR_FRAME_TEXTURE
		hotbar_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hotbar_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hotbar_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hotbar_frame.anchor_left = 0.5
		hotbar_frame.anchor_top = 1.0
		hotbar_frame.anchor_right = 0.5
		hotbar_frame.anchor_bottom = 1.0
		hotbar_frame.offset_left = -380.0
		hotbar_frame.offset_top = -156.0
		hotbar_frame.offset_right = 380.0
		hotbar_frame.offset_bottom = -14.0
		root.add_child(hotbar_frame)
		root.move_child(hotbar_frame, $Control/BottomCenterPanel.get_index())

	var bottom_panel := $Control/BottomCenterPanel as PanelContainer
	bottom_panel.anchor_left = 0.5
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 0.5
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = -252.0
	bottom_panel.offset_top = -108.0
	bottom_panel.offset_right = 252.0
	bottom_panel.offset_bottom = -44.0
	bottom_panel.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	var hotbar := $Control/BottomCenterPanel/HotbarContainer as HBoxContainer
	hotbar.add_theme_constant_override("separation", 8)
	for index in range(1, 9):
		var slot := hotbar.get_node("Slot%d" % index) as PanelContainer
		slot.custom_minimum_size = Vector2(56, 56)
		slot.add_theme_stylebox_override("panel", GothicUI.slot_style(index <= 3))
		var icon := slot.get_node_or_null("SkillIcon") as TextureRect
		if not icon:
			icon = slot.get_node_or_null("FistIcon") as TextureRect
		if icon:
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.modulate = Color(0.92, 0.88, 0.78, 1.0)
		var key_label := slot.get_node_or_null("SlotLabel") as Label
		if key_label:
			key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			key_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			key_label.add_theme_font_size_override("font_size", 10)
			key_label.add_theme_color_override("font_color", GothicUI.BRASS_LIGHT)
			key_label.add_theme_color_override("font_outline_color", GothicUI.INK)
			key_label.add_theme_constant_override("outline_size", 4)
	_create_flask_bar()

	var xp_panel := $Control/TopXPPanel as PanelContainer
	xp_panel.anchor_left = 0.22
	xp_panel.anchor_top = 1.0
	xp_panel.anchor_right = 0.78
	xp_panel.anchor_bottom = 1.0
	xp_panel.offset_left = 0.0
	xp_panel.offset_top = -13.0
	xp_panel.offset_right = 0.0
	xp_panel.offset_bottom = -3.0
	xp_panel.custom_minimum_size = Vector2.ZERO
	xp_panel.add_theme_stylebox_override("panel", GothicUI.panel_style(GothicUI.INK, GothicUI.BRASS_DARK, 1))
	xp_bar.add_theme_stylebox_override("background", GothicUI.panel_style(Color(0.015, 0.01, 0.008, 1), Color(0, 0, 0, 0), 0))
	xp_bar.add_theme_stylebox_override("fill", GothicUI.panel_style(Color(0.56, 0.31, 0.08, 1), Color(0, 0, 0, 0), 0))
	xp_label.add_theme_font_size_override("font_size", 9)
	xp_label.add_theme_color_override("font_color", GothicUI.BONE)

	var minimap_panel := $Control/MinimapPanel as PanelContainer
	minimap_panel.offset_left = -214.0
	minimap_panel.offset_top = 22.0
	minimap_panel.offset_right = -22.0
	minimap_panel.offset_bottom = 214.0
	minimap_panel.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.018, 0.017, 0.016, 0.90), GothicUI.BRASS_DARK, 4, 0, 8))


func _style_orb(container: Control, orb: TextureProgressBar, label: Label, right_side: bool) -> void:
	container.custom_minimum_size = Vector2(188, 188)
	container.offset_top = -204.0
	container.offset_bottom = -16.0
	if right_side:
		container.offset_left = -204.0
		container.offset_right = -16.0
	else:
		container.offset_left = 16.0
		container.offset_right = 204.0
	# Enlarge the complete ornament around its existing center so the carefully
	# matched liquid, frame, statue and dragon geometry stays unchanged.
	container.pivot_offset = Vector2(94.0, 94.0)
	container.scale = Vector2.ONE * ORB_COMPOSITION_SCALE
	# The HP liquid slightly overlaps its organic tail aperture so the dark edge
	# cannot leave a visible gap; the approved mana ornament stays at 152 px.
	var orb_inset := 18.0 if right_side else 14.0
	orb.offset_left = orb_inset
	orb.offset_top = orb_inset
	orb.offset_right = -orb_inset
	orb.offset_bottom = -orb_inset
	orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	orb.material = _create_liquid_material(
		Color(0.78, 0.05, 0.08, 1.0) if not right_side else Color(0.04, 0.30, 0.92, 1.0),
		false,
		0.0,
		1.0,
		Vector2(128.0, 128.0)
	)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", GothicUI.BONE)
	label.add_theme_color_override("font_outline_color", GothicUI.INK)
	label.add_theme_constant_override("outline_size", 5)
	var old_frame := container.get_node_or_null("OrbFrame")
	if old_frame:
		old_frame.queue_free()
	var decor := container.get_node_or_null("OrbDecor") as TextureRect
	if not decor:
		decor = TextureRect.new()
		decor.name = "OrbDecor"
		decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		decor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		decor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		container.add_child(decor)
	decor.texture = MANA_ORB_DECOR_TEXTURE if right_side else HP_ORB_DECOR_TEXTURE
	decor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Measured from the alpha arcs of the approved high-resolution sources.
	# The HP tail's circular opening is centered lower than the dragon artwork,
	# so align that measured center with the procedural orb instead of centering
	# the full square texture.
	decor.position = Vector2(-43.0, -41.0) if right_side else Vector2(-18.0, -31.0)
	decor.size = Vector2(222.0, 222.0) if right_side else Vector2(220.0, 220.0)


func _create_liquid_material(
	tint: Color,
	recolor_red_source: bool,
	liquid_top: float,
	liquid_bottom: float,
	pixel_grid: Vector2
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PIXEL_LIQUID_SHADER
	material.set_shader_parameter("liquid_tint", tint)
	material.set_shader_parameter("fill_ratio", 1.0)
	material.set_shader_parameter("liquid_top", liquid_top)
	material.set_shader_parameter("liquid_bottom", liquid_bottom)
	material.set_shader_parameter("recolor_red_source", recolor_red_source)
	material.set_shader_parameter("pixel_grid", pixel_grid)
	return material


func _create_flask_bar() -> void:
	if _flask_bar:
		return
	_flask_bar = HBoxContainer.new()
	_flask_bar.name = "FlaskBar"
	_flask_bar.anchor_left = 0.5
	_flask_bar.anchor_top = 1.0
	_flask_bar.anchor_right = 0.5
	_flask_bar.anchor_bottom = 1.0
	_flask_bar.offset_left = -400.0
	_flask_bar.offset_top = -146.0
	_flask_bar.offset_right = -276.0
	_flask_bar.offset_bottom = -24.0
	_flask_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_flask_bar.add_theme_constant_override("separation", 8)
	$Control.add_child(_flask_bar)


func configure_flasks(flasks: Array[FlaskDataType]) -> void:
	_create_flask_bar()
	for child in _flask_bar.get_children():
		child.queue_free()
	_flask_controls.clear()
	for flask in flasks:
		_create_flask_control(flask)


func _create_flask_control(data: FlaskDataType) -> void:
	var root := Control.new()
	root.name = "%sFlask" % str(data.flask_id).capitalize()
	root.custom_minimum_size = Vector2(54.0, 112.0)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	_flask_bar.add_child(root)

	var liquid := TextureRect.new()
	liquid.name = "Liquid"
	liquid.texture = data.icon
	liquid.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	liquid.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	liquid.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	liquid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	liquid.offset_bottom = -10.0
	liquid.material = _create_liquid_material(data.liquid_tint, true, 0.25, 0.83, Vector2(64.0, 128.0))
	root.add_child(liquid)

	var button := Button.new()
	button.name = "UseButton"
	button.flat = true
	button.tooltip_text = data.build_tooltip()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", GothicUI.panel_style(Color(0.33, 0.22, 0.08, 0.16), GothicUI.BRASS_DARK, 1, 3))
	button.add_theme_stylebox_override("pressed", GothicUI.panel_style(Color(0.55, 0.34, 0.09, 0.22), GothicUI.BRASS, 1, 3))
	button.pressed.connect(func(): flask_requested.emit(data.flask_id))
	root.add_child(button)

	var key_label := Label.new()
	key_label.name = "Hotkey"
	key_label.text = data.hotkey_label
	key_label.position = Vector2(1.0, 3.0)
	key_label.size = Vector2(18.0, 18.0)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 9)
	key_label.add_theme_color_override("font_color", GothicUI.BRASS_LIGHT)
	key_label.add_theme_color_override("font_outline_color", GothicUI.INK)
	key_label.add_theme_constant_override("outline_size", 4)
	root.add_child(key_label)

	var charge_label := Label.new()
	charge_label.name = "Charges"
	charge_label.position = Vector2(32.0, 88.0)
	charge_label.size = Vector2(20.0, 18.0)
	charge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	charge_label.add_theme_font_size_override("font_size", 9)
	charge_label.add_theme_color_override("font_color", GothicUI.BONE)
	charge_label.add_theme_color_override("font_outline_color", GothicUI.INK)
	charge_label.add_theme_constant_override("outline_size", 4)
	root.add_child(charge_label)

	var pips: Array[ColorRect] = []
	var visible_pips := mini(data.max_charges, 5)
	for index in range(visible_pips):
		var pip := ColorRect.new()
		pip.name = "Charge%d" % (index + 1)
		pip.position = Vector2(6.0 + index * 8.0, 105.0)
		pip.size = Vector2(5.0, 3.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(pip)
		pips.append(pip)

	_flask_controls[data.flask_id] = {
		"root": root,
		"material": liquid.material,
		"charge_label": charge_label,
		"pips": pips,
		"data": data,
	}
	update_flask_state(data.flask_id, data.max_charges, data.max_charges, 1.0, 0.0)


func update_flask_state(
	flask_id: StringName,
	charges: int,
	max_charges: int,
	liquid_ratio: float,
	_recharge_ratio: float
) -> void:
	if not _flask_controls.has(flask_id):
		return
	var entry: Dictionary = _flask_controls[flask_id]
	var material := entry["material"] as ShaderMaterial
	material.set_shader_parameter("fill_ratio", clampf(liquid_ratio, 0.0, 1.0))
	var charge_label := entry["charge_label"] as Label
	charge_label.text = str(charges)
	var pips: Array = entry["pips"]
	for index in range(pips.size()):
		var pip := pips[index] as ColorRect
		pip.color = GothicUI.BRASS_LIGHT if index < charges else Color(0.13, 0.11, 0.10, 0.9)
	if max_charges > pips.size():
		charge_label.text = "%d/%d" % [charges, max_charges]


func flash_flask_unavailable(flask_id: StringName) -> void:
	if not _flask_controls.has(flask_id):
		return
	var root := (_flask_controls[flask_id] as Dictionary)["root"] as Control
	root.modulate = Color(1.0, 0.28, 0.22, 1.0)
	var tween := root.create_tween()
	tween.tween_property(root, "modulate", Color.WHITE, 0.24).set_trans(Tween.TRANS_QUAD)

func _process(delta: float) -> void:
	_refresh_tooltips()
	_update_cooldowns(delta)

func _refresh_tooltips() -> void:
	var ctrl = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_CTRL)
	if skill1_tooltip:
		skill1_tooltip.visible = ctrl and hovered_slot == 1
	if skill2_tooltip:
		skill2_tooltip.visible = ctrl and hovered_slot == 2
	if skill3_tooltip:
		skill3_tooltip.visible = ctrl and hovered_slot == 3

func _setup_procedural_orbs() -> void:
	var hp_bg_tex = _create_circle_texture(
		Color(0.20, 0.028, 0.038, 1.0), Color(0.34, 0.10, 0.075, 1.0), 160
	)
	var hp_fill_tex = _create_circle_texture(
		Color(0.68, 0.025, 0.055, 1.0), Color(0.20, 0.015, 0.02, 1.0), 160
	)
	
	var energy_bg_tex = _create_circle_texture(
		Color(0.025, 0.105, 0.24, 1.0), Color(0.08, 0.22, 0.42, 1.0), 152
	)
	var energy_fill_tex = _create_circle_texture(
		Color(0.025, 0.25, 0.68, 1.0), Color(0.01, 0.055, 0.18, 1.0), 152
	)
	
	hp_orb.texture_under = hp_bg_tex
	hp_orb.texture_progress = hp_fill_tex
	
	energy_orb.texture_under = energy_bg_tex
	energy_orb.texture_progress = energy_fill_tex



func _create_circle_texture(fill_color: Color, border_color: Color, size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius := size * (61.0 / 128.0)
	var border_width := maxf(2.0, size * (2.0 / 128.0))
	var glint_center := Vector2(size * (43.0 / 128.0), size * (38.0 / 128.0))
	var glint_radius := size * (10.0 / 128.0)
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius - border_width:
				var radial_light: float = 1.04 - (dist / radius) * 0.34
				var depth_shadow: float = lerpf(0.68, 1.05, 1.0 - float(y) / size)
				var liquid: Color = fill_color * radial_light * depth_shadow
				liquid.a = 1.0
				var glint_distance: float = Vector2(x, y).distance_to(glint_center)
				if glint_distance < glint_radius:
					liquid = liquid.lerp(
						Color(1.0, 0.78, 0.62, 1.0),
						(glint_radius - glint_distance) / (glint_radius * 2.8)
					)
				img.set_pixel(x, y, liquid)
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
	_start_cooldown(1, duration)

func trigger_skill_cooldown(slot_index: int, duration: float) -> void:
	_start_cooldown(slot_index, duration)

func _start_cooldown(slot_index: int, duration: float) -> void:
	if duration <= 0.0 or not _cooldown_states.has(slot_index):
		return
	var state: Dictionary = _cooldown_states[slot_index]
	state["duration"] = maxf(duration, 0.001)
	state["remaining"] = duration
	var overlay := state["overlay"] as ColorRect
	overlay.visible = true
	_update_cooldown_visual(state)

func _update_cooldowns(delta: float) -> void:
	for value in _cooldown_states.values():
		var state: Dictionary = value
		var remaining := float(state["remaining"])
		if remaining <= 0.0:
			continue
		state["remaining"] = maxf(remaining - delta, 0.0)
		_update_cooldown_visual(state)

func _update_cooldown_visual(state: Dictionary) -> void:
	var remaining := float(state["remaining"])
	var duration := float(state["duration"])
	var overlay := state["overlay"] as ColorRect
	var shade := state["shade"] as ColorRect
	var sweep := state["sweep"] as ColorRect
	var timer_label := state["timer"] as Label
	var ratio := clampf(remaining / duration, 0.0, 1.0)
	var wipe_position := 1.0 - ratio

	shade.anchor_top = wipe_position
	shade.anchor_bottom = 1.0
	sweep.anchor_top = wipe_position
	sweep.anchor_bottom = wipe_position
	timer_label.text = "%.3f" % remaining

	if remaining <= 0.0:
		overlay.visible = false
		timer_label.text = ""
