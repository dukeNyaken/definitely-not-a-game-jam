extends Control
## Главное меню.

var _seed_edit: LineEdit
var _rules: PanelContainer
var ui: Control
var _render_button: Button
var _hero_button: Button
var _showcase: ItemShowcase


func _ready() -> void:
	theme = UiKit.theme()
	get_tree().paused = false
	Engine.time_scale = 1.0
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.16, 0.11, 0.12))
	grad.set_color(1, Color(0.02, 0.018, 0.025))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.68, 0.5)
	tex.fill_to = Vector2(1.25, 1.1)
	tex.width = 256
	tex.height = 256
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	UiKit.full_rect(bg)
	add_child(bg)
	var showcase := ItemShowcase.new()
	_showcase = showcase
	showcase.self_pixelate = false
	showcase.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	showcase.offset_left = -900
	showcase.offset_right = -20
	showcase.offset_top = -380
	showcase.offset_bottom = 380
	add_child(showcase)
	var preview: Array[ItemState] = []
	for id in Db.ITEM_IDS:
		preview.append(ItemState.create(id))
	showcase.show_ring(preview)

	# Интерфейс — на слое поверх ретро-постобработки, чтобы текст оставался чётким.
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui = Control.new()
	ui.theme = UiKit.theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(ui)
	ui_layer.add_child(ui)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.offset_left = 110
	v.offset_right = 760
	v.offset_top = -300
	v.offset_bottom = 320
	v.add_theme_constant_override(&"separation", 16)
	ui.add_child(v)
	v.add_child(UiKit.outlined(UiKit.label("Только самое нужное", 64, UiKit.GOLD), 8))
	var line := ColorRect.new()
	line.color = UiKit.BLOOD
	line.custom_minimum_size = Vector2(620, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(line)
	v.add_child(UiKit.label("Семь вещей. Шесть жертв. Один предмет.", 26, UiKit.TEXT))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	v.add_child(spacer)
	var start := UiKit.button("Начать забег", _start)
	start.custom_minimum_size = Vector2(360, 58)
	start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(start)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override(&"separation", 10)
	seed_row.add_child(UiKit.label("Сид:", 20, UiKit.MUTED))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "случайный"
	_seed_edit.custom_minimum_size = Vector2(290, 44)
	_seed_edit.max_length = 9
	seed_row.add_child(_seed_edit)
	v.add_child(seed_row)
	_render_button = UiKit.button("", _toggle_render)
	_render_button.custom_minimum_size = Vector2(360, 50)
	_render_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(_render_button)
	_update_render_button()
	var story_btn := UiKit.button(Render.cutscenes_text(), func(): pass)
	story_btn.pressed.connect(func():
		Render.set_cutscenes(not Render.cutscenes)
		story_btn.text = Render.cutscenes_text()
	)
	story_btn.custom_minimum_size = Vector2(360, 50)
	story_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(story_btn)
	# Выбор героя — только если собран прототип сгенерированных героев (prototype/heroes.json).
	if SkinnedActorModel.available() and SkinnedActorModel.variants().size() > 1:
		_hero_button = UiKit.button("", _next_hero)
		_hero_button.custom_minimum_size = Vector2(360, 50)
		_hero_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(_hero_button)
		_update_hero_button()
	var how := UiKit.button("Как играть", _toggle_rules)
	how.custom_minimum_size = Vector2(360, 50)
	how.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(how)
	if OS.get_name() != "Web":
		var quit := UiKit.button("Выход", func(): get_tree().quit())
		quit.custom_minimum_size = Vector2(360, 50)
		quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(quit)
	var foot := UiKit.label("Геймджем «Только самое нужное» · Godot 4 · F2 — переключить рендер PS1/PS2", 15, Color(UiKit.MUTED, 0.7))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 24
	foot.offset_top = -40
	foot.offset_bottom = -14
	foot.offset_right = 900
	ui.add_child(foot)
	Audio.play_music(&"music_menu")


func _toggle_render() -> void:
	Render.toggle()
	_update_render_button()


func _update_render_button() -> void:
	_render_button.text = "Рендер: %s" % Render.mode_name()


func _next_hero() -> void:
	var list := SkinnedActorModel.variants()
	var i := list.find(SkinnedActorModel.current())
	SkinnedActorModel.select(list[(i + 1) % list.size()]["id"])
	_update_hero_button()
	_showcase.rebuild_hero()


func _update_hero_button() -> void:
	_hero_button.text = "Герой: %s" % SkinnedActorModel.current()["title"]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"render"):
		_update_render_button.call_deferred()


func _start() -> void:
	var text := _seed_edit.text.strip_edges()
	var s := int(text) if text.is_valid_int() else -1
	RunState.new_run(s)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _toggle_rules() -> void:
	if _rules != null:
		_rules.queue_free()
		_rules = null
		return
	_rules = PanelContainer.new()
	_rules.set_anchors_preset(Control.PRESET_CENTER)
	_rules.offset_left = -520
	_rules.offset_right = 520
	_rules.offset_top = -330
	_rules.offset_bottom = 330
	var v := VBoxContainer.new()
	_rules.add_child(v)
	var g := UiKit.hex(UiKit.GOLD)
	v.add_child(UiKit.rich(
		"[center][b][color=#%s]Как играть[/color][/b][/center]\n\n" % g +
		"Герой начинает забег с семью вещами: меч, щит, доспех, шлем, перчатки, сапоги, амулет. Они стоят по кольцу в случайном порядке.\n\n" +
		"[b]7 этапов.[/b] На этапах 1–6 — три волны врагов и элитная волна, затем алтарь жертвы. На 7-м — босс.\n\n" +
		"[b]Жертва.[/b] На алтаре вы навсегда отдаёте одну вещь. Её сила уходит соседу по стрелке и становится свойством: «событие соседа → сила жертвы». Например, щит в сапогах — «Неуязвимый рывок».\n\n" +
		"[b]Финал.[/b] Остаётся одна вещь — дерево всех ваших решений. А Тиран, старший брат героя, наденет всё, что вы отдали.\n\n" +
		"[b]Управление:[/b] WASD, мышь, ЛКМ / ПКМ / Пробел / Q / E — действия вещей, Tab — дерево свойств, Esc — пауза.", 20))
	var ok := UiKit.button("Закрыть", _toggle_rules)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)
	ui.add_child(_rules)
