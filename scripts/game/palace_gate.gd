class_name PalaceGate
extends Node3D
## Ворота дворца Тирана на краю арены: две башни со стягами Сигварда, арка, тёмный проём и решётка.
## Проём смотрит в +Z — поставьте ворота так, чтобы +Z был направлен к центру арены.

const OPENING := Vector2(3.2, 3.8)

var _portcullis: Node3D


func _ready() -> void:
	var brick := Color(0.7, 0.66, 0.64)
	var dark := Color(0.02, 0.012, 0.02)
	var purple := Color(0.3, 0.1, 0.36)
	var gold := Color(0.95, 0.76, 0.32)
	var iron := Color(0.4, 0.4, 0.44)
	# Тёмный проём и пол под аркой.
	add_child(LowPoly.box(Vector3(OPENING.x, OPENING.y, 0.2), dark, Vector3(0, OPENING.y * 0.5, -0.9)))
	add_child(LowPoly.box(Vector3(OPENING.x + 0.4, 0.06, 2.2), Color(0.45, 0.42, 0.4), Vector3(0, 0.03, 0), 0.95, 0.0, 0.0, &"stone"))
	add_child(LowPoly.box(Vector3(4.6, 0.16, 1.0), Color(0.6, 0.56, 0.54), Vector3(0, 0.08, 1.4), 0.95, 0.0, 0.0, &"stone"))
	# Арка над проёмом.
	add_child(LowPoly.box(Vector3(OPENING.x + 0.6, 2.3, 2.0), brick, Vector3(0, OPENING.y + 1.15, 0), 0.95, 0.0, 0.0, &"brick"))
	add_child(LowPoly.prism(Vector3(OPENING.x + 0.6, 1.1, 2.0), brick, Vector3(0, OPENING.y + 2.85, 0), 0.95, 0.0, 0.0, &"brick"))
	# Кольцо из семи над аркой — как на щите героя, только в золоте Тирана.
	var ring := LowPoly.torus(0.42, 0.54, 16, 4, gold, Vector3(0, OPENING.y + 1.15, 1.02), 0.4, 0.8, 0.6, &"gold")
	ring.rotation.x = PI / 2
	add_child(ring)
	for k in 7:
		var a := TAU * k / 7.0 + PI / 2
		add_child(LowPoly.box(Vector3(0.12, 0.12, 0.06), Color(0.6, 0.08, 0.1), Vector3(cos(a) * 0.48, OPENING.y + 1.15 + sin(a) * 0.48, 1.06), 0.9, 0.0, 0.8))
	for side in [-1.0, 1.0]:
		_tower(side, brick, purple, gold)
		# Глухая стена дальше от ворот.
		add_child(LowPoly.box(Vector3(4.2, 4.2, 1.4), brick.darkened(0.08), Vector3(side * 5.6, 2.1, -0.3), 0.95, 0.0, 0.0, &"brick"))
		for k in 4:
			add_child(LowPoly.box(Vector3(0.5, 0.45, 1.4), brick.darkened(0.08), Vector3(side * (4.0 + k * 1.05), 4.42, -0.3), 0.95, 0.0, 0.0, &"brick"))
		_torch(Vector3(side * 2.05, 2.6, 1.3))
	_portcullis = LowPoly.pivot("Portcullis", Vector3(0, 0, 0.55))
	add_child(_portcullis)
	for k in 7:
		var x := -OPENING.x * 0.5 + 0.25 + k * (OPENING.x - 0.5) / 6.0
		_portcullis.add_child(LowPoly.box(Vector3(0.09, OPENING.y, 0.09), iron, Vector3(x, OPENING.y * 0.5, 0), 0.6, 0.6, 0.0, &"rust"))
		_portcullis.add_child(LowPoly.pyramid(Vector2(0.12, 0.12), 0.22, iron, Vector3(x, -0.05, 0), &"rust", 0.6))
	for k in 4:
		_portcullis.add_child(LowPoly.box(Vector3(OPENING.x, 0.08, 0.08), iron, Vector3(0, 0.6 + k * 0.95, 0.05), 0.6, 0.6, 0.0, &"rust"))


func _tower(side: float, brick: Color, purple: Color, gold: Color) -> void:
	var x := side * (OPENING.x * 0.5 + 1.0)
	add_child(LowPoly.box(Vector3(2.0, 6.6, 2.3), brick, Vector3(x, 3.3, 0), 0.95, 0.0, 0.0, &"brick"))
	for k in 4:
		var cx := x - 0.75 + (k % 2) * 1.5
		var cz := -0.85 + (k / 2) * 1.7
		add_child(LowPoly.box(Vector3(0.5, 0.55, 0.5), brick, Vector3(cx, 6.88, cz), 0.95, 0.0, 0.0, &"brick"))
	add_child(LowPoly.box(Vector3(0.14, 0.6, 0.05), Color(1.0, 0.55, 0.2), Vector3(x, 5.2, 1.16), 0.5, 0.0, 3.0))
	# Стяг Сигварда: пурпур с золотой полосой.
	add_child(LowPoly.frustum(Vector2(1.0, 0.04), Vector2(1.1, 0.04), 2.8, purple, Vector3(x, 3.0, 1.18), &"cloth"))
	add_child(LowPoly.box(Vector3(0.14, 2.7, 0.03), gold, Vector3(x, 3.0, 1.21), 0.5, 0.6, 0.4, &"gold"))
	add_child(LowPoly.prism(Vector3(1.0, 0.35, 0.05), purple, Vector3(x, 1.45, 1.18), 0.9, 0.0, 0.0, &"cloth"))


func _torch(pos: Vector3) -> void:
	add_child(LowPoly.box(Vector3(0.1, 0.5, 0.1), Color(0.35, 0.25, 0.18), pos, 0.9, 0.0, 0.0, &"wood"))
	add_child(LowPoly.prism(Vector3(0.18, 0.3, 0.18), Color(1.0, 0.55, 0.15), pos + Vector3(0, 0.38, 0), 0.5, 0.0, 4.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 1.4
	light.omni_range = 4.5
	light.position = pos + Vector3(0, 0.5, 0.3)
	add_child(light)


## Решётка уходит вверх, в арку (проём остаётся выше человеческого роста). dur 0 — сразу.
func open(dur: float = 2.2) -> void:
	var up := 2.4
	if dur <= 0.0:
		_portcullis.position.y = up
		return
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_portcullis, "position:y", up, dur)


func is_open() -> bool:
	return _portcullis.position.y > 0.1
