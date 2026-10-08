extends Node2D

var verb := "Walk"
var inventory: Array[String] = []
var player := Vector2(87, 153)
var destination := player
var time := 0.0
var message := "ASTRO-BURGER • Somewhere off the sanitation route."
var talked := false
var fixed := false
var departed := false
var selected := ""
var buttons: Array[Button] = []
var caption: Label
var bag: Button
var hotspots := {"cook": Rect2(184, 83, 27, 43), "news": Rect2(28, 37, 57, 35), "grease": Rect2(218, 117, 20, 13), "panel": Rect2(272, 104, 14, 16), "exit": Rect2(276, 66, 35, 71)}

func _ready():
 for i in range(4):
  var b := Button.new()
  b.text = ["Walk", "Look", "Use", "Talk"][i]
  b.position = Vector2(i * 49 + 3, 174)
  b.size = Vector2(47, 22)
  b.add_theme_font_size_override("font_size", 10)
  var name_verb: String = b.text
  b.pressed.connect(func(): verb = name_verb; selected = ""; update_hud())
  add_child(b)
  buttons.append(b)
 bag = Button.new()
 bag.position = Vector2(201, 174)
 bag.size = Vector2(116, 22)
 bag.add_theme_font_size_override("font_size", 10)
 bag.pressed.connect(func():
  if inventory.is_empty():
   say("Your pockets contain lint. Heroic lint.")
  else:
   selected = inventory[0]
   verb = "Use"
   say("Grease selected. Click something to use it.")
  update_hud())
 add_child(bag)
 caption = Label.new()
 caption.position = Vector2(5, 157)
 caption.size = Vector2(310, 19)
 caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 caption.add_theme_font_size_override("font_size", 8)
 caption.clip_text = false
 add_child(caption)
 update_hud()

func update_hud():
 caption.text = message
 bag.text = "Bag: " + ("empty" if inventory.is_empty() else "grease")
 for b in buttons:
  b.modulate = Color("ffe49a") if b.text == verb else Color.WHITE

func say(line: String):
 message = line
 update_hud()

func _process(delta):
 time += delta
 player = player.move_toward(destination, delta * 39)
 queue_redraw()

func _unhandled_input(event):
 if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  var p := get_global_mouse_position()
  if p.y >= 155 or departed:
   return
  var target := ""
  for key in ["panel", "grease", "cook", "news", "exit"]:
   if hotspots[key].has_point(p):
    target = key
    break
  if verb == "Walk":
   destination = Vector2(clampf(p.x, 12, 307), clampf(p.y, 132, 153))
   if target == "exit":
    interact(target)
  elif target != "":
   interact(target)
  else:
   say("Look" + ": A diner with a worrying hygiene score." if verb == "Look" else "Nothing useful happens. A familiar feeling.")

func interact(target: String):
 if verb == "Look":
  say({"cook": "A cook. His apron has achieved sentience.", "news": "R0-GER steals the Mop of Destiny! Universe next?", "grease": "Fryer grease. Lubricant, condiment, cosmic hazard.", "panel": "The shuttle-door gears are jammed. They need grease.", "exit": "Shuttle bay. The door is " + ("open." if fixed else "jammed.")}[target])
 elif verb == "Talk":
  if target == "cook":
   talked = true
   say("COOK: Take that grease. Try it on the door gears.")
  elif target == "news":
   say("The news ignores you. Refreshingly professional.")
  else:
   say("It declines to join the conversation.")
 elif verb == "Use":
  if target == "grease":
   if not inventory.is_empty() or fixed:
    say("You already collected the grease.")
   elif talked:
    inventory.append("grease")
    say("Collected fryer grease. Your pocket will never recover.")
   else:
    say("Ask the cook before pocketing his industrial waste.")
  elif target == "panel":
   if fixed:
    say("The gears are running smoothly. Suspicious.")
   elif selected == "grease" and inventory.has("grease"):
    fixed = true
    inventory.clear()
    selected = ""
    say("Greased the gears! Walk through the shuttle door.")
   else:
    say("Select grease from your bag, then use it here.")
  elif target == "exit":
   leave_diner()
  else:
   say("That would violate at least three diner policies.")
 elif target == "exit":
  leave_diner()
 update_hud()
 queue_redraw()

func leave_diner():
 if fixed:
  departed = true
  say("Demo complete! Destination: Arcada Memorial Museum.")
 else:
  say("The shuttle door is jammed. Inspect the little panel.")

func block(x: float, y: float, w: float, h: float, color: String):
 draw_rect(Rect2(x, y, w, h), Color(color))

func lettering(text: String, x: float, y: float, size: int, color: String):
 draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color))

func _draw():
 block(0, 0, 320, 200, "17182d")
 if departed:
  for i in range(70):
   block((i * 79) % 320, (i * 37) % 150, 1, 1, "d2d6e8")
  block(83, 64, 127, 38, "737f99")
  block(108, 52, 64, 21, "8596b1")
  block(115, 57, 49, 11, "213755")
  block(75, 81, 25, 14, "f7b359")
  lettering("TO BE CONTINUED...", 78, 132, 13, "ffe49a")
  return
 # Indigo alien sky, distant city, and diner architecture.
 block(0, 16, 320, 112, "393257")
 block(95, 33, 70, 49, "151f3b")
 block(98, 36, 64, 43, "253451")
 draw_circle(Vector2(146, 47), 9, Color("e1ad91"))
 for i in range(21):
  block(100 + (i * 13) % 60, 38 + (i * 11) % 37, 1, 1, "8fa3ca")
 for i in range(8):
  block(99 + i * 8, 69 - (i % 3) * 5, 6, 10 + (i % 3) * 5, "101829")
 block(0, 0, 320, 17, "24233d")
 block(0, 17, 320, 3, "cf785e")
 block(0, 81, 271, 5, "8b657e")
 block(0, 86, 271, 37, "513f5d")
 for i in range(9):
  block(i * 32, 87, 2, 36, "352d48")
 block(0, 123, 320, 32, "777083")
 for i in range(5):
  draw_line(Vector2(0, 127 + i * 7), Vector2(320, 127 + i * 7), Color("59556e"))
 for i in range(12):
  draw_line(Vector2(i * 32 - 20, 123), Vector2(i * 36 - 28, 155), Color("59556e"))
 # News monitor.
 block(24, 33, 65, 43, "151a30")
 block(28, 37, 57, 35, "42637a")
 block(33, 41, 20, 22, "24324c")
 block(39, 44, 9, 8, "c4ae87")
 block(37, 52, 13, 10, "8a3453")
 lettering("NEWS", 57, 48, 7, "f9e6b9")
 lettering("MOP", 57, 57, 7, "f9e6b9")
 lettering("HEIST!", 55, 66, 7, "f9e6b9")
 block(49, 76, 14, 4, "22253c")
 # Neon sign and service hatch.
 lettering("ASTRO-BURGER", 107, 15, 13, "f6b57d")
 block(170, 34, 83, 49, "221f36")
 block(174, 38, 75, 39, "654257")
 lettering("TODAY'S SPECIAL", 179, 49, 7, "ffe1ad")
 lettering("Probably edible", 181, 63, 8, "e4ab92")
 # Cook's head, hat, apron, and arms.
 block(189, 87, 15, 13, "dcad86")
 block(187, 81, 19, 7, "eee0bf")
 block(190, 76, 13, 7, "eee0bf")
 block(199, 90, 2, 2, "25243c")
 block(186, 101, 22, 20, "bd6b65")
 block(191, 102, 12, 19, "ead8b0")
 block(181, 104, 5, 12, "dcad86")
 block(208, 104, 5, 12, "dcad86")
 # Counter, grease jar, stools.
 block(149, 120, 106, 5, "e1a987")
 block(153, 125, 98, 12, "884f5f")
 block(156, 128, 91, 3, "b96d72")
 if not inventory.has("grease") and not fixed:
  block(221, 116, 13, 3, "e4ca8e")
  block(222, 119, 11, 5, "95722f")
 for x in [160, 242]:
  block(x, 141, 18, 4, "ac647a")
  block(x + 7, 145, 4, 9, "30354d")
 # Door and gear panel.
 block(271, 28, 49, 99, "20243a")
 lettering("SHUTTLE", 275, 42, 9, "a8cec4")
 block(277, 53, 36, 74, "849097")
 block(281, 58, 28, 69, "182b42" if fixed else "49566c")
 if not fixed:
  block(294, 59, 2, 66, "8995a0")
 block(272, 105, 13, 14, "c4936c")
 block(275, 108, 7, 7, "86c6a1" if fixed else "e38c69")
 # Booth on the left.
 block(4, 97, 16, 38, "864e6c")
 block(7, 101, 9, 24, "b56b80")
 block(4, 132, 48, 6, "ad6276")
 block(28, 114, 32, 4, "e3a483")
 block(42, 118, 4, 25, "33324b")
 # Original janitor character with a blue uniform.
 var x := floorf(player.x)
 var y := floorf(player.y)
 var stepping := 1 if player.distance_to(destination) > 1 and sin(time * 13) > 0 else 0
 draw_ellipse_shadow(Vector2(x, y))
 block(x - 4, y - 28, 8, 3, "a67448")
 block(x - 5, y - 25, 10, 8, "e5b18a")
 block(x + 2, y - 23, 1, 2, "20243a")
 block(x - 6, y - 17, 12, 11, "6595c0")
 block(x - 2, y - 16, 3, 5, "e8d3a2")
 block(x - 8, y - 15, 3, 9, "dca47f")
 block(x + 5, y - 15, 3, 9, "dca47f")
 block(x - 5, y - 6, 4, 6 - stepping, "374c75")
 block(x + 1, y - 6, 4, 5 + stepping, "374c75")
 block(x - 6, y - 1 - stepping, 5, 2, "20243a")
 block(x + 1, y - 1 + stepping, 6, 2, "20243a")

func draw_ellipse_shadow(p: Vector2):
 draw_rect(Rect2(p.x - 9, p.y - 1, 18, 3), Color("494459"))
