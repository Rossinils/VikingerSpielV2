class_name EnemyLayer
extends Node2D

## Kulissen der Begegnungen (assets/enemies.png, erzeugt von tools/make_enemies.py).
## Zwei Instanzen: die hintere (front = false) liegt zwischen Himmel und hinterer Wasserschicht und zeigt
## Gegnerschiff, Insel, Dorf, Hafen usw.; die vordere (front = true) liegt vor dem Schiff, aber hinter der
## vorderen Wasserschicht und zeigt nur die Tentakel des Kraken. Alles auf ganzen Pixeln, ohne Überblendung:
## Das Bild fährt heran (gestufte Verschiebung), schaukelt mit Waves.height und sinkt oder fährt davon.
## Atlas: 4 Spalten x 3 Zeilen zu 128x96, Anker (Wasserlinie, Mitte) bei (64, 72); Tentakel: je 2 Frames zu 64x96, Anker (32, 80).

const CELL := Vector2i(128, 96)
const COLS := 4
const ANCHOR := Vector2i(64, 72)
const TENT_SIZE := Vector2i(64, 96)
const TENT_ANCHOR := Vector2i(32, 80)
const KRAKEN_CELL := 8
const TENT_CELL0 := 9

## Begegnung (Encounters.Id) -> Zelle im Atlas
const CELL_OF := {0: 2, 1: 3, 2: 7, 3: 5, 4: 4, 5: 0, 6: 1, 7: 8, 8: 6, 9: 12}
## je Zelle: x (Bildmitte), y-Versatz der Wasserlinie zur hinteren Wasserschicht, schaukelt (1) oder steht (0)
const PLACE := {
	0: {"x": 304.0, "dy": 2.0, "bob": 1},
	1: {"x": 304.0, "dy": 2.0, "bob": 1},
	2: {"x": 304.0, "dy": 2.0, "bob": 1},
	3: {"x": 290.0, "dy": -4.0, "bob": 0},
	4: {"x": 270.0, "dy": -4.0, "bob": 0},
	5: {"x": 282.0, "dy": -8.0, "bob": 0},
	6: {"x": 322.0, "dy": 2.0, "bob": 1},
	7: {"x": 330.0, "dy": 3.0, "bob": 1},
	8: {"x": 312.0, "dy": 4.0, "bob": 1},
	12: {"x": 304.0, "dy": 2.0, "bob": 1},
}
## Ereignisse auf der Strecke (assets/route_props.png, tools/make_route_props.py): Zelle ROUTE_CELL0 + (Id − ROUTE_FIRST),
## gleiche Zellgröße und gleicher Anker; sie treiben neben dem Schiff und ziehen beim Weiterfahren nach links davon.
const ROUTE_CELL0 := 100
const ROUTE_PLACE := {"x": 96.0, "dy": 3.0}  # links neben dem Heck: rechts liegt die Seekarte darüber
## x der drei Tentakel (vor dem Schiff)
const TENT_X := [196.0, 286.0, 332.0]
const TENT_VARIANT := [0, 1, 2]
const INTRO_TIME := 1.6
const EXIT_TIME := 1.8

var voy: Voyage
var front := false
var back_y := Waves.WATER_Y - 12.0

var _tex: Texture2D
var _tex_route: Texture2D
var _no_intro := false
var _cell := -1  # Zelle des gezeigten Bildes, -1 nichts
var _t := 0.0  # Zeit seit Beginn der Begegnung
var _leave_t := -1.0  # >= 0: Bild verlässt die Szene (Zeit seit Abgang)
var _sink := false  # Abgang: versinken (sonst davonfahren)
var _kraken := false
var _hull_frac := 1.0
var _crew_frac := 1.0
var _tent: Array[float] = [1.0, 1.0, 1.0]  # Höhe der Tentakel 0..1


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)  # ohne Bild nichts laden und nichts rechnen
		return
	_tex = load("res://assets/enemies.png")
	if ResourceLoader.exists("res://assets/route_props.png"):
		_tex_route = load("res://assets/route_props.png")
	_no_intro = "--shotenc" in OS.get_cmdline_user_args()  # Screenshot der ersten Begegnungsbilder: gleich an Ort und Stelle


func _process(delta: float) -> void:
	if voy == null or _tex == null:
		return
	var enc := voy.encounter
	var want: int = int(CELL_OF.get(enc, -1)) if enc >= 0 else -1
	if Encounters.is_route(enc) and not front and _tex_route != null:
		want = ROUTE_CELL0 + enc - Encounters.ROUTE_FIRST
	if want != _cell:
		if want >= 0:
			_cell = want
			_t = INTRO_TIME + 1.0 if _no_intro else 0.0
			_leave_t = -1.0
			_kraken = want == KRAKEN_CELL
			for i in 3:
				_tent[i] = 1.0 if _no_intro else 0.0
		elif _cell >= 0 and _leave_t < 0.0:
			_leave_t = 0.0
			_sink = _hostile_gone()
		elif _cell < 0:
			pass
	if _cell >= 0:
		if _leave_t >= 0.0:
			_leave_t += delta
			if _leave_t >= EXIT_TIME:
				_cell = -1
				_leave_t = -1.0
		else:
			_t += delta
			_track_battle(delta)
	queue_redraw()


func _hostile_gone() -> bool:
	# Gegner besiegt: der Bericht der Fahrt sagt "versinkt" bzw. "sinkt" -> das Bild sinkt; sonst (Flucht, Ablauf, Landgang) fährt es davon.
	if not (_cell == 0 or _cell == 1 or _cell == KRAKEN_CELL):
		return false
	var n := voy.history.size()
	for i in range(maxi(n - 3, 0), n):
		if String(voy.history[i].get("text", "")).contains("sinkt") or String(voy.history[i].get("text", "")).contains("versinkt"):
			return true
	return false


func _track_battle(delta: float) -> void:
	var b := voy.battle
	if not b.is_empty():
		_hull_frac = clampf(float(b["ehull"]) / maxf(float(b["ehull_max"]), 1.0), 0.0, 1.0)
		_crew_frac = clampf(float(b["ecrew"]) / maxf(float(b["ecrew_max"]), 1.0), 0.0, 1.0)
	elif _cell != 0 and _cell != 1 and _cell != KRAKEN_CELL:
		_hull_frac = 1.0
		_crew_frac = 1.0
	# Tentakel: bei voller Besatzung drei, dann zwei, einer, keiner; sie heben und senken sich ruhig
	var n := 3
	if not b.is_empty():
		n = clampi(ceili(_crew_frac * 3.0 - 0.001), 0, 3)
		if _hull_frac <= 0.0:
			n = 0
	var intro := clampf((_t - 0.5) / 1.2, 0.0, 1.0)
	for i in 3:
		var goal := intro if i < n else 0.0
		_tent[i] = move_toward(_tent[i], goal, delta * 0.7)


## Versatz durch Heranfahren / Abgang: gestufte ganze Pixel, kein Überblenden.
func _slide_offset() -> Vector2:
	if _leave_t >= 0.0:
		var k := clampf(_leave_t / EXIT_TIME, 0.0, 1.0)
		if _sink:
			return Vector2(0.0, floorf(k * k * 70.0 / 2.0) * 2.0)
		return Vector2(-floorf(k * k * 220.0 / 3.0) * 3.0, 0.0)
	var k2 := 1.0 - clampf(_t / INTRO_TIME, 0.0, 1.0)
	var e := k2 * k2 * k2
	return Vector2(floorf(e * 120.0 / 3.0) * 3.0, 0.0)


func _draw() -> void:
	if _cell < 0 or _tex == null:
		return
	if front:
		if _kraken:
			_draw_tentacles()
		return
	if _cell >= ROUTE_CELL0:
		var ri := _cell - ROUTE_CELL0
		var rx := float(ROUTE_PLACE["x"])
		var roff := _slide_offset()
		var ry := roundf(back_y + float(ROUTE_PLACE["dy"]) + Waves.height(rx, 0) * 0.5) + roff.y
		var rsrc := Rect2(Vector2((ri % COLS) * CELL.x, (ri / COLS) * CELL.y), Vector2(CELL))
		draw_texture_rect_region(_tex_route, Rect2(Vector2(roundf(rx) + roff.x, ry) - Vector2(ANCHOR), Vector2(CELL)), rsrc)
		return
	var p: Dictionary = PLACE[_cell]
	var x := float(p["x"])
	var off := _slide_offset()
	var wave := 0.0
	if int(p["bob"]) == 1:
		wave = Waves.height(x, 0) * 0.5
	var low := 0.0
	if _cell == 0 or _cell == 1 or _cell == KRAKEN_CELL:
		low = floorf((1.0 - _hull_frac) * 8.0)  # angeschlagen liegt das Schiff tiefer im Wasser
	var y := roundf(back_y + float(p["dy"]) + wave + low) + off.y
	var pos := Vector2(roundf(x) + off.x, y)
	var src := Rect2(Vector2((_cell % COLS) * CELL.x, (_cell / COLS) * CELL.y), Vector2(CELL))
	draw_texture_rect_region(_tex, Rect2(pos - Vector2(ANCHOR), Vector2(CELL)), src)


func _draw_tentacles() -> void:
	var frame := int(floorf(Waves.time * 0.9)) % 2
	var off := _slide_offset()
	for i in 3:
		var raise := _tent[i]
		if raise <= 0.0:
			continue
		var x: float = TENT_X[i]
		var wave := roundf(Waves.height(x, 1) * 0.4)
		var down := floorf((1.0 - raise) * 90.0 / 2.0) * 2.0
		var y := Waves.WATER_Y + 4.0 + wave + down
		var f := (frame + i) % 2
		var cell := TENT_CELL0 + int(TENT_VARIANT[i])
		var src := Rect2(Vector2((cell % COLS) * CELL.x + f * TENT_SIZE.x, (cell / COLS) * CELL.y), Vector2(TENT_SIZE))
		var pos := Vector2(roundf(x) + off.x * 0.5, y)
		draw_texture_rect_region(_tex, Rect2(pos - Vector2(TENT_ANCHOR), Vector2(TENT_SIZE)), src)
