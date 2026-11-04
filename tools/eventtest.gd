extends SceneTree
## Prüft die Ereignisfelder von Combat.events (SPEC 3.1) und die Verträge FightLevel/FightGeo/Voyage.stage_t.
## Aufruf: godot --headless --path . --script tools/eventtest.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		fails += 1
		print("FEHLER: ", what)


func _init() -> void:
	check(FightLevel.of(5, false, false) == FightLevel.GRAZE, "FightLevel 5 = Streifer")
	check(FightLevel.of(10, false, false) == FightLevel.NORMAL, "FightLevel 10 = normal")
	check(FightLevel.of(24, false, false) == FightLevel.HEAVY, "FightLevel 24 = schwer")
	check(FightLevel.of(3, true, false) == FightLevel.CRIT, "FightLevel krit")
	check(FightLevel.of(3, true, true) == FightLevel.KILL, "FightLevel tödlich")
	check(FightLevel.of(30, false, false, true) == FightLevel.GRAZE, "FightLevel Blutung = Streifer")
	for p in [Vector2(100, 50), Vector2(240, 172), Vector2(400, 200)]:
		check(FightGeo.to_screen(p, 1.0, 240.0).distance_to(p) <= 0.5, "to_screen Zoom 1 = Identität %s" % p)
	var foot := Vector2(FightGeo.HERO_X[0], FightGeo.FEET)
	check(FightGeo.rect_to_screen(Rect2(foot - Vector2(20, 60), Vector2(40, 62)), 1.5, 240.0).has_point(FightGeo.to_screen(foot, 1.5, 240.0)), "Fußpunkt liegt im Figurenrechteck bei Zoom 1,5")
	var bad := 0
	for zi in [1.0, 1.125, 1.25, 1.375]:
		for d in [0.05, 0.25, 0.5, 0.75, 1.0]:  # Tiefe > 1 (Vordergrund) kann bei extremem Schwenk 1..16 px Lücke lassen: Befund in BASELINE.md
			for cx in [240.0 / zi, 240.0, 480.0 - 240.0 / zi]:
				var xf := FightGeo.layer_xf(d, zi, cx)
				var r := xf * Rect2(0, 0, 480, 320)
				if r.position.x > 0.5 or r.end.x < 479.5:
					bad += 1
	check(bad == 0, "layer_xf deckt 0..480 (%d Ausnahmen)" % bad)

	var v := Voyage.new()
	v.auto_combat = true
	root.add_child(v)
	v.begin()
	# stage_t: im Schnellmodus wirkungslos, sonst gedeckelt auf 4 s
	var cv := Voyage.new()
	root.add_child(cv)
	cv.begin()
	var pp: Array = []
	for i in 4:
		var m2 := CrewMember.new()
		m2.id = 900 + i
		m2.role = Roles.Id.SCHILD
		m2.kraft = 100.0
		pp.append(m2)
	cv.combat = Combat.create(cv, "draugr", pp, Foes.units_for("draugr", 3), 3)
	cv.combat.begin()
	cv.auto_combat = true
	cv.combat_stage(5.0)
	check(cv.stage_t == 0.0, "combat_stage wirkt im Schnellmodus nicht")
	cv.auto_combat = false
	cv.combat_stage(99.0)
	check(cv.stage_t == 4.0, "combat_stage(99) wird auf 4,0 gedeckelt")
	cv.combat_stage(1.0)
	check(cv.stage_t == 4.0, "combat_stage verkürzt nie")
	cv.combat = null
	cv.free()
	var total := 0
	var errs: PackedStringArray = []
	var li := 0
	for form in ["draugr", "raeuber", "haendler", "dorf", "kraken"]:
		for sd in 40:
			seed(1000 * li + sd)
			var party: Array = []
			var roles := [Roles.Id.SCHILD, Roles.Id.AXT, Roles.Id.BOGEN, Roles.Id.SKALDE]
			for i in 4:
				var m := CrewMember.new()
				m.id = 800 + i
				m.display_name = "P%d" % i
				m.role = roles[i]
				m.kraft = 100.0
				party.append(m)
			var c := Combat.create(v, form, party, Foes.units_for(form, 3), 3)
			c.begin()
			var evs: Array = []
			var last := 0
			var n := 0
			while c.state != "done" and n < 400:
				n += 1
				if c.state == "hero":
					c.auto_hero()
				else:
					c.act_foe()
				for ev in c.events:
					if int(ev["id"]) > last:
						evs.append(ev)
						last = int(ev["id"])
			total += 1
			for e in _audit(evs):
				errs.append("%s/%d: %s" % [form, sd, e])
		li += 1
	check(errs.is_empty(), "%d Kämpfe, Ereignisfelder stimmig (%d Fehler)%s" % [total, errs.size(), ("\n   " + "\n   ".join(errs.slice(0, 8))) if not errs.is_empty() else ""])
	v.free()
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)


func _audit(evs: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var prev_act := 0
	var acts := {}
	var turns := {}
	for i in evs.size():
		var e: Dictionary = evs[i]
		var t := String(e["type"])
		for k in ["act", "rank", "round"]:
			if not e.has(k):
				out.append("Ereignis %s ohne %s" % [t, k])
		if not e.has("by"):
			out.append("Ereignis %s ohne by" % t)
		if e.has("act"):
			if int(e["act"]) < prev_act:
				out.append("act sinkt bei %s (#%d)" % [t, int(e["id"])])
			prev_act = maxi(prev_act, int(e["act"]))
			acts[int(e["act"])] = true
		if t == "attack" and not e.has("tgts"):
			out.append("attack ohne tgts")
		if t == "hit" or t == "heal":
			if not (e.has("hp0") and e.has("hp1")):
				out.append("%s ohne hp0/hp1" % t)
			elif float(e["hp0"]) < float(e["hp1"]) and t == "hit":
				out.append("hit mit hp0 < hp1")
			elif t == "hit" and not bool(e.get("door", false)) and not bool(e.get("lethal", false)) and absf(float(e["hp0"]) - float(e["hp1"]) - float(e["n"])) > 1.0:
				out.append("hit: hp1 != hp0 - n (%s, %s, %s)" % [e["hp0"], e["hp1"], e["n"]])
		if t == "hit" and bool(e.get("lethal", false)):
			var found := false
			for j in range(i + 1, mini(i + 8, evs.size())):
				if String(evs[j]["type"]) == "die" and evs[j]["who"] == e["who"]:
					found = true
					break
			if not found:
				out.append("lethal ohne folgendes die")
		if t == "turn":
			turns[int(e.get("act", 0))] = int(turns.get(int(e.get("act", 0)), 0)) + 1
	for a in turns:
		if int(turns[a]) > 1:
			out.append("mehr als ein turn in Handlung %d" % a)
	return out
