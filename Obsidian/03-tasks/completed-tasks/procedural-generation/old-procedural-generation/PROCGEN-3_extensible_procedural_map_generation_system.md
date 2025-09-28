# Extensible Procedural Map Generation System

**Date**: 2025-09-23
**Status**: 🚧 IN PROGRESS
**Type**: System Architecture Extension
**Parent Task**: [Forest Arena Procedural Generation](2025-09-22_forest_arena_procedural_generation.md)

## Overview

Extend the forest-specific procedural generation system into a general, tileset-agnostic framework that can generate diverse biome types (swamp, desert, winter, etc.) without requiring separate plugins. Implement proper z-ordering for tree bases, add rich object/decoration generation, and integrate with hideout for seamless procedural map access.

## Objectives

### 🎯 Primary Goals

1. **Generalize Forest Generator**: Abstract tileset-specific logic into a configurable system
2. **Tree Base Z-Ordering**: Implement proper player-behind-tree rendering with base collision
3. **Rich Object System**: Add interactive objects, decorations, and environmental elements
4. **Hideout Integration**: Create seamless entry to procedural maps via E key interaction
5. **Multi-Biome Support**: Enable easy addition of new biomes (swamp, desert, winter)

### 🎮 User Experience Goals

- **Seamless Exploration**: Enter procedural maps from hideout like normal arenas
- **Visual Polish**: Proper depth layering with trees and objects
- **Biome Variety**: Multiple distinct environments without code duplication
- **Interactive Environment**: Objects that enhance gameplay and immersion

## System Architecture Design

### 🏗️ Core Architecture: Abstract Generator Framework

**★ Insight ─────────────────────────────────────**
• The current ForestArenaGenerator is tileset-specific with hardcoded coordinates
• A general system needs BiomeConfig resources that define tile mappings per tileset
• Z-ordering requires separate TileMapLayers for base vs. top elements (tree base vs. tree canopy)
**─────────────────────────────────────────────────**

#### New Class Structure

```gdscript
# scripts/systems/ProceduralArenaGenerator.gd - General generator
class_name ProceduralArenaGenerator
extends Node2D

@export var biome_config: BiomeConfig  # Configurable biome data
@export var generation_params: GenerationParams  # Size, density, etc.

# Core generation phases (biome-agnostic)
func generate_arena() -> void:
    _generate_floor_layer()
    _generate_boundary_layer()
    _generate_base_objects()     # Tree bases, rock foundations
    _generate_top_objects()      # Tree canopies, tall decorations
    _generate_interactive_objects()  # Chests, ruins, etc.
```

```gdscript
# scripts/resources/BiomeConfig.gd - Tileset-agnostic configuration
class_name BiomeConfig
extends Resource

@export var biome_name: String
@export var tileset_resource: TileSet

# Tile category mappings (coordinates in tileset)
@export var floor_tiles: Array[Vector2i] = []
@export var boundary_tiles: Array[Vector2i] = []
@export var decoration_tiles: Array[Vector2i] = []

# Object definitions (base + top for z-ordering)
@export var tree_objects: Array[TreeObjectConfig] = []
@export var interactive_objects: Array[InteractiveObjectConfig] = []
```

#### Z-Ordering Architecture

```
TileMapLayer Structure:
├── Ground (z_index: 0)          # Floor tiles
├── ObjectBases (z_index: 1)     # Tree bases, collision foundations
├── Decorations (z_index: 2)     # Small objects, bushes
├── ObjectTops (z_index: 10)     # Tree canopies, tall elements
└── Interactive (z_index: 5)     # Chests, ruins (player interaction)
```

**Tree Z-Ordering Pattern:**
- **Tree Base**: ObjectBases layer - provides collision, player can't walk through
- **Tree Canopy**: ObjectTops layer - visual only, player walks behind naturally
- **Player**: z_index: 6 (between ObjectBases and ObjectTops)

### 🌲 Tree Base System Implementation

#### Tree Object Configuration

```gdscript
# scripts/resources/TreeObjectConfig.gd
class_name TreeObjectConfig
extends Resource

@export var tree_name: String
@export var base_tile: Vector2i      # Collision tile (ObjectBases layer)
@export var canopy_tile: Vector2i    # Visual tile (ObjectTops layer)
@export var base_collision_shape: PackedScene  # StaticBody2D for collision
@export var placement_weight: float = 1.0
```

#### Generation Process

```gdscript
func _generate_tree_objects(rng: RandomNumberGenerator) -> void:
    for boundary_pos in boundary_positions:
        if _should_place_tree(boundary_pos, rng):
            var tree_config = biome_config.get_random_tree_object(rng)

            # Place base (collision + visual base)
            object_bases_layer.set_cell(boundary_pos, tree_config.base_tile)
            _add_tree_collision(boundary_pos, tree_config)

            # Place canopy (visual only, player walks behind)
            object_tops_layer.set_cell(boundary_pos, tree_config.canopy_tile)
```

### 🎨 Rich Object and Decoration System

#### Object Categories

1. **Environmental Objects**
   - **Trees**: Base + canopy with collision
   - **Rocks**: Collision boundaries, ore deposits
   - **Water Features**: Ponds, streams (navigation obstacles)

2. **Interactive Objects**
   - **Treasure Chests**: Loot containers
   - **Ancient Ruins**: Lore/quest elements
   - **Resource Nodes**: Harvestable materials
   - **Shrine Points**: Buff/heal stations

3. **Atmospheric Decorations**
   - **Ground Cover**: Flowers, grass patches, fallen logs
   - **Particle Emitters**: Fireflies, mist, falling leaves
   - **Ambient Objects**: Skulls, camp remains, stone circles

#### Implementation Architecture

```gdscript
# scripts/systems/ObjectPlacementSystem.gd
class_name ObjectPlacementSystem
extends RefCounted

static func place_interactive_objects(
    arena: Node2D,
    biome_config: BiomeConfig,
    placement_params: ObjectPlacementParams,
    rng: RandomNumberGenerator
) -> void:
    # Zone-based placement for gameplay balance
    var zones = _calculate_object_zones(arena.get_arena_bounds())

    for zone in zones:
        _place_zone_objects(zone, biome_config, placement_params, rng)

func _place_zone_objects(zone: Rect2i, config: BiomeConfig, params: ObjectPlacementParams, rng: RandomNumberGenerator) -> void:
    # Ensure balanced distribution across arena
    var chest_count = _calculate_chest_count_for_zone(zone, params)
    var decoration_count = _calculate_decoration_count_for_zone(zone, params)

    _place_treasure_chests(zone, config, chest_count, rng)
    _place_atmospheric_decorations(zone, config, decoration_count, rng)
```

### 🏠 Hideout Integration for Procedural Map Access

#### Hideout Enhancement Architecture

```gdscript
# scripts/systems/ProceduralMapPortal.gd
class_name ProceduralMapPortal
extends Area2D

@export var portal_name: String = "Procedural Exploration"
@export var available_biomes: Array[BiomeConfig] = []
@export var map_difficulty_scaling: DifficultyConfig

signal portal_activated(biome_config: BiomeConfig)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        _show_biome_selection_ui()

func _show_biome_selection_ui() -> void:
    # UI overlay for biome selection
    var selection_modal = ProceduralMapSelectionModal.new()
    selection_modal.setup_biome_options(available_biomes)
    selection_modal.biome_selected.connect(_on_biome_selected)
    UIManager.show_modal(selection_modal)
```

#### StateManager Integration

```gdscript
# Update StateManager for procedural arena flow
enum GameState {
    MENU,
    CHARACTER_SELECT,
    HIDEOUT,
    ARENA,
    PROCEDURAL_ARENA,  # New state for generated maps
    RESULTS
}

# Transition: HIDEOUT → PROCEDURAL_ARENA → RESULTS → HIDEOUT
func transition_to_procedural_arena(biome_config: BiomeConfig) -> void:
    current_state = GameState.PROCEDURAL_ARENA
    _load_procedural_arena_scene(biome_config)
```

## Implementation Plan

### 📋 Phase 1: Abstract Generator Framework

**Goal**: Create tileset-agnostic generation system

#### Tasks
1. **Abstract ForestArenaGenerator**
   - Create `ProceduralArenaGenerator` base class
   - Extract tileset-specific logic to `BiomeConfig` resource
   - Implement biome resource loading system

2. **Create BiomeConfig System**
   - Design `BiomeConfig` resource class
   - Create forest biome configuration (migrate from ForestTileMapping)
   - Add swamp biome configuration as proof of concept

3. **Layer Architecture Setup**
   - Define standard TileMapLayer structure (5 layers)
   - Implement z-index ordering system
   - Create layer management utilities

**Acceptance Criteria:**
- [ ] ForestArena works identically with new ProceduralArenaGenerator
- [ ] Swamp biome generates correctly using different tileset
- [ ] All 5 TileMapLayers render with proper z-ordering

### 📋 Phase 2: Tree Base Z-Ordering System

**Goal**: Implement proper player-behind-tree rendering

#### Tasks
1. **Tree Object System**
   - Create `TreeObjectConfig` resource
   - Implement base + canopy placement logic
   - Add collision shape generation for tree bases

2. **Z-Index Architecture**
   - Configure ObjectBases layer (z_index: 1)
   - Configure ObjectTops layer (z_index: 10)
   - Set player z_index: 6 for proper sorting

3. **Collision Integration**
   - Generate StaticBody2D collision for tree bases
   - Ensure canopy tiles are visual-only (no collision)
   - Test player navigation around trees

**Acceptance Criteria:**
- [ ] Player walks behind tree canopies naturally
- [ ] Tree base collision prevents walking through trunk
- [ ] Performance remains >60 FPS with complex tree layouts

### 📋 Phase 3: Rich Object and Decoration System

**Goal**: Add interactive objects and atmospheric elements

#### Tasks
1. **Interactive Object Framework**
   - Create `InteractiveObjectConfig` resource system
   - Implement treasure chest placement and interaction
   - Add shrine/buff station objects

2. **Atmospheric Decoration System**
   - Ground cover decoration placement
   - Particle effect integration (fireflies, mist)
   - Ambient object distribution (skull piles, camp remains)

3. **Zone-Based Object Placement**
   - Implement ObjectPlacementSystem for balanced distribution
   - Create difficulty-based object scaling
   - Add object density configuration per biome

**Acceptance Criteria:**
- [ ] Treasure chests spawn with balanced distribution
- [ ] Atmospheric decorations enhance visual appeal
- [ ] Interactive objects integrate with existing game systems

### 📋 Phase 4: Hideout Integration

**Goal**: Seamless procedural map access from hideout

#### Tasks
1. **Portal System Implementation**
   - Create ProceduralMapPortal Area2D with E key interaction
   - Implement biome selection UI modal
   - Add portal placement in hideout scene

2. **StateManager Extension**
   - Add PROCEDURAL_ARENA state
   - Implement transition flow: HIDEOUT → PROCEDURAL_ARENA → RESULTS
   - Add return-to-hideout functionality

3. **Scene Management**
   - Dynamic procedural arena scene loading
   - Proper cleanup when exiting procedural maps
   - Progress persistence between hideout and procedural areas

**Acceptance Criteria:**
- [ ] E key interaction opens biome selection in hideout
- [ ] Smooth scene transitions to/from procedural arenas
- [ ] Player progress persists correctly across transitions

### 📋 Phase 5: Multi-Biome Expansion

**Goal**: Add multiple distinct biomes with unique gameplay

#### Additional Biomes
1. **Swamp Biome**
   - Murky water features and fallen logs
   - Poisonous gas pools (environmental hazards)
   - Twisted trees with hanging moss

2. **Desert Biome**
   - Sand dunes and rock formations
   - Cactus barriers and oasis features
   - Ancient pyramid ruins with treasures

3. **Winter Biome**
   - Snow-covered ground with ice patches
   - Frozen trees and icicle barriers
   - Frozen lakes and warming campfires

#### Unique Biome Features
- **Environmental Hazards**: Poison pools, ice slips, sandstorms
- **Biome-Specific Objects**: Desert pyramids, swamp gas vents, winter shelters
- **Adaptive Enemy Spawning**: Biome-appropriate enemy types

**Acceptance Criteria:**
- [ ] Each biome has distinct visual identity and gameplay
- [ ] Environmental hazards integrate with damage system
- [ ] Biome-specific objects enhance exploration experience

## Technical Implementation Details

### 🔧 File Structure Changes

```
New Files:
├── scripts/systems/ProceduralArenaGenerator.gd      # Abstract generator
├── scripts/systems/ObjectPlacementSystem.gd        # Object distribution
├── scripts/systems/ProceduralMapPortal.gd         # Hideout portal
├── scripts/resources/BiomeConfig.gd                # Biome configuration
├── scripts/resources/TreeObjectConfig.gd           # Tree base+canopy
├── scripts/resources/InteractiveObjectConfig.gd    # Chests, shrines
├── scripts/resources/GenerationParams.gd           # Size, density params
├── data/content/biomes/ForestBiome.tres           # Forest configuration
├── data/content/biomes/SwampBiome.tres            # Swamp configuration
├── scenes/ui/ProceduralMapSelectionModal.tscn     # Biome selection UI
└── scenes/arena/ProceduralArena.tscn              # Dynamic arena template

Modified Files:
├── scenes/arena/ForestArena.tscn                   # Migrate to new generator
├── autoload/StateManager.gd                       # Add PROCEDURAL_ARENA
└── scenes/hideout/Hideout.tscn                    # Add portal placement
```

### 🎨 TileMapLayer Configuration

```gdscript
# Standard layer setup for all biomes
Ground (z_index: 0):
  - Floor tiles, paths, ground cover
  - Collision: false

ObjectBases (z_index: 1):
  - Tree bases, rock foundations
  - Collision: true (StaticBody2D children)

Decorations (z_index: 2):
  - Small bushes, ground decorations
  - Collision: false

Interactive (z_index: 5):
  - Chests, shrines, harvestable nodes
  - Collision: true (Area2D for interaction)

ObjectTops (z_index: 10):
  - Tree canopies, tall visual elements
  - Collision: false (player walks behind)
```

### 🎮 Performance Considerations

**Generation Performance:**
- **Target**: <100ms generation time for 40x30 arena
- **Optimization**: Pre-compute object placement zones
- **Memory**: Reuse TileMapLayer nodes, avoid scene instancing during generation

**Runtime Performance:**
- **Target**: 60+ FPS with 100+ objects and complex layering
- **Z-Index Limits**: Max 5 layers to avoid excessive sorting
- **Collision Optimization**: Use simple collision shapes for tree bases

### 🔧 Integration with Existing Systems

**SimpleTileSpawnValidator Integration:**
```gdscript
# Extend spawn validator for multi-layer support
func cache_procedural_arena_tiles(arena: ProceduralArenaGenerator) -> void:
    # Cache ground tiles from Ground layer
    _cache_layer_tiles(arena.ground_layer, "ground")

    # Cache interactive positions from Interactive layer
    _cache_layer_tiles(arena.interactive_layer, "interactive")
```

**EventBus Integration:**
```gdscript
# New signals for procedural system
signal procedural_arena_generated(biome_name: String, generation_stats: Dictionary)
signal interactive_object_activated(object_id: String, object_type: String)
signal biome_portal_entered(available_biomes: Array[String])
```

## Testing Strategy

### 🧪 Test Coverage Plan

1. **Unit Tests**
   - BiomeConfig resource loading and validation
   - ObjectPlacementSystem zone calculation
   - TreeObjectConfig collision generation

2. **Integration Tests**
   - ProceduralArenaGenerator with multiple biomes
   - Z-ordering correctness across all layers
   - Portal system state transitions

3. **Performance Tests**
   - Generation time benchmarks (<100ms target)
   - Runtime FPS with complex object layouts (60+ FPS target)
   - Memory usage during multiple biome switches

4. **Visual Tests**
   - Screenshot comparison for biome consistency
   - Z-ordering validation (player behind canopies)
   - Interactive object accessibility

### 🎯 Success Metrics

**Functional Success:**
- [ ] All 4 biomes generate correctly with unique visuals
- [ ] Tree z-ordering works perfectly (player behind canopies)
- [ ] Portal integration is seamless and intuitive
- [ ] Interactive objects enhance gameplay experience

**Performance Success:**
- [ ] Generation time <100ms for 40x30 arena
- [ ] Runtime performance >60 FPS with 100+ objects
- [ ] Memory usage stable across biome transitions

**User Experience Success:**
- [ ] Biome selection feels natural in hideout
- [ ] Visual polish meets or exceeds current arena quality
- [ ] System extensibility proven with 4 distinct biomes

## Future Enhancements

### 🚀 Advanced Features (Post-MVP)

1. **Dynamic Generation**
   - Real-time arena expansion during gameplay
   - Procedural quest objective placement
   - Seasonal biome variations

2. **Environmental Gameplay**
   - Destructible trees and rocks
   - Weather effects affecting visibility/movement
   - Day/night cycles with different spawns

3. **Social Features**
   - Shared procedural maps with friends
   - Custom biome creation tools
   - Community-generated content

## Risk Assessment

### ⚠️ Potential Challenges

1. **Z-Ordering Complexity**
   - **Risk**: Player sorting issues with complex object layouts
   - **Mitigation**: Extensive testing, fallback to simple z-index system

2. **Performance with Many Objects**
   - **Risk**: FPS drops with 100+ interactive objects
   - **Mitigation**: Object pooling, LOD system for distant objects

3. **Biome Balance**
   - **Risk**: Some biomes more appealing than others
   - **Mitigation**: Playtesting, biome-specific rewards

4. **Code Complexity Growth**
   - **Risk**: System becomes unwieldy with many biomes
   - **Mitigation**: Strong abstraction layers, good documentation

## Success Criteria Summary

### ✅ MVP Definition

**Core Features Complete:**
- [ ] 4 biomes working (Forest, Swamp, Desert, Winter)
- [ ] Tree base z-ordering implemented
- [ ] Interactive objects placed and functional
- [ ] Hideout portal system working
- [ ] Performance targets met

**Quality Standards:**
- [ ] Follows all project architecture patterns
- [ ] Comprehensive testing coverage
- [ ] Documentation updated
- [ ] Performance benchmarks passed

**User Experience:**
- [ ] Seamless integration with existing game flow
- [ ] Visual quality matches or exceeds existing arenas
- [ ] Intuitive biome selection and navigation

---

**Implementation Timeline**: 2-3 weeks for MVP (Phases 1-4)
**Review Points**: End of each phase for quality validation
**Integration Strategy**: Continuous integration with existing systems, no breaking changes