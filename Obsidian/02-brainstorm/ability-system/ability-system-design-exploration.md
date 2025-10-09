# Ability System Design Exploration - 2025-10-03

## 🎯 Vision Summary

This document captures the design vision for a modular, data-driven ability system that enables flexible character builds through combinable abilities and power-ups. The system aims to provide fun, emergent gameplay through the interaction of abilities with broad-spectrum modifiers.

---

## 📋 Core Design Principles

### 1. Character Definition
- **Each character has ONE base ability** that defines their identity
- Characters start with **4 ability slots total**: 1 filled (base ability), 3 empty
- Base ability is permanent and character-defining (e.g., Ranger shoots arrows, Mage casts spells)

### 2. Ability Acquisition Flow
```
Player enters game
    ├─→ Starts with base ability only
    ├─→ Kills monsters / loots items / levels up
    ├─→ Upgrade popup appears
    └─→ Player chooses from:
        ├─→ New ability (fills empty slot)
        ├─→ Power-up (broad modifier)
        ├─→ Ability level-up (existing ability)
        └─→ Stat increase
```

### 3. Ability vs Power-Up Distinction

**Abilities:**
- Active skills that fill ability slots (max 4)
- Example: "Throw bananas at enemies"
- Once selected, ability is SET in that slot
- Can be leveled up through repeated selection

**Power-Ups (Modifiers):**
- Broad-spectrum effects that modify multiple abilities
- Do NOT consume ability slots
- Use tag system to determine applicability
- Examples:
  - `+X% projectile count` → affects all projectile abilities
  - `Projectiles apply burning` → affects all projectiles
  - `Projectiles bounce between enemies` → affects all projectiles
  - `+X% attack speed` → affects all abilities with attack speed
  - `+X% area of effect` → affects all abilities with AoE tag
  - `+X% duration` → affects all abilities with duration tag
  - `+X% knockback` → affects abilities that can knock back

**Design Philosophy:**
- **Prefer broad modifiers** that affect MANY abilities (creates synergies)
- **Minimize specific modifiers** that only affect certain abilities (limits build variety)
- Result: Large possibility space for combining abilities + power-ups

---

## 🏗️ System Architecture Goals

### Data-Driven Design
**Core Principle:** "LEGO Sandbox Approach"

```
New Ability Implementation = Data File + Minimal Code
    ├─→ Define ability parameters in .tres resource
    ├─→ Hook up animation/visuals
    ├─→ System handles the rest automatically
    └─→ Ability becomes selectable in upgrade pool
```

**Goal:** After implementing the first few abilities in each category, new abilities should require:
1. Creating a data file (`.tres`)
2. Configuring parameters
3. Linking animations/visuals
4. **That's it!** No deep system changes needed.

### Tag System
**Purpose:** Define which power-ups can affect which abilities

**Example Tags:**
- `projectile` - Can be affected by projectile modifiers
- `aoe` - Can be affected by area of effect modifiers
- `duration` - Can be affected by duration modifiers
- `melee` - Melee range abilities
- `buff` - Self-buff abilities
- `debuff` - Enemy debuff abilities
- `fire`, `ice`, `poison` - Damage type tags

**Tag Application:**
```gdscript
# Power-up checks ability tags
if ability.has_tag("projectile") and ability.has_tag("fire"):
    apply_burning_modifier(ability)

if ability.has_tag("duration"):
    ability.duration *= duration_multiplier
```

### Visual Integration
**Power-ups must have visual implications:**

| Power-Up | Visual Effect |
|----------|---------------|
| +5 projectile count | Show 5 arrows/projectiles |
| Increased duration | Effects last visually longer |
| Increased AoE | Larger circle/area visuals |
| Burning damage | Fire particles on projectiles |
| Projectile bounce | Visual bounce arc between enemies |

**Implementation Note:** Animation system needs to be flexible enough to dynamically adjust to modifier counts.

---

## 🎮 Ability Categories

### Category Design Philosophy
Each category should have:
1. **Shared base class** with common behavior
2. **Category-specific systems** (e.g., projectile pooling, buff timers)
3. **Minimal per-ability code** - mainly data + visuals

### Proposed Categories

#### 1. Projectile/Ranged Attacks
**Base Class:** `ProjectileAbility`

**Examples:**
- Ranger base ability: Fire arrows at nearby enemies
- Mage fireball: Throw explosive projectiles
- Boomerang: Projectile that returns to player

**Common Systems:**
- Projectile pooling
- Targeting (auto-target closest/random - configurable)
- Speed/damage modification
- Piercing behavior
- Bounce mechanics

#### 2. Player Buffs
**Base Class:** `BuffAbility`

**Examples:**
- Shield: Periodically grant damage absorption
- Haste: Temporary speed boost
- Rage: Damage boost for duration

**Common Systems:**
- Buff duration tracking
- Buff stacking rules
- Periodic activation
- Visual indicators (aura/particles)

#### 3. Close-Range/Circular Attacks
**Base Class:** `RadialAbility`

**Examples:**
- Flame aura: Leave trail of fire behind player
- Spinning blades: Circular damage around player
- Ground slam: AoE damage pulse

**Common Systems:**
- Radius calculation (affected by AoE modifiers)
- Continuous vs periodic damage
- Visual ring/circle effects

#### 4. Sky-Based/Magic Effects
**Base Class:** `CelestialAbility`

**Examples:**
- Lightning bolt: Strike random enemy from above
- Meteor: Target area from sky
- Blessing: Healing rain from above

**Common Systems:**
- Target selection
- Travel time/delay
- Impact effects
- Visual trajectory (sky → ground)

#### 5. Generic Magic Effects
**Base Class:** `MagicAbility`

**Examples:**
- Teleport
- Summon
- Transform

**Common Systems:**
- Effect duration
- Cooldown management
- Special visual effects

### Shared Base Architecture
**Question for Architecture:** Should all categories inherit from a single `BaseAbility` class?

```gdscript
# Potential hierarchy
BaseAbility (abstract)
    ├─→ ProjectileAbility
    ├─→ BuffAbility
    ├─→ RadialAbility
    ├─→ CelestialAbility
    └─→ MagicAbility
```

**Shared Properties:**
- `ability_id: String`
- `ability_name: String`
- `ability_level: int`
- `base_damage: float`
- `cooldown: float`
- `tags: Array[String]`
- `visual_scene: PackedScene`

**Shared Methods:**
- `apply_modifier(modifier: PowerUp) -> void`
- `level_up() -> void`
- `can_apply_modifier(modifier: PowerUp) -> bool`
- `get_modified_value(stat_name: String) -> float`

---

## 🔄 Ability Leveling System

### Level-Up Mechanic
**When player picks same ability upgrade again:**
```
NOT: Add duplicate ability
BUT: Level up existing ability

Example:
1. Player picks "Banana Throw" → Level 1 Banana Throw
2. Later, "Banana Throw" appears in upgrade pool again
3. Player picks it → Level 2 Banana Throw (NOT 2 separate abilities)
```

### Level Scaling Options

**Option A: Progressive Stat Increases**
```
Level 1: 10 damage
Level 2: 12 damage (+20%)
Level 3: 14 damage (+20%)
Level 4: 16 damage (+20%)
```

**Option B: Breakpoint Bonuses**
```
Level 1-4: +20% damage per level
Level 5: +1 projectile (breakpoint)
Level 6-9: +20% damage per level
Level 10: +1 projectile (breakpoint)
```

**Option C: Hybrid (Recommended)**
```gdscript
# Ability level-up resource
@export var damage_per_level: float = 2.0
@export var damage_multiplier_per_level: float = 1.1
@export var level_breakpoints: Dictionary = {
    5: {"projectile_count": +1},
    10: {"projectile_count": +1, "pierce_count": +1},
    15: {"projectile_count": +2}
}
```

---

## 🎲 Character Stats & Scaling

### Player Stats Affecting Abilities
**Each character has stats that scale abilities:**

**Primary Stats:**
- `strength` - Affects melee/physical damage
- `dexterity` - Affects attack speed, crit chance
- `intelligence` - Affects magic damage, cooldown reduction
- `vitality` - Affects HP, HP regen

**Derived Stats:**
- `damage_multiplier` - Scales all damage
- `attack_speed_multiplier` - Scales all attack speeds
- `cooldown_reduction` - Reduces all cooldowns
- `critical_chance` - Chance for critical hits
- `critical_multiplier` - Crit damage multiplier
- `area_multiplier` - Scales all AoE abilities
- `duration_multiplier` - Scales all duration effects
- `projectile_speed_multiplier` - Scales projectile speeds

### Ability Scaling Configuration
**Each ability defines which stats it scales with:**

```gdscript
# Example: Ranger Arrow ability
@export var damage_base: float = 10.0
@export var scales_with: Dictionary = {
    "dexterity": 0.5,      # +50% dex as damage
    "intelligence": 0.2,   # +20% int as damage
}
@export var affected_by_multipliers: Array[String] = [
    "damage_multiplier",
    "attack_speed_multiplier",
    "projectile_speed_multiplier",
    "critical_chance",
    "critical_multiplier"
]
```

**Calculation:**
```gdscript
final_damage = damage_base
    + (player.dexterity * 0.5)
    + (player.intelligence * 0.2)
    * player.damage_multiplier
```

---

## 🔗 System Integration Requirements

### Quest System Integration
**Quest system unlocks abilities progressively:**

```
Initial State: Only basic abilities available
    ├─→ Complete Quest "Defeat 100 enemies"
    ├─→ Unlock "Banana Throw" ability
    └─→ Banana Throw now appears in upgrade pool

Progression:
    Quest Completion → Unlock Ability/Power-Up → Add to Pool → Random Selection
```

**Questions:**
- Does ability system need to track unlock state?
- Or does quest system handle it entirely?
- How do we configure which abilities are locked/unlocked?

**Proposed:** Quest system emits unlock events, ability pool manager handles adding to available pool.

```gdscript
# EventBus signal
signal ability_unlocked(ability_id: String)

# AbilityPoolManager
func _on_ability_unlocked(ability_id: String) -> void:
    available_abilities.append(ability_id)
    Logger.info("Ability unlocked: %s" % ability_id, "abilities")
```

### Session/Stats Tracking Integration
**Track per-ability damage for run statistics:**

```gdscript
# SessionManager tracking
var ability_stats: Dictionary = {
    "fireball": {
        "total_damage": 15234.5,
        "hits": 432,
        "kills": 23
    },
    "arrow": {
        "total_damage": 8432.1,
        "hits": 234,
        "kills": 12
    }
}
```

**Integration Points:**
- `EventBus.damage_dealt` signal should include `source_ability_id`
- `SessionManager` subscribes and tracks per-ability stats
- Results screen displays damage breakdown by ability

**Also Important for Quests:**
- Quest: "Deal 10,000 damage with Banana Throw"
- Requires tracking damage per ability

**Proposed Signal Enhancement:**
```gdscript
# EventBus.gd
signal damage_dealt(
    source_id: String,
    target_id: String,
    damage: float,
    ability_id: String,  # ← ADD THIS
    damage_types: Array[String]
)
```

---

## 🧩 Existing System Leverage

### Bullet Upgrade Strategy Pattern
**From:** `/Obsidian/03-tasks/open-tasks/ability-system/2025-09-26_bullet-upgrade-strategy-pattern.md`

**Key Insights:**
1. **Strategy Pattern for Modifiers** - Use for power-ups
2. **Resource-Based Configuration** - Use for abilities + power-ups
3. **EventBus Integration** - Apply to ability system
4. **Modifier Pipeline** - Apply upgrades to abilities when activated

**Applicability to Ability System:**

**✅ Directly Applicable:**
- Strategy pattern for power-ups/modifiers
- `.tres` resource configuration
- Stack limit tracking
- Upgrade collection system
- Visual indicator system

**🔄 Needs Adaptation:**
- Bullet-specific → Ability-specific
- Single target (bullets) → Multiple ability types
- No leveling system → Add level-up mechanics

**Example Adaptation:**
```gdscript
# Instead of: BaseBulletStrategy
class_name BaseModifierStrategy extends Resource

# Instead of: apply_upgrade(bullet: Node2D)
func apply_to_ability(ability: BaseAbility, context: Dictionary) -> void:
    pass

# Add: Tag-based applicability
func can_apply_to_ability(ability: BaseAbility) -> bool:
    for tag in required_tags:
        if not ability.has_tag(tag):
            return false
    return true
```

---

## ⚠️ CRITICAL ARCHITECTURAL NOTE

### Three-Layer System Clarification (2025-10-03)

**IMPORTANT**: The MetaProgression three-category system has distinct purposes:

#### **Skills** (Abilities)
- **Purpose**: Active abilities with 4 slots per character
- **Scaling**: Damage scales through LEVELING (re-picking when already owned)
- **Rarity System**: Common (+1 level), Uncommon (+2), Rare (+3), Epic (+4), Legendary (+5)
- **Max Level**: ~20 levels (requires testing in endless arena)
- **Example**: Fireball, Arrow Shot, Shield Buff, Lightning Strike

#### **Tomes** (Ability Buffs)
- **Purpose**: General buffs that affect abilities
- **Limited Slots**: 4 tome slots total
- **Distinct Effects**: Each tome has unique scaling effect on abilities
- **Broad Applicability**: Affects multiple abilities via tag system
- **Example**: "Tome of Fire" (+20% fire damage), "Tome of Haste" (-10% cooldowns)

#### **Items** (Game Mechanics)
- **Purpose**: Broader game systems beyond just abilities
- **Examples**:
  - Luck chance modifiers
  - Drop rate increases
  - Movement speed
  - Experience gain multipliers
  - Enemy health/damage modifiers
- **Can affect abilities**: But this is NOT their primary purpose
- **Broader Range**: Affects various game systems

**Key Distinctions**:
- **Damage scaling** = Ability leveling (re-picking abilities)
- **Ability buffs** = Tomes (4 slots, general effects)
- **Game mechanics** = Items (luck, drops, movement, etc.)

**Acquisition Flow (CRITICAL):**
- **Level-up upgrade screen** = Abilities + Tomes ONLY
- **Purchasable Chests** = Items (cost gold from enemy kills)
- **Gold Economy**: Enemies drop gold → Player buys chests → Guaranteed item drop
- This separation prevents pool dilution and creates strategic spending decisions

**Impact on Design**:
- Power-ups are now primarily associated with **Tomes** (not Items)
- Items have their own modifier system for game mechanics
- Tag system applies to both Tomes (ability tags) and Items (mechanic tags)
- Upgrade screen generation only includes abilities + tomes (NO items)

---

## 🎯 Implementation Goals

### MVP (Minimum Viable Product)
**First Implementation Must Achieve:**

1. **One ability from each category working**
   - Projectile: Ranger arrow
   - Buff: Simple shield
   - Radial: Flame aura
   - Celestial: Lightning strike
   - Magic: TBD

2. **3-5 Tomes working** (renamed from "power-ups")**
   - +X% damage (fire/physical/lightning)
   - +X% attack speed
   - +1 projectile count
   - Projectiles apply burning
   - +X% area of effect

3. **Core systems functional:**
   - Ability selection popup
   - Ability leveling
   - Power-up application
   - Tag-based filtering
   - Visual modifier feedback

4. **Integration complete:**
   - EventBus signals
   - Session tracking (per-ability damage)
   - Quest unlock compatibility (stub)

### Fun Factor Requirements
**Must be fun to:**
- **Implement** - Easy to add new abilities with minimal code
- **Design** - Creative freedom to experiment with combinations
- **Play** - Satisfying feedback, clear visual power-ups, emergent builds

**Anti-Goals (Avoid):**
- Complex ability trees (keep simple for MVP)
- Ability removal/swapping (once set, it's set for run)
- Cross-ability interactions (too complex for MVP)

---

## ❓ Open Questions for Q&A Session

### Architecture Questions

#### ✅ ANSWERED (REVISED 2025-10-06) - Question 1: Base Class Hierarchy
**Decision: MINIMAL `BaseAbility` + `DamageAbility` intermediate class + type-specific subclasses**

**Original Decision (DEPRECATED):**
- ONE unified BaseAbility class with ALL optional properties (damage, cooldown, buff, AOE, orbit, etc.)
- Unused properties acceptable for code simplicity
- Tag system determines which properties are active

**Revised Decision (CURRENT):**
- **BaseAbility**: TRULY minimal - only universal properties (10 total)
- **DamageAbility**: Intermediate class for damage-dealing abilities (adds 10 damage properties)
- **UtilityAbility**: Intermediate class for non-damage abilities (stub for future)
- **Type-specific subclasses**: ProjectileAbility, MeleeAbility, BuffAbility, etc.

**Rationale for Revision:**
- Opening .tres files in Inspector showed 50+ properties with many irrelevant (buff_duration on projectiles)
- Designers couldn't easily identify which properties actually matter for each ability type
- Cluttered property inspector made iteration slower
- Duck typing provides same cross-hierarchy modifier support without monolithic base class

**New Implementation:**
```gdscript
BaseAbility (TRULY minimal - 10 properties)
  ├─→ DamageAbility (adds damage/cooldown/scaling - 10 properties)
  │   ├─→ ProjectileAbility (adds projectile behavior - 9 properties)
  │   ├─→ MeleeAbility (adds melee behavior - future)
  │   └─→ AoEAbility (adds AOE behavior - future)
  └─→ UtilityAbility (adds duration/cooldown - stub)
      ├─→ BuffAbility (adds stat modifiers - stub)
      ├─→ ShieldAbility (adds damage absorption - future)
      └─→ MovementAbility (adds dash/teleport - future)

BaseAbility properties (100% universal):
- ability_id, ability_name, description, icon
- tags, ability_level, max_level
- visual_scene, impact_effect

DamageAbility properties (100% of damage abilities):
- base_damage, damage_type, inherent_element
- base_cooldown, projectile_count (generic multi-hit)
- damage_scaling_per_level, cooldown_scaling_per_level
- level_breakpoints, breakpoint_bonuses
- final_damage, final_cooldown (computed)
- _active_modifiers (runtime modifier storage)

ProjectileAbility properties (100% of projectile abilities):
- fire_mode, is_homing, homing_strength
- chains_to_enemies, chain_radius, pierce_count
- knockback_distance, spread_angle
- projectile_speed, projectile_lifetime
```

**Duck Typing for Cross-Hierarchy Modifiers:**
```gdscript
# BaseTome.apply_to_ability() - defensive duck typing
if not ability.has_method("add_modifier"):
    push_warning("Cannot apply to non-damage ability")
    return

# DamageAbility._recalculate_final_stats() - flexible modifier application
for modifier in _active_modifiers:
    if "damage_multiplier" in modifier:
        final_damage *= pow(modifier.damage_multiplier, modifier.stack_count)
    if "cooldown_multiplier" in modifier:
        final_cooldown *= pow(modifier.cooldown_multiplier, modifier.stack_count)
    if "projectile_count_bonus" in modifier:
        projectile_count += modifier.projectile_count_bonus * modifier.stack_count

# Future ProjectileAbility override
func _recalculate_final_stats() -> void:
    super._recalculate_final_stats()  # Apply damage modifiers

    # Apply projectile-specific modifiers
    for modifier in _active_modifiers:
        if "pierce_bonus" in modifier:
            pierce_count += modifier.pierce_bonus * modifier.stack_count
```

**Designer Experience Improvements:**
- ProjectileAbility .tres files: 26 relevant properties (was 50+ with obsolete)
- Clear property organization: BaseAbility (10) → DamageAbility (10) → ProjectileAbility (9)
- No confusing buff_duration, aoe_radius, orbit_radius on projectile abilities
- Ability Testing Tool shows only relevant fields (10 for ProjectileAbility, 3 for base DamageAbility)
- Future ability types automatically work via duck typing

---

#### ✅ ANSWERED - Question 2: Animation/Visual Connection
**Decision: Hybrid approach - Scene reference with optional modifier interface**

**Rationale:**
- Need editor control for visual experimentation (particles, animations, sprites)
- Main ability visuals are scene-based for flexibility
- Optional code-based effects via modifier methods
- Allows iteration: start simple (sprite), add complexity later (particles, trails)

**Implementation Pattern:**
```gdscript
# BaseAbility (or category classes)
@export var visual_scene: PackedScene  # e.g., res://scenes/abilities/arrow.tscn

# Ability activates and spawns visuals:
func activate(player: Node2D, context: Dictionary) -> void:
    # Handle projectile_count by spawning multiple instances
    for i in projectile_count:
        var visual = visual_scene.instantiate()
        _apply_visual_modifiers(visual)  # Optional modifier methods
        _spawn_visual(visual, player, i)

# Visual scenes can implement optional modifier methods:
func _apply_visual_modifiers(visual: Node2D) -> void:
    # Check if visual supports modifiers (optional)
    if visual.has_method("set_scale_from_damage"):
        visual.set_scale_from_damage(base_damage)

    if has_tag("fire") and visual.has_node("FireParticles"):
        visual.get_node("FireParticles").emitting = true
```

**Visual Scene Convention (arrow.tscn script - OPTIONAL methods):**
```gdscript
extends Node2D
class_name AbilityVisual  # Optional marker class

# These methods are OPTIONAL - implement if visual needs them:
func set_scale_from_damage(damage: float) -> void:
    scale = Vector2.ONE * (1.0 + damage * 0.05)

func set_explosion_radius(radius: float) -> void:
    if has_node("AoEIndicator"):
        $AoEIndicator.radius = radius
```

**Benefits:**
- Visual scenes can be as simple or complex as needed
- Ability system handles spawning (projectile_count → spawn N instances)
- Modifier methods are opt-in (visual scenes without them still work)
- Easy to iterate: create basic sprite, test, then polish with particles/effects

**Note:** Requires experimentation during implementation to refine conventions

---

#### ✅ ANSWERED - Question 3: Instance Ownership
**Decision: Hybrid - AbilityManager for registry, Player owns instances**

**Rationale:**
- Clear separation: shared definitions (.tres) vs per-player instances (unique state)
- Each player has unique ability state (levels, applied modifiers)
- Supports character-specific base abilities + universal pool
- Multiplayer-ready architecture

**Implementation Pattern:**
```gdscript
# autoload/AbilityManager.gd
var ability_definitions: Dictionary = {}  # ALL abilities (base + pool)

func create_ability_instance(ability_id: String) -> BaseAbility:
    return ability_definitions[ability_id].duplicate()  # Create instance

# ----

# CharacterDefinition.gd
@export var base_ability_id: String = "ranger_arrow"  # Character-specific

# ----

# Player.gd
var ability_slots: Array[BaseAbility] = [null, null, null, null]

func initialize_character(char_def: CharacterDefinition) -> void:
    # Slot 0 = character's base ability (permanent)
    ability_slots[0] = AbilityManager.create_ability_instance(char_def.base_ability_id)
    # Slots 1-3 = empty, filled during run
```

**Upgrade System Integration:**
- All abilities exist in universal pool (including base abilities)
- Characters start with their base ability pre-equipped in slot 0
- Finding ability upgrade → check if already owned:
  - **Already have:** Level up existing ability (by rarity: common +1, rare +4, legendary +5)
  - **Don't have:** Add to first empty slot (slots 1-3)

**Cross-Character Example:**
```
Mage starts: Fireball (slot 0 - base)
Mage finds: Ranger Arrow upgrade → adds to slot 1 (new ability for Mage)
Mage finds: Ranger Arrow upgrade again → slot 1 levels up

Ranger starts: Ranger Arrow (slot 0 - base)
Ranger finds: Ranger Arrow upgrade → slot 0 levels up (already owned)
```

**Rarity System:**
- Common: +1 level
- Uncommon: +2 levels (TBD)
- Rare: +4 levels
- Legendary: +5 levels

---

#### ✅ ANSWERED - Question 4: Cooldown Management
**Decision: Player tracks cooldowns in parallel array (auto-cast system)**

**Rationale:**
- Consistent with Question 3 (Player owns ability state)
- Abilities are auto-cast (like Brotato/Vampire Survivors) - no manual activation
- Player stats (cooldown_reduction) easily applied when starting cooldowns
- Abilities remain pure behavior/data, Player manages state
- Cooldowns not shown in UI (player sees abilities activate, stats shown in upgrade screen)

**Implementation Pattern:**
```gdscript
# Player.gd
var ability_slots: Array[BaseAbility] = [null, null, null, null]
var ability_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var stats: PlayerStats  # includes cooldown_reduction

func _process(delta: float) -> void:
    _update_ability_cooldowns(delta)
    _auto_cast_ready_abilities()

func _update_ability_cooldowns(delta: float) -> void:
    for i in range(4):
        if ability_cooldowns[i] > 0.0:
            ability_cooldowns[i] -= delta

func _auto_cast_ready_abilities() -> void:
    for i in range(4):
        var ability = ability_slots[i]
        if ability and ability_cooldowns[i] <= 0.0:
            if _can_auto_activate(ability):
                _activate_ability(i)

func _activate_ability(slot_index: int) -> void:
    var ability = ability_slots[slot_index]
    var context = {
        "player": self,
        "target": _get_target_for_ability(ability),
        "stats": stats
    }

    ability.activate(self, context)

    # Apply cooldown with player's cooldown reduction stat
    if ability.has_tag("cooldown"):
        var final_cooldown = ability.cooldown * (1.0 - stats.cooldown_reduction)
        ability_cooldowns[slot_index] = final_cooldown
```

**Auto-Cast Conditions:**
- Projectile abilities: Only fire if enemies exist in range
- Buff abilities: Always cast when ready
- Other types: Define in `_can_auto_activate()`

**UI Implications:**
- Ability slots shown (top-left) - no cooldown timers displayed
- Upgrade screen shows player stats panel (right side) with global cooldown_reduction
- Player sees abilities activating visually, feels power scaling through faster/more effects

**Benefits for Testing/Balance:**
- No player skill variance (pure stat-based scaling)
- Easier to test DPS/ability interactions
- Simpler implementation (no input handling)

---

### Tag System Questions

#### ✅ ANSWERED - Questions 5-7: Tag System Design
**Decisions:**
1. **Granularity:** Few broad tags (10-15 core tags)
2. **Type:** StringName constants (code safety + editor friendliness)
3. **Inheritance:** Explicit tags only (no inheritance system)

**Rationale:**
- Broad tags support "broad power-ups affecting many abilities" vision
- Constants provide autocomplete and typo safety in code
- Explicit tags keep system simple and clear
- Easy to see exactly what tags an ability has

**Implementation Pattern:**
```gdscript
# scripts/domain/AbilityTags.gd
class_name AbilityTags
extends Object

## Behavior tags
const PROJECTILE: StringName = &"projectile"
const BUFF: StringName = &"buff"
const DEBUFF: StringName = &"debuff"
const AOE: StringName = &"aoe"
const MELEE: StringName = &"melee"
const RADIAL: StringName = &"radial"
const CHANNELED: StringName = &"channeled"

## Mechanic tags
const DAMAGE: StringName = &"damage"
const COOLDOWN: StringName = &"cooldown"
const DURATION: StringName = &"duration"

## Element tags
const FIRE: StringName = &"fire"
const ICE: StringName = &"ice"
const POISON: StringName = &"poison"
const LIGHTNING: StringName = &"lightning"
const PHYSICAL: StringName = &"physical"

# ----

# BaseAbility.gd
@export var tags: Array[String] = []  # Stored as strings for .tres compatibility

func has_tag(tag: String) -> bool:
    return tag in tags
```

**Resource File Example:**
```tres
# data/content/abilities/ranger_arrow.tres
[gd_resource type="ProjectileAbility"]

[resource]
ability_id = "ranger_arrow"
ability_name = "Ranger's Arrow"
tags = ["projectile", "damage", "physical", "cooldown"]  # ← Explicit, readable
base_damage = 15.0
cooldown = 0.8
```

**Code Usage Example:**
```gdscript
# Power-up application
if ability.has_tag(AbilityTags.PROJECTILE):
    ability.projectile_count += 2  # ← Autocomplete, typo-safe

if ability.has_tag(AbilityTags.DAMAGE):
    ability.base_damage *= 1.5

# Multi-tag check
if ability.has_tag(AbilityTags.FIRE) and ability.has_tag(AbilityTags.PROJECTILE):
    ability.apply_burning_on_hit = true
```

**Core Tag Set (Starting Point):**
- **Behavior (6):** projectile, buff, debuff, aoe, melee, radial
- **Mechanics (3):** damage, cooldown, duration
- **Elements (5):** fire, ice, poison, lightning, physical

**Total:** ~15 tags (can expand as needed, but keep focused on broad categories)

---

### Modifier/Power-Up Questions

#### ✅ ANSWERED - Question 8: Visual Stacking & Caps
**Decision: Hard cap + pool removal system**

**Rationale:**
- Prevents absurd visual clutter in endless runs
- Forces build diversity (can't infinitely stack one power-up)
- Simple to implement and balance
- Performance-safe (natural limits on extreme values)
- Can add evolution system later as enhancement

**Implementation Pattern:**
```gdscript
# BasePowerUp.gd
@export var stack_limit: int = 10  # Hard cap per power-up

# Player.gd
var powerup_counts: Dictionary = {}  # powerup_id -> stack_count

func add_powerup(powerup: BasePowerUp) -> bool:
    var current_count = powerup_counts.get(powerup.powerup_id, 0)

    if current_count >= powerup.stack_limit:
        return false  # At cap, can't add more

    powerup_counts[powerup.powerup_id] = current_count + 1
    apply_powerup_to_abilities(powerup)
    EventBus.powerup_acquired.emit(powerup.powerup_id, current_count + 1)
    return true

# Upgrade pool generation (filters out capped power-ups)
func get_available_powerups() -> Array[BasePowerUp]:
    var available = []
    for powerup in all_powerups:
        var current_count = powerup_counts.get(powerup.powerup_id, 0)
        if current_count < powerup.stack_limit:
            available.append(powerup)
    return available
```

**Example Stack Limits (tunable):**
- +1 Projectile Count: 10 stacks max
- +50% Damage: 8 stacks max
- +25% Attack Speed: 12 stacks max
- "Projectiles Apply Burning": 1 stack (binary on/off)

**Visual Cap for Abilities:**
```gdscript
# ProjectileAbility - cap visual spawns even if count higher
@export var max_visual_projectiles: int = 15

func activate(player: Node2D, context: Dictionary) -> void:
    var visual_count = min(projectile_count, max_visual_projectiles)
    var damage_per = base_damage * (float(projectile_count) / visual_count)

    for i in visual_count:
        # Spawn up to 15 visuals, scale damage if count > 15
```

**Future Enhancement (Phase 2):**
- Evolution system: At cap, power-up transforms into advanced version
- Example: "+1 Projectile (10 stacks)" → "Projectiles Fork on Hit (5 stacks)"

---

#### ✅ ANSWERED - Question 10: Power-Up Display UI
**Decision: Bottom center, transparent icon row with stack counts**

**UI Design:**
```
Screen Layout:
┌─────────────────────────────────────┐
│       [Gameplay Area]               │
│                                     │
└─────────────────────────────────────┘
         Bottom center ↓
    [🔥] [⚡³] [💪] [🎯⁵] [🛡]
     ↑    ↑    ↑    ↑    ↑
   Just icons, transparent background
   Number = stack count (if > 1)
```

**Specifications:**
- **Location:** Bottom center of screen
- **Icons:** Just icon texture, no border/frame
- **Background:** Transparent
- **Stack count:** Small number indicator in corner (e.g., ³ = 3 stacks)
- **Spacing:** Compact horizontal row, icons close together
- **Size:** ~32x32 pixels per icon

**Implementation:**
```gdscript
# scenes/ui/hud/PowerUpDisplay.gd
class_name PowerUpDisplay
extends Control

@onready var icon_container: HBoxContainer = $IconContainer

func update_powerups(powerup_counts: Dictionary) -> void:
    # Clear existing
    for child in icon_container.get_children():
        child.queue_free()

    # Add icon for each power-up
    for powerup_id in powerup_counts.keys():
        var count = powerup_counts[powerup_id]
        var def = PowerUpManager.get_definition(powerup_id)

        var icon = PowerUpIcon.new()
        icon_container.add_child(icon)
        icon.setup(def.icon_texture, count)

# ----

# PowerUpIcon.tscn
# Control
#   ├─ TextureRect (32x32, icon texture)
#   └─ Label (stack count, top-right corner, only if > 1)
```

**Inspiration:** Risk of Rain 2, Vampire Survivors, Brotato style item displays

---

#### ✅ ANSWERED - Question 9: Modifier Duration/Permanence
**Decision: Permanent Tomes for entire run (Option A)**

**⚠️ UPDATED 2025-10-03**: Terminology corrected from "power-ups" to "Tomes"

**Rationale:**
- Auto-cast system makes temporary/charge mechanics less meaningful
- Matches Brotato/Vampire Survivors genre conventions
- Simpler system (no duration/charge tracking)
- Clear, predictable power scaling for endless runs
- Easier to balance and test

**Implementation:**
```gdscript
# BaseTome.gd
class_name BaseTome
extends Resource

@export var tome_id: String
@export var tome_name: String
@export var icon_texture: Texture2D
@export var stack_limit: int = 10
@export var applicable_tags: Array[String] = []  # Which abilities this affects
# No duration/charges - all tomes are permanent

# Player.gd (Tome slots - 4 total)
var tome_slots: Array[BaseTome] = [null, null, null, null]
var tome_stacks: Array[int] = [0, 0, 0, 0]  # Stack count per slot

func add_tome(tome: BaseTome, slot: int = -1) -> void:
    # Find existing slot or use new slot
    if slot == -1:
        slot = find_tome_slot(tome.tome_id)
        if slot == -1:
            slot = find_empty_tome_slot()

    if slot == -1:
        Logger.warn("No tome slots available", "abilities")
        return

    # Apply permanently to abilities
    for ability in ability_slots:
        if ability and tome.can_apply_to(ability):
            tome.apply_to_ability(ability, tome_stacks[slot] + 1)

    tome_slots[slot] = tome
    tome_stacks[slot] += 1
    Logger.info("Added %s (stack: %d)" % [tome.tome_name, tome_stacks[slot]], "tomes")
```

**Examples:**
- "Tome of Fire" (+20% fire damage) → Permanent for entire run
- "Tome of Haste" (-10% cooldown) → Permanent for entire run
- "Tome of Might" (+1 projectile to projectile abilities) → Permanent for entire run
- "Tome of Precision" (+15% crit chance) → Permanent for entire run

**Future Extension (Separate System):**
- **Temporary buffs** will be handled separately (different from Tomes)
- Examples: Map shrine buffs, consumable items, event effects
- Need interface for applying temporary stat/ability modifications
- Could use same tag system but with duration tracking
- Not part of upgrade screen Tome pool

**Note:** This keeps Tome system simple. Temporary effects handled by future buff/consumable system.

---

#### ✅ ANSWERED - Question 11: Modifier Application Timing
**Decision: Apply when acquired (modify ability data directly)**

**⚠️ UPDATED 2025-10-03**: Terminology corrected from "power-ups" to "Tomes"

**Rationale:**
- Permanent Tomes (from Q9) don't need recalculation every activation
- Simple and performant (calculate once vs every cast)
- Clear state (ability data reflects current power level)
- Easy to debug (inspect ability, see modified values)
- When new ability equipped, apply all existing Tomes to it

**Implementation Pattern:**
```gdscript
# Player.gd
var ability_slots: Array[BaseAbility] = [null, null, null, null]
var tome_slots: Array[BaseTome] = [null, null, null, null]
var tome_stacks: Array[int] = [0, 0, 0, 0]

# When Tome acquired or stacked
func add_tome(tome: BaseTome, slot: int = -1) -> void:
    # Find existing slot or use new slot
    if slot == -1:
        slot = find_tome_slot(tome.tome_id)
        if slot == -1:
            slot = find_empty_tome_slot()

    # Immediately apply to all existing abilities
    for ability in ability_slots:
        if ability:
            _apply_tome_to_ability(tome, ability, tome_stacks[slot] + 1)

    tome_slots[slot] = tome
    tome_stacks[slot] += 1
    EventBus.tome_acquired.emit(tome.tome_id, tome_stacks[slot])

func _apply_tome_to_ability(tome: BaseTome, ability: BaseAbility, stack_count: int) -> void:
    # Check if Tome applies to this ability (via tags)
    if not tome.can_apply_to(ability):
        return

    # Modify ability data directly (additive per stack)
    if tome.damage_multiplier != 1.0 and ability.has_tag(AbilityTags.DAMAGE):
        var multiplier = 1.0 + ((tome.damage_multiplier - 1.0) * stack_count)
        ability.base_damage *= multiplier

    if tome.projectile_count_bonus > 0 and ability.has_tag(AbilityTags.PROJECTILE):
        (ability as ProjectileAbility).projectile_count += tome.projectile_count_bonus * stack_count

    if tome.cooldown_reduction != 0.0 and ability.has_tag(AbilityTags.COOLDOWN):
        var reduction = tome.cooldown_reduction * stack_count
        ability.cooldown *= (1.0 - reduction)

    # Special effects stored as flags (binary - single stack activates)
    if tome.applies_burning and stack_count >= 1:
        ability.applies_burning = true

    Logger.debug("Applied %s (stack %d) to %s" % [tome.tome_name, stack_count, ability.ability_name], "tomes")

# When new ability equipped
func add_ability(ability_id: String, slot: int) -> void:
    var new_ability = AbilityManager.create_ability_instance(ability_id)

    # Apply ALL existing Tomes to new ability
    for i in tome_slots.size():
        var tome = tome_slots[i]
        if tome:
            _apply_tome_to_ability(tome, new_ability, tome_stacks[i])

    ability_slots[slot] = new_ability
    Logger.info("Equipped %s with %d tomes applied" %
               [new_ability.ability_name, _get_active_tome_count()], "abilities")

# Activation is simple - just use current ability values
func _activate_ability(slot_index: int) -> void:
    var ability = ability_slots[slot_index]
    ability.activate(self, {"player": self})
    # Ability already has all Tomes applied to its data
```

**Example Flow:**
```
1. Player starts: Ranger Arrow (projectile_count=1, base_damage=15)
2. Pick up: Tome of Might (+1 Projectile Count per stack)
   → Ranger Arrow: (projectile_count=2, base_damage=15)
3. Pick up: Tome of Fire (+20% Fire Damage)
   → Ranger Arrow: (projectile_count=2, base_damage=18)
4. Equip: Fireball (new ability)
   → Auto-apply Tome of Might, Tome of Fire
   → Fireball starts: (projectile_count=2, base_damage=30)
```

**Benefits:**
- Activation logic stays simple (no runtime calculation)
- Performance efficient (modify once, not every cast)
- State inspection easy (ability values show current power)
- New abilities automatically benefit from collected Tomes
- **Items** will have their own application system (broader game mechanics)

---

### Leveling Questions

#### ✅ ANSWERED - Questions 12-14: Ability Leveling System

**Q12: Level Scaling - Per-Ability Configuration (Flexible)**

**Decision:** Configurable per ability with sensible defaults

**Rationale:**
- Data-driven flexibility for unique ability progression
- Most abilities use default scaling (simple)
- Special abilities can have breakpoint bonuses (interesting)
- Allows tuning per ability during testing

**Implementation:**
```gdscript
# BaseAbility.gd
@export var damage_scaling_per_level: float = 1.15  # Default: 15% increase
@export var cooldown_scaling_per_level: float = 0.95  # Default: 5% faster
@export var level_breakpoints: Dictionary = {}  # Optional special bonuses

# Example breakpoints (optional):
# {
#     5: {"projectile_count": 1},   # At level 5, +1 projectile
#     10: {"projectile_count": 1, "pierce_count": 1},
#     15: {"applies_burning": true}
# }

func level_up(levels: int = 1) -> void:
    for i in levels:
        ability_level += 1

        # Apply scaling
        if has_tag(AbilityTags.DAMAGE):
            base_damage *= damage_scaling_per_level

        if has_tag(AbilityTags.COOLDOWN):
            cooldown *= cooldown_scaling_per_level

        # Check for breakpoint bonuses
        if ability_level in level_breakpoints:
            _apply_breakpoint_bonus(level_breakpoints[ability_level])

    Logger.info("%s leveled up to %d" % [ability_name, ability_level], "abilities")
```

**Example Configurations:**
```tres
# ranger_arrow.tres - Simple scaling
damage_scaling_per_level = 1.15
cooldown_scaling_per_level = 0.95
level_breakpoints = {}  # No special breakpoints

# banana_throw.tres - With breakpoints
damage_scaling_per_level = 1.20  # Scales faster
cooldown_scaling_per_level = 0.98  # Slower cooldown reduction
level_breakpoints = {
    5: {"projectile_count": 1},
    10: {"projectile_count": 1}
}
```

---

**Q13: Max Level Cap - Configurable with Default**

**Decision:** Max level cap with default ~20, tunable during endless arena testing

**Rationale:**
- Need to test with endless arena generation to find right balance
- Cap prevents single-ability dominance (forces build diversity)
- Combined with power-up caps, creates natural "build ceiling"
- Players can still progress farther with optimal builds/skill
- Configurable per ability if needed (some cap at 10, others at 30)

**Implementation:**
```gdscript
# BaseAbility.gd
@export var max_level: int = 20  # Default cap, configurable per ability

func can_level_up() -> bool:
    return ability_level < max_level

# When generating upgrade options
func get_available_ability_upgrades() -> Array:
    var available = []
    for ability in player.ability_slots:
        if ability and ability.can_level_up():
            available.append(ability)
    return available
```

**Design Philosophy:**
```
Build ceiling = Combined caps
├─ Ability level caps (e.g., max level 20)
├─ Power-up stack caps (e.g., max 10 stacks)
└─ Total cap creates natural "max power" point

Beyond build ceiling:
├─ Player skill matters more (movement, positioning)
├─ Synergies between abilities become key
└─ "Going farther" = optimization, not raw power scaling
```

**Tuning Notes:**
- Start with max_level = 20 for testing
- Adjust based on endless arena feedback
- May vary by ability type (projectiles 20, buffs 10, etc.)
- Monitor: at what level do runs "feel capped"?

---

**Q14: Leveling Mechanic - Automatic**

**Decision:** Automatic level-up when ability upgrade picked again

**Rationale:**
- Already confirmed in earlier discussion
- Simple, clear feedback
- No additional choice dialogs needed
- Matches genre conventions (Vampire Survivors style)

**Implementation:**
```gdscript
# Player picks upgrade from upgrade screen
func on_ability_upgrade_selected(upgrade: AbilityUpgradeOption) -> void:
    var ability_id = upgrade.ability_id
    var existing_slot = find_ability_slot(ability_id)

    if existing_slot != -1:
        # Already have ability → Level it up
        var level_gain = upgrade.get_level_increase()  # Based on rarity
        ability_slots[existing_slot].level_up(level_gain)

        Logger.info("Leveled up %s by %d (rarity: %s)" %
                   [ability_id, level_gain, upgrade.rarity], "abilities")
    else:
        # Don't have ability → Add to empty slot
        var empty_slot = find_empty_slot()
        if empty_slot != -1:
            add_ability(ability_id, empty_slot)
```

**Rarity-Based Leveling (from earlier decision):**
- Common: +1 level
- Uncommon: +2 levels
- Rare: +4 levels
- Legendary: +5 levels

---

### Integration Questions

#### ✅ ANSWERED - Question 15: Meta-Progression & Three-Layer Pool System

**Decision: Use existing MetaProgression system with three-layer progression (Skills + Tomes + Items)**

**⚠️ UPDATED 2025-10-03**: Corrected understanding of three-layer system purposes

**Rationale:**
- Existing `MetaProgression.gd` already handles unlock/discovery for three categories
- Toggler system already implemented (enable/disable unlocked items after 40 unlocks)
- Quest-based unlock triggers already supported
- All three layers use same unlock infrastructure

**Three-Layer Progression System:**

1. **Skills (Abilities)** - MetaProgression category: `"skills"`
   - **Purpose**: Active abilities that auto-cast (Brotato/Vampire Survivors style)
   - 4 ability slots per character (slot 0 = base, slots 1-3 = unlockable)
   - **Damage scaling**: Through leveling (re-picking when already owned)
   - Rarity-based leveling: Common (+1), Uncommon (+2), Rare (+3), Epic (+4), Legendary (+5)
   - Max level cap (default 20, configurable per ability)
   - **Examples**: Fireball, Arrow Shot, Shield Buff, Lightning Strike

2. **Tomes (Ability Buffs)** - MetaProgression category: `"tomes"`
   - **Purpose**: General buffs that enhance abilities
   - **Limited slots**: 4 tome slots total (similar structure to abilities)
   - **Distinct effects**: Each tome has unique scaling effect on abilities
   - Applied to abilities via tag system
   - Stack limits per tome (configurable, similar to old "power-ups")
   - **Examples**:
     - "Tome of Fire" (+20% fire damage to all fire abilities)
     - "Tome of Haste" (-10% cooldown to all abilities)
     - "Tome of Precision" (+15% crit chance to projectile abilities)
     - "Tome of Might" (+1 projectile count to all projectile abilities)

3. **Items (Game Mechanics)** - MetaProgression category: `"items"`
   - **Purpose**: Broader game systems beyond just abilities
   - **⚠️ ACQUISITION**: Found in chests/events, NOT from level-up upgrade screen
   - **Affects multiple mechanics**, not limited to abilities
   - **Examples**:
     - Luck chance modifiers (global drop rate)
     - Experience gain multipliers (+10% XP from all sources)
     - Movement speed (+15% player movement)
     - Enemy modifiers (enemies move 10% slower)
     - Resource multipliers (enemies drop +50% rift fragments)
   - **Can affect abilities**: But this is NOT their primary purpose
   - **Example ability interaction**: "Glass Cannon" (+25% damage, -25% max HP)
   - **Design Intent**: "Found treasure" feel, environmental rewards, special acquisition flow

**Pool Generation Flow:**
```gdscript
# Session start - Create pools from MetaProgression
func start_run(character_id: String, map_id: String, tier: int) -> void:
    # Get ALL unlocked from MetaProgression
    var all_skills = MetaProgression.get_unlocked_items("skills")
    var all_tomes = MetaProgression.get_unlocked_items("tomes")
    var all_items = MetaProgression.get_unlocked_items("items")

    # Apply Toggler filtering (player's pre-run disable choices)
    _available_ability_pool = _apply_toggler_filter("skills", all_skills)
    _available_tome_pool = _apply_toggler_filter("tomes", all_tomes)
    _available_item_pool = _apply_toggler_filter("items", all_items)

    Logger.info("Run pools: %d abilities, %d tomes, %d items" %
               [_available_ability_pool.size(), _available_tome_pool.size(),
                _available_item_pool.size()], "progression")

func _apply_toggler_filter(category: String, items: Array[String]) -> Array[String]:
    if not MetaProgression.is_toggler_enabled(category):
        return items  # Toggler not unlocked, return all

    # Filter out disabled items
    return items.filter(func(item_id):
        return not MetaProgression.is_item_disabled(category, item_id)
    )
```

**Level-Up Upgrade Screen Generation (Abilities + Tomes ONLY):**
```gdscript
# ⚠️ UPDATED 2025-10-03: Items NOT in level-up pool (chest/event rewards only)
func generate_levelup_upgrade_options(player: Player, count: int = 3) -> Array:
    var available_options: Array = []

    # Filter abilities (can level up or equip new)
    for ability_id in _available_ability_pool:
        var option = _check_ability_availability(player, ability_id)
        if option: available_options.append(option)

    # Filter tomes (under stack limit, slots available)
    for tome_id in _available_tome_pool:
        var option = _check_tome_availability(player, tome_id)
        if option: available_options.append(option)

    # ❌ NO ITEMS in level-up pool - acquired from chests/events instead

    # Randomly select from combined pool (abilities + tomes)
    available_options.shuffle()
    return available_options.slice(0, min(count, available_options.size()))

# Items acquired separately from chests/events
func on_chest_opened(chest_type: String) -> void:
    # Roll for item drop
    var item_id = _roll_item_drop(chest_type)
    if item_id:
        var item = ItemManager.get_definition(item_id)
        player.add_item(item)
        EventBus.item_acquired.emit(item_id, "chest")
        Logger.info("Found item in chest: %s" % item.item_name, "items")
```

**Availability Checks (Level-Up Only):**
```gdscript
func _check_ability_availability(player: Player, ability_id: String) -> AbilityUpgradeOption:
    var existing_slot = player.find_ability_slot(ability_id)

    if existing_slot != -1:
        # Already have → Can level up if not at cap
        var ability = player.ability_slots[existing_slot]
        if ability.ability_level < ability.max_level:
            return AbilityUpgradeOption.new(ability_id, "level_up")
    else:
        # Don't have → Can equip if slots available
        if player.has_empty_ability_slot():
            return AbilityUpgradeOption.new(ability_id, "equip")

    return null  # Can't use this ability right now

func _check_tome_availability(player: Player, tome_id: String) -> TomeUpgradeOption:
    var existing_slot = player.find_tome_slot(tome_id)
    var tome_def = TomeManager.get_definition(tome_id)

    if existing_slot != -1:
        # Already have → Can level up if under stack limit
        var current_stack = player.tome_stacks[existing_slot]
        if current_stack < tome_def.stack_limit:
            return TomeUpgradeOption.new(tome_id, "stack")
    else:
        # Don't have → Can equip if slots available
        if player.has_empty_tome_slot():
            return TomeUpgradeOption.new(tome_id, "equip")

    return null  # Can't use this tome right now

# ❌ NO item availability check for level-up - items from chests/events
```

**Item Acquisition System (Purchasable Chests - Slot Machine Feel):**
```gdscript
# ChestManager.gd (or similar)
class_name ChestManager

# ⚠️ ALL CHESTS IDENTICAL - Cost scales with map tier/wave, NOT chest type
# Rarity roll happens AFTER opening (visual slot machine moment)

func get_chest_cost(map_tier: int, wave_num: int) -> int:
    # Base cost scales with difficulty
    var base_cost = 50
    var tier_multiplier = 1.0 + (map_tier - 1) * 0.5  # T1: 1.0x, T2: 1.5x, T3: 2.0x, T4: 2.5x
    var wave_scaling = 1.0 + (wave_num / 10.0) * 0.2  # Gradually increase with waves

    return int(base_cost * tier_multiplier * wave_scaling)

    # Example costs:
    # Tier 1, Wave 1: 50g
    # Tier 1, Wave 10: 60g
    # Tier 2, Wave 1: 75g
    # Tier 4, Wave 30: 187g

# Base rarity weights (modified by player's luck stat from Items)
const BASE_RARITY_WEIGHTS: Dictionary = {
    "common": 50,
    "uncommon": 30,
    "rare": 15,
    "epic": 4,
    "legendary": 1
}

# Chest spawning (all chests identical visually)
func spawn_chest(position: Vector2) -> void:
    var chest_scene = preload("res://scenes/interactables/Chest.tscn")
    var chest = chest_scene.instantiate()
    chest.global_position = position

    # Small chance to spawn already-opened (free loot!)
    const FREE_CHEST_CHANCE: float = 0.05  # 5% chance
    chest.is_free = RNG.stream("loot").randf() < FREE_CHEST_CHANCE

    if chest.is_free:
        chest.play_already_open_visual()  # Lid already open, glowing
        Logger.debug("Spawned FREE chest at %v" % position, "chests")
    else:
        # Cost determined dynamically when opened (based on current tier/wave)
        Logger.debug("Spawned chest at %v" % position, "chests")

    Arena.add_child(chest)

# Player interacts with chest
func on_chest_interaction(chest: Node, player: Player) -> void:
    var cost = 0

    if not chest.is_free:
        # Calculate cost based on current game state
        cost = get_chest_cost(RunManager.current_tier, Arena.current_wave)

        # Check if player has enough gold
        if player.gold < cost:
            UI.show_notification("Not enough gold! (%d/%d)" % [player.gold, cost])
            Logger.debug("Insufficient gold for chest (need %d)" % cost, "chests")
            return

        # Deduct gold
        player.gold -= cost
        EventBus.gold_spent.emit(cost, "chest")
        Logger.info("Opened chest for %d gold" % cost, "chests")
    else:
        # FREE CHEST!
        UI.show_notification("FREE CHEST!")
        Logger.info("Opened FREE chest (no cost)", "chests")

    # SLOT MACHINE VISUAL SEQUENCE (no player choice)
    await _play_chest_opening_animation(chest, player, chest.is_free)

    # Remove chest from world
    chest.queue_free()

# Slot machine visual animation
func _play_chest_opening_animation(chest: Node, player: Player, is_free: bool) -> void:
    # 1. Roll rarity (with luck modifier, +bonus for free chests!)
    var luck_bonus = 0
    if is_free:
        luck_bonus = 10  # Free chests have better odds!

    var rarity = _roll_item_rarity_with_luck(player, luck_bonus)

    # 2. Get eligible item
    var item = _get_random_item(player, rarity)
    if not item:
        Logger.warn("No eligible items for rarity %s" % rarity, "items")
        return

    # 3. Visual sequence (all happens automatically, no player input)
    if not is_free:
        chest.play_opening_animation()  # Chest lid opens
        await get_tree().create_timer(0.3).timeout
    # else: Already open, skip opening animation

    # 4. SLOT MACHINE ROLL - Fast cycling through rarities
    var rarity_display = chest.get_node("RarityDisplay")
    var roll_duration = 2.0  # 2 seconds of spinning
    var roll_time = 0.0

    while roll_time < roll_duration:
        # Cycle through rarities visually (getting slower)
        var speed = 0.05 + (roll_time / roll_duration) * 0.3  # Speed up as we approach result
        await get_tree().create_timer(speed).timeout

        var fake_rarity = _get_random_rarity_for_visual()
        rarity_display.show_rarity(fake_rarity)
        chest.play_rarity_sound(fake_rarity)  # Audio feedback

        roll_time += speed

    # 5. CLIMAX - Show actual result
    rarity_display.show_rarity(rarity)  # Final result
    chest.play_rarity_reveal_sound(rarity)  # Bigger sound for actual result
    await get_tree().create_timer(0.5).timeout

    # 6. Item rises from chest
    var item_visual = chest.spawn_item_visual(item)
    item_visual.play_rise_animation()  # Float up from chest
    await item_visual.animation_finished

    # 7. Add to player
    player.add_item(item)
    EventBus.item_acquired.emit(item.item_id, rarity)

    # 8. Show item details popup
    UI.show_item_acquired_popup(item, rarity)

    Logger.info("Acquired %s item: %s" % [rarity, item.item_name], "items")

func _roll_item_rarity_with_luck(player: Player, bonus_luck: int = 0) -> String:
    # Get base weights
    var weights = BASE_RARITY_WEIGHTS.duplicate()

    # Apply luck modifier from Items (e.g., "Lucky Coin" item)
    var luck_bonus = player.get_stat("luck") + bonus_luck  # Default 0, Items can add +5%, +10%, etc.

    # Luck shifts probability toward higher rarities
    if luck_bonus > 0:
        # Reduce common weight, increase higher rarities
        weights["common"] = max(10, weights["common"] - luck_bonus * 2)
        weights["uncommon"] += luck_bonus
        weights["rare"] += luck_bonus
        weights["epic"] += int(luck_bonus * 0.5)
        weights["legendary"] += int(luck_bonus * 0.25)

func _get_eligible_items(player: Player, rarity: String) -> Array[String]:
    var all_items = MetaProgression.get_unlocked_items("items")

    return all_items.filter(func(item_id):
        var item_def = ItemManager.get_definition(item_id)

        # Must match rarity
        if item_def.rarity != rarity:
            return false

        # Check if player can still acquire (stack limit or binary)
        if item_def.has_stack_limit:
            var current_stack = player.item_stacks.get(item_id, 0)
            return current_stack < item_def.stack_limit
        else:
            # Binary item - only drop if not owned
            return not player.has_item(item_id)
    )

func _roll_item_rarity(chest_type: String) -> String:
    var weights = CHEST_RARITY_WEIGHTS.get(chest_type, {})
    var total_weight = 0
    for rarity in weights:
        total_weight += weights[rarity]

    var roll = RNG.stream("loot").randi_range(0, total_weight - 1)
    var cumulative = 0

    for rarity in weights:
        cumulative += weights[rarity]
        if roll < cumulative:
            return rarity

    return "common"  # Fallback

func _get_random_rarity_for_visual() -> String:
    # For slot machine visual cycling (not the actual roll)
    var rarities = ["common", "uncommon", "rare", "epic", "legendary"]
    return rarities.pick_random()

func _get_random_item(player: Player, rarity: String) -> BaseItem:
    var eligible_items = _get_eligible_items(player, rarity)
    if eligible_items.is_empty():
        return null

    var item_id = eligible_items.pick_random()
    return ItemManager.get_definition(item_id)
```

**Gold Economy Integration (No Visual Drops):**
```gdscript
# Player.gd - Gold tracking with kill streak display
var gold: int = 0
var gold_streak_active: bool = false
var gold_streak_timer: float = 0.0
var gold_streak_amount: int = 0
const GOLD_STREAK_TIMEOUT: float = 2.0  # 2 seconds without kill = streak ends

@onready var gold_streak_label: Label = $GoldStreakLabel  # Floating label near character

func _ready() -> void:
    EventBus.enemy_killed.connect(_on_enemy_killed)
    gold_streak_label.visible = false

func _process(delta: float) -> void:
    if gold_streak_active:
        gold_streak_timer -= delta

        if gold_streak_timer <= 0.0:
            # Streak ended
            _end_gold_streak()

func _on_enemy_killed(enemy_id: String, position: Vector2) -> void:
    # Get gold value from enemy type
    var enemy_type = EnemyManager.get_type(enemy_id)
    var gold_amount = enemy_type.gold_value  # Defined in enemy data

    # ❌ NO VISUAL GOLD DROP - Just accumulate in counter
    gold += gold_amount
    EventBus.gold_gained.emit(gold_amount, "enemy_kill")

    # Update streak
    if gold_streak_active:
        # Continue streak
        gold_streak_amount += gold_amount
        gold_streak_timer = GOLD_STREAK_TIMEOUT  # Reset timer
        _update_streak_label()
    else:
        # Start new streak
        _start_gold_streak(gold_amount)

    # Update top HUD counter
    UI.update_gold_display(gold)

func _start_gold_streak(initial_amount: int) -> void:
    gold_streak_active = true
    gold_streak_amount = initial_amount
    gold_streak_timer = GOLD_STREAK_TIMEOUT

    gold_streak_label.visible = true
    _update_streak_label()

    Logger.debug("Gold streak started: %d" % initial_amount, "economy")

func _update_streak_label() -> void:
    # Real-time updating label next to character
    gold_streak_label.text = "+%dg" % gold_streak_amount

    # Color feedback based on streak size
    if gold_streak_amount > 100:
        gold_streak_label.modulate = Color.GOLD  # Big streak!
    elif gold_streak_amount > 50:
        gold_streak_label.modulate = Color.YELLOW
    else:
        gold_streak_label.modulate = Color.WHITE

    # Keep label positioned near player
    gold_streak_label.position = Vector2(0, -60)  # Above player

func _end_gold_streak() -> void:
    gold_streak_active = false
    gold_streak_label.visible = false

    Logger.debug("Gold streak ended: %d total" % gold_streak_amount, "economy")

    # Optional: Show final streak amount popup
    if gold_streak_amount > 50:
        UI.show_streak_end_popup(gold_streak_amount)

# ----

# EnemyType.gd enhancement
@export var gold_value: int = 5  # Default 5 gold per enemy

# Example enemy gold values (tunable):
# - Small enemies (grunts): 5 gold
# - Medium enemies: 10-15 gold
# - Elite enemies: 25-40 gold
# - Bosses: 100-300 gold
```

**Chest Spawning Patterns:**
```gdscript
# Pre-placed chests (map design)
# - Designer places chest nodes in arena scene
# - Chests spawn at wave start or specific triggers
# - Strategic placement (corners, behind obstacles, etc.)

# Event-spawned chests (dynamic)
func on_wave_complete(wave_num: int) -> void:
    # Spawn chest reward for completing wave
    if wave_num % 3 == 0:  # Every 3 waves
        var chest_type = _determine_chest_type(wave_num)
        var spawn_pos = _get_safe_spawn_position()
        ChestManager.spawn_chest(chest_type, spawn_pos)

        UI.show_notification("Chest spawned!")

func _determine_chest_type(wave_num: int) -> String:
    if wave_num >= 30: return "legendary"
    if wave_num >= 20: return "epic"
    if wave_num >= 10: return "rare"
    return "common"

# Boss kill rewards
func on_boss_killed(boss_id: String, position: Vector2) -> void:
    # Guarantee legendary chest from boss
    ChestManager.spawn_chest("legendary", position)
```

**Item Acquisition Sources:**
- **Purchasable Chests**: All identical, cost scales with tier/wave (no choice paralysis)
- **Free Chests (5% chance)**: Spawn already-opened, no cost, better rarity odds (+10 luck!)
- **Gold Economy**: Enemies drop gold (no visual pickups, auto-accumulated)
- **Kill Streak Display**: Real-time "+Xg" counter near player during streaks
- **Wave Rewards**: Chests spawn every N waves
- **Boss Rewards**: Guaranteed chest on boss kill
- **Future Expansion**: Gold can also buy shrines, rerolls, temporary buffs

**Chest Opening Experience (Slot Machine):**
1. **Interact** → Deduct gold (or FREE if already open)
2. **Lid opens** → Animation (skipped if free chest)
3. **Slot machine** → 2 seconds of fast rarity cycling with escalating sounds
4. **Climax** → Slow down, reveal actual rarity (BIG sound effect)
5. **Item rises** → Visual floats up from chest
6. **Result popup** → Show item details + stats
7. **No player choice** → Fully automated spectacle (pure dopamine)

**Gold Streak System:**
- **No visual drops**: Gold auto-accumulated in top-right HUD counter
- **Streak display**: Floating "+50g" label next to player during active kills
- **Color tiers**: White (0-50g) → Yellow (50-100g) → Gold (100g+)
- **2 second timeout**: Streak ends if no kill for 2 seconds
- **Streak end popup**: Show total earned if streak > 50g
- **Encourages aggression**: Rewards continuous kills

**Design Benefits:**
- **Slot machine excitement**: Anticipation → visual roll → climax reveal (peak dopamine)
- **Luck stat integration**: Items that boost luck directly improve chest outcomes
- **No choice paralysis**: All chests identical (no "wrong choice" regret)
- **Free chest hype**: 5% chance creates surprise excitement moments
- **Free chests = better odds**: +10 luck bonus rewards finding free chests
- **Scalable economy**: Chest costs increase with tier/wave (always relevant)
- **Skill expression**: Better players earn more gold via kill streaks
- **Visual clarity**: No gold clutter, clean arena, clear HUD
- **Streak gameplay**: Encourages aggressive play to maintain momentum

**Toggler System (Pre-Run Customization):**
```gdscript
# Unlocked after 40 items in category
if MetaProgression.get_unlocked_items("skills").size() >= 40:
    MetaProgression.enable_toggler("skills")

# Player disables items before run (in hideout/menu)
MetaProgression.toggle_item("skills", "banana_throw", false)  # Won't appear in run
MetaProgression.toggle_item("items", "projectile_count", false)  # Won't appear
```

**Unlock Flow (Quest Integration from 3_PROGRESSION_quest_system_backend.md):**
```gdscript
# Quest System Backend (QuestManager.gd) awards rewards upon completion
# Two reward types: reward_discover (shop) and reward_unlocks (instant)

# QuestManager detects objective completion
func _check_quest_completion(quest: QuestConfig) -> void:
    if quest.objective_met():
        _award_quest_rewards(quest)

# Award rewards through MetaProgression
func _award_quest_rewards(quest: QuestConfig) -> void:
    # Award Rift Fragments (currency for purchases)
    MetaProgression.earn_rift_fragments(quest.reward_rift_fragments)

    # Discovery rewards → Item appears in shop (requires purchase)
    for item_id in quest.reward_discover:
        MetaProgression.discover_item(_get_category(item_id), item_id)

    # Instant unlock rewards → Skip shop, directly available
    for item_id in quest.reward_unlocks:
        MetaProgression.unlock_item(_get_category(item_id), item_id)

    quest_progress[quest.quest_id].completed = true
    EventBus.quest_completed.emit(quest.quest_id, _get_reward_summary(quest))

# UnlockShop.gd displays discovered vs unlocked items
func _refresh_shop_display() -> void:
    for item_id in ContentDB.get_all_items():
        var is_unlocked = MetaProgression.is_item_unlocked("items", item_id)
        var is_discovered = MetaProgression.is_item_discovered("items", item_id)

        if is_unlocked:
            _display_as_owned(item_id)  # Colored icon, "Owned" badge
        elif is_discovered:
            _display_as_available(item_id)  # Grey icon, shows cost
        else:
            _display_as_locked(item_id)  # Hidden or "???"

# Player purchases in shop UI
func _on_purchase_button_pressed(item_id: String, cost: int) -> void:
    if MetaProgression.can_afford(cost):
        MetaProgression.spend_rift_fragments(cost)
        MetaProgression.unlock_item("items", item_id)  # Now available in runs
```

**Quest Reward Strategy Examples:**
```gdscript
# Early quests: Instant unlocks (skip shop, reward milestone)
QuestConfig.new()
    quest_id = "first_blood"
    objective = "Kill 1 enemy"
    reward_rift_fragments = 10
    reward_unlocks = ["cheese"]  # ← Instant unlock, available immediately

# Mid-game quests: Discovery rewards (must purchase)
QuestConfig.new()
    quest_id = "slayer"
    objective = "Kill 500 enemies"
    reward_rift_fragments = 50
    reward_discover = ["lucky_coin"]  # ← Appears in shop (100 fragments to buy)

# Advanced quests: Hybrid rewards (both types)
QuestConfig.new()
    quest_id = "boss_killer"
    objective = "Kill first boss"
    reward_rift_fragments = 75
    reward_discover = ["damage_tome_tier2"]  # Expensive shop item
    reward_unlocks = ["damage_tome_tier1"]   # Free unlock as milestone
```

**Progression Flow (Quest → Shop → Run):**
```
1. Player starts with DEFAULT unlocked items/abilities
   ↓
2. Quest completes (tracked via SessionState → QuestManager)
   ↓
3a. reward_unlocks → MetaProgression.unlock_item() → Instantly available
3b. reward_discover → MetaProgression.discover_item() → Appears in shop
   ↓
4. Player earns Rift Fragments from quest rewards + run performance
   ↓
5. Visit UnlockShop.gd → See discovered items (grey, shows cost)
   ↓
6. Purchase with Rift Fragments → MetaProgression.unlock_item()
   ↓
7. Next run: SessionState.start_run() → Queries MetaProgression.get_unlocked_items()
   ↓
8. New items appear in upgrade pool during run
```

**Initial Player Experience:**
- Start with default abilities/items/tomes (already unlocked)
- Play runs, earn Rift Fragments, complete quests naturally
- After run: visit shop, see newly discovered items
- Purchase with Rift Fragments to expand pool
- Next run: new items appear in upgrade options

**Quest Types:**
- **Automatic/Passive:** "Deal 10,000 damage" → completes naturally while playing
- **Specific:** "Defeat boss with Fireball ability at level 10" → targeted challenge
- Both types discover new items for shop purchase

**Terminology Decision (FINAL):**

After reviewing quest system integration, the current terminology is **ideal** and should be kept:

✅ **"Discovered"** = Item visible in shop, requires purchase
- Makes sense for quest rewards: "Quest complete → item discovered"
- Familiar to roguelike players (Hades, Dead Cells, Binding of Isaac)
- Already implemented in UnlockShop.gd (no refactor needed)
- Clear progression: discovered → purchase → unlocked

✅ **"Unlocked"** = Item owned, available in runs
- Standard game terminology (universally understood)
- Clear final state: unlocked items appear in run pools
- Works for both shop purchases AND instant quest rewards

✅ **Quest rewards use both:**
- `reward_discover` → Quest adds item to shop (must buy with Rift Fragments)
- `reward_unlocks` → Quest gives instant unlock (skips shop, milestone reward)
- Flexible reward design (early quests instant, late quests shop-based)

**Alternative considered:** Rename "discover" to "unlock in shop" or "available for purchase"
- ❌ More verbose, less elegant
- ❌ Breaks existing UnlockShop.gd implementation
- ❌ Unfamiliar to roguelike players
- ❌ No clear benefit over current terminology

**Recommendation:** Keep current MetaProgression API unchanged. Quest system integrates perfectly with existing discover/unlock flow.

**Future Tome Design Considerations:**
- Tomes may have different application timing than items
- May affect multiple systems simultaneously (XP + Damage + Projectiles)
- Ability system should be extensible to support tome interactions
- Tag system must support tome-to-ability connections
- Example: "Tome of Fire" → All abilities gain "fire" tag + burning effect

**Architecture Extensibility:**
All three systems share:
- MetaProgression unlock state (discover → unlock flow)
- Tag-based applicability checking
- Toggler filtering support
- Quest-based unlock triggers (via QuestManager)
- Discovery-to-unlock progression (quest rewards → shop → runs)

---

#### ✅ ANSWERED - Question 16: Ability Data Hot-Reloading

**Decision: In-game Ability Debug Panel** (integrated with existing DebugPanel)

**Rationale:**
- Better UX than hot keys (Shift+F5 requires memorization, panels are visual)
- Immediate feedback loop: Edit → Save → Test (no restart)
- Matches existing debug panel architecture
- Professional game dev workflow (Hades, Dead Cells use similar tools)

**Implementation:**
See detailed design: [Ability Debug Panel Design](ability-debug-panel-design.md)

**Summary:**
```gdscript
// Tabbed interface added to existing DebugPanel.gd
[Enemy Spawn] [Abilities] [Cheats] ← Tab system

// Abilities tab has two columns:
LEFT COLUMN: Ability Editor
├─ Dropdown: Select ability to edit
├─ Editable fields: damage, cooldown, projectile_count, etc.
├─ [Save to File] → Writes to .tres file (ResourceSaver)
└─ [Apply to Equipped] → Instant update to player's equipped abilities

RIGHT COLUMN: Slot Equipment
├─ 4 slot dropdowns (select ability per slot)
├─ [Equip Selected Abilities] → Assigns to Player.ability_slots[]
├─ Current Equipped display (shows level, stats)
└─ Testing Actions: Level Up, Clear All, Refresh
```

**Designer Workflow:**
```
1. Press F3 (open debug panel)
2. Click "Abilities" tab
3. Select ability from dropdown
4. Edit damage/cooldown/projectile_count
5. Click "Save to File" (writes to fireball.tres)
6. Click "Apply to Equipped" (instant update if equipped)
7. Test in-game (see changes immediately)
```

**Iteration Time:** ~5 seconds (edit → save → test)
- ✅ No game restart
- ✅ No Shift+F5 memorization
- ✅ No external file editor
- ✅ Visual feedback (see current equipped abilities)

**Why This is Better Than Hot Keys:**
- Dropdowns for browsing all abilities (discoverability)
- Visual feedback (current values, equipped status)
- Slot management (equip/unequip for testing)
- One-click save + apply workflow
- Testing actions (level up, clear, refresh)

---

#### ✅ ANSWERED - Question 17: Damage System Integration

**Decision: Abilities call central DamageService + use existing EventBus signals**

**Rationale:**
- Existing codebase has well-established damage pipeline (DamageService → EventBus signals)
- Consistency with melee system (all damage flows through same central system)
- SessionState auto-tracks ability damage via EventBus.damage_dealt signal
- Future-proof for modifiers (crit, resistance, shields, damage reduction)
- Unified logging and debugging

**Implementation Pattern:**
```gdscript
// Ability Activation → Spawn projectile with damage data
func activate(player: Node2D, context: Dictionary) -> void:
    var projectile_data = {
        "damage": base_damage,
        "ability_id": ability_id,
        "tags": tags  // ["projectile", "fire"]
    }
    ProjectileManager.spawn_projectile(visual_scene, projectile_data, player.position)

// Projectile Collision → Call DamageService
func _on_enemy_hit(enemy_id: String) -> void:
    DamageService.apply_damage(
        enemy_id,         // Target entity
        damage,           // Amount
        ability_id,       // Source (for tracking)
        damage_tags       // ["projectile", "fire"]
    )
    // DamageService automatically emits EventBus.damage_applied signal
    queue_free()

// SessionState tracks ability damage (existing autoload)
func _on_damage_dealt(payload: EventBus.DamageDealtPayload_Type) -> void:
    damage_dealt += payload.damage_amount

    // Track per-ability breakdown
    var ability_id = payload.source
    ability_damage_breakdown[ability_id] += payload.damage_amount
    // End-of-run stats: "Fireball dealt 5000 damage"
```

**Architecture Flow:**
```
Ability activates → Spawn projectile/effect
    ↓
Projectile collides → Call DamageService.apply_damage()
    ↓
DamageService (central system):
├─ Updates entity HP
├─ Emits EventBus.damage_applied (UI/VFX)
├─ Emits EventBus.damage_dealt (session tracking)
└─ Handles death if HP <= 0
    ↓
SessionState listens → Tracks ability damage breakdown
```

**Abilities Must:**
- ✅ Call `DamageService.apply_damage()` on collision
- ✅ Use existing EventBus signals (damage_applied, damage_dealt)
- ❌ **NOT** apply damage directly to enemy HP
- ❌ **NOT** create custom damage signals

**Benefits:**
- Consistent with existing melee system
- Auto-tracked by SessionState for end-of-run stats
- Easy to add modifiers (crit multipliers, resistance, shields)
- Unified damage logging for debugging

---

### Data Structure Questions

#### ✅ ANSWERED - Question 18: Ability Resource File Structure

**Decision: One .tres file per ability, organized in category folders, loaded via `ResourceLoader.load()` at runtime**

**Rationale:**
- Individual files → Hot-reload works per-file (edit fireball.tres, only fireball reloads)
- Version control → Cleaner git diffs, no merge conflicts
- Scalability → Add 100 abilities, code stays same
- Content-driven → Designers add .tres files, no code changes needed
- Godot compiles into .pck for exported builds (works identically in dev and Steam release)

**Folder Structure:**
```
data/content/abilities/
├── projectile/
│   ├── fireball.tres
│   ├── ice_shard.tres
│   ├── lightning_bolt.tres
│   ├── poison_arrow.tres
│   └── banana_throw.tres
│
├── buff/
│   ├── speed_boost.tres
│   ├── damage_aura.tres
│   └── regeneration.tres
│
├── aoe/
│   ├── meteor_strike.tres
│   ├── flame_circle.tres
│   └── frost_nova.tres
│
├── radial/
│   ├── spinning_blades.tres
│   └── orbital_shields.tres
│
└── celestial/
    ├── comet_rain.tres
    └── star_fall.tres
```

**Example .tres File:**
```tres
[gd_resource type="Resource" script_class="ProjectileAbility" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/systems/abilities/ProjectileAbility.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/abilities/projectiles/fireball_visual.tscn" id="2"]

[resource]
script = ExtResource("1")
ability_id = "fireball"
ability_name = "Fireball"
ability_level = 1
max_level = 20
tags = PackedStringArray("projectile", "damage", "fire", "cooldown")

base_damage = 25.0
cooldown = 1.5
projectile_count = 1
projectile_speed = 400.0
pierce_count = 0

visual_scene = ExtResource("2")
```

**Loading Pattern:**
```gdscript
// AbilityManager.gd - Works in BOTH development and exported builds
func _load_all_abilities() -> void:
    var categories = ["projectile", "buff", "aoe", "radial", "celestial"]

    for category in categories:
        var category_path = "res://data/content/abilities/" + category + "/"
        var dir = DirAccess.open(category_path)

        if not dir:
            Logger.warn("Ability category not found: %s" % category, "abilities")
            continue

        dir.list_dir_begin()
        var file_name = dir.get_next()

        while file_name != "":
            if file_name.ends_with(".tres"):
                var full_path = category_path + file_name
                var ability = ResourceLoader.load(full_path) as BaseAbility
                _ability_registry[ability.ability_id] = ability
                _ability_file_paths[ability.ability_id] = full_path
                _ability_categories[ability.ability_id] = category
            file_name = dir.get_next()

        dir.list_dir_end()

    Logger.info("Loaded %d abilities across %d categories" %
               [_ability_registry.size(), categories.size()], "abilities")
```

**Development vs Exported Build:**
```
// Development:
ResourceLoader.load("res://data/content/abilities/projectile/fireball.tres")
→ Reads text file from disk (~2-5ms per file)
→ Hot-reload works (Godot watches file changes)

// Exported Build (Steam):
ResourceLoader.load("res://data/content/abilities/projectile/fireball.tres")
→ Reads binary blob from .pck archive (~0.1-0.5ms per file)
→ Folder structure preserved in .pck
→ Code unchanged, Godot handles difference automatically
```

**File Naming Convention:**
- `ability_id` = filename (without extension)
- `ability_name` = Human-readable display name
- Example: `fireball.tres` → ability_id: "fireball", ability_name: "Fireball"

**Why NOT Grouped Files:**
- ❌ Hot-reload reloads ALL abilities in file (slower iteration)
- ❌ Merge conflicts when multiple designers edit same file
- ❌ Harder to delete individual abilities (must edit file)
- ❌ Version control diffs show entire file changed

**Benefits:**
- ✅ Hot-reload per ability (fast iteration)
- ✅ Clean git diffs (one ability changed = one file diff)
- ✅ Easy to add/remove abilities (add/delete .tres file)
- ✅ Debug panel integration (dropdown with categories)
- ✅ Consistent with existing enemy template pattern

---

#### ✅ ANSWERED - Question 19: Ability Variants vs Elemental Modifiers

**Decision: Separate .tres files for distinct abilities + Elemental conversion via power-ups/modifiers**

**Rationale:**
- **Distinct abilities** = Fundamentally different gameplay (Fireball vs Lightning Bolt vs Ice Shard)
- **Elemental conversion** = Power-ups modify existing abilities (Ranger Arrow + Fire Modifier = Fire Arrow)
- Follows PoE model: Some abilities have inherent elements, power-ups convert damage types
- Centralized elemental effect application (one fire effect system, not per-ability)

**Two Types of Variants:**

**Type 1: Distinct Abilities (Separate Files)**
```
data/content/abilities/projectile/
├── fireball.tres              ← Always fire damage (inherent)
├── ice_shard.tres             ← Always ice damage (inherent)
├── lightning_bolt.tres        ← Always lightning damage (inherent)
├── poison_dart.tres           ← Always poison damage (inherent)
└── ranger_arrow.tres          ← Physical damage (convertible via power-ups)
```

**Example - Fireball (Inherent Element):**
```tres
// fireball.tres - ALWAYS fire, cannot be converted
ability_id = "fireball"
ability_name = "Fireball"
tags = PackedStringArray("projectile", "damage", "fire", "cooldown")
inherent_element = "fire"  // Cannot be converted by power-ups

base_damage = 25.0
damage_type = "fire"  // Always fire
```

**Type 2: Elemental Conversion (Power-Up System)**
```
data/content/power-ups/elemental/
├── fire_conversion.tres       ← Converts all damage to fire
├── ice_conversion.tres        ← Converts all damage to ice
├── poison_conversion.tres     ← Converts all damage to poison
└── lightning_conversion.tres  ← Converts all damage to lightning
```

**Example - Fire Conversion Power-Up:**
```tres
// fire_conversion.tres
powerup_id = "fire_conversion"
powerup_name = "Flame Infusion"
tags = PackedStringArray("elemental", "conversion", "fire")
stack_limit = 1  // Only one elemental conversion at a time

effect_type = "elemental_conversion"
target_element = "fire"
conversion_percent = 100  // 100% of damage converted to fire

// Applies to ALL abilities with "damage" tag that DON'T have inherent_element
applies_to_tags = ["damage"]
excludes_inherent_elements = true  // Skip abilities with inherent_element set
```

**Elemental Modifier Application Pattern:**

```gdscript
// Player.gd - Apply elemental conversion to abilities
func add_powerup(powerup: BasePowerUp) -> void:
    active_powerups.append(powerup)

    # Apply to all existing abilities
    for ability in ability_slots:
        if ability:
            _apply_powerup_to_ability(powerup, ability)

func _apply_powerup_to_ability(powerup: BasePowerUp, ability: BaseAbility) -> void:
    # Check if power-up applies to this ability
    if not powerup.can_apply_to(ability):
        return

    # Elemental conversion (if no inherent element)
    if powerup.effect_type == "elemental_conversion":
        if not ability.has_inherent_element():
            ability.damage_type = powerup.target_element
            ability.add_tag(powerup.target_element)  // Add "fire" tag
            Logger.info("Converted %s to %s damage" %
                       [ability.ability_name, powerup.target_element], "abilities")
```

**Centralized Elemental Effect System:**

```gdscript
// ElementalEffectManager.gd (autoload or system)
const FIRE_IMPACT = preload("res://scenes/abilities/impacts/fire_explosion.tscn")
const ICE_IMPACT = preload("res://scenes/abilities/impacts/ice_shatter.tscn")
const POISON_IMPACT = preload("res://scenes/abilities/impacts/poison_cloud.tscn")
const LIGHTNING_IMPACT = preload("res://scenes/abilities/impacts/lightning_strike.tscn")

func apply_elemental_effect(element: String, position: Vector2) -> void:
    match element:
        "fire":
            _spawn_effect(FIRE_IMPACT, position)
            _apply_burning_dot(position)
        "ice":
            _spawn_effect(ICE_IMPACT, position)
            _apply_slow_effect(position)
        "poison":
            _spawn_effect(POISON_IMPACT, position)
            _apply_poison_dot(position)
        "lightning":
            _spawn_effect(LIGHTNING_IMPACT, position)
            _apply_chain_lightning(position)

// Projectile collision calls this
func _on_enemy_hit(enemy_id: String) -> void:
    DamageService.apply_damage(enemy_id, damage, ability_id, damage_tags)

    # Apply elemental effect based on current damage type
    if damage_type != "physical":
        ElementalEffectManager.apply_elemental_effect(damage_type, global_position)
```

**Example Player Progression:**

```
1. Player starts with "Ranger Arrow" (physical damage)
   ├─ Tags: ["projectile", "damage", "physical", "cooldown"]
   └─ damage_type: "physical"

2. Player acquires "Flame Infusion" power-up
   ├─ Ranger Arrow → Fire Arrow (converted)
   ├─ Tags: ["projectile", "damage", "fire", "cooldown"]  // "fire" added, "physical" removed
   └─ damage_type: "fire"
   └─ Projectile now spawns fire_explosion on hit

3. Player levels up "Fireball" ability
   ├─ Fireball stays fire (has inherent_element)
   ├─ Flame Infusion does NOT affect it (already fire)
   └─ Both abilities now deal fire damage

4. Player acquires second "Fireball" from card selection
   ├─ Cannot acquire (already have Fireball in slot)
   └─ Auto-levels Fireball instead (+1 level)
```

**Asset Sharing (Centralized Elemental Effects):**

```
scenes/abilities/impacts/
├── fire_explosion.tscn         ← Used by ANY fire ability
├── ice_shatter.tscn            ← Used by ANY ice ability
├── poison_cloud.tscn           ← Used by ANY poison ability
└── lightning_strike.tscn       ← Used by ANY lightning ability

scenes/abilities/trails/
├── fire_trail.tscn             ← Used by ANY fire projectile
├── ice_trail.tscn              ← Used by ANY ice projectile
└── poison_trail.tscn           ← Used by ANY poison projectile
```

**Benefits:**
- ✅ **Distinct abilities** have clear identity (Fireball, Lightning Bolt, Ice Shard)
- ✅ **Convertible abilities** can be modified (Ranger Arrow → Fire Arrow via power-up)
- ✅ **Centralized effects** (one fire explosion, not per-ability)
- ✅ **Power-up flexibility** (any ability can gain elements if not inherent)
- ✅ **Clear design rules** (inherent_element = cannot convert, no inherent_element = convertible)

**Design Rule:**
- **Themed abilities** (Fireball, Ice Shard) → `inherent_element` set → Always that element
- **Generic abilities** (Ranger Arrow, Magic Missile) → No `inherent_element` → Convertible via power-ups
- **Elemental effects** → Centralized system (ElementalEffectManager) → Shared across all abilities

---

#### ✅ ANSWERED - Question 20: Unlock Configuration

**Decision: Unlock requirements managed by Quest system, NOT in ability files**

**Rationale:**
- Separation of concerns: Ability = gameplay stats, Quest = unlock progression
- Already covered in Q15 (MetaProgression + Quest integration)
- Abilities are "dumb data" - they don't know how they're unlocked
- Quest system controls via `reward_discover` and `reward_unlocks` arrays

**Implementation:**

```gdscript
// Ability file (NO unlock requirements - pure gameplay data)
// fireball.tres
ability_id = "fireball"
ability_name = "Fireball"
base_damage = 25.0
cooldown = 1.5
tags = ["projectile", "damage", "fire"]
// ... gameplay stats only, NO unlock_cost or unlock_quest

// Quest file (HAS unlock requirements + rewards)
// first_fire_quest.tres (from Q15)
quest_id = "first_fire_quest"
display_name = "Pyromaniac"
objective_type = "KILL_ENEMIES"
objective_target = 100
objective_cumulative = true  // Across all runs

reward_rift_fragments = 50
reward_discover = ["fireball", "fire_conversion"]  // ← Appears in shop
reward_unlocks = []  // No instant unlocks for this quest

// Player completes quest
QuestManager._award_quest_rewards(quest)
  ↓
MetaProgression.discover_item("skills", "fireball")
  ↓
UnlockShop displays: "Fireball - 100 Rift Fragments"
  ↓
Player purchases → MetaProgression.unlock_item("skills", "fireball")
  ↓
Fireball available in run pools
```

**Why NOT in ability files:**
```gdscript
// ❌ WRONG: Putting unlock requirements in ability file
// fireball.tres (DON'T DO THIS)
ability_id = "fireball"
unlock_quest = "first_fire_quest"  // ❌ Ability shouldn't know this
unlock_cost = 100                  // ❌ This belongs in shop config
```

**Problems with ability-based unlocks:**
- ❌ Tight coupling (ability depends on quest system)
- ❌ Hard to change unlock requirements (must edit ability file)
- ❌ Can't have multiple unlock paths (quest A OR quest B)
- ❌ Quests can't unlock multiple abilities at once

**Quest-based approach benefits:**
- ✅ Quests can unlock multiple abilities (`reward_discover = ["fireball", "ice_shard"]`)
- ✅ Multiple quests can unlock same ability (different progression paths)
- ✅ Easy to adjust unlock requirements (edit quest file, not ability file)
- ✅ Abilities remain pure gameplay data (no progression logic)

**See Question 15 for complete quest integration details.**

---

### Performance Questions

#### ✅ ANSWERED - Question 21: Object Pooling for Ability Instances?

**Decision: NO pooling for ability instances, YES pooling for projectile/effect entities**

**Rationale:**
- **Ability instances** = 4 per player, lightweight Resource data → No pooling needed
- **Projectile entities** = Hundreds active → Already have object pools (existing infrastructure)
- **Visual effects** = Particles, flashes → Use existing particle pools
- Clear separation: Ability data (persistent) vs spawned entities (pooled)

**Architecture Clarification:**
```gdscript
# Player.gd - Ability instances (NO pooling needed)
var ability_slots: Array[BaseAbility] = [null, null, null, null]  # 4 instances MAX

# Each BaseAbility is a Resource (lightweight data container)
# No need to pool - we only ever have 4 active per player

# ---

# ProjectileAbility.gd - Spawns projectiles from pools
func activate(player: Node2D, context: Dictionary) -> void:
    for i in projectile_count:
        # Get entity from existing object pool
        var projectile = ProjectilePool.acquire(projectile_type)
        projectile.setup(base_damage, projectile_speed, pierce_count)
        projectile.global_position = player.global_position
        projectile.direction = _calculate_direction(i, projectile_count)

        # Pool handles cleanup when projectile expires
```

**Existing Pool Infrastructure (from CLAUDE.md):**
- `/scripts/systems/object_pools/` (if exists) or Arena manages pools
- Already used for enemy entities and projectiles
- MultiMeshInstance2D for rendering optimization

**Memory Profile:**
```
Player ability system:
- 4 ability instances × ~200 bytes each = ~800 bytes (negligible)
- 4 tome instances × ~200 bytes each = ~800 bytes (negligible)
- Item instances: Variable, but typically ~50 items × ~150 bytes = ~7.5 KB

Projectile system (pooled):
- Pool size: ~500-1000 projectiles (configurable)
- Per projectile: ~1-2 KB (Node2D + script state)
- Total pool: ~500 KB - 2 MB (reused)

Conclusion: Pool projectiles, not ability instances.
```

**Benefits:**
- Simple ability lifecycle (create once, modify in-place)
- Existing pool infrastructure handles performance-critical entities
- Clear ownership (Player owns abilities, Arena owns projectile pools)

---

#### ✅ ANSWERED - Question 22: Active Ability Limit Before Performance Issues?

**Decision: 4 abilities per player (design limit), performance not a concern**

**Rationale:**
- Abilities are auto-cast with cooldowns (not constantly activating)
- Hard limit of 4 ability slots prevents performance issues by design
- Real performance cost is spawned entities (projectiles, effects), not ability logic
- 30Hz combat step handles ability cooldown checks efficiently

**Performance Breakdown:**
```gdscript
# Per 30Hz combat step (every ~33ms):
func _on_combat_step(delta: float) -> void:
    _update_ability_cooldowns(delta)  # 4 float subtractions = ~0.001ms
    _auto_cast_ready_abilities()      # Check 4 abilities = ~0.005ms

    # Total ability system overhead: ~0.006ms per step
    # Combat step budget: 33ms → 0.02% of budget

# Real performance cost:
# - Spawning projectiles: ~0.1-0.5ms per projectile (from pools)
# - MultiMesh updates: ~0.05ms per 100 projectiles
# - Collision detection: ~0.5-2ms per frame (Godot physics)
# - Particle effects: ~0.1-1ms depending on count
```

**Scaling Concerns (NOT from abilities themselves):**
- **Projectile count**: Builds with +10 projectile stacks → 11 projectiles per cast
- **Attack speed**: Builds with -50% cooldown → 2x cast frequency
- **Combined**: 11 projectiles × 2x frequency × 4 abilities = ~88 projectiles/second
  - Still manageable with pools + MultiMesh
  - Hard caps prevent runaway scaling (projectile visual cap at 15)

**Monitoring Strategy:**
```gdscript
# Debug tracking (if performance issues arise)
var ability_activation_count: int = 0
var projectile_spawn_count: int = 0

func _on_ability_activated(ability_id: String) -> void:
    ability_activation_count += 1

func _on_combat_step_end() -> void:
    if ability_activation_count > 10:  # More than 10 activations per step
        Logger.warn("High ability activation rate: %d" % ability_activation_count, "performance")

    ability_activation_count = 0
```

**Conclusion:** 4 abilities with cooldowns = no performance concern. Watch spawned entity counts instead.

---

#### ✅ ANSWERED - Question 23: Handling Hundreds of Projectiles?

**Decision: Use existing MultiMesh + object pooling infrastructure with visual/stack caps**

**Rationale:**
- Project already uses MultiMeshInstance2D for high-count rendering (CLAUDE.md confirmed)
- Object pools for entity reuse (avoid GC pressure)
- Hard caps prevent infinite scaling (15 visual projectiles max, 10 stack limit on Tomes)
- Damage scales even when visual count is capped

**Implementation Strategy:**

**1. Visual Cap (from Q8):**
```gdscript
# ProjectileAbility.gd
@export var max_visual_projectiles: int = 15

func activate(player: Node2D, context: Dictionary) -> void:
    var actual_count = projectile_count  # Could be 50+ with Tome stacks
    var visual_count = min(actual_count, max_visual_projectiles)
    var damage_per = base_damage * (float(actual_count) / visual_count)

    for i in visual_count:
        var projectile = ProjectilePool.acquire(projectile_type)
        projectile.setup(damage_per, projectile_speed, pierce_count)
        # Spawn 15 projectiles with 3.33x damage each (if actual_count = 50)
```

**2. MultiMesh Rendering (existing infrastructure):**
```gdscript
# Arena.gd or ProjectileManager.gd (existing system)
# One MultiMeshInstance2D per projectile visual variant
var multimesh_fireball: MultiMeshInstance2D
var multimesh_arrow: MultiMeshInstance2D
var multimesh_ice_shard: MultiMeshInstance2D

func _process(delta: float) -> void:
    # Update transforms for all active projectiles
    _update_multimesh_transforms("fireball", active_fireballs)
    _update_multimesh_transforms("arrow", active_arrows)
    # Single draw call per variant, hundreds of instances

func _update_multimesh_transforms(type: String, projectiles: Array) -> void:
    var mm = _get_multimesh(type)
    mm.instance_count = projectiles.size()

    for i in projectiles.size():
        var transform = Transform2D()
        transform.origin = projectiles[i].position
        transform = transform.rotated(projectiles[i].rotation)
        mm.set_instance_transform_2d(i, transform)
```

**3. Object Pooling (existing infrastructure):**
```gdscript
# ProjectilePool.gd (or similar existing system)
var pool_fireball: Array[Projectile] = []
var pool_arrow: Array[Projectile] = []
var active_fireballs: Array[Projectile] = []

func acquire(type: String) -> Projectile:
    var pool = _get_pool(type)

    if pool.is_empty():
        # Expand pool if needed (rare)
        return _create_new_projectile(type)

    var projectile = pool.pop_back()
    projectile.reset()
    return projectile

func release(projectile: Projectile) -> void:
    projectile.visible = false
    _get_pool(projectile.type).append(projectile)
```

**Performance Targets:**
- **100 projectiles**: Smooth 60 FPS (baseline)
- **300 projectiles**: Smooth 60 FPS (MultiMesh optimized)
- **500+ projectiles**: 45-60 FPS (acceptable for crazy builds)
- **1000+ projectiles**: 30-45 FPS (extreme edge case, visual cap prevents this)

**Preventing Performance Issues:**
- ✅ Hard cap projectile visuals at 15 per ability (damage still scales)
- ✅ Tome stack limits (10 max) prevent +50 projectile builds
- ✅ MultiMesh reduces draw calls (1 per variant vs 1 per projectile)
- ✅ Object pools prevent GC pauses
- ✅ Fixed 30Hz combat step keeps logic predictable

**User Confirmation:** "this multi mesh system is still there and ready to be used"

**Conclusion:** Existing infrastructure handles hundreds of projectiles. Visual/stack caps prevent extreme cases.

### Testing Questions

#### ✅ ANSWERED - Question 24: Testing Ability + Tome Combinations

**⚠️ UPDATED 2025-10-03**: Terminology corrected from "power-ups" to "Tomes" based on architectural clarification

**Decision: Two-tier testing approach (Designer Tool + Automated Tests)**

**User Context:** After architectural clarification, Tomes are the ability buffs (4 slots), Items are broader mechanics.

**1. Designer Testing: Ability Debug Panel Enhancement**

Enhance the Ability Testing Popup (from Q16) with Tome testing capabilities:

```gdscript
// AbilityTestingPopup.gd (enhanced from Q16 design)
extends Window
class_name AbilityTestingPopup

# Existing ability editor (left column)
@onready var ability_dropdown: OptionButton
@onready var damage_spinner: SpinBox
@onready var cooldown_spinner: SpinBox

# NEW: Tome testing section (middle column)
@onready var tome_dropdown: OptionButton
@onready var tome_stack_spinner: SpinBox  # 1-10
@onready var add_tome_btn: Button
@onready var active_tomes_list: VBoxContainer
@onready var clear_tomes_btn: Button

var current_ability: BaseAbility = null
var test_tomes: Dictionary = {}  # {tome_id: stack_count}

func _ready() -> void:
    _populate_tome_dropdown()
    add_tome_btn.pressed.connect(_on_add_tome_pressed)
    clear_tomes_btn.pressed.connect(_on_clear_tomes_pressed)

func _populate_tome_dropdown() -> void:
    tome_dropdown.clear()

    # Load all tome definitions
    var tome_files = DirAccess.get_files_at("res://data/content/tomes/")
    for file in tome_files:
        if file.ends_with(".tres"):
            var tome = ResourceLoader.load("res://data/content/tomes/" + file) as BaseTome
            tome_dropdown.add_item(tome.tome_name, tome_dropdown.item_count)
            tome_dropdown.set_item_metadata(tome_dropdown.item_count - 1, tome.tome_id)

func _on_add_tome_pressed() -> void:
    var selected_idx = tome_dropdown.selected
    if selected_idx == -1:
        return

    var tome_id = tome_dropdown.get_item_metadata(selected_idx) as String
    var stack_count = int(tome_stack_spinner.value)

    # Add or update tome in test set
    test_tomes[tome_id] = stack_count

    # Refresh current ability with all tomes applied
    if current_ability:
        _reapply_all_tomes_to_ability()

    # Update UI list
    _refresh_tome_list()

    Logger.info("Added %s (×%d) to test set" % [tome_id, stack_count], "debug")

func _reapply_all_tomes_to_ability() -> void:
    # Reset ability to base stats (reload from file)
    var ability_file = AbilityManager.get_file_path(current_ability.ability_id)
    current_ability = ResourceLoader.load(ability_file).duplicate(true)

    # Apply ALL test tomes
    for tome_id in test_tomes:
        var tome_def = TomeManager.get_definition(tome_id)
        var stack_count = test_tomes[tome_id]

        # Apply tome stack_count times
        _apply_tome_to_ability(tome_def, current_ability, stack_count)

    # Refresh editor UI with new values
    _refresh_ability_editor()

func _apply_tome_to_ability(tome: BaseTome, ability: BaseAbility, stack_count: int) -> void:
    # Same logic as Player._apply_tome_to_ability (from Q11)
    if not tome.can_apply_to(ability):
        Logger.warn("%s cannot apply to %s (tags mismatch)" %
                   [tome.tome_name, ability.ability_name], "debug")
        return

    # Apply modifiers
    if tome.damage_multiplier != 1.0 and ability.has_tag(AbilityTags.DAMAGE):
        var multiplier = 1.0 + ((tome.damage_multiplier - 1.0) * stack_count)
        ability.base_damage *= multiplier

    if tome.projectile_count_bonus > 0 and ability.has_tag(AbilityTags.PROJECTILE):
        (ability as ProjectileAbility).projectile_count += tome.projectile_count_bonus * stack_count

    if tome.cooldown_reduction != 0.0:
        ability.cooldown *= (1.0 - (tome.cooldown_reduction * stack_count))

func _refresh_tome_list() -> void:
    # Clear existing UI
    for child in active_tomes_list.get_children():
        child.queue_free()

    # Add UI entry for each tome
    for tome_id in test_tomes:
        var tome_def = TomeManager.get_definition(tome_id)
        var stack_count = test_tomes[tome_id]

        var label = Label.new()
        label.text = "%s (×%d)" % [tome_def.tome_name, stack_count]
        active_tomes_list.add_child(label)

func _on_clear_tomes_pressed() -> void:
    test_tomes.clear()
    _refresh_tome_list()

    if current_ability:
        _reapply_all_tomes_to_ability()

func _on_apply_to_equipped_pressed() -> void:
    # Apply current test configuration to actual player
    var player = Arena.get_player()  # Or get_tree().get_first_node_in_group("player")

    # Find ability slot
    var slot = player.find_ability_slot(current_ability.ability_id)
    if slot != -1:
        # Replace with modified instance
        player.ability_slots[slot] = current_ability.duplicate(true)

        Logger.info("Applied modified %s to player slot %d" %
                   [current_ability.ability_name, slot], "debug")
    else:
        Logger.warn("Player doesn't have %s equipped" % current_ability.ability_name, "debug")
```

**UI Layout Enhancement:**
```
┌─────────────────────────────────────────────────────────────────┐
│ Ability Testing                                          [Close] │
├─────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┬──────────────────┬──────────────────────┐ │
│ │ Ability Editor   │ Tome Testing     │ Equipped Slots       │ │
│ │                  │                  │                      │ │
│ │ Ability: [▾]     │ Tome: [▾]        │ Slot 0: Fireball    │ │
│ │ Damage:  [25.0 ] │ Stacks: [1]      │   Level: 5          │ │
│ │ Cooldown:[1.5  ] │ [Add Tome]       │   Damage: 45.2      │ │
│ │ Proj Count: [1 ] │                  │                      │ │
│ │                  │ Active Tomes:    │ Slot 1: Arrow       │ │
│ │ [Save to File]   │ • Fire (+20%)    │   Level: 3          │ │
│ │ [Apply to Equip] │ • Might (×2)     │                      │ │
│ │                  │                  │ [Refresh Slots]     │ │
│ │                  │ [Clear All]      │                      │ │
│ └──────────────────┴──────────────────┴──────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Benefits:**
- Visual, instant feedback (change tome stacks, see damage update)
- Test combinations without restarting game
- One-click apply to live player for in-game testing
- Export test configuration for balance documentation

---

**2. Technical Validation: Isolated Test Scenes**

For automated/reproducible testing, create dedicated test scenes:

```gdscript
// tests/ability_tome_combinations.tscn (with script attached)
extends Node
class_name AbilityTomeCombinationTest

func _ready() -> void:
    print("=== Ability + Tome Combination Tests ===")

    test_damage_multiplier_stacking()
    test_projectile_count_stacking()
    test_cooldown_reduction_stacking()
    test_tag_compatibility()
    test_multiple_tome_interaction()

    print("=== All Tests Passed ===")
    get_tree().quit()

func test_damage_multiplier_stacking() -> void:
    print("\nTest: Damage Multiplier Stacking")

    # Create test ability
    var ability = ProjectileAbility.new()
    ability.ability_id = "test_fireball"
    ability.base_damage = 25.0
    ability.tags = ["projectile", "damage", "fire"]

    # Create tome (+20% damage per stack)
    var tome = BaseTome.new()
    tome.tome_id = "tome_fire"
    tome.damage_multiplier = 1.20
    tome.applicable_tags = ["fire"]

    # Apply 3 stacks
    _apply_tome(tome, ability, 3)

    # Expected: 25.0 * (1 + (0.20 * 3)) = 25.0 * 1.60 = 40.0
    assert(abs(ability.base_damage - 40.0) < 0.01, "Damage should be 40.0, got " + str(ability.base_damage))
    print("✓ 3 stacks of +20% damage: 25.0 → 40.0")

func test_projectile_count_stacking() -> void:
    print("\nTest: Projectile Count Stacking")

    var ability = ProjectileAbility.new()
    ability.projectile_count = 1
    ability.tags = ["projectile"]

    var tome = BaseTome.new()
    tome.projectile_count_bonus = 1
    tome.applicable_tags = ["projectile"]

    _apply_tome(tome, ability, 5)

    assert(ability.projectile_count == 6, "Count should be 6, got " + str(ability.projectile_count))
    print("✓ 5 stacks of +1 projectile: 1 → 6")

func test_multiple_tome_interaction() -> void:
    print("\nTest: Multiple Tome Interaction")

    var ability = ProjectileAbility.new()
    ability.base_damage = 20.0
    ability.projectile_count = 1
    ability.cooldown = 2.0
    ability.tags = ["projectile", "damage", "fire"]

    # Tome 1: +25% damage (2 stacks)
    var tome_damage = BaseTome.new()
    tome_damage.damage_multiplier = 1.25
    tome_damage.applicable_tags = ["damage"]
    _apply_tome(tome_damage, ability, 2)

    # Tome 2: +1 projectile (3 stacks)
    var tome_proj = BaseTome.new()
    tome_proj.projectile_count_bonus = 1
    tome_proj.applicable_tags = ["projectile"]
    _apply_tome(tome_proj, ability, 3)

    # Tome 3: -10% cooldown (1 stack)
    var tome_cd = BaseTome.new()
    tome_cd.cooldown_reduction = 0.10
    tome_cd.applicable_tags = []  # Applies to all
    _apply_tome(tome_cd, ability, 1)

    # Expected:
    # Damage: 20.0 * (1 + 0.25*2) = 20.0 * 1.5 = 30.0
    # Projectiles: 1 + (1*3) = 4
    # Cooldown: 2.0 * (1 - 0.10) = 1.8

    assert(abs(ability.base_damage - 30.0) < 0.01, "Damage mismatch")
    assert(ability.projectile_count == 4, "Projectile count mismatch")
    assert(abs(ability.cooldown - 1.8) < 0.01, "Cooldown mismatch")

    print("✓ Multiple tomes applied correctly")

func _apply_tome(tome: BaseTome, ability: BaseAbility, stack_count: int) -> void:
    # Same logic as Player._apply_tome_to_ability
    if not _can_apply_to(tome, ability):
        return

    if tome.damage_multiplier != 1.0 and ability.has_tag(AbilityTags.DAMAGE):
        var multiplier = 1.0 + ((tome.damage_multiplier - 1.0) * stack_count)
        ability.base_damage *= multiplier

    if tome.projectile_count_bonus > 0 and ability is ProjectileAbility:
        ability.projectile_count += tome.projectile_count_bonus * stack_count

    if tome.cooldown_reduction != 0.0:
        ability.cooldown *= (1.0 - (tome.cooldown_reduction * stack_count))

func _can_apply_to(tome: BaseTome, ability: BaseAbility) -> bool:
    if tome.applicable_tags.is_empty():
        return true  # Applies to all

    for tag in tome.applicable_tags:
        if ability.has_tag(tag):
            return true
    return false
```

**Run Command:**
```bash
"../Godot_v4.4.1-stable_win64_console.exe" --headless tests/ability_tome_combinations.tscn
```

**Benefits:**
- Automated validation (CI/CD integration possible)
- Regression testing (ensure changes don't break formulas)
- Fast iteration (run tests in <1 second)
- Documentation (tests show expected behavior)

---

#### ✅ ANSWERED - Question 25: Validating Damage Calculations with Stat Scaling

**Decision: Monte-Carlo simulation tests + in-game damage logging**

**Rationale:**
- Project already uses Monte-Carlo sims for balance validation (CLAUDE.md)
- Ability system adds new scaling dimension (level + Tomes + Items)
- Need to validate: DPS curves, TTK (time-to-kill), power scaling feels right

**1. Monte-Carlo Simulation Test:**

```gdscript
// tests/ability_dps_validation.tscn (with script attached)
extends Node
class_name AbilityDPSValidation

const SIMULATION_DURATION: float = 30.0  # 30 seconds of combat
const SAMPLE_SIZE: int = 100  # Run 100 simulations

func _ready() -> void:
    print("=== Ability DPS Validation ===")

    # Test configuration: Fireball at different levels
    test_fireball_level_scaling()

    # Test configuration: Fireball + Tomes
    test_fireball_with_tomes()

    # Test configuration: Full build (4 abilities + 4 tomes)
    test_full_build_dps()

    print("=== Validation Complete ===")
    get_tree().quit()

func test_fireball_level_scaling() -> void:
    print("\nTest: Fireball DPS Scaling by Level")

    var base_dps = _simulate_ability_dps("fireball", 1, {})  # Level 1, no tomes

    for level in [5, 10, 15, 20]:
        var dps = _simulate_ability_dps("fireball", level, {})
        var scaling_factor = dps / base_dps

        print("Level %d: %.1f DPS (%.1fx base)" % [level, dps, scaling_factor])

        # Validate scaling curve (15% per level from Q12)
        var expected_factor = pow(1.15, level - 1)
        var tolerance = 0.05  # 5% tolerance

        assert(abs(scaling_factor - expected_factor) < tolerance,
               "Level %d scaling outside expected range" % level)

func test_fireball_with_tomes() -> void:
    print("\nTest: Fireball + Tome of Fire DPS")

    var base_dps = _simulate_ability_dps("fireball", 10, {})

    # Tome of Fire: +20% fire damage per stack
    for stacks in [1, 3, 5, 10]:
        var tomes = {"tome_fire": stacks}
        var dps = _simulate_ability_dps("fireball", 10, tomes)
        var increase = ((dps - base_dps) / base_dps) * 100.0

        print("%d stacks: %.1f DPS (+%.1f%%)" % [stacks, dps, increase])

        # Validate: +20% per stack
        var expected_increase = 20.0 * stacks
        assert(abs(increase - expected_increase) < 5.0,
               "%d stacks outside expected range" % stacks)

func _simulate_ability_dps(ability_id: String, level: int, tomes: Dictionary) -> float:
    var total_damage: float = 0.0

    for run in SAMPLE_SIZE:
        # Create ability instance at specified level
        var ability = AbilityManager.create_ability_instance(ability_id)
        ability.level_up(level - 1)  # Level up from 1 to target level

        # Apply tomes
        for tome_id in tomes:
            var tome = TomeManager.get_definition(tome_id)
            var stacks = tomes[tome_id]
            _apply_tome_to_ability(tome, ability, stacks)

        # Simulate combat for duration
        var time: float = 0.0
        while time < SIMULATION_DURATION:
            time += ability.cooldown

            # Calculate damage per activation
            var activation_damage = ability.base_damage

            # Multiply by projectile count (all hit)
            if ability is ProjectileAbility:
                activation_damage *= ability.projectile_count

            total_damage += activation_damage

    # Average across runs
    var avg_damage = total_damage / SAMPLE_SIZE
    return avg_damage / SIMULATION_DURATION  # DPS

func test_full_build_dps() -> void:
    print("\nTest: Full Build DPS (4 abilities + 4 tomes)")

    # Configuration: Endgame build
    var abilities = {
        "fireball": 15,
        "arrow": 12,
        "lightning": 10,
        "shield": 8
    }

    var tomes = {
        "tome_fire": 5,
        "tome_might": 3,
        "tome_haste": 2,
        "tome_precision": 1
    }

    var total_dps: float = 0.0

    # Calculate DPS per ability
    for ability_id in abilities:
        var level = abilities[ability_id]
        var dps = _simulate_ability_dps(ability_id, level, tomes)
        total_dps += dps

        print("  %s (L%d): %.1f DPS" % [ability_id, level, dps])

    print("\nTotal Build DPS: %.1f" % total_dps)

    # Validate: Endgame DPS should be in target range
    # (Requires tuning based on enemy HP/difficulty curves)
    assert(total_dps > 1000.0, "Endgame DPS too low")
    assert(total_dps < 10000.0, "Endgame DPS too high (balance concern)")
```

**2. In-Game Damage Logging:**

```gdscript
// Player.gd enhancement for validation
func _on_ability_activated(ability: BaseAbility) -> void:
    # Log activation for validation
    if OS.is_debug_build() and Logger.is_level_enabled("balance"):
        Logger.debug("Activated %s: dmg=%.1f, cd=%.2f, proj=%d" %
                    [ability.ability_name, ability.base_damage,
                     ability.cooldown, ability.projectile_count], "balance")

// DamageSystem.gd logging (already exists from Q17 integration)
func apply_damage(...) -> void:
    # ... existing damage application ...

    # Log for validation
    if OS.is_debug_build():
        _damage_log.append({
            "ability": ability_id,
            "damage": final_damage,
            "timestamp": Time.get_ticks_msec()
        })

// SessionManager enhancement
func _on_run_end() -> void:
    # Export damage breakdown for validation
    if OS.is_debug_build():
        var stats_file = "user://debug/run_stats_%d.json" % Time.get_unix_time_from_system()
        _export_damage_breakdown(stats_file)

func _export_damage_breakdown(file_path: String) -> void:
    var data = {
        "run_duration": run_duration,
        "total_damage": total_damage,
        "abilities": ability_stats,  # Per-ability breakdown from Q17
        "average_dps": total_damage / run_duration
    }

    var file = FileAccess.open(file_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(data, "  "))
    file.close()

    print("Exported stats to: " + file_path)
```

**Benefits:**
- Automated validation of scaling formulas
- Balance tuning data (DPS curves vs difficulty curves)
- Regression testing (detect formula bugs)
- Designer-friendly output (JSON for spreadsheet import)

---

#### ✅ ANSWERED - Question 26: Simulating Full Build Scenarios for Balance

**Decision: Dedicated balance test scenes + spreadsheet integration**

**Rationale:**
- Need to test combinations: 4 abilities × 4 tomes × items
- Balance requires iteration (adjust, test, repeat)
- Designer-friendly workflow (not just programmer tests)

**1. Balance Test Scene:**

```gdscript
// tests/balance_full_build_sim.tscn (with script attached)
extends Node
class_name BalanceFullBuildSim

# Test configurations (data-driven)
const BUILD_CONFIGS: Array[Dictionary] = [
    {
        "name": "Fire Mage Build",
        "abilities": {"fireball": 15, "flame_circle": 12, "comet_rain": 10, "fire_shield": 8},
        "tomes": {"tome_fire": 5, "tome_haste": 3, "tome_might": 2, "tome_precision": 1},
        "items": ["glass_cannon", "spell_damage_up"]
    },
    {
        "name": "Projectile Spam Build",
        "abilities": {"arrow": 20, "fireball": 15, "ice_shard": 10, "banana_throw": 5},
        "tomes": {"tome_might": 10, "tome_haste": 5, "tome_fire": 2, "tome_ice": 2},
        "items": ["multi_shot", "fast_hands"]
    },
    {
        "name": "Tank Support Build",
        "abilities": {"shield": 15, "heal_aura": 12, "damage_reduction": 10, "slow_enemies": 8},
        "tomes": {"tome_defense": 5, "tome_regen": 5, "tome_aoe": 3, "tome_haste": 2},
        "items": ["hp_boost", "armor_up"]
    }
]

func _ready() -> void:
    print("=== Full Build Balance Simulation ===\n")

    for config in BUILD_CONFIGS:
        simulate_build(config)

    print("\n=== Simulation Complete ===")
    _export_results_to_csv()
    get_tree().quit()

func simulate_build(config: Dictionary) -> void:
    print("Testing: %s" % config.name)

    # Create player with build configuration
    var player = _create_test_player(config)

    # Simulate against standard enemy waves
    var results = _run_simulation(player, 60.0)  # 60 seconds

    # Validate metrics
    _validate_build_balance(config.name, results)

    print("  DPS: %.1f" % results.dps)
    print("  Survivability: %.1f%%" % results.survival_rate)
    print("  Clear Time: %.1fs" % results.average_clear_time)
    print("")

func _create_test_player(config: Dictionary) -> Node:
    # Instantiate player with configured build
    var player = preload("res://scenes/player/Player.tscn").instantiate()

    # Equip abilities
    var slot_idx = 0
    for ability_id in config.abilities:
        var level = config.abilities[ability_id]
        var ability = AbilityManager.create_ability_instance(ability_id)
        ability.level_up(level - 1)
        player.ability_slots[slot_idx] = ability
        slot_idx += 1

    # Equip tomes
    slot_idx = 0
    for tome_id in config.tomes:
        var stacks = config.tomes[tome_id]
        var tome = TomeManager.get_definition(tome_id)
        player.tome_slots[slot_idx] = tome
        player.tome_stacks[slot_idx] = stacks
        slot_idx += 1

        # Apply tomes to abilities
        for ability in player.ability_slots:
            if ability:
                _apply_tome_to_ability(tome, ability, stacks)

    # Apply items
    for item_id in config.items:
        var item = ItemManager.get_definition(item_id)
        player.add_item(item)

    return player

func _run_simulation(player: Node, duration: float) -> Dictionary:
    # Spawn standard enemy wave
    var enemies = _spawn_test_wave()

    var total_damage: float = 0.0
    var time: float = 0.0
    var step: float = 1.0 / 30.0  # 30Hz combat step

    while time < duration:
        # Simulate combat step
        for ability in player.ability_slots:
            if ability and _is_ability_ready(ability, time):
                var damage = _calculate_activation_damage(ability)
                total_damage += damage

        time += step

    return {
        "dps": total_damage / duration,
        "survival_rate": 100.0,  # Placeholder (requires enemy damage sim)
        "average_clear_time": duration / 3  # Placeholder
    }

func _validate_build_balance(build_name: String, results: Dictionary) -> void:
    # Balance validation rules (designer-tunable)
    const TARGET_DPS_MIN: float = 500.0
    const TARGET_DPS_MAX: float = 5000.0

    if results.dps < TARGET_DPS_MIN:
        push_warning("%s: DPS too low (%.1f < %.1f)" %
                    [build_name, results.dps, TARGET_DPS_MIN])

    if results.dps > TARGET_DPS_MAX:
        push_warning("%s: DPS too high (%.1f > %.1f) - Balance concern!" %
                    [build_name, results.dps, TARGET_DPS_MAX])

func _export_results_to_csv() -> void:
    # Export for spreadsheet analysis
    var csv_path = "user://debug/balance_sim_results.csv"
    var file = FileAccess.open(csv_path, FileAccess.WRITE)

    file.store_line("Build Name,DPS,Survival Rate,Clear Time")

    for config in BUILD_CONFIGS:
        # Re-run for export (or cache results)
        var player = _create_test_player(config)
        var results = _run_simulation(player, 60.0)

        file.store_line("%s,%.1f,%.1f,%.1f" %
                       [config.name, results.dps,
                        results.survival_rate, results.average_clear_time])

    file.close()
    print("Exported results to: " + csv_path)
```

**Run Command:**
```bash
"../Godot_v4.4.1-stable_win64_console.exe" --headless tests/balance_full_build_sim.tscn
```

**Output Example:**
```
=== Full Build Balance Simulation ===

Testing: Fire Mage Build
  DPS: 1523.4
  Survival: 87.5%
  Clear Time: 42.3s

Testing: Projectile Spam Build
  DPS: 2341.2
  Survival: 65.2%
  Clear Time: 31.7s

Testing: Tank Support Build
  DPS: 623.8
  Survival: 95.3%
  Clear Time: 68.1s

=== Simulation Complete ===
Exported results to: user://debug/balance_sim_results.csv
```

**2. Spreadsheet Integration:**

```csv
Build Name,DPS,Survival Rate,Clear Time,Notes
Fire Mage Build,1523.4,87.5,42.3,Good balance
Projectile Spam Build,2341.2,65.2,31.7,High DPS but fragile
Tank Support Build,623.8,95.3,68.1,Too slow?
```

Designers can:
- Import CSV into Google Sheets/Excel
- Chart DPS curves, survivability vs clear time
- Identify outliers (builds too strong/weak)
- Adjust ability/tome configs, re-run tests

**Benefits:**
- Rapid iteration (run test, adjust, repeat)
- Data-driven balance (not just gut feeling)
- Catches edge cases (broken combinations)
- Designer-friendly (CSV export, no code needed)

---

## 📁 Related Documentation

**Existing Documents:**
- `/Obsidian/03-tasks/open-tasks/ability-system/2025-09-26_bullet-upgrade-strategy-pattern.md` - Strategy pattern implementation (RELEVANT)
- `/Obsidian/03-tasks/open-tasks/ability-system/` - Other files (REVIEW NEEDED)

**System Documentation to Reference:**
- `/ARCHITECTURE.md` - Project architecture guidelines
- `/CLAUDE.md` - Project working rules
- `/autoload/EventBus.gd` - Signal contracts
- `/scripts/domain/signal_payloads/` - Event payload types

**Related Systems:**
- Quest system (unlock integration)
- Session manager (stats tracking)
- Damage system (damage application)
- Balance system (stat multipliers)

---

## 📊 Next Steps

### Immediate Actions
1. **Q&A Session** - Answer open questions to refine architecture
2. **Review Existing Files** - Determine if other ability-system docs are obsolete
3. **Architecture Document** - Create detailed technical architecture doc
4. **Resource Schema** - Define `.tres` structure for abilities + modifiers
5. **EventBus Updates** - Add required signals for ability system

### Implementation Phases
**Phase 1: Foundation**
- Base ability classes
- Tag system
- Modifier system
- Resource schema

**Phase 2: First Ability**
- Implement one projectile ability end-to-end
- Prove data-driven approach works
- Test with 2-3 modifiers

**Phase 3: Category Expansion**
- Add one ability per category
- Ensure category systems are robust
- Validate LEGO approach

**Phase 4: Integration**
- Quest unlock system
- Session tracking
- UI upgrade selection
- Visual feedback polish

**Phase 5: Content Expansion**
- Add 3-5 abilities per category
- Add 10-15 broad modifiers
- Balance testing
- Fun validation

---

**Status:** ✅ **Q&A COMPLETE - ALL 26 QUESTIONS ANSWERED**
**Created:** 2025-10-03
**Completed:** 2025-10-03
**Next Phase:** Technical architecture document creation + implementation planning

**Critical Updates:**
- **2025-10-03 (Update 1)**: Corrected three-layer system terminology (Items = broad mechanics, Tomes = ability buffs)
- **2025-10-03 (Update 2)**: Clarified acquisition flow (Level-ups = Abilities+Tomes, Chests/Events = Items)
- **2025-10-03 (Update 3)**: Chests are purchasable with gold (not random drops) - gold economy system
- **2025-10-03 (Update 4)**: All chests identical (slot machine feel), 5% spawn free with better odds
- **2025-10-03 (Update 5)**: Gold streak system (no visual drops, real-time counter near player)
- All 26 questions answered with implementation patterns
- Complete slot machine chest system designed (visual roll, luck integration, free chest bonus)
- Kill streak gold display system designed (2s timeout, color tiers, floating label)
- Ready for architecture document and Phase 1 implementation
