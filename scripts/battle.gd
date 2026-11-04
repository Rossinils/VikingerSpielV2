class_name Battle
extends RefCounted

## Seeschlacht: bis zu sechs Runden. Der Gegner kündigt seinen nächsten Zug an (wie in Darkest Dungeon),
## du wählst eine Taktik, die Karten zeigen die Folgen. Gegnerstärke und Schaden wachsen mit der Etappe.
## Zustand liegt in Voyage.battle: {"enemy", "ehull", "ehull_max", "ecrew", "ecrew_max", "round", "intent", "reload"}.
##
## Taktiken:
##   ram     Rammen: Schaden am Gegner-Rumpf nach Ruder- und Steuerleistung, eigener Rumpf −8
##   arrows  Pfeilhagel: tötet Besatzung, mindert Enterer, Kraft −5
##   cannon  Kanonen: schwerer Schaden, braucht Pulver, danach eine Runde Nachladen
##   board   Entern: Aussicht nach Kampfstärke; Sieg −4 Besatzung, Niederlage ein Toter
##   shield  Schildwall: der nächste Gegnerzug wirkt nur zu 40 %
##   repair  Flicken: die Zimmerleute stopfen Löcher, kein Angriff
##   flee    Fliehen: Kampf endet ohne Beute, Rumpf −10 (−4 bei guter Ruderbesatzung)

enum Intent { RAM, BOARD, DIRGE, SHOOT, GRAB, CRUSH, INK }

const ROUNDS := 6
const ENEMIES := {
	"draugr": {"name": "Draugr-Schiff", "hull": 60.0, "crew": 6, "loot": 70, "intents": [[Intent.RAM, 35], [Intent.BOARD, 40], [Intent.DIRGE, 25]], "crew_name": "Draugr"},
	"raeuber": {"name": "Räuberschiff", "hull": 50.0, "crew": 8, "loot": 95, "intents": [[Intent.SHOOT, 40], [Intent.BOARD, 35], [Intent.RAM, 25]], "crew_name": "Räuber"},
	"kraken": {"name": "Kraken", "hull": 85.0, "crew": 6, "loot": 130, "intents": [[Intent.GRAB, 40], [Intent.CRUSH, 35], [Intent.INK, 25]], "crew_name": "Tentakel"},
}
const INTENT_NAMES := ["Rammstoß", "Enterkommando", "Totenklage", "Kanonenfeuer", "Tentakelgriff", "Zerquetschen", "Tintenwolke"]
const INTENT_HINTS := [
	"Schildwall mindert auf 40 %. Wer selbst rammt, nimmt +8.",
	"Entern wehrt ab (30 %), Pfeilhagel mindert (60 %), Schildwall (40 %).",
	"Schildwall mindert auf 40 %.",
	"Schildwall mindert auf 40 %. Wer entert oder rammt, ist im Weg (60 %).",
	"Entern kappt Tentakel (35 %), Pfeile und Kanonen mindern, Schildwall (40 %).",
	"Schildwall mindert auf 40 %. Wer rammt, drängt sich in den Griff (+8).",
	"Schildwall mindert auf 40 %.",
]


## Faktor auf alle Schäden der Gegner: +14 % je Etappe.
static func mult(voy: Voyage) -> float:
	return 1.0 + 0.14 * float(voy.stage - 1)


static func start(voy: Voyage) -> void:
	var key := String(Encounters.DATA[voy.encounter]["enemy"])
	var e: Dictionary = ENEMIES[key]
	var diff := voy.stage - 1
	var hull := float(e["hull"]) + 12.0 * float(diff)
	var crew := int(e["crew"]) + floori(float(diff) / 2.0)
	voy.battle = {"enemy": key, "ehull": hull, "ehull_max": hull, "ecrew": crew, "ecrew_max": crew, "round": 1, "intent": roll_intent(key), "reload": 0}


static func enemy_def(voy: Voyage) -> Dictionary:
	return ENEMIES[String(voy.battle["enemy"])]


static func roll_intent(key: String) -> int:
	var list: Array = ENEMIES[key]["intents"]
	var total := 0
	for it in list:
		total += int(it[1])
	var r := randi() % total
	for it in list:
		r -= int(it[1])
		if r < 0:
			return int(it[0])
	return int(list[0][0])


## Name, Wirkung (mit der echten Zahl dieser Etappe) und Hinweis zum angekündigten Zug.
static func intent_info(voy: Voyage) -> Dictionary:
	var m := mult(voy)
	var kind := int(voy.battle["intent"])
	var desc := ""
	match kind:
		Intent.RAM:
			desc = "Rumpf −%d" % roundi(16.0 * m)
		Intent.BOARD:
			desc = "2 Männer verletzt, Todesgefahr"
		Intent.DIRGE:
			desc = "Verzweiflung +%d für alle" % roundi(14.0 * m)
		Intent.SHOOT:
			desc = "Rumpf −%d, ein Mann verletzt" % roundi(11.0 * m)
		Intent.GRAB:
			desc = "Mann über Bord?, Rumpf −%d" % roundi(6.0 * m)
		Intent.CRUSH:
			desc = "Rumpf −%d" % roundi(22.0 * m)
		Intent.INK:
			desc = "Verzweiflung +%d, Kraft −8" % roundi(10.0 * m)
	return {"name": INTENT_NAMES[kind], "desc": desc, "hint": INTENT_HINTS[kind]}


static func ram_damage(voy: Voyage) -> int:
	return roundi(5.0 + 7.0 * (voy.power(Stations.Id.RUDER) + 0.5 * voy.power(Stations.Id.STEUER)) + voy.stat("ram"))


static func ram_self_damage(voy: Voyage) -> int:
	return roundi(8.0 * voy.stat("ram_self"))


static func cannon_damage(voy: Voyage) -> int:
	return roundi(float(voy.cannons()) * 14.0 * voy.stat("cannon_dmg") * (0.7 + 0.3 * clampf(voy.strength(), 0.0, 1.2)))


static func repair_amount(voy: Voyage) -> int:
	return roundi(voy.power(Stations.Id.ZIMMERMANN) * Voyage.REPAIR_PER_MAN * 1.2 * voy.stat("repair"))


static func board_chance(voy: Voyage) -> float:
	return clampf(0.5 + 0.45 * voy.strength() - 0.05 * float(voy.battle["ecrew"]) - 0.03 * float(voy.stage - 1), 0.1, 0.9)


static func flee_cost(voy: Voyage) -> int:
	return 4 if voy.power(Stations.Id.RUDER) >= 1.6 else 10


## Darf diese Taktik jetzt gewählt werden? (Kanonen brauchen Kanonen, Pulver und geladene Rohre.)
static func can_use(voy: Voyage, tactic: String) -> bool:
	match tactic:
		"cannon":
			return voy.cannons() > 0 and voy.powder >= 1 and int(voy.battle.get("reload", 0)) == 0
		"repair":
			return voy.power(Stations.Id.ZIMMERMANN) > 0.0 and voy.hull < voy.hull_max() - 1.0
	return true


## Text für die Taktikkarten (kurz, passt auf etwa 60 Pixel).
static func lines(voy: Voyage, tactic: String) -> Array:
	match tactic:
		"ram":
			return ["−%d Gegner" % ram_damage(voy), "du: Rumpf −%d" % ram_self_damage(voy)]
		"arrows":
			return ["~%d fallen" % roundi(voy.strength() * 3.0), "Kraft −5 alle", "Enterer ×0,6"]
		"cannon":
			if voy.cannons() == 0:
				return ["keine Kanonen", "im Laderaum", "gibt es welche"]
			if int(voy.battle.get("reload", 0)) > 0:
				return ["lädt nach …", "nächste Runde"]
			if voy.powder < 1:
				return ["kein Pulver"]
			return ["−%d Gegner" % cannon_damage(voy), "Pulver −1", "danach Pause"]
		"board":
			if String(voy.battle.get("enemy", "")) == "kraken":
				return ["Deckkampf", "Fangarme, dann", "der Körper"]
			return ["Deckkampf", "Gegnerbesatzung", "Verluste möglich"]
		"shield":
			return ["Gegnerzug ×0,4", "Kraft −3 alle"]
		"repair":
			return ["Rumpf +%d" % repair_amount(voy), "kein Angriff"]
		"flee":
			return ["Kampf endet", "Rumpf −%d" % flee_cost(voy), "keine Beute"]
	return []


static func decide(voy: Voyage, tactic: String) -> void:
	if tactic == "board":
		# Entern ist ein Deckkampf gegen den Rest der Besatzung des Gegners; am Kraken gegen Fangarme und Körper,
		# dessen Kraft nach dem Rammen und Beschießen schon gelitten hat
		var b := voy.battle
		var ratio := float(b["ecrew"]) / maxf(float(b["ecrew_max"]), 1.0)
		if String(b["enemy"]) == "kraken":
			var hp := clampf(float(b["ehull"]) / maxf(float(b["ehull_max"]), 1.0), 0.45, 1.0)
			voy.start_fight("kraken", {"source": "board"}, clampi(ceili(ratio * 2.0), 1, 2) + 1, hp)
		else:
			voy.start_fight(String(b["enemy"]), {"source": "board"}, clampi(ceili(ratio * 4.0), 1, 4))
		return
	voy.phase = Voyage.Phase.RESOLVE
	voy.traveling = false
	voy._steps = [
		{"delay": 0.9, "fn": Battle.act.bind(voy, tactic)},
		{"delay": 1.2, "fn": Battle.enemy.bind(voy, tactic)},
		{"delay": 1.0, "fn": Battle.after.bind(voy, tactic)},
	]
	voy._step_left = 0.9


## Rumpfschaden durch den Gegner: die Panzerung nimmt jedem Treffer etwas ab.
static func _hit(voy: Voyage, amount: float) -> float:
	var dmg := maxf(amount - voy.stat("armor"), 1.0)
	voy._damage(dmg)
	voy.impact = 1.0
	return dmg


static func act(voy: Voyage, tactic: String) -> void:
	var b := voy.battle
	match tactic:
		"ram":
			var dmg := ram_damage(voy)
			b["ehull"] = float(b["ehull"]) - dmg
			voy._damage(float(ram_self_damage(voy)))
			voy.impact = 1.0
			Sfx.play("crash")
			voy._fact("Ihr rammt das Schiff: Gegner-Rumpf −%d, eigener Rumpf −%d." % [dmg, ram_self_damage(voy)], Voyage.Kind.GOOD)
			voy._lore("battle_ram")
		"arrows":
			var n := clampi(int(voy.strength() * 3.0 + randf()), 0, 3)
			b["ecrew"] = maxi(int(b["ecrew"]) - n, 0)
			b["ehull"] = float(b["ehull"]) - 4.0
			for m in voy.crew:
				if m.state == CrewMember.State.ABOARD:
					m.kraft = maxf(m.kraft - 5.0, 0.0)
			Sfx.play("rope")
			voy._fact("Pfeilhagel: %d fallen (noch %d). Kraft −5 für alle." % [n, int(b["ecrew"])], Voyage.Kind.GOOD if n > 0 else Voyage.Kind.FACT)
			voy._lore("battle_arrows")
		"cannon":
			var dmg2 := cannon_damage(voy)
			var kills := floori(float(voy.cannons()) / 2.0)
			voy.powder = maxi(voy.powder - 1, 0)
			b["ehull"] = float(b["ehull"]) - dmg2
			b["ecrew"] = maxi(int(b["ecrew"]) - kills, 0)
			b["reload"] = 1
			voy.impact = 0.8
			Sfx.play("cannon")
			voy._fact("Breitseite: Gegner-Rumpf −%d%s. Pulver noch %d." % [dmg2, (", %d Mann fallen" % kills) if kills > 0 else "", voy.powder], Voyage.Kind.GOOD)
			voy._lore("battle_cannon")
		"board":
			if randf() < board_chance(voy):
				b["ecrew"] = maxi(int(b["ecrew"]) - 4, 0)
				var hurt := voy._random_aboard()
				if hurt != null:
					hurt.kraft = maxf(hurt.kraft - 30.0, 0.0)
				Sfx.play("crash")
				voy._fact("Ihr entert: vier fallen (noch %d)." % int(b["ecrew"]), Voyage.Kind.GOOD)
				voy._lore("battle_board_win")
			else:
				b["ecrew"] = maxi(int(b["ecrew"]) - 1, 0)
				var lost := voy._random_aboard()
				var name := ""
				if lost != null:
					name = lost.display_name
					voy._kill(lost, true)
					voy._note("killed", name, voy.encounter)
					voy._fact("%s fällt auf dem Deck des Gegners." % name, Voyage.Kind.BAD)
				var hurt2 := voy._random_aboard()
				if hurt2 != null:
					hurt2.kraft = maxf(hurt2.kraft - 25.0, 0.0)
				voy._lore("battle_board_lose", name)
		"shield":
			for m in voy.crew:
				if m.state == CrewMember.State.ABOARD:
					m.kraft = maxf(m.kraft - 3.0, 0.0)
			voy._fact("Schildwall: der nächste Angriff wirkt nur zu 40 %.", Voyage.Kind.FACT)
			voy._lore("battle_shield")
		"repair":
			var heal := repair_amount(voy)
			voy.hull = minf(voy.hull + float(heal), voy.hull_max())
			for m in voy.crew:
				if m.state == CrewMember.State.ABOARD and Stations.slot_station(m.slot) == Stations.Id.ZIMMERMANN:
					m.kraft = maxf(m.kraft - 5.0, 0.0)
			Sfx.play("hammer")
			voy._fact("Die Zimmerleute stopfen Löcher: Rumpf +%d." % heal, Voyage.Kind.GOOD)
			voy._lore("battle_repair")
		"flee":
			var cost := flee_cost(voy)
			voy._damage(float(cost))
			Sfx.play("creak")
			voy._fact("Ihr dreht ab. Ein letzter Treffer: Rumpf −%d." % cost, Voyage.Kind.BAD)
			voy._lore("battle_flee")


static func enemy(voy: Voyage, tactic: String) -> void:
	var b := voy.battle
	if tactic == "flee" or float(b["ehull"]) <= 0.0 or int(b["ecrew"]) <= 0:
		return
	var m := mult(voy)
	var shield := 0.4 if tactic == "shield" else 1.0
	var enemy_key := String(b["enemy"])
	match int(b["intent"]):
		Intent.RAM:
			var dmg := _hit(voy, (16.0 * shield + (8.0 if tactic == "ram" else 0.0)) * m)
			Sfx.play("crash")
			voy._fact("Rammstoß: Rumpf −%d" % roundi(dmg), Voyage.Kind.BAD)
			voy._lore("draugr_ram" if enemy_key == "draugr" else "raider_ram")
		Intent.BOARD:
			var f := shield
			if tactic == "board":
				f *= 0.3
			elif tactic == "arrows":
				f *= 0.6
			for k in 2:
				var man := voy._random_aboard()
				if man != null:
					man.kraft = maxf(man.kraft - 25.0 * f * m, 0.0)
			voy._fact("Enterkommando: zwei Männer verletzt (Kraft −%d)." % roundi(25.0 * f * m), Voyage.Kind.BAD)
			if randf() < 0.3 * f * minf(m, 1.6):
				var victim := voy._random_aboard()
				if victim != null:
					voy._kill(victim, true)
					voy._note("killed", victim.display_name, voy.encounter)
					voy._fact("%s wird über die Reling gezogen." % victim.display_name, Voyage.Kind.BAD)
			voy._lore("draugr_board" if enemy_key == "draugr" else "raider_board")
		Intent.DIRGE:
			for man in voy.crew:
				if man.state == CrewMember.State.ABOARD:
					voy._add_stress(man, 14.0 * shield * m)
			Sfx.play("heartbeat")
			voy._fact("Totenklage: Verzweiflung +%d für alle." % roundi(14.0 * shield * m), Voyage.Kind.BAD)
			voy._lore("draugr_dirge")
		Intent.SHOOT:
			var close := 0.6 if (tactic == "board" or tactic == "ram") else 1.0  # wer nah heran ist, steht im toten Winkel
			var dmg2 := _hit(voy, 11.0 * shield * close * m)
			var man2 := voy._random_aboard()
			if man2 != null:
				man2.kraft = maxf(man2.kraft - 20.0 * shield * close, 0.0)
			Sfx.play("cannon")
			voy._fact("Kanonenfeuer: Rumpf −%d, ein Mann verletzt." % roundi(dmg2), Voyage.Kind.BAD)
			voy._lore("raider_shoot")
		Intent.GRAB:
			var gf := shield
			if tactic == "board":
				gf *= 0.35
			elif tactic == "arrows" or tactic == "cannon":
				gf *= 0.7
			var gd := _hit(voy, 6.0 * gf * m)
			var prey := voy._random_aboard()
			if prey != null and randf() < 0.6 * gf * minf(m, 1.5) and voy._pending.size() < 2:
				voy._throw_overboard(prey)
				voy._fact("Ein Tentakel reißt %s von Bord. Rumpf −%d." % [prey.display_name, roundi(gd)], Voyage.Kind.BAD)
			else:
				voy._fact("Ein Tentakel tastet über das Deck: Rumpf −%d, alle halten sich fest." % roundi(gd), Voyage.Kind.BAD)
			Sfx.play("splash")
			voy._lore("kraken_grab")
		Intent.CRUSH:
			var cd := _hit(voy, (22.0 * shield + (8.0 if tactic == "ram" else 0.0)) * m)
			Sfx.play("crash")
			voy._fact("Der Kraken umschlingt das Schiff: Rumpf −%d" % roundi(cd), Voyage.Kind.BAD)
			voy._lore("kraken_crush")
		Intent.INK:
			for man3 in voy.crew:
				if man3.state == CrewMember.State.ABOARD:
					voy._add_stress(man3, 10.0 * shield * m)
					man3.kraft = maxf(man3.kraft - 8.0 * shield, 0.0)
			Sfx.play("fog")
			voy._fact("Tintenwolke: Verzweiflung +%d, Kraft −%d für alle." % [roundi(10.0 * shield * m), roundi(8.0 * shield)], Voyage.Kind.BAD)
			voy._lore("kraken_ink")
	voy._check_breakdown()


static func after(voy: Voyage, tactic: String) -> void:
	var b := voy.battle
	var won := float(b["ehull"]) <= 0.0 or int(b["ecrew"]) <= 0
	if int(b["reload"]) > 0 and tactic != "cannon":
		b["reload"] = int(b["reload"]) - 1
	if won and tactic != "flee":
		var loot := roundi(float(enemy_def(voy)["loot"]))
		voy._apply_fx({"loot": loot, "proviant": 4, "stress_all": -10})
		Sfx.play("coin")
		var suffix := "" if String(b["enemy"]) == "draugr" else "_" + String(b["enemy"])  # Saga und Skalde je nach Gegner
		voy._note("battle_win" + suffix)
		var gone := "Der Kraken sinkt unter die Wellen." if String(b["enemy"]) == "kraken" else "Das Schiff versinkt."
		var real := roundi(float(loot) * voy.stat("loot") * (1.0 + 0.12 * float(voy.stage - 1)))
		voy._fact("%s Proviant +4, Verzweiflung −10 für alle." % gone, Voyage.Kind.GOOD)
		voy._fact("Beute +%d aus: %s." % [real, Encounters.booty_for("battle_" + String(b["enemy"]), true)], Voyage.Kind.GOOD)
		voy._lore("battle_win" + suffix)
		if String(b["enemy"]) == "kraken":
			voy._find_item(Items.Rarity.EPISCH, 1.5, "Aus dem Wrack des Kraken")  # der Boss lässt immer etwas Besonderes zurück
		elif randf() < 0.3:
			voy._find_item(0, 0.5, "Vom versunkenen Schiff")
		voy.gain_xp(30 + 4 * voy.stage)
		_leave(voy)
	elif tactic == "flee" or voy.hull <= 0.0 or voy.aboard_count() == 0:
		_leave(voy)
	elif int(b["round"]) >= ROUNDS:
		voy._lore("battle_timeout" if String(b["enemy"]) == "draugr" else "battle_timeout_" + String(b["enemy"]))
		_leave(voy)
	else:
		b["round"] = int(b["round"]) + 1
		b["intent"] = roll_intent(String(b["enemy"]))
		voy.phase = Voyage.Phase.ENCOUNTER
		voy._steps.clear()


static func _leave(voy: Voyage) -> void:
	voy._leaving = true
	voy.battle = {}
	voy._after_encounter()
