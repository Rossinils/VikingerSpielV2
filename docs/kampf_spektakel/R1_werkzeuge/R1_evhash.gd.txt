extends SceneTree

## Nur für die Analyse (Arbeitskopie "ablauf"): Prüfsummen über viele Kämpfe mit festem Seed.
## Die Logik-Prüfsumme (Ergebnis, Runden, Verluste, Kraft) darf sich bei einem Umbau der Ereignisse NIE ändern.
## Die Ereignis-Prüfsumme (Typen und Reihenfolge der Ereignisse) ändert sich nur, wenn neue Ereignisse dazukommen.

var v: Voyage


func _init() -> void:
	v = Voyage.new()
	v.auto_combat = true
	root.add_child(v)
	v.begin()
	var logic := ""
	var evs := ""
	var fights := 0
	for form in ["draugr", "raeuber", "haendler", "dorf", "kraken"]:
		for s in range(1, 41):
			seed(s * 7919 + form.length())
			var party: Array = []
			var roles := [Roles.Id.SCHILD, Roles.Id.AXT, Roles.Id.BOGEN, Roles.Id.SKALDE]
			for i in 4:
				var m := CrewMember.new()
				m.id = 800 + i
				m.display_name = "P%d" % i
				m.role = roles[i]
				m.kraft = 100.0
				m.stress = 0.0
				party.append(m)
			var c := Combat.create(v, form, party, Foes.units_for(form, 3), 3)
			c.begin()
			c.auto_play()
			c.finish()
			fights += 1
			logic += "%s|%d|%d|%d|%d|%d|%d;" % [c.result, c.round_no, c.killed, c.fled, c.casualties.size(), c.overboard.size(), c.snaps.size()]
			for m in party:
				logic += "%d," % roundi(m.kraft)
			for ev in c.events:
				evs += String(ev["type"]).substr(0, 2) + String(ev["sk"]) + ("c" if bool(ev["crit"]) else "") + str(int(ev["n"])) + ";"
	print("Kämpfe: %d  Logik-Prüfsumme: %d  Ereignis-Prüfsumme: %d  (Länge Ereignistext %d)" % [fights, logic.hash(), evs.hash(), evs.length()])
	quit()
