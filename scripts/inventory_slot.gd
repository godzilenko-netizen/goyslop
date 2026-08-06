extends PanelContainer
class_name InventorySlot

signal transfer_requested(from_slot: InventorySlot, to_slot: InventorySlot)
signal activate_requested(slot: InventorySlot)

var item: Dictionary = {}
var slot_index: int = -1
var allowed_category: String = ""
var placeholder: String = ""

var _item_label: Label
var _placeholder_label: Label


func configure(index: int, category: String = "", empty_text: String = "") -> void:
	slot_index = index
	allowed_category = category
	placeholder = empty_text
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_placeholder_label = get_node_or_null("L") as Label
	_ensure_item_label()
	_refresh()


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


func _ensure_item_label() -> void:
	_item_label = get_node_or_null("ItemLabel") as Label
	if _item_label:
		return
	_item_label = Label.new()
	_item_label.name = "ItemLabel"
	_item_label.layout_mode = 2
	_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_label.add_theme_font_size_override("font_size", 10)
	_item_label.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.01, 1.0))
	_item_label.add_theme_constant_override("outline_size", 3)
	_item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_item_label)


func _refresh() -> void:
	if not _item_label:
		return
	var empty := item.is_empty()
	_item_label.visible = not empty
	if _placeholder_label:
		_placeholder_label.visible = empty
	if empty:
		tooltip_text = placeholder
		return

	var quantity := int(item.get("quantity", 1))
	var suffix := "\nx%d" % quantity if quantity > 1 else ""
	_item_label.text = "%s%s" % [str(item.get("name", "Предмет")), suffix]
	var rarity := str(item.get("rarity", "common"))
	var colors := {
		"common": Color(0.88, 0.84, 0.72),
		"magic": Color(0.38, 0.68, 1.0),
		"rare": Color(1.0, 0.82, 0.22),
		"unique": Color(1.0, 0.48, 0.12),
	}
	_item_label.add_theme_color_override("font_color", colors.get(rarity, colors["common"]))
	tooltip_text = "%s\n%s" % [str(item.get("name", "Предмет")), str(item.get("description", ""))]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item.is_empty():
		return null
	var preview := Label.new()
	preview.text = str(item.get("name", "Предмет"))
	preview.add_theme_font_size_override("font_size", 12)
	preview.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	preview.add_theme_constant_override("outline_size", 4)
	set_drag_preview(preview)
	return {"source": self, "item": item.duplicate(true)}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var source = data.get("source")
	return source is InventorySlot and source != self and can_accept(data.get("item", {}))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source = data.get("source")
	if source is InventorySlot:
		transfer_requested.emit(source, self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click and not item.is_empty():
			activate_requested.emit(self)
			accept_event()
