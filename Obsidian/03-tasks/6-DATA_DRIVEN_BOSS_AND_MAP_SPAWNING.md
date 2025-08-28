# Data-Driven Boss & Map-Based Enemy Spawning (AnimatedSprite2D Bosses)

Status: Not Started
Owner: Solo (Indie)
Priority: High
Dependencies: Enemy V2 MVP (EnemyTemplate/EnemyFactory/SpawnConfig), WaveDirector, BalanceDB, EventBus, RNG, existing boss scenes (AncientLich.tscn, DragonLord.tscn)
Risk: Medium (touches spawning paths and introduces new resources)
Complexity: 6/10

---

## State Analysis (Current System)

- WaveDirector.gd:
  - Hardcoded boss scene switch: match spawn_config.template_id → scene path
  - Uses EnemyFactory V2 for regular enemies via weighted pool
  - Boss-tier routed to _spawn_boss_scene(spawn_config) (currently switch)

- EnemyTemplate.gd (V2):
  - Data-driven template with deterministic ranges and render_tier
  - No boss scene path field yet

- EnemyFactory.gd:
  - Loads templates (templates/ + variations/)
  - Deterministic SpawnConfig generation
  - No map-based filtering or map pools yet

- SpawnConfig.gd:
  - Bridge to legacy pooling
  - Provides stats/visuals/template_id/render_tier

- Boss scenes exist (scenes/bosses/AncientLich.tscn, DragonLord.tscn), but selection is hardcoded in WaveDirector.

Decision: Use AnimatedSprite2D for all boss visuals to leverage the frame editor when adding new bosses. Remove hardcoded scene mapping via data on EnemyTemplate.

---

## Goals & Acceptance Criteria

- Data-driven boss scene selection:
  - [ ] Boss scene path configured on EnemyTemplate (.tres), no code switches
- AnimatedSprite2D boss workflow:
  - [ ] Boss scenes are standard Godot scenes editable via Animation Panel
- Map-based enemy/boss pools:
  - [ ] Each map defines which enemies/bosses can spawn and when (wave/time/interval)
  - [ ] Map-driven timers can trigger special spawns/events
- Backwards compatibility:
  - [ ] Regular enemies continue via MultiMesh pooling path
  - [ ] Fallback behavior if boss scene path missing
- Determinism preserved:
  - [ ] All random choices use RNG with proper streams (waves/ai)
- Tests/docs:
  - [ ] Isolated tests for map pools and boss spawning
  - [ ] Architecture/CHANGELOG updated

---

## Sequencing and Scope Split

- Do Task 6 first (6-BOSS_ANIMATEDSPRITE_MIGRATION_AND_BASEBOSS.md):
  - BaseBoss runtime, AnimatedSprite2D boss scenes, boss_scene_path on EnemyTemplate, WaveDirector no-switch boss instantiation, Damage v2 compliance, stable IDs.
- Then this task (5-DATA_DRIVEN_BOSS_AND_MAP_SPAWNING.md):
  - MapConfig, EnemyPool/BossPool, SpawnTimer resources, EnemyFactory map helpers, WaveDirector map and timers.
- Tests/docs:
  - Hybrid spawning tests live here; boss runtime tests live in Task 6.

## Implementation Plan (Phases & Checklist)

### Phase A — Boss Scene Path on EnemyTemplate [Handled in Task 6]
- [ ] Add field to EnemyTemplate.gd:
      `@export var boss_scene_path: String = ""`
- [ ] Validate path format in EnemyTemplate.validate() (optional warning if render_tier == "boss" and path empty)
- [ ] Update boss variations:
  - [ ] data/content/enemies_v2/variations/ancient_lich.tres → boss_scene_path = "res://scenes/bosses/AncientLich.tscn"
  - [ ] data/content/enemies_v2/variations/dragon_lord.tres → boss_scene_path = "res://scenes/bosses/DragonLord.tscn"

Output: Boss templates carry their own scene identity (no WaveDirector switches).

### Phase B — WaveDirector Refactor (No Switches) [Handled in Task 6]
- [ ] Replace _spawn_boss_scene(spawn_config) switch with data-driven path:
  - [ ] Resolve template via EnemyFactory.get_template(spawn_config.template_id)
  - [ ] Read template.boss_scene_path
  - [ ] If empty → fallback to procedural boss spawn (_spawn_procedural_boss or log warn)
  - [ ] Else load PackedScene and instantiate
- [ ] Maintain existing registration (boss_hit_feedback), logging, and parenting
- [ ] Keep deterministic position logic and context propagation

Output: Adding a new boss requires only a .tres + scene, no code edits.

### Phase C — MapConfig Resource System (Editor-Driven)
Create new resource types under scripts/domain:

- [ ] MapConfig.gd
  ```
  extends Resource
  class_name MapConfig
  @export var id: String = ""
  @export var display_name: String = ""
  @export var enemy_pools: Array[EnemyPoolConfig] = []
  @export var boss_pools: Array[BossPoolConfig] = []
  @export var spawn_timers: Array[SpawnTimerConfig] = []
  @export var environment_settings: Dictionary = {}
  ```
- [ ] EnemyPoolConfig.gd
  ```
  extends Resource
  class_name EnemyPoolConfig
  @export var wave_range: Vector2i = Vector2i(1, 10)
  @export var enemy_template_ids: Array[String] = []
  @export var spawn_weights: Array[float] = []
  @export var max_concurrent: int = 50
  ```
- [ ] BossPoolConfig.gd
  ```
  extends Resource
  class_name BossPoolConfig
  @export var trigger_conditions: Array[String] = [] # e.g., ["wave_10", "timer_elite", "time_300"]
  @export var boss_template_ids: Array[String] = []
  @export var spawn_weights: Array[float] = []
  @export var cooldown_seconds: float = 60.0
  ```
- [ ] SpawnTimerConfig.gd
  ```
  extends Resource
  class_name SpawnTimerConfig
  @export var id: String = ""
  @export var interval_seconds: float = 30.0
  @export var start_delay: float = 0.0
  @export var repeat_count: int = -1
  @export var trigger_actions: Array[String] = [] # data-coded actions like "spawn_pool:elite_pack", "spawn_boss:ancient_lich"
  ```

Example map data under data/content/maps/:
- [ ] forest_map.tres (two enemy pools, wave ranges, 1 boss pool at wave 10, one repeating timer)
- [ ] dungeon_map.tres (undead-focused pools, boss pool at wave 15 and/or timer-based)

Output: Designer can define enemies/bosses per map in editor without code.

### Phase D — EnemyFactory Map Filtering Helpers
- [ ] Add optional factory helpers (non-breaking):
  - [ ] `spawn_from_map_pool(map_config: MapConfig, wave_index: int, context: Dictionary) -> SpawnConfig` (filters template set and weights based on active pools)
  - [ ] `get_allowed_templates_config, wave_index) -> Array[EnemyTemplate]`
- [ ] Ensure RNG remains deterministic using provided context (run_id, wave_index, spawn_index)

Output: Centralized, testable selection logic consistent with V2.

### Phase E — WaveDirector Map Integration & Timers
- [ ] Inject/set current_map_config on WaveDirector (from ArenaSystem/GameOrchestrator)
- [ ] On spawn: if map_config exists, pick from EnemyFactory.spawn_from_map_pool; else fallback to current weighted pool
- [ ] Timer management:
  - [ ] Initialize timers from MapConfig.spawn_timers at start
  - [ ] On timer tick, resolve trigger_actions and perform spawns (enemies or boss via template_id)
  - [ ] Persist cooldowns for BossPoolConfig triggers to avoid repeats (unless intended)

Output: Map controls enemy composition and special timed spawns.

### Phase F — AnimatedSprite2D Boss Workflow [Handled in Task 6]
- [ ] Confirm boss scenes use AnimatedSprite2D (or AnimatedSprite2D + AnimationPlayer) for frame editor workflow
- [ ] In _spawn_boss_scene, if boss_instance supports `setup_from_spawn_config`, pass SpawnConfig
- [ ] Optional: support simple visual_config application if desired (e.g., tint/scale)

Output: Smooth authoring of boss visuals in the editor.

### Phase G — Tests & Docs
- [ ] tests/test_boss_spawning.gd: update/extend to validate no-switch path (load via EnemyTemplate.boss_scene_path)
- [ ] New isolated tests:
  - [ ] tests/WaveDirector_Isolated.gd: map-config driven spawn filtering (wave-range enforcement)
  - [ ] tests/test_hybrid_spawning.tscn/gd: regular enemies pooled; bosses as scenes
- [ ] Documentation:
  - [ ] docs/ARCHITECTURE_QUICK_REFERENCE.md: add MapConfig and data-driven boss mapping
  - [ ] docs/ARCHITECTURE_RULES.md: editor-driven content rule for map spawns
  - [ ] changelogs/features/YYYY_MM_DD-data_driven_boss_and_map_spawning.md (feature entry)

---

## File Touch List

Code:
- scripts/domain/EnemyTemplate.gd (+ boss_scene_path)
- scripts/systems/WaveDirector.gd (remove switch; template-driven boss scenes)
- scripts/systems/enemy_v2/EnemyFactory.gd (+ map filtering helpers, optional)
- scripts/domain/MapConfig.gd (NEW)
- scripts/domain/EnemyPoolConfig.gd (NEW)
- scripts/domain/BossPoolConfig.gd (NEW)
- scripts/domain/SpawnTimerConfig.gd (NEW)

Data:
- data/content/enemies_v2/variations/ancient_lich.tres (set boss_scene_path)
- data/content/enemies_v2/variations/dragon_lord.tres (set boss_scene_path)
- data/content/maps/forest_map.tres (NEW)
- data/content/maps/dungeon_map.tres (NEW)

Tests:
- tests/test_boss_spawning.gd (extend)
- tests/WaveDirector_Isolated.tscn/gd (extend)
- tests/test_hybrid_spawning.tscn/gd (validate hybrid path)

Docs:
- docs/ARCHITECTURE_QUICK_REFERENCE.md (update)
- docs/ARCHITECTURE_RULES.md (update)
- changelogs/features/YYYY_MM_DD-data_driven_boss_and_map_spawning.md (NEW)

---

## Notes & Guards

- Keep all changes additive and data-driven. No new cross-module coupling. Use EventBus for signals.
- Determinism: keep seed composition stable (run_id, wave_index, spawn_index, template_id).
 Boss fallback: if boss_scene_path missing/invalid, log warn and use procedural/fallback path (no crash).
- Editor authoring: prefer simple, typed resources for map config; avoid hardcoding logic in code.
- Performance: Map filtering happens at selection time, not per-frame. Avoid allocations in hot paths.

---

## Minimal Milestone (Ship in small steps)

- [ ] C1: Implement MapConfig/BossPool/EnemyPool/SpawnTimer resources and one sample map (e.g., forest_map.tres)
- [ ] D1: Add EnemyFactory.spawn_from_map_pool() helper with deterministic selection
- [ ] E1: Integrate WaveDirector with MapConfig (pool selection + one repeating timer)
- [ ] Sanity test: map-drivenawns influence enemy composition; bosses resolve via template.boss_scene_path from Task 6
- [ ] Commit and tag

Proceed with remaining C/D/E expansions (more maps, more pools/timers) after validation.
