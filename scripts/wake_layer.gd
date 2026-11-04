class_name WakeLayer
extends Node2D

## Schaumsaum um den Rumpf, Bugwelle und Kielwasser, auf der vorderen Wasserschicht. Stärke nach
## Fahrt (nur Lesezugriff auf Voyage); im Stand bleibt ein leiser Saum.

const BOW_X := 302.0
const STERN_X := 178.0
const FOAM := Color("c4d2d8")
const FOAM_DIM := Color("8fa3ad")
const FOAM_FAR := Color("5f7684")

var voy: Voyage
var _drive := 0.12
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var target := 0.12
	if voy != null and voy.is_working(Stations.Id.STEUER):
		target = clampf(0.42 + voy.sail_visual * 0.26 + (0.2 if voy.rowing_now else 0.0), 0.0, 1.0)
	_drive = move_toward(_drive, target, delta * 0.35)
	Waves.drive = _drive
	queue_redraw()


func _surf(x: float) -> float:
	return roundf(Waves.WATER_Y + 1.0 + Waves.height(x, 1))


static func _h(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	var dr := _drive
	var st := Waves.storm
	# Saum entlang der Wasserlinie unter dem Rumpf
	var thr := 0.78 - dr * 0.32 - st * 0.1
	var x := STERN_X - 4.0
	while x < BOW_X + 8.0:
		var y := _surf(x)
		if _h(x, 3.0) > thr:
			draw_rect(Rect2(x, y, 1, 1), FOAM)
			if _h(x, 5.0) > 0.7:
				draw_rect(Rect2(x, y + 1.0, 1, 1), FOAM_DIM)
		x += 1.0
	# Bugwelle: ein Schaumpolster und kleine Spritzer, die bogenförmig aufsteigen
	var bow_w := roundf(3.0 + dr * 7.0)
	for i in int(bow_w):
		var bx := BOW_X + 3.0 + float(i)
		draw_rect(Rect2(bx, _surf(bx) - 1.0, 1, 1), FOAM)
		if i % 2 == 0:
			draw_rect(Rect2(bx, _surf(bx), 1, 1), FOAM_DIM)
	var sprays := int(round(1.0 + dr * 5.0))
	for k in sprays:
		var age := fposmod(_t * 0.9 + float(k) * 0.37, 1.0)
		var sx := BOW_X + 4.0 + float(k) * 2.0 + age * 9.0
		var sy := _surf(sx) - 2.0 - sin(age * PI) * (3.0 + dr * 4.0)
		draw_rect(Rect2(roundf(sx), roundf(sy), 1, 1), FOAM if age < 0.6 else FOAM_DIM)
	# Kielwasser: Schaumsprenkel, die vom Heck nach links treiben und verblassen
	var n := 26
	for k in n:
		if float(k) / float(n) > dr:
			continue
		var dist := fposmod(float(k) * 8.3 + _t * (5.0 + dr * 14.0), 112.0)
		var wx := STERN_X - 2.0 - dist
		var wy := _surf(wx) + (1.0 if _h(float(k), 9.0) > 0.6 else 0.0)
		var wlen := 3.0 if dist < 40.0 else (2.0 if dist < 80.0 else 1.0)
		var col := FOAM if dist < 36.0 else (FOAM_DIM if dist < 76.0 else FOAM_FAR)
		draw_rect(Rect2(roundf(wx), wy, wlen, 1), col)
