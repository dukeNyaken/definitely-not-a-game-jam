class_name CutsceneFx
extends RefCounted
## Эффекты сюжетных сцен из частиц и света: пыль и угли в воздухе, искры удара, пыль от падения,
## столб света дара, шлейф летящей вещи, огонь, вспышка и живой (мерцающий) свет.
## Разовые эффекты убирают себя сами; постоянные (пыль, огонь, свет) — реквизит сцены.

static var _cube: BoxMesh


## Свет с живым огнём: энергия дрожит вокруг base.
class FlickerLight extends OmniLight3D:
	var base: float = 1.0
	var amount: float = 0.12
	var _t: float = randf() * 10.0

	func _process(delta: float) -> void:
		_t += delta
		light_energy = base * (1.0 + sin(_t * 9.0) * amount + sin(_t * 23.0 + 1.3) * amount * 0.5)


static func _mesh() -> BoxMesh:
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	return _cube


## Частицы-кубики: цвет вершин (затухание по color_ramp) умножается на яркий цвет материала.
static func _particles(color: Color, emissive: float, additive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _mesh()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(color.r * emissive, color.g * emissive, color.b * emissive, color.a)
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Прозрачность частицы за жизнь: появиться, пожить, погаснуть.
static func _ramp(fade_in: float = 0.15, hold: float = 0.6) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, fade_in, hold, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	return g


static func _free_after(node: Node, sec: float) -> void:
	if node.is_inside_tree():
		node.get_tree().create_timer(sec, true, false, true).timeout.connect(node.queue_free)


## Пылинки или угли, висящие в воздухе вокруг точки.
static func motes(parent: Node3D, center: Vector3, extents: Vector3, color: Color, amount: int = 40, rise: float = 0.15) -> CPUParticles3D:
	var p := _particles(color, 1.6, true)
	p.amount = amount
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0.2, 1, 0.1)
	p.spread = 70.0
	p.initial_velocity_min = rise * 0.3
	p.initial_velocity_max = rise
	p.gravity = Vector3(0, rise * 0.1, 0)
	p.scale_amount_min = 0.025
	p.scale_amount_max = 0.06
	p.color_ramp = _ramp(0.25, 0.7)
	parent.add_child(p)
	p.global_position = center
	return p


## Искры удара: разлетаются и падают.
static func sparks(parent: Node3D, pos: Vector3, color: Color, amount: int = 22, speed: float = 4.0) -> void:
	var p := _particles(color, 2.2, true)
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.07
	p.color_ramp = _ramp(0.01, 0.5)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_after(p, 1.0)


## Пыль по земле кольцом: падение, удар, открытые ворота.
static func dust(parent: Node3D, pos: Vector3, radius: float = 1.0, color: Color = Color(0.62, 0.56, 0.52, 0.7), amount: int = 26) -> void:
	var p := _particles(color, 1.0, false)
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.3
	p.direction = Vector3(1, 0.15, 0)
	p.spread = 180.0
	p.flatness = 0.85
	p.initial_velocity_min = radius * 1.2
	p.initial_velocity_max = radius * 2.6
	p.damping_min = radius * 2.0
	p.damping_max = radius * 3.0
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.24
	p.color_ramp = _ramp(0.05, 0.4)
	parent.add_child(p)
	p.global_position = pos + Vector3(0, 0.15, 0)
	p.emitting = true
	_free_after(p, 1.6)


## Огонь (жаровня, свеча): языки поднимаются и гаснут. size — высота пламени.
static func fire(parent: Node3D, pos: Vector3, size: float = 0.5, color: Color = Color(1.0, 0.5, 0.15)) -> CPUParticles3D:
	var p := _particles(color, 2.4, true)
	p.amount = int(18 + size * 20)
	p.lifetime = 0.7
	p.preprocess = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.35
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = size * 1.2
	p.initial_velocity_max = size * 2.4
	p.gravity = Vector3(0, size, 0)
	p.scale_amount_min = size * 0.12
	p.scale_amount_max = size * 0.3
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1.2, 1.0, 0.6, 0.0), Color(1.2, 0.95, 0.5, 1.0), Color(1.0, 0.4, 0.2, 0.8), Color(0.5, 0.1, 0.1, 0.0)])
	p.color_ramp = g
	parent.add_child(p)
	p.global_position = pos
	return p


## Шлейф за летящей вещью: частицы остаются в мире и гаснут. Выключите emitting, когда вещь долетит.
static func trail(node: Node3D, color: Color) -> CPUParticles3D:
	var p := _particles(color, 2.0, true)
	p.local_coords = false
	p.amount = 36
	p.lifetime = 0.55
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.08
	p.color_ramp = _ramp(0.02, 0.4)
	node.add_child(p)
	return p


## Столб света от земли: дар принят, клятва дана, перстень отдан.
static func pillar(parent: Node3D, pos: Vector3, color: Color, height: float = 5.0, radius: float = 0.55, dur: float = 1.6) -> void:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.global_position = pos
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.55
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 14
	cyl.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	var mat := Vfx.material(Color(color, 0.55), 1.8, true)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = height * 0.5
	pivot.add_child(mi)
	pivot.scale = Vector3(0.15, 0.05, 0.15)
	var tw := pivot.create_tween().set_ignore_time_scale(true)
	tw.tween_property(pivot, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "scale", Vector3(0.04, 1.1, 0.04), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(pivot.queue_free)
	flare(parent, pos + Vector3(0, 1.2, 0), color, 3.0, 6.0, dur + 0.3)


## Вспышка света: быстро загорается и гаснет за dur.
static func flare(parent: Node3D, pos: Vector3, color: Color, energy: float = 2.5, range_m: float = 5.0, dur: float = 0.8) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(l.queue_free)


## Постоянный свет сцены (ключевой свет, свеча, фонарь). flicker — живой огонь.
static func light(parent: Node3D, pos: Vector3, color: Color, energy: float = 1.5, range_m: float = 5.0, flicker: float = 0.0) -> OmniLight3D:
	var l: OmniLight3D
	if flicker > 0.0:
		var f := FlickerLight.new()
		f.base = energy
		f.amount = flicker
		l = f
	else:
		l = OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	parent.add_child(l)
	l.global_position = pos
	return l


## Плавно меняет силу света (у мерцающего — базовую силу).
static func light_to(l: OmniLight3D, energy: float, dur: float) -> void:
	if l == null or not is_instance_valid(l):
		return
	var prop := "base" if l is FlickerLight else "light_energy"
	if dur <= 0.0:
		l.set(prop, energy)
		return
	l.create_tween().set_ignore_time_scale(true).tween_property(l, prop, energy, dur)
