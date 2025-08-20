@echo off
echo Running Godot balance tests...
"../Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/cli_test_runner.gd
pause
