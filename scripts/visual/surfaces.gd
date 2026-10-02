class_name Surfaces
extends RefCounted
## Текстуры поверхностей (assets/textures, генерирует tools/gen_textures.py) и их масштаб.
## Масштаб — повторов текстуры на метр: у персонажей мельче, у мира крупнее.

const OBJECT_SCALE := {
	&"iron": 0.55, &"rust": 0.55, &"leather": 0.6, &"cloth": 0.6, &"rags": 0.45, &"skin": 0.45,
	&"bone": 0.6, &"wood": 0.5, &"flesh": 0.5, &"gold": 0.7, &"fur": 0.6, &"stone": 0.35,
	&"brick": 0.3, &"dirt": 0.3, &"blood": 1.0,
}
const WORLD_SCALE := {
	&"stone": 0.38, &"brick": 0.3, &"dirt": 0.16, &"wood": 0.35, &"iron": 0.4, &"rust": 0.4,
	&"bone": 0.5, &"blood": 0.5, &"cloth": 0.4, &"rags": 0.4,
}

static var _cache: Dictionary = {}


static func tex(key: StringName) -> Texture2D:
	if not _cache.has(key):
		_cache[key] = load("res://assets/textures/%s.png" % key)
	return _cache[key]


static func scale(key: StringName, world: bool) -> float:
	var table := WORLD_SCALE if world else OBJECT_SCALE
	return float(table.get(key, 0.4))
