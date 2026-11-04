class_name FightGeo
extends RefCounted

const VIEW := Vector2(480, 320)
const STAGE_RECT := Rect2(0, 0, 480, 192)
const UI_BAR_Y := 192.0
const FEET := 140.0                       # Stiefelsohle aller Figuren, zugleich Drehpunkt der Kamera (Kampfbühne, hud.gd)
const HERO_X: Array[float] = [210.0, 152.0, 94.0, 36.0]     # Reihe 1..4
const FOE_X: Array[float] = [270.0, 328.0, 386.0, 444.0]
const BIG_X := 392.0                      # Riese (Kraken)
const BIG_SOLE := 164.0
const FUGE_X := 239.0
const HORIZON := 68.0
const RAIL_Y := 116.0
const DECK_Y := 134.0
const CELL := Vector2i(116, 108)          # Rig-Zelle (112x104 plus 2 px Rand)
const ANCHOR := Vector2i(42, 101)         # Pixel der Zelle, der auf (Fußmitte, FEET) liegt; gespiegelt: Spalte 73
const OLD_CELL := Vector2i(44, 56)        # alter Atlas combat.png
const OLD_ANCHOR := Vector2i(22, 52)
const RIG_TOP := 64.0                     # Scheitel über der Sohle (Rig)
const OLD_TOP := 82.0                     # Scheitel im 2x-Gerüst (41 * 2)
const BIG_TOP := 88.0
## Standardanker ab Fußmitte (x nach vorn, y nach oben), falls <id>.json fehlt oder Gerüst
const RIG_ANCHORS := {"chest": Vector2(0, 38), "head": Vector2(0, 72), "hand": Vector2(32, 30), "tip": Vector2(56, 26)}
const OLD_ANCHORS := {"chest": Vector2(0, 60), "head": Vector2(0, 96), "hand": Vector2(40, 54), "tip": Vector2(70, 52)}

static var rig := false                   # FigArt setzt es: true, wenn alle Rig-Streifen vorhanden sind und nicht --norig

static func fe() -> float:                # Figurenmaßstab für Effekte (k in D3): Rig 1,6, Gerüst 2,0
	return 1.6 if rig else 2.0

static func top(big: bool) -> float:
	return BIG_TOP if big else (RIG_TOP if rig else OLD_TOP)

static func fig_x(side: int, rank: int, big: bool) -> float:
	if big:
		return BIG_X
	return (HERO_X if side == 0 else FOE_X)[clampi(rank, 0, 3)]

static func sole(big: bool) -> float:
	return BIG_SOLE if big else FEET

## Matrix einer Schicht der Tiefe d (1,0 = Figuren). Füße (y = FEET) bleiben bei d = 1 auf ihrer Zeile.
static func layer_xf(depth: float, zoom: float, center_x: float, shake: Vector2 = Vector2.ZERO) -> Transform2D:
	var s := 1.0 + (zoom - 1.0) * depth
	var c := 240.0 + (center_x - 240.0) * depth
	return Transform2D(Vector2(s, 0.0), Vector2(0.0, s),
			Vector2(roundf(240.0 - c * s + shake.x * depth), roundf(FEET * (1.0 - s) + shake.y * depth)))

static func to_screen(p: Vector2, zoom: float, center_x: float, shake: Vector2 = Vector2.ZERO) -> Vector2:
	return layer_xf(1.0, zoom, center_x, shake) * p

static func rect_to_screen(r: Rect2, zoom: float, center_x: float, shake: Vector2 = Vector2.ZERO) -> Rect2:
	return layer_xf(1.0, zoom, center_x, shake) * r

## Matrix des Hintergrunds (Tiefe 0,35): wie layer_xf, dazu 3 % Überlappung um die Bildmitte, damit beim Wackeln (bis 8 px, mit der
## Tiefe gewichtet) und beim Schwenken am Rand kein Streifen aufblitzt.
static func back_xf(zoom: float, center_x: float, shake: Vector2 = Vector2.ZERO) -> Transform2D:
	var over := Transform2D(Vector2(1.03, 0.0), Vector2(0.0, 1.03), Vector2(240.0 * (1.0 - 1.03), FEET * (1.0 - 1.03)))
	return over * layer_xf(0.35, zoom, center_x, shake)
