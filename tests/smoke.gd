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

func write_legacy_checkpoint(old_finished_build := false) -> void:
	# Earlier chapter builds put the mop straight into inventory at the locker.
	var snapshot: Dictionary = game.state.duplicate(true)
	snapshot["flags"].erase("mop_taken")
	if old_finished_build:
		snapshot["flags"].erase("chapter_one_complete")
		snapshot["flags"]["complete"] = true
		snapshot["room"] = "dock"
	snapshot["player"] = [game.player.x, game.player.y]
	var file := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	expect(file != null, "Legacy checkpoint fixture can be written to the isolated test save slot")
	if file != null:
		file.store_string(JSON.stringify(snapshot))
		file.close()

func click(point: Vector2, mouse_button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = mouse_button
		event.pressed = pressed
		event.position = point
		event.global_position = point
		# Treat positions as logical viewport coordinates, including in headless mode.
		root.push_input(event, true)
		await process_frame

func click_button(button: Button) -> void:
	# Canvas stretching scales Control coordinates before viewport input routing.
	await click(button.get_global_transform_with_canvas() * (button.size / 2.0))

func click_hotspot(id: String, mouse_button := MOUSE_BUTTON_LEFT) -> void:
	await click(game.get_global_transform_with_canvas() * game.hotspots[id].get_center(), mouse_button)

func press_key(keycode: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func finish_walk(dismiss_dialogue := true) -> void:
	# Drive normal movement/arrival code with a deterministic simulation interval.
	for frame in range(900):
		game._process(1.0 / 60.0)
		if game.pending_interaction.is_empty() and game.player.distance_to(game.destination) <= 1.0:
			break
	if dismiss_dialogue:
		game.close_dialogue()
	expect(game.pending_interaction.is_empty() and game.player.distance_to(game.destination) <= 1.0, "Click movement reaches its destination and completes the queued action")

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
	expect(game.verb == "Interact", "New game starts with automatic object interactions")
	var walk_button_exists := false
	for button in game.verb_buttons:
		walk_button_exists = walk_button_exists or button.text == "Walk"
	expect(not walk_button_exists and game.verb_buttons.size() == 3, "Interface offers optional Look, Use, Talk without a Walk button")
	await click_hotspot("exit")
	finish_walk()
	expect(game.state["room"] == "diner", "Broken hatch blocks leaving the diner")
	await click_hotspot("grease")
	finish_walk()
	expect(not has_item("grease"), "Taking grease requires the cook's permission")
	act("panel", "Use", "grease")
	expect(not flag("hatch_fixed"), "An unowned inventory item cannot solve the hatch")

	# Floor clicks always move, without requiring any movement verb.
	await click(Vector2(125, 302))
	expect(game.player.distance_to(game.destination) > 1.0 and game.pending_interaction.is_empty(), "Default floor click starts walking instead of an object interaction")
	finish_walk()
	expect(game.player.distance_to(Vector2(125, 302)) <= 1.0, "Automatic walking reaches the clicked floor location")
	await click_button(game.verb_buttons[0])
	expect(game.verb == "Look", "Optional Look button selects inspection mode")
	await click(Vector2(185, 302))
	expect(game.player.distance_to(game.destination) > 1.0 and game.verb == "Look", "Floor click still walks while Look is selected")
	finish_walk()
	expect(game.player.distance_to(Vector2(185, 302)) <= 1.0, "Walking in Look mode reaches the clicked floor location")
	await click_button(game.verb_buttons[0])
	expect(game.verb == "Interact", "Clicking an active override returns to automatic interactions")
	await click_hotspot("news")
	finish_walk(false)
	expect(game.dialogue_panel.visible and game.verb == "Interact", "Primary news-terminal click automatically opens story inspection dialogue")
	game.close_dialogue()
	await click_hotspot("cook", MOUSE_BUTTON_RIGHT)
	finish_walk(false)
	expect(game.dialogue_panel.visible and not flag("cook_help"), "Right-clicking a person inspects them without triggering their conversation puzzle")
	game.close_dialogue()
	await click_button(game.verb_buttons[2])
	await click(Vector2(185, 302), MOUSE_BUTTON_RIGHT)
	expect(game.verb == "Interact" and game.selected.is_empty(), "Right-clicking empty floor cancels the optional verb")
	await click(Vector2(125, 302))
	finish_walk()
	await click_hotspot("cook")
	expect(not game.pending_interaction.is_empty(), "Clicking the cook queues an interaction")
	finish_walk()
	expect(flag("cook_help") and has_item("service chit") and game.verb == "Interact", "Primary cook click approaches and automatically talks, without choosing Talk")
	var score_after_cook: int = game.state["score"]
	act("cook", "Talk")
	expect(game.state["inventory"].count("service chit") == 1, "Repeated dialogue cannot duplicate the service chit")
	expect(game.state["score"] == score_after_cook, "Repeated puzzle dialogue cannot duplicate score")
	await click_hotspot("grease")
	finish_walk()
	expect(has_item("grease"), "Primary grease click automatically picks it up after permission")
	act("grease")
	expect(game.state["inventory"].count("grease") == 1, "Grease can be collected only once")
	act("panel")
	expect(not flag("hatch_fixed"), "The panel requires a selected inventory item")
	act("panel", "Use", "service chit")
	expect(not flag("hatch_fixed") and has_item("service chit"), "Wrong-item use leaves puzzle state and inventory intact")
	await process_frame
	await click_button(game.inventory_buttons["grease"])
	expect(game.selected == "grease", "Inventory mouse click selects the item for the next object interaction")
	await click(Vector2(185, 302), MOUSE_BUTTON_RIGHT)
	expect(game.selected.is_empty() and game.verb == "Interact", "Right-clicking empty floor cancels the selected inventory item")
	await click_button(game.inventory_buttons["grease"])
	await press_key(KEY_ESCAPE)
	expect(game.selected.is_empty() and game.verb == "Interact", "Escape cancels the selected item and returns to automatic interactions")
	await click_button(game.inventory_buttons["grease"])
	await click(Vector2(185, 302))
	expect(game.player.distance_to(game.destination) > 1.0 and game.selected == "grease", "Floor click walks while preserving the selected inventory item")
	finish_walk()
	expect(game.player.distance_to(Vector2(185, 302)) <= 1.0 and game.selected == "grease", "Walking with a selected item reaches the clicked floor and keeps the item selected")
	await click_hotspot("panel")
	finish_walk()
	expect(flag("hatch_fixed") and not has_item("grease"), "Using grease at the panel repairs the hatch and consumes it")
	# Cancel a remaining override, then use the door directly.
	await click(Vector2(185, 302), MOUSE_BUTTON_RIGHT)
	await click_hotspot("exit")
	finish_walk()
	expect(game.state["room"] == "dock", "Repaired hatch leads to the dock")
	act("museum")
	expect(game.state["room"] == "dock", "Museum entry requires authorization")
	act("shuttle")
	expect(not flag("complete") and game.travel_is_open() and game.travel.destination_buttons["labion"].disabled, "Labion departure stays locked without coordinates while local travel is offered")
	game.close_travel_menu()
	act("locker")
	expect(not has_item("mop") and not has_item("cleaner"), "Locker cannot provide tools without a keycard")
	act("terminal")
	expect(not flag("museum_access"), "Terminal authorization requires the keycard")
	act("guard", "Use", "service chit")
	expect(has_item("keycard") and has_item("maintenance pass") and not has_item("service chit"), "Guard trades the service chit for access items")
	act("guard", "Use", "service chit")
	expect(game.state["inventory"].count("keycard") == 1, "Repeated guard interaction cannot duplicate access items")
	await click_hotspot("mop")
	finish_walk()
	expect(not has_item("mop"), "Dock mop cannot be picked up before its magnetic lock is released")
	act("locker", "Use", "keycard")
	expect(flag("locker_open") and has_item("cleaner") and not has_item("mop"), "Keycard opens locker, supplies cleaner, and releases the world mop")
	expect(game.save_game(), "Fresh checkpoint can be saved before the unlocked world mop is collected")
	game.new_game(false)
	expect(game.load_game() and not flag("mop_taken") and has_item("cleaner"), "Fresh locker checkpoint leaves the uncollected mop available")
	expect(game.hotspot_at(game.hotspots["mop"].get_center()) == "mop", "Uncollected mop remains clickable after loading a fresh checkpoint")
	await click_hotspot("mop")
	finish_walk()
	expect(has_item("mop") and flag("mop_taken"), "Primary world mop click automatically picks it up after unlocking")
	expect(game.hotspot_at(game.hotspots["mop"].get_center()) != "mop", "Collected mop is removed from world interaction targets")
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
	write_legacy_checkpoint()
	game.new_game(false)
	expect(game.load_game() and flag("mop_taken") and has_item("mop"), "Legacy save with a mop in inventory marks the world pickup as already taken")
	expect(game.state == saved_state, "Legacy mop checkpoint normalizes to the current puzzle state")

	act("museum")
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
	act("exit")
	expect(game.state["room"] == "dock", "Museum exit returns to dock")
	act("shuttle")
	expect(not flag("complete") and game.travel.destination_buttons["labion"].disabled, "Possessing the map alone does not program the shuttle")
	game.close_travel_menu()
	act("terminal", "Use", "star map")
	expect(flag("coordinates_set") and not has_item("star map"), "Terminal accepts the map and programs destination coordinates")
	act("shuttle")
	game.choose_destination("labion")
	game.finish_flight()
	expect(flag("chapter_one_complete") and not flag("complete") and game.state["room"] == "labion_dock" and game.state["score"] == 100, "The programmed shuttle completes the opening and reaches playable Labion at 100 points")
	expect(game.save_game(), "Saving the completed chapter succeeds")
	game.new_game(false)
	expect(not flag("chapter_one_complete") and not flag("complete"), "New game resets opening and campaign completion")
	expect(game.load_game() and flag("chapter_one_complete") and not flag("complete"), "Loading opening completion restores the continuing adventure")
	expect(not game.finale_panel.visible and game.state["room"] == "labion_dock", "Loading completed opening progress shows playable Labion and no campaign finale")
	write_legacy_checkpoint(true)
	game.new_game(false)
	expect(game.load_game() and flag("chapter_one_complete") and not flag("complete") and flag("mop_taken") and game.state["room"] == "dock" and game.state["score"] == 100, "Legacy completed opening saves migrate to a continuing 100-point dock checkpoint without resurrecting the consumed mop")
	game.close_dialogue()
	game.new_game(false)
	expect(game.selected.is_empty() and game.pending_interaction.is_empty() and game.verb == "Interact", "New game clears selected inventory and pending movement and restores automatic interactions")
	if failures == 0:
		print("PASS: %d checks — opening puzzle chain, blocked progression, mouse routing, inventory puzzles, save/load/reset, playable Labion continuation" % checks)
	else:
		push_error("%d of %d smoke checks failed" % [failures, checks])
	game.queue_free()
	# Let the audio mixer release the scene's active WAV playback before exit.
	await create_timer(0.15).timeout
	quit(0 if failures == 0 else 1)
