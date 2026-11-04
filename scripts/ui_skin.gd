class_name UiSkin
extends RefCounted

## Pixel-Rahmen, Knöpfe, Balken und Zierleisten der Oberfläche. Alles harte Pixel im 480x320-Raster:
## Teile kommen aus assets/ui.png (Lage in UiAtlas.R, erzeugt von tools/make_ui.py), Linien sind 1-Pixel-Rechtecke.
## Nichts hier rechnet pro Bild etwas Teures: Kacheln werden einmal aus dem Atlas geschnitten.

const INK := Color("0d0b10")
const STEEL_HI := Color("8a95a6")
const STEEL := Color("5a6577")
const STEEL_LO := Color("2a303c")
const BRONZE := Color("7d6330")
const BRONZE_HI := Color("b8913a")
const BRONZE_LO := Color("4a3c20")
const GOLD := Color("d9b24a")
const PAPER := Color("e6e0cc")
const RED := Color("a83a35")

enum State { NORMAL, HOVER, SELECTED, DISABLED }

static var _atlas: Texture2D = null
static var _crew: Texture2D = null
static var _vig: Texture2D = null
static var _tiles := {}


static func atlas() -> Texture2D:
	if _atlas == null:
		_atlas = load("res://assets/ui.png") as Texture2D
	return _atlas


## Kachel (16x16) aus dem Atlas als eigene Textur, damit sie sich kacheln lässt. Ohne Bild (z. B. ohne Grafik) null.
static func tile(name: String) -> Texture2D:
	if _tiles.has(name):
		return _tiles[name]
	var t: Texture2D = null
	var a := atlas()
	if a != null:
		var img := a.get_image()
		if img != null and not img.is_empty():
			var r: Rect2i = UiAtlas.R[name]
			t = ImageTexture.create_from_image(img.get_region(r))
	_tiles[name] = t
	return t


## Ein Atlasteil an ganzzahliger Stelle; flip_x/flip_y spiegeln (für die vier Ecken).
static func spr(ci: CanvasItem, name: String, pos: Vector2, mod: Color = Color.WHITE, flip_x: bool = false, flip_y: bool = false) -> void:
	var a := atlas()
	if a == null:
		return
	var r: Rect2i = UiAtlas.R[name]
	var w := float(r.size.x)
	var h := float(r.size.y)
	var p := Vector2(roundf(pos.x), roundf(pos.y))
	var dst := Rect2(p, Vector2(w, h))
	if flip_x:
		dst.size.x = -w  # negative Größe spiegelt, die Lage bleibt die linke obere Ecke
	if flip_y:
		dst.size.y = -h
	ci.draw_texture_rect_region(a, dst, Rect2(r), mod)


static func spr_size(name: String) -> Vector2:
	var r: Rect2i = UiAtlas.R[name]
	return Vector2(r.size)


static func fill_tile(ci: CanvasItem, r: Rect2, name: String, tint: Color = Color.WHITE) -> void:
	var t := tile(name)
	if t != null:
		ci.draw_texture_rect(t, r, true, tint)
	else:
		ci.draw_rect(r, Color(0.07, 0.08, 0.11, 0.92))


static func _line_rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), col)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), col)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), col)


## Rand mit Lichtkante oben/links und Schattenkante unten/rechts (je 1 Pixel).
static func _bevel(ci: CanvasItem, r: Rect2, hi: Color, lo: Color) -> void:
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), hi)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 1), hi)
	ci.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 1, 1), lo)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), lo)


static func snap(r: Rect2) -> Rect2:
	var x0 := roundf(r.position.x)
	var y0 := roundf(r.position.y)
	return Rect2(x0, y0, roundf(r.end.x) - x0, roundf(r.end.y) - y0)


## Rahmenfarbe je Zustand.
static func accent(state: int) -> Color:
	match state:
		State.HOVER:
			return Color("c9c4ac")
		State.SELECTED:
			return GOLD
		State.DISABLED:
			return Color("2f3541")
	return BRONZE


## Panel: Pixelrahmen mit Eisenecken.
## corners 2 = große Panels (Doppelrahmen, große Eckbeschläge), 1 = Karten (feine Ecken), 0 = nur Rahmen.
## glow: zweite, schwächere Linie innen (gewählt, überfahren).
static func panel(ci: CanvasItem, rect: Rect2, col: Color = BRONZE, corners: int = 2, tile_name: String = "tile_wood", fill: bool = true, tint: Color = Color.WHITE, glow: bool = false) -> void:
	var r := snap(rect)
	if fill and tile_name != "":
		fill_tile(ci, Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2), tile_name, tint)
	_line_rect(ci, r, INK)
	var in1 := r.grow(-1)
	if corners >= 2:
		_bevel(ci, in1, STEEL.lerp(col, 0.25), STEEL_LO)
		var in3 := r.grow(-3)
		_line_rect(ci, in3, Color(col, 0.85))
		if glow:
			_line_rect(ci, r.grow(-4), Color(col, 0.35))
		var cs := spr_size("corner_l")
		var tone := Color.WHITE.lerp(col, 0.0) if col.is_equal_approx(BRONZE) else Color(0.8 + col.r * 0.4, 0.8 + col.g * 0.3, 0.8 + col.b * 0.2)
		spr(ci, "corner_l", r.position, tone)
		spr(ci, "corner_l", Vector2(r.end.x - cs.x, r.position.y), tone, true)
		spr(ci, "corner_l", Vector2(r.position.x, r.end.y - cs.y), tone, false, true)
		spr(ci, "corner_l", Vector2(r.end.x - cs.x, r.end.y - cs.y), tone, true, true)
		# Nieten in der Mitte der Längskanten
		for sx in [r.position.x + roundf(r.size.x * 0.5) - 1.0]:
			_stud(ci, Vector2(sx, r.position.y + 1))
			_stud(ci, Vector2(sx, r.end.y - 3))
	else:
		_line_rect(ci, in1, col)
		if glow:
			_line_rect(ci, r.grow(-2), Color(col, 0.35))
		else:
			_bevel(ci, r.grow(-2), Color(1, 1, 1, 0.06), Color(0, 0, 0, 0.35))
		if corners == 1 and r.size.x >= 24.0 and r.size.y >= 20.0:
			var cs2 := spr_size("corner_s")
			var tone2 := Color(0.85 + col.r * 0.5, 0.85 + col.g * 0.4, 0.85 + col.b * 0.3)
			spr(ci, "corner_s", r.position, tone2)
			spr(ci, "corner_s", Vector2(r.end.x - cs2.x, r.position.y), tone2, true)
			spr(ci, "corner_s", Vector2(r.position.x, r.end.y - cs2.y), tone2, false, true)
			spr(ci, "corner_s", Vector2(r.end.x - cs2.x, r.end.y - cs2.y), tone2, true, true)


static func _stud(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_rect(Rect2(p.x, p.y, 2, 2), BRONZE_LO)
	ci.draw_rect(Rect2(p.x, p.y, 1, 1), BRONZE_HI)


## Knopf: Lichtkante oben, Schatten unten, Rahmen in der Zustandsfarbe. Kein Weichzeichnen, nur Pixelreihen.
static func button(ci: CanvasItem, rect: Rect2, state: int, col_override: Color = Color(0, 0, 0, 0)) -> void:
	var r := snap(rect)
	var body := Color("1d222c")
	var top := Color("323a49")
	var bot := Color("12151c")
	var edge := accent(state)
	if col_override.a > 0.0:
		edge = col_override
	match state:
		State.HOVER:
			body = Color("2a303d")
			top = Color("485267")
			bot = Color("181c25")
		State.SELECTED:
			body = Color("3b2d12")
			top = Color("68511f")
			bot = Color("231a09")
		State.DISABLED:
			body = Color("12151b")
			top = Color("12151b")
			bot = Color("0d0f14")
	ci.draw_rect(r, body)
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1), top)
	ci.draw_rect(Rect2(r.position.x + 1, r.end.y - 2, r.size.x - 2, 1), bot)
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), edge.lightened(0.12))
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), edge)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), edge.darkened(0.25))
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), edge.darkened(0.35))
	if state == State.SELECTED:
		ci.draw_rect(Rect2(r.position.x + 2, r.end.y - 2, r.size.x - 4, 1), edge)


## Fortschrittsbalken: Rahmen, Glanzkante oben, Schattenkante unten, Skalenstriche bei 25/50/75 %.
static func bar(ci: CanvasItem, x: float, y: float, w: float, h: float, frac: float, col: Color, ticks: bool = true) -> void:
	x = roundf(x)
	y = roundf(y)
	w = roundf(w)
	h = roundf(h)
	ci.draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), INK)
	ci.draw_rect(Rect2(x, y, w, h), Color("181c25"))
	ci.draw_rect(Rect2(x, y, w, 1), Color("0f1218"))
	var fw := roundf(w * clampf(frac, 0.0, 1.0))
	if fw > 0.0:
		ci.draw_rect(Rect2(x, y, fw, h), col)
		ci.draw_rect(Rect2(x, y, fw, 1), col.lightened(0.5))
		if h >= 4.0:
			ci.draw_rect(Rect2(x, y + h - 1, fw, 1), col.darkened(0.35))
		if fw >= 2.0:
			ci.draw_rect(Rect2(x + fw - 1, y + 1, 1, maxf(h - 2.0, 1.0)), col.lightened(0.2))
	if ticks and w >= 30.0:
		for q in [0.25, 0.5, 0.75]:
			ci.draw_rect(Rect2(x + roundf(w * q), y, 1, h), Color(INK, 0.55))


## Dünner Balken (3 Pixel) für die Mannschaftskarten.
static func mini_bar(ci: CanvasItem, x: float, y: float, w: float, frac: float, col: Color) -> void:
	x = roundf(x)
	y = roundf(y)
	w = roundf(w)
	ci.draw_rect(Rect2(x, y, w, 3), Color("14171e"))
	var fw := roundf(w * clampf(frac, 0.0, 1.0))
	if fw > 0.0:
		ci.draw_rect(Rect2(x, y, fw, 3), col.darkened(0.2))
		ci.draw_rect(Rect2(x, y, fw, 1), col.lightened(0.35))
	ci.draw_rect(Rect2(x + roundf(w * 0.5), y, 1, 3), Color(INK, 0.5))


## Zierlinie unter Titeln: feine Doppellinie mit kleinem Stein in der Mitte (mid) und Endpunkten.
static func rule(ci: CanvasItem, x0: float, x1: float, y: float, col: Color = BRONZE, mid: bool = true) -> void:
	x0 = roundf(x0)
	x1 = roundf(x1)
	y = roundf(y)
	ci.draw_rect(Rect2(x0, y, x1 - x0, 1), Color(col, 0.9))
	ci.draw_rect(Rect2(x0, y + 1, x1 - x0, 1), Color(INK, 0.8))
	ci.draw_rect(Rect2(x0, y - 1, 2, 3), col.lightened(0.3))
	ci.draw_rect(Rect2(x1 - 2, y - 1, 2, 3), col.lightened(0.3))
	if mid:
		var m := roundf((x0 + x1) * 0.5)
		ci.draw_rect(Rect2(m - 4, y - 1, 9, 3), Color(INK, 0.95))
		ci.draw_rect(Rect2(m - 1, y - 3, 3, 7), col.lightened(0.25))
		ci.draw_rect(Rect2(m - 3, y, 7, 1), col.lightened(0.25))
		ci.draw_rect(Rect2(m, y - 1, 1, 3), PAPER)


## Große Titellinie (Hauptmenü): Schwerter links und rechts, Rune in der Mitte.
static func title_rule(ci: CanvasItem, cx: float, half: float, y: float) -> void:
	var sw := spr_size("sword")
	ci.draw_rect(Rect2(cx - half + sw.x, y, half * 2.0 - sw.x * 2.0, 1), Color(GOLD, 0.55))
	ci.draw_rect(Rect2(cx - half + sw.x, y + 1, half * 2.0 - sw.x * 2.0, 1), Color(INK, 0.8))
	spr(ci, "sword", Vector2(cx - half, y - 3))
	spr(ci, "sword", Vector2(cx + half - sw.x, y - 3), Color.WHITE, true)
	ci.draw_rect(Rect2(cx - 14, y - 1, 29, 3), Color("07080c"))
	spr(ci, "rune", Vector2(cx - 4, y - 4))


## Geflecht (Knotenwerk) als Zierleiste, waagerecht gekachelt.
static func knot_band(ci: CanvasItem, x0: float, x1: float, y: float, tint: Color = Color.WHITE) -> void:
	var a := atlas()
	if a == null:
		return
	var t := tile_of("knot")
	if t != null:
		ci.draw_texture_rect(t, Rect2(roundf(x0), roundf(y), roundf(x1 - x0), 7), true, tint)


static func tile_of(name: String) -> Texture2D:
	var key := "T:" + name
	if _tiles.has(key):
		return _tiles[key]
	var t: Texture2D = null
	var a := atlas()
	if a != null:
		var img := a.get_image()
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img.get_region(Rect2i(UiAtlas.R[name])))
	_tiles[key] = t
	return t


## Dunkle Bildränder als Dither-Muster (nur Ränder). times = 2 für die dunklere Fassung (Hauptmenü).
static func vignette(ci: CanvasItem, times: int = 1) -> void:
	if _vig == null:
		_vig = load("res://assets/vignette.png") as Texture2D
	if _vig == null:
		return
	for i in times:
		ci.draw_texture_rect(_vig, Rect2(0, 0, 480, 320), false)


## Gesicht eines Mannes (aus assets/crew.png, Zeile = Look, Pose 0) im kleinen Rahmen. pos = linke obere Ecke, 10x14.
static func portrait(ci: CanvasItem, pos: Vector2, look: int, mod: Color = Color.WHITE, rim: Color = Color("4a5568")) -> void:
	var p := Vector2(roundf(pos.x), roundf(pos.y))
	ci.draw_rect(Rect2(p.x, p.y, 10, 14), INK)
	ci.draw_rect(Rect2(p.x + 1, p.y + 1, 8, 12), Color("232a36").lerp(Color("0f1218"), 0.0))
	ci.draw_rect(Rect2(p.x + 1, p.y + 1, 8, 1), Color("323b4c"))
	ci.draw_rect(Rect2(p.x, p.y, 10, 1), rim)
	ci.draw_rect(Rect2(p.x, p.y + 1, 1, 13), rim.darkened(0.2))
	if _crew == null:
		_crew = load("res://assets/crew.png") as Texture2D
	if _crew != null:
		ci.draw_texture_rect_region(_crew, Rect2(p.x + 1, p.y + 1, 8, 12), Rect2(3, look * 16 + 4, 8, 12), mod)
	ci.draw_rect(Rect2(p.x, p.y + 13, 10, 1), INK)
	ci.draw_rect(Rect2(p.x + 9, p.y, 1, 14), INK)
