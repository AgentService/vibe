# Enemy V2 — MVP and Spawn Plan (Comprehensive Implementation Task)

Status: Planned
Owner: Solo (Indie)
Priority: High
Dependencies: CLAUDE.md, ARCHITECTURE.md, BalanceDB, RNG, EventBus, existing pooling/MultiMesh
Risk: Low (additive behind toggle), reversible

## Context & Goals

You want to add new enemies with minimal code changes while keeping determinism, performance (pools + MultiMesh), and inspector-friendly authoring. This task delivers a minimal, additive MVP for Template-based enemies (Option A) and then a follow-up Spawn Plan to schedule enemies by phases/zones/timing — both fully data-driven.

- MVP Goal: Add a new enemy by creating a single `.tres` file and adjusting a weight — no code changes.
- Spawn Plan Goal: Control when/where enemies spawn using data-only resources (per map/arena), still deterministic.

This work is additive, lives in new files, and is behind a single toggle. The legacy system remains untouched until explicitly removed (see separate decommission task: REMOVE_LEGACY_ENEMY_SYSTEM.md).

---
 
## New Recommendations (Integrated)

1) Add Base Boss System to MVP (accepted)
- BaseBoss.gd: minimal boss controller with phases, telegraph hooks, and UI hooks (health bar, warnings)
- BossTemplate.gd: base stats and visual config for bosses; scene scripts handle rich AI/abilities
- Boss scene inheritance pattern: BossBase.tscn -> ConcreteBoss.tscn with exported BossTemplate

Notes:
- Deterministic: boss phase triggers and telegraphs should use RNG.stream("ai") where randomness is needed
- Signals: BaseBoss emits signals for phase_changed, telegraph_started, telegraph_ended for UI/effects systems

2) Specify Scaling Mechanics in BalanceDB (accepted)
Add to BalanceDB schema (MVP-friendly):
```
enemy_scaling: {
  "time_multipliers": {
    "60": {"health": 1.2, "damage": 1.1},
    "120": {"health": 1.5, "damage": 1.3}
  },
  "tier_multipliers": {
    "elite": {"health": 2.0, "damage": 1.5},
    "boss": {"health": 5.0, "damage": 2.0}
  }
}
```
Usage:
- EnemyFactory applies time-based multipliers using elapsed_time or wave_index context
- SpawnDirector (or wave system) provides tier tags (e.g., "elite", "boss") so Factory can apply tier multipliers

3) Arena-Enemy Connection Strategy (accepted)
Make explicit in ArenaConfig.tres:
- spawn_plan: "res://data/spawn_plans/forest_arena.tres"
- enemy_scaling_profile: "standard"
- boss_sequence: ["forest_guardian", "ancient_treant"]

Notes:
- ArenaSystem loads ArenaConfig and emits a signal with these references
- SpawnDirector reads spawn_plan and enemy_scaling_profile
- Boss spawns follow boss_sequence at milestones (times or events) defined in the plan

## System Flow Diagrams

### A) Current System (Legacy)
```
EnemyType.tres ──> EnemyRegistry ──> WaveDirector ──> Enemy Pool ──> MultiMesh Renderer
                        │                                
                        └──> Boss Scenes (DragonLord.tscn)

Pain Points:
• Hardcoded visual variety (colors/shapes)
• Manual editing in multiple places per enemy  
• Map-specific pacing in code
• Need new .tres file for each variation
```

---

### B) Target MVP (Enemy V2)
```
EnemyTemplate.tres ──> EnemyFactory ──> SpawnConfig ──> Enemy Pool ──> MultiMesh Renderer
      │                     │                              │
   Templates/            RNG.stream("ai")              Same systems
   Variations/           Deterministic                   as legacy
                         variations

Integration: if use_enemy_v2_system: V2_path() else: legacy_path()

Benefits:
• Add enemy = 1 .tres + weight (no code)
• Infinite variations (color/size/speed jitter) 
• Deterministic consistency
• Zero legacy disruption
```

---

### C) Future Vision (Full Data-Driven Spawn Plans)
```text
┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   FULL ENEMY V2 + SPAWN ORCHESTRATION                                        │
├───────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                               │
│  🗺️  MAP CONFIGURATION                🎯 SPAWN ORCHESTRATION               🏭 ENEMY GENERATION                 │
│  ┌─────────────────────────┐          ┌────────────────────────────┐        ┌─────────────────────────┐        │
│  │   ArenaConfig.tres      │          │      SpawnDirector         │        │     EnemyFactory        │        │
│  │ ┌─────────────────────┐ │  loads   │ ┌────────────────────────┐ │ calls  │ ┌─────────────────────┐ │        │
│  │ │spawn_plan: "forest" │ ├─────────▶│ │ 30Hz fixed-step timer  │ ├───────▶│ │ Templates + Scaling │ │        │
│  │ │scaling_profile: std │ │          │ │ Phase management       │ │        │ │ Deterministic RNG   │ │        │
│  │ │boss_sequence: [...]  │ │          │ │ Zone weight selection  │ │        │ │ Variation compute   │ │        │
│  │ └─────────────────────┘ │          │ │ Pool → Template route  │ │        │ └─────────────────────┘ │        │
│  └─────────────────────────┘          │ └────────────────────────┘ │        └─────────────────────────┘        │
│            │                          └────────────────────────────┘                       │                  │
│            ▼                                         │                                      ▼                  │
│  ┌─────────────────────────┐                        │                        ┌─────────────────────────┐        │
│  │ ArenaSpawnPlan.tres     │                        │                        │      SpawnConfig        │        │
│  │ ┌─────────────────────┐ │                        │                        │ ┌─────────────────────┐ │        │
│  │ │ phases: [           │ │                        │                        │ │ Finalized Stats     │ │        │
│  │ │   {0-60s: "early"}  │ │                        │                        │ │ Visual Properties   │ │        │
│  │ │   {60-180s: "mid"}  │ │◀──────── reads ─────────┘                        │ │ Behavior Tags       │ │        │
│  │ │   {180s+: "late"}   │ │                                                 │ └─────────────────────┘ │        │
│  │ │ ]                   │ │                                                 └─────────────────────────┘        │
│  │ │ zone_weights: {     │ │                                                            │                  │
│  │ │   "north": 0.4      │ │                                                            ▼                  │
│  │ │   "south": 0.6      │ │                                     ┌─────────────────────────────────────────┐ │
│  │ │ }                   │ │                                     │         EXISTING SYSTEMS               │ │
│  │ │ boss_events: [      │ │                                     │                                         │ │
│  │ │   {120s: "lich"}    │ │                                     │  Enemy Pool ──┐                        │ │
│  │ │ ]                   │ │                                     │               │                        │ │
│  │ └─────────────────────┘ │                                     │  Combat Logic ┤ ← No Changes Required   │ │
│  └─────────────────────────┘                                     │               │                        │ │
│                                                                  │  Render Tiers ┤                        │ │
│  📦 SPAWN POOLS                                                   │               │                        │ │
│  ┌─────────────────────────┐                                     │  MultiMesh    ──┘                        │ │
│  │   SpawnPool.tres        │                                     │                                         │ │
│  │ ┌─────────────────────┐ │                                     └─────────────────────────────────────────┘ │
│  │ │ "early_forest":     │ │                                                                                 │
│  │ │   goblin: 0.6       │ │                                                                                 │
│  │ │   wolf: 0.4         │ │                                                                                 │
│  │ │                     │ │                 🎲 DETERMINISTIC SELECTION                                      │
│  │ │ "mid_forest":       │ │                 ┌─────────────────────────────────────────────────┐            │
│  │ │   orc: 0.5          │ │                 │ All choices derive from:                        │            │
│  │ │   treant: 0.3       │ │                 │ hash(run_id, phase_idx, event_idx, zone_id)     │            │
│  │ │   archer: 0.2       │ │                 │                                                 │            │
│  │ │                     │ │                 │ Phase → Pool → Template → Zone → Variation      │            │
│  │ │ "boss_encounters":  │ │                 │          ↓           ↓        ↓           ↓      │            │
│  │ │   ancient_lich: 1.0 │ │                 │     Weighted    Template  Weighted   RNG.stream │            │
│  │ │                     │ │                 │     Selection   Loading   Selection    ("ai")   │            │
│  │ └─────────────────────┘ │                 └─────────────────────────────────────────────────┘            │
│  └─────────────────────────┘                                                                                 │
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

🚀 FULL SYSTEM BENEFITS:
• Map designers control enemy flow with pure data
• Time-based progression and zone-specific spawning  
• Boss events scheduled by milestones
• Complete determinism across all systems
• Template inheritance reduces content duplication
• Hot-reload everything during development
• Performance maintained (pools + MultiMesh unchanged)
```

Shared systems:
- BalanceDB.enemy_scaling (time/tier/wave) applied inside EnemyFactory
- RNG.stream("waves"|"ai") feeds all random choices deterministically
- EventBus drives timing (combat_step), SpawnDirector listens for arena load
- Bosses scheduled by boss_events/boss_sequence; scenes remain rich and featureful

Optional layers to add over time:
- TemplateRegistry (snapshot + hot-reload signal)
- VisualPreset (shapes/sprites/atlas-friendly)
- Behavior modules (data refs; logic in systems)
- SpawnPolicy (per-group routing; migration tooling)
- Telemetry (spawn histograms, parity checks)
- Decommission legacy (after parity proven)

## Scope

- Implement a minimal Template system (`EnemyTemplate.tres`) + `EnemyFactory.gd` that computes deterministic variations (hue, scale, speed) and outputs a SpawnConfig that works with current pooling/render tiers.
- Integrate via a single guarded branch in the spawner (toggle: `use_enemy_v2_system`).
- Follow-up: Add SpawnPlan/SpawnPool resources for map-aware timing/tiers/zones (data-only).
- Testing: basic isolated scene + two essential checks (inheritance resolution, determinism).
- Zero removal required now (legacy stays operational).

---

## Architecture Guardrails (per CLAUDE.md / ARCHITECTURE.md)

- Typed GDScript; functions small; systems communicate via EventBus signals; use Logger, not print (except tests).
- Determinism: fixed-step 30 Hz, RNG streams via `RNG.stream("ai"|"waves")`.
- Pools for logic; MultiMesh for rendering; only per-instance color to preserve instancing.
- Content as `.tres` under `vibe/data/*`; system code under `vibe/scripts/*`.

---

## Deliverables and File Layout

New code and data live in their own folders (easy to remove later if desired):

- Code (new)
  - `vibe/scripts/systems/enemy_v2/`
    - `EnemyFactory.gd` — loads templates, resolves inheritance, applies deterministic variation, returns SpawnConfig.
- Data (new)
  - `vibe/data/content/enemies_v2/`
    - `templates/` — base templates: `melee_base.tres`, `ranged_base.tres`, `boss_base.tres` (basic stats/visual hints).
    - `variations/` — quick variations extending bases (e.g., `goblin.tres`, `archer.tres`, `lich.tres`).
- Balance (additive)
  - `vibe/data/balance/` (existing BalanceDB):
    - Add `use_enemy_v2_system: bool` and `v2_template_weights: { id: weight }` (or keep weights in templates — pick one for MVP).
- Tests
  - Isolated visual test scene (optional code overlay): `vibe/tests/EnemySystem_Isolated_v2.tscn`

Note: You can keep “v2” folders separate to enable a trivial directory delete later if needed.

---

## Minimal Data Schemas (MVP)

EnemyTemplate.tres (Resource)
- `id: StringName`
- `parent_path: String` (optional; file path for simple inheritance)
- `health_range: Vector2` (min, max)
- `damage_range: Vector2` (min, max)
- `speed_range: Vector2` (min, max)
- `size_factor: float` (default 1.0)
- `hue_range: Vector2` (0.0–1.0)
- `tags: Array[StringName]`
- `weight: float` (optional if using central weight table in BalanceDB)

Variation (MVP)
- Deterministic color tint (hue), size_factor, speed jitter — applied in EnemyFactory using RNG streams and seed.

SpawnConfig (internal struct/object produced by EnemyFactory)
- Finalized numeric stats (health, speed, damage)
- Visual tint (Color), size/scale
 Template ID and tags
- Any tier/shape attributes necessary for pooling/render tiers

---

## Determinism & Hot-Reload

- Seed for variation (per enemy):
  - `seed = hash(run_id, wave_index, spawn_index, template_id)`
  - Use `RNG.stream("ai")` and/or `RNG.stream("waves")`
- Hot-reload: In dev only, allow reloading templates with `CACHE_MODE_IGNORE` behind a BalanceDB dev flag. For MVP you can reload on F5 or provide a simple reload call in EnemyFactory.

---

## Integration Seam (single guarded branch)

In your existing spawner (e.g., WaveDirector/EnemySystem), add the following small branch. This is the only legacy file you change:

```gdscript
# V2 INTEGRATION START
if BalanceDB.use_enemy_v2_system:
    # Prefer a local preload so later removal is trivial
    const EnemyFactory := preload("res://vibe/scripts/systems/enemy_v2/EnemyFactory.gd")
    # Example; adapt parameters to your existing spawn call data:
    var cfg := EnemyFactory.spawn_from_weights({
        "run_id": RunManager.current_run_id,
        "wave_index": current_wave_index,
 "spawn_index": local_spawn_counter,
        "position": spawn_position,
        "context_tags": current_context_tags  # optional
    })
    # Hand off to existing pooling/rendering, using cfg's finalized stats/visuals
    return spawn_from_config(cfg)
# V2 INTEGRATION END
```

- Legacy stays unchanged and continues to run when toggle is off.
- This makes future decommissioning safe and localized.

---

## Implementation Steps (MVP)

1) Create folders
- `vibe/scripts/systems/enemy_v2/`
- `vibe/data/content/enemies_v2/templates/`
- `vibe/data/content/enemies_v2/variations/`

2) Implement EnemyFactory.gd (MVP)
- Load templates & variations (one-time; store in a dictionary by id).
- Support simple inheritance via `parent_path` (flatten on load).
- Deterministically compute variation (hue/scale/speed) using RNG streams and seed context.
- Produce a SpawnConfig the current pooling system can consume.

3) Author initial templates
- `melee_base.tres`, `ranged_base.tres`, `boss_base.tres` (basic fields).
- 3–6 variations in `variations/` (e.g., `goblin.tres`, `archer.tres`, `lich.tres`).

4) Balance toggle and weights
- Add `use_enemy_v2_system: bool` to BalanceDB.
- Either:
  - Use per-template `weight` fields, OR
  - Add `v2_template_weights: { id: weight }` to BalanceDB (choose one for MVP to keep it simple).

5) Add seam in spawner
- Insert the guarded V2 branch as shown in Integration Seam.

6) Isolated test scene (recommended)
- `vibe/tests/EnemySystem_Isolated_v2.tscn` spawns 20–50 enemies (deterministic).
- HUD overlay prints seed, health, speed, color H for quick sanity checks.

7) Validation
- With toggle ON (test group only), enemies spawn using V2 with expected variety.
- With toggle OFF, legacy path behaves exactly as before.
- Stress test ~500 enemies; ensure MultiMesh batching isn’t broken (tint-only material variation).

---

## Acceptance Criteria (MVP)

- Adding a new enemy requires: create `variations/*.tres` extending a base and set/adjust its weight. No code changes.
- Fixed seeds produce identical stats/colors (determinism).
- Performance is equal or better under a 500-enemy pooled stress test; MultiMesh batching intact.
- Legacy system remains fully functional when toggle is OFF.

---

## Follow-up: Spawn Plan (Data-Driven Scheduling for Maps)

Once MVP is working, implement a small data layer to control when/where enemies spawn.

New Resources
- `SpawnPool.tres`
  - `id: StringName`
  - `include_ids: Array[StringName]` or `include_tags: Array[StringName]`
  - `weights: Dictionary[StringName, float]`
- `ArenaSpawnPlan.tres`
  - `phases: Array[ { time_start: float, time_end: float, pools: Array[StringName] } ]`
  - `zone_weights: Dictionary[StringName, float]` (names of map zones/markers)
  - `boss_events: Array[ { at_time: float, boss_id: StringName, zone: StringName } ]`

System Changes
- A light `SpawnDirector` in systems (or extend your existing wave system) that:
  - Reads `ArenaSpawnPlan` on arena load
  - At fixed steps, picks pool by phase, then picks a template by weights, picks a zone by weights
  - Calls the same seam as MVP; still behind the toggle
- Determinism: derive selections `hash(run_id, phase_index, event_index, zone_id)` via `RNG.stream("waves")`.

Acceptance Criteria (Spawn Plan)
- Map authors schedule enemies using only `.tres` files (phases/zones/pools).
- Deterministic outcomes for timing and composition under fixed seeds.
- Existing bosses remain scene-based; SpawnPlan can schedule bosses at milestones.

---

## Future Enhancements (Additional, Optional — not required for MVP)

- Typed sub-resources (Medium)
  - `EnemyStats.gd`, `VariationRules.gd`, `VisualPreset.gd` for stricter editor validation
  - Optional `TemplateRegistry.gd` with snapshot and `templates_reloaded` signal
- Behavior Composition (Full)
  - `BehaviorModuleRef.gd` data-only behavior references; behavior execution remains in systems
  - Modules: patrol, chase, melee attack, ranged attack, dash, teleport, shield
- Per-Group Routing
  - `SpawnPolicy.gd` supports per-group or per-region toggling (legacy vs v2), useful during migration
- Telemetry
  - Shadow-run histograms for health/speed/hue distribution vs legacy baselines
- Editor & Authoring UX
  - Tool script in EnemyTemplate to validate fields and show a summary/preview in the inspector
- Boss Template (Optional)
  - Add a `BossTemplate` for base boss stats/visuals while keeping boss scenes/scripts for rich AI/effects
- Visual System Growth
  - Support sprites/atlases/animation banks as `sprite_id` in `VisualPreset`; keep instancing-safe materials

---

## Risks & Mitigations

- Data drift vs legacy: start with a few mirrored enemies and compare outcomes in the isolated scene.
- Hot-reload instability: gate `CACHE_MODE_IGNORE` behind a dev flag; load once for release.
- Batching regression: keep per-instance variation to color/scale; avoid per-instance materials.

---

## Task Checklist

- [ ] Add BaseBoss.gd, BossTemplate.gd, and a sample Boss scene (inheritance pattern + hooks)
- [ ] Extend BalanceDB with `enemy_scaling` (time_multipliers, tier_multipliers) and apply in EnemyFactory/SpawnDirector
- [ ] Update ArenaConfig to include `spawn_plan`, `enemy_scaling_profile`, and `boss_sequence`; ensure SpawnDirector reads it
- [ ] Create new folders under `vibe/scripts/systems/enemy_v2/` and `vibe/data/content/enemies_v2/`
- [ ] Implement `EnemyFactory.gd` (MVP) with deterministic variation and simple inheritance
- [ ] Author 3 base templates and 3–6 variations
- [ ] Add toggle `use_enemy_v2_system` and weights (either in templates or BalanceDB)
- [ ] Insert a single guarded branch in spawner to call V2 (`V2 INTEGRATION` block)
- [ ] Build `EnemySystem_Isolated_v2.tscn` and validate determinism/variety
- [ ] Stress test for batching/performance
- [ ] Implement `SpawnPool.tres` and `ArenaSpawnPlan.tres`
- [ ] Add/extend a `SpawnDirector` to read plan and drive spawns via the same seam
- [ ] Verify deterministic scheduling and per-zone spawns in test arena

---

## Notes

- Keep all V2 code/data in the dedicated `enemy_v2` folders to simplify future removal.
- The decommission of legacy is a separate task with a safe, step-by-step guide:
  - See: `Obsidian/03-tasks/REMOVE_LEGACY_ENEMY_SYSTEM.md`
