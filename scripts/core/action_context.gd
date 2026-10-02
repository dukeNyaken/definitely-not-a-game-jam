class_name ActionContext
extends RefCounted
## Одно действие персонажа (или эффект свойства внутри цепочки).
## Событие порождается один раз на действие, а не на каждую цель.

var actor: Actor
## Вещь, от которой идёт событие. Свойства слушают только события своей вещи.
var item: ItemState
var origin: Vector3
var direction: Vector3 = Vector3.FORWARD
var aim_point: Vector3
var damage_mult: float = 1.0
var from_property: bool = false
var property: Property
var depth: int = 0
var crit_emitted: bool = false
var landed_hit: bool = false
## Цвет эффекта для VFX (цвет сущности).
var color: Color = Color.WHITE
var tag: StringName = &""


static func make(p_actor: Actor, p_item: ItemState) -> ActionContext:
	var ctx := ActionContext.new()
	ctx.actor = p_actor
	ctx.item = p_item
	if is_instance_valid(p_actor):
		ctx.origin = p_actor.global_position
		ctx.direction = p_actor.facing
		ctx.aim_point = p_actor.aim_point
	return ctx


## Контекст для эффекта свойства, сработавшего внутри цепочки.
func derive(p: Property) -> ActionContext:
	var ctx := ActionContext.make(actor, item)
	ctx.from_property = true
	ctx.property = p
	ctx.depth = depth + 1
	ctx.damage_mult = 1.0
	if not is_instance_valid(actor):
		ctx.origin = origin
		ctx.direction = direction
		ctx.aim_point = aim_point
	return ctx
