# Map Level Difficulty Scaling Integration

**Created:** 2025-09-29
**Status:** 🟡 Planning
**Priority:** High
**Estimated Effort:** 2-3 weeks
**Category:** ⚔️ Combat System Enhancement

## 📋 Task Description

Integrate MapLevel's time-based progression system with difficulty scaling for bosses and spawning enemies. Create an MVP scaling system that increases enemy stats (health, damage, speed) and spawn rates as map level increases over time, inspired by MEGABONK's risk-engagement philosophy but adapted for our needs.

**UPDATED:** This task implements the MEGABONK-inspired arena progression system detailed in `Obsidian/02-brainstorm/ARENA_PROGRESSION/STAGE_PROGRESSION_VISION.md`. **Key Philosophy:** Reward players for taking risks and staying longer, with voluntary difficulty control and mathematical scaling limits.

**Current State Analysis:**
- ✅ MapLevel autoload system exists (10s per level for testing)
- ✅ SpawnDirector already uses `MapLevel.get_pack_size_scaling()` for pack spawning
- ✅ EnemyFactory has stat variation system within template ranges
- ⚠️ Regular enemy spawning doesn't scale with MapLevel
- ⚠️ Individual enemy stats don't scale with MapLevel
- ⚠️ Boss spawning isn't connected to difficulty progression

**MEGABONK System Integration Requirements:**
- ⚠️ MapLevel needs to support **difficulty coefficient** concept (MEGABONK-style time scaling)
- ⚠️ Need **fixed stage jump** mechanic (+1.0 coefficient per stage transition)
- ⚠️ Need **boss-kill deadline** mechanic (must kill boss before 10:00 to unlock portal)
- ⚠️ Need **Final Swarm trigger** at 10:00 timer expiration with exponential scaling
- ⚠️ Need **difficulty shrines** for voluntary +5% difficulty increases (Greed Shrine)
- ⚠️ Need **reward scaling** with difficulty (higher coefficient = better gold/XP)
- ⚠️ Need **mathematical ceiling** (~13:00 Final Swarm becomes impossible)
- ⚠️ Need **simple portal** that unlocks on boss kill and stays open during Final Swarm
- ⚠️ Boss/enemy difficulty determined by coefficient at spawn time

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

### MEGABONK System Integration (NEW)
- [ ] MapLevel exposes `get_difficulty_coefficient()` method (visible in UI bar)
- [ ] MapLevel supports `add_stage_jump(float)` method for fixed stage transitions (+1.0 default)
- [ ] Stage timer (10 minutes) with visible countdown in UI
- [ ] Boss spawns at fixed time (8:00) with difficulty scaled to current coefficient
- [ ] Boss-kill deadline enforced (must kill boss before 10:00 to unlock portal)
- [ ] Final Swarm triggers at 10:00 with exponential spawn rate + stat scaling
- [ ] Mathematical ceiling at ~13:00 (Final Swarm becomes impossible)
- [ ] Difficulty shrines (Greed Shrine) allow voluntary +5% difficulty increases
- [ ] Reward scaling: higher difficulty coefficient = better gold/XP per kill
- [ ] Simple portal entity unlocks on boss kill and stays accessible during Final Swarm
- [ ] EventBus signals support progression flow (`boss_killed`, `timer_expired`, `portal_entered`, `stage_started`, `final_swarm_started`, `shrine_activated`)
- [ ] Boss/enemy difficulty scales with coefficient at spawn time (real-time scaling)

## 🔍 Technical Analysis

### Affected Systems
- [x] **autoload/MapLevel.gd** - Add enhanced scaling methods for different difficulty aspects
- [x] **scripts/systems/SpawnDirector.gd** - Apply MapLevel scaling to regular enemy spawning
- [x] **scripts/systems/enemy_v2/EnemyFactory.gd** - Add stat scaling after template variation
- [x] **scripts/systems/BossSpawnManager.gd** - Integrate credit-based spawning system
- [ ] **data/balance/difficulty_scaling.tres** - New resource for scaling configuration
- [ ] **scripts/systems/ShrineSystem.gd** - New difficulty shrine management
- [ ] **scripts/domain/DifficultyConfig.gd** - New resource class for scaling data
- [ ] **scripts/domain/ShrineConfig.gd** - New resource class for shrine definitions
- [ ] **tests/test_difficulty_scaling.tscn** - Comprehensive scaling validation

### Dependencies & Patterns
- **EventBus Signals (Original):** `difficulty_level_changed`, `spawn_rate_modified`, `enemy_stats_scaled`
- **EventBus Signals (MEGABONK):** `boss_killed`, `timer_expired`, `portal_entered`, `stage_started`, `final_swarm_started`, `shrine_activated`, `boss_spawned`
- **Resource Files:** `/data/balance/difficulty_scaling.tres` with credit thresholds and multipliers
- **Performance Impact:** Cached scaling calculations, 30Hz combat step compatible
- **Testing Strategy:** .tscn test scenes with accelerated MapLevel progression
- **Stage Timer:** 10-minute countdown per stage, integrated with MapLevel progression
- **Coefficient Formula:** `enemyLevel = 1 + (coefficient - playerFactor) / 0.33` (from progression design)
- **Portal Mechanic:** Simple locked/unlocked state, no bubble event or special spawn logic

## 📊 Implementation Plan

**Approach:** Vertical slice with isolated testing - each phase delivers a playable, testable increment.

### Phase 1: Stage Timer + Boss Deadline Foundation (1-2 sessions) 🎯 START HERE
**Goal:** Working stage timer with boss deadline mechanics
**Test Scene:** `tests/StageTimer_Isolated.tscn`

- [ ] Create `StageTimer_Isolated.tscn` test scene with basic UI
- [ ] Add `get_difficulty_coefficient()` method to MapLevel autoload (returns current coefficient value)
- [ ] Implement 10-minute countdown timer in MapLevel (10:00 → 0:00)
- [ ] Display timer + difficulty coefficient in test scene (Label updates)
- [ ] Add time acceleration debug key (T = 100x speed for rapid testing)
- [ ] Add visual markers at key times (8:00 boss spawn, 10:00 Final Swarm) - print() statements
- [ ] Add EventBus.timer_expired signal when countdown reaches 0:00
- [ ] Add EventBus.boss_spawned signal at 8:00 mark
- [ ] Test coefficient increases correctly over 10 minutes (1.0 → ~5.5)

**Deliverable:** Can watch timer count down with boss spawn and Final Swarm triggers

---

### Phase 2: Boss Spawn + Final Swarm System (2-3 sessions)
**Goal:** Boss deadline and Final Swarm mechanics working
**Test Scene:** Extend `StageTimer_Isolated.tscn` with boss and swarm spawning

- [ ] Add SpawnDirector to test scene for enemy spawning
- [ ] Implement boss spawn system:
  - [ ] Boss spawns at 8:00 with difficulty scaled to current coefficient (~4.5)
  - [ ] Boss tracked via EventBus.boss_spawned signal
  - [ ] Boss kill tracked via EventBus.boss_killed signal
  - [ ] Visual feedback for boss spawn ("Boss has arrived!")
- [ ] Implement Final Swarm system:
  - [ ] Final Swarm triggers at 10:00 (EventBus.final_swarm_started signal)
  - [ ] Exponential spawn rate increase (3x → 5x → 10x normal)
  - [ ] Enemy stat scaling during Final Swarm (+50% → +100% → +200%)
  - [ ] Mathematical ceiling around 13:00 (spawn rate becomes impossible)
- [ ] Add on-screen event log (shows "8:00 - Boss Spawned!", "10:00 - Final Swarm!")
- [ ] Test boss-kill deadline (boss must die before 10:00)

**Deliverable:** Boss spawn at 8:00, Final Swarm escalation system working

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

### Phase 4: Difficulty Shrines + Reward Scaling (2-3 sessions)
**Goal:** Voluntary difficulty control and risk/reward mechanics
**Test Scene:** Add shrine system to existing test

- [ ] Create ShrineSystem for managing difficulty shrines:
  - [ ] Greed Shrine spawns randomly during stage (every 2-3 minutes)
  - [ ] Shrine interaction: +5% difficulty coefficient
  - [ ] Visual feedback: "Difficulty increased! (+5%)"
  - [ ] EventBus.shrine_activated signal with difficulty delta
- [ ] Implement reward scaling system:
  - [ ] Higher difficulty coefficient = better gold per kill
  - [ ] Higher difficulty coefficient = better XP per kill
  - [ ] Formula: reward_multiplier = 1.0 + (coefficient * 0.1)
  - [ ] Visual feedback: damage numbers show scaled rewards
- [ ] Add shrine interaction UI:
  - [ ] Shrine appears as interactable object (press E)
  - [ ] Confirmation dialog: "Increase difficulty for better rewards?"
  - [ ] Cost display (if any) and benefit explanation
- [ ] Test risk/reward balance:
  - [ ] More difficult enemies = more gold earned
  - [ ] Higher spawn rates = more kill opportunities
  - [ ] Shrines create strategic decision points

**Deliverable:** Voluntary difficulty control with visible risk/reward mechanics

---

### Phase 5: Portal System + Boss Deadline (2-3 sessions)
**Goal:** Complete stage cycle with boss-kill deadline
**Test Scene:** Add portal entity and deadline enforcement

- [ ] Create simple Portal scene (Sprite2D + Area2D + interaction logic):
  - [ ] Visual states: locked (gray), unlocked (green/glowing)
  - [ ] Spawns at stage start in locked state
  - [ ] Player can enter when unlocked (press E or walk into)
- [ ] Implement boss-kill deadline mechanics:
  - [ ] Boss must be killed before 10:00 timer expires
  - [ ] Boss kill unlocks portal permanently (EventBus.boss_killed)
  - [ ] Display "Portal Unlocked!" message on boss kill
  - [ ] Portal stays accessible during Final Swarm
- [ ] Implement deadline failure handling:
  - [ ] If timer expires (10:00) without boss kill → Portal stays locked
  - [ ] Display "FINAL SWARM - NO ESCAPE" warning message
  - [ ] Player trapped in Final Swarm until death (no progression)
- [ ] Implement success path:
  - [ ] Portal entry triggers EventBus.portal_entered signal
  - [ ] Display "Stage Completed!" message
  - [ ] Reset for next stage (prep for Phase 7)

**Deliverable:** Boss deadline creates clear objective, portal unlocks on success

---

### Phase 6: Final Swarm Intensity Tuning (1-2 sessions)
**Goal:** Mathematical ceiling with escalating intensity
**Test Scene:** Tune Final Swarm escalation curve

- [ ] Implement Final Swarm intensity scaling:
  - [ ] 10:00-11:00: Spawn rate 3x normal, stat multiplier +50%
  - [ ] 11:00-12:00: Spawn rate 5x, stat multiplier +100%
  - [ ] 12:00-13:00: Spawn rate 8x, stat multiplier +150%
  - [ ] 13:00+: Mathematical ceiling (spawn rate 10x, stats +200%, impossible)
- [ ] Add visual intensity feedback:
  - [ ] Screen shake increases with swarm intensity
  - [ ] Red vignette effect at edges
  - [ ] Spawn counter (enemies/second display)
  - [ ] Audio cues for intensity escalation
- [ ] Playtest and tune for balance:
  - [ ] Strong builds should survive 2-4 minutes in Final Swarm
  - [ ] Weak builds die within 1-2 minutes
  - [ ] Mathematical ceiling provides hard stop
  - [ ] Risk/reward: more kills vs death risk
- [ ] Add performance safeguards (enemy count cap at 1000)

**Deliverable:** Final Swarm provides optional leaderboard challenge with clear limits

---

### Phase 7: Stage Transition & Multi-Stage (2-3 sessions)
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

**Deliverable:** Full multi-stage progression loop working

---

### Phase 8: Polish & Configuration (2-3 sessions)
**Goal:** Hot-reloadable balance and visual polish

- [ ] Create `DifficultyConfig` resource class with scaling curves and thresholds
- [ ] Create `ShrineConfig` resource class for shrine definitions
- [ ] Create `/data/balance/difficulty_scaling.tres` with tunable values:
  - [ ] Stage duration (default 10 minutes)
  - [ ] Coefficient increase rate (default ~0.5 per minute)
  - [ ] Stage jump amount (default +1.0)
  - [ ] Boss spawn timing (default 8:00)
  - [ ] Final Swarm intensity curve
  - [ ] Shrine spawn rates and effects
  - [ ] Stat scaling multipliers (HP +30%, DMG +20%)
  - [ ] Reward scaling formulas
- [ ] Implement BalanceDB integration for hot-reload
- [ ] Add emergency scaling disable toggle (CheatSystem command)
- [ ] Create difficulty bar UI in HUD (top right: Easy → Normal → Hard → INSANE)
- [ ] Add timer display to HUD (top center: "8:32" countdown)
- [ ] Add stage number display to HUD (top left: "Stage 3")

**Deliverable:** Polished MEGABONK-style progression system with designer-friendly tuning

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
- [ ] `scripts/systems/ShrineSystem.gd` - Difficulty shrine management
- [ ] `scripts/domain/DifficultyConfig.gd` - Scaling configuration resource
- [ ] `scripts/domain/ShrineConfig.gd` - Shrine definitions resource
- [ ] `data/balance/difficulty_scaling.tres` - Balance configuration
- [ ] `data/balance/shrine_config.tres` - Shrine balance configuration
- [ ] `tests/test_difficulty_scaling.tscn` - Comprehensive test suite
- [ ] `tests/StageTimer_Isolated.tscn` - Isolated progression testing

### Documentation Updates Needed:
- [ ] `autoload/CLAUDE.md` - MapLevel and EventBus pattern updates
- [ ] `scripts/systems/CLAUDE.md` - ShrineSystem integration patterns
- [ ] `scripts/domain/CLAUDE.md` - New DifficultyConfig and ShrineConfig resource models
- [ ] `tests/CLAUDE.md` - Scaling test execution patterns
- [ ] `Obsidian/systems/MEGABONK-Difficulty-System.md` - Complete system documentation

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

### 2025-09-30 - MEGABONK System Conversion
- **MAJOR UPDATE:** Converted from ROR2 approach to MEGABONK risk-engagement philosophy
- **Key Change:** Shifted from "efficiency optimization" to "voluntary risk-taking" design
- Updated all acceptance criteria for boss-kill deadline mechanics
- Added Final Swarm system with mathematical ceiling (~13:00 impossible)
- Added difficulty shrine system (Greed Shrine +5% voluntary difficulty)
- Added reward scaling: higher difficulty = better gold/XP per kill
- Simplified technical complexity: removed ROR2 credit/director system
- Updated implementation phases to focus on core MEGABONK mechanics
- **Philosophy:** Rewards staying longer and taking risks, aligns with kill-count leaderboards
- **Boss Deadline:** Must kill boss before 10:00 to unlock portal progression
- **Final Swarm:** Optional challenge for leaderboard pushing, not punishment mechanic
- References MEGABONK Ultra Guide and Stage Progression Vision documents

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