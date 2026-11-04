class_name Persist
extends RefCounted

## Speichern: die laufende Fahrt (nach jeder Meile) und der Gedenkstein (alle beendeten Fahrten).
## Die Pfade liegen im Nutzerordner und lassen sich für Tests umbiegen.

static var run_path := "user://run.json"
static var memorial_path := "user://gedenkstein.json"
const MAX_RUNS := 40


static func has_run() -> bool:
	return FileAccess.file_exists(run_path)


static func save_run(v: Voyage) -> void:
	var f := FileAccess.open(run_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(v.to_dict()))


static func load_run() -> Dictionary:
	if not has_run():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(run_path))
	return parsed if parsed is Dictionary else {}


static func clear_run() -> void:
	if has_run():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path))


static func load_memorial() -> Dictionary:
	if FileAccess.file_exists(memorial_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(memorial_path))
		if parsed is Dictionary and parsed.has("runs"):
			return parsed
	return {"runs": []}


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
	var f := FileAccess.open(memorial_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
