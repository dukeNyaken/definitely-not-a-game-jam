extends Node
## Драйвер автопрохождения (загружается из tools/autoplay.gd после старта движка).

var _seed := 1234
var _speed := 4.0
var _immortal := true
var _pick := 0
var _t := 0.0
var _game: Node
var _bot_t := 0.0
var _stage_start := 0.0
var _stage_damage := 0.0
var _log: Array[String] = []
var _last_stage := 0
var _hooked_hero: Object
var _strafe := 1.0
var _status_t := 0.0
var _block_t := 0.0
var _shots: Array = []
var _shot_prefix := ""
var _start_stage := 1
var _cutscenes := false
var _threat := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.get_node("RunState")
	_start()


func _start() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"seed": _seed = int(kv[1])
			"speed": _speed = float(kv[1])
			"immortal": _immortal = kv[1] == "1"
			"pick": _pick = int(kv[1])
			"render": Render.set_mode(Render.Mode.PS2 if kv[1] == "ps2" else Render.Mode.PS1, false)
			"shots": _shots = Array(kv[1].split(",")).map(func(x): return float(x))
			"prefix": _shot_prefix = kv[1]
			"stage": _start_stage = int(kv[1])
			"cutscenes": _cutscenes = kv[1] == "1"
			"threat": _threat = kv[1]
	var rs = get_tree().root.get_node("RunState")
	rs.new_run(_seed)
	rs.debug_immortal = _immortal
	# Сюжетные сцены по умолчанию выключены (время прогона как раньше); cutscenes=1 проходит их тоже —
	# реплики уходят сами, ввода сцены не ждут.
	rs.skip_cutscenes = not _cutscenes
	for i in _start_stage - 1:
		rs.sacrifice(_pick % rs.ring.size())
	rs.stage = _start_stage
	if _threat != "" and _start_stage >= 2:
		rs.threat_order[_start_stage - 2] = StringName(_threat)
	get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")


func _process(delta: float) -> void:
	if _tick(delta):
		get_tree().quit()


func _tick(delta: float) -> bool:
	Engine.time_scale = _speed if not get_tree().paused else 1.0
	_t += delta
	var rs = get_tree().root.get_node("RunState")
	var scene := get_tree().current_scene
	if scene != null and scene.name == "FinalCard":
		_log.append("FINAL: outcome=%d stage=%d time=%s artifact=%s" % [rs.outcome, rs.stage, rs.time_text(), rs.artifact_name()])
		for l in _log:
			print(l)
		return true
	# С сюжетными сценами забег длиннее: сцены идут около десяти минут сверх боёв.
	if _t > 60.0 * (24.0 if _cutscenes else 14.0):
		print("TIMEOUT")
		for l in _log:
			print(l)
		return true
	_game = get_tree().get_first_node_in_group(&"game")
	if _game == null:
		return false
	var hero = _game.hero
	if hero != _hooked_hero:
		_hooked_hero = hero
		hero.damaged.connect(func(amount, _ctx): _stage_damage += amount)
	if rs.stage != _last_stage:
		if _last_stage > 0:
			_log.append("stage %d: %.0fs, damage taken %.0f" % [_last_stage, rs.elapsed - _stage_start, _stage_damage])
		_last_stage = rs.stage
		_stage_start = rs.elapsed
		_stage_damage = 0.0
	_drive(hero)
	if not _shots.is_empty() and _t >= float(_shots[0]):
		var at: float = _shots.pop_front()
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("%s_%03d.png" % [_shot_prefix, int(at)])
			print("shot ", at)
		if _shots.is_empty() and _shot_prefix != "":
			return true
	_status_t += delta
	if _status_t > 20.0:
		_status_t = 0.0
		var extra := ""
		if _game.boss_director != null and _game.boss_director.boss != null:
			var b = _game.boss_director.boss
			extra = " BOSS hp=%.0f phase=%d pos=%s items=%s inv=%.1f hero_items=%s" % [b.hp, _game.boss_director.phase, b.global_position, b.items.map(func(i): return i.def_id), b.invuln_time, hero.items.map(func(i): return i.def_id)]
		var kinds := {}
		for a in Combat.living_actors(get_tree()):
			if a.faction != hero.faction:
				var k: String = a.display_name
				kinds[k] = int(kinds.get(k, 0)) + 1
		print("t=%.0f stage=%d threat=%s state=%d wave=%d alive=%s hero_items=%s hp=%.0f%s" % [_t, rs.stage, rs.current_threat().id if rs.current_threat() != null else &"boss", _game.state, _game.wave, kinds, hero.items.map(func(i): return [i.def_id, i.properties.size()]), hero.hp, extra])
	return false


func _drive(hero) -> void:
	var g = _game
	var state: int = g.state
	# Сюжетную сцену бот не трогает: героя ведёт сцена.
	if g.cutscene != null and g.cutscene.active:
		return
	# Экраны: алтарь — жертвуем, святилище — отказываемся.
	if g.hud.has_screen():
		var ui = g.hud._screen
		if ui.has_method("_on_hover"):
			var rs = get_tree().root.get_node("RunState")
			var idx := clampi(_pick, 0, rs.ring.size() - 1)
			g.hud._on_altar_confirmed(idx)
		elif ui.has_signal("finished"):
			ui.finished.emit(false)
		else:
			g.hud.close_screen()
		return
	if hero.dead:
		return
	var target = null
	var best := 1e9
	for a in Combat.living_actors(get_tree()):
		if a.faction != hero.faction:
			var d: float = a.global_position.distance_to(hero.global_position)
			if d < best:
				best = d
				target = a
	if state == g.State.CLEARED and g.altar != null:
		hero.move_input = Combat.flat(g.altar.global_position - hero.global_position).normalized()
		if Combat.flat(g.altar.global_position - hero.global_position).length() < 0.5:
			hero.move_input = Vector3.ZERO
			if g.state == g.State.CLEARED:
				g._on_altar_stepped()
		return
	if target == null:
		hero.move_input = Vector3.ZERO
		return
	hero.aim_point = target.global_position
	var to: Vector3 = Combat.flat(target.global_position - hero.global_position)
	var want := 1.6 if hero.has_item(&"sword") else 1.2
	if best > want + target.body_radius:
		hero.move_input = to.normalized()
	else:
		hero.move_input = Vector3(-to.z, 0, to.x).normalized() * _strafe * 0.3
	hero.press(&"attack")
	# Щит: короткие поднятия, чтобы запускать дерево свойств щита.
	_block_t += 0.016
	if _block_t > 0.45:
		_block_t = 0.0
		hero.release(&"block")
		hero.press(&"block")
	elif _block_t > 0.12:
		hero.release(&"block")
	if best < 6.0:
		hero.press(&"grab")
	if best < 7.0:
		hero.press(&"volley")
	if randf() < 0.01:
		hero.press(&"dash")
		_strafe = -_strafe
