# EventSkillTree UI Components Documentation

## Component Architecture

The EventSkillTree UI is built with a modular component system that provides clear separation of concerns and reusable visual elements.

## Core UI Components

### 1. AtlasTreeUI (scenes/ui/atlas/AtlasTreeUI.tscn)
*Main container and navigation interface*

**Purpose**: Tabbed interface wrapper that manages multiple event type skill trees

**Key Elements**:
- `TabContainer` - Handles event type switching
- `PointsPanel` - Shows available/allocated points and controls
- Background ColorRect with breach theme

**Responsibilities**:
- Event type tab management
- Global reset functionality
- Points display coordination
- UI visibility control (ESC to close)

**Signals**:
```gdscript
signal atlas_closed()  # Emitted when UI is hidden
```

### 2. EventSkillTree (scenes/ui/skill_tree/EventSkillTree.tscn)
*Event-specific skill tree container*

**Purpose**: Manages layout and logic for a single event type's skill progression

**Key Properties**:
- `event_type: StringName` - Defines which event this tree represents
- Auto-discovery of child SkillNode components
- Dynamic passive mapping via node hierarchy

**Core Systems**:
- **Node Discovery**: Recursively finds all SkillNode children
- **Prerequisite Validation**: Enforces parent-child allocation rules
- **Reset Mode**: Special interaction mode for deallocation
- **Visual Refresh**: Coordinates line connections and borders

### 3. SkillNode (scenes/ui/skill_tree/skill_button.tscn)
*Individual skill button component*

**Purpose**: Interactive skill point that represents a single passive ability

**Visual Elements**:
```
SkillButton (TextureButton)
├── BorderHighlight (ColorRect) - z_index: -1
├── Panel (Panel) - Hidden background
├── MarginContainer
│   └── Label - Shows checkmark (✓) when allocated
└── Line2D - Connection to parent node
```

**Key Features**:
- **Single-Level Logic**: Binary allocation (0 or 1)
- **Purple Border Theme**: Color-coded state feedback
- **Dynamic Line Connections**: Visual parent-child relationships
- **Reset Mode Integration**: Special highlighting for deallocation

## Visual Design System

### Border Color Scheme (Purple Breach Theme)

```gdscript
BORDER_DEFAULT = Color(0.275, 0.0, 0.267, 1.0)    # 460044 - Base state
BORDER_ALLOCATED = Color(0.5, 0.15, 0.48, 1.0)    # Bright purple - Allocated
BORDER_REMOVABLE = Color(0.18, 0.0, 0.17, 1.0)    # Dark purple - Can remove
BORDER_BLOCKED = Color(0.5, 0.05, 0.15, 1.0)      # Red-purple - Cannot remove
BORDER_AVAILABLE = Color(0.4, 0.1, 0.39, 1.0)     # Medium purple - Available
```

### Line Connection System

**Colors**:
- **Active** (Yellow): Both parent and child are allocated
- **Available** (Gray): Parent allocated, child not allocated
- **Disabled** (Dark Gray): Parent not allocated

**Positioning**:
- Dynamic margin calculation ensures minimum visible line length
- Lines connect node centers with configurable margin offset
- Automatic positioning updates when nodes move

### Typography & Labels

- **Allocated Skills**: Checkmark symbol (✓)
- **Unallocated Skills**: Empty label
- **Font**: Inherits from theme with outline for readability
- **Alignment**: Bottom-right corner of skill node

## Interaction Patterns

### Normal Mode Interactions

1. **Click Unallocated Node**:
   - Validates prerequisites (parent allocated)
   - Checks available points
   - Allocates if valid, shows message if invalid

2. **Click Allocated Node**:
   - Validates no child dependencies
   - Deallocates if safe, shows warning if blocked

3. **Visual Feedback**:
   - Border changes to allocated color
   - Checkmark appears
   - Line connections update colors
   - Child nodes become available

### Reset Mode Interactions

**Activation**: Click "Reset Skillpoints" button

**Visual Changes**:
- All nodes show color-coded borders:
  - **Dark Purple**: Removable (no child dependencies)
  - **Red-Purple**: Blocked (has child dependencies)
  - **Default Purple**: No points allocated

**Interactions**:
- **Click Removable Node**: Immediately deallocates
- **Click Blocked Node**: Shows warning message
- **Allocation Disabled**: Cannot add points in reset mode

**Exit**: Click "Exit Reset Mode" or perform any allocation

### Prerequisite Validation UI

**Visual Indicators**:
- Disabled state grays out unavailable nodes
- Line connections show availability chain
- Border colors indicate interaction possibility

**User Feedback**:
- Logger messages explain why actions are blocked
- Clear visual hierarchy shows required progression path

## Layout & Positioning

### Responsive Design

**Anchor System**:
- Nodes use anchor presets for responsive positioning
- Offset values provide fine-tuning
- Grow flags ensure proper scaling

**Z-Index Layering**:
```
Top (2): SkillButton clickable area
Mid (1): Line2D connections
Base (0): Panel containers
Back (-1): BorderHighlight effects
Bottom (-3): Background elements
```

### Node Hierarchy Best Practices

1. **Parent-Child Scene Tree**: Physical parent in scene = prerequisite parent
2. **Logical Grouping**: Related skills grouped under common ancestors
3. **Visual Flow**: Left-to-right or bottom-to-top progression
4. **Balanced Trees**: Avoid deep chains (max 4 levels recommended)

## Asset Management

### Texture Organization

**Skill Icons**:
- Path: `assets/skilltree/40-free-skillability-icons-volume-1-release/`
- Format: PNG, Dark theme variants
- Size: Consistent icon dimensions for visual harmony

**Materials**:
- `circular_border_material.tres` - Shader effect for node appearance
- Applied to all skill nodes for consistent visual style

### Theme Integration

**Color Consistency**:
- All purple values derived from base 460044
- Brightness variations maintain hue relationship
- High contrast for accessibility

**Icon Selection Guidelines**:
- Choose thematically appropriate icons per skill
- Maintain visual distinction between tree branches
- Consider color palette compatibility

## Performance Optimization

### Rendering Efficiency

- **BorderHighlight**: ColorRect more efficient than NinePatchRect
- **Line2D**: Top-level lines prevent transform inheritance overhead
- **Deferred Updates**: Line connections updated after position changes

### Signal Management

- **Minimal Signal Chains**: Direct connections avoid unnecessary hops
- **Batched Updates**: UI refreshes triggered by allocation events
- **Selective Refreshes**: Only affected nodes update, not entire tree

### Memory Considerations

- **Shared Materials**: Reuse materials across nodes
- **Texture Sharing**: Common icon textures loaded once
- **Node Pooling**: Not implemented (static trees don't require pooling)

## Accessibility Features

### Visual Accessibility

- **High Contrast Borders**: Clear state differentiation
- **Color-Independent Information**: Checkmarks supplement color coding
- **Readable Typography**: Outlined text ensures visibility

### Interaction Accessibility

- **Clear Feedback**: Every action provides visual and/or log feedback
- **Predictable Behavior**: Consistent interaction patterns
- **Error Prevention**: Prerequisites prevent invalid states

## Debugging & Development

### Visual Debugging

**Logger Categories**:
- `"ui"` - UI initialization and component setup
- `"events"` - User interactions and allocations
- `"system"` - Backend integration issues

**Common Debug Scenarios**:
```gdscript
# Node mapping verification
Logger.debug("Mapped %s: level %d" % [passive_id, node.level], "ui")

# Prerequisite validation
Logger.debug("Cannot allocate %s - parent %s has no points" % [child_id, parent_id], "events")

# Reset mode state
Logger.debug("Updated reset mode highlighting for %d nodes" % all_nodes.size(), "events")
```

### Development Tools

**Scene Inspector**:
- Check passive_type assignments in editor
- Verify anchor/offset positioning
- Test material assignments

**Runtime Inspection**:
- EventMasterySystem state via autoload
- Node mapping dictionary contents
- Signal connection verification

---

## Integration Guidelines

### Adding New Visual States

1. **Define Color Constants**: Add to skill_button.gd
2. **Update State Logic**: Modify _update_border_for_level()
3. **Test Visual Feedback**: Verify color contrast and clarity

### Customizing Tree Layouts

1. **Maintain Z-Index Order**: Preserve rendering layers
2. **Use Anchor Presets**: Ensure responsive behavior
3. **Test Line Connections**: Verify visual parent-child relationships

### Theme Customization

1. **Color Palette**: Maintain hue relationships for consistency
2. **Icon Selection**: Choose thematically appropriate textures
3. **Material Effects**: Customize shaders for unique visual effects

This modular UI architecture ensures maintainable, accessible, and visually appealing skill progression interfaces.