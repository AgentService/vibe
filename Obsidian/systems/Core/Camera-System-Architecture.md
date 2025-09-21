# Camera System Architecture

## Overview

The [[CameraSystem]] provides smooth player following, zoom controls, and screen shake effects for the 2D top-down arena gameplay. It follows signal-based architecture patterns and integrates with the display configuration for optimal performance.

## Current Implementation Status

**File**: `scripts/systems/CameraSystem.gd` (187 lines)  
**Last Updated**: August 23, 2025 - Display & zoom improvements  
**Status**: ✅ Production ready with proper zoom limits  

## Core Components

### Camera Configuration
```gdscript
@export var follow_speed: float = 8.0      # Camera follow smoothness
@export var zoom_speed: float = 5.0        # Zoom transition speed  
@export var min_zoom: float = 2.0          # Minimum zoom (default/max zoom out)
@export var max_zoom: float = 4.0          # Maximum zoom (max zoom in)
@export var default_zoom: float = 2.0      # Starting zoom level
@export var deadzone_radius: float = 20.0  # Player movement tolerance
```

### Zoom Behavior (Updated August 2025)
- **Default State**: Starts at 2.0x zoom (close tactical view)
- **Zoom In**: Mouse wheel up increases zoom (2.0 → 4.0)
- **Zoom Out**: Mouse wheel down blocked at default (2.0) - no over-zooming
- **Smooth Transitions**: Lerped zoom changes for fluid experience

## Signal Architecture

### Outgoing Signals
```gdscript
signal camera_moved(position: Vector2)           # Position updates
signal camera_zoomed(zoom_level: float)          # Zoom changes
signal camera_shake_requested(intensity, duration) # Shake events
```

### Incoming Signals (EventBus)
```gdscript
EventBus.arena_bounds_changed    → _on_arena_bounds_changed()
EventBus.player_position_changed → _on_player_position_changed() 
EventBus.damage_dealt           → _on_damage_dealt()
EventBus.game_paused_changed    → _on_game_paused_changed()
```

### Direct Connections
```gdscript
PlayerState.player_position_changed → _on_player_moved()
```

## Camera Features

### 1. Player Following
- **Deadzone System**: Camera only moves when player exceeds 20px radius
- **Smooth Following**: Speed increases with distance from deadzone center
- **Arena Bounds**: Camera clamped to arena boundaries with viewport consideration

### 2. Zoom System
- **Input Handling**: Mouse wheel controls zoom with proper limits
- **Zoom Constraints**: 
  - Cannot zoom out beyond default (2.0)
  - Can zoom in up to 4.0x for detailed combat
- **Balance Integration**: Loads balance data from [[BalanceDB]] for configuration

### 3. Screen Shake
- **Damage-Based**: Automatic shake on significant damage (>20 damage)
- **Intensity Scaling**: 
  - Major damage (>50): 2.0 intensity, 0.2s duration
  - Medium damage (>20): 1.0 intensity, 0.1s duration
- **Smooth Falloff**: Shake intensity reduces over duration

### 4. Arena Integration  
- **Bounds Awareness**: Prevents camera from showing outside arena
- **Dynamic Sizing**: Adapts to different arena layouts
- **Viewport Calculation**: Accounts for zoom level in boundary calculations

## Display Integration

### Project Settings (Updated August 2025)
```ini
[display]
window/size/viewport_width=1920          # Full HD standard
window/size/viewport_height=1080         # 16:9 aspect ratio
window/size/mode=2                       # Maximized window
window/vsync/vsync_mode=1               # Smooth rendering

[rendering]  
renderer/rendering_method="forward_plus" # High performance
anti_aliasing/quality/msaa_2d=1         # Smooth edges
```

### Camera Setup Process
1. **Player Attachment**: Camera added as child to player node
2. **Initial Positioning**: Set to player's starting position
3. **Zoom Application**: Default zoom applied immediately
4. **Signal Binding**: All EventBus connections established

## Performance Considerations

### Optimization Features
- **Physics Process**: Updates at fixed timestep for consistent behavior
- **Lerp Smoothing**: Gradual transitions prevent jarring movements  
- **Bounds Clamping**: Efficient viewport-aware boundary checking
- **Shake Timer**: Automatic cleanup prevents perpetual shake effects

### Balance Data Integration
```gdscript
# Loads from data/balance/waves.json
min_zoom = BalanceDB.get_waves_value("camera_min_zoom")
```

## Usage Patterns

### System Setup (in Arena)
```gdscript
camera_system = CameraSystem.new()
add_child(camera_system)
camera_system.setup_camera(player_node)
```

### Manual Camera Control
```gdscript
camera_system.set_zoom(3.0)              # Set specific zoom
camera_system.center_on_position(pos)    # Jump to position  
camera_system.shake_camera(5.0, 1.0)     # Manual shake
```

## Recent Updates (August 23, 2025)

### Display Configuration
- ✅ **Viewport Size**: Upgraded to 1920x1080 (Full HD)
- ✅ **VSync**: Enabled for smooth rendering
- ✅ **Window Behavior**: Maximized, centered, resizable
- ✅ **Anti-aliasing**: MSAA 2D for crisp edges

### Zoom Behavior Fixes
- ✅ **Default Zoom**: Maintains original close view (2.0)
- ✅ **Zoom Out Limit**: Prevents zooming beyond default
- ✅ **Smooth Transitions**: Proper lerp-based zoom changes
- ✅ **Balance Integration**: Compatible with existing balance data

## Integration Points

### Required Systems
- [[PlayerState]]: Player position tracking
- [[EventBus]]: Signal communication hub  
- [[BalanceDB]]: Configuration data loading
- [[ArenaSystem]]: Arena bounds information

### UI Integration
- Works with [[HUD]] for screen-space UI elements
- Supports [[EnemyRadar-Component]] positioning
- Compatible with [[Modal-Overlay-System]] during pause

## Future Enhancements

### Planned Features
- **Camera Presets**: Quick zoom levels for different situations
- **Follow Modes**: Different following behaviors (lag, predict, etc.)
- **Cinematic System**: Cutscene camera control
- **Screen Transitions**: Scene change camera effects

### Performance Improvements
- **Viewport Culling**: Only update when visible
- **Priority Following**: Focus on important events
- **Shake Pooling**: Reuse shake effect instances

## Related Documentation

- [[Component-Structure-Reference]]: System integration patterns
- [[EventBus-System]]: Signal communication details
- [[UI-Architecture-Overview]]: Camera-UI relationship
- [[Arena-System-Architecture]]: Arena bounds and layouts