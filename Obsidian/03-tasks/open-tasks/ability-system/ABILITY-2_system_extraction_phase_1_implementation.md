# Ability System Extraction — Phase 1 (Skeleton + Single Ranged Ability)

Status: Ready to Start
Owner: Solo (Indie)
Priority: Medium
Type: System Extraction
Dependencies: 12-G_STATE_MANAGER_CORE_LOOP, RunClock (optional), EventBus, BalanceDB, Arena.gd (current ability hooks)
Risk: Medium-Low (additive, behind seam)
Complexity: 4/10

---

## Purpose
Extract a minimal AbilityModule skeleton out of Arena with one concrete ranged projectile ability to prove the decoupled pipeline. Keep strongly modular boundaries, data-driven definitions, and deterministic behavior.

---

## Goals & Acceptance Criteria
- [ ] AbilityModule autoload with typed API and signals
  - cast_ability(id: StringName, context: Dictionary) -> void
  - signal ability_cast(id: StringName, context: Dictionary)
- [ ] Data-driven ability definitions (.tres)
  - AbilityResource.gd with fields: id, type, cooldown, projectile_config, damage, tags
- [ ] Single ranged ability implemented:
  - Fires toward mouse from player, uses pooling if available
  - Deterministic RNG stream usage for spread/multishot (if any)
- [ ] Arena integration seam:
  - Arena input calls AbilityModule.cast_ability("ranged_basic", context)
  - No ability logic in Arena; it only routes requests
- [ ] Tests:
  - AbilitySystem_Isolated covers cast → projectile spawn → EventBus signals
  - Deterministic behavior across runs
- [ ] Toggle:
 - AbilityModule can be disabled via BalanceDB for regression comparison

---

## Implementation Plan (Small Phases)

### Phase A — Module Skeleton
- [ ] `autoload/AbilityModule.gd`:
  - Registry of abilities (id -> resource)
  - cast_ability(...) dispatch + cooldown check
  - Emits signals; uses Logger
- [ ] `scripts/resources/AbilityResource.gd`:
  ```
  extends Resource
  class_name AbilityResource
  @export var id: StringName
  @export var type: StringName = &"projectile"  # projectile/aoe/beam etc.
  @export var cooldown: float = 0.5
  @export var damage: float = 10.0
  @export var projectile_config: Dictionary = {} # speed, lifetime, sprite, pool id
  @export var tags: Array[StringName] = []
  ```

### Phase B — First Ability
- [ ] `data/content/abilities/ranged_basic.tres`
  - Basic forward shot toward cursor, medium speed, short lifetime
- [ ] AbilityModule handler:
  - Creates/borrows projectile via existing projectile system/pool
  - Sets damage/tags; routes to DamageService on hit

### Phase C — Arena Seam
- [ ] Arena.gd:
  - Replace direct projectile spawn with: `AbilityModule.cast_ability(&"ranged_basic", { origin: player.global_position, target: get_global_mouse_position() })`
  - Remove any residual ability logic from Arena (guard behind toggle for quick revert)

### Phase D — Determinism & Signals
- [ ] Use `RNG.stream(&"abilities")` for any spread/modifiers (not needed for single straight shot MVP)
- [ ] EventBus:
  - Optional: `ability_cast` / `projectile_spawned` for UI/analytics

### Phase E — Tests
- [ ] `tests/AbilitySystem_Isolated.tscn/gd`:
  - Cast ability → assert projectile node created/moved
  - Ensure fixed results across seeds
  - Ensure cooldown respected
- [ ] `tests/test_signal_contracts.gd`: add ability signals coverage

### Phase F — Docs
- [ ] Update `docs/ARCHITECTURE_QUICK_REFERENCE.md`: AbilityModule overview
- [ ] Update `docs/ARCHITECTURE_RULES.md`: ability logic must live in AbilityModule; Arena only routes input

---

## File Touch List

Code:
- autoload/AbilityModule.gd (NEW)
- scripts/resources/AbilityResource.gd (NEW)
- scenes/arena/Arena.g (EDIT: route to AbilityModule)
- scripts/systems/projectiles/* (verify; integrate spawn seam)
- autoload/EventBus.gd (optional: ability signals)

Data:
- data/content/abilities/ranged_basic.tres (NEW)

Tests:
- tests/AbilitySystem_Isolated.tscn/gd (NEW or EDIT)
- tests/test_signal_contracts.gd (EDITDocs:
- docs/ARCHITECTURE_QUICK_REFERENCE.md (update)
- docs/ARCHITECTURE_RULES.md (update)

---

## Notes & Guards
- Keep module boundaries strict; no scene lookups inside AbilityModule—use passed context or service references.
- Reuse pools; avoid per-cast allocations.
- All data in .tres; no hardcoded ability stats in code.

---

## Minimal Milestone
- [ ] A1: AbilityModule skeleton + AbilityResource + ranged_basic.tres
- [ ] B1: Arena routes input to AbilityModule; projectile spawns and deals damage
- [ ] Sanity: AbilitySystem_Isolated passes; toggle allows disabling module
