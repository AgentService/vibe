# [PRE-TASK] Item System - Design Brainstorming & Decision Making

**Status:** 🟡 In Progress (Design Phase)
**Priority:** High
**Category:** Item System / Architecture
**Estimated Time:** 2-4 hours (discussion + documentation)
**Blocks:** `ITEM-SYSTEM_1_implementation.md`

---

## 📋 Purpose

Finalize architectural decisions for the item system BEFORE implementation. This task captures open questions, explores design alternatives, and documents final decisions to prevent mid-implementation pivots.

**Why This Matters:** The item system interacts with abilities, visuals, combat, and progression. Poor architecture choices now = technical debt later. Better to spend 2 hours planning than 2 weeks refactoring.

---

## 🎯 Objectives

- [ ] Define complete item example catalog (20-30 items)
- [ ] Decide on core architecture (property-based vs strategy pattern vs hybrid)
- [ ] Resolve visual effect application (particle trails, impact visuals)
- [ ] Determine item-ability interaction model
- [ ] Document final decisions with rationale

---

## 📊 Current Item Examples (From Discussion)

### Proc-Based Items
- **Lightning Gloves:** Lightning strike on hit (10s cooldown)
- **Electric Armor:** Electric shock on damage taken
- **Bloodthirst Ring:** 27% chance to apply Bloodmark stack on hit
- **Poison Gloves:** Moldy poison cloud on hit
- **BONK Gloves:** 2% chance to deal 20x damage
- **Explosive Ring:** 25% chance to explode (65% AOE damage)
- **Proc Amplifier:** +1 chance to proc on-hit effects (meta-modifier)

### Stat Bonus Items
- **Health Ring:** +25 Max HP
- **Regeneration Band:** +35 HP Regen
- **Turbo Socks:** +15% Movement Speed
- **Lucky Charm:** +10% free chest chance
- **Frost Gloves:** +7.5% freeze chance on hit
- **Volley Tome:** +1 Projectile Count (note: overlaps with tome system?)

### Conditional Damage Items
- **Executioner's Glove:** +20% damage to enemies >90% HP
- **Elite Hunter Medal:** +15% damage to elites/bosses
- **Curse Amulet:** Curse enemy (30% max HP per second)

---

## 🔍 Open Design Questions

### Question 1: Visual Effect Application

**Problem:** How do items add visual effects to abilities?

**Example:** "Poison Gloves" item should:
- Add green poison particles to ALL ability projectiles
- Spawn poison cloud on impact
- Make impact effect green-tinted

**Options:**

#### Option A: Items Spawn Effects Independently
```gdscript
# Item triggers visual on hit
func _on_damage_dealt(payload):
    if item.on_hit_poison:
        EffectSpawner.spawn_poison_cloud(payload.position)
        # BUT: Projectile still has default visual, no poison trail
```
**Pros:** Simple, items self-contained
**Cons:** Doesn't modify ability visuals (projectiles look the same)

#### Option B: Items Modify Ability Visuals (Query Pattern)
```gdscript
# Ability queries ItemManager when spawning
func spawn_projectile():
    var projectile_data = {...}

    # Query equipped items for visual modifiers
    var visual_mods = ItemManager.get_visual_modifiers()
    if visual_mods.has_poison_trail:
        projectile_data.particle_trail = "poison_trail"
    if visual_mods.has_poison_impact:
        projectile_data.impact_effect = "poison_impact"

    EventBus.ability_projectile_requested.emit(projectile_data)
```
**Pros:** Abilities visually reflect items
**Cons:** Abilities coupled to ItemManager

#### Option C: Hybrid - Functional vs Visual Separation
```gdscript
# Functional effects: ItemManager handles damage/status
# Visual effects: Abilities have default, items spawn extras

# Projectile has default visual
# On impact: ItemManager spawns poison cloud (separate from projectile)
```
**Pros:** Clean separation of concerns
**Cons:** Visuals don't integrate with abilities (feels disjointed)

#### Option D: Strategy Pattern for Visuals Only
```gdscript
# Use ParticleStrategy for visual modifications
class ParticleStrategy:
    particle_trail: PackedScene
    impact_effect: PackedScene
    color_modulation: Color

# Item carries visual strategies
item.visual_strategies = [PoisonParticleStrategy.new()]

# Ability applies visual strategies at spawn
for strategy in ItemManager.get_visual_strategies():
    strategy.apply_to_projectile(projectile)
```
**Pros:** Flexible, reusable, scales well
**Cons:** More complex, strategy pattern overhead

**✅ DECISION MADE: Option A/C Hybrid - Items Spawn Independent Effects**

**Core Principle:** Items don't modify ability visuals. Items trigger their own independent effects.

**Rules:**
1. **Default Behavior:** Items don't add visuals to abilities (fireball stays fire-colored, arrow stays physical)
2. **Specific Items CAN Spawn Effects:**
   - Thunder Mitts: Spawns generic lightning strike visual on impact (item-specific)
   - Moldy Gloves: Spawns generic poison cloud visual on impact (item-specific)
   - Spicy Meatball: Spawns generic explosion visual on impact (works on ALL abilities)
3. **Status Effects (poison/bleed/ignite/cold):** No visuals from items (gameplay only)
4. **AOE Explosions:** If ability already has AOE (like Fireball), item explosion happens ADDITIONALLY (both trigger)
5. **Generic Effect Library:** Lightning, explosion, poison cloud use same visuals regardless of ability

**Technical Implementation:**
- Items spawn effects via EffectSpawner (centralized effect manager)
- Abilities remain unaware of items (no coupling)
- ItemManager listens to EventBus.damage_dealt and triggers item effects
- Effects are generic and reusable (not per-ability customization)

**Future System (NOT Item System):** Ability customization via ROR2-style alternate skills (pre-run or mid-run modification)

**Rationale:**
- Keeps abilities clean and decoupled from items
- Items self-contained (easy to add new items)
- Generic effects reduce art/VFX workload
- Prevents visual clutter from item stacking
- Leaves ability customization to dedicated future system

---

### Question 2: Impact AOE from Items

**Problem:** Items like "Explosive Shard" add AOE explosion to projectiles.

**This is different from visual effects - it changes BEHAVIOR:**
- Projectile with no AOE → now has 200px AOE
- Needs to apply damage to multiple targets
- Needs to spawn explosion visual
- Needs to scale with player stats

**Options:**

#### Option A: Modify Projectile Data at Spawn
```gdscript
# Item modifies ability stats before spawn (like tomes)
func spawn_projectile():
    var projectile_data = {
        "impact_aoe_radius": ability.impact_aoe_radius  # Base: 0
    }

    # Apply item modifiers
    for item in ItemManager.equipped_items:
        if item.adds_impact_aoe:
            projectile_data.impact_aoe_radius += item.aoe_radius_bonus

    EventBus.ability_projectile_requested.emit(projectile_data)
```
**Pros:** Clean, similar to tome system
**Cons:** Abilities need to know about items

#### Option B: Items Trigger AOE Separately
```gdscript
# Projectile hits normally (single target)
# ItemManager detects hit, applies AOE damage separately
func _on_damage_dealt(payload):
    if item.adds_impact_aoe:
        var nearby = EntityTracker.get_entities_in_radius(payload.position, 200)
        for enemy in nearby:
            DamageService.apply_damage(enemy, payload.damage * 0.65)
```
**Pros:** Items self-contained
**Cons:** Weird gameplay (single-target visual, multi-target damage)

#### Option C: Hybrid - Items Set Flags, Abilities Check
```gdscript
# Item sets flag: "player has impact AOE"
# Abilities check flag at spawn time
func spawn_projectile():
    var has_impact_aoe = ItemManager.has_modifier("impact_aoe")
    if has_impact_aoe:
        projectile_data.impact_aoe_radius = 200
```
**Pros:** Abilities in control, items declarative
**Cons:** Abilities need ItemManager dependency

**✅ DECISION MADE: Option A - ItemManager Handles AOE Damage**

**Core Principle:** Items trigger AOE damage independently. Abilities stay single-target, ItemManager applies AOE.

**Rules:**
1. **Damage Scaling:** Item explosions use `payload.damage_amount` as base (includes ability + tome scaling)
2. **Item Properties Scale with Items Only:** Item explosion radius/effects scale with OTHER items, NOT tomes
3. **Tome Boundary:** Tomes only affect abilities (not item procs). Item explosions benefit from tomes INDIRECTLY via payload damage
4. **Independence:** Abilities don't know about item explosions (arrow stays single-target)
5. **Additivity:** If ability already has AOE (Fireball), item explosion happens ADDITIONALLY

**Technical Implementation:**
```gdscript
func _on_damage_dealt(payload):
    // Spicy Meatball: 25% explosion chance
    if item.explosion_chance > 0 and _roll_proc(item.explosion_chance):
        var base_damage = payload.damage_amount  // Includes tome scaling (indirect)

        // Item properties scale with OTHER items only (not tomes)
        var aoe_radius = item.explosion_radius  // Fixed 200px
        var explosion_damage = base_damage * item.explosion_damage_mult  // 0.65

        // Apply item-based modifiers (NOT tome modifiers)
        explosion_damage *= PlayerState.get_item_damage_multiplier()  // Beefy Ring, etc.

        var nearby = EntityTracker.get_entities_in_radius(payload.position, aoe_radius)
        for enemy in nearby:
            DamageService.apply_damage(enemy, explosion_damage)

        EffectSpawner.spawn_explosion(payload.position, aoe_radius)
```

**Example Flow:**
1. Arrow (100 base damage) hits enemy
2. Tome +50% damage applied to arrow → 150 damage
3. Beefy Ring +20% (item) applied to arrow → 180 damage dealt
4. EventBus.damage_dealt.emit(enemy, **180**)
5. Spicy Meatball rolls 25% → SUCCESS
6. Explosion base: 180 * 0.65 = 117 damage
7. Beefy Ring +20% (item) applied to explosion → 140 damage to nearby enemies
8. Explosion radius: 200px (fixed, no tome scaling)

**Rationale:**
- Best practice: Centralized item logic in ItemManager
- Easiest: Abilities unchanged, no coupling
- Performant: Direct damage application, no queries
- Scales naturally: Uses payload damage (includes tome scaling indirectly)
- Clean separation: Tomes affect abilities, items affect items (no cross-contamination)

---

### Question 3: Item vs Tome Boundary

**Problem:** Some items feel like tomes ("+1 projectile count").

**Current Separation:**
- **Tomes:** Modify ability stats at template level (permanent per-ability)
- **Items:** Trigger runtime effects (temporary per-run?)

**Overlap Examples:**
- "+1 Projectile Count" - Tome or Item?
- "+15% Fire Damage" - Tome or Item?
- "+20% AOE Radius" - Tome or Item?

**Options:**

#### Option A: Strict Separation
- **Tomes:** ONLY stat multipliers (damage, cooldown, etc.)
- **Items:** ONLY procs and unique effects
- No overlap allowed

#### Option B: Allow Overlap
- Items CAN have stat bonuses
- Tomes CAN have proc effects
- Use both systems for flexibility

#### Option C: Merge Systems
- Rename "BaseItem" to include tome functionality
- One unified "Modifier" system
- Different item types determine behavior

**✅ DECISION MADE: Option B - Allow Overlap, Generic Bonuses Only**

**Core Principle:** Tomes and items can have overlapping generic effects. No element-specific tomes/items.

**Rules:**
1. **No Element-Specific Modifiers:** No "fire damage" or "cold damage" modifiers (generic "+damage" only)
2. **Overlap Allowed:** Both tomes and items can have "+damage", "+cooldown reduction", "+AOE radius"
3. **Different Acquisition:** Tomes from card selection, items from shops/chests/drops
4. **Stacking:** Tome bonuses stack multiplicatively with item bonuses
5. **Projectile Count Exception:** "+1 Projectile Count" item increases MAX CAP by 1 (not adds to all abilities)

**Stacking Formula:** Not yet defined (additive, diminishing, or multiplicative TBD)

**Examples:**

**Tome Examples (Generic Bonuses):**
- "+20% damage to ALL abilities"
- "-15% cooldown for ALL abilities"
- "+2 pierce for ALL projectile abilities"
- "+30% AOE radius for ALL AOE abilities"

**Item Examples (Generic Bonuses + Procs):**
- Beefy Ring: "+20% damage per 10 max HP" (conditional stat bonus)
- Turbo Socks: "+15% movement speed" (player stat)
- Thunder Mitts: "Lightning strike on hit, 10s cooldown" (proc)
- Magic Quiver: "+1 projectile count MAX CAP" (cap increase)

**Overlap Example:**
```
Player has:
- Tome: +20% damage (from card selection)
- Beefy Ring: +20% damage (from item)

Arrow base damage: 100
After tome: 100 * 1.2 = 120
After item: 120 * 1.2 = 144
Both apply multiplicatively: 44% total increase

Spicy Meatball explosion:
- Uses payload damage (144) ← Includes tome scaling
- Applies item explosion mult: 144 * 0.65 = 93.6
- Applies OTHER item damage bonuses: 93.6 * 1.2 = 112.32
- Does NOT apply tome bonuses again (clean separation)
```

**Rationale:**
- Simplifies design (no element-specific balancing needed)
- Tomes and items complement each other (not redundant - different sources)
- Clear acquisition paths (cards vs equipment drops)
- Stacking creates build diversity
- Projectile count cap prevents abuse
- Clean tome/item separation (tomes affect abilities, items affect items)

---

### Question 4: Item Scaling

**Current Understanding:** "Abilities and items scale with level."

**What does this mean for items?**

**Example:** "Lightning Gloves" (lightning strike on hit, 150% weapon damage)
- Level 1: Lightning does 100 damage
- Level 10: Lightning does ??? damage

**Options:**

#### Option A: Items Scale with Ability Damage
```gdscript
# Item procs use current ability damage as base
var lightning_damage = current_ability_damage * item.lightning_damage_mult
# Level 1: 100 * 1.5 = 150
# Level 10: 400 * 1.5 = 600 (scales naturally)
```

#### Option B: Items Have Independent Scaling
```gdscript
# Item has base damage + per-level multiplier
var lightning_damage = item.base_lightning_damage * (1.15 ^ player_level)
# Level 1: 100 * 1.15^1 = 115
# Level 10: 100 * 1.15^10 = 405
```

#### Option C: Items Use Player Stats
```gdscript
# Item scales with generic "power" stat
var lightning_damage = item.base_damage * PlayerState.power_multiplier
```

**✅ DECISION MADE: Option A - Items Scale with Payload Damage**

**Core Principle:** Item procs use `payload.damage_amount` as their base, scaling automatically with all player progression.

**Rules:**
1. **Automatic Scaling:** Items use actual damage dealt (from payload) as base for proc calculations
2. **No Manual Scaling:** No per-level multipliers or independent scaling curves
3. **Scales with Everything:** Automatically benefits from ability levels, tomes, other items, future systems
4. **Zero Maintenance:** Add new scaling systems without touching item code

**Technical Implementation:**
```gdscript
func _on_damage_dealt(payload):
    // Thunder Mitts: Lightning strike (150% weapon damage)
    if item.on_hit_lightning and _lightning_cooldown <= 0:
        var lightning_damage = payload.damage_amount * item.lightning_damage_mult  // 1.5

        DamageService.apply_damage(nearest_enemy, lightning_damage)
        _lightning_cooldown = item.lightning_cooldown
```

**Example Scaling:**
```
Level 1 Arrow: 100 base damage
- After progression: 100 damage dealt
- Thunder Mitts: 100 * 1.5 = 150 lightning damage

Level 10 Arrow: 100 base damage
- Ability level scaling: 100 * (1.15^10) = 405
- Tome +20%: 405 * 1.2 = 486
- Beefy Ring +20%: 486 * 1.2 = 583 damage dealt
- Thunder Mitts: 583 * 1.5 = 874 lightning damage

Result: Lightning automatically scales from 150 → 874 (5.8× increase)
```

**Rationale:**
- Zero maintenance (no per-item scaling curves)
- Consistent with all other systems (tomes, levels, items all stack naturally)
- Simple implementation (one line: `payload.damage_amount * multiplier`)
- Future-proof (new scaling systems work automatically)
- Balancing is straightforward (multipliers are relative to player power)

---

### Question 5: Performance Budget

**Context:** Players can have 10-50 items with 1-3 procs each.

**Performance Scenarios:**
- **Scenario A:** 10 items, 100 hits/sec = 1,000 checks/sec
- **Scenario B:** 50 items, 200 hits/sec = 10,000 checks/sec
- **Scenario C:** 50 items with 3 procs each = 30,000 checks/sec

**Current Estimates:**
- Property-based: ~0.1ms per frame (500 boolean checks)
- Strategy pattern: ~0.3ms per frame (150 virtual calls)

**Questions:**
- What's the target item count? (10? 50? 100?)
- What's the hit rate? (100/sec? 500/sec?)
- Is 0.3ms acceptable overhead?

**✅ DECISION MADE: Pragmatic Performance Budget**

**Core Principle:** Start with reasonable implementation, optimize if lag occurs.

**Target Specs:**
1. **Max Items:** 50+ items total
2. **Unique Procs:** ~10 unique proc types (rest are stat bonuses or stacking duplicates)
3. **Hit Rate:** 300-500 hits/sec (volley abilities, fast attacks)
4. **Performance Target:** Will optimize if lag occurs (pragmatic approach)

**Performance Reality (Better Than Expected):**
```
50+ items breakdown:
- 10 items with unique procs (lightning, explosion, freeze, etc.)
- 40 items are stat bonuses (HP, damage, movement speed)

Per-hit checks:
- 10 proc items × 15 checks = 150 boolean checks per hit
- Stat bonus items: 0 checks per hit (applied on equip only!)
- At 400 hits/sec: 60,000 checks/sec
- Cost: ~0.05-0.1ms per frame (very acceptable!)
```

**Why This is Better:**
- Stat bonus items don't need per-hit checks (only affect final damage calculation)
- Stacking items increase proc chance (not proc count) - same number of checks
- 10 unique procs << 50 total items

**Optimization Strategy (If Needed):**
1. **Phase 1:** Property-based system (current plan)
2. **If lag occurs:** Profile to find bottleneck
3. **If item checks are slow:** Add early exit conditions (check cooldowns first)
4. **If still slow:** Separate active procs from passive items (only check active list)

**Rationale:**
- Pragmatic approach (build first, optimize if needed)
- Realistic estimate shows performance is fine
- Property-based system has room for optimization
- Focus on gameplay first, performance second

---

## 🎨 Architecture Options Summary

### Option A: Pure Property-Based System ⭐ (Current Recommendation)

**Structure:**
```gdscript
class BaseItem extends Resource:
    # Identity
    item_id, item_name, description, icon, rarity

    # Stat bonuses (applied on equip)
    max_hp_bonus, hp_regen_bonus, movement_speed_mult, projectile_count_bonus

    # On-hit procs (boolean flags + parameters)
    on_hit_lightning: bool, lightning_cooldown: float, lightning_damage_mult: float
    on_hit_explosion: bool, explosion_chance: float, explosion_damage_mult: float
    on_hit_freeze: bool, freeze_chance: float, freeze_duration: float
    ... (15-20 common proc types)

    # Visual modifiers (for particle trails, impact effects)
    adds_poison_particles: bool, poison_particle_color: Color
    adds_fire_trail: bool, fire_trail_scene: PackedScene
    ... (10-15 visual modifier types)

class ItemManager extends Node:
    equipped_items: Array[BaseItem]

    # Connect to EventBus
    _on_damage_dealt() -> Check all items for on-hit procs
    _on_player_damaged() -> Check all items for defensive procs

    # Provide query API for abilities
    get_visual_modifiers() -> Dictionary
    get_behavior_modifiers() -> Dictionary
```

**Pros:**
- ✅ Simple, fast, Inspector-friendly
- ✅ Easy to add new items (just .tres files)
- ✅ 3× faster execution than strategy pattern
- ✅ Separate from tome system

**Cons:**
- ⚠️ Need to add @export properties for each new proc type
- ⚠️ Can't add new proc types at runtime
- ⚠️ Visual modifiers still need query pattern (abilities check ItemManager)

**Best For:**
- Predefined items (not procedural generation)
- 15-30 common proc types
- Performance-critical (100+ hits/sec)

---

### Option B: Strategy Pattern System

**Structure:**
```gdscript
class BaseItem extends Resource:
    item_id, item_name, description, icon, rarity
    strategies: Array[BaseAbilityStrategy]

class BaseAbilityStrategy extends Resource:
    applicable_tags: Array[String]
    trigger_event: String  # "on_hit", "on_damage_taken", etc.
    apply_to_instance(entity, context)

# Strategy subclasses
class ProcStrategy extends BaseAbilityStrategy:
    proc_type: String, proc_chance: float, cooldown: float

class ParticleStrategy extends BaseAbilityStrategy:
    particle_trail: PackedScene, color_modulation: Color

class BehaviorStrategy extends BaseAbilityStrategy:
    impact_aoe_radius: float, aoe_damage_mult: float
```

**Pros:**
- ✅ Extremely flexible (add new strategy types without editing BaseItem)
- ✅ Supports runtime composition (procedural items)
- ✅ Unified system for procs + visuals + behavior

**Cons:**
- ⚠️ Complex (3-4× more code)
- ⚠️ Slower (virtual calls, array iteration)
- ⚠️ Harder to debug (strategy chains)
- ⚠️ More files (.tres for item + .tres for each strategy)

**Best For:**
- Procedurally generated items
- Modding support (users create custom strategies)
- 50+ unique effect types
- Runtime effect composition

---

### Option C: Hybrid System ⭐⭐ (Alternative Recommendation)

**Structure:**
```gdscript
class BaseItem extends Resource:
    # Common effects use properties (fast path)
    on_hit_lightning: bool
    on_hit_explosion: bool
    max_hp_bonus: int

    # Unique/complex effects use strategies (flexible path)
    custom_strategies: Array[BaseAbilityStrategy] = []

    func check_on_hit_procs():
        var triggered = []

        # Fast path: property-based procs (90% of items)
        if on_hit_lightning and _cooldown <= 0:
            triggered.append(...)

        # Flexible path: strategy-based procs (10% of items)
        for strategy in custom_strategies:
            if strategy.should_trigger():
                triggered.append(strategy.get_effect_data())

        return triggered
```

**Pros:**
- ✅ Fast for common cases (properties)
- ✅ Flexible for edge cases (strategies)
- ✅ Easy migration path (add strategies later)
- ✅ Balances simplicity and flexibility

**Cons:**
- ⚠️ Two systems to maintain
- ⚠️ Slightly more complex than pure property-based

**Best For:**
- Start simple, scale as needed
- Most items use properties, rare items use strategies
- Future-proofing without over-engineering

---

## 🔬 Final Architecture (DECIDED)

**✅ Property-Based Item System with Independent Effect Spawning**

### Core Implementation:

**BaseItem.gd** (Resource with @export properties):
```gdscript
class_name BaseItem extends Resource

# Identity
@export var item_id: String
@export var item_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export_enum("common", "uncommon", "rare", "legendary") var rarity: String

# Stat bonuses (applied on equip, no per-hit checks)
@export var max_hp_bonus: int = 0
@export var hp_regen_bonus: int = 0
@export var movement_speed_mult: float = 1.0
@export var damage_mult: float = 1.0  # Beefy Ring

# On-hit procs (checked per hit)
@export var on_hit_lightning: bool = false
@export var lightning_cooldown: float = 10.0
@export var lightning_damage_mult: float = 1.5

@export var on_hit_explosion: bool = false
@export_range(0.0, 1.0) var explosion_chance: float = 0.25
@export var explosion_damage_mult: float = 0.65
@export var explosion_radius: float = 200.0

@export var on_hit_freeze: bool = false
@export_range(0.0, 1.0) var freeze_chance: float = 0.075
@export var freeze_duration: float = 2.0

# ... 10-15 unique proc types total
```

**ItemManager.gd** (Autoload):
```gdscript
extends Node

var equipped_items: Array[BaseItem] = []

func _ready():
    EventBus.combat_step.connect(_on_combat_step)  # Cooldown updates
    EventBus.damage_dealt.connect(_on_damage_dealt)  # Proc checks

func _on_damage_dealt(payload):
    for item in equipped_items:
        # Thunder Mitts
        if item.on_hit_lightning and item._lightning_cooldown <= 0:
            var lightning_damage = payload.damage_amount * item.lightning_damage_mult
            EffectSpawner.spawn_lightning(payload.position, lightning_damage)
            item._lightning_cooldown = item.lightning_cooldown

        # Spicy Meatball
        if item.on_hit_explosion and _roll_proc(item.explosion_chance):
            var explosion_damage = payload.damage_amount * item.explosion_damage_mult
            explosion_damage *= get_item_damage_multiplier()  # Other items

            var nearby = EntityTracker.get_entities_in_radius(payload.position, item.explosion_radius)
            for enemy in nearby:
                DamageService.apply_damage(enemy, explosion_damage)

            EffectSpawner.spawn_explosion(payload.position, item.explosion_radius)
```

### Key Decisions Summary:

1. **Visual Effects:** Items spawn independent effects (no ability modification)
2. **Impact AOE:** ItemManager applies AOE damage using payload damage as base
3. **Tome/Item Overlap:** Both can have generic bonuses (+damage, +cooldown, etc.)
4. **Item Scaling:** Uses payload damage (automatic scaling with everything)
5. **Performance:** 10 unique procs, 50+ total items, <0.1ms overhead

### Implementation Priority:

**Phase 1 (MVP):** Core item system
- BaseItem.gd with 10 unique proc types
- ItemManager.gd with EventBus wiring
- EffectSpawner for visual effects
- 10-15 example items

**Phase 2:** Content expansion
- Add 20-30 more items
- Add 5 more proc types if needed
- Balance proc chances and cooldowns

**Phase 3 (Optional):** Advanced features
- Item stacking formula (additive, diminishing, or multiplicative)
- Meta-modifiers (proc chance multiplier)
- Conditional damage (Beefy Ring, Executioner's Glove)

**Rationale:**
- Simple, fast, Inspector-friendly
- No ability coupling (clean architecture)
- Scales automatically with all systems
- Room for optimization if needed
- 20-30 items covers initial content needs

---

## 📋 Decision Checklist

✅ **ALL DECISIONS COMPLETE - READY FOR IMPLEMENTATION**

- [x] **Visual Effect Application:** ✅ Spawn separately (items spawn independent effects)
- [x] **Impact AOE Approach:** ✅ ItemManager handles AOE damage (payload damage as source)
- [x] **Item vs Tome Boundary:** ✅ Allow overlap, generic bonuses only (no element-specific)
- [x] **Item Scaling Model:** ✅ Scale with payload damage (automatic, zero maintenance)
- [x] **Performance Budget:** ✅ 50+ items (10 unique procs), 300-500 hits/sec, optimize if needed
- [x] **Architecture Choice:** ✅ Property-based system (simple, fast, Inspector-friendly)
- [x] **Visual Modifier API:** ✅ Not needed (items spawn effects independently)
- [ ] **Item Example Catalog:** TODO - Finalize 20-30 example items with all properties defined

---

## 📝 Next Steps

1. **Brainstorm Session:**
   - Review all open questions
   - Discuss trade-offs for each option
   - Make architectural decisions
   - Document rationale

2. **Define Item Catalog:**
   - List 20-30 example items
   - Define all properties/effects for each
   - Identify common patterns
   - Ensure architecture supports all examples

3. **Update Implementation Task:**
   - Transfer decisions to `ITEM-SYSTEM_1_implementation.md`
   - Add concrete examples
   - Define acceptance criteria
   - Estimate implementation time

4. **Create Test Plan:**
   - Define test scenarios
   - Performance validation criteria
   - Integration test cases

---

## 🔗 Related Documents

- `ITEM-SYSTEM_1_implementation.md` (blocked by this task)
- `ITEM-SYSTEM_strategy-pattern-integration.md` (strategy pattern reference)
- `2_ABILITIES_system_implementation.md` (ability system integration)
- `scripts/resources/tomes/BaseTome.gd` (tome system for comparison)

---

**Status:** ✅ COMPLETE - All Decisions Finalized
**Next Action:** Update implementation task and begin Phase 1
**Time Saved:** Q&A session completed design phase efficiently
**Ready For:** `ITEM-SYSTEM_1_implementation.md` execution
