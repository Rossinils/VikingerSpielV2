class_name FigArt
extends RefCounted

## Die Kampffiguren mit Körper-Rig: lädt assets/fig/<id>.png (32 Spalten zu 116x108, Zeile 0 die Figur, Zeile 1 dieselbe ganz weiß
## für den Trefferblitz), wählt zu einem Bildnamen die Spalte und zeichnet sie, gespiegelt für Gegner. Daten: scripts/fig_atlas.gd.
## Alle Figuren schauen im Streifen nach rechts, die Fußmitte liegt auf FigAtlas.ANCHOR. Fehlt einer der Streifen, bleibt das alte
## Gerüst (assets/combat.png, doppelt gezeichnet) – nie gemischt (`rig` ist nur wahr, wenn alle Streifen da sind).

const FRAMES: Array = FigAtlas.FRAMES

## Ersatz für Bilder, die ein Streifen nicht hat (Hund und Fangarm kennen nicht alle 32): der Reihe nach das erste, das es gibt.
const FALLBACK := {
	"strike_1": ["strike_0"], "follow_0": ["strike_1", "strike_0"], "follow_1": ["follow_0", "ready_0"],
	"windup_0": ["ready_0"], "windup_1": ["windup_0", "ready_0"],
	"cast_0": ["ready_0", "strike_0"], "cast_1": ["cast_0", "ready_1", "strike_0"], "cast_2": ["cast_1", "strike_0"],
	"block_0": ["ready_0"], "block_1": ["hit_0", "ready_0"], "dodge": ["hit_0"],
	"hit_1": ["hit_0"], "stun_0": ["hit_1", "hit_0"], "stun_1": ["stun_0", "hit_1"],
	"door_0": ["hit_1", "stun_0"], "door_1": ["door_0", "hit_1"],
	"fall_0": ["hit_1", "hit_0"], "fall_1": ["fall_0", "hit_1"], "fall_2": ["fall_1", "hit_1"], "dead": ["fall_2", "hit_1"],
	"cheer_0": ["ready_0"], "cheer_1": ["cheer_0", "ready_1"], "cheer_2": ["cheer_0", "ready_0"],
	"grab": ["stun_0", "hit_1"],
	"ready_0": ["idle_0"], "ready_1": ["ready_0"], "idle_1": ["idle_0"], "idle_2": ["idle_1", "idle_0"], "idle_3": ["idle_1", "idle_0"],
}

static var rig := false  # alle Streifen vorhanden und nicht --norig
static var _tex: Dictionary = {}  # Streifen je Figur (in einer Klassenvariablen, sonst zeichnet Godot ein weißes Rechteck)
static var _asked: Dictionary = {}
static var _checked := false


## Welche Streifen fehlen? (Ressourcen-Prüfung, auch ohne Fenster sicher)
static func missing() -> PackedStringArray:
	var out: PackedStringArray = []
	for id in FigAtlas.IDS:
		if not ResourceLoader.exists("res://assets/fig/%s.png" % id):
			out.append(String(id))
	return out


## Einmal prüfen, ob das Rig benutzt werden kann (Aufruf vor dem ersten Kampfbild).
static func init() -> void:
	if _checked:
		return
	_checked = true
	rig = missing().is_empty() and not OS.get_cmdline_user_args().has("--norig") and DisplayServer.get_name() != "headless"
	if not missing().is_empty() and DisplayServer.get_name() != "headless":
		push_warning("Hinweis: Rig-Figuren fehlen (%s), der Kampf zeigt die alten Figuren. tools/make_fig_rig.py erzeugt sie." % ", ".join(missing().slice(0, 4)))


## Der Streifen einer Figur, nur wenn gezeichnet wird (kopflos: null).
static func texture(id: String) -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	if _tex.has(id):
		return _tex[id]
	var t := load("res://assets/fig/%s.png" % id) as Texture2D
	_tex[id] = t
	return t


## Streifen im Hintergrund laden (Aufstellung), damit der Kampfbeginn nicht ruckelt.
static func prewarm(ids: Array) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for id in ids:
		var key := String(id)
		if _tex.has(key) or _asked.has(key):
			continue
		_asked[key] = true
		ResourceLoader.load_threaded_request("res://assets/fig/%s.png" % key)


## Zwischenspeicher leeren (am Ende des Kampfes), damit nicht alle 25 Streifen im Speicher bleiben.
static func release() -> void:
	_tex.clear()
	_asked.clear()


## Dateiname der Figur eines Kämpfers: Männer nach Rolle, Gegner nach Art.
static func id_of(f: Combat.Fighter) -> String:
	if f.side == 0:
		var ids: Array = Roles.FIG_IDS
		return String(ids[clampi(f.role, 0, ids.size() - 1)])
	return String(f.kind)


## Gibt es für diese Figur einen Streifen (der Kraken hat keinen: er bleibt ein eigenes Bild)?
static func has(id: String) -> bool:
	return FigAtlas.ANCHORS.has(id)


## Spalte eines Bildnamens (mit Ersatz); -1: Figur unbekannt.
static func column(id: String, frame: String) -> int:
	var tab: Dictionary = FigAtlas.ANCHORS.get(id, {})
	if tab.is_empty():
		return -1
	var name := frame
	var guard := 0
	while not tab.has(name) and guard < 6:
		guard += 1
		var alts: Array = FALLBACK.get(name, [])
		var found := ""
		for a in alts:
			if tab.has(a):
				found = String(a)
				break
		if found == "":
			name = "idle_0"
			break
		name = found
	return FRAMES.find(name)


## Das Bild, das wirklich gezeichnet wird (nach Ersatz).
static func resolved(id: String, frame: String) -> String:
	var c := column(id, frame)
	return String(FRAMES[c]) if c >= 0 else ""


## Ruhebild nach Zustand und Uhr: Atmen, am Zug (ready), benommen, kniend an der Schwelle.
static func rest_frame(clock: float, rank: int, ready: bool, stun: bool, door: bool) -> String:
	var t := clock + float(rank) * 0.37
	if door:
		return "door_%d" % (int(t / 0.5) % 2)
	if stun:
		return "stun_%d" % (int(t / 0.3) % 2)
	if ready:
		return "ready_%d" % (int(t / 0.25) % 2)
	return "idle_%d" % (int(t / 0.2) % 4)


## Anker eines Bildes ab Fußmitte (x nach vorn, y nach oben): "hand", "tip", "chest", "head". Gespiegelt flippt der Aufrufer x.
static func anchor(id: String, frame: String, what: String) -> Vector2:
	var tab: Dictionary = FigAtlas.ANCHORS.get(id, {})
	var name := resolved(id, frame)
	if tab.is_empty() or name == "":
		return Vector2(FightGeo.RIG_ANCHORS.get(what, Vector2.ZERO))
	var a: Array = tab[name]
	var k := {"hand": 0, "tip": 2, "chest": 4, "head": 6}.get(what, 4) as int
	return Vector2(float(a[k]), float(a[k + 1]))


## Eine Figur zeichnen. feet: Fußmitte (Stiefelsohle) in Bühnenpixeln, `base` die Abbildung Bühne -> Bild (Kamera), mirror für
## Gegner, mod Helligkeit und Tönung, white 0..1 der weiße Frame des Treffers, lift hebt die Figur (Würgegriff).
static func draw(ci: CanvasItem, id: String, frame: String, feet: Vector2, base: Transform2D, mirror: bool, mod: Color = Color.WHITE, white: float = 0.0, lift: float = 0.0) -> void:
	var tex := texture(id)
	var col := column(id, frame)
	if tex == null or col < 0:
		return
	var ax := float(FigAtlas.ANCHOR_X.get(id, FigAtlas.ANCHOR.x))
	var left := roundf(feet.x - ax)
	var top := roundf(feet.y - float(FigAtlas.ANCHOR.y) - lift)
	var cw := float(FigAtlas.CELL.x)
	var ch := float(FigAtlas.CELL.y)
	var src := Rect2(float(col) * cw, 0.0, cw, ch)
	if mirror:
		# Spiegelung an der Fußmitte: x' = 2 * feet.x - x, die Zelle liegt danach links von der Fußmitte
		ci.draw_set_transform_matrix(base * Transform2D(Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(2.0 * roundf(feet.x), 0.0)))
	else:
		ci.draw_set_transform_matrix(base)
	var dst := Rect2(left, top, cw, ch)
	ci.draw_texture_rect_region(tex, dst, src, mod)
	if white > 0.01:
		ci.draw_texture_rect_region(tex, dst, Rect2(src.position.x, ch, cw, ch), Color(1, 1, 1, clampf(white, 0.0, 1.0) * mod.a))
	ci.draw_set_transform_matrix(base)
