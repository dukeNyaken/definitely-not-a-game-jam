class_name EssenceEffect
extends RefCounted
## Эффект сущности, который применяет свойство. Цвет эффекта — цвет сущности.


func apply(_essence: EssenceDef, _ctx: ActionContext) -> void:
	pass


func play_sound(essence: EssenceDef) -> void:
	Audio.play(StringName("essence_%s" % essence.id))
