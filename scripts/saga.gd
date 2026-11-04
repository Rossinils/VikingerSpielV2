class_name Saga
extends RefCounted

## Der Skalde fasst eine Fahrt zusammen: aus dem, was wirklich geschah (Voyage.saga_events).
## Tote zuerst (höchstens drei), dann je ein besonderes Ereignis, am Ende der Ausgang.

const LINES := {
	"drowned": [
		"{n} ging unter, die Hand am Seil und einen Fluch auf den Lippen.",
		"Das Meer holte {n}, und das Seil war zu kurz. Niemand war schuld, und alle gaben sich welche.",
	],
	"abandoned": [
		"{n} blieb zurück. Wer ihn zuletzt sah, sprach später nie darüber.",
		"Wir überließen {n} den Wellen. Der Schwur galt wohl nur für Tage mit besserem Wetter.",
	],
	"starved": [
		"{n} verhungerte, weil der Proviant früher endete als die See.",
		"{n} schlief hungrig ein und wachte nicht mehr auf.",
	],
	"killed": [
		"{n} fiel {what}.",
		"{n} kam {what} nicht zurück.",
	],
	"rescued": [
		"{n} wurde aus den Wellen gezogen und tat, als wäre nichts gewesen.",
		"Das Seil hielt, und {n} lebte weiter, was man ihm nicht ansah.",
	],
	"hired": [
		"Im Hafen heuerte {n} an, und niemand fragte, woher er kam.",
		"{n} kam im Hafen an Bord und blieb, bis das Meer ihn forderte oder das Ziel ihn entließ.",
	],
	"breakdown": [
		"{n} verlor den Mut, nur den Rest nicht.",
		"Irgendwo auf dem Weg riss in {n} etwas, und die anderen taten, als hörten sie es nicht.",
	],
	"berserk": [
		"{n} sah rot und wurde gefürchtet, auch von seinen Freunden.",
	],
	"heroic": [
		"{n} wuchs im Kampf über sich hinaus und tat es ohne Zeugen, die es glaubten.",
		"Als es hart auf hart kam, stand {n} auf, und alle, die es sahen, erzählen es lauter, als es war.",
	],
	"raid_win": [
		"Die Beute war reicher, als der Anlass es verdiente.",
		"Wir nahmen, was wir tragen konnten, und trugen mehr, als gut für uns war.",
	],
	"storm": [
		"Im schlimmsten Sturm hielten wir Kurs, weil nichts anderes übrig blieb.",
	],
	"battle_win": [
		"Wir versenkten ein Geisterschiff. Seine Mannschaft nahm es gelassen, sie hatte Übung im Untergehen.",
		"Das Draugr-Schiff sank vor unseren Augen, und niemand wollte es zuerst ein Wunder nennen.",
	],
	"battle_win_raeuber": [
		"Wir versenkten ein Räuberschiff. Seine Beute war nun unsere, und die Räuber lernten, was sie eigentlich waren: Gäste.",
		"Das Räuberschiff ging unter. Wer von uns noch Münzen zählen konnte, zählte sie.",
	],
	"battle_win_kraken": [
		"Wir schlugen den Kraken in die Tiefe zurück. Dort mag er an seinen Tentakeln nachdenken.",
		"Der Kraken ließ von uns ab, in Stücken. Das Meer nahm es ihm nicht übel, das Meer nimmt vieles.",
	],
	"comrade_new": [
		"{n} zog {other} aus dem Wasser, und seitdem waren die beiden nicht mehr zu trennen.",
		"Aus einer Rettung wurde bei {n} und {other} etwas, das man Freundschaft nennen würde, wenn man dabei nicht rot würde.",
	],
	"brother_lost": [
		"{n} trauerte um {other}, seinen Bruder, und ruderte weiter, weil es nichts anderes gab, das er konnte.",
		"Als {other} fiel, blieb von {n} nur die Hälfte übrig. Die tat, was nötig war.",
	],
}

## Wo ein Mann fiel, nach Encounters.Id
const WHAT := [
	"beim Entern des Handelsschiffs",
	"im Hinterhalt auf der Insel",
	"im Kampf mit dem Seeungeheuer",
	"bei einer Rauferei im Hafen",
	"beim Überfall auf das Küstendorf",
	"im Kampf mit dem Geisterschiff",
	"im Kampf mit den Räubern",
	"in den Armen des Kraken",
	"im Wrack, das keines bleiben wollte",
	"bei Adlerssons Spiel, das er nie verliert",
]


static func compose(voy: Voyage) -> String:
	var parts: Array[String] = []
	parts.append("Wir liefen mit %d Mann aus: %s." % [voy.start_names.size(), ", ".join(PackedStringArray(voy.start_names))])
	var deaths := 0
	for e in voy.saga_events:
		if ["drowned", "abandoned", "starved", "killed"].has(e["type"]) and deaths < 3:
			parts.append(_line(e))
			deaths += 1
	for type in ["battle_win", "battle_win_raeuber", "battle_win_kraken", "brother_lost", "comrade_new", "rescued", "raid_win", "heroic", "berserk", "breakdown", "hired", "storm"]:
		for e in voy.saga_events:
			if e["type"] == type:
				parts.append(_line(e))
				break
	parts.append(_ending(voy))
	return " ".join(PackedStringArray(parts))


static func _line(e: Dictionary) -> String:
	var options: Array = LINES[String(e["type"])]
	var text: String = options[randi() % options.size()]
	var what := ""
	var enc := int(e.get("extra", -1))
	if enc >= 0 and enc < WHAT.size():
		what = String(WHAT[enc])
	return text.replace("{n}", String(e.get("name", ""))).replace("{other}", String(e.get("other", ""))).replace("{what}", what)


static func _ending(voy: Voyage) -> String:
	var alive: Array[String] = []
	for m in voy.crew:
		if m.state != CrewMember.State.DEAD:
			alive.append(m.display_name)
	var reach := "Wir kamen bis Etappe %d, Stufe %d, und fuhren %d Meilen." % [voy.stage, voy.level, roundi(voy.total_miles)]
	if voy.victory:
		if voy.fallen_names.is_empty():
			return "%s Dann legten wir an und blieben. Das glaubt uns niemand." % reach
		return "%s Dann legten wir an, und es blieben: %s. Die anderen blieben anderswo." % [reach, ", ".join(PackedStringArray(alive))]
	if voy.cause == "sunk":
		return "%s Dann kenterte das Schiff, und mit ihm das Meiste, was wir waren." % reach
	return "%s Zuletzt war niemand mehr da, der hätte erzählen können. Also erzähle ich." % reach
