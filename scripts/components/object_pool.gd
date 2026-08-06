class_name ObjectPool
extends Node

@export var scene_to_pool: PackedScene
@export var initial_pool_size: int = 16

var _available_objects: Array[Node] = []

func _ready() -> void:
	if scene_to_pool:
		for i in range(initial_pool_size):
			var obj := _create_new_object()
			_available_objects.append(obj)

func get_object() -> Node:
	var obj: Node = null
	if _available_objects.size() > 0:
		obj = _available_objects.pop_back()
	else:
		obj = _create_new_object()

	if obj.has_method("on_pool_spawn"):
		obj.on_pool_spawn()
	return obj

func return_object(obj: Node) -> void:
	if not is_instance_valid(obj): return
	if obj.has_method("on_pool_despawn"):
		obj.on_pool_despawn()
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	_available_objects.append(obj)

func _create_new_object() -> Node:
	var obj := scene_to_pool.instantiate()
	if obj.has_signal("request_despawn"):
		obj.request_despawn.connect(func(): return_object(obj))
	return obj
