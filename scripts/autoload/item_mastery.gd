extends Node
## Постоянный опыт по типу вещи. Снимки и свойства не являются носителями XP.

signal changed
signal unlocked(item_id: StringName, level: int)
signal progress_reset

const SAVE_PATH := "user://item_mastery.cfg"
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_mastery.json"))
var xp: Dictionary = {}
var choices: Dictionary = {}
var run_xp: Dictionary = {}
## Снимок до забега: вычитать run_xp из XP нельзя из-за ограничения на максимуме.
var run_start_xp: Dictionary = {}
var memory_only: bool = false
var save_error: bool = false


func _ready() -> void:
	memory_only = OS.get_environment("GODOT_META_MEMORY") == "1" or "--meta-memory" in OS.get_cmdline_user_args()
	if not memory_only:
		load_progress()


func level(id: StringName) -> int:
	var total := int(xp.get(id, 0))
	var thresholds: Array = rules["thresholds"]
	for i in range(thresholds.size() - 1, -1, -1):
		if total >= int(thresholds[i]):
			return i + 1
	return 1


func selected(id: StringName) -> int:
	return clampi(int(choices.get(id, level(id))), 1, level(id))


func begin_run() -> void:
	run_xp.clear()
	run_start_xp = xp.duplicate()


func form(id: StringName, tier: int) -> Dictionary:
	return rules["items"][String(id)][clampi(tier, 1, 3) - 1]


func choose(id: StringName, tier: int) -> void:
	if not id in Db.ITEM_IDS or tier < 1 or tier > level(id):
		return
	choices[id] = tier
	save_progress()
	changed.emit()


func reward(id: StringName, stage: int, elite: bool = false) -> int:
	var base := int(rules["rewards"].get(String(id), 0))
	return roundi(base * (1.0 + float(rules["stage_bonus"]) * maxi(stage - 1, 0)) * (float(rules["elite_multiplier"]) if elite else 1.0))


func award(hero: Actor, amount: int) -> void:
	if amount <= 0:
		return
	var upgraded := false
	var seen: Dictionary = {}
	for item in hero.items:
		var id := item.def_id
		if seen.has(id):
			continue
		seen[id] = true
		var previous := level(id)
		xp[id] = mini(int(xp.get(id, 0)) + amount, int(rules["thresholds"].back()))
		run_xp[id] = int(run_xp.get(id, 0)) + amount
		var current := level(id)
		if current > previous:
			choices[id] = current
			item.appearance = current
			var comp := hero.component(id)
			if comp != null:
				comp.def = item.def()
				if id == &"armor":
					var new_max: float = comp.def.stat("armor", 50.0)
					hero.armor += maxf(new_max - hero.max_armor, 0.0)
					hero.max_armor = new_max
				if comp is ShieldAction and comp.holding:
					hero.block_arc_degrees = comp.def.stat("arc", 120.0)
			upgraded = true
			unlocked.emit(id, current)
	if upgraded:
		hero.items_changed.emit()
		hero.health_changed.emit()
	save_progress()
	changed.emit()


func progress_text(id: StringName) -> String:
	var lv := level(id)
	if lv == 3:
		return "Ур. 3 · МАКС"
	return "Ур. %d · %d / %d XP" % [lv, int(xp.get(id, 0)), int(rules["thresholds"][lv])]


## Отладочный сброс: новый пустой профиль, включая резервную копию.
func reset_progress(path: String = SAVE_PATH) -> bool:
	xp.clear()
	choices.clear()
	run_xp.clear()
	run_start_xp.clear()
	save_error = false
	var saved := save_progress(path)
	if saved and not memory_only:
		var err := DirAccess.copy_absolute(path, path + ".bak")
		save_error = err != OK
		if save_error:
			push_warning("Не удалось сбросить резервную копию опыта: %s" % error_string(err))
		saved = not save_error
	# Прошедший забег и снимки жертв сохраняют свои облики; текущий герой — нет.
	# Катсцена временно останавливает running, но не завершает настоящий забег.
	var ongoing_scene := RunState.outcome == RunState.Outcome.NONE and not Theater.requested() and get_tree().get_first_node_in_group(&"game") != null
	if RunState.running or ongoing_scene:
		for item in RunState.ring.items:
			item.appearance = 1
		var hero := Combat.hero
		if is_instance_valid(hero):
			for item in hero.items:
				item.appearance = 1
				var comp := hero.component(item.def_id)
				if comp == null:
					continue
				comp.def = item.def()
				if item.def_id == &"armor":
					var capacity := float(comp.def.stat("armor", 50.0))
					hero.armor = clampf(hero.armor + capacity - hero.max_armor, 0.0, capacity)
					hero.max_armor = capacity
				if comp is ShieldAction and comp.holding:
					hero.block_arc_degrees = comp.def.stat("arc", 120.0)
			hero.items_changed.emit()
			hero.health_changed.emit()
		RunState.ring_changed.emit()
	progress_reset.emit()
	changed.emit()
	return saved


func load_progress(path: String = SAVE_PATH) -> void:
	xp.clear()
	choices.clear()
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK or int(cfg.get_value("meta", "version", 0)) != 1:
		if cfg.load(path + ".bak") != OK or int(cfg.get_value("meta", "version", 0)) != 1:
			return
	for id in Db.ITEM_IDS:
		var value: Variant = cfg.get_value("xp", String(id), 0)
		if value is int:
			xp[id] = clampi(value, 0, int(rules["thresholds"].back()))
		var choice: Variant = cfg.get_value("appearance", String(id), level(id))
		if choice is int:
			choices[id] = clampi(choice, 1, level(id))


func save_progress(path: String = SAVE_PATH) -> bool:
	if memory_only:
		return true
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	for id in Db.ITEM_IDS:
		cfg.set_value("xp", String(id), int(xp.get(id, 0)))
		cfg.set_value("appearance", String(id), selected(id))
	var err := cfg.save(path + ".tmp")
	if err == OK and FileAccess.file_exists(path):
		err = DirAccess.copy_absolute(path, path + ".bak")
	if err == OK:
		err = DirAccess.rename_absolute(path + ".tmp", path)
	save_error = err != OK
	if save_error:
		push_warning("Не удалось сохранить опыт вещей: %s" % error_string(err))
	return not save_error
