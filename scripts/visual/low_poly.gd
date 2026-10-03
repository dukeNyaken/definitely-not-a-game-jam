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


## Ретро-материал с готовой текстурой по UV — для запечённых моделей (assets/characters/).
static func mat_textured(tex: Texture2D, roughness: float = 0.9) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	Render.register(m)
	m.set_shader_parameter(&"surface_tex", tex)
	m.set_shader_parameter(&"use_uv", true)
	m.set_shader_parameter(&"roughness_v", roughness)
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


## Выпуклый многогранник из граней (петли вершин). Нормали плоские и смотрят наружу:
## порядок вершин каждого треугольника выправляется относительно центра фигуры.
static func convex(faces: Array) -> ArrayMesh:
	var centroid := Vector3.ZERO
	var count := 0
	for f in faces:
		for v in f:
			centroid += v
			count += 1
	centroid /= maxf(count, 1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for f in faces:
		for i in range(1, f.size() - 1):
			var a: Vector3 = f[0]
			var b: Vector3 = f[i]
			var c: Vector3 = f[i + 1]
			var n := (c - a).cross(b - a)
			if n.length_squared() < 1e-10:
				continue
			if n.dot((a + b + c) / 3.0 - centroid) < 0.0:
				var t := b
				b = c
				c = t
				n = -n
			n = n.normalized()
			verts.append(a)
			verts.append(b)
			verts.append(c)
			norms.append(n)
			norms.append(n)
			norms.append(n)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Усечённая пирамида (центр — в середине высоты): нижний и верхний прямоугольники X×Z,
## верх можно сдвинуть. Верх 0×0 — пирамида, верх X×0 — клин.
static func frustum_mesh(bottom: Vector2, top: Vector2, height: float, top_offset: Vector2 = Vector2.ZERO) -> Mesh:
	var key := "fru%s|%s|%.3f|%s" % [bottom, top, height, top_offset]
	if _meshes.has(key):
		return _meshes[key]
	var h := height * 0.5
	var bx := bottom.x * 0.5
	var bz := bottom.y * 0.5
	var tx := top.x * 0.5
	var tz := top.y * 0.5
	var ox := top_offset.x
	var oz := top_offset.y
	var b := [Vector3(-bx, -h, -bz), Vector3(bx, -h, -bz), Vector3(bx, -h, bz), Vector3(-bx, -h, bz)]
	var t := [Vector3(-tx + ox, h, -tz + oz), Vector3(tx + ox, h, -tz + oz), Vector3(tx + ox, h, tz + oz), Vector3(-tx + ox, h, tz + oz)]
	var faces := [b, t]
	for i in 4:
		var j := (i + 1) % 4
		faces.append([b[i], b[j], t[j], t[i]])
	var m := convex(faces)
	_meshes[key] = m
	return m


## Двойная пирамида (кристалл, осколок): кольцо из sides точек и две вершины.
static func gem_mesh(radius: float, up: float, down: float, sides: int) -> Mesh:
	var key := "gem%.3f|%.3f|%.3f|%d" % [radius, up, down, sides]
	if _meshes.has(key):
		return _meshes[key]
	var ring := []
	for i in sides:
		var a := TAU * i / sides
		ring.append(Vector3(cos(a) * radius, 0, sin(a) * radius))
	var faces := []
	for i in sides:
		var j := (i + 1) % sides
		faces.append([ring[i], ring[j], Vector3(0, up, 0)])
		faces.append([ring[j], ring[i], Vector3(0, -down, 0)])
	var m := convex(faces)
	_meshes[key] = m
	return m


static func _shape(mesh: Mesh, color: Color, pos: Vector3, surface: StringName, metallic: float, emission: float) -> MeshInstance3D:
	return _instance(mesh, color, pos, 0.6 if metallic > 0.0 else 0.9, metallic, emission, surface)


static func frustum(bottom: Vector2, top: Vector2, height: float, color: Color, pos: Vector3 = Vector3.ZERO, surface: StringName = &"", top_offset: Vector2 = Vector2.ZERO, metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	return _shape(frustum_mesh(bottom, top, height, top_offset), color, pos, surface, metallic, emission)


static func pyramid(base: Vector2, height: float, color: Color, pos: Vector3 = Vector3.ZERO, surface: StringName = &"", metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	return _shape(frustum_mesh(base, Vector2.ZERO, height), color, pos, surface, metallic, emission)


static func wedge(size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO, surface: StringName = &"", metallic: float = 0.0) -> MeshInstance3D:
	return _shape(frustum_mesh(Vector2(size.x, size.z), Vector2(size.x, 0.0), size.y), color, pos, surface, metallic, 0.0)


static func gem(radius: float, up: float, down: float, sides: int, color: Color, pos: Vector3 = Vector3.ZERO, surface: StringName = &"", metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	return _shape(gem_mesh(radius, up, down, sides), color, pos, surface, metallic, emission)


## Вариант материала для персонажа: контурный свет по силуэту (у героя тёплый, у врагов холодный).
static var _variants: Dictionary = {}


static func rim_variant(base: ShaderMaterial, rim: Color, strength: float) -> ShaderMaterial:
	if base.has_meta(&"rim_variant"):
		return base
	var key := "%d|%s|%.2f" % [base.get_instance_id(), rim.to_html(), strength]
	if _variants.has(key):
		return _variants[key]
	var m := unique(base)
	m.set_shader_parameter(&"rim_color", rim)
	m.set_shader_parameter(&"rim_strength", strength)
	m.set_meta(&"rim_variant", true)
	_variants[key] = m
	return m


static func pivot(name: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	return n
