class_name ActionComponent
extends Node3D
## Узел-компонент действия вещи. Одинаково работает у героя, элит и босса.

signal used(ctx: ActionContext)

var actor: Actor
## Вещь компонента; null у врождённых атак (кулак, атаки врагов).
var item: ItemState
var def: ItemDef
var cooldown_left: float = 0.0
var cooldown_total: float = 0.0


func setup(p_actor: Actor, p_item: ItemState) -> void:
	actor = p_actor
	item = p_item
	def = p_item.def() if p_item != null else null
	_on_setup()


func _on_setup() -> void:
	pass


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_tick(delta)


func _tick(_delta: float) -> void:
	pass


func input_action() -> StringName:
	return def.input_action if def != null else &""


func is_passive() -> bool:
	return def != null and def.is_passive()


func can_use() -> bool:
	return cooldown_left <= 0.0 and actor != null and actor.can_act() and not actor.is_dashing()


## Нажатие кнопки (или решение ИИ). Возвращает true, если действие состоялось.
func press() -> bool:
	return false


func release() -> void:
	pass


## Сбивает замах/блок при оглушении.
func interrupt() -> void:
	pass


func speed_factor() -> float:
	return 1.0


func on_removed() -> void:
	pass


func start_cooldown(t: float) -> void:
	cooldown_left = t
	cooldown_total = t


func cooldown_ratio() -> float:
	if cooldown_total <= 0.0:
		return 0.0
	return clampf(cooldown_left / cooldown_total, 0.0, 1.0)


## Каждое свойство на вещи даёт +10% к урону её действия.
func damage_mult() -> float:
	return ActionContext.item_mult(item)


func new_context() -> ActionContext:
	var ctx := ActionContext.make(actor, item)
	ctx.damage_mult = damage_mult()
	if def != null:
		ctx.color = def.essence.color
	return ctx


## Родное событие вещи: один раз на действие.
func emit_native(ctx: ActionContext) -> void:
	if def != null:
		actor.bus.emit_event(def.event_id, ctx)
