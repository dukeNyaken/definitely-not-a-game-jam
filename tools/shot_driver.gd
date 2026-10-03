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
	if _preset == "mastery":
		Mastery.memory_only = true
		for id in Db.ITEM_IDS:
			Mastery.xp[id] = 1000
			Mastery.choices[id] = 3
	RunState.new_run(424242)
	var scene := "res://scenes/game.tscn"
	match _preset:
		"menu", "mastery":
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
	if _preset == "mastery":
		get_tree().current_scene.ui.add_child(MasteryUi.new())
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


func _process(delta: float) -> void:
	_t += delta
	if not _setup_done and _t > 1.0:
		_setup_done = true
		_setup()
	var g := _game()
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
