class_name SetPieces
extends RefCounted
## Декорации сюжетных сцен из примитивов LowPoly: двор крепости (стойка с мечами, чучело),
## покои ярла (свеча), тронный зал Сигварда (трон, жаровни, стяги, окна в зареве)
## и мелкий реквизит (письмо, хлеб, фляга).

const WOOD := Color(0.5, 0.36, 0.24)
const DARK_WOOD := Color(0.24, 0.15, 0.12)
const STONE := Color(0.46, 0.43, 0.43)
const IRON := Color(0.38, 0.38, 0.42)
const PURPLE := Color(0.3, 0.1, 0.36)
const GOLD := Color(0.95, 0.76, 0.32)
const FIRE := Color(1.0, 0.5, 0.18)


## Стойка с деревянными мечами.
static func weapon_rack() -> Node3D:
	var r := LowPoly.pivot("WeaponRack")
	for x in [-0.62, 0.62]:
		r.add_child(LowPoly.box(Vector3(0.1, 1.15, 0.1), WOOD, Vector3(x, 0.57, 0), 0.9, 0.0, 0.0, &"wood"))
	for y in [0.35, 1.0]:
		r.add_child(LowPoly.box(Vector3(1.4, 0.08, 0.12), WOOD.darkened(0.15), Vector3(0, y, 0), 0.9, 0.0, 0.0, &"wood"))
	for k in 3:
		var s := NpcLooks.wooden_sword()
		s.rotation = Vector3(0.12, 0.0, deg_to_rad(10.0 - k * 9.0))
		s.position = Vector3(-0.36 + k * 0.36, 0.12, 0.1)
		r.add_child(s)
	return r


## Чучело для учебных боёв: столб, перекладина, мешок соломы.
static func training_post() -> Node3D:
	var r := LowPoly.pivot("TrainingPost")
	r.add_child(LowPoly.cyl(0.08, 0.1, 1.8, 6, WOOD, Vector3(0, 0.9, 0), 0.9, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.box(Vector3(0.95, 0.09, 0.09), WOOD.darkened(0.1), Vector3(0, 1.38, 0), 0.9, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.cyl(0.2, 0.25, 0.62, 7, Color(0.78, 0.66, 0.4), Vector3(0, 0.98, 0), 1.0, 0.0, 0.0, &"cloth"))
	r.add_child(LowPoly.sphere(0.16, 6, 4, Color(0.78, 0.66, 0.4), Vector3(0, 1.62, 0), 1.0, 0.0, 0.0, &"cloth"))
	return r


## Высокий подсвечник у ложа ярла. Свет и огонь ставит сцена: огонь — над точкой flame_height().
static func candle_stand() -> Node3D:
	var r := LowPoly.pivot("CandleStand")
	r.add_child(LowPoly.cyl(0.18, 0.24, 0.08, 6, IRON, Vector3(0, 0.04, 0), 0.6, 0.5, 0.0, &"rust"))
	r.add_child(LowPoly.cyl(0.03, 0.04, 1.3, 5, IRON, Vector3(0, 0.69, 0), 0.6, 0.5, 0.0, &"rust"))
	r.add_child(LowPoly.cyl(0.12, 0.08, 0.06, 6, IRON, Vector3(0, 1.36, 0), 0.6, 0.5, 0.0, &"rust"))
	r.add_child(LowPoly.cyl(0.05, 0.05, 0.22, 6, Color(0.95, 0.9, 0.78), Vector3(0, 1.5, 0), 0.8, 0.0, 0.2))
	r.add_child(LowPoly.prism(Vector3(0.05, 0.1, 0.05), FIRE, Vector3(0, 1.66, 0), 0.5, 0.0, 4.0))
	return r


static func flame_height() -> float:
	return 1.66


## Трон Сигварда на двухступенчатом помосте. Смотрит в +Z.
static func throne() -> Node3D:
	var r := LowPoly.pivot("Throne")
	r.add_child(LowPoly.box(Vector3(3.0, 0.2, 2.4), STONE, Vector3(0, 0.1, 0), 0.95, 0.0, 0.0, &"stone"))
	r.add_child(LowPoly.box(Vector3(2.2, 0.2, 1.7), STONE.lightened(0.05), Vector3(0, 0.3, -0.2), 0.95, 0.0, 0.0, &"stone"))
	r.add_child(LowPoly.box(Vector3(1.2, 0.5, 0.9), DARK_WOOD, Vector3(0, 0.65, -0.3), 0.8, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.box(Vector3(1.0, 0.08, 0.75), PURPLE, Vector3(0, 0.94, -0.28), 0.9, 0.0, 0.0, &"cloth"))
	r.add_child(LowPoly.box(Vector3(1.2, 2.4, 0.2), DARK_WOOD, Vector3(0, 1.6, -0.75), 0.8, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.box(Vector3(0.9, 1.7, 0.05), PURPLE, Vector3(0, 1.5, -0.63), 0.9, 0.0, 0.0, &"cloth"))
	r.add_child(LowPoly.prism(Vector3(1.3, 0.5, 0.22), GOLD, Vector3(0, 3.05, -0.75), 0.4, 0.8, 0.4, &"gold"))
	for x in [-0.62, 0.62]:
		r.add_child(LowPoly.box(Vector3(0.16, 0.32, 0.9), DARK_WOOD, Vector3(x, 1.06, -0.3), 0.8, 0.0, 0.0, &"wood"))
		r.add_child(LowPoly.sphere(0.1, 6, 4, GOLD, Vector3(x, 1.26, 0.12), 0.4, 0.8, 0.4, &"gold"))
		r.add_child(LowPoly.cyl(0.06, 0.06, 2.6, 5, GOLD, Vector3(x, 1.5, -0.75), 0.4, 0.8, 0.3, &"gold"))
	# Кольцо из семи — как над воротами.
	var ring := LowPoly.torus(0.24, 0.32, 14, 4, GOLD, Vector3(0, 2.35, -0.6), 0.4, 0.8, 0.6, &"gold")
	ring.rotation.x = PI / 2
	r.add_child(ring)
	for k in 7:
		var a := TAU * k / 7.0 + PI / 2
		r.add_child(LowPoly.box(Vector3(0.07, 0.07, 0.04), Color(0.6, 0.08, 0.1), Vector3(cos(a) * 0.28, 2.35 + sin(a) * 0.28, -0.57), 0.9, 0.0, 0.8))
	return r


## Жаровня на треноге. Огонь и свет добавляет brazier_fire().
static func brazier() -> Node3D:
	var r := LowPoly.pivot("Brazier")
	for k in 3:
		var a := TAU * k / 3.0
		var leg := LowPoly.box(Vector3(0.07, 1.0, 0.07), IRON, Vector3(cos(a) * 0.22, 0.45, sin(a) * 0.22), 0.6, 0.5, 0.0, &"rust")
		leg.rotation = Vector3(sin(a) * 0.2, 0.0, -cos(a) * 0.2)
		r.add_child(leg)
	r.add_child(LowPoly.cyl(0.42, 0.24, 0.3, 8, IRON, Vector3(0, 1.0, 0), 0.6, 0.5, 0.0, &"rust"))
	r.add_child(LowPoly.cyl(0.36, 0.36, 0.05, 8, Color(1.0, 0.45, 0.12), Vector3(0, 1.13, 0), 0.5, 0.0, 3.0))
	return r


## Огонь и живой свет над жаровней. Возвращает свет — им можно разжечь или пригасить пламя.
static func brazier_fire(b: Node3D, energy: float = 2.2) -> OmniLight3D:
	var top := b.global_position + Vector3(0, 1.15, 0)
	var f := CutsceneFx.fire(b, top, 0.55)
	f.name = "Fire"
	return CutsceneFx.light(b, top + Vector3(0, 0.6, 0), Color(1.0, 0.45, 0.22), energy, 7.0, 0.14)


## Стяг Сигварда на древке.
static func banner() -> Node3D:
	var r := LowPoly.pivot("Banner")
	r.add_child(LowPoly.cyl(0.04, 0.05, 3.6, 5, DARK_WOOD, Vector3(0, 1.8, 0), 0.8, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.box(Vector3(1.0, 0.06, 0.06), GOLD, Vector3(0, 3.45, 0.05), 0.4, 0.8, 0.3, &"gold"))
	r.add_child(LowPoly.frustum(Vector2(0.95, 0.04), Vector2(0.95, 0.04), 2.2, PURPLE, Vector3(0, 2.3, 0.08), &"cloth"))
	r.add_child(LowPoly.box(Vector3(0.12, 2.1, 0.03), GOLD, Vector3(0, 2.3, 0.11), 0.5, 0.6, 0.4, &"gold"))
	r.add_child(LowPoly.prism(Vector3(0.95, 0.35, 0.04), PURPLE, Vector3(0, 1.05, 0.08), 0.9, 0.0, 0.0, &"cloth"))
	return r


## Стрельчатое окно, за которым — зарево. Смотрит в +Z.
static func glow_window(glow: Color = Color(0.9, 0.22, 0.12)) -> Node3D:
	var r := LowPoly.pivot("Window")
	r.add_child(LowPoly.box(Vector3(1.0, 2.2, 0.1), glow, Vector3(0, 2.4, 0), 0.9, 0.0, 1.6))
	r.add_child(LowPoly.prism(Vector3(1.0, 0.5, 0.1), glow, Vector3(0, 3.75, 0), 0.9, 0.0, 1.6))
	r.add_child(LowPoly.box(Vector3(0.07, 2.6, 0.14), IRON, Vector3(0, 2.6, 0.04), 0.6, 0.5, 0.0, &"rust"))
	r.add_child(LowPoly.box(Vector3(1.0, 0.07, 0.14), IRON, Vector3(0, 2.6, 0.04), 0.6, 0.5, 0.0, &"rust"))
	r.add_child(LowPoly.box(Vector3(1.3, 0.16, 0.3), STONE, Vector3(0, 1.25, 0.1), 0.95, 0.0, 0.0, &"stone"))
	return r


## Тронный зал: пол, ковёр, задняя стена с окнами, колонны, трон, стяги, жаровни.
## Возвращает узел зала; жаровни — в meta "braziers" (свет каждой — в meta "light").
static func throne_hall() -> Node3D:
	var hall := LowPoly.pivot("ThroneHall")
	var floor_mi := LowPoly.cyl(7.5, 7.5, 0.3, 18, Color(0.22, 0.2, 0.21), Vector3(0, -0.15, 0), 0.95, 0.0, 0.0, &"stone")
	hall.add_child(floor_mi)
	hall.add_child(LowPoly.box(Vector3(1.5, 0.03, 9.0), PURPLE.darkened(0.15), Vector3(0, 0.015, 1.0), 0.95, 0.0, 0.0, &"cloth"))
	for x in [-0.78, 0.78]:
		hall.add_child(LowPoly.box(Vector3(0.08, 0.035, 9.0), GOLD.darkened(0.2), Vector3(x, 0.02, 1.0), 0.5, 0.6, 0.2, &"gold"))
	hall.add_child(LowPoly.box(Vector3(14.0, 7.0, 0.6), Color(0.42, 0.36, 0.36), Vector3(0, 3.5, -4.6), 0.95, 0.0, 0.0, &"brick"))
	for x in [-4.4, -2.2, 2.2, 4.4]:
		var w := glow_window()
		w.position = Vector3(x, 0, -4.25)
		hall.add_child(w)
	for x in [-5.6, -3.3, 3.3, 5.6]:
		hall.add_child(LowPoly.cyl(0.32, 0.38, 6.5, 8, STONE, Vector3(x, 3.25, -3.9), 0.95, 0.0, 0.0, &"stone"))
	var throne := throne()
	throne.position = Vector3(0, 0, -2.6)
	hall.add_child(throne)
	for x in [-1.7, 1.7]:
		var b := banner()
		b.position = Vector3(x, 0, -3.6)
		hall.add_child(b)
	var braziers: Array[Node3D] = []
	for x in [-2.6, 2.6]:
		var br := brazier()
		br.position = Vector3(x, 0, -0.6)
		hall.add_child(br)
		braziers.append(br)
	hall.set_meta(&"braziers", braziers)
	return hall


## Письмо с багровой печатью.
static func letter() -> Node3D:
	var r := LowPoly.pivot("Letter")
	r.add_child(LowPoly.box(Vector3(0.22, 0.3, 0.015), Color(0.92, 0.86, 0.72), Vector3(0, 0.12, 0), 0.9, 0.0, 0.1))
	r.add_child(LowPoly.cyl(0.035, 0.035, 0.02, 6, Color(0.6, 0.06, 0.08), Vector3(0, 0.06, 0.012), 0.6, 0.0, 0.3))
	r.rotation.x = deg_to_rad(-70)
	return r


## Хлеб в холщовом узелке.
static func bread() -> Node3D:
	var r := LowPoly.pivot("Bread")
	r.add_child(LowPoly.sphere(0.13, 6, 4, Color(0.82, 0.76, 0.62), Vector3.ZERO, 1.0, 0.0, 0.0, &"cloth"))
	r.add_child(LowPoly.pyramid(Vector2(0.08, 0.08), 0.1, Color(0.82, 0.76, 0.62), Vector3(0, 0.12, 0), &"cloth"))
	return r


## Кожаная фляга.
static func flask() -> Node3D:
	var r := LowPoly.pivot("Flask")
	r.add_child(LowPoly.sphere(0.12, 6, 4, Color(0.45, 0.3, 0.2), Vector3.ZERO, 0.9, 0.0, 0.0, &"leather"))
	r.add_child(LowPoly.cyl(0.03, 0.04, 0.1, 5, Color(0.35, 0.24, 0.16), Vector3(0, 0.14, 0), 0.9, 0.0, 0.0, &"wood"))
	return r
