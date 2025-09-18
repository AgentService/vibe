# Skill Tree System V2 - Data-Driven Architecture

**Status:** Parked - Superseded by Atlas System MVP
  **Priority:** Future Enhancement
  **Note:** Revisit after EVENT_SYSTEM_FOLLOW_UP_INTEGRATION atlas system is complete
  
  **Status:** Ready for Implementation  
**Priority:** High  
**Type:** System Architecture Redesign  
**Estimated Time:** 12-16 hours  
**Created:** 2025-01-18  
**Context:** Replace rigid SkillTreeUI with sophisticated, reusable data-driven system supporting multiple tree types

## Background & Problem Statement

The current SkillTreeUI system has fundamental scalability limitations:

### Current System Issues ❌
- **Manual Scene Work**: Each tree requires hardcoded SkillTreeNode placement in Godot editor
- **Rigid Layout**: Fixed 2x2 quadrant system limits tree variety and growth
- **Poor Reusability**: Meta progression, equipment trees, character trees need separate implementations
- **Hardcoded Connections**: Connection logic is event-type agnostic and inflexible
- **Designer Friction**: Adding new trees requires significant programmer involvement

### Current Implementation Analysis
**Examined Files:**
- `scripts/ui/skill_tree/SkillTreeNode.gd` - Well-designed component with visual states ✅
- `scripts/ui/SkillTreeUI.gd` - Main controller with quadrant management ❌
- `scripts/resources/EventMasteryTree.gd` - Simple point tracking resource ❌
- `scenes/ui/skill_tree/SkillTreeNode.tscn` - Reusable node component ✅

**What Works Well:**
- SkillTreeNode component architecture is excellent and reusable
- Visual state management (locked/available/allocated/hover) is solid
- Theme integration and color coding system works

**What Needs Redesign:**
- Fixed quadrant layout system in SkillTreeUI
- Manual node positioning workflow
- Lack of data-driven tree generation
- No support for different tree topologies

## Solution: Data-Driven Architecture

### Core Principle: Editor Control + Data Flexibility
**The best of both worlds approach:**

1. **Design Phase**: Create `.tres` files defining tree structure, nodes, connections
2. **Generation Phase**: Custom Godot editor tool generates `.tscn` scenes from `.tres` definitions  
3. **Visual Phase**: Use normal Godot editor to adjust positioning, styling, add custom elements
4. **Runtime Phase**: SkillTreeRenderer reads `.tres` data and builds interactive tree

**Example Workflow:**
```
Designer: Creates breach_mastery_tree.tres (data)
↓
Editor Tool: Generates BreachMasteryTree.tscn (scene)
↓  
Developer: Opens .tscn in Godot editor (visual control)
↓
Runtime: Uses both .tres + .tscn (full functionality)
```

## Architecture Design

### Core Components

#### 1. SkillTreeDefinition Resource
```gdscript
# scripts/resources/SkillTreeDefinition.gd
class_name SkillTreeDefinition
extends Resource

@export var tree_id: StringName = ""
@export var tree_name: String = ""
@export var layout_type: LayoutType = LayoutType.HIERARCHICAL

@export_group("Tree Structure")
@export var nodes: Array[SkillNodeDefinition] = []
@export var connections: Array[SkillConnectionDefinition] = []
@export var layout_config: SkillTreeLayoutConfig

@export_group("Visual Theme")
@export var tree_theme: SkillTreeTheme
@export var background_texture: Texture2D
@export var connection_style: ConnectionStyle

enum LayoutType {
    LINEAR,        # Meta progression (vertical chains)
    RADIAL,        # Ritual mastery (hub-and-spoke) 
    WEB,           # Equipment/crafting (interconnected)
    HIERARCHICAL,  # Character skills (prerequisite-based)
    GRID,          # Traditional skill grid
    CUSTOM         # Custom positioning
}

enum ConnectionStyle {
    STRAIGHT,      # Direct lines
    CURVED,        # Bezier curves
    STEPPED,       # Right-angle connections
    ORGANIC        # Flowing natural curves
}
```

#### 2. SkillNodeDefinition Resource
```gdscript
# scripts/resources/SkillNodeDefinition.gd
class_name SkillNodeDefinition
extends Resource

@export var node_id: StringName = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D

@export_group("Progression")
@export var unlock_cost: int = 1
@export var prerequisite_nodes: Array[StringName] = []
@export var tier_requirement: int = 1

@export_group("Layout")
@export var position_hint: Vector2 = Vector2.ZERO  # For custom layouts
@export var layout_weight: float = 1.0             # For auto-layout algorithms
@export var group_id: StringName = ""              # For grouping related nodes

@export_group("Effects")
@export var effect_data: Dictionary = {}           # Game-specific effect data
@export var tags: Array[StringName] = []          # For filtering/searching

@export_group("Visual")
@export var custom_color: Color = Color.TRANSPARENT
@export var node_size: Vector2 = Vector2.ZERO     # Zero = use default
@export var visual_style: NodeVisualStyle = NodeVisualStyle.DEFAULT

enum NodeVisualStyle {
    DEFAULT,
    KEYSTONE,    # Large important nodes
    MINOR,       # Small utility nodes
    MASTERY,     # Special mastery nodes
    LEGENDARY    # Rare/unique nodes
}
```

#### 3. SkillConnectionDefinition Resource
```gdscript
# scripts/resources/SkillConnectionDefinition.gd
class_name SkillConnectionDefinition
extends Resource

@export var from_node: StringName = ""
@export var to_node: StringName = ""
@export var connection_type: ConnectionType = ConnectionType.PREREQUISITE

@export_group("Visual")
@export var connection_color: Color = Color.TRANSPARENT  # Transparent = use theme
@export var connection_width: float = 0.0                # 0 = use theme default
@export var is_bidirectional: bool = false

enum ConnectionType {
    PREREQUISITE,    # Standard unlock requirement
    SYNERGY,         # Bonus when both nodes allocated
    EXCLUSIVE,       # Cannot have both nodes
    GATEWAY,         # Special unlock requirement
    AESTHETIC        # Visual only, no gameplay impact
}
```

#### 4. Universal SkillTreeRenderer
```gdscript
# scripts/systems/SkillTreeRenderer.gd
class_name SkillTreeRenderer
extends Control

signal node_clicked(node_id: StringName)
signal node_hovered(node_id: StringName)
signal node_unhovered(node_id: StringName)

@export var tree_definition: SkillTreeDefinition
@export var auto_load_on_ready: bool = true

var _layout_engine: SkillTreeLayoutEngine
var _connection_renderer: SkillTreeConnectionRenderer
var _node_instances: Dictionary = {}  # node_id -> SkillTreeNode
var _progression_data: SkillTreeProgressionData

func load_tree_definition(definition: SkillTreeDefinition) -> void
func rebuild_tree() -> void
func update_node_states(progression: SkillTreeProgressionData) -> void
func get_node_instance(node_id: StringName) -> SkillTreeNode
func highlight_path_to_node(node_id: StringName) -> void
```

#### 5. Layout Engine System
```gdscript
# scripts/systems/SkillTreeLayoutEngine.gd
class_name SkillTreeLayoutEngine
extends RefCounted

static func calculate_layout(definition: SkillTreeDefinition, canvas_size: Vector2) -> Dictionary:
    match definition.layout_type:
        SkillTreeDefinition.LayoutType.LINEAR:
            return _calculate_linear_layout(definition, canvas_size)
        SkillTreeDefinition.LayoutType.RADIAL:
            return _calculate_radial_layout(definition, canvas_size)
        SkillTreeDefinition.LayoutType.WEB:
            return _calculate_web_layout(definition, canvas_size)
        SkillTreeDefinition.LayoutType.HIERARCHICAL:
            return _calculate_hierarchical_layout(definition, canvas_size)
        SkillTreeDefinition.LayoutType.GRID:
            return _calculate_grid_layout(definition, canvas_size)
        SkillTreeDefinition.LayoutType.CUSTOM:
            return _use_custom_positions(definition)

# Layout algorithms for different tree types
static func _calculate_hierarchical_layout(definition: SkillTreeDefinition, canvas_size: Vector2) -> Dictionary
static func _calculate_radial_layout(definition: SkillTreeDefinition, canvas_size: Vector2) -> Dictionary
static func _calculate_web_layout(definition: SkillTreeDefinition, canvas_size: Vector2) -> Dictionary
static func _calculate_linear_layout(definition: SkillTreeDefinition, canvas_size: Vector2) -> Dictionary
static func _calculate_grid_layout(definition: SkillTreeDefinition, canvas_size: Vector2) -> Dictionary
```

### Layout Algorithm Specifications

#### Hierarchical Layout (Character Skills)
- **Structure**: Tree-like with clear parent-child relationships
- **Flow**: Top-to-bottom or left-to-right progression
- **Features**: Automatic tier organization, prerequisite chains
- **Use Cases**: Character talent trees, ability progression

#### Radial Layout (Ritual Mastery)
- **Structure**: Central hub with spokes radiating outward
- **Flow**: Center-to-edge progression with specialization branches
- **Features**: Central mastery node, themed branches
- **Use Cases**: Mastery systems, elemental specializations

#### Web Layout (Equipment/Crafting)
- **Structure**: Interconnected network with multiple paths
- **Flow**: Multiple entry points, complex prerequisites
- **Features**: Cross-connections, alternative paths
- **Use Cases**: Crafting systems, complex skill webs

#### Linear Layout (Meta Progression)
- **Structure**: Single or multiple parallel chains
- **Flow**: Sequential unlocking, clear progression
- **Features**: Milestone markers, branching at key points
- **Use Cases**: Meta progression, upgrade paths

#### Grid Layout (Traditional)
- **Structure**: Regular grid with constrained movement
- **Flow**: Adjacent cell unlocking patterns
- **Features**: Familiar grid navigation, spatial organization
- **Use Cases**: Traditional RPG skill trees

## Editor Integration Tools

### Custom Godot Editor Plugin

#### 1. Skill Tree Editor Dock
```gdscript
# addons/skill_tree_editor/skill_tree_dock.gd
@tool
extends EditorPlugin

const SkillTreeEditorDock = preload("res://addons/skill_tree_editor/dock/SkillTreeEditorDock.tscn")

var dock_instance

func _enter_tree():
    dock_instance = SkillTreeEditorDock.instantiate()
    add_control_to_dock(DOCK_SLOT_LEFT_UR, dock_instance)

func _exit_tree():
    remove_control_from_docks(dock_instance)
```

#### 2. Visual Tree Editor Interface
**Features:**
- Drag-and-drop node creation
- Visual connection drawing
- Real-time layout preview
- Property inspector integration
- Template system for common patterns

#### 3. Tree Generation Tools
```gdscript
# addons/skill_tree_editor/tree_generator.gd
@tool
class_name SkillTreeGenerator

static func generate_scene_from_definition(definition: SkillTreeDefinition) -> PackedScene:
    var scene = PackedScene.new()
    var root = SkillTreeRenderer.new()
    root.tree_definition = definition
    
    # Generate layout
    var layout = SkillTreeLayoutEngine.calculate_layout(definition, Vector2(1920, 1080))
    
    # Create node instances
    for node_def in definition.nodes:
        var node_instance = _create_node_instance(node_def, layout)
        root.add_child(node_instance)
    
    # Create connections
    for connection_def in definition.connections:
        _create_connection_visual(connection_def, root)
    
    scene.pack(root)
    return scene

static func _create_node_instance(node_def: SkillNodeDefinition, layout: Dictionary) -> SkillTreeNode:
    var node = preload("res://scenes/ui/skill_tree/SkillTreeNode.tscn").instantiate()
    node.setup_node(node_def.node_id, "", node_def.display_name, node_def.description, node_def.unlock_cost)
    node.position = layout[node_def.node_id]
    return node
```

## Implementation Plan

### Phase 1: Core Resource System (4 hours)
**Goal:** Create data structure foundation

#### 1.1 Resource Classes
- [ ] Create `SkillTreeDefinition.gd` with complete tree structure support
- [ ] Create `SkillNodeDefinition.gd` with comprehensive node configuration
- [ ] Create `SkillConnectionDefinition.gd` with connection types and visual options
- [ ] Create `SkillTreeTheme.gd` for visual customization
- [ ] Create `SkillTreeLayoutConfig.gd` for layout-specific parameters

#### 1.2 Example Tree Definitions
- [ ] Create `breach_mastery_tree.tres` - Hierarchical layout example
- [ ] Create `meta_progression_tree.tres` - Linear layout example  
- [ ] Create `equipment_crafting_tree.tres` - Web layout example
- [ ] Create `ritual_mastery_tree.tres` - Radial layout example

#### 1.3 Resource Validation
- [ ] Add validation methods to all resource classes
- [ ] Create resource import/export utilities
- [ ] Add backwards compatibility for existing EventMasteryTree

### Phase 2: Layout Engine System (3 hours)
**Goal:** Implement automatic layout algorithms

#### 2.1 Layout Engine Core
- [ ] Create `SkillTreeLayoutEngine.gd` with algorithm dispatcher
- [ ] Implement hierarchical layout algorithm (character skills)
- [ ] Implement radial layout algorithm (mastery systems)
- [ ] Implement linear layout algorithm (progression chains)
- [ ] Implement web layout algorithm (complex interconnected)

#### 2.2 Layout Optimization
- [ ] Add collision detection
