# Item System - Implementation Task

**Status:** ✅ COMPLETE (2025-10-14)
**Priority:** High
**Category:** Item System / Implementation
**Estimated Time:** 6-10 hours (Phase 1 MVP) ← 100% Complete
**Design Doc:** `completed-tasks/ITEM-SYSTEM_0_design-brainstorm.md` ✅ Complete

---

## 📋 Task Description

Implement **property-based item system** with independent effect spawning. Items are equipment that:
- Grant stat bonuses (HP, movement speed, damage) - applied on equip
- Trigger proc effects on combat events (lightning on hit, explosions, freeze)
- Spawn independent visual effects (no ability modification)
- Scale automatically via payload damage (zero maintenance)
- Support 50+ items (10 unique procs) with <0.1ms overhead

**Key Architecture Decision:**
- **Property-Based System:** @export properties for procs (simple, fast, Inspector-friendly)
- **Independent Effects:** Items spawn their own visuals/damage (no ability coupling)
- **Payload Damage Scaling:** Items use `payload.damage_amount` as base (auto-scales with everything)

**Key Differentiator from Tomes:**
- **Tomes:** Modify ability templates (compile-time stats)
- **Items:** React to combat events (runtime procs)
- **Overlap:** Both can have generic bonuses (+damage, +cooldown)

---

## 🏗️ Architecture: ItemMetadata vs BaseItem (Dual-Resource Pattern)

**Critical Integration Note:** This system integrates with existing shop/quest systems and follows TomeManager patterns.

### **Existing System (Keep):**
- **ItemMetadata** (`scripts/resources/ItemMetadata.gd`) - Already used by:
  - Shop UI (display_name, icon, unlock_cost)
  - Admin panel (quest requirements, discovery state)
  - MetaProgression (discovered_items, unlocked_items tracking)
  - Quest system rewards (Task 5a: Quest completion unlocks by item_id)

### **New System (Add):**
- **BaseItem** (`scripts/resources/items/BaseItem.gd`) - Pure gameplay resource:
  - Stat bonuses (@export max_hp_bonus, movement_speed_mult, damage_mult)
  - Proc properties (@export on_hit_lightning, lightning_cooldown, lightning_damage_mult)
  - Runtime state (cooldown tracking, proc counters)
  - Zero UI concerns (no display_name, icons, descriptions)

### **File Naming Convention (Coupled Suffix):**
```
data/content/items/
  ├── thunder_mitts_metadata.tres    # ItemMetadata (UI/catalog)
  └── thunder_mitts_gameplay.tres    # BaseItem (procs/stats)
```

**Suffix pattern:** `{item_id}_metadata.tres` for catalog, `{item_id}_gameplay.tres` for effects

### **ItemManager Pattern (Following TomeManager):**
```gdscript
// autoload/ItemManager.gd (mirrors TomeManager.gd)
class_name ItemManager extends Node

# Dual registries (following TomeManager pattern)
var _item_registry: Dictionary = {}       # {item_id: BaseItem} - Gameplay
var _metadata_registry: Dictionary = {}   # {item_id: ItemMetadata} - Catalog
var _item_file_paths: Dictionary = {}     # Hot-reload support

func _ready():
    _load_all_items_from_directory("res://data/content/items/")

# Gameplay query (chest drops, proc checks)
func get_base_item(item_id: String) -> BaseItem:
    return _item_registry.get(item_id)

# Catalog query (shop UI, quest rewards display)
func get_item_metadata(item_id: String) -> ItemMetadata:
    return _metadata_registry.get(item_id)
```

### **Integration Flow (Quest → Shop → Chest → Gameplay):**

**1. Quest Completion (Task 5a):**
```gdscript
// QuestConfig.tres
reward_unlocks: ["thunder_mitts"]

// QuestManager awards reward
MetaProgression.discover_item("items", "thunder_mitts")  # Uses "items" category
MetaProgression.unlock_item("items", "thunder_mitts")
```

**2. Shop Display (Existing):**
```gdscript
// UnlockShop.gd
var metadata = ItemManager.get_item_metadata("thunder_mitts")  # Load catalog data
shop_ui.display_item(metadata.display_name, metadata.icon, metadata.unlock_cost)
```

**3. Chest Drop (Future ChestSystem):**
```gdscript
// ChestSystem.gd
func spawn_item(item_id: String):
    // Check unlock state
    if not MetaProgression.is_item_unlocked("items", item_id):
        return  # Can't drop locked items

    // Load gameplay resource
    var base_item = ItemManager.get_base_item(item_id)  # Load procs/stats
    ItemManager.equip_item(base_item)  # Apply effects
```

**4. Gameplay Effects (This Task):**
```gdscript
// ItemManager.gd
func equip_item(item: BaseItem):
    equipped_items.append(item)
    _apply_stat_bonuses(item)  # +HP, +movement speed
    _register_procs(item)       # Lightning, explosion, freeze
```

### **Category Consistency:**
- **MetaProgression category:** `"items"` (matches existing `_get_unlocked_array`)
- **Quest reward category:** `"items"` (Task 5a integration)
- **File paths:** `res://data/content/items/`
- **ItemManager loads from:** `data/content/items/*_gameplay.tres` and `*_metadata.tres`

### **Why This Architecture:**
1. ✅ **Preserves existing systems** - Shop, admin panel, MetaProgression unchanged
2. ✅ **Clean separation** - UI data stays in ItemMetadata, gameplay in BaseItem
3. ✅ **Follows TomeManager pattern** - Dual registries, hot-reload support
4. ✅ **Quest integration ready** - Quest completion → MetaProgression → ItemManager
5. ✅ **Performance** - Chest/gameplay only loads BaseItem (lighter than full metadata)
6. ✅ **Filename coupling** - Suffix pattern keeps related files discoverable

---

## 🎯 Architecture Decision: DamageDealtPayload Position Data

**Q&A Resolution (2025-10-13):** How should ItemManager get position data for spawning effects?

### **Decision: Extend DamageDealtPayload with Both Positions**

```gdscript
// DamageDealtPayload.gd - Extended payload
class_name DamageDealtPayload extends RefCounted

var damage: float
var source: String
var target: String
var source_position: Vector2  # NEW: Where damage originated (player/ability)
var impact_position: Vector2  # NEW: Where damage landed (enemy position)

func _init(dealt_damage: float, damage_source: String, damage_target: String,
           src_pos: Vector2 = Vector2.ZERO, impact_pos: Vector2 = Vector2.ZERO):
    # Backwards compatible - old code uses defaults
```

### **Rationale:**

**Why extend existing payload instead of new signal:**
1. ✅ **Simpler** - One signal contract instead of three
2. ✅ **Better performance** - Single emission per damage event
3. ✅ **More flexible** - Provides BOTH source (player) and impact (enemy) positions
4. ✅ **Backwards compatible** - Default parameters preserve existing listeners
5. ✅ **Leverages PackedArrays** - Uses DamageRegistry's efficient position storage
6. ✅ **Only 2 files modified** - DamageDealtPayload.gd + DamageRegistry.gd
7. ✅ **Future-proof** - Other systems can use positions (knockback, screen effects)

### **Position Semantics:**
- **source_position** - Where damage ORIGINATED (player position, ability spawn point)
  - Use for: Knockback direction, damage lines, player-centric effects
- **impact_position** - Where damage LANDED (enemy position at hit)
  - Use for: Item proc spawning (lightning, explosions, poison clouds)

### **Integration Pattern:**

```gdscript
// ItemManager.gd - Uses impact_position for effects
func _on_damage_dealt(payload: EventBus.DamageDealtPayload_Type):
    // Filter out item-generated damage to prevent recursion
    if payload.source.begins_with("item_"):
        return  // Items don't proc other items

    // Only proc on player damage
    if payload.source not in ["melee", "projectile", "ability", "player"]:
        return

    // Spawn effects at IMPACT position (where enemy was hit)
    for item in equipped_items:
        if item.on_hit_lightning and item._lightning_cooldown <= 0:
            EffectSpawner.spawn_lightning(payload.impact_position, damage)

// DamageRegistry.gd - Emission site
func _process_damage_immediate(...):
    var impact_position = Vector2(_entity_positions_x[index], _entity_positions_y[index])

    var payload = EventBus.DamageDealtPayload_Type.new(
        final_damage,
        source,
        target_id,
        source_position,   # Player/ability origin
        impact_position    # Enemy position (from PackedArrays)
    )
    EventBus.damage_dealt.emit(payload)
```

### **Recursion Prevention:**

**Source Filtering Pattern:**
```gdscript
// Item-generated damage uses prefixed source names
DamageService.apply_damage(
    enemy_id,
    explosion_damage,
    "item_explosion",  // ← Prefix prevents recursion
    ["physical"],
    0.0,
    impact_position
)

// ItemManager filters by source
if payload.source.begins_with("item_"):
    return  // Don't proc items on item damage
```

**Result:** Spicy Meatball explosion → hits 5 enemies → damage tracked, camera shakes, but NO cascading explosions.

---

## 🎯 Architecture Decision: PlayerStats Component for Mutable Properties

**Q&A Resolution (2025-10-13):** How should items/tomes modify player stats when Player.gd only has read-only getters?

### **Problem: Stat Modification Currently Broken**

**Current Issue:**
```gdscript
// BaseTome.gd:310-324 attempts direct property modification
if movement_speed_multiplier != 1.0 and player.has("movement_speed"):
    player.movement_speed *= pow(movement_speed_multiplier, effective_stacks)
// ❌ FAILS: player.has("movement_speed") returns false - no such property exists

// Player.gd:127-160 only has read-only getters
func get_move_speed() -> float:
    if player_type:
        return player_type.move_speed
    return 110.0  // No setter, no writable property
```

**Impact:** Tomes (and future items) cannot modify player stats. All stat bonuses are no-ops.

### **Decision: PlayerStats Component Pattern (Option B)**

**Create dedicated resource for runtime stat modifications:**

```gdscript
// scripts/resources/PlayerStats.gd
class_name PlayerStats extends Resource

# Base values synced from PlayerType on init
var base_movement_speed: float = 110.0
var base_max_health: int = 199
var base_pickup_radius: float = 12.0
var base_damage: float = 25.0

# Runtime modifiers (applied by tomes/items)
var movement_speed_mult: float = 1.0
var max_hp_bonus: int = 0
var pickup_radius_mult: float = 1.0
var damage_mult: float = 1.0

# Computed effective values
func get_effective_move_speed() -> float:
    return base_movement_speed * movement_speed_mult

func get_effective_max_health() -> int:
    return base_max_health + max_hp_bonus

func get_effective_pickup_radius() -> float:
    return base_pickup_radius * pickup_radius_mult

func get_effective_damage() -> float:
    return base_damage * damage_mult

# Sync base values from PlayerType (preserves hot-reload)
func sync_from_player_type(player_type: PlayerType) -> void:
    base_movement_speed = player_type.move_speed
    base_max_health = player_type.max_health
    base_pickup_radius = player_type.pickup_radius
    base_damage = player_type.base_damage
```

### **Integration Pattern:**

**Player.gd Changes:**
```gdscript
// Player.gd - Add runtime_stats component
var runtime_stats: PlayerStats

func _ready():
    # Create and sync runtime stats from player_type
    runtime_stats = PlayerStats.new()
    if player_type:
        runtime_stats.sync_from_player_type(player_type)

# Update getters to use runtime_stats (preserves hot-reload)
func get_move_speed() -> float:
    if runtime_stats:
        return runtime_stats.get_effective_move_speed()
    return 110.0  # Fallback

func get_max_health() -> int:
    if runtime_stats:
        return runtime_stats.get_effective_max_health()
    return 199
```

**BaseTome.gd Changes:**
```gdscript
// BaseTome.gd - Modify runtime_stats instead of player properties
func apply_to_player(player: Node2D, stack_count: int) -> void:
    if not player.runtime_stats:
        Logger.warn("Player missing runtime_stats component", "tomes")
        return

    var effective_stacks = clampi(stack_count, min_stacks, max_stacks)

    # Apply multiplicative modifiers to runtime_stats
    if movement_speed_multiplier != 1.0:
        player.runtime_stats.movement_speed_mult *= pow(movement_speed_multiplier, effective_stacks)

    if pickup_radius_multiplier != 1.0:
        player.runtime_stats.pickup_radius_mult *= pow(pickup_radius_multiplier, effective_stacks)

    # Apply additive bonuses to runtime_stats
    if max_hp_bonus != 0:
        player.runtime_stats.max_hp_bonus += max_hp_bonus * effective_stacks

    if damage_multiplier != 1.0:
        player.runtime_stats.damage_mult *= pow(damage_multiplier, effective_stacks)
```

**ItemManager.gd Integration (Future):**
```gdscript
// ItemManager.gd - Apply item stat bonuses
func equip_item(item: BaseItem) -> void:
    var player = _get_player_reference()
    if not player or not player.runtime_stats:
        Logger.warn("Cannot apply item stats - player missing runtime_stats", "items")
        return

    equipped_items.append(item)

    # Apply stat bonuses to runtime_stats
    if item.max_hp_bonus != 0:
        player.runtime_stats.max_hp_bonus += item.max_hp_bonus

    if item.movement_speed_mult != 1.0:
        player.runtime_stats.movement_speed_mult *= item.movement_speed_mult

    if item.damage_mult != 1.0:
        player.runtime_stats.damage_mult *= item.damage_mult
```

### **Rationale:**

**Why PlayerStats Component:**
1. ✅ **Preserves hot-reload** - Base values stay in player_type.tres, runtime mods in PlayerStats
2. ✅ **Clean architecture** - Separates configuration (PlayerType) from runtime state (PlayerStats)
3. ✅ **Matches tome pattern** - BaseTome already uses multiplicative/additive separation
4. ✅ **Scales well** - Future items/passives/buffs all modify runtime_stats
5. ✅ **No breaking changes** - Player getters stay compatible, internal implementation changes
6. ✅ **Testable** - PlayerStats can be unit tested independently

**Implementation Steps:**
1. Create `scripts/resources/PlayerStats.gd` resource class
2. Update `Player.gd` to instantiate runtime_stats and sync from player_type
3. Update Player getters to query runtime_stats.get_effective_*()
4. Fix `BaseTome.apply_to_player()` to modify runtime_stats properties
5. Test tome stat bonuses work correctly (movement speed, HP, damage)
6. Document pattern in `scripts/domain/CLAUDE.md` for items to follow

---

## 🎯 Acceptance Criteria

### Phase 1 (MVP): ✅ 100% COMPLETE (2025-10-14)
- [x] Design decisions documented in brainstorm task ✅
- [x] BaseItem.gd created with proc types (poison, lightning, explosion, freeze) ✅
- [x] ItemManager.gd autoload created with dual registries + EventBus wiring ✅
- [x] EffectSpawner system for lightning/explosion/freeze visuals ✅
- [x] StatusEffectSystem for poison DoT with overflow scaling ✅
- [x] Stat bonuses apply via Player.runtime_stats (movement_speed, damage, HP, pickup_radius, crit_chance) ✅
- [x] On-hit procs trigger correctly (Thunder Mitts, Spicy Meatball, Cheese, Frost Glaive) ✅
- [x] Cooldown tracking works (per-item independent cooldowns) ✅
- [x] Proc chance rolls use RNG.stream("item_procs") for determinism ✅
- [x] Item explosions/poison use payload damage + overflow scaling ✅
- [x] 8 example items created (_gameplay + _metadata pairs) ✅
- [x] Items can stack with multiplicative/overflow formulas ✅
- [x] Performance validated (50 stacks tested, poison system <0.1ms overhead) ✅
- [x] Documentation updated (autoload/CLAUDE.md, data/README.md) ✅
- [x] Utility items configured (clover 1.3x pickup radius, rabbits_foot 0.1 crit chance) ✅

### Future Phases:
- [ ] 20-30 total items created (content expansion)
- [ ] Conditional damage modifiers (Beefy Ring: +20% per 10 max HP)
- [ ] Meta-modifiers (proc chance multiplier item)
- [ ] Item stacking formula finalized (additive/diminishing/multiplicative)
- [ ] On-damage-taken procs (Electric Armor)

---

## 🔍 Technical Approach

**Architecture:** Property-Based System (see brainstorm doc for rationale)

### Core Components:

**1. BaseItem.gd** (Resource)
- @export properties for identity, stat bonuses, procs
- 10 unique proc types: lightning, explosion, freeze, poison, bonk, bloodmark, etc.
- Runtime state: cooldown tracking (_lightning_cooldown_remaining, etc.)
- Methods: check_on_hit_procs(), check_on_damaged_procs(), update_cooldowns()

**2. ItemManager.gd** (Autoload)
- equipped_items: Array[BaseItem]
- Connects to EventBus.combat_step (cooldown updates)
- Connects to EventBus.damage_dealt (proc checks)
- Methods: equip_item(), unequip_item(), get_item_damage_multiplier()
- RNG: Uses RNG.stream("item_procs") for deterministic proc rolls

**3. EffectSpawner.gd** (Autoload or System)
- spawn_lightning(position, damage)
- spawn_explosion(position, radius)
- spawn_poison_cloud(position, damage_per_sec, duration)
- Generic reusable effects (not per-ability customization)

### Key Design Patterns:

**Payload Damage as Source of Truth:**
```gdscript
func _on_damage_dealt(payload):
    for item in equipped_items:
        if item.on_hit_lightning and item._lightning_cooldown <= 0:
            var lightning_damage = payload.damage_amount * item.lightning_damage_mult
            EffectSpawner.spawn_lightning(payload.position, lightning_damage)
```

**Item Damage Modifiers (Not Tome Modifiers):**
```gdscript
func _on_damage_dealt(payload):
    if item.on_hit_explosion and _roll_proc(item.explosion_chance):
        var explosion_damage = payload.damage_amount * item.explosion_damage_mult
        explosion_damage *= get_item_damage_multiplier()  # Beefy Ring, etc.

        var nearby = EntityTracker.get_entities_in_radius(...)
        for enemy in nearby:
            DamageService.apply_damage(enemy, explosion_damage)
```

**Independent Effect Spawning:**
- Items spawn visuals via EffectSpawner (centralized)
- Abilities remain unaware of items (no coupling)
- Generic effects work on all abilities (lightning works on fireball, arrow, etc.)

---

## 📊 Implementation Phases

### Phase 1: Core Item System (4-6 hours) - MVP

**Goal:** Basic item procs working with 3-5 example items

**Tasks:**
1. Create `scripts/resources/items/BaseItem.gd` (1.5 hours)
   - Identity properties (item_id, name, description, icon, rarity)
   - Stat bonus properties (max_hp_bonus, movement_speed_mult, damage_mult)
   - 3 proc types to start: lightning, explosion, freeze
   - Cooldown tracking variables
   - check_on_hit_procs() method stub

2. Create `autoload/ItemManager.gd` (1.5 hours)
   - equipped_items array
   - EventBus.combat_step connection (cooldown updates)
   - EventBus.damage_dealt connection (proc checks)
   - equip_item() / unequip_item() methods
   - get_item_damage_multiplier() helper
   - RNG.stream("item_procs") integration

3. Create `scripts/systems/EffectSpawner.gd` (1 hour)
   - spawn_lightning() - placeholder visual + DamageService call
   - spawn_explosion() - placeholder visual + area damage
   - spawn_freeze() - placeholder visual + StatusEffectSystem call
   - Use existing FireballImpact.tscn as explosion template

4. Create 3-5 Example Items (1 hour)
   - Thunder Mitts (lightning on hit, 10s cooldown)
   - Spicy Meatball (25% explosion chance)
   - Frost Gloves (7.5% freeze on hit)
   - Health Ring (+25 max HP)
   - Turbo Socks (+15% movement speed)

**Success Criteria:**
- Equip Thunder Mitts → lightning spawns every 10s on hit
- Equip Spicy Meatball → 25% explosion chance applies AOE damage
- Stat bonuses apply correctly (HP, movement speed visible in debug)

---

### Phase 2: Content Expansion (2-3 hours)

**Goal:** Add 7 more proc types + 10-15 more items

**Tasks:**
1. Add proc types to BaseItem.gd:
   - Poison cloud, bloodmark, bonk crit, bleed, burn, shock (on-damage-taken), proc chance multiplier

2. Expand EffectSpawner:
   - spawn_poison_cloud(), spawn_bloodmark(), spawn_bonk_visual()

3. Create 10-15 more items (.tres files)

4. Implement item stacking (multiple copies increase proc chance)

**Success Criteria:**
- 10 unique proc types working
- 15-20 total items created
- Item stacking formula chosen and implemented

---

### Phase 3: Advanced Features (2-4 hours) - Optional

**Goal:** Conditional modifiers + meta-modifiers

**Tasks:**
1. Conditional damage modifiers:
   - Beefy Ring: +20% damage per 10 max HP (query PlayerState.max_hp)
   - Executioner's Glove: +20% vs enemies >90% HP (query EntityTracker)

2. Meta-modifiers:
   - Proc chance multiplier item (affects other items)

3. On-damage-taken procs:
   - Electric Armor: Shock on damage taken

**Success Criteria:**
- Beefy Ring scales damage with player HP
- Proc chance multiplier affects all procs
- Defensive procs trigger correctly

---

## 🔗 Related Files

### Will Create:
- [ ] `scripts/resources/items/BaseItem.gd` (Pure gameplay resource - stat bonuses, procs)
- [ ] `autoload/ItemManager.gd` (Dual registry: BaseItem + ItemMetadata, following TomeManager pattern)
- [ ] `scripts/systems/EffectSpawner.gd` (Generic effect spawning - may be autoload)

**BaseItem Gameplay Resources (data/content/items/*_gameplay.tres):**
- [ ] `data/content/items/thunder_mitts_gameplay.tres` (Lightning on hit, 10s cooldown)
- [ ] `data/content/items/spicy_meatball_gameplay.tres` (25% explosion chance)
- [ ] `data/content/items/frost_gloves_gameplay.tres` (7.5% freeze on hit)
- [ ] `data/content/items/health_ring_gameplay.tres` (+25 max HP stat bonus)
- [ ] `data/content/items/turbo_socks_gameplay.tres` (+15% movement speed)
- [ ] 10-15 more gameplay .tres files

**ItemMetadata Catalog Resources (data/content/items/*_metadata.tres):**
- [ ] `data/content/items/thunder_mitts_metadata.tres` (Display name, icon, unlock cost, quest requirement)
- [ ] `data/content/items/spicy_meatball_metadata.tres` (Catalog UI data)
- [ ] `data/content/items/frost_gloves_metadata.tres` (Catalog UI data)
- [ ] `data/content/items/health_ring_metadata.tres` (Catalog UI data)
- [ ] `data/content/items/turbo_socks_metadata.tres` (Catalog UI data)
- [ ] 10-15 more metadata .tres files

### Will Modify:
- [ ] `autoload/EventBus.gd` (verify damage_dealt payload has position)
- [ ] `scripts/domain/signal_payloads/DamageDealtPayload.gd` (add target_position if missing)
- [ ] `scripts/systems/damage_v2/DamageRegistry.gd` (emit damage_dealt with position)
- [ ] `scenes/arena/Player.gd` (add equipped_items integration - maybe)
- [ ] `autoload/MetaProgression.gd` (verify "items" category works correctly - already exists)
- [ ] Project autoload settings (add ItemManager to autoload list)

### Documentation:
- [ ] `autoload/CLAUDE.md` (ItemManager patterns)
- [ ] `scripts/resources/CLAUDE.md` (BaseItem resource pattern)
- [ ] `data/README.md` (item .tres schema documentation)

---

## 📝 Progress Notes

### 2025-10-13 - Q&A Architecture Resolutions Complete ✅

**All three architectural gaps resolved via Q&A session:**

#### **Q1: ItemMetadata vs BaseItem Architecture ✅**
- ✅ **Decision:** Dual-resource pattern with filename coupling
- ✅ **ItemMetadata preserved** - Existing shop/admin/MetaProgression/quest system unchanged
- ✅ **BaseItem added** - Pure gameplay resource for procs/stats/runtime state
- ✅ **Filename convention:** `{item_id}_metadata.tres` and `{item_id}_gameplay.tres`
- ✅ **ItemManager pattern:** Dual registries following TomeManager (get_base_item, get_item_metadata)
- ✅ **Category consistency:** Uses "items" category (MetaProgression compatible)
- ✅ **Integration flow:** Quest → MetaProgression → Shop (metadata) → Chest (gameplay)

#### **Q2: DamageDealtPayload Position Data ✅**
- ✅ **Decision:** Extend DamageDealtPayload with both source_position and impact_position
- ✅ **Position semantics defined:**
  - source_position = Player/ability origin (for knockback, damage lines)
  - impact_position = Enemy position where hit occurred (for item effect spawning)
- ✅ **Backwards compatible:** Default parameters preserve existing listeners
- ✅ **Recursion prevention:** Source filtering pattern (payload.source.begins_with("item_"))
- ✅ **Simpler than alternatives:** 2 files modified vs 3 new signals
- ✅ **Leverages PackedArrays:** Uses DamageRegistry's efficient position storage
- ✅ **Files to modify:** DamageDealtPayload.gd + DamageRegistry.gd

#### **Q3: Player Stat Mutability ✅**
- ✅ **Decision:** PlayerStats component pattern (Option B)
- ✅ **Problem identified:** Player.gd only has read-only getters, BaseTome.apply_to_player() is no-op
- ✅ **Solution:** Create PlayerStats resource with base values + runtime modifiers
- ✅ **Preserves hot-reload:** Base values sync from player_type.tres on _ready()
- ✅ **Clean architecture:** Separates configuration (PlayerType) from runtime state (PlayerStats)
- ✅ **Matches tome pattern:** multiplicative/additive modifier separation
- ✅ **No breaking changes:** Player getters stay compatible, internal refactor only
- ✅ **Files to modify:** Create PlayerStats.gd, update Player.gd + BaseTome.gd

**Ready for Implementation:**
- All architectural blockers resolved
- Clear implementation path defined
- Integration patterns documented
- File modification checklist complete

**Next Steps:**
1. Create PlayerStats.gd and fix tome stat bonuses (prerequisite for items)
2. Extend DamageDealtPayload with positions
3. Create BaseItem.gd with proc types
4. Create ItemManager.gd with dual registries
5. Create EffectSpawner.gd for visual effects
6. Create example item pairs (_metadata + _gameplay)
7. Test item procs in-game

### 2025-01-13 - Design Complete, Ready to Implement
- ✅ Design brainstorm completed via Q&A session
- ✅ All 5 design questions answered and documented
- ✅ Architecture chosen: Property-based system
- ✅ Key patterns defined: Payload damage scaling, independent effects
- ✅ Performance validated: <0.1ms for 50 items

**Design Decisions Made:**
1. Visual effects: Items spawn independently (no ability modification)
2. Impact AOE: ItemManager handles via payload damage
3. Tome/item overlap: Allowed for generic bonuses only
4. Item scaling: Automatic via payload damage
5. Performance: 10 unique procs, 50+ items, optimize if needed

**Next Steps:**
1. Create BaseItem.gd with 3 proc types (lightning, explosion, freeze)
2. Create ItemManager.gd with dual registries (TomeManager pattern)
3. Create EffectSpawner.gd for generic effects
4. Create 3-5 example items (both _metadata and _gameplay files)
5. Test and iterate

---

## 🚨 Implementation Notes

### EventBus Integration:
- Need to verify `DamageDealtPayload` has `target_position: Vector2`
- If missing, add to payload for effect spawning
- ItemManager subscribes to `EventBus.damage_dealt`

### RNG Integration:
- Use `RNG.stream("item_procs")` for deterministic proc rolls
- Seeded by RunManager per-run

### Performance:
- Start simple, profile if lag occurs
- Early exit optimizations: Check cooldowns before proc conditions
- Separate active procs from passive items if needed

### Testing Strategy:
- Manual testing: Equip items, verify procs trigger
- Performance testing: 10 items, 400 hits/sec, measure frame time
- Integration testing: Multiple items, stacking, stat bonuses

---

**Status:** 🟢 Ready to implement
**Last Updated:** 2025-01-13
**Time Estimate:** 6-10 hours (Phase 1 MVP)
