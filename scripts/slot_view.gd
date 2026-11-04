class_name SlotView
extends RefCounted

## Anzeige und Ablauf der Spielautomaten über allem (Regeln: scripts/slots.gd, Einbindung: scripts/voyage.gd).
## Der Hud ruft tick() und draw() auf. Die Ergebnisse stehen schon fest, wenn die Walzen losdrehen; hier wird nur
## inszeniert: Walzenlauf mit Auslaufen und Nachfedern, Spannung vor der dritten Blitzrune, Gewinnlinien,
## Blitzschlag, Stapel und Power-Up im Freispiel, Münzregen und die Szene "Es lebt!".
## Klickt man während des Ablaufs, läuft er schneller.

enum St { IDLE, SPIN, EVAL, ALIVE, PAUSE, SUMMARY, FLIP, CURSE }

const GOLD := Color("e3b94a")
const GOLD_D := Color("8a6a22")
const PAPER := Color("e6e0cc")
const DIM := Color("a3a9b0")
const INK := Color("0d0b10")
const GREEN := Color("62e0a0")
const GREEN_D := Color("2c8a62")
const RED := Color("d2564b")
const VIOLET := Color("6b3f96")
const VIOLET_D := Color("1b1030")
const ZAP := Color("bfe9ff")

const NORN_X0 := 140.0
const NORN_Y0 := 62.0
const NORN_CELL := 38.0
const LOKI_X0 := 90.0
const LOKI_Y0 := 56.0
const LOKI_CELL := 46.0
const VIEW := Vector2(480.0, 320.0)
const COIN_ROW := 32.0
const ALIVE_LEN := 4.7  # Dauer der Szene "It's alive!" (der Schrei in slot_alive.wav ist rund 4 s lang, die Stimme beginnt nach 0,5 + 0,55 s)
const ALIVE_SHOUT2 := 2.7  # Beginn des zweiten Schreis

var voy: Voyage
var tex: Texture2D
var machine := "norn"
var cols := 5
var cell := NORN_CELL
var x0 := NORN_X0
var y0 := NORN_Y0

var st := St.IDLE
var t := 0.0  # Zeit im aktuellen Abschnitt
var time := 0.0  # Uhr für Lampen und Flimmern
var fast := false
var spin_t := 100.0  # Zeit seit Beginn des Walzenlaufs
var res: Dictionary = {}
var grid: Array = []
var rs: Array = []
var tease: Array[int] = []
var tease_start: Dictionary = {}
var last_stop := 0.0
var hidden: Dictionary = {}  # "walze,reihe" -> Symbol, das bis zum Blitzschlag gezeigt wird
var pulse: Dictionary = {}  # "walze,reihe" -> Restzeit des Aufleuchtens
var lines_shown: Array = []
var line_idx := -1
var all_marked := false
var mult_shown := 1
var m_stack := 0
var m_pu := 0
var win_shown := 0.0
var win_target := 0
var count_rate := 0.0
var spin_win := 0  # Anzeige "Gewinn": was die Folge bisher gebracht hat
var banner := ""
var banner_sub := ""
var banner_t := -1.0
var banner_col := GOLD
var shake := 0.0
var flash := 0.0
var flash_col := Color.WHITE
var particles: Array = []
var bolts: Array = []
var floaters: Array = []
var _events: Array = []
var alive_t := -1.0
var status := ""
var flip_ok := false
var flip_t := -1.0
var curse_text := ""
var reward_text := ""
var _spin_snd := 0.0
var _tease_snd := 0.0
var _free_started := false
var _coin_sound_t := 0.0
var _rng := RandomNumberGenerator.new()


func _init(v: Voyage) -> void:
	voy = v
	_rng.randomize()
	if DisplayServer.get_name() != "headless":
		tex = load("res://assets/slots.png")
	machine = "loki" if v.automat_kind == "loki" else "norn"
	cols = 3 if machine == "loki" else 5
	cell = LOKI_CELL if machine == "loki" else NORN_CELL
	x0 = LOKI_X0 if machine == "loki" else NORN_X0
	y0 = LOKI_Y0 if machine == "loki" else NORN_Y0
	grid = _random_grid()
	_set_static(grid)
	spin_t = 100.0


func busy() -> bool:
	return st != St.IDLE


## Für Screenshots: eine Szene ohne Spiel zeigen (siehe --shotslot in main.gd). Die Werte stehen im Spiel schon fest.
func demo(pose: String) -> void:
	match pose:
		"spin":
			_begin_spin(voy.automat_spin() if machine == "norn" else voy.loki_spin())
			t = 0.6
			spin_t = 0.6
		"win":
			var r := _demo_spin()
			for k in 300:
				if int(r["win"]) >= 3 * voy.automat.bet / 2 and (r["lines"] as Array).size() >= 2:
					break
				r = _demo_spin()
			_settle(r)
			t = 0.9
		"alive":
			voy.automat.force_trigger = true
			_settle(_demo_spin())
			_events.clear()
			_begin_alive()
			t = 1.6
			alive_t = 1.6
		"free":
			voy.automat.force_trigger = true
			_demo_spin()
			voy.automat.free_left = 30
			var r3 := _demo_spin()
			for k in 600:
				if not (r3["stacks"] as Array).is_empty() or int(r3["powerup"]) > 0:
					break
				r3 = _demo_spin()
			_settle(r3)
			t = 1.7
		"jackpot":
			banner = "ODINS JACKPOT"
			banner_sub = "Fünf Augen auf einer Linie"
			banner_t = 0.5
			banner_col = GOLD
			win_target = 1840
			win_shown = 1840.0
			spin_win = 1840
			_burst_coins(60)
			flash = 0.5
			shake = 0.6
		"bottle":
			_settle(voy.loki_spin())
			t = 1.0
		"loki_win":
			var r4 := _demo_loki()
			for k in 200:
				if voy.loki_pot > 0:
					break
				r4 = _demo_loki()
			_settle(r4)
			t = 2.5
		"loki_curse":
			var r5 := _demo_loki()
			for k in 900:
				if bool(r5["curse"]):
					break
				r5 = _demo_loki()
			_settle(r5)
			t = 1.4


## Dreh für die Demo: ohne Grenzen für Drehs und Beute.
func _demo_spin() -> Dictionary:
	voy._harbor_spins = 0
	if not voy.automat.in_free():
		voy.loot = maxf(voy.loot, 600.0)
	return voy.automat_spin()


func _demo_loki() -> Dictionary:
	voy.loki_round = 0
	voy.loki_pot = 0
	voy.loot = maxf(voy.loot, 600.0)
	voy.hull = maxf(voy.hull, 80.0)
	return voy.loki_spin()


## Ein Ergebnis ohne Walzenlauf zeigen (für die Szenen von demo()).
func _settle(r: Dictionary) -> void:
	_begin_spin(r)
	spin_t = 10.0
	for rr in rs:
		(rr as Dictionary)["stopped"] = true
	_enter_eval()


# --- Ablauf ---------------------------------------------------------------------

func _random_grid() -> Array:
	var g: Array = []
	for c in cols:
		var col: Array = []
		for r in 3:
			col.append(_filler())
		g.append(col)
	return g


func _filler() -> int:
	if machine == "loki":
		return [3, 9, 4, 5, 7, 10][_rng.randi() % 6]
	return _rng.randi() % 8


func _set_static(g: Array) -> void:
	rs.clear()
	for c in cols:
		rs.append({"strip": (g[c] as Array).duplicate(), "d": 0, "ts": 0.0, "stopped": true})


func _sched(at: float, fn: Callable) -> void:
	_events.append({"at": at, "fn": fn})


func _run_events() -> void:
	var keep: Array = []
	for ev in _events:
		if t >= float((ev as Dictionary)["at"]):
			((ev as Dictionary)["fn"] as Callable).call()
		else:
			keep.append(ev)
	_events = keep


## Der Spieler dreht (Klick, Leertaste).
func spin() -> void:
	if st != St.IDLE:
		fast = true
		return
	var r: Dictionary = {}
	if machine == "loki":
		r = voy.loki_spin()
	else:
		r = voy.automat_spin()
	if r.is_empty():
		return
	spin_win = 0
	m_stack = 0
	m_pu = 0
	mult_shown = 1
	_begin_spin(r)


func _begin_spin(r: Dictionary) -> void:
	res = r
	st = St.SPIN
	t = 0.0
	spin_t = 0.0
	_events.clear()
	lines_shown = []
	line_idx = -1
	all_marked = false
	win_shown = 0.0
	win_target = 0
	status = ""
	reward_text = ""
	curse_text = ""
	_free_started = bool(r["free"])
	var fin: Array = r["grid"]
	var old: Array = grid
	var scat := 0
	tease = []
	tease_start = {}
	rs.clear()
	var prev_ts := 0.0
	for c in cols:
		var ts := (0.85 + 0.36 * float(c)) if machine == "norn" else (0.8 + 0.42 * float(c))
		if machine == "norn" and not bool(r["free"]) and c >= 2 and scat >= 2:
			tease.append(c)
			tease_start[c] = maxf(ts, prev_ts + 0.1)
			ts = maxf(ts, prev_ts + 0.1) + (1.0 if c < 4 else 1.5)
		ts = maxf(ts, prev_ts + 0.3)
		prev_ts = ts
		var d := int(14.0 * ts) + 3
		var strip: Array = []
		for k in 3:
			strip.append(int((fin[c] as Array)[k]))
		for k in range(3, d):
			strip.append(_filler())
		for k in 3:
			strip.append(int((old[c] as Array)[k]) if old.size() > c else _filler())
		for k in 3:
			if int((fin[c] as Array)[k]) == Slots.Sym.BLITZ:
				scat += 1
		rs.append({"strip": strip, "d": d, "ts": ts, "stopped": false})
	last_stop = prev_ts
	hidden.clear()
	for cellv in r.get("bolt", []):
		hidden["%d,%d" % [int((cellv as Array)[0]), int((cellv as Array)[1])]] = _rng.randi() % 8
	grid = fin
	_spin_snd = 0.0
	_tease_snd = 0.0
	Sfx.play("slot_lever")
	Sfx.play("slot_spin", 0.0, 0.3)
	_spin_snd = 1.0
	flash = 0.0


func _u(rr: Dictionary) -> float:
	var ts: float = rr["ts"]
	if spin_t >= ts:
		var tb := spin_t - ts
		if tb < 0.4 and int(rr["d"]) > 0:
			return 0.13 * sin(minf(tb / 0.28, 1.0) * PI) * exp(-tb * 3.5)
		return 0.0
	var x := spin_t / ts
	return float(rr["d"]) * pow(1.0 - x, 2.0)


func _tick_spin() -> void:
	if t >= _spin_snd and t < last_stop - 0.3:
		Sfx.play("slot_spin")
		_spin_snd = t + 0.85
	var all_stopped := true
	for c in cols:
		var rr: Dictionary = rs[c]
		if not bool(rr["stopped"]):
			all_stopped = false
			if spin_t >= float(rr["ts"]):
				rr["stopped"] = true
				_on_stop(c)
	if tease.size() > 0 and t >= _tease_snd:
		for c in tease:
			var rr2: Dictionary = rs[c]
			if not bool(rr2["stopped"]) and spin_t >= float(tease_start[c]):
				if _tease_snd == 0.0:
					Sfx.play("slot_tease")
				else:
					Sfx.play("slot_tick", 0.0, 0.0, 1.0 + 0.5 * minf((spin_t - float(tease_start[c])) / 1.2, 1.0))
				_tease_snd = t + 0.09 if _tease_snd > 0.0 else t + 0.12
				break
	if all_stopped and spin_t >= last_stop + 0.32:
		_enter_eval()


func _on_stop(c: int) -> void:
	Sfx.play("slot_stop", 0.0, 0.0, 0.88 + 0.06 * float(c))
	shake = maxf(shake, 0.28)
	for k in 3:
		if int((grid[c] as Array)[k]) == Slots.Sym.BLITZ:
			pulse["%d,%d" % [c, k]] = 1.4
			Sfx.play("slot_zap", -7.0)
			_spark_burst(_cell_center(c, k), 8, ZAP)
	var bx := x0 + float(c) * cell + cell * 0.5
	_spark_burst(Vector2(bx, y0 + cell * 3.0), 4, GOLD)


func _enter_eval() -> void:
	st = St.EVAL
	t = 0.0
	_events.clear()
	var at := 0.25
	for cellv in res.get("bolt", []):
		var cv: Array = cellv
		_sched(at, _ev_bolt.bind(int(cv[0]), int(cv[1])))
		at += 0.3
	if not (res.get("bolt", []) as Array).is_empty():
		at += 0.25
	if bool(res.get("bottle", false)):
		_sched(0.1, _ev_bottle)
		at = maxf(at, 1.1)  # erst zeigt das Banner die Flasche, dann kommen die Linien
	if bool(res["curse"]):
		_sched(at, _begin_curse)
		return
	var ls: Array = (res["lines"] as Array).duplicate()
	ls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["pay"]) > int(b["pay"]))
	lines_shown = ls
	var shown := mini(ls.size(), 7)
	if int(res["powerup"]) > 0:
		_sched(at, _ev_powerup.bind(int(res["powerup"])))
		at += 0.9
	var stacks: Array = res.get("stacks", [])
	m_stack = 0
	m_pu = 0
	mult_shown = 1
	for k in stacks.size():
		_sched(at, _ev_stack.bind(int(stacks[k]), k + 1))
		at += 0.55
	if int(res["retrigger"]) > 0:
		_sched(at, _ev_retrigger)
		at += 0.7
	for i in shown:
		_sched(at, _ev_line.bind(i))
		at += 0.62 if shown <= 4 else 0.42
	if shown > 0:
		_sched(at, _ev_all_lines)
		at += 0.25
	_sched(at, _ev_count)
	var ratio := float(res["big"])
	var dur := clampf(0.5 + 0.55 * log(1.0 + ratio) / log(2.0), 0.0, 3.2) if int(res["win"]) > 0 else 0.0
	var tier := _tier(ratio, bool(res["jackpot"]))
	if tier != "":
		_sched(at + 0.4, _ev_tier.bind(tier))
	at += dur + (1.5 if tier != "" else 0.25)
	_sched(at, _after_eval)


## Stufe eines Gewinns nach Vielfachen des Einsatzes: "" (nichts Besonderes), "gross", "mega", "saga", "jackpot".
func _tier(ratio: float, jackpot: bool) -> String:
	if jackpot:
		return "jackpot"
	if ratio >= 60.0:
		return "saga"
	if ratio >= 20.0:
		return "mega"
	if ratio >= 6.0:
		return "gross"
	return ""


func _ev_bolt(c: int, r: int) -> void:
	hidden.erase("%d,%d" % [c, r])
	var target := _cell_center(c, r)
	_add_bolt(Vector2(target.x + _rng.randf_range(-30.0, 30.0), 8.0), target, 0.28)
	Sfx.play("slot_zap")
	flash = maxf(flash, 0.35)
	flash_col = ZAP
	shake = maxf(shake, 0.5)
	pulse["%d,%d" % [c, r]] = 0.9
	_spark_burst(target, 14, ZAP)


func _ev_bottle() -> void:
	banner = "PFANDFLASCHE"
	banner_sub = "Ein sicheres Freispiel"
	banner_t = 0.0
	banner_col = Items.pfand_color()
	flash = 0.6
	flash_col = GOLD
	shake = 0.4
	Sfx.play("bell")
	Sfx.play("slot_power", -3.0, 0.2)
	_spark_burst(Vector2(240.0, 140.0), 30, GOLD)


func _ev_powerup(m: int) -> void:
	m_pu = m
	mult_shown = maxi(m_stack, 1) * m_pu
	banner = "POWER-UP  x%d" % m
	banner_sub = ""
	banner_t = 0.0
	banner_col = ZAP
	flash = 0.5
	flash_col = ZAP
	shake = 0.6
	Sfx.play("slot_power")
	_spark_burst(Vector2(x0 + cell * 0.5, y0 + cell * 1.5), 24, ZAP)


func _ev_stack(c: int, k: int) -> void:
	m_stack = k
	mult_shown = maxi(m_stack, 1) * maxi(m_pu, 1)
	var cx := x0 + float(c) * cell + cell * 0.5
	_add_bolt(Vector2(cx, y0 - 8.0), Vector2(cx, y0 + cell * 3.0), 0.4)
	Sfx.play("slot_stack", 0.0, 0.0, 0.9 + 0.08 * float(k))
	flash = 0.45
	flash_col = GREEN
	shake = 0.8
	for r in 3:
		pulse["%d,%d" % [c, r]] = 1.2
	_spark_burst(Vector2(cx, y0 + cell * 1.5), 20, GREEN)
	_float("x%d" % k, Vector2(cx, y0 - 2.0), GREEN, 12)


func _ev_retrigger() -> void:
	banner = "+%d FREISPIELE" % int(res["retrigger"])
	banner_sub = ""
	banner_t = 0.0
	banner_col = GREEN
	Sfx.play("slot_coil")
	flash = 0.4
	flash_col = GREEN
	shake = 0.5


func _ev_line(i: int) -> void:
	line_idx = i
	var wl: Dictionary = lines_shown[i]
	var cells: Array = wl["cells"]
	var last: Array = cells[cells.size() - 1]
	var pay := 0.0
	if machine == "norn":
		pay = float(wl["pay"]) * float(voy.automat.bet) / 10.0 * float(maxi(int(res["mult"]), 1))
	else:
		pay = float(wl["pay"]) * float(res.get("stake_value", 0))
	_float("+%d" % roundi(pay), _cell_center(int(last[0]), int(last[1])), GOLD, 11)
	Sfx.play("slot_win1", -2.0 * float(maxi(0, i - 3)), 0.0, 1.0 + 0.06 * float(i))
	for cv in cells:
		pulse["%d,%d" % [int((cv as Array)[0]), int((cv as Array)[1])]] = 0.7
	_spark_burst(_cell_center(int(last[0]), int(last[1])), 6, GOLD)


func _ev_all_lines() -> void:
	line_idx = -1
	all_marked = true


func _ev_count() -> void:
	win_target = int(res["win"])
	win_shown = 0.0
	var ratio := float(res["big"])
	var dur := clampf(0.5 + 0.55 * log(1.0 + ratio) / log(2.0), 0.3, 3.2)
	count_rate = float(win_target) / dur if win_target > 0 else 0.0
	if win_target > 0:
		var snd := "slot_win1"
		if ratio >= 6.0:
			snd = "slot_win3"
		elif ratio >= 2.0:
			snd = "slot_win2"
		Sfx.play(snd)
		if ratio >= 2.0:
			Sfx.play("slot_coins", -3.0, 0.2)
		_burst_coins(clampi(int(ratio * 3.0), 4, 70))


func _ev_tier(name: String) -> void:
	match name:
		"gross":
			banner = "GROSSER GEWINN"
			banner_col = GOLD
			banner_sub = ""
		"mega":
			banner = "MEGA GEWINN"
			banner_col = Color("ffb347")
			banner_sub = "Die Götter bieten Segen"
		"saga":
			banner = "SAGENHAFT"
			banner_col = Color("ff7a45")
			banner_sub = "Segen und ein Fund"
		_:
			banner = "ODINS JACKPOT"
			banner_col = Color("fff0a0")
			banner_sub = "Fünf Augen auf einer Linie"
	banner_t = 0.0
	flash = 0.6
	flash_col = GOLD
	shake = 0.9 if name != "gross" else 0.5
	if name != "gross":
		Sfx.play("slot_jackpot" if name == "jackpot" or name == "saga" else "slot_win3")
		_burst_coins(80 if name == "jackpot" else 50)


func _after_eval() -> void:
	var due_lines := voy.automat_bank() if machine == "norn" else []
	if machine == "norn":
		spin_win += win_target
		if not due_lines.is_empty():
			reward_text = ", ".join(PackedStringArray(due_lines))
	if int(res["trigger"]) > 0:
		_begin_alive()
		return
	if machine == "norn" and voy.automat.in_free():
		st = St.PAUSE
		t = 0.0
		_events.clear()
		_sched(0.55, _auto_free_spin)
		return
	if machine == "norn" and bool(res["ended"]):
		_begin_summary()
		return
	if machine == "loki":
		if voy.loki_pot > 0:
			status = "Kassieren oder Risiko?"
		elif voy.loki_over():
			status = "Alle Runden gespielt."
	st = St.IDLE
	t = 0.0
	fast = false


func _auto_free_spin() -> void:
	var r := voy.automat_spin()
	if r.is_empty():
		st = St.IDLE
		return
	_begin_spin(r)


## Zweiter Teil nach der Auslösung: der Draugr erwacht (Freispiele). Der Schrei steht in slot_alive.wav.
func _begin_alive() -> void:
	st = St.ALIVE
	t = 0.0
	alive_t = 0.0
	_events.clear()
	fast = false
	Sfx.play("slot_coil")
	Sfx.play("slot_alive", 0.0, 0.5)
	_sched(0.7, func() -> void:
		flash = 0.8
		flash_col = ZAP
		shake = 0.9
		_add_bolt(Vector2(190.0, 0.0), Vector2(240.0, 140.0), 0.3))
	_sched(1.05, func() -> void:
		flash = 1.0
		flash_col = Color.WHITE
		shake = 1.0
		_add_bolt(Vector2(300.0, 0.0), Vector2(250.0, 130.0), 0.3)
		_add_bolt(Vector2(170.0, 0.0), Vector2(225.0, 150.0), 0.3)
		_spark_burst(Vector2(240.0, 150.0), 50, GREEN))
	_sched(1.5, func() -> void:
		flash = 0.6
		flash_col = ZAP
		_add_bolt(Vector2(240.0, 0.0), Vector2(240.0, 120.0), 0.25))
	_sched(2.0, func() -> void:
		flash = 0.5
		flash_col = GREEN
		shake = 0.6
		_add_bolt(Vector2(130.0, 0.0), Vector2(200.0, 160.0), 0.25)
		_add_bolt(Vector2(350.0, 0.0), Vector2(280.0, 160.0), 0.25))
	_sched(ALIVE_SHOUT2 - 0.05, func() -> void:  # der zweite Schrei, lauter
		flash = 1.0
		flash_col = Color.WHITE
		shake = 1.0
		_add_bolt(Vector2(200.0, 0.0), Vector2(215.0, 140.0), 0.3)
		_add_bolt(Vector2(290.0, 0.0), Vector2(270.0, 150.0), 0.3)
		_add_bolt(Vector2(100.0, 0.0), Vector2(190.0, 170.0), 0.3)
		_spark_burst(Vector2(240.0, 150.0), 70, GREEN))
	_sched(3.3, func() -> void:
		flash = 0.5
		flash_col = ZAP
		shake = 0.5
		_add_bolt(Vector2(380.0, 0.0), Vector2(290.0, 150.0), 0.25))
	_sched(ALIVE_LEN, _end_alive)


func _end_alive() -> void:
	alive_t = -1.0
	st = St.PAUSE
	t = 0.0
	_events.clear()
	_sched(0.5, _auto_free_spin)


func _begin_summary() -> void:
	st = St.SUMMARY
	t = 0.0
	_events.clear()
	var total := int(res["fg_total"])
	var ratio := float(total) / float(maxi(voy.automat.bet, 1))
	banner = "FREISPIELE VORBEI"
	banner_sub = "Gewonnen: %d Beute" % total
	banner_t = 0.0
	banner_col = GREEN
	var tier := _tier(ratio, voy.automat_seq_jackpot)
	if tier != "":
		_ev_tier(tier)
		banner_sub = "Freispiele: %d Beute%s" % [total, ("  ·  " + reward_text) if reward_text != "" else ""]
	_burst_coins(clampi(int(ratio * 2.0), 6, 90))
	Sfx.play("slot_win3" if ratio >= 6.0 else "slot_win2")
	_sched(2.7, func() -> void:
		st = St.IDLE
		t = 0.0
		fast = false)


func _begin_curse() -> void:
	st = St.CURSE
	t = 0.0
	_events.clear()
	curse_text = "%s  ·  %s" % [String(res.get("lost", "")), String(res.get("penalty", ""))]
	Sfx.play("slot_curse")
	flash = 0.7
	flash_col = GREEN_D
	shake = 1.0
	_sched(2.6, func() -> void:
		st = St.IDLE
		t = 0.0
		fast = false
		if voy.loki_over():
			status = "Alle Runden gespielt."
		else:
			status = "Adlersson lacht.")


# --- Eingabe ----------------------------------------------------------------------

func click(id: String) -> void:
	if id == "":
		if busy():
			fast = true
		return
	if id == "xs":
		spin()
		return
	if busy():
		fast = true
		return
	match id:
		"xb0":
			voy.automat_set_bet(voy.automat_bet_i - 1)
			Sfx.play("click")
		"xb1":
			voy.automat_set_bet(voy.automat_bet_i + 1)
			Sfx.play("click")
		"xq":
			voy.automat_close()
		"xc":
			var pot := voy.loki_pot
			voy.loki_cash()
			spin_win = pot
			Sfx.play("slot_win2")
			Sfx.play("slot_coins", -3.0, 0.1)
			_burst_coins(clampi(pot / 30, 6, 60))
			status = "Kassiert: %d Beute" % pot
		"xr":
			var pot2 := voy.loki_pot
			flip_ok = voy.loki_risk()
			st = St.FLIP
			t = 0.0
			flip_t = 0.0
			Sfx.play("slot_flip")
			status = ""
			_events.clear()
			_sched(1.7, func() -> void:
				if flip_ok:
					Sfx.play("slot_win2")
					_burst_coins(30)
					status = "Verdoppelt: %d Beute" % voy.loki_pot
					flash = 0.5
					flash_col = GOLD
				else:
					Sfx.play("slot_lose")
					status = "Weg: %d Beute" % pot2
					shake = 0.5
				flip_t = -1.0
				st = St.IDLE
				t = 0.0)
		_:
			if id.begins_with("xl"):
				var kinds := ["loot", "hull", "man", "bottle"]
				voy.loki_pick(String(kinds[clampi(int(id.substr(2)), 0, 3)]))
				Sfx.play("click")


func key(k: int) -> bool:
	match k:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if busy():
				fast = true
			elif machine == "norn" and voy.automat_can_spin():
				spin()
			elif machine == "loki" and voy.loki_can_spin():
				spin()
			elif voy.automat_kind == "bonus" and voy.automat_done:
				voy.automat_close()
			return true
		KEY_ESCAPE:
			if not busy():
				voy.automat_close()
			return true
		KEY_UP:
			if not busy():
				voy.automat_set_bet(voy.automat_bet_i + 1)
			return true
		KEY_DOWN:
			if not busy():
				voy.automat_set_bet(voy.automat_bet_i - 1)
			return true
	return false


# --- Zeit ---------------------------------------------------------------------------

func tick(delta: float) -> void:
	var dt := delta * (2.6 if (fast and st != St.ALIVE) else 1.0)  # der Schrei lässt sich nicht überspringen
	time += delta
	t += dt
	if st == St.SPIN or spin_t < 10.0:
		spin_t += dt
	shake = maxf(shake - delta * 2.2, 0.0)
	flash = maxf(flash - delta * 2.4, 0.0)
	if banner_t >= 0.0:
		banner_t += dt
		if banner_t > 2.6:
			banner_t = -1.0
	if alive_t >= 0.0:
		alive_t += dt
	if flip_t >= 0.0:
		flip_t += dt
	for key in pulse.keys():
		pulse[key] = float(pulse[key]) - dt
		if float(pulse[key]) <= 0.0:
			pulse.erase(key)
	_run_events()
	if st == St.SPIN:
		_tick_spin()
	if win_shown < float(win_target):
		win_shown = minf(win_shown + count_rate * dt, float(win_target))
		_coin_sound_t -= dt
	_tick_particles(dt)


func _tick_particles(dt: float) -> void:
	var keep: Array = []
	for p in particles:
		var pd: Dictionary = p
		pd["life"] = float(pd["life"]) - dt
		if float(pd["life"]) <= 0.0:
			continue
		var v: Vector2 = pd["v"]
		if int(pd["kind"]) == 0:  # Münze
			v.y += 330.0 * dt
			pd["a"] = float(pd["a"]) + dt * 12.0
		else:
			v.y += 60.0 * dt
			v *= 1.0 - minf(dt * 2.0, 0.9)
		pd["v"] = v
		pd["p"] = (pd["p"] as Vector2) + v * dt
		if int(pd["kind"]) == 0 and (pd["p"] as Vector2).y > VIEW.y + 10.0:
			continue
		keep.append(pd)
	particles = keep
	var keep_b: Array = []
	for b in bolts:
		var bd: Dictionary = b
		bd["life"] = float(bd["life"]) - dt
		if float(bd["life"]) > 0.0:
			keep_b.append(bd)
	bolts = keep_b
	var keep_f: Array = []
	for f in floaters:
		var fd: Dictionary = f
		fd["life"] = float(fd["life"]) - dt
		fd["p"] = (fd["p"] as Vector2) + Vector2(0.0, -16.0 * dt)
		if float(fd["life"]) > 0.0:
			keep_f.append(fd)
	floaters = keep_f


func _burst_coins(n: int) -> void:
	for i in n:
		particles.append({"kind": 0, "p": Vector2(_rng.randf_range(60.0, 420.0), _rng.randf_range(-40.0, 10.0)), "v": Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(20.0, 120.0)), "life": 3.0, "a": _rng.randf() * 4.0})


func _spark_burst(p: Vector2, n: int, col: Color) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(30.0, 130.0)
		particles.append({"kind": 1, "p": p, "v": Vector2(cos(a), sin(a)) * sp, "life": _rng.randf_range(0.25, 0.6), "col": col})


func _add_bolt(a: Vector2, b: Vector2, life: float) -> void:
	var pts := PackedVector2Array()
	var steps := 9
	for i in steps + 1:
		var f := float(i) / float(steps)
		var p := a.lerp(b, f)
		if i > 0 and i < steps:
			p += Vector2(_rng.randf_range(-9.0, 9.0), _rng.randf_range(-4.0, 4.0))
		pts.append(p)
	bolts.append({"pts": pts, "life": life, "max": life})


func _float(text: String, p: Vector2, col: Color, size: int) -> void:
	floaters.append({"text": text, "p": p, "life": 1.1, "col": col, "size": size})


func _cell_center(c: int, r: int) -> Vector2:
	return Vector2(x0 + float(c) * cell + cell * 0.5, y0 + float(r) * cell + cell * 0.5)


# --- Zeichnen -----------------------------------------------------------------------

func _blit(h: Hud, sym: int, pos: Vector2, clip: Rect2, mod: Color, size: float = 32.0) -> void:
	if tex == null:
		return
	var dst := Rect2(pos, Vector2(size, size))
	var vis := dst.intersection(clip)
	if vis.size.x <= 0.0 or vis.size.y <= 0.0:
		return
	var k := 32.0 / size
	var src := Rect2(float(sym) * 32.0 + (vis.position.x - dst.position.x) * k, (vis.position.y - dst.position.y) * k, vis.size.x * k, vis.size.y * k)
	h.draw_texture_rect_region(tex, vis, src, mod)


func draw(h: Hud, mouse: Vector2) -> void:
	h._btns.clear()
	h._tips.clear()
	var off := Vector2(roundf(_rng.randf_range(-1.0, 1.0) * shake * 3.0), roundf(_rng.randf_range(-1.0, 1.0) * shake * 3.0))
	h.draw_set_transform(off, 0.0, Vector2.ONE)
	_draw_backdrop(h)
	if machine == "loki":
		_draw_loki(h, mouse)
	else:
		_draw_norn(h, mouse)
	_draw_effects(h)
	if alive_t >= 0.0:
		_draw_alive(h)
	if st == St.CURSE:
		_draw_curse(h)
	_draw_banner(h)
	h.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.0:
		h.draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(flash_col, clampf(flash, 0.0, 1.0) * 0.55))
	h._draw_tip(mouse)


func _draw_backdrop(h: Hud) -> void:
	var free := machine == "norn" and voy.automat != null and voy.automat.in_free()
	var tint := Color(0.02, 0.01, 0.05, 0.9)
	if free or alive_t >= 0.0:
		tint = Color(0.0, 0.05, 0.04, 0.92)
	if machine == "loki":
		tint = Color(0.0, 0.04, 0.03, 0.93)
	h.draw_rect(Rect2(-8, -8, VIEW.x + 16, VIEW.y + 16), tint)
	if free or machine == "loki":
		# fernes Wetterleuchten
		var f := maxf(sin(time * 1.3) * sin(time * 0.37 + 1.0), 0.0)
		if f > 0.55:
			h.draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(GREEN_D, (f - 0.55) * 0.5))
	UiSkin.vignette(h, 1)


func _lamp_ring(h: Hud, r: Rect2, speed: float, col_a: Color, col_b: Color, boost: bool) -> void:
	var per := 12.0
	var n := 0
	var phase := int(time * speed)
	var pts: Array[Vector2] = []
	var x := r.position.x
	while x <= r.end.x:
		pts.append(Vector2(x, r.position.y))
		x += per
	var y := r.position.y + per
	while y < r.end.y:
		pts.append(Vector2(r.end.x, y))
		y += per
	x = r.end.x
	while x >= r.position.x:
		pts.append(Vector2(x, r.end.y))
		x -= per
	y = r.end.y - per
	while y > r.position.y:
		pts.append(Vector2(r.position.x, y))
		y -= per
	for p in pts:
		var on := ((n + phase) % 3 == 0) or (boost and (n + phase) % 2 == 0)
		h.draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 3, 3), INK)
		h.draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 2, 2), col_a if on else col_b)
		if on:
			h.draw_rect(Rect2(p.x - 2.0, p.y - 2.0, 5, 5), Color(col_a, 0.18))
		n += 1


func _draw_norn(h: Hud, mouse: Vector2) -> void:
	var free := voy.automat.in_free()
	var body := Rect2(34, 4, 412, 312)
	UiSkin.panel(h, body, UiSkin.BRONZE_HI if free else UiSkin.BRONZE, 2, "tile_stone")
	h.draw_rect(body.grow(-6), Color(VIOLET_D, 0.82))
	# Anzeigetafel oben
	var mar := Rect2(110, 11, 260, 32)
	h.draw_rect(mar, Color(0.07, 0.03, 0.14))
	UiSkin.panel(h, mar, GOLD_D, 0, "")
	var title := "NORNENWALZEN"
	var tcol := GOLD
	if free:
		title = "IT'S ALIVE!"
		tcol = GREEN
		if int(time * 6.0) % 2 == 0:
			tcol = Color("c8ffe2")
	h._t(Vector2(mar.position.x, mar.position.y + 23.0), title, tcol, 18, HORIZONTAL_ALIGNMENT_CENTER, mar.size.x, h._lore)
	_lamp_ring(h, Rect2(104, 8, 272, 38), 9.0 if not free else 16.0, GREEN if free else GOLD, GOLD_D, free or banner_t >= 0.0)
	# Seitenteile: Spule links, Draugr rechts
	_draw_coil(h, Rect2(46, 52, 84, 132), free)
	_draw_draugr_panel(h, Rect2(350, 52, 84, 132), free)
	# Walzenfenster
	var frame := Rect2(x0 - 5.0, y0 - 5.0, cell * 5.0 + 10.0, cell * 3.0 + 10.0)
	UiSkin.panel(h, frame, GREEN if free else UiSkin.BRONZE_HI, 0, "")
	h.draw_rect(Rect2(x0, y0, cell * 5.0, cell * 3.0), Color("0b0a12"))
	_draw_reels(h)
	_lamp_ring(h, frame.grow(5.0), 7.0 if st == St.IDLE else 14.0, GREEN if free else GOLD, GOLD_D, st == St.EVAL and all_marked)
	_draw_info_strip(h, free)
	_draw_norn_controls(h, mouse, free)
	_tip_paytable(h, Rect2(x0, y0, cell * 5.0, cell * 3.0))


func _draw_coil(h: Hud, r: Rect2, free: bool) -> void:
	h.draw_rect(r, Color(0.04, 0.03, 0.08))
	UiSkin.panel(h, r, GOLD_D, 0, "")
	var cx := r.position.x + r.size.x * 0.5
	var base_y := r.position.y + 74.0
	h.draw_rect(Rect2(cx - 16.0, base_y, 32, 8), Color("3a3144"))
	h.draw_rect(Rect2(cx - 16.0, base_y, 32, 1), Color("6a5a7a"))
	for k in 6:
		var w := 14.0 - float(k) * 1.2
		var yy := base_y - 6.0 - float(k) * 6.0
		h.draw_rect(Rect2(cx - w * 0.5, yy, w, 4), Color("b87333") if k % 2 == 0 else Color("8a5424"))
	var top := Vector2(cx, base_y - 48.0)
	var glow := 0.25 + 0.2 * sin(time * 5.0)
	if free or alive_t >= 0.0:
		glow = 0.6 + 0.3 * sin(time * 18.0)
	h.draw_circle(top, 11.0, Color(ZAP, glow * 0.35))
	h.draw_circle(top, 7.0, Color("8a9bb0"))
	h.draw_circle(top + Vector2(-2, -2), 3.0, Color("e8f2ff"))
	if free or alive_t >= 0.0 or int(time * 1.7) % 4 == 0:
		for k in 3:
			var a := time * 7.0 + float(k) * 2.1
			var end := top + Vector2(cos(a) * 30.0, sin(a * 1.3) * 22.0)
			end = Vector2(clampf(end.x, r.position.x + 3.0, r.end.x - 3.0), clampf(end.y, r.position.y + 3.0, r.end.y - 3.0))
			var mid := top.lerp(end, 0.5) + Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0))
			h.draw_polyline(PackedVector2Array([top, mid, end]), Color(ZAP, 0.9), 1.0)
	if free:
		h._t(Vector2(r.position.x, r.position.y + 100.0), "FREISPIELE", GREEN, 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var left := voy.automat.free_left
		var done := voy.automat.free_done
		h._t(Vector2(r.position.x, r.position.y + 118.0), "%d / %d" % [done, done + left], PAPER, 12, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	else:
		h._t(Vector2(r.position.x, r.position.y + 100.0), "3 Blitzrunen", ZAP, 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		h._t(Vector2(r.position.x, r.position.y + 111.0), "wecken den", DIM, 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		h._t(Vector2(r.position.x, r.position.y + 122.0), "Draugr", DIM, 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_draugr_panel(h: Hud, r: Rect2, free: bool) -> void:
	h.draw_rect(r, Color(0.04, 0.03, 0.08))
	UiSkin.panel(h, r, GOLD_D, 0, "")
	var awake := free or alive_t >= 0.0
	var center := Vector2(r.position.x + r.size.x * 0.5, r.position.y + 46.0)
	if awake:
		h.draw_circle(center, 38.0, Color(GREEN, 0.14 + 0.08 * sin(time * 9.0)))
	if tex != null:
		var mod := Color(0.45, 0.5, 0.55) if not awake else Color(1.0, 1.0, 1.0)
		h.draw_texture_rect_region(tex, Rect2(center - Vector2(32, 32), Vector2(64, 64)), Rect2(6.0 * 32.0, 0.0, 32.0, 32.0), mod)
		if awake:
			var glow := 0.55 + 0.45 * sin(time * 11.0)
			for ex in [-5.0, 3.0]:
				h.draw_circle(center + Vector2(float(ex) * 2.0, -4.0), 6.0, Color(GREEN, 0.5 * glow))
	if awake:
		h._t(Vector2(r.position.x, r.position.y + 104.0), "FAKTOR", GREEN, 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var m := maxi(mult_shown, 1)
		if st == St.EVAL or st == St.SPIN:
			m = maxi(mult_shown if st == St.EVAL else 1, 1)
		h._t(Vector2(r.position.x, r.position.y + 124.0), "x%d" % m, PAPER if m <= 1 else GREEN, 18 if m > 1 else 14, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	else:
		h._t(Vector2(r.position.x, r.position.y + 112.0), "Zzz", DIM, 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		h._t(Vector2(r.position.x, r.position.y + 124.0), "schläft noch", DIM, 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_reels(h: Hud) -> void:
	var win := Rect2(x0, y0, cell * float(cols), cell * 3.0)
	var marked: Dictionary = {}
	var focus: Dictionary = {}
	if st == St.EVAL or st == St.IDLE or st == St.PAUSE or st == St.SUMMARY:
		if line_idx >= 0 and line_idx < lines_shown.size():
			for cv in (lines_shown[line_idx] as Dictionary)["cells"]:
				focus["%d,%d" % [int((cv as Array)[0]), int((cv as Array)[1])]] = true
		elif all_marked:
			for wl in lines_shown:
				for cv in (wl as Dictionary)["cells"]:
					marked["%d,%d" % [int((cv as Array)[0]), int((cv as Array)[1])]] = true
	for c in cols:
		var rr: Dictionary = rs[c]
		var strip: Array = rr["strip"]
		var u := _u(rr)
		var speed := 0.0
		if not bool(rr["stopped"]) or spin_t < float(rr["ts"]) + 0.01:
			var ts: float = rr["ts"]
			if spin_t < ts and ts > 0.0:
				speed = 2.0 * float(rr["d"]) * (1.0 - spin_t / ts) / ts
		var blur := clampf(speed / 14.0, 0.0, 1.0)
		var base := int(floorf(u))
		for j in range(base - 1, base + 4):
			if j < 0 or j >= strip.size():
				continue
			var sym := int(strip[j])
			var py := y0 + (float(j) - u) * cell
			var rowi := j  # nur bei stehender Walze zählt die Zeile
			var key := "%d,%d" % [c, rowi]
			if speed <= 0.0 and rowi >= 0 and rowi < 3 and hidden.has(key):
				sym = int(hidden[key])
			var sp := Vector2(x0 + float(c) * cell + (cell - 32.0) * 0.5, py + (cell - 32.0) * 0.5)
			var mod := Color(1, 1, 1, 1.0 - 0.45 * blur)
			if speed <= 0.0 and not focus.is_empty() and not focus.has(key) and rowi >= 0 and rowi < 3:
				mod = Color(0.45, 0.45, 0.5, 1.0)
			var cr := Rect2(x0 + float(c) * cell, py, cell, cell)
			if speed <= 0.0 and rowi >= 0 and rowi < 3:
				var pf := float(pulse.get(key, 0.0))
				if focus.has(key) or pf > 0.0:
					h.draw_rect(cr.intersection(win).grow(-1.0), Color(GOLD, 0.28 + 0.18 * sin(time * 14.0)))
				elif marked.has(key):
					h.draw_rect(cr.intersection(win).grow(-1.0), Color(GOLD, 0.14))
			_blit(h, sym, sp, win, mod)
			if speed <= 0.0 and rowi >= 0 and rowi < 3 and (focus.has(key) or float(pulse.get(key, 0.0)) > 0.0):
				var rc := cr.intersection(win).grow(-1.0)
				_frame(h, rc, GOLD if float(pulse.get(key, 0.0)) <= 0.0 or focus.has(key) else ZAP)
		if blur > 0.05:
			for k in 4:
				var sy := y0 + fposmod(time * 380.0 * (1.0 + 0.2 * float(k)) + float(c) * 37.0 + float(k) * 41.0, cell * 3.0)
				h.draw_rect(Rect2(x0 + float(c) * cell + 4.0 + float(k) * 8.0, sy, 2, 12.0), Color(1, 1, 1, 0.10 * blur))
		# Walzenwand: oben und unten dunkler, wie auf einer Rolle
		var wx := x0 + float(c) * cell
		for k in 8:
			var a := 0.5 * (1.0 - float(k) / 8.0)
			h.draw_rect(Rect2(wx, y0 + float(k), cell, 1), Color(0, 0, 0, a))
			h.draw_rect(Rect2(wx, y0 + cell * 3.0 - 1.0 - float(k), cell, 1), Color(0, 0, 0, a))
		if c > 0:
			h.draw_rect(Rect2(wx, y0, 1, cell * 3.0), Color(0, 0, 0, 0.75))
		# Spannung: leuchtender Rahmen um die Walze, die noch läuft
		if c in tease and not bool(rr["stopped"]) and spin_t >= float(tease_start.get(c, 0.0)):
			_frame(h, Rect2(wx, y0, cell, cell * 3.0), Color(GOLD, 0.6 + 0.4 * sin(time * 20.0)))
			_frame(h, Rect2(wx + 1.0, y0 + 1.0, cell - 2.0, cell * 3.0 - 2.0), Color(GOLD, 0.35))
	# Linie der Gewinnlinie
	if line_idx >= 0 and line_idx < lines_shown.size():
		var pts := PackedVector2Array()
		for cv in (lines_shown[line_idx] as Dictionary)["cells"]:
			pts.append(_cell_center(int((cv as Array)[0]), int((cv as Array)[1])))
		if pts.size() >= 2:
			h.draw_polyline(pts, Color(0, 0, 0, 0.7), 4.0)
			h.draw_polyline(pts, Color(GOLD, 0.95), 2.0)


func _frame(h: Hud, r: Rect2, col: Color) -> void:
	h.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), col)
	h.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1), col)
	h.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), col)
	h.draw_rect(Rect2(r.end.x - 1.0, r.position.y, 1, r.size.y), col)


func _draw_info_strip(h: Hud, free: bool) -> void:
	var y := y0 + cell * 3.0 + 22.0
	var text := status
	var col := DIM
	if line_idx >= 0 and line_idx < lines_shown.size():
		var wl: Dictionary = lines_shown[line_idx]
		text = "Linie %d: %dx %s" % [int(wl["line"]) + 1, int(wl["count"]), Slots.sym_name(int(wl["sym"]))]
		col = GOLD
	elif st == St.EVAL and win_target > 0:
		text = "Gewinn %d" % int(win_shown)
		col = GOLD
	elif st == St.IDLE and text == "":
		text = "Drei Blitzrunen starten die Freispiele" if machine == "norn" else ""
	if free and st == St.PAUSE:
		text = "Freispiel läuft …"
		col = GREEN
	h._t(Vector2(x0 - 10.0, y), text, col, 9, HORIZONTAL_ALIGNMENT_CENTER, cell * float(cols) + 20.0)


func _draw_norn_controls(h: Hud, mouse: Vector2, free: bool) -> void:
	var idle := st == St.IDLE
	# Beute und Gewinn
	h.draw_rect(Rect2(46, 236, 100, 30), Color(0.04, 0.03, 0.08))
	UiSkin.panel(h, Rect2(46, 236, 100, 30), GOLD_D, 0, "")
	h._t(Vector2(50, 247), "BEUTE", DIM, 7)
	h._t(Vector2(46, 261), str(roundi(voy.loot)), GOLD, 13, HORIZONTAL_ALIGNMENT_CENTER, 100.0)
	h.draw_rect(Rect2(334, 236, 100, 30), Color(0.04, 0.03, 0.08))
	UiSkin.panel(h, Rect2(334, 236, 100, 30), GOLD_D, 0, "")
	var shown := int(win_shown) if st == St.EVAL or win_shown > 0.0 else 0
	var seq := spin_win if (free or st == St.SUMMARY) else shown
	h._t(Vector2(338, 247), "GEWINN" if not free else "FREISPIELE", DIM, 7)
	h._t(Vector2(334, 261), str(seq), GREEN if free else (GOLD if seq > 0 else DIM), 13, HORIZONTAL_ALIGNMENT_CENTER, 100.0)
	# Einsatz
	var bet := voy.automat_bet()
	var can_bet := idle and voy.automat_kind == "harbor" and not free
	var minus := Rect2(150, 208, 20, 18)
	var plus := Rect2(310, 208, 20, 18)
	h._small_button(minus, "−", can_bet and minus.has_point(mouse), can_bet and voy.automat_bet_i > 0, 11)
	h._small_button(plus, "+", can_bet and plus.has_point(mouse), can_bet and voy.automat_bet_i < 2, 11)
	if can_bet and voy.automat_bet_i > 0:
		h._register(minus, "xb0")
	if can_bet and voy.automat_bet_i < 2:
		h._register(plus, "xb1")
	var label := "EINSATZ %d" % bet if voy.automat_kind != "bonus" else "FREIDREH · Einsatz %d" % bet
	h._t(Vector2(170, 221), label, PAPER, 10, HORIZONTAL_ALIGNMENT_CENTER, 140.0)
	h._tip(Rect2(150, 208, 180, 18), Tips._tip("Einsatz", [
		Tips._l("Der Einsatz wird bei jedem Dreh gezahlt und auf zehn Linien verteilt. Die Gewinne sind Vielfache davon.", PAPER),
		Tips._l("Pfeiltasten hoch und runter stellen ihn ein. Im Hafen sind %d Drehs je Besuch möglich (noch %d)." % [Voyage.SLOT_HARBOR_SPINS, maxi(Voyage.SLOT_HARBOR_SPINS - voy._harbor_spins, 0)], DIM),
	]))
	# Drehknopf
	var rb := Rect2(172, 236, 136, 32)
	var can_spin := idle and voy.automat_can_spin()
	var bonus_done := voy.automat_kind == "bonus" and voy.automat_done and idle
	var btext := "DREHEN"
	if free:
		btext = "FREISPIEL"
	elif bonus_done:
		btext = "WEITER"
	elif voy.automat_kind == "bonus":
		btext = "FREIDREH!"
	elif not can_spin and idle:
		btext = "ZU WENIG BEUTE" if _harbor_left() > 0 else "KEINE DREHS MEHR"
	var hov := (can_spin or bonus_done) and rb.has_point(mouse)
	var pulse_btn := can_spin and int(time * 3.0) % 2 == 0
	UiSkin.button(h, rb, UiSkin.State.HOVER if hov else (UiSkin.State.SELECTED if (can_spin or bonus_done) else UiSkin.State.DISABLED))
	if pulse_btn:
		h.draw_rect(rb.grow(1.0), Color(GOLD, 0.12))
	h._t(Vector2(rb.position.x, rb.position.y + 21.0), btext, GOLD if (can_spin or bonus_done) else DIM, 13, HORIZONTAL_ALIGNMENT_CENTER, rb.size.x)
	if can_spin:
		h._register(rb, "xs")
	elif bonus_done:
		h._register(rb, "xq")
	# Schluss
	var rq := Rect2(340, 276, 94, 22)
	var can_q := idle and not free
	h._small_button(rq, "Schluss", can_q and rq.has_point(mouse), can_q, 9)
	if can_q:
		h._register(rq, "xq")
	# Meldungen
	var note := ""
	if reward_text != "":
		note = reward_text
	elif voy.history.size() > 0:
		note = String((voy.history[voy.history.size() - 1] as Dictionary).get("text", ""))
	if note != "":
		h._wrap(note, 52.0, 272.0, 280.0, 7, DIM if reward_text == "" else GOLD)
	h._tip(Rect2(46, 270, 100, 28), Tips._tip("Gewinntabelle", _paytable_lines()))


func _harbor_left() -> int:
	return Voyage.SLOT_HARBOR_SPINS - voy._harbor_spins


func _paytable_lines() -> Array:
	var out: Array = []
	if machine == "norn":
		out.append(Tips._l("Drei, vier oder fünf gleiche von links nach rechts auf einer der zehn Linien (Vielfache des Linieneinsatzes):", PAPER))
		for row in Slots.pay_text("norn"):
			out.append(Tips._l("%s: %s" % [row[0], row[1]], GOLD))
		out.append(Tips._l("Odinsauge ist Joker. Drei Blitzrunen irgendwo: 8 Freispiele (4: 12, 5: 16), dazu 2x, 10x oder 50x den Einsatz.", ZAP))
		out.append(Tips._l("Im Freispiel ist der Draugr Joker, jede Walze voller Draugr zählt als Faktor, eine Blitzrune auf der ersten Walze ist ein Power-Up (x2 bis x10).", GREEN))
	else:
		out.append(Tips._l("Drei gleiche auf einer der fünf Linien zahlen ein Vielfaches des Einsatzes:", PAPER))
		for row in Slots.pay_text("loki"):
			out.append(Tips._l("%s: %s" % [row[0], row[1]], GOLD))
		out.append(Tips._l("Drei Masken sind Adlerssons Streich: alles weg, dazu eine Strafe.", RED))
	return out


func _tip_paytable(h: Hud, r: Rect2) -> void:
	h._tip(r, Tips._tip("Gewinntabelle", _paytable_lines()))


# --- Adlerssons Automat ---------------------------------------------------------------------

func _draw_loki(h: Hud, mouse: Vector2) -> void:
	var body := Rect2(34, 4, 412, 312)
	UiSkin.panel(h, body, Color("3f8a6a"), 2, "tile_stone")
	h.draw_rect(body.grow(-6), Color(0.02, 0.07, 0.06, 0.85))
	var mar := Rect2(110, 11, 260, 32)
	h.draw_rect(mar, Color(0.03, 0.08, 0.06))
	UiSkin.panel(h, mar, GREEN_D, 0, "")
	h._t(Vector2(mar.position.x, mar.position.y + 23.0), "ADLERSSONS WALZEN", GREEN, 18, HORIZONTAL_ALIGNMENT_CENTER, mar.size.x, h._lore)
	_lamp_ring(h, Rect2(104, 8, 272, 38), 8.0, GREEN, GREEN_D, st == St.CURSE)
	# Maske links
	if tex != null:
		var mx := 52.0
		h.draw_circle(Vector2(mx + 16.0, 150.0), 24.0, Color(GREEN, 0.10 + 0.05 * sin(time * 4.0)))
	var frame := Rect2(x0 - 5.0, y0 - 5.0, cell * 3.0 + 10.0, cell * 3.0 + 10.0)
	UiSkin.panel(h, frame, GREEN_D, 0, "")
	h.draw_rect(Rect2(x0, y0, cell * 3.0, cell * 3.0), Color("050a09"))
	_draw_reels(h)
	_lamp_ring(h, frame.grow(5.0), 6.0, GREEN, GREEN_D, false)
	_tip_paytable(h, Rect2(x0, y0, cell * 3.0, cell * 3.0))
	var idle := st == St.IDLE
	# Einsätze
	var rx := 252.0
	h._t(Vector2(rx, 62.0), "EINSATZ  ·  Runde %d / %d" % [mini(voy.loki_round + 1, Voyage.LOKI_ROUNDS), Voyage.LOKI_ROUNDS], GREEN, 9)
	var stakes := voy.loki_stakes()
	var tips := [
		"Beute: die Hälfte deiner Beute (mindestens 20, höchstens %d). Verlust: der Einsatz." % (100 + 50 * voy.stage),
		"Rumpf: ein Viertel des Rumpfes steht auf dem Spiel. Verlust: der Rumpf wird um so viel beschädigt (nie unter 1).",
		"Ein Mann: Adlersson setzt auf einen Mann der Besatzung. Verlust: er ist tot, und seine Ausrüstung kehrt in den Vorrat zurück. Der Gewinn ist am größten.",
		"Pfandflasche (legendär): ein sicheres Freispiel. Die Walzen drehen, bis es einen Gewinn gibt, Adlerssons Streich zählt nicht, nichts steht auf dem Spiel. Die Flasche zählt nicht als Runde.",
	]
	for i in 4:
		var st_d: Dictionary = stakes[i]
		var kind_i := String(st_d["kind"])
		var r := Rect2(rx, 66.0 + float(i) * 25.0, 182, 23)
		var can_pick := idle and voy.loki_pot == 0 and (voy.loki_round < Voyage.LOKI_ROUNDS or kind_i == "bottle")
		var sel := kind_i == voy.loki_stake
		var ok := bool(st_d["ok"]) and can_pick
		var hover := ok and r.has_point(mouse)
		UiSkin.button(h, r, UiSkin.State.SELECTED if sel else (UiSkin.State.HOVER if hover else (UiSkin.State.NORMAL if bool(st_d["ok"]) else UiSkin.State.DISABLED)))
		var tx := r.position.x + 6.0 + (17.0 if kind_i == "bottle" else 0.0)
		var label_col := GOLD if sel else (PAPER if bool(st_d["ok"]) else DIM)
		var text_col := DIM if not bool(st_d["ok"]) else (RED if (i > 0 and kind_i != "bottle") else PAPER)
		if kind_i == "bottle":
			_blit(h, 11, Vector2(r.position.x + 3.0, r.position.y + 3.0), r, Color(1, 1, 1, 1.0 if bool(st_d["ok"]) else 0.35), 16.0)
			label_col = Items.pfand_color() if bool(st_d["ok"]) else DIM
			text_col = GREEN if bool(st_d["ok"]) else DIM
		h._t(Vector2(tx, r.position.y + 10.0), String(st_d["label"]), label_col, 9)
		h._t(Vector2(tx, r.position.y + 20.0), String(st_d["text"]), text_col, 8)
		h._t(Vector2(r.position.x, r.position.y + 14.0), "Wert %d" % int(st_d["value"]), GREEN if bool(st_d["ok"]) else DIM, 8, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6.0)
		if ok:
			h._register(r, "xl%d" % i)
		h._tip(r, Tips._tip(String(st_d["label"]), [Tips._l(String(tips[i]), PAPER), Tips._l("Gewinne sind Vielfache des Einsatzwertes (%d), gedeckelt bei %d." % [int(st_d["value"]), Voyage.LOKI_CAP], DIM)]))
	# Gewinn und Risikoleiter
	var pot := voy.loki_pot if (st == St.IDLE or st == St.FLIP) else 0
	var pot_disp := pot if pot > 0 else (int(win_shown) if st == St.EVAL else 0)
	h._t(Vector2(rx, 175.0), "GEWINN", DIM, 8)
	h._t(Vector2(rx + 50.0, 181.0), str(pot_disp), GOLD if pot_disp > 0 else DIM, 15)
	for k in Slots.RISK_STEPS:
		var rb := Rect2(rx + float(k) * 46.0, 187.0, 42, 15)
		var done := k < voy.loki_ladder
		h.draw_rect(rb, Color(0.05, 0.12, 0.09) if not done else Color(0.3, 0.24, 0.05))
		_frame(h, rb, GREEN_D if not done else GOLD)
		var vtext := "x%d" % (2 << k)
		if done:
			vtext = "✓ x%d" % (2 << k)
		elif pot > 0 and k == voy.loki_ladder:
			vtext = str(pot * 2)
		h._t(Vector2(rb.position.x, rb.position.y + 12.0), vtext, GOLD if (done or (pot > 0 and k == voy.loki_ladder)) else DIM, 8, HORIZONTAL_ALIGNMENT_CENTER, rb.size.x)
	# Knöpfe
	var spin_r := Rect2(92, 232, 138, 30)
	var can_spin := idle and voy.loki_can_spin()
	var hov_s := can_spin and spin_r.has_point(mouse)
	UiSkin.button(h, spin_r, UiSkin.State.HOVER if hov_s else (UiSkin.State.SELECTED if can_spin else UiSkin.State.DISABLED))
	var stext := "DREHEN"
	if voy.loki_pot > 0:
		stext = "ENTSCHEIDE"
	elif voy.loki_over():
		stext = "FERTIG"
	elif not can_spin and idle:
		stext = "KEIN EINSATZ"
	h._t(Vector2(spin_r.position.x, spin_r.position.y + 20.0), stext, GOLD if can_spin else DIM, 13, HORIZONTAL_ALIGNMENT_CENTER, spin_r.size.x)
	if can_spin:
		h._register(spin_r, "xs")
	var cash := Rect2(rx, 206.0, 88, 24)
	var risk := Rect2(rx + 94.0, 206.0, 88, 24)
	var can_dec := idle and pot > 0
	var can_risk := can_dec and voy.loki_ladder < Slots.RISK_STEPS
	UiSkin.button(h, cash, UiSkin.State.HOVER if (can_dec and cash.has_point(mouse)) else (UiSkin.State.SELECTED if can_dec else UiSkin.State.DISABLED))
	h._t(Vector2(cash.position.x, cash.position.y + 16.0), "KASSIEREN", GOLD if can_dec else DIM, 10, HORIZONTAL_ALIGNMENT_CENTER, cash.size.x)
	UiSkin.button(h, risk, UiSkin.State.HOVER if (can_risk and risk.has_point(mouse)) else (UiSkin.State.NORMAL if can_risk else UiSkin.State.DISABLED))
	h._t(Vector2(risk.position.x, risk.position.y + 16.0), "RISIKO x2", RED if can_risk else DIM, 10, HORIZONTAL_ALIGNMENT_CENTER, risk.size.x)
	if can_dec:
		h._register(cash, "xc")
	if can_risk:
		h._register(risk, "xr")
	h._tip(risk, Tips._tip("Risikoleiter", [Tips._l("Münzwurf: mit der Hälfte der Fälle wird der Gewinn verdoppelt, sonst ist er weg. Bis zu %d Mal hintereinander." % Slots.RISK_STEPS, PAPER), Tips._l("Wer aufhört, behält, was auf der Leiter steht.", DIM)]))
	var rq := Rect2(340, 276, 94, 22)
	var can_q := idle
	h._small_button(rq, "Gehen", can_q and rq.has_point(mouse), can_q, 9)
	if can_q:
		h._register(rq, "xq")
	# Beute und Meldungen
	h.draw_rect(Rect2(46, 270, 120, 26), Color(0.03, 0.08, 0.06))
	UiSkin.panel(h, Rect2(46, 270, 120, 26), GREEN_D, 0, "")
	h._t(Vector2(50, 279), "BEUTE", DIM, 7)
	h._t(Vector2(46, 291), "%d    Rumpf %d" % [roundi(voy.loot), roundi(voy.hull)], GOLD, 9, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	var line := status
	if line == "":
		line = "Gewinn mit gleichen Symbolen auf einer Linie. Masken sind Adlerssons Streich."
	h._wrap(line, 176.0, 270.0, 160.0, 7, GOLD if status != "" else DIM)
	if st == St.FLIP:
		_draw_flip(h)


func _draw_flip(h: Hud) -> void:
	var c := Vector2(240.0, 140.0)
	var k := clampf(flip_t / 1.5, 0.0, 1.0)
	var rise := sin(k * PI) * 90.0
	h.draw_rect(Rect2(150, 70, 180, 150), Color(0, 0, 0, 0.78))
	_frame(h, Rect2(150, 70, 180, 150), GOLD)
	var ctr := c + Vector2(0.0, 40.0 - rise)
	var frame := int(flip_t * 14.0) % 4
	if tex != null:
		var ww: float = [48.0, 28.0, 8.0, 28.0][frame]
		var src := Rect2(float(frame) * 12.0, COIN_ROW, 12.0, 12.0)
		if k >= 0.95:
			src = Rect2(0.0, COIN_ROW, 12.0, 12.0)
			ww = 48.0
		h.draw_texture_rect_region(tex, Rect2(ctr - Vector2(ww * 0.5, 24.0), Vector2(ww, 48.0)), src)
	if flip_t >= 1.5:
		var txt := "VERDOPPELT!" if flip_ok else "VERLOREN"
		h._t(Vector2(150, 205), txt, GREEN if flip_ok else RED, 14, HORIZONTAL_ALIGNMENT_CENTER, 180.0)


func _draw_curse(h: Hud) -> void:
	var a := clampf(t / 0.3, 0.0, 1.0) * (1.0 - clampf((t - 2.2) / 0.4, 0.0, 1.0))
	h.draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(0.0, 0.1, 0.05, 0.7 * a))
	if tex != null:
		var s := 6.0 * (1.0 + 0.04 * sin(time * 9.0)) * minf(0.6 + t * 1.2, 1.0)
		var sz := 32.0 * s
		h.draw_texture_rect_region(tex, Rect2(Vector2(240.0 - sz * 0.5, 150.0 - sz * 0.5), Vector2(sz, sz)), Rect2(10.0 * 32.0, 0.0, 32.0, 32.0), Color(1, 1, 1, a))
	h._t(Vector2(0, 62), "ADLERSSONS STREICH!", Color(GREEN, a), 24, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, h._lore)
	h._t(Vector2(0, 280), curse_text, Color(RED.lightened(0.2), a), 11, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x)


# --- Szenen und Wirkungen -------------------------------------------------------------

func _draw_effects(h: Hud) -> void:
	for b in bolts:
		var bd: Dictionary = b
		var a := clampf(float(bd["life"]) / float(bd["max"]), 0.0, 1.0)
		var pts: PackedVector2Array = bd["pts"]
		h.draw_polyline(pts, Color(GREEN, 0.25 * a), 7.0)
		h.draw_polyline(pts, Color(ZAP, 0.6 * a), 3.0)
		h.draw_polyline(pts, Color(1, 1, 1, a), 1.0)
	for p in particles:
		var pd: Dictionary = p
		var pos: Vector2 = pd["p"]
		if int(pd["kind"]) == 0:
			var frame := int(float(pd["a"])) % 4
			if tex != null:
				var w: float = [12.0, 8.0, 3.0, 8.0][frame]
				h.draw_texture_rect_region(tex, Rect2(pos - Vector2(w * 0.5, 6.0), Vector2(w, 12.0)), Rect2(float(frame) * 12.0, COIN_ROW, 12.0, 12.0))
		else:
			var col: Color = pd["col"]
			h.draw_rect(Rect2(pos.x - 1.0, pos.y - 1.0, 2, 2), Color(col, clampf(float(pd["life"]) * 3.0, 0.0, 1.0)))
	for f in floaters:
		var fd: Dictionary = f
		var col2: Color = fd["col"]
		h._t(Vector2((fd["p"] as Vector2).x - 30.0, (fd["p"] as Vector2).y), String(fd["text"]), Color(col2, clampf(float(fd["life"]) * 2.0, 0.0, 1.0)), int(fd["size"]), HORIZONTAL_ALIGNMENT_CENTER, 60.0)


func _draw_banner(h: Hud) -> void:
	if banner_t < 0.0 or banner == "":
		return
	var k := banner_t
	var s := 1.0 + maxf(0.0, 1.0 - k / 0.25) * 1.6
	var a := 1.0 - clampf((k - 2.0) / 0.6, 0.0, 1.0)
	var cy := 118.0
	# Strahlen hinter der Schrift
	var cnt := 14
	for i in cnt:
		var ang := float(i) / float(cnt) * TAU + time * 0.6
		var p0 := Vector2(240.0, cy)
		var p1 := p0 + Vector2(cos(ang - 0.08), sin(ang - 0.08)) * 230.0
		var p2 := p0 + Vector2(cos(ang + 0.08), sin(ang + 0.08)) * 230.0
		h.draw_colored_polygon(PackedVector2Array([p0, p1, p2]), Color(banner_col, 0.09 * a))
	h.draw_rect(Rect2(0, cy - 22.0, VIEW.x, 40), Color(0, 0, 0, 0.62 * a))
	h.draw_rect(Rect2(0, cy - 22.0, VIEW.x, 1), Color(banner_col, 0.8 * a))
	h.draw_rect(Rect2(0, cy + 17.0, VIEW.x, 1), Color(banner_col, 0.8 * a))
	var size := int(24.0 * minf(s, 1.5))
	h._t(Vector2(0, cy + 8.0), banner, Color(banner_col, a), size, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, h._lore)
	if banner_sub != "":
		h._t(Vector2(0, cy + 31.0), banner_sub, Color(PAPER, a), 10, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x)


## Die große Szene: Gewitter, der Draugr reißt die Augen auf, "ES LEBT!".
func _draw_alive(h: Hud) -> void:
	var a := alive_t
	var dark := clampf(a / 0.4, 0.0, 1.0) * (1.0 - clampf((a - (ALIVE_LEN - 0.5)) / 0.45, 0.0, 1.0))
	h.draw_rect(Rect2(-8, -8, VIEW.x + 16, VIEW.y + 16), Color(0.0, 0.03, 0.02, 0.86 * dark))
	# Wolken und Wetterleuchten
	var flick := maxf(sin(a * 31.0) * sin(a * 13.0), 0.0)
	h.draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(ZAP, 0.06 * flick * dark))
	for i in 6:
		var xx := fposmod(float(i) * 97.0 + a * 24.0, VIEW.x + 80.0) - 40.0
		h.draw_circle(Vector2(xx, 14.0 + float(i % 3) * 8.0), 34.0, Color(0.02, 0.07, 0.06, 0.8 * dark))
	# der Draugr
	var rise := clampf((a - 0.75) / 0.35, 0.0, 1.0)
	var overshoot := 1.0 + 0.25 * maxf(0.0, 1.0 - (a - 0.75) / 0.25)
	var kick := maxf(0.0, 1.0 - (a - ALIVE_SHOUT2) / 0.3) * 0.12 if a >= ALIVE_SHOUT2 else 0.0  # beim zweiten Schrei schwillt er noch einmal an
	var sc := 6.0 * rise * overshoot * (1.0 + kick)
	var center := Vector2(240.0, 150.0)
	var pulse_g := 0.5 + 0.5 * sin(a * 16.0)
	if rise > 0.0:
		h.draw_circle(center, 110.0 * rise, Color(GREEN, (0.10 + 0.06 * pulse_g) * dark))
		h.draw_circle(center, 70.0 * rise, Color(GREEN, (0.10 + 0.06 * pulse_g) * dark))
		if tex != null:
			var sz := 32.0 * sc
			var mod := Color(0.55 + 0.45 * rise, 0.6 + 0.4 * rise, 0.6 + 0.4 * rise, dark)
			h.draw_texture_rect_region(tex, Rect2(center - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Rect2(6.0 * 32.0, 0.0, 32.0, 32.0), mod)
			# Augen flammen auf
			var eye := clampf((a - 1.0) / 0.2, 0.0, 1.0)
			for ex in [-5.0, 3.0]:
				var epos := center + Vector2(float(ex) * sc, -2.0 * sc)
				h.draw_circle(epos, 2.2 * sc + 4.0 * eye * pulse_g, Color(GREEN, 0.55 * eye * dark))
				h.draw_circle(epos, 1.0 * sc, Color(0.9, 1.0, 0.95, eye * dark))
			# Funken an den Elektroden
			if a > 1.05:
				for side in [-1.0, 1.0]:
					var el := center + Vector2(float(side) * 12.5 * sc, 6.0 * sc)
					var tip := el + Vector2(float(side) * 18.0 + _rng.randf_range(-6.0, 6.0), _rng.randf_range(-16.0, 16.0))
					h.draw_polyline(PackedVector2Array([el, el.lerp(tip, 0.5) + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0)), tip]), Color(ZAP, 0.9 * dark), 1.0)
	# Schrift
	if a > 0.95:
		var ta := a - 0.95 if a < ALIVE_SHOUT2 else a - ALIVE_SHOUT2  # Zeit seit dem letzten Schrei: der Text schlägt jedes Mal neu ein
		var ts := 1.0 + maxf(0.0, 1.0 - ta / 0.2) * (1.4 if a < ALIVE_SHOUT2 else 1.9)
		var shk := Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.5, 1.5)) * (1.0 if ta < 1.1 else 0.2)
		var txt_col := Color(GREEN.lightened(0.5), dark)
		var size := int(34.0 * minf(ts, 1.4))
		h._t(Vector2(shk.x + 2.0, 262.0 + shk.y + 2.0), "IT'S ALIVE!", Color(0, 0, 0, dark), size, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, h._lore)
		h._t(Vector2(shk.x, 262.0 + shk.y), "IT'S ALIVE!", txt_col, size, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, h._lore)
	if a > 3.1:
		var fa := clampf((a - 3.1) / 0.25, 0.0, 1.0) * (1.0 - clampf((a - (ALIVE_LEN - 0.4)) / 0.3, 0.0, 1.0))
		var n := voy.automat.free_left
		h._t(Vector2(0, 290.0), "%d FREISPIELE" % n, Color(GOLD, fa), 16, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, h._lore)
