class_name SlotMarker
extends Node2D

## Decksplatz: zeigt, wo ein freier Platz ist und wohin man den gewählten Mann setzen kann.

var slot := 0
var voy: Voyage
var ship: ShipSprite


func setup(i: int, v: Voyage, s: ShipSprite) -> void:
	slot = i
	voy = v
	ship = s


func _process(_delta: float) -> void:
	position = ship.deck_point(Stations.slot_x(slot))
	queue_redraw()


func is_free() -> bool:
	return voy.slot_owner[slot] == null


func hit(world_pos: Vector2) -> bool:
	return voy.phase == Voyage.Phase.PLAN and is_free() and Rect2(position + Vector2(-5, -20), Vector2(16, 24)).has_point(world_pos)


func _draw() -> void:
	if voy.phase != Voyage.Phase.PLAN or not is_free():
		return
	var col: Color = Stations.COLORS[Stations.slot_station(slot)]
	if voy.selected != null:
		col.a = 1.0 if fmod(Waves.time, 0.8) < 0.5 else 0.5
	else:
		col.a = 0.6
	draw_rect(Rect2(-1, -14, 8, 14), col, false, 1.0)
	draw_rect(Rect2(2, -21, 4, 2), col)
