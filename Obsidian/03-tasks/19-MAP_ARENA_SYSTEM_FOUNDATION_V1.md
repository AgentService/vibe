# Map/Arena System Foundation v1 (Modular, Data-Driven)

Status: Planning → Small Commit Loops  
Owner: Solo (Indie)  
Priority: High  
Type: Architecture + Systems  
Dependencies: EventBus, GameOrchestrator, PlayerProgression, RNG, tests; Related: 01-5-5_MAP_BASED_ENEMY_SPAWNING, 02-6-DATA_DRIVEN_SPAWN_SYSTEM  
Risk: Medium-Low (additive, behind seams)  
Complexity: 6/10

---

## Background

We need a future-proof, modular Map/Arena foundation: multiple maps, tiers, flexible modifiers, efficient scene transitions, and scalable progression. This v1 introduces data resources, clean loader contracts, and minimal UI hooks without breaking current flows.

---

## Goals & Acceptance Criteria

- [ ] Data model (.tres Resources) for MapDef, MapModifierDef, MapInstance, SpawnProfile, TierCurve
- [ ] EventBus lifecycle signals: map_run_requested/loading/loaded/started/completed/unloaded, tier_unlocked
- [ ] Services: MapRegistry, ModifiersService (aggregate effects), MapProgressionService (gating/unlocks)
- [ ] ArenaLoader: single entry to swap scenes efficiently, inject MapInstance, no leaks (validated by tests)
- [ ] ArenaRuntimeController contract per arena: setup(instance, mods), start(), end(success)
- [ ] ExampleArena scene wired to auto-spawn via SpawnProfile; supports static SpawnPoints + event triggers
- [ ] MapDevice UI stub (hideout) that builds MapInstance and emits map_run_requested
- [ ] Determinism preserved (RNG streams); performance and teardown validated
- [ ] Example data: one map, a few modifiers, a spawn profile, a tier curve
- [ ] Tests: isolated arena system, scene swap/teardown; docs/changelog entries prepared

---

## Key Decisions

- **Scene loading mode**: Exclusive swap (change_scene_to_packed) for v1. Justification: simplest, safest teardown; can add additive mode later if needed.
- **Damage stays unified** via DamageService (no direct take_damage on nodes).
- **All tunables in .tres**; no hardcoding in gameplay code.
- **Signals as cross-module boundaries**; no deep node lookups.

---

## EventBus Contract (typed)

```gdscript
# Map lifecycle signals
signal map_run_requested(MapInstance)
signal map_loading(MapInstance)
signal map_loaded(MapInstance)
signal map_started(MapInstance)
signal map_completed(MapInstance, success: bool)
signal map_unloaded(MapInstance)

# Progression signals
signal tier_unlocked(map_id: StringName, new_max_tier: int)
signal map_modifier_applied(MapInstance, modifier_id: StringName)
```

---

## Data Schemas (minimal)

### MapDef.gd
```gdscript
class_name MapDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var base_tier_min: int = 1
@export var base_tier_max: int = 16
@export var default_spawn_profile: Resource # SpawnProfile
@export var allowed_modifier_tags: Array[StringName] = []
@export var map_tags: Array[StringName] = []
```

### MapModifierDef.gd
```gdscript
class_name MapModifierDef
extends Resource

@export var id: StringName
@export var name: String
@export var weight: float = 1.0
@export var cost_tag: StringName
@export var effects: Array[Dictionary] = [] # [{key: StringName, op: "mul|add|set", value: float}]
@export var tags: Array[StringName] = []
```

### MapInstance.gd
```gdscript
class_name MapInstance
extends Resource

@export var def: MapDef
@export var tier: int = 1
@export var seed: int = 0
@export var applied_modifiers: Array[Resource] = [] # MapModifierDef
@export var snapshot_spawn_profile: Resource # SpawnProfile
```

### SpawnProfile.gd
```gdscript
class_name SpawnProfile
extends Resource

@export var enemy_pools: Array[Dictionary] = [] # [{id, weight, max_concurrent}]
@export var wave_curve: Curve
@export var spawn_rate_base: float = 1.0
@export var pack_size_base: float = 1.0
@export var use_static_points: bool = false
```

### TierCurve.gd
```gdscript
class_name TierCurve
extends Resource

@export var base_multiplier: float = 1.18
@export var curve: Curve # Optional override for complex scaling

func get_scalar(tier: int) -> float:
    if curve:
        return curve.sample(float(tier - 1) / 15.0) # Normalize to 0-1
    else:
        return pow(base_multiplier, tier - 1)
```

---

## Services

### MapRegistry
```gdscript
class_name MapRegistry
extends RefCounted

static var _maps: Dictionary = {} # StringName -> MapDef

static func register_map(def: MapDef) -> void
static func get_map(id: StringName) -> MapDef
static func get_scene(id: StringName) -> PackedScene
static func list_maps() -> Array[MapDef]
static func preload_scene(id: StringName) -> void
```

### ModifiersService
```gdscript
class_name ModifiersService
extends RefCounted

var _table: Dictionary = {}

static func from_instance(instance: MapInstance, tier_scalar: float) -> ModifiersService:
    var svc = ModifiersService.new()
    svc._table["enemies.health_mult"] = tier_scalar
    svc._table["enemies.damage_mult"] = tier_scalar
    svc._table["spawn.rate_mult"] = 1.0
    svc._table["spawn.pack_size_mult"] = 1.0
    
    for modifier in instance.applied_modifiers:
        for effect in modifier.effects:
            match effect.op:
                "mul": svc._table[effect.key] = (svc._table.get(effect.key, 1.0)) * effect.value
                "add": svc._table[effect.key] = (svc._table.get(effect.key, 0.0)) + effect.value
                "set": svc._table[effect.key] = effect.value
    return svc

func get_effect(key: StringName, default_value: float = 1.0) -> float:
    return float(_table.get(key, default_value))
```

### MapProgressionService
```gdscript
class_name MapProgressionService
extends RefCounted

static func can_access(map_id: StringName, tier: int) -> bool:
    # Check PlayerProgression for unlocked tiers
    return PlayerProgression.get_max_tier(map_id) >= tier

static func on_complete(instance: MapInstance, success: bool) -> void:
    if success and instance.tier >= PlayerProgression.get_max_tier(instance.def.id):
        var new_max = instance.tier + 1
        PlayerProgression.set_max_tier(instance.def.id, new_max)
        EventBus.tier_unlocked.emit(instance.def.id, new_max)
```

### ArenaLoader (integrates GameOrchestrator)
```gdscript
class_name ArenaLoader
extends RefCounted

static func run_map(instance: MapInstance) -> void:
    EventBus.map_loading.emit(instance)
    
    var arena_scene: PackedScene = MapRegistry.get_scene(instance.def.id)
    await _fade_out()
    _teardown_current_scene()
    
    get_tree().change_scene_to_packed(arena_scene)
    await get_tree().process_frame
    
    var controller := get_tree().current_scene.get_node("%ArenaRuntimeController")
    var tier_scalar := _compute_tier_scalar(instance.tier)
    var mods := ModifiersService.from_instance(instance, tier_scalar)
    
    controller.setup(instance, mods)
    EventBus.map_loaded.emit(instance)
    controller.start()
    await _fade_in()

static func _compute_tier_scalar(tier: int) -> float:
    # Load from TierCurve resource or default formula
    return pow(1.18, tier - 1)
```

---

## Small Commit Loops (Phases 30–90 min each)

### Phase 0 — Signals + Stubs
- Add EventBus signals.
- Create empty service stubs and resource class shells.
- **Done when**: compiles, no usages yet; tests added for signal presence.

### Phase 1 — Resource Classes
- Implement MapDef/MapModifierDef/MapInstance/SpawnProfile/TierCurve (typed).
- Create minimal example .tres placeholders.
- **Done when**: editor loads resources; validation logs ok.

### Phase 2 — ModifiersService + Tier Scalar
- Implement aggregation (mul/add/set) + scalar pow(1.18, t-1).
- Unit test: effect table composition.

### Phase 3 — MapRegistry + ArenaLoader (skeleton)
- Registry load by id; ArenaLoader path with no fade (MVP); emit loading/loaded.
- Test: swap/teardown using test_scene_swap_teardown baseline.

### Phase 4 — ArenaRuntimeController + ExampleArena
- Add controller script with setup/start/end; hook SpawnProfile to WaveDirector seam.
- Support static SpawnPoints and basic auto-spawn.
- Test: ArenaSystem_Isolated loads and starts.

### Phase 5 — MapDevice UI Stub (Hideout)
- Minimal selector: MapDef + tier + modifiers; emits map_run_requested(MapInstance).
- Integrate gating via MapProgressionService.can_access.

### Phase 6 — Completion + Progression Hook
- Wire map_completed → MapProgressionService.on_complete; sample tier unlock.
- Add sample TierCurve.tres and modifier .tres; smoke test.

### Phase 7 — Docs + Changelog + Guard Tests
- Update ARCHITECTURE_QUICK_REFERENCE/RULES.
- Add feature changelog.
- Tests: ensure determinism (seed/tiers), no leaks on unload.

---

## File Touch List

### New Files
**Resources:**
- scripts/resources/MapDef.gd
- scripts/resources/MapModifierDef.gd
- scripts/resources/MapInstance.gd
- scripts/resources/SpawnProfile.gd
- scripts/resources/TierCurve.gd

**Services:**
- scripts/systems/maps/MapRegistry.gd
- scripts/systems/maps/ModifiersService.gd
- scripts/systems/maps/MapProgressionService.gd
- scripts/systems/maps/ArenaLoader.gd

**Scenes:**
- scenes/arena/ExampleArena.tscn
- scripts/systems/maps/ArenaRuntimeController.gd
- scenes/ui/MapDevice.tscn
- scripts/systems/maps/MapDevice.gd

**Data:**
- data/maps/example_arena.tres
- data/maps/modifiers/damage_boost.tres
- data/maps/modifiers/spawn_rate_increase.tres
- data/maps/spawn_profiles/example_profile.tres
- data/maps/tier_curve.tres

### Tests
- tests/ArenaSystem_Isolated.tscn/.gd (new)
- tests/test_scene_swap_teardown.gd (reuse/verify)

### Docs
- docs/ARCHITECTURE_QUICK_REFERENCE.md
- docs/ARCHITECTURE_RULES.md
- changelogs/features/YYYY_MM_DD-map_arena_foundation_v1.md

---

## Commit Loop Examples

1. `chore(eventbus): add map lifecycle signals (no usages)`
2. `feat(resources): MapDef/Instance/Modifier/SpawnProfile/TierCurve + sample .tres`
3. `feat(maps): ModifiersService tier+effects aggregation + unit test`
4. `feat(loader): ArenaLoader skeleton + MapRegistry; swap/teardown test`
5. `feat(arena): ExampleArena + ArenaRuntimeController; auto-spawn seam`
6. `feat(ui): MapDevice stub emits map_run_requested`
7. `feat(progress): MapProgressionService unlock v1; hook map_completed`
8. `docs: update architecture; add feature changelog`

---

## Arena Scene Contract

Each arena root must have an ArenaRuntimeController.gd script:

```gdscript
extends Node
class_name ArenaRuntimeController

var instance: MapInstance
var mods: ModifiersService

func setup(p_instance: MapInstance, p_mods: ModifiersService) -> void:
    instance = p_instance
    mods = p_mods
    
    # Wire WaveDirector/SpawnPoints
    # Apply spawn_profile to spawning systems
    # Pass mods to enemy factory for scaling
    
func start() -> void:
    EventBus.map_started.emit(instance)
    # Begin spawning/gameplay
    
func end(success: bool) -> void:
    EventBus.map_completed.emit(instance, success)
    # Cleanup and transition
```

---

## MVP Behavior Covered

- **Multiple maps** via MapDef/MapRegistry; tier gating via MapProgressionService.
- **Efficient scene swaps** via ArenaLoader with proper teardown.
- **Modifiers applied at entry** using ModifiersService; extendable keys for future systems.
- **Auto-spawn** via SpawnProfile/WaveDirector; static SpawnPoints and EventTriggers supported.
- **Progression hooks** via EventBus; unlock/loot/drop can be layered later without breaking contracts.

---

## Definition of Done

- [ ] All acceptance criteria satisfied
- [ ] Tests pass (isolated + teardown)
- [ ] Docs/changelog updated
- [ ] Old flows unaffected until MapDevice triggers map_run_requested
- [ ] Example data demonstrates tier scaling and modifier effects
- [ ] Performance validated (no regression from current arena loading)
- [ ] Deterministic behavior with fixed seeds

---

## Future Extensions (Not Required for v1)

### Advanced Map Features
- **Dynamic events**: Time-based or condition-triggered map events
- **Environmental hazards**: Map-specific dangers and mechanics
- **Multi-stage maps**: Maps with multiple phases or areas
- **Weather/time systems**: Environmental effects on gameplay

### Modifier System Expansion
- **Conditional modifiers**: Effects that activate under specific conditions
- **Stacking rules**: How multiple instances of same modifier interact
- **Temporary modifiers**: Time-limited effects during runs
- **Player-applied modifiers**: Consumables that modify current map

### Progression Features
- **Map mastery**: Completion bonuses for repeated clears
- **Leaderboards**: Best times/scores per map/tier
- **Daily/weekly maps**: Rotating special maps with unique rewards
- **Map crafting**: Player-created map variations

---

## Risk Assessment & Mitigations

### Medium-Low Risk - System Integration
- **Risk**: New systems may not integrate cleanly with existing flows
- **Mitigation**: All features additive and behind seams; extensive testing
- **Fallback**: Can disable new systems and revert to current arena loading

### Low Risk - Performance Impact
- **Risk**: Additional resource loading and scene management overhead
- **Mitigation**: Profile before/after; optimize resource caching
- **Validation**: Performance tests ensure no regression

### Low Risk - Data Complexity
- **Risk**: Too many configuration options may overwhelm content creation
- **Mitigation**: Start with simple examples; add complexity gradually
- **Validation**: Test actual content creation workflow with designers

---

## Timeline & Effort

**Total Effort:** ~12-16 hours across 8 phases

- **Phase 0 (Signals/Stubs):** 1 hour
- **Phase 1 (Resources):** 2 hours
- **Phase 2 (ModifiersService):** 1.5 hours
- **Phase 3 (Registry/Loader):** 2 hours
- **Phase 4 (Arena Controller):** 2.5 hours
- **Phase 5 (MapDevice UI):** 2 hours
- **Phase 6 (Progression):** 1.5 hours
- **Phase 7 (Docs/Tests):** 2 hours

**Recommended Schedule:**
- Week 1: Phases 0-3 (Foundation + services)
- Week 2: Phases 4-7 (Arena integration + UI + polish)

This creates a complete foundation for a scalable map/arena system that enables designers to create varied content entirely through .tres resource files while maintaining clean architecture boundaries and deterministic behavior.
