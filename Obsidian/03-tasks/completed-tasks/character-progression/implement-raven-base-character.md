# Implement Raven Fantasy Base Character

**Status:** ✅ Completed - See follow-up task: `complete-raven-animations-and-layered-equipment.md`  
**Priority:** High  
**Estimated Time:** 2-3 hours  
**Dependencies:** Raven Fantasy assets already purchased and imported  

## Objective
Replace current CraftPix swordsman with Raven Fantasy base character (naked/unclothed) to establish foundation for layered equipment system.

## Technical Specifications
- **Grid Size:** 48x48 pixels per frame (confirmed from official instructions)
- **Base Asset:** `Full.png` or `Skin 1.png` from Base folder
- **Animation Sets:** 15+ comprehensive animation types
- **Frame Count:** ~4 frames per direction × 4 directions per animation

## Implementation Steps

### Phase 1: Asset Preparation ✅ COMPLETED
- [x] Organize Raven assets into clean `/assets/sprites/raven_character/` structure
- [x] Set Godot import settings: Filter Off, Mipmaps Off for pixel-perfect rendering
- [x] Create Atlas extraction script for 48x48 grid slicing

### Phase 2: Animation System ✅ COMPLETED (Core animations)
- [x] Extract base character animations from `Full.png`:
  - [x] Walk, Idle, Run (core movement) 
  - [ ] Strike 01, Strike 02 (basic combat) - *See follow-up task*
  - [ ] Conjure, Magic (spell casting) - *See follow-up task*
  - [ ] Dodge, Jump, Climb (utility) - *See follow-up task*
- [x] Create comprehensive SpriteFrames resource (`raven_ranger_frames.tres`)
- [x] Configure frame timing and loop settings
- [x] Test animation playback and transitions

### Phase 3: Player Integration ✅ COMPLETED
- [x] Create new `PlayerRanger.tscn` scene for ranger class
- [x] Replace AnimatedSprite2D with Raven base character
- [x] Update collision shape for 48x48 frame size
- [x] Test with existing movement and combat systems

### Phase 4: System Compatibility ✅ COMPLETED
- [x] Verify 30Hz combat step compatibility
- [x] Test with existing HUD, radar, and UI scaling
- [x] Ensure proper interaction with camera system (MapDevice integration)
- [x] Validate performance with MultiMeshInstance2D

### Phase 5: Integration Testing ✅ COMPLETED
- [x] Test all movement animations (idle, run, walk)
- [x] Verify combat animations work with damage system (melee attacks functional)
- [x] Check animation state machine transitions
- [x] Performance testing in arena with multiple enemies
- [x] Character selection system integration
- [x] Dynamic PlayerSpawner scene loading

## Success Criteria
- [ ] Base character renders at correct scale relative to existing game elements
- [ ] All core animations (movement, basic combat) functional
- [ ] No performance regression from current CraftPix system
- [ ] Proper integration with existing player systems (health, movement, combat)
- [ ] Foundation ready for clothing/equipment layers

## Notes
- Start with `Skin 1.png` for consistent base
- Focus on core animations first (walk, idle, run, basic strike)
- Defer advanced animations (conjure, magic, tools) until clothing system ready
- Document frame extraction process for future clothing layer implementation

## Architecture Impact
- Establishes foundation for equipment visualization system
- Enables future character customization features
- Supports PoE-style buildcraft visual representation

## Files to Modify
- `/scenes/arena/Player.tscn` or create new `/scenes/arena/PlayerRaven.tscn`
- Create new SpriteFrames resource in `/assets/sprites/raven_character/`
- Update player script if animation names change

## Testing Requirements
- Verify with headless tests that combat mechanics unchanged
- Performance benchmark against current system
- UI scaling validation across different screen sizes