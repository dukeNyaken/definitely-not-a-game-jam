class_name Vfx
extends RefCounted
## Процедурные эффекты: дуги, кольца, вспышки, всплески. Всё из простых мешей.

static var _mat_cache: Dictionary = {}


static func root_for(node: Node) -> Node:
	if node == null or not node.is_inside_tree():
		return null
	var p := node.get_parent()
	return p if p != null else node.get_tree().current_scene


static func material(color: Color, emissive: float = 1.5, additive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r * emissive, color.g * emissive, color.b * emissive, color.a)
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	return m


## Плоский сектор в плоскости XZ, обращённый к -Z.
static func sector_mesh(radius: float, arc_degrees: float, inner: float = 0.0, segments: int = 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(arc_degrees) * 0.5
	for i in segments:
		var a0 := -half + (2.0 * half) * float(i) / segments
		var a1 := -half + (2.0 * half) * float(i + 1) / segments
		var o0 := Vector3(sin(a0), 0, -cos(a0))
		var o1 := Vector3(sin(a1), 0, -cos(a1))
		if inner <= 0.0:
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(o0 * radius)
			st.add_vertex(o1 * radius)
		else:
			st.add_vertex(o0 * inner)
			st.add_vertex(o0 * radius)
			st.add_vertex(o1 * radius)
			st.add_vertex(o0 * inner)
			st.add_vertex(o1 * radius)
			st.add_vertex(o1 * inner)
	return st.commit()


static func ring_mesh(radius: float, width: float, segments: int = 40) -> ArrayMesh:
	return sector_mesh(radius, 360.0, maxf(radius - width, 0.0), segments)


static func _spawn(parent: Node, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	return mi


static func _fade_free(mi: MeshInstance3D, duration: float, grow: float = 1.0) -> void:
	var mat := mi.material_override as StandardMaterial3D
	var tw := mi.create_tween().set_parallel(true)
	if mat != null:
		var c := mat.albedo_color
		tw.tween_property(mat, "albedo_color", Color(c.r, c.g, c.b, 0.0), duration).set_ease(Tween.EASE_IN)
	if grow != 1.0:
		tw.tween_property(mi, "scale", mi.scale * grow, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)


## Дуга удара (меч, кулак, Лезвие).
static func slash(owner: Node3D, origin: Vector3, dir: Vector3, radius: float, arc_degrees: float, color: Color, duration: float = 0.22) -> void:
	var parent := root_for(owner)
	if parent == null:
		return
	var mi := _spawn(parent, sector_mesh(radius, arc_degrees, radius * 0.45), material(Color(color, 0.85), 1.6, true), origin + Vector3(0, 0.6, 0))
	var d := Combat.flat_dir(dir)
	mi.look_at(mi.global_position + d, Vector3.UP)
	_fade_free(mi, duration, 1.08)


## Кольцо на земле (волна, толчок, Взор).
static func ring(owner: Node3D, center: Vector3, radius: float, color: Color, duration: float = 0.35, width: float = 0.35) -> void:
	var parent := root_for(owner)
	if parent == null:
		return
	var mi := _spawn(parent, ring_mesh(1.0, width / maxf(radius, 0.1)), material(Color(color, 0.9), 1.6, true), center + Vector3(0, 0.08, 0))
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var mat := mi.material_override as StandardMaterial3D
	var c := mat.albedo_color
	tw.tween_property(mat, "albedo_color", Color(c.r, c.g, c.b, 0.0), duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Сфера-купол вокруг персонажа (Оплот).
static func dome(owner: Node3D, color: Color, duration: float, radius: float = 1.1) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = material(Color(color, 0.35), 1.4, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(mi)
	mi.position = Vector3(0, 0.9, 0)
	_fade_free(mi, duration, 1.15)


## Короткая вспышка в точке (попадание, крит).
static func burst(owner: Node, pos: Vector3, color: Color, size: float = 0.5, duration: float = 0.18) -> void:
	var parent := root_for(owner)
	if parent == null:
		return
	var s := SphereMesh.new()
	s.radius = size * 0.5
	s.height = size
	s.radial_segments = 8
	s.rings = 4
	var mi := _spawn(parent, s, material(Color(color, 0.9), 2.0, true), pos)
	_fade_free(mi, duration, 2.2)


## Линия между точками (цепь Хватки, натяжение лука).
static func beam(owner: Node, a: Vector3, b: Vector3, color: Color, width: float = 0.12, duration: float = 0.25) -> void:
	var parent := root_for(owner)
	if parent == null:
		return
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var box := BoxMesh.new()
	box.size = Vector3(width, width, len)
	var mi := _spawn(parent, box, material(Color(color, 0.9), 1.8, true), (a + b) * 0.5)
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	_fade_free(mi, duration, 1.0)


## След рывка.
static func streak(owner: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	beam(owner, from + Vector3(0, 0.5, 0), to + Vector3(0, 0.5, 0), color, 0.5, 0.3)
