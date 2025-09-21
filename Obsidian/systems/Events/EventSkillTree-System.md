# EventSkillTree System Documentation

## Overview

The EventSkillTree system provides a single-level binary allocation skill tree for different event types (breach, ritual, pack_hunt, boss). It features visual node connections, prerequisite validation, reset functionality, and persistent storage through the EventMasterySystem.

## System Architecture

### Core Components

1. **BreachSkillTree.gd** - Main controller for skill tree logic (updated from EventSkillTree.gd)
2. **SkillNode (skill_button.gd)** - Individual skill button with scene-based tooltips
3. **AtlasTreeUI.gd** - Tabbed interface wrapper
4. **EventMasterySystem.gd** - Backend storage and validation

### Data Flow

```
User Click → EventSkillTree → EventMasterySystem → Save/Load
     ↑            ↓               ↓
SkillNode ← Visual Update ← Passive Definitions
```

## EventSkillTree.gd

### Key Features

- **Single-Level Allocation**: Binary 0/1 allocation (allocated/not allocated)
- **Prerequisite Validation**: Parent nodes must be allocated before children
- **Reset Mode**: Special mode for deallocation with dependency checking
- **Visual Feedback**: Line connections and border highlighting
- **Persistence**: Automatic save/load through EventMasterySystem

### Core Functions

```gdscript
# Main allocation handler
func _on_skill_node_clicked(passive_id: StringName, node) -> void

# Prerequisite checking
func _can_allocate_with_prerequisites(passive_id: StringName) -> bool
func _can_deallocate_with_prerequisites(passive_id: StringName) -> bool

# UI management
func _refresh_all_nodes() -> void
func set_reset_mode(active: bool) -> void
```

### Signal Flow

```gdscript
# Emitted signals
signal passive_allocated(passive_id: StringName)
signal passive_deallocated(passive_id: StringName)

# Consumed from EventBus
EventBus.mastery_points_earned.connect(_on_mastery_points_earned)
```

## SkillNode Component

### Visual States

- **Default**: Purple border (460044), no checkmark
- **Allocated**: Bright purple border, checkmark (✓)
- **Reset Removable**: Dark red border
- **Reset Blocked**: Standard purple border
- **Line Connections**: Bright purple when active, medium purple when available, dark purple when disabled

### Scene-Based Tooltip System

Each SkillNode now includes built-in tooltips with:
- **TooltipPanel**: Auto-sizing with 300px fixed width, variable height
- **RichTextLabel**: BBCode support for rich text formatting
- **MarginContainer**: 8px margins for professional spacing
- **Auto-content**: Displays skill name and description from EventMasterySystem

### Passive Type Mapping

Uses enum system for type-safe passive ID mapping:

```gdscript
enum PassiveType {
    NONE,
    # Support Tree
    SUPPORT_A_STABILIZATION,    # maps to "breach_stabilization"
    SUPPORT_B_FORTIFICATION,    # maps to "breach_fortification"
    # ... etc
}
```

### Key Features

- **Single-Level Logic**: Level clamped to 0 or 1
- **Line Connections**: Dynamic positioning with margin calculations
- **Border Highlighting**: Purple theme with state-based colors
- **Toggle Behavior**: Click to allocate/deallocate (outside reset mode)
- **Integrated Tooltips**: Scene-based tooltips with automatic content from passive definitions

## AtlasTreeUI Integration

### Tab Management

```gdscript
var tab_names = ["breach", "ritual", "pack_hunt", "boss"]
```

- **Active Tab**: Controls which event tree is displayed
- **Points Display**: Shows available/allocated points for current event type
- **Reset Controls**: Global reset and selective reset modes

### UI Flow

1. User opens Atlas Tree (E key near MasteryDevice)
2. Selects event type tab
3. Clicks skill nodes to allocate/deallocate
4. Uses reset mode for removing allocated skills
5. Changes persist automatically

## EventMasterySystem Integration

### Passive Definitions

Single-level format:
```gdscript
"breach_stabilization": {
    "name": "Breach Stabilization",
    "description": "Breaches open and close 75% slower",
    "max_level": 1,
    "cost": 1,
    "event_type": "breach",
    "modifiers": {"breach_open_time": 1.75}
}
```

### Allocation Logic

- **Points System**: Each event type has separate point pools
- **Cost Validation**: Checks available points before allocation
- **Dependency Validation**: Ensures prerequisite chains are maintained
- **Persistence**: Automatic save to profile system

## Visual Design

### Purple Breach Theme

```gdscript
# Border Colors
const BORDER_DEFAULT = Color(0.275, 0.0, 0.267, 1.0)      # 460044
const BORDER_ALLOCATED = Color(0.5, 0.15, 0.48, 1.0)      # Bright purple
const BORDER_REMOVABLE = Color(0.18, 0.0, 0.17, 1.0)      # Dark purple
const BORDER_BLOCKED = Color(0.5, 0.05, 0.15, 1.0)        # Red-purple
```

### Line Connections

- **Active**: Bright yellow (both nodes allocated)
- **Available**: Gray (parent allocated, child not)
- **Disabled**: Dark gray (parent not allocated)
- **Dynamic Positioning**: Maintains minimum line length with margin calculations

## Technical Implementation

### Node Discovery

```gdscript
# Automatic mapping via passive_type export property
for node in _find_skill_nodes_recursive(self):
    if node.passive_id != "":
        _skill_nodes[node.passive_id] = node
```

### Prerequisite Chain Validation

```gdscript
# Recursive subtree checking for deallocation
func _is_subtree_empty(passive_id: StringName) -> bool:
    var children = _get_node_children(passive_id)
    for child_id in children:
        if _mastery_system.get_passive_level(child_id) > 0:
            return false
    return true
```

### Reset Mode Logic

- **Entry**: Highlights removable (green) and blocked (red) nodes
- **Deallocation Only**: Prevents allocation, only allows removal
- **Dependency Aware**: Cannot remove if children are allocated
- **Visual Feedback**: Clear color-coded borders for user guidance

## Performance Considerations

- **Deferred Line Updates**: Line connections updated after position changes
- **Signal Batching**: UI refreshes triggered by allocation events
- **Scene Tree Optimization**: Minimal node traversal for updates
- **Memory Efficient**: No intermediate state storage, direct EventMasterySystem updates

## Error Handling

- **Graceful Degradation**: Unmapped nodes work in visual-only mode
- **Validation Layers**: Multiple checks prevent invalid allocations
- **Logging Integration**: Comprehensive debug output via Logger system
- **Recovery**: System handles missing EventMasterySystem gracefully

---

*This system provides a robust, user-friendly skill progression interface with clear visual feedback and reliable data persistence.*