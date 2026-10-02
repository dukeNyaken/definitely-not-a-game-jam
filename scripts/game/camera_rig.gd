class_name CameraRig
extends Node3D
## Ортографическая изометрия: наклон ~35°, поворот 45°. Следует за героем со смещением к курсору.

@export var pitch_degrees: float = 35.0
@export var yaw_degrees: float = 45.0
@export var size: float = 14.5
@export var distance: float = 40.0
@export var cursor_lead: float = 0.22
@export var max_lead: float = 4.0
@export var follow_speed: float = 7.0

var target: Node3D
var camera: Camera3D
var _shake: float = 0.0
var _focus: Vector3


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.near = 0.5
	camera.far = 120.0
	add_child(camera)
	rotation_degrees = Vector3(-pitch_degrees, yaw_degrees, 0)
	camera.position = Vector3(0, 0, distance)
	camera.current = true
	var sky := EclipseSky.new()
	sky.name = "Eclipse"
	camera.add_child(sky)
	sky.position = Vector3(size * 0.12, size * 0.36, -80.0)


func snap() -> void:
	if target != null:
		_focus = target.global_position
		global_position = _focus


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var desired := target.global_position
	var mouse: Variant = mouse_ground_point()
	if mouse != null:
		var lead: Vector3 = (mouse - desired) * cursor_lead
		desired += lead.limit_length(max_lead)
	_focus = _focus.lerp(desired, minf(1.0, delta * follow_speed))
	var offset := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		offset = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * _shake * 0.4
	global_position = _focus + offset


## Точка на полу под курсором.
func mouse_ground_point() -> Variant:
	if camera == null:
		return null
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	return Plane(Vector3.UP, 0.0).intersects_ray(from, dir)


## Направления «вверх» и «вправо» экрана на полу — для WASD.
func ground_axes() -> Array[Vector3]:
	var fwd := Combat.flat_dir(-global_basis.z)
	var right := Combat.flat_dir(global_basis.x)
	return [fwd, right]
