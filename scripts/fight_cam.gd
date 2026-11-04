class_name FightCam
extends RefCounted

## Kamera des Deckkampfs: Zoom und Brennpunkt mit Fahrten und Wackeln nach dem Trauma-Modell (SPEC 3.6, D1 3).
## Der Drehpunkt ist die Fußlinie FightGeo.FEET: die Füße bleiben beim Zoomen auf ihrer Zeile, der Kopf wandert. Die Kamera rechnet in
## Echtzeit (nicht in Bühnenzeit): Zeitlupe und Standbild halten sie nicht an. Reine Zahlen, zeichnet nichts.

enum { CUBIC_OUT, SINE_IN_OUT, QUAD_OUT }

const MIN_ZOOM := 1.0
const SHAKE_HZ := 25.0  # alle 40 ms wechselt das Vorzeichen
const SHAKE_MAX := 8.0

var zoom := 1.0
var center_x := 240.0
var shake := Vector2.ZERO  # ganze Pixel, wird erst nach dem Runden der Fahrt addiert

var _z0 := 1.0
var _z1 := 1.0
var _c0 := 240.0
var _c1 := 240.0
var _t := 0.0
var _dur := 0.0
var _kind := CUBIC_OUT
var _shakes: Array = []  # {amp, dur, t, axis, trauma, seed}
var _seed := 0


## Auf neue Werte fahren (dur in Sekunden, 0 = sofort). Die Brennweite wird auf 1/8 gerundet (Pixelraster).
func go(zoom_want: float, center: float, dur: float, kind: int = CUBIC_OUT) -> void:
	var z := maxf(MIN_ZOOM, zoom_want)
	var c := clampf(center, 240.0 / z, 480.0 - 240.0 / z)
	if dur <= 0.0:
		zoom = z
		center_x = c
		_z0 = z
		_z1 = z
		_c0 = c
		_c1 = c
		_t = 0.0
		_dur = 0.0
		return
	_z0 = zoom
	_c0 = center_x
	_z1 = z
	_c1 = c
	_t = 0.0
	_dur = dur
	_kind = kind


## Fährt die Kamera noch?
func moving() -> bool:
	return _dur > 0.0 and _t < _dur


## Wohin die Fahrt führt (für Tests und für „bleibt stehen, wenn fast gleich“).
func target_zoom() -> float:
	return _z1 if _dur > 0.0 else zoom


func target_center() -> float:
	return _c1 if _dur > 0.0 else center_x


static func ease_of(kind: int, u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	match kind:
		SINE_IN_OUT:
			return 0.5 - 0.5 * cos(PI * u)
		QUAD_OUT:
			return 1.0 - (1.0 - u) * (1.0 - u)
		_:
			return 1.0 - pow(1.0 - u, 3.0)


## Ein Wackeln dazugeben: amp_px Spitze (bei Trauma 1), dur Sekunden, axis die Schlagachse (die ersten zwei Ausschläge laufen
## entlang, danach gemischt), trauma 0..1 (die Stärke fällt mit dem Quadrat des Traumas, das linear abklingt).
func add_shake(amp_px: float, dur: float, axis: Vector2 = Vector2.RIGHT, trauma: float = 1.0) -> void:
	if amp_px <= 0.0 or dur <= 0.0:
		return
	_seed += 1
	_shakes.append({"amp": amp_px, "dur": dur, "t": 0.0, "axis": axis.normalized() if axis.length() > 0.01 else Vector2.RIGHT, "trauma": clampf(trauma, 0.0, 1.0), "seed": _seed})
	if _shakes.size() > 6:
		_shakes.pop_front()


func shaking() -> bool:
	return not _shakes.is_empty()


func tick(dt: float) -> void:
	if _dur > 0.0:
		_t += dt
		var u := clampf(_t / _dur, 0.0, 1.0)
		var e := ease_of(_kind, u)
		zoom = lerpf(_z0, _z1, e)
		center_x = lerpf(_c0, _c1, e)
		if u >= 1.0:
			zoom = _z1
			center_x = _c1
			_dur = 0.0
	var sum := Vector2.ZERO
	var keep: Array = []
	for s in _shakes:
		s["t"] = float(s["t"]) + dt
		var d := float(s["dur"])
		if float(s["t"]) >= d:
			continue
		keep.append(s)
		var left := 1.0 - float(s["t"]) / d
		var tr := float(s["trauma"]) * left
		var strength := float(s["amp"]) * tr * tr
		var k := int(float(s["t"]) * SHAKE_HZ)
		var sgn := 1.0 if k % 2 == 0 else -1.0
		var ax: Vector2 = s["axis"]
		if k >= 2:
			# danach gemischt: abwechselnd quer, schräg und längs, damit es nicht nur hin und her geht
			var v := (int(s["seed"]) * 7 + k * 5) % 3
			ax = Vector2(ax.y, -ax.x) if v == 0 else (Vector2(ax.x, -ax.y) if v == 1 else ax)
		sum += ax * strength * sgn
	_shakes = keep
	shake = Vector2(clampf(roundf(sum.x), -SHAKE_MAX, SHAKE_MAX), clampf(roundf(sum.y), -SHAKE_MAX, SHAKE_MAX))


func clear() -> void:
	_shakes.clear()
	shake = Vector2.ZERO


## Größter Zoom, bei dem Handelnder und Brennpunkt samt Rand im Bild bleiben und der Kopf unter der Kopfzeile (y 40) bleibt.
## Gerundet nach unten auf 1/8; weniger als 1,0625 ist 1,0 (kein Zucken für nichts). fe = Figurenmaßstab (Rig 1,6).
static func limit_zoom(want: float, x_att: float, x_foc: float, head_top_y: float, fe: float) -> float:
	var z_h := 480.0 / (absf(x_att - x_foc) + 2.0 * 28.0 * fe)
	var z_v := (FightGeo.FEET - 40.0) / maxf(FightGeo.FEET - head_top_y, 1.0)
	var z := minf(want, minf(z_h, z_v))
	z = floorf(z * 8.0) / 8.0
	return 1.0 if z < 1.0625 else z
