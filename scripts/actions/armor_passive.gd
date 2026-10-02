class_name ArmorPassive
extends ActionComponent
## Доспех, пассив: броня 50 поверх HP, восстанавливается после волны.
## Событие — Ответ: персонаж получил урон.


func _on_setup() -> void:
	actor.max_armor = def.stat("armor", 50.0)
	actor.armor = actor.max_armor
	actor.damaged.connect(_on_damaged)


func on_removed() -> void:
	actor.max_armor = 0.0
	actor.armor = 0.0
	if actor.damaged.is_connected(_on_damaged):
		actor.damaged.disconnect(_on_damaged)
	actor.health_changed.emit()


func _on_damaged(_amount: float, by: ActionContext) -> void:
	if actor.dead:
		return
	var ctx := new_context()
	if by != null:
		ctx.depth = by.depth + 1
		var attacker_pos := by.actor.global_position if is_instance_valid(by.actor) else by.origin
		ctx.aim_point = attacker_pos
		ctx.direction = Combat.flat_dir(attacker_pos - actor.global_position, actor.facing)
	used.emit(ctx)
	emit_native(ctx)
