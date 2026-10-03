class_name BattleSkillInfo
extends RefCounted
## Числа для инфографики: текущий облик навыка и исходная сила поглощённой сущности.

static func number(value: float) -> String:
	var rounded := snappedf(value, 0.01)
	return str(roundi(rounded)) if is_equal_approx(rounded, roundf(rounded)) else str(rounded).replace(".", ",")


static func metric(label: String, value: Variant, unit: String = "") -> Dictionary:
	return {"label": label, "value": (number(float(value)) if value is float or value is int else str(value)) + unit}


## Только эффект переданной сущности: особые эффекты облика жертвы не наследуются.
static func effect_summary(prop: Property) -> String:
	match prop.essence_id:
		&"blade": return "Разрез перед героем."
		&"bulwark": return "Неуязвимость; отражение снарядов."
		&"mass": return "Отброс и оглушение вокруг."
		&"gaze": return "Враги рядом открыты для крита."
		&"grip": return "Притягивание перед героем."
		&"gust": return "Рывок к курсору."
		&"energy": return "Сквозная волна к курсору."
	return ""


static func native(item: ItemState) -> Array[Dictionary]:
	var def := item.def()
	var s := def.stats
	var damage := ActionContext.item_mult(item)
	var result: Array[Dictionary] = []
	match item.def_id:
		&"sword":
			var combo := PackedStringArray()
			for value in s["combo"]:
				combo.append(number(value * damage))
			result = [metric("Комбо · урон", "/".join(combo)), metric("Сектор удара", s["arc"], "°"), metric("Финальный удар", s.get("finisher_arc", s["arc"]), "°"), metric("Дальность финала", s.get("finisher_range", s["range"]), " м")]
		&"shield":
			result = [metric("Блок спереди", s["arc"], "°"), metric("Скорость с щитом", (1.0 - float(s["speed_multiplier"])) * -100, "%")]
			if float(s.get("raise_reflect", 0)) > 0:
				result.append(metric("Отражение", s["raise_reflect"], " с"))
		&"armor":
			result = [metric("Броня", s["armor"]), metric("Восстановление", "После волны")]
			if s.has("retaliation_radius"):
				result.append(metric("Радиус ответа", s["retaliation_radius"], " м"))
				result.append(metric("Отброс", s["retaliation_push"], " м"))
				if s.has("retaliation_stun"):
					result.append(metric("Оглушение", s["retaliation_stun"], " с"))
				result.append(metric("Откат ответа", s["retaliation_cooldown"], " с"))
		&"helmet":
			result = [metric("Крит", "×" + number(s["crit_multiplier"])), metric("Окно после атаки", s["window"], " с")]
			if s.has("crit_open"):
				result.append(metric("Открытие критом", s["crit_open"], " с"))
				result.append(metric("Радиус открытия", s["crit_open_radius"], " м") if s.has("crit_open_radius") else metric("Открывает", "Одну цель"))
		&"boots":
			result = [metric("Рывок", s["distance"], " м"), metric("Откат", s["cooldown"], " с")]
			if s.has("dash_guard"):
				result.append(metric("Неуязвимость", s["dash_guard"], " с"))
		&"gloves":
			result = [metric("Урон", float(s["damage"]) * damage), metric("Дальность", s["range"], " м"), metric("Сектор", s["arc"], "°"), metric("Откат", s["cooldown"], " с"), metric("Оглушение", s["stun"], " с")]
			if s.has("grab_open"):
				result.append(metric("Открытие для крита", s["grab_open"], " с"))
		&"amulet":
			result = [metric("Урон", float(s["damage"]) * damage), metric("Радиус", s["radius"], " м"), metric("Отброс", s.get("wave_push", 1), " м"), metric("Откат", s["cooldown"], " с")]
			if s.has("wave_stun"):
				result.append(metric("Оглушение", s["wave_stun"], " с"))
	return result


static func effect(prop: Property, host: ItemState) -> Array[Dictionary]:
	var essence := Db.essence(prop.essence_id)
	var s := essence.stats
	var damage := ActionContext.item_mult(host)
	var result: Array[Dictionary] = []
	match prop.essence_id:
		&"blade":
			result = [metric("Урон", float(s["damage"]) * damage), metric("Сектор разреза", s["arc"], "°"), metric("Радиус", s["radius"], " м")]
		&"bulwark":
			result = [metric("Неуязвимость", s["duration"], " с"), metric("Снаряды", "Отражает")]
		&"mass":
			result = [metric("Урон", float(s["damage"]) * damage), metric("Радиус", s["radius"], " м"), metric("Отброс", s["push"], " м"), metric("Оглушение", s["stun"], " с")]
		&"gaze":
			result = [metric("Радиус", s["radius"], " м"), metric("Открытие для крита", s["duration"], " с")]
		&"grip":
			result = [metric("Дальность", s["range"], " м"), metric("Сектор", s["arc"], "°"), metric("Притягивание", "К герою")]
		&"gust":
			result = [metric("Рывок к курсору", s["distance"], " м"), metric("Длительность", s["duration"], " с")]
		&"energy":
			result = [metric("Урон", float(s["damage"]) * damage), metric("Дальность", s["range"], " м"), metric("Волна", "Сквозная")]
	result.append(metric("Откат свойства", prop.cooldown, " с"))
	return result
