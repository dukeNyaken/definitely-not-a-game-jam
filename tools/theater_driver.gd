extends Node
## Драйвер прогона сюжетных сцен (загружается из tools/theater.gd после старта движка).

## Сцена дольше этого (в секундах сцены) считается зависшей.
const LIMIT := 420.0

var _speed := 8.0
var _key := ""
var _keys: Array[String] = []
var _shown := 0
var _t := 0.0
var _log: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"speed": _speed = float(kv[1])
			"key": _key = kv[1]
	var items: Array[Dictionary] = []
	for e in CutsceneCatalog.playable():
		if _key == "" or e["key"] == _key:
			items.append({"key": e["key"], "opts": CutsceneCatalog.resolve(e)})
			_keys.append(e["key"])
	if items.is_empty():
		print("нет сцены с ключом ", _key)
		get_tree().quit(1)
		return
	Theater.open.call_deferred(get_tree(), items)


func _process(delta: float) -> void:
	Engine.time_scale = _speed
	_t += delta
	var scene := get_tree().current_scene
	var done := scene != null and scene.name == "CutsceneGallery"
	# Очередь шагнула к следующей сцене (или кончилась): предыдущая сцена доиграна.
	var cursor := _keys.size() if done else Theater.cursor
	while _shown < cursor:
		_log.append("%-12s %4.0f с" % [_keys[_shown], _t])
		_shown += 1
		_t = 0.0
	if done:
		_finish(0)
	elif _t > LIMIT:
		_log.append("%-12s ЗАВИСЛА" % _keys[_shown])
		_finish(1)


func _finish(code: int) -> void:
	set_process(false)
	Engine.time_scale = 1.0
	for l in _log:
		print(l)
	print("сцен показано: %d из %d" % [_shown, _keys.size()])
	get_tree().quit(code)
