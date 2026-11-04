class_name ShipSprite
extends Sprite2D

## assets/ship.png ist ein Atlas (tools/make_art.py): Spalten = Neigungswinkel, Zeilen = Segelstufe
## (0 eingeholt .. 4 voll). Konstanten müssen zum Skript passen. Anker (Wasserlinie, Schiffsmitte)
## liegt in jedem Frame bei (110, 108).

const FRAME_COUNT := 31
const SAIL_ROWS := 5
const FRAME_ANCHOR := Vector2(110, 108)
const MAX_ANGLE := 37.5
const ANGLE_STEP := 2.5
## Rumpfgeometrie im Basisbild (für die Decksplätze der Crew)
const HULL_CX := 82.0
const HULL_HALF := 62.0

var voy: Voyage
var base_y := Waves.WATER_Y
var _angle := 0.0  # Grad, positiv = Bug nach unten
var _col := FRAME_COUNT / 2


func _ready() -> void:
	texture = load("res://assets/ship.png")
	hframes = FRAME_COUNT
	vframes = SAIL_ROWS
	centered = false
	offset = -FRAME_ANCHOR
	frame_coords = Vector2i(_col, SAIL_ROWS - 1)


func _process(_delta: float) -> void:
	var x := position.x
	var jolt := 0.0
	var row := SAIL_ROWS - 1
	if voy != null:
		jolt = sin(Waves.time * 45.0) * voy.impact * 2.0
		row = clampi(roundi(voy.sail_visual * 2.0), 0, SAIL_ROWS - 1)
	position.y = roundf(base_y + Waves.height(x) + jolt)
	var slope := (Waves.height(x + 12.0) - Waves.height(x - 12.0)) / 24.0
	var target := clampf(rad_to_deg(atan(slope)) * 0.9, -MAX_ANGLE, MAX_ANGLE)
	_angle = lerpf(_angle, target, 0.12)
	_col = clampi(roundi((_angle + MAX_ANGLE) / ANGLE_STEP), 0, FRAME_COUNT - 1)
	frame_coords = Vector2i(_col, row)


## Neigung des gerade angezeigten Frames (Bogenmaß, positiv = Bug nach unten).
func frame_angle_rad() -> float:
	return deg_to_rad(_col * ANGLE_STEP - MAX_ANGLE)


## Punkt auf der Reling über dem Decksplatz mit Schiffsbild-x `slot_x`, in Weltkoordinaten.
func deck_point(slot_x: float) -> Vector2:
	var t := (slot_x + 2.0 - HULL_CX) / HULL_HALF
	var local := Vector2(slot_x - HULL_CX, roundf(-14.0 - 12.0 * t * t))
	return (position + local.rotated(frame_angle_rad())).round()
