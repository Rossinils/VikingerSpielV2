extends SceneTree
## Prüft die Tastensteuerung im Stil von Darkest Dungeon: ← → wählen den Kurs (Knoten links und rechts auf der Seekarte),
## ↑ fährt eine Wache, in Begegnungen wählen ← → eine Karte und Enter nimmt sie.
## Aufruf: godot --headless --path . --script tools/keytest.gd -- --nosave --nohelp --seed=3

var fails := 0
var main: Node
var frames := 0


func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		fails += 1
		print("FEHLER: ", what)


func key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	main._unhandled_input(ev)


func _init() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	_run()
	print("FEHLER: ", fails)
	return true


func _run() -> void:
	var v: Voyage = main._voy
	var hud: Hud = main._hud
	hud.hide_help()
	check(v.phase == Voyage.Phase.PLAN and v.mile == 0, "Start in der Planung")
	var links: Array = v.next_links().duplicate()
	links.sort()
	v.route = -1
	key(KEY_LEFT)
	check(v.route == int(links[0]), "← legt den Kurs auf den linken Knoten")
	key(KEY_RIGHT)
	check(v.route == int(links[mini(1, links.size() - 1)]), "→ schiebt ihn einen Knoten nach rechts")
	for i in 4:
		key(KEY_RIGHT)
	check(v.route == int(links.back()), "am rechten Rand bleibt er stehen")
	v.route = -1
	key(KEY_RIGHT)
	check(v.route == int(links.back()), "ohne Wahl nimmt → den rechten Weg")
	key(KEY_UP)
	check(v.phase == Voyage.Phase.RESOLVE, "↑ fährt eine Wache auf dem gewählten Kurs")
	var n := 0
	while v.phase != Voyage.Phase.PLAN and n < 200:
		if v.phase == Voyage.Phase.ENCOUNTER:
			v.decide_encounter((Encounters.DATA[v.encounter]["options"] as Array).size() - 1)
		elif v.phase == Voyage.Phase.RESCUE:
			v.decide_rescue(false)
		v._process(0.5)
		n += 1
	check(v.phase == Voyage.Phase.PLAN, "danach wieder Planung")
	# zwischen zwei Knoten ist der Kurs gesetzt: ← → ändern nichts
	if v.leg > 0.0:
		var r0 := v.route
		key(KEY_LEFT)
		check(v.route == r0, "zwischen zwei Knoten bleibt der Kurs")
	# Begegnung unterwegs: ← → wählen eine Karte, Enter nimmt sie
	v._enc_pending = Encounters.Id.TREIBEIS
	v._advance()
	hud.kb_sync("test")
	check(v.phase == Voyage.Phase.ENCOUNTER and hud.kb_card == -1, "Begegnung: noch keine Karte gewählt")
	key(KEY_RIGHT)
	check(hud.kb_card == 0, "→ wählt die erste Karte")
	key(KEY_RIGHT)
	key(KEY_RIGHT)
	key(KEY_RIGHT)
	check(hud.kb_card == 2, "→ bis zur letzten Karte, dort bleibt es")
	key(KEY_LEFT)
	check(hud.kb_card == 1, "← eine zurück")
	var proviant_before := v.proviant
	key(KEY_ENTER)
	check(v.phase == Voyage.Phase.RESOLVE and v.proviant == proviant_before - 1, "Enter nimmt die gewählte Karte (Umfahren kostet Proviant 1)")
	# Segen: ← → und Enter
	n = 0
	while v.phase != Voyage.Phase.PLAN and n < 200:
		v._process(0.5)
		n += 1
	v._perk_pending = 1
	v.perk_offer = Perks.offer(v.perks)
	hud.kb_sync("perk")
	var perks_before := v.perks.size()
	key(KEY_RIGHT)
	key(KEY_ENTER)
	check(v.perks.size() == perks_before + 1 and v.perk_offer.is_empty(), "Segen: → und Enter wählen den ersten")
