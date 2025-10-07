# Enemy Spawn Dissolve Effect - Usage Guide

## Overview

The enemy spawn dissolve effect creates a materialization animation when enemies appear. Enemies "fade in" from transparent to fully visible using a procedural noise-based dissolve shader.

## Files Created

1. **Shader**: `shaders/enemy_spawn_dissolve.gdshader`
2. **Helper Class**: `scripts/domain/EnemySpawnEffect.gd`

## How It Works

### Visual Effect
- Enemies start fully dissolved (invisible)
- Over 0.6 seconds, they materialize with a cyan edge glow
- The dissolve pattern uses procedural Simplex noise for organic appearance
- After spawn completes, the shader is removed (no performance impact)

### Technical Flow
```
1. Enemy spawns (invisible)
2. Apply dissolve shader material
3. Tween: dissolve_progress 1.0 → 0.0
4. Restore original material
```

## Implementation

### Option 1: Per-Enemy Scene (Recommended for Unique Enemies)

Add to your enemy scene script (e.g., `Enemy_Grunt.gd`):

```gdscript
extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    # Your existing enemy setup...

    # Apply spawn dissolve effect
    EnemySpawnEffect.apply_spawn_effect(sprite, get_tree())
```

### Option 2: Auto-Apply via Enemy Factory (Future Enhancement)

For automatic application to ALL enemies, modify `SpawnDirector` or enemy creation point:

```gdscript
# In SpawnDirector or wherever enemies are instantiated
func _create_enemy_instance(config: SpawnConfig) -> Node2D:
    var enemy = enemy_scene.instantiate()

    # Find sprite and apply spawn effect
    var sprite = enemy.get_node("AnimatedSprite2D") # Adjust path as needed
    if sprite:
        EnemySpawnEffect.apply_spawn_effect(sprite, get_tree())

    return enemy
```

### Option 3: Centralized System Initialization

Initialize once at game start (recommended in GameOrchestrator or Arena):

```gdscript
# GameOrchestrator.gd or Arena.gd _ready()
func _ready() -> void:
    # Initialize spawn effect system (loads shader, creates noise texture)
    EnemySpawnEffect.initialize()

    # ... rest of setup
```

## Customization

### Adjust Spawn Duration

Edit `EnemySpawnEffect.gd`:
```gdscript
const SPAWN_DURATION = 0.4  # Faster spawn (default: 0.6)
```

### Change Edge Glow Color

```gdscript
const EDGE_GLOW_COLOR = Color(1.0, 0.5, 0.0, 1.0)  # Orange glow
```

### Shader Parameters

In `enemy_spawn_dissolve.gdshader`:
- `edge_width` - Thickness of glow edge (default: 0.05)
- `noise_scale` - Size of dissolve pattern (default: 1.5)
- `edge_color` - Color of materialization glow

## Performance

- **Initialization**: One-time cost to generate noise texture (~256x256)
- **Per-Spawn**: Minimal - tween + shader parameter updates
- **After Spawn**: Zero - shader material is removed after animation
- **Memory**: Shared shader material and noise texture across all enemies

## Boss Compatibility

Bosses can use the same effect:

```gdscript
# In BaseBoss or specific boss script
func _ready() -> void:
    super._ready()  # Call parent

    # Apply spawn effect to boss
    if animated_sprite:
        EnemySpawnEffect.apply_spawn_effect(animated_sprite, get_tree())
```

## Troubleshooting

### Effect not visible
- Ensure `EnemySpawnEffect.initialize()` is called at game start
- Check that sprite reference is valid `AnimatedSprite2D`
- Verify shader file exists at `res://shaders/enemy_spawn_dissolve.gdshader`

### Performance issues
- Reduce noise texture size in `_create_noise_texture()` (256→128)
- Shorten `SPAWN_DURATION` to reduce active shader time

### Effect looks wrong
- Adjust `noise_scale` parameter (higher = larger dissolve chunks)
- Modify `edge_width` for thicker/thinner glow
- Change `edge_color` for different visual style

## Integration with Existing Systems

The spawn effect is **decoupled** from:
- EnemyFactory (works with any enemy creation method)
- Damage systems (purely visual, no gameplay impact)
- Boss hit feedback (different shader, no conflicts)

It's a **pure visual enhancement** that can be toggled on/off per-enemy or globally.

## Future Enhancements

- [ ] Add configuration resource for tuning per-enemy-type
- [ ] Support different dissolve patterns (vertical wipe, radial, etc.)
- [ ] Add sound effect trigger at spawn completion
- [ ] Create particle burst at materialization finish
- [ ] Add option for reverse effect (enemies dissolve on death)
