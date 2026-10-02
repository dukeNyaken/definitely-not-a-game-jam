class_name Arena
extends Node3D
## Круглая арена: каменный пол, колонны с жаровнями по краю, бездна вокруг.

var radius: float = 15.0
var floor_tint: Color = Color(0.32, 0.3, 0.28)
var _floor_mats: Array[StandardMaterial3D] = []
var _env: WorldEnvironment
var _sun: DirectionalLight3D


func build(p_radius: float) -> void:
	radius = p_radius
	_build_environment()
	_build_floor()
	_build_edge()


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
		var pillar := LowPoly.cyl(0.55, 0.65, h, 6, Color(0.36, 0.33, 0.32), pos + Vector3(0, h * 0.5, 0))
		add_child(pillar)
		add_child(LowPoly.box(Vector3(1.5, 0.3, 1.5), Color(0.28, 0.26, 0.25), pos + Vector3(0, 0.15, 0)))
		if not broken and k % 2 == 0:
			_brazier(pos + Vector3(0, h + 0.1, 0))
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


func _brazier(pos: Vector3) -> void:
	add_child(LowPoly.cyl(0.45, 0.3, 0.3, 6, Color(0.25, 0.22, 0.2), pos, 0.5, 0.5))
	var flame := LowPoly.cyl(0.0, 0.32, 0.7, 5, Color(1.0, 0.55, 0.18), pos + Vector3(0, 0.45, 0), 0.5, 0.0, 3.0)
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position = pos + Vector3(0, 0.8, 0)
	add_child(light)
