extends SceneTree

# Text/layout checks require X11/Xvfb; use isolated XDG_DATA_HOME.
var game
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

func snapshot() -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.state))

func find_button(label: String, parent: Node = game) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == label and child.is_visible_in_tree():
			return child
		var found := find_button(label, child)
		if found != null:
			return found
	return null

func fill_pockets() -> void:
	game.new_game(false)
	for item in ["service chit", "grease", "keycard", "maintenance pass", "mop", "cleaner", "star map", "novelty badge", "monolith coupon", "empty flask", "vine rope", "bog herb", "fryer sludge", "service token", "frozen memo", "arcade code", "mirror wrench", "academy badge", "mop certificate", "trade chit", "sunglasses", "bucket of eternal suds", "squeegee of power", "vacuum of infinite suction", "broom of cosmic sweep", "polish of eternal shine", "mop of destiny"]:
		game.add_item(item)
	game.update_hud()

func check_inventory_layout_and_selection() -> void:
	fill_pockets()
	await process_frame
	await process_frame
	var before := snapshot()
	expect(game.inventory_buttons.size() == game.state["inventory"].size(), "Every campaign item is represented in the footer inventory")
	expect(not game.inventory_scroll.get_global_rect().intersects(game.sound_button.get_global_rect()), "The scrolling inventory viewport stays clear of the Sound control")
	expect(game.inventory_scroll.get_h_scroll_bar().visible, "A large inventory exposes a horizontal scrollbar instead of overflowing the footer")
	await press_key(KEY_I)
	await process_frame
	expect(game.inventory_is_open() and game.inventory_grid_buttons.size() == game.state["inventory"].size(), "I opens a full inventory grid containing every item")
	expect(game.inventory_grid.columns == 2, "The full inventory uses two readable columns")
	var grid_scroll: ScrollContainer = game.inventory_grid.get_parent()
	expect(grid_scroll.get_v_scroll_bar().visible, "The grid scrolls when the campaign inventory needs more than one page")
	var buttons: Array = game.inventory_grid_buttons.values()
	for index in range(buttons.size()):
		var button: Button = buttons[index]
		expect(button.size.x >= 250.0 and button.size.y >= 35.0, "The full inventory gives " + button.text + " a readable selection target")
		if index > 0:
			expect(not button.get_global_rect().intersects(buttons[index - 1].get_global_rect()), "Neighboring inventory choices do not overlap")
	var last_item := "mop of destiny"
	grid_scroll.scroll_vertical = int(grid_scroll.get_v_scroll_bar().max_value)
	await process_frame
	await process_frame
	var last_button: Button = game.inventory_grid_buttons[last_item]
	expect(grid_scroll.get_global_rect().encloses(last_button.get_global_rect()), "Scrolling reveals the entire final artifact button inside the grid viewport")
	await click_control(last_button)
	expect(not game.inventory_is_open() and game.selected == last_item and snapshot() == before, "A real grid click selects the final artifact and closes pockets without consuming it")
	await press_key(KEY_I)
	grid_scroll = game.inventory_grid.get_parent()
	grid_scroll.scroll_vertical = int(grid_scroll.get_v_scroll_bar().max_value)
	await process_frame
	await process_frame
	await click_control(game.inventory_grid_buttons[last_item])
	expect(game.selected.is_empty() and not game.inventory_is_open() and snapshot() == before, "Selecting the same grid item again deselects it and preserves every pocket item")
	completed_cases["inventory_layout"] = true

func check_inventory_modal() -> void:
	fill_pockets()
	var before := snapshot()
	game.open_inventory()
	var position_before: Vector2 = game.player
	game.destination = Vector2(530, 298)
	var steps := int(game.audio.event_counts.get("step_a", 0)) + int(game.audio.event_counts.get("step_b", 0))
	for frame in range(90):
		game._process(1.0 / 60.0)
	expect(game.player == position_before and int(game.audio.event_counts.get("step_a", 0)) + int(game.audio.event_counts.get("step_b", 0)) == steps, "Full pockets pause walking and footsteps")
	await click(Vector2(18, 580))
	game.perform_action("cook", "Talk")
	expect(game.inventory_is_open() and snapshot() == before and game.pending_interaction.is_empty(), "Pockets block background clicks and direct world actions")
	expect(not game.save_game(), "An open transient inventory cannot replace the normal checkpoint")
	game.toggle_sound_panel()
	expect(not game.sound_is_open() and game.inventory_is_open(), "Pockets block competing Sound options so their item choices remain the active modal")
	await press_key(KEY_ESCAPE)
	expect(not game.inventory_is_open(), "Escape closes the active pockets panel")
	game.destination = game.player
	game.show_title()
	game.open_inventory()
	expect(game.title_is_open() and not game.inventory_is_open(), "The title blocks hidden inventory opening")
	game.new_game(false)
	game.enter_room("monolith")
	game.open_burger_shift()
	game.open_inventory()
	expect(game.burger_is_open() and not game.inventory_is_open(), "The burger modal blocks hidden inventory opening")
	game.close_burger_shift()
	game.open_travel_menu()
	game.open_inventory()
	expect(game.travel_is_open() and not game.inventory_is_open(), "Navigation blocks hidden inventory opening")
	game.choose_destination("dock")
	game.open_inventory()
	expect(game.flight_is_active() and not game.inventory_is_open(), "Flight blocks hidden inventory opening")
	game.new_game(false)
	completed_cases["inventory_modal"] = true

func check_death_layout_and_retry() -> void:
	fill_pockets()
	var before := snapshot()
	var position_before: Vector2 = game.player
	game.show_death("Roger has discovered that the warning sign was an instruction, rather than a dare. The universe briefly applauds his commitment to experimental janitorial science.")
	await process_frame
	await process_frame
	expect(game.death_is_open() and game.death_panel.get_global_rect().encloses(game.death_retry_button.get_global_rect()), "Comic failure displays an accessible Retry button inside its panel")
	expect(game.death_text.get_minimum_size().y <= game.death_text.size.y and game.death_text.get_global_rect().end.y < game.death_retry_button.get_global_rect().position.y, "The complete comic failure text fits above Retry")
	await click(Vector2(20, 580))
	game.perform_action("cook", "Talk")
	game.open_inventory()
	game.open_travel_menu()
	game.toggle_sound_panel()
	expect(game.death_is_open() and not game.inventory_is_open() and not game.travel_is_open() and not game.sound_is_open() and snapshot() == before, "Failure blocks hidden world actions and other interaction panels")
	expect(not game.save_game(), "A comic failure cannot overwrite a playable checkpoint")
	await click_control(game.death_retry_button)
	expect(not game.death_is_open() and game.player == position_before and game.destination == position_before and snapshot() == before, "Retry restores the same room position with all campaign items and progress intact")
	game.show_death("An unexpected suction demonstration reduces Roger to a highly qualified draft.")
	await press_key(KEY_ENTER)
	expect(not game.death_is_open() and snapshot() == before, "Enter activates Retry without losing puzzle progress")
	completed_cases["death"] = true

func check_finale_layout() -> void:
	game.new_game(false)
	game.enter_room("clone_chamber")
	game.state["campaign"]["clone_armed"] = true
	game.state["campaign"]["clone_sabotaged"] = true
	game.state["score"] = 295
	game.add_item("mop of destiny")
	game.perform_action("object")
	await process_frame
	await process_frame
	expect(game.flag("complete") and game.state["score"] == 300 and game.finale_panel.visible, "The real final shutdown handler supplies the complete 300-point ending text")
	var play_again := find_button("Play again", game.finale_panel)
	expect(play_again != null and game.finale_panel.get_global_rect().encloses(play_again.get_global_rect()), "The completed adventure keeps Play again reachable within the ending panel")
	expect(game.finale_text.get_minimum_size().y <= game.finale_text.size.y and game.finale_panel.get_global_rect().encloses(game.finale_text.get_global_rect()), "All three ending paragraphs fit inside the finale panel without clipping (text %s; minimum %s; panel %s)" % [game.finale_text.get_global_rect(), game.finale_text.get_minimum_size(), game.finale_panel.get_global_rect()])
	if play_again != null:
		expect(game.finale_text.get_global_rect().end.y + 4.0 <= play_again.get_global_rect().position.y, "The full ending stays clear of Play again (text ends %s; button starts %s)" % [game.finale_text.get_global_rect().end.y, play_again.get_global_rect().position.y])
	var hint := find_button("Hint")
	expect(game.score_label.get_minimum_size().x <= game.score_label.size.x and hint != null and game.score_label.get_global_rect().end.x + 2.0 <= hint.get_global_rect().position.x, "The complete SCORE 300/300 header fits before Hint")
	completed_cases["finale"] = true

func check() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Campaign inventory/death layout verification requires a graphical display; omit --headless and use X11/Xvfb.")
		quit(1)
		return
	create_timer(40.0).timeout.connect(func():
		push_error("Campaign UI integration test timed out")
		quit(1))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.travel.set_process(false)
	await check_inventory_layout_and_selection()
	await check_inventory_modal()
	await check_death_layout_and_retry()
	await check_finale_layout()
	for scenario in ["inventory_layout", "inventory_modal", "death", "finale"]:
		expect(completed_cases.get(scenario, false), "Scenario completed without script interruption: " + scenario)
	game.queue_free()
	await create_timer(0.15).timeout
	if failures == 0:
		print("PASS: %d campaign UI checks — large scrolling/grid inventory, real item selection/deselection, layout, modal input, readable comic failures and Retry" % checks)
	else:
		push_error("%d of %d campaign UI checks failed" % [failures, checks])
	quit(0 if failures == 0 else 1)
