# Ability System Mouse Firing Enhancement

## Overview
Clarify and improve mouse-based projectile firing functionality. The feature exists in the real game but has different behavior compared to isolated test, and requires specific player stats to be enabled.

## Current Status

### ✅ Working Implementation
Mouse firing **is implemented** in the real game (`Arena.gd:452-529`):

**Right-Click Firing** (Line 298):
```gdscript
elif event.button_index == MOUSE_BUTTON_RIGHT and RunManager.stats.get("has_projectiles", false):
    _handle_projectile_attack(world_pos)
```

**Fire toward mouse** (Lines 515-529):
```gdscript
func _spawn_debug_projectile() -> void:
    var spawn_pos: Vector2 = player.global_position
    var mouse_pos := get_global_mouse_position()
    var direction := (mouse_pos - spawn_pos).normalized()
    # ... spawns projectiles via ability_system.spawn_projectile()
```

## Issues Identified

### 1. **Inconsistent Controls**
- **Real Game**: Right-click fires projectiles
- **Isolated Test**: Left-click fires projectiles
- **User Expectation**: May expect left-click (more common for primary attack)

### 2. **Hidden Requirement**
Projectile firing requires `RunManager.stats.get("has_projectiles", false)` to be true:
- Not documented in controls or UI
- No feedback when right-clicking without projectiles enabled
- Unclear how player obtains projectile capability

### 3. **Control Documentation**
Current UI/controls don't clearly indicate right-click for projectiles vs left-click for melee.

## Potential Improvements

### Option A: Standardize on Right-Click
- Update isolated test to match real game (right-click firing)
- Update documentation/UI to show right-click for projectiles
- Add visual feedback when projectile capability is disabled

### Option B: Support Both Buttons
- Left-click: Melee attack (current behavior)
- Right-click: Projectile attack (current behavior)  
- Add clear UI indicators for both attack types

### Option C: Make Left-Click Context-Sensitive
- Left-click: Projectile attack if player has projectiles, otherwise melee
- Right-click: Always melee attack
- More intuitive single-button interaction

## Recommended Changes

### 1. **Update Isolated Test** (Low effort)
Change AbilitySystem_Isolated.gd to use right-click to match real game:
```gdscript
# Line 295: Change MOUSE_BUTTON_LEFT to MOUSE_BUTTON_RIGHT
if event.button_index == MOUSE_BUTTON_RIGHT:
    print("Right mouse button detected - firing projectile")
    _fire_projectile_toward_mouse()
```

### 2. **Add User Feedback** (Medium effort)  
Show feedback when right-clicking without projectile capability:
```gdscript
elif event.button_index == MOUSE_BUTTON_RIGHT:
    if RunManager.stats.get("has_projectiles", false):
        _handle_projectile_attack(world_pos)
    else:
        # Show "No projectiles available" message
        EventBus.ui_message.emit("Projectiles not yet unlocked")
```

### 3. **Document Controls** (Low effort)
Update UI/HUD to show:
- "Left-click: Melee Attack"
- "Right-click: Projectile Attack (if unlocked)"

## Files to Modify
- `tests/AbilitySystem_Isolated.gd` (for consistency)
- `scenes/arena/Arena.gd` (for user feedback)
- UI/HUD files (for control documentation)

## Testing
1. **Enable projectiles**: Set `RunManager.stats.has_projectiles = true` in debug
2. **Test right-click**: Verify projectiles fire toward mouse position  
3. **Test without projectiles**: Verify appropriate feedback
4. **Isolated test consistency**: Ensure test matches real game behavior

## Priority
**Low-Medium** - Feature works correctly, just needs better UX and consistency

## Estimated Time
1-2 hours for full improvements, 30 minutes for just test consistency