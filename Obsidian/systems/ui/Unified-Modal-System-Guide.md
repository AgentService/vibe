# Unified Modal System Guide

**System**: Unified Overlay System V1 | **Status**: ✅ Production Ready | **Framework**: Desktop-Optimized Modal System

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Architecture Overview](#architecture-overview)
3. [Implementation Guide](#implementation-guide)
4. [Migration from Legacy](#migration-from-legacy)
5. [Performance & Optimization](#performance--optimization)
6. [Troubleshooting](#troubleshooting)

---

## Quick Reference

### Core API Usage

```gdscript
# Show modal
UIManager.show_modal(UIManager.ModalType.RESULTS_SCREEN, data_dict)

# Check modal state
UIManager.has_active_modal()
UIManager.get_modal_count()

# Close current modal
UIManager.hide_current_modal()
```

### Creating New Modal Template

```gdscript
extends "res://scripts/ui_framework/BaseModal.gd"

func _ready() -> void:
    modal_type = UIManager.ModalType.MY_MODAL
    dims_background = true
    pauses_game = false  # or true for system modals
    closeable_with_escape = true
    keyboard_navigable = true
    default_focus_control = some_button
    modal_size = Vector2(600, 400)
    auto_center = true
    super._ready()

func _initialize_modal_content(data: Dictionary) -> void:
    # Handle data passed from show_modal()
    pass
```

### Modal Registration

```gdscript
# 1. Add to UIManager.ModalType enum
MY_MODAL,

# 2. Add to ModalFactory.modal_scenes
UIManager.ModalType.MY_MODAL: preload("res://path/to/MyModal.tscn"),
```

### Button Handler Pattern

```gdscript
func _on_button_pressed() -> void:
    close_modal()  # Always close first
    StateManager.do_something()  # Then perform action
```

---

## Architecture Overview

### Design Principles

The Unified Overlay System replaces scene-based modal implementations with a coordinated overlay framework that maintains visual context while providing desktop-class modal functionality.

1. **Visual Continuity**: Modals display over dimmed game background instead of jarring scene transitions
2. **Desktop UX Standards**: Keyboard navigation, focus management, ESC handling, tooltips
3. **Performance Optimization**: Canvas layer management, animation pooling, memory efficiency
4. **Extensibility**: Factory pattern and base class framework for easy modal addition
5. **Integration**: Seamless StateManager and EventBus coordination

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    UIManager (Autoload)                 │
├─────────────────────────────────────────────────────────┤
│ • Modal Coordinator & Factory                           │
│ • Canvas Layer Management (5,10,50,100)               │
│ • Background Dimming                                    │
│ • Input Priority Control                                │
│ • Animation Orchestration                               │
└─────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────┐
│                 BaseModal Framework                     │
├─────────────────────────────────────────────────────────┤
│ • Lifecycle Management (open/close/pause)              │
│ • Keyboard Navigation (tab, escape, shortcuts)         │
│ • Process Mode Coordination (pause behavior)           │
│ • Theme Integration                                     │
│ • Focus Management                                      │
└─────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────┐
│              Individual Modal Implementations            │
├─────────────────────────────────────────────────────────┤
│ • ResultsScreen, Inventory, Settings, etc.             │
│ • Modal-specific behavior and content                   │
│ • StateManager integration                              │
│ • Data handling and validation                          │
└─────────────────────────────────────────────────────────┘
```

### Component Architecture

#### UIManager (Autoload Coordinator)

**Responsibilities**:
- Modal lifecycle coordination (show/hide/stack management)
- Canvas layer organization and z-ordering
- Factory pattern modal instantiation
- Background dimming and visual effects
- Input priority management (ESC handling)
- Animation orchestration and performance monitoring

**Key API**:
```gdscript
UIManager.show_modal(modal_type: ModalType, data: Dictionary) -> BaseModal
UIManager.hide_current_modal() -> void
UIManager.has_active_modal() -> bool
UIManager.get_modal_count() -> int
```

#### BaseModal (Framework Base Class)

**Responsibilities**:
- Modal lifecycle events and state management
- Keyboard navigation and accessibility
- Process mode management for pause coordination
- Theme application and visual consistency
- Focus management and tab ordering
- Input handling and conflict prevention

**Override Points**:
```gdscript
func _initialize_modal_content(data: Dictionary) -> void
func _on_modal_opened(context: Dictionary) -> void
func _on_modal_closing() -> void
func _can_close_modal() -> bool
```

#### Modal Categories & Layer Assignment

| Layer | Purpose | Modal Types | Z-Order | Pause Behavior |
|-------|---------|-------------|---------|----------------|
| **5** | Game Modals | Inventory, Character, Skill Tree, Crafting | Lowest | Non-blocking |
| **10** | System Modals | Results, Settings, Pause Menu | Middle | Blocking |
| **50** | Critical Alerts | Error dialogs, System warnings | High | Blocking |
| **100** | Debug Overlays | Console, Debug panels, Performance | Highest | Non-blocking |

---

## Implementation Guide

### Creating Your First Modal

#### Step 1: Create Modal Scene
1. Create new scene with Control root node
2. Add your UI elements (Panel, buttons, labels, etc.)
3. Save as `.tscn` file in `scenes/ui/modals/` directory

#### Step 2: Create Modal Script
```gdscript
extends "res://scripts/ui_framework/BaseModal.gd"

@onready var my_button: Button = $Panel/MyButton
@onready var my_label: Label = $Panel/MyLabel

func _ready() -> void:
    # Configure modal properties
    modal_type = UIManager.ModalType.MY_MODAL
    dims_background = true
    pauses_game = false
    closeable_with_escape = true
    keyboard_navigable = true
    default_focus_control = my_button
    modal_size = Vector2(500, 300)
    auto_center = true
    
    super._ready()
    
    # Connect button signals
    my_button.pressed.connect(_on_my_button_pressed)

func _initialize_modal_content(data: Dictionary) -> void:
    # Handle initialization data
    if data.has("title"):
        my_label.text = data.title

func _on_my_button_pressed() -> void:
    # Always close modal first, then perform action
    close_modal()
    # Perform your action here
```

#### Step 3: Register Modal
1. Add to `UIManager.ModalType` enum:
```gdscript
enum ModalType {
    # ... existing types ...
    MY_MODAL,
}
```

2. Add to `ModalFactory.modal_scenes`:
```gdscript
var modal_scenes: Dictionary = {
    # ... existing entries ...
    UIManager.ModalType.MY_MODAL: preload("res://scenes/ui/modals/MyModal.tscn"),
}
```

#### Step 4: Display Modal
```gdscript
# From anywhere in your code
UIManager.show_modal(UIManager.ModalType.MY_MODAL, {
    "title": "My Custom Modal"
})
```

### Essential Properties

```gdscript
modal_type          # Required: UIManager.ModalType enum
dims_background     # true = use UIManager dimming
pauses_game         # true = pause game while open
closeable_with_escape  # true = ESC closes modal
keyboard_navigable  # true = enable tab navigation
default_focus_control  # Control to focus on open
modal_size          # Vector2 for auto-centering
auto_center         # true = automatically center content
```

### Animation System

The ModalAnimator provides standardized animations with performance optimization:

```gdscript
# Basic animations
ModalAnimator.fade_in_modal(modal)
ModalAnimator.scale_in_modal(modal)
ModalAnimator.slide_in_modal(modal, Vector2(0, -200))
ModalAnimator.bounce_in_modal(modal)

# Exit animations
ModalAnimator.fade_out_modal(modal)
ModalAnimator.scale_out_modal(modal)

# Button animations
ModalAnimator.animate_button_hover(button)
ModalAnimator.animate_button_press(button)
```

### Theme System

The ModalTheme provides consistent styling:

```gdscript
# Apply theme to modal
var theme = preload("res://themes/modal_theme.tres")
modal.apply_modal_theme(theme)

# Create themed components
var button = ModalTheme.create_themed_button()
var panel = ModalTheme.create_themed_panel()
var label = ModalTheme.create_themed_label("Text", 18)
```

---

## Migration from Legacy

### Converting Scene-Based Modals

**Before (Scene-based ResultsScreen)**:
```gdscript
# OLD: Full scene transition
Player death → StateManager.end_run(result) → SceneTransitionManager → ResultsScreen.tscn
```

**After (Modal-based ResultsScreen)**:
```gdscript
# NEW: Modal overlay
Player death → UIManager.show_modal(ModalType.RESULTS_SCREEN, death_result)
# ResultsScreen appears as overlay over dimmed Arena background
```

### Legacy Cleanup Tasks

#### Remove Scene Transition Logic
```gdscript
# In SceneTransitionManager._resolve_map_path() - Remove:
"results": return "res://scenes/ui/ResultsScreen.tscn"  # ← Remove this
```

#### Update Death Handling
```gdscript
# In Player.gd _handle_death_sequence()
# OLD:
StateManager.end_run(death_result)

# NEW:
UIManager.show_modal(UIManager.ModalType.RESULTS_SCREEN, death_result)
```

#### Replace Hardcoded Styling
```gdscript
# FIND & REPLACE patterns:
add_theme_color_override("panel", Color(0.2, 0.2, 0.2, 0.95))
add_theme_font_size_override("font_size", 32)

# REPLACE WITH:
apply_modal_theme()
```

---

## Performance & Optimization

### Memory Management

The modal system includes several optimization strategies:

1. **Scene Preloading**: Modal scenes preloaded in ModalFactory for instant access
2. **Animation Pooling**: Tween objects reused across modal transitions
3. **Automatic Cleanup**: BaseModal ensures signal disconnections and resource cleanup
4. **Canvas Layer Isolation**: Prevents unnecessary redraws of game content

### Performance Monitoring

```gdscript
# Get performance statistics
var stats = ModalAnimator.get_performance_stats()
print("Active animations: ", stats.active_animations)
print("Pooled tweens: ", stats.pooled_tweens)

# Monitor modal lifecycle
Logger.debug("Modal opened: %s (%.2fms)" % [modal_type, duration], "ui")
```

### Desktop Performance Budget

- **Target Hardware**: GTX 1060 / RX 580 equivalent or better
- **Frame Budget**: 16.67ms (60 FPS) with 5ms UI allowance 
- **Animation Budget**: 20+ simultaneous overlay animations
- **Memory Budget**: 100MB+ for UI textures and components
- **Loading Budget**: <200ms overlay open time (SSD assumed)

---

## Troubleshooting

### Common Issues

**Modal not visible?**
- Check BaseModal inheritance
- Verify modal_type is set
- Ensure auto_center + modal_size configured
- Check canvas layer assignment

**Buttons not working?**
- Check process_mode (BaseModal handles this automatically)
- Verify focus_mode = FOCUS_ALL
- Ensure buttons not disabled
- Check signal connections

**ESC conflicts?**
- UIManager has input priority (100)
- BaseModal handles ESC automatically via UIManager
- Check closeable_with_escape setting
- Verify no input conflicts with GameOrchestrator

**Animation issues?**
- Check ModalAnimator tween pool status
- Verify modal visibility before animating
- Monitor performance stats for overload
- Ensure proper cleanup on modal close

### Debug Information

```gdscript
# Get modal information
var info = modal.get_modal_info()
print("Modal debug: ", info)

# Validate modal setup
if not modal.validate_modal_setup():
    print("Modal configuration issues found")

# Check theme validation
var theme = preload("res://themes/modal_theme.tres")
if not theme.validate_theme():
    print("Theme validation failed")
```

### State Management Integration

The modal system coordinates with multiple state-aware systems:

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ BaseModal    │    │ PauseManager │    │ GameOrchest. │
│ (owns pause) │◄──►│ (game state) │◄──►│ (ESC input)  │
└──────────────┘    └──────────────┘    └──────────────┘
                            │
                    ┌──────────────┐
                    │   PauseUI    │
                    │ (visual UI)  │
                    └──────────────┘
```

**Pause Ownership Model**:
- Modal sets `modal_owns_pause = true` when pausing
- `_process()` re-asserts pause if external systems interfere
- Unpause only occurs when modal closes (if modal owns pause)
- Input priority prevents ESC conflicts between systems

---

## Production Examples

### ResultsScreen Implementation
The ResultsScreen serves as the reference implementation showing:
- Complete BaseModal inheritance
- StateManager integration for scene transitions
- Theme application and consistent styling
- Proper button handling patterns
- Session management coordination

### File Structure

```
scripts/ui_framework/
├── BaseModal.gd          # Framework base class
├── ModalAnimator.gd      # Animation utilities  
└── ModalTheme.gd         # Theming system

autoload/
└── UIManager.gd          # Modal coordinator

scenes/ui/
├── ResultsScreen.tscn    # Reference modal implementation
└── modals/               # Future modal implementations

themes/
└── modal_theme.tres      # Default modal styling
```

---

## Common Patterns

### State Transition
```gdscript
func _on_confirm() -> void:
    close_modal()
    StateManager.start_run(arena_id, {"source": "modal"})
```

### Data Validation
```gdscript
func _can_close_modal() -> bool:
    if has_unsaved_changes:
        show_warning()
        return false
    return true
```

### Dynamic Updates
```gdscript
func _ready() -> void:
    super._ready()
    EventBus.player_level_changed.connect(_update_display)
```

### Keyboard Shortcuts
```gdscript
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("quick_inventory"):
        UIManager.show_modal(UIManager.ModalType.INVENTORY)
        get_viewport().set_input_as_handled()
```

---

## Future Enhancements

**Planned Features**:
- Modal stacking (multiple modals open simultaneously)
- Advanced animation presets and transitions
- Accessibility improvements (screen reader support)
- Theme system expansion with multiple visual styles
- Performance optimization for mobile platforms

**Extension Points**:
- Custom modal base classes for specialized behavior
- Plugin system for third-party modal implementations
- Advanced input handling for gamepad/touch support
- Internationalization integration for multi-language support

The Unified Overlay System provides a robust, scalable foundation for all modal UI needs while maintaining high performance and excellent user experience standards optimized for desktop gaming.