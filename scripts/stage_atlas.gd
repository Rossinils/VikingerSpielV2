class_name StageAtlas
extends RefCounted

## Lage der Teile in assets/stage_*.png. ERZEUGT von tools/make_stage_art.py, nicht von Hand ändern.

const ORTE := ["draugr", "raeuber", "haendler", "dorf", "kraken"]
const BACK_SIZE := Vector2i(240, 72)   # ein Ort im Hintergrund (halbe Auflösung, im Spiel doppelt gezeichnet)
const RAIL_SIZE := Vector2i(240, 28)   # Reling-Ebene mit Alpha, beginnt in Zeile RAIL_TOP des Hintergrunds
const RAIL_TOP := 44
const DECK_SIZE := Vector2i(240, 32)
const GLOW_BALL := Rect2(0, 0, 64, 64)
const GLOW_POOL := Rect2(64, 0, 96, 32)
const FOG_SIZE := Vector2i(256, 40)
const HORIZON := 34  # Zeile des Horizonts im Hintergrund
const RAIL_Y := 58   # Oberkante der Reling
const GAP_X := 118    # Lücke zwischen den Schiffen
