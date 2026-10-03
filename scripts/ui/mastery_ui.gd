class_name MasteryUi
extends Control
## Постоянная коллекция: просмотр всех обликов и выбор открытого перед забегом.

var initial_scroll: int = 0
var _scroll: ScrollContainer

func _ready() -> void:
	UiKit.full_rect(self)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.95)
	UiKit.full_rect(dim)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -640
	panel.offset_right = 640
	panel.offset_top = -390
	panel.offset_bottom = 390
	add_child(panel)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	layout.add_child(UiKit.label("Самое нужное остаётся с тобой", 34, UiKit.GOLD))
	layout.add_child(UiKit.label("Каждое убийство даёт XP всем надетым вещам. Облик определяет эффект навыка.", 19))
	layout.add_child(UiKit.label("Новый уровень сразу надевает новый облик. Здесь можно выбрать прежний для следующего забега.", 17, UiKit.MUTED))
	if Mastery.save_error:
		layout.add_child(UiKit.label("Не удалось записать прогресс на диск. Он пока доступен только в этой сессии.", 18, UiKit.DANGER))
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id in Db.ITEM_IDS:
		_add_item(list, id)
	scroll.set_deferred("scroll_vertical", initial_scroll)
	layout.add_child(UiKit.button("Закрыть", queue_free))


func _add_item(list: VBoxContainer, id: StringName) -> void:
	var row := HBoxContainer.new()
	list.add_child(row)
	var preview := ItemShowcase.new()
	preview.custom_minimum_size = Vector2(200, 210)
	row.add_child(preview)
	var item := ItemState.create(id)
	item.appearance = Mastery.selected(id)
	preview.show_single(item)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UiKit.label("%s · %s" % [item.def().display_name, Mastery.progress_text(id)], 24, UiKit.GOLD))
	for tier in range(1, 4):
		var form := Mastery.form(id, tier)
		var unlocked := tier <= Mastery.level(id)
		var suffix := " · выбран" if tier == Mastery.selected(id) else ""
		if not unlocked:
			suffix = " · нужно %d XP" % int(Mastery.rules["thresholds"][tier - 1])
		var button := UiKit.button("%d. %s%s" % [tier, form["name"], suffix], func():
			Mastery.choose(id, tier)
			var replacement := MasteryUi.new()
			replacement.initial_scroll = _scroll.scroll_vertical
			get_parent().add_child(replacement)
			queue_free())
		button.disabled = not unlocked
		info.add_child(button)
		info.add_child(UiKit.label(str(form["effect"]) if tier > 1 else Db.item(id).action_text, 17, UiKit.TEXT if unlocked else UiKit.MUTED))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		queue_free()
