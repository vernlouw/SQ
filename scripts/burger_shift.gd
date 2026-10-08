extends RefCounted
## A persistent optional relief shift. No timer, puzzle flags, or main score.
## These are new meal tickets referencing SQ history, not copied game dialogue.

const COUPON := "monolith coupon"
const ORDERS: Array = [
	{
		"id": "mallard",
		"customer": "A pilot with a suspiciously second-hand ship",
		"text": "\"Give my burger the bird-shaped garnish named for Roger's ship in Space Quest III. The ship's Aluminum something. My receipt's covered in engine oil.\"",
		"choices": [
			{"id": "mallard_pickle", "label": "Aluminum Mallard pickle"},
			{"id": "eureka_egg", "label": "Eureka egg"},
			{"id": "arcada_relish", "label": "Arcada relish"}
		],
		"correct_id": "mallard_pickle",
		"hint": "Roger pilots the Aluminum Mallard in Space Quest III, which also features Monolith Burger.",
		"success": "One Aluminum Mallard pickle, cleared for landing on a burger. The pilot signs the receipt with a landing checklist.",
		"wrong": {
			"eureka_egg": "The pilot refuses to take a garbage scow egg into orbit. His ship was the Aluminum Mallard; try the pickle.",
			"arcada_relish": "Arcada relish comes with an incident report. This pilot wants the Aluminum Mallard pickle."
		}
	},
	{
		"id": "counter",
		"customer": "A time traveller insisting this is his lunch hour",
		"text": "\"Send my burger to the restaurant where Roger actually worked flipping patties in Space Quest IV. I can't remember the counter, but I remember the wages.\"",
		"choices": [
			{"id": "starcon_cafeteria", "label": "StarCon academy cafeteria"},
			{"id": "monolith_counter", "label": "Monolith Burger counter"},
			{"id": "eureka_bay", "label": "Eureka loading bay"}
		],
		"correct_id": "monolith_counter",
		"hint": "Roger's Space Quest IV burger-flipping job is at Monolith Burger.",
		"success": "Monolith Burger pickup confirmed. The traveller tips you in next week's money; Bex refuses to count it until Thursday.",
		"wrong": {
			"starcon_cafeteria": "The academy sends back a tray and three requisition forms. Roger's Space Quest IV burger job was at Monolith Burger.",
			"eureka_bay": "The loading bay treats the meal as cargo. Send it to Monolith Burger, where Roger flipped burgers in Space Quest IV."
		}
	},
	{
		"id": "eureka",
		"customer": "A sanitation captain requesting a clean lunch",
		"text": "\"My crew wants the special topping named for the garbage scow Roger captained in Space Quest V. Please leave actual garbage out of it.\"",
		"choices": [
			{"id": "mallard_mustard", "label": "Aluminum Mallard mustard"},
			{"id": "arcada_sauce", "label": "Arcada bridge sauce"},
			{"id": "eureka_relish", "label": "Eureka salvage relish"}
		],
		"correct_id": "eureka_relish",
		"hint": "Roger captains the sanitation ship Eureka in Space Quest V.",
		"success": "Eureka salvage relish, from a reassuringly new jar. The captain approves your spotless handling of a very dirty pun.",
		"wrong": {
			"mallard_mustard": "The captain likes the duck, but it is the wrong ship. Roger's Space Quest V command was the Eureka.",
			"arcada_sauce": "Arcada bridge sauce is a much earlier recipe. Roger captained the Eureka garbage scow in Space Quest V."
		}
	}
]

static func title(_game) -> String:
	return "MONOLITH BURGER — RELIEF SHIFT"

static func _read_state(game) -> Dictionary:
	var saved = game.state.get("burger_shift", {})
	return saved if saved is Dictionary else {}

static func _state(game) -> Dictionary:
	if not game.state.get("burger_shift", null) is Dictionary:
		game.state["burger_shift"] = {}
	var quest: Dictionary = game.state["burger_shift"]
	for key in ["started", "completed", "coupon_awarded", "coupon_redeemed"]:
		if not quest.has(key):
			quest[key] = false
	if not quest.has("index"):
		quest["index"] = 0
	if not quest.has("attempts"):
		quest["attempts"] = 0
	return quest

static func status(game) -> Dictionary:
	# UI and inspection may query status without starting or changing the quest.
	var quest: Dictionary = _read_state(game)
	var index: int = clampi(int(quest.get("index", 0)), 0, ORDERS.size())
	var completed: bool = bool(quest.get("completed", false)) or index >= ORDERS.size()
	var redeemed: bool = bool(quest.get("coupon_redeemed", false))
	var order: Dictionary = {} if completed else ORDERS[index]
	var message := "Bex's menu offers a Monolith Burger relief shift: three peculiar meal tickets, one free lunch. Choose the right garnish, counter, and topping."
	if bool(quest.get("started", false)):
		message = "Three orders, one coupon. Bex is willing to overlook your qualifications; the customers are less charitable."
	if completed:
		message = "Your relief shift is finished. Use the COUPON on Bex to claim lunch."
	if redeemed:
		message = "Lunch claimed. Bex has recorded the break as advanced burger inspection."
	return {
		"started": bool(quest.get("started", false)),
		"index": index,
		"completed": completed,
		"done": completed,
		"coupon_redeemed": redeemed,
		"coupon_awarded": bool(quest.get("coupon_awarded", false)),
		"order": order,
		"choices": order.get("choices", []),
		"progress": str(index) + "/" + str(ORDERS.size()) + " orders served",
		"message": message
	}

static func start(game) -> Dictionary:
	var quest: Dictionary = _state(game)
	quest["started"] = true
	return status(game)

static func _reply(game, message: String, accepted: bool, awarded: bool = false) -> Dictionary:
	var result: Dictionary = status(game)
	result["message"] = message
	result["accepted"] = accepted
	# In a response, this reports whether this action created the coupon.
	result["coupon_awarded"] = awarded
	return result

static func choose(game, choice_id: String) -> Dictionary:
	var quest: Dictionary = _state(game)
	if bool(quest["completed"]) or int(quest["index"]) >= ORDERS.size():
		return _reply(game, status(game)["message"], false)
	quest["started"] = true
	var index: int = clampi(int(quest["index"]), 0, ORDERS.size() - 1)
	var order: Dictionary = ORDERS[index]
	var known_choice := false
	for choice in order["choices"]:
		if choice["id"] == choice_id:
			known_choice = true
			break
	if not known_choice:
		return _reply(game, "That isn't on this ticket. Choose one of the three meal options.", false)
	quest["attempts"] = int(quest["attempts"]) + 1
	if choice_id != order["correct_id"]:
		return _reply(game, order["wrong"].get(choice_id, order["hint"]), false)
	quest["index"] = index + 1
	if int(quest["index"]) < ORDERS.size():
		return _reply(game, order["success"], true)
	quest["completed"] = true
	var awarded := false
	if not bool(quest["coupon_awarded"]) and not bool(quest["coupon_redeemed"]):
		game.add_item(COUPON)
		quest["coupon_awarded"] = true
		awarded = true
	return _reply(game, "Three orders served. Bex awards one meal coupon and the honorary title Assistant to the Acting Relief Burger Technician. Use COUPON on Bex for lunch.", true, awarded)

static func redeem(game) -> Dictionary:
	var current: Dictionary = _read_state(game)
	if bool(current.get("coupon_redeemed", false)):
		return _reply(game, "You've already claimed your lunch. The coupon's generous terms stop just short of infinity.", false)
	if not bool(current.get("completed", false)) or not game.has_item(COUPON):
		return _reply(game, "Serve the three relief-shift orders first. Then bring Bex the meal coupon; honorary job titles are not edible.", false)
	var quest: Dictionary = _state(game)
	game.remove_item(COUPON)
	quest["coupon_redeemed"] = true
	return _reply(game, "One burger, as promised. I'm stamping your break as 'advanced burger inspection' so payroll won't panic. Yes, the bun is included. I'm a cook, not Intergalactic Finance.", true)
