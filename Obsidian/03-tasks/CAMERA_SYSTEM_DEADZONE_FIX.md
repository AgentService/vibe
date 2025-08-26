# Camera System Deadzone Fix

## Overview
Fix the real game CameraSystem to properly implement deadzone functionality. Currently, the camera is parented to the player node, which causes it to follow the player directly and breaks the deadzone behavior.

## Problem
**Current Implementation (CameraSystem.gd:70)**:
```gdscript
# Add camera to player so it follows automatically
player_node.add_child(camera)
```

This causes the camera to move directly with the player, making the deadzone logic ineffective.

## Solution
The camera should be independent of the player node and only move when the player exits the deadzone radius, similar to how it works in the isolated test.

## Required Changes

### 1. Camera Setup (lines 59-73)
**Current**:
```gdscript
func setup_camera(player_node: Node2D) -> void:
    camera = Camera2D.new()
    camera.name = "FollowCamera"
    camera.zoom = Vector2(default_zoom, default_zoom)
    camera.enabled = true
    
    # Add camera to player so it follows automatically
    player_node.add_child(camera)
    
    target_position = player_node.global_position
    original_position = target_position
```

**Should be**:
```gdscript
func setup_camera(player_node: Node2D) -> void:
    camera = Camera2D.new()
    camera.name = "FollowCamera"
    camera.zoom = Vector2(default_zoom, default_zoom)
    camera.enabled = true
    
    # Add camera to scene root, not player - for proper deadzone control
    var scene_root = player_node.get_tree().current_scene
    scene_root.add_child(camera)
    
    target_position = player_node.global_position
    camera.global_position = target_position  # Initialize camera position
    original_position = target_position
```

### 2. Update Camera Position Logic (lines 83-111)
The existing `_update_camera_position` method looks correct and should work properly once the camera is independent.

### 3. Test the Deadzone
Verify that:
- Camera doesn't move when player is within `deadzone_radius` (default 20.0)
- Camera follows smoothly when player moves outside the deadzone
- Camera bounds enforcement still works correctly

## Files to Modify
- `vibe/scripts/systems/CameraSystem.gd` (lines 59-73)

## Testing
1. **Manual Test**: Run the game and move the player slowly to verify deadzone behavior
2. **Isolated Test**: Compare behavior with `CameraSystem_Isolated.tscn` which works correctly
3. **Bounds Test**: Verify arena boundaries still constrain the camera properly

## Impact
- **Low Risk**: This is primarily a structural change that should improve camera behavior
- **Benefits**: Proper deadzone functionality, smoother camera following
- **Systems Affected**: Only CameraSystem, no other system dependencies

## Priority
**Medium** - Improves gameplay feel but doesn't break existing functionality

## Estimated Time
30 minutes - Small focused change with clear solution