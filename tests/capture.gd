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
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--room="):
			room_id = argument.trim_prefix("--room=")
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--portrait":
			portrait = true
	if room_id not in ["diner", "dock", "museum"]:
		push_error("Unknown room: " + room_id)
		quit(1)
		return
	if output.is_empty():
		output = "user://capture_" + room_id + ".png"
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.new_game(false)
	game.enter_room(room_id)
	if portrait:
		game.perform_action("cook" if room_id == "diner" else "guard" if room_id == "dock" else "guardian", "Talk")
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
