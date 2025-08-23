# Arena System Simplification & .tres Migration

**Status**: 📋 **TODO**  
**Priority**: High  
**Type**: System Refactor + Migration  
**Created**: 2025-08-23  
**Context**: Simplify arena system and migrate to single .tres arena

## Overview

Remove complex arena system logic and migrate to single default arena using .tres resource. This includes complete removal of wall system and arena switching.

## Phase 1: System Cleanup

### Remove Wall System Completely
- [ ] Delete `WallSystem.gd` class
- [ ] Delete `vibe/data/arena/walls.json`
- [ ] Remove wall system references from ArenaSystem
- [ ] Remove wall collision logic
- [ ] Remove wall rendering

### Remove Complex Arena Logic
- [ ] Delete all arena JSON files except `basic_arena.json`:
  - hazard_arena.json
  - dungeon_crawler.json
  - large_arena.json
  - mega_arena.json
- [ ] Delete all room JSON files:
  - All files in `/arena/layouts/rooms/`
- [ ] Remove `RoomLoader` class
- [ ] Remove arena switching/transition logic
- [ ] Remove theme switching

### Simplify ArenaSystem
- [ ] Remove subsystem complexity (TerrainSystem, ObstacleSystem, InteractableSystem)
- [ ] Remove room management
- [ ] Keep only basic arena loading
- [ ] Remove arena_loaded/room_changed signals

## Phase 2: Create Simple Arena Resource

### Create ArenaConfig Resource
- [ ] Create `ArenaConfig.gd` resource class in `scripts/domain/`
- [ ] Add @export properties for:
  - arena_id (String)
  - arena_name (String)
  - bounds (Rect2)
  - spawn_radius (float)
  - arena_center (Vector2)

### Convert to .tres
- [ ] Convert `basic_arena.json` to `default_arena.tres`
- [ ] Test loading in ArenaSystem
- [ ] Verify arena bounds work correctly

## Phase 3: Update Systems

### Update ArenaSystem
- [ ] Simplify to load single `default_arena.tres`
- [ ] Remove complex initialization
- [ ] Keep only essential arena bounds/center
- [ ] Update Arena scene connections

### Update Dependent Systems
- [ ] Update spawn systems to use simplified arena
- [ ] Update collision systems for new bounds
- [ ] Remove any wall collision checks
- [ ] Update camera bounds if needed

## Files to Delete

```
vibe/data/arena/walls.json
vibe/data/arena/layouts/hazard_arena.json
vibe/data/arena/layouts/dungeon_crawler.json
vibe/data/arena/layouts/large_arena.json
vibe/data/arena/layouts/mega_arena.json
vibe/data/arena/layouts/rooms/ (entire directory)
vibe/scripts/systems/WallSystem.gd
vibe/scripts/systems/RoomLoader.gd
vibe/scripts/systems/TerrainSystem.gd
vibe/scripts/systems/ObstacleSystem.gd
vibe/scripts/systems/InteractableSystem.gd
```

## Testing

- [ ] Verify arena loads correctly
- [ ] Test enemy spawning within bounds
- [ ] Test collision detection works
- [ ] Ensure no references to deleted systems

## Success Criteria

- ✅ Wall system completely removed
- ✅ Arena simplified to single default_arena.tres
- ✅ All unused arena/room files deleted
- ✅ ArenaSystem loads single static arena
- ✅ No complex room switching logic
- ✅ Game functions with simplified arena