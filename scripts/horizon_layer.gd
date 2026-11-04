class_name HorizonLayer
extends Node2D

## Ferne Küste (kachelnder Streifen, driftet mit der Fahrt) und Möwen. Beides nur bei ruhiger
## See: im Sturm löst sich die Silhouette im Raster in den Dunst auf, die Möwen sind fort.

const COAST_BOTTOM := 158.0  # Unterkante des Streifens; das Wasser deckt die unteren Zeilen
const COAST_W := 640.0

var _coast: Texture2D
var _gulls: Texture2D
var _mat: ShaderMaterial
var _scroll := 593.0  # so liegt eine Felsinsel zu Beginn im freien Streifen rechts vom Schiff
var _t := 0.0
var _gull_node: Node2D


func _ready() -> void:
	_coast = load("res://assets/coast.png")
	_gulls = load("res://assets/gulls.png")
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/dissolve.gdshader")
	material = _mat
	_gull_node = Node2D.new()
	_gull_node.draw.connect(_draw_gulls)
	add_child(_gull_node)


func _process(delta: float) -> void:
	_t += delta
	# die Küste wandert mit der Fahrt nach links (Bug zeigt nach rechts), im Stand nur ein Hauch
	_scroll = fposmod(_scroll + delta * (0.25 + Waves.drive * 1.6), COAST_W)
	queue_redraw()
	_gull_node.queue_redraw()


func _draw() -> void:
	var st := Waves.storm
	var vis := clampf(1.0 - st * 1.8, 0.0, 1.0)
	if vis <= 0.03:
		return
	_mat.set_shader_parameter("amount", vis)
	_mat.set_shader_parameter("tint", clampf(st * 2.2, 0.0, 0.8))
	var x0 := -floorf(_scroll)
	var top := COAST_BOTTOM - _coast.get_height() + 1.0
	draw_texture(_coast, Vector2(x0, top))
	draw_texture(_coast, Vector2(x0 + COAST_W, top))


func _draw_gulls() -> void:
	if Waves.storm >= 0.35:
		return
	for k in 3:
		var gx := fposmod(_t * (5.0 + k) + k * 190.0, 620.0) - 70.0
		var gy := 98.0 + k * 13.0 + roundf(sin(_t * 0.45 + k * 2.0) * 3.0)
		var fr := int(_t * 1.6 + k * 1.3) % 4
		var cell: int = [0, 1, 2, 1][fr]
		_gull_node.draw_texture_rect_region(_gulls, Rect2(floorf(gx), gy, 12, 8), Rect2(cell * 12, 0, 12, 8))
