class_name Skalde
extends RefCounted

## Der Erzähler. {n} = betroffener Mann, {r} = Retter.

const LINES := {
	"start": [
		"Wir laufen aus. Die Götter haben schlechtes Wetter bestellt – und liefern pünktlich.",
		"Der Himmel hat uns gesehen und beschlossen, dass wir zu glücklich aussehen.",
		"Der König gab den Befehl, wir nahmen Kurs ins Grau. Gefragt hat uns keiner.",
		"Der Morgen biss ins graue Meer. Die Küste schwand, kein Heim blieb dort. Ein guter Anfang.",
	],
	"launch_full": [
		"Volle Fahrt. Wer jetzt noch betet, tut es im Laufen.",
		"Das Segel steht, die Ruder knarren. Vorsicht ist etwas für Lebende, die nichts vorhaben.",
	],
	"launch_bug": [
		"Der Bug dreht in die See. Wer dem Meer ins Gesicht sieht, wird seltener von hinten überrascht.",
		"Wir nehmen die Wellen von vorn. Die ehrlichste Art, nass zu werden.",
	],
	"launch_reef": [
		"Das Segel wird geborgen. Die Ruderer sehen aus, als hätten sie es kommen sehen.",
		"Nur noch Muskeln, kein Wind. Die Götter sind unbeeindruckt.",
	],
	"launch_open": [
		"Weg von der Küste, hinaus in die Weite. Dort sind die Wellen größer, aber ehrlicher.",
	],
	"launch_coast": [
		"Wir halten uns dicht am Land. Das Wasser ist glatter, die Felsen sind es nicht.",
	],
	"launch_rest": [
		"Wir drehen bei und lassen uns treiben. Zum ersten Mal seit Tagen schläft jemand.",
		"Segel runter, Ruder ein. Das Meer darf uns heute schaukeln, ausnahmsweise ohne Absicht.",
	],
	"overboard": [
		"{n} ist über Bord. Er wollte ohnehin mal schwimmen lernen.",
		"Die See nimmt {n}. Sie gibt selten zurück.",
		"{n} hat die Reling gegen das Meer getauscht. Schlechter Tausch.",
	],
	"rescued": [
		"{n} ist zurück an Bord. Nass, wütend, am Leben – die beste Kombination.",
		"Das Meer gibt {n} wieder her. Es hat ihn wohl nicht gemocht.",
		"Solang wir einen Atem teilen, verschlingt uns diese See nicht. {n} atmet. Das genügt.",
		"Wir zogen {n} vom kalten Rand. Dann sangen wir die alten Lieder, bis wieder Kraft in Armen stand.",
	],
	"rescue_fail": [
		"Das Seil fällt ins Leere. {n} sieht uns an, dann sieht er nichts mehr.",
		"{n} greift nach dem Seil. Das Seil greift nicht zurück.",
		"Hand an das Tau, Schulter an Schulter – und es reicht trotzdem nicht. {n} sinkt.",
	],
	"abandon": [
		"Wir lassen {n} zurück. Niemand sieht sich um. Alle denken daran.",
		"{n} wird kleiner und kleiner. Keiner sagt etwas. Das ist das Schlimmste.",
		"Wir hatten geschworen: Kein Mann wird hier zurückgelassen. Schwüre sind billig, wenn das Meer teuer ist.",
	],
	"hunger": [
		"Der Proviant ist aus. Die Männer kauen auf ihren Stiefeln und ihren Gedanken.",
		"Das letzte Brot, hart wie Stein. Früher brach man es zu zweit. Jetzt zählt jeder Krümel allein.",
	],
	"starved": [
		"{n} schläft ein und wacht nicht mehr auf.",
	],
	"heroic": [
		"{n} brüllt etwas, das kein Wort ist, und die Welt hält kurz inne.",
		"In {n} brennt es plötzlich hell. Die anderen schauen weg, vom Licht geblendet.",
		"Wo andere zerbrechen, wird {n} härter. Das Meer notiert es mit Interesse.",
	],
	"breakdown": [
		"{n} sieht in die Wellen und beschließt, nichts mehr zu hoffen.",
		"Etwas in {n} ist gerissen, und es war nicht das Tau.",
		"{n} hört auf zu singen. Zwischen den Männern ist es plötzlich sehr leise.",
	],
	"fc_brecher": [
		"Voraus hebt sich das Meer wie ein Rücken. Das wird kein Brecher, das wird ein Berg.",
		"Eine Wand aus Wasser. Das wird nass.",
	],
	"fc_boe": [
		"Der Wind riecht nach Ärger. Hoffentlich nicht nach Segelflicken.",
	],
	"fc_riff": [
		"Dunkle Zähne im Wasser. Das Meer zeigt sein Gebiss.",
	],
	"fc_nebel": [
		"Nebel. Man hört nur das Knarren der Planken und das eigene Zweifeln.",
	],
	"hz_brecher_ok": [
		"Der Brecher bricht sich am Bug. Das Schiff schüttelt sich nur.",
	],
	"hz_brecher_hit": [
		"Wassereinbruch! Der Brecher drückt Planken ein, und die Zimmerleute fluchen.",
		"Das Meer klopft an. Es klopft mit der Faust, und der Rumpf antwortet mit einem Riss.",
	],
	"hz_boe_ok": [
		"Die Böe kommt – und trifft auf ein kluges, kleines Segel.",
	],
	"hz_boe_hit": [
		"Das Segel brüllt auf. Der Mast beklagt sich.",
	],
	"hz_riff_ok": [
		"Das Riff liegt links im Dunkeln. Wir haben es nicht gesehen. Es uns auch nicht.",
	],
	"hz_riff_hit": [
		"Es knirscht unter dem Kiel. Kein Geräusch, das man zweimal hören will.",
	],
	"hz_nebel_ok": [
		"Wir tasten uns durch den Nebel. Irgendwo knirscht nichts. Wunderbar.",
	],
	"hz_nebel_hit": [
		"Aus dem Nebel kommt Treibgut. Es hat uns zuerst gesehen.",
	],
	"resume": [
		"Wir setzen die Fahrt fort, wo wir sie liegen ließen. Das Meer hat in der Zwischenzeit nicht aufgeräumt.",
	],
	"berserk": [
		"Etwas in {n} reißt, und was dahinter wartet, ist wütend. Die Männer rücken ein Stück ab.",
	],
	"berserk_hit": [
		"{n} sieht rot und schlägt zu. {r} war zur falschen Zeit am falschen Ruder.",
	],
	"enc_village": [
		"Ein Küstendorf. Rauch aus den Schornsteinen, Hunde am Strand. Jemand läutet bereits.",
	],
	"village_win": [
		"Das Dorf wehrte sich mit Mistgabeln und Würde. Beides half wenig.",
		"Die Vorratskammern waren voll, die Gesichter der Dörfler leer. Wir nahmen beides zur Kenntnis.",
	],
	"village_lose": [
		"Die Bauern waren zahlreicher und wütender, als der Plan vorsah. {n} bezahlt dafür.",
	],
	"village_sneak_ok": [
		"Im Schutz der Dämmerung trugen wir fort, was nicht angebunden war.",
	],
	"village_sneak_none": [
		"Die Schuppen waren leer. Das Dorf hatte früher mit uns gerechnet als wir mit ihm.",
	],
	"village_sneak_alarm": [
		"Ein Hund bellte, ein Kind schrie, und dann läuteten alle Glocken. Wir ruderten, als hätten wir es nie anders gewollt.",
	],
	"village_pass": [
		"Wir lassen das Dorf schlafen. Es wird nie erfahren, wie viel Glück es hatte.",
	],
	"enc_harbor": [
		"Ein Hafen. Zum ersten Mal seit Tagen riecht es nach etwas anderem als nach uns.",
		"Lichter am Ufer, Rauch aus der Taverne. Wer hier nicht anlegt, hat entweder Schulden oder Verstand.",
	],
	"harbor_mead": [
		"Der Met fließt, die Männer singen, und die Fäuste bleiben meistens unten.",
		"Ein Humpen auf die Lebenden, einer auf die Toten, und dazwischen keiner auf die Vernunft.",
	],
	"harbor_brawl": [
		"Die Rauferei dauerte kürzer als der Vorsatz, sie zu vermeiden. Der Met war trotzdem gut.",
	],
	"harbor_rest": [
		"Ein Dach, ein Strohsack, drei Stunden ohne Wellen. Die Männer schlafen wie Tote, nur gesünder.",
	],
	"harbor_hire": [
		"{n} heuert an. Sein Lebenslauf besteht aus einem Händedruck und einer Lüge.",
		"{n} steht plötzlich an Deck und tut so, als wäre er schon immer dabei gewesen.",
	],
	"harbor_buy": [
		"Gepökelter Fisch, hartes Brot und ein Preis, der nach Wucher riecht.",
	],
	"harbor_repair": [
		"Die Werftleute klopfen, fluchen und verlangen mehr. Der Rumpf sieht aus, als wollte er weiterleben.",
	],
	"harbor_leave": [
		"Wir legen ab. Der Hafen vergisst uns schneller, als wir ihn.",
		"Die Leinen werden gelöst. Hinter uns zählt jemand die Münzen, vor uns wartet das Meer.",
	],
	"enc_trader": [
		"Ein Handelsschiff, tief im Wasser. Wer so viel trägt, hat viel zu verlieren – und Äxte an Bord.",
	],
	"enc_island": [
		"Eine Insel. Rauch steigt auf. Entweder Hütten oder eine sehr schlechte Idee.",
	],
	"enc_monster": [
		"Das Wasser wölbt sich. Etwas Altes hebt den Kopf und sieht uns an, als hätte es auf Gesellschaft gewartet.",
	],
	"trader_win": [
		"Die Händler wehren sich mit Würde und Besen. Wir gewinnen trotzdem.",
		"Ihre Ware gehört jetzt uns. Ihr Glück, dass sie sie nie bezahlt haben.",
	],
	"trader_lose": [
		"Die Händler hatten mehr Äxte, als der Preis hergab. {n} bezahlt dafür.",
	],
	"trader_trade": [
		"Ein ehrlicher Handel. Beide Seiten fühlen sich betrogen – man nennt das fair.",
	],
	"trader_pass": [
		"Wir lassen das Schiff ziehen. Es sieht erleichtert aus, wir nicht.",
	],
	"island_a": [
		"Eine Quelle, Beeren, und kein einziger Mörder. Ausnahmsweise.",
	],
	"island_b": [
		"Verlassene Hütten. Die Bewohner ließen alles stehen, nur nicht ihre Ruhe.",
	],
	"island_c": [
		"Strandgut und Holz. Die Zimmerleute sehen aus, als hätten sie Geburtstag.",
	],
	"island_d": [
		"Ein Hinterhalt. Die Insel hatte Gäste erwartet – und schlechte Manieren. {n} kommt nicht zurück.",
	],
	"island_careful_ok": [
		"Wir bleiben am Strand und nehmen, was der Strand hergibt.",
	],
	"island_careful_none": [
		"Der Strand gibt nichts her außer Sand in den Stiefeln.",
	],
	"island_careful_hit": [
		"Selbst am Strand gibt es Ärger. Man muss ihn nicht suchen, er kommt gern zu Besuch.",
	],
	"island_pass": [
		"Wir lassen die Insel in Ruhe. Sie wird es überleben.",
	],
	"monster_win": [
		"Das Ungeheuer sinkt. Seine Knochen sind mehr wert als sein Charakter.",
	],
	"monster_lose": [
		"Es war größer, als die Geschichten sagten. {n} gehört jetzt dem Meer, das Ungeheuer dem Abendessen.",
	],
	"monster_harpoon": [
		"Die Harpune fährt tief, die Leine singt. Das Ungeheuer zieht uns eine Meile weit, dann zieht es nicht mehr.",
	],
	"monster_harpoon_miss": [
		"Die Harpune trifft, aber nur die Haut. Das Ungeheuer nimmt es persönlich und den Rumpf gleich mit.",
	],
	"monster_pay": [
		"Wir opfern Proviant. Das Ungeheuer nimmt an und ist, wie alle Schnorrer, nicht dankbar.",
	],
	"monster_flee_ok": [
		"Wir rudern, als hätte jeder von uns Schulden. Das Ungeheuer verliert das Interesse.",
	],
	"monster_flee_hit": [
		"Wir kommen davon, aber nicht ungeschoren. Der Rumpf erzählt noch lange davon.",
	],
	"enc_draugr": [
		"Ein Schiff ohne Wind, ohne Flagge, ohne Lebende. Es hält Kurs auf uns, als hätte es nie ein anderes Ziel gehabt.",
		"Aus dem Nebel schält sich ein Rumpf, grün von Algen und Jahren. An der Reling stehen Männer, die nicht atmen. Höflichkeit erwarten wir nicht.",
	],
	"enc_raider": [
		"Ein schwarzes Segel, eine Kanone am Bug und ein Kapitän, der uns schon beim Namen kennt. Schlechte Nachrichten haben es eilig.",
		"Räuber. Sie wollen, was wir haben, und wir wollen es behalten. Das wird ein sehr kurzes Gespräch.",
	],
	"raider_ram": [
		"Das Räuberschiff hält direkt auf uns zu. Wer so rammt, hat nichts zu verlieren, vor allem keinen Verstand.",
	],
	"raider_board": [
		"Enterhaken fliegen, Räuber brüllen. Ein Kampf wie auf der Straße, nur mit mehr Salzwasser.",
	],
	"raider_shoot": [
		"Ihre Kanone spricht, und die Planken antworten mit Splittern. Die Kommunikation ist einseitig.",
		"Ein Blitz, ein Knall, und irgendwo schreit jemand 'Das war mein Bein!'. Es war sein Bein.",
	],
	"battle_cannon": [
		"Unsere Kanone antwortet, wie nur Bronze antworten kann: laut, endgültig und mit Nachhall bis zum Horizont.",
		"Die Breitseite fährt hinaus. Danach ist es ganz still, nur in den Ohren klingelt es.",
	],
	"battle_repair": [
		"Die Zimmerleute stopfen Löcher mit Segeltuch, Fluchen und dem, was gerade da ist.",
	],
	"battle_ram": [
		"Wir treffen es mit dem Bug. Das Holz bricht, und weder wir noch es schreien.",
	],
	"battle_arrows": [
		"Die Pfeile pfeifen. Ein Toter mehr stört die Toten wenig, aber es beruhigt uns.",
		"Wir schießen, bis die Köcher leer sind. Wer schon gestorben ist, nimmt Pfeile nicht persönlich.",
	],
	"battle_board_win": [
		"Wir springen hinüber und schlagen zu, bis nichts mehr zurückschlägt. Es dauert länger, als es sollte.",
	],
	"battle_board_lose": [
		"Der Sprung gelingt, die Landung nicht. {n} bleibt drüben. Die Draugr haben jetzt einen Mann mehr.",
		"Kalte Hände halten {n} fest. Wir sehen zu, bis die Wellen dazwischenfahren.",
	],
	"battle_shield": [
		"Die Schilde schließen sich zur Mauer. Dahinter atmen wir, solange man das noch darf.",
	],
	"battle_flee": [
		"Wir drehen ab. Das Geisterschiff folgt nicht, es hat Zeit.",
	],
	"draugr_ram": [
		"Das Geisterschiff rammt uns mit der Ruhe der Toten. Unser Rumpf klagt lauter als die Besatzung.",
	],
	"draugr_board": [
		"Kalte Hände greifen über die Reling. Sie wollen nur Gesellschaft, und zwar dauerhaft.",
	],
	"draugr_dirge": [
		"Sie singen. Kein Lied, das man summen möchte. Es handelt von uns.",
		"Eine Totenklage weht herüber, und wir erkennen mit Schrecken ein paar der Namen.",
	],
	"battle_win": [
		"Das Geisterschiff versinkt, wie es hätte vor langer Zeit tun sollen. In seinem Bauch liegt Silber, das niemand mehr vermisst.",
		"Die Toten sind wieder tot. Ihre Truhen gehören nun uns, und ihr Fluch hoffentlich nicht.",
	],
	"battle_win_raeuber": [
		"Das Räuberschiff sinkt. Die Räuber hatten einen Plan, wir hatten Kanonen und schlechte Laune. Das Silber sinkt nicht mit.",
		"Raub ist ein ehrliches Handwerk, bis man auf Leute trifft, die es besser können.",
	],
	"battle_win_kraken": [
		"Der Kraken sinkt, in mehreren Teilen. Sein Blick sagt, dass er es persönlich nimmt.",
		"Das Untier taucht ab und lässt Tinte, Tentakel und einen ernsten Eindruck zurück.",
	],
	"camp_start": [
		"Man baut ein Lager am Strand. Die Männer tun so, als wäre das Land nicht auch gefährlich.",
		"Feuer, Fisch, ein bisschen Ruhe. Die Götter schauen weg, das ist schon viel.",
	],
	"camp_quiet": [
		"Die Nacht bleibt still. Verdächtig still, aber es bleibt dabei.",
		"Nichts geschieht. Der Skalde ist fast enttäuscht.",
	],
	"camp_raid_win": [
		"Sie kamen im Dunkeln und gingen im Dunkeln, nur mit weniger Männern. Das Lager hat gewonnen, mit knapper Not.",
	],
	"camp_raid_lose": [
		"Wer schläft, ist leichte Beute. Heute Nacht war es das Lager.",
	],
	"camp_storm": [
		"Der Sturm weckt alle und gibt jedem etwas zu tun, vor allem etwas zu fürchten.",
	],
	"camp_stranger": [
		"Ein Fremder am Feuer, der nichts will außer Gesellschaft. Das ist selten und verdächtig.",
	],
	"camp_find": [
		"Das Meer gibt manchmal etwas zurück. Meist ist es nicht das, was man vermisst.",
	],
	"battle_timeout": [
		"Der Kampf zieht sich. Das Geisterschiff verliert im Nebel die Lust, wir den Mut. Man trennt sich ohne Beute.",
	],
	"battle_timeout_raeuber": [
		"Der Kampf zieht sich. Die Räuber drehen ab, wir auch. Beide Seiten behaupten später, gewonnen zu haben.",
	],
	"battle_timeout_kraken": [
		"Der Kraken verliert das Interesse und sinkt, als wäre nichts gewesen. Uns bleibt das Zittern.",
	],
	"brother_mourn": [
		"{n} trauert um {r}. Er rudert weiter, aber jetzt für zwei, die beide nicht mehr da sind.",
		"{r} fehlt, und {n} sieht überall seinen Platz. Niemand sagt etwas, sogar der Wind nicht.",
	],
	"brother_abandon": [
		"{n} sieht den Wellen nach, in denen {r} versank. Er hat nichts gesagt, und es ist, als hätte er geschrien.",
	],
	"rival_relief": [
		"{r} ist fort. {n} atmet auf und schämt sich einen halben Tag dafür.",
		"Ohne {r} ist es an Deck merklich ruhiger. {n} zählt es nicht als Gewinn, sondern nur als Rechnung.",
	],
	"rival_fight": [
		"{n} und {r} geraten aneinander. Es beginnt mit Worten, die nicht in die Saga gehören.",
		"Ein Blick zu lang, ein Ruder zu nah: {n} und {r} gehen aufeinander los. Die anderen wetten.",
	],
	"island_repair": [
		"In einer stillen Bucht ziehen wir das Schiff an Land und klopfen, bis es wieder nach Schiff klingt.",
		"Die Zimmerleute flicken, die anderen halten Wache und tun, als wüssten sie, wovor.",
	],
	"village_repair": [
		"Die Dorfhandwerker flicken uns für einen Preis, der höflich 'Freundschaft' heißt.",
	],
	"enc_kraken": [
		"Das Wasser wird glatt wie ein Spiegel, und das ist nie ein gutes Zeichen. Dann hebt sich die See, und sie hat Arme.",
		"Ein Schatten unter dem Schiff, größer als das Schiff. Der Steuermann bittet leise darum, nicht darüber zu reden.",
	],
	"kraken_grab": [
		"Ein Tentakel tastet über die Reling, sucht und findet. Die Männer lernen schnell, sich festzuhalten.",
		"Der Arm ist kalt, glitschig und sehr entschlossen. Er nimmt, was er greifen kann, und das ist meistens ein Mann.",
	],
	"kraken_crush": [
		"Die Planken stöhnen wie ein alter Mann auf der Treppe. Der Kraken drückt zu und lässt sich Zeit.",
	],
	"kraken_ink": [
		"Schwarze Wolken im Wasser, schwarze Gedanken an Deck. Die Tinte brennt in den Augen, die Furcht in allem anderen.",
	],
	"enc_wreck": [
		"Ein Wrack, die Rippen wie ein Gerippe in den Wellen. Entweder ist es leer oder es hat seine Gründe.",
	],
	"wreck_item": [
		"Unter einem Haufen Tang liegt etwas Brauchbares. Der Tote daneben hat nichts dagegen.",
	],
	"wreck_loot": [
		"Eine Truhe, nass, aber voll. Wer sie zuletzt trug, braucht sie nicht mehr.",
	],
	"wreck_food": [
		"Fässer mit Salzfleisch im Bauch des Wracks. Es schmeckt nach Seefahrt und nach nichts, was man laut sagen möchte.",
	],
	"wreck_trap": [
		"Das Wrack gibt nach, und mit ihm der Boden. Nicht jedes Schiff sinkt freiwillig langsam.",
	],
	"wreck_wood": [
		"Gutes Holz, ein paar Taue und ein Brett mit einem fremden Namen. Wir nehmen alles außer dem Namen.",
	],
	"wreck_nothing": [
		"Das Wrack ist leer, bis auf Möwen und Schweigen.",
	],
	"wreck_pass": [
		"Wir lassen das Wrack liegen. Es hat noch jeden Besucher überlebt.",
	],
	# --- Ereignisse auf der Strecke ---
	"rev_drift": [
		"Treibgut voraus: Fässer, Planken, ein Segel ohne Schiff. Irgendwo hat jemand einen sehr schlechten Tag gehabt.",
		"Die See spuckt aus, was sie nicht mag. Diesmal Fässer.",
	],
	"drift_food": [
		"Zwei Fässer Salzfisch, kaum nass. Der Vorbesitzer wird sie nicht vermissen, er ist jetzt selbst Fisch.",
	],
	"drift_loot": [
		"Eine Kiste, schwer von Münzen. Das Meer zahlt selten, aber wenn, dann bar.",
	],
	"drift_wood": [
		"Gute Planken, gerade gewachsen. Die Zimmerleute nicken, das ist bei ihnen fast ein Lied.",
	],
	"drift_hook": [
		"In dem Netz hing ein Haken, und an dem Haken hing nach einem Augenblick {n}. Er flucht, also lebt er.",
		"Das Fass war morsch, die Hand darin nicht mehr ganz heil. Die See nimmt immer einen Zoll.",
	],
	"drift_pass": [
		"Wir lassen es treiben. Nicht alles, was schwimmt, will gerettet werden.",
	],
	"rev_castaway": [
		"Ein Mann im Wasser, an eine Planke geklammert. Er winkt, als wäre das hier ein Hafen.",
		"Eine Stimme aus den Wellen ruft um Hilfe. Die Wellen klingen zufrieden.",
	],
	"castaway_join": [
		"Wir ziehen ihn an Bord. Er heißt {n}, sagt er, und er rudert, sobald die Finger wieder gehorchen.",
	],
	"castaway_cache": [
		"Kein Platz an Bord, aber er bezahlt die Fahrt bis zur nächsten Küste: er weiß, wo sein Schiff gesunken ist, und was es geladen hatte.",
	],
	"castaway_dies": [
		"Er stirbt in der Nacht, warm und in Decken. Es gibt schlechtere Arten, und wir kennen die meisten.",
	],
	"castaway_draugr": [
		"Unter der blauen Haut war er schon lange tot. Er beißt, bevor er zu Staub zerfällt. Die See hat einen schlechten Humor.",
	],
	"castaway_barrel": [
		"Wir werfen ihm ein Fass zu. Er schwimmt damit davon, Richtung Land, oder Richtung Walhall. Eins von beiden.",
	],
	"castaway_pass": [
		"Wir fahren vorbei. Sein Rufen bleibt länger an Bord als er.",
	],
	"rev_ice": [
		"Treibeis versperrt den Weg, Schollen so groß wie Langhäuser. Der Norden schließt seine Tür.",
	],
	"ice_row": [
		"Rudern, stoßen, rudern. Die Schollen weichen, die Rücken der Ruderer nicht.",
	],
	"ice_luck": [
		"Wir segeln durch, die Schollen schaben am Rumpf und lassen ihn ganz. Glück ist auch eine Art von Seemannschaft.",
	],
	"ice_crash": [
		"Eine Scholle, die keiner sah, sieht uns. Das Krachen hört man noch lange in den Planken.",
	],
	"ice_tar": [
		"Frischer Teer auf den Bug, und das Schiff schiebt die Schollen wie ein Bauer die Schafe. Unhöflich, aber heil.",
	],
	"ice_around": [
		"Wir fahren außen herum, eine Wache länger. Das Eis hat Zeit, wir haben Proviant.",
	],
	"rev_hook": [
		"Haken fliegen über die Reling, ein Ruderboot hängt sich an unser Heck. Räuber, und sie haben gute Laune.",
	],
	"hook_win": [
		"Die Räuber liegen im Wasser, ihr Boot treibt leer davon. Ihre Börsen haben wir behalten.",
	],
	"hook_lose": [
		"Sie nehmen, was sie tragen können, und lassen uns das, was sie nicht tragen wollen: Schrammen und Scham.",
	],
	"hook_cut": [
		"Äxte auf die Taue, Ruder ins Wasser. Das Boot bleibt zurück, ihre Flüche nicht.",
	],
	"hook_cut_loss": [
		"Wir kommen los, aber ein Sack Beute geht mit ihnen. Zum Abschied winken sie damit.",
	],
	"rev_bottle": [
		"Eine Flasche schaukelt am Bug, ein Zettel darin. Irgendwer wollte gelesen werden.",
	],
	"bottle_map": [
		"Eine Karte der nächsten Untiefen, gezeichnet von jemandem, der sie zu spät kannte. Wir sehen jetzt weiter als er.",
	],
	"bottle_coins": [
		"Keine Nachricht, nur Münzen. Jemand wollte etwas vor den Erben verstecken und hat es den Fischen gegeben.",
	],
	"bottle_letter": [
		"Ein Abschiedsbrief. Der Name darin ist der eines Schiffes, das vor uns diesen Kurs fuhr. Niemand liest ihn zweimal.",
	],
	"bottle_back": [
		"Wir werfen sie zurück. Was das Meer verschickt, soll es selbst zustellen.",
	],
	"rev_whale": [
		"Ein Wal zieht neben uns her, größer als das Schiff. Er sieht uns an, als hätte er Zeit, und er hat sie.",
	],
	"whale_win": [
		"Der Wal ist erlegt. Fleisch, Tran und Fischbein für Wochen. Die Ruderer riechen danach noch länger.",
	],
	"whale_harpoon": [
		"Ein Wurf, eine Leine, ein langer Ritt. Am Ende ist der Wal ruhig und wir sind reich an Tran.",
	],
	"whale_lose": [
		"Der Wal schlägt einmal mit der Flosse, und das Schiff lernt fliegen, kurz. Die Landung ist schlechter.",
	],
	"whale_watch": [
		"Er taucht ab, und für einen Augenblick ist das Meer nicht feindlich. Nur für einen.",
	],
	"rev_wisp": [
		"Blaue Lichter über dem Wasser, und sie rufen mit Stimmen von Müttern und toten Brüdern.",
		"Irrlichter. Wer ihnen folgt, findet immer etwas. Meistens sich selbst, unter Wasser.",
	],
	"wisp_treasure": [
		"Sie führen zu einem Grab im Riff. Der Tote darin hatte Geschmack und keine Einwände.",
	],
	"wisp_trap": [
		"Die Lichter führen uns auf ein Riff und erlöschen, zufrieden. Der Rumpf ist es nicht, die Männer auch nicht.",
	],
	"wisp_ignore": [
		"Wachs in die Ohren, Blick aufs Ruder. Die Stimmen rufen weiter, nur nicht mehr uns.",
	],
	"wisp_gift": [
		"Ein Brot und ein Becher Met für die Lichter. Sie ziehen weiter, und die Männer schlafen in dieser Nacht.",
	],
	"rev_maelstrom": [
		"Das Wasser beginnt sich zu drehen, erst langsam, dann nicht mehr. In der Mitte singt Rán ihr Lied für Schiffe.",
	],
	"maelstrom_row": [
		"Rudern, bis die Hände bluten, und noch zwei Schläge mehr. Der Strudel lässt uns gehen, enttäuscht.",
	],
	"maelstrom_lucky": [
		"Wir treiben einmal im Kreis und dann hinaus. Rán hatte heute schon gegessen.",
	],
	"maelstrom_bad": [
		"Der Strudel spuckt uns aus, aber nicht ganz. Ein Teil des Rumpfes bleibt bei Rán.",
	],
	"maelstrom_offer": [
		"Silber für Rán, über die Reling. Das Wasser wird ruhig, das Lied verstummt. Sie ist käuflich, wie alle Götter.",
	],
	"rev_raft": [
		"Ein Floß aus Leichen treibt heran. Einige sitzen aufrecht, und sie sitzen nicht still.",
	],
	"raft_win": [
		"Die Toten liegen wieder, diesmal endgültig. Ihr Schmuck reist mit uns weiter.",
	],
	"raft_lose": [
		"Wir stoßen das Floß weg, aber zwei von ihnen haben ihre Zähne in unseren Männern gelassen.",
	],
	"raft_burn": [
		"Pech und Feuer, und das Floß brennt wie ein Grab bei den Alten. Die Männer singen, ohne es zu wollen.",
	],
	"raft_tar": [
		"Teer auf das Floß, eine Fackel hinterher. Es brennt so gründlich, dass selbst die Toten Ruhe geben.",
	],
	"raft_burn_bad": [
		"Das Floß brennt, und ein brennender Toter klettert noch bis an unsere Reling. Wir löschen den Rumpf, dann ihn.",
	],
	"rev_fish": [
		"Das Wasser kocht vor Fisch, Möwen kreischen darüber. Ein gutes Zeichen, sagen die Alten. Die Alten sagen viel.",
	],
	"fish_ok": [
		"Die Netze kommen voll herauf. Heute Abend gibt es Fisch, und morgen, und übermorgen.",
	],
	"fish_torn": [
		"Ein großer Fisch nimmt das halbe Netz mit. Der Rest reicht für eine Mahlzeit und einen Fluch.",
	],
	"fish_pass": [
		"Wir fahren durch den Schwarm hindurch. Die Möwen sehen uns hinterher, mit Verachtung.",
	],
	"enc_gambler": [
		"Grüne Laternen über schwarzem Wasser, und an Deck ein Automat, der leise summt. Adlersson spielt nie, ohne dass jemand anderes bezahlt.",
	],
	"gambler_pass": [
		"Wir ließen das Spielschiff liegen. Hinter uns lachte jemand, und es war nicht der Wind.",
	],
	"slot_alive": [
		"Der Draugr riss die Augen auf und schrie. Das Wetter hörte zu, und die Walzen drehten sich von selbst weiter.",
		"„It's alive!“ rief die Maschine, und kein Mann an Bord widersprach.",
	],
	"slot_big": [
		"Die Walzen spuckten Silber, bis der Tisch sich bog. Selbst die Nornen sahen kurz weg, aus Neid.",
		"Ein Regen aus Münzen, und der Wirt zählte zum ersten Mal schneller als wir.",
	],
	"slot_jackpot": [
		"Fünfmal das Auge Odins. Der Allvater sah zu, zwinkerte nicht, und zahlte.",
	],
	"slot_loki_win": [
		"Adlersson verzog den Mund, als hätte er sich auf die Zunge gebissen. Er zahlte, aber er merkte sich unsere Gesichter.",
		"Die Walzen blieben stehen, und für einen Augenblick war es still. Dann lachte nur noch die Beute.",
	],
	"slot_loki_lose": [
		"Der Einsatz wanderte unter Adlerssons Mantel. Der Mann lächelte, als hätte er es von Anfang an gewusst.",
	],
	"slot_loki_curse": [
		"Drei Masken. Adlersson klatschte in die Hände, und irgendwo hinter uns ging etwas kaputt, das wir bisher für fest hielten.",
	],
	"slot_loki_man": [
		"Adlersson nahm {n} an der Schulter, wie man einen alten Freund nimmt. Dann war da nur noch Wasser.",
	],
	"slot_risk_lose": [
		"Die Münze fiel auf die falsche Seite. Die Beute auch, nämlich ins Wasser.",
	],
	"slot_risk_win": [
		"Die Münze drehte sich, blieb auf der Kante stehen und fiel dann zu unseren Gunsten. Sogar Adlersson klatschte, dünn.",
	],
	"pfand_found": [
		"In einer Ecke lag eine leere Flasche mit einem Zettel: Pfand. Erst hielten wir sie für Müll, dann für ein Vermögen.",
		"Eine Flasche, leer und ohne Etikett, aber mit einem Gewicht, das nicht von Glas kam. Wir behielten sie.",
	],
	"slot_bottle": [
		"Adlersson sah die Pfandflasche, seufzte wie ein Mann, der ein altes Versprechen einlöst, und drehte die Walzen selbst.",
		"Gegen die Flasche bleibt der Automat ehrlich, zum ersten Mal und gegen jede Gewohnheit seines Besitzers.",
	],
	"slot_bonus": [
		"Der Sieg riecht noch nach Pulver, und aus der Beute klimpert ein Automat. Ein Dreh gehört uns.",
	],
	"slot_harbor_lose": [
		"Die Walzen mögen uns heute nicht. Das Silber bleibt dennoch in der Welt, nur nicht mehr in unseren Taschen.",
	],	"theme_1": [
		"Nebelmeer. Man sieht nicht weit, hört aber umso mehr, und nichts davon ist beruhigend.",
	],
	"theme_2": [
		"Sturmfront. Der Himmel hat sich entschieden, und er hat sich gegen uns entschieden.",
	],
	"theme_3": [
		"Piratengewässer. Hier sind alle bewaffnet, höflich und auf der Suche nach Gesellschaft, die sie ausnehmen können.",
	],
	"theme_4": [
		"Totensee. Das Wasser ist still, weil nichts mehr darin zappelt. Die Toten haben viel Zeit und wenig Geduld.",
	],	"comrade_new": [
		"{n} und {r} sehen sich an, als hätten sie gerade beschlossen, nie wieder darüber zu reden. Seitdem stehen sie nebeneinander.",
		"Wer einen aus dem Wasser zieht, bekommt ihn nicht mehr los. {n} und {r} werden es noch bereuen und nie ändern.",
	],	"level_up": [
		"Stufe {n}. Die Götter haben uns bemerkt, was selten etwas Gutes bedeutet, diesmal aber ein Geschenk.",
		"Stufe {n}: Der Ruf eilt uns voraus. Hoffentlich schneller als die Gläubiger.",
	],
	"stage_new": [
		"Etappe {n}. Hinter uns der Hafen, vor uns das, was Hafenleute 'Wetter' nennen und wir 'Absicht'.",
		"Wir legen ab zu Etappe {n}. Die See hat nachgelegt, und wir auch: Die Beute wächst, die Wellen ebenso.",
	],
	"retire": [
		"Wir gehen in Rente, mit mehr Narben als Verstand und genug Beute für eine Taverne, die uns nicht kennt.",
	],
	"victory": [
		"Land! Es riecht nach Dreck und Schafen – wir sind zuhause.",
		"Dann brach der Nebel offen, und goldnes Gras erschien. Wir gingen fort als Seemänner und kommen heim als Legende.",
		"Man wird unsere Namen singen, am Hafen und im Wind. Die Lieder werden schöner sein als die Wahrheit.",
	],
	"sunk": [
		"Das Schiff sinkt. Wenigstens ist jetzt alles gleich nass.",
		"Der Hafen ruft aus fernem Grau. Wir kommen heim – nicht alle. Genauer gesagt: wir kommen nicht.",
	],
	"all_dead": [
		"Niemand mehr an Bord. Ein Geisterschiff – die Beute gehört den Möwen.",
		"Und wenn die Glocke ihre Namen schlägt, steht keiner am Kai. Es gibt auch niemanden mehr, der ihn vermissen könnte.",
	],
}


static func line(key: String, n: String = "", r: String = "") -> String:
	var options: Array = LINES[key]
	var text: String = options[randi() % options.size()]
	return text.replace("{n}", n).replace("{r}", r)
