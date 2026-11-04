class_name Tips
extends RefCounted

## Erklärtexte für die Tooltips der Oberfläche: was bedeutet ein Wert, wie kommt er zustande, was kann man tun.
## Ein Tooltip ist {"t": Titel, "l": [[Zeile, Farbe], ...]}. Farben: n = normal, d = gedämpft, g = Gold, r = Rot, k = Grün.

const GOLD := Color("d9b24a")
const PAPER := Color("e6e0cc")
const DIM := Color("a3a9b0")
const RED := Color("d2564b")
const GREEN := Color("7ab85a")
const VIOLET := Color("a97fd6")

const HAZARD_TEXT := {
	Sea.Hazard.BRECHER: "Hohe, brechende Wellen schlagen auf das Deck. Sie beschädigen den Rumpf und reißen manchmal einen Mann über Bord.",
	Sea.Hazard.BOE: "Eine plötzliche Böe packt das Segel. Sie beschädigt den Rumpf und kann Männer über Bord werfen.",
	Sea.Hazard.RIFF: "Felsen dicht unter der Wasserfläche. Sie reißen den Rumpf auf, und beim Ausweichen geht Beute über Bord.",
	Sea.Hazard.NEBEL: "Man sieht die Hand vor Augen nicht und läuft auf Treibgut und Untiefen. Das beschädigt den Rumpf. Außerdem kennt man auf dieser Meile nur den nächsten Knoten.",
}


static func _tip(title: String, lines: Array) -> Dictionary:
	return {"t": title, "l": lines}


static func _l(text: String, col: Color = PAPER) -> Array:
	return [text, col]


static func _pct(x: float) -> String:
	return "%d %%" % roundi(x * 100.0)


## Welche Reglerstellungen schützen wie stark vor einer Gefahr (aus Strategy.COUNTER).
static func protection_text(hz: int) -> String:
	var c: Array = Strategy.COUNTER[hz]
	var parts: Array[String] = []
	for dial in 3:
		for lv in 3:
			var v := float(c[dial][lv])
			if v > 0.0:
				parts.append("%s %s %s" % [Strategy.DIAL_NAMES[dial], Strategy.LEVEL_NAMES[dial][lv], _pct(v)])
			elif v < 0.0:
				parts.append("%s %s %s" % [Strategy.DIAL_NAMES[dial], Strategy.LEVEL_NAMES[dial][lv], "verschlimmert"])
	return ", ".join(PackedStringArray(parts))


## Eine Gefahr auf dem Weg: Wirkung, Rechnung und was man dagegen tun kann. row ist eine Zeile aus Voyage.plan().
static func hazard(voy: Voyage, hz: int, row: Dictionary = {}) -> Dictionary:
	var base: Dictionary = Sea.HAZARD[hz]
	var lines: Array = [_l(String(HAZARD_TEXT[hz]))]
	var hm := voy.stat("hazard") * voy.stage_mul()
	if not row.is_empty():
		var mit := float(row["mit"])
		lines.append(_l("Grundschaden %d × Etappenhärte %s%s = %d" % [roundi(float(base["damage"])), Voyage.fmt(voy.stage_mul()), "" if absf(voy.stat("hazard") - 1.0) < 0.01 else " × Schutz der Gegenstände", roundi(float(base["damage"]) * hm)], DIM))
		lines.append(_l("Dein Schutz mit dieser Stellung: %s%s" % [_pct(mit), "" if mit >= 0.0 else " (es wird schlimmer)"], GREEN if mit >= 0.7 else (GOLD if mit >= 0.3 else RED)))
		lines.append(_l("→ Rumpf −%d%s%s" % [roundi(float(row["h_dmg"])), (", Beute −%d" % roundi(float(row["h_loot"]))) if float(row["h_loot"]) > 0.0 else "", (", Mann über Bord %s" % _pct(float(row["h_over"]))) if float(row["h_over"]) > 0.0 else ""], RED if mit < 0.3 else PAPER))
	lines.append(_l("Schutz durch die Regler:", GOLD))
	lines.append(_l(protection_text(hz), DIM))
	if hz == Sea.Hazard.NEBEL:
		lines.append(_l("Im Nebel sieht man nur eine Meile voraus.", DIM))
	return _tip(String(Sea.HAZARD_NAMES[hz]), lines)


## "Über Bord (See): N %": das Risiko, dass die See einen Mann holt.
static func wash(voy: Voyage, pct: int) -> Dictionary:
	var sea := voy.location_sea()
	return _tip("Über Bord (See)", [
		_l("Je rauer die See, desto eher spült sie einen Mann vom Deck. Auf dieser Strecke ist die Chance zusammen %d %%." % pct),
		_l("Sie wächst mit dem Seegang (jetzt %s) und mit dem Segel voll oder der Küste weit; Küste nah senkt sie." % Sea.SEA_NAMES[sea], DIM),
		_l("Wer über Bord geht, kann mit dem Seil gerettet werden: das kostet Proviant, vielleicht Rumpf und Kraft.", DIM),
	])


static func miles(voy: Voyage, p: Dictionary) -> Dictionary:
	var lines: Array = [
		_l("So weit kommt das Schiff in dieser Fahrt (eine Wache). Eine Meile ist der Abstand zwischen zwei Knoten, es geht also auch zwischen zwei Knoten weiter."),
		_l("Vortrieb der Regler: %s Meilen × Besetzung %s = %s" % [Voyage.fmt(float(p["want"])), _pct(float(p["ratio"])), Voyage.fmt(float(p["miles"]))], DIM),
		_l("An jeder Gabelung und an jeder Begegnung hält das Schiff an; der Rest der Strecke verfällt.", DIM),
	]
	return _tip("Meilen", lines)


static func arrival(voy: Voyage, p: Dictionary) -> Dictionary:
	var stop := String(p["stop"])
	var lines: Array = [_l("Dort kommt das Schiff nach dieser Fahrt an. Jeder erreichte Knoten wird einzeln abgehandelt: Seegang und Gefahr schlagen zu.")]
	if stop == "fork":
		lines.append(_l("Gabelung: das Schiff hält an, du wählst danach den weiteren Weg.", GOLD))
	elif stop == "encounter" or stop == "end":
		lines.append(_l("Halt: hier wartet eine Begegnung (oder der Hafen). Der Rest der Strecke verfällt.", GOLD))
	return _tip("Ankunft", lines)


static func food(voy: Voyage, p: Dictionary) -> Dictionary:
	var left := voy.proviant - int(p["proviant"])
	var to_harbor := voy.harbor_distance()
	var lines: Array = [
		_l("Proviant ist die Uhr der Fahrt: jede Fahrt kostet %d, egal wie weit sie kommt. Wer langsam fährt, zahlt pro Meile mehr." % int(p["proviant"])),
		_l("Danach bleiben %d. Der nächste Hafen ist %s Meilen entfernt." % [maxi(left, 0), Voyage.fmt(to_harbor)], DIM),
	]
	if float(left) < to_harbor + 1.0:
		lines.append(_l("Das wird knapp: ohne Proviant wächst die Verzweiflung, die Kraft schwindet und Erschöpfte sterben.", RED))
	else:
		lines.append(_l("Das reicht bis zum Hafen.", GREEN))
	return _tip("Proviant", lines)


static func hull(voy: Voyage, p: Dictionary) -> Dictionary:
	var lines: Array = [
		_l("Der Rumpf ist der Zustand des Schiffes. Bei 0 sinkt es."),
		_l("Seegang ab Raue See (3) und Gefahren beschädigen ihn, Zimmerleute flicken ihn: Seegang −%d, Gefahren −%d, Reparatur +%d." % [roundi(float(p["strain"])), roundi(float(p["hazard_dmg"])), roundi(float(p["repair"]))], DIM),
	]
	return _tip("Rumpf", lines)


static func crewing(ratio: float) -> Dictionary:
	return _tip("Besetzung", [
		_l("Ruder, Segel und Steuer brauchen genug Hände. Bei %s Besetzung fährt das Schiff nur so viel von dem, was die Regler versprechen." % _pct(ratio)),
		_l("Männer auf diesen Plätzen werden mit der Mannschaftsansicht (C) oder per Klick getauscht; wer müde ist, arbeitet schlechter. Die Wachablösung (A) tauscht Müde automatisch gegen den Mann auf der Ladungsbank.", DIM),
	])


## Die vier Müdigkeitsstufen eines Mannes mit seinen Zahlen.
static func fatigue(m: CrewMember) -> Dictionary:
	var lines: Array = [
		_l("Kraft %d. Stufe: %s, Leistung %s." % [roundi(m.kraft), m.fatigue_name(), _pct(CrewMember.kraft_efficiency(m.kraft))]),
		_l("frisch ab 70 (100 %) · müde ab 40 (90–100 %) · erschöpft ab 15 (65–90 %) · am Ende darunter (35–65 %, Verzweiflung wächst).", DIM),
		_l("Arbeit kostet Kraft, die Ladungsbank und Beidrehen erholen. Im Hafen hilft Rasten (+30).", DIM),
	]
	return _tip("Müdigkeit", lines)


static func relief(voy: Voyage) -> Dictionary:
	return _tip("Wachablösung", [
		_l("Ist sie an, löst vor jeder Fahrt der frischeste Mann von der Ladungsbank den Müdesten ab, sobald der unter 40 Kraft fällt und der Ruhende mindestens 25 Kraft mehr hat. Das Umsetzen von Hand entfällt.", GREEN if voy.relief else DIM),
		_l("Der Tausch steht im Protokoll und in der Aufstellung; du kannst ihn jederzeit selbst rückgängig machen. Taste A schaltet um.", DIM),
	])


static func tired(names: Array) -> Dictionary:
	return _tip("Erschöpft", [
		_l("Diese Männer fallen nach der Fahrt unter 40 Kraft (erschöpft, nur noch 65–90 %% Leistung): %s." % ", ".join(PackedStringArray(names))),
		_l("Setze sie auf die Ladung (Ruheplatz) oder lass das Schiff beidrehen, damit sie sich erholen.", DIM),
	])


static func target(voy: Voyage, text: String) -> Dictionary:
	return _tip("Weg", [_l(text)])


# --- Kopfzeile ----------------------------------------------------------------

static func top_hull(voy: Voyage) -> Dictionary:
	return _tip("Rumpf", [
		_l("Zustand des Schiffes: %d von %d. Bei 0 sinkt es." % [maxi(roundi(voy.hull), 0), roundi(voy.hull_max())]),
		_l("Ab Raue See (3) und durch Gefahren nimmt der Rumpf Schaden; Zimmerleute flicken ihn, beim Beidrehen besser. Mehr Rumpf geben Gegenstände und Segen.", DIM),
		_l("Reparieren: Bucht, Dorf-Handwerker, Werft im Hafen, im Kampf „Flicken“.", DIM),
	])


static func top_food(voy: Voyage) -> Dictionary:
	return _tip("Proviant", [
		_l("Vorrat: %d (Lager bis %d). Jede Fahrt kostet 1, egal wie weit sie kommt: langsam fahren kostet pro Meile also mehr. Ab dem achten Mann an Bord (Reserve) kommt je Mann ein halber dazu: jetzt %d je Fahrt." % [voy.proviant, roundi(voy.stat("proviant_max")), 1 + voy.extra_food()]),
		_l("Ohne Proviant steigt die Verzweiflung, die Kraft sinkt und Erschöpfte verhungern. Nachschub gibt es in Hafen, Dorf, auf Inseln und nach Kämpfen.", DIM),
	])


static func top_loot(voy: Voyage) -> Dictionary:
	return _tip("Beute", [
		_l("Die Währung der Fahrt: %d." % roundi(voy.loot)),
		_l("Man bekommt sie durch Entern, Plündern, Funde und Seeschlachten (mit Zuschlag von %d %% je Etappe). Ausgegeben wird sie im Hafen: Met, Anheuern, Proviant, Werft. Riffe können Beute kosten." % roundi(12.0 * float(maxi(voy.stage - 1, 0))), DIM),
		_l("Jede Meldung dazu steht links oben in der Mitte: wo sie herkommt und was es war.", DIM),
	])


## Die Pfandflasche in der Schiffsansicht.
static func pfand(voy: Voyage) -> Dictionary:
	return _tip("Pfandflasche (legendär)", [
		_l("Du hast %d von höchstens %d." % [voy.pfand, Items.PFAND_MAX], Items.pfand_color()),
		_l(Items.PFAND_DESC, PAPER),
		_l("Gib sie bei Adlersson ab (seltene Begegnung auf See): ein sicheres Freispiel. Gefunden wird sie im Wrack, nach Kämpfen, nach dem Kraken oft, manchmal beim Met in der Taverne.", DIM),
	])


static func top_powder(voy: Voyage) -> Dictionary:
	return _tip("Pulver", [
		_l("Vorrat: %d von %d. Jeder Kanonenschuss in der Seeschlacht kostet 1 Pulver, danach lädt man eine Runde nach." % [voy.powder, roundi(voy.stat("powder_max"))]),
		_l("Pulver kauft man in der Werft (+4).", DIM),
	])


static func top_mile(voy: Voyage) -> Dictionary:
	return _tip("Meile", [
		_l("Fortschritt dieser Etappe: %s von %d Meilen. Am Ende liegt immer ein Hafen." % [Voyage.fmt(float(voy.mile) + voy.leg), Voyage.MILES]),
		_l("Das Schiff kann zwischen zwei Knoten liegen: der Kurs ist dann schon gesetzt.", DIM),
	])


static func top_sea(voy: Voyage) -> Dictionary:
	var sea := voy.location_sea()
	var lines: Array = []
	if sea <= 2:
		lines.append(_l("Bei ruhiger oder leichter See gibt es keinen Rumpfschaden.", GREEN))
	else:
		lines.append(_l("Auf dieser See nimmt der Rumpf je Meile etwa %d Schaden (mal Etappenhärte %s, mal Wirkung der Regler)." % [roundi(float(Sea.STRAIN[sea])), Voyage.fmt(voy.stage_mul())], GOLD if sea == 3 else RED))
	lines.append(_l("Dazu kommt das Risiko, dass ein Mann über Bord gespült wird: %s je Meile ohne Schutz." % _pct(Sea.wash_chance(sea)), DIM))
	lines.append(_l("Seegang 1 ruhig · 2 leicht · 3 rau · 4 schwer · 5 Sturm. Er steigt mit den Etappen.", DIM))
	return _tip("Seegang: %s" % Sea.SEA_NAMES[sea], lines)


static func stage(voy: Voyage) -> Dictionary:
	return _tip("Etappe %d" % voy.stage, [
		_l("Eine Etappe sind %d Meilen bis zum nächsten Hafen. Mit jeder Etappe wird die See härter: +%d %% Seegangs- und Gefahrenschaden je Etappe (jetzt ×%s) und die Gegner zäher." % [Voyage.MILES, roundi(Voyage.STAGE_HARDNESS * 100.0), Voyage.fmt(voy.stage_mul())]),
		_l("Dafür wächst die Beute um 12 %% je Etappe (jetzt +%d %%)." % roundi(12.0 * float(voy.stage - 1)), DIM),
	])


static func level(voy: Voyage) -> Dictionary:
	return _tip("Stufe %d" % voy.level, [
		_l("Erfahrung: %d von %d bis zur nächsten Stufe." % [voy.xp, voy.xp_needed()]),
		_l("Erfahrung gibt es für erreichte Knoten, gewonnene Begegnungen, Seeschlachten und Etappen. Bei jedem Stufenaufstieg wählst du einen von drei Segen für den Rest der Fahrt.", DIM),
	])


const THEME_TEXT := [
	"",
	"Viel Nebel: man kennt nur zwei Meilen voraus, im Nebel selbst nur den nächsten Knoten.",
	"Ein Grad mehr Seegang, mehr Böen und Brecher.",
	"Dreimal so viele Räuberschiffe.",
	"Dreimal so viele Draugr-Schiffe, oft Kraken.",
]


static func theme(voy: Voyage) -> Dictionary:
	return _tip(String(Voyage.THEMES[voy.theme]), [_l(String(THEME_TEXT[voy.theme])), _l("Jede Etappe ab der zweiten hat ein Thema, nie zweimal dasselbe.", DIM)])


# --- Seekarte -------------------------------------------------------------------

## Ein Knoten der Karte: Seegang, Gefahr, Begegnung und was man davon zu erwarten hat.
static func node(voy: Voyage, c: int, i: int) -> Dictionary:
	var nd := voy.node_at(c, i)
	var sea := int(nd["sea"])
	var lines: Array = []
	if sea <= 2:
		lines.append(_l("%s: kein Rumpfschaden." % Sea.SEA_NAMES[sea], GREEN))
	else:
		lines.append(_l("%s: Rumpf etwa −%d je Meile, mehr Männer über Bord (%s)." % [Sea.SEA_NAMES[sea], roundi(float(Sea.STRAIN[sea]) * voy.stage_mul()), _pct(Sea.wash_chance(sea))], GOLD if sea == 3 else RED))
	var hz := int(nd["hazard"])
	if hz != Sea.Hazard.NONE:
		lines.append(_l("%s: %s" % [Sea.HAZARD_NAMES[hz], String(HAZARD_TEXT[hz])], RED))
		lines.append(_l("Schutz: " + protection_text(hz), DIM))
	var enc := int(nd["enc"])
	if bool(nd.get("cove", false)):
		lines.append(_l("Ankerbucht: hier kann man sicher lagern (Taste L, einmal je Etappe).", GREEN))
	if enc >= 0 and not bool(nd.get("visited", false)):
		var def: Dictionary = Encounters.DATA[enc]
		lines.append(_l("%s: %s" % [def["name"], Encounters.hint(enc)], GOLD))
	elif hz == Sea.Hazard.NONE:
		lines.append(_l("Keine Gefahr, keine Begegnung: ein ruhiger Weg.", DIM))
	return _tip("Meile %d" % c, lines)


## Ein Ereignis auf der Strecke (Raute auf einem Weg der Seekarte).
static func route_event(voy: Voyage, id: int, known: bool) -> Dictionary:
	if not known:
		return _tip("Unterwegs: etwas", [
			_l("Auf diesem Weg liegt etwas. Was es ist, sieht man erst vom Knoten davor, wie einen Gang in Darkest Dungeon."),
			_l("Das Schiff hält dort an, mitten auf dem Weg; der Rest der Strecke verfällt.", DIM)])
	var def: Dictionary = Encounters.DATA[id]
	var col := RED if Encounters.route_tone(id) == "gefahr" else (VIOLET if Encounters.route_tone(id) == "spuk" else GOLD)
	return _tip("Unterwegs: %s" % def["name"], [
		_l(Encounters.hint(id), col),
		_l("Das Schiff hält dort an, mitten auf dem Weg; der Rest der Strecke verfällt. Danach geht es auf demselben Kurs weiter.", DIM)])


# --- Begegnungskarten -------------------------------------------------------------

## Was eine Option bringt und kostet, mit der echten Beute (Zuschläge) und der Art des Fundes.
static func option(voy: Voyage, enc: int, opt: Dictionary) -> Dictionary:
	if bool(opt.get("crew", false)):
		return _tip("Taverne", [_l("Hier warten drei Anwärter, jeden Hafen andere. Du siehst Kraft, Eigenschaften und Preis. Wer Platz hat (Reserve oder ein gefallener Mann), kann gleich anheuern."), _l("Die Mannschaftsansicht zeigt auch deine Reserve: Männer tauschen, Reservisten entlassen.", DIM)])
	if String(opt.get("slot", "")) == "harbor":
		var left := maxi(Voyage.SLOT_HARBOR_SPINS - voy._harbor_spins, 0)
		var lv := Slots.bet_levels(voy.stage)
		return _tip("Spelunke", [
			_l("Die Nornenwalzen: ein Spielautomat mit fünf Walzen und zehn Gewinnlinien. Du setzt Beute (%d, %d oder %d) und drehst." % [lv[0], lv[1], lv[2]], PAPER),
			_l("Drei Blitzrunen wecken den Draugr: Freispiele mit Joker, Stapeln und Power-Ups, die richtig dick zahlen. Große Gewinne bringen auch einen Segen oder einen Fund.", GREEN),
			_l("Höchstens %d bezahlte Drehs je Hafenbesuch (noch %d). Auf Dauer zahlt der Automat etwas mehr zurück, als man setzt, aber es schwankt stark." % [Voyage.SLOT_HARBOR_SPINS, left], DIM),
			_l("Nach gewonnenen Deckkämpfen gibt es manchmal einen Freidreh umsonst, nach dem Kraken sind die Freispiele sicher.", DIM),
		])
	if bool(opt.get("bottle", false)):
		return _tip("Pfandflasche (legendär)", [
			_l("Du hast %d Pfandflasche(n). Gibst du eine ab, bekommst du bei Adlersson ein sicheres Freispiel: Seine Walzen drehen, bis es einen Gewinn gibt, und Adlerssons Streich zählt nicht." % voy.pfand if voy.pfand > 0 else "Du hast keine Pfandflasche. Man findet sie selten: im Wrack, nach Kämpfen (nach dem Kraken oft), manchmal beim Met in der Taverne.", GREEN if voy.pfand > 0 else DIM),
			_l("Der Gewinn wird wie sonst kassiert oder auf die Risikoleiter gesetzt. Die Flasche zählt nicht als Runde.", PAPER),
		])
	if String(opt.get("slot", "")) == "loki":
		return _tip("Adlerssons Walzen", [
			_l("Ein Automat mit hohem Einsatz: du setzt Beute, ein Viertel des Rumpfes oder einen Mann. Gewinne sind Vielfache des Einsatzwertes, bis zum Hundertfachen.", PAPER),
			_l("Nach einem Gewinn: kassieren oder die Risikoleiter (Münzwurf, verdoppeln oder alles verlieren).", GOLD),
			_l("Drei Masken auf einer Linie sind Adlerssons Streich: der Einsatz ist weg und eine Strafe kommt dazu (ein Mann, Rumpf, Proviant oder Mut).", RED),
			_l("Bis zu %d Runden. Wer nicht spielt, verliert nichts." % Voyage.LOKI_ROUNDS, DIM),
		])
	var lines: Array = []
	var cost: Dictionary = opt.get("cost", {})
	if not cost.is_empty():
		var cs: Array[String] = []
		if cost.has("loot"):
			cs.append("Beute −%d" % roundi(float(cost["loot"])))
		if cost.has("proviant"):
			cs.append("Proviant −%d" % int(cost["proviant"]))
		lines.append(_l("Kosten: " + ", ".join(PackedStringArray(cs)), GOLD))
	if opt.has("fight"):
		lines.append(_l("Aussicht %s aus der Kampfstärke deiner Besatzung (Männer mit Kraft, Waffen und Eigenschaften)." % _pct(Encounters.chance(voy, opt)), GOLD))
	var outs: Array = opt.get("outcomes", [])
	var seen := {}
	for k in outs.size():
		var o: Dictionary = outs[k]
		var fx: Dictionary = o.get("fx", {})
		if fx.is_empty():
			continue
		var label := ""
		if opt.has("fight"):
			label = "Sieg: " if k == 0 else "Niederlage: "
		elif outs.size() > 1:
			label = "Möglich: "
		var text := label + Encounters.fx_summary(Encounters.scaled_fx(voy, fx))
		var bt := Encounters.booty_for(String(o.get("lore", "")))
		if bt != "" and float(fx.get("loot", 0)) > 0.0:
			text += " (%s)" % bt
		if not seen.has(text):
			seen[text] = true
			var bad := fx.has("kill") or int(fx.get("hull", 0)) < 0
			lines.append(_l(text, RED if bad else (GREEN if (fx.has("loot") or fx.has("proviant")) else PAPER)))
	if outs.size() > 1 and not opt.has("fight"):
		lines.append(_l("Der Ausgang ist ungewiss; welche Chancen es gibt, erfährt man erst vor Ort.", DIM))
	if lines.is_empty():
		lines.append(_l("Nichts geschieht.", DIM))
	return _tip(String(opt.get("label", "")), lines)


## Der Lagerplatz: warum sicher oder unsicher.
static func camp_site(voy: Voyage) -> Dictionary:
	if bool(voy.here().get("cove", false)):
		return _tip("Ankerbucht", [
			_l("Eine geschützte Bucht mit Strand. Ein Lager hier ist sicher: die Chance auf ein Nachtereignis liegt bei nur %d %%." % roundi(voy.camp_night_chance() * 100.0), GREEN),
			_l("Auf offener Küste ist die Nacht deutlich unsicherer.", DIM),
		])
	return _tip("Offene Küste", [
		_l("Ein Lager auf ruhiger See ohne Gefahr, aber ohne Schutz der Bucht. Nachts kann etwas passieren: Überfall, Sturm, ein Fremder, ein Fund.", GOLD),
		_l("Schlafen ohne Wache ist am riskantesten; eine Wache senkt die Gefahr auf ein Viertel.", DIM),
	])


static func camp_points(voy: Voyage) -> Dictionary:
	return _tip("Lagerpunkte", [
		_l("Jedes Lager hat %d Punkte (noch %d). Jede Aktion kostet Punkte, jede nur einmal (Flicken so oft, wie Zimmerleute bereitstehen)." % [Camp.POINTS, voy.camp_points]),
		_l("Das Lager selbst kostet %d Proviant und die Fahrt: auf der Karte vergeht keine Meile. Pro Etappe gibt es ein Lager." % Camp.PROVIANT_COST, DIM),
	])


static func camp_action(voy: Voyage, id: String) -> Dictionary:
	var d: Dictionary = Camp.DATA[id]
	var lines: Array = [_l(String(d["desc"]))]
	lines.append(_l("Kosten: %d Lagerpunkt%s" % [int(d["cost"]), "" if int(d["cost"]) == 1 else "e"], GOLD))
	var why := Camp.why_not(voy, id)
	if why != "":
		lines.append(_l("Jetzt nicht möglich: " + why + ".", RED))
	return _tip(String(d["name"]), lines)


static func camp_crew(voy: Voyage) -> Dictionary:
	return _tip("Mannschaft ändern", [
		_l("Im Lager darfst du die Reserve an Deck holen und Männer tauschen. Das kostet keinen Lagerpunkt."),
		_l("Erholte Reservisten können müde Männer ersetzen. Kehrt man zurück, zählt die neue Aufstellung.", DIM),
	])


static func camp_night(voy: Voyage) -> Dictionary:
	return _tip("Die Nacht", [
		_l("Beim Aufbruch wird die Nacht abgewickelt. Die Chance auf ein Ereignis ist jetzt %d %%." % roundi(voy.camp_night_chance() * 100.0)),
		_l("Ankerbucht: klein. Offene Küste: größer, und größer, wenn man schläft, ohne Wache zu stellen. Später und in Piratengewässern und der Totensee wird es gefährlicher.", DIM),
		_l("Ereignisse: Überfall (Abwehr nach Kampfstärke und Wache), Sturm (Rumpf −6), ein Fremder (Proviant +3), ein Fund (Beute).", DIM),
	])


## Die Schaltfläche "Lager" in der Planung.
static func camp_button(voy: Voyage) -> Dictionary:
	var why := voy.camp_reason()
	if why == "":
		return _tip("Lager aufschlagen", [
			_l("Rast an Land: sechs Lagerpunkte für Essen, Schlafen, Wache, Lied, Flicken und mehr. Kostet %d Proviant, eine Meile geht dabei nicht voran." % Camp.PROVIANT_COST),
			_l("Taste L. Einmal je Etappe.", DIM),
		])
	return _tip("Lager", [_l(why, RED), _l("Ein Lager ist möglich an Ankerbuchten (A auf der Karte) oder auf ruhiger See ohne Gefahr, einmal je Etappe.", DIM)])


# --- Deckkampf ---------------------------------------------------------------------

static func _ranks(a: Array) -> String:
	var parts: Array[String] = []
	for r in a:
		parts.append(str(int(r) + 1))
	return ", ".join(PackedStringArray(parts))


## Zwei Zeilen für die Fertigkeitskarte im Kampf.
static func skill_short(c: Combat, f: Combat.Fighter, sid: String) -> Array:
	var sk: Dictionary = c.eff_skill(f, sid)
	var fx: Dictionary = sk["fx"]
	if not (sk["from"] as Array).has(f.rank):
		return ["nur aus Reihe", _ranks(sk["from"])]
	if c.uses_left(f, sid) <= 0:
		return ["keine Einsätze", "mehr"]
	if fx.has("fire") and not f.loaded:
		return ["Muskete leer:", "erst nachladen"]
	if fx.has("reload") and f.loaded:
		return ["Muskete ist", "schon geladen"]
	var tgt := String(sk["tgt"])
	if tgt == "foe":
		var tl := c.targets(f, sid)
		if tl.is_empty():
			return ["kein Ziel in", "Reichweite"]
		var rng := c.damage_range(f, tl[0], sk)
		return ["Treffer %d %%" % roundi(c.hit_chance(f, tl[0], sk)), "Schaden %d–%d" % [roundi(rng[0]), roundi(rng[1])]]
	if tgt == "foes":
		var tl2 := c.targets(f, sid)
		if float(sk["dmg"]) <= 0.0:
			return ["alle Gegner", "markiert"]
		var rng2 := c.damage_range(f, tl2[0], sk) if not tl2.is_empty() else [0.0, 0.0]
		return ["%d Ziele" % tl2.size(), "je %d–%d" % [roundi(rng2[0]), roundi(rng2[1])]]
	var left := ""
	if sk.has("uses"):
		left = "noch %d" % c.uses_left(f, sid)
	if fx.has("taunt"):
		return ["Gegner zielen", "nur auf ihn"]
	if fx.has("guard"):
		return ["Schutz +40 %", "zieht Gegner an" if tgt == "self" else "für einen Mann"]
	if fx.has("cleanse"):
		return ["löst Betäubung,", "Blutung, Tinte"]
	if fx.has("buff"):
		var rounds := "%d Runden" % int(fx["buff"])
		return ["Schaden +25 %", ("alle, " + rounds) if tgt == "allies" else rounds]
	if fx.has("heal"):
		return ["Kraft +%d" % int(fx["heal"]), left if left != "" else "für einen Mann"]
	if fx.has("stress_heal"):
		return ["Mut +%d" % int(fx["stress_heal"]), left if left != "" else "für einen Mann"]
	if fx.has("reload"):
		return ["lädt die", "Muskete"]
	return _two_lines(String(sk["desc"]), 18)


## Teilt einen Text an Wortgrenzen auf zwei Zeilen zu höchstens n Zeichen (die zweite endet bei Bedarf mit …),
## damit Kartentexte nie mitten im Wort abbrechen.
static func _two_lines(text: String, n: int) -> Array:
	var first := ""
	var rest := ""
	for word in text.split(" "):
		if rest == "" and (first == "" or first.length() + 1 + word.length() <= n):
			first = word if first == "" else first + " " + word
		else:
			rest = word if rest == "" else rest + " " + word
	if rest.length() > n:
		rest = rest.substr(0, n - 1).rstrip(" ,.") + "…"
	return [first, rest]


static func skill(c: Combat, f: Combat.Fighter, sid: String) -> Dictionary:
	var sk: Dictionary = c.eff_skill(f, sid)
	var lines: Array = [_l(String(sk["desc"]))]
	var lvl := int(f.skill_lvl.get(sid, 0))
	if lvl > 0:
		lines.append(_l("Stufe %d aus der Kampfschule: %s." % [lvl, Roles.upgrade_text(sid)], GOLD))
	lines.append(_l("Einsetzbar aus Reihe %s (jetzt Reihe %d)." % [_ranks(sk["from"]), f.rank + 1], GREEN if (sk["from"] as Array).has(f.rank) else RED))
	if String(sk["tgt"]) in ["foe", "hero", "foes"] and not (sk["to"] as Array).is_empty():
		lines.append(_l("Trifft Reihe %s des Ziels." % _ranks(sk["to"]), DIM))
	if (sk["fx"] as Dictionary).has("fire") or (sk["fx"] as Dictionary).has("reload"):
		lines.append(_l("Die Muskete ist %s." % ("geladen" if f.loaded else "leer"), GREEN if f.loaded else RED))
	if sk.has("uses"):
		lines.append(_l("Noch %d von %d Einsätzen in diesem Kampf." % [c.uses_left(f, sid), int(sk["uses"])], DIM))
	if String(sk["tgt"]) in ["foe", "foes"] and float(sk["dmg"]) > 0.0:
		for t in c.targets(f, sid):
			var rng := c.damage_range(f, t, sk)
			lines.append(_l("%s: Treffer %d %%, Schaden %d–%d" % [t.name, roundi(c.hit_chance(f, t, sk)), roundi(rng[0]), roundi(rng[1])], PAPER))
	return _tip(String(sk["name"]), lines)

static func fighter(c: Combat, f: Combat.Fighter, armed_skill: String) -> Dictionary:
	var lines: Array = []
	lines.append(_l("Kraft %d von %d%s" % [maxi(roundi(f.hp), 0), roundi(f.hp_max), "  ·  an der Schwelle" if (f.door and f.side == 0) else ""], PAPER))
	lines.append(_l("Ausweichen %d %%, Schutz %d %%, Tempo %d" % [roundi(f.dodge), roundi(f.prot * 100.0), f.speed], DIM))
	if f.side == 0 and f.man != null:
		lines.append(_l("Verzweiflung %d. %s" % [roundi(f.man.stress), "Müdigkeit: " + f.man.fatigue_name()], DIM))
		if f.snapped:
			lines.append(_l("In diesem Kampf schon gekippt.", DIM))
		elif f.man.stress >= 50.0:
			lines.append(_l("Bei 100 Verzweiflung kippt er: mit etwa 3 Chancen in 10 wächst er über sich hinaus (Heldenmut, ein Skalde hilft), sonst bricht er zusammen (verzagt oder Berserker).", GOLD))
	var st: Array[String] = []
	if f.stun > 0:
		st.append("betäubt")
	if f.bleed_turns > 0:
		st.append("blutet (%d × %d)" % [f.bleed_turns, roundi(f.bleed_dmg)])
	if f.mark > 0:
		st.append("markiert")
	if f.guard > 0:
		st.append("Schildwall")
	if f.buff > 0:
		st.append("Kriegslied")
	if f.held_by != null and not f.held_by.gone:
		st.append("im Griff (G)")
	if f.blind > 0:
		st.append("geblendet (T): Treffer −20 %% für %d Runden" % f.blind)
	if f.charge:
		st.append("spannt sich (Z)")
	if not st.is_empty():
		lines.append(_l("Zustand: " + ", ".join(PackedStringArray(st)), GOLD))
	if f.held_by != null and not f.held_by.gone:
		lines.append(_l("%s hält ihn: fällt oder betäubt der Fangarm nicht, geht er über Bord. Er selbst kann nichts tun." % f.held_by.name, RED))
	if f.holding != null and not f.holding.gone:
		lines.append(_l("Hält %s und zieht ihn in %d Zügen über Bord. Fällt er, ist der Mann frei; betäubt, verliert er Zeit." % [f.holding.name, f.hold_left], RED))
	if f.charge:
		lines.append(_l("Zerquetscht im nächsten Zug alle Männer auf Deck. Betäubt, verpufft es.", RED))
	if f.side == 1 and f.guarded:
		if c._tentacles() > 0:
			lines.append(_l("Unerreichbar, solange noch ein Fangarm steht. Alle Fangarme fällen (sie wachsen nach %d Runden mit 60 %% Kraft nach), dann ist er dran." % Combat.REGROW, GOLD))
		else:
			lines.append(_l("Jetzt offen: Fangarme sind alle gefällt. Schnell zuschlagen, bevor einer nachwächst.", GREEN))
	if f.side == 1:
		var names: Array[String] = []
		for pair in f.skills:
			names.append(String(Roles.skill(String(pair[0]))["name"]))
		lines.append(_l("Kann: " + ", ".join(PackedStringArray(names)), DIM))
		if f.kind == "kraken":
			lines.append(_l("Und alle paar Runden Zerquetschen: erst angekündigt, im nächsten Zug ausgeführt.", DIM))
		if not f.immune.is_empty():
			lines.append(_l("Immun gegen: " + ", ".join(PackedStringArray(f.immune)), DIM))
		if f.coward:
			lines.append(_l("Feige: flieht, wenn er allein ist.", DIM))
	if armed_skill != "" and c.actor != null and String(Roles.skill(armed_skill)["tgt"]) == "foe":
		var sk: Dictionary = c.eff_skill(c.actor, armed_skill)
		var rng := c.damage_range(c.actor, f, sk)
		lines.append(_l("Mit %s: Treffer %d %%, Schaden %d–%d" % [sk["name"], roundi(c.hit_chance(c.actor, f, sk)), roundi(rng[0]), roundi(rng[1])], GREEN))
	var title := f.name
	if f.side == 0:
		title += "  (%s)" % Roles.role_name(f.role)
	return _tip(title, lines)


## Ein Mann in der Aufstellung: Rolle, Fertigkeiten, Zustand.
static func fight_man(voy: Voyage, m: CrewMember) -> Dictionary:
	var r: Dictionary = Roles.role(m.role)
	var names: Array[String] = []
	for sid in m.skills():
		var lv := int(m.skill_lvl.get(String(sid), 0))
		names.append(String(Roles.skill(String(sid))["name"]) + (" %d" % lv if lv > 0 else ""))
	var lines: Array = [
		_l("%s: %s" % [r["name"], r["desc"]]),
		_l("Fertigkeiten: " + ", ".join(PackedStringArray(names)), DIM),
		_l("Kraft %d (%s), Verzweiflung %d." % [roundi(m.kraft), m.fatigue_name(), roundi(m.stress)], PAPER),
	]
	for gs in [Gear.Slot.WAFFE, Gear.Slot.RUESTUNG, Gear.Slot.AMULETT]:
		if m.gear.has(gs):
			lines.append(_l("%s: %s" % [Gear.SLOT_NAMES[gs], Gear.name_of(String(m.gear[gs]))], Gear.rarity_color(String(m.gear[gs]))))
	if m.weapon_lvl > 0 or m.armor_lvl > 0:
		lines.append(_l("Schmiede: Waffe Stufe %d (+%d %% Schaden), Rüstung Stufe %d (+%d %% Schutz)." % [m.weapon_lvl, roundi(Voyage.WEAPON_DMG * 100.0 * float(m.weapon_lvl)), m.armor_lvl, roundi(Voyage.ARMOR_PROT * 100.0 * float(m.armor_lvl))], GOLD))
	if m.kraft < CrewMember.TIRED_AT:
		lines.append(_l("Müde Männer treffen schlechter und schaden weniger. Wer bei 0 Kraft getroffen wird, kann sterben.", RED))
	if m.state == CrewMember.State.RESERVE:
		lines.append(_l("Aus der Reserve: kein Platz an Deck bleibt unbesetzt.", GREEN))
	elif m.slot >= 0:
		lines.append(_l("Er verlässt für den Kampf seinen Platz (%s)." % Stations.NAMES[Stations.slot_station(m.slot)], DIM))
	return _tip(m.display_name, lines)


## Ein Gegenstand mit seiner Seltenheit: Werte, Zusatzwert, im Angebot der Preis.
static func item(key: String, stage: int, offer: bool) -> Dictionary:
	var lines: Array = [
		_l("%s · %s" % [Items.rarity_name(key), Items.KIND_NAMES[Items.kind_of(key)]], Items.rarity_color(key)),
		_l(Items.desc_of(key), DIM),
	]
	for ml in Items.lines_of(key):
		lines.append(_l(String(ml[0]), GREEN if bool(ml[1]) else RED))
	if Items.rarity_of(key) >= Items.Rarity.EPISCH:
		lines.append(_l("Episch und Legendär bringen einen Zusatzwert mit.", DIM))
	if Items.rarity_of(key) > 0:
		lines.append(_l("Seltene Gegenstände sind stärker, aber teurer. Funde im Wrack und besiegte Gegner liefern sie auch.", DIM))
	if offer:
		lines.append(_l("Preis %d Beute." % Items.price_at(key, stage), GOLD))
	return _tip(Items.name_of(key), lines)


## Ein Stück Ausrüstung mit Seltenheit, Werten und im Angebot dem Preis.
static func gear(key: String, stage: int, offer: bool) -> Dictionary:
	var lines: Array = [
		_l("%s · %s" % [Gear.rarity_name(key), Gear.SLOT_NAMES[Gear.slot_of(key)]], Gear.rarity_color(key)),
		_l(Gear.desc_of(key), DIM),
	]
	for ml in Gear.lines_of(key):
		lines.append(_l(String(ml[0]), GREEN if bool(ml[1]) else RED))
	if Items.rarity_of(key) >= Items.Rarity.EPISCH:
		lines.append(_l("Episch und Legendär bringen einen Zusatzwert mit.", DIM))
	if offer:
		lines.append(_l("Preis %d Beute. Es kommt in den Vorrat, angelegt wird in der Ausrüstung." % Gear.price_at(key, stage), GOLD))
	else:
		lines.append(_l("Verkaufswert %d Beute." % roundi(float(Gear.price_at(key, stage)) * 0.5), DIM))
	return _tip(Gear.name_of(key), lines)


## Waffe oder Rüstung in der Schmiede.
static func forge_gear(kind: String, m: CrewMember) -> Dictionary:
	if kind == "weapon":
		return _tip("Waffe", [
			_l("Jede Stufe: +%d %% Schaden aller Angriffe von %s, bis Stufe %d." % [roundi(Voyage.WEAPON_DMG * 100.0), m.display_name, Voyage.WEAPON_MAX]),
			_l("Gilt für alle künftigen Kämpfe. Fällt der Mann, ist es verloren.", DIM),
		])
	return _tip("Rüstung", [
		_l("Jede Stufe: +%d %% Schutz gegen alle Treffer, bis Stufe %d." % [roundi(Voyage.ARMOR_PROT * 100.0), Voyage.ARMOR_MAX]),
		_l("Gilt für alle künftigen Kämpfe. Fällt der Mann, ist es verloren.", DIM),
	])


## Eine Fertigkeit in der Kampfschule.
static func forge_skill(m: CrewMember, sid: String) -> Dictionary:
	var sk: Dictionary = Roles.skill(sid)
	var lvl := int(m.skill_lvl.get(sid, 0))
	var lines: Array = [_l(String(sk["desc"]))]
	if Roles.upgradable(sid):
		lines.append(_l("Stufe %d von %d. Nächste Stufe: %s." % [lvl, Roles.max_level(sid), Roles.upgrade_text(sid)], GOLD))
		if not m.skills().has(sid):
			lines.append(_l("Sie gehört nicht zu seinen vier gewählten Fertigkeiten (Aufstellung).", DIM))
	else:
		lines.append(_l("Hier gibt es nichts zu verbessern.", DIM))
	return _tip(String(sk["name"]), lines)


## Die Fertigkeiten eines Mannes in der Aufstellung.
static func loadout(m: CrewMember) -> Dictionary:
	var lines: Array = []
	for sid in m.skills():
		var sk: Dictionary = Roles.skill(String(sid))
		lines.append(_l("%s: %s" % [sk["name"], sk["desc"]], PAPER))
	lines.append(_l("Klicken wählt aus den sechs Fertigkeiten der Rolle vier aus.", GOLD))
	return _tip("Fertigkeiten von %s" % m.display_name, lines)


static func fight_auto() -> Dictionary:
	return _tip("Beste vier", [_l("Wählt aus allen Männern bis zu vier: von jeder Rolle den Kräftigsten, Schildträger vorn, dahinter Axt und Bogen, der Skalde hinten. Müde Männer (unter 25 Kraft) bleiben möglichst zurück.")])


## Reserve unter Deck: Regeln auf einen Blick.
static func reserve(voy: Voyage) -> Dictionary:
	return _tip("Reserve", [
		_l("Männer unter Deck: %d von %d Plätzen belegt. Sie arbeiten nicht, sind vor dem Meer sicher und erholen sich bei jeder Fahrt (Kraft +15, Verzweiflung −3)." % [voy.reserve.size(), voy.reserve_cap()]),
		_l("Sie essen mit: ab dem achten Mann an Bord kostet jeder Mann einen halben Proviant je Fahrt (jetzt +%d)." % voy.extra_food(), GOLD),
		_l("Sie kommen nur im Hafen, im Lager und am Anfang einer Etappe an Deck. Frische Reservisten lösen müde Männer dann automatisch ab (Taste A). Sie kämpfen bei Entern und Überfall mit, ohne dass eine Station fehlt.", DIM),
		_l("Mehr Plätze: Hängematten in der Werft (+2, höchstens 5).", DIM),
	])


## Ein Anwärter in der Taverne.
static func recruit(voy: Voyage, c: Dictionary, afford: bool) -> Dictionary:
	var lines: Array = [_l("%s. Kraft %d, Verzweiflung %d. Preis: Beute %d." % [Roles.role_name(int(c.get("role", 0))), int(c["kraft"]), int(c["stress"]), int(c["price"])])]
	for t in c["traits"]:
		var d: Dictionary = Traits.DATA[int(t)]
		lines.append(_l("%s: %s" % [d["name"], d["desc"]], DIM))
	if not afford:
		lines.append(_l("Zu teuer oder kein Platz (Reserve voll, kein Gefallener zu ersetzen).", RED))
	elif voy.reserve_free() > 0 or voy._dead_entry() < 0:
		lines.append(_l("Er kommt in die Reserve. Dort ist er sicher, isst aber mit (ab dem achten Mann).", GREEN))
	else:
		lines.append(_l("Er nimmt gleich den Platz des Gefallenen an Deck ein.", GREEN))
	return _tip(String(c["name"]), lines)


static func battle_enemy(voy: Voyage) -> Dictionary:
	var def := Battle.enemy_def(voy)
	var loot := roundi(float(def["loot"]) * voy.stat("loot") * (1.0 + 0.12 * float(voy.stage - 1)))
	var key := String(voy.battle["enemy"])
	return _tip(String(def["name"]), [
		_l("Beute bei Sieg: %d (%s), dazu Proviant +4, Verzweiflung −10 und Erfahrung." % [loot, Encounters.booty_for("battle_" + key)], GOLD),
		_l("Besiegt ist der Gegner, wenn sein Rumpf oder seine Besatzung auf 0 sinkt. Nach 6 Runden zieht er ab: ohne Beute. Fliehen kostet Rumpf und bringt keine Beute.", DIM),
		_l("Der Gegner kündigt seinen nächsten Zug an; Schildwall, Pfeilhagel oder Flicken können ihn abschwächen.", DIM),
	])


# --- Mannschaft -------------------------------------------------------------------

static func station(id: int) -> String:
	return String(Stations.DESC[id])
