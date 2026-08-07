extends PanelContainer
class_name InventorySlot

const GothicUI = preload("res://scripts/ui/gothic_ui.gd")

signal transfer_requested(from_slot: InventorySlot, to_slot: InventorySlot)
signal activate_requested(slot: InventorySlot)
signal drag_hovered(from_slot: InventorySlot, to_slot: InventorySlot, dragged_item: Dictionary)
signal drag_finished

var item: Dictionary = {}
var slot_index: int = -1
var allowed_category: String = ""
var placeholder: String = ""
var drop_validator: Callable = Callable()

var _item_label: Label
var _placeholder_label: Label
var _item_icon: TextureRect
var _quantity_label: Label
var _drag_cell_size: int = 36
var _drag_gap: int = 2
var _drag_active := false


func configure(index: int, category: String = "", empty_text: String = "") -> void:
	slot_index = index
	allowed_category = category
	placeholder = empty_text
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_placeholder_label = get_node_or_null("L") as Label
	_ensure_item_visuals()
	_refresh()


func set_drag_grid_metrics(cell_size: int, gap: int) -> void:
	_drag_cell_size = maxi(cell_size, 1)
	_drag_gap = maxi(gap, 0)


func set_item(value: Dictionary) -> void:
	item = value.duplicate(true) if not value.is_empty() else {}
	_refresh()


func take_item() -> Dictionary:
	var result := item
	item = {}
	_refresh()
	return result


func can_accept(candidate: Dictionary) -> bool:
	if candidate.is_empty() or allowed_category.is_empty():
		return true
	return str(candidate.get("slot", "")) == allowed_category


func _ensure_item_visuals() -> void:
	_item_icon = get_node_or_null("ItemIcon") as TextureRect
	if not _item_icon:
		_item_icon = TextureRect.new()
		_item_icon.name = "ItemIcon"
		_item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_item_icon.offset_left = 4.0
		_item_icon.offset_top = 4.0
		_item_icon.offset_right = -4.0
		_item_icon.offset_bottom = -4.0
		_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_item_icon)

	_item_label = get_node_or_null("ItemLabel") as Label
	if not _item_label:
		_item_label = Label.new()
		_item_label.name = "ItemLabel"
		_item_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_item_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_item_label.add_theme_font_size_override("font_size", 11)
		_item_label.add_theme_color_override("font_outline_color", GothicUI.INK)
		_item_label.add_theme_constant_override("outline_size", 4)
		_item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_item_label)
	else:
		_item_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	_quantity_label = get_node_or_null("QuantityLabel") as Label
	if not _quantity_label:
		_quantity_label = Label.new()
		_quantity_label.name = "QuantityLabel"
		_quantity_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_quantity_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_quantity_label.offset_right = -5.0
		_quantity_label.offset_bottom = -3.0
		_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_quantity_label.add_theme_font_size_override("font_size", 11)
		_quantity_label.add_theme_color_override("font_color", GothicUI.BONE)
		_quantity_label.add_theme_color_override("font_outline_color", GothicUI.INK)
		_quantity_label.add_theme_constant_override("outline_size", 4)
		_quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_quantity_label)
	else:
		_quantity_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	if _placeholder_label:
		_placeholder_label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _refresh() -> void:
	if not _item_label:
		return
	var empty := item.is_empty()
	_item_label.visible = false
	_item_icon.visible = false
	_quantity_label.visible = false
	if _placeholder_label:
		_placeholder_label.visible = empty
	if empty:
		tooltip_text = placeholder
		return

	var quantity := int(item.get("quantity", 1))
	var icon_path := str(item.get("icon", ""))
	if not icon_path.is_empty():
		var tex: Texture2D = null
		if ResourceLoader.exists(icon_path):
			tex = load(icon_path) as Texture2D
		if not tex:
			var global_p := ProjectSettings.globalize_path(icon_path)
			if FileAccess.file_exists(global_p):
				var img := Image.load_from_file(global_p)
				if img:
					tex = ImageTexture.create_from_image(img)
		_item_icon.texture = tex
		_item_icon.visible = _item_icon.texture != null
	else:
		_item_icon.texture = null

	if not _item_icon.visible:
		var suffix := "\nx%d" % quantity if quantity > 1 else ""
		_item_label.text = "%s%s" % [str(item.get("name", "Предмет")), suffix]
		_item_label.visible = true
	elif quantity > 1:
		_quantity_label.text = str(quantity)
		_quantity_label.visible = true

	var rarity := str(item.get("rarity", "common"))
	var colors := {
		"common": Color(0.76, 0.76, 0.78),
		"magic": Color(0.38, 0.68, 1.0),
		"rare": Color(1.0, 0.82, 0.22),
		"unique": Color(1.0, 0.48, 0.12),
	}
	_item_label.add_theme_color_override("font_color", colors.get(rarity, colors["common"]))
	var item_size: Vector2i = item.get("grid_size", Vector2i.ONE)
	var stats_text := ""
	if int(item.get("armor", 0)) > 0:
		stats_text = "\nБроня: %d" % int(item.get("armor", 0))
	tooltip_text = "%s%s\nРазмер: %d×%d\n%s" % [
		str(item.get("name", "Предмет")), stats_text, item_size.x, item_size.y,
		str(item.get("description", ""))
	]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item.is_empty():
		return null
	_drag_active = true
	modulate.a = 0.32
	set_drag_preview(_create_drag_preview())
	return {"source": self, "item": item.duplicate(true)}


func _create_drag_preview() -> Control:
	var item_size: Vector2i = item.get("grid_size", Vector2i.ONE)
	var preview_size := Vector2(
		item_size.x * _drag_cell_size + (item_size.x - 1) * _drag_gap,
		item_size.y * _drag_cell_size + (item_size.y - 1) * _drag_gap
	)
	var preview := PanelContainer.new()
	preview.custom_minimum_size = preview_size
	preview.size = preview_size
	preview.position = Vector2(10.0, 10.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.62)

	preview.add_theme_stylebox_override("panel", GothicUI.panel_style(Color(0.025, 0.018, 0.014, 0.82), GothicUI.BRASS, 2, 1, 5))

	var icon_path := str(item.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var preview_icon := TextureRect.new()
		preview_icon.texture = load(icon_path) as Texture2D
		preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(preview_icon)
	else:
		var preview_label := Label.new()
		preview_label.text = str(item.get("name", "Предмет"))
		preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preview_label.add_theme_font_size_override("font_size", 11)
		preview_label.add_theme_color_override("font_outline_color", Color.BLACK)
		preview_label.add_theme_constant_override("outline_size", 3)
		preview.add_child(preview_label)
	return preview


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var source = data.get("source")
	if not source is InventorySlot or source == self:
		return false
	var dragged_item: Dictionary = data.get("item", {})
	drag_hovered.emit(source, self, dragged_item)
	if drop_validator.is_valid():
		return bool(drop_validator.call(source, self, dragged_item))
	return can_accept(dragged_item)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source = data.get("source")
	if source is InventorySlot:
		transfer_requested.emit(source, self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_active:
		_drag_active = false
		modulate.a = 1.0
		drag_finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click and not item.is_empty():
			activate_requested.emit(self)
			accept_event()
