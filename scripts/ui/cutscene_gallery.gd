extends Control
## Меню «Катсцены»: все сюжетные сцены по порядку забега. Слева — лента сцен по этапам; справа —
## выбранная сцена: когда она идёт, что в ней происходит, от чего зависит и кто в ней участвует,
## её варианты (какая вещь отдана, у кого оберег и перстень) и просмотр — одной сцены или подряд
## до конца истории. Показ ведёт Theater: сцена идёт в настоящей игре и возвращает сюда.
## В шапке — переключатель, идут ли сцены в забеге (сам просмотр отсюда работает всегда).

const MENU_SCENE := "res://scenes/main_menu.tscn"
const LIST_WIDTH := 470.0
const CAST_SIZE := Vector2(420, 236)
const SUBTITLE := "Вся история по порядку забега — %d сцен. %s"
const STORY_ON := "В забеге они идут."
const STORY_OFF := "В забеге они выключены, здесь — идут."
const HINT := "W / S или стрелки — выбор сцены  ·  Enter — смотреть  ·  Esc — назад        В сцене: ЛКМ, Пробел или Enter — следующая реплика  ·  удерживать Пробел — пропустить  ·  удерживать Esc — вернуться сюда"

## Варианты, выбранные зрителем: ключ сцены -> { ключ варианта: значение }. Переживают просмотр.
static var _chosen: Dictionary = {}

var ui: Control
var _entries: Array[Dictionary] = []
var _index: int = 0
var _rows: Array[Button] = []
var _scroll: ScrollContainer
var _detail: VBoxContainer
var _subtitle: Label
var _story_button: Button


func _ready() -> void:
	theme = UiKit.theme()
	get_tree().paused = false
	Engine.time_scale = 1.0
	_entries = CutsceneCatalog.entries()
	_build_background()
	# Интерфейс — на слое поверх ретро-постобработки, чтобы текст оставался чётким.
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui = Control.new()
	ui.theme = UiKit.theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(ui)
	ui_layer.add_child(ui)
	var margin := MarginContainer.new()
	UiKit.full_rect(margin)
	margin.add_theme_constant_override(&"margin_left", 56)
	margin.add_theme_constant_override(&"margin_right", 56)
	margin.add_theme_constant_override(&"margin_top", 26)
	margin.add_theme_constant_override(&"margin_bottom", 22)
	ui.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 12)
	margin.add_child(page)
	page.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 20)
	page.add_child(body)
	body.add_child(_build_list())
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override(&"separation", 10)
	panel.add_child(_detail)
	page.add_child(UiKit.label(HINT, 14, Color(UiKit.MUTED, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	_select(maxi(_index_of(Theater.last_key), 0))
	Audio.play_music(&"music_menu")


func _build_background() -> void:
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.15, 0.1, 0.11))
	grad.set_color(1, Color(0.02, 0.018, 0.025))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.62, 0.42)
	tex.fill_to = Vector2(1.3, 1.1)
	tex.width = 256
	tex.height = 256
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	UiKit.full_rect(bg)
	add_child(bg)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override(&"separation", -6)
	titles.add_child(UiKit.outlined(UiKit.label("Катсцены", 48, UiKit.GOLD), 8))
	# Строка обрезается, а не растягивает шапку: иначе длинный текст вытолкнул бы кнопки за край экрана.
	_subtitle = UiKit.label("", 18, UiKit.MUTED)
	_subtitle.clip_text = true
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(_subtitle)
	row.add_child(titles)
	_story_button = UiKit.button("", _toggle_story)
	for b in [_story_button, UiKit.button("Смотреть всю историю", _play_from.bind(0)), UiKit.button("Назад", _back)]:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size = Vector2(0, 50)
		row.add_child(b)
	_update_story()
	return row


## Идут ли сюжетные сцены в забеге. Та же настройка, что в паузе; просмотр из этого меню от неё не зависит.
func _toggle_story() -> void:
	Render.set_cutscenes(not Render.cutscenes)
	_update_story()


func _update_story() -> void:
	_story_button.text = "Сцены в забеге: %s" % ("вкл" if Render.cutscenes else "выкл")
	_subtitle.text = SUBTITLE % [_entries.size(), STORY_ON if Render.cutscenes else STORY_OFF]


## Лента сцен: заголовки этапов и строки сцен по порядку забега.
func _build_list() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 3)
	_scroll.add_child(list)
	var group := ButtonGroup.new()
	var last_group := ""
	for i in _entries.size():
		var e := _entries[i]
		if e["group"] != last_group:
			last_group = e["group"]
			var head := UiKit.label(last_group, 14, UiKit.GOLD.darkened(0.25))
			head.custom_minimum_size = Vector2(0, 30 if i > 0 else 20)
			head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			list.add_child(head)
		var row := UiKit.button(_row_text(i), _select.bind(i))
		row.toggle_mode = true
		row.button_group = group
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.clip_text = true
		_compact(row, 17)
		list.add_child(row)
		_rows.append(row)
	return panel


## Плотная кнопка основным шрифтом: строки ленты и варианты сцены.
func _compact(b: Button, font_size: int) -> void:
	b.add_theme_font_override(&"font", UiKit.body_font())
	b.add_theme_font_size_override(&"font_size", font_size)
	b.add_theme_stylebox_override(&"normal", UiKit.box(Color(0.08, 0.06, 0.065, 0.7), UiKit.BORDER.darkened(0.45), 1, 2, 10))
	b.add_theme_stylebox_override(&"hover", UiKit.box(Color(0.16, 0.06, 0.05), UiKit.DANGER.darkened(0.25), 1, 2, 10))
	b.add_theme_stylebox_override(&"pressed", UiKit.box(Color(0.26, 0.08, 0.05), UiKit.GOLD.darkened(0.15), 1, 2, 10))
	b.add_theme_stylebox_override(&"disabled", UiKit.box(Color(0.06, 0.05, 0.05), Color(0.2, 0.18, 0.18), 1, 2, 10))


func _row_text(i: int) -> String:
	var e := _entries[i]
	var title: Array = CutsceneCatalog.title_of(e, _opts(e))
	var text := "%d.  %s" % [i + 1, title[0]]
	if title[1] != "":
		text += " — %s" % title[1]
	return text


func _index_of(key: String) -> int:
	for i in _entries.size():
		if _entries[i]["key"] == key:
			return i
	return -1


## Варианты сцены: выбор зрителя поверх значений по умолчанию.
func _opts(e: Dictionary) -> Dictionary:
	return CutsceneCatalog.resolve(e, _chosen.get(e["key"], {}))


# --- Выбранная сцена --------------------------------------------------------

func _select(i: int) -> void:
	_index = i
	_rows[i].button_pressed = true
	_show()
	_reveal(_rows[i])


## Прокручивает ленту к строке. Ждёт кадр: сразу после постройки у ленты ещё нет размеров.
func _reveal(row: Button) -> void:
	await get_tree().process_frame
	if is_instance_valid(row):
		_scroll.ensure_control_visible(row)


func _show() -> void:
	for ch in _detail.get_children():
		_detail.remove_child(ch)
		ch.queue_free()
	var e := _entries[_index]
	var opts := _opts(e)
	var title: Array = CutsceneCatalog.title_of(e, opts)
	var gold := UiKit.hex(UiKit.GOLD)
	# Шапка: слева — что это за сцена и когда она идёт, справа — действующие лица.
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 22)
	_detail.add_child(top)
	var head := VBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_constant_override(&"separation", 2)
	top.add_child(head)
	head.add_child(UiKit.label("Сцена %d из %d  ·  %s" % [_index + 1, _entries.size(), e["group"]], 15, UiKit.MUTED))
	head.add_child(UiKit.outlined(UiKit.label(title[0], 44, UiKit.GOLD), 6))
	if title[1] != "":
		head.add_child(UiKit.label(title[1], 23, UiKit.TEXT))
	var line := ColorRect.new()
	line.color = UiKit.BLOOD
	line.custom_minimum_size = Vector2(0, 2)
	head.add_child(line)
	var when: String = e["when"]
	var duration := CutsceneCatalog.duration_text(e["seconds"])
	if duration != "":
		when += " Идёт %s." % duration
	head.add_child(_text(_section("Когда", when, gold) + "\n\n" + _section("Что происходит", e["about"], gold)))
	# Справа — действующие лица и ключевая реплика сцены.
	var side := _add_cast(top, CutsceneCatalog.cast_of(e, opts))
	var quote: Array = CutsceneCatalog.quote_of(e, opts)
	if not quote.is_empty() and quote[1] != "":
		var sp := Story.speaker(quote[0])
		side.add_child(_text("\n«%s»\n— [color=#%s]%s[/color]" % [quote[1], UiKit.hex(sp["color"]), sp["name"]], 16))
	# Логика сцены; если текста много — прокручивается.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail.add_child(scroll)
	var bullets := PackedStringArray()
	for l in e["logic"]:
		bullets.append("—  " + l)
	scroll.add_child(_text(_section("Логика", "\n".join(bullets), gold)))
	for o in e["options"]:
		_detail.add_child(_option_row(e, o, opts))
	_detail.add_child(_actions(e))


func _section(title: String, body: String, gold: String) -> String:
	return "[color=#%s][b]%s[/b][/color]\n%s" % [gold, title, body]


func _text(bbcode: String, font_size: int = 17) -> RichTextLabel:
	var t := UiKit.rich(bbcode, font_size)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_constant_override(&"line_separation", 3)
	return t


## Действующие лица: модели в ряд и подписи под ними. Витрина заполняется уже в дереве сцены —
## актёрам нужен мир, в котором они стоят. Возвращает колонку: под подписи можно добавить текст.
func _add_cast(parent: Control, whos: Array[StringName]) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(CAST_SIZE.x, 0)
	box.add_theme_constant_override(&"separation", 2)
	parent.add_child(box)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.025, 0.02, 0.03, 0.9), Color(UiKit.BORDER, 0.55), 1, 2, 0))
	box.add_child(frame)
	var stage := ItemShowcase.new()
	stage.custom_minimum_size = CAST_SIZE
	frame.add_child(stage)
	stage.show_cast(whos, CAST_SIZE.x / CAST_SIZE.y)
	var names := HBoxContainer.new()
	names.add_theme_constant_override(&"separation", 0)
	box.add_child(names)
	for who in whos:
		var sp := Story.speaker(who)
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override(&"separation", -3)
		var name_label := UiKit.label(sp["name"], 16, sp["color"], HORIZONTAL_ALIGNMENT_CENTER)
		name_label.clip_text = true
		cell.add_child(name_label)
		var role := UiKit.label(str(sp.get("role", "")), 12, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role.custom_minimum_size = Vector2(10, 0)
		cell.add_child(role)
		names.add_child(cell)
	return box


## Вариант сцены: подпись и кнопки значений, выбранное подсвечено.
func _option_row(e: Dictionary, o: Dictionary, opts: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var caption := UiKit.label("%s:" % o["label"], 17, UiKit.MUTED)
	caption.custom_minimum_size = Vector2(0, 34)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	var group := ButtonGroup.new()
	for c in o["choices"]:
		var chip := UiKit.button(c[1], _choose.bind(e["key"], o["key"], c[0]))
		chip.toggle_mode = true
		chip.button_group = group
		chip.button_pressed = opts[o["key"]] == c[0]
		_compact(chip, 16)
		row.add_child(chip)
	return row


func _choose(key: String, option: String, value: Variant) -> void:
	if not _chosen.has(key):
		_chosen[key] = {}
	_chosen[key][option] = value
	_rows[_index].text = _row_text(_index)
	_show()


func _actions(e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	if not e["playable"]:
		var off := UiKit.button("Только в забеге", func(): pass)
		off.disabled = true
		off.custom_minimum_size = Vector2(300, 54)
		row.add_child(off)
		return row
	var play := UiKit.button("Смотреть сцену", _play_one)
	play.custom_minimum_size = Vector2(300, 54)
	row.add_child(play)
	if _items_from(_index).size() > 1:
		var rest := UiKit.button("Смотреть подряд отсюда", _play_from.bind(_index))
		rest.custom_minimum_size = Vector2(0, 54)
		row.add_child(rest)
	return row


# --- Просмотр ---------------------------------------------------------------

## Сцены для показа подряд: все, что можно посмотреть отдельно, начиная с i-й.
func _items_from(i: int) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for k in range(i, _entries.size()):
		var e := _entries[k]
		if e["playable"]:
			items.append({"key": e["key"], "opts": _opts(e)})
	return items


func _play_one() -> void:
	var e := _entries[_index]
	if not e["playable"]:
		return
	var items: Array[Dictionary] = [{"key": e["key"], "opts": _opts(e)}]
	Theater.open(get_tree(), items)


func _play_from(i: int) -> void:
	Theater.open(get_tree(), _items_from(i))


func _back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_back()
	elif event.is_action_pressed(&"move_down", true):
		_select(mini(_index + 1, _entries.size() - 1))
	elif event.is_action_pressed(&"move_up", true):
		_select(maxi(_index - 1, 0))
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_play_one()
	else:
		return
	get_viewport().set_input_as_handled()
