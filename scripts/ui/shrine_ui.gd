class_name ShrineUi
extends Control
## Святилище: один раз меняет местами двух соседей в кольце.

signal finished(swapped: bool)

var ring: RingWidget
var info: RichTextLabel
var _selected: int = -1
var _swap_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.8)
	UiKit.full_rect(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var title := UiKit.outlined(UiKit.label("Святилище", 40, Color(0.55, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER), 8)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 30
	title.offset_left = -400
	title.offset_right = 400
	add_child(title)
	var sub := UiKit.label("Нажмите на вещь, чтобы поменять её местами с соседом по стрелке. Один раз за этап.", 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_top = 86
	sub.offset_left = -560
	sub.offset_right = 560
	add_child(sub)
	ring = RingWidget.new()
	ring.interactive = true
	ring.icon_radius = 44.0
	ring.show_names = true
	ring.set_anchors_preset(Control.PRESET_CENTER)
	ring.offset_left = -560
	ring.offset_right = 40
	ring.offset_top = -280
	ring.offset_bottom = 300
	add_child(ring)
	ring.set_items(RunState.ring.items)
	ring.clicked.connect(_on_click)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = 80
	panel.offset_right = 640
	panel.offset_top = -160
	panel.offset_bottom = 160
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 16)
	panel.add_child(v)
	info = UiKit.rich("Выберите пару соседей.", 20)
	info.custom_minimum_size = Vector2(520, 120)
	v.add_child(info)
	_swap_button = UiKit.button("Поменять", _swap)
	_swap_button.disabled = true
	v.add_child(_swap_button)
	v.add_child(UiKit.button("Не менять", func(): finished.emit(false)))


func _on_click(i: int) -> void:
	_selected = i
	var r := RunState.ring
	var j := r.recipient_index(i)
	ring.highlight_victim = i
	ring.highlight_pair = j
	ring.queue_redraw()
	var a := r.items[i].def().display_name
	var b := r.items[j].def().display_name
	info.text = "Поменять местами [b]%s[/b] и [b]%s[/b].\n\nПосле обмена %s будет отдавать силу тому, кому раньше отдавал(а) %s." % [a, b, a, b]
	_swap_button.disabled = false


func _swap() -> void:
	if _selected < 0:
		return
	RunState.swap(_selected)
	finished.emit(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		finished.emit(false)
