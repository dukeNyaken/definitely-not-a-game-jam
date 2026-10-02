class_name PlayerController
extends Node
## Ввод игрока → намерения Actor: WASD — движение, мышь — направление, кнопки — действия вещей.

const BUFFER := 0.18

var actor: Actor
var rig: CameraRig
## Пока открыт алтарь, пауза и т. п. — ввод не идёт в героя.
var enabled: bool = true
var _buffered: Dictionary = {}


func setup(p_actor: Actor, p_rig: CameraRig) -> void:
	actor = p_actor
	rig = p_rig


func _physics_process(delta: float) -> void:
	if actor == null or actor.dead:
		return
	if not enabled:
		actor.move_input = Vector3.ZERO
		actor.release(&"block")
		return
	var axes := rig.ground_axes()
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	actor.move_input = axes[1] * v.x - axes[0] * v.y
	var mouse = rig.mouse_ground_point()
	if mouse != null:
		actor.aim_point = mouse
	# ЛКМ удерживается — комбо идёт само.
	if Input.is_action_pressed(&"attack"):
		actor.press(&"attack")
	if Input.is_action_just_pressed(&"block"):
		actor.press(&"block")
	elif Input.is_action_pressed(&"block"):
		var shield := actor.slot(&"block") as ShieldAction
		if shield != null and not shield.holding:
			actor.press(&"block")
	if Input.is_action_just_released(&"block"):
		actor.release(&"block")
	for action in [&"dash", &"grab", &"volley"]:
		if Input.is_action_just_pressed(action):
			_buffered[action] = BUFFER
	for action in _buffered.keys():
		_buffered[action] -= delta
		if _buffered[action] <= 0.0:
			_buffered.erase(action)
			continue
		if action == &"dash":
			var boots := actor.slot(&"dash") as BootsAction
			if boots != null:
				boots.dash_direction = actor.move_input
		if actor.press(action):
			_buffered.erase(action)
