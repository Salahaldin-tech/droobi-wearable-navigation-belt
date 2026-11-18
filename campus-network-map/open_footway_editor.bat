@echo off
rem Serves this folder on http://127.0.0.1:8765 (this computer only) and opens
rem the footway drawing page. OpenStreetMap tiles need an http:// page; they
rem are blocked when the page is opened directly as a file.
rem Close this window to stop the server.
cd /d "%~dp0"
set PORT=8765
where python >nul 2>nul
if errorlevel 1 (
  echo Python was not found on PATH. Install Python or open the page directly
  echo and use the Satellite or "Streets (Esri, backup)" layer.
  pause
  exit /b 1
)
start "" "http://127.0.0.1:%PORT%/engineering_footway_editor.html"
echo Footway editor: http://127.0.0.1:%PORT%/engineering_footway_editor.html
echo Close this window to stop the local server.
python -m http.server %PORT% --bind 127.0.0.1
