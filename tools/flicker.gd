extends SceneTree
## Карта ряби сюжетной сцены: где в кадре поверхности мигают, перекрывая друг друга (z-fighting).
## Сцена из меню «Катсцены» доигрывается до секунды at и замирает; камера каждый кадр сдвигается
## на случайную долю ретро-пикселя — так же меняется привязка вершин в PS1, когда камера ведёт идущих.
## Картинка при этом стоит на месте, поэтому мигает только то, что рябит. На карте (out) залитые
## пятна — рябь наложенных поверхностей; тонкие контуры — обычное дрожание краёв, это норма.
##   godot --audio-driver Dummy --path . -s tools/flicker.gd -- key=song at=55 out=/tmp/flicker.png
## Нужен экран (не --headless): карта строится по кадрам. speed=N — как быстро доиграть до at.
## Драйвер грузится после старта, когда автозагрузки уже зарегистрированы.

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var drv: Node = load("res://tools/flicker_driver.gd").new()
		drv.name = "FlickerDriver"
		root.add_child(drv)
	return false
