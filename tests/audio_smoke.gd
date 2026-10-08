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

func loop_channels_playing(room_id: String) -> void:
	expect(game.audio.music_player.playing and game.audio.music_player.stream.data == game.audio.streams["music_" + room_id].data, room_id + " uses its own playing music stream")
	expect(game.audio.ambience_player.playing and game.audio.ambience_player.stream.data == game.audio.streams["ambience_" + room_id].data, room_id + " uses its own playing ambience stream")
	expect(game.audio.music_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and game.audio.music_player.stream.loop_end > 0, room_id + " music player loops its whole WAV")
	expect(game.audio.ambience_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and game.audio.ambience_player.stream.loop_end > 0, room_id + " ambience player loops its whole WAV")
	var loop_players := 0
	for child in game.audio.get_children():
		if child is AudioStreamPlayer and child.stream is AudioStreamWAV and child.playing and child.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			loop_players += 1
	expect(loop_players == 2, room_id + " has exactly one music and one ambience player without overlapping old room loops")

func check_assets() -> void:
	var expected_assets := 20 if game.audio.streams.has("intro_theme") else 19
	expect(game.audio.streams.size() == expected_assets, "All six room loops and thirteen original effects load, plus the optional intro when provided")
	for stream_name in game.audio.streams:
		var stream = game.audio.streams[stream_name]
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
	expect(game.flag("complete") and count_event("complete") == completion + 1, "Completing the actual chapter plays one ending cue")
	act("shuttle")
	expect(count_event("complete") == completion + 1, "Completed chapter cannot replay the ending cue")
	var saves := count_event("save")
	var loads := count_event("load")
	expect(game.save_game() and count_event("save") == saves + 1, "Successful checkpoint saving plays its confirmation cue")
	game.new_game(false)
	expect(game.load_game() and count_event("load") == loads + 1, "Successful checkpoint loading plays its confirmation cue")
	expect(count_event("complete") == completion + 1, "Restoring a completed save does not replay the ending cue")

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

func check_optional_intro() -> void:
	var fixture_dir := "user://audio_intro_fixture"
	var fixture_path := fixture_dir + "/intro_theme.wav"
	DirAccess.make_dir_recursive_absolute(fixture_dir)
	game.audio.custom_dir = fixture_dir
	game.audio.reload_assets()
	var intro_count := count_event("intro_theme")
	game.new_game(true)
	expect(not game.audio.intro_active and count_event("intro_theme") == intro_count, "Without an intro recording, new-game dialogue keeps the normal room score")
	loop_channels_playing("diner")
	game.close_dialogue()
	# This is an original test tone, kept outside the project. It is not the
	# requested song and is removed before the test finishes.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var pcm := PackedByteArray()
	pcm.resize(11025 * 2)
	for index in range(11025):
		pcm.encode_s16(index * 2, int(sin(index * 2.0 * PI * 660.0 / 22050.0) * 4500.0))
	wav.data = pcm
	expect(wav.save_to_wav(fixture_path) == OK, "Isolated synthetic intro fixture can be written")
	game.audio.reload_assets()
	expect(game.audio.source_paths.get("intro_theme", "") == fixture_path, "Optional intro recording loads from the configured local audio directory")
	game.new_game(true)
	expect(game.audio.intro_active and count_event("intro_theme") == intro_count + 1, "New-game opening dialogue starts the optional intro once")
	expect(game.audio.music_player.playing and game.audio.music_player.stream.data == game.audio.streams["intro_theme"].data, "The music player plays the actual optional intro WAV")
	expect(game.audio.music_player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Optional intro is a one-shot rather than a repeating room loop")
	expect(game.audio.music_player.bus == game.audio.CHANNEL_BUSES["music"], "Optional intro uses the existing music volume channel")
	expect(game.audio.ambience_player.playing and game.audio.ambience_player.stream.data == game.audio.streams["ambience_diner"].data, "Intro playback preserves the current room ambience")
	await create_timer(0.75).timeout
	expect(not game.audio.intro_active and game.dialogue_panel.visible, "Natural intro completion returns the score while leaving opening dialogue readable")
	loop_channels_playing("diner")
	game.new_game(true)
	await press_key(KEY_SPACE)
	expect(game.audio.intro_active and game.dialogue_panel.visible, "Advancing the first opening line keeps its intro playing")
	await press_key(KEY_SPACE)
	expect(not game.audio.intro_active and not game.dialogue_panel.visible, "Dismissing the last opening line restores normal room music")
	loop_channels_playing("diner")
	game.new_game(true)
	await press_key(KEY_ESCAPE)
	expect(not game.audio.intro_active and not game.dialogue_panel.visible, "Escape skips the intro with the opening dialogue")
	game.new_game(true)
	game.close_dialogue()
	expect(not game.audio.intro_active and game.audio.music_player.stream.data == game.audio.streams["music_diner"].data, "Explicit dialogue dismissal also restores the room score")
	game.new_game(true)
	game.enter_room("dock")
	expect(not game.audio.intro_active, "Entering another room cancels the intro")
	loop_channels_playing("dock")
	game.new_game(false)
	expect(game.save_game(), "Intro cancellation checkpoint can be saved")
	game.new_game(true)
	expect(game.audio.intro_active and game.load_game() and not game.audio.intro_active, "Loading the same room cancels an active intro")
	loop_channels_playing("diner")
	game.new_game(true)
	game.audio.set_volume("music", 0.23, false)
	var music_bus := AudioServer.get_bus_index(game.audio.CHANNEL_BUSES["music"])
	expect(game.audio.intro_active and is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.23)), "Changing music volume adjusts the intro's actual audio bus")
	game.audio.set_muted(true, false)
	expect(game.audio.intro_active and AudioServer.is_bus_mute(music_bus), "Mute silences the optional intro through the existing music bus")
	game.audio.set_muted(false, false)
	game.new_game(false)
	expect(not game.audio.intro_active, "Starting without opening dialogue never starts the optional intro")
	game.audio.set_volumes(0.35, 0.65, 0.2)
	DirAccess.remove_absolute(fixture_path)
	game.audio.custom_dir = game.audio.CUSTOM_DIR
	game.audio.reload_assets()
	DirAccess.remove_absolute(fixture_dir)
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
	var room_starts := int(game.audio.room_start_counts.get("museum", 0))
	game.audio.set_room("museum")
	expect(int(game.audio.room_start_counts.get("museum", 0)) == room_starts, "Reapplying the same room does not restart its music or ambience")
	check_movement()
	check_puzzle_events()
	await check_settings()
	check_custom_override()
	await check_panel_input()
	await check_optional_intro()
	AudioServer.remove_bus_effect(0, capture_effect_index)
	game.queue_free()
	# AudioServer releases stopped WAV playback on the next mixer update. Give
	# the Dummy driver time to drain before terminating the integration harness.
	await create_timer(0.15).timeout
	if failures == 0:
		print("PASS: %d audio checks — decoded assets, room loops, mixer output/mute, footsteps, puzzle cues, local overrides, persisted options, modal input, optional intro lifecycle" % checks)
	else:
		push_error("%d of %d audio checks failed" % [failures, checks])
	quit(0 if failures == 0 else 1)
