# Modern Debug Interface System

**Priority:** High  
**Status:** Not Started  
**Estimated Effort:** 3-4 days  
**Dependencies:** EnemyManager, BossFactory, V2AbilityProxy, TicketSpawnManager  

## Overview
Replace the outdated cheat system with a modern, comprehensive debugging interface that provides real-time entity inspection, manual spawning controls, and ability testing tools. This system will significantly improve development velocity and testing capabilities.

## Architecture Goals
1. **Modern Debug Interface**: Replace outdated cheat system with proper debugging tools
2. **Developer Experience**: Intuitive UI with visual feedback and real-time inspection
3. **Unified Systems**: Create consistent interfaces while preserving performance optimizations  
4. **Scalability**: Make adding new content straightforward and data-driven

## Core Components

### 1. DebugManager (Core Debug Coordinator)
**File:** `scripts/systems/debug/DebugManager.gd`

```gdscript
extends Node
class_name DebugManager

static var instance: DebugManager

signal debug_mode_toggled(enabled: bool)
signal entity_selected(entity_id: int)
signal entity_inspected(entity_data: Dictionary)

var debug_enabled: bool = false
var selected_entity_id: int = -1
var debug_ui: Control

func toggle_debug_mode():
    debug_enabled = !debug_enabled
    emit_signal("debug_mode_toggled", debug_enabled)
    
    if debug_enabled:
        _enter_debug_mode()
    else:
        _exit_debug_mode()

func _enter_debug_mode():
    # Disable Twitch spawning
    TicketSpawnManager.instance.set_spawning_enabled(false)
    
    # Clear all enemies
    EnemyManager.instance.clear_all_enemies()
    BossFactory.instance.clear_all_bosses()
    
    # Show debug UI
    _show_debug_ui()

func _exit_debug_mode():
    # Re-enable normal systems
    TicketSpawnManager.instance.set_spawning_enabled(true)
    
    # Hide debug UI
    _hide_debug_ui()
```

### 2. Entity Selection System
**File:** `scripts/systems/debug/EntitySelector.gd`

```gdscript
extends Node
class_name EntitySelector

func get_entity_at_position(world_pos: Vector2) -> Dictionary:
    # Check enemies first (array-based)
    var enemy_id = EnemyManager.instance.get_enemy_at_position(world_pos)
    if enemy_id >= 0:
        return {
            "type": "enemy",
            "id": enemy_id,
            "data": EnemyManager.instance.get_enemy_data(enemy_id)
        }
    
    # Check bosses (node-based)
    var boss = BossFactory.instance.get_boss_at_position(world_pos)
    if boss:
        return {
            "type": "boss",
            "node": boss,
            "data": boss.get_debug_data()
        }
    
    return {}
```

### 3. Debug Ability Trigger
**File:** `scripts/systems/debug/DebugAbilityTrigger.gd`

```gdscript
extends Node
class_name DebugAbilityTrigger

func trigger_ability(entity_data: Dictionary, ability_name: String):
    match entity_data.type:
        "enemy":
            AbilityProxy.instance.force_execute_ability(entity_data.id, ability_name)
        "boss":
            if entity_data.node.has_method("force_trigger_ability"):
                entity_data.node.force_trigger_ability(ability_name)
```

## UI Layout Specification

```
┌─────────────────────────────────────────┐
│ Debug Panel (F12 to toggle)             │
├─────────────────────────────────────────┤
│ Enemy Spawner                           │
│ ┌─────────────────────────────────────┐ │
│ │ [Dropdown: Select Enemy Type]       │ │
│ │ ├─ Knight Regular                  │ │
│ │ ├─ Knight Elite                    │ │
│ │ ├─ Knight Swarm                    │ │
│ │ └─ Knight Boss                     │ │
│ └─────────────────────────────────────┘ │
│ [Spawn at Cursor] [Spawn at Player]     │
│ Count: [1] [5] [10] [100]              │
├─────────────────────────────────────────┤
│ Entity Inspector                        │
│ ┌─────────────────────────────────────┐ │
│ │ Selected: Knight Elite #42          │ │
│ │ Type: knight_elite                  │ │
│ │ Health: 45/50                       │ │
│ │ Speed: 75                           │ │
│ │ XP Value: 15                        │ │
│ │ State: Moving                       │ │
│ │                                     │ │
│ │ Abilities:                          │ │
│ │ [Trigger Charge] (Ready)            │ │
│ │ [Trigger Block] (Cooldown: 2.3s)    │ │
│ │ [Trigger Stomp] (Ready)             │ │
│ └─────────────────────────────────────┘ │
│ [Kill Selected] [Heal Full] [Damage 10] │
├─────────────────────────────────────────┤
│ System Controls                         │
│ □ Pause AI                             │
│ □ Show Collision Shapes                │
│ □ Show Pathfinding Grid                │
│ □ Show Performance Stats               │
│ [Clear All Enemies] [Reset Session]    │
└─────────────────────────────────────────┘
```

## Implementation Tasks

### Phase 1: Core Debug Framework
- [ ] Create DebugManager autoload system
- [ ] Implement F12 toggle functionality
- [ ] Add debug mode state management
- [ ] Create basic debug UI scene structure
- [ ] Implement debug UI visibility controls

### Phase 2: Entity Management
- [ ] Build EntitySelector system
- [ ] Add click-to-select entity functionality
- [ ] Create entity data inspection system
- [ ] Implement visual selection indicators
- [ ] Add entity manipulation controls (kill, heal, damage)

### Phase 3: Spawning System
- [ ] Create enemy type dropdown with ContentDB integration
- [ ] Implement spawn-at-cursor functionality
- [ ] Add spawn-at-player option
- [ ] Create batch spawning controls (1, 5, 10, 100)
- [ ] Add spawn position validation

### Phase 4: Ability Testing
- [ ] Build DebugAbilityTrigger system
- [ ] Create ability UI buttons for selected entities
- [ ] Implement force-trigger functionality for AbilityProxy
- [ ] Add boss ability forcing support
- [ ] Display ability cooldowns and states

### Phase 5: System Integration
- [ ] Add TicketSpawnManager integration (disable/enable)
- [ ] Implement system pause controls (AI, collisions)
- [ ] Create performance stats overlay
- [ ] Add pathfinding grid visualization
- [ ] Implement collision shape debugging

### Phase 6: Advanced Features
- [ ] Create save/load test scenario functionality
- [ ] Add entity state modification tools
- [ ] Implement debug command console
- [ ] Create automated test scenario runner
- [ ] Add debug session recording

## Technical Requirements

### Input Handling
- **F12**: Toggle debug mode
- **Mouse Click**: Select entity at cursor position
- **UI Events**: Handle all debug panel interactions

### Integration Points
- **EnemyManager**: Entity data access and manipulation
- **BossFactory**: Boss entity management
- **AbilityProxy**: Enemy ability triggering
- **TicketSpawnManager**: Spawning control
- **ContentDB**: Enemy type enumeration

### Performance Considerations
- Debug UI only active when debug mode enabled
- Entity selection using efficient spatial queries
- Real-time updates throttled to 30fps
- Debug overlays as separate rendering layers

## Debug Mode Workflow

1. **Press F12** to enter debug mode
2. **All enemies cleared**, Twitch spawning disabled
3. **Select enemy type** from dropdown
4. **Click to spawn** at cursor position
5. **Click enemy** to select and inspect
6. **Trigger abilities** manually for testing
7. **Monitor stats** in real-time
8. **Press F12** again to exit debug mode

## File Structure
```
scripts/systems/debug/
├── DebugManager.gd                 # Core debug coordinator
├── EntitySelector.gd               # Entity selection system
├── DebugAbilityTrigger.gd         # Ability testing system
├── DebugUI.gd                     # Main debug panel controller
└── DebugOverlay.gd                # Visual debug overlays

scenes/debug/
├── DebugPanel.tscn                # Main debug UI
├── EntityInspector.tscn           # Entity inspection panel
├── SpawnerControls.tscn           # Enemy spawning controls
└── SystemControls.tscn            # System debugging controls
```

## Future Enhancements
- **Save/Load Test Scenarios**: Export current state for reproduction
- **Replay System**: Record and replay entity behaviors  
- **Visual Scripting**: Node-based ability creation
- **Mod Support**: Allow community content via resources
- **A/B Testing**: Compare different stat configurations
- **Automated Testing**: Use debug system for integration tests

## Validation Criteria
- [ ] F12 successfully toggles debug mode
- [ ] Entity selection works for both enemies and bosses
- [ ] Ability triggering functions correctly
- [ ] Enemy spawning respects ContentDB definitions
- [ ] Performance impact minimal when debug disabled
- [ ] UI responsive and intuitive
- [ ] System integration maintains game stability

## Related Documents
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture patterns
- [CLAUDE.md](../CLAUDE.md) - Development guidelines
- [EnemyManager Documentation](../systems/EnemyManager.md)
- [AbilityProxy Documentation](../systems/AbilityProxy.md)

---
**Notes:**
- This replaces the legacy cheat system entirely
- Must maintain performance when debug mode disabled
- Should integrate seamlessly with existing ContentDB patterns
- UI should follow established game theme and styling