extends Node
## Драйвер карты ряби (загружается из tools/flicker.gd после старта движка).

## Сколько кадров сравнивается и сколько раз пиксель должен мигнуть, чтобы считаться рябящим.
const FRAMES := 48
const HOT := 10
## Насколько должен измениться цвет пикселя между кадрами, чтобы это считалось миганием.
const THRESHOLD := 0.08
## Сравнивается каждый STEP-й пиксель по обеим осям.
const STEP := 2

var _key := "song"
var _at := 20.0
var _out := "user://flicker.png"
var _speed := 4.0
var _t := 0.0
var _frozen := false
var _n := 0
var _centre: Vector3
var _prev: Image
var _heat: PackedInt32Array
var _w := 0
var _h := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"key": _key = kv[1]
			"at": _at = float(kv[1])
			"out": _out = kv[1]
			"speed": _speed = float(kv[1])
	var entry := CutsceneCatalog.find(_key)
	if entry.is_empty() or not entry["playable"]:
		print("нет сцены с ключом ", _key)
		get_tree().quit(1)
		return
	var items: Array[Dictionary] = [{"key": _key, "opts": CutsceneCatalog.resolve(entry)}]
	Theater.open.call_deferred(get_tree(), items)


func _game() -> Game:
	return get_tree().get_first_node_in_group(&"game") as Game


func _process(delta: float) -> void:
	var g := _game()
	if g == null:
		return
	if not _frozen:
		Engine.time_scale = _speed
		_t += delta
		if _t >= _at:
			_freeze(g)
		return
	_n += 1
	# Сдвиг камеры — в пределах одного пикселя низкого разрешения.
	var px: float = g.rig.camera.size / float(Render.TARGET_LINES[Render.mode])
	g.rig.global_position = _centre + g.rig.global_basis.x * randf_range(-0.5, 0.5) * px \
			+ g.rig.global_basis.y * randf_range(-0.5, 0.5) * px
	if _n < 3:
		return
	var img := get_viewport().get_texture().get_image()
	if _prev == null:
		_w = img.get_width() / STEP
		_h = img.get_height() / STEP
		_heat.resize(_w * _h)
	else:
		for y in _h:
			for x in _w:
				var a := img.get_pixel(x * STEP, y * STEP)
				var b := _prev.get_pixel(x * STEP, y * STEP)
				if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > THRESHOLD:
					_heat[y * _w + x] += 1
	_prev = img
	if _n >= FRAMES + 3:
		_report(img)


## Сцена замирает: актёры, частицы и твины — паузой дерева; режиссёр сцены и часы песни — выключением.
func _freeze(g: Game) -> void:
	_frozen = true
	Engine.time_scale = 1.0
	for n in g.cutscene.get_children():
		n.process_mode = Node.PROCESS_MODE_DISABLED
	g.cutscene.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = true
	_centre = g.rig.global_position


func _report(last: Image) -> void:
	var map := Image.create(_w, _h, false, Image.FORMAT_RGB8)
	var hot := 0
	for y in _h:
		for x in _w:
			var count := _heat[y * _w + x]
			if count >= HOT:
				hot += 1
			var base := last.get_pixel(x * STEP, y * STEP)
			var k := minf(count / float(FRAMES / 2), 1.0)
			map.set_pixel(x, y, Color(base.r * 0.35, base.g * 0.35, base.b * 0.35).lerp(Color(1.0, 0.1 + k * 0.8, 0.0), minf(k * 2.0, 1.0)))
	map.save_png(_out)
	print("%s на %.0f с: рябит %.2f%% кадра -> %s" % [_key, _at, 100.0 * hot / (_w * _h), ProjectSettings.globalize_path(_out)])
	get_tree().quit()
