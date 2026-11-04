class_name FightViews
extends RefCounted

class FigView extends RefCounted:
	var f: Combat.Fighter
	var big := false
	var frame := ""               # "" = Ruhe: Renderer wählt idle_0..3 / ready_0..1 / stun_0..1 / door_0..1 nach ready, stun, shown_door und Bühnenuhr; sonst Name aus FigArt.FRAMES
	var ready := false            # am Zug in der Eingabe
	var stun := false
	var off := Vector2.ZERO       # Versatz (Ausfall, Vortreten, Gleiten), ganze Pixel, ohne Kamera, +x = zum Gegner hin (Renderer spiegelt für Gegner)
	var lean := 0.0               # nur Gerüst: Neigung am Kopf in px (Zeilenband-Scherung), + = zum Gegner
	var flash := 0.0              # weißer Frame 0..1 (Director-Anteil; der Renderer nimmt das Maximum mit FxPose.hit)
	var red := 0.0                # Rotstich 0..1
	var lit := 0.0                # 0 = Ortslicht, 1 = Schlüssellicht (3.9)
	var desat_add := 0.0
	var alpha := 1.0
	var outline := Color(0, 0, 0, 0)  # a = 0 aus (Zielwahl: Gold/Rot/Grün)
	var z := 0                    # Zeichenreihenfolge; der Handelnde bekommt den höchsten Wert
	var drop := 0.0               # Vortreten: px tiefer
	var shadow_w := 0.0           # Schatten breiter (px)
	var ghosts: Array[Vector2] = []   # Nachbilder (Versatz gegenüber off), höchstens 3
	var x := 0.0                  # gezeigte Fußmitte (gleitet beim Nachrücken)
	var shown_rank := 0
	var shown_hp := 0.0
	var trail_hp := 0.0           # Nachzieher des Kraftbalkens
	var shown_door := false
	var alive := true             # false: stirbt/ist weg, wird gezeichnet bis alpha 0
	var hit_t := -1.0             # Sekunden seit dem Kontakt (Bühnenzeit), < 0 = kein Treffer aktiv
	var hit_level := 0            # FightLevel
	var hit_dir := 1.0            # Schlagrichtung (+1 nach rechts)
	var frozen := false           # Standbild: Pose halten, Zittern
	var death_kind := ""          # "", crumble, fall, sink, kraken
	var death_t := -1.0
	var death_dir := 1.0
	var status: Array[String] = []    # Zustandsnamen nach StatusIcons.ORDER (Schnappschuss am Kontakt)
	var status_pop := {}              # Name -> Alter in s (0..0,12 poppt)
	var hit_real := 99.0          # Echtzeit-Sekunden seit dem Kontakt (Blitz und Rotstich laufen in Echtzeit, auch im Standbild)
	var white_s := 0.05           # Dauer des weißen Frames (s), danach klingt er in 80 ms ab
	var red_s := 0.15             # Dauer des Rotstichs (s)
	var jitter := 0.0             # Zittern im Standbild: Stärke in px (Opfer 1, Angreifer 1)
	var jitter_hz := 30.0
	var death_dur := 0.7          # Ausblenden der Leiche (s)
	var pop := 1.0                # Auftritt 0..1 (Beschwörung, Nachwachsen)
	var gone_t := 0.0             # Flucht und Überbordgehen: Sekunden seit dem Beginn
	var gone_kind := ""           # "", flee, overboard
	var hop := 0.0                # Hüpfen beim Platztausch (px nach oben)

class LightState extends RefCounted:
	var bg := 1.0                 # Hintergrundhelligkeit RELATIV zum Ortswert (Ruhe 1,0)
	var vignette := 0.0           # Zuschlag
	var spot_pos := Vector2.ZERO  # Mitte der Abstufungs-Ellipse in Bühnenpixeln
	var spot_r := Vector2(190, 110)   # Halbachsen bei Zoom 1; die Bühne multipliziert mit dem Zoom
	var spot_col := Color(1, 0.85, 0.5)
	var spot_amt := 0.0           # 0..1
	var spot2_pos := Vector2.ZERO # zweiter Spot (Fläche, Zielwahl)
	var spot2_amt := 0.0
	var foe_turn := false         # kaltes Licht, Schlüsselfarbe `foe_key` des Ortes
	var flicker := 0.0            # 0..1: Flackern ±8 % mit 7 Hz (Auswahlphase)

class UiState extends RefCounted:
	var plaque := {}              # Fokusschild {who, name, skill, icon, side, crit, small, t (0..1), alpha, dy, kind "act"|"chip", text}
	var big := {}                 # große Ansage {text, sub, col, style "rise"|"sink"|"pop", t, dur}
	var turn_pulse := {}          # {f, t}
	var round_flash := 0.0
	var warn_crush := false       # Kraken spannt sich
	var edge := 0.0               # Stärke des Schwellenrands 0..1 (Herzschlag, Bühnenzeit)
	var selecting := false
