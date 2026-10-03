extends GutTest
## Музыка «на плёнке»: у алтаря битву зажёвывает, после алтаря она возвращается; битва — случайный плейлист.


func after_each() -> void:
	Audio.stop_music(0.0)


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


func test_battle_playlist_starts_a_random_track_and_keeps_it_across_stages() -> void:
	Audio.play_music(&"music_menu", 0.0)
	Audio.play_playlist(Game.BATTLE_MUSIC)
	var first: StringName = Audio._music_current
	assert_has(Game.BATTLE_MUSIC, first)
	Audio.play_playlist(Game.BATTLE_MUSIC)
	assert_eq(Audio._music_current, first, "следующий этап не меняет трек")


func test_battle_playlist_resumes_after_the_altar() -> void:
	Audio.play_music(&"music_menu", 0.0)
	Audio.play_playlist(Game.BATTLE_MUSIC)
	var first: StringName = Audio._music_current
	Audio.tape_switch(&"music_altar")
	Audio.play_playlist(Game.BATTLE_MUSIC)
	assert_eq(Audio._music_current, first, "после алтаря продолжается тот же трек")
	assert_false(Audio.tape_held())


func test_finished_battle_track_gives_way_to_another() -> void:
	Audio.play_music(&"music_menu", 0.0)
	Audio.play_playlist(Game.BATTLE_MUSIC)
	var seen := {}
	for i in 8:
		var before: StringName = Audio._music_current
		seen[before] = true
		Audio._on_music_finished(Audio._music_active)
		assert_ne(Audio._music_current, before, "трек не повторяется подряд")
		assert_has(Game.BATTLE_MUSIC, Audio._music_current)
	assert_eq(seen.size(), Game.BATTLE_MUSIC.size(), "за два круга прозвучали все треки")


func test_only_playlist_tracks_stop_at_the_end() -> void:
	Audio.play_playlist(Game.BATTLE_MUSIC)
	assert_false((Audio._stream(Audio._music_current) as AudioStreamMP3).loop, "трек битвы доигрывает до конца")
	Audio.play_music(&"music_boss", 0.0)
	assert_true((Audio._stream(&"music_boss") as AudioStreamMP3).loop, "босс зациклен")
