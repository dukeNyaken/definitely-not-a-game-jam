class_name SetPieces
extends RefCounted
## Декорации сюжетных сцен из примитивов LowPoly: двор крепости (стойка с мечами, чучело),
## покои ярла (свеча), тронный зал Сигварда (трон, жаровни, стяги, окна в зареве),
## дом Сольвейг (очаг, окно в ночь, стол, прялка, сундук с приданым)
## и мелкий реквизит (письмо, хлеб, фляга, кошель).

const WOOD := Color(0.5, 0.36, 0.24)
const DARK_WOOD := Color(0.24, 0.15, 0.12)
const LOG := Color(0.4, 0.29, 0.21)
const PLANK := Color(0.34, 0.25, 0.19)
const STONE := Color(0.46, 0.43, 0.43)
const IRON := Color(0.38, 0.38, 0.42)
const PURPLE := Color(0.3, 0.1, 0.36)
const GOLD := Color(0.95, 0.76, 0.32)
const FIRE := Color(1.0, 0.5, 0.18)
const SNOW := Color(0.8, 0.86, 0.96)
const ICE := Color(0.56, 0.74, 0.9)
const FIR := Color(0.13, 0.27, 0.21)


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


## Каменный очаг с котлом на крюке. Огонь и свет ставит сцена — в точке hearth_fire_point().
static func hearth() -> Node3D:
	var r := LowPoly.pivot("Hearth")
	r.add_child(LowPoly.box(Vector3(2.5, 0.14, 1.4), STONE, Vector3(0, 0.07, 0.2), 0.95, 0.0, 0.0, &"stone"))
	for x in [-0.92, 0.92]:
		r.add_child(LowPoly.box(Vector3(0.46, 1.3, 0.8), STONE, Vector3(x, 0.79, 0), 0.95, 0.0, 0.0, &"stone"))
	r.add_child(LowPoly.box(Vector3(1.4, 1.3, 0.12), Color(0.1, 0.08, 0.08), Vector3(0, 0.79, -0.34), 0.95))
	r.add_child(LowPoly.box(Vector3(2.6, 0.32, 0.96), STONE.lightened(0.06), Vector3(0, 1.6, 0.03), 0.95, 0.0, 0.0, &"stone"))
	r.add_child(LowPoly.frustum(Vector2(2.3, 0.86), Vector2(1.0, 0.6), 1.7, STONE.darkened(0.1), Vector3(0, 2.61, -0.05), &"stone"))
	# Поленья и жар под котлом.
	for k in 2:
		var billet := LowPoly.cyl(0.08, 0.09, 0.9, 6, WOOD.darkened(0.35), Vector3(0, 0.24 + k * 0.1, 0.08 - k * 0.14), 0.95, 0.0, 0.0, &"wood")
		billet.rotation = Vector3(0, 0.3 - k * 0.7, PI / 2)
		r.add_child(billet)
	r.add_child(LowPoly.box(Vector3(0.95, 0.05, 0.45), FIRE, Vector3(0, 0.17, 0.04), 0.5, 0.0, 3.0))
	r.add_child(LowPoly.box(Vector3(0.03, 0.5, 0.03), IRON, Vector3(0, 1.2, 0.06), 0.6, 0.5, 0.0, &"rust"))
	r.add_child(LowPoly.cyl(0.25, 0.17, 0.3, 8, IRON.darkened(0.35), Vector3(0, 0.84, 0.06), 0.6, 0.5, 0.0, &"rust"))
	return r


## Где горит огонь в очаге (в координатах очага).
static func hearth_fire_point() -> Vector3:
	return Vector3(0, 0.32, 0.06)


## Окно в холодную ночь с распахнутыми ставнями. Смотрит в +Z.
static func night_window(glow: Color = Color(0.3, 0.46, 0.95)) -> Node3D:
	var r := LowPoly.pivot("NightWindow")
	r.add_child(LowPoly.box(Vector3(1.0, 1.1, 0.08), glow, Vector3(0, 1.95, 0), 0.9, 0.0, 1.0))
	r.add_child(LowPoly.box(Vector3(0.06, 1.1, 0.12), DARK_WOOD, Vector3(0, 1.95, 0.03), 0.9, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.box(Vector3(1.0, 0.06, 0.12), DARK_WOOD, Vector3(0, 1.95, 0.03), 0.9, 0.0, 0.0, &"wood"))
	for y in [1.36, 2.54]:
		r.add_child(LowPoly.box(Vector3(1.24, 0.1, 0.18), DARK_WOOD, Vector3(0, y, 0.04), 0.9, 0.0, 0.0, &"wood"))
	for x in [-0.56, 0.56]:
		r.add_child(LowPoly.box(Vector3(0.1, 1.28, 0.18), DARK_WOOD, Vector3(x, 1.95, 0.04), 0.9, 0.0, 0.0, &"wood"))
		var shutter := LowPoly.box(Vector3(0.5, 1.1, 0.05), WOOD.darkened(0.2), Vector3(x * 1.8, 1.95, 0.14), 0.9, 0.0, 0.0, &"wood")
		shutter.rotation.y = -signf(x) * 0.5
		r.add_child(shutter)
	r.add_child(LowPoly.box(Vector3(1.4, 0.08, 0.32), WOOD, Vector3(0, 1.29, 0.14), 0.9, 0.0, 0.0, &"wood"))
	return r


## Стол со свечой, миской и хлебом. Пламя свечи — узел "Flame"; фитиль — table_wick_point().
static func table() -> Node3D:
	var r := LowPoly.pivot("Table")
	r.add_child(LowPoly.box(Vector3(1.7, 0.08, 0.9), WOOD, Vector3(0, 0.8, 0), 0.9, 0.0, 0.0, &"wood"))
	for x in [-0.75, 0.75]:
		for z in [-0.36, 0.36]:
			r.add_child(LowPoly.box(Vector3(0.09, 0.76, 0.09), WOOD.darkened(0.2), Vector3(x, 0.38, z), 0.9, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.cyl(0.04, 0.045, 0.2, 6, Color(0.95, 0.9, 0.78), Vector3(0.1, 0.94, 0), 0.8, 0.0, 0.2))
	var flame := LowPoly.prism(Vector3(0.05, 0.1, 0.05), FIRE, table_wick_point(), 0.5, 0.0, 4.0)
	flame.name = "Flame"
	r.add_child(flame)
	r.add_child(LowPoly.cyl(0.15, 0.09, 0.08, 7, Color(0.55, 0.42, 0.3), Vector3(-0.5, 0.88, 0.1), 0.9, 0.0, 0.0, &"wood"))
	var loaf := bread()
	loaf.position = Vector3(0.55, 0.96, -0.08)
	r.add_child(loaf)
	return r


## Фитиль свечи на столе (в координатах стола).
static func table_wick_point() -> Vector3:
	return Vector3(0.1, 1.1, 0)


## Прялка: колесо (узел "Wheel") на станине и кудель на пряслице.
static func spinning_wheel() -> Node3D:
	var r := LowPoly.pivot("SpinningWheel")
	r.add_child(LowPoly.box(Vector3(1.0, 0.07, 0.3), WOOD, Vector3(0, 0.45, 0), 0.9, 0.0, 0.0, &"wood"))
	for x in [-0.42, 0.42]:
		r.add_child(LowPoly.box(Vector3(0.07, 0.45, 0.07), WOOD.darkened(0.2), Vector3(x, 0.22, 0), 0.9, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.box(Vector3(0.06, 0.55, 0.06), WOOD.darkened(0.2), Vector3(-0.2, 0.72, -0.09), 0.9, 0.0, 0.0, &"wood"))
	var wheel := LowPoly.pivot("Wheel", Vector3(-0.2, 0.95, 0))
	var rim := LowPoly.torus(0.3, 0.38, 12, 4, WOOD.darkened(0.15), Vector3.ZERO, 0.9, 0.0, 0.0, &"wood")
	rim.rotation.x = PI / 2
	wheel.add_child(rim)
	for k in 2:
		var spoke := LowPoly.box(Vector3(0.64, 0.03, 0.03), WOOD, Vector3.ZERO, 0.9, 0.0, 0.0, &"wood")
		spoke.rotation.z = k * PI / 2
		wheel.add_child(spoke)
	r.add_child(wheel)
	r.add_child(LowPoly.cyl(0.02, 0.02, 0.8, 5, WOOD, Vector3(0.38, 0.86, 0), 0.9, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.sphere(0.13, 6, 4, Color(0.88, 0.84, 0.74), Vector3(0.38, 1.24, 0), 1.0, 0.0, 0.0, &"cloth"))
	return r


## Сундук с приданым: всё, что у невесты есть.
static func chest() -> Node3D:
	var r := LowPoly.pivot("Chest")
	r.add_child(LowPoly.box(Vector3(1.15, 0.5, 0.62), DARK_WOOD.lightened(0.1), Vector3(0, 0.25, 0), 0.9, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.frustum(Vector2(1.19, 0.66), Vector2(1.0, 0.4), 0.22, DARK_WOOD, Vector3(0, 0.61, 0), &"wood"))
	for x in [-0.4, 0.4]:
		r.add_child(LowPoly.box(Vector3(0.08, 0.52, 0.65), GOLD.darkened(0.25), Vector3(x, 0.26, 0), 0.5, 0.6, 0.15, &"gold"))
	r.add_child(LowPoly.box(Vector3(0.14, 0.16, 0.05), GOLD, Vector3(0, 0.44, 0.32), 0.4, 0.8, 0.4, &"gold"))
	return r


## Дом Сольвейг: дощатый пол, бревенчатая стена с очагом и окном в ночь, стол со свечой, прялка
## у огня, сундук с приданым. Смотрит в +Z, как тронный зал. Узлы для сцены — в meta:
## "hearth", "window", "table", "wheel" (колесо прялки), "chest".
static func cottage() -> Node3D:
	var room := LowPoly.pivot("Cottage")
	# Пол и стена собраны из коротких досок и брёвен: в PS1 свет считается по вершинам,
	# и на одной большой грани пятно света от очага не получилось бы.
	for ix in 14:
		for iz in 4:
			var plank := LowPoly.box(Vector3(0.98, 0.2, 1.98), PLANK.darkened(0.07 * ((ix + iz) % 3)), Vector3(-6.5 + ix, -0.1, -2.5 + iz * 2.0), 0.95, 0.0, 0.0, &"wood")
			room.add_child(plank)
	for row in 7:
		for seg in 8:
			var x := -7.0 + seg * 2.0 + (1.0 if row % 2 == 1 else 0.0)
			room.add_child(LowPoly.box(Vector3(1.98, 0.48, 0.5), LOG.darkened(0.1 * ((row + seg) % 2)), Vector3(x, 0.25 + row * 0.5, -3.5), 0.95, 0.0, 0.0, &"wood"))
	room.add_child(LowPoly.box(Vector3(16.0, 0.3, 0.7), DARK_WOOD, Vector3(0, 3.65, -3.4), 0.9, 0.0, 0.0, &"wood"))
	for x in [-5.8, 5.8]:
		room.add_child(LowPoly.box(Vector3(0.32, 3.5, 0.32), DARK_WOOD, Vector3(x, 1.75, -3.15), 0.9, 0.0, 0.0, &"wood"))
	var fireplace := hearth()
	fireplace.position = Vector3(-2.6, 0, -2.95)
	room.add_child(fireplace)
	room.add_child(LowPoly.box(Vector3(1.9, 0.03, 1.2), Color(0.5, 0.2, 0.18), Vector3(-2.6, 0.015, -1.3), 0.95, 0.0, 0.0, &"cloth"))
	var window := night_window()
	window.position = Vector3(3.0, 0, -3.2)
	room.add_child(window)
	var desk := table()
	desk.position = Vector3(1.0, 0, -2.55)
	room.add_child(desk)
	var wheel := spinning_wheel()
	wheel.position = Vector3(-0.7, 0, -2.7)
	room.add_child(wheel)
	var dowry := chest()
	dowry.position = Vector3(4.7, 0, -2.4)
	dowry.rotation.y = -0.35
	room.add_child(dowry)
	# Полка с горшками и пучки трав под балкой.
	room.add_child(LowPoly.box(Vector3(1.6, 0.06, 0.3), WOOD, Vector3(1.0, 2.2, -3.1), 0.9, 0.0, 0.0, &"wood"))
	for k in 3:
		room.add_child(LowPoly.cyl(0.1, 0.13, 0.22 + 0.06 * (k % 2), 6, Color(0.6, 0.38, 0.26), Vector3(0.5 + k * 0.5, 2.35, -3.1), 0.9))
	for k in 4:
		var herbs := LowPoly.pyramid(Vector2(0.14, 0.14), 0.4, Color(0.38, 0.5, 0.28), Vector3(-5.2 + k * 0.3, 3.1, -3.12), &"rags")
		herbs.rotation.x = PI
		room.add_child(herbs)
	room.set_meta(&"hearth", fireplace)
	room.set_meta(&"window", window)
	room.set_meta(&"table", desk)
	room.set_meta(&"wheel", wheel.get_node("Wheel"))
	room.set_meta(&"chest", dowry)
	return room


## Кошель с золотом: Сигвард бросает его к ногам Сольвейг.
static func purse() -> Node3D:
	var r := LowPoly.pivot("Purse")
	var leather := Color(0.42, 0.26, 0.18)
	r.add_child(LowPoly.sphere(0.13, 6, 4, leather, Vector3(0, 0.1, 0), 0.9, 0.0, 0.0, &"leather"))
	r.add_child(LowPoly.cyl(0.08, 0.05, 0.08, 6, leather, Vector3(0, 0.24, 0), 0.9, 0.0, 0.0, &"leather"))
	r.add_child(LowPoly.torus(0.04, 0.06, 8, 3, GOLD, Vector3(0, 0.2, 0), 0.4, 0.8, 0.5, &"gold"))
	# Монеты у горловины.
	for k in 3:
		var a := TAU * k / 3.0
		r.add_child(LowPoly.cyl(0.04, 0.04, 0.015, 6, GOLD, Vector3(cos(a) * 0.05, 0.29 + k * 0.012, sin(a) * 0.05), 0.4, 0.8, 1.0, &"gold"))
	return r


## Письмо с багровой печатью.
static func letter() -> Node3D:
	var r := LowPoly.pivot("Letter")
	r.add_child(LowPoly.box(Vector3(0.22, 0.3, 0.015), Color(0.92, 0.86, 0.72), Vector3(0, 0.12, 0), 0.9, 0.0, 0.1))
	r.add_child(LowPoly.cyl(0.035, 0.035, 0.02, 6, Color(0.6, 0.06, 0.08), Vector3(0, 0.06, 0.012), 0.6, 0.0, 0.3))
	r.rotation.x = deg_to_rad(-70)
	return r


## Плащ: ворот на плечах и полотнище за спиной. Начало координат — у шеи, плащ висит вниз,
## спина — в сторону +Z (модели смотрят в -Z). Как он сидит на актёре — WornCloak.
static func cloak(color: Color = Color(0.5, 0.12, 0.12)) -> Node3D:
	var r := LowPoly.pivot("Cloak")
	r.add_child(LowPoly.box(Vector3(0.66, 0.13, 0.38), color, Vector3(0, -0.03, 0.0), 0.95, 0.0, 0.0, &"cloth"))
	var back := LowPoly.frustum(Vector2(0.9, 0.1), Vector2(0.58, 0.16), 1.05, color.darkened(0.08), Vector3(0, -0.58, 0.17), &"cloth")
	back.rotation.x = 0.1
	r.add_child(back)
	for x in [-0.25, 0.25]:
		r.add_child(LowPoly.box(Vector3(0.15, 0.46, 0.05), color.darkened(0.15), Vector3(x, -0.3, -0.17), 0.95, 0.0, 0.0, &"cloth"))
	return r


# --- Зима: песня Ильвы (IlvaSongScene) ---------------------------------------

## Земля и всё, что лежит на ней вплотную, в PS1 не дрожит. Дрожание сдвигает треугольники по экрану,
## а глубина у них остаётся прежней — и то, что лежит в паре сантиметров над землёй (тени под ногами,
## тропа, плиты света), то проваливается под неё, то выходит наружу: кадр рябит. Так же сделан пол арены.
## Материал копируется: общий, из кэша LowPoly, остаётся дрожащим для остальных.
static func steady(mi: MeshInstance3D) -> MeshInstance3D:
	var m := LowPoly.unique(mi.material_override as ShaderMaterial)
	m.set_shader_parameter(&"snap_vertices", false)
	mi.material_override = m
	return mi


## Снежное поле (или лёд): одна сетка с частыми вершинами. В PS1 свет считается по вершинам,
## и на редкой сетке пятна света от костра и фонаря не было бы.
static func snow_ground(size: Vector2, color: Color = SNOW, emission: float = 0.1) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = int(size.x / 1.2)
	plane.subdivide_depth = int(size.y / 1.2)
	var mi := MeshInstance3D.new()
	mi.name = "SnowGround"
	mi.mesh = plane
	mi.material_override = LowPoly.mat(color, 0.95, 0.0, emission)
	return steady(mi)


## Ель под снегом: три яруса, у каждого зелёный низ и снежный верх.
## Части стоят друг на друге точно, край в край, и не входят одна в другую: в PS1 вершины дрожат,
## и там, где сетки пересекаются или лежат почти вплотную, кадр рябит.
static func fir(height: float = 3.2) -> Node3D:
	var r := LowPoly.pivot("Fir")
	var k := height / 3.36
	r.add_child(LowPoly.cyl(0.09 * k, 0.12 * k, 0.6 * k, 5, DARK_WOOD, Vector3(0, 0.3 * k, 0), 0.9, 0.0, 0.0, &"wood"))
	var y := 0.6 * k
	for i in 3:
		var rad := (1.05 - i * 0.28) * k
		var h := (1.0 - i * 0.08) * k
		var mid := rad * 0.5
		# Верх яруса уже низа следующего: его срез остаётся внутри следующего яруса и не виден.
		var top := 0.0 if i == 2 else rad * 0.22
		r.add_child(LowPoly.cyl(mid, rad, h * 0.6, 6, FIR.lightened(i * 0.05), Vector3(0, y + h * 0.3, 0), 0.95, 0.0, 0.12))
		r.add_child(LowPoly.cyl(top, mid, h * 0.4, 6, SNOW, Vector3(0, y + h * 0.8, 0), 0.95, 0.0, 0.2))
		y += h
	return r


## Сугроб.
static func snow_drift(radius: float = 1.0) -> Node3D:
	var r := LowPoly.pivot("SnowDrift")
	var m := LowPoly.sphere(radius, 9, 5, SNOW, Vector3.ZERO, 0.95, 0.0, 0.2)
	m.scale = Vector3(1.0, 0.2, 0.72)
	r.add_child(steady(m))
	return r


## Костёр: камни по кругу, поленья шалашом, угли. Огонь и свет ставит сцена.
static func campfire() -> Node3D:
	var r := LowPoly.pivot("Campfire")
	for k in 7:
		var a := TAU * k / 7.0
		r.add_child(LowPoly.box(Vector3(0.22, 0.14, 0.18), STONE.darkened(0.12 * (k % 2)), Vector3(cos(a) * 0.48, 0.07, sin(a) * 0.48), 0.95, 0.0, 0.0, &"stone"))
	for k in 3:
		var stick := LowPoly.cyl(0.05, 0.065, 0.72, 5, DARK_WOOD, Vector3(0, 0.22, 0), 0.9, 0.0, 0.0, &"wood")
		stick.rotation = Vector3(0.95, TAU * k / 3.0, 0)
		r.add_child(stick)
	r.add_child(LowPoly.sphere(0.2, 6, 4, FIRE, Vector3(0, 0.1, 0), 0.6, 0.0, 2.5))
	return r


## Бревно у костра: на нём сидят.
static func log_seat() -> Node3D:
	var r := LowPoly.pivot("LogSeat")
	# Утоплено в снег: лежа на земле вплотную, бревно касалось бы её по линии и рябило.
	var trunk := LowPoly.cyl(0.24, 0.27, 1.8, 7, LOG, Vector3(0, 0.17, 0), 0.9, 0.0, 0.0, &"wood")
	trunk.rotation.z = PI / 2
	r.add_child(trunk)
	return r


## Пень у костра: на нём сидят. Узкий — под сидящим его почти не видно, и вещи сидящего
## (щит на руке, плед на плечах) висят вокруг пня, а не проходят сквозь него, как сквозь бревно.
static func stump() -> Node3D:
	var r := LowPoly.pivot("Stump")
	r.add_child(LowPoly.cyl(0.24, 0.28, 0.44, 7, LOG, Vector3(0, 0.22, 0), 0.9, 0.0, 0.0, &"wood"))
	return r


## Вешка у дороги: камни под снежной шапкой.
static func cairn() -> Node3D:
	var r := LowPoly.pivot("Cairn")
	r.add_child(LowPoly.box(Vector3(0.42, 0.3, 0.38), STONE, Vector3(0, 0.15, 0), 0.95, 0.0, 0.0, &"stone"))
	r.add_child(LowPoly.box(Vector3(0.3, 0.26, 0.3), STONE.darkened(0.12), Vector3(0.02, 0.43, 0), 0.95, 0.0, 0.0, &"stone"))
	r.add_child(LowPoly.box(Vector3(0.36, 0.09, 0.36), SNOW, Vector3(0.02, 0.6, 0), 0.95, 0.0, 0.12))
	return r


## Ладья, вмёрзшая в лёд: корпус, штевни, резная голова на носу, мачта со свёрнутым парусом,
## щиты по бортам, снег на палубе. Нос смотрит в +X.
static func longship() -> Node3D:
	var r := LowPoly.pivot("Longship")
	# Борт в плане — миндаль: острые нос и корма, киль уже борта.
	var top: Array = []
	var bottom: Array = []
	for pt in [[-3.3, 0.0], [-2.2, 0.62], [0.0, 0.8], [2.2, 0.62], [3.3, 0.0], [2.2, -0.62], [0.0, -0.8], [-2.2, -0.62]]:
		top.append(Vector3(pt[0], 0.72, pt[1]))
		bottom.append(Vector3(pt[0] * 0.82, 0.0, pt[1] * 0.4))
	var faces: Array = [top, bottom]
	for i in top.size():
		var j := (i + 1) % top.size()
		faces.append([bottom[i], bottom[j], top[j], top[i]])
	var hull := MeshInstance3D.new()
	hull.mesh = LowPoly.convex(faces)
	hull.material_override = LowPoly.mat(DARK_WOOD.lightened(0.14), 0.9, 0.0, 0.0, &"wood")
	r.add_child(hull)
	# Снег на палубе лежит заметно выше борта, щиты висят с зазором от него: вплотную они рябили бы.
	r.add_child(LowPoly.box(Vector3(4.0, 0.14, 0.86), SNOW, Vector3(0, 0.8, 0), 0.95, 0.0, 0.2))
	for s in [-1.0, 1.0]:
		var post := LowPoly.box(Vector3(0.18, 2.0, 0.18), DARK_WOOD.lightened(0.05), Vector3(s * 3.45, 1.45, 0), 0.9, 0.0, 0.0, &"wood")
		post.rotation.z = -s * 0.36
		r.add_child(post)
	r.add_child(LowPoly.box(Vector3(0.55, 0.24, 0.22), DARK_WOOD.lightened(0.14), Vector3(4.05, 2.42, 0), 0.9, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.pyramid(Vector2(0.12, 0.12), 0.26, GOLD, Vector3(4.0, 2.66, 0), &"gold", 0.6, 0.6))
	r.add_child(LowPoly.cyl(0.07, 0.09, 3.0, 5, WOOD, Vector3(0, 2.1, 0), 0.9, 0.0, 0.0, &"wood"))
	for spec in [[0.05, 2.7, WOOD.darkened(0.1), 3.3], [0.15, 2.3, Color(0.82, 0.76, 0.62), 3.12]]:
		var spar := LowPoly.cyl(spec[0], spec[0], spec[1], 6, spec[2], Vector3(0, spec[3], 0), 0.9)
		spar.rotation.x = PI / 2
		r.add_child(spar)
	var paint := [Color(0.62, 0.14, 0.12), GOLD.darkened(0.15), Color(0.2, 0.3, 0.46)]
	for k in 5:
		for s in [-1.0, 1.0]:
			var sx := -2.0 + k * 1.0
			var shield := LowPoly.cyl(0.27, 0.27, 0.06, 8, paint[k % 3], Vector3(sx, 0.7, s * (0.93 - absf(sx) * 0.085)), 0.8, 0.0, 0.25)
			shield.rotation.x = PI / 2
			r.add_child(shield)
	return r


## Горящий дом: сруб, двускатная крыша, проёмы в огне. Огонь и свет ставит сцена — над точками fire_points.
static func burning_hut() -> Node3D:
	var r := LowPoly.pivot("BurningHut")
	r.add_child(LowPoly.box(Vector3(3.4, 1.7, 2.6), LOG.darkened(0.4), Vector3(0, 0.85, 0), 0.95, 0.0, 0.0, &"wood"))
	r.add_child(LowPoly.prism(Vector3(3.9, 1.3, 3.0), DARK_WOOD.darkened(0.25), Vector3(0, 2.35, 0), 0.95, 0.0, 0.0, &"wood"))
	# Проёмы выступают из стены на ладонь, а не лежат в её плоскости.
	r.add_child(LowPoly.box(Vector3(0.8, 1.2, 0.2), FIRE, Vector3(0.3, 0.6, 1.3), 0.6, 0.0, 3.0))
	r.add_child(LowPoly.box(Vector3(0.6, 0.5, 0.2), FIRE, Vector3(-1.0, 1.05, 1.3), 0.6, 0.0, 3.0))
	r.set_meta(&"fire_points", [Vector3(0, 2.9, 0), Vector3(-1.2, 2.3, 0.6), Vector3(1.1, 2.4, -0.3), Vector3(0.3, 1.3, 1.45)])
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
