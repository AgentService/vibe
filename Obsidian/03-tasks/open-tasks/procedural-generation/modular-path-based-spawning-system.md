# Modular Path-Based Spawning System

**Created:** 2025-09-28
**Status:** 🟡 Planning
**Priority:** High
**Estimated Effort:** 1-2 Weeks

## 📋 Overview

Create a modular spawning system foundation based on PathAware_Forest that allows easy expansion of arena-related systems. The goal is to provide a solid base for various spawning mechanics (enemies, events, items, powerups) while ensuring they respect path boundaries and utilize available space efficiently.

### Key Requirements
- **Path-Aware Spawning**: All spawns must respect the generated path system to ensure they're within valid arena areas
- **Modular Design**: Easy to add new spawning systems without modifying core path logic
- **Space Detection**: Automatically detect available space between paths and boundaries
- **Multiple Spawn Types**: Support different spawn strategies (along paths, at endpoints, around paths, in clearings)
- **Visual Debugging**: Debug visualization for spawn areas and validation

## 🎯 Inspiration from BONK/Megabonk

Based on research, key features to adapt:
- **Wave-based spawning** with increasing complexity
- **Boss encounters at endpoints** (similar to branch ends)
- **Dynamic item/powerup placement** throughout arena
- **Movement-based gameplay** requiring open spaces
- **Progression-gated content** spawning in specific areas

## 🏗️ Revised System Architecture Design

**Based on Assessment:** Using PathAwareMapConfig subtype approach for clean separation while maintaining existing system compatibility.

### Core Components

#### 1. **PathAwareMapConfig** (New MapConfig Subtype)
Clean extension of existing MapConfig specifically for generated arenas.

```gdscript
# scripts/resources/PathAwareMapConfig.gd
extends MapConfig
class_name PathAwareMapConfig

# Path-specific fields only
@export var path_snapshot: PathAwarePathSnapshot
@export var spawn_profiles: Array[PathSpawnProfile] = []
@export var generation_seed: int = 0
@export var auto_optimize_spawns: bool = true

# Override to provide path-aware spawn zones
func get_effective_spawn_zones() -> Array[SpawnZone]:
    if path_snapshot and auto_optimize_spawns:
        return _generate_zones_from_paths()
    else:
        return spawn_zones  # Fall back to manual zones if any
```

#### 2. **PathAwarePathSnapshot** (New Resource)
Snapshot of generated path data for consumption by spawning systems.

```gdscript
# scripts/resources/PathAwarePathSnapshot.gd
extends Resource
class_name PathAwarePathSnapshot

# Core path geometry
@export var main_path_points: Array[Vector2] = []
@export var branch_data: Array[BranchInfo] = []
@export var connection_points: Array[ConnectionPoint] = []

# Derived spatial data
@export var path_corridors: Array[Corridor] = []      # Width-aware path segments
@export var clearings: Array[Clearing] = []           # Open areas between boundaries
@export var boundary_zones: Array[BoundaryZone] = []  # Tree/obstacle areas

# Spawn-relevant metadata
@export var endpoint_positions: Array[Vector2] = []
@export var checkpoint_positions: Array[Vector2] = []
@export var total_arena_bounds: Rect2
@export var generation_seed: int
@export var generation_timestamp: float
```

#### 3. **PathSpawnProfile** (New Resource)
Configuration for specific spawn system behaviors.

```gdscript
# scripts/resources/PathSpawnProfile.gd
extends Resource
class_name PathSpawnProfile

@export var system_name: String  # "enemies", "breach", "powerups"
@export var spawn_categories: Array[PathSpawnCategory] = []
@export var priority_weight: float = 1.0
@export var cooldown_hints: Dictionary = {}

enum PathSpawnCategory {
    ALONG_MAIN_PATH,
    ALONG_BRANCHES,
    AT_ENDPOINTS,
    IN_CLEARINGS,
    AROUND_PATHS
}
```

#### 4. **PathAwareSpaceService** (New Autoload)
Service layer providing path data to spawning systems.

```gdscript
# autoload/PathAwareSpaceService.gd
extends Node

var _arena_snapshots: Dictionary = {}  # arena_id -> PathAwarePathSnapshot
var _arena_configs: Dictionary = {}    # arena_id -> PathAwareMapConfig

func _ready():
    EventBus.arena_path_snapshot_ready.connect(_on_snapshot_ready)

func _on_snapshot_ready(arena_id: String, snapshot: PathAwarePathSnapshot):
    _arena_snapshots[arena_id] = snapshot
    _optimize_spatial_queries(arena_id, snapshot)

# Public API for spawn systems
func get_spawn_positions(arena_id: String, category: PathSpawnCategory) -> Array[Vector2]
func validate_spawn_area(arena_id: String, position: Vector2, radius: float) -> bool
```

#### 5. **Enhanced Arena Integration**
Minimal changes to Arena.gd for path-aware detection.

```gdscript
# scenes/arena/Arena.gd - add detection logic
func _setup_spawning_systems():
    if map_config is PathAwareMapConfig:
        _setup_path_aware_spawning(map_config as PathAwareMapConfig)
    else:
        _setup_traditional_spawning(map_config)

func _setup_path_aware_spawning(config: PathAwareMapConfig):
    # Use PathAwareSpaceService + optimized systems for generated arenas
    spawn_director.use_path_aware_mode(config.path_snapshot)

func _setup_traditional_spawning(config: MapConfig):
    # Existing logic unchanged - handmade arenas continue working
    spawn_director.use_zone_mode(config.spawn_zones)
```

#### 6. **PathAwareDebugVisualizer** (New Editor/Runtime Tool)
Creates lightweight overlays so designers can confirm spawn data before systems consume it.

```gdscript
# tools/debug/PathAwareDebugVisualizer.gd
@tool
extends Node2D
class_name PathAwareDebugVisualizer

@export var snapshot: PathAwarePathSnapshot
@export var display_categories: Array[PathSpawnCategory] = [
    PathSpawnCategory.ALONG_MAIN_PATH,
    PathSpawnCategory.ALONG_BRANCHES,
    PathSpawnCategory.AT_ENDPOINTS,
    PathSpawnCategory.IN_CLEARINGS,
    PathSpawnCategory.AROUND_PATHS,
]
@export var color_palette := {
    PathSpawnCategory.ALONG_MAIN_PATH: Color.CYAN,
    PathSpawnCategory.ALONG_BRANCHES: Color.MAGENTA,
    PathSpawnCategory.AT_ENDPOINTS: Color.YELLOW,
    PathSpawnCategory.IN_CLEARINGS: Color.GREEN,
    PathSpawnCategory.AROUND_PATHS: Color.ORANGE,
}

func _draw():
    if snapshot == null:
        return

    for category in display_categories:
        _draw_category(category)

func _draw_category(category: PathSpawnCategory) -> void:
    var positions := PathAwareSpaceService.get_spawn_positions(get_arena_id(), category)
    var color := color_palette.get(category, Color.WHITE)
    for position in positions:
        draw_circle(position, 12.0, color)
```

- Editor overlay toggles for designers (auto-refresh on path regeneration)
- Runtime debug mode (hotkey toggles, optional gizmo layers)
- Supports step-by-step visualization of corridors → points → spawn zones
- Ensures every `PathSpawnCategory` enum is visible and validated early

### Integration with Existing Systems

#### **PathAware_Forest Integration**
```gdscript
# scenes/arena/PathAware_Forest.gd - Updated to use PathAwareMapConfig
@export var map_config: PathAwareMapConfig  # Typed specifically for generated arenas

func _generate_arena():
    # ... existing generation logic ...

    # NEW: Create snapshot from generated data
    var snapshot = arena_generator.get_path_snapshot()

    # NEW: Populate PathAwareMapConfig
    map_config.path_snapshot = snapshot
    map_config.generation_seed = generation_seed

    # NEW: Emit ready signal for service registration
    EventBus.arena_path_snapshot_ready.emit(get_arena_id(), snapshot)
```

#### **PathAwareArenaGenerator Enhancement**
```gdscript
# scripts/systems/PathAwareArenaGenerator.gd - Add snapshot creation
func get_path_snapshot() -> PathAwarePathSnapshot:
    var snapshot = PathAwarePathSnapshot.new()

    # Core path data
    snapshot.main_path_points = current_path_data.get("points", [])
    snapshot.branch_data = _extract_branch_info()
    snapshot.connection_points = current_path_data.get("connections", [])

    # Derived spatial analysis
    snapshot.path_corridors = _calculate_corridors()
    snapshot.clearings = _detect_clearings()
    snapshot.boundary_zones = _analyze_boundaries()
    snapshot.endpoint_positions = _identify_endpoints()

    # Metadata
    snapshot.total_arena_bounds = _calculate_arena_bounds()
    snapshot.generation_seed = generation_seed
    snapshot.generation_timestamp = Time.get_ticks_msec()

    return snapshot
```

#### **Breach Event Integration**
```gdscript
# Enhanced BreachEventHandler.gd - Use PathAwareMapConfig detection
func spawn_breach_event() -> void:
    var arena = get_current_arena()
    if arena.map_config is PathAwareMapConfig:
        _spawn_breach_at_path_endpoint(arena.map_config as PathAwareMapConfig)
    else:
        _spawn_breach_traditional()  # Existing logic for handmade arenas

func _spawn_breach_at_path_endpoint(config: PathAwareMapConfig) -> void:
    var endpoints = config.path_snapshot.endpoint_positions
    if not endpoints.is_empty():
        var selected_endpoint = endpoints[randi() % endpoints.size()]
        _create_breach_at_position(selected_endpoint)
```

## ✨ Vibe Coding Principles
- Prefer typed Resources and arrays so tooling + autocompletion stay sharp.
- Document each public method with a one-line comment describing intent and expectations.
- Keep debug overlays opt-in (editor toggles + runtime hotkeys) to avoid shipping noise.
- Emit structured `Logger.debug()` messages (tagged `path_spawn`) for spawn decisions.
- Update the **Current State** section after every phase to keep progress transparent.


## 📊 Stepwise Implementation Plan

### **Milestone 0: Config & Snapshot Foundation** (1-2 days)

#### Phase 0.1: Resource Classes
- [ ] Create PathAwareMapConfig extending MapConfig
- [ ] Create PathAwarePathSnapshot resource class
- [ ] Create PathSpawnProfile resource class
- [ ] Stub supporting structs (BranchInfo, Corridor, Clearing, etc.) with TODO docs

#### Phase 0.2: Generator Snapshot Integration
- [ ] Add `get_path_snapshot()` to PathAwareArenaGenerator
- [ ] Implement spatial analysis helpers (`_calculate_corridors`, `_detect_clearings`, `_identify_endpoints`)
- [ ] Calculate arena bounds + metadata (seed, timestamp)
- [ ] Ensure generated data is deterministic per `generation_seed`

#### Phase 0.3: PathAware_Forest Wiring
- [ ] Export PathAwareMapConfig in PathAware_Forest
- [ ] Populate snapshot + seed after generation
- [ ] Emit `arena_path_snapshot_ready` EventBus signal
- [ ] Smoke-test snapshot contents in a debug print (remove before shipping)

**Success Criteria:** PathAware_Forest saves a populated snapshot into PathAwareMapConfig every time the arena regenerates.

### **Milestone 1: Visualization Sandbox (First Visible Win)** (1-2 days)

#### Phase 1.1: Debug Harness Scene
- [ ] Create `tools/debug/PathAwareVisualizerScene.tscn` loading PathAware_Forest + debug overlay
- [ ] Auto-refresh overlay when generator reseeds (editor + runtime)
- [ ] Provide keyboard toggle (`F6`) and editor inspector toggle

#### Phase 1.2: Category Coverage
- [ ] Hook PathAwareDebugVisualizer to `PathSpawnCategory` enums
- [ ] Render main path segments (cyan polylines)
- [ ] Render branch segments (magenta polylines)
- [ ] Render endpoint markers (yellow discs)
- [ ] Render clearings (green translucent circles)
- [ ] Render around-path buffer (orange rings)
- [ ] Add legend widget + color palette resource

#### Phase 1.3: Validation & QA
- [ ] Unit test: snapshot builds expected category buckets
- [ ] Guard against missing services (graceful fallback text)
- [ ] Document visualization workflow in `docs/path_aware_debug.md`

**Success Criteria:** Designers can open the debug scene and visually confirm every spawn category before any gameplay systems consume the data.

### **Milestone 2: Arena Detection & PathAwareSpaceService** (2-3 days)

#### Phase 2.1: Arena Detection Logic
- [ ] Add PathAwareMapConfig detection to Arena.gd
- [ ] Implement `_setup_path_aware_spawning()` and fallback path
- [ ] Update SpawnDirector init to set `_is_path_aware_mode`

#### Phase 2.2: PathAwareSpaceService Creation
- [ ] Create autoload with snapshot registration + caching
- [ ] Implement grid/quad-tree spatial acceleration
- [ ] Expose `get_spawn_positions()`, `validate_spawn_area()` APIs
- [ ] Forward debug overlay queries through the service (single source of truth)

#### Phase 2.3: SpawnDirector Bridge
- [ ] Add `use_path_aware_mode()` API (with docstring)
- [ ] Provide helper methods per category (e.g., `_pick_main_path_position()`)
- [ ] Emit structured logs for spawn decisions when debug mode enabled

**Success Criteria:** Arena.gd routes generated arenas into path-aware mode and debug visualizations pull data through PathAwareSpaceService.

### **Milestone 3: Enemy Spawning in Valid Spaces** (2-3 days)

#### Phase 3.1: Spatial Validation
- [ ] Clearance checks using corridor widths + entity radius
- [ ] Distance-to-boundary rejection
- [ ] Occupancy/reservation map for recent spawns
- [ ] Fallback search heuristics when preferred category is exhausted

#### Phase 3.2: Enemy Spawn Integration
- [ ] Wire SpawnDirector enemy routines to path-aware queries
- [ ] Ensure pack spawning honours spacing + density caps
- [ ] Maintain compatibility with analytics/kill tracking

**Success Criteria:** Enemy spawns respect path corridors automatically; handmade arenas still use traditional spawn zones unchanged.

### **Milestone 4: Breach Event Branch Integration** (2-3 days)

#### Phase 4.1: BreachEventHandler Path-Aware Branch
- [ ] Detect PathAwareMapConfig in event handler
- [ ] Select endpoints deterministically (support weighted rules)
- [ ] Validate breach radius fits before spawning portal

#### Phase 4.2: Advanced Breach Behaviour
- [ ] Scale breach intensity based on distance along path
- [ ] Allow multi-endpoint breaches (optional)
- [ ] Emit debug overlay for breach footprint

**Success Criteria:** Breach events spawn on valid endpoints with enough clearance and rich debug output.

### **Milestone 5: Extensibility & Polish** (2-3 days)

#### Phase 5.1: Spawn Profile System
- [ ] Implement PathSpawnProfile weighting + cooldown hints
- [ ] Add hot-reloadable configs under `data/content/arena_configs/pathaware`
- [ ] Provide sample profiles (enemies, loot, powerups)

#### Phase 5.2: Performance & Tooling
- [ ] Cache heavy calculations across frames
- [ ] Batch process spawn queries per tick
- [ ] Add Godot inspector helpers (buttons to preview each category)

#### Phase 5.3: QA & Documentation
- [ ] Expand automated tests (unit + headless scenes)
- [ ] Record GIF/clip of visualization for design docs
- [ ] Update `docs/path_aware_forest.md` and task **Current State**

#### Phase 5.4: Legacy System Cleanup Preparation
- [ ] Validate PathAware system stability and performance
- [ ] Confirm all spawn systems working reliably with PathAwareMapConfig
- [ ] Get design team approval for legacy system removal
- [ ] Execute [Legacy System Cleanup](legacy-system-cleanup.md) task

**Success Criteria:** System feels shippable for generated maps: fast, documented, and designer-friendly. Legacy system removed cleanly.



### **Week 1: Foundation & Core Spawning**
```
Day 1-2: Milestone 1 (PathAwareMapConfig Foundation)
Day 3-4: Milestone 2 (Arena Detection & Service)
Day 5: Milestone 3 Start (Enemy Spawning)
```

### **Week 2: Features & Integration**
```
Day 1-2: Milestone 3 Complete (Enemy Spawning)
Day 3-4: Milestone 4 (Breach Events)
Day 5: Milestone 5 (Extensibility & Polish)
```

## 🎯 Key Benefits of Revised Approach

### **Clean Separation**
- **Generated Arenas**: Use PathAwareMapConfig with optimized path-aware systems
- **Handmade Arenas**: Continue using MapConfig with existing zone-based systems
- **Zero Conflicts**: No mixing of incompatible configuration paradigms

### **Minimal System Impact**
- **Arena.gd**: Single detection check (`if map_config is PathAwareMapConfig`)
- **SpawnDirector**: Add path-aware mode alongside existing functionality
- **BreachEventHandler**: Add path-aware detection for endpoint spawning
- **Existing Systems**: Continue working unchanged

## 🎯 Technical Specifications

### **Performance Targets**
- **Space Query Time**: <1ms for spawn position requests
- **Validation Time**: <0.5ms per position validation
- **Memory Overhead**: <10MB for spatial optimization structures
- **Arena Analysis**: <100ms for complete space analysis

### **API Design Principles**
- **Type Safety**: All queries use typed resource classes
- **Performance**: Spatial optimization with caching
- **Modularity**: Clear separation between systems
- **Extensibility**: Easy to add new spawn types and systems

### **EventBus Integration**
```gdscript
# New signals for path-aware spawning
signal arena_space_data_ready(arena_id: String)
signal spawn_validation_requested(position: Vector2, requirements: SpawnRequirements)
signal spawn_area_calculated(area_data: Dictionary)
signal path_spawn_system_registered(system_name: String)
```

### **Resource Configuration Structure**
```
data/content/
├── spawn_systems/
│   ├── enemy_spawner_config.tres
│   ├── breach_spawner_config.tres
│   ├── item_spawner_config.tres
│   └── powerup_spawner_config.tres
├── path_spawn_templates/
│   ├── default_arena_spawn.tres
│   ├── boss_arena_spawn.tres
│   └── exploration_arena_spawn.tres
```

## 🚀 Future Expansion Opportunities

### **Post-MVP Features**
- **Dynamic Path Modification**: Runtime path changes affecting spawn areas
- **Procedural Spawn Patterns**: AI-driven spawn placement based on player behavior
- **Multi-Layer Arenas**: Vertical spawning with elevation-based rules
- **Seasonal Events**: Time-based spawn modifications and special areas
- **Narrative Triggers**: Story-driven spawn sequences tied to path progression

### **Advanced Spawn Systems**
- **Treasure Hunting**: Hidden loot in specific path intersections
- **Boss Arenas**: Dynamic boss spawn areas that modify path layout
- **Environmental Hazards**: Trap and hazard placement along paths
- **Player Progression Gates**: Unlock new areas as player advances
- **Cooperative Elements**: Multi-player spawn coordination

### **Performance Scaling**
- **Hierarchical Spatial Indexing**: Multi-level optimization for massive arenas
- **Distributed Processing**: Spawn calculation distribution across frames
- **Predictive Caching**: Pre-calculate likely spawn scenarios
- **LOD Spawning**: Distance-based spawn detail levels

## 🔧 Integration Points

### **With Existing Systems**
- **Arena.gd**: Coordinate system initialization
- **SpawnDirector.gd**: Enhanced with path-aware capabilities
- **BreachEventHandler.gd**: Branch endpoint integration
- **EventBus.gd**: New spawn-related signals
- **Balance System**: Configuration for spawn frequencies and requirements

### **New System Dependencies**
- **PathAwareSpaceService**: Central autoload dependency
- **SpawnLocationQuery**: Domain model for spawn requests
- **PathAwareSpawnValidator**: Validation service
- **SpawnSystemRegistry**: System coordination

## 📈 Success Metrics

### **Functional Requirements**
- [ ] Enemies spawn only in valid arena areas (no tree boundaries)
- [ ] Breaches spawn precisely at branch endpoints
- [ ] Full arena space utilization (no dead zones)
- [ ] Multiple systems can spawn independently
- [ ] Visual debugging shows all spawn areas clearly

### **Performance Requirements**
- [ ] <1ms spawn position queries
- [ ] <100ms arena analysis time
- [ ] No frame drops during spawn calculations
- [ ] Memory usage within acceptable limits

### **Architecture Requirements**
- [ ] Clean separation between path generation and spawning
- [ ] Easy to add new spawn system types
- [ ] Hot-reloadable configuration
- [ ] Comprehensive error handling and logging

---

## 🔄 Next Steps

1. Draft PathAwareMapConfig / PathAwarePathSnapshot resources (Milestone 0.1) and scaffold docstrings.
2. Hook snapshot export into PathAwareArenaGenerator + PathAware_Forest (Milestone 0.2/0.3).
3. Build the visualization sandbox scene and ensure every `PathSpawnCategory` renders (Milestone 1).
4. Update the **Current State** section with milestone outcomes after each phase.
5. Gather feedback from design once visualization is live before wiring gameplay systems.
6. **Execute legacy system cleanup** once all milestones complete (see [Legacy System Cleanup](legacy-system-cleanup.md))

## 📝 Current State

| Date       | Phase    | Notes |
|------------|----------|-------|
| 2025-09-28 | Planning | Document aligned to PathAwareMapConfig approach, visualization-first milestone defined, awaiting Milestone 0 kickoff. |
| 2025-01-09 | Milestone 1 - Visualization | PathSpawnCategory visualization implemented via editor plugin approach instead of standalone UI. All categories working (ALONG_MAIN_PATH, ALONG_BRANCHES, AT_ENDPOINTS, IN_CLEARINGS) except AROUND_PATHS. AROUND_PATHS logic removed due to performance issues - need spawnable layer approach for replacement. |

