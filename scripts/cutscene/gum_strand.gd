class_name GumStrand
extends Node3D
## Жвачка из кармана Сигварда. У сгенерированной модели босса ткань штанов привязана к кистям:
## стоит поднять руку — за ней от бедра тянется нить. Там, где это заметнее всего (PalaceScene),
## изъян обыгран: нить стала розовой жвачкой, и Сигвард говорит о ней сам.
## Тянется от кармана (from) к кисти (to), провисает, пока рука близко, и лопается по snap().

const PINK := Color(1.0, 0.45, 0.68)
## Ближе этого рука «в кармане» — жвачки не видно.
const MIN_LENGTH := 0.28
const THICK := 0.045
const THIN := 0.018

var from: Node3D
var to: Node3D
var _parts: Array[MeshInstance3D] = []
var _wad: MeshInstance3D
var _gone: bool = false


static func stretch(world: Node3D, p_from: Node3D, p_to: Node3D) -> GumStrand:
	var g := GumStrand.new()
	g.name = "GumStrand"
	g.from = p_from
	g.to = p_to
	world.add_child(g)
	return g


func _ready() -> void:
	for i in 2:
		var seg := LowPoly.box(Vector3.ONE, PINK, Vector3.ZERO, 0.5, 0.0, 0.9)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(seg)
		_parts.append(seg)
	_wad = LowPoly.sphere(0.06, 6, 4, PINK, Vector3.ZERO, 0.5, 0.0, 0.9)
	add_child(_wad)
	_update()


func _process(_delta: float) -> void:
	_update()


## Видна ли нить сейчас: рука достаточно далеко от кармана и жвачка ещё не лопнула.
func stretched() -> bool:
	return not _gone and is_instance_valid(from) and is_instance_valid(to) \
			and from.global_position.distance_to(to.global_position) > MIN_LENGTH


func _update() -> void:
	visible = stretched()
	if not visible:
		return
	var a := from.global_position
	var b := to.global_position
	# Чем сильнее натянута, тем тоньше и прямее.
	var slack := clampf(1.0 - (a.distance_to(b) - MIN_LENGTH) / 0.6, 0.0, 1.0)
	var mid := (a + b) * 0.5 + Vector3.DOWN * 0.14 * slack
	var width := lerpf(THIN, THICK, slack)
	_span(_parts[0], a, mid, width)
	_span(_parts[1], mid, b, width)
	_wad.global_position = b


## Растягивает единичный куб в брусок от a до b.
func _span(seg: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	var d := b - a
	var length := d.length()
	seg.visible = length > 0.001
	if not seg.visible:
		return
	var z := d / length
	var x := (Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).cross(z).normalized()
	var y := z.cross(x)
	seg.global_transform = Transform3D(Basis(x * width, y * width, z * length), (a + b) * 0.5)


## Жвачка лопается: розовые брызги и чмок.
func snap() -> void:
	if stretched():
		var mid := (from.global_position + to.global_position) * 0.5
		CutsceneFx.sparks(get_parent() as Node3D, mid, PINK, 12, 1.8)
		Audio.play(&"slime_squish", -6.0)
	_gone = true
	visible = false
