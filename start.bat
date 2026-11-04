@echo off
rem Startet "Halt Kurs" (Windows). Godot 4.7.2 wird gesucht: Umgebungsvariable GODOT, winget-Installation, PATH.
rem Weitere Schalter gehen an das Spiel, z. B.:  start.bat --seed=3 --nohelp
setlocal
cd /d "%~dp0"
set "G=%GODOT%"
if "%G%"=="" if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" set "G=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if "%G%"=="" for %%I in (godot.exe) do set "G=%%~$PATH:I"
if "%G%"=="" (
  echo Godot 4.7.2 nicht gefunden.
  echo Installieren: https://godotengine.org/download/archive/4.7.2-stable/ oder "winget install GodotEngine.GodotEngine"
  echo oder die Umgebungsvariable GODOT auf die Godot-Datei setzen.
  pause
  exit /b 1
)
"%G%" --path . -- %*
