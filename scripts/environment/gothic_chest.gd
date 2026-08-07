extends Node3D
class_name GothicChest

const InventoryModelType = preload("res://scripts/data/inventory_model.gd")
const ItemDataType = preload("res://scripts/data/item_data.gd")
const LEATHER_ARMOR_DATA = preload("res://data/items/leather_armor.tres")
const RING_OF_STRENGTH_DATA = preload("res://data/items/ring_of_strength.tres")

const FloatingLabel = preload("res://scripts/ui/floating_label.gd")

@export var chest_title: String = "Готический сундук"
@export var interaction_range: float = 3.5
@export var auto_close_range: float = 4.8

@onready var lid_pivot: Node3D = $LidPivot
@onready var interaction_area: Area3D = $InteractionArea
@onready var glow_light: OmniLight3D = $GlowLight
@onready var label: Label3D = $Label3D

var inventory_model: InventoryModelType
var is_open: bool = false
var player: Node3D = null
var chest_ui_instance: ChestUI = null
var _tween: Tween = null
var _hovered := false
var floating_label: FloatingLabel = null


func _ready() -> void:
	add_to_group("Interactable")
	inventory_model = InventoryModelType.new(169, {}, 13)
	_populate_initial_loot()

	if label:
		label.fixed_size = false
		label.pixel_size = 0.0045
		label.no_depth_test = true
		label.render_priority = 10
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		label.font_size = 64
		label.outline_size = 8

	if interaction_area:
		interaction_area.input_ray_pickable = true
		interaction_area.mouse_entered.connect(func(): _hovered = true)
		interaction_area.mouse_exited.connect(func(): _hovered = false)
		interaction_area.input_event.connect(_on_area_input_event)

	if glow_light:
		glow_light.light_energy = 0.0

	_update_label()


func _populate_initial_loot() -> void:
	if RING_OF_STRENGTH_DATA:
		inventory_model.add_item(RING_OF_STRENGTH_DATA.to_inventory_item())
	if LEATHER_ARMOR_DATA:
		inventory_model.add_item(LEATHER_ARMOR_DATA.to_inventory_item())
	inventory_model.set_gold(250)


func get_chest_name() -> String:
	return chest_title


func _process(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as Node3D

	var show_all := Input.is_physical_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_ALT)
	var nearby := _is_player_near(interaction_range)
	if label:
		label.visible = show_all or _hovered or nearby

	if is_open and not _is_player_near(auto_close_range):
		close_chest()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		if _is_player_near(interaction_range):
			toggle_chest()
			get_viewport().set_input_as_handled()


func _on_area_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_player_near(interaction_range):
			toggle_chest()
			get_viewport().set_input_as_handled()
		else:
			_show_too_far_message()


func toggle_chest() -> void:
	if is_open:
		close_chest()
	else:
		open_chest()


func open_chest() -> void:
	if is_open:
		return
	is_open = true

	# Поворот крышки сундука назад (~75 градусов по оси X)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if lid_pivot:
		_tween.tween_property(lid_pivot, "rotation:x", -deg_to_rad(78.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if glow_light:
		_tween.tween_property(glow_light, "light_energy", 2.2, 0.4)

	_get_or_create_chest_ui()
	if chest_ui_instance:
		chest_ui_instance.open_chest(self, inventory_model)

	_update_label()


func close_chest() -> void:
	if not is_open:
		return
	is_open = false

	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if lid_pivot:
		_tween.tween_property(lid_pivot, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if glow_light:
		_tween.tween_property(glow_light, "light_energy", 0.0, 0.3)

	if chest_ui_instance and chest_ui_instance.is_open:
		chest_ui_instance.close_chest()

	_update_label()


func close_lid() -> void:
	# Вызывается из UI при закрытии по крестику или Esc
	if is_open:
		is_open = false
		if _tween:
			_tween.kill()
		_tween = create_tween().set_parallel(true)
		if lid_pivot:
			_tween.tween_property(lid_pivot, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if glow_light:
			_tween.tween_property(glow_light, "light_energy", 0.0, 0.3)
		_update_label()


func _is_player_near(dist: float) -> bool:
	return player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) <= dist


func _show_too_far_message() -> void:
	if label:
		label.text = "ПОДОЙДИТЕ БЛИЖЕ"
		label.modulate = Color(1.0, 0.35, 0.25)
		get_tree().create_timer(1.2).timeout.connect(_update_label)


func _update_label() -> void:
	if not is_instance_valid(self) or not label:
		return
	label.modulate = Color(0.94, 0.88, 0.74)
	if is_open:
		label.text = "%s\n[ОТКРЫТО]" % chest_title
	else:
		label.text = "%s (13×13)\nЛКМ или [E]" % chest_title


func _get_or_create_chest_ui() -> void:
	if chest_ui_instance and is_instance_valid(chest_ui_instance):
		return
	var existing := get_tree().root.find_child("ChestUI", true, false) as ChestUI
	if existing:
		chest_ui_instance = existing
	else:
		var scene := load("res://scenes/chest_ui.tscn") as PackedScene
		if scene:
			chest_ui_instance = scene.instantiate() as ChestUI
			var parent_node: Node = player.get_parent() if (player and is_instance_valid(player)) else get_tree().current_scene
			if not parent_node:
				parent_node = get_tree().root
			parent_node.add_child(chest_ui_instance)

	if chest_ui_instance and player:
		chest_ui_instance.player_ref = player
