extends SceneTree

# Use isolated XDG_DATA_HOME. These checks write the game's normal save slot.
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

func start_restaurant() -> void:
	game.new_game(false)
	game.enter_room("monolith")

func snapshot() -> Dictionary:
	return {"room": game.state["room"], "score": game.state["score"], "flags": game.state["flags"].duplicate(true), "inventory": game.state["inventory"].duplicate()}

func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
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

func find_button(label: String, parent: Node = game) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == label and child.is_visible_in_tree():
			return child
		var found := find_button(label, child)
		if found != null:
			return found
	return null

func choose_via_mouse(choice_id: String) -> void:
	var status: Dictionary = shift.status(game)
	var label := ""
	for choice in status["choices"]:
		if choice["id"] == choice_id:
			label = choice["label"]
	var button := find_button(label)
	expect(button != null, "Current order renders a clickable option for " + choice_id)
	if button != null:
		await click_control(button)

func finish_walk() -> void:
	for frame in range(900):
		game._process(1.0 / 60.0)
		if game.pending_interaction.is_empty() and game.player.distance_to(game.destination) <= 1.0:
			break
	expect(game.pending_interaction.is_empty(), "Roger reaches the order terminal and completes its queued interaction")

func act(id: String, action := "Use", item := "") -> void:
	game.close_dialogue()
	game.perform_action(id, action, item)
	game.close_dialogue()

func check_choice_geometry() -> void:
	var buttons: Array = game.burger_choice_buttons.values()
	var choice_top := INF
	var choice_bottom := 0.0
	var panel_rect: Rect2 = game.burger_panel.get_global_rect()
	for button in buttons:
		var rect: Rect2 = button.get_global_rect()
		choice_top = minf(choice_top, rect.position.y)
		choice_bottom = maxf(choice_bottom, rect.end.y)
		expect(panel_rect.encloses(rect), "Every food option stays inside the burger panel")
	for first in range(buttons.size()):
		for second in range(first + 1, buttons.size()):
			expect(not buttons[first].get_global_rect().intersects(buttons[second].get_global_rect()), "Long food labels cannot expand their buttons over neighboring choices")
	expect(game.burger_order.get_global_rect().end.y + 4.0 <= choice_top and game.burger_order.get_minimum_size().y <= game.burger_order.size.y, "The full customer ticket fits above the option buttons (ticket %s; minimum %s; choices start %s)" % [game.burger_order.get_global_rect(), game.burger_order.get_minimum_size(), choice_top])
	expect(game.burger_feedback.get_global_rect().position.y >= choice_bottom + 4.0 and panel_rect.encloses(game.burger_feedback.get_global_rect()), "Feedback stays below the choices and within the popup (feedback %s; panel %s; choices end %s)" % [game.burger_feedback.get_global_rect(), panel_rect, choice_bottom])

func check_open_and_retry() -> void:
	game.new_game(false)
	var diner_before: Dictionary = game.state.duplicate(true)
	act("bit_menu", "Look")
	expect(game.state == diner_before and not game.burger_is_open(), "Diner advertisement inspection is read-only")
	act("bit_menu")
	expect(not game.burger_is_open() and not shift.status(game)["started"], "The diner advert gives directions instead of opening the restaurant job")
	start_restaurant()
	var original := snapshot()
	var original_state: Dictionary = game.state.duplicate(true)
	act("shift_counter", "Look")
	expect(game.state == original_state and not game.burger_is_open(), "Inspecting the menu is read-only and does not start a shift")
	game.player = Vector2(45, 302)
	game.destination = game.player
	var menu_rect: Rect2 = game.room_hotspots()["shift_counter"]["rect"]
	await click(game.get_global_transform_with_canvas() * menu_rect.get_center())
	expect(not game.pending_interaction.is_empty(), "Empty-hand order-terminal click walks to the optional burger job")
	finish_walk()
	expect(game.burger_is_open() and shift.status(game)["started"], "Arriving at the order terminal opens the Monolith Burger popup")
	expect(shift.status(game)["index"] == 0 and snapshot() == original, "Opening the optional job preserves all main story progress")
	var order: Dictionary = shift.ORDERS[0]
	var wrong_id := ""
	for choice in order["choices"]:
		if choice["id"] != order["correct_id"]:
			wrong_id = choice["id"]
			break
	await choose_via_mouse(wrong_id)
	expect(game.burger_is_open() and shift.status(game)["index"] == 0 and not shift.status(game)["completed"], "A wrong order gives another try instead of advancing the shift")
	expect(snapshot() == original, "Wrong orders consume no puzzle items or story points")
	game.choose_burger_option(wrong_id)
	expect(shift.status(game)["index"] == 0, "Wrong-order retries remain available without a failure lockout")
	game.choose_burger_option("not_a_menu_choice")
	expect(shift.status(game)["index"] == 0 and snapshot() == original, "Unknown choice IDs cannot advance the job or change main progress")
	completed_cases["open_retry"] = true

func check_completion_and_reward() -> void:
	start_restaurant()
	for item in ["service chit", "keycard", "maintenance pass", "grease"]:
		game.add_item(item)
	game.add_item("novelty badge")
	var original := snapshot()
	game.open_burger_shift()
	expect(shift.ORDERS.size() == 3, "The optional job contains three authored customer orders")
	for index in range(3):
		var order: Dictionary = shift.ORDERS[index]
		expect(shift.status(game)["index"] == index, "Customer orders appear in their authored sequence")
		await process_frame
		check_choice_geometry()
		await choose_via_mouse(order["correct_id"])
		expect(shift.status(game)["index"] == index + 1, "Correct customer choice advances exactly one order")
		if index < 2:
			expect(not game.has_item("monolith coupon"), "A coupon is awarded only after all three orders")
	expect(shift.status(game)["completed"] and game.state["inventory"].count("monolith coupon") == 1, "Finishing the third order awards exactly one Monolith coupon")
	var rewarded_inventory: Array = original["inventory"].duplicate()
	rewarded_inventory.append("monolith coupon")
	expect(game.state["inventory"] == rewarded_inventory and game.state["flags"] == original["flags"] and game.state["score"] == original["score"], "Optional completion adds only its coupon and leaves the /100 story untouched")
	expect(game.inventory_buttons.size() == 6, "Badge, coupon, and four story items each have a usable inventory button")
	var inventory_right := 0.0
	for button in game.inventory_buttons.values():
		inventory_right = maxf(inventory_right, button.get_global_rect().end.x)
	expect(inventory_right + 4.0 <= game.sound_button.get_global_rect().position.x, "Six pocket items fit without overlapping the Sound control")
	game.choose_burger_option(shift.ORDERS[2]["correct_id"])
	game.close_burger_shift()
	game.open_burger_shift()
	game.choose_burger_option(shift.ORDERS[0]["correct_id"])
	expect(shift.status(game)["completed"] and game.state["inventory"].count("monolith coupon") == 1, "Repeated completion or reopening cannot farm another coupon")
	game.close_burger_shift()
	game.enter_room("diner")
	act("cook", "Use", "monolith coupon")
	expect(game.has_item("monolith coupon") and not shift.status(game)["coupon_redeemed"], "Bex directs Roger to Monolith Burger without consuming its coupon")
	game.enter_room("monolith")
	await process_frame
	await click_control(game.inventory_buttons["monolith coupon"])
	expect(game.selected == "monolith coupon", "The earned coupon can be selected from Roger's pockets")
	await click(game.get_global_transform_with_canvas() * game.room_hotspots()["manager"]["rect"].get_center())
	finish_walk()
	expect(shift.status(game)["coupon_redeemed"] and not game.has_item("monolith coupon"), "Flipp accepts and consumes the completed shift's coupon")
	game.close_dialogue()
	expect(snapshot() == original, "Redeeming the coupon preserves every main puzzle item, story flag, and point")
	act("manager", "Use", "monolith coupon")
	expect(snapshot() == original and shift.status(game)["coupon_redeemed"], "Repeated coupon redemption cannot consume other items or alter the story")
	game.open_burger_shift()
	expect(shift.status(game)["completed"] and not game.has_item("monolith coupon"), "A redeemed completed shift does not award another coupon")
	game.close_burger_shift()
	completed_cases["completion_reward"] = true

func check_reopen_and_save() -> void:
	start_restaurant()
	game.open_burger_shift()
	game.choose_burger_option(shift.ORDERS[0]["correct_id"])
	game.close_burger_shift()
	expect(not game.burger_is_open() and shift.status(game)["index"] == 1, "Closing the job keeps its partially completed order sequence")
	game.open_burger_shift()
	expect(game.burger_is_open() and shift.status(game)["index"] == 1, "Reopening resumes with the next customer")
	expect(game.save_game(), "A partial optional job can be saved")
	start_restaurant()
	expect(not shift.status(game)["started"], "New Game clears optional burger progress")
	expect(game.load_game() and not game.burger_is_open() and shift.status(game)["index"] == 1, "Load restores the partial job without reopening a transient popup")
	game.close_dialogue()
	game.open_burger_shift()
	game.choose_burger_option(shift.ORDERS[1]["correct_id"])
	game.choose_burger_option(shift.ORDERS[2]["correct_id"])
	game.close_burger_shift()
	expect(game.save_game(), "Completed coupon progress can be saved")
	start_restaurant()
	expect(game.load_game() and shift.status(game)["completed"] and game.state["inventory"].count("monolith coupon") == 1, "Loading completion restores exactly one reward")
	game.close_dialogue()
	act("manager", "Use", "monolith coupon")
	expect(game.save_game(), "Coupon redemption can be saved")
	start_restaurant()
	expect(game.load_game() and shift.status(game)["coupon_redeemed"] and not game.has_item("monolith coupon"), "Loading redeemed progress cannot resurrect the coupon")
	game.close_dialogue()
	completed_cases["reopen_save"] = true

func check_modal_input() -> void:
	start_restaurant()
	game.open_burger_shift()
	var original := snapshot()
	var burger_before: Dictionary = game.state.get("burger_shift", {}).duplicate(true)
	var player_before: Vector2 = game.player
	game.destination = Vector2(450, 280)
	var step_count := int(game.audio.event_counts.get("step_a", 0)) + int(game.audio.event_counts.get("step_b", 0))
	for frame in range(120):
		game._process(1.0 / 60.0)
	expect(game.player == player_before and int(game.audio.event_counts.get("step_a", 0)) + int(game.audio.event_counts.get("step_b", 0)) == step_count, "The burger popup pauses walking and footsteps")
	await click(Vector2(10, 300))
	game.perform_action("manager", "Talk")
	expect(snapshot() == original and game.state.get("burger_shift", {}) == burger_before and game.pending_interaction.is_empty(), "Popup background clicks and hidden world actions are blocked")
	await press_key(KEY_ESCAPE)
	expect(not game.burger_is_open() and shift.status(game)["index"] == 0, "Escape closes the optional job without changing its progress")
	game.destination = game.player
	game.show_title()
	game.open_burger_shift()
	game.choose_burger_option(shift.ORDERS[0]["correct_id"])
	expect(game.title_is_open() and not game.burger_is_open() and game.state.get("burger_shift", {}) == burger_before, "Title blocks hidden job opening and order choices")
	start_restaurant()
	game.toggle_sound_panel()
	var before_sound: Dictionary = game.state.duplicate(true)
	game.open_burger_shift()
	game.choose_burger_option(shift.ORDERS[0]["correct_id"])
	expect(game.sound_panel.visible and not game.burger_is_open() and game.state == before_sound, "Sound options block hidden job opening and order choices")
	game.close_sound_panel()
	game.open_burger_shift()
	game.toggle_sound_panel()
	var before_options: Dictionary = game.state.get("burger_shift", {}).duplicate(true)
	game.choose_burger_option(shift.ORDERS[0]["correct_id"])
	expect(game.sound_panel.visible and game.state.get("burger_shift", {}) == before_options, "Sound options over an open job block its covered choices")
	await press_key(KEY_ESCAPE)
	expect(game.burger_is_open() and not game.sound_panel.visible, "Escape closes Sound first and preserves the job beneath it")
	await press_key(KEY_ESCAPE)
	expect(not game.burger_is_open(), "A second Escape closes the job")
	completed_cases["modal_input"] = true

func check() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Burger layout verification requires a graphical display; omit --headless and use X11/Xvfb in CI.")
		quit(1)
		return
	create_timer(40.0).timeout.connect(func():
		push_error("Burger-shift integration test timed out")
		quit(1))
	shift = load("res://scripts/burger_shift.gd")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	await check_open_and_retry()
	await check_completion_and_reward()
	check_reopen_and_save()
	await check_modal_input()
	for scenario in ["open_retry", "completion_reward", "reopen_save", "modal_input"]:
		expect(completed_cases.get(scenario, false), "Scenario completed without script interruption: " + scenario)
	game.queue_free()
	await create_timer(0.15).timeout
	if failures == 0:
		print("PASS: %d burger checks — restaurant terminal mouse routing, order retries/sequence, single coupon/redemption, reopen/save/load, paused gameplay, modal input" % checks)
	else:
		push_error("%d of %d burger checks failed" % [failures, checks])
	quit(0 if failures == 0 else 1)
