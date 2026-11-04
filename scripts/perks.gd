class_name Perks
extends RefCounted

## Segen: Bei jedem Stufenaufstieg wählt man einen von dreien. "mods" gilt dauerhaft für diese Fahrt,
## "now" wirkt sofort (hull Rumpf, proviant, powder, kraft_all, stress_all, loot).

const DATA := {
	"odin": {"name": "Odins Gunst", "desc": "Rumpf +10 (größer und sofort geheilt). Er hat es nicht ausdrücklich versprochen.", "mods": {"hull_max": 10.0}, "now": {"hull": 10}},
	"vorrat": {"name": "Gut gelagert", "desc": "Proviant +4 und Platz für mehr.", "mods": {"proviant_max": 4.0}, "now": {"proviant": 4}},
	"wind": {"name": "Frischer Wind", "desc": "Segel bringen 10 % mehr Vortrieb.", "mods": {"sail": 1.1}, "now": {}},
	"arme": {"name": "Starke Arme", "desc": "Die Riemen bringen 10 % mehr Vortrieb.", "mods": {"oars": 1.1}, "now": {}},
	"haende": {"name": "Geübte Hände", "desc": "Die Zimmerleute flicken 25 % mehr.", "mods": {"repair": 1.25}, "now": {}},
	"lieder": {"name": "Heldenlieder", "desc": "Verzweiflung −25 für alle, künftig 10 % weniger.", "mods": {"stress": 0.9}, "now": {"stress_all": -25}},
	"zaeh": {"name": "Zähe Burschen", "desc": "Kraft +30 für alle.", "mods": {}, "now": {"kraft_all": 30}},
	"glueck": {"name": "Glückspfennig", "desc": "Beute +60, künftig 10 % mehr.", "mods": {"loot": 1.1}, "now": {"loot": 60}},
	"karte": {"name": "Seekarte der Alten", "desc": "Eine Meile weiter sehen.", "mods": {"visible": 1.0}, "now": {}},
	"pulver": {"name": "Ein Fass Pulver", "desc": "Pulver +5, Lager +4.", "mods": {"powder_max": 4.0}, "now": {"powder": 5}},
	"ramm": {"name": "Rammbock", "desc": "Rammen schadet dem Gegner 4 mehr.", "mods": {"ram": 4.0}, "now": {}},
	"schilde": {"name": "Schilde an die Reling", "desc": "Jeder Treffer im Gefecht schadet 2 weniger.", "mods": {"armor": 2.0}, "now": {}},
	"sturm": {"name": "Sturmfest", "desc": "Gefahren schaden 10 % weniger.", "mods": {"hazard": 0.9}, "now": {}},
	"wellen": {"name": "Wellenreiter", "desc": "Der Seegang schadet dem Rumpf 8 % weniger.", "mods": {"strain": 0.92}, "now": {}},
}


static func ids() -> Array:
	return DATA.keys()


## Drei zufällige Segen, die man noch nicht hat.
static func offer(taken: Array) -> Array:
	var pool: Array = []
	for id in DATA:
		if not taken.has(id):
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))
