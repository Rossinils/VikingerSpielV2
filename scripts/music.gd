class_name MusicDirector
extends Node

## Wählt je nach Lage (Stimmung) das passende Stück und überblendet. Jede Stimmung hat eine Liste von Stücken:
##   Hauptmenü                      Neue Ufer, neues Land / Langschiff durch die See (mit Gesang, abwechselnd)
##   Ende: Ruhestand / Untergang    Neue Ufer, neues Land / Halt aus, mein Freund (mit Gesang)
##   ruhige See                     Morgenwind, Ruderlied (wechseln nach einigen Minuten)
##   Nebelmeer, Totensee (ruhig)    Nebelfahrt, Morgenwind
##   Seegang 3                      Halt aus (ohne Gesang), Ruderlied
##   Seegang 4-5 oder Sturmfront    Sturmwache
##   Spuk (Draugr, Irrlichter, Totenfloß, Wrack, Schiffbrüchiger)   Nebelfahrt
##   Deckkampf                      Schildwall, Blutige Planken, Eisen und Salz (jeder Kampf das nächste)
##   Kraken (Begegnung und Kampf)   Aus der Tiefe
##   Seeschlacht                    Eisen und Salz, Schildwall
##   Hafen / Lager                  Taverne am Kai / Lagerfeuer
##   Mann über Bord                 Halt aus (ohne Gesang)
## Fehlt ein Stück (Musik/ liegt nicht im Repository), springt das nächste der Liste oder der Ersatzliste ein. Während der
## Fahrt läuft nie Gesang. Zwischen zwei Stimmungen der See wird erst nach MIN_HOLD gewechselt, sonst sofort.
## Die Stücke laufen in Endlosschleife (auch wenn der Import es nicht so eingestellt hat) und setzen beim Zurückwechseln dort
## fort, wo sie unterbrochen wurden. Lautstärke und Stummschaltung werden in user://settings.cfg gemerkt.

enum Track { UFER, LANGSCHIFF, HALT_AUS, HALT_AUS_INSTR, MORGENWIND, STURMWACHE, EISEN, TAVERNE,
	SCHILDWALL, PLANKEN, TIEFE, NEBEL, RUDER, LAGER }

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
	Track.SCHILDWALL: {"title": "Schildwall", "path": "res://Musik/Hintergrund/schildwall.wav", "vocal": false, "gain": -5.0},
	Track.PLANKEN: {"title": "Blutige Planken", "path": "res://Musik/Hintergrund/blutige_planken.wav", "vocal": false, "gain": -5.0},
	Track.TIEFE: {"title": "Aus der Tiefe", "path": "res://Musik/Hintergrund/aus_der_tiefe.wav", "vocal": false, "gain": -5.0},
	Track.NEBEL: {"title": "Nebelfahrt", "path": "res://Musik/Hintergrund/nebelfahrt.wav", "vocal": false, "gain": -8.0},
	Track.RUDER: {"title": "Ruderlied", "path": "res://Musik/Hintergrund/ruderlied.wav", "vocal": false, "gain": -6.0},
	Track.LAGER: {"title": "Lagerfeuer", "path": "res://Musik/Hintergrund/lagerfeuer.wav", "vocal": false, "gain": -6.0},
}
## Stimmung -> [Stücke, Ersatz]. Die Ersatzliste gilt nur, wenn kein Stück der ersten Liste vorhanden ist.
const MOODS := {
	"menu": [[Track.UFER, Track.LANGSCHIFF], [Track.MORGENWIND]],
	"win": [[Track.UFER], [Track.RUDER, Track.MORGENWIND]],
	"lose": [[Track.HALT_AUS], [Track.NEBEL, Track.MORGENWIND]],
	"rescue": [[Track.HALT_AUS_INSTR], [Track.STURMWACHE]],
	"calm": [[Track.MORGENWIND, Track.RUDER], []],
	"fog": [[Track.NEBEL, Track.MORGENWIND], []],
	"rough": [[Track.HALT_AUS_INSTR, Track.RUDER], [Track.STURMWACHE, Track.MORGENWIND]],
	"storm": [[Track.STURMWACHE], [Track.EISEN]],
	"spook": [[Track.NEBEL], [Track.STURMWACHE]],
	"fight": [[Track.SCHILDWALL, Track.PLANKEN, Track.EISEN], [Track.STURMWACHE]],
	"boss": [[Track.TIEFE], [Track.EISEN, Track.STURMWACHE]],
	"battle": [[Track.EISEN, Track.SCHILDWALL], [Track.STURMWACHE]],
	"harbor": [[Track.TAVERNE], [Track.MORGENWIND]],
	"camp": [[Track.LAGER], [Track.MORGENWIND]],
}
const SEA_MOODS := ["calm", "fog", "rough", "storm"]  # zwischen diesen erst nach MIN_HOLD wechseln
const FRESH_EACH_TIME := ["fight", "battle", "menu"]  # jedes Mal das nächste Stück der Liste
const SPOOKY := [Encounters.Id.DRAUGR, Encounters.Id.WRACK, Encounters.Id.IRRLICHTER, Encounters.Id.TOTENFLOSS, Encounters.Id.SCHIFFBRUECHIGER]
const MIN_HOLD := 40.0  # Sekunden, bevor die Stimmung der See das Stück wechselt
const ROTATE := 200.0  # so lange läuft ein Stück, bevor die gleiche Stimmung zum nächsten ihrer Liste wechselt
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
var _mood := ""
var _since := 0.0
var _streams: Dictionary = {}
var _missing: Dictionary = {}  # Stücke ohne Datei (Musik/ liegt nicht im Repository): bleiben still, ohne Fehlermeldung
var _positions: Dictionary = {}
var _pick: Dictionary = {}  # Stimmung -> Zähler (welches Stück der Liste gerade dran ist)
var _rescue_hold := false
var _tween: Tween = null


func _ready() -> void:
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	add_child(_a)
	add_child(_b)
	_load_settings()
	AudioServer.set_bus_mute(0, muted)
	for t in TRACKS:
		var path := String(TRACKS[t]["path"])
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)
		else:
			_missing[t] = true
	if not _missing.is_empty():
		print("Hinweis: %d von %d Musikstücken fehlen (Musik/ liegt nicht im Repository, siehe README); das Spiel läuft ohne diese Stücke." % [_missing.size(), TRACKS.size()])


func _process(delta: float) -> void:
	_since += delta
	title_time = maxf(title_time - delta, 0.0)
	if voy == null:
		return
	var mood := mood_now()
	if mood == "":
		return  # eine gewöhnliche Begegnung: das laufende Stück bleibt
	var entering := mood != _mood
	if entering and FRESH_EACH_TIME.has(mood):
		_pick[mood] = int(_pick.get(mood, -1)) + 1
	elif not entering and _since >= ROTATE and _available(MOODS[mood][0]).size() > 1:
		_pick[mood] = int(_pick.get(mood, 0)) + 1  # lange genug gehört: das nächste Stück dieser Stimmung
		_since = 0.0
	var want := _track_for(mood)
	if want < 0:
		return
	var calm_change := SEA_MOODS.has(mood) and SEA_MOODS.has(_mood)
	if want != _current and (_current < 0 or not calm_change or not entering or _since >= MIN_HOLD):
		_switch(want, FADE if (calm_change or not entering) else (1.0 if mood in ["fight", "boss", "battle"] else 1.5))
		_mood = mood
	elif want == _current:
		_mood = mood


## Die Stimmung der Lage; "" heißt: das laufende Stück bleibt (gewöhnliche Begegnung unterwegs).
func mood_now() -> String:
	if menu:
		return "menu"
	if voy.ended:
		return "win" if voy.victory else "lose"
	if voy.phase == Voyage.Phase.RESCUE:
		_rescue_hold = true
	elif voy.phase != Voyage.Phase.RESOLVE:  # Seilwurf läuft noch; danach gilt wieder die Lage (Schlacht, Hafen ...)
		_rescue_hold = false
	if _rescue_hold:
		return "rescue"
	if voy.phase == Voyage.Phase.COMBAT:
		var form := voy.combat.formation if voy.combat != null else String(voy.fight_prep.get("formation", ""))
		return "boss" if form == "kraken" else "fight"
	if voy.camping:
		return "camp"
	if voy.encounter >= 0:
		if voy.encounter == Encounters.Id.KRAKEN:
			return "boss"  # auch die Seeschlacht gegen den Kraken
		if Encounters.is_battle(voy.encounter):
			return "battle"
		if Encounters.is_harbor(voy.encounter):
			return "harbor"
		if SPOOKY.has(voy.encounter):
			return "spook"
		if _current >= 0 and not bool(TRACKS[_current]["vocal"]):
			return ""  # bei Begegnungen keine Unterbrechung
	var sea := voy.sea_view
	if sea >= 4 or voy.front >= voy.ship_at() - 0.001:
		return "storm"
	if sea == 3:
		return "rough"
	if voy.theme == 1 or voy.theme == 4:  # Nebelmeer, Totensee
		return "fog"
	return "calm"


## Das Stück, das jetzt laufen soll (für Tests: dasselbe, was _process wählt).
func _desired() -> int:
	var mood := mood_now()
	if mood == "":
		return _current
	return _track_for(mood)


func _available(list: Array) -> Array:
	var out: Array = []
	for t in list:
		if not _missing.has(t):
			out.append(t)
	return out


func _track_for(mood: String) -> int:
	var lists: Array = MOODS[mood]
	var have := _available(lists[0])
	if have.is_empty():
		have = _available(lists[1])
	if have.is_empty():
		return -1
	return int(have[maxi(int(_pick.get(mood, 0)), 0) % have.size()])


func _stream_for(track: int) -> AudioStream:
	if _streams.has(track):
		return _streams[track]
	if _missing.has(track):
		return null
	var path := String(TRACKS[track]["path"])
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		var res := ResourceLoader.load_threaded_get(path) as AudioStream
		_make_loop(res)
		_streams[track] = res
		return res
	return null  # lädt noch, der nächste Frame versucht es wieder


## Endlosschleife erzwingen: die Hintergrundstücke kommen ohne Schleifenmarke aus make_music.py, und der Import stellt sie
## nicht von selbst ein. Ohne das verstummt ein Stück nach seinem Ende.
static func _make_loop(res: AudioStream) -> void:
	var w := res as AudioStreamWAV
	if w == null or w.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = int(w.get_length() * float(w.mix_rate))


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
