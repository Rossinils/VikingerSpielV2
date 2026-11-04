extends SceneTree

## Logiktest ohne Grafik:  godot --headless --path . --script tools/selftest.gd

var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("ok   ", what)
	else:
		fails += 1
		print("FAIL ", what)


func new_voyage(seed_value: int) -> Voyage:
	seed(seed_value)
	var v := Voyage.new()
	v.auto_combat = true  # Überfälle und Entern werden ohne Ansicht ausgespielt
	root.add_child(v)
	v.begin()
	return v


## Spielt einen offenen Automaten wie ein Zufallsspieler durch und schließt ihn.
func play_automat(v: Voyage) -> void:
	if not v.automat_open:
		return
	match v.automat_kind:
		"harbor", "bonus":
			var n := 0
			while n < 12 and v.automat_can_spin():
				v.automat_spin()
				var guard := 0
				while v.automat.in_free() and guard < 80:
					v.automat_spin()
					guard += 1
				v.automat_bank()
				n += 1
		"loki":
			var rounds := 0
			while rounds < Voyage.LOKI_ROUNDS and v.loki_can_spin():
				var kinds: Array[String] = []
				for st in v.loki_stakes():
					if bool((st as Dictionary)["ok"]):
						kinds.append(String((st as Dictionary)["kind"]))
				if kinds.is_empty() or not v.loki_pick(kinds[randi() % kinds.size()]):
					break
				v.loki_spin()
				if v.loki_pot > 0:
					if randf() < 0.5:
						v.loki_risk()
					v.loki_cash()
				rounds += 1
	v.automat_close()


## Lässt die Folgen ablaufen. Rettungen werden zurückgelassen, Begegnungen bleiben stehen.
func run_until_idle(v: Voyage, limit: int = 800) -> void:
	play_automat(v)
	var n := 0
	while n < limit and (v.phase == Voyage.Phase.RESOLVE or v.phase == Voyage.Phase.RESCUE):
		if v.phase == Voyage.Phase.RESCUE:
			v.decide_rescue(false)
		v._process(0.5)
		n += 1


func invariants(v: Voyage) -> String:
	for i in v.slot_owner.size():
		var m: CrewMember = v.slot_owner[i]
		if m != null and (m.slot != i or m.state != CrewMember.State.ABOARD):
			return "Platz %d inkonsistent (%s)" % [i, m.display_name]
	for rm in v.reserve:
		if rm.state != CrewMember.State.RESERVE or rm.slot >= 0 or v.crew.has(rm):
			return "Reservist %s inkonsistent" % rm.display_name
	for m in v.crew:
		if m.state == CrewMember.State.ABOARD and (m.slot < 0 or v.slot_owner[m.slot] != m):
			return "%s an Bord ohne Platz" % m.display_name
		if m.state != CrewMember.State.ABOARD and m.slot >= 0:
			return "%s hat Platz trotz Zustand %d" % [m.display_name, m.state]
		if m.kraft < 0.0 or m.kraft > 100.0:
			return "Kraft außerhalb"
	if v.mile < 0 or v.mile > Voyage.MILES or v.proviant < 0:
		return "Meile/Proviant außerhalb"
	if v.pos < 0 or v.pos >= (v.map[v.mile] as Array).size():
		return "Position außerhalb der Karte"
	return ""


## Setzt zwei Männer auf bestimmte Plätze (alle sieben Plätze sind besetzt).
func seat(v: Voyage, a: CrewMember, sa: int, b: CrewMember, sb: int) -> void:
	if a.slot != sa:
		v._swap(a, v.slot_owner[sa])
	if b.slot != sb:
		v._swap(b, v.slot_owner[sb])


## Eine zufällige Taktik, die gerade wählbar ist.
func random_tactic(v: Voyage) -> int:
	var opts: Array = Encounters.DATA[v.encounter]["options"]
	var ok: Array[int] = []
	for i in opts.size():
		if Encounters.available(v, opts[i]):
			ok.append(i)
	return ok[randi() % ok.size()]


func start_battle(seed_value: int) -> Voyage:
	var v := new_voyage(seed_value)
	v._enc_pending = Encounters.Id.DRAUGR
	v._advance()
	return v


## Das Manöver einer Vorlage (Strategy.PRESETS) für diese Fahrt.
func pre(v: Voyage, id: int) -> Dictionary:
	var dl: Array = Strategy.preset(id)
	return v.maneuver(int(dl[0]), int(dl[1]), int(dl[2]))


func random_dials(v: Voyage) -> void:
	v.set_dial(0, randi() % 3)
	v.set_dial(1, randi() % 3)
	v.set_dial(2, randi() % 3)


func quiet_node(v: Voyage, col: int, i: int, sea: int) -> void:
	var nd: Dictionary = v.map[col][i]
	nd["sea"] = sea
	nd["hazard"] = Sea.Hazard.NONE
	nd["enc"] = -1


func _init() -> void:
	var v := new_voyage(1)
	check(v.crew.size() == 7, "Start: 7 Mann")

	# --- Seekarte ---
	var map_ok := v.map.size() == Voyage.MILES + 1 and (v.map[0] as Array).size() == 1 and (v.map[Voyage.MILES] as Array).size() == 1
	for c in range(1, Voyage.MILES):
		var n := (v.map[c] as Array).size()
		if n < 2 or n > 3:
			map_ok = false
	check(map_ok, "Karte: 11 Spalten, Heimat und Land einzeln, dazwischen 2-3 Knoten")
	var links_ok := true
	for c in Voyage.MILES:
		var incoming: Array[bool] = []
		incoming.resize((v.map[c + 1] as Array).size())
		incoming.fill(false)
		for i in (v.map[c] as Array).size():
			var ls: Array = v.node_at(c, i)["links"]
			if ls.is_empty():
				links_ok = false
			for j in ls:
				if int(j) < 0 or int(j) >= incoming.size():
					links_ok = false
				else:
					incoming[int(j)] = true
		if incoming.has(false):
			links_ok = false
	check(links_ok, "Karte: jeder Knoten hat Ausgänge und ist erreichbar")
	var reach: Array = [0]
	for c in Voyage.MILES:
		var nxt: Array = []
		for i in reach:
			for j in v.node_at(c, int(i))["links"]:
				if not nxt.has(j):
					nxt.append(j)
		reach = nxt
	check(reach == [0], "Karte: vom Start aus ist das Land erreichbar")
	# Kursentscheidungen: viele Gabelungen, und an den meisten sind die Wege wirklich verschieden
	var forks := 0
	var forks_real := 0
	var maps_with_few := 0
	for sd in range(300, 340):
		var vm := new_voyage(sd)
		var f_here := 0
		for c in range(0, Voyage.MILES - 1):
			for nd in vm.map[c]:
				var lk: Array = nd["links"]
				if lk.size() < 2:
					continue
				f_here += 1
				var lo := 99
				var hi := -1
				var encs := 0
				for j in lk:
					var tg: Dictionary = vm.map[c + 1][int(j)]
					var risk := vm._node_risk(tg)
					lo = mini(lo, risk)
					hi = maxi(hi, risk)
					if int(tg["enc"]) >= 0:
						encs += 1
				if hi - lo >= 2 or (encs > 0 and encs < lk.size()):
					forks_real += 1
		forks += f_here
		if f_here < 4:
			maps_with_few += 1
		vm.queue_free()
	check(float(forks) / 40.0 >= 5.0, "Karte: im Schnitt mindestens fünf Gabelungen je Etappe (%.1f)" % (float(forks) / 40.0))
	check(float(forks_real) >= 0.75 * float(forks), "Karte: an mindestens drei Vierteln der Gabelungen sind die Wege verschieden (%d von %d)" % [forks_real, forks])
	check(maps_with_few <= 2, "Karte: kaum eine Etappe mit weniger als vier Gabelungen (%d von 40)" % maps_with_few)
	var enc_count := 0
	var edge_ok := true
	for c in range(0, Voyage.MILES + 1):
		for nd in v.map[c]:
			if int(nd["enc"]) >= 0:
				enc_count += 1
				if c < 2 or (c > Voyage.MILES - 2 and c < Voyage.MILES):
					edge_ok = false
			if (c == 0 or c == Voyage.MILES) and int(nd["hazard"]) != Sea.Hazard.NONE:
				edge_ok = false
	check(enc_count >= 3 and edge_ok, "Karte: mindestens 3 Begegnungen, keine am Rand")
	check(int(v.node_at(Voyage.MILES, 0)["enc"]) == Encounters.Id.HAFEN and int(v.node_at(Voyage.MILES, 0)["hazard"]) == Sea.Hazard.NONE, "Karte: am Ende der Etappe liegt ein Hafen")
	var harbor_cols: Array[int] = []
	for c in range(0, Voyage.MILES + 1):
		for nd in v.map[c]:
			if int(nd["enc"]) == Encounters.Id.HAFEN:
				harbor_cols.append(c)
				if int(nd["hazard"]) != Sea.Hazard.NONE or int(nd["sea"]) > 2:
					edge_ok = false
	check(not harbor_cols.is_empty() and harbor_cols[0] >= 4 and edge_ok, "Karte: ein geschützter Hafen ab Meile 4 (Spalten %s)" % str(harbor_cols))

	# --- Kurs und Fahrweise ---
	check(v.phase == Voyage.Phase.PLAN and v.route == -1 and v.next_links().size() >= 2, "Planung beginnt ohne gewählten Kurs")
	v.select_strategy(Strategy.Id.BUG_IN_DIE_SEE)
	check(v.route_missing() and not v.can_confirm(), "ohne Kurs kein Auslaufen")
	v.select_route(99)
	check(v.route == -1, "ungültiger Kurs wird ignoriert")
	v.select_route(int(v.next_links()[0]))
	check(v.can_confirm(), "mit Kurs und Fahrweise kann man auslaufen")
	for nd1 in v.map[1]:
		nd1["links"] = [int(nd1["links"][0])]  # geradeaus, damit die Strecke nicht an einer Gabelung endet
	var p := v.plan(pre(v, Strategy.Id.VOLLE_FAHRT))
	check((p["arrivals"] as Array).size() == 2, "volle Fahrt erreicht zwei Knoten")
	check(int((p["arrivals"] as Array)[1][1]) == v.best_successor(1, v.route), "zweiter Schritt: ruhigster Weg")
	for i in Strategy.PRESETS.size():
		check(float(v.plan(pre(v, i))["ratio"]) == 1.0, "Vorlage %d voll besetzt" % i)

	# Mannschaft ordnen
	var a := v.crew[0]
	var b := v.crew[3]
	var sa := a.slot
	var sb := b.slot
	v.click_crew(a)
	v.click_crew(b)
	check(a.slot == sb and b.slot == sa and v.selected == null, "tauschen")

	# Unterbesetzung wirkt
	var rowers: Array[CrewMember] = []
	for m in v.crew:
		if Stations.slot_station(m.slot) == Stations.Id.RUDER:
			rowers.append(m)
	for m in rowers:
		m.kraft = 0.0
	check(float(v.plan(pre(v, Strategy.Id.VOLLE_FAHRT))["miles"]) < 2.0, "erschöpfte Ruderer: keine volle Fahrt")
	check(float(v.plan(pre(v, Strategy.Id.BUG_IN_DIE_SEE))["ratio"]) < 1.0, "Besetzung unter 100 %")
	for m in rowers:
		m.kraft = 100.0

	# --- eine Meile fahren ---
	var target_col := v.mile + 1
	var target_i := v.route
	v.select_strategy(Strategy.Id.BUG_IN_DIE_SEE)
	v.confirm()
	check(v.phase == Voyage.Phase.RESOLVE, "Auslaufen startet die Folgen")
	v.select_strategy(Strategy.Id.VOLLE_FAHRT)
	check(v.sail_set == 1 and v.oars_set == 1 and v.coast_set == 1, "Regler während der Fahrt gesperrt")
	run_until_idle(v)
	check(v.mile == target_col and v.pos == target_i, "Schiff liegt im gewählten Knoten")
	check(bool(v.here().get("visited", false)), "Knoten ist als besucht markiert")
	check(v.leg > 0.05 and v.leg < 0.15 and v.route >= 0, "1,1 Meilen: Knoten erreicht und 10 %% weiter auf dem festgelegten Kurs (leg %.2f)" % v.leg)
	var kept_route := v.route
	v.select_route(99)
	check(v.route == kept_route and v.sea_view == v.location_sea(), "zwischen Knoten bleibt der Kurs stehen")
	check(invariants(v) == "", "nach der Fahrt konsistent")

	# Beidrehen braucht keinen Kurs und bewegt nicht
	var r := new_voyage(7)
	r.select_strategy(Strategy.Id.BEIDREHEN)
	check(r.can_confirm(), "Beidrehen ohne Kurs möglich")
	r.confirm()
	run_until_idle(r)
	check(r.mile == 0 and is_equal_approx(r.leg, 0.0) and r.proviant == Voyage.START_PROVIANT - Strategy.REST_PROVIANT, "Beidrehen: keine Meile, 1 Proviant")

	# --- Begegnungen ---
	var e := new_voyage(11)
	for j in e.next_links():
		quiet_node(e, 1, int(j), 1)
		(e.map[1][int(j)] as Dictionary)["enc"] = Encounters.Id.HAENDLER
	e.select_route(int(e.next_links()[0]))
	e.select_strategy(Strategy.Id.BUG_IN_DIE_SEE)
	e.confirm()
	run_until_idle(e)
	check(e.phase == Voyage.Phase.ENCOUNTER and e.encounter == Encounters.Id.HAENDLER, "Begegnung beim Ankommen")
	check(int(e.here()["enc"]) == -1, "Begegnung ist verbraucht")
	var loot_before := e.loot
	var prov_before := e.proviant
	e.decide_encounter(1)
	run_until_idle(e)
	check(e.loot == loot_before - 30.0 and e.proviant == prov_before + 6, "Handeln: Beute −30, Proviant +6")
	check(e.phase == Voyage.Phase.PLAN and e.encounters_done == 1, "danach wieder Planung")

	# Volle Fahrt rauscht an Begegnungen vorbei
	var f := new_voyage(12)
	for j in (f.map[1] as Array).size():
		quiet_node(f, 1, j, 1)
		(f.map[1][j] as Dictionary)["enc"] = Encounters.Id.INSEL
	for j in (f.map[2] as Array).size():
		quiet_node(f, 2, j, 1)
	f.select_route(int(f.next_links()[0]))
	f.select_strategy(Strategy.Id.VOLLE_FAHRT)
	f.confirm()
	run_until_idle(f)
	check(f.mile == 1 and f.phase == Voyage.Phase.ENCOUNTER, "volle Fahrt hält an der ersten Begegnung an, der Rest der Strecke verfällt")

	# Alle Optionen aller Begegnungen: konsistent, enden in Planung
	var all_ok := true
	var opts_seen := 0
	for type in Encounters.DATA.size():
		if Encounters.is_harbor(type) or Encounters.is_battle(type):
			continue  # Hafen und Seeschlacht haben eigene Tests
		var opt_count: int = (Encounters.DATA[type]["options"] as Array).size()
		for oi in opt_count:
			for sd in range(8):
				var g := new_voyage(300 + sd)
				g._enc_pending = type
				g._advance()
				if g.phase != Voyage.Phase.ENCOUNTER:
					all_ok = false
					continue
				if not Encounters.available(g, Encounters.option(type, oi)):
					continue
				opts_seen += 1
				g.decide_encounter(oi)
				run_until_idle(g)
				if invariants(g) != "" or not (g.phase == Voyage.Phase.PLAN or g.phase == Voyage.Phase.ENDED):
					all_ok = false
					print("   Begegnung ", type, " Option ", oi, ": ", invariants(g), " Phase ", g.phase)
	check(all_ok and opts_seen > 0, "alle Begegnungs-Optionen laufen sauber durch (%d Läufe)" % opts_seen)
	# --- Seeschlacht gegen das Draugr-Schiff ---
	var bt := start_battle(80)
	check(bt.phase == Voyage.Phase.ENCOUNTER and Encounters.is_battle(bt.encounter) and is_equal_approx(float(bt.battle["ehull"]), 60.0) and int(bt.battle["round"]) == 1, "Draugr-Schiff: Seeschlacht beginnt in Runde 1")
	check(Battle.ram_damage(bt) >= 5 and Battle.board_chance(bt) >= 0.1 and Battle.board_chance(bt) <= 0.9 and Battle.lines(bt, "ram").size() > 0 and Battle.lines(bt, "flee").size() > 0, "Seeschlacht: Werte und Kartentexte im Rahmen")
	var bf := start_battle(81)
	var bf_hull := bf.hull
	var bf_loot := bf.loot
	bf.decide_encounter(6)
	run_until_idle(bf)
	check(bf.phase == Voyage.Phase.PLAN and bf.battle.is_empty() and bf.hull < bf_hull and is_equal_approx(bf.loot, bf_loot), "Fliehen beendet den Kampf ohne Beute und kostet Rumpf")
	var bw := start_battle(82)
	bw.battle["ehull"] = 1.0
	var bw_loot := bw.loot
	bw.decide_encounter(0)
	run_until_idle(bw)
	var won_noted := false
	for ev in bw.saga_events:
		if ev["type"] == "battle_win":
			won_noted = true
	check(bw.phase == Voyage.Phase.PLAN and bw.battle.is_empty() and is_equal_approx(bw.loot, bw_loot + 70.0) and won_noted and bw.xp > 0, "Sieg: Beute +70, Erfahrung, Saga merkt den Sieg")
	var bs := start_battle(83)
	bs.battle["intent"] = Battle.Intent.RAM
	var bs_hull := bs.hull
	bs.decide_encounter(4)
	run_until_idle(bs)
	var ba := start_battle(83)
	ba.battle["intent"] = Battle.Intent.RAM
	var ba_hull := ba.hull
	ba.decide_encounter(1)
	run_until_idle(ba)
	check(is_equal_approx(bs_hull - bs.hull, 16.0 * 0.4) and is_equal_approx(ba_hull - ba.hull, 16.0) and bs.phase == Voyage.Phase.ENCOUNTER, "Schildwall mindert den Rammstoß auf 40 %% (%.1f statt %.1f)" % [bs_hull - bs.hull, ba_hull - ba.hull])
	var bto := start_battle(84)
	bto.battle["round"] = Battle.ROUNDS
	bto.battle["ehull"] = 1000.0
	var bto_loot := bto.loot
	bto.decide_encounter(4)
	run_until_idle(bto)
	check(bto.battle.is_empty() and bto.phase == Voyage.Phase.PLAN and is_equal_approx(bto.loot, bto_loot), "Nach der letzten Runde endet der Kampf ohne Beute")
	var board_wins := 0
	var board_losses := 0
	for sd in range(60):
		var bb := start_battle(900 + sd)
		if sd % 2 == 1:  # jede zweite Fahrt: späte Etappe, müde Männer
			bb.stage = 6
			for m in bb.crew:
				m.kraft = 30.0
		bb.decide_encounter(3)
		run_until_idle(bb)
		if bb.battle.is_empty():
			if bb.loot > 100.0:
				board_wins += 1  # der Deckkampf gewann das Schiff
			continue
		board_losses += 1  # der Deckkampf ging verloren oder wurde abgebrochen: die Schlacht geht weiter
	check(board_wins > 0 and board_losses > 0, "Entern (Deckkampf) kann gelingen (%d) und scheitern (%d von 60)" % [board_wins, board_losses])
	var battle_ok := true
	var battles_won := 0
	for sd in range(40):
		var br := start_battle(1200 + sd)
		var rounds := 0
		while br.phase == Voyage.Phase.ENCOUNTER and Encounters.is_battle(br.encounter) and rounds < 12:
			rounds += 1
			br.decide_encounter(random_tactic(br))
			run_until_idle(br)
			if invariants(br) != "":
				battle_ok = false
		if rounds > Battle.ROUNDS or not (br.phase == Voyage.Phase.PLAN or br.phase == Voyage.Phase.ENDED) or not br.battle.is_empty():
			battle_ok = false
			print("   Seeschlacht ", sd, ": Runden ", rounds, " Phase ", br.phase)
		for ev2 in br.saga_events:
			if ev2["type"] == "battle_win":
				battles_won += 1
	check(battle_ok, "40 zufällige Seeschlachten enden sauber in höchstens %d Runden (%d Siege)" % [Battle.ROUNDS, battles_won])

	# --- Beziehungen ---
	var bo := new_voyage(90)
	var seen := {}
	var bonds_ok := bo.bonds.size() >= 1 and int(bo.bonds[0]["type"]) == Voyage.Bond.BROTHER
	for bd in bo.bonds:
		if seen.has(int(bd["a"])) or seen.has(int(bd["b"])) or int(bd["a"]) == int(bd["b"]):
			bonds_ok = false
		seen[int(bd["a"])] = true
		seen[int(bd["b"])] = true
	check(bonds_ok, "Beziehungen: mindestens ein Brüderpaar, jeder Mann nur einmal (%d Paare)" % bo.bonds.size())
	var bx := new_voyage(91)
	var xa := bx.crew[0]
	var xb := bx.crew[1]
	var xc := bx.crew[2]
	var xd := bx.crew[3]
	for m in bx.crew:
		m.traits = []
	bx.bonds = [{"a": xa.id, "b": xb.id, "type": Voyage.Bond.BROTHER}, {"a": xc.id, "b": xd.id, "type": Voyage.Bond.RIVAL}]
	for m in [xa, xb, xc, xd]:
		(m as CrewMember).stress = 50.0
	seat(bx, xa, 0, xb, 1)
	seat(bx, xc, 3, xd, 4)
	bx._bond_effects()
	check(is_equal_approx(xa.stress, 47.0) and is_equal_approx(xb.stress, 47.0), "Brüder nebeneinander beruhigen sich (Mut −3)")
	check(xc.stress >= 52.0 and xd.stress >= 52.0, "Rivalen nebeneinander reizen sich (Verzweiflung +2 oder mehr)")
	xa.stress = 50.0
	xb.stress = 50.0
	xc.stress = 50.0
	xd.stress = 50.0
	seat(bx, xa, 0, xb, 5)
	seat(bx, xc, 2, xd, 6)
	bx._bond_effects()
	check(is_equal_approx(xa.stress, 50.0) and is_equal_approx(xc.stress, 50.0), "Ohne Nachbarschaft keine Wirkung der Beziehungen")
	xb.stress = 20.0
	xd.stress = 20.0
	bx._kill(xa, true)
	bx._kill(xc, true)
	check(is_equal_approx(xb.stress, 50.0) and is_equal_approx(xd.stress, 10.0), "Bruder trauert (Mut +30), Rivale atmet auf (Mut −10)")
	bx.victory = true
	var bx_story := Saga.compose(bx)
	check(bx_story.contains(xb.display_name) and bx_story.contains(xa.display_name), "Saga erzählt von der Trauer um den Bruder")
	var rr := new_voyage(93)
	for m in rr.crew:
		m.traits = []
		m.kraft = 100.0
	rr.bonds = [{"a": rr.crew[0].id, "b": rr.crew[1].id, "type": Voyage.Bond.BROTHER}]
	rr.swimmer = rr.crew[0]
	rr.sea_view = 4
	var bro_chance := rr.rescue_chance(rr.crew[1])
	var other_chance := rr.rescue_chance(rr.crew[2])
	check(is_equal_approx(bro_chance - other_chance, 0.15), "Für den eigenen Bruder zieht man fester (%d %% statt %d %%)" % [roundi(bro_chance * 100.0), roundi(other_chance * 100.0)])
	var hr := new_voyage(94)
	hr.bonds = [{"a": hr.crew[0].id, "b": hr.crew[1].id, "type": Voyage.Bond.BROTHER}]
	hr._kill(hr.crew[0], true)
	hr._roll_recruit()
	hr._hire()
	check(hr.bonds.is_empty() and hr.crew[0].state == CrewMember.State.ABOARD, "Ein Neuer erbt keine Beziehung des Gefallenen")

	# --- Mannschaftsansicht: Plätze anklicken ---
	var cs := new_voyage(95)
	var cs_a := cs.crew[0]
	var cs_b := cs.crew[1]
	var cs_sa := cs_a.slot
	var cs_sb := cs_b.slot
	cs.click_seat(cs_sa)
	check(cs.selected == cs_a, "Platz anklicken wählt den Mann")
	cs.click_seat(cs_sb)
	check(cs_a.slot == cs_sb and cs_b.slot == cs_sa and cs.selected == null, "zwei Plätze anklicken tauscht die Männer")
	cs._kill(cs.crew[2], true)
	var cs_free := -1
	for i in cs.slot_owner.size():
		if cs.slot_owner[i] == null:
			cs_free = i
	cs.click_seat(cs_a.slot)
	cs.click_seat(cs_free)
	check(cs_free >= 0 and cs_a.slot == cs_free and cs.slot_owner[cs_free] == cs_a, "freien Platz anklicken setzt den gewählten Mann dorthin")
	cs._enc_pending = Encounters.Id.INSEL
	cs._advance()
	var cs_before := cs_b.slot
	cs.click_seat(cs_b.slot)
	check(cs.phase == Voyage.Phase.ENCOUNTER and cs.selected == null and cs_b.slot == cs_before, "bei einer Begegnung wird nichts umgestellt")

	# --- Strecke zwischen den Knoten ---
	var ed_p := new_voyage(140)
	for c2 in range(1, 4):
		for i2 in (ed_p.map[c2] as Array).size():
			quiet_node(ed_p, c2, i2, 1)
	for c4 in range(1, 4):
		for nd4 in ed_p.map[c4]:
			nd4["links"] = [int(nd4["links"][0])]
	ed_p.select_route(int(ed_p.next_links()[0]))
	var mv_a := ed_p.simulate_move(0.5)
	var mv_b := ed_p.simulate_move(1.0)
	var mv_c := ed_p.simulate_move(1.6)
	check((mv_a["arrivals"] as Array).is_empty() and is_equal_approx(float(mv_a["leg"]), 0.5), "0,5 Meilen: noch kein Knoten, halber Weg")
	check((mv_b["arrivals"] as Array).size() == 1 and is_equal_approx(float(mv_b["leg"]), 0.0) and int(mv_b["route"]) == -1, "1,0 Meilen: genau am Knoten, neuer Kurs nötig")
	check((mv_c["arrivals"] as Array).size() == 1 and is_equal_approx(float(mv_c["leg"]), 0.6) and int(mv_c["route"]) >= 0, "1,6 Meilen: ein Knoten und 60 % weiter, Kurs steht")
	(ed_p.map[1][0] as Dictionary)["enc"] = Encounters.Id.INSEL
	var mv_d := ed_p.simulate_move(1.9)
	check(String(mv_d["stop"]) == "encounter" and (mv_d["arrivals"] as Array).size() == 1 and is_equal_approx(float(mv_d["leg"]), 0.0), "an einem Knoten mit Begegnung hält das Schiff an")
	(ed_p.map[1][0] as Dictionary)["enc"] = -1
	var fork_nd: Dictionary = ed_p.map[1][0]
	var saved_links: Array = fork_nd["links"]
	fork_nd["links"] = [0, 1]
	var mv_f := ed_p.simulate_move(1.9)
	check(String(mv_f["stop"]) == "fork" and (mv_f["arrivals"] as Array).size() == 1 and int(mv_f["route"]) == -1, "an einer Gabelung hält das Schiff an: Kurs wählt der Spieler")
	fork_nd["links"] = saved_links
	ed_p.set_dial(0, 1)
	ed_p.set_dial(1, 0)
	ed_p.set_dial(2, 1)  # nur gerefftes Segel: 0,5 Meilen
	ed_p.confirm()
	run_until_idle(ed_p)
	check(ed_p.mile == 0 and is_equal_approx(ed_p.leg, 0.5) and ed_p.route == 0 and ed_p.phase == Voyage.Phase.PLAN, "halbe Fahrt: das Schiff liegt zwischen den Knoten, der Kurs bleibt")
	check(ed_p.can_confirm(), "zwischen Knoten braucht man keinen neuen Kurs")
	ed_p.confirm()
	run_until_idle(ed_p)
	check(ed_p.mile == 1 and is_equal_approx(ed_p.leg, 0.0) and ed_p.total_miles > 0.9, "zwei halbe Fahrten ergeben einen Knoten")

	# --- Etappen, Stufen, Endlosfahrt ---
	var ed_s := new_voyage(121)
	ed_s.mile = Voyage.MILES
	ed_s.pos = 0
	ed_s._enc_pending = Encounters.Id.HAFEN
	ed_s._advance()
	check(ed_s.phase == Voyage.Phase.ENCOUNTER and Encounters.is_harbor(ed_s.encounter), "Ankunft am Hafen am Ende der Etappe")
	var xp_before := ed_s.xp + ed_s.level * 1000
	ed_s.decide_encounter(6)
	run_until_idle(ed_s)
	check(not ed_s.ended and ed_s.stage == 2 and ed_s.mile == 0 and ed_s.phase == Voyage.Phase.PLAN, "Ablegen im Zielhafen beginnt die nächste Etappe, die Fahrt geht weiter")
	check(ed_s.xp + ed_s.level * 1000 > xp_before and int(ed_s.node_at(Voyage.MILES, 0)["enc"]) == Encounters.Id.HAFEN, "Etappe bringt Erfahrung und hat wieder einen Hafen am Ende")
	var ed_r := new_voyage(122)
	ed_r.max_stage = 1
	ed_r.mile = Voyage.MILES
	ed_r._enc_pending = Encounters.Id.HAFEN
	ed_r._advance()
	ed_r.decide_encounter(6)
	run_until_idle(ed_r)
	check(ed_r.ended and ed_r.victory and ed_r.cause == "retire", "Rentenstufe für Tests und Bots beendet die Fahrt")
	var ed_l := new_voyage(123)
	ed_l.gain_xp(ed_l.xp_needed())
	check(ed_l.level == 2 and ed_l.perk_offer.size() == 3 and not ed_l.can_confirm(), "Stufenaufstieg: drei Segen zur Wahl, vorher kein Auslaufen")
	var perk_id := String(ed_l.perk_offer[0])
	ed_l.choose_perk(0)
	check(ed_l.perks == [perk_id] and ed_l.perk_offer.is_empty(), "Segen gewählt")
	var sea1 := 0.0
	var sea5 := 0.0
	var hz1 := 0
	var hz5 := 0
	var ed_m := new_voyage(124)
	for k in range(40):
		ed_m.stage = 1
		ed_m._make_map()
		for c3 in range(1, Voyage.MILES):
			for nd in ed_m.map[c3]:
				sea1 += float(nd["sea"])
				hz1 += 1 if int(nd["hazard"]) != Sea.Hazard.NONE else 0
		ed_m.stage = 6
		ed_m._make_map()
		for c3 in range(1, Voyage.MILES):
			for nd in ed_m.map[c3]:
				sea5 += float(nd["sea"])
				hz5 += 1 if int(nd["hazard"]) != Sea.Hazard.NONE else 0
	check(sea5 > sea1 and hz5 > hz1 and is_equal_approx(ed_m.stage_mul(), 1.0 + 5.0 * Voyage.STAGE_HARDNESS), "spätere Etappen: rauere See, mehr Gefahren, Faktor %.2f (Seegang %.1f -> %.1f)" % [ed_m.stage_mul(), sea1 / 40.0, sea5 / 40.0])
	var ed_d := new_voyage(125)
	ed_d.stage = 3
	ed_d._enc_pending = Encounters.Id.DRAUGR
	ed_d._advance()
	check(is_equal_approx(float(ed_d.battle["ehull"]), 84.0) and int(ed_d.battle["ecrew"]) == 7, "Gegner werden mit der Etappe stärker (Rumpf 84, 7 Draugr)")
	var ed_f := new_voyage(126)
	ed_f.proviant = 30
	ed_f._apply_fx({"proviant": 10})
	check(ed_f.proviant == 32, "Proviant ist durch das Lager begrenzt")

	# --- Gegenstände und Segen ---
	var ed_i := new_voyage(127)
	check(is_equal_approx(ed_i.hull_max(), 100.0) and ed_i.cannons() == 0, "ohne Gegenstände: Rumpf 100, keine Kanonen")
	ed_i.equip("beschlag")
	check(is_equal_approx(ed_i.hull_max(), 120.0) and is_equal_approx(ed_i.stat("armor"), 1.0), "Eisenbeschläge: Rumpf +20, Panzerung +1")
	ed_i.equip("planken")  # gleicher Platz: ersetzt die Beschläge
	check(is_equal_approx(ed_i.hull_max(), 140.0) and is_equal_approx(ed_i.stat("armor"), 0.0) and ed_i.items.size() == 1, "ein neuer Gegenstand ersetzt den alten auf dem Platz")
	ed_i.equip("kanone")
	ed_i.equip("schwere")
	check(ed_i.cannons() == 2 and ed_i.items.size() == 3, "zwei Kanonen passen auf die beiden Kanonenplätze")
	var base_miles := float(Strategy.build(1, 1, 1)["miles"])
	ed_i.equip("tuch")
	check(float(ed_i.maneuver(1, 1, 1)["miles"]) > base_miles, "besseres Segeltuch bringt mehr Vortrieb")
	ed_i.perks.append("wind")
	ed_i._mods = {}
	check(is_equal_approx(ed_i.stat("sail"), 1.15 * 1.1 * 0.95), "Segen und Gegenstände wirken zusammen (Segel %.3f)" % ed_i.stat("sail"))
	check(Items.slots_for("kanone") == [4, 5] and Items.slots_for("fass") == [6], "Kanonen haben zwei Plätze, ein Fass einen")
	var ed_k := new_voyage(128)
	ed_k.hull = 60.0
	ed_k.proviant = 10
	ed_k._enc_pending = Encounters.Id.INSEL
	ed_k._advance()
	ed_k.decide_encounter(2)
	run_until_idle(ed_k)
	check(ed_k.hull >= 79.0 and ed_k.proviant == 9, "Insel: in der Bucht flicken (Rumpf +20, Proviant −1)")
	var ed_h := new_voyage(129)
	ed_h.hull = 60.0
	var ed_h_loot := ed_h.loot
	ed_h._enc_pending = Encounters.Id.DORF
	ed_h._advance()
	ed_h.decide_encounter(2)
	run_until_idle(ed_h)
	check(ed_h.hull >= 84.0 and is_equal_approx(ed_h.loot, ed_h_loot - 25.0), "Küstendorf: Handwerker flicken (Rumpf +25, Beute −25)")

	# --- Kanonen und Gegnerarten ---
	var cb := start_battle(130)
	check(not Battle.can_use(cb, "cannon") and not Encounters.available(cb, Encounters.option(Encounters.Id.DRAUGR, 2)), "ohne Kanonen keine Breitseite")
	cb.equip("kanone")
	cb.equip("kanone")
	check(not Battle.can_use(cb, "cannon"), "ohne Pulver keine Breitseite")
	cb.powder = 3
	check(Battle.can_use(cb, "cannon") and Battle.cannon_damage(cb) >= 20, "mit Kanonen und Pulver: Breitseite (%d Schaden)" % Battle.cannon_damage(cb))
	cb.battle["intent"] = Battle.Intent.DIRGE
	var ehull0 := float(cb.battle["ehull"])
	cb.decide_encounter(2)
	run_until_idle(cb)
	check(cb.powder == 2 and float(cb.battle["ehull"]) < ehull0 - 15.0 and int(cb.battle["reload"]) == 1 and not Battle.can_use(cb, "cannon"), "Breitseite: Pulver −1, Gegner-Rumpf sinkt, danach eine Runde Nachladen")
	cb.battle["intent"] = Battle.Intent.DIRGE
	cb.decide_encounter(4)
	run_until_idle(cb)
	check(int(cb.battle["reload"]) == 0 and Battle.can_use(cb, "cannon"), "nach einer Runde ist wieder geladen")
	var rb := start_battle(131)
	rb.hull = 40.0
	rb.battle["intent"] = Battle.Intent.DIRGE
	rb.decide_encounter(5)
	run_until_idle(rb)
	check(rb.hull > 55.0, "Flicken: die Zimmerleute stopfen Löcher (Rumpf 40 -> %d)" % roundi(rb.hull))
	var rdr := new_voyage(132)
	rdr._enc_pending = Encounters.Id.RAEUBER
	rdr._advance()
	check(String(rdr.battle["enemy"]) == "raeuber" and int(rdr.battle["ecrew"]) == 8 and is_equal_approx(float(rdr.battle["ehull"]), 50.0), "Räuberschiff: 50 Rumpf, 8 Räuber")
	rdr.battle["intent"] = Battle.Intent.SHOOT
	var rdr_hull := rdr.hull
	rdr.decide_encounter(1)
	run_until_idle(rdr)
	check(rdr.hull < rdr_hull - 8.0, "Räuber schießen: Rumpf −11 (%d)" % roundi(rdr_hull - rdr.hull))
	rdr.battle["intent"] = Battle.Intent.SHOOT
	rdr.equip("beschlag")
	var rdr_hull2 := rdr.hull
	rdr.decide_encounter(1)
	run_until_idle(rdr)
	check(rdr_hull2 - rdr.hull < rdr_hull - rdr_hull2 + 0.1 or rdr.battle.is_empty(), "Panzerung nimmt jedem Treffer etwas ab")

	# --- Kraken ---
	var kr := new_voyage(150)
	kr._enc_pending = Encounters.Id.KRAKEN
	kr._advance()
	check(Encounters.is_battle(kr.encounter) and String(kr.battle["enemy"]) == "kraken" and is_equal_approx(float(kr.battle["ehull"]), 85.0) and int(kr.battle["ecrew"]) == 6, "Kraken: 85 Rumpf, 6 Tentakel")
	kr.battle["intent"] = Battle.Intent.CRUSH
	var kr_hull := kr.hull
	kr.decide_encounter(1)
	run_until_idle(kr)
	check(is_equal_approx(kr_hull - kr.hull, 22.0), "Kraken: Zerquetschen kostet 22 Rumpf")
	var kr_over := 0
	for sd in range(30):
		var kg := new_voyage(1500 + sd)
		kg._enc_pending = Encounters.Id.KRAKEN
		kg._advance()
		kg.battle["intent"] = Battle.Intent.GRAB
		kg.decide_encounter(1)
		run_until_idle(kg)
		if not kg._pending.is_empty():
			kr_over += 1
	check(kr_over > 3 and kr_over < 30, "Kraken: Tentakelgriff reißt manchmal einen Mann über Bord (%d von 30)" % kr_over)
	var ed_t := new_voyage(151)
	ed_t.stage = 2
	var kraken_stage2 := 0
	for k in range(300):
		if Encounters.random_type(2, 0) == Encounters.Id.KRAKEN or Encounters.random_type(2, 4) == Encounters.Id.KRAKEN:
			kraken_stage2 += 1  # auch in der Totensee gibt es vor Etappe 3 keine Kraken
	var kraken_stage5 := 0
	for k in range(300):
		if Encounters.random_type(5, 4) == Encounters.Id.KRAKEN:
			kraken_stage5 += 1
	check(kraken_stage2 == 0 and kraken_stage5 > 10, "Kraken erscheinen erst ab Etappe 3, in der Totensee häufig (%d von 300)" % kraken_stage5)

	# --- Müdigkeit und Wachablösung ---
	check(CrewMember.kraft_efficiency(100.0) == 1.0 and absf(CrewMember.kraft_efficiency(40.0) - 0.9) < 0.001 and absf(CrewMember.kraft_efficiency(15.0) - 0.65) < 0.001, "Müdigkeit: Leistung 100 / 90 / 65 % an den Stufengrenzen")
	var eff_ok := true
	var eff_last := 0.0
	for kv in range(0, 101, 5):
		var ev := CrewMember.kraft_efficiency(float(kv))
		if ev < eff_last:
			eff_ok = false
		eff_last = ev
	check(eff_ok, "Müdigkeit: Leistung steigt stetig mit der Kraft, keine Klippe")
	var rl := new_voyage(808)
	var rl_worker: CrewMember = rl.slot_owner[3]  # Ruder
	var rl_rest: CrewMember = rl.slot_owner[6]  # Ladungsbank
	check(Stations.slot_station(3) == Stations.Id.RUDER and Stations.slot_station(6) == Stations.Id.LADUNG, "Wachablösung: Testplätze stimmen")
	rl_worker.kraft = 20.0
	rl_rest.kraft = 90.0
	rl.relief = false
	rl._auto_relief()
	check(rl_worker.slot == 3 and rl_rest.slot == 6, "Wachablösung aus: niemand wird getauscht")
	rl.relief = true
	rl._auto_relief()
	check(rl_worker.slot == 6 and rl_rest.slot == 3, "Wachablösung an: der Müde ruht auf der Ladungsbank, der Frische rudert")
	rl_rest.kraft = 30.0
	rl_worker.kraft = 10.0
	rl._auto_relief()
	check(rl_worker.slot == 6, "Wachablösung: ohne frischen Ersatz bleibt alles, wie es ist")
	var rest_cost: Dictionary = Strategy.build(0, 0, 1)["cost"]
	check(int(rest_cost[Stations.Id.LADUNG]) <= -25, "Beidrehen erholt deutlich (Ladung %d)" % int(rest_cost[Stations.Id.LADUNG]))
	check(int(Strategy.build(1, 1, 1)["cost"][Stations.Id.RUDER]) <= 6, "Rudern ruhig kostet nur noch 6 Kraft je Fahrt")

	# --- Reserve ---
	var rsv := new_voyage(900)
	for m in rsv.crew:
		m.traits = []
	rsv.loot = 600.0
	rsv._enc_pending = Encounters.Id.HAFEN
	rsv._advance()
	check(rsv.hire_candidate(0) and rsv.hire_candidate(0) and rsv.reserve.size() == 2 and rsv.reserve_cap() == 2, "Reserve: zwei Anwärter in der Reserve")
	check(not rsv.can_recruit() and not rsv.hire_candidate(0), "Reserve voll: kein weiteres Anheuern")
	rsv.equip("haengematte")
	check(rsv.reserve_cap() == 4 and rsv.hire_candidate(0) and rsv.reserve.size() == 3, "Hängematten: vier Plätze, ein dritter Mann")
	check(rsv.headcount() == 10 and rsv.extra_food() == 1, "zehn Mann an Bord: ein Proviant mehr je Fahrt (%d)" % rsv.extra_food())
	check(rsv.plan()["proviant"] == 2, "die Vorschau nennt den Zusatzproviant")
	var rsv_pre := rsv.reserve[0]
	var rsv_act: CrewMember = rsv.slot_owner[3]
	rsv.click_crew(rsv_pre)
	rsv.click_crew(rsv_act)
	check(rsv_pre.slot == 3 and rsv_pre.state == CrewMember.State.ABOARD and rsv_act.state == CrewMember.State.RESERVE and rsv.reserve.has(rsv_act) and invariants(rsv) == "", "im Hafen tauscht die Reserve mit einem Mann an Deck")
	rsv.decide_encounter(6)
	run_until_idle(rsv)
	check(rsv.phase == Voyage.Phase.PLAN and rsv.can_use_reserve(), "am Etappenanfang darf man die Reserve einsetzen")
	rsv.mile = 3
	rsv.pos = 0
	var rsv_res1 := rsv.reserve[0]
	var rsv_seat_man: CrewMember = rsv.slot_owner[4]
	rsv.click_crew(rsv_res1)
	rsv.click_crew(rsv_seat_man)
	check(rsv_res1.state == CrewMember.State.RESERVE and rsv_seat_man.state == CrewMember.State.ABOARD and not rsv.can_use_reserve(), "mitten auf der Etappe bleibt die Reserve unten")
	rsv.mile = 0
	rsv.reserve[0].kraft = 40.0
	rsv._reserve_rest()
	check(is_equal_approx(rsv.reserve[0].kraft, 55.0), "Reserve erholt sich je Fahrt um 15 Kraft")
	var rsv_dict := JSON.parse_string(JSON.stringify(rsv.to_dict())) as Dictionary
	var rsv2 := Voyage.new()
	root.add_child(rsv2)
	rsv2.resume(rsv_dict)
	check(rsv2.reserve.size() == rsv.reserve.size() and rsv2.reserve[0].display_name == rsv.reserve[0].display_name and rsv2.reserve[0].state == CrewMember.State.RESERVE and rsv2.headcount() == rsv.headcount() and invariants(rsv2) == "", "Speichern und Fortsetzen: die Reserve bleibt erhalten")
	rsv2.queue_free()
	var rsv_dead: CrewMember = rsv.slot_owner[2]
	rsv._kill(rsv_dead, true)
	var rsv_before := rsv.reserve.size()
	rsv._fill_from_reserve()
	check(rsv.slot_owner[2] != null and rsv.reserve.size() == rsv_before - 1 and invariants(rsv) == "", "Ein Gefallener wird aus der Reserve ersetzt")
	var rsv_gone := rsv.reserve[0]
	check(rsv.dismiss(rsv_gone) and not rsv.reserve.has(rsv_gone), "Entlassen nimmt den Mann von Bord")
	rsv.queue_free()

	# --- Lager ---
	var cp := new_voyage(950)
	for m in cp.crew:
		m.traits = []
	cp.crew[0].traits = [Traits.Id.STERNGUCKER]
	cp.crew[1].traits = [Traits.Id.SCHWIMMER]
	cp.mile = 2
	cp.pos = 0
	var cp_node := cp.here()
	cp_node["sea"] = 1
	cp_node["hazard"] = Sea.Hazard.NONE
	cp_node["cove"] = false
	check(cp.can_camp(), "Lager: auf ruhiger See ohne Gefahr möglich")
	cp_node["sea"] = 4
	check(not cp.can_camp() and cp.camp_reason().begins_with("Zu rau"), "Lager: bei rauer See nicht, mit Begründung")
	cp_node["cove"] = true
	check(cp.can_camp(), "Lager: in einer Ankerbucht auch bei raucher See")
	cp.leg = 0.4
	check(not cp.can_camp(), "Lager: nicht zwischen zwei Knoten")
	cp.leg = 0.0
	for m in cp.crew:
		m.kraft = 30.0
		m.stress = 50.0
	var cp_prov := cp.proviant
	cp.camp_start()
	check(cp.camping and cp.camp_points == Camp.POINTS and cp.proviant == cp_prov - 2 and cp.camps_used == 1 and not cp.can_confirm(), "Lager: aufgeschlagen, Proviant −2, sechs Punkte, keine Fahrt währenddessen")
	check(cp.camp_do("sleep") and cp.camp_points == 4 and is_equal_approx(cp.crew[2].kraft, 70.0) and is_equal_approx(cp.crew[2].stress, 40.0), "Lager: Schlafen kostet 2 Punkte, Kraft +40, Verzweiflung −10")
	check(not cp.camp_do("sleep"), "Lager: man schläft nur einmal")
	var cp_food := cp.proviant
	check(cp.camp_do("eat") and cp.proviant == cp_food - Camp.food_needed(cp) and is_equal_approx(cp.crew[2].kraft, 90.0), "Lager: Essen kostet Proviant und gibt Kraft +20")
	check(cp.camp_do("watch") and cp.camp_watch != null and cp.camp_points == 2, "Lager: Wache gestellt")
	var cp_p2 := cp.proviant
	check(cp.camp_do("fish") and cp.proviant >= cp_p2 + 3, "Lager: Fischen mit einem Schwimmer bringt Proviant")
	check(not cp.camp_do("repair"), "Lager: Flicken geht nicht, wenn der Rumpf heil ist")
	cp.hull = 60.0
	var cp_vis := cp.visible_cols()
	check(not cp.camp_do("map") or cp.visible_cols() == cp_vis + 1, "Lager: Karten lesen erweitert die Sicht um eine Meile")
	check(cp.camp_points == 0 and not cp.camp_do("song"), "Lager: ohne Punkte keine Aktion")
	check(cp.camp_night_chance() < 0.05, "Lager: in der Bucht mit Wache ist die Nacht fast sicher (%.3f)" % cp.camp_night_chance())
	cp.camp_end()
	check(not cp.camping and cp.phase == Voyage.Phase.PLAN and not cp.can_camp() and cp.camp_reason().begins_with("Auf dieser Etappe"), "Lager: Aufbrechen beendet es, nur eines je Etappe")
	cp_node["cove"] = false
	cp.camp_slept = true
	cp.camp_watch = null
	check(cp.camp_night_chance() >= 0.2, "Lager: offene Küste, geschlafen ohne Wache: die Nacht ist unsicher (%.2f)" % cp.camp_night_chance())
	var cp_coves_ok := true
	for sd in range(960, 980):
		var cv := new_voyage(sd)
		var cv_n := 0
		for col in cv.map:
			for nd in col:
				if bool(nd.get("cove", false)):
					cv_n += 1
					if int(nd["enc"]) >= 0 or int(nd["hazard"]) != Sea.Hazard.NONE or int(nd["sea"]) > 2:
						cp_coves_ok = false
		if cv_n < 1:
			cp_coves_ok = false
		cv.queue_free()
	check(cp_coves_ok, "Karte: jede Etappe hat eine Ankerbucht (ruhig, ohne Begegnung)")
	var cp_dict := JSON.parse_string(JSON.stringify(cp.to_dict())) as Dictionary
	var cp2 := Voyage.new()
	root.add_child(cp2)
	cp2.resume(cp_dict)
	check(cp2.camps_used == cp.camps_used and bool(cp2.here().get("cove", false)) == bool(cp.here().get("cove", false)), "Speichern: Lagerzähler und Ankerbuchten bleiben erhalten")
	cp2.queue_free()
	cp.queue_free()

	# --- Deckkampf ---
	var cbv := new_voyage(1000)
	for m in cbv.crew:
		m.traits = []
		m.kraft = 100.0
		m.stress = 0.0
	var cb_roles := [Roles.Id.SCHILD, Roles.Id.AXT, Roles.Id.BOGEN, Roles.Id.SKALDE]
	var cb_party: Array = []
	for k in 4:
		cbv.crew[k].role = cb_roles[k]
		cb_party.append(cbv.crew[k])
	var cb_units: Array[String] = ["rost", "rost", "bogner"]
	var cbc := Combat.create(cbv, "draugr", cb_party, cb_units, 1)
	check(cbc.heroes.size() == 4 and cbc.foes.size() == 3 and cbc.heroes[0].rank == 0 and cbc.heroes[3].rank == 3, "Kampf: vier Männer in Reihen 1–4, drei Gegner")
	var cb_bow := cbc.heroes[2]
	var cb_axe := cbc.heroes[1]
	var cb_shield := cbc.heroes[0]
	check(not cbc.can_use(cb_bow, "b_schuss") == false and cbc.can_use(cb_bow, "b_schuss"), "Kampf: der Bogenschütze schießt aus Reihe 3")
	check(not cbc.can_use(cb_axe, "a_ansturm") == false, "Kampf: Ansturm geht aus Reihe 2")
	check(cbc.can_use(cbc.heroes[3], "k_heil") and not cbc.can_use(cbc.heroes[3], "k_stab") and not cbc.can_use(cb_shield, "k_heil"), "Kampf: der Skalde heilt aus Reihe 4, sticht aber nicht von dort; Heilsegen nicht aus Reihe 1")
	var cb_foe0 := cbc.foes[0]
	check(is_equal_approx(cbc.hit_chance(cb_axe, cb_foe0, Roles.skill("a_hieb")), 90.0), "Kampf: Treffer 90 % gegen Ausweichen 0")
	cb_foe0.mark = 2
	check(is_equal_approx(cbc.hit_chance(cb_axe, cb_foe0, Roles.skill("a_hieb")), 95.0), "Kampf: Markierung macht Treffer leichter")
	cb_foe0.mark = 0
	cb_axe.man.kraft = 30.0
	check(is_equal_approx(cbc.hit_chance(cb_axe, cb_foe0, Roles.skill("a_hieb")), 80.0), "Kampf: Müde treffen schlechter (−10)")
	cb_axe.man.kraft = 100.0
	# Zustände: Betäubung, Blutung (Draugr sind immun gegen Blutung)
	var cb_stunned := false
	var cb_bled := false
	var cb_immune_ok := true
	for k in 60:
		var cbt := Combat.create(cbv, "raeuber", cb_party, ["brecher", "messerkerl"] as Array[String], 1)
		cbt.begin()
		cbt._execute(cbt.heroes[0], "s_stoss", cbt.foes[0])
		if cbt.foes[0].stun > 0:
			cb_stunned = true
		cbt._execute(cbt.heroes[1], "a_spalt", cbt.foes[1])
		if cbt.foes[1].bleed_turns > 0:
			cb_bled = true
		var cbd := Combat.create(cbv, "draugr", cb_party, ["rost"] as Array[String], 1)
		cbd._execute(cbd.heroes[1], "a_spalt", cbd.foes[0])
		if cbd.foes[0].bleed_turns > 0:
			cb_immune_ok = false
	check(cb_stunned, "Kampf: Schildstoß betäubt")
	check(cb_bled, "Kampf: Spaltschlag lässt bluten")
	check(cb_immune_ok, "Kampf: Draugr sind gegen Blutung immun")
	# An der Schwelle: erst Schwelle, dann 50 % Tod je Treffer
	var cb_deaths := 0
	var cb_door_first := true
	for k in 80:
		var cbs := Combat.create(cbv, "draugr", cb_party, ["rost"] as Array[String], 1)
		var hh := cbs.heroes[1]
		hh.man.stress = 0.0
		hh.hp = 5.0
		hh.man.kraft = 5.0
		cbs._hurt(hh, 10, null)
		if not (hh.door and hh.hp == 0.0 and not hh.gone):
			cb_door_first = false
		for t in 6:
			cbs._hurt(hh, 5, null)
		if hh.gone and cbs.casualties.has(hh.man):
			cb_deaths += 1
		hh.man.kraft = 100.0
	check(cb_door_first and cb_deaths > 60, "Kampf: bei 0 Kraft an der Schwelle, weitere Treffer töten (%d von 80)" % cb_deaths)
	# Kämpfe laufen durch: stark gegen schwach, schwach gegen stark
	var cb_wins := 0
	var cb_loses := 0
	var cb_ranks_ok := true
	for k in 40:
		for m in cbv.crew:
			m.kraft = 100.0
			m.stress = 0.0
		var cbw := Combat.create(cbv, "draugr", cb_party, Foes.units_for("draugr", 1), 1)
		cbw.begin()
		cbw.auto_play()
		if cbw.result == "win":
			cb_wins += 1
		cbw.finish()
	for k in 40:
		for m in cbv.crew:
			m.kraft = 25.0
		var cbl := Combat.create(cbv, "raeuber", cb_party, Foes.units_for("raeuber", 7), 7)
		cbl.begin()
		cbl.auto_play()
		if cbl.result == "lose" or cbl.result == "flee":
			cb_loses += 1
		if cbl.heroes.size() > 4 or cbl.foes.size() > 4:
			cb_ranks_ok = false
	check(cb_wins >= 28, "Kampf: Etappe 1, frische Männer gewinnen meist gegen die Draugr (%d von 40)" % cb_wins)
	check(cb_loses >= 28 and cb_ranks_ok, "Kampf: Etappe 7 mit müden Männern geht meist verloren (%d von 40)" % cb_loses)
	for m in cbv.crew:
		m.kraft = 100.0
		m.stress = 0.0
	# Einbau: Handelsschiff überfallen (schnell aufgelöst), Seeschlacht "Entern", Aufstellung von Hand
	var cb_loot_gain := 0
	var cb_fights_ok := true
	for sd in range(1010, 1030):
		var cfv := new_voyage(sd)
		cfv.loot = 50.0
		cfv._enc_pending = Encounters.Id.HAENDLER
		cfv._advance()
		cfv.decide_encounter(0)
		run_until_idle(cfv)
		if cfv.phase == Voyage.Phase.COMBAT or cfv.combat != null or not cfv.fight_prep.is_empty() or invariants(cfv) != "":
			cb_fights_ok = false
		if cfv.loot > 60.0:
			cb_loot_gain += 1
		cfv.queue_free()
	check(cb_fights_ok and cb_loot_gain >= 6, "Handelsschiff überfallen: wird bekämpft, die Fahrt geht weiter, Sieg bringt Beute (%d von 20)" % cb_loot_gain)
	var cb_sea_ok := true
	for sd in range(1040, 1050):
		var csv := new_voyage(sd)
		csv._enc_pending = Encounters.Id.DRAUGR
		csv._advance()
		csv.decide_encounter(3)  # Entern
		run_until_idle(csv)
		if csv.phase == Voyage.Phase.COMBAT or csv.combat != null or invariants(csv) != "":
			cb_sea_ok = false
		csv.queue_free()
	check(cb_sea_ok, "Seeschlacht: Entern ist ein Deckkampf und führt die Schlacht fort")
	var cmv := new_voyage(1060)
	cmv.auto_combat = false
	cmv._enc_pending = Encounters.Id.DORF
	cmv._advance()
	cmv.decide_encounter(0)
	check(cmv.phase == Voyage.Phase.COMBAT and not cmv.fight_prep.is_empty() and (cmv.fight_prep["party"] as Array).size() == 4, "Aufstellung: der Kampf beginnt mit einer Vorauswahl von vier Männern")
	var cmv_first: CrewMember = (cmv.fight_prep["party"] as Array)[0]
	cmv.fight_toggle(cmv_first)
	check((cmv.fight_prep["party"] as Array).size() == 3 and not (cmv.fight_prep["party"] as Array).has(cmv_first), "Aufstellung: einen Mann herausnehmen")
	cmv.fight_toggle(cmv_first)
	cmv.fight_shift(cmv_first, -1)
	check((cmv.fight_prep["party"] as Array).size() == 4 and cmv.fight_begin() and cmv.combat != null and cmv.fight_prep.is_empty(), "Aufstellung bestätigen: der Kampf läuft")
	cmv.combat.auto_play()
	cmv._process(0.1)
	check(cmv.combat == null and cmv.phase == Voyage.Phase.RESOLVE, "Kampfende: zurück in den Ablauf")
	run_until_idle(cmv)
	check(cmv.phase == Voyage.Phase.PLAN and invariants(cmv) == "", "nach dem Kampf geht die Fahrt weiter, alles konsistent")
	var crd := JSON.parse_string(JSON.stringify(cmv.to_dict())) as Dictionary
	var crv3 := Voyage.new()
	root.add_child(crv3)
	crv3.resume(crd)
	var cb_roles_same := true
	for k in cmv.crew.size():
		if crv3.crew[k].role != cmv.crew[k].role:
			cb_roles_same = false
	check(cb_roles_same, "Speichern: die Kampfrollen bleiben erhalten")
	crv3.queue_free()
	cmv.queue_free()
	cbv.queue_free()
	# Kampffiguren: das Bild hat eine Zeile je Rolle (4) und je Gegnerart, fünf Posen
	var cb_img := Image.load_from_file("res://assets/combat.png")
	var cb_rows := Roles.ROLES.size() + Foes.ROW.size()
	check(cb_img != null and cb_img.get_width() == 44 * 5 and cb_img.get_height() == 56 * cb_rows, "Kampffiguren: assets/combat.png hat %d Zeilen zu 5 Posen" % cb_rows)
	var cb_row_ok := true
	for key in Foes.TYPES:
		if Foes.is_big(key):
			continue
		if not Foes.ROW.has(key) or int(Foes.ROW[key]) < Roles.ROLES.size() or int(Foes.ROW[key]) >= cb_rows:
			cb_row_ok = false
	check(cb_row_ok and Foes.ROW.size() + Foes.BIG.size() == Foes.TYPES.size(), "Kampffiguren: jede Gegnerart hat eine Zeile im Bild oder ein Riesenbild")
	var cb_big_ok := true
	for key in Foes.BIG:
		var bimg := Image.load_from_file(String(Foes.BIG[key]["file"]))
		if bimg == null or bimg.get_width() != int(Foes.BIG[key]["w"]) * 5 or bimg.get_height() != int(Foes.BIG[key]["h"]):
			cb_big_ok = false
	check(cb_big_ok, "Kampffiguren: das Riesenbild des Kraken hat fünf Posen")
	var cb_sfx_ok := true
	for sid in Roles.SKILLS:
		if not Sfx.SKILL_SND.has(sid):
			cb_sfx_ok = false
			print("   ohne Kampfgeräusch: ", sid)
	for sid in Sfx.SKILL_SND:
		for snd in Sfx.SKILL_SND[sid]:
			if String(snd) != "" and not Sfx.GAIN.has(String(snd)):
				cb_sfx_ok = false
				print("   unbekannter Klang: ", snd)
	check(cb_sfx_ok and Sfx.GAIN.has("whiff") and Sfx.GAIN.has("fall") and Sfx.GAIN.has("heal"), "Kampfgeräusche: jede Fertigkeit hat Klänge, alle Klänge sind eingetragen")
	var cbe_v := new_voyage(1100)
	var cbe_party: Array = [cbe_v.crew[0], cbe_v.crew[1], cbe_v.crew[2], cbe_v.crew[3]]
	var cbe := Combat.create(cbe_v, "raeuber", cbe_party, Foes.units_for("raeuber", 1), 1)
	cbe.begin()
	cbe.auto_play()
	var cbe_types := {}
	for ev in cbe.events:
		cbe_types[String(ev["type"])] = true
	check(cbe_types.has("attack") and cbe_types.has("hit") and cbe_types.has("die"), "Kampf: Ereignisse für die Anzeige (Angriff, Treffer, Tod) werden gemeldet")
	var cbe_sk := true
	for ev in cbe.events:
		if String(ev["type"]) == "attack" and not Sfx.SKILL_SND.has(String(ev["sk"])):
			cbe_sk = false
	check(cbe_sk, "Kampf: jeder Angriff meldet seine Fertigkeit für das Geräusch")
	cbe_v.queue_free()

	# --- Kraken (Boss) ---
	var kv := new_voyage(1200)
	var kp: Array = [kv.crew[0], kv.crew[1], kv.crew[2], kv.crew[3]]
	check(",".join(Foes.units_for("kraken", 1)) == "tentakel,tentakel,kraken" and ",".join(Foes.units_for("kraken", 9, 2)) == "tentakel,kraken" and Foes.units_for("kraken", 1, 4).size() == 4, "Kraken: Aufstellung aus Fangarmen und Körper, der Körper steht immer dabei")
	var kc := Combat.create(kv, "kraken", kp, Foes.units_for("kraken", 1), 1)
	kc.begin()
	var k_body: Combat.Fighter = kc.foes[kc.foes.size() - 1]
	check(k_body.kind == "kraken" and k_body.guarded and k_body.fearless, "Kraken: der Körper steht hinten und ist geschützt")
	check(not kc.targets(kc.heroes[0], "b_schuss").has(k_body) and not kc.targets(kc.heroes[0], "b_regen").has(k_body), "Kraken: der Körper ist unerreichbar, solange ein Fangarm steht")
	for t in kc.foes.duplicate():
		if t.kind == "tentakel":
			kc._hurt(t, 9999, null)
	check(kc.targets(kc.heroes[0], "b_schuss").has(k_body) and kc.state != "done", "Kraken: ohne Fangarme ist der Körper erreichbar")
	for _r1 in 4:
		kc._new_round()
	check(kc._tentacles() == 2 and kc.foes.size() == 3 and kc.foes[0].hp < float(Foes.info("tentakel")["hp"]) * Combat.FOE_HP, "Kraken: gefällte Fangarme wachsen nach (mit weniger Kraft)")
	for _r2 in 8:
		kc._new_round()
	check(kc._tentacles() <= 2 and kc.foes.size() <= 3, "Kraken: es wachsen nie mehr Fangarme nach als am Anfang")
	kc._hurt(k_body, 9999, null)
	kc._check_end()
	check(kc.result == "win" and kc.foes.is_empty(), "Kraken: fällt der Körper, ist der Kampf gewonnen")
	var kg := Combat.create(kv, "kraken", kp, Foes.units_for("kraken", 1), 1)
	kg.begin()
	var k_arm: Combat.Fighter = kg.foes[0]
	var k_man: Combat.Fighter = kg.heroes[1]
	k_man.held_by = k_arm
	k_arm.holding = k_man
	k_arm.hold_left = 2
	kg._hold_turn(k_arm)
	check(k_man.held_by == k_arm and not k_man.gone and k_arm.hold_left == 1, "Kraken: der Fangarm presst den Mann zuerst")
	kg._hurt(k_arm, 9999, null)
	check(k_man.held_by == null and k_arm.holding == null, "Kraken: fällt der Fangarm, ist der Mann frei")
	var kg2 := Combat.create(kv, "kraken", kp, Foes.units_for("kraken", 1), 1)
	kg2.begin()
	var k_arm2: Combat.Fighter = kg2.foes[0]
	var k_man2: Combat.Fighter = kg2.heroes[2]
	k_man2.held_by = k_arm2
	k_arm2.holding = k_man2
	k_arm2.hold_left = 1
	kg2._hold_turn(k_arm2)
	check(kg2.overboard.has(k_man2.man) and k_man2.gone and not kg2.heroes.has(k_man2) and not kg2.casualties.has(k_man2.man), "Kraken: hält der Griff, geht der Mann über Bord (lebt, muss gerettet werden)")
	var ks :=Combat.create(kv, "kraken", kp, Foes.units_for("kraken", 1), 1)
	ks.begin()
	var k_b2: Combat.Fighter = ks.foes[ks.foes.size() - 1]
	k_b2.charge = true
	k_b2.stun = 1
	var k_ord: Array[Combat.Fighter] = [k_b2]
	ks.order = k_ord
	ks.cursor = -1
	ks._next_actor()
	check(not k_b2.charge, "Kraken: ein Betäubter kann nicht zerquetschen")
	var kq := Combat.create(kv, "kraken", kp, Foes.units_for("kraken", 1), 1)
	kq.begin()
	var k_b3: Combat.Fighter = kq.foes[kq.foes.size() - 1]
	k_b3.crush_cd = 0
	kq.actor = k_b3
	kq.state = "foe"
	kq.act_foe()
	var k_announced := k_b3.charge
	var k_hp_before := kq.heroes[0].hp
	kq.actor = k_b3
	kq.state = "foe"
	kq.act_foe()
	var k_crushed := false
	for jl in kq.journal:
		if String(jl["text"]).contains("Zerquetschen"):
			k_crushed = true
	check(k_announced and not k_b3.charge and k_crushed and kq.heroes[0].hp < k_hp_before, "Kraken: Zerquetschen wird erst angekündigt und im nächsten Zug ausgeführt")
	var kb := Combat.create(kv, "kraken", kp, Foes.units_for("kraken", 1), 1)
	kb.begin()
	kb.heroes[0].blind = 2
	check(kb.hit_chance(kb.heroes[0], kb.foes[0], Roles.skill("b_schuss")) == kb.hit_chance(kb.heroes[1], kb.foes[0], Roles.skill("b_schuss")) - 20.0, "Kraken: die Tinte senkt die Trefferchance um 20 Punkte")
	kv.queue_free()
	var kwins := 0
	for sd in range(1210, 1230):
		var kvv := new_voyage(sd)
		kvv.auto_combat = true
		kvv.start_fight("kraken", {"source": "encounter"}, 3)
		run_until_idle(kvv)
		if kvv.phase == Voyage.Phase.COMBAT or kvv.combat != null or invariants(kvv) != "":
			kwins = -1000
		kvv.queue_free()
	check(kwins >= 0, "Kraken: der Deckkampf läuft im Spiel durch, alles bleibt konsistent")
	var kov := new_voyage(1240)
	kov.auto_combat = false
	kov.start_fight("kraken", {"source": "encounter"}, 3)
	kov.fight_begin()
	var ko_man: CrewMember = kov.combat.heroes[0].man
	kov.combat.overboard.append(ko_man)
	kov.combat.heroes[0].gone = true
	kov.combat.result = "win"
	kov.combat.state = "done"
	kov._end_fight()
	check(kov._pending.has(ko_man) and ko_man.state == CrewMember.State.OVERBOARD, "Kraken: wer über Bord gezerrt wurde, schwimmt und muss gerettet werden")
	kov.queue_free()
	var ksv := new_voyage(1250)
	ksv.auto_combat = false
	ksv._enc_pending = Encounters.Id.KRAKEN
	ksv._advance()
	ksv.decide_encounter(3)  # Entern
	check(ksv.phase == Voyage.Phase.COMBAT and ksv.fight_prep.get("formation", "") == "kraken", "Kraken: Entern in der Seeschlacht beginnt den Deckkampf gegen den Kraken")
	ksv.queue_free()

	# --- Wucht und Nerven im Kampf ---
	var fx_all := true
	for sid in Roles.SKILLS:
		if not FightFx.SKILL_FX.has(sid):
			fx_all = false
			print("   ohne Kampfwirkung: ", sid)
	check(fx_all and Voyage.COMBAT_PACE >= 0.8, "Wucht: jede Fertigkeit hat eine Wirkung, das Kampftempo lässt sie ausspielen")
	var fxo := FightFx.new()
	fxo.cue("shake", {"amp": 3.0, "d": 0.3}, 0.1)
	fxo.add("slash", {"x": 100.0, "y": 90.0}, 0.2, 0.3)
	fxo.show_banner("Hieb", "Knut", 0)
	var fx_a := fxo.offset() == Vector2.ZERO
	fxo.tick(0.05)
	fx_a = fx_a and fxo.offset() == Vector2.ZERO
	fxo.tick(0.1)
	var fx_b := fxo._shake_t > 0.0
	fxo.freeze = 0.1
	var fx_c := not fxo.tick(0.05) and not fxo.tick(0.06) and fxo.tick(0.1)
	for k in 20:
		fxo.tick(0.1)
	check(fx_a and fx_b and fx_c and fxo.items.is_empty() and fxo.banner.is_empty(), "Wucht: Wirkungen warten auf den Treffer, Wackeln und Einfrieren laufen ab")
	var sn_v := new_voyage(1300)
	var sn_p: Array = [sn_v.crew[0], sn_v.crew[1], sn_v.crew[2], sn_v.crew[3]]
	sn_p[0].role = Roles.Id.SCHILD
	sn_p[1].role = Roles.Id.AXT
	sn_p[2].role = Roles.Id.BOGEN
	sn_p[3].role = Roles.Id.SKALDE
	for m in sn_p:
		m.afflicted = false
		m.affliction = CrewMember.Affliction.NONE
		m.stress = 0.0
		m.kraft = 100.0
	var sn_h := Combat.create(sn_v, "draugr", sn_p, Foes.units_for("draugr", 1), 1)
	sn_h.begin()
	sn_h.snap_force = "heroic"
	sn_h.snap_variant = 0
	var sn_h_man: Combat.Fighter = sn_h.heroes[1]
	sn_h_man.man.stress = 97.0
	var sn_h_order := sn_h.order.size()
	sn_h._stress(sn_h_man, 6.0)
	var sn_h_types := {}
	for ev in sn_h.events:
		sn_h_types[String(ev["type"])] = true
	check(sn_h_man.snapped and sn_h_man.man.stress == 40.0 and sn_h_man.buff >= 3 and sn_h.order.size() == sn_h_order + 1 and sn_h.snaps.size() == 1 and String(sn_h.snaps[0]["kind"]) == "heroic" and sn_h_types.has("heroic"), "Nerven: bei 100 Verzweiflung wächst ein Mann über sich hinaus (Kampfrausch: Zug extra, Schaden)")
	sn_h._stress(sn_h_man, 70.0)
	check(sn_h.snaps.size() == 1, "Nerven: gekippt wird nur einmal je Kampf und Mann")
	var sn_b := Combat.create(sn_v, "draugr", sn_p, Foes.units_for("draugr", 1), 1)
	sn_b.begin()
	sn_b.snap_force = "break"
	var sn_b_man: Combat.Fighter = sn_b.heroes[2]
	sn_b_man.man.stress = 99.0
	sn_b._stress(sn_b_man, 30.0)
	var sn_b_kind := String(sn_b.snaps[0]["kind"]) if sn_b.snaps.size() > 0 else ""
	check(sn_b_man.man.afflicted and sn_b_man.man.stress >= 60.0 and sn_b_man.man.stress < 80.0 and (sn_b_kind == "verzagt" or sn_b_kind == "berserk"), "Nerven: sonst bricht er zusammen (verzagt oder Berserker) und bleibt es")
	sn_b_man.man.afflicted = false
	var sn_r := Combat.create(sn_v, "draugr", sn_p, Foes.units_for("draugr", 1), 1)
	sn_r.begin()
	sn_r.snap_force = "heroic"
	sn_r.snap_variant = 1
	var sn_r_man: Combat.Fighter = sn_r.heroes[1]
	sn_r_man.man.afflicted = true
	sn_r_man.man.affliction = CrewMember.Affliction.VERZAGT
	sn_r_man.hp = 20.0
	sn_r_man.man.stress = 99.0
	sn_r._stress(sn_r_man, 3.0)
	check(not sn_r_man.man.afflicted and sn_r_man.hp == 50.0 and sn_r_man.guard >= 2, "Nerven: Heldenmut heilt eine Marotte (Eiserner Wille: Kraft +30, Schutz)")
	var sn_p2 := Combat.create(sn_v, "draugr", sn_p, Foes.units_for("draugr", 1), 1)
	sn_p2.begin()
	sn_p2.snap_force = "break"
	var sn_p_man: Combat.Fighter = sn_p2.heroes[0]
	sn_p_man.man.afflicted = true
	sn_p_man.man.affliction = CrewMember.Affliction.VERZAGT
	sn_p_man.man.stress = 99.0
	sn_p2._stress(sn_p_man, 4.0)
	var sn_p_ord: Array[Combat.Fighter] = [sn_p_man]
	sn_p2.order = sn_p_ord
	sn_p2.cursor = -1
	var sn_p_before := sn_p_man.panic
	sn_p2._next_actor()
	check(sn_p_before == 1 and sn_p_man.panic == 0 and String(sn_p2.snaps[0]["kind"]) == "panik", "Nerven: wer schon gebrochen ist, erstarrt vor Schreck und setzt einen Zug aus")
	var sn_z := Combat.create(sn_v, "draugr", sn_p, Foes.units_for("draugr", 1), 1)
	sn_z.begin()
	var sn_z_man: Combat.Fighter = sn_z.heroes[1]
	sn_z_man.man.afflicted = true
	sn_z_man.man.affliction = CrewMember.Affliction.BERSERK
	sn_z.foes[0].hp = 9999.0
	var sn_z_hit := false
	for k in 40:
		var before_hp := 0.0
		for h in sn_z.heroes:
			before_hp += h.hp
		sn_z._rage(sn_z_man)
		var after_hp := 0.0
		for h in sn_z.heroes:
			after_hp += h.hp
		if after_hp < before_hp:
			sn_z_hit = true
			break
	check(sn_z_hit, "Nerven: ein Berserker schlägt manchmal einen Kameraden")
	var sn_s := Combat.create(sn_v, "draugr", sn_p, Foes.units_for("draugr", 1), 1)
	sn_s.begin()
	var sn_s_man: Combat.Fighter = sn_s.heroes[0]
	sn_s_man.man.stress = 10.0
	sn_s._hurt(sn_s_man, 150, null)
	check(sn_s_man.door and sn_s_man.man.stress > 15.0, "Nerven: an die Schwelle zu kommen kostet Mut")
	sn_v.queue_free()


	# --- Fertigkeiten, Musketier, Gegnerrollen ---
	var t3_pools_ok := true
	for rid in Roles.ROLES.size():
		var t3_pool := Roles.pool(rid)
		var t3_def := Roles.default_loadout(rid)
		if t3_pool.size() != 6 or t3_def.size() != 4:
			t3_pools_ok = false
		for s in t3_def:
			if not t3_pool.has(s):
				t3_pools_ok = false
		for s in t3_pool:
			if not Roles.SKILLS.has(s) or String(Roles.skill(s)["icon"]) == "" or SkillIcons.index_of(Roles.icon_of(s)) < 0:
				t3_pools_ok = false
				print("   Fertigkeit ohne Symbol: ", s)
	check(t3_pools_ok and Roles.Id.MUSKET == 4 and Roles.ROLES.size() == 5, "Fertigkeiten: jede Rolle hat sechs, vier davon als Standardwahl, alle mit Symbol (fünf Rollen)")
	var t3_icons := Image.load_from_file(SkillIcons.PATH)
	check(t3_icons != null and t3_icons.get_width() == SkillIcons.SIZE * SkillIcons.ORDER.size() and t3_icons.get_height() == SkillIcons.SIZE, "Symbole: assets/skill_icons.png hat %d Felder" % SkillIcons.ORDER.size())
	var t3_icon_all := true
	for sid in Roles.SKILLS:
		if SkillIcons.index_of(Roles.icon_of(sid)) < 0:
			t3_icon_all = false
	check(t3_icon_all and not Roles.SKILLS["k_heil"].has("uses") and not Roles.SKILLS["k_krieg"].has("uses") and not Roles.SKILLS["k_trost"].has("uses"), "Skalde: seine Lieder haben keine Einsatzgrenze mehr, jede Fertigkeit hat ein Symbol")
	var t3_lo := Roles.valid_loadout(Roles.Id.AXT, ["a_hieb", "a_hieb", "gibt_es_nicht", "a_wut", "a_spalt", "a_wirbel", "a_spalter"])
	check(t3_lo == ["a_hieb", "a_wut", "a_spalt", "a_wirbel"] and Roles.valid_loadout(Roles.Id.AXT, []) == Roles.default_loadout(Roles.Id.AXT), "Wahl: Doppelte und fremde Fertigkeiten fliegen raus, höchstens vier, leer gibt die Standardwahl")
	var t3_v := new_voyage(1400)
	t3_v.crew[0].role = Roles.Id.MUSKET
	t3_v.crew[0].loadout = ["m_schuss", "m_kopf", "m_nachladen", "m_pistole"]
	var t3_json := JSON.parse_string(JSON.stringify(t3_v._man_dict(t3_v.crew[0]))) as Dictionary
	var t3_man := t3_v._man_from(t3_json)
	check(t3_man.role == Roles.Id.MUSKET and t3_man.skills() == ["m_schuss", "m_kopf", "m_nachladen", "m_pistole"], "Wahl: die gewählten Fertigkeiten überstehen Speichern und Laden")
	var t3_party: Array = [t3_v.crew[0], t3_v.crew[1], t3_v.crew[2], t3_v.crew[3]]
	for m in t3_party:
		m.afflicted = false
		m.stress = 0.0
		m.kraft = 100.0
	t3_v.crew[1].role = Roles.Id.SCHILD
	t3_v.crew[2].role = Roles.Id.AXT
	t3_v.crew[3].role = Roles.Id.SKALDE
	t3_v.crew[1].loadout = []
	t3_v.crew[2].loadout = []
	t3_v.crew[3].loadout = []
	var t3_c := Combat.create(t3_v, "draugr", t3_party, ["rost", "rost", "bogner", "totenwart"] as Array[String], 1)
	t3_c.begin()
	var t3_mus: Combat.Fighter = t3_c.heroes[0]
	# Muskete: Schuss, danach leer, Nachladen füllt wieder
	t3_c.heroes.erase(t3_mus)
	t3_c.heroes.insert(1, t3_mus)
	t3_c._renumber()
	var t3_before := t3_c.can_use(t3_mus, "m_schuss")
	t3_c.foes[0].hp = 9999.0
	t3_c._execute(t3_mus, "m_schuss", t3_c.foes[0])
	var t3_empty := not t3_mus.loaded and not t3_c.can_use(t3_mus, "m_schuss") and not t3_c.can_use(t3_mus, "m_kopf") and t3_c.can_use(t3_mus, "m_nachladen")
	t3_c._execute(t3_mus, "m_nachladen", null)
	check(t3_before and t3_empty and t3_mus.loaded and not t3_c.can_use(t3_mus, "m_nachladen"), "Muskete: ein Schuss leert sie, Nachladen lädt sie, die Pistole braucht nichts")
	# Heilen: nur Verwundete, der Heiler heilt
	var t3_priest := t3_c._make_foe("priester", 1.0)
	t3_c.foes.append(t3_priest)
	t3_c._renumber()
	var t3_none := t3_c.targets(t3_priest, "f_heilen").is_empty()
	t3_c.foes[0].hp = 10.0
	t3_c.foes[0].hp_max = 40.0
	var t3_tl := t3_c.targets(t3_priest, "f_heilen")
	t3_c._execute(t3_priest, "f_heilen", t3_c.foes[0])
	check(t3_none and t3_tl.has(t3_c.foes[0]) and t3_c.foes[0].hp > 10.0, "Gegnerrolle Heiler: heilt nur Verwundete")
	# Beschützer: Deckung auf einen Verbündeten
	var t3_g := t3_c._make_foe("waechter", 1.0)
	t3_c.foes.append(t3_g)
	t3_c._renumber()
	var t3_gt := t3_c.targets(t3_g, "f_deckung")
	t3_c._execute(t3_g, "f_deckung", t3_gt[0])
	check(not t3_gt.has(t3_g) and t3_gt[0].guard >= 2, "Gegnerrolle Beschützer: gibt einem Verbündeten Schutz, nicht sich selbst")
	# Beschwörer: ruft ein Skelett an die Front, nie mehr als vier
	var t3_c2 := Combat.create(t3_v, "draugr", t3_party, ["beschwoerer", "rost"] as Array[String], 1)
	t3_c2.begin()
	var t3_necro: Combat.Fighter = t3_c2.foes[0]
	t3_c2._execute(t3_necro, "f_beschwoeren", null)
	var t3_summoned := t3_c2.foes.size() == 3 and t3_c2.foes[0].kind == "knochen"
	t3_c2._execute(t3_necro, "f_beschwoeren", null)
	check(t3_summoned and t3_c2.foes.size() <= 4 and not t3_c2.can_use(t3_necro, "f_beschwoeren"), "Gegnerrolle Beschwörer: ruft Skelette an die Front, höchstens zweimal und nie über vier Gegner")
	# Rammer: stößt einen Mann nach hinten
	var t3_c3 := Combat.create(t3_v, "raeuber", t3_party, ["brecher"] as Array[String], 1)
	t3_c3.begin()
	var t3_front: Combat.Fighter = t3_c3.heroes[0]
	var t3_name := t3_front.name
	var t3_pushed := false
	for k in 40:
		t3_c3._strike(t3_c3.foes[0], Roles.skill("f_ramm"), t3_c3.heroes[0])
		if t3_c3.heroes[0].name != t3_name:
			t3_pushed = true
			break
	check(t3_pushed, "Gegnerrolle Rammer: der Rammstoß schiebt einen Mann eine Reihe zurück")
	# Herausforderung: die Gegner zielen fast nur auf ihn
	var t3_c4 := Combat.create(t3_v, "draugr", t3_party, ["rost"] as Array[String], 1)
	t3_c4.begin()
	var t3_tank: Combat.Fighter = t3_c4.heroes[1]
	t3_c4._execute(t3_tank, "s_ruf", null)
	var t3_hits := 0
	for k in 200:
		if t3_c4._pick_hero_target(t3_c4.foes[0], "f_hieb") == t3_tank:
			t3_hits += 1
	check(t3_tank.taunt > 0 and t3_hits > 80, "Herausforderung: die Gegner zielen vor allem auf den Rufer (%d von 200)" % t3_hits)
	# Weckruf löst Betäubung und Blutung
	var t3_c5 := Combat.create(t3_v, "draugr", t3_party, ["rost"] as Array[String], 1)
	t3_c5.begin()
	t3_c5.heroes[0].stun = 1
	t3_c5.heroes[1].bleed_turns = 3
	t3_c5.heroes[2].blind = 2
	t3_c5._support(t3_c5.heroes[3], t3_c5.heroes[3], {"fx": {}, "tgt": "allies", "name": "x"})
	for h in t3_c5.heroes:
		t3_c5._support(h, h, Roles.skill("k_weck"))
	check(t3_c5.heroes[0].stun == 0 and t3_c5.heroes[1].bleed_turns == 0 and t3_c5.heroes[2].blind == 0, "Weckruf: löst Betäubung, Blutung und Tinte bei allen")
	# Aufstellungen wechseln
	var t3_seen := {}
	for k in 60:
		t3_seen[",".join(Foes.units_for("draugr", 3))] = true
	var t3_roles_in := false
	for k in 60:
		for u in Foes.units_for("draugr", 3):
			if Foes.role_hint(String(u)) in ["Heiler", "Beschützer", "Beschwörer"]:
				t3_roles_in = true
	check(t3_seen.size() >= 2 and t3_roles_in, "Gegner: jede Aufstellung gibt es in Spielarten, mit Heilern, Beschützern und Beschwörern")
	# Brüder rächen sich
	var t3_a: CrewMember = t3_v.crew[1]
	var t3_b: CrewMember = t3_v.crew[2]
	t3_v.bonds.append({"a": t3_a.id, "b": t3_b.id, "type": Voyage.Bond.BROTHER})
	var t3_c6 := Combat.create(t3_v, "draugr", t3_party, ["rost"] as Array[String], 1)
	t3_c6.begin()
	var t3_fa := t3_c6._fighter_of(t3_a)
	var t3_fb := t3_c6._fighter_of(t3_b)
	t3_c6._kill_hero(t3_fa)
	check(t3_fb != null and t3_fb.buff >= 3, "Bindung: wer seinen Bruder fallen sieht, kämpft zornig weiter")
	# Schlussansage verzögert das Ende des Kampfes nur im echten Spiel
	var t3_o := new_voyage(1410)
	t3_o.auto_combat = false
	t3_o.combat_outro = 0.5
	t3_o.start_fight("draugr", {"source": "encounter"}, 2)
	t3_o.fight_begin()
	t3_o.combat.result = "win"
	t3_o.combat.state = "done"
	t3_o._tick_combat(0.2)
	var t3_wait := t3_o.combat != null
	t3_o._tick_combat(0.2)
	var t3_wait2 := t3_o.combat != null
	t3_o._tick_combat(0.2)
	check(t3_wait and t3_wait2 and t3_o.combat == null, "Schlussansage: der Kampf endet erst nach der Ansage, ohne Ansage sofort")
	t3_o.queue_free()
	t3_v.queue_free()


	# --- Gegenstände mit Seltenheit, Schmiede und Kampfschule ---
	check(Items.valid("teer") and Items.valid("teer@2") and not Items.valid("teer@5") and not Items.valid("xyz@1") and not Items.valid("teer@x"), "Seltenheit: Schlüssel wie teer@2 sind gültig, falsche nicht")
	check(Items.rarity_of("teer") == 0 and Items.rarity_of("teer@3") == 3 and Items.base_id("teer@3") == "teer" and Items.make("teer", 0) == "teer" and Items.make("teer", 2) == "teer@2", "Seltenheit: Schlüssel lesen und bauen")
	var t4_plain := float(Items.mods_of("beschlag")["hull_max"])
	var t4_rare := float(Items.mods_of("beschlag@1")["hull_max"])
	var t4_leg := float(Items.mods_of("beschlag@3")["hull_max"])
	check(t4_plain == 20.0 and t4_rare > t4_plain and t4_leg > t4_rare, "Seltenheit: je seltener, desto stärker (Rumpf %d, %d, %d)" % [roundi(t4_plain), roundi(t4_rare), roundi(t4_leg)])
	check(float(Items.mods_of("kanone@3")["cannons"]) == 1.0 and float(Items.mods_of("prunk@3")["exposure"]) == 1.1, "Seltenheit: Kanonen bleiben eine, Nachteile wachsen nicht mit")
	check(not Items.mods_of("teer").has("hazard") and not Items.mods_of("teer@1").has("hazard") and Items.mods_of("teer@2").has("hazard") and Items.mods_of("teer@3").has("hazard"), "Seltenheit: Episch und Legendär bringen einen Zusatzwert mit")
	check(Items.name_of("teer@3") == "Teer der Nornen" and Items.name_of("teer@1") == "Teerung" and Items.price_at("teer@3", 1) > Items.price_at("teer@1", 1) and Items.price_at("teer@1", 1) > Items.price_at("teer", 1), "Seltenheit: Legendäres hat einen eigenen Namen und kostet mehr")
	var t4_names_ok := true
	for id in Items.ids():
		for t4_r in 4:
			var t4_key := Items.make(String(id), t4_r)
			if not Items.valid(t4_key) or Items.name_of(t4_key) == "" or Items.mods_of(t4_key).is_empty() or Items.lines_of(t4_key).is_empty():
				t4_names_ok = false
	check(t4_names_ok, "Seltenheit: jeder Gegenstand gibt es in allen vier Seltenheiten, mit Namen und Werten")
	var t4_epic_early := 0
	var t4_leg_early := 0
	for k in 600:
		var r1 := Items.roll_rarity(1)
		if r1 >= 2:
			t4_epic_early += 1
		var r2 := Items.roll_rarity(2)
		if r2 >= 3:
			t4_leg_early += 1
	var t4_late_epic := 0
	for k in 600:
		if Items.roll_rarity(7) >= 2:
			t4_late_epic += 1
	var t4_min_ok := true
	for k in 200:
		if Items.roll_rarity(4, 1.5, 2) < 2:
			t4_min_ok = false
	check(t4_epic_early == 0 and t4_leg_early == 0 and t4_late_epic > 30 and t4_min_ok, "Seltenheit: früh nichts Episches, später öfter, der Mindestwert gilt (%d von 600 in Etappe 7)" % t4_late_epic)
	var t4_v := new_voyage(1500)
	t4_v.equip("planken")
	var t4_h0 := t4_v.hull_max()
	t4_v.equip("planken@2")
	check(t4_v.hull_max() > t4_h0 and t4_v.items.size() == 1, "Seltenheit: ein seltener Gegenstand wirkt stärker auf dem Schiff")
	t4_v.items.clear()
	t4_v._mods = {}
	t4_v._find_item(2, 1.5)
	var t4_got := false
	for s in t4_v.items:
		if Items.rarity_of(String(t4_v.items[s])) >= 2:
			t4_got = true
	check(t4_got, "Fund: der Mindestwert Episch wird eingehalten und das Stück gleich eingebaut")
	for slot_i in Items.SLOT_NAMES.size():
		t4_v.items[slot_i] = "teer"
	t4_v.stage = 4
	var t4_loot0 := t4_v.loot
	t4_v._find_item(3, 3.0)
	var t4_better := false
	for s in t4_v.items:
		if Items.rarity_of(String(t4_v.items[s])) >= 3:
			t4_better = true
	check(t4_better and t4_v.loot > t4_loot0, "Fund: ein besseres Stück ersetzt das alte, das alte wird verkauft")
	t4_v.queue_free()

	var t4_f := new_voyage(1510)
	t4_f.loot = 2000.0
	var t4_m: CrewMember = t4_f.crew[0]
	t4_m.role = Roles.Id.AXT
	t4_m.weapon_lvl = 0
	t4_m.armor_lvl = 0
	t4_m.skill_lvl = {}
	check(t4_f.forge_price("weapon", t4_m) == 70 and not t4_f.forge_buy("weapon", t4_m), "Schmiede: ohne offene Werft wird nichts verkauft")
	t4_f.shop_open = true
	check(t4_f.forge_buy("weapon", t4_m) and t4_m.weapon_lvl == 1 and is_equal_approx(t4_f.loot, 1930.0), "Schmiede: Waffe verbessern kostet Beute")
	for k in 5:
		t4_f.forge_buy("weapon", t4_m)
		t4_f.forge_buy("armor", t4_m)
	check(t4_m.weapon_lvl == Voyage.WEAPON_MAX and t4_m.armor_lvl == Voyage.ARMOR_MAX and t4_f.forge_price("weapon", t4_m) == -1, "Schmiede: bei Stufe 4 ist Schluss")
	check(t4_f.forge_buy("skill", t4_m, "a_hieb") and t4_f.forge_buy("skill", t4_m, "a_hieb") and t4_f.forge_buy("skill", t4_m, "a_hieb") and not t4_f.forge_buy("skill", t4_m, "a_hieb") and int(t4_m.skill_lvl["a_hieb"]) == 3, "Kampfschule: Fertigkeiten wachsen bis Stufe 3")
	check(Roles.max_level("m_nachladen") == 0 and t4_f.forge_price("skill", t4_m, "m_nachladen") == -1 and Roles.max_level("s_wall") == 1 and Roles.max_level("k_heil") == 3, "Kampfschule: Nachladen lässt sich nicht verbessern, Hilfen nur um eine Stufe")
	var t4_wall := Roles.effective("s_wall", 1)
	var t4_heal := Roles.effective("k_heil", 2)
	var t4_cut := Roles.effective("a_hieb", 3)
	check(int(t4_wall["fx"]["guard"]) == 3 and int(t4_heal["fx"]["heal"]) > 18 and float(t4_cut["dmg"]) > 1.0 and int(t4_cut["acc"]) > 90 and int(Roles.skill("s_wall")["fx"]["guard"]) == 2, "Kampfschule: die Stufen verbessern Schaden, Treffer, Heilung und Dauer, ohne das Original zu ändern")
	var t4_json := JSON.parse_string(JSON.stringify(t4_f._man_dict(t4_m))) as Dictionary
	var t4_back := t4_f._man_from(t4_json)
	check(t4_back.weapon_lvl == 4 and t4_back.armor_lvl == 4 and int(t4_back.skill_lvl.get("a_hieb", 0)) == 3, "Schmiede: die Stufen überstehen Speichern und Laden")
	var t4_party: Array = [t4_f.crew[0], t4_f.crew[1], t4_f.crew[2], t4_f.crew[3]]
	for pm in t4_party:
		pm.afflicted = false
		pm.stress = 0.0
		pm.kraft = 100.0
	var t4_plain_man: CrewMember = t4_f.crew[1]
	t4_plain_man.role = Roles.Id.AXT
	t4_plain_man.weapon_lvl = 0
	t4_plain_man.armor_lvl = 0
	t4_plain_man.skill_lvl = {}
	var t4_c := Combat.create(t4_f, "draugr", t4_party, ["rost"] as Array[String], 1)
	var t4_strong := t4_c._fighter_of(t4_m)
	var t4_weak := t4_c._fighter_of(t4_plain_man)
	var t4_dmg_s := t4_c.damage_range(t4_strong, t4_c.foes[0], t4_c.eff_skill(t4_strong, "a_hieb"))
	var t4_dmg_w := t4_c.damage_range(t4_weak, t4_c.foes[0], t4_c.eff_skill(t4_weak, "a_hieb"))
	check(t4_dmg_s[1] > t4_dmg_w[1] * 1.4 and t4_strong.prot > t4_weak.prot + 0.1, "Schmiede im Kampf: bessere Waffe und Fertigkeit schlagen härter, die Rüstung schützt (%d gegen %d)" % [roundi(t4_dmg_s[1]), roundi(t4_dmg_w[1])])
	t4_f.queue_free()


	# --- Ausrüstung der Männer ---
	check(Gear.valid("schwert") and Gear.valid("rune@3") and not Gear.valid("rune@4") and not Gear.valid("teer") and Gear.slot_of("schwert") == Gear.Slot.WAFFE and Gear.slot_of("kette") == Gear.Slot.RUESTUNG and Gear.slot_of("auge") == Gear.Slot.AMULETT, "Ausrüstung: Schlüssel und Plätze (Waffe, Rüstung, Amulett)")
	var t5_all_ok := true
	for id in Gear.ids():
		for t5_r in 4:
			var t5_key := Gear.make(String(id), t5_r)
			if not Gear.valid(t5_key) or Gear.name_of(t5_key) == "" or Gear.mods_of(t5_key).is_empty() or Gear.lines_of(t5_key).is_empty():
				t5_all_ok = false
	var t5_per_slot := [0, 0, 0]
	for id in Gear.ids():
		t5_per_slot[Gear.slot_of(String(id))] += 1
	check(t5_all_ok and t5_per_slot == [6, 6, 6], "Ausrüstung: 18 Stücke, je sechs für Waffe, Rüstung und Amulett, alle in vier Seltenheiten")
	check(float(Gear.mods_of("schwert@1")["dmg"]) > float(Gear.mods_of("schwert")["dmg"]) and float(Gear.mods_of("schwert@3")["dmg"]) > float(Gear.mods_of("schwert@1")["dmg"]), "Ausrüstung: je seltener, desto stärker")
	check(float(Gear.mods_of("hammer@3")["acc"]) == -3.0 and float(Gear.mods_of("kette@3")["speed"]) == -1.0 and float(Gear.mods_of("rune@3")["stress"]) < float(Gear.mods_of("rune")["stress"]), "Ausrüstung: Nachteile wachsen nicht mit, gute Werte schon (Verzweiflung sinkt weiter)")
	check(not Gear.mods_of("schwert@1").has("crit") and Gear.mods_of("schwert@2").has("crit") and Gear.name_of("schwert@3") == "Tyrfing" and Gear.price_at("schwert@3", 1) > Gear.price_at("schwert@1", 1), "Ausrüstung: Episch bringt einen Zusatzwert, Legendär einen eigenen Namen und kostet mehr")
	var t5_sum := Gear.sum_mods({0: "schwert", 1: "leder", 2: "rune"})
	check(is_equal_approx(float(t5_sum["dmg"]), 0.08) and is_equal_approx(float(t5_sum["prot"]), 0.04) and float(t5_sum["dodge"]) == 3.0 and is_equal_approx(float(t5_sum["stress"]), 0.88) and float(Gear.sum_mods({})["stress"]) == 1.0, "Ausrüstung: die Werte der drei Stücke zählen zusammen")
	var t5_v := new_voyage(1600)
	var t5_a: CrewMember = t5_v.crew[0]
	var t5_b: CrewMember = t5_v.crew[1]
	t5_a.gear = {}
	t5_b.gear = {}
	t5_v.stash = []
	t5_v.shop_open = true
	t5_v.loot = 1000.0
	t5_v.gear_shop = ["axt@1", "leder", "rune@2"]
	var t5_f0 := t5_a.stress_factor()
	t5_a.gear[2] = "rune@3"
	check(t5_a.stress_factor() < t5_f0 * 0.85, "Ausrüstung: ein Amulett senkt, wie schnell die Verzweiflung wächst")
	t5_a.gear = {}
	var t5_loot := t5_v.loot
	var t5_price := Gear.price_at("axt@1", t5_v.stage)
	check(t5_v.buy_gear(0) and t5_v.stash == ["axt@1"] and is_equal_approx(t5_v.loot, t5_loot - float(t5_price)) and t5_v.gear_shop.size() == 2, "Rüstkammer: ein Stück kaufen legt es in den Vorrat")
	t5_v.shop_open = false
	check(not t5_v.buy_gear(0) and not t5_v.sell_gear(0), "Rüstkammer: nur in der offenen Werft")
	t5_v.shop_open = true
	check(t5_v.equip_gear(t5_a, 0) and t5_a.gear.get(0, "") == "axt@1" and t5_v.stash.is_empty(), "Ausrüstung: anlegen nimmt das Stück aus dem Vorrat")
	t5_v.stash = ["schwert@2"]
	check(t5_v.equip_gear(t5_a, 0) and t5_a.gear[0] == "schwert@2" and t5_v.stash == ["axt@1"], "Ausrüstung: ein Tausch schickt das alte Stück in den Vorrat")
	check(t5_v.unequip_gear(t5_a, 0) and t5_a.gear.is_empty() and t5_v.stash.size() == 2, "Ausrüstung: ablegen legt es in den Vorrat zurück")
	var t5_loot2 := t5_v.loot
	var t5_stash_size := t5_v.stash.size()
	check(t5_v.sell_gear(0) and t5_v.loot > t5_loot2 and t5_v.stash.size() == t5_stash_size - 1, "Rüstkammer: Verkaufen bringt die Hälfte des Preises")
	t5_v.stash = ["axt@2", "schwert", "leder@1", "rune", "kette", "horn@3"]
	for m in t5_v.forge_men():
		m.gear = {}
	var t5_changed := t5_v.auto_equip()
	var t5_filled := 0
	for m in t5_v.forge_men():
		t5_filled += m.gear.size()
	check(t5_changed >= 4 and t5_filled >= 4 and t5_v.stash.size() <= 2, "Ausrüstung: Beste anlegen füllt leere Plätze (%d Stücke angelegt)" % t5_filled)
	t5_v.stash = ["axt@3"]
	t5_v.auto_equip()
	var t5_best := 0
	for m in t5_v.forge_men():
		if m.gear.has(0):
			t5_best = maxi(t5_best, Items.rarity_of(String(m.gear[0])))
	check(t5_best == 3, "Ausrüstung: ein besseres Stück ersetzt ein schlechteres")
	t5_v.stash = []
	t5_v._find_gear(2, 1.5)
	check(t5_v.stash.size() == 1 and Items.rarity_of(String(t5_v.stash[0])) >= 2, "Fund: Ausrüstung mit Mindestseltenheit landet im Vorrat")
	t5_v.stash = []
	for k in Gear.STASH_MAX:
		t5_v.stash.append("schwert")
	var t5_loot3 := t5_v.loot
	t5_v._find_gear(0, 1.0)
	check(t5_v.stash.size() == Gear.STASH_MAX and t5_v.loot > t5_loot3, "Fund: ist der Vorrat voll, wird der Fund verkauft")
	var t5_dead: CrewMember = t5_v.crew[3]
	t5_dead.gear = {0: "speer@1", 2: "zahn"}
	t5_v.stash = []
	t5_v._kill(t5_dead, true)
	check(t5_dead.gear.is_empty() and t5_v.stash.size() == 2, "Ausrüstung: fällt ein Mann, kehrt sie in den Vorrat zurück")
	t5_v.stash = ["leder@1", "rune@2"]
	t5_a.gear = {0: "schwert@3"}
	t5_a.weapon_lvl = 1
	var t5_dict := JSON.parse_string(JSON.stringify(t5_v._man_dict(t5_a))) as Dictionary
	var t5_back := t5_v._man_from(t5_dict)
	check(t5_back.gear.get(0, "") == "schwert@3" and t5_back.weapon_lvl == 1, "Ausrüstung: überlebt Speichern und Laden")
	var t5_p: Array = [t5_v.crew[0], t5_v.crew[1], t5_v.crew[2], t5_v.crew[4]]
	for pm in t5_p:
		pm.afflicted = false
		pm.stress = 0.0
		pm.kraft = 100.0
		pm.role = Roles.Id.AXT
		pm.weapon_lvl = 0
		pm.armor_lvl = 0
		pm.skill_lvl = {}
		pm.gear = {}
	t5_p[1].gear = {0: "schwert@3", 1: "kette@3", 2: "zahn@3"}
	var t5_c := Combat.create(t5_v, "draugr", t5_p, ["rost"] as Array[String], 1)
	var t5_plain := t5_c._fighter_of(t5_p[0])
	var t5_geared := t5_c._fighter_of(t5_p[1])
	check(t5_geared.dmg_hi > t5_plain.dmg_hi * 1.1 and t5_geared.prot > t5_plain.prot + 0.1 and t5_geared.crit_bonus > 0.0 and t5_geared.acc_bonus > 0.0, "Ausrüstung im Kampf: mehr Schaden, Schutz, Krit und Treffer")
	t5_geared.hp = 50.0
	t5_geared.regen = 5.0
	t5_c.order = [t5_geared] as Array[Combat.Fighter]
	t5_c._end_round()
	check(is_equal_approx(t5_geared.hp, 55.0), "Ausrüstung im Kampf: Regeneration heilt je Runde")
	t5_v.queue_free()

	# --- Wrack ---
	var wr_items := 0
	for sd in range(40):
		var wk := new_voyage(1600 + sd)
		wk._enc_pending = Encounters.Id.WRACK
		wk._advance()
		wk.decide_encounter(0)
		run_until_idle(wk)
		if wk.items.size() > 0:
			wr_items += 1
		if invariants(wk) != "":
			wr_items = -1000
	check(wr_items > 3 and wr_items < 40, "Wrack: Durchsuchen findet manchmal einen Gegenstand (%d von 40)" % wr_items)
	var wf := new_voyage(152)
	for slot_i in Items.SLOT_NAMES.size():
		wf.items[slot_i] = "teer"
	wf._mods = {}
	var wf_loot := wf.loot
	wf._find_item()
	check(wf.loot > wf_loot, "Wrack: ist der Platz belegt, wird der Fund verkauft")

	# --- Etappen-Themen ---
	var th_ok := true
	var th := new_voyage(153)
	for t_id in Voyage.THEMES.size():
		th.theme = t_id
		th.stage = 1 + t_id
		th._make_map()
		if th.map.size() != Voyage.MILES + 1 or int(th.node_at(Voyage.MILES, 0)["enc"]) != Encounters.Id.HAFEN:
			th_ok = false
	check(th_ok, "jedes Etappen-Thema ergibt eine gültige Karte mit Hafen am Ende")
	var fog_haz := 0
	var plain_haz := 0
	for k in range(30):
		th.stage = 3
		th.theme = 1
		th._make_map()
		for c5 in range(1, Voyage.MILES):
			for nd in th.map[c5]:
				fog_haz += 1 if int(nd["hazard"]) == Sea.Hazard.NEBEL else 0
		th.theme = 0
		th._make_map()
		for c5 in range(1, Voyage.MILES):
			for nd in th.map[c5]:
				plain_haz += 1 if int(nd["hazard"]) == Sea.Hazard.NEBEL else 0
	check(fog_haz > plain_haz * 1.5, "Nebelmeer hat deutlich mehr Nebel (%d gegen %d)" % [fog_haz, plain_haz])
	th.theme = 1
	check(th.visible_cols() == th.mile + 2, "im Nebelmeer sieht man nur zwei Meilen voraus")
	var th2 := new_voyage(154)
	th2.mile = Voyage.MILES
	th2.max_stage = 0
	th2._enc_pending = Encounters.Id.HAFEN
	th2._advance()
	th2.decide_encounter(6)
	run_until_idle(th2)
	check(th2.stage == 2 and th2.theme >= 1, "die zweite Etappe bekommt ein Thema")

	# --- Gefährten ---
	var cmr := new_voyage(155)
	cmr.bonds = []
	var cmr_r := cmr.crew[0]
	var cmr_s := cmr.crew[1]
	cmr._throw_overboard(cmr_s)
	cmr._advance()
	cmr.rescuer = cmr_r
	cmr._roll_ok = true
	cmr.decide_rescue(true)
	cmr._roll_ok = true
	while cmr.phase == Voyage.Phase.RESOLVE:
		cmr._process(0.5)
	var comrades := 0
	for bd in cmr.bonds:
		if int(bd["type"]) == Voyage.Bond.COMRADE:
			comrades += 1
	check(comrades <= 1 and (cmr_s.state == CrewMember.State.ABOARD) == (comrades == 1), "Rettung ohne Bindung schafft Gefährten (Rettung %s, Gefährten %d)" % [str(cmr_s.state == CrewMember.State.ABOARD), comrades])
	var cmr2 := new_voyage(156)
	cmr2.bonds = []
	cmr2._form_bond(cmr2.crew[0], cmr2.crew[1])
	check(cmr2.bonds.size() == 1 and int(cmr2.bonds[0]["type"]) == Voyage.Bond.COMRADE, "Gefährtenband entsteht")
	cmr2._form_bond(cmr2.crew[0], cmr2.crew[2])
	check(cmr2.bonds.size() == 1, "wer schon eine Bindung hat, bekommt keine zweite")
	cmr2.crew[1].stress = 10.0
	cmr2._kill(cmr2.crew[0], true)
	check(cmr2.crew[1].stress > 20.0 and cmr2.crew[1].stress < 40.0, "Trauer um einen Gefährten ist milder als um einen Bruder")
	check(is_equal_approx(cmr2.rescue_bond_bonus(cmr2.crew[3], cmr2.crew[4]), 0.0), "ohne Band kein Rettungsbonus")

	# --- Vermächtnis ---
	var leg0 := Voyage.legacy_for({"runs": []})
	check((leg0["lines"] as Array).is_empty() and int(leg0["veterans"]) == 0, "ohne frühere Fahrten kein Vermächtnis")
	var fallen_list: Array = []
	for k in range(17):
		fallen_list.append({"name": "X", "cause": "ertrunken"})
	var leg1 := Voyage.legacy_for({"runs": [{"stage": 5, "fallen": fallen_list}, {"stage": 8, "fallen": []}]})
	check(int(leg1["best"]) == 8 and float(leg1["loot"]) == 50.0 and int(leg1["proviant"]) == 2 and String(leg1["item"]) == "teer" and String(leg1["perk"]) == "odin" and int(leg1["veterans"]) == 2, "Vermächtnis: Etappe 8 und 17 Gefallene geben Beute, Proviant, Teerung, Odins Gunst, zwei Veteranen")
	var lg := Voyage.new()
	root.add_child(lg)
	lg.autosave = false
	lg.begin()
	check(is_equal_approx(lg.loot, 100.0) and lg.items.is_empty(), "Tests und Bots starten ohne Vermächtnis")
	Settings.change_sfx(-3.0)
	check(is_equal_approx(Settings.sfx_db, -3.0) and is_equal_approx(Sfx.offset_db, -3.0), "Einstellung: Effekte leiser")
	Settings.change_sfx(3.0)

	var st := new_voyage(21)
	var fight: Dictionary = Encounters.option(Encounters.Id.HAENDLER, 0)
	var strong := Encounters.chance(st, fight)
	for m in st.crew:
		m.kraft = 0.0
	var weak := Encounters.chance(st, fight)
	check(weak < strong and weak >= 0.1 and strong <= 0.9, "Kampfaussicht hängt von der Besatzung ab (%d %% -> %d %%)" % [roundi(strong * 100), roundi(weak * 100)])
	var poor := new_voyage(22)
	poor.loot = 10.0
	check(not Encounters.available(poor, Encounters.option(Encounters.Id.HAENDLER, 1)), "Handeln ohne genug Beute nicht möglich")

	# --- Hafen ---
	var hb := new_voyage(40)
	hb._enc_pending = Encounters.Id.HAFEN
	hb._advance()
	var hopts: Array = Encounters.DATA[Encounters.Id.HAFEN]["options"]
	check(hb.phase == Voyage.Phase.ENCOUNTER and Encounters.is_harbor(hb.encounter), "Hafen öffnet sich")
	check(hb.recruits.size() == 3 and hb.can_recruit() and hb.reserve_free() == 2, "Taverne: drei Anwärter, Platz in der Reserve")
	check(Encounters.available(hb, hopts[2]) and bool(hopts[2].get("crew", false)), "Anheuern ist im Hafen immer wählbar (öffnet die Taverne)")
	hb.hull = 40.0
	hb.decide_encounter(4)
	check(hb.shop_open and hb.phase == Voyage.Phase.ENCOUNTER and hb.shop.size() == 3, "Werft: öffnet sich mit drei Angeboten, der Hafen bleibt offen")
	hb.loot = 500.0
	check(hb.buy_repair() and is_equal_approx(hb.hull, 65.0) and is_equal_approx(hb.loot, 500.0 - float(hb.repair_price())), "Werft: Rumpf +25 gegen Beute")
	var offer_id := String(hb.shop[0])
	var offer_price := Items.price_at(offer_id, hb.stage)
	var loot_pre := hb.loot
	check(hb.buy_offer(0) and hb.items.values().has(offer_id) and is_equal_approx(hb.loot, loot_pre - float(offer_price)) and hb.shop.size() == 2, "Werft: Gegenstand kaufen und einbauen")
	hb.loot = 1.0
	check(not hb.buy_offer(0) and not hb.buy_repair(), "zu teuer: nichts gekauft")
	hb.close_shop()
	check(not hb.shop_open and hb.phase == Voyage.Phase.ENCOUNTER, "Werft schließen: der Hafen bleibt offen")
	hb.loot = 300.0
	hb.crew[0].stress = 50.0
	hb.decide_encounter(0)
	run_until_idle(hb)
	check(hb.crew[1].stress < 50.0 or hb.crew[0].stress < 50.0, "Met senkt die Verzweiflung")
	check(hb.phase == Voyage.Phase.ENCOUNTER and not Encounters.available(hb, hopts[0]), "Met nur einmal pro Besuch")
	hb.decide_encounter(1)
	run_until_idle(hb)
	check(not Encounters.available(hb, hopts[1]) and hb.phase == Voyage.Phase.ENCOUNTER, "Rasten nur einmal pro Besuch")
	var cand: Dictionary = hb.recruits[0]
	var price0 := int(cand["price"])
	var loot_h := hb.loot
	hb.decide_encounter(2)
	check(hb.crew_requested and hb.phase == Voyage.Phase.ENCOUNTER, "Anheuern öffnet die Taverne, der Hafen bleibt offen")
	hb.crew_requested = false
	check(hb.hire_candidate(0) and hb.reserve.size() == 1 and hb.reserve[0].state == CrewMember.State.RESERVE and hb.reserve[0].display_name == String(cand["name"]) and is_equal_approx(hb.loot, loot_h - float(price0)), "Anheuern: der Neue kommt in die Reserve, Beute bezahlt")
	check(hb.recruits.size() == 2 and invariants(hb) == "", "zwei Anwärter bleiben, alles konsistent")
	var fallen_man := hb.crew[3]
	hb._kill(fallen_man, true)
	check(hb.can_recruit() and invariants(hb) == "", "nach einem Todesfall ist Platz für einen Neuen")
	var alive0 := hb.alive_count()
	var name2 := String((hb.recruits[0] as Dictionary)["name"])
	check(hb.hire_candidate(0) and hb.alive_count() == alive0 + 1 and hb.crew[3].display_name == name2 and hb.crew[3].state == CrewMember.State.ABOARD and invariants(hb) == "", "Anheuern: der Neue nimmt den Platz des Gefallenen ein")
	check(hb.fallen_names.size() == 1 and hb.reserve.size() == 1, "der Gefallene bleibt in der Liste, die Reserve ist unberührt")
	hb.loot = 100.0
	var prov0 := hb.proviant
	hb.decide_encounter(3)
	run_until_idle(hb)
	check(hb.proviant == prov0 + 8, "Proviant kaufen: +8")
	hb.loot = 10.0
	check(not Encounters.available(hb, hopts[3]), "ohne Beute keinen Proviant")
	hb.decide_encounter(3)
	check(hb.phase == Voyage.Phase.ENCOUNTER, "unbezahlbare Option wird ignoriert")
	hb.decide_encounter(6)
	run_until_idle(hb)
	check(hb.phase == Voyage.Phase.PLAN and hb.encounter == -1, "Ablegen beendet den Hafenbesuch")

	# --- Rettung ---
	var w := new_voyage(2)
	for m in w.crew:
		m.traits = []  # Eigenschaften würden die erwarteten Zahlen verschieben
	var victim := w.crew[4]
	w._throw_overboard(victim)
	check(victim.state == CrewMember.State.OVERBOARD and w.slot_owner[4] == null, "über Bord macht Platz frei")
	w._advance()
	check(w.phase == Voyage.Phase.RESCUE and w.swimmer == victim and w.rescuer != null, "Rettungsentscheidung")
	var stress_before := w.crew[0].stress
	w.decide_rescue(false)
	run_until_idle(w)
	check(victim.state == CrewMember.State.DEAD and w.fallen.has(victim), "zurückgelassen = tot")
	check(w.crew[0].stress >= stress_before + 19.0 or w.crew[0].afflicted, "Zurücklassen kostet alle Mut")
	check(w.phase == Voyage.Phase.PLAN and invariants(w) == "", "danach Planung, konsistent")

	var ok_count := 0
	var fail_count := 0
	for sd in range(20):
		var x := new_voyage(100 + sd)
		var s := x.crew[5]
		x._throw_overboard(s)
		x._advance()
		var prov := x.proviant
		x.decide_rescue(true)
		var n2 := 0
		while x.phase == Voyage.Phase.RESOLVE and n2 < 100:
			x._process(0.5)
			n2 += 1
		if s.state == CrewMember.State.ABOARD:
			ok_count += 1
			if x.slot_owner[s.slot] != s or s.kraft > 25.0:
				check(false, "gerettet aber inkonsistent")
		else:
			fail_count += 1
		if x.proviant != prov - 1 and prov > 0:
			check(false, "Rettung kostet Proviant")
		var msg := invariants(x)
		if msg != "":
			check(false, "Rettung konsistent: " + msg)
	check(ok_count > 0 and fail_count > 0, "Rettung gelingt (%d) und scheitert (%d)" % [ok_count, fail_count])

	# --- Verzagen, Hunger ---
	var z := new_voyage(3)
	z.crew[1].stress = 105.0
	z._check_breakdown()
	var zc := z.crew[1]
	var kippt := zc.afflicted and zc.stress == 60.0
	if zc.affliction == CrewMember.Affliction.BERSERK:
		kippt = kippt and is_equal_approx(zc.efficiency(), 1.2)
	else:
		kippt = kippt and zc.efficiency() <= 0.5
	check(kippt, "bei 100 Verzweiflung kippt er (verzagt: halbe Leistung, Berserker: 1,2-fach)")
	var h := new_voyage(4)
	h.proviant = 0
	h.hull = 50.0
	for m in h.crew:
		m.kraft = 0.0
	h.proviant = 2
	h.select_strategy(Strategy.Id.BEIDREHEN)  # Beidrehen braucht Proviant; danach ist er aufgebraucht
	h.proviant = 0
	h._plan = h.plan()
	h._do_upkeep()
	check(h.alive_count() < 7, "ohne Proviant sterben Erschöpfte")

	# --- Rumpf ---
	var c := new_voyage(5)
	quiet_node(c, 1, 0, 2)
	for i in (c.map[2] as Array).size():
		quiet_node(c, 2, i, 2)  # auch der Weg dahinter ist ruhig
	c.select_route(0)
	var calm := c.plan(pre(c, Strategy.Id.BUG_IN_DIE_SEE))
	check(float(calm["strain"]) == 0.0 and float(calm["hull_after"]) == 100.0, "ruhige See: kein Rumpfschaden")
	quiet_node(c, 1, 0, 4)
	var rough := c.plan(pre(c, Strategy.Id.BUG_IN_DIE_SEE))
	check(float(rough["strain"]) > 0.0, "schwere See schadet dem Rumpf")
	c.hull = 60.0
	c.select_strategy(Strategy.Id.BEIDREHEN)
	c.confirm()
	run_until_idle(c)
	check(c.hull > 60.0 and c.hull <= 100.0, "Zimmerleute reparieren den Rumpf (60 -> %d)" % roundi(c.hull))
	var idle := new_voyage(6)
	quiet_node(idle, 1, 0, 1)
	quiet_node(idle, 1, 1, 1)
	for i in (idle.map[2] as Array).size():
		quiet_node(idle, 2, i, 1)
	var cm: CrewMember = null
	for m in idle.crew:
		if m.slot >= 0 and Stations.slot_station(m.slot) == Stations.Id.ZIMMERMANN:
			cm = m
	cm.kraft = 50.0
	idle.select_route(int(idle.next_links()[0]))
	idle.select_strategy(Strategy.Id.BUG_IN_DIE_SEE)
	idle.confirm()
	run_until_idle(idle)
	check(cm.kraft > 50.0, "Zimmerleute ruhen, wenn nichts zu reparieren ist")
	var broke := new_voyage(8)
	broke.proviant = 0
	check(broke.can_choose(pre(broke, Strategy.Id.VOLLE_FAHRT)), "Manöver mit Meilen immer wählbar")
	check(not broke.can_choose(pre(broke, Strategy.Id.BEIDREHEN)), "Rasten ohne Proviant gesperrt")
	broke.set_dial(0, 0)
	broke.set_dial(1, 0)
	check(not Strategy.is_rest(broke.sail_set, broke.oars_set), "Regler lassen kein Beidrehen ohne Proviant zu")

	# --- Manöver aus drei Reglern ---
	var dm_ok := true
	for dm_s in 3:
		for dm_o in 3:
			for dm_k in 3:
				var dm_d := Strategy.build(dm_s, dm_o, dm_k)
				var dm_rest := dm_s == 0 and dm_o == 0
				if bool(dm_d["rest"]) != dm_rest or float(dm_d["miles"]) > 2.0 or (not dm_rest and float(dm_d["miles"]) < 0.5) or (dm_rest and float(dm_d["miles"]) != 0.0):
					dm_ok = false
				for dm_hz in dm_d["counter"]:
					if absf(float(dm_d["counter"][dm_hz])) > 1.0:
						dm_ok = false
				if not dm_rest and not (dm_d["needs"] as Dictionary).has(Stations.Id.STEUER):
					dm_ok = false
	check(dm_ok, "alle 27 Reglerstellungen ergeben ein stimmiges Manöver")
	var dm_a := Strategy.build(2, 0, 1)
	check(int(dm_a["miles"]) == 1 and not bool(dm_a["rows"]) and int((dm_a["cost"] as Dictionary)[Stations.Id.RUDER]) < 0, "nur unter Segel: 1 Meile, die Ruderer ruhen")
	var dm_b := Strategy.build(0, 2, 1)
	check(int(dm_b["miles"]) == 1 and bool(dm_b["rows"]) and float((dm_b["counter"] as Dictionary)[Sea.Hazard.BOE]) >= 1.0, "nur gerudert: Böen können nichts anhaben")
	check(float(Strategy.build(1, 2, 1)["miles"]) >= 1.5 and float(Strategy.build(2, 1, 1)["miles"]) >= 1.5 and float(Strategy.build(1, 1, 1)["miles"]) < 1.5 and is_equal_approx(float(Strategy.build(2, 2, 1)["miles"]), 2.0), "Vortrieb: gerefft + ruhig 1,1, voll + kräftig 2,0 Meilen")
	var dm_c := Strategy.build(1, 1, 0)
	var dm_f := Strategy.build(1, 1, 2)
	check(float(dm_c["strain"]) < float(dm_f["strain"]) and float((dm_c["counter"] as Dictionary)[Sea.Hazard.RIFF]) < 0.0 and float((dm_f["counter"] as Dictionary)[Sea.Hazard.RIFF]) >= 1.0, "nahe Küste: weniger Seegang, aber Riffe; weit draußen umgekehrt")
	check(Strategy.build(0, 0, 0)["rest"] and int(Strategy.build(0, 0, 0)["proviant"]) == Strategy.REST_PROVIANT, "beide aus ist Beidrehen und kostet Proviant")
	var dm_v := new_voyage(96)
	var dm_before := [dm_v.sail_set, dm_v.oars_set, dm_v.coast_set]
	dm_v.maneuver(0, 0, 2)  # Vorschau darf nichts verstellen
	check(dm_before == [dm_v.sail_set, dm_v.oars_set, dm_v.coast_set], "Vorschau verstellt die Regler nicht")
	dm_v.set_dial(0, 2)
	dm_v.set_dial(1, 2)
	dm_v.set_dial(2, 0)
	check(dm_v.sail_set == 2 and dm_v.oars_set == 2 and dm_v.coast_set == 0, "Regler lassen sich einzeln verstellen")
	dm_v.set_dial(3, 1)
	dm_v.set_dial(0, 5)
	check(dm_v.sail_set == 2, "ungültige Regler werden ignoriert")
	var dm_rowers: Array[CrewMember] = []
	for m in dm_v.crew:
		if Stations.slot_station(m.slot) == Stations.Id.RUDER:
			dm_rowers.append(m)
	for m in dm_rowers:
		m.kraft = 25.0
	dm_v.select_route(int(dm_v.next_links()[0]))
	var dm_hard := int(dm_v.plan(dm_v.maneuver(2, 2, 1))["miles"])
	var dm_soft := int(dm_v.plan(dm_v.maneuver(2, 1, 1))["miles"])
	check(dm_hard >= dm_soft, "kräftiges Rudern trägt auch eine müde Besatzung weiter (%d statt %d Meilen)" % [dm_hard, dm_soft])

	# --- Eigenschaften und Marotten ---
	var sets_ok := true
	for k in range(300):
		var ts := Traits.random_set()
		if ts.is_empty() or ts.size() > 2:
			sets_ok = false
		if ts.size() == 2:
			for pair in Traits.CONFLICTS:
				if (ts[0] == pair[0] and ts[1] == pair[1]) or (ts[0] == pair[1] and ts[1] == pair[0]):
					sets_ok = false
	check(sets_ok, "Eigenschaften: 1-2 pro Mann, ohne Widersprüche")
	var tv := new_voyage(60)
	var all_traits := true
	for m in tv.crew:
		if m.traits.is_empty():
			all_traits = false
	check(all_traits, "jeder Mann der Besatzung hat Eigenschaften")
	var strong_man := CrewMember.new()
	strong_man.traits = [Traits.Id.STARK]
	check(is_equal_approx(strong_man.efficiency_at(Stations.Id.RUDER), 1.3) and is_equal_approx(strong_man.efficiency_at(Stations.Id.STEUER), 1.0), "Starker Arm: nur am Ruder stärker")
	var anxious := CrewMember.new()
	anxious.traits = [Traits.Id.AENGSTLICH]
	var calm_man := CrewMember.new()
	calm_man.traits = [Traits.Id.GELASSEN]
	tv._add_stress(anxious, 10.0)
	tv._add_stress(calm_man, 10.0)
	check(is_equal_approx(anxious.stress, 15.0) and is_equal_approx(calm_man.stress, 6.0), "Ängstlich 1,5-fach, gelassen 0,6-fach")
	calm_man.stress = 50.0
	tv._add_stress(calm_man, -10.0)
	check(is_equal_approx(calm_man.stress, 40.0), "Erleichterung wirkt immer voll")
	var unlucky := CrewMember.new()
	unlucky.traits = [Traits.Id.PECHVOGEL]
	var sailor := CrewMember.new()
	sailor.traits = [Traits.Id.SEEBAER]
	var pool: Array[CrewMember] = [unlucky, sailor]
	var unlucky_n := 0
	var sailor_n := 0
	for k in range(2000):
		if tv._pick_weighted(pool) == unlucky:
			unlucky_n += 1
		else:
			sailor_n += 1
	check(unlucky_n > sailor_n * 3, "Pechvogel fällt viel öfter über Bord als der Seebär (%d zu %d)" % [unlucky_n, sailor_n])
	var fighter := new_voyage(61)
	var base_strength := fighter.strength()
	for m in fighter.crew:
		m.traits = [Traits.Id.HEISSSPORN]
	check(fighter.strength() > base_strength or base_strength >= 1.0, "Heißsporn stärkt die Kampfkraft")
	var swimmer_v := new_voyage(62)
	var swimmer_man := swimmer_v.crew[2]
	swimmer_man.traits = [Traits.Id.SCHWIMMER]
	swimmer_v.swimmer = swimmer_man
	var plain_v := new_voyage(62)
	plain_v.swimmer = plain_v.crew[2]
	plain_v.crew[2].traits = [Traits.Id.ZAEH]
	check(swimmer_v.rescue_chance(swimmer_v.crew[0]) > plain_v.rescue_chance(plain_v.crew[0]), "Schwimmer werden eher gerettet")

	var bz := new_voyage(63)
	bz.crew[1].stress = 105.0
	bz.crew[1].traits = [Traits.Id.HEISSSPORN]
	bz._check_breakdown()
	check(bz.crew[1].afflicted and (bz.crew[1].affliction == CrewMember.Affliction.VERZAGT or bz.crew[1].affliction == CrewMember.Affliction.BERSERK), "Kippen: verzagt oder Berserker")
	var berserk := new_voyage(64)
	var bm := berserk.crew[3]
	bm.afflicted = true
	bm.affliction = CrewMember.Affliction.BERSERK
	bm.kraft = 100.0
	check(is_equal_approx(bm.efficiency(), 1.2), "Berserker arbeitet stärker")
	var hits := [0]
	berserk.log_added.connect(func(text: String, _kind: int) -> void:
		if text.contains("rastet aus"):
			hits[0] += 1)
	berserk.select_strategy(Strategy.Id.BEIDREHEN)
	for k in range(60):
		berserk._plan = berserk.plan()
		berserk._do_upkeep()
	check(hits[0] > 0, "Berserker schlagen um sich (%d Mal in 60 Fahrten)" % hits[0])

	# --- Saga ---
	var sg := new_voyage(65)
	sg._note("drowned", sg.crew[0].display_name)
	sg._note("rescued", sg.crew[1].display_name)
	sg._note("killed", sg.crew[2].display_name, Encounters.Id.UNGEHEUER)
	sg.fallen_names.append(sg.crew[0].display_name)
	sg.victory = true
	var story := Saga.compose(sg)
	check(story.contains("Wir liefen mit 7 Mann aus") and story.contains(sg.crew[0].display_name) and story.contains(sg.crew[1].display_name), "Saga nennt Ausgangsbesatzung und Ereignisse")
	check(sg.death_causes[sg.crew[0].display_name] == "ertrunken" and String(sg.death_causes[sg.crew[2].display_name]).contains("Seeungeheuer"), "Todesursachen werden gemerkt")

	# --- Speichern, Fortsetzen, Gedenkstein (mit Testdateien) ---
	Persist.run_path = "user://selftest_run.json"
	Persist.memorial_path = "user://selftest_gedenkstein.json"
	Persist.clear_run()
	if FileAccess.file_exists(Persist.memorial_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Persist.memorial_path))
	var pv := new_voyage(70)
	pv.autosave = true
	for turn in range(3):
		if pv.phase == Voyage.Phase.PLAN:
			pv.select_route(int(pv.next_links()[0]))
			pv.select_strategy(Strategy.Id.BUG_IN_DIE_SEE)
			pv.confirm()
		var guard2 := 0
		while pv.phase != Voyage.Phase.PLAN and not pv.ended and guard2 < 400:
			guard2 += 1
			if pv.phase == Voyage.Phase.RESCUE:
				pv.decide_rescue(true)
			elif pv.phase == Voyage.Phase.ENCOUNTER:
				pv.decide_encounter(Encounters.DATA[pv.encounter]["options"].size() - 1)
			else:
				pv._process(0.5)
	check(Persist.has_run() and not pv.ended, "Autosave: nach jeder Meile liegt ein Spielstand vor")
	pv.equip("beschlag")
	pv.equip("tuch@3")
	pv.crew[0].weapon_lvl = 2
	pv.crew[0].skill_lvl = {"s_hieb": 1}
	pv.perks.append("wind")
	pv._mods = {}
	pv.level = 3
	pv.xp = 20
	pv.powder = 3
	pv.set_dial(0, 2)
	pv.set_dial(2, 0)
	Persist.save_run(pv)
	var saved := Persist.load_run()
	check(saved.has("map") and saved.has("crew") and int(saved["mile"]) == pv.mile, "Spielstand ist lesbar")
	Persist.save_run(pv)  # zweites Mal: die erste Fassung wird zur Sicherung
	check(FileAccess.file_exists(Persist.run_path + ".bak") and not FileAccess.file_exists(Persist.run_path + ".tmp"), "Speichern: die vorige Fassung bleibt als Sicherung, keine Reste")
	var cut := FileAccess.open(Persist.run_path, FileAccess.WRITE)
	cut.store_string('{"map": [[{"sea": 1')  # wie nach einem Abbruch mitten im Schreiben
	cut.close()
	var rescued := Persist.load_run()
	check(rescued.has("map") and rescued.has("crew") and int(rescued["mile"]) == pv.mile, "Speichern: eine abgeschnittene Datei fällt auf die Sicherung zurück")
	Persist.save_run(pv)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Persist.run_path))  # wie nach einem Abbruch zwischen Löschen und Umbenennen
	check(Persist.has_run() and Persist.resumable(Persist.load_run()), "Speichern: fehlt die Hauptdatei, wird die Sicherung fortgesetzt")
	Persist.save_run(pv)
	check(Persist.resumable(saved), "Spielstand enthält alle Schlüssel, die das Fortsetzen braucht")
	var broken := saved.duplicate()
	broken.erase("enc_done")
	check(not Persist.resumable(broken) and not Persist.resumable({}), "ein Spielstand ohne Kernschlüssel wird nicht fortgesetzt (neue Fahrt statt Absturz)")
	var rv := Voyage.new()
	root.add_child(rv)
	rv.resume(saved)
	check(rv.crew[0].weapon_lvl == 2 and int(rv.crew[0].skill_lvl.get("s_hieb", 0)) == 1 and rv.items.values().has("tuch@3"), "Speichern: Schmiede-Stufen und seltene Gegenstände bleiben erhalten")
	var same := rv.mile == pv.mile and rv.pos == pv.pos and is_equal_approx(rv.hull, pv.hull) and rv.proviant == pv.proviant and is_equal_approx(rv.loot, pv.loot) and rv.turns == pv.turns
	for i in pv.crew.size():
		var pa := pv.crew[i]
		var pb := rv.crew[i]
		if pa.display_name != pb.display_name or pa.state != pb.state or pa.slot != pb.slot or not is_equal_approx(pa.kraft, pb.kraft) or pa.traits != pb.traits or pa.afflicted != pb.afflicted:
			same = false
	for col in range(0, Voyage.MILES + 1):
		for i in (pv.map[col] as Array).size():
			var na: Dictionary = pv.node_at(col, i)
			var nb: Dictionary = rv.node_at(col, i)
			if int(na["sea"]) != int(nb["sea"]) or int(na["hazard"]) != int(nb["hazard"]) or int(na["enc"]) != int(nb["enc"]) or (na["links"] as Array) != (nb["links"] as Array) or bool(na.get("visited", false)) != bool(nb.get("visited", false)):
				same = false
	check(same, "Fortsetzen stellt Karte, Schiff und Mannschaft genau wieder her")
	var bonds_same := rv.bonds.size() == pv.bonds.size() and pv.bonds.size() >= 1
	for i in mini(rv.bonds.size(), pv.bonds.size()):
		for key in ["a", "b", "type"]:
			if int(rv.bonds[i][key]) != int(pv.bonds[i][key]):
				bonds_same = false
	check(bonds_same, "Beziehungen werden gespeichert und fortgesetzt")
	check(rv.stage == pv.stage and is_equal_approx(rv.leg, pv.leg) and rv.route == pv.route and rv.level == 3 and rv.xp == 20 and rv.items == pv.items and rv.perks == pv.perks and rv.powder == 3 and is_equal_approx(rv.total_miles, pv.total_miles) and is_equal_approx(rv.hull_max(), 120.0), "Etappe, Strecke, Stufe, Gegenstände und Segen werden gespeichert")
	check(rv.sail_set == 2 and rv.oars_set == pv.oars_set and rv.coast_set == 0, "Reglerstellung wird gespeichert und fortgesetzt")
	check(rv.phase == Voyage.Phase.PLAN and invariants(rv) == "", "fortgesetzte Fahrt ist in Planung und konsistent")
	rv.select_route(int(rv.next_links()[0]))
	rv.select_strategy(Strategy.Id.BUG_IN_DIE_SEE)
	rv.confirm()
	run_until_idle(rv)
	check(rv.mile > pv.mile or not is_equal_approx(rv.leg, pv.leg) or rv.phase == Voyage.Phase.ENCOUNTER, "fortgesetzte Fahrt lässt sich weiterspielen")

	var mv := new_voyage(71)
	mv.autosave = true
	mv.max_stage = 2
	var mguard := 0
	while not mv.ended and mguard < 3000:
		mguard += 1
		if mv.automat_open:
			play_automat(mv)  # ein Automat im Hafen (Spelunke) oder nach einem Sieg: wie ein Zufallsspieler durchspielen
			continue
		if mv.phase == Voyage.Phase.PLAN:
			if not mv.perk_offer.is_empty():
				mv.choose_perk(0)
			var ml := mv.next_links()
			mv.select_route(int(ml[randi() % ml.size()]))
			random_dials(mv)
			mv.confirm()
		elif mv.phase == Voyage.Phase.RESCUE:
			mv.decide_rescue(randf() < 0.5)
		elif mv.phase == Voyage.Phase.ENCOUNTER:
			mv.decide_encounter(random_tactic(mv))
		else:
			mv._process(0.5)
	check(mv.ended and mv.saga_text != "", "Fahrt endet mit einer Saga")
	check(not Persist.has_run(), "nach dem Ende ist der laufende Spielstand gelöscht")
	var mem := Persist.load_memorial()
	var runs0: Array = mem["runs"]
	check(runs0.size() == 1 and String(runs0[0]["saga"]) == mv.saga_text, "Gedenkstein hat die Fahrt aufgenommen")
	check(runs0.size() == 1 and int(runs0[0]["n"]) == 1 and (runs0[0]["fallen"] as Array).size() == mv.fallen_names.size(), "Gedenkstein zählt Fahrten und Gefallene")
	var mv2 := new_voyage(72)
	mv2.victory = true
	mv2.fallen_names.append("Test")
	Persist.add_memorial(mv2)
	mem = Persist.load_memorial()
	check((mem["runs"] as Array).size() == 2 and int(mem["runs"][1]["n"]) == 2, "zweite Fahrt wird als Nummer 2 angehängt")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Persist.memorial_path))
	Persist.clear_run()
	for suffix in [".bak", ".tmp"]:
		for base in [Persist.run_path, Persist.memorial_path]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(base + suffix))
	check(not Persist.has_run() and not FileAccess.file_exists(Persist.memorial_path), "Testdateien aufgeräumt")

	# --- Spielautomaten ---
	var s6_lv := Slots.bet_levels(3)
	check(s6_lv == [10, 20, 50] and Slots.bonus_bet(3) == 20 and Slots.bonus_bet(3, true) == 30, "Automat: Einsatzstufen wachsen mit der Etappe, der Freidreh nach dem Kraken ist höher")
	var s6_s := Slots.new("norn", 100)
	var s6_row := func(a: int, b: int, c: int, d: int, e: int) -> Array:
		# Mittellinie mit diesen Symbolen, darüber und darunter Schild/Axt abwechselnd, damit nichts anderes zahlt
		var g: Array = []
		for k in 5:
			var mid: int = [a, b, c, d, e][k]
			g.append([Slots.Sym.HORN if k % 2 == 0 else Slots.Sym.AXT, mid, Slots.Sym.AXT if k % 2 == 0 else Slots.Sym.HORN])
		return g
	var s6_l1: Array = s6_s._norn_lines(s6_row.call(Slots.Sym.RABE, Slots.Sym.RABE, Slots.Sym.RABE, Slots.Sym.RABE, Slots.Sym.RABE), false)
	var s6_l2: Array = s6_s._norn_lines(s6_row.call(Slots.Sym.SCHILD, Slots.Sym.AUGE, Slots.Sym.SCHILD, Slots.Sym.RABE, Slots.Sym.HAMMER), false)
	var s6_l3: Array = s6_s._norn_lines(s6_row.call(Slots.Sym.SCHILD, Slots.Sym.SCHILD, Slots.Sym.BLITZ, Slots.Sym.SCHILD, Slots.Sym.SCHILD), false)
	var s6_l4: Array = s6_s._norn_lines(s6_row.call(Slots.Sym.AUGE, Slots.Sym.AUGE, Slots.Sym.AUGE, Slots.Sym.AUGE, Slots.Sym.AUGE), false)
	var s6_l5: Array = s6_s._norn_lines(s6_row.call(Slots.Sym.DRAUGR, Slots.Sym.DRAUGR, Slots.Sym.DRAUGR, Slots.Sym.DRAUGR, Slots.Sym.DRAUGR), true)
	var s6_l6: Array = s6_s._norn_lines(s6_row.call(Slots.Sym.DRAUGR, Slots.Sym.DRAUGR, Slots.Sym.DRAUGR, Slots.Sym.DRAUGR, Slots.Sym.DRAUGR), false)
	var s6_mid1 := func(ls: Array) -> Dictionary:
		for s6_wl in ls:
			if int((s6_wl as Dictionary)["line"]) == 0:
				return s6_wl
		return {}
	check(not (s6_mid1.call(s6_l1) as Dictionary).is_empty() and int((s6_mid1.call(s6_l1) as Dictionary)["pay"]) == 80 and int((s6_mid1.call(s6_l1) as Dictionary)["count"]) == 5, "Automat: fünf Raben auf der Mittellinie zahlen 80 Linieneinsätze")
	check(int((s6_mid1.call(s6_l2) as Dictionary).get("count", 0)) == 3 and int((s6_mid1.call(s6_l2) as Dictionary).get("sym", -1)) == Slots.Sym.SCHILD, "Automat: das Odinsauge ersetzt ein Symbol (Schild-Schild-Schild)")
	check(s6_mid1.call(s6_l3).is_empty(), "Automat: eine Blitzrune unterbricht die Linie")
	check(int((s6_mid1.call(s6_l4) as Dictionary).get("pay", 0)) == 1000 and int((s6_mid1.call(s6_l5) as Dictionary).get("pay", 0)) == 500, "Automat: fünf Joker zahlen 1000, im Freispiel zahlen fünf Draugr 500")
	check(int((s6_mid1.call(s6_l6) as Dictionary).get("pay", 0)) == 500, "Automat: im Grundspiel ist der Draugr ein gewöhnliches Symbol")
	# die Folge: sicherer Auslöser, Freispiele, Stapel und Obergrenze
	var s6_f := Slots.new("norn", 50)
	s6_f.rng.seed = 321
	s6_f.force_trigger = true
	var s6_t := s6_f.spin()
	check(int(s6_t["trigger"]) >= 8 and s6_f.in_free() and s6_f.free_left == int(s6_t["trigger"]) and (s6_t["scatter"] as Array).size() >= 3, "Automat: drei Blitzrunen lösen Freispiele aus (%d)" % int(s6_t["trigger"]))
	var s6_ok := true
	var s6_stacks := 0
	var s6_power := 0
	var s6_cap_ok := true
	for k in 400:
		var s6_g_f := Slots.new("norn", 50)
		s6_g_f.rng.seed = 500 + k
		s6_g_f.force_trigger = true
		s6_g_f.spin()
		var s6_total_fg := 0
		var s6_guard_fg := 0
		while s6_g_f.in_free() and s6_guard_fg < 80:
			s6_guard_fg += 1
			var s6_rf := s6_g_f.spin()
			var s6_units := 0
			for s6_wl in s6_g_f._norn_lines(s6_rf["grid"], true):
				s6_units += int((s6_wl as Dictionary)["pay"])
			var s6_mult := maxi((s6_rf["stacks"] as Array).size(), 1) * (int(s6_rf["powerup"]) if int(s6_rf["powerup"]) > 0 else 1)
			if int(s6_rf["mult"]) != s6_mult:
				s6_ok = false
			var s6_expect := roundi(float(s6_units) * 50.0 / 10.0 * float(s6_mult))
			if int(s6_rf["win"]) > s6_expect or (int(s6_rf["win"]) < s6_expect and s6_total_fg + s6_expect < roundi(Slots.FREE_CAP * 50.0)):
				s6_ok = false
			s6_total_fg += int(s6_rf["win"])
			s6_stacks += 1 if not (s6_rf["stacks"] as Array).is_empty() else 0
			s6_power += 1 if int(s6_rf["powerup"]) > 0 else 0
		if s6_total_fg > roundi(Slots.FREE_CAP * 50.0) or s6_g_f.free_left != 0 or s6_g_f.mode != Slots.Mode.BASE:
			s6_cap_ok = false
	check(s6_ok, "Automat: Freispiel-Gewinn = Linien x Faktor (Stapel mal Power-Up), nur die Obergrenze kürzt")
	check(s6_cap_ok and s6_stacks > 20 and s6_power > 5, "Automat: Freispiele enden sauber unter der Obergrenze, Stapel (%d) und Power-Ups (%d) kommen vor" % [s6_stacks, s6_power])
	# Rückzahlung: groß genug, um zu begeistern, aber kein Selbstläufer
	var s6_r := Slots.new("norn", 100)
	s6_r.rng.seed = 2468
	var s6_paid := 0.0
	var s6_n := 60000
	for k in s6_n:
		var s6_rr := s6_r.spin()
		s6_paid += float(s6_rr["win"])
		var s6_gg := 0
		while s6_r.in_free() and s6_gg < 80:
			s6_paid += float(s6_r.spin()["win"])
			s6_gg += 1
	var s6_rtp := s6_paid / (100.0 * float(s6_n))
	check(s6_rtp > 0.95 and s6_rtp < 1.5, "Automat: Rückzahlung der Nornenwalzen %.0f %%" % (s6_rtp * 100.0))
	var s6_lk := Slots.new("loki", 100)
	s6_lk.rng.seed = 1357
	var s6_lpaid := 0.0
	var s6_curses := 0
	for k in 40000:
		var s6_rl := s6_lk.spin()
		s6_lpaid += float(s6_rl["win"])
		s6_curses += 1 if bool(s6_rl["curse"]) else 0
	var s6_lrtp := s6_lpaid / (100.0 * 40000.0)
	check(s6_lrtp > 0.9 and s6_lrtp < 1.4 and s6_curses > 400 and s6_curses < 2400, "Automat: Lokis Walzen zahlen %.0f %% zurück, Lokis Streich in %.1f %% der Drehs" % [s6_lrtp * 100.0, float(s6_curses) / 400.0])
	# Einbindung: Hafen (Spelunke)
	var s6_hopts: Array = Encounters.DATA[Encounters.Id.HAFEN]["options"]
	check(s6_hopts.size() == 7 and String(s6_hopts[5]["label"]) == "Spelunke" and bool(s6_hopts[6].get("leave", false)), "Hafen: die Spelunke steht vor dem Ablegen")
	var s6_v := new_voyage(2101)
	s6_v.stage = 3
	s6_v.loot = 300.0
	s6_v._enc_pending = Encounters.Id.HAFEN
	s6_v._advance()
	check(Encounters.available(s6_v, s6_hopts[5]), "Spelunke: mit genug Beute wählbar")
	s6_v.decide_encounter(5)
	check(s6_v.automat_open and s6_v.automat_kind == "harbor" and s6_v.phase == Voyage.Phase.ENCOUNTER and s6_v.automat_bet() == 10, "Spelunke: der Automat öffnet sich, die Begegnung bleibt offen")
	var s6_before := s6_v.loot
	s6_v.automat.rng.seed = 11
	var s6_res := s6_v.automat_spin()
	check(not s6_res.is_empty() and is_equal_approx(s6_v.loot, s6_before - 10.0) and s6_v.automat_unbanked == int(s6_res["win"]), "Spelunke: der Einsatz wird gleich bezahlt, der Gewinn wartet auf das Gutschreiben")
	s6_v.automat_bank()
	check(s6_v.automat_unbanked == 0 and is_equal_approx(s6_v.loot, s6_before - 10.0 + float(int(s6_res["win"]))), "Spelunke: Gutschreiben bringt den Gewinn auf die Beute")
	var s6_guard := 0
	while s6_v.automat.in_free() and s6_guard < 80:
		s6_v.automat_spin()
		s6_guard += 1
	s6_v.automat_bank()
	s6_v.automat_set_bet(2)
	check(s6_v.automat_bet() == 50, "Spelunke: Einsatzstufen einstellbar (nur außerhalb der Freispiele)")
	s6_v.loot = 5000.0
	var s6_spins := 0
	while s6_v.automat_can_spin() and s6_spins < 30:
		s6_v.automat_spin()
		while s6_v.automat.in_free():
			s6_v.automat_spin()
		s6_v.automat_bank()
		s6_spins += 1
	check(s6_spins <= Voyage.SLOT_HARBOR_SPINS and not s6_v.automat_can_spin(), "Spelunke: höchstens %d bezahlte Drehs je Hafenbesuch (gespielt %d)" % [Voyage.SLOT_HARBOR_SPINS, s6_spins])
	s6_v.automat_close()
	check(not s6_v.automat_open and s6_v.phase == Voyage.Phase.ENCOUNTER and not Encounters.available(s6_v, s6_hopts[5]), "Spelunke: Schließen führt zurück in den Hafen, die Drehs sind verbraucht")
	var s6_poor := new_voyage(2102)
	s6_poor.loot = 3.0
	s6_poor._enc_pending = Encounters.Id.HAFEN
	s6_poor._advance()
	check(not Encounters.available(s6_poor, s6_hopts[5]), "Spelunke: ohne Beute für den kleinsten Einsatz nicht wählbar")
	# Belohnungen jenseits der Beute
	var s6_d1 := s6_v._slot_due(25.0, false)
	var s6_d2 := s6_v._slot_due(70.0, false)
	var s6_d3 := s6_v._slot_due(1.0, true)
	var s6_d4 := s6_v._slot_due(3.0, false)
	check(bool(s6_d1.get("perk", false)) and not s6_d1.has("gear") and int(s6_d2["gear"]) == Items.Rarity.EPISCH and int(s6_d3["gear"]) == Items.Rarity.LEGENDAER and bool(s6_d3.get("perk", false)) and s6_d4.is_empty(), "Belohnung: ab 20 Einsätzen ein Segen, ab 60 dazu ein epischer Fund, das Jackpot legendär")
	var s6_pv := new_voyage(2103)
	s6_pv.stage = 3
	s6_pv.automat_enter("bonus", 20, true)
	var s6_stash := s6_pv.stash.size()
	var s6_lines: Array = []
	s6_pv.automat_due = {"perk": true, "gear": Items.Rarity.EPISCH}
	s6_pv._pay_due(s6_pv.automat_due, s6_lines)
	check(not s6_pv.perk_offer.is_empty() and s6_pv.stash.size() == s6_stash + 1 and Items.rarity_of(String(s6_pv.stash[s6_pv.stash.size() - 1])) >= Items.Rarity.EPISCH, "Belohnung: Segenwahl und Fund (mindestens episch) werden gutgeschrieben")
	# Freidreh nach einem Sieg (Kraken: sichere Freispiele)
	var s6_bv := new_voyage(2104)
	s6_bv.stage = 3
	s6_bv.loot = 100.0
	check(s6_bv.automat_enter("bonus", Slots.bonus_bet(3, true), true) and s6_bv.automat_open and s6_bv.automat_token, "Freidreh: öffnet sich ohne Einsatz")
	var s6_b1 := s6_bv.automat_spin()
	check(int(s6_b1["trigger"]) >= 8 and is_equal_approx(s6_bv.loot, 100.0), "Freidreh nach dem Kraken: die Freispiele sind sicher, nichts kostet Beute")
	var s6_bg := 0
	while s6_bv.automat.in_free() and s6_bg < 80:
		s6_bv.automat_spin()
		s6_bg += 1
	s6_bv.automat_bank()
	check(s6_bv.automat_done and not s6_bv.automat_can_spin() and s6_bv.loot >= 100.0, "Freidreh: nach den Freispielen ist er zu Ende, die Beute wächst nur")
	s6_bv.automat_close()
	check(not s6_bv.automat_open, "Freidreh: Schließen")
	# Begegnung: Lokis Spielschiff
	check(Encounters.DATA.size() == Encounters.Id.size() and String(Encounters.DATA[Encounters.Id.SPIELER]["letter"]) == "L" and Encounters.WEIGHTS.size() == Encounters.DATA.size(), "Lokis Spielschiff: Begegnung mit eigenem Symbol und Gewicht")
	var s6_early := 0
	var s6_late := 0
	for k in 3000:
		if Encounters.random_type(1, 0) == Encounters.Id.SPIELER:
			s6_early += 1
		if Encounters.random_type(3, 0) == Encounters.Id.SPIELER:
			s6_late += 1
	check(s6_early == 0 and s6_late > 50 and s6_late < 600, "Lokis Spielschiff: kommt nicht in der ersten Etappe, später selten (%d von 3000)" % s6_late)
	var s6_lv2 := new_voyage(2105)
	s6_lv2.stage = 3
	s6_lv2.loot = 500.0
	s6_lv2._enc_pending = Encounters.Id.SPIELER
	s6_lv2._advance()
	check(s6_lv2.phase == Voyage.Phase.ENCOUNTER and s6_lv2.encounter == Encounters.Id.SPIELER and Encounters.available(s6_lv2, Encounters.option(Encounters.Id.SPIELER, 0)), "Lokis Spielschiff: Begegnung beginnt, Spielen möglich")
	s6_lv2.decide_encounter(0)
	var s6_st := s6_lv2.loki_stakes()
	check(s6_lv2.automat_open and s6_lv2.automat_kind == "loki" and s6_st.size() == 4 and int(s6_st[0]["value"]) == 250 and bool(s6_st[0]["ok"]) and bool(s6_st[1]["ok"]) and bool(s6_st[2]["ok"]) and not bool(s6_st[3]["ok"]), "Adlersson: vier Einsätze, Beute (die Hälfte, gedeckelt), Rumpf, ein Mann und die Pfandflasche (nur mit einer)")
	var s6_seen_win := false
	var s6_seen_loss := false
	var s6_seen_curse := false
	var s6_loss_ok := true
	var s6_win_ok := true
	for k in 1500:
		s6_lv2.loki_round = 0
		s6_lv2.loki_pot = 0
		s6_lv2.loot = 500.0
		s6_lv2.stash = []
		s6_lv2.loki_pick("loot")
		var s6_rl2 := s6_lv2.loki_spin()
		if s6_rl2.is_empty():
			s6_loss_ok = false
			break
		if bool(s6_rl2["curse"]):
			s6_seen_curse = true
			if int(s6_rl2["win"]) != 0 or String(s6_rl2["penalty"]) == "" or s6_lv2.loki_pot != 0:
				s6_loss_ok = false
		elif int(s6_rl2["win"]) > 0:
			s6_seen_win = true
			var s6_pot := s6_lv2.loki_pot
			if s6_pot != int(s6_rl2["win"]) or s6_pot > Voyage.LOKI_CAP or not is_equal_approx(s6_lv2.loot, 250.0):
				s6_win_ok = false
			s6_lv2.loki_cash()
			if s6_lv2.loki_pot != 0 or not is_equal_approx(s6_lv2.loot, 250.0 + float(s6_pot)):
				s6_win_ok = false
		else:
			s6_seen_loss = true
			if not is_equal_approx(s6_lv2.loot, 250.0) or s6_lv2.loki_pot != 0:
				s6_loss_ok = false
		if s6_lv2.alive_count() < 4:
			break
		s6_lv2.hull = 100.0
	check(s6_seen_win and s6_seen_loss and s6_seen_curse and s6_loss_ok and s6_win_ok, "Loki: Beute als Einsatz geht bei Niederlage und Streich verloren, ein Gewinn wird erst beim Kassieren gutgeschrieben")
	var s6_up := 0
	var s6_down := 0
	for k in 200:
		s6_lv2.loki_pot = 100
		s6_lv2.loki_ladder = 0
		s6_lv2.loki_reward = {}
		if s6_lv2.loki_risk():
			s6_up += 1
			if s6_lv2.loki_pot != 200 or s6_lv2.loki_ladder != 1:
				s6_up = -1000
		else:
			s6_down += 1
			if s6_lv2.loki_pot != 0:
				s6_down = -1000
	check(s6_up > 60 and s6_down > 60, "Loki: die Risikoleiter verdoppelt oder verliert alles (%d zu %d)" % [s6_up, s6_down])
	var s6_lv3 := new_voyage(2106)
	s6_lv3.stage = 3
	s6_lv3.loot = 500.0
	s6_lv3._enc_pending = Encounters.Id.SPIELER
	s6_lv3._advance()
	s6_lv3.decide_encounter(0)
	check(s6_lv3.loki_pick("hull"), "Loki: der Rumpf lässt sich als Einsatz wählen")
	var s6_hull_ok := false
	var s6_pts := float(roundi(s6_lv3.hull_max() * 0.25))
	for k in 400:
		s6_lv3.loki_round = 0
		s6_lv3.loki_pot = 0
		s6_lv3.hull = s6_lv3.hull_max()
		var s6_rh := s6_lv3.loki_spin()
		if s6_rh.is_empty():
			break
		if not bool(s6_rh["curse"]) and int(s6_rh["win"]) == 0:
			s6_hull_ok = is_equal_approx(s6_lv3.hull, s6_lv3.hull_max() - s6_pts)
			break
	check(s6_hull_ok, "Loki: ein verlorener Rumpf-Einsatz kostet ein Viertel des Rumpfes")
	var s6_man_ok := false
	var s6_man: CrewMember = null
	check(s6_lv3.loki_pick("man"), "Loki: ein Mann lässt sich als Einsatz wählen")
	for k in 400:
		s6_lv3.loki_round = 0
		s6_lv3.loki_pot = 0
		s6_lv3.hull = s6_lv3.hull_max()
		s6_lv3.loki_stakes()
		s6_man = s6_lv3.loki_man
		var s6_fallen_before := s6_lv3.fallen.size()
		var s6_rm := s6_lv3.loki_spin()
		if s6_rm.is_empty() or s6_man == null:
			break
		if not bool(s6_rm["curse"]) and int(s6_rm["win"]) == 0:
			s6_man_ok = s6_man.state == CrewMember.State.DEAD and s6_lv3.fallen.size() == s6_fallen_before + 1 and invariants(s6_lv3) == ""
			break
	check(s6_man_ok, "Loki: der verlorene Mann ist tot, die Mannschaft bleibt in Ordnung")
	s6_lv3.automat_close()
	check(not s6_lv3.automat_open and s6_lv3.phase == Voyage.Phase.RESOLVE, "Loki: Schließen beendet die Begegnung")
	run_until_idle(s6_lv3)
	check(s6_lv3.phase == Voyage.Phase.PLAN and invariants(s6_lv3) == "", "Loki: danach geht die Fahrt weiter")
	# Pfandflasche: legendärer Schlüsselgegenstand, sicheres Freispiel bei Adlersson
	var s7_v := new_voyage(2110)
	s7_v.stage = 3
	s7_v.loot = 500.0
	check(s7_v.pfand == 0 and Items.PFAND_MAX == 3 and Items.pfand_color() == Items.RARITY_COLORS[Items.Rarity.LEGENDAER], "Pfandflasche: legendär, zu Beginn hat man keine")
	s7_v._find_pfand("Test")
	s7_v._find_pfand("Test")
	check(s7_v.pfand == 2, "Pfandflasche: Funde zählen")
	s7_v._find_pfand("Test")
	var s7_loot := s7_v.loot
	s7_v._find_pfand("Test")
	check(s7_v.pfand == 3 and s7_v.loot > s7_loot, "Pfandflasche: mehr als %d trägt man nicht, der Rest wird gegen Pfand eingelöst" % Items.PFAND_MAX)
	var s7_dict := JSON.parse_string(JSON.stringify(s7_v.to_dict())) as Dictionary
	var s7_r := new_voyage(2111)
	s7_r.resume(s7_dict)
	check(s7_r.pfand == 3, "Pfandflasche: überlebt Speichern und Laden")
	var s7_finds := 0
	for k in 600:
		s7_v.pfand = 0
		s7_v.stash = []
		s7_v._apply_fx({"item": 1})
		s7_finds += s7_v.pfand
	check(s7_finds > 20 and s7_finds < 120, "Pfandflasche: im Wrack selten, etwa jeder zehnte Fund (%d von 600)" % s7_finds)
	var s7_e := new_voyage(2112)
	s7_e.stage = 3
	s7_e.loot = 500.0
	s7_e._enc_pending = Encounters.Id.SPIELER
	s7_e._advance()
	var s7_opts: Array = Encounters.DATA[Encounters.Id.SPIELER]["options"]
	check(s7_opts.size() == 3 and String(s7_opts[1]["label"]) == "Pfandflasche" and not Encounters.available(s7_e, s7_opts[1]) and Encounters.available(s7_e, s7_opts[0]), "Adlersson: die Karte Pfandflasche gibt es nur mit einer Pfandflasche")
	s7_e.pfand = 1
	check(Encounters.available(s7_e, s7_opts[1]), "Adlersson: mit einer Pfandflasche wählbar")
	s7_e.decide_encounter(1)
	check(s7_e.automat_open and s7_e.automat_kind == "loki" and s7_e.loki_stake == "bottle" and s7_e.loki_can_spin() and int(s7_e.loki_stake_of("bottle")["value"]) == 170, "Adlersson: die Karte öffnet den Automaten mit der Pfandflasche als Einsatz")
	var s7_ok := true
	var s7_wins := 0
	for k in 300:
		s7_e.pfand = 1
		s7_e.loki_round = 0
		s7_e.loki_pot = 0
		s7_e.loot = 500.0
		s7_e.stash = []  # ein Fund als Belohnung soll keine Beute einbringen (voller Vorrat verkauft)
		s7_e.loki_pick("bottle")
		var s7_rb := s7_e.loki_spin()
		if s7_rb.is_empty() or not bool(s7_rb["bottle"]) or bool(s7_rb["curse"]) or int(s7_rb["win"]) <= 0 or s7_e.pfand != 0 or s7_e.loki_round != 0 or s7_e.loki_pot != int(s7_rb["win"]) or not is_equal_approx(s7_e.loot, 500.0):
			s7_ok = false
			break
		s7_wins += int(s7_rb["win"])
		s7_e.loki_cash()
		if not is_equal_approx(s7_e.loot, 500.0 + float(int(s7_rb["win"]))) or s7_e.alive_count() != 7:
			s7_ok = false
			break
	check(s7_ok and s7_wins > 300 * 170, "Pfandflasche: das Freispiel gewinnt immer, kostet nichts außer der Flasche und kennt keinen Streich (Schnitt %d)" % (s7_wins / 300))
	s7_e.pfand = 1
	s7_e.loki_round = Voyage.LOKI_ROUNDS
	s7_e.loki_pot = 0
	check(s7_e.loki_pick("bottle") and s7_e.loki_can_spin() and not s7_e.loki_pick("loot") and not s7_e.loki_over(), "Pfandflasche: geht auch nach der letzten Runde")
	s7_e.pfand = 0
	s7_e._loki_fix_stake()
	check(s7_e.loki_over() and not s7_e.loki_can_spin(), "Adlersson: ohne Pfandflasche und ohne Runden ist Schluss")
	s7_e.automat_close()
	# der offene Automat hält die Schritte der Begegnung an
	var s6_hold := new_voyage(2107)
	s6_hold.stage = 3
	s6_hold.loot = 300.0
	s6_hold.automat_bonus_on = false
	s6_hold.phase = Voyage.Phase.RESOLVE
	s6_hold._steps = [{"delay": 0.1, "fn": func() -> void: s6_hold.loot += 1.0}]
	s6_hold._step_left = 0.1
	s6_hold.automat_enter("bonus", 20, false)
	s6_hold._process(1.0)
	check(is_equal_approx(s6_hold.loot, 300.0) and s6_hold._steps.size() == 1, "Automat: solange er offen ist, warten die Schritte der Begegnung")
	s6_hold.automat_close()
	s6_hold._process(1.0)
	check(is_equal_approx(s6_hold.loot, 301.0), "Automat: nach dem Schließen laufen sie weiter")

	# --- viele Zufallsfahrten ---
	var wins := 0
	var losses := 0
	var problems := 0
	var total_enc := 0
	for sd in range(60):
		var g := new_voyage(1000 + sd)
		g.max_stage = 3
		var guard := 0
		while not g.ended and guard < 3000:
			guard += 1
			if g.phase == Voyage.Phase.PLAN:
				if randf() < 0.3 and g.crew[0].state == CrewMember.State.ABOARD:
					g.click_crew(g.crew[0])
					g.click_crew(g.crew[randi() % g.crew.size()])
				if not g.perk_offer.is_empty():
					g.choose_perk(randi() % g.perk_offer.size())
				var links := g.next_links()
				g.select_route(int(links[randi() % links.size()]))
				random_dials(g)
				g.confirm()
			elif g.phase == Voyage.Phase.RESCUE:
				g.decide_rescue(randf() < 0.7)
			elif g.phase == Voyage.Phase.ENCOUNTER:
				if g.automat_open:
					play_automat(g)
				else:
					g.decide_encounter(random_tactic(g))
			else:
				g._process(0.5)
			var msg := invariants(g)
			if msg != "":
				problems += 1
				print("   Spiel ", sd, ": ", msg)
				break
		if not g.ended:
			problems += 1
			print("   Spiel ", sd, " endet nicht (Phase ", g.phase, ", Meile ", g.mile, ", Fahrten ", g.turns, ", Proviant ", g.proviant, ", am Leben ", g.alive_count(), ")")
		elif g.victory:
			wins += 1
		else:
			losses += 1
		total_enc += g.encounters_done
	check(problems == 0, "60 Zufallsfahrten ohne Hänger/Inkonsistenz (Siege %d, Niederlagen %d, Begegnungen %d)" % [wins, losses, total_enc])

	_test_route_events()
	_test_storm_difficulty()
	_test_supplies_focus()

	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)


## Ereignisse auf der Strecke: zwischen zwei Knoten, Halt mitten auf dem Weg, Karten wie bei Begegnungen.
func _test_storm_difficulty() -> void:
	# Schwierigkeit: drei Stufen, aufsteigend härter; Startproviant und Vorsprung folgen ihr
	var d: Array = Voyage.DIFFICULTY
	check(d.size() == 3 and float(d[0]["hard"]) < float(d[1]["hard"]) and float(d[1]["hard"]) < float(d[2]["hard"]) and float(d[0]["front"]) < float(d[2]["front"]), "Schwierigkeit: Seebär < Sturm < Ragnarök")
	var food: Array = []
	var gaps: Array = []
	var muls: Array = []
	for i in 3:
		seed(11)
		var v := Voyage.new()
		v.auto_combat = true
		v.difficulty = i
		root.add_child(v)
		v.begin()
		food.append(v.proviant)
		gaps.append(v.front_gap())
		muls.append(v.stage_mul())
		v.free()
	check(int(food[0]) > int(food[1]) and int(food[1]) > int(food[2]) and float(gaps[0]) > float(gaps[2]) and float(muls[0]) < float(muls[2]), "Schwierigkeit: Proviant %s, Vorsprung %s, Härte %s" % [food, gaps, muls])
	# Sturmfront: sie rückt je Wache vor; liegt sie auf dem Schiff, ist die See einen Grad schwerer und die Vorschau sagt es
	seed(12)
	var w := Voyage.new()
	w.auto_combat = true
	root.add_child(w)
	w.begin()
	var calm_plan := w.plan(w.maneuver())
	check(not bool(calm_plan["storm"]) and not w.storm_next(), "Sturmfront: zu Beginn mit Vorsprung %s" % Voyage.fmt(w.front_gap()))
	var sea_calm := int((calm_plan["rows"] as Array)[0]["sea"])
	w.front = w.ship_at()
	var storm_plan := w.plan(w.maneuver())
	var sea_storm := int((storm_plan["rows"] as Array)[0]["sea"])
	check(bool(storm_plan["storm"]) and sea_storm == mini(sea_calm + 1, 5), "Sturmfront: eingeholt, See %d → %d" % [sea_calm, sea_storm])
	var f0 := w.front
	var dd := w.to_dict()
	var w2 := Voyage.new()
	root.add_child(w2)
	w2.resume(dd)
	check(is_equal_approx(w2.front, f0) and w2.difficulty == w.difficulty, "Sturmfront und Schwierigkeit überstehen Speichern und Laden")
	w.free()
	w2.free()


func _test_supplies_focus() -> void:
	seed(21)
	var v := Voyage.new()
	v.auto_combat = true
	root.add_child(v)
	v.begin()
	# Krämer: nur im Hafen, kostet Beute, Höchstmenge
	v.loot = 500.0
	check(not v.buy_supply("teer"), "Vorräte: auf See gibt es keinen Krämer")
	v.shop_open = true
	var bought := 0
	for k in 5:
		if v.buy_supply("teer"):
			bought += 1
	check(bought == Supplies.cap("teer") and is_equal_approx(v.loot, 500.0 - float(bought * Supplies.price(v, "teer"))), "Vorräte: Teerfass bis zur Höchstmenge (%d), Beute passend abgezogen" % bought)
	v.buy_supply("verband")
	v.buy_supply("schnaps")
	v.buy_supply("harpune")
	v.shop_open = false
	# Einsetzen auf See: nur mit Wirkung
	check(v.phase == Voyage.Phase.PLAN and not v.can_use_supply("teer"), "Vorräte: Teer bei heilem Rumpf ohne Wirkung, nicht einsetzbar")
	v.hull = v.hull_max() - 30.0
	var h0 := v.hull
	check(v.use_supply("teer") and is_equal_approx(v.hull, h0 + 15.0) and v.supply("teer") == bought - 1, "Vorräte: Teer gibt Rumpf +15")
	var weak: CrewMember = v.crew[2]
	weak.kraft = 20.0
	check(v.use_supply("verband") and is_equal_approx(weak.kraft, 50.0), "Vorräte: Verband gibt dem Schwächsten Kraft +30")
	for m in v.crew:
		m.stress = 30.0
	check(v.use_supply("schnaps") and is_equal_approx((v.crew[0] as CrewMember).stress, 22.0), "Vorräte: Schnaps senkt die Verzweiflung aller um 8")
	check(not v.use_supply("harpune") and v.supply("harpune") == 1, "Vorräte: die Harpune wirkt nicht von allein")
	# Karten, die Vorräte kosten: ohne Vorrat gesperrt, mit Vorrat verbraucht
	var wal_opt: Dictionary = Encounters.option(Encounters.Id.WAL, 1)
	check(Encounters.available(v, wal_opt), "Vorräte: Harpune an Bord, die Walkarte ist offen")
	v.supplies["harpune"] = 0
	check(not Encounters.available(v, wal_opt), "Vorräte: ohne Harpune ist die Walkarte gesperrt")
	v.supplies["harpune"] = 1
	v._enc_pending = Encounters.Id.WAL
	v._start_encounter()
	v.decide_encounter(1)
	check(v.supply("harpune") == 0, "Vorräte: die Harpune wird beim Wurf verbraucht")
	v._steps.clear()
	# Speichern und Laden
	v.supplies = {"verband": 2, "harpune": 1}
	(v.crew[0] as CrewMember).fokus = 1
	var dd := JSON.parse_string(JSON.stringify(v.to_dict())) as Dictionary
	var v2 := Voyage.new()
	root.add_child(v2)
	v2.resume(dd)
	check(v2.supply("verband") == 2 and v2.supply("harpune") == 1 and v2.supply("teer") == 0 and (v2.crew[0] as CrewMember).fokus == 1, "Vorräte und Fokus überstehen Speichern und Laden")
	v2.queue_free()
	# Fokus: Kampfprobe +15 Punkte (höchstens 95 %), Würfelprobe zwei Würfe; kostet einen Punkt und Verzweiflung
	var opt_f: Dictionary = Encounters.option(Encounters.Id.UNGEHEUER, 0)
	var c0 := Encounters.chance(v, opt_f)
	var c1 := Encounters.chance(v, opt_f, true)
	check(is_equal_approx(c1, minf(c0 + Voyage.FOCUS_BONUS, 0.95)) or c1 == c0, "Fokus: Aussicht %d %% → %d %%" % [roundi(c0 * 100.0), roundi(c1 * 100.0)])
	check(Voyage.focus_applies(opt_f) and not Voyage.focus_applies(Encounters.option(Encounters.Id.TOTENFLOSS, 0)) and not Voyage.focus_applies(Encounters.option(Encounters.Id.TREIBEIS, 0)), "Fokus: greift bei Proben, nicht bei Deckkämpfen und sicheren Karten")
	var bad := 0
	var bad_f := 0
	var sw: Dictionary = Encounters.option(Encounters.Id.STRUDEL, 2)
	seed(3)
	for k in 2000:
		if Encounters.pick(v, sw) != (sw["outcomes"] as Array)[0]:
			bad += 1
		if Encounters.pick(v, sw, true) != (sw["outcomes"] as Array)[0]:
			bad_f += 1
	check(bad > 850 and bad < 1150 and bad_f > 380 and bad_f < 620, "Fokus: zweiter Wurf halbiert das Pech (ohne %d, mit %d von 2000)" % [bad, bad_f])
	for m2 in v.crew:
		m2.fokus = Voyage.FOCUS_MAX
		m2.stress = 0.0
	var total0 := v.focus_total()
	v._enc_pending = Encounters.Id.STRUDEL
	v._start_encounter()
	v.toggle_focus()
	check(v.focus_armed, "Fokus: in der Begegnung angesagt")
	v.decide_encounter(2)
	var stressed := 0
	for m3 in v.crew:
		if m3.fokus == Voyage.FOCUS_MAX - 1 and m3.stress > 0.0:
			stressed += 1
	check(v.focus_total() == total0 - 1 and not v.focus_armed and stressed == 1, "Fokus: ein Punkt verbraucht, Verzweiflung +%d für den, der sich sammelt" % roundi(Voyage.FOCUS_STRESS))
	v._steps.clear()
	v._complete_stage()
	check(v.focus_total() == Voyage.FOCUS_MAX * v.aboard_count(), "Fokus: mit der neuen Etappe wieder voll")
	v.queue_free()


func _test_route_events() -> void:
	# Daten: jede Art hat Hinweis, Gewicht 0 auf Knoten, Skalden-Text, die letzte Option kostet nichts
	var data_ok := true
	var lore_missing: PackedStringArray = []
	for id in range(Encounters.ROUTE_FIRST, Encounters.DATA.size()):
		var def: Dictionary = Encounters.DATA[id]
		if not Encounters.is_route(id) or int(Encounters.WEIGHTS[id]) != 0:
			data_ok = false
		if not Skalde.LINES.has(String(def["intro"])):
			lore_missing.append(String(def["intro"]))
		var opts: Array = def["options"]
		var last: Dictionary = opts[opts.size() - 1]
		if (last.get("cost", {}) as Dictionary).size() > 0 or last.has("formation") or opts.size() > 4:
			data_ok = false
		for o in opts:
			for out in (o as Dictionary).get("outcomes", []):
				var lk := String((out as Dictionary).get("lore", ""))
				if lk != "" and not Skalde.LINES.has(lk):
					lore_missing.append(lk)
	check(data_ok and Encounters.HINTS.size() == Encounters.DATA.size(), "Streckenereignisse: %d Arten, nie auf Knoten, höchstens vier Karten, die letzte kostet nichts" % (Encounters.DATA.size() - Encounters.ROUTE_FIRST))
	check(lore_missing.is_empty(), "Streckenereignisse: der Skalde hat zu jedem Ausgang etwas zu sagen (%s)" % ", ".join(lore_missing))
	var snd_ok := Encounters.ROUTE_SND.size() == Encounters.DATA.size() - Encounters.ROUTE_FIRST
	for sid in Encounters.ROUTE_SND:
		snd_ok = snd_ok and Sfx.GAIN.has(String(Encounters.ROUTE_SND[sid]))
	check(snd_ok, "Streckenereignisse: jede Art hat einen eigenen Klang beim Halt")
	# Würfeln: nur Streckenarten, Totenfloß erst ab Etappe 2, Räuberboote in Piratengewässern häufiger
	seed(5)
	var only_route := true
	var raft1 := 0
	var hooks_n := 0
	var hooks_p := 0
	for k in 600:
		var a := Encounters.random_route_type(1, 0)
		only_route = only_route and Encounters.is_route(a)
		if a == Encounters.Id.TOTENFLOSS:
			raft1 += 1
		if Encounters.random_route_type(3, 0) == Encounters.Id.ENTERHAKEN:
			hooks_n += 1
		if Encounters.random_route_type(3, 3) == Encounters.Id.ENTERHAKEN:
			hooks_p += 1
	check(only_route and raft1 == 0 and hooks_p > hooks_n * 2, "Streckenereignisse: Würfeln nach Etappe und Thema (Enterhaken %d gegen %d in Piratengewässern)" % [hooks_n, hooks_p])
	# Karte: Ereignisse liegen auf echten Wegen, mitten auf der Strecke, höchstens eines je Startknoten
	var placed_ok := true
	var counts: Array[int] = []
	for sd in 12:
		var v := new_voyage(900 + sd)
		var n := 0
		for c in Voyage.MILES:
			for i in (v.map[c] as Array).size():
				var mid: Array = v.node_at(c, i).get("mid", [])
				if mid.size() > 1:
					placed_ok = false
				for ev in mid:
					n += 1
					var links: Array = v.node_at(c, i)["links"]
					if c < 1 or c >= Voyage.MILES - 1 or not links.has(int(ev["to"])) or float(ev["t"]) < 0.3 or float(ev["t"]) > 0.7 or not Encounters.is_route(int(ev["id"])):
						placed_ok = false
		counts.append(n)
		v.free()
	check(placed_ok and counts.min() >= 3, "Streckenereignisse: je Karte %d bis %d, alle auf Wegen zwischen Meile 1 und 9, bei 30 bis 70 %% des Weges" % [counts.min(), counts.max()])
	# Fahrt: das Schiff hält am Ereignis an, der Rest der Strecke verfällt; danach geht es auf demselben Kurs weiter
	var r := new_voyage(950)
	for c in Voyage.MILES:
		for i in (r.map[c] as Array).size():
			r.node_at(c, i)["mid"] = []
	r.mile = 1
	r.pos = 0
	var to := int(r.node_at(1, 0)["links"][0])
	r.node_at(1, 0)["mid"] = [{"to": to, "id": Encounters.Id.TREIBGUT, "t": 0.5, "done": false}]
	quiet_node(r, 2, to, 1)
	r.node_at(2, to)["enc"] = -1
	r.select_route(to)
	r.sail_set = 2
	r.oars_set = 2
	var pr := r.plan()
	check(String(pr["stop"]) == "event" and is_equal_approx(float(pr["leg_after"]), 0.5) and (pr["arrivals"] as Array).is_empty(), "volle Fahrt hält mitten auf dem Weg am Ereignis (Vorschau: Halt bei 50 %)")
	r.confirm()
	run_until_idle(r)
	check(r.phase == Voyage.Phase.ENCOUNTER and r.encounter == Encounters.Id.TREIBGUT and is_equal_approx(r.leg, 0.5) and r.route == to, "Halt: Treibgut als Begegnung, das Schiff liegt bei 50 % auf dem Weg")
	check(bool((r.node_at(1, 0)["mid"] as Array)[0]["done"]), "das Ereignis gilt als erlebt")
	var last_opt := (Encounters.DATA[Encounters.Id.TREIBGUT]["options"] as Array).size() - 1
	r.decide_encounter(last_opt)
	run_until_idle(r)
	check(r.phase == Voyage.Phase.PLAN and is_equal_approx(r.leg, 0.5) and r.route == to, "nach dem Ereignis: Planung, Kurs bleibt gesetzt")
	r.confirm()
	run_until_idle(r)
	check(r.mile >= 2 and r.encounter != Encounters.Id.TREIBGUT, "danach fährt das Schiff weiter, ohne erneut zu halten")
	# Speichern und Laden behalten die Ereignisse
	var sv := new_voyage(960)
	var before := 0
	for c in Voyage.MILES:
		for i in (sv.map[c] as Array).size():
			before += (sv.node_at(c, i).get("mid", []) as Array).size()
	var first_ev: Dictionary = {}
	for c in Voyage.MILES:
		for i in (sv.map[c] as Array).size():
			if first_ev.is_empty() and not (sv.node_at(c, i).get("mid", []) as Array).is_empty():
				first_ev = (sv.node_at(c, i)["mid"] as Array)[0]
				first_ev["done"] = true
	var js: Variant = JSON.parse_string(JSON.stringify(sv.to_dict()))
	var lv := new_voyage(961)
	lv.resume(js as Dictionary)
	var after := 0
	var done_after := 0
	var types_ok := true
	for c in Voyage.MILES:
		for i in (lv.map[c] as Array).size():
			for ev in (lv.node_at(c, i).get("mid", []) as Array):
				after += 1
				if bool(ev["done"]):
					done_after += 1
				types_ok = types_ok and Encounters.is_route(int(ev["id"])) and typeof(ev["id"]) == TYPE_INT
	check(before > 0 and after == before and done_after == 1 and types_ok, "Speichern und Laden: %d Ereignisse, das erlebte bleibt erlebt" % after)
	# Schiffbrüchiger: ein Mann kommt an Bord, wenn Platz ist; sonst Beute
	var cv := new_voyage(970)
	cv.crew[2].state = CrewMember.State.DEAD
	cv.slot_owner[cv.crew[2].slot] = null
	cv.crew[2].slot = -1
	var alive_before := cv.alive_count()
	var offers_before := cv.recruits.size()
	cv._apply_fx({"castaway": 1})
	check(cv.alive_count() == alive_before + 1 and cv.recruits.size() == offers_before, "Schiffbrüchiger: mit Platz kommt ein Mann an Bord, die Anwärter im Hafen bleiben")
	var full := new_voyage(971)
	for k in Voyage.RESERVE_MAX + 2:
		full.reserve.append(CrewMember.new())
		full.reserve.back().state = CrewMember.State.RESERVE
	var loot0 := full.loot
	full._apply_fx({"castaway": 1})
	check(full.loot > loot0, "Schiffbrüchiger: ohne Platz zeigt er sein gesunkenes Schiff (Beute)")
	var sight := new_voyage(972)
	var vis0 := sight.visible_cols()
	sight._apply_fx({"sight": 1})
	check(sight.visible_cols() == vis0 + 1, "Flaschenpost: eine Karte bringt eine Meile mehr Sicht")
