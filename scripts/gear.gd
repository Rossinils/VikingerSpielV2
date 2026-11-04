class_name Gear
extends RefCounted

## Ausrüstung der Männer: Waffe, Rüstung und Amulett. Jeder Mann trägt höchstens je eins davon; was man findet oder kauft,
## liegt im Vorrat (Voyage.stash), bis es jemand anlegt. Fällt ein Mann, kehrt seine Ausrüstung in den Vorrat zurück.
## Wie bei den Schiffsgegenständen beschreibt ein Schlüssel das Stück samt Seltenheit: "schwert" oder "schwert@2".
##
## Werte (mods): dmg (Anteil mehr Schaden), crit (Punkte Krit-Chance), acc (Punkte Trefferchance), prot (Anteil mehr Schutz),
## dodge (Punkte Ausweichen), speed (Tempo), stress (Faktor auf Verzweiflung, kleiner ist besser), regen (Kraft je Runde).

enum Slot { WAFFE, RUESTUNG, AMULETT }

const SLOT_NAMES := ["Waffe", "Rüstung", "Amulett"]
const STASH_MAX := 6

const LABELS := {
	"dmg": "Schaden", "crit": "Krit", "acc": "Treffer", "prot": "Schutz", "dodge": "Ausweichen", "speed": "Tempo",
	"stress": "Verzweiflung", "regen": "Regeneration",
}
const PERCENT := ["dmg", "prot"]  # Anteile, werden in Prozent angezeigt

const DATA := {
	"schwert": {"name": "Eisenschwert", "slot": Slot.WAFFE, "price": 60, "mods": {"dmg": 0.08, "acc": 3.0}, "desc": "Ehrliches Eisen.", "legend": "Tyrfing", "bonus": {"crit": 4.0}},
	"axt": {"name": "Bartaxt", "slot": Slot.WAFFE, "price": 70, "mods": {"dmg": 0.12, "speed": -1.0}, "desc": "Schwer, breit und nicht eilig.", "legend": "Tyrs Bartaxt", "bonus": {"acc": 4.0}},
	"speer": {"name": "Langspeer", "slot": Slot.WAFFE, "price": 60, "mods": {"dmg": 0.06, "crit": 5.0}, "desc": "Wer zuerst zusticht, erzählt später.", "legend": "Gungnir", "bonus": {"acc": 5.0}},
	"dolch": {"name": "Kurzer Dolch", "slot": Slot.WAFFE, "price": 45, "mods": {"speed": 1.0, "crit": 4.0}, "desc": "Schnell, klein und gemein.", "legend": "Lokis Zahn", "bonus": {"dodge": 3.0}},
	"hammer": {"name": "Kriegshammer", "slot": Slot.WAFFE, "price": 80, "mods": {"dmg": 0.14, "acc": -3.0}, "desc": "Für Schädel und Türen.", "legend": "Mjölnir-Splitter", "bonus": {"prot": 0.03}},
	"runenstab": {"name": "Runenstab", "slot": Slot.WAFFE, "price": 65, "mods": {"dmg": 0.05, "stress": 0.92}, "desc": "Die Runen flüstern beruhigend.", "legend": "Mimirs Stab", "bonus": {"regen": 1.0}},
	"leder": {"name": "Lederwams", "slot": Slot.RUESTUNG, "price": 50, "mods": {"prot": 0.04, "dodge": 3.0}, "desc": "Leicht, geschmeidig, nach Fisch riechend.", "legend": "Haut des Fafnir", "bonus": {"stress": 0.95}},
	"kette": {"name": "Kettenhemd", "slot": Slot.RUESTUNG, "price": 85, "mods": {"prot": 0.08, "speed": -1.0}, "desc": "Klirrt beim Gehen und beim Fallen.", "legend": "Brynja der Walküre", "bonus": {"dodge": 3.0}},
	"fell": {"name": "Bärenfell", "slot": Slot.RUESTUNG, "price": 60, "mods": {"prot": 0.05, "stress": 0.93}, "desc": "Wer es trägt, fürchtet sich weniger.", "legend": "Fell des Fenriswolfs", "bonus": {"dmg": 0.04}},
	"schuppen": {"name": "Schuppenpanzer", "slot": Slot.RUESTUNG, "price": 90, "mods": {"prot": 0.10, "dodge": -3.0}, "desc": "Fischhaut, hart wie Eisen.", "legend": "Schuppen der Midgardschlange", "bonus": {"regen": 1.0}},
	"mantel": {"name": "Wolfsmantel", "slot": Slot.RUESTUNG, "price": 55, "mods": {"dodge": 6.0, "regen": 1.0}, "desc": "Warm und schwer zu fassen.", "legend": "Mantel der Nornen", "bonus": {"prot": 0.03}},
	"helm": {"name": "Hörnerhelm", "slot": Slot.RUESTUNG, "price": 65, "mods": {"prot": 0.06, "crit": 2.0}, "desc": "Sieht beeindruckend aus, hält mehr aus.", "legend": "Helm des Schreckens", "bonus": {"stress": 0.94}},
	"rune": {"name": "Schutzrune", "slot": Slot.AMULETT, "price": 55, "mods": {"stress": 0.88}, "desc": "Ein Stein mit einer Rune gegen die Angst.", "legend": "Rune der Hel", "bonus": {"prot": 0.03}},
	"zahn": {"name": "Wolfszahn", "slot": Slot.AMULETT, "price": 50, "mods": {"crit": 6.0, "speed": 1.0}, "desc": "Der Wolf war schneller.", "legend": "Zahn des Garm", "bonus": {"dmg": 0.04}},
	"hammeranhaenger": {"name": "Hammeranhänger", "slot": Slot.AMULETT, "price": 70, "mods": {"dmg": 0.06, "prot": 0.02}, "desc": "Thor sieht zu, wenn man ihn trägt.", "legend": "Thors Segen", "bonus": {"regen": 1.0}},
	"muenze": {"name": "Glücksmünze", "slot": Slot.AMULETT, "price": 55, "mods": {"dodge": 5.0, "acc": 4.0}, "desc": "Fällt sie auf Kopf, hat man Glück.", "legend": "Freyas Münze", "bonus": {"crit": 3.0}},
	"horn": {"name": "Trinkhorn", "slot": Slot.AMULETT, "price": 60, "mods": {"regen": 2.0, "stress": 0.95}, "desc": "Was darin ist, hilft.", "legend": "Horn des Heimdall", "bonus": {"prot": 0.03}},
	"auge": {"name": "Odinsauge", "slot": Slot.AMULETT, "price": 80, "mods": {"acc": 8.0, "crit": 3.0}, "desc": "Man sieht genauer, wohin man schlägt.", "legend": "Odins Auge", "bonus": {"dmg": 0.05}},
}


static func ids() -> Array:
	return DATA.keys()


static func base_id(key: String) -> String:
	return Items.base_id(key)


static func rarity_of(key: String) -> int:
	return Items.rarity_of(key)


static func make(id: String, rarity: int) -> String:
	return Items.make(id, rarity)


static func valid(key: String) -> bool:
	return DATA.has(base_id(key)) and (not key.contains("@") or (key.get_slice("@", 1).is_valid_int() and int(key.get_slice("@", 1)) >= 1 and int(key.get_slice("@", 1)) <= 3))


static func slot_of(key: String) -> int:
	return int(DATA[base_id(key)]["slot"])


static func name_of(key: String) -> String:
	if rarity_of(key) == Items.Rarity.LEGENDAER:
		return String(DATA[base_id(key)]["legend"])
	return String(DATA[base_id(key)]["name"])


static func desc_of(key: String) -> String:
	return String(DATA[base_id(key)]["desc"])


static func rarity_name(key: String) -> String:
	return Items.rarity_name(key)


static func rarity_color(key: String) -> Color:
	return Items.rarity_color(key)


static func _is_good(key: String, v: float) -> bool:
	return v < 1.0 if key == "stress" else v > 0.0


static func _scaled(key: String, v: float, mult: float) -> float:
	if not _is_good(key, v):
		return v  # Nachteile wachsen nicht mit der Seltenheit
	if key == "stress":
		return maxf(1.0 + (v - 1.0) * mult, 0.5)
	if PERCENT.has(key):
		return snappedf(v * mult, 0.005)
	return float(maxi(roundi(v * mult), 1))


static func _merge(into: Dictionary, key: String, v: float) -> void:
	if not into.has(key):
		into[key] = v
	elif key == "stress":
		into[key] = float(into[key]) * v
	else:
		into[key] = float(into[key]) + v


## Die Werte mit der Seltenheit eingerechnet; Episch und Legendär bringen einen Zusatzwert mit.
static func mods_of(key: String) -> Dictionary:
	var id := base_id(key)
	var r := rarity_of(key)
	var out := {}
	for k in DATA[id]["mods"]:
		out[k] = _scaled(String(k), float(DATA[id]["mods"][k]), float(Items.RARITY_MULT[r]))
	if r >= Items.Rarity.EPISCH:
		var bonus: Dictionary = DATA[id]["bonus"]
		for k in bonus:
			_merge(out, String(k), _scaled(String(k), float(bonus[k]), 1.0 if r == Items.Rarity.EPISCH else 1.6))
	return out


## Zeilen für die Anzeige: ["Schaden +8 %", good] je Wert
static func lines_of(key: String) -> Array:
	var out: Array = []
	var mods := mods_of(key)
	for k in mods:
		var v := float(mods[k])
		var text := ""
		if k == "stress":
			text = "Verzweiflung %s %%" % Voyage.signed(roundi((v - 1.0) * 100.0))
		elif PERCENT.has(k):
			text = "%s %s %%" % [LABELS[k], Voyage.signed(roundi(v * 100.0))]
		else:
			text = "%s %s" % [LABELS[k], Voyage.signed(roundi(v))]
		out.append([text, _is_good(String(k), v)])
	return out


static func price_at(key: String, stage: int) -> int:
	return roundi(float(DATA[base_id(key)]["price"]) * float(Items.RARITY_PRICE[rarity_of(key)]) * (1.0 + 0.1 * float(stage - 1)))


## Was ein Mann mit dieser Ausrüstung (Platz -> Schlüssel) insgesamt mitbringt: Werte addiert, "stress" multipliziert.
static func sum_mods(gear: Dictionary) -> Dictionary:
	var total := {"dmg": 0.0, "crit": 0.0, "acc": 0.0, "prot": 0.0, "dodge": 0.0, "speed": 0.0, "stress": 1.0, "regen": 0.0}
	for slot in gear:
		var key := String(gear[slot])
		if not valid(key):
			continue
		var m := mods_of(key)
		for k in m:
			if k == "stress":
				total[k] = float(total[k]) * float(m[k])
			else:
				total[k] = float(total[k]) + float(m[k])
	return total


## Würfelt ein Stück (Seltenheit wie bei den Schiffsgegenständen). slot -1 = beliebig.
static func roll(stage: int, luck: float = 0.0, minimum: int = 0, slot: int = -1) -> String:
	var pool: Array = []
	for id in DATA:
		if slot < 0 or int(DATA[id]["slot"]) == slot:
			pool.append(id)
	return make(String(pool[randi() % pool.size()]), Items.roll_rarity(stage, luck, minimum))
