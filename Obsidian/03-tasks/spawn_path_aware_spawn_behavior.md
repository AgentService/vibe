# Path-Aware Enemy Spawn Behavior

**Created:** 2025-01-21
**Status:** 🟡 Planning
**Priority:** High
**Estimated Effort:** 1-2 Days

## 📋 Task Description

Implement a spawn behavior system that uses the procedurally generated main path and branches to determine valid enemy spawn locations. Currently, enemies can spawn anywhere within the spawn radius, including in boundary trees or outside the arena. This task will create path-aware spawning that ensures enemies only spawn in accessible, valid arena areas.

**Key Requirement:** Breach events must also spawn along path lines and branches, not in tree boundaries or inaccessible areas.

## 🎯 Acceptance Criteria

- [ ] Enemies only spawn within the main path and branch areas, never in boundary trees
- [ ] **Breach events spawn along path lines and branches**, respecting path-aware boundaries
- [ ] Spawn validation uses the actual generated path data from PathAwareArenaGenerator
- [ ] Integration with existing SpawnDirector and BreachEventHandler without breaking functionality
- [ ] Fallback mechanism for arenas without path generation
- [ ] Performance: Spawn validation must complete within 2ms per request
- [ ] Visual debugging option to show valid spawn areas for both enemies and breach events

## 🔍 Technical Analysis

### Affected Systems
- [x] scripts/systems/ (SpawnDirector, Arena systems)
- [ ] autoload/ (EventBus for new spawn validation signals)
- [ ] scripts/domain/ (Spawn validation models)
- [ ] scenes/ (PathAware_Forest integration)
- [ ] data/ (Path configuration schemas)
- [ ] tests/ (Spawn validation tests)

### Dependencies & Patterns
- **EventBus Signals:**
  - `spawn_validation_requested(position: Vector2) -> bool`
  - `valid_spawn_areas_updated(areas: Array[Rect2])`
  - `breach_spawn_validation_requested(position: Vector2, radius: float) -> Vector2`
- **Resource Files:**
  - Update PathConfiguration.tres with spawn area definitions
  - New SpawnAreaConfiguration.tres for spawn validation settings
  - Update BreachEventConfig.tres with path-aware spawn requirements
- **Performance Impact:**
  - Must maintain 30Hz combat compatibility
  - Cache valid spawn areas for efficient lookups
  - Breach event validation must not block event spawning
- **Testing Strategy:**
  - .tscn pattern for SpawnDirector and BreachEventHandler integration testing
  - Performance validation with large path networks and multiple breach events

## 📊 Implementation Plan

### Phase 1: Analysis & Design
- [ ] Study existing PathAwareArenaGenerator path data structure
- [ ] Analyze current SpawnDirector spawn position logic
- [ ] Design path-aware spawn validation API
- [ ] Plan integration with SimpleTileSpawnValidator

### Phase 2: Core Implementation
- [ ] Create PathAwareSpawnValidator class for spawn area validation
- [ ] Implement path data extraction from PathAwareArenaGenerator
- [ ] Add spawn area caching system for performance
- [ ] Create EventBus signals for spawn validation

### Phase 3: SpawnDirector & BreachEventHandler Integration
- [ ] Integrate PathAwareSpawnValidator with SpawnDirector
- [ ] **Integrate PathAwareSpawnValidator with BreachEventHandler for breach spawning**
- [ ] Add fallback mechanism for non-path-aware arenas
- [ ] Update spawn position generation logic for both enemies and breach events
- [ ] Add logging with Logger (ensure 'spawning' and 'events' categories exist in debug.tres)

### Phase 4: Testing & Validation
- [ ] Write spawn validation tests (PathAwareSpawning_test.tscn)
- [ ] **Write breach event path spawning tests (BreachPathSpawning_test.tscn)**
- [ ] Performance testing with complex path networks
- [ ] Integration testing with PathAware_Forest scene for both enemies and breach events
- [ ] Visual debugging tools for spawn area validation

### Phase 5: Documentation & Finalization
- [ ] Update scripts/systems/CLAUDE.md with spawn patterns
- [ ] Update CHANGELOG.md with spawn behavior improvements
- [ ] Document path-aware spawning in Obsidian/systems/Spawning/
- [ ] Prepare commit with conventional format

## 🔗 Related Files

### Will Likely Modify:
- [ ] `scripts/systems/SpawnDirector.gd` (spawn validation integration)
- [ ] `scripts/systems/BreachEventHandler.gd` (breach spawn validation)
- [ ] `scripts/systems/PathAwareArenaGenerator.gd` (path data access)
- [ ] `autoload/EventBus.gd` (spawn validation signals)
- [ ] `data/content/DefaultPathConfiguration.tres` (spawn area config)
- [ ] `data/balance/breach_event_config.tres` (path-aware breach spawning)

### Documentation Updates Needed:
- [ ] `scripts/systems/CLAUDE.md` (spawn validation patterns)
- [ ] `tests/CLAUDE.md` (spawn testing approaches)
- [ ] `Obsidian/systems/Spawning/GUIDE_Path_Aware_Spawning.md` (new guide)

## 📝 Progress Notes

### [2025-01-21] - Planning
- Initial task creation
- Need to analyze PathAwareArenaGenerator path data structure
- Consider integration with existing SimpleTileSpawnValidator
- Research path bounds calculation methods
- **IMPORTANT: Must include breach event spawning along path lines**
- Consider BreachEventHandler integration for path-aware breach placement

## 🚨 Risks & Considerations

- **Performance:** Path validation must not impact 30Hz combat loop
- **Architecture:** Maintain clean separation between path generation and spawning
- **Testing:** Need comprehensive validation with various path configurations
- **Dependencies:** Integration with existing arena systems without breaking changes

## ✅ Definition of Done

- [ ] All acceptance criteria met
- [ ] Enemies never spawn in boundary trees or outside arena
- [ ] Code follows vibe project patterns (EventBus, Logger, 30Hz compatibility)
- [ ] SpawnDirector properly integrated with path-aware validation
- [ ] Performance validated (≤2ms spawn validation)
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Visual debugging tools available
- [ ] Commit ready with conventional format

## 🎯 Implementation Details

### Key Components to Implement:

1. **PathAwareSpawnValidator** - Core validation logic for both enemies and breach events
2. **SpawnAreaCache** - Performance optimization for repeated lookups
3. **PathDataExtractor** - Interface to PathAwareArenaGenerator data
4. **DebugSpawnVisualizer** - Visual debugging for spawn areas (enemies + breach events)
5. **BreachPathSpawnIntegration** - Specialized breach event path spawning

### Integration Points:

- **SpawnDirector**: Primary integration point for enemy spawn validation
- **BreachEventHandler**: Integration point for breach event spawn validation
- **PathAwareArenaGenerator**: Source of path and boundary data
- **SimpleTileSpawnValidator**: Potential synergy for ground tile validation
- **Arena.gd**: Coordination of spawn validation systems

### Performance Targets:

- **Spawn validation**: ≤2ms per spawn request
- **Area caching**: Update cache only when path changes
- **Memory usage**: Minimal impact on arena memory footprint
- **30Hz compatibility**: No impact on combat step performance