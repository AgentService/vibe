## Brief overview
- Architecture boundaries, event-driven flow, and autoload usage for this Godot project.
- Keep systems decoupled, data-driven, and aligned with existing vibe/ structure.

## Boundaries and layering
- Separate concerns: systems in vibe/scripts/systems, reusable utils/resources in vibe/scripts/{utils,resources}, scenes in vibe/scenes/*, data in vibe/data/*.
- No cross-layer reach-ins; interact via signals/services, not direct node lookups across modules.
- One script per scene; scene script orchestrates, system scripts implement logic.

## Signals and events
- Use EventBus.gd for cross-system communication; avoid NodePath coupling.
- Prefer typed signals with clear payloads; keep signal names past-tense (e.g., enemy_spawned).
- Connect in _ready() or via a setup() method; disconnect on teardown.

## Autoloads and singletons
- EventBus.gd (signals), Logger.gd (logs), GameOrchestrator.gd (flow), RNG.gd (determinism), RunManager.gd (run state).
- Keep autoloads small and focused; do not store mutable global state unless owned by that singleton.
- Access autoloads directly; inject other dependencies via setup(params) for testability.

## Scene ownership and composition
- Parent owns child lifecycle; components talk to owner via signals/callbacks, not tree scans.
- Use groups for discovery when needed; avoid deep hierarchies and long NodePaths.
- Disable _process/_physics_process unless required; prefer event/timer-driven updates.

## Data-driven resources
- Store tunables in .tres under vibe/data/*; avoid hardcoded gameplay values.
- Validate resources at load where critical; keep names/ids stable for tooling.
- Preload for hot paths; lazy-load via ResourceLoader for infrequent assets.

## Unified damage system v2
- Single entry: use DamageService autoload (res://scripts/systems/damage_v2/DamageRegistry.gd) for all damage requests; do not call take_damage() on nodes directly.
- Payload shape: Dictionary-based request with keys {source: String, target: String, base_damage: float, tags: Array[StringName] or Array[String]}; apply crits/modifiers centrally.
- Signals: Route via EventBus with typed signals (damage_requested, damage_applied, damage_taken); systems subscribe; no cross-module method calls.
- IDs: Use string-based entity IDs (e.g., "enemy_15", "boss_ancient_lich", "player"); resolve via registry/services, not scene tree scans.
- Ownership: DamageService owns lifecycle/death handling; emits kill events; consumers react via signals.
- Disallow: direct health lookups, per-system damage paths, direct take_damage() methods, and scene tree searches for enemies.

## Initialization and lifecycle
- Keep _ready() minimal; expose explicit setup(config: Resource) to inject dependencies/data.
- Ensure deterministic RNG usage (RNG.gd or local RandomNumberGenerator with fixed seed in tests).
- Clean up connections/timers on _exit_tree(); avoid leaking references.

## Performance and determinism
- Minimize per-frame allocations; reuse arrays/dicts; cache node references.
- Use physics layers/areas for filtering over manual checks; batch operations where feasible.
- Guard heavy logs behind flags; use Logger.gd for structured context.

## Documentation and checks
- Reflect architectural changes in docs/ARCHITECTURE_QUICK_REFERENCE.md and vibe/docs/ARCHITECTURE_RULES.md.
- Add/adjust isolated tests in vibe/tests for new boundaries; run vibe/check_architecture.bat if applicable.
