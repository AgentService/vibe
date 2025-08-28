# Modal Overlay System

## Current Implementation

### CardPicker Modal
**File**: `scenes/ui/CardPicker.tscn`
**Script**: `scenes/ui/CardPicker.gd`

### Modal Flow
```gdscript
# Triggered from Arena.gd line 226-229
func _on_level_up(new_level: int) -> void:
    print("Arena received level up signal: ", new_level)
    RunManager.pause_game(true)      # Pause game
    card_picker.open()               # Show modal
```

### Modal Pattern Analysis
- **Trigger**: EventBus signal (`EventBus.level_up`)
- **Game State**: Pauses via [[RunManager-System]]
- **Display**: Modal overlays existing UI
- **Dismissal**: User selects card (presumably)

## Current Modal Behavior

### ✅ Working Correctly
- **Pause Integration**: Uses `RunManager.pause_game(true)`
- **Signal-Driven**: Responds to `EventBus.level_up`
- **Overlay Positioning**: Appears above HUD correctly

### ❌ Current Limitations
- **No Generic Modal System**: CardPicker is hardcoded
- **No Modal Stack**: Can't handle multiple overlays
- **No Background Dimming**: No visual focus indication
- **No Animation**: Instant show/hide (no transitions)
- **No Escape Handling**: No universal close mechanism

## Missing Modal Types (From Original Plan)

### Required Modals
1. **Pause Menu** - Game pause with options
2. **Options Menu** - Settings configuration  
3. **Loading Screen** - Scene transitions
4. **Error Dialogs** - System messages
5. **Confirmation Dialogs** - Yes/No prompts

## Proposed Modal Architecture

### Generic Modal System
```gdscript
# Proposed structure
class ModalManager extends Node:
    var modal_stack: Array[Control] = []
    var background_dimmer: ColorRect
    
    func show_modal(modal: Control, dim_background: bool = true):
        # Add to stack, pause game, show with animation
    
    func hide_modal():
        # Remove from stack, resume if empty, hide with animation
```

### Modal Categories

#### 1. Game Modals (Layer 2)
- **CardPicker** ✅ (currently implemented)
- **Pause Menu** ❌ (missing)
- **Inventory/Character Sheet** ❌ (future)

#### 2. System Modals (Layer 3)  
- **Loading Screen** ❌ (missing)
- **Error Dialogs** ❌ (missing)
- **Confirmation Prompts** ❌ (missing)

#### 3. Menu Modals (Layer 2)
- **Options Menu** ❌ (missing)
- **Controls Settings** ❌ (missing)
- **Audio Settings** ❌ (missing)

## Implementation Patterns

### Current Pattern (CardPicker)
```gdscript
# In Arena.gd
EventBus.level_up.connect(_on_level_up)

func _on_level_up(new_level: int) -> void:
    RunManager.pause_game(true)
    card_picker.open()
```

### Proposed Generic Pattern
```gdscript
# Via ModalManager
ModalManager.show_modal(card_picker_scene, {
    "pause_game": true,
    "dim_background": true,
    "close_on_escape": false
})
```

## Modal State Management

### Current State Issues
- No tracking of which modal is active
- No prevention of multiple modals
- No proper cleanup on scene change

### Proposed State Tracking
```gdscript
enum ModalState {
    NONE,           # No modal active
    CARD_PICKER,    # Level up card selection
    PAUSE_MENU,     # Game paused
    OPTIONS,        # Settings menu
    LOADING         # Scene transition
}
```

## Integration with Game Systems

### Pause System Integration
```gdscript
# Current: Direct RunManager call
RunManager.pause_game(true)

# Proposed: Automatic via ModalManager
ModalManager.show_modal(modal, {"auto_pause": true})
```

### Input Handling
- **Current**: Each modal handles own input
- **Proposed**: ModalManager intercepts input when modal active
- **Escape Key**: Universal modal dismiss (configurable)

## Animation and Polish

### Missing Visual Polish
- **Fade In/Out**: Smooth modal transitions
- **Background Dim**: Focus on modal content
- **Scale Animation**: Modern modal appearance
- **Sound Effects**: Audio feedback for open/close

### Implementation with Godot Tween
```gdscript
func show_modal_with_animation(modal: Control):
    modal.modulate.a = 0.0
    modal.scale = Vector2(0.8, 0.8)
    modal.show()
    
    var tween = create_tween()
    tween.parallel().tween_property(modal, "modulate:a", 1.0, 0.3)
    tween.parallel().tween_property(modal, "scale", Vector2.ONE, 0.3)
```

## Related Systems

- [[Canvas-Layer-Structure]]: Modal layering approach
- [[EventBus-System]]: Modal trigger communication
- [[RunManager-System]]: Game pause integration
- [[UI-Architecture-Overview]]: Overall modal placement in UI
- [[Scene-Management-System]]: Modal behavior across scenes