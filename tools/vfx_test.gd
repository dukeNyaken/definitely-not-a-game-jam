extends Node3D
## Тестовая сцена эффектов: удары, крит, Взор, аура элиты — для сравнения «было/стало».

var hero: Actor
var dummies: Array[Actor] = []
var elite: Actor
var hero_model: ActorModel
var _t: float = 0.0
var _done: Dictionary = {}
## Сценарий: hits — удары, Взор, аура (пилот); arcs — дуги ударов, кольца, ударная волна;
## pools — лужи яда, волна Энергии, извержение зоны, удар громилы;
## ward — купол Оплота, цепи Хватки, следы рывка; dash — настоящий рывок героя со следом;
## ritual — круг алтаря, порталы врагов, поток огоньков жертвы; summon — призывные круги обычного врага и элиты;
## motifs — эффекты сущностей с мотивами: Лезвие, Масса, Порыв.
var scenario := "hits"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scenario="):
			scenario = a.trim_prefix("scenario=")
	var arena := Arena.new()
	add_child(arena)
	arena.build(15.0)
	hero = Actor.new()
	add_child(hero)
	hero.global_position = Vector3(1.2, 0, 1.2)
	hero.set_items([ItemState.create(&"sword"), ItemState.create(&"helmet")] as Array[ItemState])
	var hm := ActorModel.new()
	hero.add_child(hm)
	hm.setup(hero, ActorModel.Kind.HERO)
	hero_model = hm
	hero.add_child(HeroMarker.new())
	Combat.hero = hero
	for p in [Vector3(-1.2, 0, -0.4), Vector3(-0.2, 0, -1.4), Vector3(-1.9, 0, -1.9)]:
		var d := EnemyFactory.create(Db.enemy(&"infantry"), 1)
		(d.get_node("AI") as AIController).active = false
		add_child(d)
		d.global_position = p
		d.max_hp = 9999.0
		d.hp = 9999.0
		d.facing = Combat.flat_dir(hero.global_position - p)
		dummies.append(d)
	elite = EnemyFactory.create(Db.enemy(&"infantry"), 1, [ItemState.create(&"shield"), ItemState.create(&"helmet")] as Array[ItemState])
	(elite.get_node("AI") as AIController).active = false
	add_child(elite)
	elite.global_position = Vector3(1.6, 0, -2.2)
	elite.facing = Combat.flat_dir(hero.global_position - elite.global_position)
	hero.aim_point = dummies[0].global_position
	var rig := CameraRig.new()
	rig.size = 7.5
	add_child(rig)
	rig.global_position = Vector3(-0.3, 0, -0.5)
	rig.cinematic = true


func _once(key: String, at: float) -> bool:
	if _t >= at and not _done.has(key):
		_done[key] = true
		return true
	return false


func _process(delta: float) -> void:
	_t += delta
	var ctx := ActionContext.make(hero, null)
	if scenario == "arcs":
		_arcs(ctx)
		return
	if scenario == "pools":
		_pools(ctx)
		return
	if scenario == "ward":
		_ward()
		return
	if scenario == "dash":
		_dash()
		return
	if scenario == "ritual":
		_ritual()
		return
	if scenario == "summon":
		_summon()
		return
	if scenario == "motifs":
		_motifs()
		return
	if _once("gaze", 1.1):
		var e := Db.essence(&"gaze")
		var g := ActionContext.make(hero, ItemState.create(&"helmet"))
		g.from_property = true
		Db.effect(&"gaze").apply(e, g)
	if _once("hit1", 1.3):
		dummies[1].open_time = 0.0
		Combat.deal(ctx, dummies[1], 10.0)
	if _once("block", 1.33):
		elite.block_arc_degrees = 140.0
		Combat.deal(ctx, elite, 10.0)
	if _once("crit", 1.36):
		dummies[0].open_for_crit(1.0)
		Combat.deal(ctx, dummies[0], 10.0)
	if _once("kill", 2.0):
		elite.block_arc_degrees = 0.0
		Combat.deal(ctx, elite, 99999.0)


func _arcs(ctx: ActionContext) -> void:
	if _once("sword", 1.0):
		Vfx.slash(hero, hero.global_position, dummies[0].global_position - hero.global_position, 2.3, 120.0, Color(1, 1, 1))
	if _once("enemy", 1.0):
		Vfx.slash(elite, elite.global_position, hero.global_position - elite.global_position, 1.7, 100.0, Color(1, 0.45, 0.3), 0.18)
	if _once("blade", 1.6):
		Vfx.slash(hero, hero.global_position, Vector3(-1, 0, 0.3), 2.5, 180.0, Db.essence(&"blade").color, 0.26, true)
	if _once("mass", 2.2):
		Vfx.ring(hero, dummies[2].global_position, 3.0, Db.essence(&"mass").color, 0.45, 0.6)
	if _once("wave", 2.2):
		var wave := Shockwave.new()
		wave.setup(ctx, 6.0, 0.0, 0.6, Db.essence(&"energy").color)
		add_child(wave)
		wave.global_position = hero.global_position


func _pools(ctx: ActionContext) -> void:
	var foe := ActionContext.make(elite, null)
	if _once("trail", 0.4):
		var slime := Db.enemy(&"slime")
		for i in 6:
			PoisonPuddle.spawn(foe, Vector3(-3.6 + i * 0.8, 0, 1.6 + sin(i * 1.3) * 0.4), slime, 0.0)
		PoisonPuddle.spawn(foe, Vector3(-3.0, 0, 3.0), Db.enemy(&"slime_small"), 0.0)
	if _once("zone", 0.8):
		DamageZone.spawn(foe, Vector3(3.4, 0, 0.6), 2.0, 0.6, 0.0)
	if _once("energy", 1.0):
		var p := Projectile.spawn(ctx, hero.global_position, dummies[1].global_position - hero.global_position, 5.0, 0.0, &"energy", Db.essence(&"energy").color)
		p.pierce = true
	if _once("slam", 1.45):
		var c := Vector3(-3.2, 0, -2.6)
		Vfx.ring(elite, c, 2.2, Color(1, 0.5, 0.3), 0.3, 0.9)
		FlipbookFx.eruption_field(elite, c, 2.2 * 0.7, Color(0.8, 0.6, 0.4), 3)


func _ward() -> void:
	if _once("dome", 1.0):
		Vfx.dome(hero, Db.essence(&"bulwark").color, 0.6)
	if _once("chains", 1.02):
		for d in dummies:
			Vfx.beam(hero, hero.global_position + Vector3(0, 0.9, 0), d.global_position + Vector3(0, 0.9, 0), Db.essence(&"grip").color, 0.1, 0.4)
	if _once("dash", 1.0):
		Vfx.streak(hero, Vector3(3.6, 0, 3.0), Vector3(-0.6, 0, 3.6), Color(0.8, 0.75, 0.6, 0.6))
	if _once("gust", 1.04):
		Vfx.streak(hero, Vector3(-4.2, 0, -0.5), Vector3(-2.6, 0, 2.8), Db.essence(&"gust").color)


func _dash() -> void:
	if _once("dash", 1.0):
		var dir := Vector3(-1, 0, 0.35).normalized()
		var from := hero.global_position
		hero.start_dash(dir, 4.0, 0.18)
		Vfx.streak(hero, from, from + dir * 4.0, Color(0.8, 0.75, 0.6, 0.6))


func _ritual() -> void:
	if _once("setup", 0.2):
		var altar := Altar.new()
		add_child(altar)
		altar.global_position = Vector3(-3.4, 0, 1.4)
		for p in [Vector3(3.2, 0, 0.4), Vector3(-1.0, 0, 3.6)]:
			var portal := SpawnPortal.new()
			portal.delay = 0.9 if p.x > 0 else 99.0
			portal.payload = {"test": true}
			add_child(portal)
			portal.global_position = p
	if _once("gift", 1.0):
		var from := Vector3(-3.4, 1.2, 1.4)
		SacrificeFx.play(self, hero_model, from, &"helmet", Db.essence(&"gaze").color)


func _summon() -> void:
	if _once("circles", 1.0):
		var elite_items: Array[ItemState] = [ItemState.create(&"shield"), ItemState.create(&"helmet")]
		for spec in [[Vector3(-3.2, 0, 1.6), {"items": []}], [Vector3(2.6, 0, 0.8), {"items": elite_items}]]:
			var portal := SpawnPortal.new()
			portal.delay = 1.0
			portal.payload = spec[1]
			add_child(portal)
			portal.global_position = spec[0]
			portal.opened.connect(_summoned)


func _summoned(p: SpawnPortal) -> void:
	var items: Array[ItemState] = []
	items.assign(p.payload.get("items", []))
	var e := EnemyFactory.create(Db.enemy(&"infantry"), 1, items)
	(e.get_node("AI") as AIController).active = false
	add_child(e)
	e.global_position = p.global_position
	e.facing = Combat.flat_dir(hero.global_position - p.global_position)
	p.emerge(e)


func _essence(id: StringName, item: StringName) -> void:
	var ctx := ActionContext.make(hero, ItemState.create(item))
	ctx.from_property = true
	Db.effect(id).apply(Db.essence(id), ctx)


func _motifs() -> void:
	if _once("blade", 1.0):
		hero.aim_point = dummies[0].global_position
		hero.facing = Combat.flat_dir(hero.aim_point - hero.global_position)
		_essence(&"blade", &"sword")
	if _once("mass", 1.6):
		_essence(&"mass", &"armor")
	if _once("gust", 2.2):
		hero.aim_point = hero.global_position + Vector3(-4, 0, 1.2)
		_essence(&"gust", &"boots")
