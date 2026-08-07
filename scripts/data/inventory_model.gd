class_name InventoryModel
extends RefCounted

signal changed
signal gold_changed(value: int)

var capacity: int
var columns: int
var rows: int
var items: Array[Dictionary] = []
var occupancy: Array[int] = []
var equipment: Dictionary = {}
var equipment_categories: Dictionary = {}
var gold: int = 0


func _init(slot_capacity: int, categories: Dictionary, grid_columns: int = 0) -> void:
	capacity = maxi(slot_capacity, 1)
	columns = clampi(grid_columns if grid_columns > 0 else capacity, 1, capacity)
	rows = ceili(float(capacity) / float(columns))
	equipment_categories = categories.duplicate(true)
	for _index in range(capacity):
		items.append({})
		occupancy.append(-1)
	for key in equipment_categories:
		equipment[key] = {}


func grid_ref(index: int) -> Dictionary:
	return {"kind": "grid", "index": index}


func equipment_ref(key: String) -> Dictionary:
	return {"kind": "equipment", "key": key}


func get_item(slot_ref: Dictionary) -> Dictionary:
	if str(slot_ref.get("kind", "")) == "grid":
		var anchor := get_anchor_index(int(slot_ref.get("index", -1)))
		return items[anchor] if anchor >= 0 else {}
	var key := str(slot_ref.get("key", ""))
	return equipment.get(key, {})


func get_anchor_index(index: int) -> int:
	if index < 0 or index >= occupancy.size():
		return -1
	return occupancy[index]


func is_anchor(index: int) -> bool:
	return get_anchor_index(index) == index


func get_item_size(candidate: Dictionary) -> Vector2i:
	var raw_size: Variant = candidate.get("grid_size", Vector2i.ONE)
	var result := Vector2i.ONE
	if raw_size is Vector2i:
		result = raw_size
	elif raw_size is Vector2:
		result = Vector2i(raw_size)
	elif raw_size is Array and raw_size.size() >= 2:
		result = Vector2i(int(raw_size[0]), int(raw_size[1]))
	elif raw_size is Dictionary:
		result = Vector2i(int(raw_size.get("x", 1)), int(raw_size.get("y", 1)))
	return Vector2i(maxi(result.x, 1), maxi(result.y, 1))


func can_place_at(index: int, candidate: Dictionary, ignored_anchor: int = -1) -> bool:
	if candidate.is_empty() or index < 0 or index >= capacity:
		return candidate.is_empty()
	var item_size := get_item_size(candidate)
	var start_col := index % columns
	var start_row := index / columns
	if start_col + item_size.x > columns or start_row + item_size.y > rows:
		return false
	for y in range(item_size.y):
		for x in range(item_size.x):
			var cell := (start_row + y) * columns + start_col + x
			if cell >= capacity:
				return false
			var occupied_by := occupancy[cell]
			if occupied_by >= 0 and occupied_by != ignored_anchor:
				return false
	return true


func find_first_fit(candidate: Dictionary) -> int:
	for index in range(capacity):
		if can_place_at(index, candidate):
			return index
	return -1


func can_accept(slot_ref: Dictionary, candidate: Dictionary) -> bool:
	if candidate.is_empty():
		return true
	if str(slot_ref.get("kind", "")) == "grid":
		var index := int(slot_ref.get("index", -1))
		return can_place_at(index, candidate, get_anchor_index(index))
	var key := str(slot_ref.get("key", ""))
	return str(candidate.get("slot", "")) == str(equipment_categories.get(key, ""))


func transfer(source_ref: Dictionary, target_ref: Dictionary) -> bool:
	var source_item := get_item(source_ref)
	var target_item := get_item(target_ref)
	if source_item.is_empty():
		return false

	var source_kind := str(source_ref.get("kind", ""))
	var target_kind := str(target_ref.get("kind", ""))
	var source_grid_index := get_anchor_index(int(source_ref.get("index", -1))) if source_kind == "grid" else -1
	var requested_target_index := int(target_ref.get("index", -1)) if target_kind == "grid" else -1
	var target_grid_anchor := get_anchor_index(requested_target_index) if target_kind == "grid" else -1
	if source_kind == "grid" and target_kind == "grid" and source_grid_index == target_grid_anchor:
		return false

	if target_kind == "equipment" and not can_accept(target_ref, source_item):
		return false
	if not target_item.is_empty() and source_kind == "equipment" and not can_accept(source_ref, target_item):
		return false

	var old_items := _copy_items()
	var old_occupancy: Array[int] = occupancy.duplicate()
	var old_equipment := equipment.duplicate(true)

	_clear_slot(source_ref)
	if not target_item.is_empty():
		_clear_slot(target_ref)

	var target_destination := target_grid_anchor if target_grid_anchor >= 0 else requested_target_index
	if not _put_item(target_ref, source_item, target_destination):
		_restore_snapshot(old_items, old_occupancy, old_equipment)
		return false
	if not target_item.is_empty():
		if not _put_item(source_ref, target_item, source_grid_index):
			_restore_snapshot(old_items, old_occupancy, old_equipment)
			return false

	changed.emit()
	return true


func can_transfer(source_ref: Dictionary, target_ref: Dictionary) -> bool:
	var simulation := InventoryModel.new(capacity, equipment_categories, columns)
	simulation.items = _copy_items()
	simulation.occupancy = occupancy.duplicate()
	simulation.equipment = equipment.duplicate(true)
	return simulation.transfer(source_ref, target_ref)


func remove_item(slot_ref: Dictionary) -> Dictionary:
	var stored := get_item(slot_ref)
	if stored.is_empty():
		return {}
	var result := stored.duplicate(true)
	_clear_slot(slot_ref)
	changed.emit()
	return result


func consume(slot_ref: Dictionary, amount: int = 1) -> bool:
	var item := get_item(slot_ref)
	if item.is_empty() or amount <= 0:
		return false
	var remaining := int(item.get("quantity", 1)) - amount
	if str(slot_ref.get("kind", "")) == "grid":
		var anchor := get_anchor_index(int(slot_ref.get("index", -1)))
		if remaining > 0:
			var updated := item.duplicate(true)
			updated["quantity"] = remaining
			items[anchor] = updated
		else:
			_clear_grid_at(anchor)
	else:
		var key := str(slot_ref.get("key", ""))
		if remaining > 0:
			var updated := item.duplicate(true)
			updated["quantity"] = remaining
			equipment[key] = updated
		else:
			equipment[key] = {}
	changed.emit()
	return true


func add_item(new_item: Dictionary) -> bool:
	if new_item.is_empty() or not new_item.has("id") or not new_item.has("name"):
		return false
	var old_items := _copy_items()
	var old_occupancy: Array[int] = occupancy.duplicate()
	var remaining := int(new_item.get("quantity", 1))
	var max_stack: int = maxi(1, int(new_item.get("max_stack", 1)))

	if max_stack > 1:
		for index in range(items.size()):
			var existing := items[index]
			if existing.is_empty() or existing.get("id") != new_item.get("id"):
				continue
			if int(existing.get("quantity", 1)) >= max_stack:
				continue
			var space: int = max_stack - int(existing.get("quantity", 1))
			var moved: int = mini(space, remaining)
			existing["quantity"] = int(existing.get("quantity", 1)) + moved
			items[index] = existing
			remaining -= moved
			if remaining <= 0:
				break

	while remaining > 0:
		var placed := new_item.duplicate(true)
		placed["quantity"] = mini(remaining, max_stack)
		placed["grid_size"] = get_item_size(placed)
		var empty_index := find_first_fit(placed)
		if empty_index < 0 or not _place_grid_item(empty_index, placed):
			items = old_items
			occupancy = old_occupancy
			return false
		remaining -= int(placed["quantity"])

	changed.emit()
	return true


func sort_items() -> void:
	var stored: Array[Dictionary] = []
	for item in items:
		if not item.is_empty():
			stored.append(item.duplicate(true))
	stored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_size := get_item_size(a)
		var b_size := get_item_size(b)
		var a_area := a_size.x * a_size.y
		var b_area := b_size.x * b_size.y
		if a_area != b_area:
			return a_area > b_area
		var a_key := "%s_%s" % [str(a.get("slot", "zz_consumable")), str(a.get("name", ""))]
		var b_key := "%s_%s" % [str(b.get("slot", "zz_consumable")), str(b.get("name", ""))]
		return a_key.naturalnocasecmp_to(b_key) < 0
	)
	_clear_grid()
	for item in stored:
		var index := find_first_fit(item)
		if index >= 0:
			_place_grid_item(index, item)
	changed.emit()


func set_gold(amount: int) -> void:
	gold = maxi(0, amount)
	gold_changed.emit(gold)


func serialize() -> Dictionary:
	return {
		"version": 2,
		"gold": gold,
		"columns": columns,
		"items": _copy_items(),
		"equipment": equipment.duplicate(true),
	}


func load_state(state: Dictionary) -> void:
	_clear_grid()
	var stored_items: Array = state.get("items", [])
	for index in range(mini(stored_items.size(), capacity)):
		var value: Variant = stored_items[index]
		if not value is Dictionary or value.is_empty():
			continue
		var item: Dictionary = value.duplicate(true)
		if not _place_grid_item(index, item):
			var fallback := find_first_fit(item)
			if fallback >= 0:
				_place_grid_item(fallback, item)
	var stored_equipment: Dictionary = state.get("equipment", {})
	for key in equipment:
		var value: Dictionary = stored_equipment.get(key, {})
		equipment[key] = value.duplicate(true) if can_accept(equipment_ref(key), value) else {}
	gold = maxi(0, int(state.get("gold", 0)))
	changed.emit()
	gold_changed.emit(gold)


func _place_grid_item(index: int, value: Dictionary) -> bool:
	if not can_place_at(index, value):
		return false
	var copy := value.duplicate(true)
	var item_size := get_item_size(copy)
	copy["grid_size"] = item_size
	items[index] = copy
	var start_col := index % columns
	var start_row := index / columns
	for y in range(item_size.y):
		for x in range(item_size.x):
			var cell := (start_row + y) * columns + start_col + x
			occupancy[cell] = index
	return true


func _clear_grid_at(index: int) -> void:
	var anchor := get_anchor_index(index)
	if anchor < 0:
		return
	for cell in range(occupancy.size()):
		if occupancy[cell] == anchor:
			occupancy[cell] = -1
	items[anchor] = {}


func _clear_grid() -> void:
	for index in range(capacity):
		items[index] = {}
		occupancy[index] = -1


func _clear_slot(slot_ref: Dictionary) -> void:
	if str(slot_ref.get("kind", "")) == "grid":
		_clear_grid_at(int(slot_ref.get("index", -1)))
	else:
		var key := str(slot_ref.get("key", ""))
		if equipment.has(key):
			equipment[key] = {}


func _put_item(slot_ref: Dictionary, value: Dictionary, grid_index: int = -1) -> bool:
	if str(slot_ref.get("kind", "")) == "grid":
		return _place_grid_item(grid_index, value)
	if not can_accept(slot_ref, value):
		return false
	var key := str(slot_ref.get("key", ""))
	equipment[key] = value.duplicate(true)
	return true


func _copy_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items:
		result.append(item.duplicate(true))
	return result


func _restore_snapshot(old_items: Array[Dictionary], old_occupancy: Array[int], old_equipment: Dictionary) -> void:
	items = old_items
	occupancy = old_occupancy
	equipment = old_equipment
