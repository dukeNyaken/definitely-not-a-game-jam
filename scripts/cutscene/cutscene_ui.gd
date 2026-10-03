class_name CutsceneUi
extends CanvasLayer
## Интерфейс сюжетных сцен: кинорамка, реплики с печатью по буквам, летопись по центру, заставки глав,
## реплики в бою, подсказка пропуска, вспышки и «плёнка» кадра (тонировка, виньетка, зерно).
## Слой 12 — над HUD (10), под отладкой (50).

const BAR_H := 104.0
const SEPIA := Color(1.0, 0.78, 0.5)
## Наклон мыслей: сдвиг верха буквы вправо. Матрица — как в документации FontVariation:
## Transform2D(1, slant, 0, 1, 0, 0). Сдвиг по другой оси поворачивает буквы, а не наклоняет.
const THOUGHT_SLANT := 0.16
const LINE_SLIDE := 10.0

var root: Control
var _top: ColorRect
var _bottom: ColorRect
var _grade: ColorRect
var _grade_mat: ShaderMaterial
var _black: ColorRect
var _flash: ColorRect
var _line_bg: TextureRect
var _line_box: VBoxContainer
var _line_name: Label
var _line_text: RichTextLabel
var _center_box: VBoxContainer
var _center_name: Label
var _center_text: RichTextLabel
var _chapter_box: VBoxContainer
var _chapter_title: Label
var _chapter_sub: Label
var _chapter_lines: Array[ColorRect] = []
var _chapter_font: FontVariation
var _bark_box: VBoxContainer
var _bark_name: Label
var _bark_text: RichTextLabel
var _skip_box: HBoxContainer
var _skip_fill: ColorRect
var _typed: RichTextLabel
var _thought_font: FontVariation
var _tweens: Dictionary = {}
var _base_offsets: Dictionary = {}
## Таблички над головами: { "node": Node3D, "box": Control, "h": float }.
var _tags: Array[Dictionary] = []


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(root)
	add_child(root)
	_thought_font = FontVariation.new()
	_thought_font.base_font = UiKit.body_font()
	_thought_font.variation_transform = Transform2D(Vector2(1.0, THOUGHT_SLANT), Vector2(0.0, 1.0), Vector2.ZERO)
	_build_grade()
	_black = _rect(Color(0, 0, 0, 0))
	UiKit.full_rect(_black)
	_build_bars()
	_build_line()
	_build_center()
	_build_chapter()
	_build_bark()
	_build_skip()
	_flash = _rect(Color(1, 1, 1, 0))
	UiKit.full_rect(_flash)


# --- Постройка --------------------------------------------------------------

func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


func _build_grade() -> void:
	_grade = _rect(Color.WHITE)
	UiKit.full_rect(_grade)
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = preload("res://shaders/cutscene_tint.gdshader")
	for p in [&"amount", &"vignette", &"grain", &"flicker"]:
		_grade_mat.set_shader_parameter(p, 0.0)
	_grade.material = _grade_mat
	_grade.visible = false


func _build_bars() -> void:
	# Полосы на всю ширину; высоту задаёт bars(). Отступы обнуляем явно — пресет хранит нулевую ширину.
	_top = _rect(Color.BLACK)
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bottom = _rect(Color.BLACK)
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	for r in [_top, _bottom]:
		r.offset_left = 0
		r.offset_right = 0
		r.offset_top = 0
		r.offset_bottom = 0


func _text_label(size: int) -> RichTextLabel:
	var t := UiKit.rich("", size)
	t.add_theme_constant_override(&"outline_size", 8)
	t.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return t


func _build_line() -> void:
	# Мягкая тень над нижней полосой: длинная реплика в две строки читается и на светлом кадре.
	_line_bg = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.62))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	_line_bg.texture = tex
	_line_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_line_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_line_bg.offset_left = 0
	_line_bg.offset_right = 0
	_line_bg.offset_top = -BAR_H - 120
	_line_bg.offset_bottom = -BAR_H
	_line_bg.modulate.a = 0.0
	root.add_child(_line_bg)
	_line_box = VBoxContainer.new()
	_line_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# Узкая колонка: длинная реплика переносится на вторую строку, а не дотягивается до подсказки пропуска справа.
	_line_box.offset_left = -450
	_line_box.offset_right = 450
	_line_box.offset_top = -BAR_H - 96
	_line_box.offset_bottom = -22
	_line_box.alignment = BoxContainer.ALIGNMENT_END
	_line_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_box.add_theme_constant_override(&"separation", 2)
	root.add_child(_line_box)
	_line_name = UiKit.outlined(UiKit.label("", 28, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 8)
	_line_box.add_child(_line_name)
	_line_text = _text_label(25)
	_line_box.add_child(_line_text)
	_line_box.modulate.a = 0.0
	_base_offsets[_line_box] = Vector2(_line_box.offset_top, _line_box.offset_bottom)


func _build_center() -> void:
	_center_box = VBoxContainer.new()
	_center_box.set_anchors_preset(Control.PRESET_CENTER)
	_center_box.offset_left = -600
	_center_box.offset_right = 600
	_center_box.offset_top = -160
	_center_box.offset_bottom = 160
	_center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_box.add_theme_constant_override(&"separation", 14)
	root.add_child(_center_box)
	_center_name = UiKit.outlined(UiKit.label("", 26, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER), 6)
	_center_box.add_child(_center_name)
	_center_text = _text_label(32)
	_center_box.add_child(_center_text)
	_center_box.modulate.a = 0.0
	_base_offsets[_center_box] = Vector2(_center_box.offset_top, _center_box.offset_bottom)


## Заставка главы: золотой заголовок между двумя тонкими линиями, под ним подзаголовок.
func _build_chapter() -> void:
	_chapter_box = VBoxContainer.new()
	_chapter_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_chapter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapter_box.add_theme_constant_override(&"separation", 6)
	root.add_child(_chapter_box)
	_chapter_font = FontVariation.new()
	_chapter_font.base_font = UiKit.title_font()
	_chapter_box.add_child(_ornament())
	_chapter_title = UiKit.outlined(UiKit.label("", 64, Color(1.0, 0.84, 0.5), HORIZONTAL_ALIGNMENT_CENTER), 8)
	_chapter_title.add_theme_font_override(&"font", _chapter_font)
	_chapter_box.add_child(_chapter_title)
	_chapter_sub = UiKit.outlined(UiKit.label("", 22, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER), 6)
	_chapter_box.add_child(_chapter_sub)
	_chapter_box.add_child(_ornament())
	_chapter_box.modulate.a = 0.0


func _ornament() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	for k in 3:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if k == 1:
			# Ромб посередине.
			r.color = Color(1.0, 0.8, 0.42, 0.95)
			r.custom_minimum_size = Vector2(7, 7)
			r.pivot_offset = Vector2(3.5, 3.5)
			r.rotation = PI / 4
		else:
			r.color = Color(1.0, 0.8, 0.42, 0.7)
			r.custom_minimum_size = Vector2(0, 2)
			_chapter_lines.append(r)
		row.add_child(r)
	return row


func _build_bark() -> void:
	_bark_box = VBoxContainer.new()
	_bark_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bark_box.offset_left = -560
	_bark_box.offset_right = 560
	_bark_box.offset_top = -250
	_bark_box.offset_bottom = -128
	_bark_box.alignment = BoxContainer.ALIGNMENT_END
	_bark_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bark_box)
	_bark_name = UiKit.outlined(UiKit.label("", 22, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 6)
	_bark_box.add_child(_bark_name)
	_bark_text = _text_label(22)
	_bark_box.add_child(_bark_text)
	_bark_box.modulate.a = 0.0


func _build_skip() -> void:
	_skip_box = HBoxContainer.new()
	_skip_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_box.offset_left = -420
	_skip_box.offset_right = -28
	_skip_box.offset_top = -46
	_skip_box.offset_bottom = -20
	_skip_box.alignment = BoxContainer.ALIGNMENT_END
	_skip_box.add_theme_constant_override(&"separation", 10)
	_skip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_skip_box)
	_skip_box.add_child(UiKit.label("удерживайте Пробел — пропустить", 15, Color(UiKit.MUTED, 0.85)))
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.12)
	track.custom_minimum_size = Vector2(70, 4)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_box.add_child(track)
	_skip_fill = ColorRect.new()
	_skip_fill.color = UiKit.GOLD
	_skip_fill.size = Vector2(0, 4)
	_skip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_skip_fill)
	_skip_box.modulate.a = 0.0


# --- Твины ------------------------------------------------------------------

func _tw(key: StringName) -> Tween:
	var old: Tween = _tweens.get(key)
	if old != null and old.is_valid():
		old.kill()
	var tw := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens[key] = tw
	return tw


func _fade_to(node: CanvasItem, key: StringName, alpha: float, dur: float) -> void:
	if dur <= 0.0:
		_tw(key).kill()
		node.modulate.a = alpha
		return
	_tw(key).tween_property(node, "modulate:a", alpha, dur)


## Текст всплывает снизу на несколько пикселей — так реплика появляется мягче.
func _slide_in(box: Control, key: StringName, dur: float) -> void:
	var base: Vector2 = _base_offsets[box]
	var tw := _tw(key).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float):
		box.offset_top = base.x + v
		box.offset_bottom = base.y + v, LINE_SLIDE, 0.0, dur)


# --- Управление -------------------------------------------------------------

## Чёрные полосы сверху и снизу и подсказка пропуска.
func bars(on: bool, dur: float = 0.6) -> void:
	var h := BAR_H if on else 0.0
	var tw := _tw(&"bars").set_parallel(true)
	tw.tween_property(_top, "offset_bottom", h, dur)
	tw.tween_property(_bottom, "offset_top", -h, dur)
	_fade_to(_skip_box, &"skip", 1.0 if on else 0.0, dur)


## Реплика внизу: имя цветом говорящего. Мысль — без имени, золотым наклонным.
func show_line(speaker: String, color: Color, text: String, thought: bool = false) -> void:
	_line_name.text = speaker
	_line_name.add_theme_color_override(&"font_color", color)
	_line_name.visible = speaker != ""
	if thought:
		_line_text.add_theme_font_override(&"normal_font", _thought_font)
		_line_text.add_theme_color_override(&"default_color", UiKit.GOLD)
	else:
		_line_text.remove_theme_font_override(&"normal_font")
		_line_text.add_theme_color_override(&"default_color", UiKit.TEXT)
	_line_text.text = "[center]%s[/center]" % text
	_line_text.visible_ratio = 0.0
	_typed = _line_text
	_fade_to(_line_box, &"line", 1.0, 0.18)
	_fade_to(_line_bg, &"line_bg", 1.0, 0.3)
	_slide_in(_line_box, &"line_slide", 0.35)


func hide_line(dur: float = 0.25) -> void:
	_fade_to(_line_box, &"line", 0.0, dur)
	_fade_to(_line_bg, &"line_bg", 0.0, dur + 0.2)


## Летопись: крупный текст по центру, необязательный заголовок над ним.
func show_center(header: String, text: String, text_color: Color = UiKit.TEXT, header_color: Color = UiKit.MUTED) -> void:
	_center_name.text = header
	_center_name.visible = header != ""
	_center_name.add_theme_color_override(&"font_color", header_color)
	_center_text.add_theme_color_override(&"default_color", text_color)
	_center_text.text = "[center]%s[/center]" % text
	_center_text.visible_ratio = 0.0
	_typed = _center_text
	_fade_to(_center_box, &"center", 1.0, 0.4)
	_slide_in(_center_box, &"center_slide", 0.9)


func hide_center(dur: float = 0.5) -> void:
	_fade_to(_center_box, &"center", 0.0, dur)


## Заставка главы. small — компактная, в верхней части кадра поверх сцены (дар);
## иначе крупная по центру (пролог, ворота, эпилог). Видна hold секунд, потом гаснет.
func chapter(title: String, subtitle: String, small: bool, hold: float) -> void:
	_chapter_title.text = title
	_chapter_sub.text = subtitle
	_chapter_sub.visible = subtitle != ""
	_chapter_title.add_theme_font_size_override(&"font_size", 40 if small else 68)
	_chapter_sub.add_theme_font_size_override(&"font_size", 18 if small else 23)
	if small:
		_chapter_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_chapter_box.offset_top = BAR_H + 18
		_chapter_box.offset_bottom = BAR_H + 150
	else:
		_chapter_box.set_anchors_preset(Control.PRESET_CENTER)
		_chapter_box.offset_top = -110
		_chapter_box.offset_bottom = 110
	_chapter_box.offset_left = -560
	_chapter_box.offset_right = 560
	var line_w := 150.0 if small else 240.0
	for l in _chapter_lines:
		l.custom_minimum_size.x = 0.0
	_chapter_font.spacing_glyph = 10
	var tw := _tw(&"chapter").set_parallel(true)
	tw.tween_property(_chapter_box, "modulate:a", 1.0, 0.7)
	for l in _chapter_lines:
		tw.tween_property(l, "custom_minimum_size:x", line_w, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Буквы медленно «сходятся» всё время, пока заставка на экране.
	tw.tween_property(_chapter_font, "spacing_glyph", 2, hold + 1.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(_chapter_box, "modulate:a", 0.0, 0.7).set_delay(0.7 + hold)


func hide_chapter(dur: float = 0.3) -> void:
	_fade_to(_chapter_box, &"chapter", 0.0, dur)


## Доля напечатанного текста у последней показанной реплики.
func set_typed(k: float) -> void:
	if _typed != null:
		_typed.visible_ratio = clampf(k, 0.0, 1.0)


## Затемнение кадра. color — для голоса из дворца (тёмно-багровый вместо чёрного).
func black(alpha: float, dur: float, color: Color = Color.BLACK) -> void:
	_black.color = Color(color, _black.color.a)
	if dur <= 0.0:
		_tw(&"black").kill()
		_black.color.a = alpha
		return
	_tw(&"black").tween_property(_black, "color:a", alpha, dur)


## Вспышка во весь кадр: удар, превращение, перстень.
func flash(color: Color = Color.WHITE, dur: float = 0.5, strength: float = 0.85) -> void:
	_flash.color = Color(color, strength)
	_tw(&"flash").tween_property(_flash, "color:a", 0.0, maxf(dur, 0.01)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## «Плёнка» кадра: тонировка цветом color (amount 0 — без неё), виньетка, зерно, мерцание.
func grade(color: Color, amount: float, vignette: float, grain: float, flicker: float, dur: float) -> void:
	_grade_mat.set_shader_parameter(&"tint", color)
	var target := {&"amount": amount, &"vignette": vignette, &"grain": grain, &"flicker": flicker}
	var off := amount <= 0.0 and vignette <= 0.0 and grain <= 0.0 and flicker <= 0.0
	_grade.visible = true
	var tw := _tw(&"grade").set_parallel(true)
	for p in target:
		var from: Variant = _grade_mat.get_shader_parameter(p)
		var f := 0.0 if from == null else float(from)
		var to: float = target[p]
		if dur <= 0.0:
			_grade_mat.set_shader_parameter(p, to)
		else:
			tw.tween_method(func(v: float): _grade_mat.set_shader_parameter(p, v), f, to, dur)
	if dur <= 0.0:
		tw.kill()
		_grade.visible = not off
	elif off:
		tw.chain().tween_callback(func(): _grade.visible = false)


## Тонировка без остальной «плёнки» (совместимость со старыми вызовами).
func tint(color: Color, amount: float, dur: float) -> void:
	grade(color, amount, _param(&"vignette"), _param(&"grain"), _param(&"flicker"), dur)


func _param(p: StringName) -> float:
	var v: Variant = _grade_mat.get_shader_parameter(p)
	return 0.0 if v == null else float(v)


func skip_progress(k: float) -> void:
	_skip_fill.size.x = 70.0 * clampf(k, 0.0, 1.0)


## Реплика в бою: без рамки, над панелью действий; видна, пока не скроют.
func show_bark(speaker: String, color: Color, text: String, thought: bool) -> void:
	_bark_name.text = speaker
	_bark_name.visible = speaker != ""
	_bark_name.add_theme_color_override(&"font_color", color)
	if thought:
		_bark_text.add_theme_font_override(&"normal_font", _thought_font)
		_bark_text.add_theme_color_override(&"default_color", UiKit.GOLD)
	else:
		_bark_text.remove_theme_font_override(&"normal_font")
		_bark_text.add_theme_color_override(&"default_color", UiKit.TEXT)
	_bark_text.text = "[center]%s[/center]" % text
	_fade_to(_bark_box, &"bark", 1.0, 0.2)


func hide_bark() -> void:
	_fade_to(_bark_box, &"bark", 0.0, 0.4)


# --- Таблички над головами --------------------------------------------------

## Имя и роль над персонажем: кто это, когда он впервые появляется в кадре. duration 0 — пока не уберут.
func tag(node: Node3D, title: String, subtitle: String, color: Color, height: float, duration: float) -> void:
	untag(node, 0.0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", -2)
	box.add_child(UiKit.outlined(UiKit.label(title, 28, color, HORIZONTAL_ALIGNMENT_CENTER), 7))
	if subtitle != "":
		box.add_child(UiKit.outlined(UiKit.label(subtitle, 17, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER), 6))
	box.modulate.a = 0.0
	root.add_child(box)
	_tags.append({"node": node, "box": box, "h": height})
	_place_tag(_tags.back())
	var tw := box.create_tween().set_ignore_time_scale(true)
	tw.tween_property(box, "modulate:a", 1.0, 0.4)
	if duration > 0.0:
		tw.tween_interval(duration)
		tw.tween_property(box, "modulate:a", 0.0, 0.6)
		tw.tween_callback(box.queue_free)


func untag(node: Node3D, dur: float = 0.4) -> void:
	for e in _tags:
		if e["node"] == node and is_instance_valid(e["box"]):
			var box: Control = e["box"]
			if dur <= 0.0:
				box.queue_free()
			else:
				var tw := box.create_tween().set_ignore_time_scale(true)
				tw.tween_property(box, "modulate:a", 0.0, dur)
				tw.tween_callback(box.queue_free)


func clear_tags() -> void:
	for e in _tags:
		if is_instance_valid(e["box"]):
			(e["box"] as Control).queue_free()
	_tags.clear()


func _process(_delta: float) -> void:
	if _tags.is_empty():
		return
	for e in _tags:
		if not is_instance_valid(e["node"]) and is_instance_valid(e["box"]):
			(e["box"] as Control).queue_free()
	_tags = _tags.filter(func(e): return is_instance_valid(e["box"]) and is_instance_valid(e["node"]))
	for e in _tags:
		_place_tag(e)


func _place_tag(e: Dictionary) -> void:
	var box: Control = e["box"]
	var node: Node3D = e["node"]
	var cam := get_viewport().get_camera_3d()
	var p3 := node.global_position + Vector3(0, float(e["h"]), 0)
	if cam == null or cam.is_position_behind(p3) or not node.is_visible_in_tree():
		box.visible = false
		return
	box.visible = true
	box.reset_size()
	box.position = cam.unproject_position(p3) - Vector2(box.size.x * 0.5, box.size.y)
