extends SceneTree

# Run with an isolated XDG_DATA_HOME. The test writes the normal settings/save
# files and its override fixture into that isolated application-data directory.
var game
var failures := 0
var checks := 0
var capture: AudioEffectCapture
var capture_effect_index := -1

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func count_event(event_name: String) -> int:
	return int(game.audio.event_counts.get(event_name, 0))

func act(target: String, action := "Use", item := "") -> void:
	game.close_dialogue()
	game.perform_action(target, action, item)
	game.close_dialogue()

func click(point: Vector2, mouse_button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = mouse_button
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame

func click_control(control: Control) -> void:
	await click(control.get_global_transform_with_canvas() * (control.size / 2.0))

func press_key(keycode: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func mixed_energy(seconds := 0.35) -> float:
	capture.clear_buffer()
	await create_timer(seconds).timeout
	var frame_count := capture.get_frames_available()
	expect(frame_count > 0, "Dummy audio driver produces mixed PCM frames for capture")
	var energy := 0.0
	if frame_count > 0:
		for frame in capture.get_buffer(frame_count):
			energy += frame.length_squared()
	return energy

func loop_channels_playing(room_id: String, theme := "") -> void:
	var score_id := room_id if theme.is_empty() else theme
	expect(game.audio.music_player.playing and game.audio.music_player.stream.data == game.audio.streams["music_" + score_id].data, room_id + " uses its assigned playing music stream")
	expect(game.audio.ambience_player.playing and game.audio.ambience_player.stream.data == game.audio.streams["ambience_" + score_id].data, room_id + " uses its assigned playing ambience stream")
	expect(game.audio.music_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and game.audio.music_player.stream.loop_end > 0, room_id + " music player loops its whole WAV")
	expect(game.audio.ambience_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and game.audio.ambience_player.stream.loop_end > 0, room_id + " ambience player loops its whole WAV")
	var loop_players := 0
	for child in game.audio.get_children():
		if child is AudioStreamPlayer and child.stream is AudioStreamWAV and child.playing and child.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			loop_players += 1
	expect(loop_players == 2, room_id + " has exactly one music and one ambience player without overlapping old room loops")

func check_assets() -> void:
	var expected_assets := 33 + int(game.audio.streams.has("intro_theme")) + int(game.audio.streams.has("intro_fanfare"))
	expect(game.audio.streams.size() == expected_assets, "All twenty regional loops and thirteen original effects load, plus supplied title cues")
	for stream_name in game.audio.streams:
		var stream = game.audio.streams[stream_name]
		if stream is AudioStreamOggVorbis:
			expect(stream is AudioStreamOggVorbis, str(stream_name) + " decodes as an Ogg Vorbis audio stream")
			expect(stream.get_length() > 0.0, str(stream_name) + " has a positive decoded duration")
			var playback: AudioStreamPlayback = stream.instantiate_playback()
			playback.start(2.0)
			var energy := 0.0
			for frame in playback.mix_audio(1.0, 4096):
				energy += frame.length_squared()
			playback.stop()
			expect(energy > 0.000001, str(stream_name) + " decodes to nonzero PCM samples")
			expect(not stream.loop, str(stream_name) + " is a one-shot recording")
			continue
		expect(stream is AudioStreamWAV, str(stream_name) + " decodes as a WAV audio stream")
		if not stream is AudioStreamWAV:
			continue
		expect(stream.data.size() > 0 and stream.get_length() > 0.0, str(stream_name) + " has nonempty decoded PCM and a positive duration")
		var nonzero := false
		for index in range(0, stream.data.size(), 13):
			if stream.data[index] != 0:
				nonzero = true
				break
		expect(nonzero, str(stream_name) + " contains nonzero sample data")
		if str(stream_name).begins_with("music_") or str(stream_name).begins_with("ambience_"):
			expect(stream.get_length() >= 8.0, str(stream_name) + " provides a full room loop rather than a short effect")
		else:
			expect(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, str(stream_name) + " plays as a one-shot effect")

func check_campaign_scores() -> void:
	var regional_rooms := {"labion_dock": "labion", "plexi_gallery": "plexi", "starcon_class": "starcon", "polysorbate_market": "polysorbate", "glitzon_vault": "glitzon", "clone_chamber": "finale"}
	var previous_music: PackedByteArray = game.audio.music_player.stream.data
	for room_id in regional_rooms:
		game.enter_room(room_id)
		loop_channels_playing(room_id, regional_rooms[room_id])
		expect(game.audio.current_room == room_id, "Audio remembers the actual campaign location rather than replacing it with the score theme")
		expect(game.audio.music_player.stream.data != previous_music, "Each new story region replaces the preceding region's music with a distinct score")
		previous_music = game.audio.music_player.stream.data
		var starts := int(game.audio.room_start_counts.get(room_id, 0))
		game.audio.set_room(room_id)
		expect(int(game.audio.room_start_counts.get(room_id, 0)) == starts, "Same-room campaign audio requests cannot restart or stack the region's loops")
	expect(await mixed_energy() > 0.000001, "The final campaign region produces actual nonzero PCM through Godot's mixer")
	for room_id in ["monolith_berth", "monolith_kitchen", "monolith_freezer", "monolith_arcade"]:
		game.enter_room(room_id)
		loop_channels_playing(room_id, "monolith")

func check_movement() -> void:
	game.new_game(false)
	game.player = Vector2(173, 280)
	game.destination = Vector2(300, 280)
	var start_a := count_event("step_a")
	var start_b := count_event("step_b")
	for frame in range(55):
		game._process(1.0 / 60.0)
	var steps_a := count_event("step_a") - start_a
	var steps_b := count_event("step_b") - start_b
	expect(steps_a > 0 and steps_b > 0 and absi(steps_a - steps_b) <= 1, "Walking alternates the two footstep sounds")
	game.destination = game.player
	var stopped_count := count_event("step_a") + count_event("step_b")
	for frame in range(90):
		game._process(1.0 / 60.0)
	expect(count_event("step_a") + count_event("step_b") == stopped_count, "Idle Roger emits no footsteps")
	game.destination = Vector2(450, 280)
	game.show_dialog("roger", ["Audio validation pauses walking during dialogue."])
	var paused_position: Vector2 = game.player
	for frame in range(90):
		game._process(1.0 / 60.0)
	expect(game.player == paused_position and count_event("step_a") + count_event("step_b") == stopped_count, "Dialogue pauses movement and footsteps")
	game.close_dialogue()
	game.destination = game.player

func check_puzzle_events() -> void:
	game.new_game(false)
	var pickups := count_event("pickup")
	act("grease")
	expect(count_event("pickup") == pickups, "Blocked pickup does not play a success pickup sound")
	act("cook", "Talk")
	expect(count_event("pickup") == pickups + 1, "Receiving the service chit plays one pickup")
	act("cook", "Talk")
	expect(count_event("pickup") == pickups + 1, "Repeated service-chit conversation does not repeat pickup audio")
	act("grease")
	expect(count_event("pickup") == pickups + 2, "Collecting the grease plays one pickup")
	act("grease")
	expect(count_event("pickup") == pickups + 2, "Repeated grease collection does not repeat pickup audio")
	var successes := count_event("success")
	act("panel", "Use", "grease")
	expect(count_event("success") == successes + 1, "Repairing the hatch plays its puzzle-success cue")
	act("panel", "Use", "grease")
	expect(count_event("success") == successes + 1, "Repeated hatch action does not repeat the success cue")
	var doors := count_event("door")
	act("exit")
	expect(game.state["room"] == "dock" and count_event("door") == doors + 1, "Actual room travel plays one door cue")
	act("guard", "Use", "service chit")
	expect(count_event("pickup") == pickups + 3, "Receiving the guard's access items plays one pickup cue for the trade")
	var locker_doors := count_event("door")
	act("locker", "Use", "keycard")
	expect(count_event("door") == locker_doors + 1, "Unlocking the maintenance locker plays its door cue once")
	act("locker", "Use", "keycard")
	expect(count_event("door") == locker_doors + 1, "Repeated open-locker interaction does not replay its door cue")
	act("mop")
	expect(count_event("pickup") == pickups + 5, "Collecting the cleaner and unlocked mop plays their pickup cues")
	var terminals := count_event("terminal")
	act("terminal", "Use", "keycard")
	expect(count_event("terminal") == terminals + 1, "First successful terminal authorization plays its cue")
	act("terminal", "Use", "keycard")
	expect(count_event("terminal") == terminals + 1, "Repeated authorization does not repeat puzzle audio")
	act("museum")
	expect(game.state["room"] == "museum" and count_event("door") == doors + 3, "Museum travel plays one door cue after the locker was opened")
	var combinations := count_event("combine")
	expect(game.combine_items("cleaner", "mop"), "The real inventory puzzle combines cleaner and mop")
	game.close_dialogue()
	expect(count_event("combine") == combinations + 1, "Successful inventory combination plays its cue once")
	expect(not game.combine_items("cleaner", "mop") and count_event("combine") == combinations + 1, "Consumed ingredients cannot replay the combination cue")
	act("guardian", "Use", "maintenance pass")
	expect(count_event("terminal") == terminals + 2, "Guardian maintenance authorization plays its terminal cue")
	act("guardian", "Use", "maintenance pass")
	expect(count_event("terminal") == terminals + 2, "Repeated guardian authorization does not replay the cue")
	act("spill", "Use", "charged mop")
	expect(count_event("success") == successes + 2, "Cleaning the coolant plays one puzzle-success cue")
	act("spill", "Use", "charged mop")
	expect(count_event("success") == successes + 2, "Repeated cleaned-floor interaction does not replay its cue")
	act("plinth")
	expect(count_event("pickup") == pickups + 6, "Star map collection adds a pickup cue; combination uses its own sound")
	act("plinth")
	expect(count_event("pickup") == pickups + 6, "Repeated map interaction does not duplicate the pickup cue")
	act("exit")
	act("terminal", "Use", "star map")
	expect(count_event("terminal") == terminals + 3, "Programming the courier plays one terminal cue")
	var completion := count_event("complete")
	act("shuttle")
	game.choose_destination("labion")
	game.finish_flight()
	expect(game.flag("chapter_one_complete") and not game.flag("complete") and game.state["room"] == "labion_dock" and count_event("complete") == completion, "The opening flight reaches playable Labion without playing the full-campaign ending cue")
	act("shuttle")
	expect(count_event("complete") == completion, "A repeated old shuttle target cannot play a campaign ending cue")
	var saves := count_event("save")
	var loads := count_event("load")
	expect(game.save_game() and count_event("save") == saves + 1, "Successful checkpoint saving plays its confirmation cue")
	game.new_game(false)
	expect(game.load_game() and count_event("load") == loads + 1, "Successful checkpoint loading plays its confirmation cue")
	expect(count_event("complete") == completion and game.flag("chapter_one_complete") and not game.finale_panel.visible, "Restoring an opening-complete save keeps the campaign playable without an ending cue")

func check_settings() -> void:
	game.audio.set_volumes(0.42, 0.31, 0.17)
	game.audio.set_muted(true)
	var reloaded = load("res://scripts/audio.gd").new()
	root.add_child(reloaded)
	await process_frame
	expect(is_equal_approx(float(reloaded.settings["music"]), 0.42) and is_equal_approx(float(reloaded.settings["effects"]), 0.31) and is_equal_approx(float(reloaded.settings["ambience"]), 0.17), "Music, effects, and ambience volumes persist across controller startup")
	expect(bool(reloaded.settings["muted"]), "Mute preference persists across controller startup")
	reloaded.queue_free()
	await process_frame
	game.audio.apply_audio_settings()
	# Let any samples mixed just before muting leave the capture buffer.
	await create_timer(0.1).timeout
	expect(await mixed_energy() < 0.000001, "Muted buses produce silent mixed PCM")
	var pickup_count := count_event("pickup")
	expect(not game.audio.play_sfx("pickup") and count_event("pickup") == pickup_count, "Muted sound requests do not start effect playback")
	game.audio.set_muted(false)
	expect(await mixed_energy() > 0.000001, "Unmuting restores nonzero room audio")
	game.audio.set_volume("effects", 0.0, false)
	expect(not game.audio.play_sfx("pickup") and count_event("pickup") == pickup_count, "Zero effects volume suppresses new effect playback")
	game.audio.set_volumes(0.0, 0.65, 0.0, false)
	await create_timer(0.1).timeout
	expect(game.audio.play_sfx("pickup"), "An unmuted pickup starts an actual effect voice")
	var active_pickup := false
	for player in game.audio.effect_players:
		active_pickup = active_pickup or (player.playing and player.stream == game.audio.streams["pickup"])
	expect(active_pickup, "Effect pool contains the playing pickup WAV")
	expect(await mixed_energy() > 0.000001, "Effects alone produce nonzero PCM with music and ambience muted")
	game.audio.set_volumes(0.35, 0.65, 0.2)

func check_custom_override() -> void:
	var fixture_dir := "user://audio_override_fixture"
	DirAccess.make_dir_recursive_absolute(fixture_dir)
	var fixture_path := fixture_dir + "/pickup.wav"
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var pcm := PackedByteArray()
	pcm.resize(2205 * 2)
	for index in range(2205):
		pcm.encode_s16(index * 2, int(sin(index * 2.0 * PI * 500.0 / 22050.0) * 6000.0))
	wav.data = pcm
	expect(wav.save_to_wav(fixture_path) == OK, "Isolated original WAV override fixture is written")
	var bundled_pickup_path: String = game.audio.source_paths["pickup"]
	game.audio.custom_dir = fixture_dir
	game.audio.reload_assets()
	expect(game.audio.source_paths["pickup"] == fixture_path and is_equal_approx(game.audio.streams["pickup"].get_length(), 0.1), "Valid local WAV override replaces its matching bundled sound")
	expect(game.audio.source_paths["music_diner"].begins_with("res://assets/audio/") and not game.audio.source_paths["music_diner"].contains("/custom/"), "Unprovided override sounds keep their bundled fallback")
	DirAccess.remove_absolute(fixture_path)
	game.audio.reload_assets()
	expect(game.audio.source_paths["pickup"] == bundled_pickup_path, "Removing an override restores the bundled original effect")
	game.audio.custom_dir = game.audio.CUSTOM_DIR
	game.audio.reload_assets()
	DirAccess.remove_absolute(fixture_dir)

func check_panel_input() -> void:
	game.new_game(false)
	game.destination = Vector2(350, 280)
	await press_key(KEY_M)
	var position_before: Vector2 = game.player
	var destination_before: Vector2 = game.destination
	var steps_before := count_event("step_a") + count_event("step_b")
	for frame in range(60):
		game._process(1.0 / 60.0)
	expect(game.sound_panel.visible and game.player == position_before and count_event("step_a") + count_event("step_b") == steps_before, "Sound options pause walking and footsteps")
	await click(Vector2(50, 290))
	expect(game.player == position_before and game.destination == destination_before and game.pending_interaction.is_empty(), "Clicking outside sound options is consumed instead of walking")
	await click_control(game.sound_mute)
	expect(bool(game.audio.settings["muted"]) == game.sound_mute.button_pressed, "Options mute control updates the controller setting")
	game.sound_sliders["music"].value = 0.25
	expect(is_equal_approx(float(game.audio.settings["music"]), 0.25), "Options music slider updates the actual channel volume")
	await press_key(KEY_ESCAPE)
	expect(not game.sound_panel.visible, "Escape closes sound options without triggering game interaction")
	game.audio.set_muted(false)
	game.audio.set_volumes(0.35, 0.65, 0.2)
	game.destination = game.player

func intro_fixture(path: String, seconds: float, frequency: float) -> void:
	# Synthetic test tones live only in the isolated application-data directory.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var sample_count := roundi(seconds * wav.mix_rate)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for index in range(sample_count):
		pcm.encode_s16(index * 2, int(sin(index * 2.0 * PI * frequency / wav.mix_rate) * 4500.0))
	wav.data = pcm
	expect(wav.save_to_wav(path) == OK, "Isolated synthetic title fixture can be written: " + path.get_file())

func check_optional_intro() -> void:
	var fixture_dir := "user://audio_intro_fixture"
	DirAccess.make_dir_recursive_absolute(fixture_dir)
	game.new_game(false)
	game.audio.custom_dir = fixture_dir
	game.audio.reload_assets()
	# Simulate both optional recordings being unavailable without touching the
	# supplied assets in the checkout or inventing replacement production music.
	for cue in ["intro_fanfare", "intro_theme"]:
		game.audio.streams.erase(cue)
		game.audio.source_paths.erase(cue)
	var intro_count := count_event("intro_theme")
	expect(not game.audio.play_intro(), "Absent title recordings leave normal room music unchanged")
	expect(not game.audio.intro_active and count_event("intro_theme") == intro_count, "Missing optional recordings do not emit title playback events")
	loop_channels_playing("diner")
	game.show_title()
	expect(game.title_is_open() and not game.audio.intro_active, "Missing recordings still leave the title menu usable")
	expect(not game.audio.music_player.playing and not game.audio.ambience_player.playing, "A title without recordings has no room music or ambience underneath")
	expect(game.start_adventure(false), "A silent title can still start a new adventure")
	game.close_dialogue()
	loop_channels_playing("diner")
	var fanfare_path := fixture_dir + "/intro_fanfare.wav"
	var theme_path := fixture_dir + "/intro_theme.wav"
	intro_fixture(fanfare_path, 0.12, 440.0)
	intro_fixture(theme_path, 0.5, 660.0)
	game.audio.reload_assets()
	expect(game.audio.source_paths.get("intro_fanfare", "") == fanfare_path and game.audio.source_paths.get("intro_theme", "") == theme_path, "Local WAV fixtures override both supplied title recordings")
	game.new_game(false)
	var fanfare_count := count_event("intro_fanfare")
	var theme_count := count_event("intro_theme")
	expect(game.audio.play_intro(), "Available title recordings begin a sequence")
	expect(game.audio.intro_active and game.audio.intro_stage == "intro_fanfare", "The fanfare starts before the main theme")
	expect(game.audio.intro_queue == ["intro_theme"], "Only the main theme remains queued after the fanfare starts")
	expect(game.audio.music_player.playing and game.audio.music_player.stream.data == game.audio.streams["intro_fanfare"].data, "Fanfare playback uses the actual loaded WAV")
	expect(game.audio.music_player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Fanfare plays once without looping")
	expect(game.audio.music_player.bus == game.audio.CHANNEL_BUSES["music"], "Title recordings use the existing music volume channel")
	await create_timer(0.25).timeout
	expect(game.audio.intro_active and game.audio.intro_stage == "intro_theme", "Natural fanfare completion advances to the main theme")
	expect(count_event("intro_fanfare") == fanfare_count + 1 and count_event("intro_theme") == theme_count + 1, "The title sequence plays each recording exactly once")
	expect(game.audio.music_player.stream.data == game.audio.streams["intro_theme"].data and game.audio.music_player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "The main theme is the loaded one-shot WAV")
	await create_timer(0.65).timeout
	expect(not game.audio.intro_active and game.audio.intro_queue.is_empty(), "Completing both short title recordings clears the sequence")
	loop_channels_playing("diner")
	game.audio.play_intro()
	game.audio.finish_intro()
	expect(not game.audio.intro_active and game.audio.intro_queue.is_empty(), "Explicit cancellation clears the current cue and remaining queue")
	loop_channels_playing("diner")
	var restored_music := count_event("music_diner")
	game.audio.finish_intro()
	expect(count_event("music_diner") == restored_music, "Repeated cancellation cannot restart or stack room music")
	game.audio.play_intro()
	game.enter_room("dock")
	expect(not game.audio.intro_active and game.audio.intro_queue.is_empty(), "Entering another room cancels every queued title recording")
	loop_channels_playing("dock")
	expect(game.save_game(), "Title cancellation checkpoint can be saved")
	game.audio.play_intro()
	expect(game.load_game() and not game.audio.intro_active and game.audio.intro_queue.is_empty(), "Loading the same room cancels the intro and restores its score")
	loop_channels_playing("dock")
	game.audio.play_intro()
	game.audio.set_volume("music", 0.23, false)
	var music_bus := AudioServer.get_bus_index(game.audio.CHANNEL_BUSES["music"])
	expect(game.audio.intro_active and is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.23)), "Changing music volume adjusts the title sequence's actual audio bus")
	game.audio.set_muted(true, false)
	expect(game.audio.intro_active and AudioServer.is_bus_mute(music_bus), "Mute silences title recordings through the existing music bus")
	game.audio.set_muted(false, false)
	game.new_game(false)
	expect(not game.audio.intro_active and not game.title_is_open(), "A test or room restart bypasses the title and its recordings")
	game.new_game(true)
	expect(not game.audio.intro_active and game.dialogue_panel.visible, "Opening story dialogue does not replay the title recordings")
	game.close_dialogue()
	expect(game.save_game(), "Same-room checkpoint can be saved before title music completes")
	game.show_title()
	expect(game.audio.intro_stage == "intro_fanfare" and not game.audio.ambience_player.playing, "Title fanfare plays without room ambience underneath")
	await create_timer(0.25).timeout
	expect(game.audio.intro_stage == "intro_theme" and not game.audio.ambience_player.playing, "The second title recording also plays without room ambience")
	await create_timer(0.65).timeout
	expect(game.title_is_open() and not game.audio.intro_active and not game.audio.music_player.playing and not game.audio.ambience_player.playing, "Natural title completion keeps the menu open with both room channels stopped")
	expect(game.start_adventure(true) and not game.title_is_open() and game.state["room"] == "diner", "Same-room Continue succeeds after both title recordings naturally finish")
	loop_channels_playing("diner")
	game.new_game(false)
	game.audio.set_volumes(0.35, 0.65, 0.2)
	DirAccess.remove_absolute(fanfare_path)
	DirAccess.remove_absolute(theme_path)
	game.audio.custom_dir = game.audio.CUSTOM_DIR
	game.audio.reload_assets()
	DirAccess.remove_absolute(fixture_dir)
	game.new_game(false)

func check_supplied_intro() -> void:
	expect(game.audio.streams.has("intro_fanfare") and game.audio.streams.has("intro_theme"), "Both user-supplied title recordings ship in this build")
	if not game.audio.streams.has("intro_fanfare") or not game.audio.streams.has("intro_theme"):
		return
	var fanfare: AudioStream = game.audio.streams["intro_fanfare"]
	var theme: AudioStream = game.audio.streams["intro_theme"]
	expect(fanfare is AudioStreamWAV and fanfare.get_length() > 18.0 and fanfare.get_length() < 20.0, "The complete supplied SQ5 fanfare is retained at its recorded duration")
	expect(theme is AudioStreamOggVorbis and theme.get_length() > 332.0 and theme.get_length() < 334.0, "The complete supplied SQ6 intro recording is retained rather than truncated")
	game.new_game(false)
	game.audio.set_volumes(0.4, 0.0, 0.0, false)
	game.audio.play_intro()
	expect(game.audio.intro_stage == "intro_fanfare" and game.audio.music_player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Actual SQ5 recording is the title sequence's first one-shot")
	game.audio.music_player.seek(2.0)
	expect(await mixed_energy() > 0.000001, "The supplied SQ5 recording produces actual nonzero mixer PCM")
	game.audio.finish_intro()
	# Isolate the real long OGG as the only queued cue, without waiting for its
	# full five-and-a-half-minute duration during an integration test.
	var saved_fanfare = game.audio.streams["intro_fanfare"]
	game.audio.streams.erase("intro_fanfare")
	game.audio.play_intro()
	expect(game.audio.intro_stage == "intro_theme" and game.audio.music_player.stream is AudioStreamOggVorbis and not game.audio.music_player.stream.loop, "Actual SQ6 recording loads as a one-shot Vorbis stream")
	game.audio.music_player.seek(3.0)
	expect(await mixed_energy() > 0.000001, "The supplied SQ6 recording decodes to actual nonzero mixer PCM")
	game.audio.finish_intro()
	game.audio.streams["intro_fanfare"] = saved_fanfare
	game.audio.set_volumes(0.35, 0.65, 0.2)

func check_title_input() -> void:
	game.new_game(false)
	if FileAccess.file_exists(game.SAVE_PATH):
		DirAccess.remove_absolute(game.SAVE_PATH)
	game.show_title()
	expect(game.title_is_open() and game.title_continue_button.disabled, "Boot title offers New Game and disables Continue when no checkpoint exists")
	var title_position: Vector2 = game.player
	game.destination = Vector2(450, 280)
	var title_destination: Vector2 = game.destination
	var step_count := count_event("step_a") + count_event("step_b")
	for frame in range(60):
		game._process(1.0 / 60.0)
	expect(game.player == title_position and count_event("step_a") + count_event("step_b") == step_count, "Title screen pauses Roger and emits no footsteps")
	await click(Vector2(10, 240))
	expect(game.title_is_open() and game.destination == title_destination and game.pending_interaction.is_empty(), "Title background clicks cannot move Roger or queue hidden world interactions")
	await press_key(KEY_3)
	expect(game.verb == "Interact", "Title blocks room action keyboard shortcuts")
	await click_control(game.title_sound_button)
	expect(game.title_is_open() and game.sound_panel.visible, "Sound options open above the title screen")
	await press_key(KEY_ENTER)
	expect(game.title_is_open() and game.sound_panel.visible, "Enter inside Sound options cannot start the hidden title action")
	await press_key(KEY_ESCAPE)
	expect(game.title_is_open() and not game.sound_panel.visible, "Escape closes Sound options while preserving the title")
	await click_control(game.title_new_button)
	expect(not game.title_is_open() and not game.audio.intro_active and game.state["room"] == "diner" and game.dialogue_panel.visible, "New Game button skips the title sequence and opens the chapter story")
	game.close_dialogue()
	loop_channels_playing("diner")
	game.show_title()
	await press_key(KEY_ENTER)
	expect(not game.title_is_open() and not game.audio.intro_active, "Enter skips the title into a new adventure")
	game.close_dialogue()
	game.show_title()
	await press_key(KEY_ESCAPE)
	expect(not game.title_is_open() and not game.audio.intro_active, "Escape skips the title into a new adventure")
	game.close_dialogue()
	game.enter_room("dock", Vector2(243, 281))
	game.state["flags"]["museum_access"] = true
	game.state["inventory"] = ["keycard"]
	expect(game.save_game(), "A dock checkpoint can be saved for title Continue")
	var saved_state: Dictionary = game.state.duplicate(true)
	game.new_game(false)
	game.show_title()
	expect(not game.title_continue_button.disabled, "Continue enables when a valid checkpoint exists")
	await click_control(game.title_continue_button)
	expect(not game.title_is_open() and not game.audio.intro_active and game.state == saved_state, "Continue skips title recordings and restores the saved room and puzzle state")
	expect(game.player == Vector2(243, 281) and game.destination == game.player, "Title Continue restores Roger's position without stale walking")
	loop_channels_playing("dock")
	var invalid_save := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	invalid_save.store_string("{}")
	invalid_save.close()
	game.show_title()
	expect(game.title_continue_button.disabled, "Continue also disables for a structurally invalid checkpoint")
	expect(not game.start_adventure(true) and game.title_is_open(), "An invalid checkpoint keeps the title visible when Continue fails")
	game.new_game(false)

func check() -> void:
	create_timer(40.0).timeout.connect(func():
		push_error("Audio integration test timed out")
		quit(1))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.new_game(false)
	game.audio.set_muted(false, false)
	game.audio.set_volumes(0.35, 0.65, 0.2, false)
	check_assets()
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	capture_effect_index = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	loop_channels_playing("diner")
	expect(await mixed_energy() > 0.000001, "Bundled room music and ambience produce nonzero PCM in the audio mixer")
	game.enter_room("dock")
	loop_channels_playing("dock")
	game.enter_room("museum")
	loop_channels_playing("museum")
	game.enter_room("monolith")
	loop_channels_playing("monolith")
	expect(await mixed_energy() > 0.000001, "Monolith Burger room music and ambience produce nonzero mixed PCM")
	game.enter_room("museum")
	var room_starts := int(game.audio.room_start_counts.get("museum", 0))
	game.audio.set_room("museum")
	expect(int(game.audio.room_start_counts.get("museum", 0)) == room_starts, "Reapplying the same room does not restart its music or ambience")
	await check_campaign_scores()
	check_movement()
	check_puzzle_events()
	await check_settings()
	check_custom_override()
	await check_panel_input()
	await check_optional_intro()
	await check_supplied_intro()
	await check_title_input()
	AudioServer.remove_bus_effect(0, capture_effect_index)
	game.queue_free()
	# AudioServer releases stopped WAV playback on the next mixer update. Give
	# the Dummy driver time to drain before terminating the integration harness.
	await create_timer(0.15).timeout
	if failures == 0:
		print("PASS: %d audio checks — decoded assets, room loops, mixer output/mute, footsteps, puzzle cues, local overrides, persisted options, modal input, supplied title music, title sequence lifecycle" % checks)
	else:
		push_error("%d of %d audio checks failed" % [failures, checks])
	quit(0 if failures == 0 else 1)
