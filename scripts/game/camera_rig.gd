class_name CameraRig
extends Node3D
## Ортографическая изометрия: наклон ~35°, поворот 45°. Следует за героем со смещением к курсору.

@export var pitch_degrees: float = 35.0
@export var yaw_degrees: float = 45.0
@export var size: float = 13.0
@export var distance: float = 40.0
@export var cursor_lead: float = 0.22
@export var max_lead: float = 4.0
@export var follow_speed: float = 7.0

var target: Node3D
var camera: Camera3D
## Кинорежим сюжетных сцен: камера не следит за героем и курсором, ею управляют cine_*.
var cinematic: bool = false
## Дыхание камеры в кинорежиме: доля кадра, на которую она медленно плавает (0 — стоит намертво).
var sway: float = 0.006
var _shake: float = 0.0
var _sway_t: float = 0.0
var _focus: Vector3
var _cine_tween: Tween


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
	var sky := RingMoon.new()
	sky.name = "RingMoon"
	camera.add_child(sky)
	sky.position = Vector3(size * 0.12, size * 0.36, -80.0)


func snap() -> void:
	if target != null:
		_focus = target.global_position
		global_position = _focus


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Плавный наезд на точку: фокус и размер кадра (меньше — крупнее). dur 0 — мгновенно.
func cine_to(pos: Vector3, zoom: float, dur: float) -> void:
	cinematic = true
	_kill_cine()
	if dur <= 0.0:
		_focus = pos
		camera.size = zoom
		return
	_cine_tween = _new_cine_tween()
	_cine_tween.tween_property(self, "_focus", pos, dur)
	_cine_tween.tween_property(camera, "size", zoom, dur)


## Облёт камеры вокруг фокуса: поворот по горизонтали от обычного угла.
func cine_yaw(offset_degrees: float, dur: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "rotation_degrees:y", yaw_degrees + offset_degrees, maxf(dur, 0.01))


## Конец сцены: размер и поворот возвращаются, камера снова следует за целью.
func cine_release(dur: float = 0.8) -> void:
	_kill_cine()
	cinematic = false
	_cine_tween = _new_cine_tween()
	_cine_tween.tween_property(camera, "size", size, maxf(dur, 0.01))
	_cine_tween.tween_property(self, "rotation_degrees:y", yaw_degrees, maxf(dur, 0.01))


func _new_cine_tween() -> Tween:
	return create_tween().set_parallel(true).set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_cine() -> void:
	if _cine_tween != null and _cine_tween.is_valid():
		_cine_tween.kill()
	_cine_tween = null


func _process(delta: float) -> void:
	if cinematic:
		_sway_t += delta
		global_position = _focus + _sway_offset() + _shake_offset(delta)
		return
	if target == null or not is_instance_valid(target):
		return
	var desired := target.global_position
	var mouse: Variant = mouse_ground_point()
	if mouse != null:
		var lead: Vector3 = (mouse - desired) * cursor_lead
		desired += lead.limit_length(max_lead)
	_focus = _focus.lerp(desired, minf(1.0, delta * follow_speed))
	global_position = _focus + _shake_offset(delta)


## Медленный «ручной» дрейф кадра: в пикселях одинаковый при любом наезде.
func _sway_offset() -> Vector3:
	if sway <= 0.0:
		return Vector3.ZERO
	var a := sway * camera.size
	var right := global_basis.x
	var up := global_basis.y
	return right * sin(_sway_t * 0.53) * a + up * sin(_sway_t * 0.41 + 1.7) * a * 0.7


func _shake_offset(delta: float) -> Vector3:
	if _shake <= 0.0:
		return Vector3.ZERO
	_shake = maxf(_shake - delta * 2.5, 0.0)
	return Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * _shake * 0.4


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
