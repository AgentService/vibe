# ABILITY-1 — Modular Ability System (Baukastensystem) + Support Slots & Progression

Status: 📋 Planning → Ready to Start
Priority: High
Type: System Architecture + Progression Design
Created: 2025-09-11
Context: Merge of “Baukastensystem für Skills” concept with 03-ABILITY_SYSTEM_MODULE.md; extract abilities out of Arena and build a data-driven, composable system with support slots and progression gates

## Overview

Build a flexible, data-driven ability system where abilities are composed from modular “lego-like” support modules. A central AbilityService composes a Main Skill (AbilityDefinition) with zero-or-more Support Modules (e.g., Projectile, Damage, AoE, Channel, Buff, Multishot) at runtime. Progression unlocks additional support slots and support tiers over time to prevent early overwhelm and to shape build identity.

- Example: Fireball = ProjectileModule + DamageModule + AoEModule
- Goal: New skills via data composition, not new code
- Alignment: Extracts ability logic from `Arena.gd` into a dedicated module per architecture rules

## Core Pillars

### 1) Baukastensystem (Composable Abilities)
- Main Skill: `AbilityDefinition` (.tres Resource)
- Support Modules: `AbilityModule` (.tres) of types: `projectile`, `damage`, `aoe`, `channel`, `buff`, `multishot`, `pierce`, `chain`, `dot`…
- AbilityService: Composes and executes ability pipelines based on definition + attached modules
- Data-only authoring: Designers build abilities by picking modules and parameters

### 2) Support Slots & Tiers
- Early game: Only main-skill (no supports)
- Mid/late: Slots unlock via Level, Passives, Items
- Slot tiers (T1/T2/T3) gate powerful supports
- Player mixes supports (more AoE, more damage, multishot, etc.) to craft builds

### 3) Progression Options
- Level-based: unlock more slots and supports as character levels
- Tier-based (maps): powerful supports only drop on higher tiers
- Currency-based: respec/upgrade costs resources to add weight to decisions
- Passives: passive tree unlocks special supports or modifier types
- Skill-specific mastery: slot unlocks tied to usage of the main skill

### 4) Player Guidance & Identity
- Fewer decisions at the start; gradually unlock depth
- Progression fosters build identity and commitment
- Respec possible but costs resources; choices matter

### 5) Kernvision (Kurzfassung)
- Prolog (1–10): wenige Skills, keine Supports
- Midgame/Endgame (T1–T16): Supports + Slot-Progression
- Beyond T16: seltene High-End-Supports & Infinite Scaling

🧙🏾‍♂️ Kurzfassung (DE): Flexibles Baukastensystem mit Progression, die Komplexität schrittweise freischaltet: wenige Skills im Prolog, Supports im Midgame, High-End-Buildcraft im Endgame.

---

## Architecture Alignment (from 03-ABILITY_SYSTEM_MODULE.md)

### Separation of Concerns
- Extract ability logic from `Arena.gd` → `AbilityService` autoload + `AbilitySystem` scripts/resources
- Arena routes input/context only; no embedded ability logic
- Keep systems decoupled via EventBus; typed signals; no deep node lookups

### Data Definition Strategy
- Preferred: `.tres` Resources (type-safe, inspector-friendly)
- Optional Hybrid: simple prototype JSON; production in Resources
- Editor workflow: in-game editor (later), templates for common patterns, hot-reload friendly

### Integration Points
- Player input → AbilityService.cast(...)
- Damage: route through unified Damage v2 (`scripts/systems/damage_v2/DamageRegistry.gd`) only
- Visual/Audio: VFX/SFX hooks via modules or events
- UI/HUD: cooldowns, slots, tooltips
- Cards/Passives: add slots/supports or modify tags/multipliers

---

## Data Schemas (typed Resources)

### AbilityDefinition.gd
```gdscript
extends Resource
class_name AbilityDefinition

@export var id: StringName
@export var display_name: String
@export var description: String = ""
@export var base_cooldown: float = 0.5
@export var base_cost: float = 0.0
@export var tags: Array[StringName] = []          # e.g., &"fire", &"projectile"

@export var module_ids: Array[StringName] = []    # ordered pipeline of module IDs
@export var slot_schema: Array[Dictionary] = []   # [{slot: 0, tier: 1}, {slot:1, tier:1}, ...]
```

### AbilityModuleDef.gd
```gdscript
extends Resource
class_name AbilityModuleDef

@export var id: StringName
@export var kind: StringName                 # &"projectile" | &"damage" | &"aoe" | ...
@export var tier_req: int = 1                # min slot tier
@export var params: Dictionary = {}          # kind-specific tunables
@export var tags: Array[StringName] = []     # e.g., &"ignite", &"crit_eligible"
```

### AbilityProgressionDef.gd (optional resource)
```gdscript
extends Resource
class_name AbilityProgressionDef

@export var unlock_curve Dictionary = {     # gates for slots/supports
    "level": [5, 10, 15],                    # slot unlocks at levels
    "passives": [],                          # passive ids that unlock
    "items": []                              # item ids that unlock
}
@export var tier_gates: Dictionary = {       # T1/T2/T3 availability per support tag
    "support_common": 1,
    "support_rare": 2,
    "support_mythic": 3
}
```

### Example: Fireball.tres (concept)
```text
AbilityDefinition:
  id = &"fireball"
  display_name = "Fireball"
  base_cooldown = 0.6
  module_ids = [&"mod_projectile_basic", &"mod_damage_fire", &"mod_aoe_small"]
  slot_schema = [{slot:0, tier:1}, {slot:1, tier:1}]  # supports attach positions
```

---

## Runtime Service API

### autoload/AbilityService.gd
```gdscript
extends Node
class_name AbilityService

signal ability_cast(id: StringName, ctx: Dictionary)
signal ability_failed(id: StringName, reason: StringName, ctx: Dictionary)
signal support_attached(ability_id: StringName, slot: int, module_id: StringName)
signal support_slot_unlocked(ability_id: StringName, slot: int, tier: int)

# Registry (preloaded from data/content/abilities and data/content/ability_modules)
var _abilities: Dictionary = {}      # id -> AbilityDefinition
var _modules: Dictionary = {}        # id -> AbilityModuleDef

func cast(id: StringName, ctx: Dictionary) -> void:
    # Validate cooldown, costs, slots/modules, then execute pipeline:
    # for module_id in ability.module_ids + attached_supports: _apply_module(module_id, ctx)
    # Emit signals; route damage via DamageRegistry; use RNG.stream(&"abilities") if needed
    pass

func attach_support(ability_id: StringName, slot: int, module_id: StringName) -> bool:
    # Validate slot unlocked & tier gate, module tier_req, allowed tags
    pass

func get_cooldown_left(id: StringName) -> float: return 0.0
func is_castable(id: StringName) -> bool: return true
```

- Determinism: use `RNG.stream(&"abilities")` for spread/multishot.
- Damage path: always via `DamageRegistry.gd` (never call `take_damage()` directly).

---

## Slot & Tier Gating Model

- Slot unlock sources:
  - Level thresholds (per Ability or global)
  - Passive allocations
  - Items/affixes
  - Skill usage milestones (skill-specific mastery)
- Tier gating:
  - Slot has tier (T1..T3)
  - Module requires `tier_req`
  - Higher-tier supports only fit in higher-tier slots
- Drop/availability:
  - Support module availability tied to Map Tier (T1–T16)
  - BalanceDB drives drops/trade/vendors

---

## Editor Workflow (V1 → V2)

- V1:
  - Author `.tres` for `AbilityDefinition` and `AbilityModuleDef`
  - Load registry on boot; hot-reload via BalanceDB if needed
- V2 ():
  - In-game visual composer for modules/pipelines
  - Templates for archetypes (projectile/aoe/beam/homing)
  - Preview/sandbox scene for ability testing
  - Inspector helpers and validation

---

## Signals (EventBus integration)

Add typed signals to `autoload/EventBus.gd`:
```gdscript
signal ability_cast(id: StringName, ctx: Dictionary)
signal support_slot_unlocked(ability_id: StringName, slot: int, tier: int)
signal support_attached(ability_id: StringName, slot: int, module_id: StringName)
signal ability_cooldown_started(id: StringName, duration: float)
signal ability_cooldown_ready(id: StringName)
```

Consumers: UI (cooldowns/slots), Analytics, VFX/SFX, Tutorials.

---

## Example: Fireball Composition

- Base: `fireball` with:
  - `mod_projectile_basic` {speed: 900, lifetime: 1.2, sprite: "fireball"}
  - `mod_damage_fire` {base_damage: 20, tags: [&"fire", &"spell"]}
  - `mod_aoe_small` {radius: 32, falloff: 0.2}
- Supports:
  - `mod_multishot_2` (Tier 1)
  - `mod_increased_aoe_30` (Tier 1)
  - `mod_pierce_1` (Tier 2)

Execution outline:
```
cast → projectile spawn(s) → travel
on hit → DamageRegistry.request({source, target, base_damage, tags})
on explode → AoE iterate targets → DamageRegistry.request(...) per target
```

---

## Acceptance Criteria

- Abilities defined as `.tres` resources; no hardcoded stats in code
- AbilityService composes modules at runtime; pipelines deterministic
- Damage routed exclusively via DamageRegistry v2
- Support slots exist with tier gating and unlock sources
- UI displays cooldowns and available slots/supports
- Tests validate cast → module pipeline → damage signals
- Docs updated per architecture rules

---

## Milestones & Phases

### Phase 1 — Skeleton + Single Ranged Ability (Fireball)
- AbilityService autoload with minimal pipeline execution
- Resources: AbilityDefinition, AbilityModuleDef
- Implement Fireball (Projectile + Damage + AoE)
- Arena routes input → `AbilityService.cast(&"fireball", ctx)`
- Tests: `tests/AbilitySystem_Isolated.*` cover cast → projectile → damage signals

### Phase 2 — Support Slots & Basic Progression
- Implement slot schema on AbilityDefinition
- Attach/detach supports with tier validation
- Simple unlocks: level thresholds from BalanceDB or debug toggles
- UI: minimal slot display and support attachment feedback
- Tests: slot unlock flow, tier gating, deterministic multishot

### Phase 3 — Map Tier Gating & Drops
- Tie support module availability to Map Tier (T1–T16)
- Integrate with Map/Arena services (if present)
- Tests: availability changes across tiers

### Phase 4 — Editor Tooling (Optional)
- Inspector helpers, validation, hot-reload
- Sandbox/preview scene for ability tests

---

## File Touch List (Initial)

New:
- `autoload/AbilityService.gd`
- `scripts/resources/AbilityDefinition.gd`
- `scripts/resources/AbilityModuleDef.gd`
- `data/content/abilities/fireball.tres`
- `data/content/ability_modules/mod_projectile_basic.tres`
- `data/content/ability_modules/mod_damage_fire.tres`
- `data/content/ability_modules/mod_aoe_small.tres`

Modified:
- `autoload/EventBus.gd` (add signals)
- `scenes/arena/Arena.gd` (route input to AbilityService)
- `tests/AbilitySystem_Isolated.tscn/.gd` (update/expand)

Docs:
- `docs/ARCHITECTURE_QUICK_REFERENCE.md` (ability pipeline + slots)
- `docs/ARCHITECTURE_RULES.md` (all damage via DamageRegistry; data-only abilities)

---

## Testing Strategy

Isolated (scene-based, fast, deterministic):
- Cast fires projectile(s) toward cursor using RNG stream &"abilities"
- Module order respected (projectile → damage → aoe)
- Cooldown start/ready signals emitted
- Slot unlock/tier gates enforced; invalid attachment rejected
- DamageRegistry receives correct payloads with tags intact

Contract/Signals:
- EventBus typed signals match shape; no cross-module calls

Determinism:
- Given fixed seed, cast results repeat exactly (projectile count/spread)

Performance:
- No per-frame allocations in hot paths; reuse arrays/dicts; module execution pooled

---

## Open Questions / Research

- Module ordering constraints? (pre/post-hit hooks, on-travel behaviors)
- Shared cooldown groups and alternates?
- Skill-specific mastery pacing vs global unlocks
- UI affordances for support tiers and recommendations
- Visual composer: node-graph vs list-based pipeline

---

## Short German Summary (Merge of source content)

- Baukastensystem: Main-Skill (.res) + Support-Module (.tres) → AbilityService baut dynamisch zusammen (z. B. Fireball = Projectile + Damage + AoE).
- Support-Slots wachsen über Progression (Level, Passives, Items) mit Tiers (T1/T2/T3).
- Progression: Level-/Tier-/Währungs-basiert; Passives und Skill-Mastery schalten frei.
- Spielerführung: Start simpel, später Tiefe; Umskillen kostet Ressourcen.
- Vision: Prolog wenige Skills; Midgame Supports; Endgame High-End-Buildcraft.
