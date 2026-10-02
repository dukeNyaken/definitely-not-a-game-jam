class_name Arena
extends Node3D
## Круглая арена: каменный пол, колонны с жаровнями по краю, бездна вокруг.

var radius: float = 15.0
var floor_tint: Color = Color(0.32, 0.3, 0.28)
var _floor_mats: Array[StandardMaterial3D] = []
var _env: WorldEnvironment
var _sun: DirectionalLight3D
## Колонны: { "node": Node3D, "mats": [StandardMaterial3D], "base": Vector3, "top": Vector3, "alpha": float }
var _pillars: Array[Dictionary] = []
var _lights: Array[OmniLight3D] = []
var _t: float = 0.0


func build(p_radius: float) -> void:
	radius = p_radius
	_build_environment()
	_build_floor()
	_build_floor_decor()
	_build_edge()
	_build_dust()


func set_tint(c: Color) -> void:
	floor_tint = c
	for i in _floor_mats.size():
		var k := 1.0 - 0.12 * (i % 2)
		_floor_mats[i].albedo_color = Color(c.r * k, c.g * k, c.b * k)


func _build_environment() -> void:
	_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.025, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.4, 0.5)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.05
	e.fog_enabled = true
	e.fog_light_color = Color(0.06, 0.05, 0.09)
	e.fog_density = 0.012
	_env.environment = e
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-58, 30, 0)
	_sun.light_energy = 1.15
	_sun.light_color = Color(1.0, 0.93, 0.82)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 60.0
	add_child(_sun)


func _build_floor() -> void:
	# Концентрические кольца плит чередующихся тонов.
	var rings := 5
	for i in rings:
		var outer := radius + 1.0 - i * (radius + 1.0) / rings
		var inner := maxf(outer - (radius + 1.0) / rings, 0.0)
		var mi := MeshInstance3D.new()
		mi.mesh = LowPoly.flat(_disc(outer, inner, 32 - i * 3))
		var m := StandardMaterial3D.new()
		m.roughness = 0.95
		mi.material_override = m
		_floor_mats.append(m)
		mi.position.y = 0.0
		add_child(mi)
	set_tint(floor_tint)
	# Толща пола и бездна под ним.
	var base := LowPoly.cyl(radius + 1.0, radius + 0.6, 1.4, 32, Color(0.16, 0.14, 0.14), Vector3(0, -0.72, 0))
	add_child(base)
	var spokes := 8
	for k in spokes:
		var a := TAU * k / spokes
		var line := LowPoly.box(Vector3(0.12, 0.02, radius * 0.75), Color(0.2, 0.18, 0.18), Vector3(cos(a), 0, sin(a)) * radius * 0.45 + Vector3(0, 0.012, 0))
		line.rotation.y = -a + PI / 2
		add_child(line)


func _disc(outer: float, inner: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		# Обход по часовой, если смотреть сверху: лицевая сторона вверх.
		if inner <= 0.01:
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(o0 * outer)
			st.add_vertex(o1 * outer)
		else:
			st.add_vertex(o0 * inner)
			st.add_vertex(o0 * outer)
			st.add_vertex(o1 * outer)
			st.add_vertex(o0 * inner)
			st.add_vertex(o1 * outer)
			st.add_vertex(o1 * inner)
	st.generate_normals()
	return st.commit()


func _build_edge() -> void:
	var count := 12
	for k in count:
		var a := TAU * (k + 0.5) / count
		var pos := Vector3(cos(a), 0, sin(a)) * (radius + 0.9)
		var broken := k % 4 == 1
		var h := 1.6 if broken else 4.2 + (k % 3) * 0.5
		var holder := Node3D.new()
		add_child(holder)
		var pillar := LowPoly.cyl(0.55, 0.65, h, 6, Color(0.36, 0.33, 0.32), pos + Vector3(0, h * 0.5, 0))
		var mat := (pillar.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		pillar.material_override = mat
		holder.add_child(pillar)
		var mats: Array[StandardMaterial3D] = [mat]
		if not broken and k % 2 == 0:
			mats.append_array(_brazier(holder, pos + Vector3(0, h + 0.1, 0)))
		add_child(LowPoly.box(Vector3(1.5, 0.3, 1.5), Color(0.28, 0.26, 0.25), pos + Vector3(0, 0.15, 0)))
		_pillars.append({"node": holder, "mats": mats, "base": pos, "top": pos + Vector3(0, h + 1.0, 0), "alpha": 1.0})
	# Обломки по краю.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for k in 26:
		var a := rng.randf() * TAU
		var r := radius + rng.randf_range(-0.3, 1.2)
		var s := rng.randf_range(0.2, 0.55)
		var rock := LowPoly.sphere(s, 5, 3, Color(0.3, 0.28, 0.27), Vector3(cos(a) * r, s * 0.3, sin(a) * r))
		rock.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
		add_child(rock)


func _brazier(holder: Node3D, pos: Vector3) -> Array[StandardMaterial3D]:
	var bowl := LowPoly.cyl(0.45, 0.3, 0.3, 6, Color(0.25, 0.22, 0.2), pos, 0.5, 0.5)
	var bowl_mat := (bowl.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	bowl.material_override = bowl_mat
	holder.add_child(bowl)
	var flame := LowPoly.cyl(0.0, 0.32, 0.7, 5, Color(1.0, 0.55, 0.18), pos + Vector3(0, 0.45, 0), 0.5, 0.0, 3.0)
	var flame_mat := (flame.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	flame.material_override = flame_mat
	holder.add_child(flame)
	var fire := CPUParticles3D.new()
	fire.amount = 10
	fire.lifetime = 0.7
	fire.position = pos + Vector3(0, 0.5, 0)
	fire.direction = Vector3.UP
	fire.spread = 15.0
	fire.initial_velocity_min = 0.8
	fire.initial_velocity_max = 1.6
	fire.gravity = Vector3(0, 0.5, 0)
	fire.scale_amount_min = 0.08
	fire.scale_amount_max = 0.16
	var spark := BoxMesh.new()
	spark.size = Vector3.ONE
	fire.mesh = spark
	fire.material_override = Vfx.material(Color(1.0, 0.6, 0.2, 0.9), 2.5, true)
	holder.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position = pos + Vector3(0, 0.8, 0)
	add_child(light)
	_lights.append(light)
	return [bowl_mat, flame_mat]


## Пыль в воздухе над ареной.
func _build_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.amount = 60
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(radius, 2.5, radius)
	dust.position = Vector3(0, 2.5, 0)
	dust.direction = Vector3(0.3, 1, 0.1)
	dust.spread = 60.0
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.25
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 0.03
	dust.scale_amount_max = 0.07
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	dust.mesh = m
	dust.material_override = Vfx.material(Color(1.0, 0.85, 0.6, 0.5), 1.4, true)
	add_child(dust)


## Руны в центре и трещины в плитах.
func _build_floor_decor() -> void:
	var rune_col := Color(0.95, 0.75, 0.4, 0.22)
	var ring := MeshInstance3D.new()
	ring.mesh = Vfx.ring_mesh(4.2, 0.12, 64)
	ring.material_override = Vfx.material(rune_col, 1.4, true)
	ring.position.y = 0.015
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var inner := MeshInstance3D.new()
	inner.mesh = Vfx.ring_mesh(3.4, 0.06, 64)
	inner.material_override = ring.material_override
	inner.position.y = 0.015
	add_child(inner)
	for k in 7:
		var a := TAU * k / 7.0 - PI / 2
		var glyph := LowPoly.box(Vector3(0.18, 0.01, 0.5), Color(0.95, 0.75, 0.4), Vector3(cos(a), 0, sin(a)) * 3.8 + Vector3(0, 0.016, 0), 0.5, 0.0, 0.6)
		glyph.rotation.y = -a
		glyph.material_override = Vfx.material(rune_col, 1.6, true)
		add_child(glyph)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 34:
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.0, radius - 0.5)
		var crack := LowPoly.box(Vector3(rng.randf_range(0.04, 0.08), 0.01, rng.randf_range(0.5, 1.6)), Color(0.12, 0.1, 0.1), Vector3(cos(a) * r, 0.012, sin(a) * r))
		crack.rotation.y = rng.randf() * TAU
		add_child(crack)
	for k in 18:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.5, radius - 1.0)
		var slab := LowPoly.box(Vector3(rng.randf_range(0.8, 1.4), 0.04, rng.randf_range(0.8, 1.4)), Color(0, 0, 0, 0.12), Vector3(cos(a) * r, 0.01, sin(a) * r))
		slab.material_override = Vfx.material(Color(0, 0, 0, 0.14), 1.0, false)
		slab.rotation.y = rng.randf() * TAU
		add_child(slab)


func _process(delta: float) -> void:
	_t += delta
	for i in _lights.size():
		_lights[i].light_energy = 1.5 + sin(_t * 9.0 + i * 1.7) * 0.12 + sin(_t * 23.0 + i) * 0.06
	_fade_occluders(delta)


## Колонны, заслоняющие героя от камеры, становятся полупрозрачными.
func _fade_occluders(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var hero := Combat.hero
	if cam == null or hero == null or not is_instance_valid(hero):
		return
	var hp := cam.unproject_position(hero.global_position + Vector3(0, 1.0, 0))
	var cam_fwd := Combat.flat_dir(-cam.global_basis.z)
	for p in _pillars:
		var base: Vector3 = p["base"]
		var closer := (base - hero.global_position).dot(-cam_fwd) > 0.0
		var target := 1.0
		if closer:
			var a := cam.unproject_position(base)
			var b := cam.unproject_position(p["top"])
			var rect := Rect2(Vector2(minf(a.x, b.x) - 60, minf(a.y, b.y) - 20), Vector2(absf(a.x - b.x) + 120, absf(a.y - b.y) + 40))
			if rect.has_point(hp):
				target = 0.25
		var alpha := move_toward(float(p["alpha"]), target, delta * 4.0)
		if alpha != float(p["alpha"]):
			p["alpha"] = alpha
			for m in p["mats"]:
				var mat := m as StandardMaterial3D
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.albedo_color.a = alpha
