extends SceneTree

## Test der Musikregie, ohne Ton (Headless nutzt einen stummen Audiotreiber):
##   godot --headless --path . --script tools/musictest.gd

var fails := 0
var voy: Voyage
var music: MusicDirector
var step := 0
var started := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("ok   ", what)
	else:
		fails += 1
		print("FAIL ", what)


## Regie ohne Ton und ohne Dateien: welche Stimmung, welches Stück, was einspringt, wenn Stücke fehlen. Läuft immer.
func logic_tests() -> void:
	var v := Voyage.new()
	root.add_child(v)
	v.begin()
	var m := MusicDirector.new()
	m.voy = v
	root.add_child(m)
	m._missing = {}  # so tun, als wären alle Stücke da
	v.theme = 0
	v.sea_view = 2
	v.front = v.ship_at() - 3.0
	check(m.mood_now() == "calm" and m._desired() == MusicDirector.Track.MORGENWIND, "ruhige See: Morgenwind")
	# Deckkampf: eigene Musik, jeder Kampf das nächste Stück der Liste
	v.phase = Voyage.Phase.COMBAT
	v.fight_prep = {"formation": "raeuber"}
	m._process(0.1)
	var f1 := m._desired()
	check(m.mood_now() == "fight" and f1 == MusicDirector.Track.SCHILDWALL, "Deckkampf: Schildwall (nicht die ruhige Musik)")
	v.phase = Voyage.Phase.PLAN
	m._process(0.1)
	v.phase = Voyage.Phase.COMBAT
	m._process(0.1)
	check(m._desired() == MusicDirector.Track.PLANKEN, "der nächste Deckkampf: Blutige Planken")
	v.fight_prep = {"formation": "kraken"}
	check(m.mood_now() == "boss" and m._desired() == MusicDirector.Track.TIEFE, "Kraken: Aus der Tiefe")
	v.phase = Voyage.Phase.ENCOUNTER
	v.encounter = Encounters.Id.KRAKEN
	check(m._desired() == MusicDirector.Track.TIEFE, "Kraken taucht auf: schon vor dem Kampf Aus der Tiefe")
	v.encounter = Encounters.Id.IRRLICHTER
	check(m._desired() == MusicDirector.Track.NEBEL, "Irrlichter: Nebelfahrt")
	v.encounter = Encounters.Id.HAENDLER
	m._current = MusicDirector.Track.MORGENWIND
	check(m.mood_now() == "", "gewöhnliche Begegnung: das Stück bleibt")
	v.encounter = -1
	v.phase = Voyage.Phase.PLAN
	v.camping = true
	check(m._desired() == MusicDirector.Track.LAGER, "Lager: Lagerfeuer")
	v.camping = false
	v.theme = 1
	check(m._desired() == MusicDirector.Track.NEBEL, "Nebelmeer bei ruhiger See: Nebelfahrt")
	v.theme = 0
	v.front = v.ship_at()
	check(m.mood_now() == "storm" and m._desired() == MusicDirector.Track.STURMWACHE, "Sturmfront hat das Schiff eingeholt: Sturmwache")
	v.front = v.ship_at() - 3.0
	# Abwechslung: nach einer Weile in derselben Stimmung das nächste Stück
	m._mood = "calm"
	m._current = MusicDirector.Track.MORGENWIND
	m._since = MusicDirector.ROTATE + 1.0
	m._process(0.1)
	check(m._desired() == MusicDirector.Track.RUDER, "ruhige See nach einigen Minuten: Ruderlied")
	# nie Gesang unterwegs, auch nicht im Kampf und im Lager
	var vocal := false
	for ph in [Voyage.Phase.PLAN, Voyage.Phase.RESOLVE, Voyage.Phase.ENCOUNTER, Voyage.Phase.RESCUE, Voyage.Phase.COMBAT]:
		for enc in [-1, Encounters.Id.DRAUGR, Encounters.Id.KRAKEN, Encounters.Id.HAFEN, Encounters.Id.WAL]:
			for sea in [1, 3, 5]:
				for camp in [false, true]:
					v.phase = ph
					v.encounter = enc
					v.sea_view = sea
					v.camping = camp
					var t := m._desired()
					if t >= 0 and bool(MusicDirector.TRACKS[t]["vocal"]):
						vocal = true
	v.phase = Voyage.Phase.PLAN
	v.encounter = -1
	v.camping = false
	check(not vocal, "unterwegs (auch im Kampf und Lager) nie ein Lied mit Gesang")
	# fehlen Stücke, springt ein anderes ein; fehlt alles, bleibt es still (-1)
	m._missing = {MusicDirector.Track.SCHILDWALL: true, MusicDirector.Track.PLANKEN: true}
	m._pick.erase("fight")
	v.phase = Voyage.Phase.COMBAT
	v.fight_prep = {"formation": "raeuber"}
	check(m._desired() == MusicDirector.Track.EISEN, "ohne die neuen Kampfstücke: Eisen und Salz")
	m._missing = {MusicDirector.Track.SCHILDWALL: true, MusicDirector.Track.PLANKEN: true, MusicDirector.Track.EISEN: true}
	check(m._desired() == MusicDirector.Track.STURMWACHE, "ohne jedes Kampfstück: Sturmwache als Ersatz")
	v.phase = Voyage.Phase.PLAN
	m.menu = true
	m._missing = {MusicDirector.Track.UFER: true, MusicDirector.Track.LANGSCHIFF: true}
	check(m._desired() == MusicDirector.Track.MORGENWIND, "Hauptmenü ohne Lieder mit Gesang: Morgenwind")
	m.menu = false
	# Schleife: auch ohne Schleifenmarke im Import
	var path := String(MusicDirector.TRACKS[MusicDirector.Track.MORGENWIND]["path"])
	if ResourceLoader.exists(path):
		var w := load(path) as AudioStreamWAV
		MusicDirector._make_loop(w)
		check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_end > 0, "Hintergrundstücke laufen in Endlosschleife")
	m.queue_free()
	v.queue_free()


func _initialize() -> void:
	logic_tests()
	var present := 0
	for t in MusicDirector.TRACKS:
		if ResourceLoader.exists(String(MusicDirector.TRACKS[t]["path"])):
			present += 1
	if present < MusicDirector.TRACKS.size():
		# Musik/ liegt nicht im Repository (tools/make_music.py erzeugt nur die vier Hintergrundstücke): der Test
		# braucht alle acht (Seegang 3 spielt die Fassung ohne Gesang, das Hauptmenü ein Lied mit Gesang)
		print("übersprungen: Abspielteil, nur %d von %d Musikstücken vorhanden (Musik/ liegt nicht im Repository, siehe README)" % [present, MusicDirector.TRACKS.size()])
		print("FEHLER: ", fails)
		quit(1 if fails > 0 else 0)
		return
	voy = Voyage.new()
	root.add_child(voy)
	voy.begin()
	voy.theme = 0
	music = MusicDirector.new()
	music.voy = voy
	root.add_child(music)
	started = Time.get_ticks_msec()


func finish() -> bool:
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)
	return true


func now(track: int) -> bool:
	return music._current == track


func _process(_delta: float) -> bool:
	if music == null:  # übersprungen (keine Musikdateien): quit() läuft erst nach diesem Bild
		return true
	match step:
		0:
			# warten, bis das erste Stück geladen ist und läuft
			if music._current >= 0:
				check(now(MusicDirector.Track.MORGENWIND), "Aufbruch bei ruhiger See: Morgenwind (ohne Gesang)")
				check(music.status.contains("Morgenwind"), "Titel wird gemeldet")
				step = 1
			elif Time.get_ticks_msec() - started > 60000:
				check(false, "erstes Stück wurde nicht geladen")
				return finish()
		1:
			for t in MusicDirector.TRACKS:
				var s := music._stream_for(t) as AudioStreamWAV
				if s == null:
					if Time.get_ticks_msec() - started > 150000:
						check(false, "Stück %d wurde nicht geladen" % t)
						return finish()
					return false
			check(true, "alle Stücke geladen")
			for t in MusicDirector.TRACKS:
				var s2 := music._stream_for(t) as AudioStreamWAV
				check(s2.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Stück %d läuft in Endlosschleife" % t)
			# Stimmung der See (erst nach der Mindestdauer)
			voy.sea_view = 3
			music._process(0.1)
			check(now(MusicDirector.Track.MORGENWIND), "kein Wechsel vor der Mindestdauer")
			music._since = 100.0
			music._process(0.1)
			check(now(MusicDirector.Track.HALT_AUS_INSTR), "Seegang 3: Halt aus (ohne Gesang)")
			voy.sea_view = 5
			music._since = 100.0
			music._process(0.1)
			check(now(MusicDirector.Track.STURMWACHE), "Sturm: Sturmwache")
			# Mann über Bord: sofort, aber ohne Gesang
			voy.phase = Voyage.Phase.RESCUE
			music._process(0.1)
			check(now(MusicDirector.Track.HALT_AUS_INSTR), "Mann über Bord: sofort Halt aus ohne Gesang")
			voy.phase = Voyage.Phase.RESOLVE
			music._since = 100.0
			music._process(0.1)
			check(now(MusicDirector.Track.HALT_AUS_INSTR), "während der Rettung bleibt das Stück")
			voy.phase = Voyage.Phase.PLAN
			voy.sea_view = 2
			music._since = 100.0
			music._process(0.1)
			check(now(MusicDirector.Track.MORGENWIND), "danach wieder die Stimmung der See")
			check(music._positions.has(MusicDirector.Track.STURMWACHE), "Position des unterbrochenen Stücks gemerkt")
			# Seeschlacht und Hafen haben ihre eigene Musik und geben sie danach gleich wieder her
			voy.encounter = Encounters.Id.DRAUGR
			voy.phase = Voyage.Phase.ENCOUNTER
			music._process(0.1)
			check(now(MusicDirector.Track.EISEN), "Seeschlacht: Eisen und Salz")
			voy.encounter = -1
			voy.phase = Voyage.Phase.PLAN
			music._process(0.1)
			check(now(MusicDirector.Track.MORGENWIND), "nach der Schlacht gleich zurück auf See")
			voy.encounter = Encounters.Id.HAFEN
			voy.phase = Voyage.Phase.ENCOUNTER
			music._process(0.1)
			check(now(MusicDirector.Track.TAVERNE), "Hafen: Taverne am Kai")
			voy.encounter = Encounters.Id.INSEL
			voy.sea_view = 5
			music._process(0.1)
			check(now(MusicDirector.Track.TAVERNE) or now(MusicDirector.Track.MORGENWIND), "Insel: keine Unterbrechung durch die See")
			voy.encounter = -1
			voy.phase = Voyage.Phase.PLAN
			music._process(0.1)
			# Während der Fahrt nie Gesang, in keiner Lage
			var vocal_seen := false
			for sea in range(1, 6):
				for enc in [-1, Encounters.Id.HAENDLER, Encounters.Id.DRAUGR, Encounters.Id.RAEUBER, Encounters.Id.HAFEN]:
					for ph in [Voyage.Phase.PLAN, Voyage.Phase.RESOLVE, Voyage.Phase.ENCOUNTER, Voyage.Phase.RESCUE]:
						voy.sea_view = sea
						voy.encounter = enc
						voy.phase = ph
						if bool(MusicDirector.TRACKS[music._desired()]["vocal"]):
							vocal_seen = true
			voy.encounter = -1
			voy.phase = Voyage.Phase.PLAN
			voy.sea_view = 2
			check(not vocal_seen, "unterwegs läuft in keiner Lage ein Lied mit Gesang")
			# Hauptmenü: Lieder mit Gesang
			music.menu = true
			music._process(0.1)
			check(now(MusicDirector.Track.UFER) and bool(MusicDirector.TRACKS[music._current]["vocal"]), "Hauptmenü: Neue Ufer, neues Land mit Gesang")
			music.menu = false
			music._process(0.1)
			check(now(MusicDirector.Track.MORGENWIND), "Menü zu: wieder Musik ohne Gesang")
			# Ende
			voy.ended = true
			voy.victory = true
			music._process(0.1)
			check(now(MusicDirector.Track.UFER), "Ruhestand: Neue Ufer, neues Land")
			voy.victory = false
			music._process(0.1)
			check(now(MusicDirector.Track.HALT_AUS), "Untergang: Halt aus, mein Freund (mit Gesang)")
			# Lautstärke und Stummschaltung (Einstellungen werden danach zurückgesetzt)
			var v0 := music.volume_db
			var m0 := music.muted
			music.change_volume(-3.0)
			check(is_equal_approx(music.volume_db, v0 - 3.0), "Lautstärke leiser")
			music.change_volume(3.0)
			check(is_equal_approx(music.volume_db, v0), "Lautstärke wieder lauter")
			music.toggle_mute()
			check(music.muted != m0 and AudioServer.is_bus_mute(0) == music.muted, "Stummschaltung wirkt auf den Bus")
			music.toggle_mute()
			check(music.muted == m0, "Stummschaltung zurück")
			step = 2
		_:
			return finish()
	return false
