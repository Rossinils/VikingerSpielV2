class_name SkyLayer
extends Node2D

## Himmel: ein einziges Rechteck mit dem Pixel-Shader shaders/sky.gdshader (Bayer-Dithering,
## Wolkenschichten, Sonne). Der Shader rechnet im 480x320-Raster, nichts wird weichgezeichnet.
## Die Küstensilhouette und die Möwen liegen in HorizonLayer (Kind dieser Schicht).

const SUN := Vector2(300.0, 86.0)
const SKY_BOTTOM := 200.0  # tiefer ist alles vom Wasser verdeckt

var _mat: ShaderMaterial
var _off_a := 0.0
var _off_b := 0.0


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/sky.gdshader")
	_mat.set_shader_parameter("noise_tex", load("res://assets/cloud_noise.png"))
	_mat.set_shader_parameter("sun_pos", SUN)
	material = _mat
	add_child(HorizonLayer.new())


func _process(delta: float) -> void:
	var st := Waves.storm
	# Wolken ziehen ruhig; im Sturm schneller, bei Fahrt eine Spur mehr
	_off_a = fposmod(_off_a + delta * (2.5 + st * 12.0 + Waves.drive * 1.5), 100000.0)
	_off_b = fposmod(_off_b + delta * (1.2 + st * 6.0 + Waves.drive * 1.0), 100000.0)
	_mat.set_shader_parameter("storm", st)
	_mat.set_shader_parameter("flash", Waves.flash)
	_mat.set_shader_parameter("off_a", _off_a)
	_mat.set_shader_parameter("off_b", _off_b)


func _draw() -> void:
	draw_rect(Rect2(-16, -16, Waves.VIEW_W + 32, SKY_BOTTOM + 16), Color.WHITE)
