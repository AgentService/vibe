# MenuBackground Component

## Overview
Persistent animated background system for all menu scenes. The background runs continuously across scene transitions without interruption, maintaining animation state, particle effects, and parallax scrolling.

## Architecture

### MenuBackgroundManager (Autoload)
- **Type:** CanvasLayer autoload
- **Layer:** -10 (renders behind all UI)
- **Purpose:** Manages persistent background instance across scene changes
- **State Management:** Automatically shows/hides based on StateManager.GameState

### MenuBackground.tscn/gd (Component)
- **Type:** Node2D scene with script
- **Features:**
  - Parallax scrolling background (2 layers with different speeds)
  - GPU particles (floating particles effect)
  - AnimationPlayer for additional effects
  - Auto-scrolling at constant velocity

## Usage

### The background is automatically managed - no manual setup required!

The `MenuBackgroundManager` autoload:
1. Loads on game start
2. Instances `MenuBackground.tscn`
3. Shows/hides based on game state
4. Persists across all menu scene transitions

### Automatic Visibility Rules:
```gdscript
# Visible in:
- StateManager.GameState.MENU
- StateManager.GameState.CHARACTER_SELECT

# Hidden in:
- StateManager.GameState.ARENA
- StateManager.GameState.HIDEOUT
- All other states
```

## Customization

### Adjust Parallax Speed:
Edit `MenuBackground.gd`:
```gdscript
const SCROLL_SPEED: Vector2 = Vector2(-20, -5)  # Change X/Y speeds
```

### Modify Particle Effects:
Edit `MenuBackground.tscn` → Select `FloatingParticles` node:
- Amount: Number of particles
- Lifetime: How long each particle lives
- Gravity: Particle movement direction
- Scale: Particle size range

### Add More Parallax Layers:
In `MenuBackground.tscn`:
1. Add new `ParallaxLayer` under `ParallaxBackground`
2. Set `motion_scale` (0.1-1.0, lower = slower)
3. Set `motion_mirroring` to screen size
4. Add visual content (Sprite2D, ColorRect, etc.)

### Add Animations:
In `MenuBackground.tscn` → `AnimationPlayer`:
1. Create new animation (e.g., "pulse", "glow")
2. Animate node properties (modulate, position, scale)
3. Set autoplay: `animation_player.autoplay = "your_animation"`

## Transition Effects

### Fade Out/In During Scene Changes:
```gdscript
# In your menu script:
func _on_transition_to_character_select() -> void:
    await MenuBackgroundManager.fade_out(0.3)
    StateManager.go_to_character_select()
    await MenuBackgroundManager.fade_in(0.3)
```

## Performance Notes

### Memory:
- Single instance loaded once (minimal memory cost)
- Particles: ~50 particles = negligible impact
- Parallax: Texture streaming handles large backgrounds

### CPU:
- `_process()` runs every frame for scrolling
- Particle simulation on GPU
- Optimized for 60+ FPS

### Best Practices:
- Keep particle count < 100 for low-end devices
- Use GPU particles (GPUParticles2D) not CPU particles
- Compress background textures (Lossy, mipmaps off for UI)
- Limit parallax layers to 3-4 maximum

## Technical Details

### Layer Rendering Order:
```
MenuBackgroundManager (CanvasLayer -10)
  └─ MenuBackground (Node2D)
      └─ Parallax layers, particles, effects

MainMenu (CanvasLayer 0)
  └─ UI elements

UIManager Modals (CanvasLayer 10+)
```

### Animation Continuity:
- Background instance never destroyed during menu flow
- Particles continue emitting across scene changes
- AnimationPlayer maintains playback position
- Parallax scroll offset accumulates continuously

### State Management Integration:
- Listens to `StateManager.state_changed` signal
- Automatically adjusts visibility
- No manual show/hide calls needed in menu scenes

## Example: Adding Custom Background Elements

```gdscript
# Extend MenuBackground.gd
extends Node2D

@onready var custom_sprite: Sprite2D = $CustomSprite

func _ready() -> void:
    super._ready()  # Call parent initialization
    _setup_custom_elements()

func _setup_custom_elements() -> void:
    custom_sprite.modulate.a = 0.5

    # Pulse animation
    var tween = create_tween().set_loops()
    tween.tween_property(custom_sprite, "modulate:a", 0.8, 2.0)
    tween.tween_property(custom_sprite, "modulate:a", 0.5, 2.0)
```

## Troubleshooting

### Background not visible:
1. Check current game state: `print(StateManager.current_state)`
2. Verify MenuBackgroundManager is in autoload list
3. Check canvas layer value (should be -10)

### Animations stuttering:
1. Check FPS (should be 60+)
2. Reduce particle count
3. Optimize background texture size
4. Use simpler parallax layers

### Background shows during gameplay:
1. Verify `_on_state_changed()` logic in MenuBackgroundManager.gd
2. Check if state transitions are being called correctly

## Future Enhancements

Potential additions:
- Dynamic background swapping (different themes)
- Weather effects (rain, snow particles)
- Time-of-day system (day/night cycle)
- Shader effects (chromatic aberration, blur)
- Audio-reactive elements (pulse with music)
