# Boss AnimatedSprite2D Migration & BaseBoss Unification

Status: Ready to Start
Owner: Solo (Indie)
Priority: High
Dependencies: Enemy V2 (EnemyTemplate/EnemyFactory/SpawnConfig), EventBus, Damage v2 (DamageService/Registry), BalanceDB, RNG, WaveDirector, existing boss scenes
Risk: Medium (touches spawn path and combat integration)
Complexity: 6/10

---

TASK was party completed:

CURRENT ISSUE:
 HP Bar doenst move. Sometimes when hitting one enemy, the damage_taken animation from another far away one triggers instead of the attacked on.

> W 0:06:23:162   Logger.gd:55 @ _log(): [WARN:COMBAT] Damage requested on      │
│   unknown entity: player                                                        │
│     <C++ Source>  core/variant/variant_utility.cpp:1118 @ push_warning()        │
│     <Stack Trace> Logger.gd:55 @ _log()                                         │
│                   Logger.gd:35 @ warn()                                         │
│                   DamageRegistry.gd:52 @ apply_damage()                         │
│                   BaseBoss.gd:151 @ _perform_attack()                           │
│                   BaseBoss.gd:137 @ _update_ai()                                │
│                   BaseBoss.gd:102 @ _on_combat_step()                           │
│                   RunManager.gd:67 @ _process()                                 │
│   W 0:06:19:436   Logger.gd:55 @ _log(): [WARN:COMBAT] Damage requested on      │
│   dead entity: boss:dragon_lord:5                                               │
│     <C++ Source>  core/variant/variant_utility.cpp:1118 @ push_warning()        │
│     <Stack Trace> Logger.gd:55 @ _log()                                         │
│                   Logger.gd:35 @ warn()                                         │
│                   DamageRegistry.gd:57 @ apply_damage()                         │
│                   MeleeSystem.gd:178 @ perform_attack()                         │
│                   Arena.gd:532 @ _handle_auto_attack()                          │
│                   Arena.gd:326 @ _process()                   





## State Analysis

- Bosses currently piggyback on pooled/MultiMesh paths or rely on hardcoded scene switches in WaveDirector.
- Authoring problem: Boss animations are not editor-friendly when using pooled systems; need AnimatedSprite2D workflow to use the frame editor.
- Data gap: Boss scene mapping is hardcoded in code vs configured in templates.
- Architecture gaps identified:
  - Direct damage emission from bosses in some paths; all damage must route via DamageService (unified pipeline).
  - Entity IDs derived from get_instance_id() are unstable; prefer stable IDs from SpawnConfig/spawner.
  - Health bar coupling: Base logic writes ProgressBar directly; prefer boss → signal → component pattern.
- Determinism and testing requirements from .clinerules demand:
  - Event-driven flow via EventBus
  - Typed signals
  - No direct scene tree scans for combat logic
  - Isolation tests for registration/cleanup and signal sequences

Decision: Migrate all boss visuals to AnimatedSprite2D scenes and centralize boss logic in BaseBoss. Make boss scene instantiation data-driven via EnemyTemplate.boss_scene_path. Keep regular enemies on MultiMesh pools for performance.

---

## Goals & Acceptance Criteria

- AnimatedSprite2D authoring:
  - [ ] All bosses are scene-based with AnimatedSprite2D so animations are editable in the Animation panel.
- Data-driven boss scene mapping:
  - [ ] EnemyTemplate.tres carries `boss_scene_path` for boss-tier templates; WaveDirector uses it (no switches).
- Unified damage pipeline:
  - [ ] Boss attacks call `DamageService.request_damage(payload)`; no direct EventBus.damage_taken or take_damage calls.
- Stable entity IDs:
  - [ ] Boss entity IDs originate from SpawnConfig/spawner and remain stable for the lifetime of the boss.
- Decoupled UI:
  - [ ] Boss emits `health_changed(current,max)`; a reusable BossHealthBar scene subscribes and updates UI.
- Determinism:
  - [ ] All random choices (if any) use RNG streams; behavior deterministic under fixed seeds.
- Tests & docs:
  - [ ] Isolated boss tests validate registration, damage flow, animation wake-up path, and signal cleanup.
  - [ ] Architecture docs and changelogs updated per .clinerules.

---

## Implementation Plan (Phased)

### Phase A — BaseBoss Foundations (logic and contracts)
- [ ] Create/align `scripts/systems/BaseBoss.gd`:
  - Class: `class_name BaseBoss extends CharacterBody2D`
 - Typed signals:
    - `signal died(entity_id: String)`
    - `signal health_changed(current: float, max: float)`
  - @onready: `AnimatedSprite2D`, optional `ProgressBar` reference is allowed but UI updates should be signal-driven.
  - Lifecycle:
    - Connect to `EventBus.combat_step` in `_ready()` and disconnect in `_exit_tree()`.
    - Register/unregister self with `DamageService` using stable `entity_id` from `SpawnConfig` or injected config.
  - Setup:
    - `func setup_from_spawn_config(config: SpawnConfig) -> void` to assign stats, scale, position, `entity_id`.
  - AI shell:
    - `_update_ai(dt: float)`, `_update_custom_ai(dt: float, distance: float) -> bool`.
  - Attack path (no direct EventBus.emit):
    - On attack, call:
      ```gdscript
      var payload := {
        "source": entity_id,
        "target": "player",
        "base_damage": attack_damage,
        "tags": ["boss", "melee"]
      }
      DamageService.request_damage(payload)
      ```
  - Health:
    - `set_current_health(new_health)` emits `health_changed(current_health, max_health)`.
    - On death `died(entity_id)` then `queue_free()`.
  - Animation:
    - `_setup_animations()`, `_play_animation(name)`, `_on_animation()` including wake_up → default flow.

Notes:
- Prefer a target provider injection for testing (e.g., assign a function or object to fetch player position); fallback to `PlayerState` if not set.

### Phase B — Reusable BossHealthBar component
- [ ] Create `scenes/components/BossHealthBar.tscn` (ProgressBar with style).
- [ ] Script subscribes to parent boss `health_changed` on `_ready()`:
  ```gdscript
  func _ready():
      var boss := get_parent() as BaseBoss
      if boss:
          boss.health_changed.connect(_on_health_changed)
  ```
- [ ] `_on_health_changed(current, max): value = (current / max) * 100.0`.
- [ ] Position relative to sprite; keep visuals in `.tscn` (styleable in editor).

### Phase C — Template + WaveDirector refactor (data-driven scenes)
- [ ] Update `scripts/domain/EnemyTemplate.gd`:
  - Add `@export var boss_scene_path: String = ""`
  - Optional validate(): warn if `render_tier == "boss"` and `boss_scene_path == ""`.
- [ ] Update boss variations:
  - `data/content/enemies_v2/variations/ancient_lich.tres`: set `boss_scene_path = "res://scenes/bosses/AncientLich.tscn"`.
  - `data/content/enemies_v2/variations/dragon_lord.tres`: set corresponding path.
- [ ] Modify `scripts/systems/WaveDirector.gd`:
  - Replace switch-based `_spawn_boss_scene(spawn_config)` with template-driven:
    ```gdscript
    var tpl := EnemyFactory.get_template(spawn_config.template_id)
    var path: String = tpl.boss_scene_path
    if path == "":
        Logger.warn("Boss template missing boss_scene_path: " + spawn_config.template_id, "bosses")
        return
    var scene := load(path) as PackedScene
    var boss := scene.instantiate()
    add_child(boss)
    boss.setup_from_spawn_config(spawn_config)
    ```
  - Preserve registration hooks/logging/parenting and deterministic spawn position logic.

### Phase D — Boss scene templates and concrete bosses
- [ ] Create `scenes/bosses/BossTemplate.tscn`:
  - Node tree: `CharacterBody2D (script: BaseBoss)`, child `AnimatedSprite2D`, child `BossHealthBar` (from Phase B), child `Area2D HitBox` with `CollisionShape2D`.
- [ ] Create/convert concrete boss scenes inheriting from `BossTemplate.tscn`:
  - `scenes/bosses/AncientLich.tscn` with its own `AnimatedSprite2D` frames and optional override script to implement `_perform_custom_attack()` and custom animations.

### Phase E — Damage v2 compliance and stable IDs
- [ ] Ensure bosses call `DamageService.register_entity(entity_id, data)`/`unregister` correctly and only once.
- [ ] Use `SpawnConfig` to pass `entity_id`:
  - Suggested shape: `spawn_config.entity_id = "boss:" + template_id + ":" + str(counter_or_seed)`
  - Or reuse existing deterministic id from spawner. Avoid `get_instance_id()` for entity id stability.
- [ ] Replace any direct EventBus damage emits in boss code with `DamageService.request_damage(payload)`.

### Phase F — Tests
- [ ] `tests/BossSystem_Isolated.tscn/gd`:
  - Spawn a boss scene; assert:
    - registration on ready and unregistration on exit
    - `health_changed` emits and BossHealthBar updates
    - wake_up → default animation sequence
    - damage pipeline: request → applied → taken signals order
- [ ] `tests/test_hybrid_spawning.tscn/gd`:
  - Validate regular enemies via MultiMesh pool and bosses via scene instantiation coexist.
- [ ] Extend `tests/test_boss_spawning.gd` to cover template-driven `boss_scene_path`.

### Phase G — Docs & Changelog
- [ ] Update `docs/ARCHITECTURE_QUICK_REFERENCE.md` & `docs/ARCHITECTURE_RULES.md`:
  - Boss authoring with AnimatedSprite2D, BaseBoss usage, and data-driven mapping.
- [ ] Add feature entry: `changelogs/features/YYYY_MM_DD-boss-animatedsprite-migration.md`.

---

## File Touch List

Code:
- [ ] scripts/systems/BaseBoss.gd (NEW or aligned to spec)
- [ ] scripts/domain/EnemyTemplate.gd (+ boss_scene_path)
- [ ] scripts/systems/WaveDirector.gd (spawn boss via template path; remove switch)
 [ ] scripts/systems/damage_v2/DamageRegistry.gd (ensure API supports request_damage if not already)

Scenes:
- [ ] scenes/components/BossHealthBar.tn (NEW)
- [ ] scenes/bosses/BossTemplate.tscn (NEW)
- [ ] scenes/bosses/AncientLich.tscn (convert/inherit, confirm AnimatedSprite2D)
- [ ] scenes/bosses/DragonLord.tscn (convert/inherit, confirm AnimatedSprite2D)

Data:
- [ ] data/content/enemies_v2/variations/ancient_lich.tres (set boss_scene_path)
- [ ] data/content/enemies_v2/variations/dragon_lord.tres (set boss_scene_path)

Tests:
- [ ] tests/BossSystem_Isolated.tscn/gd (NEW)
- [ ] tests/test_hybrid_spawning.tscn/gd (NEW)
- [ ] tests/test_boss_spawning.gd (extend)

Docs:
- [ ] docs/ARCHITECTURE_QUICK_REFERENCE.md (update)
- [ ] docs/ARCHITECTURE_RULES.md (update)
- [ ] changelogs/features/YYYY_MM_DD-boss-animatedsprite-migration.md (NEW)

---

## Signal & Payload Contracts

BaseBoss signals:
- `signal health_changed(current: float, max: float)`
- `signal died(entity_id: String)`

Damage request payload (example):
```gdscript
var payload := {
  "source": entity_id,             # String
  "target": "player",              # String id
  "base_damage": attack_damage,    # float
  "tags": ["boss", "melee"]        # Array[StringName] or Array[String]
}
DamageService.request_damage(payload)
```

---

## Determinism & IDs

- Use RNG.stream("ai") for any random boss decisions; seed via run_id + wave_index + boss_index.
- Entity ID stability:
  - Prefer: `spawn_config.entity_id` from spawner (e.g., "boss:ancient_lich:1").
  - Do not use `get_instance_id()` for entity identity in DamageService.

---

## Risks & Mitigations

- Scene mapping misconfigurations:
  - Mitigation: Validate `boss_scene_path` for boss-tier templates; warn on missing path and skip instantiation safely.
- Damage pipeline regressions:
  - Mitigation: Tests asserting `damage_requested → damage_applied → damage_taken` sequence.
- UI coupling:
  - Mitigation: Boss emits signals; BossHealthBar subscribes; avoid direct progress bar writes in BaseBoss except optional fallback.

---

## Timeline Estimate

- Phase A (BaseBoss alignment): 1.5–2 hours
- Phase B (BossHealthBar): 0.5 hour
- Phase C–D (Template + scenes + WaveDirector): 1.5–2 hours
- Phase E–F (Damage v2 compliance + tests): 1–1.5 hours
- Phase G (Docs/Changelog): 0.5 hour

Total: ~4–6 hours

---

## Minimal Milestone (Ship in small steps)

- [ ] A1: Implement/align BaseBoss.gd and signals
- [ ] B1: Create BossHealthBar.tscn and connect to boss
- [ ] C1: Add boss_scene_path to EnemyTemplate + update two boss .tres
- [ ] C2: Refactor WaveDirector to instantiate boss scenes from template
- [ ] Sanity test: manual spawn of AncientLich shows AnimatedSprite2D with health bar

---

## Checklist

- [ ] BaseBoss.gd created/aligned (signals, DamageService, stable IDs)
- [ ] BossHealthBar.tscn implemented (subscribe → update)
- [ ] EnemyTemplate has boss_scene_path (boss-tier only)
- [ ] WaveDirector uses template-driven boss scene instantiation
- [ ] All boss damage uses DamageService.request_damage
- [ ] Deterministic RNG usage for any boss randomness
- [ ] Tests added/updated boss spawning and damage flow
- [ ] Docs and changelogs updated
