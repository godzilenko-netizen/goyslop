extends CanvasLayer

const InventoryModelType = preload("res://scripts/data/inventory_model.gd")
const InventorySlot = preload("res://scripts/inventory_slot.gd")
const WORLD_ITEM_DROP_SCENE = preload("res://scenes/world_item_drop.tscn")
const GothicUI = preload("res://scripts/ui/gothic_ui.gd")
const GOTHIC_THEME = preload("res://themes/diablo2_theme.tres")
const INVENTORY_BACKDROP = preload("res://assets/ui/inventory_backdrop.png")

const GRID_COLS := 10
const GRID_ROWS := 6
const INVENTORY_CAPACITY := GRID_COLS * GRID_ROWS
const MARGIN_TOP := 16.0
const MARGIN_BOTTOM := 115.0
const MARGIN_RIGHT := 14.0

@onready var root_panel: Control = %RootPanel
@onready var grid_root: Control = %GridRoot
@onready var world_drop_zone: InventoryDropZone = $WorldDropZone
@onready var sort_button: Button = $RootPanel/InnerBorder/OM/VBox/Footer/FM/FHBox/SortLbl
@onready var gold_label: Label = $RootPanel/InnerBorder/OM/VBox/Footer/FM/FHBox/GoldBox/GBM/GBoxH/GoldAmt

var is_open := false
var panel_w := 0.0
var panel_h := 0.0
var player_ref: Node = null
var grid_slots: Array[InventorySlot] = []
var equipment_slots: Dictionary = {}
var equipment_key_by_slot: Dictionary = {}
var inventory_model: InventoryModelType
var grid_cell_size: int = 36
var grid_gap: int = 2
var drag_highlights: Array[Control] = []

const EQUIPMENT_PATHS := {
	"weapon_1": ["RootPanel/InnerBorder/OM/VBox/EquipSection/ESM/EquipVBox/Row1/LeftCol/SlotWeapon", "weapon", "ОРУЖИЕ 1"],
	"weapon_2": ["RootPanel/InnerBorder/OM/VBox/EquipSection/ESM/EquipVBox/Row1/RightCol/SlotShield", "weapon", "ОРУЖИЕ 2"],
	"helmet": ["RootPanel/InnerBorder/OM/VBox/EquipSection/ESM/EquipVBox/Row1/CenterCol/HatRow/SlotHelmet", "helmet", "ШЛЕМ"],
	"armor": ["RootPanel/InnerBorder/OM/VBox/EquipSection/ESM/EquipVBox/Row1/CenterCol/ArmorRow/SlotArmor", "armor", "БРОНЯ"],
	"belt": ["RootPanel/InnerBorder/OM/VBox/EquipSection/ESM/EquipVBox/Row1/CenterCol/BeltRow/SlotBelt", "belt", "ПОЯС"],
	"amulet": ["RootPanel/InnerBorder/OM/VBox/EquipSection/ESM/EquipVBox/Row1/CenterCol/HatRow/SlotAmulet", "amulet", "АМУЛЕТ"],
	"ring_1": ["RootPanel/InnerBorder/OM/VBox/EquipSection/ESM/EquipVBox/Row1/CenterCol/ArmorRow/SlotRing1", "ring", "КОЛЬЦО 1"],
	"ring_2": ["RootPanel/InnerBorder/OM/VBox/EquipSection/ESM/EquipVBox/Row1/CenterCol/ArmorRow/SlotRing2", "ring", "КОЛЬЦО 2"],
	"accessory_1": ["RootPanel/InnerBorder/OM/VBox/EquipSection/ESM/EquipVBox/Row1/CenterCol/BeltRow/SlotAcc1", "accessory", "АКСЕС. 1"],
	"accessory_2": ["RootPanel/InnerBorder/OM/VBox/EquipSection/ESM/EquipVBox/Row1/CenterCol/BeltRow/SlotAcc2", "accessory", "АКСЕС. 2"],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_gothic_inventory_style()
	var vp := get_viewport().get_visible_rect().size
	panel_w = vp.x * 0.44 - MARGIN_RIGHT
	panel_h = vp.y - MARGIN_TOP - MARGIN_BOTTOM
	root_panel.size = Vector2(panel_w, panel_h)
	root_panel.position = Vector2(vp.x, MARGIN_TOP)
	root_panel.visible = false
	world_drop_zone.visible = false
	world_drop_zone.drop_requested.connect(_drop_item_to_world)
	world_drop_zone.drag_hovered.connect(_clear_drag_highlights)

	_setup_equipment_slots()
	_setup_grid()
	var categories := {}
	for key in EQUIPMENT_PATHS:
		categories[key] = str(EQUIPMENT_PATHS[key][1])
	inventory_model = InventoryModelType.new(INVENTORY_CAPACITY, categories, GRID_COLS)
	inventory_model.changed.connect(_sync_slots)
	inventory_model.gold_changed.connect(_update_gold)
	sort_button.flat = false
	sort_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sort_button.pressed.connect(sort_inventory)
	_sync_slots()
	_update_gold()


func toggle() -> void:
	if is_open:
		_close()
	else:
		_open()


func _open() -> void:
	if is_open:
		return
	is_open = true
	world_drop_zone.visible = true
	root_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var vp := get_viewport().get_visible_rect().size
	var dst := vp.x - panel_w - MARGIN_RIGHT
	var tw := create_tween()
	tw.tween_property(root_panel, "position:x", dst, 0.30).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if player_ref and player_ref.has_method("shift_camera_for_ui"):
		player_ref.shift_camera_for_ui(true)


func _close() -> void:
	if not is_open:
		return
	is_open = false
	world_drop_zone.visible = false
	_clear_drag_highlights()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var vp := get_viewport().get_visible_rect().size
	var tw := create_tween()
	tw.tween_property(root_panel, "position:x", vp.x, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): root_panel.visible = false)
	if player_ref and player_ref.has_method("shift_camera_for_ui"):
		player_ref.shift_camera_for_ui(false)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("inventory"):
		_close()
		get_viewport().set_input_as_handled()


func _setup_equipment_slots() -> void:
	for key in EQUIPMENT_PATHS:
		var config: Array = EQUIPMENT_PATHS[key]
		var slot := get_node(str(config[0])) as InventorySlot
		slot.configure(-1, str(config[1]), str(config[2]))
		_connect_slot(slot)
		equipment_slots[key] = slot
		equipment_key_by_slot[slot] = key


func _setup_grid() -> void:
	for child in grid_root.get_children():
		child.queue_free()
	grid_slots.clear()
	var inner_w := panel_w - 164.0
	grid_cell_size = max(int((inner_w - (GRID_COLS - 1) * grid_gap) / GRID_COLS), 36)
	grid_root.custom_minimum_size = Vector2(
		GRID_COLS * grid_cell_size + (GRID_COLS - 1) * grid_gap,
		GRID_ROWS * grid_cell_size + (GRID_ROWS - 1) * grid_gap
	)
	for equipment_slot in equipment_slots.values():
		equipment_slot.set_drag_grid_metrics(grid_cell_size, grid_gap)

	for index in range(INVENTORY_CAPACITY):
		var slot := InventorySlot.new()
		slot.position = _cell_position(index)
		slot.size = Vector2(grid_cell_size, grid_cell_size)
		slot.custom_minimum_size = slot.size
		slot.add_theme_stylebox_override("panel", _make_grid_style())
		slot.configure(index)
		_connect_slot(slot)
		grid_root.add_child(slot)
		grid_slots.append(slot)


func _connect_slot(slot: InventorySlot) -> void:
	slot.transfer_requested.connect(_transfer_item)
	slot.activate_requested.connect(_activate_item)
	slot.set_drag_grid_metrics(grid_cell_size, grid_gap)
	slot.drop_validator = _can_drop_on_slot
	slot.drag_hovered.connect(_show_drag_destination)
	slot.drag_finished.connect(_clear_drag_highlights)


func _make_grid_style() -> StyleBoxFlat:
	return GothicUI.slot_style(false, true)


func _apply_gothic_inventory_style() -> void:
	root_panel.theme = GOTHIC_THEME
	root_panel.clip_contents = true
	root_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root_panel.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	var backdrop := root_panel.get_node_or_null("InventoryBackdrop") as TextureRect
	if not backdrop:
		backdrop = TextureRect.new()
		backdrop.name = "InventoryBackdrop"
		backdrop.texture = INVENTORY_BACKDROP
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.modulate = Color(0.92, 0.88, 0.84, 1.0)
		root_panel.add_child(backdrop)
		root_panel.move_child(backdrop, 0)

	var inner := root_panel.get_node("InnerBorder") as PanelContainer
	inner.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.018, 0.012, 0.01, 0.18), Color(0.36, 0.25, 0.10, 0.65), 1))
	var outer_margin := root_panel.get_node("InnerBorder/OM") as MarginContainer
	outer_margin.add_theme_constant_override("margin_left", 28)
	outer_margin.add_theme_constant_override("margin_top", 24)
	outer_margin.add_theme_constant_override("margin_right", 28)
	outer_margin.add_theme_constant_override("margin_bottom", 26)

	var equipment_section := root_panel.get_node("InnerBorder/OM/VBox/EquipSection") as PanelContainer
	equipment_section.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.025, 0.014, 0.012, 0.36), Color(0.40, 0.27, 0.10, 0.72), 2))
	var grid_card := root_panel.get_node("InnerBorder/OM/VBox/GridCard") as PanelContainer
	grid_card.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.018, 0.013, 0.011, 0.76), Color(0.37, 0.25, 0.10, 0.95), 3, 0, 8))
	var footer := root_panel.get_node("InnerBorder/OM/VBox/Footer") as PanelContainer
	footer.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.025, 0.016, 0.012, 0.84), Color(0.35, 0.23, 0.09, 0.9), 2))
	var gold_box := root_panel.get_node("InnerBorder/OM/VBox/Footer/FM/FHBox/GoldBox") as PanelContainer
	gold_box.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.012, 0.009, 0.007, 0.94), GothicUI.BRASS_DARK, 2))

	for divider_path in ["InnerBorder/OM/VBox/Sep1", "InnerBorder/OM/VBox/Sep2"]:
		var divider := root_panel.get_node(divider_path) as PanelContainer
		divider.add_theme_stylebox_override("panel", GothicUI.divider_style(Color(0.50, 0.31, 0.09, 0.9)))
	for title_path in [
		"InnerBorder/OM/VBox/TitleBar/TitleText",
		"InnerBorder/OM/VBox/GridTitleBar/GridTitleText",
	]:
		var title := root_panel.get_node(title_path) as Label
		if title:
			title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			title.add_theme_color_override("font_color", GothicUI.BRASS_LIGHT)
			title.add_theme_color_override("font_outline_color", GothicUI.INK)
			title.add_theme_constant_override("outline_size", 4)
			title.add_theme_font_size_override("font_size", 14)

	for key in EQUIPMENT_PATHS:
		var slot := get_node(str(EQUIPMENT_PATHS[key][0])) as PanelContainer
		var accent: bool = key in ["amulet", "ring_1", "ring_2", "accessory_1", "accessory_2"]
		slot.add_theme_stylebox_override("panel", GothicUI.slot_style(accent, true))
		var placeholder := slot.get_node_or_null("L") as Label
		if placeholder:
			placeholder.add_theme_color_override("font_color", GothicUI.BONE_MUTED.darkened(0.25))
			placeholder.add_theme_color_override("font_outline_color", GothicUI.INK)
			placeholder.add_theme_constant_override("outline_size", 3)


func _is_my_slot(slot: InventorySlot) -> bool:
	return grid_slots.has(slot) or equipment_slots.values().has(slot)


func _transfer_item(source: InventorySlot, target: InventorySlot) -> void:
	if source == target or not inventory_model:
		return
	_clear_drag_highlights()
	if _is_my_slot(source) and _is_my_slot(target):
		inventory_model.transfer(_slot_ref(source), _slot_ref(target))
	else:
		var chest_ui = get_tree().root.get_node_or_null("ChestUI")
		if chest_ui and chest_ui.is_open and chest_ui.has_method("_transfer_item"):
			chest_ui._transfer_item(source, target)


func _can_drop_on_slot(source: InventorySlot, target: InventorySlot, dragged_item: Dictionary) -> bool:
	if not inventory_model or source == target:
		return false
	if _is_my_slot(source) and _is_my_slot(target):
		return inventory_model.can_transfer(_slot_ref(source), _slot_ref(target))
	elif not _is_my_slot(source) and _is_my_slot(target):
		var target_ref := _slot_ref(target)
		return inventory_model.can_accept(target_ref, dragged_item)
	return false


func _show_drag_destination(source: InventorySlot, target: InventorySlot, dragged_item: Dictionary) -> void:
	_clear_drag_highlights()
	var valid := _can_drop_on_slot(source, target, dragged_item)
	if target.slot_index < 0:
		var equipment_highlight := _make_drag_highlight(valid)
		equipment_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		equipment_highlight.z_index = 50
		target.add_child(equipment_highlight)
		drag_highlights.append(equipment_highlight)
		return

	var item_size := inventory_model.get_item_size(dragged_item)
	var target_index := target.slot_index
	var occupied_anchor := inventory_model.get_anchor_index(target_index)
	if occupied_anchor >= 0:
		target_index = occupied_anchor
	var start_column := target_index % GRID_COLS
	var start_row := target_index / GRID_COLS
	for y in range(item_size.y):
		for x in range(item_size.x):
			var column := start_column + x
			var row := start_row + y
			if column < 0 or column >= GRID_COLS or row < 0 or row >= GRID_ROWS:
				continue
			var cell_index := row * GRID_COLS + column
			var highlight := _make_drag_highlight(valid)
			highlight.position = _cell_position(cell_index)
			highlight.size = Vector2(grid_cell_size, grid_cell_size)
			highlight.z_index = 50
			grid_root.add_child(highlight)
			drag_highlights.append(highlight)


func _make_drag_highlight(valid: bool) -> Panel:
	var highlight := Panel.new()
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.78, 0.34, 0.28) if valid else Color(0.92, 0.18, 0.12, 0.30)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.32, 1.0, 0.48, 0.92) if valid else Color(1.0, 0.26, 0.18, 0.95)
	style.set_corner_radius_all(2)
	highlight.add_theme_stylebox_override("panel", style)
	return highlight


func _clear_drag_highlights() -> void:
	for highlight in drag_highlights:
		if is_instance_valid(highlight):
			highlight.free()
	drag_highlights.clear()


func _drop_item_to_world(source: InventorySlot, _dragged_item: Dictionary) -> void:
	_clear_drag_highlights()
	if not is_open or not player_ref:
		return
	if get_viewport().get_mouse_position().x >= root_panel.position.x:
		return
	var removed := inventory_model.remove_item(_slot_ref(source))
	if removed.is_empty():
		return
	var player_node := player_ref as Node3D
	if not player_node or not player_node.get_parent():
		inventory_model.add_item(removed)
		return
	var drop := WORLD_ITEM_DROP_SCENE.instantiate() as WorldItemDrop
	drop.configure_item(removed)
	player_node.get_parent().add_child(drop)
	var side := Vector3.LEFT
	var player_camera := player_node.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if player_camera:
		side = -player_camera.global_transform.basis.x
		side.y = 0.0
		side = side.normalized()
	var origin := player_node.global_position + Vector3.UP * 0.85
	var target := player_node.global_position + side * 1.15 + Vector3.UP * 0.06
	drop.launch_from(origin, target)


func _activate_item(slot: InventorySlot) -> void:
	if slot.item.is_empty():
		return
	var chest_ui = get_tree().root.get_node_or_null("ChestUI")
	if chest_ui and chest_ui.get("is_open") and chest_ui.get("chest_model"):
		var c_model = chest_ui.chest_model
		if c_model and c_model.add_item(slot.item):
			inventory_model.remove_item(_slot_ref(slot))
			return

	var effect := str(slot.item.get("effect", ""))
	if effect in ["health", "mana"]:
		_use_consumable(slot, effect)
		return
	if slot.allowed_category.is_empty():
		for equipment_slot in equipment_slots.values():
			if equipment_slot.item.is_empty() and equipment_slot.can_accept(slot.item):
				_transfer_item(slot, equipment_slot)
				return
	else:
		var empty_slot := _first_empty_grid_slot(slot.item)
		if empty_slot:
			_transfer_item(slot, empty_slot)


func _use_consumable(slot: InventorySlot, effect: String) -> void:
	if not player_ref:
		return
	var power := int(slot.item.get("power", 0))
	if effect == "health":
		if not player_ref.has_method("restore_health"):
			return
		player_ref.restore_health(power)
	elif effect == "mana":
		if not player_ref.has_method("restore_energy"):
			return
		player_ref.restore_energy(power)
	else:
		return
	inventory_model.consume(_slot_ref(slot))


func add_item(new_item: Dictionary) -> bool:
	return inventory_model.add_item(new_item)


func sort_inventory() -> void:
	inventory_model.sort_items()


func set_gold(amount: int) -> void:
	inventory_model.set_gold(amount)


func get_inventory_state() -> Dictionary:
	return inventory_model.serialize()


func load_inventory_state(state: Dictionary) -> void:
	inventory_model.load_state(state)


func _first_empty_grid_slot(candidate: Dictionary = {}) -> InventorySlot:
	if not inventory_model:
		return null
	var requested := candidate if not candidate.is_empty() else {"grid_size": Vector2i.ONE}
	var index := inventory_model.find_first_fit(requested)
	if index >= 0:
		return grid_slots[index]
	return null


func _slot_ref(slot: InventorySlot) -> Dictionary:
	if slot.slot_index >= 0:
		return inventory_model.grid_ref(slot.slot_index)
	return inventory_model.equipment_ref(str(equipment_key_by_slot.get(slot, "")))


func _sync_slots() -> void:
	for index in range(grid_slots.size()):
		var slot := grid_slots[index]
		var anchor := inventory_model.get_anchor_index(index)
		slot.position = _cell_position(index)
		slot.size = Vector2(grid_cell_size, grid_cell_size)
		slot.custom_minimum_size = slot.size
		slot.z_index = 0
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		if anchor == index:
			var item := inventory_model.items[index]
			var item_size := inventory_model.get_item_size(item)
			slot.size = Vector2(
				item_size.x * grid_cell_size + (item_size.x - 1) * grid_gap,
				item_size.y * grid_cell_size + (item_size.y - 1) * grid_gap
			)
			slot.custom_minimum_size = slot.size
			slot.z_index = 2
			slot.set_item(item)
		elif anchor >= 0:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.set_item({})
		else:
			slot.set_item({})
	for key in equipment_slots:
		equipment_slots[key].set_item(inventory_model.get_item(inventory_model.equipment_ref(key)))


func _cell_position(index: int) -> Vector2:
	var column := index % GRID_COLS
	var row := index / GRID_COLS
	return Vector2(column * (grid_cell_size + grid_gap), row * (grid_cell_size + grid_gap))


func _update_gold(_value: int = 0) -> void:
	if gold_label:
		gold_label.text = str(inventory_model.gold if inventory_model else 0)
