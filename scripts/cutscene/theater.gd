class_name Theater
extends Node
## Просмотр сюжетных сцен из меню «Катсцены». Готовит забег под сцену (какие вещи уже отданы, какой
## этап), запускает её в настоящей игре — теми же путями, что и в забеге, — и возвращает зрителя
## в галерею; если сцены смотрят подряд, ведёт к следующей. На каждую сцену игра загружается заново,
## поэтому очередь показа статическая: она переживает смену сцен.
##
## В сцене: удержание Пробела пропускает её (при показе подряд — к следующей), удержание Esc —
## выход в галерею.

const GAME_SCENE := "res://scenes/game.tscn"
const GALLERY_SCENE := "res://scenes/cutscene_gallery.tscn"
const SEED := 424242

## Очередь показа: [{ "key": ключ сцены в CutsceneCatalog, "opts": её варианты }].
static var queue: Array[Dictionary] = []
static var cursor: int = 0
## Последняя показанная сцена: на неё встаёт галерея, когда зритель возвращается.
static var last_key: String = ""

var game: Game
var _abort: bool = false
var _left: bool = false


## Идёт ли просмотр: игра загружена ради сцены из очереди, а не ради забега.
static func requested() -> bool:
	return cursor < queue.size()


## Показать сцены по очереди, начиная с первой.
static func open(tree: SceneTree, items: Array[Dictionary]) -> void:
	queue = items
	cursor = 0
	if not requested():
		return
	prepare(queue[cursor])
	tree.change_scene_to_file(GAME_SCENE)


static func close() -> void:
	queue = []
	cursor = 0


## Забег под сцену: вещи, отданные до неё, и её этап. Игра прочтёт это при загрузке.
static func prepare(item: Dictionary) -> void:
	var entry := CutsceneCatalog.find(item["key"])
	RunState.new_run(SEED)
	for id in CutsceneCatalog.given_before(entry, item["opts"]):
		RunState.sacrifice(RunState.ring.index_of(id))
	RunState.stage = CutsceneCatalog.stage_of(entry)
	RunState.running = false


## Вызывается игрой вместо начала этапа.
func run(p_game: Game) -> void:
	game = p_game
	var item := queue[cursor]
	var entry := CutsceneCatalog.find(item["key"])
	var opts: Dictionary = item["opts"]
	var cs := game.cutscene
	last_key = item["key"]
	RunState.running = false
	cs.skip_requested.connect(_on_skip)
	_caption(entry, opts)
	game.set_state(Game.State.CUTSCENE)
	game.hero.global_position = Vector3(0, 0, 3)
	game.rig.snap()
	match entry["scene"]:
		&"prologue":
			game.arena.set_tint(RunState.current_threat().floor_tint)
			await PrologueScene.play(cs, game)
		&"rule":
			# Первый этап только что пройден: посреди арены поднимается алтарь.
			_between_stages()
			game.hero.global_position = Vector3(3.0, 0, 5.0)
			game.rig.snap()
			game.spawn_altar()
			cs.ui.black(1.0, 0.0)
			cs.ui.black(0.0, 0.9)
			await RuleScene.play(cs, game)
		&"gift":
			_between_stages()
			# Солдат стоит у алтаря; вещь уходит из его рук внутри сцены.
			game.hero.global_position = Vector3(0, 0, 0.6)
			game.rig.snap()
			cs.ui.black(1.0, 0.0)
			cs.ui.black(0.0, 0.9)
			game.do_sacrifice(RunState.ring.index_of(opts["item"]))
			return
		&"song":
			_between_stages()
			await IlvaSongScene.play(cs, game)
		&"hearth":
			_between_stages()
			await HearthScene.play(cs, game)
		&"temptation":
			_between_stages()
			await TemptationScene.play(cs, game)
		&"palace":
			_between_stages()
			await PalaceScene.play(cs, game, entry["n"])
		&"gates":
			game.start_stage(RunState.stage)
			await game.boss_director.intro_finished
			# Баннер «Тиран» — последний кадр сцены: даём ему прозвучать.
			await get_tree().create_timer(1.6, true, false, true).timeout
		&"finale":
			# Ворота пропускаем, Тирана — сразу на колени: дальше игра сама ведёт к финалу.
			game.start_stage(RunState.stage)
			cs.skip()
			await game.boss_director.intro_finished
			game.hud.show_banner("", "")
			game.boss_director.boss.die()
			return
	leave()


## Сцены между этапами идут под спокойную музыку и на полу только что пройденного этапа.
func _between_stages() -> void:
	game.arena.set_tint(RunState.current_threat().floor_tint)
	Audio.play_music(&"music_calm")


func _on_skip() -> void:
	_abort = _abort or Input.is_physical_key_pressed(KEY_ESCAPE)


## Сцена закончилась или её пропустили: следующая в очереди — или обратно в галерею.
func leave() -> void:
	if _left:
		return
	_left = true
	Engine.time_scale = 1.0
	game.hud.fade(true, 0.4)
	await get_tree().create_timer(0.45, true, false, true).timeout
	cursor += 1
	if _abort or not requested():
		close()
		get_tree().change_scene_to_file(GALLERY_SCENE)
		return
	prepare(queue[cursor])
	get_tree().change_scene_to_file(GAME_SCENE)


## Подпись в верхней полосе кадра: что за сцена и как выйти.
func _caption(entry: Dictionary, opts: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 13
	add_child(layer)
	var root := Control.new()
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(root)
	layer.add_child(root)
	var title: Array = CutsceneCatalog.title_of(entry, opts)
	var left := VBoxContainer.new()
	left.position = Vector2(28, 14)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override(&"separation", -2)
	root.add_child(left)
	var where := "Катсцены"
	if queue.size() > 1:
		where += " · %d из %d" % [cursor + 1, queue.size()]
	left.add_child(UiKit.label(where, 15, Color(UiKit.MUTED, 0.9)))
	left.add_child(UiKit.label("%s — %s" % [title[0], title[1]] if title[1] != "" else str(title[0]), 26, Color(UiKit.GOLD, 0.9)))
	var hint := "удерживайте Esc — выйти в галерею"
	if queue.size() > 1:
		hint = "удерживайте Пробел — к следующей сцене · Esc — выйти в галерею"
	var right := UiKit.label(hint, 15, Color(UiKit.MUTED, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -900
	right.offset_right = -28
	right.offset_top = 18
	right.offset_bottom = 44
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
