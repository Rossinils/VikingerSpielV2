extends SceneTree

## Simulation für die Balance des Deckkampfes: viele Kämpfe pro Formation und Etappe mit der automatischen Besatzung.
## Aufruf: godot --headless --path . --script tools/combatsim.gd
## Ausgabe je Zeile: Formation, Etappe, Kraft der Männer, Siegquote, Verluste je Kampf, mittlere Kraft nach dem Kampf, Runden.

const RUNS := 120
var stress0 := 0.0  # --stress=N: Verzweiflung der Männer zu Beginn
var third := Roles.Id.BOGEN  # --musket: der dritte Mann ist Musketier statt Bogenschütze


func _init() -> void:
	var v := Voyage.new()
	v.auto_combat = true
	root.add_child(v)
	v.begin()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		elif a == "--musket":
			third = Roles.Id.MUSKET
		elif a.begins_with("--stress="):
			stress0 = float(a.substr(9))
	for formation in ["draugr", "raeuber", "haendler", "dorf", "kraken"]:
		if only != "" and formation != only:
			continue
		for stage in [1, 2, 3, 5, 8]:
			for kraft in [100.0, 60.0]:
				_sim(v, formation, stage, kraft)
	quit()


func _sim(v: Voyage, formation: String, stage: int, kraft: float) -> void:
	var wins := 0
	var deaths := 0
	var hp_left := 0.0
	var rounds := 0
	var seats := 0
	var swept := 0
	var heroic := 0
	var broke := 0
	for k in RUNS:
		var party: Array = []
		var roles := [Roles.Id.SCHILD, Roles.Id.AXT, third, Roles.Id.SKALDE]
		for i in 4:
			var m := CrewMember.new()
			m.id = 500 + i
			m.display_name = "T%d" % i
			m.role = roles[i]
			m.kraft = kraft
			m.stress = stress0
			party.append(m)
		var c := Combat.create(v, formation, party, Foes.units_for(formation, stage), stage)
		c.begin()
		c.auto_play()
		c.finish()
		if c.result == "win":
			wins += 1
		deaths += c.casualties.size()
		swept += c.overboard.size()
		for sn in c.snaps:
			if String(sn["kind"]) == "heroic":
				heroic += 1
			else:
				broke += 1
		for m in party:
			if not c.casualties.has(m):
				hp_left += m.kraft
				seats += 1
		rounds += c.round_no
	print("%-9s Etappe %d Kraft %3d  Sieg %3d %%  Tote %.2f  über Bord %.2f  Heldenmut %.2f  Bruch %.2f  Kraft danach %3d  Runden %.1f" % [
		formation, stage, roundi(kraft), roundi(100.0 * wins / RUNS), float(deaths) / RUNS, float(swept) / RUNS, float(heroic) / RUNS, float(broke) / RUNS, roundi(hp_left / maxf(seats, 1)), float(rounds) / RUNS])
