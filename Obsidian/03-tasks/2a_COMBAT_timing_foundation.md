# 2a: Combat Timing Foundation

**Created:** 2025-09-29
**Updated:** 2025-10-03 (Renamed from `2_COMBAT_map_level_difficulty_scaling_integration.md`)
**Status:** 🟡 Planning - Ready to Start
**Priority:** High
**Estimated Effort:** 1-2 weeks (Phases 1-3 only)
**Category:** ⚔️ Combat System Enhancement - Technical Foundation
**Dependent Tasks:** [Task 2b - Stage Progression Flow](2b_COMBAT_stage_progression_flow.md) ← **DO THIS NEXT**

> ⚠️ **Scope:** This task implements the **timing and difficulty scaling foundation** only (Phases 1-3). For the full progression flow (portal, stage transitions, rewards), see **Task 5**.

## 📋 Task Description

Implement the **timing and difficulty scaling foundation** for MEGABONK-style arena progression. This task provides the technical infrastructure (stage timer, boss spawn timing, Final Swarm trigger, enemy stat scaling) that Task 5 (Stage Progression) will build upon for the full gameplay loop.

**Scope:** This task is **Phases 1-3 only** - the timing engine. It does NOT implement:
- ❌ Portal system (Task 5)
- ❌ Stage transitions (Task 5)
- ❌ Tier unlocking (Task 5)
- ❌ Meta-currency rewards (Task 5)
- ❌ Progression UI (Task 5)

**Configuration (7-Minute Stages):**
- **Stage Duration:** 7:00 (420 seconds)
- **Boss Spawn:** 2:00 elapsed (5:00 remaining on countdown)
- **Final Swarm:** 7:00 elapsed (0:00 = timer expiration)

**Key Philosophy:** Reward players for taking risks and staying longer, with voluntary difficulty control and mathematical scaling limits (from MEGABONK).

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
- [x] **autoload/RunManager.gd** - Reference for 30Hz fixed-step timing pattern (already implemented)
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
- **RunManager Integration:** All difficulty scaling calculations must integrate with 30Hz fixed-step combat timing
  - Scaling updates occur during `EventBus.combat_step` signal processing
  - MapLevel timer progression syncs with RunManager's COMBAT_DT (33.33ms per step)
  - Ensures deterministic difficulty progression regardless of frame rate
  - See `autoload/RunManager.gd` for fixed-step accumulator pattern documentation
  - **Note:** RunManager was simplified in Task 04a cleanup - stats tracking removed
  - Stats (enemies_killed, damage_dealt, etc.) will move to SessionState autoload (Task 04 Phase 2)
  - This task should reference SessionState for stat tracking once it exists
- **Resource Files:** `/data/balance/difficulty_scaling.tres` with credit thresholds and multipliers
- **Performance Impact:** Cached scaling calculations, 30Hz combat step compatible (<2ms per step)
- **Testing Strategy:** .tscn test scenes with accelerated MapLevel progression
- **Stage Timer:** 10-minute countdown per stage, integrated with MapLevel progression via RunManager timing
- **Coefficient Formula:** `enemyLevel = 1 + (coefficient - playerFactor) / 0.33` (from progression design)
- **Portal Mechanic:** Simple locked/unlocked state, no bubble event or special spawn logic

## 📊 Implementation Plan

**Approach:** Technical foundation implementation - Phases 1-3 only due to missing player progression systems.

**SCOPE LIMITATION:** Phases 4-8 require player progression systems (abilities, stats, upgrades, economy) that don't exist yet. This task will implement the core timing and scaling infrastructure that other systems can build upon.

### Phase 1: Stage Timer + Difficulty Coefficient Foundation (1-2 sessions) 🎯 START HERE
**Goal:** Working 7-minute stage timer with coefficient tracking
**Test Scene:** `tests/StageTimer_Isolated.tscn`

**Configuration (7-Minute Stages):**
- **Stage Duration:** 420 seconds (7:00 total)
- **Boss Spawn Time:** 120 seconds elapsed (5:00 remaining)
- **Final Swarm Trigger:** 420 seconds (0:00 remaining = timer expiration)

**RunManager Integration Note:** Timer progression must sync with RunManager's 30Hz fixed-step timing. See `autoload/RunManager.gd` for the accumulator pattern - MapLevel should increment its timer during `EventBus.combat_step` processing to ensure deterministic progression regardless of frame rate.

- [ ] Create `StageTimer_Isolated.tscn` test scene with basic UI
- [ ] Add MapLevel timer infrastructure:
  - [ ] `const STAGE_DURATION: float = 420.0` - 7-minute stages
  - [ ] `var elapsed_time: float = 0.0` - Tracks seconds since stage start
  - [ ] `var in_final_swarm: bool = false` - Final Swarm state flag
- [ ] Add `get_difficulty_coefficient()` method to MapLevel autoload (returns current coefficient value)
- [ ] Add `get_elapsed_time() -> float` method (for boss spawn timing)
- [ ] Add `get_remaining_time() -> float` method (for countdown display)
- [ ] Add `is_timer_expired() -> bool` method (checks if >= STAGE_DURATION)
- [ ] Add `reset_level()` method (resets timer for new stage)
- [ ] Implement timer progression in `_on_combat_step()`:
  - [ ] `elapsed_time += RunManager.COMBAT_DT` (33.33ms per step)
  - [ ] Ensures deterministic progression at exactly 30 Hz
  - [ ] Accumulates fixed timesteps for precise timer
- [ ] Display timer + difficulty coefficient in test scene (Label updates)
- [ ] Add time acceleration debug key (T = 100x speed for rapid testing)
- [ ] Add visual markers at key times:
  - [ ] 2:00 elapsed (5:00 remaining) - Boss spawn marker
  - [ ] 7:00 elapsed (0:00 remaining) - Final Swarm marker
- [ ] Add EventBus.timer_expired signal when `elapsed_time >= STAGE_DURATION`
- [ ] Test coefficient increases correctly over 7 minutes

**Deliverable:** Can watch timer count down with boss spawn and Final Swarm triggers

---

### Phase 2: Boss Spawn Timing + Final Swarm Trigger (2-3 sessions)
**Goal:** Time-based boss spawn and Final Swarm activation
**Test Scene:** Extend `StageTimer_Isolated.tscn` with boss and swarm spawning

**Boss Spawn Configuration:**
- **Spawn Time:** 120 seconds elapsed (2:00 into stage, 5:00 remaining)
- **Boss Difficulty:** Scaled to current coefficient at spawn time
- **Spawn Method:** EventBus.boss_spawn_requested signal (BossSpawnManager handles actual spawning)

**Final Swarm Configuration:**
- **Trigger Time:** 420 seconds elapsed (7:00 = timer expiration, 0:00 remaining)
- **Escalation:** Exponential spawn rate increase over time
- **Ceiling:** Mathematical impossibility after ~3 minutes in Final Swarm

**Implementation:**
- [ ] Add BossSpawnManager to test scene
- [ ] Implement time-based boss spawn check in MapLevel:
  - [ ] Check if `elapsed_time >= 120.0` (boss spawn time)
  - [ ] Emit `EventBus.boss_spawn_requested` signal once
  - [ ] BossSpawnManager handles boss selection and spawning
  - [ ] Visual feedback: "Boss has arrived!" message
- [ ] Implement Final Swarm trigger in MapLevel:
  - [ ] Check if `elapsed_time >= STAGE_DURATION` (420 seconds)
  - [ ] Set `in_final_swarm = true` flag
  - [ ] Emit `EventBus.final_swarm_started` signal once
  - [ ] Visual feedback: "FINAL SWARM!" message
- [ ] Add spawn rate scaling during Final Swarm:
  - [ ] Base rate: 3x normal spawns (immediate)
  - [ ] Escalation: +2x every 30 seconds (3x → 5x → 7x → 9x)
  - [ ] Mathematical ceiling: ~10x at 3 minutes into Final Swarm
- [ ] Add enemy stat scaling during Final Swarm:
  - [ ] Initial: +50% HP, +30% damage
  - [ ] Escalation: Additional +25% HP/damage every 30 seconds
  - [ ] Cap: +200% HP, +150% damage (mathematical ceiling)
- [ ] Add on-screen event log showing:
  - [ ] "2:00 - Boss Spawned!" (at 2:00 elapsed)
  - [ ] "7:00 - FINAL SWARM!" (at timer expiration)
  - [ ] "Swarm Intensity: 5.2x" (real-time multiplier display)

**Deliverable:** Boss spawn at 2:00 elapsed (5:00 remaining), Final Swarm escalation system working

---

### Phase 3: Difficulty Coefficient Enemy Stat Scaling (2-3 sessions)
**Goal:** Enemies get visibly stronger over time based on coefficient
**Test Scene:** Continue with `StageTimer_Isolated.tscn`

**Coefficient Formula:**
- **Coefficient Progression:** Increases over time during stage
- **Scaling Formula:** HP = 1.0 + (coeff * 0.3), DMG = 1.0 + (coeff * 0.2)
- **Caps:** Max 10x multiplier to prevent extreme values

**Implementation:**
- [ ] Add `get_enemy_stat_scaling(coefficient: float) -> Dictionary` method to MapLevel:
  - [ ] Returns: `{"hp": float, "damage": float, "speed": float}`
  - [ ] HP multiplier: `1.0 + (coefficient * 0.3)` (30% per coefficient point)
  - [ ] Damage multiplier: `1.0 + (coefficient * 0.2)` (20% per coefficient point)
  - [ ] Speed multiplier: `1.0 + (coefficient * 0.1)` (10% per coefficient point)
  - [ ] Cap all multipliers at 10.0 max
- [ ] Modify EnemyFactory to apply MapLevel stat multipliers:
  - [ ] Get current coefficient: `var coeff = MapLevel.get_difficulty_coefficient()`
  - [ ] Get scaling multipliers: `var scaling = MapLevel.get_enemy_stat_scaling(coeff)`
  - [ ] Apply scaling after template variation but before final config:
    - [ ] `final_hp = base_hp * scaling.hp`
    - [ ] `final_damage = base_damage * scaling.damage`
    - [ ] `final_speed = base_speed * scaling.speed`
  - [ ] Add debug logging: `Logger.debug("Enemy spawned with %.1fx HP scaling (coeff: %.2f)" % [scaling.hp, coeff], "spawning")`
- [ ] Add visual feedback in test scene:
  - [ ] Display enemy stats on spawn (HP, damage) in labels
  - [ ] Color-code enemies by difficulty tier:
    - [ ] Green: coeff < 2.0 (easy)
    - [ ] Yellow: coeff 2.0-4.0 (medium)
    - [ ] Red: coeff > 4.0 (hard)
  - [ ] Show damage numbers when enemies take hits
- [ ] Test progression:
  - [ ] Enemies at 1:00 elapsed should be baseline stats
  - [ ] Enemies at 3:00 should be noticeably stronger
  - [ ] Enemies at 6:00 should be significantly harder
- [ ] Create stat scaling validation (enemies should scale ~30%/20% per coefficient point)

**Deliverable:** Enemies spawn with scaled stats based on game time

---

## 🔒 BLOCKED PHASES (Dependency Requirements)

### Phase 4: Difficulty Shrines + Reward Scaling (BLOCKED)
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

**DEPENDENCY REQUIREMENTS:**
- ❌ Player progression system (stats, abilities)
- ❌ Economy system (gold, XP, currency)
- ❌ Upgrade/reward system (chests, items, powerups)
- ❌ UI systems for rewards and progression feedback

---

### Phase 5: Portal System + Boss Deadline (PARTIAL - Multi-Stage Blocked)
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

**DEPENDENCY REQUIREMENTS:**
- ❌ Procedural map generation system
- ❌ Multi-stage progression framework
- ⚠️ Portal mechanics can be implemented for single-stage testing

---

### Phase 6: Final Swarm Intensity Tuning (BLOCKED)
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

**DEPENDENCY REQUIREMENTS:**
- ❌ Player progression system to make risk/reward meaningful
- ❌ Without player power scaling, Final Swarm is just "impossible difficulty"
- ❌ Economy system for meaningful rewards during Final Swarm

---

### Phase 7: Stage Transition & Multi-Stage (BLOCKED)
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

**DEPENDENCY REQUIREMENTS:**
- ❌ Procedural map generation system
- ❌ Multi-stage progression framework
- ❌ Player progression system for meaningful coefficient jumps

---

### Phase 8: Polish & Configuration (BLOCKED)
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

**DEPENDENCY REQUIREMENTS:**
- ❌ Player progression system (abilities, stats, upgrades)
- ❌ Economy system (gold, XP, rewards)
- ❌ UI systems (difficulty bar, timer display, progression feedback)
- ❌ Shrine system (difficulty shrines, reward scaling)

## 🏗️ Required Systems for Full Implementation

**To complete MEGABONK progression system, the following systems must be implemented first:**

### Player Progression Systems
- [ ] **Ability System:** Player skills, skill tree, ability upgrades
- [ ] **Player Stats System:** Health, damage, speed, defensive stats
- [ ] **Experience System:** XP gain, level progression, stat increases

### Economy & Rewards
- [ ] **Currency System:** Gold, XP, premium currencies
- [ ] **Chest/Loot System:** Reward containers, random upgrades
- [ ] **Item System:** Collectible upgrades, stat modifiers
- [ ] **Upgrade Shop:** Spend currency for improvements

### Core Game Systems
- [ ] **Procedural Map Generation:** Multi-stage level creation
- [ ] **Save/Load System:** Persist progression between sessions
- [ ] **UI Framework:** HUD components, modal dialogs, feedback systems

### Quality of Life
- [ ] **Visual Effects:** Screen shake, damage numbers, intensity feedback
- [ ] **Audio System:** Music progression, intensity-based audio cues
- [ ] **Settings System:** Difficulty toggles, accessibility options

**RECOMMENDATION:** Implement Phases 1-3 now to establish the timing and scaling framework, then return to complete Phases 4-8 after the above systems exist.

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

## ✅ Definition of Done (Phases 1-3: Timing Foundation Only)

**Core Timing Infrastructure:**
- [ ] Phase 1: 7-minute stage timer working (420 seconds)
- [ ] MapLevel.get_elapsed_time() returns seconds since stage start
- [ ] MapLevel.get_remaining_time() returns countdown (7:00 → 0:00)
- [ ] MapLevel.is_timer_expired() checks if timer reached 7:00
- [ ] MapLevel.reset_level() resets timer for new stage
- [ ] MapLevel.get_difficulty_coefficient() returns current difficulty value
- [ ] Timer syncs with RunManager 30Hz fixed-step (deterministic)
- [ ] EventBus.timer_expired emitted when stage time limit reached

**Boss Spawn Timing:**
- [ ] Phase 2: Boss spawn triggered at 2:00 elapsed (5:00 remaining)
- [ ] EventBus.boss_spawn_requested signal emitted once at spawn time
- [ ] BossSpawnManager handles actual boss selection/spawning
- [ ] Boss difficulty scaled to current coefficient at spawn time
- [ ] Visual feedback: "Boss has arrived!" message

**Final Swarm System:**
- [ ] Phase 2: Final Swarm triggered at 7:00 elapsed (0:00 = timer expiration)
- [ ] MapLevel.in_final_swarm flag set when Final Swarm starts
- [ ] EventBus.final_swarm_started signal emitted once
- [ ] Spawn rate escalates over time (3x → 5x → 7x → 9x)
- [ ] Enemy stat scaling during Final Swarm (+50% HP initially, escalating)
- [ ] Mathematical ceiling reached after ~3 minutes (~10x spawn rate)
- [ ] Visual feedback: "FINAL SWARM!" message + intensity display

**Enemy Stat Scaling:**
- [ ] Phase 3: MapLevel.get_enemy_stat_scaling(coeff) returns HP/damage/speed multipliers
- [ ] EnemyFactory applies scaling on spawn (after template variation)
- [ ] Scaling formula: HP +30% per coeff point, Damage +20% per coeff point
- [ ] Scaling caps at 10x multiplier maximum
- [ ] Debug logging shows scaled stats (Logger.debug with "spawning" category)
- [ ] Visual feedback: color-coded enemies (green → yellow → red)

**Testing & Integration:**
- [ ] Test scene `StageTimer_Isolated.tscn` demonstrates all features
- [ ] Time acceleration debug key (T = 100x) for rapid testing
- [ ] Event log shows key milestones (Boss spawn, Final Swarm)
- [ ] Performance validated: <2ms scaling calculations per combat step
- [ ] 30Hz combat compatibility maintained (no frame rate dependence)
- [ ] Code follows project patterns (EventBus, Logger, 30Hz fixed-step, layer boundaries)

**Documentation:**
- [ ] autoload/CLAUDE.md updated with MapLevel timer API
- [ ] EventBus signals documented (timer_expired, boss_spawn_requested, final_swarm_started)
- [ ] CHANGELOG.md updated with timing foundation summary
- [ ] Clear note: "Task 2b builds progression flow on this timing foundation"

**Cross-Task Coordination:**
- [ ] **Task 2b Integration Point:** Timer API ready for HUD display
- [ ] **Task 2b Integration Point:** Boss spawn timing configurable
- [ ] **Task 2b Integration Point:** Final Swarm trigger works with portal system
- [ ] Commit ready: `feat(combat): implement 7-minute stage timer and difficulty scaling foundation for MEGABONK progression`

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

**Related:** [Task 2b - Stage Progression Flow (DO NEXT)](2b_COMBAT_stage_progression_flow.md) | [MapLevel System](../systems/MapLevel-System.md) | [Spawn Director](../systems/Spawn-Director-System.md) | [Combat Architecture](../../ARCHITECTURE.md#fixed-step-combat-loop-decision-5a) | [Stage Progression Vision](../02-brainstorm/ARENA_PROGRESSION/STAGE_PROGRESSION_VISION.md)

---

## 🔗 Task 2b Integration Points (For Future Reference)

**When Task 2b starts, it will use these APIs from Task 2a:**

### MapLevel Timer API:
```gdscript
# Task 2b reads these methods (no timer implementation needed)
MapLevel.get_elapsed_time() -> float      # Seconds since stage start
MapLevel.get_remaining_time() -> float    # Countdown (7:00 → 0:00)
MapLevel.is_timer_expired() -> bool       # Check if timer reached 7:00
MapLevel.reset_level() -> void            # Reset for new stage
MapLevel.get_difficulty_coefficient() -> float  # Current difficulty
```

### EventBus Signals:
```gdscript
# Task 2b listens to these signals (Task 2a emits them)
EventBus.timer_expired                    # 7:00 elapsed, Final Swarm starts
EventBus.boss_spawn_requested             # 2:00 elapsed, spawn boss
EventBus.final_swarm_started              # Final Swarm phase begins
```

### Configuration:
```gdscript
# Shared constants (both tasks must use same values)
STAGE_DURATION = 420.0       # 7:00 total stage time
BOSS_SPAWN_TIME = 120.0      # 2:00 elapsed (5:00 remaining)
FINAL_SWARM_TRIGGER = 420.0  # 7:00 elapsed (0:00 = timer expiration)
```