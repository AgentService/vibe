# Adding New Event Types to EventSkillTree System

## Quick Overview

To add a new event type (e.g., "expedition"), you need to:
1. Define passives in EventMasterySystem.gd
2. Add passive types to SkillNode enum
3. Create or copy a skill tree scene
4. Add tab to AtlasTreeUI
5. Configure tree layout and passive assignments

## Step-by-Step Implementation Guide

### Step 1: Define Passives in EventMasterySystem.gd

Add passive definitions to the `passive_definitions` dictionary:

```gdscript
# Expedition event passives - Single-level format
"expedition_preparation": {
    "name": "Expedition Preparation",
    "description": "Start expeditions with 25% more supplies",
    "max_level": 1,
    "cost": 1,
    "event_type": "expedition",
    "tree_position": "A",
    "tree_branch": "support",
    "modifiers": {"expedition_supplies": 1.25}
},
"expedition_endurance": {
    "name": "Expedition Endurance",
    "description": "Expedition duration increased by 30%",
    "max_level": 1,
    "cost": 1,
    "event_type": "expedition",
    "tree_position": "B",
    "tree_branch": "support",
    "modifiers": {"expedition_duration": 1.30}
},
# Add more passives following this pattern...
```

### Step 2: Add Passive Types to SkillNode Enum

In `scenes/ui/skill_tree/skill_button.gd`, extend the PassiveType enum:

**Note**: The skill_button.gd file now includes a scene-based tooltip system with @onready references to TooltipPanel and RichTextLabel nodes.

```gdscript
enum PassiveType {
    NONE,
    # Support Tree - Safer, Controlled Breaches
    SUPPORT_A_STABILIZATION,
    # ... existing breach types ...

    # Expedition Tree - New event type
    EXPEDITION_A_PREPARATION,     # 🗺️ Expedition A - Preparation
    EXPEDITION_B_ENDURANCE,       # 🗺️ Expedition B - Endurance
    EXPEDITION_C_MASTERY,         # 🗺️ Expedition C - Mastery
    # Add more as needed...
}
```

Then update the passive_id getter:

```gdscript
var passive_id: StringName:
    get:
        match passive_type:
            # ... existing cases ...

            # Expedition Tree
            PassiveType.EXPEDITION_A_PREPARATION: return "expedition_preparation"
            PassiveType.EXPEDITION_B_ENDURANCE: return "expedition_endurance"
            PassiveType.EXPEDITION_C_MASTERY: return "expedition_mastery"
            _: return ""
```

### Step 3: Create Skill Tree Scene

#### Option A: Copy Existing Tree (Recommended)

1. **Duplicate BreachSkillTree.tscn**:
   ```
   scenes/ui/skill_tree/BreachSkillTree.tscn → ExpeditionSkillTree.tscn
   ```

2. **Update the scene**:
   - Open `ExpeditionSkillTree.tscn` in Godot editor
   - Set event_type to "expedition" in the root node's inspector
   - Rename skill nodes (Branch1_A1 → Expedition_A1, etc.)
   - Each skill node now includes built-in scene-based tooltips

#### Option B: Create New Tree Layout

1. **Create new scene**: `scenes/ui/skill_tree/ExpeditionSkillTree.tscn`
2. **Root node**: Control with BreachSkillTree.gd script (or create EventSkillTree.gd base)
3. **Set event_type**: "expedition" in inspector
4. **Add skill nodes**: Instance skill_button.tscn for each passive
   - **Note**: skill_button.tscn now includes TooltipPanel with auto-sizing tooltips

### Step 4: Configure Node Layout (Godot Editor)

#### Node Hierarchy Setup

```
ExpeditionSkillTree (Control)
├── Expedition_A1 (SkillButton instance)
│   └── Expedition_B1 (SkillButton instance)
│       └── Expedition_C1 (SkillButton instance)
├── Expedition_A2 (SkillButton instance)
│   └── Expedition_B2 (SkillButton instance)
│       └── Expedition_C2 (SkillButton instance)
└── Expedition_A3 (SkillButton instance)
    └── Expedition_B3 (SkillButton instance)
        └── Expedition_C3 (SkillButton instance)
```

#### Per-Node Configuration

For each skill node in the editor:

1. **Select the node** in the scene tree
2. **Set passive_type** in the inspector:
   - Expedition_A1 → `EXPEDITION_A_PREPARATION`
   - Expedition_B1 → `EXPEDITION_B_ENDURANCE`
   - etc.
3. **Position the node** visually in the 2D editor
4. **Set texture_normal** to appropriate skill icon
5. **Apply material** (circular_border_material.tres)

#### Visual Layout Guidelines

- **Root nodes**: Bottom row, no parents
- **Child nodes**: Connected via scene hierarchy (parent-child)
- **Positioning**: Use anchors/offsets for responsive layout
- **Icons**: Choose thematically appropriate textures
- **Spacing**: Maintain consistent node spacing for line connections

### Step 5: Add Tab to AtlasTreeUI

#### Update AtlasTreeUI.tscn

1. **Open** `scenes/ui/atlas/AtlasTreeUI.tscn`
2. **Add new tab** under TabContainer:
   ```
   [node name="Expedition" type="Control" parent="TabContainer"]
   visible = false
   layout_mode = 2
   metadata/_tab_name = "Expedition"
   metadata/_tab_index = 4
   ```
3. **Instance tree** under the tab:
   ```
   [node name="ExpeditionTree" parent="TabContainer/Expedition" instance=ExtResource("expedition_tree")]
   layout_mode = 1
   event_type = &"expedition"
   ```

#### Update AtlasTreeUI.gd

1. **Add event type** to tab names:
   ```gdscript
   var tab_names = ["breach", "ritual", "pack_hunt", "boss", "expedition"]
   ```

2. **Add tree reference** (optional, for direct access):
   ```gdscript
   @onready var expedition_tree: EventSkillTree = $TabContainer/Expedition/ExpeditionTree
   ```

3. **Update reset functions** to handle new tree:
   ```gdscript
   func _set_reset_mode_active(active: bool) -> void:
       # ... existing trees ...
       if _current_event_type == "expedition" and expedition_tree:
           expedition_tree.set_reset_mode(active)
   ```

### Step 6: Test and Validate

#### Validation Checklist

- [ ] **Passive definitions** load correctly in EventMasterySystem
- [ ] **Node mapping** works (passive_id returns correct strings)
- [ ] **Tree displays** in Atlas UI as new tab
- [ ] **Allocation works** (click to allocate/deallocate)
- [ ] **Prerequisites** enforce correctly (parent → child)
- [ ] **Reset mode** highlights and functions properly
- [ ] **Persistence** saves/loads properly
- [ ] **Points system** shows correct available/allocated counts

#### Testing Commands

```gdscript
# Debug log to verify passive mapping
Logger.debug("Expedition passives loaded: %s" % str(EventMasterySystem.get_all_passives_for_event_type("expedition")))

# Test allocation
EventMasterySystem.allocate_passive("expedition_preparation")
```

## Advanced Customization

### Custom Tree Layouts

For unique tree structures:

1. **Different hierarchies**: Branch, diamond, circular layouts
2. **Custom positioning**: Use anchor presets and offsets
3. **Visual themes**: Create new border materials/colors
4. **Line styles**: Modify LINE_* constants in SkillNode

### Theme Integration

```gdscript
# Custom border colors for expedition theme
const BORDER_EXPEDITION_DEFAULT = Color(0.0, 0.4, 0.2, 1.0)  # Forest green
const BORDER_EXPEDITION_ALLOCATED = Color(0.2, 0.8, 0.4, 1.0)  # Bright green
```

### Performance Considerations

- **Node count**: Keep trees under 20 nodes for optimal performance
- **Line connections**: More complex hierarchies increase line calculation overhead
- **Asset optimization**: Use shared textures/materials where possible

## Common Issues & Solutions

### Issue: Passive IDs not mapping
**Solution**: Verify enum values match passive definition keys exactly

### Issue: Prerequisites not working
**Solution**: Check scene hierarchy - parent nodes must be actual scene parents

### Issue: Reset mode not highlighting
**Solution**: Ensure BorderHighlight node exists in skill_button.tscn

### Issue: Tab not appearing
**Solution**: Verify metadata/_tab_name and _tab_index are set correctly

### Issue: Points not persisting
**Solution**: Check event_type string matches exactly in all locations

---

## Quick Reference

### Required Files to Modify
1. `scripts/systems/EventMasterySystem.gd` - Passive definitions
2. `scenes/ui/skill_tree/skill_button.gd` - Enum and mapping (includes scene-based tooltips)
3. `scenes/ui/skill_tree/NewEventTree.tscn` - Tree layout (use BreachSkillTree.tscn as template)
4. `scenes/ui/atlas/AtlasTreeUI.tscn` - Tab addition
5. `scenes/ui/atlas/AtlasTreeUI.gd` - Tab logic

### Scene-Based Tooltip System (Current Architecture)

The skill nodes now include built-in tooltips with:
- **TooltipPanel**: Auto-sizing panel with 300px fixed width
- **RichTextLabel**: BBCode support for rich text formatting
- **MarginContainer**: 8px margins for clean spacing
- **Auto content**: Shows skill name and description automatically

### Minimal Example
```gdscript
# 1. EventMasterySystem.gd
"test_passive": {
    "name": "Test Passive",
    "description": "A test passive",
    "max_level": 1,
    "cost": 1,
    "event_type": "test",
    "modifiers": {"test_value": 1.5}
}

# 2. skill_button.gd enum
TEST_A_BASIC,  # maps to "test_passive"

# 3. AtlasTreeUI.gd
var tab_names = ["breach", "ritual", "pack_hunt", "boss", "test"]
```

This systematic approach ensures new event types integrate seamlessly with the existing skill tree infrastructure.