# Strategic Content Placement System

> **Status**: Planning Phase - Requires Further Exploration
> **Priority**: Future Feature
> **Dependencies**: PathAware spawn zones API (`PathAwareMapConfig.get_effective_spawn_zones()`)

## Vision

Create a unified content placement system that leverages PathAware strategic positioning for all interactive elements beyond enemies - chests, shrines, NPCs, environmental storytelling elements, and other gameplay content.

## Current State

**Existing Infrastructure:**
- `PathAwareMapConfig.get_effective_spawn_zones()` - generates strategic positions from path analysis
- Strategic categories defined: `AT_ENDPOINTS`, `MAIN_CHECKPOINTS`, `IN_CLEARINGS`, `ALONG_BRANCHES`, etc.
- API designed but not yet integrated into active spawning pipeline

**Current Gap:**
- Only enemy spawning partially implemented
- No chest/treasure placement system
- No shrine/checkpoint placement system
- No interactive object placement system

## Strategic Categories for Content

Based on PathAware analysis, each category serves different gameplay purposes:

### Primary Content Zones
- **`AT_ENDPOINTS`**: Boss encounters, major treasure chests, quest completion points
- **`MAIN_CHECKPOINTS`**: Shrines, save points, major progression rewards, story beats
- **`IN_CLEARINGS`**: Merchant areas, rest spots, social hubs, large treasure caches

### Secondary Content Zones
- **`AT_BRANCH_ENDPOINTS`**: Hidden treasures, secret shrines, optional elite encounters
- **`ALONG_MAIN_PATH`**: Regular loot, environmental storytelling, minor interactables
- **`ALONG_BRANCHES`**: Side quest items, optional content, exploration rewards

## Proposed Content Managers

### Phase 1: Core Systems
```gdscript
# ChestManager - Treasure placement
func place_treasure_chests(map_config: MapConfig) -> void:
    var chest_zones = map_config.get_effective_spawn_zones().filter(
        func(zone): return zone.category in [ENDPOINTS, CLEARINGS, BRANCH_ENDPOINTS]
    )
    # Place chests with appropriate loot tables based on zone importance

# ShrineManager - Checkpoint/healing placement
func place_shrines(map_config: MapConfig) -> void:
    var shrine_zones = map_config.get_effective_spawn_zones().filter(
        func(zone): return zone.category == MAIN_CHECKPOINTS
    )
    # Place shrines at strategic progression points
```

### Phase 2: Enhanced Content
```gdscript
# NPCManager - Character placement
# EnvironmentalStorytellingManager - Lore placement
# InteractableManager - General interactive objects
# SecretManager - Hidden content placement
```

## Architecture Considerations

### Content Manager Pattern
- **API Consumer**: Use `get_effective_spawn_zones()` without knowing path analysis details
- **Category Filtering**: Each manager filters zones appropriate for its content type
- **Placement Logic**: Managers handle their own spawning rules and validation
- **Independence**: Content systems don't depend on each other

### Integration Points
- **GameOrchestrator**: Register content managers for dependency injection
- **EventBus**: Content discovery events (chest opened, shrine activated)
- **BalanceDB**: Loot tables, spawn rates, content configuration
- **ContentDB**: Item definitions, shrine effects, NPC data

## Exploration Areas Needed

### 1. Content Categorization
- What types of interactive content do we want?
- How should loot tables correlate with zone importance?
- What shrine/checkpoint mechanics fit the game loop?

### 2. Placement Algorithms
- How many chests per zone category?
- Should placement be deterministic or randomized?
- How to prevent content clustering or gaps?

### 3. Player Progression Integration
- How does content placement scale with player level?
- Should content density change based on difficulty?
- Integration with existing progression systems?

### 4. Procedural vs Manual Content
- Which content types benefit from procedural placement?
- When should designers manually place important content?
- How to blend procedural and manual placement?

## Technical Implementation Notes

### Leveraging Existing API
```gdscript
# Content managers as API consumers
var strategic_zones = map_config.get_effective_spawn_zones()

# Filter zones by gameplay intent
var boss_zones = strategic_zones.filter(func(z): return z.category == AT_ENDPOINTS)
var treasure_zones = strategic_zones.filter(func(z): return z.weight > 1.0)
var secret_zones = strategic_zones.filter(func(z): return z.category == BRANCH_ENDPOINTS)
```

### System Registration Pattern
```gdscript
# Follow existing GameOrchestrator dependency injection
func initialize_content_systems() -> void:
    chest_manager = ChestManager.new()
    shrine_manager = ShrineManager.new()

    systems["chest_manager"] = chest_manager
    systems["shrine_manager"] = shrine_manager
```

## Success Criteria

**Phase 1 Complete When:**
- [ ] Chests spawn at strategic PathAware locations
- [ ] Shrines appear at major checkpoints
- [ ] Content placement feels intentional, not random
- [ ] API cleanly separates path analysis from content logic

**Long-term Success:**
- [ ] Rich interactive world with varied content types
- [ ] Content placement enhances path-based level design
- [ ] Easy to add new content types without touching path analysis
- [ ] Content density and quality feels balanced across arena types

## Next Steps

1. **Research Phase**: Study content placement in similar games (PoE, Diablo, roguelikes)
2. **Design Phase**: Define content types and placement rules for vibe's game loop
3. **Prototype Phase**: Implement basic ChestManager as proof of concept
4. **Integration Phase**: Connect to existing progression and balance systems
5. **Polish Phase**: Fine-tune placement algorithms and content variety

---

**Dependencies**: PathAware arena generation, ContentDB, BalanceDB
**Related Systems**: SpawnDirector, PlayerProgression, EventBus
**Documentation**: Update when implementation begins