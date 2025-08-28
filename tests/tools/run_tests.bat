@echo off
setlocal
rem Ensure we run from the repo root regardless this script's location
pushd "%~dp0\..\.."
echo Running Godot balance tests...
".\Godot_v4.4.1-stable_win64_console.exe" --headless tests/run_tests.tscn
popd
pause
