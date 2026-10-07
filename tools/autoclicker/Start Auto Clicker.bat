@echo off
rem Double-click this file to open Image Auto Clicker.
rem The first run installs what it needs (takes a minute).
cd /d "%~dp0"
title Image Auto Clicker

set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY (
    echo Python is not installed.
    echo Install it from the page that opens now, and tick "Add python.exe to PATH".
    echo Then double-click this file again.
    start https://www.python.org/downloads/
    pause
    exit /b 1
)

if not exist ".venv\Scripts\pythonw.exe" (
    echo First run: setting things up...
    %PY% -m venv .venv || goto failed
)
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -q -r requirements.txt || goto failed

start "" ".venv\Scripts\pythonw.exe" gui.py
exit /b 0

:failed
echo.
echo Setup failed, see the message above.
pause
exit /b 1
