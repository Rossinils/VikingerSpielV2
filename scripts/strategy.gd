class_name Strategy
extends RefCounted

## Das Manöver für eine Meile, vom Spieler aus drei Reglern gebaut. Alle Zahlen stehen hier.
##   Segel  0 eingeholt, 1 gerefft, 2 voll    Vortrieb, aber Böen und Seegang
##   Ruder  0 ruht, 1 ruhig, 2 kräftig        Vortrieb und Lenkbarkeit, kostet Kraft
##   Küste  0 nah, 1 mittel, 2 weit           Schutz vor Seegang gegen Riffe
## Segel und Ruder beide aus: Beidrehen, alle ruhen.
##
## build() liefert dieselben Felder, mit denen Voyage rechnet:
##  drive     Vortrieb (Segel + Ruder), daraus die Meilen
##  miles     gewünschte Meilen (bei zu wenig Besatzung weniger)
##  proviant  Verbrauch
##  strain    Faktor auf den Seegang-Schaden am Rumpf
##  exposure  Faktor auf das Grundrisiko "über Bord"
##  repair    Faktor auf die Reparaturleistung der Zimmerleute
##  stress    Verzweiflung pro Mann (negativ = erholen)
##  sail      Segelstellung für die Anzeige
##  cost      Kraftverlust pro Mann nach Station (negativ = erholt sich)
##  needs     Mindestbesetzung (Summe der Arbeitsleistung je Station); darunter wirkt das Manöver schwächer
##  counter   Schutz vor Gefahren (0 = keiner, 1 = völlig, negativ = verschlimmert)

## Vorlagen [Segel, Ruder, Küste]: nur für Bots, Tests und --select, nicht im Spiel sichtbar.
enum Id { VOLLE_FAHRT, BUG_IN_DIE_SEE, SEGEL_BERGEN, OFFENE_SEE, KUESTENNAH, BEIDREHEN }

const PRESETS := [
	{"name": "Volle Fahrt", "dials": [2, 2, 1]},
	{"name": "Bug in die See", "dials": [1, 1, 1]},
	{"name": "Segel bergen", "dials": [0, 1, 1]},
	{"name": "Offene See", "dials": [1, 1, 2]},
	{"name": "Küstennah", "dials": [1, 1, 0]},
	{"name": "Beidrehen", "dials": [0, 0, 1]},
]

const DIAL_NAMES := ["Segel", "Ruder", "Küste"]
const LEVEL_NAMES := [
	["eingeholt", "gerefft", "voll"],
	["ruht", "ruhig", "kräftig"],
	["nah", "mittel", "weit"],
]
## Vor- und Nachteil jeder Stellung in einem Satz, für die Anzeige unter den Reglern.
const INFO := [
	[
		{"plus": "Böen harmlos, wenig Seegang", "minus": "kein Vortrieb vom Wind"},
		{"plus": "Vortrieb mit Reserve", "minus": "Böen nur halb abgewehrt"},
		{"plus": "kräftiger Vortrieb", "minus": "Böen ungeschützt, mehr Schaden"},
	],
	[
		{"plus": "Ruderer erholen sich", "minus": "Vortrieb nur durch Segel"},
		{"plus": "Vortrieb, besser lenkbar", "minus": "Ruderer ermüden"},
		{"plus": "viel Vortrieb, Reserve", "minus": "Ruderer sehr müde"},
	],
	[
		{"plus": "weniger Seegang und Schaden", "minus": "Riffe sehr gefährlich"},
		{"plus": "ausgewogen", "minus": "kein besonderer Schutz"},
		{"plus": "Riffe harmlos", "minus": "mehr Seegang, mehr über Bord"},
	],
]

const SAIL_DRIVE := [0.0, 0.5, 1.0]
const OARS_DRIVE := [0.0, 0.6, 1.0]
const SAIL_STRAIN := [0.9, 1.0, 1.2]
const COAST_STRAIN := [0.7, 1.0, 1.25]
const SAIL_EXPOSURE := [1.0, 1.0, 1.25]
const COAST_EXPOSURE := [0.8, 1.0, 1.2]
const SAIL_NEED := [0.0, 0.4, 0.7]
const OARS_NEED := [0.0, 1.0, 1.6]
const COAST_NEED := [1.0, 0.7, 0.5]  # Steuer: nah an der Küste muss man genau lenken
## Kraftverlust je Fahrt (negativ = Erholung). Müdigkeit baut sich über eine Etappe auf, nicht über drei Fahrten.
const OARS_COST := [-6, 6, 12]
const SAIL_COST := [-4, 4, 6]
const STEER_COST := [7, 6, 5]
const CARPENTER_COST := [4, 5, 6]
const LADUNG_REST := [-15, -25]  # Erholung auf der Ladungsbank: bei viel Vortrieb weniger, sonst mehr
const REST_COST := {Stations.Id.RUDER: -15, Stations.Id.SEGEL: -15, Stations.Id.STEUER: -12, Stations.Id.ZIMMERMANN: 3, Stations.Id.LADUNG: -30}
const REST_PROVIANT := 1

## Schutz vor Gefahren, je Regler [Segel, Ruder, Küste]; die Summe wird auf -1..1 begrenzt.
const COUNTER := {
	Sea.Hazard.BRECHER: [[0.45, 0.3, 0.0], [0.0, 0.2, 0.2], [0.15, 0.1, 0.0]],
	Sea.Hazard.BOE: [[1.0, 0.55, 0.0], [0.0, 0.0, 0.0], [0.2, 0.0, 0.0]],
	Sea.Hazard.RIFF: [[0.0, 0.0, 0.0], [0.0, 0.1, 0.25], [-0.5, 0.0, 1.0]],
	Sea.Hazard.NEBEL: [[0.4, 0.2, 0.0], [0.0, 0.1, 0.1], [0.0, 0.15, 0.3]],
}
const PROTECT_TAGS := {
	Sea.Hazard.BRECHER: "gegen Brecher",
	Sea.Hazard.BOE: "gegen Böen",
	Sea.Hazard.RIFF: "gegen Riffe",
	Sea.Hazard.NEBEL: "gegen Nebel",
}


static func is_rest(sail: int, oars: int) -> bool:
	return sail == 0 and oars == 0


static func preset(id: int) -> Array:
	return PRESETS[id]["dials"]


## Das Manöver aus den drei Reglern. "mods" sind die Schiffswerte (Gegenstände, Segen): sail, oars, strain, exposure, repair.
## "miles" ist der Vortrieb in Meilen pro Fahrt bei voller Besatzung; die Besatzung kann ihn mindern.
static func build(sail: int, oars: int, coast: int, mods: Dictionary = {}) -> Dictionary:
	sail = clampi(sail, 0, 2)
	oars = clampi(oars, 0, 2)
	coast = clampi(coast, 0, 2)
	if is_rest(sail, oars):
		return {
			"name": "Beidrehen", "story": "launch_rest", "tags": ["Rast", "alle ruhen", "Rumpf wird besser geflickt"],
			"dials": [sail, oars, coast], "rest": true, "drive": 0.0,
			"miles": 0.0, "proviant": REST_PROVIANT, "strain": float(mods.get("strain", 1.0)), "exposure": 0.7 * float(mods.get("exposure", 1.0)), "repair": 1.5 * float(mods.get("repair", 1.0)), "stress": -8.0, "sail": 0.0, "rows": false,
			"cost": REST_COST,
			"needs": {},
			"counter": {},
		}
	var drive: float = SAIL_DRIVE[sail] * float(mods.get("sail", 1.0)) + OARS_DRIVE[oars] * float(mods.get("oars", 1.0))
	var miles := 2 if drive >= 1.5 else 1
	var needs := {Stations.Id.STEUER: COAST_NEED[coast]}
	if OARS_NEED[oars] > 0.0:
		needs[Stations.Id.RUDER] = OARS_NEED[oars]
	if SAIL_NEED[sail] > 0.0:
		needs[Stations.Id.SEGEL] = SAIL_NEED[sail]
	var counter := {}
	for hz in COUNTER:
		var c: Array = COUNTER[hz]
		counter[hz] = clampf(float(c[0][sail]) + float(c[1][oars]) + float(c[2][coast]), -1.0, 1.0)
	var cost := {
		Stations.Id.RUDER: OARS_COST[oars],
		Stations.Id.SEGEL: SAIL_COST[sail],
		Stations.Id.STEUER: STEER_COST[coast],
		Stations.Id.ZIMMERMANN: CARPENTER_COST[coast] + (2 if sail == 2 else 0),
		Stations.Id.LADUNG: LADUNG_REST[0] if drive >= 1.5 else LADUNG_REST[1],
	}
	var tags: Array[String] = ["%s Meilen" % String.num(snappedf(drive, 0.1), 1).replace(".", ",")]
	var best: Array = []
	for hz in counter:
		if float(counter[hz]) >= 0.5:
			best.append(hz)
	best.sort_custom(func(a: int, b: int) -> bool: return float(counter[a]) > float(counter[b]))
	for k in mini(best.size(), 2):
		tags.append(String(PROTECT_TAGS[best[k]]))
	if best.is_empty():
		tags.append("kaum Schutz")
	if float(counter[Sea.Hazard.RIFF]) <= -0.25 and tags.size() < 4:
		tags.append("Riffgefahr")
	elif oars == 2 and tags.size() < 4:
		tags.append("sehr müde")
	var name := "Gleichmäßige Fahrt"
	var story := "launch_bug"
	if miles == 2:
		name = "Volle Fahrt" if (sail == 2 and oars == 2) else "Schnelle Fahrt"
		story = "launch_full"
	elif oars == 0:
		name = "Unter Segel"
		story = "launch_bug" if coast == 1 else ("launch_coast" if coast == 0 else "launch_open")
	elif sail == 0:
		name = "Rudern ohne Segel"
		story = "launch_reef"
	elif coast == 0:
		name = "Küstennah"
		story = "launch_coast"
	elif coast == 2:
		name = "Offene See"
		story = "launch_open"
	return {
		"name": name, "story": story, "tags": tags,
		"dials": [sail, oars, coast], "rest": false, "drive": drive,
		"miles": drive, "proviant": 1, "strain": SAIL_STRAIN[sail] * COAST_STRAIN[coast] * float(mods.get("strain", 1.0)),
		"exposure": SAIL_EXPOSURE[sail] * COAST_EXPOSURE[coast] * float(mods.get("exposure", 1.0)),
		"repair": float(mods.get("repair", 1.0)), "stress": 0.0, "sail": float(sail), "rows": oars > 0,
		"cost": cost, "needs": needs, "counter": counter,
	}
