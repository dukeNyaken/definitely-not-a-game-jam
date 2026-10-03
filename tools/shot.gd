extends SceneTree
## Скриншоты для разработки:
## Godot --path . -s tools/shot.gd -- preset=game out=/tmp/x.png delay=3
## variant=<id> — вариант сгенерированного героя (prototype/heroes.json), как в меню «Герой».
## Драйвер грузится после старта, когда автозагрузки уже зарегистрированы.

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var drv: Node = load("res://tools/shot_driver.gd").new()
		drv.name = "ShotDriver"
		root.add_child(drv)
	return false
