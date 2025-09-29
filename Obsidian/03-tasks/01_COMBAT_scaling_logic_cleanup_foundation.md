# Scaling Logic Cleanup - Foundation for Unified Difficulty System

**Created:** 2025-09-29
**Status:** 🟡 Planning
**Priority:** High
**Estimated Effort:** 1-2 days
**Category:** ⚔️ Combat System Cleanup

## 📋 Task Description

Remove all existing scattered scaling implementations to create a clean foundation for the unified DifficultyDirector system outlined in `COMBAT_map_level_difficulty_scaling_integration.md`. Currently, the codebase has 4 different scaling systems competing with each other, creating unpredictable behavior and making it impossible to implement the comprehensive scaling solution cleanly.

**Current Problem:**
- ❌ MapLevel has convenience scaling methods (8%-15% per level)
- ❌ SpawnDirector combines MapLevel + wave scaling with complex multipliers
- ❌ BossSpawnManager applies hardcoded stat multipliers (5x health, 2x damage)
- ❌ Individual boss scripts have hardcoded stat assignments
- ❌ Multiple scaling systems conflict and create unpredictable difficulty progression

**Target State:**
- ✅ Clean MapLevel focused only on time progression tracking
- ✅ SpawnDirector with core spawning logic (no scaling calculations)
- ✅ Boss systems ready for template-driven stat application
- ✅ Clear foundation for DifficultyDirector implementation

## 🎯 Acceptance Criteria

- [ ] MapLevel.gd contains only level progression (time tracking, signals, current_level)
- [ ] All convenience scaling methods removed from MapLevel (get_health_scaling, etc.)
- [ ] SpawnDirector.gd multi-system scaling logic cleaned up (lines 777-792)
- [ ] BossSpawnManager hardcoded stat multipliers removed
- [ ] Individual boss scripts no longer assign hardcoded stats in _ready()
- [ ] All existing scaling-related method calls updated/removed
- [ ] Game runs without scaling-related errors
- [ ] No regression in core spawning or boss functionality
- [ ] Clean commit ready for DifficultyDirector implementation

## 🔍 Technical Analysis

### Affected Systems
- [x] **autoload/MapLevel.gd** - Remove convenience scaling methods, keep progression core
- [x] **scripts/systems/SpawnDirector.gd** - Remove multi-system scaling logic around line 777-792
- [x] **scripts/systems/BossSpawnManager.gd** - Remove hardcoded stat multipliers
- [x] **scenes/bosses/AncientLich.gd** - Remove hardcoded stat assignments
- [x] **scenes/bosses/TestShadowBoss.gd** - Remove hardcoded stat assignments
- [ ] **Any other files calling removed scaling methods** - Update or remove calls

### Dependencies & Patterns
- **Breaking Changes:** Systems currently calling `MapLevel.get_pack_size_scaling()` etc. need updates
- **Compatibility:** Core spawning and boss functionality must remain intact
- **Performance Impact:** Positive - fewer redundant scaling calculations
- **Testing Strategy:** Verify core gameplay works without scaling

## 📊 Implementation Plan

### Phase 1: Analysis & Impact Assessment
- [ ] Search codebase for all calls to MapLevel scaling methods
- [ ] Identify all files importing or using removed scaling logic
- [ ] Document current scaling behavior for regression testing
- [ ] Create list of all method calls that need updates

### Phase 2: MapLevel Cleanup
- [ ] Remove `get_scaling_factor()` method from MapLevel.gd
- [ ] Remove `get_exponential_scaling()` method from MapLevel.gd
- [ ] Remove convenience methods: `get_spawn_rate_scaling()`, `get_health_scaling()`, `get_damage_scaling()`, `get_pack_size_scaling()`
- [ ] Verify MapLevel retains: level progression, signals, time tracking, `current_level` access
- [ ] Update MapLevel class documentation to reflect new scope

### Phase 3: SpawnDirector Scaling Removal
- [ ] Remove complex scaling logic around lines 777-792 in SpawnDirector.gd
- [ ] Remove `var level_multiplier = MapLevel.get_pack_size_scaling()` calls
- [ ] Remove wave scaling calculations that conflict with unified approach
- [ ] Simplify pack size calculation to use base values only
- [ ] Ensure core spawning logic remains functional

### Phase 4: Boss System Cleanup
- [ ] Remove hardcoded stat multipliers from BossSpawnManager.gd (`health *= 5.0`, `damage *= 2.0`)
- [ ] Remove hardcoded stat assignments from AncientLich.gd `_ready()` method
- [ ] Remove hardcoded stat assignments from TestShadowBoss.gd `_ready()` method
- [ ] Ensure boss spawning and basic functionality still works
- [ ] Document boss stat templates for future DifficultyDirector integration

### Phase 5: Dependency Updates & Testing
- [ ] Update all files that call removed MapLevel scaling methods
- [ ] Remove any scaling-related imports that are no longer needed
- [ ] Test enemy spawning works without scaling
- [ ] Test boss spawning and basic combat works
- [ ] Verify no runtime errors from missing method calls

### Phase 6: Documentation & Validation
- [ ] Update relevant CLAUDE.md files to reflect removed scaling methods
- [ ] Document the clean foundation state for DifficultyDirector implementation
- [ ] Update CHANGELOG.md with cleanup summary
- [ ] Prepare commit with conventional format: `feat(combat): remove scattered scaling logic for unified system foundation`

## 🔗 Related Files

### Will Modify:
- [ ] `autoload/MapLevel.gd` - Remove convenience scaling methods
- [ ] `scripts/systems/SpawnDirector.gd` - Remove multi-system scaling logic
- [ ] `scripts/systems/BossSpawnManager.gd` - Remove hardcoded stat multipliers
- [ ] `scenes/bosses/AncientLich.gd` - Remove hardcoded stats
- [ ] `scenes/bosses/TestShadowBoss.gd` - Remove hardcoded stats
- [ ] Any files calling removed scaling methods (TBD during analysis)

### Will Create:
- [ ] None (cleanup task only)

### Documentation Updates Needed:
- [ ] `autoload/CLAUDE.md` - Remove MapLevel scaling method references
- [ ] `scripts/systems/CLAUDE.md` - Update SpawnDirector integration patterns
- [ ] `CHANGELOG.md` - Cleanup summary

## 📚 Specific Code Removal List

### From MapLevel.gd:
```gdscript
# REMOVE these methods entirely:
func get_scaling_factor(base_rate: float = 0.1) -> float
func get_exponential_scaling(base_rate: float = 0.05, cap: float = 3.0) -> float
func get_spawn_rate_scaling() -> float
func get_health_scaling() -> float
func get_damage_scaling() -> float
func get_pack_size_scaling() -> float
```

### From SpawnDirector.gd (around lines 777-792):
```gdscript
# REMOVE this scaling calculation block:
var level_multiplier = MapLevel.get_pack_size_scaling() if MapLevel else 1.0
var wave_scaling = scaling.get("wave_scaling_rate", 0.15)
var wave_multiplier = 1.0 + (current_wave_level - 1) * wave_scaling
var base_total_multiplier = minf(level_multiplier * wave_multiplier, max_multiplier)
```

### From BossSpawnManager.gd:
```gdscript
# REMOVE hardcoded multipliers:
boss_instance.health *= 5.0
boss_instance.damage *= 2.0
```

### From Boss Scripts:
```gdscript
# REMOVE hardcoded stat assignments in _ready():
health = 500.0
damage = 75.0
movement_speed = 120.0
```

## 📝 Progress Notes

### 2025-09-29 - Planning
- Task created to establish clean foundation for unified scaling system
- Identified 4 scattered scaling implementations to remove
- Planned systematic cleanup approach
- Coordinated with `COMBAT_map_level_difficulty_scaling_integration.md` task

## 🚨 Risks & Considerations

### Critical Risks
- **Gameplay Disruption**: Removing scaling will temporarily make game easier until DifficultyDirector is implemented
- **Method Call Errors**: Files calling removed MapLevel methods will cause runtime errors
- **Boss Balance**: Bosses may become too weak without hardcoded multipliers

### Mitigation Strategies
- **Search and Replace**: Comprehensive search for all scaling method calls before removal
- **Incremental Testing**: Test after each phase to catch issues early
- **Documentation**: Clear documentation of what was removed for DifficultyDirector implementation
- **Rollback Plan**: Keep git history clean for easy rollback if needed

### Testing Strategy
- **Core Functionality**: Ensure enemy spawning still works
- **Boss Spawning**: Verify bosses spawn and have basic functionality
- **No Runtime Errors**: Game runs without scaling-related crashes
- **Performance**: No degradation in spawn performance

## ✅ Definition of Done

- [ ] All identified scaling methods removed from MapLevel.gd
- [ ] SpawnDirector scaling logic cleaned up, core spawning intact
- [ ] Boss systems no longer use hardcoded stat scaling
- [ ] All method calls to removed scaling functions updated/removed
- [ ] Game runs without scaling-related errors
- [ ] Core enemy and boss spawning functionality preserved
- [ ] Documentation updated to reflect clean foundation state
- [ ] CHANGELOG.md updated with cleanup summary
- [ ] Clean commit ready: `feat(combat): remove scattered scaling logic for unified system foundation`
- [ ] Foundation ready for DifficultyDirector implementation from `COMBAT_map_level_difficulty_scaling_integration.md`

## 🔗 Relationship to Other Tasks

**Prerequisite for:**
- `COMBAT_map_level_difficulty_scaling_integration.md` - This cleanup creates the clean foundation needed

**Coordination Notes:**
- This task removes the scattered scaling logic
- The integration task will implement the unified DifficultyDirector approach
- No overlap - this is pure cleanup, integration task is pure implementation

---

**Related:** [Difficulty Scaling Integration](COMBAT_map_level_difficulty_scaling_integration.md) | [MapLevel System](../systems/MapLevel-System.md) | [Combat Architecture](../../ARCHITECTURE.md#fixed-step-combat-loop-decision-5a)