class_name FightLevel
extends RefCounted

## Eskalationsstufe eines Treffers (D1 2, D3 1): tödlich vor kritisch vor schwer vor Streifer.
enum { GRAZE, NORMAL, HEAVY, CRIT, KILL }

static func of(n: int, crit: bool, lethal: bool, dot: bool = false) -> int:
	if lethal:
		return KILL
	if crit:
		return CRIT
	if dot or n <= 5:
		return GRAZE
	if n >= 24:
		return HEAVY
	return NORMAL
