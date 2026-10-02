class_name PauseMenu
extends Control
## Пауза: продолжить, новый забег, главное меню, громкость.

signal resumed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	UiKit.full_rect(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -300
	panel.offset_bottom = 300
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 14)
	panel.add_child(v)
	v.add_child(UiKit.label("Пауза", 40, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label("Сид %d · %s" % [RunState.seed_value, RunState.time_text()], 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Продолжить", func(): resumed.emit()))
	v.add_child(UiKit.button("Новый забег", _restart))
	v.add_child(UiKit.button("Главное меню", _menu))
	var render_btn := UiKit.button("Рендер: %s" % Render.mode_name(), func(): pass)
	render_btn.pressed.connect(func():
		Render.toggle()
		render_btn.text = "Рендер: %s" % Render.mode_name()
	)
	v.add_child(render_btn)
	var story_btn := UiKit.button(Render.cutscenes_text(), func(): pass)
	story_btn.pressed.connect(func():
		Render.set_cutscenes(not Render.cutscenes)
		story_btn.text = Render.cutscenes_text()
	)
	v.add_child(story_btn)
	v.add_child(_volume_row("Звуки", Audio.sfx_volume_db, func(val):
		Audio.sfx_volume_db = val
		Render.save_settings()
	))
	v.add_child(_volume_row("Музыка", Audio.music_volume_db, func(val):
		Audio.set_music_volume(val)
		Render.save_settings()
	))


func _volume_row(title: String, value: float, setter: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := UiKit.label(title, 18)
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = -40.0
	s.max_value = 6.0
	s.step = 1.0
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(setter)
	s.focus_mode = Control.FOCUS_NONE
	h.add_child(s)
	return h


func _restart() -> void:
	get_tree().paused = false
	RunState.new_run()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _menu() -> void:
	get_tree().paused = false
	RunState.running = false
	Audio.stop_music()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
