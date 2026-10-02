extends Node
## Драйвер скриншотов: готовит состояние по пресету, ждёт delay секунд, сохраняет кадр.

var _preset := "game"
var _out := "user://shot.png"
var _delay := 3.0
var _t := 0.0
var _setup_done := false
var _hovered := false


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
		"menu":
			scene = "res://scenes/main_menu.tscn"
		"final", "final_death":
			for i in (6 if _preset == "final" else 3):
				RunState.sacrifice(0)
			RunState.outcome = RunState.Outcome.VICTORY if _preset == "final" else RunState.Outcome.DEATH
			RunState.stage = 7 if _preset == "final" else 4
			RunState.elapsed = 1043.0
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
	get_tree().change_scene_to_file.call_deferred(scene)


func _game() -> Game:
	return get_tree().get_first_node_in_group(&"game") as Game


func _setup() -> void:
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
	if _t >= _delay:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		get_tree().quit()
