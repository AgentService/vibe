# Spawn System v2 (Consolidated: Director + Scaling + Map Pools)

Status: Ready to Start  
Owner: Solo (Indie)  
Priority: High  
Type: System Enhancement  
Dependencies: 19-MAP_ARENA_SYSTEM_FOUNDATION_V1, 17-RUN_CLOCK_AND_PHASES_SERVICE, Enemy V2 MVP Complete, BalanceDB, EventBus, RNG  
Risk: Medium-Low (builds on proven foundations)  
Complexity: 7/10

---

## Background

This task consolidates and builds upon the Map/Arena Foundation (task 19) to create a complete data-driven enemy spawning system. It combines map-based enemy pools, phase-based scheduling, dynamic scaling, and advanced spawn management into a unified system.

**Foundation Dependencies:**
- ✅ 19-MAP_ARENA_SYSTEM_FOUNDATION_V1: MapDef, MapInstance, SpawnProfile, ModifiersService
- ✅ 17-RUN_CLOCK_AND_PHASES_SERVICE: Centralized time/phase tracking
- ✅ Enemy V2 MVP: EnemyFactory, template system, hybrid rendering, deterministic variations

---

## Goals & Acceptance Criteria

### Primary Goals
1. **SpawnDirector**: Phase-based spawn scheduling using RunClock and MapInstance.SpawnProfile
2. **Boss Framework**: Reusable BaseBoss.gd with common boss patterns and telegraph system
3. **Dynamic Scaling**: Time and tier-based enemy scaling via BalanceDB + ModifiersService
4. **Map Pool Integration**: Use MapInstance.SpawnProfile for enemy composition per map
5. **Zone-Based Spawning**: Control spawn positions via zone weights and static SpawnPoints

### Success Criteria
- [ ] SpawnDirector schedules enemies based on RunClock phases and MapInstance.SpawnProfile
- [ ] BaseBoss.gd provides reusable boss behavior foundation with phase transitions
- [ ] Enemy stats scale via ModifiersService (tier) + BalanceDB (time-based multipliers)
- [ ] Map-specific enemy pools work via SpawnProfile.enemy_pools from MapInstance
- [ ] Zone weights and static SpawnPoints control spawn positioning
- [ ] Boss events trigger at scheduled times with proper telegraph system
- [ ] All features integrate with existing V2 toggle system
- [ ] No performance regression; deterministic behavior preserved

---

## Implementation Plan

### Phase 1: SpawnDirector Foundation (2 hours)
**Files to create:**
- `scripts/systems/SpawnDirector.gd` - Phase-based spawn scheduler
- `scripts/domain/SpawnPool.gd` - Enemy pool configuration (extends SpawnProfile)

**Tasks:**
1. Create SpawnDirector.gd:
   - Listen for `EventBus.map_started(MapInstance)` signal
   - Extract SpawnProfile from MapInstance.snapshot_spawn_profile
   - Subscribe to RunClock.phase_changed and RunClock.tick signals
   - Track current phase and schedule spawns accordingly
2. Enhance SpawnProfile.gd (from task 19):
   ```gdscript
   # Add to existing SpawnProfile from task 19
   @export var phases: Array[Dictionary] = [] # [{time_start: 0, time_end: 60, pools: ["early"]}]
   @export var zone_weights: Dictionary = {} # {"north": 0.3, "south": 0.3}
   @export var boss_events: Array[Dictionary] = [] # [{at_time: 120, boss_id: "ancient_lich"}]
   ```
3. Integration with WaveDirector:
   - SpawnDirector calls existing WaveDirector._spawn_enemy_v2() seam
   - Pass scaling context (elapsed_time, tier_tags) to EnemyFactory

### Phase 2: Boss Framework System (1.5 hours)
**Files to create:**
- `scripts/domain/BossTemplate.gd` - Boss-specific configuration resource
- `scripts/systems/BaseBoss.gd` - Reusable boss controller base class
- `scenes/bosses/BossBase.tscn` - Base boss scene template

**Tasks:**
1. Create BossTemplate extending EnemyTemplate:
   ```gdscript
   extends EnemyTemplate
   class_name BossTemplate
   @export var phase_health_thresholds: Array[float] = [0.75, 0.5, 0.25]
   @export var telegraph_duration: float = 1.5
   @export var phase_abilities: Dictionary = {} # {phase_index: Array[StringName]}
   ```
2. Create BaseBoss.gd with common patterns:
   - Health-based phase transitions
   - Telegraph system with visual/audio hooks
   - Signal emissions: `phase_changed(phase)`, `telegraph_started(ability)`, `telegraph_ended()`
   - Use deterministic RNG via `RNG.stream("ai")`
3. Update existing AncientLich to extend BaseBoss (optional)

### Phase 3: Dynamic Scaling System (1 hour)
**Files to modify:**
- `autoload/BalanceDB.gd` - Add enemy_scaling schema
- `scripts/systems/enemy_v2/EnemyFactory.gd` - Apply scaling multipliers
- `data/balance/balance_config.tres` - Add scaling data

**Tasks:**
1. Add enemy_scaling to BalanceDB schema:
   ```gdscript
   enemy_scaling: {
     "time_multipliers": {
       "60": {"health": 1.2, "damage": 1.1},
       "120": {"health": 1.5, "damage": 1.3},
       "180": {"health": 2.0, "damage": 1.6}
     }
   }
   ```
2. Update EnemyFactory.spawn_from_weights() to accept scaling context:
   - Combine ModifiersService effects (tier scaling) with BalanceDB time multipliers
   - Apply to base template stats before variation generation
3. SpawnDirector provides scaling context: `{elapsed_time: RunClock.elapsed_seconds, tier_scalar: ModifiersService.get_effect("enemies.health_mult")}`

### Phase 4: Map Pool Integration (1 hour)
**Files to modify:**
- `scripts/systems/SpawnDirector.gd` - Use MapInstance.SpawnProfile
- `scripts/systems/enemy_v2/EnemyFactory.gd` - Add pool filtering helpers

**Tasks:**
1. SpawnDirector uses MapInstance.SpawnProfile.enemy_pools:
   - Filter available templates by current phase
   - Select templates by pool weights
   - Respect max_concurrent limits per pool
2. Add EnemyFactory helpers:
   ```gdscript
   static func get_templates_from_pool(pool: Dictionary, phase: StringName) -> Array[EnemyTemplate]
   static func spawn_from_pool(pool: Dictionary, scaling_context: Dictionary) -> Node
   ```
3. Deterministic selection using `RNG.stream("waves")` with proper seeding

### Phase 5: Zone-Based Spawning & Boss Events (1.5 hours)
**Files to modify:**
- `scripts/systems/SpawnDirector.gd` - Zone weights and boss scheduling
- Arena scenes - Add SpawnPoint nodes with zone tags

**Tasks:**
1. Zone-based spawn positioning:
   - Use SpawnProfile.zone_weights to select spawn areas
   - Support both dynamic zones and static SpawnPoint nodes (group: "spawn_point")
   - Fallback to existing spawn logic if no zones defined
2. Boss event scheduling:
   - Track SpawnProfile.boss_events against RunClock.elapsed_seconds
   - Trigger boss spawns at specified times
   - Use telegraph system from BaseBoss for warnings
3. Static SpawnPoints support:
   - Arena scenes can have pre-placed SpawnPoint nodes
   - SpawnDirector respects use_static_points flag from SpawnProfile

### Phase 6: Testing & Integration (1 hour)
**Files to create:**
- `tests/SpawnSystem_V2_Isolated.tscn/.gd` - Comprehensive spawn system test
- Update existing spawn-related tests

**Tasks:**
1. Create isolated test covering:
   - Phase transitions trigger correct enemy pools
   - Boss events fire at scheduled times
   - Scaling applies correctly (time + tier)
   - Zone weights affect spawn positions
   - Deterministic behavior across runs
2. Update existing tests:
   - Ensure V2 toggle compatibility
   - Validate no performance regression
   - Test fallback behavior when SpawnProfile missing
3. Integration validation:
   - Works with existing debug spawn keys (B, etc.)
   - Compatible with manual spawning
   - Proper cleanup on scene transitions

---

## Data Schema Integration

### Enhanced SpawnProfile (builds on task 19)
```gdscript
class_name SpawnProfile
extends Resource

# From task 19 foundation:
@export var enemy_pools: Array[Dictionary] = [] # [{id, weight, max_concurrent}]
@export var spawn_rate_base: float = 1.0
@export var pack_size_base: float = 1.0
@export var use_static_points: bool = false

# New additions for this task:
@export var phases: Array[Dictionary] = [] # [{time_start: 0, time_end: 60, pools: ["early"]}]
@export var zone_weights: Dictionary = {} # {"north": 0.3, "south": 0.3}
@export var boss_events: Array[Dictionary] = [] # [{at_time: 120, boss_id: "ancient_lich"}]
```

### Example Enhanced SpawnProfile
```tres
[gd_resource type="SpawnProfile"]

[resource]
enemy_pools = [
  {"id": "early_game", "weight": 1.0, "max_concurrent": 20},
  {"id": "mid_game", "weight": 0.8, "max_concurrent": 15},
  {"id": "elite", "weight": 0.3, "max_concurrent": 5}
]
phases = [
  {"time_start": 0, "time_end": 60, "pools": ["early_game"]},
  {"time_start": 60, "time_end": 180, "pools": ["mid_game", "early_game"]},
  {"time_start": 180, "time_end": -1, "pools": ["elite", "mid_game"]}
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
spawn_rate_base = 1.0
pack_size_base = 1.0
use_static_points = false
```

---

## Architecture Integration

### System Communication Flow
```
MapInstance (from task 19) → SpawnDirector.setup(MapInstance)
     ↓
RunClock.phase_changed → SpawnDirector.on_phase_changed()
     ↓
SpawnDirector.select_pool_by_phase() → select_template_by_weights()
     ↓
WaveDirector._spawn_enemy_v2() → EnemyFactory.spawn_from_weights(scaling_context)
     ↓
ModifiersService + BalanceDB scaling → Apply to template → Generate variation
```

### Deterministic Seeding Strategy
- **Phase selection**: `hash(MapInstance.seed, RunClock.elapsed_seconds)`
- **Template selection**: `hash(MapInstance.seed, phase_name, spawn_counter)`
- **Zone selection**: `hash(MapInstance.seed, template_id, spawn_counter)`
- **Boss scheduling**: `hash(MapInstance.seed, "boss_events", event_index)`

### Backward Compatibility
- All features behind existing `BalanceDB.use_enemy_v2_system` toggle
- SpawnDirector only activates when MapInstance has enhanced SpawnProfile
- Legacy spawn behavior preserved when SpawnDirector inactive
- Existing debug spawning (B key, etc.) continues to work

---

## File Touch List

### New Files
**Core Systems:**
- scripts/systems/SpawnDirector.gd
- scripts/domain/BossTemplate.gd
- scripts/systems/BaseBoss.gd
- scenes/bosses/BossBase.tscn

**Tests:**
- tests/SpawnSystem_V2_Isolated.tscn/.gd

### Modified Files
**Enhanced from task 19:**
- scripts/resources/SpawnProfile.gd (add phases, zone_weights, boss_events)

**Scaling Integration:**
- autoload/BalanceDB.gd (add enemy_scaling schema)
- scripts/systems/enemy_v2/EnemyFactory.gd (scaling context + pool helpers)
- data/balance/balance_config.tres (scaling data)

**Arena Integration:**
- scenes/arena/ExampleArena.tscn (add SpawnPoint nodes with zones)

### Documentation
- docs/ARCHITECTURE_QUICK_REFERENCE.md (SpawnDirector + BaseBoss)
- changelogs/features/YYYY_MM_DD-spawn_system_v2_consolidated.md

---

## Small Commit Strategy

1. `feat(spawn): SpawnDirector foundation + enhanced SpawnProfile schema`
2. `feat(boss): BaseBoss framework + BossTemplate + telegraph system`
3. `feat(scaling): BalanceDB time multipliers + EnemyFactory scaling context`
4. `feat(pools): Map pool integration + deterministic template selection`
5. `feat(zones): Zone-based spawning + boss event scheduling`
6. `test(spawn): SpawnSystem_V2_Isolated + integration validation`
7. `docs: update architecture + feature changelog`

---

## Success Metrics

### Functionality
- [ ] Phase transitions correctly change enemy composition
- [ ] Boss events trigger at scheduled times with telegraph warnings
- [ ] Enemy scaling applies both tier (ModifiersService) and time (BalanceDB) multipliers
- [ ] Zone weights affect spawn positioning as expected
- [ ] Static SpawnPoints work when use_static_points enabled

### Performance
- [ ] SpawnDirector 30Hz updates cause no frame drops
- [ ] Resource loading doesn't cause hitches
- [ ] Deterministic seeding maintains consistent behavior

### Integration
- [ ] Compatible with existing V2 toggle system
- [ ] Works with debug spawn keys and manual spawning
- [ ] Proper cleanup on scene transitions (validated by teardown tests)
- [ ] Fallback behavior when enhanced SpawnProfile features missing

---

## Timeline & Effort

**Total Effort:** ~8 hours across 6 phases

- **Phase 1 (SpawnDirector):** 2 hours
- **Phase 2 (Boss Framework):** 1.5 hours
- **Phase 3 (Scaling):** 1 hour
- **Phase 4 (Map Pools):** 1 hour
- **Phase 5 (Zones/Events):** 1.5 hours
- **Phase 6 (Testing):** 1 hour

**Recommended Schedule:**
- Week 1: Phases 1-3 (Director + Boss + Scaling)
- Week 2: Phases 4-6 (Pools + Zones + Testing)

This creates a complete, data-driven enemy spawning system that leverages the Map/Arena Foundation while adding advanced scheduling, scaling, and boss management capabilities.
