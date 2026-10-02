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
		(part["node"] as Node3D).add_child(addon)
	return parts


## Вещь целиком, вне тела: для постаментов, иконок и алтаря.
static func build_display(state: ItemState) -> Node3D:
	var root := Node3D.new()
	root.name = "Item_%s" % state.def_id
	var parts := build(state)
	var offsets := {
		&"sword": [Transform3D(Basis(Vector3.FORWARD, 0.0), Vector3(0, -0.45, 0))],
		&"shield": [Transform3D(Basis(Vector3.RIGHT, 0.0), Vector3.ZERO)],
		&"armor": [Transform3D(Basis(), Vector3(0, -0.05, 0))],
		&"helmet": [Transform3D(Basis(), Vector3(0, -0.12, 0))],
		&"gloves": [Transform3D(Basis(Vector3.UP, 0.4), Vector3(-0.17, 0, 0)), Transform3D(Basis(Vector3.UP, -0.4), Vector3(0.17, 0, 0))],
		&"boots": [Transform3D(Basis(Vector3.UP, 0.25), Vector3(-0.16, -0.1, 0)), Transform3D(Basis(Vector3.UP, -0.25), Vector3(0.16, -0.1, 0))],
		&"amulet": [Transform3D(Basis(), Vector3(0, 0.1, 0))],
	}
	var list: Array = offsets.get(state.def_id, [])
	for i in parts.size():
		var holder := Node3D.new()
		holder.transform = list[i] if i < list.size() else Transform3D()
		var node: Node3D = parts[i]["node"]
		if state.def_id == &"sword":
			node.rotation = Vector3.ZERO
		elif state.def_id == &"shield":
			node.rotation = Vector3(0, 0, 0)
			node.position = Vector3.ZERO
		else:
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


static func _parts(id: StringName) -> Array:
	match id:
		&"sword":
			var s := LowPoly.pivot("Sword")
			# Клинок вдоль +Y, сам меч повёрнут вперёд, когда рука опущена.
			s.add_child(LowPoly.cyl(0.035, 0.04, 0.24, 6, LEATHER, Vector3(0, -0.02, 0)))
			s.add_child(LowPoly.sphere(0.05, 6, 3, GOLD, Vector3(0, -0.16, 0), 0.4, 0.6))
			s.add_child(LowPoly.box(Vector3(0.34, 0.05, 0.08), GOLD, Vector3(0, 0.11, 0), 0.4, 0.6))
			s.add_child(LowPoly.box(Vector3(0.08, 0.86, 0.03), STEEL, Vector3(0, 0.56, 0), 0.25, 0.8))
			s.add_child(LowPoly.prism(Vector3(0.08, 0.14, 0.03), STEEL, Vector3(0, 1.06, 0), 0.25, 0.8))
			s.rotation = Vector3(deg_to_rad(-90), 0, 0)
			return [{"socket": &"r_hand", "node": s, "anchors": [
				_anchor(Vector3(0.05, 0.4, 0), Vector3.RIGHT),
				_anchor(Vector3(-0.05, 0.6, 0), Vector3.LEFT),
				_anchor(Vector3(0.05, 0.8, 0), Vector3.RIGHT),
				_anchor(Vector3(-0.05, 0.3, 0), Vector3.LEFT),
				_anchor(Vector3(0.05, 0.95, 0), Vector3.RIGHT),
				_anchor(Vector3(0, 0.11, 0.05), Vector3.BACK),
			]}]
		&"shield":
			var s := LowPoly.pivot("Shield")
			var disc := LowPoly.cyl(0.42, 0.42, 0.07, 8, WOOD)
			s.add_child(disc)
			s.add_child(LowPoly.cyl(0.44, 0.44, 0.05, 8, DARK_STEEL, Vector3(0, -0.01, 0), 0.4, 0.7))
			s.add_child(LowPoly.sphere(0.1, 6, 3, STEEL, Vector3(0, 0.05, 0), 0.3, 0.8))
			s.add_child(LowPoly.box(Vector3(0.06, 0.02, 0.7), DARK_STEEL, Vector3(0, 0.04, 0), 0.4, 0.7))
			# Лицевая сторона (+Y диска) смотрит вперёд (-Z).
			s.rotation = Vector3(deg_to_rad(-90), 0, 0)
			s.position = Vector3(-0.06, 0.2, -0.12)
			var anchors := []
			for k in 6:
				var a := TAU * float(k) / 6.0 + 0.5
				anchors.append(_anchor(Vector3(cos(a) * 0.36, 0.06, sin(a) * 0.36), Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6)))
			return [{"socket": &"l_hand", "node": s, "anchors": anchors}]
		&"armor":
			var s := LowPoly.pivot("Armor")
			s.add_child(LowPoly.box(Vector3(0.62, 0.52, 0.38), STEEL, Vector3(0, 0.02, 0), 0.35, 0.75))
			s.add_child(LowPoly.box(Vector3(0.5, 0.16, 0.36), DARK_STEEL, Vector3(0, -0.3, 0), 0.4, 0.7))
			s.add_child(LowPoly.box(Vector3(0.26, 0.14, 0.32), STEEL, Vector3(-0.37, 0.24, 0), 0.35, 0.75))
			s.add_child(LowPoly.box(Vector3(0.26, 0.14, 0.32), STEEL, Vector3(0.37, 0.24, 0), 0.35, 0.75))
			s.add_child(LowPoly.box(Vector3(0.54, 0.06, 0.37), LEATHER, Vector3(0, -0.2, 0)))
			return [{"socket": &"chest", "node": s, "anchors": [
				_anchor(Vector3(0, 0.08, -0.2), Vector3.FORWARD),
				_anchor(Vector3(-0.38, 0.32, 0), Vector3(-0.5, 1, 0)),
				_anchor(Vector3(0.38, 0.32, 0), Vector3(0.5, 1, 0)),
				_anchor(Vector3(0, 0.1, 0.2), Vector3.BACK),
				_anchor(Vector3(-0.2, -0.12, -0.2), Vector3.FORWARD),
				_anchor(Vector3(0.2, -0.12, -0.2), Vector3.FORWARD),
			]}]
		&"helmet":
			var s := LowPoly.pivot("Helmet")
			s.add_child(LowPoly.cyl(0.25, 0.26, 0.3, 8, STEEL, Vector3(0, 0.02, 0), 0.3, 0.8))
			s.add_child(LowPoly.cyl(0.04, 0.26, 0.2, 8, STEEL, Vector3(0, 0.27, 0), 0.3, 0.8))
			s.add_child(LowPoly.box(Vector3(0.3, 0.05, 0.04), Color(0.08, 0.08, 0.1), Vector3(0, 0.02, -0.25)))
			s.add_child(LowPoly.box(Vector3(0.05, 0.22, 0.04), DARK_STEEL, Vector3(0, -0.04, -0.26), 0.4, 0.7))
			return [{"socket": &"head", "node": s, "anchors": [
				_anchor(Vector3(0, 0.36, 0), Vector3.UP),
				_anchor(Vector3(-0.25, 0.1, 0), Vector3.LEFT),
				_anchor(Vector3(0.25, 0.1, 0), Vector3.RIGHT),
				_anchor(Vector3(0, 0.15, 0.24), Vector3.BACK),
				_anchor(Vector3(0, 0.2, -0.22), Vector3(0, 0.6, -1)),
				_anchor(Vector3(0, 0.3, 0.12), Vector3(0, 1, 0.6)),
			]}]
		&"gloves":
			var out := []
			for side in [&"l_hand", &"r_hand"]:
				var g := LowPoly.pivot("Glove")
				g.add_child(LowPoly.box(Vector3(0.2, 0.2, 0.2), LEATHER, Vector3(0, 0.0, 0)))
				g.add_child(LowPoly.cyl(0.12, 0.11, 0.1, 6, Color(0.36, 0.23, 0.13), Vector3(0, 0.14, 0)))
				var sx := -1.0 if side == &"l_hand" else 1.0
				out.append({"socket": side, "node": g, "anchors": [
					_anchor(Vector3(sx * 0.1, 0.02, 0), Vector3(sx, 0, 0)),
					_anchor(Vector3(0, 0.02, 0.1), Vector3.BACK),
					_anchor(Vector3(0, -0.1, 0), Vector3.DOWN),
				]})
			return out
		&"boots":
			var out := []
			for side in [&"l_foot", &"r_foot"]:
				var b := LowPoly.pivot("Boot")
				b.add_child(LowPoly.box(Vector3(0.24, 0.24, 0.36), LEATHER, Vector3(0, 0.1, -0.05)))
				b.add_child(LowPoly.box(Vector3(0.22, 0.12, 0.24), Color(0.36, 0.23, 0.13), Vector3(0, 0.28, 0.0)))
				var sx := -1.0 if side == &"l_foot" else 1.0
				out.append({"socket": side, "node": b, "anchors": [
					_anchor(Vector3(sx * 0.12, 0.22, 0.04), Vector3(sx, 0.3, 0.2)),
					_anchor(Vector3(0, 0.15, -0.24), Vector3.FORWARD),
					_anchor(Vector3(0, 0.3, 0.13), Vector3.BACK),
				]})
			return out
		&"amulet":
			var s := LowPoly.pivot("Amulet")
			var chain := LowPoly.torus(0.17, 0.195, 10, 4, GOLD, Vector3(0, 0, 0), 0.3, 0.8)
			chain.rotation = Vector3(deg_to_rad(18), 0, 0)
			s.add_child(chain)
			var pendant := LowPoly.torus(0.05, 0.08, 6, 4, GOLD, Vector3(0, -0.14, -0.19), 0.3, 0.8)
			pendant.rotation = Vector3(deg_to_rad(90), 0, 0)
			s.add_child(pendant)
			s.add_child(LowPoly.sphere(0.05, 6, 3, Color(1.0, 0.45, 0.15), Vector3(0, -0.14, -0.2), 0.2, 0.0, 1.5))
			return [{"socket": &"neck", "node": s, "anchors": [
				_anchor(Vector3(0.1, -0.14, -0.19), Vector3(1, 0, -0.5)),
				_anchor(Vector3(-0.1, -0.14, -0.19), Vector3(-1, 0, -0.5)),
				_anchor(Vector3(0, -0.04, -0.2), Vector3(0, 1, -0.5)),
				_anchor(Vector3(0, -0.24, -0.19), Vector3(0, -1, -0.5)),
				_anchor(Vector3(0.17, 0.0, 0), Vector3.RIGHT),
				_anchor(Vector3(-0.17, 0.0, 0), Vector3.LEFT),
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
