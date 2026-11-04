class_name Voyage
extends Node

## Die Fahrt als Seekarte: Knoten (Meilen) mit Seegang, Gefahr und manchmal einer Begegnung.
## Eine Etappe hat zehn Meilen und endet in einem Hafen; danach beginnt die nächste, schwerere. Die Fahrt
## endet erst, wenn das Schiff sinkt oder niemand mehr an Bord ist.
## Jede Fahrt stellst du das Manöver ein (Segel, Ruder, Küste), ordnest die Mannschaft und wählst den Kurs.
## Erst dann läuft das Schiff aus und die Folgen werden der Reihe nach gezeigt. Keine Echtzeit.
## Dieses Skript enthält nur Regeln und Zustand, gezeichnet wird anderswo.

signal log_added(text: String, kind: int)
signal finished(victory: bool)

enum Phase { PLAN, RESOLVE, RESCUE, ENCOUNTER, ENDED, COMBAT }
enum Kind { FACT, LORE, BAD, GOOD }
enum Bond { BROTHER, RIVAL, COMRADE }  # COMRADE: Schicksalsgefährten, die sich unterwegs gefunden haben

const MILES := 10  # Länge einer Etappe in Knotenspalten
const START_PROVIANT := 26
const REPAIR_PER_MAN := 8.0  # Rumpf, den ein Zimmermann bei voller Kraft pro Fahrt flickt
const THEMES := ["Nordsee", "Nebelmeer", "Sturmfront", "Piratengewässer", "Totensee"]  # Etappen-Themen, siehe _pick_theme()
const STAGE_HARDNESS := 0.2  # so viel härter wird die See je Etappe (Seegangs- und Gefahrenschaden)
const SEA_PROFILE := [1, 2, 3, 3, 4, 5, 4, 3, 2, 1]
const VISIBLE_AHEAD := 3  # so viele Meilen voraus kennt man die Knoten (im Nebel nur eine)
const CREW_NAMES := ["Bjarne", "Gunnar", "Ragnar", "Halvar", "Torvald", "Eirik", "Sigurd", "Ulf", "Leif", "Knut", "Orm", "Hakon", "Arne", "Dag", "Einar", "Finn", "Gorm", "Harald", "Ivar", "Kjell", "Olaf", "Rurik", "Sven", "Vidar"]
const RESERVE_BASE := 2  # Reserveplätze ohne Gegenstände; mit Hängematten höchstens RESERVE_MAX
const RESERVE_MAX := 5
## Wer wird zuerst für eine Rettung vom Platz geholt (unwichtigste Station zuerst).
const RESCUE_ORDER := [Stations.Id.LADUNG, Stations.Id.ZIMMERMANN, Stations.Id.RUDER, Stations.Id.SEGEL, Stations.Id.STEUER]

var ship: ShipSprite
var crew: Array[CrewMember] = []
var reserve: Array[CrewMember] = []  # Männer unter Deck: arbeiten nicht, erholen sich, kommen im Hafen, im Lager und am Etappenanfang an Deck
var relief := true  # Wachablösung an: Müde werden vor der Fahrt automatisch abgelöst, siehe _auto_relief()
var slot_owner: Array = []  # CrewMember oder null, Länge = Stations.SLOTS.size()
var selected: CrewMember = null

var phase := Phase.PLAN
var map: Array = []  # Spalten 0..MILES; jede Spalte ein Array von Knoten {"sea","hazard","enc","links"}
var mile := 0  # Spalte, in der das Schiff liegt (oder zuletzt lag)
var pos := 0  # Knoten in dieser Spalte
var route := -1  # gewählter Knoten in der nächsten Spalte; liegt das Schiff zwischen Knoten, ist er festgelegt
var leg := 0.0  # Fortschritt auf dem Weg zu diesem Knoten (0 bis unter 1): das Schiff kann zwischen zwei Knoten liegen
var hull := 100.0  # Rumpfzustand; bei 0 sinkt das Schiff
var proviant := START_PROVIANT
var loot := 100.0
var powder := 0  # Schießpulver für die Kanonen
var stage := 1  # Etappe; mit jeder wird die See härter
var theme := 0  # Thema der Etappe (Voyage.THEMES): 0 Nordsee, 1 Nebelmeer, 2 Sturmfront, 3 Piratengewässer, 4 Totensee
var total_miles := 0.0  # insgesamt gefahrene Strecke
var level := 1  # Stufe der Fahrt (Ruhm): bei jedem Aufstieg ein Segen
var xp := 0
var perks: Array = []  # gewählte Segen (Perks)
var perk_offer: Array = []  # drei Segen zur Wahl; leer, wenn gerade nichts ansteht
var items: Dictionary = {}  # Platz (Items.SLOT_NAMES) -> Gegenstand-Id
var shop: Array = []  # Angebot im Hafen: Gegenstand-Ids
var stash: Array = []  # Vorrat an Ausrüstung für die Männer (Schlüssel, höchstens Gear.STASH_MAX)
var gear_shop: Array = []  # Rüstkammer im Hafen: Angebot an Ausrüstung
var shop_open := false  # Werft im Hafen ist aufgeschlagen
var max_stage := 0  # nur für Tests und Bots: nach dieser Etappe geht man in Rente (0 = endlos)
var sail_set := 1  # Manöver: Segel 0 eingeholt, 1 gerefft, 2 voll
var oars_set := 1  # Ruder 0 ruht, 1 ruhig, 2 kräftig
var coast_set := 1  # Küste 0 nah, 1 mittel, 2 weit (Segel und Ruder beide aus: Beidrehen)
var turns := 0
var ended := false
var victory := false
var cause := ""
var fallen: Array[CrewMember] = []
var rescued_count := 0
var encounters_done := 0
var log_enabled := false
var history: Array = []  # {"text", "kind"}

# Darstellung
var storm := 0.2  # 0..1 für Wellen und Regen
var sea_view := 1
var impact := 0.0
var sail_visual := 1.0
var traveling := false
var rowing_now := false
var row_phase := 0.0
var rope_from: CrewMember = null
var rope_to: CrewMember = null

# Rettungsentscheidung
var swimmer: CrewMember = null
var rescuer: CrewMember = null

# Begegnung
var encounter := -1
var battle: Dictionary = {}  # Seeschlacht: {"ehull", "ecrew", "round", "intent"}, leer außerhalb
var bonds: Array = []  # Beziehungen: {"a": id, "b": id, "type": Bond}
var recruit: Dictionary = {}  # erster Anwärter im Hafen (für Tests und Kurzformen)
var recruits: Array = []  # drei Anwärter in der Taverne: {"name", "kraft", "stress", "traits", "price"}
var crew_requested := false  # "Anheuern" im Hafen: Main öffnet die Mannschaftsansicht
var camping := false  # Lager aufgeschlagen (Lageransicht), siehe camp_*()
var combat: Combat = null  # Deckkampf, solange phase == COMBAT und die Aufstellung bestätigt ist
var combat_ctx: Dictionary = {}
var fight_prep: Dictionary = {}  # Aufstellung vor dem Kampf: formation, units, party, pool, ctx
var auto_combat := false  # Kämpfe ohne Ansicht auflösen (Bots, Tests, Einstellung "schnell")
var _combat_t := 0.0
var stage_t := 0.0  # Sekunden, die die Kampfregie noch braucht: der Gegnerzug und das Ende warten darauf (nur Anzeige)
var combat_outro := 0.0  # Sekunden Schlussansage nach einem Deckkampf (nur im echten Spiel, sonst 0)
var _outro_t := -1.0
const COMBAT_PACE := 0.9  # Sekunden zwischen den Zügen im Deckkampf: so lange laufen Hiebe, Pfeile und Zahlen
var camps_used := 0  # Lager in dieser Etappe
var camp_points := 0  # Lagerpunkte, die im aufgeschlagenen Lager noch übrig sind
var camp_done: Dictionary = {}  # Aktion -> wie oft im laufenden Lager genutzt
var camp_slept := false
var camp_watch: CrewMember = null  # wer Wache hält
var camp_sight := 0  # +1 Meile Sicht für den Rest der Etappe (Karten lesen)
var _next_id := 100  # Nummern für Männer, die nach dem Start dazukommen
var _food_acc := 0.0  # Bruchteile des Zusatzproviants für die Männer über sieben (je einer: ein halber)
var harbor_used: Array = []  # Optionen, die man pro Hafenbesuch nur einmal nehmen kann (nach Name)

# Spielautomaten (Regeln: scripts/slots.gd, Anzeige: scripts/slot_view.gd)
const SLOT_HARBOR_SPINS := 10  # bezahlte Drehs je Hafenbesuch
const LOKI_ROUNDS := 3  # Runden an Adlerssons Automat
const LOKI_CAP := 3000  # mehr zahlt Adlersson auf einmal nie
var automat_open := false  # ein Automat ist aufgestellt (Anzeige liegt über allem, Schritte warten)
var automat_kind := ""  # "harbor" (Spelunke), "bonus" (Freidreh nach einem Sieg), "loki" (Adlerssons Spielschiff)
var automat: Slots = null
var automat_bet_i := 0  # gewählte Einsatzstufe der Nornenwalzen
var automat_unbanked := 0  # Gewinn, der noch auf die Beute kommt (die Anzeige zählt ihn hoch)
var automat_last: Dictionary = {}  # Ergebnis des letzten Drehs
var automat_spent := 0  # in dieser Sitzung gesetzt
var automat_won := 0  # in dieser Sitzung gutgeschrieben
var automat_seq := 0  # Gewinn der laufenden Folge (Dreh samt Freispielen)
var automat_seq_jackpot := false
var automat_due: Dictionary = {}  # Belohnungen (Segen, Fund), die beim Gutschreiben fällig werden
var automat_token := false  # der Freidreh nach dem Sieg ist noch nicht gespielt
var automat_done := false  # Freidreh ist gespielt und gutgeschrieben
var automat_bonus_on := false  # Main schaltet die Freidrehs nach Siegen ein; ohne bleiben Tests und Hilfsläufe unberührt
var loki_stake := "loot"  # "loot", "hull" oder "man"
var loki_man: CrewMember = null
var loki_round := 0
var loki_pot := 0  # Gewinn, über den noch entschieden wird (kassieren oder Risiko)
var loki_ladder := 0
var loki_reward: Dictionary = {}
var pfand := 0  # Pfandflaschen (legendärer Schlüsselgegenstand, siehe Items.PFAND_NAME): je eine für ein sicheres Freispiel bei Adlersson
var _harbor_spins := 0
var fallen_names: Array[String] = []  # Namen aller Gefallenen, auch wenn ihr Platz neu besetzt wurde
var start_names: Array[String] = []
var death_causes: Dictionary = {}  # Name -> Todesursache für den Gedenkstein
var saga_events: Array = []  # {"type", "name", "extra"}, daraus schreibt der Skalde die Saga
var saga_text := ""
var autosave := false  # nur im echten Spiel: Fahrt nach jeder Meile speichern, Gedenkstein führen

var _pending: Array[CrewMember] = []
var _steps: Array = []
var _step_left := 0.0
var _plan: Dictionary = {}
var _maneuver: Dictionary = {}  # das Manöver der laufenden Fahrt (Regler sind dann gesperrt)
var _perk_pending := 0  # Stufenaufstiege, für die noch ein Segen gewählt werden muss
var _mods: Dictionary = {}  # Zwischenspeicher für ship_mods()
var _roll_ok := false
var _turn_damage := 0.0  # Rumpfschaden dieser Fahrt
var _enc_pending := -1
var _leaving := false
var _hired_name := ""
var _storm_noted := false


static func signed(v: int) -> String:
	return "+%d" % v if v >= 0 else "−%d" % -v


## Meilen mit Komma, auf eine Stelle gerundet: "1,4".
static func fmt(v: float) -> String:
	return String.num(snappedf(v, 0.1), 1).replace(".", ",")


func begin() -> void:
	var names := CREW_NAMES.duplicate()
	names.shuffle()
	var start_roles := Roles.starting_roles(Stations.SLOTS.size())
	slot_owner.resize(Stations.SLOTS.size())
	for i in Stations.SLOTS.size():
		var m := CrewMember.new()
		m.id = i
		m.display_name = names[i]
		m.look = i
		m.role = start_roles[i]
		m.slot = i
		m.stress = randf_range(0.0, 12.0)
		m.traits = Traits.random_set()
		crew.append(m)
		slot_owner[i] = m
		start_names.append(m.display_name)
	_make_bonds()
	_make_map()
	if autosave:
		_apply_legacy()
	hull = hull_max()
	sea_view = current_sea()
	storm = _storm_for(sea_view)
	_lore("start")
	_start_plan()


# --- Vermächtnis: was der Gedenkstein den nächsten Fahrten mitgibt ------------------

## Aus den Sagas früherer Fahrten (Persist.load_memorial()): weiteste Etappe und Zahl der Gefallenen bringen kleine,
## dauerhafte Vorteile für den Start jeder neuen Fahrt. Für die Anzeige im Menü und für den Start.
static func legacy_for(mem: Dictionary) -> Dictionary:
	var tot := Persist.totals(mem)
	var best := int(tot["best"])
	var fallen := int(tot["fallen"])
	var out := {"best": best, "fallen": fallen, "loot": 0, "proviant": 0, "item": "", "perk": "", "veterans": 0, "lines": []}
	var lines: Array = out["lines"]
	if best >= 3:
		out["loot"] = 50
		lines.append("Beute +50 (Etappe 3 erreicht)")
	if best >= 4:
		out["proviant"] = 2
		lines.append("Proviant +2 (Etappe 4)")
	if best >= 5:
		out["item"] = "teer"
		lines.append("Teerung im Rumpf (Etappe 5)")
	if best >= 7:
		out["perk"] = "odin"
		lines.append("Odins Gunst (Etappe 7)")
	var vets := mini(floori(fallen / 8.0), 3)
	if vets > 0:
		out["veterans"] = vets
		lines.append("%d Veteran%s: zäh und stark (%d Gefallene)" % [vets, "en" if vets > 1 else "", fallen])
	return out


func _apply_legacy() -> void:
	var leg := legacy_for(Persist.load_memorial())
	loot += float(leg["loot"])
	proviant += int(leg["proviant"])
	if String(leg["item"]) != "":
		equip(String(leg["item"]))
	if String(leg["perk"]) != "":
		perks.append(String(leg["perk"]))
		_mods = {}
	var pool: Array[CrewMember] = crew.duplicate()
	pool.shuffle()
	for k in mini(int(leg["veterans"]), pool.size()):
		pool[k].traits = Traits.typed([Traits.Id.STARK, Traits.Id.ZAEH])
		pool[k].stress = 0.0
	if not (leg["lines"] as Array).is_empty():
		_fact("Das Vermächtnis der Ahnen begleitet euch: %s." % ", ".join(PackedStringArray(leg["lines"])), Kind.GOOD)

# --- Beziehungen --------------------------------------------------------------
# Brüder beruhigen einander, wenn sie nebeneinander stehen, und trauern um den anderen.
# Rivalen reizen einander nebeneinander und atmen heimlich auf, wenn der andere fehlt.

func _make_bonds() -> void:
	bonds.clear()
	var ids: Array[int] = []
	for m in crew:
		ids.append(m.id)
	ids.shuffle()
	bonds.append({"a": ids[0], "b": ids[1], "type": Bond.BROTHER})
	if randf() < 0.7:
		bonds.append({"a": ids[2], "b": ids[3], "type": Bond.RIVAL})
	if randf() < 0.3:
		bonds.append({"a": ids[4], "b": ids[5], "type": Bond.BROTHER})


func member_by_id(id: int) -> CrewMember:
	for m in crew:
		if m.id == id:
			return m
	for m in reserve:
		if m.id == id:
			return m
	return null


## Beziehungen eines Mannes: [{"other": CrewMember, "type": Bond}]
func bond_partners(m: CrewMember) -> Array:
	var out: Array = []
	for bd in bonds:
		var other: CrewMember = null
		if int(bd["a"]) == m.id:
			other = member_by_id(int(bd["b"]))
		elif int(bd["b"]) == m.id:
			other = member_by_id(int(bd["a"]))
		if other != null:
			out.append({"other": other, "type": int(bd["type"])})
	return out


func are_adjacent(a: CrewMember, b: CrewMember) -> bool:
	return a.slot >= 0 and b.slot >= 0 and absi(a.slot - b.slot) == 1


func is_brother_of(a: CrewMember, b: CrewMember) -> bool:
	for p in bond_partners(a):
		if p["other"] == b and int(p["type"]) == Bond.BROTHER:
			return true
	return false


## Zuschlag auf die Rettungsaussicht, wenn Retter und Ertrinkender verbunden sind.
func rescue_bond_bonus(a: CrewMember, b: CrewMember) -> float:
	for p in bond_partners(a):
		if p["other"] == b:
			if int(p["type"]) == Bond.BROTHER:
				return 0.15
			if int(p["type"]) == Bond.COMRADE:
				return 0.08
	return 0.0


static func bond_name(type: int) -> String:
	return ["Bruder", "Rivale", "Gefährte"][clampi(type, 0, 2)]


static func bond_text(type: int, gone: bool) -> String:
	match type:
		Bond.BROTHER:
			return "Die Lücke bleibt." if gone else "Nebeneinander ruhiger; fällt einer, trauert der andere."
		Bond.RIVAL:
			return "Ein Grund weniger zu streiten." if gone else "Nebeneinander gereizt; fällt einer, atmet der andere auf."
	return "Die Lücke bleibt." if gone else "Seit der Rettung ein Paar: nebeneinander etwas ruhiger."


## Wer gerettet wird und wer rettet, wenn beide noch keine Bindung haben: sie werden Gefährten.
func _form_bond(a: CrewMember, b: CrewMember) -> void:
	if not bond_partners(a).is_empty() or not bond_partners(b).is_empty():
		return
	bonds.append({"a": a.id, "b": b.id, "type": Bond.COMRADE})
	_fact("Zwischen %s und %s entsteht ein Band (Gefährten)." % [a.display_name, b.display_name], Kind.GOOD)
	_lore("comrade_new", a.display_name, b.display_name)
	_note("comrade_new", a.display_name, -1, b.display_name)


## Tod eines Mannes: Brüder trauern, Rivalen atmen auf.
func _mourn(m: CrewMember) -> void:
	for p in bond_partners(m):
		var other: CrewMember = p["other"]
		if other.state != CrewMember.State.ABOARD and other.state != CrewMember.State.RESERVE:
			continue
		if int(p["type"]) == Bond.COMRADE:
			_add_stress(other, 15.0)
			_fact("%s trauert um seinen Gefährten %s (Mut −15)." % [other.display_name, m.display_name], Kind.BAD)
			_lore("brother_mourn", other.display_name, m.display_name)
		elif int(p["type"]) == Bond.BROTHER:
			_add_stress(other, 30.0)
			_fact("%s trauert um seinen Bruder %s (Mut −30)." % [other.display_name, m.display_name], Kind.BAD)
			_lore("brother_mourn", other.display_name, m.display_name)
			_note("brother_lost", other.display_name, -1, m.display_name)
		else:
			other.stress = maxf(other.stress - 10.0, 0.0)
			_lore("rival_relief", other.display_name, m.display_name)


## Wirkung nebeneinander stehender Paare, einmal pro Fahrt.
func _bond_effects() -> void:
	for bd in bonds:
		var a := member_by_id(int(bd["a"]))
		var b := member_by_id(int(bd["b"]))
		if a == null or b == null or a.state != CrewMember.State.ABOARD or b.state != CrewMember.State.ABOARD or not are_adjacent(a, b):
			continue
		if int(bd["type"]) != Bond.RIVAL:
			var calm := 3.0 if int(bd["type"]) == Bond.BROTHER else 2.0
			a.stress = maxf(a.stress - calm, 0.0)
			b.stress = maxf(b.stress - calm, 0.0)
		else:
			_add_stress(a, 2.0)
			_add_stress(b, 2.0)
			if randf() < 0.15:
				a.kraft = maxf(a.kraft - 10.0, 0.0)
				b.kraft = maxf(b.kraft - 10.0, 0.0)
				_add_stress(a, 6.0)
				_add_stress(b, 6.0)
				_fact("%s und %s geraten aneinander (Kraft −10)." % [a.display_name, b.display_name], Kind.BAD)
				_lore("rival_fight", a.display_name, b.display_name)


# --- Seekarte ---------------------------------------------------------------

func _new_node(sea: int, hazard: int, enc: int) -> Dictionary:
	return {"sea": sea, "hazard": hazard, "enc": enc, "links": [], "cove": false}


## Die Karte einer Etappe: Start (der Hafen davor), zehn Spalten, am Ende der nächste Hafen.
func _make_map() -> void:
	map.clear()
	camps_used = 0
	camp_sight = 0
	map.append([_new_node(1, Sea.Hazard.NONE, -1)])  # Start
	for c in range(1, MILES):
		var col: Array = []
		for i in (3 if randf() < 0.6 else 2):  # meist drei Knoten nebeneinander: mehr Wege zur Wahl
			col.append(_random_node(c))
		map.append(col)
	map.append([_new_node(1, Sea.Hazard.NONE, Encounters.Id.HAFEN)])  # Hafen: das Ziel der Etappe
	_link_columns()
	(map[0][0] as Dictionary)["visited"] = true
	_differentiate_forks()
	# Mindestens drei Begegnungen auf der Karte, auf späteren Etappen eine mehr
	var count := 0
	for c in range(2, MILES - 1):
		for nd in map[c]:
			if int(nd["enc"]) >= 0:
				count += 1
	var want := 3 + mini(floori((stage - 1) / 3.0), 2)
	var guard := 0
	while count < want and guard < 50:
		guard += 1
		var c := randi_range(2, MILES - 2)
		var nd: Dictionary = map[c][randi() % map[c].size()]
		if int(nd["enc"]) < 0:
			nd["enc"] = Encounters.random_type(stage, theme)
			count += 1
	# Ein sicherer Hafen in der Mitte (auf der ersten Etappe immer, später meistens)
	if stage == 1 or randf() < 0.6:
		_place_harbor(randi_range(4, 6))
	_place_coves()
	_place_route_events()


## Ereignisse auf der Strecke (wie die Gänge in Darkest Dungeon): auf einigen Wegen zwischen zwei Knoten liegt etwas, an dem das
## Schiff mitten auf der Strecke anhält. Gespeichert am Startknoten des Weges: "mid" = [{"to": Knoten der nächsten Spalte,
## "id": Encounters-Id, "t": Lage auf dem Weg (0..1), "done": schon erlebt}]. Höchstens eines je Startknoten (die Karte bleibt lesbar),
## nicht auf dem ersten Weg hinter dem Hafen und nicht auf dem Weg in den Zielhafen.
func _place_route_events() -> void:
	var want := 3 + mini(floori((stage - 1) / 2.0), 3) + (1 if theme == 1 or theme == 4 else 0)
	var edges: Array = []
	for c in range(1, MILES - 1):
		for i in (map[c] as Array).size():
			for j in ((map[c][i] as Dictionary)["links"] as Array):
				edges.append([c, i, int(j)])
	edges.shuffle()
	var placed := 0
	for e in edges:
		if placed >= want:
			break
		var nd: Dictionary = map[int(e[0])][int(e[1])]
		if not (nd.get("mid", []) as Array).is_empty():
			continue
		nd["mid"] = [{"to": int(e[2]), "id": Encounters.random_route_type(stage, theme), "t": snappedf(randf_range(0.3, 0.7), 0.05), "done": false}]
		placed += 1


## Das noch offene Ereignis auf dem Weg von (col, i) nach (col + 1, j); leer, wenn dort nichts (mehr) liegt.
func route_event(col: int, i: int, j: int) -> Dictionary:
	if col < 0 or col >= MILES or i < 0 or i >= (map[col] as Array).size():
		return {}
	for ev in (node_at(col, i).get("mid", []) as Array):
		if int(ev["to"]) == j and not bool(ev.get("done", false)):
			return ev
	return {}


## Weiß man, was auf den Wegen ab dieser Spalte liegt? Auf den Wegen vom eigenen Knoten aus ja (mit Karte aus dem Lager oder der
## Flaschenpost eine Meile weiter), weiter voraus sieht man nur, dass dort etwas liegt.
func route_event_known(col: int) -> bool:
	return col <= mile + camp_sight


## Wie riskant ein Knoten ist: Seegang, Gefahr, Kampfbegegnung.
func _node_risk(nd: Dictionary) -> int:
	var r := int(nd["sea"])
	if int(nd["hazard"]) != Sea.Hazard.NONE:
		r += 2
	if Encounters.is_battle(int(nd["enc"])):
		r += 2
	return r


## An jeder Gabelung soll es eine echte Wahl geben: ein ruhiger, sicherer Weg gegen einen riskanteren, der dafür
## eine Begegnung (Beute!) bietet. Sehen beide Wege gleich aus, wird einer ruhiger und der andere kühner gemacht.
func _differentiate_forks() -> void:
	var budget := 4 + stage  # so viele zusätzliche Begegnungen darf das auf der Karte schaffen
	for c in range(0, MILES - 1):
		for nd in map[c]:
			var links: Array = nd["links"]
			if links.size() < 2:
				continue
			var targets: Array = []
			for j in links:
				targets.append(map[c + 1][int(j)])
			var lo: Dictionary = targets[0]
			var hi: Dictionary = targets[0]
			for tg in targets:
				if _node_risk(tg) < _node_risk(lo):
					lo = tg
				if _node_risk(tg) > _node_risk(hi):
					hi = tg
			if _node_risk(hi) - _node_risk(lo) >= 2 or (int(lo["enc"]) >= 0) != (int(hi["enc"]) >= 0):
				continue  # schon eine echte Wahl
			if lo == hi:
				lo = targets[0]
				hi = targets[targets.size() - 1]
			if int(lo["enc"]) != Encounters.Id.HAFEN:  # der sichere Weg: ruhigere See, keine Gefahr, keine Begegnung
				lo["hazard"] = Sea.Hazard.NONE
				lo["sea"] = maxi(int(lo["sea"]) - 1, 1)
				lo["enc"] = -1
			if int(hi["enc"]) == Encounters.Id.HAFEN:
				continue
			if int(hi["enc"]) < 0 and c + 1 >= 2 and c + 1 <= MILES - 2 and budget > 0:  # der kühne Weg: eine Begegnung
				hi["enc"] = Encounters.random_type(stage, theme)
				budget -= 1
			if int(hi["hazard"]) == Sea.Hazard.NONE and c + 1 <= MILES - 2:
				var options: Array[int] = [Sea.Hazard.BOE, Sea.Hazard.RIFF, Sea.Hazard.NEBEL]
				if int(hi["sea"]) >= 3:
					options.append(Sea.Hazard.BRECHER)
				hi["hazard"] = options[randi() % options.size()]
			hi["sea"] = mini(int(hi["sea"]) + 1, 5)


## Jede Etappe nach der ersten hat ein Thema, nie zweimal dasselbe hintereinander.
func _pick_theme() -> void:
	var old := theme
	while theme == old:
		theme = randi_range(1, THEMES.size() - 1)


## Wie viel härter ist die See auf dieser Etappe? Faktor auf Seegangs- und Gefahrenschaden.
func stage_mul() -> float:
	return 1.0 + STAGE_HARDNESS * float(stage - 1)


## Ankerbuchten: ruhige Knoten ohne Gefahr und Begegnung, in denen man sicher lagern kann.
func _place_coves() -> void:
	var want := 1 + (1 if stage >= 2 and randf() < 0.6 else 0)
	var tries := 0
	while want > 0 and tries < 40:
		tries += 1
		var c := randi_range(2, MILES - 2)
		var nd: Dictionary = map[c][randi() % (map[c] as Array).size()]
		if int(nd["enc"]) >= 0 or bool(nd.get("cove", false)):
			continue
		nd["cove"] = true
		nd["hazard"] = Sea.Hazard.NONE
		nd["sea"] = mini(int(nd["sea"]), 2)
		want -= 1


func _place_harbor(c: int) -> void:
	var nd: Dictionary = map[c][randi() % (map[c] as Array).size()]
	nd["enc"] = Encounters.Id.HAFEN
	nd["hazard"] = Sea.Hazard.NONE
	nd["sea"] = mini(int(nd["sea"]), 2)  # Hafeneinfahrten sind geschützt


func _random_node(c: int) -> Dictionary:
	# Mit den Etappen steigt der Seegang: nach zwei Etappen ein Grad, nach vier zwei
	var shift := mini(floori((stage - 1) / 2.0), 2) + (1 if theme == 2 else 0)
	var sea := clampi(int(SEA_PROFILE[c]) + randi_range(-1, 1) + shift, 1, 5)
	var hazard: int = Sea.Hazard.NONE
	if c <= MILES - 2 and randf() < minf(0.6 + 0.04 * float(stage - 1) + (0.12 if theme == 1 else 0.0), 0.92):
		var options: Array[int] = [Sea.Hazard.BOE, Sea.Hazard.RIFF, Sea.Hazard.NEBEL]
		if sea >= 3:
			options.append(Sea.Hazard.BRECHER)
			options.append(Sea.Hazard.BRECHER)
		if theme == 1:
			options.append_array([Sea.Hazard.NEBEL, Sea.Hazard.NEBEL, Sea.Hazard.NEBEL])
		elif theme == 2:
			options.append_array([Sea.Hazard.BOE, Sea.Hazard.BRECHER])
		hazard = options[randi() % options.size()]
	var enc := -1
	if c >= 2 and c <= MILES - 2 and randf() < 0.38:
		enc = Encounters.random_type(stage, theme)
	return _new_node(sea, hazard, enc)


## Verbindet jede Spalte mit der nächsten: jeder Knoten hat 1-2 Ausgänge, jeder Knoten ist erreichbar.
func _link_columns() -> void:
	for c in MILES:
		var a: Array = map[c]
		var b: Array = map[c + 1]
		var incoming: Array[bool] = []
		incoming.resize(b.size())
		incoming.fill(false)
		for i in a.size():
			var links: Array[int] = []
			if a.size() == 1:
				for j in b.size():
					links.append(j)
			elif b.size() == 1:
				links.append(0)
			else:
				var j := roundi(float(i) * float(b.size() - 1) / float(a.size() - 1))
				links.append(j)
				if randf() < 0.75:  # oft ein zweiter Weg: Gabelungen sind der Ort der Kurswahl
					var k := j + (1 if randf() < 0.5 else -1)
					if k >= 0 and k < b.size() and not links.has(k):
						links.append(k)
			for j in links:
				incoming[j] = true
			(a[i] as Dictionary)["links"] = links
		for j in b.size():
			if incoming[j]:
				continue
			var best := 0
			var best_d := 1.0e9
			for i in a.size():
				var center := float(i) * float(b.size() - 1) / maxf(float(a.size() - 1), 1.0)
				if absf(center - j) < best_d:
					best_d = absf(center - j)
					best = i
			var links2: Array = (a[best] as Dictionary)["links"]
			links2.append(j)
			links2.sort()
		_ensure_fork(a, b)


## Zwischen zwei Spalten mit mehreren Knoten gibt es mindestens eine Gabelung, damit man den Kurs ändern kann.
func _ensure_fork(a: Array, b: Array) -> void:
	if a.size() < 2 or b.size() < 2:
		return
	for nd in a:
		if (nd["links"] as Array).size() > 1:
			return
	var nd2: Dictionary = a[randi() % a.size()]
	var links: Array = nd2["links"]
	var j := int(links[0])
	var k := j + (1 if j + 1 < b.size() else -1)
	if not links.has(k):
		links.append(k)
		links.sort()

func here() -> Dictionary:
	return map[mile][pos]


func node_at(col: int, i: int) -> Dictionary:
	return map[col][i]


func current_sea() -> int:
	return int(here()["sea"])


func next_links() -> Array:
	if mile >= MILES:
		return []
	return here()["links"]


## Bis zu welcher Spalte kennt man die Knoten? Im Nebel nur die nächste.
func visible_cols() -> int:
	return mile + (1 if int(here()["hazard"]) == Sea.Hazard.NEBEL else VISIBLE_AHEAD + int(stat("visible")) + camp_sight - (1 if theme == 1 else 0))


## Meilen bis zum nächsten Hafen; der Hafen am Ende der Etappe liegt immer voraus.
func harbor_distance() -> float:
	# nur Häfen, die über die Wege der Karte erreichbar sind (kein Hafen auf dem anderen Ast einer Gabelung)
	var reach: Array = []
	var c := mile
	if leg > 0.0 and route >= 0 and mile < MILES:
		c = mile + 1
		reach = [route]
	else:
		reach = [pos]
		c = mile
	while c < MILES:
		var nxt: Array = []
		for i in reach:
			for t in (node_at(c, int(i))["links"] as Array):
				if not nxt.has(int(t)):
					nxt.append(int(t))
		c += 1
		for i in nxt:
			if int(node_at(c, int(i))["enc"]) == Encounters.Id.HAFEN:
				return float(c - mile) - leg
		reach = nxt
		if reach.is_empty():
			break
	return float(MILES - mile) - leg


## Seegang an der Stelle des Schiffes: liegt es zwischen Knoten, ist es der des Knotens, auf den es zufährt.
func location_sea() -> int:
	if leg > 0.0 and route >= 0 and mile < MILES:
		return int(node_at(mile + 1, route)["sea"])
	return current_sea()


# --- Schiffswerte: Gegenstände und Segen ------------------------------------------

## Alle Schiffswerte (Items.BASE) mit Gegenständen und Segen eingerechnet.
func ship_mods() -> Dictionary:
	if not _mods.is_empty():
		return _mods
	var m: Dictionary = Items.BASE.duplicate()
	var sources: Array = []
	for slot in items:
		sources.append(Items.mods_of(String(items[slot])))
	for id in perks:
		sources.append(Perks.DATA[String(id)]["mods"])
	for src in sources:
		for key in src:
			if Items.ADDITIVE.has(key):
				m[key] = float(m[key]) + float(src[key])
			else:
				m[key] = float(m[key]) * float(src[key])
	_mods = m
	return m


func stat(key: String) -> float:
	return float(ship_mods()[key])


func hull_max() -> float:
	return stat("hull_max")


func cannons() -> int:
	return roundi(stat("cannons"))


func _mods_changed() -> void:
	_mods = {}
	hull = minf(hull, hull_max())
	proviant = mini(proviant, roundi(stat("proviant_max")))
	powder = mini(powder, roundi(stat("powder_max")))


# --- Erfahrung, Stufen, Segen ---------------------------------------------------------

func xp_needed() -> int:
	return 60 + 40 * level


func gain_xp(n: int) -> void:
	xp += n
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		_perk_pending += 1
		Sfx.play("bell")
		_fact("Stufe %d erreicht! Die Götter bieten einen Segen an." % level, Kind.GOOD)
		_lore("level_up", str(level))
	_offer_perk()


func _offer_perk() -> void:
	if _perk_pending > 0 and perk_offer.is_empty():
		perk_offer = Perks.offer(perks)
		if perk_offer.is_empty():
			_perk_pending = 0


## Segen wählen (Index in perk_offer). Wirkt sofort und dauerhaft.
func choose_perk(i: int) -> void:
	if i < 0 or i >= perk_offer.size():
		return
	var id := String(perk_offer[i])
	perks.append(id)
	perk_offer = []
	_perk_pending = maxi(_perk_pending - 1, 0)
	var p: Dictionary = Perks.DATA[id]
	_mods_changed()
	var now: Dictionary = p["now"]
	if now.has("hull"):
		hull = minf(hull + float(now["hull"]), hull_max())
	if now.has("powder"):
		powder = mini(powder + int(now["powder"]), roundi(stat("powder_max")))
	var fx := now.duplicate()
	fx.erase("hull")
	fx.erase("powder")
	if fx.has("loot"):  # der Glückspfennig gibt genau, was auf der Karte steht (ohne Zuschläge)
		loot += float(fx["loot"])
		fx.erase("loot")
	_apply_fx(fx)
	Sfx.play("coin")
	_fact("Segen: %s." % String(p["name"]), Kind.GOOD)
	_offer_perk()


# --- Gegenstände ---------------------------------------------------------------

## Gegenstand einbauen; er ersetzt, was auf dem passenden Platz saß (Kanonen: erst ein freier Platz, sonst der erste).
func equip(id: String) -> void:
	var slots := Items.slots_for(id)
	var target: int = slots[0]
	for s in slots:
		if not items.has(s):
			target = s
			break
	items[target] = id
	_mods_changed()


## Aus dem Angebot im Hafen kaufen. Gibt zurück, ob es geklappt hat.
func buy_offer(i: int) -> bool:
	if not shop_open or i < 0 or i >= shop.size():
		return false
	var id := String(shop[i])
	var price := Items.price_at(id, stage)
	if loot < float(price):
		return false
	loot -= float(price)
	equip(id)
	shop.remove_at(i)
	Sfx.play("coin")
	_fact("Gekauft: %s, %s (Beute −%d)." % [Items.name_of(id), Items.rarity_name(id), price], Kind.GOOD)
	return true


func repair_price() -> int:
	return roundi(20.0 * stage_mul())


## In der Werft: 25 Rumpf für Beute.
func buy_repair() -> bool:
	if not shop_open or hull >= hull_max() - 0.5 or loot < float(repair_price()):
		return false
	loot -= float(repair_price())
	hull = minf(hull + 25.0, hull_max())
	Sfx.play("hammer")
	_fact("Werft: Rumpf +25 (Beute −%d)." % repair_price(), Kind.GOOD)
	return true


func powder_price() -> int:
	return roundi(15.0 * stage_mul())


## Vier Fässer Schießpulver für Beute (nur mit Kanonen sinnvoll).
func buy_powder() -> bool:
	if not shop_open or cannons() <= 0 or powder >= roundi(stat("powder_max")) or loot < float(powder_price()):
		return false
	loot -= float(powder_price())
	powder = mini(powder + 4, roundi(stat("powder_max")))
	Sfx.play("coin")
	_fact("Pulver +4 (Beute −%d)." % powder_price(), Kind.GOOD)
	return true


# --- Ausrüstung der Männer: Vorrat, Rüstkammer, Anlegen -----------------------------------

## Wie viele Plätze der Vorrat noch hat.
func stash_free() -> int:
	return Gear.STASH_MAX - stash.size()


## Drei Stücke für die Rüstkammer im Hafen, je eins für Waffe, Rüstung und Amulett.
func _roll_gear_shop() -> Array:
	var slots := [Gear.Slot.WAFFE, Gear.Slot.RUESTUNG, Gear.Slot.AMULETT]
	slots.shuffle()
	var offer: Array = []
	for s in slots:
		offer.append(Gear.roll(stage, 0.0, 0, int(s)))
	return offer


func buy_gear(i: int) -> bool:
	if not shop_open or i < 0 or i >= gear_shop.size() or stash_free() <= 0:
		return false
	var key := String(gear_shop[i])
	var price := Gear.price_at(key, stage)
	if loot < float(price):
		return false
	loot -= float(price)
	gear_shop.remove_at(i)
	stash.append(key)
	Sfx.play("coin")
	_fact("Gekauft: %s, %s (Beute −%d), liegt im Vorrat." % [Gear.name_of(key), Gear.rarity_name(key), price], Kind.GOOD)
	return true


## Ein Stück aus dem Vorrat für die Hälfte seines Preises verkaufen.
func sell_gear(i: int) -> bool:
	if not shop_open or i < 0 or i >= stash.size():
		return false
	var key := String(stash[i])
	var gain := roundi(float(Gear.price_at(key, stage)) * 0.5)
	stash.remove_at(i)
	loot += float(gain)
	Sfx.play("coin")
	_fact("Verkauft: %s (Beute +%d)." % [Gear.name_of(key), gain], Kind.FACT)
	return true


## Ein Mann legt das Stück aus dem Vorrat an; was er auf diesem Platz trug, wandert in den Vorrat.
func equip_gear(m: CrewMember, i: int) -> bool:
	if i < 0 or i >= stash.size() or not forge_men().has(m):
		return false
	var key := String(stash[i])
	var slot := Gear.slot_of(key)
	stash.remove_at(i)
	if m.gear.has(slot):
		stash.append(String(m.gear[slot]))
	m.gear[slot] = key
	Sfx.play("hammer")
	_fact("%s legt an: %s (%s)." % [m.display_name, Gear.name_of(key), Gear.rarity_name(key)], Kind.FACT)
	return true


func unequip_gear(m: CrewMember, slot: int) -> bool:
	if not m.gear.has(slot) or stash_free() <= 0 or not forge_men().has(m):
		return false
	stash.append(String(m.gear[slot]))
	m.gear.erase(slot)
	return true


## Legt alles Bessere an: leere Plätze zuerst, sonst wer das schlechtere Stück trägt. Gibt zurück, wie viel sich geändert hat.
func auto_equip() -> int:
	var changes := 0
	var men := forge_men()
	var improved := true
	while improved:
		improved = false
		for i in stash.size():
			var key := String(stash[i])
			var slot := Gear.slot_of(key)
			var best: CrewMember = null
			var best_gain := 0
			for m in men:
				var cur := Items.rarity_of(String(m.gear[slot])) if m.gear.has(slot) else -1
				var gain := Items.rarity_of(key) - cur
				if gain > best_gain:
					best = m
					best_gain = gain
			if best != null and equip_gear(best, i):
				changes += 1
				improved = true
				break
	return changes


## Ein Fund (Wrack, besiegter Gegner): ein Stück Ausrüstung mit gewürfelter Seltenheit, es kommt in den Vorrat.
## Ist der voll, wird es sofort verkauft.
func _find_gear(minimum: int = 0, luck: float = 1.0, source: String = "Fund") -> void:
	var key := Gear.roll(stage, luck, minimum)
	var label := "%s (%s, %s)" % [Gear.name_of(key), Gear.rarity_name(key), Gear.SLOT_NAMES[Gear.slot_of(key)]]
	Sfx.play("coin")
	if stash.size() < Gear.STASH_MAX:
		stash.append(key)
		_fact("%s: %s, liegt im Vorrat." % [source, label], Kind.GOOD)
	else:
		var gain := roundi(float(Gear.price_at(key, stage)) * 0.5)
		loot += float(gain)
		_fact("%s: %s, aber der Vorrat ist voll. Verkauft für %d Beute." % [source, label, gain], Kind.GOOD)


## Fund einer Pfandflasche (legendär). Mehr als Items.PFAND_MAX trägt man nicht: der Rest wird gegen Pfand eingelöst.
func _find_pfand(source: String = "Fund") -> void:
	Sfx.play("bell")
	if pfand >= Items.PFAND_MAX:
		var gain := 25 + 10 * stage
		loot += float(gain)
		_fact("%s: noch eine Pfandflasche, aber mehr trägt man nicht. Eingelöst für %d Beute." % [source, gain], Kind.GOOD)
		return
	pfand += 1
	_fact("%s: eine Pfandflasche (legendär)! Bei Adlersson gibt sie ein sicheres Freispiel." % source, Kind.GOOD)
	_lore("pfand_found")


## Fällt ein Mann, kehrt seine Ausrüstung in den Vorrat zurück (voll: verkauft).
func _return_gear(m: CrewMember) -> void:
	for slot in m.gear:
		var key := String(m.gear[slot])
		if stash.size() < Gear.STASH_MAX:
			stash.append(key)
		else:
			loot += float(roundi(float(Gear.price_at(key, stage)) * 0.5))
	m.gear.clear()


func close_shop() -> void:
	shop_open = false
	forge_tab = false


# --- Hafen: Schmiede und Kampfschule -------------------------------------------------

const WEAPON_MAX := 4
const ARMOR_MAX := 4
const SKILL_MAX := 3
const WEAPON_PRICES := [70, 140, 230, 340]
const ARMOR_PRICES := [60, 120, 200, 300]
const SKILL_PRICES := [40, 90, 150]
const WEAPON_DMG := 0.08  # je Stufe: mehr Schaden
const ARMOR_PROT := 0.035  # je Stufe: mehr Schutz

var werft_tab := 0  # in der Werft: 0 Gegenstände, 1 Schmiede, 2 Ausrüstung, 3 Rüstkammer
var forge_tab: bool:
	get:
		return werft_tab == 1
	set(v):
		werft_tab = 1 if v else 0


## Alle Männer, die man ausrüsten und ausbilden kann: an Deck und in der Reserve.
func forge_men() -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	for m in crew:
		if m.state == CrewMember.State.ABOARD:
			out.append(m)
	for m in reserve:
		out.append(m)
	return out


## Stufe von Waffe, Rüstung ("weapon", "armor") oder einer Fertigkeit ("skill", sid).
func forge_level(kind: String, m: CrewMember, sid: String = "") -> int:
	match kind:
		"weapon":
			return m.weapon_lvl
		"armor":
			return m.armor_lvl
	return int(m.skill_lvl.get(sid, 0))


func forge_max(kind: String, sid: String = "") -> int:
	match kind:
		"weapon":
			return WEAPON_MAX
		"armor":
			return ARMOR_MAX
	return Roles.max_level(sid)


## Preis der nächsten Stufe in Beute; -1, wenn nichts mehr zu verbessern ist.
func forge_price(kind: String, m: CrewMember, sid: String = "") -> int:
	var lvl := forge_level(kind, m, sid)
	if lvl >= forge_max(kind, sid):
		return -1
	var table: Array = WEAPON_PRICES if kind == "weapon" else (ARMOR_PRICES if kind == "armor" else SKILL_PRICES)
	if kind == "skill" and Roles.max_level(sid) == 1:
		table = [60]
	return roundi(float(table[lvl]) * (1.0 + 0.08 * float(stage - 1)))


func forge_can_buy(kind: String, m: CrewMember, sid: String = "") -> bool:
	var p := forge_price(kind, m, sid)
	return shop_open and p > 0 and loot >= float(p) and forge_men().has(m)


func forge_buy(kind: String, m: CrewMember, sid: String = "") -> bool:
	if not forge_can_buy(kind, m, sid):
		return false
	var p := forge_price(kind, m, sid)
	loot -= float(p)
	var what := ""
	match kind:
		"weapon":
			m.weapon_lvl += 1
			what = "Waffe Stufe %d" % m.weapon_lvl
		"armor":
			m.armor_lvl += 1
			what = "Rüstung Stufe %d" % m.armor_lvl
		_:
			m.skill_lvl[sid] = int(m.skill_lvl.get(sid, 0)) + 1
			what = "%s Stufe %d" % [Roles.skill(sid)["name"], int(m.skill_lvl[sid])]
	Sfx.play("hammer")
	_fact("Schmiede: %s, %s (Beute −%d)." % [m.display_name, what, p], Kind.GOOD)
	return true



## Hat das Schiff diesen Gegenstand (egal in welcher Seltenheit) schon?
func has_item_base(id: String) -> bool:
	for v in items.values():
		if Items.base_id(String(v)) == Items.base_id(id):
			return true
	return false


## Drei Gegenstände im Hafen, jeder mit gewürfelter Seltenheit. Wer noch keine Kanone hat, bekommt ab der zweiten Etappe oft eine angeboten.
func _roll_shop() -> Array:
	var pool: Array = []
	for id in Items.ids():
		if not has_item_base(String(id)):
			pool.append(id)
	pool.shuffle()
	var offer: Array = []
	for id in pool.slice(0, mini(3, pool.size())):
		offer.append(Items.make(String(id), Items.roll_rarity(stage)))
	if cannons() == 0 and stage >= 2 and randf() < 0.6:
		var has_cannon := false
		for key in offer:
			if Items.kind_of(String(key)) == Items.Kind.KANONE:
				has_cannon = true
		if not has_cannon and not offer.is_empty():
			offer[0] = Items.make("kanone" if not has_item_base("kanone") else "schwere", Items.roll_rarity(stage))
	return offer

func node_danger(nd: Dictionary) -> int:
	return int(nd["sea"]) * 2 + (3 if int(nd["hazard"]) != Sea.Hazard.NONE else 0)


## Zweiter Schritt der vollen Fahrt: der Steuermann nimmt den ruhigeren Weg.
func best_successor(col: int, i: int) -> int:
	var links: Array = node_at(col, i)["links"]
	var best := -1
	var best_score := 1000000
	for j in links:
		var s := node_danger(node_at(col + 1, int(j)))
		if s < best_score:
			best_score = s
			best = int(j)
	return best


func select_route(i: int) -> void:
	if phase != Phase.PLAN or leg > 0.0 or not next_links().has(i):
		return  # zwischen zwei Knoten ist der Kurs schon gesetzt
	route = i


func _storm_for(sea: int) -> float:
	return 0.1 + (sea - 1) * 0.2


func _process(delta: float) -> void:
	impact = move_toward(impact, 0.0, delta * 2.5)
	storm = move_toward(storm, _storm_for(sea_view), delta * 0.5)
	sail_visual = move_toward(sail_visual, sail_target(), delta * 0.9)
	if rowing_now:
		row_phase = fposmod(row_phase + delta / 1.1, 1.0)
	_animate_rescue(delta)
	if phase == Phase.COMBAT:
		_tick_combat(delta)
	if phase == Phase.RESOLVE and not _steps.is_empty() and not automat_open:
		_step_left -= delta
		if _step_left <= 0.0:
			var step: Dictionary = _steps.pop_front()
			var fn: Callable = step["fn"]
			fn.call()
			if not _steps.is_empty():
				_step_left = float(_steps[0]["delay"])


func _animate_rescue(delta: float) -> void:
	if rope_to == null or rope_to.state != CrewMember.State.OVERBOARD:
		return
	if _roll_ok:
		rope_to.swim_x = move_toward(rope_to.swim_x, Waves.SHIP_X - 62.0, 55.0 * delta)
	else:
		rope_to.swim_x -= 22.0 * delta


# --- Abfragen ---------------------------------------------------------------

func sail_target() -> float:
	if phase == Phase.RESOLVE and not _maneuver.is_empty():
		return float(_maneuver["sail"])
	return float(maneuver()["sail"])


func alive_count() -> int:
	var n := 0
	for m in crew:
		if m.state != CrewMember.State.DEAD:
			n += 1
	return n


func aboard_count() -> int:
	var n := 0
	for m in crew:
		if m.state == CrewMember.State.ABOARD:
			n += 1
	return n


## Summe der Arbeitsleistung aller Männer an Stationen dieser Art.
func power(station: int) -> float:
	var p := 0.0
	for i in slot_owner.size():
		var m: CrewMember = slot_owner[i]
		if m != null and m.state == CrewMember.State.ABOARD and Stations.slot_station(i) == station:
			p += m.efficiency_at(station)
	return p


func capacity(station: int) -> int:
	var n := 0
	for i in Stations.SLOTS.size():
		if Stations.slot_station(i) == station:
			n += 1
	return n


## Kampfstärke: Durchschnitt der Leistung der vier besten Männer (weniger als vier Männer = schwächer).
func strength() -> float:
	var effs: Array[float] = []
	for m in crew:
		if m.state == CrewMember.State.ABOARD:
			effs.append(m.efficiency() * m.fight_factor())
	for m in reserve:  # frische Männer unter Deck kämpfen mit, ohne dass eine Station fehlt
		effs.append(m.efficiency() * m.fight_factor())
	effs.sort()
	effs.reverse()
	var total := 0.0
	for k in mini(4, effs.size()):
		total += effs[k]
	return total / 4.0


func is_working(station: int) -> bool:
	if phase != Phase.RESOLVE or not traveling or _plan.is_empty():
		return false
	var moving := float(_plan["miles"]) > 0.0
	match station:
		Stations.Id.RUDER:
			return rowing_now
		Stations.Id.SEGEL:
			return moving and absf(sail_visual - sail_target()) > 0.05
		Stations.Id.STEUER:
			return moving
		Stations.Id.ZIMMERMANN:
			return hull < hull_max() - 0.5 or _turn_damage > 0.0
	return false


# --- Planung ----------------------------------------------------------------

## Das Manöver aus den Reglern; mit Zahlen für einen Regler wird er für eine Vorschau ersetzt.
func maneuver(sail: int = -1, oars: int = -1, coast: int = -1) -> Dictionary:
	return Strategy.build(sail_set if sail < 0 else sail, oars_set if oars < 0 else oars, coast_set if coast < 0 else coast, ship_mods())


func needs_ratio(d: Dictionary) -> float:
	var needs: Dictionary = d["needs"]
	var ratio := 1.0
	for st in needs:
		ratio = minf(ratio, clampf(power(int(st)) / float(needs[st]), 0.0, 1.0))
	return ratio


func _repair(d: Dictionary) -> float:
	return REPAIR_PER_MAN * power(Stations.Id.ZIMMERMANN) * float(d["repair"])


func _kraft_cost(m: CrewMember, d: Dictionary, sea: int, had_work: bool = true) -> float:
	var station := Stations.slot_station(m.slot)
	var costs: Dictionary = d["cost"]
	var c := float(costs.get(station, 0))
	if station == Stations.Id.ZIMMERMANN and c > 0.0 and not had_work:
		return -8.0  # nichts zu reparieren: die Zimmerleute ruhen sich aus
	if c > 0.0:
		c += maxf(sea - 2.0, 0.0)  # rauhere See macht müder
		c *= m.cost_factor()
	return c


func _stress_gain(d: Dictionary, sea: int, kraft_after: float) -> float:
	var g := float(d["stress"])
	if g >= 0.0:
		g += maxf(sea - 2.0, 0.0)
	if kraft_after <= 15.0:
		g += 3.0
	if proviant <= 2:
		g += 2.0
	return g


## Bewegt sich das Schiff bei diesem Manöver, braucht es also einen gewählten nächsten Knoten?
func route_missing(d: Dictionary = {}) -> bool:
	if d.is_empty():
		d = maneuver()
	return float(d["miles"]) > 0.0 and route < 0 and mile < MILES


func can_confirm() -> bool:
	var d := maneuver()
	return phase == Phase.PLAN and not camping and perk_offer.is_empty() and can_choose(d) and not route_missing(d)


## Fährt das Schiff `dist` Meilen weiter? Liefert die erreichten Knoten, den Fortschritt auf dem Weg zum nächsten
## und den Kurs dorthin. An einem Knoten mit Begegnung (auch am Hafen am Ende der Etappe) und an jeder Gabelung hält
## es an, der Rest der Strecke verfällt: dort wählt man den Kurs selbst. Führt nur ein Weg weiter, fährt es durch.
func simulate_move(dist: float) -> Dictionary:
	var col := mile
	var ni := pos
	var lg := leg
	var rt := route
	var remaining := dist
	var arrivals: Array = []
	var stop := ""
	var event: Dictionary = {}
	while remaining > 0.001 and col < MILES:
		if rt < 0:
			rt = int(node_at(col, ni)["links"][0])
		var ev := route_event(col, ni, rt)  # ein Ereignis auf diesem Weg hält das Schiff an, der Rest der Strecke verfällt
		if not ev.is_empty() and float(ev["t"]) > lg + 0.001 and remaining >= float(ev["t"]) - lg - 0.001:
			lg = float(ev["t"])
			remaining = 0.0
			stop = "event"
			event = ev
			break
		var need := 1.0 - lg
		if remaining < need - 0.04:
			lg += remaining
			remaining = 0.0
			break
		remaining = maxf(remaining - need, 0.0)
		col += 1
		ni = rt
		lg = 0.0
		arrivals.append([col, ni])
		if col >= MILES or int(node_at(col, ni)["enc"]) >= 0:
			stop = "end" if col >= MILES else "encounter"
			break
		if (node_at(col, ni)["links"] as Array).size() > 1:
			stop = "fork"  # an einer Gabelung hält das Schiff an: den Weg wählt der Spieler
			break
		rt = best_successor(col, ni)
	return {"arrivals": arrivals, "leg": lg, "route": rt if lg > 0.0 else -1, "stop": stop, "col": col, "ni": ni, "event": event}


## Was würde dieses Manöver mit der aktuellen Besatzung auf dem gewählten Kurs bewirken? Wird für die
## Vorschau und für das Auslaufen benutzt, damit beides übereinstimmt. Nur der Zufall (über Bord) ist offen.
## Die Strecke ist der Vortrieb mal der Besetzung der nötigen Stationen; unter 0,3 treibt das Schiff nur.
func plan(d: Dictionary = {}) -> Dictionary:
	if d.is_empty():
		d = maneuver()
	var ratio := needs_ratio(d)
	var want := float(d["miles"])
	var dist := want * ratio
	if dist < 0.3:
		dist = 0.0
	var move := {"arrivals": [], "leg": leg, "route": route, "stop": "", "col": mile, "ni": pos, "event": {}}
	if dist > 0.0:
		move = simulate_move(dist)
	var arrivals: Array = move["arrivals"]
	var lg_end := float(move["leg"])
	var partial := dist > 0.0 and lg_end > 0.0
	var count := arrivals.size() + (1 if partial else 0)
	if count == 0:
		count = 1  # Beidrehen oder Treiben: See an Ort und Stelle
	var hm := stat("hazard") * stage_mul()
	var rows: Array = []
	var strain_sum := 0.0
	var hazard_dmg := 0.0
	var last_sea := location_sea()
	for k in count:
		var kind := "stay"
		var col := mile
		var ni := pos
		var sea := location_sea()
		var weight := 1.0
		if k < arrivals.size():
			var t: Array = arrivals[k]
			kind = "arrive"
			col = int(t[0])
			ni = int(t[1])
			sea = int(node_at(col, ni)["sea"])
		elif partial:
			kind = "partial"
			col = int(move["col"]) + 1
			ni = int(move["route"])
			sea = int(node_at(col, ni)["sea"])
			weight = clampf(lg_end if not arrivals.is_empty() else dist, 0.4, 1.0)
		last_sea = sea
		var row := {
			"kind": kind, "col": col, "ni": ni, "sea": sea, "last": k == count - 1, "weight": weight,
			"strain": float(Sea.STRAIN[sea]) * float(d["strain"]) * stage_mul() * weight,
			"wash": minf(Sea.wash_chance(sea) * float(d["exposure"]) * weight, 0.9),
			"hazard": Sea.Hazard.NONE, "h_dmg": 0.0, "h_over": 0.0, "h_loot": 0.0, "mit": 0.0,
		}
		if kind == "partial" and String(move["stop"]) == "event":
			row["event"] = int((move["event"] as Dictionary)["id"])
		var hz := int(node_at(col, ni)["hazard"])
		if kind == "arrive" and hz != Sea.Hazard.NONE:
			var counter: Dictionary = d["counter"]
			var mit := float(counter.get(hz, 0.0)) * ratio
			var f := clampf(1.0 - mit, 0.0, 2.0)
			var base: Dictionary = Sea.HAZARD[hz]
			row["hazard"] = hz
			row["mit"] = mit
			row["h_dmg"] = float(base["damage"]) * f * hm
			row["h_over"] = minf(float(base["over"]) * f, 0.95)
			row["h_loot"] = float(base["loot"]) * f
			hazard_dmg += float(row["h_dmg"])
		strain_sum += float(row["strain"])
		rows.append(row)
	var repair := _repair(d)
	var damage := strain_sum + hazard_dmg
	var had_work := damage > 0.0 or hull < hull_max()
	var tired: Array[String] = []
	for m in crew:
		if m.state == CrewMember.State.ABOARD and m.kraft - _kraft_cost(m, d, last_sea, had_work) < CrewMember.TIRED_AT:
			tired.append(m.display_name)
	return {
		"d": d, "miles": dist, "want": want, "ratio": ratio, "rows": rows, "arrivals": arrivals,
		"leg_after": lg_end if dist > 0.0 else leg, "route_after": int(move["route"]) if dist > 0.0 else route, "stop": String(move["stop"]),
		"event": move["event"],
		"strain": strain_sum, "hazard_dmg": hazard_dmg, "repair": repair,
		"hull_after": minf(hull - damage + repair, hull_max()),
		"proviant": int(d["proviant"]) + extra_food(), "tired": tired, "last_sea": last_sea,
	}


## Rasten kostet Proviant: ohne genug davon bleibt nur das Weiterfahren.
func can_choose(d: Dictionary) -> bool:
	return float(d["miles"]) > 0.0 or proviant >= int(d["proviant"]) + extra_food()


## Einen Regler verstellen (nur in der Planung). Segel und Ruder beide auf "aus" ist Beidrehen und braucht Proviant.
func set_dial(dial: int, level: int) -> void:
	if phase != Phase.PLAN or dial < 0 or dial > 2 or level < 0 or level > 2:
		return
	var s := sail_set
	var o := oars_set
	var c := coast_set
	match dial:
		0:
			s = level
		1:
			o = level
		2:
			c = level
	if not can_choose(Strategy.build(s, o, c)):
		return
	sail_set = s
	oars_set = o
	coast_set = c


## Vorlage aus Strategy.PRESETS einstellen: für Bots, Tests und Screenshots.
func select_strategy(id: int) -> void:
	if id < 0 or id >= Strategy.PRESETS.size():
		return
	var dials: Array = Strategy.preset(id)
	set_dial(0, int(dials[0]))
	set_dial(1, int(dials[1]))
	set_dial(2, int(dials[2]))


func confirm() -> void:
	if can_confirm():
		_begin_resolve()


## Wachablösung: Wer unter 40 Kraft fällt, wird vor der nächsten Fahrt vom frischesten Mann auf der Ladungsbank
## abgelöst (er muss mindestens 25 Kraft mehr haben). Das ersetzt das Umsetzen von Hand; die Vorschau zeigt schon
## die neue Aufstellung, und man kann den Tausch jederzeit rückgängig machen.
func toggle_relief() -> void:
	relief = not relief
	_fact("Wachablösung %s." % ("an: Müde werden automatisch abgelöst" if relief else "aus: du setzt die Männer selbst um"), Kind.FACT)


func _auto_relief() -> void:
	if not relief or ended:
		return
	_relief_reserve()
	_relief_ladung()


func _relief_ladung() -> void:
	var rester: CrewMember = null
	for m in crew:
		if m.state == CrewMember.State.ABOARD and m.slot >= 0 and Stations.slot_station(m.slot) == Stations.Id.LADUNG:
			if rester == null or m.kraft > rester.kraft:
				rester = m
	if rester == null or rester.kraft < 50.0:
		return
	var tired: CrewMember = null
	for m in crew:
		if m.state == CrewMember.State.ABOARD and m.slot >= 0 and Stations.slot_station(m.slot) != Stations.Id.LADUNG:
			if m.kraft < CrewMember.TIRED_AT and m.kraft + 25.0 <= rester.kraft and (tired == null or m.kraft < tired.kraft):
				tired = m
	if tired == null:
		return
	_fact("Wachablösung: %s (Kraft %d) löst %s (Kraft %d) ab. %s ruht sich aus." % [rester.display_name, roundi(rester.kraft), tired.display_name, roundi(tired.kraft), tired.display_name], Kind.FACT)
	_swap(tired, rester)


func click_crew(m: CrewMember) -> void:
	if phase == Phase.RESCUE:
		if m.state == CrewMember.State.ABOARD:
			rescuer = m
		return
	if not can_arrange() or (m.state != CrewMember.State.ABOARD and m.state != CrewMember.State.RESERVE):
		return
	if selected == null:
		selected = m
	elif selected == m:
		selected = null
	else:
		_swap_any(selected, m)
		selected = null


## Klick auf einen Platz in der Mannschaftsansicht: besetzt = Mann wählen oder tauschen, frei = Mann hinsetzen.
func click_seat(i: int) -> void:
	if i < 0 or i >= slot_owner.size():
		return
	var m: CrewMember = slot_owner[i]
	if m != null:
		click_crew(m)
	else:
		click_slot(i)


func click_slot(i: int) -> void:
	if not can_arrange() or selected == null or slot_owner[i] != null:
		return
	if selected.state == CrewMember.State.RESERVE:  # ein Reservist setzt sich auf einen freien Platz
		if can_use_reserve():
			_reserve_to_seat(selected, i)
		selected = null
		return
	slot_owner[selected.slot] = null
	slot_owner[i] = selected
	selected.slot = i
	selected = null


# --- Auslaufen --------------------------------------------------------------

func _begin_resolve() -> void:
	var d := maneuver()
	_maneuver = d
	_plan = plan(d)
	phase = Phase.RESOLVE
	selected = null
	turns += 1
	_turn_damage = 0.0
	traveling = true
	var moving := float(_plan["miles"]) > 0.0
	rowing_now = moving and bool(d["rows"])
	_lore(String(d["story"]))
	Sfx.play("horn")
	if absf(float(d["sail"]) - sail_visual) > 0.4:
		Sfx.play("sail", 0.0, 0.5)
	var want := float(_plan["want"])
	if want > 0.0 and not moving:
		_fact("Zu wenig Hände an Segel und Ruder – das Schiff treibt nur.", Kind.BAD)
	elif float(_plan["ratio"]) < 0.8:
		_fact("Die Besatzung reicht nicht aus (%d %%) – das Manöver wirkt schwächer: %s statt %s Meilen." % [roundi(float(_plan["ratio"]) * 100.0), fmt(float(_plan["miles"])), fmt(want)], Kind.BAD)
	_steps = [{"delay": 1.6, "fn": _noop}]
	for row in _plan["rows"]:
		_steps.append({"delay": 2.0, "fn": _do_step.bind(row)})
	_steps.append({"delay": 1.3, "fn": _do_upkeep})
	_steps.append({"delay": 1.0, "fn": _advance})
	_step_left = float(_steps[0]["delay"])


func _noop() -> void:
	pass


func _do_step(row: Dictionary) -> void:
	match String(row["kind"]):
		"arrive":
			mile = int(row["col"])
			pos = int(row["ni"])
			leg = 0.0
			route = -1
			var nd := here()
			nd["visited"] = true
			_fact("Meile %d von %d erreicht – %s." % [mile, MILES, Sea.SEA_NAMES[int(row["sea"])]], Kind.FACT)
			gain_xp(5)
			if int(nd["enc"]) >= 0:
				_enc_pending = int(nd["enc"])
				nd["enc"] = -1
		"partial":
			if row.has("event"):
				var ev: Dictionary = _plan.get("event", {})
				if not ev.is_empty():
					ev["done"] = true
				_enc_pending = int(row["event"])
				_fact("Halt auf der Strecke: %s – %s." % [Encounters.DATA[int(row["event"])]["name"], Sea.SEA_NAMES[int(row["sea"])]], Kind.FACT)
				gain_xp(5)
			else:
				_fact("Weiter auf Kurs, noch nicht am Knoten – %s." % Sea.SEA_NAMES[int(row["sea"])], Kind.FACT)
		_:
			_fact("Ihr treibt in %s." % Sea.SEA_NAMES[int(row["sea"])], Kind.FACT)
	if bool(row["last"]) and float(_plan["miles"]) > 0.0:
		leg = float(_plan["leg_after"])
		route = int(_plan["route_after"])
		total_miles += float(_plan["miles"])
	sea_view = int(row["sea"])
	if int(row["sea"]) >= 5 and not _storm_noted:
		_storm_noted = true
		_note("storm")
	var strain := float(row["strain"])
	if roundi(strain) > 0:
		_damage(strain)
		Sfx.play("creak", 0.0 if strain > 10.0 else -6.0)
		_fact("Seegang: Rumpf −%d" % roundi(strain), Kind.BAD if strain > 10.0 else Kind.FACT)
	var hz := int(row["hazard"])
	if hz != Sea.Hazard.NONE:
		_resolve_hazard(row, hz)
	_wash(float(row["wash"]))


func _resolve_hazard(row: Dictionary, hz: int) -> void:
	var mit := float(row["mit"])
	var good := mit >= 0.5
	impact = 0.4 if good else 1.0
	_damage(float(row["h_dmg"]))
	match hz:
		Sea.Hazard.BRECHER:
			Sfx.play("wave")
		Sea.Hazard.BOE:
			Sfx.play("gust")
		Sea.Hazard.RIFF:
			Sfx.play("creak")
		Sea.Hazard.NEBEL:
			Sfx.play("fog")
	if not good:
		Sfx.play("crash", 0.0, 0.3)
	loot = maxf(loot - float(row["h_loot"]), 0.0)
	var text := "%s: Rumpf −%d" % [Sea.HAZARD_NAMES[hz], roundi(float(row["h_dmg"]))]
	if float(row["h_loot"]) > 0.0:
		text += ", Beute −%d (%s)" % [roundi(float(row["h_loot"])), Encounters.booty_for("reef")]
	if roundi(float(row["h_dmg"])) == 0 and roundi(float(row["h_loot"])) == 0:
		text = "%s: ohne Schaden" % Sea.HAZARD_NAMES[hz]
	_fact(text, Kind.GOOD if good else Kind.BAD)
	_lore("hz_%s_%s" % [Sea.HAZARD_KEYS[hz], "ok" if good else "hit"])
	if float(row["h_over"]) > 0.0:
		_wash(float(row["h_over"]))


func _wash(p: float) -> void:
	if p <= 0.0 or randf() >= p or _pending.size() >= 2:
		return
	var pool: Array[CrewMember] = []
	for m in crew:
		if m.state == CrewMember.State.ABOARD:
			pool.append(m)
	if pool.is_empty():
		return
	_throw_overboard(_pick_weighted(pool))


func _throw_overboard(m: CrewMember) -> void:
	slot_owner[m.slot] = null
	m.home_slot = m.slot
	m.slot = -1
	m.state = CrewMember.State.OVERBOARD
	m.swim_x = Waves.SHIP_X - 76.0 + 26.0 * _pending.size()  # knapp hinter dem Heck, nicht hinter dem linken Panel
	_pending.append(m)
	if selected == m:
		selected = null
	impact = maxf(impact, 0.6)
	Sfx.play("splash")
	for o in crew:
		if o.state == CrewMember.State.ABOARD:
			_add_stress(o, 8.0)
	_lore("overboard", m.display_name)


func _do_upkeep() -> void:
	var d: Dictionary = _maneuver if not _maneuver.is_empty() else maneuver()
	var had_work := _turn_damage > 0.0 or hull < hull_max()
	var healed := clampf(_repair(d), 0.0, hull_max() - hull)
	if healed >= 1.0:
		hull += healed
		Sfx.play("hammer")
		_fact("Zimmerleute: Rumpf +%d" % roundi(healed), Kind.GOOD)
	var was_ok: Array[CrewMember] = []
	for m in crew:
		if m.state != CrewMember.State.ABOARD:
			continue
		if m.kraft >= CrewMember.TIRED_AT:
			was_ok.append(m)
		m.kraft = clampf(m.kraft - _kraft_cost(m, d, sea_view, had_work), 0.0, 100.0)
		_add_stress(m, _stress_gain(d, sea_view, m.kraft))
	var exhausted: Array[String] = []
	for m in was_ok:
		if m.kraft < CrewMember.TIRED_AT:
			exhausted.append(m.display_name)
	if not exhausted.is_empty():
		_fact("Erschöpft: %s" % ", ".join(exhausted), Kind.BAD)
	# Verzagte stecken ihre Nachbarn an
	for i in slot_owner.size():
		var a: CrewMember = slot_owner[i]
		if a == null or not a.afflicted or a.affliction != CrewMember.Affliction.VERZAGT or a.state != CrewMember.State.ABOARD:
			continue
		for j in [i - 1, i + 1]:
			if j >= 0 and j < slot_owner.size() and slot_owner[j] != null:
				var n: CrewMember = slot_owner[j]
				_add_stress(n, 4.0)
	# Berserker schlagen manchmal um sich und treffen den Nachbarn
	for i in slot_owner.size():
		var b: CrewMember = slot_owner[i]
		if b == null or b.state != CrewMember.State.ABOARD or b.affliction != CrewMember.Affliction.BERSERK:
			continue
		if randf() >= 0.25:
			continue
		var targets: Array[CrewMember] = []
		for j in [i - 1, i + 1]:
			if j >= 0 and j < slot_owner.size() and slot_owner[j] != null and (slot_owner[j] as CrewMember).state == CrewMember.State.ABOARD:
				targets.append(slot_owner[j])
		if targets.is_empty():
			continue
		var victim := targets[randi() % targets.size()]
		victim.kraft = maxf(victim.kraft - 20.0, 0.0)
		_add_stress(victim, 8.0)
		b.stress = maxf(b.stress - 10.0, 0.0)
		_fact("%s rastet aus und schlägt %s nieder (Kraft −20)." % [b.display_name, victim.display_name], Kind.BAD)
		_lore("berserk_hit", b.display_name, victim.display_name)
	_bond_effects()
	var need := int(d["proviant"]) + _take_extra_food()
	var short_ration := proviant < need  # Hunger nur, wenn die Ration nicht reichte
	proviant -= need
	_fact("Proviant −%d (noch %d)%s" % [need, maxi(proviant, 0), (" – davon %d für die Männer unter Deck" % (need - int(d["proviant"]))) if need > int(d["proviant"]) else ""], Kind.FACT)
	_reserve_rest()
	if proviant <= 0:
		proviant = 0
	if short_ration:
		for m in crew:
			if m.state == CrewMember.State.ABOARD:
				_add_stress(m, 10.0)
		for r in reserve.duplicate():  # der Hunger trifft auch die Männer unter Deck
			_add_stress(r, 10.0)
			r.kraft = maxf(r.kraft - 6.0, 0.0)
			if r.kraft <= 0.0:
				_kill_reserve(r, "starved")
		_lore("hunger")
		# Wer ohne Proviant am Ende seiner Kraft ist, überlebt es nicht
		for m in crew:
			if m.state == CrewMember.State.ABOARD and m.kraft <= 0.0:
				_kill(m, true)
				_fact("%s ist verhungert." % m.display_name, Kind.BAD)
				_lore("starved", m.display_name)
				_note("starved", m.display_name)
		for m in crew:
			if m.state == CrewMember.State.ABOARD:
				m.kraft = maxf(m.kraft - 6.0, 0.0)
		# Wer ohne Proviant auch noch auf der Stelle treibt, verliert den Schwächsten an den Hunger
		if float(_plan["miles"]) == 0.0:
			var weakest: CrewMember = null
			for m in crew:
				if m.state == CrewMember.State.ABOARD and (weakest == null or m.kraft < weakest.kraft):
					weakest = m
			if weakest != null:
				_kill(weakest, true)
				_fact("%s ist verhungert." % weakest.display_name, Kind.BAD)
				_lore("starved", weakest.display_name)
				_note("starved", weakest.display_name)
	_check_breakdown()


func _check_breakdown() -> void:
	for m in crew:
		if m.state == CrewMember.State.ABOARD and m.stress >= 100.0 and not m.afflicted:
			var berserk := randf() < (0.7 if m.traits.has(Traits.Id.HEISSSPORN) else 0.35)
			m.afflicted = true
			m.affliction = CrewMember.Affliction.BERSERK if berserk else CrewMember.Affliction.VERZAGT
			m.stress = 60.0
			Sfx.play("heartbeat")
			if berserk:
				_fact("%s sieht rot: stärker, aber nicht mehr zu bremsen." % m.display_name, Kind.BAD)
				_lore("berserk", m.display_name)
				_note("berserk", m.display_name)
			else:
				_fact("%s verliert den Mut und arbeitet nur noch halb so gut." % m.display_name, Kind.BAD)
				_lore("breakdown", m.display_name)
				_note("breakdown", m.display_name)


func _advance() -> void:
	traveling = false
	rowing_now = false
	if hull <= 0.0:
		_end(false, "sunk")
		return
	_fill_from_reserve()
	if alive_count() == 0:
		_end(false, "all_dead")
		return
	if not _pending.is_empty():
		swimmer = _pending[0]
		rescuer = default_rescuer()
		phase = Phase.RESCUE
		_steps.clear()
		return
	if _enc_pending >= 0:
		_start_encounter()
		return
	if mile >= MILES:
		_complete_stage()
		return
	_start_plan()


## Der Hafen am Ende der Etappe liegt hinter uns: die nächste, härtere See beginnt.
func _complete_stage() -> void:
	gain_xp(40 + 5 * stage)
	_note("stage", str(stage))
	stage += 1
	if max_stage > 0 and stage > max_stage:
		_end(true, "retire")
		return
	_pick_theme()
	mile = 0
	pos = 0
	leg = 0.0
	route = -1
	shop = []
	shop_open = false
	_make_map()
	_lore("stage_new", str(stage))
	if theme > 0:
		_lore("theme_%d" % theme)
	_fact("Etappe %d beginnt. Die See wird rauer, die Beute größer." % stage, Kind.FACT)
	_start_plan()


func _start_plan() -> void:
	phase = Phase.PLAN
	_maneuver = {}
	if not can_choose(maneuver()):
		sail_set = 1  # ohne Proviant bleibt nur das Weiterfahren
		oars_set = 1
	if leg <= 0.0:
		route = -1
	selected = null
	swimmer = null
	rescuer = null
	encounter = -1
	_plan = {}
	_fill_from_reserve()
	_auto_relief()
	sea_view = location_sea()
	var links := next_links()
	if leg <= 0.0 and links.size() == 1:
		route = int(links[0])
	_offer_perk()
	_forecast_lore()
	if autosave:
		Persist.save_run(self)


func _forecast_lore() -> void:
	var ahead: Array = next_links() if leg <= 0.0 else [route]
	for j in ahead:
		var hz := int(node_at(mile + 1, int(j))["hazard"])
		if hz != Sea.Hazard.NONE:
			_lore("fc_" + String(Sea.HAZARD_KEYS[hz]))
			return


# --- Begegnungen ------------------------------------------------------------

func _start_encounter() -> void:
	encounter = _enc_pending
	_enc_pending = -1
	phase = Phase.ENCOUNTER
	_steps.clear()
	encounters_done += 1
	var def: Dictionary = Encounters.DATA[encounter]
	_leaving = false
	if bool(def.get("harbor", false)):
		harbor_used.clear()
		_harbor_spins = 0
		_roll_recruit()
		shop = _roll_shop()
		gear_shop = _roll_gear_shop()
		werft_tab = 0
		shop_open = false
		Sfx.play("bell")
	else:
		Sfx.play("sting")
	if bool(def.get("battle", false)):
		Battle.start(self)
	_lore(String(def["intro"]))


func decide_encounter(i: int) -> void:
	if phase != Phase.ENCOUNTER:
		return
	var opts: Array = Encounters.DATA[encounter]["options"]
	if i < 0 or i >= opts.size():
		return
	var opt: Dictionary = opts[i]
	if not Encounters.available(self, opt):
		return
	if bool(opt.get("shop", false)):
		shop_open = true  # die Werft schlägt sich auf; die Begegnung bleibt offen
		return
	if bool(opt.get("crew", false)):
		crew_requested = true  # die Taverne: Main öffnet die Mannschaftsansicht mit den Anwärtern
		return
	if opt.has("slot"):
		if automat_enter(String(opt["slot"])) and bool(opt.get("bottle", false)):  # die Begegnung bleibt offen, bis man den Automaten schließt
			loki_pick("bottle")
		return
	if opt.has("formation"):  # Überfall: wird bekämpft, nicht gewürfelt
		var outs: Array = opt["outcomes"]
		var win_fx: Dictionary = ((outs[0] as Dictionary)["fx"] as Dictionary).duplicate()
		for k in ["wound", "kill", "hull", "kraft_all"]:
			win_fx.erase(k)
		_fact("%s: %s" % [Encounters.DATA[encounter]["name"], opt["label"]], Kind.FACT)
		start_fight(String(opt["formation"]), {
			"source": "encounter", "win_fx": win_fx, "win_lore": String((outs[0] as Dictionary).get("lore", "")),
			"lose_lore": String((outs[1] as Dictionary).get("lore", "")), "pass_lore": String(opt.get("pass_lore", "")),
		}, int(opt.get("count", -1)))
		return
	if Encounters.is_battle(encounter):
		Battle.decide(self, String(opt["tactic"]))
		return
	phase = Phase.RESOLVE
	traveling = false
	if bool(opt.get("once", false)):
		harbor_used.append(opt["label"])
	_leaving = bool(opt.get("leave", false))
	var cost: Dictionary = opt.get("cost", {})
	if cost.has("loot"):
		loot = maxf(loot - float(cost["loot"]), 0.0)
		Sfx.play("coin")
		_fact("Bezahlt: Beute −%d (noch %d)" % [roundi(float(cost["loot"])), roundi(loot)], Kind.FACT)
	if cost.has("proviant"):
		proviant = maxi(proviant - int(cost["proviant"]), 0)
		_fact("Bezahlt: Proviant −%d (noch %d)" % [int(cost["proviant"]), proviant], Kind.FACT)
	_fact("%s: %s" % [Encounters.DATA[encounter]["name"], opt["label"]], Kind.FACT)
	var outcome := Encounters.pick(self, opt)
	_steps = [{"delay": 1.2, "fn": _apply_outcome.bind(outcome)}, {"delay": 1.4, "fn": _after_encounter}]
	_step_left = 1.2


func _apply_outcome(outcome: Dictionary) -> void:
	var fx: Dictionary = outcome.get("fx", {})
	_hired_name = ""
	var shown := Encounters.scaled_fx(self, fx)  # die Zusammenfassung nennt, was wirklich ankam (mit Zuschlägen und Schutz)
	var loot_before := loot
	var loot_msg := ""  # kommt als letzte Meldung vor dem Skalden, damit sie nicht gleich wegscrollt
	var killed := _apply_fx(fx)
	var gained := roundi(loot - loot_before)
	if String(outcome.get("lore", "")) == "castaway_join" and _hired_name == "":
		outcome = outcome.duplicate()
		outcome["lore"] = "castaway_cache"  # kein Platz an Bord: er bezahlt mit dem Versteck seines Schiffs
	if gained > 0:  # Beute getrennt melden: wie viel, woher, was es war
		var what := Encounters.booty_for(String(outcome.get("lore", "")), true)
		var src := String(Encounters.DATA[encounter]["name"]) if encounter >= 0 else ""
		loot_msg = "Beute +%d%s%s" % [gained, (" aus: %s" % what) if what != "" else "", (" (%s, mit Zuschlägen)" % src) if what == "" and src != "" else ""]
		shown.erase("loot")
	var summary := Encounters.fx_summary(shown)
	var bad := fx.has("kill") or int(fx.get("hull", 0)) < 0 or int(fx.get("stress_all", 0)) > 5
	if summary != "":
		_fact(summary, Kind.BAD if bad else Kind.GOOD)
	for n in killed:
		_fact("%s ist gefallen." % n, Kind.BAD)
	var key := String(outcome.get("lore", ""))
	if key == "trader_win" or key == "monster_win" or key == "village_win":
		_note("raid_win")
		gain_xp(25)
	if key == "harbor_mead" or key == "harbor_brawl":
		Sfx.play("mug")
	if key == "harbor_mead" and randf() < 0.07:
		_find_pfand("Aus der Taverne")  # der Wirt gibt die leere Flasche mit
	if int(fx.get("loot", 0)) > 0:
		Sfx.play("coin")
	if int(fx.get("hull", 0)) > 0:
		Sfx.play("hammer")
	if loot_msg != "":
		_fact(loot_msg, Kind.GOOD)
	if key != "":
		_lore(key, killed[0] if not killed.is_empty() else _hired_name)
	_check_breakdown()


func _apply_fx(fx: Dictionary) -> Array[String]:
	var killed: Array[String] = []
	if fx.has("loot"):
		var gain := float(fx["loot"])
		if gain > 0.0:
			gain *= stat("loot") * (1.0 + 0.12 * float(stage - 1))  # reichere Beute in späteren Etappen
		loot = maxf(loot + gain, 0.0)
	if fx.has("proviant"):
		var np := proviant + int(fx["proviant"])
		if int(fx["proviant"]) > 0:
			np = mini(np, maxi(proviant, roundi(stat("proviant_max"))))
		proviant = maxi(np, 0)
	if fx.has("hull"):
		var h := float(fx["hull"])
		if h < 0.0:
			_damage(-h * stat("hazard"))
		else:
			hull = minf(hull + h, hull_max())
	for m in crew:
		if m.state != CrewMember.State.ABOARD:
			continue
		if fx.has("kraft_all"):
			m.kraft = clampf(m.kraft + float(fx["kraft_all"]), 0.0, 100.0)
		if fx.has("stress_all"):
			_add_stress(m, float(fx["stress_all"]))
	for k in int(fx.get("wound", 0)):
		var m := _random_aboard()
		if m != null:
			m.kraft = maxf(m.kraft - Encounters.WOUND_KRAFT, 0.0)
	for k in int(fx.get("kill", 0)):
		var m := _random_aboard()
		if m != null:
			_kill(m, true)
			killed.append(m.display_name)
			_note("killed", m.display_name, encounter)
	for k in int(fx.get("recruit", 0)):
		_hire()
	if fx.has("sight"):
		camp_sight += int(fx["sight"])  # eine Karte: für den Rest der Etappe eine Meile weiter sehen
	for k in int(fx.get("castaway", 0)):
		# ein Schiffbrüchiger: wer Platz hat, bekommt einen neuen Mann; sonst zeigt er dafür sein gesunkenes Schiff
		var keep_r := recruits.duplicate()
		var keep_1 := recruit.duplicate()
		_roll_recruit()
		if can_recruit():
			var nm := _place_recruit(0)
			nm.kraft = minf(nm.kraft, 40.0)  # halb erfroren: er braucht ein paar Wachen auf der Ladung
		else:
			loot += 20.0 * stat("loot") * (1.0 + 0.12 * float(stage - 1))
		recruits = keep_r
		recruit = keep_1
	for k in int(fx.get("item", 0)):
		if randf() < 0.1:
			_find_pfand("Fund im Wrack")
		elif randf() < 0.35:
			_find_gear(0, 1.0, "Fund im Wrack")
		else:
			_find_item()
	return killed


## Ein Fund (Wrack, besiegter Gegner): ein zufälliger Gegenstand, den man noch nicht hat, mit gewürfelter Seltenheit.
## Ist sein Platz frei, wird er eingebaut; ist er besser als der dort, ersetzt er ihn und der alte wird verkauft;
## sonst wird er verkauft.
func _find_item(minimum: int = 0, luck: float = 1.0, source: String = "Fund im Wrack") -> void:
	var pool: Array = []
	for id in Items.ids():
		if not has_item_base(String(id)):
			pool.append(id)
	if pool.is_empty():
		return
	var key := Items.make(String(pool[randi() % pool.size()]), Items.roll_rarity(stage, luck, minimum))
	var label := "%s (%s)" % [Items.name_of(key), Items.rarity_name(key)]
	var slots := Items.slots_for(key)
	var free := false
	for s in slots:
		if not items.has(s):
			free = true
	Sfx.play("coin")
	if free:
		equip(key)
		_fact("%s: %s, gleich eingebaut." % [source, label], Kind.GOOD)
		return
	var worst: int = slots[0]
	for s in slots:
		if Items.rarity_of(String(items[s])) < Items.rarity_of(String(items[worst])):
			worst = s
	if Items.rarity_of(key) > Items.rarity_of(String(items[worst])):
		var old := String(items[worst])
		var gain_old := float(Items.price_at(old, stage)) * 0.5
		loot += gain_old
		items[worst] = key
		_mods_changed()
		_fact("%s: %s, besser als %s: eingebaut, das alte für %d Beute verkauft." % [source, label, Items.name_of(old), roundi(gain_old)], Kind.GOOD)
		return
	var gain := float(Items.price_at(key, stage)) * 0.5
	loot += gain
	_fact("%s: %s, aber der Platz ist besetzt. Verkauft für %d Beute." % [source, label, roundi(gain)], Kind.GOOD)

## Kann man in der Taverne jemanden anheuern? Platz ist für Ersatz eines Gefallenen oder in der Reserve.
func can_recruit() -> bool:
	if recruits.is_empty():
		return false
	if reserve_free() > 0:
		return true
	return _first_free_slot() >= 0 and _dead_entry() >= 0


## Index eines gefallenen Eintrags in der Mannschaftsliste (-1: keiner).
func _dead_entry() -> int:
	for k in crew.size():
		if crew[k].state == CrewMember.State.DEAD:
			return k
	return -1


## Drei Anwärter für die Taverne. Preis nach Kraft und Eigenschaften, wächst mit der Etappe.
func _roll_recruit() -> void:
	recruits = []
	var taken: Array[String] = []
	for m in crew:
		if m.state != CrewMember.State.DEAD:
			taken.append(m.display_name)
	for m in reserve:
		taken.append(m.display_name)
	for k in 3:
		var pool: Array[String] = []
		for nm in CREW_NAMES:
			if not taken.has(nm) and not fallen_names.has(nm):
				pool.append(nm)
		if pool.is_empty():
			for nm in CREW_NAMES:
				if not taken.has(nm):
					pool.append(nm)
		if pool.is_empty():
			break
		var nm2 := String(pool[randi() % pool.size()])
		taken.append(nm2)
		var kraft := randi_range(55, 100)
		var tr := Traits.random_set()
		var price := roundi((25.0 + 8.0 * float(tr.size()) + (float(kraft) - 60.0) * 0.4) * (1.0 + 0.1 * float(stage - 1)))
		recruits.append({"name": nm2, "kraft": kraft, "stress": randi_range(0, 30), "traits": tr, "price": price, "role": Roles.random_role()})
	recruit = recruits[0] if not recruits.is_empty() else {}


## Einen Anwärter anheuern und bezahlen. Er nimmt den Platz eines Gefallenen ein, sonst kommt er in die Reserve.
func hire_candidate(i: int) -> bool:
	if phase != Phase.ENCOUNTER or not Encounters.is_harbor(encounter) or i < 0 or i >= recruits.size():
		return false
	var price := int((recruits[i] as Dictionary)["price"])
	if loot < float(price) or not can_recruit():
		return false
	loot -= float(price)
	Sfx.play("coin")
	_fact("Bezahlt: Beute −%d (noch %d)" % [price, roundi(loot)], Kind.FACT)
	var m := _place_recruit(i)
	_lore("harbor_hire", m.display_name)
	return true


## Ohne Bezahlung (alter Weg über fx "recruit"): der erste Anwärter.
func _hire() -> void:
	if not recruits.is_empty() and can_recruit():
		_place_recruit(0)


func _place_recruit(i: int) -> CrewMember:
	var c: Dictionary = recruits[i]
	var m := _new_man(c)
	var seat := _first_free_slot()
	var dead_idx := _dead_entry()
	var to_seat := seat >= 0 and dead_idx >= 0
	if to_seat:
		var dead := crew[dead_idx]
		bonds = bonds.filter(func(bd: Dictionary) -> bool: return int(bd["a"]) != dead.id and int(bd["b"]) != dead.id)
		crew[dead_idx] = m
		m.state = CrewMember.State.ABOARD
		m.slot = seat
		slot_owner[seat] = m
	else:
		m.state = CrewMember.State.RESERVE
		reserve.append(m)
	recruits.remove_at(i)
	recruit = recruits[0] if not recruits.is_empty() else {}
	_hired_name = m.display_name
	_note("hired", m.display_name)
	_fact("%s heuert an (Kraft %d)%s." % [m.display_name, roundi(m.kraft), "" if to_seat else ", kommt in die Reserve"], Kind.GOOD)
	return m


## Ein Mann aus den Werten eines Anwärters.
func _new_man(c: Dictionary) -> CrewMember:
	var m := CrewMember.new()
	m.id = _next_id
	_next_id += 1
	m.display_name = String(c["name"])
	m.look = randi() % 7
	m.kraft = float(c["kraft"])
	m.stress = float(c["stress"])
	m.traits = Traits.typed(c["traits"])
	m.role = int(c.get("role", Roles.random_role()))
	return m


func _random_aboard() -> CrewMember:
	var pool: Array[CrewMember] = []
	for m in crew:
		if m.state == CrewMember.State.ABOARD:
			pool.append(m)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


func _after_encounter() -> void:
	var def: Dictionary = Encounters.DATA[encounter]
	if bool(def.get("harbor", false)) and not _leaving:
		phase = Phase.ENCOUNTER  # im Hafen: nächste Wahl, bis man ablegt
		_steps.clear()
		return
	shop_open = false
	shop = []
	encounter = -1
	_advance()


# --- Spielautomaten ---------------------------------------------------------------

func automat_levels() -> Array[int]:
	return Slots.bet_levels(stage)


## Einsatz des nächsten Drehs (Nornenwalzen); beim Freidreh der feste Einsatz.
func automat_bet() -> int:
	if automat == null:
		return 0
	if automat_kind == "bonus":
		return automat.bet
	return automat_levels()[clampi(automat_bet_i, 0, 2)]


## Ob es an dieser Stelle etwas zu spielen gibt: im Hafen genug Beute und noch Drehs, bei Adlersson mindestens ein möglicher Einsatz.
func slot_available(kind: String) -> bool:
	match kind:
		"harbor":
			return _harbor_spins < SLOT_HARBOR_SPINS and loot >= float(automat_levels()[0])
		"loki":
			for st in loki_stakes():
				if bool((st as Dictionary)["ok"]):
					return true
	return false


## Stellt einen Automaten auf. "harbor" und "loki" stehen in einer Begegnung, "bonus" ist der Freidreh nach einem Sieg.
func automat_enter(kind: String, bet: int = 0, force: bool = false) -> bool:
	if automat_open or not (kind == "bonus" or slot_available(kind)):
		return false
	automat_kind = kind
	automat = Slots.new("loki" if kind == "loki" else "norn", bet)
	automat_open = true
	automat_last = {}
	automat_unbanked = 0
	automat_spent = 0
	automat_won = 0
	automat_seq = 0
	automat_seq_jackpot = false
	automat_due = {}
	automat_done = false
	automat_token = kind == "bonus"
	if kind == "bonus":
		automat.force_trigger = force
	elif kind == "loki":
		loki_round = 0
		loki_pot = 0
		loki_ladder = 0
		loki_reward = {}
		loki_man = null
		loki_stake = "loot"
		for st in loki_stakes():
			if bool((st as Dictionary)["ok"]):
				loki_stake = String((st as Dictionary)["kind"])
				break
	else:
		automat_bet_i = mini(automat_bet_i, 2)
		while automat_bet_i > 0 and loot < float(automat_levels()[automat_bet_i]):
			automat_bet_i -= 1
		automat.bet = automat_levels()[automat_bet_i]
	return true


func automat_set_bet(i: int) -> void:
	if automat_open and automat_kind == "harbor" and not automat.in_free():
		automat_bet_i = clampi(i, 0, 2)
		automat.bet = automat_levels()[automat_bet_i]


func automat_can_spin() -> bool:
	if not automat_open or automat == null or automat_kind == "loki":
		return false
	if automat.in_free():
		return true
	if automat_kind == "bonus":
		return automat_token
	return _harbor_spins < SLOT_HARBOR_SPINS and loot >= float(automat_levels()[automat_bet_i])


## Ein Dreh der Nornenwalzen. Der Einsatz wird gleich bezahlt, der Gewinn liegt in automat_unbanked, bis automat_bank() ihn
## gutschreibt (die Anzeige tut das, wenn die Walzen stehen). Gibt das Ergebnis zurück, leer wenn nichts zu drehen ist.
func automat_spin() -> Dictionary:
	if not automat_can_spin():
		return {}
	if not automat.in_free():
		automat_seq = 0
		automat_seq_jackpot = false
		if automat_kind == "bonus":
			automat_token = false
		else:
			automat.bet = automat_levels()[automat_bet_i]
			loot -= float(automat.bet)
			automat_spent += automat.bet
			_harbor_spins += 1
	var res := automat.spin()
	var win := int(res["win"])
	automat_unbanked += win
	automat_seq += win
	if bool(res["jackpot"]):
		automat_seq_jackpot = true
	automat_last = res
	if int(res["trigger"]) > 0:
		_lore("slot_alive")
	if not automat.in_free():  # die Folge ist zu Ende: Belohnungen vormerken
		var ratio := float(automat_seq) / float(maxi(automat.bet, 1))
		automat_due = _slot_due(ratio, automat_seq_jackpot)
		if automat_kind == "bonus":
			automat_done = true
	return res


## Belohnungen jenseits der Beute: ab 20 Einsätzen ein Segen, ab 60 dazu ein Fund (mindestens episch), das Joker-Jackpot legendär.
func _slot_due(ratio: float, jackpot: bool) -> Dictionary:
	var due := {}
	if ratio >= 20.0 or jackpot:
		due["perk"] = true
	if jackpot:
		due["gear"] = Items.Rarity.LEGENDAER
	elif ratio >= 60.0:
		due["gear"] = Items.Rarity.EPISCH
	if ratio >= 10.0:
		due["lore"] = "slot_jackpot" if jackpot else "slot_big"
	return due


## Schreibt den Gewinn gut und löst die vorgemerkten Belohnungen aus. Gibt Texte für die Anzeige zurück.
func automat_bank() -> Array:
	var lines: Array = []
	if automat_unbanked > 0:
		loot += float(automat_unbanked)
		automat_won += automat_unbanked
		Sfx.play("coin")
		automat_unbanked = 0
	if not automat_due.is_empty():
		var due := automat_due
		automat_due = {}
		_pay_due(due, lines)
	return lines


func _pay_due(due: Dictionary, lines: Array) -> void:
	if due.has("lore"):
		_lore(String(due["lore"]))
	if bool(due.get("perk", false)):
		_perk_pending += 1
		_offer_perk()
		lines.append("Die Götter bieten einen Segen an")
		_fact("Der Automat zahlt mehr als Silber: ein Segen der Götter.", Kind.GOOD)
	if due.has("gear"):
		_find_gear(int(due["gear"]), 2.0, "Gewinn am Automaten")
		lines.append("Ausrüstung im Vorrat")


## Schließt den Automaten. Offenes wird gutgeschrieben. Bei Adlersson ist die Begegnung damit vorbei.
func automat_close() -> void:
	if not automat_open:
		return
	if automat_kind == "loki" and loki_pot > 0:
		loki_cash()
	automat_bank()
	var kind := automat_kind
	if automat_kind == "harbor" and automat_spent > 0:
		var diff := automat_won - automat_spent
		_fact("Spelunke: gesetzt %d, gewonnen %d (%s)." % [automat_spent, automat_won, signed(diff)], Kind.GOOD if diff >= 0 else Kind.FACT)
		if diff < 0 and automat_spent >= 3 * automat_levels()[0]:
			_lore("slot_harbor_lose")
	automat_open = false
	automat = null
	automat_kind = ""
	if kind == "loki" and phase == Phase.ENCOUNTER:
		phase = Phase.RESOLVE
		traveling = false
		_leaving = false
		_steps = [{"delay": 0.6, "fn": _after_encounter}]
		_step_left = 0.6


# --- Adlerssons Automat: Einsatz ist Beute, Rumpf oder ein Mann ---

## Die drei möglichen Einsätze: {kind, label, text, value (in Beute gerechnet, der Gewinn ist ein Vielfaches), ok}.
func loki_stakes() -> Array:
	var out: Array = []
	var v_loot := clampi(roundi(loot * 0.5), 0, 100 + 50 * stage)
	out.append({"kind": "loot", "label": "Beute", "text": "%d Beute" % v_loot, "value": v_loot, "ok": v_loot >= 20})
	var pts := roundi(hull_max() * 0.25)
	out.append({"kind": "hull", "label": "Rumpf", "text": "Rumpf −%d" % pts, "value": pts * 3, "ok": hull > float(pts) + 15.0})
	var man := _loki_man()
	out.append({"kind": "man", "label": "Ein Mann", "text": man.display_name if man != null else "–", "value": 120 + 40 * stage, "ok": man != null and alive_count() >= 3})
	# die Pfandflasche: kein Einsatz, kein Risiko, ein sicherer Gewinn (siehe _loki_bottle_spin)
	out.append({"kind": "bottle", "label": Items.PFAND_NAME, "text": ("sicheres Freispiel (%d)" % pfand) if pfand > 0 else "keine Pfandflasche", "value": 80 + 30 * stage, "ok": pfand > 0})
	return out


func _loki_man() -> CrewMember:
	if loki_man != null and loki_man.state == CrewMember.State.ABOARD:
		return loki_man
	loki_man = _random_aboard()
	return loki_man


## Ist der gewählte Einsatz nicht mehr möglich (kein Mann mehr übrig, zu wenig Beute), wird der erste mögliche gewählt.
func _loki_fix_stake() -> void:
	var cur := loki_stake_of(loki_stake)
	if not cur.is_empty() and bool(cur["ok"]):
		return
	for st in loki_stakes():
		if bool((st as Dictionary)["ok"]):
			loki_stake = String((st as Dictionary)["kind"])
			return


func loki_stake_of(kind: String) -> Dictionary:
	for st in loki_stakes():
		if String((st as Dictionary)["kind"]) == kind:
			return st
	return {}


func loki_pick(kind: String) -> bool:
	if not automat_open or automat_kind != "loki" or loki_pot > 0 or automat.in_free():
		return false
	if kind != "bottle" and loki_round >= LOKI_ROUNDS:
		return false  # die Pfandflasche zählt nicht als Runde und geht auch danach noch
	var st := loki_stake_of(kind)
	if st.is_empty() or not bool(st["ok"]):
		return false
	loki_stake = kind
	return true


func loki_over() -> bool:
	return loki_round >= LOKI_ROUNDS and loki_pot == 0 and pfand <= 0


func loki_can_spin() -> bool:
	if not automat_open or automat_kind != "loki" or loki_pot > 0:
		return false
	if loki_round >= LOKI_ROUNDS and loki_stake != "bottle":
		return false
	var st := loki_stake_of(loki_stake)
	return not st.is_empty() and bool(st["ok"])


## Ein Dreh an Adlerssons Automat. Ergebnis wie Slots.spin(), dazu stake, win (gedeckelt), penalty (Text der Strafe).
func loki_spin() -> Dictionary:
	if not loki_can_spin():
		return {}
	var st := loki_stake_of(loki_stake)
	var value := int(st["value"])
	if loki_stake == "bottle":
		return _loki_bottle_spin(value)
	automat.bet = value
	if loki_stake == "loot":
		loot -= float(value)
	var res := automat.spin()
	loki_round += 1
	loki_ladder = 0
	var win := mini(int(res["win"]), LOKI_CAP)
	res["win"] = win
	res["stake"] = loki_stake
	res["stake_value"] = value
	res["penalty"] = ""
	res["lost"] = ""
	if bool(res["curse"]):
		res["penalty"] = _loki_curse()
		res["lost"] = _loki_lose_stake()
		_lore("slot_loki_curse")
	elif win > 0:
		loki_pot = win
		loki_reward = _slot_due(float(res["big"]), bool(res["jackpot"]))
		loki_reward.erase("lore")
		_lore("slot_loki_win")
	else:
		res["lost"] = _loki_lose_stake()
		_lore("slot_loki_lose")
	_loki_fix_stake()
	automat_last = res
	return res


## Das sichere Freispiel mit der Pfandflasche: die Flasche ist weg, aber nichts steht auf dem Spiel. Gedreht wird, bis es
## einen Gewinn gibt; Adlerssons Streich zählt nicht. Der Gewinn liegt wie sonst im Topf (kassieren oder Risikoleiter),
## und die Flasche zählt nicht als Runde.
func _loki_bottle_spin(value: int) -> Dictionary:
	pfand = maxi(pfand - 1, 0)
	automat.bet = value
	var res := automat.spin()
	var guard := 0
	while (bool(res["curse"]) or int(res["win"]) <= 0) and guard < 500:
		res = automat.spin()
		guard += 1
	var win := mini(maxi(int(res["win"]), value * 2), LOKI_CAP)
	res["win"] = win
	res["stake"] = "bottle"
	res["stake_value"] = value
	res["penalty"] = ""
	res["lost"] = ""
	res["bottle"] = true
	loki_ladder = 0
	loki_pot = win
	loki_reward = _slot_due(float(res["big"]), bool(res["jackpot"]))
	loki_reward.erase("lore")
	_fact("Die Pfandflasche wirkt: ein sicheres Freispiel bei Adlersson, nichts kann verloren gehen.", Kind.GOOD)
	_lore("slot_bottle")
	_loki_fix_stake()
	automat_last = res
	return res


## Der Einsatz ist verloren: Rumpf wird zerschlagen oder der Mann geht. Beute war schon bezahlt. Gibt den Text zurück.
func _loki_lose_stake() -> String:
	var st := loki_stake_of(loki_stake)
	match loki_stake:
		"hull":
			var pts := roundi(hull_max() * 0.25)
			hull = maxf(hull - float(pts), 1.0)
			_turn_damage += float(pts)
			Sfx.play("crash")
			_fact("Adlersson nimmt den Einsatz: Rumpf −%d." % pts, Kind.BAD)
			return "Rumpf −%d" % pts
		"man":
			var m := _loki_man()
			if m != null:
				var nm := m.display_name
				death_causes[nm] = "gefallen: Adlerssons Spiel"
				_kill(m, true)
				_note("killed", nm, Encounters.Id.SPIELER)
				_fact("%s ist gefallen: Adlersson hat ihn gewonnen." % nm, Kind.BAD)
				_lore("slot_loki_man", nm)
				loki_man = null
				return "%s ist verloren" % nm
	_fact("Adlersson nimmt den Einsatz: Beute −%d." % int(st.get("value", 0)), Kind.BAD)
	return "Beute −%d" % int(st.get("value", 0))


## Adlerssons Streich (drei Masken): zusätzlich zum Einsatz eine Strafe. Gibt den Text zurück.
func _loki_curse() -> String:
	var pick := randi() % 4
	if pick == 0 and alive_count() > 2:
		var m := _random_aboard()
		if m != null and not (loki_stake == "man" and m == loki_man):
			var nm := m.display_name
			death_causes[nm] = "gefallen: Adlerssons Streich"
			_kill(m, true)
			_note("killed", nm, Encounters.Id.SPIELER)
			_fact("Adlerssons Streich: %s fällt tot um." % nm, Kind.BAD)
			return "%s fällt tot um" % nm
		pick = 1
	if pick == 1:
		var pts := roundi(hull_max() * 0.25)
		hull = maxf(hull - float(pts), 1.0)
		_turn_damage += float(pts)
		_fact("Adlerssons Streich: Rumpf −%d." % pts, Kind.BAD)
		return "Rumpf −%d" % pts
	if pick == 2:
		var half := proviant / 2
		proviant -= half
		_fact("Adlerssons Streich: Proviant −%d, alles verdorben." % half, Kind.BAD)
		return "Proviant −%d" % half
	for m in crew:
		if m.state == CrewMember.State.ABOARD:
			_add_stress(m, 25.0)
	_fact("Adlerssons Streich: die ganze Mannschaft schaudert (Verzweiflung +25).", Kind.BAD)
	return "Verzweiflung +25 für alle"


## Den Gewinn behalten.
func loki_cash() -> void:
	if not automat_open or automat_kind != "loki" or loki_pot <= 0:
		return
	var pot := loki_pot
	loki_pot = 0
	loki_ladder = 0
	automat_unbanked += pot
	var lines: Array = []
	_pay_due(loki_reward, lines)
	loki_reward = {}
	automat_bank()
	_loki_fix_stake()


## Risikoleiter: Münzwurf, der Gewinn wird verdoppelt oder ist weg. Gibt zurück, ob es geklappt hat.
func loki_risk() -> bool:
	if not automat_open or automat_kind != "loki" or loki_pot <= 0 or loki_ladder >= Slots.RISK_STEPS:
		return false
	var ok := automat.risk_flip()
	if ok:
		loki_pot = loki_pot * 2
		loki_ladder += 1
		_lore("slot_risk_win")
	else:
		_fact("Die Münze fällt falsch: %d Beute sind weg." % loki_pot, Kind.BAD)
		loki_pot = 0
		loki_ladder = 0
		loki_reward = {}
		_lore("slot_risk_lose")
	return ok


# --- Mann über Bord ---------------------------------------------------------

func rescue_chance(r: CrewMember) -> float:
	var c := 0.88 - 0.09 * float(sea_view - 1) + 0.2 * (r.efficiency() - 1.0)
	if swimmer != null:
		c += swimmer.swim_bonus()
		c += rescue_bond_bonus(r, swimmer)  # für den eigenen Bruder zieht man fester
	return clampf(c, 0.1, 0.95)


func rescue_costs() -> Dictionary:
	return {"proviant": 1, "hull": maxi(sea_view - 2, 0) * 2, "kraft": 20}


func default_rescuer() -> CrewMember:
	var best: CrewMember = null
	var best_score := -1.0e9
	for m in crew:
		if m.state != CrewMember.State.ABOARD or m.slot < 0:
			continue
		var order := RESCUE_ORDER.find(Stations.slot_station(m.slot))
		var score := m.efficiency() * 10.0 - float(order) * 1.5
		if swimmer != null and rescue_bond_bonus(m, swimmer) > 0.0:
			score += 4.0
		if score > best_score:
			best_score = score
			best = m
	return best


func decide_rescue(attempt: bool) -> void:
	if phase != Phase.RESCUE or swimmer == null:
		return
	var s := swimmer
	var r := rescuer if (rescuer != null and rescuer.state == CrewMember.State.ABOARD) else default_rescuer()
	phase = Phase.RESOLVE
	if attempt and r != null:
		_roll_ok = randf() < rescue_chance(r)
		Sfx.play("rope")
		rope_from = r
		rope_to = s
		var c := rescue_costs()
		proviant = maxi(proviant - int(c["proviant"]), 0)
		_damage(float(c["hull"]))
		var cost_text := "Proviant −%d" % int(c["proviant"])
		if int(c["hull"]) > 0:
			cost_text += ", Rumpf −%d" % int(c["hull"])
		_fact("%s wirft %s das Seil zu. %s." % [r.display_name, s.display_name, cost_text], Kind.FACT)
		_steps = [{"delay": 1.8, "fn": _rescue_result.bind(r, s)}]
	else:
		_steps = [{"delay": 0.6, "fn": _rescue_abandon.bind(s)}]
	_step_left = float(_steps[0]["delay"])


func _rescue_result(r: CrewMember, s: CrewMember) -> void:
	rope_from = null
	rope_to = null
	_pending.erase(s)
	r.kraft = maxf(r.kraft - 20.0, 0.0)
	if _roll_ok:
		s.state = CrewMember.State.ABOARD
		s.kraft = minf(s.kraft, 25.0)
		_add_stress(s, 10.0)
		var slot := s.home_slot
		if slot < 0 or slot_owner[slot] != null:
			slot = _first_free_slot()
		s.slot = slot
		if slot >= 0:
			slot_owner[slot] = s
		rescued_count += 1
		for o in crew:
			if o.state == CrewMember.State.ABOARD and o != s:
				o.stress = maxf(o.stress - 5.0, 0.0)
		r.stress = maxf(r.stress - 8.0, 0.0)
		Sfx.play("rescue_ok")
		_note("rescued", s.display_name)
		_fact("%s ist gerettet, aber am Ende seiner Kräfte." % s.display_name, Kind.GOOD)
		_lore("rescued", s.display_name)
		_form_bond(r, s)
	else:
		_kill(s)
		for o in crew:
			if o.state == CrewMember.State.ABOARD:
				_add_stress(o, 12.0)
		Sfx.play("drown")
		_note("drowned", s.display_name)
		_fact("Das Seil hält nicht. %s ist verloren. Mut −12 für alle." % s.display_name, Kind.BAD)
		_lore("rescue_fail", s.display_name)
	_check_breakdown()
	_steps = [{"delay": 1.0, "fn": _after_decision}]


func _rescue_abandon(s: CrewMember) -> void:
	_pending.erase(s)
	_kill(s)
	for o in crew:
		if o.state == CrewMember.State.ABOARD:
			_add_stress(o, 20.0)
	Sfx.play("drown")
	_note("abandoned", s.display_name)
	for p in bond_partners(s):
		var bro: CrewMember = p["other"]
		if int(p["type"]) != Bond.RIVAL and bro.state == CrewMember.State.ABOARD:
			_add_stress(bro, 20.0 if int(p["type"]) == Bond.BROTHER else 10.0)
			_fact("%s verzeiht nicht, dass sein Bruder zurückblieb (Mut −20)." % bro.display_name, Kind.BAD)
			_lore("brother_abandon", bro.display_name, s.display_name)
	_fact("%s bleibt zurück. Mut −20 für alle." % s.display_name, Kind.BAD)
	_lore("abandon", s.display_name)
	_check_breakdown()
	_steps = [{"delay": 1.0, "fn": _after_decision}]


func _after_decision() -> void:
	swimmer = null
	rescuer = null
	_advance()


func _kill(m: CrewMember, from_deck: bool = false) -> void:
	if from_deck and m.slot >= 0:
		slot_owner[m.slot] = null
	_return_gear(m)
	m.state = CrewMember.State.DEAD
	m.slot = -1
	fallen.append(m)
	fallen_names.append(m.display_name)
	if from_deck:
		Sfx.play("death")
	_mourn(m)
	if selected == m:
		selected = null


# --- Ende, Protokoll, Hilfen ------------------------------------------------

func _end(won: bool, why: String) -> void:
	phase = Phase.ENDED
	ended = true
	victory = won
	cause = why
	traveling = false
	rowing_now = false
	_lore(why)
	Sfx.play("bell" if won else "death")
	saga_text = Saga.compose(self)
	if autosave:
		Persist.add_memorial(self)
		Persist.clear_run()
	if log_enabled:
		print("ENDE: %s  Etappe %d  Stufe %d  Fahrten %d  Strecke %d  Überlebt %d  Gefallen %d  Gerettet %d  Begegnungen %d  Beute %d  Rumpf %d  Proviant %d" % [
			"SIEG" if won else "NIEDERLAGE (%s)" % why, stage, level, turns, roundi(total_miles), alive_count(), fallen_names.size(), rescued_count,
			encounters_done, roundi(loot), roundi(hull), proviant])
	finished.emit(won)


## Verzweiflung wächst je nach Eigenschaften schneller oder langsamer, Erleichterung wirkt immer voll.
func _add_stress(m: CrewMember, amount: float) -> void:
	if amount > 0.0:
		amount *= m.stress_factor() * stat("stress")
	m.stress = maxf(m.stress + amount, 0.0)


func _pick_weighted(pool: Array[CrewMember]) -> CrewMember:
	var total := 0.0
	for m in pool:
		total += m.wash_factor()
	var r := randf() * total
	for m in pool:
		r -= m.wash_factor()
		if r < 0.0:
			return m
	return pool[pool.size() - 1]


## Merkt sich ein Ereignis für die Saga; Todesursachen auch für den Gedenkstein.
func _note(type: String, who: String = "", extra: int = -1, other: String = "") -> void:
	saga_events.append({"type": type, "name": who, "extra": extra, "other": other})
	match type:
		"drowned":
			death_causes[who] = "ertrunken"
		"abandoned":
			death_causes[who] = "zurückgelassen"
		"starved":
			death_causes[who] = "verhungert"
		"killed":
			death_causes[who] = ("gefallen: %s" % String(Encounters.DATA[extra]["name"])) if extra >= 0 else "gefallen"


## Meldung für den Spieler (z. B. aus Main), im Protokoll sichtbar.
func say(text: String, kind: int = Kind.FACT) -> void:
	_fact(text, kind)


# --- Speichern und Fortsetzen -----------------------------------------------

func to_dict() -> Dictionary:
	var crew_data: Array = []
	for m in crew:
		crew_data.append(_man_dict(m))
	var reserve_data: Array = []
	for m in reserve:
		reserve_data.append(_man_dict(m))
	return {
		"v": 2, "map": map, "mile": mile, "pos": pos, "hull": hull, "proviant": proviant, "loot": loot,
		"turns": turns, "enc_done": encounters_done, "rescued": rescued_count, "sea_view": sea_view, "dials": [sail_set, oars_set, coast_set],
		"stage": stage, "theme": theme, "total_miles": total_miles, "leg": leg, "route": route, "level": level, "xp": xp, "powder": powder,
		"perks": perks, "perk_offer": perk_offer, "perk_pending": _perk_pending, "items": items, "stash": stash, "pfand": pfand,
		"fallen_names": fallen_names, "start_names": start_names, "death_causes": death_causes,
		"saga": saga_events, "storm_noted": _storm_noted, "crew": crew_data, "bonds": bonds, "relief": relief,
		"reserve": reserve_data, "next_id": _next_id, "food_acc": _food_acc, "camps": camps_used,
		"history": history.slice(maxi(history.size() - 20, 0)),
	}


## Setzt eine gespeicherte Fahrt fort (immer an einem Planungspunkt).
## Ereignisse eines Knotens aus dem Spielstand (JSON liefert Zahlen als Gleitkomma).
static func _mid_from(a: Variant) -> Array:
	var out: Array = []
	if a is Array:
		for ev in a:
			if ev is Dictionary and (ev as Dictionary).has("id"):
				out.append({"to": int(ev["to"]), "id": int(ev["id"]), "t": float(ev["t"]), "done": bool(ev.get("done", false))})
	return out


func resume(d: Dictionary) -> void:
	map.clear()
	for col in d["map"]:
		var column: Array = []
		for nd in col:
			column.append({
				"sea": int(nd["sea"]), "hazard": int(nd["hazard"]), "enc": int(nd["enc"]),
				"links": Traits.typed(nd["links"]), "visited": bool(nd.get("visited", false)), "cove": bool(nd.get("cove", false)),
				"mid": _mid_from(nd.get("mid", [])),
			})
		map.append(column)
	mile = int(d["mile"])
	pos = int(d["pos"])
	hull = float(d["hull"])
	proviant = int(d["proviant"])
	loot = float(d["loot"])
	turns = int(d["turns"])
	stage = int(d.get("stage", 1))
	relief = bool(d.get("relief", true))
	theme = clampi(int(d.get("theme", 0)), 0, THEMES.size() - 1)
	total_miles = float(d.get("total_miles", 0.0))
	leg = float(d.get("leg", 0.0))
	route = int(d.get("route", -1))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	powder = int(d.get("powder", 0))
	_perk_pending = int(d.get("perk_pending", 0))
	perks = []
	for id in d.get("perks", []):
		if Perks.DATA.has(String(id)):
			perks.append(String(id))
	perk_offer = []
	for id in d.get("perk_offer", []):
		if Perks.DATA.has(String(id)):
			perk_offer.append(String(id))
	items = {}
	var saved_items: Dictionary = d.get("items", {})
	for k in saved_items:
		if Items.valid(String(saved_items[k])):
			items[int(k)] = String(saved_items[k])
	stash = []
	for k in d.get("stash", []):
		if Gear.valid(String(k)) and stash.size() < Gear.STASH_MAX:
			stash.append(String(k))
	pfand = clampi(int(d.get("pfand", 0)), 0, Items.PFAND_MAX)
	gear_shop = []
	_mods = {}
	shop = []
	shop_open = false
	var dials: Array = d.get("dials", [1, 1, 1])
	sail_set = clampi(int(dials[0]), 0, 2)
	oars_set = clampi(int(dials[1]), 0, 2)
	coast_set = clampi(int(dials[2]), 0, 2)
	encounters_done = int(d["enc_done"])
	rescued_count = int(d["rescued"])
	_storm_noted = bool(d.get("storm_noted", false))
	fallen_names.clear()
	for nm in d["fallen_names"]:
		fallen_names.append(String(nm))
	start_names.clear()
	for nm in d["start_names"]:
		start_names.append(String(nm))
	death_causes = d.get("death_causes", {})
	saga_events = d.get("saga", [])
	bonds = []
	for bd in d.get("bonds", []):
		bonds.append({"a": int(bd["a"]), "b": int(bd["b"]), "type": int(bd["type"])})
	history = d.get("history", [])
	crew.clear()
	slot_owner.clear()
	slot_owner.resize(Stations.SLOTS.size())
	for cd in d["crew"]:
		var m := _man_from(cd)
		crew.append(m)
		if m.state == CrewMember.State.ABOARD and m.slot >= 0:
			slot_owner[m.slot] = m
	reserve.clear()
	for cd in d.get("reserve", []):
		var rm := _man_from(cd)
		rm.state = CrewMember.State.RESERVE
		rm.slot = -1
		reserve.append(rm)
	_next_id = int(d.get("next_id", 100))
	_food_acc = float(d.get("food_acc", 0.0))
	camps_used = int(d.get("camps", 0))
	sea_view = location_sea()
	storm = _storm_for(sea_view)
	_lore("resume")
	_start_plan()


# --- Deckkampf -------------------------------------------------------------------

## Einen Deckkampf vorbereiten: man wählt die Aufstellung, dann beginnt der Kampf. ctx sagt, was danach geschieht:
## {"source": "encounter", "win_fx", "win_lore", "lose_lore", "pass_lore"} oder {"source": "board"} (Seeschlacht).
func start_fight(formation: String, ctx: Dictionary, count: int = -1, hp_scale: float = 1.0) -> void:
	phase = Phase.COMBAT
	traveling = false
	selected = null
	combat = null
	var pool: Array[CrewMember] = []
	for m in crew:
		if m.state == CrewMember.State.ABOARD:
			pool.append(m)
	for m in reserve:
		pool.append(m)
	fight_prep = {
		"formation": formation, "units": Foes.units_for(formation, stage, count), "party": Combat.auto_party(self),
		"pool": pool, "ctx": ctx, "hp_scale": hp_scale,
	}
	Sfx.play("kraken_roar" if formation == "kraken" else "sting")
	_fact("Zum Kampf: %s." % String(Foes.FORMATIONS[formation]["name"]), Kind.BAD)
	if auto_combat:
		fight_begin()
		if combat != null:
			combat.auto_play()
			_end_fight()


## Aufstellung bestätigt: der Kampf beginnt.
func fight_begin() -> bool:
	if fight_prep.is_empty() or (fight_prep["party"] as Array).is_empty():
		return false
	var units: Array[String] = []
	for u in fight_prep["units"]:
		units.append(String(u))
	combat = Combat.create(self, String(fight_prep["formation"]), fight_prep["party"], units, stage, float(fight_prep["hp_scale"]))
	combat_ctx = fight_prep["ctx"]
	fight_prep = {}
	combat.begin()
	_combat_t = COMBAT_PACE + 0.2
	return true


## In der Aufstellung einen Mann aufnehmen oder wieder herausnehmen (höchstens vier).
func fight_toggle(m: CrewMember) -> void:
	if fight_prep.is_empty():
		return
	var party: Array = fight_prep["party"]
	if party.has(m):
		party.erase(m)
	elif party.size() < 4:
		party.append(m)


## Einen Kämpfer in der Aufstellung eine Reihe weiter nach vorn (-1) oder hinten (+1) schieben.
func fight_shift(m: CrewMember, dir: int) -> void:
	if fight_prep.is_empty():
		return
	var party: Array = fight_prep["party"]
	var i := party.find(m)
	var j := i + dir
	if i < 0 or j < 0 or j >= party.size():
		return
	party[i] = party[j]
	party[j] = m


func fight_auto_party() -> void:
	if not fight_prep.is_empty():
		fight_prep["party"] = Combat.auto_party(self)


func combat_act(skill_id: String, target: Combat.Fighter = null) -> bool:
	if combat == null or phase != Phase.COMBAT:
		return false
	var ok := combat.hero_act(skill_id, target)
	if ok:
		_combat_t = COMBAT_PACE
	return ok


func combat_move(to_rank: int) -> bool:
	var ok := combat != null and combat.hero_move(to_rank)
	if ok:
		_combat_t = COMBAT_PACE
	return ok


func combat_pass() -> bool:
	var ok := combat != null and combat.hero_pass()
	if ok:
		_combat_t = COMBAT_PACE
	return ok


func combat_flee() -> bool:
	return combat != null and combat.hero_flee()


## Die Kampfregie meldet, dass sie noch so lange inszeniert; nie mehr als 4 s, nie im Schnellmodus.
func combat_stage(seconds: float) -> void:
	if combat != null and not auto_combat:
		stage_t = minf(maxf(stage_t, seconds), 4.0)


func _tick_combat(delta: float) -> void:
	if combat == null:
		return
	stage_t = maxf(stage_t - delta, 0.0)
	if combat.state == "done":
		if stage_t > 0.0:
			return
		if combat_outro > 0.0:
			# Schlussansage (Sieg, Niederlage, Rückzug) im echten Spiel: erst warten, dann weiter
			if _outro_t < 0.0:
				_outro_t = combat_outro
			_outro_t -= delta
			if _outro_t > 0.0:
				return
		_end_fight()
		return
	if combat.state == "foe":
		_combat_t -= delta
		if _combat_t <= 0.0 and stage_t <= 0.0:
			combat.act_foe()
			_combat_t = COMBAT_PACE


## Der Kampf ist aus: Kraft und Verluste zurückschreiben, dann wie nach einer Begegnung weiter.
func _end_fight() -> void:
	var c := combat
	if c == null:
		return
	var ctx := combat_ctx
	_outro_t = -1.0
	c.finish()
	for m in c.casualties:
		_combat_casualty(m)
	for m in c.overboard:
		if m.state == CrewMember.State.ABOARD:
			_fact("%s wird vom Kraken über Bord gezerrt." % m.display_name, Kind.BAD)
			_throw_overboard(m)
		else:
			# ein Reservist: die Kameraden ziehen ihn halb ertrunken zurück
			m.kraft = minf(m.kraft, 15.0)
			_add_stress(m, 15.0)
			_fact("%s wird halb ertrunken aus dem Wasser gezogen (Kraft 15)." % m.display_name, Kind.BAD)
	var res := c.result
	combat = null
	combat_ctx = {}
	phase = Phase.RESOLVE
	traveling = false
	match res:
		"win":
			_fact("Der Kampf ist gewonnen (%d Gegner gefallen, %d geflohen)." % [c.killed, c.fled], Kind.GOOD)
		"lose":
			_fact("Der Kampf ist verloren: niemand steht mehr.", Kind.BAD)
		_:
			_fact("Ihr zieht euch zurück.", Kind.BAD)
	for h in c.all_heroes:
		if h.man != null and not h.gone and h.door:
			_fact("%s ist schwer verwundet (Kraft 10)." % h.name, Kind.BAD)
	if res == "win":
		if c.formation == "kraken":
			_find_gear(Items.Rarity.EPISCH, 1.5, "Aus dem Wrack des Kraken")
		elif randf() < 0.35:
			_find_gear(0, 0.5, "Beute vom Kampf")
		if randf() < (0.5 if c.formation == "kraken" else 0.04):
			_find_pfand("Aus dem Kampf")
		if automat_bonus_on and not automat_open and (c.formation == "kraken" or randf() < 0.3):
			_lore("slot_bonus")
			automat_enter("bonus", Slots.bonus_bet(stage, c.formation == "kraken"), c.formation == "kraken")  # der Kraken löst sicher die Freispiele aus
	_check_breakdown()
	if String(ctx.get("source", "")) == "board":
		var b := battle
		if res == "win":
			b["ecrew"] = 0
		elif res == "lose":
			b["ecrew"] = maxi(int(b["ecrew"]) - c.killed, 1)
		_steps = [{"delay": 0.8, "fn": Battle.enemy.bind(self, "board")}, {"delay": 1.0, "fn": Battle.after.bind(self, "board")}]
	else:
		var outcome: Dictionary
		if res == "win":
			outcome = {"fx": ctx.get("win_fx", {}), "lore": String(ctx.get("win_lore", ""))}
		elif res == "lose":
			outcome = {"fx": {"stress_all": 8}, "lore": String(ctx.get("lose_lore", ""))}
		else:
			outcome = {"fx": {"stress_all": 4}, "lore": String(ctx.get("pass_lore", ""))}
		_steps = [{"delay": 0.8, "fn": _apply_outcome.bind(outcome)}, {"delay": 1.2, "fn": _after_encounter}]
	_step_left = float(_steps[0]["delay"])


func _combat_casualty(m: CrewMember) -> void:
	var on_deck := m.state == CrewMember.State.ABOARD
	reserve.erase(m)
	_note("killed", m.display_name, encounter)
	if encounter < 0:
		death_causes[m.display_name] = "gefallen: Deckkampf"
	_kill(m, on_deck)
	_fact("%s ist im Kampf gefallen." % m.display_name, Kind.BAD)


# --- Lager ----------------------------------------------------------------------

## Ist die Küste hier sicher genug für ein Lager? Eine Ankerbucht, oder ruhige See ohne Gefahr.
func camp_site_ok() -> bool:
	var nd := here()
	return bool(nd.get("cove", false)) or (int(nd["sea"]) <= 2 and int(nd["hazard"]) == Sea.Hazard.NONE)


## Leer, wenn man jetzt lagern kann; sonst der Grund.
func camp_reason() -> String:
	if phase != Phase.PLAN or ended or camping:
		return "Nur in der Planung."
	if leg > 0.0:
		return "Nur an einem Knoten, nicht zwischen zwei Knoten."
	if mile < 1 or mile >= MILES:
		return "Im Hafen rastet man in der Taverne."
	if camps_used >= 1:
		return "Auf dieser Etappe wurde schon gelagert."
	if not camp_site_ok():
		return "Zu rau: ein Lager geht nur bei ruhiger See ohne Gefahr oder in einer Ankerbucht."
	if proviant < Camp.PROVIANT_COST:
		return "Zu wenig Proviant (%d nötig)." % Camp.PROVIANT_COST
	if not perk_offer.is_empty():
		return "Erst den Segen wählen."
	return ""


func can_camp() -> bool:
	return camp_reason() == ""


## Das Lager schlagen: kostet Proviant, gibt Lagerpunkte. Ankerbuchten sind sicher, offene Küste nicht.
func camp_start() -> void:
	if camping or not can_camp():
		return
	camping = true
	proviant -= Camp.PROVIANT_COST
	camps_used += 1
	camp_points = Camp.POINTS
	camp_done = {}
	camp_slept = false
	camp_watch = null
	selected = null
	Sfx.play("rope")
	_fact("Das Lager wird aufgeschlagen (Proviant −%d, noch %d)." % [Camp.PROVIANT_COST, proviant], Kind.FACT)
	_lore("camp_start")


func camp_do(id: String) -> bool:
	if not camping or not Camp.DATA.has(id) or Camp.why_not(self, id) != "":
		return false
	camp_points -= int(Camp.DATA[id]["cost"])
	camp_done[id] = int(camp_done.get(id, 0)) + 1
	Camp.apply(self, id)
	return true


## Aufbrechen: die Nacht wird abgewickelt (Überfall, Sturm, Fremde, Fund), dann geht es weiter.
func camp_end() -> void:
	if not camping:
		return
	camping = false
	selected = null
	_camp_night()
	_check_breakdown()
	if hull <= 0.0:
		_end(false, "sunk")
		return
	if alive_count() == 0 and reserve.is_empty():
		_end(false, "all_dead")
		return
	_fill_from_reserve()
	sea_view = location_sea()
	if autosave:
		Persist.save_run(self)


## Chance auf ein Nachtereignis: Ankerbucht klein, offene Küste größer; Schlaf ohne Wache riskanter; später und in Piraten- und Totensee mehr.
func camp_night_chance() -> float:
	var p := 0.05 if bool(here().get("cove", false)) else 0.22
	if not camp_slept:
		p *= 0.5
	if camp_watch != null:
		p *= 0.25
	p *= 1.0 + 0.08 * float(stage - 1)
	if theme == 3 or theme == 4:
		p *= 1.4
	return clampf(p, 0.0, 0.6)


func _camp_night() -> void:
	if randf() >= camp_night_chance():
		_fact("Die Nacht bleibt ruhig. Im Morgengrauen bricht das Lager auf.", Kind.GOOD)
		_lore("camp_quiet")
		return
	var r := randf()
	if r < 0.42:
		_camp_raid()
	elif r < 0.67:
		var dmg := 6.0 * stage_mul()
		_damage(dmg)
		for m in Camp.everyone(self):
			_add_stress(m, 6.0)
		impact = 0.6
		Sfx.play("gust")
		_fact("Ein Sturm zieht über die Bucht: Rumpf −%d, Verzweiflung +6 für alle." % roundi(dmg), Kind.BAD)
		_lore("camp_storm")
	elif r < 0.85:
		proviant += 3
		_fact("Ein Fremder setzt sich ans Feuer und teilt seinen Vorrat: Proviant +3.", Kind.GOOD)
		_lore("camp_stranger")
	else:
		var gain := roundi(25.0 * stat("loot") * (1.0 + 0.12 * float(stage - 1)))
		loot += float(gain)
		Sfx.play("coin")
		_fact("Am Strand liegt etwas, das das Meer nicht wollte: Beute +%d (%s)." % [gain, Encounters.booty_for("camp", true)], Kind.GOOD)
		_lore("camp_find")


func _camp_raid() -> void:
	var foe := "Draugr" if theme == 4 else "Räuber"
	var ch := clampf(0.45 + 0.4 * strength() + (0.15 if camp_watch != null else 0.0) - 0.04 * float(stage - 1), 0.15, 0.92)
	Sfx.play("sting")
	_fact("In der Nacht greifen %s an. Die Aussicht, sie abzuwehren: %d %%." % [foe, roundi(ch * 100.0)], Kind.BAD)
	if randf() < ch:
		for k in 2:
			var m := _random_aboard()
			if m != null:
				m.kraft = maxf(m.kraft - 15.0, 0.0)
		for m in Camp.everyone(self):
			_add_stress(m, 5.0)
		var msg := "Ihr schlagt sie zurück: zwei Männer verletzt (Kraft −15)."
		if theme != 4:
			var gain := roundi(20.0 * stat("loot"))
			loot += float(gain)
			msg += " Der Beutel eines Räubers bleibt liegen: Beute +%d." % gain
		_fact(msg, Kind.GOOD)
		_lore("camp_raid_win")
	else:
		var lost := mini(roundi(loot), 30)
		loot -= float(lost)
		for k in 2:
			var m2 := _random_aboard()
			if m2 != null:
				m2.kraft = maxf(m2.kraft - 25.0, 0.0)
		for m in Camp.everyone(self):
			_add_stress(m, 10.0)
		var msg2 := "Ihr werdet überrumpelt: Beute −%d, zwei Männer verletzt (Kraft −25)." % lost
		var victim: CrewMember = null
		if randf() < 0.35:
			victim = _random_aboard()
		if victim != null:
			_kill(victim, true)
			_note("killed", victim.display_name, -1)
			death_causes[victim.display_name] = "gefallen: Überfall im Lager"
			msg2 += " %s fällt." % victim.display_name
		_fact(msg2, Kind.BAD)
		_lore("camp_raid_lose")


# --- Reserve ---------------------------------------------------------------------

## Plätze unter Deck: 2, mit Hängematten bis 5.
func reserve_cap() -> int:
	return clampi(RESERVE_BASE + roundi(stat("reserve")), RESERVE_BASE, RESERVE_MAX)


func reserve_free() -> int:
	return maxi(reserve_cap() - reserve.size(), 0)


## Alle Männer an Bord, auch die unter Deck (Überbordgegangene zählen mit, bis sie gerettet oder verloren sind).
func headcount() -> int:
	return alive_count() + reserve.size()


## Zusatzproviant dieser Fahrt: ab dem achten Mann kommt ein halber Proviant je Mann dazu.
func extra_food() -> int:
	var e := maxi(headcount() - Stations.SLOTS.size(), 0)
	return floori(_food_acc + float(e) / 2.0)


func _take_extra_food() -> int:
	var e := maxi(headcount() - Stations.SLOTS.size(), 0)
	var total := _food_acc + float(e) / 2.0
	var n := floori(total)
	_food_acc = total - float(n)
	return n


## Umstellen darf man in der Planung, im Hafen und im Lager.
func can_arrange() -> bool:
	if camping:
		return true
	if phase == Phase.PLAN:
		return true
	return phase == Phase.ENCOUNTER and Encounters.is_harbor(encounter)


## Die Reserve kommt nur im Hafen, im Lager und am Anfang einer Etappe an Deck.
func can_use_reserve() -> bool:
	if camping:
		return true
	if phase == Phase.ENCOUNTER and Encounters.is_harbor(encounter):
		return true
	return phase == Phase.PLAN and mile == 0 and leg <= 0.0


func _swap_any(a: CrewMember, b: CrewMember) -> void:
	var a_res := a.state == CrewMember.State.RESERVE
	var b_res := b.state == CrewMember.State.RESERVE
	if not a_res and not b_res:
		_swap(a, b)
	elif a_res and b_res:
		return
	elif can_use_reserve():
		_swap_reserve(a if a_res else b, b if a_res else a)
	else:
		_fact("Die Reserve kommt nur im Hafen, im Lager oder am Anfang einer Etappe an Deck.", Kind.FACT)


## Ein Reservist nimmt den Platz eines Mannes an Deck, der dafür unter Deck geht.
func _swap_reserve(res: CrewMember, act: CrewMember) -> void:
	var seat := act.slot
	var idx := crew.find(act)
	var ridx := reserve.find(res)
	if seat < 0 or idx < 0 or ridx < 0:
		return
	slot_owner[seat] = res
	res.slot = seat
	res.state = CrewMember.State.ABOARD
	res.home_slot = -1
	act.slot = -1
	act.state = CrewMember.State.RESERVE
	crew[idx] = res
	reserve[ridx] = act
	if selected == act or selected == res:
		selected = null


## Ein Reservist setzt sich auf einen freien Platz; er ersetzt den Eintrag eines Gefallenen in der Mannschaftsliste.
func _reserve_to_seat(res: CrewMember, seat: int) -> void:
	var idx := _dead_entry()
	if idx < 0 or slot_owner[seat] != null or not reserve.has(res):
		return
	var dead := crew[idx]
	bonds = bonds.filter(func(bd: Dictionary) -> bool: return int(bd["a"]) != dead.id and int(bd["b"]) != dead.id)
	crew[idx] = res
	reserve.erase(res)
	res.state = CrewMember.State.ABOARD
	res.slot = seat
	res.home_slot = -1
	slot_owner[seat] = res


## Wo Plätze frei sind (Gefallene), rückt der frischeste Reservist nach.
func _fill_from_reserve() -> void:
	if reserve.is_empty():
		return
	for i in slot_owner.size():
		if slot_owner[i] != null or _dead_entry() < 0 or reserve.is_empty():
			continue
		var best: CrewMember = reserve[0]
		for r in reserve:
			if r.kraft > best.kraft:
				best = r
		_fact("Die Reserve rückt nach: %s übernimmt den Platz am %s." % [best.display_name, Stations.NAMES[Stations.slot_station(i)]], Kind.GOOD)
		_reserve_to_seat(best, i)


## Wachablösung mit der Reserve: wo man umstellen darf, ersetzt ein frischer Reservist den Müdesten an Deck.
func _relief_reserve() -> void:
	if reserve.is_empty() or not can_use_reserve():
		return
	for k in reserve.size():
		var tired: CrewMember = null
		for m in crew:
			if m.state == CrewMember.State.ABOARD and m.slot >= 0 and Stations.slot_station(m.slot) != Stations.Id.LADUNG:
				if m.kraft < CrewMember.TIRED_AT and (tired == null or m.kraft < tired.kraft):
					tired = m
		if tired == null:
			return
		var best: CrewMember = null
		for r in reserve:
			if r.kraft >= 50.0 and r.kraft >= tired.kraft + 25.0 and (best == null or r.kraft > best.kraft):
				best = r
		if best == null:
			return
		_fact("Wachablösung: %s (Kraft %d) kommt von unten und löst %s (Kraft %d) ab." % [best.display_name, roundi(best.kraft), tired.display_name, roundi(tired.kraft)], Kind.FACT)
		_swap_reserve(best, tired)


## Die Männer unter Deck erholen sich bei jeder Fahrt.
func _reserve_rest() -> void:
	for r in reserve:
		r.kraft = minf(r.kraft + 15.0, 100.0)
		r.stress = maxf(r.stress - 3.0, 0.0)


func _kill_reserve(m: CrewMember, why: String) -> void:
	reserve.erase(m)
	_kill(m, false)
	_fact("%s ist verhungert." % m.display_name, Kind.BAD)
	_lore("starved", m.display_name)
	_note(why, m.display_name)


## Einen Reservisten entlassen (Hafen, Lager, Etappenanfang). Wer ihm nahestand, nimmt es schwer.
func dismiss(m: CrewMember) -> bool:
	if m.state != CrewMember.State.RESERVE or not reserve.has(m) or not can_use_reserve():
		return false
	reserve.erase(m)
	if selected == m:
		selected = null
	for p in bond_partners(m):
		var o: CrewMember = p["other"]
		if o.state == CrewMember.State.ABOARD or o.state == CrewMember.State.RESERVE:
			_add_stress(o, 8.0)
	bonds = bonds.filter(func(bd: Dictionary) -> bool: return int(bd["a"]) != m.id and int(bd["b"]) != m.id)
	_fact("%s geht von Bord." % m.display_name, Kind.FACT)
	return true


func _man_dict(m: CrewMember) -> Dictionary:
	return {
		"id": m.id, "name": m.display_name, "look": m.look, "state": int(m.state), "slot": m.slot,
		"kraft": m.kraft, "stress": m.stress, "afflicted": m.afflicted, "affliction": m.affliction,
		"traits": m.traits, "role": m.role, "loadout": m.loadout, "weapon": m.weapon_lvl, "armor": m.armor_lvl, "slv": m.skill_lvl, "gear": m.gear,
	}


func _man_from(cd: Dictionary) -> CrewMember:
	var m := CrewMember.new()
	m.id = int(cd["id"])
	m.display_name = String(cd["name"])
	m.look = int(cd["look"])
	m.state = int(cd["state"]) as CrewMember.State
	m.slot = int(cd["slot"])
	m.kraft = float(cd["kraft"])
	m.stress = float(cd["stress"])
	m.afflicted = bool(cd["afflicted"])
	m.affliction = int(cd["affliction"])
	m.traits = Traits.typed(cd["traits"])
	m.role = int(cd.get("role", Roles.random_role()))
	m.loadout = Roles.valid_loadout(m.role, cd.get("loadout", []))
	for gs in (cd.get("gear", {}) as Dictionary):
		if Gear.valid(String((cd["gear"] as Dictionary)[gs])) and Gear.slot_of(String((cd["gear"] as Dictionary)[gs])) == int(gs):
			m.gear[int(gs)] = String((cd["gear"] as Dictionary)[gs])
	m.weapon_lvl = clampi(int(cd.get("weapon", 0)), 0, WEAPON_MAX)
	m.armor_lvl = clampi(int(cd.get("armor", 0)), 0, ARMOR_MAX)
	for sid in (cd.get("slv", {}) as Dictionary):
		if Roles.SKILLS.has(String(sid)):
			m.skill_lvl[String(sid)] = clampi(int((cd["slv"] as Dictionary)[sid]), 0, Roles.max_level(String(sid)))
	return m


func _swap(a: CrewMember, b: CrewMember) -> void:
	var sa := a.slot
	var sb := b.slot
	slot_owner[sa] = b
	slot_owner[sb] = a
	a.slot = sb
	b.slot = sa


func _first_free_slot() -> int:
	for i in slot_owner.size():
		if slot_owner[i] == null:
			return i
	return -1


func _damage(amount: float) -> void:
	if amount <= 0.0:
		return
	hull -= amount
	_turn_damage += amount


func _fact(text: String, kind: int = Kind.FACT) -> void:
	_log(text, kind)


func _lore(key: String, n: String = "", r: String = "") -> void:
	_log(Skalde.line(key, n, r), Kind.LORE)


func _log(text: String, kind: int) -> void:
	history.append({"text": text, "kind": kind})
	if history.size() > 60:
		history.pop_front()
	if log_enabled:
		print("[Fahrt %d] %s" % [turns, text])
	log_added.emit(text, kind)
