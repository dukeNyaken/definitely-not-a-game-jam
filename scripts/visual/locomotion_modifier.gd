class_name LocomotionModifier
extends SkeletonModifier3D
## Поправка поверх анимации (работает после AnimationTree, в каждом кадре):
##
## twist — поворот таза к направлению бега, рад. Ноги бегут туда, куда движется
##   герой; позвоночник поворачивается обратно на тот же угол (веса — SPINE),
##   поэтому торс и руки остаются к цели. Так бег вбок и наискосок не выглядит
##   скольжением боком.
##
## Прижимать стопы к полу здесь не нужно: в игре щиколотка в опоре на 0.19 м при 0.17 в покое
## (tools/anim_check.gd trace=1), а прижатие в фазе полёта тянуло к полу летящую ногу.

## Доли обратного поворота по позвонкам: в сумме 1 — торс смотрит, куда смотрел.
const SPINE := {&"Spine": 0.4, &"Chest": 0.3, &"UpperChest": 0.3}

var twist := 0.0

var _hips := -1
var _spine: Dictionary = {}       # индекс кости -> доля


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_hips = sk.find_bone("Hips")
	for b in SPINE:
		var i := sk.find_bone(b)
		if i >= 0:
			_spine[i] = SPINE[b]


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _hips < 0:
		return
	if absf(twist) > 0.001:
		var hp := sk.get_bone_parent(_hips)
		var up := Vector3.UP if hp < 0 else (sk.get_bone_global_pose(hp).basis.inverse() * Vector3.UP).normalized()
		sk.set_bone_pose_rotation(_hips, Quaternion(up, twist) * sk.get_bone_pose_rotation(_hips))
		for i in _spine:
			var parent_basis := sk.get_bone_global_pose(sk.get_bone_parent(i)).basis
			var axis := (parent_basis.inverse() * Vector3.UP).normalized()
			sk.set_bone_pose_rotation(i, Quaternion(axis, -twist * _spine[i]) * sk.get_bone_pose_rotation(i))
