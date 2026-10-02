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
	var mi := LowPoly.box(size, color, pos, 0.6 if metallic > 0.0 else 0.9, metallic, emission, surface)
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _fr(parent: Node3D, bottom: Vector2, top: Vector2, h: float, color: Color, pos: Vector3, surface: StringName = &"", top_offset: Vector2 = Vector2.ZERO, rot: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	var mi := LowPoly.frustum(bottom, top, h, color, pos, surface, top_offset, metallic, emission)
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _py(parent: Node3D, base: Vector2, h: float, color: Color, pos: Vector3, surface: StringName = &"", rot: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	var mi := LowPoly.pyramid(base, h, color, pos, surface, metallic, emission)
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _gm(parent: Node3D, r: float, up: float, down: float, sides: int, color: Color, pos: Vector3, surface: StringName = &"", rot: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	var mi := LowPoly.gem(r, up, down, sides, color, pos, surface, metallic, emission)
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _parts(id: StringName) -> Array:
	var white := Color(1, 1, 1)
	var steel := Color(1.25, 1.25, 1.32)
	var dark := Color(0.08, 0.06, 0.06)
	match id:
		&"sword":
			# Бастард: обычный рост, широкий дол, зазубрины, квилоны вниз. Клинок вдоль +Y.
			var s := LowPoly.pivot("Sword")
			_fr(s, Vector2(0.05, 0.05), Vector2(0.045, 0.045), 0.34, white, Vector3(0, -0.06, 0), &"leather")
			_gm(s, 0.06, 0.06, 0.08, 4, steel, Vector3(0, -0.28, 0), &"iron", Vector3.ZERO, 0.6)
			_box(s, Vector3(0.36, 0.05, 0.07), steel, Vector3(0, 0.13, 0), &"iron", Vector3.ZERO, 0.6)
			for side in [-1.0, 1.0]:
				_py(s, Vector2(0.06, 0.06), 0.14, steel, Vector3(side * 0.18, 0.08, 0), &"iron", Vector3(PI, 0, side * 0.35), 0.6)
			_fr(s, Vector2(0.12, 0.05), Vector2(0.1, 0.035), 1.0, steel, Vector3(0, 0.66, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.7)
			_box(s, Vector3(0.025, 0.78, 0.055), Color(0.35, 0.35, 0.4), Vector3(0, 0.6, 0), &"iron", Vector3.ZERO, 0.6)
			_py(s, Vector2(0.1, 0.035), 0.24, steel, Vector3(0, 1.28, 0), &"iron", Vector3.ZERO, 0.7)
			_box(s, Vector3(0.04, 0.05, 0.06), dark, Vector3(0.055, 0.95, 0))
			_box(s, Vector3(0.035, 0.04, 0.06), dark, Vector3(-0.05, 0.55, 0))
			_box(s, Vector3(0.09, 0.22, 0.06), Color(0.38, 0.03, 0.03), Vector3(0.01, 1.05, 0))
			s.rotation = Vector3(deg_to_rad(-105), 0, 0)
			return [{"socket": &"r_hand", "node": s, "anchors": [
				_anchor(Vector3(0.07, 0.4, 0), Vector3.RIGHT),
				_anchor(Vector3(-0.07, 0.6, 0), Vector3.LEFT),
				_anchor(Vector3(0.07, 0.8, 0), Vector3.RIGHT),
				_anchor(Vector3(-0.07, 1.0, 0), Vector3.LEFT),
				_anchor(Vector3(0, 0.5, 0.03), Vector3.BACK),
				_anchor(Vector3(0, 0.13, 0.04), Vector3.BACK),
			]}]
		&"shield":
			# Каплевидный щит из досок; на лице — кольцо из семи. Лицо смотрит в -Z.
			var s := LowPoly.pivot("Shield")
			_fr(s, Vector2(0.62, 0.07), Vector2(0.68, 0.07), 0.36, white, Vector3(0, 0.2, 0), &"wood")
			_fr(s, Vector2(0.06, 0.07), Vector2(0.62, 0.07), 0.48, white, Vector3(0, -0.22, 0), &"wood")
			_fr(s, Vector2(0.66, 0.09), Vector2(0.7, 0.09), 0.05, steel, Vector3(0, 0.38, 0), &"rust", Vector2.ZERO, Vector3.ZERO, 0.4)
			var ring := LowPoly.torus(0.13, 0.16, 14, 4, Color(0.85, 0.82, 0.72), Vector3(0, 0.06, -0.04))
			ring.rotation.x = PI / 2
			s.add_child(ring)
			for k in 7:
				var a := TAU * k / 7.0 + PI / 2
				_box(s, Vector3(0.04, 0.04, 0.02), Color(0.55, 0.06, 0.05), Vector3(cos(a) * 0.145, 0.06 + sin(a) * 0.145, -0.05))
			_gm(s, 0.06, 0.05, 0.02, 6, steel, Vector3(0, 0.06, -0.04), &"iron", Vector3(PI / 2, 0, 0), 0.6)
			s.position = Vector3(-0.08, 0.16, -0.13)
			var anchors := []
			for k in 6:
				var a := TAU * float(k) / 6.0 + 0.5
				anchors.append(_anchor(Vector3(cos(a) * 0.26, sin(a) * 0.28 + 0.04, -0.04), Vector3(cos(a) * 0.6, sin(a) * 0.6, -1.0)))
			return [{"socket": &"l_hand", "node": s, "anchors": anchors}]
		&"armor":
			# Стальная кираса с рёбром, пластинчатые наплечники, меховая накидка, рваный плащ.
			var s := LowPoly.pivot("Armor")
			_fr(s, Vector2(0.5, 0.38), Vector2(0.7, 0.46), 0.52, steel, Vector3(0, 0.03, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
			_box(s, Vector3(0.06, 0.48, 0.06), steel, Vector3(0, 0.04, -0.215), &"iron", Vector3(0, PI / 4, 0), 0.6)
			for k in 3:
				_fr(s, Vector2(0.5 - k * 0.03, 0.4), Vector2(0.52 - k * 0.03, 0.42), 0.1, steel.darkened(0.12 * k), Vector3(0, -0.27 - k * 0.09, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
			_fr(s, Vector2(0.84, 0.54), Vector2(0.34, 0.3), 0.22, Color(0.8, 0.72, 0.62), Vector3(0, 0.35, 0.01), &"fur")
			for side in [-1.0, 1.0]:
				var pad := LowPoly.pivot("Pauldron", Vector3(side * 0.43, 0.26, 0))
				pad.rotation.z = side * -0.35
				_fr(pad, Vector2(0.34, 0.42), Vector2(0.22, 0.32), 0.16, steel, Vector3.ZERO, &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
				_fr(pad, Vector2(0.36, 0.42), Vector2(0.32, 0.4), 0.08, steel.darkened(0.15), Vector3(side * 0.02, -0.11, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
				_py(pad, Vector2(0.08, 0.08), 0.22, steel, Vector3(0, 0.18, 0), &"iron", Vector3.ZERO, 0.6)
				s.add_child(pad)
			_box(s, Vector3(0.6, 0.07, 0.46), white, Vector3(0, -0.46, 0), &"leather")
			_fr(s, Vector2(0.96, 0.04), Vector2(0.62, 0.04), 1.2, Color(0.55, 0.22, 0.18), Vector3(0, -0.34, 0.27), &"rags", Vector2.ZERO, Vector3(0.1, 0, 0))
			return [{"socket": &"chest", "node": s, "anchors": [
				_anchor(Vector3(0, 0.08, -0.24), Vector3.FORWARD),
				_anchor(Vector3(-0.45, 0.42, 0), Vector3(-0.4, 1, 0)),
				_anchor(Vector3(0.45, 0.42, 0), Vector3(0.4, 1, 0)),
				_anchor(Vector3(0, 0.1, 0.25), Vector3.BACK),
				_anchor(Vector3(-0.2, -0.15, -0.23), Vector3.FORWARD),
				_anchor(Vector3(0.2, -0.15, -0.23), Vector3.FORWARD),
			]}]
		&"helmet":
			# Шлем-«сахарная голова»: конус, крестовая прорезь, дыхательные отверстия, рваная лента.
			var s := LowPoly.pivot("Helmet")
			_fr(s, Vector2(0.32, 0.34), Vector2(0.28, 0.3), 0.32, steel, Vector3(0, 0.04, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
			_fr(s, Vector2(0.28, 0.3), Vector2(0.03, 0.03), 0.22, steel, Vector3(0, 0.31, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
			_fr(s, Vector2(0.34, 0.36), Vector2(0.33, 0.35), 0.05, steel.darkened(0.2), Vector3(0, -0.1, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
			_box(s, Vector3(0.24, 0.03, 0.02), dark, Vector3(0, 0.08, -0.171))
			_box(s, Vector3(0.03, 0.16, 0.02), dark, Vector3(0, 0.03, -0.172))
			for k in 4:
				_box(s, Vector3(0.02, 0.02, 0.02), dark, Vector3(0.06 + (k % 2) * 0.04, -0.01 - (k / 2) * 0.04, -0.168))
			_box(s, Vector3(0.06, 0.38, 0.02), Color(0.62, 0.1, 0.08), Vector3(0.04, -0.06, 0.17), &"rags", Vector3(0.25, 0, -0.15))
			return [{"socket": &"head", "node": s, "anchors": [
				_anchor(Vector3(0, 0.42, 0), Vector3.UP),
				_anchor(Vector3(-0.16, 0.1, 0), Vector3.LEFT),
				_anchor(Vector3(0.16, 0.1, 0), Vector3.RIGHT),
				_anchor(Vector3(0, 0.12, 0.16), Vector3.BACK),
				_anchor(Vector3(0, 0.18, -0.14), Vector3(0, 0.6, -1)),
				_anchor(Vector3(0, 0.28, 0.08), Vector3(0, 1, 0.6)),
			]}]
		&"gloves":
			var out := []
			for side in [&"l_hand", &"r_hand"]:
				var g := LowPoly.pivot("Gauntlet")
				_fr(g, Vector2(0.15, 0.15), Vector2(0.22, 0.22), 0.18, steel, Vector3(0, 0.14, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
				_fr(g, Vector2(0.13, 0.15), Vector2(0.17, 0.2), 0.14, steel, Vector3(0, -0.02, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
				for k in 3:
					_fr(g, Vector2(0.15 - k * 0.02, 0.14), Vector2(0.15 - k * 0.02, 0.15), 0.04, steel.darkened(0.1), Vector3(0, -0.11 - k * 0.04, -0.01), &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
				for k in 3:
					_py(g, Vector2(0.035, 0.035), 0.09, Color(1.1, 1.1, 1.15), Vector3(-0.045 + k * 0.045, -0.06, -0.1), &"iron", Vector3(deg_to_rad(-90), 0, 0), 0.7)
				var sx := -1.0 if side == &"l_hand" else 1.0
				out.append({"socket": side, "node": g, "anchors": [
					_anchor(Vector3(sx * 0.1, 0.05, 0), Vector3(sx, 0, 0)),
					_anchor(Vector3(0, 0.05, 0.1), Vector3.BACK),
					_anchor(Vector3(0, 0.22, 0), Vector3.UP),
				]})
			return out
		&"boots":
			var out := []
			for side in [&"l_foot", &"r_foot"]:
				var b := LowPoly.pivot("Sabaton")
				_fr(b, Vector2(0.24, 0.36), Vector2(0.18, 0.2), 0.18, steel, Vector3(0, 0.09, -0.02), &"iron", Vector2(0, 0.06), Vector3.ZERO, 0.6)
				_py(b, Vector2(0.18, 0.14), 0.16, steel, Vector3(0, 0.06, -0.24), &"iron", Vector3(deg_to_rad(-90), 0, 0), 0.6)
				_fr(b, Vector2(0.15, 0.16), Vector2(0.19, 0.2), 0.38, steel, Vector3(0, 0.36, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.6)
				_gm(b, 0.1, 0.06, 0.06, 6, steel, Vector3(0, 0.57, -0.05), &"iron", Vector3.ZERO, 0.6)
				_box(b, Vector3(0.22, 0.04, 0.24), white, Vector3(0, 0.24, 0), &"leather")
				var sx := -1.0 if side == &"l_foot" else 1.0
				out.append({"socket": side, "node": b, "anchors": [
					_anchor(Vector3(sx * 0.11, 0.34, 0.02), Vector3(sx, 0.3, 0.2)),
					_anchor(Vector3(0, 0.15, -0.3), Vector3.FORWARD),
					_anchor(Vector3(0, 0.42, 0.11), Vector3.BACK),
				]})
			return out
		&"amulet":
			# Кольцо с семью зубьями и бледным камнем на кожаном шнуре.
			var s := LowPoly.pivot("Amulet")
			var cord := LowPoly.torus(0.17, 0.19, 10, 3, Color(0.6, 0.45, 0.32), Vector3.ZERO, 0.9, 0.0, 0.0, &"leather")
			cord.rotation = Vector3(deg_to_rad(18), 0, 0)
			s.add_child(cord)
			var ring := LowPoly.torus(0.055, 0.075, 10, 4, steel, Vector3(0, -0.17, -0.21), 0.5, 0.6, 0.0, &"iron")
			ring.rotation.x = PI / 2
			s.add_child(ring)
			for k in 7:
				var a := TAU * k / 7.0
				_py(s, Vector2(0.025, 0.025), 0.05, steel, Vector3(cos(a) * 0.09, -0.17 + sin(a) * 0.09, -0.21), &"iron", Vector3(0, 0, a - PI / 2), 0.6)
			_gm(s, 0.035, 0.04, 0.04, 5, Color(0.8, 0.88, 1.0), Vector3(0, -0.17, -0.215), &"", Vector3(PI / 2, 0, 0), 0.0, 1.6)
			return [{"socket": &"neck", "node": s, "anchors": [
				_anchor(Vector3(0.1, -0.17, -0.2), Vector3(1, 0, -0.5)),
				_anchor(Vector3(-0.1, -0.17, -0.2), Vector3(-1, 0, -0.5)),
				_anchor(Vector3(0, -0.06, -0.21), Vector3(0, 1, -0.5)),
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
				_py(n, Vector2(0.05, 0.05), 0.17, c, Vector3((k - 1) * 0.065, 0.085, 0), &"", Vector3(0, 0, (k - 1) * -0.3), 0.3, 0.7)
		&"bulwark":
			var r := LowPoly.torus(0.07, 0.1, 8, 4, c, Vector3(0, 0.02, 0), 0.25, 0.9, 0.5)
			n.add_child(r)
			_gm(n, 0.05, 0.06, 0.02, 4, c, Vector3(0, 0.04, 0), &"", Vector3.ZERO, 0.9, 0.9)
		&"mass":
			_fr(n, Vector2(0.17, 0.13), Vector2(0.12, 0.09), 0.05, c, Vector3(0, 0.025, -0.03), &"", Vector2.ZERO, Vector3.ZERO, 0.4, 0.3)
			_fr(n, Vector2(0.15, 0.11), Vector2(0.1, 0.07), 0.05, c.darkened(0.25), Vector3(0, 0.06, 0.05), &"", Vector2.ZERO, Vector3.ZERO, 0.4, 0.3)
		&"gaze":
			_gm(n, 0.065, 0.05, 0.03, 6, Color(0.95, 0.9, 1.0), Vector3(0, 0.03, 0), &"", Vector3.ZERO, 0.0, 0.4)
			_gm(n, 0.04, 0.035, 0.0, 6, c, Vector3(0, 0.07, 0), &"", Vector3.ZERO, 0.0, 2.5)
			n.add_child(LowPoly.box(Vector3(0.025, 0.02, 0.025), Color(0.02, 0.0, 0.05), Vector3(0, 0.1, 0)))
		&"grip":
			for k in 3:
				var link := LowPoly.torus(0.02, 0.04, 6, 3, c, Vector3(0, 0.04 + k * 0.06, 0), 0.4, 0.6, 0.6)
				link.rotation = Vector3(PI / 2, 0, PI / 2 if k % 2 == 0 else 0.0)
				n.add_child(link)
		&"gust":
			for side in [-1.0, 1.0]:
				var w := Node3D.new()
				w.rotation = Vector3(0, 0, side * deg_to_rad(35))
				for f in 3:
					_fr(w, Vector2(0.02, 0.05), Vector2(0.01, 0.0), 0.15 - f * 0.03, c, Vector3(side * 0.02, 0.08 + f * 0.02, 0.05 * f - 0.05), &"", Vector2.ZERO, Vector3.ZERO, 0.0, 0.9)
				n.add_child(w)
		&"energy":
			var spin := RuneSpinner.new()
			for k in 3:
				var a := TAU * k / 3.0
				_gm(spin, 0.03, 0.05, 0.05, 4, c, Vector3(cos(a) * 0.09, 0.07, sin(a) * 0.09), &"", Vector3.ZERO, 0.0, 3.0)
			n.add_child(spin)
	return n
