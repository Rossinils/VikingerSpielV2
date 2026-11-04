extends Node2D

## Startet die Überfahrt und verdrahtet Welt, Crew und Anzeige.
## Testoptionen (nach "--" auf der Kommandozeile):
##   --autoplay | --random    ein Bot spielt (klug bzw. zufällig)
##   --log --timescale=8 --seed=3
##   --nohelp --select=1      Hilfe ausblenden / Vorlage (Strategy.PRESETS) einstellen
##   --shot=pfad.png@5 [--shotswim]   Screenshot in Fensterauflösung nach 5 Sekunden (bzw. wenn jemand im Wasser ist)
##   --forceenc=5 [--shotbattle]       jede Begegnung ist ein Draugr-Schiff; Screenshot in Runde 2 der Seeschlacht

var _voy: Voyage
var _music: MusicDirector
var _no_music := false
var _no_save := false
var _memtest := false  # Testdateien statt der echten Speicherstände (user://shot_*.json)
var _shot_mem := false
var _persist := false  # Fahrt speichern und Gedenkstein führen: nur im echten Spiel, nie in Tests
var _new_armed := 0.0
var _world: Node2D
var _ship: ShipSprite
var _hud: Hud
var _views: Array[CrewView] = []
var _markers: Array[SlotMarker] = []

static var skip_menu := false  # nach "Noch eine Fahrt" gleich losfahren, ohne Hauptmenü
var _show_menu_flag := false  # --menu: Hauptmenü auch in Tests und Screenshots zeigen
var _hud_settings := false  # --settingsopen: Einstellungen im Menü aufgeschlagen
var _shot_shop := false  # --shopopen (mit --shotharbor): die Werft aufgeschlagen
var _shot_shop_mode := ""  # --shoprare: Werft mit seltenen Angeboten, --shotforge: Werft im Reiter Schmiede
var _give_perk := false  # --giveperk: gleich zu Beginn ein Stufenaufstieg (für Screenshots)
var _give_loot := false  # --giveloot: viel Beute und ein paar Gegenstände (für Screenshots)
var _give_pfand := false  # --givepfand: drei Pfandflaschen zu Beginn (für Tests und Screenshots)

var _bot := ""
var _bot_cd := 1.0
var _end_wait := 0.0
var _shot_path := ""
var _shot_time := 0.0
var _shot_swim := false
var _shot_enc := false
var _shot_harbor := false
var _shot_battle := false  # Screenshot erst in Runde 2 einer Seeschlacht (mit --forceenc=5 --autoplay)
var _shot_crew := false  # Mannschaftsansicht offen, ein Mann gewählt
var _shot_fight := 0  # Deckkampf: 1 Aufstellung, 2 Kampf, 3 Kampf mit gewählter Fertigkeit (--shotfight, --shotfight2, --shotfight3)
var _shot_form := ""  # --shotform=draugr|raeuber|haendler|dorf|kraken: Ort des Deckkampfs bei --shotfight2/3
var _shot_kraken := 0  # Deckkampf gegen den Kraken: 1 mit Griff und Tinte, 2 Körper offen und spannt sich (--shotkraken, --shotkraken2)
var _shot_fx := 0  # Deckkampf mitten im Schuss (1, --shotfx), Hieb (2, --shotfx2) oder Musketenschuss (3, --shotfx3)
var _shot_kill := false  # --shotkill: wie --shotfx2, aber der Gegner hat nur noch 1 Kraft und fällt (Todesstoß, Kamera, Zeitlupe)
var _shot_crit := false  # --shotcrit: der Hieb trifft kritisch
var _shot_loadout := false  # Aufstellung mit der Fertigkeitenwahl des Musketiers (--shotloadout)
var _shot_snap := ""  # Deckkampf mit Heldenmut (--shotheroic) oder Zusammenbruch (--shotsnap)
var _shot_tavern := false  # Hafen mit Taverne und Reserve (--shottavern)
var _shot_camp := false  # Lager an einer Ankerbucht (--shotcamp)
var _shot_slot := ""  # Spielautomat: --shotslot=spin|win|alive|free|jackpot (Nornenwalzen im Hafen), loki|loki_win|loki_curse (Adlerssons Schiff)
var _bot_slot_visit := -1  # Hafenbesuch, in dem der Bot schon an der Spelunke war
var _max_stage := 0  # --maxstage=N: nach dieser Etappe geht die Fahrt zu Ende (Bots: Standard 6)
var _bot_shop_visit := -1  # Hafenbesuch (encounters_done), in dem der Bot die Werft schon besucht hat
var _hover_dial_arg: Array = []  # --hoverdial=Regler,Stellung: Vorschau-Screenshot mit "Maus" auf einem Knopf
var _hover_mouse_arg := Vector2(-1, -1)  # --hovermouse=x,y: Tooltip-Screenshot mit "Maus" an dieser Stelle (Spielfeldpixel)
var _start_help := true
var _start_select := -1


func _ready() -> void:
	Waves.time = 0.0
	var log_enabled := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			_bot = "smart"
		elif arg == "--random":
			_bot = "random"
		elif arg == "--log":
			log_enabled = true
		elif arg.begins_with("--timescale="):
			Engine.time_scale = float(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			seed(int(arg.get_slice("=", 1)))
		elif arg == "--textcheck":
			Hud.text_check = true  # Entwicklung: meldet Text, der breiter als sein Feld ist oder über den Bildrand ragt
		elif arg == "--nohelp":
			_start_help = false
		elif arg == "--nomusic" or arg == "--nosound":
			_no_music = true
		elif arg == "--nosave":
			_no_save = true
		elif arg == "--memtest":
			_memtest = true
		elif arg == "--shotmem":
			_shot_mem = true
		elif arg.begins_with("--select="):
			_start_select = int(arg.get_slice("=", 1))
		elif arg == "--shotswim":
			_shot_swim = true
		elif arg == "--shotenc":
			_shot_enc = true
		elif arg == "--shoprare" or arg == "--shotforge" or arg == "--shotgear" or arg == "--shotarmory":
			_shot_shop = true
			_shot_harbor = true
			_shot_shop_mode = String(arg.substr(2)).replace("shop", "").replace("shot", "")
		elif arg == "--shotharbor":
			_shot_harbor = true
		elif arg == "--shotbattle":
			_shot_battle = true
		elif arg.begins_with("--maxstage="):
			_max_stage = int(arg.get_slice("=", 1))
		elif arg == "--menu":
			_show_menu_flag = true
		elif arg == "--settingsopen":
			_show_menu_flag = true
			_hud_settings = true
		elif arg == "--shopopen":
			_shot_shop = true
		elif arg == "--giveperk":
			_give_perk = true
		elif arg == "--giveloot":
			_give_loot = true
		elif arg == "--givepfand":
			_give_pfand = true
		elif arg.begins_with("--hoverdial="):
			_hover_dial_arg = [int(arg.get_slice("=", 1).get_slice(",", 0)), int(arg.get_slice("=", 1).get_slice(",", 1))]
		elif arg.begins_with("--hovermouse="):
			_hover_mouse_arg = Vector2(float(arg.get_slice("=", 1).get_slice(",", 0)), float(arg.get_slice("=", 1).get_slice(",", 1)))
		elif arg == "--shotcrew":
			_shot_crew = true
		elif arg == "--shotfight" or arg == "--shotfight2" or arg == "--shotfight3":
			_shot_fight = int(arg.substr(arg.length() - 1)) if arg != "--shotfight" else 1
		elif arg == "--shotkraken" or arg == "--shotkraken2":
			_shot_kraken = int(arg.substr(arg.length() - 1)) if arg != "--shotkraken" else 1
		elif arg.begins_with("--stagefx="):
			Settings.stage_fx = int(arg.get_slice("=", 1))  # 0 = Kampfbild schlicht (für Prüfungen)
		elif arg.begins_with("--shotform="):
			_shot_form = arg.get_slice("=", 1)
		elif arg == "--shotloadout":
			_shot_loadout = true
		elif arg == "--shotfx" or arg == "--shotfx2" or arg == "--shotfx3":
			_shot_fx = int(arg.substr(arg.length() - 1)) if arg != "--shotfx" else 1
		elif arg == "--shotkill" or arg == "--shotcrit":
			_shot_fx = 2
			_shot_kill = arg == "--shotkill"
			_shot_crit = arg == "--shotcrit"
		elif arg == "--shotheroic" or arg == "--shotsnap":
			_shot_snap = "heroic" if arg == "--shotheroic" else "break"
		elif arg == "--shottavern":
			_shot_tavern = true
		elif arg == "--shotcamp":
			_shot_camp = true
		elif arg.begins_with("--shotslot="):
			_shot_slot = arg.get_slice("=", 1)
		elif arg.begins_with("--forceenc="):
			Encounters.forced = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shot="):
			var spec := arg.substr(7)
			_shot_path = spec.get_slice("@", 0)
			_shot_time = float(spec.get_slice("@", 1))

	# Gespeichert wird nur im echten Spiel: nie im Headless-Modus, mit Bots oder bei Screenshots
	_persist = DisplayServer.get_name() != "headless" and _bot == "" and _shot_path == "" and not _no_save
	if _persist:
		Settings.enabled = true
		MusicDirector.persist = true
		Settings.load_all()
		if Settings.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		if not Settings.help_at_start:
			_start_help = false
	_voy = Voyage.new()
	_voy.log_enabled = log_enabled
	_voy.autosave = _persist
	_voy.auto_combat = _bot != "" or (_persist and Settings.auto_combat)
	_voy.max_stage = _max_stage if _max_stage > 0 else (6 if _bot != "" else 0)
	_voy.automat_bonus_on = _bot != "" or _shot_path == ""  # Freidrehs nach Siegen: im echten Spiel und bei Bots, nicht in Screenshots
	if _memtest:
		Persist.run_path = "user://shot_run.json"
		Persist.memorial_path = "user://shot_gedenkstein.json"
		_voy.autosave = true
	add_child(_voy)

	_world = Node2D.new()
	add_child(_world)
	_world.add_child(SkyLayer.new())

	var far := OceanLayer.new()  # ferne, dunstige Wasserschicht am Horizont
	far.layer = 2
	far.base_y = Waves.WATER_Y - 20.0
	_world.add_child(far)

	var enemy_back := EnemyLayer.new()  # Kulissen der Begegnungen hinter der hinteren Welle
	enemy_back.voy = _voy
	_world.add_child(enemy_back)

	var back := OceanLayer.new()
	back.layer = 0
	back.base_y = Waves.WATER_Y - 12.0
	back.color = Color("0f232e")
	_world.add_child(back)

	_ship = ShipSprite.new()
	_ship.position = Vector2(Waves.SHIP_X, Waves.WATER_Y)
	_ship.voy = _voy
	_world.add_child(_ship)
	_voy.ship = _ship

	var ui := CanvasLayer.new()
	_hud = Hud.new()
	ui.add_child(_hud)
	add_child(ui)
	_hud.setup(_voy)

	if _bot == "" and DisplayServer.get_name() != "headless":
		_voy.combat_outro = 1.9  # Schlussansage nach dem Deckkampf (Bots und Tests lösen sofort auf)
	# Tests (Bots, Screenshots) spielen nie Ton: sie sollen niemanden stören
	if _bot == "" and _shot_path == "" and not _no_music:
		_music = MusicDirector.new()
		_music.voy = _voy
		add_child(_music)
		_hud.music = _music
		add_child(Sfx.new())

	var saved := Persist.load_run() if (_persist or _memtest) else {}
	var can_resume := Persist.resumable(saved)
	if can_resume:
		_voy.resume(saved)
		_hud.hide_help()
	else:
		_voy.begin()
	if not _start_help:
		_hud.hide_help()
	if _start_select >= 0:
		_voy.select_strategy(_start_select)
		if _voy.route < 0:
			_voy.select_route(int(_voy.next_links()[0]))  # nur für Screenshots: Vorschau mit Kurs
	_hud.debug_hover = _hover_dial_arg
	_hud.debug_mouse = _hover_mouse_arg
	if _give_loot:
		_voy.loot = 600.0
		for id in ["beschlag", "tuch", "kanone", "kanone", "fass"]:
			_voy.equip(String(id))
		_voy.powder = 5
	if _give_pfand:
		_voy.pfand = Items.PFAND_MAX
	if _give_perk:
		_voy.gain_xp(500)
	var show_menu := (_persist or _show_menu_flag) and not skip_menu
	skip_menu = false  # gilt nur für diesen einen Neustart
	if show_menu:
		_hud.menu_open = true
		_hud.menu_can_continue = can_resume
		_hud.settings_open = _hud_settings
		if _music != null:
			_music.menu = true
	if _shot_crew:
		_hud.hide_help()
		_hud.toggle_crew()
		_voy.click_seat(3)
	if _shot_fight > 0:  # Screenshot: Aufstellung (1) oder laufender Kampf (2) beim Überfall auf ein Handelsschiff
		_hud.hide_help()
		_voy.auto_combat = false
		_voy.stage = 3
		if _shot_form != "" and _shot_fight >= 2:
			_voy.start_fight(_shot_form, {"source": "encounter"}, 3)
		else:
			_voy._enc_pending = Encounters.Id.HAENDLER
			_voy._advance()
			_voy.decide_encounter(0)
		if _shot_fight >= 2:
			_voy.fight_begin()
			var guard_n := 0
			while _voy.combat != null and _voy.combat.state != "hero" and guard_n < 20:
				_voy.combat.act_foe()
				guard_n += 1
			if _voy.combat != null and _voy.combat.state == "hero":
				_voy.combat.auto_hero()
				while _voy.combat.state == "foe" and guard_n < 40:
					_voy.combat.act_foe()
					guard_n += 1
			if _shot_fight >= 3 and _voy.combat != null and _voy.combat.state == "hero":
				_hud._fight_actor = _voy.combat.actor  # sonst setzt die Anzeige die gewählte Fertigkeit im ersten Bild zurück
				_hud._fight_skill = String(_voy.combat.actor.skills[0])
	if _shot_kraken > 0:  # Screenshot: der Kraken im Deckkampf
		_hud.hide_help()
		_voy.auto_combat = false
		_voy.stage = 3
		_voy.start_fight("kraken", {"source": "encounter"}, 3)
		_voy.fight_begin()
		var kc := _voy.combat
		var kguard := 0
		while kc.state == "foe" and kguard < 20:
			kc.act_foe()
			kguard += 1
		if _shot_kraken == 1:
			kc.heroes[1].held_by = kc.foes[0]
			kc.foes[0].holding = kc.heroes[1]
			kc.foes[0].hold_left = 2
			kc.heroes[2].blind = 2
			kc.heroes[1].hp = 55.0
		else:
			for kt in kc.foes.duplicate():
				if kt.kind == "tentakel":
					kc._hurt(kt, 9999, null)
			kc.foes[kc.foes.size() - 1].charge = true
			kc.foes[kc.foes.size() - 1].hp *= 0.6
			kc.heroes[0].hp = 40.0
		_voy._combat_t = 9999.0
	if _shot_loadout:  # Screenshot: Aufstellung, dann die Wahl der Fertigkeiten des Musketiers
		_hud.hide_help()
		_voy.auto_combat = false
		_voy.stage = 3
		var lr: Array = [Roles.Id.SCHILD, Roles.Id.AXT, Roles.Id.MUSKET, Roles.Id.SKALDE]
		for li in 4:
			_voy.crew[li].role = lr[li]
		_voy._enc_pending = Encounters.Id.HAENDLER
		_voy._advance()
		_voy.decide_encounter(0)
		for pm in _voy.fight_prep["party"]:
			if pm.role == Roles.Id.MUSKET:
				_hud._loadout_man = pm
	if _shot_fx > 0:  # Screenshot: ein Mann schießt oder schlägt, das Bild kommt mitten in der Wirkung
		_hud.hide_help()
		if _shot_fx == 3:
			var fr: Array = [Roles.Id.SCHILD, Roles.Id.AXT, Roles.Id.MUSKET, Roles.Id.SKALDE]
			for fi in 4:
				_voy.crew[fi].role = fr[fi]
		_voy.auto_combat = false
		_voy.stage = 3
		_voy._enc_pending = Encounters.Id.HAENDLER
		_voy._advance()
		_voy.decide_encounter(0)
		_voy.fight_begin()
		var xc := _voy.combat
		var want := Roles.Id.BOGEN if _shot_fx == 1 else (Roles.Id.AXT if _shot_fx == 2 else Roles.Id.MUSKET)
		var xg := 0
		while xc.state != "done" and xg < 60:
			if xc.state == "foe":
				xc.act_foe()
			elif xc.actor.role != want:
				xc.hero_pass()
			else:
				break
			xg += 1
		xc.events.clear()
		if _shot_kill:
			xc.foes[0].hp = 1.0
		if _shot_crit:
			xc.heroes[0].crit_bonus = 100.0
		_voy.combat_act("b_schuss" if _shot_fx == 1 else ("a_hieb" if _shot_fx == 2 else "m_schuss"), xc.foes[0])
		_voy._combat_t = 9999.0
	if _shot_snap != "":  # Screenshot: ein Mann kippt mitten im Kampf
		_hud.hide_help()
		_voy.auto_combat = false
		_voy.stage = 3
		_voy._enc_pending = Encounters.Id.HAENDLER
		_voy._advance()
		_voy.decide_encounter(0)
		_voy.fight_begin()
		var sc := _voy.combat
		var sguard := 0
		while sc.state == "foe" and sguard < 20:
			sc.act_foe()
			sguard += 1
		sc.snap_force = _shot_snap
		sc.heroes[1].man.stress = 98.0
		sc._stress(sc.heroes[1], 6.0)
		_voy._combat_t = 9999.0
	if _shot_tavern:  # Screenshot: Hafen mit Taverne, zwei Männer in der Reserve
		_hud.hide_help()
		_voy.loot = 400.0
		_voy._enc_pending = Encounters.Id.HAFEN
		_voy._advance()
		_voy.hire_candidate(0)
		_voy.hire_candidate(0)
		_voy.crew[2].kraft = 35.0
		_voy.reserve[0].kraft = 60.0
		_hud.toggle_crew()
	if _shot_slot != "":  # Screenshot: Spielautomat in einer Szene (siehe SlotView.demo)
		_hud.hide_help()
		_voy.stage = 3
		_voy.loot = 600.0
		var on_loki := _shot_slot.begins_with("loki") or _shot_slot == "playloki" or _shot_slot == "bottle"
		if _shot_slot == "harbor" or _shot_slot == "lokicard" or _shot_slot == "ship":
			on_loki = _shot_slot == "lokicard"
			_hud.slot_demo = ""
		if _shot_slot == "bottle" or _shot_slot == "lokicard" or _shot_slot == "ship":
			_voy.pfand = 2  # für die Bilder: zwei Pfandflaschen
		_voy._enc_pending = Encounters.Id.SPIELER if on_loki else Encounters.Id.HAFEN
		_voy._advance()
		if _shot_slot != "harbor" and _shot_slot != "lokicard" and _shot_slot != "ship":  # nur die Begegnung mit ihren Karten, bzw. die Schiffsansicht
			_voy.automat_enter("loki" if on_loki else "harbor")
		if _shot_slot == "bottle":
			_voy.loki_pick("bottle")
		if _shot_slot == "ship":
			_hud.toggle_ship()
		_hud.slot_demo = "" if (_shot_slot == "loki" or _shot_slot == "idle" or _shot_slot == "play" or _shot_slot == "playloki") else _shot_slot
	if _shot_camp:  # Screenshot: Lager an einer Ankerbucht, ein paar Aktionen getan
		_hud.hide_help()
		_voy.mile = 3
		_voy.pos = 0
		_voy.here()["cove"] = true
		_voy.loot = 200.0
		_voy.crew[1].traits = [Traits.Id.STERNGUCKER]
		_voy.crew[2].traits = [Traits.Id.SCHWIMMER]
		_voy.hull = 70.0
		_voy.loot = 300.0
		_voy._enc_pending = Encounters.Id.HAFEN
		_voy._advance()
		_voy.hire_candidate(0)
		_voy.decide_encounter(6)
		_voy._process(2.0)
		for k in 3:
			_voy._process(2.0)
		for m in _voy.crew:
			m.kraft = 45.0 + randf() * 20.0
		_voy.mile = 3
		_voy.pos = 0
		_voy.here()["cove"] = true
		_voy.phase = Voyage.Phase.PLAN
		_voy.encounter = -1
		_voy.camp_start()
		_voy.camp_do("sleep")
		_voy.camp_do("watch")

	for i in Stations.SLOTS.size():
		var mk := SlotMarker.new()
		mk.setup(i, _voy, _ship)
		_world.add_child(mk)
		_markers.append(mk)
	for m in _voy.crew:
		var v := CrewView.new()
		v.setup(m, _voy, _ship)
		_world.add_child(v)
		_views.append(v)

	var enemy_front := EnemyLayer.new()  # Tentakel des Kraken vor dem Schiff
	enemy_front.voy = _voy
	enemy_front.front = true
	_world.add_child(enemy_front)

	var front := OceanLayer.new()
	front.layer = 1
	front.base_y = Waves.WATER_Y + 1.0
	front.color = Color("16313f")
	_world.add_child(front)

	var wake := WakeLayer.new()  # Schaumsaum, Bugwelle und Kielwasser
	wake.voy = _voy
	_world.add_child(wake)

	_world.add_child(RainLayer.new())


func _process(delta: float) -> void:
	Waves.time += delta
	Waves.storm = _voy.storm
	_new_armed = maxf(_new_armed - delta, 0.0)
	_hud.menu_new_armed = _new_armed > 0.0
	_hud.hover_crew = null
	if _voy.crew_requested:  # "Anheuern" im Hafen: die Taverne ist Teil der Mannschaftsansicht
		_voy.crew_requested = false
		if not _hud.crew_open:
			_hud.toggle_crew()
	var wp_mouse := get_viewport().get_mouse_position() - _world.position
	for v in _views:
		if v.hit(wp_mouse):
			_hud.hover_crew = v.member
			break
	if _bot != "":
		_bot_step(delta)
	if (_shot_slot == "play" or _shot_slot == "playloki") and _hud.slot_view != null and not _hud.slot_view.busy():
		_shot_slot_play()

	var shake := maxf(_voy.storm - 0.6, 0.0) * 2.0 + _voy.impact * 4.0
	_world.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)).round()

	if _shot_mem and _voy.ended and not _hud.memorial_open:
		_hud.toggle_memorial()
	if _shot_path != "":
		var in_harbor := _voy.phase == Voyage.Phase.ENCOUNTER and Encounters.is_harbor(_voy.encounter)
		if _shot_shop and in_harbor and not _voy.shop_open:
			_voy.shop_open = true
			_voy.loot = 600.0
			if _shot_shop_mode == "rare":
				_voy.shop = ["teer@1", "planken@2", "kanone@3"]
				_voy.items[0] = "sporn@2"
				_voy.items[1] = "beschlag@1"
				_voy.items[3] = "esche@3"
				_voy.items[6] = "fass"
				_voy._mods = {}
			elif _shot_shop_mode == "gear":
				_voy.werft_tab = 2
				_voy.stash = ["axt@2", "schwert@1", "rune@3", "leder", "zahn@1"]
				var gm0 := _voy.forge_men()[0]
				gm0.gear[0] = "speer@1"
				gm0.gear[2] = "horn@2"
			elif _shot_shop_mode == "armory":
				_voy.werft_tab = 3
				_voy.gear_shop = ["hammer@2", "mantel@1", "auge@3"]
				_voy.stash = ["axt@2", "schwert", "rune@1"]
			elif _shot_shop_mode == "forge":
				_voy.forge_tab = true
				var fm := _voy.forge_men()[0]
				_voy.forge_buy("weapon", fm)
				_voy.forge_buy("weapon", fm)
				_voy.forge_buy("armor", fm)
				_voy.forge_buy("skill", fm, String(Roles.pool(fm.role)[0]))
		var in_battle := _voy.phase == Voyage.Phase.ENCOUNTER and not _voy.battle.is_empty() and int(_voy.battle["round"]) >= 2
		var phase_ok := (not _shot_swim or _voy.phase == Voyage.Phase.RESCUE) and (not _shot_enc or _voy.phase == Voyage.Phase.ENCOUNTER) and (not _shot_harbor or in_harbor) and (not _shot_battle or in_battle) and (not _shot_mem or _hud.memorial_open)
		if Waves.time >= _shot_time and phase_ok:
			var path := _shot_path
			_shot_path = ""
			_take_shot(path)


## Nur für Screenshots und Fehlersuche (--shotslot=play|playloki): dreht den Automaten durch die echte Anzeige, immer weiter.
func _shot_slot_play() -> void:
	_voy.loot = maxf(_voy.loot, 400.0)
	if _voy.automat_kind == "loki":
		if _voy.loki_pot > 0:
			if randf() < 0.6 and _voy.loki_ladder < 2:
				_hud.slot_view.click("xr")
			else:
				_hud.slot_view.click("xc")
			return
		_voy.loki_round = 0
		_voy.hull = maxf(_voy.hull, 60.0)
		if _voy.loki_can_spin():
			_voy.loki_pick(["loot", "hull", "man"][randi() % 3])
			_hud.slot_view.spin()
		return
	_voy._harbor_spins = 0
	if _voy.automat.spins == 0:
		_voy.automat.force_trigger = true
	if _voy.automat_can_spin():
		_hud.slot_view.spin()


func _take_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Screenshot %dx%d: %s" % [img.get_width(), img.get_height(), path])
	print("STAGE Messung: Zeichenaufrufe=%d Primitive=%d Objekte=%d" % [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if _global_key(key):
			return
		if _hud.memorial_open:
			match key:
				KEY_G, KEY_ESCAPE:
					_hud.toggle_memorial()
				KEY_LEFT:
					_hud.memorial_step(-1)
				KEY_RIGHT:
					_hud.memorial_step(1)
			return
		if _hud.menu_open and _hud.settings_open:
			if key == KEY_ESCAPE or key == KEY_ENTER:
				_hud.settings_open = false
			return
		if _hud.menu_open:
			match key:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_close_menu()
				KEY_ESCAPE:
					if _hud.menu_can_continue:
						_close_menu()
				KEY_G:
					_hud.toggle_memorial()
				KEY_N:
					if _hud.menu_can_continue:
						_new_run()
			return
		if _voy.automat_open:
			_hud.slot_key(key)
			return
		if not _voy.perk_offer.is_empty() and _voy.phase == Voyage.Phase.PLAN:
			if key >= KEY_1 and key <= KEY_3:
				_voy.choose_perk(key - KEY_1)
			return
		if _hud.ship_active():
			match key:
				KEY_B, KEY_ESCAPE:
					_hud.toggle_ship()
				KEY_1, KEY_2, KEY_3:
					_voy.buy_offer(key - KEY_1)
				KEY_R:
					_voy.buy_repair()
				KEY_P:
					_voy.buy_powder()
			return
		if _hud.crew_open:
			if key == KEY_C or key == KEY_ESCAPE:
				_hud.toggle_crew()
			elif key == KEY_A:
				_voy.toggle_relief()
			return
		if _voy.phase == Voyage.Phase.COMBAT:
			_hud.fight_key(key)
			return
		if _voy.camping:  # im Lager: 1–9 Aktionen, Enter bricht auf, C die Mannschaft
			if key >= KEY_1 and key <= KEY_9 and key - KEY_1 < Camp.ORDER.size():
				_voy.camp_do(String(Camp.ORDER[key - KEY_1]))
			elif key == KEY_ENTER or key == KEY_KP_ENTER:
				_voy.camp_end()
			elif key == KEY_C:
				_hud.toggle_crew()
			elif key == KEY_A:
				_voy.toggle_relief()
			return
		if _voy.phase == Voyage.Phase.ENCOUNTER:
			if key >= KEY_1 and key <= KEY_7:
				_voy.decide_encounter(key - KEY_1)
		elif key >= KEY_1 and key <= KEY_9:
			_voy.set_dial(floori((key - KEY_1) / 3.0), (key - KEY_1) % 3)  # 1–3 Segel, 4–6 Ruder, 7–9 Küste
		match key:
			KEY_Q:
				_voy.select_route(0)
			KEY_W:
				_voy.select_route(1)
			KEY_E:
				_voy.select_route(2)
			KEY_ENTER, KEY_KP_ENTER:
				if _voy.ended:
					skip_menu = true  # gleich die nächste Fahrt, ohne Hauptmenü
					get_tree().reload_current_scene()
				else:
					_confirm()
			KEY_R:
				if _voy.default_rescuer() != null:
					_voy.decide_rescue(true)
			KEY_Z:
				_voy.decide_rescue(false)
			KEY_ESCAPE:
				if _voy.selected != null:
					_voy.selected = null
				elif _voy.ended:
					skip_menu = false  # zurück ins Hauptmenü
					get_tree().reload_current_scene()
				elif _voy.phase == Voyage.Phase.PLAN or _voy.phase == Voyage.Phase.ENCOUNTER:
					_open_menu()
			KEY_H:
				_hud.toggle_help()
			KEY_G:
				_hud.toggle_memorial()
			KEY_A:
				if _voy.phase == Voyage.Phase.PLAN or _voy.phase == Voyage.Phase.ENCOUNTER:
					_voy.toggle_relief()
			KEY_L:
				_voy.camp_start()
			KEY_C:
				_hud.toggle_crew()
			KEY_B:
				_hud.toggle_ship()
			KEY_N:
				if event.ctrl_pressed:
					_new_run()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)


## Klick in den Einstellungen.
func _setting_click(id: String) -> void:
	match id:
		"tm0":
			if _music != null:
				_music.change_volume(-3.0)
		"tm1":
			if _music != null:
				_music.change_volume(3.0)
		"tmute":
			if _music != null:
				_music.toggle_mute()
		"te0":
			Settings.change_sfx(-3.0)
		"te1":
			Settings.change_sfx(3.0)
		"tfull":
			Settings.fullscreen = not Settings.fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
			Settings.save_all()
		"thelp":
			Settings.help_at_start = not Settings.help_at_start
			Settings.save_all()
		"tfight":
			Settings.auto_combat = not Settings.auto_combat
			_voy.auto_combat = Settings.auto_combat
			Settings.save_all()
		"tstage":
			Settings.stage_fx = 0 if Settings.stage_fx != 0 else 1  # Kampfbild: voll (Nebel, Glanz, Regen, Blitz) oder schlicht
			Settings.save_all()
		"tview":
			Settings.fight_view = 1 if Settings.fight_view == 0 else 0  # Kampfansicht: voll (Zoom, Zeitlupe, Standbild) oder kurz (halbe Zeiten)
			Settings.save_all()
		"tshake":
			Settings.shake = (Settings.shake + 2) % 3  # Wackeln: normal -> schwach -> aus
			Settings.save_all()
		"tback":
			_hud.settings_open = false


## Tasten, die überall gelten: Ton und Vollbild.
func _global_key(key: int) -> bool:
	match key:
		KEY_M:
			if _music != null:
				_music.toggle_mute()
			return true
		KEY_MINUS, KEY_KP_SUBTRACT:
			if _music != null:
				_music.change_volume(-3.0)
			return true
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
			if _music != null:
				_music.change_volume(3.0)
			return true
		KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return true
	return false


func _close_menu() -> void:
	_hud.menu_open = false
	if _music != null:
		_music.menu = false


func _open_menu() -> void:
	_hud.menu_open = true
	_hud.menu_can_continue = true
	if _music != null:
		_music.menu = true


## Zweimal bestätigen (Strg+N oder im Menü): die laufende Fahrt verwerfen und neu beginnen.
func _new_run() -> void:
	if _voy.ended:
		return
	if _new_armed > 0.0:
		if _persist:
			Persist.clear_run()
		skip_menu = true
		get_tree().reload_current_scene()
	else:
		_new_armed = 4.0
		if not _hud.menu_open:
			_voy.say("Noch einmal drücken: die laufende Fahrt geht dabei verloren.", Voyage.Kind.BAD)


func _confirm() -> void:
	if _voy.phase == Voyage.Phase.PLAN and _voy.can_confirm():
		_hud.hide_help()
	_voy.confirm()


func _click(p: Vector2) -> void:
	if _hud.memorial_open:  # ein Klick schliesst den Gedenkstein (Blättern mit den Pfeiltasten)
		Sfx.play("click")
		_hud.toggle_memorial()
		return
	if _voy.ended:
		return
	if _voy.automat_open:  # der Automat hat seine eigenen Klänge
		_hud.slot_click(_hud.button_at(p))
		return
	Sfx.play("click")
	var b := _hud.button_at(p)
	if _hud.help_open() and not _hud.menu_open:  # der erste Klick schliesst nur die Hilfe
		_hud.hide_help()
		return
	if _voy.phase == Voyage.Phase.COMBAT:
		_hud.fight_click(b)
		return
	if _hud.menu_open and _hud.settings_open:
		_setting_click(b)
		return
	if _hud.menu_open:
		match b:
			"mc":
				_close_menu()
			"mn":
				_new_run()
			"mg":
				_hud.toggle_memorial()
			"mo":
				_hud.settings_open = true
			"mq":
				get_tree().quit()
		return
	if not _voy.perk_offer.is_empty() and _voy.phase == Voyage.Phase.PLAN:
		if b.begins_with("p"):
			_voy.choose_perk(int(b.substr(1)))
		return
	if _hud.ship_active():
		if b == "ix":
			_hud.toggle_ship()
		elif b == "irep":
			_voy.buy_repair()
		elif b == "ipow":
			_voy.buy_powder()
		elif b.begins_with("g"):
			_hud.forge_click(b)
		elif b.begins_with("i"):
			_voy.buy_offer(int(b.substr(1)))
		return
	if _hud.crew_open:
		if b == "kx":
			_hud.toggle_crew()
		elif b == "krel":
			_voy.toggle_relief()
		elif b == "krd":
			if _voy.selected != null:
				_voy.dismiss(_voy.selected)
		elif b.begins_with("r") and b.length() > 1:
			_hud.reserve_click(int(b.substr(1)))
		elif b.begins_with("h") and b.length() > 1:
			_voy.hire_candidate(int(b.substr(1)))
		elif b.begins_with("k"):
			_hud.crew_click(int(b.substr(1)))
		return
	if b != "":
		if b == "kopen":
			_hud.toggle_crew()
		elif b == "sopen":
			_hud.toggle_ship()
		elif b.begins_with("d"):
			_voy.set_dial(int(b.substr(1, 1)), int(b.substr(2, 1)))
		elif b.begins_with("n"):
			_voy.select_route(int(b.substr(1)))
		elif b.begins_with("e"):
			_voy.decide_encounter(int(b.substr(1)))
		elif b == "go":
			_confirm()
		elif b == "lager":
			_voy.camp_start()
		elif b == "cend":
			_voy.camp_end()
		elif b == "ccrew":
			_hud.toggle_crew()
		elif b.begins_with("ca") and b.length() > 2:
			var ci := int(b.substr(2))
			if ci >= 0 and ci < Camp.ORDER.size():
				_voy.camp_do(String(Camp.ORDER[ci]))
		elif b == "rescue":
			_voy.decide_rescue(true)
		elif b == "abandon":
			_voy.decide_rescue(false)
		return
	if _voy.camping:
		return
	var i := _hud.card_at(p)
	if i >= 0:
		_voy.click_crew(_voy.crew[i])
		return
	var wp := p - _world.position
	for v in _views:
		if v.hit(wp):
			_voy.click_crew(v.member)
			return
	for mk in _markers:
		if mk.hit(wp):
			_voy.click_slot(mk.slot)
			return
	_voy.selected = null


# --- Spielbot für Tests ohne Menschen --------------------------------------

func _bot_step(delta: float) -> void:
	if _voy.ended:
		_end_wait -= delta
		if _end_wait < -1.0 and _shot_path == "":
			get_tree().quit()  # Testlauf beendet (kurz nachlaufen, damit die Ausgabe vollständig ist)
		return
	_bot_cd -= delta
	if _bot_cd > 0.0:
		return
	_bot_cd = 0.4
	if _voy.automat_open:
		if not (_shot_path != "" and _shot_slot != ""):
			_bot_slot()
		return
	if _voy.phase == Voyage.Phase.PLAN:
		if not _voy.perk_offer.is_empty():
			_bot_perk()
			return
		var links := _voy.next_links()
		if _bot == "smart":
			_bot_rotate()
			_bot_camp()
			_voy.select_route(_bot_route())
			_bot_dials()
		else:
			_voy.select_route(int(links[randi() % links.size()]))
			_voy.set_dial(0, randi() % 3)  # der Zufallsbot probiert alle Reglerstellungen
			_voy.set_dial(1, randi() % 3)
			_voy.set_dial(2, randi() % 3)
		_voy.confirm()
	elif _voy.phase == Voyage.Phase.RESCUE and not _shot_swim:
		_voy.decide_rescue(_bot == "smart" or randf() < 0.6)
	elif _voy.phase == Voyage.Phase.ENCOUNTER and not _shot_enc and not (_shot_harbor and Encounters.is_harbor(_voy.encounter)):
		if _voy.shop_open:
			_bot_shop()
		elif _bot == "smart" and Encounters.is_harbor(_voy.encounter) and _bot_hire():
			pass  # er hat jemanden angeheuert und schaut beim nächsten Schritt weiter
		else:
			_voy.decide_encounter(_bot_encounter())


## Der kluge Bot lagert, wenn die Männer müde, mutlos oder der Rumpf angeschlagen ist und der Proviant es trägt.
func _bot_camp() -> void:
	if not _voy.can_camp() or _voy.proviant < 9:
		return
	var men := Camp.everyone(_voy)
	var kraft := 0.0
	var stress_max := 0.0
	for m in men:
		kraft += m.kraft
		stress_max = maxf(stress_max, m.stress)
	var avg := kraft / maxf(float(men.size()), 1.0)
	if avg >= 62.0 and stress_max < 60.0 and _voy.hull >= 0.7 * _voy.hull_max():
		return
	_voy.camp_start()
	for id in ["watch", "sleep", "eat", "repair", "repair", "song", "fish", "map", "stories"]:
		_voy.camp_do(id)
	_voy.camp_end()


## Der Bot nimmt den ungefährlichsten Knoten, Händler und Inseln locken ihn, Monster nur mit starker Besatzung.
func _bot_route() -> int:
	var best := -1
	var best_score := 1000000.0
	for j in _voy.next_links():
		var nd := _voy.node_at(_voy.mile + 1, int(j))
		var score := float(_voy.node_danger(nd))
		var enc := int(nd["enc"])
		if enc == Encounters.Id.HAFEN:
			score -= 5.0 if (_voy.proviant < 12 or _voy.hull < 80.0 or _voy.fallen.size() > 0) else 2.0
		elif enc == Encounters.Id.HAENDLER or enc == Encounters.Id.INSEL or enc == Encounters.Id.WRACK:
			score -= 3.0
		elif enc == Encounters.Id.UNGEHEUER and _voy.strength() < 0.85:
			score += 4.0
		elif enc == Encounters.Id.DRAUGR or enc == Encounters.Id.RAEUBER or enc == Encounters.Id.KRAKEN:
			var ready := _voy.strength() >= 0.9 and _voy.hull >= 0.6 * _voy.hull_max()
			score += -1.0 if (ready or _voy.cannons() > 0) else 4.0
		if score < best_score:
			best_score = score
			best = int(j)
	return best


## Der kluge Bot heuert in der Taverne den kräftigsten Anwärter an, solange danach noch Beute bleibt und Platz da ist.
func _bot_hire() -> bool:
	if not _voy.can_recruit() or _voy.recruits.is_empty():
		return false
	var best := -1
	var best_kraft := -1.0
	for i in _voy.recruits.size():
		var c: Dictionary = _voy.recruits[i]
		if _voy.loot - float(c["price"]) >= 60.0 and float(c["kraft"]) > best_kraft:
			best = i
			best_kraft = float(c["kraft"])
	if best < 0:
		return false
	# eine zweite Reserve nur, wenn die Vorräte es tragen
	if _voy.reserve_free() > 0 and _voy.alive_count() >= Stations.SLOTS.size() and (_voy.proviant < 14 or _voy.reserve.size() >= 2):
		return false
	return _voy.hire_candidate(best)


## Der Bot am Automaten spielt gleich durch (ohne die Anzeige abzuwarten) und schließt wieder.
func _bot_slot() -> void:
	var smart := _bot == "smart"
	match _voy.automat_kind:
		"harbor":
			_bot_slot_visit = _voy.encounters_done
			var target := 6 if smart else randi_range(1, 10)
			var n := 0
			while n < target and _voy.automat_can_spin():
				_voy.automat_set_bet(1 if _voy.loot >= 5.0 * float(_voy.automat_levels()[1]) else 0)
				_slot_play_out()
				n += 1
		"bonus":
			if _voy.automat_can_spin():
				_slot_play_out()
		"loki":
			var uses := 0
			while _voy.pfand > 0 and uses < Items.PFAND_MAX and _voy.loki_pick("bottle") and _voy.loki_can_spin():  # erst die sicheren Freispiele
				_voy.loki_spin()
				if _voy.loki_pot > 0:
					if not smart and randf() < 0.5:
						_voy.loki_risk()
					_voy.loki_cash()
				uses += 1
			var rounds := 0
			while rounds < Voyage.LOKI_ROUNDS and _voy.loki_can_spin():
				var kinds: Array[String] = []
				for st in _voy.loki_stakes():
					if bool((st as Dictionary)["ok"]):
						kinds.append(String((st as Dictionary)["kind"]))
				if kinds.is_empty():
					break
				var pick := "loot" if (smart and kinds.has("loot")) else kinds[randi() % kinds.size()]
				if smart and (pick != "loot" or _voy.loot < 90.0):
					break
				if not _voy.loki_pick(pick):
					break
				_voy.loki_spin()
				if _voy.loki_pot > 0:
					if not smart and randf() < 0.5:
						_voy.loki_risk()
					_voy.loki_cash()
				rounds += 1
	_voy.automat_close()


## Ein Dreh der Nornenwalzen samt allen Freispielen, dann gutschreiben.
func _slot_play_out() -> void:
	_voy.automat_spin()
	var guard := 0
	while _voy.automat.in_free() and guard < 60:
		_voy.automat_spin()
		guard += 1
	_voy.automat_bank()


## Im Hafen kauft der kluge Bot, was fehlt, und legt dann ab; der Zufallsbot probiert herum.
func _bot_harbor() -> int:
	var opts: Array = Encounters.DATA[_voy.encounter]["options"]
	var order: Array[int] = []
	if _bot == "smart":
		var stress := 0.0
		var kraft := 0.0
		var n := 0
		for m in _voy.crew:
			if m.state == CrewMember.State.ABOARD:
				stress += m.stress
				kraft += m.kraft
				n += 1
		var avg_stress := stress / maxf(n, 1)
		var avg_kraft := kraft / maxf(n, 1)
		if _voy.proviant < _voy.stat("proviant_max") - 5.0:
			order.append(3)
		if (_voy.hull < _voy.hull_max() - 15.0 or _voy.loot >= 70.0) and _bot_shop_visit != _voy.encounters_done:
			order.append(4)  # Werft: reparieren und ausbauen
		if avg_stress > 30.0:
			order.append(0)
		if avg_kraft < 60.0:
			order.append(1)
		if _voy.proviant < 11:
			order.append(3)
		if _voy.loot >= 120.0 and _bot_slot_visit != _voy.encounters_done:
			order.append(5)  # Spelunke: ein paar Drehs mit überschüssiger Beute
	else:
		order.append(randi() % opts.size())
	for i in order:
		if Encounters.available(_voy, opts[i]):
			return i
	return opts.size() - 1


## In der Werft: erst reparieren, dann kaufen, was am meisten bringt, Reserve behalten, zuletzt schließen.
func _bot_shop() -> void:
	if _bot != "smart":
		if randf() < 0.5 and not _voy.shop.is_empty():
			_voy.buy_offer(randi() % _voy.shop.size())
		_bot_shop_visit = _voy.encounters_done
		_voy.close_shop()
		return
	if _voy.hull < _voy.hull_max() - 20.0 and _voy.buy_repair():
		return
	var order := ["kanone", "beschlag", "teer", "tuch", "schwere", "riemen", "planken", "werkzeug", "esche", "sturm", "fass", "pulver", "truhe", "prunk", "drachenkopf", "sporn"]
	for id in order:
		var idx := -1
		for k in _voy.shop.size():
			if Items.base_id(String(_voy.shop[k])) == id:
				idx = k
		if idx >= 0 and _voy.loot - float(Items.price_at(String(_voy.shop[idx]), _voy.stage)) >= 25.0 and _voy.buy_offer(idx):
			return
	_voy.auto_equip()  # was im Vorrat liegt, legt jemand an
	if _bot_forge():
		return
	if _voy.hull >= _voy.hull_max() * 0.85:
		for gi in _voy.gear_shop.size():
			if _voy.loot - float(Gear.price_at(String(_voy.gear_shop[gi]), _voy.stage)) >= 90.0 and _voy.buy_gear(gi):
				_voy.auto_equip()
				return
	if _voy.cannons() > 0 and _voy.powder < 6 and _voy.buy_powder():
		return
	_bot_shop_visit = _voy.encounters_done
	_voy.close_shop()


## Schmiede für den klugen Bot: die billigste Verbesserung, die ihm noch Beute übrig lässt (Waffe und Rüstung zuerst).
func _bot_forge() -> bool:
	var best_kind := ""
	var best_man: CrewMember = null
	var best_sid := ""
	var best_price := 100000
	if _voy.hull < _voy.hull_max() * 0.85:
		return false  # erst den Rumpf, dann die Männer
	for m in _voy.forge_men():
		for kind in ["weapon", "armor"]:
			var p := _voy.forge_price(kind, m)
			if p > 0 and p < best_price and _voy.loot - float(p) >= 60.0:
				best_price = p
				best_kind = kind
				best_man = m
				best_sid = ""
		for sid in m.skills():
			var p2 := _voy.forge_price("skill", m, String(sid))
			if p2 > 0 and p2 < best_price and _voy.loot - float(p2) >= 60.0:
				best_price = p2
				best_kind = "skill"
				best_man = m
				best_sid = String(sid)
	return best_man != null and _voy.forge_buy(best_kind, best_man, best_sid)

## Seeschlacht: der kluge Bot liest den angekündigten Zug und wählt die Taktik dagegen.
func _bot_battle() -> int:
	# Karten: 0 Rammen, 1 Pfeilhagel, 2 Kanonen, 3 Entern, 4 Schildwall, 5 Flicken, 6 Fliehen
	var opts: Array = Encounters.DATA[_voy.encounter]["options"]
	if _bot != "smart":
		var r := randi() % opts.size()
		return r if Encounters.available(_voy, opts[r]) else 4
	var b := _voy.battle
	var ecrew := int(b["ecrew"])
	var ehull := float(b["ehull"])
	var intent := int(b["intent"])
	var frac := _voy.hull / _voy.hull_max()
	var can_cannon := Battle.can_use(_voy, "cannon")
	var can_repair := Battle.can_use(_voy, "repair")
	var pick := 0
	if can_cannon and ehull <= float(Battle.cannon_damage(_voy)):
		pick = 2  # der Schuss beendet es
	elif ehull <= float(Battle.ram_damage(_voy)) and _voy.hull > 30.0:
		pick = 0
	elif frac < 0.22:
		pick = 6
	elif frac < 0.45 and can_repair and intent != Battle.Intent.RAM:
		pick = 5
	elif can_cannon:
		pick = 2
	elif ecrew <= 2 and Battle.board_chance(_voy) >= 0.55:
		pick = 3
	else:
		match intent:
			Battle.Intent.RAM:
				pick = 4 if frac < 0.6 else 1
			Battle.Intent.BOARD:
				pick = 3 if Battle.board_chance(_voy) >= 0.65 else 1
			Battle.Intent.SHOOT:
				pick = 3 if Battle.board_chance(_voy) >= 0.6 else (0 if frac > 0.6 else 4)
			_:
				pick = 0 if frac > 0.6 else 1
	if not Encounters.available(_voy, opts[pick]):
		pick = 4
	return pick


func _bot_encounter() -> int:
	if Encounters.is_harbor(_voy.encounter):
		return _bot_harbor()
	if Encounters.is_battle(_voy.encounter):
		return _bot_battle()
	var s := _voy.strength()
	var pick := 2
	match _voy.encounter:
		Encounters.Id.HAENDLER:
			pick = 0 if s > 0.75 else (1 if (_voy.loot >= 30.0 and _voy.proviant < 10) else 2)
		Encounters.Id.INSEL:
			pick = 0 if _voy.proviant < 12 else 1
			if _voy.hull < _voy.hull_max() - 30.0 and _voy.proviant >= 3:
				pick = 2  # Bucht: flicken
		Encounters.Id.WRACK:
			pick = 0 if _voy.hull > 0.5 * _voy.hull_max() else 1
		Encounters.Id.UNGEHEUER:
			pick = 0 if s > 0.85 else (1 if _voy.proviant >= 8 else 2)
		Encounters.Id.DORF:
			pick = 0 if s > 0.75 else 1
			if _voy.hull < _voy.hull_max() - 30.0 and _voy.loot >= 30.0:
				pick = 2  # Handwerker
		Encounters.Id.SPIELER:
			pick = 1 if _voy.pfand > 0 else (0 if _voy.loot >= 120.0 else 2)  # die Pfandflasche zuerst, sonst nur mit Beute zum Verspielen
	var opts: Array = Encounters.DATA[_voy.encounter]["options"]
	if _bot != "smart":
		pick = randi() % opts.size()
	if not Encounters.available(_voy, opts[pick]):
		pick = opts.size() - 1  # die letzte Option ist immer kostenlos
	return pick


## Die Frischesten an die wichtigen Plätze, die Müdesten auf die Ladung (Rast).
func _bot_rotate() -> void:
	var order := [Stations.Id.STEUER, Stations.Id.RUDER, Stations.Id.ZIMMERMANN, Stations.Id.SEGEL, Stations.Id.LADUNG]
	var slots: Array[int] = []
	for st in order:
		for i in Stations.SLOTS.size():
			if Stations.slot_station(i) == st:
				slots.append(i)
	var men: Array[CrewMember] = []
	for m in _voy.crew:
		if m.state == CrewMember.State.ABOARD:
			men.append(m)
	men.sort_custom(func(a: CrewMember, b: CrewMember) -> bool: return a.kraft > b.kraft)
	for k in mini(men.size(), slots.size()):
		var man := men[k]
		var slot := slots[k]
		if man.slot == slot:
			continue
		var occupant: CrewMember = _voy.slot_owner[slot]
		_voy.click_crew(man)
		if occupant == null:
			_voy.click_slot(slot)
		else:
			_voy.click_crew(occupant)


## Segen wählen: der kluge Bot nimmt, was am längsten trägt; der Zufallsbot irgendeinen.
func _bot_perk() -> void:
	var pick := randi() % _voy.perk_offer.size()
	if _bot == "smart":
		var order := ["odin", "wellen", "sturm", "haende", "schilde", "ramm", "wind", "arme", "vorrat", "lieder", "zaeh", "pulver", "karte", "glueck"]
		var best := 999
		for i in _voy.perk_offer.size():
			var rank := order.find(String(_voy.perk_offer[i]))
			if rank >= 0 and rank < best:
				best = rank
				pick = i
	_voy.choose_perk(pick)


## Der kluge Bot probiert alle 27 Reglerstellungen in der Vorschau durch und nimmt die mit dem besten Verhältnis
## aus Strecke, Rumpfschaden, Verlust über Bord, Müdigkeit und Proviant.
func _bot_dials() -> void:
	var best := -1.0e9
	var best_set: Array = [1, 1, 1]
	var avg := 0.0
	var n := 0
	for m in _voy.crew:
		if m.state == CrewMember.State.ABOARD:
			avg += m.kraft
			n += 1
	avg /= maxf(n, 1)
	for s in 3:
		for o in 3:
			for c in 3:
				var d := _voy.maneuver(s, o, c)
				if not _voy.can_choose(d):
					continue
				if bool(d["rest"]) and avg >= 55.0 and _voy.hull >= 0.75 * _voy.hull_max():
					continue  # rasten nur, wenn es etwas zu erholen gibt
				var p := _voy.plan(d)
				var score := float(p["miles"]) * 14.0
				if float(p["miles"]) == 0.0 and not bool(d["rest"]):
					score -= 40.0  # nur treiben bringt nichts: lieber richtig rasten oder fahren
				var after := float(p["hull_after"])
				var drop := _voy.hull - after
				score -= drop * (1.0 if _voy.hull > 50.0 else 2.5)
				if after <= 0.0:
					score -= 1000.0
				var keep := 1.0
				for row in p["rows"]:
					keep *= (1.0 - float(row["wash"])) * (1.0 - float(row["h_over"]))
				score -= (1.0 - keep) * 45.0
				score -= (p["tired"] as Array).size() * 6.0
				# Reicht der Proviant bis zum nächsten Hafen? Knapp gerechnet eine Fahrt pro Meile, dazu zwei Reserve.
				var reserve := maxf(_voy.harbor_distance() - float(p["miles"]), 0.0) * 1.15 + 2.0
				var spare := float(_voy.proviant - int(d["proviant"])) - reserve
				score -= float(d["proviant"]) * 2.0
				if spare < 0.0:
					score -= -spare * 6.0
				var costs: Dictionary = d["cost"]
				var change := 0.0
				for i in Stations.SLOTS.size():
					if _voy.slot_owner[i] != null:
						change -= float(costs.get(Stations.slot_station(i), 0))
				score += change / maxf(n, 1) * (0.5 if avg < 60.0 else 0.15)
				if score > best:
					best = score
					best_set = [s, o, c]
	_voy.set_dial(0, int(best_set[0]))
	_voy.set_dial(1, int(best_set[1]))
	_voy.set_dial(2, int(best_set[2]))
	if _voy.log_enabled:
		print("DIAL %d%d%d" % [best_set[0], best_set[1], best_set[2]])


