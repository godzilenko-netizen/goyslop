extends CanvasLayer
class_name ChestUI

const InventoryModelType = preload("res://scripts/data/inventory_model.gd")
const InventorySlot = preload("res://scripts/inventory_slot.gd")
const GothicUI = preload("res://scripts/ui/gothic_ui.gd")
const GOTHIC_THEME = preload("res://themes/diablo2_theme.tres")
const INVENTORY_BACKDROP = preload("res://assets/ui/inventory_backdrop.png")

const GRID_COLS := 13
const GRID_ROWS := 13
const CHEST_CAPACITY := GRID_COLS * GRID_ROWS
const MARGIN_TOP := 16.0
const MARGIN_BOTTOM := 115.0
const MARGIN_LEFT := 16.0

@onready var root_panel: Control = $RootPanel
@onready var grid_root: Control = $RootPanel/InnerBorder/OM/VBox/GridCard/Margin/GridRoot
@onready var sort_button: Button = $RootPanel/InnerBorder/OM/VBox/Footer/FM/FHBox/SortBtn
@onready var close_button: Button = $RootPanel/InnerBorder/OM/VBox/TitleBar/CloseBtn
@onready var title_label: Label = $RootPanel/InnerBorder/OM/VBox/TitleBar/TitleText

var is_open := false
var panel_w := 0.0
var panel_h := 0.0
var player_ref: Node = null
var current_chest: Node = null
var chest_model: InventoryModelType = null
var grid_slots: Array[InventorySlot] = []
var grid_cell_size: int = 30
var grid_gap: int = 2
var drag_highlights: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if root_panel:
		root_panel.layout_mode = 0
		root_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_apply_gothic_style()
	var vp := get_viewport().get_visible_rect().size
	panel_w = clampf(vp.x * 0.44, 460.0, 560.0)
	panel_h = vp.y - MARGIN_TOP - MARGIN_BOTTOM
	root_panel.size = Vector2(panel_w, panel_h)
	root_panel.position = Vector2(-panel_w, MARGIN_TOP)
	root_panel.visible = false

	_setup_grid()
	
	if sort_button:
		sort_button.flat = false
		sort_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		sort_button.pressed.connect(sort_chest)
	if close_button:
		close_button.pressed.connect(close_chest)


func open_chest(chest_node: Node, model: InventoryModelType) -> void:
	current_chest = chest_node
	chest_model = model
	if not player_ref or not is_instance_valid(player_ref):
		if chest_node and chest_node.get("player") and is_instance_valid(chest_node.get("player")):
			player_ref = chest_node.get("player")
		elif get_tree():
			player_ref = get_tree().get_first_node_in_group("Player")
	if not chest_model.changed.is_connected(_sync_slots):
		chest_model.changed.connect(_sync_slots)
	
	if title_label and chest_node.has_method("get_chest_name"):
		title_label.text = "%s (13×13)" % str(chest_node.get_chest_name()).to_upper()
	else:
		title_label.text = "СУНДУК (13×13)"

	_sync_slots()
	_open()


func toggle() -> void:
	if is_open:
		close_chest()
	else:
		_open()


func _open() -> void:
	if is_open:
		return
	is_open = true
	root_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var tw := create_tween()
	tw.tween_property(root_panel, "position:x", MARGIN_LEFT, 0.30).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var inv_ui := _get_inventory_ui()
	if inv_ui and not inv_ui.is_open:
		inv_ui.open()



func close_chest() -> void:
	if not is_open:
		return
	is_open = false
	_clear_drag_highlights()
	
	var tw := create_tween()
	tw.tween_property(root_panel, "position:x", -panel_w - 20.0, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): root_panel.visible = false)
	
	if current_chest and current_chest.has_method("close_lid"):
		current_chest.close_lid()
	current_chest = null


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close_chest()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		var inv_ui := _get_inventory_ui()
		if inv_ui:
			inv_ui.toggle()
		get_viewport().set_input_as_handled()


func _get_inventory_ui() -> Node:
	if not get_tree() or not get_tree().root:
		return null
	return get_tree().root.find_child("InventoryUI", true, false)


func _setup_grid() -> void:
	for child in grid_root.get_children():
		child.queue_free()
	grid_slots.clear()
	
	var available_w := panel_w - 56.0
	grid_cell_size = max(int((available_w - (GRID_COLS - 1) * grid_gap) / GRID_COLS), 26)
	
	grid_root.custom_minimum_size = Vector2(
		GRID_COLS * grid_cell_size + (GRID_COLS - 1) * grid_gap,
		GRID_ROWS * grid_cell_size + (GRID_ROWS - 1) * grid_gap
	)

	for index in range(CHEST_CAPACITY):
		var slot := InventorySlot.new()
		slot.position = _cell_position(index)
		slot.size = Vector2(grid_cell_size, grid_cell_size)
		slot.custom_minimum_size = slot.size
		slot.add_theme_stylebox_override("panel", GothicUI.slot_style(false, true))
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


func sort_chest() -> void:
	if chest_model:
		chest_model.sort_items()


func _cell_position(index: int) -> Vector2:
	var column := index % GRID_COLS
	var row := index / GRID_COLS
	return Vector2(column * (grid_cell_size + grid_gap), row * (grid_cell_size + grid_gap))


func _sync_slots() -> void:
	if not chest_model:
		return
	for index in range(grid_slots.size()):
		var slot := grid_slots[index]
		var anchor := chest_model.get_anchor_index(index)
		slot.position = _cell_position(index)
		slot.size = Vector2(grid_cell_size, grid_cell_size)
		slot.custom_minimum_size = slot.size
		slot.z_index = 0
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		if anchor == index:
			var item := chest_model.items[index]
			var item_size := chest_model.get_item_size(item)
			slot.size = Vector2(
				item_size.x * grid_cell_size + (item_size.x - 1) * grid_gap,
				item_size.y * grid_cell_size + (item_size.y - 1) * grid_gap
			)
			slot.custom_minimum_size = slot.size
			slot.z_index = 2
			slot.set_item(item)
		elif anchor >= 0:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.size = Vector2(grid_cell_size, grid_cell_size)
			slot.custom_minimum_size = slot.size
			slot.set_item({})
		else:
			slot.size = Vector2(grid_cell_size, grid_cell_size)
			slot.custom_minimum_size = slot.size
			slot.set_item({})


func _transfer_item(source: InventorySlot, target: InventorySlot) -> void:
	_clear_drag_highlights()
	if source == target or not chest_model:
		return

	var is_source_chest := grid_slots.has(source)
	var is_target_chest := grid_slots.has(target)

	if is_source_chest and is_target_chest:
		# Перемещение внутри сундука
		chest_model.transfer(chest_model.grid_ref(source.slot_index), chest_model.grid_ref(target.slot_index))
	elif is_source_chest and not is_target_chest:
		# Из сундука в инвентарь игрока
		_transfer_chest_to_player(source, target)
	elif not is_source_chest and is_target_chest:
		# Из инвентаря игрока в сундук
		_transfer_player_to_chest(source, target)


func _ensure_player_ref() -> bool:
	if not player_ref or not is_instance_valid(player_ref):
		if get_tree():
			player_ref = get_tree().get_first_node_in_group("Player")
	return player_ref != null and player_ref.get("inventory_ui") != null


func _transfer_chest_to_player(source: InventorySlot, target: InventorySlot) -> void:
	if not _ensure_player_ref():
		return
	var player_inv_ui = player_ref.inventory_ui
	var player_model = player_inv_ui.inventory_model
	if not player_model:
		return
	
	var item_to_move: Dictionary = chest_model.get_item(chest_model.grid_ref(source.slot_index))
	if item_to_move.is_empty():
		return
		
	var target_ref: Dictionary
	if target.slot_index >= 0:
		target_ref = player_model.grid_ref(target.slot_index)
	else:
		var equip_key: String = str(player_inv_ui.equipment_key_by_slot.get(target, ""))
		target_ref = player_model.equipment_ref(equip_key)
		
	var target_item: Dictionary = player_model.get_item(target_ref)
	
	if target_item.is_empty():
		if player_model.can_accept(target_ref, item_to_move):
			var removed: Dictionary = chest_model.remove_item(chest_model.grid_ref(source.slot_index))
			var dest_index: int = target.slot_index if target.slot_index >= 0 else -1
			player_model._put_item(target_ref, removed, dest_index)
			player_model.changed.emit()
			chest_model.changed.emit()
	else:
		# Обмен предметами между сундуком и инвентарём
		if player_model.can_accept(target_ref, item_to_move) and chest_model.can_accept(chest_model.grid_ref(source.slot_index), target_item):
			var item_from_chest: Dictionary = chest_model.remove_item(chest_model.grid_ref(source.slot_index))
			var item_from_player: Dictionary = player_model.remove_item(target_ref)
			player_model._put_item(target_ref, item_from_chest, target.slot_index)
			chest_model._put_item(chest_model.grid_ref(source.slot_index), item_from_player, source.slot_index)
			player_model.changed.emit()
			chest_model.changed.emit()


func _transfer_player_to_chest(source: InventorySlot, target: InventorySlot) -> void:
	if not _ensure_player_ref():
		return
	var player_inv_ui = player_ref.inventory_ui
	var player_model = player_inv_ui.inventory_model
	if not player_model:
		return

	var source_ref: Dictionary
	if source.slot_index >= 0:
		source_ref = player_model.grid_ref(source.slot_index)
	else:
		var equip_key: String = str(player_inv_ui.equipment_key_by_slot.get(source, ""))
		source_ref = player_model.equipment_ref(equip_key)

	var item_to_move: Dictionary = player_model.get_item(source_ref)
	if item_to_move.is_empty():
		return

	var target_ref: Dictionary = chest_model.grid_ref(target.slot_index)
	var target_item: Dictionary = chest_model.get_item(target_ref)

	if target_item.is_empty():
		if chest_model.can_accept(target_ref, item_to_move):
			var removed: Dictionary = player_model.remove_item(source_ref)
			chest_model._put_item(target_ref, removed, target.slot_index)
			player_model.changed.emit()
			chest_model.changed.emit()
	else:
		if chest_model.can_accept(target_ref, item_to_move) and player_model.can_accept(source_ref, target_item):
			var item_from_player: Dictionary = player_model.remove_item(source_ref)
			var item_from_chest: Dictionary = chest_model.remove_item(target_ref)
			chest_model._put_item(target_ref, item_from_player, target.slot_index)
			player_model._put_item(source_ref, item_from_chest, source.slot_index)
			player_model.changed.emit()
			chest_model.changed.emit()


func _can_drop_on_slot(source: InventorySlot, target: InventorySlot, dragged_item: Dictionary) -> bool:
	if source == target:
		return false
	var is_source_chest := grid_slots.has(source)
	var is_target_chest := grid_slots.has(target)

	if is_source_chest and is_target_chest:
		return chest_model.can_transfer(chest_model.grid_ref(source.slot_index), chest_model.grid_ref(target.slot_index))
	elif not is_source_chest and is_target_chest:
		return chest_model.can_accept(chest_model.grid_ref(target.slot_index), dragged_item)
	elif is_source_chest and not is_target_chest:
		if player_ref and player_ref.get("inventory_ui"):
			var player_inv_ui = player_ref.inventory_ui
			var player_model = player_inv_ui.inventory_model
			if player_model:
				if target.slot_index >= 0:
					return player_model.can_accept(player_model.grid_ref(target.slot_index), dragged_item)
				else:
					var equip_key: String = str(player_inv_ui.equipment_key_by_slot.get(target, ""))
					if not equip_key.is_empty():
						return player_model.can_accept(player_model.equipment_ref(equip_key), dragged_item)
	return false


func _activate_item(slot: InventorySlot) -> void:
	if slot.item.is_empty() or not chest_model:
		return
	# Быстрое перемещение из сундука в инвентарь игрока по двойному клику
	if grid_slots.has(slot):
		if player_ref and player_ref.get("inventory_ui"):
			var player_inv_ui = player_ref.inventory_ui
			if player_inv_ui.add_item(slot.item):
				chest_model.remove_item(chest_model.grid_ref(slot.slot_index))


func _show_drag_destination(source: InventorySlot, target: InventorySlot, dragged_item: Dictionary) -> void:
	_clear_drag_highlights()
	if not grid_slots.has(target):
		return
	var valid := _can_drop_on_slot(source, target, dragged_item)
	var item_size := chest_model.get_item_size(dragged_item)
	var target_index := target.slot_index
	var occupied_anchor := chest_model.get_anchor_index(target_index)
	if occupied_anchor >= 0:
		target_index = occupied_anchor
	var start_column := target_index % GRID_COLS
	var start_row := target_index / GRID_ROWS
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


func _apply_gothic_style() -> void:
	root_panel.theme = GOTHIC_THEME
	root_panel.clip_contents = true
	root_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root_panel.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	
	var backdrop := root_panel.get_node_or_null("ChestBackdrop") as TextureRect
	if not backdrop:
		backdrop = TextureRect.new()
		backdrop.name = "ChestBackdrop"
		backdrop.texture = INVENTORY_BACKDROP
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.modulate = Color(0.85, 0.82, 0.88, 1.0)
		root_panel.add_child(backdrop)
		root_panel.move_child(backdrop, 0)

	var inner := root_panel.get_node("InnerBorder") as PanelContainer
	inner.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.018, 0.012, 0.01, 0.18), Color(0.36, 0.25, 0.10, 0.65), 1))
	var outer_margin := root_panel.get_node("InnerBorder/OM") as MarginContainer
	outer_margin.add_theme_constant_override("margin_left", 20)
	outer_margin.add_theme_constant_override("margin_top", 20)
	outer_margin.add_theme_constant_override("margin_right", 20)
	outer_margin.add_theme_constant_override("margin_bottom", 22)

	var grid_card := root_panel.get_node("InnerBorder/OM/VBox/GridCard") as PanelContainer
	grid_card.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.018, 0.013, 0.011, 0.76), Color(0.37, 0.25, 0.10, 0.95), 3, 0, 8))
	var footer := root_panel.get_node("InnerBorder/OM/VBox/Footer") as PanelContainer
	footer.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.025, 0.016, 0.012, 0.84), Color(0.35, 0.23, 0.09, 0.9), 2))

	var divider := root_panel.get_node("InnerBorder/OM/VBox/Sep1") as PanelContainer
	if divider:
		divider.add_theme_stylebox_override("panel", GothicUI.divider_style(Color(0.50, 0.31, 0.09, 0.9)))
	
	if title_label:
		title_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		title_label.add_theme_color_override("font_color", GothicUI.BRASS_LIGHT)
		title_label.add_theme_color_override("font_outline_color", GothicUI.INK)
		title_label.add_theme_constant_override("outline_size", 4)
		title_label.add_theme_font_size_override("font_size", 14)
	if sort_button:
		sort_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if close_button:
		close_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
