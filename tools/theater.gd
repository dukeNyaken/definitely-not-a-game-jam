extends SceneTree
## Прогон сюжетных сцен из меню «Катсцены» без игрока: каждая идёт своим ходом, реплики уходят сами.
## Печатает, сколько длится каждая сцена, и проверяет, что все доходят до конца и возвращают в галерею.
##   godot --headless --path . -s tools/theater.gd -- speed=8            все сцены подряд
##   godot --headless --path . -s tools/theater.gd -- speed=8 key=hearth одна сцена (ключи — в CutsceneCatalog)
## Драйвер грузится после старта, когда автозагрузки уже зарегистрированы.

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var drv: Node = load("res://tools/theater_driver.gd").new()
		drv.name = "TheaterDriver"
		root.add_child(drv)
	return false
