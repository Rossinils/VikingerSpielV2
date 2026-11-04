class_name SkillIcons
extends RefCounted

## Kleine Symbole für die Fertigkeiten (assets/skill_icons.png, erzeugt von tools/make_skill_icons.py):
## ein Streifen aus 16x16-Feldern, die Reihenfolge hier ist die Spalte im Bild.

const SIZE := 16
const PATH := "res://assets/skill_icons.png"
const ORDER := [
	"sword", "bash", "shield", "guardally", "sweep", "taunt",
	"axe", "cleave", "charge", "whirl", "axe_big", "rage",
	"bow", "mark", "rain", "fire_arrow", "stun", "retreat",
	"staff", "song_war", "heal", "song_calm", "cleanse", "mock",
	"musket", "reload", "pistol", "scatter", "crosshair", "bang",
	"claw", "wail", "knife", "hook", "thrown", "fork", "hammer", "fang",
	"push", "horn", "summon",
	"tentacle", "grab", "beak", "ink", "crush",
	"swap", "flee",
]

static var _tex: Texture2D = null


static func index_of(name: String) -> int:
	return ORDER.find(name)


static func texture() -> Texture2D:
	if _tex == null:
		_tex = load(PATH) as Texture2D
	return _tex


## Zeichnet das Symbol (ohne Skalierung) mit der oberen linken Ecke bei pos; nichts, wenn es das Symbol nicht gibt.
static func draw(ci: CanvasItem, name: String, pos: Vector2, tint: Color = Color.WHITE) -> void:
	var i := index_of(name)
	var t := texture()
	if i < 0 or t == null:
		return
	ci.draw_texture_rect_region(t, Rect2(pos, Vector2(SIZE, SIZE)), Rect2(float(i * SIZE), 0.0, float(SIZE), float(SIZE)), tint)
