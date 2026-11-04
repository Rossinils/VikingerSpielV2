class_name BeatPlanner
extends RefCounted

## Aus den Ereignissen einer Handlung (`act`) wird ein Beat: eine Zeitleiste mit Ausholen, Schlag, Kontakt, Standbild, Zeitlupe,
## Kamerawunsch und Cues (SPEC 3.6 und 3.9, D1 7). Rein rechnend, zeichnet nichts, kennt keine Anzeige. Alle Zahlen stehen in `T`
## und `LEVEL` – das sind die Stellschrauben für das Gefühl des Kampfes.
## Zeiten eines Beats sind Bühnen-Millisekunden ab Beginn; Standbilder (`freezes`) sind Echtzeit, sie halten die Bühnenuhr an;
## `slows` verlangsamen sie in einem Fenster. Echtzeit = len + Standbilder + (Fenster / Faktor − Fenster).

enum Mode { FULL, SHORT }

## Echtzeit-Dauer je Beat-Art in ms (voll); kurz = die Hälfte (SPEC 3.9).
const REAL := {
	"held_nahkampf": 900.0, "held_bogen": 900.0, "held_muskete": 900.0, "gegner_nahkampf": 900.0, "gegner_fern": 900.0,
	"hilfe_ziel": 800.0, "hilfe_selbst": 700.0, "hilfe_alle": 900.0, "fehlschlag": 700.0,
	"held_krit": 1250.0, "gegner_krit": 1250.0,
	"flaeche_2": 900.0, "flaeche_3": 1020.0, "flaeche_4": 1150.0,
	"gegner_faellt_klein": 950.0, "gegner_faellt_gross": 1000.0,
	"mann_faellt": 1700.0, "mann_faellt_schwelle": 1721.0, "letzter_gegner": 1500.0,
	"schwelle_erreicht": 1140.0, "schwelle_haelt": 1300.0,
	"heldenmut": 1800.0, "zusammenbruch": 1800.0,
	"blutung": 350.0, "ausgesetzt": 600.0, "abwarten": 250.0, "platztausch": 360.0, "flucht": 600.0,
	"beschwoeren": 1100.0, "kraken_spannt": 1100.0, "wuergegriff": 1100.0, "ueber_bord": 1400.0, "kraken_quetscht": 1900.0,
	"kampfbeginn": 1300.0, "kraken_auftritt": 2600.0, "hinweis": 450.0,
}
## Nur diese Arten dürfen länger als der Takt (900 ms) dauern; alles andere hält ihn (Prüfung im Test).
const LONG_KINDS := ["held_krit", "gegner_krit", "flaeche_3", "flaeche_4", "gegner_faellt_klein", "gegner_faellt_gross", "mann_faellt",
	"mann_faellt_schwelle", "letzter_gegner", "schwelle_erreicht", "schwelle_haelt", "heldenmut", "zusammenbruch", "beschwoeren",
	"kraken_spannt", "wuergegriff", "ueber_bord", "kraken_quetscht", "kampfbeginn", "kraken_auftritt"]
## Fällt bei zu vielen wartenden Beats weg (nur Endzustand setzen)
const DROPPABLE := ["blutung", "abwarten", "platztausch", "hilfe_selbst", "ausgesetzt"]

## Zeiten in Bühnen-ms
const T := {
	"announce": 200.0,       # Gegnerzug: Ankündigung vor dem Ausholen (Schild, Licht)
	"wind_hero": 200.0, "wind_foe": 220.0, "wind_bow_foe": 270.0, "wind_gun": 180.0,
	"lunge": 50.0,           # Ausfall bis zum Kontakt
	"flight_bow": 140.0, "flight_bow_foe": 50.0, "flight_gun": 100.0, "flight_whip": 140.0,
	"area_gap": 130.0,       # Abstand der Kontakte bei Mehrfachtreffern
	"cast_hero": 200.0, "cast_self": 150.0,
	"hold": 150.0,           # Pose nach dem Kontakt
	"return": 160.0,         # Rückkehr in die Ruhe
	"hit_0": 100.0, "hit_1": 150.0,    # Treffer-Reaktion des Opfers
	"fall": [80.0, 100.0, 120.0],      # fall_0..2
	"fade": 700.0, "fade_big": 1200.0, # Ausblenden der Leiche
	"slide": 180.0,          # Nachrücken
	"dodge": 300.0,
	"release": 120.0,        # Kamera löst 120 ms nach dem Beat-Ende
	"cam_in": 140.0, "cam_in_crit": 110.0, "cam_in_kill": 300.0,
}

## Eskalationsstufen (FightLevel: 0 Streifer, 1 normal, 2 schwer, 3 krit, 4 Todesstoß)
const LEVEL := {
	"zoom": [1.0, 1.125, 1.125, 1.25, 1.375],
	"freeze": [40.0, 80.0, 110.0, 150.0, 160.0],
	"white": [33.0, 50.0, 50.0, 66.0, 80.0],
	"red": [100.0, 150.0, 150.0, 180.0, 220.0],
	"recoil": [2.0, 4.0, 6.0, 9.0, 9.0],
	"shake_px": [1.0, 2.0, 3.0, 5.0, 6.0],
	"shake_ms": [120.0, 200.0, 260.0, 360.0, 500.0],
	"trauma": [0.4, 0.6, 0.7, 0.85, 1.0],
	"halo_r": [26.0, 34.0, 42.0, 54.0, 64.0],
	"halo_ms": [160.0, 200.0, 220.0, 260.0, 350.0],
	"blood": [3, 7, 12, 16, 20],
	"spark": [0, 4, 6, 9, 9],
}

## Ausfall in Pixeln je Fertigkeit (sonst 12); wer sich nicht bewegt (Pfeil, Peitsche, Zauber), hat 0
const LUNGE := {"a_ansturm": 28.0, "f_ramm": 22.0, "s_stoss": 14.0, "f_stoss": 14.0, "f_biss": 28.0, "f_kr_schnabel": 14.0}
const LUNGE_DEFAULT := 12.0


class Beat extends RefCounted:
	var kind := ""
	var act := 0
	var actor: Combat.Fighter = null
	var side := 0
	var sk := ""
	var motion := "none"          # melee, bow, gun, whip, cast, guard, none
	var evs: Array = []
	var contacts: Array = []      # {t, kind: hit|miss|heal, who, n, crit, level, lethal, door, resist, hp0, hp1, first, ev}
	var level := 0
	var announce := 0.0           # Ankündigung (nur Gegner)
	var t_wind := 0.0             # Beginn des Ausholens
	var t_strike := 0.0           # Schlag / Loslassen / Wirkung
	var len_ms := 900.0           # Bühnen-ms
	var real_ms := 900.0          # Echtzeit-ms (Summe)
	var freezes: Array = []       # [[t_Bühne, ms_echt]]
	var slows: Array = []         # [[von, bis, Faktor]]
	var cues: Array = []          # {t, kind, data}
	var zoom_want := 1.0
	var foes_dead: Array = []     # Gegner, die in diesem Beat fallen
	var heroes_dead: Array = []
	var lunge := 0.0
	var big_death := false
	var last_foe := false
	var mode := Mode.FULL
	var short := false


static func k(mode: int) -> float:
	return 0.5 if mode == Mode.SHORT else 1.0


## Welche Bewegung gehört zur Fertigkeit dieses Handelnden?
static func motion_of(actor: Combat.Fighter, sk: String) -> String:
	if actor == null:
		return "none"
	var g := FightFx.go_fx(sk)
	match g:
		"arrow":
			return "gun" if (actor.side == 1 and actor.kind == "armbrust") else "bow"
		"bullet":
			return "gun"
		"whip":
			return "whip"
		"shield":
			return "guard"
	if FightFx.hit_fx(sk) != "":
		return "melee"
	return "cast"


## Stufe eines Treffers
static func level_of(ev: Dictionary) -> int:
	return FightLevel.of(int(ev.get("n", 0)), bool(ev.get("crit", false)), bool(ev.get("lethal", false)), bool(ev.get("dot", false)))


## Die Beat-Art nach der Entscheidungstabelle (D1 „Schnittstellen“). ctx: foes_left, kills (bisherige Gegnertode).
static func classify(evs: Array, ctx: Dictionary) -> String:
	if evs.is_empty():
		return ""
	var atk: Dictionary = {}
	var hits: Array = []
	var misses := 0
	var heals := 0
	var dies: Array = []
	var other := {}
	for e in evs:
		match String(e["type"]):
			"attack":
				if atk.is_empty():
					atk = e
			"hit":
				hits.append(e)
			"miss":
				misses += 1
			"heal":
				heals += 1
			"die":
				dies.append(e)
			_:
				other[String(e["type"])] = e
	if atk.is_empty():
		if not hits.is_empty():
			return "blutung"  # Schaden ohne Handlung: Blutung
		for t in ["heroic", "snap", "spawn", "overboard", "move", "wait", "flee", "skip", "text"]:
			if other.has(t):
				match t:
					"heroic":
						return "heldenmut"
					"snap":
						return "zusammenbruch"
					"spawn":
						return "beschwoeren"
					"overboard":
						return "ueber_bord"
					"move":
						return "platztausch"
					"wait":
						return "abwarten"
					"flee":
						return "flucht"
					"skip":
						return "ausgesetzt"
					"text":
						var tx := String(other[t].get("text", ""))
						if tx == "spannt sich!":
							return "kraken_spannt"
						if tx == "gepackt!":
							return "wuergegriff"
						return "hinweis"
		return ""
	var who: Combat.Fighter = atk["who"]
	var side := who.side if who != null else 0
	var max_lv := 0
	var crit := false
	var hero_killed := false
	var foe_killed := false
	var door_new := false
	var resist := false
	for h in hits:
		max_lv = maxi(max_lv, level_of(h))
		if bool(h.get("crit", false)):
			crit = true
		if bool(h.get("lethal", false)):
			var hw: Combat.Fighter = h["who"]
			if hw != null and hw.side == 0:
				hero_killed = true
			else:
				foe_killed = true
		if bool(h.get("door", false)) and not bool(h.get("lethal", false)) and not bool(h.get("resist", false)):
			door_new = true  # der Mann hat die Schwelle eben erst erreicht (war er schon dort, ist es ein Widerstand)
		if bool(h.get("resist", false)):
			resist = true
	if hero_killed:
		return "mann_faellt"
	if foe_killed:
		var left := int(ctx.get("foes_left", 99))
		var dead_now := 0
		for d in dies:
			var dw: Combat.Fighter = d["who"]
			if dw != null and dw.side == 1:
				dead_now += 1
		if left - dead_now <= 0:
			return "letzter_gegner"
		var kills := int(ctx.get("kills", 0))
		var big := kills == 0 or (kills + 1) % 3 == 0
		for d in dies:
			var dw2: Combat.Fighter = d["who"]
			if dw2 != null and dw2.side == 1:
				for pair in Foes.info(dw2.kind)["skills"]:
					if String(pair[0]) in ["f_heilen", "f_beschwoeren", "f_horn"]:
						big = true
		return "gegner_faellt_gross" if big else "gegner_faellt_klein"
	if resist:
		return "schwelle_haelt"
	if door_new:
		return "schwelle_erreicht"
	var contacts := hits.size() + misses
	if contacts == 0:
		var tg := String(atk.get("tgt", ""))
		if tg in ["self", "fself"]:
			return "hilfe_selbst"
		if tg in ["allies", "fallies", "heroes", "foes"] or (atk.get("tgts", []) as Array).size() > 1:
			return "hilfe_alle"
		return "hilfe_ziel"
	if crit:
		return "gegner_krit" if side == 1 else "held_krit"
	if contacts >= 2:
		return "flaeche_%d" % mini(contacts, 4)
	if hits.is_empty():
		return "fehlschlag"
	var mot := motion_of(who, String(atk.get("sk", "")))
	if side == 1:
		return "gegner_fern" if mot in ["bow", "gun", "whip"] else "gegner_nahkampf"
	if mot == "bow":
		return "held_bogen"
	if mot == "gun":
		return "held_muskete"
	return "held_nahkampf"


## Echtzeit-Länge eines Beats in ms (Bühne + Standbilder + Zeitlupen-Zuschlag)
static func real_length(b: Beat) -> float:
	var total := b.len_ms
	for f in b.freezes:
		total += float(f[1])
	for s in b.slows:
		total += (float(s[1]) - float(s[0])) * (1.0 / float(s[2]) - 1.0)
	return total


## Aus Ereignissen einen Beat planen. ctx: foes_left, kills, streak (gleiche Art in Folge), x_att/x_foc für nichts (die Kamera
## rechnet der Director beim Start, wenn die Figuren stehen).
static func plan(evs: Array, ctx: Dictionary, mode: int = Mode.FULL) -> Beat:
	var kind := classify(evs, ctx)
	if kind == "":
		return null
	var b := Beat.new()
	b.kind = kind
	b.mode = mode
	b.short = mode == Mode.SHORT
	b.evs = evs
	b.act = int(evs[0].get("act", 0))
	var km := k(mode)
	var atk: Dictionary = {}
	for e in evs:
		if String(e["type"]) == "attack" and atk.is_empty():
			atk = e
	if not atk.is_empty():
		b.actor = atk["who"]
		b.sk = String(atk.get("sk", ""))
		b.side = b.actor.side if b.actor != null else 0
		b.motion = motion_of(b.actor, b.sk)
	else:
		b.actor = evs[0]["who"]
		b.side = b.actor.side if b.actor != null else 0
	# Wirkungen (Kontakte)
	var first_hit := true
	for e in evs:
		var ty := String(e["type"])
		if (ty == "hit" and (atk.is_empty() or not bool(e.get("dot", false)))) or ty == "miss" or ty == "heal":
			var c := {"kind": ty, "who": e["who"], "n": int(e.get("n", 0)), "crit": bool(e.get("crit", false)), "lethal": bool(e.get("lethal", false)),
				"door": bool(e.get("door", false)), "resist": bool(e.get("resist", false)), "hp0": float(e.get("hp0", 0.0)), "hp1": float(e.get("hp1", 0.0)),
				"dot": bool(e.get("dot", false)), "ev": e, "first": false, "t": 0.0, "level": 0}
			if ty == "hit":
				c["level"] = level_of(e)
				if first_hit:
					c["first"] = true
					first_hit = false
				b.level = maxi(b.level, int(c["level"]))
			if ty == "hit" and bool(e.get("lethal", false)):
				var w: Combat.Fighter = e["who"]
				if w != null and w.side == 1:
					b.foes_dead.append(w)
				elif w != null:
					b.heroes_dead.append(w)
			b.contacts.append(c)
	for e in evs:
		if String(e["type"]) == "die":
			var dw: Combat.Fighter = e["who"]
			if dw != null and not b.foes_dead.has(dw) and not b.heroes_dead.has(dw):
				(b.foes_dead if dw.side == 1 else b.heroes_dead).append(dw)
	b.last_foe = kind == "letzter_gegner"
	b.big_death = kind in ["gegner_faellt_gross", "letzter_gegner"]
	b.lunge = float(LUNGE.get(b.sk, LUNGE_DEFAULT)) if b.motion == "melee" else 0.0
	if b.motion == "melee" and b.actor != null and b.actor.kind == "hund":
		b.lunge = 28.0
	# --- Zeitleiste -----------------------------------------------------------------------------------
	b.announce = (T["announce"] if b.side == 1 and b.motion != "none" else 0.0) * km
	var wind := 0.0
	var flight := 0.0
	match b.motion:
		"melee":
			wind = T["wind_foe"] if b.side == 1 else T["wind_hero"]
			flight = T["lunge"]
		"bow":
			wind = T["wind_bow_foe"] if b.side == 1 else T["wind_hero"]
			flight = T["flight_bow_foe"] if b.side == 1 else T["flight_bow"]
		"gun":
			wind = T["wind_gun"] + (60.0 if b.side == 1 else 0.0)
			flight = T["flight_gun"]
		"whip":
			wind = T["wind_foe"]
			flight = T["flight_whip"]
		"cast", "guard":
			wind = T["cast_self"] if kind == "hilfe_selbst" else T["cast_hero"]
			flight = 100.0
		_:
			wind = 0.0
			flight = 0.0
	wind *= km
	flight *= km
	b.t_wind = b.announce
	b.t_strike = b.t_wind + wind
	var tc0 := b.t_strike + flight
	var gap: float = float(T["area_gap"]) * km
	var idx := 0
	for c in b.contacts:
		c["t"] = tc0 + gap * float(idx)
		idx += 1
	# Standbild und Zeitlupe
	var tfirst := tc0
	for c in b.contacts:
		if String(c["kind"]) == "hit":
			tfirst = float(c["t"])
			break
	var fl := 0.0
	var first := true
	for c in b.contacts:
		if String(c["kind"]) != "hit":
			continue
		var lv := int(c["level"])
		var fz := float(LEVEL["freeze"][lv])
		var tgt: Combat.Fighter = c["who"]
		if lv == FightLevel.NORMAL and tgt != null and tgt.side == 0:
			fz = 60.0  # ein Mann empfängt: etwas weniger
		if b.kind == "gegner_faellt_klein" and lv < FightLevel.KILL:
			fz = maxf(fz, 100.0)
		if not first:
			fz *= 0.7
		if b.short:
			fz = minf(fz * 0.5, 40.0)
		b.freezes.append([float(c["t"]), fz])
		fl += fz
		first = false
	match b.kind:
		"mann_faellt", "letzter_gegner":
			if not b.short:
				b.slows.append([maxf(tfirst - 150.0, b.t_strike), tfirst, 0.35])
				b.slows.append([tfirst, tfirst + 130.0, 0.3])
		"held_krit", "gegner_krit":
			if not b.short:
				b.slows.append([tfirst, tfirst + 100.0, 0.5])
		"gegner_faellt_gross":
			if not b.short:
				b.slows.append([tfirst, tfirst + 100.0, 0.5])
	var target_real: float = float(REAL.get(kind, 900.0)) * km
	var extra := 0.0
	for s in b.slows:
		extra += (float(s[1]) - float(s[0])) * (1.0 / float(s[2]) - 1.0)
	if bool(ctx.get("lean", false)):
		# Zeitbudget des Kampfes aufgebraucht: kein Beat dauert mehr länger als der Takt, keine Zeitlupe
		b.slows.clear()
		extra = 0.0
		target_real = minf(target_real, 900.0 * km)
	b.len_ms = maxf(target_real - fl - extra, tc0 + 200.0 * km)
	# Ermüdung: dritte gleichartige Handlung in Folge, die Nachwirkung wird 20 % kürzer
	if int(ctx.get("streak", 0)) >= 2 and not b.contacts.is_empty():
		var last_t := tc0 + gap * float(maxi(b.contacts.size() - 1, 0))
		b.len_ms = last_t + (b.len_ms - last_t) * 0.8
	b.real_ms = real_length(b)
	b.zoom_want = zoom_wish(b)
	_cues(b, atk)
	return b


## Zoom-Wunsch (D1 3)
static func zoom_wish(b: Beat) -> float:
	if b.short:
		return 1.0
	if b.actor != null and (b.actor.kind in ["kraken"] or (b.actor.side == 1 and b.actor.kind == "tentakel")):
		return 1.0
	match b.kind:
		"mann_faellt", "mann_faellt_schwelle", "letzter_gegner":
			return float(LEVEL["zoom"][4])
		"held_krit", "gegner_krit", "schwelle_erreicht", "schwelle_haelt":
			return float(LEVEL["zoom"][3])
		"flaeche_2":
			return 1.125
		"flaeche_3", "flaeche_4":
			return 1.0
		"hilfe_ziel", "hilfe_selbst", "hilfe_alle", "fehlschlag":
			return 1.0625
		"held_nahkampf", "held_bogen", "held_muskete":
			return float(LEVEL["zoom"][maxi(b.level, 1)])
		"gegner_nahkampf", "gegner_fern":
			return 1.0625 if b.level >= 1 else 1.0
		"gegner_faellt_klein", "gegner_faellt_gross":
			return 1.0
	return 1.0


static func _cues(b: Beat, atk: Dictionary) -> void:
	var km := k(b.mode)
	if b.actor != null and b.motion != "none":
		b.cues.append({"t": 0.0, "kind": "turn_pulse", "data": {"f": b.actor}})
	if not atk.is_empty():
		var contacts: Array = []
		var tgts: Array = []
		for c in b.contacts:
			contacts.append(float(c["t"]) - b.t_wind)
			tgts.append(c["who"])
		b.cues.append({"t": b.t_wind, "kind": "go", "data": {"who": b.actor, "sk": b.sk, "tgts": tgts, "contacts": contacts, "contact_in": (contacts[0] if not contacts.is_empty() else 0.0), "release_in": b.t_strike - b.t_wind, "motion": b.motion,
			"miss": not b.contacts.is_empty() and b.contacts.all(func(x: Dictionary) -> bool: return String(x["kind"]) == "miss")}})
	var first_hit_done := false
	for c in b.contacts:
		var t := float(c["t"])
		var who: Combat.Fighter = c["who"]
		match String(c["kind"]):
			"hit":
				var lv := int(c["level"])
				var dirv := 1.0 if b.actor == null or b.actor.side == 0 else -1.0
				b.cues.append({"t": t, "kind": "impact", "data": {"att": b.actor, "tgt": who, "sk": b.sk, "n": int(c["n"]), "level": lv, "crit": bool(c["crit"]),
					"lethal": bool(c["lethal"]), "first": not first_hit_done, "dir": dirv, "hp0": float(c["hp0"]), "hp1": float(c["hp1"]), "dot": bool(c["dot"])}})
				b.cues.append({"t": t + 1.0, "kind": "number", "data": {"f": who, "cls": "crit" if bool(c["crit"]) else ("dot" if bool(c["dot"]) else "dmg"), "text": "−%d" % int(c["n"])}})
				first_hit_done = true
				if bool(c["lethal"]) and who != null:
					var dk := "kraken" if who.kind == "kraken" else ("sink" if who.kind == "tentakel" else "fall")
					b.cues.append({"t": t + 1.0, "kind": "die", "data": {"f": who, "kind": dk, "dir": dirv, "big": b.big_death}})
					if who.side == 0:
						b.cues.append({"t": t + 400.0 * km, "kind": "big", "data": {"text": "GEFALLEN", "sub": "%s kehrt nicht zurück" % who.name, "col": Color(0.9, 0.35, 0.35), "dur": 1.7}})
			"miss":
				b.cues.append({"t": t, "kind": "miss", "data": {"att": b.actor, "tgt": who, "sk": b.sk}})
				b.cues.append({"t": t + 1.0, "kind": "number", "data": {"f": who, "cls": "miss", "text": "verfehlt"}})
			"heal":
				b.cues.append({"t": b.t_strike, "kind": "heal", "data": {"who": b.actor, "tgt": who, "n": int(float(c["hp1"]) - float(c["hp0"])), "hp1": float(c["hp1"]), "sk": b.sk}})
	for e in b.evs:
		var ty := String(e["type"])
		if ty in ["text", "heroic", "snap", "spawn", "overboard", "skip", "flee"]:
			b.cues.append({"t": b.t_strike if ty != "text" else b.t_wind, "kind": "word", "data": {"f": e["who"], "type": ty, "text": String(e.get("text", ""))}})
	b.cues.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t"]) < float(y["t"]))
