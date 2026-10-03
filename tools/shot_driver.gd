extends Node
## Драйвер скриншотов: готовит состояние по пресету, ждёт delay секунд, сохраняет кадр.

var _preset := "game"
var _out := "user://shot.png"
var _delay := 3.0
var _t := 0.0
var _setup_done := false
var _hovered := false
var _card_view := ""
var _item := ""
var _tier := 0
var _node := 0


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
			"card": _card_view = kv[1]
			"item": _item = kv[1]
			"tier": _tier = int(kv[1])
			"node": _node = int(kv[1])
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
	if _preset.begins_with("tree"):
		Mastery.memory_only = true
		for id in Db.ITEM_IDS:
			Mastery.xp[id] = 1000
			Mastery.choices[id] = 3
	RunState.new_run(424242)
	var scene := "res://scenes/game.tscn"
	match _preset:
		"menu", "rules", "mastery", "mastery_mixed", "mastery_empty":
			scene = "res://scenes/main_menu.tscn"
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
		"boss", "boss_fight", "tree_full":
			for i in 6:
				RunState.sacrifice(0)
			RunState.stage = 7
		"stage4", "tree":
			for i in 3:
				RunState.sacrifice(0)
			RunState.stage = 4
		"tree_branch":
			RunState.ring = Ring.from_ids([&"shield", &"boots", &"sword", &"armor", &"helmet", &"gloves", &"amulet"])
			for item in RunState.ring.items:
				item.appearance = Mastery.selected(item.def_id)
			for id in [&"shield", &"boots", &"helmet", &"armor", &"sword", &"amulet"]:
				RunState.sacrifice(RunState.ring.index_of(id))
			RunState.stage = 7
		"gallery":
			scene = "res://tools/gallery.tscn"
	get_tree().change_scene_to_file.call_deferred(scene)


func _game() -> Game:
	return get_tree().get_first_node_in_group(&"game") as Game


func _setup() -> void:
	if _preset == "rules":
		get_tree().current_scene._toggle_rules()
		return
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
		"tree", "tree_start", "tree_full", "tree_branch":
			g.hud.toggle_tree()
			if _item != "":
				g.hud._screen.select_item(StringName(_item))
			if _node > 0:
				g.hud._screen._diagram.select_node(_node)
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
