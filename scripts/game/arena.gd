class_name Arena
extends Node3D
## Арена-лобное место: брусчатка в крови, кровавый круг-клеймо в центре, по краю — руины,
## колья с черепами, колёса на столбах, клетки, мёртвые деревья и жаровни. В небе — луна в кольце осколков.

const EDGE_PROPS := [&"wall", &"brazier", &"stakes", &"wheel", &"wall", &"tree", &"brazier", &"gibbet", &"wall", &"stakes", &"brazier", &"wheel", &"tree", &"wall"]

var radius: float = 15.0
var floor_tint: Color = Color(0.32, 0.3, 0.28)
var _floor_mats: Array[ShaderMaterial] = []
var _env: WorldEnvironment
var _moon: DirectionalLight3D
var _rim: DirectionalLight3D
## Высокие предметы по краю: { "mats": [ShaderMaterial], "base": Vector3, "top": Vector3, "alpha": float }
var _occluders: Array[Dictionary] = []
var _lights: Array[OmniLight3D] = []
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()


func build(p_radius: float) -> void:
	radius = p_radius
	_rng.seed = 1666
	_build_environment()
	_build_floor()
	_build_center_brand()
	_build_edge()
	_build_particles()
	Render.mode_changed.connect(_apply_render_mode)
	_apply_render_mode(Render.mode)


## Этап босса: на полу — разбитое кольцо из семи сегментов. Сегменты пожертвованных вещей
## светятся цветом их сущностей; кольцо треснуло — сегменты сдвинуты.
func show_boss_sigil(colors: Array) -> void:
	var existing := get_node_or_null("BossSigil")
	if existing != null:
		existing.queue_free()
	if colors.is_empty():
		return
	var root := Node3D.new()
	root.name = "BossSigil"
	add_child(root)
	var dark := MeshInstance3D.new()
	dark.mesh = Vfx.sector_mesh(4.4, 360.0, 0.0, 40)
	dark.material_override = Vfx.material(Color(0.0, 0.0, 0.0, 0.5), 1.0, false)
	dark.position.y = 0.02
	root.add_child(dark)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 7:
		var seg := MeshInstance3D.new()
		seg.mesh = Vfx.sector_mesh(5.4, 360.0 / 7.0 - 7.0, 4.5, 8)
		var c: Color = colors[k] if k < colors.size() else Color(0.35, 0.3, 0.3)
		seg.material_override = Vfx.material(Color(c, 0.75 if k < colors.size() else 0.35), 1.5, k < colors.size())
		var a := TAU * (k + 0.5) / 7.0
		seg.rotation.y = -a + PI / 2
		seg.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(-0.25, 0.35) + Vector3(0, 0.022 + k * 0.001, 0)
		root.add_child(seg)
	for n in root.get_children():
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_tint(c: Color) -> void:
	floor_tint = c
	for i in _floor_mats.size():
		var k := 1.4 * (1.0 - 0.06 * (i % 2))
		var l := (c.r + c.g + c.b) / 3.0
		var d := Color(lerpf(l, c.r, 0.35), lerpf(l, c.g, 0.35), lerpf(l, c.b, 0.35))
		_floor_mats[i].set_shader_parameter(&"albedo_color", Color(d.r * k, d.g * k, d.b * k))


# --- Свет и туман -----------------------------------------------------------

func _build_environment() -> void:
	_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.012, 0.016)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.34, 0.33, 0.4)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color(0.1, 0.035, 0.04)
	e.fog_depth_begin = 34.0
	e.fog_depth_end = 64.0
	e.fog_depth_curve = 1.2
	_env.environment = e
	add_child(_env)
	_moon = DirectionalLight3D.new()
	_moon.rotation_degrees = Vector3(-55, 35, 0)
	_moon.light_energy = 0.85
	_moon.light_color = Color(0.72, 0.76, 0.95)
	_moon.directional_shadow_max_distance = 60.0
	add_child(_moon)
	_rim = DirectionalLight3D.new()
	_rim.rotation_degrees = Vector3(-20, 215, 0)
	_rim.light_energy = 0.4
	_rim.light_color = Color(1.0, 0.28, 0.16)
	add_child(_rim)


func _apply_render_mode(mode: int) -> void:
	var e := _env.environment
	var ps1 := mode == Render.Mode.PS1
	_moon.shadow_enabled = not ps1
	e.glow_enabled = not ps1
	e.glow_intensity = 0.9
	e.glow_bloom = 0.12
	e.glow_hdr_threshold = 0.9
	e.ambient_light_energy = 1.5 if ps1 else 0.8
	_moon.light_energy = 1.35 if ps1 else 1.05


# --- Пол --------------------------------------------------------------------

func _build_floor() -> void:
	# Брусчатка кольцами (оттенок по угрозе этапа), грязь по краю, толща плиты, бездна.
	var rings := 4
	var stone_r := radius - 1.5
	for i in rings:
		var outer := stone_r - i * stone_r / rings
		var inner := maxf(outer - stone_r / rings, 0.0)
		var mi := MeshInstance3D.new()
		mi.mesh = LowPoly.flat(_disc(outer, inner, 40 - i * 6))
		var m := LowPoly.unique(LowPoly.mat(Color(0.6, 0.56, 0.52), 0.95, 0.0, 0.0, &"stone", true))
		m.set_shader_parameter(&"snap_vertices", false)
		mi.material_override = m
		_floor_mats.append(m)
		add_child(mi)
	set_tint(floor_tint)
	var mud := MeshInstance3D.new()
	mud.mesh = LowPoly.flat(_disc(radius + 1.4, stone_r, 40))
	var mud_mat := LowPoly.unique(LowPoly.mat(Color(0.95, 0.85, 0.8), 1.0, 0.0, 0.0, &"dirt", true))
	mud_mat.set_shader_parameter(&"snap_vertices", false)
	mud.material_override = mud_mat
	mud.position.y = -0.01
	add_child(mud)
	add_child(LowPoly.cyl(radius + 1.4, radius + 0.8, 2.0, 40, Color(0.7, 0.62, 0.58), Vector3(0, -1.3, 0), 0.95, 0.0, 0.0, &"brick"))
	# Пятна крови.
	for k in 9:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(2.5, radius - 0.5)
		_blood_decal(Vector3(cos(a) * r, 0.012, sin(a) * r), _rng.randf_range(0.9, 2.2))


func _blood_decal(pos: Vector3, size: float) -> void:
	var quad := BoxMesh.new()
	quad.size = Vector3(size, 0.004, size)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var m := LowPoly.unique(LowPoly.mat(Color(0.55, 0.5, 0.5), 0.95, 0.0, 0.0, &"blood"))
	m.set_shader_parameter(&"tex_scale", 1.0 / size)
	m.set_shader_parameter(&"tex_offset", Vector2(0.5, 0.5))
	m.set_shader_parameter(&"snap_vertices", false)
	mi.material_override = m
	mi.rotation.y = _rng.randf() * TAU
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = pos


## Плоское кольцо, мелко разбитое по радиусу: вершинный свет PS1 ложится ровно.
func _disc(outer: float, inner: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(1, ceili((outer - inner) / 0.9))
	var segs := maxi(segments, 56)
	for r in steps:
		var r0 := lerpf(inner, outer, float(r) / steps)
		var r1 := lerpf(inner, outer, float(r + 1) / steps)
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var o0 := Vector3(cos(a0), 0, sin(a0))
			var o1 := Vector3(cos(a1), 0, sin(a1))
			# Обход по часовой, если смотреть сверху: лицевая сторона вверх.
			if r0 <= 0.01:
				st.add_vertex(Vector3.ZERO)
				st.add_vertex(o0 * r1)
				st.add_vertex(o1 * r1)
			else:
				st.add_vertex(o0 * r0)
				st.add_vertex(o0 * r1)
				st.add_vertex(o1 * r1)
				st.add_vertex(o0 * r0)
				st.add_vertex(o1 * r1)
				st.add_vertex(o1 * r0)
	st.generate_normals()
	return st.commit()


## Кровавый круг в центре: двойное кольцо, семь отметок по числу вещей, капли к центру.
func _build_center_brand() -> void:
	var col := Color(0.32, 0.03, 0.03, 0.85)
	var mat := Vfx.material(col, 1.2, false)
	for r in [4.3, 3.5]:
		var ring := MeshInstance3D.new()
		ring.mesh = Vfx.ring_mesh(r, 0.14 if r > 4 else 0.08, 56)
		ring.material_override = mat
		ring.position.y = 0.016
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	for k in 7:
		var a := TAU * k / 7.0 - PI / 2
		var mark := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.16, 0.01, 0.75)
		mark.mesh = b
		mark.material_override = mat
		mark.rotation.y = -a + PI / 2
		mark.position = Vector3(cos(a), 0, sin(a)) * 3.9 + Vector3(0, 0.017, 0)
		add_child(mark)
		var spoke := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.05, 0.01, 2.2)
		spoke.mesh = sb
		spoke.material_override = mat
		spoke.rotation.y = -a + PI / 2
		spoke.position = Vector3(cos(a), 0, sin(a)) * 2.0 + Vector3(0, 0.016, 0)
		add_child(spoke)


# --- Край арены -------------------------------------------------------------

func _build_edge() -> void:
	var count := EDGE_PROPS.size()
	for k in count:
		var a := TAU * (k + 0.5) / count + _rng.randf_range(-0.08, 0.08)
		var pos := Vector3(cos(a), 0, sin(a)) * (radius + 0.9)
		var holder := Node3D.new()
		add_child(holder)
		holder.position = pos
		holder.rotation.y = -a + PI / 2
		match EDGE_PROPS[k]:
			&"wall": _wall(holder)
			&"brazier": _brazier(holder)
			&"stakes": _stakes(holder)
			&"wheel": _wheel(holder)
			&"tree": _tree(holder)
			&"gibbet": _gibbet(holder)
	# Груды костей и черепов вдоль края.
	for k in 22:
		var a := _rng.randf() * TAU
		var r := radius + _rng.randf_range(-0.6, 1.0)
		var pos := Vector3(cos(a) * r, 0, sin(a) * r)
		if _rng.randf() < 0.45:
			_skull(self, pos + Vector3(0, 0.12, 0), _rng.randf() * TAU)
		else:
			var b := LowPoly.box(Vector3(0.07, 0.07, _rng.randf_range(0.35, 0.6)), Color(0.9, 0.86, 0.78), pos + Vector3(0, 0.04, 0), 0.9, 0.0, 0.0, &"bone")
			b.rotation.y = _rng.randf() * TAU
			add_child(b)
	for k in 18:
		var a := _rng.randf() * TAU
		var r := radius + _rng.randf_range(-0.3, 1.2)
		var s := _rng.randf_range(0.2, 0.5)
		var rock := LowPoly.sphere(s, 5, 3, Color(0.75, 0.7, 0.68), Vector3(cos(a) * r, s * 0.3, sin(a) * r), 0.95, 0.0, 0.0, &"stone")
		rock.rotation = Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf())
		add_child(rock)


## Высокий предмет: его материалы затухают, когда он заслоняет героя.
func _occluder(holder: Node3D, height: float) -> void:
	var mats: Array[ShaderMaterial] = []
	_unique_materials(holder, mats)
	_occluders.append({"mats": mats, "base": holder.position, "top": holder.position + Vector3(0, height, 0), "alpha": 1.0})


func _unique_materials(n: Node, mats: Array[ShaderMaterial]) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).material_override is ShaderMaterial:
			var m := LowPoly.unique((ch as MeshInstance3D).material_override as ShaderMaterial)
			(ch as MeshInstance3D).material_override = m
			mats.append(m)
		_unique_materials(ch, mats)


func _wall(h: Node3D) -> void:
	var height := _rng.randf_range(1.6, 3.6)
	var width := _rng.randf_range(2.2, 3.4)
	var c := Color(0.75, 0.7, 0.68)
	h.add_child(LowPoly.box(Vector3(width, height, 0.8), c, Vector3(0, height * 0.5, 0), 0.95, 0.0, 0.0, &"brick"))
	# Обломанный верх.
	for k in 3:
		var x := -width * 0.35 + k * width * 0.35
		var top := LowPoly.prism(Vector3(width * 0.3, _rng.randf_range(0.3, 0.8), 0.8), c, Vector3(x, height + 0.2, 0), 0.95, 0.0, 0.0, &"brick")
		h.add_child(top)
	h.add_child(LowPoly.box(Vector3(width * 0.5, 0.4, 0.9), c.darkened(0.2), Vector3(width * 0.4, 0.2, 0.5), 0.95, 0.0, 0.0, &"brick"))
	_occluder(h, height + 0.8)


func _brazier(h: Node3D) -> void:
	var iron := Color(0.6, 0.58, 0.62)
	for k in 3:
		var a := TAU * k / 3.0
		var leg := LowPoly.box(Vector3(0.08, 1.4, 0.08), iron, Vector3(cos(a) * 0.3, 0.65, sin(a) * 0.3), 0.6, 0.5, 0.0, &"iron")
		leg.rotation = Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)
		h.add_child(leg)
	h.add_child(LowPoly.cyl(0.55, 0.35, 0.35, 7, iron, Vector3(0, 1.45, 0), 0.6, 0.5, 0.0, &"rust"))
	h.add_child(LowPoly.cyl(0.0, 0.42, 0.85, 5, Color(1.0, 0.5, 0.15), Vector3(0, 1.95, 0), 0.5, 0.0, 3.0))
	var fire := CPUParticles3D.new()
	fire.amount = 14
	fire.lifetime = 0.8
	fire.position = Vector3(0, 1.9, 0)
	fire.direction = Vector3.UP
	fire.spread = 18.0
	fire.initial_velocity_min = 1.0
	fire.initial_velocity_max = 2.0
	fire.gravity = Vector3(0, 0.6, 0)
	fire.scale_amount_min = 0.08
	fire.scale_amount_max = 0.18
	var spark := BoxMesh.new()
	spark.size = Vector3.ONE
	fire.mesh = spark
	fire.material_override = Vfx.material(Color(1.0, 0.55, 0.18, 0.9), 2.5, true)
	h.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.25)
	light.light_energy = 1.8
	light.omni_range = 10.0
	light.position = Vector3(0, 2.4, 0)
	h.add_child(light)
	_lights.append(light)


func _skull(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var s := Node3D.new()
	parent.add_child(s)
	s.position = pos
	s.rotation.y = yaw
	var bone := Color(0.92, 0.88, 0.8)
	s.add_child(LowPoly.box(Vector3(0.24, 0.22, 0.26), bone, Vector3.ZERO, 0.9, 0.0, 0.0, &"bone"))
	s.add_child(LowPoly.box(Vector3(0.16, 0.08, 0.1), bone, Vector3(0, -0.12, -0.08), 0.9, 0.0, 0.0, &"bone"))
	for x in [-0.055, 0.055]:
		s.add_child(LowPoly.box(Vector3(0.06, 0.06, 0.02), Color(0.02, 0.01, 0.01), Vector3(x, 0.01, -0.13)))


func _stakes(h: Node3D) -> void:
	for k in 4:
		var x := -0.9 + k * 0.6 + _rng.randf_range(-0.1, 0.1)
		var len := _rng.randf_range(1.6, 2.6)
		var tilt := Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.25, 0.25))
		var stake := Node3D.new()
		stake.position = Vector3(x, 0, _rng.randf_range(-0.3, 0.3))
		stake.rotation = tilt
		h.add_child(stake)
		stake.add_child(LowPoly.cyl(0.05, 0.07, len, 5, Color(0.8, 0.7, 0.6), Vector3(0, len * 0.5, 0), 0.9, 0.0, 0.0, &"wood"))
		stake.add_child(LowPoly.prism(Vector3(0.1, 0.25, 0.1), Color(0.8, 0.7, 0.6), Vector3(0, len + 0.12, 0), 0.9, 0.0, 0.0, &"wood"))
		if k % 2 == 0 or _rng.randf() < 0.5:
			_skull(stake, Vector3(0, len - 0.1, 0), _rng.randf_range(-0.6, 0.6))
	_occluder(h, 3.0)


func _wheel(h: Node3D) -> void:
	var wood := Color(0.75, 0.65, 0.55)
	var height := 3.6
	h.add_child(LowPoly.cyl(0.09, 0.11, height, 6, wood, Vector3(0, height * 0.5, 0), 0.9, 0.0, 0.0, &"wood"))
	var wheel := Node3D.new()
	wheel.position = Vector3(0, height + 0.05, 0)
	wheel.rotation = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.35, 0.35))
	h.add_child(wheel)
	wheel.add_child(LowPoly.torus(0.85, 1.0, 14, 4, wood, Vector3.ZERO, 0.9, 0.0, 0.0, &"wood"))
	for k in 6:
		var spoke := LowPoly.box(Vector3(0.07, 0.06, 1.8), wood, Vector3.ZERO, 0.9, 0.0, 0.0, &"wood")
		spoke.rotation.y = PI * k / 6.0
		wheel.add_child(spoke)
	# Обрывки ткани и кости на колесе.
	wheel.add_child(LowPoly.box(Vector3(0.5, 0.08, 0.7), Color(0.4, 0.15, 0.12), Vector3(0.2, 0.06, 0.1), 0.9, 0.0, 0.0, &"rags"))
	_skull(wheel, Vector3(-0.3, 0.16, -0.2), 0.5)
	_occluder(h, height + 1.0)


func _tree(h: Node3D) -> void:
	var wood := Color(0.45, 0.4, 0.38)
	var height := _rng.randf_range(3.0, 4.2)
	h.add_child(LowPoly.cyl(0.14, 0.26, height, 6, wood, Vector3(0, height * 0.5, 0), 0.95, 0.0, 0.0, &"wood"))
	for k in 5:
		var y := height * _rng.randf_range(0.45, 0.95)
		var branch := Node3D.new()
		branch.position = Vector3(0, y, 0)
		branch.rotation = Vector3(0, _rng.randf() * TAU, _rng.randf_range(0.6, 1.1))
		h.add_child(branch)
		var len := _rng.randf_range(0.9, 1.6)
		branch.add_child(LowPoly.cyl(0.03, 0.07, len, 5, wood, Vector3(0, len * 0.5, 0), 0.95, 0.0, 0.0, &"wood"))
	_occluder(h, height + 0.6)


func _gibbet(h: Node3D) -> void:
	var wood := Color(0.75, 0.65, 0.55)
	var iron := Color(0.62, 0.6, 0.62)
	h.add_child(LowPoly.cyl(0.1, 0.12, 3.8, 6, wood, Vector3(0, 1.9, 0), 0.9, 0.0, 0.0, &"wood"))
	h.add_child(LowPoly.box(Vector3(1.5, 0.12, 0.12), wood, Vector3(0.65, 3.7, 0), 0.9, 0.0, 0.0, &"wood"))
	h.add_child(LowPoly.box(Vector3(0.03, 0.6, 0.03), iron, Vector3(1.3, 3.35, 0), 0.6, 0.5, 0.0, &"iron"))
	var cage := Node3D.new()
	cage.position = Vector3(1.3, 2.5, 0)
	h.add_child(cage)
	for k in 6:
		var a := TAU * k / 6.0
		cage.add_child(LowPoly.box(Vector3(0.04, 1.1, 0.04), iron, Vector3(cos(a) * 0.32, 0, sin(a) * 0.32), 0.6, 0.5, 0.0, &"rust"))
	cage.add_child(LowPoly.cyl(0.36, 0.36, 0.05, 6, iron, Vector3(0, 0.55, 0), 0.6, 0.5, 0.0, &"rust"))
	cage.add_child(LowPoly.cyl(0.36, 0.36, 0.05, 6, iron, Vector3(0, -0.55, 0), 0.6, 0.5, 0.0, &"rust"))
	_skull(cage, Vector3(0.05, -0.4, 0), 1.0)
	_occluder(h, 4.2)


# --- Пепел и угли ----------------------------------------------------------

func _build_particles() -> void:
	var ash := CPUParticles3D.new()
	ash.amount = 70
	ash.lifetime = 10.0
	ash.preprocess = 10.0
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(radius, 0.5, radius)
	ash.position = Vector3(0, 7.0, 0)
	ash.direction = Vector3(0.3, -1, 0.15)
	ash.spread = 25.0
	ash.initial_velocity_min = 0.3
	ash.initial_velocity_max = 0.7
	ash.gravity = Vector3(0, -0.05, 0)
	ash.scale_amount_min = 0.04
	ash.scale_amount_max = 0.09
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	ash.mesh = m
	ash.material_override = Vfx.material(Color(0.55, 0.5, 0.5, 0.8), 1.0, false)
	add_child(ash)
	var embers := CPUParticles3D.new()
	embers.amount = 26
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(radius, 0.2, radius)
	embers.position = Vector3(0, 0.3, 0)
	embers.direction = Vector3(0.2, 1, 0.1)
	embers.spread = 30.0
	embers.initial_velocity_min = 0.3
	embers.initial_velocity_max = 0.8
	embers.gravity = Vector3(0, 0.05, 0)
	embers.scale_amount_min = 0.04
	embers.scale_amount_max = 0.07
	embers.mesh = m
	embers.material_override = Vfx.material(Color(1.0, 0.45, 0.15, 0.9), 2.5, true)
	add_child(embers)


func _process(delta: float) -> void:
	_t += delta
	for i in _lights.size():
		_lights[i].light_energy = 1.7 + sin(_t * 9.0 + i * 1.7) * 0.15 + sin(_t * 23.0 + i) * 0.08
	_fade_occluders(delta)


## Предметы, заслоняющие героя от камеры, становятся «решётчато» прозрачными.
func _fade_occluders(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var hero := Combat.hero
	if cam == null or hero == null or not is_instance_valid(hero):
		return
	var hp := cam.unproject_position(hero.global_position + Vector3(0, 1.0, 0))
	var cam_fwd := Combat.flat_dir(-cam.global_basis.z)
	for o in _occluders:
		var base: Vector3 = o["base"]
		var closer := (base - hero.global_position).dot(-cam_fwd) > 0.0
		var target := 1.0
		if closer:
			var a := cam.unproject_position(base)
			var b := cam.unproject_position(o["top"])
			var rect := Rect2(Vector2(minf(a.x, b.x) - 90, minf(a.y, b.y) - 30), Vector2(absf(a.x - b.x) + 180, absf(a.y - b.y) + 60))
			if rect.has_point(hp):
				target = 0.3
		var alpha := move_toward(float(o["alpha"]), target, delta * 4.0)
		if alpha != float(o["alpha"]):
			o["alpha"] = alpha
			for m in o["mats"]:
				(m as ShaderMaterial).set_shader_parameter(&"fade", alpha)
