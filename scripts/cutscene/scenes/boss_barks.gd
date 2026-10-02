class_name BossBarks
extends RefCounted
## Реплики в бою с Тираном: игра не останавливается. При смене фазы Сигвард срывается на крик,
## а Солдат узнаёт сброшенную вещь — он знает её слабое место. В третьей фазе Ильва кричит «держись».


static func play(cs: Cutscene, phase: int) -> void:
	if Story.BROTHER_BARKS.has(phase):
		cs.bark(&"brother", Story.BROTHER_BARKS[phase], 2.6)
	if phase == 2:
		cs.bark(&"faithful", Story.IVA_BARK, 2.2)
	var dropped := Story.phase_dropped(phase, RunState.snapshots)
	if not dropped.is_empty():
		cs.bark(&"thought", Story.gift(dropped[0].def_id).get("bark", ""), 2.6)
