# Unified Overlay System Framework Guide

**System Status**: ✅ **PRODUCTION READY** - Complete implementation with comprehensive testing

> **Architecture Decision**: Replace scene-based modals with unified overlay system for seamless desktop UX. All modals now display over dimmed game background instead of jarring scene transitions.

## Table of Contents

1. [Quick Start Guide](#quick-start-guide)
2. [Framework Architecture](#framework-architecture)
3. [Creating New Modals](#creating-new-modals)
4. [Modal Configuration](#modal-configuration)
5. [Advanced Features](#advanced-features)
6. [Integration Patterns](#integration-patterns)
7. [Performance Guidelines](#performance-guidelines)
8. [Troubleshooting](#troubleshooting)

---

## Quick Start Guide

### Display a Modal

```gdscript
# Show any modal from anywhere in the codebase
UIManager.show_modal(UIManager.ModalType.RESULTS_SCREEN, {
    "run_result": result_data
})
```

### Close Current Modal

```gdscript
# From within a modal
close_modal()

# From external system
UIManager.hide_current_modal()
```

### Check Modal State

```gdscript
# Check if any modal is active
if UIManager.has_active_modal():
    Logger.info("Modal is currently displayed", "ui")
```

---

## Framework Architecture

### Core Components

```
UIManager (Autoload)
├── CanvasLayer Management (layers 5, 10, 50, 100)
├── ModalFactory (creates modal instances)
├── Animation System (entrance/exit transitions)
└── Background Dimmer (visual context)

BaseModal (Base Class)
├── Modal Lifecycle (open/close/pause behavior)
├── Keyboard Navigation (tab, escape, shortcuts)
├── Input Handling (prevents conflicts)
└── Theme Integration (consistent styling)

ModalAnimator (Performance System)
├── Tween Pooling (reusable animations)
├── Preset Animations (fade, scale, slide)
└── Performance Monitoring (frame rate awareness)
```

### Canvas Layer Strategy

| Layer | Purpose | Modal Types | Z-Order |
|-------|---------|-------------|---------|
| 5 | Game Modals | Inventory, Character, Skill Tree | Lowest |
| 10 | System Modals | Results, Settings, Pause Menu | Middle |
| 50 | Critical Alerts | Error dialogs, System messages | High |
| 100 | Debug Overlays | Console, Debug panels | Highest |

---

## Creating New Modals

### Step 1: Create Modal Scene

```gdscript
# MyModal.tscn structure
MyModal (Control) - extends BaseModal
├── Background (ColorRect) - optional, can be hidden
├── MainPanel (Panel) - primary content container
│   ├── VBoxContainer
│   │   ├── TitleLabel (Label)
│   │   ├── ContentArea (Control/Container)
│   │   └── ButtonContainer (HBoxContainer)
│   │       ├── PrimaryButton (Button)
│   │       └── SecondaryButton (Button)
```

### Step 2: Create Modal Script

```gdscript
# MyModal.gd
extends "res://scripts/ui_framework/BaseModal.gd"

## Description of what this modal does
## Usage context and integration notes

@onready var title_label: Label = $MainPanel/VBoxContainer/TitleLabel
@onready var primary_button: Button = $MainPanel/VBoxContainer/ButtonContainer/PrimaryButton

func _ready() -> void:
    # Configure modal properties
    modal_type = UIManager.ModalType.MY_MODAL
    dims_background = true              # Use UIManager dimming
    pauses_game = false                # Set based on modal purpose
    closeable_with_escape = true       # Allow ESC to close
    keyboard_navigable = true          # Enable tab navigation
    default_focus_control = primary_button
    
    # Set modal size for auto-centering
    modal_size = Vector2(600, 400)
    auto_center = true
    
    super._ready()  # Initialize BaseModal
    
    _setup_ui_elements()
    _connect_signals()

func _initialize_modal_content(data: Dictionary) -> void:
    """Initialize modal with provided data"""
    # Process data passed from UIManager.show_modal()
    var title = data.get("title", "Default Title")
    title_label.text = title
    
    # Call deferred if you need @onready nodes
    call_deferred("_setup_with_data", data)

func _setup_ui_elements() -> void:
    """Configure UI elements and styling"""
    # Apply modal theme
    apply_modal_theme()
    
    # Configure buttons
    primary_button.text = "Confirm"
    primary_button.focus_mode = Control.FOCUS_ALL

func _connect_signals() -> void:
    """Connect button and system signals"""
    primary_button.pressed.connect(_on_primary_pressed)

func _on_primary_pressed() -> void:
    """Handle primary action"""
    Logger.info("Primary action confirmed", "ui")
    
    # Close modal first
    close_modal()
    
    # Perform action (state transition, etc.)
    # StateManager.do_something()
```

### Step 3: Register Modal Type

```gdscript
# In UIManager.gd - Add to ModalType enum
enum ModalType {
    # Existing types...
    MY_MODAL,        # Add your new modal
}

# In ModalFactory - Add to modal_scenes dictionary
var modal_scenes: Dictionary = {
    # Existing mappings...
    UIManager.ModalType.MY_MODAL: preload("res://scenes/ui/MyModal.tscn"),
}
```

---

## Modal Configuration

### Essential Properties

```gdscript
# In _ready() function of your modal

# Modal type (required for UIManager coordination)
modal_type = UIManager.ModalType.YOUR_MODAL

# Background behavior
dims_background = true          # Use UIManager dimming (recommended)
# dims_background = false       # Handle your own background

# Game pause behavior  
pauses_game = true             # Pause game while modal is open
# pauses_game = false          # Keep game running (for non-blocking UI)

# Input behavior
closeable_with_escape = true   # Allow ESC to close modal
keyboard_navigable = true      # Enable tab navigation between controls

# Focus management
default_focus_control = some_button  # Control to focus when opened

# Size and positioning
modal_size = Vector2(600, 500)  # Size for auto-centering
auto_center = true              # Automatically center content
```

### Modal Categories Guide

**System Modals** (pause game):
- Results screens, death screens
- Settings menus, pause menus  
- Critical confirmation dialogs

**Game Modals** (don't pause):
- Inventory, character screens
- Skill trees, crafting menus
- Non-critical information displays

---

## Advanced Features

### Custom Animations

```gdscript
# Override animation behavior in your modal
func _on_modal_opened(context: Dictionary) -> void:
    # Custom entrance animation
    var tween = create_tween()
    tween.tween_property(main_panel, "position:x", 0, 0.3)

func _on_modal_closing() -> void:
    # Custom exit animation before close
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    await tween.finished
```

### Keyboard Shortcuts

```gdscript
func setup_keyboard_shortcuts() -> void:
    """Override to add modal-specific shortcuts"""
    # This is called automatically by BaseModal
    
func _input(event: InputEvent) -> void:
    if not is_modal_open:
        return
        
    # Add custom keyboard handling
    if event.is_action_pressed("inventory_quick_sort"):
        _perform_quick_sort()
        get_viewport().set_input_as_handled()
    
    # Call super for default tab navigation
    super._input(event)
```

### Conditional Close Prevention

```gdscript
func _can_close_modal() -> bool:
    """Override to prevent closure under certain conditions"""
    if _has_unsaved_changes():
        _show_unsaved_warning()
        return false
    return true
```

### Tooltip Integration

```gdscript
func _setup_ui_elements() -> void:
    # Enable tooltip support
    has_tooltips = true
    
func _on_button_mouse_entered() -> void:
    request_tooltip("This button does X", get_global_mouse_position())

func _on_button_mouse_exited() -> void:
    hide_tooltip()
```

---

## Integration Patterns

### State Manager Integration

```gdscript
# Trigger state transitions from modals
func _on_confirm_pressed() -> void:
    close_modal()  # Always close first
    
    # Then perform state transition
    StateManager.start_run(StringName("arena"), {
        "source": "modal_confirmation",
        "preserve_progression": false
    })
```

### Event Bus Communication

```gdscript
# Listen to game events
func _ready() -> void:
    super._ready()
    EventBus.player_level_changed.connect(_on_player_level_changed)

func _on_player_level_changed(new_level: int) -> void:
    # Update modal content dynamically
    level_label.text = "Level: %d" % new_level
```

### Data Passing Patterns

```gdscript
# From caller
UIManager.show_modal(UIManager.ModalType.INVENTORY, {
    "player_items": player_inventory,
    "max_slots": 40,
    "highlight_item": "sword_123"
})

# In modal
func _initialize_modal_content(data: Dictionary) -> void:
    var items = data.get("player_items", [])
    var highlight = data.get("highlight_item", "")
    
    _populate_inventory(items)
    if not highlight.is_empty():
        _highlight_item(highlight)
```

---

## Performance Guidelines

### Memory Management

```gdscript
# Modal instances are automatically cleaned up by UIManager
# But clean up any additional resources in _on_modal_closing()

func _on_modal_closing() -> void:
    # Clean up any temporary resources
    if temporary_texture:
        temporary_texture.queue_free()
    
    # Disconnect any external signals
    if external_object and external_object.some_signal.is_connected(_handler):
        external_object.some_signal.disconnect(_handler)
```

### Large Content Optimization

```gdscript
# For modals with lots of content (inventories, skill trees)
func _initialize_modal_content(data: Dictionary) -> void:
    # Defer heavy content population
    call_deferred("_populate_large_content", data)

func _populate_large_content(data: Dictionary) -> void:
    # Populate content over multiple frames
    var items = data.get("items", [])
    var batch_size = 10
    
    for i in range(0, items.size(), batch_size):
        var batch = items.slice(i, i + batch_size)
        _add_items_to_ui(batch)
        await get_tree().process_frame  # Yield between batches
```

### Animation Performance

```gdscript
# Use the built-in ModalAnimator for optimal performance
# Avoid creating many tweens simultaneously

func animate_list_items() -> void:
    # Good: Stagger animations
    for i in range(item_nodes.size()):
        var delay = i * 0.05
        get_tree().create_timer(delay).timeout.connect(func():
            ModalAnimator.fade_in(item_nodes[i], 0.2)
        )
```

---

## Troubleshooting

### Common Issues

**Modal Not Visible**:
```gdscript
# Check these common issues:
1. Ensure modal scene extends BaseModal
2. Verify modal_type is set correctly
3. Check if modal_size and auto_center are configured
4. Ensure popup content is visible (not hidden by your code)
5. Check canvas layer assignment in get_modal_layer()
```

**Buttons Not Working**:
```gdscript
# Usually a process mode issue:
1. Ensure BaseModal sets PROCESS_MODE_WHEN_PAUSED if modal pauses game
2. Check button focus_mode is set to FOCUS_ALL
3. Verify button signals are connected correctly
4. Make sure buttons are not disabled
```

**ESC Key Conflicts**:
```gdscript
# Input priority issues:
1. UIManager has higher priority (100) than GameOrchestrator
2. BaseModal no longer handles ESC directly
3. Ensure closeable_with_escape is set correctly
```

**Animation Issues**:
```gdscript
# Animation not running:
1. Check if modal.visible = true before animation
2. Ensure tween is not being overridden
3. Verify modulate.a starts at correct value (0.1 for debug)
```

### Debug Logging

```gdscript
# Enable comprehensive modal debugging
Logger.set_level("DEBUG")

# Key debug signals to monitor:
SessionManager.session_reset_started.connect(_debug_reset)
UIManager.modal_displayed.connect(_debug_modal_shown)
UIManager.modal_hidden.connect(_debug_modal_hidden)
```

### Validation Checklist

Before deploying a new modal:

- [ ] Extends BaseModal with proper configuration
- [ ] Registered in ModalType enum and ModalFactory
- [ ] Handles _initialize_modal_content() correctly  
- [ ] Calls close_modal() before state transitions
- [ ] Follows keyboard navigation patterns
- [ ] Tested with different data scenarios
- [ ] Verified performance with large content
- [ ] ESC key behavior works as expected
- [ ] Integrates properly with StateManager

---

## Examples Reference

**Study These Production Examples**:
- `ResultsScreen.gd` - Complete modal with session integration
- `BaseModal.gd` - Framework implementation patterns
- `UIManager.gd` - Modal coordination and lifecycle

**Test Your Modal**:
```gdscript
# Quick test snippet
func _test_my_modal():
    UIManager.show_modal(UIManager.ModalType.MY_MODAL, {
        "test_data": "Hello World",
        "debug_mode": true
    })
```

The Unified Overlay System provides a robust, extensible foundation for all modal UI needs while maintaining desktop-class UX standards.