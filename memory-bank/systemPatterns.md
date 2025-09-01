# System Patterns

Authoritative reference for architecture, design patterns, and critical implementation paths.

## Layered Architecture and Boundaries
- Layers:
  - Domain (scripts/domain): Pure data and helpers; no EventBus; no scene references.
  - Systems (scripts/systems): Game logic; import Domain + Autoload; communicate via EventBus; no get_node() into scenes.
  - Scenes (scenes/*): UI/visual orchestration; import Systems + Autoload; do not import Domain directly.
  - Autoload (autoload/*): Glue/singletons (EventBus, Logger, RunManager, RNG, BalanceDB, PauseManager, PlayerState, GameOrchestrator); may import Domain.
- Enforcement:
  - Pre-commit and CI boundary checks.
  - Tools: check_architecture.bat, tests/test_architecture_boundaries.gd, tools/check_boundaries*.
- Anti-patterns blocked:
  - Systems → Scenes coupling (get_node()).
  - Scenes → Domain imports (bypass Systems).
  - Domain → EventBus or any non-domain import.
  - Circular dependencies.

## Event-Driven Signals
- Single global EventBus autoload; connect in _ready() and disconnect in _exit_tree().
- Typed payloads for compile-time safety (payload classes in scripts/domain/signal_payloads accessed via EventBus preloads).
- Core cadence:
  - combat_step(dt): 30 Hz fixed-step from RunManager.
  - Damage flow: damage_requested → damage_applied (and/or damage_batch_applied) → damage_dealt → damage_taken; entity_killed on death.
  - Game state/UI: game_paused_changed, arena_bounds_changed, player_position_changed, entity_health_changed (planned for BossHealthBar).
- Rules:
  - Use EntityId (string-based ids) and payloads; never Node references.
  - Scenes listen/update UI; Systems compute/emit; Domain stays pure.

## Fixed-Step Combat Loop (Determinism)
- RunManager accumulates frame delta and emits combat_step at fixed 1/30 s increments.
- Systems subscribe to combat_step(dt) and update logic deterministically (DoT, AI, cooldowns).
- Rendering remains frame-rate based; logic is decoupled and deterministic.

## RNG Strategy (Deterministic Streams)
- RNG autoload seeded per run (RunManager).
- Named sub-streams for isolation: "crit", "loot", "waves", "ai", "craft".
- No direct randi()/randf(); always use RNG.stream(name) helpers to preserve determinism and replayability.

## Unified Damage System v2
- Single entry point via DamageService autoload and central DamageRegistry.
- Request shape (dictionary/payload):
  - { source: String, target: String, base_damage: float, tags: Array[String]/PackedStringArray }
- Pipeline:
  - Emit EventBus.damage_requested(payload) → DamageSystem applies crits/modifiers → emit damage_applied/dealt → DamageRegistry updates entity HP/state → emit damage_taken/entity_killed.
- IDs:
  - String-based entity ids ("enemy_15", "player", "boss_ancient_lich"); resolved via registry/services.
- Ownership:
  - Lifecycle/death handled centrally; consumers react via signals.
- Disallow:
  - Direct take_damage() on nodes; scene tree scans for entities; per-system custom damage paths.

## Data-Driven Resources and Hot-Reload
- All tunables and content are typed Resources (.tres) under data/* (balance, XP curves, UI configs, content).
- Patterns:
  - Scenes: @export var config: ResourceType for inspector hot-reload.
  - Systems/Autoloads: ResourceLoader with monitoring/file timers (BalanceDB) and CACHE_MODE_IGNORE for live updates.
- Validation:
  - Resource classes provide validate(); loaders apply safe fallbacks.
- Migration:
  - JSON → .tres complete for configs (e.g., log_config, radar_config, xp_curves).

## Rendering and Performance
- Enemy rendering foundation: MultiMesh-only baseline (batched). Per-instance colors enabled via use_colors; white base textures for modulation.
- Render tiers: SWARM/REGULAR/ELITE/BOSS with tier-based routing to appropriate layers.
- Object pools for enemies/projectiles; cache allocations (e.g., Transform2D arrays sized to max_enemies).
- Disable _process/_physics_process when unused; prefer signals/timers; batch operations; use physics layers/areas for filtering.
- Boss hit feedback via shaders/boss_flash.gdshader material for boss damage flashes.

## Spawning Patterns (Hybrid)
- WaveDirector routes by EnemyType:
  - Pooled enemies for bulk waves (performance path).
  - Scene-based special bosses for complex AI/behaviors (boss_scene, is_special_boss, spawn method).
- Public APIs: spawn_boss_by_id(), spawn_event_enemies(); registry filters exclude special bosses from random waves.

## Logging
- Logger autoload: info/warn/error with optional categories (balance, combat, waves, player, ui, performance, abilities).
- No print/push_warning/push_error in game code; tests may use print.

## Testing Patterns
- Scene-based isolated tests under tests/*_Isolated.tscn for autoload-dependent systems; headless via Godot console.
- CLI runner: tests/cli_test_runner.gd; run_tests.bat convenience.
- Deterministic seeding (RNG) in tests; fast and deterministic; clear pass/fail.
- Architecture boundary tests (test_architecture_boundaries.gd) enforce layer rules.
- Use assert() and explicit checks; avoid global state leaks; reset/disconnect on teardown.

## UI/Scene Patterns
- CanvasLayer for all UI overlays (HUD, KeybindingsDisplay, modals).
- Modal overlays pause combat; generic modal system planned (CardPicker precedent).
- Scene management roadmap: GameManager entry, transitions, centralized UI state.
- BossHealthBar: ProgressBar + theme component; current direct-call update_health(current, max); migrate to EventBus entity_health_changed; add isolated test.

## Conventions and Style
- Static typing everywhere (vars, functions, signals); typed arrays/dicts.
- Naming: Classes PascalCase; constants UPPER_SNAKE_CASE; functions/vars snake_case; signals past-tense snake_case.
- @onready typed node refs; no magic numbers (use const or data Resource).
- Document schema in data/README; include example .tres for new resource classes.
