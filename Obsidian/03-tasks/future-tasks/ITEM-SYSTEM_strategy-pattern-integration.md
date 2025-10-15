# Strategy Pattern Integration for Item System

**Created:** 2025-01-10
**Status:** 🟡 Planning
**Priority:** High
**Estimated Effort:** 3-4 weeks
**Category:** Item System / Architecture

## 📋 Task Description

Implement a comprehensive strategy pattern system that applies modular upgrades to abilities **after** tome/level calculations are complete. This system will power:

1. **Item System** - Items from the unlock shop (Rabbit's Foot, Cheese, etc.) will carry strategy collections
2. **Shrine System** - World shrines that grant temporary/permanent strategy upgrades
3. **Particle/Visual Strategies** - Dynamic visual effects and color modulation for abilities
4. **Specialized Ability Strategies** - Buff, Orbit, and other ability-specific enhancements

The strategy pattern sits as **Layer 5** in the modification pipeline:
```
Base Stats → Tome Modifiers → Level Scaling → Final Stats → 🆕 Strategy Application
```

## 🎯 Acceptance Criteria

- [ ] BaseAbilityStrategy resource system with tag-based targeting
- [ ] 4 strategy types: BulletStrategy, ParticleStrategy, BuffStrategy, OrbitStrategy
- [ ] ItemType resource linking items to strategy collections
- [ ] Shrine system with activation areas and strategy grants
- [ ] Strategy application at projectile/ability spawn time
- [ ] MultiMesh color modulation support via ParticleStrategy
- [ ] Scene-based visual variant selection support
- [ ] Tag system integration (strategies respect AbilityTags)
- [ ] Player strategy collection management (equip/unequip)
- [ ] Performance impact <5% for 100 active strategies

## 🔍 Technical Analysis

### Affected Systems
- [x] scripts/resources/ (NEW: strategies/, ItemType.gd)
- [x] scripts/resources/ (MODIFY: ItemMetadata.gd)
- [x] scripts/systems/ (MODIFY: AbilityController.gd)
- [x] scripts/resources/abilities/ (MODIFY: ProjectileAbility.gd, UtilityAbility.gd)
- [x] scenes/arena/ (MODIFY: Player.gd)
- [x] scenes/world/ (NEW: Shrine.gd)
- [x] data/content/ (NEW: strategies/, shrines/, CONVERT: items/)
- [x] autoload/ (POTENTIAL: StrategyManager.gd for caching/optimization)

### Dependencies & Patterns
- **EventBus Signals:** Potentially `strategy_applied`, `item_equipped`, `shrine_activated`
- **Resource Files:**
  - BaseAbilityStrategy.tres (base template)
  - 20+ strategy .tres files (pierce, bleed, fire, cold, aoe, etc.)
  - ItemType.tres definitions for all items
  - ShrineConfig.tres for shrine definitions
- **Performance Impact:**
  - Strategy application happens at spawn (not per-frame)
  - Tag filtering reduces overhead
  - Pre-calculated strategy lists per ability
- **Testing Strategy:**
  - Unit tests for tag matching (.gd standalone)
  - Integration tests with abilities (.tscn with autoloads)
  - Performance validation with 100+ strategies

## 📊 Implementation Plan

### Phase 1: Base Strategy Foundation (Days 1-3)
- [ ] Create `scripts/resources/strategies/BaseAbilityStrategy.gd`
  - Properties: `strategy_id`, `strategy_name`, `description`, `icon`, `applicable_tags`, `application_priority`
  - Methods: `can_apply_to_ability()`, `apply_to_instance()`, `get_preview_text()`
  - Validation: `validate()` returns Array[String]
- [ ] Create `scripts/domain/AbilityTags.gd` extensions (if needed)
  - Review existing tags: PROJECTILE, AOE, MELEE, BUFF, DEBUFF, ORBIT
  - Add missing tags for strategy targeting
- [ ] Create 4 strategy subclasses:
  - `BulletStrategy.gd` - Pierce, chain, aoe-on-impact, elemental damage
  - `ParticleStrategy.gd` - Visual effects, color modulation, scene variants
  - `BuffStrategy.gd` - Buff ability enhancements (duration, area, stacks)
  - `OrbitStrategy.gd` - Orbit ability behaviors (speed, count, radius)
- [ ] Test tag matching system with existing abilities

### Phase 2: Item System Integration (Days 4-7)
- [ ] Create `scripts/resources/ItemType.gd`
  - Extends Resource
  - Properties: `item_id`, `item_name`, `description`, `icon`, `rarity`, `strategies: Array[BaseAbilityStrategy]`
  - Links to ItemMetadata for unlock shop integration
- [ ] Expand `scripts/resources/ItemMetadata.gd`
  - Add `item_type_reference: ItemType` property
  - Maintain existing unlock shop properties
- [ ] Convert existing items to new format:
  - `data/content/items/rabbits_foot.tres` → ItemType with crit strategy
  - `data/content/items/cheese.tres` → ItemType with HP strategy
- [ ] Implement player item equip/unequip system
  - Add `equipped_items: Array[ItemType]` to Player or AbilityController
  - Method: `equip_item(item: ItemType)` → collects strategies
  - Method: `unequip_item(item: ItemType)` → removes strategies
- [ ] Create 5 example ItemType resources with strategies

### Phase 3: Bullet Strategy Implementation (Days 8-12)
- [ ] Implement BulletStrategy modifiers:
  - `pierce_bonus: int` - Additional pierce count
  - `chain_bonus: int` - Additional chain targets
  - `chain_radius_multiplier: float` - Chain range scaling
  - `aoe_on_impact: bool` - Explodes on hit
  - `aoe_radius: float` - Explosion radius
  - `elemental_conversion: String` - Converts damage to fire/cold/poison
  - `apply_on_hit_effect: String` - bleed, poison, ignite, freeze
  - `projectile_speed_multiplier: float` - Speed modification
- [ ] Integrate with ProjectileAbility:
  - Add `apply_strategies(bullet, context)` in spawn logic
  - Pass strategy context: `{"ability": self, "player": player, "enemies": nearby_enemies}`
  - Apply after tome/level bonuses calculated
- [ ] Create 8 BulletStrategy .tres examples:
  - Pierce +2, Chain +1, AOE on Impact, Fire Conversion
  - Poison on Hit, Speed +50%, Ice Conversion, Bleed on Hit
- [ ] Test with existing projectile abilities (focused_seeker, seeking_volley)

### Phase 4: Particle Strategy Implementation (Days 13-16)

**🎯 MVP Reference: Fireball Implementation (2025-01-13)**
The current fireball ability serves as the **prototype and MVP** for ParticleStrategy:
- ✅ **Impact effect scaling**: `FireballImpact.set_aoe_radius()` method demonstrates strategy-based visual scaling
- ✅ **Diameter-based calibration**: BASE_SCALE = 21.875 ensures visual matches gameplay (700px diameter)
- ✅ **Dynamic spawning**: `AbilityProjectile` spawns `impact_effect` PackedScene on collision
- ✅ **Element-specific visuals**: FireballImpact.tscn uses fire-themed sprites (Row 2 from impact atlas)
- ✅ **Non-looping animation**: 5 FPS, plays once to final frame (growth pattern)
- **Key insight**: This pattern generalizes to ANY element × ANY ability combination via strategy system

**Implementation Tasks:**
- [ ] Implement ParticleStrategy dual-mode support:
  - **MultiMesh Mode**: `color_modulation: Color`, `shader_params: Dictionary`
  - **Scene Mode**: `scene_variants: Dictionary` (element → scene path)
  - `spawn_particle_effect: PackedScene` - Impact/trail particles
  - `particle_lifetime: float` - Effect duration
  - `scales_with_aoe: bool` - Auto-scale like fireball (default: true)
  - `base_visual_radius: float` - Calibration reference (e.g., 350.0)
- [ ] Integrate with ProjectileAbility:
  - MultiMesh: Apply color via `MultiMeshManager.set_color_modulation()`
  - Scene-based: Load variant scene from `scene_variants` dictionary
  - Particle spawning: Instantiate particle scenes on spawn/impact
  - **Call `effect.set_aoe_radius()` if method exists** (fireball pattern)
- [ ] Create 6 ParticleStrategy .tres examples:
  - Fire Glow (red modulation), Ice Trail (blue modulation)
  - Poison Cloud (green particles), Lightning Arc (yellow glow)
  - Fire Scene Variant (→ FireballImpact.tscn), Cold Scene Variant (→ IceShatterImpact.tscn)
- [ ] Test with both MultiMesh and scene-based projectiles
- [ ] Generalize FireballImpact → BaseImpactEffect for element reuse

### Phase 5: Buff/Orbit Strategy Implementation (Days 17-20)
- [ ] Implement BuffStrategy modifiers:
  - `duration_multiplier: float` - Buff duration scaling
  - `area_multiplier: float` - AOE buff radius scaling
  - `stack_bonus: int` - Additional effect stacks
  - `refresh_on_cast: bool` - Reset duration instead of stacking
- [ ] Implement OrbitStrategy modifiers:
  - `orbit_radius_multiplier: float` - Orbit distance scaling
  - `orbit_speed_multiplier: float` - Rotation speed
  - `projectile_count_bonus: int` - Additional orbiting projectiles
  - `pierce_on_orbit: bool` - Orbiters pierce enemies
- [ ] Integrate with UtilityAbility (buff placeholder):
  - Add `apply_strategies(buff_instance, context)` hook
  - Future: Integrate with actual buff system when implemented
- [ ] Create OrbitAbility subclass (if needed):
  - Extend DamageAbility or create new branch
  - Orbit-specific properties: orbit_radius, orbit_speed, etc.
- [ ] Create 4 strategy .tres examples:
  - Buff Duration +50%, Buff Area +30%
  - Orbit Speed +100%, Orbit Projectiles +3

### Phase 6: Shrine System (Days 21-24)
- [ ] Create `scenes/world/Shrine.gd` (extends Area2D):
  - Properties: `shrine_config: ShrineConfig`, `activation_duration: float`, `cooldown: float`
  - Activation: Player stands in area for duration
  - Visual feedback: Progress bar, particle effects
  - Signals: `shrine_activated`, `shrine_ready`
- [ ] Create `scripts/resources/ShrineConfig.gd` (extends Resource):
  - Properties: `shrine_id`, `shrine_name`, `description`, `icon`
  - `granted_strategies: Array[BaseAbilityStrategy]`
  - `is_permanent: bool` - Permanent vs temporary boost
  - `duration: float` - If temporary, how long it lasts
- [ ] Integrate with Arena:
  - Place shrine nodes in arena scenes
  - Connect to Player strategy collection
  - EventBus integration: `EventBus.shrine_activated.emit(shrine_id, strategies)`
- [ ] Create 3 shrine types:
  - "Shrine of Piercing" - Grants Pierce +2 strategy
  - "Shrine of Elements" - Grants Fire Conversion strategy
  - "Shrine of Speed" - Grants Speed +50% strategy
- [ ] UI integration: Show active shrine buffs

### Phase 7: Player Integration & Management (Days 25-27)
- [ ] Add to Player or AbilityController:
  - `strategy_collection: Array[BaseAbilityStrategy]` - All active strategies
  - `item_strategies: Dictionary` - Item ID → strategies
  - `shrine_strategies: Dictionary` - Shrine ID → strategies (with expiry)
  - `temporary_strategies: Array` - Time-limited buffs
- [ ] Implement strategy management:
  - `add_strategy(strategy: BaseAbilityStrategy, source: String)` - Track source
  - `remove_strategy(strategy: BaseAbilityStrategy, source: String)`
  - `get_applicable_strategies(ability: BaseAbility) → Array[BaseAbilityStrategy]`
  - `update_temporary_strategies(delta: float)` - Remove expired
- [ ] Optimize strategy application:
  - Pre-calculate applicable strategies per ability (cache)
  - Invalidate cache on item equip/unequip
  - Sort by `application_priority` before applying
- [ ] Add strategy preview system:
  - Tooltip generation: Show what strategies will do
  - Item inspection: Display granted strategies
  - Shrine preview: Show buff before activation

### Phase 8: Testing & Validation (Days 28-30)
- [ ] Unit tests for tag matching:
  - Test `strategy.can_apply_to_ability(ability)` with various tag combinations
  - Test exclusive tag conflicts
  - Test priority sorting
- [ ] Integration tests:
  - Projectile + pierce strategy → verify pierce_count increases
  - Item equip → verify strategies added to collection
  - Shrine activation → verify temporary strategies expire
  - Multiple strategies → verify stacking/conflicts resolved
- [ ] Performance validation:
  - Benchmark 100 strategies on 50 projectiles spawned/sec
  - Target: <5% overhead vs baseline
  - Profile tag matching and cache effectiveness
- [ ] Edge case testing:
  - Conflicting strategies (fire + cold conversion)
  - Stack limits and duplicate prevention
  - Strategy removal mid-application
  - Invalid tag references

### Phase 9: Documentation & Finalization (Days 31-33)
- [ ] Update `scripts/resources/CLAUDE.md`:
  - Document strategy pattern architecture
  - Add usage examples for each strategy type
  - Document tag matching system
- [ ] Update `scripts/systems/CLAUDE.md`:
  - Document AbilityController strategy integration
  - Add performance notes and optimization patterns
- [ ] Update `data/README.md`:
  - Document strategy .tres schema
  - Document ItemType .tres schema
  - Document ShrineConfig .tres schema
  - Add creation guide for new strategies
- [ ] Create `Obsidian/systems/Strategy-Pattern-Architecture.md`:
  - Comprehensive architecture doc
  - Integration patterns with existing systems
  - Migration guide from old item system
- [ ] Update `CHANGELOG.md`:
  - Document strategy pattern addition
  - Document item system changes
  - Document shrine system addition

## 🔗 Related Files

### Will Create (NEW):
- [ ] `scripts/resources/strategies/BaseAbilityStrategy.gd`
- [ ] `scripts/resources/strategies/BulletStrategy.gd`
- [ ] `scripts/resources/strategies/ParticleStrategy.gd`
- [ ] `scripts/resources/strategies/BuffStrategy.gd`
- [ ] `scripts/resources/strategies/OrbitStrategy.gd`
- [ ] `scripts/resources/ItemType.gd`
- [ ] `scripts/resources/ShrineConfig.gd`
- [ ] `scenes/world/Shrine.gd`
- [ ] `data/content/strategies/bullet/*.tres` (8 examples)
- [ ] `data/content/strategies/particle/*.tres` (6 examples)
- [ ] `data/content/strategies/buff/*.tres` (2 examples)
- [ ] `data/content/strategies/orbit/*.tres` (2 examples)
- [ ] `data/content/shrines/*.tres` (3 examples)
- [ ] `Obsidian/systems/Strategy-Pattern-Architecture.md`

### Will Modify (EXISTING):
- [ ] `scripts/resources/ItemMetadata.gd` (add ItemType link)
- [ ] `scripts/systems/AbilityController.gd` (add strategy management)
- [ ] `scripts/resources/abilities/ProjectileAbility.gd` (add strategy application)
- [ ] `scripts/resources/abilities/UtilityAbility.gd` (add strategy hooks)
- [ ] `scenes/arena/Player.gd` (add item equip/strategy management)
- [ ] `data/content/items/*.tres` (convert to ItemType format)

### Documentation Updates Needed:
- [ ] `scripts/resources/CLAUDE.md`
- [ ] `scripts/systems/CLAUDE.md`
- [ ] `scripts/domain/CLAUDE.md`
- [ ] `data/README.md`
- [ ] `Obsidian/systems/Strategy-Pattern-Architecture.md` (NEW)

## 📝 Progress Notes

### 2025-01-10 - Planning
- Initial task creation and architecture analysis
- Researched Godot Resource patterns via Context7
- Analyzed existing tome system for compatibility
- Confirmed strategy pattern sits after tome/level calculations
- Identified 4 strategy types needed: Bullet, Particle, Buff, Orbit
- **Key Decision**: Strategies apply at spawn time, not during ability template modification (unlike tomes)
- **Key Decision**: Use tag-based targeting like tomes for consistency

## 🚨 Risks & Considerations

### Performance Risks
- **Risk**: Strategy tag matching on every projectile spawn (200-500 projectiles/sec in late game)
- **Mitigation**: Pre-calculate applicable strategies per ability, cache by ability_id, invalidate on strategy collection change
- **Risk**: Deep copying strategies for context passing
- **Mitigation**: Pass strategy references, not copies; strategies are immutable Resources

### Architecture Risks
- **Risk**: Conflicts between tome modifiers and strategies
- **Mitigation**: Clear layering: Tomes modify template → Strategies modify instances. No overlap in properties.
- **Risk**: Circular dependencies (Item → Strategy → Ability → Item)
- **Mitigation**: One-way flow: Items carry strategies, strategies modify abilities, abilities don't reference items

### Integration Risks
- **Risk**: MultiMesh projectiles don't support per-instance data (colors, effects)
- **Mitigation**: ParticleStrategy uses global color modulation + shader params. Individual colors require scene-based projectiles.
- **Risk**: Buff/Orbit abilities not yet implemented
- **Mitigation**: Create strategy interface now, implement actual application when buff system exists. Use placeholder hooks.

### Testing Challenges
- **Risk**: Hard to validate strategy combinations (100s of permutations)
- **Mitigation**: Focus on core combinations (pierce + fire, aoe + poison). Document known conflicts.
- **Risk**: Temporary strategy expiry timing
- **Mitigation**: Use 30Hz combat_step for deterministic expiry. Test with fast-forward simulation.

## 📚 Official Godot Documentation Research

### Relevant Concepts from Godot Docs:

**Resource System (@export pattern):**
```gdscript
# From official docs - Custom resources with exported properties
class_name BotStats
extends Resource

@export var health: int
@export var sub_resource: Resource
@export var strings: PackedStringArray
```

**Best Practices:**
- Use `class_name` for resources that will be referenced in Inspector
- `@export` properties hot-reload automatically when .tres files change
- Resources should be stateless and reusable (don't store runtime state)
- Use `_init()` for default values if needed by editor

**Strategy Pattern Application:**
```gdscript
# BaseAbilityStrategy will follow this pattern
class_name BaseAbilityStrategy
extends Resource

@export var strategy_id: String
@export var strategy_name: String
@export var applicable_tags: Array[String] = []
@export var application_priority: int = 0

# Virtual method for subclasses
func apply_to_instance(entity: Node, context: Dictionary) -> void:
    pass
```

### Performance Considerations from Docs:
- **Resource Loading**: Use `preload()` for resources needed at scene start, `load()` for dynamic loading
- **Resource Caching**: Godot automatically caches loaded resources by path
- **Array Performance**: `Array[Type]` typed arrays are faster than `Array` generic
- **Dictionary Lookups**: Use for sparse data, avoid for hot-path iterations

### Examples from Documentation:
- Custom resource types with validation methods
- Resource inheritance hierarchies (BotStats → Stats → Resource)
- Inspector integration with `@tool` annotation
- Resource save/load with `ResourceSaver` and `ResourceLoader`

## ✅ Definition of Done

- [ ] All 4 strategy types implemented and tested
- [ ] 18+ strategy .tres examples created
- [ ] Item system converted to ItemType format
- [ ] 3+ shrine types implemented and placed in arena
- [ ] Player can equip items and receive strategies
- [ ] Strategies apply correctly to projectiles/abilities
- [ ] MultiMesh color modulation working
- [ ] Scene-based visual variants working
- [ ] Tag matching system validated with unit tests
- [ ] Performance validated: <5% overhead for 100 strategies
- [ ] All documentation updated (4+ CLAUDE.md files)
- [ ] CHANGELOG.md updated with feature summary
- [ ] Architecture doc created in Obsidian/systems/
- [ ] Code follows vibe project patterns (typed GDScript, EventBus signals, Logger)
- [ ] No `print()` statements (all logging via Logger)
- [ ] Commit ready with conventional format: `feat(items): strategy pattern integration with shrine system`

## 🔮 Future Extensions (Post-MVP)

### Strategy Enhancements
- **Conditional Strategies** - Triggered by specific events (low HP, kill streak, etc.)
- **Temporary Buff Strategies** - Duration-based effects from skills
- **Strategy Evolution** - Strategies that upgrade based on conditions
- **Strategy Synergies** - Combinations that unlock bonus effects

### System Enhancements
- **Strategy Trees** - Prerequisites and unlock paths
- **Strategy Crafting** - Combine basic strategies into advanced ones
- **Strategy Trading** - Multiplayer strategy exchange (future)
- **Strategy Persistence** - Save/load strategy collections

### Performance Optimizations
- **Strategy Pooling** - Object pools for frequently used strategies
- **Batch Application** - Apply multiple strategies in single pass
- **GPU Strategies** - Move some visual strategies to shaders
- **Lazy Evaluation** - Only calculate strategies when needed

---

**Status**: 🟡 **PLANNING COMPLETE**
**Next Phase**: Phase 1 - Base Strategy Foundation
**Integration Ready**: Aligns with existing tome/ability architecture
**Last Updated**: 2025-01-10

`★ Insight ─────────────────────────────────────`
**Architectural Layering**: This strategy pattern sits at Layer 5 (post-calculation) vs tomes at Layer 2 (pre-calculation). This separation allows tomes to set baselines while strategies add dynamic modifiers. It's analogous to PoE's support gems (tomes) vs. item affixes (strategies) - both modify skills but at different points in the calculation chain.
`─────────────────────────────────────────────────`
