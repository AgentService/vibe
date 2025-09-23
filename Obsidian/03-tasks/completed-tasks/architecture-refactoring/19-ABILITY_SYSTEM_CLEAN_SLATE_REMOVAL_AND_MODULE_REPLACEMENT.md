# Ability System Clean Slate Removal & Module Replacement

**Status**: 📋 **Ready to Start**  
**Priority**: Medium  
**Type**: System Replacement  
**Created**: 2025-09-09  
**Context**: Remove current AbilitySystem.gd and replace with new AbilityModule following clean-slate approach

## Overview

Remove the existing AbilitySystem.gd (projectile pool) and all references, then build the new AbilityModule from scratch. This provides a clean foundation for the data-driven ability system without legacy coupling.

## Phase 1: Clean Slate Removal (Compile-Safe Pruning)

### Goals
- Remove all AbilitySystem references while maintaining compilation
- Strip projectiles_updated signal usage entirely
- Prepare codebase for new AbilityModule implementation
- Ensure no orphaned references remain

### Implementation Steps

#### A. Remove AbilitySystem from Core Systems
- [ ] **GameOrchestrator.gd**: Remove AbilitySystem preload, instantiation, and systems["AbilitySystem"] entry
- [ ] **GameOrchestrator.gd**: Update DamageSystem.set_references() call to remove ability_system parameter
- [ ] **SystemInjectionManager.gd**: Delete set_ability_system(), injected["AbilitySystem"], and projectiles_updated connections
- [ ] **Arena.gd**: Remove ability_system field, set_ability_system method, and all projectiles_updated signal wiring
- [ ] **PlayerAttackHandler.gd**: Remove ability_system field/parameter and comment out spawn_projectile calls with TODO for AbilityModule.cast_ability
- [ ] **DamageSystem.gd**: Remove ability_system variable and change set_references(ability_sys, wave_dir) → set_references(wave_dir)
- [ ] **PerformanceMonitor.gd**: Remove ability_system parameter and usage

#### B. Remove projectiles_updated Signal Usage
- [ ] **MultimeshManager**: Remove projectiles_updated connections (will be replaced with pull-based snapshot)
- [ ] **Arena.gd**: Strip all projectiles_updated connect/disconnect blocks
- [ ] **SystemInjectionManager.gd**: Remove projectiles_updated wiring logic

#### C. Update Tests and References
- [ ] **tests/AbilitySystem_Isolated.gd/.tscn**: Comment out or remove (will be replaced with AbilityModule_Isolated)
- [ ] **tests/test_signal_cleanup_validation.gd**: Remove AbilitySystem from systems list
- [ ] **tests/test_signal_contracts.gd**: Remove AbilitySystem references
- [ ] **tests/test_memory_issues_diagnostic.gd**: Remove AbilitySystem from systems lists
- [ ] **tests/test_melee_damage_flow*.gd**: Remove AbilitySystem instantiation
- [ ] **tests/test_performance_500_enemies.gd**: Remove AbilitySystem finding/creation logic

#### D. Final Cleanup
- [ ] **Delete scripts/systems/AbilitySystem.gd**: Remove the entire file
- [ ] **Verify compilation**: Ensure project compiles without errors after removal

## Phase 2: New AbilityModule Implementation

### Goals
- Build AbilityModule autoload with embedded projectile pooling
- Implement .tres-based ability definitions
- Replace push-based rendering with pull-based snapshot
- Maintain 30 Hz deterministic behavior and pooling performance

### Implementation Steps

#### A. Core AbilityModule Structure
- [ ] **autoload/AbilityModule.gd**: Create new autoload with:
  - `cast_ability(id: StringName, context: Dictionary) -> void` API
  - Internal projectile pool (ported from old AbilitySystem logic)
  - 30 Hz update via EventBus.combat_step connection
  - `get_projectile_snapshot() -> PackedVector2Array` for rendering
  - Optional `ability_cast(id, context)` signal for analytics
  - Cooldown tracking per ability ID
  - BalanceDB integration for max_projectiles and arena_bounds

#### B. Ability Resource System
- [ ] **scripts/resources/AbilityResource.gd**: Create resource class:
  ```gdscript
  extends Resource
  class_name AbilityResource
  @export var id: StringName
  @export var type: StringName = &"projectile"
  @export var cooldown: float = 0.5
  @export var damage: float = 10.0
  @export var projectile_config: Dictionary = {
    "speed": 400.0,
    "lifetime": 2.0,
    "sprite": "",
    "tags": []
  }
  @export var tags: Array[StringName] = []
  ```
- [ ] **data/content/abilities/ranged_basic.tres**: Create first ability definition

#### C. Rendering Integration (Pull-Based)
- [ ] **MultimeshManager**: Update to pull projectile data on EventBus.combat_step:
  - Call `AbilityModule.get_projectile_snapshot()` 
  - Update multimesh instances from packed array
  - Reuse buffers to maintain zero-allocation behavior
- [ ] **Arena.gd**: Remove old projectiles_updated connections, ensure MultimeshManager pulls on combat_step

#### D. Input Integration
- [ ] **PlayerAttackHandler.gd**: Replace spawn_projectile calls with:
  ```gdscript
  AbilityModule.cast_ability(&"ranged_basic", {
    "origin": spawn_pos,
    "target": get_global_mouse_position(),
    "spread": spread_angle
  })
  ```
- [ ] **Arena.gd**: Ensure input routing calls PlayerAttackHandler appropriately

## Phase 3: Testing and Validation

### Implementation Steps
- [ ] **tests/AbilityModule_Isolated.gd/.tscn**: Create new isolated test:
  - Test cast_ability → projectile spawned in pool
  - Verify deterministic behavior across seeds
  - Test cooldown enforcement
  - Validate get_projectile_snapshot() returns correct data
- [ ] **tests/test_signal_contracts.gd**: Add AbilityModule signals if using ability_cast
- [ ] **Integration testing**: Verify Arena → PlayerAttackHandler → AbilityModule → MultimeshManager flow works
- [ ] **Performance validation**: Ensure no regression from old system

## Phase 4: Documentation and Polish

### Implementation Steps
- [ ] **docs/ARCHITECTURE_QUICK_REFERENCE.md**: Update with AbilityModule overview
- [ ] **docs/ARCHITECTURE_RULES.md**: Document ability logic boundaries
- [ ] **CHANGELOG.md**: Document system replacement
- [ ] **Balance validation**: Ensure projectile behavior matches previous system

## File Touch List

### Files to Remove
- `scripts/systems/AbilitySystem.gd` (DELETE)
- `tests/AbilitySystem_Isolated.gd/.tscn` (REMOVE/REPLACE)

### Files to Create
- `autoload/AbilityModule.gd` (NEW)
- `scripts/resources/AbilityResource.gd` (NEW)
- `data/content/abilities/ranged_basic.tres` (NEW)
- `tests/AbilityModule_Isolated.gd/.tscn` (NEW)

### Files to Modify
- `autoload/GameOrchestrator.gd` (EDIT: remove AbilitySystem, update DamageSystem init)
- `scripts/systems/SystemInjectionManager.gd` (EDIT: remove ability system injection)
- `scenes/arena/Arena.gd` (EDIT: remove ability_system field/methods, update MultimeshManager)
- `scripts/systems/PlayerAttackHandler.gd` (EDIT: replace spawn_projectile with cast_ability)
- `scripts/systems/DamageSystem.gd` (EDIT: update set_references signature)
- `scripts/systems/PerformanceMonitor.gd` (EDIT: remove ability_system usage)
- `scenes/arena/MultimeshManager.gd` (EDIT: pull-based projectile updates)
- Multiple test files (EDIT: remove AbilitySystem references)

## Success Criteria

### Functional Requirements
- [ ] Project compiles after Phase 1 removal
- [ ] AbilityModule provides same projectile behavior as old system
- [ ] Rendering works with pull-based snapshot approach
- [ ] Input routing fires projectiles toward mouse cursor
- [ ] Cooldowns prevent ability spam
- [ ] Deterministic behavior maintained across runs

### Performance Requirements
- [ ] No regression in projectile update performance
- [ ] Zero-allocation behavior preserved in hot paths
- [ ] 30 Hz update cadence maintained
- [ ] Memory usage equivalent to old system

### Architecture Requirements
- [ ] Clean separation: Arena only routes input, AbilityModule handles logic
- [ ] Data-driven: abilities defined in .tres resources
- [ ] Modular: easy to add new ability types
- [ ] Testable: isolated tests validate behavior

## Risk Mitigation

### High Risk: Rendering Integration
- **Risk**: Pull-based rendering may break multimesh updates
- **Mitigation**: Test MultimeshManager changes incrementally, maintain buffer reuse patterns

### Medium Risk: Input Flow Complexity  
- **Risk**: PlayerAttackHandler → AbilityModule integration may introduce bugs
- **Mitigation**: Preserve existing input handling patterns, test thoroughly

### Low Risk: Performance Regression
- **Risk**: New system may be slower than optimized old system
- **Mitigation**: Port proven pooling/update logic directly, profile before/after

## Timeline Estimate

- **Phase 1 (Removal)**: 2-3 hours
- **Phase 2 (Implementation)**: 4-5 hours  
- **Phase 3 (Testing)**: 1-2 hours
- **Phase 4 (Documentation)**: 1 hour

**Total**: 8-11 hours for complete replacement

## Next Steps After Completion

This task enables the roadmap outlined in:
- `03-ABILITY_SYSTEM_MODULE.md`: Full ability system architecture
- `18-ABILITY_SYSTEM_EXTRACTION_PHASE_1_IMPLEMENTATION.md`: Extended ability types and features

The clean AbilityModule foundation will support:
- Multiple ability types (AOE, beam, homing)
- Complex ability interactions and combinations  
- Visual effects and sound integration
- Card system ability upgrades
- Data-driven ability balancing

---

**Ready to Start**: All dependencies analyzed, clean removal path identified, replacement architecture designed.
