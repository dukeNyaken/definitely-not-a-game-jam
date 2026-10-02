class_name WorldOverlay
extends Control
## Поверх 3D: полоски здоровья врагов и всплывающие цифры урона.

var camera: Camera3D
var _numbers: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(self)


func _process(delta: float) -> void:
	for a in Combat.living_actors(get_tree()):
		if not a.has_meta(&"overlay_hooked"):
			a.set_meta(&"overlay_hooked", true)
			a.hit_received.connect(_on_hit.bind(a))
			a.blocked.connect(_on_blocked.bind(a))
	for n in _numbers:
		n["t"] = float(n["t"]) + delta
	_numbers = _numbers.filter(func(n): return float(n["t"]) < 0.9)
	queue_redraw()


func _on_hit(amount: float, crit: bool, _ctx: ActionContext, a: Actor) -> void:
	if not is_instance_valid(a):
		return
	var col := Color(1, 0.95, 0.85)
	if a.faction == Actor.Faction.HERO:
		col = Color(1, 0.35, 0.3)
	elif crit:
		col = Color(0.85, 0.55, 1.0)
	var text := str(int(round(amount)))
	if crit:
		text += "!"
	_numbers.append({"pos": a.global_position + Vector3(randf_range(-0.3, 0.3), 2.0 * _height(a), 0), "text": text, "color": col, "t": 0.0, "size": 30 if crit else 22})


func _on_blocked(_ctx: ActionContext, a: Actor) -> void:
	if is_instance_valid(a):
		_numbers.append({"pos": a.global_position + Vector3(0, 2.0 * _height(a), 0), "text": "блок", "color": Color(1.0, 0.8, 0.35), "t": 0.0, "size": 20})


func _height(a: Actor) -> float:
	if a.has_meta(&"boss"):
		return 1.8
	if a.has_meta(&"enemy_def"):
		return (a.get_meta(&"enemy_def") as EnemyDef).scale
	return 1.0


func _draw() -> void:
	if camera == null or not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
		if camera == null:
			return
	var font := get_theme_default_font()
	for a in Combat.living_actors(get_tree()):
		if a.faction == Actor.Faction.HERO or a.has_meta(&"boss"):
			continue
		var elite: bool = a.get_meta(&"elite", false)
		if a.hp >= a.max_hp and not elite:
			continue
		var p3 := a.global_position + Vector3(0, 2.15 * _height(a) * (1.2 if elite else 1.0), 0)
		if camera.is_position_behind(p3):
			continue
		var p := camera.unproject_position(p3)
		var w := 64.0 if elite else 44.0
		var r := Rect2(p - Vector2(w * 0.5, 0), Vector2(w, 6))
		draw_rect(r.grow(1), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(r.position, Vector2(w * clampf(a.hp / a.max_hp, 0, 1), 6)), Color(0.9, 0.25, 0.2) if not elite else Color(1.0, 0.75, 0.3))
		if a.armor > 0.0 and a.max_armor > 0.0:
			draw_rect(Rect2(r.position - Vector2(0, 4), Vector2(w * a.armor / a.max_armor, 3)), UiKit.ARMOR)
	for n in _numbers:
		var t: float = n["t"]
		var p3: Vector3 = n["pos"] + Vector3(0, t * 1.4, 0)
		if camera.is_position_behind(p3):
			continue
		var p := camera.unproject_position(p3)
		var col: Color = n["color"]
		col.a = 1.0 - maxf(t - 0.5, 0.0) * 2.5
		var sz: int = n["size"]
		draw_string_outline(font, p + Vector2(-50, 0), n["text"], HORIZONTAL_ALIGNMENT_CENTER, 100, sz, 6, Color(0, 0, 0, col.a * 0.8))
		draw_string(font, p + Vector2(-50, 0), n["text"], HORIZONTAL_ALIGNMENT_CENTER, 100, sz, col)
