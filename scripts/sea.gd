class_name Sea
extends RefCounted

## See und Gefahren: Seegang 1..5 und was auf einer Meile lauern kann.

enum Hazard { NONE, BRECHER, BOE, RIFF, NEBEL }

const SEA_NAMES := ["", "Ruhige See", "Leichter Seegang", "Raue See", "Schwere See", "Sturm"]
const SEA_COLORS := [Color.WHITE, Color("5a8ad9"), Color("6aa3a0"), Color("d9b24a"), Color("d9803a"), Color("d2564b")]
const HAZARD_NAMES := ["–", "Brecher", "Böen", "Riffe", "Nebel"]
## Schaden am Rumpf pro Meile durch den Seegang. Bei ruhiger See (1 und 2) gibt es keinen.
const STRAIN := [0.0, 0.0, 0.0, 5.0, 10.0, 16.0]
## Wirkung einer ungeschützten Gefahr: Rumpfschaden, Wahrscheinlichkeit für "Mann über Bord", Beuteverlust
const HAZARD := [
	{"damage": 0.0, "over": 0.0, "loot": 0.0},
	{"damage": 18.0, "over": 0.45, "loot": 0.0},
	{"damage": 8.0, "over": 0.30, "loot": 0.0},
	{"damage": 25.0, "over": 0.0, "loot": 15.0},
	{"damage": 14.0, "over": 0.0, "loot": 0.0},
]
const HAZARD_KEYS := ["", "brecher", "boe", "riff", "nebel"]


## Grundrisiko pro Meile, dass die See einen Mann über Bord spült.
static func wash_chance(sea: int) -> float:
	var s := float(sea - 1)
	return 0.02 * s * s
