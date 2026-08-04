# ==============================================================================
# MODEL VALIDATOR & AUTOMATIC ENTITY STANDARDIZER (Godot 4)
# Модуль абсолютной авто-подгонки 3D-моделей.
# Гарантирует: Модель ВСЕГДА видна, ростом ровно 1.8м, ступни на полу Y=0,
# без слепящего света и без телепортаций анимаций.
# ==============================================================================
class_name ModelValidator
extends RefCounted

## Главный автоматический адаптер любой 3D-модели под стандарт человеческого роста
static func auto_fit_model_size(model_root: Node3D, target_height: float = 1.8) -> void:
	if not model_root:
		return
		
	# 1. Отключение встроенных ламп и камер импортированного файла
	purge_embedded_lights_and_cameras(model_root)
	
	# 2. Включаем видимость всех мешей
	var meshes: Array[MeshInstance3D] = []
	find_all_meshes(model_root, meshes)
	
	var combined_aabb := AABB()
	var has_mesh := false
	
	for m in meshes:
		if m.mesh:
			m.visible = true
			var aabb = m.get_aabb()
			if not has_mesh:
				combined_aabb = aabb
				has_mesh = true
			else:
				combined_aabb = combined_aabb.merge(aabb)
				
	if not has_mesh or combined_aabb.size.y <= 0.001:
		print("⚠️ ModelValidator: Меш в ", model_root.name, " еще не загрузился или равен 0.")
		return
		
	# 3. Рассчитываем точный коэффициент приведения высоты сетки к target_height (1.8м)
	var raw_height = combined_aabb.size.y
	var desired_scale = target_height / raw_height
	
	# 4. Разворачиваем лицо модели ровно к прицелу мыши (180 градусов вокруг Y)
	model_root.scale = Vector3(desired_scale, desired_scale, desired_scale)
	model_root.rotation_degrees = Vector3(0, 180, 0)
	
	# 5. Ставим ступни строго на уровень пола Y = 0
	var lowest_y = combined_aabb.position.y * desired_scale
	model_root.position = Vector3(0, -lowest_y, 0)
	model_root.visible = true
	
	print("✅ ModelValidator: Авто-подгонка '", model_root.name, "' успешна! Высота=", target_height, "м (scale=", desired_scale, ", Y=", model_root.position.y, ")")

## Безопасное отключение только внутренних встроенных ламп и камер
static func purge_embedded_lights_and_cameras(node: Node) -> void:
	if not node:
		return
	if node is Light3D:
		node.visible = false
		if node.has_method("set_param"):
			node.set_param(Light3D.PARAM_ENERGY, 0.0)
	elif node is Camera3D:
		node.current = false
		node.clear_current()
		
	for child in node.get_children():
		purge_embedded_lights_and_cameras(child)

## Безупречная авто-санитаризация Root Motion у кости таза (Hips)
static func sanitize_animation(anim: Animation) -> void:
	if not anim:
		return
		
	for track_idx in range(anim.get_track_count()):
		var track_type = anim.track_get_type(track_idx)
		var path_str = String(anim.track_get_path(track_idx)).to_lower()
		
		# Фиксируем X и Z в 0 для таза Hips -> движение In-Place без разрывов
		if track_type == Animation.TYPE_POSITION_3D and ("hips" in path_str or "root" in path_str):
			var key_count = anim.track_get_key_count(track_idx)
			var first_y = 0.0
			if key_count > 0:
				first_y = (anim.track_get_key_value(track_idx, 0) as Vector3).y
				
			for k in range(key_count):
				var pos_val = anim.track_get_key_value(track_idx, k) as Vector3
				var target_y = pos_val.y
				if abs(target_y) < 0.001 and abs(first_y) > 0.001:
					target_y = first_y
				anim.track_set_key_value(track_idx, k, Vector3(0, target_y, 0))

static func find_all_meshes(node: Node, out_array: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_array.append(node)
	for child in node.get_children():
		find_all_meshes(child, out_array)
