# Tech Context

Technologies, setup, constraints, dependencies, and tool usage patterns for this project.

## Stack and Environment
- Engine: Godot 4.x (Windows)
  - Binaries in repo root:
    - Godot_v4.4.1-stable_win64.exe
    - Godot_v4.4.1-stable_win64_console.exe (headless)
- Language: GDScript with static typing (vars, functions, signals; typed arrays/dicts required)
- OS target: Windows (dev), game is cross-platform via Godot

## Project Layout
- Main project: (root)/
  - addons/ (plugins)
  - assets/ (art/sound)
  - autoload/ (EventBus, Logger, RNG, RunManager, etc.)
  - data/ (typed .tres resources: balance, content, ui, xp_curves)
  - scenes/ (UI/visual)
  - scripts/ (domain/resources/systems/utils)
  - tests/ (scene-based isolated tests, headless runners)
- Documentation:
  - Root ARCHITECTURE.md (system design/decisions)
  - docs/ARCHITECTURE_QUICK_REFERENCE.md (boundary tools + patterns)
  - vibe/docs/ARCHITECTURE_RULES.md (enforcement rules)
  - Obsidian/ (system docs with [[links]])
  - memory-bank/ (this Memory Bank)

## Run, Test, Validate
- Run game:
  - cd vibe
  - "../Godot_v4.4.1-stable_win64.exe"
- Run tests (headless, 15s cap):
  - cd vibe
  - "../Godot_v4.4.1-stable_win64_console.exe" --headless tests/run_tests.tscn --quit-after 15
- Architecture check:
  - cd vibe && double-click check_architecture.bat
  - Or:
    - "../Godot_v4.4.1-stable_win64_console.exe" --headless --script tools/check_boundaries_standalone.gd --quit-after 10
- Pre-commit:
  - Hooks run boundary checks automatically; CI runs on PRs

## Plugins and Dependencies- Limbo Console v0.4.1 (vibe/addons/limbo_console): in-game console (F1 toggle) for dev commands/tuning
- GDAI MCP Plugin v0.2.4 (vibe/addons/gdai-mcp-plugin-godot): AI tools integration for Godot editor
- No external runtime deps required beyond Godot

## Data and Resources
- Resource-first approach: all tunables/content as typed .tres under vibe/data/*
  - Completed migration from JSON → .tres (log_config, radar_config, xp_curves, balance/content)
- Hot-reload:
  - Scenes: @export var config: ResourceType (inspector hot-reload)
  - Systems/Autoloads: ResourceLoader with monitoring/timers; CACHE_MODE_IGNORE where needed
  - BalanceDB file monitor scans .tres periodically for live updates

## Core Autoloads and Services
- EventBus.gd: typed signal hub (connect in _ready, disconnect in _exit_tree)
- Logger.gd: structured logging (DEBUG/INFO/WARN/ERROR), categories (balance, combat, waves, player, ui, performance, abilities)
- RunManager.gd: fixed-step accumulator (30 Hz), run lifecycle
- RNG.gd: deterministic streams seeded per run (crit, loot, waves, ai, craft)
- PauseManager.gd: pause state and process_mode handling
- BalanceDB.gd: resource loading/validation/hot-reload
- PlayerState.gd: cached position (typed payload cadence)
- GameOrchestrator.gd: game flow coordination

## Systems and Patterns
- Boundaries:
  - Scenes → Systems+Autoload only (no Domain import)
  - Systems → Domain+Autoload (no get_node into scenes)
  - Domain → Domain only (no EventBus)
- Determinism:
  - Logic advances on EventBus.combat_step(dt) at 30 Hz; rendering frame-based
  - RNG via named streams; no direct randi()/randf()
- Damage v2 (unified):
  - Single pipeline via DamageService/DamageRegistry
  - Signals: damage_requested → damage_applied/dealt → damage_taken; entity_killed
  - IDs are strings; registry/services resolve targets; no scene tree scans
- Rendering/performance:
  - MultiMesh baseline for enemies; use_colors=true; white base textures for modulation
  - Render tiers (SWARM/REGULAR/ELITE/BOSS); object pools; cached Transform2D arrays

## Testing Standards
- Use scene-based tests (*.tscn) for anything needing autoloads; headless via console binary
- CLI: vibe/tests/cli_test_runner.gd and vibe/run_tests.bat
- Deterministic seeding per test; avoid global state leaks; disconnect on teardown
- Print is allowed in tests (Logger is not); assert early with helpful messages

## Constraints and Prohibitions
- No networking for MVP
- No print/push_warning/push_error in game code (use Logger)
- No direct Node references in systems across boundaries; use EventBus + typed payloads
- Keep functions small (<40 lines), static typing everywhere

## CI/CD and Tooling
- Pre-commit: boundary checks block violations with clear messages
- CI: GitHub Actions runs architecture validation and tests headless
- Documentation workflow: Obsidian updates + changelogs; keep Memory Bank synced with decisions

## Known Tooling Pitfalls (from Lessons Learned)
- Godot 4 signal connections: use dot syntax (EventBus.signal.connect(handler))
- Typed arrays from dicts: construct Array[Type]() instead of []
- Signal declarations must be single-line; declare signals in EventBus before emission
- Use Panel for custom drawn UI backgrounds; Control without style is invisible
