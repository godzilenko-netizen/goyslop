extends CanvasLayer

const InventoryModelType = preload("res://scripts/data/inventory_model.gd")

const GRID_COLS := 10
const GRID_ROWS := 6
const INVENTORY_CAPACITY := GRID_COLS * GRID_ROWS
const MARGIN_TOP := 16.0
const MARGIN_BOTTOM := 115.0
const MARGIN_RIGHT := 14.0

@onready var root_panel: Control = $RootPanel
@onready var grid_root: GridContainer = $RootPanel/InnerBorder/OM/VBox/GridCard/GridMargin/GridRoot
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
	var vp := get_viewport().get_visible_rect().size
	panel_w = vp.x * 0.44 - MARGIN_RIGHT
	panel_h = vp.y - MARGIN_TOP - MARGIN_BOTTOM
	root_panel.size = Vector2(panel_w, panel_h)
	root_panel.position = Vector2(vp.x, MARGIN_TOP)
	root_panel.visible = false

	_setup_equipment_slots()
	_setup_grid()
	var categories := {}
	for key in EQUIPMENT_PATHS:
		categories[key] = str(EQUIPMENT_PATHS[key][1])
	inventory_model = InventoryModelType.new(INVENTORY_CAPACITY, categories)
	inventory_model.changed.connect(_sync_slots)
	inventory_model.gold_changed.connect(_update_gold)
	sort_button.flat = true
	sort_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sort_button.pressed.connect(sort_inventory)
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
	grid_root.columns = GRID_COLS
	var inner_w := panel_w - 164.0
	var gap := 2
	var cell_size: int = max(int((inner_w - (GRID_COLS - 1) * gap) / GRID_COLS), 36)
	grid_root.add_theme_constant_override("h_separation", gap)
	grid_root.add_theme_constant_override("v_separation", gap)

	for index in range(INVENTORY_CAPACITY):
		var slot := InventorySlot.new()
		slot.custom_minimum_size = Vector2(cell_size, cell_size)
		slot.add_theme_stylebox_override("panel", _make_grid_style())
		slot.configure(index)
		_connect_slot(slot)
		grid_root.add_child(slot)
		grid_slots.append(slot)


func _connect_slot(slot: InventorySlot) -> void:
	slot.transfer_requested.connect(_transfer_item)
	slot.activate_requested.connect(_activate_item)


func _make_grid_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.060, 0.050, 0.035, 0.93)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.30, 0.22, 0.08, 0.90)
	style.set_corner_radius_all(2)
	return style


func _transfer_item(source: InventorySlot, target: InventorySlot) -> void:
	if source == target:
		return
	inventory_model.transfer(_slot_ref(source), _slot_ref(target))


func _activate_item(slot: InventorySlot) -> void:
	if slot.item.is_empty():
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
		var empty_slot := _first_empty_grid_slot()
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


func _first_empty_grid_slot() -> InventorySlot:
	for slot in grid_slots:
		if slot.item.is_empty():
			return slot
	return null


func _slot_ref(slot: InventorySlot) -> Dictionary:
	if slot.slot_index >= 0:
		return inventory_model.grid_ref(slot.slot_index)
	return inventory_model.equipment_ref(str(equipment_key_by_slot.get(slot, "")))


func _sync_slots() -> void:
	for index in range(grid_slots.size()):
		grid_slots[index].set_item(inventory_model.get_item(inventory_model.grid_ref(index)))
	for key in equipment_slots:
		equipment_slots[key].set_item(inventory_model.get_item(inventory_model.equipment_ref(key)))


func _update_gold(_value: int = 0) -> void:
	if gold_label:
		gold_label.text = str(inventory_model.gold if inventory_model else 0)
