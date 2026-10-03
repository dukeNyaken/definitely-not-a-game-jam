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
	custom_minimum_size = Vector2(66, 86)
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
	var r := Rect2(Vector2(1, 1), Vector2(64, 64))
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
	if comp != null and comp.cooldown_ratio() > 0.0:
		var h := 64.0 * comp.cooldown_ratio()
		draw_rect(Rect2(Vector2(1, 1 + 64 - h), Vector2(64, h)), Color(0, 0, 0, 0.6))
	if comp is ShieldAction and (comp as ShieldAction).holding:
		draw_rect(r, Color(1.0, 0.8, 0.3, 0.18))
	if _flash > 0.0:
		draw_rect(r, Color(1, 1, 1, _flash * 1.6))
	draw_rect(r, border, false, 2.0)
	if crossed:
		draw_line(r.position + Vector2(6, 6), r.end - Vector2(6, 6), UiKit.DANGER, 4.0, true)
		draw_line(Vector2(r.end.x - 6, r.position.y + 6), Vector2(r.position.x + 6, r.end.y - 6), UiKit.DANGER, 4.0, true)
	elif comp != null and comp.item != null and comp.item.properties.size() > 0:
		var bp := Vector2(r.end.x - 4, r.position.y + 4)
		draw_circle(bp, 10.0, UiKit.GOLD)
		draw_string(get_theme_default_font(), bp + Vector2(-10, 5), str(comp.item.properties.size()), HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.1, 0.07, 0.05))
	if not crossed:
		draw_string(get_theme_default_font(), Vector2(4, 17), "I".repeat(comp.item.appearance), HORIZONTAL_ALIGNMENT_LEFT, 42, 16, UiKit.GOLD)
		var lv := Mastery.level(item_id)
		var progress := 1.0 if lv == 3 else float(Mastery.xp.get(item_id, 0)) / float(Mastery.rules["thresholds"][lv])
		draw_rect(Rect2(2, 61, 62 * progress, 3), UiKit.GOLD)
	var font := get_theme_default_font()
	var label := key_text if not crossed or fallback_text == "" else fallback_text
	draw_string(font, Vector2(0, 82), label, HORIZONTAL_ALIGNMENT_CENTER, 66, 15, UiKit.TEXT if not crossed else UiKit.MUTED)
