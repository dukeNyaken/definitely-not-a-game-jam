class_name AltarUi
extends Control
## Кольцо слева, карточка последствий справа. Жертва — удержание ЛКМ 1 с.

signal confirmed(index: int)
signal cancelled

const HOLD_TIME := 1.0

var ring: RingWidget
var _hold: float = 0.0
var _holding_index: int = -1
var _selected: int = -1
var _done: bool = false
var _tutorial: PanelContainer
var _header: VBoxContainer
var _panel: PanelContainer
var _scroll: ScrollContainer
var _empty: RichTextLabel
var _content: VBoxContainer
var _victim_name: Label
var _recipient_name: Label
var _victim_icon: TextureRect
var _recipient_icon: TextureRect
var _now: RichTextLabel
var _loss: RichTextLabel
var _gain: RichTextLabel
var _keep: RichTextLabel
var _stat: Label
var _values: Label
var _note: RichTextLabel
var _details_button: Button
var _details: RichTextLabel
var _footer: VBoxContainer
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.82)
	UiKit.full_rect(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_header = VBoxContainer.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_theme_constant_override(&"separation", 6)
	add_child(_header)
	_header.add_child(UiKit.label("ЖЕРТВА %d / %d" % [RunState.sacrifices_count() + 1, Db.ITEM_IDS.size() - 1], 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_header.add_child(UiKit.outlined(UiKit.label("Алтарь жертвы", 40, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 8))
	var subtitle := UiKit.label("Одна вещь исчезнет. Её сила перейдёт соседу по стрелке.", 20, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.add_child(subtitle)

	# Сам RingWidget, его графика и порядок передачи силы остаются прежними.
	ring = RingWidget.new()
	ring.interactive = true
	ring.icon_radius = 44.0
	ring.show_names = true
	add_child(ring)
	ring.set_items(RunState.ring.items)
	ring.hovered.connect(_on_hover)
	ring.clicked.connect(_begin_hold)
	ring.mouse_exited.connect(_leave_ring)

	_build_card()
	_build_footer()
	_footer.minimum_size_changed.connect(func(): _layout.call_deferred())
	IconFactory.icons_ready.connect(_refresh_icons)
	resized.connect(_layout)
	_layout()
	if RunState.ring.size() > 1:
		_on_hover(0)
	if not RunState.seen_ring_tutorial:
		RunState.seen_ring_tutorial = true
		_show_tutorial()
	Audio.play(&"altar_open", -6.0)


func _build_card() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UiKit.box(UiKit.PANEL, UiKit.BORDER, 1, 2, 24))
	add_child(_panel)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override(&"separation", 10)
	_panel.add_child(frame)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 14)
	_scroll.add_child(body)
	_empty = UiKit.rich("Выберите вещь в кольце, чтобы увидеть потери и усиление соседа.", 22)
	body.add_child(_empty)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 10)
	body.add_child(_content)
	_content.hide()

	var pair := HBoxContainer.new()
	pair.add_theme_constant_override(&"separation", 14)
	_content.add_child(pair)
	_victim_icon = _icon(pair)
	var victim := VBoxContainer.new()
	victim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(victim)
	_victim_name = UiKit.label("", 32)
	victim.add_child(_victim_name)
	victim.add_child(UiKit.label("Жертва", 16, UiKit.MUTED))
	pair.add_child(UiKit.label("→", 32, UiKit.GOLD))
	_recipient_icon = _icon(pair)
	var recipient := VBoxContainer.new()
	recipient.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(recipient)
	_recipient_name = UiKit.label("", 32)
	recipient.add_child(_recipient_name)
	recipient.add_child(UiKit.label("Получит силу", 16, UiKit.MUTED))

	_content.add_child(UiKit.label("СЕЙЧАС У ВАС", 16, UiKit.MUTED))
	_now = UiKit.rich("", 18)
	_content.add_child(_now)
	_loss = _block("ПОТЕРЯЕТЕ НАВСЕГДА", Color(0.26, 0.10, 0.09, 0.75), Color(0.66, 0.36, 0.30))
	_gain = _block("ПОЛУЧИТЕ ВМЕСТО ЭТОГО", Color(0.23, 0.21, 0.13, 0.60), UiKit.GOLD)
	_keep = UiKit.rich("", 17)
	_content.add_child(_keep)
	var stats := HBoxContainer.new()
	_content.add_child(stats)
	_stat = UiKit.label("", 18)
	_stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_child(_stat)
	_values = UiKit.label("", 22, UiKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	stats.add_child(_values)
	var line := HSeparator.new()
	_content.add_child(line)
	_note = UiKit.rich("", 16)
	_note.add_theme_color_override(&"default_color", UiKit.MUTED)
	_content.add_child(_note)
	_details_button = Button.new()
	_details_button.text = "+  Цепочка и перенос свойств"
	_details_button.toggle_mode = true
	_details_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_button.add_theme_font_override(&"font", UiKit.body_font())
	_details_button.add_theme_font_size_override(&"font_size", 18)
	_details_button.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	_details_button.add_theme_stylebox_override(&"pressed", StyleBoxEmpty.new())
	_details_button.toggled.connect(_toggle_details)
	frame.add_child(_details_button)
	_details = UiKit.rich("", 18)
	_content.add_child(_details)
	_details.hide()


func _icon(parent: Control) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(46, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


func _block(title: String, bg: Color, accent: Color) -> RichTextLabel:
	var panel := PanelContainer.new()
	var style := UiKit.box(bg, accent, 0, 0, 16)
	style.border_width_left = 3
	panel.add_theme_stylebox_override(&"panel", style)
	_content.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 8)
	panel.add_child(rows)
	rows.add_child(UiKit.label(title, 16, UiKit.TEXT))
	var text := UiKit.rich("", 20)
	rows.add_child(text)
	return text


func _build_footer() -> void:
	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override(&"separation", 12)
	add_child(_footer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.09, 0.075, 0.08, 0.7), UiKit.BORDER, 1, 0, 16))
	_footer.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var bonus := Db.balance.sacrifice_speed_bonus
	var count := RunState.sacrifices_count()
	var speed := UiKit.label("Скорость: +%s%% → +%s%%" % [SacrificePreview.number(count * bonus * 100.0), SacrificePreview.number((count + 1) * bonus * 100.0)], 18, UiKit.GOLD)
	speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(speed)
	row.add_child(UiKit.label("Вещи: %d → %d" % [RunState.ring.size(), RunState.ring.size() - 1], 18))
	var next := RunState.stage + 1
	var text := "Далее: этап %d · Ворота дворца" % next
	if not RunState.is_boss_stage(next):
		var threat := RunState.threat_for(next)
		if threat != null:
			text = "Далее: этап %d · %s — %s" % [next, threat.display_name, threat.description]
	var threat_label := UiKit.outlined(UiKit.label(text, 17, UiKit.MUTED))
	threat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_child(threat_label)
	_hint = UiKit.outlined(UiKit.label("", 18, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_child(_hint)


func _layout() -> void:
	if _panel == null:
		return
	var margin := clampf(size.x * 0.045, 24.0, 80.0)
	var width := size.x - margin * 2.0
	_header.position = Vector2(margin, 24)
	_header.size = Vector2(width, 105)
	_footer.size = Vector2(width, 105)
	_footer.position = Vector2(margin, size.y - _footer.size.y - 24)
	var height := maxf(260.0, _footer.position.y - 169.0)
	var ring_side := minf(600.0, minf(width * 0.44, height))
	var left_width := width * 0.46
	ring.position = Vector2(margin + (left_width - ring_side) * 0.5, 145 + (height - ring_side) * 0.5)
	ring.size = Vector2(ring_side, ring_side)
	_panel.position = Vector2(margin + left_width + 24, 145)
	_panel.size = Vector2(width - left_width - 24, height)
	ring.queue_redraw()


func _toggle_details(open: bool) -> void:
	_details.visible = open
	_details_button.text = ("−" if open else "+") + "  Цепочка и перенос свойств"
	if open:
		_scroll.set_deferred("scroll_vertical", 100000)


func _refresh_icons() -> void:
	if _selected < 0:
		return
	_victim_icon.texture = IconFactory.icon(RunState.ring.items[_selected].def_id)
	_recipient_icon.texture = IconFactory.icon(RunState.ring.items[RunState.ring.recipient_index(_selected)].def_id)


func _on_hover(index: int) -> void:
	if _done:
		return
	_reset_hold()
	# Карточка остаётся видна, когда курсор уходит с вещи к подробностям.
	if index < 0 or index >= RunState.ring.size():
		return
	_selected = index
	ring.highlight_victim = index
	ring.highlight_pair = RunState.ring.recipient_index(index)
	var data := SacrificePreview.build(RunState.ring, index)
	if data.is_empty():
		return
	_empty.hide()
	_content.show()
	_victim_name.text = (data["victim"] as ItemState).def().display_name
	_recipient_name.text = (data["recipient"] as ItemState).def().display_name
	_now.text = data["now"]
	_loss.text = data["loss"]
	_gain.text = data["gain"]
	_keep.text = "✓  " + str(data["keep"])
	_stat.text = data["stat_name"]
	_values.text = "%s → %s" % [data["before"], data["result"]]
	_note.text = data["note"]
	_details.text = data["details"]
	_details_button.set_pressed_no_signal(false)
	_toggle_details(false)
	_scroll.scroll_vertical = 0
	_hint.text = "Удерживайте ЛКМ на вещи «%s» 1 с, чтобы отдать навсегда · Esc — отойти" % _victim_name.text
	_refresh_icons()
	ring.queue_redraw()


## Полное текстовое представление для отладки и инструментов снимка.
static func describe(index: int) -> String:
	var data := SacrificePreview.build(RunState.ring, index)
	if data.is_empty():
		return ""
	return "Сейчас у вас:\n%s\n\nПотеряете навсегда:\n%s\n\nПолучите вместо этого:\n%s\n\n%s\n%s: %s → %s\n\n%s" % [data["now"], data["loss"], data["gain"], data["keep"], data["stat_name"], data["before"], data["result"], data["details"]]


func _show_tutorial() -> void:
	_tutorial = PanelContainer.new()
	_tutorial.set_anchors_preset(Control.PRESET_CENTER)
	_tutorial.offset_left = -440
	_tutorial.offset_right = 440
	_tutorial.offset_top = -230
	_tutorial.offset_bottom = 230
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 16)
	_tutorial.add_child(v)
	v.add_child(UiKit.label("Кольцо вещей", 32, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.rich(
		"После каждого этапа вы отдаёте одну вещь навсегда.\n\n" +
		"• Выберите вещь в кольце. Карточка справа покажет, что исчезнет и что вы получите.\n" +
		"• Сила и накопленные свойства перейдут соседу по стрелке. Родное действие жертвы исчезнет.\n" +
		"• Например: щит, отданный сапогам, даст неуязвимость при рывке. Отдельного блока на ПКМ больше не будет.\n" +
		"• Каждая жертва даёт +%s%% скорости. Каждое свойство даёт +%s%% к урону действия вещи и её свойств.\n\n" % [SacrificePreview.number(Db.balance.sacrifice_speed_bonus * 100.0), SacrificePreview.number(Db.balance.property_damage_bonus * 100.0)] +
		"Чтобы подтвердить выбор, удерживайте ЛКМ на вещи 1 секунду.", 21))
	var ok := UiKit.button("Понятно", func(): _tutorial.queue_free())
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)
	add_child(_tutorial)


func _begin_hold(index: int) -> void:
	if _done or (_tutorial != null and is_instance_valid(_tutorial)):
		return
	_on_hover(index)
	_holding_index = index


func _leave_ring() -> void:
	ring.hover_index = -1
	_reset_hold()


func _reset_hold() -> void:
	_hold = 0.0
	_holding_index = -1
	ring.hold_progress = 0.0
	ring.queue_redraw()


func _process(delta: float) -> void:
	if _done or (_tutorial != null and is_instance_valid(_tutorial)):
		return
	if _holding_index < 0:
		return
	var over := ring.index_at(ring.get_local_mouse_position())
	if over != _holding_index or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_reset_hold()
		return
	_hold += delta
	ring.hold_progress = _hold / HOLD_TIME
	ring.queue_redraw()
	if int(_hold * 8.0) != int((_hold - delta) * 8.0):
		Audio.play(&"hold_tick", -10.0, 0.0)
	if _hold >= HOLD_TIME:
		_confirm(_holding_index)


func _confirm(index: int) -> void:
	_done = true
	_details_button.disabled = true
	var color := RunState.ring.items[index].def().essence.color
	ring.play_stream(index, RunState.ring.recipient_index(index), color)
	Audio.play(&"sacrifice_confirm")
	await get_tree().create_timer(1.3).timeout
	confirmed.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not _done:
		get_viewport().set_input_as_handled()
		cancelled.emit()
