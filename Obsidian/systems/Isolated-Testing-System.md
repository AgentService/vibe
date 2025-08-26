# Isolated Testing System

## Overview
The isolated testing system provides dedicated test scenes for individual game systems, allowing developers to verify system behavior without full game dependencies. Each test focuses on a single system with minimal UI for interaction and feedback.

## Current Test Scenes

### `/vibe/tests/DamageSystem_Isolated.tscn`
**Purpose:** Test damage calculation, application, and enemy death handling
- **Auto-damage:** Applies damage to random/nearest enemies every 2 seconds
- **Visual feedback:** Enemy scaling based on health percentage
- **Death handling:** Uses proper WaveDirector damage methods
- **Controls:** WASD (move), E (spawn enemy), 1-4 (damage types), +/- (damage amount)

### `/vibe/tests/EnemySystem_Isolated.tscn`
**Purpose:** Test enemy spawning, management, and rendering
- **Grid spawning:** Space spawns 50 enemies in 10x5 grid pattern
- **Type variations:** Different enemy types with distinct visual scaling
- **Camera setup:** Positioned at (400,300) with 0.8x zoom for optimal viewing
- **Controls:** Space (spawn grid), R (clear all), 1-4 (spawn specific types)

### `/vibe/tests/MeleeSystem_Isolated.tscn`
**Purpose:** Test melee attack mechanics and cone detection
- **Auto cone attacks:** 60-degree cone attacks every 1.5 seconds
- **Range detection:** 80-unit attack range targeting nearest enemies  
- **Visual feedback:** Enemy scaling reflects health damage
- **Controls:** WASD (move), E (spawn enemy at mouse)

## Architecture Patterns

### System Setup Pattern
```gdscript
func _setup_systems():
    # Create EnemyRegistry first (WaveDirector depends on it)
    var enemy_registry = EnemyRegistry.new()
    add_child(enemy_registry)
    
    # Create WaveDirector and inject EnemyRegistry
    wave_director = WaveDirector.new()
    add_child(wave_director)
    wave_director.set_enemy_registry(enemy_registry)
    
    # Connect signals for visual updates
    if wave_director.has_signal("enemies_updated"):
        wave_director.enemies_updated.connect(_update_enemy_visuals)
```

### Visual Update Pattern
```gdscript
func _update_enemy_visuals():
    var alive_enemies = wave_director.get_alive_enemies()
    enemy_multimesh.multimesh.instance_count = alive_enemies.size()
    
    for i in range(alive_enemies.size()):
        var enemy = alive_enemies[i]
        var transform = Transform2D()
        transform.origin = enemy.pos
        
        # Scale based on health or type
        var scale_factor = _calculate_scale(enemy)
        transform = transform.scaled(Vector2(scale_factor, scale_factor))
        
        enemy_multimesh.multimesh.set_instance_transform_2d(i, transform)
```

### Camera Setup Pattern
```gdscript
func _setup_camera():
    camera.zoom = Vector2(0.8, 0.8)  # Slight zoom out for better overview
    camera.position = Vector2(400, 300)  # Center on test area
```

## When to Create New Isolated Tests

Create a new isolated test when:

1. **New Core System Added**
   - Any system in `/scripts/systems/` that manages game entities
   - Systems with complex logic requiring visual verification
   - Systems with real-time behavior (combat, movement, spawning)

2. **System Integration Points**
   - Systems that interact with multiple other systems
   - Systems that emit/consume EventBus signals
   - Systems with complex state management

3. **Visual/Interactive Systems**
   - Systems with visual feedback (UI, rendering, effects)  
   - Systems requiring player input testing
   - Systems with timing-dependent behavior

4. **Performance-Critical Systems**
   - Systems managing large numbers of entities
   - Systems with pooling/caching mechanisms
   - Systems with frame-rate dependencies

### Examples of Systems That Need Tests:
- **ProjectileSystem** → Test projectile spawning, movement, collision
- **EffectSystem** → Test visual effects, duration, cleanup
- **AISystem** → Test enemy behavior, pathfinding, state changes
- **InventorySystem** → Test item management, UI updates
- **AudioSystem** → Test sound triggering, volume, spatial audio

### Test Scene Naming Convention:
`/vibe/tests/[SystemName]_Isolated.tscn`
`/vibe/tests/[SystemName]_Isolated.gd`

## Test Development Guidelines

### Essential Components
1. **Camera2D** with proper positioning and zoom
2. **MultiMeshInstance2D** for efficient entity rendering (if applicable)
3. **UI Layer** with CanvasLayer for controls and info display
4. **Player node** for interaction testing (if needed)

### Visual Standards
- **Base enemy scale:** 0.8 with type-specific modifiers
- **Enemy colors:** Orange base instead of white for visibility
- **Positioning:** Center around (400,300) to avoid origin clustering
- **Spacing:** 32px for tight grids, 150px for scattered spawns

### Control Standards
- **WASD:** Player movement (if applicable)
- **Space:** Primary action (spawn grid, main test)
- **E:** Secondary spawn (mouse position)
- **R:** Reset/clear action
- **1-4:** Type/mode selection
- **+/-:** Parameter adjustment

### Debug Output
- Use `print()` statements for isolated test feedback
- Log system state before/after major actions
- Show entity counts and positions for verification
- Include timing information for auto-actions

## Integration with Main Codebase

### Running Tests
```bash
# Headless testing
"./Godot_v4.4.1-stable_win64_console.exe" --headless vibe/tests/SystemName_Isolated.tscn --quit-after 5

# Visual testing via MCP
mcp__godot-mcp__open_scene("res://tests/SystemName_Isolated.tscn")
mcp__godot-mcp__play_scene("current")
```

### Architecture Consistency
- All tests use WaveDirector/EnemyEntity pattern (not legacy EnemyRegistry)
- Systems use proper EventBus signal communication
- Tests follow the same dependency injection patterns as main game
- Use Logger for production code, `print()` for test-specific output

## Maintenance

### Regular Updates Needed
- When system interfaces change (method signatures, signals)
- When new enemy types are added to content files
- When EventBus payloads are modified
- When core architecture patterns change

### Validation
- Tests should run without errors in headless mode
- Visual elements should render correctly with MCP
- All controls should provide expected feedback
- Performance should remain stable with max entity counts