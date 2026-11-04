class_name Stations
extends RefCounted

## Stationen an Bord und die Decksplätze (von Heck nach Bug).
## "x" ist die Position im Schiffsbild (Basisbild von tools/make_art.py), Anker bei x=82.

enum Id { RUDER, SEGEL, STEUER, ZIMMERMANN, LADUNG }

const NAMES := ["Ruder", "Segel", "Steuer", "Zimmermann", "Ladung"]
const DESC := [
	"Rudern bringt das Schiff voran und macht am müdesten.",
	"Segel setzen und bergen; bei Wind unverzichtbar.",
	"Hält Kurs und weicht Brechern und Riffen aus.",
	"Flickt den Rumpf und schöpft, was hereinkommt.",
	"Zwischen den Säcken erholt man sich. Hier ruht, wer müde ist.",
]
const COLORS := [Color("d08a3a"), Color("d8d2c0"), Color("4aa3a0"), Color("4a78c9"), Color("6aa34a")]

const SLOTS := [
	{"station": Id.STEUER, "x": 28},
	{"station": Id.ZIMMERMANN, "x": 40},
	{"station": Id.ZIMMERMANN, "x": 52},
	{"station": Id.RUDER, "x": 64},
	{"station": Id.SEGEL, "x": 90},
	{"station": Id.RUDER, "x": 104},
	{"station": Id.LADUNG, "x": 120},
]


static func slot_station(slot: int) -> int:
	return int(SLOTS[slot]["station"])


static func slot_x(slot: int) -> float:
	return float(SLOTS[slot]["x"])
