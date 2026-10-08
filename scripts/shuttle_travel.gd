extends Control
## Shuttle routes and the short, skippable flight between playable locations.
## The game owns destination validation and the arrival action.

const FLIGHT_DURATION := 2.6
const DESTINATION_NAMES := {
	"monolith": "MONOLITH BURGER",
	"dock": "SERVICE DOCK 7",
	"labion": "LABION"
}

var game
var destination_buttons: Dictionary = {}
var close_button: Button
var menu_panel: Panel
var menu_shade: ColorRect
var route_label: Label
var explanation_label: Label
var flight_labels: Control
var flight_heading: Label
var flight_route: Label
var flight_caption: Label
var flight_progress: Label
var _menu_open := false
var _flight_active := false
var _flight_elapsed := 0.0
var _flight_destination := ""
var _departure := ""
var _arrival_sent := false

func setup(owner_game) -> void:
	game = owner_game
	name = "ShuttleTravel"
	position = Vector2.ZERO
	size = Vector2(640, 400)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_menu()
	_build_flight_labels()
	hide()

func _style(fill: Color, border: Color = Color("47667b"), radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _label(value: String, at: Vector2, dimensions: Vector2, font_size: int, parent: Control) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("dfe8ed"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(value: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("e4edf2"))
	button.add_theme_color_override("font_hover_color", Color("fff0be"))
	button.add_theme_color_override("font_disabled_color", Color("788b99"))
	button.add_theme_stylebox_override("normal", _style(Color("172b3d")))
	button.add_theme_stylebox_override("hover", _style(Color("26465a"), Color("dbb671")))
	button.add_theme_stylebox_override("pressed", _style(Color("315972"), Color("dbb671")))
	button.add_theme_stylebox_override("disabled", _style(Color("14202b"), Color("30424e")))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func():
		if not _menu_open or game.sound_is_open():
			return
		game.audio.play_sfx("ui_click")
		callback.call())
	menu_panel.add_child(button)
	button.size = dimensions
	return button

func _build_menu() -> void:
	menu_shade = ColorRect.new()
	menu_shade.size = size
	menu_shade.color = Color(0.015, 0.026, 0.04, 0.77)
	menu_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu_shade)
	menu_panel = Panel.new()
	menu_panel.position = Vector2(62, 66)
	menu_panel.size = Vector2(516, 270)
	menu_panel.add_theme_stylebox_override("panel", _style(Color("0c1c29"), Color("caa86b"), 10))
	add_child(menu_panel)
	_label("SHUTTLE NAVIGATION", Vector2(23, 17), Vector2(466, 27), 20, menu_panel).add_theme_color_override("font_color", Color("f5d49a"))
	route_label = _label("", Vector2(24, 50), Vector2(468, 21), 11, menu_panel)
	route_label.add_theme_color_override("font_color", Color("94b7ca"))
	destination_buttons["monolith"] = _button("Fly to Monolith Burger", Vector2(24, 87), Vector2(468, 43), func(): game.choose_destination("monolith"))
	destination_buttons["dock"] = _button("Return to Service Dock 7", Vector2(24, 87), Vector2(468, 43), func(): game.choose_destination("dock"))
	destination_buttons["labion"] = _button("Set course for Labion", Vector2(24, 139), Vector2(468, 43), func(): game.choose_destination("labion"))
	explanation_label = _label("", Vector2(24, 191), Vector2(347, 57), 11, menu_panel)
	explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_button = _button("Cancel", Vector2(389, 224), Vector2(103, 29), func(): game.close_travel_menu())
	close_button.tooltip_text = "Return to the room — Esc"

func _build_flight_labels() -> void:
	flight_labels = Control.new()
	flight_labels.size = size
	flight_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flight_labels)
	flight_heading = _label("IN FLIGHT", Vector2(26, 17), Vector2(588, 23), 15, flight_labels)
	flight_heading.add_theme_color_override("font_color", Color("f5d49a"))
	flight_route = _label("", Vector2(26, 46), Vector2(588, 25), 12, flight_labels)
	flight_route.add_theme_color_override("font_color", Color("d4e7ef"))
	flight_caption = _label("", Vector2(26, 313), Vector2(588, 24), 12, flight_labels)
	flight_caption.clip_text = true
	flight_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	flight_progress = _label("", Vector2(26, 366), Vector2(588, 18), 10, flight_labels)
	flight_progress.add_theme_color_override("font_color", Color("abc0cc"))
	flight_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func open_menu(room: String, labion_available: bool) -> void:
	if _flight_active or room not in ["dock", "monolith"]:
		return
	_menu_open = true
	menu_shade.show()
	menu_panel.show()
	flight_labels.hide()
	destination_buttons["monolith"].visible = room == "dock"
	destination_buttons["dock"].visible = room == "monolith"
	destination_buttons["labion"].visible = room == "dock"
	destination_buttons["labion"].disabled = not labion_available
	destination_buttons["labion"].tooltip_text = "The museum archive holds Labion's coordinates." if not labion_available else "Launch the story mission and complete this chapter."
	route_label.text = "DEPARTURE: SERVICE DOCK 7  /  CHOOSE A DESTINATION" if room == "dock" else "DEPARTURE: MONOLITH BURGER  /  LOCAL RETURN ROUTE"
	if room == "monolith":
		explanation_label.text = "Your shuttle is parked outside. Return to the dock whenever you are ready."
	elif labion_available:
		explanation_label.text = "Monolith Burger is an optional stop. Labion begins the next leg of Roger's chase."
	else:
		explanation_label.text = "Monolith Burger's local route is built in. Recover the museum star map to unlock Labion."
	show()
	queue_redraw()

func close_menu() -> void:
	_menu_open = false
	menu_shade.hide()
	menu_panel.hide()
	if not _flight_active:
		hide()
	queue_redraw()

func menu_is_open() -> bool:
	return _menu_open

func begin_flight(destination_id: String) -> void:
	if destination_id not in DESTINATION_NAMES:
		return
	close_menu()
	_flight_destination = destination_id
	_flight_elapsed = 0.0
	_arrival_sent = false
	_flight_active = true
	_departure = "MONOLITH BURGER" if str(game.state.get("room", "dock")) == "monolith" else "SERVICE DOCK 7"
	flight_heading.text = "APPROACHING MONOLITH BURGER" if destination_id == "monolith" else "RETURNING TO SERVICE DOCK 7" if destination_id == "dock" else "SETTING COURSE FOR LABION"
	flight_route.text = _departure + "  →  " + str(DESTINATION_NAMES[destination_id])
	flight_caption.text = "Roger hopes the drive-through has a less literal definition of 'drive'." if destination_id == "monolith" else "A successful burger run. The paperwork will claim it was reconnaissance." if destination_id == "dock" else "One small trip for a janitor. One enormous overtime claim."
	flight_labels.show()
	show()
	_update_flight_text()
	queue_redraw()

func cancel_flight() -> void:
	_flight_active = false
	_flight_elapsed = 0.0
	_arrival_sent = false
	flight_labels.hide()
	if not _menu_open:
		hide()
	queue_redraw()

func flight_is_active() -> bool:
	return _flight_active

func _process(delta: float) -> void:
	if not _flight_active:
		return
	_flight_elapsed = minf(_flight_elapsed + delta, FLIGHT_DURATION)
	_update_flight_text()
	queue_redraw()
	if _flight_elapsed >= FLIGHT_DURATION and not _arrival_sent:
		_arrival_sent = true
		game.finish_flight()

func _update_flight_text() -> void:
	var percent := int(roundf(100.0 * _flight_elapsed / FLIGHT_DURATION))
	flight_progress.text = "COURSE PROGRESS %d%%    •    Click, Enter or Space to arrive" % percent

func _draw() -> void:
	if not _flight_active:
		return
	var progress := clampf(_flight_elapsed / FLIGHT_DURATION, 0.0, 1.0)
	var texture_name := "flight_labion" if _flight_destination == "labion" else "flight_monolith"
	if game.textures.has(texture_name):
		var zoom := 1.035 - 0.035 * progress if _flight_destination == "dock" else 1.0 + 0.035 * progress
		var dimensions := size * zoom
		draw_texture_rect(game.textures[texture_name], Rect2((size - dimensions) * 0.5, dimensions), false)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.045, 0.15))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("07101e"))
		draw_circle(Vector2(527, 225), 113.0, Color("232c43"))
		draw_arc(Vector2(527, 225), 121.0, 1.0, 4.7, 64, Color("7186a5"), 2.0, true)
	# Sparse, soft streaks give the illustrated exterior a sense of motion.
	for index in range(23):
		var x := fposmod(float(index * 97) - _flight_elapsed * (24.0 + float(index % 5) * 7.0), 684.0) - 22.0
		var y := 94.0 + fposmod(float(index * 47), 197.0)
		var opacity := 0.13 + float(index % 3) * 0.045
		draw_line(Vector2(x, y), Vector2(x + 7.0 + float(index % 4) * 2.0, y - 0.8), Color(0.8, 0.9, 1.0, opacity), 1.0, true)
	draw_rect(Rect2(0, 0, 640, 81), Color(0.025, 0.047, 0.072, 0.87))
	draw_rect(Rect2(0, 304, 640, 96), Color(0.025, 0.047, 0.072, 0.9))
	draw_line(Vector2(26, 350), Vector2(614, 350), Color("294558"), 3.0)
	draw_line(Vector2(26, 350), Vector2(26 + 588 * progress, 350), Color("e1be78"), 3.0)
