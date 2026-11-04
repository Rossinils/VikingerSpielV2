class_name RainLayer
extends Node2D

## Regen in harten Pixeln (zwei Tiefenstufen, Spritzer auf dem Wasser) und Blitze: statt eines
## weißen Vollbilds setzt der Blitz Waves.flash (Himmel hinter den Wolken wird hell, die Wolken
## bleiben dunkle Scherenschnitte) und zeichnet einen gezackten Pixelstrahl.

const FAR_COL := Color(0.45, 0.55, 0.62, 0.42)
const NEAR_COL := Color(0.66, 0.76, 0.84, 0.62)
const SPLASH_COL := Color(0.78, 0.86, 0.9, 0.7)

var _drops: Array[Vector3] = []  # x, y, Tiefe 0 (fern) .. 1 (nah)
var _splashes: Array[Vector3] = []  # x, y, Alter
var _flash := 0.0
var _bolt_age := 9.0
var _bolt: PackedVector2Array = PackedVector2Array()
var _bolt_branch: PackedVector2Array = PackedVector2Array()
var _next_bolt := 3.0


func _process(delta: float) -> void:
	var want := int(Waves.storm * 200.0)
	while _drops.size() < want:
		_drops.append(Vector3(randf_range(-16.0, Waves.VIEW_W + 120.0), randf_range(-16.0, Waves.VIEW_H), randf()))
	while _drops.size() > want:
		_drops.pop_back()

	var wind := Vector2(-90.0, 340.0 + Waves.storm * 200.0)
	for i in _drops.size():
		var d := _drops[i]
		var q := Vector2(d.x, d.y) + wind * (0.75 + d.z * 0.5) * delta
		var hit_y := Waves.WATER_Y + 3.0 + Waves.height(q.x, 1) + d.z * 34.0 + 6.0
		if q.y > hit_y or q.x < -16.0:
			if q.y > hit_y and q.x > 0.0 and q.x < Waves.VIEW_W and _splashes.size() < 48 and d.z > 0.2:
				_splashes.append(Vector3(roundf(q.x), roundf(hit_y), 0.0))
			q = Vector2(randf_range(0.0, Waves.VIEW_W + 120.0), -8.0)
			d.z = randf()
		_drops[i] = Vector3(q.x, q.y, d.z)
	var k := 0
	while k < _splashes.size():
		var sp := _splashes[k]
		_splashes[k] = Vector3(sp.x, sp.y, sp.z + delta)
		if sp.z + delta > 0.22:
			_splashes.remove_at(k)
		else:
			k += 1

	_next_bolt -= delta
	if _next_bolt <= 0.0:
		if Waves.storm > 0.55:
			_strike()
			Sfx.play("thunder", 0.0, randf_range(0.3, 1.6))  # der Donner kommt nach dem Blitz
		_next_bolt = randf_range(2.5, 8.0) / maxf(Waves.storm, 0.2)
	_bolt_age += delta
	# Doppelschlag: kurzer Hauptblitz, nach 0.2 s ein schwächeres Nachflackern, alles ruhig abklingend
	var f := exp(-_bolt_age * 7.0)
	if _bolt_age > 0.2:
		f = maxf(f, 0.6 * exp(-(_bolt_age - 0.2) * 8.0))
	_flash = f if _bolt_age < 1.5 else 0.0
	Waves.flash = _flash
	queue_redraw()


## Gezackter Strahl von oben bis zum Horizont, ein kurzer Seitenast.
func _strike() -> void:
	_bolt_age = 0.0
	_bolt = PackedVector2Array()
	_bolt_branch = PackedVector2Array()
	var x := randf_range(90.0, 400.0)
	var y := -8.0
	var branch_at := randi_range(4, 8)
	var n := 0
	while y < 146.0:
		_bolt.append(Vector2(roundf(x), roundf(y)))
		y += float(randi_range(5, 9))
		x += float(randi_range(-5, 5))
		n += 1
		if n == branch_at:
			var bx := x
			var by := y
			for j in 4:
				_bolt_branch.append(Vector2(roundf(bx), roundf(by)))
				by += float(randi_range(4, 7))
				bx += float(randi_range(2, 6)) * (1.0 if x > 240.0 else -1.0)


func _draw() -> void:
	for d in _drops:
		var q := Vector2(roundf(d.x), roundf(d.y))
		if d.z > 0.5:
			draw_rect(Rect2(q, Vector2(1, 3)), NEAR_COL)
			draw_rect(Rect2(q + Vector2(-1, 3), Vector2(1, 2)), NEAR_COL)
		else:
			draw_rect(Rect2(q, Vector2(1, 2)), FAR_COL)
	for sp in _splashes:
		var a := sp.z
		var p := Vector2(sp.x, sp.y)
		draw_rect(Rect2(p + Vector2(-1.0 - roundf(a * 8.0), -1.0), Vector2(1, 1)), SPLASH_COL)
		draw_rect(Rect2(p + Vector2(1.0 + roundf(a * 8.0), -1.0), Vector2(1, 1)), SPLASH_COL)
		draw_rect(Rect2(p + Vector2(0, -1.0 - roundf(a * 10.0)), Vector2(1, 1)), SPLASH_COL)
	if _bolt_age < 0.28 and _bolt.size() > 1:
		_draw_bolt(_bolt)
		_draw_bolt(_bolt_branch)


func _draw_bolt(pts: PackedVector2Array) -> void:
	# nur waagerechte und senkrechte Pixelzüge, zweifarbig (Kern hell, Saum dunkler)
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var mid := Vector2(b.x, a.y)  # erst quer, dann hinab
		_px_line(a, mid, Color(0.55, 0.66, 0.82, 0.8), 1)
		_px_line(mid, b, Color(0.55, 0.66, 0.82, 0.8), 1)
		_px_line(a, mid, Color(0.92, 0.95, 1.0), 0)
		_px_line(mid, b, Color(0.92, 0.95, 1.0), 0)


func _px_line(a: Vector2, b: Vector2, col: Color, grow: int) -> void:
	var r := Rect2(minf(a.x, b.x), minf(a.y, b.y), absf(b.x - a.x) + 1.0, absf(b.y - a.y) + 1.0)
	draw_rect(r.grow(float(grow)), col)
