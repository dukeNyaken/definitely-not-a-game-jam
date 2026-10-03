extends GutTest
## Музыка «на плёнке»: у алтаря битву зажёвывает, после алтаря она возвращается.


func after_each() -> void:
	Audio.stop_music(0.0)


func test_battle_tracks_follow_the_stages() -> void:
	assert_eq(Game.battle_music(1), &"music_battle_1")
	assert_eq(Game.battle_music(2), &"music_battle_1")
	assert_eq(Game.battle_music(3), &"music_battle_2")
	assert_eq(Game.battle_music(4), &"music_battle_3")
	assert_eq(Game.battle_music(5), &"music_battle_4")
	assert_eq(Game.battle_music(6), &"music_battle_4")
	assert_eq(Game.battle_music(99), &"music_battle_4", "за пределами этапов — последний трек")


func test_every_music_track_exists() -> void:
	for track in [&"music_menu", &"music_boss", &"music_altar", &"music_calm", &"music_battle_1",
			&"music_battle_2", &"music_battle_3", &"music_battle_4", &"tape_stop", &"tape_start"]:
		assert_not_null(Audio._stream(track), "нет файла %s" % track)


func test_altar_holds_the_battle_track_and_gives_it_back() -> void:
	Audio.play_music(&"music_battle_1", 0.0)
	assert_false(Audio.tape_held())
	Audio.tape_switch(&"music_altar")
	assert_true(Audio.tape_held(), "битву зажевало")
	assert_eq(Audio._music_current, &"music_altar")
	Audio.tape_switch(&"music_altar")
	assert_true(Audio.tape_held(), "повторный шаг на алтарь ничего не меняет")
	Audio.tape_resume()
	assert_false(Audio.tape_held())
	assert_eq(Audio._music_current, &"music_battle_1", "вернулся тот же трек битвы")


func test_next_stage_can_resume_with_its_own_track() -> void:
	Audio.play_music(&"music_battle_1", 0.0)
	Audio.tape_switch(&"music_altar")
	Audio.tape_resume(&"music_battle_2")
	assert_eq(Audio._music_current, &"music_battle_2")
	assert_false(Audio.tape_held())


func test_plain_switch_forgets_the_held_track() -> void:
	Audio.play_music(&"music_battle_1", 0.0)
	Audio.tape_switch(&"music_altar")
	Audio.play_music(&"music_boss", 0.0)
	assert_false(Audio.tape_held(), "босс начинается заново, без возврата плёнки")
	Audio.tape_resume()
	assert_eq(Audio._music_current, &"music_boss")
