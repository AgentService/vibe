# EventBus System

## Current Implementation

**File**: `autoload/EventBus.gd`
**Type**: Autoload (Global Singleton)

## Signal Architecture

**🆕 UPDATED**: All signals now use **typed payload objects** for compile-time safety and better IDE support.

### Core Signal Groups

This section reflects the signals currently defined in `autoload/EventBus.gd`.

**TIMING**
- `signal combat_step(payload)`: Drives deterministic combat updates.

**DAMAGE**
- `signal damage_applied(payload)`: Confirms a single damage instance was applied.
- `signal damage_batch_applied(payload)`: Confirms multiple damage instances for AoE attacks.
- `signal damage_dealt(payload)`: Signals damage was dealt, used for effects like camera shake.
- `signal damage_taken(damage: int)`: Signals the player has taken damage.
- `signal player_died()`: Signals the player's health has reached zero.

**MELEE**
- `signal melee_attack_started(payload)`: A melee attack has been initiated.
- `signal melee_enemies_hit(payload)`: A melee attack has hit one or more enemies.

**ENTITIES**
- `signal entity_killed(payload)`: An entity has been killed, contains reward data.
- `signal enemy_killed(payload)`: **[DEPRECATED]** Legacy signal, use `entity_killed`.

**PROGRESSION**
- `signal xp_changed(payload)`: The player's XP has changed.
- `signal level_up(payload)`: The player has leveled up.

**GAME STATE & CAMERA**
- `signal game_paused_changed(payload)`: The game's pause state has changed.
- `signal arena_bounds_changed(payload)`: Informs the camera of the new arena's boundaries.
- `signal player_position_changed(payload)`: Provides cached player position for other systems.

**INTERACTION & LOOT**
- `signal interaction_prompt_changed(payload)`: **[DEPRECATED]** No longer used.
- `signal loot_generated(payload)`: Signals loot was generated (e.g., from a chest).

**DEBUG**
- `signal cheat_toggled(payload)`: A debug cheat has been toggled.

### Typed Payload Classes
**Location**: `/scripts/domain/signal_payloads/`
- All payload classes provide compile-time type safety
- Accessed via EventBus preloads: `EventBus.DamageRequestPayload.new()`
- Full IDE support with property auto-completion

## UI Communication Patterns

### HUD Updates (Event → UI) - **UPDATED**
```gdscript
# In HUD.gd - now uses typed payloads
EventBus.xp_changed.connect(_on_xp_changed)
EventBus.level_up.connect(_on_level_up)

# Handler receives typed payload with full IDE support
func _on_xp_changed(payload) -> void:
    _update_xp_display(payload.current_xp, payload.next_level_xp)
```

### Modal Triggers (Event → Modal) - **UPDATED**  
```gdscript
# In Arena.gd - now uses typed payloads
EventBus.level_up.connect(_on_level_up)

# Triggers CardPicker modal with typed payload
func _on_level_up(payload) -> void:
    # payload.new_level available with full IDE support
    RunManager.pause_game(true)
    card_picker.open()
```

## Signal Flow Analysis

### ✅ Well-Implemented Patterns
- **Decoupled Communication**: UI doesn't directly reference systems
- **Consistent Naming**: Clear signal names with type hints
- **Proper Cleanup**: Signals disconnected in `_exit_tree()`
- **Type Safety**: All signals use typed parameters

### ❌ Current Issues
- **Limited UI Signals**: No signals for UI state changes
- **No Modal Events**: No unified modal open/close events  
- **Missing System Events**: Some systems communicate directly

## Missing Signal Categories

### UI State Signals
```gdscript
# Should be added to EventBus
signal modal_opened(modal_name: String)
signal modal_closed(modal_name: String)
signal ui_state_changed(state: String)
signal tooltip_requested(text: String, position: Vector2)
```

### Scene Transition Signals
```gdscript
# For scene management system
signal scene_change_requested(scene_name: String)
signal scene_transition_started(from_scene: String, to_scene: String)
signal scene_transition_completed(scene_name: String)
```

### Input & Interaction Signals
```gdscript
# For user interactions
signal input_context_changed(context: String)  # "game", "menu", "modal"
signal hotkey_pressed(action: String)
signal interaction_available(object_id: String)
```

## Communication Anti-Patterns

### Direct Scene References (❌ Wrong)
```gdscript
# Bad - direct coupling
get_node("../../UI/HUD").update_health(hp)
```

### Proper EventBus Usage (✅ Correct)
```gdscript
# Good - decoupled communication
EventBus.health_changed.emit(current_hp, max_hp)
```

## System Integration Patterns

### Systems → EventBus → UI
```
XpSystem → EventBus.xp_changed → HUD._on_xp_changed()
AbilitySystem → EventBus.level_up → Arena._on_level_up() → CardPicker.open()
```

### Enemy System Signal Flow (UPDATED)
```
WaveDirector.enemies_updated(Array[EnemyEntity]) → Arena._on_enemies_updated()
    ↓
EnemyRenderTier.group_enemies_by_tier() → Dictionary arrays for MultiMesh
    ↓
MultiMeshInstance2D.multimesh.set_instance_transform_2d()
```

### Combat System Integration (UPDATED)
```
DamageSystem collision detection → WaveDirector.damage_enemy(pool_index)
    ↓
EnemyEntity.hp -= damage → EventBus.enemy_killed → XpSystem._on_enemy_killed()
```

### EventBus → Systems → EventBus  
```
Input → EventBus.ability_cast → AbilitySystem → DamageService.apply_damage() → EventBus.damage_applied
```

## Signal Lifecycle Management

### Connection Patterns
```gdscript
# In _ready()
EventBus.signal_name.connect(_on_signal_name)

# In _exit_tree() 
EventBus.signal_name.disconnect(_on_signal_name)
```

### Current Connection Locations (UPDATED)
- **Arena.gd**: Lines 61, 367 (main signal hub) - now processes enemies_updated with Array[EnemyEntity]
- **HUD.gd**: Lines 11-12 (UI updates) - unchanged, uses typed payloads
- **WaveDirector.gd**: Line 35 (enemies_updated signal) - emits typed Array[EnemyEntity]
- **DamageSystem.gd**: Lines 18-19 (combat_step) - enhanced object identity collision
- **MeleeSystem.gd**: Line 32 (combat_step) - now references WaveDirector for pool indexing

## Performance Considerations

### ✅ Efficient Patterns
- **Typed Signals**: No runtime type checking overhead
- **Direct Connections**: No reflection or string matching
- **Proper Cleanup**: No memory leaks from signal references

### ⚠️ Potential Issues
- **Signal Flooding**: High-frequency signals like `combat_step`
- **Cascade Effects**: Multiple systems reacting to same signal
- **Debug Overhead**: Print statements in signal handlers

## Future Enhancements

### Signal Debugging
```gdscript
# Proposed debug wrapper
func emit_debug(signal_name: String, args: Array):
    if EventBus.debug_mode:
        Logger.debug("EventBus: " + signal_name + " with " + str(args), "debug")
    emit(signal_name, args)
```

### Signal Analytics
- Track most frequently fired signals
- Monitor signal connection/disconnection patterns
- Detect potential signal loops

## Related Systems

- [[Modal-Overlay-System]]: How modals use EventBus for triggers
- [[Canvas-Layer-Structure]]: UI layer communication via EventBus  
- [[Scene-Management-System]]: Scene transitions via signals
- [[UI-Architecture-Overview]]: Overall communication architecture
