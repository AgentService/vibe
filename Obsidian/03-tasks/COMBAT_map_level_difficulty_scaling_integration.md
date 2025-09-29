# Map Level Difficulty Scaling Integration

**Created:** 2025-09-29
**Status:** 🟡 Planning
**Priority:** High
**Estimated Effort:** 2-3 weeks
**Category:** ⚔️ Combat System Enhancement

## 📋 Task Description

Integrate MapLevel's time-based progression system with difficulty scaling for bosses and spawning enemies. Create an MVP scaling system that increases enemy stats (health, damage, speed) and spawn rates as map level increases over time, inspired by Risk of Rain 2's director system but simplified for our needs.

**Current State Analysis:**
- ✅ MapLevel autoload system exists (10s per level for testing)
- ✅ SpawnDirector already uses `MapLevel.get_pack_size_scaling()` for pack spawning
- ✅ EnemyFactory has stat variation system within template ranges
- ⚠️ Regular enemy spawning doesn't scale with MapLevel
- ⚠️ Individual enemy stats don't scale with MapLevel
- ⚠️ Boss spawning isn't connected to difficulty progression

## 🎯 Acceptance Criteria

- [ ] Regular enemy spawn rates increase with MapLevel progression (8% faster per level)
- [ ] Individual enemy stats scale with MapLevel (health +12%, damage +10% per level)
- [ ] Boss spawning integrates with difficulty credit system
- [ ] All scaling respects performance constraints (30Hz combat compatibility)
- [ ] Balance data hot-reloadable via BalanceDB integration
- [ ] Scaling can be toggled/configured for rapid balance iteration
- [ ] Performance impact <2ms per combat step for scaling calculations
- [ ] Comprehensive test suite validates scaling progression accuracy

## 🔍 Technical Analysis

### Affected Systems
- [x] **autoload/MapLevel.gd** - Add enhanced scaling methods for different difficulty aspects
- [x] **scripts/systems/SpawnDirector.gd** - Apply MapLevel scaling to regular enemy spawning
- [x] **scripts/systems/enemy_v2/EnemyFactory.gd** - Add stat scaling after template variation
- [x] **scripts/systems/BossSpawnManager.gd** - Integrate credit-based spawning system
- [ ] **data/balance/difficulty_scaling.tres** - New resource for scaling configuration
- [ ] **scripts/systems/DifficultyDirector.gd** - New credit-based scaling coordinator
- [ ] **scripts/domain/DifficultyConfig.gd** - New resource class for scaling data
- [ ] **tests/test_difficulty_scaling.tscn** - Comprehensive scaling validation

### Dependencies & Patterns
- **EventBus Signals:** `difficulty_level_changed`, `spawn_rate_modified`, `enemy_stats_scaled`
- **Resource Files:** `/data/balance/difficulty_scaling.tres` with credit thresholds and multipliers
- **Performance Impact:** Cached scaling calculations, 30Hz combat step compatible
- **Testing Strategy:** .tscn test scenes with accelerated MapLevel progression

## 📊 Implementation Plan

### Phase 1: Foundation - Enhanced MapLevel Methods
- [ ] Add `get_enemy_stat_scaling()` method to MapLevel autoload
- [ ] Add `get_spawn_interval_scaling()` method for spawn rate modifications
- [ ] Add `get_event_frequency_scaling()` method for boss/event spawning
- [ ] Create `DifficultyConfig` resource class with scaling curves and thresholds
- [ ] Implement scaling result caching to minimize per-frame calculations
- [ ] Add EventBus signals for difficulty progression notifications

### Phase 2: Core Implementation - SpawnDirector Integration
- [ ] Modify regular enemy spawning to use `MapLevel.get_spawn_interval_scaling()`
- [ ] Apply level scaling to spawn count ranges with proper caps
- [ ] Integrate scaling with existing wave progression multipliers
- [ ] Add performance monitoring for spawn scaling calculations
- [ ] Create fallback mechanisms if scaling impacts performance

### Phase 3: Enemy Stat Scaling - EnemyFactory Enhancement
- [ ] Add MapLevel stat multipliers to spawn configuration generation
- [ ] Apply scaling after template variation but before final config
- [ ] Implement stat scaling caps to prevent extreme values
- [ ] Add debug logging for scaled enemy stats (bosses category)
- [ ] Create stat scaling validation to ensure reasonable progression

### Phase 4: Credit-Based Boss System - DifficultyDirector
- [ ] Create `DifficultyDirector` system for credit accumulation
- [ ] Implement credit-based boss spawning cost system
- [ ] Integrate with existing BossSpawnManager for cost validation
- [ ] Add credit generation scaling based on MapLevel progression
- [ ] Create credit spending mechanics for boss spawn events

### Phase 5: Testing & Validation
- [ ] Create comprehensive scaling progression test suite
- [ ] Implement accelerated time testing (0.1s per level for rapid validation)
- [ ] Add performance regression tests for 30Hz combat compatibility
- [ ] Create Monte-Carlo simulations for balance validation
- [ ] Test edge cases (rapid level changes, extreme scaling values)

### Phase 6: Balance & Configuration
- [ ] Create hot-reloadable difficulty curves using Godot Curve resources
- [ ] Implement BalanceDB integration for runtime configuration changes
- [ ] Add emergency scaling disable toggle for balance emergencies
- [ ] Create visual feedback for difficulty level changes in HUD
- [ ] Document scaling formulas and balance considerations

## 🔗 Related Files

### Will Modify:
- [ ] `autoload/MapLevel.gd` - Enhanced scaling methods
- [ ] `scripts/systems/SpawnDirector.gd` - Regular spawn scaling integration
- [ ] `scripts/systems/enemy_v2/EnemyFactory.gd` - Stat scaling application
- [ ] `scripts/systems/BossSpawnManager.gd` - Credit system integration
- [ ] `autoload/EventBus.gd` - New difficulty progression signals
- [ ] `data/debug.tres` - Add scaling debug category
- [ ] `scripts/domain/LogConfigResource.gd` - Add scaling debug category

### Will Create:
- [ ] `scripts/systems/DifficultyDirector.gd` - Credit-based scaling coordinator
- [ ] `scripts/domain/DifficultyConfig.gd` - Scaling configuration resource
- [ ] `data/balance/difficulty_scaling.tres` - Balance configuration
- [ ] `tests/test_difficulty_scaling.tscn` - Comprehensive test suite
- [ ] `tests/test_scaling_performance.tscn` - Performance validation

### Documentation Updates Needed:
- [ ] `autoload/CLAUDE.md` - MapLevel and EventBus pattern updates
- [ ] `scripts/systems/CLAUDE.md` - DifficultyDirector integration patterns
- [ ] `scripts/domain/CLAUDE.md` - New DifficultyConfig resource model
- [ ] `tests/CLAUDE.md` - Scaling test execution patterns
- [ ] `Obsidian/systems/Difficulty-Scaling-System.md` - Complete system documentation

## 📚 Official Godot Documentation Research

### Relevant Concepts from Godot Docs:
- **Timer Systems**: `SceneTree.create_timer()` for one-shot delays, `Timer.timeout` signals for recurring events
- **Resource Management**: `Resource.changed` signal for hot-reload, `@export` properties for editor configuration
- **Signal Patterns**: Proper connection/disconnection lifecycle, typed signal payloads for performance
- **Performance Optimization**: Curve resource sampling, cached calculations, fixed-step integration

### Best Practices Identified:
- **Fixed-Step Timing**: All progression calculations should integrate with 30Hz combat step
- **Resource-Based Config**: Use `.tres` files with Curve resources for designer-configurable scaling
- **Signal Lifecycle**: Proper `_EnterTree`/`_ExitTree` signal management for dynamic connections
- **Memory Management**: Pre-allocated arrays and object pools for high-frequency scaling calculations

### Examples from Documentation:
- Timer-based progression using `Timer.timeout` signals for deterministic advancement
- Resource property setters that emit `changed` signals for hot-reload integration
- Custom performance monitors using `Performance.add_custom_monitor()` for scaling validation
- SceneTree timer creation for delayed boss spawning events

### Performance Considerations:
- Cache scaling multipliers to avoid repeated curve sampling
- Use PackedFloat32Array for pre-computed scaling values
- Limit scaling calculations to once per second maximum frequency
- Implement emergency performance fallbacks if frame rate drops

## 📝 Progress Notes

### 2025-09-29 - Planning
- Initial task creation based on comprehensive research
- Analyzed existing MapLevel, SpawnDirector, and EnemyFactory integration points
- Identified Risk of Rain 2 director system inspiration for credit-based approach
- Completed parallel agent analysis: code archaeology, technical research, risk assessment
- Researched Godot documentation via Context7 MCP for timer and signal patterns

## 🚨 Risks & Considerations

### Performance Risks (CRITICAL)
- **30Hz Combat Impact**: Scaling calculations must complete <2ms per combat step
- **Memory Usage**: Scaling data caching vs dynamic calculation balance
- **Spawn Rate Scaling**: Exponential enemy increases could breach 1000 enemy limit
- **Mitigation**: Implement tiered caching, scaling caps, and performance monitoring

### Architecture Risks (HIGH)
- **System Coupling**: Avoid tight coupling between MapLevel and individual systems
- **Balance Disruption**: Existing boss scaling (5x health, 2x damage) conflicts with dynamic scaling
- **EventBus Load**: New difficulty signals must not impact existing signal performance
- **Mitigation**: Use ScalingCoordinator pattern, validate scaling bounds, object pools for signals

### Testing Complexity (MEDIUM)
- **Time-Based Progression**: MapLevel increases every 10-60 seconds makes testing slow
- **Compound Effects**: Multiple scaling systems interacting creates complex test scenarios
- **Performance Regression**: Scaling impact difficult to validate without comprehensive benchmarks
- **Mitigation**: Accelerated progression for tests, isolated system testing, automated performance validation

### Implementation Risk (MEDIUM)
- **Resource Hot-Reload**: BalanceDB changes mid-game could reset scaling progression
- **Save/Load**: MapLevel progression not persisted across sessions
- **Emergency Rollback**: Need ability to disable scaling if balance breaks
- **Mitigation**: Scaling state validation, emergency disable toggle, comprehensive rollback testing

## ✅ Definition of Done

- [ ] All acceptance criteria met and validated through testing
- [ ] Code follows vibe project patterns (30Hz fixed-step, EventBus signals, layer boundaries)
- [ ] MapLevel scaling methods properly integrated with existing systems
- [ ] EnemyFactory stat scaling respects template ranges while adding level progression
- [ ] SpawnDirector regular spawning scales with MapLevel without breaking pack spawning
- [ ] DifficultyDirector credit system provides boss spawning cost control
- [ ] EventBus signals properly typed with payload classes for performance
- [ ] Logger used with appropriate categories (no print() statements)
- [ ] Comprehensive test suite covering progression, performance, and edge cases
- [ ] Balance data hot-reloadable with BalanceDB integration
- [ ] Documentation updated for all affected systems and new patterns
- [ ] CHANGELOG.md updated with scaling system integration summary
- [ ] Performance validated: <2ms scaling calculations, 30Hz combat compatibility maintained
- [ ] Emergency controls implemented: scaling disable toggle, rollback capabilities
- [ ] Commit ready with conventional format: `feat(combat): integrate MapLevel difficulty scaling with credit-based director system`

## 🎯 Success Metrics

### Functional Validation:
- Enemy spawn rate increases 8% per MapLevel without performance degradation
- Enemy health scales 12% per level, damage 10% per level within reasonable bounds
- Boss spawning cost system prevents inappropriate boss spam
- All scaling respects caps and emergency disable functionality

### Performance Validation:
- Scaling calculations complete <2ms per 30Hz combat step
- Memory usage increases <10% baseline per 10 MapLevel increases
- Frame rate maintains 30+ FPS with scaling active through level 50
- No observable hitches during MapLevel transitions

### Balance Validation:
- Scaled enemies provide appropriate challenge progression
- Player progression keeps pace with enemy scaling
- Boss encounters remain balanced with credit cost system
- Extreme scaling scenarios (level 100+) remain playable

---

**Related:** [MapLevel System](../systems/MapLevel-System.md) | [Spawn Director](../systems/Spawn-Director-System.md) | [Combat Architecture](../../ARCHITECTURE.md#fixed-step-combat-loop-decision-5a)