# Spawnable Layer Generator Implementation

**Created:** 2025-01-09
**Status:** 🟡 Planning
**Priority:** High
**Estimated Effort:** 3-4 Days

## 📋 Task Description

Implement a dedicated spawnable layer system that generates valid spawn areas during map creation and provides efficient runtime spawn validation. This system replaces the removed AROUND_PATHS logic with a deterministic, boundary-aware approach that integrates seamlessly with the existing PathAwareArenaGenerator and tilemap architecture.

The spawnable layer will be a hidden TileMapLayer that marks all valid spawn positions during arena generation, allowing spawn systems to quickly query for valid positions without expensive runtime calculations.

## 🎯 Acceptance Criteria

- [ ] SpawnableLayerGenerator creates valid spawn tiles during arena generation
- [ ] SpawnableLayerService autoload provides <1ms spawn position queries
- [ ] Spatial partitioning enables efficient lookups for large arenas
- [ ] Integration with PathAwareArenaGenerator follows existing layer patterns
- [ ] SpawnDirector uses spawnable layer with fallback to radius-based spawning
- [ ] EventBus integration follows project signal patterns
- [ ] Performance metrics and logging throughout the system
- [ ] Hot-reloadable configuration via .tres resources
- [ ] Visual debug mode for spawn area visualization
- [ ] Complete replacement of AROUND_PATHS functionality

## 🔍 Technical Analysis

### Affected Systems
- [x] **scripts/systems/PathAwareArenaGenerator.gd** - Add spawnable area generation phase
- [x] **autoload/** - New SpawnableLayerService autoload for runtime queries
- [x] **scripts/systems/SpawnDirector.gd** - Integration with spawnable layer validation
- [x] **scripts/resources/** - New SpawnableLayerConfig resource class
- [x] **autoload/EventBus.gd** - New spawnable_layer_ready signal
- [x] **scripts/domain/signal_payloads/** - New SpawnableLayerReadyPayload
- [ ] **scenes/** - Optional debug visualization UI components
- [x] **data/content/** - Configuration .tres files for spawnable areas
- [x] **tests/** - Performance validation and spawn coverage tests

### Dependencies & Patterns
- **EventBus Signals:** `spawnable_layer_ready(SpawnableLayerReadyPayload)`
- **Resource Files:** `SpawnableLayerConfig.tres`, arena configuration updates
- **Performance Impact:** <1ms queries, spatial partitioning, 30Hz compatibility
- **Testing Strategy:** .tscn scenes for integration tests, .gd for unit tests

## 📚 Official Godot Documentation Research

### Relevant Concepts from Godot Docs:
- **TileMapLayer.get_used_cells_by_id()** - Efficient tile querying by atlas coordinates
- **TileMapLayer.map_to_local()** - Tile coordinate to world position conversion
- **Spatial Indexing** - Grid-based partitioning for O(grid_cells) lookups
- **Physics Quadrant Size** - Performance optimization for tile-based systems
- **get_used_rect()** - Bounding box calculation for tile areas

### Best Practices Identified:
- Use spatial grids (512px cells) to reduce search complexity from O(all_tiles) to O(grid_cells)
- Cache tile positions in world coordinates for faster distance calculations
- Pre-calculate spawnable areas during generation rather than runtime validation
- Use `get_used_cells_by_id()` for efficient tile type filtering

### Performance Considerations:
- **Rendering Quadrants:** Set appropriate quadrant size for spawnable layer rendering
- **Physics Quadrants:** Configure for collision detection if needed
- **Memory Usage:** Spatial grid caching balanced against lookup performance
- **Godot TileMapLayer Optimization:** Leverage built-in tile batching and indexing

## 📊 Implementation Plan

### Phase 1: Core Resource Classes & Configuration (Day 1)
- [ ] Create `SpawnableLayerConfig.gd` resource class with tile atlas configuration
- [ ] Define spawnable/non-spawnable tile types and atlas coordinates
- [ ] Create `SpawnableLayerData.gd` for runtime spatial data management
- [ ] Add configuration to existing PathAware_Forest .tres files
- [ ] Create `SpawnableLayerReadyPayload.gd` signal payload class
- [ ] Add `spawnable_layer_ready` signal to EventBus.gd

### Phase 2: SpawnableLayerService Autoload (Day 1-2)
- [ ] Create SpawnableLayerService autoload with spatial partitioning
- [ ] Implement arena registration and layer data caching
- [ ] Build spatial grid system (512px cells) for efficient position queries
- [ ] Add performance metrics and logging with "spawnlayer" category
- [ ] Implement `get_spawn_position(arena_id, target_pos, radius)` API
- [ ] Add `validate_spawn_area(arena_id, position, radius)` validation method

### Phase 3: PathAwareArenaGenerator Integration (Day 2)
- [ ] Add SPAWNABLE_LAYER_NAME constant to layer management
- [ ] Extend `_find_layer_node()` to support spawnable layer discovery
- [ ] Implement `_generate_spawnable_areas()` method in generation sequence
- [ ] Calculate valid spawn positions based on path boundaries and clearings
- [ ] Set appropriate tiles using spawnable layer configuration
- [ ] Emit `spawnable_layer_ready` signal after generation completion
- [ ] Add spawnable area metrics to generation logging

### Phase 4: SpawnDirector Integration & Validation (Day 2-3)
- [ ] Add spawnable layer validation to spawn position queries
- [ ] Implement fallback pattern: SpawnableLayerService → radius-based spawning
- [ ] Update `_spawn_enemy_v2()` to use spawnable layer validation
- [ ] Maintain compatibility with handmade arenas (traditional spawn zones)
- [ ] Add logging for spawn method selection and performance
- [ ] Ensure spawn distance validation respects tile boundaries

### Phase 5: Testing & Performance Validation (Day 3-4)
- [ ] Create performance test for spawn position queries (<1ms target)
- [ ] Build coverage test ensuring spawnable areas cover expected regions
- [ ] Test spatial partitioning efficiency with large arenas
- [ ] Validate integration with existing spawn systems (enemies, breaches)
- [ ] Performance comparison with removed AROUND_PATHS system
- [ ] Memory usage validation for spatial grid caching

### Phase 6: Documentation & Debug Tools (Day 4)
- [ ] Create visual debug mode for spawnable area visualization
- [ ] Add inspector tools for spawnable layer configuration
- [ ] Update PathAwareArenaGenerator documentation
- [ ] Document SpawnableLayerService API and usage patterns
- [ ] Add performance tuning guide for spatial partitioning
- [ ] Update CHANGELOG.md with spawnable layer implementation

## 🔗 Related Files

### Will Modify:
- [ ] `scripts/systems/PathAwareArenaGenerator.gd` (add spawnable generation)
- [ ] `scripts/systems/SpawnDirector.gd` (add spawnable layer integration)
- [ ] `autoload/EventBus.gd` (new signal)
- [ ] `scenes/arena/PathAware_Forest.gd` (configuration setup)

### Will Create:
- [ ] `autoload/SpawnableLayerService.gd` (new autoload)
- [ ] `scripts/resources/SpawnableLayerConfig.gd` (configuration resource)
- [ ] `scripts/resources/SpawnableLayerData.gd` (runtime data class)
- [ ] `scripts/domain/signal_payloads/SpawnableLayerReadyPayload.gd` (signal payload)
- [ ] `data/content/arena_configs/spawnable_layer_default.tres` (default config)
- [ ] `tests/test_spawnable_layer_performance.tscn` (performance validation)

### Documentation Updates Needed:
- [ ] `scripts/systems/CLAUDE.md` (SpawnableLayerService patterns)
- [ ] `autoload/CLAUDE.md` (new autoload documentation)
- [ ] `scripts/resources/CLAUDE.md` (resource patterns)
- [ ] `Obsidian/systems/Arena/PathAware-Arena-Generation-System.md`

## 📝 Progress Notes

### 2025-01-09 - Planning
- Initial task creation with comprehensive technical analysis
- Extended thinking analysis completed (8000+ tokens)
- Godot documentation research via Context7 MCP completed
- Existing code pattern analysis completed for reusable components
- Task structured with clear phases and acceptance criteria

### [DATE] - Phase 1 Implementation
- [Track resource class creation and configuration]

### [DATE] - Phase 2 Implementation
- [Track autoload service development]

### [DATE] - Testing & Validation
- [Track performance metrics and validation results]

### [DATE] - Completion
- [Final integration notes and lessons learned]

## 🚨 Risks & Considerations

### **Performance Risks:**
- **Large Arena Memory Usage:** Spatial grids may consume significant memory for massive arenas
  - *Mitigation:* Configurable grid cell size, lazy loading of grid cells
- **Tile Generation Time:** Complex boundary calculations during arena generation
  - *Mitigation:* Async generation phases, progress logging, performance profiling

### **Architecture Risks:**
- **Layer Integration Complexity:** TileMapLayer discovery and management across different arena types
  - *Mitigation:* Follow existing _find_layer_node() patterns, comprehensive error handling
- **Spawn System Dependencies:** Multiple spawn systems depending on new service
  - *Mitigation:* Robust fallback patterns, graceful degradation to radius-based spawning

### **Testing Risks:**
- **Spatial Validation Complexity:** Ensuring spawnable areas correctly respect path boundaries
  - *Mitigation:* Visual debug tools, comprehensive coverage tests, boundary validation
- **Performance Regression:** New system impacting existing spawn performance
  - *Mitigation:* Before/after performance benchmarking, 30Hz combat step compatibility

### **Integration Risks:**
- **EventBus Signal Timing:** Ensuring spawnable layer ready before spawn systems need it
  - *Mitigation:* Proper signal emission sequencing, service readiness checks
- **Configuration Hot-Reload:** Resource changes affecting spawnable layer behavior
  - *Mitigation:* Follow established BalanceDB hot-reload patterns, validation on load

## ✅ Definition of Done

- [ ] All acceptance criteria met with documented verification
- [ ] Code follows vibe project patterns (typed GDScript, small functions, proper logging)
- [ ] EventBus properly used with typed payloads (no direct system coupling)
- [ ] Logger used with "spawnlayer" category (no print() statements)
- [ ] Performance tests written and passing (<1ms spawn queries)
- [ ] Integration tests validate spawnable layer coverage and boundary respect
- [ ] Documentation updated in all relevant CLAUDE.md files
- [ ] CHANGELOG.md updated with spawnable layer implementation details
- [ ] Performance validated via headless test suite
- [ ] Visual debug tools functional for designer validation
- [ ] Complete replacement of AROUND_PATHS functionality verified
- [ ] Commit ready with conventional format: `feat: implement spawnable layer generator system`

## 🎯 Success Metrics

### **Functional Requirements**
- [ ] Spawnable areas generated within valid arena boundaries (no tree overlap)
- [ ] Spawn position queries return valid positions within specified radius
- [ ] All spawn systems (enemies, breaches, items) use spawnable layer successfully
- [ ] Fallback to radius-based spawning works seamlessly for edge cases
- [ ] Visual debug mode clearly shows spawnable vs non-spawnable areas

### **Performance Requirements**
- [ ] <1ms spawn position queries (target achieved consistently)
- [ ] <100ms spawnable layer generation during arena creation
- [ ] Memory usage <50MB for spatial grid data structures
- [ ] No frame drops during spawn calculations in 30Hz combat step
- [ ] Spatial partitioning reduces query complexity from O(all_tiles) to O(grid_cells)

### **Architecture Requirements**
- [ ] Clean integration with PathAwareArenaGenerator layer management
- [ ] SpawnableLayerService follows autoload service patterns
- [ ] Hot-reloadable configuration through .tres resources
- [ ] Comprehensive error handling and graceful degradation
- [ ] EventBus signal patterns followed for loose coupling

---

## 🔄 Current Implementation Status

**Phase:** Planning Complete
**Next Action:** Begin Phase 1 - Core Resource Classes & Configuration
**Blockers:** None identified
**Performance Target:** <1ms spawn queries with spatial partitioning

---

*This task replaces the removed AROUND_PATHS system with a more efficient, deterministic spawnable layer approach that integrates seamlessly with the existing PathAwareArenaGenerator architecture.*