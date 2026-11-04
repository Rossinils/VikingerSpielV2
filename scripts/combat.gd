class_name Combat
extends RefCounted

## Deckkampf: bis zu vier Männer gegen bis zu vier Gegner, rundenbasiert wie ein Kampf in Darkest Dungeon.
## Reine Logik ohne Anzeige, damit sie ohne Fenster testbar ist. Reihe 0 steht vorn.
##
## Ablauf: create() -> begin() -> solange state == "hero": hero_act()/hero_move()/hero_pass()/hero_flee(),
## solange state == "foe": act_foe(); bei state == "done" steht result ("win", "lose", "flee") fest und finish()
## schreibt Kraft und Verluste zurück. Mit auto_play() spielt die Maschine beide Seiten (Bots, schnelles Auflösen).
##
## Kraft der Männer ist zugleich ihre Verletzbarkeit. Bei 0 Kraft sind sie "an der Schwelle": jeder weitere Treffer
## tötet mit 50 %. Verzweiflung wächst durch Gegner-Fertigkeiten, kritische Treffer und Verluste.

class Fighter extends RefCounted:
	var side := 0  # 0 Männer, 1 Gegner
	var name := ""
	var kind := ""  # Rollenkürzel oder Gegnerart
	var role := -1
	var man: CrewMember = null
	var hp := 0.0
	var hp_max := 100.0
	var dodge := 0.0
	var prot := 0.0
	var speed := 0
	var dmg_lo := 5.0
	var dmg_hi := 8.0
	var skills: Array = []  # Männer: Fertigkeits-Ids; Gegner: [[Id, Gewicht], ...]
	var immune: Array = []
	var coward := false
	var rank := 0
	var stun := 0
	var stun_immune := 0
	var bleed_turns := 0
	var bleed_dmg := 0.0
	var mark := 0
	var guard := 0
	var buff := 0
	var door := false
	var gone := false
	var uses: Dictionary = {}
	var initiative := 0.0
	var fearless := false  # flieht nie
	var guarded := false  # unerreichbar, solange ein Fangarm steht
	var held_by: Fighter = null  # Mann: im Griff dieses Fangarms
	var holding: Fighter = null  # Fangarm: hält diesen Mann
	var hold_left := 0  # Züge des Fangarms, bis er den Mann über Bord zieht
	var blind := 0  # Runden mit 20 % weniger Trefferchance (Tinte)
	var charge := false  # Kraken: spannt sich zum Zerquetschen
	var crush_cd := 2  # Kraken: eigene Züge bis zur nächsten Ankündigung
	var snapped := false  # bei 100 Verzweiflung schon gekippt oder über sich hinausgewachsen (einmal je Kampf)
	var panic := 0  # Züge, die er vor Schreck aussetzt
	var loaded := true  # Musketier: die Muskete ist geladen
	var skill_lvl: Dictionary = {}  # Stufen seiner Fertigkeiten aus der Kampfschule
	var crit_bonus := 0.0  # Ausrüstung: Punkte mehr Krit-Chance
	var acc_bonus := 0.0  # Ausrüstung: Punkte mehr Trefferchance
	var regen := 0.0  # Ausrüstung: Kraft, die er je Runde zurückbekommt
	var taunt := 0  # Runden, in denen die Gegner fast nur auf ihn zielen

## Härte der Gegner: Grundfaktoren auf Schaden und Kraft und der Zuwachs je Etappe.
const FOE_DMG := 2.0
const FOE_HP := 1.4
const STAGE_DMG := 0.12
const STAGE_HP := 0.15
const REGROW := 4  # Runden, bis ein gefällter Fangarm nachwächst
const REGROW_HP := 0.6  # ein nachgewachsener Fangarm hat nur so viel Kraft wie ein frischer
const OVERBOARD_MAX := 2  # höchstens so viele Männer gehen in einem Kampf über Bord
const HEROIC_CHANCE := 0.3  # bei 100 Verzweiflung: Anteil Heldenmut, der Rest ist Zusammenbruch
const HEROIC_SKALDE := 0.1  # mehr Heldenmut, solange noch ein anderer Skalde steht
const RAGE_CHANCE := 0.25  # ein Berserker schlägt in seinem Zug mit dieser Chance einen Kameraden

var heroes: Array[Fighter] = []  # lebende Männer, Index = Reihe
var foes: Array[Fighter] = []  # lebende Gegner, Index = Reihe
var all_heroes: Array[Fighter] = []
var all_foes: Array[Fighter] = []
var round_no := 0
var order: Array[Fighter] = []
var cursor := -1
var state := "idle"  # hero (ein Mann ist dran), foe (ein Gegner ist dran), done
var actor: Fighter = null
var result := ""
var journal: Array[Dictionary] = []  # {"text", "kind"}: 0 Tatsache, 1 gut, 2 schlecht
var voy: Voyage = null
var formation := ""
var dmg_mult := 1.0
var killed := 0
var fled := 0
var foes_start := 0
var casualties: Array[CrewMember] = []
var overboard: Array[CrewMember] = []  # vom Kraken über Bord gezerrt: leben noch, müssen aber gerettet werden
var snap_force := ""  # nur für Tests und Screenshots: "heroic" oder "break" erzwingt den Ausgang
var snap_variant := -1  # nur für Tests: erzwingt die Art des Heldenmuts (0 Kampfrausch, 1 Eiserner Wille, 2 Mitreißend)
var snaps: Array[Dictionary] = []  # wer bei 100 Verzweiflung gekippt oder gewachsen ist: {"name", "kind" (heroic, verzagt, berserk, panik)}
var event_seq := 0  # zählt Meldungen hoch, damit die Anzeige neue erkennt
var events: Array[Dictionary] = []  # Bewegungsereignisse für die Anzeige: {"id", "type" (attack, hit, miss, heal, die, text, spawn, overboard), "who", "n", "crit", "sk" (Fertigkeit), "text"}
var _hp_scale := 1.0
var _tentacle_cap := 0
var _regrow: Array = []  # Runden, in denen ein Fangarm nachwächst
var _ev_id := 0
var _cur_sid := ""  # Fertigkeit, die gerade ausgeführt wird (für die Ereignisse)


static func create(v: Voyage, form: String, party: Array, units: Array[String], stage: int = 1, hp_scale: float = 1.0) -> Combat:
	var c := Combat.new()
	c.voy = v
	c.formation = form
	c.dmg_mult = FOE_DMG * (1.0 + STAGE_DMG * float(stage - 1))
	var hs := FOE_HP * (1.0 + STAGE_HP * float(stage - 1)) * hp_scale
	for m in party:
		c.heroes.append(c._make_hero(m as CrewMember))
	c._hp_scale = hs
	for key in units:
		c.foes.append(c._make_foe(String(key), hs))
		if String(key) == "tentakel":
			c._tentacle_cap += 1
	c.all_heroes = c.heroes.duplicate()
	c.all_foes = c.foes.duplicate()
	c.foes_start = c.foes.size()
	c._renumber()
	return c


func _make_hero(m: CrewMember) -> Fighter:
	var f := Fighter.new()
	f.side = 0
	f.man = m
	f.name = m.display_name
	f.role = clampi(m.role, 0, Roles.ROLES.size() - 1)
	var r: Dictionary = Roles.role(f.role)
	f.kind = String(r["short"])
	f.hp = m.kraft
	f.hp_max = 100.0
	f.dodge = float(r["dodge"])
	f.prot = float(r["prot"])
	f.speed = int(r["speed"])
	var gm := Gear.sum_mods(m.gear)  # Ausrüstung: Waffe, Rüstung, Amulett
	var arms := (1.0 + Voyage.WEAPON_DMG * float(m.weapon_lvl)) * (1.0 + float(gm["dmg"]))  # Schmiede und Ausrüstung: mehr Schaden
	f.dmg_lo = float((r["dmg"] as Array)[0]) * arms
	f.dmg_hi = float((r["dmg"] as Array)[1]) * arms
	f.prot = minf(f.prot + Voyage.ARMOR_PROT * float(m.armor_lvl) + float(gm["prot"]), 0.6)  # Schmiede und Ausrüstung: mehr Schutz
	f.dodge += float(gm["dodge"])
	f.speed += int(roundf(float(gm["speed"])))
	f.crit_bonus = float(gm["crit"])
	f.acc_bonus = float(gm["acc"])
	f.regen = float(gm["regen"])
	f.skill_lvl = m.skill_lvl.duplicate()
	f.skills = m.skills()
	f.door = m.kraft <= 0.0
	return f


func _make_foe(key: String, hp_scale: float) -> Fighter:
	var t: Dictionary = Foes.info(key)
	var f := Fighter.new()
	f.side = 1
	f.name = String(t["name"])
	f.kind = key
	f.hp = roundf(float(t["hp"]) * hp_scale)
	f.hp_max = f.hp
	f.dodge = float(t["dodge"])
	f.prot = float(t["prot"])
	f.speed = int(t["speed"])
	f.dmg_lo = float((t["dmg"] as Array)[0])
	f.dmg_hi = float((t["dmg"] as Array)[1])
	f.skills = (t["skills"] as Array).duplicate(true)
	f.immune = (t["immune"] as Array).duplicate()
	f.coward = bool(t.get("coward", false))
	f.fearless = bool(t.get("fearless", false))
	f.guarded = bool(t.get("guarded", false))
	return f


func _renumber() -> void:
	for i in heroes.size():
		heroes[i].rank = i
	for i in foes.size():
		foes[i].rank = i


func _event(type: String, who: Fighter, n: int = 0, crit: bool = false, text: String = "") -> void:
	_ev_id += 1
	events.append({"id": _ev_id, "type": type, "who": who, "n": n, "crit": crit, "sk": _cur_sid, "text": text})
	if events.size() > 150:
		events.pop_front()


func _log(text: String, kind: int = 0) -> void:
	journal.append({"text": text, "kind": kind})
	if journal.size() > 80:
		journal.pop_front()
	event_seq += 1


# --- Ablauf -----------------------------------------------------------------------

func begin() -> void:
	_log("Der Kampf beginnt: %d gegen %d." % [heroes.size(), foes.size()])
	_new_round()
	_next_actor()


func _new_round() -> void:
	round_no += 1
	_regrow_tentacles()
	order = []
	for f in heroes:
		order.append(f)
	for f in foes:
		order.append(f)
	for f in order:
		f.initiative = float(f.speed) + randf() * 4.0
	order.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.initiative > b.initiative)
	cursor = -1
	_log("— Runde %d —" % round_no)


func _end_round() -> void:
	for f in order:
		f.mark = maxi(f.mark - 1, 0)
		f.guard = maxi(f.guard - 1, 0)
		f.buff = maxi(f.buff - 1, 0)
		f.blind = maxi(f.blind - 1, 0)
		f.taunt = maxi(f.taunt - 1, 0)
		if f.side == 0 and f.regen > 0.0 and not f.gone:
			f.hp = minf(f.hp + f.regen, f.hp_max)  # Ausrüstung: Regeneration
			if f.hp > 0.0:
				f.door = false
			_sync(f)
		if f.side == 0 and not f.gone and f.hp < 35.0:
			_stress(f, 2.0)  # wer schwer verwundet weiterkämpft, verzweifelt


func _tentacles() -> int:
	var n := 0
	for f in foes:
		if f.kind == "tentakel":
			n += 1
	return n


func _boss_alive() -> bool:
	for f in foes:
		if f.kind == "kraken":
			return true
	return false


## Gefällte Fangarme wachsen nach, solange der Körper lebt (immer vorn, höchstens so viele wie am Anfang).
func _regrow_tentacles() -> void:
	if _regrow.is_empty():
		return
	var later: Array = []
	var due := 0
	for r in _regrow:
		if int(r) <= round_no:
			due += 1
		else:
			later.append(r)
	_regrow = later
	for _k in due:
		if not _boss_alive() or _tentacles() >= _tentacle_cap or foes.size() >= 4:
			continue
		var t := _make_foe("tentakel", _hp_scale * REGROW_HP)
		foes.insert(0, t)
		all_foes.append(t)
		_renumber()
		_log("Ein neuer Fangarm bricht aus dem Wasser.", 2)
		_event("spawn", t)


func _check_end() -> bool:
	if result == "":
		if foes.is_empty():
			result = "win"
		elif heroes.is_empty():
			result = "lose"
	if result != "":
		state = "done"
		actor = null
		return true
	return false


## Bis zum nächsten Zug (Mann oder Gegner) vorrücken; Blutung und Betäubung werden dabei abgewickelt.
func _next_actor() -> void:
	var guard_loop := 0
	while guard_loop < 500:
		guard_loop += 1
		if _check_end():
			return
		cursor += 1
		if cursor >= order.size():
			_end_round()
			if _check_end():
				return
			_new_round()
			continue
		var f := order[cursor]
		if f.gone:
			continue
		if f.bleed_turns > 0:
			f.bleed_turns -= 1
			_log("%s blutet (−%d)." % [f.name, roundi(f.bleed_dmg)], 2 if f.side == 0 else 1)
			_event("hit", f, roundi(f.bleed_dmg))
			_hurt(f, roundi(f.bleed_dmg), null)
			if _check_end():
				return
			if f.gone:
				continue
		if f.stun > 0:
			f.stun -= 1
			f.stun_immune = 1
			_log("%s ist betäubt und setzt aus." % f.name, 2 if f.side == 0 else 1)
			if f.charge:
				f.charge = false
				_log("Der Kraken verliert den Schwung: das Zerquetschen misslingt.", 1)
				_event("text", f, 0, false, "unterbrochen!")
			continue
		if f.stun_immune > 0:
			f.stun_immune -= 1
		if f.side == 0 and f.held_by != null:
			if f.held_by.gone:
				f.held_by = null
			else:
				_log("%s hängt im Griff und kann sich nicht rühren." % f.name, 2)
				continue
		actor = f
		if f.side == 0:
			if f.panic > 0:
				f.panic -= 1
				_log("%s ist vor Schreck wie gelähmt und setzt aus." % f.name, 2)
				continue
			if f.man != null and f.man.afflicted and f.man.affliction == CrewMember.Affliction.BERSERK and heroes.size() >= 2 and randf() < RAGE_CHANCE:
				_rage(f)
				continue
			if f.man != null and f.man.afflicted and f.man.affliction == CrewMember.Affliction.VERZAGT and randf() < 0.3:
				_log("%s zögert und verliert seinen Zug (verzagt)." % f.name, 2)
				continue
			state = "hero"
		else:
			state = "foe"
		return
	state = "done"
	result = "lose"


# --- Fertigkeiten, Ziele, Chancen --------------------------------------------------

## Die Fertigkeit so, wie dieser Kämpfer sie beherrscht (mit den Stufen aus der Kampfschule).
func eff_skill(f: Fighter, skill_id: String) -> Dictionary:
	return Roles.effective(skill_id, int(f.skill_lvl.get(skill_id, 0)))


func needs_target(skill_id: String) -> bool:
	var t := String(Roles.skill(skill_id)["tgt"])
	return t == "foe" or t == "ally" or t == "hero" or t == "fally"


func uses_left(f: Fighter, skill_id: String) -> int:
	var sk: Dictionary = Roles.skill(skill_id)
	if not sk.has("uses"):
		return 99
	return int(sk["uses"]) - int(f.uses.get(skill_id, 0))


func targets(f: Fighter, skill_id: String) -> Array[Fighter]:
	var sk: Dictionary = Roles.skill(skill_id)
	var out: Array[Fighter] = []
	match String(sk["tgt"]):
		"foe":
			for t in foes:
				if (sk["to"] as Array).has(t.rank) and _reachable(t):
					out.append(t)
		"hero":
			for t in heroes:
				if (sk["to"] as Array).has(t.rank):
					out.append(t)
		"ally":
			for t in heroes:
				out.append(t)
		"foes":
			for t in foes:
				if _reachable(t) and ((sk["to"] as Array).is_empty() or (sk["to"] as Array).has(t.rank)):
					out.append(t)
		"heroes", "allies":
			out.append_array(heroes)
		"self", "fself":
			out.append(f)
		"fally":
			var fxs: Dictionary = sk["fx"]
			for t in foes:
				if fxs.has("heal"):
					if t.hp < t.hp_max * 0.75:
						out.append(t)
				elif t != f and (not fxs.has("guard") or t.guard == 0):
					out.append(t)
		"fallies":
			var buffed := false
			for t in foes:
				if t.buff > 0:
					buffed = true
			if not (buffed and (sk["fx"] as Dictionary).has("buff")):
				out.append_array(foes)
	return out


## Der Körper des Kraken steht hinter seinen Fangarmen: erst wenn keiner mehr steht, ist er erreichbar.
func _reachable(t: Fighter) -> bool:
	return not (t.guarded and _tentacles() > 0)


## Darf dieser Kämpfer die Fertigkeit jetzt einsetzen?
func can_use(f: Fighter, skill_id: String) -> bool:
	var sk: Dictionary = Roles.skill(skill_id)
	if not (sk["from"] as Array).has(f.rank) or uses_left(f, skill_id) <= 0:
		return false
	var fxd: Dictionary = sk["fx"]
	if fxd.has("grab") and (f.holding != null or overboard.size() >= OVERBOARD_MAX):
		return false
	if fxd.has("fire") and not f.loaded:
		return false
	if fxd.has("reload") and f.loaded:
		return false
	if fxd.has("summon") and foes.size() >= 4:
		return false
	return not targets(f, skill_id).is_empty()


func hit_chance(att: Fighter, def: Fighter, sk: Dictionary) -> float:
	if int(sk["acc"]) >= 100:
		return 100.0
	var acc := float(sk["acc"]) - def.dodge + att.acc_bonus
	if att.side == 0 and att.man != null and att.man.kraft < CrewMember.TIRED_AT:
		acc -= 10.0
	if att.blind > 0:
		acc -= 20.0
	if def.mark > 0:
		acc += 10.0
	return clampf(acc, 5.0, 95.0)


func _dmg_mult_of(att: Fighter) -> float:
	if att.side == 1:
		return dmg_mult * (1.25 if att.buff > 0 else 1.0)
	var m := 1.0
	if att.man != null:
		m *= CrewMember.kraft_efficiency(att.man.kraft)
		m *= 1.0 + 0.5 * (att.man.fight_factor() - 1.0)
		if att.man.afflicted:
			m *= 1.2 if att.man.affliction == CrewMember.Affliction.BERSERK else 0.7
	if att.buff > 0:
		m *= 1.25
	return m


func _prot_of(def: Fighter) -> float:
	return clampf(def.prot + (0.4 if def.guard > 0 else 0.0), 0.0, 0.8)


## Spanne des Schadens [von, bis] gegen dieses Ziel, ohne Krit.
func damage_range(att: Fighter, def: Fighter, sk: Dictionary) -> Array[float]:
	if float(sk["dmg"]) <= 0.0:
		return [0.0, 0.0]
	var m := _dmg_mult_of(att) * float(sk["dmg"]) * (1.0 - _prot_of(def)) * (1.25 if def.mark > 0 else 1.0)
	return [att.dmg_lo * m, att.dmg_hi * m]


# --- Aktionen der Männer --------------------------------------------------------------

func hero_act(skill_id: String, target: Fighter = null) -> bool:
	if state != "hero" or actor == null or not Roles.SKILLS.has(skill_id) or not can_use(actor, skill_id):
		return false
	if needs_target(skill_id) and (target == null or not targets(actor, skill_id).has(target)):
		return false
	_execute(actor, skill_id, target)
	_next_actor()
	return true


## Der aktive Mann tauscht mit dem Mann auf einer anderen Reihe den Platz (kostet seinen Zug).
func hero_move(to_rank: int) -> bool:
	if state != "hero" or actor == null or to_rank < 0 or to_rank >= heroes.size() or to_rank == actor.rank:
		return false
	_swap(heroes, actor.rank, to_rank)
	_log("%s wechselt auf Reihe %d." % [actor.name, actor.rank + 1])
	_next_actor()
	return true


func hero_pass() -> bool:
	if state != "hero":
		return false
	_log("%s wartet." % actor.name)
	_next_actor()
	return true


## Rückzug: der Kampf endet ohne Sieg.
func hero_flee() -> bool:
	if state != "hero":
		return false
	_log("Der Rückzug wird geblasen.", 2)
	result = "flee"
	state = "done"
	actor = null
	return true


func _swap(arr: Array[Fighter], a: int, b: int) -> void:
	var tmp := arr[a]
	arr[a] = arr[b]
	arr[b] = tmp
	_renumber()


# --- Aktionen der Gegner ----------------------------------------------------------------

func act_foe() -> bool:
	if state != "foe" or actor == null:
		return false
	var f := actor
	if _foe_flees(f):
		foes.erase(f)
		f.gone = true
		fled += 1
		_renumber()
		_log("%s flieht." % f.name, 1)
		_next_actor()
		return true
	if f.holding != null:
		if f.holding.gone or f.holding.held_by != f:
			f.holding = null
		else:
			_hold_turn(f)
			_next_actor()
			return true
	if f.kind == "kraken" and _boss_turn(f):
		_next_actor()
		return true
	var options: Array = []
	for pair in f.skills:
		var sid := String(pair[0])
		if can_use(f, sid):
			options.append([sid, int(pair[1])])
	if options.is_empty():
		# nichts zu tun: eine Reihe vorrücken, sonst warten
		if f.rank > 0:
			_swap(foes, f.rank, f.rank - 1)
			_log("%s rückt vor." % f.name)
		else:
			_log("%s wartet." % f.name)
		_next_actor()
		return true
	var total := 0
	for o in options:
		total += int(o[1])
	var r := randi() % maxi(total, 1)
	var sid2 := String(options[0][0])
	for o in options:
		r -= int(o[1])
		if r < 0:
			sid2 = String(o[0])
			break
	var target: Fighter = null
	if String(Roles.skill(sid2)["tgt"]) == "fally":
		target = _pick_foe_ally(f, sid2)
	elif needs_target(sid2):
		target = _pick_hero_target(f, sid2)
	_execute(f, sid2, target)
	_next_actor()
	return true


## Der Kraken kündigt das Zerquetschen an und führt es im nächsten eigenen Zug aus. true = der Zug ist verbraucht.
func _boss_turn(f: Fighter) -> bool:
	if f.charge:
		f.charge = false
		f.crush_cd = 3
		_execute(f, "f_kr_quetsch", null)
		return true
	if f.crush_cd <= 0:
		f.charge = true
		_log("Der Kraken spannt seine Arme um das Schiff! Im nächsten Zug zerquetscht er das Deck. Ein Betäubter kann es nicht.", 2)
		_event("text", f, 0, false, "spannt sich!")
		return true
	f.crush_cd -= 1
	return false


## Der Fangarm hält einen Mann: erst presst er ihn, im Zug darauf zieht er ihn über Bord.
func _hold_turn(h: Fighter) -> void:
	var m := h.holding
	h.hold_left -= 1
	_cur_sid = "f_kr_wuerg"
	_event("attack", h)
	if h.hold_left <= 0:
		_cur_sid = ""
		if overboard.size() >= OVERBOARD_MAX:
			_log("%s lässt %s los." % [h.name, m.name], 1)
			_release(h)
		else:
			_drag_overboard(m, h)
		return
	var dmg := maxi(roundi(randf_range(h.dmg_lo, h.dmg_hi) * dmg_mult * 0.5), 1)
	_log("%s presst %s: −%d" % [h.name, m.name, dmg], 2)
	_event("hit", m, dmg, false)
	_hurt(m, dmg, h)
	_cur_sid = ""


func _drag_overboard(m: Fighter, h: Fighter) -> void:
	heroes.erase(m)
	m.gone = true
	m.held_by = null
	h.holding = null
	if m.man != null:
		overboard.append(m.man)
	_renumber()
	_event("overboard", m)
	_log("  %s wird über Bord gezerrt!" % m.name, 2)
	_stress_heroes(8.0)


## Der Fangarm lässt los (gefällt, geflohen oder satt): der Mann ist frei.
func _release(h: Fighter) -> void:
	var m := h.holding
	h.holding = null
	if m != null and m.held_by == h:
		m.held_by = null
		if not m.gone:
			_log("  %s ist frei!" % m.name, 1)
			_event("text", m, 0, false, "frei!")


func _foe_flees(f: Fighter) -> bool:
	if f.fearless:
		return false
	if f.coward and foes.size() == 1:
		return true
	if foes_start >= 3 and float(killed + fled) >= float(foes_start) * 0.5 and not f.coward:
		return randf() < 0.3
	return false


func _pick_hero_target(att: Fighter, sid: String) -> Fighter:
	var list := targets(att, sid)
	if (Roles.skill(sid)["fx"] as Dictionary).has("grab"):
		var free: Array[Fighter] = []
		for t in list:
			if t.held_by == null:
				free.append(t)
		if not free.is_empty():
			list = free
	var total := 0.0
	for t in list:
		total += _aggro(t)
	var r := randf() * total
	for t in list:
		r -= _aggro(t)
		if r < 0.0:
			return t
	return list[list.size() - 1]


## Wie sehr die Gegner auf diesen Mann zielen: Schildwall zieht Treffer an, Herausforderung noch mehr.
func _aggro(t: Fighter) -> float:
	if t.taunt > 0:
		return 8.0
	return 3.0 if t.guard > 0 else 1.0


## Ein Verbündeter des Gegners für Heilen und Deckung: der Angeschlagenste.
func _pick_foe_ally(att: Fighter, sid: String) -> Fighter:
	var list := targets(att, sid)
	var best: Fighter = list[0]
	for t in list:
		if t.hp / maxf(t.hp_max, 1.0) < best.hp / maxf(best.hp_max, 1.0):
			best = t
	return best


# --- Ausführung ---------------------------------------------------------------------------

func _execute(att: Fighter, sid: String, target: Fighter) -> void:
	var sk: Dictionary = eff_skill(att, sid)
	if sk.has("uses"):
		att.uses[sid] = int(att.uses.get(sid, 0)) + 1
	var good := 1 if att.side == 0 else 2
	_cur_sid = sid
	_event("attack", att)
	if (sk["fx"] as Dictionary).has("fire"):
		att.loaded = false
	match String(sk["tgt"]):
		"foe", "hero":
			_log("%s: %s gegen %s." % [att.name, sk["name"], target.name], 0)
			_strike(att, sk, target)
		"foes":
			_log("%s: %s." % [att.name, sk["name"]], 0)
			for t in targets(att, sid):
				_strike(att, sk, t)
		"heroes":
			_log("%s: %s." % [att.name, sk["name"]], 2)
			for t in heroes.duplicate():
				_strike(att, sk, t)
		"self", "fself":
			_support(att, att, sk)
			_log("%s: %s." % [att.name, sk["name"]], good)
		"ally", "fally":
			_support(att, target, sk)
		"allies":
			for t in heroes:
				_support(att, t, sk)
			_log("%s: %s." % [att.name, sk["name"]], good)
		"fallies":
			for t in foes.duplicate():
				_support(att, t, sk)
			_log("%s: %s." % [att.name, sk["name"]], good)
	var fx: Dictionary = sk["fx"]
	if fx.has("move") and not att.gone:
		var to_rank := att.rank + int(fx["move"])
		var list: Array[Fighter] = heroes if att.side == 0 else foes
		if to_rank >= 0 and to_rank < list.size() and to_rank != att.rank:
			_swap(list, att.rank, to_rank)
	_cur_sid = ""


func _strike(att: Fighter, sk: Dictionary, def: Fighter) -> void:
	if def.gone:
		return
	var chance := hit_chance(att, def, sk)
	if randf() * 100.0 >= chance:
		_log("  verfehlt %s." % def.name, 0)
		_event("miss", def)
		return
	var dmg := 0
	var crit := false
	if float(sk["dmg"]) > 0.0:
		var rng := damage_range(att, def, sk)
		var base := randf_range(rng[0], rng[1])
		if randf() * 100.0 < float(sk["crit"]) + att.crit_bonus:
			crit = true
			base *= 1.5
		dmg = maxi(roundi(base), 1)
	var fx: Dictionary = sk["fx"]
	if dmg > 0:
		_log("  trifft %s: −%d%s" % [def.name, dmg, " (kritisch!)" if crit else ""], 1 if def.side == 1 else 2)
		_event("hit", def, dmg, crit)
		_hurt(def, dmg, att)
		if def.side == 0 and not def.gone:
			if crit:
				_stress(def, 10.0)
				for h in heroes.duplicate():
					if h != def:
						_stress(h, 4.0)
			elif dmg >= 15:
				_stress(def, 3.0)
	if def.gone:
		return
	if int(sk.get("stress", 0)) > 0 and def.side == 0:
		_stress(def, float(sk["stress"]))
		_log("  %s verliert den Mut (Verzweiflung +%d)." % [def.name, int(sk["stress"])], 2)
	if fx.has("stun") and def.stun_immune == 0 and not def.immune.has("stun") and dmg >= 0:
		def.stun = maxi(def.stun, int(fx["stun"]))
		_log("  %s ist betäubt." % def.name, 1 if def.side == 1 else 2)
	if fx.has("bleed") and not def.immune.has("bleed"):
		var b: Array = fx["bleed"]
		def.bleed_turns = maxi(def.bleed_turns, int(b[0]))
		def.bleed_dmg = float(b[1]) * (dmg_mult if att.side == 1 else 1.0)
		_log("  %s blutet." % def.name, 1 if def.side == 1 else 2)
	if fx.has("mark"):
		def.mark = maxi(def.mark, int(fx["mark"]))
		_log("  %s ist markiert." % def.name, 1)
	if fx.has("pull") and def.side == 0 and def.rank > 0:
		_swap(heroes, def.rank, 0)
		_log("  %s wird nach vorn gezerrt." % def.name, 2)
	if fx.has("push") and def.side == 0 and def.rank < heroes.size() - 1:
		_swap(heroes, def.rank, def.rank + 1)
		_log("  %s wird nach hinten gestoßen." % def.name, 2)
	if fx.has("grab") and def.side == 0 and att.holding == null and def.held_by == null and overboard.size() < OVERBOARD_MAX:
		def.held_by = att
		att.holding = def
		att.hold_left = int(fx["grab"])
		_log("  %s hängt im Griff! Fällt der Fangarm nicht bald, geht er über Bord." % def.name, 2)
		_event("text", def, 0, false, "gepackt!")
	if fx.has("ink") and def.side == 0:
		def.blind = maxi(def.blind, int(fx["ink"]))
		_log("  %s sieht nichts mehr (Treffer −20 %%)." % def.name, 2)
		_event("text", def, 0, false, "geblendet")


func _support(att: Fighter, t: Fighter, sk: Dictionary) -> void:
	var fx: Dictionary = sk["fx"]
	var single := String(sk["tgt"]) in ["ally", "fally"]
	if fx.has("guard"):
		t.guard = maxi(t.guard, int(fx["guard"]))
		if t != att:
			_log("%s: %s schützt %s." % [att.name, sk["name"], t.name], 1 if att.side == 0 else 2)
	if fx.has("buff"):
		t.buff = maxi(t.buff, int(fx["buff"]))
	if fx.has("taunt"):
		t.taunt = int(fx["taunt"])
		_log("%s ruft die Gegner heraus: sie zielen nur noch auf ihn." % t.name, 1)
	if fx.has("cleanse"):
		t.stun = 0
		t.bleed_turns = 0
		t.blind = 0
	if fx.has("reload"):
		att.loaded = true
		_log("%s lädt die Muskete nach." % att.name, 1)
	if fx.has("self_stress"):
		_stress(att, float(fx["self_stress"]))
	if fx.has("summon"):
		_summon(att, String(fx["summon"]))
	if fx.has("heal"):
		var amount := roundi(float(fx["heal"]) * (1.0 if t.side == 0 else _hp_scale))
		t.hp = minf(t.hp + float(amount), t.hp_max)
		if t.hp > 0.0:
			t.door = false
		_sync(t)
		_event("heal", t, amount)
		_log("%s: %s heilt %s (Kraft +%d)." % [att.name, sk["name"], t.name, amount], 1 if att.side == 0 else 2)
	if fx.has("stress_heal") and t.side == 0:
		_stress(t, -float(fx["stress_heal"]))
		if single:
			_log("%s: %s tröstet %s (Verzweiflung −%d)." % [att.name, sk["name"], t.name, int(fx["stress_heal"])], 1)


## Ein Gegner ruft Verstärkung: sie tritt an die Front.
func _summon(att: Fighter, kind: String) -> void:
	if foes.size() >= 4:
		return
	var t := _make_foe(kind, _hp_scale)
	foes.insert(0, t)
	all_foes.append(t)
	_renumber()
	_log("%s ruft einen %s herbei." % [att.name, t.name], 2)
	_event("spawn", t, 0, false, "beschworen")


func _sync(f: Fighter) -> void:
	if f.side == 0 and f.man != null:
		f.man.kraft = clampf(f.hp, 0.0, 100.0)


func _stress(f: Fighter, amount: float) -> void:
	if f.man == null:
		return
	if voy != null:
		voy._add_stress(f.man, amount)
	else:
		f.man.stress = maxf(f.man.stress + amount, 0.0)
	if amount > 0.0 and f.man.stress >= 100.0 and not f.snapped and not f.gone:
		_snap(f)


func _stress_heroes(amount: float) -> void:
	for h in heroes.duplicate():
		_stress(h, amount)


## Bei 100 Verzweiflung kippt ein Mann mitten im Kampf: mit etwa drei Chancen in zehn wächst er über sich hinaus
## (Heldenmut, ein Skalde an seiner Seite hilft), sonst bricht er zusammen (verzagt oder Berserker). Einmal je Kampf.
func _snap(f: Fighter) -> void:
	f.snapped = true
	var chance := HEROIC_CHANCE
	for h in heroes:
		if h != f and h.role == Roles.Id.SKALDE:
			chance += HEROIC_SKALDE
			break
	var roll := randf()
	if snap_force == "heroic":
		roll = 0.0
	elif snap_force == "break":
		roll = 1.0
	if roll < chance:
		_heroic(f)
	elif f.man.afflicted:
		_panic(f)
	else:
		_break(f)


func _heroic(f: Fighter) -> void:
	var m := f.man
	var cured := m.afflicted
	m.stress = 40.0
	m.afflicted = false
	m.affliction = CrewMember.Affliction.NONE
	var vname := ""
	match snap_variant if snap_variant >= 0 else randi() % 3:
		0:
			vname = "Kampfrausch"
			f.buff = maxi(f.buff, 3)
			order.insert(mini(cursor + 1, order.size()), f)
			_log("HELDENMUT! %s stürmt vor: ein Zug extra, 3 Runden mehr Schaden." % f.name, 1)
		1:
			vname = "Eiserner Wille"
			f.hp = minf(f.hp + 30.0, f.hp_max)
			f.door = false
			f.guard = maxi(f.guard, 2)
			_sync(f)
			_log("HELDENMUT! %s beißt die Zähne zusammen: Kraft +30 und Schutz." % f.name, 1)
		_:
			vname = "Mitreißend"
			for h in heroes:
				h.buff = maxi(h.buff, 2)
				if h != f:
					_stress(h, -8.0)
			_log("HELDENMUT! %s reißt alle mit: mehr Schaden für alle, Verzweiflung −8." % f.name, 1)
	if cured:
		_log("%s ist wieder ganz bei sich." % f.name, 1)
	snaps.append({"name": f.name, "kind": "heroic"})
	_event("heroic", f, 0, false, vname)
	if voy != null:
		voy._note("heroic", f.name)
		voy._fact("%s zeigt im Kampf Heldenmut (%s)." % [f.name, vname], Voyage.Kind.GOOD)
		voy._lore("heroic", f.name)


func _break(f: Fighter) -> void:
	var m := f.man
	var berserk := randf() < (0.7 if m.traits.has(Traits.Id.HEISSSPORN) else 0.35)
	m.afflicted = true
	m.affliction = CrewMember.Affliction.BERSERK if berserk else CrewMember.Affliction.VERZAGT
	m.stress = 60.0
	if berserk:
		f.buff = maxi(f.buff, 3)
		_log("ZUSAMMENBRUCH! %s sieht rot: stärker, aber nicht mehr zu bremsen." % f.name, 2)
		_event("snap", f, 0, false, "Berserker")
	else:
		f.panic = 1
		for h in heroes:
			if h != f:
				_stress(h, 5.0)
		_log("ZUSAMMENBRUCH! %s verliert den Mut und erstarrt. Seine Angst steckt die anderen an." % f.name, 2)
		_event("snap", f, 0, false, "verzagt")
	snaps.append({"name": f.name, "kind": "berserk" if berserk else "verzagt"})
	if voy != null:
		if berserk:
			voy._note("berserk", f.name)
			voy._fact("%s sieht im Kampf rot: stärker, aber nicht mehr zu bremsen." % f.name, Voyage.Kind.BAD)
			voy._lore("berserk", f.name)
		else:
			voy._note("breakdown", f.name)
			voy._fact("%s verliert im Kampf den Mut und arbeitet nur noch halb so gut." % f.name, Voyage.Kind.BAD)
			voy._lore("breakdown", f.name)


## Wer schon gebrochen ist und noch einmal an die Grenze kommt, erstarrt vor Schreck.
func _panic(f: Fighter) -> void:
	f.man.stress = 60.0
	f.panic = 1
	for h in heroes:
		if h != f:
			_stress(h, 5.0)
	_log("PANIK! %s ist vor Schreck wie gelähmt." % f.name, 2)
	snaps.append({"name": f.name, "kind": "panik"})
	_event("snap", f, 0, false, "Panik")


## Ein Berserker schlägt in seinem Zug einen Kameraden statt eines Gegners.
func _rage(f: Fighter) -> void:
	var victims: Array[Fighter] = []
	for h in heroes:
		if h != f:
			victims.append(h)
	var sid := ""
	for s in f.skills:
		var sk: Dictionary = Roles.skill(String(s))
		if String(sk["tgt"]) == "foe" and float(sk["dmg"]) > 0.0:
			sid = String(s)
			break
	if victims.is_empty() or sid == "":
		return
	var v := victims[randi() % victims.size()]
	_log("%s rastet aus und schlägt %s!" % [f.name, v.name], 2)
	_event("text", f, 0, false, "rastet aus!")
	_cur_sid = sid
	_event("attack", f)
	_strike(f, Roles.skill(sid), v)
	_cur_sid = ""
	_stress(v, 4.0)


## Schaden einstecken: Gegner sterben bei 0, Männer gehen erst "an die Schwelle".
func _hurt(f: Fighter, dmg: int, _src: Fighter) -> void:
	if f.gone or dmg <= 0:
		return
	if f.side == 1:
		f.hp -= float(dmg)
		if f.hp <= 0.0:
			_kill_foe(f)
		return
	if f.door:
		if randf() < 0.5:
			_kill_hero(f)
		else:
			_log("  %s hält noch durch." % f.name, 1)
		return
	f.hp -= float(dmg)
	if f.hp <= 0.0:
		f.hp = 0.0
		f.door = true
		_log("  %s ist an der Schwelle!" % f.name, 2)
		_sync(f)
		_stress(f, 12.0)
		for h in heroes.duplicate():
			if h != f:
				_stress(h, 4.0)
		return
	_sync(f)


func _kill_foe(f: Fighter) -> void:
	foes.erase(f)
	f.gone = true
	killed += 1
	_renumber()
	_event("die", f)
	_log("  %s fällt." % f.name, 1)
	for h in heroes:
		_stress(h, -4.0)
	if f.holding != null:
		_release(f)
	if f.kind == "tentakel" and _boss_alive():
		_regrow.append(round_no + REGROW)
	elif f.kind == "kraken":
		_log("Der Kraken sinkt brüllend in die Tiefe, seine Fangarme erschlaffen.", 1)
		for t in foes.duplicate():
			if t.holding != null:
				_release(t)
			t.gone = true
			foes.erase(t)
			_event("die", t)
		_renumber()


func _kill_hero(f: Fighter) -> void:
	if f.held_by != null:
		f.held_by.holding = null
		f.held_by = null
	heroes.erase(f)
	f.gone = true
	if f.man != null:
		casualties.append(f.man)
	_renumber()
	_event("die", f)
	_log("  %s fällt im Kampf." % f.name, 2)
	_stress_heroes(12.0)
	if voy != null and f.man != null:
		for p in voy.bond_partners(f.man):
			var o := _fighter_of(p["other"] as CrewMember)
			if o == null or o.gone:
				continue
			if int(p["type"]) == Voyage.Bond.BROTHER:
				o.buff = maxi(o.buff, 3)
				_stress(o, 15.0)
				_log("  %s will Rache für seinen Bruder %s!" % [o.name, f.name], 2)
				_event("text", o, 0, false, "Rache!")
			elif int(p["type"]) == Voyage.Bond.COMRADE:
				_stress(o, 8.0)
				_log("  %s trauert um %s." % [o.name, f.name], 2)


func _fighter_of(m: CrewMember) -> Fighter:
	for h in heroes:
		if h.man == m:
			return h
	return null


# --- Maschine spielt ------------------------------------------------------------------------

func auto_play(limit: int = 400) -> void:
	var n := 0
	while state != "done" and n < limit:
		n += 1
		if state == "hero":
			auto_hero()
		elif state == "foe":
			act_foe()
		else:
			break
	if state != "done":
		result = "flee"
		state = "done"


## Der beste Zug für den aktiven Mann nach einfachen Regeln: Heilen, wenn jemand schwach ist, sonst den größten Nutzen.
func auto_hero() -> void:
	if state != "hero" or actor == null:
		return
	var f := actor
	var best_score := -1.0
	var best_skill := ""
	var best_target: Fighter = null
	for sid in f.skills:
		var s := String(sid)
		if not can_use(f, s):
			continue
		var sk: Dictionary = eff_skill(f, s)
		var tl := targets(f, s)
		if needs_target(s):
			for t in tl:
				var sc := _score(f, sk, s, t)
				if sc > best_score:
					best_score = sc
					best_skill = s
					best_target = t
		else:
			var sc2 := _score(f, sk, s, null)
			if sc2 > best_score:
				best_score = sc2
				best_skill = s
				best_target = null
	if best_skill != "" and best_score > 0.5:
		hero_act(best_skill, best_target)
		return
	# kein brauchbarer Zug: auf eine Reihe wechseln, aus der man etwas tun kann
	for r in heroes.size():
		if r == f.rank:
			continue
		var probe_ok := false
		for sid2 in f.skills:
			var sk2: Dictionary = Roles.skill(String(sid2))
			if (sk2["from"] as Array).has(r) and String(sk2["tgt"]) in ["foe", "foes"] and float(sk2["dmg"]) > 0.0:
				probe_ok = true
		if probe_ok:
			hero_move(r)
			return
	hero_pass()


func _score(f: Fighter, sk: Dictionary, sid: String, t: Fighter) -> float:
	var fx: Dictionary = sk["fx"]
	var tgt := String(sk["tgt"])
	var s := 0.0
	if tgt == "foe":
		var rng := damage_range(f, t, sk)
		var avg := (rng[0] + rng[1]) * 0.5
		var p := hit_chance(f, t, sk) / 100.0
		s = p * avg
		if avg * 1.2 >= t.hp:
			s += 25.0 * p
		s += (20.0 - minf(t.hp, 20.0)) * 0.2
		if fx.has("stun") and t.stun == 0 and t.stun_immune == 0:
			s += 8.0 * p + t.dmg_hi * 0.4
		if fx.has("bleed") and t.bleed_turns == 0 and not t.immune.has("bleed") and t.hp > 15.0:
			s += 5.0 * p
		if fx.has("mark") and t.mark == 0 and t.hp > 15.0:
			s += 5.0
		if fx.has("move"):
			s += 1.0 if int(fx["move"]) < 0 else (4.0 if f.rank == 0 and f.hp < 60.0 else -1.0)
		if t.holding != null:
			s += 14.0  # einen Kameraden aus dem Griff befreien
		if t.charge and fx.has("stun") and t.stun == 0:
			s += 40.0  # das Zerquetschen verhindern
		if fx.has("fire"):
			s *= 0.6  # danach kostet das Nachladen einen Zug
	elif tgt == "foes":
		var hit_list := targets(f, sid)
		if float(sk["dmg"]) <= 0.0:
			# Hohnlied: lohnt, wenn mehrere unmarkierte Gegner stehen
			var unmarked := 0
			for e in hit_list:
				if e.mark == 0:
					unmarked += 1
			s = 3.0 * float(unmarked) if unmarked >= 3 and round_no <= 6 else 0.0
		else:
			for e in hit_list:
				var rng2 := damage_range(f, e, sk)
				s += hit_chance(f, e, sk) / 100.0 * (rng2[0] + rng2[1]) * 0.5
			if hit_list.size() < 2:
				s *= 0.6
			if fx.has("fire"):
				s *= 0.6
	elif tgt == "self":
		if fx.has("reload"):
			s = 14.0
		elif fx.has("taunt"):
			s = 6.0 if f.rank == 0 and f.taunt == 0 and f.guard > 0 and heroes.size() > 1 else 0.5
		elif fx.has("buff"):
			s = 7.0 if f.buff == 0 and f.hp > 45.0 and round_no <= 5 and foes.size() >= 2 else 0.0
		else:
			var in_front := f.rank == 0
			s = 2.0
			if in_front and f.hp < 60.0:
				s = 9.0
			if f.guard > 0:
				s = 0.0
	elif tgt == "allies":
		if fx.has("cleanse"):
			for h in heroes:
				if h.stun > 0 or h.bleed_turns > 0 or h.blind > 0:
					s += 7.0
		else:
			s = 0.0 if f.buff > 0 or round_no > 5 else 3.0 * float(heroes.size())
			for h in heroes:
				if h.buff > 0:
					s = 0.0
	elif tgt == "ally":
		if fx.has("guard"):
			if t != f and t.guard == 0 and t.rank == 0 and t.hp < 70.0:
				s = 8.0
		elif fx.has("heal"):
			if t.hp <= 55.0:
				s = 18.0 + (100.0 - t.hp) * 0.2
			if t.door and t.hp <= 0.0:
				s += 20.0
		elif fx.has("stress_heal"):
			var st := t.man.stress if t.man != null else 0.0
			if st >= 55.0:
				s = 10.0 + (st - 55.0) * 0.2
	return s


## Zurück an die Männer: Kraft setzen, "an der Schwelle" heißt 10 Kraft. Gefallene meldet casualties.
func finish() -> void:
	if result == "flee":
		# wer beim Rückzug noch im Griff hängt, geht über Bord
		for f in heroes.duplicate():
			if f.held_by != null and not f.held_by.gone and f.man != null and overboard.size() < OVERBOARD_MAX:
				overboard.append(f.man)
				f.gone = true
	for f in all_heroes:
		if f.man == null or f.gone:
			continue
		f.man.kraft = 10.0 if f.hp <= 0.0 else clampf(f.hp, 0.0, 100.0)


## Die Reihenfolge der Zugleiste: die nächsten Kämpfer dieser Runde (ab dem aktiven).
func upcoming(count: int = 8) -> Array[Fighter]:
	var out: Array[Fighter] = []
	var i := maxi(cursor, 0)
	while i < order.size() and out.size() < count:
		if not order[i].gone:
			out.append(order[i])
		i += 1
	return out


## Wer soll in die Aufstellung? Von jeder Rolle der kräftigste, dann der Rest nach Kraft; Schild vorn, Skalde hinten.
static func auto_party(v: Voyage) -> Array[CrewMember]:
	var pool: Array[CrewMember] = []
	for m in v.crew:
		if m.state == CrewMember.State.ABOARD:
			pool.append(m)
	for m in v.reserve:
		pool.append(m)
	pool.sort_custom(func(a: CrewMember, b: CrewMember) -> bool: return a.kraft > b.kraft)
	var chosen: Array[CrewMember] = []
	for rid in [Roles.Id.SCHILD, Roles.Id.AXT, Roles.Id.BOGEN, Roles.Id.SKALDE, Roles.Id.MUSKET]:
		if chosen.size() >= 4:
			break
		for m in pool:
			if m.role == rid and m.kraft >= 25.0 and not chosen.has(m):
				chosen.append(m)
				break
	for m in pool:
		if chosen.size() >= 4:
			break
		if not chosen.has(m) and m.kraft >= 15.0:
			chosen.append(m)
	if chosen.is_empty() and not pool.is_empty():
		chosen.append(pool[0])
	chosen.sort_custom(func(a: CrewMember, b: CrewMember) -> bool: return _front_order(a.role) < _front_order(b.role))
	return chosen


static func _front_order(role_id: int) -> int:
	match role_id:
		Roles.Id.SCHILD:
			return 0
		Roles.Id.AXT:
			return 1
		Roles.Id.BOGEN, Roles.Id.MUSKET:
			return 2
	return 3
