extends SceneTree
## Проверка анимаций героя крупным планом (камера игры: орто, наклон 35°, рендер PS1/PS2):
## Godot --path . -s tools/anim_check.gd -- out=<папка> [render=ps2] [size=4]
## Кадры состояний: стойка, бег, удары, блок, рывок, попадание, смерть — по файлу на кадр.
## Драйвер грузится после старта, когда автозагрузки уже зарегистрированы.

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var drv: Node = load("res://tools/anim_check_driver.gd").new()
		drv.name = "AnimCheckDriver"
		root.add_child(drv)
	return false
