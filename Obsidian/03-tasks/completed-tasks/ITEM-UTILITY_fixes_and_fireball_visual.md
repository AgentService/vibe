# Item System - Utility Item Fixes + FireballImpact Visual Investigation

**Status:** 🔴 Not Started
**Priority:** Medium
**Category:** Item System / Bug Fixes + Visual Effects
**Estimated Time:** 2-3 hours
**Depends On:** ITEM-SYSTEM_1_implementation.md (Phase 1 complete)
**Created:** 2025-10-14

---

## 📋 Task Description

Fix utility item bonuses that are currently not working and investigate why FireballImpact's self_modulate visual effect is not functioning correctly.

###  Task Completion Status

The item system is 90% complete - all proc items (poison, lightning, explosion, freeze) work correctly with stack formulas and overflow scaling. The remaining issues are:
1. **Utility items** with passive bonuses need implementation
2. **FireballImpact visual** self_modulate not working (green poison variant needed)

---

## 🎯 Objectives

### Part 1: Fix Utility Item Bonuses

**Problem:** Three utility items have bonuses that aren't implemented yet:
- `clover_gameplay.tres` - Pickup radius bonus (likely needs pickup_radius_mult property)
- `lucky_coin_gameplay.tres` - Unknown bonus (needs design decision)
- `rabbits_foot_gameplay.tres` - Crit chance bonus (needs crit_chance_bonus property)

**Expected Behavior:**
- Clover: +X% pickup radius → modify `Player.runtime_stats.pickup_radius_mult`
- Rabbits Foot: +X% crit chance → modify `Player.runtime_stats.crit_chance_bonus`
- Lucky Coin: ??? (needs specification - maybe luck/drop rate?)

### Part 2: Investigate FireballImpact self_modulate

**Problem:** FireballImpact.tscn scene has self_modulate property but changing it has no visual effect on the explosion color.

**Expected Behavior:**
- Poison explosions (Voodoo Doll + Cheese) should be green-tinted
- Fire explosions should stay orange/red

**Investigation Steps:**
1. Check if modulate works on FireballImpact AnimatedSprite2D
2. Verify shader/material not overriding modulate
3. Check sprite blend mode and material settings
4. Test with direct scene instance (not from item proc)

**Potential Causes:**
- Material override blocking modulate
- Shader overriding color
- Blend mode incompatibility
- AnimatedSprite2D not propagating modulate to frames

---

## 🔍 Technical Analysis

### Utility Item Properties Needed

**BaseItem.gd additions:**
```gdscript
# Utility bonuses (@export properties)
@export var pickup_radius_mult: float = 1.0  # Clover: 1.3 = +30% pickup radius
@export var crit_chance_bonus: float = 0.0   # Rabbits Foot: 0.1 = +10% crit chance
@export var luck_bonus: float = 0.0          # Lucky Coin: TBD (drop rate/chest quality?)
```

**ItemManager.gd integration:**
```gdscript
func _apply_stat_bonuses(item: BaseItem, stack_count: int = 1) -> void:
    # Existing bonuses (working)
    if item.movement_speed_mult != 1.0:
        player.runtime_stats.movement_speed_mult *= pow(item.movement_speed_mult, stack_count)

    if item.damage_mult != 1.0:
        player.runtime_stats.damage_mult *= pow(item.damage_mult, stack_count)

    if item.max_hp_bonus != 0:
        player.runtime_stats.max_hp_bonus += item.max_hp_bonus * stack_count

    # NEW: Pickup radius (multiplicative)
    if item.pickup_radius_mult != 1.0:
        player.runtime_stats.pickup_radius_mult *= pow(item.pickup_radius_mult, stack_count)

    # NEW: Crit chance (additive)
    if item.crit_chance_bonus != 0.0:
        player.runtime_stats.crit_chance_bonus += item.crit_chance_bonus * stack_count
```

### FireballImpact Visual Investigation

**Files to check:**
- `scenes/effects/FireballImpact.tscn` - Scene structure and sprite setup
- `assets/sprites/impact_atlas.png` - Source texture (check if green variant exists)
- AnimatedSprite2D properties (material, blend mode, self_modulate vs modulate)

**Possible solutions:**
1. **If modulate works:** Use `explosion.modulate = Color(0.5, 1.0, 0.5)` for green
2. **If shader needed:** Create material with color_mult uniform
3. **If sprite variant needed:** Duplicate FireballImpact → PoisonImpact with green atlas row
4. **If AnimatedSprite2D issue:** Try CanvasModulate node or shader material

**Test command:**
```gdscript
# Quick test in debugger/script console
var explosion = load("res://scenes/effects/FireballImpact.tscn").instantiate()
explosion.modulate = Color(0.5, 1.0, 0.5)  # Green tint
get_tree().root.add_child(explosion)
explosion.global_position = player.global_position
```

---

## ✅ Acceptance Criteria

### Part 1: Utility Items
- [ ] Clover grants pickup radius bonus (visible in Player.runtime_stats)
- [ ] Rabbits Foot grants crit chance bonus (visible in Player.runtime_stats)
- [ ] Lucky Coin bonus designed and implemented (or marked for future)
- [ ] All utility items stack correctly with formulas (multiplicative/additive)
- [ ] Tested with 10 stacks of each item

### Part 2: FireballImpact Visual
- [ ] Root cause identified (documented in progress notes)
- [ ] Green poison variant works for item explosions
- [ ] Fire explosions stay orange/red (original color)
- [ ] Solution doesn't break existing fireball ability visuals

---

## 📊 Implementation Plan

### Phase 1: Utility Item Properties (1 hour)
1. Add @export properties to BaseItem.gd (pickup_radius_mult, crit_chance_bonus, luck_bonus)
2. Update ItemManager._apply_stat_bonuses() to handle new properties
3. Update ItemManager._remove_stat_bonuses() for unequip
4. Configure clover_gameplay.tres (pickup_radius_mult = 1.3)
5. Configure rabbits_foot_gameplay.tres (crit_chance_bonus = 0.1)
6. Test with ItemManager.equip_item() and verify Player.runtime_stats

### Phase 2: FireballImpact Investigation (30-60 min)
1. Read FireballImpact.tscn scene file
2. Check AnimatedSprite2D properties (material, blend mode)
3. Test direct modulate on scene instance
4. Try alternative approaches (shader, variant scene)
5. Document findings and chosen solution

### Phase 3: Implement Visual Solution (30-60 min)
**Option A: If modulate works**
```gdscript
// EffectSpawner.gd
func spawn_explosion(position: Vector2, damage: float, tint: Color = Color.WHITE):
    var explosion = EXPLOSION_SCENE.instantiate()
    explosion.global_position = position
    explosion.modulate = tint  # Apply color tint
    _arena.add_child(explosion)
```

**Option B: If shader needed**
```gdscript
// Create shader material with color multiplier
shader_type canvas_item;
uniform vec4 color_mult : source_color = vec4(1.0);
void fragment() {
    COLOR = texture(TEXTURE, UV) * color_mult;
}
```

**Option C: If variant scene needed**
- Duplicate FireballImpact.tscn → PoisonImpact.tscn
- Use green sprite row from impact atlas (row 3?)
- ItemManager spawns PoisonImpact for poison items

### Phase 4: Testing (30 min)
- Equip 10 Clovers → verify pickup radius increases
- Equip 10 Rabbits Foot → verify crit chance increases (if crit system exists)
- Spawn poison explosion → verify green tint
- Spawn fire explosion → verify orange/red preserved

---

## 🔗 Related Files

### Will Modify:
- [ ] `scripts/resources/items/BaseItem.gd` - Add utility properties
- [ ] `autoload/ItemManager.gd` - Apply/remove utility bonuses
- [ ] `data/content/items/clover_gameplay.tres` - Configure pickup radius
- [ ] `data/content/items/rabbits_foot_gameplay.tres` - Configure crit chance
- [ ] `autoload/EffectSpawner.gd` - Add tint parameter to spawn_explosion()

### Will Investigate:
- [ ] `scenes/effects/FireballImpact.tscn` - Visual effect structure
- [ ] `assets/sprites/impact_atlas.png` - Source texture variants

### Potentially Create:
- [ ] `scenes/effects/PoisonImpact.tscn` (if variant scene needed)
- [ ] `assets/shaders/color_multiply.gdshader` (if shader needed)

---

## 📝 Progress Notes

### 2025-10-14 - Task Created
- Extracted from ITEM-SYSTEM_1_implementation.md remaining work
- Phase 1 item system complete (poison, lightning, explosion, freeze all working)
- Utility item bonuses (clover, lucky_coin, rabbits_foot) need implementation
- FireballImpact self_modulate not working (investigation needed)

---

## 🚨 Open Questions

1. **Lucky Coin bonus:** What should this do? Options:
   - +X% chest quality (better loot rolls)
   - +X% drop rate (more items/currency)
   - +X% rare item chance
   - Mark as "future" and leave unimplemented for now?

2. **Crit system:** Does the game have crit chance/crit damage yet?
   - If yes: Apply crit_chance_bonus directly
   - If no: Store bonus for future crit system

3. **FireballImpact visual:** What's the preferred solution?
   - Option A: Direct modulate (simplest, if it works)
   - Option B: Shader material (flexible, more complex)
   - Option C: Variant scene (clean, more files)

---

**Status:** 🔴 Not Started
**Dependencies:** ITEM-SYSTEM_1_implementation.md Phase 1 ✅ Complete
**Next Action:** Add utility properties to BaseItem.gd and investigate FireballImpact.tscn
**Time Estimate:** 2-3 hours total
