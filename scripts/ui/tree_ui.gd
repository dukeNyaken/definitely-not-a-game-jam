class_name TreeUi
extends Control
## Tab: дерево свойств каждой вещи и жертвы, ушедшие боссу.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.78)
	UiKit.full_rect(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -640
	panel.offset_right = 640
	panel.offset_top = -380
	panel.offset_bottom = 380
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var text := UiKit.rich(build_text(), 19)
	text.custom_minimum_size = Vector2(1220, 0)
	scroll.add_child(text)


static func build_text() -> String:
	var g := UiKit.hex(UiKit.GOLD)
	var muted := UiKit.hex(UiKit.MUTED)
	var lines := PackedStringArray()
	lines.append("[center][b][color=#%s]Дерево свойств[/color][/b]   [color=#%s]Tab — закрыть[/color][/center]" % [g, muted])
	lines.append("")
	lines.append("[color=#%s]Событие вещи запускает её свойства: каждое применяет силу сущности и порождает событие дальше по дереву. Откат свойства — %s с.[/color]" % [muted, str(Db.balance.property_cooldown).replace(".", ",")])
	lines.append("")
	for s in RunState.ring.items:
		lines.append(PropertyTree.tree_bbcode(s, true))
		lines.append(Mastery.progress_text(s.def_id))
		lines.append("")
	if not RunState.sacrifice_log.is_empty():
		lines.append("[b][color=#%s]Жертвы (их наденет босс):[/color][/b]" % UiKit.hex(Color(0.8, 0.6, 1.0)))
		for i in RunState.sacrifice_log.size():
			var e: Dictionary = RunState.sacrifice_log[i]
			var p: Property = e["property"]
			lines.append("  %d. %s → %s  [color=#%s]«%s»[/color]" % [i + 1, Db.item(e["victim"]).display_name, Db.item(e["recipient"]).display_name, UiKit.hex(Db.essence(p.essence_id).color), p.display_name()])
	return "\n".join(lines)
