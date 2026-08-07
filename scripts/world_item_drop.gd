extends Area3D
class_name WorldItemDrop

const ItemDataType = preload("res://scripts/data/item_data.gd")

@export var item_data: ItemDataType
@export var pickup_range: float = 3.0
@export var launch_duration: float = 0.55

@onready var cube: MeshInstance3D = $Cube
@onready var beam: MeshInstance3D = $Beam
@onready var glow: MeshInstance3D = $Glow
@onready var item_label: Label3D = $ItemLabel

var player: Node3D = null
var hovered := false
var launch_elapsed := 0.0
var launch_origin := Vector3.ZERO
var launch_target := Vector3.ZERO
var is_launching := false
var label_message_until := 0
var item_instance: Dictionary = {}
var pickup_in_progress := false


func _ready() -> void:
	add_to_group("WorldLoot")
	input_ray_pickable = true
	player = get_tree().get_first_node_in_group("Player") as Node3D
	mouse_entered.connect(func(): hovered = true)
	mouse_exited.connect(func(): hovered = false)
	if item_instance.is_empty() and item_data:
		item_instance = item_data.to_inventory_item()
	_configure_item_label()


func configure_item(value: Dictionary) -> void:
	item_instance = value.duplicate(true)
	if is_node_ready():
		_configure_item_label()


func launch_from(origin: Vector3, target: Vector3) -> void:
	launch_origin = origin
	launch_target = target
	launch_elapsed = 0.0
	is_launching = true
	global_position = origin
	beam.visible = false


func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as Node3D

	if is_launching:
		launch_elapsed += delta
		var t := clampf(launch_elapsed / maxf(launch_duration, 0.01), 0.0, 1.0)
		global_position = launch_origin.lerp(launch_target, t)
		global_position.y += sin(t * PI) * 0.75
		cube.rotation = Vector3(t * PI * 1.4, t * TAU, t * PI * 0.6)
		if t >= 1.0:
			is_launching = false
			global_position = launch_target
			cube.rotation = Vector3.ZERO
			beam.visible = true
	else:
		cube.rotation.y += delta * 0.65
		cube.position.y = 0.16 + sin(Time.get_ticks_msec() * 0.003) * 0.018

	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.06
	glow.scale = Vector3(pulse, 1.0, pulse)
	beam.scale.y = 0.96 + sin(Time.get_ticks_msec() * 0.0035) * 0.04

	var show_all := Input.is_physical_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_ALT)
	var nearby := _is_player_near()
	item_label.visible = show_all or (hovered and nearby) or Time.get_ticks_msec() < label_message_until


func _input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		try_pickup()


func try_pickup() -> bool:
	if pickup_in_progress:
		return true
	if not _is_player_near():
		_show_temporary_message("ПОДОЙДИТЕ БЛИЖЕ", Color(0.82, 0.82, 0.84))
		return true
	if not player or not player.has_method("add_inventory_item") or item_instance.is_empty():
		return true
	if player.add_inventory_item(item_instance):
		pickup_in_progress = true
		input_ray_pickable = false
		monitorable = false
		queue_free()
	else:
		_show_temporary_message("ИНВЕНТАРЬ ЗАПОЛНЕН", Color(1.0, 0.28, 0.18))
	return true


func _is_player_near() -> bool:
	return player and is_instance_valid(player) and global_position.distance_to(player.global_position) <= pickup_range


func _configure_item_label() -> void:
	if item_instance.is_empty():
		item_label.text = "Неизвестный предмет"
		return
	var size: Vector2i = item_instance.get("grid_size", Vector2i.ONE)
	var rarity: String = {
		"common": "Обычный",
		"magic": "Магический",
		"rare": "Редкий",
		"unique": "Уникальный",
	}.get(str(item_instance.get("rarity", "common")), "Обычный")
	item_label.text = "%s\n%s · %d×%d · ЛКМ" % [
		str(item_instance.get("name", "Предмет")), rarity, size.x, size.y
	]
	item_label.modulate = Color(0.78, 0.78, 0.80, 1.0)


func _show_temporary_message(message: String, color: Color) -> void:
	item_label.text = message
	item_label.modulate = color
	item_label.visible = true
	label_message_until = Time.get_ticks_msec() + 1000
	get_tree().create_timer(1.0).timeout.connect(_restore_label)


func _restore_label() -> void:
	if is_instance_valid(self):
		_configure_item_label()
