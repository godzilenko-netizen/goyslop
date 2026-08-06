class_name InventoryModel
extends RefCounted

signal changed
signal gold_changed(value: int)

var capacity: int
var items: Array[Dictionary] = []
var equipment: Dictionary = {}
var equipment_categories: Dictionary = {}
var gold: int = 0


func _init(slot_capacity: int, categories: Dictionary) -> void:
	capacity = slot_capacity
	equipment_categories = categories.duplicate(true)
	for _index in range(capacity):
		items.append({})
	for key in equipment_categories:
		equipment[key] = {}


func grid_ref(index: int) -> Dictionary:
	return {"kind": "grid", "index": index}


func equipment_ref(key: String) -> Dictionary:
	return {"kind": "equipment", "key": key}


func get_item(slot_ref: Dictionary) -> Dictionary:
	if str(slot_ref.get("kind", "")) == "grid":
		var index := int(slot_ref.get("index", -1))
		return items[index] if index >= 0 and index < items.size() else {}
	var key := str(slot_ref.get("key", ""))
	return equipment.get(key, {})


func can_accept(slot_ref: Dictionary, candidate: Dictionary) -> bool:
	if candidate.is_empty():
		return true
	if str(slot_ref.get("kind", "")) == "grid":
		return true
	var key := str(slot_ref.get("key", ""))
	return str(candidate.get("slot", "")) == str(equipment_categories.get(key, ""))


func transfer(source_ref: Dictionary, target_ref: Dictionary) -> bool:
	var source_item := get_item(source_ref)
	var target_item := get_item(target_ref)
	if source_item.is_empty() or not can_accept(target_ref, source_item):
		return false
	if not target_item.is_empty() and not can_accept(source_ref, target_item):
		return false
	_set_item(source_ref, target_item)
	_set_item(target_ref, source_item)
	changed.emit()
	return true


func consume(slot_ref: Dictionary, amount: int = 1) -> bool:
	var item := get_item(slot_ref)
	if item.is_empty() or amount <= 0:
		return false
	var remaining := int(item.get("quantity", 1)) - amount
	if remaining > 0:
		var updated := item.duplicate(true)
		updated["quantity"] = remaining
		_set_item(slot_ref, updated)
	else:
		_set_item(slot_ref, {})
	changed.emit()
	return true


func add_item(new_item: Dictionary) -> bool:
	if new_item.is_empty() or not new_item.has("id") or not new_item.has("name"):
		return false
	var working: Array[Dictionary] = []
	for item in items:
		working.append(item.duplicate(true))
	var remaining := int(new_item.get("quantity", 1))
	var max_stack: int = maxi(1, int(new_item.get("max_stack", 1)))
	if max_stack > 1:
		for index in range(working.size()):
			var existing := working[index]
			if existing.get("id") == new_item.get("id") and int(existing.get("quantity", 1)) < max_stack:
				var space: int = max_stack - int(existing.get("quantity", 1))
				var moved: int = mini(space, remaining)
				existing["quantity"] = int(existing.get("quantity", 1)) + moved
				working[index] = existing
				remaining -= moved
				if remaining <= 0:
					break
	while remaining > 0:
		var empty_index := _first_empty_index(working)
		if empty_index < 0:
			return false
		var placed := new_item.duplicate(true)
		placed["quantity"] = mini(remaining, max_stack)
		working[empty_index] = placed
		remaining -= int(placed["quantity"])
	items = working
	changed.emit()
	return true


func sort_items() -> void:
	var occupied: Array[Dictionary] = []
	for item in items:
		if not item.is_empty():
			occupied.append(item.duplicate(true))
	occupied.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := "%s_%s" % [str(a.get("slot", "zz_consumable")), str(a.get("name", ""))]
		var b_key := "%s_%s" % [str(b.get("slot", "zz_consumable")), str(b.get("name", ""))]
		return a_key.naturalnocasecmp_to(b_key) < 0
	)
	for index in range(items.size()):
		items[index] = occupied[index] if index < occupied.size() else {}
	changed.emit()


func set_gold(amount: int) -> void:
	gold = maxi(0, amount)
	gold_changed.emit(gold)


func serialize() -> Dictionary:
	var stored_items: Array[Dictionary] = []
	for item in items:
		stored_items.append(item.duplicate(true))
	var stored_equipment := {}
	for key in equipment:
		stored_equipment[key] = equipment[key].duplicate(true)
	return {"version": 1, "gold": gold, "items": stored_items, "equipment": stored_equipment}


func load_state(state: Dictionary) -> void:
	var stored_items: Array = state.get("items", [])
	for index in range(capacity):
		var value = stored_items[index] if index < stored_items.size() else {}
		items[index] = value.duplicate(true) if value is Dictionary else {}
	var stored_equipment: Dictionary = state.get("equipment", {})
	for key in equipment:
		var value: Dictionary = stored_equipment.get(key, {})
		equipment[key] = value.duplicate(true) if can_accept(equipment_ref(key), value) else {}
	gold = maxi(0, int(state.get("gold", 0)))
	changed.emit()
	gold_changed.emit(gold)


func _set_item(slot_ref: Dictionary, value: Dictionary) -> void:
	var copy := value.duplicate(true) if not value.is_empty() else {}
	if str(slot_ref.get("kind", "")) == "grid":
		var index := int(slot_ref.get("index", -1))
		if index >= 0 and index < items.size():
			items[index] = copy
	else:
		var key := str(slot_ref.get("key", ""))
		if equipment.has(key):
			equipment[key] = copy


func _first_empty_index(collection: Array[Dictionary]) -> int:
	for index in range(collection.size()):
		if collection[index].is_empty():
			return index
	return -1
