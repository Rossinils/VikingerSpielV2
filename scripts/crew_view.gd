class_name CrewView
extends Node2D

## Darstellung eines Mannes: an Deck an seinem Platz, im Wasser als Schwimmer.
## Ursprung = Fußpunkt auf der Reling (an Deck) bzw. Schulterhöhe (im Wasser).

enum Pose { IDLE, WORK_A, WORK_B, SWIM_A, SWIM_B }

const POSES := 5
const LOOKS := 7
const INK := Color("0d0b10")
const OAR := Color("9a7149")
const ROPE := Color("c9b98a")
const STEEL := Color("a9b0b8")

var member: CrewMember
var voy: Voyage
var ship: ShipSprite
var _sprite: Sprite2D
var _t := 0.0


func setup(m: CrewMember, v: Voyage, s: ShipSprite) -> void:
	member = m
	voy = v
	ship = s
	_t = randf() * 10.0
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/crew.png")
	_sprite.hframes = POSES
	_sprite.vframes = LOOKS
	_sprite.centered = false
	_sprite.offset = Vector2(-4, -16)
	add_child(_sprite)


func _process(delta: float) -> void:
	_t += delta
	visible = member.state != CrewMember.State.DEAD
	if not visible:
		return
	if member.state == CrewMember.State.OVERBOARD:
		position = Waves.swim_position(member.swim_x)
	elif member.slot >= 0:
		position = ship.deck_point(Stations.slot_x(member.slot))
	_sprite.frame = member.look * POSES + _pose()
	if member.afflicted:
		_sprite.modulate = Color(0.78, 0.66, 0.92)
	elif member.kraft < 40.0:
		_sprite.modulate = Color(0.7, 0.72, 0.92)
	else:
		_sprite.modulate = Color.WHITE
	queue_redraw()


func hit(world_pos: Vector2) -> bool:
	if member.state != CrewMember.State.ABOARD:
		return false
	return Rect2(position + Vector2(-5, -20), Vector2(16, 24)).has_point(world_pos)


func _station() -> int:
	return Stations.slot_station(member.slot) if member.slot >= 0 else -1


func _pose() -> int:
	if member.state == CrewMember.State.OVERBOARD:
		return Pose.SWIM_A if fmod(_t * 3.5, 1.0) < 0.5 else Pose.SWIM_B
	if voy.rope_from == member:
		return Pose.WORK_A if fmod(_t * 2.0, 1.0) < 0.5 else Pose.WORK_B
	var st := _station()
	if st >= 0 and voy.is_working(st):
		var a := fmod(_t * 2.2, 1.0) < 0.5
		if st == Stations.Id.RUDER:
			a = voy.row_phase < 0.6
		return Pose.WORK_A if a else Pose.WORK_B
	return Pose.IDLE


func _draw() -> void:
	if not visible:
		return
	var st := _station()
	if member.state == CrewMember.State.ABOARD and st >= 0:
		draw_rect(Rect2(2, -21, 4, 2), INK)
		draw_rect(Rect2(2, -21, 4, 1), Stations.COLORS[st])
		if voy.rowing_now and st == Stations.Id.RUDER:
			_draw_oar()
		elif st == Stations.Id.ZIMMERMANN and voy.is_working(st):
			_draw_hammer()
	if voy.rope_from == member and voy.rope_to != null:
		var tip := Waves.swim_position(voy.rope_to.swim_x) - position
		draw_line(Vector2(8, -6), tip + Vector2(0, -3), ROPE, 1.0)
	if member.state == CrewMember.State.OVERBOARD:
		# Warnzeichen und Wellenringe, damit man den Schwimmer vor dem Rumpf nicht übersieht
		var bob := roundf(sin(_t * 7.0))
		draw_colored_polygon(PackedVector2Array([Vector2(-1, -26 + bob), Vector2(9, -26 + bob), Vector2(4, -20 + bob)]), Color("d2564b"))
		var ring := fmod(_t * 1.5, 1.0)
		var rw := 10.0 + ring * 10.0
		draw_rect(Rect2(4.0 - rw * 0.5, -4, rw, 1), Color(0.9, 0.95, 1.0, 0.7 * (1.0 - ring)))
	if voy.selected == member and fmod(_t, 0.8) < 0.5:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -30), Vector2(8, -30), Vector2(4, -25)]), Color("f2d36b"))
	if voy.phase == Voyage.Phase.RESCUE and voy.rescuer == member and fmod(_t, 0.8) < 0.5:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -30), Vector2(8, -30), Vector2(4, -25)]), Color("7ab85a"))


func _draw_oar() -> void:
	var p := voy.row_phase
	var stroke := p / 0.6 if p < 0.6 else 1.0 - (p - 0.6) / 0.4
	var a := ship.frame_angle_rad()
	var hand := Vector2(7, -5).rotated(a)
	var tip := Vector2(lerpf(14.0, -20.0, stroke), 20.0).rotated(a)
	draw_line(hand, tip, INK, 3.0)
	draw_line(hand, tip, OAR, 1.0)


## Zimmermann: schlägt mit dem Hammer auf die Planken.
func _draw_hammer() -> void:
	var swing := sin(fmod(_t * 2.4, 1.0) * PI)
	var a := ship.frame_angle_rad()
	var hand := Vector2(8, -5).rotated(a)
	var tip := (Vector2(8, -5) + Vector2(3.0 + swing * 2.0, -8.0 + swing * 7.0)).rotated(a)
	draw_line(hand, tip, INK, 3.0)
	draw_line(hand, tip, OAR, 1.0)
	draw_rect(Rect2(tip + Vector2(-2, -2), Vector2(5, 4)), INK)
	draw_rect(Rect2(tip + Vector2(-1, -1), Vector2(3, 2)), STEEL)
