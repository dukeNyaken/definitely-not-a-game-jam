class_name Property
extends Resource
## Свойство: слушает событие → применяет эффект сущности → порождает событие. Плюс откат.

@export var listen_event: StringName
@export var essence_id: StringName
@export var emit_event: StringName
@export var cooldown: float = 0.4
## Вещь, пожертвованная ради этого свойства.
@export var source_item_id: StringName


static func create(listen: StringName, essence: StringName, emit: StringName, source: StringName, cd: float) -> Property:
	var p := Property.new()
	p.listen_event = listen
	p.essence_id = essence
	p.emit_event = emit
	p.source_item_id = source
	p.cooldown = cd
	return p


## «Неуязвимый рывок»: прилагательное сущности + слово слушаемого события.
func display_name() -> String:
	var essence: EssenceDef = Db.essence(essence_id)
	var listened: ItemDef = Db.item_by_event(listen_event)
	return "%s %s" % [essence.adjective, listened.event_word]


func key() -> String:
	return "%s>%s>%s" % [listen_event, essence_id, emit_event]
