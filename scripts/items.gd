class_name Items
extends RefCounted

## Gegenstände für das Schiff. Sieben Plätze, jeder nimmt eine Art Gegenstand; Kanonen passen auf zwei Plätze.
## Die Wirkung steht in "mods" und wird von Voyage.ship_mods() mit den Segen (Perks) zusammengezählt.
## Zusätzliche Werte (add) werden addiert, Faktoren (mul) multipliziert.

enum Kind { BUG, RUMPF, SEGEL, RIEMEN, KANONE, LAGER }

const SLOT_NAMES := ["Bug", "Rumpf", "Segel", "Riemen", "Kanone I", "Kanone II", "Laderaum"]
const SLOT_KIND := [Kind.BUG, Kind.RUMPF, Kind.SEGEL, Kind.RIEMEN, Kind.KANONE, Kind.KANONE, Kind.LAGER]
const KIND_NAMES := ["Bug", "Rumpf", "Segel", "Riemen", "Kanone", "Laderaum"]

## Grundwerte des Schiffes ohne Gegenstände.
const BASE := {
	"hull_max": 100.0, "strain": 1.0, "hazard": 1.0, "exposure": 1.0, "sail": 1.0, "oars": 1.0, "repair": 1.0,
	"proviant_max": 32.0, "stress": 1.0, "loot": 1.0, "cannons": 0.0, "cannon_dmg": 1.0, "ram": 0.0, "ram_self": 1.0,
	"powder_max": 8.0, "armor": 0.0, "visible": 0.0, "reserve": 0.0,
}
const ADDITIVE := ["hull_max", "proviant_max", "cannons", "ram", "powder_max", "armor", "visible", "reserve"]

## Anzeigetext je Wert: [Name, Einheit, kleiner ist besser]
const LABELS := {
	"hull_max": ["Rumpf", "", false], "strain": ["Seegangsschaden", "%", true], "hazard": ["Gefahrenschaden", "%", true],
	"exposure": ["Verlust über Bord", "%", true], "sail": ["Segelvortrieb", "%", false], "oars": ["Ruderkraft", "%", false],
	"repair": ["Reparatur", "%", false], "proviant_max": ["Proviantlager", "", false], "stress": ["Verzweiflung", "%", true],
	"loot": ["Beute", "%", false], "cannons": ["Kanonen", "", false], "cannon_dmg": ["Kanonenschaden", "%", false],
	"ram": ["Rammschaden", "", false], "ram_self": ["eigener Rammschaden", "%", true], "powder_max": ["Pulverlager", "", false],
	"armor": ["Panzerung", "", false], "visible": ["Sichtweite", "", false], "reserve": ["Reserveplätze", "", false],
}

const DATA := {
	"sporn": {"name": "Eiserner Rammsporn", "kind": Kind.BUG, "price": 70, "mods": {"ram": 8.0, "ram_self": 0.6}, "desc": "Wer rammt, tut es mit Eisen."},
	"drachenkopf": {"name": "Drachenkopf", "kind": Kind.BUG, "price": 60, "mods": {"stress": 0.85, "loot": 1.05}, "desc": "Schaut so grimmig, dass die Mannschaft sich schämt zu verzagen."},
	"teer": {"name": "Teerung", "kind": Kind.RUMPF, "price": 45, "mods": {"strain": 0.88}, "desc": "Stinkt und hält."},
	"beschlag": {"name": "Eisenbeschläge", "kind": Kind.RUMPF, "price": 90, "mods": {"hull_max": 20.0, "armor": 1.0}, "desc": "Der Rumpf trägt jetzt Rüstung, die Mannschaft nicht."},
	"planken": {"name": "Doppelte Planken", "kind": Kind.RUMPF, "price": 150, "mods": {"hull_max": 40.0, "strain": 0.9, "sail": 0.95}, "desc": "Schwer, dick, kaum totzukriegen."},
	"tuch": {"name": "Gutes Segeltuch", "kind": Kind.SEGEL, "price": 60, "mods": {"sail": 1.15}, "desc": "Fängt Wind, den andere nicht mal bemerken."},
	"prunk": {"name": "Prunksegel", "kind": Kind.SEGEL, "price": 110, "mods": {"sail": 1.25, "exposure": 1.1}, "desc": "Man sieht uns von Weitem, vor allem das Segel."},
	"sturm": {"name": "Sturmsegel", "kind": Kind.SEGEL, "price": 80, "mods": {"hazard": 0.88, "sail": 1.05}, "desc": "Kleiner, zäher und beleidigt von Böen."},
	"riemen": {"name": "Lange Riemen", "kind": Kind.RIEMEN, "price": 55, "mods": {"oars": 1.15}, "desc": "Hebel, wie ihn sich nur ein Faulpelz ausdenkt."},
	"esche": {"name": "Eschenriemen", "kind": Kind.RIEMEN, "price": 100, "mods": {"oars": 1.25, "repair": 1.05}, "desc": "Biegsam, zäh, teuer."},
	"kanone": {"name": "Bronzekanone", "kind": Kind.KANONE, "price": 120, "mods": {"cannons": 1.0, "powder_max": 2.0}, "desc": "Laut, schwer und unbeliebt bei Fischen."},
	"schwere": {"name": "Schwere Kanone", "kind": Kind.KANONE, "price": 190, "mods": {"cannons": 1.0, "cannon_dmg": 1.4, "powder_max": 2.0}, "desc": "Wenn sie feuert, bewegt sich das Schiff nach hinten."},
	"fass": {"name": "Proviantfass", "kind": Kind.LAGER, "price": 40, "mods": {"proviant_max": 8.0}, "desc": "Mehr Platz für Pökelfisch."},
	"pulver": {"name": "Pulverkammer", "kind": Kind.LAGER, "price": 65, "mods": {"powder_max": 8.0}, "desc": "Trocken, kühl, nicht zum Rauchen."},
	"haengematte": {"name": "Hängematten", "kind": Kind.LAGER, "price": 55, "mods": {"reserve": 2.0}, "desc": "Zwei Mann mehr unter Deck, die sich ausruhen, bis man sie braucht. Sie essen aber mit."},
	"werkzeug": {"name": "Werkzeugkiste", "kind": Kind.LAGER, "price": 70, "mods": {"repair": 1.3}, "desc": "Die Zimmerleute lieben sie mehr als ihre Frauen."},
	"truhe": {"name": "Beutetruhe", "kind": Kind.LAGER, "price": 80, "mods": {"loot": 1.2}, "desc": "Alles, was glänzt, bleibt besser hängen."},
}


## Ein Gegenstand wird im Spiel durch einen Schlüssel beschrieben: "teer" (gewöhnlich) oder "teer@2" (Seltenheit 2).
## Alle Funktionen unten nehmen so einen Schlüssel; die Wirkung wächst mit der Seltenheit.
enum Rarity { GEWOEHNLICH, SELTEN, EPISCH, LEGENDAER }

const RARITY_NAMES := ["Gewöhnlich", "Selten", "Episch", "Legendär"]
const RARITY_COLORS := [Color("b8b2a2"), Color("5b9be8"), Color("b070e0"), Color("f2a53a")]
const RARITY_MULT := [1.0, 1.3, 1.65, 2.1]  # Faktor auf die guten Werte
const RARITY_PRICE := [1.0, 1.8, 3.2, 5.5]  # Faktor auf den Preis
const WHOLE := ["cannons", "reserve", "visible"]  # ganze Zahlen: Kanonen bleiben eine, Plätze und Sicht runden

## Episch und Legendär bringen einen Zusatzwert mit (Legendär stärker) und ein Legendärer einen eigenen Namen.
const EXTRA := {
	"sporn": {"legend": "Fenrirs Eisenzahn", "bonus": {"hull_max": 10.0}},
	"drachenkopf": {"legend": "Nidhöggs Antlitz", "bonus": {"exposure": 0.92}},
	"teer": {"legend": "Teer der Nornen", "bonus": {"hazard": 0.93}},
	"beschlag": {"legend": "Hel-Beschläge", "bonus": {"strain": 0.94}},
	"planken": {"legend": "Yggdrasil-Planken", "bonus": {"repair": 1.1}},
	"tuch": {"legend": "Segel der Walküren", "bonus": {"hazard": 0.95}},
	"prunk": {"legend": "Freyas Prunksegel", "bonus": {"loot": 1.06}},
	"sturm": {"legend": "Odins Sturmtuch", "bonus": {"strain": 0.94}},
	"riemen": {"legend": "Riemen des Njörd", "bonus": {"strain": 0.96}},
	"esche": {"legend": "Weltenbaum-Eschen", "bonus": {"hull_max": 8.0}},
	"kanone": {"legend": "Donnerrohr des Thor", "bonus": {"cannon_dmg": 1.15}},
	"schwere": {"legend": "Hammerlauf des Thor", "bonus": {"powder_max": 3.0}},
	"fass": {"legend": "Fass ohne Boden", "bonus": {"stress": 0.95}},
	"pulver": {"legend": "Surtrs Pulverkammer", "bonus": {"cannon_dmg": 1.1}},
	"haengematte": {"legend": "Wiegen der Ran", "bonus": {"stress": 0.94}},
	"werkzeug": {"legend": "Wielands Werkzeugkiste", "bonus": {"hull_max": 10.0}},
	"truhe": {"legend": "Fafnirs Hort", "bonus": {"stress": 0.95}},
}


## Die Pfandflasche: ein legendärer Schlüsselgegenstand ohne Platz am Schiff (Voyage.pfand zählt sie).
## Wer sie bei Adlersson abgibt, bekommt ein sicheres Freispiel an seinem Automaten.
const PFAND_NAME := "Pfandflasche"
const PFAND_MAX := 3
const PFAND_DESC := "Leer, aber Pfand ist Pfand. Adlersson würde dafür seine Walzen verpfänden: ein sicheres Freispiel, bei dem nichts verloren gehen kann."


static func pfand_color() -> Color:
	return RARITY_COLORS[Rarity.LEGENDAER]


static func ids() -> Array:
	return DATA.keys()


static func base_id(key: String) -> String:
	return key.get_slice("@", 0)


static func rarity_of(key: String) -> int:
	return clampi(int(key.get_slice("@", 1)), 0, 3) if key.contains("@") else 0


static func make(id: String, rarity: int) -> String:
	return id if rarity <= 0 else "%s@%d" % [id, clampi(rarity, 0, 3)]


## Ist das ein gültiger Schlüssel?
static func valid(key: String) -> bool:
	return DATA.has(base_id(key)) and (not key.contains("@") or (key.get_slice("@", 1).is_valid_int() and int(key.get_slice("@", 1)) >= 1 and int(key.get_slice("@", 1)) <= 3))


static func kind_of(key: String) -> int:
	return int(DATA[base_id(key)]["kind"])


static func name_of(key: String) -> String:
	if rarity_of(key) == Rarity.LEGENDAER:
		return String(EXTRA[base_id(key)]["legend"])
	return String(DATA[base_id(key)]["name"])


static func desc_of(key: String) -> String:
	return String(DATA[base_id(key)]["desc"])


static func rarity_name(key: String) -> String:
	return String(RARITY_NAMES[rarity_of(key)])


static func rarity_color(key: String) -> Color:
	return RARITY_COLORS[rarity_of(key)]


## Passende Plätze für einen Gegenstand (nach Art).
static func slots_for(key: String) -> Array[int]:
	var out: Array[int] = []
	for i in SLOT_KIND.size():
		if int(SLOT_KIND[i]) == kind_of(key):
			out.append(i)
	return out


## Gut für das Schiff? Mehr Rumpf ist gut, mehr Seegangsschaden schlecht.
static func _is_good(key: String, v: float) -> bool:
	var info: Array = LABELS[key]
	if ADDITIVE.has(key):
		return v > 0.0
	return (v < 1.0) == bool(info[2])


static func _scaled(key: String, v: float, mult: float) -> float:
	if key == "cannons":
		return v
	if not _is_good(key, v):
		return v  # Nachteile wachsen nicht mit der Seltenheit
	if WHOLE.has(key):
		return float(roundi(v * mult))
	if ADDITIVE.has(key):
		return snappedf(v * mult, 0.1)
	return maxf(1.0 + (v - 1.0) * mult, 0.3)


static func _merge(into: Dictionary, key: String, v: float) -> void:
	if not into.has(key):
		into[key] = v
	elif ADDITIVE.has(key):
		into[key] = float(into[key]) + v
	else:
		into[key] = float(into[key]) * v


## Die Wirkung mit der Seltenheit eingerechnet.
static func mods_of(key: String) -> Dictionary:
	var id := base_id(key)
	var r := rarity_of(key)
	var out := {}
	for k in DATA[id]["mods"]:
		out[k] = _scaled(String(k), float(DATA[id]["mods"][k]), float(RARITY_MULT[r]))
	if r >= Rarity.EPISCH:
		var bonus: Dictionary = EXTRA[id]["bonus"]
		for k in bonus:
			_merge(out, String(k), _scaled(String(k), float(bonus[k]), 1.0 if r == Rarity.EPISCH else 1.6))
	return out


## Zeilen für die Anzeige: ["Rumpf +20", good] je Wert
static func mod_lines(mods: Dictionary) -> Array:
	var out: Array = []
	for key in mods:
		var info: Array = LABELS[key]
		var v := float(mods[key])
		var text := ""
		var good := true
		if ADDITIVE.has(key):
			text = "%s %s" % [info[0], Voyage.signed(roundi(v))]
			good = v > 0.0
		else:
			var pct := roundi((v - 1.0) * 100.0)
			text = "%s %s %%" % [info[0], Voyage.signed(pct)]
			good = (v < 1.0) == bool(info[2])
		out.append([text, good])
	return out


static func lines_of(key: String) -> Array:
	return mod_lines(mods_of(key))


static func price_at(key: String, stage: int) -> int:
	return roundi(float(DATA[base_id(key)]["price"]) * float(RARITY_PRICE[rarity_of(key)]) * (1.0 + 0.1 * float(stage - 1)))


## Würfelt eine Seltenheit. Je höher die Etappe, desto besser; luck (0 Laden, 1 Wrack, 1,5 Kraken) verschiebt zum Seltenen.
static func roll_rarity(stage: int, luck: float = 0.0, minimum: int = 0) -> int:
	var w: Array = [
		maxf(80.0 - 6.0 * float(stage - 1) - 10.0 * luck, 35.0),
		17.0 + 3.0 * float(stage - 1) + 6.0 * luck,
		0.0 if stage < 2 else 2.5 + 1.5 * float(stage - 2) + 3.0 * luck,
		0.0 if stage < 3 else 0.3 + 0.4 * float(stage - 3) + 1.0 * luck,
	]
	for i in minimum:
		w[i] = 0.0
	var total := 0.0
	for x in w:
		total += float(x)
	var r := randf() * total
	for i in 4:
		r -= float(w[i])
		if r < 0.0:
			return i
	return 3 if float(w[3]) > 0.0 else clampi(minimum, 0, 2)