extends Node
## Драйвер скриншотов: готовит состояние по пресету, ждёт delay секунд, сохраняет кадр.
## every=N — серия кадров каждые N секунд до delay (раскадровка сюжетной сцены).
## preset=theater key=<ключ сцены> — сцена из меню «Катсцены» (ключи — в CutsceneCatalog: hearth, temptation,
## gift_3, palace_5 …); preset=cutscenes — само меню, key — выбранная в нём сцена. speed=N ускоряет время.

var _preset := "game"
var _out := "user://shot.png"
var _delay := 3.0
## Серия: кадр каждые every секунд до delay — out_<секунда>.png (раскадровка сцены за один прогон).
var _every := 0.0
var _next_shot := 0.0
## Ключ сцены каталога для пресетов theater и cutscenes.
var _key := "hearth"
var _speed := 1.0
var _t := 0.0
var _setup_done := false
var _hovered := false
var _card_view := ""
var _item := ""
var _tier := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"preset": _preset = kv[1]
			"render": Render.set_mode(Render.Mode.PS2 if kv[1] == "ps2" else Render.Mode.PS1, false)
			"out": _out = kv[1]
			"delay": _delay = float(kv[1])
			"every": _every = float(kv[1])
			"variant": SkinnedActorModel.select(kv[1])
			"key": _key = kv[1]
			"speed": _speed = float(kv[1])
			"card": _card_view = kv[1]
			"item": _item = kv[1]
			"tier": _tier = int(kv[1])
	if _preset in ["final_mastery", "final_empty", "final_max", "final_error", "mastery_mixed", "mastery_empty"]:
		Mastery.memory_only = true
		Mastery.xp.clear()
		Mastery.choices.clear()
		var starts := [210, 440, 900, 1000, 10, 620, 200]
		for i in Db.ITEM_IDS.size():
			var id := Db.ITEM_IDS[i]
			Mastery.xp[id] = 0 if _preset in ["final_empty", "mastery_empty"] else 1000 if _preset == "final_max" else starts[i]
	if _preset == "mastery":
		Mastery.memory_only = true
		for id in Db.ITEM_IDS:
			Mastery.xp[id] = 1000
			Mastery.choices[id] = 3
	RunState.new_run(424242)
	# Сюжетные сцены — только в сюжетных пресетах; остальные снимают игру как раньше.
	var story := _preset in ["prologue", "gift", "gates", "finale"]
	RunState.skip_cutscenes = not story
	if story:
		Render.cutscenes = true
	var scene := "res://scenes/game.tscn"
	match _preset:
		"gift":
			RunState.sacrifice(0)
			RunState.stage = 2
		"gates", "finale":
			for i in 6:
				RunState.sacrifice(0)
			RunState.stage = 7
		"menu", "mastery", "mastery_mixed", "mastery_empty":
			scene = "res://scenes/main_menu.tscn"
		"cutscenes":
			Theater.last_key = _key
			scene = Theater.GALLERY_SCENE
		"theater":
			var items: Array[Dictionary] = [{"key": _key, "opts": CutsceneCatalog.resolve(CutsceneCatalog.find(_key))}]
			Theater.queue = items
			Theater.cursor = 0
			Theater.prepare(items[0])
		"final", "final_death", "final_mastery", "final_empty", "final_max", "final_error":
			var is_victory := _preset in ["final", "final_mastery", "final_max", "final_error"]
			for i in (0 if _preset == "final_empty" else 6 if is_victory else 3):
				RunState.sacrifice(0)
			if _preset in ["final_mastery", "final_max", "final_error"]:
				var rewards := [110, 330, 420, 210, 185, 380, 45]
				for i in Db.ITEM_IDS.size():
					var id := Db.ITEM_IDS[i]
					Mastery.run_xp[id] = rewards[i]
					Mastery.xp[id] = mini(int(Mastery.xp[id]) + rewards[i], 1000)
					Mastery.choices[id] = Mastery.level(id)
				for item in RunState.ring.items:
					item.appearance = Mastery.selected(item.def_id)
			Mastery.save_error = _preset == "final_error"
			RunState.outcome = RunState.Outcome.VICTORY if is_victory else RunState.Outcome.DEATH
			RunState.stage = 7 if is_victory else 1 if _preset == "final_empty" else 4
			RunState.elapsed = 1043.0
			RunState.running = false
			scene = "res://scenes/final_card.tscn"
		"boss", "boss_fight":
			for i in 6:
				RunState.sacrifice(0)
			RunState.stage = 7
		"stage4", "tree":
			for i in 3:
				RunState.sacrifice(0)
			RunState.stage = 4
		"gallery":
			scene = "res://tools/gallery.tscn"
		"vfx":
			scene = "res://tools/vfx_test.tscn"
	get_tree().change_scene_to_file.call_deferred(scene)


func _game() -> Game:
	return get_tree().get_first_node_in_group(&"game") as Game


func _setup() -> void:
	if _preset.begins_with("final"):
		var card := get_tree().current_scene
		if _item != "":
			card._wheel.select_item(StringName(_item))
		if _card_view == "details":
			card._open_details()
		elif _card_view == "collection":
			card._open_collection()
			if _tier > 0:
				card._modal._inspect_tier(_tier)
		return
	if _preset in ["mastery", "mastery_mixed", "mastery_empty"]:
		var collection := MasteryUi.new()
		if _item != "":
			collection.selected_id = StringName(_item)
		get_tree().current_scene.ui.add_child(collection)
		if _tier > 0:
			collection._inspect_tier(_tier)
		return
	var g := _game()
	if g == null:
		return
	match _preset:
		"altar":
			g.debug_skip_stage()
		"tree":
			g.hud.toggle_tree()
		"shrine":
			g.hud.open_shrine()
		"gift":
			g.debug_skip_stage()
		"finale":
			# Ворота пропускаем, Тирана — сразу на колени.
			g.cutscene.skip()


func _process(delta: float) -> void:
	if _speed != 1.0:
		Engine.time_scale = _speed
	_t += delta
	if not _setup_done and _t > 1.0:
		_setup_done = true
		_setup()
	var g := _game()
	if _preset == "gift" and g != null:
		if g.state == Game.State.CLEARED and g.altar != null and g.altar.active:
			g.hero.global_position = Vector3(0, 0, 0)
			g._on_altar_stepped()
		if g.hud.has_screen() and g.hud._screen is AltarUi:
			g.hud._on_altar_confirmed(0)
	if _preset == "finale" and g != null and _t > 2.0 and g.state == Game.State.BOSS:
		var b := g.boss_director.boss
		if b != null and not b.dead:
			b.die()
	if _preset == "altar" and g != null:
		if g.state == Game.State.CLEARED and g.altar != null and g.altar.active:
			g.hero.global_position = Vector3(0, 0, 3)
			g._on_altar_stepped()
		if not _hovered and g.hud.has_screen() and _t > _delay - 0.5:
			_hovered = true
			var ui := g.hud._screen as AltarUi
			if ui != null:
				if ui._tutorial != null:
					ui._tutorial.queue_free()
				ui.ring.hover_index = 0
				ui._on_hover(0)
	if _every > 0.0 and _t >= _next_shot + _every:
		_next_shot += _every
		# Номер кадра — секунды; при шаге короче секунды — десятые доли, иначе кадры затирали бы друг друга.
		var stamp := int(round(_next_shot)) if _every >= 1.0 else int(round(_next_shot * 10.0))
		var path := "%s_%03d.png" % [_out.get_basename(), stamp]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	if _t >= _delay:
		if _every <= 0.0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_out)
			print("saved ", _out)
		get_tree().quit()
