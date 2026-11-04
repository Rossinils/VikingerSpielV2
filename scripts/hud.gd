class_name Hud
extends Control

## Anzeige der Überfahrt. Text wird in Bildschirmauflösung gezeichnet (Stretch-Modus canvas_items),
## alle Koordinaten hier sind Spielfeld-Pixel (480x320). Klicks wertet Main über button_at() und
## card_at() aus; die Schaltflächen werden bei jedem Zeichnen neu eingetragen.

const CARD_W := 65.0
const CARD_H := 38.0
const CARD_Y := Waves.VIEW_H - CARD_H - 4.0
const CARD_X0 := 6.0
const CARD_STEP := 67.0
const STRAT_X0 := 6.0
const STRAT_W := 75.0
const STRAT_STEP := 78.0
const STRAT_Y := 196.0  # Begegnungs-, Hafen- und Schlachtkarten (hoch, mehr Text)
const STRAT_H := 66.0
const BAND_Y := 226.0  # unten ein dunkles Band wie bei Darkest Dungeon: Regler, Mannschaft, Schaltflächen
const DIAL_STEP := 124.0  # drei Reglergruppen nebeneinander: Segel, Ruder, Küste
const DIAL_Y := 244.0  # Oberkante der Knöpfe
const DIAL_H := 16.0
const ENC_W := 152.0
const ENC_STEP := 158.0
const GO_RECT := Rect2(384, 238, 90, 22)
const CREW_LINK := Rect2(430, 264, 44, 11)
const LAGER_RECT := Rect2(384, 229, 90, 9)  # Lager aufschlagen (Taste L), über "Auslaufen"
const SHIP_LINK := Rect2(384, 264, 44, 11)
const PREVIEW_RECT := Rect2(4, 40, 150, 150)
const CHART_RECT := Rect2(344, 14, 130, 178)
const CHART_TOP := 42.0  # Zeile der Spalte 10 (Land); Heimat liegt 10 Zeilen darunter
const CHART_STEP := 12.5
const CHART_INFO_Y := 178.0  # Einzelheiten zum Knoten unter dem Karteninhalt

const INK := Color("0d0b10")
const PAPER := Color("e6e0cc")
const DIM := Color("a3a9b0")
const GOLD := Color("d9b24a")
const RED := Color("d2564b")
const GREEN := Color("7ab85a")
const BLUE := Color("5a8ad9")
const VIOLET := Color("a97fd6")
const TRACK := Color(0.1, 0.12, 0.15, 0.85)
const PANEL := Color(0.04, 0.05, 0.07, 0.88)

var voy: Voyage
var music: MusicDirector
var hover_crew: CrewMember = null  # Main meldet den Mann unter der Maus (an Deck)
var memorial_open := false
var menu_open := false  # Hauptmenü (beim Start und mit Esc)
var menu_can_continue := false  # es gibt eine laufende Fahrt, die man fortsetzen kann
var menu_new_armed := false  # "Neue Fahrt" wurde einmal angeklickt
var _legacy: Dictionary = {}  # Vermächtnis für die Menüanzeige (einmal berechnet)
var settings_open := false  # Einstellungen (aus dem Hauptmenü)
var crew_open := false  # Mannschaftsansicht (Taste C)
var ship_open := false  # Schiffsansicht (Taste B); im Hafen öffnet die Werft sie mit dem Angebot
var _crew_pick: CrewMember = null
var _mem_runs: Array = []
var _mem_data: Dictionary = {"runs": []}
var _mem_index := 0
var _ui: Font
static var text_check := false  # --textcheck: _t meldet zu breiten Text (Entwicklung)
var _text_seen := {}
var _lore: Font
var _help := true
var _btns: Array = []
var debug_hover: Array = []  # nur für Screenshot-Tests (--hoverdial=1,2): tut so, als läge die Maus auf diesem Knopf
var debug_mouse := Vector2(-1, -1)  # nur für Screenshot-Tests (--hovermouse=x,y)
var _hover_dial: Array = []  # [Regler, Stellung] unter der Maus, leer wenn keiner
var _hover_node: Array = []
var _tips: Array = []  # Tooltip-Flächen dieses Bildes: [{r: Rect2, tip: Dictionary}], später eingetragene gelten zuerst
var slot_view: SlotView = null  # Spielautomat über allem, solange voy.automat_open
var slot_demo := ""  # nur für Screenshots (--shotslot=...): Szene des Automaten
var _loot_seen := -1.0
var _loot_pop := 0.0  # so lange wird die Änderung der Beute neben der Zahl gezeigt
var _loot_delta := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui = _make_font(["Segoe UI Semibold", "Segoe UI", "Arial"], false)
	_lore = _make_font(["Georgia", "Palatino Linotype", "Times New Roman"], true)


func _exit_tree() -> void:
	slot_view = null


func _make_font(names: Array, italic: bool) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_italic = italic
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


func setup(v: Voyage) -> void:
	voy = v


func toggle_help() -> void:
	_help = not _help


func hide_help() -> void:
	_help = false


func help_open() -> bool:
	return _help


func card_rect(i: int) -> Rect2:
	return Rect2(CARD_X0 + i * CARD_STEP, CARD_Y, CARD_W, CARD_H)


func strategy_rect(i: int) -> Rect2:
	return Rect2(STRAT_X0 + i * STRAT_STEP, STRAT_Y, STRAT_W, STRAT_H)


## Knopf einer Stellung (dial 0 Segel, 1 Ruder, 2 Küste; level 0..2).
func dial_rect(dial: int, level: int) -> Rect2:
	return Rect2(STRAT_X0 + dial * DIAL_STEP + level * 40.0, DIAL_Y, 38.0, DIAL_H)


## Begegnungskarten teilen sich die Breite: drei breite oder vier schmalere.
func encounter_rect(i: int) -> Rect2:
	var n := 3
	if voy != null and voy.encounter >= 0:
		n = maxi((Encounters.DATA[voy.encounter]["options"] as Array).size(), 3)
	var gap := 6.0
	var w := (468.0 - gap * float(n - 1)) / float(n)
	return Rect2(STRAT_X0 + float(i) * (w + gap), STRAT_Y, w, STRAT_H)


func node_pos(c: int, i: int) -> Vector2:
	var n: int = (voy.map[c] as Array).size()
	var x := CHART_RECT.position.x + CHART_RECT.size.x * float(i + 1) / float(n + 1)
	var y := CHART_TOP + (Voyage.MILES - c) * CHART_STEP
	return Vector2(roundf(x), roundf(y))


func card_at(p: Vector2) -> int:
	if voy == null:
		return -1
	for i in voy.crew.size():
		if card_rect(i).has_point(p):
			return i
	return -1


func button_at(p: Vector2) -> String:
	for b in _btns:
		if (b["rect"] as Rect2).has_point(p):
			return String(b["id"])
	return ""


func _process(delta: float) -> void:
	_tick_fight(delta)
	if voy != null:
		if voy.automat_open:
			if slot_view == null:
				slot_view = SlotView.new(voy)
				if slot_demo != "":
					slot_view.demo(slot_demo)
					slot_demo = ""
			slot_view.tick(delta)
		elif slot_view != null:
			slot_view = null
		if _loot_seen < 0.0:
			_loot_seen = voy.loot
		elif absf(voy.loot - _loot_seen) >= 1.0:  # Beute hat sich geändert: kurz daneben anzeigen
			var change := roundi(voy.loot - _loot_seen)
			_loot_delta = _loot_delta + change if _loot_pop > 0.0 else change
			_loot_pop = 3.5
			_loot_seen = voy.loot
		_loot_pop = maxf(_loot_pop - delta, 0.0)
	queue_redraw()

## Das Manöver, das sich ergäbe, wenn dieser Regler auf diese Stellung käme (Regler aus dem Spiel bleiben sonst gleich).
func _with_dial(dial: int, level: int) -> Dictionary:
	return voy.maneuver(level if dial == 0 else -1, level if dial == 1 else -1, level if dial == 2 else -1)


## Knopf unter der Maus als [Regler, Stellung]; leer, wenn keiner oder nicht wählbar (z. B. Rast ohne Proviant).
func _dial_at(p: Vector2) -> Array:
	if not debug_hover.is_empty():
		return debug_hover
	for dl in 3:
		for lv in 3:
			if dial_rect(dl, lv).has_point(p) and voy.can_choose(_with_dial(dl, lv)):
				return [dl, lv]
	return []


func _draw() -> void:
	if voy == null or voy.crew.is_empty():
		return
	_btns.clear()
	_tips.clear()
	var mouse := get_local_mouse_position() if debug_mouse.x < 0.0 else debug_mouse
	_hover_dial = []
	if menu_open:
		_draw_music()
		if settings_open:
			_draw_settings(mouse)
		else:
			_draw_menu(mouse)
		if memorial_open:
			_draw_memorial()
		return
	if voy.phase == Voyage.Phase.COMBAT:
		_draw_combat_view(mouse)
		return
	if voy.phase == Voyage.Phase.PLAN and not crew_open and not ship_active():
		_hover_dial = _dial_at(mouse)
	if (crew_open or ship_open) and (voy.ended or not (voy.phase == Voyage.Phase.PLAN or voy.phase == Voyage.Phase.ENCOUNTER)):
		crew_open = false
		ship_open = false
	UiSkin.vignette(self, 1)
	_draw_top()
	_draw_music()
	_draw_log()
	_draw_chart(mouse)
	_draw_preview()
	_draw_band()
	if voy.encounter >= 0 and (voy.phase == Voyage.Phase.ENCOUNTER or voy.phase == Voyage.Phase.RESOLVE):
		_draw_encounter_cards()
	else:
		_draw_dials()
	_draw_go()
	_draw_lager_button(mouse)
	_draw_crew_link(mouse)
	_draw_cards(mouse)
	if voy.phase == Voyage.Phase.RESCUE:
		_draw_rescue()
	if crew_open:
		_draw_crew_manager(mouse)
	elif voy.camping:
		_draw_camp(mouse)
	elif ship_active():
		_draw_ship_view(mouse)
	elif not memorial_open:
		_draw_crew_tooltip(mouse)
		if voy.perk_offer.is_empty() and not _help and not voy.ended and _hover_dial.is_empty():
			_draw_tip(mouse)
	if not voy.perk_offer.is_empty() and voy.phase == Voyage.Phase.PLAN:
		_draw_perks(mouse)
	if _help:
		_draw_help()
	if voy.ended:
		_draw_end()
	if memorial_open:
		_draw_memorial()
	if voy.automat_open and slot_view != null:
		slot_view.draw(self, mouse)


## Klick und Taste für den Spielautomaten (Main leitet sie weiter, solange voy.automat_open).
func slot_click(id: String) -> void:
	if slot_view != null:
		slot_view.click(id)


func slot_key(key: int) -> bool:
	return slot_view != null and slot_view.key(key)


# --- Zeichenhelfer ----------------------------------------------------------

func _t(pos: Vector2, s: String, col: Color = PAPER, size: int = 9, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0, font: Font = null) -> void:
	var f := font if font != null else _ui
	if w > 0.0 and float(s.length()) * float(size) * 0.95 > w:
		# Sicherheitsnetz: draw_string schneidet Text, der breiter als w ist, hart ab (mitten im Wort). Lieber erst
		# eine Stufe kleiner (bis 6), dann mit "…" kürzen. Kurze Texte kommen an dieser Prüfung gar nicht vorbei.
		var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if tw > w:
			var was := s
			var k := size
			while k > 6 and tw > w:
				k -= 1
				tw = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, k).x
			if tw > w:
				while s.length() > 1 and tw > w:
					s = s.substr(0, s.length() - 1)
					tw = f.get_string_size(s.rstrip(" ,.") + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, k).x
				s = s.rstrip(" ,.") + "…"
			if text_check and not _text_seen.has(was):
				_text_seen[was] = true
				print("TEXTCHECK: \"%s\" (Größe %d, bei %.0f,%.0f): zu breit für %.0f px, angepasst auf Größe %d%s" % [was, size, pos.x, pos.y, w, k, " und gekürzt" if s != was else ""])
			size = k
	draw_string_outline(f, pos, s, align, w, size, 3, INK)
	draw_string(f, pos, s, align, w, size, col)
	if text_check and w <= 0.0:
		_check_text(pos, s, align, w, size, f)


## --textcheck: meldet (einmal je Text), wenn eine Zeile breiter als das ihr gegebene Feld ist oder rechts aus dem Bild ragt.
func _check_text(pos: Vector2, s: String, align: int, w: float, size: int, f: Font) -> void:
	if s == "":
		return
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var why := ""
	if w > 0.0 and tw > w + 0.5:
		why = "breiter als das Feld (%.0f > %.0f px)" % [tw, w]
	elif align == HORIZONTAL_ALIGNMENT_LEFT and pos.x + tw > Waves.VIEW_W + 0.5:
		why = "ragt rechts aus dem Bild (bis x %.0f)" % (pos.x + tw)
	if why != "" and not _text_seen.has(s):
		_text_seen[s] = true
		print("TEXTCHECK: \"%s\" (Größe %d, bei %.0f,%.0f): %s" % [s, size, pos.x, pos.y, why])


func _bar(x: float, y: float, w: float, h: float, frac: float, col: Color) -> void:
	UiSkin.bar(self, x, y, w, h, frac, col)


func _register(rect: Rect2, id: String) -> void:
	_btns.append({"rect": rect, "id": id})


## Eine Fläche, über der ein Erklär-Tooltip erscheint (Texte stehen in scripts/tips.gd).
func _tip(rect: Rect2, tip: Dictionary) -> void:
	_tips.append({"r": rect, "tip": tip})


## Der Tooltip unter der Maus: Titel in Gold, darunter die Erklärung, umgebrochen. Springt nach links oder oben,
## wo rechts oder unten kein Platz ist.
func _draw_tip(mouse: Vector2) -> void:
	var tip: Dictionary = {}
	for k in range(_tips.size() - 1, -1, -1):
		if (_tips[k]["r"] as Rect2).has_point(mouse):
			tip = _tips[k]["tip"]
			break
	if tip.is_empty():
		return
	var lines: Array = tip["l"]
	var max_h := Waves.VIEW_H - 12.0
	# zu hoher Text: erst breiter setzen, dann hinten kürzen, damit nie etwas unten abgeschnitten wird
	var w := 178.0
	var h := _tip_height(lines, w)
	if h > max_h:
		w = 250.0
		h = _tip_height(lines, w)
	if h > max_h:
		var shown: Array = []
		var used := 22.0
		for ln in lines:
			var lh := _ui.get_multiline_string_size(String(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, w - 12.0, 8, -1).y + 3.0
			if used + lh + 12.0 > max_h:
				break
			shown.append(ln)
			used += lh
		shown.append(["…", DIM])
		lines = shown
		h = _tip_height(lines, w)
	var x := mouse.x + 10.0
	if x + w > Waves.VIEW_W - 4.0:
		x = mouse.x - w - 8.0
	var y := mouse.y + 12.0
	if y + h > Waves.VIEW_H - 4.0:
		y = mouse.y - h - 6.0
	var box := Rect2(clampf(x, 4.0, Waves.VIEW_W - w - 4.0), clampf(y, 4.0, maxf(Waves.VIEW_H - h - 4.0, 4.0)), w, h)
	UiSkin.panel(self, box, UiSkin.BRONZE, 1, "tile_stone")
	_t(box.position + Vector2(7, 13), String(tip["t"]), GOLD, 9)
	var ty := box.position.y + 18.0
	for ln in lines:
		ty = _wrap(String(ln[0]), box.position.x + 7.0, ty, w - 12.0, 8, ln[1])


## Höhe eines Tooltips für diese Zeilen bei Breite w.
func _tip_height(lines: Array, w: float) -> float:
	var h := 22.0
	for ln in lines:
		h += _ui.get_multiline_string_size(String(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, w - 12.0, 8, -1).y + 3.0
	return h

## Großes Panel im Pixelrahmen (Eisenecken, Doppelrahmen, Nieten).
func _panel(r: Rect2, border: Color = UiSkin.BRONZE, tile_name: String = "tile_wood") -> void:
	UiSkin.panel(self, r, border, 2, tile_name)


## Karte mit Zustand: normal (Bronze), überfahren (hell, leuchtende Innenlinie), gesperrt (dunkel).
func _card(r: Rect2, state: int, alpha: float = 1.0, col: Color = Color(0, 0, 0, 0)) -> void:
	var edge := UiSkin.accent(state) if col.a <= 0.0 else col
	UiSkin.panel(self, r, edge, 1, "tile_wood", true, Color(1, 1, 1, alpha), state == UiSkin.State.HOVER or state == UiSkin.State.SELECTED)


## Kleiner Schalter (Schließen, Zurück, ±): Knopf mit Text.
func _small_button(r: Rect2, label: String, hover: bool, enabled: bool = true, size: int = 8) -> void:
	UiSkin.button(self, r, UiSkin.State.HOVER if (hover and enabled) else (UiSkin.State.NORMAL if enabled else UiSkin.State.DISABLED))
	_t(Vector2(r.position.x, r.position.y + (r.size.y + float(size)) * 0.5 - 1.0), label, PAPER if enabled else DIM, size, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


# --- Bereiche ---------------------------------------------------------------

## Eine ruhige Kopfzeile: Rumpf, Proviant und Beute links, Meile und See rechts. Die Erfahrung ist nur ein
## feiner Strich am oberen Rand, Etappe und Stufe stehen über der Seekarte.
func _draw_top() -> void:
	# dunkle Leiste mit Bronzekante; die Erfahrung läuft als feiner Strich an ihrer Unterkante
	UiSkin.fill_tile(self, Rect2(0, 0, Waves.VIEW_W, 13), "tile_band", Color(1, 1, 1, 0.92))
	draw_rect(Rect2(0, 13, Waves.VIEW_W, 1), Color(UiSkin.BRONZE, 0.85))
	var xpw := roundf(Waves.VIEW_W * float(voy.xp) / float(voy.xp_needed()))
	if xpw > 0.0:
		draw_rect(Rect2(0, 13, xpw, 1), VIOLET)
	var x := 6.0
	var hmax := voy.hull_max()
	var hcol := GREEN if voy.hull > 0.6 * hmax else (GOLD if voy.hull > 0.3 * hmax else RED)
	_t(Vector2(x, 12), "Rumpf", DIM, 8)
	_bar(x + 30.0, 5.0, 44.0, 6.0, voy.hull / hmax, hcol)
	_t(Vector2(x + 80.0, 12), "%d" % maxi(roundi(voy.hull), 0), PAPER, 9)
	x = 118.0
	_t(Vector2(x, 12), "Proviant", DIM, 8)
	_bar(x + 36.0, 5.0, 44.0, 6.0, float(voy.proviant) / voy.stat("proviant_max"), RED if voy.proviant <= 3 else GOLD)
	_t(Vector2(x + 86.0, 12), "%d" % voy.proviant, PAPER, 9)
	_t(Vector2(226, 12), "Beute", DIM, 8)
	_t(Vector2(252, 12), "%d" % roundi(voy.loot), GOLD, 9)
	if voy.cannons() > 0:
		_t(Vector2(282, 12), "Pulver", DIM, 8)
		_t(Vector2(310, 12), "%d" % voy.powder, RED if voy.powder == 0 else PAPER, 9)
	var sea := voy.location_sea()
	var text := "Meile %s von %d  ·  " % [Voyage.fmt(float(voy.mile) + voy.leg), Voyage.MILES]
	var w1 := _ui.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var w2 := _ui.get_string_size(Sea.SEA_NAMES[sea], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var x2 := 474.0 - w1 - w2
	_t(Vector2(x2, 12), text, PAPER)
	_t(Vector2(x2 + w1, 12), Sea.SEA_NAMES[sea], Sea.SEA_COLORS[sea])
	if _loot_pop > 0.0 and _loot_delta != 0:  # Beute gewonnen (grün) oder bezahlt (rot), blendet aus
		var nx := 252.0 + _ui.get_string_size("%d" % roundi(voy.loot), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 4.0
		_t(Vector2(nx, 12), Voyage.signed(_loot_delta), Color(GREEN if _loot_delta > 0 else RED, minf(_loot_pop, 1.0)), 9)
	_tip(Rect2(0, 0, 112, 14), Tips.top_hull(voy))
	_tip(Rect2(114, 0, 108, 14), Tips.top_food(voy))
	_tip(Rect2(224, 0, 56, 14), Tips.top_loot(voy))
	if voy.cannons() > 0:
		_tip(Rect2(280, 0, 48, 14), Tips.top_powder(voy))
	_tip(Rect2(x2, 0, w1 - 6.0, 14), Tips.top_mile(voy))
	_tip(Rect2(x2 + w1, 0, w2 + 2.0, 14), Tips.top_sea(voy))

## Titel des laufenden Liedes, blendet nach ein paar Sekunden aus (links unter der Kopfzeile).
func _draw_music() -> void:
	if music == null or music.title_time <= 0.0 or music.status == "":
		return
	var a := clampf(music.title_time, 0.0, 1.0)
	var pos := Vector2(6, 24)
	draw_string_outline(_ui, pos, music.status, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(INK, a))
	draw_string(_ui, pos, music.status, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(DIM, a))


## Nur die beiden letzten Meldungen, die ältere verblasst. Alles Weitere steht in der Vorschau und im Steckbrief.
func _draw_log() -> void:
	var x := 158.0
	var w := 176.0
	var y := 88.0
	var items: Array = []  # [Eintrag, Schrift, Größe, Höhe]
	for i in range(voy.history.size() - 1, -1, -1):
		if items.size() >= 2:
			break
		var e: Dictionary = voy.history[i]
		var is_lore := int(e["kind"]) == Voyage.Kind.LORE
		var f := _lore if is_lore else _ui
		var size := 10 if is_lore else 9
		var sz := f.get_multiline_string_size(String(e["text"]), HORIZONTAL_ALIGNMENT_CENTER, w, size, -1)
		y -= sz.y
		if y < 20.0:
			break
		items.append([e, f, size, sz.y, y])
		y -= 3.0
	if items.is_empty():
		return
	# dunkle Leiste hinter dem Text, damit er auch vor hellen Wolken lesbar bleibt
	var top := float(items.back()[4]) - 4.0
	var back := Rect2(x - 4.0, top, w + 8.0, 92.0 - top)
	draw_rect(back, Color(0.03, 0.04, 0.07, 0.5))
	draw_rect(Rect2(back.position.x, back.position.y, back.size.x, 1), Color(UiSkin.BRONZE, 0.5))
	draw_rect(Rect2(back.position.x, back.end.y - 1, back.size.x, 1), Color(UiSkin.BRONZE, 0.5))
	for k in items.size():
		var e: Dictionary = items[k][0]
		var f: Font = items[k][1]
		var size: int = items[k][2]
		var text := String(e["text"])
		var kind := int(e["kind"])
		var col := PAPER
		if kind == Voyage.Kind.BAD:
			col = Color(0.88, 0.45, 0.4)  # helleres Rot: vor Wolken und Wellen lesbar
		elif kind == Voyage.Kind.GOOD:
			col = GREEN
		var a := 1.0 if k == 0 else 0.6
		var pos := Vector2(x, float(items[k][4]) + f.get_ascent(size))
		draw_multiline_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, -1, 3, Color(INK, a))
		draw_multiline_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, -1, Color(col, a))


## Seekarte: Heimat unten, Land oben. Man kennt nur die nächsten Meilen (im Nebel nur eine).
var _pix_cache := {}  # Pixelwege (Bresenham) je Linie, einmal berechnet


## Harte Pixellinie zwischen zwei Punkten, gestrichelt (2 an, 2 aus) oder durchgezogen; thick = Breite in Pixeln.
func _pix_line(a: Vector2, b: Vector2, col: Color, dashed: bool, thick: int) -> void:
	var key := Vector4(roundf(a.x), roundf(a.y), roundf(b.x), roundf(b.y))
	var pts: PackedVector2Array
	if _pix_cache.has(key):
		pts = _pix_cache[key]
	else:
		pts = PackedVector2Array()
		var x0 := int(key.x)
		var y0 := int(key.y)
		var x1 := int(key.z)
		var y1 := int(key.w)
		var dx := absi(x1 - x0)
		var dy := -absi(y1 - y0)
		var sx := 1 if x0 < x1 else -1
		var sy := 1 if y0 < y1 else -1
		var err := dx + dy
		while true:
			pts.append(Vector2(x0, y0))
			if x0 == x1 and y0 == y1:
				break
			var e2 := 2 * err
			if e2 >= dy:
				err += dy
				x0 += sx
			if e2 <= dx:
				err += dx
				y0 += sy
		if _pix_cache.size() > 600:
			_pix_cache.clear()
		_pix_cache[key] = pts
	var sz := Vector2(thick, thick)
	for k in pts.size():
		if dashed and (k % 4) >= 2:
			continue
		draw_rect(Rect2(pts[k], sz), col)


## Vier Eckwinkel um einen Knoten (hart, ohne Verlauf).
func _brackets(p: Vector2, half: int, col: Color, thick: int) -> void:
	var n := 3.0
	var t := float(thick)
	var lo := Vector2(p.x - half, p.y - half)
	var hi := Vector2(p.x + half, p.y + half)
	for sx in [0, 1]:
		for sy in [0, 1]:
			var x := lo.x if sx == 0 else hi.x - n + 1.0
			var y := lo.y if sy == 0 else hi.y - t + 1.0
			draw_rect(Rect2(x, y, n, t), col)
			var x2 := lo.x if sx == 0 else hi.x - t + 1.0
			var y2 := lo.y if sy == 0 else hi.y - n + 1.0
			draw_rect(Rect2(x2, y2, t, n), col)


func _draw_chart(mouse: Vector2) -> void:
	if UiSkin.atlas() != null:
		UiSkin.spr(self, "chart", CHART_RECT.position)
	else:
		draw_rect(CHART_RECT, Color(0.1, 0.09, 0.07, 0.95))
	UiSkin.panel(self, CHART_RECT, UiSkin.BRONZE, 1, "", false)
	_t(Vector2(CHART_RECT.position.x + 7, CHART_RECT.position.y + 11), "Etappe %d" % voy.stage, PAPER, 8)
	_t(Vector2(CHART_RECT.position.x, CHART_RECT.position.y + 11), "Stufe %d" % voy.level, GOLD, 8, HORIZONTAL_ALIGNMENT_RIGHT, CHART_RECT.size.x - 7.0)
	if voy.theme > 0:
		_t(Vector2(CHART_RECT.position.x + 7, CHART_RECT.position.y + 22), String(Voyage.THEMES[voy.theme]), Color(VIOLET, 0.95), 8)
		_tip(Rect2(CHART_RECT.position.x + 4, CHART_RECT.position.y + 14, 96, 10), Tips.theme(voy))
	_tip(Rect2(CHART_RECT.position.x, CHART_RECT.position.y, 64, 13), Tips.stage(voy))
	_tip(Rect2(CHART_RECT.end.x - 64, CHART_RECT.position.y, 64, 13), Tips.level(voy))
	var vis := voy.visible_cols()
	var planning := voy.phase == Voyage.Phase.PLAN
	var links_now: Array = voy.next_links() if (planning and voy.leg <= 0.0) else []

	# Wege: gestrichelte Pixellinien in Tintenfarbe, besuchte Strecke durchgezogen in Gold
	for c in Voyage.MILES:
		for i in (voy.map[c] as Array).size():
			var a := node_pos(c, i)
			for j in (voy.node_at(c, i)["links"] as Array):
				var b := node_pos(c + 1, int(j))
				var col := Color(0.52, 0.45, 0.32, 0.55)
				var dashed := true
				var thick := 1
				if c + 1 <= vis:
					col = Color(0.86, 0.78, 0.56, 0.85)
				if bool(voy.node_at(c, i).get("visited", false)) and bool(voy.node_at(c + 1, int(j)).get("visited", false)):
					col = Color(GOLD, 0.9)
					dashed = false
				if planning and c == voy.mile and i == voy.pos and int(j) == voy.route:
					col = GOLD
					dashed = false
					thick = 2
				_pix_line(a, b, col, dashed, thick)
	# Voraussichtliche Strecke dieser Fahrt: Gold bis zum letzten erreichten Knoten, gestrichelt bis zum Ziel dahinter
	if planning and (voy.route >= 0 or voy.leg > 0.0):
		var pp := voy.plan(_shown_maneuver())
		var arrivals: Array = pp["arrivals"]
		var from := node_pos(voy.mile, voy.pos)
		if voy.leg > 0.0 and voy.route >= 0:
			from = from.lerp(node_pos(voy.mile + 1, voy.route), voy.leg)
		for arr in arrivals:
			var to := node_pos(int(arr[0]), int(arr[1]))
			_pix_line(from, to, Color(GOLD, 0.9), false, 2)
			from = to
		if float(pp["miles"]) > 0.0 and float(pp["leg_after"]) > 0.0 and int(pp["route_after"]) >= 0:
			var base_col := voy.mile if arrivals.is_empty() else int(arrivals.back()[0])
			var base_i := voy.pos if arrivals.is_empty() else int(arrivals.back()[1])
			var tip := node_pos(base_col, base_i).lerp(node_pos(base_col + 1, int(pp["route_after"])), float(pp["leg_after"]))
			_pix_line(from, tip, Color(GOLD, 1.0), true, 2)
			tip = Vector2(roundf(tip.x), roundf(tip.y))
			draw_rect(Rect2(tip.x - 2, tip.y - 2, 5, 5), UiSkin.INK)
			draw_rect(Rect2(tip.x - 1, tip.y - 1, 3, 3), GOLD)

	# Knoten: kleine Pixelsymbole je Begegnung, Seefarbe für leere Knoten, Wegstein für besuchte
	_hover_node = []
	for c in range(0, Voyage.MILES + 1):
		for i in (voy.map[c] as Array).size():
			var nd := voy.node_at(c, i)
			var p := node_pos(c, i)
			var known := c <= vis
			var visited := bool(nd.get("visited", false))
			var r := Rect2(p.x - 4, p.y - 4, 9, 9)
			var enc := int(nd["enc"])
			if visited:
				UiSkin.spr(self, "seen", Vector2(p.x - 4, p.y - 4), Color(0.78, 0.72, 0.6))
			elif known:
				if enc >= 0:
					UiSkin.spr(self, "ic_" + String(Encounters.DATA[enc]["letter"]), Vector2(p.x - 4, p.y - 4))
				else:
					UiSkin.spr(self, "pip", Vector2(p.x - 3, p.y - 3), Sea.SEA_COLORS[int(nd["sea"])].lightened(0.1))
				if int(nd["hazard"]) != Sea.Hazard.NONE:
					UiSkin.spr(self, "haz", Vector2(p.x - 11, p.y - 2))
				if enc >= 0:
					_t(Vector2(r.end.x + 2, p.y + 3), String(Encounters.DATA[enc]["letter"]), Color(GOLD, 0.85), 8)
				elif bool(nd.get("cove", false)):  # Ankerbucht: sicherer Lagerplatz
					_t(Vector2(r.end.x + 2, p.y + 3), "A", Color("6aa3a0"), 8)
			else:
				draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), Color("2c261c"))
				draw_rect(Rect2(p.x, p.y, 1, 1), Color("5a5038"))
			if c == voy.mile and i == voy.pos:
				_brackets(p, 5, PAPER, 1)
			if voy.leg > 0.0 and c == voy.mile + 1 and i == voy.route:
				_brackets(p, 5, GOLD, 2)  # der Kurs ist zwischen zwei Knoten schon gesetzt
			if planning and c == voy.mile + 1 and links_now.has(i):
				var chosen := voy.route == i
				_brackets(p, 5, GOLD if chosen else PAPER, 2 if chosen else 1)
				_register(r.grow(4), "n%d" % i)
			if r.grow(5).has_point(mouse) and (known or visited):
				_hover_node = [c, i]
				if not (planning and c == voy.mile + 1 and links_now.has(i)):
					_brackets(p, 5, Color(PAPER, 0.55), 1)

	if not _hover_node.is_empty():  # Erklärung zum Knoten unter der Maus: Seegang, Gefahr, Begegnung
		_tip(Rect2(mouse - Vector2(1, 1), Vector2(2, 2)), Tips.node(voy, int(_hover_node[0]), int(_hover_node[1])))

	# Das Schiff selbst: zwischen zwei Knoten ein Punkt auf dem Weg
	if voy.leg > 0.0 and voy.route >= 0 and voy.mile < Voyage.MILES:
		var sp := node_pos(voy.mile, voy.pos).lerp(node_pos(voy.mile + 1, voy.route), voy.leg)
		sp = Vector2(roundf(sp.x), roundf(sp.y))
		draw_rect(Rect2(sp.x - 2, sp.y - 2, 5, 5), UiSkin.INK)
		draw_rect(Rect2(sp.x - 1, sp.y - 1, 3, 3), PAPER)

	# Einzelheiten zum Knoten unter der Maus, sonst zum gewählten Kurs
	var detail: Array = _hover_node
	if detail.is_empty() and planning and voy.route >= 0:
		detail = [voy.mile + 1, voy.route]
	var x := CHART_RECT.position.x + 7.0
	if detail.is_empty():
		var hint := "Kurs wählen: Knoten anklicken" if (planning and links_now.size() > 1) else ""
		_t(Vector2(x, CHART_INFO_Y), hint, GOLD, 8)
		return
	var nd2 := voy.node_at(int(detail[0]), int(detail[1]))
	if int(detail[0]) > vis and not bool(nd2.get("visited", false)):
		_t(Vector2(x, CHART_INFO_Y), "Meile %d: unbekannt" % int(detail[0]), DIM, 8)
		return
	var sea2 := int(nd2["sea"])
	var l1 := "Meile %d: " % int(detail[0])
	_t(Vector2(x, CHART_INFO_Y), l1, PAPER, 8)
	_t(Vector2(x + _ui.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, CHART_INFO_Y), Sea.SEA_NAMES[sea2], Sea.SEA_COLORS[sea2], 8)
	var hz := int(nd2["hazard"])
	var enc := int(nd2["enc"])
	var l2 := ""
	if hz != Sea.Hazard.NONE:
		l2 = String(Sea.HAZARD_NAMES[hz])
	var x2 := x
	if l2 != "":
		_t(Vector2(x2, CHART_INFO_Y + 9.0), l2, RED, 8)
		x2 += _ui.get_string_size(l2 + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	if enc >= 0 and not bool(nd2.get("visited", false)):
		_t(Vector2(x2, CHART_INFO_Y + 9.0), String(Encounters.DATA[enc]["name"]), GOLD, 8)
	elif l2 == "":
		_t(Vector2(x2, CHART_INFO_Y + 9.0), "keine Gefahr", DIM, 8)


## Bricht jede Zeile [Text, Farbe, Tooltip?] an Wortgrenzen so um, dass sie in w Pixel passt; Folgezeilen erben Farbe und Tooltip.
## Ohne das ragen lange Zeilen (große Zahlen, lange Namen) aus ihrem Feld heraus.
func _fit_lines(lines: Array, w: float, size: int) -> Array:
	var out: Array = []
	for line in lines:
		var rows: PackedStringArray = _fit_rows(String(line[0]), w, size)
		for k in rows.size():
			var row: Array = line.duplicate()
			row[0] = rows[k] if k == 0 else "  " + rows[k]
			out.append(row)
	return out


func _fit_rows(s: String, w: float, size: int) -> PackedStringArray:
	var rows := PackedStringArray()
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if cur != "" and _ui.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
			rows.append(cur)
			cur = word
		else:
			cur = t
	rows.append(cur)
	return rows


## Das Manöver für die Vorschau: der Knopf unter der Maus, sonst die gewählten Stellungen.
func _shown_maneuver() -> Dictionary:
	if not _hover_dial.is_empty():
		return _with_dial(int(_hover_dial[0]), int(_hover_dial[1]))
	return voy.maneuver()


## Die Vorschau in wenigen Zeilen: Strecke, Ankunft, Proviant, Rumpf, Gefahren, Warnungen.
func _preview_lines(d: Dictionary) -> Array:
	var out: Array = []
	if voy.route_missing(d):
		out.append(["Kurs wählen: Knoten rechts anklicken", GOLD])
	var p := voy.plan(d)
	var miles := float(p["miles"])
	var want := float(p["want"])
	var arr: Array = p["arrivals"]
	if want == 0.0:
		out.append(["Rast: das Schiff bleibt liegen", DIM])
	elif miles == 0.0:
		out.append(["Es treibt nur: zu wenig Hände!", RED, Tips.crewing(float(p["ratio"]))])
	else:
		out.append(["+%s Meilen%s" % [Voyage.fmt(miles), "" if miles >= want - 0.05 else " (Hände fehlen)"], PAPER if miles >= want - 0.05 else GOLD, Tips.miles(voy, p)])
		var target := ""
		if arr.is_empty():
			target = "noch kein Knoten (%d %%)" % roundi(float(p["leg_after"]) * 100.0)
		else:
			var last: Array = arr.back()
			var nd := voy.node_at(int(last[0]), int(last[1]))
			target = "Meile %d" % int(last[0])
			if int(nd["hazard"]) != Sea.Hazard.NONE:
				target += " (%s)" % Sea.HAZARD_NAMES[int(nd["hazard"])]
			if String(p["stop"]) == "fork":
				target += ", Gabelung: Halt"
			elif String(p["stop"]) == "encounter" or String(p["stop"]) == "end":
				target += ", Halt"
			elif float(p["leg_after"]) > 0.0:
				target += " + %d %%" % roundi(float(p["leg_after"]) * 100.0)
		out.append(["→ " + target, DIM, Tips.arrival(voy, p)])
	var left := voy.proviant - int(p["proviant"])
	var to_harbor := voy.harbor_distance()
	out.append(["Proviant −%d, dann %d · Hafen %s" % [int(p["proviant"]), maxi(left, 0), Voyage.fmt(to_harbor)], RED if float(left) < to_harbor + 1.0 else PAPER, Tips.food(voy, p)])
	var after := float(p["hull_after"])
	var now := roundi(voy.hull)
	if after <= 0.0:
		out.append(["Rumpf: das Schiff sinkt!", RED])
	elif roundi(after) == now:
		out.append(["Rumpf bleibt %d" % now, GREEN])
	else:
		var drop := now - roundi(after)
		out.append(["Rumpf %d → %d" % [now, roundi(after)], GREEN if drop <= 0 else (GOLD if drop < 15 else RED)])
	out.back().append(Tips.hull(voy, p))  # die Rumpfzeile erklärt sich beim Darüberfahren
	for row in p["rows"]:
		var hz := int(row["hazard"])
		if hz == Sea.Hazard.NONE:
			continue
		var mit := float(row["mit"])
		var col := GREEN if mit >= 0.7 else (GOLD if mit >= 0.3 else RED)
		var text := "%s −%d" % [Sea.HAZARD_NAMES[hz], roundi(float(row["h_dmg"]))]
		if float(row["h_loot"]) > 0.0:
			text += ", Beute −%d" % roundi(float(row["h_loot"]))
		if float(row["h_over"]) > 0.0:
			text += ", über Bord %d %%" % roundi(float(row["h_over"]) * 100.0)
		out.append([text, col, Tips.hazard(voy, hz, row)])
	var keep := 1.0
	for row in p["rows"]:
		keep *= 1.0 - float(row["wash"])
	var wash := roundi((1.0 - keep) * 100.0)
	if wash >= 8:
		out.append(["Über Bord (See): %d %%" % wash, GOLD if wash < 20 else RED, Tips.wash(voy, wash)])
	var ratio := float(p["ratio"])
	if ratio < 1.0:
		out.append(["Besetzung %d %%" % roundi(ratio * 100.0), RED if ratio < 0.6 else GOLD, Tips.crewing(ratio)])
	var tired: Array = p["tired"]
	if not tired.is_empty():
		var names := ", ".join(PackedStringArray(tired.slice(0, 2)))
		if tired.size() > 2:
			names += " …"
		out.append(["Erschöpft: %s" % names, RED, Tips.tired(tired)])
	return out


## Linkes Feld: nur da, wenn es etwas zu entscheiden gibt (Planung der Fahrt, Begegnung oder Schlacht).
func _draw_preview() -> void:
	var d := _shown_maneuver()
	var planning := voy.phase == Voyage.Phase.PLAN
	if voy.encounter < 0 and not planning:
		return
	var box := PREVIEW_RECT
	var plan_lines: Array = []
	if voy.encounter < 0:
		plan_lines = _fit_lines(_preview_lines(d), box.size.x - 18.0, 8)
		box.size.y = minf(box.size.y, 40.0 + plan_lines.size() * 10.5)  # so hoch wie der Inhalt
	elif voy.battle.is_empty():
		var text_h := _lore.get_multiline_string_size(String(Encounters.DATA[voy.encounter]["desc"]), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 12.0, 9).y
		box.size.y = minf(box.size.y, 40.0 + text_h)
	_panel(box)
	var x := box.position.x + 9.0
	var y := box.position.y + 17.0
	var w := box.size.x - 18.0
	if voy.battle.is_empty() or voy.encounter < 0:
		UiSkin.rule(self, box.position.x + 8.0, box.end.x - 8.0, y + 4.0, UiSkin.BRONZE, false)
	if voy.encounter >= 0 and not voy.battle.is_empty():
		_draw_battle_panel(x, y, w)
		return
	if voy.encounter >= 0:
		var def: Dictionary = Encounters.DATA[voy.encounter]
		_t(Vector2(x, y), String(def["name"]), GOLD, 10)
		var desc := String(def["desc"])
		draw_multiline_string_outline(_lore, Vector2(x, y + 14.0), desc, HORIZONTAL_ALIGNMENT_LEFT, w, 9, 9, 3, INK)
		draw_multiline_string(_lore, Vector2(x, y + 14.0), desc, HORIZONTAL_ALIGNMENT_LEFT, w, 9, 9, PAPER)
		return
	var preview := not _hover_dial.is_empty() and (d["dials"] as Array) != (voy.maneuver()["dials"] as Array)
	_t(Vector2(x, y), String(d["name"]) + ("  (Vorschau)" if preview else ""), GOLD, 10)
	y += 2.0
	for line in plan_lines:
		y += 10.5
		if y > box.end.y - 5.0:
			break
		_t(Vector2(x, y), String(line[0]), line[1], 8)
		if line.size() > 2:
			_tip(Rect2(x - 3.0, y - 8.0, w + 6.0, 10.5), line[2])


## Seeschlacht links: Zustand des Gegners und sein angekündigter nächster Zug.
func _draw_battle_panel(x: float, y: float, w: float) -> void:
	var b := voy.battle
	var def := Battle.enemy_def(voy)
	_t(Vector2(x, y), String(def["name"]), GOLD, 10)
	_t(Vector2(x, y), "Runde %d/%d" % [int(b["round"]), Battle.ROUNDS], DIM, 8, HORIZONTAL_ALIGNMENT_RIGHT, w)
	_tip(Rect2(x - 6.0, y - 12.0, w + 12.0, 48.0), Tips.battle_enemy(voy))
	var ehull := maxf(float(b["ehull"]), 0.0)
	_t(Vector2(x, y + 14.0), "Gegner-Rumpf  %d / %d" % [roundi(ehull), roundi(float(b["ehull_max"]))], PAPER, 8)
	_bar(x, y + 18.0, w, 4.0, ehull / float(b["ehull_max"]), RED)
	_t(Vector2(x, y + 36.0), "%s an Bord: %d" % [def["crew_name"], int(b["ecrew"])], PAPER, 8)
	_t(Vector2(x, y + 53.0), "Nächster Zug des Gegners:", DIM, 8)
	var it := Battle.intent_info(voy)
	_t(Vector2(x, y + 66.0), String(it["name"]), RED, 10)
	_t(Vector2(x, y + 77.0), String(it["desc"]), PAPER, 8)
	var hint := String(it["hint"])
	draw_multiline_string_outline(_ui, Vector2(x, y + 88.0), hint, HORIZONTAL_ALIGNMENT_LEFT, w, 8, 4, 3, INK)
	draw_multiline_string(_ui, Vector2(x, y + 88.0), hint, HORIZONTAL_ALIGNMENT_LEFT, w, 8, 4, DIM)


## Seeschlacht: bis zu sieben Taktikkarten in einer Reihe.
func _draw_battle_cards(active: bool) -> void:
	var opts: Array = Encounters.DATA[voy.encounter]["options"]
	var mouse := get_local_mouse_position()
	var gap := 4.0
	var w := (468.0 - gap * float(opts.size() - 1)) / float(opts.size())
	for i in opts.size():
		var opt: Dictionary = opts[i]
		var r := Rect2(STRAT_X0 + float(i) * (w + gap), STRAT_Y, w, STRAT_H)
		var ok := Encounters.available(voy, opt)
		var hover := active and ok and r.has_point(mouse)
		_card(r, UiSkin.State.HOVER if hover else (UiSkin.State.NORMAL if (active and ok) else UiSkin.State.DISABLED), 1.0 if active else 0.6)
		_t(r.position + Vector2(5, 15), String(opt["label"]), GOLD if (active and ok) else DIM, 9, HORIZONTAL_ALIGNMENT_LEFT, w - 9.0)
		var lines: Array = Battle.lines(voy, String(opt["tactic"]))
		for k in lines.size():
			var text := String(lines[k])
			var col := DIM
			if text.begins_with("du:") or text.begins_with("Rumpf −") or text.begins_with("Kraft −") or text.begins_with("Tod ") or text.begins_with("Pulver −"):
				col = RED if (active and ok) else DIM
			elif text.begins_with("Rumpf +"):
				col = GREEN if (active and ok) else DIM
			elif k == 0:
				col = PAPER if (active and ok) else DIM
			_t(r.position + Vector2(5, 29 + k * 11), text, col, 8, HORIZONTAL_ALIGNMENT_LEFT, w - 9.0)
		_t(r.position + Vector2(r.size.x - 10, r.size.y - 5), str(i + 1), DIM, 8)
		if active and ok:
			_register(r, "e%d" % i)


## Das dunkle Band unten, wie bei Darkest Dungeon: darin sitzen Regler, Schaltflächen und die Mannschaft.
func _draw_band() -> void:
	UiSkin.fill_tile(self, Rect2(0, BAND_Y, Waves.VIEW_W, Waves.VIEW_H - BAND_Y), "tile_band", Color(1, 1, 1, 0.97))
	draw_rect(Rect2(0, BAND_Y, Waves.VIEW_W, 1), UiSkin.INK)
	draw_rect(Rect2(0, BAND_Y + 1, Waves.VIEW_W, 1), Color(UiSkin.BRONZE_HI, 0.8))
	draw_rect(Rect2(0, BAND_Y + 2, Waves.VIEW_W, 1), Color(UiSkin.BRONZE, 0.9))
	draw_rect(Rect2(0, BAND_Y + 3, Waves.VIEW_W, 1), UiSkin.INK)
	# kleine Nieten in der Kante
	for k in range(12, 480, 48):
		draw_rect(Rect2(k, BAND_Y + 1, 2, 2), UiSkin.BRONZE_HI)
		draw_rect(Rect2(k + 1, BAND_Y + 2, 1, 1), UiSkin.BRONZE_LO)


## Drei Reglergruppen für das Manöver: Segel, Ruder, Küste. Auf den Knöpfen steht nur die Stellung; was sie
## bringt und kostet, zeigt ein Hinweis beim Darüberfahren, die genauen Folgen die Vorschau links.
## Segel und Ruder beide auf "aus" ist Beidrehen.
func _draw_dials() -> void:
	var active := voy.phase == Voyage.Phase.PLAN
	var cur := [voy.sail_set, voy.oars_set, voy.coast_set]
	var rest := Strategy.is_rest(voy.sail_set, voy.oars_set)
	for dl in 3:
		var x0 := STRAT_X0 + dl * DIAL_STEP
		var off := dl == 2 and rest  # beim Beidrehen zählt die Küste nicht
		_t(Vector2(x0, DIAL_Y - 5), String(Strategy.DIAL_NAMES[dl]), Color(DIM, 0.6) if off else DIM, 8)
		var hovering := not _hover_dial.is_empty() and int(_hover_dial[0]) == dl
		for lv in 3:
			var r := dial_rect(dl, lv)
			var ok := voy.can_choose(_with_dial(dl, lv))
			var sel := int(cur[dl]) == lv
			var hover := active and ok and hovering and int(_hover_dial[1]) == lv
			var bstate := UiSkin.State.NORMAL
			if sel and not off:
				bstate = UiSkin.State.SELECTED
			elif hover:
				bstate = UiSkin.State.HOVER
			elif not (active and ok) and not sel:
				bstate = UiSkin.State.DISABLED
			UiSkin.button(self, r, bstate)
			var col := GOLD if (sel and not off) else (PAPER if (ok and not off) else Color(DIM, 0.7))
			_t(r.position + Vector2(0, 11), String(Strategy.LEVEL_NAMES[dl][lv]), col, 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			if active and ok:
				_register(r, "d%d%d" % [dl, lv])
	_draw_dial_tip()


## Hinweis zur Stellung unter der Maus: Vorteil und Nachteil, in einem schmalen Kasten über dem Knopf.
func _draw_dial_tip() -> void:
	if _hover_dial.is_empty():
		return
	var dl := int(_hover_dial[0])
	var lv := int(_hover_dial[1])
	if dl == 2 and Strategy.is_rest(voy.sail_set, voy.oars_set):
		return
	var info: Dictionary = Strategy.INFO[dl][lv]
	var r := dial_rect(dl, lv)
	var w := 150.0
	var x := clampf(r.position.x + r.size.x * 0.5 - w * 0.5, 4.0, Waves.VIEW_W - w - 4.0)
	var box := Rect2(x, DIAL_Y - 40.0, w, 32.0)
	UiSkin.panel(self, box, UiSkin.BRONZE, 0, "tile_stone")
	_t(box.position + Vector2(6, 13), "+ " + String(info["plus"]), GREEN, 8)
	_t(box.position + Vector2(6, 25), "− " + String(info["minus"]), RED, 8)


## Im Hafen: sechs Aktionen in einer Reihe wie die Fahrweisen. Man bleibt, bis man ablegt.
func _draw_harbor_cards(active: bool) -> void:
	var opts: Array = Encounters.DATA[voy.encounter]["options"]
	var mouse := get_local_mouse_position()
	var gap := 4.0
	var cw := (468.0 - gap * float(opts.size() - 1)) / float(opts.size())  # sieben Karten teilen sich die Breite wie bei der Seeschlacht
	for i in opts.size():
		var opt: Dictionary = opts[i]
		var r := Rect2(STRAT_X0 + float(i) * (cw + gap), STRAT_Y, cw, STRAT_H)
		var done := Encounters.used(voy, opt)
		var ok := Encounters.available(voy, opt)
		var hover := active and ok and r.has_point(mouse)
		_card(r, UiSkin.State.HOVER if hover else (UiSkin.State.NORMAL if ok else UiSkin.State.DISABLED), 1.0 if active else 0.6)
		_t(r.position + Vector2(5, 15), String(opt["label"]), GOLD if ok else DIM, 9, HORIZONTAL_ALIGNMENT_LEFT, cw - 9.0)
		var lines: Array = Encounters.card_lines(voy, opt)
		for k in lines.size():
			var text := String(lines[k])
			var col := DIM
			if text.begins_with("Beute −") or text.begins_with("Proviant −"):
				col = RED if not ok else PAPER
			elif text.contains("+"):
				col = GREEN if ok else DIM
			_t(r.position + Vector2(5, 29 + k * 11), text, col, 8, HORIZONTAL_ALIGNMENT_LEFT, cw - 9.0)
		if done:
			_t(r.position + Vector2(5, r.size.y - 6), "erledigt", DIM, 8)
		elif not ok and String(opt.get("need", "")) == "recruit":
			_t(r.position + Vector2(5, r.size.y - 6), "kein Platz", RED, 8)
		elif not ok and opt.has("slot") and voy._harbor_spins >= Voyage.SLOT_HARBOR_SPINS:
			_t(r.position + Vector2(5, r.size.y - 6), "keine Drehs", RED, 8)
		elif not ok:
			_t(r.position + Vector2(5, r.size.y - 6), "zu teuer", RED, 8)
		_t(r.position + Vector2(r.size.x - 12, r.size.y - 6), str(i + 1), DIM, 8)
		if not opt.has("shop"):
			_tip(r, Tips.option(voy, voy.encounter, opt))
		if active and ok:
			_register(r, "e%d" % i)


func _draw_encounter_cards() -> void:
	var active := voy.phase == Voyage.Phase.ENCOUNTER
	if Encounters.is_harbor(voy.encounter):
		_draw_harbor_cards(active)
		return
	if Encounters.is_battle(voy.encounter):
		_draw_battle_cards(active)
		return
	var opts: Array = Encounters.DATA[voy.encounter]["options"]
	var mouse := get_local_mouse_position()
	for i in opts.size():
		var opt: Dictionary = opts[i]
		var r := encounter_rect(i)
		var ok := Encounters.available(voy, opt)
		var hover := active and ok and r.has_point(mouse)
		_card(r, UiSkin.State.HOVER if hover else (UiSkin.State.NORMAL if ok else UiSkin.State.DISABLED))
		_t(r.position + Vector2(7, 16), String(opt["label"]), GOLD if ok else DIM, 10, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 14.0)
		var lines: Array = Encounters.card_lines(voy, opt)
		for k in lines.size():
			var col := PAPER
			var text := String(lines[k])
			if k == 0 and opt.has("fight"):
				var ch := Encounters.chance(voy, opt)
				col = GREEN if ch >= 0.7 else (GOLD if ch >= 0.45 else RED)
			elif text.begins_with("Kosten") or text.begins_with("Verlust"):
				col = RED if k > 0 else GOLD
			elif text.begins_with("Sieg") or text.begins_with("Proviant +") or text.begins_with("Funde"):
				col = GREEN
			else:
				col = DIM if k > 0 else PAPER
			_t(r.position + Vector2(7, 30 + k * 11), text, col, 8, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 14.0)
		if not ok:
			_t(r.position + Vector2(7, r.size.y - 6), "nicht möglich", RED, 8)
		_t(r.position + Vector2(r.size.x - 12, r.size.y - 6), str(i + 1), DIM, 8)
		_tip(r, Tips.option(voy, voy.encounter, opt))
		if ok and active:
			_register(r, "e%d" % i)


## Schaltfläche "Lager" über "Auslaufen": zeigt auch, warum es gerade nicht geht.
func _draw_lager_button(mouse: Vector2) -> void:
	if voy.phase != Voyage.Phase.PLAN or voy.camping or voy.leg > 0.0 or voy.mile < 1 or voy.mile >= Voyage.MILES:
		return
	var ok := voy.can_camp()
	var hover := ok and LAGER_RECT.has_point(mouse)
	UiSkin.button(self, LAGER_RECT, UiSkin.State.HOVER if hover else (UiSkin.State.NORMAL if ok else UiSkin.State.DISABLED))
	_t(Vector2(LAGER_RECT.position.x, LAGER_RECT.position.y + 7), "Lager (L)", GOLD if ok else Color(DIM, 0.7), 7, HORIZONTAL_ALIGNMENT_CENTER, LAGER_RECT.size.x)
	if ok:
		_register(LAGER_RECT, "lager")
	_tip(LAGER_RECT, Tips.camp_button(voy))


func _draw_go() -> void:
	if voy.phase != Voyage.Phase.PLAN and not (voy.phase == Voyage.Phase.RESOLVE and voy.encounter < 0):
		return
	var ready := voy.can_confirm()
	var r := GO_RECT
	var label := "Beidrehen" if Strategy.is_rest(voy.sail_set, voy.oars_set) else "Auslaufen"
	if voy.phase == Voyage.Phase.RESOLVE:
		label = "…"
	elif not ready:
		label = "Kurs wählen"
	var hover := ready and r.has_point(get_local_mouse_position())
	UiSkin.button(self, r, UiSkin.State.HOVER if (hover and ready) else (UiSkin.State.SELECTED if ready else UiSkin.State.DISABLED))
	_t(Vector2(r.position.x, r.position.y + 14), label, GOLD if ready else DIM, 10, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if ready:
		_register(r, "go")


func _bond_color(type: int) -> Color:
	return GOLD if type == Voyage.Bond.BROTHER else (RED if type == Voyage.Bond.RIVAL else BLUE)


func _draw_cards(mouse: Vector2) -> void:
	# Wer unter der Maus liegt, dessen Partner (Bruder/Rivale) wird farbig umrandet
	var focus := hover_crew
	if focus == null and card_at(mouse) >= 0:
		focus = voy.crew[card_at(mouse)]
	for i in voy.crew.size():
		var m := voy.crew[i]
		var r := card_rect(i)
		var border := Color(DIM, 0.3)
		var partners := voy.bond_partners(m)
		var bond_border := Color(0, 0, 0, 0)
		if focus != null and focus != m:
			for p in voy.bond_partners(focus):
				if p["other"] == m:
					bond_border = _bond_color(int(p["type"]))
		var status := ""
		var scol := PAPER
		match m.state:
			CrewMember.State.ABOARD:
				var st := Stations.slot_station(m.slot)
				status = Stations.NAMES[st]
				scol = Stations.COLORS[st]
			CrewMember.State.OVERBOARD:
				status = "ÜBER BORD"
				scol = RED
				border = RED
			CrewMember.State.DEAD:
				status = "ertrunken"
				scol = DIM
		var dead := m.state == CrewMember.State.DEAD
		if voy.phase == Voyage.Phase.RESCUE and voy.rescuer == m:
			status = "Retter"
			scol = GREEN
			border = GREEN
		if voy.selected == m:
			border = Color("f2d36b")
		elif not dead and r.has_point(mouse) and voy.phase != Voyage.Phase.RESOLVE:
			border = PAPER
		var chosen := voy.selected == m or (voy.phase == Voyage.Phase.RESCUE and voy.rescuer == m)
		var bstate := UiSkin.State.NORMAL
		if dead:
			bstate = UiSkin.State.DISABLED
		elif chosen:
			bstate = UiSkin.State.SELECTED
		elif border == PAPER:
			bstate = UiSkin.State.HOVER
		var col := UiSkin.accent(bstate)
		if border == RED and not dead:
			col = RED.darkened(0.25)
		elif border == GREEN:
			col = GREEN.darkened(0.2)
		if bond_border.a > 0.0 and not dead:
			col = bond_border
			bstate = UiSkin.State.HOVER
		_card(r, bstate, 1.0, col)
		UiSkin.portrait(self, r.position + Vector2(5, 4), m.look, Color(0.45, 0.45, 0.5) if dead else (Color(0.8, 0.8, 0.95) if m.kraft < 40.0 and m.state == CrewMember.State.ABOARD else Color.WHITE))
		if not dead and not partners.is_empty():
			# Bruder / Rivale / Gefährte als kleines Pixelsymbol oben rechts
			var bt := int(partners[0]["type"])
			var bname := "bond_b" if bt == Voyage.Bond.BROTHER else ("bond_r" if bt == Voyage.Bond.RIVAL else "bond_c")
			var bsz := UiSkin.spr_size(bname)
			var gone := (partners[0]["other"] as CrewMember).state == CrewMember.State.DEAD
			UiSkin.spr(self, bname, Vector2(r.end.x - bsz.x - 4.0, r.position.y + 4.0), Color(0.55, 0.55, 0.6) if gone else Color.WHITE)
		_t(r.position + Vector2(19, 12), m.display_name, DIM if dead else _name_color(m), 9)
		_t(r.position + Vector2(5, 25), status, scol, 8)
		if not dead and m.state == CrewMember.State.ABOARD and m.fatigue_stage() > 0:  # z / zz / zzz: müde, erschöpft, am Ende
			_t(Vector2(r.end.x - 24.0, r.position.y + 25.0), "z".repeat(m.fatigue_stage()), _kraft_col(m.kraft), 8, HORIZONTAL_ALIGNMENT_RIGHT, 20.0)
		if not dead and m.state == CrewMember.State.ABOARD:
			var bw := r.size.x - 10.0
			var kcol := _kraft_col(m.kraft)
			UiSkin.mini_bar(self, r.position.x + 5, r.end.y - 11, bw, m.kraft / 100.0, kcol)
			var scolr := VIOLET if m.stress < 70.0 else RED
			UiSkin.mini_bar(self, r.position.x + 5, r.end.y - 6, bw, clampf(m.stress, 0.0, 100.0) / 100.0, scolr)


## Kleine Zeile über der Mannschaft: führt in die Mannschaftsansicht.
func _draw_crew_link(mouse: Vector2) -> void:
	var can := voy.phase == Voyage.Phase.PLAN or voy.phase == Voyage.Phase.ENCOUNTER
	if not can or voy.ended:
		return
	for tab in [[CREW_LINK, "Crew", "kopen"], [SHIP_LINK, "Schiff", "sopen"]]:
		var r: Rect2 = tab[0]
		var hover := r.has_point(mouse)
		UiSkin.button(self, r, UiSkin.State.HOVER if hover else UiSkin.State.NORMAL)
		_t(Vector2(r.position.x, r.position.y + 9), String(tab[1]), PAPER if hover else DIM, 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		_register(r, String(tab[2]))


func _draw_rescue() -> void:
	var s := voy.swimmer
	if s == null:
		return
	var r := Rect2(156, 14, 182, 100)
	UiSkin.panel(self, r, Color("8c2d2d"), 2, "tile_stone")
	_t(Vector2(r.position.x, 31), "Mann über Bord!", RED, 12, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, _lore)
	UiSkin.rule(self, r.position.x + 10.0, r.end.x - 10.0, 34.0, Color("8c2d2d"), false)
	_t(Vector2(r.position.x + 8, 43), "%s kämpft in den Wellen." % s.display_name, PAPER, 9)
	var rr := voy.rescuer
	if rr == null:
		_t(Vector2(r.position.x + 8, 55), "Niemand kann das Seil werfen.", RED, 9)
	else:
		var chance := roundi(voy.rescue_chance(rr) * 100.0)
		_t(Vector2(r.position.x + 8, 55), "Retter: %s" % rr.display_name, GREEN, 9)
		_t(Vector2(r.position.x + 98, 55), "Aussicht %d %%" % chance, GREEN if chance >= 70 else (GOLD if chance >= 45 else RED), 9)
	var c := voy.rescue_costs()
	var cost_text := "Kosten: Proviant −%d" % int(c["proviant"])
	if int(c["hull"]) > 0:
		cost_text += ", Rumpf −%d" % int(c["hull"])
	cost_text += ", Retter −%d Kraft" % int(c["kraft"])
	_t(Vector2(r.position.x + 8, 67), cost_text, DIM, 8)
	_t(Vector2(r.position.x + 8, 77), "Scheitert es: Mut −12. Zurücklassen: Mut −20.", DIM, 8)
	var b1 := Rect2(r.position.x + 6, r.position.y + 70, 82, 22)
	var b2 := Rect2(r.position.x + 94, r.position.y + 70, 82, 22)
	for b in [[b1, "Seil werfen", "rescue", rr != null], [b2, "Zurücklassen", "abandon", true]]:
		var rect: Rect2 = b[0]
		var enabled: bool = b[3]
		UiSkin.button(self, rect, UiSkin.State.HOVER if (enabled and rect.has_point(get_local_mouse_position())) else (UiSkin.State.NORMAL if enabled else UiSkin.State.DISABLED))
		_t(Vector2(rect.position.x, rect.position.y + 15), String(b[1]), PAPER if enabled else DIM, 9, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		if enabled:
			_register(rect, String(b[2]))
	_t(Vector2(r.position.x - 10.0, r.end.y + 12), "Anderen Mann anklicken: Retter wechseln.", DIM, 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20.0)


# --- Hauptmenü ----------------------------------------------------------------

## Titelbild über dem ruhigen Meer: hier laufen die Lieder mit Gesang.
func _draw_menu(mouse: Vector2) -> void:
	_btns.clear()
	draw_rect(Rect2(0, 0, Waves.VIEW_W, Waves.VIEW_H), Color(0.02, 0.03, 0.05, 0.55))
	UiSkin.vignette(self, 2)
	# Zierleisten oben und unten: Knotenwerk zwischen Bronzelinien
	UiSkin.knot_band(self, 0, 480, 10, Color(1, 1, 1, 0.55))
	UiSkin.knot_band(self, 0, 480, 313, Color(1, 1, 1, 0.55))
	# Titel mit hartem Pixel-Schatten (zwei Stufen, versetzt um ganze Pixel)
	_t(Vector2(2, 58), "Halt Kurs", UiSkin.INK, 34, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	_t(Vector2(1, 57), "Halt Kurs", UiSkin.BRONZE_LO, 34, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	_t(Vector2(0, 54), "Halt Kurs", GOLD, 34, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	UiSkin.title_rule(self, 240.0, 120.0, 66.0)
	_t(Vector2(0, 85), "Ein Spiel für Männer, die es besser wissen müssten.", Color(DIM, 0.9), 9, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	var entries: Array = []
	if menu_can_continue:
		entries.append(["Fahrt fortsetzen", "mc"])
		entries.append(["Neue Fahrt (verwirft die laufende)" if not menu_new_armed else "Wirklich neu beginnen?", "mn"])
	else:
		entries.append(["Fahrt beginnen", "mc"])
	entries.append(["Einstellungen", "mo"])
	entries.append(["Gedenkstein", "mg"])
	entries.append(["Beenden", "mq"])
	# Wie im Menü von Darkest Dungeon: nur Schrift, das Gewählte leuchtet golden zwischen zwei Rauten.
	var top := 196.0 - maxf(entries.size() - 4, 0) * 20.0  # mit laufender Fahrt fünf Einträge: höher, damit unten Platz bleibt
	for i in entries.size():
		var r := Rect2(150, top + i * 20, 180, 18)
		var hover := r.has_point(mouse)
		var col := GOLD if hover else (PAPER if i == 0 else Color(DIM, 0.9))
		_t(Vector2(r.position.x, r.position.y + 13), String(entries[i][0]), col, 11, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if hover:
			var half := _ui.get_string_size(String(entries[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5 + 10.0
			for sx in [-1.0, 1.0]:
				UiSkin.spr(self, "sel", Vector2(r.position.x + r.size.x * 0.5 + sx * half - 3.0, r.position.y + 5.0))
		_register(r, String(entries[i][1]))
	if _legacy.is_empty():
		_legacy = Voyage.legacy_for(Persist.load_memorial())
	if not (_legacy["lines"] as Array).is_empty():
		var legacy_text := "Vermächtnis: " + "  ·  ".join(PackedStringArray(_legacy["lines"]))  # unter den Einträgen, bricht um
		draw_multiline_string_outline(_ui, Vector2(20, 289), legacy_text, HORIZONTAL_ALIGNMENT_CENTER, 440.0, 8, 2, 3, INK)
		draw_multiline_string(_ui, Vector2(20, 289), legacy_text, HORIZONTAL_ALIGNMENT_CENTER, 440.0, 8, 2, Color(VIOLET, 0.85))
	_t(Vector2(0, 309), "Enter: los   ·   M: Ton an/aus   ·   +/−: Lautstärke   ·   F11: Vollbild", Color(DIM, 0.8), 8, HORIZONTAL_ALIGNMENT_CENTER, 480.0)


## Einstellungen: nur Schrift, links die Namen, rechts die Werte mit − und +.
func _draw_settings(mouse: Vector2) -> void:
	_btns.clear()
	draw_rect(Rect2(0, 0, Waves.VIEW_W, Waves.VIEW_H), Color(0.02, 0.03, 0.05, 0.88))
	UiSkin.vignette(self, 1)
	UiSkin.knot_band(self, 0, 480, 10, Color(1, 1, 1, 0.55))
	UiSkin.knot_band(self, 0, 480, 313, Color(1, 1, 1, 0.55))
	_t(Vector2(1, 63), "Einstellungen", UiSkin.BRONZE_LO, 22, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	_t(Vector2(0, 62), "Einstellungen", GOLD, 22, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	UiSkin.rule(self, 150.0, 330.0, 73.0, UiSkin.BRONZE, true)
	var rows: Array = []
	if music != null:
		rows.append(["Musik", "%d dB" % roundi(music.volume_db), "tm0", "tm1"])
		rows.append(["Ton", "aus" if music.muted else "an", "tmute", "tmute"])
	rows.append(["Effekte", "%+d dB" % roundi(Settings.sfx_db), "te0", "te1"])
	rows.append(["Vollbild beim Start", "an" if Settings.fullscreen else "aus", "tfull", "tfull"])
	rows.append(["Hilfe beim Start", "an" if Settings.help_at_start else "aus", "thelp", "thelp"])
	rows.append(["Kämpfe", "schnell" if Settings.auto_combat else "von Hand", "tfight", "tfight"])
	rows.append(["Kampfbild", "voll" if Settings.stage_fx != 0 else "schlicht", "tstage", "tstage"])
	for i in rows.size():
		var y := 98.0 + float(i) * 24.0
		_t(Vector2(120, y + 12), String(rows[i][0]), PAPER, 11)
		var minus := Rect2(274, y, 18, 18)
		var plus := Rect2(380, y, 18, 18)
		var both := String(rows[i][2]) == String(rows[i][3])
		var val := Rect2(274, y, 124, 18) if both else Rect2(296, y, 80, 18)
		_t(Vector2(val.position.x, y + 13), String(rows[i][1]), GOLD if val.has_point(mouse) else PAPER, 11, HORIZONTAL_ALIGNMENT_CENTER, val.size.x)
		if both:
			_register(val, String(rows[i][2]))
		else:
			for pair in [[minus, "−", rows[i][2]], [plus, "+", rows[i][3]]]:
				var br: Rect2 = pair[0]
				var hv := br.has_point(mouse)
				UiSkin.button(self, br, UiSkin.State.HOVER if hv else UiSkin.State.NORMAL)
				_t(Vector2(br.position.x, br.position.y + 13), String(pair[1]), PAPER, 11, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
				_register(br, String(pair[2]))
	var back := Rect2(150, 98.0 + float(rows.size()) * 24.0 + 14.0, 180, 18)
	var hb := back.has_point(mouse)
	_t(Vector2(back.position.x, back.position.y + 13), "Zurück", GOLD if hb else PAPER, 11, HORIZONTAL_ALIGNMENT_CENTER, back.size.x)
	_register(back, "tback")
	_t(Vector2(0, 309), "Esc: zurück", Color(DIM, 0.8), 8, HORIZONTAL_ALIGNMENT_CENTER, 480.0)

# --- Schiff und Werft ---------------------------------------------------------

func ship_active() -> bool:
	return voy != null and (ship_open or voy.shop_open)


func toggle_ship() -> void:
	if voy == null:
		return
	if voy.shop_open:
		voy.close_shop()
		return
	if ship_open:
		ship_open = false
		return
	if not voy.ended and (voy.phase == Voyage.Phase.PLAN or voy.phase == Voyage.Phase.ENCOUNTER):
		ship_open = true
		crew_open = false
		_help = false


## Die sieben Plätze des Schiffes und was darauf sitzt; im Hafen rechts das Angebot (Reiter Gegenstände) oder die
## Schmiede und Kampfschule, sonst die Schiffswerte. Die Farbe zeigt die Seltenheit.
func _draw_ship_view(mouse: Vector2) -> void:
	_btns.clear()
	_tips.clear()
	var shopping := voy.shop_open
	draw_rect(Rect2(0, 0, Waves.VIEW_W, Waves.VIEW_H), Color(0, 0, 0, 0.88))
	var panel := Rect2(14, 8, 452, 304)
	UiSkin.panel(self, panel, UiSkin.BRONZE, 2, "tile_stone")
	var tab := voy.werft_tab if shopping else 0
	var titles := ["Werft", "Schmiede", "Ausrüstung", "Rüstkammer"]
	_t(Vector2(24, 34), String(titles[tab]) if shopping else "Das Schiff", GOLD, 16, HORIZONTAL_ALIGNMENT_LEFT, 96.0 if shopping else -1.0, _lore)
	_t(Vector2(0, 49), "Beute %d" % roundi(voy.loot), GOLD, 9, HORIZONTAL_ALIGNMENT_RIGHT, 456.0)
	if voy.pfand > 0 and tab == 0:  # die Pfandflasche (legendär) hat keinen Platz am Schiff, aber hier einen Hinweis (unten rechts: oben liegt der Hinweistext)
		ItemIcons.draw_inner(self, "pfand", Vector2(262, 292), 3)
		_t(Vector2(282, 304), "Pfandflasche ×%d" % voy.pfand, Items.pfand_color(), 8, HORIZONTAL_ALIGNMENT_LEFT, 120.0)
		_tip(Rect2(260, 290, 124, 20), Tips.pfand(voy))
	UiSkin.rule(self, 24.0, 456.0, 39.0, UiSkin.BRONZE, false)
	var close := Rect2(394, 17, 60, 16)
	_small_button(close, "Schließen", close.has_point(mouse))
	_register(close, "ix")
	if shopping:
		var labels := ["Schiff", "Schmiede", "Ausrüstung", "Rüstkammer"]
		var widths := [50.0, 62.0, 70.0, 72.0]
		var tx := 124.0
		for k in 4:
			var tr := Rect2(tx, 17, float(widths[k]), 16)
			UiSkin.button(self, tr, UiSkin.State.SELECTED if k == tab else (UiSkin.State.HOVER if tr.has_point(mouse) else UiSkin.State.NORMAL))
			_t(Vector2(tr.position.x, tr.position.y + 12), String(labels[k]), PAPER, 8, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
			_register(tr, "gt%d" % k)
			tx += float(widths[k]) + 3.0
	if tab == 1:
		_t(Vector2(24, 49), "Waffe und Rüstung machen jeden Mann stärker, die Kampfschule seine Fertigkeiten. Wer fällt, nimmt es mit.", DIM, 7, HORIZONTAL_ALIGNMENT_LEFT, 330.0)
		_draw_forge(mouse)
		_draw_tip(mouse)
		return
	if tab == 2:
		_t(Vector2(24, 49), "Waffe, Rüstung und Amulett je Mann. Fällt er, kehrt seine Ausrüstung in den Vorrat zurück.", DIM, 7, HORIZONTAL_ALIGNMENT_LEFT, 330.0)
		_draw_gear_tab(mouse)
		_draw_tip(mouse)
		return
	if tab == 3:
		_t(Vector2(24, 49), "Hier kaufst du Ausrüstung, und was im Vorrat liegt, verkaufst du für die Hälfte.", DIM, 7, HORIZONTAL_ALIGNMENT_LEFT, 330.0)
		_draw_armory(mouse)
		_draw_tip(mouse)
		return
	var hint := "Ein gekaufter Gegenstand ersetzt, was auf seinem Platz sitzt. Die Farbe zeigt die Seltenheit." if shopping else "Gegenstände kaufst du im Hafen in der Werft (B schließt)."
	_t(Vector2(24, 49), hint, DIM, 8)

	# Links: die Plätze
	for i in Items.SLOT_NAMES.size():
		var r := Rect2(22, 60 + i * 34, 224, 31)
		var has := voy.items.has(i)
		var key := String(voy.items[i]) if has else ""
		var edge: Color = Items.rarity_color(key) if (has and Items.rarity_of(key) > 0) else UiSkin.BRONZE_LO.lerp(UiSkin.BRONZE, 0.5)
		UiSkin.panel(self, r, edge, 1 if (has and Items.rarity_of(key) > 0) else 0, "tile_wood")
		if has:
			ItemIcons.draw(self, key, r.position + Vector2(4, 5), Items.rarity_of(key))
		else:
			_empty_plate(Rect2(r.position + Vector2(4, 5), Vector2(ItemIcons.TILE, ItemIcons.TILE)))
		_t(r.position + Vector2(28, 11), String(Items.SLOT_NAMES[i]), DIM, 8)
		if has:
			_t(r.position + Vector2(74, 11), Items.name_of(key), Items.rarity_color(key) if Items.rarity_of(key) > 0 else GOLD, 9, HORIZONTAL_ALIGNMENT_LEFT, 98.0)
			if Items.rarity_of(key) > 0:
				_t(r.position + Vector2(r.size.x - 50, 11), Items.rarity_name(key), Items.rarity_color(key), 7, HORIZONTAL_ALIGNMENT_RIGHT, 46.0)
			var parts: PackedStringArray = []
			for ml in Items.lines_of(key):
				parts.append(String(ml[0]))
			_t(r.position + Vector2(28, 24), "  ·  ".join(parts), DIM, 7, HORIZONTAL_ALIGNMENT_LEFT, 192.0)
			_tip(r, Tips.item(key, voy.stage, false))
		else:
			_t(r.position + Vector2(74, 11), "leer", Color(DIM, 0.6), 9)

	# Rechts
	var x := 262.0
	if shopping:
		_t(Vector2(x, 66), "Angebot", GOLD, 10)
		for k in voy.shop.size():
			var id2 := String(voy.shop[k])
			var price := Items.price_at(id2, voy.stage)
			var can := voy.loot >= float(price)
			var r2 := Rect2(x, 72 + k * 62, 194, 58)
			var hover := can and r2.has_point(mouse)
			var rc := Items.rarity_color(id2)
			_card(r2, UiSkin.State.HOVER if hover else (UiSkin.State.NORMAL if can else UiSkin.State.DISABLED), 1.0, rc if Items.rarity_of(id2) > 0 else Color(0, 0, 0, 0))
			ItemIcons.draw(self, id2, r2.position + Vector2(6, 4), Items.rarity_of(id2), Color.WHITE if can else Color(1, 1, 1, 0.5))
			_t(r2.position + Vector2(32, 13), Items.name_of(id2), (rc if Items.rarity_of(id2) > 0 else GOLD) if can else DIM, 9, HORIZONTAL_ALIGNMENT_LEFT, 112.0)
			_t(r2.position + Vector2(0, 13), "%d" % price, GOLD if can else RED, 9, HORIZONTAL_ALIGNMENT_RIGHT, r2.size.x - 6.0)
			_t(r2.position + Vector2(32, 23), "%s · %s" % [Items.rarity_name(id2), Items.KIND_NAMES[Items.kind_of(id2)]], rc if can else Color(DIM, 0.8), 7, HORIZONTAL_ALIGNMENT_LEFT, 150.0)
			var yy := 30.0
			for ml in Items.lines_of(id2):
				if yy > 55.0:
					break
				_t(r2.position + Vector2(6, yy), String(ml[0]), GREEN if bool(ml[1]) else RED, 7)
				yy += 8.0
			_register(r2, "i%d" % k)
			_tip(r2, Tips.item(id2, voy.stage, true))
		if voy.shop.is_empty():
			_t(Vector2(x, 90), "Ausverkauft.", DIM, 9)
		var rep := Rect2(x, 256, 194, 17)
		var can_rep := voy.hull < voy.hull_max() - 0.5 and voy.loot >= float(voy.repair_price())
		UiSkin.button(self, rep, UiSkin.State.HOVER if (can_rep and rep.has_point(mouse)) else (UiSkin.State.NORMAL if can_rep else UiSkin.State.DISABLED))
		_t(Vector2(rep.position.x + 6, rep.position.y + 12), "Rumpf reparieren  +25", PAPER if can_rep else DIM, 8)
		_t(Vector2(rep.position.x, rep.position.y + 12), "%d" % voy.repair_price(), GOLD if can_rep else DIM, 8, HORIZONTAL_ALIGNMENT_RIGHT, rep.size.x - 6.0)
		_register(rep, "irep")
		if voy.cannons() > 0:
			var pw := Rect2(x, 276, 194, 17)
			var can_pw := voy.powder < roundi(voy.stat("powder_max")) and voy.loot >= float(voy.powder_price())
			UiSkin.button(self, pw, UiSkin.State.HOVER if (can_pw and pw.has_point(mouse)) else (UiSkin.State.NORMAL if can_pw else UiSkin.State.DISABLED))
			_t(Vector2(pw.position.x + 6, pw.position.y + 12), "Pulver +4  (%d / %d)" % [voy.powder, roundi(voy.stat("powder_max"))], PAPER if can_pw else DIM, 8)
			_t(Vector2(pw.position.x, pw.position.y + 12), "%d" % voy.powder_price(), GOLD if can_pw else DIM, 8, HORIZONTAL_ALIGNMENT_RIGHT, pw.size.x - 6.0)
			_register(pw, "ipow")
	else:
		_t(Vector2(x, 66), "Schiffswerte", GOLD, 10)
		var y := 80.0
		var mods := voy.ship_mods()
		_t(Vector2(x, y), "Rumpf %d von %d" % [roundi(voy.hull), roundi(voy.hull_max())], PAPER, 9)
		y += 12.0
		for key2 in Items.LABELS:
			if key2 == "hull_max":
				continue
			var base: float = Items.BASE[key2]
			var now := float(mods[key2])
			if absf(now - base) < 0.001:
				continue
			var info: Array = Items.LABELS[key2]
			var txt := ""
			var good := true
			if Items.ADDITIVE.has(key2):
				txt = "%s %d" % [info[0], roundi(now)]
				good = now > base
			else:
				txt = "%s %s %%" % [info[0], Voyage.signed(roundi((now - 1.0) * 100.0))]
				good = (now < 1.0) == bool(info[2])
			_t(Vector2(x, y), txt, GREEN if good else RED, 8)
			y += 10.0
		y += 4.0
		_t(Vector2(x, y + 8), "Segen", GOLD, 10)
		y += 20.0
		if voy.perks.is_empty():
			_t(Vector2(x, y), "noch keine", DIM, 8)
		for pid in voy.perks:
			if y > 292.0:
				break
			_t(Vector2(x, y), String(Perks.DATA[String(pid)]["name"]), PAPER, 8)
			y += 10.0
	_draw_tip(mouse)


## Leere Platte (20x20) für einen unbesetzten Platz: dunkel, mit blassem Rand.
func _empty_plate(r: Rect2) -> void:
	draw_rect(r, Color(UiSkin.INK, 0.55))
	draw_rect(r, Color(DIM, 0.35), false, 1.0)


## Die Männerliste links in Schmiede und Ausrüstung.
func _draw_men_list(mouse: Vector2, cur: CrewMember) -> void:
	var men := voy.forge_men()
	for i in men.size():
		var m: CrewMember = men[i]
		var rr := Rect2(22, 60.0 + float(i) * 19.0, 170, 18)
		var sel := m == cur
		_card(rr, UiSkin.State.SELECTED if sel else (UiSkin.State.HOVER if rr.has_point(mouse) else UiSkin.State.NORMAL))
		UiSkin.portrait(self, rr.position + Vector2(4, 2), m.look)
		_t(rr.position + Vector2(19, 12), m.display_name, _name_color(m), 8, HORIZONTAL_ALIGNMENT_LEFT, 50.0)
		_t(rr.position + Vector2(72, 12), String(Roles.role(m.role)["short"]), Color(DIM, 0.95), 7)
		var ups := m.weapon_lvl + m.armor_lvl + m.gear.size()
		for v in m.skill_lvl.values():
			ups += int(v)
		if ups > 0:
			_t(rr.position + Vector2(rr.size.x - 34, 12), "+%d" % ups, GOLD, 8, HORIZONTAL_ALIGNMENT_RIGHT, 30.0)
		_register(rr, "gm%d" % i)


## Eine Zeile mit den Werten einer Ausrüstung, knapp: "Schaden +8 % · Treffer +3".
func _gear_summary(key: String) -> String:
	var parts: PackedStringArray = []
	for ml in Gear.lines_of(key):
		parts.append(String(ml[0]))
	return "  ·  ".join(parts)


## Ausrüstung: was ein Mann trägt und was im Vorrat liegt; ein Klick legt an oder ab.
func _draw_gear_tab(mouse: Vector2) -> void:
	var cur := _forge_current()
	_draw_men_list(mouse, cur)
	if cur == null:
		return
	var x := 204.0
	_t(Vector2(x, 66), "%s, %s" % [cur.display_name, Roles.role_name(cur.role)], GOLD, 10)
	for s in 3:
		var rr := Rect2(x, 72.0 + float(s) * 30.0, 254, 28)
		var has := cur.gear.has(s)
		var key := String(cur.gear[s]) if has else ""
		var rc := Gear.rarity_color(key) if (has and Items.rarity_of(key) > 0) else Color(0, 0, 0, 0)
		_card(rr, UiSkin.State.HOVER if (has and rr.has_point(mouse)) else UiSkin.State.NORMAL, 0.95, rc)
		if has:
			ItemIcons.draw(self, key, rr.position + Vector2(4, 4), Items.rarity_of(key))
		else:
			_empty_plate(Rect2(rr.position + Vector2(4, 4), Vector2(ItemIcons.TILE, ItemIcons.TILE)))
		_t(rr.position + Vector2(28, 11), String(Gear.SLOT_NAMES[s]), DIM, 8)
		if has:
			_t(rr.position + Vector2(74, 11), Gear.name_of(key), Gear.rarity_color(key) if Items.rarity_of(key) > 0 else GOLD, 9, HORIZONTAL_ALIGNMENT_LEFT, 118.0)
			_t(rr.position + Vector2(rr.size.x - 62, 11), "ablegen" if rr.has_point(mouse) else Gear.rarity_name(key), Color(DIM, 0.9) if rr.has_point(mouse) else Gear.rarity_color(key), 7, HORIZONTAL_ALIGNMENT_RIGHT, 56.0)
			_t(rr.position + Vector2(28, 22), _gear_summary(key), DIM, 7, HORIZONTAL_ALIGNMENT_LEFT, 220.0)
			_register(rr, "gu%d" % s)
			_tip(rr, Tips.gear(key, voy.stage, false))
		else:
			_t(rr.position + Vector2(74, 11), "leer", Color(DIM, 0.6), 9)
	var free := voy.stash_free()
	_t(Vector2(x, 176), "Vorrat (%d von %d)" % [voy.stash.size(), Gear.STASH_MAX], GOLD, 9)
	var auto_b := Rect2(x + 150, 165, 104, 14)
	var can_auto := not voy.stash.is_empty()
	_small_button(auto_b, "Beste anlegen", can_auto and auto_b.has_point(mouse), can_auto, 7)
	if can_auto:
		_register(auto_b, "gauto")
	for i in voy.stash.size():
		var key2 := String(voy.stash[i])
		var rr2 := Rect2(x, 182.0 + float(i) * 21.0, 254, 19)
		var rc2 := Gear.rarity_color(key2) if Items.rarity_of(key2) > 0 else Color(0, 0, 0, 0)
		_card(rr2, UiSkin.State.HOVER if rr2.has_point(mouse) else UiSkin.State.NORMAL, 0.95, rc2)
		ItemIcons.draw_inner(self, key2, rr2.position + Vector2(3, 1.5), Items.rarity_of(key2))
		_t(rr2.position + Vector2(22, 12), Gear.name_of(key2), Gear.rarity_color(key2) if Items.rarity_of(key2) > 0 else GOLD, 8, HORIZONTAL_ALIGNMENT_LEFT, 80.0)
		_t(rr2.position + Vector2(104, 12), "%s · %s" % [Gear.SLOT_NAMES[Gear.slot_of(key2)], _gear_summary(key2)], Color(DIM, 0.95), 6, HORIZONTAL_ALIGNMENT_LEFT, 148.0)
		_register(rr2, "ge%d" % i)
		_tip(rr2, Tips.gear(key2, voy.stage, false))
	if voy.stash.is_empty():
		_t(Vector2(x, 198), "Der Vorrat ist leer. Funde, Beute und die Rüstkammer füllen ihn.", DIM, 7, HORIZONTAL_ALIGNMENT_LEFT, 250.0)
	if free <= 0:
		_t(Vector2(x, 308), "Vorrat voll: neue Funde werden verkauft.", RED, 7)


## Rüstkammer: drei Stücke zum Kaufen, rechts der Vorrat zum Verkaufen.
func _draw_armory(mouse: Vector2) -> void:
	_t(Vector2(22, 66), "Angebot", GOLD, 10)
	for k in voy.gear_shop.size():
		var key := String(voy.gear_shop[k])
		var price := Gear.price_at(key, voy.stage)
		var can := voy.loot >= float(price) and voy.stash_free() > 0
		var rr := Rect2(22, 72.0 + float(k) * 62.0, 224, 58)
		var rc := Gear.rarity_color(key)
		_card(rr, UiSkin.State.HOVER if (can and rr.has_point(mouse)) else (UiSkin.State.NORMAL if can else UiSkin.State.DISABLED), 1.0, rc if Items.rarity_of(key) > 0 else Color(0, 0, 0, 0))
		ItemIcons.draw(self, key, rr.position + Vector2(6, 4), Items.rarity_of(key), Color.WHITE if can else Color(1, 1, 1, 0.5))
		_t(rr.position + Vector2(32, 13), Gear.name_of(key), (rc if Items.rarity_of(key) > 0 else GOLD) if can else DIM, 9, HORIZONTAL_ALIGNMENT_LEFT, 132.0)
		_t(rr.position + Vector2(0, 13), "%d" % price, GOLD if can else RED, 9, HORIZONTAL_ALIGNMENT_RIGHT, rr.size.x - 6.0)
		_t(rr.position + Vector2(32, 23), "%s · %s" % [Gear.rarity_name(key), Gear.SLOT_NAMES[Gear.slot_of(key)]], rc if can else Color(DIM, 0.8), 7, HORIZONTAL_ALIGNMENT_LEFT, 150.0)
		var yy := 30.0
		for ml in Gear.lines_of(key):
			if yy > 55.0:
				break
			_t(rr.position + Vector2(6, yy), String(ml[0]), GREEN if bool(ml[1]) else RED, 7)
			yy += 8.0
		_register(rr, "gb%d" % k)
		_tip(rr, Tips.gear(key, voy.stage, true))
	if voy.gear_shop.is_empty():
		_t(Vector2(22, 90), "Ausverkauft.", DIM, 9)
	_t(Vector2(262, 66), "Vorrat verkaufen (%d von %d)" % [voy.stash.size(), Gear.STASH_MAX], GOLD, 10)
	for i in voy.stash.size():
		var key2 := String(voy.stash[i])
		var rr2 := Rect2(262, 72.0 + float(i) * 25.0, 194, 23)
		var rc2 := Gear.rarity_color(key2) if Items.rarity_of(key2) > 0 else Color(0, 0, 0, 0)
		_card(rr2, UiSkin.State.HOVER if rr2.has_point(mouse) else UiSkin.State.NORMAL, 0.95, rc2)
		ItemIcons.draw_inner(self, key2, rr2.position + Vector2(3, 3.5), Items.rarity_of(key2))
		_t(rr2.position + Vector2(24, 11), Gear.name_of(key2), Gear.rarity_color(key2) if Items.rarity_of(key2) > 0 else GOLD, 8, HORIZONTAL_ALIGNMENT_LEFT, 100.0)
		_t(rr2.position + Vector2(24, 20), Gear.SLOT_NAMES[Gear.slot_of(key2)], Color(DIM, 0.9), 6)
		_t(rr2.position + Vector2(0, 15), "+%d" % roundi(float(Gear.price_at(key2, voy.stage)) * 0.5), GOLD, 8, HORIZONTAL_ALIGNMENT_RIGHT, rr2.size.x - 6.0)
		_register(rr2, "gv%d" % i)
		_tip(rr2, Tips.gear(key2, voy.stage, false))
	if voy.stash.is_empty():
		_t(Vector2(262, 90), "Nichts im Vorrat.", DIM, 8)


## Der gerade gewählte Mann der Schmiede (der erste, wenn noch keiner gewählt ist).
func _forge_current() -> CrewMember:
	var men := voy.forge_men()
	if men.is_empty():
		return null
	if _forge_man == null or not men.has(_forge_man):
		_forge_man = men[0]
	return _forge_man


## Schmiede (Waffe, Rüstung) und Kampfschule (Fertigkeiten) für einen gewählten Mann.
func _draw_forge(mouse: Vector2) -> void:
	var cur := _forge_current()
	_draw_men_list(mouse, cur)
	if cur == null:
		return
	var x := 204.0
	_t(Vector2(x, 66), "%s, %s" % [cur.display_name, Roles.role_name(cur.role)], GOLD, 10)
	# Waffe und Rüstung
	var rows := [["weapon", "Waffe", "Schaden", Voyage.WEAPON_DMG, "gw"], ["armor", "Rüstung", "Schutz", Voyage.ARMOR_PROT, "ga"]]
	for k in rows.size():
		var kind := String(rows[k][0])
		var lvl := voy.forge_level(kind, cur)
		var price := voy.forge_price(kind, cur)
		var can := voy.forge_can_buy(kind, cur)
		var rr2 := Rect2(x, 72.0 + float(k) * 22.0, 254, 20)
		_card(rr2, UiSkin.State.NORMAL, 0.9)
		_t(rr2.position + Vector2(6, 13), "%s  Stufe %d von %d" % [rows[k][1], lvl, voy.forge_max(kind)], PAPER, 8)
		_t(rr2.position + Vector2(104, 13), "%s +%d %%" % [rows[k][2], roundi(float(rows[k][3]) * 100.0 * float(lvl))], GOLD if lvl > 0 else DIM, 8)
		var btn := Rect2(rr2.end.x - 74, rr2.position.y + 2, 70, 16)
		if price > 0:
			UiSkin.button(self, btn, UiSkin.State.HOVER if (can and btn.has_point(mouse)) else (UiSkin.State.NORMAL if can else UiSkin.State.DISABLED))
			_t(Vector2(btn.position.x, btn.position.y + 12), "Stufe %d: %d" % [lvl + 1, price], PAPER if can else DIM, 7, HORIZONTAL_ALIGNMENT_CENTER, btn.size.x)
			if can:
				_register(btn, String(rows[k][4]))
		else:
			_t(Vector2(btn.position.x, btn.position.y + 12), "höchste Stufe", DIM, 7, HORIZONTAL_ALIGNMENT_CENTER, btn.size.x)
		_tip(rr2, Tips.forge_gear(kind, cur))
	# Kampfschule: die sechs Fertigkeiten der Rolle
	_t(Vector2(x, 128), "Kampfschule", GOLD, 9)
	var pool := Roles.pool(cur.role)
	var chosen: Array = cur.skills()
	for i in pool.size():
		var sid := String(pool[i])
		var lvl2 := voy.forge_level("skill", cur, sid)
		var mx := Roles.max_level(sid)
		var price2 := voy.forge_price("skill", cur, sid)
		var can2 := voy.forge_can_buy("skill", cur, sid)
		var rr3 := Rect2(x, 132.0 + float(i) * 27.0, 254, 25)
		_card(rr3, UiSkin.State.SELECTED if chosen.has(sid) else UiSkin.State.NORMAL, 0.9)
		SkillIcons.draw(self, Roles.icon_of(sid), rr3.position + Vector2(4, 4))
		_t(rr3.position + Vector2(25, 11), "%s  %s" % [Roles.skill(sid)["name"], ("Stufe %d von %d" % [lvl2, mx]) if mx > 0 else ""], GOLD if lvl2 > 0 else PAPER, 8, HORIZONTAL_ALIGNMENT_LEFT, 150.0)
		_t(rr3.position + Vector2(25, 21), Roles.upgrade_text(sid), Color(DIM, 0.95), 6, HORIZONTAL_ALIGNMENT_LEFT, 150.0)
		var btn2 := Rect2(rr3.end.x - 74, rr3.position.y + 4, 70, 16)
		if price2 > 0:
			UiSkin.button(self, btn2, UiSkin.State.HOVER if (can2 and btn2.has_point(mouse)) else (UiSkin.State.NORMAL if can2 else UiSkin.State.DISABLED))
			_t(Vector2(btn2.position.x, btn2.position.y + 12), "Stufe %d: %d" % [lvl2 + 1, price2], PAPER if can2 else DIM, 7, HORIZONTAL_ALIGNMENT_CENTER, btn2.size.x)
			if can2:
				_register(btn2, "gs%d" % i)
		else:
			_t(Vector2(btn2.position.x, btn2.position.y + 12), "höchste Stufe" if mx > 0 else "–", DIM, 7, HORIZONTAL_ALIGNMENT_CENTER, btn2.size.x)
		_tip(rr3, Tips.forge_skill(cur, sid))


## Klicks in der Schmiede (Reiter, Mann wählen, kaufen).
func forge_click(id: String) -> void:
	if voy == null or not voy.shop_open:
		return
	var cur := _forge_current()
	if id.begins_with("gt"):
		voy.werft_tab = clampi(int(id.substr(2)), 0, 3)
	elif id == "gauto":
		voy.auto_equip()
	elif id.begins_with("gb"):
		voy.buy_gear(int(id.substr(2)))
	elif id.begins_with("gv"):
		voy.sell_gear(int(id.substr(2)))
	elif cur != null and id.begins_with("ge"):
		voy.equip_gear(cur, int(id.substr(2)))
	elif cur != null and id.begins_with("gu"):
		voy.unequip_gear(cur, int(id.substr(2)))
	elif id.begins_with("gm"):
		var men := voy.forge_men()
		var k := int(id.substr(2))
		if k >= 0 and k < men.size():
			_forge_man = men[k]
	elif cur != null and id == "gw":
		voy.forge_buy("weapon", cur)
	elif cur != null and id == "ga":
		voy.forge_buy("armor", cur)
	elif cur != null and id.begins_with("gs"):
		var pool := Roles.pool(cur.role)
		var k2 := int(id.substr(2))
		if k2 >= 0 and k2 < pool.size():
			voy.forge_buy("skill", cur, String(pool[k2]))


# --- Segen bei einem Stufenaufstieg -------------------------------------------

func _draw_perks(mouse: Vector2) -> void:
	_btns.clear()
	draw_rect(Rect2(0, 0, Waves.VIEW_W, Waves.VIEW_H), Color(0, 0, 0, 0.94))
	UiSkin.vignette(self, 1)
	_t(Vector2(1, 53), "Stufe %d" % voy.level, UiSkin.BRONZE_LO, 22, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	_t(Vector2(0, 52), "Stufe %d" % voy.level, GOLD, 22, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	UiSkin.rule(self, 150.0, 330.0, 59.0, UiSkin.BRONZE, true)
	_t(Vector2(0, 70), "Die Götter bieten einen Segen an. Wähle einen, er gilt für den Rest der Fahrt.", DIM, 9, HORIZONTAL_ALIGNMENT_CENTER, 480.0)
	var n := voy.perk_offer.size()
	for i in n:
		var p: Dictionary = Perks.DATA[String(voy.perk_offer[i])]
		var r := Rect2(240.0 - float(n) * 76.0 + float(i) * 152.0 + 4.0, 92, 144, 134)
		var hover := r.has_point(mouse)
		UiSkin.panel(self, r, UiSkin.accent(UiSkin.State.HOVER) if hover else UiSkin.BRONZE_HI, 2, "tile_stone", true, Color.WHITE, hover)
		ItemIcons.draw_emblem(self, String(voy.perk_offer[i]), Vector2(r.position.x + (r.size.x - float(ItemIcons.EMBLEM)) * 0.5, r.position.y + 9.0), Color.WHITE if hover else Color(0.92, 0.92, 0.92))
		_t(Vector2(r.position.x, r.position.y + 58), String(p["name"]), GOLD, 11, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8.0)
		UiSkin.rule(self, r.position.x + 12.0, r.end.x - 12.0, r.position.y + 63.0, UiSkin.BRONZE, false)
		_wrap(String(p["desc"]), r.position.x + 10.0, r.position.y + 71.0, r.size.x - 20.0, 9, PAPER)
		_t(Vector2(r.position.x, r.end.y - 8), str(i + 1), DIM, 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		_register(r, "p%d" % i)


# --- Lager ----------------------------------------------------------------------

## Das Lager: links die Aktionen mit Lagerpunkten, rechts die Männer, unten Meldungen und die Schaltflächen.
func _draw_camp(mouse: Vector2) -> void:
	_btns.clear()
	_tips.clear()
	draw_rect(Rect2(0, 0, Waves.VIEW_W, Waves.VIEW_H), Color(0, 0, 0, 0.88))
	var panel := Rect2(14, 8, 452, 304)
	UiSkin.panel(self, panel, UiSkin.BRONZE, 2, "tile_stone")
	var cove := bool(voy.here().get("cove", false))
	_t(Vector2(24, 34), "Lager", GOLD, 16, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _lore)
	_t(Vector2(84, 33), "Ankerbucht: sicher" if cove else "offene Küste: die Nacht ist unsicher", GREEN if cove else GOLD, 8)
	_tip(Rect2(24, 20, 260, 18), Tips.camp_site(voy))
	UiSkin.rule(self, 24.0, 456.0, 39.0, UiSkin.BRONZE, false)
	# Lagerpunkte als Kreise oben rechts
	for k in Camp.POINTS:
		var cx := 440.0 - float(Camp.POINTS - 1 - k) * 12.0
		var on := k < voy.camp_points
		draw_rect(Rect2(cx - 4, 22, 8, 8), INK)
		draw_rect(Rect2(cx - 3, 23, 6, 6), GOLD if on else Color(0.16, 0.15, 0.13))
		if on:
			draw_rect(Rect2(cx - 3, 23, 6, 1), Color(1, 1, 0.8, 0.7))
	_tip(Rect2(340, 18, 116, 16), Tips.camp_points(voy))
	_t(Vector2(24, 50), "Lagerpunkte: %d von %d.  Proviant %d  ·  Beute %d" % [voy.camp_points, Camp.POINTS, voy.proviant, roundi(voy.loot)], DIM, 8)

	# Linke Spalte: die Aktionen
	var hover_man: CrewMember = null
	for i in Camp.ORDER.size():
		var id: String = Camp.ORDER[i]
		var d: Dictionary = Camp.DATA[id]
		var r := Rect2(22, 56.0 + float(i) * 24.0, 236, 22)
		var why := Camp.why_not(voy, id)
		var ok := why == ""
		var used := int(voy.camp_done.get(id, 0)) > 0
		var hh := r.has_point(mouse)
		_card(r, UiSkin.State.HOVER if (hh and ok) else (UiSkin.State.NORMAL if ok else UiSkin.State.DISABLED), 1.0 if (ok or used) else 0.7)
		_t(r.position + Vector2(8, 10), "%d  %s" % [i + 1, String(d["name"])], GOLD if ok else (PAPER if used else DIM), 9)
		_t(r.position + Vector2(8, 19), String(d["short"]) if ok or used else why, (Color(PAPER, 0.85) if ok else (GREEN if used else Color(RED, 0.8))), 7)
		for c in int(d["cost"]):  # Kosten in Lagerpunkten
			draw_rect(Rect2(r.end.x - 14.0 - float(c) * 9.0, r.position.y + 7.0, 7, 7), INK)
			draw_rect(Rect2(r.end.x - 13.0 - float(c) * 9.0, r.position.y + 8.0, 5, 5), GOLD if ok else Color(0.3, 0.28, 0.22))
		if used:
			_t(r.position + Vector2(0, 10), "getan", GREEN, 7, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 30.0)
		if ok:
			_register(r, "ca%d" % i)
		_tip(r, Tips.camp_action(voy, id))

	# Rechte Spalte: alle Männer, an Deck und unter Deck
	var rx := 274.0
	draw_rect(Rect2(rx - 6, 52, 1, 232), Color(DIM, 0.3))
	_t(Vector2(rx, 58), "Mannschaft", GOLD, 9)
	var men: Array[CrewMember] = []
	for m in voy.crew:
		if m.state == CrewMember.State.ABOARD:
			men.append(m)
	for m in voy.reserve:
		men.append(m)
	for k in men.size():
		var m: CrewMember = men[k]
		var mr := Rect2(rx, 62.0 + float(k) * 18.0, 184, 17)
		var mh := mr.has_point(mouse)
		if mh:
			hover_man = m
		_card(mr, UiSkin.State.HOVER if mh else UiSkin.State.NORMAL, 0.9)
		var res := m.state == CrewMember.State.RESERVE
		_t(mr.position + Vector2(6, 12), m.display_name + ("  (Reserve)" if res else ""), _name_color(m) if not res else Color(DIM, 0.95), 8)
		if voy.camp_watch == m:
			_t(mr.position + Vector2(0, 12), "Wache", GREEN, 7, HORIZONTAL_ALIGNMENT_RIGHT, 80.0)
		UiSkin.mini_bar(self, mr.position.x + 108.0, mr.position.y + 4.0, 70.0, m.kraft / 100.0, _kraft_col(m.kraft))
		UiSkin.mini_bar(self, mr.position.x + 108.0, mr.position.y + 9.0, 70.0, clampf(m.stress, 0.0, 100.0) / 100.0, VIOLET if m.stress < 70.0 else RED)

	# Unten: letzte Meldung und Schaltflächen
	for k in range(voy.history.size() - 1, -1, -1):
		var e: Dictionary = voy.history[k]
		if int(e["kind"]) != Voyage.Kind.LORE:
			_t(Vector2(24, 285), String(e["text"]), PAPER, 8, HORIZONTAL_ALIGNMENT_LEFT, 430.0)
			break
	var crew_btn := Rect2(24, 292, 112, 15)
	_small_button(crew_btn, "Mannschaft (C)", crew_btn.has_point(mouse))
	_register(crew_btn, "ccrew")
	_tip(crew_btn, Tips.camp_crew(voy))
	var go_btn := Rect2(338, 292, 118, 15)
	_small_button(go_btn, "Aufbrechen (Enter)", go_btn.has_point(mouse))
	_register(go_btn, "cend")
	_t(Vector2(144, 302), "Chance auf ein Nachtereignis: %d %%" % roundi(voy.camp_night_chance() * 100.0), Color(DIM, 0.9), 8)
	_tip(Rect2(140, 292, 190, 15), Tips.camp_night(voy))
	if hover_man != null:
		_draw_crew_tooltip(mouse, hover_man)
	else:
		_draw_tip(mouse)


# --- Deckkampf --------------------------------------------------------------------

const FIGHT_HERO_X := [210.0, 152.0, 94.0, 36.0]  # Mitte je Reihe (Reihe 1 steht der Mitte am nächsten)
const FIGHT_FOE_X := [270.0, 328.0, 386.0, 444.0]
const FIGHT_FEET := 140.0  # Zeile, auf der die Füße stehen
const FIGHT_BIG_SOLE := 164.0  # Unterkante der Riesenfigur (Kraken): sie steht hinter dem Deck, dessen Rand ihre Füße verdeckt
const FIGHT_BIG_X := 392.0
const FIG_W := 44.0  # Zelle in assets/combat.png
const FIG_H := 56.0
const FS := 2.0  # Maßstab der Kampffiguren: der Atlas bleibt, gezeichnet wird doppelt (dieselbe Pixelgröße wie die Bühne)

var _fight_skill := ""  # gewählte Fertigkeit, die noch ein Ziel braucht
var _fight_move := false  # "Reihe wechseln": der Mann, mit dem getauscht wird, wird gewählt
var _fight_actor: Combat.Fighter = null
var _combat_tex: Texture2D = null
var _big_tex: Dictionary = {}  # Riesenfiguren (Kraken) je Gegnerart
var _anim: Dictionary = {}  # Kämpfer -> {"kind": attack|hit, "t": Restzeit}
var _floats: Array = []  # schwebende Zahlen: {"x", "y", "text", "col", "t", "big"}
var _ghosts: Array = []  # Gefallene, die noch ausblenden: {"f", "t"}
var _ev_seen := 0
var _ev_combat: Combat = null
var _ev_stagger := 0  # wievielter Treffer des laufenden Zuges, damit Mehrfachtreffer nacheinander klingen
var _outro_for: Combat = null  # der Kampf, für den die Schlussansage (Sieg, Niederlage, Rückzug) schon lief
var _intro_pending := false
var _forge_man: CrewMember = null  # Schmiede: der gewählte Mann
var _loadout_man: CrewMember = null  # in der Aufstellung: wessen Fertigkeiten gerade gewählt werden
var _ev_actor: Combat.Fighter = null  # wer zuletzt zugeschlagen hat (Start der Pfeile und Fangarme)
var _ev_sk := ""
var _fx := FightFx.new()  # Hiebbögen, Pfeile, Leuchten, Banner, Wackeln (scripts/fight_fx.gd)
var _lit := {}  # Kämpfer -> wie hell er steht (0,5 .. 1,0), wechselt weich: der Handelnde im Licht, die anderen im Halbdunkel
var _stage_dim := 0.0  # Abdunkelung des Hintergrunds, solange jemand handelt
var _stage_xf := Transform2D.IDENTITY  # Kamera der Bühne (Wackeln und Schub), für die Kampfeffekte


## Klicks und Tasten im Deckkampf (Aufstellung und Kampf).
func fight_click(id: String) -> void:
	if voy.phase != Voyage.Phase.COMBAT:
		return
	if voy.combat == null:
		var party: Array = voy.fight_prep.get("party", [])
		var pool: Array = voy.fight_prep.get("pool", [])
		if _loadout_man != null:
			# die Fertigkeitenwahl ist offen
			if id == "lodef":
				_loadout_man.loadout = Roles.default_loadout(_loadout_man.role)
			elif id == "lodone":
				_loadout_man = null
			elif id.begins_with("lo"):
				var lp := Roles.pool(_loadout_man.role)
				var lk := int(id.substr(2))
				if lk >= 0 and lk < lp.size():
					_loadout_toggle(String(lp[lk]))
			return
		if id.begins_with("fl"):
			var li := int(id.substr(2))
			if li >= 0 and li < party.size():
				_loadout_man = party[li]
		elif id.begins_with("fp"):
			voy.fight_toggle(pool[int(id.substr(2))])
		elif id.begins_with("fu"):
			voy.fight_shift(party[int(id.substr(2))], -1)
		elif id.begins_with("fd"):
			voy.fight_shift(party[int(id.substr(2))], 1)
		elif id == "fauto":
			voy.fight_auto_party()
		elif id == "fgo":
			voy.fight_begin()
		return
	var c := voy.combat
	if c.state != "hero":
		return
	if id.begins_with("fs"):
		var opts := _fight_options(c)
		var slot := int(id.substr(2))
		if slot < 0 or slot >= opts.size():
			return
		var sid := opts[slot]
		_fight_move = false
		_fight_skill = ""
		if sid == "move":
			_fight_move = true
		elif sid == "flee":
			voy.combat_flee()
		elif not c.can_use(c.actor, sid):
			return
		elif c.needs_target(sid):
			var tl := c.targets(c.actor, sid)
			if tl.size() == 1:
				voy.combat_act(sid, tl[0])
			else:
				_fight_skill = sid
		else:
			voy.combat_act(sid, null)
	elif id.begins_with("ft"):
		var side := int(id.substr(2, 1))
		var rank := int(id.substr(4))
		var list: Array[Combat.Fighter] = c.heroes if side == 0 else c.foes
		if rank < 0 or rank >= list.size():
			return
		if _fight_move:
			if side == 0:
				voy.combat_move(rank)
				_fight_move = false
		elif _fight_skill != "" and c.targets(c.actor, _fight_skill).has(list[rank]):
			voy.combat_act(_fight_skill, list[rank])
			_fight_skill = ""
	elif id == "fwait":
		voy.combat_pass()


func fight_key(key: int) -> void:
	if voy.combat == null:
		if _loadout_man != null:
			if key == KEY_ESCAPE or key == KEY_ENTER or key == KEY_KP_ENTER:
				_loadout_man = null
			return
		if key == KEY_ENTER or key == KEY_KP_ENTER:
			fight_click("fgo")
		elif key == KEY_A:
			fight_click("fauto")
		return
	if key >= KEY_1 and key <= KEY_6:
		fight_click("fs%d" % (key - KEY_1))
	elif key == KEY_SPACE:
		fight_click("fwait")
	elif key == KEY_ESCAPE:
		_fight_skill = ""
		_fight_move = false
	elif key == KEY_Q or key == KEY_W or key == KEY_E or key == KEY_R:
		var rank := [KEY_Q, KEY_W, KEY_E, KEY_R].find(key)
		var heroes_side := _fight_move or (_fight_skill != "" and String(Roles.skill(_fight_skill)["tgt"]) == "ally")
		fight_click("ft%d_%d" % [0 if heroes_side else 1, rank])


func _fight_options(c: Combat) -> Array[String]:
	var out: Array[String] = []
	if c.actor != null:
		for s in c.actor.skills:
			out.append(String(s))
	out.append("move")
	out.append("flee")
	return out


func _is_big(f: Combat.Fighter) -> bool:
	return f.side == 1 and Foes.is_big(f.kind)


func _big_texture(kind: String) -> Texture2D:
	if not _big_tex.has(kind):
		_big_tex[kind] = load(String(Foes.BIG[kind]["file"])) as Texture2D
	return _big_tex[kind]


## Riesenfiguren stehen immer ganz rechts, hinter den anderen Gegnern.
func _fig_x(f: Combat.Fighter) -> float:
	if _is_big(f):
		return FIGHT_BIG_X
	return FIGHT_HERO_X[f.rank] if f.side == 0 else FIGHT_FOE_X[f.rank]


func _fighter_rect(f: Combat.Fighter) -> Rect2:
	if _is_big(f):
		return Rect2(_fig_x(f) - 70.0, FIGHT_FEET - 150.0, 140.0, 156.0)
	return Rect2(_fig_x(f) - 28.0, FIGHT_FEET - 100.0, 56.0, 106.0)


func _fig_row(f: Combat.Fighter) -> int:
	if f.side == 0:
		return clampi(f.role, 0, Roles.ROLES.size() - 1)
	return int(Foes.ROW.get(f.kind, 4))


func _status_text(f: Combat.Fighter) -> String:
	var s := ""
	if f.door and f.side == 0:
		s += "!"
	if f.held_by != null and not f.held_by.gone:
		s += "G"
	if f.blind > 0:
		s += "T"
	if f.charge:
		s += "Z"
	if f.stun > 0:
		s += "B"
	if f.bleed_turns > 0:
		s += "b"
	if f.mark > 0:
		s += "M"
	if f.guard > 0:
		s += "S"
	if f.buff > 0:
		s += "+"
	return s


## Ereignisse des Kampfes in Bewegung, Wirkung und Klang übersetzen. Treffer wirken erst, wenn Hieb oder Pfeil ankommt.
func _fight_events(c: Combat) -> void:
	if c != _ev_combat:
		_ev_combat = c
		_ev_seen = 0
		_anim.clear()
		_floats.clear()
		_ghosts.clear()
		_fx.clear()
		_ev_actor = null
		_ev_sk = ""
		_outro_for = null
		_intro_pending = true
		_lit.clear()
		_stage_dim = 0.0
	# Läuft ein schnell aufgelöster Kampf erst jetzt auf, würden Hunderte Klänge auf einmal losgehen: dann still bleiben
	var fresh := 0
	for ev in c.events:
		if int(ev["id"]) > _ev_seen:
			fresh += 1
	var loud := fresh <= 24
	if _intro_pending:
		_intro_pending = false
		if c.round_no <= 1 and loud:
			var boss := c.formation == "kraken"
			_fx.show_big("DER KRAKEN" if boss else "KAMPF", "Fangarme zuerst, dann der Körper" if boss else String(Foes.FORMATIONS[c.formation]["name"]), Color(0.9, 0.35, 0.35), 1.9 if boss else 1.5)
			_fx.flash(Color(0, 0, 0, 0.5), 0.7)
			_slow(1.8)
	for ev in c.events:
		var id := int(ev["id"])
		if id <= _ev_seen:
			continue
		_ev_seen = id
		var who: Combat.Fighter = ev["who"]
		var fx := _fig_x(who)
		var sk := String(ev.get("sk", ""))
		var hw := 0.2 + 0.13 * float(_ev_stagger)  # wann der nächste Treffer dieses Zuges ankommt
		match String(ev["type"]):
			"attack":
				_ev_actor = who
				_ev_sk = sk
				_ev_stagger = 0
				var mv := 1.0 if FightFx.lunges(sk) else (-0.3 if FightFx.is_flight(sk) else 0.0)
				_anim[who] = {"kind": "attack", "t": 0.42, "mv": mv}
				if loud:
					Sfx.play(Sfx.skill_sound(sk, "go"))
					_fx_go(c, who, sk)
					var sname := _skill_label(sk)
					if sname != "":
						_fx.show_banner(sname, who.name if who.side == 0 else String(Foes.info(who.kind).get("short", who.name)), who.side, Roles.icon_of(sk))
			"hit":
				var crit := bool(ev["crit"])
				var dmg := int(ev["n"])
				_anim[who] = {"kind": "hit", "t": 0.42, "wait": hw}
				_floats.append({"x": fx, "y": FIGHT_FEET - 92.0, "text": "−%d" % dmg, "col": GOLD if crit else (Color(0.95, 0.45, 0.4) if who.side == 0 else PAPER), "t": 1.0, "big": crit, "wait": hw})
				if loud:
					Sfx.play(Sfx.skill_sound(sk, "hit"), 2.0 if crit else 0.0, hw)
					if crit:
						Sfx.play("clash", -6.0, hw)
					_fx_hit(who, sk, hw, crit, dmg)
					_ev_stagger += 1
			"miss":
				_anim[who] = {"kind": "dodge", "t": 0.3, "wait": hw}
				_floats.append({"x": fx, "y": FIGHT_FEET - 88.0, "text": "verfehlt", "col": Color(DIM, 0.95), "t": 0.9, "big": false, "wait": hw})
				if loud:
					Sfx.play("whiff", 0.0, hw)
					_fx_miss(who, sk, hw)
					_ev_stagger += 1
			"heal":
				_floats.append({"x": fx, "y": FIGHT_FEET - 92.0, "text": "+%d" % int(ev["n"]), "col": GREEN, "t": 1.0, "big": false, "wait": 0.25})
				if loud:
					Sfx.play("heal", 0.0, 0.25)
					_fx.add("heal", {"x": fx, "y": FIGHT_FEET - 68.0}, 0.25, 0.9)
			"die":
				var hold := 0.2 + 0.13 * float(maxi(_ev_stagger - 1, 0))
				var big := _is_big(who)
				_ghosts.append({"f": who, "t": hold + (1.2 if big else 0.7)})
				if loud:
					Sfx.play("kraken_roar" if big else ("tentacle" if who.kind == "tentakel" else ("bones" if who.kind in ["knochen", "rost", "bogner"] else "fall")), 0.0, hold + 0.1)
					_fx.cue("shake", {"amp": 7.0 if big else 3.0, "d": 0.7 if big else 0.3}, hold)
					_fx.cue("freeze", {"d": 0.09}, hold)
					if big:
						_fx.cue("flash", {"col": Color(1, 1, 1, 0.5), "d": 0.6}, hold)
					_slow(1.2)
					var focus := Vector2(fx, FIGHT_FEET - 60.0)
					if who.side == 0:
						_fx.cue("slowmo", {"f": 0.35, "d": 0.8}, hold)
						_fx.cue("zoom", {"amp": 0.08, "d": 0.8, "fx": fx, "fy": focus.y}, hold)
						if _fx.big.is_empty():
							_fx.show_big("GEFALLEN", "%s kehrt nicht zurück" % who.name, Color(0.9, 0.35, 0.35), 1.7)
							_slow(1.9)
					elif c.foes.is_empty() and c.heroes.size() > 0:
						_fx.cue("slowmo", {"f": 0.3, "d": 1.0}, hold)
						_fx.cue("zoom", {"amp": 0.11, "d": 1.0, "fx": fx, "fy": focus.y}, hold)
			"overboard":
				_ghosts.append({"f": who, "t": 0.7})
				_floats.append({"x": fx, "y": FIGHT_FEET - 92.0, "text": "über Bord!", "col": Color(0.6, 0.8, 0.95), "t": 1.3, "big": true, "wait": 0.0})
				if loud:
					Sfx.play("splash", 0.0, 0.3)
					_fx.add("ring", {"x": fx, "y": FIGHT_FEET - 40.0, "r": 22.0, "col": Color(0.6, 0.8, 0.95, 0.9), "w": 2.0}, 0.2, 0.6)
					_fx.cue("shake", {"amp": 2.5, "d": 0.25}, 0.2)
			"spawn":
				var stx := String(ev.get("text", ""))
				_floats.append({"x": fx, "y": FIGHT_FEET - 92.0, "text": stx if stx != "" else "wächst nach", "col": VIOLET, "t": 1.2, "big": false, "wait": 0.0})
				if loud:
					Sfx.play("bones" if stx == "beschworen" else "tentacle", -3.0)
					_fx.add("dust", {"x": fx}, 0.0, 0.6)
					_fx.cue("shake", {"amp": 1.5, "d": 0.2}, 0.0)
			"text":
				var tx := String(ev.get("text", ""))
				var tcol := GREEN if tx == "frei!" else (RED if tx in ["gepackt!", "spannt sich!", "rastet aus!"] else Color(0.75, 0.7, 0.95))
				_floats.append({"x": fx, "y": FIGHT_FEET - (150.0 if _is_big(who) else 92.0), "text": tx, "col": tcol, "t": 1.4, "big": tx in ["spannt sich!", "unterbrochen!"], "wait": 0.0})
				if loud and tx == "spannt sich!":
					Sfx.play("kraken_roar")
					_fx.cue("shake", {"amp": 2.0, "d": 0.5}, 0.0)
				elif loud and tx == "gepackt!":
					Sfx.play("tentacle", 0.0, 0.2)
			"heroic":
				if loud:
					Sfx.play("heroic")
					_fx.show_big("HELDENMUT", "%s: %s" % [who.name, String(ev.get("text", ""))], GOLD, 2.3)
					_fx.flash(Color(1.0, 0.85, 0.4, 0.4), 0.55)
					_fx.add("ring", {"x": fx, "y": FIGHT_FEET - 52.0, "r": 40.0, "col": Color(1.0, 0.85, 0.4, 0.9), "w": 2.0}, 0.0, 0.8)
					_fx.add("ring", {"x": fx, "y": FIGHT_FEET - 52.0, "r": 24.0, "col": Color(1.0, 1.0, 0.8, 0.9), "w": 1.0}, 0.15, 0.7)
					_slow(2.4)
			"snap":
				if loud:
					Sfx.play("snap")
					_fx.show_big("ZUSAMMENBRUCH", "%s: %s" % [who.name, String(ev.get("text", ""))], Color(0.9, 0.35, 0.35), 2.3)
					_fx.flash(Color(0.45, 0.0, 0.1, 0.45), 0.6)
					_fx.cue("shake", {"amp": 4.0, "d": 0.5}, 0.0)
					_slow(2.4)


## Die Schlussansage: Sieg, Niederlage oder Rückzug, bevor es weitergeht.
func _fight_outro(c: Combat) -> void:
	match c.result:
		"win":
			var boss := c.formation == "kraken"
			_fx.show_big("DER KRAKEN SINKT" if boss else "SIEG", "%d Gegner gefallen" % c.killed if not boss else "Das Meer ist wieder still", GOLD, voy.combat_outro)
			_fx.flash(Color(1.0, 0.85, 0.4, 0.4), 0.8)
			Sfx.play("bell")
		"lose":
			_fx.show_big("NIEDERLAGE", "niemand steht mehr", Color(0.9, 0.35, 0.35), voy.combat_outro)
			_fx.flash(Color(0.4, 0.0, 0.05, 0.5), 0.8)
			Sfx.play("death")
		_:
			_fx.show_big("RÜCKZUG", "ihr zieht euch zurück", Color(0.75, 0.78, 0.82), voy.combat_outro)


## Das Kampftempo dehnen, damit eine große Wirkung nicht vom nächsten Zug überrollt wird.
func _slow(seconds: float) -> void:
	if voy != null:
		voy._combat_t = maxf(voy._combat_t, seconds)


## Name der Fertigkeit für das Banner; leer für alles ohne Namen.
func _skill_label(sk: String) -> String:
	if Roles.SKILLS.has(sk):
		return String(Roles.skill(sk)["name"])
	if sk == "f_kr_wuerg":
		return "Würgen"
	return ""


## Wirkung beim Ausholen: Lieder, Schild, Klage, Tinte, Zerquetschen, Schüsse, Wut, Nachladen, Horn, Beschwörung.
func _fx_go(c: Combat, who: Combat.Fighter, sk: String) -> void:
	var gx := _fig_x(who)
	var gy := FIGHT_FEET - 60.0
	var dirv := 1.0 if who.side == 0 else -1.0
	match FightFx.go_fx(sk):
		"shield":
			_fx.add("shield", {"x": gx + 16.0 * dirv, "y": FIGHT_FEET - 52.0}, 0.0, 0.7)
		"notes":
			_fx.add("notes", {"x": gx, "y": FIGHT_FEET - 64.0, "col": Color(0.7, 0.85, 1.0)}, 0.0, 1.1)
		"warsong":
			_fx.add("notes", {"x": gx, "y": FIGHT_FEET - 64.0, "col": GOLD}, 0.0, 1.1)
			for h in c.heroes:
				_fx.add("ring", {"x": _fig_x(h), "y": FIGHT_FEET - 48.0, "r": 16.0, "col": Color(GOLD, 0.9), "w": 1.0}, 0.2, 0.6)
		"wail":
			for i in 3:
				_fx.add("ring", {"x": gx, "y": FIGHT_FEET - 60.0, "r": 90.0, "col": Color(0.6, 0.95, 0.8, 0.7), "w": 2.0}, float(i) * 0.15, 0.8)
		"ink":
			_fx.add("ink", {}, 0.1, 1.3)
			_fx.cue("shake", {"amp": 1.5, "d": 0.3}, 0.2)
		"crush":
			_fx.cue("flash", {"col": Color(0.5, 0.0, 0.05, 0.5), "d": 0.6}, 0.3)
			_fx.cue("shake", {"amp": 6.0, "d": 0.7}, 0.3)
			_slow(1.5)
		"taunt":
			for i in 2:
				_fx.add("ring", {"x": gx, "y": FIGHT_FEET - 56.0, "r": 34.0, "col": Color(0.95, 0.4, 0.3, 0.9), "w": 2.0}, float(i) * 0.12, 0.6)
			_fx.cue("shake", {"amp": 1.5, "d": 0.2}, 0.0)
		"rage":
			for i in 3:
				_fx.add("ring", {"x": gx, "y": FIGHT_FEET - 52.0, "r": 26.0, "col": Color(1.0, 0.45, 0.2, 0.9), "w": 2.0}, float(i) * 0.1, 0.5)
			_fx.cue("flash", {"col": Color(0.8, 0.15, 0.1, 0.28), "d": 0.3}, 0.0)
		"reload":
			_fx.add("ring", {"x": gx + 16.0 * dirv, "y": gy, "r": 10.0, "col": Color(0.85, 0.85, 0.9, 0.8), "w": 1.0}, 0.0, 0.35)
			_fx.add("spark", {"x": gx + 16.0 * dirv, "y": gy, "col": Color(1.0, 0.85, 0.4), "n": 4, "dir": dirv}, 0.3, 0.4)
		"horn":
			for i in 3:
				_fx.add("ring", {"x": gx, "y": FIGHT_FEET - 72.0, "r": 70.0, "col": Color(1.0, 0.7, 0.3, 0.7), "w": 2.0}, float(i) * 0.14, 0.7)
		"summon":
			for i in 2:
				_fx.add("ring", {"x": FIGHT_FOE_X[0], "y": FIGHT_FEET - 40.0, "r": 26.0, "col": Color(0.7, 0.4, 0.95, 0.9), "w": 2.0}, 0.15 + float(i) * 0.15, 0.7)
			_fx.cue("shake", {"amp": 2.0, "d": 0.3}, 0.2)
		"bullet":
			# Mündungsfeuer sofort, alle Kugeln fliegen danach einzeln zu ihren Zielen
			_fx.add("muzzle", {"x": gx + 26.0 * dirv, "y": gy, "dir": dirv}, 0.0, 0.9)
			_fx.cue("flash", {"col": Color(1.0, 0.95, 0.8, 0.22), "d": 0.12}, 0.0)
			_fx.cue("shake", {"amp": 2.0, "d": 0.18}, 0.0)


## Wirkung eines Treffers am Ziel: Hieb, Pfeil und Kugel im Flug, Biss, Peitschenhieb; Funken; Wucht bei Krit und schwerem Schaden.
func _fx_hit(who: Combat.Fighter, sk: String, hw: float, crit: bool, dmg: int) -> void:
	var hx := _fig_x(who)
	var hy := FIGHT_FEET - 60.0
	var dirv := 1.0 if who.side == 1 else -1.0  # Richtung vom Angreifer zum Ziel
	if FightFx.is_flight(sk) and _ev_actor != null and sk == _ev_sk:
		var ax := _fig_x(_ev_actor)
		match FightFx.go_fx(sk):
			"arrow":
				_fx.add("arrow", {"x": ax + dirv * 22.0, "y": hy, "x2": hx, "y2": hy}, maxf(hw - 0.2, 0.0), 0.2)
			"bullet":
				_fx.add("bullet", {"x": ax + dirv * 30.0, "y": hy, "x2": hx, "y2": hy}, maxf(hw - 0.09, 0.0), 0.09)
			_:
				_fx.add("whip", {"x": ax - dirv * 8.0, "y": FIGHT_FEET - 96.0, "x2": hx, "y2": hy}, maxf(hw - 0.22, 0.0), 0.45)
		_fx.add("ring", {"x": hx, "y": hy, "r": 9.0, "col": Color(1, 1, 1, 0.8), "w": 1.0}, hw, 0.2)
	match FightFx.hit_fx(sk):
		"slash":
			_fx.add("slash", {"x": hx, "y": hy, "dir": dirv, "crit": crit}, hw, 0.28)
		"chop":
			_fx.add("slash", {"x": hx, "y": hy, "dir": dirv, "heavy": true, "crit": crit}, hw, 0.34)
		"bash":
			_fx.add("bash", {"x": hx, "y": hy, "heavy": dmg >= 20}, hw, 0.3)
		"bite":
			_fx.add("bite", {"x": hx, "y": hy}, hw, 0.4)
	if sk == "f_kr_peitsche" or sk == "f_kr_griff" or sk == "f_kr_wuerg":
		_fx.add("dust", {"x": hx}, hw, 0.5)
	# Funken in der Farbe des Getroffenen
	var spark_col := Color(0.85, 0.2, 0.18)
	if who.side == 1:
		if who.kind in ["tentakel", "kraken"]:
			spark_col = Color(0.65, 0.4, 0.85)
		elif who.immune.has("bleed"):
			spark_col = Color(0.8, 0.95, 0.85)
	if crit:
		spark_col = Color(1.0, 0.82, 0.3)
	_fx.add("spark", {"x": hx, "y": hy, "col": spark_col, "n": 9 if crit else (6 if dmg >= 15 else 4), "dir": -dirv}, hw, 0.5)
	if crit:
		_fx.cue("flash", {"col": Color(1.0, 0.85, 0.4, 0.3), "d": 0.2}, hw)
		_fx.cue("shake", {"amp": 2.5, "d": 0.25}, hw)
		_fx.cue("freeze", {"d": 0.07}, hw)
		_fx.cue("zoom", {"amp": 0.05, "d": 0.3, "fx": hx, "fy": hy}, hw)
		_fx.cue("slowmo", {"f": 0.5, "d": 0.25}, hw)
		_slow(1.1)
	elif dmg >= 24:
		_fx.cue("shake", {"amp": 1.5, "d": 0.18}, hw)


## Ein Fehlschlag: der Pfeil oder die Kugel fliegt vorbei, der Hieb geht ins Leere.
func _fx_miss(who: Combat.Fighter, sk: String, hw: float) -> void:
	var hx := _fig_x(who)
	var hy := FIGHT_FEET - 60.0
	var dirv := 1.0 if who.side == 1 else -1.0
	if FightFx.is_flight(sk) and _ev_actor != null and sk == _ev_sk and FightFx.go_fx(sk) == "arrow":
		var ax := _fig_x(_ev_actor)
		_fx.add("arrow", {"x": ax + dirv * 22.0, "y": hy, "x2": hx + dirv * 80.0, "y2": hy + 12.0, "miss": true}, maxf(hw - 0.2, 0.0), 0.3)
	elif FightFx.is_flight(sk) and _ev_actor != null and sk == _ev_sk and FightFx.go_fx(sk) == "bullet":
		var bx := _fig_x(_ev_actor)
		_fx.add("bullet", {"x": bx + dirv * 30.0, "y": hy, "x2": hx + dirv * 120.0, "y2": hy + 8.0, "miss": true}, maxf(hw - 0.09, 0.0), 0.2)
		_fx.add("spark", {"x": hx + dirv * 52.0, "y": hy + 28.0, "col": Color(0.8, 0.75, 0.6), "n": 3, "dir": -dirv}, hw + 0.1, 0.35)
	elif FightFx.hit_fx(sk) in ["slash", "chop"]:
		_fx.add("slash", {"x": hx - dirv * 12.0, "y": hy, "dir": dirv, "faint": true}, hw, 0.25)


func _tick_fight(delta: float) -> void:
	if not _fx.tick(delta):
		return  # kurzes Einfrieren bei Krit und Tod
	delta *= _fx.time_scale()  # Zeitlupe beim letzten Gegner und beim Tod eines Mannes
	for f in _anim.keys():
		var a: Dictionary = _anim[f]
		if float(a.get("wait", 0.0)) > 0.0:
			a["wait"] = float(a["wait"]) - delta
			continue
		a["t"] = float(a["t"]) - delta
		if float(a["t"]) <= 0.0:
			_anim.erase(f)
	for fl in _floats:
		if float(fl.get("wait", 0.0)) > 0.0:
			fl["wait"] = float(fl["wait"]) - delta
			continue
		fl["t"] = float(fl["t"]) - delta
		fl["y"] = float(fl["y"]) - 16.0 * delta
	_floats = _floats.filter(func(d: Dictionary) -> bool: return float(d["t"]) > 0.0)
	for g in _ghosts:
		g["t"] = float(g["t"]) - delta
	_ghosts = _ghosts.filter(func(d: Dictionary) -> bool: return float(d["t"]) > 0.0)


## Wie hell ein Kämpfer steht (0,5 bis 1,0): der Handelnde, gültige Ziele und wer gerade getroffen wird oder zuschlägt stehen im
## Licht, alle anderen im Halbdunkel. Der Wert wechselt weich, damit das Licht von einem zum anderen wandert.
func _focus_light(c: Combat, f: Combat.Fighter, valid: bool, busy: bool) -> float:
	var target := 1.0
	if c.state != "done" and c.actor != null and not busy and c.actor != f and not valid:
		if _fight_skill != "" or _fight_move:
			target = 0.5  # die Zielwahl läuft: nur die Ziele leuchten
		else:
			target = 0.64 if f.side == 0 else 0.72
	var cur := float(_lit.get(f, target))
	cur = move_toward(cur, target, get_process_delta_time() * 3.0)
	_lit[f] = cur
	return cur


## part: 0 nur die Figur (mit Licht und Markierungen), 1 nur das Schild darunter (Name, Kraft, Zustände), 2 beides.
## Die Figuren des Atlas (44x56) werden doppelt gezeichnet; die Füße stehen auf FIGHT_FEET, der Riese auf FIGHT_BIG_SOLE.
func _draw_fighter(c: Combat, f: Combat.Fighter, mouse: Vector2, valid: bool, part: int = 2) -> void:
	if part != 1:
		_draw_fighter_body(c, f, valid)
	if part != 0:
		_draw_fighter_plate(c, f, valid)


func _draw_fighter_body(c: Combat, f: Combat.Fighter, valid: bool) -> void:
	if _combat_tex == null:
		_combat_tex = load("res://assets/combat.png") as Texture2D
	var cx := _fig_x(f)
	var a: Dictionary = _anim.get(f, {})
	if not a.is_empty() and float(a.get("wait", 0.0)) > 0.0:
		a = {}  # die Reaktion wartet, bis der Hieb oder Pfeil ankommt
	var dir := 1.0 if f.side == 0 else -1.0
	var dx := 0.0
	var tint := Color.WHITE
	var col := (int(Time.get_ticks_msec() / 520) + f.rank) % 2
	if f.side == 0 and f.door:
		col = 4
	if not a.is_empty():
		var tt := float(a["t"])
		match String(a["kind"]):
			"attack":
				col = 2
				dx = dir * 9.0 * FS * float(a.get("mv", 1.0)) * sin(PI * clampf(1.0 - tt / 0.42, 0.0, 1.0))
			"dodge":
				dx = -dir * 5.0 * FS * sin(PI * clampf(1.0 - tt / 0.3, 0.0, 1.0))
			_:
				col = 3
				dx = -dir * 2.0 * FS + (FS if int(tt * 40.0) % 2 == 0 else -FS)
				tint = Color(1.7, 0.6, 0.55)
	var active := c.actor == f and c.state != "done"
	var big := _is_big(f)
	if big and f.charge and a.is_empty():
		col = 4
	var lit := _focus_light(c, f, valid, not a.is_empty())
	var dimc := Color(lit, lit, minf(lit * 1.06, 1.0), 1.0)
	var t_now := float(Time.get_ticks_msec()) / 1000.0
	# Schatten, Lichtkegel und Markierung unter den Füßen
	if not big:
		FightStage.draw_shadow(self, cx, FIGHT_FEET, 64.0, 0.6)
	if active:
		FightStage.draw_spot(self, cx, FIGHT_FEET, f.side == 1, 1.0, t_now)
		var mark := GOLD if f.side == 0 else Color(0.85, 0.42, 0.42)
		draw_rect(Rect2(cx - 32, FIGHT_FEET + 3, 64, 2), mark)
		draw_rect(Rect2(cx - 26, FIGHT_FEET + 5, 52, 1), Color(mark, 0.5))
	if big:
		var bw := float(Foes.BIG[f.kind]["w"])
		var bh := float(Foes.BIG[f.kind]["h"])
		draw_texture_rect_region(_big_texture(f.kind), Rect2(roundf(cx - bw * FS * 0.5 + dx), FIGHT_BIG_SOLE - bh * FS, bw * FS, bh * FS), Rect2(float(col) * bw, 0.0, bw, bh), tint * dimc)
	elif _combat_tex != null:
		var row := _fig_row(f)
		draw_texture_rect_region(_combat_tex, Rect2(roundf(cx - FIG_W * FS * 0.5 + dx), FIGHT_FEET - 52.0 * FS, FIG_W * FS, FIG_H * FS), Rect2(float(col) * FIG_W, float(row) * FIG_H, FIG_W, FIG_H), tint * dimc)
	var rect := _fighter_rect(f)
	if active and f.side == 0:
		var ay := FIGHT_FEET - 106.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, ay), Vector2(cx + 5, ay), Vector2(cx, ay + 6)]), GOLD)
	if valid:
		var pulse := 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) / 160.0)
		draw_rect(rect.grow(2), Color(PAPER, pulse), false, 1.0)
		var vy := rect.position.y - 8.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, vy), Vector2(cx + 5, vy), Vector2(cx, vy + 6)]), RED if f.side == 1 else GREEN)
		_register(rect.grow(4), "ft%d_%d" % [f.side, f.rank])


func _draw_fighter_plate(c: Combat, f: Combat.Fighter, valid: bool) -> void:
	var cx := _fig_x(f)
	var rect := _fighter_rect(f)
	# Name, Kraft, Verzweiflung, Zustände
	var nm := f.name if f.side == 0 else String(Foes.info(f.kind).get("short", f.name))
	_t(Vector2(cx - 26, FIGHT_FEET + 14), nm, PAPER, 8, HORIZONTAL_ALIGNMENT_CENTER, 52.0)
	_bar(cx - 19, FIGHT_FEET + 18, 38, 4, f.hp / f.hp_max, _kraft_col(f.hp) if f.side == 0 else RED)
	if f.side == 0 and f.man != null:
		UiSkin.mini_bar(self, cx - 19, FIGHT_FEET + 24, 38, clampf(f.man.stress, 0.0, 100.0) / 100.0, VIOLET if f.man.stress < 70.0 else RED)
	var info := "%d" % maxi(roundi(f.hp), 0)
	var stext := _status_text(f)
	if stext != "":
		info += "  " + stext
	_t(Vector2(cx - 26, FIGHT_FEET + 36), info, PAPER if stext == "" else GOLD, 7, HORIZONTAL_ALIGNMENT_CENTER, 52.0)
	if f.side == 1 and f.guarded:
		_t(Vector2(cx - 38, FIGHT_FEET + 46), "geschützt" if c._tentacles() > 0 else "offen!", DIM if c._tentacles() > 0 else GREEN, 7, HORIZONTAL_ALIGNMENT_CENTER, 76.0)
	_tip(rect, Tips.fighter(c, f, _fight_skill if valid else ""))


func _draw_fight_overlay() -> void:
	for g in _ghosts:
		var f: Combat.Fighter = g["f"]
		var span := 1.2 if _is_big(f) else 0.7
		var held := float(g["t"]) > span  # der tödliche Hieb ist noch unterwegs: die Figur steht noch
		var al := clampf(float(g["t"]) / span, 0.0, 1.0)
		var gcol := 0 if held else 3
		var gtint := Color.WHITE if held else Color(1.4, 0.7, 0.7, al)
		if _is_big(f):
			var bw := float(Foes.BIG[f.kind]["w"])
			var bh := float(Foes.BIG[f.kind]["h"])
			draw_texture_rect_region(_big_texture(f.kind), Rect2(roundf(_fig_x(f) - bw * FS * 0.5), FIGHT_BIG_SOLE - bh * FS + (1.0 - al) * 28.0, bw * FS, bh * FS), Rect2(float(gcol) * bw, 0.0, bw, bh), gtint)
		elif _combat_tex != null:
			draw_texture_rect_region(_combat_tex, Rect2(roundf(_fig_x(f) - FIG_W * FS * 0.5), FIGHT_FEET - 52.0 * FS + (1.0 - al) * 6.0 * FS, FIG_W * FS, FIG_H * FS), Rect2(float(gcol) * FIG_W, float(_fig_row(f)) * FIG_H, FIG_W, FIG_H), gtint)
	_fx.draw(self, _stage_xf)
	for fl in _floats:
		if float(fl.get("wait", 0.0)) > 0.0:
			continue
		var al2 := clampf(float(fl["t"]) / 0.5, 0.0, 1.0)
		var size := 14 if bool(fl["big"]) else 11
		var col: Color = fl["col"]
		_t(Vector2(float(fl["x"]) - 30.0, float(fl["y"])), String(fl["text"]), Color(col, al2), size, HORIZONTAL_ALIGNMENT_CENTER, 60.0)


## Aufblitzen, Banner mit dem Namen der Fertigkeit und die große Ansage bei Heldenmut und Zusammenbruch.
func _draw_fight_texts() -> void:
	# Vignette: die Ränder der Bühne sind dunkel, bei großen Ansagen noch mehr
	FightStage.draw_vignette(self, 0.34 + (0.3 if not _fx.big.is_empty() else 0.0))
	var fl := _fx.flash_color()
	if fl.a > 0.0:
		draw_rect(Rect2(0, 0, Waves.VIEW_W, FightStage.STAGE_H), fl)
	if not _fx.banner.is_empty():
		var b := _fx.banner
		var al := clampf(float(b["t"]) / 0.3, 0.0, 1.0)
		var r := Rect2(236, 4, 172, 18)
		draw_rect(r, Color(INK, 0.88 * al))
		draw_rect(r, Color(GOLD if int(b["side"]) == 0 else RED, al), false, 1.0)
		SkillIcons.draw(self, String(b.get("icon", "")), Vector2(r.position.x + 1, r.position.y + 1), Color(1, 1, 1, al))
		_t(Vector2(r.position.x + 18, r.position.y + 13), "%s: %s" % [b["who"], b["name"]], Color(PAPER, al), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 20.0)
	if not _fx.big.is_empty():
		var g := _fx.big
		var el := 1.0 - float(g["t"]) / float(g["dur"])
		var al2 := clampf(minf(el * 8.0, (1.0 - el) * 5.0), 0.0, 1.0)
		var col: Color = g["col"]
		draw_rect(Rect2(0, 70, Waves.VIEW_W, 56), Color(0, 0, 0, 0.6 * al2))
		draw_rect(Rect2(0, 70, Waves.VIEW_W, 1), Color(col, al2))
		draw_rect(Rect2(0, 125, Waves.VIEW_W, 1), Color(col, al2))
		_t(Vector2(0, 99), String(g["text"]), Color(col, al2), 24, HORIZONTAL_ALIGNMENT_CENTER, Waves.VIEW_W)
		_t(Vector2(0, 116), String(g["sub"]), Color(PAPER, al2), 10, HORIZONTAL_ALIGNMENT_CENTER, Waves.VIEW_W)


## Aufstellung und Kampf im Platzhalterbild: Kästen statt Figuren, alles klickbar und mit Tooltips.
func _draw_combat_view(mouse: Vector2) -> void:
	_btns.clear()
	_tips.clear()
	draw_rect(Rect2(0, 0, Waves.VIEW_W, Waves.VIEW_H), Color(0.02, 0.03, 0.05, 0.9))
	if voy.combat == null:
		_draw_fight_prep(mouse)
		_draw_tip(mouse)
		return
	var c := voy.combat
	if c.actor != _fight_actor:
		_fight_actor = c.actor
		_fight_skill = ""
		_fight_move = false
	_fight_events(c)
	if c.state == "done" and _outro_for != c and voy.combat_outro > 0.0:
		_outro_for = c
		_fight_outro(c)
	var zsc := _fx.zoom_scale()
	var cam := _fx.offset() + _fx.zoom_offset()
	_stage_xf = Transform2D(Vector2(zsc, 0.0), Vector2(0.0, zsc), cam)
	draw_set_transform(cam, 0.0, Vector2(zsc, zsc))  # Wackeln und Kameraschub: nur die Bühne, nicht die Karten
	var tnow := float(Time.get_ticks_msec()) / 1000.0
	var want_dim := 0.0 if (c.state == "done" or c.actor == null) else 0.24  # der Hintergrund tritt zurück, solange jemand handelt
	_stage_dim = move_toward(_stage_dim, want_dim, get_process_delta_time() * 1.5)
	FightStage.draw_back(self, c.formation, tnow, _stage_dim)
	var armed_ally := _fight_skill != "" and String(Roles.skill(_fight_skill)["tgt"]) == "ally"
	var valid_foes: Array[Combat.Fighter] = []
	var valid_heroes: Array[Combat.Fighter] = []
	if c.state == "hero" and c.actor != null:
		if _fight_skill != "":
			var tl := c.targets(c.actor, _fight_skill)
			if armed_ally:
				valid_heroes = tl
			else:
				valid_foes = tl
		elif _fight_move:
			for hh in c.heroes:
				if hh != c.actor:
					valid_heroes.append(hh)
	for f in c.foes:
		if _is_big(f):
			_draw_fighter(c, f, mouse, valid_foes.has(f), 0)  # Riesen stehen hinter dem Deck und allen anderen
	FightStage.draw_deck(self, c.formation, _stage_dim)
	FightStage.draw_mid(self, c.formation, tnow)
	_t(Vector2(8, 190), "Eure Männer (Reihe 1 vorn)", Color(PAPER, 0.5), 7)
	_t(Vector2(250, 190), "Gegner", Color(PAPER, 0.5), 7)
	for f in c.heroes:
		_draw_fighter(c, f, mouse, valid_heroes.has(f))
	for f in c.foes:
		if not _is_big(f):
			_draw_fighter(c, f, mouse, valid_foes.has(f))
	for f in c.foes:
		if _is_big(f):
			_draw_fighter(c, f, mouse, valid_foes.has(f), 1)
	for f in c.foes:
		if f.holding != null and not f.holding.gone:
			# der Griff: ein Fangarm schwingt in einem Bogen über die Männer zum Gepackten
			var ga := Vector2(_fig_x(f) - 16.0, FIGHT_FEET - 80.0)
			var gb := Vector2(_fig_x(f.holding) + 18.0, FIGHT_FEET - 60.0)
			var gc := Vector2((ga.x + gb.x) * 0.5, FIGHT_FEET - 160.0)
			var arc := PackedVector2Array()
			for k in 13:
				var u := float(k) / 12.0
				arc.append(ga.lerp(gc, u).lerp(gc.lerp(gb, u), u))
			draw_polyline(arc, Color("3a2552"), 8.0)
			draw_polyline(arc, Color("6b4a8a"), 5.0)
			draw_polyline(arc, Color("8a62a6"), 2.0)
	FightStage.draw_front(self, c.formation, tnow)
	_draw_fight_overlay()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_fight_texts()
	# Kopfzeile und Zugleiste über der Bühne
	_t(Vector2(14, 18), "Deckkampf: %s" % String(Foes.FORMATIONS[c.formation]["name"]), GOLD, 11)
	_t(Vector2(0, 18), "Runde %d" % c.round_no, PAPER, 9, HORIZONTAL_ALIGNMENT_RIGHT, 466.0)
	# Zugleiste: wer als Nächstes dran ist
	var up := c.upcoming(10)
	for i in up.size():
		var u := up[i]
		var ur := Rect2(14.0 + float(i) * 22.0, 26.0, 20.0, 14.0)
		draw_rect(ur, INK)
		draw_rect(ur.grow(-1), Color("2a3a55") if u.side == 0 else Color("5b2a2a"))
		if i == 0:
			draw_rect(ur, GOLD, false, 1.0)
		_t(Vector2(ur.position.x, ur.position.y + 11), u.name.substr(0, 1), PAPER, 9, HORIZONTAL_ALIGNMENT_CENTER, ur.size.x)
		_tip(ur, Tips.fighter(c, u, ""))
	# Meldungen
	var jl := c.journal
	var first := maxi(jl.size() - 4, 0)
	for i in range(first, jl.size()):
		var e: Dictionary = jl[i]
		var col := PAPER
		if int(e["kind"]) == 1:
			col = GREEN
		elif int(e["kind"]) == 2:
			col = Color(0.9, 0.45, 0.4)
		_t(Vector2(14, 201.0 + float(i - first) * 8.0), String(e["text"]), col, 7, HORIZONTAL_ALIGNMENT_LEFT, 440.0)
	# Karten des Mannes, der dran ist
	if c.state == "hero" and c.actor != null:
		var opts := _fight_options(c)
		var hint := "Wähle ein Ziel (Q W E R oder Klick), Esc bricht ab." if (_fight_skill != "" or _fight_move) else "%s ist dran. Wähle eine Fertigkeit (1–6)." % c.actor.name
		_t(Vector2(14, 236), hint, GOLD, 9)
		for i in opts.size():
			var sid := opts[i]
			var cr := Rect2(6.0 + float(i) * 78.0, 242.0, 74.0, 58.0)
			var ok := true
			var title := ""
			var info: Array = []
			if sid == "move":
				title = "Platztausch"
				info = ["tauscht mit einem", "anderen Mann"]
				ok = c.heroes.size() > 1
			elif sid == "flee":
				title = "Rückzug"
				info = ["Kampf endet ohne", "Sieg"]
			else:
				var sk := Roles.skill(sid)
				title = String(sk["name"])
				ok = c.can_use(c.actor, sid)
				info = Tips.skill_short(c, c.actor, sid)
			var armed := _fight_skill == sid or (sid == "move" and _fight_move)
			var hover := ok and cr.has_point(mouse)
			_card(cr, UiSkin.State.SELECTED if armed else (UiSkin.State.HOVER if hover else (UiSkin.State.NORMAL if ok else UiSkin.State.DISABLED)))
			var icon := "swap" if sid == "move" else ("flee" if sid == "flee" else Roles.icon_of(sid))
			SkillIcons.draw(self, icon, cr.position + Vector2(4, 4), Color.WHITE if ok else Color(1, 1, 1, 0.4))
			_t(cr.position + Vector2(22, 11), "%d" % (i + 1), Color(DIM, 0.9) if not ok else Color(GOLD, 0.7), 7)
			_t(cr.position + Vector2(29, 13), title, GOLD if ok else DIM, 8 if title.length() <= 10 else 7, HORIZONTAL_ALIGNMENT_LEFT, 44.0)
			for k in info.size():
				_t(cr.position + Vector2(5, 31 + k * 10), String(info[k]), PAPER if ok else Color(DIM, 0.8), 7, HORIZONTAL_ALIGNMENT_LEFT, 66.0)
			if ok:
				_register(cr, "fs%d" % i)
			if sid != "move" and sid != "flee":
				_tip(cr, Tips.skill(c, c.actor, sid))
		var wait_r := Rect2(6, 302, 150, 12)
		_t(Vector2(14, 311), "Abwarten (Leertaste)", Color(PAPER, 0.9) if wait_r.has_point(mouse) else Color(DIM, 0.9), 8)
		_register(wait_r, "fwait")
	elif c.state == "foe" and c.actor != null:
		_t(Vector2(14, 246), "%s ist am Zug …" % c.actor.name, Color(0.9, 0.45, 0.4), 10)
	_draw_tip(mouse)


## Aufstellung: bis zu vier Kämpfer wählen; wer zuerst steht, kämpft vorn. Über den Symbolen wählt man die Fertigkeiten.
func _draw_fight_prep(mouse: Vector2) -> void:
	var panel := Rect2(14, 8, 452, 304)
	UiSkin.panel(self, panel, UiSkin.BRONZE, 2, "tile_stone")
	var reg := _loadout_man == null  # solange die Fertigkeitenwahl offen ist, bleibt alles dahinter stumm
	var formation := String(voy.fight_prep.get("formation", ""))
	_t(Vector2(24, 34), "Aufstellung", GOLD, 16, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _lore)
	_t(Vector2(24, 34), "gegen: %s" % String(Foes.FORMATIONS[formation]["name"]), RED, 9, HORIZONTAL_ALIGNMENT_RIGHT, 424.0)
	UiSkin.rule(self, 24.0, 456.0, 39.0, UiSkin.BRONZE, false)
	_t(Vector2(24, 50), "Bis zu vier Männer kämpfen, der Rest bleibt zurück. Wer zuerst steht, kämpft vorn. Symbole anklicken: Fertigkeiten wählen.", DIM, 7, HORIZONTAL_ALIGNMENT_LEFT, 430.0)
	var pool: Array = voy.fight_prep.get("pool", [])
	var party: Array = voy.fight_prep.get("party", [])
	# links: alle Männer
	for i in pool.size():
		var m: CrewMember = pool[i]
		var rr := Rect2(22, 58.0 + float(i) * 19.0, 236, 18)
		var inp := party.has(m)
		var hh := reg and rr.has_point(mouse)
		_card(rr, UiSkin.State.SELECTED if inp else (UiSkin.State.HOVER if hh else UiSkin.State.NORMAL))
		UiSkin.portrait(self, rr.position + Vector2(4, 2), m.look)
		_t(rr.position + Vector2(19, 12), m.display_name, _name_color(m), 8, HORIZONTAL_ALIGNMENT_LEFT, 50.0)
		_t(rr.position + Vector2(70, 12), String(Roles.role(m.role)["short"]), Color(DIM, 0.95), 7)
		UiSkin.mini_bar(self, rr.position.x + 108.0, rr.position.y + 4.0, 70.0, m.kraft / 100.0, _kraft_col(m.kraft))
		UiSkin.mini_bar(self, rr.position.x + 108.0, rr.position.y + 10.0, 70.0, clampf(m.stress, 0.0, 100.0) / 100.0, VIOLET if m.stress < 70.0 else RED)
		if inp:
			_t(rr.position + Vector2(182, 12), "Reihe %d" % (party.find(m) + 1), GOLD, 8)
		else:
			var where := "Reserve" if m.state == CrewMember.State.RESERVE else (String(Stations.NAMES[Stations.slot_station(m.slot)]) if m.slot >= 0 else "")
			_t(rr.position + Vector2(182, 12), where, Color(DIM, 0.8), 7, HORIZONTAL_ALIGNMENT_LEFT, 52.0)
		if reg:
			_register(rr, "fp%d" % i)
			_tip(rr, Tips.fight_man(voy, m))
	# rechts: die gewählte Aufstellung mit den Symbolen der gewählten Fertigkeiten
	var rx := 274.0
	draw_rect(Rect2(rx - 6, 54, 1, 232), Color(DIM, 0.3))
	_t(Vector2(rx, 66), "Kampfreihe (vorn zuerst)", GOLD, 9)
	for i in 4:
		var pr := Rect2(rx, 70.0 + float(i) * 24.0, 184, 22)
		if i < party.size():
			var m2: CrewMember = party[i]
			_card(pr, UiSkin.State.NORMAL)
			_t(pr.position + Vector2(5, 14), "%d %s" % [i + 1, m2.display_name], PAPER, 8, HORIZONTAL_ALIGNMENT_LEFT, 44.0)
			var picks := m2.skills()
			var strip := Rect2(pr.position.x + 52.0, pr.position.y + 3.0, 70.0, 16.0)
			for k in picks.size():
				SkillIcons.draw(self, Roles.icon_of(String(picks[k])), strip.position + Vector2(float(k) * 17.0, 0.0))
			if reg and strip.has_point(mouse):
				draw_rect(strip.grow(1), Color(GOLD, 0.8), false, 1.0)
			var up := Rect2(pr.end.x - 40, pr.position.y + 4, 16, 14)
			var dn := Rect2(pr.end.x - 22, pr.position.y + 4, 16, 14)
			_small_button(up, "▲", reg and up.has_point(mouse), i > 0)
			_small_button(dn, "▼", reg and dn.has_point(mouse), i < party.size() - 1)
			if reg:
				_register(strip, "fl%d" % i)
				_tip(strip, Tips.loadout(m2))
				if i > 0:
					_register(up, "fu%d" % i)
				if i < party.size() - 1:
					_register(dn, "fd%d" % i)
		else:
			_card(pr, UiSkin.State.DISABLED, 0.55)
			_t(pr.position + Vector2(6, 14), "%d  frei" % (i + 1), DIM, 9)
	# Gegner im Überblick, mit ihrer Aufgabe im Kampf
	_t(Vector2(rx, 182), "Gegner", RED, 9)
	var units: Array = voy.fight_prep.get("units", [])
	for i in units.size():
		var key := String(units[i])
		var t: Dictionary = Foes.info(key)
		var hint := Foes.role_hint(key)
		var line := "%d  %s  (Kraft %d)" % [i + 1, t["name"], roundi(float(t["hp"]) * Combat.FOE_HP * (1.0 + Combat.STAGE_HP * float(voy.stage - 1)))]
		_t(Vector2(rx, 195.0 + float(i) * 10.0), line + ("  · " + hint if hint != "" else ""), PAPER if hint == "" else GOLD, 8, HORIZONTAL_ALIGNMENT_LEFT, 186.0)
	var auto_b := Rect2(rx, 244, 90, 16)
	_small_button(auto_b, "Beste vier (A)", reg and auto_b.has_point(mouse))
	var go := Rect2(rx + 94, 244, 90, 16)
	var can_go := party.size() > 0
	_small_button(go, "Kampf! (Enter)", reg and go.has_point(mouse) and can_go, can_go)
	if reg:
		_register(auto_b, "fauto")
		_tip(auto_b, Tips.fight_auto())
		if can_go:
			_register(go, "fgo")
	_t(Vector2(rx, 278), "Tempo und Rolle bestimmen, wer wann was kann.", Color(DIM, 0.85), 7, HORIZONTAL_ALIGNMENT_LEFT, 186.0)
	if _loadout_man != null:
		_draw_loadout(mouse)


## Die Wahl der Fertigkeiten: sechs zur Auswahl, höchstens vier im Kampf.
func _draw_loadout(mouse: Vector2) -> void:
	var m := _loadout_man
	var box := Rect2(36, 40, 408, 256)
	draw_rect(Rect2(14, 8, 452, 304), Color(0, 0, 0, 0.6))
	UiSkin.panel(self, box, UiSkin.BRONZE, 2, "tile_stone")
	_t(Vector2(48, 62), "Fertigkeiten: %s, %s" % [m.display_name, Roles.role_name(m.role)], GOLD, 12)
	_t(Vector2(48, 76), "Wähle bis zu vier der sechs. Die Wahl gilt für alle weiteren Kämpfe, bis du sie änderst.", DIM, 7, HORIZONTAL_ALIGNMENT_LEFT, 384.0)
	var chosen: Array = m.skills()
	var pool := Roles.pool(m.role)
	for i in pool.size():
		var sid := String(pool[i])
		var sk := Roles.skill(sid)
		var rr := Rect2(46, 84.0 + float(i) * 30.0, 388, 28)
		var on := chosen.has(sid)
		var hh := rr.has_point(mouse)
		_card(rr, UiSkin.State.SELECTED if on else (UiSkin.State.HOVER if hh else UiSkin.State.NORMAL))
		SkillIcons.draw(self, Roles.icon_of(sid), rr.position + Vector2(5, 6), Color.WHITE if on else Color(1, 1, 1, 0.6))
		_t(rr.position + Vector2(28, 12), String(sk["name"]), GOLD if on else PAPER, 9, HORIZONTAL_ALIGNMENT_LEFT, 120.0)
		_t(rr.position + Vector2(28, 23), String(sk["desc"]), Color(PAPER, 0.85) if on else Color(DIM, 0.95), 6, HORIZONTAL_ALIGNMENT_LEFT, 300.0)
		_t(rr.position + Vector2(rr.size.x - 46, 17), "gewählt" if on else "", GREEN, 8, HORIZONTAL_ALIGNMENT_LEFT, 44.0)
		_register(rr, "lo%d" % i)
	var warn := ""
	if m.role == Roles.Id.MUSKET and not chosen.has("m_nachladen"):
		warn = "Ohne Nachladen ist die Muskete nach einem Schuss nutzlos."
	elif chosen.size() < Roles.MAX_LOADOUT:
		warn = "Noch %d Platz frei." % (Roles.MAX_LOADOUT - chosen.size())
	_t(Vector2(48, 284), warn, RED if m.role == Roles.Id.MUSKET and not chosen.has("m_nachladen") else DIM, 8, HORIZONTAL_ALIGNMENT_LEFT, 200.0)
	var def_b := Rect2(256, 274, 84, 16)
	var done_b := Rect2(348, 274, 84, 16)
	_small_button(def_b, "Standard", def_b.has_point(mouse))
	_small_button(done_b, "Fertig (Esc)", done_b.has_point(mouse))
	_register(def_b, "lodef")
	_register(done_b, "lodone")
	_draw_tip(mouse)


## Eine Fertigkeit ein- oder ausschalten; die Reihenfolge folgt dem Pool.
func _loadout_toggle(sid: String) -> void:
	if _loadout_man == null:
		return
	var cur: Array = _loadout_man.skills()
	if cur.has(sid):
		if cur.size() > 1:
			cur.erase(sid)
	elif cur.size() < Roles.MAX_LOADOUT:
		cur.append(sid)
	var ordered: Array = []
	for p in Roles.pool(_loadout_man.role):
		if cur.has(p):
			ordered.append(p)
	_loadout_man.loadout = ordered


# --- Mannschaftsansicht -------------------------------------------------------

func toggle_crew() -> void:
	if crew_open:
		crew_open = false
		if voy != null:
			voy.selected = null
		return
	if voy != null and not voy.ended and (voy.phase == Voyage.Phase.PLAN or voy.phase == Voyage.Phase.ENCOUNTER):
		crew_open = true
		_help = false
		_crew_pick = null


## Klick auf einen Platz der Liste. Umgestellt wird nur in der Planung, ansehen geht auch bei Begegnungen.
## Klick auf einen Reservisten (unter Deck).
func reserve_click(k: int) -> void:
	if k < 0 or k >= voy.reserve.size():
		return
	_crew_pick = voy.reserve[k]
	voy.click_crew(voy.reserve[k])


func crew_click(seat: int) -> void:
	if seat < 0 or seat >= voy.slot_owner.size():
		return
	_crew_pick = voy.slot_owner[seat]
	voy.click_seat(seat)


func _seat_rect(i: int) -> Rect2:
	return Rect2(22, 62 + i * 32, 240, 29)


## Schreibt Text mit Umbruch und gibt die Zeile darunter zurück.
func _wrap(text: String, x: float, y: float, w: float, size: int, col: Color) -> float:
	var h := _ui.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, size).y
	var pos := Vector2(x, y + _ui.get_ascent(size))
	draw_multiline_string_outline(_ui, pos, text, HORIZONTAL_ALIGNMENT_LEFT, w, size, -1, 3, INK)
	draw_multiline_string(_ui, pos, text, HORIZONTAL_ALIGNMENT_LEFT, w, size, -1, col)
	return y + h + 3.0


func _draw_crew_manager(mouse: Vector2) -> void:
	_btns.clear()  # nur die Schaltflächen der Mannschaftsansicht zählen, die Hauptansicht darunter nicht
	_tips.clear()
	draw_rect(Rect2(0, 0, Waves.VIEW_W, Waves.VIEW_H), Color(0, 0, 0, 0.88))
	var panel := Rect2(14, 8, 452, 304)
	UiSkin.panel(self, panel, UiSkin.BRONZE, 2, "tile_stone")
	_t(Vector2(24, 34), "Mannschaft", GOLD, 16, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _lore)
	UiSkin.rule(self, 24.0, 456.0, 39.0, UiSkin.BRONZE, false)
	var close := Rect2(394, 17, 60, 16)
	_small_button(close, "Schließen", close.has_point(mouse))
	_register(close, "kx")
	var rel_r := Rect2(284, 17, 106, 16)
	_small_button(rel_r, "Ablösung: an" if voy.relief else "Ablösung: aus", rel_r.has_point(mouse))
	_register(rel_r, "krel")
	_tip(rel_r, Tips.relief(voy))
	var can_move := voy.can_arrange()
	var hint := "Mann anklicken, dann einen anderen Mann (tauschen) oder einen freien Platz (hinsetzen)." if can_move else "Umstellen geht nur in der Planung, im Hafen und im Lager."
	_t(Vector2(24, 49), hint, DIM, 8)

	# Linke Spalte: die sieben Plätze von Heck bis Bug
	var hover_man: CrewMember = null
	var focus := voy.selected
	for i in voy.slot_owner.size():
		var r := _seat_rect(i)
		var m: CrewMember = voy.slot_owner[i]
		var st := Stations.slot_station(i)
		var hover := r.has_point(mouse)
		if hover and m != null:
			hover_man = m
		var border := Color(DIM, 0.3)
		var thick := 1.0
		if m != null and voy.selected == m:
			border = GOLD
			thick = 2.0
		elif hover:
			border = PAPER
		else:
			var anchor := voy.selected if voy.selected != null else hover_man
			if anchor != null and m != null and anchor != m:
				for p in voy.bond_partners(anchor):
					if p["other"] == m:
						border = _bond_color(int(p["type"]))
						thick = 2.0
		var sstate := UiSkin.State.NORMAL
		var scol2 := UiSkin.BRONZE_LO.lerp(UiSkin.BRONZE, 0.5)
		if thick >= 2.0 and border == GOLD:
			sstate = UiSkin.State.SELECTED
		elif thick >= 2.0:
			scol2 = border
			sstate = UiSkin.State.HOVER
		elif border == PAPER:
			sstate = UiSkin.State.HOVER
		_card(r, sstate, 1.0, scol2 if sstate == UiSkin.State.NORMAL or thick >= 2.0 and border != GOLD else Color(0, 0, 0, 0))
		draw_rect(Rect2(r.position.x + 3, r.position.y + 3, 2, r.size.y - 6), Stations.COLORS[st])
		if m != null:
			UiSkin.portrait(self, r.position + Vector2(9, 7), m.look)
			_t(r.position + Vector2(24, 13), m.display_name, _name_color(m), 10)
			_t(r.position + Vector2(24, 24), String(Stations.NAMES[st]), Stations.COLORS[st], 8)
			_t(r.position + Vector2(86, 24), String(Roles.role(m.role)["short"]), Color(DIM, 0.95), 7)
			var bx := r.position.x + 118.0
			var bw := 90.0
			var kcol := _kraft_col(m.kraft)
			_bar(bx, r.position.y + 8.0, bw, 4.0, m.kraft / 100.0, kcol)
			_bar(bx, r.position.y + 17.0, bw, 4.0, m.stress / 100.0, VIOLET if m.stress < 70.0 else RED)
			var pbs := voy.bond_partners(m)
			if not pbs.is_empty():
				var bt2 := int(pbs[0]["type"])
				var bn2 := "bond_b" if bt2 == Voyage.Bond.BROTHER else ("bond_r" if bt2 == Voyage.Bond.RIVAL else "bond_c")
				var gone2 := (pbs[0]["other"] as CrewMember).state == CrewMember.State.DEAD
				UiSkin.spr(self, bn2, Vector2(r.end.x - UiSkin.spr_size(bn2).x - 8.0, r.position.y + 11.0), Color(0.55, 0.55, 0.6) if gone2 else Color.WHITE)
		else:
			_t(r.position + Vector2(24, 13), "frei", DIM, 10)
			_t(r.position + Vector2(24, 24), String(Stations.NAMES[st]), Stations.COLORS[st], 8)
		_register(r, "k%d" % i)
	_t(Vector2(142, 58), "oben Kraft", GREEN, 8)
	_t(Vector2(142 + _ui.get_string_size("oben Kraft  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 58), "unten Verzweiflung", VIOLET, 8)

	# Rechte Spalte: die Reserve unter Deck, in Häfen darunter die Taverne mit den Anwärtern
	var rx := 272.0
	var rw := 186.0
	draw_rect(Rect2(rx - 6, 52, 1, 236), Color(DIM, 0.3))
	var cap := voy.reserve_cap()
	var use_ok := voy.can_use_reserve()
	_t(Vector2(rx, 58), "Reserve  %d / %d" % [voy.reserve.size(), cap], GOLD, 9)
	if not use_ok:
		_t(Vector2(rx, 58), "nur Hafen, Lager, Etappenstart", Color(DIM, 0.8), 7, HORIZONTAL_ALIGNMENT_RIGHT, rw)
	_tip(Rect2(rx, 49, rw, 12), Tips.reserve(voy))
	for k in cap:
		var rr := Rect2(rx, 62.0 + float(k) * 24.0, rw, 22.0)
		if k >= voy.reserve.size():
			_card(rr, UiSkin.State.DISABLED, 0.55)
			_t(rr.position + Vector2(8, 15), "frei", DIM, 9)
			continue
		var rm: CrewMember = voy.reserve[k]
		var rhover := rr.has_point(mouse)
		if rhover:
			hover_man = rm
		var rsel := voy.selected == rm
		_card(rr, UiSkin.State.SELECTED if rsel else (UiSkin.State.HOVER if rhover else UiSkin.State.NORMAL))
		UiSkin.portrait(self, rr.position + Vector2(5, 4), rm.look)
		_t(rr.position + Vector2(20, 15), rm.display_name, _name_color(rm), 9)
		var rbx := rr.position.x + 92.0
		UiSkin.mini_bar(self, rbx, rr.position.y + 6.0, 62.0, rm.kraft / 100.0, _kraft_col(rm.kraft))
		UiSkin.mini_bar(self, rbx, rr.position.y + 13.0, 62.0, clampf(rm.stress, 0.0, 100.0) / 100.0, VIOLET if rm.stress < 70.0 else RED)
		var rpb := voy.bond_partners(rm)
		if not rpb.is_empty():
			var rbt := int(rpb[0]["type"])
			var rbn := "bond_b" if rbt == Voyage.Bond.BROTHER else ("bond_r" if rbt == Voyage.Bond.RIVAL else "bond_c")
			UiSkin.spr(self, rbn, Vector2(rr.end.x - UiSkin.spr_size(rbn).x - 6.0, rr.position.y + 8.0))
		_register(rr, "r%d" % k)
	var in_harbor := voy.phase == Voyage.Phase.ENCOUNTER and Encounters.is_harbor(voy.encounter)
	if in_harbor:
		_t(Vector2(rx, 194), "Taverne: Anwärter", GOLD, 9)
		_t(Vector2(rx, 194), "Beute %d" % roundi(voy.loot), DIM, 8, HORIZONTAL_ALIGNMENT_RIGHT, rw)
		for i in voy.recruits.size():
			var c: Dictionary = voy.recruits[i]
			var hr := Rect2(rx, 198.0 + float(i) * 28.0, rw, 26.0)
			var afford := voy.loot >= float(c["price"]) and voy.can_recruit()
			var hh := hr.has_point(mouse)
			_card(hr, UiSkin.State.HOVER if (hh and afford) else (UiSkin.State.NORMAL if afford else UiSkin.State.DISABLED))
			_t(hr.position + Vector2(7, 11), String(c["name"]), PAPER if afford else DIM, 9)
			var tn: Array[String] = []
			for t in c["traits"]:
				tn.append(String(Traits.DATA[int(t)]["name"]))
			_t(hr.position + Vector2(7, 22), String(Roles.role(int(c.get("role", 0)))["short"]) + " · " + ", ".join(PackedStringArray(tn)), Color(DIM, 0.95), 7)
			_t(hr.position + Vector2(0, 11), "Kraft %d" % int(c["kraft"]), _kraft_col(float(c["kraft"])), 8, HORIZONTAL_ALIGNMENT_RIGHT, rw - 8.0)
			_t(hr.position + Vector2(0, 22), "Beute −%d" % int(c["price"]), GOLD if afford else RED, 8, HORIZONTAL_ALIGNMENT_RIGHT, rw - 8.0)
			if afford:
				_register(hr, "h%d" % i)
			_tip(hr, Tips.recruit(voy, c, afford))
		if voy.recruits.is_empty():
			_t(Vector2(rx, 214), "Heute wartet niemand am Kai.", DIM, 9)
	else:
		_wrap("Mit der Maus über einen Mann: Steckbrief, Müdigkeit, Eigenschaften. Neue Männer gibt es in der Taverne im Hafen.", rx, 196.0, rw, 8, DIM)
	# Entlassen: nur für einen gewählten Reservisten, wo die Reserve erreichbar ist
	if voy.selected != null and voy.selected.state == CrewMember.State.RESERVE and use_ok:
		var dis := Rect2(176, 17, 104, 16)
		_small_button(dis, "Entlassen: %s" % voy.selected.display_name, dis.has_point(mouse))
		_register(dis, "krd")

	# Unten: die Gefallenen dieser Fahrt
	if not voy.fallen_names.is_empty():
		var names := "Gefallen: " + ", ".join(PackedStringArray(voy.fallen_names))
		_wrap(names, 24, 292, 430, 8, Color(RED, 0.85))
	if hover_man != null and hover_man.state != CrewMember.State.DEAD:
		_draw_crew_tooltip(mouse, hover_man)
	else:
		_draw_tip(mouse)


func _draw_help() -> void:
	var r := Rect2(24, 82, 432, 200)
	UiSkin.panel(self, r, UiSkin.BRONZE, 2, "tile_stone")
	_t(Vector2(0, 101), "So funktioniert die Überfahrt", GOLD, 11, HORIZONTAL_ALIGNMENT_CENTER, 480.0)
	UiSkin.rule(self, 60.0, 420.0, 106.0, UiSkin.BRONZE, true)
	var rows := [
		["Seekarte (rechts)", "Kurs wählen: nächsten Knoten anklicken (Q W E)"],
		["1–9  Manöver", "1–3 Segel, 4–6 Ruder, 7–9 Küste, oder die Knöpfe anklicken"],
		["Enter / Auslaufen", "Eine Fahrt fahren. Vorher in Ruhe planen, es gibt keine Eile."],
		["Klick auf Mann  /  C", "wählen, dann tauschen; C öffnet die Mannschaftsansicht"],
		["Kraft (grün)", "sinkt bei Arbeit, ab 40 müde, ab 15 sehr schwach. Ladung = Rast"],
		["A  /  L", "Wachablösung an/aus  ·  Lager aufschlagen (Ankerbucht A auf der Karte)"],
		["Verzweiflung (lila)", "steigt bei Verlusten und Sturm; bei 100 verzagt der Mann"],
		["Buchstaben auf der Karte", "H Handel · I Insel · M Monster · T Hafen · D Dorf"],
		["", "G Draugr · R Räuber · K Kraken · W Wrack"],
		["Maus über einen Mann", "Steckbrief: Eigenschaften, Zustand, Bruder (gold) / Rivale (rot)"],
		["B  /  G", "Schiff und Werft  /  Gedenkstein"],
		["Esc H F11 M + −", "Hauptmenü, Hilfe, Vollbild, Ton an/aus, Lautstärke"],
	]
	var y := 120.0
	for row in rows:
		_t(Vector2(34, y), row[0], PAPER, 9)
		_t(Vector2(150, y), row[1], DIM, 9)
		y += 14.0


## Ende der Fahrt: Ausgang, die Saga des Skalden und die Bilanz.
func _draw_end() -> void:
	draw_rect(Rect2(0, 0, Waves.VIEW_W, Waves.VIEW_H), Color(0, 0, 0, 0.93))
	UiSkin.vignette(self, 1)
	UiSkin.knot_band(self, 0, 480, 10, Color(1, 1, 1, 0.5))
	UiSkin.knot_band(self, 0, 480, 313, Color(1, 1, 1, 0.5))
	var title := "Im Ruhestand" if voy.victory else ("Das Schiff kentert" if voy.cause == "sunk" else "Niemand mehr an Bord")
	_t(Vector2(1, 43), title, UiSkin.BRONZE_LO if voy.victory else Color("4a1a1a"), 22, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	_t(Vector2(0, 42), title, GOLD if voy.victory else RED, 22, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	UiSkin.rule(self, 150.0, 330.0, 50.0, UiSkin.BRONZE if voy.victory else Color("8c2d2d"), true)
	var saga := voy.saga_text
	draw_multiline_string_outline(_lore, Vector2(46, 72), saga, HORIZONTAL_ALIGNMENT_CENTER, 388.0, 10, 12, 3, INK)
	draw_multiline_string(_lore, Vector2(46, 72), saga, HORIZONTAL_ALIGNMENT_CENTER, 388.0, 10, 12, PAPER)
	var alive: PackedStringArray = []
	for m in voy.crew:
		if m.state != CrewMember.State.DEAD:
			alive.append(m.display_name)
	var lines := "Überlebt: %s   ·   Gefallen: %s\nEtappe %d   ·   Stufe %d   ·   Strecke %d Meilen   ·   Beute %d   ·   Gerettet %d   ·   Begegnungen %d" % [
		", ".join(alive) if not alive.is_empty() else "niemand",
		", ".join(PackedStringArray(voy.fallen_names)) if not voy.fallen_names.is_empty() else "niemand",
		voy.stage, voy.level, roundi(voy.total_miles), roundi(voy.loot), voy.rescued_count, voy.encounters_done]
	draw_multiline_string_outline(_ui, Vector2(20, 236), lines, HORIZONTAL_ALIGNMENT_CENTER, 440.0, 9, 3, 3, INK)
	draw_multiline_string(_ui, Vector2(20, 236), lines, HORIZONTAL_ALIGNMENT_CENTER, 440.0, 9, 3, DIM)
	_t(Vector2(0, 280), "[Enter]  Noch eine Fahrt        [Esc]  Hauptmenü        [G]  Gedenkstein", GOLD, 10, HORIZONTAL_ALIGNMENT_CENTER, 480.0)


## Der Gedenkstein: alle Gefallenen und die Sagas der beendeten Fahrten (bleibt zwischen den Fahrten).
func toggle_memorial() -> void:
	memorial_open = not memorial_open
	if memorial_open:
		_mem_data = Persist.load_memorial()
		_mem_runs = _mem_data["runs"]
		_mem_index = _mem_runs.size() - 1


func memorial_step(dir: int) -> void:
	if not _mem_runs.is_empty():
		_mem_index = clampi(_mem_index + dir, 0, _mem_runs.size() - 1)


func _draw_memorial() -> void:
	var r := Rect2(20, 14, 440, 292)
	UiSkin.panel(self, r, UiSkin.BRONZE, 2, "tile_stone")
	_t(Vector2(1, 43), "Gedenkstein", UiSkin.BRONZE_LO, 20, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	_t(Vector2(0, 42), "Gedenkstein", GOLD, 20, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	var tot := Persist.totals(_mem_data)
	UiSkin.title_rule(self, 240.0, 130.0, 66.0)
	_t(Vector2(0, 58), "%d Fahrten  ·  weiteste Etappe %d  ·  %d Gefallene" % [maxi(int(_mem_data.get("count", 0)), _mem_runs.size()), int(tot["best"]), int(tot["fallen"])], DIM, 9, HORIZONTAL_ALIGNMENT_CENTER, 480.0)
	if _mem_runs.is_empty():
		_t(Vector2(0, 160), "Noch keine Fahrt beendet. Hier stehen bald Namen.", PAPER, 11, HORIZONTAL_ALIGNMENT_CENTER, 480.0, _lore)
	else:
		var run2: Dictionary = _mem_runs[_mem_index]
		_t(Vector2(34, 82), "Die Gefallenen der Fahrt %d" % int(run2["n"]), GOLD, 10)
		var fallen_list: Array = run2["fallen"]
		var y := 98.0
		for k in mini(fallen_list.size(), 16):
			var f: Dictionary = fallen_list[k]
			_t(Vector2(34, y), "%s, %s" % [String(f["name"]), String(f["cause"])], PAPER, 8, HORIZONTAL_ALIGNMENT_LEFT, 204.0)
			y += 12.0
		if fallen_list.size() > 16:
			_t(Vector2(34, y), "… und %d weitere" % (fallen_list.size() - 16), DIM, 8)
		elif fallen_list.is_empty():
			_t(Vector2(34, 98), "Niemand ist gefallen.", DIM, 9, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _lore)
		var res := String(run2.get("result", ""))
		var res_txt := "im Ruhestand" if res == "victory" else ("niemand mehr an Bord" if res == "all_dead" else "gekentert")
		var head := "Fahrt %d  ·  %s  ·  Etappe %d, Stufe %d" % [int(run2["n"]), String(run2["date"]), int(run2.get("stage", 1)), int(run2.get("level", 1))]
		_t(Vector2(248, 78), head, GOLD, 9, HORIZONTAL_ALIGNMENT_LEFT, 212.0)
		_t(Vector2(248, 89), res_txt, DIM, 8)
		var saga := String(run2["saga"])
		draw_multiline_string_outline(_lore, Vector2(248, 102), saga, HORIZONTAL_ALIGNMENT_LEFT, 212.0, 8, 19, 3, INK)
		draw_multiline_string(_lore, Vector2(248, 102), saga, HORIZONTAL_ALIGNMENT_LEFT, 212.0, 8, 19, PAPER)
	_t(Vector2(0, 298), "←  →  Fahrten durchblättern        G / Esc  schließen", DIM, 9, HORIZONTAL_ALIGNMENT_CENTER, 480.0)


## Farbe des Kraftbalkens nach Müdigkeitsstufe: frisch grün, müde gold, erschöpft orange, am Ende rot.
func _kraft_col(k: float) -> Color:
	if k >= CrewMember.FRESH_AT:
		return GREEN
	if k >= CrewMember.TIRED_AT:
		return GOLD
	if k >= CrewMember.SPENT_AT:
		return Color("d9803a")
	return RED


func _name_color(m: CrewMember) -> Color:
	if m.afflicted:
		return RED if m.affliction == CrewMember.Affliction.BERSERK else VIOLET
	return PAPER


## Steckbrief eines Mannes beim Überfahren (Karte unten oder Figur an Deck).
func _draw_crew_tooltip(mouse: Vector2, forced: CrewMember = null) -> void:
	var m := forced if forced != null else hover_crew
	var anchor := mouse
	if m == null:
		var i := card_at(mouse)
		if i >= 0:
			m = voy.crew[i]
			anchor = Vector2(card_rect(i).position.x + 40.0, card_rect(i).position.y)
	if m == null or m.state == CrewMember.State.DEAD or voy.ended:
		return
	var rows: Array = []
	rows.append([m.display_name, GOLD, 10])
	rows.append(["Kraft %d   Verzweiflung %d" % [roundi(m.kraft), roundi(m.stress)], PAPER, 9])
	rows.append(["Kampfrolle: %s" % Roles.role_name(m.role), PAPER, 8])
	rows.append(["Müdigkeit: %s (Leistung %d %%). Kraft sinkt bei Arbeit; Verzweiflung steigt bei Sturm, Verlusten und Hunger, bei 100 kippt er." % [m.fatigue_name(), roundi(CrewMember.kraft_efficiency(m.kraft) * 100.0)], _kraft_col(m.kraft), 8])
	if m.slot >= 0:
		rows.append([Tips.station(Stations.slot_station(m.slot)), Stations.COLORS[Stations.slot_station(m.slot)], 8])
	elif m.state == CrewMember.State.RESERVE:
		rows.append(["Unter Deck: arbeitet nicht, erholt sich bei jeder Fahrt (Kraft +15, Verzweiflung −3), isst aber mit.", DIM, 8])
	if m.afflicted:
		var verzagt := m.affliction != CrewMember.Affliction.BERSERK
		rows.append(["%s: %s" % [m.affliction_name(), "halbe Leistung, steckt an" if verzagt else "stärker, aber unberechenbar"], VIOLET if verzagt else RED, 8])
	for t in m.traits:
		var d: Dictionary = Traits.DATA[t]
		rows.append([String(d["name"]), PAPER, 9])
		rows.append([String(d["desc"]), DIM, 8])
	for p in voy.bond_partners(m):
		var other: CrewMember = p["other"]
		var gone := other.state == CrewMember.State.DEAD
		rows.append(["%s von %s%s" % [Voyage.bond_name(int(p["type"])), other.display_name, " (gefallen)" if gone else ""], _bond_color(int(p["type"])), 9])
		rows.append([Voyage.bond_text(int(p["type"]), gone), DIM, 8])
	for gs in [Gear.Slot.WAFFE, Gear.Slot.RUESTUNG, Gear.Slot.AMULETT]:
		if m.gear.has(gs):
			rows.append(["%s: %s" % [Gear.SLOT_NAMES[gs], Gear.name_of(String(m.gear[gs]))], Gear.rarity_color(String(m.gear[gs])), 8])
	if m.weapon_lvl > 0 or m.armor_lvl > 0:
		rows.append(["Schmiede: Waffe Stufe %d, Rüstung Stufe %d" % [m.weapon_lvl, m.armor_lvl], GOLD, 8])
	# Höhe bei Breite w; zu hoch gibt erst mehr Breite, dann werden die letzten Zeilen gekürzt, damit nichts unten abgeschnitten wird
	var w := 174.0
	var max_h := Waves.VIEW_H - 12.0
	var h := _crew_tip_height(rows, w - 2.0)
	if h > max_h:
		w = 250.0
		h = _crew_tip_height(rows, w - 2.0)
	if h > max_h:
		var kept: Array = []
		var used := 10.0
		for row in rows:
			var lh := _ui.get_multiline_string_size(String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, w - 2.0, int(row[2])).y + 3.0
			if used + lh + 12.0 > max_h:
				break
			kept.append(row)
			used += lh
		kept.append(["…", DIM, 8])
		rows = kept
		h = _crew_tip_height(rows, w - 2.0)
	var x := clampf(anchor.x - 90.0, 6.0, Waves.VIEW_W - w - 18.0)
	var y := anchor.y - h - 8.0
	if y < 4.0:
		y = anchor.y + 18.0
	y = clampf(y, 4.0, maxf(Waves.VIEW_H - h - 4.0, 4.0))
	var rect := Rect2(x, y, w + 12.0, h)
	UiSkin.panel(self, rect, UiSkin.BRONZE, 0, "tile_stone")
	var ty := y + 5.0
	for row in rows:
		ty = _wrap(String(row[0]), x + 7.0, ty, w - 2.0, int(row[2]), row[1])


## Höhe des Mannschafts-Tooltips für diese Zeilen bei Breite w (lange Zeilen werden umgebrochen).
func _crew_tip_height(rows: Array, w: float) -> float:
	var h := 12.0
	for row in rows:
		h += _ui.get_multiline_string_size(String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, w, int(row[2])).y + 3.0
	return h
