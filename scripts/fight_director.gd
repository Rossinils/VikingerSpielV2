class_name FightDirector
extends RefCounted

## Die Regie des Deckkampfs (SPEC 3.6, D1): schneidet die Ereignisse von Combat.events in Beats (eine Handlung = ein Beat), spielt sie als
## Zeitleiste ab und schreibt, was man sieht, in Anzeigewerte: Figurenbilder, Versatz, Blitz, Licht, Kamera. Die Regeln des Kampfes laufen
## weiter sofort; der Director verzögert nur die Anzeige und hält über `pending_s()` den Gegnerzug an (Voyage.combat_stage).
## Zwei Uhren: Echtzeit (Kamera, Licht, Blitz, Standbild) und Bühnenzeit (Figuren, Wirkungen), die im Standbild steht und in der
## Zeitlupe langsamer läuft. Zeichnet nichts; die Anzeige (hud.gd) liest figs(), camera(), light() und reagiert auf das Signal `cue`.

enum Mode { FULL, SHORT }

signal cue(kind: String, data: Dictionary)

static var instances := 0

const SUBSTEP := 0.004  # Schrittweite der Uhr in Sekunden (Standbild und Zeitlupe auf wenige ms genau)
const MAX_QUEUE_DROP := 6
const WATCHDOG_S := 4.0
const OVER_BUDGET_MS := 6000.0  # Zeitbudget je Kampf: Summe der Überlängen über dem Takt (SPEC 3.9); danach dauert kein Beat mehr als der Takt

var mode: int = Mode.FULL
var manual_clock := false
var ok := true  # false: dem Kampf fehlen die Ereignisfelder, die Regie bleibt stumm

var _cam := FightCam.new()
var _light := FightViews.LightState.new()
var _ui := FightViews.UiState.new()
var _c: Combat = null
var _seen := 0
var _views: Dictionary = {}
var _order: Array = []
var _rows: Array = [[], []]
var _queue: Array = []
var _cur: BeatPlanner.Beat = null
var _bt := 0.0  # Bühnen-ms im laufenden Beat
var _real := 0.0  # Echtzeit-ms im laufenden Beat
var _cue_i := 0
var _frz_i := 0
var _frz := 0.0  # Standbild: verbleibende Echtzeit in s
var _frz_views: Array = []
var _stage_dt := 0.0
var _clock := 0.0
var _release := -1.0
var _armed := false  # ein Ziel wird gesucht: Kamera 1,0
var _valid: Array = []
var _input_actor: Combat.Fighter = null
var _turn: Combat.Fighter = null
var _plan_foes := 0
var _plan_kills := 0
var _plan_kind := ""
var _plan_n := 0
var _over_ms := 0.0
var _slides: Dictionary = {}
var _result := ""
var _flash_stamps: Array = []
var _killcam_done := false
var _played := 0  # abgespielte Beats (Tests)
var _warned := false


func _init(p_mode: int = Mode.FULL, p_manual: bool = false) -> void:
	mode = p_mode
	manual_clock = p_manual
	instances += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		instances -= 1


# --- Lebenslauf ----------------------------------------------------------------------------------------

func begin(c: Combat) -> void:
	end()
	_c = c
	ok = true
	for ev in c.events:
		if not ev.has("act") or not ev.has("by"):
			push_warning("FightDirector: Ereignisse ohne act/by (SPEC 3.1), die Regie bleibt stumm")
			ok = false
			return
	for h in c.heroes:
		_view(h)
	for f in c.foes:
		_view(f)
	_rows = [c.heroes.duplicate(), c.foes.duplicate()]
	_plan_foes = c.foes.size()
	_seen = 0
	var intro := BeatPlanner.Beat.new()
	var boss := c.formation == "kraken"
	intro.kind = "kraken_auftritt" if boss else "kampfbeginn"
	intro.mode = mode
	intro.len_ms = float(BeatPlanner.REAL[intro.kind]) * BeatPlanner.k(mode)
	intro.real_ms = intro.len_ms
	intro.cues.append({"t": 0.0, "kind": "big", "data": {"text": "DER KRAKEN" if boss else "KAMPF",
		"sub": "Fangarme zuerst, dann der Körper" if boss else String(Foes.FORMATIONS[c.formation]["name"]),
		"col": Color(0.9, 0.35, 0.35), "dur": 1.9 if boss else 1.5}})
	if boss:
		intro.cues.append({"t": 0.0, "kind": "lightning", "data": {"strength": 1.0}})
	_queue.append(intro)
	_light.bg = 0.55


func end() -> void:
	_queue.clear()
	_cur = null
	_views.clear()
	_order.clear()
	_rows = [[], []]
	_slides.clear()
	_c = null
	_seen = 0
	_bt = 0.0
	_real = 0.0
	_frz = 0.0
	_frz_views.clear()
	_release = -1.0
	_result = ""
	_cam = FightCam.new()
	_light = FightViews.LightState.new()
	_ui = FightViews.UiState.new()
	_plan_kills = 0
	_plan_kind = ""
	_plan_n = 0
	_over_ms = 0.0
	_armed = false
	_valid.clear()
	_input_actor = null
	_turn = null
	_killcam_done = false
	_warned = false


func camera() -> FightCam:
	return _cam


func light() -> FightViews.LightState:
	return _light


func ui() -> FightViews.UiState:
	return _ui


func stage_dt() -> float:
	return _stage_dt


func busy() -> bool:
	return ok and (_cur != null or not _queue.is_empty())


## Echte Sekunden, die der Director noch braucht; der Hud reicht das an voy.combat_stage() weiter (Obergrenze 4 s dort).
func pending_s() -> float:
	if not ok:
		return 0.0
	var s := 0.0
	if _cur != null:
		s += maxf(_cur.real_ms - _real, 0.0)
	for b in _queue:
		s += (b as BeatPlanner.Beat).real_ms
	return s / 1000.0


func figs() -> Array:
	return _order


func fig(f: Combat.Fighter) -> FightViews.FigView:
	return _view(f)


func current_kind() -> String:
	return _cur.kind if _cur != null else ""


func played() -> int:
	return _played


## Der Mann am Zug und ob ein Ziel gesucht wird (valid: die gültigen Ziele). Der Hud ruft das in jedem Bild.
func set_input(actor: Combat.Fighter, armed: bool, valid: Array) -> void:
	_input_actor = actor
	_valid = valid
	if armed and not _armed:
		_armed = true
		_cam.go(1.0, 240.0, 0.14, FightCam.SINE_IN_OUT)
		_release = -1.0
	elif not armed:
		_armed = false


## Zielwahl (SPEC): leer = nicht am Wählen
func set_selecting(valid_targets: Array) -> void:
	set_input(_input_actor, not valid_targets.is_empty(), valid_targets)


func set_result(res: String) -> void:
	_result = res


## Die Einleitung auslassen (Fertigkeit gewählt, Leertaste): ausblenden in 120 ms
func skip_intro() -> void:
	if _cur != null and (_cur.kind == "kampfbeginn" or _cur.kind == "kraken_auftritt"):
		_cur.len_ms = minf(_cur.len_ms, _bt + 120.0)
		_cur.real_ms = minf(_cur.real_ms, _real + 120.0)
	for b in _queue.duplicate():
		if (b as BeatPlanner.Beat).kind in ["kampfbeginn", "kraken_auftritt"]:
			_queue.erase(b)


# --- Ereignisse -> Beats -----------------------------------------------------------------------------

func feed(c: Combat) -> void:
	if c != _c or not ok:
		return
	var fresh: Array = []
	for ev in c.events:
		if int(ev["id"]) > _seen:
			fresh.append(ev)
	if fresh.is_empty():
		return
	_seen = int(fresh[fresh.size() - 1]["id"])
	for ev in fresh:
		if String(ev["type"]) == "turn":
			_turn = ev["who"]
	if fresh.size() > 24:
		_snap(c)  # ein schnell aufgelöster Kampf läuft erst jetzt auf: nur der Endzustand, still
		return
	var groups: Array = []
	var cur: Array = []
	var cur_act := -1
	for ev in fresh:
		var a := int(ev.get("act", 0))
		if not cur.is_empty() and a != cur_act:
			groups.append(cur)
			cur = []
		cur.append(ev)
		cur_act = a
	if not cur.is_empty():
		groups.append(cur)
	for g in groups:
		var ctx := {"foes_left": _plan_foes, "kills": _plan_kills, "streak": _plan_n if _plan_kind != "" else 0}
		var b := BeatPlanner.plan(g, ctx, mode)
		if b == null:
			continue
		var km := BeatPlanner.k(mode)
		var extra := maxf(b.real_ms - 900.0 * km, 0.0)
		if extra > 0.0 and _over_ms + extra > OVER_BUDGET_MS * km:
			ctx["lean"] = true
			b = BeatPlanner.plan(g, ctx, mode)
			extra = maxf(b.real_ms - 900.0 * km, 0.0)
		_over_ms += extra
		if b.kind == _plan_kind:
			_plan_n += 1
		else:
			_plan_kind = b.kind
			_plan_n = 1
		_plan_foes -= b.foes_dead.size()
		_plan_kills += b.foes_dead.size()
		for e in g:
			if String(e["type"]) == "spawn":
				_plan_foes += 1
		_enqueue(b)


func _enqueue(b: BeatPlanner.Beat) -> void:
	_queue.append(b)
	if _queue.size() > MAX_QUEUE_DROP:
		for q in _queue.duplicate():
			if (q as BeatPlanner.Beat).kind in BeatPlanner.DROPPABLE and _queue.size() > 1:
				_queue.erase(q)
				_apply_end(q)


## Endzustand ohne Beat: gezeigte Kraft, Reihen, Zustände aus dem Kampf übernehmen
func _snap(c: Combat) -> void:
	_queue.clear()
	_cur = null
	_frz = 0.0
	_slides.clear()
	for v in _order.duplicate():
		var f: Combat.Fighter = (v as FightViews.FigView).f
		if not (c.heroes.has(f) or c.foes.has(f)):
			_views.erase(f)
			_order.erase(v)
	for h in c.heroes:
		_sync(h)
	for f in c.foes:
		_sync(f)
	_rows = [c.heroes.duplicate(), c.foes.duplicate()]
	_plan_foes = c.foes.size()
	_cam.go(1.0, 240.0, 0.0)


func _sync(f: Combat.Fighter) -> void:
	var v := _view(f)
	v.shown_hp = f.hp
	v.trail_hp = f.hp
	v.shown_door = f.door
	v.stun = f.stun > 0
	v.alive = true
	v.alpha = 1.0
	v.shown_rank = f.rank
	v.x = FightGeo.fig_x(f.side, f.rank, v.big)


func _apply_end(b: BeatPlanner.Beat) -> void:
	for c in b.contacts:
		var f: Combat.Fighter = c["who"]
		if f == null:
			continue
		var v := _view(f)
		match String(c["kind"]):
			"hit":
				v.shown_hp = float(c["hp1"])
				if bool(c["door"]):
					v.shown_door = true
			"heal":
				v.shown_hp = float(c["hp1"])
	for f in b.foes_dead + b.heroes_dead:
		_die_now(f)
	_apply_moves(b)
	for e in b.evs:
		if String(e["type"]) == "flee" and e["who"] != null:
			_flee_now(e["who"])


## Platztausch und Vorrücken durch Fertigkeiten: `move` meldet je Beteiligtem die neue Reihe (n). Die Figuren gleiten (der vordere hüpft).
func _apply_moves(b: BeatPlanner.Beat) -> void:
	if b.moves_done:
		return
	b.moves_done = true
	var touched := {}
	for e in b.evs:
		if String(e["type"]) != "move":
			continue
		var f: Combat.Fighter = e["who"]
		if f == null:
			continue
		var rows: Array = _rows[f.side]
		var n := int(e.get("n", 0))
		if n < 0 or n >= rows.size():
			continue
		if not rows.has(f):
			continue
		var old_i := rows.find(f)
		var other: Combat.Fighter = rows[n]
		rows[n] = f
		rows[old_i] = other
		touched[f.side] = true
	for side in touched.keys():
		_slide_side(int(side), 0.36)
		for f in _rows[side]:
			var sl := _slides.get(f, {}) as Dictionary
			if not sl.is_empty():
				sl["hop"] = 6.0 if float(sl["to"]) > float(sl["from"]) == (side == 0) else 0.0


func _flee_now(f: Combat.Fighter) -> void:
	var v := _view(f)
	if v.gone_kind != "":
		return
	v.gone_kind = "flee"
	v.gone_t = 0.0
	_rows_remove(f)


func _die_now(f: Combat.Fighter) -> void:
	var v := _view(f)
	if not v.alive:
		return
	v.alive = false
	v.death_t = 0.0
	v.death_kind = "fall"
	v.death_dur = 1.2 if v.big else 0.7
	_rows_remove(f)


# --- Figuren ---------------------------------------------------------------------------------------------

func _view(f: Combat.Fighter) -> FightViews.FigView:
	if _views.has(f):
		return _views[f]
	var v := FightViews.FigView.new()
	v.f = f
	v.big = f.side == 1 and Foes.is_big(f.kind)
	v.shown_rank = f.rank
	v.x = FightGeo.fig_x(f.side, f.rank, v.big)
	v.shown_hp = f.hp
	v.trail_hp = f.hp
	v.shown_door = f.door
	v.stun = f.stun > 0
	_views[f] = v
	_order.append(v)
	return v


func _rows_remove(f: Combat.Fighter) -> void:
	var side := f.side
	(_rows[side] as Array).erase(f)
	_slide_side(side)


func _slide_side(side: int, dur: float = 0.18) -> void:
	var rows: Array = _rows[side]
	for i in rows.size():
		var f: Combat.Fighter = rows[i]
		var v := _view(f)
		var tx := FightGeo.fig_x(side, i, v.big)
		v.shown_rank = i
		var cur := _slides.get(f, {}) as Dictionary
		if (cur.is_empty() and absf(tx - v.x) > 0.5) or (not cur.is_empty() and absf(float(cur["to"]) - tx) > 0.5):
			_slides[f] = {"from": v.x, "to": tx, "t": 0.0, "dur": dur, "hop": 0.0}


func _facing(f: Combat.Fighter) -> float:
	return 1.0 if f.side == 0 else -1.0


# --- Uhr ---------------------------------------------------------------------------------------------------

func tick(real_dt: float) -> void:
	if not ok or _c == null:
		return
	real_dt = minf(real_dt, 0.25)
	_last_dt = real_dt
	_clock += real_dt
	var speed := 1.0
	if _queue.size() > 1:
		speed = minf(1.0 + 0.25 * float(_queue.size() - 1), 1.75)
	var rem := real_dt * speed
	_stage_dt = 0.0
	while rem > 0.0:
		var h := minf(rem, SUBSTEP)
		_step(h)
		rem -= h
	_cam.tick(real_dt)
	_update_slides(real_dt)
	_update_views(real_dt)
	_update_light(real_dt)
	_watchdog()


func _step(h: float) -> void:
	if _cur == null:
		if not _queue.is_empty():
			_start_beat(_queue.pop_front())
		else:
			_stage_dt += h
			if _release > 0.0:
				_release -= h
				if _release <= 0.0:
					_release = -1.0
					if not _armed:
						_cam.go(1.0, 240.0, 0.14, FightCam.SINE_IN_OUT)
			return
	var b := _cur
	_real += h * 1000.0
	var scale := 1.0
	if _frz > 0.0:
		_frz -= h
		scale = 0.0
		if _frz <= 0.0:
			_frz = 0.0
			for v in _frz_views:
				(v as FightViews.FigView).frozen = false
			_frz_views.clear()
	else:
		scale = _slow_factor(b, _bt)
	_stage_dt += h * scale
	_bt += h * scale * 1000.0
	while _cue_i < b.cues.size() and float((b.cues[_cue_i] as Dictionary)["t"]) <= _bt:
		_fire(b.cues[_cue_i])
		_cue_i += 1
	while _frz_i < b.freezes.size() and float((b.freezes[_frz_i] as Array)[0]) <= _bt:
		_begin_freeze(b, float((b.freezes[_frz_i] as Array)[1]))
		_frz_i += 1
	if _bt >= b.len_ms and _frz <= 0.0 and _cue_i >= b.cues.size():
		_end_beat()


func _slow_factor(b: BeatPlanner.Beat, bt: float) -> float:
	for s in b.slows:
		if bt >= float((s as Array)[0]) and bt < float((s as Array)[1]):
			return float((s as Array)[2])
	return 1.0


func _begin_freeze(b: BeatPlanner.Beat, ms: float) -> void:
	if ms <= 0.0:
		return
	_frz = ms / 1000.0
	_frz_views.clear()
	for c in b.contacts:
		if absf(float(c["t"]) - _bt) < 40.0 and String(c["kind"]) == "hit":
			var tv := _view(c["who"])
			tv.frozen = true
			tv.jitter = 1.0
			tv.jitter_hz = 30.0
			_frz_views.append(tv)
	if b.actor != null:
		var av := _view(b.actor)
		av.frozen = true
		av.jitter = 1.0
		av.jitter_hz = 15.0
		_frz_views.append(av)


func _start_beat(b: BeatPlanner.Beat) -> void:
	_cur = b
	_bt = 0.0
	_real = 0.0
	_cue_i = 0
	_frz_i = 0
	_frz = 0.0
	_release = -1.0
	_killcam_done = false
	_played += 1
	if b.kind == "platztausch" or b.kind == "flucht":
		_apply_moves(b)  # der Tausch und die Flucht laufen während des Beats, nicht erst danach
		for e in b.evs:
			if String(e["type"]) == "flee" and e["who"] != null:
				_flee_now(e["who"])
	_camera_for(b)


func _end_beat() -> void:
	var b := _cur
	_apply_end(b)
	_cur = null
	_bt = 0.0
	_real = 0.0
	if _queue.is_empty():
		_release = float(BeatPlanner.T["release"]) / 1000.0
		_resync()


## Wenn nichts mehr wartet: Zustände (betäubt, Schwelle) aus dem Kampf übernehmen
func _resync() -> void:
	if _c == null:
		return
	for h in _c.heroes:
		var v := _view(h)
		v.shown_door = h.door
		v.stun = h.stun > 0
	for f in _c.foes:
		var v2 := _view(f)
		v2.stun = f.stun > 0


func _watchdog() -> void:
	if _cur != null and _real > 2.0 * _cur.real_ms + 600.0:
		_flush("Beat %s hängt (%.0f ms)" % [_cur.kind, _real])
	elif pending_s() > WATCHDOG_S:
		_flush("zu viele wartende Beats (%.1f s)" % pending_s())


func _flush(why: String) -> void:
	if not _warned:
		push_warning("FightDirector: %s, Warteschlange geleert" % why)
		_warned = true
	if _cur != null:
		_apply_end(_cur)
	for q in _queue:
		_apply_end(q)
	_queue.clear()
	_cur = null
	_frz = 0.0
	for v in _frz_views:
		(v as FightViews.FigView).frozen = false
	_frz_views.clear()
	if _c != null:
		_resync()
	_cam.go(1.0, 240.0, 0.14, FightCam.SINE_IN_OUT)


# --- Kamera ----------------------------------------------------------------------------------------------

func _camera_for(b: BeatPlanner.Beat) -> void:
	if mode == Mode.SHORT or _armed or b.actor == null or (b.motion == "none" and b.contacts.is_empty()):
		return
	var tv: FightViews.FigView = null
	for c in b.contacts:
		if c["who"] != null and (c["who"] as Combat.Fighter) != b.actor:
			tv = _view(c["who"])
			break
	var av := _view(b.actor)
	var xa := av.x
	var xt := tv.x if tv != null else av.x
	var w := Vector2(0.6, 0.4) if b.side == 0 else Vector2(0.35, 0.65)
	var focus := w.x * xa + w.y * xt
	var z := FightCam.limit_zoom(b.zoom_want, xa, xt, FightGeo.FEET - FightGeo.top(false), FightGeo.fe())
	if z <= 1.0 and _cam.target_zoom() <= 1.0:
		z = 1.0
		focus = 240.0
	var cz := _cam.target_zoom()
	var cc := _cam.target_center()
	if absf(focus - cc) < 8.0 and absf(z - cz) < 0.04:
		return
	var dur := float(BeatPlanner.T["cam_in_crit"] if b.level >= FightLevel.CRIT else BeatPlanner.T["cam_in"]) / 1000.0
	_cam.go(z, focus, dur, FightCam.CUBIC_OUT if cz <= 1.0 else FightCam.SINE_IN_OUT)


## Todesstoß: die Kamera fährt 150 ms vor dem Kontakt in 300 ms auf 1,375
func _killcam(b: BeatPlanner.Beat, c: Dictionary) -> void:
	if mode == Mode.SHORT or _armed or _killcam_done or b.actor == null:
		return
	_killcam_done = true
	var tv := _view(c["who"])
	var av := _view(b.actor)
	var w := Vector2(0.6, 0.4) if b.side == 0 else Vector2(0.35, 0.65)
	var z := FightCam.limit_zoom(float(BeatPlanner.LEVEL["zoom"][4]), av.x, tv.x, FightGeo.FEET - FightGeo.top(false), FightGeo.fe())
	_cam.go(z, w.x * av.x + w.y * tv.x, float(BeatPlanner.T["cam_in_kill"]) / 1000.0, FightCam.CUBIC_OUT)


# --- Cues ----------------------------------------------------------------------------------------------------

func _fire(cu: Dictionary) -> void:
	var kind := String(cu["kind"])
	var d: Dictionary = cu["data"]
	match kind:
		"turn_pulse":
			_ui.turn_pulse = {"f": d["f"], "t": 0.0}
		"impact":
			_on_impact(d)
		"heal":
			var hv := _view(d["tgt"])
			hv.shown_hp = float(d.get("hp1", hv.shown_hp))
		"die":
			_on_die(d)
		"big":
			_ui.big = {"text": d["text"], "sub": d["sub"], "col": d["col"], "t": 0.0, "dur": d["dur"]}
		"word":
			_on_word(d)
	cue.emit(kind, d)


func _on_impact(d: Dictionary) -> void:
	var tgt: Combat.Fighter = d["tgt"]
	if tgt == null:
		return
	var v := _view(tgt)
	var lv := int(d["level"])
	v.hit_real = 0.0
	v.white_s = float(BeatPlanner.LEVEL["white"][lv]) / 1000.0
	v.red_s = float(BeatPlanner.LEVEL["red"][lv]) / 1000.0
	v.shown_hp = float(d["hp1"])
	v.hit_t = 0.0
	v.hit_level = lv
	v.hit_dir = float(d["dir"])
	if tgt.stun > 0:
		v.stun = true
	var strong := bool(d["first"])
	var sk := 1.0
	if Settings.shake == 1:
		sk = 0.5
	elif Settings.shake == 0:
		sk = 0.0
	if mode == Mode.SHORT:
		sk *= 0.5
	if strong and sk > 0.0:
		_cam.add_shake(float(BeatPlanner.LEVEL["shake_px"][lv]) * sk, float(BeatPlanner.LEVEL["shake_ms"][lv]) / 1000.0, Vector2(float(d["dir"]), 0.0), float(BeatPlanner.LEVEL["trauma"][lv]))
	if lv >= FightLevel.CRIT:
		cue.emit("halo", {"pos": Vector2(v.x, FightGeo.FEET - 38.0), "col": Color(1.0, 0.82, 0.3) if lv == FightLevel.CRIT else Color(1.0, 0.4, 0.3), "radius": float(BeatPlanner.LEVEL["halo_r"][lv]), "dur": float(BeatPlanner.LEVEL["halo_ms"][lv]) / 1000.0})
		if lv == FightLevel.CRIT:
			cue.emit("mood", {"col": Color(1.0, 0.82, 0.3), "amount": 0.18, "dur": 0.12})
		else:
			cue.emit("mood", {"col": Color(0.8, 0.1, 0.1), "amount": 0.25, "dur": 0.4})


func _on_die(d: Dictionary) -> void:
	var f: Combat.Fighter = d["f"]
	if f == null:
		return
	var v := _view(f)
	v.alive = false
	v.death_t = 0.0
	v.death_kind = String(d["kind"])
	v.death_dur = float(BeatPlanner.T["fade_big"] if v.big else BeatPlanner.T["fade"]) / 1000.0
	v.death_dir = float(d["dir"])
	v.shown_hp = 0.0
	_rows_remove(f)


func _on_word(d: Dictionary) -> void:
	var f: Combat.Fighter = d["f"]
	if f == null:
		return
	var ty := String(d["type"])
	if ty == "spawn":
		var v := _view(f)
		v.pop = 0.0
		if not (_rows[f.side] as Array).has(f):
			var rows: Array = _rows[f.side]
			rows.insert(clampi(f.rank, 0, rows.size()), f)
		v.shown_rank = f.rank
		v.x = FightGeo.fig_x(f.side, f.rank, v.big)
	elif ty == "overboard":
		var v2 := _view(f)
		v2.gone_kind = "overboard"
		v2.gone_t = 0.0
		_rows_remove(f)


# --- Anzeigewerte je Bild -----------------------------------------------------------------------------

func _update_slides(dt: float) -> void:
	for f in _slides.keys():
		var s: Dictionary = _slides[f]
		s["t"] = float(s["t"]) + dt
		var u := clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
		var v := _view(f)
		v.x = lerpf(float(s["from"]), float(s["to"]), FightCam.ease_of(FightCam.QUAD_OUT, u))
		v.hop = float(s.get("hop", 0.0)) * sin(PI * u)
		if u >= 1.0:
			v.x = float(s["to"])
			v.hop = 0.0
			_slides.erase(f)


func _update_views(dt: float) -> void:
	for v in _order:
		var fv := v as FightViews.FigView
		fv.frame = ""
		fv.off = Vector2.ZERO
		fv.flash = 0.0
		fv.red = 0.0
		fv.drop = 0.0
		fv.shadow_w = 0.0
		fv.ghosts.clear()
		fv.z = 0
		fv.hit_real += dt
		if fv.hit_t >= 0.0:
			fv.hit_t += _stage_dt
		fv.pop = minf(fv.pop + dt * 2.5, 1.0)
		fv.ready = _input_actor == fv.f and fv.f.side == 0 and _cur == null
		fv.trail_hp = move_toward(fv.trail_hp, fv.shown_hp, maxf(fv.f.hp_max, 1.0) * dt * 0.5) if fv.trail_hp > fv.shown_hp else fv.shown_hp
		if fv.big:
			fv.z = -10
	if _cur != null:
		_pose_beat(_cur)
	for v in _order.duplicate():
		var fv2 := v as FightViews.FigView
		_finish_view(fv2)
	_order.sort_custom(_draw_before)


func _finish_view(v: FightViews.FigView) -> void:
	# Blitz und Rotstich laufen in Echtzeit, auch im Standbild
	if v.hit_real < v.white_s + 0.08:
		v.flash = 1.0 if v.hit_real < v.white_s else clampf(1.0 - (v.hit_real - v.white_s) / 0.08, 0.0, 1.0)
	if v.hit_real < v.red_s:
		v.red = (1.0 - v.hit_real / v.red_s) * 0.85
	if v.frozen:
		var jit := 1.0 if int(_clock * 2.0 * v.jitter_hz) % 2 == 0 else -1.0
		v.off.x += jit * v.jitter
	if not v.alive:
		v.death_t += _stage_dt * 1000.0
		_death_pose(v)
	elif v.gone_kind == "flee":
		v.gone_t += _stage_dt
		var uf := clampf(v.gone_t / 0.6, 0.0, 1.0)
		v.off.x -= 46.0 * uf
		v.alpha = 1.0 - uf
		v.frame = "dodge"
		if uf >= 1.0:
			_remove_view(v)
	elif v.gone_kind == "overboard":
		v.gone_t += _stage_dt
		var u := clampf(v.gone_t / 0.7, 0.0, 1.0)
		v.drop = -60.0 * u
		v.alpha = 1.0 - u
		v.frame = "grab"
		if u >= 1.0:
			_remove_view(v)
	v.drop -= v.hop
	if v.alive and v.pop < 1.0:
		v.alpha *= v.pop
		v.drop += (1.0 - v.pop) * 10.0
	if _result == "win" and v.alive and v.f.side == 0 and _cur == null and v.frame == "":
		v.frame = "cheer_%d" % (int((_clock + float(v.f.rank) * 0.3) / 0.2) % 3)
	if v.alive and v.frame == "" and v.f.side == 0 and v.f.held_by != null and not v.f.held_by.gone and v.gone_kind == "":
		v.frame = "grab"  # vom Fangarm gepackt: die Beine baumeln
		v.drop -= 6.0
	var lt := _target_lit(v)
	v.lit = move_toward(v.lit, lt, (1.0 / 0.14 if lt > v.lit else 1.0 / 0.16) * _last_dt)


var _last_dt := 0.016


## Zeichenreihenfolge: z, dann Männer vor Gegnern, dann hintere Reihen zuerst, zuletzt die Kennung (stabil, kein Flackern)
func _draw_before(a: FightViews.FigView, b: FightViews.FigView) -> bool:
	if a.z != b.z:
		return a.z < b.z
	if a.f.side != b.f.side:
		return a.f.side < b.f.side
	if a.shown_rank != b.shown_rank:
		return a.shown_rank > b.shown_rank
	return a.f.get_instance_id() < b.f.get_instance_id()


func _remove_view(v: FightViews.FigView) -> void:
	_views.erase(v.f)
	_order.erase(v)
	_slides.erase(v.f)


func _death_pose(v: FightViews.FigView) -> void:
	var ms := v.death_t
	var fall: Array = BeatPlanner.T["fall"]
	var f0 := float(fall[0])
	var f1 := f0 + float(fall[1])
	var f2 := f1 + float(fall[2])
	if v.death_kind == "kraken":
		v.frame = "hit_1"
		v.alpha = clampf(1.0 - ms / (v.death_dur * 1000.0), 0.0, 1.0)
		v.drop = (1.0 - v.alpha) * 40.0
	else:
		if ms < f0:
			v.frame = "fall_0"
		elif ms < f1:
			v.frame = "fall_1"
		elif ms < f2:
			v.frame = "fall_2"
		else:
			v.frame = "dead"
		v.off.x = -8.0 * FightCam.ease_of(FightCam.QUAD_OUT, ms / f2)
		if ms > f2:
			var u := clampf((ms - f2) / (v.death_dur * 1000.0), 0.0, 1.0)
			v.alpha = 1.0 - u
			v.drop = 6.0 * u
	v.z = -1
	if ms > f2 + v.death_dur * 1000.0 + 50.0:
		_remove_view(v)


# --- Posen eines Beats ---------------------------------------------------------------------------------------

func _pose_beat(b: BeatPlanner.Beat) -> void:
	if b.actor != null and b.motion != "none" and _views.has(b.actor):
		_pose_actor(b, _view(b.actor))
	for c in b.contacts:
		var f: Combat.Fighter = c["who"]
		if f == null or not _views.has(f):
			continue
		var dt := _bt - float(c["t"])
		if dt < 0.0:
			continue
		var v := _view(f)
		match String(c["kind"]):
			"hit":
				if not bool(c["lethal"]) and v.alive:
					var lv := int(c["level"])
					v.frame = "hit_0" if dt < float(BeatPlanner.T["hit_0"]) else ("hit_1" if dt < float(BeatPlanner.T["hit_0"]) + float(BeatPlanner.T["hit_1"]) else "")
					var rec := float(BeatPlanner.LEVEL["recoil"][lv]) * FightGeo.fe() / 1.6
					var off := 0.0
					if dt < 120.0:
						off = rec * FightCam.ease_of(FightCam.QUAD_OUT, dt / 120.0)
					elif dt < 320.0:
						off = rec * (1.0 - (dt - 120.0) / 200.0)
					v.off.x -= off
					v.z = maxi(v.z, 50)
			"miss":
				if dt < float(BeatPlanner.T["dodge"]):
					v.frame = "dodge"
					v.off.x -= 5.0 * sin(PI * dt / float(BeatPlanner.T["dodge"]))
					v.z = maxi(v.z, 50)


func _pose_actor(b: BeatPlanner.Beat, v: FightViews.FigView) -> void:
	var km := BeatPlanner.k(b.mode)
	var res := _actor_at(b, _bt, km)
	v.frame = String(res[0])
	v.off.x += float(res[1])
	v.z = 100
	v.drop = 2.0 if _bt >= b.t_wind else 0.0
	v.shadow_w = 2.0 if _bt >= b.t_wind else 0.0
	# Nachbilder beim Ausfall
	if b.motion == "melee" and b.lunge > 0.0 and _bt >= b.t_strike and _bt < b.t_strike + 260.0 * km:
		for i in 3:  # drei Nachbilder im Abstand von 35 ms (Alpha 0,30 / 0,18 / 0,10 legt der Zeichner fest)
			var past := _actor_at(b, _bt - 35.0 * float(i + 1), km)
			v.ghosts.append(Vector2(float(past[1]) - float(res[1]), 0.0))


## Bild und Versatz des Handelnden zur Zeit bt: [Bildname, Versatz in px zum Gegner hin]
func _actor_at(b: BeatPlanner.Beat, bt: float, km: float) -> Array:
	var t_w := b.t_wind
	var t_s := b.t_strike
	var fe := FightGeo.fe() / 1.6
	var pre := "ready_0" if b.side == 1 else ""
	if bt < t_w:
		return [pre, 0.0]
	var first_c := t_s
	var last_c := t_s
	for c in b.contacts:
		if String(c["kind"]) != "heal":
			first_c = float(c["t"]) if first_c == t_s else first_c
			last_c = float(c["t"])
	match b.motion:
		"melee":
			var tc := t_s + float(BeatPlanner.T["lunge"]) * km
			var lunge := b.lunge * fe
			if bt < t_s:
				var u := clampf((bt - t_w) / maxf(t_s - t_w, 1.0), 0.0, 1.0)
				return ["windup_0" if u < 0.5 else "windup_1", -3.0 * FightCam.ease_of(FightCam.QUAD_OUT, u)]
			if bt < tc:
				var u2 := clampf((bt - t_s) / maxf(tc - t_s, 1.0), 0.0, 1.0)
				return ["strike_0", lerpf(-3.0, lunge, u2)]
			var tl := maxf(last_c, tc)
			var dt := bt - tl
			if bt < tl:
				return ["strike_1", lunge]
			if dt < 80.0:
				return ["strike_1", lunge]
			if dt < 170.0:
				return ["follow_0", lunge]
			var hold := float(BeatPlanner.T["hold"]) * km
			if dt < hold + 20.0:
				return ["follow_1", lunge]
			var ret := float(BeatPlanner.T["return"]) * km
			var ur := clampf((dt - hold - 20.0) / ret, 0.0, 1.0)
			if ur >= 1.0:
				return ["", 0.0]
			return ["follow_1", lunge * (1.0 - FightCam.ease_of(FightCam.QUAD_OUT, ur))]
		"bow", "gun", "whip":
			var recoil := 4.0 if b.motion == "gun" else (1.0 if b.motion == "bow" else 0.0)
			if bt < t_s:
				var uw := clampf((bt - t_w) / maxf(t_s - t_w, 1.0), 0.0, 1.0)
				return ["windup_0" if uw < 0.5 else "windup_1", 0.0]
			var ds := bt - t_s
			var off := -recoil * fe * (1.0 - clampf(ds / 160.0, 0.0, 1.0))
			if ds < 80.0:
				return ["strike_0", off]
			var tcl := maxf(last_c, t_s + 80.0)
			if bt < tcl:
				return ["strike_1", off]
			var dt2 := bt - tcl
			if dt2 < 150.0:
				return ["follow_0", 0.0]
			if dt2 < 280.0:
				return ["follow_1", 0.0]
			return ["", 0.0]
		"cast":
			var span := maxf(t_s - t_w, 1.0)
			if bt < t_w + span * 0.5:
				return ["cast_0", 0.0]
			if bt < t_s:
				return ["cast_1", 0.0]
			if bt < t_s + 170.0:
				return ["cast_2", 0.0]
			return ["", 0.0]
		"guard":
			if bt < t_s:
				return ["block_0", 0.0]
			if bt < b.len_ms - 120.0:
				return ["block_1" if bt < t_s + 150.0 else "block_0", 0.0]
			return ["", 0.0]
	return ["", 0.0]


# --- Licht -----------------------------------------------------------------------------------------------------

func _target_lit(v: FightViews.FigView) -> float:
	var f := v.f
	if _result == "win":
		return 1.0 if f.side == 0 else 0.0
	if _result == "lose":
		return 0.0
	if _cur != null and (_cur.actor != null or not _cur.contacts.is_empty()):
		var b := _cur
		if f == b.actor:
			return 1.0 if b.side == 0 else 0.78
		for c in b.contacts:
			if c["who"] == f:
				if b.side == 1:
					return 1.0
				return 1.0 if String(c["kind"]) == "heal" or b.motion in ["cast", "guard"] else 0.78
		if b.side == 0:
			return 0.0
		return 0.33 if f.side == 0 else 0.0
	if _armed:
		if f == _input_actor:
			return 1.0
		if _valid.has(f):
			return 0.9
		return 0.0
	if _input_actor != null:
		return 1.0 if f == _input_actor else 0.55
	return 0.7


func _update_light(dt: float) -> void:
	_last_dt = dt
	var bg_t := 1.0
	var vg_t := 0.0
	var foe := false
	if _result == "lose":
		bg_t = 0.5
	elif _result == "win":
		bg_t = 1.0
	elif _cur != null and (_cur.motion != "none" or not _cur.contacts.is_empty()):
		bg_t = 0.8 if _cur.side == 0 else 0.78
		vg_t = 0.10 if _cur.side == 0 else 0.15
		foe = _cur.side == 1
	elif _armed:
		bg_t = 0.92
	elif _input_actor != null:
		bg_t = 0.92
	_light.bg = move_toward(_light.bg, bg_t, dt / 0.16)
	_light.vignette = move_toward(_light.vignette, vg_t, dt / 0.16)
	_light.foe_turn = foe
	# Scheinwerfer unter dem Handelnden
	var spot_t := 0.0
	var spot_f: Combat.Fighter = null
	if _cur != null and _cur.actor != null and _cur.motion != "none":
		spot_f = _cur.actor
		spot_t = 1.0
	elif _input_actor != null and _result == "":
		spot_f = _input_actor
		spot_t = 0.6
	if spot_f != null and _views.has(spot_f):
		var sv := _view(spot_f)
		_light.spot_pos = Vector2(sv.x, FightGeo.FEET)
	_light.spot_amt = move_toward(_light.spot_amt, spot_t, dt / 0.14)
	if _ui.turn_pulse.has("t"):
		_ui.turn_pulse["t"] = float(_ui.turn_pulse["t"]) + dt
	if not _ui.big.is_empty():
		_ui.big["t"] = float(_ui.big["t"]) + dt
		if float(_ui.big["t"]) >= float(_ui.big["dur"]):
			_ui.big = {}
	_light.flicker = 1.0 if (_armed or _input_actor != null) else 0.0


## Prüfhilfe (nur mit manueller Uhr): so viele Echtzeit-Millisekunden vorspulen
func debug_seek(ms: float) -> void:
	var t := 0.0
	while t < ms:
		var step := minf(16.0, ms - t)
		tick(step / 1000.0)
		t += step
