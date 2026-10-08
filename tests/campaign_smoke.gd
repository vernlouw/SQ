extends SceneTree

# Run with isolated XDG_DATA_HOME. This harness uses the real checkpoint slot.
var game
var campaign
var checks := 0
var failures := 0
var visited: Dictionary = {}
var completed_cases: Dictionary = {}

const ARTIFACTS := ["bucket of eternal suds", "squeegee of power", "vacuum of infinite suction", "broom of cosmic sweep", "polish of eternal shine", "mop of destiny"]

func _initialize() -> void:
	call_deferred("check")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func state_snapshot() -> Dictionary:
	return JSON.parse_string(JSON.stringify(game.state))

func story_snapshot() -> Dictionary:
	return {"flags": game.state["flags"].duplicate(true), "inventory": game.state["inventory"].duplicate(), "score": game.state["score"], "campaign": game.state.get("campaign", {}).duplicate(true)}

func record_room() -> void:
	var id: String = game.state["room"]
	if visited.has(id):
		return
	visited[id] = true
	expect(game.ROOM_NAMES.has(id), "The campaign enters a registered playable room: " + id)
	expect(game.textures.has("room_" + id), "The room uses its own imported illustration: " + id)
	expect(game.room_hotspots().size() >= 3, "The room exposes several actual interactions rather than a travel-only screen: " + id)
	var before := story_snapshot()
	var destination := Vector2(220, 300) if game.player.distance_to(Vector2(220, 300)) > 10.0 else Vector2(330, 300)
	game.destination = destination
	for frame in range(600):
		game._process(1.0 / 60.0)
		if game.player.distance_to(destination) <= 1.0:
			break
	expect(game.player.distance_to(destination) <= 1.0, "Roger can walk across the playable floor in " + id)
	expect(story_snapshot() == before, "Walking changes no puzzle items, flags, or score in " + id)

func act(id: String, action := "Use", item := "") -> void:
	game.close_dialogue()
	game.selected = ""
	game.perform_action(id, action, item)
	game.close_dialogue()
	record_room()

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

func clickable_point(id: String) -> Vector2:
	var rect: Rect2 = game.room_hotspots()[id]["rect"]
	for row in range(1, 10):
		for column in range(1, 10):
			var point := rect.position + rect.size * Vector2(column / 10.0, row / 10.0)
			if game.hotspot_at(point) == id:
				return point
	return Vector2(-1, -1)

func click_hotspot(id: String, button := MOUSE_BUTTON_LEFT) -> void:
	var point := clickable_point(id)
	expect(point.x >= 0, "A real, unobstructed mouse target exists for " + game.state["room"] + ":" + id)
	if point.x >= 0:
		await click(game.get_global_transform_with_canvas() * point, button)

func finish_walk() -> void:
	for frame in range(900):
		game._process(1.0 / 60.0)
		if game.pending_interaction.is_empty() and game.player.distance_to(game.destination) <= 1.0:
			break
	expect(game.pending_interaction.is_empty(), "Normal walking reaches and executes the queued campaign interaction")
	record_room()

func fly(id: String) -> void:
	game.close_dialogue()
	game.open_travel_menu()
	expect(game.travel_is_open() and game.choose_destination(id), "The unlocked route starts a real flight to " + id)
	expect(game.flight_is_active(), "Route selection shows a flight before arrival")
	game.finish_flight()
	expect(not game.flight_is_active(), "Arrival ends the transient flight")
	record_room()

func assert_unique_inventory() -> void:
	var unique: Dictionary = {}
	for item in game.state["inventory"]:
		expect(not unique.has(item), "An item is owned at most once: " + str(item))
		unique[item] = true

func checkpoint_roundtrip() -> void:
	game.close_dialogue()
	var saved := state_snapshot()
	var position_before: Vector2 = game.player
	expect(game.save_game(), "Campaign checkpoint saves the current region and puzzle state")
	game.new_game(false)
	expect(game.load_game(), "Campaign checkpoint reload succeeds")
	game.close_dialogue()
	expect(state_snapshot() == saved and game.player == position_before, "Reload restores every campaign flag/item/score and player position")
	expect(not game.finale_panel.visible, "Intermediate campaign checkpoints remain playable rather than opening the finale")
	if game.state["score"] == 280:
		# Keep one genuine pre-finale checkpoint for optional inventory/death captures.
		var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(game.SAVE_PATH), ProjectSettings.globalize_path("user://campaign_preview_save.json"))
		if error != OK:
			failures += 1
			push_error("Could not retain the campaign preview checkpoint")

func move_to(id: String, expected_room: String) -> void:
	act(id)
	expect(game.state["room"] == expected_room, "A usable passage reaches " + expected_room)

func wrong_item(id: String, item := "keycard") -> void:
	var before := story_snapshot()
	act(id, "Use", item)
	expect(story_snapshot() == before, "A wrong item preserves inventory, score, flags, and route progress at " + game.state["room"] + ":" + id)

func repeat_action(id: String, action := "Use", item := "") -> void:
	var before := story_snapshot()
	act(id, action, item)
	expect(story_snapshot() == before, "Repeating a solved action cannot duplicate rewards or consume other items at " + game.state["room"] + ":" + id)

func locked_route(id: String) -> void:
	game.close_dialogue()
	game.open_travel_menu()
	var before := story_snapshot()
	expect(game.travel_is_open() and game.travel.destination_buttons.has(id) and game.travel.destination_buttons[id].disabled, "Navigation displays the locked next destination: " + id)
	expect(not game.choose_destination(id) and not game.flight_is_active() and story_snapshot() == before, "Locked regional route cannot launch or alter progress: " + id)
	game.close_travel_menu()

func fail_and_retry(id: String) -> void:
	var before := state_snapshot()
	var position_before: Vector2 = game.player
	act(id)
	expect(game.death_is_open() and not game.finale_panel.visible, "The actual hazard opens comic failure and Retry: " + game.state["room"] + ":" + id)
	game.destination = Vector2(530, 299)
	var steps := int(game.audio.event_counts.get("step_a", 0)) + int(game.audio.event_counts.get("step_b", 0))
	for frame in range(90):
		game._process(1.0 / 60.0)
	game.perform_action("pickup")
	expect(game.player == position_before and state_snapshot() == before and int(game.audio.event_counts.get("step_a", 0)) + int(game.audio.event_counts.get("step_b", 0)) == steps, "Comic failure pauses movement/audio and blocks hidden pickup actions without losing progress")
	await click_control(game.death_retry_button)
	expect(not game.death_is_open() and state_snapshot() == before and game.player == position_before and game.destination == position_before, "A real Retry click restores the same room and preserves all items, flags, and score")

func check_opening_and_early_gate() -> void:
	game.new_game(false)
	visited.clear()
	record_room()
	expect(game.ROOM_NAMES.size() >= 30 and campaign.ROOM_NAMES.size() == game.ROOM_NAMES.size(), "The runtime registers at least thirty playable rooms independently of title/flight/menu screens")
	act("cook", "Talk")
	act("grease")
	act("panel", "Use", "grease")
	move_to("exit", "dock")
	fly("monolith")
	var before := story_snapshot()
	act("campaign_left")
	expect(game.state["room"] == "monolith" and story_snapshot() == before, "Early restaurant access cannot bypass Labion's legendary kitchen credential")
	move_to("exit", "monolith_berth")
	move_to("right", "monolith_berth")
	expect(game.travel_is_open(), "The service berth airlock opens actual shuttle navigation")
	game.close_travel_menu()
	fly("dock")
	act("guard", "Use", "service chit")
	act("locker", "Use", "keycard")
	act("mop")
	act("terminal", "Use", "keycard")
	move_to("museum", "museum")
	act("guardian", "Use", "maintenance pass")
	game.combine_items("cleaner", "mop")
	game.close_dialogue()
	act("spill", "Use", "charged mop")
	act("plinth")
	move_to("exit", "dock")
	act("terminal", "Use", "star map")
	fly("labion")
	expect(game.state["room"] == "labion_dock" and game.state["score"] == 100 and game.flag("chapter_one_complete") and not game.flag("complete") and not game.finale_panel.visible, "The opening leads into playable Labion at 100 points and keeps the full campaign running")
	completed_cases["opening"] = true

func check_labion() -> void:
	locked_route("plexi")
	act("pickup")
	expect(game.has_item("empty flask"), "Labion supplies the sealed flask required for the final sabotage ingredient")
	repeat_action("pickup")
	move_to("left", "labion_jungle")
	var before := story_snapshot()
	await click(game.get_global_transform_with_canvas() * Vector2(270, 301))
	finish_walk()
	expect(game.player.distance_to(Vector2(270, 301)) <= 1.0 and story_snapshot() == before, "A real floor click walks Roger inside a new campaign location without solving a puzzle")
	await click_hotspot("pickup", MOUSE_BUTTON_RIGHT)
	finish_walk()
	expect(game.dialogue_panel.visible and story_snapshot() == before, "Right-clicking the jungle rope inspects it without collecting it")
	game.close_dialogue()
	await click_hotspot("pickup")
	finish_walk()
	game.close_dialogue()
	expect(game.has_item("vine rope") and game.state["score"] == 105, "Actual mouse approach collects the rope and its authored puzzle points")
	repeat_action("pickup")
	move_to("right", "labion_bog")
	act("right")
	expect(game.state["room"] == "labion_bog" and not game.has_item("bog herb"), "The uncrossed bog blocks forward travel and herb pickup")
	await fail_and_retry("object")
	wrong_item("object")
	act("object", "Use", "vine rope")
	expect(game.has_item("bog herb") and not game.has_item("vine rope"), "The rope anchors the crossing and yields the medicinal herb exactly once")
	repeat_action("object", "Use", "vine rope")
	move_to("right", "labion_gate")
	act("right")
	expect(game.state["room"] == "labion_gate", "The sick guard blocks the shrine until treated")
	wrong_item("npc")
	act("npc", "Use", "bog herb")
	expect(not game.has_item("bog herb"), "The gate consumes only the medicinal herb")
	repeat_action("npc", "Use", "bog herb")
	move_to("right", "labion_shrine")
	act("pickup")
	expect(not game.has_item(ARTIFACTS[0]), "The Bucket remains sealed until maintenance authorization")
	wrong_item("object")
	act("object", "Use", "maintenance pass")
	repeat_action("object", "Use", "maintenance pass")
	act("pickup")
	expect(game.has_item(ARTIFACTS[0]) and game.state["score"] == 135, "The complete Labion puzzle yields the Bucket and 35 authored points")
	repeat_action("pickup")
	checkpoint_roundtrip()
	move_to("right", "labion_dock")
	fly("monolith")
	completed_cases["labion"] = true

func check_monolith() -> void:
	move_to("campaign_left", "monolith_kitchen")
	var before := story_snapshot()
	act("object", "Use", "empty flask")
	expect(story_snapshot() == before and game.has_item("empty flask") and not game.has_item("fryer sludge"), "The pressurized trap preserves the flask and needs the berth valve first")
	move_to("left", "monolith")
	move_to("exit", "monolith_berth")
	act("object")
	repeat_action("object")
	move_to("left", "monolith")
	move_to("campaign_left", "monolith_kitchen")
	wrong_item("object")
	act("object", "Use", "empty flask")
	expect(game.has_item("fryer sludge") and not game.has_item("empty flask"), "Kitchen collection bottles sludge and consumes only its empty flask")
	repeat_action("object", "Use", "empty flask")
	act("npc", "Talk")
	expect(game.has_item("service token"), "The kitchen cook supplies the records token after the sludge sample")
	repeat_action("npc", "Talk")
	move_to("right", "monolith_freezer")
	wrong_item("object")
	act("object", "Use", "service token")
	expect(game.has_item("frozen memo") and not game.has_item("service token"), "The freezer trades only the staff token for its memo")
	repeat_action("object", "Use", "service token")
	move_to("right", "monolith_arcade")
	act("npc", "Talk")
	expect(not game.state.get("campaign", {}).get("plexi_unlocked", false), "The arcade attendant cannot unlock the planet before the memo is decoded")
	act("object", "Use", "frozen memo")
	expect(game.has_item("arcade code") and game.has_item("fryer sludge"), "Astro Chicken produces the route code while retaining the finale sludge")
	repeat_action("object", "Use", "frozen memo")
	act("npc", "Talk")
	repeat_action("npc", "Talk")
	expect(game.state["score"] == 170 and game.state.get("campaign", {}).get("plexi_unlocked", false), "The four service rooms complete the Monolith story and unlock Plexi-Prime")
	before = story_snapshot()
	expect(not game.combine_items(ARTIFACTS[0], "fryer sludge") and story_snapshot() == before, "Invalid artifact combinations preserve both the relic and the final sabotage ingredient")
	game.close_dialogue()
	move_to("right", "monolith_berth")
	fly("plexi")
	completed_cases["monolith"] = true

func check_plexi() -> void:
	locked_route("starcon")
	move_to("right", "plexi_plaza")
	act("pickup")
	expect(game.has_item("mirror wrench"), "The plaza supplies the gallery alignment tool")
	repeat_action("pickup")
	move_to("right", "plexi_gallery")
	wrong_item("object")
	act("object", "Use", "mirror wrench")
	repeat_action("object", "Use", "mirror wrench")
	move_to("right", "plexi_control")
	act("object")
	act("right")
	expect(game.state["room"] == "plexi_control" and not game.state.get("campaign", {}).get("plexi_vault_open", false), "Aligned mirrors alone cannot open an unauthorized vault")
	wrong_item("npc")
	var before := story_snapshot()
	await click_hotspot("npc", MOUSE_BUTTON_RIGHT)
	finish_walk()
	expect(game.dialogue_panel.visible and story_snapshot() == before, "Actual inspection of the new Robo-Janitor stays read-only")
	game.close_dialogue()
	act("npc", "Use", "maintenance pass")
	repeat_action("npc", "Use", "maintenance pass")
	act("object")
	repeat_action("object")
	move_to("right", "plexi_vault")
	act("pickup")
	expect(game.has_item(ARTIFACTS[1]) and game.state["score"] == 205, "The mirror and authorization puzzle yields the Squeegee and its complete 35-point region")
	repeat_action("pickup")
	checkpoint_roundtrip()
	move_to("right", "plexi_dock")
	fly("starcon")
	completed_cases["plexi"] = true

func check_starcon() -> void:
	locked_route("polysorbate")
	move_to("right", "starcon_hall")
	act("npc", "Talk")
	expect(game.has_item("academy badge"), "Registration supplies one academy badge")
	repeat_action("npc", "Talk")
	var before := story_snapshot()
	await click_hotspot("return", MOUSE_BUTTON_RIGHT)
	finish_walk()
	expect(game.state["room"] == "starcon_hall" and story_snapshot() == before, "Inspecting the academy's dock return stays in the hall and preserves all progress")
	game.close_dialogue()
	await click_hotspot("return")
	finish_walk()
	game.close_dialogue()
	expect(game.state["room"] == "starcon_dock" and story_snapshot() == before, "A real click walks through the lower-left academy return to its dock without points or item loss")
	move_to("right", "starcon_hall")
	await click_hotspot("right")
	finish_walk()
	game.close_dialogue()
	expect(game.state["room"] == "starcon_simulator", "The hall's visibly labeled right doorway reaches the simulator before qualification")
	act("object", "Use", "academy badge")
	expect(not game.state.get("campaign", {}).get("simulation_passed", false) and game.state["score"] == before["score"], "The student badge alone cannot pass the practical simulator")
	act("right")
	expect(game.state["room"] == "starcon_simulator", "Entering the simulator early cannot bypass its lab gate")
	move_to("left", "starcon_class")
	move_to("left", "starcon_hall")
	move_to("left", "starcon_class")
	wrong_item("object")
	act("object", "Use", "academy badge")
	expect(game.has_item("mop certificate"), "Advanced Mop Dynamics supplies the simulator certificate")
	repeat_action("object", "Use", "academy badge")
	move_to("right", "starcon_simulator")
	act("right")
	expect(game.state["room"] == "starcon_simulator", "The lab is gated by a passed practical simulation")
	await fail_and_retry("object")
	act("object", "Use", "mop certificate")
	repeat_action("object", "Use", "mop certificate")
	move_to("right", "starcon_lab")
	act("pickup")
	expect(not game.has_item(ARTIFACTS[2]), "Passing the simulator still requires the scientist's artifact clearance")
	wrong_item("npc")
	act("npc", "Use", "mop certificate")
	repeat_action("npc", "Use", "mop certificate")
	act("pickup")
	expect(game.has_item(ARTIFACTS[2]) and game.state["score"] == 240, "Academy enrollment, training, and authorization yield the Vacuum and 35 region points")
	repeat_action("pickup")
	checkpoint_roundtrip()
	move_to("right", "starcon_dock")
	fly("polysorbate")
	completed_cases["starcon"] = true

func check_polysorbate_and_glitzon() -> void:
	locked_route("glitzon")
	move_to("right", "polysorbate_market")
	wrong_item("npc")
	act("npc", "Use", "mop certificate")
	expect(game.has_item("trade chit") and game.has_item("mop certificate"), "The vendor buys a certificate scan and preserves the original")
	repeat_action("npc", "Use", "mop certificate")
	move_to("right", "polysorbate_alley")
	var before := story_snapshot()
	act("extra")
	expect(story_snapshot() == before and not game.death_is_open(), "The optional alley token joke leaves the trade and all inventory intact")
	act("pickup")
	expect(not game.has_item(ARTIFACTS[3]), "The Broom cannot be taken before the agreed trade")
	wrong_item("object")
	act("object", "Use", "trade chit")
	expect(not game.has_item("trade chit"), "The salvage locker consumes only its agreed trade chit")
	repeat_action("object", "Use", "trade chit")
	act("pickup")
	expect(game.has_item(ARTIFACTS[3]) and game.has_item("sunglasses") and game.state["score"] == 260, "The Broom package supplies protective glasses and the 20-point region reward")
	repeat_action("pickup")
	move_to("right", "polysorbate_dock")
	fly("glitzon")
	locked_route("finale")
	move_to("right", "glitzon_boulevard")
	act("npc", "Talk")
	act("right")
	expect(game.state["room"] == "glitzon_boulevard", "The unprotected glare scanner blocks vault access")
	wrong_item("object")
	act("object", "Use", "sunglasses")
	expect(game.has_item("sunglasses"), "Glare protection does not consume the eyewear")
	repeat_action("object", "Use", "sunglasses")
	act("npc", "Talk")
	repeat_action("npc", "Talk")
	move_to("right", "glitzon_vault")
	await fail_and_retry("extra")
	act("pickup")
	expect(game.has_item(ARTIFACTS[4]) and game.state["score"] == 280, "Glitzon yields the fifth recovered artifact and the clone's final route")
	repeat_action("pickup")
	checkpoint_roundtrip()
	for artifact in ARTIFACTS.slice(0, 5):
		expect(game.state["inventory"].count(artifact) == 1, "Five-region collection retains exactly one " + artifact)
	assert_unique_inventory()
	move_to("right", "glitzon_dock")
	fly("finale")
	completed_cases["polysorbate_glitzon"] = true

func check_finale_and_full_save() -> void:
	act("pickup")
	expect(not game.has_item(ARTIFACTS[5]), "The stolen Mop remains clamped before sabotage")
	var before := story_snapshot()
	act("object", "Use", "fryer sludge")
	expect(story_snapshot() == before and game.has_item("fryer sludge"), "The closed intake preserves sludge until all five relic sockets are occupied")
	act("object")
	expect(game.state["score"] == 285 and game.state.get("campaign", {}).get("clone_armed", false), "The actual intake arms once and awards its authored five points")
	for artifact in ARTIFACTS.slice(0, 5):
		expect(not game.has_item(artifact), "The intake confiscates its specific artifact: " + artifact)
	expect(game.has_item("fryer sludge") and game.has_item("maintenance pass") and game.has_item("keycard"), "The intake leaves the contaminant and ordinary puzzle tools intact")
	repeat_action("object")
	await fail_and_retry("extra")
	checkpoint_roundtrip()
	wrong_item("object")
	act("object", "Use", "fryer sludge")
	expect(not game.has_item("fryer sludge") and game.state["score"] == 290 and game.state.get("campaign", {}).get("clone_sabotaged", false), "Sludge sabotages the machine and consumes only its contaminant bottle")
	repeat_action("object", "Use", "fryer sludge")
	act("object")
	expect(not game.flag("complete"), "Sabotage alone cannot skip recovery of the stolen Mop")
	act("pickup")
	expect(game.has_item(ARTIFACTS[5]) and game.state["score"] == 295, "The released Mop is a separate legendary pickup with five points")
	repeat_action("pickup")
	var ending_cues := int(game.audio.event_counts.get("complete", 0))
	act("object")
	expect(game.flag("complete") and game.finale_panel.visible and game.state["score"] == 300, "The final shutdown completes the full thirty-room story at exactly 300 points")
	for artifact in ARTIFACTS:
		expect(game.state["inventory"].count(artifact) == 1, "Final recovery returns exactly one of every legendary artifact: " + artifact)
	expect(int(game.audio.event_counts.get("complete", 0)) == ending_cues + 1, "Full campaign completion plays its ending cue once")
	before = story_snapshot()
	act("object")
	expect(story_snapshot() == before and int(game.audio.event_counts.get("complete", 0)) == ending_cues + 1, "Repeated finale interaction cannot duplicate artifacts, points, or ending audio")
	expect(visited.size() >= 30, "The successful walkthrough actually entered thirty distinct playable rooms")
	for room_id in campaign.ROOM_NAMES:
		expect(visited.has(room_id), "The end-to-end route visited the real location " + room_id)
	expect(game.state.get("visited_rooms", []).size() >= 30, "The game's own saved room history also records all thirty locations")
	expect(game.state.get("campaign", {}).get("visited", {}).size() >= 30, "Campaign room-visit bookkeeping persists the same thirty actual locations")
	assert_unique_inventory()
	expect(game.save_game(), "The full 300-point finale saves successfully")
	var saved := state_snapshot()
	var ending_text: String = game.finale_text.text
	game.new_game(false)
	expect(game.load_game() and state_snapshot() == saved and game.flag("complete") and game.finale_panel.visible and game.state["score"] == 300, "Full-campaign completed checkpoints remain complete and retain all six relics rather than migrating as old demos")
	expect(game.finale_text.text == ending_text, "Loading the actual full finale restores its complete ending narration")
	var file := FileAccess.open(game.SAVE_PATH, FileAccess.READ)
	var older_full_save: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	older_full_save.erase("ending_lines")
	file = FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	expect(file != null, "An older full-campaign save without stored ending text can be written")
	if file != null:
		file.store_string(JSON.stringify(older_full_save))
		file.close()
	game.new_game(false)
	expect(game.load_game() and game.flag("complete") and game.state["score"] == 300 and game.finale_panel.visible, "An older full-campaign save retains its completed adventure and 300 points")
	expect(game.finale_text.text.split("\n\n").size() == 3 and game.finale_text.text.contains("THE END") and int(game.audio.event_counts.get("complete", 0)) == ending_cues + 1, "A save without ending lines restores full three-paragraph narration without replaying completion audio")
	completed_cases["finale"] = true

func check() -> void:
	create_timer(70.0).timeout.connect(func():
		push_error("Thirty-room campaign integration test timed out")
		quit(1))
	campaign = load("res://scripts/campaign.gd")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.travel.set_process(false)
	check_opening_and_early_gate()
	await check_labion()
	check_monolith()
	await check_plexi()
	await check_starcon()
	await check_polysorbate_and_glitzon()
	await check_finale_and_full_save()
	for scenario in ["opening", "labion", "monolith", "plexi", "starcon", "polysorbate_glitzon", "finale"]:
		expect(completed_cases.get(scenario, false), "Scenario completed without script interruption: " + scenario)
	game.queue_free()
	await create_timer(0.2).timeout
	if failures == 0:
		print("PASS: %d campaign checks — thirty actual room visits, complete six-artifact story/300-point finale, real mouse movement/inspection/pickup, regional gates, comic failures/Retry, idempotent rewards, inventory preservation, saved campaign/full finale" % checks)
	else:
		push_error("%d of %d campaign checks failed" % [failures, checks])
	quit(0 if failures == 0 else 1)
