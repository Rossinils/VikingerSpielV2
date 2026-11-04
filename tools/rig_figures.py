"""Beschreibungen aller menschlichen Kampffiguren (fuenf Maenner, achtzehn Gegner) fuer den Rig (tools/rig_core.py).

Die Schluessel sind die Namen der Dateien in assets/fig/ und stimmen mit Roles.Id (Maenner) und Foes.TYPES (Gegner) ueberein.
Farben und Ausstattung folgen den alten Figuren aus assets/combat.png, damit man jeden Gegner wiedererkennt."""
from rig_core import spec, hx, GOLD, LEATHER, LEATHER_D, RUST, RUST_D, BONE, GLOW, STEEL

# --- die fuenf Maenner (Reihenfolge = Roles.Id) --------------------------------------------------------
SCHILD = spec(wt=18, wb=15, cloth=hx("#5f6d7a"), cloth2=hx("#8a95a0"), pants=hx("#3a3a44"), belt=hx("#2c2118"), hair=hx("#5a3a22"),
              helm="nasal", mail=True, gear="sword", shield=(hx("#3e5f8f"), hx("#e0d8c0")), cls="shield")
AXT = spec(cloth=hx("#8a3a30"), hair=hx("#9a5a2a"), beard=hx("#9a5a2a"), longhair=True, gear="axe")
BOGEN = spec(wt=15, wb=13, torso=18, cloth=hx("#4c6a3f"), cloth2=hx("#6f8f5a"), pants=hx("#3f3a2c"), hair=hx("#5a4a30"), helm="hood",
             hood=hx("#3d5a33"), gear="bow", cls="bow", quiver=True)
SKALDE = spec(wt=16, wb=15, cloth=hx("#35507a"), cloth2=GOLD, pants=hx("#35507a"), robe=True, belt=LEATHER, hair=hx("#bdb7a6"),
              beard=hx("#bdb7a6"), helm="circlet", gear="staff", cls="staff", cape=hx("#2a3a5a"), orb=GOLD)
MUSKETE = spec(wt=16, wb=14, cloth=hx("#7a3a36"), cloth2=hx("#d0a84a"), pants=hx("#3a342e"), belt=LEATHER_D, hair=hx("#3a2a1c"),
               beard=hx("#3a2a1c"), helm="tricorn", hood=hx("#26262c"), gear="musket", cls="gun")

# --- Draugr -----------------------------------------------------------------------------------------------
ROST = spec(wt=17, wb=14, skin=hx("#7d9a86"), cloth=RUST_D, cloth2=RUST, pants=hx("#3c3a34"), belt=hx("#2c2118"), helm="rusty",
            eye_glow=True, mail=True, hunch=3, gear="rustsword")
BOGNER = spec(wt=15, wb=13, torso=18, skin=BONE, cloth=hx("#2f4a33"), cloth2=hx("#4d6e4a"), pants=hx("#2a2f26"), boots=hx("#1e1a14"),
              helm="hood", hood=hx("#2a4230"), skull=True, eye_glow=True, gear="bow", cls="bow", hunch=2)
TOTENWART = spec(wt=16, wb=15, cloth=hx("#27342d"), cloth2=hx("#4a6a58"), pants=hx("#27342d"), robe=True, belt=hx("#4a6a58"), skull=True,
                 eye_glow=True, helm="antler", gear="staff", cls="staff", orb=GLOW)
WAECHTER = spec(wt=18, wb=15, skin=BONE, cloth=hx("#5f6d7a"), cloth2=hx("#8a95a0"), pants=hx("#3a3a44"), belt=hx("#2c2118"),
                helm="nasal", skull=True, eye_glow=True, mail=True, gear="rustsword", cls="shield",
                shield=(hx("#6f7a85"), hx("#4a4f58")))
PRIESTER = spec(wt=16, wb=15, skin=BONE, cloth=hx("#3a2a52"), cloth2=hx("#8a62b0"), pants=hx("#3a2a52"), robe=True, belt=hx("#8a62b0"),
                helm="hood", hood=hx("#2a1f3d"), skull=True, eye_glow=True, gear="staff", cls="staff", orb=hx("#b074e6"))
BESCHWOERER = spec(wt=16, wb=15, skin=BONE, cloth=hx("#5a2a2e"), cloth2=hx("#a8504e"), pants=hx("#5a2a2e"), robe=True, belt=hx("#a8504e"),
                   skull=True, eye_glow=True, helm="antler", gear="staff", cls="staff", orb=hx("#e5503f"))
KNOCHEN = spec(wt=14, wb=12, torso=19, skin=BONE, cloth=hx("#cbc2a8"), cloth2=None, pants=hx("#b8ae92"), boots=hx("#6a5f4a"),
               belt=hx("#6a5f4a"), skull=True, eye_glow=True, bones=True, bare_arms=True, aw=3.2, legw=3.4, gear="bone", cls="melee")

# --- Raeuber ----------------------------------------------------------------------------------------------
BRECHER = spec(wt=25, wb=20, torso=21, cloth=hx("#5a2a2a"), cloth2=LEATHER, pants=hx("#26262c"), belt=LEATHER_D, hair=hx("#2a2018"),
               beard=hx("#2a2018"), helm="round", bare_arms=True, gear="club", legw=6)
MESSERKERL = spec(wt=15, wb=13, torso=18, cloth=hx("#2a2c3a"), cloth2=hx("#a8302a"), sleeve=hx("#d9d2c0"), pants=hx("#26262c"),
                  hair=hx("#3a2a1c"), helm="band", hood=hx("#b03a32"), gear="knife", gear_b="knife", cls="dual")
SCHUETZE = spec(wt=16, wb=14, torso=18, cloth=hx("#5a4a3a"), cloth2=hx("#7a6a58"), pants=hx("#3a342a"), hair=hx("#2a2018"),
                helm="cap", hood=hx("#2f3d5a"), gear="bow", cls="bow")
HAKEN = spec(wt=16, wb=14, cloth=hx("#4f3f6a"), cloth2=hx("#6f5f8a"), pants=hx("#2f2a36"), hair=hx("#4a3a2a"), helm="cap",
             hood=hx("#5a4a78"), gear="hook", cls="throw")
ANTREIBER = spec(wt=19, wb=16, torso=19, cloth=hx("#7a3a2e"), cloth2=GOLD, pants=hx("#2c2a2e"), hair=hx("#4a3020"),
                 beard=hx("#4a3020"), helm="band", hood=hx("#b03a32"), gear="horn", cls="horn")

# --- Haendler ---------------------------------------------------------------------------------------------
WACHE = spec(wt=18, wb=15, cloth=hx("#3e5f8f"), cloth2=GOLD, pants=hx("#2f3440"), belt=hx("#2c2118"), hair=hx("#5a3a22"),
             helm="round", gear="spear", cls="spear", shield=(hx("#d9b24a"), hx("#3e5f8f")))
ARMBRUST = spec(wt=15, wb=13, torso=18, cloth=hx("#4a5a74"), cloth2=hx("#6a7a94"), pants=hx("#2c2f3a"), hair=hx("#3a2a1c"),
                helm="cap", hood=hx("#34466a"), gear="crossbow", cls="gun")
KAUFMANN = spec(wt=18, wb=16, torso=19, cloth=hx("#6a3f7a"), cloth2=GOLD, pants=hx("#3a2f3a"), hair=hx("#4a3a2a"),
                beard=hx("#4a3a2a"), helm="felt", hood=hx("#6a4a2e"), gear="pouch", cls="throw")

# --- Dorf -------------------------------------------------------------------------------------------------
BAUER = spec(wt=17, wb=15, cloth=hx("#7a6a3a"), cloth2=hx("#a8946a"), pants=hx("#4a4228"), hair=hx("#5a4a30"), helm="straw",
             gear="fork", cls="staff")
SCHMIED = spec(wt=24, wb=19, torso=21, cloth=hx("#5a3e2a"), cloth2=hx("#8a6240"), pants=hx("#2c2a2e"), belt=LEATHER_D,
               hair=hx("#1e1a16"), beard=hx("#1e1a16"), bare_arms=True, gear="hammer", legw=6)
KRAEUTERFRAU = spec(wt=15, wb=15, torso=19, skin=hx("#e0b898"), cloth=hx("#4f6f48"), cloth2=hx("#8aa070"), pants=hx("#4f6f48"),
                    robe=True, belt=hx("#6a4a2e"), hair=hx("#a8803f"), longhair=True, helm="kerchief", hood=hx("#d9d2c0"),
                    gear="herb", cls="throw", carry="basket")

# Reihenfolge der Ausgabe: Maenner (Roles.Id), dann die Gegner in der Reihenfolge von Foes.ROW (ohne hund, tentakel, kraken)
HEROES = [("schild", SCHILD), ("axt", AXT), ("bogen", BOGEN), ("skalde", SKALDE), ("muskete", MUSKETE)]
FOES = [("rost", ROST), ("bogner", BOGNER), ("totenwart", TOTENWART), ("brecher", BRECHER), ("messerkerl", MESSERKERL),
        ("schuetze", SCHUETZE), ("haken", HAKEN), ("wache", WACHE), ("armbrust", ARMBRUST), ("kaufmann", KAUFMANN),
        ("bauer", BAUER), ("schmied", SCHMIED), ("priester", PRIESTER), ("waechter", WAECHTER), ("beschwoerer", BESCHWOERER),
        ("knochen", KNOCHEN), ("antreiber", ANTREIBER), ("kraeuterfrau", KRAEUTERFRAU)]
HUMANS = HEROES + FOES
