extends CanvasLayer

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
var gold := 0
var grid_slots: Array[InventorySlot] = []
var equipment_slots: Dictionary = {}

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
	sort_button.flat = true
	sort_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sort_button.pressed.connect(sort_inventory)
	_seed_starter_items()
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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var vp := get_viewport().get_visible_rect().size
	var tw := create_tween()
	tw.tween_property(root_panel, "position:x", vp.x, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): root_panel.visible = false)
	if player_ref and player_ref.has_method("shift_camera_for_ui"):
		player_ref.shift_camera_for_ui(false)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _setup_equipment_slots() -> void:
	for key in EQUIPMENT_PATHS:
		var config: Array = EQUIPMENT_PATHS[key]
		var slot := get_node(str(config[0])) as InventorySlot
		slot.configure(-1, str(config[1]), str(config[2]))
		_connect_slot(slot)
		equipment_slots[key] = slot


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
	if source == target or source.item.is_empty() or not target.can_accept(source.item):
		return
	if not target.item.is_empty() and not source.can_accept(target.item):
		return
	var source_item := source.take_item()
	var target_item := target.take_item()
	target.set_item(source_item)
	source.set_item(target_item)


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
	if effect == "health":
		var current_hp := int(player_ref.get("current_hp"))
		var max_hp := int(player_ref.get("max_hp"))
		player_ref.set("current_hp", min(max_hp, current_hp + int(slot.item.get("power", 35))))
	elif effect == "mana":
		var current_energy := int(player_ref.get("current_energy"))
		var max_energy := int(player_ref.get("max_energy"))
		player_ref.set("current_energy", min(max_energy, current_energy + int(slot.item.get("power", 25))))
	else:
		return
	if player_ref.has_method("_update_hud"):
		player_ref.call("_update_hud")
	var updated := slot.item.duplicate(true)
	updated["quantity"] = int(updated.get("quantity", 1)) - 1
	slot.set_item(updated if updated["quantity"] > 0 else {})


func add_item(new_item: Dictionary) -> bool:
	if new_item.is_empty() or not new_item.has("id") or not new_item.has("name"):
		return false
	var remaining := int(new_item.get("quantity", 1))
	var max_stack: int = max(1, int(new_item.get("max_stack", 1)))
	if max_stack > 1:
		for slot in grid_slots:
			if slot.item.get("id") == new_item.get("id") and int(slot.item.get("quantity", 1)) < max_stack:
				var stacked := slot.item.duplicate(true)
				var space: int = max_stack - int(stacked.get("quantity", 1))
				var moved: int = min(space, remaining)
				stacked["quantity"] = int(stacked.get("quantity", 1)) + moved
				slot.set_item(stacked)
				remaining -= moved
				if remaining <= 0:
					return true
	while remaining > 0:
		var empty_slot := _first_empty_grid_slot()
		if not empty_slot:
			return false
		var placed := new_item.duplicate(true)
		placed["quantity"] = min(remaining, max_stack)
		empty_slot.set_item(placed)
		remaining -= int(placed["quantity"])
	return true


func sort_inventory() -> void:
	var items: Array[Dictionary] = []
	for slot in grid_slots:
		if not slot.item.is_empty():
			items.append(slot.item.duplicate(true))
		slot.set_item({})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := "%s_%s" % [str(a.get("slot", "zz_consumable")), str(a.get("name", ""))]
		var b_key := "%s_%s" % [str(b.get("slot", "zz_consumable")), str(b.get("name", ""))]
		return a_key.naturalnocasecmp_to(b_key) < 0
	)
	for index in range(items.size()):
		grid_slots[index].set_item(items[index])


func set_gold(amount: int) -> void:
	gold = max(0, amount)
	_update_gold()


func get_inventory_state() -> Dictionary:
	var stored_items: Array[Dictionary] = []
	for slot in grid_slots:
		stored_items.append(slot.item.duplicate(true))
	var equipped := {}
	for key in equipment_slots:
		equipped[key] = equipment_slots[key].item.duplicate(true)
	return {"gold": gold, "items": stored_items, "equipment": equipped}


func load_inventory_state(state: Dictionary) -> void:
	set_gold(int(state.get("gold", 0)))
	var stored_items: Array = state.get("items", [])
	for index in range(grid_slots.size()):
		grid_slots[index].set_item(stored_items[index] if index < stored_items.size() else {})
	var equipped: Dictionary = state.get("equipment", {})
	for key in equipment_slots:
		var value: Dictionary = equipped.get(key, {})
		equipment_slots[key].set_item(value if equipment_slots[key].can_accept(value) else {})


func _first_empty_grid_slot() -> InventorySlot:
	for slot in grid_slots:
		if slot.item.is_empty():
			return slot
	return null


func _update_gold() -> void:
	if gold_label:
		gold_label.text = str(gold)


func _seed_starter_items() -> void:
	add_item({"id": "bronze_sword", "name": "Бронзовый\nмеч", "slot": "weapon", "rarity": "rare", "description": "+12 к урону"})
	add_item({"id": "ice_wand", "name": "Ледяной\nжезл", "slot": "weapon", "rarity": "magic", "description": "+10% к силе льда"})
	add_item({"id": "leather_helmet", "name": "Кожаный\nшлем", "slot": "helmet", "description": "+5 к защите"})
	add_item({"id": "health_potion", "name": "Зелье HP", "effect": "health", "power": 35, "quantity": 3, "max_stack": 10, "rarity": "magic", "description": "Восстанавливает 35 здоровья"})
	add_item({"id": "mana_potion", "name": "Зелье MP", "effect": "mana", "power": 25, "quantity": 3, "max_stack": 10, "rarity": "magic", "description": "Восстанавливает 25 маны"})
	set_gold(125)
