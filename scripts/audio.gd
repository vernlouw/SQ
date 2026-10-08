extends Node
## Original score and effects; optional local recordings can replace each cue.
## Preferences live separately from chapter checkpoints.

const SETTINGS_PATH := "user://audio_settings.cfg"
const CUSTOM_DIR := "res://assets/audio/custom"
const CHANNEL_BUSES := {"music": "SQMusic", "effects": "SQEffects", "ambience": "SQAmbience"}
const DEFAULT_SETTINGS := {"music": 0.35, "effects": 0.65, "ambience": 0.20, "muted": false}
const ROOMS := ["diner", "dock", "museum", "monolith"]
const EFFECTS := ["ui_click", "pickup", "door", "terminal", "combine", "success", "blocked", "save", "load", "complete", "dialogue", "step_a", "step_b"]
const STEP_INTERVAL := 0.28
const EFFECT_PLAYER_COUNT := 8

var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var streams: Dictionary = {}
var source_paths: Dictionary = {}
var custom_dir := CUSTOM_DIR
var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var effect_players: Array[AudioStreamPlayer] = []
var current_room := ""
var intro_active := false
var intro_queue: Array[String] = []
var intro_stage := ""
var title_mode := false
var event_counts: Dictionary = {}
var event_log: Array[String] = []
var room_start_counts: Dictionary = {}
var _next_effect := 0
var _step_clock := 0.0
var _left_step := true
var _intro_resume_room_music := true

func _ready() -> void:
	for channel in CHANNEL_BUSES:
		var bus_name: String = CHANNEL_BUSES[channel]
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	music_player = _new_player("RoomMusic", "music")
	music_player.finished.connect(_on_music_finished)
	ambience_player = _new_player("RoomAmbience", "ambience")
	for index in range(EFFECT_PLAYER_COUNT):
		effect_players.append(_new_player("Effect" + str(index), "effects"))
	load_settings()
	reload_assets()
	apply_audio_settings()

func _new_player(player_name: String, channel: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = CHANNEL_BUSES[channel]
	add_child(player)
	return player

func _exit_tree() -> void:
	var players: Array = effect_players.duplicate()
	players.append(music_player)
	players.append(ambience_player)
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	streams.clear()

func _safe_volume(value: Variant, fallback: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), 0.0, 1.0)

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for channel in CHANNEL_BUSES:
		settings[channel] = _safe_volume(config.get_value("audio", channel, DEFAULT_SETTINGS[channel]), DEFAULT_SETTINGS[channel])
	var mute_value: Variant = config.get_value("audio", "muted", false)
	settings["muted"] = mute_value if mute_value is bool else false

func save_settings() -> bool:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("audio", key, settings[key])
	return config.save(SETTINGS_PATH) == OK

func apply_audio_settings() -> void:
	for channel in CHANNEL_BUSES:
		var index := AudioServer.get_bus_index(CHANNEL_BUSES[channel])
		if index != -1:
			var volume: float = settings[channel]
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
			AudioServer.set_bus_mute(index, settings["muted"] or volume <= 0.0)

func set_volume(channel: String, value: float, persist: bool = true) -> void:
	if not CHANNEL_BUSES.has(channel):
		return
	settings[channel] = _safe_volume(value, DEFAULT_SETTINGS[channel])
	apply_audio_settings()
	if persist:
		save_settings()

func set_volumes(music: float, effects: float, ambience: float, persist: bool = true) -> void:
	set_volume("music", music, false)
	set_volume("effects", effects, false)
	set_volume("ambience", ambience, false)
	if persist:
		save_settings()

func set_muted(muted: bool, persist: bool = true) -> void:
	settings["muted"] = muted
	apply_audio_settings()
	if persist:
		save_settings()

func _load_stream(path: String) -> AudioStream:
	# Import-backed loading works in both the editor and exported games. The file
	# loader also allows optional user-added WAV/OGG files without an import pass.
	if ResourceLoader.exists(path):
		var resource := ResourceLoader.load(path)
		if resource is AudioStream:
			return resource
	if not FileAccess.file_exists(path):
		return null
	if path.get_extension().to_lower() == "wav":
		return AudioStreamWAV.load_from_file(path)
	if path.get_extension().to_lower() == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)
	return null

func reload_assets() -> void:
	streams.clear()
	source_paths.clear()
	var names: Array = EFFECTS.duplicate()
	for room in ROOMS:
		names.append("music_" + room)
		names.append("ambience_" + room)
	# Supplied introduction recordings are optional. Local custom cues can
	# override them; this loader never downloads recordings.
	names.append("intro_fanfare")
	names.append("intro_theme")
	for id in names:
		var stream: AudioStream
		var path := ""
		for extension in ["ogg", "wav"]:
			var custom_path: String = custom_dir.path_join(id + "." + extension)
			stream = _load_stream(custom_path)
			if stream != null:
				path = custom_path
				break
		if stream == null:
			# Supplied introduction recordings may be OGG; the original room
			# soundtrack and effects remain their existing WAV resources.
			var extensions := ["ogg", "wav"] if id in ["intro_fanfare", "intro_theme"] else ["wav"]
			for extension in extensions:
				path = "res://assets/audio/" + id + "." + extension
				stream = _load_stream(path)
				if stream != null:
					break
		if stream != null:
			streams[id] = stream
			source_paths[id] = path

func _loop_stream(source: AudioStream) -> AudioStream:
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
		stream.loop_offset = 0.0
	return stream

func _one_shot_stream(source: AudioStream) -> AudioStream:
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		stream.loop = false
	return stream

func _start_room_music() -> void:
	var id := "music_" + current_room
	music_player.stream = _loop_stream(streams[id]) if streams.has(id) else null
	if music_player.stream != null:
		music_player.play()
		_record_event(id)

func _start_room_ambience() -> void:
	var id := "ambience_" + current_room
	ambience_player.stream = _loop_stream(streams[id]) if streams.has(id) else null
	if ambience_player.stream != null:
		ambience_player.play()
		_record_event(id)

func play_intro(resume_room_music: bool = true) -> bool:
	if current_room == "":
		return false
	if intro_active:
		return true
	intro_queue.clear()
	for id in ["intro_fanfare", "intro_theme"]:
		if streams.has(id):
			intro_queue.append(id)
	if intro_queue.is_empty():
		return false
	_intro_resume_room_music = resume_room_music
	# Reuse the music player so the introduction and room score never overlap.
	music_player.stop()
	intro_active = true
	_play_next_intro()
	return true

func _play_next_intro() -> void:
	while not intro_queue.is_empty() and not streams.has(intro_queue[0]):
		intro_queue.pop_front()
	if intro_queue.is_empty():
		intro_active = false
		intro_stage = ""
		music_player.stop()
		music_player.stream = null
		if _intro_resume_room_music:
			_start_room_music()
		return
	intro_stage = intro_queue.pop_front()
	music_player.stream = _one_shot_stream(streams[intro_stage])
	music_player.play()
	_record_event(intro_stage)

func start_title_music() -> bool:
	# Room ambience stays silent on the title, including after the recordings
	# finish naturally. Starting play restores both room channels.
	_clear_intro()
	title_mode = true
	music_player.stop()
	music_player.stream = null
	ambience_player.stop()
	return play_intro(false)

func stop_title_music() -> void:
	finish_intro()

func _clear_intro() -> void:
	intro_active = false
	intro_queue.clear()
	intro_stage = ""

func finish_intro() -> void:
	if not intro_active and intro_stage == "" and not title_mode:
		return
	title_mode = false
	_clear_intro()
	music_player.stop()
	_start_room_music()
	if not ambience_player.playing:
		_start_room_ambience()

func _on_music_finished() -> void:
	if intro_active:
		_play_next_intro()

func set_room(room: String, restart: bool = false) -> void:
	if not ROOMS.has(room):
		return
	if room == current_room and not restart:
		finish_intro()
		# A title sequence which ended naturally leaves its music player idle.
		if music_player.stream == null:
			_start_room_music()
		return
	# Stop before assigning the next room: returning to a room never stacks loops.
	title_mode = false
	_clear_intro()
	music_player.stop()
	ambience_player.stop()
	current_room = room
	_step_clock = 0.0
	room_start_counts[room] = int(room_start_counts.get(room, 0)) + 1
	_start_room_music()
	_start_room_ambience()

func _record_event(id: String) -> void:
	event_counts[id] = int(event_counts.get(id, 0)) + 1
	event_log.append(id)
	if event_log.size() > 128:
		event_log.pop_front()

func play_sfx(id: String) -> bool:
	if not EFFECTS.has(id) or not streams.has(id) or settings["muted"] or settings["effects"] <= 0.0:
		return false
	var player: AudioStreamPlayer = effect_players[_next_effect]
	for offset in range(EFFECT_PLAYER_COUNT):
		var index := (_next_effect + offset) % EFFECT_PLAYER_COUNT
		if not effect_players[index].playing:
			player = effect_players[index]
			_next_effect = index
			break
	_next_effect = (_next_effect + 1) % EFFECT_PLAYER_COUNT
	player.stop()
	player.stream = streams[id]
	# Dialogue is a single soft acknowledgement, never a synthetic voice track.
	player.volume_db = -18.0 if id == "dialogue" else (-10.0 if id in ["step_a", "step_b"] else -2.0)
	player.play()
	_record_event(id)
	return true

func update_footsteps(delta: float, walking: bool) -> void:
	if not walking:
		_step_clock = 0.0
		return
	_step_clock += maxf(delta, 0.0)
	# Cap catch-up after a stalled frame; footsteps should not become a burst.
	var emitted := 0
	while _step_clock >= STEP_INTERVAL and emitted < 4:
		_step_clock -= STEP_INTERVAL
		play_sfx("step_a" if _left_step else "step_b")
		_left_step = not _left_step
		emitted += 1
	if emitted == 4:
		_step_clock = minf(_step_clock, STEP_INTERVAL)
