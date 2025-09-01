# Project Brief

PoE-style buildcraft roguelike (2D top-down) built in Godot 4.x with a mechanics-first, deterministic, data-driven architecture. This document defines core requirements, scope, and success criteria. It is the source of truth that shapes all other Memory Bank files.

## Vision and Scope
- Core loop: fixed-step (30 Hz) deterministic combat with wave/survivor arena.
- Buildcraft focus: skills + supports, items/affixes, small skill tree, card-like progression choices.
- Performance-first: thousands of enemies via batched rendering (MultiMesh) and pooling.
- Data-driven: gameplay/balance/content configured via typed Resources (.tres) under data/*.
- Event-driven: cross-system communication via EventBus autoload with typed payloads.
- Layered architecture: Domain (pure data) → Systems (logic) → Scenes (UI); Autoloads as glue.

## Must-Haves (Non-Negotiable)
- Determinism:
  - Fixed-step combat loop (RunManager emits_step at 30 Hz).
  - RNG singleton with named streams seeded per run (RNG.stream("crit" | "loot" | "waves" | "ai" | "craft")).
- Architecture boundaries enforced:
  - Scenes import Systems + Autoloads only.
  - Systems import Domain + Autoloads; no get_node() coupling to scenes.
  - Domain is pure data; no EventBus, no scene references.
  - Automated boundary checks (tests/tools, pre-commit, CI).
- Typed GDScript everywhere; small functions; explicit types for arrays/dicts.
- Logging via Logger autoload (no print in game code).
- Data and balance as Resources:
  - .tres resources for content + configuration (balance, XP curves, UI configs, etc.).
  - Hot-reload support (F5 pattern and/or file monitoring in BalanceDB).
- Unified Damage System v2:
  - Single entry via Service/Registry with dictionary/payload-based requests.
  - Signals: damage_requested → damage_applied → damage_taken; entity_killed handled centrally.
  - String-based entity IDs; resolve via registry/services, not scene tree scans.

## Nice-to-Haves (Stretch)
- Generic modal/overlay system for UI (card picker, options).
- Scene management flow (GameManager) with clean transitions and state.
- Developer console (Limbo Console) integrated for runtime tuning and diagnostics.

## Constraints
- No networking for MVP.
- Tests must run headless and fast; isolated scene-based tests when autoloads required.
- Architecture and documentation must remain in sync (Obsidian system docs + changelogs).

## Success Criteria
- Stable 30 Hz deterministic combat across machines/seeds.
- Architecture check matrix remains clean (no forbidden edges).
- All tunables live in data/* as typed .tres with hot-reload.
- Damage pipeline unified across all entity types (pooled enemies, scene bosses, player).
- CI/pre-commit enforce boundaries and tests pass headless.
- Documentation accurate: Memory Bank + Obsidian systems reflect current implementation.

## Non-Goals
- Online multiplayer, leagues, or server-side systems in MVP.
- Feature creep beyond mechanics-first core loop and buildcraft essentials.

## High-Level Architecture (Authoritative)
- Autoloads: EventBus, Logger, RunManager, RNG, PauseManager, BalanceDB, PlayerState, GameOrchestrator
- Systems: AbilitySystem, DamageSystem/Service/Registry (v2), WaveDirector, EnemyRegistry, EnemyRenderTier, MeleeSystem, XpSystem
- Domain: Typed Resources and payloads (EnemyType, PlayerType, XP curves, signal payload classes)
- Scenes/UI: Arena (to be decomposed), HUD (includes BossHealthBar), Keybindings, future modal/overlay layers
