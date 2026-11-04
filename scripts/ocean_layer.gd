class_name OceanLayer
extends Node2D

## Wasserschicht. Die Oberkante (ganze Pixel, Waves.height) wird jede Bildfolge in eine 480x1-Textur
## geschrieben; shaders/ocean.gdshader zeichnet daraus Tiefenstufen, Wellenlinien, Schaum und
## Glitzern in harten Pixeln. Ein einziges Rechteck statt tausender draw_rect.
## layer: 2 = ferne Schicht am Horizont, 0 = mittlere, 1 = vordere (vor dem Schiff).

@export var layer := 1
@export var base_y := 190.0
@export var color := Color("16313f")  # nur noch Altlast, die Palette steckt im Shader

const WIDTH := Waves.VIEW_W
const BOTTOM := Waves.VIEW_H + 10

var _img: Image
var _tex: ImageTexture
var _mat: ShaderMaterial
var _buf := PackedFloat32Array()


func _ready() -> void:
	_img = Image.create(WIDTH, 1, false, Image.FORMAT_RF)
	_tex = ImageTexture.create_from_image(_img)
	_buf.resize(WIDTH)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/ocean.gdshader")
	_mat.set_shader_parameter("surf", _tex)
	_mat.set_shader_parameter("tone", 0 if layer == 2 else (1 if layer == 0 else 2))
	_mat.set_shader_parameter("sun_pos", SkyLayer.SUN)
	material = _mat
	_update()
	queue_redraw()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	for x in WIDTH:
		_buf[x] = roundf(base_y + Waves.height(x, layer))
	_img.set_data(WIDTH, 1, false, Image.FORMAT_RF, _buf.to_byte_array())
	_tex.update(_img)
	_mat.set_shader_parameter("storm", Waves.storm)
	_mat.set_shader_parameter("flash", Waves.flash)
	_mat.set_shader_parameter("time", Waves.time)


func _draw() -> void:
	var top := base_y - 40.0
	var bottom := float(BOTTOM) if layer == 1 else 236.0
	draw_rect(Rect2(-16, top, WIDTH + 32, bottom - top), Color.WHITE)
