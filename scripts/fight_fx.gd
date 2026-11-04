class_name FightFx
extends RefCounted

## Wucht im Deckkampf: Hiebbögen, Pfeile im Flug, Heilleuchten, Lieder, Tinte, Banner mit dem Namen der Fertigkeit,
## Wackeln, Aufblitzen und kurzes Einfrieren. Reine Anzeige, rechnet nichts und kennt keine Kampfregeln.
## Die Kampfansicht (hud.gd) füttert das hier aus den Ereignissen von Combat.events und zeichnet es über die Figuren.

const FEET := 120.0

## Wirkung je Fertigkeit: [beim Ausholen, beim Treffer]. Leer = nichts.
## Ausholen: shield, notes (Lied), warsong, wail, ink, crush. Treffer: slash, chop, bash, bite.
## arrow und whip fliegen vom Angreifer zu jedem Ziel (sie stehen unter "Ausholen", entstehen aber je Ziel).
const SKILL_FX := {
	"s_hieb": ["", "slash"], "s_stoss": ["", "bash"], "s_wall": ["shield", ""], "s_deckung": ["shield", ""],
	"s_rund": ["", "slash"], "s_ruf": ["taunt", ""],
	"a_hieb": ["", "chop"], "a_spalt": ["", "chop"], "a_ansturm": ["", "chop"], "a_wirbel": ["", "chop"],
	"a_spalter": ["", "chop"], "a_wut": ["rage", ""],
	"b_schuss": ["arrow", ""], "b_mark": ["arrow", ""], "b_regen": ["arrow", ""], "b_brand": ["arrow", ""],
	"b_lahm": ["arrow", ""], "b_rueck": ["arrow", ""],
	"k_stab": ["", "bash"], "k_krieg": ["warsong", ""], "k_heil": ["notes", ""], "k_trost": ["notes", ""],
	"k_weck": ["notes", ""], "k_hohn": ["notes", ""],
	"m_schuss": ["bullet", ""], "m_nachladen": ["reload", ""], "m_pistole": ["bullet", ""], "m_streu": ["bullet", ""],
	"m_kopf": ["bullet", ""], "m_knall": ["bullet", ""],
	"f_hieb": ["", "slash"], "f_kralle": ["", "slash"], "f_pfeil": ["arrow", ""], "f_klage": ["wail", ""],
	"f_stoss": ["", "bash"], "f_messer": ["", "slash"], "f_netz": ["", "slash"], "f_armbrust": ["arrow", ""],
	"f_wurf": ["", "bash"], "f_gabel": ["", "slash"], "f_hammer": ["", "chop"], "f_biss": ["", "bite"],
	"f_ramm": ["", "bash"], "f_heilen": ["", ""], "f_deckung": ["shield", ""], "f_horn": ["horn", ""], "f_beschwoeren": ["summon", ""],
	"f_kr_peitsche": ["whip", ""], "f_kr_griff": ["whip", ""], "f_kr_schnabel": ["", "chop"], "f_kr_tinte": ["ink", ""],
	"f_kr_quetsch": ["crush", "bash"], "f_kr_wuerg": ["", "bash"],
}

var items: Array = []  # {"k", "age" (negativ = wartet noch), "dur", ...}
var banner: Dictionary = {}  # {"name", "who", "side", "t"}
var big: Dictionary = {}  # große Ansage: {"text", "sub", "col", "t", "dur"}
var freeze := 0.0
var _zoom_t := 0.0
var _zoom_dur := 0.01
var _zoom_amp := 0.0
var _zoom_focus := Vector2(240.0, 90.0)
var _slow_t := 0.0
var _slow_factor := 1.0
var _shake_t := 0.0
var _shake_dur := 0.01
var _shake_amp := 0.0
var _flash_t := 0.0
var _flash_dur := 0.01
var _flash_col := Color.WHITE


static func go_fx(sid: String) -> String:
	return String((SKILL_FX.get(sid, ["", ""]) as Array)[0])


static func hit_fx(sid: String) -> String:
	return String((SKILL_FX.get(sid, ["", ""]) as Array)[1])


## Fliegt etwas vom Angreifer zum Ziel (Pfeil, Fangarm)? Dann bleibt der Angreifer stehen, statt auszufallen.
static func is_flight(sid: String) -> bool:
	return go_fx(sid) in ["arrow", "whip", "bullet"]


## Fällt der Angreifer beim Zuschlagen nach vorn? Nur bei Nahkampf-Treffern.
static func lunges(sid: String) -> bool:
	return hit_fx(sid) != "" and not is_flight(sid)


func clear() -> void:
	items.clear()
	banner = {}
	big = {}
	freeze = 0.0
	_shake_t = 0.0
	_flash_t = 0.0
	_zoom_t = 0.0
	_slow_t = 0.0


func add(kind: String, data: Dictionary = {}, wait: float = 0.0, dur: float = 0.3) -> void:
	var it := data.duplicate()
	it["k"] = kind
	it["age"] = -wait
	it["dur"] = dur
	items.append(it)
	if items.size() > 80:
		items.pop_front()


## Kurzer Kameraschub auf einen Punkt: das Bild wächst um amp und fällt wieder zurück.
func zoom(amp: float, dur: float, focus: Vector2) -> void:
	if amp >= _zoom_amp * (_zoom_t / maxf(_zoom_dur, 0.01)):
		_zoom_amp = amp
		_zoom_t = dur
		_zoom_dur = dur
		_zoom_focus = focus


func zoom_scale() -> float:
	if _zoom_t <= 0.0:
		return 1.0
	return 1.0 + _zoom_amp * sin(PI * (1.0 - _zoom_t / maxf(_zoom_dur, 0.01)))


## Verschiebung, die den Brennpunkt beim Zoomen an seinem Platz hält.
func zoom_offset() -> Vector2:
	return _zoom_focus * (1.0 - zoom_scale())


## Zeitlupe der Anzeige (nicht der Regeln): factor < 1 für dur Sekunden.
func slowmo(factor: float, dur: float) -> void:
	_slow_factor = factor
	_slow_t = dur


func time_scale() -> float:
	return _slow_factor if _slow_t > 0.0 else 1.0


func shake(amp: float, dur: float) -> void:
	if amp >= _shake_amp * (_shake_t / maxf(_shake_dur, 0.01)):
		_shake_amp = amp
		_shake_t = dur
		_shake_dur = dur


func flash(col: Color, dur: float) -> void:
	_flash_col = col
	_flash_t = dur
	_flash_dur = dur


func show_banner(skill_name: String, who: String, side: int, icon: String = "") -> void:
	banner = {"name": skill_name, "who": who, "side": side, "t": 1.25, "icon": icon}


func show_big(text: String, sub: String, col: Color, dur: float = 2.0) -> void:
	big = {"text": text, "sub": sub, "col": col, "t": dur, "dur": dur}


## Zeit vergeht; false, solange das Bild kurz eingefroren ist (dann soll auch die Anzeige warten).
func tick(delta: float) -> bool:
	if freeze > 0.0:
		freeze -= delta
		return false
	_slow_t = maxf(_slow_t - delta, 0.0)
	_zoom_t = maxf(_zoom_t - delta, 0.0)
	delta *= time_scale()
	for it in items:
		it["age"] = float(it["age"]) + delta
		if String(it["k"]) == "cue" and float(it["age"]) >= 0.0 and not bool(it.get("done", false)):
			it["done"] = true
			_do_cue(it)
	items = items.filter(func(d: Dictionary) -> bool: return float(d["age"]) <= float(d["dur"]) and not bool(d.get("done", false)))
	if not banner.is_empty():
		banner["t"] = float(banner["t"]) - delta
		if float(banner["t"]) <= 0.0:
			banner = {}
	if not big.is_empty():
		big["t"] = float(big["t"]) - delta
		if float(big["t"]) <= 0.0:
			big = {}
	_shake_t = maxf(_shake_t - delta, 0.0)
	_flash_t = maxf(_flash_t - delta, 0.0)
	return true


## Eine Wirkung, die erst im Augenblick des Treffers eintreten soll: "shake" (amp, d), "flash" (col, d), "freeze" (d).
func cue(what: String, data: Dictionary, wait: float) -> void:
	var it := data.duplicate()
	it["what"] = what
	add("cue", it, wait, 1.0)


func _do_cue(it: Dictionary) -> void:
	match String(it["what"]):
		"shake":
			shake(float(it["amp"]), float(it["d"]))
		"flash":
			flash(it["col"] as Color, float(it["d"]))
		"freeze":
			freeze = float(it["d"])
		"slowmo":
			slowmo(float(it["f"]), float(it["d"]))
		"zoom":
			zoom(float(it["amp"]), float(it["d"]), Vector2(float(it["fx"]), float(it["fy"])))


## Verschiebung des ganzen Kampfbildes in Pixeln, solange es wackelt.
func offset() -> Vector2:
	if _shake_t <= 0.0:
		return Vector2.ZERO
	var k := _shake_amp * _shake_t / maxf(_shake_dur, 0.01)
	var ms := float(Time.get_ticks_msec())
	return Vector2(roundf(sin(ms * 0.11) * k), roundf(cos(ms * 0.14) * k))


func flash_color() -> Color:
	if _flash_t <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(_flash_col, _flash_col.a * _flash_t / maxf(_flash_dur, 0.01))


func draw(ci: CanvasItem) -> void:
	for it in items:
		var age := float(it["age"])
		if age < 0.0:
			continue
		var u := clampf(age / float(it["dur"]), 0.0, 1.0)
		match String(it["k"]):
			"slash":
				_slash(ci, it, u)
			"bash":
				_bash(ci, it, u)
			"arrow":
				_arrow(ci, it, u)
			"whip":
				_whip(ci, it, u)
			"bite":
				_bite(ci, it, u)
			"heal":
				_heal(ci, it, u)
			"notes":
				_notes(ci, it, u)
			"shield":
				_shield(ci, it, u)
			"ink":
				_ink(ci, it, u)
			"ring":
				_ring(ci, it, u)
			"dust":
				_dust(ci, it, u)
			"bullet":
				_bullet(ci, it, u)
			"muzzle":
				_muzzle(ci, it, u)
			"spark":
				_spark(ci, it, u)


func _slash(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var x := float(it["x"])
	var y := float(it["y"])
	var d := float(it.get("dir", 1.0))
	var heavy := bool(it.get("heavy", false))
	var faint := bool(it.get("faint", false))
	var a0 := Vector2(x - d * 12.0, y - 14.0)
	var a1 := Vector2(x + d * 12.0, y + 12.0)
	var p := clampf(u / 0.5, 0.0, 1.0)
	var al := (1.0 - clampf((u - 0.5) / 0.5, 0.0, 1.0)) * (0.3 if faint else 1.0)
	var col := Color(1.0, 0.86, 0.55, al) if heavy else Color(1.0, 0.97, 0.88, al)
	var tip := a0.lerp(a1, p)
	ci.draw_line(a0, tip, col, 3.0 if heavy else 2.0)
	ci.draw_line(a0 + Vector2(1, 3), tip + Vector2(1, 3), Color(col, al * 0.4), 1.0)
	if bool(it.get("crit", false)):
		var b0 := Vector2(x + d * 12.0, y - 14.0)
		var b1 := Vector2(x - d * 12.0, y + 12.0)
		ci.draw_line(b0, b0.lerp(b1, p), Color(0.98, 0.8, 0.3, al), 2.0)
	if u > 0.4 and not faint:
		var sp := (u - 0.4) / 0.6
		for k in 5:
			var ang := -1.2 + float(k) * 0.6
			var v := Vector2(cos(ang) * d, sin(ang))
			ci.draw_line(a1 + v * (3.0 + 4.0 * sp), a1 + v * (5.0 + 9.0 * sp), Color(col, al * 0.8), 1.0)


func _bash(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var c := Vector2(float(it["x"]), float(it["y"]))
	var r := 3.0 + (20.0 if bool(it.get("heavy", false)) else 14.0) * u
	var col := Color(1.0, 0.95, 0.8, 1.0 - u)
	ci.draw_arc(c, r, 0.0, TAU, 22, col, 2.0)
	if u < 0.7:
		for k in 4:
			var ang := PI * 0.25 + float(k) * PI * 0.5
			var v := Vector2(cos(ang), sin(ang))
			ci.draw_line(c + v * (r * 0.4), c + v * (r * 0.4 + 5.0), Color(col, col.a * 0.8), 1.0)


func _arrow(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var from := Vector2(float(it["x"]), float(it["y"]))
	var to := Vector2(float(it["x2"]), float(it["y2"]))
	var pos := from.lerp(to, u) + Vector2(0.0, -9.0 * sin(PI * u))
	var slope := (to - from).normalized() + Vector2(0.0, -0.5 * cos(PI * u))
	var dv := slope.normalized()
	var al := 1.0 - (clampf((u - 0.6) / 0.4, 0.0, 1.0) if bool(it.get("miss", false)) else 0.0)
	var tail := pos - dv * 9.0
	ci.draw_line(tail, pos, Color(0.8, 0.64, 0.4, al), 1.0)
	ci.draw_line(pos, pos + dv * 2.0, Color(0.92, 0.93, 0.97, al), 2.0)
	ci.draw_line(tail, tail + dv.rotated(2.5) * 3.0, Color(0.6, 0.72, 0.5, al), 1.0)
	ci.draw_line(tail, tail + dv.rotated(-2.5) * 3.0, Color(0.6, 0.72, 0.5, al), 1.0)


func _whip(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var a := Vector2(float(it["x"]), float(it["y"]))
	var b := Vector2(float(it["x2"]), float(it["y2"]))
	var c := Vector2((a.x + b.x) * 0.5, minf(a.y, b.y) - 38.0)
	var p := clampf(u / 0.5, 0.0, 1.0)
	var al := 1.0 - clampf((u - 0.6) / 0.4, 0.0, 1.0)
	var pts := PackedVector2Array()
	for k in 14:
		var t := p * float(k) / 13.0
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	ci.draw_polyline(pts, Color(0.23, 0.15, 0.32, al), 5.0)
	ci.draw_polyline(pts, Color(0.42, 0.29, 0.54, al), 3.0)
	ci.draw_polyline(pts, Color(0.54, 0.38, 0.65, al), 1.0)
	if u > 0.5:
		var q := (u - 0.5) / 0.5
		ci.draw_arc(b, 3.0 + 12.0 * q, 0.0, TAU, 18, Color(0.55, 0.4, 0.7, 1.0 - q), 2.0)


func _bite(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var x := float(it["x"])
	var y := float(it["y"])
	var gap := 10.0 * (1.0 - clampf(u / 0.45, 0.0, 1.0))
	var al := 1.0 - clampf((u - 0.6) / 0.4, 0.0, 1.0)
	var col := Color(0.96, 0.94, 0.88, al)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y - 16 - gap), Vector2(x + 8, y - 16 - gap), Vector2(x, y - 4 - gap)]), col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y + 10 + gap), Vector2(x + 8, y + 10 + gap), Vector2(x, y - 2 + gap)]), col)
	if u > 0.45:
		ci.draw_line(Vector2(x - 6, y - 3), Vector2(x + 6, y - 3), Color(0.8, 0.2, 0.2, al), 1.0)


func _heal(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var x := float(it["x"])
	var y := float(it["y"])
	var al := 1.0 - u
	ci.draw_arc(Vector2(x, y + 6.0), 5.0 + 11.0 * u, 0.0, TAU, 20, Color(0.55, 0.95, 0.65, al * 0.7), 1.0)
	for i in 8:
		var fr := fmod(float(i) * 0.37, 1.0)
		var px := x + sin(float(i) * 2.1 + u * 3.0) * 11.0
		var py := y + 14.0 - (36.0 * u) * (0.55 + 0.45 * fr)
		var col := Color(0.6, 1.0, 0.7, al) if i % 2 == 0 else Color(1.0, 1.0, 0.8, al)
		ci.draw_rect(Rect2(roundf(px), roundf(py), 2, 2), col)
		ci.draw_rect(Rect2(roundf(px) - 1, roundf(py) + 1, 4, 0), Color(col, al * 0.6))


func _notes(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var x := float(it["x"])
	var y := float(it["y"])
	var col0: Color = it.get("col", Color(0.7, 0.85, 1.0))
	for i in 3:
		var q := clampf(u * 1.25 - float(i) * 0.15, 0.0, 1.0)
		if q <= 0.0:
			continue
		var px := roundf(x + 8.0 + float(i) * 8.0 + sin(q * 6.0 + float(i)) * 3.0)
		var py := roundf(y - q * 34.0)
		var col := Color(col0, sin(q * PI))
		ci.draw_rect(Rect2(px, py, 3, 2), col)
		ci.draw_rect(Rect2(px + 2, py - 6, 1, 7), col)
		ci.draw_rect(Rect2(px + 3, py - 6, 2, 1), col)


func _shield(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var c := Vector2(float(it["x"]), float(it["y"]))
	var al := sin(PI * clampf(u, 0.0, 1.0))
	ci.draw_arc(c, 15.0 + 3.0 * u, -PI * 0.45, PI * 0.45, 14, Color(0.55, 0.75, 1.0, al), 3.0)
	ci.draw_arc(c, 12.0 + 3.0 * u, -PI * 0.4, PI * 0.4, 12, Color(0.9, 0.95, 1.0, al * 0.8), 1.0)


func _ink(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var al := 0.55 * (1.0 - u * u)
	for i in 16:
		var cx := 22.0 + float((i * 53) % 215)
		var cy := 62.0 + float((i * 37) % 56)
		var r := (7.0 + float((i * 7) % 9)) * (0.4 + u * 1.2)
		ci.draw_circle(Vector2(cx, cy), r, Color(0.11, 0.05, 0.19, al))
	for i in 8:
		var bx := 30.0 + float((i * 71) % 190)
		var by := 110.0 - u * (30.0 + float((i * 13) % 25))
		ci.draw_arc(Vector2(bx, by), 1.0 + float(i % 3), 0.0, TAU, 8, Color(0.6, 0.5, 0.8, (1.0 - u) * 0.8), 1.0)


func _ring(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var c := Vector2(float(it["x"]), float(it["y"]))
	var r := 3.0 + float(it.get("r", 16.0)) * u
	var col: Color = it.get("col", Color(1, 1, 1))
	ci.draw_arc(c, r, 0.0, TAU, 24, Color(col, col.a * (1.0 - u)), float(it.get("w", 2.0)))


## Kugelspur: ein heller Strich, der schneller fliegt als jeder Pfeil.
func _bullet(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var from := Vector2(float(it["x"]), float(it["y"]))
	var to := Vector2(float(it["x2"]), float(it["y2"]))
	var pos := from.lerp(to, u)
	var dv := (to - from).normalized()
	var al := 1.0 - (clampf((u - 0.7) / 0.3, 0.0, 1.0) if bool(it.get("miss", false)) else 0.0)
	ci.draw_line(pos - dv * 16.0, pos, Color(1.0, 0.85, 0.4, 0.45 * al), 3.0)
	ci.draw_line(pos - dv * 12.0, pos, Color(1.0, 0.97, 0.8, al), 1.0)
	ci.draw_rect(Rect2(roundf(pos.x) - 1, roundf(pos.y) - 1, 2, 2), Color(1, 1, 1, al))


## Mündungsfeuer und Pulverrauch an der Waffe.
func _muzzle(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var x := float(it["x"])
	var y := float(it["y"])
	var d := float(it.get("dir", 1.0))
	if u < 0.3:
		var s := 1.0 - u / 0.3
		var pts := PackedVector2Array([
			Vector2(x, y - 2.0 * s), Vector2(x + d * 14.0 * s, y - 6.0 * s), Vector2(x + d * 7.0 * s, y),
			Vector2(x + d * 16.0 * s, y + 1.0), Vector2(x + d * 7.0 * s, y + 3.0 * s), Vector2(x + d * 12.0 * s, y + 7.0 * s),
			Vector2(x, y + 2.0 * s)])
		ci.draw_colored_polygon(pts, Color(1.0, 0.82, 0.3, 0.95))
		ci.draw_circle(Vector2(x + d * 3.0, y), 3.0 * s + 1.0, Color(1, 1, 0.9, 0.95))
	for i in 6:
		var k := float(i) / 5.0
		var px := x + d * (4.0 + 22.0 * u * (0.5 + k * 0.7)) + sin(float(i) * 2.3) * 3.0
		var py := y - 3.0 * u * 8.0 * (0.4 + k) + sin(float(i) * 1.7) * 2.0
		ci.draw_circle(Vector2(px, py), 2.0 + 5.0 * u * (0.6 + k * 0.5), Color(0.62, 0.6, 0.6, 0.5 * (1.0 - u)))


## Funken beim Treffer: Splitter in der Farbe des Getroffenen (Blut, Knochenstaub, Tinte, Gold bei Krit).
func _spark(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var x := float(it["x"])
	var y := float(it["y"])
	var d := float(it.get("dir", 1.0))
	var col: Color = it.get("col", Color(0.9, 0.3, 0.25))
	var n := int(it.get("n", 6))
	for i in n:
		var a := -2.4 + float(i) * (2.2 / maxf(float(n - 1), 1.0)) + sin(float(i) * 3.1) * 0.3
		var sp := 22.0 + float((i * 17) % 19)
		var px := x + cos(a) * sp * u * d
		var py := y + sin(a) * sp * u + 38.0 * u * u
		var al := 1.0 - u
		ci.draw_rect(Rect2(roundf(px), roundf(py), 2, 2), Color(col, al))
		if i % 3 == 0:
			ci.draw_rect(Rect2(roundf(px) - 1, roundf(py) + 1, 1, 1), Color(col, al * 0.6))


func _dust(ci: CanvasItem, it: Dictionary, u: float) -> void:
	var x := float(it["x"])
	for i in 6:
		var px := x - 15.0 + float(i) * 6.0 + (u * 8.0 if i % 2 == 0 else -u * 8.0)
		var py := FEET - 2.0 - u * (5.0 + float(i % 3) * 3.0)
		ci.draw_circle(Vector2(px, py), 2.0 + 3.0 * u, Color(0.45, 0.33, 0.22, 0.6 * (1.0 - u)))
