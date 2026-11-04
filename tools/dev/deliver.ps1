param([Parameter(Mandatory=$true)][string]$Name, [Parameter(Mandatory=$true)][string[]]$Files)
# Kopiert fertige Dateien aus der Arbeitskopie <Name> zurueck ins Hauptprojekt (Pfade relativ zum Projekt, z.B. scripts/fight_stage.gd).
# Nur Dateien liefern, die dir laut Auftrag gehoeren.
$proj = Split-Path (Split-Path $PSScriptRoot)
$src = Join-Path (Join-Path (Split-Path $proj) "_sandbox") $Name
foreach ($f in $Files) {
  $from = Join-Path $src $f; $to = Join-Path $proj $f
  if (-not (Test-Path $from)) { "FEHLT in der Arbeitskopie: $f"; continue }
  New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
  Copy-Item $from $to -Force
  "geliefert: $f"
}
