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


## Дуга удара (меч, кулак, Лезвие): пиксельный взмах, натянутый на сектор. mirror — взмах справа налево;
## sheet — развёртка взмаха (мотив сущности, например &"blade_arc").
static func slash(owner: Node3D, origin: Vector3, dir: Vector3, radius: float, arc_degrees: float, color: Color, duration: float = 0.22, mirror: bool = false, sheet: StringName = &"slash_arc") -> void:
	var fx := FlipbookFx.spawn(owner, sheet, origin + Vector3(0, 0.6, 0), color, 1.0,
		{"mesh": arc_mesh(arc_degrees), "duration": maxf(duration * 1.25, 0.26), "energy": 1.9, "pull": 0.2})
	if fx == null:
		return
	var d := Combat.flat_dir(dir)
	fx.rotation.y = atan2(-d.x, -d.z)
	fx.scale = Vector3(-radius if mirror else radius, 1.0, radius)


## Кольцо на земле (волна, толчок, Взор): пиксельный фронт расходится до radius и рвётся на штрихи.
## sheet — лист с radius_px (мотив сущности, например &"mass_wave"); каждый раз под случайным углом;
## delay_s — задержка появления (несколько волн подряд).
static func ring(owner: Node3D, center: Vector3, radius: float, color: Color, duration: float = 0.35, _width: float = 0.35, sheet: StringName = &"shock_ring", delay_s: float = 0.0) -> void:
	var spec: Dictionary = FlipbookFx.SHEETS[sheet]
	var size := radius * float(spec["size_px"]) / float(spec["radius_px"][-1])
	var fx := FlipbookFx.spawn(owner, sheet, center + Vector3(0, 0.08, 0), color, size,
		{"billboard": false, "duration": duration * 1.3, "energy": spec.get("energy", 1.8), "pull": 0.05})
	if fx != null:
		fx.rotation.y = randf() * TAU
		if delay_s > 0.0:
			fx.delay = delay_s
			fx.visible = false


## Сфера Оплота вокруг персонажа: пиксельный пузырь с рунами, держится duration и гаснет.
static func dome(owner: Node3D, color: Color, duration: float, radius: float = 1.1) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	# Контур сферы — 21 px из 24 половины листа.
	var fx := FlipbookFx.attach(owner, &"ward_bubble", Vector3(0, 0.95, 0), color, radius * 2.0 * 24.0 / 21.0,
		{"loop": true, "energy": 1.7, "pull": radius * 0.7})
	var full := fx.scale
	fx.scale = full * 0.4
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", full, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(duration - 0.27, 0.0))
	tw.tween_callback(fx.fade_out.bind(0.15))


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


## Лента плашмя от a к b (u вдоль ленты: 0 у a, 1 у b) — для цепи и следа рывка.
static func _ribbon(owner: Node, id: StringName, a: Vector3, b: Vector3, width: float, color: Color, opts: Dictionary) -> FlipbookFx:
	var d := Combat.flat(b - a)
	var len := d.length()
	if len < 0.05:
		return null
	opts["billboard"] = false
	var fx := FlipbookFx.spawn(owner, id, (a + b) * 0.5, color, 1.0, opts)
	if fx == null:
		return null
	span(fx, a, b, width)
	return fx


## Перекладывает ленту между a и b (u = 0 у a, u = 1 у b).
static func span(fx: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	var d := Combat.flat(b - a)
	fx.global_position = (a + b) * 0.5
	fx.rotation.y = atan2(-d.z, d.x)
	fx.scale = Vector3(maxf(d.length(), 0.01), 1.0, width)


## Цепь от a (кто тянет) к b (кого тянут): звенья ползут к a, через duration цепь гаснет.
static func beam(owner: Node, a: Vector3, b: Vector3, color: Color, width: float = 0.12, duration: float = 0.25) -> void:
	# Период звеньев — 16 px из 32 на ширину 8 px: звено вдвое длиннее ширины ленты.
	var link := maxf(width, 0.08) * 4.5
	var fx := _ribbon(owner, &"grip_chain", a, b, link / 2.0, color, {"loop": true, "energy": 1.9, "pull": 0.3, "tile": a.distance_to(b) / (link * 2.0)})
	if fx != null:
		fx.create_tween().tween_callback(fx.fade_out.bind(0.12)).set_delay(maxf(duration - 0.12, 0.0))


## След рывка: линии скорости тянутся за персонажем от точки старта, после рывка хвосты втягиваются к нему.
## Если owner не в рывке (сцена, тест) — след сразу на весь путь from → to.
## sheet — лист следа (мотив сущности, например &"gust_lines"), width — ширина ленты, м.
static func streak(owner: Node3D, from: Vector3, to: Vector3, color: Color, sheet: StringName = &"speed_lines", width: float = 1.0) -> void:
	var lift := Vector3(0, 0.45, 0)
	if owner is Actor and (owner as Actor).is_dashing():
		DashTrail.follow(owner as Actor, from + lift, color, sheet, width)
		return
	_ribbon(owner, sheet, from + lift, to + lift, width, color, {"energy": 1.6, "pull": 0.2})
