class_name Slots
extends RefCounted

## Die Spielautomaten, reine Regeln ohne Anzeige (Anzeige: scripts/slot_view.gd, Einbindung: scripts/voyage.gd).
##
## "norn" (Nornenwalzen): 5 Walzen zu 3 Reihen, 10 feste Gewinnlinien von links nach rechts. Das Odinsauge ist Joker.
##   Drei Blitzrunen irgendwo lösen die Freispiele aus ("Es lebt!"): Der Draugr erwacht, ist dann Joker, und eine
##   Walze voller Draugr (ein Stapel) zählt als Faktor für den ganzen Dreh. Eine Blitzrune auf der ersten Walze
##   ist im Freispiel ein Power-Up (Faktor 2 bis 10), zwei weitere Blitzrunen geben drei Freispiele dazu.
##   Im Grundspiel schlägt manchmal ein Blitz ein und macht ein paar Felder zu Jokern.
## "loki" (Adlerssons Walzen): 3 Walzen, 3 Reihen, 5 Linien. Der Einsatz ist ein Wert (Beute, Rumpf oder ein Mann), der
##   Gewinn ein Vielfaches davon. Drei Masken auf einer Linie sind Adlerssons Streich: der Einsatz ist weg und es kommt
##   eine Strafe dazu. Nach einem Gewinn gibt es die Risikoleiter (Münzwurf: verdoppeln oder alles verlieren).

enum Sym { SCHILD, AXT, HORN, RABE, SCHIFF, HAMMER, DRAUGR, AUGE, BLITZ, WOLF, MASKE }
enum Mode { BASE, FREE }

const NAMES := ["Schild", "Axt", "Horn", "Rabe", "Drachenschiff", "Mjölnir", "Draugr", "Odinsauge", "Blitzrune", "Wolf", "Adlerssons Maske"]

const NORN_COLS := 5
const ROWS := 3
const LOKI_COLS := 3

## Zeile (0 oben) je Walze, für jede der zehn Linien
const NORN_LINES := [
	[1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
	[0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0],
]
const LOKI_LINES := [[1, 1, 1], [0, 0, 0], [2, 2, 2], [0, 1, 2], [2, 1, 0]]

## Gewinn in Vielfachen des Linieneinsatzes (Einsatz / 10) für 3, 4 und 5 gleiche Symbole
const NORN_PAYS := {
	Sym.SCHILD: [3, 10, 30], Sym.AXT: [4, 12, 40], Sym.HORN: [5, 15, 50], Sym.RABE: [8, 25, 80],
	Sym.SCHIFF: [12, 40, 150], Sym.HAMMER: [20, 80, 300], Sym.DRAUGR: [30, 120, 500], Sym.AUGE: [40, 200, 1000],
}
## Blitzrunen (3, 4, 5) zahlen dazu in Vielfachen des ganzen Einsatzes und geben so viele Freispiele
const SCATTER_PAY := [2, 10, 50]
const FREE_SPINS := [8, 12, 16]
const RETRIGGER := 3
const FREE_MAX := 30
const FREE_CAP := 300.0  # ein Freispiel-Durchgang zahlt höchstens so viele Einsätze
const POWERUPS := [[2, 50], [3, 28], [5, 16], [10, 6]]  # [Faktor, Gewicht]
const BOLT_CHANCE := 0.05

## Gewichte der Symbole je Feld im Grundspiel und im Freispiel; Blitzrunen je Walze
const NORN_W := {Sym.SCHILD: 22, Sym.AXT: 20, Sym.HORN: 18, Sym.RABE: 15, Sym.SCHIFF: 11, Sym.HAMMER: 8, Sym.DRAUGR: 5, Sym.AUGE: 4}
const FREE_W := {Sym.SCHILD: 20, Sym.AXT: 18, Sym.HORN: 16, Sym.RABE: 14, Sym.SCHIFF: 10, Sym.HAMMER: 8, Sym.DRAUGR: 8, Sym.AUGE: 3}
const NORN_BLITZ := [5, 4, 5, 4, 5]
const FREE_BLITZ := [3, 2, 2, 2, 2]
const FREE_STACK := [0.03, 0.04, 0.05, 0.04, 0.03]  # Chance, dass eine ganze Walze Draugr zeigt

const LOKI_W := {Sym.RABE: 22, Sym.WOLF: 19, Sym.SCHIFF: 14, Sym.HAMMER: 10, Sym.AUGE: 8, Sym.MASKE: 17}
## Gewinn in Vielfachen des Einsatzwertes für drei gleiche auf einer Linie
const LOKI_PAYS := {Sym.RABE: 2, Sym.WOLF: 5, Sym.SCHIFF: 12, Sym.HAMMER: 25, Sym.AUGE: 100}
const RISK_STEPS := 4  # so oft darf man verdoppeln

var machine := "norn"
var bet := 10
var mode := Mode.BASE
var free_left := 0
var free_total := 0  # bisher im laufenden Freispiel gewonnen
var free_done := 0  # gespielte Freispiele
var free_start := 0  # so viele wurden zu Beginn vergeben
var rng := RandomNumberGenerator.new()
var force_trigger := false  # der nächste Dreh bringt sicher die Freispiele
var spins := 0


func _init(machine_id: String = "norn", bet_value: int = 10) -> void:
	machine = machine_id
	bet = bet_value
	rng.randomize()


func cols() -> int:
	return NORN_COLS if machine == "norn" else LOKI_COLS


func lines() -> Array:
	return NORN_LINES if machine == "norn" else LOKI_LINES


## Einsatzstufen der Nornenwalzen: 1x, 2x und 5x einer Grundmenge, die mit der Etappe wächst.
static func bet_levels(stage: int) -> Array[int]:
	var unit := 4 + 2 * stage
	return [unit, unit * 2, unit * 5]


## Der Einsatz eines Freidrehs nach einem Sieg; nach dem Kraken ist er höher.
static func bonus_bet(stage: int, kraken: bool = false) -> int:
	var lv := bet_levels(stage)
	return lv[1] + (lv[0] if kraken else 0)


static func sym_name(s: int) -> String:
	return String(NAMES[s])


func in_free() -> bool:
	return mode == Mode.FREE


# --- Ziehen --------------------------------------------------------------------

func _pick(weights: Dictionary, extra_blitz: int = 0) -> int:
	var total := extra_blitz
	for k in weights:
		total += int(weights[k])
	var r := rng.randi_range(0, total - 1)
	for k in weights:
		r -= int(weights[k])
		if r < 0:
			return int(k)
	return Sym.BLITZ


func _roll_norn(free: bool) -> Array:
	var w: Dictionary = FREE_W if free else NORN_W
	var grid: Array = []
	for r in NORN_COLS:
		var col: Array = []
		var blitz: int = (FREE_BLITZ if free else NORN_BLITZ)[r]
		if free and rng.randf() < float(FREE_STACK[r]):
			for row in ROWS:
				col.append(int(Sym.DRAUGR))
		else:
			for row in ROWS:
				col.append(_pick(w, blitz))
		grid.append(col)
	return grid


func _roll_loki() -> Array:
	var grid: Array = []
	for r in LOKI_COLS:
		var col: Array = []
		for row in ROWS:
			col.append(_pick(LOKI_W))
		grid.append(col)
	return grid


## Drei Blitzrunen auf verschiedene Walzen legen (für den sicheren Auslöser).
func _plant_scatters(grid: Array, count: int) -> void:
	var reels := [0, 1, 2, 3, 4]
	for i in reels.size():
		var j := rng.randi_range(i, reels.size() - 1)
		var t: int = reels[i]
		reels[i] = reels[j]
		reels[j] = t
	for k in count:
		grid[reels[k]][rng.randi_range(0, ROWS - 1)] = int(Sym.BLITZ)


# --- Auswerten -----------------------------------------------------------------

func _is_wild(s: int, free: bool) -> bool:
	return s == Sym.AUGE or (free and s == Sym.DRAUGR)


## Gewinnlinien der Nornenwalzen: [{line, sym, count, pay (in Linieneinsätzen), cells}]
func _norn_lines(grid: Array, free: bool) -> Array:
	var out: Array = []
	for li in NORN_LINES.size():
		var line: Array = NORN_LINES[li]
		var syms: Array[int] = []
		for r in NORN_COLS:
			syms.append(int(grid[r][int(line[r])]))
		var base := -1
		for s in syms:
			if s == Sym.BLITZ:
				break
			if not _is_wild(s, free):
				base = s
				break
		var pay_sym := base
		if base < 0:
			pay_sym = Sym.DRAUGR if free else Sym.AUGE  # nur Joker auf der Linie
		var n := 0
		for s in syms:
			if s == base or (s != Sym.BLITZ and _is_wild(s, free)):
				n += 1
			else:
				break
		if n >= 3 and NORN_PAYS.has(pay_sym):
			var cells: Array = []
			for r in n:
				cells.append([r, int(line[r])])
			out.append({"line": li, "sym": pay_sym, "count": n, "pay": int((NORN_PAYS[pay_sym] as Array)[n - 3]), "cells": cells})
	return out


func _loki_lines(grid: Array) -> Array:
	var out: Array = []
	for li in LOKI_LINES.size():
		var line: Array = LOKI_LINES[li]
		var a: int = int(grid[0][int(line[0])])
		if int(grid[1][int(line[1])]) == a and int(grid[2][int(line[2])]) == a:
			var cells: Array = []
			for r in LOKI_COLS:
				cells.append([r, int(line[r])])
			out.append({"line": li, "sym": a, "count": 3, "pay": int(LOKI_PAYS.get(a, 0)), "cells": cells})
	return out


func _count_sym(grid: Array, sym: int) -> Array:
	var cells: Array = []
	for r in grid.size():
		for row in ROWS:
			if int(grid[r][row]) == sym:
				cells.append([r, row])
	return cells


## Ein Dreh. Im Grundspiel zahlt der Aufrufer vorher den Einsatz; im Freispiel kostet er nichts.
## Ergebnis: grid, lines, win (ganze Beute), mult, trigger (vergebene Freispiele), retrigger, stacks, powerup, bolt,
## scatter (Zellen), free (war ein Freispiel), free_left, free_total, ended (Freispiel ist damit vorbei),
## jackpot (fünf Augen auf einer Linie), curse (Adlersson), big (Gewinn / Einsatz)
func spin() -> Dictionary:
	spins += 1
	if machine == "loki":
		return _spin_loki()
	return _spin_norn()


func _spin_norn() -> Dictionary:
	var free := mode == Mode.FREE
	if free:
		free_left -= 1
		free_done += 1
	var grid := _roll_norn(free)
	var res := {"free": free, "trigger": 0, "retrigger": 0, "stacks": [], "powerup": 0, "bolt": [], "jackpot": false, "ended": false, "curse": false}
	if not free:
		if force_trigger:
			_plant_scatters(grid, 3)
			force_trigger = false
		elif rng.randf() < BOLT_CHANCE:
			var cells: Array = []
			for k in rng.randi_range(2, 5):
				var rr := rng.randi_range(0, NORN_COLS - 1)
				var ro := rng.randi_range(0, ROWS - 1)
				if int(grid[rr][ro]) != Sym.BLITZ:
					grid[rr][ro] = int(Sym.AUGE)
					cells.append([rr, ro])
			res["bolt"] = cells
	var win_lines := _norn_lines(grid, free)
	var units := 0
	var jackpot := false
	for wl in win_lines:
		units += int(wl["pay"])
		if int(wl["sym"]) == Sym.AUGE and int(wl["count"]) == 5:
			jackpot = true
	var total := float(units) * float(bet) / 10.0
	var scatter := _count_sym(grid, Sym.BLITZ)
	var mult := 1
	if free:
		var stacks: Array = []
		for r in NORN_COLS:
			if int(grid[r][0]) == Sym.DRAUGR and int(grid[r][1]) == Sym.DRAUGR and int(grid[r][2]) == Sym.DRAUGR:
				stacks.append(r)
		res["stacks"] = stacks
		mult = maxi(stacks.size(), 1)
		var other: Array = []
		for cell in scatter:
			if int((cell as Array)[0]) == 0:
				res["powerup"] = _roll_powerup()
			else:
				other.append(cell)
		if int(res["powerup"]) > 0:
			mult *= int(res["powerup"])
		if other.size() >= 2 and free_left + RETRIGGER <= FREE_MAX:
			free_left += RETRIGGER
			res["retrigger"] = RETRIGGER
	else:
		if scatter.size() >= 3:
			var idx := mini(scatter.size(), 5) - 3
			total += float(SCATTER_PAY[idx]) * float(bet)
			res["trigger"] = int(FREE_SPINS[idx])
	var win := roundi(total * float(mult))
	if free:
		var room := roundi(FREE_CAP * float(bet)) - free_total
		win = clampi(win, 0, maxi(room, 0))
		free_total += win
	res["grid"] = grid
	res["lines"] = win_lines
	res["scatter"] = scatter
	res["mult"] = mult
	res["win"] = win
	res["jackpot"] = jackpot
	res["big"] = float(win) / float(maxi(bet, 1))
	if not free and int(res["trigger"]) > 0:
		mode = Mode.FREE
		free_left = int(res["trigger"])
		free_start = free_left
		free_total = 0
		free_done = 0
	if free and free_left <= 0:
		res["ended"] = true
		res["fg_total"] = free_total
		mode = Mode.BASE
	res["free_left"] = free_left
	res["free_total"] = free_total
	return res


func _roll_powerup() -> int:
	var total := 0
	for p in POWERUPS:
		total += int((p as Array)[1])
	var r := rng.randi_range(0, total - 1)
	for p in POWERUPS:
		r -= int((p as Array)[1])
		if r < 0:
			return int((p as Array)[0])
	return 2


func _spin_loki() -> Dictionary:
	var grid := _roll_loki()
	var win_lines := _loki_lines(grid)
	var curse := false
	var units := 0
	var best := -1
	var jackpot := false
	for wl in win_lines:
		if int(wl["sym"]) == Sym.MASKE:
			curse = true
		else:
			units += int(wl["pay"])
			best = maxi(best, int(wl["sym"]))
			if int(wl["sym"]) == Sym.AUGE:
				jackpot = true
	if curse:
		units = 0
	var win := bet * units
	return {
		"grid": grid, "lines": win_lines, "win": win, "mult": units, "curse": curse, "jackpot": jackpot, "best": best,
		"big": float(units), "trigger": 0, "retrigger": 0, "stacks": [], "powerup": 0, "bolt": [], "scatter": [],
		"free": false, "ended": false, "free_left": 0, "free_total": 0,
	}


## Risikoleiter (Adlersson): Münzwurf, verdoppelt oder verliert alles.
func risk_flip() -> bool:
	return rng.randf() < 0.5


## Tabelle für den Hinweistext: Zeilen [Name, Text].
static func pay_text(machine_id: String) -> Array:
	var out: Array = []
	if machine_id == "norn":
		for s in [Sym.AUGE, Sym.DRAUGR, Sym.HAMMER, Sym.SCHIFF, Sym.RABE, Sym.HORN, Sym.AXT, Sym.SCHILD]:
			var p: Array = NORN_PAYS[s]
			out.append([sym_name(s), "%s / %s / %s" % [_x(p[0]), _x(p[1]), _x(p[2])]])
	else:
		for s in [Sym.AUGE, Sym.HAMMER, Sym.SCHIFF, Sym.WOLF, Sym.RABE]:
			out.append([sym_name(s), "%s" % _x(LOKI_PAYS[s])])
	return out


static func _x(v: int) -> String:
	return "%dx" % v
