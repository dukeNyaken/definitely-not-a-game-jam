extends SceneTree
## Автопрохождение забега ботом (проверка цикла и баланса).
## Godot --headless --path . -s tools/autoplay.gd -- seed=123 speed=4 immortal=1 pick=0
## Драйвер грузится после старта, когда автозагрузки уже зарегистрированы.

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var drv: Node = load("res://tools/autoplay_driver.gd").new()
		drv.name = "AutoplayDriver"
		root.add_child(drv)
	return false
