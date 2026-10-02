extends Node
## Карта ввода. Клавиши физические: WASD работает и на русской раскладке.

const KEYS := {
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"dash": [KEY_SPACE],
	&"grab": [KEY_Q],
	&"volley": [KEY_E],
	&"tree": [KEY_TAB],
	&"pause": [KEY_ESCAPE],
	&"debug": [KEY_F1],
	&"interact": [KEY_F],
}
const MOUSE := {
	&"attack": MOUSE_BUTTON_LEFT,
	&"block": MOUSE_BUTTON_RIGHT,
}


func _init() -> void:
	for action in KEYS:
		_ensure(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		_ensure(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[action]
		InputMap.action_add_event(action, mb)


func _ensure(action: StringName) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.2)
