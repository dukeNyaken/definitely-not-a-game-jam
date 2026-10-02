class_name ItemVisuals
extends RefCounted
## Меши вещей на сокетах персонажа и добавки сущностей на вещи-получателе.
## build() возвращает части: [{ "socket": &"r_hand", "node": Node3D, "anchors": [Transform3D] }].

const STEEL := Color(0.72, 0.75, 0.8)
const DARK_STEEL := Color(0.42, 0.45, 0.5)
const LEATHER := Color(0.45, 0.29, 0.17)
const WOOD := Color(0.52, 0.34, 0.19)
const GOLD := Color(0.95, 0.75, 0.3)
## Добавки крупнее «реального» размера, чтобы читаться с изометрической камеры.
const ADDON_SCALE := 1.7


static func build(state: ItemState) -> Array:
	var parts := _parts(state.def_id)
	var anchored := parts.filter(func(p): return not (p["anchors"] as Array).is_empty())
	for i in state.properties.size():
		var essence := Db.essence(state.properties[i].essence_id)
		var part: Dictionary = anchored[i % anchored.size()]
		var anchors: Array = part["anchors"]
		var t: Transform3D = anchors[(i / anchored.size()) % anchors.size()]
		var addon := build_addon(essence)
		addon.transform = t.scaled_local(Vector3.ONE * ADDON_SCALE)
		addon.set_meta(&"prop_index", i)
		(part["node"] as Node3D).add_child(addon)
	return parts


## Вещь целиком, вне тела: для постаментов, иконок и алтаря.
static func build_display(state: ItemState) -> Node3D:
	var root := Node3D.new()
	root.name = "Item_%s" % state.def_id
	var parts := build(state)
	var offsets := {
		&"sword": [Transform3D(Basis(), Vector3(0, -0.85, 0))],
		&"shield": [Transform3D(Basis(), Vector3.ZERO)],
		&"armor": [Transform3D(Basis(), Vector3(0, 0.05, 0))],
		&"helmet": [Transform3D(Basis(), Vector3(0, -0.12, 0))],
		&"gloves": [Transform3D(Basis(Vector3.UP, 0.4), Vector3(-0.18, 0, 0)), Transform3D(Basis(Vector3.UP, -0.4), Vector3(0.18, 0, 0))],
		&"boots": [Transform3D(Basis(Vector3.UP, 0.25), Vector3(-0.17, -0.25, 0)), Transform3D(Basis(Vector3.UP, -0.25), Vector3(0.17, -0.25, 0))],
		&"amulet": [Transform3D(Basis(), Vector3(0, 0.12, 0))],
	}
	var list: Array = offsets.get(state.def_id, [])
	for i in parts.size():
		var holder := Node3D.new()
		holder.transform = list[i] if i < list.size() else Transform3D()
		var node: Node3D = parts[i]["node"]
		node.rotation = Vector3.ZERO
		node.position = Vector3.ZERO
		holder.add_child(node)
		root.add_child(holder)
	return root


static func _anchor(pos: Vector3, normal: Vector3) -> Transform3D:
	var n := normal.normalized()
	var up_hint := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var x := up_hint.cross(n).normalized()
	var z := x.cross(n).normalized()
	return Transform3D(Basis(x, n, z), pos)


static func _box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, surface: StringName = &"", rot: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	var mi := LowPoly.box(size, color, pos, 0.75 if metallic > 0.0 else 0.9, metallic, emission, surface)
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _prism(parent: Node3D, size: Vector3, color: Color, pos: Vector3, surface: StringName = &"", rot: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mi := LowPoly.prism(size, color, pos, 0.75, metallic, 0.0, surface)
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _parts(id: StringName) -> Array:
	var white := Color(1, 1, 1)
	var black_iron := Color(0.95, 0.95, 1.05)
	match id:
		&"sword":
			# Слишком большой, чтобы называться мечом: плита железа. Клинок вдоль +Y.
			var s := LowPoly.pivot("Sword")
			s.add_child(LowPoly.cyl(0.045, 0.05, 0.44, 6, white, Vector3(0, -0.04, 0), 0.9, 0.0, 0.0, &"leather"))
			s.add_child(LowPoly.sphere(0.075, 6, 3, black_iron, Vector3(0, -0.3, 0), 0.6, 0.6, 0.0, &"iron"))
			_box(s, Vector3(0.5, 0.1, 0.13), black_iron, Vector3(0, 0.2, 0), &"iron", Vector3.ZERO, 0.5)
			_box(s, Vector3(0.28, 1.56, 0.07), black_iron, Vector3(0, 1.02, 0), &"iron", Vector3.ZERO, 0.6)
			_box(s, Vector3(0.035, 1.5, 0.075), Color(0.95, 0.95, 1.0), Vector3(-0.13, 1.0, 0), &"iron", Vector3.ZERO, 0.8)
			_box(s, Vector3(0.035, 1.5, 0.075), Color(0.95, 0.95, 1.0), Vector3(0.13, 1.0, 0), &"iron", Vector3.ZERO, 0.8)
			_prism(s, Vector3(0.28, 0.26, 0.07), black_iron, Vector3(0, 1.93, 0), &"iron", Vector3.ZERO, 0.6)
			# Зазубрины и запёкшаяся кровь.
			_box(s, Vector3(0.06, 0.08, 0.08), Color(0.08, 0.06, 0.06), Vector3(0.14, 1.35, 0))
			_box(s, Vector3(0.05, 0.06, 0.08), Color(0.08, 0.06, 0.06), Vector3(-0.14, 0.75, 0))
			_box(s, Vector3(0.2, 0.34, 0.076), Color(0.35, 0.03, 0.03), Vector3(0.02, 1.65, 0))
			s.rotation = Vector3(deg_to_rad(-115), 0, 0)
			return [{"socket": &"r_hand", "node": s, "anchors": [
				_anchor(Vector3(0.15, 0.5, 0), Vector3.RIGHT),
				_anchor(Vector3(-0.15, 0.8, 0), Vector3.LEFT),
				_anchor(Vector3(0.15, 1.1, 0), Vector3.RIGHT),
				_anchor(Vector3(-0.15, 1.4, 0), Vector3.LEFT),
				_anchor(Vector3(0, 0.6, 0.04), Vector3.BACK),
				_anchor(Vector3(0, 0.2, 0.07), Vector3.BACK),
			]}]
		&"shield":
			# Тяжёлый щит-«утюг»: доски, ржавая оковка, грубая багровая полоса. Лицо смотрит в -Z.
			var s := LowPoly.pivot("Shield")
			_box(s, Vector3(0.66, 0.6, 0.07), white, Vector3(0, 0.12, 0), &"wood")
			_prism(s, Vector3(0.66, 0.46, 0.07), white, Vector3(0, -0.41, 0), &"wood", Vector3(0, 0, PI))
			for x in [-0.34, 0.34]:
				_box(s, Vector3(0.05, 0.62, 0.09), white, Vector3(x, 0.12, 0), &"rust", Vector3.ZERO, 0.4)
			_box(s, Vector3(0.72, 0.06, 0.09), white, Vector3(0, 0.43, 0), &"rust", Vector3.ZERO, 0.4)
			_box(s, Vector3(0.1, 0.9, 0.08), Color(0.42, 0.05, 0.04), Vector3(0, 0.0, -0.01))
			s.add_child(LowPoly.sphere(0.1, 6, 3, black_iron, Vector3(0, 0.08, -0.05), 0.6, 0.6, 0.0, &"iron"))
			s.position = Vector3(-0.08, 0.16, -0.13)
			var anchors := []
			for k in 6:
				var a := TAU * float(k) / 6.0 + 0.5
				anchors.append(_anchor(Vector3(cos(a) * 0.28, sin(a) * 0.3 + 0.05, -0.04), Vector3(cos(a) * 0.6, sin(a) * 0.6, -1.0)))
			return [{"socket": &"l_hand", "node": s, "anchors": anchors}]
		&"armor":
			# Чернёная кираса, шипастые наплечники, рваный плащ.
			var s := LowPoly.pivot("Armor")
			_box(s, Vector3(0.68, 0.54, 0.44), black_iron, Vector3(0, 0.04, 0), &"iron", Vector3.ZERO, 0.6)
			for k in 3:
				_box(s, Vector3(0.62 - k * 0.04, 0.11, 0.46), black_iron.darkened(0.1 * k), Vector3(0, -0.22 - k * 0.1, 0), &"iron", Vector3.ZERO, 0.6)
			s.add_child(LowPoly.cyl(0.22, 0.26, 0.12, 7, black_iron, Vector3(0, 0.33, 0), 0.6, 0.6, 0.0, &"iron"))
			for side in [-1.0, 1.0]:
				var pad := LowPoly.pivot("Pauldron", Vector3(side * 0.42, 0.28, 0))
				pad.rotation.z = side * -0.3
				_box(pad, Vector3(0.36, 0.17, 0.42), black_iron, Vector3.ZERO, &"iron", Vector3.ZERO, 0.6)
				_box(pad, Vector3(0.32, 0.1, 0.4), black_iron.darkened(0.15), Vector3(side * 0.03, -0.12, 0), &"iron", Vector3.ZERO, 0.6)
				for k in 2:
					_prism(pad, Vector3(0.07, 0.26, 0.07), black_iron, Vector3(side * 0.05, 0.18, -0.1 + k * 0.2), &"iron", Vector3.ZERO, 0.6)
				s.add_child(pad)
			_box(s, Vector3(0.62, 0.08, 0.48), white, Vector3(0, -0.46, 0), &"leather")
			# Плащ свисает с плеч за спиной.
			_box(s, Vector3(0.86, 1.3, 0.04), Color(0.4, 0.12, 0.1), Vector3(0, -0.38, 0.27), &"rags", Vector3(0.1, 0, 0))
			return [{"socket": &"chest", "node": s, "anchors": [
				_anchor(Vector3(0, 0.1, -0.23), Vector3.FORWARD),
				_anchor(Vector3(-0.44, 0.42, 0), Vector3(-0.4, 1, 0)),
				_anchor(Vector3(0.44, 0.42, 0), Vector3(0.4, 1, 0)),
				_anchor(Vector3(0, 0.1, 0.24), Vector3.BACK),
				_anchor(Vector3(-0.2, -0.15, -0.24), Vector3.FORWARD),
				_anchor(Vector3(0.2, -0.15, -0.24), Vector3.FORWARD),
			]}]
		&"helmet":
			# Звериный шлем: вытянутое рыло, горящие прорези, рога.
			var s := LowPoly.pivot("Helmet")
			s.add_child(LowPoly.cyl(0.24, 0.26, 0.36, 8, black_iron, Vector3(0, 0.05, 0), 0.6, 0.6, 0.0, &"iron"))
			s.add_child(LowPoly.cyl(0.05, 0.25, 0.14, 8, black_iron, Vector3(0, 0.29, 0), 0.6, 0.6, 0.0, &"iron"))
			_box(s, Vector3(0.2, 0.15, 0.28), black_iron, Vector3(0, -0.03, -0.27), &"iron", Vector3.ZERO, 0.6)
			_prism(s, Vector3(0.08, 0.3, 0.06), black_iron, Vector3(0, 0.05, -0.36), &"iron", Vector3(deg_to_rad(-80), 0, 0), 0.6)
			for x in [-0.075, 0.075]:
				_box(s, Vector3(0.08, 0.025, 0.02), Color(1.0, 0.18, 0.08), Vector3(x, 0.08, -0.25), &"", Vector3.ZERO, 0.0, 4.0)
			for side in [-1.0, 1.0]:
				_prism(s, Vector3(0.07, 0.34, 0.07), Color(0.85, 0.8, 0.7), Vector3(side * 0.2, 0.32, 0.04), &"bone", Vector3(0.4, 0, side * -0.5))
			return [{"socket": &"head", "node": s, "anchors": [
				_anchor(Vector3(0, 0.38, 0), Vector3.UP),
				_anchor(Vector3(-0.25, 0.1, 0), Vector3.LEFT),
				_anchor(Vector3(0.25, 0.1, 0), Vector3.RIGHT),
				_anchor(Vector3(0, 0.15, 0.25), Vector3.BACK),
				_anchor(Vector3(0, 0.05, -0.42), Vector3(0, 0.6, -1)),
				_anchor(Vector3(0, 0.3, 0.14), Vector3(0, 1, 0.6)),
			]}]
		&"gloves":
			var out := []
			for side in [&"l_hand", &"r_hand"]:
				var g := LowPoly.pivot("Gauntlet")
				_box(g, Vector3(0.23, 0.23, 0.25), black_iron, Vector3.ZERO, &"iron", Vector3.ZERO, 0.6)
				_box(g, Vector3(0.24, 0.07, 0.14), black_iron.darkened(0.15), Vector3(0, -0.1, -0.07), &"iron", Vector3.ZERO, 0.6)
				for k in 3:
					_prism(g, Vector3(0.045, 0.1, 0.045), Color(0.9, 0.9, 0.95), Vector3(-0.07 + k * 0.07, -0.12, -0.15), &"iron", Vector3(deg_to_rad(-90), 0, 0), 0.7)
				g.add_child(LowPoly.cyl(0.14, 0.12, 0.16, 6, white, Vector3(0, 0.17, 0), 0.9, 0.0, 0.0, &"leather"))
				var sx := -1.0 if side == &"l_hand" else 1.0
				out.append({"socket": side, "node": g, "anchors": [
					_anchor(Vector3(sx * 0.12, 0.02, 0), Vector3(sx, 0, 0)),
					_anchor(Vector3(0, 0.02, 0.12), Vector3.BACK),
					_anchor(Vector3(0, 0.12, 0), Vector3.UP),
				]})
			return out
		&"boots":
			var out := []
			for side in [&"l_foot", &"r_foot"]:
				var b := LowPoly.pivot("Sabaton")
				_box(b, Vector3(0.26, 0.2, 0.32), black_iron, Vector3(0, 0.1, -0.02), &"iron", Vector3.ZERO, 0.6)
				_prism(b, Vector3(0.24, 0.2, 0.16), black_iron, Vector3(0, 0.07, -0.24), &"iron", Vector3(deg_to_rad(-90), 0, 0), 0.6)
				b.add_child(LowPoly.cyl(0.14, 0.13, 0.36, 6, black_iron, Vector3(0, 0.36, 0), 0.6, 0.6, 0.0, &"iron"))
				_box(b, Vector3(0.3, 0.05, 0.3), white, Vector3(0, 0.44, 0), &"leather")
				var sx := -1.0 if side == &"l_foot" else 1.0
				out.append({"socket": side, "node": b, "anchors": [
					_anchor(Vector3(sx * 0.14, 0.34, 0.02), Vector3(sx, 0.3, 0.2)),
					_anchor(Vector3(0, 0.15, -0.3), Vector3.FORWARD),
					_anchor(Vector3(0, 0.4, 0.13), Vector3.BACK),
				]})
			return out
		&"amulet":
			# Багровый камень-яйцо на грубой цепи.
			var s := LowPoly.pivot("Amulet")
			var chain := LowPoly.torus(0.17, 0.2, 10, 4, white, Vector3(0, 0, 0), 0.6, 0.5, 0.0, &"rust")
			chain.rotation = Vector3(deg_to_rad(18), 0, 0)
			s.add_child(chain)
			var egg := LowPoly.sphere(0.08, 7, 4, Color(0.75, 0.08, 0.1), Vector3(0, -0.17, -0.21), 0.3, 0.0, 1.2, &"flesh")
			egg.scale = Vector3(0.8, 1.15, 0.8)
			s.add_child(egg)
			_box(s, Vector3(0.1, 0.04, 0.05), black_iron, Vector3(0, -0.07, -0.21), &"iron", Vector3.ZERO, 0.6)
			return [{"socket": &"neck", "node": s, "anchors": [
				_anchor(Vector3(0.1, -0.16, -0.2), Vector3(1, 0, -0.5)),
				_anchor(Vector3(-0.1, -0.16, -0.2), Vector3(-1, 0, -0.5)),
				_anchor(Vector3(0, -0.04, -0.21), Vector3(0, 1, -0.5)),
				_anchor(Vector3(0, -0.28, -0.2), Vector3(0, -1, -0.5)),
				_anchor(Vector3(0.18, 0.0, 0), Vector3.RIGHT),
				_anchor(Vector3(-0.18, 0.0, 0), Vector3.LEFT),
			]}]
	return []


## Добавка сущности. Локальная ось +Y смотрит наружу от вещи.
static func build_addon(essence: EssenceDef) -> Node3D:
	var n := LowPoly.pivot("Addon_%s" % essence.id)
	var c := essence.color
	match essence.id:
		&"blade":
			for k in 3:
				var p := LowPoly.prism(Vector3(0.05, 0.16, 0.05), c, Vector3((k - 1) * 0.07, 0.08, 0), 0.2, 0.3, 0.6)
				n.add_child(p)
		&"bulwark":
			var r := LowPoly.torus(0.07, 0.1, 8, 4, c, Vector3(0, 0.02, 0), 0.25, 0.9, 0.5)
			n.add_child(r)
			n.add_child(LowPoly.box(Vector3(0.05, 0.05, 0.05), c, Vector3(0, 0.04, 0), 0.25, 0.9, 0.8))
		&"mass":
			n.add_child(LowPoly.box(Vector3(0.16, 0.05, 0.12), c, Vector3(0, 0.02, -0.03), 0.5, 0.4, 0.3))
			n.add_child(LowPoly.box(Vector3(0.14, 0.05, 0.1), c.darkened(0.25), Vector3(0, 0.05, 0.05), 0.5, 0.4, 0.3))
		&"gaze":
			n.add_child(LowPoly.sphere(0.065, 8, 4, Color(0.95, 0.9, 1.0), Vector3(0, 0.04, 0), 0.3, 0.0, 0.4))
			n.add_child(LowPoly.sphere(0.04, 6, 3, c, Vector3(0, 0.085, 0), 0.2, 0.0, 2.5))
			n.add_child(LowPoly.sphere(0.018, 4, 2, Color(0.02, 0.0, 0.05), Vector3(0, 0.12, 0)))
		&"grip":
			for k in 3:
				var link := LowPoly.torus(0.02, 0.04, 6, 3, c, Vector3(0, 0.04 + k * 0.06, 0), 0.4, 0.6, 0.6)
				link.rotation = Vector3(0, 0, PI / 2 if k % 2 == 0 else 0.0)
				link.rotation.x = PI / 2
				n.add_child(link)
		&"gust":
			for side in [-1.0, 1.0]:
				var w := Node3D.new()
				w.rotation = Vector3(0, 0, side * deg_to_rad(35))
				for f in 3:
					w.add_child(LowPoly.box(Vector3(0.02, 0.14 - f * 0.03, 0.06), c, Vector3(side * 0.02, 0.08 + f * 0.02, 0.05 * f - 0.05), 0.4, 0.0, 0.9))
				n.add_child(w)
		&"energy":
			var spin := RuneSpinner.new()
			for k in 3:
				var a := TAU * k / 3.0
				spin.add_child(LowPoly.box(Vector3(0.045, 0.06, 0.015), c, Vector3(cos(a) * 0.09, 0.07, sin(a) * 0.09), 0.2, 0.0, 3.0))
			n.add_child(spin)
	return n
