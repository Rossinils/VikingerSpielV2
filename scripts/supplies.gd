class_name Supplies
extends RefCounted

## Vorräte: Verbrauchsgüter, die man im Hafen beim Krämer kauft und später einsetzt. Verband, Schnaps und Teerfass
## wirken auf See (in der Planung, Leiste links unten); die Harpune und manchmal die anderen öffnen bei Ereignissen
## unterwegs eine eigene Karte ("Kosten: Harpune 1"). Symbole: assets/supply_icons.png (tools/make_supply_icons.py).

const ORDER := ["verband", "schnaps", "teer", "harpune"]
const DATA := {
	"verband": {"name": "Verband", "price": 12, "max": 3, "sea": true,
		"short": "Kraft +30 für den Schwächsten",
		"desc": "Leinen, Salbe, ein fester Knoten. Der Mann mit der wenigsten Kraft an Bord bekommt Kraft +30. Bei Schiffbrüchigen rettet er Leben."},
	"schnaps": {"name": "Schnaps", "price": 10, "max": 3, "sea": true,
		"short": "Verzweiflung −8 für alle",
		"desc": "Ein Schluck für jeden an Bord, und die See sieht freundlicher aus. Verzweiflung −8 für alle an Bord."},
	"teer": {"name": "Teerfass", "price": 18, "max": 2, "sea": true,
		"short": "Rumpf +15",
		"desc": "Heißer Teer in die Fugen: Rumpf +15, auch mitten auf See. Bei Treibeis und dem Totenfloß hilft er auf eigene Weise."},
	"harpune": {"name": "Harpune", "price": 15, "max": 2, "sea": false,
		"short": "nur bei Ereignissen",
		"desc": "Ein schwerer Speer an einer Leine. Wirkt nicht von allein: bei einem Wal oder einem Ungeheuer öffnet sie eine eigene, bessere Karte."},
}


static func has_key(k: String) -> bool:
	return DATA.has(k)


static func name_of(k: String) -> String:
	return String((DATA.get(k, {}) as Dictionary).get("name", k))


static func cap(k: String) -> int:
	return int((DATA.get(k, {}) as Dictionary).get("max", 0))


## Preis beim Krämer (mit dem Preisfaktor der Schwierigkeit).
static func price(voy: Voyage, k: String) -> int:
	return roundi(float(DATA[k]["price"]) * voy.price_mul())


## Kostet eine Begegnungs-Option Vorräte? Dann hier die Namen ("harpune" …), sonst leer.
static func cost_keys(cost: Dictionary) -> Array:
	var out: Array = []
	for k in ORDER:
		if int(cost.get(k, 0)) > 0:
			out.append(k)
	return out
