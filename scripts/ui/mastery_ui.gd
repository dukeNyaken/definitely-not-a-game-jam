class_name MasteryUi
extends Control
## Круговая коллекция: все 21 облик на одном экране, без прокрутки.

const TIER_NAMES := ["Исходный", "Пробуждение", "Реликвия"]

var selected_id: StringName = &"sword"
var preview_tier := 1
var _wheel: MasteryWheel
var _info: VBoxContainer
var _tier_buttons: Array[Button] = []
var _tier_status: Array[Label] = []
var _form_name: Label
var _effect: Label
var _progress: Label
var _next: Label
var _save_status: Label
var _equip: Button


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.full_rect(self)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.96)
	UiKit.full_rect(dim)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -700
	panel.offset_right = 700
	panel.offset_top = -410
	panel.offset_bottom = 410
	panel.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.05, 0.035, 0.055), UiKit.GOLD.darkened(0.35), 2, 12, 24))
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 12)
	panel.add_child(layout)
	layout.add_child(UiKit.label("Облики семи вещей", 42, UiKit.GOLD))
	_save_status = UiKit.label("Выбери вещь на круге, затем её облик", 18, UiKit.MUTED)
	layout.add_child(_save_status)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 28)
	layout.add_child(row)
	_wheel = MasteryWheel.new()
	_wheel.collection_mode = true
	_wheel.selected_id = selected_id
	row.add_child(_wheel)
	_wheel.item_selected.connect(_show_item)
	_wheel.appearance_inspected.connect(func(_id: StringName, tier: int): _inspect_tier(tier))
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(630, 0)
	frame.add_theme_stylebox_override(&"panel", UiKit.box(Color(0.07, 0.05, 0.075), Color(0.25, 0.2, 0.25), 1, 8, 18))
	row.add_child(frame)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override(&"separation", 10)
	frame.add_child(_info)
	_show_item(selected_id)
	Mastery.changed.connect(_refresh)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 24)
	layout.add_child(footer)
	var legend := VBoxContainer.new()
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(legend)
	legend.add_child(UiKit.label("Цвет — открыт · Тёмный — закрыт · Золотая точка — выбран", 17, UiKit.MUTED))
	legend.add_child(UiKit.label("От центра: I · II (%d XP) · III (%d XP)" % [int(Mastery.rules["thresholds"][1]), int(Mastery.rules["thresholds"][2])], 16, UiKit.GOLD))
	var close := UiKit.button("Закрыть", queue_free)
	close.custom_minimum_size.x = 180
	close.focus_mode = Control.FOCUS_ALL
	footer.add_child(close)


func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var label := UiKit.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _show_item(id: StringName) -> void:
	selected_id = id
	preview_tier = Mastery.selected(id)
	for child in _info.get_children():
		_info.remove_child(child)
		child.queue_free()
	_tier_buttons.clear()
	_tier_status.clear()
	_info.add_child(UiKit.label(Db.item(id).display_name, 38, Db.item(id).essence.color))
	_progress = UiKit.label("", 20)
	_info.add_child(_progress)
	_next = UiKit.label("", 17, UiKit.MUTED)
	_info.add_child(_next)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override(&"separation", 10)
	_info.add_child(cards)
	for tier in range(1, 4):
		var button := UiKit.button("", _inspect_tier.bind(tier))
		button.custom_minimum_size = Vector2(0, 270)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cards.add_child(button)
		_tier_buttons.append(button)
		var margin := MarginContainer.new()
		UiKit.full_rect(margin)
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override(StringName("margin_" + side), 10)
		button.add_child(margin)
		var contents := VBoxContainer.new()
		margin.add_child(contents)
		contents.add_child(UiKit.label(MasteryWheel.ROMAN[tier - 1], 26, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		contents.add_child(UiKit.label(TIER_NAMES[tier - 1], 16, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var preview := ItemShowcase.new()
		preview.custom_minimum_size = Vector2(0, 170)
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		contents.add_child(preview)
		var state := ItemState.create(id)
		state.appearance = tier
		preview.show_single(state)
		preview.viewport.get_camera_3d().size = minf(2.6, float(IconFactory.FRAMING[id][0]) * 1.6)
		var status := UiKit.label("", 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		contents.add_child(status)
		_tier_status.append(status)
		_ignore_input(margin)
	_form_name = _wrapped("", 30, UiKit.GOLD)
	_info.add_child(_form_name)
	_effect = _wrapped("", 18, UiKit.TEXT)
	_info.add_child(_effect)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_child(spacer)
	_equip = UiKit.button("", _choose_preview)
	_equip.focus_mode = Control.FOCUS_ALL
	_info.add_child(_equip)
	_refresh()


func _ignore_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_input(child)


func _inspect_tier(tier: int) -> void:
	preview_tier = clampi(tier, 1, 3)
	_refresh()


func _choose_preview() -> void:
	if preview_tier <= Mastery.level(selected_id) and preview_tier != Mastery.selected(selected_id):
		Mastery.choose(selected_id, preview_tier)


func _refresh() -> void:
	var color := Db.item(selected_id).essence.color
	var lv := Mastery.level(selected_id)
	var total := int(Mastery.xp.get(selected_id, 0))
	var equipped := Mastery.selected(selected_id)
	_progress.text = "Уровень %s · %d / %d XP" % [MasteryWheel.ROMAN[lv - 1], total, int(Mastery.rules["thresholds"].back())]
	_next.text = "Все облики открыты" if lv == 3 else "До облика %s: %d XP" % [MasteryWheel.ROMAN[lv], int(Mastery.rules["thresholds"][lv]) - total]
	for i in _tier_buttons.size():
		var tier := i + 1
		var unlocked := tier <= lv
		var inspecting := tier == preview_tier
		_tier_buttons[i].add_theme_stylebox_override(&"normal", UiKit.box(Color(color, 0.12) if unlocked else Color(0.04, 0.03, 0.05), UiKit.GOLD if inspecting else color.darkened(0.45) if unlocked else Color(0.23, 0.2, 0.26), 2 if inspecting else 1, 8, 4))
		_tier_buttons[i].add_theme_stylebox_override(&"hover", UiKit.box(Color(color, 0.18), color, 2, 8, 4))
		_tier_buttons[i].tooltip_text = str(Mastery.form(selected_id, tier)["name"])
		_tier_status[i].text = "Выбран" if tier == equipped else "Открыт" if unlocked else "Ещё %d XP" % (int(Mastery.rules["thresholds"][i]) - total)
		_tier_status[i].add_theme_color_override(&"font_color", UiKit.GOLD if tier == equipped else UiKit.MUTED)
	var form := Mastery.form(selected_id, preview_tier)
	_form_name.text = str(form["name"]) if preview_tier > 1 else "%s · исходный облик" % Db.item(selected_id).display_name
	_effect.text = str(form["effect"]) if preview_tier > 1 else Db.item(selected_id).action_text
	_equip.disabled = preview_tier > lv or preview_tier == equipped
	_equip.text = "Выбран для следующего забега" if preview_tier == equipped else "Ещё %d XP до открытия" % (int(Mastery.rules["thresholds"][preview_tier - 1]) - total) if preview_tier > lv else "Выбрать для следующего забега"
	_save_status.text = "Не удалось сохранить · выбор пока в памяти" if Mastery.save_error else "Выбери вещь на круге, затем её облик"
	_save_status.add_theme_color_override(&"font_color", UiKit.DANGER.lightened(0.3) if Mastery.save_error else UiKit.MUTED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		queue_free()
