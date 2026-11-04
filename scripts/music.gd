class_name MusicDirector
extends Node

## Wählt je nach Lage das passende Stück und überblendet sanft.
##   Hauptmenü, Ende einer Fahrt     Lieder mit Gesang (Neue Ufer, neues Land / Halt aus, mein Freund)
##   Fahrt: ruhige See               Morgenwind (komponiert, ohne Gesang)
##   Fahrt: Seegang 3                Halt aus, mein Freund (ohne Gesang)
##   Fahrt: Seegang 4-5              Sturmwache (komponiert)
##   Seeschlacht                     Eisen und Salz (komponiert)
##   Hafen                           Taverne am Kai (komponiert)
##   Mann über Bord                  Halt aus, mein Freund (ohne Gesang)
## Während der Fahrt läuft nie Gesang, damit er beim Lesen nicht stört. Die Stücke laufen in Endlosschleife und
## setzen beim Zurückwechseln dort fort, wo sie unterbrochen wurden.
## Lautstärke und Stummschaltung werden in user://settings.cfg gemerkt.

enum Track { UFER, LANGSCHIFF, HALT_AUS, HALT_AUS_INSTR, MORGENWIND, STURMWACHE, EISEN, TAVERNE }

## "gain" gleicht die Lautstärke der Stücke aneinander an (in dB).
const TRACKS := {
	Track.UFER: {"title": "Neue Ufer, neues Land", "path": "res://Musik/Neue_Ufer_neues_Land.wav", "vocal": true, "gain": 0.0},
	Track.LANGSCHIFF: {"title": "Langschiff durch die See", "path": "res://Musik/Langschiff_durch_die_See.wav", "vocal": true, "gain": 0.0},
	Track.HALT_AUS: {"title": "Halt aus, mein Freund", "path": "res://Musik/Halt aus, mein Freund.wav", "vocal": true, "gain": 0.0},
	Track.HALT_AUS_INSTR: {"title": "Halt aus (ohne Gesang)", "path": "res://Musik/Halt aus, mein Freund (Without Lead Vocal).wav", "vocal": false, "gain": 0.0},
	Track.MORGENWIND: {"title": "Morgenwind", "path": "res://Musik/Hintergrund/morgenwind.wav", "vocal": false, "gain": -5.0},
	Track.STURMWACHE: {"title": "Sturmwache", "path": "res://Musik/Hintergrund/sturmwache.wav", "vocal": false, "gain": -7.0},
	Track.EISEN: {"title": "Eisen und Salz", "path": "res://Musik/Hintergrund/eisen_und_salz.wav", "vocal": false, "gain": -6.0},
	Track.TAVERNE: {"title": "Taverne am Kai", "path": "res://Musik/Hintergrund/taverne.wav", "vocal": false, "gain": -4.0},
}
const MIN_HOLD := 40.0  # Sekunden, bevor die Stimmung (nicht aber ein Ereignis) das Lied wechselt
const FADE := 3.0
const SILENT_DB := -60.0
const SETTINGS := "user://settings.cfg"

static var persist := false  # nur im echten Spiel schreiben (Tests und Bots lassen settings.cfg in Ruhe)

var voy: Voyage
var menu := false  # Hauptmenü offen: dann laufen die Lieder mit Gesang
var volume_db := -8.0
var muted := false
var title_time := 0.0  # so lange wird der Titel eingeblendet
var status := ""

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer = null
var _current := -1
var _since := 0.0
var _streams: Dictionary = {}
var _positions: Dictionary = {}
var _rescue_hold := false
var _last_menu := false
var _tween: Tween = null


func _ready() -> void:
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	add_child(_a)
	add_child(_b)
	_load_settings()
	AudioServer.set_bus_mute(0, muted)
	for t in TRACKS:
		ResourceLoader.load_threaded_request(String(TRACKS[t]["path"]))


func _process(delta: float) -> void:
	_since += delta
	title_time = maxf(title_time - delta, 0.0)
	if voy == null:
		return
	var want := _desired()
	var urgent := voy.ended or _rescue_hold or menu != _last_menu or voy.encounter >= 0
	if _current == Track.EISEN or _current == Track.TAVERNE:
		urgent = true  # nach Schlacht oder Hafenbesuch gleich zurück auf See
	_last_menu = menu
	if want != _current and (_current < 0 or urgent or _since >= MIN_HOLD):
		_switch(want, 1.5 if urgent else FADE)


## Lieder mit Gesang nur im Hauptmenü und nach der Fahrt, unterwegs nur Stücke ohne Gesang.
func _desired() -> int:
	if menu:
		return Track.UFER
	if voy.ended:
		return Track.UFER if voy.victory else Track.HALT_AUS
	if voy.phase == Voyage.Phase.RESCUE:
		_rescue_hold = true
	elif voy.phase != Voyage.Phase.RESOLVE:  # Seilwurf läuft noch; danach gilt wieder die Lage (Schlacht, Hafen ...)
		_rescue_hold = false
	if _rescue_hold:
		return Track.HALT_AUS_INSTR
	if voy.encounter >= 0:
		if Encounters.is_battle(voy.encounter):
			return Track.EISEN
		if Encounters.is_harbor(voy.encounter):
			return Track.TAVERNE
		if _current >= 0 and not bool(TRACKS[_current]["vocal"]):
			return _current  # bei Begegnungen keine Unterbrechung
	var sea := voy.sea_view
	if sea >= 4:
		return Track.STURMWACHE
	if sea == 3:
		return Track.HALT_AUS_INSTR
	return Track.MORGENWIND


func _stream_for(track: int) -> AudioStream:
	if _streams.has(track):
		return _streams[track]
	var path := String(TRACKS[track]["path"])
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		var res := ResourceLoader.load_threaded_get(path) as AudioStream
		_streams[track] = res
		return res
	return null  # lädt noch, der nächste Frame versucht es wieder


func _switch(track: int, fade: float) -> void:
	var stream := _stream_for(track)
	if stream == null:
		return
	var old := _active
	var fresh := _b if _active == _a else _a
	if old != null and old.playing:
		_positions[_current] = old.get_playback_position()
	if _tween != null:
		_tween.kill()
	fresh.stream = stream
	fresh.volume_db = SILENT_DB
	fresh.play(float(_positions.get(track, 0.0)))
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(fresh, "volume_db", volume_db + float(TRACKS[track]["gain"]), fade)
	if old != null:
		_tween.tween_property(old, "volume_db", SILENT_DB, fade)
		_tween.chain().tween_callback(old.stop)
	_active = fresh
	_current = track
	_since = 0.0
	status = "Musik: %s" % String(TRACKS[track]["title"])
	title_time = 6.0


func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	status = "Ton aus  (M)" if muted else "Ton an"
	title_time = 3.0
	_save_settings()


func change_volume(step_db: float) -> void:
	volume_db = clampf(volume_db + step_db, -40.0, 0.0)
	if _active != null:
		if _tween != null and _tween.is_running():  # Überblendung abbrechen, sonst läuft sie zum alten Wert
			_tween.kill()
			var other := _b if _active == _a else _a
			other.stop()
		_active.volume_db = volume_db + float(TRACKS[_current]["gain"])
	status = "Lautstärke %d dB" % roundi(volume_db)
	title_time = 3.0
	_save_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		volume_db = clampf(float(cfg.get_value("music", "volume_db", volume_db)), -40.0, 0.0)
		muted = bool(cfg.get_value("music", "muted", false))


func _save_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("music", "volume_db", volume_db)
	cfg.set_value("music", "muted", muted)
	cfg.save(SETTINGS)
