class_name Encounters
extends RefCounted

## Begegnungen auf der Überfahrt: ein Ereignis mit drei Optionen, deren Kosten und Risiken man sieht.
##
## Option:
##   label      Name auf der Karte
##   lines      Text auf der Karte; {ch} wird durch die Erfolgsaussicht in Prozent ersetzt
##   cost       Kosten {"loot": n, "proviant": n}, die man haben muss und bezahlt
##   fight      Erfolgsaussicht aus der Kampfstärke der Besatzung: outcomes[0] = Sieg, outcomes[1] = Niederlage
##   outcomes   Ausgänge; ohne "fight" zählen die Gewichte "w" (die Wahrscheinlichkeiten bleiben verborgen)
## Wirkungen ("fx") eines Ausgangs:
##   loot, proviant, hull (Rumpf), kraft_all, stress_all, wound (n Männer verlieren Kraft), kill (n Männer sterben)

enum Id { HAENDLER, INSEL, UNGEHEUER, HAFEN, DORF, DRAUGR, RAEUBER, KRAKEN, WRACK, SPIELER }

const WEIGHTS := [35, 40, 25, 0, 30, 18, 14, 0, 16, 0]  # Hafen wird fest platziert, nicht gewürfelt; das Spielschiff kommt erst ab Etappe 2
const WOUND_KRAFT := 30.0

const BATTLE_OPTIONS := [
	{"label": "Rammen", "tactic": "ram"},
	{"label": "Pfeilhagel", "tactic": "arrows"},
	{"label": "Kanonen", "tactic": "cannon"},
	{"label": "Entern", "tactic": "board"},
	{"label": "Schildwall", "tactic": "shield"},
	{"label": "Flicken", "tactic": "repair"},
	{"label": "Fliehen", "tactic": "flee"},
]
const DATA := [
	{
		"name": "Handelsschiff", "letter": "H", "intro": "enc_trader",
		"desc": "Ein schwer beladenes Handelsschiff. Es hat Waren, die ihr brauchen könnt, und eine Besatzung, die sich wehren wird.",
		"options": [
			{
				"label": "Entern",
				"formation": "haendler", "pass_lore": "trader_pass",
				"lines": ["Deckkampf gegen die Wachen", "Sieg: Beute +45, Proviant +4", "Verluste möglich"],
				"fight": {"base": 0.35, "per": 0.5, "min": 0.1, "max": 0.9},
				"outcomes": [
					{"fx": {"loot": 45, "proviant": 4, "wound": 2, "stress_all": -5}, "lore": "trader_win"},
					{"fx": {"kill": 1, "hull": -10, "stress_all": 10}, "lore": "trader_lose"},
				],
			},
			{
				"label": "Handeln",
				"lines": ["Kosten: Beute 30", "Proviant +6", "ohne Risiko"],
				"cost": {"loot": 30},
				"outcomes": [{"fx": {"proviant": 6, "stress_all": -3}, "lore": "trader_trade"}],
			},
			{
				"label": "Vorbeiziehen",
				"lines": ["Nichts geschieht."],
				"outcomes": [{"fx": {}, "lore": "trader_pass"}],
			},
		],
	},
	{
		"name": "Insel", "letter": "I", "intro": "enc_island",
		"desc": "Eine bewaldete Insel, Rauch über den Bäumen. Hier gibt es vielleicht Vorräte, Beute oder Ärger. Man erfährt es erst an Land.",
		"options": [
			{
				"label": "Erkunden",
				"lines": ["Meist ergiebig,", "manchmal ein Hinterhalt", "Funde: Proviant, Beute, Holz"],
				"outcomes": [
					{"w": 35, "fx": {"proviant": 5, "stress_all": -8}, "lore": "island_a"},
					{"w": 25, "fx": {"loot": 35}, "lore": "island_b"},
					{"w": 15, "fx": {"hull": 20, "proviant": 1}, "lore": "island_c"},
					{"w": 25, "fx": {"kill": 1, "wound": 2, "stress_all": 12}, "lore": "island_d"},
				],
			},
			{
				"label": "Am Strand suchen",
				"lines": ["Proviant +3 wahrscheinlich", "kaum Risiko"],
				"outcomes": [
					{"w": 60, "fx": {"proviant": 3}, "lore": "island_careful_ok"},
					{"w": 30, "fx": {}, "lore": "island_careful_none"},
					{"w": 10, "fx": {"wound": 1, "stress_all": 4}, "lore": "island_careful_hit"},
				],
			},
			{
				"label": "Bucht: flicken",
				"lines": ["Proviant −1", "Rumpf +20", "Zimmerleute müde"],
				"cost": {"proviant": 1},
				"outcomes": [{"fx": {"hull": 20, "kraft_all": -6}, "lore": "island_repair"}],
			},
			{
				"label": "Vorbeifahren",
				"lines": ["Nichts geschieht."],
				"outcomes": [{"fx": {}, "lore": "island_pass"}],
			},
		],
	},
	{
		"name": "Seeungeheuer", "letter": "M", "intro": "enc_monster",
		"desc": "Ein riesiges Wesen taucht neben dem Schiff auf. Kämpfen bringt Beute, aber es kostet Blut. Man kann es auch bezahlen oder fliehen.",
		"options": [
			{
				"label": "Kämpfen",
				"lines": ["Aussicht {ch} %", "Sieg: Beute +60, Mut +10", "Verlust: ein Mann, Rumpf −25"],
				"fight": {"base": 0.25, "per": 0.45, "min": 0.1, "max": 0.8},
				"outcomes": [
					{"fx": {"loot": 60, "wound": 1, "stress_all": -10}, "lore": "monster_win"},
					{"fx": {"kill": 1, "hull": -25, "wound": 2, "stress_all": 15}, "lore": "monster_lose"},
				],
			},
			{
				"label": "Opfern",
				"lines": ["Kosten: Proviant 4", "Es lässt euch ziehen"],
				"cost": {"proviant": 4},
				"outcomes": [{"fx": {"stress_all": 4}, "lore": "monster_pay"}],
			},
			{
				"label": "Davonrudern",
				"lines": ["Alle Kraft −12", "35 %: Rumpf −15"],
				"outcomes": [
					{"w": 65, "fx": {"kraft_all": -12}, "lore": "monster_flee_ok"},
					{"w": 35, "fx": {"kraft_all": -12, "hull": -15}, "lore": "monster_flee_hit"},
				],
			},
		],
	},
	{
		# Hafen mit Taverne: man bleibt, bis man ablegt. Bezahlt wird mit Beute.
		"name": "Hafen", "letter": "T", "intro": "enc_harbor", "harbor": true,
		"desc": "Ein Hafen mit Taverne. Hier gibt es Met, Proviant, Holz und Männer, die Arbeit suchen. Alles hat seinen Preis, bezahlt wird mit Beute.",
		"options": [
			{
				"label": "Met",
				"lines": ["Beute −25", "Mut +20 alle", "Rauferei? 15 %"],
				"cost": {"loot": 25}, "once": true,
				"outcomes": [
					{"w": 85, "fx": {"stress_all": -20, "kraft_all": 5}, "lore": "harbor_mead"},
					{"w": 15, "fx": {"stress_all": -10, "wound": 1}, "lore": "harbor_brawl"},
				],
			},
			{
				"label": "Rasten",
				"lines": ["Proviant −2", "Kraft +30", "Mut +8"],
				"cost": {"proviant": 2}, "once": true,
				"outcomes": [{"fx": {"kraft_all": 30, "stress_all": -8}, "lore": "harbor_rest"}],
			},
			{
				"label": "Anheuern",
				"lines": ["Taverne:", "3 Anwärter", "Reserve {rf}/{rc}"],
				"crew": true,
			},
			{
				"label": "Proviant",
				"lines": ["Beute −15", "Proviant +8"],
				"cost": {"loot": 15},
				"outcomes": [{"fx": {"proviant": 8}, "lore": "harbor_buy"}],
			},
			{
				"label": "Werft",
				"lines": ["Schiff, Gerät,", "Schmiede,", "Ausrüstung"],
				"shop": true,
			},
			{
				"label": "Spelunke",
				"lines": ["Nornenwalzen", "Spielautomat", "Beute setzen"],
				"slot": "harbor",
			},
			{
				"label": "Ablegen",
				"lines": ["Weiter aufs", "Meer."],
				"leave": true,
				"outcomes": [{"fx": {}, "lore": "harbor_leave"}],
			},
		],
	},
	{
		"name": "Küstendorf", "letter": "D", "intro": "enc_village",
		"desc": "Ein Küstendorf: Vieh auf den Weiden, Fischerboote am Strand. Die Bauern sind keine Krieger, aber die Glocke am Strand läutet schneller, als man rudern kann.",
		"options": [
			{
				"label": "Überfallen",
				"formation": "dorf", "pass_lore": "village_pass",
				"lines": ["Deckkampf gegen das Dorf", "Sieg: Beute +55, Proviant +6", "Verluste möglich"],
				"fight": {"base": 0.45, "per": 0.4, "min": 0.15, "max": 0.9},
				"outcomes": [
					{"fx": {"loot": 55, "proviant": 6, "wound": 1, "stress_all": 5}, "lore": "village_win"},
					{"fx": {"kill": 1, "hull": -5, "stress_all": 10}, "lore": "village_lose"},
				],
			},
			{
				"label": "Heimlich plündern",
				"lines": ["Beute +25, Proviant +3", "meist unbemerkt", "Alarm möglich"],
				"outcomes": [
					{"w": 60, "fx": {"loot": 25, "proviant": 3}, "lore": "village_sneak_ok"},
					{"w": 25, "fx": {}, "lore": "village_sneak_none"},
					{"w": 15, "fx": {"wound": 1, "hull": -5, "stress_all": 4}, "lore": "village_sneak_alarm"},
				],
			},
			{
				"label": "Handwerker",
				"lines": ["Beute −25", "Rumpf +25", "ohne Risiko"],
				"cost": {"loot": 25},
				"outcomes": [{"fx": {"hull": 25, "stress_all": -3}, "lore": "village_repair"}],
			},
			{
				"label": "Vorbeifahren",
				"lines": ["Nichts geschieht."],
				"outcomes": [{"fx": {}, "lore": "village_pass"}],
			},
		],
	},
	{
		# Seeschlacht über mehrere Runden, siehe scripts/battle.gd. Die Karten zeigen die Taktiken.
		"name": "Draugr-Schiff", "letter": "G", "intro": "enc_draugr", "battle": true, "enemy": "draugr",
		"desc": "Ein Schiff ohne Wind, ohne Flagge, ohne Lebende. Es hält Kurs auf euch, als hätte es nie ein anderes Ziel gehabt.",
		"options": BATTLE_OPTIONS,
	},
	{
		"name": "Räuberschiff", "letter": "R", "intro": "enc_raider", "battle": true, "enemy": "raeuber",
		"desc": "Ein Schiff mit schwarzem Segel und vielen Gesichtern an der Reling. Es hat Kanonen, Hunger und eine Beuteliste, auf der ihr steht.",
		"options": BATTLE_OPTIONS,
	},
	{
		"name": "Kraken", "letter": "K", "intro": "enc_kraken", "battle": true, "enemy": "kraken",
		"desc": "Die See wölbt sich, und aus der Tiefe greift etwas mit mehr Armen, als ein Mann zählen möchte. Es hat das Schiff gesehen und beschlossen, es zu behalten.",
		"options": BATTLE_OPTIONS,
	},
	{
		"name": "Wrack", "letter": "W", "intro": "enc_wreck",
		"desc": "Ein halb gesunkenes Schiff, die Rippen ragen aus dem Wasser. Vielleicht liegt darin etwas Brauchbares, vielleicht ein Grund, warum es hier liegt.",
		"options": [
			{
				"label": "Durchsuchen",
				"lines": ["Oft ein Fund,", "manchmal eine Falle", "Gegenstand möglich"],
				"outcomes": [
					{"w": 35, "fx": {"item": 1, "stress_all": -4}, "lore": "wreck_item"},
					{"w": 25, "fx": {"loot": 45}, "lore": "wreck_loot"},
					{"w": 15, "fx": {"proviant": 5}, "lore": "wreck_food"},
					{"w": 25, "fx": {"wound": 1, "hull": -8, "stress_all": 8}, "lore": "wreck_trap"},
				],
			},
			{
				"label": "Holz bergen",
				"lines": ["Rumpf +12", "Proviant +1", "kaum Risiko"],
				"outcomes": [
					{"w": 75, "fx": {"hull": 12, "proviant": 1}, "lore": "wreck_wood"},
					{"w": 25, "fx": {}, "lore": "wreck_nothing"},
				],
			},
			{
				"label": "Vorbeifahren",
				"lines": ["Nichts geschieht."],
				"outcomes": [{"fx": {}, "lore": "wreck_pass"}],
			},
		],
	},
	{
		# Adlerssons Spielschiff: ein Automat mit hohem Einsatz, siehe Slots (Maschine "loki") und Voyage.loki_*()
		"name": "Adlerssons Spielschiff", "letter": "L", "intro": "enc_gambler",
		"desc": "Ein Schiff unter grünen Laternen, auf dem Deck glüht ein Automat. Ein Mann mit zu vielen Zähnen winkt: eine Runde? Gewinnen kann man hier viel, verlieren auch.",
		"options": [
			{
				"label": "Spielen",
				"lines": ["Adlerssons Walzen", "Einsatz: Beute,", "Rumpf oder Mann"],
				"slot": "loki",
			},
			{
				"label": "Pfandflasche",
				"lines": ["Legendär: ein sicheres", "Freispiel bei", "Adlersson"],
				"slot": "loki", "bottle": true,
			},
			{
				"label": "Vorbeisegeln",
				"lines": ["Nichts geschieht."],
				"outcomes": [{"fx": {}, "lore": "gambler_pass"}],
			},
		],
	}
]


static var forced := -1  # nur für Tests: --forceenc=N lässt jede Begegnung diesen Typ haben


## Zufällige Begegnung; auf späteren Etappen treffen sich Draugr und Ungeheuer häufiger.
static func random_type(stage: int = 1, theme: int = 0) -> int:
	if forced >= 0:
		return forced
	var weights: Array = WEIGHTS.duplicate()
	weights[Id.DRAUGR] = mini(int(weights[Id.DRAUGR]) + 4 * (stage - 1), 55)
	weights[Id.UNGEHEUER] = mini(int(weights[Id.UNGEHEUER]) + 2 * (stage - 1), 40)
	weights[Id.RAEUBER] = mini(int(weights[Id.RAEUBER]) + 3 * (stage - 1), 45)
	weights[Id.KRAKEN] = 0 if stage < 3 else mini(6 + 3 * (stage - 3), 30)
	weights[Id.SPIELER] = 0 if stage < 2 else 7
	if theme == 3:
		weights[Id.RAEUBER] = int(weights[Id.RAEUBER]) * 3
	elif theme == 4:
		weights[Id.DRAUGR] = int(weights[Id.DRAUGR]) * 3
		weights[Id.KRAKEN] = int(weights[Id.KRAKEN]) * 2 + (8 if stage >= 3 else 0)
	var total := 0
	for w in weights:
		total += int(w)
	var r := randi() % total
	for i in weights.size():
		r -= int(weights[i])
		if r < 0:
			return i
	return Id.INSEL


static func option(id: int, i: int) -> Dictionary:
	var opts: Array = DATA[id]["options"]
	return opts[i]


## Aussicht auf Erfolg (0..1) bei Kampf-Optionen.
static func chance(voy: Voyage, opt: Dictionary) -> float:
	var f: Dictionary = opt["fight"]
	return clampf(float(f["base"]) + float(f["per"]) * voy.strength(), float(f["min"]), float(f["max"]))


static func is_harbor(id: int) -> bool:
	return id >= 0 and bool(DATA[id].get("harbor", false))


static func is_battle(id: int) -> bool:
	return id >= 0 and bool(DATA[id].get("battle", false))


static func used(voy: Voyage, opt: Dictionary) -> bool:
	return bool(opt.get("once", false)) and voy.harbor_used.has(opt["label"])


static func available(voy: Voyage, opt: Dictionary) -> bool:
	if used(voy, opt):
		return false
	if opt.has("tactic") and not Battle.can_use(voy, String(opt["tactic"])):
		return false
	if String(opt.get("need", "")) == "recruit" and not voy.can_recruit():
		return false
	if opt.has("slot") and not voy.slot_available(String(opt["slot"])):
		return false
	if bool(opt.get("bottle", false)) and voy.pfand <= 0:
		return false
	var cost: Dictionary = opt.get("cost", {})
	if float(cost.get("loot", 0)) > voy.loot:
		return false
	if int(cost.get("proviant", 0)) > voy.proviant:
		return false
	return true


## Was man bei einem Fund an Beute in der Hand hält (zufällig gewählt oder die erste Art für Erklärtexte).
const BOOTY := {
	"trader_win": ["Silberbarren, Pelzballen und ein Fass Wein", "Gewürze, Seide und ein Beutel Silber", "Bernstein, Salzfisch und ein Säckchen Münzen"],
	"island_b": ["ein vergrabener Beutel Silber", "Bernstein vom Strand und ein Wikingerhelm", "ein Händlerschatz unter einer Kiefer"],
	"monster_win": ["Perlen aus dem Bauch des Untiers", "Zähne, Elfenbein und verschluckte Münzen", "ein Hort aus Gold und Schiffsnägeln"],
	"village_win": ["Münzen, Vieh und Fässer voll Met", "das Gemeindesilber und ein Kessel", "Wolle, Münzen und das beste Schwert des Dorfes"],
	"village_sneak_ok": ["ein Beutel Münzen vom Dorfschmied", "Silberschmuck aus einem Langhaus", "Münzen aus der Kirchenkasse"],
	"wreck_loot": ["Münzen in einer wassergefüllten Truhe", "Silber im Kielraum", "ein Beutel Gold am Skelett des Kapitäns"],
	"battle_draugr": ["rostiges Silber und Truhen, die niemand mehr vermisst", "Gold der Toten und ihr Fluch"],
	"battle_raeuber": ["Münzen, Schmuck und die Beuteliste der Räuber", "gestohlene Fässer, Silber und ein Kanonenfass"],
	"battle_kraken": ["Perlen und Gold aus dem Magen des Untiers", "versunkene Münzen und ein Tentakelstumpf zum Angeben"],
	"reef": ["über Bord gegangene Truhen"],
	"camp": ["ein Beutel im Seetang", "Münzen in einem angespülten Fass", "Silber im Treibholz"],
}
## Kurz, was einen bei einer Begegnung erwartet (für die Tooltips der Seekarte).
const HINTS := [
	"Entern bringt Beute und Proviant; Handeln kostet Beute; man kann vorbeiziehen.",
	"Erkunden ist meist ergiebig (Proviant, Beute, Holz), manchmal ein Hinterhalt. In der Bucht flickt man den Rumpf.",
	"Kämpfen bringt Beute, kostet aber Blut. Man kann es mit Proviant bezahlen oder fliehen.",
	"Ein Hafen: Met, Rast, Anheuern, Proviant und die Werft. Hier endet das Anhalten nur, wenn man ablegt.",
	"Überfallen bringt Beute und Proviant, heimlich Plündern ist leiser. Handwerker flicken den Rumpf gegen Beute.",
	"Seeschlacht gegen ein Geisterschiff: viel Beute, Todesgefahr, Totenklage.",
	"Seeschlacht gegen Räuber mit Kanonen: viel Beute, Rumpfschaden.",
	"Seeschlacht gegen den Kraken: sehr viel Beute, Männer können über Bord gerissen werden.",
	"Durchsuchen findet oft etwas (auch einen Gegenstand), manchmal eine Falle. Holz bergen flickt den Rumpf.",
	"Ein Spielautomat mit hohem Einsatz: Beute, Rumpf oder sogar ein Mann. Wenig Gewinne, aber richtig dicke, und Adlerssons Streich bei den Masken.",
]


## Beuteart zu einem Ausgang (Schlüssel "lore" des Ausgangs oder "battle_<Gegner>"). zufällig: für Meldungen im Spiel.
static func booty_for(key: String, random: bool = false) -> String:
	if not BOOTY.has(key):
		return ""
	var list: Array = BOOTY[key]
	return String(list[randi() % list.size()] if random else list[0])


static func hint(id: int) -> String:
	return String(HINTS[id])


## Wirkung mit den echten Zahlen: Beute mit Gegenstands- und Etappenzuschlag, Rumpfschaden mit Schutz der Gegenstände.
static func scaled_fx(voy: Voyage, fx: Dictionary) -> Dictionary:
	var out := fx.duplicate()
	if float(out.get("loot", 0)) > 0.0:
		out["loot"] = roundi(float(out["loot"]) * voy.stat("loot") * (1.0 + 0.12 * float(voy.stage - 1)))
	if float(out.get("hull", 0)) < 0.0:
		out["hull"] = -roundi(-float(out["hull"]) * voy.stat("hazard"))
	return out


static var _loot_re: RegEx = null


static func card_lines(voy: Voyage, opt: Dictionary) -> Array:
	var out: Array = []
	var ch := 0
	if opt.has("fight"):
		ch = roundi(chance(voy, opt) * 100.0)
	var rn := String(voy.recruit.get("name", "–"))
	var rk := str(int(voy.recruit.get("kraft", 0)))
	var rt := ""
	var tl: Array = voy.recruit.get("traits", [])
	if not tl.is_empty():
		rt = String(Traits.DATA[int(tl[0])]["name"]) + (" …" if tl.size() > 1 else "")
	for line in opt["lines"]:
		var text := String(line).replace("{ch}", str(ch)).replace("{rn}", rn).replace("{rk}", rk).replace("{rt}", rt).replace("{rf}", str(voy.reserve.size())).replace("{rc}", str(voy.reserve_cap()))
		out.append(_scale_loot_text(voy, text))
	return out


## "Beute +45" auf der Karte zeigt, was man wirklich bekommt (mit Zuschlägen); "Beute −25" (Kosten) bleibt.
static func _scale_loot_text(voy: Voyage, text: String) -> String:
	if _loot_re == null:
		_loot_re = RegEx.new()
		_loot_re.compile("Beute \\+(\\d+)")
	var out := text
	for m in _loot_re.search_all(text):
		var base := float(m.get_string(1))
		var real := roundi(base * voy.stat("loot") * (1.0 + 0.12 * float(voy.stage - 1)))
		out = out.replace(m.get_string(0), "Beute +%d" % real)
	return out


static func pick(voy: Voyage, opt: Dictionary) -> Dictionary:
	var outs: Array = opt["outcomes"]
	if opt.has("fight"):
		return outs[0] if randf() < chance(voy, opt) else outs[1]
	var total := 0.0
	for o in outs:
		total += float(o.get("w", 1.0))
	var r := randf() * total
	for o in outs:
		r -= float(o.get("w", 1.0))
		if r < 0.0:
			return o
	return outs[outs.size() - 1]


static func fx_summary(fx: Dictionary) -> String:
	var parts: Array[String] = []
	if fx.has("loot"):
		parts.append("Beute %s" % Voyage.signed(int(fx["loot"])))
	if fx.has("proviant"):
		parts.append("Proviant %s" % Voyage.signed(int(fx["proviant"])))
	if fx.has("hull"):
		parts.append("Rumpf %s" % Voyage.signed(int(fx["hull"])))
	if fx.has("kraft_all"):
		parts.append("Kraft %s für alle" % Voyage.signed(int(fx["kraft_all"])))
	if fx.has("stress_all"):
		parts.append("Verzweiflung %s für alle" % Voyage.signed(int(fx["stress_all"])))
	if fx.has("item"):
		parts.append("Gegenstand")
	if fx.has("wound"):
		parts.append("%d verletzt" % int(fx["wound"]))
	return ", ".join(PackedStringArray(parts))
