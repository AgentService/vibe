@echo off
echo Running Architecture Boundary Analysis...
echo.
"..\Godot_v4.4.1-stable_win64_console.exe" --headless --script tools/check_boundaries_standalone.gd --quit-after 10
echo.
pause