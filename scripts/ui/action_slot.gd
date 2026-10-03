class_name ActionSlot
extends Control
## Ячейка панели действий: иконка вещи, клавиша, откат. Пожертвованная вещь перечёркнута.

var item_id: StringName
var key_text: String = ""
var actor: Actor
var crossed: bool = false
var fallback_text: String = ""
var _flash: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(76, 100)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash() -> void:
	_flash = 0.25


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _component() -> ActionComponent:
	if actor == null or not is_instance_valid(actor):
		return null
	return actor.component(item_id)


func _draw() -> void:
	var r := Rect2(Vector2(1, 1), Vector2(74, 74))
	var font := get_theme_default_font()
	var def := Db.item(item_id)
	var comp := _component()
	crossed = comp == null
	var border := def.essence.color if not crossed else Color(0.35, 0.3, 0.3)
	draw_rect(r, Color(0.08, 0.07, 0.09, 0.9))
	var tex := IconFactory.icon(item_id)
	var tint := Color(1, 1, 1, 1) if not crossed else Color(0.45, 0.42, 0.42, 0.7)
	if tex != null:
		draw_texture_rect(tex, r.grow(-4), false, tint)
	else:
		draw_string(get_theme_default_font(), Vector2(4, 40), def.display_name.substr(0, 3), HORIZONTAL_ALIGNMENT_CENTER, 58, 18, tint)
	var cooling := comp != null and comp.cooldown_left > 0.0
	if cooling:
		var h := r.size.y * comp.cooldown_ratio()
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - h), Vector2(r.size.x, h)), Color(0, 0, 0, 0.8))
	if comp is ShieldAction and (comp as ShieldAction).holding:
		draw_rect(r, Color(1.0, 0.8, 0.3, 0.18))
	if _flash > 0.0:
		draw_rect(r, Color(1, 1, 1, _flash * 1.6))
	draw_rect(r, Color(1.0, 0.7, 0.3) if cooling else border, false, 2.0)
	if crossed:
		draw_line(r.position + Vector2(6, 6), r.end - Vector2(6, 6), UiKit.DANGER, 4.0, true)
		draw_line(Vector2(r.end.x - 6, r.position.y + 6), Vector2(r.position.x + 6, r.end.y - 6), UiKit.DANGER, 4.0, true)
	elif comp != null and comp.item != null and comp.item.properties.size() > 0:
		var badge := Rect2(r.end.x - 32, r.position.y + 3, 29, 21)
		draw_rect(badge, Color(0.08, 0.06, 0.04, 0.95))
		draw_rect(badge, UiKit.GOLD, false, 1.0)
		draw_string(font, badge.position + Vector2(0, 16), UiKit.roman(comp.item.properties.size()), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 16, UiKit.GOLD)
	if not crossed:
		draw_string_outline(font, Vector2(5, 19), UiKit.roman(comp.item.appearance), HORIZONTAL_ALIGNMENT_LEFT, 32, 17, 4, Color.BLACK)
		draw_string(font, Vector2(5, 19), UiKit.roman(comp.item.appearance), HORIZONTAL_ALIGNMENT_LEFT, 32, 17, UiKit.GOLD)
		var lv := Mastery.level(item_id)
		var progress := 1.0 if lv == 3 else float(Mastery.xp.get(item_id, 0)) / float(Mastery.rules["thresholds"][lv])
		draw_rect(Rect2(2, r.end.y - 4, (r.size.x - 2) * progress, 3), UiKit.GOLD)
	if cooling:
		# Округляем вверх: до готовности никогда не показываем ноль.
		var seconds := ceili(comp.cooldown_left * 10.0) / 10.0
		var countdown := "%.1f" % seconds if seconds < 10.0 else str(ceili(seconds))
		var at := Vector2(1, 53)
		draw_rect(Rect2(7, 29, 62, 29), Color(0.025, 0.02, 0.03, 0.85))
		draw_string_outline(UiKit.bold_font(), at, countdown, HORIZONTAL_ALIGNMENT_CENTER, 74, 27, 6, Color.BLACK)
		draw_string(UiKit.bold_font(), at, countdown, HORIZONTAL_ALIGNMENT_CENTER, 74, 27, Color.WHITE)
		draw_rect(Rect2(1, 79, 74, 5), Color(0.02, 0.02, 0.025, 0.95))
		draw_rect(Rect2(1, 79, 74 * (1.0 - comp.cooldown_ratio()), 5), Color(1.0, 0.7, 0.3))
	var label := key_text if not crossed or fallback_text == "" else fallback_text
	draw_string(font, Vector2(0, 98), label, HORIZONTAL_ALIGNMENT_CENTER, 76, 15, UiKit.TEXT if not crossed else UiKit.MUTED)
