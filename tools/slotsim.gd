extends SceneTree

## Rechnet die Automaten durch (Rückzahlung, Trefferquote, Freispiele), ohne Anzeige:
##   godot --headless --path . --script tools/slotsim.gd -- --n=400000

func _initialize() -> void:
	var n := 200000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
	_norn(n)
	_loki(n)
	quit()


func _norn(n: int) -> void:
	var s := Slots.new("norn", 100)
	s.rng.seed = 12345
	var bet := 100.0
	var base_win := 0.0
	var scatter_part := 0.0
	var free_win := 0.0
	var triggers := 0
	var retriggers := 0
	var bolts := 0
	var hits := 0
	var big5 := 0
	var big20 := 0
	var big60 := 0
	var max_total := 0.0
	var fg_wins: Array[float] = []
	var stack_spins := 0
	var free_spins := 0
	var jackpots := 0
	for i in n:
		var r := s.spin()
		var total := float(r["win"])
		if int(r["jackpot"]) > 0 or bool(r["jackpot"]):
			jackpots += 1
		if not (r["bolt"] as Array).is_empty():
			bolts += 1
		if total > 0.0:
			hits += 1
		base_win += total
		var fg := 0.0
		if int(r["trigger"]) > 0:
			triggers += 1
			scatter_part += float(Slots.SCATTER_PAY[mini((r["scatter"] as Array).size(), 5) - 3]) * bet
			while s.in_free():
				var f := s.spin()
				free_spins += 1
				fg += float(f["win"])
				if int(f["retrigger"]) > 0:
					retriggers += 1
				if not (f["stacks"] as Array).is_empty():
					stack_spins += 1
				if bool(f["jackpot"]):
					jackpots += 1
			free_win += fg
			fg_wins.append(fg / bet)
		var spin_total := total + fg
		max_total = maxf(max_total, spin_total)
		if spin_total >= 5.0 * bet:
			big5 += 1
		if spin_total >= 20.0 * bet:
			big20 += 1
		if spin_total >= 60.0 * bet:
			big60 += 1
	var nf := float(n)
	fg_wins.sort()
	var med := 0.0 if fg_wins.is_empty() else fg_wins[fg_wins.size() / 2]
	var mean_fg := 0.0 if fg_wins.is_empty() else free_win / bet / float(fg_wins.size())
	print("== Nornenwalzen, %d Dreh" % n)
	print("Rückzahlung gesamt: %.1f %%   (Grundspiel inkl. Blitzrunen-Zahlung %.1f %%, Freispiele %.1f %%)" % [(base_win + free_win) / (nf * bet) * 100.0, base_win / (nf * bet) * 100.0, free_win / (nf * bet) * 100.0])
	print("Trefferquote Grundspiel: %.1f %%   Blitzschlag: 1 von %.0f" % [float(hits) / nf * 100.0, nf / maxf(float(bolts), 1.0)])
	print("Freispiele: 1 von %.1f Drehs   im Schnitt %.1f Einsätze (Median %.1f, Höchstes %.0f)   Nachlegen: %d" % [nf / maxf(float(triggers), 1.0), mean_fg, med, 0.0 if fg_wins.is_empty() else fg_wins[fg_wins.size() - 1], retriggers])
	print("Freispiele mit Stapel: %.1f %% der Freidrehs   Joker-Linien fünffach: %d" % [float(stack_spins) / maxf(float(free_spins), 1.0) * 100.0, jackpots])
	print("Dreh (samt Freispielen) >= 5x: 1 von %.0f   >= 20x: 1 von %.0f   >= 60x: 1 von %.0f   Höchster: %.0fx" % [nf / maxf(float(big5), 1.0), nf / maxf(float(big20), 1.0), nf / maxf(float(big60), 1.0), max_total / bet])


func _loki(n: int) -> void:
	var s := Slots.new("loki", 100)
	s.rng.seed = 777
	var bet := 100.0
	var total := 0.0
	var wins := 0
	var curses := 0
	var big10 := 0
	var big50 := 0
	var jack := 0
	var maxx := 0.0
	for i in n:
		var r := s.spin()
		var w := float(r["win"])
		total += w
		if bool(r["curse"]):
			curses += 1
		elif w > 0.0:
			wins += 1
		if w >= 10.0 * bet:
			big10 += 1
		if w >= 50.0 * bet:
			big50 += 1
		if bool(r["jackpot"]):
			jack += 1
		maxx = maxf(maxx, w)
	var nf := float(n)
	print("== Adlerssons Walzen, %d Dreh" % n)
	print("Rückzahlung: %.1f %%   Gewinn in %.1f %% der Drehs   Adlerssons Streich in %.1f %%" % [total / (nf * bet) * 100.0, float(wins) / nf * 100.0, float(curses) / nf * 100.0])
	print(">= 10x: 1 von %.0f   >= 50x: 1 von %.0f   Odinsauge-Linie: 1 von %.0f   Höchster: %.0fx" % [nf / maxf(float(big10), 1.0), nf / maxf(float(big50), 1.0), nf / maxf(float(jack), 1.0), maxx / bet])
