extends SceneTree
## Выгружает все тексты сюжета (Story) в JSON с метками: метка -> { "speaker": id, "text": строка }.
## Метки совпадают с колонкой «Метка» в таблице диалогов — по ним правки возвращаются в story.gd.
##   godot --headless --path . -s tools/export_story.gd -- out=story.json


func _init() -> void:
	_export.call_deferred()


## Story грузится после старта: его функции ссылаются на автозагрузки, которых при разборе этого скрипта ещё нет.
func _export() -> void:
	var story = load("res://scripts/story/story.gd")
	var out_path := "user://story.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_path = a.substr(4)
	var lines := {}
	for who in story.SPEAKERS:
		var sp: Dictionary = story.SPEAKERS[who]
		lines["speaker.%s.name" % who] = {"speaker": who, "text": sp["name"]}
		lines["speaker.%s.role" % who] = {"speaker": who, "text": sp.get("role", "")}
	lines["caption.light"] = {"speaker": "thought", "text": story.LIGHT_CAPTION}
	lines["caption.interlude_header"] = {"speaker": "brother", "text": story.INTERLUDE_HEADER}
	for key in story.CHAPTERS:
		lines["chapter.%s.title" % key] = {"speaker": "", "text": story.CHAPTERS[key][0]}
		lines["chapter.%s.sub" % key] = {"speaker": "", "text": story.CHAPTERS[key][1]}
	for i in story.ORDINALS.size():
		lines["ordinal.%d" % (i + 1)] = {"speaker": "", "text": story.ORDINALS[i]}
	for id in story.GENITIVE:
		lines["gen.%s" % id] = {"speaker": "", "text": story.GENITIVE[id]}
	for id in story.ITEM_NAMES:
		lines["item.%s" % id] = {"speaker": "", "text": story.ITEM_NAMES[id]}
	for id in story.GIFTS:
		var g: Dictionary = story.GIFTS[id]
		for field in ["plea", "reply", "oath", "extra", "secret", "gate", "bark", "payoff"]:
			if not g.has(field):
				continue
			var speaker: String = g["who"]
			if field == "reply":
				speaker = "hero"
			elif field in ["extra", "secret", "bark", "payoff"]:
				speaker = "thought"
			lines["gift.%s.%s" % [id, field]] = {"speaker": speaker, "text": g[field]}
	for i in story.IVA_LINES.size():
		lines["iva.%d" % (i + 1)] = {"speaker": "faithful", "text": story.IVA_LINES[i]}
	for i in story.BROTHER_LINES.size():
		lines["brother.%d" % (i + 1)] = {"speaker": "brother", "text": story.BROTHER_LINES[i]}
	lines["brother.%d.ring" % story.RING_LINE_INDEX] = {"speaker": "brother", "text": story.BROTHER_RING_LINE}
	for p in story.BROTHER_BARKS:
		lines["bark.brother.%d" % p] = {"speaker": "brother", "text": story.BROTHER_BARKS[p]}
	lines["bark.iva"] = {"speaker": "faithful", "text": story.IVA_BARK}
	for section in [["prologue", story.PROLOGUE], ["hearth", story.HEARTH], ["temptation", story.TEMPTATION],
			["gates", story.GATES], ["finale", story.FINALE]]:
		var d: Dictionary = section[1]
		for key in d:
			lines["%s.%s" % [section[0], key]] = {"speaker": "", "text": d[key]}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(lines, "\t", false))
	f.close()
	print("exported %d lines to %s" % [lines.size(), ProjectSettings.globalize_path(out_path)])
	quit()
