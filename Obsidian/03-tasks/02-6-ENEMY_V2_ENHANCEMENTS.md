# 6-ENEMY_V2_ENHANCEMENTS

**Status:** Ready to Start  
**Owner:** Solo (Indie)  
**Priority:** Medium  
**Dependencies:** Enemy V2 MVP Complete (see completed-tasks), BalanceDB, ArenaConfig, EventBus  
**Risk:** Low (additive enhancements to working system)  
**Complexity:** 6/10 (Medium - extends existing V2 foundation)  

---

## Context & Purpose

The Enemy V2 MVP is complete and working excellently. This task implements the remaining enhancements to create a fully data-driven enemy spawning system with scaling mechanics and arena-specific spawn plans.

**What's already done (MVP):**
- ✅ EnemyFactory with template system
- ✅ Boss scene spawning with AnimatedSprite2D workflow  
- ✅ Hybrid rendering (MultiMesh + scenes)
- ✅ Deterministic variations
- ✅ 9 working enemy templates
- ✅ Performance validated (500+ enemies)

**What this task adds:**
- Boss base class system for reusable boss patterns
- Enemy scaling system (time-based and tier-based multipliers)
- Arena-specific spawn configuration
- Data-driven spawn scheduling by phases
- SpawnDirector for advanced spawn management

---

## Goals & Success Criteria

### Primary Goals
1. **Boss Framework**: Reusable BaseBoss.gd with common boss patterns
2. **Dynamic Scaling**: Time and tier-based enemy scaling via BalanceDB
3. **Arena Integration**: Connect spawn plans to specific arenas
4. **Phase-Based Spawning**: Data-driven spawn scheduling (early/mid/late game phases)
5. **Zone-Based Spawning**: Control which enemies spawn in which map areas

### Success Criteria
- [ ] BaseBoss.gd provides reusable boss behavior foundation
- [ ] Enemy stats scale based on elapsed time and enemy tier
- [ ] ArenaConfig specifies spawn_plan and scaling_profile for each arena
- [ ] SpawnPool resources define enemy composition by phase
- [ ] SpawnDirector schedules enemies based on time phases and zone weights
- [ ] All features work with existing V2 toggle system
- [ ] No performance regression from V2 MVP baseline

---

## Implementation Plan

### Phase 1: Boss Base System (1.5 hours)
**Files to create:**
- `scripts/domain/BossTemplate.gd` - Boss-specific configuration resource
- `scripts/systems/BaseBoss.gd` - Reusable boss controller base class
- `scenes/bosses/BossBase.tscn` - Base boss scene template

**Tasks:**
1. Create BossTemplate extending EnemyTemplate with boss-specific fields:
   - `phase_health_thresholds: Array[float]` (e.g., [0.75, 0.5, 0.25])
   - `telegraph_duration: float` 
   - `phase_abilities: Dictionary[int, Array[StringName]]`
2. Create BaseBoss.gd with common boss patterns:
   - Health-based phase transitions
   - Telegraph system with visual/audio hooks  
   - Signal emissions: `phase_changed(phase)`, `telegraph_started(ability)`, `telegraph_ended()`
   - UI integration hooks for health bars and warnings
3. Update AncientLich to extend BaseBoss (optional inheritance)
4. Use deterministic RNG via `RNG.stream("ai")` for boss decision-making

### Phase 2: Enemy Scaling System (1 hour)
**Files to modify:**
- `autoload/BalanceDB.gd` - Add enemy_scaling schema
- `scripts/systems/enemy_v2/EnemyFactory.gd` - Apply scaling multipliers
- `data/balance/balance_config.tres` - Add scaling data

**Tasks:**
1. Add enemy_scaling to BalanceDB:
   ```gdscript
   enemy_scaling: {
     "time_multipliers": {
       "60": {"health": 1.2, "damage": 1.1},
       "120": {"health": 1.5, "damage": 1.3},
       "180": {"health": 2.0, "damage": 1.6}
     },
     "tier_multipliers": {
       "elite": {"health": 2.0, "damage": 1.5},
       "boss": {"health": 5.0, "damage": 2.0}
     }
   }
   ```
2. Update EnemyFactory.spawn_from_weights() to accept scaling context:
   - `elapsed_time: float` or `wave_index: int` for time-based scaling
   - `tier_tags: Array[StringName]` for tier-based scaling
3. Apply multipliers to base template stats before variation generation
4. Ensure scaling works for both pooled enemies and boss scenes

### Phase 3: Arena Configuration Updates (45 minutes)
**Files to modify:**
- `scripts/domain/ArenaConfig.gd` - Add spawn plan references
- `scripts/systems/ArenaSystem.gd` - Emit spawn plan signals
- Sample arena configs in `data/content/arenas/`

**Tasks:**
1. Add fields to ArenaConfig:
   - `spawn_plan: String` - path to ArenaSpawnPlan.tres
   - `enemy_scaling_profile: String` - scaling profile name
   - `boss_sequence: Array[String]` - boss IDs to spawn at milestones
2. Update ArenaSystem to emit spawn configuration:
   - `EventBus.arena_spawn_config_loaded.emit(spawn_plan, scaling_profile, boss_sequence)`
3. Create sample arena config demonstrating new fields
4. Ensure backward compatibility with existing arena configs

### Phase 4: Spawn Plan Resources (1 hour)
**Files to create:**
- `scripts/domain/SpawnPool.gd` - Enemy pool configuration resource
- `scripts/domain/ArenaSpawnPlan.gd` - Complete spawn plan resource
- Sample spawn plans in `data/content/spawn_plans/`

**Tasks:**
1. Create SpawnPool.gd:
   ```gdscript
   @export var id: StringName
   @export var include_ids: Array[StringName]  # Template IDs to include
   @export var include_tags: Array[StringName]  # Or tags to match
   @export var weights: Dictionary  # StringName -> float weights
   ```
2. Create ArenaSpawnPlan.gd:
   ```gdscript
   @export var phases: Array[Dictionary]  # [{time_start: 0, time_end: 60, pools: ["early"]}]
   @export var zone_weights: Dictionary  # {"north": 0.4, "south": 0.6}
   @export var boss_events: Array[Dictionary]  # [{at_time: 120, boss_id: "ancient_lich", zone: "center"}]
   @export var spawn_pools: Array[SpawnPool]
   ```
3. Create sample spawn plan: `data/content/spawn_plans/forest_arena_plan.tres`
4. Design sample pools: "early", "mid", "late", "boss" with appropriate enemy compositions

### Phase 5: SpawnDirector Implementation (1.5 hours)
**Files to create:**
- `scripts/systems/SpawnDirector.gd` - Phase-based spawn scheduler
- Update WaveDirector integration

**Tasks:**
1. Create SpawnDirector.gd:
   - Listen for `arena_spawn_config_loaded` signal
   - Load ArenaSpawnPlan from path
   - Track current phase based on elapsed combat time
   - Schedule boss events at specified times
   - Use zone_weights for spawn position selection
2. Implement deterministic spawn selection:
   - Use `RNG.stream("waves")` with `hash(run_id, phase_index, spawn_index)`
   - Select pool by current phase
   - Select template by pool weights  
   - Select zone by zone weights
3. Integration with existing systems:
   - Call existing V2 spawn seam in WaveDirector
   - Provide scaling context (elapsed_time, tier_tags) to EnemyFactory
   - Maintain compatibility with manual spawning (debug keys)
4. Add 30Hz update cycle for phase transitions and boss event scheduling

### Phase 6: Testing & Polish (30 minutes)
**Tasks:**
1. Test phase transitions work correctly based on elapsed time
2. Verify boss events trigger at specified times with correct bosses
3. Confirm zone-based spawning affects spawn positions
4. Test enemy scaling applies correctly across time and tiers
5. Ensure V2 toggle still works and can disable all enhancements
6. Validate no performance regression from SpawnDirector overhead

---

## Data Schema Examples

### SpawnPool Example
```tres
[gd_resource type="SpawnPool"]

[resource]
id = "early_game"
include_tags = ["basic", "common"]
weights = {
  "goblin": 0.4,
  "orc_warrior": 0.3,
  "archer": 0.3
}
```

### ArenaSpawnPlan Example
```tres
[gd_resource type="ArenaSpawnPlan"]

[resource]
phases = [
  {"time_start": 0, "time_end": 60, "pools": ["early_game"]},
  {"time_start": 60, "time_end": 180, "pools": ["mid_game", "early_game"]},
  {"time_start": 180, "time_end": -1, "pools": ["late_game", "elite"]}
]
zone_weights = {
  "north_spawn": 0.3,
  "south_spawn": 0.3,  
  "east_spawn": 0.2,
  "west_spawn": 0.2
}
boss_events = [
  {"at_time": 120.0, "boss_id": "ancient_lich", "zone": "center"},
  {"at_time": 300.0, "boss_id": "dragon_lord", "zone": "north_spawn"}
]
```

### Updated ArenaConfig Example
```tres
[gd_resource type="ArenaConfig"]

[resource]
arena_name = "Forest Arena"
spawn_plan = "res://data/content/spawn_plans/forest_arena_plan.tres"
enemy_scaling_profile = "standard"
boss_sequence = ["ancient_lich", "dragon_lord"]
# ... existing fields
```

---

## Architecture Integration

### System Communication Flow
```
ArenaSystem → EventBus.arena_spawn_config_loaded
     ↓
SpawnDirector → loads ArenaSpawnPlan → tracks phases
     ↓
30Hz update → select pool by phase → select template by weights
     ↓
WaveDirector._spawn_enemy_v2() → EnemyFactory.spawn_from_weights(scaling_context)
     ↓
Apply scaling → Generate variation → Route to MultiMesh/Scene
```

### Deterministic Seeding
- **Phase selection**: `hash(run_id, elapsed_time_seconds)`
- **Template selection**: `hash(run_id, phase_name, spawn_counter)`  
- **Zone selection**: `hash(run_id, template_id, spawn_counter)`
- **Boss scheduling**: `hash(run_id, "boss_events", event_index)`

### Backward Compatibility
- All features behind existing `BalanceDB.use_enemy_v2_system` toggle
- ArenaConfig fields optional - missing fields use defaults/disable features
- SpawnDirector only activates when spawn_plan provided
- Legacy spawn behavior preserved when SpawnDirector inactive

---

## Acceptance Criteria

### Functionality Requirements
- [ ] Boss templates define phase transitions and telegraph behavior
- [ ] BaseBoss.gd provides reusable boss controller patterns
- [ ] Enemy stats scale correctly based on time elapsed and enemy tier  
- [ ] Arena configs specify spawn plans and scaling profiles
- [ ] Spawn plans control enemy composition by time phases
- [ ] Zone weights affect where enemies spawn on the map
- [ ] Boss events trigger specific bosses at scheduled times
- [ ] All spawning remains deterministic with fixed RNG seeds

### Performance Requirements  
- [ ] SpawnDirector 30Hz updates cause no performance regression
- [ ] Phase calculations remain efficient during combat
- [ ] Resource loading doesn't cause hitches during gameplay
- [ ] Enemy scaling calculations don't impact spawn rate

### Integration Requirements
- [ ] Compatible with existing V2 toggle system
- [ ] Works alongside manual spawn debugging (B key, etc.)
- [ ] Doesn't break existing arena configs without new fields  
- [ ] Maintains compatibility with current WaveDirector flow
- [ ] Boss scenes continue working with new BaseBoss system

### Quality Requirements
- [ ] Clear error handling when spawn plans are malformed
- [ ] Graceful fallback when referenced templates don't exist
- [ ] Comprehensive logging for spawn decisions and phase transitions
- [ ] Documentation updated in data/README.md with new schemas

---

## Future Extensions (Not Required)

### Advanced Spawn Features
- **Conditional spawning**: Spawn different enemies based on player performance
- **Adaptive difficulty**: Dynamic scaling based on player success rate
- **Special events**: Holiday/seasonal spawn modifications
- **Weather effects**: Environmental spawn modifiers

### Boss System Expansion
- **Multi-phase bosses**: Complex state machines with phase-specific abilities
- **Boss telegraphs**: Visual warning system for boss attacks
- **Boss AI modules**: Modular behavior system for boss decision-making
- **Boss summoning**: Bosses that spawn additional enemies

### Performance Optimization
- **Spawn prediction**: Pre-calculate next N spawns for smoother performance
- **Pool preloading**: Cache frequently used spawn pools
- **Zone culling**: Only calculate spawns for zones near player
- **Batch processing**: Group spawn decisions for efficiency

---

## Risk Assessment & Mitigations

### Low Risk - System Extension
- **Benefit**: Building on proven V2 foundation
- **Mitigation**: All features additive and behind toggle system

### Medium Risk - Performance Impact  
- **Risk**: SpawnDirector 30Hz updates could impact performance
- **Mitigation**: Profile before/after, optimize spawn calculations
- **Fallback**: Reduce update frequency or simplify calculations

### Low Risk - Complexity Creep
- **Risk**: Too many spawn configuration options
- **Mitigation**: Start with simple examples, add complexity gradually
- **Validation**: Test with actual content creation workflow

---

## Timeline & Effort

**Total Effort:** ~6 hours across 6 phases

- **Phase 1 (Boss System):** 1.5 hours
- **Phase 2 (Scaling):** 1 hour  
- **Phase 3 (Arena Config):** 45 minutes
- **Phase 4 (Spawn Plans):** 1 hour
- **Phase 5 (SpawnDirector):** 1.5 hours
- **Phase 6 (Testing):** 30 minutes

**Recommended Schedule:**
- Week 1: Phases 1-3 (Boss system + scaling)
- Week 2: Phases 4-6 (Spawn plans + director + testing)

This creates a complete data-driven enemy spawning system that enables designers to control enemy composition, scaling, and timing entirely through .tres resource files.