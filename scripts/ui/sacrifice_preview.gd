class_name SacrificePreview
extends RefCounted
## Тексты последствий из живого состояния вещей. Просмотр не меняет кольцо.


static func number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".").replace(".", ",")


static func action_name(item: ItemState) -> String:
	match item.def_id:
		&"sword": return "комбо на ЛКМ"
		&"shield": return "блок на ПКМ"
		&"boots": return "рывок на Пробел"
		&"gloves": return "захват на Q"
		&"amulet": return "волна на E"
		&"armor": return "броня поверх здоровья"
		&"helmet": return "крит после атаки врага"
	return item.def().action_text


static func action_summary(item: ItemState) -> String:
	var d := item.def()
	var mult := ActionContext.item_mult(item)
	var text := ""
	match item.def_id:
		&"sword":
			text = "ЛКМ: комбо из трёх ударов. Урон: %s." % _combo(item)
		&"shield":
			text = "Удерживайте ПКМ: блок спереди в секторе %s°. Скорость при блоке: %s%% от обычной." % [number(d.stat("arc")), number(d.stat("speed_multiplier") * 100.0)]
		&"boots":
			text = "Пробел: рывок на %s м. Откат: %s с." % [number(d.stat("distance")), number(d.stat("cooldown"))]
		&"gloves":
			text = "Q: притяжение врагов в конусе %s°, до %s м. Урон: %s. Оглушение: %s с. Откат: %s с." % [number(d.stat("arc")), number(d.stat("range")), number(d.stat("damage") * mult), number(d.stat("stun")), number(d.stat("cooldown"))]
		&"amulet":
			text = "E: волна вокруг героя, радиус %s м. Урон: %s. Откат: %s с." % [number(d.stat("radius")), number(d.stat("damage") * mult), number(d.stat("cooldown"))]
		&"armor":
			text = "Пассивно: %s брони поверх здоровья. Броня восстанавливается после волны." % number(d.stat("armor"))
		&"helmet":
			text = "Пассивно: крит ×%s в течение %s с после атаки врага." % [number(d.stat("crit_multiplier")), number(d.stat("window"))]
	if item.appearance > 1:
		var form := Mastery.form(item.def_id, item.appearance)
		text += "\nОблик «%s»: %s" % [form["name"], form["effect"]]
	return text


static func trigger(event: StringName) -> String:
	match event:
		&"hit": return "При ударе мечом"
		&"block": return "При поднятии блока"
		&"dash": return "При рывке"
		&"grab": return "При захвате"
		&"volley": return "При выпуске волны"
		&"response": return "При получении урона"
		&"crit": return "При критическом ударе"
	return "При действии вещи"


static func effect(p: Property, holder: ItemState) -> String:
	var e := Db.essence(p.essence_id)
	var mult := ActionContext.item_mult(holder)
	match p.essence_id:
		&"blade": return "разрез дугой %s°, радиус %s м, %s урона" % [number(e.stat("arc")), number(e.stat("radius")), number(e.stat("damage") * mult)]
		&"bulwark": return "неуязвимость на %s с и отражение снарядов" % number(e.stat("duration"))
		&"mass": return "толчок врагов на %s м в радиусе %s м, оглушение на %s с и %s урона" % [number(e.stat("push")), number(e.stat("radius")), number(e.stat("stun")), number(e.stat("damage") * mult)]
		&"gust": return "рывок на %s м к курсору" % number(e.stat("distance"))
		&"grip": return "притяжение врагов в конусе %s°, до %s м" % [number(e.stat("arc")), number(e.stat("range"))]
		&"gaze": return "открытие врагов в радиусе %s м для крита на %s с" % [number(e.stat("radius")), number(e.stat("duration"))]
		&"energy": return "волна-снаряд к курсору: %s урона, дальность %s м, проходит насквозь" % [number(e.stat("damage") * mult), number(e.stat("range"))]
	return e.effect_text


static func _combo(item: ItemState) -> String:
	var values := PackedStringArray()
	for damage in item.def().stat("combo", PackedFloat32Array()):
		values.append(number(damage * ActionContext.item_mult(item)))
	return " / ".join(values)


static func build(ring: Ring, index: int) -> Dictionary:
	if ring == null or ring.size() < 2 or index < 0 or index >= ring.size():
		return {}
	var preview := ring.preview(index)
	var victim: ItemState = preview["victim"]
	var recipient: ItemState = preview["recipient"]
	var after: ItemState = preview["recipient_after"]
	var prop: Property = preview["property"]
	var now := action_summary(victim)
	if not victim.properties.is_empty():
		for entry in PropertyTree.walk(victim):
			var p: Property = entry["property"]
			now += "\n• %s: %s." % [trigger(p.listen_event), effect(p, victim)]
	var loss := ""
	match victim.def_id:
		&"sword": loss = "Комбо мечом исчезнет. На ЛКМ останется удар кулаком: %s урона." % number(Db.balance.fist_damage)
		&"armor": loss = "Вы лишитесь %s брони. Полученный урон будет снижать здоровье." % number(victim.def().stat("armor"))
		&"helmet": loss = "Окно крита после обычной атаки врага исчезнет. Эффекты открытия для крита продолжат работать."
		&"amulet": loss = "Отдельная волна на E больше недоступна."
		&"boots": loss = "Отдельный рывок на Пробел больше недоступен."
		&"gloves": loss = "Отдельный захват на Q больше недоступен."
		&"shield": loss = "Блок на ПКМ больше недоступен."
	if victim.appearance > 1:
		loss += "\nОсобый эффект облика жертвы также исчезнет."
	var gain := "%s: %s." % [trigger(prop.listen_event), effect(prop, after)]
	for entry in PropertyTree.walk(victim):
		var p: Property = entry["property"]
		gain += "\n• Перейдёт «%s»: %s — %s." % [p.display_name(), trigger(p.listen_event).to_lower(), effect(p, after)]
	var keep := "Сохраняется %s." % action_name(recipient)
	if recipient.appearance > 1:
		keep += " Облик «%s» сохраняется." % Mastery.form(recipient.def_id, recipient.appearance)["name"]
	if not recipient.properties.is_empty():
		keep += "\nПрежние свойства: %s." % ", ".join(recipient.property_names())
	var stat_name := "Бонус к урону действия и свойств"
	var before := "+%s%%" % number((ActionContext.item_mult(recipient) - 1.0) * 100.0)
	var result := "+%s%%" % number((ActionContext.item_mult(after) - 1.0) * 100.0)
	if recipient.def_id == &"sword":
		stat_name = "Урон комбо"
		before = _combo(recipient)
		result = _combo(after)
	elif recipient.def().stats.has("damage"):
		stat_name = "Урон захвата" if recipient.def_id == &"gloves" else "Урон волны"
		before = number(recipient.def().stat("damage") * ActionContext.item_mult(recipient))
		result = number(after.def().stat("damage") * ActionContext.item_mult(after))
	var details := PackedStringArray()
	details.append("После жертвы: %s" % action_summary(after))
	details.append("\nЦепочка свойств:")
	for entry in PropertyTree.walk(after):
		var p: Property = entry["property"]
		details.append("%s• %s → %s. Откат: %s с." % ["    ".repeat(entry["depth"]), trigger(p.listen_event), effect(p, after), number(p.cooldown)])
	details.append("\nПереносится сила вещи и её свойства. Родное действие и эффект облика жертвы не переносятся.")
	return {
		"victim": victim, "recipient": recipient, "after": after,
		"now": now, "loss": loss, "gain": gain, "keep": keep,
		"stat_name": stat_name, "before": before, "result": result,
		"note": "Свойства: %d → %d. Бонус к урону: +%s%% → +%s%%." % [recipient.properties.size(), after.properties.size(), number((ActionContext.item_mult(recipient) - 1.0) * 100.0), number((ActionContext.item_mult(after) - 1.0) * 100.0)],
		"details": "\n".join(details),
	}
