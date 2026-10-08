extends RefCounted
## Campaign data and puzzle logic. Every room contains usable scenery and characters.

const ROOM_NAMES := {
	"diner": "ORBITAL DINER",
	"dock": "SERVICE DOCK 7",
	"museum": "ARCADA MEMORIAL MUSEUM",
	"monolith": "MONOLITH BURGER",
	"labion_dock": "LABION — LANDING PLATFORM",
	"labion_jungle": "LABION — VINE CANOPY",
	"labion_bog": "LABION — SINGING BOG",
	"labion_gate": "LABION — RUIN CHECKPOINT",
	"labion_shrine": "LABION — SUDS SHRINE",
	"monolith_berth": "MONOLITH — SHUTTLE BERTH",
	"monolith_kitchen": "MONOLITH — BURGER KITCHEN",
	"monolith_freezer": "MONOLITH — WALK-IN FREEZER",
	"monolith_arcade": "MONOLITH — ASTRO CHICKEN ARCADE",
	"plexi_dock": "PLEXI-PRIME — ARRIVAL DOCK",
	"plexi_plaza": "PLEXI-PRIME — MIRROR PLAZA",
	"plexi_gallery": "PLEXI-PRIME — REFRACTION GALLERY",
	"plexi_control": "PLEXI-PRIME — ROBO-JANITOR CONTROL",
	"plexi_vault": "PLEXI-PRIME — SQUEEGEE VAULT",
	"starcon_dock": "STARCON — ACADEMY DOCK",
	"starcon_hall": "STARCON — CADET HALL",
	"starcon_class": "STARCON — ADVANCED MOP DYNAMICS",
	"starcon_simulator": "STARCON — SUCTION SIMULATOR",
	"starcon_lab": "STARCON — SUCTION RESEARCH LAB",
	"polysorbate_dock": "POLYSORBATE LX — DOCKSIDE",
	"polysorbate_market": "POLYSORBATE LX — JUNK MARKET",
	"polysorbate_alley": "POLYSORBATE LX — BACK ALLEY",
	"glitzon_dock": "GLITZON — CELEBRITY DOCK",
	"glitzon_boulevard": "GLITZON — STARLIGHT BOULEVARD",
	"glitzon_vault": "GLITZON — ETERNAL SHINE VAULT",
	"clone_chamber": "R0-GER — MOP0CALYPSE CHAMBER",
}

const ARTIFACTS := ["bucket of eternal suds", "squeegee of power", "vacuum of infinite suction", "broom of cosmic sweep", "polish of eternal shine"]
const ITEM_NAMES := {
	"empty flask": "Empty survey flask", "vine rope": "Braided vine rope", "bog herb": "Medicinal bog herb",
	"bucket of eternal suds": "Bucket of Eternal Suds", "fryer sludge": "Monolith fryer sludge",
	"service token": "Monolith staff records token", "frozen memo": "Thawed employee memo", "arcade code": "Astro Chicken route code",
	"mirror wrench": "Mirror alignment wrench", "squeegee of power": "Squeegee of Power", "academy badge": "StarCon student badge",
	"mop certificate": "Advanced Mop Dynamics certificate", "vacuum of infinite suction": "Vacuum of Infinite Suction",
	"trade chit": "Salvage trade chit", "broom of cosmic sweep": "Broom of Cosmic Sweep", "sunglasses": "Protective sunglasses",
	"polish of eternal shine": "Polish of Eternal Shine", "mop of destiny": "Mop of Destiny"
}
const ITEM_SHORT := {
	"empty flask": "FLASK", "vine rope": "VINE", "bog herb": "HERB", "bucket of eternal suds": "BUCKET",
	"fryer sludge": "SLUDGE", "service token": "TOKEN", "frozen memo": "MEMO", "arcade code": "CODE",
	"mirror wrench": "WRENCH", "squeegee of power": "SQUEEGEE", "academy badge": "CADET", "mop certificate": "DIPLOMA",
	"vacuum of infinite suction": "VACUUM", "trade chit": "TRADE", "broom of cosmic sweep": "BROOM",
	"sunglasses": "SHADES", "polish of eternal shine": "POLISH", "mop of destiny": "DESTINY"
}

const ROOM_INTROS := {
	"diner": "Your shift ended three hours ago. Naturally, the universe waited until now to need a janitor.",
	"dock": "A dock inspector, a grounded shuttle, and an impressive backlog of paperwork. Home sweet bureaucracy.",
	"museum": "The museum's priceless navigation archive is guarded by a machine with very strong opinions about cleanliness.",
	"monolith": "Monolith Burger. Billions served, several identified. Your shuttle is waiting at the berth on the right.",
	"labion_dock": "A damp landing platform, an optimistic safety notice, and an ecosystem that has never met bleach.",
	"labion_jungle": "The vines have annexed the path. Their paperwork is surprisingly thorough.",
	"labion_bog": "The bog sings softly. It has excellent acoustics and a disturbing appetite.",
	"labion_gate": "A guard with a spectacular cold stands between you and ancient custodial glory.",
	"labion_shrine": "The Bucket of Eternal Suds waits in a temple whose last clean was recorded in a dead language.",
	"monolith_berth": "Your ship rests beside the galaxy’s least nutritious beacon. The kitchen drain has its own airlock.",
	"monolith_kitchen": "A kitchen where no substance may leave until it has been deep-fried twice.",
	"monolith_freezer": "The freezer preserves burgers, records, and one employee’s enthusiasm at minus thirty degrees.",
	"monolith_arcade": "Astro Chicken returns. The cabinet has survived four management teams and every attempt to explain it.",
	"plexi_dock": "Plexi-Prime reflects everything except on its poor employment practices.",
	"plexi_plaza": "A mirror plaza displays six angles of your face. None was necessary.",
	"plexi_gallery": "The gallery takes light very seriously. Visitors should take being incinerated similarly.",
	"plexi_control": "A Robo-Janitor supervises a security system based entirely on impeccable reflection.",
	"plexi_vault": "The Squeegee of Power rests under security lighting that has never seen a streak.",
	"starcon_dock": "StarCon welcomes future heroes and people who parked in the wrong bay.",
	"starcon_hall": "Enrollment runs on courage, discipline, and five identical copies of the same form.",
	"starcon_class": "Advanced Mop Dynamics: finally, years of humiliation count as prerequisites.",
	"starcon_simulator": "The simulator recreates a black hole, a supernova, or the academy’s budget meeting.",
	"starcon_lab": "This vacuum can remove dirt, planets, and inconvenient evidence.",
	"polysorbate_dock": "Polysorbate LX has made industrial residue a tourism category.",
	"polysorbate_market": "The market sells authentic antiques. Several become antiques next Tuesday.",
	"polysorbate_alley": "A back alley where even the rubbish tries to look inconspicuous.",
	"glitzon_dock": "Glitzon sparkles so fiercely its weather report includes lens flare.",
	"glitzon_boulevard": "The boulevard is paved with stars. Most resent you walking on them.",
	"glitzon_vault": "An eternal shine has outlived its warranty twice.",
	"clone_chamber": "Six sockets, one enormous machine, and no plan for living in a perfectly sterile universe.",
}

const LINKS := {
	"labion_dock": ["labion_jungle", "travel"],
	"labion_jungle": ["labion_dock", "labion_bog"],
	"labion_bog": ["labion_jungle", "labion_gate"],
	"labion_gate": ["labion_bog", "labion_shrine"],
	"labion_shrine": ["labion_gate", "labion_dock"],
	"monolith_berth": ["monolith", "travel"],
	"monolith_kitchen": ["monolith", "monolith_freezer"],
	"monolith_freezer": ["monolith_kitchen", "monolith_arcade"],
	"monolith_arcade": ["monolith", "monolith_berth"],
	"plexi_dock": ["travel", "plexi_plaza"],
	"plexi_plaza": ["plexi_dock", "plexi_gallery"],
	"plexi_gallery": ["plexi_plaza", "plexi_control"],
	"plexi_control": ["plexi_gallery", "plexi_vault"],
	"plexi_vault": ["plexi_control", "plexi_dock"],
	"starcon_dock": ["travel", "starcon_hall"],
	"starcon_hall": ["starcon_class", "starcon_simulator"],
	"starcon_class": ["starcon_hall", "starcon_simulator"],
	"starcon_simulator": ["starcon_class", "starcon_lab"],
	"starcon_lab": ["starcon_simulator", "starcon_dock"],
	"polysorbate_dock": ["travel", "polysorbate_market"],
	"polysorbate_market": ["polysorbate_dock", "polysorbate_alley"],
	"polysorbate_alley": ["polysorbate_market", "polysorbate_dock"],
	"glitzon_dock": ["travel", "glitzon_boulevard"],
	"glitzon_boulevard": ["glitzon_dock", "glitzon_vault"],
	"glitzon_vault": ["glitzon_boulevard", "glitzon_dock"],
	"clone_chamber": ["travel", "travel"],
}

const HOTSPOTS := {
	"labion_dock": {
		"left": {"rect": Rect2(0, 111, 90, 118), "at": Vector2(45.0, 281), "name": "To LABION / VINE CANOPY", "use_label": "Enter"},
		"right": {"rect": Rect2(554, 120, 86, 112), "at": Vector2(597.0, 281), "name": "Shuttle airlock", "use_label": "Board"},
		"npc": {"rect": Rect2(409, 116, 68, 110), "at": Vector2(443.0, 281), "name": "Dockmaster Jib", "use_label": "Talk to"},
		"object": {"rect": Rect2(284, 138, 122, 84), "at": Vector2(345.0, 281), "name": "Landing service kiosk", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(162, 181, 17, 12), "at": Vector2(170.5, 281), "name": "Sealed survey flask case", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(292, 209, 21, 12), "at": Vector2(302.5, 281), "name": "Emergency beacon", "use_label": "Try"},
	},
	"labion_jungle": {
		"left": {"rect": Rect2(0, 110, 66, 129), "at": Vector2(33.0, 281), "name": "To LABION / LANDING PLATFORM", "use_label": "Enter"},
		"right": {"rect": Rect2(551, 155, 89, 89), "at": Vector2(595.5, 281), "name": "To LABION / SINGING BOG", "use_label": "Enter"},
		"npc": {"rect": Rect2(422, 151, 45, 69), "at": Vector2(444.5, 281), "name": "Rilka, the botanist", "use_label": "Talk to"},
		"object": {"rect": Rect2(266, 76, 148, 154), "at": Vector2(340.0, 281), "name": "Survey winch and carnivorous vine", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(96, 173, 83, 27), "at": Vector2(137.5, 281), "name": "Coiled vine rope", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(274, 217, 21, 12), "at": Vector2(284.5, 281), "name": "Winch warning light", "use_label": "Try"},
	},
	"labion_bog": {
		"left": {"rect": Rect2(0, 141, 57, 104), "at": Vector2(28.5, 281), "name": "To LABION / VINE CANOPY", "use_label": "Enter"},
		"right": {"rect": Rect2(587, 175, 53, 90), "at": Vector2(613.5, 281), "name": "To LABION / RUIN CHECKPOINT", "use_label": "Enter"},
		"npc": {"rect": Rect2(417, 113, 54, 75), "at": Vector2(444.0, 281), "name": "Bog ranger Merv", "use_label": "Talk to"},
		"object": {"rect": Rect2(314, 52, 30, 104), "at": Vector2(329.0, 281), "name": "Quicksand crossing", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(151, 149, 47, 39), "at": Vector2(174.5, 281), "name": "Medicinal bog herb", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(260, 171, 123, 56), "at": Vector2(321, 281), "name": "Quicksand bubbles", "use_label": "Try"},
	},
	"labion_gate": {
		"left": {"rect": Rect2(0, 132, 94, 91), "at": Vector2(47.0, 281), "name": "To LABION / SINGING BOG", "use_label": "Enter"},
		"right": {"rect": Rect2(470, 72, 156, 150), "at": Vector2(548.0, 281), "name": "To LABION / SUDS SHRINE", "use_label": "Enter"},
		"npc": {"rect": Rect2(386, 110, 70, 114), "at": Vector2(421.0, 281), "name": "Sniffling temple guard", "use_label": "Talk to"},
		"object": {"rect": Rect2(279, 109, 71, 115), "at": Vector2(314.5, 281), "name": "Sanitation checkpoint", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(162, 180, 28, 10), "at": Vector2(176.0, 281), "name": "Unissued temple visitor pass", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(287, 211, 21, 12), "at": Vector2(297.5, 281), "name": "Checkpoint gong switch", "use_label": "Try"},
	},
	"labion_shrine": {
		"left": {"rect": Rect2(0, 103, 83, 113), "at": Vector2(41.5, 281), "name": "To LABION / RUIN CHECKPOINT", "use_label": "Enter"},
		"right": {"rect": Rect2(555, 66, 69, 157), "at": Vector2(589.5, 281), "name": "To LABION / LANDING PLATFORM", "use_label": "Enter"},
		"npc": {"rect": Rect2(424, 80, 92, 149), "at": Vector2(470.0, 281), "name": "Keeper Foam", "use_label": "Talk to"},
		"object": {"rect": Rect2(151, 119, 63, 55), "at": Vector2(182.5, 281), "name": "Custodian oath pedestal", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(334, 123, 65, 54), "at": Vector2(366.5, 281), "name": "Bucket of Eternal Suds", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(204, 182, 35, 17), "at": Vector2(221.5, 281), "name": "Ancient soap bar", "use_label": "Try"},
	},
	"monolith_berth": {
		"left": {"rect": Rect2(8, 86, 87, 105), "at": Vector2(51.5, 281), "name": "To MONOLITH BURGER", "use_label": "Enter"},
		"right": {"rect": Rect2(566, 63, 74, 123), "at": Vector2(603.0, 281), "name": "Shuttle airlock", "use_label": "Board"},
		"npc": {"rect": Rect2(360, 121, 90, 74), "at": Vector2(405.0, 281), "name": "Dockbot Bumper", "use_label": "Talk to"},
		"object": {"rect": Rect2(209, 78, 146, 115), "at": Vector2(282.0, 281), "name": "Grease drain valve", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(147, 159, 28, 10), "at": Vector2(161.0, 281), "name": "Spare drain wrench", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(217, 180, 21, 12), "at": Vector2(227.5, 281), "name": "Luggage alarm test switch", "use_label": "Try"},
	},
	"monolith_kitchen": {
		"left": {"rect": Rect2(0, 55, 71, 140), "at": Vector2(35.5, 281), "name": "To MONOLITH BURGER", "use_label": "Enter"},
		"right": {"rect": Rect2(555, 57, 85, 140), "at": Vector2(597.5, 281), "name": "To MONOLITH / WALK-IN FREEZER", "use_label": "Enter"},
		"npc": {"rect": Rect2(398, 75, 92, 112), "at": Vector2(444.0, 281), "name": "Chef Sizzl", "use_label": "Talk to"},
		"object": {"rect": Rect2(222, 108, 174, 93), "at": Vector2(309.0, 281), "name": "Industrial grease trap", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(144, 136, 53, 17), "at": Vector2(170.5, 281), "name": "Thermal gloves", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(93, 133, 44, 16), "at": Vector2(115.0, 281), "name": "Suspicious tasting ladle", "use_label": "Try"},
	},
	"monolith_freezer": {
		"left": {"rect": Rect2(0, 68, 97, 173), "at": Vector2(48.5, 281), "name": "To MONOLITH / BURGER KITCHEN", "use_label": "Enter"},
		"right": {"rect": Rect2(578, 86, 62, 146), "at": Vector2(609.0, 281), "name": "To MONOLITH / ASTRO CHICKEN ARCADE", "use_label": "Enter"},
		"npc": {"rect": Rect2(406, 49, 88, 113), "at": Vector2(450.0, 281), "name": "Frosty, frozen employee", "use_label": "Talk to"},
		"object": {"rect": Rect2(315, 129, 41, 40), "at": Vector2(335.5, 281), "name": "Staff records icebox", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(191, 110, 57, 26), "at": Vector2(219.5, 281), "name": "Emergency thermal battery", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(261, 99, 38, 38), "at": Vector2(280.0, 281), "name": "Freezer warming panel", "use_label": "Try"},
	},
	"monolith_arcade": {
		"left": {"rect": Rect2(0, 79, 82, 127), "at": Vector2(41.0, 281), "name": "To MONOLITH BURGER", "use_label": "Enter"},
		"right": {"rect": Rect2(570, 94, 68, 119), "at": Vector2(604.0, 281), "name": "To MONOLITH / SHUTTLE BERTH", "use_label": "Enter"},
		"npc": {"rect": Rect2(400, 155, 76, 82), "at": Vector2(438.0, 281), "name": "Cluck-9, arcade attendant", "use_label": "Talk to"},
		"object": {"rect": Rect2(212, 61, 178, 188), "at": Vector2(301.0, 281), "name": "Astro Chicken cabinet", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(139, 178, 16, 8), "at": Vector2(147.0, 281), "name": "Abandoned arcade token", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(92, 147, 33, 38), "at": Vector2(108.5, 281), "name": "Prize ticket scanner", "use_label": "Try"},
	},
	"plexi_dock": {
		"left": {"rect": Rect2(0, 51, 67, 146), "at": Vector2(33.5, 281), "name": "Shuttle airlock", "use_label": "Board"},
		"right": {"rect": Rect2(552, 72, 88, 131), "at": Vector2(596.0, 281), "name": "To PLEXI-PRIME / MIRROR PLAZA", "use_label": "Enter"},
		"npc": {"rect": Rect2(398, 80, 57, 119), "at": Vector2(426.5, 281), "name": "Dock clerk Prism", "use_label": "Talk to"},
		"object": {"rect": Rect2(302, 126, 80, 73), "at": Vector2(342.0, 281), "name": "Shuttle navigation kiosk", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(161, 143, 34, 16), "at": Vector2(178.0, 281), "name": "Reflective safety visor", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(310, 186, 21, 12), "at": Vector2(320.5, 281), "name": "Polishing drone control", "use_label": "Try"},
	},
	"plexi_plaza": {
		"left": {"rect": Rect2(0, 104, 56, 115), "at": Vector2(28.0, 281), "name": "To PLEXI-PRIME / ARRIVAL DOCK", "use_label": "Enter"},
		"right": {"rect": Rect2(555, 72, 85, 147), "at": Vector2(597.5, 281), "name": "To PLEXI-PRIME / REFRACTION GALLERY", "use_label": "Enter"},
		"npc": {"rect": Rect2(437, 135, 65, 76), "at": Vector2(469.5, 281), "name": "Tour guide Gleam", "use_label": "Talk to"},
		"object": {"rect": Rect2(273, 162, 124, 52), "at": Vector2(335.0, 281), "name": "Reflective directory", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(173, 158, 41, 30), "at": Vector2(193.5, 281), "name": "Mirror wrench", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(281, 201, 21, 12), "at": Vector2(291.5, 281), "name": "Holographic fountain", "use_label": "Try"},
	},
	"plexi_gallery": {
		"left": {"rect": Rect2(0, 61, 84, 136), "at": Vector2(42.0, 281), "name": "To PLEXI-PRIME / MIRROR PLAZA", "use_label": "Enter"},
		"right": {"rect": Rect2(578, 61, 62, 136), "at": Vector2(609.0, 281), "name": "To PLEXI-PRIME / ROBO-JANITOR CONTROL", "use_label": "Enter"},
		"npc": {"rect": Rect2(454, 120, 36, 93), "at": Vector2(472.0, 281), "name": "Curator Facet", "use_label": "Talk to"},
		"object": {"rect": Rect2(216, 76, 201, 118), "at": Vector2(316.5, 281), "name": "Adjustable mirror array", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(162, 157, 22, 17), "at": Vector2(173.0, 281), "name": "Exhibit prism", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(224, 181, 21, 12), "at": Vector2(234.5, 281), "name": "Laser demonstration switch", "use_label": "Try"},
	},
	"plexi_control": {
		"left": {"rect": Rect2(15, 59, 77, 151), "at": Vector2(53.5, 281), "name": "To PLEXI-PRIME / REFRACTION GALLERY", "use_label": "Enter"},
		"right": {"rect": Rect2(505, 67, 135, 147), "at": Vector2(572.5, 281), "name": "To PLEXI-PRIME / SQUEEGEE VAULT", "use_label": "Enter"},
		"npc": {"rect": Rect2(420, 99, 56, 122), "at": Vector2(448.0, 281), "name": "Custodial unit P-LISH", "use_label": "Talk to"},
		"object": {"rect": Rect2(231, 118, 188, 92), "at": Vector2(325.0, 281), "name": "Vault beam console", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(195, 148, 13, 16), "at": Vector2(201.5, 281), "name": "Spare alignment prism", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(239, 197, 21, 12), "at": Vector2(249.5, 281), "name": "Floor buffer switch", "use_label": "Try"},
	},
	"plexi_vault": {
		"left": {"rect": Rect2(0, 55, 103, 163), "at": Vector2(51.5, 281), "name": "To PLEXI-PRIME / ROBO-JANITOR CONTROL", "use_label": "Enter"},
		"right": {"rect": Rect2(555, 54, 85, 164), "at": Vector2(597.5, 281), "name": "To PLEXI-PRIME / ARRIVAL DOCK", "use_label": "Enter"},
		"npc": {"rect": Rect2(446, 129, 44, 90), "at": Vector2(468.0, 281), "name": "Vault caretaker Pane", "use_label": "Talk to"},
		"object": {"rect": Rect2(142, 147, 21, 31), "at": Vector2(152.5, 281), "name": "Artifact pressure stand", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(295, 99, 64, 54), "at": Vector2(327.0, 281), "name": "Squeegee of Power", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(150, 165, 13, 12), "at": Vector2(156.5, 281), "name": "Security grille control", "use_label": "Try"},
	},
	"starcon_dock": {
		"left": {"rect": Rect2(0, 42, 67, 133), "at": Vector2(33.5, 281), "name": "Shuttle airlock", "use_label": "Board"},
		"right": {"rect": Rect2(533, 68, 107, 128), "at": Vector2(586.5, 281), "name": "To STARCON / CADET HALL", "use_label": "Enter"},
		"npc": {"rect": Rect2(407, 104, 49, 118), "at": Vector2(431.5, 281), "name": "Flight instructor Decks", "use_label": "Talk to"},
		"object": {"rect": Rect2(300, 134, 97, 31), "at": Vector2(348.5, 281), "name": "Shuttle navigation kiosk", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(187, 158, 13, 11), "at": Vector2(193.5, 281), "name": "Unissued cadet badge", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(308, 152, 21, 12), "at": Vector2(318.5, 281), "name": "Luggage rack release", "use_label": "Try"},
	},
	"starcon_hall": {
		"left": {"rect": Rect2(0, 82, 99, 121), "at": Vector2(49.5, 281), "name": "To STARCON / ADVANCED MOP DYNAMICS", "use_label": "Enter"},
		"right": {"rect": Rect2(563, 82, 77, 127), "at": Vector2(601.5, 281), "name": "To STARCON / SUCTION SIMULATOR", "use_label": "Enter"},
		"return": {"rect": Rect2(0, 247, 65, 37), "at": Vector2(50, 290), "name": "Back to Academy Dock", "use_label": "Return"},
		"npc": {"rect": Rect2(406, 136, 34, 92), "at": Vector2(423.0, 281), "name": "Registrar Form-ica", "use_label": "Talk to"},
		"object": {"rect": Rect2(249, 107, 168, 102), "at": Vector2(333.0, 281), "name": "Enrollment information desk", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(188, 169, 16, 8), "at": Vector2(196.0, 281), "name": "Registrar credential shelf", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(257, 196, 21, 12), "at": Vector2(267.5, 281), "name": "Coffee service switch", "use_label": "Try"},
	},
	"starcon_class": {
		"left": {"rect": Rect2(0, 123, 48, 47), "at": Vector2(25, 281), "name": "To STARCON / CADET HALL", "use_label": "Enter"},
		"right": {"rect": Rect2(589, 122, 51, 57), "at": Vector2(614.5, 281), "name": "To STARCON / SUCTION SIMULATOR", "use_label": "Enter"},
		"npc": {"rect": Rect2(410, 98, 74, 118), "at": Vector2(447.0, 281), "name": "Professor Swab", "use_label": "Talk to"},
		"object": {"rect": Rect2(244, 165, 165, 55), "at": Vector2(326.5, 281), "name": "Mop Dynamics examination station", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(83, 163, 37, 53), "at": Vector2(101.5, 281), "name": "Credential dispenser", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(252, 207, 21, 12), "at": Vector2(262.5, 281), "name": "Practice console mop mode", "use_label": "Try"},
	},
	"starcon_simulator": {
		"left": {"rect": Rect2(0, 82, 48, 117), "at": Vector2(25, 281), "name": "To STARCON / ADVANCED MOP DYNAMICS", "use_label": "Enter"},
		"right": {"rect": Rect2(599, 82, 41, 117), "at": Vector2(615, 281), "name": "To STARCON / SUCTION RESEARCH LAB", "use_label": "Enter"},
		"npc": {"rect": Rect2(396, 83, 58, 145), "at": Vector2(425.0, 281), "name": "Instructor Suckley", "use_label": "Talk to"},
		"object": {"rect": Rect2(244, 145, 158, 70), "at": Vector2(323.0, 281), "name": "Vacuum hazard simulator", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(118, 76, 73, 40), "at": Vector2(154.5, 281), "name": "Safety procedure placard", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(184, 146, 19, 26), "at": Vector2(193.5, 281), "name": "Unshielded suction lever", "use_label": "Try"},
	},
	"starcon_lab": {
		"left": {"rect": Rect2(0, 79, 65, 130), "at": Vector2(32.5, 281), "name": "To STARCON / SUCTION SIMULATOR", "use_label": "Enter"},
		"right": {"rect": Rect2(570, 77, 70, 127), "at": Vector2(605.0, 281), "name": "To STARCON / ACADEMY DOCK", "use_label": "Enter"},
		"npc": {"rect": Rect2(425, 114, 40, 98), "at": Vector2(445.0, 281), "name": "Dr. Venturi", "use_label": "Talk to"},
		"object": {"rect": Rect2(174, 156, 70, 48), "at": Vector2(209.0, 281), "name": "Artifact containment console", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(299, 69, 48, 105), "at": Vector2(323.0, 281), "name": "Vacuum of Infinite Suction", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(182, 191, 21, 12), "at": Vector2(192.5, 281), "name": "Experimental dust chamber", "use_label": "Try"},
	},
	"polysorbate_dock": {
		"left": {"rect": Rect2(0, 72, 61, 132), "at": Vector2(30.5, 281), "name": "Shuttle airlock", "use_label": "Board"},
		"right": {"rect": Rect2(559, 66, 81, 139), "at": Vector2(599.5, 281), "name": "To POLYSORBATE LX / JUNK MARKET", "use_label": "Enter"},
		"npc": {"rect": Rect2(419, 109, 55, 98), "at": Vector2(446.5, 281), "name": "Dockbroker Grub", "use_label": "Talk to"},
		"object": {"rect": Rect2(291, 111, 91, 93), "at": Vector2(336.5, 281), "name": "Shuttle navigation kiosk", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(165, 152, 69, 48), "at": Vector2(199.5, 281), "name": "Scrap recycling bin", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(299, 191, 21, 12), "at": Vector2(309.5, 281), "name": "Air freshener button", "use_label": "Try"},
	},
	"polysorbate_market": {
		"left": {"rect": Rect2(0, 72, 69, 133), "at": Vector2(34.5, 281), "name": "To POLYSORBATE LX / DOCKSIDE", "use_label": "Enter"},
		"right": {"rect": Rect2(555, 82, 85, 126), "at": Vector2(597.5, 281), "name": "To POLYSORBATE LX / BACK ALLEY", "use_label": "Enter"},
		"npc": {"rect": Rect2(403, 90, 68, 118), "at": Vector2(437.0, 281), "name": "Salvage vendor Vreek", "use_label": "Talk to"},
		"object": {"rect": Rect2(308, 76, 40, 112), "at": Vector2(328.0, 281), "name": "Display broom price scanner", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(165, 162, 35, 15), "at": Vector2(182.5, 281), "name": "Souvenir trade disc", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(316, 175, 21, 12), "at": Vector2(326.5, 281), "name": "Souvenir authenticity dial", "use_label": "Try"},
	},
	"polysorbate_alley": {
		"left": {"rect": Rect2(0, 79, 54, 126), "at": Vector2(27.0, 281), "name": "To POLYSORBATE LX / JUNK MARKET", "use_label": "Enter"},
		"right": {"rect": Rect2(588, 82, 52, 123), "at": Vector2(614.0, 281), "name": "To POLYSORBATE LX / DOCKSIDE", "use_label": "Enter"},
		"npc": {"rect": Rect2(421, 128, 69, 79), "at": Vector2(455.5, 281), "name": "Alley custodian Filch", "use_label": "Talk to"},
		"object": {"rect": Rect2(243, 87, 166, 115), "at": Vector2(326.0, 281), "name": "Trade-chit salvage locker", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(94, 171, 56, 34), "at": Vector2(122.0, 281), "name": "Sealed artifact case", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(158, 177, 20, 18), "at": Vector2(168.0, 281), "name": "Vendor’s gold token", "use_label": "Try"},
	},
	"glitzon_dock": {
		"left": {"rect": Rect2(57, 82, 77, 100), "at": Vector2(95.5, 281), "name": "Shuttle airlock", "use_label": "Board"},
		"right": {"rect": Rect2(588, 97, 52, 131), "at": Vector2(614.0, 281), "name": "To GLITZON / STARLIGHT BOULEVARD", "use_label": "Enter"},
		"npc": {"rect": Rect2(411, 132, 84, 74), "at": Vector2(453.0, 281), "name": "Arrival stylist Dazzle", "use_label": "Talk to"},
		"object": {"rect": Rect2(298, 96, 90, 119), "at": Vector2(343.0, 281), "name": "Shuttle navigation kiosk", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(181, 164, 44, 15), "at": Vector2(203.0, 281), "name": "Luxury eyewear display", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(306, 202, 21, 12), "at": Vector2(316.5, 281), "name": "Celebrity luggage release", "use_label": "Try"},
	},
	"glitzon_boulevard": {
		"left": {"rect": Rect2(0, 87, 46, 122), "at": Vector2(25, 281), "name": "To GLITZON / CELEBRITY DOCK", "use_label": "Enter"},
		"right": {"rect": Rect2(593, 86, 47, 124), "at": Vector2(615, 281), "name": "To GLITZON / ETERNAL SHINE VAULT", "use_label": "Enter"},
		"npc": {"rect": Rect2(390, 85, 91, 149), "at": Vector2(435.5, 281), "name": "Security concierge Flash", "use_label": "Talk to"},
		"object": {"rect": Rect2(274, 68, 88, 158), "at": Vector2(318.0, 281), "name": "Dazzling vault entrance scanner", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(189, 158, 21, 14), "at": Vector2(199.5, 281), "name": "Unsigned celebrity permit", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(282, 213, 21, 12), "at": Vector2(292.5, 281), "name": "Autograph machine switch", "use_label": "Try"},
	},
	"glitzon_vault": {
		"left": {"rect": Rect2(17, 76, 90, 135), "at": Vector2(62.0, 281), "name": "To GLITZON / STARLIGHT BOULEVARD", "use_label": "Enter"},
		"right": {"rect": Rect2(540, 76, 99, 135), "at": Vector2(589.5, 281), "name": "To GLITZON / CELEBRITY DOCK", "use_label": "Enter"},
		"npc": {"rect": Rect2(425, 100, 62, 117), "at": Vector2(456.0, 281), "name": "Custodian Lustre", "use_label": "Talk to"},
		"object": {"rect": Rect2(168, 145, 42, 26), "at": Vector2(189.0, 281), "name": "Polish containment stand", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(304, 90, 37, 70), "at": Vector2(322.5, 281), "name": "Polish of Eternal Shine", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(176, 158, 21, 12), "at": Vector2(186.5, 281), "name": "Unfiltered shine control", "use_label": "Try"},
	},
	"clone_chamber": {
		"intake": {"rect": Rect2(166, 160, 17, 15), "at": Vector2(181, 281), "name": "Forbidden contaminant intake", "use_label": "Use"},
		"left": {"rect": Rect2(0, 90, 49, 101), "at": Vector2(25, 281), "name": "Shuttle airlock", "use_label": "Board"},
		"right": {"rect": Rect2(598, 91, 42, 100), "at": Vector2(615, 281), "name": "Shuttle airlock", "use_label": "Board"},
		"npc": {"rect": Rect2(475, 97, 61, 112), "at": Vector2(505.5, 281), "name": "R0-GER, your counterfeit clone", "use_label": "Talk to"},
		"object": {"rect": Rect2(204, 136, 248, 53), "at": Vector2(328.0, 281), "name": "Universal cleaning apparatus", "use_label": "Interact with"},
		"pickup": {"rect": Rect2(407, 156, 34, 15), "at": Vector2(424.0, 281), "name": "Stolen Mop of Destiny", "use_label": "Inspect / collect"},
		"extra": {"rect": Rect2(175, 140, 17, 16), "at": Vector2(183.5, 281), "name": "Universal sterilization trigger", "use_label": "Try"},
	},
	"monolith": {
		"campaign_left": {"rect": Rect2(546, 99, 31, 113), "at": Vector2(545, 281), "name": "Kitchen access hatch", "use_label": "Enter"},
		"campaign_right": {"rect": Rect2(155, 77, 29, 121), "at": Vector2(179, 281), "name": "Astro Chicken arcade passage", "use_label": "Enter"},
		"exit": {"rect": Rect2(581, 92, 59, 137), "at": Vector2(586, 271), "name": "Shuttle berth door", "use_label": "Enter"},
	}
}


static func _read(game) -> Dictionary:
	var value = game.state.get("campaign", {})
	return value if value is Dictionary else {}

static func _data(game) -> Dictionary:
	if not game.state.get("campaign", null) is Dictionary:
		game.state["campaign"] = {}
	return game.state["campaign"]

static func _done(game, key: String) -> bool:
	return bool(_read(game).get(key, false))

static func _mark(game, key: String) -> void:
	_data(game)[key] = true

static func _gain(game, key: String, points: int) -> void:
	_mark(game, key)
	game.award("campaign_" + key, points)

static func _line(game, text: String, npc: bool = false) -> void:
	game.show_dialog("campaign_npc" if npc else "roger", [text])

static func _blocked(game, text: String, npc: bool = false) -> void:
	game.audio.play_sfx("blocked")
	_line(game, text, npc)

static func _take(game, room: String, item: String, points: int, message: String) -> void:
	if _done(game, "taken:" + room):
		_line(game, "You already collected it. Taking an empty stand would make this a very different adventure.")
		return
	_mark(game, "taken:" + room)
	game.add_item(item)
	if points > 0:
		_gain(game, "pickup:" + room, points)
	_line(game, message)

static func visible(_game, _room: String, _id: String) -> bool:
	# Empty stands stay inspectable, and other modules own their own visibility.
	return true

static func is_character(room: String, id: String) -> bool:
	return LINKS.has(room) and id == "npc"

static func default_action(room: String, id: String) -> String:
	return "Talk" if is_character(room, id) else "Use"

static func destination_room(_game, id: String) -> String:
	return {"dock": "dock", "monolith": "monolith", "labion": "labion_dock", "plexi": "plexi_dock", "starcon": "starcon_dock", "polysorbate": "polysorbate_dock", "glitzon": "glitzon_dock", "finale": "clone_chamber"}.get(id, "")

static func navigation_routes(game, room: String) -> Array:
	if room not in ["dock", "monolith", "monolith_berth", "labion_dock", "plexi_dock", "starcon_dock", "polysorbate_dock", "glitzon_dock", "clone_chamber"]:
		return []
	var routes: Array = [
		{"id": "dock", "label": "Service Dock 7", "enabled": true, "reason": "Your original service berth."},
		{"id": "monolith", "label": "Monolith Burger", "enabled": true, "reason": "The local franchise route is pre-programmed."},
		{"id": "labion", "label": "Labion", "enabled": game.flag("coordinates_set"), "reason": "Load the museum star map at the service dock terminal."},
		{"id": "plexi", "label": "Plexi-Prime", "enabled": _done(game, "plexi_unlocked"), "reason": "Decode the employee memo at Monolith's Astro Chicken arcade."},
		{"id": "starcon", "label": "StarCon Academy", "enabled": _done(game, "starcon_unlocked"), "reason": "Recover the Squeegee of Power on Plexi-Prime."},
		{"id": "polysorbate", "label": "Polysorbate LX", "enabled": _done(game, "polysorbate_unlocked"), "reason": "Recover StarCon's legendary vacuum."},
		{"id": "glitzon", "label": "Glitzon", "enabled": _done(game, "glitzon_unlocked"), "reason": "Recover the cosmic broom from Polysorbate's salvage locker."},
		{"id": "finale", "label": "R0-GER's command ship", "enabled": _done(game, "finale_unlocked"), "reason": "The Polish of Eternal Shine records the clone's final rendezvous."}
	]
	var available: Array = []
	for route in routes:
		if destination_room(game, str(route["id"])) == room:
			continue
		if room == "monolith_berth" and route["id"] == "monolith":
			continue
		available.append(route)
	return available

static func _passage_target(room: String, id: String) -> String:
	if room == "starcon_hall" and id == "return":
		return "starcon_dock"
	return LINKS[room][0 if id == "left" else 1]

static func _walk(game, room: String, id: String) -> void:
	var target: String = _passage_target(room, id)
	if target == "monolith_kitchen" and not game.has_item("bucket of eternal suds") and not _done(game, "bucket_recovered"):
		_blocked(game, "Kitchen access is restricted to legendary sanitation contractors. Recover Labion's Bucket of Eternal Suds first.")
		return
	if id == "right":
		match room:
			"labion_bog":
				if not _done(game, "bog_crossed"):
					_blocked(game, "The far path is across quicksand. Tie the vine rope to the crossing before trying it.")
					return
			"labion_gate":
				if not _done(game, "labion_gate_open"):
					_blocked(game, "The guard is too miserable to check your credentials. The bog ranger mentioned a medicinal herb.")
					return
			"plexi_control":
				if not _done(game, "plexi_vault_open"):
					_blocked(game, "The vault beam is still live. Align the gallery mirrors, show the Robo-Janitor your maintenance pass, then operate the beam console.")
					return
			"starcon_simulator":
				if not _done(game, "simulator_clearance"):
					_blocked(game, "Research access requires a passed suction simulation. Use your Mop Dynamics certificate on the simulator.")
					return
			"glitzon_boulevard":
				if not _done(game, "glitzon_vault_open"):
					_blocked(game, "The concierge controls the vault door. Protect your eyes at the scanner, then talk to Flash.")
					return
	if target == "travel":
		game.open_travel_menu()
	else:
		game.enter_room(target, Vector2(563, 281) if id == "left" else Vector2(73, 281))

static func handle(game, room: String, id: String, action: String, item: String) -> bool:
	if room == "monolith" and id in ["exit", "campaign_left", "campaign_right"]:
		if action == "Look":
			_line(game, {"exit": "The berth houses your shuttle and the kitchen's exterior grease valve.", "campaign_left": "A staff hatch leads to Monolith's kitchen. Legendary cleaning equipment earns staff access.", "campaign_right": "A passage to Astro Chicken, the freezer corridor, and several lost childhoods."}[id])
		elif item != "":
			_blocked(game, "Doors prefer an unoccupied hand. Keep your inventory item and click it again to put it away.")
		elif id == "campaign_left" and not game.has_item("bucket of eternal suds") and not _done(game, "bucket_recovered"):
			_blocked(game, "Monolith requires legendary sanitation credentials for kitchen access. Follow the clone to Labion and recover the Bucket first.")
		else:
			game.enter_room({"exit": "monolith_berth", "campaign_left": "monolith_kitchen", "campaign_right": "monolith_arcade"}[id], Vector2(73, 281))
		return true
	if not LINKS.has(room) or not HOTSPOTS[room].has(id):
		return false
	if action == "Look":
		_look(game, room, id)
		return true
	if item != "" and not game.has_item(item):
		_blocked(game, "That item is not in your pockets. Your imagination remains better equipped than your inventory.")
		return true
	if id in ["left", "right", "return"]:
		if item == "":
			_walk(game, room, id)
		else:
			_blocked(game, "Keep the " + str(ITEM_NAMES.get(item, item)) + ". Click your selected pocket item again before using the passage.")
		return true
	if action == "Walk":
		game.say("Standing beside " + str(HOTSPOTS[room][id]["name"]) + ". Click to interact, or right-click to inspect.")
		return true
	if id == "npc":
		_npc(game, room, item)
	elif id == "pickup":
		if item == "":
			_pickup(game, room)
		else:
			_blocked(game, "You keep your " + str(ITEM_NAMES.get(item, item)) + ". It is not a substitute for picking something up.")
	elif id in ["object", "intake"]:
		_object(game, room, item)
	elif id == "extra":
		if item == "":
			_extra(game, room)
		else:
			_blocked(game, "Your " + str(ITEM_NAMES.get(item, item)) + " stays in your pocket. This experiment has enough uncontrolled variables.")
	return true

static func _look(game, room: String, id: String) -> void:
	if id == "npc":
		_line(game, str(HOTSPOTS[room][id]["name"]) + ". They look like someone who knows the local procedure, and would enjoy telling you about it.")
	elif id in ["left", "right", "return"]:
		var target: String = _passage_target(room, id)
		_line(game, "Your shuttle's navigation menu is through here." if target == "travel" else "This passage leads to " + str(ROOM_NAMES[target]) + ".")
	elif id == "pickup" and _done(game, "taken:" + room):
		_line(game, "You already collected the useful part. The display remains a surprisingly accurate exhibit of absence.")
	elif id == "object":
		_line(game, _local_hint(game, room))
	else:
		_line(game, str(HOTSPOTS[room][id]["name"]) + ". It has survived local management; your intervention may be the safer option.")

static func _npc(game, room: String, item: String) -> void:
	if item != "" and item == "novelty badge":
		_line(game, "Visitor of the Minute? An impressive rank. Around here, visitors usually last only thirty seconds before somebody hands them a form.", true)
		return
	match room:
		"labion_gate":
			if item == "bog herb":
				game.remove_item(item)
				_gain(game, "labion_gate_open", 5)
				_line(game, "My sinuses! I can smell colours again! The shrine is open to you. Its pedestal recognizes a maintenance pass; finally, an ancient civilization with sensible paperwork.", true)
				return
		"monolith_kitchen":
			if item == "" and game.has_item("fryer sludge") and not _done(game, "service_token_given"):
				_mark(game, "service_token_given")
				game.add_item("service token")
				_line(game, "That's the grease our drain rejected. Keep it sealed. Here's a staff records token: use it on the freezer icebox. A memo inside mentions your counterfeit janitor and the Astro Chicken cabinet.", true)
				return
		"monolith_arcade":
			if item == "" and _done(game, "arcade_decoded") and game.has_item("fryer sludge") and _done(game, "bucket_recovered"):
				_gain(game, "plexi_unlocked", 10)
				_line(game, "Your clone hid Plexi-Prime coordinates in an Astro Chicken high score. We spent years assuming that score was impossible. Course uploaded to your shuttle; keep the fryer sludge for his cleaning machine.", true)
				return
		"plexi_control":
			if item == "maintenance pass":
				_gain(game, "plexi_authorized", 5)
				_line(game, "MAINTENANCE PASS ACCEPTED. If the gallery mirrors are aligned, activate the beam console. The vault door will open. Please do not leave fingerprints on history.", true)
				return
		"starcon_hall":
			if item == "" and not _done(game, "academy_enrolled"):
				_gain(game, "academy_enrolled", 5)
				game.add_item("academy badge")
				_line(game, "Roger Wilco? Your cleaning record qualifies as combat experience. Here's your student badge. Use it at the Advanced Mop Dynamics examination station in the classroom.", true)
				return
		"starcon_lab":
			if item == "mop certificate" and _done(game, "simulator_clearance"):
				_gain(game, "lab_authorized", 5)
				_line(game, "Certificate and simulation clearance verified. The legendary vacuum is yours to borrow. Our vendor on Polysorbate LX buys training research; show them your certificate. Please don't vacuum that planet.", true)
				return
		"polysorbate_market":
			if item == "mop certificate":
				if not _done(game, "trade_chit_given"):
					_gain(game, "trade_chit_given", 5)
					game.add_item("trade chit")
				_line(game, "A genuine Mop Dynamics research certificate! I'll pay for a scan, so keep the original. This trade chit opens my salvage locker in the alley. Its broom comes with protective sunglasses; trust me, keep those.", true)
				return
		"polysorbate_alley":
			if item == "":
				_line(game, "The broom I'm holding? Ordinary model. It sweeps ordinary rubbish and occasionally my lunch. The legendary Broom is in that sealed red artifact case on the left. Use Vreek's trade chit on the salvage locker to unlock it, then collect the case's contents.", true)
				return
		"glitzon_boulevard":
			if item == "" and _done(game, "glitzon_shielded"):
				_gain(game, "glitzon_vault_open", 5)
				_line(game, "Retinal protection confirmed. The vault is open. You've achieved our minimum standards for both safety and celebrity anonymity.", true)
				return
		"clone_chamber":
			if item == "":
				game.show_dialog("clone", ["Original me! How efficient: you've brought the five artifacts I hadn't stolen yet. Place them in my apparatus and watch me remove every imperfection from the universe.", "All that glorious suction! My lubrication intake is labelled CONTAMINANTS STRICTLY FORBIDDEN. Naturally, no competent janitor would put anything disgusting in there."])
				return
	if item != "":
		_blocked(game, "I appreciate the offer, but " + str(ITEM_NAMES.get(item, item)) + " isn't what this procedure requires. You keep it.", true)
	else:
		_line(game, _local_hint(game, room), true)

static func _pickup(game, room: String) -> void:
	match room:
		"labion_dock":
			_take(game, room, "empty flask", 0, "You take the survey flask from the landing supplies. It's sealed for hazardous samples. At last, equipment designed for your lunches.")
		"labion_jungle":
			_take(game, room, "vine rope", 5, "You collect a braided vine rope. The botanist says it's strong enough to anchor a crossing over the bog. Its employment prospects immediately exceed yours.")
		"labion_bog":
			if _done(game, "bog_crossed"):
				_line(game, "You already collected the medicinal herb while crossing. Take it to the sick guard at the ruin checkpoint.")
			else:
				_blocked(game, "The medicinal herb is on the far bank. Use the vine rope on the crossing first.")
		"labion_shrine":
			if not _done(game, "shrine_unsealed"):
				_blocked(game, "The Bucket is sealed to its stand. Present your maintenance pass at the oath pedestal.")
			else:
				_take(game, room, "bucket of eternal suds", 10, "You recover the Bucket of Eternal Suds. Its handle hums with ancient sanitation. Monolith Burger recognizes legendary janitorial tools as kitchen credentials; fly there next.")
				_mark(game, "bucket_recovered")
		"plexi_plaza":
			_take(game, room, "mirror wrench", 5, "You take the mirror wrench. Its diagram shows how to align the gallery's reflective array with the vault beam relay.")
		"plexi_vault":
			if not _done(game, "plexi_vault_open"):
				_blocked(game, "The security beam still seals the Squeegee. Return to the control room and disable it properly.")
			else:
				_take(game, room, "squeegee of power", 10, "The Squeegee of Power is yours. Its archive records a transfer request from StarCon Academy. The new course has been uploaded to your shuttle.")
				_mark(game, "starcon_unlocked")
		"starcon_lab":
			if not _done(game, "lab_authorized"):
				_blocked(game, "Dr. Venturi controls the containment lock. Pass the simulator, then show the doctor your Mop Dynamics certificate.")
			else:
				_take(game, room, "vacuum of infinite suction", 10, "You recover the Vacuum of Infinite Suction. It tries to ingest your pocket lint, then politely waits. Polysorbate LX is now available in navigation.")
				_mark(game, "polysorbate_unlocked")
		"polysorbate_alley":
			if not _done(game, "salvage_locker_open"):
				_blocked(game, "The broom is locked up. Show the market vendor your certificate, then use their trade chit on this locker.")
			else:
				if not _done(game, "taken:" + room):
					game.add_item("sunglasses", false)
				_take(game, room, "broom of cosmic sweep", 10, "You recover the Broom of Cosmic Sweep and its complimentary protective sunglasses. The delivery label points to Glitzon. That world is bright enough to qualify as an eye injury.")
				_mark(game, "glitzon_unlocked")
		"glitzon_vault":
			if not _done(game, "glitzon_vault_open"):
				_blocked(game, "The display remains sealed. Use sunglasses at the boulevard scanner, then speak to the concierge.")
			else:
				_take(game, room, "polish of eternal shine", 10, "You recover the Polish of Eternal Shine. It reflects the clone's command ship coordinates. Five artifacts recovered; his stolen Mop makes six. Keep Monolith's fryer sludge for the final confrontation.")
				_mark(game, "finale_unlocked")
		"clone_chamber":
			if not _done(game, "clone_sabotaged"):
				_blocked(game, "R0-GER still has the Mop clamped to his apparatus. His forbidden contaminant intake offers a promising weakness.")
			else:
				_take(game, room, "mop of destiny", 5, "You recover the Mop of Destiny while R0-GER fights an avalanche of rancid foam. All six artifacts are accounted for. Shut down the apparatus before its emergency sterilization cycle starts.")
		_:
			_line(game, _local_hint(game, room))

static func _object(game, room: String, item: String) -> void:
	match room:
		"labion_dock", "plexi_dock", "starcon_dock", "polysorbate_dock", "glitzon_dock":
			if item == "":
				game.open_travel_menu()
			else:
				_blocked(game, "Navigation already has your route data. Keep the " + str(ITEM_NAMES.get(item, item)) + " and put it away before choosing a flight.")
			return
		"labion_bog":
			if _done(game, "bog_crossed"):
				_line(game, "The vine crossing is secure. The medicinal herb you collected will help the gate guard.")
				return
			if item == "vine rope":
				game.remove_item(item)
				_gain(game, "bog_crossed", 5)
				game.add_item("bog herb")
				_line(game, "You anchor the rope, cross the quicksand, and collect the bog herb. The crossing remains tied in place. Your careful approach disappoints several hungry bubbles.")
				return
			if item == "":
				game.show_death("You stride confidently into the quicksand. It accepts your confidence as a garnish. Tie a vine rope to the crossing before trying again.")
				return
		"labion_shrine":
			if item == "maintenance pass":
				_gain(game, "shrine_unsealed", 10)
				_line(game, "The pedestal accepts your maintenance pass. AUTHORIZED CUSTODIAN, it declares, releasing the Bucket. An ancient society finally recognizes your professional qualifications.")
				return
		"monolith_berth":
			if item == "":
				_gain(game, "drain_ready", 5)
				_line(game, "You open the external grease return valve. The kitchen trap is safe to sample now. Take the sealed survey flask from Labion's landing supplies and fill it at the kitchen grease trap.")
				return
		"monolith_kitchen":
			if item == "empty flask":
				if not _done(game, "drain_ready"):
					_blocked(game, "The grease trap is pressurized. Open the external drain valve in the shuttle berth first.")
				else:
					game.remove_item(item)
					game.add_item("fryer sludge")
					_gain(game, "sludge_bottled", 10)
					_line(game, "You bottle the fryer sludge. It looks like everything a universal cleaning machine would hate. Keep it for the clone; talk to Chef Sizzl about the employee records.")
				return
		"monolith_freezer":
			if item == "service token":
				game.remove_item(item)
				game.add_item("frozen memo")
				_gain(game, "freezer_memo_recovered", 5)
				_line(game, "The icebox accepts your staff token and warms a memo. 'Counterfeit janitor: destination code concealed in Astro Chicken cabinet.' You retain the memo, despite its aggressive smell of onions.")
				return
		"monolith_arcade":
			if item == "frozen memo":
				game.add_item("arcade code")
				_gain(game, "arcade_decoded", 5)
				_line(game, "You follow the memo's instructions: flap, flap, pause, indignity. Astro Chicken displays a route code. Talk to Cluck-9 to upload Plexi-Prime coordinates to the shuttle.")
				return
		"plexi_gallery":
			if item == "mirror wrench":
				_gain(game, "mirror_aligned", 5)
				_line(game, "You align the mirrors with the beam relay. The control-room console can now divert vault security safely. Its Robo-Janitor still needs to see your maintenance pass.")
				return
		"plexi_control":
			if item == "" and _done(game, "mirror_aligned") and _done(game, "plexi_authorized"):
				_gain(game, "plexi_vault_open", 10)
				_line(game, "The relay redirects the security beam into a harmless municipal advertising display. The Squeegee vault is open. The ad is, regrettably, louder.")
				return
		"starcon_class":
			if item == "academy badge":
				game.add_item("mop certificate")
				_gain(game, "mop_exam_passed", 5)
				_line(game, "Your badge logs you into Advanced Mop Dynamics. Years of actual cleaning defeat an exam designed by people who have never touched a mop. Certificate awarded. Use it on the suction simulator next.")
				return
		"starcon_simulator":
			if item == "mop certificate":
				_gain(game, "simulator_clearance", 10)
				_line(game, "You apply the certificate's shutdown sequence, run the suction trial, and pass. The lab is open. Show your certificate to Dr. Venturi to release the legendary vacuum.")
				return
			if item == "" and not _done(game, "simulator_clearance"):
				game.show_death("You activate untrained suction mode. The simulator removes your hat, your dignity, and then the rest of you. Earn a Mop Dynamics certificate before operating it.")
				return
		"polysorbate_alley":
			if item == "trade chit":
				game.remove_item(item)
				_gain(game, "salvage_locker_open", 5)
				_line(game, "The salvage locker accepts the trade chit and opens. The cosmic broom is ready to collect. Complimentary sunglasses are attached with an unusually urgent warning label.")
				return
		"glitzon_boulevard":
			if item == "sunglasses":
				_gain(game, "glitzon_shielded", 5)
				_line(game, "You put on the sunglasses and withstand the retinal scanner. The concierge can now authorize the vault. The glasses also conceal the fact that you have no idea what celebrity you are pretending to be.")
				return
		"clone_chamber":
			_finale(game, item)
			return
	if item != "":
		_blocked(game, "The " + str(ITEM_NAMES.get(item, item)) + " doesn't solve this. You keep it. " + _local_hint(game, room))
	else:
		_line(game, _local_hint(game, room))

static func _finale(game, item: String) -> void:
	if item == "" and not _done(game, "clone_armed"):
		for artifact in ARTIFACTS:
			if not game.has_item(artifact):
				_blocked(game, "Five recovered artifacts belong in the intake: Bucket, Squeegee, Vacuum, Broom, and Polish. You're missing " + str(ITEM_NAMES[artifact]) + ". The clone's stolen Mop occupies socket six.")
				return
		for artifact in ARTIFACTS:
			game.remove_item(artifact)
		_gain(game, "clone_armed", 5)
		game.show_dialog("clone", ["All six! The universe will be spotless! Your little contribution will be remembered, original me. Briefly.", "The lubrication intake opens. It explicitly forbids fryer sludge. For a villain, I have been remarkably helpful with the labelling."])
	elif item == "fryer sludge":
		if not _done(game, "clone_armed"):
			_blocked(game, "The contaminant intake only opens when all six sockets are occupied. Insert your five recovered artifacts first.")
		else:
			game.remove_item(item)
			_gain(game, "clone_sabotaged", 5)
			_line(game, "Monolith's fryer sludge overwhelms the perfect cleaning apparatus. Rancid foam erupts, the Mop clamp releases, and R0-GER discovers a stain no amount of ambition can remove. Recover the stolen Mop now.")
	elif item == "" and _done(game, "clone_sabotaged") and game.has_item("mop of destiny"):
		for artifact in ARTIFACTS:
			game.add_item(artifact, false)
		_gain(game, "finale_complete", 5)
		game.finish_campaign(["You shut down the apparatus and recover the five captured artifacts. All six legendary tools are safe. The universe retains its stains, its inhabitants, and its regrettable burger franchises.", "R0-GER is sentenced to an eternity of cleaning his own mess. Your reward is a promotion to Acting Temporary Assistant Senior Janitor, with no change in pay.", "Roger Wilco has saved the galaxy again. Somewhere, a dirty table awaits. THE END."])
	elif item == "":
		_line(game, "The apparatus is armed. " + ("Recover the released Mop, then shut down the machine." if _done(game, "clone_sabotaged") else "Its forbidden contaminant intake is open. Monolith's fryer sludge should ruin the clone's immaculate plan."))
	else:
		_blocked(game, "Keep your " + str(ITEM_NAMES.get(item, item)) + ". The apparatus needs all five recovered artifacts, then a contaminant its cleaning system can't handle.")

static func _extra(game, room: String) -> void:
	var jokes := {
		"labion_dock": "You test the emergency beacon. It plays cheerful hold music. Rescue has been outsourced.",
		"labion_jungle": "You test the winch warning light. It flashes TOO MUCH WORK, TOO LITTLE ROPE. At last, machinery that understands its operator.",
		"labion_gate": "You strike the gong. It rings once, then an inscription requests that future announcements be submitted in writing.",
		"labion_shrine": "The ancient soap bar bears a solemn prophecy: WASH BEHIND YOUR EARS. You return it reverently, grateful that archaeological hygiene is not your department.",
		"monolith_berth": "You test the luggage alarm. It accuses three nearby crates of being your suitcase. Their confidence is admirable.",
		"monolith_kitchen": "You lift the tasting ladle. Its contents briefly attempt to lift you back. You return it to the bench; quality control is best left to people with extra stomachs.",
		"monolith_freezer": "You adjust the thermostat by one degree. Frosty begins a moving speech about the return of spring. You put it back.",
		"monolith_arcade": "The prize dispenser gives you an imaginary plush chicken. 'Digital fulfillment,' says the receipt. Even the consolation prize has been modernized.",
		"plexi_dock": "The polishing drone cleans your boots, scans your credit rating, and apologizes to the boots.",
		"plexi_plaza": "The fountain displays a hologram of water. Its plaque thanks the committee that eliminated expensive wetness.",
		"plexi_gallery": "The laser demonstration projects a smile onto the ceiling. It is the closest the gallery has come to relaxing.",
		"plexi_control": "The floor buffer briefly tries to organize a union. Its supervisor switches it to circular grievances.",
		"plexi_vault": "You admire the laser grille from a safe distance. A sign congratulates you on basic mammalian judgment.",
		"starcon_dock": "A luggage rack labels your imaginary suitcase UNPROMISING OFFICER MATERIAL. Even furniture has entrance standards.",
		"starcon_hall": "The coffee robot dispenses a lecture on leadership. The coffee costs extra.",
		"starcon_class": "You salute the practice mop. It stands at attention more convincingly than the cadets.",
		"starcon_lab": "The dust chamber demonstrates a perfectly choreographed dust storm. Research describes this as a repeatable cleaning problem.",
		"polysorbate_dock": "The air freshener produces a smell named 'Less Polysorbate.' It has an ambitious business model.",
		"polysorbate_market": "A souvenir claims to be genuine Sarien wreckage. Its price tag still reads 'Kitchen utensils.' You respect the historical journey.",
		"polysorbate_alley": "You read the gold token's small print: NOT LEGAL TENDER, NOT A MEDAL, NO REFUNDS. A whole economic system condensed into one disappointment.",
		"glitzon_dock": "The luggage sculpture applauds itself. It may already be the planet's most grounded celebrity.",
		"glitzon_boulevard": "The autograph machine signs Roger Wilco, spelling both words incorrectly. You are finally famous enough to be misrepresented."
	}
	if room in ["labion_bog", "starcon_simulator", "glitzon_vault", "clone_chamber"]:
		var deaths := {
			"labion_bog": "You poke the bubbling sinkhole. The bog decides you are its bubble. Retry, and leave the ominous holes to qualified holesologists.",
			"starcon_simulator": "The unshielded suction lever demonstrates exactly why it was shielded in the instructor's diagram. Your certificate cannot substitute for common sense.",
			"glitzon_vault": "You activate the unfiltered shine projector. Every molecule in your body is briefly voted Best Dressed, then evaporates.",
			"clone_chamber": "You press UNIVERSAL STERILIZATION. The button does exactly what its surprisingly honest label promised. Try the contaminant intake instead."
		}
		game.show_death(deaths[room])
	else:
		_line(game, str(jokes.get(room, "You perform a small, unnecessary adjustment. Somewhere, a maintenance log expands.")))

static func _local_hint(game, room: String) -> String:
	match room:
		"labion_dock": return "Take the sealed survey flask from the landing supplies. The jungle path leads to a vine rope, then a bog crossing. Your shuttle remains available at this dock."
		"labion_jungle": return "Collect the vine rope. Use it on the bog's quicksand crossing; the medicinal herb on the far bank will help the temple guard."
		"labion_bog": return "Anchor the vine rope at the quicksand crossing. It lets you collect medicinal bog herb and opens the far path. Walking straight into quicksand is still quicksand."
		"labion_gate": return "Use medicinal bog herb on the sniffling guard. He will open the shrine. Its oath pedestal recognizes an authorized maintenance pass."
		"labion_shrine": return "Use your maintenance pass on the custodian oath pedestal, then collect the Bucket. Fly to Monolith Burger; the Bucket grants access to its kitchen areas."
		"monolith_berth": return "Turn the external grease valve here, then return through the left door and use the restaurant's staff hatch for kitchen access. Fill Labion's sealed flask at the grease trap. The right airlock boards your shuttle."
		"monolith_kitchen": return "Open the berth's drain valve, then use the survey flask on this grease trap. Keep the bottled sludge for R0-GER. Talk to Chef Sizzl after collecting it to obtain a staff records token."
		"monolith_freezer": return "Use Chef Sizzl's staff token on the records icebox. The thawed memo tells you how to decode the Astro Chicken cabinet in the arcade."
		"monolith_arcade": return "Use the thawed employee memo on Astro Chicken, then talk to Cluck-9. Once you've recovered the Bucket and bottled fryer sludge, the attendant uploads Plexi-Prime's route."
		"plexi_dock": return "The mirror plaza leads to the gallery, control room, and Squeegee vault. Take the plaza's mirror wrench. Your shuttle can return to earlier worlds."
		"plexi_plaza": return "Collect the mirror wrench, then use it on the gallery mirror array. The control-room Robo-Janitor wants to see your maintenance pass."
		"plexi_gallery": return "Use the mirror wrench on the reflective array. Then show your maintenance pass to the control-room Robo-Janitor and operate the beam console."
		"plexi_control": return "The beam console needs aligned gallery mirrors and authorization from this Robo-Janitor. Show your maintenance pass, then operate the console with no pocket item selected."
		"plexi_vault": return "The Squeegee can be collected once the control console has diverted security. Its archive unlocks the StarCon Academy route."
		"starcon_dock": return "Speak to the registrar in the enrollment hall. Your professional humiliation may finally qualify you for something."
		"starcon_hall": return "Talk to the registrar for a student badge. The left doorway leads to classrooms: use your badge on the examination station. The right doorway leads to simulators. The lower-left exit returns to the academy dock."
		"starcon_class": return "Use your academy badge on the examination station to earn a Mop Dynamics certificate. Then use the certificate on the suction simulator."
		"starcon_simulator": return "Use your Mop Dynamics certificate on the simulator before operating suction equipment. Passing opens the research lab; show the certificate to Dr. Venturi there."
		"starcon_lab": return "Show Dr. Venturi your Mop Dynamics certificate after passing the simulator. Then collect the legendary vacuum. A Polysorbate vendor trades for a scan of your certificate."
		"polysorbate_dock": return "The market vendor buys StarCon research. Show them your Mop Dynamics certificate; their trade chit opens an alley salvage locker."
		"polysorbate_market": return "Show Vreek your Mop Dynamics certificate. You keep the original and receive a trade chit. Use that chit on the salvage locker in the alley."
		"polysorbate_alley": return "Use the vendor's trade chit on the salvage locker, then collect the sealed red artifact case on the left. The broom Filch holds is ordinary; the case contains the cosmic Broom and sunglasses you'll need on Glitzon."
		"glitzon_dock": return "Take the boulevard path. Use your protective sunglasses at the dazzling vault scanner, then speak to the security concierge."
		"glitzon_boulevard": return "Use the sunglasses from Polysorbate's broom package at the scanner. Then talk to Flash to open the Polish vault."
		"glitzon_vault": return "Collect the Polish once Flash opens the vault. Its reflections reveal the clone's command ship coordinates. Bring all five artifacts and Monolith's bottled fryer sludge."
		"clone_chamber":
			if not _done(game, "clone_armed"): return "Use the apparatus with no pocket item selected to insert all five recovered artifacts. The stolen Mop already occupies the sixth socket."
			if not _done(game, "clone_sabotaged"): return "Use Monolith's fryer sludge on the apparatus's now-open contaminant intake."
			if not game.has_item("mop of destiny"): return "Collect the released Mop of Destiny, then operate the apparatus again to shut it down and recover the other five artifacts."
			return "Operate the sabotaged apparatus with no pocket item selected. Recover all six legendary tools and save the galaxy."
	return "The shuttle connects the regional docks. Earlier locations remain available for anything you missed."

static func hint(game) -> String:
	var room: String = game.state.get("room", "diner")
	if LINKS.has(room):
		return _local_hint(game, room)
	if not game.flag("chapter_one_complete"):
		return ""
	if not _done(game, "bucket_recovered"):
		return "Fly to Labion. Its jungle rope crosses the bog; medicinal herb persuades the gate guard. Present your maintenance pass at the shrine and collect the Bucket."
	if not _done(game, "plexi_unlocked"):
		return "Monolith's kitchen side of the story is separate from the optional burger shift. Turn the berth's drain valve, bottle grease with Labion's flask, obtain the chef's token, thaw a memo in the freezer, and decode Astro Chicken."
	if not _done(game, "starcon_unlocked"):
		return "Fly to Plexi-Prime. Take its mirror wrench, align the gallery mirrors, show the control Robo-Janitor your maintenance pass, and open the Squeegee vault."
	if not _done(game, "polysorbate_unlocked"):
		return "Fly to StarCon Academy. Enroll, earn your Mop Dynamics certificate, pass the simulator, and ask the laboratory doctor to release the legendary vacuum."
	if not _done(game, "glitzon_unlocked"):
		return "Fly to Polysorbate LX. Trade a scan of your certificate for a chit, open the alley locker, and collect the cosmic broom and sunglasses."
	if not _done(game, "finale_unlocked"):
		return "Fly to Glitzon. Use the sunglasses at its boulevard scanner, talk to Flash, and recover the Polish from the vault."
	return "Fly to R0-GER's command ship with five artifacts and Monolith's fryer sludge. His machine already holds the stolen Mop."
