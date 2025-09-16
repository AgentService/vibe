# Repository Guidelines

## Project Structure & Module Organization
- `scenes/` holds UI and visual scenes; pair with `scripts/ui/` for view logic.
- `scripts/` is split into `domain/` (pure models), `systems/` (gameplay logic), `arena/`, `utils/`, and `resources/`; singletons live in `autoload/`.
- Assets sit in `assets/` and `themes/`; balance/config JSON or `.tres` live under `data/`.
- Tests reside in `tests/`, with `_Isolated.tscn` scenes for system slices and `run_tests.tscn` for the main suite.
- Tooling and automation lives under `tools/` and `tests/tools/`; architecture docs live in `docs/` and root markdown files.

## Build, Test, and Development Commands
- Launch the game: `./Godot_v4.4.1-stable_win64.exe`.
- Run headless suite: `./Godot_v4.4.1-stable_win64_console.exe --headless tests/run_tests.tscn --quit-after 15`.
- Check architecture boundaries: double-click `tests/tools/check_architecture.bat` or run `./Godot_v4.4.1-stable_win64_console.exe --headless --script tools/check_boundaries_standalone.gd --quit-after 10`.
- Optional quick sim: `./Godot_v4.4.1-stable_win64_console.exe --headless tests/balance_sims.gd`.
- Pre-commit hooks rerun architecture checks; fix issues before retrying `git commit`.

## Coding Style & Naming Conventions
- Use typed GDScript everywhere; keep functions under ~40 lines and prefer small, single-purpose nodes.
- Signals via `EventBus` coordinate systems; never `get_node()` across layers or call scenes from systems.
- Store tunables in `data/content` or `data/balance` `.tres` files; runtime logs go through `Logger.*` (no raw `print()` in production).
- Files and resources use snake_case (e.g., `enemy_system.gd`, `arena_config.tres`); exported enums/constants are ALL_CAPS.
- Default to four-space indentation; `.editorconfig` enforces UTF-8.

## Testing Guidelines
- New mechanics require a headless test: prefer `_Isolated.tscn` when autoloads are needed, or `.gd` scripts for pure logic.
- Keep deterministic seeds via `RNG.stream()` helpers; document expectations in `tests/README.md` updates when applicable.
- Balance changes must adjust or add sims under `tests/baselines/` and `tests/balance` to prove DPS/TTK budgets.
- Use `print()` inside tests for diagnostics and ensure suites quit within 30s to keep CI stable.

## Commit & Pull Request Guidelines
- Follow conventional prefixes (`feat:`, `fix:`, `balance:`, `chore:`) noted in repo docs; include concise impact notes (e.g., `feat: add hideout pause gating`).
- Reference linked issues or design docs and list headless commands run; attach clips/screens for visual changes.
- Update `CHANGELOG.md` for the current week and note any `Obsidian/` doc updates needed.
- PR descriptions must spell out layer touchpoints and any new signals introduced; flag migrations or content schema updates explicitly.
