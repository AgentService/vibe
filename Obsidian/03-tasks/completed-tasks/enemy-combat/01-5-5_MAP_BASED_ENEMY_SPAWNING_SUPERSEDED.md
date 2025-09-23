# Map-Based Enemy Spawning System

Status: **SUPERSEDED** by 21-SPAWN_SYSTEM_V2_CONSOLIDATED.md
Owner: Solo (Indie)
Priority: ~~High~~ **SUPERSEDED**
Dependencies: Data-Driven Boss Spawning (completed), EnemyFactory V2, WaveDirector, EventBus, RNG
Risk: Medium (new resource system and spawning logic)
Complexity: 7/10

---

## ⚠️ SUPERSEDED NOTICE

This task has been **merged and superseded** by:
- **21-SPAWN_SYSTEM_V2_CONSOLIDATED.md** - Consolidated spawn system that combines this task with 02-6-DATA_DRIVEN_SPAWN_SYSTEM
- **19-MAP_ARENA_SYSTEM_FOUNDATION_V1.md** - Provides the foundational MapDef/MapInstance/SpawnProfile resources

**Reason for supersession:** To avoid duplication and create a unified spawn system that builds on the new Map/Arena Foundation.

**Key elements preserved in consolidated task:**
- Map-based enemy pools and spawn filtering
- WaveDirector integration with map configs
- Deterministic RNG usage
- Designer-friendly .tres workflow

---

---

## Background

Boss spawning is now data-driven via EnemyTemplate.boss_scene_path. This task completes the system by adding map-based enemy pools, spawn timers, and designer-configurable enemy composition per map without code changes.

---

## Goals & Acceptance Criteria

- Map-based enemy/boss pools:
  - [ ] Each map defines which enemies/bosses can spawn and when (wave/time/interval)
  - [ ] Map-driven timers can trigger special spawns/events
- Designer workflow:
  - [ ] Map configuration via .tres resources in editor
  - [ ] No code changes needed to add new maps or adjust spawning
- System integration:
  - [ ] EnemyFactory helpers for map-based filtering
  - [ ] WaveDirector integration with map configs
- Determinism preserved:
  - [ ] All random choices use RNG with proper streams
- Tests/docs:
  - [ ] Isolated tests for map pools and spawn filtering
  - [ ] Architecture/CHANGELOG updated

---

## Implementation Plan

### Phase A — MapConfig Resource System
- [ ] Create MapConfig.gd resource class:
  ```gdscript
  extends Resource
  class_name MapConfig
  @export var id: String = ""
  @export var display_name: String = ""
  @export var enemy_pools: Array[EnemyPoolConfig] = []
  @export var boss_pools: Array[BossPoolConfig] = []
  @export var spawn_timers: Array[SpawnTimerConfig] = []
  @export var environment_settings: Dictionary = {}
  ```

- [ ] Create EnemyPoolConfig.gd:
  ```gdscript
  extends Resource
  class_name EnemyPoolConfig
  @export var wave_range: Vector2i = Vector2i(1, 10)
  @export var enemy_template_ids: Array[String] = []
  @export var spawn_weights: Array[float] = []
  @export var max_concurrent: int = 50
  ```

- [ ] Create BossPoolConfig.gd:
  ```gdscript
  extends Resource
  class_name BossPoolConfig
  @export var trigger_conditions: Array[String] = []  # ["wave_10", "timer_elite", "time_300"]
  @export var boss_template_ids: Array[String] = []
  @export var spawn_weights: Array[float] = []
  @export var cooldown_seconds: float = 60.0
  ```

- [ ] Create SpawnTimerConfig.gd:
  ```gdscript
  extends Resource
  class_name SpawnTimerConfig
  @export var id: String = ""
  @export var interval_seconds: float = 30.0
  @export var start_delay: float = 0.0
  @export var repeat_count: int = -1
  @export var trigger_actions: Array[String] = []  # ["spawn_pool:elite_pack", "spawn_boss:ancient_lich"]
  ```

### Phase B — Example Map Data
- [ ] Create data/content/maps/ directory
- [ ] Create forest_map.tres (basic enemy pools, boss at wave 10)
- [ ] Create dungeon_map.tres (undead-focused, boss at wave 15 + timer)

### Phase C — EnemyFactory Map Filtering
- [ ] Add spawn_from_map_pool(map_config, wave_index, context) helper
- [ ] Add get_allowed_templates(map_config, wave_index) helper
- [ ] Ensure deterministic RNG using existing streams

### Phase D — WaveDirector Map Integration
- [ ] Add current_map_config property to WaveDirector
- [ ] Update spawn logic to use map pools when available
- [ ] Implement timer management for special spawns
- [ ] Track boss cooldowns per BossPoolConfig

### Phase E — Tests & Documentation
- [ ] Create tests/test_map_based_spawning.gd
- [ ] Update existing boss spawning tests
- [ ] Update docs/ARCHITECTURE_QUICK_REFERENCE.md
- [ ] Add feature changelog entry

---

## File Touch List

New Files:
- scripts/domain/MapConfig.gd
- scripts/domain/EnemyPoolConfig.gd
- scripts/domain/BossPoolConfig.gd
- scripts/domain/SpawnTimerConfig.gd
- data/content/maps/forest_map.tres
- data/content/maps/dungeon_map.tres
- tests/test_map_based_spawning.gd

Modified Files:
- scripts/systems/enemy_v2/EnemyFactory.gd (+ map filtering helpers)
- scripts/systems/WaveDirector.gd (+ map integration and timers)

Documentation:
- docs/ARCHITECTURE_QUICK_REFERENCE.md
- changelogs/features/YYYY_MM_DD-map_based_enemy_spawning.md

---

## Notes

- Keep all changes additive and data-driven
- Use EventBus for cross-system communication
- Maintain deterministic RNG with proper stream usage
- Map filtering happens at selection time, not per-frame
- Fallback to current system if no map config provided
