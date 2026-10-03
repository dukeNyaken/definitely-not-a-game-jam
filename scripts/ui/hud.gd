class_name Hud
extends CanvasLayer
## Игровой интерфейс: здоровье и броня, сид, действия, баннеры, экраны.

const SLOT_ORDER: Array[StringName] = [&"sword", &"shield", &"boots", &"gloves", &"amulet", &"armor", &"helmet"]

var game: Game
var root: Control
var overlay: WorldOverlay
var _hp_bar: Control
var _stage_label: Label
var _wave_label: Label
var _seed_label: Label
var _speed_label: Label
var _slots: Dictionary = {}
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _boss_bar: Control
var _hint: PanelContainer
var _fade: ColorRect
var _screen: Control
var _screen_kind: StringName = &""
## Части интерфейса, которые прячутся в сюжетных сценах.
var _status_box: Control
var _ring_panel: Control
var _action_bar: Control
var _cinematic_tween: Tween
## Чёрные полосы вступления босса (без сюжетных сцен).
var _bars: Array[ColorRect] = []


func setup(p_game: Game) -> void:
	game = p_game
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(root)
	add_child(root)
	overlay = WorldOverlay.new()
	root.add_child(overlay)
	_build_status()
	_build_tree_hint()
	_build_actions()
	_build_banner()
	_build_boss_bar()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_fade)
	root.add_child(_fade)
	game.banner.connect(show_banner)
	game.wave_started.connect(_on_wave_started)
	game.state_changed.connect(_on_state_changed)
	game.hero.health_changed.connect(_hp_bar.queue_redraw)


# --- Постройка --------------------------------------------------------------

func _build_status() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(24, 20)
	box.add_theme_constant_override(&"separation", 6)
	root.add_child(box)
	_status_box = box
	_stage_label = UiKit.outlined(UiKit.label("", 24, UiKit.GOLD))
	box.add_child(_stage_label)
	_hp_bar = Control.new()
	_hp_bar.custom_minimum_size = Vector2(340, 34)
	_hp_bar.draw.connect(_draw_hp)
	box.add_child(_hp_bar)
	_wave_label = UiKit.outlined(UiKit.label("", 18, UiKit.TEXT))
	box.add_child(_wave_label)
	_speed_label = UiKit.outlined(UiKit.label("", 16, UiKit.MUTED))
	box.add_child(_speed_label)


func _draw_hp() -> void:
	var h := game.hero
	var w := _hp_bar.size.x
	_hp_bar.draw_rect(Rect2(0, 8, w, 22), Color(0, 0, 0, 0.7))
	_hp_bar.draw_rect(Rect2(2, 10, (w - 4) * clampf(h.hp / h.max_hp, 0, 1), 18), UiKit.HP)
	if h.max_armor > 0.0:
		_hp_bar.draw_rect(Rect2(0, 0, w * 0.7, 7), Color(0, 0, 0, 0.7))
		_hp_bar.draw_rect(Rect2(1, 1, (w * 0.7 - 2) * clampf(h.armor / h.max_armor, 0, 1), 5), UiKit.ARMOR)
	var font := _hp_bar.get_theme_default_font()
	var text := "%d / %d" % [ceili(h.hp), int(h.max_hp)]
	if h.max_armor > 0.0:
		text += "   броня %d" % ceili(h.armor)
	_hp_bar.draw_string_outline(font, Vector2(10, 25), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
	_hp_bar.draw_string(font, Vector2(10, 25), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.TEXT)


func _build_tree_hint() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	v.offset_left = -260
	v.offset_right = -24
	v.offset_top = 20
	v.offset_bottom = 70
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)
	v.add_child(UiKit.outlined(UiKit.label("Tab — кольцо навыков", 17, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)))
	_seed_label = UiKit.outlined(UiKit.label("Сид %d" % RunState.seed_value, 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	v.add_child(_seed_label)


func _build_actions() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 8)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	_action_bar = bar
	for id in SLOT_ORDER:
		var def := Db.item(id)
		if id == &"armor":
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(16, 0)
			bar.add_child(sep)
		var s := ActionSlot.new()
		s.item_id = id
		s.actor = game.hero
		s.key_text = def.input_label
		if id == &"sword":
			s.fallback_text = "кулак"
		bar.add_child(s)
		_slots[id] = s
	bar.reset_size()
	bar.offset_left = -bar.size.x * 0.5
	bar.offset_right = bar.size.x * 0.5
	bar.offset_top = -bar.size.y - 14
	bar.offset_bottom = -14
	for comp in game.hero.components.values():
		(comp as ActionComponent).used.connect(_on_used.bind((comp as ActionComponent).def.id))


func _on_used(_ctx: ActionContext, id: StringName) -> void:
	if _slots.has(id):
		(_slots[id] as ActionSlot).flash()


func _build_banner() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_top = 150
	box.offset_left = -500
	box.offset_right = 500
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_banner_title = UiKit.outlined(UiKit.label("", 54, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 10)
	_banner_sub = UiKit.outlined(UiKit.label("", 24, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER), 6)
	box.add_child(_banner_title)
	box.add_child(_banner_sub)
	box.modulate.a = 0.0
	_banner_title.get_parent().set_meta(&"box", true)


func _build_boss_bar() -> void:
	_boss_bar = Control.new()
	_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.offset_left = -360
	_boss_bar.offset_right = 360
	_boss_bar.offset_top = 22
	_boss_bar.offset_bottom = 80
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.visible = false
	_boss_bar.draw.connect(_draw_boss_bar)
	root.add_child(_boss_bar)


func _draw_boss_bar() -> void:
	var bd := game.boss_director
	if bd == null or bd.boss == null or not is_instance_valid(bd.boss):
		return
	var b := bd.boss
	var w := _boss_bar.size.x
	var font := UiKit.title_font()
	var title := "%s — фаза %d" % [Story.TYRANT_NAME, bd.phase + 1]
	_boss_bar.draw_string_outline(font, Vector2(0, 20), title, HORIZONTAL_ALIGNMENT_CENTER, w, 28, 6, Color(0, 0, 0, 0.9))
	_boss_bar.draw_string(font, Vector2(0, 20), title, HORIZONTAL_ALIGNMENT_CENTER, w, 28, UiKit.GOLD)
	_boss_bar.draw_rect(Rect2(0, 28, w, 20), Color(0, 0, 0, 0.8))
	_boss_bar.draw_rect(Rect2(2, 30, (w - 4) * clampf(b.hp / b.max_hp, 0, 1), 16), Color(0.55, 0.05, 0.04))
	_boss_bar.draw_rect(Rect2(0, 28, w, 20), UiKit.BORDER, false, 1.0)
	if b.max_armor > 0.0:
		_boss_bar.draw_rect(Rect2(2, 50, (w - 4) * clampf(b.armor / b.max_armor, 0, 1), 4), UiKit.ARMOR)
	for th in Db.balance.boss_phase_thresholds:
		var x := 2 + (w - 4) * th
		_boss_bar.draw_line(Vector2(x, 28), Vector2(x, 48), UiKit.GOLD, 2.0)


# --- Обновление -------------------------------------------------------------

func _process(_delta: float) -> void:
	var s := RunState.stage
	if RunState.is_boss_stage():
		_stage_label.text = "Этап 7/7 · Босс"
	else:
		var threat := RunState.current_threat()
		_stage_label.text = "Этап %d/7 · %s" % [s, threat.display_name if threat != null else ""]
	var sac := RunState.sacrifices_count()
	_speed_label.text = "Скорость +%d%% · время %s" % [int(round(Db.balance.sacrifice_speed_bonus * sac * 100)), RunState.time_text()]
	_boss_bar.visible = game.state == Game.State.BOSS and game.boss_director != null and game.boss_director.boss != null
	if _boss_bar.visible:
		_boss_bar.queue_redraw()
	_hp_bar.queue_redraw()


func _on_wave_started(index: int, total: int) -> void:
	_wave_label.text = "Волна %d/%d" % [index + 1, total] if index < total - 1 else "Элитная волна"


func _on_state_changed(state: int) -> void:
	match state:
		Game.State.CLEARED:
			_wave_label.text = "Этап пройден — к алтарю"
		Game.State.SHRINE:
			_wave_label.text = "Святилище открыто"
		Game.State.BOSS_INTRO, Game.State.BOSS:
			_wave_label.text = ""
	if state != Game.State.INTRO and state != Game.State.WAVES and _hint != null and RunState.stage > 1:
		_hint.queue_free()
		_hint = null


## Сверху и снизу выезжают чёрные полосы (интерфейс прячет set_cinematic).
func letterbox(on: bool) -> void:
	if _bars.is_empty():
		for top in [true, false]:
			var bar := ColorRect.new()
			bar.color = Color(0, 0, 0, 1)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
			bar.offset_top = 0.0 if top else 0.0
			bar.offset_bottom = 0.0
			root.add_child(bar)
			root.move_child(bar, overlay.get_index() + 1)
			_bars.append(bar)
	var h := 96.0 if on else 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_bars[0], "offset_bottom", h, 0.6)
	tw.tween_property(_bars[1], "offset_top", -h, 0.6)


func show_banner(title: String, subtitle: String) -> void:
	var box := _banner_title.get_parent() as Control
	_banner_title.text = title
	_banner_sub.text = subtitle
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(box, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(2.0)
	_banner_tween.tween_property(box, "modulate:a", 0.0, 0.6)


func fade(to_black: bool, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0 if to_black else 0.0, duration)


## Сюжетная сцена: статус, кольцо, панель действий, подсказка, полоса босса и цифры над врагами уходят.
func set_cinematic(on: bool, duration: float = 0.4) -> void:
	if _cinematic_tween != null and _cinematic_tween.is_valid():
		_cinematic_tween.kill()
	_cinematic_tween = create_tween().set_parallel(true)
	var parts: Array[Control] = [_status_box, _ring_panel, _action_bar, _boss_bar, overlay]
	if _hint != null:
		parts.append(_hint)
	for c in parts:
		if c != null and is_instance_valid(c):
			_cinematic_tween.tween_property(c, "modulate:a", 0.0 if on else 1.0, duration)


func show_controls_hint() -> void:
	if _hint != null:
		return
	_hint = PanelContainer.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 20
	_hint.offset_bottom = -20
	_hint.offset_top = -290
	_hint.offset_right = 420
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := UiKit.rich(
		"[b][color=#%s]Управление[/color][/b]\n" % UiKit.hex(UiKit.GOLD) +
		"WASD — движение, мышь — направление\n" +
		"ЛКМ — меч (без меча — кулак)\n" +
		"ПКМ (держать) — щит\n" +
		"Пробел — рывок сапогами\n" +
		"Q — хват перчатками · E — волна амулета\n" +
		"Tab — дерево свойств · Esc — пауза\n" +
		"F2 — рендер PS1 / PS2", 17)
	text.custom_minimum_size = Vector2(380, 0)
	_hint.add_child(text)
	root.add_child(_hint)


# --- Экраны поверх игры -----------------------------------------------------

func has_screen() -> bool:
	return _screen != null and is_instance_valid(_screen)


func _open_screen(screen: Control, kind: StringName, pause: bool = true) -> void:
	close_screen()
	_screen = screen
	_screen_kind = kind
	root.add_child(screen)
	game.lock_input(true)
	if pause:
		get_tree().paused = true


func close_screen() -> void:
	if not has_screen():
		return
	var kind := _screen_kind
	_screen.queue_free()
	_screen = null
	_screen_kind = &""
	get_tree().paused = false
	game.lock_input(false)
	if kind == &"altar":
		game.altar_closed()


func open_altar() -> void:
	var ui := AltarUi.new()
	ui.confirmed.connect(_on_altar_confirmed)
	ui.cancelled.connect(close_screen)
	_open_screen(ui, &"altar")


func _on_altar_confirmed(index: int) -> void:
	_screen_kind = &""
	close_screen()
	game.do_sacrifice(index)


func open_shrine() -> void:
	var ui := ShrineUi.new()
	ui.finished.connect(func(swapped: bool):
		close_screen()
		game.shrine_done(swapped)
	)
	_open_screen(ui, &"shrine")


func toggle_tree() -> void:
	if _screen_kind == &"tree":
		close_screen()
	elif not has_screen():
		var ui := TreeUi.new()
		ui.actor = game.hero
		ui.close_requested.connect(close_screen)
		_open_screen(ui, &"tree")


func toggle_pause() -> void:
	if _screen_kind == &"pause":
		close_screen()
	elif has_screen():
		close_screen()
	else:
		var ui := PauseMenu.new()
		ui.resumed.connect(close_screen)
		_open_screen(ui, &"pause")


func _unhandled_input(event: InputEvent) -> void:
	if game.state == Game.State.OVER or game.state == Game.State.CUTSCENE:
		return
	if game.cutscene != null and game.cutscene.active:
		return
	if event.is_action_pressed(&"pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"tree"):
		toggle_tree()
		get_viewport().set_input_as_handled()
