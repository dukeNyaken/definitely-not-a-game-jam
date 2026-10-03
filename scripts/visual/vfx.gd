class_name Vfx
extends RefCounted
## Эффекты: дуги и кольца — пиксельные листы (FlipbookFx), вспышки, лучи, купола — простые меши.

static var _mat_cache: Dictionary = {}
static var _arc_cache: Dictionary = {}


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


## Сектор единичного радиуса с развёрткой UV: u — вдоль дуги слева направо, v — от внешнего края (0) внутрь (1).
static func arc_mesh(arc_degrees: float, inner: float = 0.45) -> ArrayMesh:
	var key := "%d|%.2f" % [int(round(arc_degrees)), inner]
	if _arc_cache.has(key):
		return _arc_cache[key]
	var segments := maxi(6, int(arc_degrees / 8.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(arc_degrees) * 0.5
	for i in segments:
		var u0 := float(i) / segments
		var u1 := float(i + 1) / segments
		var a0 := -half + 2.0 * half * u0
		var a1 := -half + 2.0 * half * u1
		var o0 := Vector3(sin(a0), 0, -cos(a0))
		var o1 := Vector3(sin(a1), 0, -cos(a1))
		for v in [[o0 * inner, Vector2(u0, 1)], [o0, Vector2(u0, 0)], [o1, Vector2(u1, 0)],
				[o0 * inner, Vector2(u0, 1)], [o1, Vector2(u1, 0)], [o1 * inner, Vector2(u1, 1)]]:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var mesh := st.commit()
	_arc_cache[key] = mesh
	return mesh


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


## Дуга удара (меч, кулак, Лезвие): пиксельный взмах, натянутый на сектор. mirror — взмах справа налево.
static func slash(owner: Node3D, origin: Vector3, dir: Vector3, radius: float, arc_degrees: float, color: Color, duration: float = 0.22, mirror: bool = false) -> void:
	var fx := FlipbookFx.spawn(owner, &"slash_arc", origin + Vector3(0, 0.6, 0), color, 1.0,
		{"mesh": arc_mesh(arc_degrees), "duration": maxf(duration * 1.25, 0.26), "energy": 1.9, "pull": 0.2})
	if fx == null:
		return
	var d := Combat.flat_dir(dir)
	fx.rotation.y = atan2(-d.x, -d.z)
	fx.scale = Vector3(-radius if mirror else radius, 1.0, radius)


## Кольцо на земле (волна, толчок, Взор): пиксельный фронт расходится до radius и рвётся на штрихи.
static func ring(owner: Node3D, center: Vector3, radius: float, color: Color, duration: float = 0.35, _width: float = 0.35) -> void:
	var spec: Dictionary = FlipbookFx.SHEETS[&"shock_ring"]
	var size := radius * float(spec["size_px"]) / float(spec["radius_px"][-1])
	FlipbookFx.spawn(owner, &"shock_ring", center + Vector3(0, 0.08, 0), color, size,
		{"billboard": false, "duration": duration * 1.3, "energy": 1.8, "pull": 0.05})


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
