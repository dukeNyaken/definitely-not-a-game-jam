class_name WornCloak
extends Node3D
## Плащ на плечах актёра сюжетной сцены. К кости он не привязан: идёт за шеей модели и поворачивается
## вместе с ней — поэтому одинаково сидит на сгенерированных и процедурных моделях и поднимается
## вместе с тем, кто встаёт с колен. Снятый плащ (wearer пуст) — обычный реквизит: его можно
## перенести по воздуху (Cutscene.fly) и надеть на другого.

## Насколько плащ отнесён от шеи за спину, м (при росте модели 1).
const BACK := 0.1

var wearer: Puppet
## Длина плаща: 1 — до пят стоящего. Сидящему — короче, иначе плащ уйдёт в землю и в то, на чём он сидит.
var drop: float = 1.0


static func make(color: Color) -> WornCloak:
	var c := WornCloak.new()
	c.name = "WornCloak"
	c.add_child(SetPieces.cloak(color))
	return c


func put_on(p: Puppet) -> void:
	wearer = p
	_follow()


func take_off() -> void:
	wearer = null


## Где плащ окажется на плечах актёра: сюда его несут по воздуху.
static func shoulders(p: Puppet) -> Vector3:
	var neck: Node3D = p.model.sockets.get(&"neck")
	if neck == null:
		return p.global_position + Vector3(0, 1.4, 0)
	return neck.global_position + p.model.global_basis.z.normalized() * BACK * p.model.scale.y


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if wearer == null or not is_instance_valid(wearer) or wearer.model == null:
		return
	global_position = shoulders(wearer)
	global_rotation = Vector3(0.0, wearer.model.global_rotation.y, 0.0)
	var k := wearer.model.scale.y
	scale = Vector3(k, k * drop, k)
