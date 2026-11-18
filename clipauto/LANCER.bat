@echo off
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel%==0 (
  py -3 clip_auto.py
) else (
  where python >nul 2>nul
  if errorlevel 1 (
    echo Python n'est pas installe. Installe "Python 3.12" depuis le Microsoft Store, puis relance LANCER.bat.
  ) else (
    python clip_auto.py
  )
)
pause
