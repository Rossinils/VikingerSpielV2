class_name StatusIcons
extends RefCounted

## Statussymbole im Deckkampf (assets/status_icons.png, erzeugt von tools/make_status_icons.py): ein Streifen aus 9x9-Feldern,
## die Reihenfolge hier ist die Spalte im Bild. Kopflos wird nichts geladen und nichts gezeichnet.

const SIZE := 9
const PATH := "res://assets/status_icons.png"
const ORDER := ["schwelle", "griff", "blind", "quetschen", "betaeubt", "blutet", "markiert", "schildwall", "kriegslied", "spott", "panik", "leer"]
## Kurzname je Symbol (für Hinweise)
const NAMES := {
	"schwelle": "an der Schwelle", "griff": "im Griff", "blind": "geblendet", "quetschen": "spannt sich", "betaeubt": "betäubt",
	"blutet": "blutet", "markiert": "markiert", "schildwall": "Schildwall", "kriegslied": "Kriegslied", "spott": "fordert heraus",
	"panik": "in Panik", "leer": "Muskete leer",
}

static var _tex: Texture2D = null


static func texture() -> Texture2D:
	if _tex == null and DisplayServer.get_name() != "headless" and ResourceLoader.exists(PATH):
		_tex = load(PATH) as Texture2D
	return _tex


## Welche Zustände eine Figur gerade hat, in fester Reihenfolge (das Gefährlichste zuerst).
static func of(f: Combat.Fighter) -> Array:
	var out: Array = []
	if f.door and f.side == 0:
		out.append("schwelle")
	if f.charge:
		out.append("quetschen")
	if f.held_by != null and not f.held_by.gone:
		out.append("griff")
	if f.stun > 0:
		out.append("betaeubt")
	if f.panic > 0:
		out.append("panik")
	if f.blind > 0:
		out.append("blind")
	if f.bleed_turns > 0:
		out.append("blutet")
	if f.mark > 0:
		out.append("markiert")
	if f.taunt > 0:
		out.append("spott")
	if f.guard > 0:
		out.append("schildwall")
	if f.buff > 0:
		out.append("kriegslied")
	if not f.loaded:
		out.append("leer")
	return out


## Zeichnet das Symbol (ohne Skalierung) mit der oberen linken Ecke bei pos.
static func draw(ci: CanvasItem, name: String, pos: Vector2, tint: Color = Color.WHITE) -> void:
	var i := ORDER.find(name)
	var t := texture()
	if i < 0 or t == null:
		return
	ci.draw_texture_rect_region(t, Rect2(pos.round(), Vector2(SIZE, SIZE)), Rect2(float(i * SIZE), 0.0, float(SIZE), float(SIZE)), tint)
