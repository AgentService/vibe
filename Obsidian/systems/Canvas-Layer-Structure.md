# Canvas Layer Structure

## Current Implementation

### Arena UI Setup
```gdscript
# From Arena.gd lines 214-223
func _setup_ui() -> void:
    var ui_layer: CanvasLayer = CanvasLayer.new()
    ui_layer.name = "UILayer"
    add_child(ui_layer)
    
    hud = HUD_SCENE.instantiate()
    ui_layer.add_child(hud)
    
    card_picker = CARD_PICKER_SCENE.instantiate()
    ui_layer.add_child(card_picker)
```

### Current Layer Structure
```
UILayer (CanvasLayer - layer 0)
├── HUD.tscn (Always visible game UI)
│   ├── VBoxContainer (Level + XP)
│   └── EnemyRadar (Top-right panel)
└── CardPicker.tscn (Modal overlay)
```

## Layer Priorities Analysis

### ✅ What Works
- **Basic Separation**: UI exists in separate CanvasLayer
- **Modal Functionality**: CardPicker can overlay the HUD
- **Event Integration**: HUD responds to [[EventBus-System]] signals

### ❌ Current Limitations
- **Single Layer**: Everything on same CanvasLayer (layer 0)
- **No Priority Management**: No z-ordering control
- **No UI State**: No central visibility management
- **Fixed Layout**: No responsive positioning

## Proposed Layer Architecture

### From Original Plan
```
UIManager (CanvasLayer structure)
├── Layer 0: GameHUD (health, abilities, always visible)
├── Layer 1: GameOverlays (tooltips, damage numbers)
├── Layer 2: MenuOverlays (pause menu, card picker)
└── Layer 3: SystemOverlays (loading, transitions)
```

### Layer Priorities
- **Layer 0 (Background UI)**: Game HUD, minimap, health bars
- **Layer 1 (Interactive UI)**: Tooltips, contextual menus
- **Layer 2 (Modal UI)**: Pause menu, card selection, options
- **Layer 3 (System UI)**: Loading screens, transitions, error dialogs

## Current Components Detail

### HUD Component (Layer 0 equivalent)
**File**: `vibe/scenes/ui/HUD.tscn`
**Script**: `vibe/scenes/ui/HUD.gd` (31 lines)

**Structure**:
```
HUD (Control - fullscreen)
├── VBoxContainer (bottom-left)
│   ├── LevelLabel ("Level: 1")
│   └── XPBar (ProgressBar)
└── EnemyRadar (top-right panel)
```

**Responsibilities**:
- Listen to `EventBus.xp_changed` and `EventBus.level_up`
- Update level and XP display
- Contains [[EnemyRadar-Component]]

### CardPicker Component (Layer 2 equivalent)  
**File**: `vibe/scenes/ui/CardPicker.tscn`
**Modal Behavior**: Pauses game via `RunManager.pause_game(true)`

## Implementation Requirements

### For Proper Layer Management
```gdscript
# Proposed UIManager structure
class UIManager extends Node:
    var layers: Dictionary = {
        "hud": CanvasLayer.new(),        # layer = 0
        "overlays": CanvasLayer.new(),   # layer = 1
        "modals": CanvasLayer.new(),     # layer = 2
        "system": CanvasLayer.new()      # layer = 3
    }
```

### Benefits of Multi-Layer Approach
- **Z-Order Control**: Proper element stacking
- **Performance**: Only update visible layers
- **Modularity**: Independent layer management
- **Scalability**: Easy to add new UI types

## Screen Size Considerations

### Current Issues
- **Fixed Positioning**: Hard-coded offsets in HUD
- **No Scaling**: UI doesn't adapt to different resolutions
- **No Safe Areas**: No consideration for mobile/varied aspect ratios

### Proposed Solutions
- Use `anchors_preset` properly for responsive positioning
- Implement [[UI-Scaling-System]] for different screen sizes
- Add safe area margins for mobile compatibility

## Related Systems

- [[UI-Architecture-Overview]]: Overall UI structure
- [[Modal-Overlay-System]]: How modals like CardPicker work
- [[EventBus-System]]: UI communication patterns
- [[EnemyRadar-Component]]: Specific UI component example