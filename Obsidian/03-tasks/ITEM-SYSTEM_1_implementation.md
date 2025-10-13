# Item System - Implementation Task

**Status:** 🟢 Ready to Implement (design complete)
**Priority:** High
**Category:** Item System / Implementation
**Estimated Time:** 6-10 hours (Phase 1 MVP)
**Design Doc:** `ITEM-SYSTEM_0_design-brainstorm.md` ✅ Complete

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

## 🎯 Acceptance Criteria

### Phase 1 (MVP):
- [x] Design decisions documented in brainstorm task ✅
- [ ] BaseItem.gd created with 10 unique proc types
- [ ] ItemManager.gd autoload created with EventBus wiring
- [ ] EffectSpawner system for lightning/explosion/poison visuals
- [ ] Stat bonuses apply on equip (HP, movement speed, damage)
- [ ] On-hit procs trigger correctly (Thunder Mitts, Spicy Meatball)
- [ ] Cooldown tracking works (per-item independent cooldowns)
- [ ] Proc chance rolls use RNG.stream("item_procs") for determinism
- [ ] Item explosions use payload damage + item damage modifiers
- [ ] 10-15 example items created as .tres files
- [ ] Items can stack (multiple copies increase proc chance - formula TBD)
- [ ] Performance validated (<0.1ms for 10 procs at 400 hits/sec)
- [ ] Documentation updated (autoload/CLAUDE.md, data/README.md)

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
- [ ] `scripts/resources/items/BaseItem.gd` (Resource with @export properties)
- [ ] `autoload/ItemManager.gd` (Event handling + equip/unequip)
- [ ] `scripts/systems/EffectSpawner.gd` (Generic effect spawning - may be autoload)
- [ ] `data/content/items/thunder_mitts.tres` (Example: Lightning on hit)
- [ ] `data/content/items/spicy_meatball.tres` (Example: Explosion chance)
- [ ] `data/content/items/frost_gloves.tres` (Example: Freeze on hit)
- [ ] `data/content/items/health_ring.tres` (Example: Stat bonus)
- [ ] `data/content/items/turbo_socks.tres` (Example: Movement speed)
- [ ] 10-15 more item .tres files

### Will Modify:
- [ ] `autoload/EventBus.gd` (verify damage_dealt payload has position)
- [ ] `scripts/domain/signal_payloads/DamageDealtPayload.gd` (add target_position if missing)
- [ ] `scripts/systems/DamageSystem.gd` (emit damage_dealt with position)
- [ ] `scenes/arena/Player.gd` (add equipped_items integration - maybe)
- [ ] Project autoload settings (add ItemManager, EffectSpawner)

### Documentation:
- [ ] `autoload/CLAUDE.md` (ItemManager patterns)
- [ ] `scripts/resources/CLAUDE.md` (BaseItem resource pattern)
- [ ] `data/README.md` (item .tres schema documentation)

---

## 📝 Progress Notes

### 2025-01-13 - Design Complete, Ready to Implement
- ✅ Design brainstorm completed via Q&A session
- ✅ All 5 design questions answered and documented
- ✅ Architecture chosen: Property-based system
- ✅ Key patterns defined: Payload damage scaling, independent effects
- ✅ Performance validated: <0.1ms for 50 items
- 🟢 Ready to begin Phase 1 implementation

**Design Decisions Made:**
1. Visual effects: Items spawn independently (no ability modification)
2. Impact AOE: ItemManager handles via payload damage
3. Tome/item overlap: Allowed for generic bonuses only
4. Item scaling: Automatic via payload damage
5. Performance: 10 unique procs, 50+ items, optimize if needed

**Next Steps:**
1. Create BaseItem.gd with 3 proc types (lightning, explosion, freeze)
2. Create ItemManager.gd with EventBus wiring
3. Create EffectSpawner.gd for generic effects
4. Create 3-5 example items
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
