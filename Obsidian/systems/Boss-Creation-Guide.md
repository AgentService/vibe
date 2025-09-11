# Boss Creation Guide

Complete workflow for creating new bosses in the game using the Unified Damage System V3 and Boss Performance System V2.

> **Performance Note**: All bosses use the centralized `BossUpdateManager` for optimal 500+ entity scaling with zero-allocation batch processing.

---

## Overview

The boss system supports two types of enemies:
- **Pooled Enemies**: High-performance MultiMesh rendering for swarms (managed by WaveDirector pools)
- **Scene Bosses**: Complex editor-created scenes with custom AI, animations, and behaviors

This guide focuses on **Scene Bosses** as they provide the most flexibility for unique boss encounters.

---

## Scene Boss Architecture

### **Core Components:**
1. **Boss Scene** (`.tscn`): CharacterBody2D with visual/collision setup
2. **Boss Script** (`.gd`): AI logic, health management, damage handling  
3. **Boss Configuration** (`.tres`): Stats, spawn settings, visual config
4. **DamageService Integration**: Unified damage handling across all systems

### **Required Boss Script Interface:**
```gdscript
extends CharacterBody2D

# Required signals
signal died

# Required methods for damage system integration
func get_current_health() -> float
func get_max_health() -> float
func set_current_health(new_health: float) -> void
func is_alive() -> bool

# Required method for spawn system integration
func setup_from_spawn_config(config: SpawnConfig) -> void
```

---

## Step-by-Step Boss Creation

### **Step 1: Create Boss Scene**

1. **Create new scene**: `scenes/bosses/YourBoss.tscn`
2. **Add CharacterBody2D as root** with your boss name
3. **Add CollisionShape2D child** with **CircleShape2D** collision shape
4. **Add AnimatedSprite2D child** for directional animations (scale: 1.0, 1.0 - no pre-scaling!)
5. **Add HitBox (Area2D)** with CollisionShape2D child for damage detection
6. **Add AttackTimer (Timer)** for attack cooldowns
7. **Add BossHealthBar scene instance** from `res://scenes/components/BossHealthBar.tscn`

**⚠️ IMPORTANT: Sprite Scaling Best Practice**
- **Always keep AnimatedSprite2D scale at (1.0, 1.0)** in the scene
- **Use size_factor in .tres template** for all scaling adjustments
- **Resize sprite assets** if they appear too large/small at 1.0 scale
- **Avoid pre-scaling sprites** in scenes as it complicates the scaling system

**Required scene structure:**
```
YourBoss (CharacterBody2D)
├── AnimatedSprite2D (scale: 2x2)
├── CollisionShape2D (CircleShape2D, centered at origin 0,0)
├── HitBox (Area2D)
│   └── HitBoxShape (CollisionShape2D, CircleShape2D, centered at origin 0,0)
├── AttackTimer (Timer)
├── BossHealthBar (BossHealthBar scene instance)
└── BossShadow (BossShadow scene instance) [AUTO-CREATED by BaseBoss]
```

**⚠️ Important Collision Setup:**
- **Always use CircleShape2D** for boss collision instead of RectangleShape2D
- **Keep collision shapes centered** at (0, 0) for smooth movement and rotation
- **Circle collision provides** better AI pathfinding and natural movement around obstacles
- **Set appropriate radius** based on your boss sprite size (typically 24-48 pixels for 2x scaled sprites)

**✨ NEW: Flexible Auto-Adjusting Health Bar with Perfect Scaling**

The `BossHealthBar.tscn` scene now automatically:
- **📏 Sizes itself** based on your boss's HitBox dimensions (width = 80% of HitBox width, no minimum size constraint)
- **📍 Positions itself** 12px above the HitBox bounds automatically  
- **🎯 Works with any shape** - CircleShape2D or RectangleShape2D HitBoxes supported
- **🔄 Updates instantly** when you copy-paste the scene to any boss
- **⚖️ Perfect scaling** - Health bar automatically readjusts after boss size factor changes
- **🎮 Real-time updates** - Works with F5 hot-reload system for immediate size factor testing

**⚠️ Requirements for Auto-Adjustment:**
- Boss must have `HitBox/HitBoxShape` node structure
- HitBoxShape must have a shape assigned (CircleShape2D or RectangleShape2D)
- BossHealthBar will warn in console if requirements aren't met

**✨ NEW: Automatic Shadow System**

The new shadow system provides realistic ground shadows for all bosses:

- **🔄 Auto-created** - Shadows are automatically generated when using BaseBoss inheritance
- **📏 Auto-sized** - Shadow size matches HitBox dimensions with configurable multiplier 
- **📍 Auto-positioned** - Shadows appear below the boss with configurable offset
- **🎨 Configurable** - Opacity, size, and position can be customized per-boss
- **⚡ Performance optimized** - Uses single sprite with alpha modulation

**Shadow Configuration:**
```gdscript
# In your boss _ready() method - customize before calling super._ready()
shadow_enabled = true          # Enable/disable shadows
shadow_size_multiplier = 0.8   # Size relative to HitBox (0.8 = 80% of HitBox size)
shadow_opacity = 0.6           # Shadow transparency (0.0 = invisible, 1.0 = opaque)
shadow_offset_y = 2.0          # Pixels below HitBox bottom
```

**✨ NEW: Real-Time Shadow Hot-Reload System**

The shadow system now supports real-time updates during development:

- **🔄 Single Source of Truth**: BaseBoss.gd contains global defaults for all bosses
- **📝 Boss Script Overrides**: Individual bosses can override specific shadow properties
- **⚡ Instant Updates**: Changes to shadow values update immediately in both test scenes and gameplay
- **🎯 Clean Architecture**: No duplicate defaults across multiple files

**Hot-Reload Architecture:**
```gdscript
# BaseBoss.gd - GLOBAL defaults for ALL bosses (single source of truth)
var shadow_size_multiplier: float = 2.5  # All bosses default to 2.5x HitBox size
var shadow_opacity: float = 0.4          # All bosses default to 40% opacity  
var shadow_offset_y: float = 3.0         # All bosses default to 3px below HitBox

# Individual Boss Scripts - Override only when needed
# DragonLord.gd - Example boss-specific customization
shadow_size_multiplier = 2.2  # Dragon has slightly smaller shadow than global default
shadow_offset_y = 2.0         # Dragon shadow closer to ground
# shadow_opacity inherited from BaseBoss (0.4)
```

**Usage Patterns:**

1. **Global Changes**: Modify BaseBoss.gd values to affect ALL bosses simultaneously
2. **Boss-Specific Overrides**: Set values in individual boss scripts before `super._ready()`
3. **Runtime Overrides**: Use SpawnConfig.shadow_config for dynamic variations

**Testing Your Changes:**
- **ShadowTestScene**: Direct scene instantiation - uses your exact script values
- **F5 Gameplay**: Spawn pipeline - uses same values through unified system
- **Both methods produce identical results** with the new architecture

**Shadow Asset System:**
- Uses existing shadow sprites from `assets/sprites/.../shadow_single.png`
- Automatically applies dark modulation with configurable alpha
- Z-index set to -1 to render below boss sprites

### **Step 2: Create Boss Script**

**✨ NEW: Inherit from BaseBoss for automatic directional animations and unified systems integration**

**Create `scenes/bosses/YourBoss.gd`:**
```gdscript
extends BaseBoss

## Your Boss - Inherits from BaseBoss with custom stats and attack behavior

class_name YourBoss

func _ready() -> void:
    # Set custom boss stats (override BaseBoss defaults)
    max_health = 300.0
    current_health = 300.0
    damage = 40.0
    speed = 60.0
    attack_damage = 40.0
    attack_cooldown = 2.0
    attack_range = 80.0
    chase_range = 350.0
    animation_prefix = "walk"  # Uses walk_north, walk_south, etc.
    
    # Configure shadow properties (optional - defaults to enabled)
    shadow_enabled = true
    shadow_size_multiplier = 0.8  # 80% of HitBox size
    shadow_opacity = 0.6          # Semi-transparent
    shadow_offset_y = 2.0         # 2 pixels below HitBox
    
    # Call parent _ready() to handle all base initialization (including shadow setup)
    super._ready()

func get_boss_name() -> String:
    return "YourBoss"

# Required: Implement your boss's attack behavior
func _perform_attack() -> void:
    Logger.debug("YourBoss attacks for %.1f damage!" % attack_damage, "bosses")
    
    # Apply damage to player via unified DamageService
    var distance_to_player: float = global_position.distance_to(target_position)
    if distance_to_player <= attack_range:
        var source_name = "boss_your_boss"
        var damage_tags = ["physical", "boss"]  # Customize damage tags
        DamageService.apply_damage("player", attack_damage, source_name, damage_tags)

# Optional: Override AI for custom behavior
func _update_ai(dt: float) -> void:
    # Call base AI first (handles chase, movement, directional animations)
    super._update_ai(dt)
    
    # Add custom AI behavior here (special attacks, phase changes, etc.)
```

**🎉 Benefits of BaseBoss Inheritance:**
- ✅ **Automatic directional animations** - Just set `animation_prefix` and it works!
- ✅ **Unified damage system integration** - All damage handling built-in
- ✅ **Performance optimization** - BossUpdateManager registration included
- ✅ **Health bar integration** - BossHealthBar automatically managed
- ✅ **Consistent AI patterns** - Override only what you need to customize
- ✅ **Signal management** - All EventBus connections handled automatically

### **Step 2.5: Setup Directional Animations (For Bosses with 8-Direction Movement)**

**⚠️ Animation Architecture:** 

**✨ NEW: Hybrid Approach - BaseBoss with Boss-Specific Animations**

The new system combines the best of both worlds:
- **BaseBoss handles animation logic** - Automatic 8-directional animation switching
- **Boss scenes define sprite assets** - Each boss has unique visual animations
- **Simple animation_prefix setup** - Just set the prefix, BaseBoss handles the rest

**Benefits:**
- ✅ **Automatic directional logic** - No manual angle calculations needed
- ✅ **Boss-specific visual identity** - Each boss uses unique sprite animations
- ✅ **Consistent behavior** - All bosses use the same animation switching logic
- ✅ **Easy setup** - Just set `animation_prefix = "your_animation_name"`
- ✅ **Minimal code** - BaseBoss handles all the complex logic

#### **A. Prepare Animation Assets**

1. **Organize sprite assets** in this structure:
   ```
   assets/sprites/boss_name/animations/walk_animation/
   ├── north/frame_000.png → frame_007.png
   ├── north-east/frame_000.png → frame_007.png
   ├── east/frame_000.png → frame_007.png
   ├── south-east/frame_000.png → frame_007.png
   ├── south/frame_000.png → frame_007.png
   ├── south-west/frame_000.png → frame_007.png
   ├── west/frame_000.png → frame_007.png
   └── north-west/frame_000.png → frame_007.png
   ```

2. **Verify frame count**: Ensure consistent frame count across all 8 directions (typically 8 frames)

#### **B. Create ExtResource Imports**

Add texture imports to your boss `.tscn` file header (after existing ExtResources):

```gdscript
# Update load_steps count to accommodate all frames (typically 74 for 8x8 frames + other resources)
[gd_scene load_steps=74 format=3 uid="uid://your_boss_uid"]

# Add texture imports for all 8 directions x 8 frames = 64 textures
[ext_resource type="Texture2D" path="res://assets/sprites/boss_name/animations/walk_animation/south/frame_000.png" id="3_s0"]
[ext_resource type="Texture2D" path="res://assets/sprites/boss_name/animations/walk_animation/south/frame_001.png" id="4_s1"]
# ... continue for all south frames (000-007)
[ext_resource type="Texture2D" path="res://assets/sprites/boss_name/animations/walk_animation/north/frame_000.png" id="11_n0"]
# ... continue for all directions: north, east, west, north-east, south-east, north-west, south-west
```

#### **C. Create SpriteFrames Resource**

Add this SpriteFrames SubResource to your `.tscn` file:

```gdscript
[sub_resource type="SpriteFrames" id="SpriteFrames_boss"]
animations = [{
"frames": [{
"duration": 1.0,
"texture": ExtResource("3_s0")
}, {
"duration": 1.0, 
"texture": ExtResource("4_s1")
# ... continue for all 8 south frames
}],
"loop": true,
"name": &"walk_south", 
"speed": 6.0
}, {
"frames": [/* north frames */],
"loop": true,
"name": &"walk_north",
"speed": 6.0
}, {
"frames": [/* east frames */],
"loop": true, 
"name": &"walk_east",
"speed": 6.0
}, {
"frames": [/* west frames */],
"loop": true,
"name": &"walk_west", 
"speed": 6.0
}, {
"frames": [/* north_east frames */],
"loop": true,
"name": &"walk_north_east",
"speed": 6.0
}, {
"frames": [/* south_east frames */],
"loop": true,
"name": &"walk_south_east", 
"speed": 6.0
}, {
"frames": [/* north_west frames */],
"loop": true,
"name": &"walk_north_west",
"speed": 6.0
}, {
"frames": [/* south_west frames */],
"loop": true,
"name": &"walk_south_west",
"speed": 6.0
}]
```

#### **D. Assign SpriteFrames to AnimatedSprite2D**

Update your AnimatedSprite2D node in the `.tscn`:

```gdscript
[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
scale = Vector2(2, 2)
sprite_frames = SubResource("SpriteFrames_boss")
animation = &"walk_south"  # Default starting animation
```

#### **E. Set Animation Prefix in Boss Script**

**✨ SIMPLIFIED: No manual animation logic needed!**

Just set the `animation_prefix` in your boss script's `_ready()` method:

```gdscript
func _ready() -> void:
    # Set your boss stats...
    animation_prefix = "walk"  # For walk_north, walk_south, etc.
    # OR
    animation_prefix = "scary_walk"  # For scary_walk_north, scary_walk_south, etc.
    
    # Call parent _ready()
    super._ready()
```

**🎉 That's it!** BaseBoss automatically handles:
- Converting movement direction to animation names
- Switching animations based on 8-directional movement  
- Only updating animations when direction changes
- Checking animation exists before playing

**Animation Name Pattern:** 
BaseBoss expects animations named: `{animation_prefix}_{direction}`
- Example: `walk_north`, `walk_south_east`, `scary_walk_west`, etc.

#### **F. Animation Testing Checklist**

✅ All 8 animations load without errors in Godot editor  
✅ Each direction has consistent frame count (8 frames)  
✅ Animation speed (6.0 FPS) provides smooth movement  
✅ Direction switching responds correctly to movement input  
✅ Animations loop seamlessly during continuous movement  

### **Step 3: Create Boss Configuration**

**Create `data/content/enemies/your_boss.tres`:**
```gdscript
[gd_resource type="Resource" script_class="EnemyType" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/domain/EnemyType.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/bosses/YourBoss.tscn" id="2"]

[resource]
script = ExtResource("1")
id = "your_boss"
display_name = "Your Boss Name"
health = 300.0
speed = 50.0
speed_min = 45.0
speed_max = 55.0
size = Vector2(96, 96)
collision_radius = 48.0
xp_value = 150
spawn_weight = 0.0  # 0.0 = doesn't spawn in random waves
render_tier = "special_boss"
visual_config = {
    "color": {
        "r": 1.0,
        "g": 0.5,
        "b": 0.0,
        "a": 1.0
    },
    "shape": "square"
}
behavior_config = {
    "aggro_range": 350.0,
    "ai_type": "boss_custom"
}
shadow_config = {
    "enabled": true,
    "size_multiplier": 0.8,
    "opacity": 0.6,
    "offset_y": 2.0
}
boss_scene = ExtResource("2")
is_special_boss = true
boss_spawn_method = "scene"
```

**✨ NEW: F5 Hot-Reload System for Real-Time Balancing**

The boss system now supports instant size factor updates without restarting the game:

**Hot-Reload Workflow:**
1. **Edit .tres file** - Change size_factor value (e.g., 1.0 → 2.0)
2. **Press F5 in-game** - Forces reload of all enemy templates 
3. **Spawn new enemies** - Immediately use updated size factors
4. **Iterate quickly** - Perfect for real-time balancing and testing

**Supported Template Properties:**
- `size_factor` - Boss scaling (0.5x = half size, 2.0x = double size)
- `health_range`, `damage_range`, `speed_range` - Combat stats
- `shadow_config` - Shadow appearance settings
- All other template properties reload instantly

**Technical Details:**
- Uses `CACHE_MODE_IGNORE` to bypass Godot's resource cache
- Integrated with existing debug system (F5 key in DebugManager)
- Works with both individual templates and inherited templates
- Zero custom file watchers - leverages Godot's built-in resource system

### **Step 4: Test Your Boss**

1. **Load scene in editor** to verify visual setup
2. **Test spawn via debug key**:
   ```gdscript
   # In Arena.gd or create test function
   spawn_boss_by_id("your_boss", Vector2(100, 100))
   ```
3. **Test damage integration** with T key damage test
4. **Verify AI behavior** with player movement
5. **Check death handling** by dealing enough damage

---

## Advanced Boss Features

### **Multi-Phase Bosses**
```gdscript
func _check_phase_transitions() -> void:
    var health_percent = current_health / max_health
    if health_percent <= 0.5 and current_phase == 1:
        _enter_phase_2()

func _enter_phase_2() -> void:
    current_phase = 2
    attack_damage *= 1.5
    speed *= 1.2
    Logger.info("Boss entered Phase 2!", "bosses")
```

### **Special Attack Patterns**
```gdscript
func _perform_special_attack() -> void:
    # Example: Spawn projectiles in circle
    for i in range(8):
        var angle = (i * PI * 2) / 8
        var direction = Vector2.from_angle(angle)
        _spawn_boss_projectile(direction)
```

### **Custom Visual Effects**
```gdscript
func _spawn_death_effect() -> void:
    # Add particles, screen shake, sound effects
    var effect = preload("res://effects/BossDeathEffect.tscn").instantiate()
    get_parent().add_child(effect)
    effect.global_position = global_position
```

---

## Boss Spawning Integration

### **Manual Spawning**
```gdscript
# In Arena.gd or other systems
var success = wave_director.spawn_boss_by_id("your_boss", Vector2(200, 200))
```

### **Event-Based Spawning**
```gdscript
# Connect to game events
func _on_player_reached_area() -> void:
    spawn_boss_by_id("your_boss", boss_spawn_position)
```

### **Wave-Based Spawning**
```gdscript
# Set spawn_weight > 0.0 in configuration to include in waves
# Or use manual wave director controls
```

---

## Troubleshooting

### **Boss Not Taking Damage:**
- ✅ Check `get_current_health()`, `set_current_health()` methods exist
- ✅ Verify `died` signal is declared
- ✅ Confirm DamageService registration in `_ready()`
- ✅ Test with T key damage test function

### **Boss Not Spawning:**
- ✅ Check `.tres` file is properly configured
- ✅ Verify `boss_scene` reference points to correct scene
- ✅ Confirm `is_special_boss = true` and `boss_spawn_method = "scene"`
- ✅ Check spawn position is within valid game area

### **Boss Movement Issues:**
- ✅ **Use CircleShape2D collision** - RectangleShape2D causes jerky movement
- ✅ **Center collision shapes** at (0, 0) - Offset shapes cause rotation issues
- ✅ **Set appropriate radius** - Too large causes wall sticking, too small allows clipping
- ✅ **Match HitBox size** to collision shape for consistent damage detection

### **Health Bar Issues:**
- ✅ **Health bar not visible** - Appears only after first damage (performance feature)
- ✅ **Health bar wrong size** - Check HitBox/HitBoxShape node structure exists
- ✅ **Health bar wrong position** - Ensure HitBoxShape has assigned shape (Circle or Rectangle)
- ✅ **Health bar not adjusting** - Check console for BossHealthBar warnings about missing nodes

### **Shadow Issues:**
- ✅ **Shadow not appearing** - Check `shadow_enabled = true` in boss _ready() method
- ✅ **Shadow wrong size** - Adjust `shadow_size_multiplier` (0.5-1.5 recommended range)
- ✅ **Shadow too dark/light** - Modify `shadow_opacity` (0.3-0.8 for realistic shadows)
- ✅ **Shadow wrong position** - Check HitBox/HitBoxShape structure, adjust `shadow_offset_y`
- ✅ **Shadow appears above boss** - Verify BossShadow z_index is set to -1
- ✅ **Multiple shadows** - Only one shadow per boss; check for manual BossShadow instances in scene
- ✅ **Shadow asset not found** - Verify shadow_single.png exists in sprite assets directory

### **Boss AI Not Working:**
- ✅ Verify EventBus.combat_step connection in `_ready()` (or BaseBoss inheritance)
- ✅ Check PlayerState.has_player_reference() returns true
- ✅ Confirm collision detection and movement logic
- ✅ Test with Logger.debug() statements in AI methods

### **Performance Issues:**
- ✅ Use object pooling for boss projectiles/effects
- ✅ Limit expensive calculations to combat step frequency (30 Hz)
- ✅ Cache frequently accessed values (player position, distances)
- ✅ Use groups instead of scene tree traversal for finding targets

---

## Best Practices

### **Code Organization:**
- **Keep AI logic in `_update_ai()`** for consistent timing
- **Use combat step frequency** for game logic (30 Hz)
- **Cache player position** from PlayerState rather than scene queries
- **Use Logger for debugging** instead of print statements

### **Performance:**
- **Register/unregister with DamageService** in _ready()/_exit_tree()
- **Use signal connections** instead of polling for events
- **Batch expensive operations** (pathfinding, complex calculations)
- **Clean up resources** in _exit_tree() to prevent memory leaks

### **Integration:**
- **Follow signal patterns** for boss death/rewards
- **Use SpawnConfig** for consistent configuration
- **Test with unified damage system** to ensure compatibility
- **Document custom behaviors** for team members

### **Shadow System:**
- **Use BaseBoss inheritance** for automatic shadow management
- **Configure shadows in _ready()** before calling super._ready()
- **Test shadow positioning** with different boss sizes and collision shapes
- **Use consistent shadow settings** across similar boss types for visual coherence
- **Disable shadows for flying bosses** by setting `shadow_enabled = false`

With this guide, you can create complex, performant bosses that integrate seamlessly with the game's unified systems while maintaining flexibility for unique mechanics and behaviors.