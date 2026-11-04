param([string]$Script, [int]$Tail = 40, [int]$Timeout = 300, [string]$Extra = "", [string]$Proj = "")
# Fuehrt ein GDScript (--script) oder den Import ("import") headless aus und zeigt Ausgabe und Fehler.
# Beispiele: tools\dev\rungd.ps1 -Script tools/selftest.gd -Tail 1500 -Timeout 900 | Select-String "FAIL|FEHLER"
#            tools\dev\rungd.ps1 -Script import        (nach neuen PNG/WAV/class_name-Dateien einmal ausfuehren)
if ($Proj -eq "") { $Proj = Split-Path (Split-Path $PSScriptRoot) }
$g = if ($env:GODOT) { $env:GODOT } else { "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" }  # Umgebungsvariable GODOT überschreibt den winget-Pfad
$id = [guid]::NewGuid().ToString("N").Substring(0, 8)
$out = Join-Path $env:TEMP "rungd_out_$id.txt"; $err = Join-Path $env:TEMP "rungd_err_$id.txt"
$a = @("--headless", "--path", $Proj)
if ($Script -eq "import") { $a += "--import" } else { $a += @("--script", $Script) }
if ($Extra -ne "") { $a += @("--", $Extra) }
$p = Start-Process -FilePath $g -ArgumentList $a -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -NoNewWindow
if (-not $p.WaitForExit($Timeout * 1000)) { try { $p.Kill() } catch {}; "TIMEOUT" }
"--- OUT"
Get-Content $out -Encoding UTF8 | Select-Object -Last $Tail
"--- ERR"
Get-Content $err -Encoding UTF8 | Select-Object -Last 30
Remove-Item $out, $err -ErrorAction SilentlyContinue
