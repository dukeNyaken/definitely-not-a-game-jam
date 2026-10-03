class_name PS1Material
## Подменяет материалы импортированной модели на ps1.gdshader, забирая из них
## текстуру. Возвращает сводку для проверки: треугольники и размеры текстур.

const SHADER := preload("res://ps1.gdshader")


static func apply(root: Node) -> Dictionary:
	var stats := {"meshes": 0, "tris": 0, "textures": []}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		stats.meshes += 1
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			stats.tris += idx.size() / 3 if idx.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size() / 3
			var src: Material = mi.get_active_material(s)
			var tex: Texture2D = src.albedo_texture if src is BaseMaterial3D else null
			var mat := ShaderMaterial.new()
			mat.shader = SHADER
			mat.set_shader_parameter("albedo_tex", tex)
			mi.set_surface_override_material(s, mat)
			if tex:
				stats.textures.append("%s %dx%d" % [mi.name, tex.get_width(), tex.get_height()])
	return stats
