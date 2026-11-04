extends SceneTree

## Nur für die Analyse (Arbeitskopie "ablauf"): Rechenzeit des Schnellmodus (Combat.create + begin + auto_play + finish), Grundwert gegen spätere Umbauten.


func _init() -> void:
	var v := Voyage.new()
	v.auto_combat = true
	root.add_child(v)
	v.begin()
	seed(3)
	for form in ["draugr", "kraken"]:
		var t0 := Time.get_ticks_usec()
		var n := 0
		var events := 0
		for k in 400:
			var party: Array = []
			var roles := [Roles.Id.SCHILD, Roles.Id.AXT, Roles.Id.BOGEN, Roles.Id.SKALDE]
			for i in 4:
				var m := CrewMember.new()
				m.id = 950 + i
				m.display_name = "T%d" % i
				m.role = roles[i]
				m.kraft = 100.0
				party.append(m)
			var c := Combat.create(v, form, party, Foes.units_for(form, 3), 3)
			c.begin()
			c.auto_play()
			c.finish()
			events += c._ev_id
			n += 1
		var dt := float(Time.get_ticks_usec() - t0) / 1000.0
		print("%-8s %d Kämpfe in %.0f ms = %.2f ms je Kampf, %.1f Ereignisse je Kampf" % [form, n, dt, dt / float(n), float(events) / float(n)])
	quit()
