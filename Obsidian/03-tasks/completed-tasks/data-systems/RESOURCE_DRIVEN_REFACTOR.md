# Resource-Driven Architecture Refactor

**Status:** PLANNED  
**Priority:** Medium  
**Estimated Effort:** 2-3 sessions

## Overview
Refactor programmatic configurations to resource-driven approach while maintaining performance-critical systems. Improves MCP integration and editor experience without compromising game architecture.

## Goals
- ✅ Good MCP interaction through .tres files
- ✅ Visual/animation editing in editor
- ✅ Keep performance systems programmatic
- ✅ Maintain clean "good vibe" coding

## Implementation Plan

### Phase 1: Player Configuration (Quick Win)
**Files to Create:**
- `scripts/domain/PlayerType.gd` - Resource class
- `data/content/player/player_default.tres` - Default player config
- Update `scenes/arena/Player.gd` - Load from resource

**Tasks:**
1. Create PlayerType resource class with properties:
   - `move_speed`, `max_health`, `pickup_radius`, `roll_speed`
   - `animation_config: AnimationConfig`
   - `starting_abilities: Array[String]`
2. Create default player .tres file
3. Update Player.gd to load from resource with @export fallbacks
4. **CHECKPOINT:** Test game runs, player moves correctly

### Phase 2: Arena Configuration 
**Files to Create:**
- `scripts/domain/ArenaType.gd` - Resource class
- `data/content/arena/default_arena.tres` - Fixes missing file
- Update `scripts/systems/ArenaSystem.gd` - Proper resource loading

**Tasks:**
1. Create ArenaType resource class:
   - `size: Vector2`, `spawn_zones: Array[Rect2]`
   - `theme: String`, `tileset_scene: PackedScene`
2. Create default_arena.tres (currently missing)
3. Fix ArenaSystem.gd resource loading
4. **CHECKPOINT:** Test game runs, arena loads properly

### Phase 3: Animation Enhancement
**Files to Update:**
- `scenes/arena/Arena.gd` - Animation system improvements
- Enemy animation configs in `data/animations/`

**Tasks:**
1. Add AnimatedSprite2D preview nodes for enemies (editor-visible)
2. Keep MultiMesh for performance (runtime-optimized)
3. Create animation preview system for .tres files
4. **CHECKPOINT:** Test animations work, performance maintained

### Phase 4: Editor Tools (Optional Polish)
**Files to Create:**
- Debug visualization @tool scripts
- Inspector plugins for resource editing

**Tasks:**
1. Add @tool debug overlays for spawn zones
2. Create arena bounds visualizer
3. Add enemy preview system in FileSystem dock
4. **CHECKPOINT:** Test editor tools, MCP integration

## Performance Preservation

**Keep Programmatic:**
- `WaveDirector.enemies: Array[EnemyEntity]` - Pool performance
- `AbilitySystem.projectiles: Array[Dictionary]` - Pool performance  
- Combat collision detection - 30Hz fixed-step critical
- MultiMesh instance updates - GPU optimization
- System dependency injection - Architecture flexibility

**Make Resource-Driven:**
- Player stats and configuration
- Arena layout and theming
- Enemy type definitions (already done)
- Animation configurations (already done)
- Balance tunables (already done)

## Testing Strategy

**After Each Phase:**
1. Run `./Godot_v4.4.1-stable_win64_console.exe --headless tests/run_tests.tscn`
2. Test basic game startup: `scenes/main/Main.tscn`
3. Verify player movement, enemy spawning, combat
4. **Wait for user confirmation** before proceeding

## Expected Benefits

**MCP Integration:**
- Can modify player configs via .tres editing
- Arena spawn zones editable through resources
- Animation previews visible in FileSystem
- Debug tools accessible through inspector

**Developer Experience:**
- Visual spawn zone editing
- Animation timeline preview
- Resource-based content creation
- Clean separation: content vs mechanics

**Architecture:**
- Maintains performance-critical pools
- Respects existing system boundaries
- Incremental adoption possible
- No breaking changes to core systems

## Risks & Mitigation

**Risk:** Performance regression in pools
**Mitigation:** Keep pools programmatic, only config becomes resource-driven

**Risk:** Complex migration
**Mitigation:** Phase-by-phase with checkpoints, user confirmation required

**Risk:** Testing complexity
**Mitigation:** Run full test suite after each phase

## Files Modified Summary

### Phase 1 (Player):
- NEW: `scripts/domain/PlayerType.gd`
- NEW: `data/content/player/player_default.tres`
- EDIT: `scenes/arena/Player.gd`

### Phase 2 (Arena):
- NEW: `scripts/domain/ArenaType.gd`
- NEW: `data/content/arena/default_arena.tres`
- EDIT: `scripts/systems/ArenaSystem.gd`

### Phase 3 (Animations):
- EDIT: `scenes/arena/Arena.gd`
- EDIT: Enemy animation handling

### Phase 4 (Editor Tools):
- NEW: Debug visualization tools
- NEW: Inspector plugins

## Success Criteria
- [ ] MCP can edit player/arena configs via .tres files
- [ ] Game performance maintains 30Hz fixed-step combat
- [ ] All existing tests pass
- [ ] Visual editing tools work in editor
- [ ] No regression in gameplay mechanics