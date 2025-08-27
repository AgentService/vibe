## Brief overview
- Testing standards for this Godot workspace.
- Focus on fast, deterministic, isolated scene-based tests aligned with vibe/ structure.

## Test layout and naming
- Place tests under vibe/tests mirroring system names (e.g., DamageSystem_Isolated.tscn/.gd).
- Use suffixes consistently: _Isolated for unit-style scene tests; test_* for integration/regression scripts.
- Keep one concern per test scene/script; prefer small focused cases over mega-tests.

## Execution
- Primary: run via vibe/tests/cli_test_runner.gd; batch: vibe/run_tests.bat.
- Tests must run headless without editor interaction.
- Ensure each test returns clear pass/fail signals; avoid flaky time-based waits.

## Isolation and determinism
- No global/autoload state leaks; reset or stub singletons as needed per test.
- Seed RNG deterministically for tests via RNG autoload or local RandomNumberGenerator with fixed seed.
- Avoid cross-test dependencies; each test sets up and tears down its own scene/resources.

## Assertions and logging
- Use assert() and explicit condition checks; prefer early-fail with helpful messages.
- Keep logs minimal; use Logger.gd for context (system, entity id) when diagnosing failures.
- Do not use print()/push_warning() in tests except for immediate failure context.

## Performance
- Target sub-second runtime per isolated test; batch suites should complete quickly.
- Avoid per-frame allocations in test loops; cap frame counts; prefer signals/timers to polling.
- Eliminate sleeps/timeouts where possible; use deterministic triggers.

## Test data and resources
- Store test fixtures under vibe/data/debug/ or dedicated test folders; avoid inline hardcoding.
- Reuse .tres resources where feasible; load via preload() for hot paths in tests.

## Unified damage v2 testing
- Exercise the single damage pipeline via DamageService (res://scripts/systems/damage_v2/DamageRegistry.gd); never call take_damage() directly in tests.
- Use dictionary-based payloads with keys {source, target, base_damage, tags}; assert values propagate unchanged through signals and registry.
- Assert EventBus signal sequence: damage_requested -> damage_applied -> damage_taken using await or signal spies.
- Use string-based entity IDs (e.g., "enemy_15"); avoid scene tree scans; resolve via services.
- Include an isolated DamageSystem_Isolated_Clean.tscn/gd test; cap frames and seed RNG deterministically.

## Coverage and scope
- Add tests for new systems and bug regressions alongside feature work.
- Include boundary/architecture checks (e.g., test_architecture_boundaries.gd) to prevent coupling regressions.
- Prefer verifying public behavior over internal implementation details.
