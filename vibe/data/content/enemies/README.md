# Enemy Definitions

Enemy type definitions including stats, behaviors, and visual properties using Godot Resources (.tres format).

## Current Implementation

**Status**: ✅ **Implemented** (migrated to .tres resources)

Enemy definitions are loaded by `EnemyRegistry.gd` and used by:
- `WaveDirector` for spawning
- `EnemyRenderTier` for visual rendering
- Combat systems for stats and behaviors

## File Structure

```
enemies/
├── knight_regular.tres     # Basic enemy type
├── knight_elite.tres       # Elite variant
├── knight_swarm.tres       # Swarm variant  
├── knight_boss.tres        # Boss variant
```

## Resource Schema

Each enemy .tres file contains an `EnemyType` resource with properties:
- `id: String` - Unique identifier
- `display_name: String` - Human-readable name
- `health: float` - Base health value
- `speed: float` - Movement speed in pixels/second
- `size: Vector2` - Collision box dimensions
- `collision_radius: float` - Circular collision detection radius
- `xp_value: int` - Experience points awarded when killed
- `spawn_weight: float` - Weight for random selection in waves
- `visual_config: Dictionary` - Visual properties (color, shape)
- `behavior_config: Dictionary` - AI behavior settings

## Editing Workflow

### In Godot Editor (Recommended)
1. **Open .tres file** in Godot Inspector
2. **Edit properties** using visual controls (sliders, dropdowns, etc.)
3. **Save file** - changes apply automatically to newly spawned enemies
4. **Type safety** - Invalid values caught immediately

### In Text Editor (Advanced)
```tres
[gd_resource type="Resource" script_class="EnemyType" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/domain/EnemyType.gd" id="1"]
[resource]
script = ExtResource("1")
id = "knight_regular"
health = 6.0
speed = 60.0    # ← Edit values directly
# ... other properties
```

## Validation

Enemy .tres files provide:
- **Compile-time type checking** - Godot validates property types
- **Inspector warnings** - Invalid values highlighted in editor
- **Runtime validation** - Additional business logic validation
- **Automatic fallbacks** - Safe defaults for missing properties

## Hot-Reload

**Automatic** - Godot detects .tres file changes and reloads resources immediately. No manual reload required.

---

**Migration History**: 
- Originally JSON files in `/data/enemies/`
- Moved to `/data/content/enemies/` (2025-08-23)
- Migrated to .tres format (2025-08-23)