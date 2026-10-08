extends SceneTree

# Optional graphical helper; pass -- --room=diner --output=/tmp/diner.png.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Screenshots require a graphical display. Omit --headless.")
		quit(1)
		return
	var room_id := "diner"
	var output := ""
	var portrait := false
	var title := false
	var sound := false
	var bits := false
	var burger := false
	var travel := false
	var flight := false
	var interaction := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--room="):
			room_id = argument.trim_prefix("--room=")
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--portrait":
			portrait = true
		elif argument == "--title":
			title = true
		elif argument == "--sound":
			sound = true
		elif argument == "--bits":
			bits = true
		elif argument == "--burger":
			burger = true
		elif argument == "--travel":
			travel = true
		elif argument == "--flight":
			flight = true
		elif argument.begins_with("--interact="):
			interaction = argument.trim_prefix("--interact=")
	if room_id not in ["diner", "dock", "museum", "monolith"]:
		push_error("Unknown room: " + room_id)
		quit(1)
		return
	if output.is_empty():
		output = "user://capture_" + ("title" if title else room_id) + ".png"
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if title:
		game.show_title()
	else:
		game.new_game(false)
		game.enter_room(room_id)
	if portrait and not title:
		var speaker: String = {"diner": "cook", "dock": "guard", "museum": "guardian", "monolith": "manager"}[room_id]
		game.perform_action(speaker, "Talk")
	if bits and not title:
		game.show_hotspots = true
	if not interaction.is_empty() and not title:
		if not game.room_hotspots(room_id).has(interaction):
			push_error("Unknown interaction for " + room_id + ": " + interaction)
			quit(1)
			return
		game.close_dialogue()
		game.perform_action(interaction, game.default_action(interaction))
	if burger and not title:
		game.close_dialogue()
		game.open_burger_shift()
	if (travel or flight) and not title:
		game.close_dialogue()
		game.open_travel_menu()
		if flight:
			game.choose_destination("dock" if room_id == "monolith" else "monolith")
			game.travel.set_process(false)
	if sound:
		game.toggle_sound_panel()
	game.hovered = ""
	game.set_process(false)
	# Allow the imported textures and Control layout to reach the render server.
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save screenshot: " + output + " (" + str(error) + ")")
		quit(1)
		return
	print("Screenshot: " + ProjectSettings.globalize_path(output))
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	quit()
