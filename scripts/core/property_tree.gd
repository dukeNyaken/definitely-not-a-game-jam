class_name PropertyTree
extends RefCounted
## Дерево свойств вещи: корень — родное событие вещи, дети — свойства, слушающие событие,
## дальше — свойства, слушающие порождённые ими события.


## [{ "depth": int, "property": Property }] в порядке обхода в глубину.
static func walk(state: ItemState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	_walk_event(state, state.def().event_id, 0, out, seen)
	# Свойства, не достижимые из родного события (выданы отладкой) — отдельными корнями.
	for p in state.properties:
		if not seen.has(p):
			seen[p] = true
			out.append({"depth": 0, "property": p})
			_walk_event(state, p.emit_event, 1, out, seen)
	return out


static func _walk_event(state: ItemState, event_id: StringName, depth: int, out: Array[Dictionary], seen: Dictionary) -> void:
	if depth > 8:
		return
	for p in state.properties:
		if p.listen_event == event_id and not seen.has(p):
			seen[p] = true
			out.append({"depth": depth, "property": p})
			_walk_event(state, p.emit_event, depth + 1, out, seen)


static func event_label(event_id: StringName) -> String:
	return Db.event_word(event_id).capitalize()


## «Рывок → Оплот → Блок» в BBCode с цветом сущности.
static func chain_bbcode(p: Property) -> String:
	var e := Db.essence(p.essence_id)
	return "%s → [color=#%s]%s[/color] → %s" % [event_label(p.listen_event), UiKit.hex(e.color), e.display_name, event_label(p.emit_event)]


static func property_bbcode(p: Property, with_effect: bool = false) -> String:
	var e := Db.essence(p.essence_id)
	var s := "[color=#%s]«%s»[/color]  %s" % [UiKit.hex(e.color), p.display_name(), chain_bbcode(p)]
	if with_effect:
		s += "  [color=#%s](%s)[/color]" % [UiKit.hex(UiKit.MUTED), e.effect_text]
	return s


## Многострочное дерево с отступами.
static func tree_bbcode(state: ItemState, with_effect: bool = false) -> String:
	var def := state.def()
	var lines := PackedStringArray()
	var head := "[b]%s[/b] — %s" % [def.display_name, event_label(def.event_id)]
	if not def.is_passive():
		head += " (%s)" % def.input_label
	lines.append(head)
	lines.append("Облик %d: %s — %s" % [state.appearance, Mastery.form(state.def_id, state.appearance)["name"], Mastery.form(state.def_id, state.appearance)["effect"]])
	for entry in walk(state):
		var indent := "    ".repeat(int(entry["depth"]) + 1)
		lines.append("%s└ %s" % [indent, property_bbcode(entry["property"], with_effect)])
	return "\n".join(lines)
