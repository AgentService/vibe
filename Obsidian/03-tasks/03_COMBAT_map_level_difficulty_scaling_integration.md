# Map Level Difficulty Scaling Integration

**Created:** 2025-09-29
**Status:** 🟡 Planning
**Priority:** High
**Estimated Effort:** 2-3 weeks
**Category:** ⚔️ Combat System Enhancement

## 📋 Task Description

Integrate MapLevel's time-based progression system with difficulty scaling for bosses and spawning enemies. Create an MVP scaling system that increases enemy stats (health, damage, speed) and spawn rates as map level increases over time, inspired by Risk of Rain 2's director system but simplified for our needs.

**UPDATED:** This task now serves as the technical foundation for the MEGABONK-inspired arena progression system detailed in `Obsidian/02-brainstorm/ARENA_PROGRESSION/STAGE_PROGRESSION_VISION.md`.

**Current State Analysis:**
- ✅ MapLevel autoload system exists (10s per level for testing)
- ✅ SpawnDirector already uses `MapLevel.get_pack_size_scaling()` for pack spawning
- ✅ EnemyFactory has stat variation system within template ranges
- ⚠️ Regular enemy spawning doesn't scale with MapLevel
- ⚠️ Individual enemy stats don't scale with MapLevel
- ⚠️ Boss spawning isn't connected to difficulty progression

**Progression System Integration Requirements:**
- ⚠️ MapLevel needs to support **difficulty coefficient** concept (ROR2-style)
- ⚠️ Need **fixed stage jump** mechanic (+1.0 coefficient per stage transition)
- ⚠️ Need **timed event spawning** (mini-bosses at 3:00, 7:00; pressure waves at 4:00, 6:00, 8:00)
- ⚠️ Need **Final Swarm trigger** at 10:00 timer expiration with exponential scaling
- ⚠️ Need **boss-kill deadline** mechanic (must kill boss before 10:00 to unlock portal)
- ⚠️ Need **simple portal** that unlocks on boss kill (no special rift event mechanics)
- ⚠️ Boss/enemy difficulty determined by coefficient at spawn time (no snapshot needed)

## 🎯 Acceptance Criteria

### Core Scaling (Original)
- [ ] Regular enemy spawn rates increase with MapLevel progression (8% faster per level)
- [ ] Individual enemy stats scale with MapLevel (health +30%, damage +20% per level - UPDATED from progression design)
- [ ] Boss spawning integrates with difficulty credit system
- [ ] All scaling respects performance constraints (30Hz combat compatibility)
- [ ] Balance data hot-reloadable via BalanceDB integration
- [ ] Scaling can be toggled/configured for rapid balance iteration
- [ ] Performance impact <2ms per combat step for scaling calculations
- [ ] Comprehensive test suite validates scaling progression accuracy

### Progression System Integration (NEW)
- [ ] MapLevel exposes `get_difficulty_coefficient()` method (visible in UI bar)
- [ ] MapLevel supports `add_stage_jump(float)` method for fixed stage transitions (+1.0 default)
- [ ] SpawnDirector can trigger timed events (mini-boss at 3:00, 7:00; pressure waves at 4:00, 6:00, 8:00)
- [ ] SpawnDirector supports Final Swarm mode with exponential spawn rate increase
- [ ] BossSpawnManager enforces boss-kill deadline (10:00) and unlocks portal on success
- [ ] Simple portal entity that becomes usable after boss kill (no special event mechanics)
- [ ] Boss/enemy difficulty scales with coefficient at spawn time (real-time, no snapshot)
- [ ] EventBus signals support stage progression flow (`boss_killed`, `timer_expired`, `portal_entered`, `stage_started`)
- [ ] Mathematical ceiling implemented (Final Swarm becomes impossible around 13:00)

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
- **EventBus Signals (Original):** `difficulty_level_changed`, `spawn_rate_modified`, `enemy_stats_scaled`
- **EventBus Signals (Progression):** `boss_killed`, `timer_expired`, `portal_entered`, `stage_started`, `mini_boss_spawn`, `pressure_wave_start`
- **Resource Files:** `/data/balance/difficulty_scaling.tres` with credit thresholds and multipliers
- **Performance Impact:** Cached scaling calculations, 30Hz combat step compatible
- **Testing Strategy:** .tscn test scenes with accelerated MapLevel progression
- **Stage Timer:** 10-minute countdown per stage, integrated with MapLevel progression
- **Coefficient Formula:** `enemyLevel = 1 + (coefficient - playerFactor) / 0.33` (from progression design)
- **Portal Mechanic:** Simple locked/unlocked state, no bubble event or special spawn logic

## 📊 Implementation Plan

**Approach:** Vertical slice with isolated testing - each phase delivers a playable, testable increment.

### Phase 1: Stage Timer Foundation (1-2 sessions) 🎯 START HERE
**Goal:** Working stage timer with visual feedback
**Test Scene:** `tests/StageTimer_Isolated.tscn`

- [ ] Create `StageTimer_Isolated.tscn` test scene with basic UI
- [ ] Add `get_difficulty_coefficient()` method to MapLevel autoload (returns current coefficient value)
- [ ] Implement 10-minute countdown timer in MapLevel (10:00 → 0:00)
- [ ] Display timer + difficulty coefficient in test scene (Label updates)
- [ ] Add time acceleration debug key (T = 100x speed for rapid testing)
- [ ] Add visual markers at key times (3:00, 7:00, 8:00, 10:00) - print() statements
- [ ] Add EventBus.timer_expired signal when countdown reaches 0:00
- [ ] Test coefficient increases correctly over 10 minutes (1.0 → ~5.5)

**Deliverable:** Can watch timer count down and coefficient increase in isolated test

---

### Phase 2: Timed Event Spawning (2-3 sessions)
**Goal:** All timed events fire at correct times with visual feedback
**Test Scene:** Extend `StageTimer_Isolated.tscn` with enemy spawning

- [ ] Add SpawnDirector to test scene for enemy spawning
- [ ] Implement timed event trigger system in MapLevel:
  - [ ] Mini-boss spawn trigger at 3:00 (EventBus.mini_boss_spawn signal)
  - [ ] Pressure wave trigger at 4:00 (EventBus.pressure_wave_start signal)
  - [ ] Pressure wave trigger at 6:00
  - [ ] Mini-boss spawn trigger at 7:00
  - [ ] Pressure wave trigger at 8:00
  - [ ] Main boss spawn trigger at 8:00 (EventBus.boss_spawn signal)
  - [ ] Final Swarm trigger at 10:00 (EventBus.final_swarm_start signal)
  - [ ] Black Ghosts trigger at 11:00 (EventBus.black_ghosts_spawn signal)
- [ ] Wire SpawnDirector to respond to event signals:
  - [ ] Spawn 1 elite enemy on mini_boss_spawn
  - [ ] Spawn burst of 20 enemies on pressure_wave_start
  - [ ] Spawn 1 large boss enemy on boss_spawn
  - [ ] Spawn continuous waves on final_swarm_start
- [ ] Add on-screen event log (shows "3:00 - Mini Boss Spawned!" messages)
- [ ] Stop timed events when portal entered (future-proof for Phase 4)

**Deliverable:** All events fire at correct times with visible enemy spawns

---

### Phase 3: Difficulty Coefficient Scaling (2-3 sessions)
**Goal:** Enemies get visibly stronger over time
**Test Scene:** Continue with `StageTimer_Isolated.tscn`

- [ ] Add `get_enemy_stat_scaling(coefficient)` method to MapLevel
  - [ ] Returns multipliers: HP = 1.0 + (coeff * 0.3), DMG = 1.0 + (coeff * 0.2)
- [ ] Modify EnemyFactory to apply MapLevel stat multipliers:
  - [ ] Get current coefficient from MapLevel on enemy spawn
  - [ ] Apply scaling after template variation but before final config
  - [ ] Add debug logging for scaled stats (Logger.debug with "bosses" category)
- [ ] Implement stat scaling caps (max 10x multiplier) to prevent extreme values
- [ ] Add visual feedback in test scene:
  - [ ] Display enemy stats on spawn (HP, damage)
  - [ ] Color-code enemies by difficulty tier (green→yellow→red)
  - [ ] Show damage numbers when enemies take hits
- [ ] Test progression: enemies at 3:00 weaker than enemies at 9:00
- [ ] Create stat scaling validation (enemies should scale ~30%/20% per coefficient point)

**Deliverable:** Enemies spawn with scaled stats based on game time

---

### Phase 4: Boss-Kill Deadline & Portal (2-3 sessions)
**Goal:** Complete stage cycle with win/lose conditions
**Test Scene:** Add portal entity and boss-kill tracking

- [ ] Create simple Portal scene (Sprite2D + Area2D + interaction logic):
  - [ ] Visual states: locked (gray), unlocked (green/glowing)
  - [ ] Spawns at 1:30 in locked state
  - [ ] Player can enter when unlocked (press E or walk into)
- [ ] Implement boss-kill deadline in BossSpawnManager:
  - [ ] Boss spawns at 8:00, scaled to current coefficient (~4.5)
  - [ ] Track boss kill via EventBus.boss_killed signal
  - [ ] Boss kill unlocks portal permanently
  - [ ] Display "Portal Unlocked!" message on boss kill
- [ ] Implement deadline failure handling:
  - [ ] If timer expires (10:00) without boss kill → Portal stays locked
  - [ ] Display "FINAL SWARM - NO ESCAPE" warning message
  - [ ] Player must survive or die (no stage progression)
- [ ] Implement success path:
  - [ ] Portal entry triggers EventBus.portal_entered signal
  - [ ] Display "Stage Completed!" message
  - [ ] Stop all spawning and reset timer (prep for Phase 6)
- [ ] Add portal accessibility during Final Swarm (if boss was killed)

**Deliverable:** Full stage cycle with clear win condition (kill boss + enter portal)

---

### Phase 5: Final Swarm Intensity Tuning (1-2 sessions)
**Goal:** Final Swarm feels overwhelming but survivable for 2-4 minutes
**Test Scene:** Add Final Swarm mode testing

- [ ] Implement `get_spawn_interval_scaling()` method for spawn rate modifications
- [ ] Implement Final Swarm spawn mode (triggered at 10:00):
  - [ ] 10:00-11:00: Spawn rate 3x normal, stat multiplier +50%
  - [ ] 11:00-12:00: Black Ghosts spawn, stat multiplier +100%, faster enemies
  - [ ] 12:00-13:00: Spawn rate 5x, stat multiplier +150%
  - [ ] 13:00+: Mathematical ceiling (spawn rate 10x, stats +200%, survival impossible)
- [ ] Add visual intensity feedback:
  - [ ] Screen shake increases with swarm intensity
  - [ ] Red vignette effect at edges
  - [ ] Spawn counter (enemies/second display)
- [ ] Playtest and tune for "feel":
  - [ ] Strong builds should survive 3-4 minutes
  - [ ] Weak builds die within 1-2 minutes
  - [ ] Mathematical ceiling is unavoidable death
- [ ] Add performance monitoring (enemy count cap at 1000)

**Deliverable:** Final Swarm provides optional high-skill challenge

---

### Phase 6: Stage Transition & Multi-Stage (2-3 sessions)
**Goal:** Multi-stage progression with coefficient jumps
**Test Scene:** Integrate with ProceduralMapManager

- [ ] Implement `add_stage_jump(float)` method in MapLevel (+1.0 default)
- [ ] Implement stage transition on portal entry:
  - [ ] Capture current coefficient (e.g., 5.5 at portal entry)
  - [ ] Apply +1.0 stage jump → new stage starts at 6.5
  - [ ] Emit EventBus.stage_started signal with new coefficient
  - [ ] Generate new procedural map (call ProceduralMapManager)
  - [ ] Reset stage timer to 10:00
  - [ ] Clear all enemies and projectiles
- [ ] Test multi-stage progression:
  - [ ] Stage 1: Coeff 1.0 → 5.5, boss at coeff ~4.5
  - [ ] Stage 2: Coeff 6.5 → 11.0, boss at coeff ~10.0
  - [ ] Stage 3: Coeff 12.0 → 16.5, boss at coeff ~15.5
- [ ] Add stage number display (top UI: "Stage 3")
- [ ] Validate scaling feels appropriate across 5+ stages
- [ ] Test that player can't progress past mathematical ceiling without dying

**Deliverable:** Full multi-stage progression loop working

---

### Phase 7: Polish & Configuration (2-3 sessions)
**Goal:** Hot-reloadable balance and visual polish

- [ ] Create `DifficultyConfig` resource class with scaling curves and thresholds
- [ ] Create `/data/balance/difficulty_scaling.tres` with tunable values:
  - [ ] Stage duration (default 10 minutes)
  - [ ] Coefficient increase rate (default ~0.5 per minute)
  - [ ] Stage jump amount (default +1.0)
  - [ ] Event timings (mini-boss, pressure waves, boss spawn)
  - [ ] Final Swarm intensity curve
  - [ ] Stat scaling multipliers (HP +30%, DMG +20%)
- [ ] Implement BalanceDB integration for hot-reload
- [ ] Add emergency scaling disable toggle (CheatSystem command)
- [ ] Create difficulty bar UI in HUD (top right: Easy → Normal → Hard → INSANE)
- [ ] Add timer display to HUD (top center: "8:32" countdown)
- [ ] Add stage number display to HUD (top left: "Stage 3")
- [ ] Document scaling formulas in `/Obsidian/systems/Difficulty-Scaling-System.md`

**Deliverable:** Polished progression system with designer-friendly tuning

---

### Phase 8: DifficultyDirector & Credits (Optional - Later)
**Goal:** ROR2-style spawn budget system for fine-tuned control
**Note:** This is the original task scope, deferred for later polish

- [ ] Create `DifficultyDirector` system for credit accumulation
- [ ] Implement credit-based boss spawning cost system
- [ ] Integrate with existing BossSpawnManager for cost validation
- [ ] Add credit generation scaling based on MapLevel progression
- [ ] Create credit spending mechanics for boss spawn events
- [ ] Add credit display for debugging (shows available credits)

**Deliverable:** Spawn budget system for advanced balance tuning

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

### 2025-09-30 - Progression System Integration
- Updated task to align with MEGABONK-inspired arena progression system
- Added progression-specific acceptance criteria (difficulty coefficient, stage jumps, timed events)
- Integrated boss-kill deadline and portal unlock mechanics
- Added Final Swarm trigger and mathematical ceiling requirements
- Updated stat scaling values (HP +30%, DMG +20% per level to match progression design)
- Added timed event spawning requirements (mini-bosses, pressure waves, boss spawn)
- Clarified: No snapshot scaling needed (spawn time = difficulty determination)
- Clarified: Simple portal entity, no special rift event/bubble mechanics
- Referenced `STAGE_PROGRESSION_VISION.md` as design source
- **IMPLEMENTATION APPROACH:** Restructured to vertical slice + isolated testing methodology
- Organized into 8 phases with clear deliverables and test scenes
- Phase 1 START HERE: Create `StageTimer_Isolated.tscn` for immediate visual feedback
- Deferred DifficultyDirector (ROR2 credits system) to Phase 8 (optional polish)

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

**Related:** [MapLevel System](../systems/MapLevel-System.md) | [Spawn Director](../systems/Spawn-Director-System.md) | [Combat Architecture](../../ARCHITECTURE.md#fixed-step-combat-loop-decision-5a) | [Stage Progression Vision](../02-brainstorm/ARENA_PROGRESSION/STAGE_PROGRESSION_VISION.md)