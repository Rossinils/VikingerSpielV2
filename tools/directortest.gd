extends SceneTree
## Prüft die Kampfregie: FightCam, BeatPlanner (Beat-Arten, Zeitleisten), FightDirector (Warteschlange, Standbild, Kamera, Ablauf in
## simulierten Kämpfen). Alles ohne Fenster: Planer und Director sind RefCounted und zeichnen nichts.
## Aufruf: godot --headless --path . --script tools/directortest.gd

var fails := 0
var _id := 0
var _act := 0
var _c: Combat = null


func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		fails += 1
		print("FEHLER: ", what)


func _party(roles: Array) -> Array:
	var party: Array = []
	for i in roles.size():
		var m := CrewMember.new()
		m.id = 700 + i
		m.display_name = "M%d" % i
		m.role = roles[i]
		m.kraft = 100.0
		party.append(m)
	return party


## Ein Ereignis wie Combat._event es meldet (nur die Felder, die der Planer liest)
func ev(type: String, who: Combat.Fighter, n: int = 0, crit: bool = false, sk: String = "", extra: Dictionary = {}) -> Dictionary:
	_id += 1
	var e := {"id": _id, "type": type, "who": who, "n": n, "crit": crit, "sk": sk, "text": "", "act": _act, "by": who, "rank": who.rank, "round": 1}
	for k in extra:
		e[k] = extra[k]
	return e


func hit(who: Combat.Fighter, n: int, crit: bool, sk: String, extra: Dictionary = {}) -> Dictionary:
	var e := {"hp0": who.hp, "hp1": maxf(who.hp - float(n), 0.0), "lethal": false, "door": false, "resist": false}
	for k in extra:
		e[k] = extra[k]
	return ev("hit", who, n, crit, sk, e)


func plan(evs: Array, ctx: Dictionary = {}, mode: int = BeatPlanner.Mode.FULL) -> BeatPlanner.Beat:
	var c2 := {"foes_left": 3, "kills": 1, "streak": 0}
	for k in ctx:
		c2[k] = ctx[k]
	return BeatPlanner.plan(evs, c2, mode)


func _init() -> void:
	_test_cam()
	_test_geo()
	_test_planner()
	_test_director()
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)


# --- FightCam ----------------------------------------------------------------------------------------------

func _test_cam() -> void:
	check(FightCam.limit_zoom(1.375, 210.0, 270.0, 76.0, 1.6) == 1.375, "limit_zoom: Reihe 1 gegen 1 darf auf 1,375")
	check(FightCam.limit_zoom(1.25, 36.0, 444.0, 76.0, 1.6) < 1.25, "limit_zoom: Reihe 4 gegen 4 bleibt unter dem Wunsch")
	check(FightCam.limit_zoom(1.0625, 210.0, 270.0, 76.0, 1.6) == 1.0, "limit_zoom: unter 1,0625 ist 1,0")
	check(FightCam.limit_zoom(1.375, 210.0, 270.0, 30.0, 1.6) < 1.375, "limit_zoom: der Kopf bleibt unter der Kopfzeile")
	var z := FightCam.limit_zoom(1.33, 210.0, 270.0, 76.0, 1.6)
	check(is_equal_approx(z * 8.0, roundf(z * 8.0)), "limit_zoom: Vielfaches von 1/8 (%s)" % z)
	var cam := FightCam.new()
	cam.go(1.25, 280.0, 0.14, FightCam.CUBIC_OUT)
	cam.tick(0.07)
	check(cam.zoom > 1.0 and cam.zoom < 1.25, "Kamera fährt: Mitte der Fahrt liegt dazwischen (%.3f)" % cam.zoom)
	cam.tick(0.1)
	check(is_equal_approx(cam.zoom, 1.25) and is_equal_approx(cam.center_x, 280.0), "Kamera kommt genau an")
	cam.go(1.375, 20.0, 0.0)
	check(cam.center_x >= 240.0 / 1.375 - 0.01, "Brennpunkt wird begrenzt (Bild bleibt in der Bühne)")
	cam.go(1.0, 240.0, 0.0)
	cam.add_shake(6.0, 0.5, Vector2.RIGHT, 1.0)
	cam.tick(0.001)
	check(cam.shake.y == 0.0 and absf(cam.shake.x) >= 1.0, "Wackeln: die ersten Ausschläge laufen entlang der Schlagachse")
	var mx := 0.0
	for i in 40:
		cam.tick(0.01)
		mx = maxf(mx, maxf(absf(cam.shake.x), absf(cam.shake.y)))
	check(mx <= FightCam.SHAKE_MAX and mx >= 1.0, "Wackeln bleibt in Grenzen (%.0f)" % mx)
	for i in 40:
		cam.tick(0.02)
	check(cam.shake == Vector2.ZERO and not cam.shaking(), "Wackeln klingt auf null ab")
	check(cam.shake.x == roundf(cam.shake.x), "Wackeln ist ganzzahlig")


func _test_geo() -> void:
	for zi in [1.0, 1.125, 1.25, 1.375]:
		for cx0 in [240.0, 300.0, 180.0, 20.0, 470.0]:
			var cx := clampf(cx0, 240.0 / zi, 480.0 - 240.0 / zi)  # so begrenzt FightCam.go den Brennpunkt
			var xf := FightGeo.layer_xf(1.0, zi, cx)
			check(absf((xf * Vector2(300.0, FightGeo.FEET)).y - FightGeo.FEET) < 0.51, "Füße bleiben beim Zoomen auf ihrer Zeile (Zoom %s, Mitte %s)" % [zi, cx])
			for shk in [Vector2.ZERO, Vector2(8, 8), Vector2(-8, -8)]:
				var xb := FightGeo.back_xf(zi, cx, shk)
				var ok := (xb * Vector2(0.0, 0.0)).x <= 0.5 and (xb * Vector2(480.0, 0.0)).x >= 479.5 and (xb * Vector2(0.0, 0.0)).y <= 0.5
				if not ok:
					check(false, "Hintergrund deckt das Bild (Zoom %s, Mitte %s, Wackeln %s)" % [zi, cx, shk])
	check(true, "Füße und Hintergrund: Abdeckung bei allen gültigen Kameras geprüft")


# --- BeatPlanner ----------------------------------------------------------------------------------------------

func _test_planner() -> void:
	seed(5)
	var v := Voyage.new()
	root.add_child(v)
	v.begin()
	_c = Combat.create(v, "draugr", _party([Roles.Id.SCHILD, Roles.Id.AXT, Roles.Id.BOGEN, Roles.Id.SKALDE]), Foes.units_for("draugr", 3), 3)
	_c.begin()
	var h := _c.heroes[0]
	var h2 := _c.heroes[1]
	var f0 := _c.foes[0]
	var f1 := _c.foes[1]
	var cases := {}
	# Held, ein Hieb, normal
	_act += 1
	var e1 := [ev("attack", h2, 0, false, "a_hieb", {"tgts": [f0], "tgt": "foe"}), hit(f0, 10, false, "a_hieb")]
	cases["held_nahkampf"] = plan(e1)
	# Held Bogen
	_act += 1
	cases["held_bogen"] = plan([ev("attack", _c.heroes[2], 0, false, "b_schuss", {"tgts": [f0], "tgt": "foe"}), hit(f0, 9, false, "b_schuss")])
	# kritisch
	_act += 1
	cases["held_krit"] = plan([ev("attack", h2, 0, false, "a_hieb", {"tgts": [f0], "tgt": "foe"}), hit(f0, 18, true, "a_hieb")])
	# Fehlschlag
	_act += 1
	cases["fehlschlag"] = plan([ev("attack", h2, 0, false, "a_hieb", {"tgts": [f0], "tgt": "foe"}), ev("miss", f0, 0, false, "a_hieb")])
	# Flaeche 2 und 3
	_act += 1
	cases["flaeche_2"] = plan([ev("attack", h2, 0, false, "a_wirbel", {"tgts": [f0, f1], "tgt": "foes"}), hit(f0, 7, false, "a_wirbel"), hit(f1, 7, false, "a_wirbel")])
	_act += 1
	cases["flaeche_3"] = plan([ev("attack", h2, 0, false, "a_wirbel", {"tgts": [f0, f1, _c.foes[2]], "tgt": "foes"}), hit(f0, 7, false, "a_wirbel"), hit(f1, 7, false, "a_wirbel"), hit(_c.foes[2], 7, false, "a_wirbel")])
	# Hilfe
	_act += 1
	cases["hilfe_ziel"] = plan([ev("attack", _c.heroes[3], 0, false, "k_heil", {"tgts": [h], "tgt": "ally"}), ev("heal", h, 12, false, "k_heil", {"hp0": 60.0, "hp1": 72.0})])
	_act += 1
	cases["hilfe_selbst"] = plan([ev("attack", h, 0, false, "s_wall", {"tgts": [h], "tgt": "self"})])
	_act += 1
	cases["hilfe_alle"] = plan([ev("attack", _c.heroes[3], 0, false, "k_krieg", {"tgts": _c.heroes.duplicate(), "tgt": "allies"})])
	# Gegner trifft Mann
	_act += 1
	cases["gegner_nahkampf"] = plan([ev("attack", f0, 0, false, "f_hieb", {"tgts": [h], "tgt": "hero"}), hit(h, 9, false, "f_hieb")])
	_act += 1
	cases["gegner_krit"] = plan([ev("attack", f0, 0, false, "f_hieb", {"tgts": [h], "tgt": "hero"}), hit(h, 18, true, "f_hieb")])
	# Gegner faellt (nicht der letzte, nicht der erste Tod: klein), erster Tod: gross
	_act += 1
	cases["gegner_faellt_klein"] = plan([ev("attack", h2, 0, false, "a_hieb", {"tgts": [f0], "tgt": "foe"}), hit(f0, 30, false, "a_hieb", {"lethal": true}), ev("die", f0)], {"kills": 1})
	_act += 1
	cases["gegner_faellt_gross"] = plan([ev("attack", h2, 0, false, "a_hieb", {"tgts": [f0], "tgt": "foe"}), hit(f0, 30, false, "a_hieb", {"lethal": true}), ev("die", f0)], {"kills": 0})
	_act += 1
	cases["letzter_gegner"] = plan([ev("attack", h2, 0, false, "a_hieb", {"tgts": [f0], "tgt": "foe"}), hit(f0, 30, false, "a_hieb", {"lethal": true}), ev("die", f0)], {"foes_left": 1})
	_act += 1
	cases["mann_faellt"] = plan([ev("attack", f0, 0, false, "f_hieb", {"tgts": [h], "tgt": "hero"}), hit(h, 30, false, "f_hieb", {"lethal": true}), ev("die", h)])
	_act += 1
	cases["schwelle_erreicht"] = plan([ev("attack", f0, 0, false, "f_hieb", {"tgts": [h], "tgt": "hero"}), hit(h, 20, false, "f_hieb", {"door": true})])
	_act += 1
	cases["schwelle_haelt"] = plan([ev("attack", f0, 0, false, "f_hieb", {"tgts": [h], "tgt": "hero"}), hit(h, 20, false, "f_hieb", {"door": true, "resist": true})])
	_act += 1
	cases["blutung"] = plan([hit(f0, 3, false, "", {"dot": true})])
	_act += 1
	cases["heldenmut"] = plan([ev("heroic", h, 0, false, "", {"text": "Wut"})])
	_act += 1
	cases["zusammenbruch"] = plan([ev("snap", h, 0, false, "", {"text": "Panik"})])
	_act += 1
	cases["platztausch"] = plan([ev("move", h, 1, false, "", {"rank": 0}), ev("move", h2, 0, false, "", {"rank": 1})])
	_act += 1
	cases["abwarten"] = plan([ev("wait", h)])
	_act += 1
	cases["flucht"] = plan([ev("flee", f0)])
	_act += 1
	cases["ausgesetzt"] = plan([ev("skip", h, 0, false, "", {"text": "betäubt"})])
	_act += 1
	cases["beschwoeren"] = plan([ev("spawn", f0, 0, false, "", {"text": "beschworen"})])
	var all_ok := true
	var bad: PackedStringArray = []
	var worst_len := 0.0
	var exact_bad: PackedStringArray = []
	var overlong := {}
	for kind in cases.keys():
		var b: BeatPlanner.Beat = cases[kind]
		if b == null:
			all_ok = false
			bad.append("%s: kein Beat" % kind)
			continue
		if b.kind != kind:
			# schwelle und mann_faellt_schwelle teilen sich Zeiten, sonst muss die Art stimmen
			all_ok = false
			bad.append("%s statt %s" % [b.kind, kind])
		var want := float(BeatPlanner.REAL[kind])
		if absf(b.real_ms - want) > 3.0:
			exact_bad.append("%s %.0f statt %.0f" % [kind, b.real_ms, want])
		worst_len = maxf(worst_len, b.real_ms)
		if b.real_ms > 900.0 + 3.0 and not (kind in BeatPlanner.LONG_KINDS):
			overlong[kind] = b.real_ms
		var q := plan([], {})
		check(q == null, "leere Handlung ergibt keinen Beat") if kind == "blutung" else null
	check(all_ok, "Beat-Arten werden richtig erkannt (%s)" % ", ".join(bad))
	check(exact_bad.is_empty(), "Echtzeit-Dauer je Art = Tabelle ±3 ms (%s)" % ", ".join(exact_bad))
	check(overlong.is_empty(), "nur Tabellenfälle dauern länger als der Takt (%s)" % str(overlong))
	check(worst_len <= 2600.0, "kein Beat über 2,6 s (längster %.0f ms)" % worst_len)
	# Kurzfassung: halbiert, kein Zoom, keine Zeitlupe, Standbild höchstens 40 ms
	var bs := plan(e1, {}, BeatPlanner.Mode.SHORT)
	check(absf(bs.real_ms - 450.0) <= 3.0, "kurz: Hieb 450 ms (%.0f)" % bs.real_ms)
	var bk := plan([ev("attack", h2, 0, false, "a_hieb", {"tgts": [f0], "tgt": "foe"}), hit(f0, 18, true, "a_hieb")], {}, BeatPlanner.Mode.SHORT)
	check(bk.zoom_want == 1.0 and bk.slows.is_empty(), "kurz: kein Zoom, keine Zeitlupe")
	var fmax := 0.0
	for fz in bk.freezes:
		fmax = maxf(fmax, float(fz[1]))
	check(fmax <= 40.0, "kurz: Standbild höchstens 40 ms")
	# Stufen
	var bn: BeatPlanner.Beat = cases["held_nahkampf"]
	var bc: BeatPlanner.Beat = cases["held_krit"]
	check(bn.freezes.size() == 1 and absf(float(bn.freezes[0][1]) - 80.0) < 0.1, "normaler Hieb: Standbild 80 ms")
	check(absf(float(bc.freezes[0][1]) - 150.0) < 0.1 and bc.slows.size() == 1 and absf(float(bc.slows[0][2]) - 0.5) < 0.01, "Krit: Standbild 150 ms, Zeitlupe 0,5")
	check(bc.zoom_want == 1.25 and bn.zoom_want == 1.125, "Zoom-Wunsch: Krit 1,25, Hieb 1,125")
	var bg: BeatPlanner.Beat = cases["gegner_nahkampf"]
	check(absf(float(bg.freezes[0][1]) - 60.0) < 0.1, "ein Mann empfängt: Standbild 60 ms")
	var bm: BeatPlanner.Beat = cases["mann_faellt"]
	check(bm.slows.size() == 2 and absf(float(bm.slows[0][2]) - 0.35) < 0.01 and absf(float(bm.slows[1][2]) - 0.3) < 0.01, "Mann fällt: Zeitlupe 0,35 davor, 0,3 danach")
	check(bm.zoom_want == 1.375, "Mann fällt: Zoom 1,375")
	var bl: BeatPlanner.Beat = cases["flaeche_3"]
	check(bl.freezes.size() == 3 and float(bl.freezes[1][1]) < float(bl.freezes[0][1]), "Fläche: weitere Treffer mit kürzerem Standbild")
	# Ermüdung: dritte gleichartige Handlung in Folge
	var tired := plan(e1, {"streak": 2})
	check(tired.real_ms < bn.real_ms - 20.0 and tired.real_ms > bn.real_ms * 0.8, "Ermüdung: Nachwirkung 20 %% kürzer (%.0f statt %.0f)" % [tired.real_ms, bn.real_ms])
	# Reihenfolge der Cues und Kontakte
	var seq_ok := true
	for kind in cases.keys():
		var b2: BeatPlanner.Beat = cases[kind]
		var last := -1.0
		for cu in b2.cues:
			if float(cu["t"]) < last:
				seq_ok = false
			last = float(cu["t"])
	check(seq_ok, "Cues stehen in zeitlicher Reihenfolge")
	var gocue: Dictionary = {}
	for cu in bn.cues:
		if String(cu["kind"]) == "go":
			gocue = cu["data"]
	check(not gocue.is_empty() and float(gocue["contact_in"]) > 0.0 and (gocue["contacts"] as Array).size() == 1, "go-Cue nennt Kontaktzeit und Ziele")
	v.free()


# --- FightDirector ----------------------------------------------------------------------------------------------

func _fight(form: String, sd: int, mode: int) -> Dictionary:
	seed(sd * 31 + 7)
	var v := Voyage.new()
	root.add_child(v)
	v.begin()
	var party := _party([Roles.Id.SCHILD, Roles.Id.AXT, Roles.Id.BOGEN, Roles.Id.SKALDE])
	var c := Combat.create(v, form, party, Foes.units_for(form, 3), 3)
	c.begin()
	var d := FightDirector.new(mode, true)
	d.begin(c)
	var stat := {"over": 0.0, "max_beat": 0.0, "max_pending": 0.0, "zoom_max": 1.0, "zoom_min": 1.0, "bad_frame": 0, "impacts": 0, "hits": 0, "dies": 0, "deaths": 0,
		"beats": 0, "snaps": 0, "intro": 0.0, "acts": 0, "busy_end": false, "hp_ok": true, "negative_dt": false}
	d.cue.connect(func(kind: String, _data: Dictionary) -> void:
		if kind == "impact" and not bool(_data["dot"]):
			stat["impacts"] = int(stat["impacts"]) + 1
		if kind == "die":
			stat["dies"] = int(stat["dies"]) + 1)
	var n := 0
	var last_seen := 0
	while c.state != "done" and n < 300:
		n += 1
		if c.state == "hero":
			c.auto_hero()
		else:
			c.act_foe()
		for e in c.events:
			if int(e["id"]) > last_seen:
				last_seen = int(e["id"])
				if String(e["type"]) == "hit" and not bool(e.get("dot", false)):
					stat["hits"] = int(stat["hits"]) + 1
				if String(e["type"]) == "die":
					stat["deaths"] = int(stat["deaths"]) + 1
		d.feed(c)
		stat["max_pending"] = maxf(float(stat["max_pending"]), d.pending_s())
		var queued: Array = d._queue
		for b in queued:
			var bb := b as BeatPlanner.Beat
			stat["beats"] = int(stat["beats"]) + 1
			if bb.kind == "kampfbeginn" or bb.kind == "kraken_auftritt":
				stat["intro"] = bb.real_ms
			else:
				stat["over"] = float(stat["over"]) + maxf(bb.real_ms - 900.0 * BeatPlanner.k(mode), 0.0)
				stat["max_beat"] = maxf(float(stat["max_beat"]), bb.real_ms)
		var steps := int(d.pending_s() * 1000.0 / 16.0) + 12
		for i in steps:
			d.tick(0.016)
			stat["zoom_max"] = maxf(float(stat["zoom_max"]), d.camera().zoom)
			stat["zoom_min"] = minf(float(stat["zoom_min"]), d.camera().zoom)
			for fv in d.figs():
				var fr := (fv as FightViews.FigView).frame
				if fr != "" and not (fr in FigAtlas.FRAMES):
					stat["bad_frame"] = int(stat["bad_frame"]) + 1
			if d.stage_dt() < 0.0:
				stat["negative_dt"] = true
	# ausspielen
	for i in 400:
		d.tick(0.016)
	stat["busy_end"] = d.busy()
	stat["zoom_end"] = d.camera().zoom
	stat["acts"] = n
	for hh in c.heroes:
		var hv := d.fig(hh)
		if absf(hv.shown_hp - hh.hp) > 0.01:
			stat["hp_ok"] = false
	for ff in c.foes:
		var fvv := d.fig(ff)
		if absf(fvv.shown_hp - ff.hp) > 0.01:
			stat["hp_ok"] = false
	d.end()
	v.free()
	return stat


func _test_director() -> void:
	var before := FightDirector.instances
	var worst_over := 0.0
	var worst_beat := 0.0
	var worst_pending := 0.0
	var zmax := 1.0
	var zmin := 1.0
	var bad_frames := 0
	var busy_left := 0
	var hp_bad := 0
	var impact_diff := 0
	var die_diff := 0
	var dt_bad := 0
	var fights := 0
	var zoom_end_bad := 0
	for form in ["draugr", "raeuber", "haendler", "dorf", "kraken"]:
		for sd in 8:
			var st := _fight(form, sd, FightDirector.Mode.FULL)
			fights += 1
			worst_over = maxf(worst_over, float(st["over"]))
			worst_beat = maxf(worst_beat, float(st["max_beat"]))
			worst_pending = maxf(worst_pending, float(st["max_pending"]))
			zmax = maxf(zmax, float(st["zoom_max"]))
			zmin = minf(zmin, float(st["zoom_min"]))
			bad_frames += int(st["bad_frame"])
			if bool(st["busy_end"]):
				busy_left += 1
			if not bool(st["hp_ok"]):
				hp_bad += 1
			if int(st["impacts"]) != int(st["hits"]):
				impact_diff += 1
			if int(st["dies"]) != int(st["deaths"]):
				die_diff += 1
			if bool(st["negative_dt"]):
				dt_bad += 1
			if absf(float(st["zoom_end"]) - 1.0) > 0.001:
				zoom_end_bad += 1
	check(worst_over <= 6000.0, "%d Kämpfe: Summe der Überlängen je Kampf höchstens 6,0 s (größte %.1f s)" % [fights, worst_over / 1000.0])
	check(worst_beat <= 2600.0, "kein Beat über 2,6 s (längster %.0f ms)" % worst_beat)
	check(worst_pending <= 4.0, "pending_s bleibt unter 4,0 s (größter Wert %.2f)" % worst_pending)
	check(zmax <= 1.375 + 0.001 and zmin >= 1.0 - 0.001, "Zoom bleibt zwischen 1,0 und 1,375 (%.3f .. %.3f)" % [zmin, zmax])
	check(zoom_end_bad == 0, "nach dem Kampf steht die Kamera wieder auf 1,0")
	check(bad_frames == 0, "jedes gemeldete Bild ist ein bekannter Name")
	check(busy_left == 0, "nach dem Ausspielen ist die Regie fertig")
	check(hp_bad == 0, "gezeigte Kraft = tatsächliche Kraft nach dem Ausspielen")
	check(impact_diff == 0, "jeder Treffer wird genau einmal gezeigt (impact-Cue je hit)")
	check(die_diff == 0, "jeder Tod wird genau einmal gezeigt (die-Cue je die)")
	check(dt_bad == 0, "die Bühnenzeit läuft nie rückwärts")
	# Kurzfassung: nie Zoom, Zeiten halb
	var short_zoom := 1.0
	var short_over := 0.0
	for sd in 4:
		var ss := _fight("draugr", sd, FightDirector.Mode.SHORT)
		short_zoom = maxf(short_zoom, float(ss["zoom_max"]))
		short_over = maxf(short_over, float(ss["over"]))
	check(short_zoom == 1.0, "kurz: die Kamera bleibt auf 1,0")
	check(short_over <= 3000.0, "kurz: Überlängen höchstens halb so groß")
	# Genauigkeit der Uhr: ein Hieb dauert 900 ms ±8
	seed(3)
	var v := Voyage.new()
	root.add_child(v)
	v.begin()
	var c := Combat.create(v, "draugr", _party([Roles.Id.AXT, Roles.Id.SCHILD, Roles.Id.BOGEN, Roles.Id.SKALDE]), Foes.units_for("draugr", 3), 3)
	c.begin()
	var d := FightDirector.new(FightDirector.Mode.FULL, true)
	d.begin(c)
	d.skip_intro()
	for i in 200:
		d.tick(0.016)
	check(not d.busy(), "die Einleitung ist ausgespielt")
	_act = 5000
	_c = c
	var h := c.heroes[0]
	var f0 := c.foes[0]
	var evs: Array = [ev("attack", h, 0, false, "a_hieb", {"tgts": [f0], "tgt": "foe"}), hit(f0, 10, false, "a_hieb")]
	c.events.append_array(evs)
	d.feed(c)
	check(d.busy() and absf(d.pending_s() - 0.9) < 0.005, "ein Hieb meldet 0,9 s")
	var t_ms := 0.0
	while d.busy() and t_ms < 3000.0:
		d.tick(0.001)
		t_ms += 1.0
	check(absf(t_ms - 900.0) <= 8.0, "ein Hieb dauert 900 ms in Echtzeit (%.0f)" % t_ms)
	# Standbild: die Bühnenuhr steht, während die Echtzeit läuft
	c.events.clear()
	c.events.append_array([ev("attack", h, 0, false, "a_hieb", {"tgts": [f0], "tgt": "foe"}), hit(f0, 10, false, "a_hieb")])
	d.feed(c)
	var froze := false
	var stage_sum := 0.0
	var real_sum := 0.0
	while d.busy() and real_sum < 3.0:
		d.tick(0.001)
		real_sum += 0.001
		stage_sum += d.stage_dt()
		if d._frz > 0.0 and d.stage_dt() == 0.0:
			froze = true
	check(froze, "im Standbild läuft die Bühnenzeit nicht")
	check(absf((real_sum - stage_sum) - 0.080) < 0.012, "Bühnenzeit ist um das Standbild (80 ms) kürzer (%.0f ms)" % ((real_sum - stage_sum) * 1000.0))
	# Warteschlange: mehr als 6 wartende Beats, ablösbare fallen weg; Watchdog hält pending unter 4 s
	for i in 10:
		_act += 1
		c.events.append_array([ev("attack", h, 0, false, "s_wall", {"tgts": [h], "tgt": "self"})])
	d.feed(c)
	check(d._queue.size() <= 7, "Warteschlange: ablösbare Beats fallen bei mehr als 6 wartenden weg (%d)" % d._queue.size())
	for i in 600:
		d.tick(0.016)
	check(not d.busy() and d.pending_s() == 0.0, "die Warteschlange läuft leer")
	# viele frische Ereignisse auf einmal: nur Endzustand
	c.events.clear()
	for i in 30:
		_act += 1
		c.events.append_array([ev("attack", h, 0, false, "s_wall", {"tgts": [h], "tgt": "self"})])
	d.feed(c)
	check(not d.busy(), "mehr als 24 frische Ereignisse: keine Beats, nur Endzustand")
	# Selbstprüfung: fehlende Ereignisfelder
	var d2 := FightDirector.new(FightDirector.Mode.FULL, true)
	var c3 := Combat.create(v, "draugr", _party([Roles.Id.SCHILD]), Foes.units_for("draugr", 3), 3)
	c3.events.append({"id": 1, "type": "turn", "who": c3.heroes[0], "n": 1, "crit": false, "sk": "", "text": ""})
	d2.begin(c3)
	check(not d2.ok and not d2.busy() and d2.pending_s() == 0.0, "Ereignisse ohne act: die Regie bleibt stumm und blockiert nie")
	d2.end()
	d.end()
	v.free()
	d = null
	d2 = null
	check(FightDirector.instances == before, "Director-Zähler: alle freigegeben (%d)" % FightDirector.instances)
