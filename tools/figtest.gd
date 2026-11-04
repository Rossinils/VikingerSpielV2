extends SceneTree
## Prüft die Rig-Figuren (assets/fig/*.png, scripts/fig_atlas.gd) und FigArt: alle Streifen da, richtige Größe, jedes belegte Bild
## nicht leer und mit 2 px Rand, die weiße Zeile deckt sich mit der Figur, Anker plausibel, Ersatzbilder lösen auf.
## Aufruf: godot --headless --path . --script tools/figtest.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		fails += 1
		print("FEHLER: ", what)


func _init() -> void:
	# --- der Satz der Streifen wird aus Roles und Foes abgeleitet, nicht aus einer Zahl ---
	var want: Array = []
	for id in Roles.FIG_IDS:
		want.append(String(id))
	for k in Foes.TYPES.keys():
		if not Foes.is_big(String(k)):
			want.append(String(k))
	var have: Array = FigAtlas.IDS.duplicate()
	want.sort()
	have.sort()
	check(want == have, "Streifen = Männer (%d) + Gegner ohne Riesen (%d): %d Figuren" % [Roles.FIG_IDS.size(), want.size() - Roles.FIG_IDS.size(), want.size()])
	check(Roles.FIG_IDS.size() == Roles.ROLES.size(), "jede Rolle hat eine Figur")
	check(FigAtlas.FRAMES.size() == FigAtlas.COLUMNS and FigAtlas.COLUMNS == 32, "32 Spalten, 32 Bildnamen")
	check(FigArt.FRAMES == FigAtlas.FRAMES, "FigArt und FigAtlas kennen dieselben Bildnamen")
	var cw := FigAtlas.CELL.x
	var ch := FigAtlas.CELL.y
	var empty_cells: PackedStringArray = []
	var clipped: PackedStringArray = []
	var white_bad: PackedStringArray = []
	var anchor_bad: PackedStringArray = []
	var dims_bad: PackedStringArray = []
	var missing: PackedStringArray = []
	var frames_total := 0
	for id in FigAtlas.IDS:
		var path := "res://assets/fig/%s.png" % id
		if not FileAccess.file_exists(path):
			missing.append(String(id))
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null or img.get_width() != cw * FigAtlas.COLUMNS or img.get_height() != ch * 2:
			dims_bad.append(String(id))
			continue
		var tab: Dictionary = FigAtlas.ANCHORS[id]
		var humans: bool = not (String(id) in ["hund", "tentakel"])
		if humans and tab.size() != FigAtlas.COLUMNS:
			dims_bad.append("%s hat %d statt 32 Bilder" % [id, tab.size()])
		for fr in tab.keys():
			frames_total += 1
			var col := FigAtlas.FRAMES.find(fr)
			var a := img.get_region(Rect2i(col * cw, 0, cw, ch)).get_used_rect()
			var w := img.get_region(Rect2i(col * cw, ch, cw, ch)).get_used_rect()
			if a.size.x < 6 or a.size.y < 6:
				empty_cells.append("%s/%s" % [id, fr])
				continue
			if a.position.x < 2 or a.position.y < 2 or a.end.x > cw - 2 or a.end.y > ch - 2:
				clipped.append("%s/%s" % [id, fr])
			if a != w:
				white_bad.append("%s/%s" % [id, fr])
			var v: Array = tab[fr]
			if v.size() != 8:
				anchor_bad.append("%s/%s (Länge)" % [id, fr])
			else:
				var chest_y := int(v[5])
				var head_y := int(v[7])
				if chest_y < 2 or head_y < chest_y - 2 or head_y > 100 or absi(int(v[0])) > 100 or absi(int(v[2])) > 110:
					anchor_bad.append("%s/%s %s" % [id, fr, v])
		# weiße Zeile wirklich weiß (Stichprobe: ein Bild)
		var wc := img.get_region(Rect2i(0, ch, cw, ch))
		var ok_white := true
		var seen := 0
		for y in range(0, ch, 3):
			for x in range(0, cw, 3):
				var p := wc.get_pixel(x, y)
				if p.a > 0.5:
					seen += 1
					if p.r < 0.99 or p.g < 0.99 or p.b < 0.99:
						ok_white = false
		if not ok_white:
			white_bad.append("%s (Farbe)" % id)
	check(missing.is_empty(), "alle Streifen liegen in assets/fig/ (fehlend: %s)" % ", ".join(missing))
	check(dims_bad.is_empty(), "Streifen 3712 x 216, Menschen mit 32 Bildern (%s)" % ", ".join(dims_bad))
	check(empty_cells.is_empty(), "%d belegte Bilder, keines leer (%s)" % [frames_total, ", ".join(empty_cells.slice(0, 5))])
	check(clipped.is_empty(), "jedes Bild hält 2 px Rand (%s)" % ", ".join(clipped.slice(0, 5)))
	check(white_bad.is_empty(), "die weiße Zeile deckt sich mit der Figur und ist weiß (%s)" % ", ".join(white_bad.slice(0, 5)))
	check(anchor_bad.is_empty(), "Anker plausibel (%s)" % ", ".join(anchor_bad.slice(0, 3)))
	# Ersatzbilder
	check(FigArt.resolved("axt", "strike_1") == "strike_1", "Mensch: strike_1 ist da")
	check(FigArt.resolved("hund", "strike_1") == "strike_1" and FigArt.resolved("hund", "cheer_1") != "", "Hund: Sprung da, Jubel löst auf")
	check(FigArt.resolved("tentakel", "door_0") != "" and FigArt.resolved("tentakel", "block_0") != "", "Fangarm: fehlende Bilder lösen auf")
	check(FigArt.column("axt", "gibtsnicht") == 0, "unbekannter Name: Ruhebild")
	check(FigArt.column("kraken", "idle_0") == -1, "der Kraken hat keinen Streifen")
	check(FigArt.anchor("schild", "idle_0", "chest").y > 20.0, "Anker Brust über den Füßen")
	check(FigAtlas.ANCHOR_X.get("tentakel", 0) != 0, "Fangarm steht weiter links in der Zelle")
	# Ruhebild nach Zustand
	check(FigArt.rest_frame(0.0, 0, false, false, false) == "idle_0", "Ruhe: idle_0")
	check(FigArt.rest_frame(0.25, 0, false, false, false) == "idle_1", "Ruhe: Atmen nach 0,2 s")
	check(FigArt.rest_frame(0.0, 0, true, false, false).begins_with("ready_"), "am Zug: ready")
	check(FigArt.rest_frame(0.0, 0, true, true, false).begins_with("stun_"), "betäubt: stun vor ready")
	check(FigArt.rest_frame(0.0, 0, true, true, true).begins_with("door_"), "Schwelle: door vor allem")
	var all_known := true
	for id2 in Roles.FIG_IDS:
		all_known = all_known and FigArt.has(String(id2))
	for k2 in Foes.TYPES.keys():
		if not Foes.is_big(String(k2)):
			all_known = all_known and FigArt.has(String(k2))
	check(all_known and not FigArt.has("kraken"), "jede Rolle und jede Gegnerart (außer dem Kraken) hat Anker und Streifen")
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)
