class_name ActorModel
extends Node3D
## Лоу-поли гуманоид с сокетами под вещи и процедурной анимацией.
## Читает состояние своего Actor каждый кадр; разовые анимации — по сигналам.

enum Kind { HERO, INFANTRY, ARCHER, BRUTE, CASTER, BOSS, SWARM }

const SKIN := Color(0.86, 0.66, 0.52)

var actor: Actor
var kind: int = Kind.HERO
var body_color: Color = SKIN
var accent: Color = Color(0.92, 0.9, 0.84)

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var sockets: Dictionary = {}
var _item_nodes: Dictionary = {}
var _meshes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D
var _open_mat: StandardMaterial3D
var _flash: float = 0.0
var _walk: float = 0.0
var _swing_t: float = 99.0
var _swing_dur: float = 0.2
var _swing_kind: StringName = &""
var _windup: float = 0.0
var _yaw: float = 0.0
var _dying: bool = false
var _base_y: float = 0.0


func setup(p_actor: Actor, p_kind: int, p_body: Color = SKIN, p_accent: Color = Color(0.92, 0.9, 0.84)) -> void:
	actor = p_actor
	kind = p_kind
	body_color = p_body
	accent = p_accent
	_build_body()
	_flash_mat = Vfx.material(Color(1, 1, 1, 0.75), 2.0, true)
	_open_mat = Vfx.material(Color(0.68, 0.32, 0.98, 0.45), 1.6, true)
	actor.hit_received.connect(_on_hit)
	actor.items_changed.connect(refresh_items)
	actor.died.connect(_on_died)
	refresh_items()


func _build_body() -> void:
	_add_shadow()
	if kind == Kind.SWARM:
		_build_swarm()
		return
	var p := _proportions()
	hips = LowPoly.pivot("Hips", Vector3(0, p["hip_y"], 0))
	add_child(hips)
	leg_l = LowPoly.pivot("LegL", Vector3(-p["hip_w"], -0.06, 0))
	leg_r = LowPoly.pivot("LegR", Vector3(p["hip_w"], -0.06, 0))
	hips.add_child(leg_l)
	hips.add_child(leg_r)
	var leg_len: float = p["leg"]
	sockets[&"l_foot"] = _socket(leg_l, Vector3(0, -leg_len, 0))
	sockets[&"r_foot"] = _socket(leg_r, Vector3(0, -leg_len, 0))
	torso = LowPoly.pivot("Torso", Vector3(0, 0.14, 0))
	hips.add_child(torso)
	var chest_h: float = p["chest"].y
	sockets[&"chest"] = _socket(torso, Vector3(0, chest_h * 0.52, 0))
	sockets[&"neck"] = _socket(torso, Vector3(0, chest_h + 0.04, 0))
	head = LowPoly.pivot("Head", Vector3(0, chest_h + 0.04, 0))
	torso.add_child(head)
	sockets[&"head"] = _socket(head, Vector3(0, 0.2, 0))
	var shoulder: float = p["shoulder"]
	arm_l = LowPoly.pivot("ArmL", Vector3(-shoulder, chest_h - 0.04, 0))
	arm_r = LowPoly.pivot("ArmR", Vector3(shoulder, chest_h - 0.04, 0))
	torso.add_child(arm_l)
	torso.add_child(arm_r)
	var arm_len: float = p["arm"]
	sockets[&"l_hand"] = _socket(arm_l, Vector3(0, -arm_len, 0))
	sockets[&"r_hand"] = _socket(arm_r, Vector3(0, -arm_len, 0))
	match kind:
		Kind.HERO: _dress_hero(p)
		Kind.INFANTRY: _dress_infantry(p)
		Kind.ARCHER: _dress_archer(p)
		Kind.BRUTE: _dress_brute(p)
		Kind.CASTER: _dress_caster(p)
		Kind.BOSS: _dress_boss(p)
	_collect_meshes()


## Пропорции тела по типу: ширина плеч, длина рук и ног, размер торса.
func _proportions() -> Dictionary:
	match kind:
		Kind.ARCHER:
			return {"hip_y": 0.9, "hip_w": 0.11, "leg": 0.84, "chest": Vector3(0.38, 0.56, 0.22), "shoulder": 0.27, "arm": 0.66, "limb": 0.1}
		Kind.BRUTE:
			return {"hip_y": 0.82, "hip_w": 0.17, "leg": 0.76, "chest": Vector3(0.74, 0.66, 0.5), "shoulder": 0.47, "arm": 0.72, "limb": 0.24}
		Kind.CASTER:
			return {"hip_y": 0.92, "hip_w": 0.12, "leg": 0.86, "chest": Vector3(0.44, 0.6, 0.28), "shoulder": 0.3, "arm": 0.66, "limb": 0.14}
		Kind.BOSS:
			return {"hip_y": 0.94, "hip_w": 0.14, "leg": 0.88, "chest": Vector3(0.6, 0.66, 0.34), "shoulder": 0.38, "arm": 0.7, "limb": 0.18}
		Kind.INFANTRY:
			return {"hip_y": 0.9, "hip_w": 0.13, "leg": 0.84, "chest": Vector3(0.52, 0.6, 0.3), "shoulder": 0.34, "arm": 0.66, "limb": 0.16}
		_:
			return {"hip_y": 0.92, "hip_w": 0.13, "leg": 0.86, "chest": Vector3(0.58, 0.62, 0.34), "shoulder": 0.38, "arm": 0.7, "limb": 0.18}


func _add(parent: Node3D, mi: Node3D, rot: Vector3 = Vector3.ZERO) -> Node3D:
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Конечность: сегмент от сустава вниз.
func _limb_mesh(pivot: Node3D, width: float, length: float, color: Color, surface: StringName) -> void:
	pivot.add_child(LowPoly.box(Vector3(width, length, width * 1.08), color, Vector3(0, -length * 0.5, 0), 0.9, 0.0, 0.0, surface))


func _add_shadow() -> void:
	var sh := MeshInstance3D.new()
	sh.name = "BlobShadow"
	sh.mesh = Vfx.sector_mesh(0.55 if kind != Kind.SWARM else 0.45, 360.0, 0.0, 12)
	sh.material_override = Vfx.material(Color(0, 0, 0, 0.55), 1.0, false)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.position.y = 0.025
	add_child(sh)


func _eyes(color: Color, y: float, z: float, spread: float = 0.075, energy: float = 3.5) -> void:
	head.add_child(LowPoly.box(Vector3(0.06, 0.035, 0.02), color, Vector3(-spread, y, z), 0.5, 0.0, energy))
	head.add_child(LowPoly.box(Vector3(0.06, 0.035, 0.02), color, Vector3(spread, y, z), 0.5, 0.0, energy))


# --- Герой: наёмник в шрамах и бинтах, под вещами — набедренная повязка -------

func _dress_hero(p: Dictionary) -> void:
	var skin := Color(0.86, 0.8, 0.76)
	var wrap := Color(0.82, 0.78, 0.68)
	var limb: float = p["limb"]
	_limb_mesh(leg_l, limb + 0.02, p["leg"], skin, &"skin")
	_limb_mesh(leg_r, limb + 0.02, p["leg"], skin, &"skin")
	for leg in [leg_l, leg_r]:
		leg.add_child(LowPoly.box(Vector3(limb + 0.06, 0.1, limb + 0.08), wrap, Vector3(0, -0.42, 0), 0.9, 0.0, 0.0, &"cloth"))
	hips.add_child(LowPoly.box(Vector3(0.46, 0.22, 0.32), Color(0.62, 0.56, 0.46), Vector3(0, -0.02, 0), 0.9, 0.0, 0.0, &"cloth"))
	hips.add_child(LowPoly.box(Vector3(0.5, 0.08, 0.35), Color(0.7, 0.6, 0.5), Vector3(0, 0.08, 0), 0.8, 0.0, 0.0, &"leather"))
	hips.add_child(LowPoly.box(Vector3(0.24, 0.36, 0.04), Color(0.55, 0.48, 0.42), Vector3(0, -0.16, -0.17), 0.9, 0.0, 0.0, &"rags"))
	hips.add_child(LowPoly.box(Vector3(0.28, 0.32, 0.04), Color(0.5, 0.44, 0.4), Vector3(0, -0.15, 0.17), 0.9, 0.0, 0.0, &"rags"))
	var chest: Vector3 = p["chest"]
	torso.add_child(LowPoly.box(chest, skin, Vector3(0, chest.y * 0.52, 0), 0.9, 0.0, 0.0, &"skin"))
	torso.add_child(LowPoly.box(Vector3(chest.x * 0.86, 0.2, chest.z * 0.9), skin, Vector3(0, 0.06, 0), 0.9, 0.0, 0.0, &"skin"))
	# Бинт через грудь.
	_add(torso, LowPoly.box(Vector3(0.07, 0.76, chest.z + 0.02), wrap, Vector3(0, chest.y * 0.52, 0), 0.9, 0.0, 0.0, &"cloth"), Vector3(0, 0, 0.62))
	head.add_child(LowPoly.cyl(0.08, 0.09, 0.12, 6, skin, Vector3(0, 0.02, 0), 0.9, 0.0, 0.0, &"skin"))
	head.add_child(LowPoly.box(Vector3(0.3, 0.34, 0.32), skin, Vector3(0, 0.22, 0), 0.9, 0.0, 0.0, &"skin"))
	head.add_child(LowPoly.box(Vector3(0.3, 0.05, 0.04), Color(0.25, 0.18, 0.16), Vector3(0, 0.29, -0.16)))
	head.add_child(LowPoly.box(Vector3(0.05, 0.04, 0.02), Color(0.06, 0.05, 0.05), Vector3(-0.07, 0.25, -0.165)))
	head.add_child(LowPoly.box(Vector3(0.05, 0.04, 0.02), Color(0.06, 0.05, 0.05), Vector3(0.07, 0.25, -0.165)))
	_add(head, LowPoly.box(Vector3(0.02, 0.16, 0.02), Color(0.55, 0.18, 0.16), Vector3(0.05, 0.22, -0.165)), Vector3(0, 0, 0.5))
	# Чёрные растрёпанные волосы.
	var hair := Color(0.07, 0.06, 0.06)
	head.add_child(LowPoly.box(Vector3(0.33, 0.12, 0.35), hair, Vector3(0, 0.39, 0.02)))
	for k in 6:
		var a := TAU * k / 6.0
		_add(head, LowPoly.prism(Vector3(0.1, 0.2, 0.1), hair, Vector3(cos(a) * 0.1, 0.48, sin(a) * 0.1 + 0.03)), Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5))
	for arm in [arm_l, arm_r]:
		_limb_mesh(arm, limb, p["arm"], skin, &"skin")
		arm.add_child(LowPoly.box(Vector3(limb + 0.04, 0.22, limb + 0.06), wrap, Vector3(0, -0.5, 0), 0.9, 0.0, 0.0, &"cloth"))


# --- Пехотинец: восставший латник в ржавом шлеме-шапеле --------------------

func _dress_infantry(p: Dictionary) -> void:
	var flesh := Color(0.62, 0.68, 0.56)
	var mail := Color(0.75, 0.75, 0.8)
	var tabard := Color(0.6, 0.18, 0.15)
	var limb: float = p["limb"]
	for leg in [leg_l, leg_r]:
		_limb_mesh(leg, limb, p["leg"], mail, &"iron")
		leg.add_child(LowPoly.box(Vector3(limb + 0.06, 0.22, limb + 0.12), Color(0.7, 0.6, 0.5), Vector3(0, -0.74, -0.02), 0.9, 0.0, 0.0, &"leather"))
	hips.add_child(LowPoly.box(Vector3(0.44, 0.22, 0.3), mail, Vector3(0, -0.02, 0), 0.6, 0.4, 0.0, &"iron"))
	var chest: Vector3 = p["chest"]
	torso.add_child(LowPoly.box(chest, mail, Vector3(0, chest.y * 0.52, 0), 0.6, 0.4, 0.0, &"iron"))
	torso.add_child(LowPoly.box(Vector3(chest.x * 0.8, chest.y * 1.15, chest.z + 0.04), tabard, Vector3(0, chest.y * 0.4, 0), 0.9, 0.0, 0.0, &"rags"))
	head.add_child(LowPoly.box(Vector3(0.28, 0.32, 0.3), flesh, Vector3(0, 0.2, 0), 0.9, 0.0, 0.0, &"skin"))
	head.add_child(LowPoly.cyl(0.17, 0.2, 0.18, 7, Color(1, 1, 1), Vector3(0, 0.38, 0), 0.7, 0.3, 0.0, &"rust"))
	head.add_child(LowPoly.cyl(0.34, 0.34, 0.03, 9, Color(1, 1, 1), Vector3(0, 0.3, 0), 0.7, 0.3, 0.0, &"rust"))
	head.add_child(LowPoly.box(Vector3(0.18, 0.06, 0.04), Color(0.1, 0.06, 0.05), Vector3(0, 0.12, -0.15)))
	_eyes(Color(0.75, 1.0, 0.45), 0.22, -0.155, 0.065, 3.0)
	for arm in [arm_l, arm_r]:
		_limb_mesh(arm, limb, p["arm"], flesh, &"skin")
		arm.add_child(LowPoly.box(Vector3(limb + 0.08, 0.16, limb + 0.1), mail, Vector3(0, -0.06, 0), 0.6, 0.4, 0.0, &"iron"))
	var sword := LowPoly.pivot("EnemySword")
	sword.add_child(LowPoly.box(Vector3(0.09, 0.72, 0.03), Color(1, 1, 1), Vector3(0, 0.42, 0), 0.5, 0.5, 0.0, &"rust"))
	sword.add_child(LowPoly.box(Vector3(0.24, 0.05, 0.06), Color(0.35, 0.25, 0.2), Vector3(0, 0.06, 0)))
	sword.rotation.x = deg_to_rad(-100)
	sockets[&"r_hand"].add_child(sword)


# --- Лучник: скелет-арбалетчик в капюшоне ---------------------------------

func _dress_archer(p: Dictionary) -> void:
	var bone := Color(1, 1, 1)
	var hood := Color(0.35, 0.3, 0.28)
	var limb: float = p["limb"]
	for leg in [leg_l, leg_r]:
		_limb_mesh(leg, limb, p["leg"], bone, &"bone")
	hips.add_child(LowPoly.box(Vector3(0.3, 0.12, 0.18), bone, Vector3.ZERO, 0.9, 0.0, 0.0, &"bone"))
	hips.add_child(LowPoly.box(Vector3(0.36, 0.42, 0.04), hood, Vector3(0, -0.2, -0.12), 0.9, 0.0, 0.0, &"rags"))
	var chest: Vector3 = p["chest"]
	torso.add_child(LowPoly.box(Vector3(0.06, chest.y, 0.06), bone, Vector3(0, chest.y * 0.5, 0.06), 0.9, 0.0, 0.0, &"bone"))
	for k in 4:
		torso.add_child(LowPoly.box(Vector3(chest.x * (1.0 - k * 0.1), 0.05, chest.z), bone, Vector3(0, chest.y * (0.3 + k * 0.17), 0), 0.9, 0.0, 0.0, &"bone"))
	torso.add_child(LowPoly.box(Vector3(chest.x + 0.12, chest.y * 0.9, 0.05), hood, Vector3(0, chest.y * 0.55, 0.14), 0.9, 0.0, 0.0, &"rags"))
	head.add_child(LowPoly.box(Vector3(0.26, 0.28, 0.28), bone, Vector3(0, 0.2, 0), 0.9, 0.0, 0.0, &"bone"))
	head.add_child(LowPoly.box(Vector3(0.2, 0.08, 0.06), bone, Vector3(0, 0.05, -0.1), 0.9, 0.0, 0.0, &"bone"))
	head.add_child(LowPoly.box(Vector3(0.07, 0.06, 0.02), Color(0.02, 0.01, 0.01), Vector3(-0.065, 0.22, -0.142)))
	head.add_child(LowPoly.box(Vector3(0.07, 0.06, 0.02), Color(0.02, 0.01, 0.01), Vector3(0.065, 0.22, -0.142)))
	_eyes(Color(1.0, 0.2, 0.1), 0.22, -0.152, 0.065, 4.0)
	head.add_child(LowPoly.cyl(0.0, 0.25, 0.44, 6, hood, Vector3(0, 0.36, 0.04), 0.9, 0.0, 0.0, &"rags"))
	for arm in [arm_l, arm_r]:
		_limb_mesh(arm, limb, p["arm"], bone, &"bone")
	torso.add_child(LowPoly.box(Vector3(0.14, 0.5, 0.14), Color(0.8, 0.65, 0.5), Vector3(0.14, chest.y * 0.6, 0.2), 0.9, 0.0, 0.0, &"leather"))
	var bow := LowPoly.pivot("Crossbow")
	bow.add_child(LowPoly.box(Vector3(0.06, 0.06, 0.6), Color(1, 1, 1), Vector3(0, 0, -0.2), 0.9, 0.0, 0.0, &"wood"))
	bow.add_child(LowPoly.box(Vector3(0.62, 0.05, 0.05), Color(1, 1, 1), Vector3(0, 0.02, -0.46), 0.6, 0.4, 0.0, &"iron"))
	bow.add_child(LowPoly.box(Vector3(0.6, 0.01, 0.01), Color(0.8, 0.75, 0.6), Vector3(0, 0.03, -0.36)))
	bow.position = Vector3(0, -0.02, -0.04)
	bow.rotation.x = deg_to_rad(-80)
	sockets[&"l_hand"].add_child(bow)


# --- Громила: мясник-апостол с тесаком ------------------------------------

func _dress_brute(p: Dictionary) -> void:
	var flesh := Color(0.8, 0.76, 0.74)
	var pale := Color(0.72, 0.74, 0.66)
	var limb: float = p["limb"]
	for leg in [leg_l, leg_r]:
		_limb_mesh(leg, limb, p["leg"], pale, &"skin")
	hips.add_child(LowPoly.box(Vector3(0.62, 0.3, 0.46), Color(0.6, 0.5, 0.42), Vector3(0, -0.04, 0), 0.9, 0.0, 0.0, &"leather"))
	var chest: Vector3 = p["chest"]
	torso.add_child(LowPoly.box(chest, pale, Vector3(0, chest.y * 0.55, 0), 0.9, 0.0, 0.0, &"skin"))
	var belly := LowPoly.sphere(0.36, 7, 4, flesh, Vector3(0, 0.18, -0.14), 0.9, 0.0, 0.0, &"flesh")
	belly.scale = Vector3(1.0, 0.85, 0.9)
	torso.add_child(belly)
	torso.add_child(LowPoly.box(Vector3(0.6, 0.62, 0.05), Color(0.85, 0.7, 0.6), Vector3(0, 0.12, -0.36), 0.9, 0.0, 0.0, &"leather"))
	torso.add_child(LowPoly.box(Vector3(0.3, 0.2, 0.06), Color(0.45, 0.04, 0.04), Vector3(0.08, 0.0, -0.39)))
	for k in 4:
		var a := -0.6 + k * 0.4
		_add(torso, LowPoly.prism(Vector3(0.1, 0.3, 0.1), Color(1, 1, 1), Vector3(sin(a) * 0.3, chest.y + 0.05, 0.12), 0.9, 0.0, 0.0, &"bone"), Vector3(0.5, 0, a))
	head.add_child(LowPoly.box(Vector3(0.32, 0.28, 0.32), pale, Vector3(0, 0.12, -0.04), 0.9, 0.0, 0.0, &"skin"))
	head.add_child(LowPoly.box(Vector3(0.26, 0.06, 0.04), Color(0.95, 0.9, 0.75), Vector3(0, 0.02, -0.2)))
	var eye := Color(1.0, 0.15, 0.05)
	for e in [Vector3(-0.08, 0.17, -0.2), Vector3(0.08, 0.17, -0.2), Vector3(0, 0.24, -0.2)]:
		head.add_child(LowPoly.box(Vector3(0.05, 0.04, 0.02), eye, e, 0.5, 0.0, 4.0))
	for arm in [arm_l, arm_r]:
		_limb_mesh(arm, limb, p["arm"], flesh, &"flesh")
	var cleaver := LowPoly.pivot("Cleaver")
	cleaver.add_child(LowPoly.cyl(0.05, 0.05, 0.55, 6, Color(1, 1, 1), Vector3(0, 0.15, 0), 0.9, 0.0, 0.0, &"wood"))
	cleaver.add_child(LowPoly.box(Vector3(0.5, 0.8, 0.05), Color(1, 1, 1), Vector3(0.14, 0.82, 0), 0.6, 0.5, 0.0, &"rust"))
	cleaver.add_child(LowPoly.box(Vector3(0.12, 0.3, 0.06), Color(0.4, 0.03, 0.03), Vector3(0.32, 1.0, 0)))
	cleaver.rotation.x = deg_to_rad(-80)
	sockets[&"r_hand"].add_child(cleaver)


# --- Заклинатель: культист в клювастой маске со свечным посохом -------------

func _dress_caster(p: Dictionary) -> void:
	var robe := Color(0.85, 0.36, 0.32)
	var limb: float = p["limb"]
	for leg in [leg_l, leg_r]:
		_limb_mesh(leg, limb, p["leg"], robe, &"cloth")
	hips.add_child(LowPoly.cyl(0.26, 0.46, 0.92, 8, robe, Vector3(0, -0.42, 0), 0.9, 0.0, 0.0, &"rags"))
	var chest: Vector3 = p["chest"]
	torso.add_child(LowPoly.box(chest, robe, Vector3(0, chest.y * 0.52, 0), 0.9, 0.0, 0.0, &"cloth"))
	torso.add_child(LowPoly.box(Vector3(0.1, chest.y, 0.03), Color(0.75, 0.6, 0.3), Vector3(0, chest.y * 0.5, -chest.z * 0.52), 0.6, 0.4, 0.0, &"gold"))
	head.add_child(LowPoly.cyl(0.0, 0.27, 0.52, 7, robe.darkened(0.3), Vector3(0, 0.3, 0.03), 0.9, 0.0, 0.0, &"cloth"))
	head.add_child(LowPoly.box(Vector3(0.24, 0.24, 0.2), Color(1, 1, 1), Vector3(0, 0.18, -0.06), 0.9, 0.0, 0.0, &"bone"))
	_add(head, LowPoly.prism(Vector3(0.12, 0.34, 0.1), Color(1, 1, 1), Vector3(0, 0.12, -0.3), 0.9, 0.0, 0.0, &"bone"), Vector3(deg_to_rad(-100), 0, 0))
	_eyes(Color(1.0, 0.25, 0.1), 0.22, -0.162, 0.06, 4.0)
	for arm in [arm_l, arm_r]:
		_limb_mesh(arm, limb + 0.04, p["arm"], robe, &"cloth")
	var staff := LowPoly.pivot("Staff")
	staff.add_child(LowPoly.cyl(0.03, 0.035, 1.6, 5, Color(1, 1, 1), Vector3(0, 0.25, 0), 0.9, 0.0, 0.0, &"wood"))
	staff.add_child(LowPoly.box(Vector3(0.16, 0.16, 0.16), Color(1, 1, 1), Vector3(0, 1.08, 0), 0.9, 0.0, 0.0, &"bone"))
	staff.add_child(LowPoly.cyl(0.03, 0.04, 0.12, 5, Color(0.9, 0.85, 0.7), Vector3(0, 1.22, 0)))
	staff.add_child(LowPoly.prism(Vector3(0.07, 0.14, 0.07), Color(1.0, 0.45, 0.15), Vector3(0, 1.35, 0), 0.5, 0.0, 4.0))
	sockets[&"r_hand"].add_child(staff)


# --- Босс: чёрный рыцарь с черепом, короной шипов и затмением за спиной ---

func _dress_boss(p: Dictionary) -> void:
	var body := Color(0.13, 0.1, 0.14)
	var limb: float = p["limb"]
	for leg in [leg_l, leg_r]:
		_limb_mesh(leg, limb, p["leg"], body, &"iron")
	hips.add_child(LowPoly.box(Vector3(0.48, 0.26, 0.34), body, Vector3(0, -0.02, 0), 0.6, 0.4, 0.0, &"iron"))
	var chest: Vector3 = p["chest"]
	torso.add_child(LowPoly.box(chest, body, Vector3(0, chest.y * 0.52, 0), 0.6, 0.4, 0.0, &"iron"))
	torso.add_child(LowPoly.box(Vector3(0.9, 1.6, 0.04), Color(0.22, 0.12, 0.14), Vector3(0, -0.15, 0.26), 0.9, 0.0, 0.0, &"rags"))
	head.add_child(LowPoly.box(Vector3(0.3, 0.32, 0.32), Color(0.75, 0.72, 0.65), Vector3(0, 0.2, 0), 0.9, 0.0, 0.0, &"bone"))
	head.add_child(LowPoly.box(Vector3(0.22, 0.1, 0.08), Color(0.75, 0.72, 0.65), Vector3(0, 0.04, -0.12), 0.9, 0.0, 0.0, &"bone"))
	head.add_child(LowPoly.box(Vector3(0.08, 0.07, 0.02), Color(0.01, 0.0, 0.0), Vector3(-0.07, 0.22, -0.162)))
	head.add_child(LowPoly.box(Vector3(0.08, 0.07, 0.02), Color(0.01, 0.0, 0.0), Vector3(0.07, 0.22, -0.162)))
	_eyes(Color(1.0, 0.1, 0.05), 0.22, -0.172, 0.07, 5.0)
	for k in 7:
		var a := TAU * k / 7.0
		_add(head, LowPoly.prism(Vector3(0.05, 0.22, 0.05), Color(1, 1, 1), Vector3(cos(a) * 0.15, 0.44, sin(a) * 0.15), 0.6, 0.4, 0.0, &"iron"), Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3))
	for arm in [arm_l, arm_r]:
		_limb_mesh(arm, limb, p["arm"], body, &"iron")
	# Затмение: чёрный диск в багровой короне за головой.
	var halo := LowPoly.pivot("Eclipse", Vector3(0, 0.25, 0.34))
	var disc := LowPoly.cyl(0.42, 0.42, 0.03, 16, Color(0.0, 0.0, 0.0))
	disc.rotation.x = PI / 2
	halo.add_child(disc)
	var corona := LowPoly.torus(0.42, 0.54, 16, 4, Color(0.9, 0.12, 0.06), Vector3.ZERO, 0.5, 0.0, 3.5)
	corona.rotation.x = PI / 2
	halo.add_child(corona)
	head.add_child(halo)


## Рой: бес-падальщик на четырёх лапах, с пастью и костяными шипами по хребту.
func _build_swarm() -> void:
	hips = LowPoly.pivot("Hips", Vector3(0, 0.9, 0))
	add_child(hips)
	torso = LowPoly.pivot("Torso")
	hips.add_child(torso)
	head = LowPoly.pivot("Head")
	torso.add_child(head)
	arm_l = LowPoly.pivot("ArmL")
	arm_r = LowPoly.pivot("ArmR")
	leg_l = LowPoly.pivot("LegL")
	leg_r = LowPoly.pivot("LegR")
	for n in [arm_l, arm_r, leg_l, leg_r]:
		torso.add_child(n)
	var body := LowPoly.pivot("Body", Vector3(0, -0.55, 0))
	torso.add_child(body)
	var flesh := Color(0.85, 0.72, 0.72)
	var trunk := LowPoly.sphere(0.36, 7, 4, flesh, Vector3(0, 0.08, 0.08), 0.9, 0.0, 0.0, &"flesh")
	trunk.scale = Vector3(0.9, 0.7, 1.35)
	body.add_child(trunk)
	var jaw := LowPoly.box(Vector3(0.3, 0.2, 0.3), flesh, Vector3(0, 0.08, -0.46), 0.9, 0.0, 0.0, &"flesh")
	body.add_child(jaw)
	body.add_child(LowPoly.box(Vector3(0.24, 0.05, 0.04), Color(0.25, 0.02, 0.03), Vector3(0, 0.03, -0.62)))
	for k in 4:
		_add(body, LowPoly.prism(Vector3(0.04, 0.08, 0.04), Color(0.95, 0.9, 0.8), Vector3(-0.09 + k * 0.06, 0.09, -0.62)), Vector3(PI, 0, 0))
	var eye := Color(1.0, 0.85, 0.15)
	body.add_child(LowPoly.box(Vector3(0.06, 0.04, 0.03), eye, Vector3(-0.08, 0.17, -0.6), 0.5, 0.0, 4.0))
	body.add_child(LowPoly.box(Vector3(0.06, 0.04, 0.03), eye, Vector3(0.08, 0.17, -0.6), 0.5, 0.0, 4.0))
	for k in 4:
		_add(body, LowPoly.prism(Vector3(0.07, 0.2, 0.07), Color(1, 1, 1), Vector3(0, 0.32, 0.25 - k * 0.15), 0.9, 0.0, 0.0, &"bone"), Vector3(-0.4, 0, 0))
	for side in [-1.0, 1.0]:
		for k in 2:
			_add(body, LowPoly.box(Vector3(0.36, 0.07, 0.07), flesh.darkened(0.3), Vector3(side * 0.34, -0.12, -0.18 + k * 0.4), 0.9, 0.0, 0.0, &"flesh"), Vector3(0, 0, side * -0.7))
	_add(body, LowPoly.box(Vector3(0.05, 0.05, 0.45), flesh.darkened(0.2), Vector3(0, 0.12, 0.62), 0.9, 0.0, 0.0, &"flesh"), Vector3(0.3, 0, 0))
	sockets[&"chest"] = _socket(body, Vector3(0, 0.34, 0.05))
	for key in [&"head", &"neck", &"l_hand", &"r_hand", &"l_foot", &"r_foot"]:
		sockets[key] = sockets[&"chest"]
	_collect_meshes()


func _socket(parent: Node3D, pos: Vector3) -> Node3D:
	var s := LowPoly.pivot("Socket", pos)
	parent.add_child(s)
	return s


func _collect_meshes() -> void:
	_meshes.clear()
	_collect(self)


func _collect(n: Node) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			_meshes.append(ch)
		_collect(ch)


## Перевешивает меши вещей по текущему набору: пожертвованные исчезают, на получателе растут добавки.
func refresh_items() -> void:
	for nodes in _item_nodes.values():
		for n in nodes:
			(n as Node).queue_free()
	_item_nodes.clear()
	for state in actor.items:
		var nodes := []
		for part in ItemVisuals.build(state):
			var socket: Node3D = sockets.get(part["socket"])
			if socket == null:
				socket = sockets[&"chest"]
			socket.add_child(part["node"])
			nodes.append(part["node"])
		_item_nodes[state.def_id] = nodes
	_hide_kind_weapons()
	_connect_actions()
	_collect_meshes.call_deferred()


func _connect_actions() -> void:
	var comps: Array = actor.components.values()
	if actor.innate != null:
		comps.append(actor.innate)
	for c in comps:
		var comp := c as ActionComponent
		if not comp.used.is_connected(_on_action_used):
			comp.used.connect(_on_action_used.bind(comp))


func _on_action_used(_ctx: ActionContext, comp: ActionComponent) -> void:
	if comp is SwordAction:
		var step := (comp as SwordAction).combo_step
		play_swing([&"slash", &"slash_back", &"chop"][clampi(step, 0, 2)], 0.3 if step == 2 else 0.2)
	elif comp is FistAction:
		play_swing(&"punch", 0.18)
	elif comp is GlovesAction:
		play_swing(&"grab", 0.3)
	elif comp is AmuletAction:
		play_swing(&"cast", 0.32)
	elif comp is EnemyAttack:
		match (comp as EnemyAttack).edef.behavior:
			EnemyDef.Behavior.CASTER:
				play_swing(&"cast", 0.3)
			EnemyDef.Behavior.RANGED:
				play_swing(&"punch", 0.2)
			EnemyDef.Behavior.SWARM:
				pass
			_:
				play_swing(&"chop", 0.22)


## Элита с мечом/щитом героя прячет собственное оружие.
func _hide_kind_weapons() -> void:
	var r_hand: Node3D = sockets[&"r_hand"]
	for ch in r_hand.get_children():
		if ch.name in ["EnemySword", "Cleaver", "Staff"]:
			(ch as Node3D).visible = not actor.has_item(&"sword")


## Прячет добавки свойств с индекса start (новые после жертвы) — они вырастут, когда долетит поток.
func hide_addons(item_id: StringName, start: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in _item_nodes.get(item_id, []):
		_find_addons(n, start, out)
	for a in out:
		a.set_meta(&"full_scale", a.scale)
		a.scale = Vector3.ONE * 0.001
	return out


func _find_addons(n: Node, start: int, out: Array[Node3D]) -> void:
	for ch in n.get_children():
		if ch.has_meta(&"prop_index") and int(ch.get_meta(&"prop_index")) >= start:
			out.append(ch)
		_find_addons(ch, start, out)


func reveal_addons(addons: Array[Node3D]) -> void:
	for a in addons:
		if is_instance_valid(a):
			var tw := a.create_tween()
			tw.tween_property(a, "scale", a.get_meta(&"full_scale", Vector3.ONE) * 1.4, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(a, "scale", a.get_meta(&"full_scale", Vector3.ONE), 0.15)
	_flash = 0.12


## Позиция сокета в мире: откуда летят потоки при жертве.
func socket_position(id: StringName) -> Vector3:
	var socket_name: StringName = &"chest"
	match id:
		&"sword": socket_name = &"r_hand"
		&"shield": socket_name = &"l_hand"
		&"helmet": socket_name = &"head"
		&"gloves": socket_name = &"r_hand"
		&"boots": socket_name = &"r_foot"
		&"amulet": socket_name = &"neck"
	var s: Node3D = sockets.get(socket_name)
	return s.global_position if s != null else global_position + Vector3(0, 1, 0)


func play_swing(kind_name: StringName, duration: float = 0.2) -> void:
	_swing_kind = kind_name
	_swing_dur = duration
	_swing_t = 0.0


func set_windup(progress: float) -> void:
	_windup = progress


func _on_hit(_amount: float, _crit: bool, _ctx: ActionContext) -> void:
	_flash = 0.09


func _on_died(_a: Actor) -> void:
	_dying = true
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", deg_to_rad(80), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", -0.6, 0.8).set_delay(0.3)


func _process(delta: float) -> void:
	if actor == null or _dying:
		return
	if actor.innate is EnemyAttack:
		_windup = (actor.innate as EnemyAttack).windup_progress()
	_animate(delta)
	_update_overlay(delta)


func _animate(delta: float) -> void:
	# Поворот к взгляду.
	var target_yaw := atan2(-actor.facing.x, -actor.facing.z)
	_yaw = lerp_angle(_yaw, target_yaw, minf(1.0, delta * 18.0))
	rotation.y = _yaw
	var speed := Combat.flat(actor.velocity).length()
	var moving := clampf(speed / maxf(actor.base_speed, 0.1), 0.0, 1.0)
	_walk += delta * (4.0 + speed * 1.6)
	var swing := sin(_walk) * 0.7 * moving
	leg_l.rotation.x = swing
	leg_r.rotation.x = -swing
	hips.position.y = 0.9 + absf(cos(_walk)) * 0.05 * moving
	torso.rotation = Vector3(-0.12 * moving, 0, 0)
	if actor.is_dashing():
		torso.rotation.x = -0.45
	if actor.stun_time > 0.0:
		torso.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.15
	# Руки: базовая поза плюс ходьба.
	var arm_l_basis := Basis(Vector3.RIGHT, -swing * 0.6)
	var arm_r_basis := Basis(Vector3.RIGHT, swing * 0.6)
	if actor.has_item(&"sword") or kind != Kind.HERO:
		arm_r_basis = Basis(Vector3.RIGHT, 0.35 + swing * 0.3)
	match kind:
		Kind.ARCHER:
			arm_l_basis = Basis(Vector3.UP, -0.35) * Basis(Vector3.RIGHT, 1.2)
			arm_r_basis = Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, 1.1)
		Kind.BRUTE:
			arm_l_basis = Basis(Vector3.FORWARD, 0.25) * arm_l_basis
		Kind.CASTER:
			arm_r_basis = Basis(Vector3.RIGHT, 0.6 + swing * 0.2)
	if actor.block_arc_degrees > 0.0:
		arm_l_basis = Basis(Vector3.UP, -0.9) * Basis(Vector3.RIGHT, 1.25)
	elif actor.has_item(&"shield"):
		arm_l_basis = Basis(Vector3.UP, -0.2) * Basis(Vector3.RIGHT, 0.4)
	# Замах врага: рука уходит назад-вверх.
	if _windup > 0.0:
		arm_r_basis = Basis(Vector3.RIGHT, lerpf(0.35, 2.6, _windup))
		torso.rotation.y = lerpf(0.0, 0.5, _windup)
	# Удар.
	_swing_t += delta
	if _swing_t < _swing_dur:
		var k := _swing_t / _swing_dur
		var e := 1.0 - pow(1.0 - k, 3.0)
		match _swing_kind:
			&"slash":
				arm_r_basis = Basis(Vector3.UP, lerpf(1.3, -1.1, e)) * Basis(Vector3.RIGHT, 1.45)
				torso.rotation.y = lerpf(0.5, -0.45, e)
			&"slash_back":
				arm_r_basis = Basis(Vector3.UP, lerpf(-1.1, 1.2, e)) * Basis(Vector3.RIGHT, 1.45)
				torso.rotation.y = lerpf(-0.45, 0.45, e)
			&"chop":
				arm_r_basis = Basis(Vector3.RIGHT, lerpf(2.9, 0.9, e))
				torso.rotation.x = lerpf(0.1, -0.35, e)
			&"punch":
				arm_r_basis = Basis(Vector3.RIGHT, lerpf(0.4, 1.55, sin(k * PI)))
				torso.rotation.y = lerpf(0.0, -0.35, sin(k * PI))
			&"cast":
				arm_r_basis = Basis(Vector3.RIGHT, lerpf(0.4, 2.4, sin(k * PI)))
				arm_l_basis = Basis(Vector3.RIGHT, lerpf(0.4, 2.4, sin(k * PI)))
			&"grab":
				arm_r_basis = Basis(Vector3.RIGHT, lerpf(1.55, 1.2, e))
				arm_l_basis = Basis(Vector3.RIGHT, lerpf(1.55, 1.2, e))
	arm_l.basis = arm_l_basis
	arm_r.basis = arm_r_basis


func _update_overlay(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	var overlay: Material = null
	if _flash > 0.0:
		overlay = _flash_mat
	elif actor.faction != Actor.Faction.HERO and _is_open_to_hero():
		overlay = _open_mat
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = overlay


## Окно уязвимости подсвечено, только если у героя есть шлем (или враг открыт Взором).
func _is_open_to_hero() -> bool:
	if actor.open_time > 0.0:
		return true
	var hero := Combat.hero
	if hero == null or not is_instance_valid(hero) or hero.dead:
		return false
	var w := hero.helmet_window()
	return w > 0.0 and actor.time_since_attack() <= w
