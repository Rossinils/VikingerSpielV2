class_name Persist
extends RefCounted

## Speichern: die laufende Fahrt (nach jeder Meile) und der Gedenkstein (alle beendeten Fahrten).
## Die Pfade liegen im Nutzerordner und lassen sich für Tests umbiegen.

static var run_path := "user://run.json"
static var memorial_path := "user://gedenkstein.json"
const MAX_RUNS := 40


## Schlüssel, die Voyage.resume() ohne Vorgabewert liest: fehlt einer (beschädigte oder sehr alte Datei), wäre das Laden ein Absturz.
const RESUME_KEYS := ["map", "crew", "fallen_names", "start_names", "mile", "pos", "hull", "proviant", "loot", "turns", "enc_done", "rescued"]


## Kann dieser Spielstand fortgesetzt werden?
static func resumable(d: Dictionary) -> bool:
	for k in RESUME_KEYS:
		if not d.has(k):
			return false
	return true


## Gibt es etwas zum Fortsetzen? Auch die Sicherung zählt: bricht das Spiel beim Austauschen der Datei ab (Windows löscht
## zuerst die alte), fehlt die Hauptdatei, die vorige gute Fassung liegt aber noch als .bak da.
static func has_run() -> bool:
	return FileAccess.file_exists(run_path) or FileAccess.file_exists(run_path + ".bak")


static func save_run(v: Voyage) -> void:
	write_json_safe(run_path, JSON.stringify(v.to_dict()))


static func load_run() -> Dictionary:
	if not has_run():
		return {}
	return read_json_safe(run_path)


static func clear_run() -> void:
	for p in [run_path, run_path + ".bak", run_path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


static func load_memorial() -> Dictionary:
	var parsed := read_json_safe(memorial_path)
	if parsed.has("runs"):
		return parsed
	return {"runs": []}


## Schreibt erst in <pfad>.tmp und tauscht dann aus, damit ein Abbruch mitten im Schreiben (Fenster zu, Absturz, voller
## Datenträger) nie die einzige gute Datei zerstört; die vorige gute Fassung bleibt als <pfad>.bak liegen.
static func write_json_safe(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	var abs_dst := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) and read_json_safe_one(path) != null:
		DirAccess.copy_absolute(abs_dst, abs_dst + ".bak")
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_dst) == OK


## Liest eine JSON-Datei (Dictionary); ist sie unlesbar oder abgeschnitten, kommt die Sicherung <pfad>.bak dran. Sonst {}.
static func read_json_safe(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		var parsed = read_json_safe_one(p)
		if parsed is Dictionary:
			return parsed
	return {}


static func read_json_safe_one(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()  # parse() meldet Fehler als Rückgabewert, parse_string() druckt sie ins Log
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data if json.data is Dictionary else null


static func entry_for(v: Voyage, number: int) -> Dictionary:
	var fallen: Array = []
	for nm in v.fallen_names:
		fallen.append({"name": nm, "cause": String(v.death_causes.get(nm, "gefallen"))})
	var survivors: Array = []
	for m in v.crew:
		if m.state != CrewMember.State.DEAD:
			survivors.append(m.display_name)
	return {
		"n": number,
		"date": Time.get_date_string_from_system(),
		"result": "victory" if v.victory else v.cause,
		"saga": v.saga_text if v.saga_text != "" else Saga.compose(v),
		"fallen": fallen, "survivors": survivors,
		"loot": roundi(v.loot), "turns": v.turns, "miles": roundi(v.total_miles), "stage": v.stage, "level": v.level,
	}


## Weiteste Etappe und Zahl der Gefallenen über ALLE Fahrten: auch die, die aus der Liste (MAX_RUNS) gefallen sind.
static func totals(mem: Dictionary) -> Dictionary:
	var best := int(mem.get("best", 0))
	var fallen := int(mem.get("fallen_total", 0))
	if not mem.has("fallen_total"):  # alter Stand ohne Summen: aus den vorhandenen Fahrten
		for run in mem.get("runs", []):
			fallen += (run.get("fallen", []) as Array).size()
	for run in mem.get("runs", []):
		best = maxi(best, int(run.get("stage", 1)))
	return {"best": best, "fallen": fallen}


static func add_memorial(v: Voyage) -> void:
	var data := load_memorial()
	var runs: Array = data["runs"]
	var tot := totals(data)  # vor dem Anhängen und Kürzen
	runs.append(entry_for(v, int(data.get("count", runs.size())) + 1))
	data["best"] = maxi(int(tot["best"]), v.stage)
	data["fallen_total"] = int(tot["fallen"]) + v.fallen_names.size()
	data["count"] = int(data.get("count", runs.size() - 1)) + 1
	if runs.size() > MAX_RUNS:
		runs = runs.slice(runs.size() - MAX_RUNS)
	data["runs"] = runs
	write_json_safe(memorial_path, JSON.stringify(data))
