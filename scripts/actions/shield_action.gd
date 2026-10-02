class_name ShieldAction
extends ActionComponent
## Щит, ПКМ (удерживать): блок 120° спереди, −50% скорости. Событие — Блок (при поднятии щита).

var holding: bool = false


func _on_setup() -> void:
	actor.blocked.connect(_on_blocked)


func press() -> bool:
	if holding or not can_use():
		return false
	holding = true
	actor.block_arc_degrees = def.stat("arc", 120.0)
	start_cooldown(float(def.stat("raise_cooldown", 0.25)))
	var ctx := new_context()
	Audio.play(&"shield_raise")
	used.emit(ctx)
	emit_native(ctx)
	return true


func release() -> void:
	if not holding:
		return
	holding = false
	actor.block_arc_degrees = 0.0


func interrupt() -> void:
	release()


func speed_factor() -> float:
	return float(def.stat("speed_multiplier", 0.5)) if holding else 1.0


func on_removed() -> void:
	release()
	if actor.blocked.is_connected(_on_blocked):
		actor.blocked.disconnect(_on_blocked)


func _on_blocked(ctx: ActionContext) -> void:
	Audio.play(&"block")
	var src := ctx.origin if ctx != null else actor.global_position + actor.facing
	var p := actor.global_position + Combat.flat_dir(src - actor.global_position, actor.facing) * 0.8 + Vector3(0, 0.9, 0)
	FlipbookFx.spawn(actor, &"impact", p, def.essence.color, 1.3, {"energy": 2.4, "pull": 1.2})
