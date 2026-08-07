class_name RetroMaterialStyler
extends RefCounted


static func apply_to_model(root: Node, tint: Color, minimum_roughness: float = 0.82) -> void:
	if not root:
		return
	_style_recursive(root, tint, minimum_roughness)


static func _style_recursive(node: Node, tint: Color, minimum_roughness: float) -> void:
	if node is MeshInstance3D:
		_style_mesh(node as MeshInstance3D, tint, minimum_roughness)
	for child in node.get_children():
		_style_recursive(child, tint, minimum_roughness)


static func _style_mesh(mesh_instance: MeshInstance3D, tint: Color, minimum_roughness: float) -> void:
	if not mesh_instance.mesh:
		return
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source: Material = mesh_instance.get_active_material(surface_index)
		var styled: StandardMaterial3D
		if source is StandardMaterial3D:
			styled = source.duplicate(true) as StandardMaterial3D
		else:
			styled = StandardMaterial3D.new()
		var source_color := styled.albedo_color
		styled.albedo_color = Color(
			tint.r * source_color.r,
			tint.g * source_color.g,
			tint.b * source_color.b,
			source_color.a
		)
		styled.roughness = maxf(styled.roughness, minimum_roughness)
		styled.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mesh_instance.set_surface_override_material(surface_index, styled)
