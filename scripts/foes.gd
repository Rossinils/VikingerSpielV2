class_name Foes
extends RefCounted

## Gegner des Deckkampfes und ihre Aufstellungen. Reihe 0 steht vorn. Werte für Etappe 1, sie wachsen mit der Etappe.
##   hp      Kraft
##   dodge   Ausweichen in Prozent, prot Schutz (0..0.8)
##   speed   Tempo; dmg Grundschaden [von, bis]
##   skills  [Fertigkeit, Gewicht]; gewählt wird nach Gewicht unter den aus der Reihe möglichen
##   immune  Zustände, die nichts bewirken (bleed, stun)
##   coward  flieht, wenn er allein übrig ist; fearless  flieht nie
##   guarded unerreichbar, solange noch ein Fangarm (kind "tentakel") steht

const TYPES := {
	"rost": {"name": "Rost-Draugr", "short": "Rost", "hp": 26.0, "dodge": 0.0, "prot": 0.10, "speed": 3, "dmg": [8.0, 12.0], "skills": [["f_hieb", 70], ["f_kralle", 30]], "immune": ["bleed"]},
	"bogner": {"name": "Draugr-Bogner", "short": "Bogner", "hp": 18.0, "dodge": 5.0, "prot": 0.0, "speed": 5, "dmg": [7.0, 11.0], "skills": [["f_pfeil", 100]], "immune": ["bleed"]},
	"totenwart": {"name": "Totenwart", "short": "Totenwart", "hp": 20.0, "dodge": 5.0, "prot": 0.0, "speed": 6, "dmg": [5.0, 8.0], "skills": [["f_klage", 55], ["f_hieb", 45]], "immune": ["bleed"]},
	"brecher": {"name": "Räuber-Brecher", "short": "Brecher", "hp": 30.0, "dodge": 0.0, "prot": 0.15, "speed": 3, "dmg": [9.0, 13.0], "skills": [["f_hieb", 45], ["f_stoss", 30], ["f_ramm", 25]], "immune": []},
	"messerkerl": {"name": "Messerkerl", "short": "Messer", "hp": 20.0, "dodge": 15.0, "prot": 0.0, "speed": 7, "dmg": [8.0, 12.0], "skills": [["f_messer", 100]], "immune": []},
	"schuetze": {"name": "Räuber-Schütze", "short": "Schütze", "hp": 18.0, "dodge": 5.0, "prot": 0.0, "speed": 5, "dmg": [8.0, 12.0], "skills": [["f_pfeil", 100]], "immune": []},
	"haken": {"name": "Hakenwerfer", "short": "Haken", "hp": 20.0, "dodge": 5.0, "prot": 0.0, "speed": 6, "dmg": [6.0, 9.0], "skills": [["f_netz", 60], ["f_wurf", 40]], "immune": []},
	"wache": {"name": "Schiffswache", "short": "Wache", "hp": 28.0, "dodge": 0.0, "prot": 0.20, "speed": 4, "dmg": [8.0, 12.0], "skills": [["f_hieb", 100]], "immune": []},
	"armbrust": {"name": "Armbrustschütze", "short": "Armbrust", "hp": 18.0, "dodge": 5.0, "prot": 0.0, "speed": 5, "dmg": [9.0, 13.0], "skills": [["f_armbrust", 100]], "immune": []},
	"kaufmann": {"name": "Kaufmann", "short": "Kaufmann", "hp": 16.0, "dodge": 0.0, "prot": 0.0, "speed": 2, "dmg": [4.0, 6.0], "skills": [["f_wurf", 100]], "immune": [], "coward": true},
	"bauer": {"name": "Bauer", "short": "Bauer", "hp": 20.0, "dodge": 0.0, "prot": 0.0, "speed": 3, "dmg": [6.0, 10.0], "skills": [["f_gabel", 100]], "immune": []},
	"schmied": {"name": "Schmied", "short": "Schmied", "hp": 32.0, "dodge": 0.0, "prot": 0.10, "speed": 2, "dmg": [9.0, 13.0], "skills": [["f_hammer", 100]], "immune": []},
	"hund": {"name": "Dorfhund", "short": "Hund", "hp": 14.0, "dodge": 15.0, "prot": 0.0, "speed": 8, "dmg": [5.0, 8.0], "skills": [["f_biss", 100]], "immune": []},
	# Gegnerrollen: Heiler, Beschützer, Beschwörer, Antreiber
	"priester": {"name": "Knochenpriester", "short": "Priester", "hp": 16.0, "dodge": 5.0, "prot": 0.0, "speed": 6, "dmg": [4.0, 6.0], "skills": [["f_heilen", 70], ["f_klage", 30]], "immune": ["bleed"]},
	"waechter": {"name": "Grabwächter", "short": "Wächter", "hp": 34.0, "dodge": 0.0, "prot": 0.20, "speed": 3, "dmg": [8.0, 12.0], "skills": [["f_deckung", 40], ["f_hieb", 60]], "immune": ["bleed"]},
	"beschwoerer": {"name": "Totenbeschwörer", "short": "Beschwörer", "hp": 18.0, "dodge": 10.0, "prot": 0.0, "speed": 5, "dmg": [4.0, 7.0], "skills": [["f_beschwoeren", 55], ["f_klage", 20], ["f_hieb", 25]], "immune": ["bleed"]},
	"knochen": {"name": "Skelett", "short": "Skelett", "hp": 10.0, "dodge": 0.0, "prot": 0.0, "speed": 4, "dmg": [5.0, 8.0], "skills": [["f_hieb", 100]], "immune": ["bleed"]},
	"antreiber": {"name": "Trommler", "short": "Trommler", "hp": 20.0, "dodge": 5.0, "prot": 0.0, "speed": 6, "dmg": [5.0, 8.0], "skills": [["f_horn", 45], ["f_wurf", 55]], "immune": []},
	"kraeuterfrau": {"name": "Kräuterfrau", "short": "Kräuter", "hp": 14.0, "dodge": 5.0, "prot": 0.0, "speed": 5, "dmg": [3.0, 5.0], "skills": [["f_heilen", 60], ["f_wurf", 40]], "immune": []},
	# Der Kraken: Fangarme an Deck, der Körper dahinter ist erst erreichbar, wenn alle Fangarme gefällt sind
	"tentakel": {"name": "Fangarm", "short": "Fangarm", "hp": 20.0, "dodge": 5.0, "prot": 0.05, "speed": 5, "dmg": [5.0, 7.0], "skills": [["f_kr_peitsche", 60], ["f_kr_griff", 40]], "immune": [], "fearless": true},
	"kraken": {"name": "Kraken", "short": "Kraken", "hp": 60.0, "dodge": 0.0, "prot": 0.10, "speed": 6, "dmg": [7.0, 10.0], "skills": [["f_kr_schnabel", 60], ["f_kr_tinte", 40]], "immune": [], "fearless": true, "guarded": true},
}

## Reihenfolge = Reihe (vorn zuerst). Am Anfang (Etappe 1) steht nur, was vorn und in der Mitte kämpft.
## Zeile der Figur in assets/combat.png (tools/make_combat_art.py); die ersten vier Zeilen gehören den Rollen der Männer.
const ROW := {"rost": 5, "bogner": 6, "totenwart": 7, "brecher": 8, "messerkerl": 9, "schuetze": 10, "haken": 11, "wache": 12, "armbrust": 13, "kaufmann": 14, "bauer": 15, "schmied": 16, "hund": 17, "tentakel": 18, "priester": 19, "waechter": 20, "beschwoerer": 21, "knochen": 22, "antreiber": 23, "kraeuterfrau": 24}
## Riesenfiguren haben ein eigenes Bild (assets/<Name>.png, eine Zeile, Zellen BIG_W x BIG_H) statt einer Zeile in combat.png.
const BIG := {"kraken": {"file": "res://assets/kraken.png", "w": 88, "h": 88}}

## "boss": steht immer als Letzter dabei, auch wenn weniger Gegner gewünscht sind (units nennt zuerst die Fußtruppen).
const FORMATIONS := {
	"draugr": {"name": "Draugr", "variants": [["rost", "rost", "bogner", "totenwart"], ["waechter", "rost", "priester", "bogner"], ["rost", "rost", "beschwoerer", "bogner"]], "stress": 0},
	"raeuber": {"name": "Räuber", "variants": [["brecher", "messerkerl", "schuetze", "haken"], ["brecher", "messerkerl", "antreiber", "schuetze"], ["messerkerl", "brecher", "haken", "antreiber"]], "stress": 0},
	"haendler": {"name": "Wachen des Handelsschiffs", "variants": [["wache", "wache", "armbrust", "kaufmann"], ["wache", "wache", "kaufmann", "armbrust"], ["wache", "armbrust", "antreiber", "kaufmann"]], "stress": 0},
	"dorf": {"name": "Dorfbewohner", "variants": [["bauer", "hund", "schmied", "bauer"], ["bauer", "bauer", "kraeuterfrau", "schmied"], ["hund", "bauer", "kraeuterfrau", "hund"]], "stress": 0},
	"kraken": {"name": "Kraken", "units": ["tentakel", "tentakel", "tentakel"], "boss": "kraken", "stress": 0},
}


static func info(key: String) -> Dictionary:
	return TYPES[key]


## Aufstellung für Formation, Etappe und gewünschte Anzahl (-1: nach Etappe: in Etappe 1 drei, danach vier).
static func units_for(formation: String, stage: int, count: int = -1) -> Array[String]:
	var f: Dictionary = FORMATIONS[formation]
	var all: Array = f["units"] if f.has("units") else (f["variants"] as Array)[randi() % (f["variants"] as Array).size()]
	var boss := String(f.get("boss", ""))
	var n := count if count > 0 else (3 if stage <= 1 else 4)
	if boss != "" and count <= 0:
		n = 3  # zwei Fangarme und der Körper
	var out: Array[String] = []
	for k in mini(n - (1 if boss != "" else 0), all.size()):
		out.append(String(all[k]))
	if boss != "":
		out.append(boss)
	return out


## Was ein Gegner im Kampf vor allem tut (für die Aufstellung): leer, wenn er einfach zuschlägt.
static func role_hint(key: String) -> String:
	var ids: Array = []
	for pair in info(key)["skills"]:
		ids.append(String(pair[0]))
	if ids.has("f_heilen"):
		return "Heiler"
	if ids.has("f_deckung"):
		return "Beschützer"
	if ids.has("f_beschwoeren"):
		return "Beschwörer"
	if ids.has("f_horn"):
		return "Antreiber"
	if ids.has("f_netz"):
		return "Zerrer"
	if ids.has("f_ramm"):
		return "Rammer"
	if ids.has("f_klage"):
		return "Schreier"
	if ids.has("f_pfeil") or ids.has("f_armbrust"):
		return "Schütze"
	return ""


## Der Gegner steht auf einem eigenen Riesenbild.
static func is_big(key: String) -> bool:
	return BIG.has(key)
