# Hideout Phase 0 — Boot Switch & Config Hardening (Typed, Minimal-Risk)

Status: Ready to Start  
Owner: Solo (Indie)  
Priority: High  
Dependencies: EventBus (autoload), GameOrchestrator (autoload), Logger, RunManager, scenes/main, scenes/arena, scenes/core  
Risk: Low (additive, small scoped changes)  
Complexity: 3/10

---

## Context

Implement the highest-priority improvements to enable a typed, configurable boot flow and a minimal Hideout hub, without invasive refactors:
- Standardize config to a typed .tres Resource (no JSON drift).
- Add typed, past-tense EventBus signals for scene transitions/selection.
- Switch boot in Main.gd to select Hideout vs Arena from config (Phase 0).
- Prepare minimal Hideout scene stub, PlayerSpawner seam, and MapDevice contract.
- Add deterministic tests and documentation updates.

This task is the prioritized subset from the Hideout plan review to unblock quick iteration and testing.

---

## Objectives (ordered by priority)

1) Typed DebugConfig Resource (.tres only, no JSON)
- Create DebugConfig.gd Resource with exported, typed fields.
- Use config/debug.tres in code via preload().

2) EventBus typed signals (past-tense)
- enter_map_requested(map_id: StringName)
- character_selected(character_id: StringName)
- (Optional for future phases) mode_changed(mode: StringName)

3) Phase 0 boot switch via Main.gd
- Remove static Arena instance from Main.tscn.
- In Main.gd _ready(): load config, choose Hideout/Arena dynamically.
- Preserve existing EventBus wiring; add structured logs.

4) Minimal Hideout.tscn (precise structure)
- Node2D (root)
  - YSort
    - Marker2D name: "spawn_hideout_main"
  - MapDevice: Area2D (CollisionShape2D + "E: Travel")
  - Camera2D (current=true; reasonable defaults)

5) PlayerSpawner seam (stub)
- scripts/systems/spawn/PlayerSpawner.gd with spawn_at(root, spawn_name) API.
- Export player PackedScene; use deferred spawn to avoid race.

6) Tests (deterministic)
- test_debug_boot_modes.gd: config toggle selects Hideout/Arena; Hideout has spawn_hideout_main.
- Hideout_Isolated: simulate MapDevice interaction → EventBus.enter_map_requested with correct payload.

7) Documentation & changelog
- Update architecture docs with signals + Hideout hub.
- Add feature entry for Phase 0 boot switch.

---

## Acceptance Criteria

- Boot mode is selected via config/debug.tres (Resource) without editor changes.
- When start_mode == "hideout", the game loads Hideout.tscn; when "map", loads Arena.tscn.
- EventBus defines and exports typed, past-tense signals:
  - enter_map_requested(map_id: StringName)
  - character_selected(character_id: StringName)
- Hideout scene contains a Marker2D named "spawn_hideout_main" and an Area2D-based MapDevice.
- PlayerSpawner.gd stub exists with a typed spawn_at(root, spawn_name) method.
- Tests pass:
  - Debug boot modes: Hideout/Arena selection and marker presence assert.
  - Hideout interaction emits enter_map_requested with expected payload.
- Docs updated to reflect new signals, Hideout hub, and config resource usage.

---

## Implementation Plan

Step 1 — DebugConfig Resource (Typed)
- Create scripts/resources/DebugConfig.gd:
```gdscript
extends Resource
class_name DebugConfig
@export var debug_mode: bool = true
@export var start_mode: StringName = &"hideout"  # &"map", &"map_test"
@export var map_scene: String = "res://scenes/arena/Arena.tscn"
@export var character_id: StringName = &"knight_default"
```
- Create/ensure config/debug.tres uses DebugConfig.

Step 2 — EventBus Signals
- autoload/EventBus.gd additions:
```gdscript
signal enter_map_requested(map_id: StringName)
signal character_selected(character_id: StringName)
```

Step 3 — Phase 0 Boot Switch (Main)
- scenes/main/Main.tscn: keep a single Main Node2D with script; remove static Arena.
- scenes/main/Main.gd (pseudo):
```gdscript
@onready var _cfg: DebugConfig = preload("res://config/debug.tres")

func _ready() -> void:
    if _cfg.debug_mode and _cfg.start_mode == &"hideout":
        Logger.info("Boot: Hideout", "Boot")
        _load_scene("res://scenes/core/Hideout.tscn")
    else:
        Logger.info("Boot: Arena", "Boot")
        _load_scene("res://scenes/arena/Arena.tscn")

func _load_scene(path: String) -> void:
    var ps: PackedScene = load(path)
    var inst: Node = ps.instantiate()
    add_child(inst)
```

Step 4 — Hideout.tscn (Minimal)
- Structure:
  -2D (root)
    - YSort
      - Marker2D (name: "spawn_hideout_main")
    - MapDevice: Area2D
      - CollisionShape2D
      - Label ("E: Travel")
    - Camera2D (current=true)

Step 5 — PlayerSpawner (Stub)
- scripts/systems/spawn/PlayerSpawner.gd:
```gdscript
extends Node
class_name PlayerSpawner
@export var player_scene: PackedScene

func spawn_at(root: Node, spawn_name: String) -> Node2D:
    var marker := root.get_node_or_null(spawn_name)
    if marker == null:
        Logger.error("Spawn marker not found: %s" % spawn_name, "PlayerSpawner")
        return null
    var player := player_scene.instantiate()
    call_deferred("_finalize_spawn", root, player, marker)
    return player

func _finalize_spawn(root: Node, player: Node2D, marker: Node) -> void:
    player.global_position = (marker as Node2D).global_position
    root.add_child(player)
```

Step 6 — MapDevice Contract
- scenes/core/MapDevice.gd:
```gdscript
extends Area2D
@export var map_id: StringName = &"forest_01"

func _on_interact() -> void:
    EventBus.enter_map_requested.emit(map_id)
```

Step 7 — Tests
- tests/test_debug_boot_modes.gd:
  - Load config with start_mode="hideout" → assert current scene contains "spawn_hideout_main" marker.
  - Flip to "map" → assert Arena scene root type/name is loaded.
- tests/Hideout_Isolated.tscn/gd:
  - Instantiate MapDevice, simulate _on_interact(), await one frame.
  - Assert signal captured: map_id equals exported value.

Step 8 — Docs/Changelog
- docs/ARCHITECTURE_QUICK_REFERENCE.md: Add Hideout hub, signals, and boot selection.
- docs/ARCHITECTURE_RULES.md: Note typed signals and .tres config guidance.
- changelogs/features/YYYY_MM_DD-hideout_phase0_boot_switch.md entry.

---

## File Touch List

Code
- scripts/resources/DebugConfig.gd (NEW)
- autoload/EventBus.gd (EDIT: +2 signals)
- scenes/main/Main.tscn (EDIT: remove static Arena)
- scenes/main/Main.gd (EDIT: boot switch logic)
- scenes/core/Hideout.tscn (NEW)
- scripts/systems/spawn/PlayerSpawner.gd (NEW)
- scenes/core/MapDevice.gd (NEW)

Data/Config
- config/debug.tres (EDIT or NEW using DebugConfig)

Tests
- tests/test_debug_boot_modes.gd (NEW)
- tests/Hideout_Isolated.tscn (NEW)
- tests/Hideout_Isolated.gd (NEW)

Docs
- docs/ARCHITECTURE_QUICK_REFERENCE.md (EDIT)
- docs/ARCHITECTURE_RULES.md (EDIT)
- changelogs/features/YYYY_MM_DD-hideout_phase0_boot_switch.md (NEW)

---

## Timeline (est.)

- Config Resource + EventBus signals: 20–30 min  
- Main boot switch changes: 20–30 min  
- Hideout.tscn + MapDevice stub: 20–30 min  
- PlayerSpawner stub: 15–20 min  
- Tests + Docs + Changelog: 45–60 min  
Total: ~2.5 hours incremental

---

## Risks & Guards

- Dual config sources causing drift → Mitigation: .tres Resource only; remove JSON mentions.
- Spawn timing race → Mitigation: call_deferred finalize spawn; or await ready.
- Signal contract drift → Mitigation: typed signals; add to Quick Reference; test listens.

---

## Definition of Done

- Boot toggles between Hideout/Arena via config/debug.tres.
- EventBus exposes typed signals; MapDevice emits enter_map_requested.
- Hideout scene exists with "spawn_hideout_main" marker.
- PlayerSpawner stub compiles and is referenced where needed later.
- Tests pass and docs/changelog updated.

---

## Checklist (Execution)

- [ ] Create DebugConfig.gd and config/debug.tres
- [ ] Add EventBus signals
- [ ] Update Main.tscn/Main.gd to dynamic boot
- [ ] Add Hideout.tscn (marker + camera + MapDevice)
- [ ] Add PlayerSpawner.gd stub
- [ ] Add tests (boot modes + Hideout interaction)
- [ ] Update docs and changelog
