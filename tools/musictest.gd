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


func _initialize() -> void:
	voy = Voyage.new()
	root.add_child(voy)
	voy.begin()
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
			check(true, "alle acht Stücke geladen")
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
