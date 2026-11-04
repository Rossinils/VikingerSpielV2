class_name Camp
extends RefCounted

## Das Lager: eine Rast an Land, wie das Zeltlager in Darkest Dungeon. Man hat sechs Lagerpunkte und verteilt sie auf
## Aktionen. Jede Aktion nennt vorher, was sie bringt und kostet. Die Zahlen stehen alle hier.

const POINTS := 6
const PROVIANT_COST := 2  # Nacht und Aufbau
const MEAD_COST := 10  # Beute

const ORDER := ["eat", "sleep", "watch", "song", "repair", "fish", "map", "stories", "mead"]
const DATA := {
	"eat": {"name": "Essen", "cost": 1, "short": "Kraft +20, Mut +5", "desc": "Ein warmes Mahl für alle. Kostet Proviant (ein halber je Mann). Kraft +20 und Verzweiflung −5 für alle, auch unter Deck."},
	"sleep": {"name": "Schlafen", "cost": 2, "short": "Kraft +40, Mut +10", "desc": "Eine echte Nacht. Kraft +40 und Verzweiflung −10 für alle. Ohne Wache ist die Nacht unsicher."},
	"watch": {"name": "Wache stellen", "cost": 1, "short": "Nacht sicherer", "desc": "Der frischeste Mann hält Wache (Kraft −10). Die Gefahr eines nächtlichen Überfalls sinkt auf ein Viertel und die Abwehr wird besser."},
	"song": {"name": "Lied am Feuer", "cost": 1, "short": "Mut +12 für alle", "desc": "Ein Lied, ein Fass Geschichten, ein bisschen Zusammenhalt. Verzweiflung −12 für alle."},
	"repair": {"name": "Flicken", "cost": 1, "short": "Rumpf +12", "desc": "Die Zimmerleute flicken am Strand. Rumpf +12 je Zimmermann an Deck, der noch etwas Kraft hat (bis zu zweimal)."},
	"fish": {"name": "Fischen", "cost": 1, "short": "Proviant +3", "desc": "Ein Schwimmer oder Seebär geht angeln. Proviant +3, mit zweien +4. Manchmal beißt auch das Meer (ein Mann verliert 20 Kraft)."},
	"map": {"name": "Karten lesen", "cost": 1, "short": "Sicht +1 Meile", "desc": "Ein Sterngucker liest Sterne und Küste. Du siehst auf dieser Etappe eine Meile weiter."},
	"stories": {"name": "Geschichten teilen", "cost": 1, "short": "Bindung stärken", "desc": "Zwei Männer mit Bindung (Brüder, Gefährten) sitzen am Feuer. Beiden Verzweiflung −12."},
	"mead": {"name": "Met trinken", "cost": 1, "short": "Mut +20, Kater", "desc": "Beute −10. Verzweiflung −20 für alle, am Morgen Kraft −5 für alle."},
}


## Alle Männer an Bord: an Deck und unter Deck.
static func everyone(voy: Voyage) -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	for m in voy.crew:
		if m.state == CrewMember.State.ABOARD:
			out.append(m)
	for m in voy.reserve:
		out.append(m)
	return out


static func food_needed(voy: Voyage) -> int:
	return ceili(float(everyone(voy).size()) / 2.0)


static func with_trait(voy: Voyage, ids: Array) -> Array[CrewMember]:
	var out: Array[CrewMember] = []
	for m in everyone(voy):
		for t in ids:
			if m.traits.has(int(t)):
				out.append(m)
				break
	return out


## Der Wachmann: der frischeste, der noch bei Kräften ist.
static func watcher(voy: Voyage) -> CrewMember:
	var best: CrewMember = null
	for m in everyone(voy):
		if m.kraft >= 35.0 and not m.afflicted and (best == null or m.kraft > best.kraft):
			best = m
	return best


## Zimmerleute an Deck mit Kraft: so viele Flickaktionen sind möglich.
static func carpenters(voy: Voyage) -> int:
	var n := 0
	for i in voy.slot_owner.size():
		var m: CrewMember = voy.slot_owner[i]
		if m != null and m.state == CrewMember.State.ABOARD and Stations.slot_station(i) == Stations.Id.ZIMMERMANN and m.kraft >= 10.0:
			n += 1
	return n


## Ein Paar mit Bindung (Bruder oder Gefährte), beide an Bord.
static func bond_pair(voy: Voyage) -> Array:
	for bd in voy.bonds:
		if int(bd["type"]) == Voyage.Bond.RIVAL:
			continue
		var a := voy.member_by_id(int(bd["a"]))
		var b := voy.member_by_id(int(bd["b"]))
		if a != null and b != null and (a.state == CrewMember.State.ABOARD or a.state == CrewMember.State.RESERVE) and (b.state == CrewMember.State.ABOARD or b.state == CrewMember.State.RESERVE):
			return [a, b]
	return []


## Leer, wenn die Aktion jetzt möglich ist; sonst der Grund.
static func why_not(voy: Voyage, id: String) -> String:
	var cost := int(DATA[id]["cost"])
	var used := int(voy.camp_done.get(id, 0))
	if voy.camp_points < cost:
		return "keine Lagerpunkte mehr"
	match id:
		"eat":
			if voy.proviant < food_needed(voy):
				return "zu wenig Proviant (%d nötig)" % food_needed(voy)
		"sleep":
			if used > 0:
				return "schon geschlafen"
		"watch":
			if used > 0:
				return "die Wache steht schon"
			if watcher(voy) == null:
				return "niemand ist kräftig genug"
		"song":
			if used > 0:
				return "schon gesungen"
		"repair":
			if voy.hull >= voy.hull_max() - 0.5:
				return "der Rumpf ist heil"
			if used >= mini(carpenters(voy), 2):
				return "keine Zimmerleute übrig" if used > 0 else "kein Zimmermann bei Kräften"
		"fish":
			if used > 0:
				return "schon gefischt"
			if with_trait(voy, [Traits.Id.SCHWIMMER, Traits.Id.SEEBAER]).is_empty():
				return "niemand versteht sich auf Fischfang (Schwimmer, Seebär)"
		"map":
			if used > 0:
				return "schon gelesen"
			if with_trait(voy, [Traits.Id.STERNGUCKER]).is_empty():
				return "kein Sterngucker an Bord"
		"stories":
			if used > 0:
				return "schon erzählt"
			if bond_pair(voy).is_empty():
				return "kein Paar mit Bindung an Bord"
		"mead":
			if used > 0:
				return "schon getrunken"
			if voy.loot < float(MEAD_COST):
				return "zu wenig Beute"
	return ""


static func apply(voy: Voyage, id: String) -> void:
	var men := everyone(voy)
	match id:
		"eat":
			var need := food_needed(voy)
			voy.proviant = maxi(voy.proviant - need, 0)
			for m in men:
				m.kraft = minf(m.kraft + 20.0, 100.0)
				voy._add_stress(m, -5.0)
			voy._fact("Das Lager isst: Proviant −%d (noch %d), Kraft +20, Verzweiflung −5 für alle." % [need, voy.proviant], Voyage.Kind.GOOD)
		"sleep":
			for m in men:
				m.kraft = minf(m.kraft + 40.0, 100.0)
				voy._add_stress(m, -10.0)
			voy.camp_slept = true
			voy._fact("Die Männer schlafen: Kraft +40, Verzweiflung −10 für alle.", Voyage.Kind.GOOD)
		"watch":
			var w := watcher(voy)
			if w != null:
				w.kraft = maxf(w.kraft - 10.0, 0.0)
				voy.camp_watch = w
				voy._fact("%s hält Wache (Kraft −10)." % w.display_name, Voyage.Kind.FACT)
		"song":
			for m in men:
				voy._add_stress(m, -12.0)
			voy._fact("Ein Lied am Feuer: Verzweiflung −12 für alle.", Voyage.Kind.GOOD)
		"repair":
			var heal := roundi(12.0 * voy.stat("repair"))
			voy.hull = minf(voy.hull + float(heal), voy.hull_max())
			Sfx.play("hammer")
			voy._fact("Die Zimmerleute flicken am Strand: Rumpf +%d." % heal, Voyage.Kind.GOOD)
		"fish":
			var anglers := with_trait(voy, [Traits.Id.SCHWIMMER, Traits.Id.SEEBAER])
			var gain := 3 + (1 if anglers.size() >= 2 else 0)
			voy.proviant = mini(voy.proviant + gain, maxi(voy.proviant, roundi(voy.stat("proviant_max"))))
			var bitten := ""
			if randf() < 0.2:
				var victim := men[randi() % men.size()]
				victim.kraft = maxf(victim.kraft - 20.0, 0.0)
				bitten = " %s hat sich dabei etwas geholt (Kraft −20)." % victim.display_name
			voy._fact("%s fängt Fisch: Proviant +%d.%s" % [anglers[0].display_name, gain, bitten], Voyage.Kind.GOOD)
		"map":
			voy.camp_sight = 1
			voy._fact("%s liest die Sterne: auf dieser Etappe siehst du eine Meile weiter." % with_trait(voy, [Traits.Id.STERNGUCKER])[0].display_name, Voyage.Kind.GOOD)
		"stories":
			var pair := bond_pair(voy)
			for m in pair:
				voy._add_stress(m, -12.0)
			voy._fact("%s und %s erzählen sich am Feuer, was sie sonst nie erzählen (Verzweiflung −12)." % [pair[0].display_name, pair[1].display_name], Voyage.Kind.GOOD)
		"mead":
			voy.loot = maxf(voy.loot - float(MEAD_COST), 0.0)
			for m in men:
				voy._add_stress(m, -20.0)
				m.kraft = maxf(m.kraft - 5.0, 0.0)
			Sfx.play("mug")
			voy._fact("Das Fass wird geleert: Beute −%d, Verzweiflung −20, Kater (Kraft −5)." % MEAD_COST, Voyage.Kind.GOOD)
