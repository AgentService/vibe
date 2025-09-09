# Damage System Cleanup - Single Entry Point Consolidation

Status: Ready to Start
Owner: Solo (Indie)
Priority: High
Type: Architecture Cleanup
Dependencies: EventBus, DamageService/DamageRegistry, existing damage systems
Risk: Low (cleanup/consolidation)
Complexity: 3/10

---

## Purpose

Clean up mixed damage entry points before implementing zero-allocation queues. Currently the system has both EventBus.damage_requested signal emitters and direct DamageService.apply_damage calls, creating architectural ambiguity and complicating optimization efforts.

Based on code analysis:
- EventBus.damage_requested signal exists and is emitted in some places (tests, boss scenes)
- DamageSystem's old damage_requested handler was removed
- Most active systems now call DamageService.apply_damage directly
- Mixed entry points create confusion and test flakiness risk

---

## Goals & Acceptance Criteria

- [ ] Single damage entry point: DamageService.apply_damage() for all damage requests
- [ ] EventBus.damage_requested becomes outcome-only (damage_applied, damage_taken, entity_killed)
- [ ] Compatibility adapter: EventBus.damage_requested → DamageService.apply_damage for legacy/test code
- [ ] Clear documentation: damage_requested marked as deprecated for producers
- [ ] All tests pass with unified entry point
- [ ] Architecture docs updated to reflect single entry point rule

---

## Current State Analysis

### Active Direct Callers (Good - Keep These)
- `scripts/systems/MeleeSystem.gd` - Uses DamageService.apply_damage
- `scripts/systems/DamageSystem.gd` - Uses DamageService.apply_damage for projectiles
- `autoload/DebugManager.gd` - Uses DamageService.apply_damage for debug commands

### Signal Emitters (Need Migration or Adapter)
- `scenes/bosses/AncientLich.gd` - Emits EventBus.damage_requested
- `scenes/bosses/BananaLord.gd` - Emits EventBus.damage_requested
- `tests/DamageSystem_Isolated_Clean.gd` - Emits EventBus.damage_requested
- `tests/test_signal_contracts.gd` - Emits EventBus.damage_requested

### Signal Listeners (Need Review)
- `tests/DamageSystem_Isolated_Clean.gd` - Connects to damage_requested
- `tests/test_signal_contracts.gd` - Connects to damage_requested

---

## Implementation Plan

### Phase A — Add Compatibility Adapter
- [ ] Add EventBus.damage_requested → DamageService adapter in DamageService:
  ```gdscript
  # In DamageService._ready()
  EventBus.damage_requested.connect(_on_damage_requested_compat)
  
  func _on_damage_requested_compat(payload) -> void:
      # Extract fields from payload and route to apply_damage
      var source: String = payload.get("source_id", "unknown")
      var target: String = payload.get("target_id", "unknown") 
      var damage: float = payload.get("base_damage", 0.0)
      var tags: Array = payload.get("tags", [])
      
      apply_damage(target, damage, source, tags)
  ```

### Phase B — Update Boss Scenes (Preferred Path)
- [ ] Replace EventBus.damage_requested.emit in boss scenes with direct DamageService calls:
  - `scenes/bosses/AncientLich.gd`
  - `scenes/bosses/BananaLord.gd`
- [ ] Use existing entity registration pattern (bosses already register with DamageService)

### Phase C — Update Test Infrastructure
- [ ] `tests/DamageSystem_Isolated_Clean.gd`:
  - Replace damage_requested emits with DamageService.apply_damage calls
  - Keep damage_requested listener for outcome verification (damage_applied, etc.)
- [ ] `tests/test_signal_contracts.gd`:
  - Update to test the adapter path if keeping signal compatibility
  - Or migrate to direct service calls

### Phase D — Documentation Updates
- [ ] Mark EventBus.damage_requested as deprecated for producers:
  ```gdscript
  ## @deprecated Use DamageService.apply_damage() directly for damage requests.
  ## This signal is maintained for compatibility and outcome broadcasting only.
  @warning_ignore("unused_signal")
  signal damage_requested(payload)
  ```
- [ ] Update .clinerules and architecture docs:
  - Single entry point rule: DamageService.apply_damage()
  - EventBus for outcomes only: damage_applied, damage_taken, entity_killed

### Phase E — Validation & Testing
- [ ] Run all damage-related tests to ensure no regressions
- [ ] Verify boss damage still works correctly
- [ ] Confirm debug damage commands still function
- [ ] Test adapter path with remaining signal emitters

---

## File Touch List

Code (EDIT):
- `scripts/systems/damage_v2/DamageRegistry.gd` - Add compatibility adapter
- `scenes/bosses/AncientLich.gd` - Replace signal emit with service call
- `scenes/bosses/BananaLord.gd` - Replace signal emit with service call
- `autoload/EventBus.gd` - Add deprecation comment to damage_requested

Tests (EDIT):
- `tests/DamageSystem_Isolated_Clean.gd` - Migrate to service calls
- `tests/test_signal_contracts.gd` - Update for new pattern

Docs (EDIT):
- `.clinerules/01-godot-coding.md` - Update damage system rules
- `.clinerules/03-architecture.md` - Update single entry point rule
- `docs/ARCHITECTURE_QUICK_REFERENCE.md` - Update damage flow diagram
- `docs/ARCHITECTURE_RULES.md` - Clarify single entry point

---

## Benefits

### Architectural Clarity
- Single entry point eliminates confusion about damage request paths
- Clear separation: service calls for requests, EventBus for outcomes
- Easier to optimize (zero-alloc queues can focus on single entry point)

### Performance Preparation  
- Positions system for zero-allocation queue implementation
- Eliminates dual-path complexity in hot damage pipeline
- Reduces signal emission overhead for damage requests

### Maintainability
- Consistent damage request pattern across all systems
- Easier debugging (single entry point to instrument)
- Clear ownership: DamageService owns damage processing

---

## Success Criteria

- [ ] All damage requests go through DamageService.apply_damage()
- [ ] EventBus.damage_requested adapter works for legacy code
- [ ] No test regressions or gameplay changes
- [ ] Documentation clearly states single entry point rule
- [ ] Ready for zero-allocation queue implementation

---

## Notes & Guards

- Keep changes minimal and backwards compatible
- Adapter ensures no breaking changes for existing signal-based code
- Focus on consolidation, not feature changes
- Preserve all existing damage behavior and test coverage

---

## Timeline

**Estimated Effort:** 2-3 hours
- Phase A (Adapter): 30 minutes
- Phase B (Boss Updates): 45 minutes  
- Phase C (Test Updates): 45 minutes
- Phase D (Documentation): 30 minutes
- Phase E (Validation): 30 minutes

This cleanup prepares the damage system for the zero-allocation queue implementation by establishing a single, clear entry point and eliminating architectural ambiguity.
