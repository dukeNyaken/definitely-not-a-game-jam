class_name NpcLooks
extends RefCounted
## Наряды людей из сюжетных сцен. Собраны из тех же гранёных примитивов ActorModel, что герой и враги.
## Лицо смотрит в -Z, как у всех моделей.

const SKIN := Color(0.9, 0.8, 0.72)
const PALE := Color(0.96, 0.88, 0.83)
const DARK := Color(0.05, 0.04, 0.04)
const LINEN := Color(0.88, 0.84, 0.74)
const GOLD := Color(0.95, 0.76, 0.32)
const STEEL := Color(1.15, 1.15, 1.2)
const BOOTS := Color(0.42, 0.3, 0.22)


static func scale_for(kind: int, variant: StringName = &"") -> float:
	match kind:
		ActorModel.Kind.REFUGEE:
			return 0.8
		ActorModel.Kind.BELOVED, ActorModel.Kind.FAITHFUL, ActorModel.Kind.WIDOW:
			return 0.94
		ActorModel.Kind.SMITH:
			return 1.04
		ActorModel.Kind.TYRANT:
			return 1.0 if variant == &"young" else 1.04
		ActorModel.Kind.FATHER:
			return 0.98
		ActorModel.Kind.MOTHER:
			return 0.9
	return 1.0


static func dress(m: ActorModel, p: Dictionary) -> void:
	match m.kind:
		ActorModel.Kind.FRIEND: _friend(m, p)
		ActorModel.Kind.BELOVED: _beloved(m, p)
		ActorModel.Kind.FAITHFUL: _faithful(m, p)
		ActorModel.Kind.REFUGEE: _refugee(m, p)
		ActorModel.Kind.CAPTAIN: _captain(m, p)
		ActorModel.Kind.WIDOW: _widow(m, p)
		ActorModel.Kind.SMITH: _smith(m, p)
		ActorModel.Kind.NOVICE: _novice(m, p)
		ActorModel.Kind.TYRANT: _tyrant(m, p)
		ActorModel.Kind.FATHER: _father(m, p)
		ActorModel.Kind.MOTHER: _mother(m, p)


# --- Общие части ------------------------------------------------------------

## Шея, череп, челюсть, нос и глаза.
static func _head(m: ActorModel, skin: Color, jaw_w: float = 0.22) -> void:
	m.head.add_child(LowPoly.cyl(0.065, 0.075, 0.14, 6, skin, Vector3(0, 0.03, 0), 0.9, 0.0, 0.0, &"skin"))
	m._ball(m.head, 0.15, skin, Vector3(0, 0.25, 0.0), &"skin", Vector3(0.92, 1.1, 1.0))
	m._f(m.head, Vector2(jaw_w * 0.7, 0.13), Vector2(jaw_w, 0.2), 0.12, skin, Vector3(0, 0.15, -0.025), &"skin")
	m._put(m.head, LowPoly.wedge(Vector3(0.04, 0.07, 0.05), skin, Vector3(0, 0.215, -0.16), &"skin"), Vector3(deg_to_rad(-90), 0, 0))
	for side in [-1.0, 1.0]:
		m._bx(m.head, Vector3(0.045, 0.028, 0.02), DARK, Vector3(side * 0.058, 0.255, -0.152))
		m._ball(m.head, 0.035, skin, Vector3(side * 0.142, 0.23, 0.01), &"skin", Vector3(0.6, 1.2, 1), 5, 3)


## Волосы шапкой; лицо остаётся открытым.
static func _hair(m: ActorModel, color: Color, y: float = 0.29, r: float = 0.158) -> void:
	m._ball(m.head, r, color, Vector3(0, y, 0.025), &"fur", Vector3(0.97, 1.0, 1.05))


static func _legs(m: ActorModel, p: Dictionary, cloth: Color, surface: StringName, top_r: float = 0.11, boots: Color = BOOTS) -> void:
	var leg_len: float = p["leg"]
	for leg in [m.leg_l, m.leg_r]:
		m._limb(leg, top_r, top_r * 0.68, leg_len, cloth, surface)
		m._f(leg, Vector2(0.16, 0.3), Vector2(0.14, 0.17), 0.26, boots, Vector3(0, -leg_len + 0.13, -0.03), &"leather", Vector2(0, 0.04))


static func _arms(m: ActorModel, p: Dictionary, sleeve: Color, surface: StringName, skin: Color, top_r: float = 0.09, bottom_r: float = 0.07) -> void:
	var arm_len: float = p["arm"]
	for arm in [m.arm_l, m.arm_r]:
		m._ball(arm, top_r * 1.05, sleeve, Vector3(0, -0.03, 0), surface)
		m._limb(arm, top_r, bottom_r, arm_len, sleeve, surface)
		m._hand(arm, arm_len, skin, &"skin")


## Длинная юбка от пояса до земли (прячет ноги).
static func _skirt(m: ActorModel, color: Color, top_r: float = 0.2, bottom_r: float = 0.4) -> void:
	m.hips.add_child(LowPoly.cyl(top_r, bottom_r, 0.98, 8, color, Vector3(0, -0.44, 0), 0.9, 0.0, 0.0, &"cloth"))
	m.hips.add_child(LowPoly.cyl(bottom_r + 0.01, bottom_r + 0.015, 0.05, 8, color.darkened(0.3), Vector3(0, -0.91, 0), 0.9, 0.0, 0.0, &"cloth"))


# --- Торстейн: раненый друг в стёганке, рука на перевязи ----------------------

static func _friend(m: ActorModel, p: Dictionary) -> void:
	var gamb := Color(0.62, 0.5, 0.32)
	var chest: Vector3 = p["chest"]
	var arm_len: float = p["arm"]
	m.rest_pose = &"sling"
	_legs(m, p, Color(0.34, 0.3, 0.27), &"cloth")
	m._oval(m.hips, 0.26, 0.29, 0.36, 0.75, gamb, Vector3(0, -0.11, 0), &"cloth")
	m._oval(m.hips, 0.27, 0.27, 0.06, 0.75, Color(0.45, 0.32, 0.22), Vector3(0, 0.05, 0), &"leather")
	m._oval(m.torso, 0.32, 0.24, chest.y * 0.9, 0.66, gamb, Vector3(0, chest.y * 0.45, 0), &"cloth")
	for k in 3:
		m._bx(m.torso, Vector3(0.025, chest.y * 0.7, 0.02), gamb.darkened(0.3), Vector3(-0.12 + k * 0.12, chest.y * 0.45, -chest.z * 0.62))
	# Бинт через грудь и косынка-перевязь.
	m._bx(m.torso, Vector3(0.08, 0.78, chest.z * 0.78), LINEN, Vector3(0, chest.y * 0.5, 0), &"cloth", Vector3(0, 0, -0.62))
	m._bx(m.torso, Vector3(0.05, 0.03, 0.04), Color(0.55, 0.06, 0.05), Vector3(0.06, chest.y * 0.62, -chest.z * 0.66))
	_head(m, SKIN)
	_hair(m, Color(0.22, 0.16, 0.12), 0.3, 0.152)
	m._f(m.head, Vector2(0.12, 0.1), Vector2(0.22, 0.18), 0.1, Color(0.3, 0.22, 0.17), Vector3(0, 0.12, -0.07), &"fur")
	# Повязка на лбу с пятном крови.
	m.head.add_child(LowPoly.torus(0.145, 0.168, 10, 3, LINEN, Vector3(0, 0.31, 0.0), 0.9, 0.0, 0.0, &"cloth"))
	m._bx(m.head, Vector3(0.05, 0.03, 0.02), Color(0.6, 0.06, 0.05), Vector3(0.05, 0.315, -0.165))
	_arms(m, p, gamb, &"cloth", SKIN, 0.095, 0.075)
	m._oval(m.arm_l, 0.09, 0.085, 0.18, 1.0, LINEN, Vector3(0, -arm_len * 0.62, 0), &"cloth", 6)


# --- Сольвейг: любимая. Багровое платье, светлая коса, серебряный обруч ----------

static func _beloved(m: ActorModel, p: Dictionary) -> void:
	var dress := Color(0.78, 0.07, 0.12)
	var chest: Vector3 = p["chest"]
	var hair := Color(0.93, 0.8, 0.52)
	_legs(m, p, dress.darkened(0.3), &"cloth", 0.08)
	_skirt(m, dress, 0.2, 0.42)
	m._oval(m.torso, 0.24, 0.17, chest.y * 0.9, 0.66, dress, Vector3(0, chest.y * 0.45, 0), &"cloth")
	m._oval(m.torso, 0.2, 0.17, 0.22, 0.7, Color(0.12, 0.07, 0.09), Vector3(0, 0.13, 0), &"leather")
	m._ball(m.torso, 0.1, PALE, Vector3(0, chest.y * 0.86, -0.05), &"skin", Vector3(1.2, 0.5, 0.6))
	_head(m, PALE, 0.2)
	_hair(m, hair, 0.29, 0.16)
	# Коса по спине, на конце — багровая лента.
	for k in 5:
		var r := 0.062 - k * 0.006
		m._ball(m.head, r, hair, Vector3(0, 0.2 - k * 0.13, 0.15 + k * 0.012), &"fur", Vector3(1, 1.25, 1), 6, 3)
	m._bx(m.head, Vector3(0.08, 0.05, 0.05), dress, Vector3(0, -0.47, 0.2))
	var circlet := LowPoly.torus(0.15, 0.166, 12, 3, Color(0.92, 0.94, 1.0), Vector3(0, 0.33, -0.005), 0.4, 0.8, 0.4)
	circlet.rotation.x = -0.15
	m.head.add_child(circlet)
	m._gm(m.head, 0.025, 0.03, 0.03, 4, Color(0.75, 0.1, 0.15), Vector3(0, 0.34, -0.165), &"", Vector3.ZERO, 0.0, 1.5)
	_arms(m, p, dress, &"cloth", PALE, 0.075, 0.1)


# --- Ильва: верная. Простое платье, фартук, платок, фонарь ----------------------

static func _faithful(m: ActorModel, p: Dictionary) -> void:
	var dress := Color(0.4, 0.48, 0.58)
	var apron := Color(0.84, 0.8, 0.7)
	var scarf := Color(0.78, 0.58, 0.38)
	var skin := Color(0.92, 0.8, 0.7)
	var chest: Vector3 = p["chest"]
	m.rest_pose = &"lantern"
	_legs(m, p, dress.darkened(0.3), &"cloth", 0.08)
	_skirt(m, dress, 0.2, 0.38)
	m._f(m.hips, Vector2(0.34, 0.03), Vector2(0.26, 0.03), 0.62, apron, Vector3(0, -0.42, -0.3), &"rags", Vector2.ZERO, Vector3(0.18, 0, 0))
	m._oval(m.torso, 0.23, 0.17, chest.y * 0.9, 0.66, dress, Vector3(0, chest.y * 0.45, 0), &"cloth")
	m._f(m.torso, Vector2(0.22, 0.02), Vector2(0.18, 0.02), 0.28, apron, Vector3(0, chest.y * 0.42, -0.16), &"rags")
	# Сумка через плечо.
	m._bx(m.torso, Vector3(0.04, 0.72, chest.z * 0.72), Color(0.42, 0.3, 0.2), Vector3(0, chest.y * 0.45, 0), &"leather", Vector3(0, 0, 0.6))
	m._bx(m.hips, Vector3(0.09, 0.2, 0.24), Color(0.48, 0.34, 0.22), Vector3(0.3, -0.06, 0.02), &"leather")
	_head(m, skin, 0.2)
	m._bx(m.head, Vector3(0.22, 0.05, 0.04), Color(0.45, 0.3, 0.2), Vector3(0, 0.34, -0.12), &"fur")
	m._ball(m.head, 0.166, scarf, Vector3(0, 0.31, 0.035), &"cloth", Vector3(1.0, 0.95, 1.05))
	m._pyr(m.head, Vector2(0.08, 0.06), 0.13, scarf, Vector3(0, 0.2, 0.19), &"cloth", Vector3(1.9, 0, 0))
	_arms(m, p, dress, &"cloth", skin, 0.075, 0.065)
	m.sockets[&"l_hand"].add_child(lantern())


## Фонарь Ильвы: тёплый свет — её мотив. Висит в левой руке.
static func lantern() -> Node3D:
	var l := LowPoly.pivot("Lantern", Vector3(0, -0.12, 0))
	l.rotation.x = -0.45
	var iron := Color(0.35, 0.33, 0.32)
	l.add_child(LowPoly.torus(0.04, 0.055, 8, 3, iron, Vector3(0, 0.06, 0), 0.6, 0.5))
	l.add_child(LowPoly.frustum(Vector2(0.15, 0.15), Vector2(0.11, 0.11), 0.03, iron, Vector3(0, 0.02, 0), &"iron", Vector2.ZERO, 0.5))
	l.add_child(LowPoly.box(Vector3(0.09, 0.14, 0.09), Color(1.0, 0.72, 0.3), Vector3(0, -0.07, 0), 0.5, 0.0, 3.0))
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4
		l.add_child(LowPoly.box(Vector3(0.02, 0.18, 0.02), iron, Vector3(cos(a) * 0.065, -0.07, sin(a) * 0.065), 0.6, 0.5))
	l.add_child(LowPoly.frustum(Vector2(0.14, 0.14), Vector2(0.14, 0.14), 0.025, iron, Vector3(0, -0.16, 0), &"iron", Vector2.ZERO, 0.5))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.36)
	light.light_energy = 1.6
	light.omni_range = 3.4
	light.position = Vector3(0, -0.07, 0)
	l.add_child(light)
	return l


# --- Эйвинд: парень-беженец, босой, с узелком на палке --------------------------

static func _refugee(m: ActorModel, p: Dictionary) -> void:
	var tunic := Color(0.56, 0.46, 0.36)
	var chest: Vector3 = p["chest"]
	var leg_len: float = p["leg"]
	var arm_len: float = p["arm"]
	for leg in [m.leg_l, m.leg_r]:
		m._limb(leg, 0.09, 0.06, leg_len, SKIN, &"skin")
		m._oval(leg, 0.105, 0.1, 0.32, 1.0, Color(0.36, 0.3, 0.26), Vector3(0, -0.15, 0), &"rags", 6)
		m._foot(leg, leg_len, SKIN.darkened(0.1), &"skin")
	m._f(m.hips, Vector2(0.46, 0.32), Vector2(0.4, 0.27), 0.42, tunic, Vector3(0, -0.13, 0), &"rags")
	m.hips.add_child(LowPoly.torus(0.2, 0.235, 10, 3, Color(0.7, 0.6, 0.42), Vector3(0, 0.05, 0), 0.9))
	m._oval(m.torso, 0.28, 0.22, chest.y * 0.92, 0.62, tunic, Vector3(0, chest.y * 0.45, 0), &"rags")
	_head(m, SKIN, 0.2)
	m._bx(m.head, Vector3(0.05, 0.03, 0.02), SKIN.darkened(0.35), Vector3(-0.07, 0.19, -0.16))
	var hair := Color(0.5, 0.33, 0.18)
	_hair(m, hair, 0.3, 0.156)
	for k in 5:
		var a := -1.0 + k * 0.5
		m._pyr(m.head, Vector2(0.06, 0.06), 0.12, hair, Vector3(sin(a) * 0.1, 0.42, cos(a) * 0.04), &"fur", Vector3(0.3, 0, a * 0.6))
	for arm in [m.arm_l, m.arm_r]:
		m._oval(arm, 0.1, 0.095, 0.22, 1.0, tunic, Vector3(0, -0.1, 0), &"rags", 6)
		m._limb(arm, 0.075, 0.055, arm_len, SKIN, &"skin")
		m._hand(arm, arm_len, SKIN, &"skin")
	m.sockets[&"r_hand"].add_child(refugee_bundle())


## Узелок на палке через плечо.
static func refugee_bundle() -> Node3D:
	var stick := LowPoly.pivot("Bundle")
	stick.add_child(LowPoly.cyl(0.02, 0.025, 1.1, 5, Color(0.55, 0.4, 0.25), Vector3(0, 0.5, 0), 0.9, 0.0, 0.0, &"wood"))
	stick.add_child(LowPoly.sphere(0.15, 7, 4, LINEN.darkened(0.15), Vector3(0, 1.05, 0), 0.9, 0.0, 0.0, &"rags"))
	stick.rotation.x = 0.64
	return stick


# --- Бьёрн: капитан гвардии. Кираса, чёрно-золотой табард, шлем с плюмажем, свой щит --

static func _captain(m: ActorModel, p: Dictionary) -> void:
	var black := Color(0.1, 0.09, 0.1)
	var chest: Vector3 = p["chest"]
	var arm_len: float = p["arm"]
	_legs(m, p, Color(0.38, 0.1, 0.1), &"cloth", 0.11, Color(0.2, 0.15, 0.12))
	m._oval(m.hips, 0.25, 0.27, 0.28, 0.72, Color(0.72, 0.72, 0.78), Vector3(0, -0.07, 0), &"iron", 8, Vector3.ZERO, 0.4)
	for z in [-0.17, 0.17]:
		m._f(m.hips, Vector2(0.34, 0.03), Vector2(0.3, 0.03), 0.52, black, Vector3(0, -0.24, z), &"cloth")
	m._bx(m.hips, Vector3(0.06, 0.5, 0.02), GOLD, Vector3(0, -0.24, -0.19), &"gold", Vector3.ZERO, 0.6, 0.3)
	m._oval(m.torso, 0.33, 0.24, chest.y * 0.88, 0.64, STEEL, Vector3(0, chest.y * 0.46, 0), &"iron", 8, Vector3.ZERO, 0.6)
	m._f(m.torso, Vector2(0.3, 0.02), Vector2(0.26, 0.02), chest.y * 0.8, black, Vector3(0, chest.y * 0.4, -chest.z * 0.62), &"cloth")
	m._bx(m.torso, Vector3(0.06, chest.y * 0.8, 0.02), GOLD, Vector3(0, chest.y * 0.4, -chest.z * 0.66), &"gold", Vector3.ZERO, 0.6, 0.3)
	# Меч в ножнах у левого бедра.
	m._bx(m.hips, Vector3(0.05, 0.72, 0.06), Color(0.3, 0.2, 0.15), Vector3(-0.29, -0.32, 0.04), &"leather", Vector3(0.22, 0, 0))
	m._bx(m.hips, Vector3(0.2, 0.04, 0.05), STEEL, Vector3(-0.29, 0.06, -0.04), &"iron", Vector3(0.22, 0, 0), 0.6)
	_head(m, SKIN)
	m._f(m.head, Vector2(0.12, 0.1), Vector2(0.23, 0.18), 0.12, Color(0.42, 0.3, 0.2), Vector3(0, 0.1, -0.07), &"fur")
	# Шлем-шапель с красным плюмажем.
	m.head.add_child(LowPoly.cyl(0.27, 0.29, 0.03, 10, STEEL, Vector3(0, 0.32, 0), 0.6, 0.6, 0.0, &"iron"))
	m._ball(m.head, 0.17, STEEL, Vector3(0, 0.36, 0.01), &"iron", Vector3(1.0, 0.75, 1.0))
	for k in 3:
		m._pyr(m.head, Vector2(0.06, 0.08), 0.22 - k * 0.03, Color(0.78, 0.12, 0.1), Vector3(0, 0.5 - k * 0.02, 0.03 + k * 0.07), &"fur", Vector3(-0.5 - k * 0.3, 0, 0))
	_arms(m, p, Color(0.38, 0.1, 0.1), &"cloth", SKIN, 0.09, 0.07)
	for arm in [m.arm_l, m.arm_r]:
		m._ball(arm, 0.14, STEEL, Vector3(0, -0.02, 0), &"iron", Vector3(1.2, 0.8, 1.1))
	# Старая рана на левом предплечье: левой он так и не научился закрываться.
	m._oval(m.arm_l, 0.085, 0.08, 0.16, 1.0, LINEN, Vector3(0, -arm_len * 0.62, 0), &"cloth", 6)
	m.sockets[&"l_hand"].add_child(captain_shield())


static func captain_shield() -> Node3D:
	var shield := LowPoly.pivot("CaptainShield", Vector3(-0.08, 0.16, -0.1))
	var disc := LowPoly.cyl(0.36, 0.36, 0.05, 10, Color(0.42, 0.12, 0.1), Vector3.ZERO, 0.9, 0.0, 0.0, &"wood")
	disc.rotation.x = PI / 2
	shield.add_child(disc)
	var rim := LowPoly.torus(0.34, 0.38, 12, 3, Color(0.55, 0.55, 0.58), Vector3.ZERO, 0.6, 0.5)
	rim.rotation.x = PI / 2
	shield.add_child(rim)
	shield.add_child(LowPoly.box(Vector3(0.62, 0.07, 0.02), GOLD, Vector3(0, 0, -0.035), 0.6, 0.6, 0.3))
	shield.add_child(LowPoly.gem(0.07, 0.06, 0.02, 6, STEEL, Vector3(0, 0, -0.05), &"iron", 0.6))
	return shield


# --- Аслауг: вдова с младенцем, тёмная шаль --------------------------------------

static func _widow(m: ActorModel, p: Dictionary) -> void:
	var shawl := Color(0.22, 0.18, 0.22)
	var skirt := Color(0.38, 0.27, 0.2)
	var chest: Vector3 = p["chest"]
	m.rest_pose = &"hold"
	_legs(m, p, skirt.darkened(0.3), &"cloth", 0.08)
	_skirt(m, skirt, 0.2, 0.38)
	m._oval(m.torso, 0.23, 0.17, chest.y * 0.9, 0.66, skirt.darkened(0.15), Vector3(0, chest.y * 0.45, 0), &"cloth")
	m._f(m.torso, Vector2(0.58, 0.38), Vector2(0.3, 0.22), 0.34, shawl, Vector3(0, chest.y * 0.8, 0.02), &"cloth")
	m._f(m.torso, Vector2(0.3, 0.03), Vector2(0.46, 0.03), 0.62, shawl, Vector3(0, chest.y * 0.32, chest.z * 0.6), &"cloth")
	_head(m, SKIN.darkened(0.05), 0.2)
	m._ball(m.head, 0.168, shawl.darkened(0.2), Vector3(0, 0.3, 0.035), &"cloth", Vector3(1.0, 0.95, 1.05))
	m._f(m.head, Vector2(0.3, 0.06), Vector2(0.24, 0.06), 0.3, shawl.darkened(0.2), Vector3(0, 0.12, 0.13), &"cloth")
	_arms(m, p, shawl, &"cloth", SKIN, 0.08, 0.07)
	var baby := widow_baby()
	baby.position = Vector3(0, chest.y * 0.4, -0.25)
	m.torso.add_child(baby)


## Младенец в пелёнках у груди.
static func widow_baby() -> Node3D:
	var baby := LowPoly.pivot("Baby")
	var swaddle := LowPoly.cyl(0.1, 0.09, 0.32, 6, LINEN, Vector3.ZERO, 0.9, 0.0, 0.0, &"cloth")
	swaddle.rotation = Vector3(0, 0, PI / 2 - 0.3)
	baby.add_child(swaddle)
	baby.add_child(LowPoly.sphere(0.065, 7, 4, PALE, Vector3(0.15, 0.06, -0.01), 0.9, 0.0, 0.0, &"skin"))
	return baby


# --- Гуннар: старый кузнец, лысый, седые усы, фартук и молот ----------------------

static func _smith(m: ActorModel, p: Dictionary) -> void:
	var skin := Color(0.86, 0.7, 0.6)
	var tunic := Color(0.3, 0.26, 0.24)
	var leather := Color(0.4, 0.27, 0.18)
	var grey := Color(0.78, 0.77, 0.75)
	var chest: Vector3 = p["chest"]
	var arm_len: float = p["arm"]
	_legs(m, p, Color(0.28, 0.24, 0.22), &"cloth", 0.14, Color(0.3, 0.22, 0.16))
	m._oval(m.hips, 0.3, 0.27, 0.28, 0.75, Color(0.28, 0.24, 0.22), Vector3(0, -0.05, 0), &"cloth")
	m._oval(m.hips, 0.31, 0.31, 0.07, 0.75, leather, Vector3(0, 0.07, 0), &"leather")
	m._oval(m.torso, 0.4, 0.3, chest.y * 0.85, 0.66, tunic, Vector3(0, chest.y * 0.46, 0), &"cloth")
	m._ball(m.torso, 0.27, tunic, Vector3(0, 0.12, -0.08), &"cloth", Vector3(1.2, 1.0, 1.0))
	m._f(m.torso, Vector2(0.44, 0.03), Vector2(0.34, 0.03), chest.y * 1.5, leather, Vector3(0, chest.y * 0.08, -0.34), &"leather", Vector2.ZERO, Vector3(0.1, 0, 0))
	m._bx(m.torso, Vector3(0.12, 0.08, 0.02), Color(0.15, 0.12, 0.12), Vector3(0.1, chest.y * 0.5, -0.36))
	# Голова: лысина, седые усы и борода, кустистые брови.
	_head(m, skin, 0.24)
	m._bx(m.head, Vector3(0.22, 0.035, 0.04), grey, Vector3(0, 0.29, -0.15), &"fur")
	m._f(m.head, Vector2(0.12, 0.1), Vector2(0.26, 0.2), 0.22, grey, Vector3(0, 0.05, -0.08), &"fur")
	for side in [-1.0, 1.0]:
		m._bx(m.head, Vector3(0.11, 0.035, 0.04), grey, Vector3(side * 0.06, 0.18, -0.16), &"fur", Vector3(0, 0, side * -0.35))
	m._bx(m.head, Vector3(0.06, 0.04, 0.02), Color(0.2, 0.17, 0.16), Vector3(-0.08, 0.33, -0.13))
	for arm in [m.arm_l, m.arm_r]:
		m._ball(arm, 0.14, skin, Vector3(0, -0.05, 0), &"skin")
		m._limb(arm, 0.11, 0.08, arm_len, skin, &"skin")
		m._ball(arm, 0.1, skin, Vector3(0, -0.24, 0), &"skin", Vector3(1, 1.5, 1))
		m._hand(arm, arm_len, skin, &"skin")
	m._oval(m.arm_r, 0.1, 0.1, 0.2, 1.0, leather, Vector3(0, -arm_len * 0.72, 0), &"leather", 6)
	# Молот у правого бедра.
	var hammer := LowPoly.pivot("Hammer", Vector3(0.33, -0.2, -0.04))
	hammer.add_child(LowPoly.cyl(0.025, 0.03, 0.52, 5, Color(0.55, 0.4, 0.25), Vector3(0, -0.05, 0), 0.9, 0.0, 0.0, &"wood"))
	hammer.add_child(LowPoly.box(Vector3(0.18, 0.09, 0.09), Color(0.5, 0.5, 0.52), Vector3(0, 0.22, 0), 0.6, 0.5, 0.0, &"iron"))
	hammer.rotation.z = 0.15
	m.hips.add_child(hammer)


# --- Асмунд: ученик знахаря в рясе с капюшоном, с посохом и травами ---------------

static func _novice(m: ActorModel, p: Dictionary) -> void:
	var robe := Color(0.44, 0.33, 0.22)
	var chest: Vector3 = p["chest"]
	_legs(m, p, robe.darkened(0.3), &"cloth", 0.08)
	m.hips.add_child(LowPoly.cyl(0.2, 0.36, 0.96, 8, robe, Vector3(0, -0.43, 0), 0.9, 0.0, 0.0, &"cloth"))
	m.hips.add_child(LowPoly.torus(0.19, 0.225, 10, 3, Color(0.75, 0.64, 0.42), Vector3(0, 0.03, 0), 0.9))
	m._oval(m.torso, 0.26, 0.2, chest.y * 0.9, 0.66, robe, Vector3(0, chest.y * 0.45, 0), &"cloth")
	m._f(m.torso, Vector2(0.46, 0.32), Vector2(0.26, 0.2), 0.2, robe.darkened(0.15), Vector3(0, chest.y * 0.9, 0.03), &"cloth")
	# Сумка с травами на левом боку.
	m._bx(m.torso, Vector3(0.04, 0.72, chest.z * 0.72), Color(0.42, 0.3, 0.2), Vector3(0, chest.y * 0.45, 0), &"leather", Vector3(0, 0, -0.6))
	m._bx(m.hips, Vector3(0.09, 0.2, 0.22), Color(0.5, 0.38, 0.24), Vector3(-0.3, -0.04, 0.02), &"leather")
	for k in 3:
		m._pyr(m.hips, Vector2(0.04, 0.04), 0.12, Color(0.4, 0.6, 0.3), Vector3(-0.3, 0.1, -0.05 + k * 0.05), &"", Vector3(0, 0, -0.3 + k * 0.3))
	_head(m, SKIN, 0.2)
	_hair(m, Color(0.6, 0.45, 0.28), 0.29, 0.15)
	var hood := robe.darkened(0.15)
	m._put(m.head, LowPoly.cyl(0.12, 0.22, 0.38, 7, hood, Vector3(0, 0.3, 0.08), 0.9, 0.0, 0.0, &"cloth"), Vector3(0.2, 0, 0))
	m._ball(m.head, 0.13, hood, Vector3(0, 0.46, 0.1), &"cloth")
	_arms(m, p, robe, &"cloth", SKIN, 0.08, 0.11)
	m.sockets[&"r_hand"].add_child(novice_staff())


static func novice_staff() -> Node3D:
	var staff := LowPoly.pivot("Staff")
	staff.add_child(LowPoly.cyl(0.025, 0.03, 1.6, 5, Color(0.55, 0.4, 0.25), Vector3(0, 0.25, 0), 0.9, 0.0, 0.0, &"wood"))
	staff.add_child(LowPoly.torus(0.03, 0.045, 6, 3, Color(0.4, 0.6, 0.3), Vector3(0, 0.95, 0), 0.9))
	return staff


# --- Сигвард: старший брат. Похож на Солдата, но без единого шрама ----------------

static func _tyrant(m: ActorModel, p: Dictionary) -> void:
	var young := m.variant == &"young"
	var skin := Color(0.9, 0.82, 0.76)
	var coat := Color(0.28, 0.12, 0.34) if not young else LINEN
	var hair := Color(0.28, 0.19, 0.14)
	var chest: Vector3 = p["chest"]
	var arm_len: float = p["arm"]
	if not young:
		m.rest_pose = &"hands_back"
	_legs(m, p, Color(0.1, 0.08, 0.09) if not young else Color(0.4, 0.3, 0.22), &"cloth", 0.11, Color(0.12, 0.09, 0.08) if not young else BOOTS)
	if young:
		m._oval(m.hips, 0.24, 0.2, 0.26, 0.72, Color(0.4, 0.3, 0.22), Vector3(0, -0.04, 0), &"cloth")
	else:
		m.hips.add_child(LowPoly.cyl(0.24, 0.36, 0.72, 8, coat, Vector3(0, -0.3, 0), 0.9, 0.0, 0.0, &"cloth"))
		m.hips.add_child(LowPoly.cyl(0.365, 0.37, 0.04, 8, GOLD, Vector3(0, -0.66, 0), 0.5, 0.7, 0.2, &"gold"))
	m._oval(m.hips, 0.26, 0.26, 0.06, 0.72, Color(0.2, 0.12, 0.1), Vector3(0, 0.06, 0), &"leather")
	m._oval(m.torso, 0.33, 0.24, chest.y * 0.9, 0.62, coat, Vector3(0, chest.y * 0.45, 0), &"cloth")
	_head(m, skin, 0.25)
	if young:
		_hair(m, hair, 0.3, 0.155)
	else:
		_hair(m, hair, 0.29, 0.16)
		m._pyr(m.head, Vector2(0.08, 0.06), 0.24, hair, Vector3(0, 0.12, 0.17), &"fur", Vector3(2.8, 0, 0))
		# Аккуратная борода — как у брата, только без шрама.
		m._f(m.head, Vector2(0.12, 0.1), Vector2(0.24, 0.19), 0.13, hair, Vector3(0, 0.1, -0.07), &"fur")
		for k in 4:
			m._bx(m.torso, Vector3(0.035, 0.035, 0.02), GOLD, Vector3(0, chest.y * (0.2 + k * 0.18), -chest.z * 0.62), &"gold", Vector3.ZERO, 0.7, 0.3)
		# Плащ до пят и меховой воротник.
		m._f(m.torso, Vector2(0.95, 0.05), Vector2(0.6, 0.05), 1.6, Color(0.14, 0.07, 0.17), Vector3(0, -0.15, 0.25), &"cloth", Vector2.ZERO, Vector3(0.1, 0, 0))
		m._f(m.torso, Vector2(0.7, 0.46), Vector2(0.36, 0.28), 0.18, Color(0.8, 0.78, 0.74), Vector3(0, chest.y * 0.92, 0.02), &"fur")
		# Корона.
		m.head.add_child(LowPoly.cyl(0.165, 0.17, 0.06, 8, GOLD, Vector3(0, 0.39, 0.02), 0.4, 0.8, 0.3, &"gold"))
		for k in 5:
			var a := TAU * k / 5.0 - PI / 2
			m._pyr(m.head, Vector2(0.05, 0.05), 0.11, GOLD, Vector3(cos(a) * 0.15, 0.46, 0.02 + sin(a) * 0.15), &"gold", Vector3.ZERO, 0.8, 0.3)
		m._gm(m.head, 0.03, 0.03, 0.03, 4, Color(0.6, 0.1, 0.2), Vector3(0, 0.39, -0.155), &"", Vector3.ZERO, 0.0, 1.5)
	_arms(m, p, coat, &"cloth", skin, 0.09, 0.07)
	if not young:
		for arm in [m.arm_l, m.arm_r]:
			m._oval(arm, 0.08, 0.08, 0.06, 1.0, GOLD, Vector3(0, -arm_len + 0.06, 0), &"gold", 6)


# --- Ярл: старый отец братьев. Седая борода до пояса, меховой плащ, обруч, посох ----

static func _father(m: ActorModel, p: Dictionary) -> void:
	var robe := Color(0.22, 0.3, 0.32)
	var fur := Color(0.62, 0.6, 0.56)
	var white := Color(0.92, 0.9, 0.86)
	var skin := Color(0.88, 0.76, 0.7)
	var chest: Vector3 = p["chest"]
	m.rest_pose = &"frail"
	_legs(m, p, robe.darkened(0.3), &"cloth", 0.1)
	m.hips.add_child(LowPoly.cyl(0.24, 0.38, 0.96, 8, robe, Vector3(0, -0.43, 0), 0.9, 0.0, 0.0, &"cloth"))
	m._oval(m.hips, 0.27, 0.27, 0.07, 0.72, Color(0.42, 0.3, 0.2), Vector3(0, 0.05, 0), &"leather")
	m._oval(m.torso, 0.3, 0.23, chest.y * 0.9, 0.62, robe, Vector3(0, chest.y * 0.45, 0), &"cloth")
	# Тяжёлый меховой плащ на плечах — он стал велик старику.
	m._f(m.torso, Vector2(0.76, 0.5), Vector2(0.4, 0.3), 0.24, fur, Vector3(0, chest.y * 0.88, 0.02), &"fur")
	m._f(m.torso, Vector2(0.9, 0.05), Vector2(0.6, 0.05), 1.5, fur.darkened(0.25), Vector3(0, -0.1, 0.24), &"fur", Vector2.ZERO, Vector3(0.1, 0, 0))
	_head(m, skin)
	# Лысина, седина на висках, длинная седая борода, обруч ярла.
	m._ball(m.head, 0.155, white, Vector3(0, 0.25, 0.06), &"fur", Vector3(1.0, 0.9, 1.0))
	m._f(m.head, Vector2(0.06, 0.06), Vector2(0.26, 0.18), 0.5, white, Vector3(0, -0.06, -0.08), &"fur")
	for side in [-1.0, 1.0]:
		m._bx(m.head, Vector3(0.1, 0.03, 0.04), white, Vector3(side * 0.06, 0.18, -0.16), &"fur", Vector3(0, 0, side * -0.3))
		m._bx(m.head, Vector3(0.07, 0.025, 0.03), white, Vector3(side * 0.06, 0.3, -0.15), &"fur")
	var circlet := LowPoly.torus(0.15, 0.165, 12, 3, Color(0.85, 0.86, 0.9), Vector3(0, 0.32, 0.0), 0.4, 0.8, 0.3)
	circlet.rotation.x = -0.1
	m.head.add_child(circlet)
	_arms(m, p, robe, &"cloth", skin, 0.085, 0.07)
	m.sockets[&"l_hand"].add_child(father_staff())


static func father_staff() -> Node3D:
	var staff := LowPoly.pivot("Staff")
	staff.add_child(LowPoly.cyl(0.03, 0.035, 1.7, 5, Color(0.5, 0.36, 0.22), Vector3(0, 0.3, 0), 0.9, 0.0, 0.0, &"wood"))
	staff.add_child(LowPoly.sphere(0.06, 6, 3, Color(0.5, 0.36, 0.22), Vector3(0, 1.17, 0), 0.9, 0.0, 0.0, &"wood"))
	staff.rotation.x = -0.55
	return staff


# --- Гудрун: мать Сольвейг. Седая, в тёмном платье и белом повойнике, ключи у пояса --

static func _mother(m: ActorModel, p: Dictionary) -> void:
	var dress := Color(0.3, 0.36, 0.31)
	var apron := Color(0.82, 0.78, 0.7)
	# Выцветший багрянец шали — тот же цвет, что у платья дочери.
	var shawl := Color(0.48, 0.2, 0.2)
	var coif := Color(0.92, 0.9, 0.84)
	var grey := Color(0.74, 0.73, 0.72)
	var skin := Color(0.86, 0.75, 0.68)
	var chest: Vector3 = p["chest"]
	m.rest_pose = &"wring"
	_legs(m, p, dress.darkened(0.3), &"cloth", 0.08)
	_skirt(m, dress, 0.21, 0.4)
	m._f(m.hips, Vector2(0.34, 0.03), Vector2(0.26, 0.03), 0.62, apron, Vector3(0, -0.42, -0.3), &"rags", Vector2.ZERO, Vector3(0.18, 0, 0))
	m._oval(m.torso, 0.24, 0.18, chest.y * 0.9, 0.66, dress, Vector3(0, chest.y * 0.45, 0), &"cloth")
	m._f(m.torso, Vector2(0.56, 0.36), Vector2(0.3, 0.22), 0.3, shawl, Vector3(0, chest.y * 0.82, 0.02), &"cloth")
	m._f(m.torso, Vector2(0.28, 0.03), Vector2(0.44, 0.03), 0.5, shawl, Vector3(0, chest.y * 0.36, chest.z * 0.6), &"cloth")
	# Связка ключей у пояса: дом пока её.
	m.hips.add_child(LowPoly.torus(0.035, 0.05, 8, 3, GOLD, Vector3(0.24, -0.02, -0.12), 0.4, 0.8, 0.3, &"gold"))
	for k in 3:
		m._bx(m.hips, Vector3(0.02, 0.13, 0.02), GOLD, Vector3(0.22 + k * 0.025, -0.11, -0.13), &"gold", Vector3(0, 0, -0.2 + k * 0.2), 0.8, 0.2)
	_head(m, skin, 0.2)
	# Повойник; из-под него — седые пряди на висках.
	m._ball(m.head, 0.166, coif, Vector3(0, 0.31, 0.035), &"", Vector3(1.0, 0.95, 1.05))
	m._f(m.head, Vector2(0.28, 0.06), Vector2(0.22, 0.06), 0.24, coif, Vector3(0, 0.14, 0.13))
	for side in [-1.0, 1.0]:
		m._bx(m.head, Vector3(0.03, 0.11, 0.05), grey, Vector3(side * 0.137, 0.22, -0.08), &"fur")
	_arms(m, p, dress, &"cloth", skin, 0.075, 0.065)


# --- Реквизит ---------------------------------------------------------------

## Деревянный меч братьев из флешбэка.
static func wooden_sword() -> Node3D:
	var s := LowPoly.pivot("WoodenSword")
	var wood := Color(0.62, 0.46, 0.3)
	s.add_child(LowPoly.box(Vector3(0.07, 0.8, 0.035), wood, Vector3(0, 0.46, 0), 0.9, 0.0, 0.0, &"wood"))
	s.add_child(LowPoly.box(Vector3(0.24, 0.05, 0.06), wood.darkened(0.2), Vector3(0, 0.06, 0), 0.9, 0.0, 0.0, &"wood"))
	s.add_child(LowPoly.box(Vector3(0.045, 0.18, 0.045), wood.darkened(0.35), Vector3(0, -0.05, 0), 0.9, 0.0, 0.0, &"leather"))
	s.rotation.x = deg_to_rad(-100)
	return s


## Перстень отца: золотое кольцо с тёмным камнем. glow — тёплый свет вокруг (крупный план в сценах).
static func father_ring(glow: bool = false) -> Node3D:
	var r := LowPoly.pivot("FatherRing")
	var band := LowPoly.torus(0.05, 0.075, 10, 4, GOLD, Vector3.ZERO, 0.4, 0.8, 1.2, &"gold")
	band.rotation.x = PI / 2
	r.add_child(band)
	r.add_child(LowPoly.gem(0.04, 0.03, 0.02, 6, Color(0.55, 0.08, 0.15), Vector3(0, 0.075, 0), &"", 0.0, 1.5))
	if glow:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.4)
		light.light_energy = 1.4
		light.omni_range = 1.4
		light.position = Vector3(0, 0.1, 0)
		r.add_child(light)
	return r
