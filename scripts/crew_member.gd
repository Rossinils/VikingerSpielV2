class_name CrewMember
extends RefCounted

enum State { ABOARD, OVERBOARD, DEAD, RESERVE }  # RESERVE: an Bord, aber ohne Platz und ohne Dienst (unter Deck)
enum Affliction { NONE, VERZAGT, BERSERK }

var id := 0
var display_name := ""
var look := 0  # Zeile im Crew-Atlas
var state := State.ABOARD
var slot := -1  # Decksplatz (Index in Stations.SLOTS), -1 solange er im Wasser ist
var home_slot := -1  # Platz, auf den er nach der Rettung zurück will

var kraft := 100.0  # Kraft 0..100; unter 40 lässt die Arbeitsleistung nach
var stress := 0.0  # Verzweiflung; bei 100 kippt er
var afflicted := false  # nach dem Kippen: verzagt (halbe Leistung, steckt an) oder Berserker (stärker, aber unberechenbar)
var affliction: int = Affliction.NONE
var traits: Array[int] = []  # Eigenschaften (Traits.Id)
var role := 0  # Kampfrolle (Roles.Id): Schildträger, Axtmann, Bogenschütze, Skalde, Musketier
var loadout: Array = []  # die vier Fertigkeiten, die er in den Kampf mitnimmt (leer = Standardwahl seiner Rolle)
var weapon_lvl := 0  # Schmiede im Hafen: Waffe, bis Stufe 4 (mehr Schaden)
var armor_lvl := 0  # Schmiede im Hafen: Rüstung, bis Stufe 4 (mehr Schutz)
var skill_lvl: Dictionary = {}  # Kampfschule im Hafen: Fertigkeit -> Stufe (bis 3)
var gear: Dictionary = {}  # Ausrüstung: Platz (Gear.Slot) -> Schlüssel wie "schwert@1"
var swim_x := 0.0  # nur für die Darstellung


## Müdigkeitsstufen statt einer Klippe: frisch (ab 70), müde (ab 40), erschöpft (ab 15), am Ende (darunter).
const FRESH_AT := 70.0
const TIRED_AT := 40.0
const SPENT_AT := 15.0
const STAGE_NAMES := ["frisch", "müde", "erschöpft", "am Ende"]


func fatigue_stage() -> int:
	if kraft >= FRESH_AT:
		return 0
	if kraft >= TIRED_AT:
		return 1
	if kraft >= SPENT_AT:
		return 2
	return 3


func fatigue_name() -> String:
	return String(STAGE_NAMES[fatigue_stage()])


## Leistung aus der Kraft allein: 100 % frisch, 90–100 % müde, 65–90 % erschöpft, 35–65 % am Ende.
static func kraft_efficiency(k: float) -> float:
	if k >= FRESH_AT:
		return 1.0
	if k >= TIRED_AT:
		return 0.9 + 0.1 * (k - TIRED_AT) / (FRESH_AT - TIRED_AT)
	if k >= SPENT_AT:
		return 0.65 + 0.25 * (k - SPENT_AT) / (TIRED_AT - SPENT_AT)
	return 0.35 + 0.3 * maxf(k, 0.0) / SPENT_AT


## Arbeitsleistung aus Kraft und Zustand, ohne Eigenschaften.
func efficiency() -> float:
	var e := kraft_efficiency(kraft)
	if afflicted:
		e *= 1.2 if affliction == Affliction.BERSERK else 0.5
	return e


## Arbeitsleistung an einer Station, mit Eigenschaften.
func efficiency_at(station: int) -> float:
	var e := efficiency()
	for t in traits:
		var d: Dictionary = Traits.DATA[t]
		var by_station: Dictionary = d.get("eff", {})
		e *= float(by_station.get(station, 1.0)) * float(d.get("eff_all", 1.0))
	return e


func _factor(key: String) -> float:
	var f := 1.0
	for t in traits:
		f *= float((Traits.DATA[t] as Dictionary).get(key, 1.0))
	return f


func cost_factor() -> float:
	return _factor("cost")


func stress_factor() -> float:
	return _factor("stress") * float(Gear.sum_mods(gear)["stress"])


func wash_factor() -> float:
	return _factor("wash")


func fight_factor() -> float:
	return _factor("fight")


func swim_bonus() -> float:
	var b := 0.0
	for t in traits:
		b += float((Traits.DATA[t] as Dictionary).get("swim", 0.0))
	return b


func trait_names() -> PackedStringArray:
	var out := PackedStringArray()
	for t in traits:
		out.append(String(Traits.DATA[t]["name"]))
	return out


func affliction_name() -> String:
	if not afflicted:
		return ""
	return "Berserker" if affliction == Affliction.BERSERK else "verzagt"

## Die Fertigkeiten, mit denen er kämpft: seine Wahl, sonst die Standardwahl der Rolle.
func skills() -> Array:
	return Roles.valid_loadout(role, loadout)
