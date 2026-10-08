extends SceneTree
func _initialize():
 call_deferred("check")
func check():
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.verb = "Walk"
 game.interact("exit")
 assert(not game.departed, "Door should initially block departure")
 game.verb = "Use"
 game.interact("grease")
 assert(game.inventory.is_empty(), "Cook permission required")
 game.verb = "Talk"
 game.interact("cook")
 game.verb = "Use"
 game.interact("grease")
 assert(game.inventory.has("grease"), "Grease collection failed")
 game.interact("panel")
 assert(not game.fixed, "Must select an inventory item")
 game.bag.pressed.emit()
 game.interact("panel")
 assert(game.fixed and game.inventory.is_empty(), "Panel repair must consume grease")
 game.verb = "Walk"
 game.interact("exit")
 assert(game.departed, "Repaired door must allow departure")
 print("PASS: blocked exit, permission, pickup, item selection, repair, departure")
 quit()
