extends SceneTree

# Use isolated XDG_DATA_HOME. This harness writes the normal local save slot.
var game
var shift
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

func progress() -> Dictionary:
	var saved: Dictionary = game.state.duplicate(true)
	saved.erase("room")
	saved.erase("travel")
	saved.erase("visited_rooms")
	if saved.get("campaign", null) is Dictionary:
		saved["campaign"].erase("visited")
	# JSON checkpoints represent numeric optional counters as floats.
	return JSON.parse_string(JSON.stringify(saved))

func click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
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

func click_hotspot(id: String) -> void:
	var rect: Rect2 = game.room_hotspots()[id]["rect"]
	var point := Vector2(-1, -1)
	for row in range(1, 10):
		for column in range(1, 10):
			var candidate := rect.position + rect.size * Vector2(column / 10.0, row / 10.0)
			if game.hotspot_at(candidate) == id:
				point = candidate
				break
		if point.x >= 0:
			break
	expect(point.x >= 0, "A real unoccluded mouse target exists for " + id)
	if point.x >= 0:
		await click(game.get_global_transform_with_canvas() * point)

func finish_walk() -> void:
	for frame in range(900):
		game._process(1.0 / 60.0)
		if game.pending_interaction.is_empty() and game.player.distance_to(game.destination) <= 1.0:
			break
	expect(game.pending_interaction.is_empty(), "Walking reaches the shuttle berth and opens navigation")

func act(id: String, action := "Use", item := "") -> void:
	game.close_dialogue()
	game.perform_action(id, action, item)
	game.close_dialogue()

func fly(destination_id: String) -> void:
	game.open_travel_menu()
	expect(game.choose_destination(destination_id), "Available route begins flight to " + destination_id)
	game.finish_flight()
	expect(not game.flight_is_active() and not game.travel_is_open(), "Arrival closes transient flight/navigation controls")

func check_routes_and_cancel() -> void:
	game.new_game(false)
	game.open_travel_menu()
	expect(not game.travel_is_open(), "Navigation cannot open in a room without a shuttle")
	game.enter_room("dock", Vector2(75, 302))
	var before := progress()
	await click_hotspot("shuttle")
	expect(not game.pending_interaction.is_empty(), "Clicking the actual shuttle queues Roger's approach")
	finish_walk()
	expect(game.travel_is_open() and not game.flight_is_active(), "Approaching the shuttle opens destination selection")
	expect(game.travel.destination_buttons["monolith"].visible and not game.travel.destination_buttons["monolith"].disabled, "Monolith Burger is available before the museum coordinates")
	expect(game.travel.destination_buttons["labion"].visible and game.travel.destination_buttons["labion"].disabled, "Labion is visibly locked until the star map is programmed")
	await click_control(game.travel.destination_buttons["labion"])
	expect(game.travel_is_open() and not game.flight_is_active() and not game.flag("complete"), "A real click on locked Labion cannot launch or complete the chapter")
	expect(not game.choose_destination("labion") and not game.choose_destination("dock") and not game.choose_destination("unknown"), "The route API rejects locked, same-location, and unknown destinations")
	expect(progress() == before, "Rejected routes change no inventory, optional progress, flags, or score")
	await click_control(game.travel.close_button)
	expect(not game.travel_is_open() and game.state["room"] == "dock", "Cancel returns to the departure room without flying")
	expect(not game.choose_destination("monolith") and not game.flight_is_active(), "Choosing a route with navigation closed cannot start a hidden flight")
	game.open_travel_menu()
	await press_key(KEY_ESCAPE)
	expect(not game.travel_is_open() and progress() == before, "Escape cancels navigation and preserves all progress")
	completed_cases["routes"] = true

func check_actual_trip() -> void:
	game.new_game(false)
	game.enter_room("dock")
	for item in ["keycard", "maintenance pass", "novelty badge"]:
		game.add_item(item)
	game.update_hud()
	var before := progress()
	await process_frame
	await click_control(game.inventory_buttons["keycard"])
	await click_control(game.inventory_buttons["keycard"])
	expect(game.selected.is_empty() and progress() == before, "Clicking the selected pocket item again deselects it without spending the item")
	game.open_travel_menu()
	await click_control(game.travel.destination_buttons["monolith"])
	expect(game.flight_is_active() and not game.travel_is_open() and game.state["room"] == "dock", "A destination click shows flight before changing the departure room")
	expect(game.travel.flight_labels.visible and game.textures.has("flight_monolith"), "Flight uses the illustrated exterior and visible route information")
	expect(progress() == before, "Launching the optional flight spends no items or story points")
	game.finish_flight()
	expect(game.state["room"] == "monolith" and not game.flight_is_active(), "The outbound flight reaches the fourth playable restaurant room")
	expect(game.textures.has("room_monolith") and game.textures.has("portrait_manager"), "The restaurant has its own illustrated room and manager portrait")
	expect(game.room_hotspots().has("manager") and game.room_hotspots().has("shift_counter") and game.room_hotspots().has("exit"), "Restaurant arrival exposes a character, a usable order terminal, and a return berth")
	expect(game.audio.music_player.playing and game.audio.ambience_player.playing and game.audio.music_player.stream.data == game.audio.streams["music_monolith"].data and game.audio.ambience_player.stream.data == game.audio.streams["ambience_monolith"].data, "Arrival switches both audio channels to Monolith Burger")
	expect(progress() == before and game.state.get("travel", {}).get("visited_monolith", false) and game.state.get("travel", {}).get("trips", 0) == 1, "Arrival records only travel history and preserves all story/optional progress")
	act("manager", "Talk")
	expect(game.is_character("manager") and not game.flag("cook_help") and game.state["score"] == 0, "The new manager is a separate character and does not solve Bex's puzzle")
	game.player = Vector2(45, 302)
	game.destination = game.player
	await click_hotspot("exit")
	finish_walk()
	expect(game.state["room"] == "monolith_berth" and not game.travel_is_open(), "The restaurant doorway enters its separate playable shuttle berth")
	await click_hotspot("right")
	finish_walk()
	expect(game.travel_is_open() and game.travel.destination_buttons["dock"].visible and not game.travel.destination_buttons["monolith"].visible, "The restaurant berth offers a real return flight rather than a direct room shortcut")
	expect(game.travel.destination_buttons["labion"].visible and game.travel.destination_buttons["labion"].disabled and not game.choose_destination("labion"), "The berth displays Labion with the same unmet coordinate gate as the service dock")
	await click_control(game.travel.destination_buttons["dock"])
	expect(game.flight_is_active() and game.state["room"] == "monolith_berth", "Return selection starts flight while Roger remains in the restaurant's service berth")
	game.travel._process(game.travel.FLIGHT_DURATION + 0.1)
	expect(game.state["room"] == "dock" and not game.flight_is_active(), "Normal flight timing automatically returns Roger to the service dock")
	expect(progress() == before and game.state.get("travel", {}).get("trips", 0) == 2, "Round trip preserves inventory and puzzle state while counting two completed flights")
	var trips := int(game.state.get("travel", {}).get("trips", 0))
	game.finish_flight()
	expect(int(game.state.get("travel", {}).get("trips", 0)) == trips, "Repeated arrival cannot duplicate a completed trip")
	completed_cases["actual_trip"] = true

func check_modal_input() -> void:
	game.new_game(false)
	game.enter_room("dock")
	game.open_travel_menu()
	var before := progress()
	var position_before: Vector2 = game.player
	game.destination = Vector2(70, 302)
	var footsteps := int(game.audio.event_counts.get("step_a", 0)) + int(game.audio.event_counts.get("step_b", 0))
	for frame in range(90):
		game._process(1.0 / 60.0)
	expect(game.player == position_before and int(game.audio.event_counts.get("step_a", 0)) + int(game.audio.event_counts.get("step_b", 0)) == footsteps, "Navigation pauses walking and footsteps")
	await click(Vector2(10, 350))
	game.perform_action("guard", "Talk")
	expect(game.travel_is_open() and progress() == before and game.pending_interaction.is_empty(), "Navigation blocks background clicks and direct hidden world actions")
	game.toggle_sound_panel()
	expect(game.sound_is_open() and game.travel_is_open(), "Sound options layer above navigation")
	expect(not game.choose_destination("monolith") and not game.flight_is_active(), "Covered navigation choices cannot launch through Sound options")
	await press_key(KEY_ESCAPE)
	expect(not game.sound_is_open() and game.travel_is_open(), "Escape closes Sound first and keeps navigation beneath it")
	await press_key(KEY_ESCAPE)
	expect(not game.travel_is_open(), "A second Escape closes navigation")
	game.destination = game.player
	game.show_title()
	game.open_travel_menu()
	expect(game.title_is_open() and not game.travel_is_open(), "The title blocks hidden navigation")
	game.new_game(false)
	game.enter_room("monolith")
	game.open_burger_shift()
	game.open_travel_menu()
	expect(game.burger_is_open() and not game.travel_is_open(), "The order popup blocks hidden navigation")
	game.close_burger_shift()
	game.open_travel_menu()
	game.choose_destination("dock")
	position_before = game.player
	before = progress()
	game.destination = Vector2(75, 302)
	for frame in range(90):
		game._process(1.0 / 60.0)
	game.perform_action("manager", "Talk")
	game.open_burger_shift()
	game.toggle_sound_panel()
	expect(game.flight_is_active() and game.player == position_before and progress() == before and not game.burger_is_open() and not game.sound_is_open(), "Flight pauses world movement and blocks hidden actions and covered panels")
	await press_key(KEY_M)
	await press_key(KEY_F5)
	expect(game.flight_is_active() and not game.sound_is_open(), "World keyboard shortcuts cannot open panels over flight")
	await press_key(KEY_SPACE)
	expect(game.state["room"] == "dock" and not game.flight_is_active() and game.pending_interaction.is_empty(), "Space skips flight to arrival without queuing a world action")
	game.open_travel_menu()
	game.choose_destination("monolith")
	await click(Vector2(380, 310))
	expect(game.state["room"] == "monolith" and not game.flight_is_active() and game.pending_interaction.is_empty() and not game.burger_is_open(), "A flight click skips to arrival and is consumed before the new room can act on it")
	completed_cases["modals"] = true

func check_checkpoints() -> void:
	game.new_game(false)
	game.enter_room("dock")
	fly("monolith")
	act("bit_monolith_mascot")
	game.open_burger_shift()
	game.choose_burger_option(shift.ORDERS[0]["correct_id"])
	game.close_burger_shift()
	var before := progress()
	var saved_position: Vector2 = game.player
	expect(game.save_game(), "Restaurant progress and a partial shift can be saved")
	game.open_travel_menu()
	game.choose_destination("dock")
	expect(game.flight_is_active() and not game.save_game(), "An unfinished flight cannot replace the saved room checkpoint")
	expect(game.load_game(), "Loading a checkpoint succeeds during an unfinished flight")
	expect(game.state["room"] == "monolith" and not game.flight_is_active() and not game.travel_is_open() and not game.burger_is_open(), "Load cancels all transient travel/job panels and restores the saved restaurant")
	expect(progress() == before and game.player == saved_position and game.destination == saved_position, "Load preserves restaurant interactions, partial order, items, and precise player position")
	game.open_travel_menu()
	expect(not game.save_game(), "Open navigation cannot replace the last playable-room checkpoint")
	var file := FileAccess.open(game.SAVE_PATH, FileAccess.READ)
	var checkpoint: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	expect(checkpoint["room"] == "monolith" and not checkpoint.has("flight_destination") and not checkpoint.has("flight_elapsed"), "Blocked travel saves leave the playable room and no transient flight state in the checkpoint")
	game.new_game(false)
	expect(not game.flight_is_active() and not game.travel_is_open() and not game.state.has("travel"), "New Game resets optional travel history and cancels panels")
	expect(game.load_game() and game.state["room"] == "monolith" and not game.travel_is_open(), "A saved open navigation menu loads as the restaurant room")
	game.close_dialogue()
	var legacy := {"room": "dock", "inventory": ["keycard"], "flags": {"hatch_fixed": true}, "score": 30, "player": [246, 286]}
	file = FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	expect(game.load_game() and game.state["room"] == "dock" and game.has_item("keycard") and game.state["score"] == 30, "Earlier three-room saves without travel/job state remain valid")
	game.close_dialogue()
	fly("monolith")
	expect(game.state["room"] == "monolith" and game.has_item("keycard") and game.state["score"] == 30, "A legacy checkpoint can take the new local flight without losing its puzzle state")
	completed_cases["checkpoints"] = true

func check_optional_job_and_mission() -> void:
	game.new_game(false)
	act("cook", "Talk")
	act("grease")
	act("panel", "Use", "grease")
	act("exit")
	var before := progress()
	fly("monolith")
	game.open_burger_shift()
	for order in shift.ORDERS:
		game.choose_burger_option(order["correct_id"])
	game.close_burger_shift()
	expect(shift.status(game)["completed"] and game.state["inventory"].count("monolith coupon") == 1, "The actual restaurant awards one coupon for its three completed orders")
	act("manager", "Use", "monolith coupon")
	expect(shift.status(game)["coupon_redeemed"] and not game.has_item("monolith coupon"), "The actual manager redeems the earned restaurant meal")
	expect(game.state["flags"] == before["flags"] and game.state["score"] == before["score"] and game.state["inventory"] == before["inventory"], "The entire side job leaves main puzzle items, flags, and /100 score intact")
	fly("dock")
	act("guard", "Use", "service chit")
	act("locker", "Use", "keycard")
	act("mop")
	act("terminal", "Use", "keycard")
	act("museum")
	game.combine_items("cleaner", "mop")
	game.close_dialogue()
	act("guardian", "Use", "maintenance pass")
	act("spill", "Use", "charged mop")
	act("plinth")
	act("exit")
	act("shuttle")
	expect(game.travel_is_open() and game.travel.destination_buttons["labion"].disabled and not game.flag("complete"), "Recovering the map still requires programming the main destination")
	game.close_travel_menu()
	act("terminal", "Use", "star map")
	expect(game.flag("coordinates_set") and not game.has_item("star map"), "The original map puzzle programs Labion after the optional restaurant visit")
	act("shuttle")
	expect(not game.travel.destination_buttons["labion"].disabled, "Programming coordinates unlocks the Labion route")
	expect(game.choose_destination("labion") and game.flight_is_active() and not game.flag("complete"), "Labion departure shows the actual flight before completing the chapter")
	expect(game.textures.has("flight_labion"), "The main destination has its own imported Labion flight illustration")
	await press_key(KEY_ENTER)
	expect(game.flag("chapter_one_complete") and not game.flag("complete") and game.state["score"] == 100 and game.state["room"] == "labion_dock" and not game.finale_panel.visible, "Labion arrival preserves the original 100-point opening and continues into its playable planet")
	expect(shift.status(game)["completed"] and shift.status(game)["coupon_redeemed"], "Main completion retains the optional restaurant's reward history")
	game.finish_flight()
	game.open_travel_menu()
	expect(game.state["score"] == 100 and game.travel_is_open() and not game.flag("complete"), "The completed opening retains return travel without duplicating points or ending the campaign")
	completed_cases["mission"] = true

func check() -> void:
	create_timer(40.0).timeout.connect(func():
		push_error("Shuttle travel integration test timed out")
		quit(1))
	shift = load("res://scripts/burger_shift.gd")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.travel.set_process(false)
	await check_routes_and_cancel()
	await check_actual_trip()
	await check_modal_input()
	check_checkpoints()
	await check_optional_job_and_mission()
	for scenario in ["routes", "actual_trip", "modals", "checkpoints", "mission"]:
		expect(completed_cases.get(scenario, false), "Scenario completed without a script interruption: " + scenario)
	game.queue_free()
	await create_timer(0.15).timeout
	if failures == 0:
		print("PASS: %d travel checks — real route clicks, outbound/return flights, fourth room, locked Labion, modal input, restaurant job, preserved story, checkpoints/legacy saves, opening continuation" % checks)
	else:
		push_error("%d of %d travel checks failed" % [failures, checks])
	quit(0 if failures == 0 else 1)
