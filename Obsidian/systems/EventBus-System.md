# EventBus System

## Current Implementation

**File**: `vibe/autoload/EventBus.gd`
**Type**: Autoload (Global Singleton)

## Signal Architecture

**🆕 UPDATED**: All signals now use **typed payload objects** for compile-time safety and better IDE support.

### Combat & Damage Signals
```gdscript
# Typed payload approach - provides compile-time guarantees
signal damage_requested(payload)  # DamageRequestPayload
signal damage_applied(payload)    # DamageAppliedPayload  
signal combat_step(payload)       # CombatStepPayload
signal enemy_killed(payload)      # EnemyKilledPayload
signal entity_killed(payload)     # EntityKilledPayload
```

### Player Progression Signals  
```gdscript
# XP and leveling with typed payloads
signal xp_changed(payload)        # XpChangedPayload
signal level_up(payload)          # LevelUpPayload
```

### Arena & Environment Signals
```gdscript
# Spatial events with typed payloads
signal arena_bounds_changed(payload)      # ArenaBoundsChangedPayload
signal player_position_changed(payload)   # PlayerPositionChangedPayload
signal damage_dealt(payload)              # DamageDealtPayload
```

### Interaction & Loot Signals
```gdscript
# UI and gameplay interactions
signal interaction_prompt_changed(payload)  # InteractionPromptChangedPayload
signal loot_generated(payload)             # LootGeneratedPayload
```

### Typed Payload Classes
**Location**: `/vibe/scripts/domain/signal_payloads/`
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

### EventBus → Systems → EventBus  
```
Input → EventBus.ability_cast → AbilitySystem → EventBus.damage_requested → DamageSystem
```

## Signal Lifecycle Management

### Connection Patterns
```gdscript
# In _ready()
EventBus.signal_name.connect(_on_signal_name)

# In _exit_tree() 
EventBus.signal_name.disconnect(_on_signal_name)
```

### Current Connection Locations
- **Arena.gd**: Lines 61, 367 (main signal hub)
- **HUD.gd**: Lines 11-12 (UI updates)
- **Main.gd**: Line 8 (debug combat step)

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