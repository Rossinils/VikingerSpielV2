class_name Waves
extends RefCounted

## Gemeinsamer Wellenzustand: Ozean und Schiff lesen dieselbe Funktion.

## Spielfeld in Pixelart-Pixeln (3:2, passt ganzzahlig auf 3120x2080: Faktor 6 = 2880x1920)
const VIEW_W := 480
const VIEW_H := 320
const WATER_Y := 174.0  # Wasserlinie in der Bildmitte (darunter liegen Fahrweisen und Mannschaft)
const SHIP_X := 240.0

static var storm := 0.3  # 0.0 = ruhige See, 1.0 = Vollsturm
static var time := 0.0
static var drive := 0.0  # 0..1: wie kräftig das Schiff gerade fährt (setzt WakeLayer; Himmel und Küste lesen es)
static var flash := 0.0  # 0..1: Blitzhelligkeit (setzt RainLayer; Himmel und Wasser lesen es)


## Position eines Schwimmers (Ursprung = Schulterhöhe, Rumpf liegt unter der vorderen Wasserschicht).
static func swim_position(x: float) -> Vector2:
	var bob := sin(time * 4.0 + x * 0.1)
	return Vector2(roundf(x), roundf(WATER_Y + 1.0 + height(x, 1) + 4.0 + bob))


static func height(x: float, layer: int = 1) -> float:
	var amp := lerpf(2.0, 22.0, storm)
	var h := 0.0
	h += sin(x * 0.020 - time * (0.8 + storm * 0.6)) * amp
	h += sin(x * 0.047 - time * (1.3 + storm * 0.8) + 1.7) * amp * 0.45
	h += sin(x * 0.110 - time * 2.1 + 0.4) * amp * 0.15
	if layer == 2:  # ferne Schicht am Horizont: flach und langsam
		return sin(x * 0.035 - time * 0.4 + 4.0) * amp * 0.20 + sin(x * 0.085 - time * 0.9 + 1.0) * amp * 0.07
	if layer == 0:
		h = h * 0.6 + sin(x * 0.030 - time * 0.5 + 2.0) * amp * 0.3
	return h
