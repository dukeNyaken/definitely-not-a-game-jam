class_name LowPoly
extends RefCounted
## Лоу-поли примитивы с плоским затенением и кэшем материалов.

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


## Ретро-материал (см. shaders/retro_*.gdshader). surface — текстура из Surfaces,
## world — проекция текстуры в мировых координатах (для неподвижной геометрии).
static func mat(color: Color, roughness: float = 0.85, metallic: float = 0.0, emission: float = 0.0, surface: StringName = &"", world: bool = false) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f|%.2f|%s|%s" % [color.to_html(), roughness, metallic, emission, surface, world]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	Render.register(m)
	m.set_shader_parameter(&"albedo_color", Color(color.r, color.g, color.b, 1.0))
	if color.a < 1.0:
		m.set_shader_parameter(&"fade", color.a)
	if surface != &"":
		m.set_shader_parameter(&"surface_tex", Surfaces.tex(surface))
		m.set_shader_parameter(&"tex_scale", Surfaces.scale(surface, world))
	m.set_shader_parameter(&"world_space", world)
	m.set_shader_parameter(&"roughness_v", roughness)
	m.set_shader_parameter(&"metallic_v", metallic)
	if emission > 0.0:
		m.set_shader_parameter(&"emission_color", color)
		m.set_shader_parameter(&"emission_energy", emission)
	_materials[key] = m
	return m


## Собственная копия материала (чтобы менять параметры одного объекта, например прозрачность).
static func unique(base: ShaderMaterial) -> ShaderMaterial:
	var m := base.duplicate() as ShaderMaterial
	Render.register(m)
	return m


## Плоские нормали: каждая грань получает свою нормаль — граненый вид.
static func flat(mesh: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() if idx.size() > 0 else verts.size()
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		nv.resize(count)
		nn.resize(count)
		for i in range(0, count - 2, 3):
			var ia := idx[i] if idx.size() > 0 else i
			var ib := idx[i + 1] if idx.size() > 0 else i + 1
			var ic := idx[i + 2] if idx.size() > 0 else i + 2
			var a := verts[ia]
			var b := verts[ib]
			var c := verts[ic]
			var n := (c - a).cross(b - a)
			if n.length_squared() < 1e-12:
				n = normals[ia] if normals.size() > ia else Vector3.UP
			n = n.normalized()
			if normals.size() > ic:
				var ref := normals[ia] + normals[ib] + normals[ic]
				if ref.dot(n) < 0.0:
					n = -n
			nv[i] = a
			nv[i + 1] = b
			nv[i + 2] = c
			nn[i] = n
			nn[i + 1] = n
			nn[i + 2] = n
		var na := []
		na.resize(Mesh.ARRAY_MAX)
		na[Mesh.ARRAY_VERTEX] = nv
		na[Mesh.ARRAY_NORMAL] = nn
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
	return out


static func _cached(key: String, mesh: PrimitiveMesh) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = flat(mesh)
	return _meshes[key]


static func _instance(mesh: Mesh, color: Color, pos: Vector3, roughness: float, metallic: float, emission: float, surface: StringName = &"") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, roughness, metallic, emission, surface)
	mi.position = pos
	return mi


static func box(size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO, roughness: float = 0.85, metallic: float = 0.0, emission: float = 0.0, surface: StringName = &"") -> MeshInstance3D:
	var key := "box%s" % size
	if not _meshes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_cached(key, b)
	return _instance(_meshes[key], color, pos, roughness, metallic, emission, surface)


static func cyl(top_radius: float, bottom_radius: float, height: float, segments: int, color: Color, pos: Vector3 = Vector3.ZERO, roughness: float = 0.85, metallic: float = 0.0, emission: float = 0.0, surface: StringName = &"") -> MeshInstance3D:
	var key := "cyl%.3f|%.3f|%.3f|%d" % [top_radius, bottom_radius, height, segments]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = top_radius
		c.bottom_radius = bottom_radius
		c.height = height
		c.radial_segments = segments
		c.rings = 1
		_cached(key, c)
	return _instance(_meshes[key], color, pos, roughness, metallic, emission, surface)


static func sphere(radius: float, segments: int, rings: int, color: Color, pos: Vector3 = Vector3.ZERO, roughness: float = 0.85, metallic: float = 0.0, emission: float = 0.0, surface: StringName = &"") -> MeshInstance3D:
	var key := "sph%.3f|%d|%d" % [radius, segments, rings]
	if not _meshes.has(key):
		var s := SphereMesh.new()
		s.radius = radius
		s.height = radius * 2.0
		s.radial_segments = segments
		s.rings = rings
		_cached(key, s)
	return _instance(_meshes[key], color, pos, roughness, metallic, emission, surface)


static func prism(size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO, roughness: float = 0.85, metallic: float = 0.0, emission: float = 0.0, surface: StringName = &"") -> MeshInstance3D:
	var key := "pri%s" % size
	if not _meshes.has(key):
		var p := PrismMesh.new()
		p.size = size
		_cached(key, p)
	return _instance(_meshes[key], color, pos, roughness, metallic, emission, surface)


static func torus(inner: float, outer: float, rings: int, ring_segments: int, color: Color, pos: Vector3 = Vector3.ZERO, roughness: float = 0.6, metallic: float = 0.0, emission: float = 0.0, surface: StringName = &"") -> MeshInstance3D:
	var key := "tor%.3f|%.3f|%d|%d" % [inner, outer, rings, ring_segments]
	if not _meshes.has(key):
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = rings
		t.ring_segments = ring_segments
		_cached(key, t)
	return _instance(_meshes[key], color, pos, roughness, metallic, emission, surface)


static func pivot(name: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	return n
