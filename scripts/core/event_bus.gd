class_name EventBus
extends Node
## Шина событий персонажа. Событие вещи запускает свойства этой вещи:
## каждое применяет эффект своей сущности и порождает своё событие дальше по дереву.

signal event_fired(event_id: StringName, ctx: ActionContext)
signal property_triggered(prop: Property, ctx: ActionContext)

## Собственные часы шины: идут только пока идёт игра (пауза их останавливает).
var clock: float = 0.0
var _last_fired: Dictionary = {}


func _process(delta: float) -> void:
	clock += delta


func emit_event(event_id: StringName, ctx: ActionContext) -> void:
	if ctx.depth > Db.balance.max_chain_depth:
		return
	event_fired.emit(event_id, ctx)
	if ctx.item == null:
		return
	for prop in ctx.item.properties.duplicate():
		if prop.listen_event != event_id or not is_ready(prop):
			continue
		_last_fired[prop] = clock
		var essence := Db.essence(prop.essence_id)
		var child := ctx.derive(prop)
		child.color = essence.color
		Db.effect(prop.essence_id).apply(essence, child)
		property_triggered.emit(prop, child)
		emit_event(prop.emit_event, child)


func is_ready(prop: Property) -> bool:
	if not _last_fired.has(prop):
		return true
	return clock - float(_last_fired[prop]) >= prop.cooldown - 0.0001


func reset_cooldowns() -> void:
	_last_fired.clear()
