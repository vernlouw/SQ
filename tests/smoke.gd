extends SceneTree

var game
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func flag(name: String) -> bool:
	return bool(game.state["flags"].get(name, false))

func has_item(name: String) -> bool:
	return game.state["inventory"].has(name)

func act(target: String, action := "Use", item := "") -> void:
	game.close_dialogue()
	game.perform_action(target, action, item)
	game.close_dialogue()

func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		# Treat positions as logical viewport coordinates, including in headless mode.
		root.push_input(event, true)
		await process_frame

func click_button(button: Button) -> void:
	# Canvas stretching scales Control coordinates before viewport input routing.
	await click(button.get_global_transform_with_canvas() * (button.size / 2.0))

func finish_walk() -> void:
	# Drive normal movement/arrival code with a deterministic simulation interval.
	for frame in range(900):
		game._process(1.0 / 60.0)
		if game.pending_interaction.is_empty():
			break
	game.close_dialogue()
	expect(game.pending_interaction.is_empty(), "Hotspot interaction must complete after walking into position")

func check() -> void:
	# If a parse/runtime failure interrupts this routine, fail instead of hanging.
	create_timer(30.0).timeout.connect(func():
		push_error("Smoke test timed out before completing")
		quit(1))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.new_game(false)
	expect(game.state["room"] == "diner", "New game starts in the diner")
	expect(game.state["inventory"].is_empty(), "New game starts without puzzle items")
	act("exit", "Walk")
	expect(game.state["room"] == "diner", "Broken hatch blocks leaving the diner")
	act("grease")
	expect(not has_item("grease"), "Taking grease requires the cook's permission")
	act("panel", "Use", "grease")
	expect(not flag("hatch_fixed"), "An unowned inventory item cannot solve the hatch")

	# Use actual mouse events for verb buttons and the world hotspot path.
	await click_button(game.verb_buttons[1])
	await click(game.get_global_transform_with_canvas() * game.hotspots["news"].get_center())
	expect(game.verb == "Look" and game.dialogue_panel.visible, "Look button and news hotspot open readable story dialogue")
	game.close_dialogue()
	await click_button(game.verb_buttons[3])
	expect(game.verb == "Talk", "Mouse clicks on the Talk button select Talk")
	await click(game.get_global_transform_with_canvas() * game.hotspots["cook"].get_center())
	expect(not game.pending_interaction.is_empty(), "Clicking the cook queues an interaction")
	finish_walk()
	expect(flag("cook_help") and has_item("service chit"), "Walking to the cook executes the requested conversation")
	var score_after_cook: int = game.state["score"]
	act("cook", "Talk")
	expect(game.state["inventory"].count("service chit") == 1, "Repeated dialogue cannot duplicate the service chit")
	expect(game.state["score"] == score_after_cook, "Repeated puzzle dialogue cannot duplicate score")
	act("grease")
	act("grease")
	expect(game.state["inventory"].count("grease") == 1, "Grease can be collected only once")
	act("panel")
	expect(not flag("hatch_fixed"), "The panel requires a selected inventory item")
	act("panel", "Use", "service chit")
	expect(not flag("hatch_fixed") and has_item("service chit"), "Wrong-item use leaves puzzle state and inventory intact")
	await process_frame
	await click_button(game.inventory_buttons["grease"])
	expect(game.selected == "grease" and game.verb == "Use", "Inventory mouse selection sets the item and Use verb")
	await click(game.get_global_transform_with_canvas() * game.hotspots["panel"].get_center())
	finish_walk()
	expect(flag("hatch_fixed") and not has_item("grease"), "Using grease at the panel repairs the hatch and consumes it")
	act("exit", "Walk")
	expect(game.state["room"] == "dock", "Repaired hatch leads to the dock")
	act("museum", "Walk")
	expect(game.state["room"] == "dock", "Museum entry requires authorization")
	act("shuttle")
	expect(not flag("complete"), "Shuttle cannot depart without destination coordinates")
	act("locker")
	expect(not has_item("mop") and not has_item("cleaner"), "Locker cannot provide tools without a keycard")
	act("terminal")
	expect(not flag("museum_access"), "Terminal authorization requires the keycard")
	act("guard", "Use", "service chit")
	expect(has_item("keycard") and has_item("maintenance pass") and not has_item("service chit"), "Guard trades the service chit for access items")
	act("guard", "Use", "service chit")
	expect(game.state["inventory"].count("keycard") == 1, "Repeated guard interaction cannot duplicate access items")
	act("locker", "Use", "keycard")
	expect(flag("locker_open") and has_item("mop") and has_item("cleaner"), "Keycard opens locker and supplies tools")
	act("locker", "Use", "keycard")
	expect(game.state["inventory"].count("mop") == 1 and game.state["inventory"].count("cleaner") == 1, "Locker cannot duplicate tools")
	act("terminal", "Use", "keycard")
	expect(flag("museum_access"), "Keycard authorizes museum access")

	# Save a partially completed puzzle, reset, and restore the precise game state.
	var saved_state: Dictionary = game.state.duplicate(true)
	var saved_player: Vector2 = game.player
	expect(game.save_game(), "Saving intermediate progress succeeds")
	game.new_game(false)
	expect(game.state["room"] == "diner" and game.state["flags"].is_empty() and game.state["inventory"].is_empty(), "New game clears room, flags, and inventory")
	expect(game.load_game(), "Loading intermediate progress succeeds")
	game.close_dialogue()
	expect(game.state == saved_state, "Load restores room, inventory, flags, and score")
	expect(game.player == saved_player and game.destination == saved_player, "Load restores the character position without resuming stale movement")

	act("museum", "Walk")
	expect(game.state["room"] == "museum", "Authorized museum entrance reaches the third room")
	act("plinth")
	expect(not has_item("star map"), "Unsafe museum floor blocks the star map")
	act("spill", "Use", "mop")
	expect(not flag("floor_clean") and has_item("mop"), "Dry mop cannot clear the spill")
	var inventory_before: Array = game.state["inventory"].duplicate()
	game.combine_items("keycard", "maintenance pass")
	game.close_dialogue()
	expect(game.state["inventory"] == inventory_before, "Invalid item combinations do not consume inventory")
	game.combine_items("cleaner", "mop")
	game.close_dialogue()
	expect(has_item("charged mop") and not has_item("cleaner") and not has_item("mop"), "Combining cleaner and mop creates a charged mop and consumes both ingredients")
	act("spill", "Use", "charged mop")
	expect(not flag("floor_clean") and has_item("charged mop"), "Guardian cleaning authorization is required before cleaning")
	act("guardian", "Talk")
	act("guardian", "Use", "maintenance pass")
	expect(flag("cleaning_mode"), "Maintenance pass switches the guardian into cleaning mode")
	act("spill", "Use", "charged mop")
	expect(flag("floor_clean") and not has_item("charged mop"), "Authorized cleaning removes spill and consumes the charged mop")
	act("plinth")
	act("plinth")
	expect(game.state["inventory"].count("star map") == 1, "Cleaning unlocks the map, which can only be collected once")
	act("exit", "Walk")
	expect(game.state["room"] == "dock", "Museum exit returns to dock")
	act("shuttle")
	expect(not flag("complete"), "Possessing the map alone does not program the shuttle")
	act("terminal", "Use", "star map")
	expect(flag("coordinates_set") and not has_item("star map"), "Terminal accepts the map and programs destination coordinates")
	act("shuttle")
	expect(flag("complete"), "Programmed shuttle completes the chapter")
	expect(game.save_game(), "Saving the completed chapter succeeds")
	game.new_game(false)
	expect(not flag("complete"), "New game resets the ending")
	expect(game.load_game() and flag("complete"), "Loading completed progress restores the ending")
	expect(game.finale_panel.visible, "Loading completed progress displays the chapter ending")
	game.close_dialogue()
	game.new_game(false)
	expect(game.selected.is_empty() and game.pending_interaction.is_empty(), "New game clears selected inventory and pending movement")
	if failures == 0:
		print("PASS: %d checks — three rooms, blocked progression, mouse routing, inventory puzzles, save/load/reset, chapter ending" % checks)
	else:
		push_error("%d of %d smoke checks failed" % [failures, checks])
	quit(0 if failures == 0 else 1)
