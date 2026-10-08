extends RefCounted
## Small light, steam and dust responses over the existing illustrated props.

static func render(game, room: String) -> void:
	var objects: Dictionary = game.room_hotspots(room)
	var bits: Variant = game.state.get("bits", {})
	if bits is Dictionary:
		if room == "diner" and int(bits.get("coffee_strength", 0)) > 0:
			var light := Color("e4b06b") if int(bits["coffee_strength"]) == 1 else Color("a8e6f4")
			game.draw_circle(Vector2(248, 133), 1.5, light)
		elif room == "dock" and bool(bits.get("tape_flipped", false)):
			game.draw_line(Vector2(80, 219), Vector2(102, 212), Color(0.94, 0.69, 0.3, 0.6), 1.0)
		elif room == "museum":
			if bool(bits.get("schematic_lit", false)):
				game.draw_rect(Rect2(208, 123, 52, 13), Color(0.31, 0.73, 0.95, 0.3), false, 1.0)
			if bool(bits.get("model_lit", false)):
				var glow := 0.28 + sin(game.elapsed * 2.5) * 0.06
				game.draw_circle(Vector2(306, 48), 3.0, Color(0.36, 0.75, 1.0, glow))
				game.draw_circle(Vector2(308, 56), 2.0, Color(0.6, 0.85, 1.0, glow))
			if not bool(bits.get("badge_collected", false)):
				# A discreet glint on the souvenir makes the pickup discoverable.
				var glint := pow(maxf(0.0, sin(game.elapsed * 0.8)), 12.0) * 0.6
				game.draw_circle(Vector2(280, 184), 2.0, Color(1.0, 0.82, 0.4, glint))
	for effect in game.bit_effects:
		if effect["room"] != room or not objects.has(effect["id"]):
			continue
		var id: String = effect["id"]
		var rect: Rect2 = objects[id]["rect"]
		var center := rect.get_center()
		var progress := 1.0 - float(effect["remaining"]) / float(effect["duration"])
		var alpha := 1.0 - progress
		match id:
			"bit_coffee", "bit_duct":
				var steam := id == "bit_coffee"
				var tint := Color(0.92, 0.86, 0.73, alpha * 0.45) if steam else Color(0.75, 0.7, 0.59, alpha * 0.65)
				for index in range(6):
					var direction := -1.0 if steam else 1.0
					var point := center + Vector2(sin(progress * 5.0 + index) * 4.0 + index - 3.0, direction * (progress * 21.0 + index * 1.7))
					game.draw_circle(point, 1.0 + index * 0.15, tint)
			"bit_plant":
				for index in range(4):
					var point := center + Vector2(sin(progress * 12.0 + index) * 7.0, -5.0 + index * 3.0)
					game.draw_line(point, point + Vector2(3, -3), Color(0.65, 0.8, 0.45, alpha * 0.65), 1.0)
			"bit_sauce":
				for index in range(4):
					var point := center + Vector2((index - 1.5) * progress * 7.0, -sin(progress * PI) * 9.0 + index)
					game.draw_circle(point, 1.0, Color(0.91, 0.42, 0.2, alpha * 0.75))
			"bit_seat":
				for index in range(3):
					var point := center + Vector2(-8 + index * 8, 4)
					game.draw_line(point, point + Vector2(sin(progress * 9.0) * 2.0, -progress * 8.0), Color(0.87, 0.68, 0.43, alpha * 0.5), 1.0)
			"bit_crates", "bit_helmet", "bit_menu", "bit_tape":
				var pulse := sin(progress * PI) * 3.0
				var tint := Color(0.97, 0.78, 0.42, alpha * 0.45)
				game.draw_arc(center, minf(rect.size.x, rect.size.y) * 0.35 + pulse, -0.6, 0.6, 12, tint, 1.0)
				game.draw_arc(center, minf(rect.size.x, rect.size.y) * 0.35 + pulse, PI - 0.6, PI + 0.6, 12, tint, 1.0)
			_:
				var tint := Color(0.81, 0.91, 1.0, alpha * 0.7) if id in ["bit_telescope", "bit_model", "bit_schematic"] else Color(1.0, 0.83, 0.48, alpha * 0.7)
				var radius := 2.0 + sin(progress * PI) * 4.0
				game.draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), tint, 1.0)
				game.draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), tint, 1.0)
