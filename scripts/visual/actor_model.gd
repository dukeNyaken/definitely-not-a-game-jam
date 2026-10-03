class_name ActorModel
extends Node3D
## Лоу-поли гуманоид с сокетами под вещи и процедурной анимацией.
## Читает состояние своего Actor каждый кадр; разовые анимации — по сигналам.

## SLIME, JESTER — враги; после них — люди сюжетных сцен (наряды в NpcLooks).
enum Kind { HERO, INFANTRY, ARCHER, BRUTE, CASTER, BOSS, SWARM, SLIME, JESTER, FRIEND, BELOVED, FAITHFUL, REFUGEE, CAPTAIN, WIDOW, SMITH, NOVICE, TYRANT, FATHER, MOTHER }

const SLIME_EDGE := 0.95
## Сгенерированные сетки без скелета (experiments/char3d): если есть — вместо примитивов.
const SWARM_GLB := "res://assets/characters/enemies/swarm.glb"
const SLIME_SKULL_GLB := "res://assets/characters/enemies/slime_skull.glb"

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
var _crown: Node3D
## Вариант наряда (например, &"young" — Тиран во флешбэке). Задаётся до setup().
var variant: StringName = &""
## Поза сюжетной сцены: &"kneel", &"slump", &"sit", &"hold", &"bow", &"offer", &"ease", &"arms_up", &"hands_back",
## &"shield_up", &"lantern", &"sling", &"frail", &"frail_offer", &"wring", &"downcast", &"huddle". Пустая — обычная анимация;
## rest_pose — поза по умолчанию у NPC.
var pose: StringName = &""
var rest_pose: StringName = &""


## Рука, которой модель тянется в позе p: в неё сцена кладёт то, что протягивают.
## У процедурной модели — правая; у сгенерированной зависит от клипа (SkinnedActorModel).
func pose_hand(_p: StringName) -> StringName:
	return &"r_hand"


## Осколки короны босса по вещам: def_id → узел.
var _crown_shards: Dictionary = {}
var _slime_cube: Node3D
var _roll_basis: Basis = Basis()
var _roll_phase: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _hop: float = 0.0
var _flip_t: float = -1.0
var _jester_dashing: bool = false
var _stab_left: bool = false


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
	if kind == Kind.SLIME:
		_build_slime()
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
		Kind.JESTER: _dress_jester(p)
		_: NpcLooks.dress(self, p)
	_collect_meshes()


func is_npc() -> bool:
	return kind >= Kind.FRIEND


## Пропорции тела по типу: ширина плеч, длина рук и ног, размер торса.
func _proportions() -> Dictionary:
	match kind:
		Kind.ARCHER:
			return {"hip_y": 0.9, "hip_w": 0.11, "leg": 0.84, "chest": Vector3(0.38, 0.56, 0.22), "shoulder": 0.27, "arm": 0.66, "limb": 0.1}
		Kind.BRUTE:
			return {"hip_y": 0.82, "hip_w": 0.17, "leg": 0.76, "chest": Vector3(0.78, 0.68, 0.5), "shoulder": 0.48, "arm": 0.72, "limb": 0.24}
		Kind.CASTER:
			return {"hip_y": 0.92, "hip_w": 0.12, "leg": 0.86, "chest": Vector3(0.44, 0.6, 0.28), "shoulder": 0.3, "arm": 0.66, "limb": 0.14}
		Kind.BOSS:
			return {"hip_y": 0.96, "hip_w": 0.14, "leg": 0.9, "chest": Vector3(0.62, 0.7, 0.34), "shoulder": 0.4, "arm": 0.74, "limb": 0.17}
		Kind.JESTER:
			return {"hip_y": 0.46, "hip_w": 0.12, "leg": 0.42, "chest": Vector3(0.5, 0.42, 0.34), "shoulder": 0.3, "arm": 0.4, "limb": 0.12}
		Kind.INFANTRY:
			return {"hip_y": 0.9, "hip_w": 0.13, "leg": 0.84, "chest": Vector3(0.52, 0.6, 0.3), "shoulder": 0.34, "arm": 0.66, "limb": 0.16}
		Kind.BELOVED, Kind.FAITHFUL, Kind.WIDOW, Kind.MOTHER:
			return {"hip_y": 0.9, "hip_w": 0.11, "leg": 0.84, "chest": Vector3(0.44, 0.56, 0.28), "shoulder": 0.29, "arm": 0.64, "limb": 0.13}
		Kind.SMITH:
			return {"hip_y": 0.88, "hip_w": 0.15, "leg": 0.8, "chest": Vector3(0.72, 0.62, 0.42), "shoulder": 0.44, "arm": 0.7, "limb": 0.22}
		Kind.TYRANT:
			return {"hip_y": 0.95, "hip_w": 0.13, "leg": 0.89, "chest": Vector3(0.6, 0.64, 0.34), "shoulder": 0.39, "arm": 0.72, "limb": 0.18}
		_:
			return {"hip_y": 0.92, "hip_w": 0.13, "leg": 0.86, "chest": Vector3(0.6, 0.62, 0.34), "shoulder": 0.39, "arm": 0.7, "limb": 0.19}


# --- Строительные блоки -----------------------------------------------------

func _put(parent: Node3D, mi: MeshInstance3D, rot: Vector3) -> MeshInstance3D:
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Усечённая пирамида: нижний и верхний прямоугольники X×Z.
func _f(parent: Node3D, bottom: Vector2, top: Vector2, h: float, color: Color, pos: Vector3, surface: StringName = &"", top_offset: Vector2 = Vector2.ZERO, rot: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	return _put(parent, LowPoly.frustum(bottom, top, h, color, pos, surface, top_offset, metallic, emission), rot)


func _pyr(parent: Node3D, base: Vector2, h: float, color: Color, pos: Vector3, surface: StringName = &"", rot: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	return _put(parent, LowPoly.pyramid(base, h, color, pos, surface, metallic, emission), rot)


func _bx(parent: Node3D, size: Vector3, color: Color, pos: Vector3, surface: StringName = &"", rot: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	return _put(parent, LowPoly.box(size, color, pos, 0.6 if metallic > 0.0 else 0.9, metallic, emission, surface), rot)


func _gm(parent: Node3D, r: float, up: float, down: float, sides: int, color: Color, pos: Vector3, surface: StringName = &"", rot: Vector3 = Vector3.ZERO, metallic: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	return _put(parent, LowPoly.gem(r, up, down, sides, color, pos, surface, metallic, emission), rot)


## Сужающаяся гранёная конечность от сустава вниз (радиусы сверху и снизу).
func _limb(pivot: Node3D, top_r: float, bottom_r: float, length: float, color: Color, surface: StringName, sides: int = 6) -> void:
	pivot.add_child(LowPoly.cyl(top_r, bottom_r, length, sides, color, Vector3(0, -length * 0.5, 0), 0.9, 0.0, 0.0, surface))


## Овальная гранёная «бочка»: торс, таз, брюхо. depth — сплющивание по глубине.
func _oval(parent: Node3D, top_r: float, bottom_r: float, h: float, depth: float, color: Color, pos: Vector3, surface: StringName = &"", sides: int = 8, rot: Vector3 = Vector3.ZERO, metallic: float = 0.0) -> MeshInstance3D:
	var mi := LowPoly.cyl(top_r, bottom_r, h, sides, color, pos, 0.6 if metallic > 0.0 else 0.9, metallic, 0.0, surface)
	mi.scale = Vector3(1.0, 1.0, depth)
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Гранёный шар (голова, сустав, мышца).
func _ball(parent: Node3D, r: float, color: Color, pos: Vector3, surface: StringName = &"", scale_v: Vector3 = Vector3.ONE, segments: int = 7, rings: int = 4) -> MeshInstance3D:
	var mi := LowPoly.sphere(r, segments, rings, color, pos, 0.9, 0.0, 0.0, surface)
	mi.scale = scale_v
	parent.add_child(mi)
	return mi


func _add_shadow() -> void:
	var sh := MeshInstance3D.new()
	sh.name = "BlobShadow"
	sh.mesh = Vfx.sector_mesh(0.55 if kind != Kind.SWARM else 0.45, 360.0, 0.0, 12)
	sh.material_override = Vfx.material(Color(0, 0, 0, 0.55), 1.0, false)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.position.y = 0.025
	add_child(sh)


func _eyes(color: Color, y: float, z: float, spread: float = 0.075, energy: float = 3.5) -> void:
	_bx(head, Vector3(0.06, 0.035, 0.02), color, Vector3(-spread, y, z), &"", Vector3.ZERO, 0.0, energy)
	_bx(head, Vector3(0.06, 0.035, 0.02), color, Vector3(spread, y, z), &"", Vector3.ZERO, 0.0, energy)


## Голая ступня: клин носком вперёд.
func _foot(leg: Node3D, length: float, color: Color, surface: StringName) -> void:
	_f(leg, Vector2(0.15, 0.3), Vector2(0.12, 0.12), 0.11, color, Vector3(0, -length + 0.03, -0.05), surface, Vector2(0, 0.07))


## Кисть: небольшая усечённая пирамида.
func _hand(arm: Node3D, length: float, color: Color, surface: StringName) -> void:
	_f(arm, Vector2(0.1, 0.08), Vector2(0.12, 0.11), 0.14, color, Vector3(0, -length - 0.02, 0), surface)


# --- Герой: бритоголовый наёмник со шрамами, бородой и в бинтах ----------------

func _dress_hero(p: Dictionary) -> void:
	var skin := Color(0.9, 0.82, 0.76)
	var wrap := Color(0.86, 0.8, 0.68)
	var leg_len: float = p["leg"]
	var arm_len: float = p["arm"]
	for leg in [leg_l, leg_r]:
		_limb(leg, 0.13, 0.075, leg_len, skin, &"skin")
		_ball(leg, 0.11, skin, Vector3(0, -0.2, -0.01), &"skin", Vector3(1, 1.6, 1))
		_ball(leg, 0.075, skin, Vector3(0, -0.6, 0.02), &"skin", Vector3(1, 1.7, 1))
		_oval(leg, 0.105, 0.1, 0.08, 1.0, wrap, Vector3(0, -0.45, 0), &"cloth", 6)
		_foot(leg, leg_len, skin, &"skin")
	# Таз, пояс, набедренная повязка.
	_oval(hips, 0.24, 0.19, 0.24, 0.72, Color(0.66, 0.6, 0.5), Vector3(0, -0.03, 0), &"cloth")
	_oval(hips, 0.26, 0.25, 0.08, 0.72, Color(0.75, 0.62, 0.5), Vector3(0, 0.08, 0), &"leather")
	_f(hips, Vector2(0.3, 0.04), Vector2(0.2, 0.04), 0.42, Color(0.6, 0.52, 0.44), Vector3(0, -0.21, -0.17), &"rags")
	_f(hips, Vector2(0.34, 0.04), Vector2(0.24, 0.04), 0.38, Color(0.55, 0.48, 0.42), Vector3(0, -0.19, 0.17), &"rags")
	# Торс клином: широкая грудь, узкая талия, грудные мышцы, трапеции.
	var chest: Vector3 = p["chest"]
	_oval(torso, 0.34, 0.21, chest.y * 0.8, 0.6, skin, Vector3(0, chest.y * 0.47, 0), &"skin")
	_oval(torso, 0.22, 0.2, 0.2, 0.66, skin, Vector3(0, 0.05, 0), &"skin")
	for side in [-1.0, 1.0]:
		_ball(torso, 0.13, skin, Vector3(side * 0.11, chest.y * 0.68, -0.12), &"skin", Vector3(1.0, 0.75, 0.55))
	_f(torso, Vector2(0.5, 0.2), Vector2(0.18, 0.16), 0.16, skin, Vector3(0, chest.y * 0.92, 0.03), &"skin")
	_bx(torso, Vector3(0.07, 0.8, chest.z * 0.72), wrap, Vector3(0, chest.y * 0.5, 0), &"cloth", Vector3(0, 0, 0.62))
	# Голова: бритый череп, тяжёлая челюсть, борода, шрам.
	head.add_child(LowPoly.cyl(0.07, 0.08, 0.14, 6, skin, Vector3(0, 0.03, 0), 0.9, 0.0, 0.0, &"skin"))
	_ball(head, 0.16, skin, Vector3(0, 0.25, 0.01), &"skin", Vector3(0.95, 1.12, 1.05))
	_f(head, Vector2(0.18, 0.16), Vector2(0.26, 0.24), 0.14, skin, Vector3(0, 0.15, -0.03), &"skin")
	_bx(head, Vector3(0.26, 0.04, 0.06), skin.darkened(0.15), Vector3(0, 0.28, -0.14), &"skin")
	_put(head, LowPoly.wedge(Vector3(0.05, 0.09, 0.07), skin, Vector3(0, 0.22, -0.17), &"skin"), Vector3(deg_to_rad(-90), 0, 0))
	_bx(head, Vector3(0.05, 0.03, 0.02), Color(0.05, 0.04, 0.04), Vector3(-0.065, 0.25, -0.163))
	_bx(head, Vector3(0.05, 0.03, 0.02), Color(0.05, 0.04, 0.04), Vector3(0.065, 0.25, -0.163))
	var beard := Color(0.3, 0.21, 0.16)
	_f(head, Vector2(0.12, 0.1), Vector2(0.26, 0.2), 0.16, beard, Vector3(0, 0.09, -0.07), &"fur")
	_bx(head, Vector3(0.025, 0.2, 0.02), Color(0.62, 0.2, 0.18), Vector3(0.06, 0.33, -0.15), &"", Vector3(0, 0, 0.45))
	for side in [-1.0, 1.0]:
		_ball(head, 0.04, skin, Vector3(side * 0.155, 0.23, 0.02), &"skin", Vector3(0.6, 1.2, 1), 5, 3)
	for arm in [arm_l, arm_r]:
		_ball(arm, 0.13, skin, Vector3(0, -0.04, 0), &"skin", Vector3(1, 0.9, 1))
		_limb(arm, 0.1, 0.065, arm_len, skin, &"skin")
		_ball(arm, 0.09, skin, Vector3(0, -0.22, 0.01), &"skin", Vector3(1, 1.6, 1))
		_oval(arm, 0.085, 0.08, 0.22, 1.0, wrap, Vector3(0, -0.5, 0), &"cloth", 6)
		_hand(arm, arm_len, skin, &"skin")


# --- Пехотинец: восставший мертвец в кольчуге и ржавой шапели ---------------

func _dress_infantry(p: Dictionary) -> void:
	var corpse := Color(0.66, 0.74, 0.6)
	var mail := Color(0.85, 0.85, 0.9)
	var tabard := Color(0.75, 0.22, 0.17)
	var leg_len: float = p["leg"]
	var arm_len: float = p["arm"]
	for leg in [leg_l, leg_r]:
		_limb(leg, 0.11, 0.07, leg_len, mail, &"iron")
		_f(leg, Vector2(0.17, 0.32), Vector2(0.14, 0.17), 0.2, Color(0.72, 0.6, 0.5), Vector3(0, -leg_len + 0.1, -0.03), &"leather", Vector2(0, 0.04))
	_oval(hips, 0.25, 0.24, 0.3, 0.72, mail, Vector3(0, -0.06, 0), &"iron", 8, Vector3.ZERO, 0.3)
	var chest: Vector3 = p["chest"]
	_oval(torso, 0.3, 0.22, chest.y * 0.9, 0.62, mail, Vector3(0, chest.y * 0.45, 0), &"iron", 8, Vector3.ZERO, 0.3)
	# Табард: сужается к плечам, рваный низ.
	_f(torso, Vector2(0.42, 0.02), Vector2(0.3, 0.02), 0.95, tabard, Vector3(0, 0.12, -chest.z * 0.55), &"rags")
	_f(torso, Vector2(0.42, 0.02), Vector2(0.3, 0.02), 0.95, tabard, Vector3(0, 0.12, chest.z * 0.55), &"rags")
	_oval(torso, 0.26, 0.26, 0.06, 0.66, Color(0.65, 0.52, 0.42), Vector3(0, 0.0, 0), &"leather")
	# Голова: впалый череп, отвисшая челюсть, шапель.
	_ball(head, 0.14, corpse, Vector3(0, 0.21, 0), &"skin", Vector3(0.9, 1.15, 1.0))
	_f(head, Vector2(0.12, 0.1), Vector2(0.18, 0.16), 0.12, corpse.darkened(0.15), Vector3(0, 0.07, -0.05), &"skin")
	_bx(head, Vector3(0.12, 0.05, 0.03), Color(0.12, 0.06, 0.05), Vector3(0, 0.1, -0.12))
	_eyes(Color(0.75, 1.0, 0.45), 0.24, -0.135, 0.055, 3.0)
	# Шапель вдвое больше головы: поля шире плеч.
	head.add_child(LowPoly.cyl(0.66, 0.7, 0.05, 11, Color(1, 1, 1), Vector3(0, 0.31, 0), 0.6, 0.4, 0.0, &"rust"))
	head.add_child(LowPoly.cyl(0.14, 0.34, 0.36, 8, Color(1, 1, 1), Vector3(0, 0.5, 0), 0.6, 0.4, 0.0, &"rust"))
	_pyr(head, Vector2(0.12, 0.12), 0.2, Color(1, 1, 1), Vector3(0, 0.78, 0), &"rust", Vector3.ZERO, 0.4)
	for arm in [arm_l, arm_r]:
		_limb(arm, 0.085, 0.055, arm_len, corpse, &"skin")
		_oval(arm, 0.12, 0.11, 0.2, 1.0, mail, Vector3(0, -0.08, 0), &"iron", 6, Vector3.ZERO, 0.3)
		_hand(arm, arm_len, corpse, &"skin")
	sockets[&"r_hand"].add_child(katana())


# --- Оружие врагов: отдельные предметы на сокетах, общие с сгенерированными телами ----
# Клинок вдоль +Y, как у меча героя (ItemVisuals): сокет повернут так, что ось руки ведёт его.

## Большая двуручная катана пехотинца: длинная рукоять в оплётке, цуба, изогнутый клинок.
func katana() -> Node3D:
	var k := LowPoly.pivot("Katana")
	var steel := Color(1.25, 1.25, 1.32)
	# рукоять на две ладони, ниже кисти
	_f(k, Vector2(0.045, 0.04), Vector2(0.04, 0.035), 0.5, Color(0.15, 0.08, 0.07), Vector3(0, -0.2, 0), &"leather")
	for i in 4:
		_bx(k, Vector3(0.05, 0.02, 0.045), Color(0.7, 0.6, 0.4), Vector3(0, -0.38 + i * 0.12, 0), &"cloth", Vector3(0, 0, 0.5))
	k.add_child(LowPoly.cyl(0.1, 0.1, 0.025, 8, Color(0.3, 0.26, 0.2), Vector3(0, 0.07, 0), 0.6, 0.5, 0.0, &"iron"))
	# изгиб: три звена, каждое чуть отклонено назад
	var at := Vector3(0, 0.08, 0)
	var tilt := 0.0
	for i in 3:
		var seg := LowPoly.pivot("Blade%d" % i, at)
		seg.rotation.x = tilt
		k.add_child(seg)
		_f(seg, Vector2(0.075, 0.025), Vector2(0.07, 0.022), 0.46, steel, Vector3(0, 0.23, 0), &"iron", Vector2.ZERO, Vector3.ZERO, 0.7)
		at += Vector3(0, cos(tilt), sin(tilt)) * 0.46
		tilt += 0.06
	_put(k, LowPoly.wedge(Vector3(0.07, 0.16, 0.022), steel, at + Vector3(0, 0.07, 0.01), &"iron", 0.7), Vector3(tilt, 0, 0))
	k.rotation.x = deg_to_rad(-100)
	return k


# --- Лучник: скелет-арбалетчик в остроконечном капюшоне --------------------

func _dress_archer(p: Dictionary) -> void:
	var bone := Color(1, 1, 1)
	var hood := Color(0.42, 0.36, 0.33)
	var leg_len: float = p["leg"]
	var arm_len: float = p["arm"]
	for leg in [leg_l, leg_r]:
		_limb(leg, 0.045, 0.03, leg_len, bone, &"bone", 5)
		_gm(leg, 0.06, 0.04, 0.04, 5, bone, Vector3(0, -leg_len * 0.5, 0), &"bone")
		_foot(leg, leg_len, bone, &"bone")
	_f(hips, Vector2(0.18, 0.12), Vector2(0.32, 0.18), 0.14, bone, Vector3.ZERO, &"bone")
	var chest: Vector3 = p["chest"]
	_bx(torso, Vector3(0.05, chest.y, 0.05), bone, Vector3(0, chest.y * 0.5, 0.07), &"bone")
	for k in 4:
		var w := chest.x * (0.78 + k * 0.08)
		_f(torso, Vector2(w * 0.9, chest.z * 0.9), Vector2(w, chest.z), 0.045, bone, Vector3(0, chest.y * (0.3 + k * 0.16), 0), &"bone")
	_bx(torso, Vector3(chest.x + 0.08, 0.04, 0.08), bone, Vector3(0, chest.y * 0.92, 0), &"bone")
	# Плащ за спиной и капюшон-пирамида.
	_f(torso, Vector2(chest.x + 0.3, 0.04), Vector2(chest.x + 0.04, 0.04), chest.y * 1.5, hood, Vector3(0, chest.y * 0.3, 0.15), &"rags")
	_ball(head, 0.135, bone, Vector3(0, 0.22, 0), &"bone", Vector3(0.95, 1.05, 1.1))
	_put(head, LowPoly.wedge(Vector3(0.16, 0.08, 0.1), bone, Vector3(0, 0.07, -0.06), &"bone"), Vector3(PI, 0, 0))
	_bx(head, Vector3(0.07, 0.06, 0.02), Color(0.02, 0.01, 0.01), Vector3(-0.06, 0.22, -0.13))
	_bx(head, Vector3(0.07, 0.06, 0.02), Color(0.02, 0.01, 0.01), Vector3(0.06, 0.22, -0.13))
	_eyes(Color(1.0, 0.2, 0.1), 0.22, -0.142, 0.06, 4.0)
	_put(head, LowPoly.cyl(0.0, 0.23, 0.58, 6, hood, Vector3(0, 0.36, 0.06), 0.9, 0.0, 0.0, &"rags"), Vector3(0.2, 0, 0))
	for arm in [arm_l, arm_r]:
		_limb(arm, 0.04, 0.028, arm_len, bone, &"bone", 5)
		_hand(arm, arm_len, bone, &"bone")
	_f(torso, Vector2(0.12, 0.12), Vector2(0.15, 0.15), 0.52, Color(0.8, 0.65, 0.5), Vector3(0.14, chest.y * 0.6, 0.22), &"leather")
	sockets[&"l_hand"].add_child(crossbow())


func crossbow() -> Node3D:
	var bow := LowPoly.pivot("Crossbow")
	_f(bow, Vector2(0.07, 0.07), Vector2(0.05, 0.05), 0.62, Color(1, 1, 1), Vector3(0, 0, -0.2), &"wood", Vector2.ZERO, Vector3(PI / 2, 0, 0))
	for side in [-1.0, 1.0]:
		_put(bow, LowPoly.frustum(Vector2(0.05, 0.05), Vector2(0.03, 0.03), 0.34, Color(1, 1, 1), Vector3(side * 0.16, 0.0, -0.46), &"iron", Vector2.ZERO, 0.4), Vector3(0, 0, side * deg_to_rad(-75)))
	_bx(bow, Vector3(0.6, 0.01, 0.01), Color(0.8, 0.75, 0.6), Vector3(0, 0.02, -0.38))
	bow.position = Vector3(0, -0.02, -0.04)
	bow.rotation.x = deg_to_rad(-80)
	return bow


# --- Громила: сутулый палач-мясник в кожаном капюшоне, с секирой ---------

func _dress_brute(p: Dictionary) -> void:
	var pale := Color(0.84, 0.8, 0.72)
	var flesh := Color(0.86, 0.74, 0.7)
	var leather := Color(0.42, 0.32, 0.27)
	var leg_len: float = p["leg"]
	var arm_len: float = p["arm"]
	for leg in [leg_l, leg_r]:
		_limb(leg, 0.17, 0.11, leg_len, pale, &"skin")
		_ball(leg, 0.15, pale, Vector3(0, -0.2, 0), &"skin", Vector3(1, 1.4, 1))
		_f(leg, Vector2(0.26, 0.38), Vector2(0.22, 0.24), 0.18, leather, Vector3(0, -leg_len + 0.08, -0.04), &"leather", Vector2(0, 0.05))
	_oval(hips, 0.34, 0.3, 0.32, 0.75, leather, Vector3(0, -0.05, 0), &"leather")
	torso.rotation.x = 0.0
	var chest: Vector3 = p["chest"]
	var hunch := LowPoly.pivot("Hunch", Vector3(0, 0.0, 0))
	hunch.rotation.x = -0.28
	torso.add_child(hunch)
	_oval(hunch, 0.46, 0.32, chest.y, 0.66, pale, Vector3(0, chest.y * 0.55, 0), &"skin")
	_ball(hunch, 0.36, pale, Vector3(0, 0.22, -0.16), &"skin", Vector3(1.05, 0.9, 0.9))
	# Фартук в крови и шипы, вросшие в спину.
	_f(hunch, Vector2(0.62, 0.03), Vector2(0.44, 0.03), 0.72, Color(0.62, 0.48, 0.4), Vector3(0, 0.1, -0.44), &"leather")
	_bx(hunch, Vector3(0.28, 0.24, 0.035), Color(0.45, 0.04, 0.04), Vector3(0.1, 0.0, -0.46))
	for k in 4:
		var a := -0.6 + k * 0.4
		_pyr(hunch, Vector2(0.1, 0.1), 0.34, Color(1, 1, 1), Vector3(sin(a) * 0.3, chest.y + 0.05, 0.16), &"bone", Vector3(0.5, 0, a))
	for side in [-1.0, 1.0]:
		_ball(hunch, 0.22, flesh, Vector3(side * 0.42, chest.y * 0.92, 0.02), &"flesh", Vector3(1.1, 0.85, 1.0))
	# Голова вперёд, под капюшоном палача.
	head.position.z = -0.12
	_ball(head, 0.17, pale, Vector3(0, 0.1, -0.03), &"skin", Vector3(1.05, 0.9, 1.0))
	_put(head, LowPoly.cyl(0.0, 0.24, 0.52, 6, leather, Vector3(0, 0.34, 0.0), 0.9, 0.0, 0.0, &"leather"), Vector3(0.12, 0, 0))
	_eyes(Color(1.0, 0.15, 0.05), 0.24, -0.2, 0.07, 4.0)
	for arm in [arm_l, arm_r]:
		_ball(arm, 0.18, flesh, Vector3(0, -0.06, 0), &"flesh")
		_limb(arm, 0.15, 0.1, arm_len, flesh, &"flesh")
		_ball(arm, 0.14, flesh, Vector3(0, -0.24, 0), &"flesh", Vector3(1, 1.5, 1))
		_oval(arm, 0.12, 0.13, 0.26, 1.0, leather, Vector3(0, -arm_len * 0.72, 0), &"leather", 6)
		_hand(arm, arm_len, pale, &"skin")
	sockets[&"r_hand"].add_child(cleaver())


## Секира палача: длинное топорище и широкое лезвие клином.
func cleaver() -> Node3D:
	var axe := LowPoly.pivot("Cleaver")
	axe.add_child(LowPoly.cyl(0.03, 0.035, 1.2, 6, Color(1, 1, 1), Vector3(0, 0.45, 0), 0.9, 0.0, 0.0, &"wood"))
	_put(axe, LowPoly.frustum(Vector2(0.06, 0.2), Vector2(0.025, 0.7), 0.5, Color(1, 1, 1), Vector3(0.28, 0.85, 0), &"rust", Vector2.ZERO, 0.5), Vector3(0, 0, deg_to_rad(-90)))
	_bx(axe, Vector3(0.2, 0.3, 0.07), Color(0.4, 0.03, 0.03), Vector3(0.4, 0.95, 0))
	axe.rotation.x = deg_to_rad(-80)
	return axe


# --- Заклинатель: культист в остроконечном капюшоне и маске-клюве -----------

func _dress_caster(p: Dictionary) -> void:
	var robe := Color(0.82, 0.3, 0.28)
	var leg_len: float = p["leg"]
	var arm_len: float = p["arm"]
	for leg in [leg_l, leg_r]:
		_limb(leg, 0.08, 0.06, leg_len, robe, &"cloth")
	hips.add_child(LowPoly.cyl(0.2, 0.44, 0.96, 8, robe, Vector3(0, -0.42, 0), 0.9, 0.0, 0.0, &"rags"))
	var chest: Vector3 = p["chest"]
	_oval(torso, 0.24, 0.19, chest.y * 0.9, 0.7, robe, Vector3(0, chest.y * 0.45, 0), &"cloth")
	torso.add_child(LowPoly.cyl(0.16, 0.36, 0.26, 8, robe.darkened(0.25), Vector3(0, chest.y * 0.84, 0), 0.9, 0.0, 0.0, &"rags"))
	_bx(torso, Vector3(0.08, chest.y * 0.9, 0.03), Color(0.8, 0.65, 0.35), Vector3(0, chest.y * 0.42, -chest.z * 0.52), &"gold", Vector3.ZERO, 0.4)
	# Капюшон-пирамида, костяная маска с клювом.
	_put(head, LowPoly.cyl(0.0, 0.24, 0.64, 6, robe.darkened(0.35), Vector3(0, 0.34, 0.06), 0.9, 0.0, 0.0, &"cloth"), Vector3(0.22, 0, 0))
	_f(head, Vector2(0.18, 0.2), Vector2(0.22, 0.22), 0.24, Color(1, 1, 1), Vector3(0, 0.19, -0.06), &"bone")
	_pyr(head, Vector2(0.12, 0.1), 0.36, Color(1, 1, 1), Vector3(0, 0.12, -0.32), &"bone", Vector3(deg_to_rad(-100), 0, 0))
	_eyes(Color(1.0, 0.25, 0.1), 0.23, -0.172, 0.055, 4.0)
	for arm in [arm_l, arm_r]:
		_limb(arm, 0.08, 0.13, arm_len, robe, &"cloth")
		_hand(arm, arm_len, Color(0.75, 0.72, 0.62), &"bone")
	sockets[&"r_hand"].add_child(caster_staff())


## Посох заклинателя: шип-клетка со свечой и подвешенными костями.
func caster_staff() -> Node3D:
	var staff := LowPoly.pivot("Staff")
	_f(staff, Vector2(0.06, 0.06), Vector2(0.04, 0.04), 1.6, Color(1, 1, 1), Vector3(0, 0.25, 0), &"wood")
	for k in 3:
		var a := TAU * k / 3.0
		_pyr(staff, Vector2(0.04, 0.04), 0.3, Color(1, 1, 1), Vector3(cos(a) * 0.07, 1.18, sin(a) * 0.07), &"iron", Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4), 0.4)
	_f(staff, Vector2(0.06, 0.06), Vector2(0.05, 0.05), 0.14, Color(0.9, 0.86, 0.74), Vector3(0, 1.12, 0))
	_pyr(staff, Vector2(0.06, 0.06), 0.14, Color(1.0, 0.45, 0.15), Vector3(0, 1.27, 0), &"", Vector3.ZERO, 0.0, 4.0)
	_bx(staff, Vector3(0.03, 0.18, 0.03), Color(1, 1, 1), Vector3(0.09, 0.95, 0), &"bone")
	return staff


# --- Босс — Тиран в отданных вещах: пустой рыцарь с бледными швами и короной осколков ----

func _dress_boss(p: Dictionary) -> void:
	var body := Color(0.24, 0.22, 0.26)
	var seam := Color(0.62, 0.72, 0.95)
	var leg_len: float = p["leg"]
	var arm_len: float = p["arm"]
	for leg in [leg_l, leg_r]:
		_limb(leg, 0.11, 0.065, leg_len, body, &"iron")
		_bx(leg, Vector3(0.025, leg_len * 0.7, 0.025), seam, Vector3(0, -leg_len * 0.5, -0.11), &"", Vector3.ZERO, 0.0, 2.5)
		_foot(leg, leg_len, body, &"iron")
	_oval(hips, 0.25, 0.2, 0.26, 0.7, body, Vector3(0, -0.02, 0), &"iron", 8, Vector3.ZERO, 0.4)
	var chest: Vector3 = p["chest"]
	_oval(torso, 0.35, 0.2, chest.y * 0.9, 0.58, body, Vector3(0, chest.y * 0.45, 0), &"iron", 8, Vector3.ZERO, 0.4)
	# Бледные швы-трещины на груди.
	for k in 3:
		_bx(torso, Vector3(0.03, 0.34, 0.02), seam, Vector3(-0.12 + k * 0.12, chest.y * 0.5, -chest.z * 0.52), &"", Vector3(0, 0, -0.3 + k * 0.3), 0.0, 2.5)
	_f(torso, Vector2(1.0, 0.04), Vector2(0.62, 0.04), 1.7, Color(0.34, 0.24, 0.26), Vector3(0, -0.2, 0.26), &"rags", Vector2.ZERO, Vector3(0.08, 0, 0))
	# Вытянутый череп.
	_ball(head, 0.16, Color(0.82, 0.8, 0.74), Vector3(0, 0.22, 0), &"bone", Vector3(0.9, 1.25, 1.05))
	_put(head, LowPoly.wedge(Vector3(0.22, 0.1, 0.12), Color(0.82, 0.8, 0.74), Vector3(0, 0.03, -0.08), &"bone"), Vector3(PI, 0, 0))
	_bx(head, Vector3(0.08, 0.07, 0.02), Color(0.01, 0.0, 0.0), Vector3(-0.07, 0.23, -0.162))
	_bx(head, Vector3(0.08, 0.07, 0.02), Color(0.01, 0.0, 0.0), Vector3(0.07, 0.23, -0.162))
	_eyes(seam, 0.23, -0.172, 0.07, 5.0)
	for arm in [arm_l, arm_r]:
		_ball(arm, 0.12, body, Vector3(0, -0.04, 0), &"iron")
		_limb(arm, 0.09, 0.06, arm_len, body, &"iron")
		_bx(arm, Vector3(0.025, arm_len * 0.7, 0.025), seam, Vector3(0, -arm_len * 0.5, -0.1), &"", Vector3.ZERO, 0.0, 2.5)
		for k in 3:
			_pyr(arm, Vector2(0.035, 0.035), 0.14, Color(0.82, 0.8, 0.74), Vector3(-0.04 + k * 0.04, -arm_len - 0.1, -0.03), &"bone", Vector3(PI, 0, 0))
	# Корона из семи осколков: цвет каждого — сущность надетой вещи (обновляется в refresh_items).
	_crown = LowPoly.pivot("ShardCrown", Vector3(0, 0.62, 0))
	head.add_child(_crown)


# --- Шут: карлик в маске с ухмылкой, колпаке с бубенцами и с двумя ножами ----

func _dress_jester(p: Dictionary) -> void:
	# Ткань тёмная, поэтому оттенки ярче единицы.
	var red := Color(2.4, 0.62, 0.45)
	var black := Color(0.95, 0.85, 1.1)
	var gold := Color(0.95, 0.78, 0.35)
	var pale := Color(0.95, 0.92, 0.86)
	var leg_len: float = p["leg"]
	var arm_len: float = p["arm"]
	var legs := [leg_l, leg_r]
	for i in 2:
		var leg: Node3D = legs[i]
		var c: Color = red if i == 0 else black
		_limb(leg, 0.085, 0.06, leg_len, c, &"cloth")
		_f(leg, Vector2(0.13, 0.26), Vector2(0.1, 0.12), 0.09, black, Vector3(0, -leg_len + 0.02, -0.04), &"leather", Vector2(0, 0.05))
		_pyr(leg, Vector2(0.08, 0.08), 0.22, c, Vector3(0, -leg_len + 0.06, -0.22), &"cloth", Vector3(deg_to_rad(-60), 0, 0))
		_gm(leg, 0.03, 0.03, 0.03, 5, gold, Vector3(0, -leg_len + 0.15, -0.32), &"gold", Vector3.ZERO, 0.5)
	_oval(hips, 0.2, 0.17, 0.2, 0.8, black, Vector3(0, -0.02, 0), &"cloth")
	var chest: Vector3 = p["chest"]
	# Пухлый камзол: половина красная, половина чёрная, ромбы на груди.
	_oval(torso, 0.27, 0.27, chest.y, 0.78, red, Vector3(0, chest.y * 0.5, 0), &"cloth")
	var half := _oval(torso, 0.275, 0.275, chest.y * 1.01, 0.8, black, Vector3(0.13, chest.y * 0.5, 0), &"cloth")
	half.scale.x = 0.52
	_ball(torso, 0.2, red, Vector3(0, 0.08, -0.06), &"cloth", Vector3(1.2, 0.9, 1.0))
	for k in 3:
		_gm(torso, 0.035, 0.05, 0.05, 4, gold if k % 2 == 0 else black, Vector3(-0.1, chest.y * (0.3 + k * 0.22), -0.2), &"gold", Vector3(PI / 2, 0, 0), 0.4)
	_oval(torso, 0.24, 0.24, 0.05, 0.75, Color(0.45, 0.32, 0.24), Vector3(0, 0.04, 0), &"leather")
	# Брыжи — кольцо пирамидок вокруг шеи.
	for k in 8:
		var a := TAU * k / 8.0
		_pyr(torso, Vector2(0.07, 0.07), 0.12, pale if k % 2 == 0 else red, Vector3(cos(a) * 0.14, chest.y + 0.02, sin(a) * 0.14), &"cloth", Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2))
	# Большая голова: белая маска, ромбы глаз, кривая ухмылка, длинный нос.
	_ball(head, 0.2, pale, Vector3(0, 0.21, 0), &"bone", Vector3(1.0, 1.05, 1.0))
	for side in [-1.0, 1.0]:
		_gm(head, 0.035, 0.04, 0.04, 4, Color(0.03, 0.02, 0.03), Vector3(side * 0.065, 0.24, -0.155), &"", Vector3(PI / 2, 0, 0))
		_bx(head, Vector3(0.02, 0.02, 0.02), Color(1.0, 0.3, 0.15), Vector3(side * 0.065, 0.24, -0.17), &"", Vector3.ZERO, 0.0, 3.0)
	_bx(head, Vector3(0.16, 0.035, 0.02), Color(0.55, 0.05, 0.05), Vector3(0, 0.12, -0.155), &"", Vector3(0, 0, 0.12))
	for k in 4:
		_bx(head, Vector3(0.02, 0.025, 0.02), pale, Vector3(-0.045 + k * 0.03, 0.125 + (k - 1.5) * 0.004, -0.165))
	_pyr(head, Vector2(0.05, 0.05), 0.16, pale, Vector3(0, 0.19, -0.2), &"bone", Vector3(deg_to_rad(-80), 0, 0))
	# Колпак: обод и три рога, свисающих с бубенцами.
	head.add_child(LowPoly.cyl(0.17, 0.18, 0.08, 8, black, Vector3(0, 0.34, 0), 0.9, 0.0, 0.0, &"cloth"))
	var horn_colors := [red, black, red]
	for k in 3:
		var a := -0.9 + k * 0.9
		var horn := LowPoly.pivot("Horn", Vector3(sin(a) * 0.1, 0.38, cos(a) * 0.02))
		horn.rotation = Vector3(0, 0, -a * 0.9)
		head.add_child(horn)
		_put(horn, LowPoly.cyl(0.03, 0.08, 0.26, 6, horn_colors[k], Vector3(0, 0.13, 0), 0.9, 0.0, 0.0, &"cloth"), Vector3.ZERO)
		var tip := LowPoly.pivot("Tip", Vector3(0, 0.26, 0))
		tip.rotation = Vector3(0, 0, -signf(a + 0.001) * 1.6 if absf(a) > 0.1 else 0.0)
		horn.add_child(tip)
		_put(tip, LowPoly.cyl(0.01, 0.03, 0.2, 5, horn_colors[k], Vector3(0, 0.1, 0), 0.9, 0.0, 0.0, &"cloth"), Vector3.ZERO)
		_ball(tip, 0.04, gold, Vector3(0, 0.21, 0), &"gold", Vector3.ONE, 6, 3)
	var arms := [arm_l, arm_r]
	for i in 2:
		var arm: Node3D = arms[i]
		var c: Color = black if i == 0 else red
		_ball(arm, 0.08, c, Vector3(0, -0.03, 0), &"cloth")
		_limb(arm, 0.07, 0.05, arm_len, c, &"cloth")
		_hand(arm, arm_len, pale, &"leather")
		(sockets[&"l_hand"] if i == 0 else sockets[&"r_hand"]).add_child(knife())


## Нож шута, по одному в каждой руке.
func knife() -> Node3D:
	var k := LowPoly.pivot("Knife")
	k.add_child(LowPoly.cyl(0.02, 0.022, 0.12, 5, Color(1, 1, 1), Vector3(0, -0.02, 0), 0.9, 0.0, 0.0, &"leather"))
	_bx(k, Vector3(0.09, 0.02, 0.03), Color(0.6, 0.6, 0.65), Vector3(0, 0.05, 0), &"iron", Vector3.ZERO, 0.5)
	_f(k, Vector2(0.055, 0.015), Vector2(0.005, 0.01), 0.3, Color(1.2, 1.2, 1.25), Vector3(0.01, 0.21, 0), &"iron", Vector2(0.02, 0), Vector3.ZERO, 0.7)
	_bx(k, Vector3(0.03, 0.08, 0.017), Color(0.4, 0.03, 0.03), Vector3(0.012, 0.25, 0))
	k.rotation.x = deg_to_rad(-95)
	return k


## Слизень: полупрозрачный ядовитый куб; внутри кувыркаются череп и кости.
func _build_slime() -> void:
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
	_slime_cube = LowPoly.pivot("Cube", Vector3(0, SLIME_EDGE * 0.5, 0))
	add_child(_slime_cube)
	var bone := Color(0.9, 0.86, 0.75)
	# Сколько костей внутри — из данных: у большого слизня кости и ядро, у слизнёныша один череп.
	var bones := 3
	if actor != null and actor.has_meta(&"enemy_def"):
		bones = (actor.get_meta(&"enemy_def") as EnemyDef).slime_bones
	var skull := LowPoly.pivot("Skull", Vector3(0.02, 0.0, -0.02) if bones > 0 else Vector3.ZERO)
	skull.rotation = Vector3(0.3, 0.6, 0.2)
	if bones == 0:
		skull.scale = Vector3.ONE * 1.35
	_slime_cube.add_child(skull)
	# череп в glb шириной ~1.4 м, лицом в +Z: до ширины гранёного (0.26) и лицом вперёд
	if not _generated(SLIME_SKULL_GLB, skull, Vector3(0, -0.12, 0), PI, 0.19):
		_ball(skull, 0.13, bone, Vector3.ZERO, &"bone", Vector3(0.95, 1.0, 1.1))
		_put(skull, LowPoly.wedge(Vector3(0.14, 0.07, 0.08), bone, Vector3(0, -0.12, -0.05), &"bone"), Vector3(PI, 0, 0))
		for side in [-1.0, 1.0]:
			skull.add_child(LowPoly.box(Vector3(0.05, 0.045, 0.02), Color(0.5, 1.0, 0.3), Vector3(side * 0.05, 0.01, -0.13), 0.5, 0.0, 3.0))
	for k in bones:
		var b := LowPoly.box(Vector3(0.05, 0.05, 0.36), bone, Vector3((k - 1) * 0.2, -0.22 + k * 0.08, 0.15 - k * 0.1), 0.9, 0.0, 0.0, &"bone")
		b.rotation = Vector3(k * 0.7, k * 1.3, 0.4)
		_slime_cube.add_child(b)
	if bones > 0:
		_slime_cube.add_child(LowPoly.gem(0.09, 0.1, 0.1, 5, Color(0.5, 1.0, 0.25), Vector3(-0.15, 0.15, 0.12), &"", 0.0, 2.5))
	var jelly := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * SLIME_EDGE
	jelly.mesh = LowPoly.flat(box)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.85, 0.22, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.metallic_specular = 0.8
	m.emission_enabled = true
	m.emission = Color(0.1, 0.35, 0.05)
	m.emission_energy_multiplier = 0.8
	jelly.material_override = m
	jelly.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slime_cube.add_child(jelly)
	sockets[&"chest"] = _socket(_slime_cube, Vector3(0, SLIME_EDGE * 0.5, 0))
	for key in [&"head", &"neck", &"l_hand", &"r_hand", &"l_foot", &"r_foot"]:
		sockets[key] = sockets[&"chest"]
	_collect_meshes()


## Перекат куба через ребро: поворот по пройденному пути, центр приподнимается к 45°.
func _animate_slime(delta: float) -> void:
	rotation.y = 0.0
	var pos := actor.global_position
	if _last_pos == Vector3.INF:
		_last_pos = pos
	var d := Combat.flat(pos - _last_pos)
	_last_pos = pos
	var dist := d.length() / maxf(scale.x, 0.01)
	if dist > 0.0001 and dist < 2.0:
		var axis := Vector3.UP.cross(d.normalized())
		var ang := dist / SLIME_EDGE * (PI / 2.0)
		_roll_basis = (Basis(axis, ang) * _roll_basis).orthonormalized()
		var before := int(_roll_phase / (PI / 2.0))
		_roll_phase += ang
		if int(_roll_phase / (PI / 2.0)) != before:
			Audio.play(&"slime_roll", -14.0, 0.15)
	var phase := fmod(_roll_phase, PI / 2.0)
	var squash := 1.0 - 0.32 * _windup
	var widen := 1.0 + 0.2 * _windup
	_hop = maxf(_hop - delta, 0.0)
	_slime_cube.basis = Basis.from_scale(Vector3(widen, squash, widen)) * _roll_basis
	_slime_cube.position.y = SLIME_EDGE * 0.5 * sqrt(2.0) * sin(PI / 4.0 + phase) * squash + sin(_hop / 0.25 * PI) * 0.35


## Рой: мертвенно-зелёный бес на четырёх лапах, с рогами, пастью и шипами по хребту.
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
	sockets[&"chest"] = _socket(body, Vector3(0, 0.34, 0.05))
	for key in [&"head", &"neck", &"l_hand", &"r_hand", &"l_foot", &"r_foot"]:
		sockets[key] = sockets[&"chest"]
	# в glb морда в +X, лапы на нуле: поворот мордой в -Z, торс на высоте 0.9
	if _generated(SWARM_GLB, torso, Vector3(0, -0.9, 0), PI / 2, 1.0):
		_collect_meshes()
		return
	var hide := Color(0.62, 0.72, 0.5)
	var dark := Color(0.4, 0.46, 0.32)
	_f(body, Vector2(0.36, 0.62), Vector2(0.26, 0.4), 0.3, hide, Vector3(0, 0.08, 0.06), &"skin", Vector2(0, -0.06))
	_f(body, Vector2(0.24, 0.3), Vector2(0.18, 0.2), 0.2, hide, Vector3(0, 0.12, -0.38), &"skin", Vector2(0, -0.04))
	_put(body, LowPoly.wedge(Vector3(0.22, 0.12, 0.2), dark, Vector3(0, 0.0, -0.46), &"skin"), Vector3(PI, 0, 0))
	for k in 4:
		_pyr(body, Vector2(0.035, 0.035), 0.07, Color(0.95, 0.9, 0.8), Vector3(-0.07 + k * 0.045, 0.06, -0.55), &"", Vector3(PI, 0, 0))
	for side in [-1.0, 1.0]:
		_pyr(body, Vector2(0.06, 0.06), 0.24, Color(0.9, 0.85, 0.75), Vector3(side * 0.08, 0.28, -0.36), &"bone", Vector3(-0.5, 0, side * -0.4))
	var eye := Color(1.0, 0.85, 0.15)
	_bx(body, Vector3(0.06, 0.035, 0.03), eye, Vector3(-0.06, 0.16, -0.48), &"", Vector3.ZERO, 0.0, 4.0)
	_bx(body, Vector3(0.06, 0.035, 0.03), eye, Vector3(0.06, 0.16, -0.48), &"", Vector3.ZERO, 0.0, 4.0)
	for k in 4:
		_pyr(body, Vector2(0.07, 0.07), 0.2, Color(1, 1, 1), Vector3(0, 0.3, 0.25 - k * 0.15), &"bone", Vector3(-0.35, 0, 0))
	for side in [-1.0, 1.0]:
		for k in 2:
			var leg := _f(body, Vector2(0.05, 0.05), Vector2(0.09, 0.09), 0.4, dark, Vector3(side * 0.24, -0.08, -0.16 + k * 0.38), &"skin")
			leg.rotation = Vector3(0, 0, side * 0.6)
	for k in 3:
		_f(body, Vector2(0.06 - k * 0.015, 0.16), Vector2(0.08 - k * 0.015, 0.16), 0.06, dark, Vector3(0, 0.1 - k * 0.02, 0.42 + k * 0.15), &"skin", Vector2.ZERO, Vector3(PI / 2 - 0.3, 0, 0))
	_collect_meshes()


## Сгенерированная сетка без скелета вместо гранёных примитивов: текстура — через тот же
## ретро-материал, что у остальных моделей. false — сетки нет (ещё не собрана).
func _generated(path: String, parent: Node3D, pos: Vector3, yaw: float, size: float) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	scene.position = pos
	scene.rotation.y = yaw
	scene.scale = Vector3.ONE * size
	parent.add_child(scene)
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var src := (mi as MeshInstance3D).get_active_material(0) as BaseMaterial3D
		(mi as MeshInstance3D).material_override = LowPoly.mat_textured(src.albedo_texture if src else null)
	return true


func _socket(parent: Node3D, pos: Vector3) -> Node3D:
	var s := LowPoly.pivot("Socket", pos)
	parent.add_child(s)
	return s


func _collect_meshes() -> void:
	_meshes.clear()
	_collect(self)
	_apply_rim()


## Контурный свет по силуэту: герой — тёплый, враги — холодный, элиты — золотой, босс — бледный.
func _apply_rim() -> void:
	var rim := Color(0.55, 0.7, 1.0)
	var strength := 0.55
	if kind == Kind.TYRANT:
		rim = Color(0.78, 0.62, 1.0)
		strength = 0.6
	elif is_npc():
		rim = Color(1.0, 0.86, 0.68)
		strength = 0.45
	elif actor != null and actor.faction == Actor.Faction.HERO:
		rim = Color(1.0, 0.8, 0.5)
		strength = 0.6
	elif kind == Kind.BOSS:
		rim = Color(0.7, 0.8, 1.0)
		strength = 0.7
	elif actor != null and actor.get_meta(&"elite", false):
		rim = Color(1.0, 0.75, 0.3)
		strength = 0.7
	for m in _meshes:
		if is_instance_valid(m) and m.material_override is ShaderMaterial:
			m.material_override = LowPoly.rim_variant(m.material_override as ShaderMaterial, rim, strength)


func _collect(n: Node) -> void:
	for ch in n.get_children():
		if ch is FlipbookFx:
			continue
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
	_rebuild_crown()
	_collect_meshes.call_deferred()


## Корона босса: по осколку на каждую надетую вещь, цвета их сущностей.
func _rebuild_crown() -> void:
	if _crown == null:
		return
	for ch in _crown.get_children():
		ch.queue_free()
	_crown_shards.clear()
	var n := actor.items.size()
	for i in n:
		var color := actor.items[i].def().essence.color
		var a := TAU * i / maxf(n, 1)
		var shard := LowPoly.gem(0.06, 0.2, 0.1, 4, color, Vector3(cos(a) * 0.36, 0, sin(a) * 0.36), &"", 0.0, 2.5)
		shard.rotation.z = 0.25
		_crown.add_child(shard)
		_crown_shards[actor.items[i].def_id] = shard


func _connect_actions() -> void:
	var comps: Array = actor.components.values()
	if actor.innate != null:
		comps.append(actor.innate)
	for c in comps:
		var comp := c as ActionComponent
		if not comp.used.is_connected(_on_action_used):
			comp.used.connect(_on_action_used.bind(comp))
		if comp is EnemyAttack and not (comp as EnemyAttack).stabbed.is_connected(_on_stab):
			(comp as EnemyAttack).stabbed.connect(_on_stab)


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
			EnemyDef.Behavior.SWARM, EnemyDef.Behavior.JESTER:
				pass
			EnemyDef.Behavior.SLIME:
				_hop = 0.25
			_:
				play_swing(&"chop", 0.22)


## Элита с мечом/щитом героя прячет собственное оружие.
func _hide_kind_weapons() -> void:
	var r_hand: Node3D = sockets[&"r_hand"]
	for ch in r_hand.get_children():
		if ch.name in ["EnemySword", "Katana", "Cleaver", "Staff", "Knife"]:
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


## Вступление босса: все вещи и осколки короны скрыты, потом проявляются по одной.
func hide_all_items() -> void:
	for nodes in _item_nodes.values():
		for n in nodes:
			(n as Node3D).visible = false
	for shard in _crown_shards.values():
		(shard as Node3D).visible = false


func reveal_item(id: StringName) -> void:
	var pops: Array[Node3D] = []
	for n in _item_nodes.get(id, []):
		pops.append(n)
	if _crown_shards.has(id):
		pops.append(_crown_shards[id])
	for n in pops:
		n.visible = true
		var full := n.scale
		n.scale = full * 0.05
		var tw := n.create_tween()
		tw.tween_property(n, "scale", full * 1.35, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", full, 0.12)


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


func _on_stab() -> void:
	play_swing(&"stab_l" if _stab_left else &"stab_r", 0.14)
	_stab_left = not _stab_left


func play_swing(kind_name: StringName, duration: float = 0.2) -> void:
	_swing_kind = kind_name
	_swing_dur = duration
	_swing_t = 0.0


func set_windup(progress: float) -> void:
	_windup = progress


func _on_hit(amount: float, crit: bool, ctx: ActionContext) -> void:
	_flash = 0.09
	if amount <= 0.0:
		return
	var src := ctx.origin if ctx != null else actor.global_position
	var h := (0.45 if kind == Kind.SLIME or kind == Kind.SWARM else 0.95) * scale.y
	if crit:
		FlipbookFx.impact(actor, src, h, Color(0.8, 0.45, 1.0), 1.7)
	elif actor.faction == Actor.Faction.HERO:
		FlipbookFx.impact(actor, src, h, Color(1.0, 0.4, 0.3), 1.0)
	else:
		FlipbookFx.impact(actor, src, h, Color(1.0, 0.88, 0.7), 1.1)


func _on_died(_a: Actor) -> void:
	_dying = true
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = null
	if kind == Kind.SLIME and _slime_cube != null:
		# Растекается лужей: сначала выпрямляем куб, потом сплющиваем.
		_slime_cube.basis = Basis()
		var t := create_tween().set_parallel(true)
		t.tween_property(_slime_cube, "scale", Vector3(1.7, 0.08, 1.7), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(_slime_cube, "position:y", 0.04, 0.35)
		return
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", deg_to_rad(80), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", -0.6, 0.8).set_delay(0.3)


func _process(delta: float) -> void:
	if actor == null or _dying:
		return
	if actor.innate is EnemyAttack:
		_windup = (actor.innate as EnemyAttack).windup_progress()
	if _crown != null:
		_crown.rotation.y += delta * 0.9
	if kind == Kind.SLIME:
		_animate_slime(delta)
	else:
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
	if (actor.has_item(&"sword") or kind != Kind.HERO) and not is_npc():
		arm_r_basis = Basis(Vector3.RIGHT, 0.35 + swing * 0.3)
	match kind:
		Kind.JESTER:
			arm_l_basis = Basis(Vector3.UP, 0.35) * Basis(Vector3.RIGHT, 0.75 - swing * 0.3)
			arm_r_basis = Basis(Vector3.UP, -0.35) * Basis(Vector3.RIGHT, 0.75 + swing * 0.3)
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
			&"stab_r":
				arm_r_basis = Basis(Vector3.RIGHT, lerpf(0.7, 1.7, sin(k * PI)))
				torso.rotation.y = -0.4 * sin(k * PI)
			&"stab_l":
				arm_l_basis = Basis(Vector3.RIGHT, lerpf(0.7, 1.7, sin(k * PI)))
				torso.rotation.y = 0.4 * sin(k * PI)
	head.rotation.x = 0.0
	var p := pose if pose != &"" else rest_pose
	if p != &"" and not (_swing_t < _swing_dur):
		var arms := _apply_pose(p, moving, arm_l_basis, arm_r_basis)
		arm_l_basis = arms[0]
		arm_r_basis = arms[1]
	arm_l.basis = arm_l_basis
	arm_r.basis = arm_r_basis
	# Шут крутит сальто на каждом рывке (выпад, отскок, уворот).
	if kind == Kind.JESTER:
		var dashing := actor.is_dashing()
		if dashing and not _jester_dashing:
			_flip_t = 0.0
		_jester_dashing = dashing
		if _flip_t >= 0.0:
			_flip_t += delta
			var k2 := clampf(_flip_t / 0.3, 0.0, 1.0)
			hips.rotation.x = -TAU * (1.0 - pow(1.0 - k2, 2.0))
			hips.position.y += sin(k2 * PI) * 0.35
			if k2 >= 1.0:
				_flip_t = -1.0
				hips.rotation.x = 0.0


## Позы сюжетных сцен поверх ходьбы. Ноги без коленей: на коленях бёдра опущены, ноги лежат назад.
func _apply_pose(p: StringName, moving: float, arm_l_basis: Basis, arm_r_basis: Basis) -> Array[Basis]:
	match p:
		&"kneel", &"slump":
			hips.position.y = 0.44
			leg_l.rotation.x = -1.3
			leg_r.rotation.x = -1.2
			torso.rotation.x = -0.4 if p == &"kneel" else -0.75
			head.rotation.x = 0.25 if p == &"kneel" else 0.5
			arm_l_basis = Basis(Vector3.RIGHT, 0.25 if p == &"kneel" else 0.6)
			arm_r_basis = Basis(Vector3.RIGHT, 0.25 if p == &"kneel" else 0.6)
		&"sit":
			hips.position.y = 0.32
			leg_l.rotation.x = 1.4
			leg_r.rotation.x = 1.5
			torso.rotation.x = 0.3
			arm_l_basis = Basis(Vector3.RIGHT, -0.5)
			arm_r_basis = Basis(Vector3.RIGHT, -0.5)
		&"hold":
			arm_l_basis = Basis(Vector3.UP, -0.35) * Basis(Vector3.RIGHT, 1.05)
			arm_r_basis = Basis(Vector3.UP, 0.35) * Basis(Vector3.RIGHT, 1.05)
		&"bow":
			# Клятва: низкий поклон, вещь прижата к груди обеими руками. (Колен у модели нет — на коленях
			# стоящий читается как упавший, поэтому клянутся в поклоне.)
			hips.position.y = 0.84
			torso.rotation.x = -0.55
			head.rotation.x = 0.35
			arm_l_basis = Basis(Vector3.UP, -0.5) * Basis(Vector3.RIGHT, 1.3)
			arm_r_basis = Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, 1.3)
		&"offer":
			arm_r_basis = Basis(Vector3.UP, 0.15) * Basis(Vector3.RIGHT, 1.25)
		&"ease":
			# Солдат в разговоре: рука отведена назад, меч смотрит остриём в землю, а не в собеседника.
			if moving < 0.2:
				arm_r_basis = Basis(Vector3.RIGHT, -0.75)
		&"arms_up":
			arm_l_basis = Basis(Vector3.RIGHT, 2.3)
			arm_r_basis = Basis(Vector3.RIGHT, 2.3)
		&"hands_back":
			if moving < 0.2:
				arm_l_basis = Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.45)
				arm_r_basis = Basis(Vector3.UP, -0.4) * Basis(Vector3.RIGHT, -0.45)
		&"shield_up":
			arm_l_basis = Basis(Vector3.UP, -0.9) * Basis(Vector3.RIGHT, 1.25)
		&"lantern":
			arm_l_basis = Basis(Vector3.RIGHT, 0.45)
		&"sling":
			arm_l_basis = Basis(Vector3.UP, -0.9) * Basis(Vector3.RIGHT, 1.0)
		&"frail", &"frail_offer":
			# Старик сгорбился и опирается на посох левой рукой; frail_offer — протягивает правую.
			torso.rotation.x = -0.32
			head.rotation.x = 0.2
			arm_l_basis = Basis(Vector3.UP, -0.25) * Basis(Vector3.RIGHT, 0.55)
			if p == &"frail_offer":
				arm_r_basis = Basis(Vector3.UP, 0.2) * Basis(Vector3.RIGHT, 1.35)
		&"huddle":
			# Замёрз: стоит, сжавшись, руки крест-накрест на груди, голова втянута, мелкая дрожь.
			# Стоя, а не сидя: у модели нет коленей, и сидящий в силуэте читается как упавший.
			hips.position.y = 0.86
			torso.rotation.x = -0.3
			torso.rotation.z = sin(Time.get_ticks_msec() * 0.045) * 0.03
			head.rotation.x = -0.18
			arm_l_basis = Basis(Vector3.UP, -1.15) * Basis(Vector3.RIGHT, 1.0)
			arm_r_basis = Basis(Vector3.UP, 1.15) * Basis(Vector3.RIGHT, 1.0)
		&"wring", &"downcast":
			# Руки сцеплены у пояса: тревога, ожидание. downcast — ещё и опущенная голова: сомнение.
			arm_l_basis = Basis(Vector3.UP, -0.85) * Basis(Vector3.RIGHT, 0.55)
			arm_r_basis = Basis(Vector3.UP, 0.85) * Basis(Vector3.RIGHT, 0.55)
			# Наклон небольшой: камера смотрит сверху, и сильнее опущенная голова закрыла бы лицо макушкой.
			if p == &"downcast":
				torso.rotation.x = -0.08
				head.rotation.x = -0.16
	return [arm_l_basis, arm_r_basis]


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
