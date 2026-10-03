class_name EnemyFactory
extends RefCounted
## Сборка врагов: Actor + атака + модель + ИИ. Элиты получают 1–2 вещи героя.

const LAYER_HERO := 2
const LAYER_ENEMY := 4

const KIND_BY_BEHAVIOR := {
	EnemyDef.Behavior.MELEE: ActorModel.Kind.INFANTRY,
	EnemyDef.Behavior.RANGED: ActorModel.Kind.ARCHER,
	EnemyDef.Behavior.SWARM: ActorModel.Kind.SWARM,
	EnemyDef.Behavior.BRUTE: ActorModel.Kind.BRUTE,
	EnemyDef.Behavior.CASTER: ActorModel.Kind.CASTER,
	EnemyDef.Behavior.SLIME: ActorModel.Kind.SLIME,
	EnemyDef.Behavior.JESTER: ActorModel.Kind.JESTER,
}


static func create(def: EnemyDef, stage: int, elite_items: Array[ItemState] = []) -> Actor:
	var elite := not elite_items.is_empty()
	var scale := RunState.enemy_scale(stage)
	var a := Actor.new()
	a.name = "Enemy_%s" % def.id
	a.faction = Actor.Faction.ENEMY
	a.display_name = ("Элитный " + def.display_name.to_lower()) if elite else def.display_name
	a.max_hp = def.hp * scale * (Db.balance.elite_hp_multiplier if elite else 1.0)
	a.hp = a.max_hp
	a.base_speed = def.speed
	a.body_radius = def.body_radius * (1.15 if elite else 1.0)
	a.knockback_immune = def.knockback_immune
	a.collision_layer = LAYER_ENEMY
	a.collision_mask = LAYER_HERO
	a.set_meta(&"elite", elite)
	a.set_meta(&"mastery_xp", Mastery.reward(def.id, stage, elite))
	a.set_meta(&"enemy_def", def)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = a.body_radius
	cyl.height = 1.8 * def.scale
	shape.shape = cyl
	shape.position.y = cyl.height * 0.5
	a.add_child(shape)
	var atk := EnemyAttack.new()
	atk.configure(def, def.damage * scale)
	a.set_innate(atk)
	if elite:
		a.set_items(elite_items)
		a.item_damage_mult = Db.balance.enemy_item_damage_mult
	var model := SkinnedActorModel.for_enemy(KIND_BY_BEHAVIOR[def.behavior])
	model.name = "Model"
	a.add_child(model)
	model.setup(a, KIND_BY_BEHAVIOR[def.behavior], def.color)
	model.scale = Vector3.ONE * def.scale * (1.2 if elite else 1.0)
	if elite:
		var aura := _elite_aura()
		model.add_child(aura)
		a.died.connect(func(_dead: Actor) -> void: aura.fade_out(0.3))
	if def.trail_damage > 0.0:
		var trail := TrailDropper.new()
		trail.name = "Trail"
		a.add_child(trail)
		trail.setup(a, def, def.trail_damage * scale)
	var ai := AIController.new()
	ai.name = "AI"
	a.add_child(ai)
	ai.setup(a, def, atk)
	ai.action_gap = Db.balance.elite_action_gap
	return a


## Какие вещи может нести элита этого типа (стрелкам меч ни к чему).
static func elite_item_pool(def: EnemyDef) -> Array[StringName]:
	match def.behavior:
		EnemyDef.Behavior.RANGED, EnemyDef.Behavior.CASTER:
			return [&"shield", &"armor", &"helmet", &"boots", &"amulet", &"gloves"]
		EnemyDef.Behavior.SLIME:
			return [&"armor", &"helmet", &"boots", &"amulet", &"gloves"]
		_:
			return Db.ITEM_IDS.duplicate()


static func _elite_aura() -> FlipbookFx:
	var aura := FlipbookFx.make(&"elite_aura", Color(1.0, 0.76, 0.3), 1.9, {"billboard": false, "loop": true, "energy": 1.8, "pull": 0.05})
	aura.name = "EliteAura"
	aura.position.y = 0.04
	return aura
