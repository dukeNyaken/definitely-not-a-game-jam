class_name AltarUi
extends Control
## Алтарь: большое кольцо со стрелками по часовой. Наведи на вещь — карточка покажет:
## что теряешь, что получит сосед, что от чего теперь срабатывает, что достанется боссу,
## угрозу следующего этапа. Подтверждение — удержание ЛКМ 1 с.

signal confirmed(index: int)
signal cancelled

const HOLD_TIME := 1.0

var ring: RingWidget
var card: RichTextLabel
var _hold: float = 0.0
var _holding_index: int = -1
var _done: bool = false
var _tutorial: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.82)
	UiKit.full_rect(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var title := UiKit.outlined(UiKit.label("Алтарь жертвы", 40, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 8)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 26
	title.offset_left = -400
	title.offset_right = 400
	add_child(title)
	var sub := UiKit.label("Выберите вещь, которую отдадите навсегда. Её сила уйдёт соседу по стрелке.", 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_top = 82
	sub.offset_left = -500
	sub.offset_right = 500
	add_child(sub)

	ring = RingWidget.new()
	ring.interactive = true
	ring.icon_radius = 44.0
	ring.show_names = true
	ring.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	ring.offset_left = 70
	ring.offset_right = 70 + 600
	ring.offset_top = -280
	ring.offset_bottom = 320
	add_child(ring)
	ring.set_items(RunState.ring.items)
	ring.hovered.connect(_on_hover)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -880
	panel.offset_right = -50
	panel.offset_top = -280
	panel.offset_bottom = 300
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	card = UiKit.rich("", 19)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(780, 0)
	scroll.add_child(card)
	_show_default()

	var hint := UiKit.outlined(UiKit.label("Удерживайте ЛКМ на вещи 1 секунду, чтобы пожертвовать · Esc — отойти от алтаря", 18, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -56
	hint.offset_bottom = -24
	hint.offset_left = -600
	hint.offset_right = 600
	add_child(hint)

	if not RunState.seen_ring_tutorial:
		RunState.seen_ring_tutorial = true
		_show_tutorial()
	Audio.play(&"altar_open", -6.0)


func _show_tutorial() -> void:
	_tutorial = PanelContainer.new()
	_tutorial.set_anchors_preset(Control.PRESET_CENTER)
	_tutorial.offset_left = -430
	_tutorial.offset_right = 430
	_tutorial.offset_top = -230
	_tutorial.offset_bottom = 230
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 14)
	_tutorial.add_child(v)
	var g := UiKit.hex(UiKit.GOLD)
	v.add_child(UiKit.rich(
		"[center][b][color=#%s]Кольцо[/color][/b][/center]\n\n" % g +
		"Семь вещей стоят по кольцу. После каждого этапа вы навсегда отдаёте одну.\n\n" +
		"• Жертва уходит в [color=#%s]соседа по стрелке[/color] (по часовой), и кольцо смыкается.\n" % g +
		"• Сосед получает свойство: [i]его событие → сила жертвы[/i]. Например, щит, ушедший в сапоги, даёт «Неуязвимый рывок»: рывок теперь даёт неуязвимость.\n" +
		"• Все свойства жертвы переезжают вместе с ней — в конце останется одна вещь и всё дерево ваших решений.\n" +
		"• Каждая жертва даёт +6% скорости, каждое свойство — +10% урона действию вещи.\n" +
		"• Всё, что вы отдали, наденет финальный босс.", 19))
	var ok := UiKit.button("Понятно", func(): _tutorial.queue_free())
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)
	add_child(_tutorial)


func _show_default() -> void:
	card.text = "[color=#%s]Наведите на вещь в кольце, чтобы увидеть последствия жертвы.[/color]\n\n%s" % [UiKit.hex(UiKit.MUTED), _current_trees()]


func _current_trees() -> String:
	var parts := PackedStringArray()
	for s in RunState.ring.items:
		if not s.properties.is_empty():
			parts.append(PropertyTree.tree_bbcode(s))
	if parts.is_empty():
		return ""
	return "[b]Сейчас:[/b]\n" + "\n".join(parts)


func _on_hover(index: int) -> void:
	_hold = 0.0
	ring.hold_progress = 0.0
	if index < 0:
		ring.highlight_victim = -1
		ring.highlight_pair = -1
		_show_default()
		return
	var r := RunState.ring
	ring.highlight_victim = index
	ring.highlight_pair = r.recipient_index(index)
	card.text = describe(index)
	ring.queue_redraw()


## Карточка последствий жертвы ring[index].
static func describe(index: int) -> String:
	var r := RunState.ring
	var pv := r.preview(index)
	var victim: ItemState = pv["victim"]
	var recipient: ItemState = pv["recipient"]
	var after: ItemState = pv["recipient_after"]
	var prop: Property = pv["property"]
	var vd := victim.def()
	var rd := recipient.def()
	var g := UiKit.hex(UiKit.GOLD)
	var red := UiKit.hex(UiKit.DANGER)
	var muted := UiKit.hex(UiKit.MUTED)
	var ess := vd.essence
	var lines := PackedStringArray()
	lines.append("[b][color=#%s]Теряете:[/color][/b] %s — %s" % [red, vd.display_name, vd.action_text])
	if not victim.properties.is_empty():
		lines.append("    вместе со свойствами: %s" % ", ".join(victim.property_names()))
	lines.append("")
	lines.append("[b][color=#%s]Получит сосед:[/color][/b] %s ← [color=#%s]«%s»[/color]" % [g, rd.display_name, UiKit.hex(ess.color), prop.display_name()])
	lines.append("    сущность %s: %s" % [ess.display_name, ess.effect_text])
	if not victim.properties.is_empty():
		lines.append("    и %d свойств(а) переедут из «%s»" % [victim.properties.size(), vd.display_name])
	lines.append("    урон действия %s: +%d%%" % [rd.display_name, int(round(after.properties.size() * Db.balance.property_damage_bonus * 100))])
	lines.append("")
	lines.append("[b][color=#%s]Теперь срабатывает:[/color][/b]" % g)
	lines.append(PropertyTree.tree_bbcode(after, true))
	lines.append("")
	lines.append("[b][color=#%s]Достанется боссу:[/color][/b] %s%s" % [UiKit.hex(Color(0.8, 0.6, 1.0)), vd.display_name,
		(" со свойствами: " + ", ".join(victim.property_names())) if not victim.properties.is_empty() else ""])
	var used := RunState.sacrifices_count()
	if used == 0:
		lines.append("    [color=#%s]первая жертва — останется с боссом до самого конца[/color]" % muted)
	elif used < 3:
		lines.append("    [color=#%s]одна из трёх первых жертв — босс сохранит её во второй фазе[/color]" % muted)
	lines.append("")
	var next := RunState.stage + 1
	if RunState.is_boss_stage(next):
		lines.append("[b][color=#%s]Дальше:[/color][/b] %s у ворот дворца" % [red, Story.TYRANT_NAME])
	else:
		var th := RunState.threat_for(next)
		lines.append("[b][color=#%s]Угроза этапа %d:[/color][/b] %s — %s" % [red, next, th.display_name, th.description])
	return "\n".join(lines)


func _process(delta: float) -> void:
	if _done or (_tutorial != null and is_instance_valid(_tutorial)):
		return
	var over := ring.hover_index
	if over >= 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _holding_index != over:
			_holding_index = over
			_hold = 0.0
		_hold += delta
		ring.hold_progress = _hold / HOLD_TIME
		ring.queue_redraw()
		if int(_hold * 8.0) != int((_hold - delta) * 8.0):
			Audio.play(&"hold_tick", -10.0, 0.0)
		if _hold >= HOLD_TIME:
			_confirm(over)
	else:
		if _hold > 0.0:
			ring.hold_progress = 0.0
			ring.queue_redraw()
		_hold = 0.0
		_holding_index = -1


func _confirm(index: int) -> void:
	_done = true
	var r := RunState.ring
	var color := r.items[index].def().essence.color
	ring.play_stream(index, r.recipient_index(index), color)
	Audio.play(&"sacrifice_confirm")
	await get_tree().create_timer(1.3).timeout
	confirmed.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not _done:
		get_viewport().set_input_as_handled()
		cancelled.emit()
