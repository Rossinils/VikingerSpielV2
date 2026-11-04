class_name FightStage
extends RefCounted

## Die Bühne des Deckkampfs: Himmel, Meer, Gegnerschiff, Reling und Deck je Ort, dazu Nebel, Lampenschein, Blitz, Regen,
## der Lichtkegel auf den Handelnden und der Rand der Bühne. Reine Anzeige: alles wird nur gezeichnet.
## Hintergrund, Reling und Deck sind in halber Auflösung gemalt (tools/make_stage_art.py, Lage in stage_atlas.gd) und
## werden doppelt gezeichnet, damit sie dieselbe Pixelgröße haben wie die doppelt großen Kampffiguren.
## Reihenfolge im Hud: draw_back, (Riesen), draw_deck, draw_mid, Figuren, draw_front.
## Ohne Bild (Headless) oder bei Settings.stage_fx = 0 (Kampfbild "schlicht") fällt der bewegte Zierrat weg.

const STAGE_H := 192.0   # Unterkante der Bühne (Deck endet hier), darunter stehen Meldungen und Karten
const DECK_TOP := 134.0  # Oberkante des Decks
const RAIL_TOP_Y := 116.0  # Oberkante der Reling
const VIEW_W := 480.0

## Je Ort: Gegnerschiff (Zelle in enemies.png, Höhe des Zuschnitts über der Reling, Mitte x, Tönung), Lichtfarbe der Lampen,
## Nebelfarbe und -stärke, Tönung der ganzen Bühne, Himmelsfarbe für Wellenglanz. lamps: x der Pfosten (Anzeigepixel).
const THEMES := {
	"draugr": {"cell": 0, "src_y": 0, "cut": 56, "cx": 378.0, "tint": Color(0.62, 0.78, 0.72), "lamp": Color(0.5, 1.0, 0.75),
		"fog": Color(0.5, 0.85, 0.75), "fog_a": 0.55, "grade": Color(0.04, 0.26, 0.2, 0.16), "glint": Color(0.5, 0.9, 0.8), "lamps": [70.0, 382.0], "rain": false, "bolt": false},
	"raeuber": {"cell": 1, "src_y": 0, "cut": 52, "cx": 380.0, "tint": Color(0.72, 0.6, 0.56), "lamp": Color(1.0, 0.62, 0.26),
		"fog": Color(0.85, 0.55, 0.4), "fog_a": 0.3, "grade": Color(0.3, 0.1, 0.02, 0.14), "glint": Color(1.0, 0.7, 0.4), "lamps": [70.0, 382.0], "rain": false, "bolt": false},
	"haendler": {"cell": 2, "src_y": 0, "cut": 52, "cx": 378.0, "tint": Color(0.7, 0.68, 0.72), "lamp": Color(1.0, 0.85, 0.5),
		"fog": Color(0.8, 0.75, 0.75), "fog_a": 0.25, "grade": Color(0.1, 0.1, 0.25, 0.12), "glint": Color(1.0, 0.85, 0.6), "lamps": [70.0, 382.0], "rain": false, "bolt": false},
	"dorf": {"cell": 4, "src_y": 12, "cut": 52, "cx": 372.0, "tint": Color(0.75, 0.62, 0.62), "lamp": Color(1.0, 0.66, 0.3),
		"fog": Color(0.9, 0.6, 0.5), "fog_a": 0.28, "grade": Color(0.3, 0.08, 0.04, 0.13), "glint": Color(1.0, 0.7, 0.45), "lamps": [70.0, 330.0], "rain": false, "bolt": false},
	"kraken": {"cell": -1, "src_y": 0, "cut": 0, "cx": 0.0, "tint": Color(0.6, 0.55, 0.7), "lamp": Color(0.7, 0.6, 1.0),
		"fog": Color(0.45, 0.4, 0.65), "fog_a": 0.5, "grade": Color(0.12, 0.06, 0.25, 0.18), "glint": Color(0.6, 0.55, 0.9), "lamps": [], "rain": true, "bolt": true},
}

static var _loaded := false
static var _back: Texture2D = null
static var _rail: Texture2D = null
static var _deck: Texture2D = null
static var _glow: Texture2D = null
static var _fog: Texture2D = null
static var _enemies: Texture2D = null
static var _ship: Texture2D = null


static func _ensure() -> bool:
	if _loaded:
		return _back != null
	_loaded = true
	if DisplayServer.get_name() == "headless":
		return false
	_back = load("res://assets/stage_back.png") as Texture2D
	_rail = load("res://assets/stage_rail.png") as Texture2D
	_deck = load("res://assets/stage_deck.png") as Texture2D
	_glow = load("res://assets/stage_glow.png") as Texture2D
	_fog = load("res://assets/stage_fog.png") as Texture2D
	_enemies = load("res://assets/enemies.png") as Texture2D
	_ship = load("res://assets/ship.png") as Texture2D
	return _back != null


static func theme_for(formation: String) -> String:
	return formation if THEMES.has(formation) else "haendler"


static func _idx(theme: String) -> int:
	return maxi(StageAtlas.ORTE.find(theme), 0)


static func _fx_on() -> bool:
	return Settings.stage_fx != 0


## Himmel, Meer, Gegnerschiff, eigenes Segel und Reling. dim (0..1) dunkelt das Ganze ab (der Handelnde tritt ins Licht).
static func draw_back(ci: CanvasItem, formation: String, t: float, dim: float) -> void:
	if not _ensure():
		ci.draw_rect(Rect2(0, 0, VIEW_W, STAGE_H), Color(0.02, 0.03, 0.05))
		return
	var th := theme_for(formation)
	var d: Dictionary = THEMES[th]
	var i := _idx(th)
	var bs := StageAtlas.BACK_SIZE
	ci.draw_texture_rect_region(_back, Rect2(0, 0, VIEW_W, float(bs.y) * 2.0), Rect2(0, float(i * bs.y), float(bs.x), float(bs.y)))
	if _fx_on():
		_draw_glints(ci, d, t)
	var tint: Color = d["tint"]
	# Gegnerschiff: nur Segel, Mast und Bug über der Reling (der Rumpf liegt unter dem Deck)
	if int(d["cell"]) >= 0 and _enemies != null:
		var cell := int(d["cell"])
		var cut := float(d["cut"])
		var src := Rect2(float((cell % 4) * 128), float((cell / 4) * 96 + int(d["src_y"])), 128.0, cut)
		var dest := Rect2(float(d["cx"]) - 128.0, RAIL_TOP_Y + 2.0 - cut * 2.0, 256.0, cut * 2.0)
		ci.draw_texture_rect_region(_enemies, dest, src, tint)
	# eigenes Segel (Mitte des Schiffsbildes bei voller Besegelung)
	if _ship != null:
		var fw := 220.0
		var fh := 156.0
		var src2 := Rect2(15.0 * fw + 58.0, 4.0 * fh + 26.0, 102.0, 62.0)
		ci.draw_texture_rect_region(_ship, Rect2(2.0, RAIL_TOP_Y + 2.0 - 124.0, 204.0, 124.0), src2, Color(tint.r * 0.78, tint.g * 0.78, tint.b * 0.8))
	var rs := StageAtlas.RAIL_SIZE
	if _rail != null:
		ci.draw_texture_rect_region(_rail, Rect2(0, float(StageAtlas.RAIL_TOP) * 2.0, VIEW_W, float(rs.y) * 2.0), Rect2(0, float(i * rs.y), float(rs.x), float(rs.y)))
	if dim > 0.0:
		ci.draw_rect(Rect2(0, 0, VIEW_W, DECK_TOP), Color(0.0, 0.0, 0.02, dim))


## Das Deck beider Schiffe mit der Enterbrücke in der Mitte.
static func draw_deck(ci: CanvasItem, formation: String, dim: float) -> void:
	if not _ensure() or _deck == null:
		return
	var i := _idx(theme_for(formation))
	var ds := StageAtlas.DECK_SIZE
	ci.draw_texture_rect_region(_deck, Rect2(0, DECK_TOP, VIEW_W, float(ds.y) * 2.0), Rect2(0, float(i * ds.y), float(ds.x), float(ds.y)))
	if dim > 0.0:
		ci.draw_rect(Rect2(0, DECK_TOP, VIEW_W, STAGE_H - DECK_TOP), Color(0.0, 0.0, 0.02, dim * 0.85))


## Zwischen Hintergrund und Figuren: Nebelbank, Lampen mit Schein, Lichtpfützen der Lampen auf dem Deck.
static func draw_mid(ci: CanvasItem, formation: String, t: float) -> void:
	if not _ensure():
		return
	var th := theme_for(formation)
	var d: Dictionary = THEMES[th]
	if _fx_on() and _fog != null:
		_draw_fog(ci, d, t, 88.0, 70.0, float(d["fog_a"]) * 0.6, 5.0, 0.0)
	var lamp: Color = d["lamp"]
	for lx in d["lamps"]:
		var x := float(lx)
		var fl := 0.78 + 0.14 * sin(t * 7.3 + x) + 0.08 * sin(t * 13.1 + x * 0.3)
		_lantern(ci, x, 100.0, lamp, fl)
		if _glow != null and _fx_on():
			var ball := StageAtlas.GLOW_BALL
			var pool := StageAtlas.GLOW_POOL
			ci.draw_texture_rect_region(_glow, Rect2(x - 44.0, 100.0 - 44.0, 88.0, 88.0), ball, Color(lamp, 0.5 * fl))
			ci.draw_texture_rect_region(_glow, Rect2(x - 96.0, DECK_TOP + 6.0, 192.0, 44.0), pool, Color(lamp, 0.3 * fl))


## Über den Figuren: Nebelschleier, Regen, Blitz und die Tönung des Ortes.
static func draw_front(ci: CanvasItem, formation: String, t: float) -> void:
	var th := theme_for(formation)
	var d: Dictionary = THEMES[th]
	if _ensure() and _fx_on():
		if _fog != null:
			_draw_fog(ci, d, t, 140.0, 54.0, float(d["fog_a"]) * 0.45, 9.0, 120.0)
		if bool(d["rain"]):
			_draw_rain(ci, t)
		if bool(d["bolt"]):
			_draw_bolt(ci, t)
	var g: Color = d["grade"]
	ci.draw_rect(Rect2(0, 0, VIEW_W, STAGE_H), g)


## Der dunkle Rand der Bühne (liegt fest auf dem Bild, wackelt nicht mit): strength 0,3 normal, mehr bei großen Ansagen.
static func draw_vignette(ci: CanvasItem, strength: float) -> void:
	for k in 9:
		var a := strength * (1.0 - float(k) / 9.0)
		ci.draw_rect(Rect2(float(k) * 4.0, 0, 4, STAGE_H), Color(0, 0, 0, a * 0.8))
		ci.draw_rect(Rect2(VIEW_W - float(k + 1) * 4.0, 0, 4, STAGE_H), Color(0, 0, 0, a * 0.8))
		if k < 6:
			ci.draw_rect(Rect2(0, float(k) * 3.0, VIEW_W, 3), Color(0, 0, 0, a * 0.7))
		if k < 5:
			ci.draw_rect(Rect2(0, STAGE_H - float(k + 1) * 4.0, VIEW_W, 4), Color(0, 0, 0, a * 0.8))


## Weicher Schatten unter einer Figur (Breite w).
static func draw_shadow(ci: CanvasItem, x: float, feet: float, w: float, a: float) -> void:
	if _ensure() and _glow != null:
		ci.draw_texture_rect_region(_glow, Rect2(x - w * 0.5, feet - 7.0, w, 16.0), StageAtlas.GLOW_POOL, Color(0, 0, 0, a))
	else:
		ci.draw_rect(Rect2(x - w * 0.25, feet - 1.0, w * 0.5, 3.0), Color(0, 0, 0, 0.4))


## Lichtkegel auf einen Handelnden: Pfütze auf dem Deck und ein Strahl von oben. cold: kaltes Licht (Gegnerzug).
static func draw_spot(ci: CanvasItem, x: float, feet: float, cold: bool, amount: float, t: float) -> void:
	if amount <= 0.0:
		return
	var col := Color(0.62, 0.78, 1.0) if cold else Color(1.0, 0.86, 0.55)
	var pulse := 0.94 + 0.06 * sin(t * 3.1)
	# Strahl von oben: oben schmal und blass, unten breit und heller
	var pts := PackedVector2Array([Vector2(x - 16.0, 0.0), Vector2(x + 16.0, 0.0), Vector2(x + 52.0, feet + 4.0), Vector2(x - 52.0, feet + 4.0)])
	var cols := PackedColorArray([Color(col, 0.0), Color(col, 0.0), Color(col, 0.2 * amount * pulse), Color(col, 0.2 * amount * pulse)])
	ci.draw_polygon(pts, cols)
	if _ensure() and _glow != null:
		var pool := StageAtlas.GLOW_POOL
		ci.draw_texture_rect_region(_glow, Rect2(x - 78.0, feet - 20.0, 156.0, 52.0), pool, Color(col, 0.75 * amount * pulse))
		ci.draw_texture_rect_region(_glow, Rect2(x - 42.0, feet - 12.0, 84.0, 30.0), pool, Color(1.0, 1.0, 0.95, 0.35 * amount * pulse))


# --- Einzelteile ------------------------------------------------------------------------------

static func _lantern(ci: CanvasItem, x: float, y: float, col: Color, fl: float) -> void:
	ci.draw_rect(Rect2(x - 1.0, y - 8.0, 2.0, 6.0), Color(0.12, 0.09, 0.07))  # Aufhängung
	ci.draw_rect(Rect2(x - 4.0, y - 3.0, 8.0, 10.0), Color(0.07, 0.06, 0.06))  # Rahmen
	ci.draw_rect(Rect2(x - 3.0, y - 2.0, 6.0, 8.0), Color(col, 0.55 * fl + 0.3))
	ci.draw_rect(Rect2(x - 1.0, y, 2.0, 4.0), Color(1.0, 1.0, 0.9, 0.9 * fl))
	ci.draw_rect(Rect2(x - 5.0, y - 4.0, 10.0, 2.0), Color(0.12, 0.09, 0.07))  # Dach


static func _draw_glints(ci: CanvasItem, d: Dictionary, t: float) -> void:
	var col: Color = d["glint"]
	for k in 22:
		var h := fposmod(float(k) * 0.6180339 + 0.13, 1.0)
		var y := 72.0 + h * 40.0
		var speed := 3.0 + h * 9.0
		var x := fposmod(float(k) * 97.0 + t * speed * (1.0 if k % 2 == 0 else -1.0), VIEW_W + 40.0) - 20.0
		var w := 6.0 + float((k * 7) % 11)
		var a := (0.18 + 0.2 * h) * (0.5 + 0.5 * sin(t * 1.7 + float(k) * 2.3))
		ci.draw_rect(Rect2(roundf(x), roundf(y), w, 2.0), Color(col, a))


static func _draw_fog(ci: CanvasItem, d: Dictionary, t: float, y: float, h: float, a: float, speed: float, phase: float) -> void:
	var col: Color = d["fog"]
	var fs := StageAtlas.FOG_SIZE
	var x0 := -fposmod(t * speed + phase, float(fs.x))
	var k := 0
	while x0 + float(k * fs.x) < VIEW_W:
		ci.draw_texture_rect_region(_fog, Rect2(x0 + float(k * fs.x), y, float(fs.x), h), Rect2(0, 0, float(fs.x), float(fs.y)), Color(col, a))
		k += 1


static func _draw_rain(ci: CanvasItem, t: float) -> void:
	var col := Color(0.75, 0.8, 1.0, 0.32)
	for k in 70:
		var h := fposmod(float(k) * 0.7548776 + 0.31, 1.0)
		var fall := fposmod(t * (150.0 + 70.0 * h) + float(k) * 53.0, STAGE_H + 20.0) - 10.0
		var x := fposmod(float(k) * 71.0 - fall * 0.35, VIEW_W)
		ci.draw_line(Vector2(x, fall), Vector2(x - 3.0, fall + 9.0), Color(col, col.a * (0.5 + 0.5 * h)), 1.0)


static func _draw_bolt(ci: CanvasItem, t: float) -> void:
	var period := 4.6
	var n := floorf(t / period)
	var ph := fposmod(t, period)
	var level := 0.0
	if ph < 0.1:
		level = 1.0
	elif ph < 0.22:
		level = 0.35
	elif ph > 0.3 and ph < 0.36:
		level = 0.6
	if level <= 0.0:
		return
	ci.draw_rect(Rect2(0, 0, VIEW_W, STAGE_H), Color(0.7, 0.75, 1.0, 0.2 * level))
	if ph < 0.2:
		var x := 60.0 + fposmod(n * 137.0, 340.0)
		var pts := PackedVector2Array()
		var px := x
		var py := 0.0
		pts.append(Vector2(px, py))
		for s in 8:
			px += float(((int(n) * 7 + s * 13) % 17) - 8) * 1.2
			py += 9.0
			pts.append(Vector2(px, py))
		ci.draw_polyline(pts, Color(0.85, 0.9, 1.0, 0.9 * level), 2.0)
		ci.draw_polyline(pts, Color(1.0, 1.0, 1.0, level), 1.0)
