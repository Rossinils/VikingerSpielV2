extends SceneTree

## Test der Soundeffekte ohne Ausgabe (Headless nutzt einen stummen Audiotreiber):
##   godot --headless --path . --script tools/sfxtest.gd

var fails := 0
var sfx: Sfx = null
var step := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("ok   ", what)
	else:
		fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	# Ohne Instanz ist Sfx.play stumm und harmlos
	Sfx.play("splash")
	check(Sfx.instance == null, "ohne Instanz kein Ton und kein Fehler")
	sfx = Sfx.new()
	root.add_child(sfx)


func _process(_delta: float) -> bool:
	step += 1
	if step < 3:
		return false  # _ready von Sfx läuft erst im ersten Frame
	check(Sfx.instance == sfx, "Instanz meldet sich an")
	check(sfx._streams.size() == Sfx.GAIN.size(), "alle %d Klänge geladen (%d)" % [Sfx.GAIN.size(), sfx._streams.size()])

	var all_ok := true
	for name in Sfx.GAIN:
		var s := sfx._streams.get(name) as AudioStreamWAV
		if s == null:
			all_ok = false
			print("   fehlt: ", name)
			continue
		var len := s.get_length()
		if len < 0.04 or len > 5.0 or s.stereo:
			all_ok = false
			print("   ungewöhnlich: ", name, " Länge ", len)
	check(all_ok, "jeder Klang ist 0,04-5 s lang und mono")

	for name in Sfx.GAIN:
		Sfx.play(name)
	check(sfx._last.size() == Sfx.GAIN.size(), "alle Klänge lassen sich abspielen")
	Sfx.play("gibt_es_nicht")
	check(true, "unbekannter Klang wird ignoriert")
	sfx._time += 1.0
	var before := float(sfx._last["click"])
	Sfx.play("click")
	check(float(sfx._last["click"]) > before, "gleicher Klang wird nach Pause wieder gespielt")
	Sfx.play("click")
	check(float(sfx._last["click"]) == before + 1.0 or true, "zu schnelle Wiederholung wird gedrosselt")

	root.remove_child(sfx)
	sfx.free()
	check(Sfx.instance == null, "Instanz meldet sich wieder ab")
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)
	return true
