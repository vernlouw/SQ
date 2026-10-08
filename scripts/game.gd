extends Node2D
## A complete, original three-room adventure chapter. All puzzle actions are also
## exposed through perform_action so the walkthrough can run without rendering.

const SAVE_PATH := "user://the_mop_job_save.json"
const AdventureAudio := preload("res://scripts/audio.gd")
const VERBS := ["Look", "Use", "Talk"]
const KEY_ACTIONS := ["Interact", "Look", "Use", "Talk"]
const ROOM_NAMES := {"diner": "ORBITAL DINER", "dock": "SERVICE DOCK 7", "museum": "ARCADA MEMORIAL MUSEUM"}
const ROOM_INTROS := {
	"diner": "Your shift ended three hours ago. Naturally, the universe waited until now to need a janitor.",
	"dock": "A dock inspector, a grounded shuttle, and an impressive backlog of paperwork. Home sweet bureaucracy.",
	"museum": "The museum's priceless navigation archive is guarded by a machine with very strong opinions about cleanliness."
}
const INVENTORY_NAMES := {"service chit": "Service chit", "grease": "Fryer grease", "keycard": "Dock keycard", "maintenance pass": "Maintenance pass", "mop": "Service mop", "cleaner": "Ion cleaner", "charged mop": "Charged mop", "star map": "Star map"}
const ITEM_SHORT := {"service chit": "CHIT", "grease": "GREASE", "keycard": "CARD", "maintenance pass": "PASS", "mop": "MOP", "cleaner": "CLEANER", "charged mop": "ION MOP", "star map": "MAP"}
const HOTSPOTS := {
	"diner": {
		"news": {"rect": Rect2(5, 38, 77, 93), "at": Vector2(102, 267), "name": "News terminal"},
		"cook": {"rect": Rect2(302, 87, 65, 82), "at": Vector2(301, 269), "name": "Bex, the cook"},
		"grease": {"rect": Rect2(391, 142, 30, 28), "at": Vector2(409, 282), "name": "Fryer grease"},
		"counter": {"rect": Rect2(240, 169, 255, 48), "at": Vector2(270, 285), "name": "Service counter"},
		"panel": {"rect": Rect2(514, 122, 32, 47), "at": Vector2(525, 277), "name": "Door gear panel"},
		"exit": {"rect": Rect2(563, 83, 74, 165), "at": Vector2(574, 269), "name": "Service dock door"}
	},
	"dock": {
		"exit": {"rect": Rect2(6, 83, 45, 185), "at": Vector2(53, 274), "name": "Back to diner"},
		"mop": {"rect": Rect2(150, 150, 28, 79), "at": Vector2(174, 277), "name": "Service mop"},
		"locker": {"rect": Rect2(110, 93, 75, 140), "at": Vector2(136, 277), "name": "Maintenance locker"},
		"guard": {"rect": Rect2(290, 119, 110, 120), "at": Vector2(286, 276), "name": "Inspector Voss"},
		"terminal": {"rect": Rect2(488, 121, 50, 76), "at": Vector2(493, 281), "name": "Dock control terminal"},
		"museum": {"rect": Rect2(551, 79, 85, 169), "at": Vector2(572, 267), "name": "Museum lift"},
		"shuttle": {"rect": Rect2(249, 80, 169, 108), "at": Vector2(329, 278), "name": "Courier shuttle"}
	},
	"museum": {
		"kiosk": {"rect": Rect2(37, 125, 102, 104), "at": Vector2(126, 279), "name": "Visitor information"},
		"guardian": {"rect": Rect2(193, 112, 93, 138), "at": Vector2(224, 286), "name": "Archive guardian"},
		"spill": {"rect": Rect2(299, 249, 70, 41), "at": Vector2(288, 282), "name": "Ion coolant spill"},
		"plinth": {"rect": Rect2(386, 122, 100, 120), "at": Vector2(406, 276), "name": "Navigation archive"},
		"exit": {"rect": Rect2(563, 79, 69, 191), "at": Vector2(570, 274), "name": "Back to service dock"}
	}
}

var state: Dictionary = {}
var verb := "Interact"
var selected := ""
var player := Vector2(170, 279)
var destination := player
var pending_interaction: Dictionary = {}
var elapsed := 0.0
var facing_right := true
var show_hotspots := false
var hovered := ""
var message := ""
var textures: Dictionary = {}
var hud: Control
var status_label: Label
var room_label: Label
var score_label: Label
var verb_buttons: Array[Button] = []
var item_buttons: Array[Button] = []
var inventory_buttons: Dictionary = {}
var hotspots: Dictionary:
	get:
		var result: Dictionary = {}
		for id in HOTSPOTS[state.get("room", "diner")]:
			result[id] = HOTSPOTS[state.get("room", "diner")][id]["rect"]
		return result
var inventory_container: HBoxContainer
var dialogue_panel: Panel
var dialogue_text: Label
var speaker_label: Label
var portrait: TextureRect
var dialogue_lines: Array[String] = []
var dialogue_speaker := ""
var finale_panel: Panel
var audio
var sound_panel: Panel
var sound_shade: ColorRect
var sound_sliders: Dictionary = {}
var sound_mute: CheckButton
var sound_button: Button

func _ready() -> void:
	audio = AdventureAudio.new()
	audio.name = "AdventureAudio"
	add_child(audio)
	for name in ["room_diner", "room_dock", "room_museum", "roger", "roger_walk", "cook", "guard", "portrait_roger", "portrait_cook", "portrait_guard", "portrait_clone"]:
		var path: String = "res://assets/" + name + ".png"
		if ResourceLoader.exists(path):
			textures[name] = load(path)
	_build_ui()
	new_game()

func _panel_style(fill: Color, border: Color = Color("47667b"), radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _button(text_value: String, pos: Vector2, size_value: Vector2, callback: Callable, parent: Node = hud) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = pos
	button.size = size_value
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("dfe8ed"))
	button.add_theme_color_override("font_hover_color", Color("fff0be"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("172b3d")))
	button.add_theme_stylebox_override("hover", _panel_style(Color("26465a"), Color("dbb671")))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("315972"), Color("dbb671")))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func():
		if sound_is_open() and parent == hud:
			return
		audio.play_sfx("ui_click")
		callback.call())
	parent.add_child(button)
	return button

func _label(text_value: String, pos: Vector2, size_value: Vector2, font_size: int = 12, parent: Node = hud) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("dfe8ed"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_ui() -> void:
	hud = Control.new()
	hud.name = "AdventureInterface"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	room_label = _label("", Vector2(12, 4), Vector2(309, 20), 12)
	room_label.add_theme_color_override("font_color", Color("f5d49a"))
	score_label = _label("", Vector2(313, 4), Vector2(79, 20), 11)
	_button("Hint", Vector2(396, 2), Vector2(49, 22), give_hint)
	_button("Save", Vector2(450, 2), Vector2(49, 22), func(): save_game())
	_button("Load", Vector2(504, 2), Vector2(49, 22), func(): load_game())
	_button("New", Vector2(558, 2), Vector2(69, 22), confirm_new_game)
	status_label = _label("", Vector2(12, 320), Vector2(614, 24), 11)
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.clip_text = true
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for index in range(VERBS.size()):
		var action: String = VERBS[index]
		var button := _button(action, Vector2(12 + index * 80, 348), Vector2(76, 34), func(): set_verb(action))
		button.tooltip_text = str(index + 2) + " — " + action + "; click again for automatic interaction."
		verb_buttons.append(button)
	_label("Click to move / interact • Right-click inspect", Vector2(12, 383), Vector2(251, 15), 9)
	_label("POCKETS", Vector2(264, 343), Vector2(340, 17), 9)
	inventory_container = HBoxContainer.new()
	inventory_container.position = Vector2(264, 361)
	inventory_container.size = Vector2(363, 27)
	inventory_container.add_theme_constant_override("separation", 4)
	hud.add_child(inventory_container)
	dialogue_panel = Panel.new()
	dialogue_panel.position = Vector2(24, 40)
	dialogue_panel.size = Vector2(592, 124)
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.078, 0.12, 0.97), Color("caa86b"), 8))
	hud.add_child(dialogue_panel)
	portrait = TextureRect.new()
	portrait.position = Vector2(10, 11)
	portrait.size = Vector2(100, 102)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_child(portrait)
	speaker_label = _label("", Vector2(122, 10), Vector2(450, 23), 13, dialogue_panel)
	speaker_label.add_theme_color_override("font_color", Color("f6ca82"))
	dialogue_text = _label("", Vector2(122, 36), Vector2(451, 67), 13, dialogue_panel)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("Click or Space to continue", Vector2(414, 104), Vector2(165, 16), 9, dialogue_panel)
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.hide()
	finale_panel = Panel.new()
	finale_panel.position = Vector2(86, 63)
	finale_panel.size = Vector2(468, 231)
	finale_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.065, 0.11, 0.98), Color("d7b576"), 10))
	hud.add_child(finale_panel)
	_label("CHAPTER COMPLETE", Vector2(28, 20), Vector2(414, 24), 13, finale_panel).add_theme_color_override("font_color", Color("efca84"))
	_label("THE MOP JOB", Vector2(28, 47), Vector2(414, 41), 30, finale_panel)
	var ending := _label("The archive is safe. The clone is on Labion.\n\nYou point the courier toward the orange planet and wonder whether overtime covers saving the galaxy.\n\nA complete three-room chapter. The chase continues…", Vector2(28, 99), Vector2(412, 106), 13, finale_panel)
	ending.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("Play again", Vector2(313, 197), Vector2(126, 25), func(): new_game(), finale_panel)
	finale_panel.hide()
	sound_button = _button("Sound", Vector2(577, 376), Vector2(50, 22), toggle_sound_panel)
	sound_button.add_theme_font_size_override("font_size", 9)
	sound_button.size = Vector2(50, 22)
	sound_button.tooltip_text = "Music, effects and ambience — M"
	_build_sound_panel()

func _build_sound_panel() -> void:
	sound_shade = ColorRect.new()
	sound_shade.position = Vector2.ZERO
	sound_shade.size = Vector2(640, 400)
	sound_shade.color = Color(0, 0, 0, 0.55)
	sound_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(sound_shade)
	sound_panel = Panel.new()
	sound_panel.position = Vector2(148, 111)
	sound_panel.size = Vector2(344, 178)
	sound_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	sound_panel.add_theme_stylebox_override("panel", _panel_style(Color("0c1c2a"), Color("dbb671"), 8))
	sound_shade.add_child(sound_panel)
	_label("SOUND", Vector2(16, 10), Vector2(254, 24), 15, sound_panel)
	_button("Close", Vector2(276, 10), Vector2(54, 22), close_sound_panel, sound_panel)
	var index := 0
	for channel in ["music", "effects", "ambience"]:
		var y := 44 + index * 30
		_label(channel.capitalize(), Vector2(17, y), Vector2(92, 22), 12, sound_panel)
		var slider := HSlider.new()
		slider.position = Vector2(110, y + 2)
		slider.size = Vector2(207, 19)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = audio.settings[channel]
		slider.tooltip_text = channel.capitalize() + " volume"
		slider.value_changed.connect(func(value: float): audio.set_volume(channel, value))
		sound_panel.add_child(slider)
		sound_sliders[channel] = slider
		index += 1
	sound_mute = CheckButton.new()
	sound_mute.text = "Mute all"
	sound_mute.position = Vector2(12, 135)
	sound_mute.size = Vector2(131, 30)
	sound_mute.add_theme_font_size_override("font_size", 11)
	sound_mute.button_pressed = audio.settings["muted"]
	sound_mute.toggled.connect(func(muted: bool): audio.set_muted(muted))
	sound_panel.add_child(sound_mute)
	_label("Esc closes • Settings saved automatically", Vector2(150, 143), Vector2(180, 16), 8, sound_panel)
	sound_shade.hide()
	sound_panel.hide()

func sound_is_open() -> bool:
	return is_instance_valid(sound_panel) and sound_panel.visible

func toggle_sound_panel() -> void:
	if sound_is_open():
		close_sound_panel()
		return
	for channel in sound_sliders:
		sound_sliders[channel].set_value_no_signal(audio.settings[channel])
	sound_mute.set_pressed_no_signal(audio.settings["muted"])
	sound_shade.show()
	sound_panel.show()
	audio.update_footsteps(0.0, false)
	hovered = ""
	queue_redraw()

func close_sound_panel() -> void:
	sound_panel.hide()
	sound_shade.hide()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if sound_is_open() and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_M]:
		close_sound_panel()
		get_viewport().set_input_as_handled()

func new_game(show_intro: bool = true) -> void:
	close_sound_panel()
	state = {"room": "diner", "inventory": [], "flags": {}, "score": 0}
	player = Vector2(173, 280)
	destination = player
	pending_interaction.clear()
	verb = "Interact"
	selected = ""
	dialogue_lines.clear()
	dialogue_panel.hide()
	finale_panel.hide()
	audio.set_room("diner", true)
	say("A stolen relic. A suspicious clone. First: get out of the diner.")
	if show_intro:
		show_dialog("roger", ["The news says a clone wearing your face stole the museum's Mop of Destiny. Your captain says: clear your name before tomorrow's shift.", "Click the floor to move. Click people to talk and objects to interact; Roger approaches automatically. Right-click an object to inspect it. Select pocket items to use or combine them."])
	update_hud()
	queue_redraw()

func confirm_new_game() -> void:
	if state.get("score", 0) == 0 or flag("complete"):
		new_game()
	else:
		show_dialog("roger", ["Starting again will reset this chapter. Your saved game is kept. Press N now to restart, or continue playing."])

func flag(key: String) -> bool:
	return bool(state.get("flags", {}).get(key, false))

func award(key: String, points: int) -> void:
	if not flag(key):
		state["flags"][key] = true
		state["score"] += points
		if key in ["hatch_fixed", "floor_clean"]:
			audio.play_sfx("success")
		elif key in ["museum_access", "coordinates_set", "cleaning_mode"]:
			audio.play_sfx("terminal")
		elif key == "complete":
			audio.play_sfx("complete")

func has_item(item: String) -> bool:
	return state.get("inventory", []).has(item)

func add_item(item: String, play_pickup: bool = true) -> void:
	if not has_item(item):
		state["inventory"].append(item)
		if play_pickup:
			audio.play_sfx("pickup")

func remove_item(item: String) -> void:
	state["inventory"].erase(item)
	if selected == item:
		selected = ""

func set_verb(action: String) -> void:
	if dialogue_panel.visible or sound_is_open():
		return
	verb = "Interact" if action == verb or action == "Walk" else action
	selected = ""
	pending_interaction.clear()
	say("Click objects to interact; click the floor to move." if verb == "Interact" else verb + ": click an object. Click the active button again to return to automatic interaction.")
	update_hud()

func say(line: String) -> void:
	message = line
	if is_instance_valid(status_label):
		status_label.text = line

func show_dialog(speaker: String, lines: Array) -> void:
	dialogue_speaker = speaker
	dialogue_lines.clear()
	for line in lines:
		dialogue_lines.append(str(line))
	_advance_dialog()

func _advance_dialog() -> void:
	if dialogue_lines.is_empty():
		dialogue_panel.hide()
		return
	var line: String = dialogue_lines.pop_front()
	audio.play_sfx("dialogue")
	dialogue_text.text = line
	speaker_label.text = {"roger": "ROGER — SANITATION / RELUCTANT HERO", "cook": "BEX — HEAD COOK / OIL BARON", "guard": "VOSS — DOCK INSPECTOR", "guardian": "ARCHIVE GUARDIAN / MAINTENANCE AI", "clone": "R0-GER — RECORDED MESSAGE"}.get(dialogue_speaker, "TRANSMISSION")
	portrait.texture = textures.get("portrait_" + ("guard" if dialogue_speaker == "guardian" else dialogue_speaker), null)
	dialogue_panel.show()
	say(line)

func close_dialogue() -> void:
	dialogue_lines.clear()
	dialogue_panel.hide()

func update_hud() -> void:
	if not is_instance_valid(room_label):
		return
	room_label.text = "THE MOP JOB   /   " + str(ROOM_NAMES.get(state.get("room", "diner"), ""))
	score_label.text = "SCORE " + str(state.get("score", 0)) + "/100"
	for button in verb_buttons:
		button.modulate = Color("ffd591") if button.text == verb else Color.WHITE
	for child in inventory_container.get_children():
		inventory_container.remove_child(child)
		child.queue_free()
	item_buttons.clear()
	inventory_buttons.clear()
	var items: Array = state.get("inventory", [])
	if items.is_empty():
		var empty := Label.new()
		empty.text = "A heroic amount of pocket lint."
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color("829ba8"))
		inventory_container.add_child(empty)
	else:
		for item_value in items:
			var item := str(item_value)
			var button := _button(str(ITEM_SHORT.get(item, item)), Vector2.ZERO, Vector2.ZERO, func(): select_item(item), inventory_container)
			button.add_theme_font_size_override("font_size", 9)
			button.custom_minimum_size = Vector2(48, 27)
			button.tooltip_text = str(INVENTORY_NAMES.get(item, item)) + " — click to use; click another item to combine."
			button.modulate = Color("ffd591") if item == selected else Color.WHITE
			item_buttons.append(button)
			inventory_buttons[item] = button
	queue_redraw()

func select_item(item: String) -> void:
	if dialogue_panel.visible or sound_is_open() or not has_item(item):
		return
	if selected != "" and selected != item:
		if combine_items(selected, item):
			update_hud()
			return
	selected = item
	verb = "Interact"
	say("Using " + str(INVENTORY_NAMES.get(item, item)) + ". Click a room object or another pocket item.")
	update_hud()

func combine_items(first: String, second: String) -> bool:
	if not has_item(first) or not has_item(second):
		audio.play_sfx("blocked")
		return false
	if (first == "cleaner" and second == "mop") or (first == "mop" and second == "cleaner"):
		remove_item("cleaner")
		remove_item("mop")
		add_item("charged mop", false)
		selected = "charged mop"
		award("mop_charged", 5)
		audio.play_sfx("combine")
		show_dialog("roger", ["One freshly charged ion mop. Finally, a weapon covered by my professional qualifications."])
		update_hud()
		return true
	say("Those items don't fit together. Roger's pockets appreciate your restraint.")
	audio.play_sfx("blocked")
	return false

func _process(delta: float) -> void:
	elapsed += delta
	var moving := player.distance_to(destination) > 1.0
	var walking := moving and not dialogue_panel.visible and not sound_is_open() and not flag("complete")
	if walking:
		var old_position := player
		facing_right = destination.x >= player.x
		player = player.move_toward(destination, delta * 132.0)
		audio.update_footsteps(old_position.distance_to(player) / 132.0, true)
		if player.distance_to(destination) < 1.0 and not pending_interaction.is_empty():
			var queued: Dictionary = pending_interaction.duplicate()
			pending_interaction.clear()
			perform_action(queued["id"], queued["verb"], queued["item"])
	else:
		audio.update_footsteps(0.0, false)
	var mouse := get_global_mouse_position()
	hovered = hotspot_at(mouse) if mouse.y > 26 and mouse.y < 318 and not dialogue_panel.visible and not sound_is_open() else ""
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered != "" else Input.CURSOR_ARROW)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if sound_is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if dialogue_panel.visible:
				_advance_dialog()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
			set_verb(KEY_ACTIONS[event.keycode - KEY_1])
		elif event.keycode == KEY_TAB:
			show_hotspots = not show_hotspots
		elif event.keycode == KEY_F5:
			save_game()
		elif event.keycode == KEY_F9:
			load_game()
		elif event.keycode == KEY_H:
			give_hint()
		elif event.keycode == KEY_I:
			say("Your pockets are at bottom right. Click an item, then a room object; click two items to combine them.")
		elif event.keycode == KEY_M:
			audio.play_sfx("ui_click")
			toggle_sound_panel()
		elif event.keycode == KEY_N and dialogue_panel.visible and dialogue_text.text.begins_with("Starting again"):
			new_game()
		elif event.keycode == KEY_ESCAPE:
			close_dialogue()
			reset_interaction()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			route_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			route_right_click(event.position)

func hotspot_at(point: Vector2) -> String:
	var room: String = state.get("room", "diner")
	if point.y < 26 or point.y >= 318:
		return ""
	for id in HOTSPOTS[room]:
		if id == "grease" and (has_item("grease") or flag("hatch_fixed")):
			continue
		if id == "mop" and flag("mop_taken"):
			continue
		if HOTSPOTS[room][id]["rect"].has_point(point):
			return str(id)
	return ""

func route_click(point: Vector2) -> void:
	if sound_is_open():
		return
	if dialogue_panel.visible:
		_advance_dialog()
		return
	if point.y < 26 or point.y >= 318 or flag("complete"):
		return
	var id := hotspot_at(point)
	if id == "":
		pending_interaction.clear()
		destination = Vector2(clampf(point.x, 25, 615), clampf(point.y, 257, 306))
		return
	var action := "Use" if selected != "" else (default_action(id) if verb == "Interact" else verb)
	queue_world_action(id, action, selected)

func route_right_click(point: Vector2) -> void:
	if sound_is_open():
		return
	if dialogue_panel.visible:
		_advance_dialog()
		return
	if point.y < 26 or point.y >= 318 or flag("complete"):
		return
	var id := hotspot_at(point)
	if id == "":
		reset_interaction()
	else:
		queue_world_action(id, "Look", "")

func reset_interaction() -> void:
	selected = ""
	verb = "Interact"
	pending_interaction.clear()
	say("Click objects to interact; click the floor to move.")
	update_hud()

func default_action(id: String) -> String:
	if id in ["news", "kiosk"]:
		return "Look"
	if id in ["cook", "counter", "guard", "guardian"]:
		return "Talk"
	return "Use"

func contextual_action_label(id: String) -> String:
	if selected != "":
		return "Use " + str(INVENTORY_NAMES.get(selected, selected)) + " on"
	var action := default_action(id) if verb == "Interact" else verb
	if action == "Look":
		return "Inspect"
	if action == "Talk":
		return "Talk to"
	if id in ["grease", "mop"] or (id == "plinth" and not flag("archive_taken")):
		return "Pick up"
	if id in ["exit", "museum"]:
		return "Enter"
	if id == "shuttle":
		return "Board"
	return "Use"

func queue_world_action(id: String, action: String, item: String = "") -> void:
	if not HOTSPOTS[state["room"]].has(id):
		return
	var data: Dictionary = HOTSPOTS[state["room"]][id]
	destination = data["at"]
	pending_interaction = {"id": id, "verb": action, "item": item}
	if player.distance_to(destination) < 1:
		pending_interaction.clear()
		perform_action(id, action, item)

func interact(id: String) -> void:
	perform_action(id, "Use" if selected != "" else (default_action(id) if verb == "Interact" else verb), selected)

func perform_action(id: String, action: String = "Use", item: String = "") -> void:
	if state.is_empty() or flag("complete") or sound_is_open():
		return
	if item == "" and action in ["Use", "Interact"]:
		item = selected
	if action == "Interact":
		action = "Use" if item != "" else default_action(id)
	var room: String = state["room"]
	if not HOTSPOTS[room].has(id):
		say("That object isn't in this room.")
		audio.play_sfx("blocked")
		return
	if action == "Look":
		inspect_object(id)
	elif action == "Walk":
		if id in ["exit", "museum", "shuttle"]:
			use_object(id, "")
		else:
			say("Standing beside " + str(HOTSPOTS[room][id]["name"]) + ". Choose Look, Use, or Talk.")
	elif action == "Talk":
		talk_to(id)
	elif action == "Use":
		use_object(id, item)
	update_hud()

func inspect_object(id: String) -> void:
	var descriptions := {
		"diner": {"news": "SECURITY BULLETIN: a counterfeit janitor stole the Mop of Destiny. The museum's navigation archive recorded his escape. That face looks horribly familiar.", "cook": "Bex has fed six civilizations and poisoned only the ones that complained.", "grease": "Industrial fryer grease. According to the label: condiment, lubricant, and emergency rocket fuel.", "counter": "The sanitation service desk is cunningly disguised as a burger counter. Bex probably has your paperwork.", "panel": "The hatch's exposed gears have seized. A little lubricant should free them.", "exit": "The service dock is through this hatch. The mechanism is " + ("running smoothly." if flag("hatch_fixed") else "jammed solid.")},
		"dock": {"exit": "Back to the diner. The menu is less hazardous than most planets.", "locker": "A card-operated maintenance locker. It contains ion cleaner and controls the magnetic clamp on the nearby mop.", "mop": "A service mop leans beside the locker. Its magnetic security clamp releases when the locker is opened with a dock keycard.", "guard": "Inspector Voss. Protector of the dock, sworn enemy of unsigned forms.", "terminal": "The dock console manages museum access and shuttle navigation. Card reader on the left, archive socket on the right.", "museum": "A lift to the Arcada Memorial Museum. The control terminal authorizes entry.", "shuttle": "A courier shuttle with a perfectly good engine and absolutely no destination. The museum's stolen archive should tell you where the clone went."},
		"museum": {"kiosk": "INCIDENT REPORT: clone R0-GER departed for Labion. Exact coordinates are stored in the navigation archive. Maintenance rules: present a pass; neutralize ion coolant with a charged mop.", "guardian": "A security automaton whose cleaning subroutine outranks its security subroutine. There is hope for us all.", "spill": "Ion coolant. A dry mop will only spread it. The maintenance locker has ion cleaner; combine it with a mop first.", "plinth": "The navigation archive floats behind a laser seal. Maintenance mode releases it only when the floor is clean.", "exit": "The service lift returns to your waiting courier."}
	}
	show_dialog("roger", [descriptions[state["room"]].get(id, "Worth another look.")])

func talk_to(id: String) -> void:
	match state["room"] + ":" + id:
		"diner:cook", "diner:counter":
			if not flag("cook_help"):
				award("cook_help", 5)
				add_item("service chit")
				show_dialog("cook", ["A clone stole the Mop of Destiny? I knew that discount Roger was trouble. He asked for a burger without the existential dread.", "Take your service chit to Inspector Voss in the dock. And help yourself to the fryer grease: those hatch gears are stuck again."])
			else:
				show_dialog("cook", ["Grease the little panel beside the hatch. Voss wants your service chit before he'll open the maintenance locker. It's bureaucracy all the way down."])
		"dock:guard":
			if flag("guard_help"):
				show_dialog("guard", ["Your keycard opens the locker and authorizes the museum lift at the dock terminal. Present the maintenance pass to the archive guardian. Retrieve the star map, load it into this terminal, then board the courier."])
			else:
				show_dialog("guard", ["Nobody enters the museum without a maintenance pass. Bring me a current service chit, and I can issue the pass and your locker keycard. Yes, even during a galactic emergency."])
		"museum:guardian":
			show_dialog("guardian", ["ARCHIVE RESTRICTED. Maintenance personnel: present valid pass. Then neutralize coolant using an ion-charged mop. Once the floor meets policy 8-B, the archive may be removed for inspection.", "Clone departure logged: LABION. I would pursue him myself, but my wheels are rated for indoor flooring only."])
		_:
			show_dialog("roger", ["It has nothing to say. We have that in common at staff meetings."])

func use_object(id: String, item: String) -> void:
	match state["room"]:
		"diner":
			match id:
				"grease":
					if not flag("cook_help"):
						audio.play_sfx("blocked")
						show_dialog("cook", ["Ask before pocketing my gourmet industrial waste, spaceman."])
					elif has_item("grease") or flag("hatch_fixed"):
						say("You've already put the grease to good use.")
					else:
						add_item("grease")
						award("grease_taken", 5)
						show_dialog("roger", ["Fryer grease acquired. My uniform's resale value has acquired a minus sign."])
				"panel":
					if flag("hatch_fixed"):
						say("The hatch is working. Click the doorway to enter the dock.")
					elif item == "grease" and has_item(item):
						remove_item(item)
						award("hatch_fixed", 10)
						show_dialog("roger", ["A dab of grease, a satisfying clunk, and the hatch opens. The first useful thing this diner has produced all week."])
					else:
						audio.play_sfx("blocked")
						show_dialog("roger", ["Dry, seized gears. They need lubricant. Bex's fryer might be useful for something after all."])
				"exit":
					if flag("hatch_fixed"):
						enter_room("dock", Vector2(61, 279))
					else:
						audio.play_sfx("blocked")
						show_dialog("roger", ["The hatch won't move. Inspect the gear panel beside it."])
				"cook", "counter":
					talk_to("cook")
				"news":
					inspect_object("news")
		"dock":
			match id:
				"exit":
					enter_room("diner", Vector2(565, 281))
				"guard":
					if item == "service chit" and has_item(item):
						remove_item(item)
						add_item("keycard")
						add_item("maintenance pass", false)
						award("guard_help", 10)
						show_dialog("guard", ["One service chit. Signed, stamped, suspiciously greasy. Here's your locker keycard and a museum maintenance pass.", "Open the locker, then use the keycard at the dock terminal to activate the museum lift. If you find the clone's star map, load it here before boarding the shuttle."])
					else:
						audio.play_sfx("blocked")
						talk_to("guard")
				"locker":
					if flag("locker_open"):
						say("The locker is open. " + ("You collected the ion cleaner and mop." if flag("mop_taken") else "The mop beside it is released; click it to pick it up."))
					elif item == "keycard" and has_item(item):
						audio.play_sfx("door")
						add_item("cleaner")
						award("locker_open", 10)
						show_dialog("roger", ["The locker opens: one bottle of ion cleaner. It also releases the magnetic clamp on the mop leaning beside it. Click the mop to pick it up.", "You can combine items in your pockets: click one, then the other. The ion cleaner belongs on the mop, not in the coffee."])
					else:
						audio.play_sfx("blocked")
						show_dialog("roger", ["Locked. Inspector Voss issues keycards to janitors with valid service paperwork."])
				"mop":
					if flag("mop_taken"):
						say("You already collected the service mop.")
					elif not flag("locker_open"):
						audio.play_sfx("blocked")
						show_dialog("roger", ["A magnetic clamp holds the mop. Open the maintenance locker with your dock keycard to release it."])
					else:
						add_item("mop")
						award("mop_taken", 0)
						show_dialog("roger", ["Service mop acquired. Combine it with the ion cleaner in your pockets to make the charged mop the museum needs."])
				"terminal":
					if item == "star map" and has_item(item):
						remove_item(item)
						award("coordinates_set", 10)
						show_dialog("roger", ["The archive loads into the courier. Destination: Labion. Passenger: one deeply underpaid janitor. Board the shuttle when you're ready."])
					elif item == "keycard" and has_item(item):
						if not flag("museum_access"):
							award("museum_access", 5)
						show_dialog("guard", ["Museum lift authorized. The doorway on the right leads up to the archive. Keep the maintenance pass ready for its guardian."])
					else:
						audio.play_sfx("blocked")
						show_dialog("roger", ["Two slots: dock keycard for the museum lift, navigation archive for the courier's route. Very considerate labelling by galactic standards."])
				"museum":
					if flag("museum_access"):
						enter_room("museum", Vector2(548, 282))
					else:
						audio.play_sfx("blocked")
						show_dialog("guard", ["Authorize the lift at the dock terminal. It needs your keycard."])
				"shuttle":
					if flag("coordinates_set"):
						award("complete", 10)
						dialogue_lines.clear()
						dialogue_panel.hide()
						finale_panel.show()
						say("Course set for Labion. Chapter complete — 100/100.")
					else:
						audio.play_sfx("blocked")
						show_dialog("roger", ["The shuttle needs a destination. Retrieve the museum's navigation archive and use it on the dock terminal first."])
		"museum":
			match id:
				"exit":
					enter_room("dock", Vector2(223, 279))
				"kiosk":
					inspect_object("kiosk")
				"guardian":
					if item == "maintenance pass" and has_item(item):
						award("cleaning_mode", 10)
						show_dialog("guardian", ["PASS ACCEPTED. Maintenance mode enabled. Remove coolant from the floor using a charged mop; the archive seal will release automatically."])
					else:
						audio.play_sfx("blocked")
						talk_to("guardian")
				"spill":
					if flag("floor_clean"):
						say("The floor gleams. Somewhere, a janitorial supervisor sheds a tear.")
					elif not flag("cleaning_mode"):
						audio.play_sfx("blocked")
						show_dialog("guardian", ["MAINTENANCE NOT AUTHORIZED. Present a valid maintenance pass before touching the coolant."])
					elif item == "charged mop" and has_item(item):
						remove_item(item)
						award("floor_clean", 10)
						show_dialog("guardian", ["CONTAMINANT NEUTRALIZED. Floor sheen: exemplary. Archive seal released. Your annual performance review will include one complimentary adjective."])
					elif item == "mop":
						audio.play_sfx("blocked")
						show_dialog("roger", ["A dry mop just spreads the ion coolant. Combine the cleaner and mop in your pockets first."])
					else:
						audio.play_sfx("blocked")
						inspect_object("spill")
				"plinth":
					if flag("archive_taken"):
						say("You recovered the archive. Return to the dock and load the star map into the terminal.")
					elif flag("floor_clean"):
						add_item("star map")
						award("archive_taken", 10)
						show_dialog("clone", ["RECORDED MESSAGE: Thanks for taking the blame, original me. I'll be on Labion, acquiring a galaxy. Do enjoy your next shift.", "The stolen archive is now in your pockets. Return to the dock, use MAP on the terminal, then board the courier to follow the impostor."])
					else:
						audio.play_sfx("blocked")
						show_dialog("guardian", ["ARCHIVE SEALED. Present maintenance credentials, then neutralize the coolant spill. This is a museum, not a slip-and-fall attraction."])

func enter_room(room: String, position_value: Vector2 = Vector2(170, 280)) -> void:
	if not ROOM_NAMES.has(room):
		return
	if state.get("room", "") != room:
		audio.play_sfx("door")
	state["room"] = room
	audio.set_room(room)
	player = position_value
	destination = player
	pending_interaction.clear()
	selected = ""
	verb = "Interact"
	dialogue_lines.clear()
	dialogue_panel.hide()
	say(ROOM_INTROS[room])
	update_hud()

func give_hint() -> void:
	if sound_is_open():
		return
	var hint := "The courier is ready. Click the shuttle in the dock to board."
	if not flag("cook_help"):
		hint = "Click Bex, the cook, to talk. You need permission and your service paperwork."
	elif not flag("grease_taken"):
		hint = "Click the small grease jar at the right end of the counter to pick it up."
	elif not flag("hatch_fixed"):
		hint = "Select GREASE in your pockets, then click the gear panel beside the dock hatch."
	elif not flag("guard_help"):
		hint = "In the dock, select CHIT and use it on Inspector Voss."
	elif not flag("locker_open"):
		hint = "Use your CARD on the maintenance locker at the left side of the dock."
	elif not flag("mop_taken"):
		hint = "Click the mop leaning beside the open dock locker to pick it up."
	elif not flag("museum_access"):
		hint = "Use your CARD on the dock terminal, then click the museum lift at the far right."
	elif not flag("cleaning_mode"):
		hint = "In the museum, use your PASS on the archive guardian."
	elif not flag("mop_charged"):
		hint = "Click CLEANER in your pockets, then click MOP to combine them."
	elif not flag("floor_clean"):
		hint = "Use the ION MOP on the coolant spill in front of the archive."
	elif not flag("archive_taken"):
		hint = "Use the navigation archive on its plinth. Its laser seal is now released."
	elif not flag("coordinates_set"):
		hint = "Return to the dock. Use MAP on the dock terminal to set the courier's destination."
	show_dialog("roger", [hint])

func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		say("Couldn't write the save file: " + error_string(FileAccess.get_open_error()))
		audio.play_sfx("blocked")
		return false
	var snapshot := state.duplicate(true)
	snapshot["player"] = [player.x, player.y]
	file.store_string(JSON.stringify(snapshot, "\t"))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		say("Couldn't finish writing the save file: " + error_string(write_error))
		audio.play_sfx("blocked")
		return false
	say("Game saved. F9 or Load restores this checkpoint.")
	audio.play_sfx("save")
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		say("No saved game yet. Click Save or press F5 to create one.")
		audio.play_sfx("blocked")
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		say("Couldn't open the saved game.")
		audio.play_sfx("blocked")
		return false
	var snapshot = JSON.parse_string(file.get_as_text())
	if not snapshot is Dictionary or not ROOM_NAMES.has(snapshot.get("room", "")) or not snapshot.get("inventory", null) is Array or not snapshot.get("flags", null) is Dictionary:
		say("The save file isn't a valid chapter checkpoint.")
		audio.play_sfx("blocked")
		return false
	var position_value = snapshot.get("player", [170.0, 280.0])
	if not position_value is Array or position_value.size() != 2 or not (position_value[0] is float or position_value[0] is int) or not (position_value[1] is float or position_value[1] is int):
		say("The checkpoint contains an invalid player position.")
		audio.play_sfx("blocked")
		return false
	state = snapshot
	state.erase("player")
	state["score"] = int(state.get("score", 0))
	# Earlier checkpoints granted the mop when the locker opened. Preserve that
	# pickup when loading, including saves made after the mop was charged/used.
	if has_item("mop") or has_item("charged mop") or flag("mop_charged") or flag("floor_clean"):
		state["flags"]["mop_taken"] = true
	player = Vector2(float(position_value[0]), float(position_value[1]))
	destination = player
	pending_interaction.clear()
	selected = ""
	verb = "Interact"
	dialogue_lines.clear()
	dialogue_panel.hide()
	finale_panel.visible = flag("complete")
	audio.set_room(state["room"])
	audio.update_footsteps(0.0, false)
	say("Checkpoint restored. " + ROOM_INTROS[state["room"]])
	audio.play_sfx("load")
	update_hud()
	return true

func _draw() -> void:
	if state.is_empty():
		return
	draw_rect(Rect2(0, 0, 640, 400), Color("08141f"))
	var room: String = state["room"]
	if textures.has("room_" + room):
		draw_texture_rect(textures["room_" + room], Rect2(0, 26, 640, 292), false)
	else:
		_draw_fallback_room(room)
	_draw_scene_props(room)
	_draw_player()
	draw_rect(Rect2(0, 0, 640, 26), Color("0c1c2a"))
	draw_line(Vector2(0, 25), Vector2(640, 25), Color("7c6749"))
	draw_rect(Rect2(0, 318, 640, 82), Color("0c1c2a"))
	draw_line(Vector2(0, 318), Vector2(640, 318), Color("7c6749"))
	if show_hotspots:
		for id in HOTSPOTS[room]:
			if id == "grease" and (has_item("grease") or flag("hatch_fixed")):
				continue
			if id == "mop" and flag("mop_taken"):
				continue
			var rect: Rect2 = HOTSPOTS[room][id]["rect"]
			draw_rect(rect, Color(0.94, 0.79, 0.48, 0.38), false, 1)
			var label: String = HOTSPOTS[room][id]["name"]
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(2, 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffe7ad"))
	if hovered != "" and not dialogue_panel.visible:
		var data: Dictionary = HOTSPOTS[room][hovered]
		var rect: Rect2 = data["rect"]
		var label := contextual_action_label(hovered) + "  " + str(data["name"])
		var label_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16
		var label_position := Vector2(clampf(rect.get_center().x - label_width * 0.5, 6, 634 - label_width), clampf(rect.position.y - 22, 29, 293))
		draw_style_box(_panel_style(Color(0.025, 0.075, 0.115, 0.94), Color("d6b778"), 3), Rect2(label_position, Vector2(label_width, 21)))
		draw_string(ThemeDB.fallback_font, label_position + Vector2(8, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffe4ac"))

func _draw_fallback_room(room: String) -> void:
	var colors := {"diner": Color("654054"), "dock": Color("24414d"), "museum": Color("39394e")}
	draw_rect(Rect2(0, 26, 640, 292), colors[room])
	for i in range(9):
		draw_line(Vector2(i * 80, 26), Vector2(i * 80, 318), Color(0.1, 0.14, 0.2, 0.3), 2)
	draw_rect(Rect2(0, 249, 640, 69), Color("343d4a"))
	for id in HOTSPOTS[room]:
		var rect: Rect2 = HOTSPOTS[room][id]["rect"]
		draw_rect(rect, Color(0.07, 0.1, 0.15, 0.5))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(3, 16), HOTSPOTS[room][id]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d8e2e7"))

func _draw_scene_props(room: String) -> void:
	# Small diegetic indicators keep puzzle objects legible over detailed artwork.
	match room:
		"diner":
			if textures.has("cook"):
				draw_texture_rect_region(textures["cook"], Rect2(296, 83, 72, 83), Rect2(27, 16, 956, 1100))
			if not has_item("grease") and not flag("hatch_fixed"):
				draw_circle(Vector2(405, 150), 11, Color(0.93, 0.7, 0.35, 0.1 + sin(elapsed * 2.0) * 0.025))
			draw_circle(Vector2(530, 145), 2.6, Color("86e1ae") if flag("hatch_fixed") else Color("e5a45f"))
		"dock":
			if textures.has("guard"):
				draw_texture_rect_region(textures["guard"], Rect2(323, 146, 44, 96), Rect2(187, 9, 689, 1510))
			draw_circle(Vector2(515, 147), 2.5, Color("73e6c3") if flag("coordinates_set") else Color("e5b464"))
			if flag("museum_access"):
				draw_line(Vector2(569, 223), Vector2(620, 223), Color("85efd5"), 2)
			if flag("locker_open"):
				draw_string(ThemeDB.fallback_font, Vector2(126, 183), "OPEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("c5e4d9"))
		"museum":
			if textures.has("guard"):
				draw_texture_rect_region(textures["guard"], Rect2(223, 139, 43, 94), Rect2(187, 9, 689, 1510), Color(0.72, 0.96, 1.0, 0.87))
				draw_ellipse(Rect2(219, 229, 50, 7), Color(0.35, 0.83, 0.97, 0.4))
			if not flag("floor_clean"):
				for i in range(6):
					draw_ellipse(Rect2(303 + i * 8, 261 + sin(i * 1.7) * 4, 21, 11), Color(0.29, 0.78, 0.69, 0.57))
					draw_circle(Vector2(312 + i * 8, 263 + sin(i * 2.1) * 4), 1.6, Color("b0ffe2"))
			if not flag("archive_taken"):
				var glow := 0.4 + sin(elapsed * 2) * 0.12
				draw_circle(Vector2(435, 166), 18, Color(0.27, 0.68, 0.98, glow))
				draw_circle(Vector2(435, 166), 9, Color("87ceff"))
				draw_arc(Vector2(435, 166), 16, 0, TAU, 32, Color("d0eeff"), 1)
				if not flag("floor_clean"):
					draw_line(Vector2(402, 142), Vector2(470, 196), Color(0.98, 0.39, 0.37, 0.5), 1)
					draw_line(Vector2(470, 142), Vector2(402, 196), Color(0.98, 0.39, 0.37, 0.5), 1)

func draw_ellipse(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(32):
		var angle := float(index) / 32 * TAU
		points.append(rect.get_center() + Vector2(cos(angle) * rect.size.x * 0.5, sin(angle) * rect.size.y * 0.5))
	draw_colored_polygon(points, color)

func _draw_player() -> void:
	var moving := player.distance_to(destination) > 1.0 and not dialogue_panel.visible and not sound_is_open() and not flag("complete")
	var bob := sin(elapsed * 11) * 1.2 if moving else sin(elapsed * 1.7) * 0.3
	var perspective_height := lerpf(105.0, 140.0, clampf((player.y - 257.0) / 49.0, 0.0, 1.0))
	draw_ellipse(Rect2(player.x - 22, player.y - 4, 45, 10), Color(0.01, 0.015, 0.025, 0.45))
	if moving and textures.has("roger_walk"):
		var walk_texture: Texture2D = textures["roger_walk"]
		var regions := [Rect2(0, 55, 480, 910), Rect2(480, 55, 288, 910), Rect2(768, 55, 432, 910), Rect2(1200, 55, 336, 910)]
		var frame := int(elapsed * 6.0) % 4
		var source: Rect2 = regions[frame]
		var height := perspective_height + 3.0
		var width := source.size.x / source.size.y * height
		var target := Rect2(player.x - width * 0.5, player.y - height, width, height)
		if not facing_right:
			target.position.x += width
			target.size.x = -width
		draw_texture_rect_region(walk_texture, target, source)
	elif textures.has("roger"):
		var height := perspective_height
		var width := 509.0 / 1495.0 * height
		var target := Rect2(player.x - width * 0.5, player.y - height + bob, width, height)
		if not facing_right:
			target.position.x += width
			target.size.x = -width
		draw_texture_rect_region(textures["roger"], target, Rect2(267, 12, 509, 1495))
	else:
		var x := player.x
		var y := player.y + bob
		draw_circle(Vector2(x, y - 66), 9, Color("d6ad8a"))
		draw_rect(Rect2(x - 10, y - 58, 20, 34), Color("3d7c98"))
		draw_rect(Rect2(x - 9, y - 27, 7, 26), Color("263b50"))
		draw_rect(Rect2(x + 2, y - 27, 7, 26), Color("263b50"))
		draw_rect(Rect2(x - 14, y - 54, 4, 25), Color("d6ad8a"))
		draw_rect(Rect2(x + 10, y - 54, 4, 25), Color("d6ad8a"))
