class_name ItemIcons
extends RefCounted

## Symbole der Gegenstaende und Embleme der Segen. ERZEUGT von tools/make_item_icons.py, nicht von Hand aendern.
## assets/item_icons.png: Zeile = Seltenheit (0 gewoehnlich .. 3 legendaer), Spalte = Symbol (Reihenfolge ORDER), Feld 20x20.
## assets/perk_emblems.png: ein Streifen aus 32x32-Emblemen (Reihenfolge EMBLEMS).

const TILE := 20
const INNER := 16  # das Symbol ohne Platte (Mitte des Feldes), fuer enge Zeilen
const EMBLEM := 32
const PATH := "res://assets/item_icons.png"
const EMBLEM_PATH := "res://assets/perk_emblems.png"
const ORDER := [
	"sporn", "drachenkopf", "teer", "beschlag", "planken", "tuch",
	"prunk", "sturm", "riemen", "esche", "kanone", "schwere",
	"fass", "pulver", "haengematte", "werkzeug", "truhe", "schwert",
	"axt", "speer", "dolch", "hammer", "runenstab", "leder",
	"kette", "fell", "schuppen", "mantel", "helm", "rune",
	"zahn", "hammeranhaenger", "muenze", "horn", "auge", "pfand",
]
const EMBLEMS := [
	"odin", "vorrat", "wind", "arme", "haende", "lieder",
	"zaeh", "glueck", "karte", "pulver", "ramm", "schilde",
	"sturm", "wellen",
]

static var _tex: Texture2D = null
static var _etex: Texture2D = null


static func _load() -> void:
	if _tex == null and DisplayServer.get_name() != "headless":
		_tex = load(PATH) as Texture2D
		if ResourceLoader.exists(EMBLEM_PATH):
			_etex = load(EMBLEM_PATH) as Texture2D


## Spalte eines Schluessels: "teer@2" -> Spalte von "teer" (Schiff); Ausruestung und Pfandflasche haben eigene Namen.
static func index_of(key: String) -> int:
	return ORDER.find(key.get_slice("@", 0))


## Gegenstandsschluessel (Schiff oder Ausruestung, mit oder ohne "@Seltenheit") in der Platte zeichnen: 20x20 ab pos.
static func draw(ci: CanvasItem, key: String, pos: Vector2, rarity: int, tint: Color = Color.WHITE) -> void:
	_load()
	var i := index_of(key)
	if _tex == null or i < 0:
		return
	ci.draw_texture_rect_region(_tex, Rect2(pos, Vector2(TILE, TILE)), Rect2(float(i * TILE), float(clampi(rarity, 0, 3) * TILE), float(TILE), float(TILE)), tint)


## Nur das Symbol (16x16, ohne Rand der Platte), z. B. in Zeilen, die selbst einen Seltenheitsrahmen haben.
static func draw_inner(ci: CanvasItem, key: String, pos: Vector2, rarity: int, tint: Color = Color.WHITE) -> void:
	_load()
	var i := index_of(key)
	if _tex == null or i < 0:
		return
	var off := float((TILE - INNER) / 2)
	ci.draw_texture_rect_region(_tex, Rect2(pos, Vector2(INNER, INNER)), Rect2(float(i * TILE) + off, float(clampi(rarity, 0, 3) * TILE) + off, float(INNER), float(INNER)), tint)


## Emblem eines Segens (Schluessel wie in Perks.DATA), 32x32 ab pos.
static func draw_emblem(ci: CanvasItem, perk_id: String, pos: Vector2, tint: Color = Color.WHITE) -> void:
	_load()
	var i := EMBLEMS.find(perk_id)
	if _etex == null or i < 0:
		return
	ci.draw_texture_rect_region(_etex, Rect2(pos, Vector2(EMBLEM, EMBLEM)), Rect2(float(i * EMBLEM), 0.0, float(EMBLEM), float(EMBLEM)), tint)
