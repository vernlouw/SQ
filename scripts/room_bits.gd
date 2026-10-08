extends RefCounted
## Optional room business: no score, puzzle flags, consumables, or prerequisites.
## Inspection is read-only; repeat counters and harmless toggles live in bits.

const HOTSPOTS := {
	"diner": {
		"bit_coffee": {"rect": Rect2(239, 117, 35, 44), "at": Vector2(244, 278), "name": "Coffee dispenser", "use_label": "Brew"},
		"bit_menu": {"rect": Rect2(75, 170, 24, 28), "at": Vector2(112, 275), "name": "Booth menu / Monolith Burger advert", "use_label": "Read advert"},
		"bit_seat": {"rect": Rect2(88, 207, 78, 34), "at": Vector2(132, 276), "name": "Sticky booth seat", "use_label": "Sit"},
		"bit_plant": {"rect": Rect2(183, 126, 34, 43), "at": Vector2(206, 274), "name": "Window plant", "use_label": "Rotate"},
		"bit_sauce": {"rect": Rect2(34, 173, 17, 28), "at": Vector2(64, 277), "name": "Rocket sauce", "use_label": "Shake"}
	},
	"dock": {
		"bit_crates": {"rect": Rect2(208, 158, 40, 33), "at": Vector2(238, 276), "name": "Cargo cases", "use_label": "Rattle"},
		"bit_helmet": {"rect": Rect2(136, 88, 21, 17), "at": Vector2(142, 273), "name": "Spare pressure helmet", "use_label": "Try on"},
		"bit_tape": {"rect": Rect2(78, 209, 28, 17), "at": Vector2(91, 275), "name": "Safety chevrons", "use_label": "Peel"},
		"bit_duct": {"rect": Rect2(220, 27, 109, 19), "at": Vector2(268, 275), "name": "Overhead ventilation", "use_label": "Knock"},
		"bit_planet": {"rect": Rect2(390, 48, 80, 32), "at": Vector2(420, 281), "name": "Gas giant", "use_label": "Wave"}
	},
	"museum": {
		"bit_telescope": {"rect": Rect2(142, 129, 53, 36), "at": Vector2(161, 276), "name": "Antique inspection scope", "use_label": "Adjust"},
		"bit_schematic": {"rect": Rect2(207, 121, 55, 17), "at": Vector2(190, 276), "name": "Antique mop blueprint", "use_label": "Illuminate"},
		"bit_donor": {"rect": Rect2(268, 136, 26, 30), "at": Vector2(273, 277), "name": "Donor plaque", "use_label": "Request tour"},
		"bit_model": {"rect": Rect2(298, 27, 191, 44), "at": Vector2(382, 278), "name": "Suspended starship model", "use_label": "Run demo"},
		"bit_badge_tray": {"rect": Rect2(270, 176, 20, 22), "at": Vector2(276, 279), "name": "Souvenir badge stand", "use_label": "Pick up"}
	},
	"monolith": {
		"bit_monolith_mascot": {"rect": Rect2(186, 109, 62, 98), "at": Vector2(232, 278), "name": "Burger mascot", "use_label": "Press"},
		"bit_monolith_booth": {"rect": Rect2(27, 160, 37, 28), "at": Vector2(80, 278), "name": "Booth holomenu", "use_label": "Zoom menu"},
		"bit_monolith_mustard": {"rect": Rect2(498, 122, 42, 63), "at": Vector2(508, 278), "name": "Mustard duck", "use_label": "Pump"},
		"bit_monolith_window": {"rect": Rect2(36, 39, 115, 99), "at": Vector2(148, 277), "name": "Restaurant window", "use_label": "Admire"}
	}
}

const LOOK_LINES := {
	"bit_coffee": "Three settings: Decaf, Awake, and Legally a Cleaning Solvent. Finally, a machine that understands my two jobs.",
	"bit_menu": "The menu lists a gratuity, a gravity surcharge, and a surcharge for explaining the gravity surcharge.",
	"bit_seat": "The red upholstery has survived six governments. Whatever is holding it together has also trapped a spoon.",
	"bit_plant": "A plastic plant in real dirt. Someone has made two separate budget mistakes.",
	"bit_sauce": "Rocket sauce: for customers who feel a burger should be able to re-enter the atmosphere.",
	"bit_crates": "The cases are marked FRAGILE, THIS SIDE UP, and DO NOT READ OTHER LABELS. Logistics is going well.",
	"bit_helmet": "A spare pressure helmet. The name inside has been crossed out so often the lining is mostly promotion history.",
	"bit_tape": "Yellow safety chevrons mark exactly where an unpaid janitor is expected to be injured safely.",
	"bit_duct": "The ventilation draws warm air into the ceiling, where management keeps the rest of its promises.",
	"bit_planet": "That storm is wider than my homeworld. Still a shorter queue than Human Resources.",
	"bit_telescope": "An early inspection scope. Its plaque says it discovered a moon; the dust says it needs my attention first.",
	"bit_schematic": "The first self-wringing mop. Its inventor received a medal. The person who cleaned up the prototype did not.",
	"bit_donor": "A gold plaque thanks the patrons who made this museum possible. The cleaning crew gets a laminated rota.",
	"bit_model": "A suspended starship with immaculate hull plating. Whoever cleans it has a very expensive ladder.",
	"bit_badge_tray": "One complimentary VISITOR OF THE MINUTE badge. A career milestone with a refreshingly short probation period.",
	"bit_monolith_mascot": "The mascot has a permanent smile, a permanent hat, and apparently no scheduled breaks. Corporate's ideal employee.",
	"bit_monolith_booth": "The burger photographs are larger than the plates. The small print explains that serving size is measured in optimism.",
	"bit_monolith_mustard": "A duck-shaped mustard pump. Somebody successfully billed a condiment dispenser as an employee morale initiative.",
	"bit_monolith_window": "A ship floats beyond the glass. Somewhere aboard it, another janitor is also looking longingly at somebody else's lunch break."
}

const ITEM_LINES := {
	"bit_coffee": "You keep the %s out of the coffee. The dispenser already makes enough hazardous combinations on its own.",
	"bit_menu": "The %s would make a poor tip. Bex has an unusually thorough definition of theft.",
	"bit_seat": "You keep the %s. Getting it unstuck from that seat would require another inventory puzzle.",
	"bit_plant": "The plant does not need your %s. It has been pretending to thrive without help for years.",
	"bit_sauce": "Mixing the %s with rocket sauce would create paperwork with a blast radius.",
	"bit_crates": "You keep the %s. Cargo inspection is a different pay grade, with a different helmet allowance.",
	"bit_helmet": "The %s does not belong in the helmet. That space is reserved for your surprisingly useful head.",
	"bit_tape": "You keep the %s. Altering a safety marking requires a safety marking alteration safety briefing.",
	"bit_duct": "The %s stays down here. You have enough tasks without feeding equipment to the ventilation.",
	"bit_planet": "The %s is several million kilometres short of being useful on that planet.",
	"bit_telescope": "You keep the %s away from the lens. The cleaning crew already gets blamed for first contact.",
	"bit_schematic": "You are not applying the %s to a museum blueprint. Your performance review cannot survive another historical incident.",
	"bit_donor": "The plaque accepts major donations, not the %s. You cannot afford even the minor plaque.",
	"bit_model": "You keep the %s. The exhibit's repair estimate has more zeroes than your bank account.",
	"bit_badge_tray": "The souvenir is free. You can keep the %s and your remaining dignity.",
	"bit_monolith_mascot": "You keep the %s. The mascot already has everything it needs, including a better uniform than yours.",
	"bit_monolith_booth": "The menu declines your %s. Condiments are extra, but inventory disposal isn't a service it offers.",
	"bit_monolith_mustard": "You keep the %s away from the duck. The mustard is already doing everything legally permitted to mustard.",
	"bit_monolith_window": "You keep the %s. Even a galactic emergency doesn't justify cleaning a window with your entire inventory."
}

static func default_action(id: String) -> String:
	return "Look" if id in ["bit_planet", "bit_monolith_window"] else "Use"

static func visible(_game, _id: String) -> bool:
	# The empty souvenir stand remains inspectable after its one badge is taken.
	return true

static func _read_bits(game) -> Dictionary:
	var saved = game.state.get("bits", {})
	return saved if saved is Dictionary else {}

static func _bits(game) -> Dictionary:
	if not game.state.get("bits", null) is Dictionary:
		game.state["bits"] = {}
	return game.state["bits"]

static func _count(bits: Dictionary, key: String) -> int:
	var count: int = int(bits.get(key, 0)) + 1
	bits[key] = count
	return count

static func _toggle(bits: Dictionary, key: String) -> bool:
	bits[key] = not bool(bits.get(key, false))
	return bits[key]

static func _say(game, text: String, cue: String = "", speaker: String = "roger") -> void:
	# show_dialog supplies its own dialogue cue; action cues remain distinct.
	if cue != "" and cue != "dialogue":
		game.audio.play_sfx(cue)
	game.show_dialog(speaker, [text])

static func _badge_reaction(game, id: String) -> bool:
	if id not in ["cook", "guard", "guardian", "manager"] or not game.has_item("novelty badge"):
		return false
	var count: int = _count(_bits(game), "badge:" + id)
	match id:
		"cook":
			_say(game, "VISITOR OF THE MINUTE? Congratulations. Employees of the Year still pay for coffee." if count == 1 else "The badge gets you a complimentary smile. Smiles cannot be exchanged for burgers.", "dialogue", "cook")
		"guard":
			_say(game, "Decorative credentials noted. I'm afraid novelty authority is restricted to novelty emergencies." if count == 1 else "Your minute has expired. Luckily, souvenir status renews automatically. Dock clearance does not.", "dialogue", "guard")
		"guardian":
			_say(game, "VISITOR STATUS CONFIRMED. Badge confers one hundred percent more souvenir ownership and zero additional archive access." if count == 1 else "BADGE STILL VALID AS A BADGE. Please refrain from attempting to promote it into a maintenance pass.", "terminal", "guardian")
		"manager":
			_say(game, "Visitor of the Minute? Excellent. Our training takes two minutes. We'll make a burger professional of you before that badge cools." if count == 1 else "The badge is still adorable. It still won't pay for fries. Corporate's poetry policy is brutally clear.", "terminal", "manager")
	return true

static func handle(game, room: String, id: String, action: String, item: String) -> bool:
	if action == "Use" and item == "novelty badge" and id in ["cook", "guard", "guardian", "manager"]:
		return _badge_reaction(game, id)
	if not HOTSPOTS.has(room) or not HOTSPOTS[room].has(id):
		return false
	if action == "Talk":
		# Talk is for people. On scenery, use its normal physical interaction.
		action = default_action(id)
	if action == "Look":
		var text: String = LOOK_LINES[id]
		var bits: Dictionary = _read_bits(game)
		if id == "bit_badge_tray" and bool(bits.get("badge_collected", false)):
			text = "The complimentary badge stand is empty. For once, the museum's missing exhibit is legally in my pocket."
		elif id == "bit_helmet" and bool(bits.get("helmet_visor_closed", false)):
			text = "The helmet is back on its stand, visor sealed. At least one thing in this dock is ready for an emergency."
		elif id == "bit_model" and bool(bits.get("model_lit", false)):
			text = "The little ship is running its heroic launch demonstration. Its cleaning schedule remains suspiciously absent."
		_say(game, text)
		return true
	if action not in ["Use", "Interact"]:
		return false
	if item != "":
		_say(game, ITEM_LINES[id] % item, "blocked")
		return true
	var bits: Dictionary = _bits(game)
	var count: int = _count(bits, "uses:" + id)
	game.start_bit_effect(id)
	match id:
		"bit_coffee":
			bits["coffee_strength"] = (int(bits.get("coffee_strength", 0)) + 1) % 3
			var choices: Array = ["Decaf. Hot brown water, for when disappointment needs to be portable.", "Awake. The machine brews a cup and prints an invoice for the steam.", "Cleaning Solvent. It smells like coffee that has access to military funding."]
			_say(game, choices[bits["coffee_strength"]], "terminal")
		"bit_menu":
			_say(game, "An advert for Monolith Burger: 'Our burgers are worth crossing a sector for.' The fine print excludes fuel costs. Take the dock shuttle and select Monolith Burger." if count % 2 else "Monolith Burger is hiring relief staff. 'Previous fast-food trauma preferred.' Its actual restaurant is a shuttle ride away; select Monolith Burger from the service dock.", "ui_click")
		"bit_seat":
			_say(game, "You peel yourself free with a noise the kitchen tactfully pretends not to hear. Good staff retention, terrible upholstery." if _toggle(bits, "seat_unstuck") else "You sit again. The seat remembers you fondly, and is reluctant to resume a long-distance relationship.", "door")
		"bit_plant":
			_say(game, "You turn the plant toward the window. Even artificial staff deserve a view." if _toggle(bits, "plant_rotated") else "You turn it back toward the kitchen. It now appears to be supervising Bex. A natural career progression.", "ui_click")
		"bit_sauce":
			_say(game, "You shake the rocket sauce. The bubbles briefly arrange themselves into an evacuation arrow." if _toggle(bits, "sauce_shaken") else "You shake it again. The label politely requests that you stop preparing it for launch.", "combine")
		"bit_crates":
			bits["crate_checked"] = true
			_say(game, "You rattle a case. Somewhere inside, a smaller case files a noise complaint." if count % 2 else "Another rattle. Now two cases are complaining. This is how departments begin.", "door")
		"bit_helmet":
			_say(game, "You try the helmet, seal its visor, then put it back. It smells of somebody else's overtime." if _toggle(bits, "helmet_visor_closed") else "You try it with the visor open, then return it. The ventilation is now as generous as the benefits package.", "pickup")
		"bit_tape":
			_say(game, "You lift a peeling corner. Beneath the safety stripe is an older safety stripe. Archaeology for janitors." if _toggle(bits, "tape_flipped") else "You press the corner down again. That counts as preventative maintenance if anybody asks.", "ui_click")
		"bit_duct":
			bits["duct_dusted"] = true
			_say(game, "A polite knock releases a small cloud of dust. The ceiling has been saving work for you." if count % 2 else "You knock again. More dust. Apparently the ventilation has a subscription service.", "blocked")
		"bit_planet":
			bits["planet_waved"] = true
			_say(game, "You wave at the planet. A storm swirls back. You choose to interpret this as professional recognition." if count % 2 else "You wave again. If it waves harder, the dock will need a substantially larger mop.", "dialogue")
		"bit_telescope":
			bits["telescope_filter"] = (int(bits.get("telescope_filter", 0)) + 1) % 3
			var choices: Array = ["Normal view restored. The universe resumes being both beautiful and somebody else's cleaning problem.", "You select the lunar filter. Even the craters look more restful than the staff sleeping quarters.", "You select the inspection filter. It reveals a fingerprint on the inside. Of course it does."]
			_say(game, choices[bits["telescope_filter"]], "terminal")
		"bit_schematic":
			_say(game, "The blueprint lights up its patented wringing mechanism. Apparently progress once meant fewer blisters." if _toggle(bits, "schematic_lit") else "You switch off the highlight. The museum is preserving the mop's history; you are preserving its electricity bill.", "terminal")
		"bit_donor":
			_say(game, "The donor tour thanks seventeen benefactors before mentioning the invention. You skip ahead to the invention; it thanks the benefactors again." if count % 2 else "The tour offers to add your name for a generous donation. You offer lint. It thanks the benefactors again.", "dialogue")
		"bit_model":
			_say(game, "The model's engines glow. Its launch schedule is perfect because its passengers are imaginary." if _toggle(bits, "model_lit") else "You end the demonstration. For once, a captain returns a ship exactly where the cleaning crew expects it.", "terminal")
		"bit_badge_tray":
			if not bool(bits.get("badge_collected", false)):
				bits["badge_collected"] = true
				game.add_item("novelty badge")
				_say(game, "You pin on VISITOR OF THE MINUTE. At last, recognition that requires absolutely no extra shifts.")
			else:
				_say(game, "One complimentary badge per visitor. You already have enough duplicate Rogers in your life.", "blocked")
		"bit_monolith_mascot":
			_say(game, "You press the mascot's shoe. 'A career with us is an uplifting experience!' Its hydraulics lift it two centimetres." if _toggle(bits, "monolith_mascot_cheering") else "The mascot offers free refills on enthusiasm. A small label confirms that all enthusiasm is artificial.", "terminal")
		"bit_monolith_booth":
			_say(game, "You zoom into the burger photograph. One glistening pickle now occupies the entire menu. This is how hunger becomes marketing." if _toggle(bits, "monolith_menu_zoomed") else "You restore the menu to normal size. The advertised burger loses seven storeys and gains a disclaimer.", "ui_click")
		"bit_monolith_mustard":
			bits["monolith_mustard_pumps"] = int(bits.get("monolith_mustard_pumps", 0)) + 1
			_say(game, "You pump the duck. It dispenses mustard with the wounded dignity of an underpaid mascot." if count % 2 else "Another pump. The duck appears to be considering a career outside the condiment sector.", "combine")
		"bit_monolith_window":
			bits["monolith_window_waved"] = true
			_say(game, "You wave at the ship. A landing light blinks back. Finally, a customer acknowledges the cleaning staff." if count % 2 else "You wave again. The pilot has apparently exhausted this week's employee-recognition budget.")
	return true
