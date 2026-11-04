class_name Roles
extends RefCounted

## Kampfrollen der Männer und alle Fertigkeiten des Deckkampfes (Männer und Gegner). Alle Zahlen stehen hier.
##
## Jede Rolle hat sechs Fertigkeiten ("pool"), vier davon nimmt ein Mann mit in den Kampf ("skills" = Standardwahl,
## gewählt wird in der Aufstellung, siehe CrewMember.loadout).
##
## Fertigkeit:
##   name    Anzeigename, icon Symbol (scripts/skill_icons.gd)
##   from    Reihen (0 = vorn), aus denen sie benutzt werden darf
##   tgt     Männer: foe (ein Gegner), foes (Gegner in den Reihen "to"), ally (ein Mann), allies (alle Männer), self (er selbst)
##           Gegner: hero (ein Mann), heroes (alle Männer), fally (ein Verbündeter), fallies (alle Verbündeten), fself (er selbst)
##   to      Reihen des Ziels, die getroffen werden dürfen
##   dmg     Faktor auf den Grundschaden des Kämpfers (0 = kein Schaden)
##   acc     Grundtreffer in Prozent, crit Krit-Chance in Prozent
##   stress  Verzweiflung, die ein getroffener Mann bekommt (Gegner-Fertigkeiten)
##   uses    wie oft pro Kampf (fehlt = beliebig)
##   fx      Wirkungen: stun (Runden), bleed [Runden, Schaden], mark (Runden), guard (Runden), buff (Runden), heal (Kraft),
##           stress_heal (Verzweiflung), move (-1 = nach vorn, +1 = nach hinten, für den Benutzer), pull (Ziel nach vorn),
##           push (Ziel eine Reihe nach hinten), taunt (Runden, die Gegner zielen fast nur auf ihn), cleanse (löst Betäubung,
##           Blutung, Tinte), fire (braucht eine geladene Muskete), reload (Muskete laden), self_stress (Verzweiflung für ihn),
##           summon (Gegnerart, die an die Front tritt), grab (Runden bis zum Überbordgehen), ink (Runden mit 20 % weniger Treffern)

enum Id { SCHILD, AXT, BOGEN, SKALDE, MUSKET }

const MAX_LOADOUT := 4

const ROLES := [
	{"name": "Schildträger", "short": "Schild", "speed": 4, "dmg": [6.0, 10.0], "prot": 0.15, "dodge": 5.0,
		"pool": ["s_hieb", "s_stoss", "s_wall", "s_deckung", "s_rund", "s_ruf"], "skills": ["s_hieb", "s_stoss", "s_wall", "s_rund"],
		"desc": "Hält die erste Reihe und zieht Treffer auf sich."},
	{"name": "Axtmann", "short": "Axt", "speed": 5, "dmg": [10.0, 15.0], "prot": 0.0, "dodge": 5.0,
		"pool": ["a_hieb", "a_spalt", "a_ansturm", "a_wirbel", "a_spalter", "a_wut"], "skills": ["a_hieb", "a_spalt", "a_ansturm", "a_wirbel"],
		"desc": "Der Schadensmacher: Hiebe, Blutung, Ansturm."},
	{"name": "Bogenschütze", "short": "Bogen", "speed": 6, "dmg": [8.0, 12.0], "prot": 0.0, "dodge": 10.0,
		"pool": ["b_schuss", "b_mark", "b_regen", "b_brand", "b_lahm", "b_rueck"], "skills": ["b_schuss", "b_mark", "b_regen", "b_brand"],
		"desc": "Trifft jede Reihe aus der zweiten bis vierten."},
	{"name": "Skalde", "short": "Skalde", "speed": 7, "dmg": [4.0, 7.0], "prot": 0.0, "dodge": 10.0,
		"pool": ["k_stab", "k_krieg", "k_heil", "k_trost", "k_weck", "k_hohn"], "skills": ["k_stab", "k_krieg", "k_heil", "k_trost"],
		"desc": "Hält den Mut oben und die Männer am Leben. Seine Lieder kennen keine Grenzen."},
	{"name": "Musketier", "short": "Muskete", "speed": 3, "dmg": [14.0, 20.0], "prot": 0.0, "dodge": 5.0,
		"pool": ["m_schuss", "m_nachladen", "m_pistole", "m_streu", "m_kopf", "m_knall"], "skills": ["m_schuss", "m_nachladen", "m_pistole", "m_streu"],
		"desc": "Langsam, aber ein Schuss ändert alles. Danach muss nachgeladen werden."},
]

const SKILLS := {
	# --- Schildträger
	"s_hieb": {"name": "Hieb", "icon": "sword", "from": [0, 1], "tgt": "foe", "to": [0, 1], "dmg": 1.0, "acc": 85, "crit": 5, "fx": {}, "desc": "Ein ehrlicher Hieb."},
	"s_stoss": {"name": "Schildstoß", "icon": "bash", "from": [0, 1], "tgt": "foe", "to": [0, 1], "dmg": 0.6, "acc": 80, "crit": 0, "fx": {"stun": 1}, "desc": "Betäubt den Gegner: er setzt seinen nächsten Zug aus."},
	"s_wall": {"name": "Schildwall", "icon": "shield", "from": [0, 1, 2, 3], "tgt": "self", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"guard": 2}, "desc": "Schutz +40 % für zwei Runden; die Gegner zielen eher auf ihn."},
	"s_deckung": {"name": "Deckung", "icon": "guardally", "from": [0, 1, 2, 3], "tgt": "ally", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"guard": 2}, "desc": "Ein Mann bekommt Schutz +40 % für zwei Runden."},
	"s_rund": {"name": "Rundumschlag", "icon": "sweep", "from": [0, 1], "tgt": "foes", "to": [0, 1], "dmg": 0.55, "acc": 80, "crit": 0, "fx": {}, "desc": "Trifft die ersten beiden Reihen, aber schwach."},
	"s_ruf": {"name": "Herausforderung", "icon": "taunt", "from": [0, 1, 2, 3], "tgt": "self", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"taunt": 2}, "desc": "Die Gegner zielen zwei Runden fast nur auf ihn. Ohne Schutz, aber mit Schildwall ein Fels."},
	# --- Axtmann
	"a_hieb": {"name": "Hieb", "icon": "axe", "from": [0, 1], "tgt": "foe", "to": [0, 1], "dmg": 1.0, "acc": 90, "crit": 8, "fx": {}, "desc": "Ein schwerer Hieb."},
	"a_spalt": {"name": "Spaltschlag", "icon": "cleave", "from": [0, 1], "tgt": "foe", "to": [0, 1], "dmg": 0.8, "acc": 85, "crit": 5, "fx": {"bleed": [3, 3]}, "desc": "Reißt eine Wunde: Blutung, 3 Schaden in 3 Runden."},
	"a_ansturm": {"name": "Ansturm", "icon": "charge", "from": [1, 2, 3], "tgt": "foe", "to": [0], "dmg": 1.1, "acc": 85, "crit": 5, "fx": {"move": -1}, "desc": "Rückt eine Reihe vor und schlägt die erste Reihe."},
	"a_wirbel": {"name": "Wirbelhieb", "icon": "whirl", "from": [0, 1], "tgt": "foes", "to": [0, 1], "dmg": 0.6, "acc": 80, "crit": 3, "fx": {}, "desc": "Trifft die ersten beiden Reihen."},
	"a_spalter": {"name": "Kopfspalter", "icon": "axe_big", "from": [0, 1], "tgt": "foe", "to": [0, 1], "dmg": 1.5, "acc": 65, "crit": 15, "fx": {}, "desc": "Ein Hieb mit allem Gewicht: viel Schaden, aber er trifft seltener."},
	"a_wut": {"name": "Kampfwut", "icon": "rage", "from": [0, 1, 2, 3], "tgt": "self", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"buff": 3, "self_stress": 8}, "desc": "Drei Runden 25 % mehr Schaden, kostet ihn 8 Verzweiflung."},
	# --- Bogenschütze
	"b_schuss": {"name": "Schuss", "icon": "bow", "from": [1, 2, 3], "tgt": "foe", "to": [0, 1, 2, 3], "dmg": 0.9, "acc": 90, "crit": 8, "fx": {}, "desc": "Trifft jede Reihe."},
	"b_mark": {"name": "Markieren", "icon": "mark", "from": [1, 2, 3], "tgt": "foe", "to": [0, 1, 2, 3], "dmg": 0.3, "acc": 95, "crit": 0, "fx": {"mark": 2}, "desc": "Das Ziel nimmt 25 % mehr Schaden und ist leichter zu treffen (2 Runden)."},
	"b_regen": {"name": "Pfeilregen", "icon": "rain", "from": [2, 3], "tgt": "foes", "to": [0, 1, 2, 3], "dmg": 0.4, "acc": 80, "crit": 0, "uses": 2, "fx": {}, "desc": "Trifft alle Gegner schwach (zweimal je Kampf)."},
	"b_brand": {"name": "Brandpfeil", "icon": "fire_arrow", "from": [1, 2, 3], "tgt": "foe", "to": [0, 1, 2, 3], "dmg": 0.5, "acc": 85, "crit": 0, "fx": {"bleed": [3, 3]}, "desc": "Zündet das Ziel an: Brand, 3 Schaden in 3 Runden."},
	"b_lahm": {"name": "Lähmschuss", "icon": "stun", "from": [1, 2, 3], "tgt": "foe", "to": [0, 1, 2, 3], "dmg": 0.6, "acc": 75, "crit": 0, "fx": {"stun": 1}, "desc": "Trifft ins Bein: das Ziel setzt seinen nächsten Zug aus."},
	"b_rueck": {"name": "Rückzugsschuss", "icon": "retreat", "from": [0, 1, 2], "tgt": "foe", "to": [0, 1, 2, 3], "dmg": 0.8, "acc": 85, "crit": 5, "fx": {"move": 1}, "desc": "Schießt und weicht dabei eine Reihe zurück."},
	# --- Skalde (ohne Einsatzgrenzen: sein Zug ist der Preis)
	"k_stab": {"name": "Stabhieb", "icon": "staff", "from": [0, 1, 2], "tgt": "foe", "to": [0, 1, 2], "dmg": 1.0, "acc": 80, "crit": 3, "fx": {}, "desc": "Notfalls hilft auch ein Stock."},
	"k_krieg": {"name": "Kriegslied", "icon": "song_war", "from": [1, 2, 3], "tgt": "allies", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"buff": 2}, "desc": "Alle Männer machen 25 % mehr Schaden (2 Runden)."},
	"k_heil": {"name": "Heilsegen", "icon": "heal", "from": [1, 2, 3], "tgt": "ally", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"heal": 18}, "desc": "Ein Mann bekommt 18 Kraft."},
	"k_trost": {"name": "Trostlied", "icon": "song_calm", "from": [1, 2, 3], "tgt": "ally", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"stress_heal": 15}, "desc": "Ein Mann verliert 15 Verzweiflung."},
	"k_weck": {"name": "Weckruf", "icon": "cleanse", "from": [1, 2, 3], "tgt": "allies", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"cleanse": 1, "stress_heal": 4}, "desc": "Löst bei allen Betäubung, Blutung und Tinte und nimmt etwas Verzweiflung."},
	"k_hohn": {"name": "Hohnlied", "icon": "mock", "from": [1, 2, 3], "tgt": "foes", "to": [0, 1, 2, 3], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"mark": 1}, "desc": "Alle Gegner sind eine Runde markiert: mehr Schaden, leichter zu treffen."},
	# --- Musketier: die Muskete muss nach jedem Schuss geladen werden, die Pistole nicht
	"m_schuss": {"name": "Musketenschuss", "icon": "musket", "from": [1, 2, 3], "tgt": "foe", "to": [0, 1, 2, 3], "dmg": 1.3, "acc": 80, "crit": 10, "fx": {"fire": 1}, "desc": "Ein schwerer Schuss auf jede Reihe. Danach ist die Muskete leer."},
	"m_nachladen": {"name": "Nachladen", "icon": "reload", "from": [0, 1, 2, 3], "tgt": "self", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"reload": 1}, "desc": "Lädt die Muskete für den nächsten Schuss."},
	"m_pistole": {"name": "Pistole", "icon": "pistol", "from": [0, 1], "tgt": "foe", "to": [0, 1], "dmg": 0.8, "acc": 85, "crit": 8, "fx": {}, "desc": "Aus der Nähe: ein Schuss ohne Nachladen."},
	"m_streu": {"name": "Streuschuss", "icon": "scatter", "from": [0, 1, 2], "tgt": "foes", "to": [0, 1], "dmg": 0.7, "acc": 80, "crit": 0, "fx": {"fire": 1}, "desc": "Hagelt in die ersten beiden Reihen. Danach ist die Muskete leer."},
	"m_kopf": {"name": "Gezielter Schuss", "icon": "crosshair", "from": [1, 2, 3], "tgt": "foe", "to": [0, 1, 2, 3], "dmg": 1.0, "acc": 65, "crit": 40, "fx": {"fire": 1}, "desc": "Zielt lange: trifft seltener, aber oft kritisch. Danach ist die Muskete leer."},
	"m_knall": {"name": "Schreckschuss", "icon": "bang", "from": [0, 1, 2], "tgt": "foe", "to": [0, 1], "dmg": 0.3, "acc": 90, "crit": 0, "fx": {"stun": 1, "fire": 1}, "desc": "Der Knall betäubt den Gegner. Danach ist die Muskete leer."},
	# --- Gegner
	"f_hieb": {"name": "Hieb", "icon": "sword", "from": [0, 1], "tgt": "hero", "to": [0, 1, 2], "dmg": 1.0, "acc": 80, "crit": 5, "fx": {}, "desc": ""},
	"f_kralle": {"name": "Krallen", "icon": "claw", "from": [0, 1], "tgt": "hero", "to": [0, 1], "dmg": 0.7, "acc": 85, "crit": 5, "fx": {"bleed": [3, 2]}, "desc": ""},
	"f_pfeil": {"name": "Pfeil", "icon": "bow", "from": [1, 2, 3], "tgt": "hero", "to": [0, 1, 2, 3], "dmg": 0.9, "acc": 80, "crit": 8, "fx": {}, "desc": ""},
	"f_klage": {"name": "Totenklage", "icon": "wail", "from": [1, 2, 3], "tgt": "heroes", "to": [0, 1, 2, 3], "dmg": 0.0, "acc": 100, "crit": 0, "stress": 9, "fx": {}, "desc": ""},
	"f_stoss": {"name": "Stoß", "icon": "bash", "from": [0, 1], "tgt": "hero", "to": [0, 1], "dmg": 0.8, "acc": 75, "crit": 0, "fx": {"stun": 1}, "desc": ""},
	"f_messer": {"name": "Messer", "icon": "knife", "from": [0, 1], "tgt": "hero", "to": [0, 1, 2], "dmg": 0.8, "acc": 85, "crit": 8, "fx": {"bleed": [2, 2]}, "desc": ""},
	"f_netz": {"name": "Enterhaken", "icon": "hook", "from": [1, 2, 3], "tgt": "hero", "to": [1, 2, 3], "dmg": 0.3, "acc": 80, "crit": 0, "fx": {"pull": 1}, "desc": ""},
	"f_armbrust": {"name": "Armbrust", "icon": "bow", "from": [1, 2, 3], "tgt": "hero", "to": [0, 1, 2, 3], "dmg": 1.1, "acc": 80, "crit": 8, "fx": {}, "desc": ""},
	"f_wurf": {"name": "Wurf", "icon": "thrown", "from": [0, 1, 2, 3], "tgt": "hero", "to": [0, 1, 2, 3], "dmg": 0.4, "acc": 70, "crit": 0, "fx": {}, "desc": ""},
	"f_gabel": {"name": "Heugabel", "icon": "fork", "from": [0, 1], "tgt": "hero", "to": [0, 1], "dmg": 0.9, "acc": 75, "crit": 3, "fx": {}, "desc": ""},
	"f_hammer": {"name": "Schmiedehammer", "icon": "hammer", "from": [0, 1, 2], "tgt": "hero", "to": [0, 1], "dmg": 1.4, "acc": 70, "crit": 5, "fx": {}, "desc": ""},
	"f_biss": {"name": "Biss", "icon": "fang", "from": [0, 1], "tgt": "hero", "to": [0, 1, 2], "dmg": 0.8, "acc": 85, "crit": 5, "fx": {"bleed": [2, 2]}, "desc": ""},
	"f_ramm": {"name": "Rammstoß", "icon": "push", "from": [0, 1], "tgt": "hero", "to": [0, 1], "dmg": 0.7, "acc": 75, "crit": 0, "fx": {"push": 1}, "desc": ""},
	"f_heilen": {"name": "Heilen", "icon": "heal", "from": [0, 1, 2, 3], "tgt": "fally", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"heal": 16}, "desc": ""},
	"f_deckung": {"name": "Deckung", "icon": "guardally", "from": [0, 1, 2, 3], "tgt": "fally", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "fx": {"guard": 2}, "desc": ""},
	"f_horn": {"name": "Kriegshorn", "icon": "horn", "from": [0, 1, 2, 3], "tgt": "fallies", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "uses": 2, "fx": {"buff": 2}, "desc": ""},
	"f_beschwoeren": {"name": "Beschwören", "icon": "summon", "from": [1, 2, 3], "tgt": "fself", "to": [], "dmg": 0.0, "acc": 100, "crit": 0, "uses": 2, "fx": {"summon": "knochen"}, "desc": ""},
	# --- Kraken: Tentakel und Körper
	"f_kr_peitsche": {"name": "Tentakelhieb", "icon": "tentacle", "from": [0, 1, 2, 3], "tgt": "hero", "to": [0, 1, 2], "dmg": 1.0, "acc": 80, "crit": 5, "fx": {}, "desc": ""},
	"f_kr_griff": {"name": "Würgegriff", "icon": "grab", "from": [0, 1, 2, 3], "tgt": "hero", "to": [0, 1, 2, 3], "dmg": 0.4, "acc": 60, "crit": 0, "fx": {"grab": 3}, "desc": ""},
	"f_kr_schnabel": {"name": "Schnabelhieb", "icon": "beak", "from": [0, 1, 2, 3], "tgt": "hero", "to": [0, 1], "dmg": 1.1, "acc": 80, "crit": 5, "fx": {}, "desc": ""},
	"f_kr_tinte": {"name": "Tintenwolke", "icon": "ink", "from": [0, 1, 2, 3], "tgt": "heroes", "to": [0, 1, 2, 3], "dmg": 0.0, "acc": 100, "crit": 0, "stress": 6, "fx": {"ink": 2}, "desc": ""},
	"f_kr_quetsch": {"name": "Zerquetschen", "icon": "crush", "from": [0, 1, 2, 3], "tgt": "heroes", "to": [0, 1, 2, 3], "dmg": 0.8, "acc": 100, "crit": 0, "stress": 8, "fx": {}, "desc": ""},
}


static func role(id: int) -> Dictionary:
	return ROLES[clampi(id, 0, ROLES.size() - 1)]


static func role_name(id: int) -> String:
	return String(role(id)["name"])


static func skill(id: String) -> Dictionary:
	return SKILLS[id]


## Lässt sich die Fertigkeit in der Kampfschule verbessern? Nur, wenn es etwas zu verbessern gibt.
static func upgradable(id: String) -> bool:
	if not SKILLS.has(id) or String(SKILLS[id]["tgt"]) in ["hero", "heroes", "fally", "fallies", "fself"]:
		return false
	var fx: Dictionary = SKILLS[id]["fx"]
	return float(SKILLS[id]["dmg"]) > 0.0 or fx.has("heal") or fx.has("stress_heal") or fx.has("guard") or fx.has("buff") or fx.has("taunt") or fx.has("mark")


## Höchste Stufe: Fertigkeiten mit Schaden oder Heilung wachsen bis Stufe 3, reine Hilfen (Schutz, Lied, Ruf) nur bis 1.
static func max_level(id: String) -> int:
	if not upgradable(id):
		return 0
	var fx: Dictionary = SKILLS[id]["fx"]
	return 3 if (float(SKILLS[id]["dmg"]) > 0.0 or fx.has("heal") or fx.has("stress_heal")) else 1


## Die Fertigkeit mit ihrer Stufe: mehr Schaden und Treffer, mehr Heilung; Hilfen wirken eine Runde länger.
static func effective(id: String, lvl: int) -> Dictionary:
	var sk: Dictionary = SKILLS[id]
	if lvl <= 0 or not upgradable(id):
		return sk
	lvl = mini(lvl, max_level(id))
	var out: Dictionary = sk.duplicate(true)
	var fx: Dictionary = out["fx"]
	if float(sk["dmg"]) > 0.0:
		out["dmg"] = float(sk["dmg"]) * (1.0 + 0.10 * float(lvl))
		if int(sk["acc"]) < 100:
			out["acc"] = mini(int(sk["acc"]) + 2 * lvl, 99)
		out["crit"] = int(sk["crit"]) + 2 * lvl
	if fx.has("heal"):
		fx["heal"] = roundi(float(fx["heal"]) * (1.0 + 0.15 * float(lvl)))
	if fx.has("stress_heal"):
		fx["stress_heal"] = roundi(float(fx["stress_heal"]) * (1.0 + 0.15 * float(lvl)))
	if max_level(id) == 1:
		for key in ["guard", "buff", "taunt", "mark"]:
			if fx.has(key):
				fx[key] = int(fx[key]) + 1
	return out


## Was die nächste Stufe bringt, als kurzer Satz für die Kampfschule.
static func upgrade_text(id: String) -> String:
	if not upgradable(id):
		return "nichts zu verbessern"
	var sk: Dictionary = SKILLS[id]
	var fx: Dictionary = sk["fx"]
	var parts: Array[String] = []
	if float(sk["dmg"]) > 0.0:
		parts.append("Schaden +10 %, Treffer +2")
	if fx.has("heal") or fx.has("stress_heal"):
		parts.append("Wirkung +15 %")
	if max_level(id) == 1:
		parts.append("wirkt eine Runde länger")
	return ", ".join(PackedStringArray(parts))

## Symbol einer Fertigkeit (Name in scripts/skill_icons.gd); unbekannte Fertigkeiten haben keins.
static func icon_of(id: String) -> String:
	if SKILLS.has(id):
		return String(SKILLS[id].get("icon", ""))
	return ""


static func random_role() -> int:
	return randi() % ROLES.size()


## Alle sechs Fertigkeiten einer Rolle.
static func pool(role_id: int) -> Array:
	return (role(role_id)["pool"] as Array).duplicate()


## Die Standardwahl: vier Fertigkeiten.
static func default_loadout(role_id: int) -> Array:
	return (role(role_id)["skills"] as Array).duplicate()


## Die gewählten Fertigkeiten, bereinigt: nur solche aus dem Pool, ohne Doppelte, höchstens vier, sonst die Standardwahl.
static func valid_loadout(role_id: int, wanted: Array) -> Array:
	var allowed: Array = role(role_id)["pool"]
	var out: Array = []
	for s in wanted:
		if allowed.has(String(s)) and not out.has(String(s)) and out.size() < MAX_LOADOUT:
			out.append(String(s))
	if out.is_empty():
		return default_loadout(role_id)
	return out


## Passende Rollen für sieben Männer am Start: von jeder mindestens eine.
static func starting_roles(n: int) -> Array[int]:
	var out: Array[int] = []
	for k in n:
		out.append(k % ROLES.size())
	out.shuffle()
	return out
