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
3. **Add CollisionShape2D child** with appropriate collision shape
4. **Add visual child** (AnimatedSprite2D, Sprite2D, or custom setup)
5. **Configure collision layers/masks** for enemy detection

**Example scene structure:**
```
YourBoss (CharacterBody2D)
├── CollisionShape2D
│   └── AnimatedSprite2D
└── [Optional: Additional visual/audio components]
```

### **Step 2: Create Boss Script**

**Create `scenes/bosses/YourBoss.gd`:**
```gdscript
extends CharacterBody2D

## Your Boss - Scene-based boss with unified damage integration
class_name YourBoss

signal died

@onready var animated_sprite: AnimatedSprite2D = $CollisionShape2D/AnimatedSprite2D

# Boss configuration
var spawn_config: SpawnConfig
var max_health: float = 300.0
var current_health: float = 300.0
var speed: float = 50.0
var attack_damage: float = 40.0
var attack_cooldown: float = 2.0
var last_attack_time: float = 0.0

# AI configuration
var target_position: Vector2
var attack_range: float = 80.0
var chase_range: float = 350.0

func _ready() -> void:
    Logger.info("YourBoss spawned with " + str(max_health) + " HP", "bosses")
    
    # Start animation
    if animated_sprite and animated_sprite.sprite_frames:
        animated_sprite.play("default")
        Logger.debug("YourBoss animation started", "bosses")
    
    # BOSS PERFORMANCE V2: Register with centralized BossUpdateManager (replaces individual combat_step connection)
    var boss_id = "boss_" + str(get_instance_id())
    BossUpdateManager.register_boss(self, boss_id)
    Logger.debug("YourBoss registered with BossUpdateManager as " + boss_id, "performance")
    
    # DAMAGE V3: Register with both DamageService and EntityTracker
    var entity_id = "boss_" + str(get_instance_id())
    var entity_data = {
        "id": entity_id,
        "type": "boss",
        "hp": current_health,
        "max_hp": max_health,
        "alive": true,
        "pos": global_position
    }
    # Register with both systems for unified damage V3
    DamageService.register_entity(entity_id, entity_data)
    EntityTracker.register_entity(entity_id, entity_data)
    Logger.debug("YourBoss registered with DamageService and EntityTracker as " + entity_id, "bosses")

func _exit_tree() -> void:
    # BOSS PERFORMANCE V2: Unregister from BossUpdateManager
    var boss_id = "boss_" + str(get_instance_id())
    BossUpdateManager.unregister_boss(boss_id)
    
    # DAMAGE V3: Unregister from both systems
    var entity_id = "boss_" + str(get_instance_id())
    DamageService.unregister_entity(entity_id)
    EntityTracker.unregister_entity(entity_id)

# Required setup method for spawn system
func setup_from_spawn_config(config: SpawnConfig) -> void:
    spawn_config = config
    max_health = config.health
    current_health = config.health
    speed = config.speed
    attack_damage = config.damage
    
    # Set position and visual config
    global_position = config.position
    modulate = config.color_tint
    scale = Vector2.ONE * config.size_scale
    
    Logger.info("YourBoss configured: HP=%.1f DMG=%.1f SPD=%.1f" % [max_health, attack_damage, speed], "bosses")

# BOSS PERFORMANCE V2: Batch AI interface called by BossUpdateManager
## Replaces individual _on_combat_step connections with centralized processing
func _update_ai_batch(dt: float) -> void:
    _update_ai(dt)
    last_attack_time += dt

# AI logic (customize for your boss behavior)
func _update_ai(dt: float) -> void:
    if not PlayerState.has_player_reference():
        return
        
    target_position = PlayerState.position
    var distance_to_player: float = global_position.distance_to(target_position)
    
    # Chase behavior
    if distance_to_player <= chase_range:
        if distance_to_player > attack_range:
            # Move toward player
            var direction: Vector2 = (target_position - global_position).normalized()
            velocity = direction * speed
            move_and_slide()
        else:
            # In attack range - stop and attack
            velocity = Vector2.ZERO
            if last_attack_time >= attack_cooldown:
                _perform_attack()
                last_attack_time = 0.0

# Attack logic (customize for your boss attacks)
func _perform_attack() -> void:
    Logger.debug("YourBoss attacks for %.1f damage!" % attack_damage, "bosses")
    
    # Example: Damage player if in range
    var distance_to_player: float = global_position.distance_to(target_position)
    if distance_to_player <= attack_range:
        if EventBus:
            EventBus.damage_taken.emit(attack_damage)

# Death handling
func _die() -> void:
    Logger.info("YourBoss has been defeated!", "bosses")
    died.emit()
    queue_free()

# Required interface methods for damage system
func get_max_health() -> float:
    return max_health

func get_current_health() -> float:
    return current_health

func set_current_health(new_health: float) -> void:
    current_health = new_health
    if current_health <= 0:
        _die()

func is_alive() -> bool:
    return current_health > 0.0
```

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
boss_scene = ExtResource("2")
is_special_boss = true
boss_spawn_method = "scene"
```

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

### **Boss AI Not Working:**
- ✅ Verify EventBus.combat_step connection in `_ready()`
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

With this guide, you can create complex, performant bosses that integrate seamlessly with the game's unified systems while maintaining flexibility for unique mechanics and behaviors.