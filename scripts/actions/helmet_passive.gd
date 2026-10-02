class_name HelmetPassive
extends ActionComponent
## Шлем, пассив: крит ×2 в окно уязвимости врага (0,8 с после его атаки), окно подсвечено.
## Событие — Крит: один раз на действие, только от действий (не от эффектов свойств).


func _on_setup() -> void:
	actor.crit_dealt.connect(_on_crit)


func on_removed() -> void:
	if actor.crit_dealt.is_connected(_on_crit):
		actor.crit_dealt.disconnect(_on_crit)


func _on_crit(by: ActionContext, target: Actor) -> void:
	if by.from_property or by.crit_emitted:
		return
	by.crit_emitted = true
	var ctx := new_context()
	ctx.depth = by.depth + 1
	if is_instance_valid(target):
		ctx.aim_point = target.global_position
	Audio.play(&"crit")
	used.emit(ctx)
	emit_native(ctx)
