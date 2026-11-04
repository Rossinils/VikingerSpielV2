class_name Traits
extends RefCounted

## Eigenschaften der Männer. Jeder hat eine, manche zwei. Sie wirken auf Arbeit, Müdigkeit, Mut und Schicksal.
##   eff / eff_all  Arbeitsleistung (je Station bzw. überall)
##   cost           Faktor auf den Kraftverlust
##   stress         Faktor auf zunehmende Verzweiflung
##   wash           Faktor auf das Risiko, über Bord gespült zu werden
##   fight          Faktor auf die Kampfstärke
##   swim           Bonus auf die Rettungsaussicht, wenn er im Wasser ist

enum Id { STARK, GESCHICKT, STERNGUCKER, ZAEH, AENGSTLICH, GELASSEN, HEISSSPORN, SEEBAER, SCHWIMMER, PECHVOGEL, FAULPELZ }

const DATA := [
	{"name": "Starker Arm", "desc": "Rudert wie zwei.", "eff": {Stations.Id.RUDER: 1.3}},
	{"name": "Geschickte Hände", "desc": "Flickt schneller, als es kaputtgeht.", "eff": {Stations.Id.ZIMMERMANN: 1.3}},
	{"name": "Sterngucker", "desc": "Liest Wind und Sterne.", "eff": {Stations.Id.STEUER: 1.25, Stations.Id.SEGEL: 1.15}},
	{"name": "Zäh", "desc": "Wird langsamer müde.", "cost": 0.75},
	{"name": "Ängstlich", "desc": "Verliert schneller den Mut.", "stress": 1.5},
	{"name": "Gelassen", "desc": "Lässt sich kaum erschüttern.", "stress": 0.6},
	{"name": "Heißsporn", "desc": "Gefährlich im Kampf, schnell gereizt.", "fight": 1.4, "stress": 1.2},
	{"name": "Seebär", "desc": "Fällt selten über Bord.", "wash": 0.4, "eff": {Stations.Id.SEGEL: 1.1}},
	{"name": "Schwimmer", "desc": "Hält sich im Wasser länger oben.", "swim": 0.2},
	{"name": "Pechvogel", "desc": "Das Meer mag ihn besonders.", "wash": 1.8},
	{"name": "Faulpelz", "desc": "Arbeitet nur das Nötigste.", "eff_all": 0.85, "stress": 0.7},
]

## Paare, die sich widersprechen und nie zusammen vorkommen.
const CONFLICTS := [
	[Id.AENGSTLICH, Id.GELASSEN],
	[Id.SEEBAER, Id.PECHVOGEL],
	[Id.ZAEH, Id.FAULPELZ],
	[Id.STARK, Id.FAULPELZ],
]


static func random_set() -> Array[int]:
	var out: Array[int] = [randi() % DATA.size()]
	if randf() < 0.4:
		var second := randi() % DATA.size()
		var ok := second != out[0]
		for pair in CONFLICTS:
			if (pair[0] == out[0] and pair[1] == second) or (pair[1] == out[0] and pair[0] == second):
				ok = false
		if ok:
			out.append(second)
	return out


## Macht aus einer untypisierten Liste (z. B. aus JSON) eine Liste von Ganzzahlen.
static func typed(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		out.append(int(v))
	return out
