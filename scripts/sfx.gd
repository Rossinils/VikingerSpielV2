class_name Sfx
extends Node

## Soundeffekte (assets/sfx/*.wav, erzeugt von tools/make_sfx.py).
## Aufruf von überall: Sfx.play("splash"). Ohne Instanz (Tests, Bots, Screenshots) passiert nichts,
## es gibt dann also nie Ton.

static var instance: Sfx = null
static var offset_db := 0.0  # Einstellung: alle Effekte lauter oder leiser (siehe settings.gd)

## Lautstärke je Klang in dB. Hier fein abstimmen, wenn etwas zu laut oder leise ist.
const GAIN := {
	"click": -10.0, "horn": -4.0, "sail": -6.0, "creak": -5.0, "crash": -2.0, "wave": -4.0, "gust": -6.0,
	"splash": -3.0, "rope": -6.0, "rescue_ok": -4.0, "drown": -4.0, "death": -3.0, "hammer": -6.0,
	"coin": -8.0, "thunder": -3.0, "bell": -5.0, "sting": -3.0, "heartbeat": -3.0, "mug": -6.0, "fog": -6.0,
	"cannon": -3.0,
	"swing": -6.0, "whiff": -9.0, "slash": -4.0, "clash": -8.0, "chop": -3.0, "bash": -3.0, "bow": -5.0, "arrow_hit": -4.0,
	"bite": -4.0, "heal": -6.0, "harp": -6.0, "warsong": -6.0, "fall": -3.0, "wail": -6.0, "shield": -5.0,
	"kraken_roar": -2.0, "tentacle": -3.0, "ink": -6.0, "heroic": -3.0, "snap": -3.0,
	"musket": -2.0, "pistol": -4.0, "reload": -7.0, "bones": -5.0,
	"slot_lever": -6.0, "slot_spin": -9.0, "slot_stop": -4.0, "slot_tick": -12.0, "slot_win1": -6.0, "slot_win2": -4.0,
	"slot_win3": -3.0, "slot_coins": -7.0, "slot_jackpot": -2.0, "slot_tease": -5.0, "slot_zap": -6.0, "slot_coil": -5.0,
	"slot_alive": -1.0, "slot_flip": -5.0, "slot_lose": -6.0, "slot_curse": -4.0, "slot_power": -5.0, "slot_stack": -4.0,
	"hit_heavy": -3.0, "deathblow": -2.0, "slow_in": -6.0, "slow_out": -8.0,
	"whale": -3.0, "wisp": -6.0, "whirl": -4.0, "ice": -1.0,
}
## Mindestabstand für Klänge, die schneller aufeinander folgen dürfen als MIN_GAP
const GAP := {"slot_tick": 0.03, "slot_stop": 0.08, "slot_zap": 0.08, "slot_win1": 0.05}

## Kampfgeräusche je Fertigkeit: [beim Ausholen, beim Treffer]. Leer = kein Ton. Verfehlt wird immer "whiff".
const SKILL_SND := {
	"s_hieb": ["swing", "slash"], "s_stoss": ["", "bash"], "s_wall": ["shield", ""],
	"a_hieb": ["swing", "chop"], "a_spalt": ["swing", "chop"], "a_ansturm": ["swing", "chop"],
	"b_schuss": ["bow", "arrow_hit"], "b_mark": ["bow", "arrow_hit"], "b_regen": ["bow", "arrow_hit"],
	"k_stab": ["swing", "bash"], "k_krieg": ["warsong", ""], "k_heil": ["harp", ""], "k_trost": ["harp", ""],
	"f_hieb": ["swing", "slash"], "f_kralle": ["swing", "slash"], "f_pfeil": ["bow", "arrow_hit"], "f_klage": ["wail", ""],
	"f_stoss": ["swing", "bash"], "f_messer": ["swing", "slash"], "f_netz": ["rope", "slash"], "f_armbrust": ["bow", "arrow_hit"],
	"f_wurf": ["swing", "bash"], "f_gabel": ["swing", "slash"], "f_hammer": ["swing", "chop"], "f_biss": ["", "bite"],
	"f_kr_peitsche": ["swing", "tentacle"], "f_kr_griff": ["", "tentacle"], "f_kr_schnabel": ["swing", "bite"],
	"f_kr_tinte": ["ink", ""], "f_kr_quetsch": ["kraken_roar", "tentacle"], "f_kr_wuerg": ["", "tentacle"],
	"s_deckung": ["shield", ""], "s_rund": ["swing", "slash"], "s_ruf": ["clash", ""],
	"a_wirbel": ["swing", "chop"], "a_spalter": ["swing", "chop"], "a_wut": ["heartbeat", ""],
	"b_brand": ["bow", "arrow_hit"], "b_lahm": ["bow", "arrow_hit"], "b_rueck": ["bow", "arrow_hit"],
	"k_weck": ["harp", ""], "k_hohn": ["harp", ""],
	"m_schuss": ["musket", "arrow_hit"], "m_nachladen": ["reload", ""], "m_pistole": ["pistol", "arrow_hit"],
	"m_streu": ["musket", "arrow_hit"], "m_kopf": ["musket", "arrow_hit"], "m_knall": ["musket", "bash"],
	"f_ramm": ["swing", "bash"], "f_heilen": ["harp", ""], "f_deckung": ["shield", ""], "f_horn": ["horn", ""],
	"f_beschwoeren": ["bones", ""],
}
const POOL := 20
const MIN_GAP := 0.12  # gleicher Klang frühestens nach so vielen Sekunden wieder

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last: Dictionary = {}
var _next := 0
var _time := 0.0


## pitch > 0 spielt mit dieser Tonhöhe (1.0 normal), sonst leicht zufällig.
static func play(sound: String, extra_db: float = 0.0, delay: float = 0.0, pitch: float = 0.0) -> void:
	if instance != null:
		instance._play(sound, extra_db, delay, pitch)


## Klang einer Kampfhandlung: phase "go" (Ausholen) oder "hit" (Treffer). Unbekannte Fertigkeit trifft als "slash" (Blutung).
static func skill_sound(skill_id: String, phase: String) -> String:
	if not SKILL_SND.has(skill_id):
		return "slash" if phase == "hit" else ""
	return String((SKILL_SND[skill_id] as Array)[0 if phase == "go" else 1])


func _ready() -> void:
	instance = self
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for name in GAIN:
		var path := "res://assets/sfx/%s.wav" % name
		if ResourceLoader.exists(path):
			_streams[name] = load(path)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	_time += delta


func _play(sound: String, extra_db: float, delay: float, pitch: float) -> void:
	if not _streams.has(sound):
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_start.bind(sound, extra_db, pitch))
	else:
		_start(sound, extra_db, pitch)


func _start(sound: String, extra_db: float, pitch: float) -> void:
	if _time - float(_last.get(sound, -10.0)) < float(GAP.get(sound, MIN_GAP)):
		return
	_last[sound] = _time
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[sound]
	p.volume_db = float(GAIN.get(sound, 0.0)) + extra_db + offset_db
	p.pitch_scale = pitch if pitch > 0.0 else randf_range(0.95, 1.05)
	p.play()
