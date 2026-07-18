@echo off
chcp 65001 >nul
set "GODOT=%~dp0Godot_v4.7.1-stable_win64.exe"
if exist "%GODOT%" (
    start "" "%GODOT%" --editor --path "%~dp0"
    exit /b 0
)
echo.
echo Не найден Godot_v4.7.1-stable_win64.exe
echo Положите Godot.exe в эту папку или импортируйте project.godot вручную.
echo.
pause
