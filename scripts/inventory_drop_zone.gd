extends Control
class_name InventoryDropZone

const InventorySlotType = preload("res://scripts/inventory_slot.gd")

signal drop_requested(source_slot: InventorySlot, item: Dictionary)
signal drag_hovered


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var source: Variant = data.get("source")
	var item: Dictionary = data.get("item", {})
	var valid: bool = source is InventorySlotType and not item.is_empty()
	if valid:
		drag_hovered.emit()
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source: Variant = data.get("source")
	if source is InventorySlotType:
		drop_requested.emit(source, data.get("item", {}))
