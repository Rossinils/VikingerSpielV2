class_name Settings
extends RefCounted

## Einstellungen außer der Musik (die merkt sich MusicDirector selbst): Lautstärke der Effekte, Vollbild beim Start,
## Hilfe beim Start. Alles in user://settings.cfg; Tests, Bots und Screenshots lesen und schreiben nichts davon.

const PATH := "user://settings.cfg"

static var sfx_db := 0.0
static var fullscreen := false
static var help_at_start := true
static var auto_combat := false  # Kämpfe ohne Ansicht auflösen
static var enabled := false  # nur im echten Spiel wird gespeichert


static func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	sfx_db = clampf(float(cfg.get_value("sfx", "offset_db", 0.0)), -18.0, 6.0)
	fullscreen = bool(cfg.get_value("view", "fullscreen", false))
	help_at_start = bool(cfg.get_value("view", "help", true))
	auto_combat = bool(cfg.get_value("play", "auto_combat", false))
	Sfx.offset_db = sfx_db


static func save_all() -> void:
	if not enabled:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # die Musikwerte aus music.gd bleiben erhalten
	cfg.set_value("sfx", "offset_db", sfx_db)
	cfg.set_value("view", "fullscreen", fullscreen)
	cfg.set_value("view", "help", help_at_start)
	cfg.set_value("play", "auto_combat", auto_combat)
	cfg.save(PATH)


static func change_sfx(step_db: float) -> void:
	sfx_db = clampf(sfx_db + step_db, -18.0, 6.0)
	Sfx.offset_db = sfx_db
	save_all()
	Sfx.play("click")
