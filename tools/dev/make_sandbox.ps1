param([Parameter(Mandatory=$true)][string]$Name)
# Legt eine eigene Arbeitskopie des Projekts an (ohne build, Musik, __pycache__), samt Importcache (.godot).
# Ergebnis: <Projektordner>\..\_sandbox\<Name>\  -- dort entwickeln und testen, ohne dass andere Helfer dazwischenfunken.
$proj = Split-Path (Split-Path $PSScriptRoot)
$dst = Join-Path (Join-Path (Split-Path $proj) "_sandbox") $Name
New-Item -ItemType Directory -Force $dst | Out-Null
robocopy $proj $dst /E /XD build Musik __pycache__ /XF *.exe *.zip /NFL /NDL /NJH /NJS /NP | Out-Null
"Arbeitskopie: $dst"
