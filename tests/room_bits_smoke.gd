extends SceneTree

# Run with isolated XDG_DATA_HOME: this harness writes the real local save slot.
var game
var bits_script
var checks := 0
var failures := 0
var completed_cases: Dictionary = {}

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

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

func clickable_point(id: String) -> Vector2:
	var rect: Rect2 = game.room_hotspots(game.state["room"])[id]["rect"]
	# Several existing story targets intentionally share part of the room.
	# Find a real unoccluded click location, not merely a bounding-box center.
	for row in range(1, 10):
		for column in range(1, 10):
			var point := rect.position + rect.size * Vector2(column / 10.0, row / 10.0)
			if game.hotspot_at(point) == id:
				return point
	return Vector2(-1, -1)

func click_hotspot(id: String, mouse_button := MOUSE_BUTTON_LEFT) -> void:
	var point := clickable_point(id)
	expect(point.x >= 0, "A visible mouse target exists for " + id)
	if point.x >= 0:
		await click(game.get_global_transform_with_canvas() * point, mouse_button)

func finish_walk() -> void:
	for frame in range(900):
		game._process(1.0 / 60.0)
		if game.pending_interaction.is_empty() and game.player.distance_to(game.destination) <= 1.0:
			break
	expect(game.pending_interaction.is_empty() and game.player.distance_to(game.destination) <= 1.0, "Roger reaches the optional interaction and performs its queued action")

func act(id: String, action := "Use", item := "") -> void:
	game.close_dialogue()
	game.perform_action(id, action, item)

func story_snapshot() -> Dictionary:
	return {"room": game.state["room"], "score": game.state["score"], "flags": game.state["flags"].duplicate(true), "inventory": game.state["inventory"].duplicate()}

func write_checkpoint(snapshot: Dictionary) -> void:
	var file := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	expect(file != null, "Isolated optional-content checkpoint can be written")
	if file != null:
		file.store_string(JSON.stringify(snapshot))
		file.close()

func check_targets() -> void:
	var optional_count := 0
	for room_id in bits_script.HOTSPOTS:
		game.new_game(false)
		game.enter_room(room_id)
		var merged: Dictionary = game.room_hotspots(room_id)
		for id in game.HOTSPOTS[room_id]:
			expect(merged.has(id), "Optional room content preserves story target " + room_id + ":" + id)
			expect(clickable_point(id).x >= 0, "Story target remains reachable by mouse: " + room_id + ":" + id)
		for id in bits_script.HOTSPOTS[room_id]:
			optional_count += 1
			expect(merged.has(id) and clickable_point(id).x >= 0, "Optional object is included and clickable: " + room_id + ":" + id)
	expect(optional_count >= 19, "The four rooms provide at least nineteen optional interactions")
	completed_cases["targets"] = true

func check_all_inspections() -> void:
	for room_id in bits_script.HOTSPOTS:
		game.new_game(false)
		game.enter_room(room_id)
		var before: Dictionary = game.state.duplicate(true)
		for id in bits_script.HOTSPOTS[room_id]:
			act(id, "Look")
			expect(game.dialogue_panel.visible and not game.dialogue_text.text.contains("Worth another look"), "Every optional prop has its own inspection response: " + id)
			expect(game.state == before, "Inspection is completely read-only for " + id)
	game.close_dialogue()
	completed_cases["inspection"] = true

func check_optional_click(room_id: String, id: String) -> void:
	game.new_game(false)
	game.enter_room(room_id, Vector2(45, 302))
	var baseline := story_snapshot()
	var bits_before: Dictionary = game.state.get("bits", {}).duplicate(true)
	await click_hotspot(id, MOUSE_BUTTON_RIGHT)
	finish_walk()
	expect(game.dialogue_panel.visible, "Right-click inspection opens optional-object dialogue: " + id)
	expect(game.state.get("bits", {}) == bits_before and story_snapshot() == baseline, "Inspection leaves optional counters and all story state unchanged: " + id)
	game.close_dialogue()
	game.player = Vector2(45, 302)
	game.destination = game.player
	await click_hotspot(id)
	expect(not game.pending_interaction.is_empty(), "Left-click queues walking before the optional action: " + id)
	finish_walk()
	expect(game.dialogue_panel.visible, "Contextual optional interaction opens its response: " + id)
	expect(game.state.get("bits", {}) != bits_before, "Using the optional object records its outcome: " + id)
	expect(game.state["flags"] == baseline["flags"] and game.state["score"] == baseline["score"], "Optional fun leaves progression flags and /100 score unchanged: " + id)
	completed_cases[room_id + ":mouse"] = true

func check_repeats() -> void:
	game.new_game(false)
	var baseline := story_snapshot()
	var first_coffee_line := ""
	for use_index in range(1, 4):
		act("bit_coffee")
		expect(game.state.get("bits", {}).get("uses:bit_coffee", 0) == use_index, "Coffee machine counts actual repeat interactions")
		expect(game.state.get("bits", {}).get("coffee_strength", -1) == use_index % 3, "Coffee setting cycles rather than staying at its first outcome")
		if use_index == 1:
			first_coffee_line = game.dialogue_text.text
		elif use_index == 2:
			expect(game.dialogue_text.text != first_coffee_line, "Changing the coffee setting gives a different comic response")
	expect(story_snapshot() == baseline, "Repeated optional coffee actions leave every story field unchanged")
	game.close_dialogue()
	game.enter_room("dock")
	act("bit_helmet")
	expect(game.state.get("bits", {}).get("helmet_visor_closed", false), "Using the novelty helmet closes its saved visor toggle")
	act("bit_helmet")
	expect(not game.state.get("bits", {}).get("helmet_visor_closed", true), "Using the helmet again reopens its visor")
	game.close_dialogue()
	game.enter_room("museum")
	for use_index in range(1, 4):
		act("bit_telescope")
		expect(game.state.get("bits", {}).get("telescope_filter", -1) == use_index % 3, "Telescope filters cycle through three persistent views")
	act("bit_model")
	expect(game.state.get("bits", {}).get("model_lit", false), "Ship-model lighting switches on")
	act("bit_model")
	expect(not game.state.get("bits", {}).get("model_lit", true), "Ship-model lighting switches back off")
	game.close_dialogue()
	completed_cases["repeats"] = true

func check_wrong_items() -> void:
	for room_id in bits_script.HOTSPOTS:
		game.new_game(false)
		game.enter_room(room_id)
		for puzzle_item in ["keycard", "maintenance pass", "mop", "cleaner", "grease", "service chit"]:
			game.add_item(puzzle_item)
		var baseline := story_snapshot()
		var bits_before: Dictionary = game.state.get("bits", {}).duplicate(true)
		for id in bits_script.HOTSPOTS[room_id]:
			act(id, "Use", "keycard")
			expect(game.dialogue_panel.visible, "Wrong-item optional action has an object-specific response: " + id)
			expect(story_snapshot() == baseline and game.state.get("bits", {}) == bits_before, "Wrong items preserve all puzzle items, progress, score, and optional state: " + id)
	game.close_dialogue()
	completed_cases["wrong_items"] = true

func check_badge() -> void:
	game.new_game(false)
	game.enter_room("museum", Vector2(45, 302))
	var baseline_score: int = game.state["score"]
	var baseline_flags: Dictionary = game.state["flags"].duplicate(true)
	await click_hotspot("bit_badge_tray")
	finish_walk()
	expect(game.has_item("novelty badge") and game.state.get("bits", {}).get("badge_collected", false), "The optional badge can be picked up through a real mouse interaction")
	expect(game.state["score"] == baseline_score and game.state["flags"] == baseline_flags, "Optional badge pickup does not award story points or progress")
	act("bit_badge_tray")
	expect(game.state["inventory"].count("novelty badge") == 1 and game.state.get("bits", {}).get("uses:bit_badge_tray", 0) == 2, "Repeated badge-tray interactions record jokes without duplicating the badge")
	game.close_dialogue()
	expect(clickable_point("bit_badge_tray").x >= 0, "The empty souvenir tray remains clickable after its badge is taken")
	game.add_item("service chit")
	game.add_item("keycard")
	game.add_item("maintenance pass")
	for room_id in {"diner": "cook", "dock": "guard", "museum": "guardian", "monolith": "manager"}:
		var person: String = {"diner": "cook", "dock": "guard", "museum": "guardian", "monolith": "manager"}[room_id]
		game.enter_room(room_id, Vector2(45, 302))
		var story_before := story_snapshot()
		await process_frame
		expect(game.inventory_buttons.has("novelty badge"), "Bonus badge appears as a real selectable pocket item")
		await click_control(game.inventory_buttons["novelty badge"])
		expect(game.selected == "novelty badge", "Inventory click selects the optional badge")
		await click_hotspot(person)
		finish_walk()
		expect(game.dialogue_panel.visible and game.dialogue_speaker == person, "Showing the badge gives a special in-character reaction from " + person)
		expect(game.state.get("bits", {}).get("badge:" + person, 0) == 1 and story_snapshot() == story_before, "Badge reaction records its repeat counter without consuming items or solving " + person + "'s story puzzle")
		act(person, "Use", "novelty badge")
		expect(game.state.get("bits", {}).get("badge:" + person, 0) == 2 and story_snapshot() == story_before, "Repeated badge reactions preserve original progression and inventory")
	game.close_dialogue()
	completed_cases["badge"] = true

func check_persistence() -> void:
	game.new_game(false)
	act("bit_coffee")
	act("bit_plant")
	game.close_dialogue()
	game.enter_room("dock")
	act("bit_helmet")
	game.close_dialogue()
	game.enter_room("museum")
	act("bit_model")
	act("bit_badge_tray")
	game.close_dialogue()
	var saved_bits: Dictionary = game.state.get("bits", {}).duplicate(true)
	# Godot JSON reloads numeric counters as floats. Compare their saved values
	# without treating that serialization detail as a changed game outcome.
	var expected_loaded_bits: Dictionary = JSON.parse_string(JSON.stringify(saved_bits))
	var saved_story := story_snapshot()
	expect(game.save_game(), "Optional toggles and repeat counters can be saved")
	game.new_game(false)
	expect(game.state.get("bits", {}).is_empty() and not game.has_item("novelty badge"), "New Game resets optional state and bonus inventory")
	expect(game.load_game(), "Saved optional progress can be loaded")
	expect(game.state.get("bits", {}) == expected_loaded_bits and story_snapshot() == saved_story, "Load restores exact optional toggles, repeat counters, bonus item, and story state")
	game.close_dialogue()
	act("bit_badge_tray")
	expect(game.state["inventory"].count("novelty badge") == 1, "Loaded bonus pickup cannot be collected twice")
	game.close_dialogue()
	game.enter_room("diner")
	act("bit_coffee")
	expect(game.state.get("bits", {}).get("uses:bit_coffee", 0) == 2 and game.state.get("bits", {}).get("coffee_strength", 0) == 2, "Loaded numeric counters resume the next coffee outcome correctly")
	game.new_game(false)
	var legacy: Dictionary = game.state.duplicate(true)
	legacy.erase("bits")
	legacy["player"] = [173.0, 280.0]
	write_checkpoint(legacy)
	expect(game.load_game() and game.state.get("bits", {}).is_empty(), "Earlier story checkpoints without optional bits remain valid")
	expect(game.state["score"] == 0 and game.state["flags"].is_empty() and game.state["inventory"].is_empty(), "Legacy-save normalization leaves original story progress intact")
	act("bit_coffee")
	expect(game.state.get("bits", {}).get("uses:bit_coffee", 0) == 1, "Optional interactions work after loading a legacy checkpoint")
	game.close_dialogue()
	completed_cases["persistence"] = true

func check_modal_blocking() -> void:
	game.new_game(false)
	var story_before := story_snapshot()
	var bits_before: Dictionary = game.state.get("bits", {}).duplicate(true)
	game.show_title()
	await click_hotspot("bit_coffee")
	game.perform_action("bit_coffee")
	expect(game.title_is_open() and game.pending_interaction.is_empty() and story_snapshot() == story_before and game.state.get("bits", {}) == bits_before, "Title blocks mouse and direct optional interactions underneath it")
	game.new_game(false)
	game.toggle_sound_panel()
	await click_hotspot("bit_coffee")
	game.perform_action("bit_coffee")
	expect(game.sound_panel.visible and game.pending_interaction.is_empty() and story_snapshot() == story_before and game.state.get("bits", {}) == bits_before, "Sound options block mouse and direct optional interactions underneath them")
	game.close_sound_panel()
	game.close_dialogue()
	completed_cases["modals"] = true

func check_effect_lifecycle() -> void:
	game.new_game(false)
	act("bit_coffee")
	expect(game.bit_effects.size() == 1 and game.bit_effects[0]["id"] == "bit_coffee", "The coffee gag starts its room-specific visual effect")
	var duration_before: float = game.bit_effects[0]["remaining"]
	for frame in range(120):
		game._process(1.0 / 60.0)
	expect(game.dialogue_panel.visible and is_equal_approx(game.bit_effects[0]["remaining"], duration_before), "Gag dialogue holds its visual effect until the response is dismissed")
	expect(game.save_game(), "A checkpoint can be saved while a transient gag effect is visible")
	var saved_file := FileAccess.open(game.SAVE_PATH, FileAccess.READ)
	var persisted: Variant = JSON.parse_string(saved_file.get_as_text())
	saved_file.close()
	expect(persisted is Dictionary and not persisted.has("bit_effects"), "Transient visual timers are not serialized into the saved story")
	game.close_dialogue()
	for frame in range(50):
		game._process(1.0 / 60.0)
	expect(game.bit_effects.size() == 1 and game.bit_effects[0]["remaining"] < duration_before, "Closing gag dialogue allows its short visual timer to run")
	var paused_duration: float = game.bit_effects[0]["remaining"]
	game.toggle_sound_panel()
	for frame in range(120):
		game._process(1.0 / 60.0)
	expect(is_equal_approx(game.bit_effects[0]["remaining"], paused_duration), "Sound options pause the remaining gag visual time")
	game.close_sound_panel()
	for frame in range(60):
		game._process(1.0 / 60.0)
	expect(game.bit_effects.is_empty(), "A dismissed gag effect expires instead of remaining over the artwork")
	expect(game.load_game() and game.bit_effects.is_empty() and game.state.get("bits", {}).get("coffee_strength", 0) == 1, "Load restores persistent gag settings without replaying saved transient effects")
	game.close_dialogue()
	completed_cases["effects"] = true

func check_character_only_talk() -> void:
	for room_id in bits_script.HOTSPOTS:
		game.new_game(false)
		game.enter_room(room_id)
		game.set_verb("Talk")
		for id in game.room_hotspots(room_id):
			var label: String = game.contextual_action_label(id)
			if id in ["cook", "guard", "guardian", "manager"]:
				expect(label == "Talk to", "Talk hover applies to the actual character " + id)
			else:
				expect(label != "Talk to", "Object hover describes an object action instead of conversation: " + id)
	game.new_game(false)
	game.set_verb("Talk")
	act("bit_coffee", "Talk")
	expect(game.state.get("bits", {}).get("uses:bit_coffee", 0) == 1 and game.state.get("bits", {}).get("coffee_strength", 0) == 1, "Talk override on the coffee object performs its normal brew action")
	expect(not game.state.get("bits", {}).has("talks:bit_coffee"), "Objects do not acquire conversation counters")
	game.close_dialogue()
	act("bit_menu", "Talk")
	expect(not game.burger_is_open() and game.dialogue_panel.visible, "Talk override on the diner advertisement gives directions without starting a job")
	game.close_dialogue()
	game.enter_room("monolith")
	act("shift_counter", "Talk")
	expect(game.burger_is_open(), "Talk override on the restaurant terminal opens its normal relief shift")
	game.close_burger_shift()
	game.new_game(false)
	game.enter_room("dock")
	game.set_verb("Talk")
	var before: Dictionary = game.state.duplicate(true)
	act("bit_planet", "Talk")
	expect(game.state == before and game.dialogue_panel.visible, "Talk override on the distant planet performs read-only inspection")
	game.close_dialogue()
	game.new_game(false)
	expect(game.default_action("counter") == "Use" and game.contextual_action_label("counter") != "Talk to", "The table counter advertises a contextual use action")
	act("counter", "Talk")
	expect(game.flag("cook_help") and game.has_item("service chit") and game.dialogue_speaker == "cook", "Explicit Talk on the counter reaches Bex through its normal service interaction")
	game.close_dialogue()
	completed_cases["character_talk"] = true

func check() -> void:
	create_timer(40.0).timeout.connect(func():
		push_error("Optional room interaction test timed out")
		quit(1))
	bits_script = load("res://scripts/room_bits.gd")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.new_game(false)
	check_targets()
	check_all_inspections()
	await check_optional_click("diner", "bit_coffee")
	await check_optional_click("dock", "bit_crates")
	await check_optional_click("museum", "bit_telescope")
	await check_optional_click("monolith", "bit_monolith_mascot")
	check_repeats()
	check_wrong_items()
	await check_badge()
	check_persistence()
	await check_modal_blocking()
	check_effect_lifecycle()
	check_character_only_talk()
	for scenario in ["targets", "inspection", "diner:mouse", "dock:mouse", "museum:mouse", "monolith:mouse", "repeats", "wrong_items", "badge", "persistence", "modals", "effects", "character_talk"]:
		expect(completed_cases.get(scenario, false), "Scenario completed without a script interruption: " + scenario)
	game.queue_free()
	await create_timer(0.15).timeout
	if failures == 0:
		print("PASS: %d optional room checks — reachable story/extra targets, real mouse walking/inspection, repeat jokes/toggles, bonus badge reactions, wrong-item preservation, saved bits/legacy checkpoints, modal blocking" % checks)
	else:
		push_error("%d of %d optional room checks failed" % [failures, checks])
	quit(0 if failures == 0 else 1)
