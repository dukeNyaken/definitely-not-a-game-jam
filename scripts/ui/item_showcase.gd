class_name ItemShowcase
extends SubViewportContainer
## 3D-витрина вещей: кольцо вращающихся вещей (меню) или одна вещь-артефакт (финал).

var viewport: SubViewport
var pivot: Node3D
var spin_speed: float = 0.35
## Пикселизовать самостоятельно (если витрина лежит поверх ретро-постобработки).
var self_pixelate: bool = true
var _displays: Array[Node3D] = []


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.42, 0.55)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.8
	env.environment = e
	viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.3
	viewport.add_child(light)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 2.5, -3)
	rim.light_color = Color(1.0, 0.7, 0.4)
	rim.light_energy = 2.0
	rim.omni_range = 10.0
	viewport.add_child(rim)
	pivot = Node3D.new()
	viewport.add_child(pivot)


func _add_camera(pos: Vector3, look: Vector3, size: float) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	viewport.add_child(cam)
	cam.position = pos
	cam.look_at(look, Vector3.UP)
	cam.current = true


## Семь вещей по кольцу.
func show_ring(states: Array[ItemState], radius: float = 2.2) -> void:
	_add_camera(Vector3(0, 3.2, 6.5), Vector3(0, 0.3, 0), 7.5)
	var n := states.size()
	for i in n:
		var a := TAU * i / n
		var d := ItemVisuals.build_display(states[i])
		d.scale = Vector3.ONE * 1.3
		pivot.add_child(d)
		d.position = Vector3(cos(a) * radius, 0.6, sin(a) * radius)
		_displays.append(d)
	var ring := MeshInstance3D.new()
	ring.mesh = Vfx.ring_mesh(radius, 0.06, 64)
	ring.material_override = Vfx.material(Color(1.0, 0.78, 0.35, 0.8), 1.6, true)
	pivot.add_child(ring)
	# В центре — герой в исподнем: всё это ему предстоит отдать.
	var floor_disc := LowPoly.cyl(radius + 0.6, radius + 0.8, 0.3, 24, Color(0.2, 0.17, 0.18), Vector3(0, -0.17, 0))
	viewport.add_child(floor_disc)
	var hero := Actor.new()
	hero.set_physics_process(false)
	viewport.add_child(hero)
	hero.remove_from_group(&"actors")
	hero.facing = Vector3(0.35, 0, 1).normalized()
	var model := ActorModel.new()
	hero.add_child(model)
	model.setup(hero, ActorModel.Kind.HERO)
	model.scale = Vector3.ONE * 1.05
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 2.6, 1.2)
	glow.light_color = Color(1.0, 0.8, 0.55)
	glow.light_energy = 1.6
	glow.omni_range = 6.0
	viewport.add_child(glow)
	# Затмение за спиной героя.
	var sky := EclipseSky.new()
	viewport.add_child(sky)
	sky.scale = Vector3.ONE * 0.33
	var fwd := (Vector3(0, 0.3, 0) - Vector3(0, 3.2, 6.5)).normalized()
	sky.position = Vector3(0.9, -1.2, -9.0)
	sky.look_at(sky.position + fwd, Vector3.UP)


## Одна вещь крупно.
func show_single(state: ItemState) -> void:
	_add_camera(Vector3(0, 0.9, 4.0), Vector3(0, 0.0, 0), 2.6)
	var d := ItemVisuals.build_display(state)
	d.scale = Vector3.ONE * 1.6
	pivot.add_child(d)
	_displays.append(d)
	spin_speed = 0.7


func _ready() -> void:
	Render.mode_changed.connect(_apply_retro)
	_apply_retro(Render.mode)


## В PS1 витрина рендерится в пониженном разрешении и растягивается без сглаживания.
func _apply_retro(mode: int) -> void:
	stretch_shrink = 3 if mode == Render.Mode.PS1 and self_pixelate else 1


func _process(delta: float) -> void:
	pivot.rotation.y += spin_speed * delta
	for d in _displays:
		if is_instance_valid(d) and _displays.size() > 1:
			d.rotation.y -= delta * 0.9
